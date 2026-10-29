extends Node3D
## Small cohesive patrol. Route points are world coordinates on clear ground.
@export_range(0,5,1) var requested_size := 0 # 0 chooses 3, 4 or 5 at spawn.
@export var spawn_on_ready := true
var members: Array[CharacterBody3D] = []
var route: Array[Vector3] = []
var target: Node3D
var leader: CharacterBody3D
var slots: Dictionary = {}
var waypoint := 0
var hold := 0.0
var roam_enabled := false
var roaming = preload("patrol_roaming.gd").new()
var roaming_catchup: Dictionary = {}
var attack_owner: CharacterBody3D
var attack_gap := 0.0
var stun_gap := 0.0
const STUN_PACK_COOLDOWN := 3.5
var attack_queue: Array[CharacterBody3D] = []
var request_age: Dictionary = {}
var last_attacker: CharacterBody3D
var melee_owners: Array[CharacterBody3D] = []
# Approach slots coordinate ground pressure independently of the gun slot.
# Attack admission, native recovery and collision still own the actual strike.
var melee_pressers: Array[CharacterBody3D] = []
var melee_queue: Array[CharacterBody3D] = []
var melee_gaps: Dictionary = {}
var last_melee_attacker: CharacterBody3D
const MAX_ACTIVE_MELEE := 2
const BATTLE_OPENING_SECONDS := 5.5
const GUNNER_MIN_RANGE := 7.0
const GUNNER_MAX_RANGE := 10.0
const GUNNER_GOAL_INTERVAL := .8
const GUNNER_STALL_SECONDS := 2.0
const GUNNER_MAX_ROUTE_FAILURES := 3
var battle_active := false
var battle_elapsed := 0.0
var battle_target_id := 0
var battle_begin_tick := false
var gunner: CharacterBody3D
var gunner_goal := Vector3.INF
var gunner_handoffs := 0
var gunner_axis := Vector3.FORWARD
var gunner_goal_contact := Vector3.INF
var gunner_goal_wait := 0.0
var gunner_goal_attempt := 0
var gunner_route_failures := 0
var gunner_stall := 0.0
var gunner_progress_anchor := Vector3.INF
var gunner_progress_heading := Vector3.FORWARD
var gunner_rejections: Dictionary = {}
const COMBAT_ROLE_NAMES := ["pressure","flank_left","flank_right","cutoff_left","cutoff_right"]
const ROLE_LEASE_SECONDS := 2.0
const ROLE_PLAN_INTERVAL := .20
const ROLE_CONTACT_MEMORY := .25
const ROLE_MAX_OBSERVED_SPEED := 5.0
var combat_roles: Dictionary = {}
var role_holders: Dictionary = {}
var role_rejections: Dictionary = {}
var role_clock := 0.0
var role_plan_wait := 0.0
var role_scan_index := 0
var role_axis := Vector3.FORWARD
var observed_contact := Vector3.ZERO
var observed_velocity := Vector3.ZERO
var observation_seconds := -1.0
var contact_age := INF
var role_probe_count := 0
var role_last_probe_count := 0
var role_peak_probe_count := 0
var role_handoffs := 0
var wanderers: Dictionary = {}
var wander_cooldowns: Dictionary = {}
var returning_members: Dictionary = {}
const SPACING := 2.5
const PATROL_BUBBLE := 12.0
const DRONE = preload("Shinrai_Police_Drone.tscn")

func _ready() -> void:
	process_physics_priority=-5 # Awareness runs first; formation owns only patrol.
	if spawn_on_ready: spawn_pack(requested_size)

func spawn_pack(size: int = 0) -> void:
	if not members.is_empty(): return
	var count:=randi_range(3,5) if size==0 else clampi(size,3,5)
	for i in count:
		var drone:=DRONE.instantiate() as CharacterBody3D
		var offset:=Vector3.ZERO if i==0 else Vector3((-1 if i%2==1 else 1)*SPACING,0,-ceilf(float(i)/2.0)*SPACING)
		drone.position=offset;add_child(drone);members.append(drone);slots[drone]=offset
		# A director may immediately project this formation onto navigation points.
		# Let physics synchronize every new transform before collision recovery.
		drone.set_physics_process(false)
		_activate_member.call_deferred(drone)
		var brain: Node=drone.get_node("Awareness");brain.enabled=true;brain.target=target
	leader=members[0]

func _activate_member(member: CharacterBody3D) -> void:
	if not is_instance_valid(member) or member.is_queued_for_deletion() or is_queued_for_deletion(): return
	# DISABLED still suppresses effective execution. Keep this flag enabled so
	# restoring INHERIT after a pause can resume a just-spawned member normally.
	member.set_physics_process(true)

func living_members() -> Array[CharacterBody3D]:
	var alive: Array[CharacterBody3D]=[]
	for member in members:
		if is_instance_valid(member) and not member.dead: alive.append(member)
	return alive

func report_visual_contact(observer: CharacterBody3D, contact: Node3D, point: Vector3) -> void:
	if observer not in members or observer.dead or contact!=target or not is_instance_valid(contact): return
	if not point.is_finite() or (contact.has_method("is_combat_alive") and not contact.is_combat_alive()): return
	var source: Node=observer.get_node("Awareness")
	if not source.enabled or not source.visible or source.target!=contact or source.state!="COMBAT": return
	_begin_battle()
	_record_role_observation(point)
	# Local notice/identify/entry must confirm this sighting before radio sharing.
	# Never feed an observer its own report: its native confidence stays authoritative.
	# Peers retain their own sight test for attacks and navigation/collision motor.
	for member: CharacterBody3D in living_members():
		if member==observer: continue
		_end_wander(member)
		member.get_node("Awareness").receive_pack_contact(contact,point)

