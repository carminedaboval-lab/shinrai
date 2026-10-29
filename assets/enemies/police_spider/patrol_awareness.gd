extends Node
## Optional perception controller for patrol_actor. Add as a child, assign a
## target and world-space route, then enable. +Z is the drone's forward axis.
signal state_changed(previous: String, current: String)
@export var enabled := false
@export var detection_range := 50.0
@export var pursuit_range := 78.0
@export var field_of_view_degrees := 150.0
const NOTICE_DURATION := 0.20
const IDENTIFY_DURATION := 0.25
const COMBAT_ENTER_DURATION := 0.25
const COMBAT_TURN_GAIN := 7.0
const SEARCH_TRAVEL_LIMIT := 12.0
const SEARCH_STALL_LIMIT := 3.5
const SEARCH_SCAN_DURATION := 1.4
var actor: CharacterBody3D
var target: Node3D
var pursuit_target: Node3D
var route: Array[Vector3] = []
var route_index := 0
var state := "PATROL"
var state_time := 0.0
var confidence := 0.0
var unseen_time := 0.0
var visible := false
var last_known := Vector3.ZERO
var patrol_pause := 0.0
var history: Array[String] = ["PATROL"]
var search_goal := Vector3.ZERO
var search_travel := true
var search_travel_time := 0.0
var search_stall_time := 0.0
var search_scan_time := 0.0
var search_progress_anchor := Vector3.ZERO
var had_live_target := false
var pack_contact_remaining := 0.0
const PACK_CONTACT_GRACE := .25

func _ready() -> void:
	actor=get_parent() as CharacterBody3D
	# Issue commands before the actor integrates velocity and solves its feet.
	process_physics_priority=-10

func target_alive() -> bool:
	return is_instance_valid(target) and (not target.has_method("is_combat_alive") or target.is_combat_alive())

func receive_pack_contact(contact: Node3D, point: Vector3) -> void:
	if not enabled or actor==null or actor.dead or not is_instance_valid(contact): return
	if contact.has_method("is_combat_alive") and not contact.is_combat_alive(): return
	target=contact;pursuit_target=contact;last_known=point
	confidence=1.0;unseen_time=0.0;had_live_target=true
	pack_contact_remaining=PACK_CONTACT_GRACE
	change_state("COMBAT")

func receive_damage_contact(source: Node) -> void:
	# Accepted damage is a sampled attack stimulus, never a visual confirmation.
	# Native actions/recovery and already acquired combat retain their authority.
	if not enabled or actor==null or actor.dead or actor.mode!="GROUND" or state in ["COMBAT_ENTER","COMBAT"]: return
	if is_instance_valid(actor.combat) and actor.combat.attack!="": return
	if not is_instance_valid(source) or source==actor or not source is Node3D: return
	if source.is_queued_for_deletion() or not source.is_inside_tree(): return
	if not source.has_method("is_combat_alive") or not source.is_combat_alive(): return
	var point: Vector3=(source as Node3D).global_position
	if not point.is_finite(): return
	last_known=point
	if state=="SEARCH": _begin_search()
	else: change_state("SEARCH")

func _begin_search() -> void:
	var offset:=last_known-actor.global_position;offset.y=0
	search_goal=actor.global_position+offset.limit_length(6.0)
	search_travel=true
	search_travel_time=0;search_stall_time=0;search_scan_time=0
	search_progress_anchor=actor.global_position

func can_see_target() -> bool:
	if not target_alive() or not target.is_visible_in_tree(): return false
	var _raid: Node=actor.get("navigation_source")
	if is_instance_valid(_raid) and _raid.has_method("insertion_grace") and _raid.insertion_grace(): return false
	var origin:=actor.global_position+Vector3.UP*.52
	var point:=target.global_position+Vector3.UP*.8
	var offset:=point-origin
	# A noticed target can be tracked farther than an unknown patrol contact.
	# Measure pursuit from the drone to the target, not accumulated travel.
	if target==pursuit_target:
		if actor.global_position.distance_to(target.global_position)>pursuit_range: return false
	elif offset.length()>detection_range: return false
	var flat:=Vector3(offset.x,0,offset.z)
	if flat.length()>.05 and actor.global_basis.z.dot(flat.normalized())<cos(deg_to_rad(field_of_view_degrees*.5)): return false
	var query:=PhysicsRayQueryParameters3D.create(origin,point,1)
	query.exclude=[actor.get_rid()]
	var hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider==target or target.is_ancestor_of(hit.collider)

