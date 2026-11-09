extends RefCounted
## Shared helpers for the biome builders (scripts/midori_biomes.gd).
const Biomes := preload("res://scripts/midori_biomes.gd")
const Budget := preload("res://scripts/shinrai_loading_budget.gd")
const ShaderPool := preload("res://scripts/shinrai_shader_pool.gd")

## Frame counters at the start of a time-sliced loop (see settle()).
static func frames_now() -> Vector2i:
	return Vector2i(Engine.get_process_frames(), Engine.get_physics_frames())

## Time-sliced yield for loops of pure placement maths (no nodes added, freed or
## moved inside the loop): yields only once this frame's loading budget is spent.
## It replaces yields after a fixed number of rows: behind the menu every frame
## boundary costs a whole frame (~16 ms), and the fixed counts gave ~900 frames
## to the biome stage. Results never depend on where the frames fall.
static func slice(park: Node) -> void:
	await Budget.checkpoint(park, true)

## Runs `job.call(i)` for every i in [0, count) on WorkerThreadPool and returns
## the results in index order. Only for pure data work: the job reads constants,
## packed arrays and the terrain's data methods, and writes nothing shared (each
## task fills only its own slot), so the result does not depend on the threads.
## Blocks the main thread until done (these jobs are short; the work used to run
## on the main thread anyway).
static func parallel(count: int, job: Callable, label: String) -> Array:
	var slots: Array = []
	for i: int in range(count): slots.append({})
	var run := func(i: int) -> void:
		(slots[i] as Dictionary)["v"] = job.call(i)
	var task := WorkerThreadPool.add_group_task(run, count, -1, true, label)
	WorkerThreadPool.wait_for_group_task_completion(task)
	var out: Array = []
	for i: int in range(count):
		# A task that failed on its thread is redone here, so a result is always there.
		if not (slots[i] as Dictionary).has("v"): (slots[i] as Dictionary)["v"] = job.call(i)
		out.append(slots[i]["v"])
	return out

## What the fixed-count yields always gave the code after a converted loop: at
## least one frame boundary (deferred calls flushed) and two physics steps
## (bodies added before the loop are in the space) since `since`. Usually
## already true, then it returns at once.
static func settle(park: Node, since: Vector2i) -> void:
	if not is_instance_valid(park) or not park.is_inside_tree(): return
	var tree := park.get_tree()
	while Engine.get_process_frames() <= since.x:
		await tree.process_frame
		if not is_instance_valid(park): return
	while Engine.get_physics_frames() < since.y + 2:
		await tree.physics_frame
		if not is_instance_valid(park): return

## Where a new plant or tree may stand: on land, off paths and trails, clear of
## water, and not inside an existing tree.
static func open_ground(park: Node3D, terrain: Node, p: Vector2, clearance: float, tree_gap: float = 0.0) -> bool:
	if terrain != null and terrain.water_at(p): return false
	if terrain != null and terrain.shoreline.size() > 2 and Biomes.LAKE_NEAR.has_point(p) and Biomes.shore_distance(terrain, p, clearance + 1.5) < clearance + 0.5: return false
	if park.has_method("path_edge_distance_world") and park.path_edge_distance_world(p) < clearance: return false
	var trails := park.get_node_or_null("MidoriDesirePaths")
	if trails != null and trails.has_method("distance_to_path") and trails.distance_to_path(p) < clearance + 0.6: return false
	if tree_gap > 0.0:
		for local: Vector2 in park.occupied_tree_positions:
			if (local * 2.0).distance_to(p) < tree_gap: return false
	return true

## Soft mask of surfaces that are paved or built on, from the ground's own
## landscape mask (blue = protected aprons and banks).
static func height(terrain: Node, p: Vector2) -> float:
	return terrain.height_at(p) if terrain != null else 0.0

## Hides instances of low planting inside an area by collapsing their
## transforms. `keep(world_p) -> bool` decides per instance; a dithered pick
## from position keeps edges soft. Returns how many were hidden.
static func thin_multimeshes(roots: Array, filter: Callable, keep: Callable) -> int:
	var hidden := 0
	for root: Node in roots:
		if root == null: continue
		for node: MultiMeshInstance3D in root.find_children("*", "MultiMeshInstance3D", true, false):
			if node.multimesh == null or not filter.call(node): continue
			var many := node.multimesh
			var to_world := node.global_transform
			var changed := false
			for i: int in range(many.visible_instance_count if many.visible_instance_count >= 0 else many.instance_count):
				var t := many.get_instance_transform(i)
				if t.basis.get_scale().x < 0.0001: continue
				var at := to_world * t.origin
				if keep.call(Vector2(at.x, at.z)): continue
				t.basis = t.basis.scaled(Vector3.ONE * 0.00001)
				many.set_instance_transform(i, t)
				hidden += 1
				changed = true
			if changed: node.set_meta("biome_thinned", true)
	return hidden

