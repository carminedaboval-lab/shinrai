extends Node
## Optional perception controller for patrol_actor. Add as a child, assign a
## target and world-space route, then enable. +Z is the drone's forward axis.
signal state_changed(previous: String, current: String)
@export var enabled := false
@export var detection_range := 50.0
@export var pursuit_range := 78.0
@export var field_of_view_degrees := 150.0
const NOTICE_DURATION := 0.20
# Police procedure: the scan beam holds on a contact long enough to be seen, so
# the player has a clear beat to break line of sight before force is authorised.
const IDENTIFY_DURATION := 1.1
const REACQUIRE_DURATION := .25
const COMBAT_ENTER_DURATION := 0.25
const COMBAT_TURN_GAIN := 7.0
const SEARCH_TRAVEL_LIMIT := 12.0
const SEARCH_STALL_LIMIT := 3.5
const SEARCH_SCAN_DURATION := 2.0
const SEARCH_SPEED := 1.1
# Check the spot, then sweep twice more before giving up.
const SEARCH_LEGS := 3
# Breaking sight is not escape: run on to where the contact was heading first.
const PURSUIT_MEMORY := 3.5
const PURSUIT_LEAD_MAX := 9.0
const PURSUIT_ARRIVAL := 1.6
# Pushing forward without moving this long means a kerb or step is in the way.
const HOP_STALL_SECONDS := .45
const HOP_RANGE := 30.0
# Retrying from one pose fails the same way, so a stuck unit crabs clear first.
const SEARCH_UNSTICK_SECONDS := 2.0
const COMBAT_UNSTICK_SECONDS := 2.0
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
var search_leg := 0
var search_unstuck := false
var combat_blocked_time := 0.0
var search_travel := true
var search_travel_time := 0.0
var search_stall_time := 0.0
var search_scan_time := 0.0
var search_progress_anchor := Vector3.ZERO
var had_live_target := false
var pack_contact_remaining := 0.0
const PACK_CONTACT_GRACE := .25
var last_seen_velocity := Vector3.ZERO
var hop_stall_time := 0.0
# Packmates nose to tail can each brake for the other forever: back off and sidestep.
const JAM_SECONDS := .8
const JAM_BACKOFF_SECONDS := .7
var jam_time := 0.0
var jam_backoff := 0.0
var jam_side := 1.0

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
	# Being shot must not restart an identification already under way.
	if state in ["NOTICE","IDENTIFY"]: return
	if state=="SEARCH": _begin_search()
	else: change_state("SEARCH")

## A contact the pack has already confirmed is reacquired at once, not re-identified.
func _identify_hold() -> float:
	var pack:=actor.get_parent()
	var confirmed: bool=pack.get("battle_active")==true and is_instance_valid(target) and pack.get("battle_target_id")==target.get_instance_id()
	return REACQUIRE_DURATION if confirmed else IDENTIFY_DURATION

func _begin_search() -> void:
	search_leg=0
	_begin_search_leg()

func _begin_search_leg() -> void:
	var offset:=last_known-actor.global_position;offset.y=0
	search_goal=actor.global_position+offset.limit_length(6.0)
	var pack:=actor.get_parent()
	if pack.has_method("search_point"): search_goal=pack.search_point(actor,last_known,search_leg)
	search_unstuck=false
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
	# Police procedure: a new contact is warned while it is being identified.
	if next=="IDENTIFY" and is_instance_valid(target) and _identify_hold()==IDENTIFY_DURATION:
		var pack:=actor.get_parent()
		if pack.has_method("radio_warning"): pack.radio_warning(target)
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
		if search_stall_time>=SEARCH_UNSTICK_SECONDS and not search_unstuck:
			search_unstuck=true
			if actor.try_free_move(search_goal): search_stall_time=0
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
		var speed:=SEARCH_SPEED*heading_speed(heading)*clampf(distance,0,1)
		# An empty/blocked route returns the current position. Hold and let the
		# bounded stall budget expire; never substitute a blind straight chase.
		if steering.distance_to(actor.global_position)<.1: speed=0
		var pack:=actor.get_parent()
		if pack.has_method("limit_approach"): speed=pack.limit_approach(actor,speed)
		actor.set_locomotion(speed,heading*1.6)
		_hop_if_stalled(delta,speed,steering)
	else:
		search_scan_time+=delta
		actor.set_locomotion(0,clampf(yaw*.35,-.3,.3)+sin(search_scan_time*2.0)*.12)
		if search_scan_time>=SEARCH_SCAN_DURATION:
			search_leg+=1
			if search_leg<SEARCH_LEGS: _begin_search_leg()
			else: change_state("RELAX")

