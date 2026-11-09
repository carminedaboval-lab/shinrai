extends RefCounted
## Zoki-bayashi, the north coppice (docs/biome_concepts/after_north_coppice.png).
## The darkest, most layered broadleaf ground in the park. Over the dark litter
## and moss of the look map (lawn blades and spiky beds thinned away) lie, in
## overlapping noise-shaped drifts, never rows:
##  - low mats of trailing periwinkle with paired leaves and dusty violet stars,
##  - fern drifts thickest in trunk shade,
##  - thickets of low shrubs with dark olive leaves and close-range twigs,
##  - mossy fallen logs lying a few metres off the walks, skirted by periwinkle,
##    and fallen branches.
## Paths, trails and lamps stay clear. Costs are held by visibility ranges per
## cell batch. The low, opaque foliage borrows the shadows of the existing canopy.
const Biomes := preload("res://scripts/midori_biomes.gd")
const Kit := preload("res://scripts/biomes/biome_kit.gd")
const ShaderPool := preload("res://scripts/shinrai_shader_pool.gd")
const Shore := preload("res://scripts/biomes/iris_shore.gd")
const ID := "zoki"
const RECT := Rect2(-100, -192, 154, 156)
const FLOOR := "res://assets/shinrai/parks/midori_park/models/forest_floor_20261026/"
const GRID_M := 2.0
const MAX_LOGS := 30
const MAX_SHRUBS := 270
## Windfall pockets on the south entry, each shoulder of the junction, and
## the west cabin verge. A candidate still has to clear the walks and trunks.
const WINDFALLS := [Vector3(-8.4, 0.85, -64.8), Vector3(21.0, 1.27, -145.8), Vector3(18.0, 0.78, -152.1), Vector3(-68.5, 1.2, -98.5)]
const THICKETS := [Vector2(-17, -66), Vector2(-4, -73), Vector2(-26, -76), Vector2(-7, -89), Vector2(14, -141), Vector2(13, -157), Vector2(5, -141), Vector2(-64, -96), Vector2(-59, -106)]
const FERN_ATLAS := preload("res://assets/shinrai/parks/midori_park/materials/coppice_litter/coppice_fern.png")
const PERIWINKLE := preload("res://assets/shinrai/parks/midori_park/models/forest_floor_20261026/groundcover_05_periwinkle_plant_diff_1k.png")
const OAK_SPRAY := preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/realistic_trees_collection/textures/leaves.011_baseColor.png")

