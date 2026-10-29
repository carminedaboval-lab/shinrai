extends RefCounted
## Lazy, explicit catalog. SceneState reconstruction never instantiates scripts,
## AnimationPlayers, physics actors, cameras or gameplay controllers from assets.

var last_error := ""
var _entries: Array[Dictionary] = []
var _by_id: Dictionary = {}
var _coverage: Dictionary = {}
var _loaded := false

func build_catalog() -> Array[Dictionary]:
	_load_metadata()
	return _entries.duplicate(true)

func get_entry(asset_id: String) -> Dictionary:
	_load_metadata()
	return (_by_id.get(asset_id, {}) as Dictionary).duplicate(true)

func get_coverage() -> Dictionary:
	_load_metadata()
	return _coverage.duplicate(true)

func get_factory_for_source(path: String) -> String:
	_load_metadata()
	for record: Dictionary in _entries:
		if record.source_path == path and record.placeable:
			return record.id
	return ""

func get_last_error() -> String:
	return last_error

func _load_metadata() -> void:
	if _loaded:
		return
	_loaded = true
	var path: String = get_script().resource_path.get_base_dir().path_join("creator_asset_catalog.json")
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		last_error = "The creator asset list could not be read."
		return
	var data: Dictionary = parser.data
	var available := 0
	for value: Variant in data.get("records", []):
		if not value is Dictionary:
			continue
		var record: Dictionary = value
		if _by_id.has(record.get("id", "")) or str(record.get("id", "")).is_empty():
			last_error = "Duplicate or missing creator asset identity."
			continue
		_entries.append(record)
		_by_id[record.id] = record
		if record.placeable:
			available += 1
	_coverage = {"records": _entries.size(), "placeable": available,
		"unavailable": _entries.size() - available, "source_files": data.get("source_files", 0),
		"model_scene_files": data.get("model_scene_files", 0), "scope": data.get("scope", ""),
		"limitations": data.get("limitations", []), "eager_resource_loads": 0}

func instantiate_asset(asset_id: String) -> Node3D:
	last_error = ""
	var entry := get_entry(asset_id)
	if entry.is_empty() or not bool(entry.get("placeable", false)):
		last_error = str(entry.get("reason", "Unknown creator object."))
		return null
	var root := Node3D.new()
	root.name = "CreatorObject"
	root.set_meta("creator_asset_id", asset_id)
	root.set_meta("creator_display_name", str(entry.name))
	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	if str(entry.factory) == "recipe":
		_build_recipe(visual, str(entry.recipe))
	else:
		var resource: Resource = ResourceLoader.load(str(entry.source_path))
		if resource == null:
			return _fail(root, "This object could not be loaded.")
		if str(entry.factory) == "bundle":
			var scenes: Dictionary = resource.get_meta("full_scenes", {})
			resource = scenes.get(str(entry.bundle_key)) as Resource
		if resource is PackedScene:
			var imported: Node3D = _scene_root(resource as PackedScene)
			visual.add_child(imported)
			_append_scene(imported, resource as PackedScene)
			if entry.has("source_scale"):
				var source_scale: Array = entry.source_scale
				imported.scale = Vector3(float(source_scale[0]), float(source_scale[1]), float(source_scale[2]))
			if entry.has("rotate_x_degrees"):
				imported.rotation_degrees = Vector3(float(entry.rotate_x_degrees), 0, 0)
		elif resource is Mesh:
			var mesh := MeshInstance3D.new()
			mesh.name = "Mesh"
			mesh.mesh = resource as Mesh
			visual.add_child(mesh)
		else:
			return _fail(root, "This resource has no supported static object geometry.")
		if entry.has("source_node"):
			var selected := _find_named(visual, str(entry.source_node))
			if selected == null:
				return _fail(root, "The named object is missing from its source collection.")
			var retained := selected.transform
			var ancestor := selected.get_parent() as Node3D
			while ancestor != visual and ancestor != null:
				retained = ancestor.transform * retained
				ancestor = ancestor.get_parent() as Node3D
			selected.get_parent().remove_child(selected)
			for child: Node in visual.get_children():
				child.free()
			selected.transform = retained
			visual.add_child(selected)
	visual.scale = Vector3.ONE * float(entry.get("scale", 1.0))
	var bounds_data := _bounds(root)
	if not bool(bounds_data.valid):
		return _fail(root, "This object contains no supported visible mesh.")
	var bounds: AABB = bounds_data.bounds
	if entry.has("height"):
		if bounds.size.y < 0.0001:
			return _fail(root, "This object has no usable height.")
		visual.scale *= float(entry.height) / bounds.size.y
		bounds = _bounds(root).bounds
	# Every creator object has a floor-centred pivot in metres, independent of
	# the park generator's doubled X/Z coordinates and original file pivots.
	visual.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	bounds = _bounds(root).bounds
	if bounds.size.length() > 1000.0 or bounds.size.length() < 0.00001:
		return _fail(root, "This object's dimensions need a placement adapter.")
	_add_collision(root, visual, str(entry.get("collision", "mesh")), bounds)
	if entry.has("light"):
		_add_light(root, entry.light, bounds)
	root.set_meta("creator_local_bounds", bounds)
	root.set_meta("creator_source_path", str(entry.source_path))
	return root