## A peer ahead has held this drone still: reverse and crab aside, then rejoin.
func _jam_step(delta: float, wanted: float, allowed: float, yaw: float) -> bool:
	if jam_backoff>0.0:
		jam_backoff=maxf(0.0,jam_backoff-delta)
		actor.set_combat_locomotion(-.44,.28*jam_side,yaw*COMBAT_TURN_GAIN*.5)
		return true
	var moving:=Vector2(actor.velocity.x,actor.velocity.z).length()
	if wanted<.5 or allowed>wanted*.5 or moving>.4:
		jam_time=0.0;return false
	jam_time+=delta
	# Staggered by unit so two jammed packmates do not back off in lockstep.
	if jam_time<JAM_SECONDS+float(actor.get_instance_id()%5)*.15: return false
	jam_time=0.0;jam_backoff=JAM_BACKOFF_SECONDS
	jam_side=-1.0 if yaw>0.0 else 1.0
	return false

## Commanded forward but not moving: something low is in the way. Hop it.
func _hop_if_stalled(delta: float, command: float, toward: Vector3) -> void:
	var moving:=Vector2(actor.velocity.x,actor.velocity.z).length()
	# Turning on the spot is not a stall; only a drone facing its way and held still is.
	if command<.5 or moving>.4 or actor.mode!="GROUND" or absf(yaw_to(toward))>.35:
		hop_stall_time=0.0;return
	hop_stall_time+=delta
	if hop_stall_time<HOP_STALL_SECONDS: return
	hop_stall_time=0.0
	var direction:=toward-actor.global_position
	if Vector2(direction.x,direction.z).length()<.3: direction=actor.global_basis.z
	actor.try_kerb_hop(direction)

