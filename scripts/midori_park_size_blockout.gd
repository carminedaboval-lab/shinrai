extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")
const StartupTrace = preload("res://scripts/startup_trace.gd")

const WoodlandLayout = preload("res://scripts/midori_woodland_layout.gd")

const TreeBranchContactPlacement = preload("res://scripts/midori_tree_branch_contacts.gd")

const FoliageMaterials = preload("res://scripts/midori_foliage_materials.gd")
const WalkMaterials = preload("res://scripts/midori_walk_materials.gd")
const CourtMaterials = preload("res://scripts/midori_court_materials.gd")
const BridgeWalks = preload("res://scripts/midori_bridge_walks.gd")
const BridgeLandings = preload("res://scripts/midori_bridge_landings.gd")
const MeasuredBridges = preload("res://scripts/midori_measured_bridges.gd")
const MeasuredBridgeDisplay = preload("res://scripts/midori_bridge_display.gd")
const MeasuredBridgeArtwork = preload("res://assets/shinrai/parks/midori_park/models/structures/measured/bridge_artwork_v4.res")

var _bridge_walk_surfaces: Array[Dictionary] = []
var _bridge_join_walks: Array[Dictionary] = []

const LakeGeometry = preload("res://scripts/midori_lake_geometry.gd")

@export var start_at_night := true
@export var time_of_day_toggle_key: Key = KEY_N

const PlayerScript = preload("res://scripts/player.gd")
const SakuraTreeScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_sakura_winter_sentinel_clean_v2.glb")
const FountainGrassScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_green_fountain_grass_v1.glb")
const MeadowGrassScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_swaying_meadow_grass_v1.glb")
const MossyBoulderScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_mossy_boulder_cluster_v1.glb")
const ViewingDeckScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/structures/midori_lakeside_viewing_deck_v1.glb")
const NeonToriiPortalScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/structures/vendor/neon_torii_portal/neon_torii_portal.glb")
const BroadleafTreePack: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/realistic_trees_collection/scene.glb")
const PineTreePack: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/pine_trees_pack/scene.glb")
const LilacBushPack: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/lilac_bush_pack/scene.glb")
const DenseGrassPack: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/cosmic_dust_grass/grass_1k.glb")
const DeadwoodTrunkScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/mistrzjang1_tree_trunk/tree_trunk_002.fbx")
const HollowBarkScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/michaeldebbarma_hollow_bark/hollow_bark.fbx")
const MidnightFernScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/midnight_fern/midnight_fern.glb")
const EmeraldFountainGrassScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/emerald_fountain_grass/emerald_fountain_grass.glb")
const JapaneseMapleMesh: Mesh = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/free3d_japanese_maple_n030123/midori_japanese_maple_complete.res")
const NeonParkBenchScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/furniture/vendor/neon_park_bench/neon_park_bench.glb")
const FuturisticEcoBenchScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/furniture/vendor/futuristic_eco_bench/futuristic_eco_bench.glb")
const EmeraldHaloLampScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/furniture/vendor/emerald_halo_lamp/emerald_halo_lamp.glb")
const MidoriPathStraightScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/paths/vendor/meshy_midori_path_kit/midori_path_straight.glb")
const MidoriPathCurveScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/paths/vendor/meshy_midori_path_kit/midori_path_curve.glb")
const MidoriPathJunctionScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/paths/vendor/meshy_midori_path_kit/midori_path_junction.glb")
const MidoriPathRestingPocketScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/paths/vendor/meshy_midori_path_kit/midori_path_resting_pocket.glb")
const FiveASidePitchScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/activity/meshy_five_a_side_pitch_clean.glb")
const PitchRemasterScript = preload("res://scripts/midori_pitch_remaster.gd")
const PitchFenceScript = preload("res://scripts/midori_pitch_fence.gd")

const LAYOUT_SCALE := 2.0
const LAYOUT_REFERENCE_SIZE_M := Vector2(220.0, 180.0)
const PARK_SIZE_M := LAYOUT_REFERENCE_SIZE_M * LAYOUT_SCALE
const PARK_HALF := Vector2(LAYOUT_REFERENCE_SIZE_M.x * 0.5, LAYOUT_REFERENCE_SIZE_M.y * 0.5)
const WORLD_PARK_HALF := Vector2(PARK_SIZE_M.x * 0.5, PARK_SIZE_M.y * 0.5)
const LAKE_SIZE_M := Vector2(128.0, 234.0)
const SHOW_PLANNING_LABELS := false
# The layout root doubles authored X/Z positions in world space. These trunk
# clearances leave more daylight between crowns while keeping clumped groves.
const MATURE_TREE_MIN_SPACING_M := 2.0
const SKINNY_TREE_MIN_SPACING_M := 1.5
const SKINNY_TO_SKINNY_MIN_SPACING_M := 1.0
const SHRUB_PATH_CLEARANCE_M := 0.65
const SAKURA_TREE_COUNT := 36
const LAKE_TREE_BUFFER_M := 2.0
const LAKE_PROMENADE_WIDTH_M := 3.6
const LAKE_PROMENADE_BANK_MARGIN_M := 1.0
const PLAZA_CENTER := Vector2(82.0, 68.0)
const PLAZA_CENTERPIECE_CLEARANCE_M := 3.5
const TORII_TARGET_HEIGHT_M := 7.0
const TORII_SOURCE_HEIGHT_M := 0.691406
const TORII_YAW_DEGREES := 106.0

# Final circulation follows the destination-led, nested-loop logic of the
# Pymmes Park reference. The routes intentionally avoid a rectangular grid:
# entrances feed soft three-way merges, short loops offer alternate woodland
# approaches, and the lake promenades remain the park's central circulation.
const OUTER_CIRCUIT: Array[Vector2] = [
	Vector2(-98,70),Vector2(-72,77),Vector2(-38,82),Vector2(0,84),
	Vector2(38,85),Vector2(70,85),Vector2(98,84),Vector2(105,70),
	Vector2(106,48),Vector2(105,25),Vector2(104,0),Vector2(103,-25),
	Vector2(101,-50),Vector2(98,-68),Vector2(91,-82),Vector2(62,-85),
	Vector2(25,-84),Vector2(-18,-82),Vector2(-55,-80),Vector2(-83,-76),
	Vector2(-103,-66),Vector2(-106,-42),Vector2(-106,-10),Vector2(-105,22),
	Vector2(-103,49),Vector2(-98,70),
]
const SOUTH_ARRIVAL_ROUTE: Array[Vector2] = [
	Vector2(0,90),Vector2(-4,80),Vector2(-12,68),Vector2(-18,54),
	Vector2(-22,42),Vector2(-10,34),Vector2(8,30),Vector2(18,29),
]
const WEST_DESTINATION_ROUTE: Array[Vector2] = [
	Vector2(-110,20),Vector2(-98,18),Vector2(-84,12),Vector2(-68,4),
	Vector2(-52,-2),Vector2(-36,-8),Vector2(-18,-10),Vector2(-2,-10),
	Vector2(9.5,-10.5),
]
const NORTH_ENTRY_ROUTE: Array[Vector2] = [
	Vector2(-38,-90),Vector2(-24,-82),Vector2(-8,-74),Vector2(12,-70),
	Vector2(30,-68),Vector2(47,-68.5),
]
const EAST_DECK_ROUTE: Array[Vector2] = [
	Vector2(110,-20),Vector2(98,-16),Vector2(88,-10),Vector2(82,-4),
	Vector2(80.5,-1),
]
const SPORTS_LINK_ROUTE: Array[Vector2] = [
	Vector2(-105,-20),Vector2(-92,-22),Vector2(-76,-24),Vector2(-58,-19.5),
	Vector2(-40,-28),Vector2(-22,-28),Vector2(15,-27),
]
const PLAYGROUND_LOOP: Array[Vector2] = [
	Vector2(-97,20),Vector2(-96,29),Vector2(-97,46),Vector2(-94,60),
	Vector2(-84,66),Vector2(-69,67),Vector2(-53,65),Vector2(-40,54),
	Vector2(-28,44),Vector2(-12,36),Vector2(13,28),Vector2(18,20),
	Vector2(10,21),Vector2(-5,25),Vector2(-18,28),Vector2(-34,34),
	Vector2(-50,30),Vector2(-66,28),Vector2(-82,26),Vector2(-92,24),
	Vector2(-97,20),
]
const NORTH_WOODLAND_LOOP: Array[Vector2] = [
	Vector2(15,-27),Vector2(8,-38),Vector2(4,-50),Vector2(2,-63),
	Vector2(10,-75),Vector2(20,-80),Vector2(28,-79),Vector2(30,-73),
	Vector2(20,-70),Vector2(12,-60),Vector2(10,-45),Vector2(5.666667,-45),
]
const LAKE_PROMENADE_LOOP: Array[Vector2] = [
	Vector2(48,-75),Vector2(38,-73),Vector2(29,-68),Vector2(23,-60),
	Vector2(20,-51),Vector2(17,-42),Vector2(13,-33),Vector2(10,-22),
	Vector2(8,-9),Vector2(9,5),Vector2(13,18),Vector2(19,30),
	Vector2(27,43),Vector2(38,52),Vector2(50,56),Vector2(62,54),
	Vector2(72,48),Vector2(78,37),Vector2(80,25),Vector2(84,14),
	Vector2(86,1),Vector2(83,-12),Vector2(85,-24),Vector2(83,-37),
	Vector2(79,-48),Vector2(79,-57),Vector2(73,-67),Vector2(62,-73),
	Vector2(48,-75),
]
const PLAZA_ARRIVAL_ROUTE: Array[Vector2] = [
	Vector2(0,90),Vector2(18,86),Vector2(40,82),Vector2(58,78),
	Vector2(70,74),Vector2(76,72),Vector2(82,74),Vector2(88,72),
	Vector2(91,66),Vector2(92,60),
]
const PLAZA_PAVED_ROUTE: Array[Vector2] = [
	Vector2(-1,81),Vector2(12,80),Vector2(40,82),Vector2(58,78),
	Vector2(70,74),Vector2(76,72),Vector2(82,74),Vector2(88,72),
	Vector2(91,66),Vector2(92,60),
]
const SOUTH_BRIDGE_APPROACH: Array[Vector2] = [
	Vector2(76,72),Vector2(68,64),Vector2(58,54),Vector2(52,50),
	Vector2(48,49.5),
]
const PAVILION_LINK_ROUTE: Array[Vector2] = [
	Vector2(73,-69),Vector2(80,-74),Vector2(88,-75),Vector2(98,-68),
]
const VIEWING_DECK_APPROACH_ROUTE: Array[Vector2] = [
	Vector2(80.5,-1),Vector2(83,-6),Vector2(81,-13),
]
const LAKE_SHORELINE: Array[Vector2] = LakeGeometry.ANCHORS
const VegetationClearanceCache = preload("res://scripts/vegetation_clearance_cache.gd")
var _vegetation_clearance_cache: RefCounted
const _VEGETATION_RESERVED_RECTS: Array[Vector4] = [
	# Keep the actual five-a-side enclosure and a playable apron clear.
	Vector4(-70,-43,14.0,10.5),Vector4(-72,45,20.0,17.0),
	Vector4(82,68,19.0,15.0),Vector4(76,-73,14.0,11.0),
	Vector4(0,86,11.0,7.0),Vector4(-38,-86,9.0,7.0),
	Vector4(-106,20,7.0,9.0),Vector4(106,-20,7.0,9.0),
]
var lake_contour: Array[Vector2] = LakeGeometry.contour()
const FUTURE_BRIDGE_WEST: Array[Vector2] = [
	Vector2(12,-19),Vector2(31,-19),Vector2(55,-19),Vector2(83,-19),
]
const FUTURE_BRIDGE_NORTH_EAST: Array[Vector2] = [
	Vector2(31,-57),Vector2(42,-57),Vector2(59,-57),Vector2(73,-57),
]
const FUTURE_BRIDGE_SOUTH: Array[Vector2] = [
	Vector2(22,24),Vector2(39,24),Vector2(60,24),Vector2(79,24),
]

var mat_grass: StandardMaterial3D
var mat_path: StandardMaterial3D
var mat_paved_surface: ShaderMaterial
var mat_lake_paved_surface: ShaderMaterial
var mat_water: ShaderMaterial
var mat_playground: StandardMaterial3D
var mat_plaza: ShaderMaterial
var mat_plaza_border: ShaderMaterial
var mat_plaza_inlay: StandardMaterial3D
var mat_pavilion: StandardMaterial3D
var mat_boundary: StandardMaterial3D
var mat_entry: StandardMaterial3D
var mat_island: ShaderMaterial
var mat_shore_bank: ShaderMaterial
var mat_island_bank: ShaderMaterial
var mat_shore_promenade: StandardMaterial3D
var mat_shore_landing: StandardMaterial3D
var mat_plan_marker: StandardMaterial3D
var mat_path_light_streak: ShaderMaterial
var modular_path_shader: Shader
var lamp_emissive_materials: Array[StandardMaterial3D] = []
var plaza_emissive_materials: Array[StandardMaterial3D] = []
var modular_path_emissive_materials: Array[ShaderMaterial] = []
var broadleaf_prototypes: Array[Node3D] = []
var pine_prototypes: Array[Node3D] = []
var pine_sapling_prototypes: Array[Node3D] = []
var forest_floor_bush_prototypes: Array[Node3D] = []
var lilac_prototypes: Array[Node3D] = []
var dense_grass_prototypes: Array[Node3D] = []
var deadwood_trunk_prototype: Node3D
var hollow_bark_prototype: Node3D
var midnight_fern_prototype: Node3D
var emerald_fountain_grass_prototype: Node3D
var japanese_maple_prototype: Node3D
var neon_park_bench_prototype: Node3D
var futuristic_eco_bench_prototype: Node3D
var emerald_halo_lamp_prototype: Node3D
var midori_path_straight_prototype: Node3D
var midori_path_curve_prototype: Node3D
var midori_path_junction_prototype: Node3D
var midori_path_resting_pocket_prototype: Node3D
var park_environment: Environment
var park_directional_light: DirectionalLight3D
var time_of_day_label: Label
var is_night_mode := true
var high_render_quality := false
var lake_reflection_probe: ReflectionProbe
var reflection_refresh_queued := false
const TREE_COVER_CLEARINGS: Array[Vector2] = [
	Vector2(-49,-8.928204),Vector2(-42,13),Vector2(-5,5),
	Vector2(-43,74),Vector2(-8,63.3923),Vector2(26,50.6077),
	Vector2(79.0718,10),Vector2(-55,-62),Vector2(58.5359,63),
]
var _occupied_tree_crowns: Dictionary = {}
var _tree_crown_radius_cache: Dictionary = {}
var occupied_tree_positions: Array[Vector2] = []
var occupied_tree_is_skinny: Array[bool] = []

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# A Retry or quit mid-build: the bank worker only touches its own copies.
		if _bank_fit_task >= 0: WorkerThreadPool.wait_for_task_completion(_bank_fit_task)
		_bank_fit_task = -1
		if _path_strip_task >= 0: WorkerThreadPool.wait_for_group_task_completion(_path_strip_task)
		_path_strip_task = -1
		_free_owned_park_prototypes()

func _free_owned_park_prototypes() -> void:
	# These templates are owned outside the tree; placed nodes are duplicates.
	# Keep them through remove/re-add. Only deletion ends the owner's lifetime.
	var owned: Array = []
	for bucket: Array in [broadleaf_prototypes, pine_prototypes, pine_sapling_prototypes,
			forest_floor_bush_prototypes, lilac_prototypes, dense_grass_prototypes]:
		owned.append_array(bucket)
		bucket.clear()
	for field: StringName in [&"deadwood_trunk_prototype", &"hollow_bark_prototype",
			&"midnight_fern_prototype", &"emerald_fountain_grass_prototype",
			&"japanese_maple_prototype", &"neon_park_bench_prototype",
			&"futuristic_eco_bench_prototype", &"emerald_halo_lamp_prototype",
			&"midori_path_straight_prototype", &"midori_path_curve_prototype",
			&"midori_path_junction_prototype", &"midori_path_resting_pocket_prototype"]:
		owned.append(get(field))
		set(field, null)
	var freed: Dictionary = {}
	for prototype: Variant in owned:
		if not is_instance_valid(prototype) or prototype == self:
			continue
		var id: int = prototype.get_instance_id()
		if freed.has(id) or prototype.get_parent() != null or prototype.is_inside_tree():
			continue
		freed[id] = true
		prototype.free()


