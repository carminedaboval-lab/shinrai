extends Node3D
## Exactly one three-person crew. Contact reports carry a last known point,
## never a visibility exemption or a free shot through cover.
const Scav=preload("./scav_enemy.gd")
const Tactics=preload("./scav_tactics.gd")
const Concealment=preload("./scav_concealment.gd")
const TownNavigation=preload("./scav_town_navigation.gd")
const Activity=preload("./scav_activity.gd")
const Social=preload("./scav_social.gd")
const ROLES: Array[String]=["leader","scout","rear_guard"]
var raid: Node
var asset_root: String="res://assets/enemies/scavs"
var members: Array[CharacterBody3D]=[]
var route: Array[Vector3]=[]
var spawn_report: Dictionary={}
var _leader: CharacterBody3D
var _formation_elapsed:=0.0
var _formation_goals: Dictionary={}
var tactics: RefCounted
var concealment: Node3D
var hostile:=false
var warning_active:=false
var warning_distance:=INF
var warning_started: float=-100.0
var warning_clear_time:=0.0
var _aim_threat_time: Dictionary={}
var encounter_started: float=INF
var last_visual_report: float=-100.0
var casualties: Array[Dictionary]=[]
var morale_broken:=false
var warning_anchor:=Vector3.ZERO
var _step_distance:=0.0
var town_navigation: RefCounted
var activity: RefCounted
var ready_for_use:=false
var social: RefCounted
var navigation: RefCounted:
	get:return town_navigation if town_navigation!=null else raid.get("navigation")


func _ready() -> void:
	top_level=true
	global_transform=Transform3D.IDENTITY
	add_to_group("scav_squad_directors")
	tactics=Tactics.new()
	tactics.setup(self)
	var street:=get_parent().get_node_or_null("MidoriSouthStreet") as Node3D
	if street!=null and street.get("installed")==true:
		activity=Activity.new()
		var stock_bounds: Array[AABB]=activity.discover(street)
		if stock_bounds.size()>=2:
			town_navigation=TownNavigation.new()
			await town_navigation.build(raid,stock_bounds)
			if not town_navigation.ready:town_navigation=null;activity=null
		else:activity=null
	concealment=Concealment.new()
	concealment.name="HumanConcealment"
	add_child(concealment)
	concealment.setup(get_parent())
	if not _spawn():push_error("SCAV_SQUAD: no safe connected spawn for the three-person crew")
	elif activity!=null and activity.setup(self):
		for actor: CharacterBody3D in members:
			actor.global_position=activity.guard_post if actor==activity.guard else activity.sites[activity.jobs[actor].site].point
			actor.rotation.y=0
		spawn_report.mode="town_looting";spawn_report.stock_sites=activity.sites.size();spawn_report.patrol_routes=activity.routes.size();spawn_report.navigation=town_navigation.report
	else:activity=null
	social=Social.new();social.setup(self)
	ready_for_use=true
	print("SCAV_ACTIVITIES ",JSON.stringify(spawn_report))

func _spawn() -> bool:
	for role: String in ROLES:
		if not (ResourceLoader.exists(_model(role)) if asset_root.begins_with("res://") else FileAccess.file_exists(_model(role))): return false
	var placement:=_find_placement(Vector3(0,.1,190) if town_navigation!=null else Vector3(-48,.2,140))
	if placement.is_empty(): return false
	route.assign(placement.route)
	for i: int in range(ROLES.size()):
		var actor:=Scav.new()
		actor.name="Scav_"+ROLES[i]
		actor.role=ROLES[i]
		actor.model_path=_model(ROLES[i])
		actor.squad=self
		actor.configure(raid.player,1,self,route)
		actor.position=placement.positions[i]
		actor.contact_reported.connect(_share_contact)
		actor.defeated.connect(_on_defeated)
		add_child(actor)
		members.append(actor)
	_leader=members[0]
	spawn_report={"count":members.size(),"roles":ROLES,"anchor":str(_leader.global_position),"patrol_points":route.size(),"models":ROLES.map(func(role: String)->String:return _model(role))}
	print("SCAV_SQUAD ",JSON.stringify(spawn_report))
	return members.size()==3

