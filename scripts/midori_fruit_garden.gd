extends RefCounted
## Managed Japanese fruit garden using complete licensed plant models.
## Install after street construction. Harvest mechanics owns fruit state.
const FRUIT_ASSETS := "res://assets/shinrai/plants/fruit_garden/"
const FRUIT_GROUP := "midori_harvestable_fruit"
const FRUIT_LAYER := 1 << 20
const SOIL_Y := -.015

static func plot_rolls(seed: int) -> Array[bool]:
	# Stable independent plot hashes: reproducible across runs and unrelated to
	# Godot's global RNG or the number of unrelated random calls during loading.
	var rolls: Array[bool] = [true]
	for plot: int in range(1,3):
		var digest: String = ("midori_fruit_residential_v1:%d:%d"%[seed,plot]).sha256_text()
		rolls.append(digest.substr(0,8).hex_to_int()%10000 < 6000)
	return rolls

static func _world_seed() -> Dictionary:
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--midori-fruit-seed="): continue
		var value: String = argument.trim_prefix("--midori-fruit-seed=")
		if value.is_valid_int(): return {"seed":value.to_int(),"source":"debug_cli"}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return {"seed":int(rng.randi()),"source":"randomized_once_at_world_garden_build"}

static func install(park: Node3D) -> Dictionary:
	var existing := park.get_node_or_null("ManagedFruitGarden") as Node3D
	if existing != null:
		var previous: Dictionary = existing.get_meta("fruit_garden_report",{})
		var prior_fruits: Array[Node3D] = []
		for fruit: Variant in previous.get("fruit_nodes",[]):
			if is_instance_valid(fruit): prior_fruits.append(fruit as Node3D)
		return {"root":existing,"fruits":prior_fruits,"report":previous,"already_installed":true}
	var street := park.get_node_or_null("MidoriSouthStreet") as Node3D
	if street == null or street.get("installed") != true:
		return {"root":null,"fruits":[],"report":{"error":"Install fruit garden after street.installed"}}
	var street_report: Dictionary = street.get("report")
	var context: Dictionary = street_report.get("connected_context",{})
	var report := build(street,context)
	var root: Node3D = report.get("root")
	var fruits: Array[Node3D] = []
	for fruit: Variant in report.get("fruit_nodes",[]):
		if is_instance_valid(fruit): fruits.append(fruit as Node3D)
	if root != null:
		# Street batching has already finished; moving the whole managed garden
		# to a direct park child keeps each harvest area independently removable.
		root.reparent(park,true)
	return {"root":root,"fruits":fruits,"report":report}

