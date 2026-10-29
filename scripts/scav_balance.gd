extends RefCounted
## Brief, collision-checked recovery layered over the existing tactical intent.
## The actor still uses move_and_slide; no teleport or replacement AI orders.
var impact: SkeletonModifier3D
var visual: Node3D
var actor: CharacterBody3D
var rig: Skeleton3D
var elapsed:=0.0
var duration:=0.0
var cooldown:=0.0
var mode: String="idle"
var direction:=Vector3.ZERO
var start_position:=Vector3.ZERO
var step_distance:=0.0
var step_side: String="Left"
var foot_start: Dictionary={}
var foot_goal: Dictionary={}
var brace_point:=Vector3.INF
var brace_normal:=Vector3.ZERO
var strength:=0.0
var was_crouching:=false
var reaction_count:=0
var applied_lean:=0.0
var hand_error:=INF
var planted_error:=0.0
var death_brace_frames:=0
var death_brace_contact:=false
var death_hand_target:=Vector3.INF

func setup(response: SkeletonModifier3D) -> void:
	impact=response;visual=impact.visual;actor=impact.actor;rig=impact.rig

func active() -> bool:
	return duration>0.0 and elapsed<duration

func _ray(from: Vector3,to: Vector3) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(from,to,1)
	query.exclude=[actor.get_rid()]
	return actor.get_world_3d().direct_space_state.intersect_ray(query)

func _floor(point: Vector3) -> Dictionary:
	return _ray(point+Vector3.UP*.35,point-Vector3.UP*.45)

func _supported_step(motion: Vector3) -> bool:
	if actor.test_move(actor.global_transform,motion):return false
	# Check the landing edge as well as the centre; a centre-only probe permits
	# a recovery step that leaves the supporting foot hanging over a ledge.
	for offset: Vector3 in [Vector3.ZERO,motion.normalized()*.22]:
		var floor:=_floor(actor.global_position+motion+offset)
		if floor.is_empty() or floor.normal.y<=.72 or absf(floor.position.y-actor.global_position.y)>=.24:return false
	return true

func begin(part: String, amount: float, incoming: Vector3) -> bool:
	if active() or cooldown>0.0 or actor.dead or amount<10.0:return false
	if not actor.is_on_floor():return false
	strength=clampf(amount/40.0,.45,1.0)
	was_crouching=actor.crouching
	direction=Vector3(incoming.x,0,incoming.z)
	if direction.length_squared()<.01:direction=-actor.global_basis.z
	direction=direction.normalized()
	var travel:=Vector3(actor.velocity.x,0,actor.velocity.z)
	if travel.length()>.5:direction=(direction*.7+travel.normalized()*.3).normalized()
	start_position=actor.global_position
	step_distance=(.23 if "Leg" in part else .16)*strength
	if was_crouching:step_distance*=.5
	step_side="Right" if part.begins_with("Right") else "Left"
	if not ("Leg" in part):step_side="Left" if actor.global_basis.x.dot(direction)>0 else "Right"
	brace_point=Vector3.INF;brace_normal=Vector3.ZERO;hand_error=INF
	mode="stumble" if _supported_step(direction*(step_distance+.12)) else "brace"
	# A reachable solid surface permits a palm plant. No reaching through walls.
	var shoulder_id: int=visual.arms.Left.upper
	var shoulder: Vector3=rig.to_global(rig.get_bone_global_pose(shoulder_id).origin)
	var wall:=_ray(shoulder,shoulder+direction*.65)
	if not wall.is_empty() and absf(wall.normal.y)<.55:
		var target: Vector3=wall.position+wall.normal*.045
		if target.distance_to(shoulder)<.55:
			brace_point=target;brace_normal=wall.normal;mode="brace"
	if mode=="brace":step_distance=0.0
	foot_start.clear();foot_goal.clear()
	for side: String in ["Left","Right"]:
		var foot_id: int=visual._bone(side+"Foot")
		var start: Vector3=rig.to_global(rig.get_bone_global_pose(foot_id).origin)
		foot_start[side]=start
		var goal:=start+direction*(step_distance if side==step_side else 0.0)
		var ground:=_floor(goal-Vector3.UP*.1)
		var original_ground:=_floor(start-Vector3.UP*.1)
		if not ground.is_empty() and not original_ground.is_empty():goal.y+=ground.position.y-original_ground.position.y
		foot_goal[side]=goal
	elapsed=0.0;duration=.78 if "Leg" in part else .66
	cooldown=duration+.55;reaction_count+=1
	return true

