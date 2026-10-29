extends Node
## Contact-gated melee plus a telegraphed, cover-blocked roof stun discharge.
signal attack_started(kind: String)
signal hit_landed(kind: String, damage: float)
signal attack_finished(kind: String)
signal stun_discharged(applied: bool, origin: Vector3, endpoint: Vector3)
const LEAP_REARM_RATE := 1.10
const LEAP_NATIVE_REARM_SECONDS := 1.2
const LEAP_DAMAGE := 18.0
const LEAP_FACE_ATTACH_CHANCE := .07
const LEAP_FACE_ATTACH_DAMAGE := 12.0
const LEAP_LOAD_SECONDS := .20
const LEAP_FLIGHT_SECONDS := .82
const LEAP_LEAD_SECONDS := .65
const LEAP_CONTACT_REACH := .82 # Native LeapAttack toes span .74-.86m forward.
const LEAP_MIN_CONTACT_SECONDS := .30
const LEAP_MAX_CONTACT_SECONDS := .74
const LEAP_MAX_TARGET_TURN_RATE := 2.5
const LEAP_TAKEOFF_YAW_TOLERANCE := .045
const LEAP_OVERSHOOT := .90
const LEAP_MIN_SPEED := 4.5
const LEAP_MAX_SPEED := 10.5
const LEAP_MAX_TARGET_SPEED := 5.0
const LEAP_MAX_AIM_YAW := 1.45
const LEAP_LOAD_TURN_RATE := 8.0
const LEAP_MIN_RANGE := 1.6
const LEAP_MAX_RANGE := 5.0
const LEAP_FACING_YAW := 1.15
const SLASH_DAMAGE := 7.0
const STUN_MIN_RANGE := 2.2
const STUN_MAX_RANGE := 25.0
const STUN_MAX_YAW := PI / 3.0
const STUN_DAMAGE := 8.0
const STUN_DURATION := 3.0
const STUN_EMITTER := preload("patrol_stun_emitter.gd")
const STUN_VOICE := preload("drone_tazer_voice.gd")
const STUN_WINDUP := STUN_EMITTER.WINDUP_SECONDS
const STUN_ATTACK_SECONDS := STUN_EMITTER.FINISHED_SECONDS
const STUN_COOLDOWN := 3.5
const STUN_MOVEMENT_EPSILON := .001
const STUN_MOVING_MISS_CHANCE := .75
const STUN_EXTRA_MISS_CHANCE := .05
var actor: CharacterBody3D
var target: Node3D
var attack := ""
var elapsed := 0.0
var recovery := 0.0
var recovery_duration := 0.0
var delivered: Dictionary = {}
var previous_tips: Dictionary = {}
var hit_log: Array[Dictionary] = []
var stun_shot_log: Array[Dictionary] = []
var stun_emitter: Node3D
var emitter_ready := false
var stun_voice: Node3D
var stun_voice_cycle_id := 0
var stun_voice_lock_announced := false
var stun_voice_lock_retired := false
var stun_voice_check_remaining := 0.0
var stun_cooldown := 0.0
var stun_moved_during_red := false
var stun_previous_target_position := Vector3.ZERO
var leap_reference_direction := Vector3.ZERO
var leap_plan: Dictionary = {}
var leap_previous_target_velocity := Vector3.ZERO
var leap_target_turn_rate := 0.0
var leap_floor_top_cache: Dictionary = {}

func _ready() -> void:
	actor=get_parent() as CharacterBody3D
	process_physics_priority=1
	stun_emitter=STUN_EMITTER.new()
	stun_emitter.name="StunEmitterController";add_child(stun_emitter)
	emitter_ready=stun_emitter.setup(actor)
	stun_voice=STUN_VOICE.new()
	stun_voice.name="DroneTazerVoiceController"
	stun_voice.setup(actor,_stun_voice_still_valid)
	actor.health.destroyed.connect(_on_actor_destroyed)

func _on_actor_destroyed() -> void:
	# Also retire the weapon hitbox when death occurs outside an attack.
	if is_instance_valid(stun_emitter): stun_emitter.shutdown()
	if is_instance_valid(stun_voice): stun_voice.shutdown()

func _exit_tree() -> void:
	if is_instance_valid(stun_voice): stun_voice.shutdown()

func _stun_voice_still_valid(cycle_id: int, candidate: Node3D) -> bool:
	# Evaluated only during a pending/playing cue or this active targeting cycle.
	if not is_instance_valid(actor) or actor.dead or actor.mode!="STUN_ATTACK": return false
	if attack!="StunShot" or cycle_id!=stun_voice_cycle_id or stun_voice_lock_retired: return false
	if candidate!=target or not target_valid(candidate) or delivered.has("Stun"): return false
	if not emitter_ready or elapsed<STUN_EMITTER.LIFT_FINISHED_SECONDS or elapsed>=STUN_WINDUP: return false
	var distance: float=actor.global_position.distance_to(candidate.global_position)
	return distance>=STUN_MIN_RANGE and distance<=STUN_MAX_RANGE and _stun_lane_clear(candidate)