## A small cupped five-lobed leaf, about 10 cm, base at the origin, lying flat.
static func leaf_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := PackedVector3Array()
	var lobes := 5
	for k: int in range(lobes * 2):
		var a := TAU * float(k) / float(lobes * 2)
		var r := 0.058 if k % 2 == 0 else 0.036
		# The lobe facing the stem is short, the tip lobe long.
		if k == lobes: r *= 0.55
		if k == 0: r *= 1.12
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		p.y = 0.006 * (p.length() / 0.055) * (p.length() / 0.055)
		rim.append(p)
	var centre := Vector3(0, 0.002, 0)
	for k: int in range(rim.size()):
		var a := rim[k]
		var b := rim[(k + 1) % rim.size()]
		for v: Vector3 in [centre, b, a]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z) * 8.0 + Vector2(0.5, 0.5))
			st.add_vertex(v)
	return st.commit()

const LEAF_SHADER := """
shader_type spatial;
render_mode cull_disabled;
void fragment() {
	// Leaves are seen from above; flip the lighting normal on the far side.
	if (!FRONT_FACING) NORMAL = -NORMAL;
	float vein = smoothstep(0.012, 0.0, abs(UV.x - 0.5) * 0.12) * 0.12;
	ALBEDO = COLOR.rgb * (1.0 - vein);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	BACKLIGHT = COLOR.rgb * 0.25;
}
"""

static func leaf_material() -> ShaderMaterial:
	# One pooled leaf shader for every leaf floor (maple glen, coppice, ...).
	return ShaderPool.material(LEAF_SHADER)

## Fallen-leaf colours: rust, tan, brown, a few still olive.
static func leaf_colour(rng: RandomNumberGenerator, warmth: float = 1.0) -> Color:
	var roll := rng.randf()
	var c: Color
	if roll < 0.35: c = Color(0.42, 0.17, 0.06)
	elif roll < 0.62: c = Color(0.52, 0.33, 0.13)
	elif roll < 0.85: c = Color(0.27, 0.15, 0.07)
	elif roll < 0.94: c = Color(0.55, 0.24, 0.07)
	else: c = Color(0.30, 0.31, 0.12)
	c = c.lerp(Color(0.33, 0.27, 0.15), 1.0 - warmth)
	return c * rng.randf_range(0.82, 1.1)

## The MultiMesh buffer for rows [Transform3D, Color, custom Color], each origin
## less `offset`: exactly the floats set_instance_transform, set_instance_color
## and set_instance_custom_data write (the 3x4 basis rows with the origin, then
## RGBA, then the custom RGBA), so one buffer assignment replaces two or three
## server calls per instance. `colours` / `custom` match the MultiMesh flags.
static func pack_rows(list: Array, offset: Vector3, colours: bool, custom: bool) -> PackedFloat32Array:
	var stride := 12 + (4 if colours else 0) + (4 if custom else 0)
	var buf := PackedFloat32Array()
	buf.resize(list.size() * stride)
	var k := 0
	for row: Array in list:
		var t: Transform3D = row[0]
		var o := t.origin - offset
		var bx := t.basis.x
		var by := t.basis.y
		var bz := t.basis.z
		buf[k] = bx.x; buf[k + 1] = by.x; buf[k + 2] = bz.x; buf[k + 3] = o.x
		buf[k + 4] = bx.y; buf[k + 5] = by.y; buf[k + 6] = bz.y; buf[k + 7] = o.y
		buf[k + 8] = bx.z; buf[k + 9] = by.z; buf[k + 10] = bz.z; buf[k + 11] = o.z
		k += 12
		if colours:
			var c: Color = row[1]
			buf[k] = c.r; buf[k + 1] = c.g; buf[k + 2] = c.b; buf[k + 3] = c.a
			k += 4
		if custom:
			var d: Color = row[2]
			buf[k] = d.r; buf[k + 1] = d.g; buf[k + 2] = d.b; buf[k + 3] = d.a
			k += 4
	return buf

## pack_rows for plain transforms, each one `t * relative` less `offset` (the
## per-part batches of a prototype).
static func pack_transforms(list: Array, relative: Transform3D, offset: Vector3) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(list.size() * 12)
	var k := 0
	for item: Transform3D in list:
		var t: Transform3D = item * relative
		var o := t.origin - offset
		var bx := t.basis.x
		var by := t.basis.y
		var bz := t.basis.z
		buf[k] = bx.x; buf[k + 1] = by.x; buf[k + 2] = bz.x; buf[k + 3] = o.x
		buf[k + 4] = bx.y; buf[k + 5] = by.y; buf[k + 6] = bz.y; buf[k + 7] = o.y
		buf[k + 8] = bx.z; buf[k + 9] = by.z; buf[k + 10] = bz.z; buf[k + 11] = o.z
		k += 12
	return buf

