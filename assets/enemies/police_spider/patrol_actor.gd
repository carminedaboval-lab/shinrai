extends CharacterBody3D
## Reusable traversal actor. AI can call set_locomotion, react_to_threat,
## try_dodge, try_leap and try_climb; the review supplies test commands.
signal ability_started(ability: String)
signal ability_finished(ability: String)
var visual: Node3D
var police_lights: Node3D
var scan_beam: Node3D
var damage_fx: Node3D
var combat: Node
var face_attachment: Node
var health: Node
var leg_hitboxes: Dictionary = {}
var core_hitbox: Area3D
var core_collision: CollisionShape3D
var ragdoll: Node
var dead := false
var fault_effects: Dictionary = {}
var mobility := 1.0
# Lost legs set a gait of their own: lurching on three, a crawl on two.
var cripple = preload("patrol_cripple.gd").new()
var bound_forward_speed := 3.0
var collider: CollisionShape3D
var mode := "GROUND"
var ability := ""
var phase_time := 0.0
var cooldown := 0.0
var desired_speed := 0.0
var desired_turn := 0.0
var desired_strafe := 0.0
var turn_rate := 0.0
var action_direction := Vector3.ZERO
var air_time := 0.0
var climb_input := 0.0
var wall_normal := Vector3.ZERO
var attach_start := Vector3.ZERO
var attach_end := Vector3.ZERO
var attach_basis := Basis.IDENTITY
var wall_basis := Basis.IDENTITY
var accepted: Dictionary = {}
var blocked_attempts := 0
var navigation_source: Node
var nav_path := PackedVector3Array()
var nav_goal := Vector3.INF
var nav_refresh := 0.0
var nav_endpoint := Vector3.INF
var nav_status := "idle"
var nav_query: PhysicsShapeQueryParameters3D
var nav_turn_shape: CylinderShape3D
var nav_query_source: Node
var nav_progress_anchor := Vector3.INF
var nav_progress_yaw := 0.0
var nav_stall_time := 0.0
var nav_replan_wait := 0.0
var nav_recovery_pending := false
var nav_stall_replans := 0
var obstacle_routes = preload("patrol_obstacle_routes.gd").new()
var nav_command_frame := -10
var nav_detour_points := 0
var nav_escape_point := Vector3.INF
var nav_escape_check := 0.0
var last_attacker: Node
var ground_acceleration := Vector3.ZERO
var turn_collision := KinematicCollision3D.new()
var ground_step_wait := 0.0
var ground_turn_step_wait := 0.0
var ground_step_query: PhysicsShapeQueryParameters3D
var ground_step_attempts := 0
var ground_step_successes := 0
var ground_step_success_frame := -1
var hops := 0
var hop_retry_at := 0
const GRAVITY := 9.81
const GROUND_SPEED_SCALE := 3.4 # Previous 2x ground speed, increased by another 1.7x.
const GROUND_STEP_HEIGHT := .06
const GROUND_STEP_MARGIN := .001
const COMBAT_TURN_RATE := 5.4
# A hunting drone runs down a sprinting player (6.65 m/s) instead of trailing it.
const COMBAT_SPRINT := 2.1
# A legged chassis hops a kerb or low step that its rolling ground motor cannot climb.
const HOP_CLEARANCE := .70
const HOP_REACH := 2.3
const HOP_MAX_RISE := .60
const HOP_MAX_DROP := 1.2
const COMBAT_TURN_ACCELERATION := 15.0
const COMBAT_MOTOR_TORQUE := 20.0

func _ready() -> void:
	collision_layer=2;collision_mask=1|2
	collider=CollisionShape3D.new()
	var shape:=BoxShape3D.new();shape.size=Vector3(1.40,.74,1.0)
	collider.shape=shape;collider.position.y=.38;add_child(collider)
	visual=Node3D.new();visual.set_script(preload("patrol_motion.gd"));add_child(visual)
	visual.gait_speed_scale=GROUND_SPEED_SCALE
	police_lights=Node3D.new();police_lights.name="PoliceLights"
	police_lights.set_script(preload("patrol_police_lights.gd"));police_lights.visual=visual;add_child(police_lights)
	health=Node.new();health.name="LegHealth";health.set_script(preload("patrol_health.gd"));add_child(health)
	health.destroyed.connect(_on_destroyed)
	health.leg_destroyed.connect(_on_leg_destroyed)
	_create_leg_hitboxes()
	_create_core_hitbox()
	combat=Node.new();combat.name="Combat";combat.set_script(preload("patrol_combat.gd"));add_child(combat)
	combat.attack_started.connect(func(_kind: String) -> void: police_lights.flash_attack())
	scan_beam=Node3D.new();scan_beam.name="ScanBeam"
	scan_beam.set_script(preload("patrol_scan_beam.gd"));scan_beam.actor=self;police_lights.add_child(scan_beam)
	damage_fx=Node3D.new();damage_fx.name="DamageFX"
	damage_fx.set_script(preload("patrol_damage_fx.gd"));police_lights.add_child(damage_fx)
	damage_fx.bind(health,police_lights)
	face_attachment=preload("patrol_face_attachment.gd").new();face_attachment.name="FaceAttachment"
	add_child(face_attachment);face_attachment.setup(self)
	floor_snap_length=.12

func try_attach_to_player(candidate: Node3D) -> bool:
	return face_attachment.try_attach(candidate)

func release_face_attachment(reason: String = "external") -> void:
	if is_instance_valid(face_attachment): face_attachment.release(reason)

func damage_leg(leg: String, amount: float, source: Node = null) -> float:
	var applied: float=health.damage_leg(leg,amount)
	if applied>0.0: _react_to_damage(source)
	return applied

func take_damage(amount: float, _source: Node = null) -> void:
	if is_instance_valid(_source): last_attacker=_source
	var applied: float=health.damage_body(amount)
	if applied>0.0: _react_to_damage(_source)

func _react_to_damage(source: Node) -> void:
	if dead: return
	var brain:=get_node_or_null("Awareness")
	if brain!=null: brain.receive_damage_contact(source)
	# Every hit visibly lands: the chassis jolts away and the motors falter.
	var from:=global_position-global_basis.z*randf_range(-1.0,1.0)+global_basis.x*randf_range(-1.0,1.0)
	if is_instance_valid(source) and source is Node3D and source!=self: from=(source as Node3D).global_position
	var away:=global_basis.inverse()*(global_position-from);away.y=0.0
	visual.add_hit_reaction(away.normalized())
	stagger_time=STAGGER_SECONDS
	var pack:=get_parent()
	if pack.has_method("consider_withdrawal"): pack.consider_withdrawal(self)
	# Under fire in a fight a drone sometimes throws itself aside.
	if brain==null or brain.state not in ["COMBAT_ENTER","COMBAT"] or combat.attack!="": return
	var now:=Time.get_ticks_msec()
	if now<dodge_ready_at or randf()>dodge_chance: return
	dodge_ready_at=now+int(randf_range(DODGE_COOLDOWN_MIN,DODGE_COOLDOWN_MAX)*1000.0)
	react_to_threat(from)

func _on_leg_destroyed(leg: String) -> void:
	visual.faults[leg]=true
	mobility=float(health.intact_legs())/4.0
	cripple.configure(visual.faults.keys())
	visual.cripple=cripple
	# Losing a leg mid-stride can put it straight down.
	if cripple.stumble_chance>0.0 and Vector2(velocity.x,velocity.z).length()>1.5 and not cripple.stumbling():
		cripple.stumble_duration=randf_range(cripple.STUMBLE_MIN,cripple.STUMBLE_MAX);cripple.stumble_time=cripple.stumble_duration
		cripple.stumbles+=1
	var effect:=Node3D.new();effect.set_script(preload("patrol_leg_fault.gd"))
	effect.set("actor",self);effect.set("leg",leg);add_child(effect)
	fault_effects[leg]=effect

