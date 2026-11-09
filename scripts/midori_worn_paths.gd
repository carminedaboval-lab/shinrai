extends RefCounted
## Paints the park's side walks and woodland trails into the ground itself,
## the way open-world terrain does: a fine path map tells the shared ground
## shader where feet have worn the turf away, and it swaps its own grass scan
## for its own soil scan there, with a ragged, tufted edge. Same textures, same
## lighting, no separate strip, so the walk reads as part of the ground.
## The old walk and trail meshes stay for collision and for the systems that
## read their shapes, but no camera draws them.
const Budget := preload("res://scripts/shinrai_loading_budget.gd")
const RES := 4.0 # path map pixels per metre
const ORIGIN := Vector2(-220.0, -180.0)
const SIZE := Vector2(440.0, 360.0)
const RANGE := 1.5 # metres inside / outside an edge the map encodes

const UNIFORMS := """
uniform sampler2D worn_tex : repeat_disable, filter_linear;
uniform bool worn_ready = false;
"""

const FRAGMENT := """
	if (worn_ready) {
		vec2 worn_uv = (world_pos.xz + vec2(220.0, 180.0)) / vec2(440.0, 360.0);
		// Metres inside the worn edge (negative outside).
		float inside = texture(worn_tex, worn_uv).r * 3.0 - 1.5;
		float n_broad = midori_floor_noise(world_pos.xz * 0.9 + vec2(3.1, 8.7));
		float n_mid = midori_floor_noise(world_pos.xz * 2.9 + vec2(9.2, 1.3));
		float n_fine = midori_floor_noise(world_pos.xz * 8.5 + vec2(1.7, 5.9));
		float edge = inside + (n_broad - 0.5) * 0.8 + (n_mid - 0.5) * 0.35 + (n_fine - 0.5) * 0.12;
		float worn = smoothstep(-0.1, 0.45, edge);
		// Grass tufts hold on near the rim and now and then mid-walk.
		float tuft = smoothstep(0.6, 0.78, n_mid) * (1.0 - smoothstep(0.2, 0.9, edge));
		tuft = max(tuft, smoothstep(0.86, 0.95, n_fine) * smoothstep(0.75, 0.95, n_broad) * 0.8);
		worn *= 1.0 - tuft;
		if (worn > 0.001) {
			// Two reads of the soil scan at different angles and scales, blended by
			// broad noise, so its repeat never lines up along a walk.
			mat2 worn_rot = mat2(vec2(0.719, 0.695), vec2(-0.695, 0.719));
			vec2 wa = ground_uv * 1.3 + vec2(0.71, 0.23);
			vec2 wb = worn_rot * ground_uv * 0.83 + vec2(2.37, 0.91);
			float wmix = smoothstep(0.3, 0.7, midori_floor_noise(world_pos.xz * 0.27 + vec2(6.1, 3.3)));
			vec3 dirt_scan = mix(textureGrad(soil_albedo_tex, wa, ground_uv_dx * 1.3, ground_uv_dy * 1.3).rgb, textureGrad(soil_albedo_tex, wb, ground_uv_dx * 0.83, ground_uv_dy * 0.83).rgb, wmix);
			vec3 dirt_n = mix(textureGrad(soil_normal_tex, wa, ground_uv_dx * 1.3, ground_uv_dy * 1.3).rgb, textureGrad(soil_normal_tex, wb, ground_uv_dx * 0.83, ground_uv_dy * 0.83).rgb, wmix);
			float dirt_r = mix(textureGrad(soil_roughness_tex, wa, ground_uv_dx * 1.3, ground_uv_dy * 1.3).r, textureGrad(soil_roughness_tex, wb, ground_uv_dx * 0.83, ground_uv_dy * 0.83).r, wmix);
			if (!independent_layers_ready) { dirt_scan = earth * 1.4; dirt_n = source_normal; dirt_r = source_roughness; }
			// Trodden centre is packed, drier and paler; the rim is loose, darker soil.
			float trodden = smoothstep(0.35, 1.2, edge);
			// Dusty grey-brown: the scan's detail with most of its red taken out.
			float dirt_luma = dot(dirt_scan, vec3(0.299, 0.587, 0.114));
			float worn_tone = midori_floor_noise(world_pos.xz * 0.11 + vec2(1.9, 7.4)) * 0.6 + midori_floor_noise(world_pos.xz * 0.53 + vec2(4.4, 0.6)) * 0.4;
			vec3 dirt = mix(vec3(dirt_luma), dirt_scan, 0.45) * vec3(1.08, 1.0, 0.86) * mix(0.8, 1.14, worn_tone);
			dirt = mix(dirt * vec3(0.7, 0.67, 0.6), dirt * vec3(1.32, 1.27, 1.18), trodden);
			// A little of the ground's own litter stays visible in the dirt.
			dirt = mix(dirt, ALBEDO / max(scene_light_factor, 0.01), 0.18 * (1.0 - trodden));
			// Damp hollows where water sits after rain.
			float hollow = smoothstep(0.62, 0.82, midori_floor_noise(world_pos.xz * 0.35 + vec2(5.5, 2.2))) * trodden;
			dirt = mix(dirt, dirt * vec3(0.6, 0.58, 0.55), hollow * 0.7);
			ALBEDO = mix(ALBEDO, dirt * scene_light_factor, worn);
			NORMAL_MAP = mix(NORMAL_MAP, dirt_n, worn);
			NORMAL_MAP_DEPTH = mix(NORMAL_MAP_DEPTH, 0.6, worn);
			ROUGHNESS = mix(ROUGHNESS, mix(clamp(dirt_r, 0.82, 1.0), 0.55, hollow * 0.6), worn);
		}
	}
"""

