extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")

# Existing CC0 Iris japonica scan; metre-scale stems and leaves, never primitive heads.
const MODEL_PATH := "res://assets/shinrai/parks/midori_park/models/plants/iris_japonica/iris_japonica_lod%d.glb"
const Woodland := preload("res://scripts/midori_woodland_layout.gd")
var installed := false
var colony_roots: Array[Vector3] = []
var colony_cells: Dictionary = {}
var flowering_shoots := 0
var west_carpet_roots: Array[Vector3] = []
var west_carpet_bounds := Rect2()
var removed_grass_instances := 0
var removed_companion_instances := 0
var hidden_overtopping_plants := 0
var plant_positions: Array[Vector3] = []
var patch_centres: Array[Vector3] = []
var azalea_positions: Array[Vector3] = []
var desire_paths: Node

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	call_deferred("install")

func install() -> void:
	var park := get_parent() as Node3D
	var terrain: Node = park.get_node("MidoriTerrain")
	while not terrain.installed: await get_tree().process_frame
	desire_paths = park.get_node_or_null("MidoriDesirePaths")
	if desire_paths != null:
		for frame in range(600):
			if desire_paths.get("installed") == true or desire_paths.get("finished") == true: break
			await get_tree().process_frame
	# Terrain has already draped the established vegetation. New roots use its height.
	set_as_top_level(true)
	global_transform = Transform3D.IDENTITY
	var detail: Node = get_tree().root.get_node("MidoriGrassDetail")
	var templates: Array[Dictionary] = []
	for lod in range(2):
		var model: Node = load(MODEL_PATH % lod).instantiate()
		var parts := {}
		for mesh_node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			parts[String(mesh_node.name)] = mesh_node.mesh
		assert(parts.has("FlowerStem") and parts.has("LeafFan"))
		templates.append(parts)
		model.free()
	var sockets: Array[Vector2] = []
	var planned := park.find_child("PlannedPropSockets", true, false)
	if planned:
		for marker: Node3D in planned.get_children(): sockets.append(Vector2(marker.global_position.x, marker.global_position.z))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2050100611
	# Creeping rhizomes produce connected colonies, with fewer flowering shoots
	# than leaf fans. Colony shoulders follow nearby trunks and irregular light gaps.
	for grove: Dictionary in Woodland.GROVES:
		var centres: Array[Vector2] = []
		for attempt in range(90):
			var angle := attempt * 2.399963
			var radius := sqrt(float(attempt) / 90.0) * 18.0
			var centre: Vector2 = grove.centre + Vector2(cos(angle), sin(angle)) * radius
			if not _clear(centre, park, terrain, detail, sockets): continue
			if _canopy_cover(centre, park, 1.8) == 0: continue
			var crowded := false
			for prior in centres:
				if centre.distance_to(prior) < 8.0: crowded = true
			if crowded: continue
			var stems: Array[Transform3D] = []
			var leaves: Array[Transform3D] = []
			var roots: Array[Vector3] = []
			var blooms: Array[Vector3] = []
			for z in range(-11, 12):
				for x in range(-14, 15):
					var offset := Vector2(x * .42 + rng.randf_range(-.10, .10), z * .42 + rng.randf_range(-.10, .10))
					var edge := pow(offset.x / 5.9, 2.0) + pow(offset.y / 4.4, 2.0)
					var scallop := .13 * sin(offset.x * .8 + angle) + .10 * cos(offset.y * 1.2)
					if edge > 1.0 + scallop: continue
					var p := centre + offset.rotated(angle)
					if not _clear(p, park, terrain, detail, sockets): continue
					var root := Vector3(p.x, terrain.height_at(p) - .008, p.y)
					var size := rng.randf_range(1.05, 1.30)
					var yaw := rng.randf_range(0.0, TAU)
					if rng.randf() < .58:
						# Several adjacent rhizome shoots bloom within a mature leaf clump.
						for shoot in range(2):
							var shoot_p := p + Vector2(.045, 0).rotated(yaw + shoot * PI)
							if not _clear(shoot_p, park, terrain, detail, sockets): continue
							var shoot_root := Vector3(shoot_p.x, terrain.height_at(shoot_p) - .008, shoot_p.y)
							var basis := Basis(Vector3.UP, yaw + shoot * 1.9).scaled(Vector3.ONE * size)
							stems.append(Transform3D(basis, shoot_root))
							blooms.append(shoot_root)
					for fan in range(6):
						var leaf_basis := Basis(Vector3.UP, yaw + fan * TAU / 6.0) * Basis(Vector3.BACK, rng.randf_range(.30, .50))
						leaf_basis = leaf_basis.scaled(Vector3(1.35, 1.18, 1.35) * size)
						leaves.append(Transform3D(leaf_basis, root))
					roots.append(root)
			if roots.size() < 65: continue
			# Consume the original west seed sequence so secondary colonies retain
			# their accepted placements; the west is replaced by one flowing carpet.
			if grove.name == "West iris woodland":
				centres.append(centre)
				if centres.size() >= 3: break
				continue
			var origin := Vector3(centre.x, terrain.height_at(centre), centre.y)
			for lod in range(2):
				_batch(templates[lod].FlowerStem, stems, origin, lod, "Stems")
				_batch(templates[lod].LeafFan, leaves, origin, lod, "Leaves")
			plant_positions.append_array(blooms)
			colony_roots.append_array(roots)
			patch_centres.append(origin)
			centres.append(centre)
			if centres.size() >= 3: break
	_install_west_carpet(park, terrain, detail, sockets, templates)
	flowering_shoots = plant_positions.size()
	# Spatially bounded replacement of tall grass keeps the iris fans readable.
	_install_azaleas(park, terrain, detail, sockets, rng)
	for root in colony_roots: _index_root(root, 0.0)
	for root in azalea_positions: _index_root(root, .45)
	_trim_colony_grass(park)
	_clear_overtopping_roots(park)
	installed = true
	print("JAPANESE_IRIS_READY ", JSON.stringify({"patches": patch_centres.size(), "west_carpet_clumps": west_carpet_roots.size(), "west_carpet_size_m": [west_carpet_bounds.size.x, west_carpet_bounds.size.y], "plants": plant_positions.size(), "leaf_clumps": colony_roots.size(), "removed_grass_lod_instances": removed_grass_instances, "removed_companion_mesh_instances": removed_companion_instances, "hidden_overtopping_plants": hidden_overtopping_plants, "height_m": [.46, .57], "azalea_shrubs": azalea_positions.size(), "new_collisions": 0}))

