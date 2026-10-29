extends SkeletonModifier3D
## Humanoid hit response and constrained death physics. No AI decisions here.
## Masses total approximately 75 kg; a shot breaks balance, not body mass.
const Balance=preload("./scav_balance.gd")
const CORPSE_LAYER=1<<29
const PARTS=[
	["Hips","Spine",.13,16.0,30.0,18.0],
	["Spine","Spine1",.13,10.0,22.0,15.0],
	["Spine1","Spine2",.14,10.0,22.0,15.0],
	["Spine2","Neck",.15,10.0,25.0,20.0],
	["Head","HeadTop_End",.095,5.0,38.0,35.0],
	["LeftArm","LeftForeArm",.065,2.2,75.0,45.0],
	["LeftForeArm","LeftHand",.055,1.5,65.0,20.0],
	["RightArm","RightForeArm",.065,2.2,75.0,45.0],
	["RightForeArm","RightHand",.055,1.5,65.0,20.0],
	["LeftUpLeg","LeftLeg",.09,5.0,60.0,25.0],
	["LeftLeg","LeftFoot",.065,3.0,70.0,8.0],
	["LeftFoot","LeftToeBase",.065,1.0,30.0,15.0],
	["RightUpLeg","RightLeg",.09,5.0,60.0,25.0],
	["RightLeg","RightFoot",.065,3.0,70.0,8.0],
	["RightFoot","RightToeBase",.065,1.0,30.0,15.0]]

class HitArea extends Area3D:
	var response: SkeletonModifier3D
	var part: String
	func receive_bullet_hit(amount: float, source: Node, point: Vector3, direction: Vector3) -> bool:
		return response.receive_hit(part,amount,source,point,direction)
	func take_damage(amount: float, source: Node=null) -> void:
		var direction:=Vector3.FORWARD
		if source is Node3D:direction=(global_position-source.global_position).normalized()
		response.receive_hit(part,amount,source,global_position,direction)

class BoneLengths extends SkeletonModifier3D:
	var response: SkeletonModifier3D
	func _process_modification_with_delta(_delta: float) -> void:
		if not response.dying:return
		# Physics supplies rotations and pelvis travel. A skeleton's bones keep
		# their captured lengths even during a solver's transient contact error.
		for id: int in response.death_local_positions:
			response.rig.set_bone_pose_position(id,response.death_local_positions[id])
		# Contact impulses can briefly overshoot a solver's angular limit. Keep
		# the rendered elbow/knee inside its anatomical arc without stretching.
		for part: String in ["LeftLeg","RightLeg","LeftForeArm","RightForeArm"]:
			var body: PhysicalBone3D=response.bodies[part]
			if not body.is_simulating_physics():continue
			var leg:=part.ends_with("Leg");var side: String="Left" if part.begins_with("Left") else "Right"
			var id: int=response.visual._bone(part)
			var a: Vector3=response.rig.get_bone_global_pose(response.visual._bone(side+("UpLeg" if leg else "Arm"))).origin
			var pose: Transform3D=response.rig.get_bone_global_pose(id)
			var c: Vector3=response.rig.get_bone_global_pose(response.visual._bone(side+("Foot" if leg else "Hand"))).origin
			var first: Vector3=(pose.origin-a).normalized();var second: Vector3=(c-pose.origin).normalized()
			var axis: Vector3=(response.rig.global_basis.inverse()*(body.global_basis*body.joint_offset.basis.z)).normalized()
			var bend:=atan2(first.cross(second).dot(axis),first.dot(second))
			var correction:=clampf(bend,0.0,deg_to_rad(140.0))-bend
			if absf(correction)>.0001:
				pose.basis=Basis(axis,correction)*pose.basis
				response.rig.set_bone_global_pose(id,pose)

var balance: RefCounted
var visual: Node3D
var actor: CharacterBody3D
var rig: Skeleton3D
var simulator: PhysicalBoneSimulator3D
var bodies: Dictionary={}
var hitboxes: Array[Area3D]=[]
var pose_cache: Array[Transform3D]=[]
var springs: Dictionary={}
var ready_for_use:=false
var dying:=false
var settled:=false
var last_hit: Dictionary={}
var last_hit_time: float=-100.0
var inherited_velocity:=Vector3.ZERO
var death_elapsed:=0.0
var quiet_time:=0.0
var last_reaction_angle:=0.0
var death_local_positions: Dictionary={}
var resting_damping:=false