## With a raid, the world-complete step (scripts/shinrai_world_complete.gd)
## calls install_now() before HQ; this legacy entry only runs for a raid that
## left BOOT without that step, or with no raid at all.
static func install(park: Node3D) -> void:
	var tree := park.get_tree()
	var raid := park.get_node_or_null("ExtractionRun")
	while is_instance_valid(raid) and raid.phase == raid.Phase.BOOT:
		if is_instance_valid(park) and park.get_meta(&"shinrai_world_complete_started", false): return
		await tree.process_frame
	if not is_instance_valid(park): return
	await install_now(park)

## Paints the map and injects it, once per park, on the shared loading budget.
static func install_now(park: Node3D) -> Dictionary:
	if not is_instance_valid(park): return {}
	if park.has_meta("worn_paths"): return park.get_meta("worn_paths")
	if park.get_meta(&"worn_paths_running", false):
		while is_instance_valid(park) and not park.has_meta("worn_paths"): await park.get_tree().process_frame
		return park.get_meta("worn_paths", {}) if is_instance_valid(park) else {}
	park.set_meta(&"worn_paths_running", true)
	await _paint(park)
	return park.get_meta("worn_paths", {}) if is_instance_valid(park) else {}

static func _paint(park: Node3D) -> void:
	var terrain := park.get_node_or_null("MidoriTerrain")
	var material: ShaderMaterial = null
	if terrain != null:
		for child: Node in terrain.get_children():
			if child is MeshInstance3D and child.material_override is ShaderMaterial:
				material = child.material_override
				break
	if material == null or not material.shader.code.contains("float inside") and not material.shader.code.contains("uniform sampler2D soil_albedo_tex"):
		_drop_prepaint()
		park.set_meta("worn_paths", {"error":"ground shader unavailable"})
		return
	var gathered := _gather(park)
	var lines: Array = gathered.lines
	var walks: Array[GeometryInstance3D] = gathered.walks
	# Painted ahead on a worker (prepaint) from equal lines: the same map.
	var map: Image = await _take_prepaint(park, lines)
	if not is_instance_valid(park): return
	if map == null:
		map = Image.create(int(SIZE.x * RES), int(SIZE.y * RES), false, Image.FORMAT_L8)
		map.fill(Color(0, 0, 0))
		for line: Array in lines:
			var centres: PackedVector3Array = line[0]
			for i: int in range(centres.size() - 1):
				_paint_segment(map, line, i)
				# Time-based: the map is the same however the segments split across frames.
				await Budget.checkpoint(park, true)
				if not is_instance_valid(park): return
	_inject(park, material, map, lines, walks)

