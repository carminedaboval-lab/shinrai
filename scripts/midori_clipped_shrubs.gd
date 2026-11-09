extends RefCounted
## Replaces the neighbourhood's low shrubs with clipped Japanese garden shrubs.
## The gardens round the south-street homes used the EZTree Bush006 conifer
## spray for every low shrub and hedge: about 2,400 spiky paper cards, around
## 7.5 million triangles. Each one is hidden and a clipped mound (刈り込み:
## satsuki azalea, boxwood, holly) of the same footprint stands in its place.
## Neighbouring shrubs share a species, as they would in a planted bed.
## Call once, after the gardens are built and before the street is batched.
## The park's distance-detail cells carry copies of a few park Bush006 plants
## too; there the copies render as flat brown discs, so the same swap runs on
## those cells once they are built.
const SHADER := preload("res://shaders/midori_clipped_shrub.gdshader")
const Budget := preload("res://scripts/shinrai_loading_budget.gd")
const LEAF_TEXTURE := "scene_9.png"
const CELL := 24.0
const SHELLS := [0.0, 0.035, 0.075]
## Shells drop out with distance: the leafy fringe first, the core last.
const RANGES := [160.0, 70.0, 40.0]
# Leaf colour (albedo) and how much autumn bronze, per species.
const SPECIES := [
	[Color(0.085, 0.15, 0.055), 0.16], # Satsuki azalea
	[Color(0.1, 0.14, 0.05), 0.22],   # Kurume azalea, turning
	[Color(0.14, 0.18, 0.06), 0.03],  # Boxwood
	[Color(0.06, 0.11, 0.045), 0.0],  # Japanese holly
]

## Last sweep once the raid has finished booting: some planting (the plaza
## azalea beds among it) is built after the earlier passes, so anything still
## showing Bush006 anywhere in the world is swapped then.
## With a raid, the world-complete step (scripts/shinrai_world_complete.gd)
## calls apply_after_boot_now() before HQ; this legacy entry only runs the sweep
## for a raid that left BOOT without that step, or with no raid at all.
static func apply_after_boot(park: Node3D) -> void:
	var raid := park.get_node_or_null("ExtractionRun")
	while is_instance_valid(raid) and raid.phase == raid.Phase.BOOT:
		if is_instance_valid(park) and park.get_meta(&"shinrai_world_complete_started", false): return
		await park.get_tree().process_frame
	if is_instance_valid(park): await apply_after_boot_now(park)

## The whole-world sweep, once per park, on the shared loading budget.
static func apply_after_boot_now(park: Node3D) -> Dictionary:
	if not is_instance_valid(park): return {}
	if park.has_meta("clipped_shrubs_after_boot"): return park.get_meta("clipped_shrubs_after_boot")
	if park.get_meta(&"clipped_shrubs_after_boot_running", false):
		while is_instance_valid(park) and not park.has_meta("clipped_shrubs_after_boot"): await park.get_tree().process_frame
		return park.get_meta("clipped_shrubs_after_boot", {}) if is_instance_valid(park) else {}
	park.set_meta(&"clipped_shrubs_after_boot_running", true)
	var result: Dictionary = await apply_budgeted(park, park)
	if is_instance_valid(park): park.set_meta("clipped_shrubs_after_boot", result)
	return result

static func apply(street: Node3D) -> Dictionary:
	var state := _collect_begin(street)
	for geometry: GeometryInstance3D in street.find_children("*", "GeometryInstance3D", true, false):
		_collect_one(geometry, state)
	return _place_and_build(street, state)

## apply(), split across frames on the shared loading budget: the same items in
## the same order through the same code, so the result is identical.
static func apply_budgeted(street: Node3D, park: Node) -> Dictionary:
	var state := _collect_begin(street)
	await Budget.checkpoint(park, true)
	var geometries := street.find_children("*", "GeometryInstance3D", true, false)
	await Budget.checkpoint(park, true)
	for index: int in range(geometries.size()):
		if index % 64 == 63: await Budget.checkpoint(park, true)
		if not is_instance_valid(street): return {}
		var geometry := geometries[index] as GeometryInstance3D
		if is_instance_valid(geometry): _collect_one(geometry, state)
	await Budget.checkpoint(park, true)
	if not is_instance_valid(street): return {}
	return _place_and_build(street, state)

static func _collect_begin(street: Node3D) -> Dictionary:
	var parts: Dictionary = {}
	var leaves: Dictionary = {}
	for visual: MeshInstance3D in street.find_children("*", "MeshInstance3D", true, false):
		if visual.mesh == null or not String(visual.name).contains("Bush006"): continue
		parts[visual.mesh] = true
		if String(visual.name).contains("leaves"): leaves[visual.mesh] = true
	var spots: Array[AABB] = []
	return {"parts": parts, "leaves": leaves, "bounds": {}, "spots": spots, "hidden": 0, "layers": 1}