func _begin_battle() -> void:
	var contact_id: int=target.get_instance_id()
	if battle_active and battle_target_id==contact_id: return
	_reset_battle()
	battle_active=true;battle_target_id=contact_id;battle_begin_tick=true

func _reset_battle() -> void:
	battle_active=false;battle_elapsed=0.0;battle_target_id=0;battle_begin_tick=false
	gunner=null;gunner_goal=Vector3.INF;gunner_goal_contact=Vector3.INF
	gunner_goal_wait=0.0;gunner_goal_attempt=0;gunner_route_failures=0;gunner_stall=0.0
	gunner_rejections.clear()
	combat_roles.clear();role_holders.clear();melee_pressers.clear()
	contact_age=INF;observation_seconds=-1.0;observed_velocity=Vector3.ZERO
	role_plan_wait=0.0;role_scan_index=0

func is_backline_gunner(member: CharacterBody3D) -> bool:
	return battle_active and is_instance_valid(gunner) and member==gunner

func _release_gunner(reject: bool = false) -> void:
	if is_instance_valid(gunner):
		if reject: gunner_rejections[gunner]=role_clock+2.0
		gunner_handoffs+=1
	gunner=null;gunner_goal=Vector3.INF;gunner_goal_contact=Vector3.INF
	gunner_goal_wait=0.0;gunner_goal_attempt=0;gunner_route_failures=0;gunner_stall=0.0

func _update_battle(delta: float, alive: Array[CharacterBody3D]) -> void:
	if not battle_active: return
	if not is_instance_valid(target) or target.get_instance_id()!=battle_target_id or (target.has_method("is_combat_alive") and not target.is_combat_alive()):
		_reset_battle();return
	var calm := true
	for member: CharacterBody3D in alive:
		if member.get_node("Awareness").state not in ["PATROL","RELAX"]: calm=false;break
	if alive.is_empty() or calm:
		_reset_battle();return
	# A report precedes this pack's integration in the same physics tick.
	if battle_begin_tick: battle_begin_tick=false
	else: battle_elapsed+=delta
	gunner_goal_wait=maxf(0.0,gunner_goal_wait-delta)
	for member in gunner_rejections.keys():
		if member not in alive: gunner_rejections.erase(member)
	if gunner==null:
		_select_gunner(alive);return
	if not is_instance_valid(gunner) or gunner not in alive or gunner.mobility<=0.0 or not is_instance_valid(gunner.navigation_source) or gunner.mode in ["FACE_ATTACHED","DISABLED","CLIMB","ATTACH","DETACH"]:
		_release_gunner();_select_gunner(alive);return
	if gunner.mode!="GROUND": return
	var moved: Vector3=gunner.global_position-gunner_progress_anchor
	var turned: float=absf(gunner.global_basis.z.signed_angle_to(gunner_progress_heading,Vector3.UP))
	if not gunner_goal.is_finite() or gunner.nav_status in ["blocked","rejected"]:
		gunner_stall+=delta
	elif Vector2(moved.x,moved.z).length()>=.1 or turned>=.08:
		gunner_progress_anchor=gunner.global_position;gunner_progress_heading=gunner.global_basis.z;gunner_stall=0.0
	elif gunner.nav_status=="following" and gunner.global_position.distance_to(gunner_goal)>1.0:
		gunner_stall+=delta
	else: gunner_stall=0.0
	if gunner_stall>=GUNNER_STALL_SECONDS:
		_release_gunner(true);_select_gunner(alive)

func _select_gunner(alive: Array[CharacterBody3D]) -> void:
	var selected: CharacterBody3D
	var best := INF
	for member: CharacterBody3D in alive:
		if member.mobility<=0.0 or member.mode!="GROUND" or member.combat.attack!="" or not is_instance_valid(member.navigation_source): continue
		if float(gunner_rejections.get(member,0.0))>role_clock: continue
		var distance:=Vector2(member.global_position.x-observed_contact.x,member.global_position.z-observed_contact.z).length()
		var score: float=absf(distance-(GUNNER_MIN_RANGE+GUNNER_MAX_RANGE)*.5)+member.combat.stun_cooldown*.25+(1.0-member.mobility)*2.0
		var brain: Node=member.get_node("Awareness")
		if brain.visible and member.combat.target_valid(brain.target) and member.combat._stun_lane_clear(brain.target): score-=20.0
		if score<best: best=score;selected=member
	if selected==null: return
	gunner=selected;gunner_goal=Vector3.INF;gunner_goal_contact=Vector3.INF
	gunner_goal_wait=0.0;gunner_goal_attempt=0;gunner_route_failures=0;gunner_stall=0.0
	gunner_progress_anchor=gunner.global_position;gunner_progress_heading=gunner.global_basis.z
	var away:=gunner.global_position-observed_contact;away.y=0.0
	gunner_axis=away.normalized() if away.length()>.1 else -gunner.global_basis.z
	_release_combat_role(gunner);melee_pressers.erase(gunner);melee_queue.erase(gunner)