## Path centre lines and half-widths in world metres ({lines, walks}): read from
## the path layout's metas and the desire-path routes (both final once the
## desire paths have finished), plus the walk and trail meshes to hide.
static func _gather(park: Node3D) -> Dictionary:
	var lines: Array = []
	var walks: Array[GeometryInstance3D] = []
	var layout := park.get_node_or_null("MidoriPark_440x360m_ProceduralLayout/FinalDestinationLedPathHierarchy")
	if layout != null:
		for walk: Node in layout.get_children():
			if not walk is MeshInstance3D or not walk.has_meta("midori_path_centres_world"): continue
			var centres: PackedVector3Array = walk.get_meta("midori_path_centres_world")
			var widths: PackedFloat32Array = walk.get_meta("midori_path_widths_world")
			if str(walk.get_meta("midori_path_role", "")) == "secondary":
				lines.append([centres, widths, 1.0])
				walks.append(walk)
			else:
				# Paved walks stay; the ground beside them is trampled into a
				# ragged worn shoulder up to about half a metre out.
				var shoulder := PackedFloat32Array()
				for w: float in widths: shoulder.append(w + 1.0)
				lines.append([centres, shoulder, 1.0])
	var trails := park.get_node_or_null("VisibleWoodlandTrails")
	var desire := park.get_node_or_null("MidoriDesirePaths")
	if trails != null and desire != null:
		for route: Dictionary in desire.get("routes"):
			# The route comes off a pathfinding grid; smooth it as the trail mesh does.
			var shaper = load("res://scripts/midori_trail_surface.gd").new()
			var flat: PackedVector2Array = shaper._simplify(route.points, 0.9)
			for pass_index: int in range(3): flat = shaper._chaikin(flat)
			var centres := PackedVector3Array()
			var widths := PackedFloat32Array()
			for p: Vector2 in flat:
				centres.append(Vector3(p.x, 0, p.y))
				widths.append(1.7)
			lines.append([centres, widths, 0.8])
		for trail: Node in trails.get_children():
			if trail is GeometryInstance3D: walks.append(trail)
	return {"lines": lines, "walks": walks}

## One centre-line segment `i` of `line` into the map (the brush the map has
## always used; segments in order give the same pixels on any thread).
static func _paint_segment(map: Image, line: Array, i: int) -> void:
	var centres: PackedVector3Array = line[0]
	var widths: PackedFloat32Array = line[1]
	var a := Vector2(centres[i].x, centres[i].z)
	var b := Vector2(centres[i + 1].x, centres[i + 1].z)
	var half := maxf(widths[i], widths[i + 1]) * 0.5 * float(line[2])
	var low := (a.min(b) - Vector2.ONE * (half + RANGE) - ORIGIN) * RES
	var high := (a.max(b) + Vector2.ONE * (half + RANGE) - ORIGIN) * RES
	for y: int in range(maxi(0, floori(low.y)), mini(map.get_height(), ceili(high.y))):
		for x: int in range(maxi(0, floori(low.x)), mini(map.get_width(), ceili(high.x))):
			var p := Vector2(x + 0.5, y + 0.5) / RES + ORIGIN
			var closest := Geometry2D.get_closest_point_to_segment(p, a, b)
			var t := clampf(a.distance_to(closest) / maxf(0.001, a.distance_to(b)), 0.0, 1.0)
			var h := lerpf(widths[i], widths[i + 1], t) * 0.5 * float(line[2])
			var inside := clampf(h - p.distance_to(closest), -RANGE, RANGE)
			var value := (inside + RANGE) / (RANGE * 2.0)
			if value > map.get_pixel(x, y).r: map.set_pixel(x, y, Color(value, value, value))