func change_state(next: String) -> void:
	if next==state: return
	var previous:=state
	state=next;state_time=0;history.append(next)
	# SEARCH may originate from a sound or a previous range break. Only the
	# current visible contact can acquire extended tracking on reconfirmation.
	if next in ["NOTICE","IDENTIFY"] and visible and target_alive(): pursuit_target=target
	elif next in ["PATROL","RELAX"]: pursuit_target=null
	if next=="SEARCH":
		_begin_search()
	actor.police_lights.set_alert_state(next)
	state_changed.emit(previous,next)

func yaw_to(point: Vector3) -> float:
	var offset:=actor.global_basis.inverse()*(point-actor.global_position)
	return atan2(offset.x,offset.z)

func heading_speed(yaw: float) -> float:
	# Blend into a turn rather than repeatedly stopping at one sharp angle.
	# Large sideways/backward goals still require facing before forward travel.
	return 1.0-smoothstep(.15,1.35,absf(yaw))

func search_step(delta: float, yaw: float) -> void:
	var distance:=Vector2(search_goal.x-actor.global_position.x,search_goal.z-actor.global_position.z).length()
	if search_travel:
		search_travel_time+=delta
		search_stall_time+=delta
		var displacement:=actor.global_position-search_progress_anchor;displacement.y=0
		if displacement.length()>=.08:
			# A valid path may first move away from its goal around cover.
			search_progress_anchor=actor.global_position;search_stall_time=0
		if distance<=.55 or search_travel_time>=SEARCH_TRAVEL_LIMIT or search_stall_time>=SEARCH_STALL_LIMIT:
			search_travel=false;search_scan_time=0
	if search_travel:
		var steering: Vector3=actor.steering_point(search_goal)
		if is_instance_valid(actor.navigation_source) and actor.nav_status=="arrived":
			var endpoint: Vector3=actor.nav_endpoint
			if Vector2(endpoint.x-actor.global_position.x,endpoint.z-actor.global_position.z).length()<=.70:
				# Coarse graph endpoints may differ from the observed world point.
				# Accept only the actor's reachable-arrival result, never a veto.
				search_travel=false;search_scan_time=0
				actor.set_locomotion(0,0)
				return
		var heading:=yaw_to(steering)
		var speed:=.38*heading_speed(heading)*clampf(distance,0,1)
		# An empty/blocked route returns the current position. Hold and let the
		# bounded stall budget expire; never substitute a blind straight chase.
		if steering.distance_to(actor.global_position)<.1: speed=0
		var pack:=actor.get_parent()
		if pack.has_method("limit_approach"): speed=pack.limit_approach(actor,speed)
		actor.set_locomotion(speed,heading*1.6)
	else:
		search_scan_time+=delta
		actor.set_locomotion(0,clampf(yaw*.35,-.3,.3)+sin(search_scan_time*2.0)*.12)
		if search_scan_time>=SEARCH_SCAN_DURATION: change_state("RELAX")