func _update_stun_lock_voice(delta: float) -> void:
	if not is_instance_valid(stun_voice) or stun_voice_lock_retired: return
	if elapsed<STUN_EMITTER.LIFT_FINISHED_SECONDS: return
	# Acquire once during BLUE; the helper adds precisely .6s after this event.
	if not stun_voice_lock_announced and elapsed>=STUN_EMITTER.RED_WARNING_SECONDS:
		stun_voice_lock_retired=true;return
	stun_voice_check_remaining=maxf(0.0,stun_voice_check_remaining-delta)
	if stun_voice_check_remaining>0.0: return
	stun_voice_check_remaining=.1
	if not _stun_voice_still_valid(stun_voice_cycle_id,target):
		if stun_voice_lock_announced:
			stun_voice_lock_retired=true
			stun_voice.cancel_cycle(stun_voice_cycle_id)
		return
	if not stun_voice_lock_announced:
		stun_voice_lock_announced=true
		stun_voice.notify_lock_acquired(stun_voice_cycle_id,target)

func _stun_target_point(candidate: Node3D) -> Vector3:
	var collision: CollisionShape3D=candidate.get("body_collision") as CollisionShape3D
	if is_instance_valid(collision): return collision.global_position+Vector3.UP*.15
	return candidate.global_position+Vector3.UP*.9

func _can_stun(candidate: Node3D, distance: float) -> bool:
	if not emitter_ready or stun_cooldown>0 or distance<STUN_MIN_RANGE or distance>STUN_MAX_RANGE: return false
	if not candidate.has_method("apply_drone_stun"): return false
	if float(candidate.get("stun_remaining"))>0 or float(candidate.get("stun_immunity_remaining"))>0: return false
	var pack:=actor.get_parent()
	return not pack.has_method("can_start_stun") or pack.can_start_stun(actor)

func target_valid(candidate: Node3D) -> bool:
	if not is_instance_valid(candidate) or not candidate.is_visible_in_tree() or not candidate.has_method("take_damage"): return false
	var _raid: Node=actor.get("navigation_source")
	if is_instance_valid(_raid) and _raid.has_method("insertion_grace") and _raid.insertion_grace(): return false
	if candidate.has_method("is_combat_alive") and not candidate.is_combat_alive(): return false
	return true

func clear_sight(candidate: Node3D) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.5,candidate.global_position+Vector3.UP*.65,1)
	query.exclude=[actor.get_rid()]
	var hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider==candidate or candidate.is_ancestor_of(hit.collider)

func _stun_lane_clear(candidate: Node3D) -> bool:
	# The deployed gun aims independently of the chassis. Test its raised muzzle,
	# including peers and corpses, before asking for the shared attack slot.
	var aim: Vector3=_stun_target_point(candidate)
	var origin: Vector3=stun_emitter.preview_muzzle_position(aim)
	if not origin.is_finite(): return false
	var query:=PhysicsRayQueryParameters3D.create(origin,aim,1|2|8)
	query.exclude=[actor.get_rid()];query.hit_from_inside=true
	var hit: Dictionary=actor.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider==candidate

func _leap_lane_clear(candidate: Node3D, direction: Vector3, distance: float) -> bool:
	var body: CollisionShape3D=actor.get("collider") as CollisionShape3D
	if not is_instance_valid(body) or not body.shape is BoxShape3D: return false
	# The intended victim must not veto every contact attack. Only this predictive
	# clearance query excludes it; the real actor retains its normal body mask.
	# Retain the complete corridor veto for peers/corpses. World clearance below
	# follows the native AIR arc instead of casting horizontally into paving lips.
	var box:=body.shape as BoxShape3D
	var envelope:=CylinderShape3D.new()
	envelope.radius=Vector2(box.size.x*.5+absf(body.position.x),box.size.z*.5+absf(body.position.z)).length()
	envelope.height=box.size.y
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=envelope;query.collision_mask=2|8;query.collide_with_areas=false
	var excluded: Array[RID]=[actor.get_rid()]
	if candidate is CollisionObject3D: excluded.append(candidate.get_rid())
	query.exclude=excluded
	query.transform=Transform3D(Basis.IDENTITY,actor.global_position+Vector3.UP*(body.position.y+.10))
	var space:=actor.get_world_3d().direct_space_state
	if not space.intersect_shape(query,1).is_empty(): return false
	query.motion=direction*distance
	if space.cast_motion(query)[0]<.9999: return false
	return _leap_world_arc_clear(candidate,direction,distance,body,excluded)

func _leap_tagged_floor(collider: Object) -> bool:
	return collider is StaticBody3D and (collider.is_in_group("midori_terrain_floor") or collider.is_in_group("midori_terrain_paving"))

func _leap_supported_start(from: Transform3D) -> bool:
	# Native recovery reports every contact at the exact chassis pose. Initial
	# overlaps cannot be silently skipped by cast_motion, including terrain sides.
	var collision:=KinematicCollision3D.new()
	if not actor.test_move(from,Vector3.ZERO,collision,actor.safe_margin,true,32): return false
	for index: int in collision.get_collision_count():
		if not _leap_tagged_floor(collision.get_collider(index)) or collision.get_normal(index).dot(Vector3.UP)<cos(actor.floor_max_angle): return false
	return collision.get_collision_count()>0