func _install_azaleas(park: Node3D, terrain: Node, detail: Node, sockets: Array[Vector2], rng: RandomNumberGenerator) -> void:
	var sprigs: Array[Mesh] = []
	for lod in range(2):
		var model: Node = load("res://assets/shinrai/parks/midori_park/models/plants/iris_japonica/red_azalea_lod%d.glb" % lod).instantiate()
		sprigs.append(model.find_child("AzaleaSprig", true, false).mesh)
		model.free()
	# Reuse the supplied shrub's woody/leafy structure under the scanned flowering tips.
	var prototype: Node3D = park.forest_floor_bush_prototypes[0]
	var parts: Array[Dictionary] = []
	var box := AABB()
	for part: MeshInstance3D in prototype.find_children("*", "MeshInstance3D", true, false):
		var relative: Transform3D = park._vegetation_relative_transform(part, prototype)
		var mesh := part.mesh.duplicate() as Mesh
		for surface in range(mesh.get_surface_count()): mesh.surface_set_material(surface, part.get_active_material(surface))
		var bounds: AABB = relative * mesh.get_aabb()
		box = bounds if parts.is_empty() else box.merge(bounds)
		parts.append({"mesh": mesh, "relative": relative})
	var scale_value := minf(.85 / box.size.y, 1.35 / maxf(box.size.x, box.size.z))
	var base_basis := Basis.IDENTITY.scaled(Vector3.ONE * scale_value)
	var base_box: AABB = Transform3D(base_basis, Vector3.ZERO) * box
	var base_anchor := Vector3(base_box.get_center().x, base_box.position.y, base_box.get_center().z)
	for grove: Dictionary in Woodland.GROVES:
		var centre := Vector2.ZERO
		var found := false
		for attempt in range(80):
			var angle := attempt * 2.399963
			var p: Vector2 = grove.centre + Vector2(cos(angle), sin(angle)) * rng.randf_range(12.0, 22.0)
			if not _clear(p, park, terrain, detail, sockets): continue
			if _canopy_cover(p, park, 0.0) > 1: continue
			if _west_footprint(p, 2.2): continue
			var close := false
			for patch in patch_centres:
				if p.distance_to(Vector2(patch.x, patch.z)) < 7.5: close = true
			if close: continue
			centre = p
			found = true
			break
		if not found: continue
		for shrub in range(5):
			var p := centre + Vector2(cos(shrub * 2.399963), sin(shrub * 2.399963)) * sqrt(float(shrub)) * .75
			var clear := _clear(p, park, terrain, detail, sockets)
			for side in range(12):
				var q := p + Vector2(.9, 0).rotated(side * TAU / 12.0)
				if not _clear(q, park, terrain, detail, sockets): clear = false
			if not clear: continue
			var root := Vector3(p.x, terrain.height_at(p) - .008, p.y)
			var shrub_size := rng.randf_range(.86, 1.16)
			var shrub_rotation := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
			var shrub_basis := shrub_rotation * base_basis.scaled(Vector3.ONE * shrub_size)
			for part in parts:
				var instance := MeshInstance3D.new()
				instance.mesh = part.mesh
				instance.transform = Transform3D(shrub_basis, root - shrub_rotation * base_anchor * shrub_size) * part.relative
				instance.visibility_range_end = 50.0
				instance.visibility_range_end_margin = 1.5
				instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				instance.name = "AzaleaShrubBase_%02d" % azalea_positions.size()
				add_child(instance)
			var transforms: Array[Transform3D] = []
			var height := base_box.size.y * shrub_size
			var radius := minf(base_box.size.x, base_box.size.z) * .29 * shrub_size
			for flower in range(15):
				var angle := flower * 2.399963
				var spread := sqrt(float(flower) / 15.0)
				var offset := Vector3(cos(angle) * radius * spread, height * (.90 - .06 * spread), sin(angle) * radius * spread)
				var size := rng.randf_range(.85, 1.1)
				var basis := Basis(Vector3.UP, angle).scaled(Vector3.ONE * size)
				transforms.append(Transform3D(basis, root + offset))
			for lod in range(2): _batch(sprigs[lod], transforms, root, lod, "Azalea_%02d" % azalea_positions.size())
			azalea_positions.append(root)