func setup(presentation: Node3D) -> void:
	visual=presentation;actor=visual.actor;rig=visual.skeleton
	simulator=PhysicalBoneSimulator3D.new();simulator.name="DeathPhysics"
	rig.add_child(simulator)
	for spec: Array in PARTS:
		var id: int=visual._bone(spec[0]);var tip: int=visual._bone(spec[1])
		if id<0 or tip<0:continue
		var rest:=rig.get_bone_global_rest(id)
		var end:=rig.get_bone_global_rest(tip).origin
		var segment:=end-rest.origin
		var shape:=CapsuleShape3D.new();shape.radius=spec[2]
		shape.height=maxf(segment.length(),shape.radius*2.0+.005)
		var frame:=Transform3D(Basis(Quaternion(Vector3.UP,segment.normalized())),rest.origin+segment*.5)
		var offset:=rest.affine_inverse()*frame
		var body:=PhysicalBone3D.new();body.name="Body_"+spec[0]
		body.set("bone_name",rig.get_bone_name(id))
		body.body_offset=offset;body.mass=spec[3]
		body.friction=.85;body.bounce=0.0;body.linear_damp=.28;body.angular_damp=2.3
		# Human fall gravity; the character controller uses a faster game gravity.
		body.gravity_scale=9.81/float(ProjectSettings.get_setting("physics/3d/default_gravity",9.81))
		body.collision_layer=0;body.collision_mask=1
		# Build the joints at death from the final rendered pose, including IK.
		body.joint_type=PhysicalBone3D.JOINT_TYPE_NONE
		simulator.add_child(body)
		var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
		bodies[spec[0]]=body
		var attachment:=BoneAttachment3D.new();attachment.name="HitSocket_"+spec[0]
		attachment.bone_name=rig.get_bone_name(id);rig.add_child(attachment)
		var area:=HitArea.new();area.name="Hit_"+spec[0];area.response=self;area.part=spec[0]
		area.collision_layer=2;area.collision_mask=0;area.monitoring=false;area.monitorable=false
		attachment.add_child(area);area.transform=offset
		var hit_shape:=CollisionShape3D.new();hit_shape.shape=shape;area.add_child(hit_shape)
		hitboxes.append(area)
	# While alive, these bodies never compete with the character controller.
	ready_for_use=bodies.size()==PARTS.size()
	if ready_for_use:actor.add_to_group("weapon_proxy_bodies")
	balance=Balance.new();balance.setup(self)
	var lengths:=BoneLengths.new();lengths.name="RagdollBoneLengths";lengths.response=self
	rig.add_child(lengths)
	set_physics_process(false)

func receive_hit(part: String, amount: float, source: Node, point: Vector3, direction: Vector3) -> bool:
	if not is_finite(amount) or amount<=0 or not point.is_finite() or not direction.is_finite():return false
	if direction.length_squared()<.001:return false
	var impact:=clampf(amount,1.0,80.0)
	last_hit={"part":part,"point":point,"direction":direction.normalized(),"amount":impact}
	last_hit_time=Time.get_ticks_msec()*.001
	if dying:
		settled=false;quiet_time=0.0;set_physics_process(true)
		for body: PhysicalBone3D in bodies.values():PhysicsServer3D.body_set_state(body.get_rid(),PhysicsServer3D.BODY_STATE_SLEEPING,false)
		_impulse()
		return false
	inherited_velocity=actor.velocity
	var local_direction:=rig.global_basis.inverse()*direction.normalized()
	var axis:=Vector3.UP.cross(local_direction).normalized()
	var strength:=clampf(impact/35.0,.35,1.6)
	_kick("Spine",axis*strength*1.2)
	_kick("Spine2",axis*strength*1.8+Vector3.UP*local_direction.x*strength*.7)
	if part=="Head":_kick("Head",axis*strength*2.0)
	elif "Leg" in part:_kick(part,axis*strength*1.6)
	elif "Arm" in part:_kick(part,axis*strength*1.8)
	# Repeated bullets can interrupt a burst, but do not stack seconds of stun.
	actor.attack_cooldown=maxf(actor.attack_cooldown,.16)
	actor.take_damage(amount,source)
	if not dying and balance.begin(part,amount,direction):set_physics_process(true)
	return true

func _kick(part: String, impulse: Vector3) -> void:
	var id: int=visual._bone(part)
	if id<0:return
	if not springs.has(id):springs[id]={"angle":Vector3.ZERO,"velocity":Vector3.ZERO}
	springs[id].velocity=(springs[id].velocity+impulse).limit_length(5.0)