func _leap_floor_surface_top(hit: Dictionary, landing: PhysicsShapeQueryParameters3D) -> float:
	# Saturation is accepted only after checking all actual triangle geometry
	# inside an expanded native chassis volume. INF means unknown/unsafe.
	var collider: StaticBody3D=hit.collider as StaticBody3D
	var index:=int(hit.get("shape",-1))
	if collider==null or index<0 or not landing.shape is BoxShape3D: return INF
	var owner:=collider.shape_find_owner(index)
	var shape: ConcavePolygonShape3D
	for local_index: int in collider.shape_owner_get_shape_count(owner):
		if collider.shape_owner_get_shape_index(owner,local_index)==index:
			shape=collider.shape_owner_get_shape(owner,local_index) as ConcavePolygonShape3D;break
	if shape==null: return INF
	var transform:=collider.global_transform*collider.shape_owner_get_transform(owner)
	var faces:=shape.get_faces()
	if faces.is_empty() or faces.size()%3!=0: return INF
	var half: Vector3=(landing.shape as BoxShape3D).size*.5
	var basis:=landing.transform.basis
	var extent:=Vector3(absf(basis.x.x)*half.x+absf(basis.y.x)*half.y+absf(basis.z.x)*half.z,absf(basis.x.y)*half.x+absf(basis.y.y)*half.y+absf(basis.z.y)*half.z,absf(basis.x.z)*half.x+absf(basis.y.z)*half.y+absf(basis.z.z)*half.z)
	extent+=Vector3.ONE*(landing.margin+.002)
	var low:=landing.transform.origin-extent;var high:=landing.transform.origin+extent
	# A native bounds check handles entirely flat meshes without a triangle loop.
	var bounds:=shape.get_debug_mesh().get_aabb()
	if bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.y==0.0 and transform.basis.x.y==0.0 and transform.basis.z.y==0.0:
		return (transform*Vector3(0,bounds.position.y,0)).y
	# Quantized bounds are a superset of the complete current query volume.
	# Hashing the typed transform avoids rounded textual-coordinate cache keys.
	var cells:=Vector4i(floori(low.x*8.0),floori(low.z*8.0),ceili(high.x*8.0),ceili(high.z*8.0))
	var levels:=Vector2i(floori(low.y*1000.0),ceili(high.y*1000.0))
	var cache_key:=str(shape.get_rid(),"/",hash(faces),"/",hash(transform),"/",cells,"/",levels,"/",actor.floor_max_angle)
	if leap_floor_top_cache.has(cache_key):
		var cached: Dictionary=leap_floor_top_cache[cache_key]
		if cached.world_transform==transform and cached.floor_angle==actor.floor_max_angle: return float(cached.surface_top)
	low=Vector3(float(cells.x)/8.0,float(levels.x)/1000.0,float(cells.y)/8.0)
	high=Vector3(float(cells.z)/8.0,float(levels.y)/1000.0,float(cells.w)/8.0)
	var surface_top: float=-INF
	var found:=false
	for triangle: int in range(0,faces.size(),3):
		var a:=transform*faces[triangle];var b:=transform*faces[triangle+1];var c:=transform*faces[triangle+2]
		if not a.is_finite() or not b.is_finite() or not c.is_finite(): surface_top=INF;found=false;break
		if maxf(a.x,maxf(b.x,c.x))<low.x or minf(a.x,minf(b.x,c.x))>high.x or maxf(a.y,maxf(b.y,c.y))<low.y or minf(a.y,minf(b.y,c.y))>high.y or maxf(a.z,maxf(b.z,c.z))<low.z or minf(a.z,minf(b.z,c.z))>high.z: continue
		var normal: Vector3=(b-a).cross(c-a)
		if normal.length_squared()<.000000000001: continue
		if absf(normal.normalized().y)<cos(actor.floor_max_angle): surface_top=INF;found=false;break
		surface_top=maxf(surface_top,maxf(a.y,maxf(b.y,c.y)));found=true
	if not found: surface_top=INF
	if leap_floor_top_cache.size()>=64: leap_floor_top_cache.clear()
	leap_floor_top_cache[cache_key]={"world_transform":transform,"floor_angle":actor.floor_max_angle,"surface_top":surface_top}
	return surface_top

func _leap_saturated_floor_landing(query: PhysicsShapeQueryParameters3D) -> bool:
	# Full world/peer/corpse enumeration prevents floor contacts hiding obstacles.
	var complete:=PhysicsShapeQueryParameters3D.new()
	complete.shape=query.shape;complete.transform=query.transform;complete.margin=query.margin
	complete.collision_mask=1|2|8;complete.collide_with_areas=false;complete.exclude=query.exclude
	var overlaps:=actor.get_world_3d().direct_space_state.intersect_shape(complete,32)
	if overlaps.is_empty() or overlaps.size()>=32 or not query.shape is BoxShape3D: return false
	var half: Vector3=(query.shape as BoxShape3D).size*.5
	var basis:=query.transform.basis
	var bottom:=query.transform.origin.y-(absf(basis.x.y)*half.x+absf(basis.y.y)*half.y+absf(basis.z.y)*half.z)
	var support_found:=false
	for hit: Dictionary in overlaps:
		if not _leap_tagged_floor(hit.collider): return false
		var surface_top:=_leap_floor_surface_top(hit,query)
		# Every possible contact face is walkable and stays at the feet. A plane
		# or side face elsewhere in the chassis cannot hide in 32 floor contacts.
		if not is_finite(surface_top) or surface_top>bottom+query.margin+.003: return false
		support_found=true
	return support_found