func _plan_gunner_goal() -> void:
	if not is_instance_valid(gunner) or gunner.mode!="GROUND": return
	var movement: float=INF if not gunner_goal_contact.is_finite() else Vector2(observed_contact.x-gunner_goal_contact.x,observed_contact.z-gunner_goal_contact.z).length()
	if gunner_goal.is_finite() and movement<1.5: return
	if not gunner_goal.is_finite() and gunner_goal_wait>0.0: return
	# One candidate shares the existing two-route-probe role decision budget.
	var angles := [0.0,.35,-.35,.7,-.7]
	var angle: float=angles[gunner_goal_attempt%angles.size()]
	gunner_goal_attempt+=1;gunner_goal_wait=GUNNER_GOAL_INTERVAL
	var proposed:=observed_contact+gunner_axis.rotated(Vector3.UP,angle)*((GUNNER_MIN_RANGE+GUNNER_MAX_RANGE)*.5)
	role_last_probe_count+=1;role_probe_count+=1
	var accepted: Dictionary=_combat_role_route(gunner,proposed,"gunner")
	role_peak_probe_count=maxi(role_peak_probe_count,role_last_probe_count)
	if accepted.is_empty():
		gunner_route_failures+=1
		if gunner_route_failures>=GUNNER_MAX_ROUTE_FAILURES: _release_gunner(true)
		return
	gunner_goal=accepted.goal;gunner_goal_contact=observed_contact
	gunner_goal_attempt=0;gunner_route_failures=0;gunner_stall=0.0;gunner.nav_refresh=0.0

func _physics_process(delta: float) -> void:
	attack_gap=maxf(0,attack_gap-delta)
	stun_gap=maxf(0,stun_gap-delta)
	for member in attack_queue.duplicate()+melee_queue.duplicate():
		request_age[member]=float(request_age.get(member,0.0))+delta
		if not is_instance_valid(member) or member.dead or request_age[member]>.35:
			attack_queue.erase(member);melee_queue.erase(member);request_age.erase(member)
	for member in melee_owners.duplicate():
		if not is_instance_valid(member) or member.dead: melee_owners.erase(member)
	for member in melee_gaps.keys():
		if not is_instance_valid(member) or member.dead: melee_gaps.erase(member)
		else: melee_gaps[member]=maxf(0.0,float(melee_gaps[member])-delta)
	if is_instance_valid(attack_owner) and attack_owner.dead: attack_finished_by(attack_owner)
	var alive:=living_members()
	_update_battle(delta,alive)
	_update_combat_roles(delta,alive)
	_update_melee_pressure(alive)
	if alive.is_empty():
		wanderers.clear();wander_cooldowns.clear();returning_members.clear()
		roaming_catchup.clear()
		return
	if not is_instance_valid(leader) or leader.dead:
		leader=alive[0]
		_end_wander(leader)
		# Reform around the new leader after a loss.
		for i in alive.size():
			slots[alive[i]]=Vector3.ZERO if i==0 else Vector3((-1 if i%2==1 else 1)*SPACING,0,-ceilf(float(i)/2.0)*SPACING)
	for state: Dictionary in [wanderers,wander_cooldowns,returning_members,roaming_catchup]:
		for member in state.keys():
			if member not in alive: state.erase(member)
	var wander_limit := 1 if alive.size()<=3 else 2
	for index: int in range(alive.size()-1,-1,-1):
		if wanderers.size()<=wander_limit: break
		_end_wander(alive[index])
	hold=maxf(0,hold-delta)
	var pack_alert := false
	for member: CharacterBody3D in alive:
		if member.get_node("Awareness").state!="PATROL": pack_alert=true
	for member in alive:
		var brain: Node=member.get_node("Awareness");brain.target=target
		if member!=leader:
			if not wander_cooldowns.has(member):
				wander_cooldowns[member]=20.0+maxi(0,members.find(member))*2.0+randf_range(0.0,3.0)
			wander_cooldowns[member]=maxf(0.0,float(wander_cooldowns[member])-delta)
			if member.mode=="GROUND" and brain.state=="PATROL":
				_patrol_follower(member,alive,delta,pack_alert)
			else:
				_end_wander(member)
	var leader_brain: Node=leader.get_node("Awareness")
	if leader.mode!="GROUND" or leader_brain.state!="PATROL":
		if roam_enabled: roaming.suspend(leader)
		return
	leader.set_locomotion(0,0)
	if roam_enabled and is_instance_valid(leader.navigation_source):
		var roam_goal: Vector3 = roaming.next_goal(leader,delta)
		if roam_goal.is_finite(): _follow(leader,roam_goal,.34,alive)
		return
	# Stragglers, inspections and combat never hold up the leader's patrol.
	if route.is_empty() or hold>0: return
	var goal:=route[waypoint%route.size()]
	var distance:=Vector2(goal.x-leader.global_position.x,goal.z-leader.global_position.z).length()
	if distance<.30:
		waypoint=(waypoint+1)%route.size();hold=1.8
	else:
		_follow(leader,goal,.34,alive)
		if is_instance_valid(leader.navigation_source) and leader.nav_status=="arrived":
			var endpoint: Vector3=leader.nav_endpoint
			if endpoint.distance_to(goal)<=3.0 and endpoint.distance_to(leader.global_position)<.8:
				waypoint=(waypoint+1)%route.size();hold=1.8;leader.set_locomotion(0,0)