func _on_destroyed() -> void:
	if dead: return
	var death_velocity := velocity
	var death_rotation := global_basis.y * turn_rate
	dead=true;mode="DISABLED"
	release_face_attachment("drone_death")
	police_lights.set_alert_state("DISABLED")
	set_locomotion(0,0);turn_rate=0
	nav_path.clear();nav_status="disabled";navigation_source=null
	ground_acceleration=Vector3.ZERO
	if combat.attack!="": combat._finish()
	combat.set_physics_process(false)
	var brain := get_node_or_null("Awareness")
	if brain!=null:
		brain.enabled=false;brain.set_physics_process(false)
	visual.player.stop(true)
	set_physics_process(false)
	for effect: Node in fault_effects.values(): effect.queue_free()
	fault_effects.clear()
	if is_instance_valid(last_attacker) and last_attacker.has_method("notify_kill"): last_attacker.notify_kill()
	last_attacker=null
	var pack:=get_parent()
	if pack.has_method("report_member_down"): pack.report_member_down(self)
	_begin_ragdoll.call_deferred(death_velocity,death_rotation)

func _create_core_hitbox() -> void:
	var shape: Shape3D = preload("patrol_damage_shape.gd").from_visual(visual)
	if shape==null: return
	core_hitbox=Area3D.new();core_hitbox.name="HitCore"
	core_hitbox.set_script(preload("patrol_leg_hitbox.gd"));core_hitbox.actor=self
	core_hitbox.collision_layer=4;core_hitbox.collision_mask=0;core_hitbox.monitoring=false
	core_collision=CollisionShape3D.new();core_collision.shape=shape
	core_hitbox.add_child(core_collision);add_child(core_hitbox)
	add_to_group("weapon_proxy_bodies")
	_update_leg_hitboxes()

func _begin_ragdoll(death_velocity: Vector3, death_rotation: Vector3) -> void:
	if is_instance_valid(face_attachment) and face_attachment.defer_ragdoll(death_velocity,death_rotation): return
	# Retire weapon and movement proxies before giving physics the skeleton.
	if not is_instance_valid(core_collision):
		push_error("Police drone ragdoll has no fitted core collision")
		queue_free();return
	var core_transform := global_transform.affine_inverse()*core_collision.global_transform
	var core_shape: Shape3D = core_collision.shape
	collision_layer=0;collision_mask=0;collider.disabled=true
	remove_from_group("weapon_proxy_bodies")
	core_hitbox.collision_layer=0;core_hitbox.queue_free()
	for pieces: Array in leg_hitboxes.values():
		var area := pieces[0].get_parent() as Area3D
		area.collision_layer=0;area.queue_free()
	leg_hitboxes.clear()
	ragdoll=preload("patrol_ragdoll.gd").new();add_child(ragdoll)
	if not ragdoll.start(self,core_shape,core_transform,death_velocity,death_rotation):
		push_error("Police drone ragdoll failed: "+str(ragdoll.failure_reason))
		var expiry:=Timer.new();expiry.one_shot=true
		expiry.wait_time=preload("patrol_ragdoll.gd").CORPSE_SECONDS
		add_child(expiry);expiry.timeout.connect(queue_free);expiry.start()
	else:
		# Physical bones own the corpse pose; attachments follow their bodies.
		# Sampling Skeleton3D outside the modifier callback can see its input pose.
		police_lights.set_process(false)
		for leg: String in police_lights.leg_markers:
			police_lights.leg_markers[leg].node.reparent(ragdoll.bodies_by_bone[leg+"_Lower"],true)
		police_lights.reparent(ragdoll.bodies_by_bone["Body"],true)
	velocity=Vector3.ZERO

func _exit_tree() -> void:
	if is_instance_valid(face_attachment): face_attachment.cleanup()
	# A corpse may expire while its pack remains alive. Release every pack
	# reference without changing the living formation/attack controller.
	var pack:=get_parent()
	if is_instance_valid(pack) and pack.has_method("living_members"):
		pack.attack_finished_by(self)
		pack.members.erase(self);pack.attack_queue.erase(self)
		for key: String in ["slots","request_age","wanderers","wander_cooldowns","returning_members","withdrawals","withdrawn"]:
			var state: Dictionary=pack.get(key)
			state.erase(self)
		if pack.leader==self: pack.leader=null
		if pack.last_attacker==self: pack.last_attacker=null
	last_attacker=null

func _create_leg_hitboxes() -> void:
	for leg: Dictionary in visual.legs:
		var area:=Area3D.new();area.name="Hit"+str(leg.name)
		area.set_script(preload("patrol_leg_hitbox.gd"));area.actor=self;area.leg=leg.name
		area.collision_layer=4;area.collision_mask=0;area.monitoring=false
		var pieces: Array[CollisionShape3D]=[]
		for i in [0,1]:
			var radii: Vector2=preload("patrol_ragdoll.gd").LIMB_RADII[leg.name]
			var capsule:=CapsuleShape3D.new();capsule.radius=radii[i]
			capsule.height=(visual.rest[leg.ids[i]] as Transform3D).origin.distance_to((visual.rest[leg.ids[i+1]] as Transform3D).origin)+capsule.radius*2.0
			var collision:=CollisionShape3D.new();collision.shape=capsule;area.add_child(collision);pieces.append(collision)
		var foot_bounds: Array=preload("patrol_ragdoll.gd").FOOT_BOUNDS[leg.name]
		var foot_shape:=BoxShape3D.new();foot_shape.size=foot_bounds[1]
		var foot_collision:=CollisionShape3D.new();foot_collision.shape=foot_shape
		area.add_child(foot_collision);pieces.append(foot_collision)
		add_child(area);leg_hitboxes[leg.name]=pieces
	_update_leg_hitboxes()

func _update_leg_hitboxes() -> void:
	if dead: return
	if core_collision!=null:
		var body_id: int = visual.skeleton.find_bone("Body")
		core_collision.global_transform=visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(body_id)*visual.skeleton.get_bone_global_rest(body_id).affine_inverse()*preload("patrol_damage_shape.gd").core_rest_transform
	for leg: Dictionary in visual.legs:
		if fault_effects.has(leg.name):
			fault_effects[leg.name].global_position=visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(leg.ids[1]).origin)
		for i in [0,1]:
			var a: Vector3=visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(leg.ids[i]).origin)
			var b: Vector3=visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(leg.ids[i+1]).origin)
			var collision: CollisionShape3D=leg_hitboxes[leg.name][i]
			collision.global_transform=Transform3D(Basis(Quaternion(Vector3.UP,(b-a).normalized())),(a+b)*.5)
		var foot_bounds: Array=preload("patrol_ragdoll.gd").FOOT_BOUNDS[leg.name]
		var foot_collision: CollisionShape3D=leg_hitboxes[leg.name][2]
		foot_collision.global_transform=visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(leg.ids[2])*Transform3D(Basis.IDENTITY,foot_bounds[0])

func _combat_motor_active() -> bool:
	var brain:=get_node_or_null("Awareness")
	return brain!=null and brain.enabled and brain.state=="COMBAT"

func set_area_scan(active: bool) -> void:
	visual.area_scan=active
	scan_beam.area_scan=active

func set_locomotion(speed: float, turn: float) -> void:
	if dead: speed=0;turn=0
	# AI and formation commands retain their baseline units; scale exactly once.
	var combat_motor:=_combat_motor_active()
	var turn_limit: float=COMBAT_TURN_RATE if combat_motor else 1.8
	desired_speed=clampf(speed,-.44,COMBAT_SPRINT if combat_motor else 1.55)*GROUND_SPEED_SCALE;desired_turn=clampf(turn,-turn_limit,turn_limit)
	desired_strafe=0.0

func is_in_combat_with(candidate: Node) -> bool:
	var brain:=get_node_or_null("Awareness")
	return not dead and brain!=null and brain.target==candidate and brain.state in ["COMBAT_ENTER","COMBAT"]

func hear_noise(point: Vector3, radius: float) -> void:
	if dead or global_position.distance_to(point)>radius: return
	var brain:=get_node_or_null("Awareness")
	if brain!=null and brain.state in ["PATROL","RELAX"]:
		brain.last_known=point;brain.change_state("SEARCH")

