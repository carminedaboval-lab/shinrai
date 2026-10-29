extends Node
## Physical lifecycle only. Combat owns the initial hit; the player owns escape/DOT.
const WORLD_MASK := 1 | 2 | 8
const MAX_LATCH_DISTANCE := 2.25
const MAX_FOLLOW_STEP := 1.5
const FACE_DISTANCE := .95
var actor
var host_ref: WeakRef
var host_rid := RID()
var state := "idle"
var saved: Dictionary = {}
var release_wait := 0.0
var pending_ragdoll: Dictionary = {}
var exiting := false

func setup(owner_actor: CharacterBody3D) -> void:
	actor=owner_actor
	process_physics_priority=2
	set_physics_process(false)

func _host() -> Node3D:
	if host_ref==null: return null
	return host_ref.get_ref() as Node3D

func _exclusions(include_host: bool = false) -> Array[RID]:
	var result: Array[RID]=[actor.get_rid()]
	if not include_host and host_rid.is_valid(): result.append(host_rid)
	return result

func _face_pose(anchor: Node3D) -> Transform3D:
	var facing:=anchor.global_basis.z
	facing.y=0.0
	if facing.length_squared()<.001: facing=actor.global_basis.z
	var basis:=Basis.looking_at(-facing.normalized(),Vector3.UP)
	var center:=anchor.global_position-anchor.global_basis.z.normalized()*FACE_DISTANCE-Vector3.UP*.10
	return Transform3D(basis,center-basis*actor.collider.position)

func _query(pose: Transform3D, include_host: bool, margin: float = .006) -> PhysicsShapeQueryParameters3D:
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=actor.collider.shape
	query.transform=pose*actor.collider.transform
	query.collision_mask=WORLD_MASK
	query.exclude=_exclusions(include_host)
	query.collide_with_areas=false
	query.collide_with_bodies=true
	query.margin=margin
	return query

func _pose_clear(pose: Transform3D, include_host: bool) -> bool:
	return actor.get_world_3d().direct_space_state.intersect_shape(_query(pose,include_host),1).is_empty()

func _path_clear(from: Transform3D, to: Transform3D, include_host: bool = false) -> bool:
	# cast_motion alone ignores rotation. Inflate each short swept interval by
	# its corner arc and check the start as well, including initial overlaps.
	var angle:=from.basis.get_rotation_quaternion().angle_to(to.basis.get_rotation_quaternion())
	var steps:=maxi(1,maxi(ceili(from.origin.distance_to(to.origin)/.12),ceili(angle/.08)))
	if steps>40: return false
	var size: Vector3=(actor.collider.shape as BoxShape3D).size
	var corner_radius:=size.length()*.5
	var space: PhysicsDirectSpaceState3D=actor.get_world_3d().direct_space_state
	for index: int in steps:
		var start:=from.interpolate_with(to,float(index)/steps)
		var finish:=from.interpolate_with(to,float(index+1)/steps)
		var margin: float=.006+(corner_radius+actor.collider.position.length())*angle/steps
		var query:=_query(start,include_host,margin)
		if not space.intersect_shape(query,1).is_empty(): return false
		query.motion=(finish*actor.collider.transform).origin-query.transform.origin
		if query.motion.length_squared()>.000001:
			var travel:=space.cast_motion(query)
			if travel.size()!=2 or travel[0]<.9999: return false
		if not space.intersect_shape(_query(finish,include_host,margin),1).is_empty(): return false
	return true

func try_attach(candidate: Node3D) -> bool:
	if state!="idle" or actor.dead or actor.mode!="AIR" or actor.ability!="LeapAttack": return false
	if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not candidate is PhysicsBody3D: return false
	for method: String in ["can_accept_face_drone","begin_face_drone","release_face_drone","is_face_drone_attached_to","get_face_drone_anchor"]:
		if not candidate.has_method(method): return false
	if not bool(candidate.call("can_accept_face_drone")): return false
	var anchor:=candidate.call("get_face_drone_anchor") as Node3D
	if not is_instance_valid(anchor) or not anchor.is_inside_tree(): return false
	host_rid=(candidate as PhysicsBody3D).get_rid()
	var pose:=_face_pose(anchor)
	if actor.global_position.distance_to(pose.origin)>MAX_LATCH_DISTANCE or not _path_clear(actor.global_transform,pose):
		host_rid=RID();return false
	var brain: Node=actor.get_node_or_null("Awareness")
	saved={"pose":actor.global_transform,"mode":actor.mode,"velocity":actor.velocity,"turn":actor.turn_rate,"speed":actor.desired_speed,"strafe":actor.desired_strafe,"desired_turn":actor.desired_turn,"layer":actor.collision_layer,"mask":actor.collision_mask,"physics":actor.is_physics_processing(),"brain_physics":brain!=null and brain.is_physics_processing()}
	host_ref=weakref(candidate)
	state="prepared"
	# Register everything before the player callback: synchronous cleanup is safe.
	actor.mode="FACE_ATTACHED";actor.velocity=Vector3.ZERO;actor.turn_rate=0.0
	actor.set_locomotion(0,0)
	actor.collision_layer=0;actor.collision_mask=0
	actor.set_physics_process(false)
	if brain!=null: brain.set_physics_process(false)
	var accepted:=bool(candidate.call("begin_face_drone",actor,Callable(actor,"release_face_attachment")))
	if not accepted:
		if state=="prepared": _rollback()
		return false
	if state!="prepared" or not bool(candidate.call("is_face_drone_attached_to",actor)):
		release("begin_cancelled");return false
	actor.global_transform=pose
	actor.ground_acceleration=Vector3.ZERO
	actor.nav_path.clear();actor.nav_escape_point=Vector3.INF;actor.nav_detour_points=0
	actor.nav_status="face_attached";actor.nav_refresh=0.0
	state="attached"
	actor._update_leg_hitboxes()
	set_physics_process(true)
	return true

