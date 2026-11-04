extends Node3D
## World-space foot planting with mechanical two-link IK. Motion is in metres.
## The owner moves this node; drive receives the measured velocity and turn rate.
signal foot_planted(leg: String, world_point: Vector3, intensity: float)
var skeleton: Skeleton3D
var legs: Array[Dictionary] = []
var rest: Dictionary = {}
var elapsed := 0.0
var last_velocity := Vector3.ZERO
var suspension := 0.0
var suspension_velocity := 0.0
var pitch := 0.0
var roll := 0.0
var scan := 0.0
var max_foot_slide := 0.0
var steps := 0
var surface_normal := Vector3.UP
var player: AnimationPlayer
var action_from: Array[Transform3D] = []
var expression := "PATROL"
var attention_yaw := 0.0
var posture_height := 0.0
var posture_pitch := 0.0
var combat_weight := 0.0
var faults: Dictionary = {}
# The owner's broken-leg gait (patrol_cripple.gd): posture, rocking and falls.
var cripple: RefCounted
var recovering := false
var gait_speed_scale := 1.0
var settle_time := 0.0
var settle_duration := 1.1
var settle_order: Array[String] = []
var settle_index := 0
var terrain_pitch := 0.0
var terrain_roll := 0.0
var ground_pair := 0
var ground_weight_shift := Vector3.ZERO
var inertia_shift := Vector3.ZERO
# Only shared within the current drive call; no cross-frame contact cache.
var _ground_homes: Dictionary = {}
var _body_bone := -1
var _bone_parents: PackedInt32Array = []
# Visual level of detail. Patrolling drones far from the camera or off screen
# pose their rig less often; alerted, recovering or damaged drones never skip.
# AI, movement and collision are unaffected: only leg posing is throttled.
const LOD_NEAR := 35.0
const LOD_FAR := 80.0
const LOD_SLEEP := 160.0
const LOD_MAX_STEP := .1
static var lod_enabled := true
static var _lod_phase_next := 0
var _lod_phase := 0
var pose_serial := 0
var _lod_delta := 0.0
var _lod_frozen := false
var _screen_notifier: VisibleOnScreenNotifier3D
# Stop-and-scan: the chassis rises and pans while the pack sweeps an area.
var area_scan := false
# Hit reaction: a sprung jolt on the chassis, with the feet left planted.
const HIT_SPRING := 130.0
const HIT_DAMP := 16.0
var hit_tilt := Vector2.ZERO
var hit_tilt_velocity := Vector2.ZERO
var hit_shift := Vector3.ZERO
var hit_shift_velocity := Vector3.ZERO
# Body clips: only the Body bone of an authored clip plays, on top of the
# procedural pose. Foot IK keeps running, so stances never slide the feet.
const BODY_CLIP_FADE := .18
const BODY_CLIP_MAX_OFFSET := .06
var _body_clip: Animation
var _body_clip_name := ""
var _body_clip_time := 0.0
var _body_clip_loop := false
var _body_clip_rot_track := -1
var _body_clip_pos_track := -1
var _body_clip_base_rot := Quaternion.IDENTITY
var _body_clip_base_pos := Vector3.ZERO
var _body_clip_rotation := Quaternion.IDENTITY
var _body_clip_offset := Vector3.ZERO
var _body_clip_weight := 0.0

func add_hit_reaction(away: Vector3, strength: float = 1.0) -> void:
	hit_tilt_velocity+=Vector2(away.z,-away.x)*2.6*strength
	hit_shift_velocity+=Vector3(away.x,0,away.z)*.55*strength
	suspension_velocity-=.12*strength

func play_body_clip(clip: String, loop: bool = false) -> void:
	if clip==_body_clip_name: return
	stop_body_clip()
	if player==null or not player.has_animation(clip): return
	var animation: Animation=player.get_animation(clip)
	for track: int in animation.get_track_count():
		if not str(animation.track_get_path(track)).ends_with(":Body"): continue
		if animation.track_get_type(track)==Animation.TYPE_ROTATION_3D: _body_clip_rot_track=track
		elif animation.track_get_type(track)==Animation.TYPE_POSITION_3D: _body_clip_pos_track=track
	if _body_clip_rot_track<0 and _body_clip_pos_track<0: return
	if _body_clip_rot_track>=0: _body_clip_base_rot=animation.rotation_track_interpolate(_body_clip_rot_track,0.0)
	if _body_clip_pos_track>=0: _body_clip_base_pos=animation.position_track_interpolate(_body_clip_pos_track,0.0)
	_body_clip=animation;_body_clip_name=clip;_body_clip_time=0.0;_body_clip_loop=loop