## A wounded unit ignores the fight while it falls back, then watches from cover.
func _withdraw_step() -> bool:
	var pack:=actor.get_parent()
	if not pack.has_method("withdrawal_goal"): return false
	var cover: Vector3=pack.withdrawal_goal(actor)
	if not cover.is_finite(): return false
	var steering: Vector3=actor.steering_point(cover)
	if steering.distance_to(actor.global_position)<.1:
		actor.set_locomotion(0,yaw_to(last_known)*COMBAT_TURN_GAIN)
		return true
	var heading:=yaw_to(steering)
	var speed: float=pack.limit_approach(actor,1.55*heading_speed(heading))
	actor.set_combat_locomotion(speed,pack.yield_strafe(actor),heading*COMBAT_TURN_GAIN)
	return true

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
		if state=="SEARCH": search_travel=false;search_scan_time=0;search_leg=SEARCH_LEGS
	visible=can_see_target()
	if visible:
		confidence=minf(1.0,confidence+delta*1.2)
		unseen_time=0;last_known=target.global_position
		var seen_velocity: Variant=target.get("velocity")
		if seen_velocity is Vector3:
			var flat_velocity: Vector3=seen_velocity;flat_velocity.y=0.0
			last_seen_velocity=last_seen_velocity.lerp(flat_velocity,minf(1.0,delta*8.0))
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
			elif state_time>=_identify_hold() and confidence>=.90 and visible: change_state("COMBAT_ENTER")
		"COMBAT_ENTER":
			actor.set_locomotion(0,yaw*1.6)
			if unseen_time>.20: change_state("SEARCH")
			elif state_time>=COMBAT_ENTER_DURATION: change_state("COMBAT")
		"COMBAT":
			if _withdraw_step(): return
			# Out of sight, run on along the contact's last heading before searching.
			var pursuing: bool=not visible and pack_contact_remaining<=0.0 and unseen_time<=PURSUIT_MEMORY
			var chase_point:=last_known
			if pursuing:
				chase_point=last_known+(last_seen_velocity*minf(unseen_time+.6,2.0)).limit_length(PURSUIT_LEAD_MAX)
				var reached:=Vector2(chase_point.x-actor.global_position.x,chase_point.z-actor.global_position.z).length()<=PURSUIT_ARRIVAL
				if reached or (unseen_time>.6 and actor.nav_status=="rejected"):
					last_known=chase_point;change_state("SEARCH");return
			if unseen_time>PURSUIT_MEMORY and pack_contact_remaining<=0.0:
				last_known=chase_point;change_state("SEARCH");return
			var distance:=actor.global_position.distance_to(chase_point)
			if (visible and actor.combat.target_valid(target)) or pack_contact_remaining>0.0 or pursuing:
				if visible and actor.combat.try_start(target): return
				var pack:=actor.get_parent()
				var goal:=chase_point
				if pack.has_method("combat_goal"): goal=pack.combat_goal(actor,chase_point)
				var backline: bool=pack.has_method("is_backline_gunner") and pack.is_backline_gunner(actor)
				var steering: Vector3=actor.steering_point(goal)
				combat_blocked_time=combat_blocked_time+delta if actor.nav_status=="blocked" else 0.0
				if combat_blocked_time>=COMBAT_UNSTICK_SECONDS:
					combat_blocked_time=0.0;actor.try_free_move(goal)
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
					# No route usually means a kerb or step between the drone and the
					# contact. Face it and hop across rather than wait on the road.
					if not backline and actor.nav_status in ["rejected","blocked"] and distance>2.4 and distance<HOP_RANGE:
						var to_contact:=yaw_to(chase_point)
						actor.set_locomotion(0,to_contact*COMBAT_TURN_GAIN)
						if absf(to_contact)<.5: actor.try_kerb_hop(chase_point-actor.global_position)
						return
					actor.set_locomotion(0,yaw*COMBAT_TURN_GAIN if watch_contact else 0.0);return
				yaw=yaw_to(steering)
				# Keep pressure through the final metres instead of dropping to a
				# slow walk outside claw range. Retain native braking and yielding. A shared
				# sighting supplies a navigable destination, never a blind attack.
				# Far off, sprint: a drone that is only as fast as a walk never catches anyone.
				var chase: float=actor.COMBAT_SPRINT if distance>6.0 else (1.55 if distance>2.6 else (1.10 if distance>1.5 else (.34 if distance>1.04 else 0.0)))
				if backline:
					# A close gunner must turn and travel toward its checked retreat
					# waypoint, then face the contact on arrival. Target distance must
					# not stop that retreat or turn it into backward melee pressure.
					var to_goal:=Vector2(goal.x-actor.global_position.x,goal.z-actor.global_position.z).length()
					chase=1.55 if to_goal>2.6 else (1.10 if to_goal>1.5 else (.34 if to_goal>.18 else 0.0))
				elif distance<.80: chase=-.24
				var wanted:=chase
				if pack.has_method("limit_approach"): chase=pack.limit_approach(actor,chase)
				var yielding:=0.0
				if pack.has_method("yield_strafe"): yielding=pack.yield_strafe(actor)
				if _jam_step(delta,wanted,chase,yaw): return
				actor.set_combat_locomotion(chase*heading_speed(yaw),yielding,yaw*COMBAT_TURN_GAIN)
				_hop_if_stalled(delta,chase*heading_speed(yaw),steering)
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