## The whole map from `lines`, segments in order (worker side of prepaint).
static func _paint_map(lines: Array) -> Image:
	var map := Image.create(int(SIZE.x * RES), int(SIZE.y * RES), false, Image.FORMAT_L8)
	map.fill(Color(0, 0, 0))
	for line: Array in lines:
		var centres: PackedVector3Array = line[0]
		for i: int in range(centres.size() - 1): _paint_segment(map, line, i)
	return map

# ------------------------------------------------------------ early paint
## The map reads only the lines above. The raid calls prepaint() once the desire
## paths have finished (about 25 s before the world-complete step): the lines
## are gathered then and one WorkerThreadPool task paints the map from a copy.
## _paint() gathers the lines again and takes that map only when they are equal;
## otherwise it paints as before. The shader injection and the hidden strips
## stay where they always were.
static var _pre: Dictionary = {}

static func prepaint(park: Node3D) -> void:
	# The raid wakes here in a busy frame (several producers wait for the desire
	# paths): take a budget turn first. The caller does not wait for this.
	await Budget.checkpoint(park, true)
	if not is_instance_valid(park) or park.has_meta("worn_paths") or park.get_meta(&"worn_paths_running", false): return
	_drop_prepaint()
	var lines: Array = _gather(park).lines
	var copy: Array = lines.duplicate(true)
	var out := {}
	var job := func() -> void: out["map"] = _paint_map(copy)
	_pre = {"park": park.get_instance_id(), "lines": lines, "out": out, "task": WorkerThreadPool.add_task(job, false, "midori_worn_paths prepaint")}

## The prepainted map when it was painted for this park from equal lines
## (waits for the task on frames, never blocking the main thread), else null.
static func _take_prepaint(park: Node3D, lines: Array) -> Image:
	if _pre.is_empty(): return null
	var pre := _pre
	var same: bool = int(pre.park) == park.get_instance_id() and pre.lines == lines
	if same:
		while not WorkerThreadPool.is_task_completed(int(pre.task)):
			await park.get_tree().process_frame
			if not is_instance_valid(park): break
	_drop_prepaint()
	var map: Image = (pre.out as Dictionary).get("map", null)
	if preload("res://scripts/startup_trace.gd").enabled: print("MIDORI_WORN_PATHS_PREPAINT ", "hit" if same and map != null else "stale, painting again")
	return map if same and is_instance_valid(park) else null

static func _drop_prepaint() -> void:
	if _pre.has("task"): WorkerThreadPool.wait_for_task_completion(int(_pre.task))
	_pre = {}

static func _inject(park: Node3D, material: ShaderMaterial, map: Image, lines: Array, walks: Array[GeometryInstance3D]) -> void:
	# Inject once into the shared ground shader, keeping every parameter.
	if not material.shader.code.contains("uniform bool worn_ready"):
		var parameters := {}
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			parameters[uniform.name] = material.get_shader_parameter(uniform.name)
		var code: String = material.shader.code
		code = code.replace("varying vec3 world_pos;", UNIFORMS + "varying vec3 world_pos;")
		code = code.insert(code.rfind("}"), FRAGMENT)
		var shader := Shader.new()
		shader.code = code
		material.shader = shader
		for key: String in parameters: material.set_shader_parameter(key, parameters[key])
	material.set_shader_parameter("worn_tex", ImageTexture.create_from_image(map))
	material.set_shader_parameter("worn_ready", true)
	for walk: GeometryInstance3D in walks:
		walk.layers = 0
		walk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	park.set_meta("worn_paths", {"lines":lines.size(), "hidden_strips":walks.size(), "map":map.get_size()})
	print("MIDORI_WORN_PATHS ", JSON.stringify(park.get_meta("worn_paths")))
