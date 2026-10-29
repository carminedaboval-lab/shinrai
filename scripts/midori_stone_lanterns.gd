extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")
# Traditional garden lanterns. Coordinates are world metres under the scaled park.
const MODEL := "res://assets/shinrai/parks/midori_park/models/stone_lantern/kasuga_lantern.glb"
const FIRE := "res://scripts/stone_lantern_fire.gd"
const MEASUREMENTS := "res://assets/shinrai/parks/midori_park/models/stone_lantern/measurements.json"
const ANCHORS := [
	{"name":"LakesideGarden", "target":Vector2(13,9)},
	{"name":"WoodedGarden", "target":Vector2(17,31)},
	{"name":"NorthernIrisEdge", "target":Vector2(34,-124)},
	{"name":"NorthWoodlandTurn", "target":Vector2(12,-128)},
]
var installed := false
var report: Array[Dictionary] = []
var footprints: Array[Dictionary] = []
var removed_grass := 0
var park: Node3D
var terrain: Node
var gardens: Node
var flowers: Node
var desire: Node
var data: Dictionary
var obstacles: Array[AABB] = []
var candidate_base_y := 0.0

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	call_deferred("install")

func install() -> void:
	if installed: return
	park = get_parent()
	terrain = park.get_node("MidoriTerrain")
	gardens = park.get_node("MidoriGardenSpots")
	flowers = park.get_node("MidoriJapaneseFlowers")
	while not terrain.installed or not gardens.installed or not flowers.installed:
		await get_tree().process_frame
	# This child is created later by the understory service, not in the scene file.
	while park.get_node_or_null("MidoriDesirePaths")==null: await get_tree().process_frame
	desire = park.get_node("MidoriDesirePaths")
	while not desire.finished: await get_tree().process_frame
	# No fallback primitive: delivery requires the measured, approved real asset.
	assert(ResourceLoader.exists(MODEL),"Stone lantern model missing")
	data = JSON.parse_string(FileAccess.get_file_as_string(MEASUREMENTS))
	assert(data.has("fire_origin") and data.has("collision_parts"))
	_expand_clearance_for_collision()
	_index_obstacles()
	set_as_top_level(true)
	global_transform = Transform3D.IDENTITY
	var source := load(MODEL) as PackedScene
	for index: int in range(ANCHORS.size()):
		var spec: Dictionary = ANCHORS[index]
		var placement := _find_position(spec.target)
		if placement.is_empty():
			push_warning("No clear stone lantern position: "+spec.name)
			continue
		var p: Vector2 = placement.p
		var lamp := Node3D.new()
		lamp.name = spec.name
		add_child(lamp)
		lamp.position = Vector3(p.x,placement.base_y,p.y)
		# Actual measured front aperture (+Z) faces the nearest walking line.
		var toward: Vector2 = placement.path-p
		lamp.rotation.y = atan2(toward.x,toward.y)
		var model := source.instantiate() as Node3D
		lamp.add_child(model)
		var fire := load(FIRE).new() as Node3D
		fire.phase = index*2.399963
		fire.position = _v3(data.fire_origin)
		lamp.add_child(fire)
		var body := StaticBody3D.new()
		body.name = "StoneCollision"
		body.collision_layer = 1
		body.collision_mask = 1
		lamp.add_child(body)
		for part: Dictionary in data.collision_parts:
			var collider := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = _v3(part.size)
			collider.shape = box
			collider.position = _v3(part.centre)
			body.add_child(collider)
		footprints.append({"p":p,"radius":float(data.base_radius)})
		report.append({"name":spec.name,"position":lamp.position,"yaw":lamp.rotation.y,"path_distance_m":p.distance_to(placement.path),"base_height_spread_m":placement.spread,"fire_origin":fire.position})
	_trim_base_grass()
	installed = true
	print("STONE_LANTERNS_READY ",JSON.stringify({"placements":report,"removed_grass":removed_grass,"world_scale":global_basis.get_scale(),"local_lights":report.size()}))