static func _collect_one(geometry: GeometryInstance3D, state: Dictionary) -> void:
	# Already swapped (or a hidden source prototype): leave it alone.
	if not geometry.is_visible_in_tree(): return
	var mesh: Mesh = null
	if geometry is MeshInstance3D: mesh = geometry.mesh
	elif geometry is MultiMeshInstance3D and geometry.multimesh != null: mesh = geometry.multimesh.mesh
	if mesh == null: return
	var parts: Dictionary = state.parts
	var leaves: Dictionary = state.leaves
	var bounds: Dictionary = state.bounds
	var spots: Array[AABB] = state.spots
	# Copies keep the source mesh's name even where the node is renamed.
	var named := mesh.resource_name.contains("Bush006")
	var leafy := leaves.has(mesh) or _texture(geometry, mesh) == LEAF_TEXTURE or (named and mesh.resource_name.contains("leaves"))
	if not leafy and not parts.has(mesh) and not named: return
	if leafy:
		if not bounds.has(mesh): bounds[mesh] = _drawn_bounds(mesh)
		if geometry is MultiMeshInstance3D:
			var many: MultiMesh = geometry.multimesh
			for i: int in range(many.instance_count):
				spots.append(geometry.global_transform * many.get_instance_transform(i) * bounds[mesh])
		else:
			spots.append(geometry.global_transform * bounds[mesh])
	if geometry.visible and int(state.hidden) == 0: state.layers = geometry.layers
	geometry.visible = false
	state.hidden = int(state.hidden) + 1

static func _place_and_build(street: Node3D, state: Dictionary) -> Dictionary:
	var spots: Array[AABB] = state.spots
	var hidden: int = state.hidden
	var layers: int = state.layers
	var rng := RandomNumberGenerator.new()
	rng.seed = 7351
	var cells: Dictionary = {}
	var placed := 0
	# Some source beds were laid out as lattices. Mounds that would crowd a
	# lattice are thinned and nudged so a bed reads as planted by hand.
	var occupied: Dictionary = {}
	for box: AABB in spots:
		var width := maxf(box.size.x, box.size.z)
		var long_x := box.size.x >= box.size.z
		var count := clampi(ceili(width / 1.25), 1, 4)
		for k: int in range(count):
			var t := (float(k) + 0.5) / float(count) - 0.5
			var at := box.get_center() + (Vector3.RIGHT * box.size.x if long_x else Vector3.BACK * box.size.z) * t * (1.0 - 1.0 / float(count))
			at.y = box.position.y
			var w := clampf(width / float(count) * 0.85, 0.35, 1.4) * rng.randf_range(0.9, 1.1)
			var near := 0
			var touching := false
			var here := Vector2i(floori(at.x / 2.0), floori(at.z / 2.0))
			for dz: int in range(-1, 2):
				for dx: int in range(-1, 2):
					for other: Vector2 in occupied.get(here + Vector2i(dx, dz), []):
						var gap := other.distance_to(Vector2(at.x, at.z))
						if gap < 2.0: near += 1
						if gap < w * 0.55: touching = true
			# Never drop a mound (flower sprigs may sit on it); only loosen crowded
			# lattices with a small nudge and a size change.
			if near >= 2:
				at += Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2))
				w *= rng.randf_range(0.8, 1.05)
			if touching: w *= 0.85
			if not occupied.has(here): occupied[here] = []
			occupied[here].append(Vector2(at.x, at.z))
			var h := clampf(minf(box.size.y * 0.85, w * 0.85), 0.28, 1.0) * rng.randf_range(0.85, 1.05)
			var bed := Vector2i(floori(at.x / 3.0), floori(at.z / 3.0))
			var kind: Array = SPECIES[absi(hash(bed)) % SPECIES.size()]
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w, h, w * rng.randf_range(0.75, 1.0)))
			var key := Vector2i(floori(at.x / CELL), floori(at.z / CELL))
			if not cells.has(key): cells[key] = []
			var leaf: Color = kind[0]
			leaf = leaf * rng.randf_range(0.88, 1.12)
			leaf.a = kind[1]
			cells[key].append([Transform3D(basis, at + Vector3.DOWN * 0.04), leaf])
			placed += 1
	var root := Node3D.new()
	root.name = "ClippedShrubs"
	street.add_child(root)
	root.global_transform = Transform3D.IDENTITY
	var meshes: Array[ArrayMesh] = []
	var looks: Array[ShaderMaterial] = []
	for s: int in range(SHELLS.size()):
		meshes.append(_mound(SHELLS[s]))
		var look := ShaderMaterial.new()
		look.shader = SHADER
		look.set_shader_parameter("shell", float(s))
		looks.append(look)
	for key: Vector2i in cells:
		var rows: Array = cells[key]
		for s: int in range(SHELLS.size()):
			var many := MultiMesh.new()
			many.transform_format = MultiMesh.TRANSFORM_3D
			many.use_colors = true
			many.mesh = meshes[s]
			many.instance_count = rows.size()
			for i: int in range(rows.size()):
				many.set_instance_transform(i, rows[i][0])
				many.set_instance_color(i, rows[i][1])
			var node := MultiMeshInstance3D.new()
			node.name = "Shrubs_%d_%d_%d" % [key.x, key.y, s]
			node.multimesh = many
			node.material_override = looks[s]
			node.layers = layers
			node.visibility_range_end = RANGES[s]
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if s == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(node)
	return {"hidden_bush006_nodes":hidden, "source_bushes":spots.size(), "clipped_shrubs":placed, "cells":cells.size(), "triangles_per_shrub":meshes[0].get_faces().size() / 3 * SHELLS.size()}