## Rows at least this many are packed on WorkerThreadPool (one task per cell).
const PACK_THREADS_MIN := 2048

## The cell buffers pack_rows() gives for each key of `cells` in `keys` order,
## on WorkerThreadPool when there are enough rows (pure data: the same floats).
static func pack_cells(cells: Dictionary, keys: Array, cell: float, colours: bool, custom: bool, total: int) -> Array:
	var job := func(i: int) -> PackedFloat32Array:
		var key: Vector2i = keys[i]
		var list: Array = cells[key]
		return pack_rows(list, Vector3((key.x + 0.5) * cell, 0.0, (key.y + 0.5) * cell), colours if colours else list[0].size() > 1, custom)
	if total < PACK_THREADS_MIN or keys.size() < 2:
		var out: Array = []
		for i: int in range(keys.size()): out.append(job.call(i))
		return out
	return parallel(keys.size(), job, "biome_kit pack")

## pack_transforms() of every (cell, part) pair, cells in `keys` order and parts
## in order within each cell; on WorkerThreadPool when there are enough rows.
static func pack_part_cells(cells: Dictionary, keys: Array, cell: float, parts: Array, total: int) -> Array:
	var count := keys.size() * parts.size()
	var job := func(i: int) -> PackedFloat32Array:
		var key: Vector2i = keys[i / parts.size()]
		var part: Dictionary = parts[i % parts.size()]
		return pack_transforms(cells[key], part.relative, Vector3((key.x + 0.5) * cell, 0.0, (key.y + 0.5) * cell))
	if total * parts.size() < PACK_THREADS_MIN or count < 2:
		var out: Array = []
		for i: int in range(count): out.append(job.call(i))
		return out
	return parallel(count, job, "biome_kit pack parts")

## Builds instance batches in square cells so far cells drop out by range.
static func cell_batches(parent: Node3D, name: String, mesh: Mesh, material: Material, rows: Array, cell: float, range_end: float, shadows: bool) -> int:
	var cells := {}
	for row: Array in rows:
		var t: Transform3D = row[0]
		var key := Vector2i(floori(t.origin.x / cell), floori(t.origin.z / cell))
		if not cells.has(key): cells[key] = []
		cells[key].append(row)
	var keys: Array = cells.keys()
	# colours=false: each cell's own rows decide (list[0].size() > 1), as below.
	var buffers := pack_cells(cells, keys, cell, false, false, rows.size())
	for index: int in range(keys.size()):
		var key: Vector2i = keys[index]
		var list: Array = cells[key]
		var centre := Vector3((key.x + 0.5) * cell, 0.0, (key.y + 0.5) * cell)
		var many := MultiMesh.new()
		many.transform_format = MultiMesh.TRANSFORM_3D
		many.use_colors = list[0].size() > 1
		many.mesh = mesh
		many.instance_count = list.size()
		many.buffer = buffers[index]
		var node := MultiMeshInstance3D.new()
		node.name = "%s_%d_%d" % [name, key.x, key.y]
		node.multimesh = many
		node.position = centre
		if material != null: node.material_override = material
		node.visibility_range_end = range_end
		node.visibility_range_end_margin = range_end * 0.15
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
	return cells.size()

## The meshes of a placed-plant prototype with their offsets and joint bounds.
static func prototype_parts(park: Node3D, source: Node3D) -> Dictionary:
	var parts: Array = []
	var box := AABB()
	var first := true
	if source == null: return {"parts": parts, "box": box}
	for part: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null: continue
		var relative: Transform3D = park._vegetation_relative_transform(part, source) if park.has_method("_vegetation_relative_transform") else part.transform
		var mesh := part.mesh.duplicate() as Mesh
		for surface: int in range(mesh.get_surface_count()): mesh.surface_set_material(surface, part.get_active_material(surface))
		var b: AABB = relative * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
		parts.append({"mesh": mesh, "relative": relative})
	return {"parts": parts, "box": box}

## A glb file as prototype parts (forest-floor pieces).
static func file_parts(path: String) -> Dictionary:
	var parts: Array = []
	var box := AABB()
	var first := true
	if not ResourceLoader.exists(path): return {"parts": parts, "box": box}
	var scene: Node3D = load(path).instantiate()
	for part: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null: continue
		var relative := scene.global_transform.affine_inverse() * part.global_transform if part.is_inside_tree() else _chain(part, scene)
		var mesh := part.mesh.duplicate() as Mesh
		for surface: int in range(mesh.get_surface_count()): mesh.surface_set_material(surface, part.get_active_material(surface))
		var b: AABB = relative * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
		parts.append({"mesh": mesh, "relative": relative})
	scene.free()
	return {"parts": parts, "box": box}