func _v3(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

func _expand_clearance_for_collision() -> void:
	var radius: float = data.get("clearance_radius",data.base_radius)
	for part: Dictionary in data.collision_parts:
		var centre := _v3(part.centre)
		var half := _v3(part.size)*.5
		for x: float in [-1.0,1.0]:
			for z: float in [-1.0,1.0]:
				radius=maxf(radius,Vector2(centre.x+x*half.x,centre.z+z*half.z).length())
	data.clearance_radius=radius

func _nearest_path(p: Vector2) -> Dictionary:
	var nearest := Vector2.ZERO
	var distance := INF
	for route: PackedVector2Array in terrain.paths:
		for index: int in range(route.size()-1):
			var q := Geometry2D.get_closest_point_to_segment(p,route[index],route[index+1])
			var d := p.distance_to(q)
			if d<distance: distance=d;nearest=q
	return {"p":nearest,"distance":distance}

func _find_position(target: Vector2) -> Dictionary:
	# Prefer the authored pocket; relocate nearby instead of deleting planting.
	for search_radius: float in [2.5,8.0]:
		for attempt: int in range(384):
			var p := target+Vector2(1,0).rotated(attempt*2.399963)*sqrt(float(attempt)/383.0)*search_radius
			var route := _nearest_path(p)
			var spread := _clear(p,float(route.distance))
			if spread>=0 and _view_clear(p,route.p): return {"p":p,"path":route.p,"spread":spread,"base_y":candidate_base_y}
	return {}

func _clear(p: Vector2,path_distance: float) -> float:
	var radius: float = data.base_radius
	var roof_radius: float = data.get("clearance_radius",radius)
	# The park doubles authored paths too: use its actual width-aware query.
	if path_distance>7.0 or park._is_near_destination_path(p/park.LAYOUT_SCALE,(roof_radius+.45)/park.LAYOUT_SCALE): return -1
	for walk: Dictionary in park._bridge_walk_surfaces:
		if walk.kind!="landing": continue
		var polygon: PackedVector2Array = walk.spec.footprint
		if Geometry2D.is_point_in_polygon(p,polygon): return -1
		for side: int in range(polygon.size()):
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,polygon[side],polygon[(side+1)%polygon.size()]))<roof_radius+.45: return -1
	if terrain.water_at(p) or terrain.edge_distance(p,terrain.shoreline)<radius+1.2: return -1
	if desire != null and desire.distance_to_path(p)<radius+1.3: return -1
	for trunk: Vector2 in park.occupied_tree_positions:
		if p.distance_to(trunk*park.LAYOUT_SCALE)<radius+1.4: return -1
	for footprint: Dictionary in gardens.footprints:
		if p.distance_to(footprint.p)<radius+float(footprint.radius)+.45: return -1
	if flowers._inside_colony(p,radius+.45): return -1
	for root: Vector3 in flowers.azalea_positions:
		if p.distance_to(Vector2(root.x,root.z))<radius+1.0: return -1
	for prior: Dictionary in footprints:
		if p.distance_to(prior.p)<12.0: return -1
	for box: AABB in obstacles:
		if Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(roof_radius+.12).has_point(p): return -1
	for rock: Dictionary in park.get_node("MidoriIslandNature").mainland_cover:
		if p.distance_to(rock.p)<roof_radius+float(rock.radius)+.5: return -1
	var low := terrain.height_at(p) as float
	var high := low
	for side: int in range(8):
		var q := p+Vector2(radius,0).rotated(side*TAU/8)
		if terrain.water_at(q): return -1
		var height: float = terrain.height_at(q)
		low=minf(low,height)
		high=maxf(high,height)
	# Seat the thick stone base into gentle ground instead of leaving a downhill gap.
	# The measured base is about 23cm tall: at most 4.5cm of contour variation here.
	candidate_base_y=low-.008
	return high-low if high-low<=.045 else -1.0