func tick(delta: float) -> void:
	cooldown=maxf(0.0,cooldown-delta)
	if not active():return
	elapsed=minf(elapsed+delta,duration)
	if not active():mode="idle"

func needs_tick() -> bool:
	return active() or cooldown>0.0

func can_fire() -> bool:
	return not active() or elapsed/duration>.82

func motion(desired: Vector3) -> Vector3:
	if not active():return desired
	var phase:=elapsed/duration
	var weight:=sin(PI*clampf(phase,0,1))
	var result:=desired*(1.0-.72*weight)
	if mode=="brace" and phase<.45:return Vector3.ZERO
	var distance:=Vector2(actor.global_position.x-start_position.x,actor.global_position.z-start_position.z).length()
	if mode=="stumble" and phase<.65 and distance<.48:
		var step:=direction*(step_distance*3.0*weight)
		if _supported_step(step*.18):result+=step
	return result

func pose() -> void:
	applied_lean=0.0;planted_error=0.0
	if not active():return
	var phase:=elapsed/duration
	var weight:=sin(PI*clampf(phase,0,1))
	var local:=rig.global_basis.inverse()*direction
	var axis:=Vector3.UP.cross(local).normalized()
	var hips_id: int=visual._bone("Hips")
	var hips:=rig.get_bone_global_pose(hips_id)
	hips.origin.y-=(.045 if was_crouching else .085)*strength*weight
	hips.basis=Basis(axis,.08*strength*weight)*hips.basis
	rig.set_bone_global_pose(hips_id,hips)
	for suffix: String in ["Spine","Spine2"]:
		var id: int=visual._bone(suffix)
		var bone:=rig.get_bone_global_pose(id)
		var angle:=.12*strength*weight
		bone.basis=Basis(axis,angle)*bone.basis;rig.set_bone_global_pose(id,bone)
		applied_lean+=angle
	# Plant the supporting foot while the other lifts into a small recovery step.
	var plant_weight:=smoothstep(0.0,.12,phase)*(1.0-smoothstep(.65,1.0,phase))
	for side: String in ["Left","Right"]:
		var foot_id: int=visual._bone(side+"Foot")
		var animated:=rig.get_bone_global_pose(foot_id).origin
		var p:=smoothstep(.12,.65,phase)
		var target: Vector3=foot_start[side].lerp(foot_goal[side],p)
		if mode=="stumble" and side==step_side:target.y+=sin(PI*p)*.07*strength
		var local_target:=animated.lerp(rig.to_local(target),plant_weight)
		_solve_leg(side,local_target)
		if side!=step_side:planted_error=rig.get_bone_global_pose(foot_id).origin.distance_to(local_target)
	# Release the supporting hand from the rifle while the other retains it.
	var arm: Dictionary=visual.arms.Left
	var hand:=rig.get_bone_global_pose(arm.hand)
	var target:=rig.get_bone_global_pose(visual.torso_bone).origin+Vector3(.32,-.12,.30)
	var basis:=hand.basis
	if brace_point.is_finite():
		var normal: Vector3=rig.global_basis.inverse()*brace_normal
		var palm: Basis=hand.basis*arm.palm_frame
		basis=Basis(Quaternion(palm.z.normalized(),normal.normalized()))*basis
		target=rig.to_local(brace_point)-basis*(arm.palm_offset as Vector3)
	var hand_weight:=smoothstep(0.0,.18,phase)*(1.0-smoothstep(.66,1.0,phase))
	visual._solve_arm(arm,hand.origin.lerp(target,hand_weight),hand.basis.slerp(basis,hand_weight),"Left")
	open_hand(hand_weight)
	if brace_point.is_finite():
		var result:=rig.get_bone_global_pose(arm.hand)
		hand_error=rig.to_global(result.origin+result.basis*(arm.palm_offset as Vector3)).distance_to(brace_point)

func open_hand(weight: float) -> void:
	for digit: String in ["Thumb","Index","Middle","Ring","Pinky"]:
		for segment: int in range(1,4):
			var id: int=visual._bone("LeftHand"+digit+str(segment))
			if id<0:continue
			var rest:=rig.get_bone_rest(id).basis.get_rotation_quaternion()
			rig.set_bone_pose_rotation(id,rig.get_bone_pose_rotation(id).slerp(rest,weight))