func stop_body_clip() -> void:
	_body_clip=null;_body_clip_name="";_body_clip_rot_track=-1;_body_clip_pos_track=-1

func _state_body_clip(state: String, target_yaw: float) -> void:
	match state:
		"NOTICE": play_body_clip("NoticeLeft" if target_yaw>0.0 else "NoticeRight")
		"IDENTIFY": play_body_clip("TargetConfirm")
		"COMBAT_ENTER": play_body_clip("CombatEnter")
		"COMBAT": play_body_clip("CombatIdle",true)
		"SEARCH": play_body_clip("Search",true)
		"RELAX": play_body_clip("CombatExit")
		_: stop_body_clip()

func _update_body_clip(delta: float, speed: float) -> void:
	if area_scan and expression=="PATROL" and _body_clip_name.is_empty(): play_body_clip("LookAround",true)
	elif not area_scan and _body_clip_name=="LookAround": stop_body_clip()
	if _body_clip!=null:
		_body_clip_time+=delta
		if _body_clip_time>=_body_clip.length:
			if _body_clip_loop: _body_clip_time=fposmod(_body_clip_time,_body_clip.length)
			else: stop_body_clip()
	if _body_clip!=null:
		if _body_clip_rot_track>=0: _body_clip_rotation=_body_clip.rotation_track_interpolate(_body_clip_rot_track,_body_clip_time)*_body_clip_base_rot.inverse()
		if _body_clip_pos_track>=0: _body_clip_offset=(_body_clip.position_track_interpolate(_body_clip_pos_track,_body_clip_time)-_body_clip_base_pos).limit_length(BODY_CLIP_MAX_OFFSET)
	# A stance reads while standing; on the move it is only a hint.
	var wanted:=lerpf(1.0,.3,smoothstep(.3,1.2,speed)) if _body_clip!=null else 0.0
	_body_clip_weight=move_toward(_body_clip_weight,wanted,delta/BODY_CLIP_FADE)

func begin_recovery() -> void:
	# Start at the actual attack pose; never teleport raised claws to rest anchors.
	begin_action();player.stop(true)
	recovering=true;settle_time=0.0;settle_index=0;last_velocity=Vector3.ZERO
	for leg in legs:
		var pose:=skeleton.get_bone_global_pose(leg.ids[2])
		leg.foot=skeleton.to_global(pose.origin);leg.start=leg.foot;leg.end=leg.foot
		leg.p=1.0;leg.cooldown=0.0
		leg.foot_basis=(skeleton.global_basis*pose.basis*(rest[leg.ids[2]] as Transform3D).basis.inverse()).orthonormalized()
	settle_order.assign(["FR","FL"])

func recover(delta: float) -> bool:
	settle_time+=delta
	var swinging:=false
	for leg in legs:
		if leg.p<1.0: swinging=true
	if settle_index<settle_order.size() and not swinging and settle_time>=.08+float(settle_index)*.36:
		for leg in legs:
			if leg.name!=settle_order[settle_index]: continue
			var wider: Vector3=leg.home+Vector3(signf((leg.home as Vector3).x)*.035,0,0)
			var landing:=contact(skeleton.to_global(wider))
			leg.start=leg.foot;leg.end=landing.point;leg.normal=landing.normal;leg.p=0.0
			leg.start_basis=leg.foot_basis;leg.end_basis=contact_basis(landing.normal);leg.swing_duration=.27
			break
		settle_index+=1
	drive(delta,Vector3.ZERO,0,false)
	_blend_from_action(smoothstep(0,.14,settle_time))
	if settle_time>=settle_duration:
		recovering=false
		return true
	return false

