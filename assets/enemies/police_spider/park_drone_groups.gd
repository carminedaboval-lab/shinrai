extends Node3D
## Three production patrol groups. Keep world scale independent of park layout scale.
const PACK = preload("Shinrai_Drone_Pack.tscn")
var raid: Node
var groups: Array[Node3D]=[]
var spawn_report: Array[Dictionary]=[]

func _ready() -> void:
	top_level=true;global_transform=Transform3D.IDENTITY
	add_to_group("police_drone_directors")
	_update_player_capsule()
	var preferred: Array[Vector3]=[]
	var entry: Dictionary=raid._find_visible_entry_guard_position()
	preferred.append(entry.get("position",raid.player.global_position-raid.player.global_basis.z*24))
	for site: Dictionary in raid.sites:
		if site.kind=="relay": preferred.append(site.position)
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
	if not groups.is_empty():
		var p: Vector3=groups[0].global_position
		raid.player.look_at(Vector3(p.x,raid.player.global_position.y,p.z))

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
		if Vector2(candidate.x-raid.player.position.x,candidate.z-raid.player.position.z).length()<18: continue
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
			var overlap:=false
			for other in placement:
				if at.distance_to(other)<2.2: overlap=true
			if overlap: break
			placement.append(at)
		if placement.size()==count: return placement
	return []