func _clear(p: Vector2, park: Node3D, terrain: Node, detail: Node, sockets: Array[Vector2]) -> bool:
	if terrain.water_at(p) or not detail._is_lawn_position(p.x, p.y): return false
	if desire_paths != null and desire_paths.get("installed") == true:
		if desire_paths.distance_to_path(p) < 2.0 or p.distance_to(Vector2(-20, 154)) < 3.4: return false
	if not park._is_vegetation_clear(Vector3(p.x / 2.0, 0, p.y / 2.0), .3): return false
	for marker in sockets:
		if p.distance_to(marker) < 11.0: return false
	for trunk: Vector2 in park.occupied_tree_positions:
		if p.distance_to(trunk * 2.0) < 1.1: return false
	for side in range(8):
		var q := p + Vector2(.45, 0).rotated(side * TAU / 8.0)
		if not detail._is_lawn_position(q.x, q.y): return false
	return true

func _batch(mesh: Mesh, transforms: Array[Transform3D], origin: Vector3, lod: int, label: String) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		var local := transforms[i]
		local.origin -= origin
		mm.set_instance_transform(i, local)
	var batch := MultiMeshInstance3D.new()
	batch.name = "JapaneseIris_%02d_%s_LOD%d" % [patch_centres.size(), label, lod]
	batch.multimesh = mm
	batch.position = origin
	var detail_distance := 7.0 if label.begins_with("Stems") else 14.0
	batch.visibility_range_begin = 0.0 if lod == 0 else detail_distance
	batch.visibility_range_end = detail_distance if lod == 0 else 50.0
	batch.visibility_range_begin_margin = 1.5
	batch.visibility_range_end_margin = 1.5
	batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(batch)