func _patrol_follower(member: CharacterBody3D, alive: Array[CharacterBody3D], delta: float, pack_alert: bool) -> void:
	var distance: float=member.global_position.distance_to(leader.global_position)
	if pack_alert or member.mobility<1.0 or distance>PATROL_BUBBLE or not is_instance_valid(member.navigation_source):
		_end_wander(member)
	var wander_limit := 1 if alive.size()<=3 else 2
	if not pack_alert and member.mobility>=1.0 and distance<8.0 and not returning_members.has(member) and not wanderers.has(member) and wanderers.size()<wander_limit and float(wander_cooldowns[member])<=0.0:
		_begin_wander(member)
	if wanderers.has(member) and _update_wander(member,alive,delta): return
	var goal: Vector3=leader.global_transform*(slots[member] as Vector3)
	if roam_enabled and distance>8.0 and not pack_alert:
		# Retargeting a distant follower every time the leader turns continually
		# discards its native obstacle detour. Commit one catch-up waypoint first.
		if roaming_catchup.has(member):
			roaming_catchup[member].remaining=float(roaming_catchup[member].remaining)-delta
		if not roaming_catchup.has(member) or float(roaming_catchup[member].remaining)<=0.0 or member.global_position.distance_to(roaming_catchup[member].goal)<2.5:
			roaming_catchup[member]={"goal":goal,"remaining":6.0+float(members.find(member))*1.5}
		goal=roaming_catchup[member].goal
	else:
		roaming_catchup.erase(member)
	var speed := .58
	if member.mobility>=1.0:
		if distance>14.0: speed=1.3
		elif distance>8.0: speed=1.0
	_follow(member,goal,speed,alive)
	if returning_members.has(member) and distance<8.0:
		var has_navigation: bool=is_instance_valid(member.navigation_source)
		var endpoint: Vector3=member.nav_endpoint if has_navigation else goal
		if (not has_navigation or member.nav_status in ["following","arrived"]) and member.global_position.distance_to(endpoint)<2.0:
			returning_members.erase(member)

func _begin_wander(member: CharacterBody3D) -> void:
	# Discovery and one route request happen only at a staggered decision, never
	# every frame. Real extraction sites supply object positions when available.
	wander_cooldowns[member]=randf_range(20.0,33.0)+maxi(0,members.find(member))*.4
	if not is_instance_valid(member.navigation_source): return
	var interest: Dictionary=_wander_interest(member)
	if interest.is_empty(): return
	member.nav_refresh=0.0
	member.steering_point(interest.goal)
	var endpoint: Vector3=member.nav_endpoint
	if member.nav_status not in ["following","arrived"] or not endpoint.is_finite() or endpoint.distance_to(leader.global_position)>PATROL_BUBBLE or endpoint.distance_to(member.global_position)<2.0 or endpoint.distance_to(interest.goal)>3.0:
		member.nav_refresh=0.0
		return
	interest.goal=endpoint
	interest.remaining=randf_range(12.0,16.0)
	interest.phase="wander"
	interest.inspect_remaining=randf_range(2.0,4.0)
	interest.look_time=0.0
	wanderers[member]=interest

func _wander_interest(member: CharacterBody3D) -> Dictionary:
	var source: Node=member.navigation_source
	var sites: Array=[]
	for property: Dictionary in source.get_property_list():
		if property.name=="sites":
			var value: Variant=source.get("sites")
			if value is Array: sites=value
			break
	for index: int in mini(64,sites.size()):
		var site: Dictionary=sites[index]
		if not site.get("position") is Vector3: continue
		var point: Vector3=site.position
		var away: Vector3=member.global_position-point;away.y=0.0
		if away.length()<.1: continue
		var goal: Vector3=point+away.normalized()*1.5;goal.y=member.global_position.y
		var distance: float=goal.distance_to(member.global_position)
		if distance>=4.0 and distance<=8.0 and goal.distance_to(leader.global_position)<10.0:
			return {"goal":goal,"look":point,"kind":"object","label":str(site.get("title","nearby site"))}
	# No nearby authored interaction: a short ground excursion and look around.
	for _attempt: int in 4:
		var angle: float=randf_range(0.0,TAU)
		var goal: Vector3=member.global_position+Vector3(sin(angle),0,cos(angle))*randf_range(4.0,8.0)
		if goal.distance_to(leader.global_position)<10.0:
			return {"goal":goal,"look":goal+Vector3(sin(angle),0,cos(angle))*2.0,"kind":"ground_look","label":"nearby ground"}
	return {}

func _update_wander(member: CharacterBody3D, alive: Array[CharacterBody3D], delta: float) -> bool:
	var state: Dictionary=wanderers[member]
	state.remaining=float(state.remaining)-delta
	if float(state.remaining)<=0.0:
		_end_wander(member)
		return false
	if state.phase=="inspect":
		state.inspect_remaining=float(state.inspect_remaining)-delta
		if float(state.inspect_remaining)<=0.0:
			_end_wander(member)
			return false
		state.look_time=float(state.look_time)+delta
		var offset: Vector3=member.global_basis.inverse()*((state.look as Vector3)-member.global_position)
		member.set_locomotion(0.0,atan2(offset.x,offset.z)*.8+sin(float(state.look_time)*1.7)*.15)
	else:
		_follow(member,state.goal,.45,alive)
		if member.nav_status in ["blocked","rejected"]:
			_end_wander(member)
			return false
		var endpoint: Vector3=member.nav_endpoint
		if member.nav_status=="arrived" or member.global_position.distance_to(endpoint)<.8:
			state.phase="inspect"
	return true