func _leap_floor_landing(query: PhysicsShapeQueryParameters3D, elapsed: float, descending: bool, travelled: float, minimum_travel: float) -> bool:
	if not descending or elapsed<=.1 or travelled<minimum_travel: return false
	var space:=actor.get_world_3d().direct_space_state
	var overlaps:=space.intersect_shape(query,32)
	if overlaps.is_empty() or overlaps.size()>=32: return false
	for hit: Dictionary in overlaps:
		if not _leap_tagged_floor(hit.collider): return false
	# A single closest rest normal could hide a simultaneous vertical face on
	# the same tagged terrain body. Inspect every native chassis recovery contact
	# at the advanced hit pose; this test never moves the actor or changes masks.
	var body: CollisionShape3D=actor.get("collider") as CollisionShape3D
	var parameters:=PhysicsTestMotionParameters3D.new()
	parameters.from=query.transform*body.transform.affine_inverse()
	parameters.motion=Vector3.ZERO;parameters.margin=actor.safe_margin
	parameters.max_collisions=32;parameters.recovery_as_collision=true
	parameters.exclude_bodies=query.exclude
	var result:=PhysicsTestMotionResult3D.new()
	if not PhysicsServer3D.body_test_motion(actor.get_rid(),parameters,result): return false
	var count:=result.get_collision_count()
	if count<=0: return false
	for index: int in count:
		if not _leap_tagged_floor(result.get_collider(index)) or result.get_collision_normal(index).dot(Vector3.UP)<cos(actor.floor_max_angle): return false
	return count<32 or _leap_saturated_floor_landing(query)

func _leap_world_arc_clear(candidate: Node3D, direction: Vector3, distance: float, body: CollisionShape3D, excluded: Array[RID]) -> bool:
	var ticks:=Engine.physics_ticks_per_second
	if ticks<1 or ceili(LEAP_FLIGHT_SECONDS*float(ticks))>256: return false
	var step:=1.0/float(ticks)
	var steps:=ceili(LEAP_FLIGHT_SECONDS/step)
	var basis:=Basis(Vector3.UP,atan2(direction.x,direction.z))
	var chassis:=Transform3D(basis,actor.global_position)
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=body.shape;query.transform=chassis*body.transform
	query.collision_mask=1;query.collide_with_areas=false;query.exclude=excluded;query.margin=actor.safe_margin
	var space:=actor.get_world_3d().direct_space_state
	if not space.intersect_shape(query,1).is_empty() and not _leap_supported_start(chassis): return false
	var speed:=distance/LEAP_FLIGHT_SECONDS
	var minimum_travel:=maxf(0.0,(candidate.global_position-actor.global_position).dot(direction))+.25
	var position:=actor.global_position
	var vertical_speed:=4.0
	var gravity: float=actor.GRAVITY
	for index: int in steps:
		var elapsed:=float(index+1)*step
		vertical_speed-=gravity*step
		var motion:=direction*speed*step+Vector3.UP*vertical_speed*step
		query.transform=Transform3D(basis,position)*body.transform;query.motion=Vector3.ZERO
		# Only the launch pose may have ordinary support contact. Every later
		# segment checks overlaps too, because cast_motion omits initial overlaps.
		if index>0 and not space.intersect_shape(query,1).is_empty():
			return _leap_floor_landing(query,float(index)*step,vertical_speed<0.0,(position-actor.global_position).dot(direction),minimum_travel)
		query.motion=motion
		var fractions:=space.cast_motion(query)
		if fractions[0]<.9999:
			var fraction:=minf(1.0,float(fractions[1])+.0002/maxf(motion.length(),.001))
			query.motion=Vector3.ZERO;query.transform.origin+=motion*fraction
			return _leap_floor_landing(query,elapsed,vertical_speed<0.0,(position+motion*fraction-actor.global_position).dot(direction),minimum_travel)
		position+=motion
	return true

func _observe_leap_turn(delta: float) -> void:
	var velocity:=Vector3.ZERO
	if target is CharacterBody3D:
		velocity=target.velocity;velocity.y=0.0
		velocity=velocity.limit_length(LEAP_MAX_TARGET_SPEED)
	if velocity.length()>.5 and leap_previous_target_velocity.length()>.5:
		var angle:=leap_previous_target_velocity.signed_angle_to(velocity,Vector3.UP)
		# A sudden reversal is a new direction, not a steady circular orbit.
		if absf(angle)<.25:
			var rate:=clampf(angle/maxf(delta,.001),-LEAP_MAX_TARGET_TURN_RATE,LEAP_MAX_TARGET_TURN_RATE)
			leap_target_turn_rate=move_toward(leap_target_turn_rate,rate,delta*12.0)
		else: leap_target_turn_rate=0.0
	else: leap_target_turn_rate=0.0
	leap_previous_target_velocity=velocity

func _leap_target_displacement(velocity: Vector3, turn_rate: float, seconds: float) -> Vector3:
	# Integrate the observed horizontal turn only over this bounded wind-up/air
	# horizon. No target observation is used to steer after actual takeoff.
	if absf(turn_rate)<.05: return velocity*seconds
	var angle:=turn_rate*seconds
	return velocity*(sin(angle)/turn_rate)+Vector3.UP.cross(velocity)*((1.0-cos(angle))/turn_rate)