func set_expression(state: String, target_yaw: float = 0.0) -> void:
	if state!=expression: _state_body_clip(state,target_yaw)
	expression=state
	attention_yaw=clampf(target_yaw,-.20,.20)

func held_glance(time: float) -> float:
	# Brief turns separated by still holds; avoid a continuous pendulum scan.
	var phase:=fposmod(time,8.7)
	return .13*(smoothstep(1.2,1.9,phase)-smoothstep(3.0,3.8,phase))-.10*(smoothstep(5.2,5.9,phase)-smoothstep(7.0,7.8,phase))

func _ready() -> void:
	_lod_phase=_lod_phase_next;_lod_phase_next+=1
	var art: Node3D = preload("Shinrai_Patrol_Animated.glb").instantiate()
	add_child(art)
	skeleton = art.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	player=art.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.stop()
	# The ground gait is procedural; the mixer only runs while an action clip
	# is sampled. An idle active mixer still costs a full update every frame.
	player.active=false
	_screen_notifier=VisibleOnScreenNotifier3D.new()
	_screen_notifier.aabb=AABB(Vector3(-1.2,-.2,-1.2),Vector3(2.4,1.8,2.4))
	add_child(_screen_notifier)
	_body_bone = skeleton.find_bone("Body")
	_bone_parents.resize(skeleton.get_bone_count())
	for i in skeleton.get_bone_count():
		rest[i] = skeleton.get_bone_global_rest(i)
		_bone_parents[i] = skeleton.get_bone_parent(i)
	for name in ["FL", "RR", "FR", "RL"]:
		var ids: Array[int] = []
		for part in ["Upper", "Lower", "Foot"]:
			ids.append(skeleton.find_bone(name+"_"+part))
		var ankle: Vector3 = rest[ids[2]].origin
		var foot: Vector3 = skeleton.to_global(ankle)
		legs.append({"name":name,"ids":ids,"home":ankle,"foot":foot,"start":foot,"end":foot,"p":1.0,"cooldown":0.0,"foot_basis":skeleton.global_basis,"start_basis":skeleton.global_basis,"end_basis":skeleton.global_basis})

func ground(point: Vector3) -> Vector3:
	return contact(point).point