## Route planning is the drones' biggest CPU cost. Calm patrols re-check less
## often and share a per-tick time budget so they cannot stack on one frame.
## Alerted and dispatched drones are exempt and still replan immediately.
const PATROL_REPLAN_SECONDS := 4.0
const SEARCH_REPLAN_SECONDS := 1.5 # A search leg heads for a fixed point.
const PATROL_RETARGET_GAP := 1.0
const PATROL_BLOCKED_RETRY_SECONDS := 1.2
const PATROL_BLOCKED_RETRY_MAX := 8.0
const ALERT_BLOCKED_RETRY_MAX := 2.0
const NAV_LINK_RETRY_MSEC := 250
const PATROL_PLAN_BUDGET_USEC := 3000
static var _plan_frame := -1
static var _plan_spent_usec := 0
var nav_retarget_gap := 0.0
var nav_urgent := false
var nav_turn_vetoed := false
var nav_link_retry_at := 0
const STAGGER_SECONDS := .22
const DODGE_COOLDOWN_MIN := 4.0
const DODGE_COOLDOWN_MAX := 7.0
var stagger_time := 0.0
var dodge_chance := .4
var dodge_ready_at := 0
var nav_block_streak := 0
var nav_block_until := 0
var nav_block_pos := Vector3.INF
var nav_block_goal := Vector3.INF
var nav_best_aim := INF
var nav_aim_point := Vector3.INF

func planning_budget_left() -> bool:
	var frame:=Engine.get_physics_frames()
	if frame!=_plan_frame:
		_plan_frame=frame;_plan_spent_usec=0
	return _plan_spent_usec<PATROL_PLAN_BUDGET_USEC

func _is_calm_patrol() -> bool:
	return visual!=null and visual.expression=="PATROL" and not nav_urgent

func _note_blocked_plan(goal: Vector3) -> void:
	# The same pose and goal fail the same way, so retry a stuck drone less and less.
	if nav_block_pos.is_finite() and global_position.distance_to(nav_block_pos)<1.0 and nav_block_goal.distance_to(goal)<3.0:
		nav_block_streak+=1
	else: nav_block_streak=1
	nav_block_pos=global_position;nav_block_goal=goal
	var limit:=PATROL_BLOCKED_RETRY_MAX if _is_calm_patrol() else ALERT_BLOCKED_RETRY_MAX
	var wait:=minf(PATROL_BLOCKED_RETRY_SECONDS*pow(2.0,nav_block_streak-1),limit)+randf()*.5
	nav_block_until=Time.get_ticks_msec()+int(wait*1000.0)
	nav_refresh=wait

func _block_wait_active() -> bool:
	return nav_status=="blocked" and Time.get_ticks_msec()<nav_block_until and nav_block_pos.is_finite() and global_position.distance_to(nav_block_pos)<1.0

func steering_point(goal: Vector3) -> Vector3:
	if not is_instance_valid(navigation_source): return goal
	nav_command_frame=Engine.get_physics_frames()
	# A hunting drone's goal moves with its quarry; replanning for every 3 m of that
	# hands it a fresh first waypoint, often to one side, and stops it to turn.
	var changed:=not nav_goal.is_finite() or nav_goal.distance_to(goal)>(5.0 if _combat_motor_active() else 3.0)
	var calm:=_is_calm_patrol()
	var replan:=nav_refresh<=0.0 or (changed and (not calm or nav_retarget_gap<=0.0 or not nav_goal.is_finite()))
	if replan and not changed and _block_wait_active(): replan=false
	if replan and calm and not planning_budget_left(): replan=false
	if replan:
		var plan_started:=Time.get_ticks_usec()
		var accepted_path: PackedVector3Array=navigation_source.get_path_world(global_position,goal)
		var keep_detour:=not changed and (nav_detour_points>0 or nav_escape_point.is_finite()) and not nav_recovery_pending
		nav_goal=goal
		nav_refresh=PATROL_REPLAN_SECONDS+randf()*1.5 if calm else SEARCH_REPLAN_SECONDS if visual.expression=="SEARCH" else .65+float(get_instance_id()%7)*.035
		nav_retarget_gap=PATROL_RETARGET_GAP
		if accepted_path.is_empty():
			if calm: _plan_spent_usec+=Time.get_ticks_usec()-plan_started
			nav_path.clear();nav_detour_points=0;nav_escape_point=Vector3.INF
			nav_status="rejected";nav_endpoint=global_position;set_locomotion(0,0)
			return global_position
		nav_endpoint=accepted_path[-1];nav_status="following"
		if not keep_detour:
			nav_path=accepted_path;nav_detour_points=0;nav_escape_point=Vector3.INF
			# A nearby observed destination can be followed directly only AFTER
			# the wrapper accepts it and full chassis/floor/turn clearance passes.
			if not nav_recovery_pending and _navigation_link_clear(global_position,goal):
				nav_path=PackedVector3Array([goal]);nav_endpoint=goal
			_prepare_navigation_link()
			# A fresh plan can start at a graph vertex beside or behind a running drone.
			# Skip it when the leg beyond is directly clear, rather than stop to turn.
			if _combat_motor_active() and nav_status=="following":
				while nav_path.size()>1:
					var first: Vector3=nav_path[0]-global_position;first.y=0.0
					if first.length()>.3 and absf(global_basis.z.signed_angle_to(first,Vector3.UP))<.6: break
					if not _navigation_link_clear(global_position,nav_path[1]): break
					nav_path.remove_at(0)
		# A blocked drone must not sit out the whole calm interval.
		if nav_status=="blocked": _note_blocked_plan(goal)
		else: nav_block_streak=0
		if calm: _plan_spent_usec+=Time.get_ticks_usec()-plan_started
	while not nav_path.is_empty():
		var tolerance:=.18 if nav_path.size()==1 or nav_detour_points>0 else .65
		if Vector2(nav_path[0].x-global_position.x,nav_path[0].z-global_position.z).length()>=tolerance: break
		# Do not cut a corner early: the next turn/connector must be clear
		# from the current actual pose, not only from the planned vertex.
		if nav_path.size()>1:
			# A calm drone can hold this waypoint for a tick when the budget is spent.
			if calm and not planning_budget_left(): break
			var link_started:=Time.get_ticks_usec()
			var link_clear:=_navigation_link_clear(global_position,nav_path[1])
			if calm: _plan_spent_usec+=Time.get_ticks_usec()-link_started
			if not link_clear:
				# Failing here from a held pose repeats exactly, so don't re-plan every tick.
				var retry_now:=Time.get_ticks_msec()
				if retry_now<nav_link_retry_at: break
				if calm and not planning_budget_left(): break
				nav_link_retry_at=retry_now+NAV_LINK_RETRY_MSEC
				# Standing on a detour corner with no way on: that corner is the
				# problem, so the next search has to find a different one.
				if nav_detour_points>0: obstacle_routes.remember_failure(nav_path[0])
				var prepare_started:=Time.get_ticks_usec()
				_prepare_navigation_link()
				if nav_status=="blocked": _note_blocked_plan(goal)
				if calm: _plan_spent_usec+=Time.get_ticks_usec()-prepare_started
				break
		nav_path.remove_at(0)
		# A hunting drone cuts straight to the waypoint after next when that leg is
		# clear, instead of zigzagging through every 4 m graph vertex.
		if nav_detour_points==0 and nav_path.size()>1 and _combat_motor_active() and _navigation_link_clear(global_position,nav_path[1]):
			nav_path.remove_at(0)
		if nav_detour_points>0:
			nav_detour_points-=1
			if nav_detour_points==0: nav_refresh=0.0
		if nav_escape_point.is_finite() and global_position.distance_to(nav_escape_point)<.2: nav_escape_point=Vector3.INF
	if not nav_path.is_empty(): return nav_path[0]
	if nav_status=="following": nav_status="arrived"
	# A stopped/vetoed chase must not retain last tick's forward command.
	set_locomotion(0,0)
	return global_position