func _end_wander(member: CharacterBody3D) -> void:
	if not wanderers.has(member): return
	wanderers.erase(member)
	returning_members[member]=true
	wander_cooldowns[member]=randf_range(20.0,33.0)+maxi(0,members.find(member))*.4
	member.nav_refresh=0.0

func _follow(member: CharacterBody3D, goal: Vector3, top_speed: float, alive: Array[CharacterBody3D]) -> void:
	goal=member.steering_point(goal)
	var offset:=goal-member.global_position;offset.y=0
	var distance:=offset.length()
	if distance<.18: member.set_locomotion(0,0);return
	var local:=member.global_basis.inverse()*offset
	var yaw:=atan2(local.x,local.z)
	var speed:=top_speed*clampf(1.0-absf(yaw)*1.2,0,1)*clampf(distance/.8,0,1)
	# Brake before a packmate, keeping a clear footprint during turns/reforming.
	for other in alive:
		if other==member: continue
		var separation:=other.global_position-member.global_position;separation.y=0
		if separation.length()<1.9 and member.global_basis.z.dot(separation.normalized())>.45: speed=0
	member.set_combat_locomotion(speed,yield_strafe(member),yaw*.8)

func combat_goal(member: CharacterBody3D, observed_point: Vector3) -> Vector3:
	# Roles supply destinations only while a real pack sighting is fresh.
	# Awareness still owns sight/last-known memory, and the native motor validates
	# every requested route. A role never reserves or vetoes a legal attack.
	if is_backline_gunner(member):
		# Keep a checked world waypoint; a moving observed contact can invalidate
		# it, but only the bounded planner may replace it. Hidden motion is unused.
		var range_to_goal: float=INF if not gunner_goal.is_finite() else Vector2(gunner_goal.x-observed_point.x,gunner_goal.z-observed_point.z).length()
		return gunner_goal if range_to_goal>=GUNNER_MIN_RANGE and range_to_goal<=GUNNER_MAX_RANGE else member.global_position
	if contact_age<=ROLE_CONTACT_MEMORY:
		var approach_goal:=observed_point
		if combat_roles.has(member):
			approach_goal+=combat_roles[member].offset as Vector3
		if _claim_melee_pressure(member,observed_point,approach_goal): return observed_point
		if combat_roles.has(member): return approach_goal
	# Only two packmates make a modest approach arc. Close combat remains driven
	# by the actual perceived contact, rather than by invisible target tracking.
	var index:=members.find(member)
	var approach:=member.global_position-observed_point;approach.y=0
	if index not in [1,2] or approach.length()<1.8: return observed_point
	var lead_position:=leader.global_position if is_instance_valid(leader) else member.global_position
	var axis:=lead_position-observed_point;axis.y=0
	if axis.length()<.1: axis=approach
	var side:=axis.normalized().cross(Vector3.UP)
	return observed_point+side*(2.1 if index==1 else -2.1)

func _update_melee_pressure(alive: Array[CharacterBody3D]) -> void:
	if contact_age>ROLE_CONTACT_MEMORY or not is_instance_valid(target):
		melee_pressers.clear();return
	if target.has_method("is_combat_alive") and not target.is_combat_alive():
		melee_pressers.clear();return
	for member in melee_pressers.duplicate():
		if member not in alive:
			melee_pressers.erase(member);continue
		if member==gunner or member==attack_owner or member.mobility<=0.0 or member.mode in ["FACE_ATTACHED","DISABLED","CLIMB","ATTACH","DETACH"]:
			melee_pressers.erase(member);continue
		if member.mode=="GROUND" and (member.combat.recovery>0.0 or member.cooldown>0.0 or member.nav_status in ["blocked","rejected"]):
			melee_pressers.erase(member)

func _claim_melee_pressure(member: CharacterBody3D, contact: Vector3, role_goal: Vector3) -> bool:
	if is_backline_gunner(member): return false
	if melee_pressers.has(member): return true
	if not is_instance_valid(member) or member not in members or member.dead: return false
	if member==attack_owner or member.mode!="GROUND" or member.mobility<=0.0: return false
	if member.combat.recovery>0.0 or member.cooldown>0.0 or member.nav_status in ["blocked","rejected"]: return false
	# A crippled front pair cannot slash; retain its reachable support role.
	if member.health.leg_hp.FL<=0.0 or member.health.leg_hp.FR<=0.0: return false
	# Every free nongunner may close together. Actual strike admission below
	# retains the two-native-attacker limit, recovery gaps and peer corridor veto.
	var range_to_contact:=Vector2(contact.x-member.global_position.x,contact.z-member.global_position.z).length()
	var range_to_role:=Vector2(role_goal.x-member.global_position.x,role_goal.z-member.global_position.z).length()
	# A flank is an approach waypoint, never a permanent waiting position.
	# During a gun windup, nearby free peers commit immediately. Otherwise
	# finish the approach arc or close once already inside striking distance.
	if range_to_role>1.0 and (range_to_contact>6.0 or (range_to_contact>3.5 and not is_instance_valid(attack_owner))): return false
	melee_pressers.append(member)
	member.nav_refresh=0.0
	return true

