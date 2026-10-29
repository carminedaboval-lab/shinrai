extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")

# Small authored compositions in world metres, using the supplied park models.
# Keep the open side facing the walking line and the planting behind the stones.
const GARDENS := [
	{"name":"LakesideStoneBend", "centre":Vector2(9,6), "yaw":-.25, "plants":32},
	{"name":"WoodedRiseGarden", "centre":Vector2(3,28), "yaw":.5, "plants":38},
	{"name":"NorthernIrisPocket", "centre":Vector2(30,-104), "yaw":2.9, "plants":28},
	{"name":"PlazaEastGarden", "centre":Vector2(199,137), "yaw":-1.55, "plants":44},
	{"name":"PlazaNorthGarden", "centre":Vector2(166,99), "yaw":3.1, "plants":44},
]
const ROCKS := "res://assets/shinrai/parks/midori_park/models/island_nature/rock_%02d.glb"
const MOSSY := preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_mossy_boulder_cluster_v1.glb")
const IRIS := preload("res://assets/shinrai/parks/midori_park/models/plants/iris_japonica/iris_japonica_lod0.glb")
var installed := false
var footprints: Array[Dictionary] = []
var report: Array[Dictionary] = []
var removed_grass := 0
var plaza_canopy_report: Array[Dictionary] = []
var park: Node3D
var terrain: Node
var desire_paths: Node

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	call_deferred("install")