func _prepare_navigation_link() -> void:
	var recovering:=nav_recovery_pending;nav_recovery_pending=false
	var selected:=-1
	for index: int in range(mini(4,nav_path.size())-1,-1,-1):
		if global_position.distance_to(nav_path[index])>8.0 or obstacle_routes._failed(nav_path[index]): continue
		if _navigation_link_clear(global_position,nav_path[index]): selected=index;break
	if selected>=0 and not recovering:
		if selected>0: nav_path=nav_path.slice(selected)
		if Vector2(nav_path[0].x-global_position.x,nav_path[0].z-global_position.z).length()>=.65 or nav_path.size()==1: return
		if _navigation_link_clear(global_position,nav_path[1]): return
	if _try_navigation_detour(): return
	nav_path.clear();nav_detour_points=0;nav_escape_point=Vector3.INF
	nav_status="blocked";set_locomotion(0,0)

func _try_navigation_detour() -> bool:
	if nav_path.is_empty(): return false
	var plan: Dictionary=obstacle_routes.plan(self,nav_path)
	if plan.is_empty(): return false
	var points: PackedVector3Array=plan.points
	nav_path=nav_path.slice(int(plan.rejoin))
	for index: int in range(points.size()-2,-1,-1): nav_path.insert(0,points[index])
	nav_detour_points=points.size()-1;nav_escape_point=plan.escape;nav_escape_check=0.0
	return true

func _navigation_link_clear(from: Vector3, to: Vector3, entering_heading: Vector3 = Vector3.ZERO, fixed_heading: bool = false) -> bool:
	var navigation: RefCounted=navigation_source.get("navigation")
	if navigation==null or not navigation.has_method("_can_walk_floor"): return false
	var a:=Vector2(from.x,from.z);var b:=Vector2(to.x,to.z)
	if a.distance_to(b)>8.0: return false
	if not navigation._can_walk_floor(a,b): return false
	# These route volumes model the upright, unscaled chassis used in GROUND.
	if global_basis.y!=Vector3.UP or not global_basis.get_scale().is_equal_approx(Vector3.ONE) or collider.basis!=Basis.IDENTITY: return false
	if nav_query==null or nav_query_source!=navigation_source:
		nav_query=PhysicsShapeQueryParameters3D.new()
		nav_query.collision_mask=1
		nav_query.collide_with_areas=false
		nav_turn_shape=CylinderShape3D.new()
		var body_size: Vector3=(collider.shape as BoxShape3D).size
		nav_turn_shape.radius=Vector2(body_size.x,body_size.z).length()*.5
		nav_turn_shape.height=body_size.y
		var excluded: Array[RID]=[get_rid()]
		var edge_query: PhysicsShapeQueryParameters3D=navigation.get("_edge_query")
		if edge_query!=null: excluded.append_array(edge_query.exclude)
		# Floor continuity above has checked these authored floor surfaces. Keep
		# every prop, wall, gate and low obstacle in the complete body sweep.
		for group_name: String in ["midori_terrain_floor","midori_terrain_paving"]:
			for floor_node: Node in get_tree().get_nodes_in_group(group_name):
				if floor_node is StaticBody3D: excluded.append(floor_node.get_rid())
		nav_query.exclude=excluded;nav_query_source=navigation_source
	var forward:=Vector3(b.x-a.x,0,b.y-a.y).normalized()
	# Check the rotation this connector needs at its start, then travel with the
	# chassis facing along the connector. A detour arrives along its first leg.
	var incoming:=Vector3(entering_heading.x,0,entering_heading.z)
	var start_basis:=global_basis if incoming.length()<.01 else Basis(Vector3.UP,atan2(incoming.x,incoming.z))
	var aligned:=start_basis if fixed_heading or a.distance_to(b)<.01 else Basis(Vector3.UP,atan2(forward.x,forward.z))
	# The entire footprint needs supporting walkable floor, including bridges.
	var half: Vector3=(collider.shape as BoxShape3D).size*.5
	for x: float in [-half.x,half.x]:
		for z: float in [-half.z,half.z]:
			var offset: Vector3=aligned*Vector3(x,0,z)
			var side:=Vector2(offset.x,offset.z)
			# Centre-only: _can_walk_floor would add its own side rails on top of the chassis width.
			if not navigation._can_walk_floor_centre(a+side,b+side): return false
	nav_query.collision_mask=collision_mask if fixed_heading else 1
	var angle:=start_basis.z.signed_angle_to(aligned.z,Vector3.UP)
	var box:=collider.shape as BoxShape3D
	var radius:=Vector2(box.size.x*.5+absf(collider.position.x),box.size.z*.5+absf(collider.position.z)).length()
	# All box points remain within this middle-heading box throughout the
	# requested yaw arc. The expansion bounds their maximum horizontal travel.
	var padding:=2.0*radius*sin(absf(angle)*.25)+.00001
	var turn_bound:=BoxShape3D.new()
	turn_bound.size=box.size+Vector3(padding*2.0,0,padding*2.0)
	var space:=get_world_3d().direct_space_state
	var start_y:=global_position.y if a.distance_to(Vector2(global_position.x,global_position.z))<.01 else float(navigation._floor_height(a))
	nav_query.shape=turn_bound;nav_query.motion=Vector3.ZERO
	nav_query.transform=Transform3D(Basis(Vector3.UP,atan2(start_basis.z.x,start_basis.z.z)+angle*.5),Vector3(a.x,start_y,a.y))*collider.transform
	if not space.intersect_shape(nav_query,1).is_empty():
		# The padded yaw box is conservative at its corners. The old circular
		# envelope is another complete rotation bound for this centered chassis.
		if collider.position.x!=0.0 or collider.position.z!=0.0: return false
		nav_query.shape=nav_turn_shape
		nav_query.transform=Transform3D(start_basis,Vector3(a.x,start_y,a.y))*collider.transform
		if not space.intersect_shape(nav_query,1).is_empty(): return false
	nav_query.shape=collider.shape
	var steps:=maxi(1,ceili(a.distance_to(b)))
	var previous:=Vector3(a.x,start_y,a.y)
	for index: int in range(1,steps+1):
		var point:=a.lerp(b,float(index)/float(steps))
		var next:=Vector3(point.x,float(navigation._floor_height(point)),point.y)
		# Follow the terrain, rather than casting a long chord through a rise.
		nav_query.transform=Transform3D(aligned,previous)*collider.transform
		nav_query.motion=Vector3.ZERO
		if not space.intersect_shape(nav_query,1).is_empty(): return false
		nav_query.motion=next-previous
		if space.cast_motion(nav_query)[0]<.9999: return false
		previous=next
	return true

func set_combat_locomotion(speed: float, strafe: float, turn: float) -> void:
	set_locomotion(speed,turn)
	desired_strafe=0.0 if dead else clampf(strafe,-.28,.28)*GROUND_SPEED_SCALE

func clear_launch(direction: Vector3, distance: float) -> bool:
	# Sweep the complete body volume at the expected low bound of the hop.
	var start:=global_transform;start.origin+=Vector3.UP*.10
	return not test_move(start,direction*distance)

func try_dodge(side: int) -> bool:
	if mode!="GROUND" or mobility<=0 or cooldown>0 or not is_on_floor() or cripple.stumbling(): return false
	var direction:=global_basis.x*signf(float(side))
	if direction==Vector3.ZERO or not clear_launch(direction,1.0):
		blocked_attempts+=1;return false
	_start_bound("DodgeRight" if side>0 else "DodgeLeft",direction)
	return true

func react_to_threat(world_origin: Vector3) -> bool:
	var side:= -1 if (world_origin-global_position).dot(global_basis.x)>0 else 1
	return try_dodge(side) or try_dodge(-side)

func try_leap() -> bool:
	if mode!="GROUND" or mobility<=0 or cooldown>0 or not is_on_floor() or cripple.stumbling(): return false
	if not clear_launch(global_basis.z,2.45): blocked_attempts+=1;return false
	_start_bound("Leap",global_basis.z)
	return true