func _plan_leap(candidate: Node3D, load_remaining: float, reference: Vector3, target_turn_rate: float = 0.0) -> Dictionary:
	var offset:=candidate.global_position-actor.global_position;offset.y=0.0
	if offset.length()<.1 or reference.length()<.1: return {}
	var observed_velocity:=Vector3.ZERO
	if candidate is CharacterBody3D:
		observed_velocity=candidate.velocity;observed_velocity.y=0.0
		observed_velocity=observed_velocity.limit_length(LEAP_MAX_TARGET_SPEED)
	var turn_rate:=clampf(target_turn_rate,-LEAP_MAX_TARGET_TURN_RATE,LEAP_MAX_TARGET_TURN_RATE)
	var remaining:=clampf(load_remaining,0.0,LEAP_LOAD_SECONDS)
	var contact_seconds:=LEAP_LEAD_SECONDS
	var predicted:=offset
	var travel:=0.0
	var speed:=0.0
	# Solve when the native forward claws arrive, using the existing flight,
	# overshoot and speed limits rather than assuming every leap hits at .65s.
	for iteration: int in 6:
		predicted=offset+_leap_target_displacement(observed_velocity,turn_rate,remaining+contact_seconds)
		if predicted.length()<.1: return {}
		var direction:=predicted.normalized()
		travel=clampf(maxf(offset.dot(direction),predicted.length())+LEAP_OVERSHOOT,LEAP_MIN_SPEED*LEAP_FLIGHT_SECONDS,LEAP_MAX_SPEED*LEAP_FLIGHT_SECONDS)
		speed=travel/LEAP_FLIGHT_SECONDS
		contact_seconds=clampf((predicted.length()-LEAP_CONTACT_REACH)/speed,LEAP_MIN_CONTACT_SECONDS,LEAP_MAX_CONTACT_SECONDS)
	predicted=offset+_leap_target_displacement(observed_velocity,turn_rate,remaining+contact_seconds)
	if predicted.length()<.1: return {}
	var direction:=predicted.normalized()
	var yaw:=reference.signed_angle_to(direction,Vector3.UP)
	# A clamped bearing can never reach the intended interception point.
	if absf(yaw)>LEAP_MAX_AIM_YAW: return {}
	travel=clampf(maxf(offset.dot(direction),predicted.length())+LEAP_OVERSHOOT,LEAP_MIN_SPEED*LEAP_FLIGHT_SECONDS,LEAP_MAX_SPEED*LEAP_FLIGHT_SECONDS)
	speed=travel/LEAP_FLIGHT_SECONDS
	if absf(predicted.length()-(speed*contact_seconds+LEAP_CONTACT_REACH))>.30: return {}
	if not _leap_lane_clear(candidate,direction,travel): return {}
	return {"direction":direction,"travel":travel,"speed":speed,"observed_velocity":observed_velocity,"target_turn_rate":turn_rate,"contact_seconds":contact_seconds,"predicted_contact":actor.global_position+predicted,"goal":actor.global_position+direction*travel}

func _update_leap_load(delta: float, taking_off: bool = false) -> bool:
	if not target_valid(target) or actor.mobility<1.0 or not clear_sight(target):
		_finish();return false
	_observe_leap_turn(delta)
	var remaining:=maxf(0.0,LEAP_LOAD_SECONDS-float(actor.phase_time))
	var plan:=_plan_leap(target,remaining,leap_reference_direction,leap_target_turn_rate)
	if plan.is_empty(): _finish();return false
	var wanted: Vector3=plan.direction
	var yaw:=actor.global_basis.z.signed_angle_to(wanted,Vector3.UP)
	actor.turn_rate=clampf(yaw/maxf(delta,.001),-LEAP_LOAD_TURN_RATE,LEAP_LOAD_TURN_RATE)
	# Only the existing chassis turn veto may change yaw during grounded LOAD.
	actor._turn_ground(delta);actor.turn_rate=0.0
	var actual_direction: Vector3=actor.global_basis.z.normalized()
	var alignment_error:=absf(actual_direction.signed_angle_to(wanted,Vector3.UP))
	if taking_off:
		# Actor calls this before LOAD -> AIR. A blocked/unfinished turn cancels
		# instead of launching along an obsolete or physically unsafe bearing.
		if alignment_error>LEAP_TAKEOFF_YAW_TOLERANCE or not _leap_lane_clear(target,actual_direction,float(plan.travel)):
			_finish();return false
	actor.action_direction=actual_direction
	actor.bound_forward_speed=float(plan.speed)
	plan.planned_direction=wanted;plan.direction=actual_direction;plan.alignment_error=alignment_error
	plan.goal=actor.global_position+actual_direction*float(plan.travel)
	plan.committed=taking_off
	leap_plan=plan
	return true

func prepare_leap_takeoff(delta: float) -> bool:
	# Native actor owns launch timing and freezes this result into AIR velocity.
	if attack!="LeapAttack" or actor.mode!="LOAD" or actor.dead: return false
	return _update_leap_load(delta,true)

func _attack_recovered(kind: String) -> bool:
	# Only leap opportunities rearm earlier. All native recovery poses must finish
	# (try_start still requires GROUND); other attacks keep their original timers.
	var saved_fraction:=1.0-1.0/LEAP_REARM_RATE if kind=="LeapAttack" else 0.0
	var allowed_cooldown:=LEAP_NATIVE_REARM_SECONDS*saved_fraction if actor.ability=="LeapAttack" else 0.0
	return recovery<=recovery_duration*saved_fraction and actor.cooldown<=allowed_cooldown