func install() -> void:
	if installed: return
	park = get_parent()
	terrain = park.get_node("MidoriTerrain")
	while not terrain.installed: await get_tree().process_frame
	var nature := park.get_node("MidoriIslandNature")
	while not nature.installed: await get_tree().process_frame
	desire_paths = park.get_node_or_null("MidoriDesirePaths")
	set_as_top_level(true)
	global_transform = Transform3D.IDENTITY
	var sources: Array[Node3D] = []
	for index in range(6): sources.append(load(ROCKS % index).instantiate())
	sources.append(MOSSY.instantiate())
	var iris := IRIS.instantiate() as Node3D
	var plaza_shrub := _plaza_shrub(park.forest_floor_bush_prototypes[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 2050100674
	for garden_index in range(GARDENS.size()):
		var spec: Dictionary = GARDENS[garden_index]
		var plaza := garden_index >= 3
		var group := Node3D.new()
		group.name = spec.name
		add_child(group)
		var stone_count := 0
		var plant_count := 0
		var stone_offsets := [Vector2(0,0),Vector2(-1.7,1.15),Vector2(1.6,.65),Vector2(-2.5,2.5),Vector2(2.6,2.15)]
		var widths := [3.2 if garden_index==1 else 2.8,1.25,.95,.65,.50]
		if plaza: widths = [3.2,1.7,1.25,.85,.65]
		for index in range(stone_offsets.size()):
			var source: Node3D = sources[6] if index==0 else sources[(garden_index*2+index)%6]
			var box: AABB = park._vegetation_visual_bounds(source).bounds
			var scale_value: float = widths[index]/maxf(box.size.x,box.size.z)
			var radius := Vector2(box.size.x,box.size.z).length()*.5*scale_value
			var target: Vector2 = spec.centre + stone_offsets[index].rotated(spec.yaw)
			var placement := _find_position(target,radius,3.0,true)
			if placement.is_empty(): continue
			var p: Vector2 = placement.p
			var root := _place(group,source,p,scale_value,rng.randf_range(0,TAU),"GardenStone_%d" % index,true)
			footprints.append({"p":p,"radius":radius,"stone":true,"node":root.get_path()})
			stone_count += 1
		# An uneven crescent of low foliage rather than a complete decorative ring.
		var attempts := 420 if plaza else 240
		for attempt in range(attempts):
			if plant_count >= int(spec.plants): break
			var angle := attempt*2.399963+garden_index
			var spread := sqrt(float(attempt)/float(attempts))
			var offset := Vector2(cos(angle)*6.5*spread-2.0,sin(angle)*4.6*spread+3.0).rotated(spec.yaw)
			if plaza: offset = Vector2(cos(angle)*8.0*spread-1.0,sin(angle)*4.8*spread+3.5).rotated(spec.yaw)
			var p: Vector2 = spec.centre + offset
			var flowering: bool = garden_index>=2 and plant_count%4==0
			if plaza: flowering = plant_count%5==0
			var shrub: bool = plant_count%5==0 and not flowering
			if plaza: shrub = plant_count%5 in [1,2,3]
			var source: Node3D = iris if flowering else (park.forest_floor_bush_prototypes[garden_index%park.forest_floor_bush_prototypes.size()] if shrub else park.midnight_fern_prototype)
			if plaza and shrub: source = plaza_shrub
			var box: AABB = park._vegetation_visual_bounds(source).bounds
			var height := rng.randf_range(.60,.82) if shrub else rng.randf_range(.36,.58)
			if flowering: height=.64
			if plaza: height = rng.randf_range(.85,1.15) if shrub else (.78 if flowering else rng.randf_range(.45,.62))
			var scale_value := height/maxf(.001,box.size.y)
			var radius := Vector2(box.size.x,box.size.z).length()*.5*scale_value
			if not _clear(p,radius,false): continue
			var root := _place(group,source,p,scale_value,rng.randf_range(0,TAU),"GardenFloor_%02d" % plant_count,false)
			footprints.append({"p":p,"radius":radius,"stone":false,"node":root.get_path()})
			plant_count += 1
		report.append({"name":spec.name,"centre":spec.centre,"stones":stone_count,"plants":plant_count})
	await _install_plaza_canopy(plaza_shrub,iris)
	for source in sources: source.free()
	iris.free()
	plaza_shrub.free()
	await _trim_stone_grass()
	installed = true
	print("GARDEN_SPOTS_READY ",JSON.stringify({"gardens":report,"removed_grass":removed_grass}))


func _plaza_shrub(prototype: Node3D) -> Node3D:
	# Flowering tips from the same supplied azalea scan used by the woodland.
	var shrub := Node3D.new()
	var leaves := prototype.duplicate() as Node3D
	shrub.add_child(leaves)
	var box: AABB = park._vegetation_visual_bounds(leaves).bounds
	var size := minf(1.0/box.size.y,1.65/maxf(box.size.x,box.size.z))
	leaves.scale *= size
	leaves.position -= Vector3(box.get_center().x,box.position.y,box.get_center().z)*size
	var scan := load("res://assets/shinrai/parks/midori_park/models/plants/iris_japonica/red_azalea_lod1.glb").instantiate() as Node3D
	var flowers := MultiMeshInstance3D.new()
	flowers.name = "AzaleaTips"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = scan.find_child("AzaleaSprig",true,false).mesh
	mm.instance_count = 15
	var height := box.size.y*size
	var radius := minf(box.size.x,box.size.z)*size*.29
	for index in range(15):
		var angle := index*2.399963
		var spread := sqrt(float(index)/15.0)
		var p := Vector3(cos(angle)*radius*spread,height*(.90-.06*spread),sin(angle)*radius*spread)
		mm.set_instance_transform(index,Transform3D(Basis(Vector3.UP,angle),p))
	flowers.multimesh = mm
	flowers.visibility_range_end = 45
	flowers.visibility_range_end_margin = 5
	flowers.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	shrub.add_child(flowers)
	scan.free()
	return shrub

func _install_plaza_canopy(shrub_source: Node3D, iris: Node3D) -> void:
	# Finish after the existing sparse-vegetation pass so its tree choices and
	# selective height changes stay deterministic. All coordinates are metres.
	var sparse := park.get_node_or_null("MidoriSparseVegetation")
	while sparse != null and not sparse.installed: await get_tree().process_frame
	var group := Node3D.new()
	group.name = "PlazaCanopy"
	add_child(group)
	var rng := RandomNumberGenerator.new()
	rng.seed = 205010162
	var sites := [Vector2(203,119),Vector2(204,144),Vector2(192,159)]
	for index in range(sites.size()):
		var source: Node3D = park.broadleaf_prototypes[[1,4,2][index]]
		var box: AABB = park._vegetation_visual_bounds(source).bounds
		var scale_value: float = [7.2,7.6,6.9][index]/box.size.y
		var crown_radius: float = park._tree_crown_radius(source,scale_value)
		var p := Vector2.ZERO
		var accepted := false
		for attempt in range(100):
			var q: Vector2 = sites[index]+Vector2(1,0).rotated(attempt*2.399963)*sqrt(float(attempt)/100.0)*4.0
			if not _clear(q,.65,false): continue
			if absf(q.x)+crown_radius>219 or absf(q.y)+crown_radius>179: continue
			if not park._is_tree_canopy_spaced(Vector3(q.x/2.0,0,q.y/2.0),crown_radius): continue
			p=q;accepted=true;break
		if not accepted: continue
		var root := _place(group,source,p,scale_value,rng.randf_range(0,TAU),"PlazaShadeTree_%02d"%index,false)
		for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
			mesh.visibility_range_end=180
			mesh.visibility_range_end_margin=20
		var body := StaticBody3D.new()
		body.name="TrunkCollision"
		body.collision_layer=1;body.collision_mask=1
		root.add_child(body)
		var shape := CollisionShape3D.new()
		shape.name="TrunkShape"
		var cylinder := CylinderShape3D.new()
		cylinder.radius=.24;cylinder.height=2.5
		shape.shape=cylinder;shape.position.y=1.25
		body.add_child(shape)
		footprints.append({"p":p,"radius":.65,"stone":false,"tree":true,"node":root.get_path()})
		var layout: Vector2 = p/park.LAYOUT_SCALE
		park.occupied_tree_positions.append(layout)
		park.occupied_tree_is_skinny.append(false)
		park._occupied_tree_crowns[layout]=crown_radius
		var plants := 0
		for attempt in range(140):
			if plants>=18: break
			var angle := attempt*2.399963
			var spread := sqrt(float(attempt)/140.0)
			var q := p+Vector2(cos(angle)*4.2,sin(angle)*3.6)*spread
			var kind := plants%4
			var plant: Node3D = shrub_source if kind in [0,1] else (iris if kind==2 else park.midnight_fern_prototype)
			var plant_box: AABB = park._vegetation_visual_bounds(plant).bounds
			var height := rng.randf_range(.68,.90) if kind in [0,1] else (.68 if kind==2 else .48)
			var size := height/plant_box.size.y
			var radius := Vector2(plant_box.size.x,plant_box.size.z).length()*.5*size
			if not _clear(q,radius,false): continue
			var plant_root := _place(group,plant,q,size,rng.randf_range(0,TAU),"ShadePlant_%02d_%02d"%[index,plants],false)
			footprints.append({"p":q,"radius":radius,"stone":false,"node":plant_root.get_path()})
			plants+=1
		plaza_canopy_report.append({"node":root.get_path(),"p":p,"height":box.size.y*scale_value,"crown_radius":crown_radius,"plants":plants})
		await LoadingBudget.checkpoint(park)


func _find_position(target: Vector2,radius: float,search_radius: float,stone: bool) -> Dictionary:
	for attempt in range(60):
		var p := target + Vector2(1,0).rotated(attempt*2.399963)*sqrt(float(attempt)/60.0)*search_radius
		if _clear(p,radius,stone): return {"p":p}
	return {}

func _clear(p: Vector2,radius: float,stone: bool) -> bool:
	# Protect the complete 31m-radius plaza apron and the park boundary.
	if p.distance_to(Vector2(164,136)) < 31.0+radius+.4: return false
	if absf(p.x)+radius > 219.0 or absf(p.y)+radius > 179.0: return false
	if terrain.water_at(p) or terrain.edge_distance(p,terrain.shoreline)<radius+1.0: return false
	# Signed distance from the actual rounded, variable-width paved edge.
	# This follows main-path widening and terminal tapers without fixed bands.
	if park.path_edge_distance_world(p)<radius+.20: return false
	if desire_paths != null and desire_paths.distance_to_path(p)<radius+1.2: return false
	if park.any_trunk_within(p,radius+(.75 if stone else .3)): return false
	for prior in footprints:
		if p.distance_to(prior.p)<radius+float(prior.radius)+.08: return false
	var flowers := park.get_node("MidoriJapaneseFlowers")
	if flowers._inside_colony(p,radius+.5): return false
	for root: Vector3 in flowers.azalea_positions:
		if p.distance_to(Vector2(root.x,root.z))<radius+1.0: return false
	for cover: Dictionary in park.get_node("MidoriIslandNature").mainland_cover:
		if p.distance_to(cover.p)<radius+float(cover.radius)+1.0: return false
	var old_cover := park.find_child("OpenLawnBoulderCover",true,false)
	if old_cover != null:
		for old: Node3D in old_cover.get_children():
			if String(old.name).begins_with("OpenBoulder_") and p.distance_to(Vector2(old.global_position.x,old.global_position.z))<radius+3.5: return false
	var low := INF
	var high := -INF
	for side in range(8):
		var q := p+Vector2(radius,0).rotated(side*TAU/8)
		if terrain.water_at(q): return false
		var h: float = terrain.height_at(q)
		low=minf(low,h)
		high=maxf(high,h)
	return high-low<(.35 if stone else .15)

func _place(group: Node3D,source: Node3D,p: Vector2,scale_value: float,yaw: float,label: String,stone: bool) -> Node3D:
	var root := Node3D.new()
	root.name = label
	group.add_child(root)
	var content := source.duplicate() as Node3D
	root.add_child(content)
	var box: AABB = park._vegetation_visual_bounds(content).bounds
	content.scale *= scale_value
	content.position -= Vector3(box.get_center().x,box.position.y,box.get_center().z)*scale_value
	root.rotation.y = yaw
	root.position = Vector3(p.x,terrain.height_at(p),p.y)
	if stone: root.position.y -= box.size.y*scale_value*.20
	else: root.position.y -= .015
	for mesh: MeshInstance3D in content.find_children("*","MeshInstance3D",true,false):
		mesh.visibility_range_end = 100 if stone else 55
		mesh.visibility_range_end_margin = 5
		mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if stone:
		var body := StaticBody3D.new()
		body.name = "GardenStoneCollision"
		body.collision_layer=1
		body.collision_mask=1
		root.add_child(body)
		for mesh: MeshInstance3D in content.find_children("*","MeshInstance3D",true,false):
			var shape := CollisionShape3D.new()
			shape.shape = mesh.mesh.create_convex_shape()
			body.add_child(shape)
			shape.transform = root.global_transform.affine_inverse()*mesh.global_transform
	return root

func _trim_stone_grass() -> void:
	# Remove grass beneath stone bases and new plaza plants. Keep established
	# flower colonies, tree roots and woodland companion meshes intact.
	var trim_regions: Array[Vector3] = []
	for footprint: Dictionary in footprints:
		if not footprint.stone and not str(footprint.node).contains("/Plaza"): continue
		var radius: float = float(footprint.radius)+.2 if footprint.stone else float(footprint.radius)*.72
		trim_regions.append(Vector3(footprint.p.x,footprint.p.y,radius))
	for batch: MultiMeshInstance3D in park.find_children("*","MultiMeshInstance3D",true,false):
		var label := String(batch.name)
		if not (label.begins_with("JapaneseForestGrass") or label.begins_with("ForestGrassLOD") or label.begins_with("WoodlandFillLOD") or label.contains("UprightGrass")): continue
		var mm := batch.multimesh
		if mm==null: continue
		var box := mm.mesh.get_aabb()
		var anchor := Vector3(box.get_center().x,box.position.y,box.get_center().z)
		var kept: Array[int] = []
		for index in range(mm.instance_count):
			var p3 := batch.global_transform*mm.get_instance_transform(index)*anchor
			var p := Vector2(p3.x,p3.z)
			var remove := false
			for region: Vector3 in trim_regions:
				if p.distance_to(Vector2(region.x,region.y))<region.z: remove=true;break
			if remove: removed_grass+=1
			else: kept.append(index)
		if kept.size()==mm.instance_count: continue
		var trimmed := MultiMesh.new()
		trimmed.transform_format=mm.transform_format
		trimmed.use_colors=mm.use_colors
		trimmed.use_custom_data=mm.use_custom_data
		trimmed.mesh=mm.mesh
		trimmed.custom_aabb=mm.custom_aabb
		trimmed.instance_count=kept.size()
		for index in range(kept.size()):
			trimmed.set_instance_transform(index,mm.get_instance_transform(kept[index]))
			if mm.use_colors: trimmed.set_instance_color(index,mm.get_instance_color(kept[index]))
			if mm.use_custom_data: trimmed.set_instance_custom_data(index,mm.get_instance_custom_data(kept[index]))
		batch.multimesh=trimmed
		await LoadingBudget.checkpoint(park)
