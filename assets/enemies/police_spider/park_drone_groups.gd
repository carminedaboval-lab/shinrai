extends Node3D
## Three production patrol groups. Keep world scale independent of park layout scale.
const PACK = preload("Shinrai_Drone_Pack.tscn")
var raid: Node
var groups: Array[Node3D]=[]
var spawn_report: Array[Dictionary]=[]
const BACKUP_RANGE := 420.0
# Route length a pack can cover inside its dispatch time at its measured 1.9 m/s.
const BACKUP_ROUTE_RANGE := 460.0
const BACKUP_COOLDOWN := 45.0
const WARNING_COOLDOWN := 30.0
const BACKUP_UPDATE_SECONDS := 8.0
const BACKUP_UPDATE_MOVE := 15.0
var backup_update_at := 0.0
var backup_ready_at := 0.0
var warning_ready_at := 0.0

func _ready() -> void:
	top_level=true;global_transform=Transform3D.IDENTITY
	add_to_group("police_drone_directors")
	_update_player_capsule()
	# Packs guard the relays rather than the insertion point: a new raid should
	# start quiet enough to orient, and the first contact comes on the way in.
	var preferred: Array[Vector3]=[]
	for site: Dictionary in raid.sites:
		if site.kind=="relay": preferred.append(site.position)
	if preferred.is_empty():
		preferred.append(raid.player.global_position-raid.player.global_basis.z*60)
	for i in 3:
		var placement:=_find_formation(preferred[mini(i,preferred.size()-1)],3+i)
		if placement.is_empty():
			push_error("Police drone group %d has no safe formation placement" % (i+1));continue
		var pack: Node3D=PACK.instantiate();pack.name="PoliceDroneGroup%d" % (i+1)
		pack.spawn_on_ready=false;pack.roam_enabled=true;pack.target=raid.player;add_child(pack)
		pack.global_position=placement[0];pack.spawn_pack(3+i)
		for j in pack.members.size():
			var actor: CharacterBody3D=pack.members[j]
			actor.global_position=placement[j];actor.navigation_source=raid
			actor.name="PoliceDrone_%d_%d" % [i+1,j+1]
			actor.add_to_group("extraction_hostiles");actor.add_to_group("police_spider_drones")
			actor.visual.reset_contacts()
			pack.slots[actor]=actor.global_position-pack.global_position
		var anchor: Vector3=pack.global_position
		pack.route.assign([raid.navigation.nearest(anchor+Vector3(0,0,12)),anchor,raid.navigation.nearest(anchor+Vector3(12,0,0)),anchor])
		groups.append(pack)
		spawn_report.append({"name":pack.name,"count":pack.members.size(),"anchor":str(anchor)})
	print("POLICE_DRONE_GROUPS ",JSON.stringify(spawn_report))

## The warning before force: tells the player a drone is identifying them, while
## there is still about a second to break line of sight.
func police_warning(contact: Node) -> void:
	var now: float=float(raid.run_time)
	if contact!=raid.player or now<warning_ready_at: return
	warning_ready_at=now+WARNING_COOLDOWN
	raid.announce("POLICE  ·  You are being identified. Break line of sight",3.0)

## One pack at a time answers a contact, on a raid-wide cooldown, so backup adds
## pressure and a warning without the whole park converging on the player.
func request_backup(caller: Node3D, point: Vector3) -> void:
	var now: float=float(raid.run_time)
	if now<backup_ready_at or not point.is_finite(): return
	# A wiped-out pack keeps its old goal, so only living responders count.
	for pack: Node3D in groups:
		if is_instance_valid(pack) and pack.backup_goal.is_finite() and not pack.living_members().is_empty(): return
	var goal: Vector3=raid.navigation.nearest(point)
	var candidates: Array[Dictionary]=[]
	for pack: Node3D in groups:
		if pack==caller or not is_instance_valid(pack) or not pack.is_available_for_dispatch(): continue
		var distance: float=pack.living_members()[0].global_position.distance_to(point)
		if distance<BACKUP_RANGE: candidates.append({"pack":pack,"distance":distance})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.distance<b.distance)
	# Commit only to a pack with a real route: the player is told help is coming.
	for row: Dictionary in candidates:
		var path: PackedVector3Array=raid.get_path_world(row.pack.living_members()[0].global_position,goal)
		if path.is_empty() or _path_length(path)>BACKUP_ROUTE_RANGE: continue
		backup_ready_at=now+BACKUP_COOLDOWN
		row.pack.dispatch_to(goal)
		raid.announce("DISPATCH  ·  Police backup responding to your position",4.5)
		return

