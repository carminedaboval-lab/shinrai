extends Node3D
## Night identity for the park and corporate district, matching the street:
## a lit torii and plaza, and neon crowns on the corporate blocks.
## Runs once the street and terrain exist.
const Kit = preload("res://scripts/midori_park_kit.gd")
const Retrofit = preload("res://scripts/midori_street_retrofit.gd")
const Facades = preload("res://scripts/midori_building_facades.gd")
const ROAD_ROOT := "res://assets/environment/roads/shinrai_road/textures/SHINRAI_Road_"
const PAVER_ROOT := "res://assets/shinrai/drain_hgu150/ProjectShinrai_HGU150_Drain_GameReady_SHINRAI_"
const WINDOW_HASH_SEED := 2050
const AD_WORDS := ["新東京","電脳","未来","夜市","機動","龍"]
const TORII_LEFT := Vector2(165.13, 139.94)
const TORII_RIGHT := Vector2(162.87, 132.06)
const TORII_HEIGHT := 6.6

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
	_build_torii_neon()
	if corporate != null: _retrofit_corporate(corporate)
	installed = true
	set_night_mode(park.get("is_night_mode") == true)
	print("MIDORI_NEON_PARK: ", JSON.stringify(report))

func set_night_mode(value: bool) -> void:
	for material: StandardMaterial3D in _windows_lit:
		material.emission_energy_multiplier = .55 if value else 0.0
	if _night_root != null: _night_root.visible = value

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
	var facades := {}
	for node: Node in district.get_children():
		if not node is MeshInstance3D or (node as MeshInstance3D).mesh == null: continue
		var visual := node as MeshInstance3D
		var box: AABB = visual.global_transform * visual.get_aabb()
		if box.size.y > 8.0 and box.size.x * box.size.z > 200.0:
			blocks.append(box)
			if visual.material_override != null: facades[visual.material_override] = true
	report["corporate_blocks"] = blocks.size()
	_surface_corporate(district, facades)
	report["windows_merged"] = _merge_windows(district, blocks)
	report["facade_parts"] = Facades.dress_blocks(neon, neon.get("street"), blocks)
	var colors: Array[Color] = [Color("#22d3ff"), Color("#ff2d78"), Color("#a14dff"), Color("#ffb03a")]
	for i: int in range(blocks.size()):
		_dress_block(blocks[i], colors[i % colors.size()], i)

func _surface_corporate(district: Node3D, facades: Dictionary) -> void:
	# Flat colours become the street's own scanned road and precast maps.
	_texture_slab(district.find_child("NorthSouthRoad", false, false), ROAD_ROOT + "FineAggregate_BaseColor_2K.png", ROAD_ROOT + "RealisticDry_NormalGL_2K.png", Color(.62, .62, .66), .5)
	_texture_slab(district.find_child("NorthSouthSidewalk", false, false), PAVER_ROOT + "PrecastPaver_BaseColor_1K.png", PAVER_ROOT + "PrecastExterior_NormalGL_1K.png", Color(.95, .95, .95), .85)
	var connector := park.get_node_or_null("MidoriCorporateDistrict/CorporateRoadConnection")
	if connector != null:
		for node: Node in connector.get_children():
			if String(node.name).contains("Walk"):
				_texture_slab(node, PAVER_ROOT + "PrecastPaver_BaseColor_1K.png", PAVER_ROOT + "PrecastExterior_NormalGL_1K.png", Color(.95, .95, .95), .85)
			elif String(node.name).contains("Road") or String(node.name).contains("Turn"):
				_texture_slab(node, ROAD_ROOT + "FineAggregate_BaseColor_2K.png", ROAD_ROOT + "RealisticDry_NormalGL_2K.png", Color(.62, .62, .66), .5)
	var grime := Retrofit._grime(Vector3(.82, .82, .85))
	for material: Material in facades:
		material.next_pass = grime
	report["corporate_facades"] = facades.size()

func _texture_slab(node: Node, albedo: String, normal: String, tint: Color, repeats: float) -> void:
	var slab := node as MeshInstance3D
	if slab == null or not slab.material_override is StandardMaterial3D: return
	var material := slab.material_override as StandardMaterial3D
	material.albedo_texture = load(albedo)
	material.albedo_color = tint
	material.normal_enabled = true
	material.normal_texture = load(normal)
	material.normal_scale = .5
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * repeats
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

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