func _model(role: String) -> String:
	return asset_root.path_join("%s/scav_%s.glb"%[role,role])

func _clear_at(point: Vector3) -> bool:
	var capsule:=CapsuleShape3D.new()
	capsule.height=1.72
	capsule.radius=.36
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=capsule
	query.collision_mask=1|2
	query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.89)
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _find_placement(preferred: Vector3) -> Dictionary:
	var candidates: Array[Vector3]=[]
	for id: int in navigation.walk_graph.get_point_ids():
		var p: Vector2=navigation.walk_graph.get_point_position(id)
		if p.distance_to(Vector2(preferred.x,preferred.z))<55.0:
			candidates.append(Vector3(p.x,.2,p.y))
	candidates.sort_custom(func(a: Vector3,b: Vector3)->bool:return a.distance_squared_to(preferred)<b.distance_squared_to(preferred))
	for candidate: Vector3 in candidates:
		var anchor: Vector3=get_nearest_walkable_world(candidate)
		if anchor.distance_to(raid.player.global_position)<35.0: continue
		var points: Array[Vector3]=[]
		for offset: Vector3 in [Vector3.ZERO,Vector3(-4,0,-3),Vector3(4,0,3)]:
			var at: Vector3=get_nearest_walkable_world(anchor+offset)
			if not _clear_at(at): break
			var overlap:=false
			for other: Vector3 in points:
				if at.distance_to(other)<2.0: overlap=true
			if overlap: break
			if not points.is_empty() and get_path_world(points[0],at).is_empty(): break
			points.append(at)
		if points.size()!=3: continue
		var line: Array[Vector3]=[anchor]
		for offset: Vector3 in [Vector3(-8,0,-16),Vector3(-20,0,-4),Vector3(0,0,0)]:
			var at: Vector3=get_nearest_walkable_world(anchor+offset)
			if at.distance_to(line[-1])<5.0 or get_path_world(line[-1],at).is_empty(): break
			line.append(at)
		if line.size()==4: return {"positions":points,"route":line}
	return {}

func leader() -> CharacterBody3D:
	if is_instance_valid(_leader) and not _leader.dead: return _leader
	for actor: CharacterBody3D in members:
		if is_instance_valid(actor) and not actor.dead:
			_leader=actor
			return actor
	return null

func _physics_process(delta: float) -> void:
	if not ready_for_use:return
	if raid.phase!=raid.Phase.RAID: return
	if hostile and not morale_broken: tactics.tick(delta)
	else: tactics.clock+=delta
	_update_warning(delta)
	_hear_player_steps(delta)
	if activity!=null:
		if hostile or morale_broken:activity.interrupt("combat")
		else:activity.tick(delta)
	if social!=null:social.tick(delta)
	_formation_elapsed-=delta
	if _formation_elapsed>0.0: return
	_formation_elapsed=.6
	var lead:=leader()
	if lead==null: return
	for actor: CharacterBody3D in members:
		if not is_instance_valid(actor) or actor.dead or actor==lead: continue
		var offset:=Vector3(-2.5,0,-3.0) if actor.role=="scout" else Vector3(2.5,0,3.5)
		_formation_goals[actor]=get_nearest_walkable_world(lead.global_transform*offset)

func formation_point(actor: CharacterBody3D) -> Vector3:
	var lead:=leader()
	return _formation_goals.get(actor,lead.global_position if lead!=null else actor.global_position)

func separation(actor: CharacterBody3D) -> Vector3:
	var result:=Vector3.ZERO
	for other: CharacterBody3D in members:
		if not is_instance_valid(other) or other==actor or other.dead: continue
		var away:=actor.global_position-other.global_position
		away.y=0
		var distance:=away.length()
		if distance>.01 and distance<1.3: result+=away/distance*(1.3-distance)*2.0
	return result.limit_length(1.2)

func _share_contact(source: Node, point: Vector3) -> void:
	if not hostile or morale_broken: return
	last_visual_report=tactics.clock
	tactics.report(source,point,"visual")