func _fail(root: Node3D, message: String) -> Node3D:
	last_error = message
	root.free()
	return null

func _append_scene(destination: Node3D, scene: PackedScene, depth: int = 0) -> void:
	if depth > 24:
		return
	var state := scene.get_state()
	var nodes: Dictionary = {".": destination}
	for index: int in range(state.get_node_count()):
		var path := str(state.get_node_path(index))
		var current: Node3D
		if index == 0:
			current = destination
		else:
			var parent_path := str(state.get_node_path(index, true))
			var parent: Node3D = nodes.get(parent_path, destination)
			var existing: Node = parent.get_node_or_null(NodePath(str(state.get_node_name(index))))
			if existing is Node3D:
				current = existing as Node3D
			else:
				var nested_scene := state.get_node_instance(index)
				current = _scene_root(nested_scene) if nested_scene != null else (MeshInstance3D.new() if state.get_node_type(index) == &"MeshInstance3D" else Node3D.new())
				current.name = state.get_node_name(index)
				parent.add_child(current)
		nodes[path] = current
		var nested := state.get_node_instance(index)
		if nested != null:
			_append_scene(current, nested, depth + 1)
		for property_index: int in range(state.get_node_property_count(index)):
			var property := str(state.get_node_property_name(index, property_index))
			var value: Variant = state.get_node_property_value(index, property_index)
			if property in ["transform", "position", "rotation", "rotation_degrees", "scale", "visible"]:
				current.set(property, value)
			elif current is MeshInstance3D and (property in ["mesh", "material_override", "material_overlay", "cast_shadow"] or property.begins_with("surface_material_override/")):
				current.set(property, value)

func _scene_root(scene: PackedScene) -> Node3D:
	var state := scene.get_state()
	var node: Node3D = MeshInstance3D.new() if state.get_node_count() > 0 and state.get_node_type(0) == &"MeshInstance3D" else Node3D.new()
	node.name = str(state.get_node_name(0)) if state.get_node_count() > 0 else "Model"
	return node

func _normal_name(value: String) -> String:
	return value.to_lower().replace(" ", "").replace(".", "").replace("_", "").replace("-", "")

func _find_named(node: Node3D, label: String) -> Node3D:
	if _normal_name(str(node.name)) == _normal_name(label):
		return node
	for child: Node in node.get_children():
		if child is Node3D:
			var found := _find_named(child as Node3D, label)
			if found != null:
				return found
	return null

func _bounds(root: Node3D) -> Dictionary:
	var result := AABB()
	var valid := false
	for item: Dictionary in _meshes(root):
		var mesh: MeshInstance3D = item.node
		var box: AABB = (item.transform as Transform3D) * mesh.get_aabb()
		result = result.merge(box) if valid else box
		valid = true
	return {"valid": valid, "bounds": result}