func _index_root(root: Vector3, extra_radius: float) -> void:
	var cell := Vector2i(floori(root.x), floori(root.z))
	for z in range(-3, 4):
		for x in range(-3, 4):
			var key := cell + Vector2i(x, z)
			if not colony_cells.has(key): colony_cells[key] = []
			colony_cells[key].append(Vector3(root.x, root.z, extra_radius))

func _inside_colony(p: Vector2, radius: float) -> bool:
	var cell := Vector2i(floori(p.x), floori(p.y))
	for root: Vector3 in colony_cells.get(cell, []):
		var distance := radius + root.z
		if p.distance_squared_to(Vector2(root.x, root.y)) < distance * distance: return true
	return false

func _trim_colony_grass(park: Node3D) -> void:
	var companion_frames := _companion_frames(park)
	for batch: MultiMeshInstance3D in park.find_children("*", "MultiMeshInstance3D", true, false):
		var label := String(batch.name)
		var grass := label.begins_with("JapaneseForestGrass") or label.begins_with("ForestGrassLOD") or label.begins_with("WoodlandFillLOD") or label.contains("UprightGrass")
		var companion := String(batch.get_parent().name) in ["WoodlandCompanionPockets", "WoodlandDiversity"] and not label.begins_with("fallen_wood")
		if not grass and not companion: continue
		var mm := batch.multimesh
		if mm == null: continue
		var kept: Array[int] = []
		var box := mm.mesh.get_aabb()
		var anchor := Vector3(box.get_center().x, box.position.y, box.get_center().z)
		var companion_frame := {}
		if companion:
			for frame: Dictionary in companion_frames:
				if box == frame.mesh_bounds and mm.mesh.get_surface_count() == frame.surfaces:
					companion_frame = frame
					break
			if companion_frame.is_empty():
				push_warning("FLOWER_BED: unmatched companion mesh kept: " + label)
				continue
		for i in range(mm.instance_count):
			var t := batch.global_transform * mm.get_instance_transform(i)
			var p3 := t * anchor
			var footprint := t.basis.x.abs() * box.size.x + t.basis.z.abs() * box.size.z
			var radius := .42 + minf(.65, maxf(footprint.x, footprint.z) * .5)
			if companion:
				# Recover the shared plant root from each mesh part. All parts then
				# use the same whole-plant footprint, avoiding floating leaf fragments.
				var root_transform: Transform3D = t * companion_frame.relative.affine_inverse()
				var plant_box: AABB = root_transform * companion_frame.plant_bounds
				p3 = plant_box.get_center()
				radius = minf(2.2, maxf(plant_box.size.x, plant_box.size.z) * .5) + .2
			if _inside_colony(Vector2(p3.x, p3.z), radius):
				if companion: removed_companion_instances += 1
				else: removed_grass_instances += 1
			else: kept.append(i)
		if kept.size() == mm.instance_count: continue
		var trimmed := MultiMesh.new()
		trimmed.transform_format = mm.transform_format
		trimmed.use_colors = mm.use_colors
		trimmed.use_custom_data = mm.use_custom_data
		trimmed.mesh = mm.mesh
		trimmed.instance_count = kept.size()
		for j in range(kept.size()):
			trimmed.set_instance_transform(j, mm.get_instance_transform(kept[j]))
			if mm.use_colors: trimmed.set_instance_color(j, mm.get_instance_color(kept[j]))
			if mm.use_custom_data: trimmed.set_instance_custom_data(j, mm.get_instance_custom_data(kept[j]))
		batch.multimesh = trimmed