func _update_warning(delta: float) -> void:
	if not warning_active or hostile or morale_broken: return
	var observed:=false
	for actor: CharacterBody3D in members:
		if is_instance_valid(actor) and not actor.dead and actor.own_visual_time<=delta:
			observed=true
			break
	# Retreat and lost sight must still clear a warning outside the 20m threat
	# callback. Advance once per crew tick, retaining a short absence grace.
	var distance:=Vector2(raid.player.global_position.x-warning_anchor.x,raid.player.global_position.z-warning_anchor.z).length()
	warning_clear_time=warning_clear_time+delta if not observed or distance>warning_distance+4.0 else 0.0
	if warning_clear_time>3.0:
		warning_active=false; warning_clear_time=0.0; warning_distance=INF
		warning_started=-100.0; warning_anchor=Vector3.ZERO; _aim_threat_time.clear()

func observe_player(actor: CharacterBody3D, visible: bool, delta: float) -> void:
	if morale_broken: return
	if not visible:
		_aim_threat_time.erase(actor)
		return
	if hostile:
		last_visual_report=tactics.clock
		return
	var player: Node3D=raid.player
	var distance:=Vector2(actor.global_position.x-player.global_position.x,actor.global_position.z-player.global_position.z).length()
	if distance>20.0:
		_aim_threat_time.erase(actor)
		return
	# A carried weapon is the normal player posture, not proof of an attack.
	# Escalate a personally observed aimed weapon only after a short reaction.
	var aimed: bool=_weapon_aimed_at(player,actor)
	_aim_threat_time[actor]=float(_aim_threat_time.get(actor,0.0))+delta if aimed else 0.0
	if not warning_active:
		warning_active=true
		warning_distance=distance
		warning_anchor=actor.global_position
		warning_started=tactics.clock
		_say(actor,"Back off. Keep your distance.")
		tactics.send(actor,"warning",{"player_distance":distance})
	if float(_aim_threat_time[actor])>=.65:
		make_hostile(actor,"weapon_aimed")
		return
	# Give the warning time to be read/heard. Standing still or backing away
	# never becomes hostile simply because a timer expired or a scav moved.
	if tactics.clock-warning_started>1.75 and Vector2(player.global_position.x-warning_anchor.x,player.global_position.z-warning_anchor.z).length()<warning_distance-clampf(warning_distance*.15,1.0,2.0):
		make_hostile(actor,"ignored_warning")

func _weapon_aimed_at(player: Node3D, actor: Node3D) -> bool:
	if player.has_method("is_weapon_lowered") and player.is_weapon_lowered(): return false
	if player.get("ads")!=true: return false
	var camera:=player.get("camera") as Camera3D
	if not is_instance_valid(camera): return false
	var direction: Vector3=actor.global_position+Vector3.UP*1.2-camera.global_position
	return direction.length_squared()>.01 and (-camera.global_basis.z).dot(direction.normalized())>.985

func _hear_player_steps(delta: float) -> void:
	var player: CharacterBody3D=raid.player
	if not player.is_on_floor() or bool(player.get("is_swimming")): return
	var speed:=Vector2(player.velocity.x,player.velocity.z).length()
	if speed<.4: return
	_step_distance+=speed*delta
	var crouched: bool=bool(player.get("crouching"))
	if _step_distance<(1.4 if crouched else 2.1): return
	_step_distance=0.0
	var radius: float=3.5 if crouched else 18.0 if bool(player.get("sprinting")) else 9.0
	for actor: CharacterBody3D in members:
		if not is_instance_valid(actor) or actor.dead or actor.surrendered or actor.fleeing: continue
		var muffled: bool=not tactics.sightline(actor.global_position+Vector3.UP,player.global_position+Vector3.UP)
		actor.hear_noise(player.global_position,radius*(.55 if muffled else 1.0))

func make_hostile(actor: CharacterBody3D, reason: String) -> void:
	if hostile or morale_broken: return
	hostile=true; encounter_started=tactics.clock
	# Seed only personally observed contact. A heard shot does not reveal a
	# hidden player's exact position or grant permission to shoot through walls.
	if actor._can_see_target():
		last_visual_report=tactics.clock
		tactics.on_hostile_contact(actor,raid.player.global_position)
	tactics.send(actor,"hostile",{"reason":reason})
	_say(actor,"You were warned!" if reason=="ignored_warning" else "Weapon on us!" if reason=="weapon_aimed" else "Taking fire!")