func _rollback() -> void:
	actor.global_transform=saved.pose;actor.mode=saved.mode;actor.velocity=saved.velocity
	actor.turn_rate=saved.turn;actor.desired_speed=saved.speed
	actor.desired_strafe=saved.strafe;actor.desired_turn=saved.desired_turn
	actor.collision_layer=saved.layer;actor.collision_mask=saved.mask
	actor.set_physics_process(bool(saved.physics))
	var brain: Node=actor.get_node_or_null("Awareness")
	if brain!=null: brain.set_physics_process(bool(saved.brain_physics))
	_forget()

func _drop_pose() -> Dictionary:
	var current: Transform3D=actor.global_transform
	if _pose_clear(current,true): return {"pose":current}
	# Only nearby, swept exits. Never move through a wall to find a free endpoint.
	for distance: float in [.45,.90,1.35]:
		for direction: Vector3 in [-current.basis.z,current.basis.x,-current.basis.x,(-current.basis.z+current.basis.x).normalized(),(-current.basis.z-current.basis.x).normalized(),current.basis.z]:
			var pose:=Transform3D(current.basis,current.origin+direction*distance)
			if _pose_clear(pose,true) and _path_clear(current,pose): return {"pose":pose}
	return {}

func release(reason: String) -> void:
	if state=="idle" or state=="releasing" or state=="release_pending": return
	state="releasing"
	var host:=_host()
	if is_instance_valid(host) and host.has_method("release_face_drone"):
		host.call("release_face_drone",actor,reason)
	if exiting or not actor.is_inside_tree():
		actor.collision_layer=saved.layer;actor.collision_mask=saved.mask
		_forget();return
	var drop:=_drop_pose()
	if drop.is_empty():
		# Escape always ends player damage/input capture. If a moving solid has
		# occupied the drop space, retry with the motor stopped until it clears.
		state="release_pending";actor.mode="FACE_RELEASE_PENDING"
		release_wait=.15;set_physics_process(true);return
	_complete_release(drop.pose)

func _complete_release(pose: Transform3D) -> void:
	actor.global_transform=pose
	actor.collision_layer=saved.layer;actor.collision_mask=saved.mask
	actor.velocity=Vector3.ZERO;actor.turn_rate=0.0;actor.ground_acceleration=Vector3.ZERO
	actor.set_locomotion(0,0)
	actor.nav_path.clear();actor.nav_refresh=0.0;actor.nav_status="released"
	if not actor.dead:
		actor.mode="GROUND";actor.ability="";actor.phase_time=0.0
		actor.cooldown=maxf(actor.cooldown,1.2)
		actor.visual.player.stop(true);actor.visual.reset_contacts()
		actor.set_physics_process(bool(saved.physics))
		var brain: Node=actor.get_node_or_null("Awareness")
		if brain!=null: brain.set_physics_process(bool(saved.brain_physics))
	else: actor.mode="DISABLED"
	actor._update_leg_hitboxes()
	var ragdoll_request:=pending_ragdoll.duplicate()
	_forget()
	if not ragdoll_request.is_empty(): actor._begin_ragdoll.call_deferred(ragdoll_request.velocity,ragdoll_request.rotation)

func defer_ragdoll(death_velocity: Vector3, death_rotation: Vector3) -> bool:
	if state!="release_pending": return false
	pending_ragdoll={"velocity":death_velocity,"rotation":death_rotation}
	return true

func _forget() -> void:
	state="idle";host_ref=null;host_rid=RID();saved.clear();pending_ragdoll.clear()
	set_physics_process(false)

func cleanup() -> void:
	exiting=true
	if state=="release_pending":
		actor.collision_layer=saved.layer;actor.collision_mask=saved.mask
		_forget()
	else: release("scene_exit")

func _physics_process(delta: float) -> void:
	if state=="release_pending":
		release_wait-=delta
		if release_wait<=0.0:
			release_wait=.15
			var drop:=_drop_pose()
			if not drop.is_empty(): _complete_release(drop.pose)
		return
	if state!="attached": return
	var host:=_host()
	if actor.dead or not is_instance_valid(host) or not host.is_inside_tree() or host.is_queued_for_deletion():
		release("invalid_host");return
	if not bool(host.call("is_face_drone_attached_to",actor)):
		release("player_released");return
	var anchor:=host.call("get_face_drone_anchor") as Node3D
	if not is_instance_valid(anchor) or not anchor.is_inside_tree():
		release("invalid_anchor");return
	var pose:=_face_pose(anchor)
	if actor.global_position.distance_to(pose.origin)>MAX_FOLLOW_STEP or not _path_clear(actor.global_transform,pose):
		release("blocked_follow");return
	actor.global_transform=pose
	actor._update_leg_hitboxes()

func _exit_tree() -> void:
	if is_instance_valid(actor): cleanup()