func _canopy_cover(p: Vector2, park: Node3D, shoulder: float) -> int:
	var cover := 0
	for trunk: Vector2 in park._occupied_tree_crowns:
		if p.distance_to(trunk * park.LAYOUT_SCALE) < float(park._occupied_tree_crowns[trunk]) + shoulder: cover += 1
	return cover

func _companion_frames(park: Node3D) -> Array[Dictionary]:
	var evergreen: Node3D = load("res://assets/shinrai/parks/midori_park/models/vegetation/midori_evergreen_shrub_v1.glb").instantiate()
	var sources: Array[Node3D] = [park.midnight_fern_prototype, park.lilac_prototypes[0], park.lilac_prototypes[1], park.forest_floor_bush_prototypes[0], park.emerald_fountain_grass_prototype, evergreen]
	var frames: Array[Dictionary] = []
	for source in sources:
		var bounds: AABB = park._vegetation_visual_bounds(source).bounds
		for part: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
			if part.mesh == null: continue
			frames.append({"mesh_bounds": part.mesh.get_aabb(), "surfaces": part.mesh.get_surface_count(), "relative": park._vegetation_relative_transform(part, source), "plant_bounds": bounds})
	evergreen.free()
	return frames

func _clear_overtopping_roots(park: Node3D) -> void:
	# Taller plants remain around the colony shoulders, not over the flower faces.
	for plant: Node3D in park.find_children("*", "Node3D", true, false):
		var label := String(plant.name)
		if not (label.begins_with("ForestFloorBush_") or label.begins_with("ReferenceLilacMass_") or label.begins_with("MixedTreeGapBush_") or label.begins_with("MidnightFern_") or label.begins_with("EmeraldFountainGrass_")): continue
		var visual: Dictionary = park._vegetation_visual_bounds(plant)
		if not visual.valid: continue
		var box: AABB = plant.global_transform * visual.bounds
		var p := Vector2(box.get_center().x, box.get_center().z)
		var radius := minf(2.2, maxf(box.size.x, box.size.z) * .5) + .2
		if _inside_colony(p, radius):
			plant.hide()
			hidden_overtopping_plants += 1

func _west_footprint(p: Vector2, margin: float = 0.0) -> bool:
	var c: Vector2 = Woodland.GROVES[0].centre
	var d := p - c
	var edge := pow(d.x / (14.0 + margin), 2.0) + pow(d.y / (10.5 + margin), 2.0)
	var shoulder := .09 * sin(d.x * .45) + .06 * cos(d.y * .55 + 1.2)
	return edge <= 1.0 + shoulder