func player_fired() -> void:
	for actor: CharacterBody3D in members:
		if is_instance_valid(actor) and not actor.dead and actor.global_position.distance_to(raid.player.global_position)<65.0:
			make_hostile(actor,"gunfire")
			return

func _say(actor: Node3D, text: String) -> void:
	if social!=null:social.interrupt()
	if raid.has_method("announce"): raid.announce("SCAV: "+text,3.2)
	var caption:=Label3D.new()
	caption.text=text; caption.font_size=34; caption.pixel_size=.006
	caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	caption.no_depth_test=false; caption.position=Vector3(0,2.15,0)
	actor.add_child(caption)
	var caption_ref: WeakRef=weakref(caption)
	get_tree().create_timer(3.2,false).timeout.connect(func()->void:
		var live: Node=caption_ref.get_ref()
		if is_instance_valid(live): live.queue_free())

func _on_defeated(actor: Node) -> void:
	if social!=null:social.interrupt()
	if activity!=null:activity.interrupt("casualty")
	tactics.member_down(actor)
	casualties.append({"time":tactics.clock,"leader":actor.role=="leader","unlocated":last_visual_report<encounter_started})
	if casualties.size()>=2 and not morale_broken:
		var latest: Dictionary=casualties[-1]
		var previous: Dictionary=casualties[-2]
		if (float(latest.time)-float(previous.time)<=2.0 and (latest.leader or previous.leader)) or (latest.unlocated and previous.unlocated):
			_break_morale("leader_and_partner_lost" if latest.leader or previous.leader else "unseen_ambush")
	_formation_goals.erase(actor)
	if actor==_leader: _leader=null
	_formation_elapsed=0

func _break_morale(reason: String) -> void:
	morale_broken=true
	tactics._abort_flank("morale_broken")
	for survivor: CharacterBody3D in members:
		if not is_instance_valid(survivor) or survivor.dead: continue
		tactics.orders.erase(survivor)
		var info: Dictionary=tactics.contact(survivor)
		var threat: Vector3=info.get("point",survivor.last_seen_position)
		var escape:=PackedVector3Array()
		if survivor.health/survivor.max_health>.5:
			var away: Vector3=survivor.global_position-threat; away.y=0
			if away.length()<.1: away=-survivor.global_basis.z
			for turn: float in [0.0,-.7,.7]:
				var goal: Vector3=get_nearest_walkable_world(survivor.global_position+away.normalized().rotated(Vector3.UP,turn)*24.0)
				if goal.distance_to(threat)<survivor.global_position.distance_to(threat)+10.0: continue
				escape=tactics.path_to(survivor.global_position,goal,survivor)
				if not escape.is_empty(): break
		survivor.break_morale(escape)
		tactics.send(survivor,"flee" if not escape.is_empty() else "surrender",{"reason":reason})
		_say(survivor,"I'm leaving!" if not escape.is_empty() else "Don't shoot! I give up!")

func set_active(active: bool) -> void:
	if social!=null:social.set_active(active)
	if active and is_instance_valid(concealment): concealment.rebuild()
	process_mode=Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func get_nearest_walkable_world(point: Vector3) -> Vector3:
	return town_navigation.nearest(point) if town_navigation!=null else raid.get_nearest_walkable_world(point)
func get_path_world(from: Vector3,to: Vector3) -> PackedVector3Array:
	return town_navigation.path(from,to) if town_navigation!=null else raid.get_path_world(from,to)
func get_search_positions_world(point: Vector3,count: int=4) -> Array[Vector3]:
	var output: Array[Vector3]=[]
	for i: int in range(count):
		var angle:=float(i)*TAU/maxi(1,count)
		var goal:=get_nearest_walkable_world(point+Vector3(cos(angle),0,sin(angle))*5.0)
		if goal.is_finite():output.append(goal)
	return output
