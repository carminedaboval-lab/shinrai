extends Node3D
## Night identity for the park and corporate district, matching the street:
## LED inlays along the real path curves, a lit torii and plaza, and
## neon crowns on the corporate blocks. Runs once the street and terrain exist.
const Kit = preload("res://scripts/midori_park_kit.gd")
const INLAY_WIDTH := .06
const INLAY_INSET := .42
const WINDOW_HASH_SEED := 2050
const AD_WORDS := ["新東京","電脳","未来","夜市","機動","龍"]
const TORII_LEFT := Vector2(165.13, 139.94)
const TORII_RIGHT := Vector2(162.87, 132.06)
const TORII_HEIGHT := 6.6

const INLAY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
varying vec3 world;
void vertex(){ world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	// Long dashes in metres, drifting slowly from cyan toward magenta across the park.
	if (fract(UV.x / 2.6) < 0.34) discard;
	vec3 tint = mix(vec3(0.0, 0.42, 1.0), vec3(1.0, 0.0, 0.3), smoothstep(-0.2, 0.9, sin(world.x * 0.014 + world.z * 0.011)));
	ALBEDO = tint * 0.22;
}
"""

var installed := false
var report := {}
var park: Node3D
var terrain: Node
var neon: Node3D
var _night_root: Node3D
var _windows_lit: Array[StandardMaterial3D] = []

func _ready() -> void:
	park = get_parent()
	add_to_group("midori_horizon")
	neon = park.get_node_or_null("MidoriNeonStreet")
	terrain = park.get_node_or_null("MidoriTerrain")
	if neon == null or terrain == null: return
	while neon.get("installed") != true or terrain.get("installed") != true:
		await get_tree().process_frame
	var corporate := park.get_node_or_null("MidoriCorporateDistrict")
	while corporate != null and corporate.get("installed") != true:
		await get_tree().process_frame
	_night_root = Node3D.new()
	_night_root.name = "NightOnly"
	add_child(_night_root)
	_night_root.add_to_group("midori_night_effect")
	_build_path_inlays()
	_build_torii_neon()
	if corporate != null: _retrofit_corporate(corporate)
	installed = true
	set_night_mode(park.get("is_night_mode") == true)
	print("MIDORI_NEON_PARK: ", JSON.stringify(report))

func set_night_mode(value: bool) -> void:
	for material: StandardMaterial3D in _windows_lit:
		material.emission_energy_multiplier = .55 if value else 0.0
	if _night_root != null: _night_root.visible = value

func _build_path_inlays() -> void:
	# The park's own edge index already follows every rounded path in world metres.
	var cells: Dictionary = park.get("_path_edge_cells")
	var seen := {}
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := 0
	for bucket: Array in cells.values():
		for segment: Dictionary in bucket:
			var a: Vector2 = segment.a
			var b: Vector2 = segment.b
			var key := Vector4(a.x, a.y, b.x, b.y)
			if seen.has(key): continue
			seen[key] = true
			var length := a.distance_to(b)
			if length < .02: continue
			var side := (b - a).rotated(PI * .5) / length
			var start_u := a.x + a.y
			for edge: float in [-1.0, 1.0]:
				quads += _inlay_quad(st, a, b, side * edge, float(segment.wa) * .5 - INLAY_INSET, float(segment.wb) * .5 - INLAY_INSET, start_u, length)
	if quads == 0: return
	var mesh := st.commit()
	var shader := Shader.new()
	shader.code = INLAY_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	var inlays := MeshInstance3D.new()
	inlays.name = "PathLedInlays"
	inlays.mesh = mesh
	inlays.material_override = material
	inlays.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_night_root.add_child(inlays)
	report["inlay_quads"] = quads

func _inlay_quad(st: SurfaceTool, a: Vector2, b: Vector2, side: Vector2, offset_a: float, offset_b: float, u: float, length: float) -> int:
	var inner_a := a + side * offset_a
	var inner_b := b + side * offset_b
	if terrain.water_at(inner_a) or terrain.water_at(inner_b): return 0
	var outer_a := inner_a + side * INLAY_WIDTH
	var outer_b := inner_b + side * INLAY_WIDTH
	var ya := _walk_y(inner_a)
	var yb := _walk_y(inner_b)
	var corners: Array[Vector3] = [Vector3(inner_a.x, ya, inner_a.y), Vector3(outer_a.x, ya, outer_a.y), Vector3(inner_b.x, yb, inner_b.y), Vector3(outer_b.x, yb, outer_b.y)]
	var us: Array[float] = [u, u, u + length, u + length]
	for index: int in [0, 1, 2, 2, 1, 3]:
		st.set_uv(Vector2(us[index], 0.0))
		st.add_vertex(corners[index])
	return 1

func _walk_y(p: Vector2) -> float:
	# Walks are draped, so read the real surface rather than the terrain grid.
	var from := Vector3(p.x, float(terrain.height_at(p)) + 1.0, p.y)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.0)
	var hit := park.get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) + .028 if hit.has("position") else from.y - .87

func _strip(label: String, size: Vector3, at: Vector3, yaw: float, color: Color) -> void:
	var material := Kit.glow(color)
	material.emission_energy_multiplier = 3.4
	Kit.box(_night_root, label, size, at, material, Vector3(0, yaw, 0))

func _omni(label: String, at: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.name = label
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.light_specular = 1.2
	light.omni_range = reach
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 120.0
	light.distance_fade_length = 30.0
	_night_root.add_child(light)

func _build_torii_neon() -> void:
	var along := (TORII_LEFT - TORII_RIGHT).normalized()
	var normal := along.rotated(PI * .5)
	var yaw := atan2(-along.y, along.x)
	var centre := (TORII_LEFT + TORII_RIGHT) * .5
	var pink := Color("#ff2d78")
	var cyan := Color("#22d3ff")
	for face: float in [-1.0, 1.0]:
		var offset := normal * face * .52
		for pillar: Vector2 in [TORII_LEFT, TORII_RIGHT]:
			var p := pillar + offset
			_strip("ToriiPillarNeon", Vector3(.07, TORII_HEIGHT - .7, .07), Vector3(p.x, TORII_HEIGHT * .5 - .05, p.y), yaw, pink)
		var beam := centre + offset
		_strip("ToriiBeamNeon", Vector3(11.0, .08, .08), Vector3(beam.x, TORII_HEIGHT + .3, beam.y), yaw, pink)
		_strip("ToriiTieNeon", Vector3(8.6, .05, .05), Vector3(beam.x, TORII_HEIGHT - .9, beam.y), yaw, cyan)
	for face: float in [-1.0, 1.0]:
		var wash := centre + normal * face * 3.4
		_omni("ToriiWash", Vector3(wash.x, 3.0, wash.y), pink, 3.0, 17.0)
	_omni("PlazaCoolWest", Vector3(146.0, 7.0, 152.0), cyan, 2.4, 30.0)
	_omni("PlazaCoolEast", Vector3(182.0, 7.0, 120.0), Color("#7a5cff"), 2.4, 30.0)

func _retrofit_corporate(corporate: Node) -> void:
	var district := corporate.find_child("CorporateDistrict", true, false) as Node3D
	if district == null: return
	var blocks: Array[AABB] = []
	for node: Node in district.get_children():
		if not node is MeshInstance3D or (node as MeshInstance3D).mesh == null: continue
		var visual := node as MeshInstance3D
		var box: AABB = visual.global_transform * visual.get_aabb()
		if box.size.y > 8.0 and box.size.x * box.size.z > 200.0: blocks.append(box)
	report["corporate_blocks"] = blocks.size()
	report["windows_merged"] = _merge_windows(district, blocks)
	var colors: Array[Color] = [Color("#22d3ff"), Color("#ff2d78"), Color("#a14dff"), Color("#ffb03a")]
	for i: int in range(blocks.size()):
		_dress_block(blocks[i], colors[i % colors.size()], i)

func _merge_windows(district: Node3D, blocks: Array[AABB]) -> int:
	# Thousands of single-box panes become three meshes, with varied night light.
	var dark := Kit.mat(Color("#0d141c"), .18, .6)
	var warm := Kit.mat(Color("#2b2620"), .3, .1)
	warm.emission_enabled = true
	warm.emission = Color("#ffc687")
	var cool := Kit.mat(Color("#1d2a30"), .3, .1)
	cool.emission_enabled = true
	cool.emission = Color("#8fdcff")
	_windows_lit.assign([warm, cool])
	var tools: Array[SurfaceTool] = []
	for material: Material in [dark, warm, cool]:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(material)
		tools.append(tool)
	var sources: Array[MeshInstance3D] = []
	var inverse := district.global_transform.affine_inverse()
	for node: Node in district.get_children():
		if not node is MeshInstance3D or (node as MeshInstance3D).mesh == null or node.get_child_count() > 0: continue
		var visual := node as MeshInstance3D
		var box: AABB = visual.global_transform * visual.get_aabb()
		var sizes := [box.size.x, box.size.y, box.size.z]
		sizes.sort()
		if sizes[0] > .3 or sizes[1] < .7 or sizes[2] > 5.0 or box.position.y < 2.0: continue
		var inside := false
		for block: AABB in blocks:
			if block.grow(.6).encloses(box): inside = true
		if not inside: continue
		var pick := hash(Vector3i(box.position * 2.0) + Vector3i(WINDOW_HASH_SEED, 0, 0)) % 100
		var slot := 0 if pick < 52 else (1 if pick < 84 else 2)
		for surface: int in range(visual.mesh.get_surface_count()):
			tools[slot].append_from(visual.mesh, surface, inverse * visual.global_transform)
		sources.append(visual)
	if sources.is_empty(): return 0
	var combined := ArrayMesh.new()
	for tool: SurfaceTool in tools:
		tool.commit(combined)
	var merged := MeshInstance3D.new()
	merged.name = "MergedWindows"
	merged.mesh = combined
	merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	district.add_child(merged)
	for source: MeshInstance3D in sources:
		source.get_parent().remove_child(source)
		source.queue_free()
	return sources.size()

func _dress_block(box: AABB, color: Color, index: int) -> void:
	var low := box.position
	var high := box.end
	var y := high.y + .06
	var mid := box.get_center()
	# Crown ring just proud of the parapet, and two corner risers.
	_strip("CrownNorth", Vector3(box.size.x, .1, .1), Vector3(mid.x, y, low.z - .05), 0.0, color)
	_strip("CrownSouth", Vector3(box.size.x, .1, .1), Vector3(mid.x, y, high.z + .05), 0.0, color)
	_strip("CrownWest", Vector3(.1, .1, box.size.z), Vector3(low.x - .05, y, mid.z), 0.0, color)
	_strip("CrownEast", Vector3(.1, .1, box.size.z), Vector3(high.x + .05, y, mid.z), 0.0, color)
	_strip("Riser", Vector3(.1, box.size.y, .1), Vector3(low.x - .05, mid.y, low.z - .05), 0.0, color)
	_strip("Riser", Vector3(.1, box.size.y, .1), Vector3(high.x + .05, mid.y, low.z - .05), 0.0, color)
	if index % 2 == 0:
		# Advert wall on the park-facing side.
		var size := Vector2(box.size.x * .62, minf(box.size.y * .42, 8.0))
		var tint := color.lerp(Color.WHITE, .1)
		neon._wall_screen(self, Vector3(mid.x, high.y - size.y * .5 - 1.4, low.z - .5), PI, size, tint, tint.lerp(Color("#3a7bff"), .7), AD_WORDS[(index / 2) % AD_WORDS.size()])