func _record_role_observation(point: Vector3) -> void:
	if not point.is_finite(): return
	var seconds:=float(Engine.get_physics_frames())/float(Engine.physics_ticks_per_second)
	if observation_seconds>=0.0 and seconds>observation_seconds:
		var interval:=seconds-observation_seconds
		observed_velocity=(point-observed_contact)/interval if interval<=ROLE_CONTACT_MEMORY else Vector3.ZERO
		observed_velocity.y=0.0
		observed_velocity=observed_velocity.limit_length(ROLE_MAX_OBSERVED_SPEED)
	elif observation_seconds<0.0:
		observed_velocity=Vector3.ZERO
	observed_contact=point;observation_seconds=seconds;contact_age=0.0

func _release_combat_role(member: CharacterBody3D, reject: bool = false) -> void:
	if not combat_roles.has(member): return
	var state: Dictionary=combat_roles[member]
	if role_holders.get(state.role)==member: role_holders.erase(state.role)
	if reject:
		melee_pressers.erase(member)
		var rejected: Dictionary=role_rejections.get(member,{})
		rejected[state.role]=role_clock+.9;role_rejections[member]=rejected
	combat_roles.erase(member);role_handoffs+=1

func _update_combat_roles(delta: float, alive: Array[CharacterBody3D]) -> void:
	role_clock+=delta;contact_age+=delta
	role_last_probe_count=0
	for member in role_rejections.keys():
		if member not in alive: role_rejections.erase(member)
	if alive.is_empty() or contact_age>ROLE_CONTACT_MEMORY:
		combat_roles.clear();role_holders.clear();observed_velocity=Vector3.ZERO
		role_scan_index=0;role_plan_wait=maxf(0.0,role_plan_wait-delta)
		# A replacement may use the saved contact point during SEARCH. This
		# neither samples the hidden target nor grants permission for a blind shot.
		if battle_active and is_instance_valid(gunner) and role_plan_wait<=0.0:
			role_plan_wait=ROLE_PLAN_INTERVAL;_plan_gunner_goal()
		return
	for member in combat_roles.keys():
		if member not in alive:
			_release_combat_role(member);continue
		if member==gunner or member.mobility<=0.0 or member.mode in ["FACE_ATTACHED","DISABLED","CLIMB","ATTACH","DETACH"]:
			_release_combat_role(member);continue
		# An active native attack/recovery completes without role reassignment.
		if member.mode!="GROUND": continue
		var state: Dictionary=combat_roles[member]
		var displacement: Vector3=member.global_position-(state.anchor as Vector3)
		var heading_change: float=absf(member.global_basis.z.signed_angle_to(state.heading as Vector3,Vector3.UP))
		if Vector2(displacement.x,displacement.z).length()>=.10 or heading_change>=.08:
			state.anchor=member.global_position;state.heading=member.global_basis.z;state.stall=0.0
		elif member.nav_status in ["blocked","rejected"]:
			state.stall=float(state.stall)+delta*3.0
		elif member.nav_status=="following" and (observed_contact+(state.offset as Vector3)).distance_to(member.global_position)>1.0:
			state.stall=float(state.stall)+delta
		else: state.stall=0.0
		if float(state.stall)>=2.0: _release_combat_role(member,true)
	role_plan_wait=maxf(0.0,role_plan_wait-delta)
	if role_plan_wait>0.0: return
	role_plan_wait=ROLE_PLAN_INTERVAL
	if battle_active:
		if not is_instance_valid(gunner): _select_gunner(alive)
		_plan_gunner_goal()
	var role_name: String=COMBAT_ROLE_NAMES[role_scan_index%COMBAT_ROLE_NAMES.size()]
	role_scan_index+=1
	# Replace the pressure holder promptly; other roles rotate on this fixed budget.
	if not role_holders.has("pressure") and role_scan_index%2==0: role_name="pressure"
	var holder: CharacterBody3D=role_holders.get(role_name) as CharacterBody3D
	if is_instance_valid(holder) and combat_roles.has(holder):
		var held: Dictionary=combat_roles[holder]
		if holder.mode!="GROUND" or float(held.lease_until)>role_clock: return
	if role_name=="pressure":
		var reference: Vector3=holder.global_position if is_instance_valid(holder) else alive[0].global_position
		var axis:=reference-observed_contact;axis.y=0.0
		if axis.length()>.1: role_axis=axis.normalized()
	var ranked: Array[Dictionary]=[]
	for member in alive:
		if member==gunner or member.mobility<=0.0 or member.mode!="GROUND" or not is_instance_valid(member.navigation_source): continue
		var rejected: Dictionary=role_rejections.get(member,{})
		if float(rejected.get(role_name,0.0))>role_clock: continue
		var held: Dictionary=combat_roles.get(member,{})
		if not held.is_empty() and held.role!=role_name and float(held.lease_until)>role_clock and role_name!="pressure": continue
		var goal:=_combat_role_goal(role_name,member)
		var score:=_combat_role_score(role_name,member,goal)
		if not held.is_empty() and held.role!=role_name: score+=6.0
		if member==holder: score-=2.0
		ranked.append({"member":member,"goal":goal,"score":score})
	ranked.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.score)<float(b.score))
	for index: int in mini(2-role_last_probe_count,ranked.size()):
		var choice: Dictionary=ranked[index]
		var member: CharacterBody3D=choice.member
		role_last_probe_count+=1;role_probe_count+=1
		var accepted: Dictionary=_combat_role_route(member,choice.goal,role_name)
		role_peak_probe_count=maxi(role_peak_probe_count,role_last_probe_count)
		if accepted.is_empty():
			var rejected: Dictionary=role_rejections.get(member,{})
			rejected[role_name]=role_clock+2.0;role_rejections[member]=rejected
			continue
		if is_instance_valid(holder) and holder!=member: _release_combat_role(holder)
		if combat_roles.has(member) and combat_roles[member].role!=role_name: _release_combat_role(member)
		var label: String=role_name
		if member.mobility<1.0 and role_name!="pressure": label="support_"+("left" if role_name.ends_with("left") else "right")
		combat_roles[member]={"role":role_name,"label":label,"offset":(accepted.goal as Vector3)-observed_contact,"lease_until":role_clock+ROLE_LEASE_SECONDS,"anchor":member.global_position,"heading":member.global_basis.z,"stall":0.0,"score":choice.score}
		role_holders[role_name]=member
		return