func try_start(candidate: Node3D, kind: String = "") -> bool:
	if actor.dead or actor.mobility<=0 or actor.mode!="GROUND" or not actor.is_on_floor() or not _attack_recovered("LeapAttack") or attack!="": return false
	if not target_valid(candidate): return false
	var offset:=actor.global_basis.inverse()*(candidate.global_position-actor.global_position)
	if absf(offset.y)>.65: return false
	var distance:=Vector2(offset.x,offset.z).length()
	var planned_leap: Dictionary={}
	if kind=="":
		if distance<=1.15: kind="SlashCombo"
		elif distance>=LEAP_MIN_RANGE and distance<=LEAP_MAX_RANGE and actor.mobility>=1.0:
			planned_leap=_plan_leap(candidate,LEAP_LOAD_SECONDS,actor.global_basis.z)
			kind="LeapAttack" if not planned_leap.is_empty() else "StunShot"
		else: kind="StunShot"
	if not _attack_recovered(kind): return false
	var yaw_limit: float=STUN_MAX_YAW if kind=="StunShot" else LEAP_FACING_YAW if kind=="LeapAttack" else .28
	if absf(atan2(offset.x,offset.z))>yaw_limit: return false
	if kind!="StunShot" and not clear_sight(candidate): return false
	if kind=="SlashCombo":
		if distance>1.15 or actor.health.leg_hp.FL<=0 or actor.health.leg_hp.FR<=0: return false
	elif kind=="LeapAttack":
		if distance<LEAP_MIN_RANGE or distance>LEAP_MAX_RANGE or actor.mobility<1.0: return false
		if planned_leap.is_empty(): planned_leap=_plan_leap(candidate,LEAP_LOAD_SECONDS,actor.global_basis.z)
		if planned_leap.is_empty(): return false
	elif kind=="StunShot":
		if not _can_stun(candidate,distance) or not _stun_lane_clear(candidate): return false
	else: return false
	var pack:=actor.get_parent()
	if pack.has_method("request_attack") and not pack.request_attack(actor,candidate,kind): return false
	if kind=="SlashCombo":
		actor.mode="SLASH";actor.ability=kind;actor.velocity=Vector3.ZERO;actor.turn_rate=0
		actor.visual.begin_action()
	elif kind=="LeapAttack":
		leap_reference_direction=actor.global_basis.z.normalized();leap_plan=planned_leap
		leap_target_turn_rate=0.0
		leap_previous_target_velocity=planned_leap.observed_velocity
		actor._start_bound(kind,actor.global_basis.z)
		actor.bound_forward_speed=float(planned_leap.speed)
	else:
		# The roof mechanism owns this short stationary wind-up; legs stay posed.
		actor.mode="STUN_ATTACK";actor.ability=kind;actor.velocity=Vector3.ZERO;actor.turn_rate=0
		stun_emitter.aim_at(_stun_target_point(candidate));stun_emitter.sample_attack(0.0)
	actor.set_locomotion(0,0);target=candidate;attack=kind;elapsed=0;delivered.clear();previous_tips.clear()
	stun_moved_during_red=false
	if kind=="StunShot":
		stun_voice_cycle_id+=1
		stun_voice_lock_announced=false;stun_voice_lock_retired=false;stun_voice_check_remaining=0.0
	stun_previous_target_position=candidate.global_position
	attack_started.emit(kind)
	return true

func _sample_stun_red_movement(previous_elapsed: float) -> void:
	# Use physical displacement, not held input or vertical gravity. A blocked
	# movement key and tiny stationary floor jitter do not count as a dodge.
	var position: Vector3=target.global_position
	var movement: Vector3=position-stun_previous_target_position
	movement.y=0.0
	var red_overlap:=maxf(0.0,minf(elapsed,STUN_WINDUP)-maxf(previous_elapsed,STUN_EMITTER.RED_WARNING_SECONDS))
	if red_overlap>0.0 and not delivered.has("Stun"):
		var frame_seconds:=maxf(elapsed-previous_elapsed,.000001)
		if movement.length()*red_overlap/frame_seconds>STUN_MOVEMENT_EPSILON:
			stun_moved_during_red=true
	stun_previous_target_position=position

func _stun_miss_aim(origin: Vector3, aim: Vector3, side: float) -> Vector3:
	# Bound the actual collider's horizontal footprint, including scale/tilt.
	# Aim outside that footprint; the resulting physical ray still owns damage.
	var center:=aim
	var radius:=.65
	var collision: CollisionShape3D=target.get("body_collision") as CollisionShape3D
	if is_instance_valid(collision) and collision.shape!=null:
		center=collision.global_position
		var bounds:=collision.shape.get_debug_mesh().get_aabb()
		radius=0.0
		for x: int in 2:
			for y: int in 2:
				for z: int in 2:
					var corner: Vector3=collision.global_transform*(bounds.position+bounds.size*Vector3(x,y,z))
					radius=maxf(radius,Vector2(corner.x-center.x,corner.z-center.z).length())
	var forward:=aim-origin;forward.y=0.0
	var lateral:=Vector3(-forward.z,0.0,forward.x).normalized()*side
	var offset:=maxf(1.0,(radius+.25)*2.0)
	var miss_aim:=aim+lateral*offset
	# The aimed muzzle shifts slightly as the gun turns. Check the preview of
	# that exact raised pose rather than assuming the original muzzle stays put.
	for attempt: int in 4:
		var muzzle: Vector3=stun_emitter.preview_muzzle_position(miss_aim)
		var start:=Vector3(muzzle.x,0.0,muzzle.z)
		var end:=Vector3(miss_aim.x,0.0,miss_aim.z)
		var flat_center:=Vector3(center.x,0.0,center.z)
		var closest:=Geometry3D.get_closest_point_to_segment(flat_center,start,end)
		if closest.distance_to(flat_center)>radius+.10: return miss_aim
		offset*=2.0;miss_aim=aim+lateral*offset
	return miss_aim