## A clipped mound one metre across and one high, its base at the origin:
## lumpy like hand-clipped clouds, flat underneath. `grow` pushes it out
## along its normals for the leaf shells.
static func _mound(grow: float) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 1.6
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 20
	sphere.rings = 10
	var arrays := sphere.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i: int in range(points.size()):
		var p := points[i]
		var lump := 1.0 + noise.get_noise_3dv(p * 2.0) * 0.16 + noise.get_noise_3dv(p * 5.0) * 0.05
		p = p * lump
		# Flat underneath, full and rounded on top.
		p.y = ((p.y if p.y > 0.0 else p.y * 0.3) + 0.15) / 0.65
		points[i] = p
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var tool := SurfaceTool.new()
	tool.create_from(mesh, 0)
	tool.generate_normals()
	var smooth := tool.commit_to_arrays()
	if grow > 0.0:
		var verts: PackedVector3Array = smooth[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = smooth[Mesh.ARRAY_NORMAL]
		for i: int in range(verts.size()):
			verts[i] += ns[i] * grow
		smooth[Mesh.ARRAY_VERTEX] = verts
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, smooth)
	return out

static func _texture(geometry: GeometryInstance3D, mesh: Mesh) -> String:
	var look: Material = geometry.material_override
	if look == null and mesh.get_surface_count() > 0:
		look = (geometry as MeshInstance3D).get_active_material(0) if geometry is MeshInstance3D else mesh.surface_get_material(0)
	if look is BaseMaterial3D and look.albedo_texture != null: return look.albedo_texture.resource_path.get_file()
	return ""

## Bounds of the vertices the mesh actually draws; the source pack carries
## unused LOD vertices that inflate its AABB.
## The garden and park copies of Bush006 are per-plant duplicates of a few
## source meshes, so the same vertex/index data is measured many times. Results
## are cached by content: hashed, then verified array for array (== on packed
## arrays), so a hit is only ever the same data and the same result.
static var _bounds_cache: Dictionary = {}

## End-of-boot hook (scripts/shinrai_world_complete.gd finds this static method
## by name): the drawn-bounds cache only serves the swap passes of the build;
## a later pass (Creator) measures again and refills it. Memory only, no look change.
static func release_build_data() -> Dictionary:
	var freed := {"bounds_cache": _bounds_cache.size()}
	_bounds_cache = {}
	return freed

static func _drawn_bounds(mesh: Mesh) -> AABB:
	var surfaces: Array = []
	var key := mesh.get_surface_count()
	for s: int in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		var index_array := PackedInt32Array(indices) if indices != null else PackedInt32Array()
		surfaces.append([points, index_array])
		key = hash([key, points.size(), index_array.size(), hash(points), hash(index_array)])
	for entry: Array in _bounds_cache.get(key, []):
		var same: bool = (entry[0] as Array).size() == surfaces.size()
		for s: int in range(surfaces.size()):
			if not same: break
			same = entry[0][s][0] == surfaces[s][0] and entry[0][s][1] == surfaces[s][1]
		if same: return entry[1]
	var box := _measure_drawn(surfaces)
	# Bounded: distinct source meshes are few; stop remembering past the cap.
	if _bounds_cache.size() < 256:
		if not _bounds_cache.has(key): _bounds_cache[key] = []
		_bounds_cache[key].append([surfaces, box])
	return box

## The original measuring loop, with the per-index "is it indexed" test hoisted
## out of the loop: the same points are expanded in the same order.
static func _measure_drawn(surfaces: Array) -> AABB:
	var box := AABB()
	var first := true
	for surface: Array in surfaces:
		var points: PackedVector3Array = surface[0]
		var indices: PackedInt32Array = surface[1]
		if indices.size() > 0:
			for k: int in range(indices.size()):
				var p := points[indices[k]]
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				else: box = box.expand(p)
		else:
			for k: int in range(points.size()):
				var p := points[k]
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				else: box = box.expand(p)
	return box