func _combat_role_goal(role_name: String, member: CharacterBody3D) -> Vector3:
	var side:=role_axis.cross(Vector3.UP)
	var sign:=1.0 if role_name.ends_with("left") else -1.0
	if role_name=="pressure": return observed_contact+role_axis*3.1
	if member.mobility<1.0:
		return observed_contact+role_axis*(4.4 if role_name.begins_with("cutoff") else 2.8)+side*sign*(4.2 if role_name.begins_with("cutoff") else 2.6)
	if role_name.begins_with("flank"):
		return observed_contact+role_axis*.6+side*sign*3.5
	# Lead only the last actually observed motion, capped at2.5m. A still target
	# gets a wider side approach rather than a forced rear encirclement.
	var lead:=observed_velocity*.65
	lead=lead.limit_length(2.5)
	return observed_contact+lead+role_axis*2.8+side*sign*4.7

func _combat_role_score(role_name: String, member: CharacterBody3D, goal: Vector3) -> float:
	var distance:=Vector2(goal.x-member.global_position.x,goal.z-member.global_position.z).length()
	var score:=distance/maxf(.25,member.mobility)
	score+=(1.0-clampf(member.health.body_hp/100.0,0.0,1.0))*2.0
	if role_name.begins_with("flank") and member.mobility<1.0: score+=12.0
	if member.nav_status in ["blocked","rejected"]: score+=4.0
	if role_name=="pressure":
		score+=minf(3.5,member.combat.stun_cooldown)*.5
		var brain: Node=member.get_node("Awareness")
		if brain.visible and member.combat.target_valid(brain.target):
			if member.combat._stun_lane_clear(brain.target): score-=2.0
	return score

func _combat_role_route(member: CharacterBody3D, goal: Vector3, replacing_role: String) -> Dictionary:
	# The production wrapper rejects closed gates/doors. Native footprint/floor
	# probes reject occupied or unsupported destinations and blocked first links.
	var path: PackedVector3Array=member.navigation_source.get_path_world(member.global_position,goal)
	if path.is_empty(): return {}
	var graph_endpoint: Vector3=path[-1]
	if not graph_endpoint.is_finite(): return {}
	# The graph has 4m cells. A valid tactical goal can lie farther than
	# 1.5m from its vertex; finish only through a complete native connector.
	var incoming:=member.global_basis.z
	if path.size()>1:
		incoming=graph_endpoint-path[-2];incoming.y=0.0
	if not member._navigation_link_clear(graph_endpoint,goal,incoming): return {}
	var endpoint:=goal
	var heading:=observed_contact-endpoint;heading.y=0.0
	if heading.length()<.1: heading=member.global_basis.z
	if not member._navigation_link_clear(endpoint,endpoint,heading.normalized(),true): return {}
	for point: Vector3 in path:
		if Vector2(point.x-member.global_position.x,point.z-member.global_position.z).length()<.3: continue
		if not member._navigation_link_clear(member.global_position,point): return {}
		break
	# Distinct roles must not choose overlapping actual destination footprints.
	for other in combat_roles.keys():
		if other==member or combat_roles[other].role==replacing_role: continue
		var other_goal: Vector3=observed_contact+(combat_roles[other].offset as Vector3)
		if Vector2(endpoint.x-other_goal.x,endpoint.z-other_goal.z).length()<1.8: return {}
	if member!=gunner and is_instance_valid(gunner) and gunner_goal.is_finite() and Vector2(endpoint.x-gunner_goal.x,endpoint.z-gunner_goal.z).length()<1.8: return {}
	return {"goal":endpoint}