func _discharge_stun() -> void:
	if delivered.has("Stun") or actor.dead: return
	var distance: float=actor.global_position.distance_to(target.global_position)
	if distance<STUN_MIN_RANGE or distance>STUN_MAX_RANGE:
		# The player can close inside the weapon's range during the telegraph.
		# Cancel before claiming a shot or consuming the pack discharge cooldown.
		_finish();return
	delivered["Stun"]=true
	if is_instance_valid(stun_voice): stun_voice.cancel_cycle(stun_voice_cycle_id)
	var pack:=actor.get_parent()
	if pack.has_method("register_stun_fire") and not pack.register_stun_fire(actor): return
	stun_cooldown=STUN_COOLDOWN
	var origin: Vector3=stun_emitter.muzzle_position()
	var aim: Vector3=_stun_target_point(target)
	# Exactly one draw per discharge, after both cooldown gates accept it.
	var miss_chance:=clampf((STUN_MOVING_MISS_CHANCE if stun_moved_during_red else 0.0)+STUN_EXTRA_MISS_CHANCE,0.0,1.0)
	var miss_roll:=randf()
	var intentional_miss:=miss_roll<miss_chance
	if intentional_miss:
		var side: float=-1.0 if miss_roll<miss_chance*.5 else 1.0
		aim=_stun_miss_aim(origin,aim,side)
		stun_emitter.aim_at(aim);stun_emitter.sample_attack(elapsed)
		origin=stun_emitter.muzzle_position()
	var direction: Vector3=(aim-origin).normalized()
	var endpoint: Vector3=origin+direction*STUN_MAX_RANGE
	# Recheck the actual raised muzzle at discharge. The closest collider wins:
	# world cover, other robots and physical corpses can all intercept the shot.
	var query:=PhysicsRayQueryParameters3D.create(origin,endpoint,1|2|8)
	query.exclude=[actor.get_rid()];query.hit_from_inside=true
	var hit: Dictionary=actor.get_world_3d().direct_space_state.intersect_ray(query)
	var visible_end: Vector3=hit.get("position",endpoint)
	var hit_target: bool=not hit.is_empty() and hit.collider==target
	var applied := false
	var damage := 0.0
	if hit_target:
		target.take_damage(STUN_DAMAGE);damage=STUN_DAMAGE
		if target_valid(target): applied=bool(target.apply_drone_stun(STUN_DURATION))
	stun_emitter.fire_visual(visible_end)
	var collider_path := "" if hit.is_empty() else str((hit.collider as Node).get_path())
	stun_shot_log.append({"attack":"StunShot","elapsed":elapsed,"origin":origin,"endpoint":visible_end,"target_hit":hit_target,"applied":applied,"damage":damage,"collider_path":collider_path,"mask":query.collision_mask,"duration":STUN_DURATION,"moved_during_red":stun_moved_during_red,"miss_chance":miss_chance,"miss_roll":miss_roll,"intentional_miss":intentional_miss,"aim":aim})
	if stun_shot_log.size()>32: stun_shot_log.pop_front()
	if hit_target:
		hit_log.append({"attack":"StunShot","strike":"Stun","damage":damage,"duration":STUN_DURATION,"applied":applied})
		hit_landed.emit("Stun",damage)
	stun_discharged.emit(applied,origin,visible_end)

func tip(leg: String) -> Vector3:
	var skeleton: Skeleton3D=actor.visual.skeleton
	var bone:=skeleton.find_bone(leg+"_Foot")
	var pose:=skeleton.get_bone_global_pose(bone)
	# Foot bone's local +Y points along the short claw/toe.
	return skeleton.to_global(pose.origin+pose.basis.y.normalized()*.10)

func _contact(leg: String) -> bool:
	var current:=tip(leg)
	var previous: Vector3=previous_tips.get(leg,current)
	previous_tips[leg]=current
	if not target_valid(target): return false
	# Swept claw segment against a standing-player capsule, default 0.28 m radius.
	# Host player can expose combat_capsule_radius/height for its actual dimensions.
	var body_radius:=float(target.get_meta("combat_capsule_radius",.28))
	var radius:=body_radius+.13
	var height:=float(target.get_meta("combat_capsule_height",1.75))
	var center:=float(target.get_meta("combat_capsule_center_y",height*.5))
	var half_segment:=maxf(0,height*.5-body_radius)
	var bottom:=target.global_position+Vector3.UP*(center-half_segment)
	var top:=target.global_position+Vector3.UP*(center+half_segment)
	var closest:=Geometry3D.get_closest_points_between_segments(previous,current,bottom,top)
	return closest[0].distance_to(closest[1])<=radius and clear_sight(target)