func _meshes(root: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pending: Array[Dictionary] = [{"node": root, "transform": Transform3D.IDENTITY, "visible": true}]
	while not pending.is_empty():
		var item: Dictionary = pending.pop_back()
		var node: Node3D = item.node
		var shown: bool = bool(item.visible) and node.visible
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and shown:
			result.append({"node": node, "transform": item.transform})
		for child: Node in node.get_children():
			if child is Node3D:
				pending.append({"node": child, "transform": (item.transform as Transform3D) * (child as Node3D).transform, "visible": shown})
	return result

func _add_collision(root: Node3D, visual: Node3D, policy: String, bounds: AABB) -> void:
	if policy == "none":
		return
	var body := StaticBody3D.new()
	body.name = "CreatorCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	if policy == "trunk":
		var shape := CylinderShape3D.new()
		shape.height = minf(2.8, bounds.size.y)
		shape.radius = clampf(minf(bounds.size.x, bounds.size.z) * 0.05, 0.08, 0.55)
		_add_shape(body, shape, Transform3D(Basis.IDENTITY, Vector3(0, shape.height * 0.5, 0)))
	elif policy == "box":
		var shape := BoxShape3D.new()
		shape.size = bounds.size.max(Vector3.ONE * 0.01)
		_add_shape(body, shape, Transform3D(Basis.IDENTITY, bounds.get_center()))
	else:
		for item: Dictionary in _meshes(root):
			var node: MeshInstance3D = item.node
			var faces := node.mesh.get_faces()
			if not faces.is_empty():
				# Bake source transforms into collision vertices. Nonuniform path
				# scales must not survive as unsupported physics-body scaling.
				var shape := ConcavePolygonShape3D.new()
				shape.set_faces((item.transform as Transform3D) * faces)
				shape.backface_collision = true
				_add_shape(body, shape, Transform3D.IDENTITY)
	if body.get_child_count() == 0:
		body.free()

func _add_shape(body: StaticBody3D, shape: Shape3D, at: Transform3D) -> void:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = at
	body.add_child(collider)

func _add_light(root: Node3D, specification: Dictionary, bounds: AABB) -> void:
	var light := OmniLight3D.new()
	light.name = "CreatorLampLight"
	light.position.y = minf(float(specification.get("height", 1.0)), bounds.size.y)
	light.light_energy = float(specification.get("energy", 0.4))
	light.omni_range = float(specification.get("range", 4.0))
	var color: Array = specification.get("color", [1.0, 0.88, 0.67])
	light.light_color = Color(float(color[0]), float(color[1]), float(color[2]))
	light.shadow_enabled = false
	light.add_to_group("midori_night_effect")
	root.add_child(light)

func _box(parent: Node3D, label: String, position_value: Vector3, size: Vector3, color: Color) -> void:
	var model := MeshInstance3D.new()
	model.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material = material
	model.mesh = mesh
	model.position = position_value
	parent.add_child(model)

func _build_recipe(root: Node3D, recipe: String) -> void:
	var wood := Color(0.31, 0.19, 0.10)
	var steel := Color(0.12, 0.15, 0.16)
	if recipe == "changing_bench":
		for x: float in [-0.145, 0.0, 0.145]:
			_box(root, "SeatSlat", Vector3(x, 0.4275, 0), Vector3(0.135, 0.045, 2.1), wood)
		for x: float in [-0.18, 0.18]:
			for z: float in [-0.8, 0.8]:
				_box(root, "Leg", Vector3(x, 0.205, z), Vector3(0.032, 0.41, 0.032), steel)
	elif recipe == "fence_panel":
		for x: float in [-1.5, 1.5]:
			_box(root, "Post", Vector3(x, 1.5, 0), Vector3(0.065, 3.0, 0.065), steel)
		for y: float in [0.15, 1.5, 2.97]:
			_box(root, "Rail", Vector3(0, y, 0), Vector3(3.0, 0.045, 0.045), steel)
		for index: int in range(1, 20):
			_box(root, "Wire", Vector3(-1.5 + float(index) * 0.15, 1.5, 0), Vector3(0.008, 3.0, 0.008), steel)
		for index: int in range(1, 20):
			_box(root, "Wire", Vector3(0, float(index) * 0.15, 0), Vector3(3.0, 0.008, 0.008), steel)
	elif recipe == "lake_barrier":
		for x: float in [-0.725, 0.725]:
			_box(root, "Post", Vector3(x, 0.32, 0), Vector3(0.075, 0.64, 0.075), wood)
		for y: float in [0.25, 0.48]:
			_box(root, "Rope", Vector3(0, y, 0), Vector3(1.45, 0.018, 0.018), Color(0.105, 0.082, 0.055))