const SPRIG_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D leaves : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
void fragment() {
	if (dot(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz) < 0.0) NORMAL = -NORMAL;
	vec4 surface = texture(leaves, UV);
	float value = dot(surface.rgb, vec3(0.25, 0.61, 0.14));
	ALBEDO = mix(mix(surface.rgb, value * vec3(0.84, 0.98, 0.62), 0.62), value * vec3(1.15, 0.93, 1.70), COLOR.a) * COLOR.rgb;
	ALPHA = surface.a;
	ALPHA_SCISSOR_THRESHOLD = 0.40;
	ROUGHNESS = 0.96;
	BACKLIGHT = ALBEDO * 0.08;
}
"""

static func build(park: Node3D, terrain: Node) -> Dictionary:
	var root := Node3D.new()
	root.name = "BiomeNorthCoppice"
	park.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20501102
	var inventory_before := Kit.inventory(park, RECT)
	var grid: Dictionary = await _grids(park, terrain)
	var thinned := _thin(park, grid)
	var space := park.get_world_3d().direct_space_state
	var trails := park.get_node_or_null("MidoriDesirePaths")
	var gap_at := func(q: Vector2) -> float:
		var g := 99.0
		if park.has_method("path_edge_distance_world"): g = minf(g, float(park.path_edge_distance_world(q)))
		if trails != null and trails.has_method("distance_to_path"): g = minf(g, float(trails.distance_to_path(q)) - 0.6)
		return g
	var bushes: Array = park.get("forest_floor_bush_prototypes")
	var bush := _shrub_parts(park, bushes[0] if not bushes.is_empty() else null)
	var fern := _mossy(Kit.prototype_parts(park, park.get("midnight_fern_prototype")), Color(0.84, 0.92, 0.68))
	var bark := _log_material()
	var windfalls := [_windfall_mesh(51745, bark), _windfall_mesh(51746, bark), _windfall_mesh(51747, bark)]
	var twigs: Array[Dictionary] = []
	for i: int in range(3):
		var t := Kit.file_parts(FLOOR + "branch_%02d.glb" % i)
		if not t.parts.is_empty(): twigs.append(t)
	# Logs first: they claim their ground, and periwinkle skirts them.
	var logs: Array = []
	var log_lines: Array = []
	_logs(park, terrain, rng, grid, gap_at, space, windfalls, logs, log_lines)
	var ferns: Array = [[], [], [], []]
	var fern_scans: Array = []
	var shrubs: Array = []
	var saplings: Array = []
	var sprigs: Array = [[], []]
	var tufts: Array = []
	var branch_rows: Array = []
	for i: int in range(twigs.size()): branch_rows.append([])
	var trunks: Dictionary = grid.trunks
	var since := Kit.frames_now()
	for z: int in range(int(RECT.position.y), int(RECT.end.y)):
		for x: int in range(int(RECT.position.x), int(RECT.end.x)):
			var c := Vector2(x + 0.5, z + 0.5)
			var w := _at(grid, "w", c)
			if w < 0.08: continue
			if terrain.water_at(c) or not _bare(space, terrain, c): continue
			var shade := 1.0 - smoothstep(2.5, 11.0, _at(grid, "trunk", c))
			# Broad overlapping runners occupy a metre of ground each. Break
			# them into large mats, with litter showing between the patches.
			var carpet := smoothstep(0.39, 0.65, _n(c, 1.5, Vector2(40, 9)))
			var d := w * (0.84 + 3.6 * carpet) * (0.85 + 0.3 * shade)
			for k: int in range(_count(rng, d)):
				var q := c + Vector2(rng.randf() - 0.5, rng.randf() - 0.5)
				if float(gap_at.call(q)) < 0.85 or terrain.water_at(q): continue
				_sprig(sprigs, rng, terrain, q, carpet)
			# Ferns: drifts, thickest in trunk shade, thinner over the carpets.
			var fn := smoothstep(0.38, 0.68, _n(c, 2.1, Vector2(-23, 61)))
			# Woodland grass and sedge tufts in the lighter gaps between them.
			var gd := w * (0.03 + 0.58 * (1.0 - shade)) * (1.0 - 0.7 * fn) * (1.0 - 0.65 * carpet)
			for k: int in range(_count(rng, gd)):
				var q := c + Vector2(rng.randf() - 0.5, rng.randf() - 0.5)
				if float(gap_at.call(q)) < 0.5: continue
				var s := rng.randf_range(0.75, 1.25)
				var tb := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08))
				tufts.append([Transform3D(tb.scaled(Vector3(s * rng.randf_range(0.9, 1.3), s, s * rng.randf_range(0.9, 1.3))), Vector3(q.x, terrain.height_at(q) - 0.02, q.y)), Color(1, 1, 1) * rng.randf_range(0.82, 1.04)])
			var fd := w * (0.18 + 1.26 * fn) * (0.7 + 0.65 * shade)
			for k: int in range(_count(rng, fd)):
				var q := c + Vector2(rng.randf() - 0.5, rng.randf() - 0.5)
				if float(gap_at.call(q)) < 1.05 or _trunk_near(trunks, q, 0.55) or _near_line(log_lines, q, 0.35): continue
				if terrain.water_at(q) or not _bare(space, terrain, q): continue
				var spread := rng.randf_range(0.75, 1.48) * (0.85 + 0.25 * fn)
				var fern_scale := Vector3(spread, spread * rng.randf_range(0.72, 1.22), spread)
				var fern_basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(fern_scale)
				var fern_transform := Transform3D(fern_basis, Vector3(q.x, terrain.height_at(q) - 0.018, q.y))
				if rng.randf() < 0.085:
					var fern_yaw := rng.randf() * TAU
					if Biomes.pick(q, 0.40, 73):
						fern_scans.append(Kit.seat(fern, terrain, q, fern_scale.y * 0.68, fern_yaw, 0.018))
					else:
						ferns[floori(fern_yaw * 4.0 / TAU) % 4].append([fern_transform])
				else:
					ferns[rng.randi_range(0, 3)].append([fern_transform])
			# Shrub thickets: a few bushes of mixed size round one centre.
			var sn := smoothstep(0.55, 0.8, _n(c, 1.55, Vector2(13, -37)))
			if rng.randf() < w * (0.004 + 0.018 * sn) and float(gap_at.call(c)) > 2.0 and not _trunk_near(trunks, c, 1.15) and not _near_line(log_lines, c, 1.0):
				_sapling(saplings, rng, terrain, c, rng.randf_range(0.72, 1.22))
			if rng.randf() < w * (0.003 + 0.055 * sn) * (0.48 + 0.9 * shade):
				var n := rng.randi_range(1, 2) + int(round(2.0 * sn))
				for k: int in range(n):
					var a := rng.randf() * TAU
					var q := c + Vector2(cos(a), sin(a)) * rng.randf_range(0.0, 1.6) * float(mini(k, 1))
					if float(gap_at.call(q)) < 1.7 or _trunk_near(trunks, q, 0.9) or _near_line(log_lines, q, 1.0): continue
					if not _bare(space, terrain, q): continue
					var tall := rng.randf_range(1.05, 1.65) * (1.0 + 0.25 * sn) * (0.68 if k > 0 else 1.0)
					shrubs.append(Kit.seat(bush, terrain, q, tall, rng.randf() * TAU, 0.06))
			# Fallen branches, odd ones.
			if not twigs.is_empty() and rng.randf() < 0.014 * w * (0.4 + shade):
				if float(gap_at.call(c)) > 0.8:
					var which := rng.randi() % twigs.size()
					var proto: Dictionary = twigs[which]
					var tilt := Basis(Vector3.FORWARD, rng.randf_range(-0.08, 0.08))
					branch_rows[which].append(Kit.seat(proto, terrain, c + Vector2(rng.randf() - 0.5, rng.randf() - 0.5), proto.box.size.y * rng.randf_range(0.7, 1.3), rng.randf() * TAU, 0.03, tilt))
		# Rows only collect transforms (nothing joins the scene or the physics
		# space inside this loop): yield on time, not on a row count.
		await Kit.slice(park)
	await Kit.settle(park, since)
	# Periwinkle hugging the logs, both sides, so they sit in the floor.
	for line: Array in log_lines:
		var a: Vector2 = line[0]
		var b: Vector2 = line[1]
		var side := (b - a).orthogonal().normalized()
		for k: int in range(int(a.distance_to(b) * 4.0)):
			var q := a.lerp(b, rng.randf()) + side * rng.randf_range(0.3, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)
			if float(gap_at.call(q)) < 0.85 or terrain.water_at(q): continue
			_sprig(sprigs, rng, terrain, q, 0.6)
	shrubs = _cap(rng, shrubs, MAX_SHRUBS)
	for centre: Vector2 in THICKETS:
		for k: int in range(10):
			var q := centre + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.5, 4.1)
			if _at(grid, "w", q) < 0.4 or terrain.water_at(q) or float(gap_at.call(q)) < 2.0: continue
			if _trunk_near(trunks, q, 1.15) or not _bare(space, terrain, q) or _near_line(log_lines, q, 0.85): continue
			_sapling(saplings, rng, terrain, q, rng.randf_range(0.8, 1.32))
	var off := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.cell_batches(root, "CoppiceStools", _sapling_mesh(), null, saplings, 16.0, 58.0, false)
	_batch(root, "CoppiceFernScans", fern.parts, fern_scans, 8.0, 12.0, off)
	_batch(root, "CoppiceShrubLeaves", bush.leaves, shrubs, 18.0, 56.0, off)
	_batch(root, "CoppiceShrubTwigs", bush.twigs, shrubs, 10.0, 22.0, off)
	for variant: int in range(windfalls.size()):
		var timber_rows: Array = []
		for i: int in range(variant, logs.size(), windfalls.size()): timber_rows.append(logs[i])
		var part := {"mesh": windfalls[variant].mesh, "relative": Transform3D.IDENTITY}
		_batch(root, "CoppiceLogs%d" % variant, [part], timber_rows, 32.0, 90.0, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	for i: int in range(twigs.size()): _batch(root, "CoppiceBranches%d" % i, twigs[i].parts, branch_rows[i], 12.0, 30.0, off)
	var material := ShaderPool.material(SPRIG_SHADER)
	material.set_shader_parameter("leaves", PERIWINKLE)
	for i: int in range(ferns.size()):
		var card := _fern_material(i)
		Kit.cell_batches(root, "CoppiceFerns%d" % i, _fern_crown(i), card, ferns[i], 14.0, 34.0, false)
	Kit.cell_batches(root, "CoppicePeriwinkle", _sprig_mesh(51103, false), material, sprigs[0], 12.0, 23.0, false)
	Kit.cell_batches(root, "CoppicePeriwinkleFlower", _sprig_mesh(51104, true), material, sprigs[1], 12.0, 23.0, false)
	# Tufts share the shore's procedural blade clumps and swaying shader.
	var tuft_mesh: ArrayMesh = Shore._clump_mesh(51105, _tuft_spec(), "CoppiceGrassTuft")
	Kit.cell_batches(root, "CoppiceGrass", tuft_mesh, Shore._plant_material(false, 0.025), tufts, 15.0, 28.0, false)
	var leaves := await _leaves(park, terrain, root, rng, grid, gap_at)
	var branches := 0
	for rows: Array in branch_rows: branches += rows.size()
	var fern_count := fern_scans.size()
	for group: Array in ferns: fern_count += group.size()
	return {"ferns": fern_count, "fern_scans": fern_scans.size(), "shrubs": shrubs.size(), "saplings": saplings.size(), "grass_tufts": tufts.size(), "logs": logs.size(), "log_pockets": root.get_meta("log_pockets", {}), "periwinkle": sprigs[0].size() + sprigs[1].size(), "periwinkle_flowering": sprigs[1].size(), "branches": branches, "leaves": leaves, "thinned": thinned, "inventory": inventory_before}

# ------------------------------------------------------------------ grids

## Biome weight and trunk distance on a 2 m grid over the area (weights_at
## searches the shoreline near the lake, too slow per plant).
static func _grids(park: Node3D, terrain: Node) -> Dictionary:
	var cols := int(ceil(RECT.size.x / GRID_M)) + 1
	var rows := int(ceil(RECT.size.y / GRID_M)) + 1
	var trunks := {}
	for local: Vector2 in park.occupied_tree_positions:
		var q := local * 2.0
		var key := Vector2i(floori(q.x / 4.0), floori(q.y / 4.0))
		if not trunks.has(key): trunks[key] = PackedVector2Array()
		var list: PackedVector2Array = trunks[key]
		list.append(q)
		trunks[key] = list
	var w := PackedFloat32Array()
	w.resize(cols * rows)
	var trunk := w.duplicate()
	var since := Kit.frames_now()
	# Pure maths per row (weights, and distances over the trunk table built
	# above, read only), on WorkerThreadPool; same floats in the same cells.
	Biomes.noise()
	# Each row reads its own copy of the weight kernel (Biomes.Kernel: the same
	# floats as Biomes.weight, nothing shared between the threads).
	var kernel := Biomes.terrain_kernel(terrain)
	var id_index := Biomes.region_index(ID)
	var job := func(r: int) -> Array:
		var k := kernel.clone()
		var wr := PackedFloat32Array()
		var tr := PackedFloat32Array()
		wr.resize(cols)
		tr.resize(cols)
		for c: int in range(cols):
			var p := RECT.position + Vector2(c, r) * GRID_M
			wr[c] = k.weight(p, id_index)
			tr[c] = _trunk_distance(trunks, p, 12.0)
		return [wr, tr]
	var done := Kit.parallel(rows, job, "north_coppice grids")
	for r: int in range(rows):
		var wr: PackedFloat32Array = done[r][0]
		var tr: PackedFloat32Array = done[r][1]
		for c: int in range(cols):
			w[r * cols + c] = wr[c]
			trunk[r * cols + c] = tr[c]
	await Kit.settle(park, since)
	return {"cols": cols, "rows": rows, "w": w, "trunk": trunk, "trunks": trunks}

static func _at(grid: Dictionary, key: String, p: Vector2) -> float:
	var arr: PackedFloat32Array = grid[key]
	var cols: int = grid.cols
	var q := (p - RECT.position) / GRID_M
	var x := clampi(floori(q.x), 0, cols - 2)
	var z := clampi(floori(q.y), 0, int(grid.rows) - 2)
	var f := Vector2(clampf(q.x - x, 0.0, 1.0), clampf(q.y - z, 0.0, 1.0))
	var i := z * cols + x
	return lerpf(lerpf(arr[i], arr[i + 1], f.x), lerpf(arr[i + cols], arr[i + cols + 1], f.x), f.y)

static func _trunk_distance(trunks: Dictionary, p: Vector2, cap: float) -> float:
	var best := cap
	var reach := ceili(cap / 4.0)
	var cx := floori(p.x / 4.0)
	var cz := floori(p.y / 4.0)
	for z: int in range(cz - reach, cz + reach + 1):
		for x: int in range(cx - reach, cx + reach + 1):
			var key := Vector2i(x, z)
			if not trunks.has(key): continue
			for q: Vector2 in (trunks[key] as PackedVector2Array):
				best = minf(best, q.distance_to(p))
	return best

static func _trunk_near(trunks: Dictionary, p: Vector2, r: float) -> bool:
	return _trunk_distance(trunks, p, r + 0.01) < r

static func _n(p: Vector2, scale: float, offset: Vector2) -> float:
	return 0.5 + 0.5 * Biomes.noise().get_noise_2dv(p * scale + offset)

static func _count(rng: RandomNumberGenerator, rate: float) -> int:
	if rate <= 0.0: return 0
	return int(rate) + (1 if rng.randf() < rate - floorf(rate) else 0)

## Nothing but ground under the point: no lamp, bench, sign or trunk.
static func _bare(space: PhysicsDirectSpaceState3D, terrain: Node, p: Vector2) -> bool:
	var ground: float = terrain.height_at(p)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, ground + 30.0, p.y), Vector3(p.x, ground - 1.0, p.y)))
	return hit.is_empty() or float(hit.position.y) < ground + 0.3

static func _near_line(lines: Array, p: Vector2, r: float) -> bool:
	for line: Array in lines:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[0], line[1])) < r + float(line[2]): return true
	return false

## Uniform subset without bias towards the first rows of the planting grid.
static func _cap(rng: RandomNumberGenerator, rows: Array, cap: int) -> Array:
	if rows.size() <= cap: return rows
	var out: Array = []
	for i: int in range(rows.size()):
		var needed := cap - out.size()
		if needed == 0: break
		if rng.randi_range(0, rows.size() - i - 1) < needed: out.append(rows[i])
	return out

# ------------------------------------------------------------------ logs

## The same seeded windfall pockets and path/obstacle tests serve all three
## shapes. Place the lowest points along each curved trunk on the actual terrain.
static func _logs(park: Node3D, terrain: Node, rng: RandomNumberGenerator, grid: Dictionary, gap_at: Callable, space: PhysicsDirectSpaceState3D, shapes: Array, logs: Array, lines: Array) -> void:
	var spots: Array[Vector2] = []
	var windfalls := {}
	for attempt: int in range(6000):
		if logs.size() >= MAX_LOGS: break
		var site := floori(float(attempt) / 192.0)
		var landmark := site < WINDFALLS.size()
		if landmark and windfalls.has(site): continue
		var p := RECT.position + Vector2(rng.randf() * RECT.size.x, rng.randf() * RECT.size.y)
		var yaw := rng.randf() * TAU
		if landmark:
			var pocket: Vector3 = WINDFALLS[site]
			p = Vector2(pocket.x, pocket.z) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.1, 2.9)
			yaw = pocket.y + rng.randf_range(-0.55, 0.55)
		var w := _at(grid, "w", p)
		if w < 0.45: continue
		var gap: float = gap_at.call(p)
		# Mostly 1.8-6 m off a walk; a few deeper in.
		if gap < (1.1 if landmark else 1.8) or (not landmark and gap > 6.5 and rng.randf() > 0.12): continue
		var near := false
		for other: Vector2 in spots: if other.distance_to(p) < (5.0 if landmark else 11.0): near = true
		if near or terrain.water_at(p): continue
		var length := rng.randf_range(3.7, 5.8)
		var girth := rng.randf_range(0.86, 1.22)
		var turned := Basis(Vector3.UP, yaw).x
		var axis := Vector2(turned.x, turned.z).normalized()
		var a := p - axis * length * 0.5
		var b := p + axis * length * 0.5
		if not _log_clear(a, b, grid.trunks, gap_at, space, terrain): continue
		# Across the south entry, the long bark flank faces the walk. The
		# junction shoulders have dissimilar fall directions and smaller stems.
		# Preserve the seeded selection, then check every new orientation.
		if landmark and site < 3:
			var bearings := [-0.22, -0.52, 1.26]
			if site != 0:
				length *= 0.82 if site == 1 else 0.92
				girth *= 0.75 if site == 1 else 0.83
			for offset: float in [0.0, 0.2, -0.22, 0.42, -0.45]:
				var angle: float = bearings[site] + offset
				var turn := Vector2(cos(angle), -sin(angle))
				var candidate_a := p - turn * length * 0.5
				var candidate_b := p + turn * length * 0.5
				if _log_clear(candidate_a, candidate_b, grid.trunks, gap_at, space, terrain):
					axis = turn
					break
			a = p - axis * length * 0.5
			b = p + axis * length * 0.5
		var ha := float(terrain.height_at(a))
		var hb := float(terrain.height_at(b))
		var slope := Vector3(axis.x, (hb - ha) / length, axis.y).normalized()
		var side := slope.cross(Vector3.UP).normalized()
		var up := side.cross(slope).normalized()
		var basis := Basis(slope, up, side) * Basis.from_scale(Vector3(length / 4.6, girth, girth))
		var shape: Dictionary = shapes[logs.size() % shapes.size()]
		var support := -INF
		for contact: Vector3 in shape.contacts:
			var foot := basis * contact
			var ground := float(terrain.height_at(p + Vector2(foot.x, foot.z)))
			support = maxf(support, ground - foot.y)
		var t := Transform3D(basis, Vector3(p.x, support - 0.065, p.y))
		logs.append(t)
		spots.append(p)
		lines.append([a, b, 0.4])
		if landmark: windfalls[site] = p
	park.get_node("BiomeNorthCoppice").set_meta("log_pockets", windfalls)

static func _log_clear(a: Vector2, b: Vector2, trunks: Dictionary, gap_at: Callable, space: PhysicsDirectSpaceState3D, terrain: Node) -> bool:
	for k: int in range(5):
		var q := a.lerp(b, float(k) / 4.0)
		if terrain.water_at(q) or float(gap_at.call(q)) < 0.8 or _trunk_near(trunks, q, 1.0) or not _bare(space, terrain, q): return false
	return true

## A trunk, its snapped branch collars and end grain share one material and draw.
## Build in metres along X. The bark UVs run around and along the timber.
static func _windfall_mesh(seed_value: int, material: ShaderMaterial) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	var centres: Array[Vector3] = []
	var radii: Array[float] = []
	var contacts: Array[Vector3] = []
	var bow := rng.randf_range(0.12, 0.25) * (-1.0 if seed_value % 2 == 0 else 1.0)
	var arch := rng.randf_range(0.072, 0.15)
	var phase := rng.randf() * TAU
	for j: int in range(12):
		var t := float(j) / 11.0
		var bend := sin(PI * t)
		var z := bow * bend + 0.068 * sin(TAU * t + phase) * bend
		var y := arch * bend + 0.044 * sin(3.0 * PI * t + phase) * bend
		centres.append(Vector3(lerpf(-2.3, 2.3, t), y, z))
		radii.append(lerpf(0.34, 0.17, t) + 0.035 * exp(-8.0 * t) + 0.02 * sin(4.0 * PI * t + phase))
	_timber_shell(st, centres, radii, rng, 17, 0.135, contacts)
	for k: int in range(2):
		var j := 2 + k * 4 + rng.randi_range(0, 1)
		var hand := -1.0 if k % 2 == 0 else 1.0
		var out := Vector3(rng.randf_range(0.69, 1.13), rng.randf_range(0.18, 0.44), hand * rng.randf_range(0.27, 0.49)).normalized()
		var base := centres[j] + Vector3(0, out.y, out.z).normalized() * radii[j] * 0.67
		var collar := base + out * 0.18
		var end := collar + (out + Vector3(0.08, 0.14, -0.11 * hand)).normalized() * rng.randf_range(0.105, 0.23)
		var limbs: Array[Vector3] = [base, collar, end]
		var widths: Array[float] = [0.126, 0.094, rng.randf_range(0.071, 0.088)]
		_timber_shell(st, limbs, widths, rng, 11, 0.023, [])
	st.index()
	st.generate_tangents()
	var mesh := st.commit()
	mesh.resource_name = "CoppiceWindfall%d" % seed_value
	return {"mesh": mesh, "contacts": contacts}

static func _timber_shell(st: SurfaceTool, centres: Array[Vector3], radii: Array[float], rng: RandomNumberGenerator, sides: int, chip: float, contacts: Array) -> void:
	var rings: Array = []
	var normals: Array = []
	var offsets := PackedFloat32Array()
	var lobes := PackedFloat32Array()
	for i: int in range(sides):
		offsets.append(rng.randf_range(-0.06, 0.06))
		lobes.append(rng.randf_range(-0.06, 0.06))
	var phase := rng.randf() * TAU
	for j: int in range(centres.size()):
		var axis := (centres[mini(j + 1, centres.size() - 1)] - centres[maxi(0, j - 1)]).normalized()
		var radial := axis.cross(Vector3.FORWARD).normalized()
		var tangent := axis.cross(radial).normalized()
		var ring := PackedVector3Array()
		var face := PackedVector3Array()
		var low := Vector3(0, INF, 0)
		for i: int in range(sides):
			var angle := TAU * float(i) / float(sides) + offsets[i]
			var n := radial * cos(angle) + tangent * sin(angle)
			# Long flutes turn slowly down the trunk. At a break, end fibres
			# tear to different lengths and expose splinters across the rim.
			var r := radii[j] * (1.0 + lobes[i] + 0.075 * sin(3.0 * angle + float(j) * 0.17 + phase))
			var p := centres[j] + n * r
			if j == 0 or j == centres.size() - 1:
				var depth := chip * (0.55 * sin(3.0 * angle + phase) + rng.randf_range(-0.72, 0.72))
				p += axis * (depth * 1.48 if i == 4 else depth)
			ring.append(p)
			face.append(n)
			if p.y < low.y: low = p
		rings.append(ring)
		normals.append(face)
		contacts.append(low)
	var axial_distance := 0.0
	var circumference := TAU * radii[0]
	for j: int in range(centres.size() - 1):
		var next_distance := axial_distance + centres[j].distance_to(centres[j + 1])
		for i: int in range(sides):
			var ni := (i + 1) % sides
			var u0 := float(i) * circumference / (float(sides) * 0.78)
			var u1 := float(i + 1) * circumference / (float(sides) * 0.78)
			var pts := [rings[j][i], rings[j + 1][i], rings[j + 1][ni], rings[j][ni]]
			var ns := [normals[j][i], normals[j + 1][i], normals[j + 1][ni], normals[j][ni]]
			var uvs := [Vector2(u0, axial_distance), Vector2(u0, next_distance), Vector2(u1, next_distance), Vector2(u1, axial_distance)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color(0, 1, 1, 1))
				st.set_normal(ns[k])
				st.set_uv(uvs[k])
				st.add_vertex(pts[k])
		axial_distance = next_distance
	for j: int in [0, centres.size() - 1]:
		var normal := (centres[j] - centres[1 if j == 0 else j - 1]).normalized()
		var end_centre := centres[j] - normal * chip * 0.56
		var split: Vector3 = rings[j][floori(float(sides) / 3.0)]
		end_centre += (split - centres[j]) * 0.11
		for i: int in range(sides):
			var ni := (i + 1) % sides
			var pa: Vector3 = rings[j][i]
			var pb: Vector3 = rings[j][ni]
			var ua := Vector2.from_angle(TAU * float(i) / float(sides))
			var ub := Vector2.from_angle(TAU * float(ni) / float(sides))
			var ia := end_centre.lerp(pa, 0.77) - normal * chip * (0.17 + 0.16 * sin(float(i) * 2.83))
			var ib := end_centre.lerp(pb, 0.77) - normal * chip * (0.17 + 0.16 * sin(float(ni) * 2.83))
			var pts := [pa, pb, ib, ia, end_centre]
			var uvs := [ua, ub, ub * 0.81, ua * 0.81, Vector2.ZERO]
			var idx := [0, 1, 2, 0, 2, 3, 3, 2, 4] if j == 0 else [0, 2, 1, 0, 3, 2, 3, 4, 2]
			for k: int in range(0, idx.size(), 3):
				var first: Vector3 = pts[idx[k]]
				var second: Vector3 = pts[idx[k + 1]]
				var third: Vector3 = pts[idx[k + 2]]
				var fracture := (third - first).cross(second - first).normalized()
				if fracture.dot(normal) < 0.0: fracture = -fracture
				for corner: int in range(k, k + 3):
					var vi: int = idx[corner]
					st.set_color(Color(1, 1, 1, 1))
					st.set_normal(fracture.lerp(normal, 0.28).normalized())
					st.set_uv(uvs[vi])
					st.add_vertex(pts[vi])

static func _log_material() -> ShaderMaterial:
	var material := ShaderPool.material("""
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D bark : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
varying vec3 point;
varying vec3 world_normal;
void vertex() {
	point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
float bark_value(vec2 uv) {
	return dot(texture(bark, uv).rgb, vec3(0.26, 0.60, 0.14));
}
void fragment() {
	vec3 wood;
	NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.55;
	if (COLOR.r > 0.5) {
		vec2 end_uv = UV + vec2(0.17, -0.05);
		float radius = length(end_uv);
		float fibre = bark_value(end_uv * vec2(0.79, 1.3) + vec2(0.37, 0.12));
		float rings = sin(radius * 69.0 + 2.0 * sin(end_uv.x * 4.7 + end_uv.y * 6.3) + fibre * 5.7);
		float theta = atan(end_uv.y, end_uv.x);
		float split = abs(sin(theta * 2.5 + 0.21 * sin(radius * 7.0) + 0.6));
		float checks = (1.0 - smoothstep(0.014, 0.064, split)) * smoothstep(0.35, 0.79, radius);
		wood = mix(vec3(0.092, 0.069, 0.048), vec3(0.28, 0.207, 0.145), clamp(0.18 + fibre * 2.5 + rings * 0.085, 0.0, 1.0));
		wood *= (1.0 - checks * 0.58) * mix(1.0, 0.64, smoothstep(0.80, 1.0, length(UV)));
	} else {
		// Preserve the albedo tile's scale, bark plates, lichen and dark cracks.
		vec3 scan = texture(bark, UV).rgb;
		float grain = dot(scan, vec3(0.26, 0.60, 0.14));
		vec2 step_uv = 2.0 / vec2(textureSize(bark, 0));
		float dx = bark_value(UV + vec2(step_uv.x, 0.0)) - bark_value(UV - vec2(step_uv.x, 0.0));
		float dy = bark_value(UV + vec2(0.0, step_uv.y)) - bark_value(UV - vec2(0.0, step_uv.y));
		NORMAL_MAP = normalize(vec3(-dx * 2.8, -dy * 2.8, 1.0)) * 0.5 + 0.5;
		float fleck = bark_value(point.xz * 0.80 + vec2(0.13, 0.43));
		float moss = smoothstep(0.28, 0.80, world_normal.y) * smoothstep(0.09, 0.29, fleck);
		wood = scan * mix(0.88, 1.06, smoothstep(0.025, 0.24, grain));
		wood *= mix(vec3(1.0), vec3(0.86, 1.03, 0.80), moss * 0.58);
	}
	ALBEDO = wood;
	SPECULAR = 0.06;
	ROUGHNESS = 0.97;
}
""")
	material.set_shader_parameter("bark", preload("res://assets/shinrai/parks/midori_park/materials/coppice_litter/coppice_bark.png"))
	return material

## Tint only the copied fern surfaces.
static func _mossy(proto: Dictionary, tint: Color) -> Dictionary:
	var shared := {}
	for part: Dictionary in proto.parts:
		var mesh: Mesh = part.mesh
		for s: int in range(mesh.get_surface_count()):
			var src := mesh.surface_get_material(s) as BaseMaterial3D
			if src == null: continue
			if not shared.has(src):
				var copy := src.duplicate() as BaseMaterial3D
				copy.albedo_color = src.albedo_color * tint
				shared[src] = copy
			mesh.surface_set_material(s, shared[src])
	return proto

# ---------------------------------------------------------------- shrubs

## The floor bush split into its leaf cards and its twigs, the leaves on one
## shared darker olive material (alpha scissor, not blended).
static func _shrub_parts(park: Node3D, source: Node3D) -> Dictionary:
	var proto := Kit.prototype_parts(park, source)
	var leaves: Array = []
	var twigs: Array = []
	var shared := {}
	for part: Dictionary in proto.parts:
		var mesh: Mesh = part.mesh
		var leafy := false
		for s: int in range(mesh.get_surface_count()):
			var src := mesh.surface_get_material(s) as BaseMaterial3D
			if src == null or src.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED: continue
			leafy = true
			if not shared.has(src):
				var dark := src.duplicate() as BaseMaterial3D
				dark.albedo_color = src.albedo_color * Color(0.62, 0.66, 0.5)
				dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				dark.alpha_scissor_threshold = 0.4
				shared[src] = dark
			mesh.surface_set_material(s, shared[src])
		if leafy: leaves.append(part)
		else: twigs.append(part)
	if leaves.is_empty(): leaves = proto.parts
	return {"parts": proto.parts, "leaves": leaves, "twigs": twigs, "box": proto.box}

## One MultiMesh per part per cell, with a shadow mode.
static func _batch(parent: Node3D, name: String, parts: Array, rows: Array, cell: float, range_end: float, shadow: GeometryInstance3D.ShadowCastingSetting) -> void:
	if rows.is_empty() or parts.is_empty(): return
	var cells := {}
	for t: Transform3D in rows:
		var key := Vector2i(floori(t.origin.x / cell), floori(t.origin.z / cell))
		if not cells.has(key): cells[key] = []
		cells[key].append(t)
	var keys: Array = cells.keys()
	var buffers := Kit.pack_part_cells(cells, keys, cell, parts, rows.size())
	var at := 0
	for key: Vector2i in keys:
		var list: Array = cells[key]
		var centre := Vector3((key.x + 0.5) * cell, 0.0, (key.y + 0.5) * cell)
		for part: Dictionary in parts:
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
			node.visibility_range_end_margin = range_end * 0.1
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED if shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY else GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			node.cast_shadow = shadow
			parent.add_child(node)

# ------------------------------------------------------------- ground layer

## Two low sprays arch out of the rhizome. They retain their orientation when
## the player turns, and the lighter tips rise out of the shaded crown.
static func _fern_crown(variant: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(2):
		var forward := Vector3.FORWARD.rotated(Vector3.UP, float(i) * 2.47 + variant * 0.38)
		var across := forward.cross(Vector3.UP)
		var ring: Array[Vector3] = [Vector3.ZERO, forward * 0.19 + Vector3.UP * 0.33, forward * 0.52 + Vector3.UP * (0.46 - i * 0.09)]
		for row: int in range(2):
			for corner: int in [0, 2, 1, 1, 2, 3]:
				var j := row + (1 if corner >= 2 else 0)
				var right := float(corner % 2)
				var v := float(j) * 0.5
				var width := 0.58 - v * 0.11
				var shade := 0.48 + v * 0.50
				surface.set_color(Color(shade, shade, shade, 1.0))
				surface.set_normal((Vector3.UP + forward * (v - 0.30) + across * (right - 0.5) * 0.32).normalized())
				surface.set_uv(Vector2(right, 1.0 - v))
				surface.add_vertex(ring[j] + across * (right * 2.0 - 1.0) * width)
	surface.index()
	return surface.commit()

static func _fern_material(index: int) -> ShaderMaterial:
	# Every fern index shares one pooled shader; the atlas quadrant is a uniform.
	var mat := ShaderPool.material("""
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D fronds : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 quadrant;
void fragment() {
	vec4 leaf = texture(fronds, UV * 0.5 + quadrant);
	vec3 skyward = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	if (dot(NORMAL, skyward) < 0.0) NORMAL = -NORMAL;
	NORMAL = normalize(mix(NORMAL, skyward, 0.70));
	float luma = dot(leaf.rgb, vec3(0.26, 0.61, 0.13));
	ALBEDO = mix(leaf.rgb, luma * vec3(0.82, 0.93, 0.63), 0.4) * COLOR.rgb * 0.86;
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.98;
	BACKLIGHT = ALBEDO * 0.14;
}
""")
	mat.set_shader_parameter("fronds", FERN_ATLAS)
	mat.set_shader_parameter("quadrant", Vector2(index % 2, floorf(float(index) * 0.5)) * 0.5)
	return mat

static func _sapling(rows: Array, rng: RandomNumberGenerator, terrain: Node, point: Vector2, scale_m: float) -> void:
	var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(scale_m, scale_m * rng.randf_range(0.84, 1.15), scale_m))
	rows.append([Transform3D(basis, Vector3(point.x, terrain.height_at(point) - 0.035, point.y))])

## A coppiced stool sends up several leaning woody shoots. Scanned oak sprays
## sit on the shoots at different heights; spaces between them reveal the stems.
static func _sapling_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 51741
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var foliage := SurfaceTool.new()
	foliage.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in range(6):
		var angle := TAU * (float(k) + rng.randf_range(-0.32, 0.32)) / 6.0
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-out.z, 0, out.x)
		var foot := out * rng.randf_range(0.03, 0.18)
		var top := foot + out * rng.randf_range(0.54, 1.35) + Vector3.UP * rng.randf_range(1.66, 3.25)
		var bend := foot.lerp(top, 0.55) + out * 0.17
		_wood_stem(wood, foot, bend, 0.046, 0.027)
		_wood_stem(wood, bend, top, 0.027, 0.009)
		for j: int in range(8):
			var hand := -1.0 if j % 2 == 0 else 1.0
			var t := rng.randf_range(0.32, 0.95)
			var start := bend.lerp(top, maxf(0.0, (t - 0.55) / 0.45)) if t >= 0.55 else foot.lerp(bend, t / 0.55)
			var branch := (side * hand * rng.randf_range(0.3, 1.05) + out * rng.randf_range(0.14, 0.62) + Vector3.UP * rng.randf_range(0.24, 0.85))
			var across := Vector3(-branch.z, rng.randf_range(-0.16, 0.16), branch.x).normalized() * rng.randf_range(0.3, 0.55)
			var end := start + branch
			var light := Color.WHITE.darkened(rng.randf_range(0.05, 0.34))
			_card(foliage, start, end, across, Vector2.ZERO, Vector2.ONE, light, Vector3.UP.lerp(out, 0.38).normalized())
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.28, 0.23, 0.145)
	bark.roughness = 0.98
	wood.set_material(bark)
	var result := wood.commit()
	var leaves := ShaderPool.material("""
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D leaf_spray : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
void fragment() {
	vec4 scan = texture(leaf_spray, UV);
	float lightness = dot(scan.rgb, vec3(0.27, 0.63, 0.10));
	vec3 skyward = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	if (dot(NORMAL, skyward) < 0.0) NORMAL = -NORMAL;
	ALBEDO = mix(scan.rgb, lightness * vec3(0.59, 0.74, 0.36), 0.55) * COLOR.rgb * 0.67;
	ALPHA = scan.a;
	ALPHA_SCISSOR_THRESHOLD = 0.48;
	ROUGHNESS = 1.0;
	BACKLIGHT = ALBEDO * 0.11;
}
""")
	leaves.set_shader_parameter("leaf_spray", OAK_SPRAY)
	foliage.set_material(leaves)
	foliage.index()
	foliage.commit(result)
	return result

static func _wood_stem(st: SurfaceTool, start: Vector3, end: Vector3, base_radius: float, tip_radius: float) -> void:
	var axis := (end - start).normalized()
	var across := axis.cross(Vector3.FORWARD).normalized()
	var side := axis.cross(across)
	for k: int in range(5):
		var a := TAU * float(k) / 5.0
		var b := TAU * float(k + 1) / 5.0
		var n := across * cos(a) + side * sin(a)
		var m := across * cos(b) + side * sin(b)
		st.set_normal((n + m).normalized())
		for p: Vector3 in [start + n * base_radius, end + m * tip_radius, start + m * base_radius, start + n * base_radius, end + n * tip_radius, end + m * tip_radius]:
			st.add_vertex(p)

static func _card(st: SurfaceTool, base: Vector3, tip: Vector3, across: Vector3, uv_min: Vector2, uv_max: Vector2, color: Color, normal: Vector3) -> void:
	var vertices := [base - across, base + across, tip + across, tip - across]
	var uv := [Vector2(uv_min.x, uv_max.y), uv_max, Vector2(uv_max.x, uv_min.y), uv_min]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_color(color)
		st.set_normal(normal)
		st.set_uv(uv[i])
		st.add_vertex(vertices[i])

static func _ribbon(st: SurfaceTool, a: Vector3, b: Vector3, lateral: Vector3, colour: Color) -> void:
	for p: Vector3 in [a - lateral, a + lateral, b + lateral, a - lateral, b + lateral, b - lateral]:
		st.set_color(colour)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.045, 0.21))
		st.add_vertex(p)

static func _sprig(sprigs: Array, rng: RandomNumberGenerator, terrain: Node, q: Vector2, carpet: float) -> void:
	var s := rng.randf_range(0.85, 1.34)
	var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * rng.randf_range(0.85, 1.28), s))
	var t := Transform3D(basis, Vector3(q.x, terrain.height_at(q) - 0.005, q.y))
	var tint := rng.randf_range(0.82, 1.0)
	sprigs[1 if rng.randf() < 0.05 + 0.18 * carpet else 0].append([t, Color(tint, tint, tint, 1.0)])

## A periwinkle sprig: three or four trailing stems arching off the ground,
## pairs of small oval glossy leaves along them, and (`flowers`) one or two
## pale violet five-petalled stars held just above the leaves.
static func _sprig_mesh(seed_value: int, flowers: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var greens: Array[Color] = [Color(0.79, 0.84, 0.71, 0), Color(0.84, 0.88, 0.77, 0), Color(0.93, 0.95, 0.82, 0)]
	var stem_color := Color(0.63, 0.64, 0.55, 0)
	var stems := 4
	var tips: Array[Vector3] = []
	for k: int in range(stems):
		var a := TAU * (float(k) + rng.randf_range(-0.3, 0.3)) / float(stems)
		var out := Vector3(cos(a), 0.0, sin(a))
		var length := rng.randf_range(0.33, 0.56)
		var lateral := Vector3(-out.z, 0, out.x)
		var curl := rng.randf_range(-0.18, 0.18)
		var rise := rng.randf_range(0.095, 0.20)
		var pairs := 4
		var prev := Vector3.ZERO
		for j: int in range(pairs):
			var t := (float(j) + 1.0) / float(pairs)
			var at := out * length * t + lateral * (curl * t * t) + Vector3.UP * (rise * sin(PI * t * 0.82) + 0.022)
			_ribbon(st, prev, at, lateral * 0.0055, stem_color)
			prev = at
			var size := lerpf(1.0, 0.7, t) * rng.randf_range(0.85, 1.1)
			for side: float in [-1.0, 1.0]:
				var dir := (out.rotated(Vector3.UP, side * rng.randf_range(1.0, 1.4))).normalized()
				var colour: Color = greens[rng.randi() % greens.size()]
				_leaf(st, at, dir, 0.123 * size, 0.080 * size, rng.randf_range(-0.12, 0.55), colour)
		tips.append(prev)
	if flowers:
		for k: int in range(rng.randi_range(1, 2)):
			_flower(st, tips[k] + Vector3(0.0, rng.randf_range(0.0, 0.02), 0.0), rng)
	st.index()
	return st.commit()

## The periwinkle atlas has individual photographed leaves. A curled strip
## keeps their own outline, central vein and speckled surface when seen close.
static func _leaf(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, width: float, pitch: float, colour: Color) -> void:
	var forward := (dir * cos(pitch) + Vector3.UP * sin(pitch)).normalized()
	var side := forward.cross(Vector3.UP).normalized()
	var normal := side.cross(forward).normalized()
	var start := base - forward * length * 0.04
	var end := base + forward * length
	var mid := start.lerp(end, 0.5) + Vector3.UP * width * 0.18
	var box := Rect2(0.194, 0.108, 0.181, 0.102)
	for section: int in range(2):
		var a := start if section == 0 else mid
		var b := mid if section == 0 else end
		var u0 := box.position.x + box.size.x * float(section) * 0.5
		var u1 := u0 + box.size.x * 0.5
		var pts := [a - side * width * 0.5, b - side * width * 0.5, b + side * width * 0.5, a + side * width * 0.5]
		var uvs := [Vector2(u0,box.end.y), Vector2(u1,box.end.y), Vector2(u1,box.position.y), Vector2(u0,box.position.y)]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(colour)
			st.set_normal(normal)
			st.set_uv(uvs[i])
			st.add_vertex(pts[i])

static func _flower(st: SurfaceTool, centre: Vector3, rng: RandomNumberGenerator) -> void:
	var angle := TAU * rng.randf()
	var forward := Vector3(cos(angle), 0.15, sin(angle)).normalized()
	var side := forward.cross(Vector3.UP).normalized() * 0.037
	_card(st, centre - forward * 0.037, centre + forward * 0.037, side, Vector2(0.283, 0.237), Vector2(0.530, 0.489), Color(0.93, 0.94, 1.0, 1.0), Vector3.UP)

## A shin-high woodland grass / sedge tuft: dark olive, some dry blades.
static func _tuft_spec() -> Dictionary:
	return {"blades": 17, "spread": 0.14, "h_min": 0.23, "h_max": 0.49, "lean_min": 0.3, "lean_max": 0.68, "bend_min": 0.7, "bend_max": 1.5, "w_min": 0.007, "w_max": 0.011, "rows": 2, "dead": 0.22, "twist": 0.6, "edge_on": 0.3,
		"palette": [Shore._lin(0.12, 0.14, 0.06), Shore._lin(0.22, 0.26, 0.11), Shore._lin(0.33, 0.35, 0.18)],
		"dead_palette": [Shore._lin(0.28, 0.23, 0.14), Shore._lin(0.43, 0.37, 0.24), Shore._lin(0.53, 0.46, 0.31)]}

# ------------------------------------------------------------------ leaves

## Fallen leaves over the litter, in the dull dark browns of old leaves (the
## kit's colours at full strength read as pale salmon stars on the dark
## floor, so they are dimmed here).
static func _leaves(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, grid: Dictionary, gap_at: Callable) -> int:
	var rows: Array = []
	var since := Kit.frames_now()
	for z: int in range(int(RECT.position.y), int(RECT.end.y)):
		for x: int in range(int(RECT.position.x), int(RECT.end.x)):
			var c := Vector2(x + 0.5, z + 0.5)
			var w := _at(grid, "w", c)
			if w < 0.1 or terrain.water_at(c): continue
			var d := w * (0.18 + 1.1 * _n(c, 2.7, Vector2.ZERO))
			if float(gap_at.call(c)) < 0.4: d *= 0.12
			for k: int in range(_count(rng, d)):
				var p := c + Vector2(rng.randf() - 0.5, rng.randf() - 0.5)
				var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25)) * Basis(Vector3.FORWARD, rng.randf_range(-0.25, 0.25))
				var colour := Kit.leaf_colour(rng, 0.45) * 0.6
				rows.append([Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), Vector3(p.x, terrain.height_at(p) + 0.012 + rng.randf() * 0.01, p.y)), colour])
		await Kit.slice(park)
	await Kit.settle(park, since)
	Kit.cell_batches(root, "CoppiceLeaves", Kit.leaf_mesh(), Kit.leaf_material(), rows, 12.0, 20.0, false)
	return rows.size()

# ---------------------------------------------------------------- thinning

## Lawn blades, tufts and the regular spiky beds give way to the woodland
## floor: almost all go in the core, a few odd clumps stay in light gaps, and
## the share fades with the biome weight so the edge interleaves.
static func _thin(park: Node3D, grid: Dictionary) -> Dictionary:
	var protect: Array[String] = ["fern", "bush", "lilac", "maple", "sakura", "azalea", "iris", "flower", "biome", "coppice", "lantern", "stone", "boulder", "pine", "tree"]
	var words: Array[String] = ["woodlandfill", "fountain", "emerald", "uprightgrass", "forestgrass", "grassdrift", "parkfloor_grass", "grass1", "grassautumn", "grasslawn", "dense_grass", "meshyground", "tuft", "blade", "lawn"]
	var filter := func(label: String) -> bool:
		var l := label.to_lower()
		for word: String in protect: if l.contains(word): return false
		if l.begins_with("shoulder") or l.begins_with("sparseunderstory"): return true
		for word: String in words: if l.contains(word): return true
		return false
	var keep := func(p: Vector2) -> bool:
		if not RECT.has_point(p): return true
		return not Biomes.pick(p, smoothstep(0.25, 0.75, _at(grid, "w", p)) * 0.94, 23)
	if ResourceLoader.exists("res://scripts/biomes/thin_all.gd"):
		return load("res://scripts/biomes/thin_all.gd").hide_low_planting(park, filter, keep, RECT, true)
	return {"fallback": Kit.thin_multimeshes([park], func(n: MultiMeshInstance3D) -> bool: return filter.call(String(n.name) + " " + (n.multimesh.mesh.resource_name if n.multimesh.mesh else "")), keep)}