func _strike(key: String, damage: float, legs: Array[String]) -> void:
	if delivered.has(key) or actor.dead: return
	for leg in legs:
		if actor.health.leg_hp[leg]<=0: continue
		if _contact(leg):
			# Consume the contact before the eligibility check or random trial:
			# another claw/frame cannot roll again or deal a second leap hit.
			delivered[key]=true
			var victim: Node3D=target
			var hit_attack:=attack
			var applied_damage:=damage
			var eligible: bool=hit_attack=="LeapAttack" and key=="Leap" and actor.mode=="AIR" and actor.has_method("try_attach_to_player") and victim.has_method("can_accept_face_drone")
			if eligible: eligible=bool(victim.call("can_accept_face_drone"))
			var attachment_roll: float=-1.0
			var face_attached:=false
			if eligible:
				attachment_roll=randf()
				if attachment_roll<LEAP_FACE_ATTACH_CHANCE:
					# The actor/player transaction must fully rollback before false.
					face_attached=bool(actor.call("try_attach_to_player",victim))
			if face_attached:
				applied_damage=LEAP_FACE_ATTACH_DAMAGE
				_retire_leap_for_face_attachment()
			# Exactly one initial damage call. The player helper alone owns later
			# two-HP ticks; accepted attachment replaces the normal eighteen HP.
			victim.take_damage(applied_damage)
			var entry: Dictionary={"attack":hit_attack,"strike":key,"damage":applied_damage}
			if hit_attack=="LeapAttack":
				entry.attachment_eligible=eligible;entry.attachment_roll=attachment_roll;entry.face_attached=face_attached
			hit_log.append(entry)
			hit_landed.emit(key,applied_damage)
			return

func _retire_leap_for_face_attachment() -> void:
	# Physical attachment/release belongs to the actor. Normal _finish would
	# overwrite FACE_ATTACHED with RECOVER and move the attached robot.
	var finished:=attack
	attack="";target=null;previous_tips.clear()
	stun_moved_during_red=false;stun_previous_target_position=Vector3.ZERO
	leap_previous_target_velocity=Vector3.ZERO;leap_target_turn_rate=0.0
	recovery=1.0;recovery_duration=recovery
	var pack:=actor.get_parent()
	if pack.has_method("attack_finished_by"): pack.attack_finished_by(actor)
	attack_finished.emit(finished)

func _finish() -> void:
	if attack=="StunShot" and is_instance_valid(stun_voice): stun_voice.cancel_cycle(stun_voice_cycle_id)
	var finished:=attack;attack="";target=null;previous_tips.clear()
	stun_moved_during_red=false;stun_previous_target_position=Vector3.ZERO
	recovery=1.0 if finished=="LeapAttack" else 1.4
	recovery_duration=recovery
	if finished=="StunShot" and is_instance_valid(stun_emitter):
		if actor.dead: stun_emitter.shutdown()
		else: stun_emitter.cancel_attack()
	var pack:=actor.get_parent()
	if pack.has_method("attack_finished_by"): pack.attack_finished_by(actor)
	if not actor.dead:
		actor.mode="GROUND" if finished=="StunShot" else "RECOVER"
		actor.velocity=Vector3.ZERO;actor.turn_rate=0
		actor.set_locomotion(0,0)
		if finished!="StunShot": actor.visual.begin_recovery()
	attack_finished.emit(finished)

func _physics_process(delta: float) -> void:
	recovery=maxf(0,recovery-delta)
	stun_cooldown=maxf(0,stun_cooldown-delta)
	if actor.mode=="RECOVER" and not actor.dead:
		actor.velocity=Vector3(0,actor.velocity.y-actor.GRAVITY*delta,0);actor.move_and_slide()
		if actor.visual.recover(delta): actor.mode="GROUND"
		actor._update_leg_hitboxes()
		return
	if attack=="": return
	if actor.dead:
		_finish();return
	var previous_elapsed:=elapsed
	elapsed+=delta
	if attack=="StunShot":
		if not target_valid(target): _finish();return
		_sample_stun_red_movement(previous_elapsed)
		actor.velocity=Vector3(0,actor.velocity.y-actor.GRAVITY*delta,0);actor.move_and_slide()
		actor.visual.drive(delta,Vector3.ZERO,0.0,true)
		stun_emitter.aim_at(_stun_target_point(target));stun_emitter.sample_attack(elapsed)
		_update_stun_lock_voice(delta)
		actor._update_leg_hitboxes()
		if elapsed>=STUN_WINDUP: _discharge_stun()
		if attack=="StunShot" and elapsed>=STUN_ATTACK_SECONDS: _finish()
	elif attack=="SlashCombo":
		actor.velocity=Vector3(0,actor.velocity.y-actor.GRAVITY*delta,0);actor.move_and_slide()
		actor.visual.sample_action("SlashCombo",elapsed)
		if elapsed>=.28 and elapsed<=.53: _strike("Slash1",SLASH_DAMAGE,["FL"])
		if elapsed>=.90 and elapsed<=1.16: _strike("Slash2",SLASH_DAMAGE,["FR"])
		actor._update_leg_hitboxes()
		if elapsed>=1.4:
			actor.cooldown=.3
			_finish()
	elif attack=="LeapAttack":
		if actor.mode=="LOAD": _update_leap_load(delta)
		if actor.mode=="AIR" and actor.air_time>=.28 and actor.air_time<=.78:
			_strike("Leap",LEAP_DAMAGE,["FL","FR"])
		if attack=="LeapAttack" and actor.mode=="GROUND": _finish()
	# Refresh outside hit windows too: never sweep a claw from an old wind-up pose.
	for leg in ["FL","FR"]: previous_tips[leg]=tip(leg)