static func build(street: Node3D, context: Dictionary) -> Dictionary:
	var seed_info := _world_seed()
	var seed: int = seed_info.seed
	var spawn_rolls: Array[bool] = plot_rolls(seed)
	var report := {"species":["mikan","persimmon","mikan"],"seed":seed,"seed_source":seed_info.source,"spawn_rolls":spawn_rolls,"residential_spawn_chance":.60,"spawn_policy":"public mikan always present; residential persimmon/mikan independently rolled once per loaded world, never on pause or raid reset","trees":[],"fruit_nodes":[],"fruit_ids":[],"fruit_positions":[],"rejected":[],"unspawned":[],"fruit_count":0,"tree_count":0,"source":"complete licensed plant geometry plus individually harvestable scanned fruit at actual twig markers","acceptance":"native geometry/bounds, daytime/nighttime appearance and harvest interaction require root review"}
	var root := Node3D.new()
	root.name = "ManagedFruitGarden"
	root.set_meta("creator_protected",true)
	root.set_meta("creator_editable",false)
	root.set_meta("managed_fruit_garden",true)
	root.set_meta("exclude_static_fruit_cache",true)
	street.add_child(root)
	var stalk := StandardMaterial3D.new()
	stalk.albedo_color = Color("#56523b")
	stalk.roughness = .9
	for index: int in range(3):
		var persimmon := index == 1
		var species := "persimmon" if persimmon else "mikan"
		var item_id := "garden_persimmon" if persimmon else "garden_mikan"
		var desired_z := 207.5+float(index)*3.7
		if not spawn_rolls[index]:
			report.unspawned.append({"plot":index,"species":species,"desired_z":desired_z,"reason":"residential plot absent for this world seed; 60 percent spawn chance"})
			continue
		var plant_path := FRUIT_ASSETS+("persimmon_tree.glb" if persimmon else "citrus_tree.glb")
		var asset_path := FRUIT_ASSETS+("kaki.glb" if persimmon else "mikan.glb")
		var plant_scene := load(plant_path) as PackedScene
		var fruit_scene := load(asset_path) as PackedScene
		if plant_scene == null or fruit_scene == null:
			report.rejected.append({"plot":index,"species":species,"reason":"required whole species plant or scanned fruit missing","plant":plant_path,"fruit":asset_path})
			continue
		var tree := Node3D.new()
		tree.name = ("GardenPersimmon_" if persimmon else "GardenMikan_")+str(index)
		tree.set_meta("creator_protected",true)
		tree.set_meta("creator_editable",false)
		tree.set_meta("fruit_species",species)
		tree.set_meta("fruit_plot_kind","public_managed_garden" if index == 0 else "residential_garden")
		root.add_child(tree)
		var model := plant_scene.instantiate() as Node3D
		model.name = "WholePersimmonPlant" if persimmon else "WholeCitrusPlant"
		tree.add_child(model)
		# Preserve the complete plant's authored anatomy and size. Place the
		# measured crown beside the pedestrian approach, never compress its width.
		var source_bounds := _bounds(model)
		# Seat the citrus root flare in soil; the source's pointed outer roots
		# should not suspend the trunk above ground. Sockets follow the model.
		model.position.y = -source_bounds.position.y - (0.12 if not persimmon else 0.0)
		tree.position = Vector3(42.05-source_bounds.position.x,SOIL_Y,desired_z-source_bounds.get_center().z)
		var plant_bounds := _bounds(model)
		var footprint := Rect2(plant_bounds.position.x,plant_bounds.position.z,plant_bounds.size.x,plant_bounds.size.z)
		if not _site_clear(footprint,context):
			report.rejected.append({"plot":index,"species":species,"actual_bounds":plant_bounds,"reason":"whole plant crown does not fit actual soil and pedestrian approach"})
			root.remove_child(tree)
			tree.free()
			continue
		var sockets: Array[Node3D] = []
		for fruit_index: int in range(6):
			var socket := model.find_child("FruitSocket_%d"%fruit_index,true,false) as Node3D
			if socket != null: sockets.append(socket)
		if sockets.size() != 6:
			report.rejected.append({"plot":index,"species":species,"found_sockets":sockets.size(),"reason":"complete plant requires six actual twig sockets"})
			root.remove_child(tree)
			tree.free()
			continue
		for fruit_index: int in range(6):
			var branch_tip: Vector3 = tree.to_local(sockets[fruit_index].global_position)
			var position := branch_tip-Vector3(0,.085 if persimmon else .060,0)
			# Short calyx stalk only. No constructed arms relocate fruit away from
			# the original whole plant's branches or fill space between branches.
			_rod(tree,"ShortFruitPedicel",branch_tip,position+Vector3(0,.055 if persimmon else .028,0),.0019,.0015,stalk)
			var fruit := _fruit(tree,position,index,fruit_index,species,item_id,fruit_scene)
			report.fruit_nodes.append(fruit)
			report.fruit_ids.append(fruit.get_meta("fruit_id"))
			report.fruit_positions.append({"fruit_id":fruit.get_meta("fruit_id"),"item_id":item_id,"world_position":fruit.global_position,"branch_socket_world":sockets[fruit_index].global_position,"stalk_length_m":.030 if persimmon else .032})
		var body := StaticBody3D.new()
		body.name = "FruitTrunkCollision"
		body.collision_layer = 1
		body.collision_mask = 1
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = .14 if persimmon else .065
		cylinder.height = .95
		shape.shape = cylinder
		# Canonical export origin is the actual rooted trunk, not crown center.
		shape.position = model.position+Vector3(0,.45,0)
		body.add_child(shape)
		tree.add_child(body)
		# Only six local pedicels are combined. Whole plant meshes and individual
		# scanned fruit remain untouched and independently owned.
		street.call("_batch_direct_geometry",tree)
		var bounds := _bounds(tree)
		var actual_xz := Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z)
		if not _site_clear(actual_xz,context):
			for fruit: Variant in report.fruit_nodes.duplicate():
				if is_instance_valid(fruit) and tree.is_ancestor_of(fruit):
					report.fruit_nodes.erase(fruit)
					report.fruit_ids.erase(fruit.get_meta("fruit_id"))
			for row: Variant in report.fruit_positions.duplicate():
				if str(row.fruit_id).begins_with("east_fruit_plot_%d_"%index): report.fruit_positions.erase(row)
			report.rejected.append({"plot":index,"species":species,"actual_bounds":bounds,"reason":"complete fruit/plant geometry escapes actual soil or approach"})
			root.remove_child(tree)
			tree.free()
			continue
		tree.set_meta("fruit_garden_bounds",bounds)
		report.trees.append({"id":str(tree.name),"plot":index,"species":species,"item_id":item_id,"root":tree.global_position,"soil_world_y":SOIL_Y,"world_bounds":bounds,"fruit_count":6,"form":"complete licensed species plant with actual branch fruit sockets","trunk_collision_radius_m":.14 if persimmon else .065,"plant_asset":plant_path,"fruit_model":asset_path})
	report.tree_count = report.trees.size()
	report.fruit_count = report.fruit_nodes.size()
	report["root"] = root
	report["fruit_group"] = FRUIT_GROUP
	report["fruit_collision_layer"] = FRUIT_LAYER
	report["geometry"] = _geometry(root)
	root.set_meta("fruit_garden_report",report.duplicate())
	return report