static func _chain(node: Node3D, top: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != top:
		if at is Node3D: t = (at as Node3D).transform * t
		at = at.get_parent()
	return t

## Seat a prototype of the given height at p: random yaw, base on the ground.
static func seat(proto: Dictionary, terrain: Node, p: Vector2, height: float, yaw: float, sink: float = 0.0, extra: Basis = Basis.IDENTITY) -> Transform3D:
	var box: AABB = proto.box
	var basis := (Basis(Vector3.UP, yaw) * extra).scaled(Vector3.ONE * height / maxf(box.size.y, 0.001))
	var footprint := Transform3D(basis, Vector3.ZERO) * box
	var anchor := Vector3(footprint.get_center().x, footprint.position.y, footprint.get_center().z)
	return Transform3D(basis, Vector3(p.x, terrain.height_at(p) - sink, p.y) - anchor)

## One MultiMesh per part per cell, so far cells drop out by range.
static func batch_parts(parent: Node3D, name: String, proto: Dictionary, rows: Array, cell: float, range_end: float, shadows: bool = true) -> int:
	if rows.is_empty() or proto.parts.is_empty(): return 0
	var cells := {}
	for t: Transform3D in rows:
		var key := Vector2i(floori(t.origin.x / cell), floori(t.origin.z / cell))
		if not cells.has(key): cells[key] = []
		cells[key].append(t)
	var keys: Array = cells.keys()
	var buffers := pack_part_cells(cells, keys, cell, proto.parts, rows.size())
	var at := 0
	for key: Vector2i in keys:
		var list: Array = cells[key]
		var centre := Vector3((key.x + 0.5) * cell, 0.0, (key.y + 0.5) * cell)
		for part: Dictionary in proto.parts:
			var many := MultiMesh.new()
			many.transform_format = MultiMesh.TRANSFORM_3D
			many.mesh = part.mesh
			many.instance_count = list.size()
			many.buffer = buffers[at]
			at += 1
			var node := MultiMeshInstance3D.new()
			node.name = "%s_%d_%d" % [name, key.x, key.y]
			node.multimesh = many
			node.position = centre
			node.visibility_range_end = range_end
			node.visibility_range_end_margin = range_end * 0.15
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(node)
	return rows.size()

## Fallen leaves over a rectangle: density per m2 from `per_m2(p) -> float`.
static func leaf_floor(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, rect: Rect2, per_m2: Callable, warmth: float, name: String) -> int:
	var rows: Array = []
	var since := frames_now()
	for z: int in range(floori(rect.position.y), ceili(rect.end.y)):
		for x: int in range(floori(rect.position.x), ceili(rect.end.x)):
			var cell := Vector2(x + 0.5, z + 0.5)
			var d: float = per_m2.call(cell)
			if d <= 0.0 or terrain.water_at(cell): continue
			if park.path_edge_distance_world(cell) < 0.4: d *= 0.12
			var count := int(d) + (1 if rng.randf() < d - floorf(d) else 0)
			for k: int in range(count):
				var p := Vector2(x + rng.randf(), z + rng.randf())
				var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25)) * Basis(Vector3.FORWARD, rng.randf_range(-0.25, 0.25))
				rows.append([Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.85, 1.4)), Vector3(p.x, terrain.height_at(p) + 0.012 + rng.randf() * 0.01, p.y)), leaf_colour(rng, warmth)])
		await slice(park)
	await settle(park, since)
	cell_batches(root, name, leaf_mesh(), leaf_material(), rows, 8.0, 24.0, false)
	return rows.size()

## Distance to the nearest tree trunk (world metres), capped.
static func trunk_distance(park: Node3D, p: Vector2, cap: float = 20.0) -> float:
	var best := cap
	for local: Vector2 in park.occupied_tree_positions:
		var d := (local * 2.0).distance_to(p)
		if d < best: best = d
	return best

## Low planting names per node: for the thinning filters and reports.
static func inventory(park: Node3D, rect: Rect2) -> Dictionary:
	var names := {}
	for node: MultiMeshInstance3D in park.find_children("*", "MultiMeshInstance3D", true, false):
		if node.multimesh == null or node.multimesh.instance_count == 0: continue
		var c := node.global_position
		if not rect.has_point(Vector2(c.x, c.z)): continue
		var key := String(node.name).rstrip("0123456789_-@").left(30) + "|" + (node.multimesh.mesh.resource_name.left(24) if node.multimesh.mesh else "")
		names[key] = int(names.get(key, 0)) + node.multimesh.instance_count
	return names