## Hop up or down a kerb, step or low ledge the ground motor cannot climb. The
## raised body sweep and a supported landing are both checked before takeoff.
func try_kerb_hop(direction: Vector3) -> bool:
	if mode!="GROUND" or mobility<.75 or cooldown>0 or not is_on_floor() or cripple.stumbling(): return false
	# Each try sweeps the body several times; a held drone retries a few times a second.
	var now:=Time.get_ticks_msec()
	if now<hop_retry_at: return false
	hop_retry_at=now+300
	direction.y=0.0
	if direction.length()<.1: return false
	direction=direction.normalized()
	# The chassis must already face the hop, so the Leap clip and the sweep agree.
	if absf(global_basis.z.signed_angle_to(direction,Vector3.UP))>.6: return false
	var start:=global_transform
	if test_move(start,Vector3.UP*HOP_CLEARANCE): return false
	var raised:=start;raised.origin+=Vector3.UP*HOP_CLEARANCE
	# The native Leap flies about .8 s; its forward speed sets where it lands.
	for reach: float in [HOP_REACH,1.5,3.2]:
		if test_move(raised,direction*reach): continue
		var above:=raised;above.origin+=direction*reach
		var landing:=KinematicCollision3D.new()
		if not test_move(above,Vector3.DOWN*(HOP_CLEARANCE+HOP_MAX_DROP),landing): continue
		if landing.get_normal().dot(Vector3.UP)<.8 or not _tagged_step_floor(landing.get_collider()): continue
		var rise:=above.origin.y+landing.get_travel().y-start.origin.y
		if rise>HOP_MAX_RISE or rise< -HOP_MAX_DROP: continue
		_start_bound("Leap",direction)
		bound_forward_speed=reach/.8
		hops+=1
		return true
	return false

func _start_bound(name: String, direction: Vector3) -> void:
	ability=name;mode="LOAD";phase_time=0;air_time=0
	action_direction=direction;velocity=Vector3.ZERO
	bound_forward_speed=3.0
	visual.begin_action();accepted[name]=int(accepted.get(name,0))+1
	ability_started.emit(name)

func try_climb() -> bool:
	if mode!="GROUND" or mobility<=0 or not is_on_floor() or cooldown>0 or cripple.stumbling(): return false
	var origin:=global_position+Vector3.UP*.45
	var query:=PhysicsRayQueryParameters3D.create(origin,origin+global_basis.z*1.5,1)
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not (hit.collider as Node).is_in_group("drone_climbable"): return false
	var normal: Vector3=hit.normal
	if absf(normal.dot(Vector3.UP))>.15: return false
	wall_normal=normal;wall_basis=Basis(normal.cross(Vector3.UP).normalized(),normal,Vector3.UP)
	attach_basis=visual.global_basis;attach_start=global_position
	attach_end=(hit.position as Vector3)+normal*.025;attach_end.y=global_position.y+1.0
	mode="ATTACH";ability="Climb";phase_time=0;velocity=Vector3.ZERO
	visual.begin_action();accepted["Climb"]=int(accepted.get("Climb",0))+1
	ability_started.emit("Climb")
	return true

func try_release() -> bool:
	# Descend before releasing so a heavy machine does not pivot in mid-air.
	if mode!="CLIMB": return false
	var floor_probe:=global_position+wall_normal*.95
	var floor_query:=PhysicsRayQueryParameters3D.create(floor_probe,floor_probe-Vector3.UP*1.15,1)
	var floor_hit:=get_world_3d().direct_space_state.intersect_ray(floor_query)
	if floor_hit.is_empty() or (floor_hit.normal as Vector3).dot(Vector3.UP)<.8: return false
	attach_start=global_position;attach_end=global_position+wall_normal*.95
	attach_end.y=(floor_hit.position as Vector3).y+.015
	attach_basis=visual.global_basis;wall_basis=global_basis
	mode="DETACH";phase_time=0;visual.begin_action()
	return true

func _tagged_step_floor(value: Object) -> bool:
	var node:=value as Node
	return is_instance_valid(node) and (node.is_in_group("midori_terrain_floor") or node.is_in_group("midori_terrain_paving"))

func _paving_side_contacts(collision: KinematicCollision3D) -> bool:
	var tagged_side:=false
	for index: int in collision.get_collision_count():
		if collision.get_normal(index).dot(Vector3.UP)>=.8: continue
		# Any prop, gate, peer or ceiling contact keeps the ordinary hard veto.
		if not _tagged_step_floor(collision.get_collider(index)): return false
		if collision.get_normal(index).dot(Vector3.UP)<-.1: return false
		tagged_side=true
	return tagged_side

func _supported_step_landing(collision: KinematicCollision3D) -> bool:
	if collision==null or collision.get_collision_count()==0: return false
	for index: int in collision.get_collision_count():
		if collision.get_normal(index).dot(Vector3.UP)<.8 or not _tagged_step_floor(collision.get_collider(index)): return false
	return true

func _ground_step_path_clear(raised: Transform3D, next_basis: Basis, motion: Vector3, turning: bool, start_y: float) -> bool:
	var probe:=KinematicCollision3D.new()
	if turning:
		if ground_step_query==null:
			ground_step_query=PhysicsShapeQueryParameters3D.new()
			ground_step_query.collide_with_areas=false
			ground_step_query.exclude=[get_rid()]
		var box:=collider.shape as BoxShape3D
		# This proof bounds only an upright, unscaled box making a yaw turn.
		if box==null or collider.basis!=Basis.IDENTITY or raised.basis.y!=Vector3.UP or next_basis.y!=Vector3.UP: return false
		if not raised.basis.get_scale().is_equal_approx(Vector3.ONE) or not next_basis.get_scale().is_equal_approx(Vector3.ONE): return false
		var angle:=raised.basis.z.signed_angle_to(next_basis.z,Vector3.UP)
		var radius:=Vector2(box.size.x*.5+absf(collider.position.x),box.size.z*.5+absf(collider.position.z)).length()
		# At every intermediate yaw, each corner is within this distance of its
		# midpoint pose. Expanding both horizontal axes bounds the complete arc,
		# without demanding clearance for an unrelated full-circle rotation.
		var padding:=2.0*radius*sin(absf(angle)*.25)+.00001
		var envelope:=BoxShape3D.new();envelope.size=box.size+Vector3(padding*2.0,0,padding*2.0)
		var midpoint:=Basis(Vector3.UP,atan2(raised.basis.z.x,raised.basis.z.z)+angle*.5)
		ground_step_query.shape=envelope
		ground_step_query.collision_mask=collision_mask
		ground_step_query.transform=Transform3D(midpoint,raised.origin)*collider.transform
		# Covers every intermediate orientation, rather than checking one corner pose.
		if not get_world_3d().direct_space_state.intersect_shape(ground_step_query,1).is_empty(): return false
		raised.basis=next_basis
		if test_move(raised,Vector3.ZERO,probe,GROUND_STEP_MARGIN,true,8): return false
	if test_move(raised,motion,probe,GROUND_STEP_MARGIN,true,8): return false
	var landing_from:=raised;landing_from.origin+=motion
	var landing:=KinematicCollision3D.new()
	var lift:=raised.origin.y-start_y
	var turn_recovery:=turning and motion==Vector3.ZERO
	var contact_allowance:=GROUND_STEP_MARGIN*2.0 if turn_recovery else 0.0
	# Recovery may leave the original pose just above the floor's contact skin.
	# Reach that real support without changing the maximum upward step travel.
	if not test_move(landing_from,Vector3.DOWN*(lift+contact_allowance),landing,GROUND_STEP_MARGIN,false,8): return false
	var rise:=lift+landing.get_travel().y
	if not _supported_step_landing(landing) or rise>GROUND_STEP_HEIGHT or (rise < -contact_allowance if turn_recovery else rise<=.002): return false
	return true