func contact(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point+surface_normal, point-surface_normal*1.5,1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var normal := surface_normal
	if not hit.is_empty():
		normal = hit.normal
		point = (hit.position as Vector3) + normal*.09
	return {"point":point,"normal":normal}

func contact_basis(normal: Vector3) -> Basis:
	var forward := skeleton.global_basis.z.slide(normal).normalized()
	if forward.length_squared()<.5: return skeleton.global_basis.orthonormalized()
	return Basis(normal.cross(forward).normalized(),normal,forward).orthonormalized()

func _uses_ground_gait() -> bool:
	# Action clips, recovery, wall climbing and damaged-leg crawl keep their poses.
	var owner_actor: Node = get_parent()
	return not recovering and faults.is_empty() and owner_actor != null and owner_actor.get("mode") == "GROUND" and surface_normal.dot(Vector3.UP) > .9

func _stride_allowance(leg: Dictionary, home: Vector3, direction: Vector3) -> Vector2:
	# Use this leg's supplied rig dimensions, retaining bend at full extension.
	var ids: Array[int] = leg.ids
	var hip_rest: Vector3 = (rest[ids[0]] as Transform3D).origin
	var knee_rest: Vector3 = (rest[ids[1]] as Transform3D).origin
	var ankle_rest: Vector3 = (rest[ids[2]] as Transform3D).origin
	var reach: float = (hip_rest.distance_to(knee_rest) + knee_rest.distance_to(ankle_rest)) * .92
	var hip: Vector3 = skeleton.to_global(hip_rest)
	var offset: Vector3 = (home - hip).slide(surface_normal)
	var height: float = absf((home - hip).dot(surface_normal))
	var along: float = offset.dot(direction)
	var sideways: Vector3 = offset - direction * along
	var span: float = sqrt(maxf(0.0, reach * reach - height * height - sideways.length_squared()))
	return Vector2(maxf(.025, span - along), maxf(.025, span + along))

func _ground_touchdown(plan: Dictionary, velocity: Vector3, yaw_rate: float, duration: float) -> Dictionary:
	var turning: Basis = Basis(surface_normal, yaw_rate * duration)
	var future_home: Vector3 = global_position + velocity * duration + turning * ((plan.home as Vector3) - global_position)
	return contact(future_home + turning * (plan.direction as Vector3) * float(plan.lead))

func _plan_ground_steps(velocity: Vector3, yaw_rate: float) -> float:
	_ground_homes.clear()
	var plans: Dictionary = {}
	var duration: float = .26
	var active: bool = false
	var travelling: bool = false
	for leg: Dictionary in legs:
		if leg.p < 1.0: active = true
		var home: Vector3 = ground(skeleton.to_global(leg.home))
		_ground_homes[leg.name] = home
		var travel: Vector3 = (velocity + surface_normal.cross(home - global_position) * yaw_rate).slide(surface_normal)
		var pace: float = travel.length()
		var direction: Vector3 = travel / pace if pace > .025 else Vector3.ZERO
		var lead: float = 0.0
		var lag: float = .48
		if pace > .025:
			travelling = true
			var allowance: Vector2 = _stride_allowance(leg, home, direction)
			lead = minf(.34, allowance.x * .62)
			lag = minf(.48, allowance.y * .65)
			# Both diagonal pairs must fit a complete swing/stance within reach.
			# This is achieved travel in metres, never the controller speed multiplier.
			duration = minf(duration, clampf((lead + lag) * .42 / pace, .055, .26))
		var error: Vector3 = (home - (leg.foot as Vector3)).slide(surface_normal)
		var plan: Dictionary = {"home":home,"travel":travel,"direction":direction,"lead":lead,"lag":lag,"error":error.length(),"pace":pace}
		plans[leg.name] = plan
		# If the chassis is blocked or changes direction mid-swing, complete a
		# smaller landing from the current toe pose. Planted feet never move.
		var swing_motion: Vector3 = leg.get("ground_swing_motion", travel)
		var stopped: bool = pace <= .025 and swing_motion.length() > .025
		var changed: bool = (travel - swing_motion).length() > maxf(.12, swing_motion.length() * .35)
		if leg.p < 1.0 and leg.has("ground_swing_motion") and (stopped or changed):
			var remaining: float = maxf(.10, float(leg.swing_duration) * (1.0 - float(leg.p)))
			var landing: Dictionary = _ground_touchdown(plan, velocity, yaw_rate, remaining)
			leg.start = leg.foot; leg.end = landing.point; leg.normal = landing.normal
			leg.start_basis = leg.foot_basis; leg.end_basis = contact_basis(landing.normal)
			leg.p = 0.0; leg.swing_duration = remaining; leg.ground_swing_motion = travel
	if active or not travelling: return duration
	var pairs: Array = [["FL", "RR"], ["FR", "RL"]]
	# Start together, then alternate; no per-frame resorting of the lead leg.
	for pair_index: int in [ground_pair, 1 - ground_pair]:
		var ready: bool = true
		var needed: bool = false
		for leg: Dictionary in legs:
			if not leg.name in pairs[pair_index]: continue
			ready = ready and leg.cooldown <= 0.0
			var plan: Dictionary = plans[leg.name]
			needed = needed or (plan.pace > .025 and plan.error > plan.lag)
		if not ready or not needed: continue
		for leg: Dictionary in legs:
			if not leg.name in pairs[pair_index]: continue
			var plan: Dictionary = plans[leg.name]
			# Predict touchdown at the achieved motion, then lead within rig reach.
			var landing: Dictionary = _ground_touchdown(plan, velocity, yaw_rate, duration)
			leg.start = leg.foot; leg.end = landing.point; leg.normal = landing.normal
			leg.p = 0.0; leg.swing_duration = duration; leg.ground_swing_motion = plan.travel
			leg.start_basis = (leg.foot_basis as Basis).orthonormalized()
			leg.end_basis = contact_basis(landing.normal)
		ground_pair = 1 - pair_index
		break
	return duration

func _lod_interval() -> int:
	# 1 poses every tick, N every Nth tick, 0 holds the current pose.
	if not lod_enabled or expression != "PATROL" or recovering or not faults.is_empty() or hit_tilt_velocity.length_squared()>.0004: return 1
	var camera := get_viewport().get_camera_3d()
	if camera == null: return 1
	var distance := camera.global_position.distance_to(global_position)
	# Headless runs have no screen, so only distance applies there.
	var on_screen := DisplayServer.get_name() == "headless" or _screen_notifier.is_on_screen()
	if distance > LOD_SLEEP or (not on_screen and distance > LOD_NEAR): return 0
	# Close behind the player the feet stay live, or they snap when it turns round.
	if not on_screen: return 4
	if distance > LOD_FAR: return 4
	if distance > LOD_NEAR: return 2
	return 1

func drive(delta: float, velocity: Vector3, yaw_rate: float, looking: bool) -> void:
	if skeleton == null: return
	if player.active and _uses_ground_gait(): player.active=false
	var interval := _lod_interval()
	if interval == 0:
		_lod_frozen=true;_lod_delta=0.0
		return
	if _lod_frozen:
		# The body kept moving while held; plant the feet where it now stands.
		_lod_frozen=false
		reset_contacts()
	_lod_delta+=delta
	# Each drone has its own phase so a whole band never poses on one tick.
	if (Engine.get_physics_frames()+_lod_phase)%interval!=0: return
	var step:=minf(_lod_delta,LOD_MAX_STEP)
	_lod_delta=0.0
	pose_serial+=1
	_drive(step,velocity,yaw_rate,looking)

func _drive(delta: float, velocity: Vector3, yaw_rate: float, looking: bool) -> void:
	var skeleton_transform := skeleton.global_transform
	var skeleton_inverse := skeleton_transform.affine_inverse()
	var skeleton_basis_inverse := skeleton_transform.basis.inverse()
	elapsed += delta
	var speed := velocity.length()
	var natural_ground: bool = _uses_ground_gait()
	var fast := smoothstep(.65,1.65,speed/gait_speed_scale) if faults.is_empty() else 0.0
	var accel: Vector3 = (velocity-last_velocity)/maxf(delta,.001)
	last_velocity = velocity
	var local_accel := global_basis.inverse()*accel
	# A heavy chassis rocks back as it pulls away, dips as it brakes and leans out
	# of a turn, and the body catches up with the legs a beat late.
	pitch = lerpf(pitch,clampf(-local_accel.z*.03,-.11,.11),1.0-exp(-delta*3.0))
	roll = lerpf(roll,clampf(-yaw_rate*speed*.04,-.08,.08),1.0-exp(-delta*3.0))
	var inertia_target := Vector3(clampf(-local_accel.x*.004,-.03,.03),0.0,clampf(-local_accel.z*.004,-.03,.03))
	inertia_shift = inertia_shift.lerp(inertia_target,1.0-exp(-delta*5.0))
	var alert:=expression in ["COMBAT_ENTER","COMBAT"]
	combat_weight=move_toward(combat_weight,1.0 if alert else 0.0,delta/.85)
	var notice:=expression in ["NOTICE","IDENTIFY"]
	var glance:=held_glance(elapsed)*(1.65 if expression=="SEARCH" else 1.0)
	var wanted_scan:=attention_yaw if notice or alert else glance*(1.0 if looking else .35)
	if area_scan and not alert: wanted_scan=sin(elapsed*1.1)*.17
	scan=lerpf(scan,wanted_scan,1.0-exp(-delta*3.5))
	posture_height=lerpf(posture_height,(.023 if notice else (.035 if area_scan else 0.0))-.05*combat_weight,1.0-exp(-delta*3.5))
	posture_pitch=lerpf(posture_pitch,(-.022 if notice else 0.0)+.03*combat_weight,1.0-exp(-delta*3.5))
	# Critically damped suspension, briefly compressed by each landing.
	suspension_velocity += (-95.0*suspension-19.5*suspension_velocity)*delta
	suspension += suspension_velocity*delta
	suspension = clampf(suspension,-.05,.018)
	hit_tilt_velocity += (-HIT_SPRING*hit_tilt-HIT_DAMP*hit_tilt_velocity)*delta
	hit_tilt += hit_tilt_velocity*delta
	hit_shift_velocity += (-HIT_SPRING*hit_shift-HIT_DAMP*hit_shift_velocity)*delta
	hit_shift += hit_shift_velocity*delta
	_update_body_clip(delta,speed)
	# Cadence follows travel speed so the short mechanical legs stay within reach.
	var duration := lerpf(.22,.13,fast)/gait_speed_scale
	if natural_ground: duration = _plan_ground_steps(velocity, yaw_rate)
	var step_limit := lerpf(.12,.20,fast)*(1.0-.14*combat_weight)
	# Three legs at a run take long, overlapping strides to keep up with the chassis.
	var crippled: bool = cripple != null and cripple.active()
	var running_lame: bool = crippled and cripple.top_speed > 2.0 and speed > 1.0
	if running_lame:
		step_limit = .21
		duration = clampf(.5/maxf(speed,.5),.11,.2)
	var active := 0
	for leg in legs:
		if leg.p<1.0: active+=1
	legs.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return (skeleton_transform*(a.home as Vector3)).distance_squared_to(a.foot) > (skeleton_transform*(b.home as Vector3)).distance_squared_to(b.foot))
	var targets: Dictionary = {}
	var body_id := _body_bone
	var body_rest: Transform3D = rest[body_id]
	var support_normal := Vector3.ZERO
	for leg in legs:
		support_normal += leg.get("normal",surface_normal) as Vector3
	var local_normal := skeleton_basis_inverse*support_normal.normalized()
	terrain_pitch=lerpf(terrain_pitch,clampf(atan2(local_normal.z,local_normal.y),-.18,.18),1.0-exp(-delta*3.0))
	terrain_roll=lerpf(terrain_roll,clampf(-atan2(local_normal.x,local_normal.y),-.18,.18),1.0-exp(-delta*3.0))
	var fault_roll:=0.0
	var fault_pitch:=0.0
	for failed: String in faults:
		fault_roll+=.025 if failed.ends_with("L") else -.025
		fault_pitch+=.015 if failed.begins_with("F") else -.015
	var buckle:=absf(sin(elapsed*3.8))*.012 if not faults.is_empty() and speed>.01 else 0.0
	# Each lost-leg combination has its own posture; a fall flattens it on its belly.
	var cripple_drop:=0.0
	if crippled:
		fault_pitch*=cripple.pitch_scale;fault_roll*=cripple.roll_scale
		var cycle:=TAU*float(cripple.phase)
		fault_roll+=sin(cycle)*cripple.rock;fault_pitch+=cos(cycle)*cripple.rock*.6
		cripple_drop=cripple.drop
		var down: float=cripple.stumble_weight()
		if down>0.0:
			var lean: float=cripple.side if cripple.side!=0.0 else 1.0
			cripple_drop+=.2*down;fault_roll+=.32*lean*down;fault_pitch+=.16*down
	var settling:=sin(PI*clampf(settle_time/settle_duration,0,1)) if recovering else 0.0
	var counterbalance:=sin(TAU*clampf(settle_time/settle_duration,0,1))*.028 if recovering else 0.0
	var body_basis := Basis.from_euler(Vector3(terrain_pitch+pitch+posture_pitch+fault_pitch+hit_tilt.x,scan,terrain_roll+roll+fault_roll+counterbalance+hit_tilt.y))
	if _body_clip_weight>0.0: body_basis=Basis(Quaternion.IDENTITY.slerp(_body_clip_rotation,_body_clip_weight))*body_basis
	var weight_shift:=Vector3(sin(elapsed*.67)*.003,0,0)*(1.0-fast)
	if natural_ground:
		var support_offset: Vector3 = Vector3.ZERO
		var supports: int = 0
		for leg: Dictionary in legs:
			if leg.p < 1.0: continue
			support_offset += skeleton_inverse*(leg.foot as Vector3) - (leg.home as Vector3)
			supports += 1
		var wanted_shift: Vector3 = Vector3.ZERO
		if supports > 0:
			support_offset /= float(supports)
			wanted_shift = Vector3(clampf(support_offset.x * .065, -.018, .018), 0.0, clampf(support_offset.z * .035, -.012, .012))
		ground_weight_shift = ground_weight_shift.lerp(wanted_shift, 1.0 - exp(-delta * 6.0))
		weight_shift = ground_weight_shift
	var body_transform := Transform3D(body_basis,body_rest.origin-body_basis*body_rest.origin+Vector3(0,suspension-.018*fast+posture_height-buckle-.023*settling-cripple_drop,0)+weight_shift+inertia_shift+hit_shift+_body_clip_offset*_body_clip_weight)
	targets[body_id] = body_transform*body_rest
	for leg in legs:
		leg.cooldown = maxf(0,leg.cooldown-delta)
		if faults.has(leg.name):
			# A wrecked leg no longer bears weight: it hangs tucked up under the body
			# and now and then kicks as its servo misfires.
			var seed: float = float(leg.ids[0])
			var spasm: float = pow(maxf(0.0,sin(elapsed*1.9+seed)),14.0)
			# Folded up beside its hip, the foot held above the body's waist line.
			var hip_rest: Vector3 = (rest[leg.ids[0]] as Transform3D).origin
			var reach_out: Vector3 = ((leg.home as Vector3)-hip_rest)*Vector3(.38,0.0,.38)
			var tuck: Vector3 = hip_rest+reach_out+Vector3(0.0,.11-.09*spasm+sin(elapsed*29.0+seed)*.012*spasm,0.0)+reach_out*.6*spasm
			leg.foot = skeleton_transform*(body_transform*tuck)
			leg.start = leg.foot; leg.end = leg.foot; leg.p = 1.0
			leg.foot_basis = (skeleton.global_basis*body_transform.basis).orthonormalized()
		else:
			# The planning pass already traced this exact home in this drive call.
			# Recovery, climb and damaged-leg gait keep their original live trace.
			var home: Vector3 = _ground_homes[leg.name] if natural_ground else ground(skeleton.to_global(leg.home))
			var rotating_velocity := surface_normal.cross(home-global_position)*yaw_rate
			var predicted: Vector3 = home+(velocity+rotating_velocity)*duration*1.5
			var error: float = (home-(leg.foot as Vector3)).slide(surface_normal).length()
			# Crawl has three supports. The faster gait allows only diagonal pairs;
			# a lame run lets two of its three legs swing at once to keep up.
			var can_lift: bool = active==0 or (running_lame and active==1)
			if fast>.04 and active==1:
				var partner: String = {"FL":"RR","RR":"FL","FR":"RL","RL":"FR"}[leg.name]
				for other in legs:
					if other.p<1.0 and other.name==partner: can_lift=true
			if not natural_ground and not recovering and leg.p>=1.0 and leg.cooldown<=0 and can_lift and error>step_limit:
				var landing := contact(predicted)
				leg.start=leg.foot;leg.end=landing.point;leg.normal=landing.normal;leg.p=0.0;active+=1
				leg.start_basis=(leg.foot_basis as Basis).orthonormalized();leg.end_basis=contact_basis(landing.normal)
				leg.swing_duration=duration*(1.0+.035*sin(float(steps)*2.399))
			if leg.p<1.0:
				leg.p=minf(1,leg.p+delta/float(leg.get("swing_duration",duration)))
				var p: float=leg.p
				var ease: float=p*p*(3.0-2.0*p)
				if natural_ground: ease = p*p*p*(p*(p*6.0-15.0)+10.0)
				var lift:=.045 if recovering else lerpf(.09,.15,fast)
				if running_lame: lift = .11
				var arc: float = sin(PI*p)
				if natural_ground:
					lift = lerpf(.045, .085, fast)
					# Zero vertical velocity at toe-off and touchdown, rather than a tap.
					arc = 16.0*p*p*(1.0-p)*(1.0-p)
				leg.foot=(leg.start as Vector3).lerp(leg.end,ease)+surface_normal*arc*lift
				leg.foot_basis=(leg.start_basis as Basis).orthonormalized().slerp((leg.end_basis as Basis).orthonormalized(),ease).orthonormalized()
				if p>=1:
					active-=1
					leg.cooldown = float(leg.get("swing_duration", duration)) * .8 if natural_ground else .07/gait_speed_scale
					steps+=1
					# Weight comes down on each foot: the chassis sinks a little and recovers.
					var thud: float = lerpf(.07,.12,fast) if natural_ground else lerpf(.09,.17,fast)
					if crippled: thud *= 1.35
					suspension_velocity-=thud
					foot_planted.emit(leg.name,leg.foot,lerpf(.45,1.0,fast))
		var ids: Array[int]=leg.ids
		var hip: Vector3 = body_transform*(rest[ids[0]] as Transform3D).origin
		var knee_rest: Vector3 = body_transform*(rest[ids[1]] as Transform3D).origin
		var ankle_rest: Vector3 = body_transform*(rest[ids[2]] as Transform3D).origin
		var ankle: Vector3 = skeleton_inverse*(leg.foot as Vector3)
		var upper: float = hip.distance_to(knee_rest)
		var lower: float = knee_rest.distance_to(ankle_rest)
		var axis: Vector3 = (ankle-hip).normalized()
		var distance: float = clampf(hip.distance_to(ankle),absf(upper-lower)+.001,upper+lower-.001)
		var along: float = (upper*upper-lower*lower+distance*distance)/(2*distance)
		var pole: Vector3 = knee_rest-hip
		pole=(pole-axis*pole.dot(axis)).normalized()
		var knee: Vector3=hip+axis*along+pole*sqrt(maxf(0,upper*upper-along*along))
		targets[ids[0]]=orient(ids[0],hip,knee,(rest[ids[1]] as Transform3D).origin)
		targets[ids[1]]=orient(ids[1],knee,ankle,(rest[ids[2]] as Transform3D).origin)
		targets[ids[2]]=Transform3D(skeleton_basis_inverse*(leg.foot_basis as Basis)*(rest[ids[2]] as Transform3D).basis,ankle)
	for id: int in targets:
		var parent: int = _bone_parents[id]
		var parent_global: Transform3D = targets[parent] if targets.has(parent) else Transform3D.IDENTITY
		var local_pose: Transform3D = parent_global.affine_inverse()*targets[id]
		# One local-pose write replaces three native calls; keep unit scale.
		var rotation := local_pose.basis.get_rotation_quaternion()
		skeleton.set_bone_pose(id,Transform3D(Basis(rotation),local_pose.origin))