func _solve_leg(side: String, target: Vector3) -> void:
	var upper_id: int=visual._bone(side+"UpLeg");var lower_id: int=visual._bone(side+"Leg");var foot_id: int=visual._bone(side+"Foot")
	var upper:=rig.get_bone_global_pose(upper_id);var lower:=rig.get_bone_global_pose(lower_id);var foot:=rig.get_bone_global_pose(foot_id)
	var a:=upper.origin.distance_to(lower.origin);var b:=lower.origin.distance_to(foot.origin)
	var offset:=target-upper.origin
	if offset.length_squared()<.0001:return
	var along_dir:=offset.normalized();var reach:=clampf(offset.length(),absf(a-b)+.002,a+b-.002)
	var pole:=Vector3(.10 if side=="Left" else -.10,0,1)
	var bend: Vector3=(pole-along_dir*pole.dot(along_dir)).normalized()
	var along: float=(a*a-b*b+reach*reach)/(2.0*reach)
	var knee:=upper.origin+along_dir*along+bend*sqrt(maxf(0,a*a-along*along))
	var ankle:=upper.origin+along_dir*reach
	var upper_turn:=Basis(Quaternion((lower.origin-upper.origin).normalized(),(knee-upper.origin).normalized()))
	var lower_turn:=Basis(Quaternion((foot.origin-lower.origin).normalized(),(ankle-knee).normalized()))
	rig.set_bone_global_pose(upper_id,Transform3D(upper_turn*upper.basis,upper.origin))
	rig.set_bone_global_pose(lower_id,Transform3D(lower_turn*lower.basis,knee))
	rig.set_bone_global_pose(foot_id,Transform3D(foot.basis,ankle))

func death_tick(delta: float) -> void:
	# A short, low-strength protective reach while gravity still drives the fall.
	# Never keeps a dead actor upright or revives its tactical/weapon controller.
	if impact.death_elapsed<.08 or impact.death_elapsed>1.05 or death_brace_contact:return
	if impact.last_hit.get("part","")=="Head":return
	var upper: PhysicalBone3D=impact.bodies.LeftArm
	var lower: PhysicalBone3D=impact.bodies.LeftForeArm
	var upper_bone:=upper.global_transform*upper.body_offset.affine_inverse()
	var lower_bone:=lower.global_transform*lower.body_offset.affine_inverse()
	var hand_id: int=visual.arms.Left.hand
	var wrist: Vector3=lower_bone*rig.get_bone_rest(hand_id).origin
	var fall: Vector3=impact.last_hit.get("direction",-actor.global_basis.z)
	fall=Vector3(fall.x,0,fall.z).normalized()
	var forward: Vector3=-actor.global_basis.z
	if fall.dot(forward)<-.3:fall=(actor.global_basis.x+forward*.2).normalized()
	var probe:=upper_bone.origin+fall*.22
	var ground:=_ray(probe,probe-Vector3.UP*1.0)
	if ground.is_empty() or ground.normal.y<.65:return
	var target: Vector3=death_hand_target if death_hand_target.is_finite() else ground.position+ground.normal*.10
	var a:=upper_bone.origin.distance_to(lower_bone.origin)
	var b:=lower_bone.origin.distance_to(wrist)
	var offset:=target-upper_bone.origin
	if offset.length()>a+b+.04 or offset.length()<.08:return
	death_hand_target=target;death_brace_frames+=1
	if wrist.distance_to(target)<.13:death_brace_contact=true;return
	var along_dir:=offset.normalized();var reach:=minf(offset.length(),a+b-.01)
	var pole:=actor.global_basis.x*.6-forward*.4
	var bend: Vector3=(pole-along_dir*pole.dot(along_dir)).normalized()
	var along: float=(a*a-b*b+reach*reach)/(2.0*reach)
	var elbow:=upper_bone.origin+along_dir*along+bend*sqrt(maxf(0,a*a-along*along))
	var upper_basis:=Basis(Quaternion((lower_bone.origin-upper_bone.origin).normalized(),(elbow-upper_bone.origin).normalized()))*upper_bone.basis
	var lower_basis:=Basis(Quaternion((wrist-lower_bone.origin).normalized(),(target-elbow).normalized()))*lower_bone.basis
	_motor(upper,upper_basis*upper.body_offset.basis,delta)
	_motor(lower,lower_basis*lower.body_offset.basis,delta)

func _motor(body: PhysicalBone3D, target: Basis, delta: float) -> void:
	var error: Quaternion=(target*body.global_basis.inverse()).orthonormalized().get_rotation_quaternion()
	if error.w<0:error=-error
	if error.get_angle()<.005:return
	var desired: Vector3=(error.get_axis()*error.get_angle()*6.0).limit_length(4.0)
	body.angular_velocity=body.angular_velocity.move_toward(desired,delta*14.0)