func _try_ground_step(motion: Vector3, next_basis: Basis, turning: bool) -> bool:
	if dead or mode!="GROUND" or mobility<=0 or not is_on_floor() or motion.length()>.02001: return false
	if ground_step_success_frame==Engine.get_physics_frames(): return false
	if (ground_turn_step_wait if turning else ground_step_wait)>0: return false
	# Failed turn clearance cannot starve a clear forward step, but both share
	# one successful rise per physics tick. Retries of each kind wait .2 seconds.
	if turning: ground_turn_step_wait=.2
	else: ground_step_wait=.2
	ground_step_attempts+=1
	var start:=global_transform
	var probe:=KinematicCollision3D.new()
	var lift_motion:=Vector3.UP*GROUND_STEP_HEIGHT
	# Floor recovery is part of physical travel. Reserve it inside the 6cm
	# ceiling, then repeat the full up sweep once with the corrected request.
	if test_move(start,lift_motion,probe,GROUND_STEP_MARGIN,false,8): return false
	lift_motion.y-=maxf(0,probe.get_travel().y-lift_motion.y)+.0001
	if lift_motion.y<=.002: return false
	if test_move(start,lift_motion,probe,GROUND_STEP_MARGIN,false,8): return false
	var predicted_lift:=probe.get_travel()
	if predicted_lift.y<=.002 or predicted_lift.y>GROUND_STEP_HEIGHT: return false
	if Vector2(predicted_lift.x,predicted_lift.z).length()>GROUND_STEP_MARGIN: return false
	var raised:=start;raised.origin+=predicted_lift
	if not _ground_step_path_clear(raised,next_basis,motion,turning,start.origin.y): return false
	# Commit only after all three sweeps and the supporting landing pass. The
	# turn occurs in the checked clear envelope; translation is never teleported.
	var up_hit:=move_and_collide(lift_motion,false,GROUND_STEP_MARGIN,false,8)
	var actual_lift:=maxf(0,global_position.y-start.origin.y)
	var actual_side:=Vector2(global_position.x-start.origin.x,global_position.z-start.origin.z).length()
	# Spend any lateral recovery inside the requested travel budget. Check the
	# actual raised pose too: recovery can differ slightly from the test sweep.
	var actual_motion:=motion.limit_length(maxf(0,motion.length()-actual_side))
	if up_hit!=null or actual_lift>GROUND_STEP_HEIGHT or actual_side>GROUND_STEP_MARGIN or not _ground_step_path_clear(global_transform,next_basis,actual_motion,turning,start.origin.y):
		move_and_collide(start.origin-global_position,false,GROUND_STEP_MARGIN,false,8)
		return false
	if turning: global_basis=next_basis
	var raised_position:=global_position
	var forward_hit: KinematicCollision3D=move_and_collide(actual_motion,false,GROUND_STEP_MARGIN,false,8) if actual_motion.length_squared()>.00000001 else null
	if forward_hit!=null:
		move_and_collide(raised_position-global_position,false,GROUND_STEP_MARGIN,false,8)
		if turning: global_basis=start.basis
		move_and_collide(start.origin-global_position,false,GROUND_STEP_MARGIN,false,8)
		return false
	var down_start:=global_position
	var turn_recovery:=turning and motion==Vector3.ZERO
	var contact_allowance:=GROUND_STEP_MARGIN*2.0 if turn_recovery else 0.0
	var down_hit:=move_and_collide(Vector3.DOWN*(actual_lift+contact_allowance),false,GROUND_STEP_MARGIN,false,8)
	var actual_rise:=global_position.y-start.origin.y
	if not _supported_step_landing(down_hit) or actual_rise>GROUND_STEP_HEIGHT+.0001 or (actual_rise < -contact_allowance if turn_recovery else actual_rise<=.002):
		# Unexpected runtime obstruction: reverse only travelled, checked legs.
		move_and_collide(down_start-global_position,false,GROUND_STEP_MARGIN,false,8)
		move_and_collide(raised_position-global_position,false,GROUND_STEP_MARGIN,false,8)
		if turning: global_basis=start.basis
		move_and_collide(start.origin-global_position,false,GROUND_STEP_MARGIN,false,8)
		return false
	velocity.y=0;ground_step_successes+=1
	ground_step_success_frame=Engine.get_physics_frames()
	return true

func _step_after_slide(requested: Vector3, motor: Vector3, before_slide: Vector3, delta: float) -> bool:
	if requested.length()<.01 or motor.length()<.0001 or requested.normalized().dot(motor.normalized())<.9: return false
	var tagged_side:=false
	for slide: int in get_slide_collision_count():
		var collision:=get_slide_collision(slide)
		for index: int in collision.get_collision_count():
			if collision.get_normal(index).dot(Vector3.UP)>=.8: continue
			if not _paving_side_contacts(collision): return false
			tagged_side=true
	if not tagged_side: return false
	var travelled:=global_position-before_slide;travelled.y=0
	# A hard stop clips motor velocity below the contact margin. A small extra
	# step may use the remaining current command budget, capped at 2cm. This
	# preserves the whole-frame speed/limp cap without repeatedly stalling there.
	var remaining:=minf(.02,maxf(0,requested.length()*delta-travelled.length()))
	if remaining<=.0001: return false
	return _try_ground_step(requested.normalized()*remaining,global_basis,false)

func _turn_ground(delta: float) -> void:
	if absf(turn_rate)<.0001: return
	var angle:=turn_rate*delta
	# Fast combat yaw still advances through native poses no farther apart than
	# the former 1.8rad/s motor at60Hz. Every substep retains solid/peer/step vetoes.
	var steps:=maxi(1,ceili(absf(angle)/.03))
	for _index: int in steps:
		var next:=global_transform
		next.basis=Basis(Vector3.UP,angle/float(steps))*next.basis
		# Rotation can put a rectangular corner through a wall with no translation.
		if test_move(next,Vector3.ZERO,turn_collision,.001,true,8):
			for contact: int in turn_collision.get_collision_count():
				if turn_collision.get_normal(contact).dot(Vector3.UP)<.8:
					if _paving_side_contacts(turn_collision) and _try_ground_step(Vector3.ZERO,next.basis,true): return
					turn_rate=0.0
					nav_turn_vetoed=true
					return
		# Rebuilt from yaw: stacking rotations slowly warps the basis, and route
		# checks and the ragdoll both need an exactly upright, unit-scale chassis.
		global_basis=Basis(Vector3.UP,atan2(next.basis.z.x,next.basis.z.z))
		nav_turn_vetoed=false

func _ground_motor_velocity(horizontal: Vector3, delta: float) -> Vector3:
	# Accelerate along the actual supporting floor rather than pushing a heavy
	# box down into it on every tick. Airborne gravity and solid collision remain
	# owned by move_and_slide; no floor body or collision layer is excluded.
	if is_on_floor():
		var normal:=get_floor_normal()
		if normal.is_finite() and normal.y>=cos(floor_max_angle):
			var tangent:=horizontal.slide(normal)
			return tangent.normalized()*horizontal.length() if tangent.length_squared()>.00000001 else Vector3.ZERO
	return horizontal+Vector3.UP*(velocity.y-GRAVITY*delta)

func _previous_ground_motor_velocity() -> Vector3:
	var horizontal:=Vector3(velocity.x,0,velocity.z)
	if is_on_floor() and horizontal.length_squared()>.00000001:
		var normal:=get_floor_normal()
		if normal.is_finite() and normal.y>=cos(floor_max_angle):
			# Undo the previous floor projection before accelerating in the motor's
			# XZ plane. Recovering only speed would repeatedly bias direction toward
			# the cross-slope axis. The floor-Y guard keeps this inverse well defined.
			var surface:=velocity.slide(normal)
			var flat_source:=surface-normal*(surface.y/normal.y)
			flat_source.y=0.0
			horizontal=flat_source.normalized()*surface.length() if flat_source.length_squared()>.00000001 else Vector3.ZERO
	return horizontal