func _index_obstacles() -> void:
	# Index real individual companion/bed meshes, not enormous batch bounds.
	for batch: MultiMeshInstance3D in park.find_children("*","MultiMeshInstance3D",true,false):
		var parent: Node = batch
		var relevant := false
		while parent!=null and parent!=park:
			if String(parent.name) in ["WoodlandCompanionPockets","WoodlandDiversity","MidoriPlantedBeds","FullerWalkShoulders"]: relevant=true;break
			parent=parent.get_parent()
		if not relevant or batch.multimesh==null: continue
		var mm := batch.multimesh
		if mm.mesh==null: continue
		for index: int in range(mm.instance_count):
			var box: AABB = (batch.global_transform*mm.get_instance_transform(index))*mm.mesh.get_aabb()
			var envelope := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(20.0)
			for spec: Dictionary in ANCHORS:
				# Cover the complete 8m search plus a 7m sightline and mesh extents.
				if envelope.has_point(spec.target):
					obstacles.append(box)
					break

func _view_clear(p: Vector2,path: Vector2) -> bool:
	var chamber_y: float = terrain.height_at(p)+float(data.fire_origin[1])
	for trunk: Vector2 in park.occupied_tree_positions:
		var world: Vector2 = trunk*park.LAYOUT_SCALE
		if world.distance_to(Geometry2D.get_closest_point_to_segment(world,p,path))<.45: return false
	for footprint: Dictionary in gardens.footprints:
		if footprint.stone and footprint.p.distance_to(Geometry2D.get_closest_point_to_segment(footprint.p,p,path))<float(footprint.radius)+.1: return false
	for box: AABB in obstacles:
		if box.end.y<chamber_y-.08: continue
		var rect := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(.08)
		if rect.has_point(p) or rect.has_point(path): return false
		var corners := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
		for side: int in range(4):
			if Geometry2D.segment_intersects_segment(p,path,corners[side],corners[(side+1)%4])!=null: return false
	for rock: Dictionary in park.get_node("MidoriIslandNature").mainland_cover:
		if rock.p.distance_to(Geometry2D.get_closest_point_to_segment(rock.p,p,path))<float(rock.radius)+.2: return false
	return true

func _trim_base_grass() -> void:
	# Remove individual grass tufts only where the actual base touches ground.
	for batch: MultiMeshInstance3D in park.find_children("*","MultiMeshInstance3D",true,false):
		var label := String(batch.name)
		if not (label.begins_with("JapaneseForestGrass") or label.begins_with("ForestGrassLOD") or label.begins_with("WoodlandFillLOD") or label.contains("UprightGrass")): continue
		var mm := batch.multimesh
		if mm==null or mm.mesh==null: continue
		var bounds := mm.mesh.get_aabb()
		var anchor := Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
		var kept: Array[int] = []
		for index: int in range(mm.instance_count):
			var world := batch.global_transform*mm.get_instance_transform(index)*anchor
			var p := Vector2(world.x,world.z)
			var remove := false
			for footprint: Dictionary in footprints:
				if p.distance_to(footprint.p)<float(footprint.radius)+.10: remove=true;break
			if remove: removed_grass+=1
			else: kept.append(index)
		if kept.size()==mm.instance_count: continue
		var trimmed := MultiMesh.new()
		trimmed.transform_format=mm.transform_format
		trimmed.use_colors=mm.use_colors
		trimmed.use_custom_data=mm.use_custom_data
		trimmed.mesh=mm.mesh
		trimmed.instance_count=kept.size()
		for index: int in range(kept.size()):
			trimmed.set_instance_transform(index,mm.get_instance_transform(kept[index]))
			if mm.use_colors: trimmed.set_instance_color(index,mm.get_instance_color(kept[index]))
			if mm.use_custom_data: trimmed.set_instance_custom_data(index,mm.get_instance_custom_data(kept[index]))
		batch.multimesh=trimmed