func _physics_process(delta: float) -> void:
	if not enabled or actor==null: return
	if actor.dead: return
	state_time+=delta
	pack_contact_remaining=maxf(0.0,pack_contact_remaining-delta)
	if pursuit_target!=target: pursuit_target=null
	var alive_target: bool=target_alive()
	var target_lost: bool=not alive_target and (had_live_target or is_instance_valid(target))
	had_live_target=alive_target
	# A freed/dead contact releases its pursuit. A standalone noise investigation
	# can still run when no target has ever been assigned.
	if target_lost and state in ["NOTICE","IDENTIFY","COMBAT_ENTER","COMBAT","SEARCH"]:
		confidence=0;search_travel=false;pack_contact_remaining=0.0
		change_state("RELAX")
	if is_instance_valid(pursuit_target) and actor.global_position.distance_to(pursuit_target.global_position)>pursuit_range:
		pursuit_target=null
		if state in ["NOTICE","IDENTIFY","COMBAT_ENTER","COMBAT"]: change_state("SEARCH")
		# The boundary also applies when sight was lost and SEARCH already began.
		if state=="SEARCH": search_travel=false;search_scan_time=0
	visible=can_see_target()
	if visible:
		confidence=minf(1.0,confidence+delta*1.2)
		unseen_time=0;last_known=target.global_position
		var pack:=actor.get_parent()
		if pack.has_method("report_visual_contact"): pack.report_visual_contact(actor,target,last_known)
	else:
		confidence=maxf(0,confidence-delta*.55)
		unseen_time+=delta
	# Traversal and combat recovery own root motion until their release. Search
	# travel/scan budgets advance only when this controller can actually move.
	if actor.mode!="GROUND": return
	var yaw:=yaw_to(last_known)
	actor.visual.set_expression(state,yaw)
	actor.set_locomotion(0,0)
	match state:
		"PATROL":
			if visible and confidence>=.22:
				change_state("NOTICE");return
			patrol_pause=maxf(0,patrol_pause-delta)
			if not route.is_empty() and patrol_pause<=0:
				var goal:=route[route_index]
				var distance:=Vector2(goal.x-actor.global_position.x,goal.z-actor.global_position.z).length()
				if distance<.25:
					route_index=(route_index+1)%route.size();patrol_pause=2.2
				else:
					var heading:=yaw_to(goal)
					actor.set_locomotion(.38*heading_speed(heading)*clampf(distance,0,1),heading*1.6)
		"NOTICE":
			actor.set_locomotion(0,yaw*1.6)
			if unseen_time>.25: change_state("SEARCH")
			elif state_time>=NOTICE_DURATION and visible: change_state("IDENTIFY")
		"IDENTIFY":
			actor.set_locomotion(0,yaw*1.6)
			if unseen_time>.25: change_state("SEARCH")
			elif state_time>=IDENTIFY_DURATION and confidence>=.90 and visible: change_state("COMBAT_ENTER")
		"COMBAT_ENTER":
			actor.set_locomotion(0,yaw*1.6)
			if unseen_time>.20: change_state("SEARCH")
			elif state_time>=COMBAT_ENTER_DURATION: change_state("COMBAT")
		"COMBAT":
			if unseen_time>.15 and pack_contact_remaining<=0.0:
				change_state("SEARCH");return
			var distance:=actor.global_position.distance_to(last_known)
			if (visible and actor.combat.target_valid(target)) or pack_contact_remaining>0.0:
				if visible and actor.combat.try_start(target): return
				var pack:=actor.get_parent()
				var goal:=last_known
				if pack.has_method("combat_goal"): goal=pack.combat_goal(actor,last_known)
				var backline: bool=pack.has_method("is_backline_gunner") and pack.is_backline_gunner(actor)
				var steering: Vector3=actor.steering_point(goal)
				if backline and pack.gunner_goal.is_finite() and goal==pack.gunner_goal:
					var backline_offset: Vector3=goal-actor.global_position;backline_offset.y=0.0
					if backline_offset.length()<=.18:
						# Physical arrival at the checked waypoint releases retreat yaw,
						# even if a stale route veto remains. Native turn collision still wins.
						actor.set_locomotion(0,yaw*COMBAT_TURN_GAIN);return
				if steering.distance_to(actor.global_position)<.1:
					# A path veto still forbids forward travel. It must not freeze a
					# grounded robot facing away from a nearby, freshly seen victim:
					# native yaw collision owns this in-place turn and Slash's normal
					# range/facing/contact tests still decide whether a strike can start.
					var watch_contact: bool=actor.nav_status=="arrived" or (visible and actor.combat.target_valid(target))
					actor.set_locomotion(0,yaw*COMBAT_TURN_GAIN if watch_contact else 0.0);return
				yaw=yaw_to(steering)
				# Keep pressure through the final metres instead of dropping to a
				# slow walk outside claw range. Retain native braking and yielding. A shared
				# sighting supplies a navigable destination, never a blind attack.
				var chase:=1.55 if distance>2.6 else (1.10 if distance>1.5 else (.34 if distance>1.04 else 0.0))
				if backline:
					# A close gunner must turn and travel toward its checked retreat
					# waypoint, then face the contact on arrival. Target distance must
					# not stop that retreat or turn it into backward melee pressure.
					var to_goal:=Vector2(goal.x-actor.global_position.x,goal.z-actor.global_position.z).length()
					chase=1.55 if to_goal>2.6 else (1.10 if to_goal>1.5 else (.34 if to_goal>.18 else 0.0))
				elif distance<.80: chase=-.24
				if pack.has_method("limit_approach"): chase=pack.limit_approach(actor,chase)
				var yielding:=0.0
				if pack.has_method("yield_strafe"): yielding=pack.yield_strafe(actor)
				actor.set_combat_locomotion(chase*heading_speed(yaw),yielding,yaw*COMBAT_TURN_GAIN)
				return
			var forward:=.32 if distance>4.4 else (-.24 if distance<2.7 else 0.0)
			# Deliberate repositioning with pauses, not constant skating sideways.
			var phase:=fposmod(state_time,6.0)
			var strafe:=.18 if phase>1.2 and phase<2.8 else (-.18 if phase>4.2 and phase<5.8 else 0.0)
			if not visible: strafe=0;forward=0
			actor.set_combat_locomotion(forward*heading_speed(yaw),strafe,yaw*COMBAT_TURN_GAIN)
		"SEARCH":
			if visible and confidence>=.35: change_state("IDENTIFY");return
			search_step(delta,yaw)
		"RELAX":
			if visible and confidence>=.22: change_state("NOTICE");return
			if state_time>1.6: change_state("PATROL")