func _update_navigation_progress(delta: float) -> void:
	# A drone parked on a detour corner whose next leg fails is stuck, not idle.
	var steered_detour:=nav_detour_points>0 and nav_command_frame>=Engine.get_physics_frames()-1
	var moving_intent:=absf(desired_speed)>.25 or absf(desired_turn)>.35 or nav_status=="blocked" or nav_escape_point.is_finite() or steered_detour
	if not is_instance_valid(navigation_source) or nav_status not in ["following","blocked"] or not nav_goal.is_finite() or global_position.distance_to(nav_goal)<1.0 or not moving_intent:
		nav_stall_time=0.0;nav_progress_anchor=global_position;nav_progress_yaw=global_rotation.y
		nav_recovery_pending=false;return
	if not nav_progress_anchor.is_finite(): nav_progress_anchor=global_position
	var progress:=Vector2(global_position.x-nav_progress_anchor.x,global_position.z-nav_progress_anchor.z).length()
	# Spinning back and forth without translating is not route progress, but
	# steadily turning to face the next point is.
	if progress<.08 and not nav_path.is_empty():
		var aim_offset:=nav_path[0]-global_position;aim_offset.y=0.0
		var aim:=absf(global_basis.z.signed_angle_to(aim_offset,Vector3.UP))
		# A new aim point is not progress, or a moving target would hide a stall.
		if not nav_path[0].is_equal_approx(nav_aim_point):
			nav_aim_point=nav_path[0];nav_best_aim=aim
		elif aim<nav_best_aim-.05:
			nav_best_aim=aim;nav_stall_time=0.0;return
	if progress>=.08:
		nav_stall_time=0.0;nav_progress_anchor=global_position;return
	nav_stall_time+=delta
	# A blocked drone is already on its retry back-off.
	if _block_wait_active(): return
	if nav_stall_time>=1.25 and nav_replan_wait<=0.0:
		if (nav_turn_vetoed or nav_detour_points>0) and _try_unwedge():
			nav_stall_time=0.0;nav_replan_wait=1.0;nav_stall_replans+=1
			return
		if not nav_path.is_empty(): obstacle_routes.remember_failure(nav_path[0])
		nav_stall_time=0.0;nav_replan_wait=2.5;nav_refresh=0.0
		nav_recovery_pending=true;nav_stall_replans+=1

## A corner touching a prop can veto every rotation while the route ahead still
## tests clear. Crab clear of it without turning, using the checked escape motion.
func _try_unwedge() -> bool:
	if nav_path.is_empty() or nav_escape_point.is_finite(): return false
	var ahead:=nav_path[0]-global_position;ahead.y=0.0
	var directions: Array[Vector3]=[ahead.normalized(),-global_basis.z,global_basis.x,-global_basis.x]
	for distance: float in [.7,1.2]:
		for direction: Vector3 in directions:
			var point:=global_position+direction*distance
			if _navigation_link_clear(global_position,point,global_basis.z,true):
				nav_escape_point=point;nav_escape_check=0.0;nav_turn_vetoed=false
				nav_refresh=maxf(nav_refresh,1.0)
				return true
	return false

## Backup-run recovery for a drone that has stopped dead. Retrying from one pose
## fails the same way, so crab to any checked spot nearby and route on from there.
func try_free_move(goal: Vector3) -> bool:
	if nav_escape_point.is_finite() or not is_instance_valid(navigation_source): return false
	var route: PackedVector3Array=navigation_source.get_path_world(global_position,goal)
	if route.is_empty(): return false
	var ahead:=route[mini(2,route.size()-1)]-global_position
	var heading:=atan2(ahead.x,ahead.z)
	for distance: float in [1.0,1.8]:
		for offset: float in [0.0,.8,-.8,1.6,-1.6,2.4,-2.4,PI]:
			var point:=global_position+Vector3(sin(heading+offset),0,cos(heading+offset))*distance
			if _navigation_link_clear(global_position,point,global_basis.z,true):
				nav_goal=goal;nav_path=route;nav_endpoint=route[-1]
				nav_status="following";nav_detour_points=0;nav_block_streak=0
				nav_escape_point=point;nav_escape_check=0.0;nav_refresh=1.2
				return true
	# A chassis resting against a prop fails every check above at its start pose,
	# so slide it clear with the physics motion test and let it plan again.
	var navigation: RefCounted=navigation_source.get("navigation")
	var flat:=Vector2(global_position.x,global_position.z)
	for offset: float in [0.0,.8,-.8,1.6,-1.6,2.4,-2.4,PI]:
		var step:=Vector3(sin(heading+offset),0,cos(heading+offset))*.5
		if not navigation._can_walk_floor_centre(flat,flat+Vector2(step.x,step.z)) or test_move(global_transform,step): continue
		move_and_collide(step)
		nav_refresh=0.0;nav_block_pos=Vector3.INF;nav_block_streak=0
		return true
	return false

func _navigation_ground_control(delta: float) -> Dictionary:
	var control: Dictionary={"hold_turn":false,"brake":false,"limit":INF,"requested":Vector3.INF}
	if nav_command_frame<Engine.get_physics_frames()-1 or nav_status!="following" or nav_path.is_empty(): return control
	var offset: Vector3=nav_path[0]-global_position;offset.y=0.0
	if nav_escape_point.is_finite():
		control.hold_turn=true
		offset=nav_escape_point-global_position;offset.y=0.0
		nav_escape_check=maxf(0.0,nav_escape_check-delta)
		if offset.length()<.12:
			nav_escape_point=Vector3.INF;control.brake=true;return control
		if nav_escape_check<=0.0:
			nav_escape_check=.15
			if not _navigation_link_clear(global_position,nav_escape_point,global_basis.z,true):
				obstacle_routes.remember_failure(nav_escape_point)
				nav_escape_point=Vector3.INF;nav_refresh=0.0;nav_recovery_pending=true
				control.brake=true;return control
		var local:=global_basis.inverse()*offset
		var cap:=.44*GROUND_SPEED_SCALE if absf(local.z)>absf(local.x) else .28*GROUND_SPEED_SCALE
		control.requested=offset.normalized()*minf(cap,offset.length()*1.6)
		return control
	var local:=global_basis.inverse()*offset
	var yaw:=atan2(local.x,local.z)
	control.limit=offset.length()*1.2
	# Run through a waypoint whose next leg bends gently; slow only for a real corner.
	if nav_path.size()>1:
		var onward: Vector3=nav_path[1]-nav_path[0];onward.y=0.0
		if onward.length()>.05 and absf(offset.signed_angle_to(onward,Vector3.UP))<.35: control.limit=INF
	# A hunting drone steers through a modest bend at speed; a calm one stops to turn.
	var brake_yaw:=.18
	if _combat_motor_active():
		brake_yaw=.55
		if absf(yaw)>.18: control.limit=minf(float(control.limit),.44*GROUND_SPEED_SCALE*(1.0+(brake_yaw-absf(yaw))*4.0))
	if absf(yaw)>brake_yaw:
		control.brake=true
		# Brake before rotating the box. Otherwise motor inertia can carry
		# a correctly checked turn into the pole before alignment finishes.
		control.hold_turn=Vector2(velocity.x,velocity.z).length()>.15
	return control