func _process_modification_with_delta(delta: float) -> void:
	if not ready_for_use or dying:return
	inherited_velocity=actor.velocity
	var hand_id: int=visual.arms.Right.hand
	var hand_before:=rig.global_transform*rig.get_bone_global_pose(hand_id)
	var grip: Transform3D=hand_before.affine_inverse()*visual.weapon.global_transform
	last_reaction_angle=0.0
	# Bounded substeps keep the spring stable after a slow frame.
	var count:=maxi(1,ceili(minf(delta,.1)/.008))
	var dt:=minf(delta,.1)/count
	for id: int in springs.keys():
		var spring: Dictionary=springs[id]
		for step: int in range(count):
			spring.velocity+=(-95.0*spring.angle-15.0*spring.velocity)*dt
			spring.angle=(spring.angle+spring.velocity*dt).limit_length(.24)
		var pose:=rig.get_bone_global_pose(id)
		pose.basis=Basis.from_euler(spring.angle)*pose.basis
		rig.set_bone_global_pose(id,pose)
		last_reaction_angle=maxf(last_reaction_angle,spring.angle.length())
		if spring.angle.length_squared()+spring.velocity.length_squared()<.00001:springs.erase(id)
	balance.pose()
	visual.weapon.global_transform=rig.global_transform*rig.get_bone_global_pose(hand_id)*grip
	pose_cache.clear()
	for id: int in range(rig.get_bone_count()):pose_cache.append(rig.get_bone_global_pose(id))

func start_death() -> bool:
	if not ready_for_use or dying:return false
	dying=true
	if Time.get_ticks_msec()*.001-last_hit_time>.1:
		last_hit={}
	visual.animator.pause()
	# Capture the rendered IK pose, not the restored pre-modifier animation.
	if pose_cache.size()==rig.get_bone_count():
		for id: int in range(pose_cache.size()):rig.set_bone_global_pose(id,pose_cache[id])
	else:
		pose_cache.clear()
		for id: int in range(rig.get_bone_count()):pose_cache.append(rig.get_bone_global_pose(id))
	# Physics activation is deferred out of a possible ray/physics callback.
	call_deferred("_release")
	return true

func _release() -> void:
	for id: int in range(pose_cache.size()):
		var parent: int=rig.get_bone_parent(id)
		if parent>=0 and id!=visual._bone("Hips"):
			death_local_positions[id]=(pose_cache[parent].affine_inverse()*pose_cache[id]).origin
	balance.open_hand(1.0)
	simulator.physical_bones_start_simulation()
	# Match the last rendered pose before constructing the constraints. The
	# simulator's pre-modifier pose omits weapon IK and balance recovery.
	for part: String in bodies:
		var body: PhysicalBone3D=bodies[part]
		body.global_transform=(rig.global_transform*pose_cache[body.get_bone_id()]*body.body_offset).orthonormalized()
		PhysicsServer3D.body_set_state(body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,body.global_transform)
	for part: String in bodies:
		_death_joint(part)
	_corpse_contacts()
	for part: String in bodies:
		var body: PhysicalBone3D=bodies[part]
		body.linear_velocity=inherited_velocity.limit_length(6.0)
	# A small loss of balance keeps an idle, symmetrical pose from standing rigid.
	var direction: Vector3=last_hit.get("direction",-actor.global_basis.z)
	var lean:=Vector3(direction.x,0,direction.z).normalized()
	for part: String in ["Hips","Spine","Spine1","Spine2"]:
		var body: PhysicalBone3D=bodies[part]
		body.angular_velocity=Vector3.UP.cross(lean)*.65
	_impulse()
	set_physics_process(true)