func orient(id: int, start: Vector3, end: Vector3, rest_end: Vector3) -> Transform3D:
	var r: Transform3D=rest[id]
	var rotation := Quaternion((rest_end-r.origin).normalized(),(end-start).normalized())
	return Transform3D(Basis(rotation)*r.basis,start)

func reset_contacts() -> void:
	ground_pair = 0; ground_weight_shift = Vector3.ZERO
	for leg in legs:
		var landing := contact(skeleton.to_global(leg.home))
		leg.foot=landing.point;leg.normal=landing.normal
		leg.start=leg.foot;leg.end=leg.foot;leg.p=1.0;leg.cooldown=0.0
		leg.foot_basis=contact_basis(landing.normal)
	last_velocity=Vector3.ZERO

func begin_action() -> void:
	# Actions pose the rig without drive(), and recovery replants its own feet.
	_lod_frozen=false
	stop_body_clip();_body_clip_weight=0.0
	action_from.clear()
	for id in skeleton.get_bone_count(): action_from.append(skeleton.get_bone_pose(id))

func sample_action(clip: String, seconds: float) -> void:
	pose_serial+=1
	player.active=true
	if player.current_animation!=clip: player.play(clip)
	player.seek(seconds,true)
	player.pause()
	var weight := smoothstep(0.0,.12,seconds)
	_blend_from_action(weight)

func _blend_from_action(weight: float) -> void:
	pose_serial+=1
	if weight<1.0 and action_from.size()==skeleton.get_bone_count():
		for id in skeleton.get_bone_count():
			var pose: Transform3D=action_from[id].interpolate_with(skeleton.get_bone_pose(id),weight)
			skeleton.set_bone_pose_position(id,pose.origin)
			skeleton.set_bone_pose_rotation(id,pose.basis.get_rotation_quaternion())