static func _site_clear(bounds: Rect2, context: Dictionary) -> bool:
	var safe := false
	for soil: Rect2 in context.get("soil_rectangles",[]):
		if soil.encloses(bounds): safe = true
	for walk: Rect2 in context.get("paved_rectangles",[]):
		if walk.grow(1.5).intersects(bounds): safe = false
	for road: Rect2 in context.get("road_rectangles",[]):
		if road.grow(.75).intersects(bounds): safe = false
	for house: Rect2 in context.get("building_footprints",[]):
		if house.grow(.75).intersects(bounds): safe = false
	return safe

static func _fruit(tree: Node3D, position: Vector3, tree_index: int, fruit_index: int, species: String, item_id: String, scene: PackedScene) -> Area3D:
	var fruit := Area3D.new()
	var id := "east_fruit_plot_%d_%d"%[tree_index,fruit_index]
	fruit.name = ("Kaki_" if species == "persimmon" else "Mikan_")+id
	fruit.position = position
	fruit.collision_layer = FRUIT_LAYER
	fruit.collision_mask = 0
	fruit.monitoring = false
	fruit.monitorable = true
	fruit.set_meta("fruit_id",id)
	fruit.set_meta("item_id",item_id)
	fruit.set_meta("species",species)
	fruit.set_meta("harvested",false)
	fruit.set_meta("creator_protected",true)
	fruit.set_meta("creator_editable",false)
	fruit.add_to_group(FRUIT_GROUP)
	tree.add_child(fruit)
	var collider := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .085
	collider.shape = sphere
	fruit.add_child(collider)
	var model := scene.instantiate() as Node3D
	model.name = "ScannedKaki" if species == "persimmon" else "ScannedMikan"
	# Canonical export is centered, Y-up and already sized to .09/.075m.
	model.rotation.y = float(tree_index*7+fruit_index)*2.399
	fruit.add_child(model)
	return fruit

static func _rod(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, tip_radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = tip_radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 10
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	node.position = (a+b)*.5
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)

static func _bounds(root: Node3D) -> AABB:
	var pending: Array[Node] = [root]
	var bounds := AABB()
	var first := true
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if not node is MeshInstance3D: continue
		var visual := node as MeshInstance3D
		for surface: int in range(visual.mesh.get_surface_count()):
			var arrays: Array = visual.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			for i: int in range(count):
				var point: Vector3 = visual.global_transform*vertices[indices[i] if not indices.is_empty() else i]
				bounds = AABB(point,Vector3.ZERO) if first else bounds.expand(point)
				first = false
	return bounds

static func _geometry(root: Node3D) -> Dictionary:
	var result := {"mesh_instances":0,"triangles":0,"fruit_query_areas":0,"solid_trunk_bodies":0}
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if node is Area3D: result.fruit_query_areas += 1
		if node is StaticBody3D: result.solid_trunk_bodies += 1
		if not node is MeshInstance3D: continue
		var visual := node as MeshInstance3D
		result.mesh_instances += 1
		for surface: int in range(visual.mesh.get_surface_count()):
			# surface_get_arrays also works for primitive meshes such as CylinderMesh.
			var arrays: Array = visual.mesh.surface_get_arrays(surface)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			result.triangles += int((indices.size() if indices != null else arrays[Mesh.ARRAY_VERTEX].size())/3)
	return result