func _physics_process(delta: float) -> void:
	if dead: return
	ground_step_wait=maxf(0,ground_step_wait-delta)
	ground_turn_step_wait=maxf(0,ground_turn_step_wait-delta)
	nav_refresh=maxf(0,nav_refresh-delta)
	nav_replan_wait=maxf(0.0,nav_replan_wait-delta)
	nav_retarget_gap=maxf(0.0,nav_retarget_gap-delta)
	cooldown=maxf(0,cooldown-delta);phase_time+=delta
	stagger_time=maxf(0.0,stagger_time-delta)
	if mode!="GROUND":
		ground_acceleration=Vector3.ZERO;nav_stall_time=0.0;nav_progress_anchor=global_position;nav_recovery_pending=false
		if nav_escape_point.is_finite(): nav_escape_point=Vector3.INF;nav_detour_points=0;nav_refresh=0.0
	match mode:
		"DISABLED":
			velocity=Vector3(0,velocity.y-GRAVITY*delta,0);move_and_slide()
		"GROUND":
			var ground_start:=global_position
			var ground_forward_start:=global_basis.z
			var combat_motor:=_combat_motor_active()
			var nav_control:=_navigation_ground_control(delta)
			var angular_acceleration: float=COMBAT_TURN_ACCELERATION if combat_motor else 4.5
			var crippled: bool=cripple.active()
			var flat_speed:=Vector2(velocity.x,velocity.z).length()
			if crippled:
				var driving:=absf(desired_speed)>.3 or (nav_control.requested as Vector3).is_finite()
				if cripple.step(delta,flat_speed/maxf(cripple.top_speed,.1),driving):
					# Each push throws the chassis forward and towards its missing legs.
					visual.add_hit_reaction(Vector3(cripple.side*.35,0,1).normalized(),cripple.lunge)
			var turn_wanted: float=desired_turn*(cripple.turn_scale if crippled else 1.0)
			# Missing legs on one side pull its course round towards them.
			if crippled: turn_wanted+=cripple.veer*cripple.side*clampf(flat_speed/maxf(cripple.top_speed,.1),0.0,1.0)
			if cripple.stumbling(): turn_wanted=0.0
			turn_rate=move_toward(turn_rate,turn_wanted,delta*angular_acceleration)
			if bool(nav_control.hold_turn): turn_rate=0.0
			_turn_ground(delta)
			var horizontal:=_previous_ground_motor_velocity()
			var requested: Vector3=global_basis.z*desired_speed+global_basis.x*desired_strafe
			if (nav_control.requested as Vector3).is_finite(): requested=nav_control.requested as Vector3
			elif bool(nav_control.brake): requested=Vector3.ZERO
			else: requested=requested.limit_length(float(nav_control.limit))
			if crippled: requested=(requested*cripple.surge).limit_length(cripple.top_speed*cripple.surge)
			if stagger_time>0.0: requested*=.3
			# A heavy chassis builds speed and sheds it slowly; it skids when it stops.
			var acceleration:=(.70 if requested.length()>horizontal.length() else .80)*GROUND_SPEED_SCALE
			if combat_motor: acceleration*=2.0
			# A lame push is a hard shove off the good legs, then a dragging glide.
			if crippled and cripple.surge>1.0 and requested.length()>horizontal.length(): acceleration=3.6*GROUND_SPEED_SCALE
			if cripple.stumbling(): acceleration=1.6*GROUND_SPEED_SCALE
			var change := requested-horizontal
			var wanted_acceleration := (change/maxf(delta,.001)).limit_length(acceleration)
			# Motor torque builds and releases rather than snapping on each AI command.
			var motor_torque: float=COMBAT_MOTOR_TORQUE if combat_motor else 12.0
			if crippled: motor_torque=60.0
			ground_acceleration=ground_acceleration.move_toward(wanted_acceleration,motor_torque*delta)
			var step := ground_acceleration*delta
			if step.dot(change)>0 and step.length()>change.length():
				horizontal=requested;ground_acceleration=Vector3.ZERO
			else: horizontal+=step
			# A leg can fail while already moving faster than the limp limit.
			# Bound the motion sent to physics, including motor inertia.
			if crippled: horizontal=horizontal.limit_length(cripple.top_speed*1.25)
			velocity=_ground_motor_velocity(horizontal,delta)
			var before_slide:=global_position
			move_and_slide()
			var stepped:=_step_after_slide(requested,horizontal,before_slide,delta)
			var measured := (global_position-ground_start)/maxf(delta,.001)
			if stepped:
				velocity.x=measured.x;velocity.z=measured.z
				ground_acceleration=Vector3.ZERO
			# Animation receives only motion actually achieved after collision/step checks.
			var achieved_yaw:=ground_forward_start.signed_angle_to(global_basis.z,Vector3.UP)/maxf(delta,.001)
			var motor_idle:=Vector2(measured.x,measured.z).length()<.05 and absf(achieved_yaw)<.025
			visual.drive(delta,Vector3(measured.x,0,measured.z),achieved_yaw,motor_idle)
			_update_navigation_progress(delta)
		"LOAD":
			visual.sample_action(ability,phase_time)
			if phase_time>=.20:
				# LeapAttack alone refreshes its physically checked commitment on
				# the actual takeoff tick; raw Leap/Dodge keep their native contract.
				if ability=="LeapAttack" and not combat.prepare_leap_takeoff(delta):
					if mode=="LOAD": combat._finish()
					_update_leg_hitboxes();return
				mode="AIR";phase_time=0
				var leap:=ability in ["Leap","LeapAttack"]
				velocity=action_direction*(bound_forward_speed if leap else 2.8)+Vector3.UP*(4.0 if leap else 1.65)
		"AIR":
			air_time+=delta
			velocity.y-=GRAVITY*delta;move_and_slide()
			var flight:=.82 if ability in ["Leap","LeapAttack"] else .34
			var clip_length:=1.3 if ability in ["Leap","LeapAttack"] else .8
			visual.sample_action(ability,.20+minf(1,air_time/flight)*(clip_length*.76-.20))
			if is_on_floor() and air_time>.1:
				mode="LAND";phase_time=0;velocity=Vector3.ZERO
		"LAND":
			var clip_length:=1.3 if ability in ["Leap","LeapAttack"] else .8
			visual.sample_action(ability,lerpf(clip_length*.76,clip_length,minf(1,phase_time/.28)))
			if phase_time>=.28:
				visual.player.stop(true);visual.reset_contacts();visual.suspension_velocity=-.1
				mode="GROUND";cooldown=1.2;ability_finished.emit(ability)
		"ATTACH":
			var progress:=smoothstep(0,.70,phase_time)
			visual.global_basis=attach_basis.slerp(wall_basis,progress)
			collider.basis=visual.basis;collider.position=visual.basis*Vector3(0,.38,0)
			var next:=attach_start.lerp(attach_end,progress)
			var collision:=move_and_collide(next-global_position)
			visual.sample_action("Leap",.20+progress*.55)
			if collision!=null and phase_time>.1:
				# Abort to ordinary falling instead of teleporting through an obstacle.
				visual.basis=Basis.IDENTITY;collider.basis=Basis.IDENTITY;collider.position=Vector3(0,.38,0)
				mode="GROUND";visual.reset_contacts();cooldown=1.0;return
			if phase_time>=.70:
				visual.player.stop(true);visual.surface_normal=wall_normal;visual.reset_contacts()
				mode="CLIMB";phase_time=0;motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
		"CLIMB":
			var motion:=Vector3.UP*clampf(climb_input,-1,1)*.40*mobility
			# Keep the whole stance on the tagged wall. Do not invent grips in empty space.
			var surface_ok:=true
			for height: float in [-.72,.72]:
				var point:=global_position+Vector3.UP*height+motion*delta
				var query:=PhysicsRayQueryParameters3D.create(point+wall_normal*.1,point-wall_normal*.2,1)
				if get_world_3d().direct_space_state.intersect_ray(query).is_empty(): surface_ok=false
			if not surface_ok: motion=Vector3.ZERO
			velocity=motion;move_and_slide()
			visual.drive(delta,velocity,0,false)
			if motion.length()<.01: ability="WallIdle"
			else: ability="Climb"
		"DETACH":
			var progress:=smoothstep(0,.70,phase_time)
			visual.global_basis=attach_basis.slerp(wall_basis,progress)
			collider.basis=visual.basis;collider.position=visual.basis*Vector3(0,.38,0)
			move_and_collide(attach_start.lerp(attach_end,progress)-global_position)
			visual.sample_action("Leap",.75+progress*.55)
			if phase_time>=.70:
				visual.player.stop(true);visual.surface_normal=Vector3.UP;visual.reset_contacts()
				mode="GROUND";ability="";cooldown=1.0;motion_mode=CharacterBody3D.MOTION_MODE_GROUNDED
	_update_leg_hitboxes()