func _install_west_carpet(park: Node3D, terrain: Node, detail: Node, sockets: Array[Vector2], templates: Array[Dictionary]) -> void:
	var centre: Vector2 = Woodland.GROVES[0].centre
	var rng := RandomNumberGenerator.new()
	rng.seed = 2050100621
	var correction_rng := RandomNumberGenerator.new()
	correction_rng.seed=2050102604
	var buckets := {}
	var first := true
	var changed := 0
	var removed := 0
	var pivot := Vector2(-164,-40)
	for z in range(-25, 26):
		for x in range(-33, 34):
			var offset := Vector2(x * .46 + rng.randf_range(-.10, .10), z * .46 + rng.randf_range(-.10, .10))
			var p := centre + offset
			if not _west_footprint(p) or not _clear(p, park, terrain, detail, sockets): continue
			var root := Vector3(p.x, terrain.height_at(p) - .008, p.y)
			var size := rng.randf_range(1.05, 1.30)
			var yaw := rng.randf_range(0.0, TAU)
			# Consume exactly the original source RNG before any bounded correction.
			# Outside the 24m review circle, original roots and transforms remain exact.
			var stems: Array[Transform3D] = []
			var leaves: Array[Transform3D] = []
			if rng.randf() < .58:
				for shoot in range(2):
					var shoot_p := p + Vector2(.045, 0).rotated(yaw + shoot * PI)
					if not _clear(shoot_p, park, terrain, detail, sockets): continue
					var shoot_root := Vector3(shoot_p.x, terrain.height_at(shoot_p) - .008, shoot_p.y)
					var basis := Basis(Vector3.UP, yaw + shoot * 1.9).scaled(Vector3.ONE * size)
					stems.append(Transform3D(basis, shoot_root))
			for fan in range(6):
				var basis := Basis(Vector3.UP, yaw + fan * TAU / 6.0) * Basis(Vector3.BACK, rng.randf_range(.30, .50))
				basis = basis.scaled(Vector3(1.35, 1.18, 1.35) * size)
				leaves.append(Transform3D(basis, root))
			var rotation := Basis.IDENTITY
			var factor := 1.0
			var fan_count := 6
			if p.distance_to(pivot)<=24.0:
				var density := clampf(.59+.19*sin(p.x*.34+p.y*.15)+.14*cos(p.y*.43-p.x*.11),.25,.90)
				if correction_rng.randf()>density:
					removed+=1
					continue
				var candidate := p+Vector2(correction_rng.randf_range(-.28,.28),correction_rng.randf_range(-.28,.28))
				if candidate.distance_to(pivot)<=24.0 and _west_footprint(candidate) and _clear(candidate,park,terrain,detail,sockets):
					p=candidate
				rotation=Basis(Vector3.UP,correction_rng.randf_range(-PI,PI))
				factor=correction_rng.randf_range(.67,1.0)
				fan_count=correction_rng.randi_range(3,6)
				changed+=1
			var revised_root := Vector3(p.x,terrain.height_at(p)-.008,p.y)
			var key := Vector2i(floori((p.x-centre.x)/7.0),floori((p.y-centre.y)/7.0))
			if not buckets.has(key): buckets[key]={"stems":[],"leaves":[],"far_leaves":[]}
			var bucket: Dictionary = buckets[key]
			for original: Transform3D in stems:
				var local_offset := rotation*(original.origin-root)*factor
				var at := revised_root+local_offset
				at.y=terrain.height_at(Vector2(at.x,at.z))-.008
				var updated := Transform3D(rotation*original.basis.scaled(Vector3.ONE*factor),at)
				bucket.stems.append(updated)
				plant_positions.append(at)
			for fan in range(fan_count):
				var original: Transform3D = leaves[fan]
				var updated := Transform3D(rotation*original.basis.scaled(Vector3.ONE*factor),revised_root)
				bucket.leaves.append(updated)
				if fan%2==0: bucket.far_leaves.append(updated)
			west_carpet_roots.append(revised_root)
			colony_roots.append(revised_root)
			west_carpet_bounds=Rect2(p,Vector2.ZERO) if first else west_carpet_bounds.expand(p)
			first=false
	var serial := 0
	for key: Vector2i in buckets:
		var p := centre + Vector2(key)*7.0 + Vector2(3.5,3.5)
		var origin := Vector3(p.x,terrain.height_at(p),p.y)
		var bucket: Dictionary = buckets[key]
		var stems: Array[Transform3D] = []; stems.assign(bucket.stems)
		var leaves: Array[Transform3D] = []; leaves.assign(bucket.leaves)
		var far_leaves: Array[Transform3D] = []; far_leaves.assign(bucket.far_leaves)
		for lod in range(2):
			_batch(templates[lod].FlowerStem,stems,origin,lod,"Stems_West_%02d"%serial)
			_batch(templates[lod].LeafFan,leaves if lod==0 else far_leaves,origin,lod,"Leaves_West_%02d"%serial)
		serial+=1
	patch_centres.append(Vector3(centre.x,terrain.height_at(centre),centre.y))
	park.set_meta("natural_vform_review",{"source":"Iris_japonica_LeafFan","producer":"midori_japanese_flowers._install_west_carpet","changed":changed,"removed":removed,"added":0,"pivot":pivot,"radius":24.0,"source_mesh_material_unchanged":true,"lods":2})
	print("NATURAL_VFORM_REVIEW changed=",changed," removed=",removed," added=0 source=Iris_japonica_LeafFan")