func _death_joint(part: String) -> void:
	if part=="Hips":return
	var body: PhysicalBone3D=bodies[part]
	var joint:=body.joint_offset
	var axes:=actor.global_basis.orthonormalized()
	var hinge_joint:=false
	var lower:=Vector3(-3,-2,-3);var upper:=-lower
	if part=="Head":lower=Vector3(-25,-20,-22);upper=-lower
	elif part in ["LeftArm","RightArm"]:lower=Vector3(-55,-25,-55);upper=-lower
	elif part in ["LeftUpLeg","RightUpLeg"]:lower=Vector3(-55,-18,-30);upper=Vector3(65,18,30)
	elif part in ["LeftFoot","RightFoot"]:lower=Vector3(-35,-8,-10);upper=Vector3(45,8,10)
	elif part in ["LeftLeg","RightLeg","LeftForeArm","RightForeArm"]:
		hinge_joint=true
		var leg: bool=part.ends_with("Leg")
		var side: String="Left" if part.begins_with("Left") else "Right"
		var parent_part: String=side+("UpLeg" if leg else "Arm")
		var tip: int=visual._bone(side+("Foot" if leg else "Hand"))
		var a: Vector3=rig.to_global(pose_cache[visual._bone(parent_part)].origin)
		var b: Vector3=rig.to_global(pose_cache[body.get_bone_id()].origin)
		var c: Vector3=rig.to_global(pose_cache[tip].origin)
		var proximal: Vector3=(b-a).normalized();var distal: Vector3=(c-b).normalized()
		var bend:=rad_to_deg(proximal.angle_to(distal))
		var hinge:=proximal.cross(distal)
		if hinge.length_squared()<.001:hinge=actor.global_basis.x if leg else actor.global_basis.y
		hinge=hinge.normalized()
		var along: Vector3=(distal-hinge*distal.dot(hinge)).normalized()
		axes=Basis(along,hinge.cross(along),hinge).orthonormalized()
		lower=Vector3(minf(bend,10.0)-bend,-2,-2);upper=Vector3(maxf(bend,125.0)-bend,2,2)
	joint.basis=body.global_basis.inverse()*axes
	body.joint_type=PhysicalBone3D.JOINT_TYPE_NONE
	body.joint_offset=joint
	# Assigning joint_offset resets the body from the simulator's cached pose.
	# Restore the same rendered pose used for the parent anchor before binding.
	body.global_transform=(rig.global_transform*pose_cache[body.get_bone_id()]*body.body_offset).orthonormalized()
	PhysicsServer3D.body_set_state(body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,body.global_transform)
	if hinge_joint:
		body.joint_type=PhysicalBone3D.JOINT_TYPE_HINGE
		body.set("joint_constraints/angular_limit_enabled",true)
		# Godot's hinge angle has the opposite sign to the segment bend above.
		body.set("joint_constraints/angular_limit_lower",-upper.x)
		body.set("joint_constraints/angular_limit_upper",-lower.x)
		body.set("joint_constraints/angular_limit_bias",.8)
		body.set("joint_constraints/angular_limit_softness",1.0)
		body.set("joint_constraints/angular_limit_relaxation",1.0)
		if part.ends_with("ForeArm"):body.angular_damp=5.0
		return
	body.joint_type=PhysicalBone3D.JOINT_TYPE_6DOF
	for i: int in range(3):
		var key: String="joint_constraints/"+["x","y","z"][i]+"/"
		body.set(key+"linear_limit_enabled",true)
		body.set(key+"linear_limit_lower",0.0);body.set(key+"linear_limit_upper",0.0)
		# Godot Physics uses linear_restitution for positional error correction.
		body.set(key+"linear_limit_softness",1.0);body.set(key+"linear_restitution",.8)
		body.set(key+"angular_limit_enabled",true)
		body.set(key+"angular_limit_lower",lower[i]);body.set(key+"angular_limit_upper",upper[i])
		body.set(key+"angular_limit_softness",.95);body.set(key+"angular_restitution",0.0)
		body.set(key+"erp",.8)

func _corpse_contacts() -> void:
	# Selected non-neighbour contacts prevent limbs folding through the trunk.
	# Exclude overlapping adjacent capsules, which otherwise fight the joints.
	# Arms overlap the trunk capsules in the rifle grip; permit those pairs.
	# Their anatomical hinge and render limits keep the limbs from folding.
	for part: String in bodies:
		var body: PhysicalBone3D=bodies[part]
		body.collision_layer=CORPSE_LAYER;body.collision_mask=1|CORPSE_LAYER
		for other: String in bodies:
			if part==other:continue
			var trunk: bool=other in ["Hips","Spine","Spine1","Spine2"]
			var contact: bool=part in ["LeftLeg","RightLeg","LeftFoot","RightFoot"] and trunk
			contact=contact or (part in ["LeftLeg","LeftFoot"] and other in ["RightLeg","RightFoot"])
			var reverse: bool=other in ["LeftLeg","RightLeg","LeftFoot","RightFoot"] and part in ["Hips","Spine","Spine1","Spine2"]
			reverse=reverse or (other in ["LeftLeg","LeftFoot"] and part in ["RightLeg","RightFoot"])
			if not contact and not reverse:body.add_collision_exception_with(bodies[other])

func _impulse() -> void:
	if last_hit.is_empty():return
	var body: PhysicalBone3D=bodies.get(last_hit.part,bodies.Spine2)
	# Impulse is capped independently of damage: no shotgun-launching bodies.
	var force: Vector3=last_hit.direction*clampf(last_hit.amount*.09,1.0,6.0)
	var offset: Vector3=(last_hit.point-body.global_position).limit_length(.25)
	body.apply_impulse(force,offset)

func _physics_process(delta: float) -> void:
	if not dying:
		balance.tick(delta)
		if not balance.needs_tick():set_physics_process(false)
		return
	death_elapsed+=delta
	balance.death_tick(delta)
	if death_elapsed>1.5 and not resting_damping:
		resting_damping=true
		for body: PhysicalBone3D in bodies.values():
			body.linear_damp=.8;body.angular_damp=6.0
	var quiet:=true
	for part: String in bodies:
		var body: PhysicalBone3D=bodies[part]
		if body.linear_velocity.length_squared()>.015 or body.angular_velocity.length_squared()>.04:quiet=false
	quiet_time=quiet_time+delta if quiet else 0.0
	if quiet_time>1.0:
		settled=true
		set_physics_process(false)
		# Engine sleeping preserves contact and pose without a new animation.
		for part: String in bodies:PhysicsServer3D.body_set_state(bodies[part].get_rid(),PhysicsServer3D.BODY_STATE_SLEEPING,true)