func combat_role_diagnostics() -> Dictionary:
	var rows: Array[Dictionary]=[]
	for member in combat_roles.keys():
		if not is_instance_valid(member): continue
		var state: Dictionary=combat_roles[member]
		rows.append({"member":members.find(member),"role":state.label,"goal":observed_contact+(state.offset as Vector3),"lease_remaining":maxf(0.0,float(state.lease_until)-role_clock),"stall":state.stall,"nav":member.nav_status,"score":state.score})
	return {"roles":rows,"contact_age":contact_age,"last_seen":observed_contact,"observed_velocity":observed_velocity,"last_probe_count":role_last_probe_count,"peak_probe_count":role_peak_probe_count,"total_route_probes":role_probe_count,"handoffs":role_handoffs,"battle_active":battle_active,"battle_elapsed":battle_elapsed,"gunner":members.find(gunner) if is_instance_valid(gunner) else -1,"gunner_goal":gunner_goal,"gunner_handoffs":gunner_handoffs}

func limit_approach(member: CharacterBody3D, command: float) -> float:
	if command<=0: return command
	for other in living_members():
		if other==member: continue
		var offset:=other.global_position-member.global_position;offset.y=0
		if offset.length()<2.3 and member.global_basis.z.dot(offset.normalized())>.45:
			command*=clampf((offset.length()-1.6)/.7,0,1)
	return command

func yield_strafe(member: CharacterBody3D) -> float:
	# A trailing drone steps around its nearest blocker. Only opposing traffic
	# uses stable member order; crossing approaches must still be able to yield.
	var index:=members.find(member)
	var nearest:=INF
	var command:=0.0
	for other in living_members():
		if other==member: continue
		var opposing:=member.global_basis.z.dot(other.global_basis.z)<-.5
		# A stationary, navigation-blocked peer cannot take its usual avoidance
		# turn. Let the active walker use the same bounded physical sidestep;
		# normal opposing traffic still yields by stable member order.
		var blocked_peer: bool=other.mode=="GROUND" and other.nav_status=="blocked" and Vector2(other.velocity.x,other.velocity.z).length()<.12
		if opposing and members.find(other)>index and not blocked_peer: continue
		var local:=member.global_basis.inverse()*(other.global_position-member.global_position)
		if local.z>0 and local.length()<2.3 and local.normalized().z>.45:
			if local.length_squared()<nearest:
				nearest=local.length_squared()
				command=-.16 if local.x>.05 else .16
	return command

func request_attack(member: CharacterBody3D, candidate: Node3D, attack_kind: String = "") -> bool:
	if member not in members or member.dead or not is_instance_valid(candidate): return false
	if attack_kind=="StunShot" and (candidate!=target or not can_start_stun(member)): return false
	if attack_kind!="StunShot" and is_backline_gunner(member): return false
	# Stun uses one exclusive telegraph/discharge slot. Native melee can proceed
	# alongside it, with at most two attackers and the existing peer corridor veto.
	if attack_kind!="StunShot":
		attack_queue.erase(member)
		var start:=member.global_position;var end:=candidate.global_position
		for other in living_members():
			if other==member: continue
			var nearest:=Geometry3D.get_closest_point_to_segment(other.global_position,start,end)
			if nearest.distance_to(start)>.6 and nearest.distance_to(end)>.5 and nearest.distance_to(other.global_position)<1.05:
				melee_queue.erase(member);request_age.erase(member)
				return false
		if melee_owners.has(member) or float(melee_gaps.get(member,0.0))>0.0: return false
		if not melee_queue.has(member): melee_queue.append(member)
		request_age[member]=0.0
		if melee_owners.size()>=MAX_ACTIVE_MELEE: return false
		if melee_queue.size()>1 and melee_queue[0]==last_melee_attacker:
			melee_queue.append(melee_queue.pop_front())
		if melee_queue[0]!=member: return false
		melee_owners.append(member);last_melee_attacker=member
		melee_queue.erase(member);request_age.erase(member)
		return true
	melee_queue.erase(member)
	if melee_owners.has(member): return false
	if not attack_queue.has(member): attack_queue.append(member)
	request_age[member]=0.0
	if is_instance_valid(attack_owner) or attack_gap>0 or stun_gap>0: return false
	if attack_queue.size()>1 and attack_queue[0]==last_attacker:
		attack_queue.append(attack_queue.pop_front())
	if attack_queue[0]!=member: return false
	melee_pressers.erase(member)
	attack_owner=member;last_attacker=member
	attack_queue.erase(member);request_age.erase(member)
	return true

func attack_finished_by(member: CharacterBody3D) -> void:
	melee_pressers.erase(member)
	attack_queue.erase(member);melee_queue.erase(member);request_age.erase(member)
	if melee_owners.has(member):
		melee_owners.erase(member);melee_gaps[member]=.6
	if attack_owner==member:
		attack_owner=null;attack_gap=.6

func can_start_stun(member: CharacterBody3D = null) -> bool:
	if not battle_active or battle_elapsed<BATTLE_OPENING_SECONDS or stun_gap>0.0 or not is_instance_valid(gunner): return false
	if not is_instance_valid(target) or target.get_instance_id()!=battle_target_id or (target.has_method("is_combat_alive") and not target.is_combat_alive()): return false
	if member!=null and member!=gunner: return false
	if gunner.dead or gunner.mobility<=0.0 or not gunner_goal.is_finite(): return false
	var distance:=Vector2(gunner.global_position.x-observed_contact.x,gunner.global_position.z-observed_contact.z).length()
	return distance>=GUNNER_MIN_RANGE

func register_stun_fire(member: CharacterBody3D) -> bool:
	if attack_owner!=member or not can_start_stun(member): return false
	stun_gap=STUN_PACK_COOLDOWN
	return true