## Sightings keep a responding pack on the live contact, so a player who has moved
## on is not simply left behind by a run to the first report.
func contact_update(point: Vector3) -> void:
	var now: float=float(raid.run_time)
	if now<backup_update_at or not point.is_finite(): return
	backup_update_at=now+BACKUP_UPDATE_SECONDS
	for pack: Node3D in groups:
		if not is_instance_valid(pack) or not pack.backup_goal.is_finite() or pack.living_members().is_empty(): continue
		var goal: Vector3=raid.navigation.nearest(point)
		if pack.backup_goal.distance_to(goal)<BACKUP_UPDATE_MOVE: continue
		# An unreachable sighting keeps the pack on the route it already has.
		if raid.get_path_world(pack.living_members()[0].global_position,goal).is_empty(): continue
		pack.update_dispatch(goal)

func _path_length(path: PackedVector3Array) -> float:
	var total:=0.0
	for index: int in range(1,path.size()): total+=path[index-1].distance_to(path[index])
	return total

func _process(_delta: float) -> void:
	_update_player_capsule()
	for pack in groups:
		pack.set_physics_process(raid.phase==raid.Phase.RAID)

func _update_player_capsule() -> void:
	var player: CharacterBody3D=raid.player
	player.set_meta("combat_capsule_radius",player.body_capsule.radius)
	player.set_meta("combat_capsule_height",player.body_capsule.height)
	player.set_meta("combat_capsule_center_y",player.body_collision.position.y)

func _find_formation(preferred: Vector3,count: int) -> Array[Vector3]:
	var candidates: Array[Vector3]=[]
	for id: int in raid.navigation.walk_graph.get_point_ids():
		var point: Vector2=raid.navigation.walk_graph.get_point_position(id)
		candidates.append(Vector3(point.x,preferred.y,point.y))
	candidates.sort_custom(func(a: Vector3,b: Vector3)->bool:return a.distance_squared_to(preferred)<b.distance_squared_to(preferred))
	for candidate in candidates:
		if Vector2(candidate.x-raid.player.position.x,candidate.z-raid.player.position.z).length()<40: continue
		var too_close:=false
		for pack in groups:
			if candidate.distance_to(pack.global_position)<45: too_close=true
		if too_close: continue
		var placement: Array[Vector3]=[]
		for j in count:
			var offset:=Vector3.ZERO if j==0 else Vector3((-1 if j%2==1 else 1)*3,0,-ceilf(float(j)/2)*3)
			var at: Vector3=raid.navigation.nearest(candidate+offset)
			var query:=PhysicsShapeQueryParameters3D.new();var box:=BoxShape3D.new();box.size=Vector3(1.8,.74,1.5)
			query.shape=box;query.collision_mask=1;query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*.38)
			if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): break
			# Reject a spot overhanging an edge: a drone spawned there can never leave.
			var flat:=Vector2(at.x,at.z)
			var supported:=true
			for corner: Vector2 in [Vector2(.7,.5),Vector2(-.7,.5),Vector2(.7,-.5),Vector2(-.7,-.5)]:
				if not raid.navigation._can_walk_floor(flat+corner,flat): supported=false
			if not supported: break
			var overlap:=false
			for other in placement:
				if at.distance_to(other)<2.2: overlap=true
			if overlap: break
			placement.append(at)
		if placement.size()==count: return placement
	return []