func _ready() -> void:
	var _boot_tick := StartupTrace.begin()
	is_night_mode = start_at_night
	# Behind the boot menu (incremental loading only): the add_child frame already
	# runs every child's first slice and the deferred horizon / court / playground
	# builds, which read only is_night_mode (set above). The materials start in the
	# next frame instead of adding ~1 s to that one (the worst frame behind the menu).
	if get_meta("shinrai_incremental_loading", false): await get_tree().process_frame
	_boot_tick = StartupTrace.begin()
	await _create_materials()
	_boot_tick = StartupTrace.finish("park._create_materials",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_create_environment()
	_boot_tick = StartupTrace.finish("park._create_environment",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_prepare_reference_vegetation()
	_boot_tick = StartupTrace.finish("park._prepare_reference_vegetation",_boot_tick)
	await LoadingBudget.checkpoint(self)
	await _build_park_footprint()
	_boot_tick = StartupTrace.finish("park._build_park_footprint",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_disable_imported_suns()
	_boot_tick = StartupTrace.finish("park._disable_imported_suns",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_build_lake_reflection_probe()
	_boot_tick = StartupTrace.finish("park._build_lake_reflection_probe",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_validate_approved_lake_promenade()
	_boot_tick = StartupTrace.finish("park._validate_approved_lake_promenade",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_validate_plaza_centerpiece_clearance()
	_boot_tick = StartupTrace.finish("park._validate_plaza_centerpiece_clearance",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_spawn_scale_review_player()
	# Mouse look during the one live frame below would turn the player by however
	# far the mouse moved, so its pose (and the fingerprint) varied between runs.
	# Input is restored at the end of this function, before anything can use it.
	var review_player := get_node_or_null("ParkScaleReviewPlayer")
	if review_player != null: review_player.set_process_unhandled_input(false)
	_boot_tick = StartupTrace.finish("park._spawn_scale_review_player",_boot_tick)
	# The review player falls under gravity until the run (created right after
	# this function) disables it, so its resting height is the number of physics
	# steps in between. Behind the menu that is exactly one: one frame here (the
	# spawn alone is ~0.6 s, so the next frame always steps physics once), then the
	# HUD and the end of the structure without yielding. Budget turns here could take
	# zero to several frames, which made the player's height vary from run to run.
	if get_meta("shinrai_incremental_loading", false): await get_tree().process_frame
	_build_size_hud()
	_boot_tick = StartupTrace.finish("park._build_size_hud",_boot_tick)
	print("Midori Park size blockout: %.0f m x %.0f m | diagonal %.1f m" % [
		PARK_SIZE_M.x, PARK_SIZE_M.y, PARK_SIZE_M.length()
	])
	if is_instance_valid(review_player): review_player.set_process_unhandled_input(true)
	set_meta("shinrai_structure_pending",false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F7:
		high_render_quality = not high_render_quality
		_apply_render_quality()
		_update_time_label()
		get_viewport().set_input_as_handled()
		return
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == time_of_day_toggle_key
	):
		is_night_mode = not is_night_mode
		_apply_time_of_day()

## Same materials in the same order; the loading budget may end the frame between
## the shader materials (each is compiled when its frame is drawn).
func _create_materials() -> void:
	mat_grass = _make_material(Color("#344f38"), 0.98)
	mat_path = _make_material(Color("#77786f"), 0.94)
	mat_water = _make_lake_water_material()
	await LoadingBudget.checkpoint(self)
	mat_playground = _make_material(Color("#8b6255"), 0.91)
	mat_plaza = CourtMaterials.build(false)
	await LoadingBudget.checkpoint(self)
	mat_plaza_border = CourtMaterials.build(true)
	await LoadingBudget.checkpoint(self)
	mat_plaza_inlay = _make_material(Color("#356f7c"), 0.34, 0.34)
	mat_plaza_inlay.emission_enabled = true
	mat_plaza_inlay.emission = Color("#42b9d4")
	mat_plaza_inlay.emission_energy_multiplier = 0.0
	plaza_emissive_materials.append(mat_plaza_inlay)
	mat_pavilion = _make_material(Color("#8a755e"), 0.88)
	mat_boundary = _make_material(Color("#d6d0bf"), 0.82)
	mat_entry = _make_material(Color("#a99f8a"), 0.88)
	mat_island = _make_lake_ground_material(false, false)
	await LoadingBudget.checkpoint(self)
	mat_shore_bank = _make_lake_ground_material(true, false)
	await LoadingBudget.checkpoint(self)
	mat_island_bank = _make_lake_ground_material(true, true)
	await LoadingBudget.checkpoint(self)
	mat_shore_promenade = _make_material(Color("#77776d"), 0.94)
	mat_shore_landing = _make_material(Color("#aaa28d"), 0.88)
	mat_plan_marker = _make_material(Color(0.20, 0.78, 0.92, 0.55), 0.76, 0.08)
	mat_path_light_streak = _make_path_light_streak_material()
	modular_path_shader = _make_modular_path_shader()
	await LoadingBudget.checkpoint(self)
	mat_paved_surface = _make_continuous_paving_material()
	await LoadingBudget.checkpoint(self)
	mat_lake_paved_surface = _make_continuous_paving_material(false)

## The three lake-ground materials share one Shader: the code is identical (only
## uniforms differ) and each Shader.code assignment compiles it on the main thread
## (~110 ms; it used to be set twice per material, base then with the palette).
## Same final code, same uniforms; iris_shore still swaps a duplicate onto the bank.
var _lake_ground_shader: Shader

func _make_lake_ground_material(is_bank: bool, water_at_outer_edge: bool) -> ShaderMaterial:
	if _lake_ground_shader == null:
		_lake_ground_shader = Shader.new()
		_lake_ground_shader.code = LAKE_GROUND_SHADER_CODE.replace("void vertex()", preload("res://scripts/midori_ground_texture.gd").EARTH_PALETTE_GLSL + "\nvoid vertex()")
	var shader := _lake_ground_shader
	var material := ShaderMaterial.new()
	material.resource_name = "Midori_IslandDampBank" if water_at_outer_edge else ("Midori_MainlandDampBank" if is_bank else "Midori_IslandForestGround")
	material.shader = shader
	material.set_shader_parameter("albedo_tex", load("res://assets/shinrai/parks/midori_park/materials/forrest_ground_01/forrest_ground_01_diff_2k.jpg"))
	material.set_shader_parameter("normal_tex", load("res://assets/shinrai/parks/midori_park/materials/forrest_ground_01/forrest_ground_01_nor_gl_2k.jpg"))
	material.set_shader_parameter("roughness_tex", load("res://assets/shinrai/parks/midori_park/materials/forrest_ground_01/forrest_ground_01_rough_2k.jpg"))
	material.set_shader_parameter("is_bank", is_bank)
	material.set_shader_parameter("water_at_outer_edge", water_at_outer_edge)
	return material

const LAKE_GROUND_SHADER_CODE := """
shader_type spatial;
render_mode depth_draw_opaque, cull_disabled;

uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool is_bank = false;
uniform bool water_at_outer_edge = false;
uniform float scene_light_factor = 1.0;
varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // Match the mainland scan's two-metre scale, tint and exposure at dry edges.
    vec2 ground_uv = world_position.xz / 2.0;
    vec3 scan_rgb = texture(albedo_tex, ground_uv).rgb;
    float source_luma = dot(scan_rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 dry_ground = midori_forest_floor(scan_rgb, world_position.xz);
    float wetness = 0.0;
    vec3 ground_color = dry_ground;
    if (is_bank) {
        float landward = water_at_outer_edge ? 1.0 - UV.x : UV.x;
        // Texture variation breaks up the damp band without changing the shore.
        float breakup = (source_luma - 0.22) * 0.24;
        float grass_blend = smoothstep(0.12, 0.88, landward + breakup);
        wetness = 1.0 - smoothstep(0.02, 0.44, landward + breakup);
        vec3 soil_color = dry_ground * vec3(0.68, 0.65, 0.60);
        ground_color = mix(soil_color, dry_ground, grass_blend);
        ground_color *= mix(1.0, 0.62, wetness);
    }
    ALBEDO = ground_color * scene_light_factor;
    float roughness_scan = texture(roughness_tex, ground_uv).r;
    ROUGHNESS = mix(clamp(roughness_scan * 0.94 + 0.06, 0.78, 1.0), 0.66, wetness);
    SPECULAR = mix(0.08, 0.20, wetness);
    // These generated ribbons have no tangent stream. Derive the detail normal
    // from world XZ, avoiding back-face flipping on their two-sided triangles.
    vec3 scan_normal = texture(normal_tex, ground_uv).rgb * 2.0 - 1.0;
    vec3 ground_normal = normalize(vec3(scan_normal.x * 0.26, max(scan_normal.z, 0.5), scan_normal.y * 0.26));
    NORMAL = normalize((VIEW_MATRIX * vec4(ground_normal, 0.0)).xyz);
}
"""

func _make_material(color_value: Color, roughness_value: float, metallic_value: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color_value
	material.roughness = roughness_value
	material.metallic = metallic_value
	return material

func _make_path_light_streak_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float night_strength = 1.0;

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float along = abs(UV.y - 0.5) * 2.0;
	float side_fade = 1.0 - smoothstep(0.28, 1.0, across);
	float end_fade = 1.0 - smoothstep(0.58, 1.0, along);
	float alpha = side_fade * end_fade * 0.76 * night_strength;
	vec3 blue = vec3(0.20, 0.76, 1.0);
	ALBEDO = blue;
	EMISSION = blue * 2.0 * night_strength;
	ALPHA = alpha;
}
"""
	var material := ShaderMaterial.new()
	material.resource_name = "SHINRAI_BlueSlitPathStreak"
	material.shader = shader
	return material

func _make_modular_path_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform sampler2D source_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D source_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D source_orm : filter_linear_mipmap_anisotropic;
uniform float night_emission = 1.0;

void fragment() {
	vec4 texel = texture(source_albedo, UV);
	vec3 orm = texture(source_orm, UV).rgb;
	vec3 base = texel.rgb;
	float high_channel = max(base.r, max(base.g, base.b));
	float low_channel = min(base.r, min(base.g, base.b));
	float cyan_bias = min(base.g, base.b) - base.r;
	float cyan_mask = smoothstep(0.08, 0.26, cyan_bias)
		* smoothstep(0.16, 0.48, high_channel - low_channel);
	// The supplied modules carry cyan LED inlays; they are painted out as plain
	// weathered stone (no light, no blue).
	float luma = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 stone = mix(base, vec3(luma) * vec3(1.0, 0.97, 0.9), cyan_mask);
	ALBEDO = stone * vec3(0.62, 0.59, 0.53);
	NORMAL_MAP = texture(source_normal, UV).rgb;
	NORMAL_MAP_DEPTH = 0.62;
	AO = orm.r;
	ROUGHNESS = clamp(orm.g, 0.58, 0.92);
	METALLIC = orm.b * 0.18;
}
"""
	shader.resource_name = "SHINRAI_MidoriModularPath"
	return shader

func _create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ParkReviewEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#547b9e")
	sky_material.sky_horizon_color = Color("#bacdd5")
	sky_material.sky_cover_modulate = Color("#ffffff")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# Sky-driven ambient gives cool shadows under a warm sun instead of one flat grey.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_white = 6.0
	environment.adjustment_enabled = true
	# Depth fog: a gentle haze that separates the park from the far shore and softens
	# the horizon line. Aerial perspective tints it toward the sun.
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_density = 0.0016
	environment.fog_aerial_perspective = 0.55
	environment.fog_sky_affect = 0.45
	environment.fog_height = -4.0
	environment.fog_height_density = 0.12
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		environment.volumetric_fog_enabled = false
		environment.volumetric_fog_density = 0.012
		environment.volumetric_fog_length = 90.0
		environment.volumetric_fog_albedo = Color("#6d7f96")
		environment.volumetric_fog_emission = Color("#101826")
		environment.volumetric_fog_emission_energy = 0.05
		environment.volumetric_fog_ambient_inject = 0.18
		environment.volumetric_fog_sky_affect = 0.65
		environment.volumetric_fog_anisotropy = 0.45
	world_environment.environment = environment
	park_environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34.0, -38.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.50
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 1.8
	sun.light_angular_distance = 0.6
	park_directional_light = sun
	add_child(sun)
	_apply_time_of_day()

func _apply_time_of_day() -> void:
	if park_environment == null or park_directional_light == null:
		return
	var sky_material := park_environment.sky.sky_material as ProceduralSkyMaterial
	park_environment.adjustment_brightness = 1.0
	park_environment.adjustment_contrast = 1.06
	park_environment.adjustment_saturation = 1.08
	# Gentle split tone: day has cool shade and warm light, night leans blue
	# in the shadows so lamp light reads warmer against it.
	if is_night_mode:
		park_environment.adjustment_color_correction = _grade_ramp(Color(0.215, 0.245, 0.29), Color(0.765, 0.75, 0.735))
	else:
		park_environment.adjustment_color_correction = _grade_ramp(Color(0.235, 0.252, 0.262), Color(0.765, 0.75, 0.725))
	if is_night_mode:
		# Moonlit night: deep blue sky, cool silver moon, enough fog for lamps to glow.
		sky_material.sky_top_color = Color("#070d1c")
		sky_material.sky_horizon_color = Color("#2a3a55")
		sky_material.ground_bottom_color = Color("#05080e")
		sky_material.ground_horizon_color = Color("#1a2434")
		sky_material.sky_curve = 0.12
		sky_material.sun_angle_max = 8.0
		sky_material.sun_curve = 0.4
		sky_material.sky_energy_multiplier = 0.9
		park_environment.background_energy_multiplier = 0.7
		park_environment.ambient_light_sky_contribution = 1.0
		park_environment.ambient_light_energy = 0.7
		park_environment.fog_light_color = Color("#243247")
		park_environment.fog_light_energy = 0.55
		park_environment.fog_density = 0.0032
		park_environment.fog_sun_scatter = 0.08
		park_environment.fog_aerial_perspective = 0.35
		park_environment.tonemap_exposure = 1.15
		park_environment.glow_intensity = 0.7
		park_environment.glow_bloom = 0.08
		park_environment.glow_hdr_threshold = 0.95
		park_directional_light.name = "ParkNightMoon"
		park_directional_light.rotation_degrees = Vector3(-48.0, 24.0, 0.0)
		park_directional_light.light_color = Color("#9fb3d6")
		park_directional_light.light_energy = 0.6
		mat_path.albedo_color = Color("#171c22")
		mat_boundary.albedo_color = Color("#202832")
	else:
		# Golden-hour daylight: warm low sun, blue sky overhead, hazy pale horizon.
		sky_material.sky_top_color = Color("#2f68a8")
		sky_material.sky_horizon_color = Color("#dccbb8")
		sky_material.ground_bottom_color = Color("#2a3a2e")
		sky_material.ground_horizon_color = Color("#b8ac97")
		sky_material.sky_curve = 0.09
		sky_material.sun_angle_max = 24.0
		sky_material.sun_curve = 0.18
		sky_material.sky_energy_multiplier = 1.0
		park_environment.background_energy_multiplier = 0.85
		park_environment.ambient_light_sky_contribution = 1.0
		park_environment.ambient_light_energy = 0.95
		park_environment.fog_light_color = Color("#cfc3b4")
		park_environment.fog_light_energy = 0.9
		park_environment.fog_density = 0.0011
		park_environment.fog_sun_scatter = 0.16
		park_environment.fog_aerial_perspective = 0.5
		park_environment.tonemap_exposure = 0.92
		park_environment.glow_intensity = 0.45
		park_environment.glow_bloom = 0.04
		park_environment.glow_hdr_threshold = 1.25
		park_directional_light.name = "ParkReviewSun"
		park_directional_light.rotation_degrees = Vector3(-26.0, -52.0, 0.0)
		park_directional_light.light_color = Color("#ffd9a8")
		park_directional_light.light_energy = 1.35
		mat_path.albedo_color = Color("#77786f")
		mat_boundary.albedo_color = Color("#d6d0bf")
	for material: StandardMaterial3D in lamp_emissive_materials:
		material.emission_energy_multiplier = 1.8 if is_night_mode else 0.0
	for material: StandardMaterial3D in plaza_emissive_materials:
		material.emission_energy_multiplier = 0.72 if is_night_mode else 0.0
	for material: ShaderMaterial in modular_path_emissive_materials:
		material.set_shader_parameter("night_emission", 1.0 if is_night_mode else 0.0)
	mat_path_light_streak.set_shader_parameter("night_strength", 1.0 if is_night_mode else 0.0)
	for material: ShaderMaterial in [mat_island, mat_shore_bank, mat_island_bank]:
		material.set_shader_parameter("scene_light_factor", 1.0)
	var ground_service := get_node_or_null("/root/MidoriGroundTexture")
	if ground_service != null and ground_service.has_method("set_night_mode"):
		ground_service.call("set_night_mode", is_night_mode)
	for node: Node in get_tree().get_nodes_in_group("midori_night_effect"):
		if node is Node3D:
			(node as Node3D).visible = is_night_mode
	for horizon: Node in get_tree().get_nodes_in_group("midori_horizon"):
		if horizon.has_method("set_night_mode"): horizon.call("set_night_mode", is_night_mode)
	_apply_render_quality()
	_update_time_label()
	_queue_reflection_refresh()

static func _grade_ramp(shadow: Color, highlight: Color) -> GradientTexture1D:
	# Per-channel curve: black and white stay fixed; quarter and three-quarter
	# tones are nudged to tint shadows and highlights separately.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	gradient.colors = PackedColorArray([Color.BLACK, shadow, highlight, Color.WHITE])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	ramp.width = 256
	return ramp

func _update_time_label() -> void:
	if time_of_day_label != null:
		time_of_day_label.text = "N: %s  |  F7: %s graphics  |  Target: 60 FPS" % [
			"NIGHT" if is_night_mode else "DAY", "HIGH" if high_render_quality else "BALANCED"]

func _disable_imported_suns() -> void:
	# Some supplied models include authoring lights. Directional lights affect
	# the entire park, not just their parent mesh; keep only our controlled sun.
	for light: Node in find_children("*", "DirectionalLight3D", true, false):
		if light != park_directional_light:
			(light as DirectionalLight3D).hide()
			(light as DirectionalLight3D).shadow_enabled = false

func _apply_render_quality() -> void:
	if park_environment == null:
		return
	var forward_plus := RenderingServer.get_current_rendering_method() == "forward_plus"
	if forward_plus:
		var viewport := get_viewport()
		# Keep TAA, foliage shadows, and the lake reflection at native resolution.
		# Resizing the window also increases the actual 3D pixel count.
		# Smoothing is the player's setting. A test that drives the view itself keeps its own.
		if not get_tree().root.has_meta(&"shinrai_aa_external"):
			preload("res://scripts/shinrai_settings.gd").apply(viewport)
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = preload("res://scripts/shinrai_settings.gd").session_scale()
		# Imported tree meshes already contain LODs. Earlier transitions in
		# Balanced reduce distant canopy triangles without changing near trees.
		viewport.mesh_lod_threshold = 1.0 if high_render_quality else 4.0
	# Contact shadows ground objects on both presets; Balanced uses a tighter radius.
	park_environment.ssao_enabled = forward_plus
	park_environment.ssao_radius = 1.2 if high_render_quality else 0.9
	park_environment.ssao_intensity = 1.4 if high_render_quality else 1.1
	park_environment.ssao_power = 1.8
	park_environment.ssao_detail = 0.5
	park_environment.ssao_horizon = 0.06
	park_environment.ssao_sharpness = 0.98
	park_environment.ssao_light_affect = 0.0
	park_environment.ssao_ao_channel_affect = 0.0
	# High adds soft bounce light under canopies and between buildings.
	park_environment.ssil_enabled = forward_plus and high_render_quality
	park_environment.ssil_radius = 4.0
	park_environment.ssil_intensity = 0.7
	park_environment.ssr_enabled = forward_plus and high_render_quality
	park_environment.ssr_max_steps = 48
	park_environment.ssr_depth_tolerance = 0.2
	park_environment.glow_enabled = forward_plus
	park_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	park_environment.glow_hdr_scale = 1.5
	# Night air: volumetric fog on both presets so lanterns throw visible light
	# into the haze. Balanced keeps it short and thin; High reaches further.
	# High daylight adds a thin, sun-forward haze so low sun rakes through the
	# trees as visible shafts. Balanced daylight stays fog-free for frame time.
	park_environment.volumetric_fog_enabled = forward_plus and (is_night_mode or high_render_quality)
	if is_night_mode:
		park_environment.volumetric_fog_density = 0.018 if high_render_quality else 0.012
		park_environment.volumetric_fog_albedo = Color("#6d7f96")
		park_environment.volumetric_fog_emission_energy = 0.05
		park_environment.volumetric_fog_anisotropy = 0.45
	else:
		park_environment.volumetric_fog_density = 0.0045
		park_environment.volumetric_fog_albedo = Color("#e3d6c2")
		park_environment.volumetric_fog_emission_energy = 0.0
		park_environment.volumetric_fog_anisotropy = 0.72
	park_environment.volumetric_fog_length = 96.0 if high_render_quality else 64.0
	park_environment.volumetric_fog_detail_spread = 2.2
	park_environment.volumetric_fog_temporal_reprojection_enabled = true
	park_environment.volumetric_fog_temporal_reprojection_amount = 0.92
	park_directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if high_render_quality else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	# Balanced: 60 m saved ~4.6M shadow triangles at the south lawn (35 -> 40 FPS);
	# tree shadows past that are small on screen and softened by the haze.
	park_directional_light.directional_shadow_max_distance = 110.0 if high_render_quality else 60.0
	# Two-map Balanced shadows need less normal offset to retain thin fence/goal casts.
	# Keep the original High offset and all atlas/split/distance settings.
	park_directional_light.shadow_normal_bias = 1.0 if high_render_quality else 0.5

func _build_lake_reflection_probe() -> void:
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		return
	# A separate render layer prevents the lake reflecting its own surface.
	var water := find_child("LakeWaterSurface", true, false) as MeshInstance3D
	if water != null:
		water.layers = 2
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lake_reflection_probe = ReflectionProbe.new()
	lake_reflection_probe.name = "LakeCachedReflection"
	lake_reflection_probe.position = Vector3(90.0, 8.0, -20.0)
	lake_reflection_probe.size = Vector3(170.0, 40.0, 270.0)
	lake_reflection_probe.max_distance = 320.0
	lake_reflection_probe.cull_mask = 1
	lake_reflection_probe.reflection_mask = 2
	lake_reflection_probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	lake_reflection_probe.mesh_lod_threshold = 3.0
	lake_reflection_probe.enable_shadows = true
	lake_reflection_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(lake_reflection_probe)

func _queue_reflection_refresh() -> void:
	if lake_reflection_probe == null or reflection_refresh_queued:
		return
	reflection_refresh_queued = true
	# Let sky/light changes settle, then invalidate the cached capture once.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(lake_reflection_probe):
		lake_reflection_probe.position.x = 90.001 if is_night_mode else 90.0
	reflection_refresh_queued = false

func _build_park_footprint() -> void:
	_vegetation_clearance_cache=null
	var _boot_tick := StartupTrace.begin()
	var root := Node3D.new()
	root.name = "MidoriPark_440x360m_ProceduralLayout"
	root.scale = Vector3(LAYOUT_SCALE, 1.0, LAYOUT_SCALE)
	add_child(root)

	# Geometry is authored in the original 220 x 180 m coordinate system and
	# expanded uniformly here. Placed assets compensate locally so only their
	# positions spread out; trees, furniture and props keep real-world scale.
	_add_collidable_box(root, "ParkGround_220x180m", Vector3(0.0, -0.12, 0.0), Vector3(LAYOUT_REFERENCE_SIZE_M.x, 0.24, LAYOUT_REFERENCE_SIZE_M.y), mat_grass)
	_boot_tick = StartupTrace.finish("park._add_collidable_box",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_build_boundary(root)
	_boot_tick = StartupTrace.finish("park._build_boundary",_boot_tick)
	await LoadingBudget.checkpoint(self)
	await _build_paths(root)
	_boot_tick = StartupTrace.finish("park._build_paths",_boot_tick)
	await LoadingBudget.checkpoint(self)
	await _build_curved_promenades(root)
	_boot_tick = StartupTrace.finish("park._build_curved_promenades",_boot_tick)
	await LoadingBudget.checkpoint(self)
	# Continuous paving replaces disconnected decorative modules.
	await _build_zone_placeholders(root)
	_boot_tick = StartupTrace.finish("park._build_zone_placeholders",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_build_artwork_assets(root)
	_boot_tick = StartupTrace.finish("park._build_artwork_assets",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_build_prop_placement_plan(root)
	_boot_tick = StartupTrace.finish("park._build_prop_placement_plan",_boot_tick)
	await LoadingBudget.checkpoint(self)
	if SHOW_PLANNING_LABELS:
		_build_scale_ticks(root)
	_build_sakura_trees(root)
	_boot_tick = StartupTrace.finish("park._build_sakura_trees",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_build_reference_canopy(root)
	_boot_tick = StartupTrace.finish("park._build_reference_canopy",_boot_tick)
	await LoadingBudget.checkpoint(self)
	# Primitive mushroom-like flower placeholders removed; botanical models are supplied separately.
	_build_deadwood_pass(root)
	_boot_tick = StartupTrace.finish("park._build_deadwood_pass",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_build_woodland_fallen_fragments(root)
	_boot_tick = StartupTrace.finish("park._build_woodland_fallen_fragments",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_build_japanese_maple_pass(root)
	_boot_tick = StartupTrace.finish("park._build_japanese_maple_pass",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_build_open_lawn_cover(root)
	_boot_tick = StartupTrace.finish("park._build_open_lawn_cover",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_build_park_benches(root)
	_boot_tick = StartupTrace.finish("park._build_park_benches",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_build_park_lamps(root)
	_boot_tick = StartupTrace.finish("park._build_park_lamps",_boot_tick)
	await LoadingBudget.checkpoint(self)
	_build_landmark_plaza_furniture(root)
	_boot_tick = StartupTrace.finish("park._build_landmark_plaza_furniture",_boot_tick)
	await LoadingBudget.checkpoint(self)
	TreeBranchContactPlacement.apply(self)
	WoodlandLayout.apply(self)
	var understory := Node.new()
	understory.name = "MidoriUnderstoryPlacement"
	understory.set_script(preload("res://scripts/midori_understory_placement.gd"))
	add_child(understory)
	var barrier := Node3D.new()
	barrier.name = "MidoriLakeBarrier"
	barrier.set_script(preload("res://scripts/midori_lake_barrier.gd"))
	add_child(barrier)
	var sparse := Node3D.new()
	sparse.name = "MidoriSparseVegetation"
	sparse.set_script(preload("res://scripts/midori_sparse_vegetation.gd"))
	add_child(sparse)
	var floor_detail := Node3D.new()
	floor_detail.name = "MidoriParkFloor"
	floor_detail.set_script(preload("res://scripts/midori_park_floor.gd"))
	add_child(floor_detail)

func _build_boundary(parent: Node3D) -> void:
	var edge_t := 0.32
	_add_visual_box(parent, "NorthBoundary", Vector3(0.0, 0.04, -PARK_HALF.y), Vector3(LAYOUT_REFERENCE_SIZE_M.x, 0.08, edge_t), mat_boundary)
	_add_visual_box(parent, "SouthBoundary", Vector3(0.0, 0.04, PARK_HALF.y), Vector3(LAYOUT_REFERENCE_SIZE_M.x, 0.08, edge_t), mat_boundary)
	_add_visual_box(parent, "WestBoundary", Vector3(-PARK_HALF.x, 0.04, 0.0), Vector3(edge_t, 0.08, LAYOUT_REFERENCE_SIZE_M.y), mat_boundary)
	_add_visual_box(parent, "EastBoundary", Vector3(PARK_HALF.x, 0.04, 0.0), Vector3(edge_t, 0.08, LAYOUT_REFERENCE_SIZE_M.y), mat_boundary)

	# Four broad entrances make the footprint readable before detailed paths exist.
	for entry in [
		{"name": "MainSouthEntrance", "position": Vector3(0.0, 0.09, PARK_HALF.y - 2.5), "size": Vector3(16.0, 0.10, 5.0)},
		{"name": "NorthEntrance", "position": Vector3(-38.0, 0.09, -PARK_HALF.y + 2.5), "size": Vector3(12.0, 0.10, 5.0)},
		{"name": "WestEntrance", "position": Vector3(-PARK_HALF.x + 2.5, 0.09, 20.0), "size": Vector3(5.0, 0.10, 12.0)},
		{"name": "EastEntrance", "position": Vector3(PARK_HALF.x - 2.5, 0.09, -20.0), "size": Vector3(5.0, 0.10, 12.0)},
	]:
		_add_visual_box(parent, entry["name"], entry["position"], entry["size"], mat_entry)

var _path_edge_cells: Dictionary = {}
const MAIN_PATH_WIDTHS_M := {
	"OuterWalkingCircuit":4.8, "SouthEntranceToLake":5.6,
	"SouthEntranceToPlaza":5.2, "WestEntranceToBridgeLanding":5.0,
	"NorthEntranceToLake":4.8, "EastEntranceToBridgeLanding":4.8,
	"SportsConnector":3.4,
}

func _path_width_world(label: String, authored: float) -> float:
	if MAIN_PATH_WIDTHS_M.has(label): return float(MAIN_PATH_WIDTHS_M[label])
	if label == "ContinuousLakePromenade": return authored * 0.55 * LAYOUT_SCALE
	if label.ends_with("BridgeLink"): return authored * 0.50 * LAYOUT_SCALE
	return authored * 0.46 * LAYOUT_SCALE

func _path_curve_radius(label: String) -> float:
	if label in ["PlaygroundWoodlandLoop","NorthWoodlandLoop"]:return 8.0
	return 6.0 if MAIN_PATH_WIDTHS_M.has(label) else 4.0

func _path_corner_fraction(label: String) -> float:
	return .49 if label=="PlaygroundWoodlandLoop" else (.45 if label=="NorthWoodlandLoop" else .25)

func path_edge_distance_world(point: Vector2) -> float:
	var result := INF
	var cell := Vector2i(floori(point.x/8.0),floori(point.y/8.0))
	for segment:Dictionary in _path_edge_cells.get(cell,[]):
		var nearest := Geometry2D.get_closest_point_to_segment(point,segment.a,segment.b)
		var t := clampf((nearest-segment.a).length()/maxf(.001,segment.a.distance_to(segment.b)),0.0,1.0)
		result=minf(result,point.distance_to(nearest)-lerpf(segment.wa,segment.wb,t)*.5)
	return result

func _index_path_edges(centres: PackedVector3Array,widths: PackedFloat32Array) -> void:
	for i:int in range(centres.size()-1):
		var a:=Vector2(centres[i].x,centres[i].z)
		var b:=Vector2(centres[i+1].x,centres[i+1].z)
		var reach:=maxf(widths[i],widths[i+1])*.5+9.0
		var low:=a.min(b)-Vector2.ONE*reach
		var high:=a.max(b)+Vector2.ONE*reach
		var segment:={"a":a,"b":b,"wa":widths[i],"wb":widths[i+1]}
		for z:int in range(floori(low.y/8.0),floori(high.y/8.0)+1):
			for x:int in range(floori(low.x/8.0),floori(high.x/8.0)+1):
				var key:=Vector2i(x,z)
				if not _path_edge_cells.has(key):_path_edge_cells[key]=[]
				_path_edge_cells[key].append(segment)

func _build_paths(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "FinalDestinationLedPathHierarchy"
	parent.add_child(root)
	await _add_path_strips_2d(root, [
		["OuterWalkingCircuit", OUTER_CIRCUIT, 3.8, 0.108],
		["SouthEntranceToLake", SOUTH_ARRIVAL_ROUTE, 4.0, 0.111],
		["SouthEntranceToPlaza", PLAZA_PAVED_ROUTE, 4.0, 0.112],
		["WestEntranceToBridgeLanding", WEST_DESTINATION_ROUTE, 4.0, 0.112],
		["NorthEntranceToLake", NORTH_ENTRY_ROUTE, 3.8, 0.110],
		["EastEntranceToBridgeLanding", EAST_DECK_ROUTE, 3.8, 0.110],
		["SportsConnector", SPORTS_LINK_ROUTE, 3.0, 0.109],
		["PlaygroundWoodlandLoop", PLAYGROUND_LOOP, 2.7, 0.109],
		["NorthWoodlandLoop", NORTH_WOODLAND_LOOP, 2.5, 0.109],
		["PlazaToSouthBridgeLanding", SOUTH_BRIDGE_APPROACH, 3.2, 0.111],
		["PavilionGardenLink", PAVILION_LINK_ROUTE, 2.8, 0.110],
		["EastPromenadeToViewingDeck", VIEWING_DECK_APPROACH_ROUTE, 3.0, 0.112],
	])
	# Bridge branches are fitted to the supplied front treads in the lake pass.

## Path strips in one batch. The routes and paving materials are made on the main
## thread in the original order; the vertex loop of every strip (pure maths on its
## route points, width and material kind) runs on workers at once; then the mesh
## nodes, metas and the path-edge table are made on the main thread in the original
## order. Same functions on the same inputs as the one-by-one build.
var _path_strip_task := -1

func _add_path_strips_2d(parent: Node3D, specs: Array) -> void:
	var jobs: Array = []
	for spec: Array in specs:
		jobs.append(_prepare_path_strip(spec[0], spec[1], spec[2], spec[3]))
	# All worker threads, waited for at once (a short parallel burst; a frame per
	# wait costs more on this, the critical path, than it gives back).
	await LoadingBudget.checkpoint(self)
	_path_strip_task = WorkerThreadPool.add_group_task(_path_strip_job.bind(jobs), jobs.size(), -1, true, "park.path_strips")
	WorkerThreadPool.wait_for_group_task_completion(_path_strip_task)
	_path_strip_task = -1
	for job: Dictionary in jobs:
		_commit_path_strip(parent, job)
		await LoadingBudget.checkpoint(self)

func _prepare_path_strip(
	node_name: String,
	points_2d: Array[Vector2],
	width: float,
	y_value: float
) -> Dictionary:
	# Widths are explicit world metres; scene layout scale affects positions only.
	width = _path_width_world(node_name,width) / LAYOUT_SCALE
	var route: Array[Vector2] = points_2d.duplicate()
	# Remove tiny return segments at approach endpoints that form hooked joins.
	if not route[0].is_equal_approx(route[-1]):
		while route.size() > 2 and route[-2].distance_to(route[-1]) < 3.0:
			route.remove_at(route.size() - 2)
	var points_3d: Array[Vector3] = []
	var closed := route[0].is_equal_approx(route[-1])
	# Side walks are flowing, flush gravel; the main walks keep their paving.
	var secondary := not MAIN_PATH_WIDTHS_M.has(node_name) and node_name != "ContinuousLakePromenade" and not node_name.ends_with("BridgeLink")
	var curved := _smooth_walk(route, closed) if secondary else _rounded_contour(route, closed, _path_curve_radius(node_name), _path_corner_fraction(node_name))
	if secondary:
		y_value = 0.035
		# Run each open end 1.2 m on, under the raised walk it meets, so the
		# join is hidden beneath that paving instead of butting it square.
		if not closed and curved.size() > 1:
			curved[0] += (curved[0] - curved[1]).normalized() * (1.2 / LAYOUT_SCALE)
			curved[-1] += (curved[-1] - curved[-2]).normalized() * (1.2 / LAYOUT_SCALE)
	for point: Vector2 in curved:
		points_3d.append(Vector3(point.x, y_value, point.y))
	var world_length := 0.0
	for i: int in range(points_3d.size()-1):
		world_length += points_3d[i].distance_to(points_3d[i+1]) * LAYOUT_SCALE
	var paving_material := WalkMaterials.build_secondary(width * LAYOUT_SCALE) if secondary else WalkMaterials.build(width * LAYOUT_SCALE,world_length,closed)
	paving_material.set_shader_parameter("night_emission",1.0 if is_night_mode else 0.0)
	if not modular_path_emissive_materials.has(paving_material):
		modular_path_emissive_materials.append(paving_material)
	# Gravel side walks flare where feet spread onto the walk they join.
	var masado := paving_material is ShaderMaterial and String(paving_material.resource_name).begins_with("Midori_MasadoWalk")
	return {"name": node_name, "points": points_3d, "width": width, "material": paving_material, "masado": masado}

## A side walk as people actually wear it: one flowing curve through the
## route's anchors (Chaikin corner cutting), with no straight runs or kinks.
func _smooth_walk(source: Array[Vector2], closed: bool) -> Array[Vector2]:
	var points: Array[Vector2] = source.duplicate()
	if closed: points.remove_at(points.size() - 1)
	for pass_index: int in range(4):
		var out: Array[Vector2] = []
		var count := points.size() if closed else points.size() - 1
		if not closed: out.append(points[0])
		for i: int in range(count):
			var a := points[i]
			var b := points[(i + 1) % points.size()]
			out.append(a.lerp(b, 0.25))
			out.append(a.lerp(b, 0.75))
		if not closed: out.append(points[points.size() - 1])
		points = out
	if closed: points.append(points[0])
	return points

func _build_curved_promenades(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "ApprovedLakePromenadeLoop"
	parent.add_child(root)
	await _add_path_strips_2d(root, [["ContinuousLakePromenade", LAKE_PROMENADE_LOOP, LAKE_PROMENADE_WIDTH_M, 0.114]])

## Main thread, in order: the strip's mesh node, metas and path-edge cells.
func _commit_path_strip(parent: Node3D, job: Dictionary) -> void:
	if not job.has("arrays"): return # fewer than two points: no strip, as before
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = job.name
	# What SurfaceTool.commit() makes from these arrays (no custom formats, no flags).
	var mesh := ArrayMesh.new()
	var arrays: Array = job.arrays
	if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array and (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = job.material
	parent.add_child(mesh_instance)
	var points: Array[Vector3] = job.points
	var width: float = job.width
	var widths: PackedFloat32Array = job.widths
	var node_name: String = job.name
	var centres := PackedVector3Array()
	for point:Vector3 in points: centres.append(mesh_instance.to_global(point))
	mesh_instance.set_meta("midori_path_centres_world",centres)
	mesh_instance.set_meta("midori_path_width_m",width*LAYOUT_SCALE)
	mesh_instance.set_meta("midori_path_widths_world",widths)
	mesh_instance.set_meta("midori_path_role","main" if MAIN_PATH_WIDTHS_M.has(node_name) else ("promenade" if node_name=="ContinuousLakePromenade" else "secondary"))
	_index_path_edges(centres,widths)

## Worker: the strip's vertex loop (was _add_path_strip). Touches only its own job.
static func _path_strip_job(index: int, jobs: Array) -> void:
	var job: Dictionary = jobs[index]
	var points: Array[Vector3] = job.points
	if points.size() < 2: return
	var node_name: String = job.name
	var width: float = job.width
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: Array[Vector3] = []
	var closed := points[0].is_equal_approx(points[-1])
	for i: int in range(points.size()):
		var before := points[maxi(i-1,0)]
		var after := points[mini(i+1,points.size()-1)]
		if closed and (i==0 or i==points.size()-1):
			before=points[-2];after=points[1]
		var direction := (after-before).normalized()
		sides.append(Vector3(-direction.z,0,direction.x))
	# A 20 cm mineral shoulder grades the 11 cm walk down to 15 mm above soil.
	# It is part of both the mesh and terrain-generated collision, not an overlay.
	var inset := minf(0.20 / LAYOUT_SCALE,width*0.10)
	var half := width*0.5
	var across: Array[float] = [-half,-half+inset,half-inset,half]
	var widths:=PackedFloat32Array()
	var remaining:=0.0
	for i:int in range(points.size()-1):remaining+=points[i].distance_to(points[i+1])*LAYOUT_SCALE
	var total:=remaining
	# Gravel side walks flare where feet spread onto the walk they join.
	var flared:=bool(job.masado) and not closed
	for i:int in range(points.size()):
		if i>0:remaining-=points[i-1].distance_to(points[i])*LAYOUT_SCALE
		# The north terminus already sits 11 cm from the smoothed shoreline.
		# Ease its last 24 m into the original bank-safe mouth width.
		var fraction:=smoothstep(0.0,24.0,remaining) if node_name=="NorthEntranceToLake" else 1.0
		var mouth:=1.0
		if flared: mouth=1.0+0.7*(1.0-smoothstep(0.0,5.0,minf(total-remaining,remaining)))
		widths.append(lerpf(3.496,width*LAYOUT_SCALE,fraction)*mouth)
	var travelled := 0.0
	for i: int in range(points.size()-1):
		var length := points[i].distance_to(points[i+1])
		for band: int in range(3):
			var pairs:=[Vector2i(i,band),Vector2i(i+1,band),Vector2i(i+1,band+1),Vector2i(i,band),Vector2i(i+1,band+1),Vector2i(i,band+1)]
			for tri:int in [0,3]:
				var vertices:Array[Vector3]=[]
				var uvs:Array[Vector2]=[]
				for k:int in range(3):
					var pair:Vector2i=pairs[tri+k]
					var actual_half:=widths[pair.x]/LAYOUT_SCALE*.5
					var offset:float=[-actual_half,-actual_half+inset,actual_half-inset,actual_half][pair.y]
					var point := points[pair.x]+sides[pair.x]*offset
					if pair.y==0 or pair.y==3: point.y=0.015
					point.x=clampf(point.x,-PARK_HALF.x,PARK_HALF.x)
					point.z=clampf(point.z,-PARK_HALF.y,PARK_HALF.y)
					vertices.append(point)
					var u := travelled+(length if pair.x==i+1 else 0.0)
					uvs.append(Vector2(u,(across[pair.y]+half)/width))
				var normal:=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0])
				if normal.length_squared()<.000000001:continue
				# Tight return bends can invert the inside shoulder's local fan.
				# Keep its visible and collidable surface consistently upward.
				for k:int in ([0,2,1] if normal.y>0.0 else [0,1,2]):
					_add_path_vertex(surface,vertices[k],uvs[k])
		travelled+=length
	surface.generate_normals()
	job.widths = widths
	job.arrays = surface.commit_to_arrays()

func _add_walk_edge(surface: SurfaceTool, a: Vector3, b: Vector3, uv_a: Vector2, uv_b: Vector2, normal: Vector3) -> void:
	var ground_a := Vector3(a.x,0.0,a.z)
	var ground_b := Vector3(b.x,0.0,b.z)
	for item: Array in [[a,uv_a],[ground_a,uv_a],[ground_b,uv_b],[a,uv_a],[ground_b,uv_b],[b,uv_b]]:
		var point: Vector3 = item[0]
		point.x = clampf(point.x,-PARK_HALF.x,PARK_HALF.x)
		point.z = clampf(point.z,-PARK_HALF.y,PARK_HALF.y)
		surface.set_normal(normal)
		surface.set_uv(item[1])
		surface.add_vertex(point)

static func _add_path_vertex(surface: SurfaceTool, position_value: Vector3, uv_value: Vector2) -> void:
	position_value.x = clampf(position_value.x, -PARK_HALF.x, PARK_HALF.x)
	position_value.z = clampf(position_value.z, -PARK_HALF.y, PARK_HALF.y)
	surface.set_normal(Vector3.UP)
	surface.set_uv(uv_value)
	surface.add_vertex(position_value)

func _build_modular_final_path(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "MidoriModularPath_FinalHierarchy"
	parent.add_child(root)

	# Landmark merges provide orientation without repeating the junction at
	# every bend. The narrower procedural paths beneath them remain visible as a
	# border and guarantee continuous, walkable-looking routes between modules.
	if midori_path_junction_prototype != null:
		var junctions: Array[Dictionary] = [
			{"name":"SouthEntranceSplit", "p":Vector3(0,0.118,90), "yaw":0.0},
			{"name":"MainLakeMerge", "p":Vector3(-17,0.118,43), "yaw":12.0},
			{"name":"WestEntranceMerge", "p":Vector3(-98,0.118,20), "yaw":-82.0},
			{"name":"NorthLakeMerge", "p":Vector3(-33,0.118,-50), "yaw":176.0},
			{"name":"EastBridgeMerge", "p":Vector3(86,0.118,-45), "yaw":88.0},
			{"name":"ViewingDeckSplit", "p":Vector3(99,0.118,-17), "yaw":-92.0},
			{"name":"PlazaBridgeMerge", "p":Vector3(77,0.118,74), "yaw":-36.0},
			{"name":"PavilionMerge", "p":Vector3(64,0.118,-64), "yaw":138.0},
		]
		for junction: Dictionary in junctions:
			_add_modular_path_piece(
				root, midori_path_junction_prototype,
				"PathJunction_%s" % junction["name"], junction["p"], junction["yaw"]
			)
	if midori_path_straight_prototype != null:
		_add_modular_path_run(root, SOUTH_ARRIVAL_ROUTE, "SouthArrival", 5.75)
		_add_modular_path_run(root, PLAZA_ARRIVAL_ROUTE, "PlazaArrival", 5.75)
		_add_modular_path_run(root, WEST_DESTINATION_ROUTE, "WestApproach", 5.75)
		_add_modular_path_run(root, NORTH_ENTRY_ROUTE, "NorthArrival", 5.75)
		_add_modular_path_run(root, EAST_DECK_ROUTE, "EastDeckApproach", 5.75)
		_add_modular_path_run(root, LAKE_PROMENADE_LOOP, "LakePromenade", 5.75)
		_add_modular_path_run(root, SOUTH_BRIDGE_APPROACH, "SouthBridgeApproach", 5.75)
		_add_modular_path_run(root, PAVILION_LINK_ROUTE, "PavilionLink", 5.75)
		_add_modular_path_run(root, VIEWING_DECK_APPROACH_ROUTE, "ViewingDeckApproach", 5.75)
	if midori_path_curve_prototype != null:
		var bends: Array[Dictionary] = [
			{"name":"SouthCanopy", "p":Vector3(-7,0.121,71), "yaw":-28.0},
			{"name":"PlazaArrival", "p":Vector3(38,0.121,78), "yaw":76.0},
			{"name":"PlaygroundEdge", "p":Vector3(-87,0.121,31), "yaw":-65.0},
			{"name":"SportsEdge", "p":Vector3(-38,0.121,-28), "yaw":166.0},
			{"name":"NorthWoodland", "p":Vector3(-35,0.121,-73), "yaw":92.0},
			{"name":"WestLakeCove", "p":Vector3(-44,0.121,7), "yaw":8.0},
			{"name":"NorthLakeArc", "p":Vector3(24,0.121,-72), "yaw":88.0},
			{"name":"EastLakeCove", "p":Vector3(86,0.121,7), "yaw":12.0},
			{"name":"SouthLakeArc", "p":Vector3(58,0.121,62), "yaw":-84.0},
			{"name":"WestBridgeTurn", "p":Vector3(-39,0.121,-4), "yaw":146.0},
		]
		for bend: Dictionary in bends:
			_add_modular_path_piece(
				root, midori_path_curve_prototype,
				"PathCurve_%s" % bend["name"], bend["p"], bend["yaw"]
			)
	if midori_path_resting_pocket_prototype != null:
		var pockets: Array[Dictionary] = [
			{"name":"WestRestStop", "p":Vector3(-49,0.118,58), "yaw":160.0},
			{"name":"NorthWoodlandRestStop", "p":Vector3(-20,0.118,-75), "yaw":0.0},
			{"name":"EastPromenadeRestStop", "p":Vector3(100,0.118,6), "yaw":-90.0},
			{"name":"SouthPromenadeRestStop", "p":Vector3(36,0.118,51), "yaw":180.0},
			{"name":"PavilionRestStop", "p":Vector3(76,0.118,-73), "yaw":0.0},
		]
		for pocket: Dictionary in pockets:
			_add_modular_path_piece(
				root, midori_path_resting_pocket_prototype,
				"PathPocket_%s" % pocket["name"], pocket["p"], pocket["yaw"]
			)

func _add_modular_path_run(
	parent: Node3D,
	points: Array[Vector2],
	run_name: String,
	spacing: float
) -> void:
	var serial := 1
	for index: int in range(points.size() - 1):
		var start := points[index]
		var finish := points[index + 1]
		var delta := finish - start
		var segment_length := delta.length()
		if segment_length < 0.1:
			continue
		var direction := delta / segment_length
		var distance := spacing * 0.5
		# Let the last tile slightly overlap each control point. The dedicated curve
		# or junction module then hides the join without exposing a bare underlay gap.
		while distance < segment_length:
			var point := start + direction * distance
			var yaw := rad_to_deg(atan2(direction.x, direction.y))
			_add_modular_path_piece(
				parent, midori_path_straight_prototype,
				"PathStraight_%s_%02d" % [run_name, serial],
				Vector3(point.x,0.116,point.y), yaw
			)
			serial += 1
			distance += spacing

func _add_modular_path_piece(
	parent: Node3D,
	prototype: Node3D,
	node_name: String,
	position_value: Vector3,
	yaw_degrees: float
) -> Node3D:
	var piece := prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
	if piece == null:
		return null
	piece.name = node_name
	piece.position = position_value
	piece.rotation_degrees.y = yaw_degrees
	parent.add_child(piece)
	return piece

func _build_zone_placeholders(parent: Node3D) -> void:
	# Artwork-led lake silhouette: one broad, continuous water body with a
	# tapered north inlet, asymmetric coves and a softer southern shore.
	var lake_root := Node3D.new()
	lake_root.name = "ArtworkContinuousLake_128x234m"
	parent.add_child(lake_root)
	_add_polygon_zone(lake_root, "LakeWaterSurface", lake_contour, 0.102, mat_water, 0.0)
	var bank_contour := lake_contour
	_add_shoreline_ribbon(lake_root, "ContinuousNaturalBank", bank_contour,
		1.15, 0.116, mat_shore_bank)

	# Irregular islands reproduce the layered silhouettes in the aerial artwork.
	# They sit over the single water surface, so no artificial circular seams are
	# visible between lake lobes.
	_add_lake_island(lake_root, "LakeCentralIsland", [
		Vector2(36,-6),Vector2(42,-10),Vector2(50,-8),Vector2(52,-2),
		Vector2(48,3),Vector2(40,2),Vector2(34,-1),
	], 0.148)
	_add_lake_island(lake_root, "LakeNorthIsland", [
		Vector2(46,-50),Vector2(50,-54),Vector2(56,-52),Vector2(57,-47),
		Vector2(53,-44),Vector2(47,-45),
	], 0.149)
	_add_lake_island(lake_root, "LakeSouthIsland", [
		Vector2(48,30),Vector2(52,27),Vector2(57,28),Vector2(58,33),
		Vector2(54,36),Vector2(49,35),
	], 0.149)
	_add_lake_island(lake_root, "LakeEastIslet", [
		Vector2(60,-4),Vector2(64,-7),Vector2(68,-4),Vector2(67,1),
		Vector2(63,2),Vector2(59,0),
	], 0.150)
	_add_lake_island(lake_root, "LakeWestIslet", [
		Vector2(22,-6),Vector2(26,-9),Vector2(30,-7),Vector2(30,-2),
		Vector2(26,0),Vector2(22,-2),
	], 0.150)
	_add_lake_island(lake_root, "LakeNorthWestIslet", [
		Vector2(36,-48),Vector2(40,-51),Vector2(44,-49),Vector2(43,-45),
		Vector2(39,-44),
	], 0.151)
	_add_lake_island(lake_root, "LakeSouthEastIslet", [
		Vector2(58,36),Vector2(61,34),Vector2(64,36),Vector2(63,39),
		Vector2(60,40),
	], 0.151)
	await _build_future_bridge_sockets(lake_root)
	var bank_fit := _start_bank_fit(lake_root)
	_add_zone_label(parent, "ARTWORK LAKE | 7 ISLANDS", Vector3(47.4, 1.0, -7.8), Color("#d4eff7"))
	await LoadingBudget.checkpoint(self)

	# Modular metric turf/goals replace the warped render instance only.
	# Keep the supplied source files and the established gate/floor contracts.
	PitchRemasterScript.build_visuals(parent)
	await LoadingBudget.checkpoint(self)
	var fence := PitchFenceScript.new()
	fence.name = "ACT03_FiveASideSteelFence"
	fence.position = Vector3(-70.0, 0.15, -43.0)
	fence.scale = Vector3(1.0 / LAYOUT_SCALE, 1.0, 1.0 / LAYOUT_SCALE)
	parent.add_child(fence)
	fence.build()
	await LoadingBudget.checkpoint(self)
	# The existing floor datum is shared by the level turf and cafe landing.
	_add_invisible_collision_box(
		parent, "ACT03_PitchWalkableFloor",
		Vector3(-70.0, 0.10, -43.0), Vector3(40.0, 0.10, 21.2), 0.0
	)
	_add_zone_label(parent, "SPORTS 55 x 36 m", Vector3(-70.0, 1.0, -43.0), Color.WHITE)

	_add_zone_box(parent, "PlaygroundZone", Vector3(-72.0, 0.106, 45.0), Vector2(32.0, 26.0), mat_playground)
	_add_zone_label(parent, "PLAYGROUND 32 x 26 m", Vector3(-72.0, 1.0, 45.0), Color.WHITE)

	await LoadingBudget.checkpoint(self)
	_build_landmark_plaza(parent)
	_add_zone_label(parent, "PLAZA 34 x 26 m", Vector3(82.0, 1.0, 68.0), Color("#252525"))

	_add_zone_box(parent, "PavilionZone", Vector3(76.0, 0.108, -73.0), Vector2(20.0, 14.0), mat_pavilion)
	_add_zone_label(parent, "PAVILION 20 x 14 m", Vector3(76.0, 1.0, -73.0), Color.WHITE)
	await _finish_bank_fit(bank_fit)

func _add_pitch_contact_shadow(parent: Node3D) -> void:
	# A feathered, unlit footprint grounds the supplied mesh without rendering
	# its nearly million-triangle fence and net into every shadow map.
	var inner := [Vector2(-10.6, -5.7), Vector2(10.6, -5.7),
		Vector2(10.6, 5.7), Vector2(-10.6, 5.7)]
	var outer := [Vector2(-12.0, -7.1), Vector2(12.0, -7.1),
		Vector2(12.0, 7.1), Vector2(-12.0, 7.1)]
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for side: int in range(4):
		var following := (side + 1) % 4
		var start := vertices.size()
		for corner: Vector2 in [inner[side], outer[side], outer[following], inner[following]]:
			vertices.append(Vector3(corner.x, 0.018, corner.y))
		colors.append(Color(0.0, 0.0, 0.0, 0.23))
		colors.append(Color(0.0, 0.0, 0.0, 0.0))
		colors.append(Color(0.0, 0.0, 0.0, 0.0))
		colors.append(Color(0.0, 0.0, 0.0, 0.23))
		indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	var shadow := MeshInstance3D.new()
	shadow.name = "ACT03_PitchStaticContactShadow"
	shadow.mesh = mesh
	shadow.position = Vector3(-70.0, 0.0, -43.0)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shadow)

func _build_landmark_plaza(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "SoutheastLandmarkPlaza_NeonToriiInstalled"
	parent.add_child(root)

	# Rounded apron encloses the existing furniture and joins the curved approaches.
	_add_cylinder_zone(
		root, "PlazaGroundingCourt",
		Vector3(PLAZA_CENTER.x, 0.107, PLAZA_CENTER.y), Vector2(15.5, 15.5),
		mat_plaza_border
	)
	_add_cylinder_zone(
		root, "PlazaOuterStoneTerrace",
		Vector3(PLAZA_CENTER.x, 0.114, PLAZA_CENTER.y), Vector2(12.0, 12.0),
		mat_plaza_border
	)
	_add_cylinder_zone(
		root, "PlazaMainStoneCourt",
		Vector3(PLAZA_CENTER.x, 0.120, PLAZA_CENTER.y), Vector2(10.8, 10.8),
		mat_plaza
	)
	_add_cylinder_zone(
		root, "PlazaInnerDarkStoneRing",
		Vector3(PLAZA_CENTER.x, 0.126, PLAZA_CENTER.y), Vector2(7.0, 7.0),
		mat_plaza_border
	)
	_add_cylinder_zone(
		root, "PlazaCenterpieceSocketCap_12mWorld",
		Vector3(PLAZA_CENTER.x, 0.132, PLAZA_CENTER.y), Vector2(3.0, 3.0),
		mat_plaza
	)
	_add_plaza_ring(
		root, "PlazaNavigationLightRing",
		Vector3(PLAZA_CENTER.x, 0.164, PLAZA_CENTER.y), 6.52, 6.72,
		mat_plaza_inlay
	)
	_add_plaza_ring(
		root, "PlazaCenterpieceLightRing",
		Vector3(PLAZA_CENTER.x, 0.166, PLAZA_CENTER.y), 3.04, 3.20,
		mat_plaza_inlay
	)

	var socket := Marker3D.new()
	socket.name = "ARC04_NeonToriiPortalSocket_12m"
	socket.position = Vector3(PLAZA_CENTER.x, 0.18, PLAZA_CENTER.y)
	socket.set_meta("asset_id", "ARC04_NeonToriiPortal")
	socket.set_meta("category", "architecture")
	socket.set_meta("status", "installed_neon_torii_portal")
	socket.set_meta("base_diameter_world_m", 12.0)
	socket.set_meta("target_height_world_m", Vector2(6.0, 8.0))
	root.add_child(socket)
	_install_neon_torii(root)

func _install_neon_torii(parent: Node3D) -> void:
	var uniform_scale := TORII_TARGET_HEIGHT_M / TORII_SOURCE_HEIGHT_M
	# Meshy centered the source around its origin. Raising it by half the target
	# height plants the lowest vertex on the plaza cap instead of burying it.
	var position_value := Vector3(
		PLAZA_CENTER.x,
		0.16 + TORII_TARGET_HEIGHT_M * 0.5,
		PLAZA_CENTER.y
	)
	var torii := _instance_park_asset(
		parent, NeonToriiPortalScene, "ARC04_NeonToriiPortal",
		position_value, TORII_YAW_DEGREES, Vector3.ONE * uniform_scale
	)
	if torii == null:
		return
	_configure_neon_torii_materials(torii)

	# Two narrow pillar colliders preserve the walk-through opening. Their
	# authored offsets compensate for the doubled park root scale.
	var yaw_radians := deg_to_rad(TORII_YAW_DEGREES)
	var local_x_axis := Vector2(cos(yaw_radians), -sin(yaw_radians))
	for side_index: int in [-1, 1]:
		var offset_2d := local_x_axis * 2.05 * float(side_index)
		_add_invisible_collision_box(
			parent, "NeonToriiPillarCollision_%s" % ("Left" if side_index < 0 else "Right"),
			position_value + Vector3(offset_2d.x,0.0,offset_2d.y),
			Vector3(1.25,6.8,1.65), TORII_YAW_DEGREES
		)
	_add_torii_night_lighting(parent)

func _configure_neon_torii_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
				var source_material := mesh_instance.mesh.surface_get_material(surface_index)
				if source_material is StandardMaterial3D:
					var material := source_material.duplicate() as StandardMaterial3D
					material.resource_local_to_scene = true
					material.metallic = 0.34
					material.roughness = 0.45
					material.emission_enabled = true
					material.emission = Color("#54cfea")
					material.emission_texture = material.albedo_texture
					material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
					material.emission_energy_multiplier = 0.0
					mesh_instance.set_surface_override_material(surface_index, material)
					plaza_emissive_materials.append(material)
	for child: Node in node.get_children():
		_configure_neon_torii_materials(child)

func _add_torii_night_lighting(parent: Node3D) -> void:
	var portal_light := OmniLight3D.new()
	portal_light.name = "NeonToriiPortalGlow"
	portal_light.position = Vector3(PLAZA_CENTER.x-1.65,4.0,PLAZA_CENTER.y+1.5)
	portal_light.light_color = Color("#5bdcff")
	portal_light.light_energy = 1.20
	portal_light.omni_range = 8.5
	portal_light.shadow_enabled = false
	portal_light.light_volumetric_fog_energy = 1.15
	parent.add_child(portal_light)
	portal_light.add_to_group("midori_night_effect")

	var threshold_light := OmniLight3D.new()
	threshold_light.name = "NeonToriiThresholdGlow"
	threshold_light.position = Vector3(PLAZA_CENTER.x,0.55,PLAZA_CENTER.y)
	threshold_light.light_color = Color("#42b9d4")
	threshold_light.light_energy = 0.54
	threshold_light.omni_range = 5.0
	threshold_light.shadow_enabled = false
	threshold_light.light_volumetric_fog_energy = 0.72
	parent.add_child(threshold_light)
	threshold_light.add_to_group("midori_night_effect")

func _add_plaza_ring(
	parent: Node3D,
	node_name: String,
	center: Vector3,
	inner_radius: float,
	outer_radius: float,
	material: Material
) -> void:
	var ring := MeshInstance3D.new()
	ring.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 64
	mesh.ring_segments = 8
	ring.mesh = mesh
	ring.position = center
	ring.material_override = material
	parent.add_child(ring)

func _build_artwork_assets(parent: Node3D) -> void:
	var structures := Node3D.new()
	structures.name = "ArtworkMatchedStructures"
	parent.add_child(structures)

	_instance_park_asset(
		structures, ViewingDeckScene, "WAT01_EastViewingDeck",
		Vector3(80.0, 1.75, -15.0), 90.0, Vector3.ONE * 13.0
	)
	_add_invisible_collision_box(
		structures, "WAT01_DeckCollision",
		Vector3(80.0, 1.55, -15.0), Vector3(12.5, 0.45, 11.5), 90.0
	)

	_build_mossy_shoreline_cover(parent)
	_build_waterside_grasses(parent)

func _build_mossy_shoreline_cover(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "MossyShorelineCover_9"
	parent.add_child(root)
	var shore_indices: Array[int] = [0,3,6,9,12,15,18,22,26]
	for index: int in range(shore_indices.size()):
		var shore_index := shore_indices[index]
		var shore_point := LAKE_SHORELINE[shore_index]
		var outward := _lake_shore_outward(shore_index)
		var tangent := _lake_shore_tangent(shore_index)
		var scale_value := 3.6 + float((index * 7) % 6) * 0.35
		var position_value := Vector3(
			shore_point.x + outward.x * (1.65 + float(index % 3) * 0.32),
			0.96 + float(index % 4) * 0.11,
			shore_point.y + outward.y * (1.65 + float(index % 3) * 0.32)
		)
		var rotation_value := rad_to_deg(atan2(tangent.x, tangent.y)) + float((index * 37) % 29 - 14)
		_instance_park_asset(
			root, MossyBoulderScene, "VEG07_MossyBoulders_%02d" % (index + 1),
			position_value, rotation_value, Vector3.ONE * scale_value
		)
		_add_invisible_collision_box(
			root, "VEG07_Collision_%02d" % (index + 1),
			position_value, Vector3(scale_value * 0.78, scale_value * 0.42, scale_value * 0.58), rotation_value
		)

func _build_waterside_grasses(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "WatersideVegetation_36Reed_9DenseGrass"
	parent.add_child(root)
	var natural_shore_indices: Array[int] = [0,1,3,4,6,7,9,10,12,13,15,16,18,19,21,22,24,26]
	var edge_points: Array[Vector3] = []
	var edge_tangents: Array[Vector2] = []
	for shore_index: int in natural_shore_indices:
		var shore_point := LAKE_SHORELINE[shore_index]
		var outward := _lake_shore_outward(shore_index)
		var tangent := _lake_shore_tangent(shore_index)
		edge_points.append(Vector3(
			shore_point.x + outward.x * 0.75, 0.55,
			shore_point.y + outward.y * 0.75
		))
		edge_tangents.append(tangent)
	for index: int in range(edge_points.size()):
		for variant: int in range(2):
			var tangent := edge_tangents[index]
			var outward := _lake_shore_outward(natural_shore_indices[index])
			var lateral := -0.55 if variant == 0 else 0.62
			var offset_2d := outward * (0.42 + float(variant) * 0.34) + tangent * lateral
			var offset := Vector3(offset_2d.x, 0.0, offset_2d.y)
			var source := FountainGrassScene if (index + variant) % 2 == 0 else MeadowGrassScene
			var scale_value := 1.00 + float((index + variant) % 5) * 0.10
			var plant_position := _clear_waterside_bridge_position(edge_points[index]+offset,outward,tangent)
			_instance_park_asset(
				root, source, "VEG06_WatersideGrass_%02d_%d" % [index + 1, variant + 1],
				plant_position, fmod(float(index * 97 + variant * 43), 360.0), Vector3.ONE * scale_value
			)

	if dense_grass_prototypes.is_empty():
		return
	var dense_patch_indices: Array[int] = [0, 2, 4, 6, 8, 10, 12, 14, 16]
	# Keep the very dense Grass1 variant out of the open shoreline. Its layered
	# blades are reserved for a few reduced-scale deep-woodland accents.
	var dense_variant_sequence: Array[int] = [1, 1, 2, 1, 2, 1, 1, 2, 1]
	for patch_index: int in range(dense_patch_indices.size()):
		var edge_index: int = dense_patch_indices[patch_index]
		var edge_position: Vector3 = edge_points[edge_index]
		var shore_outward := _lake_shore_outward(natural_shore_indices[edge_index])
		var landward := Vector3(shore_outward.x, 0.0, shore_outward.y)
		var dense_position := edge_position + landward * (1.15 + float(patch_index % 3) * 0.35)
		dense_position.y = 0.12
		dense_position = _clear_waterside_bridge_position(dense_position,shore_outward,edge_tangents[edge_index])
		var prototype_index: int = dense_variant_sequence[patch_index] % dense_grass_prototypes.size()
		var prototype: Node3D = dense_grass_prototypes[prototype_index]
		var patch := prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
		patch.name = "VEG06_DenseGrass_%02d" % (patch_index + 1)
		patch.position = dense_position
		patch.rotation_degrees.y = fmod(float(patch_index * 137 + 23), 360.0)
		patch.scale = Vector3.ONE * (0.86 + float(patch_index % 4) * 0.07)
		_preserve_asset_world_scale(patch)
		root.add_child(patch)
		_configure_vegetation_visibility(patch)

func _clear_waterside_bridge_position(position_value: Vector3, outward: Vector2, tangent: Vector2) -> Vector3:
	var original := Vector2(position_value.x,position_value.z)
	if _waterside_bridge_clear(original):
		return position_value
	for step: int in range(1,25):
		for direction: float in [1.0,-1.0]:
			var candidate := original+tangent*float(step)*0.65*direction+outward*float(step)*0.12
			if _waterside_bridge_clear(candidate) and not Geometry2D.is_point_in_polygon(candidate,PackedVector2Array(lake_contour)):
				return Vector3(candidate.x,position_value.y,candidate.y)
	push_warning("Midori waterside plant has no clear bridge flank")
	return position_value

func _waterside_bridge_clear(point: Vector2) -> bool:
	var world := point*LAYOUT_SCALE
	for offset: Vector2 in [Vector2.ZERO,Vector2(1.4,0),Vector2(-1.4,0),Vector2(0,1.4),Vector2(0,-1.4),Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
		if is_finite(bridge_surface_height(world+offset)):
			return false
	return true

func _build_prop_placement_plan(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "PlannedPropSockets"
	parent.add_child(root)
	var sockets: Array[Dictionary] = [
		{"id": "ARC01_Pavilion", "category": "architecture", "p": Vector3(76.0, 0.1, -73.0), "yaw": 90.0},
		{"id": "ARC02_MaintenanceRestroom", "category": "architecture", "p": Vector3(-88.0, 0.1, -63.0), "yaw": 0.0},
		{"id": "ARC03_MainEntranceMarker", "category": "architecture", "p": Vector3(0.0, 0.1, 84.0), "yaw": 0.0},
		{"id": "ARC04_NeonToriiPortal", "category": "architecture", "p": Vector3(82.0, 0.18, 68.0), "yaw": TORII_YAW_DEGREES},
		{"id": "ACT01_PlaygroundSet", "category": "activity", "p": Vector3(-72.0, 0.1, 45.0), "yaw": -12.0},
		{"id": "ACT02_BasketballHoopWest", "category": "activity", "p": Vector3(-92.0, 0.1, -43.0), "yaw": 90.0},
		{"id": "ACT02_BasketballHoopEast", "category": "activity", "p": Vector3(-48.0, 0.1, -43.0), "yaw": -90.0},
		{"id": "ACT03_TennisNet", "category": "activity", "p": Vector3(-70.0, 0.1, -43.0), "yaw": 0.0},
		{"id": "FUR06_MainInformationBoard", "category": "furniture", "p": Vector3(-7.0, 0.1, 79.0), "yaw": 0.0},
		{"id": "FUR08_DrinkingFountain", "category": "furniture", "p": Vector3(-54.0, 0.1, 57.0), "yaw": 90.0},
		{"id": "FUR09_BicycleRack", "category": "furniture", "p": Vector3(74.0, 0.1, 78.0), "yaw": 0.0},
		{"id": "FUR10_VendingMachine", "category": "furniture", "p": Vector3(88.0, 0.1, 76.0), "yaw": 180.0},
		{"id": "FUR13_EmergencyPoint", "category": "furniture", "p": Vector3(88.0, 0.1, -23.0), "yaw": -90.0},
		{"id": "GAM01_PlazaPlanterA", "category": "cover", "p": Vector3(70.0, 0.1, 78.0), "yaw": 15.0},
		{"id": "GAM01_PlazaPlanterB", "category": "cover", "p": Vector3(95.0, 0.1, 77.0), "yaw": -12.0},
		{"id": "GAM03_UtilityCabinet", "category": "cover", "p": Vector3(-96.0, 0.1, -68.0), "yaw": 90.0},
		{"id": "GAM04_SecurityCamera", "category": "security", "p": Vector3(87.0, 0.1, 66.0), "yaw": 215.0},
		{"id": "GAMEPLAY_Loot_Pavilion", "category": "gameplay", "p": Vector3(78.0, 0.1, -72.0), "yaw": 0.0},
		{"id": "GAMEPLAY_Loot_Playground", "category": "gameplay", "p": Vector3(-67.0, 0.1, 51.0), "yaw": 0.0},
		{"id": "GAMEPLAY_Loot_Deck", "category": "gameplay", "p": Vector3(80.0, 0.1, -15.0), "yaw": 0.0},
		{"id": "GAMEPLAY_Extraction_Plaza", "category": "gameplay", "p": Vector3(94.0, 0.1, 73.0), "yaw": 0.0},
	]
	var bench_points: Array[Vector3] = [
		Vector3(-49.0, 0.1, 58.0), Vector3(-17.0, 0.1, 46.0), Vector3(36.0, 0.1, 54.0),
		Vector3(94.0, 0.1, 45.0), Vector3(86.0, 0.1, -50.0), Vector3(24.0, 0.1, -75.0),
		Vector3(-20.0, 0.1, -75.0), Vector3(-91.0, 0.1, 31.0), Vector3(73.0, 0.1, 64.0),
	]
	for index: int in range(bench_points.size()):
		sockets.append({"id": "FUR01_Bench_%02d" % (index + 1), "category": "furniture", "p": bench_points[index], "yaw": fmod(float(index) * 90.0, 360.0)})

	var lamp_points: Array[Vector3] = [
		Vector3(-78.0, 0.1, 66.0), Vector3(-17.0, 0.1, 46.0), Vector3(36.0, 0.1, 54.0),
		Vector3(86.0, 0.1, 56.0), Vector3(86.0, 0.1, -45.0), Vector3(24.0, 0.1, -72.0),
		Vector3(-33.0, 0.1, -50.0), Vector3(-39.0, 0.1, -4.0), Vector3(99.0, 0.1, 24.0),
		Vector3(-98.0, 0.1, 20.0), Vector3(-98.0, 0.1, -27.0), Vector3(76.0, 0.1, -73.0),
	]
	for index: int in range(lamp_points.size()):
		sockets.append({"id": "FUR04_PathLamp_%02d" % (index + 1), "category": "lighting", "p": lamp_points[index], "yaw": 0.0})

	for socket: Dictionary in sockets:
		var marker := Marker3D.new()
		marker.name = socket["id"]
		marker.position = socket["p"]
		marker.rotation_degrees.y = socket["yaw"]
		marker.set_meta("asset_id", socket["id"])
		marker.set_meta("category", socket["category"])
		root.add_child(marker)
		if SHOW_PLANNING_LABELS:
			_add_visual_box(marker, "PlanningMarker", Vector3(0.0, 0.25, 0.0), Vector3(0.35, 0.5, 0.35), mat_plan_marker)
			_add_zone_label(marker, socket["id"], Vector3(0.0, 0.7, 0.0), Color("#8ee6ff"))

func _instance_park_asset(parent: Node3D, source: PackedScene, node_name: String, position_value: Vector3, yaw_degrees: float, scale_value: Vector3) -> Node3D:
	var instance := source.instantiate() as Node3D
	if instance == null:
		push_warning("Midori Park asset could not be instantiated: %s" % node_name)
		return null
	instance.name = node_name
	instance.position = position_value
	instance.rotation_degrees.y = yaw_degrees
	instance.scale = scale_value
	_preserve_asset_world_scale(instance)
	parent.add_child(instance)
	_configure_park_asset_visibility(instance)
	return instance

func _set_asset_shadow_casting(node: Node, enabled: bool) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_set_asset_shadow_casting(child, enabled)

func _naturalize_pitch_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.mesh.surface_get_material(surface_index)
			if source_material is StandardMaterial3D:
				var material := source_material.duplicate() as StandardMaterial3D
				# The supplied all-in-one atlas imports as fully metallic, causing
				# artificial bright turf and dark, patchy-looking goal/fence pieces.
				material.metallic = 0.0
				material.metallic_texture = null
				material.roughness = 0.90
				material.roughness_texture = null
				material.metallic_specular = 0.18
				mesh_instance.set_surface_override_material(surface_index, material)
	for child: Node in node.get_children():
		_naturalize_pitch_material(child)

var _stone_detail_shader: Shader

## Wraps the supplied boulder texture in a stone shader: fine procedural grit
## in the normals, darker crevices where faces turn away from the sky, and a
## moss skin on the upward faces so the rock sits in the lawn.
func _apply_stone_detail(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			for surface_index: int in range(mesh_node.mesh.get_surface_count()):
				var source := mesh_node.get_active_material(surface_index)
				if source is StandardMaterial3D and (source as StandardMaterial3D).albedo_texture != null:
					mesh_node.set_surface_override_material(surface_index, _stone_detail_material(source as StandardMaterial3D))
	for child: Node in node.get_children():
		_apply_stone_detail(child)

func _stone_detail_material(source: StandardMaterial3D) -> ShaderMaterial:
	if _stone_detail_shader == null:
		_stone_detail_shader = Shader.new()
		_stone_detail_shader.code = """
shader_type spatial;
render_mode cull_back, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float grit_scale = 9.0;
varying vec3 world_pos;
varying vec3 world_normal;
float hsh(vec3 p){ return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float nz(vec3 p){ vec3 c = floor(p); vec3 f = fract(p); vec3 u = f*f*(3.0-2.0*f);
	return mix(mix(mix(hsh(c), hsh(c+vec3(1,0,0)), u.x), mix(hsh(c+vec3(0,1,0)), hsh(c+vec3(1,1,0)), u.x), u.y),
		mix(mix(hsh(c+vec3(0,0,1)), hsh(c+vec3(1,0,1)), u.x), mix(hsh(c+vec3(0,1,1)), hsh(c+vec3(1,1,1)), u.x), u.y), u.z); }
void vertex(){
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment(){
	vec3 tex = texture(albedo_tex, UV).rgb;
	float luma = dot(tex, vec3(0.2126, 0.7152, 0.0722));
	// Pull the baked texture toward a cooler grey stone and keep its variation.
	vec3 stone = mix(tex, luma * vec3(0.78, 0.80, 0.82), 0.55);
	float grit = nz(world_pos * grit_scale) * 0.55 + nz(world_pos * grit_scale * 3.1) * 0.3 + nz(world_pos * grit_scale * 9.0) * 0.15;
	stone *= mix(0.82, 1.12, grit);
	// Crevices: faces that turn down or sideways read darker and damp.
	float up = clamp(world_normal.y, 0.0, 1.0);
	stone *= mix(0.62, 1.0, smoothstep(-0.2, 0.55, world_normal.y));
	// Moss skin on the top faces, broken up by noise so it is patchy.
	float moss_mask = smoothstep(0.45, 0.85, up) * smoothstep(0.35, 0.7, nz(world_pos * 2.3 + vec3(5.0)));
	vec3 moss = vec3(0.30, 0.42, 0.16) * mix(0.8, 1.2, nz(world_pos * 11.0));
	ALBEDO = mix(stone, moss, moss_mask * 0.85);
	// Procedural grit normal: derivative of the noise field, tangent-space-free.
	float e = 0.015;
	float gx = nz((world_pos + vec3(e,0,0)) * grit_scale * 3.1) - nz((world_pos - vec3(e,0,0)) * grit_scale * 3.1);
	float gy = nz((world_pos + vec3(0,e,0)) * grit_scale * 3.1) - nz((world_pos - vec3(0,e,0)) * grit_scale * 3.1);
	float gz = nz((world_pos + vec3(0,0,e)) * grit_scale * 3.1) - nz((world_pos - vec3(0,0,e)) * grit_scale * 3.1);
	vec3 bumped = normalize(world_normal - vec3(gx, gy, gz) * 2.4 * (1.0 - moss_mask * 0.7));
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);
	ROUGHNESS = mix(0.86, 0.96, moss_mask);
	SPECULAR = 0.25;
	METALLIC = 0.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = _stone_detail_shader
	material.resource_name = "SHINRAI_StoneDetail"
	material.set_shader_parameter("albedo_tex", source.albedo_texture)
	return material

func _configure_park_asset_visibility(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.visibility_range_end = 145.0
	for child: Node in node.get_children():
		_configure_park_asset_visibility(child)

func _add_invisible_collision_box(parent: Node3D, node_name: String, position_value: Vector3, size_value: Vector3, yaw_degrees: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.rotation_degrees.y = yaw_degrees
	body.scale = Vector3(1.0 / LAYOUT_SCALE, 1.0, 1.0 / LAYOUT_SCALE)
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)

func _preserve_asset_world_scale(asset_root: Node3D) -> void:
	asset_root.scale.x /= LAYOUT_SCALE
	asset_root.scale.z /= LAYOUT_SCALE

func _build_scale_ticks(parent: Node3D) -> void:
	for x_value: int in range(-100, 101, 20):
		_add_visual_box(parent, "SouthScaleTick_%d" % x_value, Vector3(float(x_value), 0.18, PARK_HALF.y - 1.0), Vector3(0.28, 0.28, 2.0), mat_entry)
		if x_value % 40 == 0:
			_add_zone_label(parent, "%d m" % x_value, Vector3(float(x_value), 0.75, PARK_HALF.y - 4.5), Color("#fff1ca"))

func _prepare_reference_vegetation() -> void:
	var broadleaf_specs: Array = [
		["Tree EZTree0.Large", 10.1], ["Tree EZTree0.Medium010", 8.3],
		["Tree EZTree0.Medium011", 7.9], ["Tree EZTree1.Large001", 9.6],
		["Tree EZTree1.Medium002", 7.8],
	]
	var pine_specs: Array = [
		["Pine_big_1_LOD1", 11.7], ["Pine_large_2_LOD1", 9.9],
		["Pine_medium_3_LOD1", 8.1],
	]
	var pine_sapling_specs: Array = [
		["Pine_sapling_1_LOD1", 3.0], ["Pine_sapling_2_LOD1", 2.7],
		["Pine_sapling_3_LOD1", 3.2],
	]
	var forest_floor_bush_specs: Array = [
		["Tree EZTree1.Bush006", 0.90],
	]
	var lilac_specs: Array = [
		["Lilac_bush_1_LOD1", 1.65], ["Lilac_bush_2_LOD1", 1.50],
	]
	var dense_grass_specs: Array = [
		["Grass1", 0.95], ["GrassLawnAutumn", 0.72], ["GrassAutumn3", 0.55],
	]
	for spec: Array in broadleaf_specs:
		var prototype := _extract_vegetation_prototype(BroadleafTreePack, spec[0], spec[1])
		if prototype != null:
			broadleaf_prototypes.append(prototype)
	for spec: Array in pine_specs:
		var prototype := _extract_vegetation_prototype(PineTreePack, spec[0], spec[1])
		if prototype != null:
			pine_prototypes.append(prototype)
	for spec: Array in pine_sapling_specs:
		var prototype := _extract_vegetation_prototype(PineTreePack, spec[0], spec[1])
		if prototype != null:
			pine_sapling_prototypes.append(prototype)
	for spec: Array in forest_floor_bush_specs:
		var prototype := _extract_vegetation_prototype(BroadleafTreePack, spec[0], spec[1])
		if prototype != null:
			forest_floor_bush_prototypes.append(prototype)
	for spec: Array in lilac_specs:
		var prototype := _extract_vegetation_prototype(LilacBushPack, spec[0], spec[1])
		if prototype != null:
			lilac_prototypes.append(prototype)
	for spec: Array in dense_grass_specs:
		var prototype := _extract_vegetation_prototype(DenseGrassPack, spec[0], spec[1])
		if prototype != null:
			_naturalize_dense_grass_prototype(prototype)
			dense_grass_prototypes.append(prototype)
	print("Midori reference vegetation: %d broadleaf | %d pine | %d pine sapling | %d floor bush | %d lilac | %d dense grass" % [
		broadleaf_prototypes.size(), pine_prototypes.size(), pine_sapling_prototypes.size(), forest_floor_bush_prototypes.size(), lilac_prototypes.size(), dense_grass_prototypes.size(),
	])
	deadwood_trunk_prototype = _extract_whole_scene_prototype(DeadwoodTrunkScene, "BeechDeadwood")
	hollow_bark_prototype = _extract_whole_scene_prototype(HollowBarkScene, "HeavyHollowBark")
	midnight_fern_prototype = _extract_whole_scene_prototype(MidnightFernScene, "MidnightFern")
	emerald_fountain_grass_prototype = _extract_whole_scene_prototype(EmeraldFountainGrassScene, "EmeraldFountainGrass")
	# The supplied fountain-grass photo is a saturated lime; every later planter
	# reuses this prototype, so tone it once here to a weathered olive.
	_tone_foliage_prototype(emerald_fountain_grass_prototype, Color(0.66, 0.66, 0.5))
	japanese_maple_prototype = _extract_mesh_prototype(JapaneseMapleMesh, "Free3DJapaneseMaple", 6.4)
	neon_park_bench_prototype = _extract_whole_scene_prototype(NeonParkBenchScene, "NeonParkBench")
	futuristic_eco_bench_prototype = _extract_whole_scene_prototype(FuturisticEcoBenchScene, "FuturisticEcoBench")
	emerald_halo_lamp_prototype = _extract_whole_scene_prototype(EmeraldHaloLampScene, "EmeraldHaloLamp")
	_make_lamp_reflective(emerald_halo_lamp_prototype)
	# Meshy exported the straight and junction on the XY plane while the curve
	# arrived on XZ. Normalize all three to the same 3 m-wide, 0.12 m-high kit.
	midori_path_straight_prototype = _prepare_path_module(
		MidoriPathStraightScene, "MidoriPathStraight",
		Vector3(-90.0, 0.0, 0.0), Vector3(6.32, 6.0, 0.875)
	)
	midori_path_curve_prototype = _prepare_path_module(
		MidoriPathCurveScene, "MidoriPathCurve",
		Vector3.ZERO, Vector3(3.90, 1.155, 3.90)
	)
	midori_path_junction_prototype = _prepare_path_module(
		MidoriPathJunctionScene, "MidoriPathJunction",
		Vector3(-90.0, 0.0, 0.0), Vector3(9.0, 9.0, 0.70)
	)
	midori_path_resting_pocket_prototype = _prepare_path_module(
		MidoriPathRestingPocketScene, "MidoriPathRestingPocket",
		Vector3(-90.0, 0.0, 0.0), Vector3(8.03, 8.0, 1.08)
	)

func _prepare_path_module(
	pack: PackedScene,
	prototype_name: String,
	source_rotation_degrees: Vector3,
	source_scale: Vector3
) -> Node3D:
	var source_root := pack.instantiate() as Node3D
	if source_root == null:
		push_warning("Midori path module failed to instantiate: %s" % prototype_name)
		return null
	_clear_vegetation_owner(source_root)
	source_root.rotation_degrees = source_rotation_degrees
	source_root.scale = source_scale

	var prototype := Node3D.new()
	prototype.name = prototype_name
	var content := Node3D.new()
	content.name = "Content"
	prototype.add_child(content)
	content.add_child(source_root)

	var bounds_data := _vegetation_visual_bounds(content)
	if not bounds_data["valid"]:
		prototype.free()
		return null
	var bounds: AABB = bounds_data["bounds"]
	content.position = -Vector3(
		bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y,
		bounds.position.z + bounds.size.z * 0.5
	)
	print("Midori path module %s normalized: %.2f x %.2f x %.2f m" % [
		prototype_name, bounds.size.x, bounds.size.y, bounds.size.z,
	])
	_configure_path_module_visuals(content)
	_add_path_module_collision_shapes(content)
	return prototype

func _configure_path_module_visuals(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.visibility_range_end = 165.0
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.mesh.surface_get_material(surface_index)
			if source_material is BaseMaterial3D:
				var base_material := source_material as BaseMaterial3D
				if base_material.albedo_texture != null and base_material.normal_texture != null:
					var material := ShaderMaterial.new()
					material.shader = modular_path_shader
					material.set_shader_parameter("source_albedo", base_material.albedo_texture)
					material.set_shader_parameter("source_normal", base_material.normal_texture)
					if source_material is ORMMaterial3D:
						material.set_shader_parameter("source_orm", (source_material as ORMMaterial3D).orm_texture)
					else:
						material.set_shader_parameter("source_orm", base_material.roughness_texture)
					material.set_shader_parameter("night_emission", 1.0 if is_night_mode else 0.0)
					mesh_instance.set_surface_override_material(surface_index, material)
					modular_path_emissive_materials.append(material)
	for child: Node in node.get_children():
		_configure_path_module_visuals(child)

func _add_path_module_collision_shapes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var shape := mesh_instance.mesh.create_trimesh_shape()
			if shape != null:
				var body := StaticBody3D.new()
				body.name = "WalkableCollision"
				var collision := CollisionShape3D.new()
				collision.shape = shape
				body.add_child(collision)
				mesh_instance.add_child(body)
	for child: Node in node.get_children():
		if not (child is StaticBody3D):
			_add_path_module_collision_shapes(child)

func _extract_vegetation_prototype(pack: PackedScene, source_name: String, target_height: float) -> Node3D:
	var source_root := pack.instantiate() as Node3D
	if source_root == null:
		push_warning("Midori vegetation pack failed to instantiate: %s" % source_name)
		return null
	var source_node := _find_vegetation_source(source_root, source_name)
	if source_node == null:
		push_warning("Midori vegetation model not found: %s" % source_name)
		source_root.free()
		return null

	var retained_transform := _vegetation_relative_transform(source_node, source_root)
	var prototype := Node3D.new()
	prototype.name = source_name.replace(" ", "_").replace(".", "_")
	var content := Node3D.new()
	content.name = "Content"
	prototype.add_child(content)
	_clear_vegetation_owner(source_node)
	source_node.reparent(content, false)
	source_node.transform = retained_transform
	source_root.free()

	var bounds_data := _vegetation_visual_bounds(content)
	if not bounds_data["valid"]:
		prototype.free()
		return null
	var bounds: AABB = bounds_data["bounds"]
	var height_scale := target_height / maxf(bounds.size.y, 0.001)
	content.scale = Vector3.ONE * height_scale
	content.position = -Vector3(
		bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y,
		bounds.position.z + bounds.size.z * 0.5
	) * height_scale
	_configure_vegetation_visibility(content)
	return prototype

func _extract_whole_scene_prototype(pack: PackedScene, prototype_name: String) -> Node3D:
	var source_root := pack.instantiate() as Node3D
	if source_root == null:
		push_warning("Midori deadwood source failed to instantiate: %s" % prototype_name)
		return null
	var prototype := Node3D.new()
	prototype.name = prototype_name
	var content := Node3D.new()
	content.name = "Content"
	prototype.add_child(content)
	_clear_vegetation_owner(source_root)
	content.add_child(source_root)
	var bounds_data := _vegetation_visual_bounds(content)
	if not bounds_data["valid"]:
		prototype.free()
		return null
	var bounds: AABB = bounds_data["bounds"]
	content.position = -Vector3(
		bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y,
		bounds.position.z + bounds.size.z * 0.5
	)
	_configure_vegetation_visibility(content)
	return prototype

func _extract_mesh_prototype(mesh: Mesh, prototype_name: String, target_height: float) -> Node3D:
	if mesh == null:
		return null
	var bounds := mesh.get_aabb()
	if bounds.size.y <= 0.001:
		return null
	var prototype := Node3D.new()
	prototype.name = prototype_name
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = mesh
	var scale_factor := target_height / bounds.size.y
	visual.position = -Vector3(
		bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y,
		bounds.position.z + bounds.size.z * 0.5
	) * scale_factor
	visual.scale = Vector3.ONE * scale_factor
	prototype.add_child(visual)
	_configure_vegetation_visibility(visual)
	return prototype

func _naturalize_dense_grass_prototype(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		# Hundreds of overlapping transparent blades were receiving and casting
		# near-black self-shadows. Keep their texture, but remove that artificial
		# occlusion while preserving ordinary light response.
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.get_active_material(surface_index)
			if source_material is StandardMaterial3D:
				var material := source_material.duplicate() as StandardMaterial3D
				material.ao_texture = null
				material.disable_receive_shadows = true
				material.metallic = 0.0
				material.metallic_specular = 0.15
				material.roughness = 0.94
				material.albedo_color = Color(0.72, 0.74, 0.6, 1.0)
				mesh_instance.set_surface_override_material(surface_index, material)
	for child: Node in node.get_children():
		_naturalize_dense_grass_prototype(child)

## Multiplies every surface's albedo by `tint` on duplicated materials (so a
## shared material is never toned twice) and takes the sheen off the leaves.
## The toned material goes on a duplicated mesh, not an instance override,
## because several planters build MultiMeshes straight from the mesh.
func _tone_foliage_prototype(node: Node, tint: Color) -> void:
	if node == null: return
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh_instance := node as MeshInstance3D
		var mesh := mesh_instance.mesh.duplicate() as Mesh
		for surface_index: int in range(mesh.get_surface_count()):
			var source_material := mesh_instance.get_active_material(surface_index)
			if source_material is StandardMaterial3D:
				var material := source_material.duplicate() as StandardMaterial3D
				material.albedo_color = material.albedo_color * tint
				material.roughness_texture = null
				material.roughness = 0.88
				material.metallic = 0.0
				material.metallic_specular = 0.2
				mesh.surface_set_material(surface_index, material)
				mesh_instance.set_surface_override_material(surface_index, null)
		mesh_instance.mesh = mesh
	for child: Node in node.get_children():
		_tone_foliage_prototype(child, tint)

func _make_lamp_reflective(node: Node) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.mesh.surface_get_material(surface_index)
			if source_material is StandardMaterial3D:
				var material := source_material.duplicate() as StandardMaterial3D
				material.roughness = 0.18
				material.metallic_specular = 0.85
				material.emission_enabled = true
				material.emission = Color("#6be5ff")
				material.emission_texture = material.albedo_texture
				material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				material.emission_energy_multiplier = 1.8 if is_night_mode else 0.0
				mesh_instance.set_surface_override_material(surface_index, material)
				lamp_emissive_materials.append(material)
	for child: Node in node.get_children():
		_make_lamp_reflective(child)

func _find_vegetation_source(root: Node, source_name: String) -> Node3D:
	var wanted := _normalized_vegetation_name(source_name)
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is Node3D and _normalized_vegetation_name(str(current.name)) == wanted:
			return current as Node3D
		for child: Node in current.get_children():
			pending.append(child)
	return null

func _normalized_vegetation_name(value: String) -> String:
	return value.to_lower().replace(" ", "").replace(".", "").replace("_", "").replace("-", "")

func _clear_vegetation_owner(node: Node) -> void:
	node.owner = null
	for child: Node in node.get_children():
		_clear_vegetation_owner(child)

func _vegetation_relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent_node := node.get_parent()
	while parent_node != null:
		if parent_node is Node3D:
			result = (parent_node as Node3D).transform * result
		if parent_node == ancestor:
			break
		parent_node = parent_node.get_parent()
	return result

func _vegetation_visual_bounds(root: Node3D) -> Dictionary:
	var combined := AABB()
	var has_bounds := false
	var pending: Array[Dictionary] = [{"node": root, "transform": Transform3D.IDENTITY}]
	while not pending.is_empty():
		var entry: Dictionary = pending.pop_back()
		var current: Node = entry["node"]
		var current_transform: Transform3D = entry["transform"]
		if current is MeshInstance3D:
			var mesh_instance := current as MeshInstance3D
			if mesh_instance.mesh != null:
				var mesh_bounds: AABB = current_transform * mesh_instance.get_aabb()
				combined = mesh_bounds if not has_bounds else combined.merge(mesh_bounds)
				has_bounds = true
		for child: Node in current.get_children():
			var child_transform := current_transform
			if child is Node3D:
				child_transform = current_transform * (child as Node3D).transform
			pending.append({"node": child, "transform": child_transform})
	return {"valid": has_bounds, "bounds": combined}

func _add_reference_plant(
	parent: Node3D,
	prototypes: Array[Node3D],
	position_value: Vector3,
	scale_value: float,
	serial: int,
	node_prefix: String
) -> void:
	if prototypes.is_empty():
		return
	var instance := prototypes[posmod(serial, prototypes.size())].duplicate() as Node3D
	if instance == null:
		return
	instance.name = "%s_%03d" % [node_prefix, serial]
	instance.position = position_value
	if node_prefix.begins_with("ReferenceBroadleaf") or node_prefix.begins_with("ReferencePine") or node_prefix.begins_with("MicroGrove") or node_prefix.begins_with("MainlandPineSapling"):
		# Extracted prototypes already have their visual base at local Y=0. Settle
		# mainland trunks slightly into the lawn instead of floating 8–14 cm.
		instance.position.y = -0.035
	if node_prefix.begins_with("ReferenceLilacMass") or node_prefix.begins_with("MixedTreeGapBush"):
		# These mainland prototypes have a normalized base at Y=0.
		instance.position.y = -0.015
	instance.rotation_degrees.y = fmod(float(serial) * 137.507, 360.0)
	var is_tree := node_prefix.begins_with("ReferenceBroadleaf") or node_prefix.begins_with("ReferencePine") or node_prefix.begins_with("MicroGrove") or node_prefix.begins_with("MainlandPineSapling") or node_prefix == "IslandTree"
	if is_tree:
		# Deterministic per-tree variation so the same prototype never reads as
		# an identical copy: size spread, a slight lean, and non-uniform crown.
		var h := float(posmod(serial * 7919, 1000)) / 1000.0
		var h2 := float(posmod(serial * 104729, 1000)) / 1000.0
		var size_jitter := lerpf(0.86, 1.16, h)
		var crown_jitter := lerpf(0.94, 1.08, h2)
		instance.scale = Vector3(scale_value * size_jitter * crown_jitter, scale_value * size_jitter, scale_value * size_jitter / crown_jitter)
		instance.rotation_degrees.x = lerpf(-2.2, 2.2, h2)
		instance.rotation_degrees.z = lerpf(-2.2, 2.2, h)
	else:
		instance.scale = Vector3.ONE * scale_value
	_preserve_asset_world_scale(instance)
	parent.add_child(instance)
	if node_prefix.begins_with("ReferenceBroadleaf") or node_prefix.begins_with("ReferencePine") or node_prefix.begins_with("MicroGrove") or node_prefix.begins_with("MainlandPineSapling") or node_prefix == "IslandTree":
		_occupied_tree_crowns[Vector2(position_value.x, position_value.z)] = _tree_crown_radius(prototypes[posmod(serial, prototypes.size())], scale_value)

func _tree_crown_radius(prototype: Node3D, size_multiplier: float = 1.0) -> float:
	var key := prototype.get_instance_id()
	if not _tree_crown_radius_cache.has(key):
		var radius_squared := 0.0
		# Measure supplied vertices, not empty corners of a rectangular bound.
		# Cache once per prototype; the resulting radius is valid at every yaw.
		var pending: Array[Dictionary] = [{"node": prototype, "transform": Transform3D.IDENTITY}]
		while not pending.is_empty():
			var entry: Dictionary = pending.pop_back()
			var node: Node = entry["node"]
			var transform_value: Transform3D = entry["transform"]
			if node is MeshInstance3D and node.mesh != null:
				for surface: int in range(node.mesh.get_surface_count()):
					var vertices: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
					for vertex: Vector3 in vertices:
						var point := transform_value * vertex
						radius_squared = maxf(radius_squared, Vector2(point.x, point.z).length_squared())
			for child: Node in node.get_children():
				var child_transform := transform_value
				if child is Node3D:
					child_transform *= child.transform
				pending.append({"node": child, "transform": child_transform})
		_tree_crown_radius_cache[key] = sqrt(radius_squared)
	return float(_tree_crown_radius_cache[key]) * size_multiplier

func _is_tree_canopy_spaced(position_value: Vector3, radius: float) -> bool:
	var point := Vector2(position_value.x, position_value.z)
	# Keep the nine existing gameplay cover clearings available while groves
	# spread locally. These are the accepted positions before this foliage pass.
	for cover_point: Vector2 in TREE_COVER_CLEARINGS:
		if point.distance_to(cover_point) < 4.05:
			return false
	for occupied: Vector2 in _occupied_tree_crowns:
		var distance_m := point.distance_to(occupied) * LAYOUT_SCALE
		# Leaf tips may mingle in a thick tree line; protect the inner crowns
		# against deep interpenetration rather than isolating every whole canopy.
		if distance_m < (radius + float(_occupied_tree_crowns[occupied])) * 0.72 + 0.20:
			return false
	return true

func _find_canopy_position(original: Vector3, radius: float, serial: int) -> Dictionary:
	# Retain authored grove neighbourhoods and all existing land/path masks.
	for offset: float in [0.0, 2.0, 4.0, 6.0, 9.0, 12.0]:
		for step: int in range(1 if offset == 0.0 else 20):
			var angle := TAU * float(posmod(step * 7 + serial, 20)) / 20.0
			var candidate := original + Vector3(cos(angle), 0.0, sin(angle)) * offset
			if _is_vegetation_clear(candidate, 3.2) and _is_tree_spaced(candidate, MATURE_TREE_MIN_SPACING_M) and _is_tree_canopy_spaced(candidate, radius):
				return {"found": true, "position": candidate}
	return {"found": false, "position": original}


func _add_reference_tree_cluster(
	parent: Node3D,
	center: Vector2,
	radius_value: float,
	count: int,
	serial_offset: int,
	uniform_mature_spacing: bool = false,
	pine_stride: int = 9
) -> void:
	count *= int(LAYOUT_SCALE * LAYOUT_SCALE)
	var placed := 0
	var attempt := 0
	while placed < count and attempt < count * 8:
		var radial_t := sqrt((float(attempt % count) + 0.42) / float(count))
		var angle := float(attempt) * 2.399963 + float(serial_offset) * 0.31
		# Spread crowded grove candidates locally before leaving out trees that
		# cannot fit; never extend a grove more than twelve world metres.
		var search_radius := radius_value + minf(float(attempt) / float(count) * 0.9, 6.0)
		var position_value := Vector3(
			center.x + cos(angle) * search_radius * radial_t,
			0.14,
			center.y + sin(angle) * search_radius * radial_t * 0.72
		)
		attempt += 1
		if not _is_vegetation_clear(position_value, 3.2):
			continue
		var serial := serial_offset * 100 + placed
		var scale_value := 0.82 + 0.055 * float(serial % 6)
		var safe_pine_stride := maxi(pine_stride, 3)
		var is_skinny_tree := serial % safe_pine_stride == 2
		var crown_prototypes: Array[Node3D] = pine_prototypes if is_skinny_tree else broadleaf_prototypes
		var crown_radius := _tree_crown_radius(crown_prototypes[posmod(serial, crown_prototypes.size())], scale_value)
		if not _is_tree_canopy_spaced(position_value, crown_radius):
			continue
		var has_tree_spacing := (
			_is_tree_spaced(position_value, MATURE_TREE_MIN_SPACING_M)
			if uniform_mature_spacing
			else _is_tree_spaced_for_type(position_value, is_skinny_tree)
		)
		if not has_tree_spacing:
			continue
		if is_skinny_tree:
			_add_reference_plant(parent, pine_prototypes, position_value, scale_value, serial, "ReferencePine")
		else:
			_add_reference_plant(parent, broadleaf_prototypes, position_value, scale_value, serial, "ReferenceBroadleaf")
		occupied_tree_positions.append(Vector2(position_value.x, position_value.z))
		occupied_tree_is_skinny.append(is_skinny_tree)
		placed += 1

func _is_tree_spaced(position_value: Vector3, minimum_distance: float) -> bool:
	var point := Vector2(position_value.x, position_value.z)
	var minimum_distance_squared := minimum_distance * minimum_distance
	for occupied: Vector2 in occupied_tree_positions:
		if point.distance_squared_to(occupied) < minimum_distance_squared:
			return false
	return true

func _is_tree_spaced_for_type(position_value: Vector3, is_skinny_tree: bool) -> bool:
	var point := Vector2(position_value.x, position_value.z)
	for occupied_index: int in range(occupied_tree_positions.size()):
		var occupied_is_skinny := (
			occupied_tree_is_skinny[occupied_index]
			if occupied_index < occupied_tree_is_skinny.size()
			else false
		)
		var minimum_distance := MATURE_TREE_MIN_SPACING_M
		if is_skinny_tree and occupied_is_skinny:
			minimum_distance = SKINNY_TO_SKINNY_MIN_SPACING_M
		elif is_skinny_tree or occupied_is_skinny:
			minimum_distance = SKINNY_TREE_MIN_SPACING_M
		if point.distance_squared_to(occupied_tree_positions[occupied_index]) < minimum_distance * minimum_distance:
			return false
	return true

func _distance_to_park_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment := b - a
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(a + segment * t)

func _validate_approved_lake_promenade() -> void:
	# The base strip must never become an accidental bridge when the shoreline is
	# revised. Sample the full loop and report the first unsafe centreline point.
	for index: int in range(LAKE_PROMENADE_LOOP.size() - 1):
		var start := LAKE_PROMENADE_LOOP[index]
		var finish := LAKE_PROMENADE_LOOP[index + 1]
		var segment_length := start.distance_to(finish)
		var sample_count := maxi(2, int(ceil(segment_length / 0.5)))
		for sample_index: int in range(sample_count + 1):
			var sample := start.lerp(finish, float(sample_index) / float(sample_count))
			var required_clearance := LAKE_PROMENADE_WIDTH_M * 0.5 + LAKE_PROMENADE_BANK_MARGIN_M
			if _is_point_in_or_near_lake(sample, required_clearance):
				push_warning("Midori lake promenade is too close to water at %s" % sample)
				return

func _validate_plaza_centerpiece_clearance() -> void:
	# No paved route may cross the future 12 m world-space landmark base.
	for route: Array[Vector2] in [PLAZA_ARRIVAL_ROUTE, SOUTH_BRIDGE_APPROACH]:
		for index: int in range(route.size() - 1):
			if _distance_to_park_segment(PLAZA_CENTER, route[index], route[index + 1]) < PLAZA_CENTERPIECE_CLEARANCE_M:
				push_warning("Midori plaza route enters the protected centerpiece socket")
				return

func _lake_shore_tangent(index: int) -> Vector2:
	var previous := LAKE_SHORELINE[(index - 1 + LAKE_SHORELINE.size()) % LAKE_SHORELINE.size()]
	var following := LAKE_SHORELINE[(index + 1) % LAKE_SHORELINE.size()]
	var tangent := following - previous
	return tangent.normalized() if tangent.length_squared() > 0.0001 else Vector2.RIGHT

func _lake_shore_outward(index: int) -> Vector2:
	var centroid := Vector2.ZERO
	for shore_point: Vector2 in LAKE_SHORELINE:
		centroid += shore_point
	centroid /= float(LAKE_SHORELINE.size())
	var current := LAKE_SHORELINE[index]
	var tangent := _lake_shore_tangent(index)
	var outward := Vector2(-tangent.y, tangent.x)
	if (current + outward - centroid).length_squared() < (current - centroid).length_squared():
		outward = -outward
	return outward

## Spatial index over occupied_tree_positions (world metres = position * 2).
## Answers "is any trunk within radius of p" by checking nearby cells only,
## instead of every tree in the park. Rebuilt when the tree list changes.
const TRUNK_GRID_CELL_M := 4.0
var _trunk_grid: Dictionary = {}
var _trunk_grid_count := -1

func invalidate_trunk_index() -> void:
	_trunk_grid_count = -1

func any_trunk_within(p: Vector2, radius: float) -> bool:
	if _trunk_grid_count != occupied_tree_positions.size():
		_trunk_grid.clear()
		for trunk: Vector2 in occupied_tree_positions:
			var w := trunk * 2.0
			var key := Vector2i(floori(w.x / TRUNK_GRID_CELL_M), floori(w.y / TRUNK_GRID_CELL_M))
			if not _trunk_grid.has(key): _trunk_grid[key] = PackedVector2Array()
			(_trunk_grid[key] as PackedVector2Array).append(w)
		_trunk_grid_count = occupied_tree_positions.size()
	var r2 := radius * radius
	var x0 := floori((p.x - radius) / TRUNK_GRID_CELL_M)
	var x1 := floori((p.x + radius) / TRUNK_GRID_CELL_M)
	var y0 := floori((p.y - radius) / TRUNK_GRID_CELL_M)
	var y1 := floori((p.y + radius) / TRUNK_GRID_CELL_M)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var bucket = _trunk_grid.get(Vector2i(cx, cy))
			if bucket == null: continue
			for w: Vector2 in bucket:
				if p.distance_squared_to(w) < r2: return true
	return false

func _is_vegetation_clear(position_value: Vector3, padding: float) -> bool:
	# Clubhouse apron and its connector: reserve in world metres.
	if Rect2(-133,-66,14,18).grow(padding*LAYOUT_SCALE).has_point(Vector2(position_value.x,position_value.z)*LAYOUT_SCALE):
		return false
	var point := Vector2(position_value.x, position_value.z)
	if absf(point.x) > PARK_HALF.x - padding or absf(point.y) > PARK_HALF.y - padding:
		return false
	if _vegetation_clearance_blocked(point, padding):
		return false

	# Keep activity surfaces, plaza, pavilion, and all four entrances open.
	var reserved_rects: Array[Vector4] = _VEGETATION_RESERVED_RECTS
	for rect: Vector4 in reserved_rects:
		if absf(point.x - rect.x) < rect.z + padding and absf(point.y - rect.y) < rect.w + padding:
			return false
	return true

func _vegetation_clearance_blocked(point: Vector2, padding: float) -> bool:
	# Preserve uncommon/invalid inputs through the unmodified original predicates.
	if not point.is_finite() or not is_finite(padding) or padding<0.0 or padding>4.0:
		return _is_point_in_or_near_lake(point,padding) or _is_near_future_bridge_corridor(point,padding) or _is_near_destination_path(point,padding)
	if _vegetation_clearance_cache==null or not _vegetation_clearance_cache.matches_contour(lake_contour):
		_build_vegetation_clearance_cache()
	return _vegetation_clearance_cache.blocked(point,padding)

func _build_vegetation_clearance_cache() -> void:
	var route_specs: Array[Dictionary] = [
		{"points":OUTER_CIRCUIT, "half_width":2.1},
		{"points":SOUTH_ARRIVAL_ROUTE, "half_width":2.2},
		{"points":WEST_DESTINATION_ROUTE, "half_width":2.2},
		{"points":NORTH_ENTRY_ROUTE, "half_width":2.0},
		{"points":EAST_DECK_ROUTE, "half_width":2.0},
		{"points":SPORTS_LINK_ROUTE, "half_width":1.5},
		{"points":PLAYGROUND_LOOP, "half_width":1.35},
		{"points":NORTH_WOODLAND_LOOP, "half_width":1.25},
		{"points":LAKE_PROMENADE_LOOP, "half_width":1.8},
		{"points":PLAZA_ARRIVAL_ROUTE, "half_width":2.0},
		{"points":PLAZA_PAVED_ROUTE, "half_width":2.0},
		{"points":SOUTH_BRIDGE_APPROACH, "half_width":1.6},
		{"points":PAVILION_LINK_ROUTE, "half_width":1.4},
		{"points":VIEWING_DECK_APPROACH_ROUTE, "half_width":1.5},
	]
	var corridors: Array = [
		FUTURE_BRIDGE_WEST,
		FUTURE_BRIDGE_NORTH_EAST,
		FUTURE_BRIDGE_SOUTH,
	]
	_vegetation_clearance_cache=VegetationClearanceCache.new()
	_vegetation_clearance_cache.configure(lake_contour,LAKE_TREE_BUFFER_M,route_specs,corridors)

func _is_near_destination_path(point: Vector2, padding: float) -> bool:
	var route_specs: Array[Dictionary] = [
		{"points":OUTER_CIRCUIT, "half_width":2.1},
		{"points":SOUTH_ARRIVAL_ROUTE, "half_width":2.2},
		{"points":WEST_DESTINATION_ROUTE, "half_width":2.2},
		{"points":NORTH_ENTRY_ROUTE, "half_width":2.0},
		{"points":EAST_DECK_ROUTE, "half_width":2.0},
		{"points":SPORTS_LINK_ROUTE, "half_width":1.5},
		{"points":PLAYGROUND_LOOP, "half_width":1.35},
		{"points":NORTH_WOODLAND_LOOP, "half_width":1.25},
		{"points":LAKE_PROMENADE_LOOP, "half_width":1.8},
		{"points":PLAZA_ARRIVAL_ROUTE, "half_width":2.0},
		{"points":PLAZA_PAVED_ROUTE, "half_width":2.0},
		{"points":SOUTH_BRIDGE_APPROACH, "half_width":1.6},
		{"points":PAVILION_LINK_ROUTE, "half_width":1.4},
		{"points":VIEWING_DECK_APPROACH_ROUTE, "half_width":1.5},
	]
	for spec: Dictionary in route_specs:
		var route: Array[Vector2] = spec["points"]
		var clearance: float = float(spec["half_width"]) + padding
		for index: int in range(route.size() - 1):
			if _distance_to_park_segment(point, route[index], route[index + 1]) < clearance:
				return true
	return false

func _is_point_in_or_near_lake(point: Vector2, padding: float) -> bool:
	if Geometry2D.is_point_in_polygon(point, PackedVector2Array(lake_contour)):
		return true
	var shoreline_clearance := maxf(padding, LAKE_TREE_BUFFER_M)
	for index: int in range(lake_contour.size()):
		var following := (index + 1) % lake_contour.size()
		if _distance_to_park_segment(point, lake_contour[index], lake_contour[following]) < shoreline_clearance:
			return true
	return false

func _is_near_future_bridge_corridor(point: Vector2, padding: float) -> bool:
	var corridors: Array = [
		FUTURE_BRIDGE_WEST,
		FUTURE_BRIDGE_NORTH_EAST,
		FUTURE_BRIDGE_SOUTH,
	]
	for corridor: Array in corridors:
		for index: int in range(corridor.size() - 1):
			if _distance_to_park_segment(point, corridor[index], corridor[index + 1]) < 2.2 + padding:
				return true
	return false

func _build_reference_canopy(parent: Node3D) -> void:
	var canopy_root := Node3D.new()
	canopy_root.name = "ArtworkReferenceCanopy"
	parent.add_child(canopy_root)
	# Dense outer woodland and the internal seams match the aerial reference while
	# preserving the sports field, playground, plaza, promenades, and entrances.
	var clusters: Array[Vector4] = [
		Vector4(-88,-85,6,8),Vector4(-66,-85,7,10),Vector4(-39,-85,7,10),
		Vector4(-10,-85,7,9),Vector4(20,-85,7,9),Vector4(86,-84,6,8),
		Vector4(-105,-58,5,8),Vector4(-105,-28,5,9),Vector4(-105,3,5,9),
		Vector4(-105,39,5,9),Vector4(-105,67,5,8),Vector4(-85,85,6,8),
		Vector4(-58,85,7,9),Vector4(-29,85,7,9),Vector4(4,85,7,8),
		Vector4(88,85,6,7),Vector4(105,58,5,7),Vector4(105,28,5,7),
		Vector4(105,4,5,7),Vector4(105,-42,5,8),Vector4(104,-68,5,7),
		Vector4(-51,-55,6,7),Vector4(-50,-27,6,8),Vector4(-50,1,6,7),
		Vector4(-50,26,6,7),Vector4(-52,58,6,8),Vector4(1,57,8,6),
		Vector4(35,57,8,6),Vector4(81,31,8,6),Vector4(84,-50,8,6),
	]
	for cluster_index: int in range(clusters.size()):
		var cluster := clusters[cluster_index]
		_add_reference_tree_cluster(
			canopy_root, Vector2(cluster.x, cluster.y), cluster.z,
			int(cluster.w), cluster_index
		)

	# Mainland infill groves occupy the large empty lawn panels seen from ground
	# level. These use a 4 m mature-trunk spacing and a more frequent skinny pine
	# to break up the broadleaf rhythm without touching either lake island.
	var mainland_infill_clusters: Array[Vector4] = [
		Vector4(-86,-16,11,9),Vector4(-63,-14,10,8),
		Vector4(-86,17,11,9),Vector4(-63,18,10,8),
		Vector4(-28,61,11,9),Vector4(23,63,11,9),
		Vector4(-18,-66,11,9),Vector4(4,-69,10,8),
		Vector4(-82,-50,12,14),Vector4(-70,-35,12,14),
		Vector4(-30,-51,13,16),Vector4(-28,-18,12,15),
		Vector4(-27,13,12,15),Vector4(-15,37,12,14),
		Vector4(0,-34,11,12),Vector4(3,36,11,12),
		Vector4(91,-30,11,12),Vector4(91,45,11,12),
		Vector4(-91,-3,13,15),Vector4(-78,47,13,15),
		Vector4(-53,-47,12,14),Vector4(-43,40,13,15),
		Vector4(-18,-5,15,19),Vector4(-8,18,13,16),
		Vector4(1,-53,12,14),Vector4(5,53,12,14),
		Vector4(94,2,13,15),Vector4(101,69,12,14),
		# Enclose the pitch clearing with layered edge woodland while its fence,
		# access paths and playable apron remain protected by the clearance mask.
		Vector4(-96,-43,11,12),Vector4(-43,-46,10,11),
		Vector4(-72,-62,9,10),
	]
	for cluster_index: int in range(mainland_infill_clusters.size()):
		var cluster := mainland_infill_clusters[cluster_index]
		_add_reference_tree_cluster(
			canopy_root, Vector2(cluster.x, cluster.y), cluster.z,
			int(cluster.w), 200 + cluster_index, true, 4
		)

	# Four small, hand-authored edge groves interrupt the remaining broad lawn
	# gaps without filling their centres. Uneven points avoid circular procedural
	# silhouettes; each group has exactly one skinny pine and 4 m trunk spacing.
	var mainland_micro_groves: Array = [
		[
			Vector3(-28.2,0.14,-37.0),Vector3(-20.4,0.14,-33.7),
			Vector3(-26.6,0.14,-29.9),Vector3(-26.1,0.14,-33.7),
			Vector3(-20.0,0.14,-37.4),
		],
		[
			Vector3(-4.1,0.14,-46.3),Vector3(-10.5,0.14,-46.7),
			Vector3(-16.9,0.14,-44.7),Vector3(-16.6,0.14,-41.1),
			Vector3(-9.5,0.14,-42.3),
		],
		[
			Vector3(-69.8,0.14,6.0),Vector3(-78.3,0.14,-0.4),
			Vector3(-67.7,0.14,3.2),Vector3(-68.4,0.14,-1.7),
			Vector3(-77.1,0.14,4.1),
		],
		[
			Vector3(88.5,0.14,-12.7),Vector3(88.6,0.14,-18.9),
			Vector3(86.4,0.14,-16.1),
		],
	]
	var micro_grove_pine_indices: Array[int] = [1,3,0,2]
	for grove_index: int in range(mainland_micro_groves.size()):
		_add_authored_mainland_micro_grove(
			canopy_root, mainland_micro_groves[grove_index],
			micro_grove_pine_indices[grove_index], 600 + grove_index
		)
	_build_mainland_pine_saplings(canopy_root)

	# Existing broadleaf and pine assets give the small islands a layered canopy.
	var island_trees: Array[Vector4] = [
		Vector4(43,-3,1.14,0),Vector4(48,-2,0.96,1),
		Vector4(38,-3,0.88,0),Vector4(46,-6,0.80,0),Vector4(49,0,0.76,1),
		Vector4(52,-49,1.02,1),Vector4(40,-48,0.94,0),
		Vector4(49,-49,0.88,0),Vector4(54,-47,0.82,0),Vector4(39,-46,0.76,1),
		Vector4(53,32,1.05,0),Vector4(61,37,0.86,1),
		Vector4(50,31,0.78,1),Vector4(56,32,0.80,1),
		Vector4(63,-2,0.88,1),Vector4(65,-3,0.78,0),
		Vector4(26,-4,0.94,0),Vector4(28,-5,0.72,1),
	]
	for index: int in range(island_trees.size()):
		var item := island_trees[index]
		var island_position := Vector3(item.x, 0.20, item.y)
		var is_skinny_tree := int(item.w) == 1
		if not _is_tree_spaced_for_type(island_position, is_skinny_tree):
			continue
		var prototypes: Array[Node3D] = pine_prototypes if is_skinny_tree else broadleaf_prototypes
		var crown_radius := _tree_crown_radius(prototypes[posmod(800 + index, prototypes.size())], item.z)
		if not _is_tree_canopy_spaced(island_position, crown_radius):
			continue
		_add_reference_plant(
			canopy_root, prototypes, island_position,
			item.z, 800 + index, "IslandTree"
		)
		occupied_tree_positions.append(Vector2(island_position.x, island_position.z))
		occupied_tree_is_skinny.append(is_skinny_tree)
	var island_understory: Array[Vector2] = [
		Vector2(38,-3),Vector2(46,-6),Vector2(48,0),Vector2(42,-7),Vector2(50,-4),
		Vector2(49,-49),Vector2(54,-47),Vector2(39,-47),Vector2(47,-48),Vector2(53,-51),
		Vector2(51,34),Vector2(55,31),Vector2(61,38),Vector2(50,32),Vector2(56,34),
		Vector2(24,-5),Vector2(27,-3),Vector2(62,-3),Vector2(65,-1),
	]
	for index: int in range(island_understory.size()):
		var point := island_understory[index]
		_add_reference_plant(
			canopy_root, forest_floor_bush_prototypes,
			Vector3(point.x, 0.17, point.y), 0.8 + float(index % 3) * 0.1,
			900 + index, "IslandUnderstory"
		)

	var understory_root := Node3D.new()
	understory_root.name = "ArtworkLilacUnderstory"
	parent.add_child(understory_root)
	_add_mixed_tree_pair_shrubs(understory_root)

	# Irregular groups replace the former evenly spaced single-shrub lines. Each
	# mass stays within 5–7 plants and preserves a 1.3 m path-side shoulder.
	var shrub_clusters: Array[Vector4] = [
		Vector4(-82,-84,9,6),Vector4(-50,-84,9,6),Vector4(-17,-84,9,6),
		Vector4(16,-84,9,6),Vector4(78,-83,8,6),Vector4(-106,-48,7,6),
		Vector4(-106,-8,7,6),Vector4(-106,53,7,6),Vector4(-72,84,8,6),
		Vector4(-35,84,8,6),Vector4(3,84,8,6),Vector4(104,48,7,6),
		Vector4(104,8,7,6),Vector4(103,-48,7,6),Vector4(-52,-15,8,6),
		Vector4(-52,20,8,6),Vector4(-54,57,7,5),Vector4(2,56,7,5),
		Vector4(34,56,7,5),Vector4(86,-48,6,5),
		Vector4(-86,-16,12,7),Vector4(-63,-14,11,7),
		Vector4(-86,17,12,7),Vector4(-63,18,11,7),
		Vector4(-28,61,12,7),Vector4(23,63,12,7),
		Vector4(-18,-66,12,7),Vector4(4,-69,11,7),
		Vector4(-91,-48,7,8),Vector4(-47,-44,7,8),
	]
	for cluster_index: int in range(shrub_clusters.size()):
		var cluster := shrub_clusters[cluster_index]
		_add_reference_shrub_cluster(
			understory_root, Vector2(cluster.x, cluster.y), cluster.z,
			int(cluster.w), 1000 + cluster_index * 20
		)
	_build_mainland_groundcover_patches(parent)
	_build_mainland_meadow_transitions(parent)
	_build_forest_floor_bush_pockets(parent)
	_build_midnight_fern_pockets(parent)
	_build_emerald_grass_clusters(parent)

func _build_midnight_fern_pockets(parent: Node3D) -> void:
	if midnight_fern_prototype == null:
		return
	var root := Node3D.new()
	root.name = "MainlandMidnightFernPockets"
	parent.add_child(root)
	var centers: Array[Vector2] = [
		Vector2(-86,-16),Vector2(-63,-14),Vector2(-86,17),Vector2(-63,18),
		Vector2(-28,61),Vector2(23,63),Vector2(-18,-66),Vector2(4,-69),
		Vector2(-26,-34),Vector2(-11,-44),Vector2(-72,3),Vector2(87,-16),
	]
	var serial := 0
	for center_index: int in range(centers.size()):
		var center := centers[center_index]
		for plant_index: int in range(4):
			var angle := float(center_index) * 1.57 + float(plant_index) * 2.33
			var radius_value := 2.6 + float((center_index + plant_index * 2) % 4) * 1.2
			var position_value := Vector3(
				center.x + cos(angle) * radius_value,
				-0.015,
				center.y + sin(angle) * radius_value * 0.70
			)
			if not _is_vegetation_clear(position_value, 0.50):
				continue
			var fern := midnight_fern_prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
			fern.name = "MidnightFern_%03d" % (serial + 1)
			fern.position = position_value
			fern.rotation_degrees.y = fmod(float(serial * 137 + center_index * 29), 360.0)
			fern.scale = Vector3.ONE * (0.42 + float((serial * 3 + center_index) % 6) * 0.055)
			_preserve_asset_world_scale(fern)
			root.add_child(fern)
			serial += 1

func _build_emerald_grass_clusters(parent: Node3D) -> void:
	if emerald_fountain_grass_prototype == null:
		return
	var root := Node3D.new()
	root.name = "MainlandEmeraldGrassClusters"
	parent.add_child(root)
	# Mid-height grass bridges the tiny clumps and knee-height shrubs. Uneven
	# 3–6 plant groups keep the supplied silhouette readable without carpeting
	# the park or repeating a regular scatter pattern.
	var clusters: Array[Vector4] = [
		Vector4(-91,-29,5.2,5),Vector4(-71,-24,4.8,4),
		Vector4(-91,31,5.6,6),Vector4(-65,34,4.4,3),
		Vector4(-36,59,5.0,5),Vector4(13,65,5.4,6),
		Vector4(-28,-66,4.7,4),Vector4(16,-70,5.2,5),
		Vector4(-19,-39,4.5,4),Vector4(84,-27,4.8,5),
		Vector4(-87,-38,4.6,5),Vector4(-52,-46,4.3,4),
	]
	var serial := 0
	for cluster_index: int in range(clusters.size()):
		var cluster := clusters[cluster_index]
		for plant_index: int in range(int(cluster.w)):
			var angle := float(cluster_index) * 1.83 + float(plant_index) * 2.399963
			var radius_value := 0.9 + sqrt(float(plant_index + 1) / cluster.w) * cluster.z
			var position_value := Vector3(
				cluster.x + cos(angle) * radius_value,
				-0.018,
				cluster.y + sin(angle) * radius_value * 0.68
			)
			if not _is_vegetation_clear(position_value, 0.62):
				continue
			var grass := emerald_fountain_grass_prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
			# Instantiation copies come back with the supplied lime material; tone them too.
			_tone_foliage_prototype(grass, Color(0.66, 0.66, 0.5))
			grass.name = "EmeraldFountainGrass_%03d" % (serial + 1)
			grass.position = position_value
			grass.rotation_degrees.y = fmod(float(serial * 137 + cluster_index * 41), 360.0)
			var scale_value := 0.62 + float((serial * 5 + cluster_index) % 7) * 0.043
			grass.scale = Vector3.ONE * scale_value
			_preserve_asset_world_scale(grass)
			root.add_child(grass)
			serial += 1

func _build_forest_floor_bush_pockets(parent: Node3D) -> void:
	if forest_floor_bush_prototypes.is_empty():
		return
	var root := Node3D.new()
	root.name = "MainlandForestFloorBushPockets"
	parent.add_child(root)
	# Low woodland plants sit in uneven five-plant pockets around the main groves.
	# They remain decorative, avoid routes, and never form isolated specimen rows.
	var centers: Array[Vector2] = [
		Vector2(-86,-16),Vector2(-63,-14),Vector2(-86,17),Vector2(-63,18),
		Vector2(-28,61),Vector2(23,63),Vector2(-18,-66),Vector2(4,-69),
		Vector2(-26,-34),Vector2(-11,-44),Vector2(88,-15),Vector2(84,-49),
		Vector2(-88,-43),Vector2(-52,-43),
		Vector2(-82,-50),Vector2(-70,-35),Vector2(-30,-51),Vector2(-27,13),
		Vector2(-15,37),Vector2(0,-34),Vector2(3,36),Vector2(-78,47),
		Vector2(-43,40),Vector2(-18,-5),Vector2(94,2),Vector2(-96,-43),
		Vector2(-43,-46),Vector2(-72,-62),
		Vector2(-88,-85),Vector2(-66,-85),Vector2(-39,-85),Vector2(-10,-85),
		Vector2(-105,-58),Vector2(-105,-28),Vector2(-105,39),Vector2(-85,85),
		Vector2(-58,85),Vector2(-29,85),Vector2(105,28),Vector2(104,-68),
	]
	var serial := 0
	for center_index: int in range(centers.size()):
		var center := centers[center_index]
		for plant_index: int in range(9):
			var angle := float(center_index) * 1.43 + float(plant_index) * 2.17
			var radius_value := 2.1 + float((plant_index * 3 + center_index) % 5) * 1.05
			var position_value := Vector3(
				center.x + cos(angle) * radius_value,
				-0.018,
				center.y + sin(angle) * radius_value * 0.72
			)
			if not _is_vegetation_clear(position_value, 0.55):
				continue
			if not _is_bush_between_trees(position_value):
				continue
			_add_reference_plant(
				root, forest_floor_bush_prototypes, position_value,
				0.86 + float((serial * 5 + center_index) % 6) * 0.05,
				5200 + serial, "ForestFloorBush"
			)
			serial += 1

func _is_bush_between_trees(position_value: Vector3) -> bool:
	var point := Vector2(position_value.x, position_value.z)
	var nearby := 0
	for trunk: Vector2 in occupied_tree_positions:
		var distance_squared := point.distance_squared_to(trunk)
		if distance_squared < 0.75 * 0.75:
			return false
		if distance_squared < 6.0 * 6.0:
			nearby += 1
	return nearby >= 2

func _build_mainland_pine_saplings(parent: Node3D) -> void:
	if pine_sapling_prototypes.is_empty():
		return
	var candidates: Array[Vector2] = [
		Vector2(-94,-31),Vector2(-91,-27),Vector2(-84,-29),Vector2(-76,-25),
		Vector2(-71,-5),Vector2(-67,-2),Vector2(-58,-5),Vector2(-56,-9),
		Vector2(-94,30),Vector2(-90,27),Vector2(-82,29),Vector2(-75,27),
		Vector2(-56,30),Vector2(-51,32),Vector2(-47,28),Vector2(-44,33),
		Vector2(-42,69),Vector2(-38,72),Vector2(-34,68),Vector2(-9,69),
		Vector2(11,71),Vector2(15,74),Vector2(30,70),Vector2(34,68),
		Vector2(-31,-73),Vector2(-27,-70),Vector2(-23,-74),Vector2(-10,-72),
		Vector2(12,-72),Vector2(16,-75),Vector2(22,-71),Vector2(29,-73),
	]
	var placed := 0
	for candidate_index: int in range(candidates.size()):
		if placed >= 16:
			break
		var point := candidates[candidate_index]
		var position_value := Vector3(point.x, 0.08, point.y)
		if not _is_vegetation_clear(position_value, 1.2):
			continue
		if not _is_tree_spaced_for_type(position_value, true):
			continue
		var crown_radius := _tree_crown_radius(pine_sapling_prototypes[posmod(4200 + candidate_index, pine_sapling_prototypes.size())], 0.86 + float((candidate_index * 3) % 5) * 0.045)
		if not _is_tree_canopy_spaced(position_value, crown_radius):
			continue
		_add_reference_plant(
			parent, pine_sapling_prototypes, position_value,
			0.86 + float((candidate_index * 3) % 5) * 0.045,
			4200 + candidate_index, "MainlandPineSapling"
		)
		occupied_tree_positions.append(point)
		occupied_tree_is_skinny.append(true)
		placed += 1

func _add_authored_mainland_micro_grove(
	parent: Node3D,
	positions: Array,
	pine_index: int,
	serial_offset: int
) -> void:
	for point_index: int in range(positions.size()):
		var position_value: Vector3 = positions[point_index]
		if not _is_vegetation_clear(position_value, 3.2):
			var lake_point := Vector2(position_value.x, position_value.z)
			if _is_point_in_or_near_lake(lake_point, 3.2):
				var relocation := _find_lakeside_tree_position(position_value, serial_offset + point_index)
				if not relocation["found"]:
					push_warning("Midori lake tree could not find a clear shoreline position: %s" % position_value)
					continue
				position_value = relocation["position"]
			else:
				var relocation := _find_clear_micro_grove_position(position_value, serial_offset + point_index)
				if not relocation["found"]:
					push_warning("Midori micro-grove point could not find clear ground: %s" % position_value)
					continue
				position_value = relocation["position"]
		if not _is_tree_spaced(position_value, MATURE_TREE_MIN_SPACING_M):
			var relocation := _find_clear_micro_grove_position(position_value, serial_offset + point_index)
			if not relocation["found"]:
				push_warning("Midori micro-grove point is below trunk spacing: %s" % position_value)
				continue
			position_value = relocation["position"]
		var is_skinny_tree := point_index == pine_index
		var prototypes: Array[Node3D] = pine_prototypes if is_skinny_tree else broadleaf_prototypes
		var serial := serial_offset * 100 + point_index
		var scale_value := 0.80 + 0.045 * float((point_index + serial_offset) % 6)
		var crown_radius := _tree_crown_radius(prototypes[posmod(serial, prototypes.size())], scale_value)
		var crown_position := _find_canopy_position(position_value, crown_radius, serial)
		if not crown_position["found"]:
			continue
		position_value = crown_position["position"]
		_add_reference_plant(
			parent, prototypes, position_value, scale_value, serial,
			"MicroGrovePine" if is_skinny_tree else "MicroGroveBroadleaf"
		)
		occupied_tree_positions.append(Vector2(position_value.x, position_value.z))
		occupied_tree_is_skinny.append(is_skinny_tree)

func _find_clear_micro_grove_position(original: Vector3, serial: int, clearance: float = 3.2) -> Dictionary:
	# Keep authored groves near their planned zone while clearing paths and trunks.
	for radius_value: float in [4.0, 7.0, 10.0, 13.0, 16.0, 20.0]:
		for step: int in range(16):
			var angle := TAU * float(posmod(step * 5 + serial, 16)) / 16.0
			var candidate := original + Vector3(cos(angle) * radius_value, 0.0, sin(angle) * radius_value)
			if _is_vegetation_clear(candidate, clearance) and _is_tree_spaced(candidate, MATURE_TREE_MIN_SPACING_M):
				return {"found": true, "position": candidate}
	return {"found": false, "position": original}

func _find_lakeside_tree_position(original: Vector3, serial: int) -> Dictionary:
	var point := Vector2(original.x, original.z)
	var closest := LAKE_SHORELINE[0]
	var closest_edge_index := 0
	var closest_distance_squared := INF
	for index: int in range(LAKE_SHORELINE.size()):
		var start := LAKE_SHORELINE[index]
		var finish := LAKE_SHORELINE[(index + 1) % LAKE_SHORELINE.size()]
		var segment := finish - start
		var length_squared := segment.length_squared()
		if length_squared <= 0.0001:
			continue
		var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
		var on_edge := start + segment * t
		var distance_squared := point.distance_squared_to(on_edge)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest = on_edge
			closest_edge_index = index
	# Search adjacent shoreline edges in alternating directions and progressively
	# wider landward bands. This preserves displaced trees as irregular shore
	# groves instead of deleting them when the nearest bank meets a path socket.
	var attempts_per_band := LAKE_SHORELINE.size()
	for attempt: int in range(attempts_per_band * 4):
		var band := attempt / attempts_per_band
		var local_step := attempt % attempts_per_band
		var edge_shift := 0
		if local_step > 0:
			edge_shift = int((local_step + 1) / 2)
			if local_step % 2 == 0:
				edge_shift = -edge_shift
		var edge_index := (closest_edge_index + edge_shift + LAKE_SHORELINE.size()) % LAKE_SHORELINE.size()
		var start := LAKE_SHORELINE[edge_index]
		var finish := LAKE_SHORELINE[(edge_index + 1) % LAKE_SHORELINE.size()]
		var anchor := closest if edge_shift == 0 else start.lerp(finish, 0.5)
		var tangent := (finish - start).normalized()
		var outward := _lake_shore_outward(edge_index)
		var shore_distance := 2.7 + float(band) * 1.65
		var lateral_step := float((serial * 5 + attempt * 3) % 9) - 4.0
		var candidate_2d := anchor + outward * shore_distance + tangent * lateral_step * 0.48
		var candidate := Vector3(candidate_2d.x, original.y, candidate_2d.y)
		if not _is_vegetation_clear(candidate, 1.7):
			continue
		if not _is_tree_spaced(candidate, MATURE_TREE_MIN_SPACING_M):
			continue
		return {"found":true, "position":candidate}
	return {"found":false, "position":original}

func _build_mainland_groundcover_patches(parent: Node3D) -> void:
	if dense_grass_prototypes.is_empty():
		return
	var root := Node3D.new()
	root.name = "MainlandDenseGrassPatches"
	parent.add_child(root)
	# These are the mainland infill groves only. Three offset patches per grove
	# create a readable knee-height layer within groves while leaving the open
	# upright-grass lawns and lake islands clear.
	var centers: Array[Vector2] = [
		Vector2(-86,-16),Vector2(-63,-14),Vector2(-86,17),Vector2(-63,18),
		Vector2(-28,61),Vector2(23,63),Vector2(-18,-66),Vector2(4,-69),
		Vector2(-87,-42),Vector2(-53,-44),Vector2(-72,-29),
	]
	var heavy_patch_serials: Array[int] = [2,8,15,21]
	var serial := 0
	for center_index: int in range(centers.size()):
		var center := centers[center_index]
		for patch_index: int in range(3):
			var angle := float(center_index) * 1.31 + float(patch_index) * 2.17
			var radius_value := 3.4 + float(patch_index) * 2.1
			var position_value := Vector3(
				center.x + cos(angle) * radius_value,
				0.025,
				center.y + sin(angle) * radius_value * 0.72
			)
			if not _is_vegetation_clear(position_value, 0.35):
				continue
			var is_heavy_patch := serial in heavy_patch_serials
			var prototype_index := 0 if is_heavy_patch else 1 + serial % maxi(dense_grass_prototypes.size() - 1, 1)
			prototype_index %= dense_grass_prototypes.size()
			var selected_prototypes: Array[Node3D] = [dense_grass_prototypes[prototype_index]]
			_add_reference_plant(
				root, selected_prototypes, position_value,
				(0.36 + float(serial % 3) * 0.035) if is_heavy_patch else (0.58 + float(serial % 4) * 0.055),
				3000 + serial,
				"MainlandDenseGrass"
			)
			serial += 1

func _build_mainland_meadow_transitions(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "MainlandMeadowTransitions"
	parent.add_child(root)
	# Light fountain and meadow grasses bridge the visual gap between the
	# upright lawn grass and the shrub/tree layer. Uneven groups avoid a tiled
	# field while leaving the important routes and open plaza readable.
	var clusters: Array[Vector4] = [
		Vector4(-89,-22,4.8,4),Vector4(-63,-8,4.2,3),
		Vector4(-90,22,4.6,4),Vector4(-59,23,4.0,3),
		Vector4(-31,66,4.8,4),Vector4(20,69,4.6,4),
		Vector4(-22,-70,4.4,4),Vector4(8,-73,4.1,4),
		Vector4(-87,-39,4.8,5),Vector4(-53,-47,4.5,5),
		Vector4(-72,-29,3.8,4),
	]
	var serial := 0
	for cluster_index: int in range(clusters.size()):
		var cluster := clusters[cluster_index]
		for plant_index: int in range(int(cluster.w)):
			var angle := float(cluster_index) * 1.71 + float(plant_index) * 2.29
			var radius_value := 1.25 + float(plant_index % 3) * cluster.z * 0.42
			var position_value := Vector3(
				cluster.x + cos(angle) * radius_value,
				0.035,
				cluster.y + sin(angle) * radius_value * 0.68
			)
			if not _is_vegetation_clear(position_value, 0.55):
				continue
			var source := FountainGrassScene if (serial + cluster_index) % 3 == 0 else MeadowGrassScene
			var scale_value := 0.62 + float((serial * 7 + cluster_index) % 5) * 0.075
			_instance_park_asset(
				root, source, "VEG06_MainlandTransition_%02d" % (serial + 1),
				position_value, fmod(float(serial * 137 + cluster_index * 31), 360.0),
				Vector3.ONE * scale_value
			)
			serial += 1

func _build_woodland_fallen_fragments(parent: Node3D) -> void:
	if deadwood_trunk_prototype == null:
		return
	var root := Node3D.new()
	root.name = "WoodlandFallenWoodFragments"
	parent.add_child(root)
	var placed := 0
	for index: int in range(0, occupied_tree_positions.size(), 7):
		if placed >= 28:
			break
		var trunk: Vector2 = occupied_tree_positions[index]
		var angle := float(index) * 2.399963
		var point := trunk + Vector2(cos(angle), sin(angle)) * 1.2
		var position_value := Vector3(point.x, 0.0, point.y)
		if not _is_vegetation_clear(position_value, 1.0) or not _is_tree_spaced(position_value, 0.65):
			continue
		var wood := deadwood_trunk_prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
		wood.name = "FallenWoodFragment_%02d" % (placed + 1)
		wood.position = position_value
		wood.rotation_degrees = Vector3(0.0, fmod(float(index) * 137.5, 360.0), 88.0 + float(index % 5))
		var thickness := 0.045 + float(index % 4) * 0.009
		wood.scale = Vector3(thickness, 0.17 + float(index % 5) * 0.035, thickness)
		_preserve_asset_world_scale(wood)
		root.add_child(wood)
		# The supplied scanned trunk has an end pivot. Settle actual vertices,
		# avoiding hovering or submerged pieces; these tiny details do not block.
		var lowest := INF
		for mesh_node: MeshInstance3D in wood.find_children("*", "MeshInstance3D", true, false):
			for surface: int in range(mesh_node.mesh.get_surface_count()):
				var vertices: PackedVector3Array = mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex: Vector3 in vertices:
					lowest = minf(lowest, (mesh_node.global_transform * vertex).y)
		if is_finite(lowest):
			wood.position.y -= lowest + 0.004
		placed += 1


func _build_deadwood_pass(parent: Node3D) -> void:
	if deadwood_trunk_prototype == null or hollow_bark_prototype == null:
		push_warning("Midori deadwood pass skipped because a staged source is unavailable")
		return
	var root := Node3D.new()
	root.name = "MainlandDeadwood_7Logs_5Stumps_1Hollow"
	parent.add_child(root)

	# The retopologized beech trunk is reused with varied proportions and angles
	# to form seven separate fallen pieces. Four of the longer pieces affect
	# movement; the smaller three remain decorative ground detail.
	var log_specs: Array[Vector4] = [
		Vector4(-82,-6,18,1.18),Vector4(-72,10,127,1.34),
		Vector4(-56,7,246,1.08),Vector4(-20.5,55.5,73,1.42),
		Vector4(10,57,311,1.24),Vector4(-4,-52,154,1.12),
		Vector4(90.5,-6,38,1.38),
	]
	for index: int in range(log_specs.size()):
		var spec := log_specs[index]
		var position_value := Vector3(spec.x, 0.48 + float(index % 3) * 0.025, spec.y)
		if not _is_vegetation_clear(position_value, SHRUB_PATH_CLEARANCE_M):
			push_warning("Midori fallen log entered a reserved route: %s" % position_value)
			continue
		var cross_scale := 0.38 + float(index % 4) * 0.025
		var log_instance := deadwood_trunk_prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
		log_instance.name = "FallenBeechLog_%02d" % (index + 1)
		log_instance.position = position_value
		log_instance.rotation_degrees = Vector3(0.0, spec.z, 90.0 + float(index % 3 - 1) * 2.5)
		log_instance.scale = Vector3(cross_scale, spec.w, cross_scale)
		_preserve_asset_world_scale(log_instance)
		root.add_child(log_instance)
		if index in [3, 6]:
			# Imported end pivots and root flares make a fixed Y unreliable.
			# Settle only the two restored logs using their actual transformed vertices.
			var lowest_vertex := INF
			for mesh_node: MeshInstance3D in log_instance.find_children("*", "MeshInstance3D", true, false):
				for surface_index: int in range(mesh_node.mesh.get_surface_count()):
					var vertices: PackedVector3Array = mesh_node.mesh.surface_get_arrays(surface_index)[Mesh.ARRAY_VERTEX]
					for vertex: Vector3 in vertices:
						lowest_vertex = minf(lowest_vertex, (mesh_node.global_transform * vertex).y)
			if is_finite(lowest_vertex):
				log_instance.position.y -= lowest_vertex + 0.012
		if index % 2 == 0:
			var collision_position := position_value
			if index == 6:
				# The restored east log's imported pivot sits at its end. Centre
				# the movement blocker on the visible wood, clear of the path.
				var visual_bounds: AABB = _vegetation_visual_bounds(log_instance)["bounds"]
				collision_position = log_instance.transform * visual_bounds.get_center()
			_add_deadwood_box_collision(
				root, "FallenLogCollision_%02d" % (index + 1), collision_position,
				log_instance.rotation_degrees,
				Vector3(0.92, 2.72 * spec.w, 0.92)
			)

	# Upright copies retain the scanned root flare and read as broken stump bases.
	var stump_specs: Array[Vector4] = [
		Vector4(-90,66,42,0.52),Vector4(-60,-3,173,0.62),
		Vector4(-13,56,286,0.48),Vector4(88,16,104,0.58),
		Vector4(-52,-8,229,0.54),
	]
	for index: int in range(stump_specs.size()):
		var spec := stump_specs[index]
		var position_value := Vector3(spec.x, -0.055, spec.y)
		if not _is_vegetation_clear(position_value, SHRUB_PATH_CLEARANCE_M):
			push_warning("Midori stump entered a reserved route: %s" % position_value)
			continue
		var stump_instance := deadwood_trunk_prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
		stump_instance.name = "BeechStump_%02d" % (index + 1)
		stump_instance.position = position_value
		stump_instance.rotation_degrees.y = spec.z
		stump_instance.scale = Vector3(0.46 + float(index % 3) * 0.035, spec.w, 0.46 + float(index % 3) * 0.035)
		_preserve_asset_world_scale(stump_instance)
		root.add_child(stump_instance)
		if index in [0,1,3]:
			var stump_height := 2.78 * spec.w
			_add_deadwood_stump_collision(
				root, "StumpCollision_%02d" % (index + 1),
				position_value + Vector3(0.0, stump_height * 0.5, 0.0),
				0.58, stump_height
			)

	# The 220k-polygon hollow bark remains a single focal prop.
	var hollow_position := Vector3(-75.0, -0.065, -7.0)
	if _is_vegetation_clear(hollow_position, SHRUB_PATH_CLEARANCE_M):
		var hollow := hollow_bark_prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
		hollow.name = "HeavyHollowBark_01"
		hollow.position = hollow_position
		hollow.rotation_degrees.y = 23.0
		hollow.scale = Vector3.ONE * 0.48
		_preserve_asset_world_scale(hollow)
		root.add_child(hollow)
		_add_deadwood_box_collision(
			root, "HeavyHollowBarkCollision_01",
			hollow_position + Vector3(0.0, 0.38, 0.0), Vector3(0.0,23.0,0.0),
			Vector3(3.55,0.76,2.55)
		)

func _build_open_lawn_cover(parent: Node3D) -> void:
	# Existing mossy rock art supplies waist-high cover in open lawn panels.
	# Keep its exact mesh collision and leave the route shoulders clear.
	var prototype := MossyBoulderScene.instantiate() as Node3D
	if prototype == null:
		return
	_apply_stone_detail(prototype)
	var info := _vegetation_visual_bounds(prototype)
	if not info["valid"]:
		prototype.free()
		return
	var bounds: AABB = info["bounds"]
	var factor := 4.4 / maxf(bounds.size.x, bounds.size.z)
	var meshes: Array[Node] = prototype.find_children("*", "MeshInstance3D", true, false)
	if prototype is MeshInstance3D:
		meshes.append(prototype)
	var collision_shapes: Array[Dictionary] = []
	for mesh_node: MeshInstance3D in meshes:
		if mesh_node.mesh != null:
			collision_shapes.append({"transform": _vegetation_relative_transform(mesh_node, prototype), "shape": mesh_node.mesh.create_trimesh_shape()})
	var anchors: Array[Vector2] = TREE_COVER_CLEARINGS.duplicate()
	var root := Node3D.new()
	root.name = "OpenLawnBoulderCover"
	parent.add_child(root)
	var fringe := Node3D.new()
	fringe.name = "OpenBoulderNativeFringe"
	root.add_child(fringe)
	var accepted: Array[Vector2] = []
	for anchor_index: int in range(anchors.size()):
		var point := Vector2.ZERO
		var found := false
		for radius_value: float in [0.0, 4.0, 8.0, 12.0, 16.0, 20.0, 24.0]:
			for step: int in range(12):
				if radius_value == 0.0 and step > 0:
					break
				var angle := TAU * float(posmod(step * 5 + anchor_index * 3, 12)) / 12.0
				var candidate := anchors[anchor_index] + Vector2(cos(angle), sin(angle)) * radius_value
				var local_position := Vector3(candidate.x, 0.0, candidate.y)
				if not _is_vegetation_clear(local_position, 3.0) or not _is_tree_spaced(local_position, 4.0):
					continue
				var too_close := false
				for other: Vector2 in accepted:
					if candidate.distance_to(other) < 12.0:
						too_close = true
						break
				if too_close:
					continue
				point = candidate
				found = true
				break
			if found:
				break
		if not found:
			continue
		var cluster := Node3D.new()
		cluster.name = "OpenBoulder_%02d" % (anchor_index + 1)
		cluster.position = Vector3(point.x, 0.0, point.y)
		cluster.rotation_degrees.y = float((anchor_index * 137) % 360)
		# Vary each cluster: size, a settled tilt and slight squash so the single
		# supplied model does not repeat as identical blobs across the lawn.
		var rock_h := float(posmod(anchor_index * 7919, 1000)) / 1000.0
		var rock_h2 := float(posmod(anchor_index * 104729, 1000)) / 1000.0
		var rock_size := factor * lerpf(0.72, 1.28, rock_h)
		var rock_squash := lerpf(0.78, 1.0, rock_h2)
		cluster.rotation_degrees.x = lerpf(-5.0, 5.0, rock_h2)
		cluster.rotation_degrees.z = lerpf(-4.0, 4.0, rock_h)
		cluster.scale = Vector3(rock_size / LAYOUT_SCALE, rock_size * rock_squash, rock_size / LAYOUT_SCALE * lerpf(0.85, 1.15, rock_h2))
		root.add_child(cluster)
		var offset := Vector3(-bounds.get_center().x, -bounds.position.y - 0.04 / factor, -bounds.get_center().z)
		var visual := prototype.duplicate() as Node3D
		visual.position += offset
		cluster.add_child(visual)
		_configure_park_asset_visibility(visual)
		for spec: Dictionary in collision_shapes:
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.transform = spec["transform"]
			body.position += offset
			cluster.add_child(body)
			var collision := CollisionShape3D.new()
			collision.shape = spec["shape"]
			body.add_child(collision)
		accepted.append(point)
		# Low native growth helps each supplied rock sit in the lawn without
		# obscuring its silhouette or changing its walkable cover collision.
		for fringe_index: int in range(3):
			var angle := float(anchor_index) * 1.43 + float(fringe_index) * 2.15
			var distance_value := 1.6 + float(fringe_index) * 0.35
			var candidate := point + Vector2(cos(angle), sin(angle)) * distance_value
			var plant_position := Vector3(candidate.x, -0.018, candidate.y)
			if not _is_vegetation_clear(plant_position, 0.5):
				continue
			var sources := forest_floor_bush_prototypes if fringe_index == 1 else dense_grass_prototypes
			if sources.is_empty():
				continue
			_add_reference_plant(
				fringe, sources, plant_position,
				0.68 if fringe_index == 1 else 0.56,
				7000 + anchor_index * 3 + fringe_index, "OpenBoulderFringe"
			)
	prototype.free()
	print("Midori open lawn cover: %d supplied boulder clusters at %s" % [accepted.size(), accepted])

func _build_japanese_maple_pass(parent: Node3D) -> void:
	if japanese_maple_prototype == null:
		push_warning("Midori Japanese maple pass skipped because its source is unavailable")
		return
	var candidates: Array[Vector3] = [
		Vector3(-17.0,-0.055,52.0),Vector3(-8.0,-0.055,54.0),
		Vector3(-25.0,-0.055,53.0),Vector3(12.0,-0.055,53.0),
		Vector3(-17.0,-0.055,63.0),
	]
	var crown_radius := _tree_crown_radius(japanese_maple_prototype)
	var maple_position := Vector3.ZERO
	var found := false
	for candidate_index: int in range(candidates.size()):
		var candidate: Vector3 = candidates[candidate_index]
		if _is_vegetation_clear(candidate, 3.6) and _is_tree_spaced(candidate, MATURE_TREE_MIN_SPACING_M) and _is_tree_canopy_spaced(candidate, _tree_crown_radius(japanese_maple_prototype)):
			maple_position = candidate
			found = true
			break
		var relocation := _find_canopy_position(candidate, crown_radius, 850 + candidate_index)
		if relocation["found"]:
			maple_position = relocation["position"]
			found = true
			break
	if not found:
		push_warning("Midori Japanese maple has no clear authored position")
		return
	var root := Node3D.new()
	root.name = "JapaneseMapleAccents_1Of2"
	parent.add_child(root)
	var maple := japanese_maple_prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
	maple.name = "Free3DJapaneseMaple_01"
	maple.position = maple_position
	maple.rotation_degrees.y = 214.0
	_preserve_asset_world_scale(maple)
	root.add_child(maple)
	_occupied_tree_crowns[Vector2(maple_position.x, maple_position.z)] = crown_radius
	occupied_tree_positions.append(Vector2(maple_position.x, maple_position.z))
	occupied_tree_is_skinny.append(false)
	_add_deadwood_stump_collision(
		root, "JapaneseMapleCollision_01",
		maple_position + Vector3(0.0,1.25,0.0), 0.48, 2.5
	)

func _park_furniture_pathside(authored: Vector3, setback: float) -> Dictionary:
	# Match the rendered, rounded paths, including their human-scale widths.
	# All distances here are in layout space (two metres per layout unit).
	var routes: Array[Dictionary] = [
		{"name":"OuterWalkingCircuit", "points": OUTER_CIRCUIT, "width": 3.8},
		{"name":"SouthEntranceToLake", "points": SOUTH_ARRIVAL_ROUTE, "width": 4.0},
		{"name":"WestEntranceToBridgeLanding", "points": WEST_DESTINATION_ROUTE, "width": 4.0},
		{"name":"NorthEntranceToLake", "points": NORTH_ENTRY_ROUTE, "width": 3.8},
		{"name":"EastEntranceToBridgeLanding", "points": EAST_DECK_ROUTE, "width": 3.8},
		{"name":"SportsConnector", "points": SPORTS_LINK_ROUTE, "width": 3.0},
		{"name":"PlaygroundWoodlandLoop", "points": PLAYGROUND_LOOP, "width": 2.7},
		{"name":"NorthWoodlandLoop", "points": NORTH_WOODLAND_LOOP, "width": 2.5},
	]
	routes.append_array([
		{"name":"SouthEntranceToPlaza","points":PLAZA_PAVED_ROUTE,"width":4.0},
		{"name":"ContinuousLakePromenade","points":LAKE_PROMENADE_LOOP,"width":LAKE_PROMENADE_WIDTH_M},
		{"name":"PlazaToSouthBridgeLanding","points":SOUTH_BRIDGE_APPROACH,"width":3.2},
		{"name":"PavilionGardenLink","points":PAVILION_LINK_ROUTE,"width":2.8},
		{"name":"EastPromenadeToViewingDeck","points":VIEWING_DECK_APPROACH_ROUTE,"width":3.0},
	])
	var point := Vector2(authored.x, authored.z)
	var nearest := Vector2.ZERO
	var tangent := Vector2.RIGHT
	var distance := INF
	var half_width := 0.0
	for route: Dictionary in routes:
		var anchors: Array[Vector2] = route["points"].duplicate()
		var closed := anchors[0].is_equal_approx(anchors[-1])
		if not closed:
			while anchors.size() > 2 and anchors[-2].distance_to(anchors[-1]) < 3.0:
				anchors.remove_at(anchors.size() - 2)
		var curve := _rounded_contour(anchors, closed, _path_curve_radius(str(route.name)), _path_corner_fraction(str(route.name)))
		for i: int in range(curve.size() - 1):
			var closest := Geometry2D.get_closest_point_to_segment(point, curve[i], curve[i + 1])
			var candidate_distance := point.distance_squared_to(closest)
			if candidate_distance < distance and not curve[i].is_equal_approx(curve[i + 1]):
				distance = candidate_distance
				nearest = closest
				tangent = (curve[i + 1] - curve[i]).normalized()
				half_width = _path_width_world(str(route.name),float(route.width)) / LAYOUT_SCALE * 0.5
	var outward := Vector2(-tangent.y, tangent.x)
	if outward.dot(point - nearest) < 0.0:
		outward = -outward
	var location := nearest + outward * (half_width + setback)
	var facing := -outward
	return {"position": Vector3(location.x, authored.y, location.y),
		"direction": Vector3(facing.x, 0.0, facing.y),
		"yaw": rad_to_deg(atan2(-facing.x, -facing.y))}


func _build_park_benches(parent: Node3D) -> void:
	if neon_park_bench_prototype == null and futuristic_eco_bench_prototype == null:
		push_warning("Midori bench pass skipped because its source is unavailable")
		return
	var root := Node3D.new()
	root.name = "ParkBenches_6_TwoVariations"
	parent.add_child(root)
	# Candidates sit just beyond path shoulders. Extra candidates allow the pass
	# to reject trees while retaining six useful, widely separated rest points.
	var candidates: Array[Vector3] = [
		Vector3(-78,-0.025,72.5),Vector3(-78,-0.025,-72.5),
		Vector3(-15,-0.025,79.5),Vector3(-12,-0.025,-78.5),
		Vector3(-45,-0.025,35),Vector3(96,-0.025,-30),
		Vector3(48,-0.025,81),Vector3(55,-0.025,-81),
		Vector3(-101,-0.025,-28),Vector3(-32,-0.025,48),
		Vector3(18,-0.025,81),Vector3(22,-0.025,-81),
		Vector3(-48,-0.025,78),Vector3(-48,-0.025,-77),
		Vector3(96,-0.025,74),Vector3(97,-0.025,-73),
	]
	var bench_positions: Array[Vector2] = []
	var placed := 0
	for authored: Vector3 in candidates:
		var pathside := _park_furniture_pathside(authored, 0.65)
		var candidate: Vector3 = pathside.position
		if placed >= 6:
			break
		if not _is_tree_spaced(candidate, 2.2):
			continue
		var point := Vector2(candidate.x, candidate.z)
		var separated := true
		for occupied: Vector2 in bench_positions:
			if point.distance_squared_to(occupied) < 18.0 * 18.0:
				separated = false
				break
		if not separated:
			continue
		var yaw: float = pathside.yaw + 180.0
		var use_eco := placed % 2 == 1 and futuristic_eco_bench_prototype != null
		var source := futuristic_eco_bench_prototype if use_eco else neon_park_bench_prototype
		if source == null:
			source = futuristic_eco_bench_prototype
		var bench := source.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
		bench.name = ("FuturisticEcoBench_%02d" if use_eco else "NeonParkBench_%02d") % (placed + 1)
		bench.position = candidate
		bench.rotation_degrees.y = yaw
		bench.scale = Vector3.ONE * 2.1
		_preserve_asset_world_scale(bench)
		root.add_child(bench)
		_add_invisible_collision_box(
			root, "ParkBenchCollision_%02d" % (placed + 1),
			candidate + Vector3(0.0,0.46,0.0), Vector3(2.05,0.92,0.72), yaw
		)
		bench_positions.append(point)
		placed += 1
	if placed < 6:
		push_warning("Midori bench pass placed only %d of 6 because of tree clearance" % placed)

func _build_park_lamps(parent: Node3D) -> void:
	# Main walks use the Japanese lamps; preserve halo lamps at the monument.
	if has_node("MidoriJapanesePathLamps"): return
	if emerald_halo_lamp_prototype == null:
		push_warning("Midori lamp pass skipped because its source is unavailable")
		return
	var root := Node3D.new()
	root.name = "EmeraldHaloPathLamps_10"
	parent.add_child(root)
	var placements: Array[Vector3] = [
		Vector3(-72,-0.025,74.4),Vector3(-20,-0.025,79.5),
		Vector3(38,-0.025,81.8),Vector3(88,-0.025,81.0),
		Vector3(-55,-0.025,-77.2),Vector3(-10,-0.025,-79.2),
		Vector3(62,-0.025,-81.6),Vector3(91,-0.025,-78.8),
		Vector3(-102.5,-0.025,5),Vector3(101.5,-0.025,0),
	]
	for index: int in range(placements.size()):
		var pathside := _park_furniture_pathside(placements[index], 0.30)
		var position_value: Vector3 = pathside.position
		if not _is_tree_spaced(position_value, 1.8):
			push_warning("Midori path lamp skipped for tree clearance at %s" % position_value)
			continue
		var lamp := emerald_halo_lamp_prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
		lamp.name = "EmeraldHaloLamp_%02d" % (index + 1)
		lamp.position = position_value
		var path_direction: Vector3 = pathside.direction
		var lamp_yaw: float = pathside.yaw
		lamp.rotation_degrees.y = lamp_yaw
		lamp.scale = Vector3.ONE * 7.2
		_preserve_asset_world_scale(lamp)
		root.add_child(lamp)
		_add_lamp_lights(root, index, position_value, path_direction)
		_add_lamp_path_streak(root, index, position_value, path_direction)
		_add_deadwood_stump_collision(
			root, "HaloLampCollision_%02d" % (index + 1),
			position_value + Vector3(0.0,3.40,0.0), 0.28, 6.8
		)

func _build_landmark_plaza_furniture(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "LandmarkPlazaFurniture_3Benches_4PathLamps"
	parent.add_child(root)
	var center_3d := Vector3(PLAZA_CENTER.x, 0.0, PLAZA_CENTER.y)

	if neon_park_bench_prototype != null or futuristic_eco_bench_prototype != null:
		var bench_points: Array[Vector3] = [
			Vector3(72.0,0.1345,77.0),
			Vector3(94.0,0.1345,76.0),
			Vector3(82.0,0.1415,57.0),
		]
		for index: int in range(bench_points.size()):
			var source := neon_park_bench_prototype
			if index % 2 == 1 and futuristic_eco_bench_prototype != null:
				source = futuristic_eco_bench_prototype
			if source == null:
				source = futuristic_eco_bench_prototype
			var bench := source.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
			var position_value := bench_points[index]
			var facing := center_3d - position_value
			var yaw := rad_to_deg(atan2(facing.x, facing.z))
			bench.name = "PlazaBench_%02d" % (index + 1)
			bench.position = position_value
			bench.rotation_degrees.y = yaw
			bench.scale = Vector3.ONE * 2.1
			_preserve_asset_world_scale(bench)
			root.add_child(bench)
			_add_invisible_collision_box(
				root, "PlazaBenchCollision_%02d" % (index + 1),
				position_value + Vector3(0.0,0.46,0.0), Vector3(2.05,0.92,0.72), yaw
			)

	if emerald_halo_lamp_prototype == null:
		return
	var lamp_specs: Array[Dictionary] = [
		{"p":Vector3(70.0,0.1345,76.0), "target":Vector3(77.0,0.1345,74.0)},
		{"p":Vector3(88.0,0.1475,75.0), "target":Vector3(88.0,0.1475,72.0)},
		{"p":Vector3(94.0,0.1345,63.0), "target":Vector3(92.0,0.1345,61.0)},
		{"p":Vector3(72.0,0.1345,66.0), "target":Vector3(73.0,0.1345,69.0)},
	]
	for index: int in range(lamp_specs.size()):
		var position_value: Vector3 = lamp_specs[index]["p"]
		var target_value: Vector3 = lamp_specs[index]["target"]
		var path_direction := target_value - position_value
		path_direction.y = 0.0
		path_direction = path_direction.normalized()
		var lamp_yaw := rad_to_deg(atan2(-path_direction.x, -path_direction.z))
		var lamp := emerald_halo_lamp_prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
		var lamp_index := index + 10
		lamp.name = "PlazaHaloLamp_%02d" % (index + 1)
		lamp.position = position_value
		lamp.rotation_degrees.y = lamp_yaw
		lamp.scale = Vector3.ONE * 7.2
		_preserve_asset_world_scale(lamp)
		root.add_child(lamp)
		_add_lamp_lights(root, lamp_index, position_value, path_direction)
		_add_lamp_path_streak(root, lamp_index, position_value, path_direction, 0.170)
		_add_deadwood_stump_collision(
			root, "PlazaHaloLampCollision_%02d" % (index + 1),
			position_value + Vector3(0.0,3.40,0.0), 0.28, 6.8
		)

func _add_lamp_lights(
	parent: Node3D,
	index: int,
	position_value: Vector3,
	path_direction: Vector3
) -> void:
	# The upper halo softly illuminates the surrounding path and vegetation.
	var halo_light := OmniLight3D.new()
	halo_light.name = "BlueHaloArea_%02d" % (index + 1)
	halo_light.position = position_value + Vector3(0.0,6.94,0.0)
	halo_light.light_color = Color("#75ddff")
	halo_light.light_energy = 0.35
	halo_light.omni_range = 7.0
	halo_light.shadow_enabled = false
	halo_light.light_volumetric_fog_energy = 1.25
	parent.add_child(halo_light)
	halo_light.add_to_group("midori_night_effect")

	# The emitter inside the lower slit throws a narrow, oblique streak onto the
	# adjacent path. The shallow projection elongates the pool into a line.
	var slit_light := SpotLight3D.new()
	slit_light.name = "BlueSlitPathLine_%02d" % (index + 1)
	slit_light.position = position_value + Vector3(0.0,1.38,0.0) + path_direction * 0.08
	slit_light.light_color = Color("#ffd9ae")
	slit_light.light_energy = 0.9
	slit_light.spot_range = 5.5
	slit_light.spot_angle = 6.0
	slit_light.shadow_enabled = false
	slit_light.light_volumetric_fog_energy = 2.0
	parent.add_child(slit_light)
	slit_light.add_to_group("midori_night_effect")
	slit_light.look_at(position_value + path_direction * 3.4 + Vector3(0.0,0.05,0.0), Vector3.UP)

func _add_lamp_path_streak(
	parent: Node3D,
	index: int,
	position_value: Vector3,
	path_direction: Vector3,
	projection_y: float = -1.0
) -> void:
	# No blue LED streaks on the walks; the lamps light the path themselves.
	return
	var streak := MeshInstance3D.new()
	streak.name = "BlueSlitProjection_%02d" % (index + 1)
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.22,3.4)
	streak.mesh = plane
	# Path surfaces reach roughly 0.11 m; keep the projection just above them.
	streak.position = position_value + path_direction * 2.15 + Vector3(0.0,0.125,0.0)
	if projection_y >= 0.0:
		streak.position.y = projection_y
	streak.rotation.y = atan2(path_direction.x, path_direction.z)
	streak.material_override = mat_path_light_streak
	parent.add_child(streak)
	streak.add_to_group("midori_night_effect")

func _add_deadwood_box_collision(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	rotation_degrees_value: Vector3,
	size_value: Vector3
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.rotation_degrees = rotation_degrees_value
	body.scale = Vector3(1.0 / LAYOUT_SCALE, 1.0, 1.0 / LAYOUT_SCALE)
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)

func _add_deadwood_stump_collision(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	radius_value: float,
	height_value: float
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.scale = Vector3(1.0 / LAYOUT_SCALE, 1.0, 1.0 / LAYOUT_SCALE)
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius_value
	shape.height = height_value
	collision.shape = shape
	body.add_child(collision)

func _add_mixed_tree_pair_shrubs(parent: Node3D) -> void:
	# Give each skinny pine's nearest mature neighbour a soft three-bush pocket.
	# The asymmetric offsets fill the eye-level gap without forming a hedge line.
	var shrub_serial := 2000
	for skinny_index: int in range(occupied_tree_positions.size()):
		if skinny_index >= occupied_tree_is_skinny.size() or not occupied_tree_is_skinny[skinny_index]:
			continue
		var skinny_position := occupied_tree_positions[skinny_index]
		var nearest_mature := Vector2.ZERO
		var nearest_distance_squared := 5.5 * 5.5
		var found_mature := false
		for mature_index: int in range(occupied_tree_positions.size()):
			if mature_index == skinny_index:
				continue
			if mature_index < occupied_tree_is_skinny.size() and occupied_tree_is_skinny[mature_index]:
				continue
			var distance_squared := skinny_position.distance_squared_to(occupied_tree_positions[mature_index])
			if distance_squared < nearest_distance_squared:
				nearest_distance_squared = distance_squared
				nearest_mature = occupied_tree_positions[mature_index]
				found_mature = true
		if not found_mature:
			continue
		var direction := (nearest_mature - skinny_position).normalized()
		var perpendicular := Vector2(-direction.y, direction.x)
		var midpoint := (skinny_position + nearest_mature) * 0.5
		var bush_offsets: Array[Vector2] = [
			perpendicular * -0.58,
			perpendicular * 0.52 + direction * 0.18,
			direction * 0.72 + perpendicular * 0.10,
		]
		for offset: Vector2 in bush_offsets:
			var bush_point := midpoint + offset
			var bush_position := Vector3(bush_point.x, 0.12, bush_point.y)
			if not _is_vegetation_clear(bush_position, SHRUB_PATH_CLEARANCE_M):
				continue
			_add_reference_plant(
				parent, lilac_prototypes, bush_position,
				0.62 + float(posmod(shrub_serial * 7, 6)) * 0.06,
				shrub_serial, "MixedTreeGapBush"
			)
			shrub_serial += 1

func _add_reference_shrub_cluster(
	parent: Node3D,
	center: Vector2,
	radius_value: float,
	count: int,
	serial_offset: int
) -> void:
	var placed := 0
	var attempt := 0
	while placed < count and attempt < count * 8:
		var radial_t := sqrt((float(attempt % count) + 0.18) / float(count))
		var angle := float(attempt) * 2.399963 + float(serial_offset) * 0.017
		var position_value := Vector3(
			center.x + cos(angle) * radius_value * radial_t,
			0.11,
			center.y + sin(angle) * radius_value * radial_t * 0.72
		)
		attempt += 1
		if not _is_vegetation_clear(position_value, SHRUB_PATH_CLEARANCE_M):
			continue
		var serial := serial_offset + placed
		_add_reference_plant(
			parent, lilac_prototypes, position_value,
			0.58 + float(posmod(serial * 7, 6)) * 0.065,
			serial, "ReferenceLilacMass"
		)
		placed += 1

func _build_wildflower_groundcover(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "ColorfulWildflowerMeadows"
	parent.add_child(root)
	var palettes: Array[Color] = [
		Color("#f2b9cf"), Color("#f0d978"), Color("#bfa7e8"),
		Color("#e8eee4"), Color("#e99a78"),
	]
	var transforms_by_color: Array = []
	for color: Color in palettes:
		transforms_by_color.append([])
	var stem_transforms: Array[Transform3D] = []
	var patches: Array[Vector4] = [
		Vector4(-78,7,15,55),Vector4(-70,68,13,45),Vector4(-18,18,13,50),
		Vector4(-12,55,12,45),Vector4(25,52,11,42),Vector4(67,73,10,36),
		Vector4(89,10,9,34),Vector4(87,-35,10,36),Vector4(8,-73,11,40),
		Vector4(45,-72,10,38),Vector4(70,-57,9,34),
	]
	var flower_serial := 0
	for patch: Vector4 in patches:
		var desired := int(patch.w) * 3
		var placed := 0
		var attempt := 0
		while placed < desired and attempt < desired * 10:
			var radial_t := sqrt((float(attempt % desired) + 0.30) / float(desired))
			var angle := float(attempt) * 2.399963 + patch.x * 0.03
			var position_value := Vector3(
				patch.x + cos(angle) * patch.z * 0.72 * radial_t,
				0.0,
				patch.y + sin(angle) * patch.z * 0.72 * radial_t * 0.68
			)
			attempt += 1
			if not _is_vegetation_clear(position_value, 0.35):
				continue
			var height := 0.24 + 0.035 * float(flower_serial % 5)
			var head_transform := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.70 + 0.08 * float(flower_serial % 4))), position_value + Vector3(0,height,0))
			transforms_by_color[flower_serial % palettes.size()].append(head_transform)
			stem_transforms.append(Transform3D(Basis.IDENTITY, position_value + Vector3(0,height * 0.5,0)).scaled_local(Vector3(1,height / 0.30,1)))
			flower_serial += 1
			placed += 1

	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.012
	stem_mesh.bottom_radius = 0.015
	stem_mesh.height = 0.30
	stem_mesh.radial_segments = 5
	_add_flower_multimesh(root, "WildflowerStems", stem_mesh, stem_transforms, _make_material(Color("#496d3e"), 0.96))
	for color_index: int in range(palettes.size()):
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.045
		head_mesh.height = 0.065
		head_mesh.radial_segments = 6
		head_mesh.rings = 4
		_add_flower_multimesh(
			root, "WildflowerHeads_%d" % color_index, head_mesh,
			transforms_by_color[color_index], _make_material(palettes[color_index], 0.82)
		)

func _add_flower_multimesh(
	parent: Node3D,
	node_name: String,
	mesh: Mesh,
	transforms: Array,
	material: Material
) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	# This batch spans the park: distance from its shared origin is unrelated
	# to distance from an individual flower patch. Retain frustum culling.
	instance.visibility_range_end = 0.0
	parent.add_child(instance)

func _build_sakura_trees(parent: Node3D) -> void:
	var trees_root := Node3D.new()
	trees_root.name = "HandPlacedSakuraAccentTrees_%d" % SAKURA_TREE_COUNT
	parent.add_child(trees_root)
	_occupied_tree_crowns.clear()
	_tree_crown_radius_cache.clear()
	var sakura_source: Node3D = load("res://assets/shinrai/vegetation/sakura/jogoss_sakura_01/Sakura.fbx").instantiate()
	var sakura_radius := _tree_crown_radius(sakura_source, 15.0)
	sakura_source.free()
	occupied_tree_positions.clear()
	invalidate_trunk_index()
	occupied_tree_is_skinny.clear()
	var placements: Array[Vector3] = [
		Vector3(-92.0, 0.0, -66.0), Vector3(-68.0, 0.0, -70.0), Vector3(-43.0, 0.0, -67.0),
		Vector3(-15.0, 0.0, -71.0), Vector3(15.0, 0.0, -70.0), Vector3(58.0, 0.0, -72.0),
		Vector3(94.0, 0.0, -62.0), Vector3(-103.0, 0.0, -42.0), Vector3(-92.0, 0.0, -12.0),
		Vector3(-93.0, 0.0, 18.0), Vector3(-92.0, 0.0, 48.0), Vector3(-90.0, 0.0, 70.0),
		Vector3(94.0, 0.0, -45.0), Vector3(93.0, 0.0, -12.0), Vector3(92.0, 0.0, 18.0),
		Vector3(94.0, 0.0, 48.0), Vector3(93.0, 0.0, 70.0), Vector3(-70.0, 0.0, 70.0),
		Vector3(-42.0, 0.0, 68.0), Vector3(-12.0, 0.0, 70.0), Vector3(18.0, 0.0, 69.0),
		Vector3(45.0, 0.0, 72.0), Vector3(70.0, 0.0, 72.0), Vector3(-30.0, 0.0, -45.0),
		Vector3(-30.0, 0.0, -15.0), Vector3(-22.0, 0.0, 18.0), Vector3(-12.0, 0.0, 32.0),
		Vector3(29.0, 0.0, 47.0), Vector3(58.0, 0.0, 31.0), Vector3(82.0, 0.0, 17.0),
		Vector3(86.0, 0.0, 5.0), Vector3(82.0, 0.0, -36.0), Vector3(55.0, 0.0, -53.0),
		Vector3(15.0, 0.0, -62.0), Vector3(-20.0, 0.0, -58.0), Vector3(-38.0, 0.0, 48.0),
		Vector3(-55.0, 0.0, -65.0), Vector3(-40.0, 0.0, -45.0), Vector3(-38.0, 0.0, -18.0),
		Vector3(-42.0, 0.0, 8.0), Vector3(-45.0, 0.0, 25.0), Vector3(-52.0, 0.0, 64.0),
		Vector3(-28.0, 0.0, 58.0), Vector3(2.0, 0.0, 58.0), Vector3(32.0, 0.0, 60.0),
		Vector3(90.0, 0.0, 35.0), Vector3(90.0, 0.0, -55.0), Vector3(30.0, 0.0, -70.0),
	]
	for index: int in range(mini(placements.size(), SAKURA_TREE_COUNT)):
		var scale_value: float = 0.80 + float(index % 7) * 0.04
		var tree_position := _clear_sakura_position(placements[index])
		var crown_position := _find_canopy_position(tree_position, sakura_radius * scale_value, index)
		if crown_position["found"]:
			tree_position = crown_position["position"]
		var tree := SakuraTreeScene.instantiate() as Node3D
		tree.name = "DenseSakura_%02d" % (index + 1)
		tree.position = tree_position
		tree.rotation_degrees.y = fmod(float(index) * 137.5, 360.0)
		tree.scale = Vector3.ONE * scale_value
		_preserve_asset_world_scale(tree)
		trees_root.add_child(tree)
		_occupied_tree_crowns[Vector2(tree_position.x, tree_position.z)] = sakura_radius * scale_value
		_configure_vegetation_visibility(tree)
		_add_sakura_trunk_collision(trees_root, index, tree_position, scale_value)
		occupied_tree_positions.append(Vector2(tree_position.x, tree_position.z))
		occupied_tree_is_skinny.append(false)

func _clear_sakura_position(authored_position: Vector3) -> Vector3:
	if _is_vegetation_clear(authored_position, 3.6) and _is_tree_spaced(authored_position, MATURE_TREE_MIN_SPACING_M):
		return authored_position
	var offsets: Array[Vector3] = [
		Vector3(-9,0,0),Vector3(9,0,0),Vector3(0,0,-9),Vector3(0,0,9),
		Vector3(-9,0,-9),Vector3(9,0,-9),Vector3(-9,0,9),Vector3(9,0,9),
		Vector3(-15,0,0),Vector3(15,0,0),Vector3(0,0,-15),Vector3(0,0,15),
		Vector3(-20,0,-10),Vector3(20,0,-10),Vector3(-20,0,10),Vector3(20,0,10),
	]
	for offset: Vector3 in offsets:
		var candidate := authored_position + offset
		if _is_vegetation_clear(candidate, 3.6) and _is_tree_spaced(candidate, MATURE_TREE_MIN_SPACING_M):
			return candidate
	for ring: int in range(5, 16):
		var radius_value := float(ring) * 4.0
		for step: int in range(ring * 8):
			var angle := TAU * float(step) / float(ring * 8)
			var candidate := authored_position + Vector3(
				cos(angle) * radius_value, 0.0, sin(angle) * radius_value
			)
			if _is_vegetation_clear(candidate, 3.6) and _is_tree_spaced(candidate, MATURE_TREE_MIN_SPACING_M):
				return candidate
	push_warning("Midori sakura has no unoccupied park position near %s" % str(authored_position))
	return authored_position

func _add_sakura_trunk_collision(parent: Node3D, index: int, position_value: Vector3, scale_value: float) -> void:
	var body := StaticBody3D.new()
	body.name = "DenseSakuraCollision_%02d" % (index + 1)
	body.position = position_value + Vector3(0.0, 1.85 * scale_value, 0.0)
	body.scale = Vector3(1.0 / LAYOUT_SCALE, 1.0, 1.0 / LAYOUT_SCALE)
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.58 * scale_value
	shape.height = 3.7 * scale_value
	collision.shape = shape
	body.add_child(collision)

func _configure_vegetation_visibility(node: Node) -> void:
	if node is MeshInstance3D:
		FoliageMaterials.configure_mesh(node as MeshInstance3D)
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.visibility_range_end = 150.0
	for child: Node in node.get_children():
		_configure_vegetation_visibility(child)

func _add_zone_box(parent: Node3D, node_name: String, center: Vector3, size_2d: Vector2, material: Material) -> void:
	_add_visual_box(parent, node_name, center, Vector3(size_2d.x, 0.07, size_2d.y), material)

func _add_cylinder_zone(parent: Node3D, node_name: String, center: Vector3, radii: Vector2, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.055
	mesh.radial_segments = 48
	mesh_instance.mesh = mesh
	mesh_instance.position = center
	mesh_instance.scale = Vector3(radii.x, 1.0, radii.y)
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

func _add_polygon_zone(
	parent: Node3D,
	node_name: String,
	points: Array[Vector2],
	y_value: float,
	material: Material,
	corner_radius: float = 2.5,
	corner_fraction: float = 0.25
) -> void:
	if points.size() < 3:
		return
	if corner_radius > 0.0:
		points = _rounded_contour(points, true, corner_radius, corner_fraction)
		points.remove_at(points.size() - 1)
	var packed_points := PackedVector2Array(points)
	var triangle_indices := Geometry2D.triangulate_polygon(packed_points)
	if triangle_indices.is_empty():
		push_warning("Midori polygon could not be triangulated: %s" % node_name)
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle_index: int in triangle_indices:
		var point := points[triangle_index]
		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2(point.x, point.y) * 0.05)
		surface.add_vertex(Vector3(point.x, y_value, point.y))
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

func _add_lake_island(
	parent: Node3D,
	node_name: String,
	points: Array[Vector2],
	y_value: float
) -> void:
	_add_polygon_zone(parent, node_name, points, y_value, mat_island)
	points = _rounded_contour(points, true, 2.5)
	points.remove_at(points.size() - 1)
	_add_shoreline_ribbon(
		parent, "%s_SoftBank" % node_name, points,
		0.42, y_value + 0.004, mat_island_bank
	)

func _build_future_bridge_sockets(parent: Node3D) -> void:
	await MeasuredBridges.new().build(self,parent,MeasuredBridgeArtwork,MeasuredBridgeDisplay)

func _build_bridge_landings(parent: Node3D, bridge_id: String, a: Vector2, b: Vector2, width: float, deck: Dictionary) -> void:
	var anchors := {
		"Main":[Vector2(20,-44),Vector2(170,-48)],
		"North":[Vector2(46,-120),Vector2(158,-114)],
		"South":[Vector2(38,60),Vector2(162,44)],
	}
	var axis := (b-a).normalized()
	for side: int in range(2):
		var direction := axis if side == 0 else -axis
		var mouth := (a if side == 0 else b)-direction*0.80
		var start: Vector2 = anchors[bridge_id][side]
		var tread := BridgeWalks.height_at(deck,mouth+direction*0.2)
		var material := WalkMaterials.build(width,0.0)
		material.set_shader_parameter("night_emission",1.0 if is_night_mode else 0.0)
		if not modular_path_emissive_materials.has(material):
			modular_path_emissive_materials.append(material)
		var landing := BridgeLandings.install(parent,"%s%sBridgeLink" % [bridge_id,"West" if side == 0 else "East"],start,mouth,direction,width,tread,material,_bridge_join_walks)
		_bridge_walk_surfaces.append({"kind":"landing","spec":landing})

func bridge_surface_height(p: Vector2) -> float:
	var result := -INF
	for surface: Dictionary in _bridge_walk_surfaces:
		var height: float = BridgeWalks.height_at(surface.spec,p) if surface.kind == "deck" else BridgeLandings.height_at(surface.spec,p)
		result = maxf(result,height)
	return result

func _add_shoreline_ribbon(
	parent: Node3D,
	node_name: String,
	points: Array[Vector2],
	width: float,
	y_value: float,
	material: Material,
	edge_indices: Array[int] = []
) -> void:
	if points.size() < 3:
		return
	var signed_area := 0.0
	for i: int in range(points.size()):
		signed_area += points[i].cross(points[(i + 1) % points.size()])
	var outer_points: Array[Vector2] = []
	for index: int in range(points.size()):
		var previous := points[posmod(index - 1, points.size())]
		var current := points[index]
		var following := points[(index + 1) % points.size()]
		var tangent := (following - previous).normalized()
		var outward := Vector2(tangent.y, -tangent.x)
		if signed_area < 0.0:
			outward = -outward
		outer_points.append(current + outward * width)
	var rendered_edges: Array[int] = []
	if edge_indices.is_empty():
		for edge_index: int in range(points.size()):
			rendered_edges.append(edge_index)
	else:
		rendered_edges.assign(edge_indices)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in rendered_edges:
		if index < 0 or index >= points.size():
			continue
		var next_index := (index + 1) % points.size()
		var inner_y := y_value
		var outer_y := y_value
		if node_name == "ContinuousNaturalBank":
			inner_y = 0.104
			outer_y = 0.22
		elif node_name.ends_with("_SoftBank"):
			outer_y = 0.104
		# Short bank sections let entrances recess only the turf under their floors.
		var sections := maxi(1,ceili(points[index].distance_to(points[next_index])*LAYOUT_SCALE/0.5)) if node_name == "ContinuousNaturalBank" else 1
		for section: int in range(sections):
			var a := float(section)/float(sections)
			var b := float(section+1)/float(sections)
			var inner_a := points[index].lerp(points[next_index],a)
			var inner_b := points[index].lerp(points[next_index],b)
			var outer_a := outer_points[index].lerp(outer_points[next_index],a)
			var outer_b := outer_points[index].lerp(outer_points[next_index],b)
			_add_shoreline_vertex(surface,inner_a,inner_y,Vector2(0,float(index)+a))
			_add_shoreline_vertex(surface,outer_a,outer_y,Vector2(1,float(index)+a))
			_add_shoreline_vertex(surface,outer_b,outer_y,Vector2(1,float(index)+b))
			_add_shoreline_vertex(surface,inner_a,inner_y,Vector2(0,float(index)+a))
			_add_shoreline_vertex(surface,outer_b,outer_y,Vector2(1,float(index)+b))
			_add_shoreline_vertex(surface,inner_b,inner_y,Vector2(0,float(index)+b))
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

## The bank is recessed under the bridge floors on a worker (pure maths on copies:
## the bank's vertex arrays, its transform and the walk-surface specs, all final
## once the bridges are built), while the rest of the zone placeholders (pitch,
## fence, plaza; none of them reads the bank) build on the main thread. The fitted
## mesh replaces the bank's at the end of the placeholders, before anything reads
## it (lake life and the terrain, after the structure). Same maths, same order.
var _bank_fit_task := -1

func _start_bank_fit(lake_root: Node3D) -> Array:
	var bank := lake_root.get_node("ContinuousNaturalBank") as MeshInstance3D
	var job := {"arrays": bank.mesh.surface_get_arrays(0), "xform": bank.global_transform,
		"surfaces": _bridge_walk_surfaces.duplicate(), "recessed": 0}
	_bank_fit_task = WorkerThreadPool.add_task(_fit_bank_job.bind(job), false, "park.bank_fit")
	return [bank, job]

func _finish_bank_fit(fit: Array) -> void:
	var _bt := StartupTrace.begin()
	if get_meta("shinrai_incremental_loading", false):
		while is_inside_tree() and not WorkerThreadPool.is_task_completed(_bank_fit_task):
			await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(_bank_fit_task)
	_bank_fit_task = -1
	StartupTrace.finish("park.bank_fit_wait", _bt)
	var bank: MeshInstance3D = fit[0]
	var job: Dictionary = fit[1]
	var fitted := ArrayMesh.new()
	fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,job.arrays)
	bank.mesh = fitted
	print("BRIDGE_BANK_CLEARANCE: recessed_vertices=%d total_vertices=%d" % [int(job.recessed),(job.arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()])

## Worker: what the main-thread loop did per vertex (bridge_surface_height on the
## same specs). Touches nothing but `job`.
static func _fit_bank_job(job: Dictionary) -> void:
	var arrays: Array = job.arrays
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var xform: Transform3D = job.xform
	var inverse := xform.affine_inverse()
	var surfaces: Array = job.surfaces
	var recessed := 0
	for index: int in range(vertices.size()):
		var world := xform*vertices[index]
		var p := Vector2(world.x,world.z)
		var floor_height := -INF
		for surface: Dictionary in surfaces:
			var height: float = BridgeWalks.height_at(surface.spec,p) if surface.kind == "deck" else BridgeLandings.height_at(surface.spec,p)
			floor_height = maxf(floor_height,height)
		if is_finite(floor_height) and world.y > floor_height-0.015:
			world.y = floor_height-0.015
			vertices[index] = inverse*world
			recessed += 1
	arrays[Mesh.ARRAY_VERTEX] = vertices
	job.recessed = recessed

func _add_shoreline_vertex(surface: SurfaceTool, point: Vector2, y_value: float, uv_value: Vector2) -> void:
	surface.set_normal(Vector3.UP)
	surface.set_uv(uv_value)
	surface.add_vertex(Vector3(point.x, y_value, point.y))

func _add_zone_label(parent: Node3D, text_value: String, position_value: Vector3, color_value: Color) -> void:
	if not SHOW_PLANNING_LABELS:
		return
	var label := Label3D.new()
	label.name = text_value.replace(" ", "_")
	label.text = text_value
	label.position = position_value
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.font_size = 72
	label.pixel_size = 0.012
	label.modulate = color_value
	label.outline_modulate = Color(0.02, 0.03, 0.035, 0.92)
	label.outline_size = 10
	parent.add_child(label)

func _add_visual_box(parent: Node3D, node_name: String, position_value: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.position = position_value
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_collidable_box(parent: Node3D, node_name: String, position_value: Vector3, size_value: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	parent.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)

func _spawn_scale_review_player() -> void:
	var player := PlayerScript.new()
	player.name = "ParkScaleReviewPlayer"
	player.position = Vector3(0.0, 0.05, WORLD_PARK_HALF.y - 20.0)
	player.rotation.y = 0.0
	add_child(player)

func _build_size_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	var label := Label.new()
	label.position = Vector2(22.0, 18.0)
	label.text = "MIDORI PARK — PROCEDURAL SCALE PASS\n440 m x 360 m | 2x concept recreation footprint\ncontinuous artwork lake | 7 islands | 3 installed bridges\n24 sakura accents | regenerated mainland groves | shoreline relocation\nNEON TORII PLAZA | 7 m landmark | 3 seats | 4 lamps | F3 fly mode"
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("#f4f1e8"))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)
	time_of_day_label = Label.new()
	time_of_day_label.position = Vector2(22.0, 156.0)
	time_of_day_label.add_theme_font_size_override("font_size", 17)
	time_of_day_label.add_theme_color_override("font_color", Color("#8fdfff"))
	time_of_day_label.add_theme_color_override("font_shadow_color", Color(0.0,0.0,0.0,0.9))
	time_of_day_label.add_theme_constant_override("shadow_offset_x", 2)
	time_of_day_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(time_of_day_label)
	_apply_time_of_day()


# Local corner rounding retains route anchors and limits shoreline displacement.
func _rounded_contour(source: Array[Vector2], closed: bool, radius: float, corner_fraction: float = 0.25) -> Array[Vector2]:
	var anchors: Array[Vector2] = source.duplicate()
	if closed and anchors[0].is_equal_approx(anchors[-1]):
		anchors.remove_at(anchors.size() - 1)
	var result: Array[Vector2] = []
	for i: int in range(anchors.size()):
		var current := anchors[i]
		if not closed and (i == 0 or i == anchors.size() - 1):
			result.append(current)
			continue
		var previous := anchors[posmod(i - 1, anchors.size())]
		var following := anchors[(i + 1) % anchors.size()]
		var trim := minf(radius, minf(current.distance_to(previous), current.distance_to(following)) * corner_fraction)
		var a := current.move_toward(previous, trim)
		var b := current.move_toward(following, trim)
		for step: int in range(7):
			var t := float(step) / 6.0
			result.append(a.lerp(current, t).lerp(current.lerp(b, t), t))
	if closed:
		result.append(result[0])
	return result

func _make_lake_water_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec2 p = world_position.xz;
    float a = dot(p, vec2(0.81, 0.47)) + TIME * 0.52;
    float b = dot(p, vec2(-1.13, 1.72)) - TIME * 0.38;
    float c = dot(p, vec2(2.67, 0.91)) + sin(p.y * 0.17) + TIME * 0.71;
    vec3 ripple = normalize(vec3(-0.016 * cos(a) + 0.010 * cos(b) - 0.006 * cos(c), 1.0,
                                -0.009 * cos(a) - 0.016 * cos(b) - 0.003 * cos(c)));
    NORMAL = normalize((VIEW_MATRIX * vec4(ripple, 0.0)).xyz);
    float variation = 0.5 + 0.5 * sin(p.x * 0.025 + sin(p.y * 0.035));
    ALBEDO = mix(vec3(0.012, 0.075, 0.110), vec3(0.025, 0.150, 0.200), variation);
    ROUGHNESS = 0.24;
    METALLIC = 0.0;
    SPECULAR = 0.5;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

# Shared paving preserves the supplied 2050 inlay and lighting artwork.
func _make_continuous_paving_material(mainland_warm: bool = true) -> ShaderMaterial:
	return WalkMaterials.build(3.68 if mainland_warm else 3.96)
