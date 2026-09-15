extends Node3D

# Procedural future-Japan town with the production SHINRAI dry road asset integrated directly into the generated street network.
# Keeps the path/search/patrol API used by enemy.gd so the ground AI can
# navigate the generated streets without a separate navigation scene.

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const WindowBayScene: PackedScene = preload("res://assets/shinrai/ProjectShinrai_WindowBay_v6_Modular.glb")
const RoofEaveScene: PackedScene = preload("res://assets/shinrai/ProjectShinrai_RoofEave_v17_Modular.glb")
const EaveSpotScene: PackedScene = preload("res://assets/shinrai/lighting/light02_concept_matched_v3/ProjectShinrai_Light02_ConceptMatched_v3_GodotYUp.glb")
const UnderEaveLEDScene: PackedScene = preload("res://assets/shinrai/lighting/light03_under_eave_led_v1/ProjectShinrai_Light03_UnderEaveLED_v1_GodotYUp.glb")
const YakitoriLanternScene: PackedScene = preload("res://assets/japanese_yakitori_lantern/japanese_yakitori_lantern.tscn")
const ShinraiRoadScene: PackedScene = preload("res://assets/environment/roads/shinrai_road/mesh/SHINRAI_Road_LP_Godot_YUp.glb")
const ShinraiRoadMaterial: Material = preload("res://assets/environment/roads/shinrai_road/godot/M_SHINRAI_Road_Dry.tres")
const PotholeRepairMaterial: Material = preload("res://assets/environment/roads/shinrai_road/repairs/M_SHINRAI_PotholeRepair.tres")
const CrackSealMaterial: Material = preload("res://assets/environment/roads/shinrai_road/repairs/M_SHINRAI_CrackSeal.tres")
const UtilityCutMaterial: Material = preload("res://assets/environment/roads/shinrai_road/repairs/M_SHINRAI_UtilityCut.tres")
const ManholeCoverMaterial: Material = preload("res://assets/environment/roads/shinrai_road/repairs/M_SHINRAI_ManholeCover.tres")
const ManholeCutMaterial: Material = preload("res://assets/environment/roads/shinrai_road/repairs/M_SHINRAI_ManholeCut.tres")
const CurbEdgeRepairMaterial: Material = preload("res://assets/environment/roads/shinrai_road/repairs/M_SHINRAI_CurbEdgeRepair.tres")
const CurbDrainScene: PackedScene = preload("res://assets/shinrai/drain_hgu150/ProjectShinrai_HGU150_Drain_GameReady.tscn")
const CurbDrainEndCapScene: PackedScene = preload("res://assets/shinrai/drain_hgu150/ProjectShinrai_HGU150_EndCap_GameReady.tscn")
const YakitoriShopBuildingScene: PackedScene = preload("res://assets/shinrai/buildings/yakitori_shop/artwork_replica_v6/ProjectShinrai_YakitoriShop_ArtworkReplica_v6.tscn")
const ApartmentConcreteShader: Shader = preload("res://assets/shinrai/buildings/apartment/materials/apartment_exposed_concrete.gdshader")
const ApartmentConcreteAlbedoTexture: Texture2D = preload("res://assets/environment/roads/shinrai_road/curb_drain/SHINRAI_CurbConcrete_Albedo_1K.png")
const ApartmentConcreteNormalTexture: Texture2D = preload("res://assets/environment/roads/shinrai_road/curb_drain/SHINRAI_CurbConcrete_NormalGL_1K.png")
const ApartmentConcreteOrmTexture: Texture2D = preload("res://assets/environment/roads/shinrai_road/curb_drain/SHINRAI_CurbConcrete_ORM_1K.png")

const GRID_WIDTH: int = 53
const GRID_HEIGHT: int = 53
const TILE_SIZE: float = 3.6
const GROUND_THICKNESS: float = 0.35
const ROAD_THICKNESS: float = 0.055
# Production SHINRAI road integration. The supplied game mesh is already Godot Y-up,
# exactly 3.10 m wide x 5.00 m long, and must stay at scale 1,1,1.
# Secondary streets use one strip. The wider main avenue uses three adjacent strips.
# No corrective X/Z rotation or rescaling is applied; only a Y-axis yaw is used to
# align the same authored road piece with horizontal streets.
const SHINRAI_ROAD_SURFACE_Y: float = ROAD_THICKNESS
const SHINRAI_ROAD_VERTICAL_UNDERLAY_DROP: float = 0.007
const SHINRAI_ROAD_WIDTH_M: float = 3.10
const SHINRAI_ROAD_LENGTH_M: float = 5.00
const SHINRAI_ROAD_SECONDARY_STRIPS: int = 1
const SHINRAI_ROAD_MAIN_STRIPS: int = 3
const SHINRAI_ROAD_LIGHTING_CHUNK_SIZE_M: float = 15.0
# Small repaired potholes break up the repeated road modules without changing
# navigation or collision. Their positions are fixed so the procedural RNG and
# the locked comparison street remain fully deterministic.
const POTHOLE_REPAIR_SURFACE_Y: float = SHINRAI_ROAD_SURFACE_Y + 0.0068
const POTHOLE_REPAIR_VISIBILITY_RANGE_M: float = 48.0
# Thin tar repairs sit just above the road and pothole decals. They are visual
# only, use fixed positions, and do not consume procedural RNG or add collision.
const CRACK_SEAL_SURFACE_Y: float = POTHOLE_REPAIR_SURFACE_Y + 0.0004
const CRACK_SEAL_VISIBILITY_RANGE_M: float = 42.0
# One locked-street utility-cut test stays isolated until its edge and tone are
# approved in the renderer. It is a visual decal only, with no collision.
const UTILITY_CUT_SURFACE_Y: float = CRACK_SEAL_SURFACE_Y + 0.0004
const UTILITY_CUT_VISIBILITY_RANGE_M: float = 44.0
# The manhole uses two flush visual layers: a feathered circular asphalt cut
# below a 65 cm cast-iron cover. Neither layer adds collision or RNG calls.
const MANHOLE_CUT_SURFACE_Y: float = UTILITY_CUT_SURFACE_Y + 0.0004
const MANHOLE_COVER_SURFACE_Y: float = MANHOLE_CUT_SURFACE_Y + 0.0005
const MANHOLE_VISIBILITY_RANGE_M: float = 46.0
# One close-range curb-edge repair test sits on the asphalt immediately beside
# the existing raised block edge. It adds no curb mesh, collision or RNG calls.
const CURB_EDGE_REPAIR_SURFACE_Y: float = SHINRAI_ROAD_SURFACE_Y + 0.0064
const CURB_EDGE_REPAIR_VISIBILITY_RANGE_M: float = 42.0
# v10.26y: the temporary box-built curb/drain test is replaced by the approved
# game-ready HGU150 asset. Eight exact 0.60 m modules form a 4.80 m run beside
# the locked commercial street. The authoring asset supplies true grate gaps,
# precast edge pieces, compacted asphalt transition, PBR materials and simple
# walkable `-colonly` collision without consuming procedural RNG.
const CURB_DRAIN_TEST_CENTER_X: float = 7.8
const CURB_DRAIN_TEST_ROAD_Z: float = 36.0
const CURB_DRAIN_MODULE_PITCH_M: float = 0.60
const CURB_DRAIN_MODULE_COUNT: int = 8
const CURB_DRAIN_END_CAP_LENGTH_M: float = 0.30
const CURB_DRAIN_CHANNEL_FROM_ROAD_EDGE_M: float = 0.097
const CURB_DRAIN_ROOT_Y: float = SHINRAI_ROAD_SURFACE_Y + 0.006
const CURB_DRAIN_VISIBILITY_RANGE_M: float = 48.0

const MAIN_ROAD_CENTER: int = 26
const ROAD_CENTERS: Array[int] = [4, 16, 26, 36, 48]
const SECONDARY_ROAD_HALF_WIDTH: int = 0
const MAIN_ROAD_HALF_WIDTH: int = 1
const MIN_BLOCK_CELLS: int = 4
const MIN_ENEMY_PATH_CELLS: int = 14
# Guarantee one first-wave K17 test encounter near the player while keeping a
# safe buffer and using only generated walkable, unblocked navigation cells.
const NEARBY_K17_TARGET_DISTANCE_M: float = 10.0
const NEARBY_K17_MIN_DISTANCE_M: float = 7.0
const NEARBY_K17_MAX_DISTANCE_M: float = 13.0
const VAN_COUNT: int = 2
const MAX_STREET_LIGHTS: int = 18
const MAX_INTERIOR_LIGHTS: int = 8
# Preserve the v10.17/v10.18 real-time light budget, but reserve most of it for
# occupied street-level businesses where the player can actually read the
# interiors from the road. The remaining two slots provide occasional lived-in
# residential/lobby light without starving the commercial frontage.
const MAX_SHOP_INTERIOR_LIGHTS: int = 6
const MAX_OTHER_INTERIOR_LIGHTS: int = 2
const ENTERABLE_HOUSE_CHANCE: float = 0.72
const ENTERABLE_SHOP_CHANCE: float = 0.92
const DETAIL_VISIBILITY_RANGE: float = 62.0
# v10.23a facade-depth trim remains deliberately closer-range than the
# older general detail kit. v10.24 keeps that geometry budget unchanged.
const FACADE_DETAIL_VISIBILITY_RANGE: float = 50.0
# v10.24 uses a very small number of close-range transparent reflection streaks.
# Keep them local because alpha blending is more expensive than opaque geometry.
const STOREFRONT_REFLECTION_VISIBILITY_RANGE: float = 28.0
const MAX_STOREFRONT_REFLECTION_SHOPS: int = 8
# v10.25d: cap the imported Blender window-bay test so the first runtime test
# can judge the art/scale without replacing every procedural facade at once.
const MAX_IMPORTED_WINDOW_BAYS: int = 24
const IMPORTED_WINDOW_BAY_VISIBILITY_RANGE: float = 52.0
# v10.25f keeps the imported roof/eave test deliberately tiny: these Blender
# modules are much denser than the procedural roof boxes, so attachment/material
# calibration must not turn into a city-wide replacement pass.
const MAX_IMPORTED_ROOF_EAVES: int = 6
const IMPORTED_ROOF_EAVE_VISIBILITY_RANGE: float = 44.0
# RoofEave v17 is authored with its front gutter at roughly source Y=-1.14.
# Keeping the module origin 0.52 m inside the procedural facade leaves about a
# 0.62 m street-side projection: layered, but no longer canopy-like.
const IMPORTED_ROOF_EAVE_ORIGIN_INSET: float = 0.52
# At that wall intersection the timber/rafter underside sits roughly 0.28-0.33 m
# above the asset origin. Dropping the root by 0.29 m seats that underside into
# the procedural wall top instead of leaving a visible floating gap.
const IMPORTED_ROOF_EAVE_WALL_CONTACT_DROP: float = 0.29
const FOLIAGE_VISIBILITY_RANGE: float = 74.0
const CABLE_VISIBILITY_RANGE: float = 70.0
# v10.25i: roadside poles/lights previously used offsets measured from the road
# centre without including the half-tile physical road edge consistently. On
# narrow streets that could place a pole almost exactly on the procedural
# facade plane. Keep hardware just outside the asphalt/curb edge, but well
# before the minimum generated facade depth.
const ROADSIDE_HARDWARE_OUTSET: float = 0.04

# v10.25k-v10.25m: lock one short central commercial side-street corridor for
# repeatable visual comparisons. The segment is the narrow east/west road at
# y=36 between the main avenue and the x=36 intersection. Its north street wall
# belongs to the commercial district, while the opposite side provides useful
# mixed-residential contrast. Keeping the seed and start view fixed makes
# wet/dry and light-budget comparisons meaningful across repeated launches.
const VISUAL_TEST_SEED: int = 102525
const VISUAL_TEST_SPAWN_CELL: Vector2i = Vector2i(32, 36)
const VISUAL_TEST_CORRIDOR_START: Vector2i = Vector2i(28, 36)
const VISUAL_TEST_CORRIDOR_END: Vector2i = Vector2i(36, 36)
# v10.25m: one deliberately local real-time contribution is allocated to the
# existing storefront fixture beside the locked starting view. The light is
# counted inside MAX_STREET_LIGHTS and remains shadowless; it is not a new art
# prop and does not alter facade/window geometry.
const VISUAL_TEST_STOREFRONT_LIGHT_MAX_DISTANCE: float = 14.0
const VISUAL_TEST_STOREFRONT_LIGHT_ENERGY: float = 0.56
const VISUAL_TEST_STOREFRONT_LIGHT_RANGE: float = 4.8
const VISUAL_TEST_NEARBY_LIGHT_AUDIT_RADIUS: float = 18.0
# v10.26d: keep the exact three-fixture supplemental street-light budget while
# swapping the locked-road modern test from the temporary wall lamp to the
# authored Light 03 recessed under-eave LED. Two renovated/contemporary
# storefronts receive Light 03 and one heritage storefront keeps Light 02.
# The approved v10.26c modern wall-lamp implementation remains in this script for
# later service entrances / utility bays, but it is deliberately not allocated on
# the locked comparison road in this pass.
const MAX_ACTIVE_UNDER_EAVE_LED_LIGHTS: int = 2
const UNDER_EAVE_LED_FIXTURE_VISIBILITY_RANGE: float = 40.0
const UNDER_EAVE_LED_LIGHT_ENERGY: float = 2.40
const UNDER_EAVE_LED_LIGHT_RANGE: float = 5.0
const UNDER_EAVE_LED_LIGHT_ANGLE_DEG: float = 58.0
const MAX_ACTIVE_MODERN_WALL_LIGHTS: int = 2
const MODERN_WALL_LIGHT_FIXTURE_VISIBILITY_RANGE: float = 38.0
const MODERN_WALL_LIGHT_ENERGY: float = 0.72
const MODERN_WALL_LIGHT_RANGE: float = 4.3
const MODERN_WALL_LIGHT_ANGLE_DEG: float = 58.0
const MAX_ACTIVE_EAVE_SPOT_LIGHTS: int = 1
const EAVE_SPOT_FIXTURE_VISIBILITY_RANGE: float = 34.0
const EAVE_SPOT_LIGHT_ENERGY: float = 0.90
const EAVE_SPOT_LIGHT_RANGE: float = 4.0
const EAVE_SPOT_LIGHT_ANGLE_DEG: float = 44.0

# v10.26g: authored hero lantern for the existing SHOP_IZAKAYA / yakitori-facing
# storefronts. The GLB remains at its authored real-world scale and local -Z
# lettering/front direction. Geometry is range-culled rather than replaced with
# a low-poly proxy, preserving the supplied master asset while containing its
# ~446k-triangle per-instance raster cost on the compatibility renderer.
const YAKITORI_LANTERN_VISIBILITY_RANGE: float = 30.0
const YAKITORI_LANTERN_VISIBILITY_MARGIN: float = 5.0
const YAKITORI_LANTERN_FALLBACK_LIGHT_ENERGY: float = 0.72
const YAKITORI_LANTERN_FALLBACK_LIGHT_RANGE: float = 2.5

# v10.32a: replace the complete procedural storefront root at the locked review
# position with the artwork-matched 4.20 m x 4.58 m two-storey Yakitori building.
# The GLB owns the shell, upper facade, roofline, rear elevation, materials and
# collision, so the former runtime architecture extension is no longer applied.
const YAKITORI_SHOP_ENTRANCE_LOCAL_Z: float = -0.72
# v10.32a: reserve three existing street-light slots for the artwork replica's
# authored recessed-canopy sockets. The town-wide light ceiling remains
# unchanged; these fixtures simply replace three generic road lights.
const YAKITORI_CANOPY_LIGHT_COUNT: int = 3
const YAKITORI_CANOPY_LIGHT_ENERGY: float = 0.46
const YAKITORI_CANOPY_LIGHT_RANGE: float = 4.2

const DISTRICT_TRADITIONAL: int = 0
const DISTRICT_RESIDENTIAL: int = 1
const DISTRICT_OVERGROWN: int = 2
const DISTRICT_COMMERCIAL: int = 3
const DISTRICT_LUXURY: int = 4

const BUILDING_TRADITIONAL: int = 0
const BUILDING_MODERN: int = 1
const BUILDING_SHOP: int = 2
const BUILDING_APARTMENT: int = 3
const BUILDING_TOWER: int = 4

# The supplied apartment and balcony sheets define one fixed real-world module.
# Two 3.00 m balcony bays plus their concrete piers require an 8.64 m frontage.
# The body is five 3.00 m storeys; rooftop service cores extend above that body.
const APARTMENT_REFERENCE_WIDTH_M: float = 8.64
const APARTMENT_REFERENCE_DEPTH_M: float = 6.60
const APARTMENT_REFERENCE_FLOOR_HEIGHT_M: float = 3.00
const APARTMENT_REFERENCE_FLOOR_COUNT: int = 5
const APARTMENT_REFERENCE_BODY_HEIGHT_M: float = 15.00

# Street-facing commercial archetypes. These share one procedural building
# system but get recognisable storefront/interior layouts instead of a generic
# shop room. Keep the kit lightweight so the v10.17 performance gains survive.
const SHOP_RAMEN: int = 0
const SHOP_IZAKAYA: int = 1
const SHOP_CONVENIENCE: int = 2
const SHOP_REPAIR: int = 3
const SHOP_RESIDENTIAL_MIX: int = 4
const SHOP_SHUTTERED: int = 5

# v10.26a-v10.26b: façade identity is separate from shop use. The locked road
# now tests three architectural ages side-by-side: preserved heritage, renovated
# old shells, and fully contemporary commercial frontage. Shop use/interiors stay
# procedural; façade selection itself consumes no RNG and remains local until the
# art direction is approved.
const SHOP_FACADE_HERITAGE: int = 0
const SHOP_FACADE_RENOVATED: int = 1
const SHOP_FACADE_CONTEMPORARY: int = 2

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]
const SPAWN_FACING_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, 1),
]

var player: CharacterBody3D
var wave: int = 1
var next_wave_timer: float = -1.0
var town_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var level_seed: int = 0
@export var generation_seed: int = 102525
@export var commercial_test_corridor_mode: bool = true
@export var dry_ground_comparison: bool = false

var walkable_lookup: Dictionary[Vector2i, bool] = {}
var blocked_lookup: Dictionary[Vector2i, bool] = {}
var walkable_cells: Array[Vector2i] = []
var road_cells: Array[Vector2i] = []
var town_blocks: Array[Rect2i] = []
var van_cells: Array[Vector2i] = []
var van_vertical: Array[bool] = []
var path_grid: AStarGrid2D = AStarGrid2D.new()
var player_spawn_cell: Vector2i = Vector2i(MAIN_ROAD_CENTER, 43)
var featured_park_block_index: int = -1

var geometry_root: Node3D
var static_root: Node3D
var decoration_root: Node3D
var vegetation_root: Node3D
var street_light_count: int = 0
var interior_light_count: int = 0
var shop_interior_light_count: int = 0
var other_interior_light_count: int = 0
var storefront_reflection_shop_count: int = 0
var imported_window_bay_count: int = 0
var imported_roof_eave_count: int = 0
var visual_test_storefront_light: OmniLight3D
var visual_test_storefront_light_target: String = ""
var visual_test_storefront_fixture_target: String = "EntranceLintel"
var active_eave_spot_count: int = 0
var active_under_eave_led_count: int = 0
var active_modern_wall_light_count: int = 0
var mat_ground: StandardMaterial3D
# Production SHINRAI road material. It is dry/matte and comes from the supplied
# Godot ORMMaterial3D resource; no legacy road shader or wetness stack remains.
var shinrai_road_material: Material
var mat_sidewalk: StandardMaterial3D
var mat_concrete: StandardMaterial3D
var mat_dark_concrete: StandardMaterial3D
# Apartment-only concrete calibration. It reuses the existing town concrete
# detail maps with a warmer exposed-formwork tint, keeping it distinct from
# the Yakitori plaster while matching the apartment reference sheet.
var mat_apartment_concrete: ShaderMaterial
var mat_apartment_concrete_recess: ShaderMaterial
var mat_wood: StandardMaterial3D
var mat_dark_wood: StandardMaterial3D
var mat_roof: StandardMaterial3D
# Shared Godot-side calibration materials for the imported RoofEave v17 kit.
# They intentionally avoid emission and real-time lights; the goal is to keep
# the asset readable while sitting in the same weathered night palette as the
# procedural facades.
var mat_imported_roof_tile: StandardMaterial3D
var mat_imported_roof_tile_dark: StandardMaterial3D
var mat_imported_roof_mortar: StandardMaterial3D
var mat_imported_roof_timber: StandardMaterial3D
var mat_imported_roof_timber_dark: StandardMaterial3D
var mat_imported_roof_rafter: StandardMaterial3D
var mat_imported_roof_plaster: StandardMaterial3D
var mat_imported_roof_gutter: StandardMaterial3D
var mat_glass: StandardMaterial3D
var mat_window_blue: StandardMaterial3D
var mat_window_warm: StandardMaterial3D
var mat_window_warm_dim: StandardMaterial3D
var mat_window_reveal_warm: StandardMaterial3D
var mat_window_shop_bright: StandardMaterial3D
var mat_black_metal: StandardMaterial3D
var mat_white: StandardMaterial3D
var mat_green: StandardMaterial3D
var mat_leaf_dark: StandardMaterial3D
var mat_trunk: StandardMaterial3D
var mat_neon_pink: StandardMaterial3D
var mat_neon_blue: StandardMaterial3D
var mat_neon_yellow: StandardMaterial3D
var mat_neon_red: StandardMaterial3D
var mat_sign_red: StandardMaterial3D
var mat_sign_pink: StandardMaterial3D
var mat_sign_blue: StandardMaterial3D
var mat_sign_warm: StandardMaterial3D
var mat_interior_task_warm: StandardMaterial3D
var mat_interior_bar_warm: StandardMaterial3D
var mat_interior_cool: StandardMaterial3D
var mat_counter_warm: StandardMaterial3D
var mat_backbar_glow: StandardMaterial3D
var mat_noren_red: StandardMaterial3D
var mat_menu_paper_warm: StandardMaterial3D
var mat_bottle_amber: StandardMaterial3D
var mat_sign_letter: StandardMaterial3D
var mat_storefront_glass_dark: StandardMaterial3D
var mat_storefront_glass_warm: StandardMaterial3D
var mat_storefront_glass_cool: StandardMaterial3D
var mat_window_dark_opaque: StandardMaterial3D
var mat_concrete_stained: StandardMaterial3D
var mat_concrete_cool: StandardMaterial3D
var mat_plaster_cool: StandardMaterial3D
var mat_plaster_soot: StandardMaterial3D
var mat_oxidized_metal: StandardMaterial3D
var mat_weathered_timber: StandardMaterial3D
var mat_weathered_metal: StandardMaterial3D
var mat_contemporary_panel: StandardMaterial3D
var mat_contemporary_panel_dark: StandardMaterial3D
var mat_contemporary_led: StandardMaterial3D
var mat_shop_plaster: StandardMaterial3D
var mat_storefront_apron: StandardMaterial3D
var mat_storefront_apron_dry: StandardMaterial3D
var mat_reflection_warm: StandardMaterial3D
var mat_reflection_red: StandardMaterial3D
var mat_reflection_cool: StandardMaterial3D
var mat_interior_wall_warm: StandardMaterial3D
var mat_interior_wall_dark: StandardMaterial3D
var mat_interior_wall_cool: StandardMaterial3D
var mat_asphalt_marking: StandardMaterial3D
var mat_tire: StandardMaterial3D
var mat_rust: StandardMaterial3D
var mat_plaster: StandardMaterial3D
var mat_dirty_plaster: StandardMaterial3D
var mat_tile: StandardMaterial3D
var mat_interior_wood: StandardMaterial3D
var mat_tatami: StandardMaterial3D
var mat_mountain: StandardMaterial3D
var mat_curb: StandardMaterial3D
var mat_soft_white: StandardMaterial3D
var mat_stone: StandardMaterial3D
var mat_stone_dark: StandardMaterial3D
var mat_blossom: StandardMaterial3D
var mat_blossom_dark: StandardMaterial3D
var mat_water: StandardMaterial3D

func _ready() -> void:
	# v10.25o keeps the v10.25k locked comparison configuration unchanged. The export
	# remains editable, but repeated launches of the supplied scene use the same
	# seed and the same short commercial-street start view.
	if generation_seed != 0:
		level_seed = generation_seed
	else:
		town_rng.randomize()
		level_seed = town_rng.randi()
	town_rng.seed = level_seed

	if commercial_test_corridor_mode:
		player_spawn_cell = VISUAL_TEST_SPAWN_CELL

	_build_environment()
	_build_materials()
	_create_roots()
	_generate_town_layout()
	_choose_van_cells()
	_configure_path_grid()
	_build_town_geometry()
	_apply_ground_comparison_mode(dry_ground_comparison)
	_spawn_player()
	_spawn_wave()
	_print_light_budget_audit()

	print(
		"Blacksite procedural Japanese town seed: %d | blocks: %d | vans: %d | featured park block: %d" % [
			level_seed,
			town_blocks.size(),
			van_cells.size(),
			featured_park_block_index,
		]
	)
	if commercial_test_corridor_mode:
		print(
			"v10.25o visual test corridor: cells %s -> %s | spawn %s | ground %s | F6 wet/dry" % [
				str(VISUAL_TEST_CORRIDOR_START),
				str(VISUAL_TEST_CORRIDOR_END),
				str(VISUAL_TEST_SPAWN_CELL),
				"DRY" if dry_ground_comparison else "WET",
			]
		)

func _build_environment() -> void:
	var world_env: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.048, 0.064, 0.092)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# v10.25h: the v10.25g runtime capture confirms the imported roof underside
	# is finally controlled, so the next correction can address the broader
	# problem: ordinary facades and alleys still collapse toward black. Lift the
	# cool ambient shadow floor while slightly reducing the directional key so
	# exposed roof planes do not flare pale against unreadable walls.
	env.ambient_light_color = Color(0.50, 0.58, 0.72)
	env.ambient_light_energy = 1.72
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color(0.20, 0.26, 0.36)
	env.fog_density = 0.0018
	world_env.environment = env
	add_child(world_env)

	# Keep the dusk direction, but soften the key again now that the ambient
	# floor carries more of the facade readability.
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "OvercastSun"
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun.light_color = Color(0.70, 0.78, 0.94)
	sun.light_energy = 0.80
	sun.shadow_enabled = true
	# The reference uses broad, readable architectural shadows. Keep balcony
	# occlusion, but soften its edge and let a controlled amount of ambient
	# light remain so concrete detail does not collapse into a black polygon.
	sun.shadow_blur = 3.40
	sun.shadow_opacity = 0.70
	# Keep the mood but avoid rendering the full 190 m town into the
	# directional shadow map every frame on the GL Compatibility renderer.
	sun.directional_shadow_max_distance = 72.0
	add_child(sun)

	var warm_fill: DirectionalLight3D = DirectionalLight3D.new()
	warm_fill.name = "LowWarmFill"
	warm_fill.rotation_degrees = Vector3(-18.0, 142.0, 0.0)
	warm_fill.light_color = Color(0.90, 0.46, 0.32)
	warm_fill.light_energy = 0.075
	warm_fill.shadow_enabled = false
	add_child(warm_fill)

func _build_materials() -> void:
	# Keep most surfaces neutral and rough. Neon is now an accent instead of
	# the dominant material, which removes the toy-like/cartoon appearance.
	mat_ground = _material(Color(0.082, 0.092, 0.080), 0.0, 0.96)
	# The road surface material is supplied by the production SHINRAI package.
	# Procedural storefront apron materials remain separate and unchanged.
	mat_sidewalk = _material(Color(0.165, 0.175, 0.188), 0.0, 0.80)
	mat_curb = _material(Color(0.115, 0.125, 0.138), 0.0, 0.86)
	# v10.25h: retain a visible blue-grey/brown facade floor in the deep side
	# streets seen in roddzz.mp4. These tiny matching emission floors are not
	# intended to look self-lit; they only stop Compatibility-renderer shadows
	# from erasing the material family completely.
	mat_concrete = _material(Color(0.205, 0.216, 0.230), 0.0, 0.92,
		Color(0.070, 0.080, 0.096), 0.035)
	mat_dark_concrete = _material(Color(0.160, 0.175, 0.198), 0.01, 0.88,
		Color(0.070, 0.084, 0.108), 0.070)
	# Apartment walls use one dedicated world-space material so texture scale
	# stays constant across every primitive. The shader adds the formwork grid,
	# tie holes, subtle runoff and ground grime present in the supplied sheet.
	var apartment_concrete_texture: Texture2D = load(
		"res://assets/procedural_textures/concrete_detail.png"
	) as Texture2D
	mat_apartment_concrete = ShaderMaterial.new()
	mat_apartment_concrete.shader = ApartmentConcreteShader
	mat_apartment_concrete.set_shader_parameter("concrete_texture", apartment_concrete_texture)
	mat_apartment_concrete.set_shader_parameter("concrete_albedo_texture", ApartmentConcreteAlbedoTexture)
	mat_apartment_concrete.set_shader_parameter("concrete_normal_texture", ApartmentConcreteNormalTexture)
	mat_apartment_concrete.set_shader_parameter("concrete_orm_texture", ApartmentConcreteOrmTexture)
	mat_apartment_concrete.set_shader_parameter("pbr_texture_scale", 0.92)
	mat_apartment_concrete.set_shader_parameter("pbr_detail_mix", 0.70)
	mat_apartment_concrete.set_shader_parameter("pbr_normal_strength", 0.24)
	mat_apartment_concrete.set_shader_parameter("concrete_tint", Color(0.305, 0.270, 0.225, 1.0))
	mat_apartment_concrete.set_shader_parameter("grime_tint", Color(0.055, 0.047, 0.035, 1.0))
	mat_apartment_concrete.set_shader_parameter("efflorescence_tint", Color(0.43, 0.40, 0.34, 1.0))
	mat_apartment_concrete.set_shader_parameter("algae_tint", Color(0.070, 0.073, 0.045, 1.0))
	mat_apartment_concrete.set_shader_parameter("texture_scale", 0.58)
	mat_apartment_concrete.set_shader_parameter("panel_width_m", 1.80)
	mat_apartment_concrete.set_shader_parameter("panel_height_m", 0.90)
	mat_apartment_concrete.set_shader_parameter("panel_strength", 0.085)
	mat_apartment_concrete.set_shader_parameter("tie_strength", 0.34)
	mat_apartment_concrete.set_shader_parameter("pore_strength", 0.14)
	mat_apartment_concrete.set_shader_parameter("crack_strength", 0.050)
	mat_apartment_concrete.set_shader_parameter("rain_strength", 0.060)
	mat_apartment_concrete.set_shader_parameter("efflorescence_strength", 0.075)
	mat_apartment_concrete.set_shader_parameter("grime_strength", 0.42)
	mat_apartment_concrete.set_shader_parameter("algae_strength", 0.10)
	mat_apartment_concrete.set_shader_parameter("grime_height_m", 1.18)
	mat_apartment_concrete.set_shader_parameter("detail_normal_strength", 0.40)
	mat_apartment_concrete.set_shader_parameter("joint_relief_strength", 0.64)
	mat_apartment_concrete.set_shader_parameter("panel_depth_variation", 0.008)
	mat_apartment_concrete.set_shader_parameter("ambient_lift", 0.012)

	mat_apartment_concrete_recess = ShaderMaterial.new()
	mat_apartment_concrete_recess.shader = ApartmentConcreteShader
	mat_apartment_concrete_recess.set_shader_parameter("concrete_texture", apartment_concrete_texture)
	mat_apartment_concrete_recess.set_shader_parameter("concrete_albedo_texture", ApartmentConcreteAlbedoTexture)
	mat_apartment_concrete_recess.set_shader_parameter("concrete_normal_texture", ApartmentConcreteNormalTexture)
	mat_apartment_concrete_recess.set_shader_parameter("concrete_orm_texture", ApartmentConcreteOrmTexture)
	mat_apartment_concrete_recess.set_shader_parameter("pbr_texture_scale", 0.92)
	mat_apartment_concrete_recess.set_shader_parameter("pbr_detail_mix", 0.60)
	mat_apartment_concrete_recess.set_shader_parameter("pbr_normal_strength", 0.20)
	mat_apartment_concrete_recess.set_shader_parameter("concrete_tint", Color(0.175, 0.150, 0.120, 1.0))
	mat_apartment_concrete_recess.set_shader_parameter("grime_tint", Color(0.040, 0.034, 0.026, 1.0))
	mat_apartment_concrete_recess.set_shader_parameter("efflorescence_tint", Color(0.32, 0.29, 0.24, 1.0))
	mat_apartment_concrete_recess.set_shader_parameter("algae_tint", Color(0.055, 0.058, 0.035, 1.0))
	mat_apartment_concrete_recess.set_shader_parameter("texture_scale", 0.62)
	mat_apartment_concrete_recess.set_shader_parameter("panel_width_m", 1.80)
	mat_apartment_concrete_recess.set_shader_parameter("panel_height_m", 0.90)
	mat_apartment_concrete_recess.set_shader_parameter("panel_strength", 0.055)
	mat_apartment_concrete_recess.set_shader_parameter("tie_strength", 0.24)
	mat_apartment_concrete_recess.set_shader_parameter("pore_strength", 0.11)
	mat_apartment_concrete_recess.set_shader_parameter("crack_strength", 0.025)
	mat_apartment_concrete_recess.set_shader_parameter("rain_strength", 0.025)
	mat_apartment_concrete_recess.set_shader_parameter("efflorescence_strength", 0.045)
	mat_apartment_concrete_recess.set_shader_parameter("grime_strength", 0.34)
	mat_apartment_concrete_recess.set_shader_parameter("algae_strength", 0.060)
	mat_apartment_concrete_recess.set_shader_parameter("grime_height_m", 1.12)
	mat_apartment_concrete_recess.set_shader_parameter("detail_normal_strength", 0.34)
	mat_apartment_concrete_recess.set_shader_parameter("joint_relief_strength", 0.48)
	mat_apartment_concrete_recess.set_shader_parameter("panel_depth_variation", 0.006)
	mat_apartment_concrete_recess.set_shader_parameter("ambient_lift", 0.006)
	mat_plaster = _material(Color(0.278, 0.263, 0.238), 0.0, 0.96,
		Color(0.092, 0.086, 0.076), 0.035)
	mat_dirty_plaster = _material(Color(0.230, 0.225, 0.216), 0.0, 0.98,
		Color(0.080, 0.080, 0.077), 0.035)
	mat_wood = _material(Color(0.225, 0.145, 0.084), 0.0, 0.95,
		Color(0.100, 0.056, 0.030), 0.045)
	mat_dark_wood = _material(Color(0.165, 0.105, 0.064), 0.0, 0.96,
		Color(0.090, 0.052, 0.030), 0.075)
	# Procedural fallback roofs were still catching the key as pale slabs in the
	# upward-looking capture. Make them rougher/less specular while leaving the
	# separately calibrated imported RoofEave v17 materials untouched.
	mat_roof = _material(Color(0.090, 0.102, 0.118), 0.03, 0.86)
	mat_roof.metallic_specular = 0.28
	mat_tile = _material(Color(0.122, 0.136, 0.150), 0.02, 0.84)
	mat_tile.metallic_specular = 0.30

	# v10.25g: runtime footage from v10.25f showed that attachment is now
	# substantially better, but the imported backing/mortar still lifts into a
	# pale continuous band from low street angles. Keep the GLB untouched and
	# push only the imported roof response deeper into the soot-grey / aged
	# timber range. This is deliberately local: no environment/light-budget
	# change is used to hide the problem.
	mat_imported_roof_tile = _material(Color(0.058, 0.067, 0.080), 0.035, 0.86)
	mat_imported_roof_tile_dark = _material(Color(0.034, 0.040, 0.050), 0.04, 0.90)
	mat_imported_roof_mortar = _material(Color(0.056, 0.054, 0.052), 0.0, 0.98)
	mat_imported_roof_timber = _material(Color(0.074, 0.039, 0.019), 0.0, 0.97)
	mat_imported_roof_timber_dark = _material(Color(0.040, 0.022, 0.013), 0.0, 0.99)
	mat_imported_roof_rafter = _material(Color(0.082, 0.043, 0.020), 0.0, 0.97)
	mat_imported_roof_plaster = _material(Color(0.037, 0.040, 0.046), 0.0, 1.0)
	mat_imported_roof_gutter = _material(Color(0.035, 0.041, 0.051), 0.32, 0.84)
	# Suppress grazing/specular lift on the broad underside/backing surfaces.
	# The roof should be readable through silhouette and timber layering, not
	# because a large flat backing plane catches the dusk key.
	mat_imported_roof_plaster.metallic_specular = 0.10
	mat_imported_roof_mortar.metallic_specular = 0.12
	mat_imported_roof_timber.metallic_specular = 0.18
	mat_imported_roof_timber_dark.metallic_specular = 0.16
	mat_imported_roof_rafter.metallic_specular = 0.18

	mat_glass = _material(Color(0.060, 0.092, 0.115, 0.43), 0.04, 0.18)
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Most upper-floor windows are now opaque dark glass. This avoids hundreds
	# of unnecessary alpha-blended panes while keeping real storefront/lobby
	# glazing transparent where seeing into the room matters.
	mat_window_dark_opaque = _material(Color(0.065, 0.090, 0.118), 0.025, 0.30)
	mat_window_dark_opaque.metallic_specular = 0.58
	mat_window_blue = _material(
		Color(0.065, 0.092, 0.115), 0.03, 0.34,
		Color(0.12, 0.24, 0.38), 0.20
	)
	mat_window_warm = _material(
		Color(0.155, 0.105, 0.060), 0.01, 0.40,
		Color(0.84, 0.36, 0.13), 0.25
	)
	mat_window_warm_dim = _material(
		Color(0.110, 0.077, 0.050), 0.01, 0.44,
		Color(0.64, 0.25, 0.085), 0.15
	)
	# A very low-energy warm reveal sits immediately behind selected occupied
	# upper-floor frames. It is not a light; it only prevents warm panes from
	# reading as pasted rectangles against a black wall.
	mat_window_reveal_warm = _material(
		Color(0.150, 0.095, 0.056), 0.0, 0.92,
		Color(0.28, 0.105, 0.035), 0.060
	)
	mat_window_shop_bright = _material(
		Color(0.175, 0.118, 0.066), 0.01, 0.36,
		Color(0.92, 0.43, 0.16), 0.42
	)
	mat_black_metal = _material(Color(0.108, 0.122, 0.140), 0.30, 0.76,
		Color(0.055, 0.069, 0.088), 0.055)
	mat_white = _material(Color(0.72, 0.72, 0.69), 0.0, 0.84)
	mat_soft_white = _material(Color(0.235, 0.245, 0.255), 0.0, 0.95)
	mat_green = _material(Color(0.052, 0.125, 0.062), 0.0, 0.98)
	mat_leaf_dark = _material(Color(0.040, 0.110, 0.055), 0.0, 1.0)
	mat_mountain = _material(Color(0.085, 0.13, 0.115), 0.0, 1.0)
	mat_trunk = _material(Color(0.14, 0.092, 0.052), 0.0, 0.98)
	mat_interior_wood = _material(Color(0.265, 0.178, 0.108), 0.0, 0.88,
		Color(0.165, 0.078, 0.033), 0.065)
	mat_tatami = _material(Color(0.47, 0.45, 0.27), 0.0, 0.96)
	mat_neon_pink = _material(
		Color(0.24, 0.045, 0.16), 0.02, 0.28,
		Color(1.0, 0.06, 0.52), 2.15
	)
	mat_neon_blue = _material(
		Color(0.035, 0.12, 0.20), 0.02, 0.28,
		Color(0.05, 0.48, 0.95), 1.95
	)
	mat_neon_yellow = _material(
		Color(0.18, 0.135, 0.075), 0.02, 0.30,
		Color(1.0, 0.66, 0.40), 0.92
	)
	mat_neon_red = _material(
		Color(0.23, 0.035, 0.026), 0.02, 0.34,
		Color(1.0, 0.08, 0.04), 1.95
	)
	# Physical storefront sign materials: brighter surface albedo and much
	# lower emission than the skyline/neon accent kit. The sign remains a
	# readable object instead of clipping into a white emissive rectangle.
	mat_sign_red = _material(
		Color(0.245, 0.043, 0.038), 0.01, 0.56,
		Color(0.78, 0.055, 0.038), 0.34
	)
	mat_sign_pink = _material(
		Color(0.215, 0.045, 0.135), 0.01, 0.54,
		Color(0.80, 0.055, 0.40), 0.34
	)
	mat_sign_blue = _material(
		Color(0.040, 0.108, 0.160), 0.01, 0.52,
		Color(0.055, 0.34, 0.62), 0.32
	)
	mat_sign_warm = _material(
		Color(0.265, 0.218, 0.175), 0.0, 0.64,
		Color(0.64, 0.40, 0.24), 0.22
	)
	# Cheap emissive fixtures provide interior identity even when a shop is not
	# one of the six businesses that receives a real OmniLight3D.
	mat_interior_task_warm = _material(
		Color(0.28, 0.19, 0.10), 0.0, 0.42,
		Color(1.0, 0.52, 0.22), 0.52
	)
	mat_interior_bar_warm = _material(
		Color(0.19, 0.105, 0.058), 0.0, 0.50,
		Color(0.95, 0.30, 0.10), 0.36
	)
	mat_interior_cool = _material(
		Color(0.15, 0.18, 0.19), 0.0, 0.40,
		Color(0.54, 0.68, 0.74), 0.44
	)
	# v10.24: key shop surfaces carry more of the readable mid-tones while the
	# fixture strips are slightly less dominant. This reveals counters/shelves
	# without adding any real-time lights or shadow cost.
	mat_counter_warm = _material(
		Color(0.415, 0.245, 0.132), 0.0, 0.78,
		Color(0.62, 0.24, 0.072), 0.16
	)
	mat_backbar_glow = _material(
		Color(0.265, 0.150, 0.075), 0.0, 0.76,
		Color(0.72, 0.22, 0.060), 0.18
	)
	mat_noren_red = _material(
		Color(0.20, 0.030, 0.028), 0.0, 0.94,
		Color(0.48, 0.045, 0.028), 0.06
	)
	mat_menu_paper_warm = _material(
		Color(0.46, 0.355, 0.238), 0.0, 0.88,
		Color(0.52, 0.24, 0.092), 0.12
	)
	mat_bottle_amber = _material(
		Color(0.12, 0.060, 0.028), 0.06, 0.32,
		Color(0.38, 0.11, 0.025), 0.05
	)
	mat_sign_letter = _material(
		Color(0.68, 0.59, 0.46), 0.0, 0.72,
		Color(0.94, 0.46, 0.20), 0.44
	)
	# v10.24: keep storefront glazing transparent and make it slightly clearer
	# so the existing interior geometry survives the night treatment from the
	# pavement instead of disappearing behind dark tinted panes.
	mat_storefront_glass_dark = _material(Color(0.040, 0.060, 0.072, 0.26), 0.05, 0.16)
	mat_storefront_glass_dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_storefront_glass_warm = _material(
		Color(0.082, 0.058, 0.040, 0.22), 0.04, 0.17,
		Color(0.64, 0.24, 0.075), 0.10
	)
	mat_storefront_glass_warm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_storefront_glass_cool = _material(
		Color(0.045, 0.072, 0.088, 0.23), 0.04, 0.17,
		Color(0.16, 0.34, 0.46), 0.08
	)
	mat_storefront_glass_cool.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Shared facade families now carry the same restrained shadow-floor logic as
	# the base materials. This is the main v10.25h readability change: it affects
	# the actual building bodies seen at normal gameplay distance, not the light
	# budget or procedural density.
	mat_concrete_stained = _material(Color(0.198, 0.212, 0.230), 0.0, 0.95,
		Color(0.064, 0.077, 0.098), 0.040)
	mat_concrete_cool = _material(Color(0.186, 0.207, 0.235), 0.0, 0.95,
		Color(0.060, 0.075, 0.100), 0.045)
	mat_plaster_cool = _material(Color(0.236, 0.249, 0.265), 0.0, 0.97,
		Color(0.077, 0.085, 0.100), 0.040)
	mat_plaster_soot = _material(Color(0.210, 0.218, 0.232), 0.0, 0.99,
		Color(0.078, 0.089, 0.108), 0.060)
	mat_oxidized_metal = _material(Color(0.160, 0.170, 0.184), 0.38, 0.78,
		Color(0.055, 0.064, 0.076), 0.050)

	# A small shop-specific material kit gives the frontage a recognisably old
	# Japanese construction language without a city-wide prop/node explosion.
	mat_weathered_timber = _material(Color(0.186, 0.112, 0.068), 0.0, 0.97,
		Color(0.100, 0.056, 0.031), 0.070)
	mat_weathered_metal = _material(Color(0.150, 0.162, 0.178), 0.34, 0.78,
		Color(0.052, 0.061, 0.075), 0.050)
	# v10.26b contemporary frontage: cleaner manufactured panels and a restrained
	# neutral-white integrated LED material. These are deliberately brighter in
	# albedo than the heritage timber so the architectural age reads under the
	# existing night environment without adding another real-time light.
	mat_contemporary_panel = _material(Color(0.315, 0.335, 0.360), 0.06, 0.74,
		Color(0.075, 0.090, 0.115), 0.045)
	mat_contemporary_panel_dark = _material(Color(0.105, 0.125, 0.150), 0.28, 0.68,
		Color(0.040, 0.055, 0.078), 0.040)
	mat_contemporary_led = _material(
		Color(0.285, 0.315, 0.335), 0.0, 0.38,
		Color(0.68, 0.78, 0.86), 0.46
	)
	mat_shop_plaster = _material(Color(0.252, 0.242, 0.224), 0.0, 0.97,
		Color(0.090, 0.085, 0.075), 0.040)
	mat_storefront_apron = _material(Color(0.118, 0.136, 0.162), 0.01, 0.46)
	mat_storefront_apron.metallic_specular = 0.48
	mat_storefront_apron.roughness_texture = load("res://assets/procedural_textures/asphalt_roughness_v24.png")
	# v10.25l: the frontage apron participates in the same moisture A/B as the
	# road. Keep its geometry and colour fixed, but give DRY mode the rough,
	# low-specular response that the comparison road receives.
	mat_storefront_apron_dry = _material(Color(0.118, 0.136, 0.162), 0.0, 0.84)
	mat_storefront_apron_dry.metallic_specular = 0.28

	# A handful of close-range fake reflection streaks supply the coloured wet
	# response that emissive signs cannot create by themselves in Compatibility.
	# They are shared materials, shadowless, alpha-blended and capped at 8 shops.
	mat_reflection_warm = _material(Color(0.30, 0.115, 0.045, 0.085), 0.0, 0.68,
		Color(0.64, 0.18, 0.045), 0.075)
	mat_reflection_warm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_reflection_red = _material(Color(0.32, 0.034, 0.030, 0.075), 0.0, 0.70,
		Color(0.68, 0.042, 0.030), 0.085)
	mat_reflection_red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_reflection_cool = _material(Color(0.040, 0.105, 0.160, 0.070), 0.0, 0.68,
		Color(0.050, 0.25, 0.44), 0.070)
	mat_reflection_cool.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Shared interior wall liners retain enough colour to make the existing shop
	# layouts legible from the pavement without increasing OmniLight3D count.
	mat_interior_wall_warm = _material(Color(0.305, 0.238, 0.174), 0.0, 0.94,
		Color(0.25, 0.110, 0.046), 0.080)
	mat_interior_wall_dark = _material(Color(0.155, 0.095, 0.062), 0.0, 0.96,
		Color(0.14, 0.054, 0.026), 0.065)
	mat_interior_wall_cool = _material(Color(0.218, 0.238, 0.250), 0.0, 0.91,
		Color(0.092, 0.140, 0.166), 0.055)
	mat_asphalt_marking = _material(Color(0.72, 0.72, 0.66), 0.0, 0.72)
	mat_tire = _material(Color(0.025, 0.027, 0.030), 0.0, 0.94)
	mat_rust = _material(Color(0.27, 0.10, 0.045), 0.05, 0.94)
	mat_stone = _material(Color(0.24, 0.255, 0.26), 0.0, 0.96)
	mat_stone_dark = _material(Color(0.115, 0.125, 0.13), 0.0, 0.98)
	mat_blossom = _material(Color(0.34, 0.145, 0.205), 0.0, 0.98)
	mat_blossom_dark = _material(Color(0.19, 0.072, 0.115), 0.0, 1.0)
	mat_water = _material(Color(0.035, 0.075, 0.10, 0.78), 0.03, 0.10)
	mat_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Small generated detail maps break up the perfectly flat primitive colors
	# without adding a large external asset pack.
	_apply_detail_texture(mat_sidewalk, "res://assets/procedural_textures/concrete_detail.png", 2.2)
	_apply_detail_texture(mat_curb, "res://assets/procedural_textures/concrete_detail.png", 2.0)
	_apply_detail_texture(mat_concrete, "res://assets/procedural_textures/concrete_detail.png", 2.5)
	_apply_detail_texture(mat_dark_concrete, "res://assets/procedural_textures/concrete_detail.png", 2.8)
	_apply_detail_texture(mat_plaster, "res://assets/procedural_textures/plaster_detail.png", 2.0)
	_apply_detail_texture(mat_dirty_plaster, "res://assets/procedural_textures/plaster_detail.png", 2.2)
	_apply_detail_texture(mat_wood, "res://assets/procedural_textures/wood_detail.png", 2.0)
	_apply_detail_texture(mat_dark_wood, "res://assets/procedural_textures/wood_detail.png", 2.4)
	_apply_detail_texture(mat_weathered_timber, "res://assets/procedural_textures/wood_detail.png", 2.7)
	_apply_detail_texture(mat_weathered_metal, "res://assets/procedural_textures/metal_weathered_v22.png", 2.6)
	_apply_detail_texture(mat_contemporary_panel, "res://assets/procedural_textures/concrete_detail.png", 2.9)
	_apply_detail_texture(mat_contemporary_panel_dark, "res://assets/procedural_textures/metal_weathered_v22.png", 3.1)
	_apply_detail_texture(mat_shop_plaster, "res://assets/procedural_textures/plaster_stained_v22.png", 2.35)
	_apply_detail_texture(mat_storefront_apron, "res://assets/procedural_textures/asphalt_detail.png", 2.6)
	_apply_detail_texture(mat_storefront_apron_dry, "res://assets/procedural_textures/asphalt_detail.png", 2.6)
	_apply_detail_texture(mat_concrete_stained, "res://assets/procedural_textures/concrete_stained_v22.png", 2.35)
	_apply_detail_texture(mat_concrete_cool, "res://assets/procedural_textures/concrete_stained_v22.png", 2.55)
	_apply_detail_texture(mat_plaster_cool, "res://assets/procedural_textures/plaster_stained_v22.png", 2.15)
	_apply_detail_texture(mat_plaster_soot, "res://assets/procedural_textures/plaster_stained_v22.png", 2.55)
	_apply_detail_texture(mat_oxidized_metal, "res://assets/procedural_textures/metal_weathered_v22.png", 2.8)
	_apply_detail_texture(mat_roof, "res://assets/procedural_textures/roof_detail.png", 2.2)
	_apply_detail_texture(mat_tile, "res://assets/procedural_textures/roof_detail.png", 2.0)
	_apply_detail_texture(mat_ground, "res://assets/procedural_textures/moss_detail.png", 3.0)
	_apply_detail_texture(mat_green, "res://assets/procedural_textures/moss_detail.png", 2.5)
	_apply_detail_texture(mat_stone, "res://assets/procedural_textures/concrete_detail.png", 2.1)
	_apply_detail_texture(mat_stone_dark, "res://assets/procedural_textures/concrete_detail.png", 2.4)

	_build_shinrai_road_material()

func _build_shinrai_road_material() -> void:
	# Production dry asphalt. Repair decals use their own authored PBR materials.
	shinrai_road_material = ShinraiRoadMaterial

func _material(
	color: Color,
	metallic: float = 0.0,
	roughness: float = 0.65,
	emission: Color = Color(0.0, 0.0, 0.0),
	emission_energy: float = 0.0
) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat

func _apply_detail_texture(material: StandardMaterial3D, texture_path: String, repeat_scale: float) -> void:
	material.albedo_texture = load(texture_path)
	material.uv1_scale = Vector3(repeat_scale, repeat_scale, repeat_scale)

func _choose_traditional_wall_material(district: int) -> Material:
	if district == DISTRICT_OVERGROWN:
		return mat_dirty_plaster if town_rng.randf() < 0.68 else mat_plaster_soot
	var roll: float = town_rng.randf()
	if roll < 0.46:
		return mat_plaster
	if roll < 0.76:
		return mat_plaster_cool
	return mat_plaster_soot

func _choose_modern_body_material(district: int) -> Material:
	if district == DISTRICT_LUXURY:
		return mat_dark_concrete
	if district == DISTRICT_OVERGROWN:
		return mat_dirty_plaster if town_rng.randf() < 0.58 else mat_concrete_stained
	var roll: float = town_rng.randf()
	if roll < 0.38:
		return mat_concrete_stained
	if roll < 0.67:
		return mat_concrete
	if roll < 0.86:
		return mat_concrete_cool
	return mat_plaster_cool

func _choose_apartment_body_material(district: int) -> Material:
	if district == DISTRICT_LUXURY:
		return mat_dark_concrete
	var roll: float = town_rng.randf()
	if district == DISTRICT_OVERGROWN and roll < 0.50:
		return mat_concrete_stained
	if roll < 0.48:
		return mat_concrete_stained
	if roll < 0.78:
		return mat_concrete
	return mat_concrete_cool

func _create_roots() -> void:
	geometry_root = Node3D.new()
	geometry_root.name = "ProceduralTownGeometry"
	add_child(geometry_root)

	static_root = Node3D.new()
	static_root.name = "ProceduralTownCollision"
	add_child(static_root)

	decoration_root = Node3D.new()
	decoration_root.name = "TownDecoration"
	add_child(decoration_root)

	vegetation_root = Node3D.new()
	vegetation_root.name = "TownVegetation"
	add_child(vegetation_root)

func _generate_town_layout() -> void:
	walkable_lookup.clear()
	blocked_lookup.clear()
	walkable_cells.clear()
	road_cells.clear()
	town_blocks.clear()
	van_cells.clear()
	van_vertical.clear()

	for y: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if _is_road_cell(cell):
				_mark_walkable(cell)
				road_cells.append(cell)

	var x_spans: Array[Vector2i] = _collect_non_road_spans(GRID_WIDTH)
	var y_spans: Array[Vector2i] = _collect_non_road_spans(GRID_HEIGHT)
	for x_span: Vector2i in x_spans:
		for y_span: Vector2i in y_spans:
			var width_cells: int = x_span.y - x_span.x
			var height_cells: int = y_span.y - y_span.x
			if width_cells < MIN_BLOCK_CELLS or height_cells < MIN_BLOCK_CELLS:
				continue
			town_blocks.append(
				Rect2i(x_span.x, y_span.x, width_cells, height_cells)
			)

	if not _is_walkable(player_spawn_cell):
		player_spawn_cell = _nearest_walkable_cell(player_spawn_cell, false)

func _collect_non_road_spans(axis_size: int) -> Array[Vector2i]:
	var spans: Array[Vector2i] = []
	var span_start: int = -1
	for index: int in range(axis_size):
		var road_axis: bool = _is_road_axis(index)
		if not road_axis and span_start < 0:
			span_start = index
		elif road_axis and span_start >= 0:
			if index - span_start >= MIN_BLOCK_CELLS:
				spans.append(Vector2i(span_start, index))
			span_start = -1
	if span_start >= 0 and axis_size - span_start >= MIN_BLOCK_CELLS:
		spans.append(Vector2i(span_start, axis_size))
	return spans

func _is_road_axis(index: int) -> bool:
	for center: int in ROAD_CENTERS:
		var half_width: int = (
			MAIN_ROAD_HALF_WIDTH
			if center == MAIN_ROAD_CENTER
			else SECONDARY_ROAD_HALF_WIDTH
		)
		if absi(index - center) <= half_width:
			return true
	return false

func _is_road_cell(cell: Vector2i) -> bool:
	return _is_road_axis(cell.x) or _is_road_axis(cell.y)

func _is_intersection_cell(cell: Vector2i) -> bool:
	return _is_road_axis(cell.x) and _is_road_axis(cell.y)

func _mark_walkable(cell: Vector2i) -> void:
	if walkable_lookup.has(cell):
		return
	walkable_lookup[cell] = true
	walkable_cells.append(cell)

func _is_walkable(cell: Vector2i) -> bool:
	return walkable_lookup.has(cell)

func _is_navigation_walkable(cell: Vector2i) -> bool:
	return walkable_lookup.has(cell) and not blocked_lookup.has(cell)

func _choose_van_cells() -> void:
	var candidates: Array[Vector2i] = []
	var near_spawn_candidates: Array[Vector2i] = []
	for cell: Vector2i in road_cells:
		if _is_intersection_cell(cell):
			continue
		var spawn_distance: int = _manhattan(cell, player_spawn_cell)
		if spawn_distance < 6:
			continue
		var vertical: bool = _is_road_axis(cell.x) and not _is_road_axis(cell.y)
		var horizontal: bool = _is_road_axis(cell.y) and not _is_road_axis(cell.x)
		if not vertical and not horizontal:
			continue
		candidates.append(cell)

		# Guarantee one van is discoverable shortly after spawning instead of
		# allowing both vehicles to land on distant back streets.
		if (
			vertical
			and absi(cell.x - MAIN_ROAD_CENTER) <= 1
			and spawn_distance <= 10
		):
			near_spawn_candidates.append(cell)

	_shuffle_cells(near_spawn_candidates)
	_shuffle_cells(candidates)

	if not near_spawn_candidates.is_empty():
		var first_van: Vector2i = near_spawn_candidates[0]
		van_cells.append(first_van)
		van_vertical.append(true)
		blocked_lookup[first_van] = true

	for cell: Vector2i in candidates:
		if van_cells.size() >= VAN_COUNT:
			break
		if van_cells.has(cell):
			continue
		var separated: bool = true
		for existing: Vector2i in van_cells:
			if _manhattan(cell, existing) < 12:
				separated = false
				break
		if not separated:
			continue
		var is_vertical: bool = _is_road_axis(cell.x) and not _is_road_axis(cell.y)
		van_cells.append(cell)
		van_vertical.append(is_vertical)
		blocked_lookup[cell] = true

func _configure_path_grid() -> void:
	path_grid.clear()
	path_grid.region = Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	path_grid.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	path_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	path_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	path_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	path_grid.update()

	for y: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if not _is_navigation_walkable(cell):
				path_grid.set_point_solid(cell, true)

func _build_town_geometry() -> void:
	var town_width: float = float(GRID_WIDTH) * TILE_SIZE
	var town_depth: float = float(GRID_HEIGHT) * TILE_SIZE

	var ground_body: StaticBody3D = StaticBody3D.new()
	ground_body.name = "TownGround"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 0
	static_root.add_child(ground_body)
	_add_collision_box(
		ground_body,
		Vector3(0.0, -GROUND_THICKNESS * 0.5, 0.0),
		Vector3(town_width + 36.0, GROUND_THICKNESS, town_depth + 36.0)
	)
	_add_visual_box(
		geometry_root,
		"GroundVisual",
		Vector3(0.0, -GROUND_THICKNESS * 0.48, 0.0),
		Vector3(town_width + 36.0, GROUND_THICKNESS, town_depth + 36.0),
		mat_ground
	)

	_build_shinrai_road_network()
	_build_pothole_repairs()
	_build_crack_seals()
	_build_utility_cut_repair()
	_build_manhole_test()
	_build_curb_edge_repair_test()
	_build_curb_drain_test()
	_build_block_sidewalks()
	# Production SHINRAI road is intentionally unmarked.
	_build_city_blocks()
	_replace_visual_test_storefront_with_yakitori_shop()
	_build_utility_poles_and_cables()
	_build_street_lights()
	_build_visual_test_storefront_lamp_coverage()
	_build_commercial_under_eave_led_lighting()
	# v10.26c modern wall-lamp builder is intentionally retained but dormant on
	# this locked road. It remains available for later utility/service contexts.
	_build_commercial_eave_spot_lighting()
	_build_street_furniture()
	_build_vans()
	_build_distant_skyline()

func _build_shinrai_road_network() -> void:
	# The town remains procedural, but visible asphalt now comes only from the
	# supplied SHINRAI game-ready mesh. The mesh is never rescaled.
	var road_mesh: Mesh = _shinrai_extract_road_mesh()
	if road_mesh == null:
		push_error("SHINRAI: could not extract MeshInstance3D from supplied road GLB")
		return
	if shinrai_road_material == null:
		push_error("SHINRAI: production road material is not available")
		return

	var road_span_m: float = float(GRID_WIDTH) * TILE_SIZE
	var length_count: int = int(ceil(road_span_m / SHINRAI_ROAD_LENGTH_M))
	var first_length_center: float = -float(length_count - 1) * SHINRAI_ROAD_LENGTH_M * 0.5

	var horizontal_transforms: Array[Transform3D] = []
	var vertical_transforms: Array[Transform3D] = []
	var horizontal_basis: Basis = Basis(Vector3.UP, PI * 0.5)

	for road_axis: int in ROAD_CENTERS:
		var road_center: float = _shinrai_road_axis_world(road_axis)
		var strip_count: int = _shinrai_road_strip_count(road_axis)
		var lateral_start: float = -float(strip_count - 1) * SHINRAI_ROAD_WIDTH_M * 0.5

		for strip_index: int in range(strip_count):
			var lateral: float = lateral_start + float(strip_index) * SHINRAI_ROAD_WIDTH_M
			for length_index: int in range(length_count):
				var along: float = first_length_center + float(length_index) * SHINRAI_ROAD_LENGTH_M

				# Local +Z is the supplied road's 5 m length. Yawing around +Y is
				# layout rotation only; it is not a coordinate-system correction.
				horizontal_transforms.append(Transform3D(
					horizontal_basis,
					Vector3(along, SHINRAI_ROAD_SURFACE_Y, road_center + lateral)
				))

				# Vertical strips sit 7 mm lower. The supplied relief tops out at
				# about 5.65 mm, so this cleanly prevents z-fighting/poke-through
				# at crossings while the horizontal road remains the visible top.
				vertical_transforms.append(Transform3D(
					Basis.IDENTITY,
					Vector3(
						road_center + lateral,
						SHINRAI_ROAD_SURFACE_Y - SHINRAI_ROAD_VERTICAL_UNDERLAY_DROP,
						along
					)
				))

	_shinrai_create_road_multimeshes("SHINRAI_Road_H", road_mesh, horizontal_transforms)
	_shinrai_create_road_multimeshes("SHINRAI_Road_V", road_mesh, vertical_transforms)

	print(
		"SHINRAI road: %d production mesh instances | 3.10m x 5.00m | scale 1,1,1 | dry PBR" %
		(horizontal_transforms.size() + vertical_transforms.size())
	)

func _shinrai_extract_road_mesh() -> Mesh:
	var temporary: Node = ShinraiRoadScene.instantiate()
	if temporary == null:
		return null
	var mesh_instance: MeshInstance3D = _shinrai_find_mesh_instance(temporary)
	if mesh_instance == null or mesh_instance.mesh == null:
		temporary.free()
		return null
	var mesh_copy: Mesh = mesh_instance.mesh.duplicate() as Mesh
	temporary.free()
	return mesh_copy

func _shinrai_find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var found: MeshInstance3D = _shinrai_find_mesh_instance(child)
		if found != null:
			return found
	return null

func _shinrai_create_road_multimeshes(
	instance_prefix: String,
	road_mesh: Mesh,
	transforms: Array[Transform3D]
) -> void:
	# Spatial batches retain MultiMesh efficiency without making the entire town
	# one GeometryInstance3D, which is important for practical-light limits in
	# the Compatibility renderer.
	var chunk_buckets: Dictionary = {}
	for transform_value: Transform3D in transforms:
		var origin: Vector3 = transform_value.origin
		var chunk_key: Vector2i = Vector2i(
			int(floor(origin.x / SHINRAI_ROAD_LIGHTING_CHUNK_SIZE_M)),
			int(floor(origin.z / SHINRAI_ROAD_LIGHTING_CHUNK_SIZE_M))
		)
		if not chunk_buckets.has(chunk_key):
			chunk_buckets[chunk_key] = []
		var bucket: Array = chunk_buckets[chunk_key]
		bucket.append(transform_value)

	for chunk_key in chunk_buckets.keys():
		var chunk_coord: Vector2i = chunk_key
		var chunk_transforms: Array = chunk_buckets[chunk_key]
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = road_mesh
		multimesh.instance_count = chunk_transforms.size()
		for index: int in range(chunk_transforms.size()):
			multimesh.set_instance_transform(index, chunk_transforms[index])

		var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
		instance.name = "%s_C%d_%d" % [instance_prefix, chunk_coord.x, chunk_coord.y]
		instance.multimesh = multimesh
		instance.material_override = shinrai_road_material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry_root.add_child(instance)

func _shinrai_road_strip_count(road_axis: int) -> int:
	return SHINRAI_ROAD_MAIN_STRIPS if road_axis == MAIN_ROAD_CENTER else SHINRAI_ROAD_SECONDARY_STRIPS

func _shinrai_road_axis_world(road_axis: int) -> float:
	return (float(road_axis) - float(GRID_WIDTH - 1) * 0.5) * TILE_SIZE

func _build_pothole_repairs() -> void:
	# x, z, size-x and size-z in metres. The first repair replaces the large
	# rectangular decal on the locked commercial street with a compact repair.
	var repair_specs: Array[Vector4] = [
		Vector4(14.6, 36.0, 0.86, 0.68),
		Vector4(-8.4, 36.0, 0.62, 0.50),
		Vector4(36.0, -20.2, 0.70, 0.56),
		Vector4(-36.0, -58.4, 0.58, 0.74),
	]
	for repair_index: int in range(repair_specs.size()):
		var spec: Vector4 = repair_specs[repair_index]
		_add_pothole_repair(
			repair_index,
			Vector3(spec.x, POTHOLE_REPAIR_SURFACE_Y, spec.y),
			Vector2(spec.z, spec.w)
		)
	print("SHINRAI pothole repairs: %d deterministic repaired depressions" % repair_specs.size())

func _add_pothole_repair(
	repair_index: int,
	center: Vector3,
	repair_size: Vector2
) -> void:
	var repair: MeshInstance3D = MeshInstance3D.new()
	repair.name = "PotholeRepair%d" % repair_index
	var repair_mesh: PlaneMesh = PlaneMesh.new()
	repair_mesh.size = repair_size
	repair.mesh = repair_mesh
	repair.position = center
	repair.material_override = PotholeRepairMaterial
	repair.rotation.y = deg_to_rad(float((repair_index * 47) % 180))
	repair.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	repair.visibility_range_end = POTHOLE_REPAIR_VISIBILITY_RANGE_M
	repair.visibility_range_end_margin = 7.0
	geometry_root.add_child(repair)

func _build_crack_seals() -> void:
	# x, z, square size and yaw degrees. Keep these sparse: two examples on the
	# locked commercial street and four elsewhere in the full road network.
	var seal_specs: Array[Vector4] = [
		Vector4(20.0, 36.0, 1.18, 18.0),
		Vector4(29.2, 36.0, 1.06, 104.0),
		Vector4(-43.4, -36.0, 1.24, 67.0),
		Vector4(36.0, -31.2, 1.12, 6.0),
		Vector4(-36.0, 55.4, 1.16, 143.0),
		Vector4(79.0, 42.0, 1.02, 91.0),
	]
	for seal_index: int in range(seal_specs.size()):
		var spec: Vector4 = seal_specs[seal_index]
		_add_crack_seal(
			seal_index,
			Vector3(spec.x, CRACK_SEAL_SURFACE_Y, spec.y),
			spec.z,
			spec.w
		)
	print("SHINRAI crack seals: %d deterministic dry tar repairs" % seal_specs.size())

func _add_crack_seal(
	seal_index: int,
	center: Vector3,
	seal_size: float,
	yaw_degrees: float
) -> void:
	var seal: MeshInstance3D = MeshInstance3D.new()
	seal.name = "CrackSeal%d" % seal_index
	var seal_mesh: PlaneMesh = PlaneMesh.new()
	seal_mesh.size = Vector2(seal_size, seal_size)
	seal.mesh = seal_mesh
	seal.position = center
	seal.rotation.y = deg_to_rad(yaw_degrees)
	seal.material_override = CrackSealMaterial
	seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seal.visibility_range_end = CRACK_SEAL_VISIBILITY_RANGE_M
	seal.visibility_range_end_margin = 6.0
	geometry_root.add_child(seal)

func _build_utility_cut_repair() -> void:
	# The square decal contains a narrow 0.49 m x 1.51 m repair in transparent
	# padding. A 90-degree yaw aligns its long axis with the locked street.
	var repair: MeshInstance3D = MeshInstance3D.new()
	repair.name = "UtilityCutRepairTest"
	var repair_mesh: PlaneMesh = PlaneMesh.new()
	repair_mesh.size = Vector2(1.75, 1.75)
	repair.mesh = repair_mesh
	repair.position = Vector3(25.0, UTILITY_CUT_SURFACE_Y, 36.0)
	repair.rotation.y = deg_to_rad(90.0)
	repair.material_override = UtilityCutMaterial
	repair.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	repair.visibility_range_end = UTILITY_CUT_VISIBILITY_RANGE_M
	repair.visibility_range_end_margin = 6.0
	geometry_root.add_child(repair)
	print("SHINRAI utility cut: 1 deterministic dry locked-street test repair")

func _build_manhole_test() -> void:
	var center: Vector3 = Vector3(33.0, MANHOLE_CUT_SURFACE_Y, 36.0)

	var asphalt_cut: MeshInstance3D = MeshInstance3D.new()
	asphalt_cut.name = "ManholeAsphaltCutTest"
	var cut_mesh: PlaneMesh = PlaneMesh.new()
	cut_mesh.size = Vector2(0.94, 0.94)
	asphalt_cut.mesh = cut_mesh
	asphalt_cut.position = center
	asphalt_cut.material_override = ManholeCutMaterial
	asphalt_cut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	asphalt_cut.visibility_range_end = MANHOLE_VISIBILITY_RANGE_M
	asphalt_cut.visibility_range_end_margin = 6.0
	geometry_root.add_child(asphalt_cut)

	var cover: MeshInstance3D = MeshInstance3D.new()
	cover.name = "JapaneseManholeCoverTest"
	var cover_mesh: PlaneMesh = PlaneMesh.new()
	cover_mesh.size = Vector2(0.65, 0.65)
	cover.mesh = cover_mesh
	cover.position = Vector3(center.x, MANHOLE_COVER_SURFACE_Y, center.z)
	cover.material_override = ManholeCoverMaterial
	cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cover.visibility_range_end = MANHOLE_VISIBILITY_RANGE_M
	cover.visibility_range_end_margin = 6.0
	geometry_root.add_child(cover)

	print("SHINRAI manhole: 1 deterministic dry 65 cm locked-street test")

func _build_curb_edge_repair_test() -> void:
	# The 2.35 m transparent plane contains an approximately 0.26 m x 2.07 m
	# repair. Its straight edge meets the north threshold at z=34.45; the worn
	# edge feathers inward across the asphalt.
	var repair: MeshInstance3D = MeshInstance3D.new()
	repair.name = "CurbEdgeRepairTest"
	var repair_mesh: PlaneMesh = PlaneMesh.new()
	repair_mesh.size = Vector2(2.35, 2.35)
	repair.mesh = repair_mesh
	repair.position = Vector3(7.8, CURB_EDGE_REPAIR_SURFACE_Y, 34.58)
	repair.rotation.y = deg_to_rad(-90.0)
	repair.material_override = CurbEdgeRepairMaterial
	repair.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	repair.visibility_range_end = CURB_EDGE_REPAIR_VISIBILITY_RANGE_M
	repair.visibility_range_end_margin = 6.0
	geometry_root.add_child(repair)
	print("SHINRAI curb edge: 1 deterministic dry locked-street test repair")

func _build_curb_drain_test() -> void:
	# The locked street's asphalt edge is z=34.45. The HGU150 origin sits on
	# the channel centreline, 97 mm outward from that edge. The imported asset's
	# local road side points toward -Z after Blender-to-glTF conversion, so a
	# 180-degree Y yaw turns it toward the street (+Z) without rescaling it.
	var drain_run: Node3D = Node3D.new()
	drain_run.name = "HGU150_CurbDrain_Run"
	geometry_root.add_child(drain_run)

	var road_edge_z: float = CURB_DRAIN_TEST_ROAD_Z - SHINRAI_ROAD_WIDTH_M * 0.5
	var channel_center_z: float = road_edge_z - CURB_DRAIN_CHANNEL_FROM_ROAD_EDGE_M
	var first_module_x: float = CURB_DRAIN_TEST_CENTER_X - float(CURB_DRAIN_MODULE_COUNT - 1) * CURB_DRAIN_MODULE_PITCH_M * 0.5

	for module_index: int in range(CURB_DRAIN_MODULE_COUNT):
		var drain_instance: Node3D = CurbDrainScene.instantiate() as Node3D
		if drain_instance == null:
			push_error("SHINRAI: HGU150 drain scene failed to instantiate")
			return
		drain_instance.name = "HGU150_Module_%02d" % module_index
		drain_instance.position = Vector3(
			first_module_x + float(module_index) * CURB_DRAIN_MODULE_PITCH_M,
			CURB_DRAIN_ROOT_Y,
			channel_center_z
		)
		drain_instance.rotation.y = PI
		drain_run.add_child(drain_instance)
		_configure_curb_drain_instance(drain_instance)

	# v10.27b: a symmetric 30 cm closed cover terminates each end of the
	# approved eight-module open-grate run. It extends the assembly instead of
	# replacing or rescaling any of the existing 0.60 m drain modules.
	var open_run_half_length: float = float(CURB_DRAIN_MODULE_COUNT) * CURB_DRAIN_MODULE_PITCH_M * 0.5
	for end_side: float in [-1.0, 1.0]:
		var end_cap: Node3D = CurbDrainEndCapScene.instantiate() as Node3D
		if end_cap == null:
			push_error("SHINRAI: HGU150 end-cap scene failed to instantiate")
			return
		end_cap.name = "HGU150_EndCap_%s" % ("West" if end_side < 0.0 else "East")
		end_cap.position = Vector3(
			CURB_DRAIN_TEST_CENTER_X + end_side * (open_run_half_length + CURB_DRAIN_END_CAP_LENGTH_M * 0.5),
			CURB_DRAIN_ROOT_Y,
			channel_center_z
		)
		end_cap.rotation.y = PI
		drain_run.add_child(end_cap)
		_configure_curb_drain_instance(end_cap)

	print(
		"SHINRAI HGU150 drain: %d x %.2f m modules | %.2f m open run + 2 closed caps | PBR + walkable collision" % [
			CURB_DRAIN_MODULE_COUNT,
			CURB_DRAIN_MODULE_PITCH_M,
			float(CURB_DRAIN_MODULE_COUNT) * CURB_DRAIN_MODULE_PITCH_M,
		]
	)

func _configure_curb_drain_instance(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		# v10.26z: the imported asphalt apron was visibly lighter/bluer than
		# Road03 and ended as a hard rectangular patch in the runtime capture.
		# Keep the authored drain, compacted joint and collision, but let the
		# existing continuous Road03 surface remain visible up to the frame.
		if geometry.name == "SM_Drain_AsphaltApron":
			geometry.visible = false
		geometry.visibility_range_end = CURB_DRAIN_VISIBILITY_RANGE_M
		geometry.visibility_range_end_margin = 6.0
	for child: Node in node.get_children():
		_configure_curb_drain_instance(child)

func _build_block_sidewalks() -> void:
	var block_index: int = 0
	for block: Rect2i in town_blocks:
		var center_cell: Vector2 = Vector2(
			float(block.position.x) + float(block.size.x - 1) * 0.5,
			float(block.position.y) + float(block.size.y - 1) * 0.5
		)
		var center_world: Vector3 = _grid_float_to_world(center_cell, 0.042)
		var width_m: float = float(block.size.x) * TILE_SIZE - 0.20
		var depth_m: float = float(block.size.y) * TILE_SIZE - 0.20
		_add_visual_box(
			geometry_root,
			"SidewalkBlock%d" % block_index,
			center_world,
			Vector3(width_m, 0.085, depth_m),
			mat_sidewalk
		)

		# The SHINRAI road is authored as a no-curb asphalt surface. The slightly raised
		# block/threshold geometry already provides the subtle shopfront edge;
		# do not add a separate toy-like curb around every block.
		block_index += 1

func _build_road_markings() -> void:
	# Main north/south road lane divider.
	var marking_index: int = 0
	for y: int in range(2, GRID_HEIGHT - 2, 3):
		if _is_road_axis(y):
			continue
		var center: Vector3 = _cell_to_world(Vector2i(MAIN_ROAD_CENTER, y), 0.062)
		_add_visual_box(
			decoration_root,
			"LaneMarkNS%d" % marking_index,
			center,
			Vector3(0.10, 0.018, 1.6),
			mat_asphalt_marking
		)
		marking_index += 1

	# Main east/west road lane divider.
	for x: int in range(2, GRID_WIDTH - 2, 3):
		if _is_road_axis(x):
			continue
		var center: Vector3 = _cell_to_world(Vector2i(x, MAIN_ROAD_CENTER), 0.062)
		_add_visual_box(
			decoration_root,
			"LaneMarkEW%d" % marking_index,
			center,
			Vector3(1.6, 0.018, 0.10),
			mat_asphalt_marking
		)
		marking_index += 1

	# Japanese-style zebra crossing at the central commercial intersection.
	var intersection_world: Vector3 = _cell_to_world(
		Vector2i(MAIN_ROAD_CENTER, MAIN_ROAD_CENTER), 0.068
	)
	for stripe_index: int in range(7):
		var offset: float = (float(stripe_index) - 3.0) * 0.72
		_add_visual_box(
			decoration_root,
			"CrosswalkNS%d" % stripe_index,
			intersection_world + Vector3(offset, 0.0, -7.0),
			Vector3(0.42, 0.020, 5.6),
			mat_asphalt_marking
		)
		_add_visual_box(
			decoration_root,
			"CrosswalkEW%d" % stripe_index,
			intersection_world + Vector3(-7.0, 0.0, offset),
			Vector3(5.6, 0.020, 0.42),
			mat_asphalt_marking
		)

func _choose_featured_park_block_index() -> int:
	# v10.15 chose the *first* overgrown block in iteration order. That put the
	# showcase park in a far map corner, which made it almost impossible to
	# discover once the street walls became dense. Choose an authored central
	# block instead: one intersection north of the spawn and immediately west
	# of the main avenue. The player still has to explore, but the park can be
	# found from a deliberate sightline rather than by wandering randomly.
	var target_center: Vector2 = Vector2(
		float(MAIN_ROAD_CENTER) - 5.0,
		float(MAIN_ROAD_CENTER) + 5.5
	)
	var best_index: int = -1
	var best_score: float = 1.0e9
	var main_left_edge: int = MAIN_ROAD_CENTER - MAIN_ROAD_HALF_WIDTH

	for block_index: int in range(town_blocks.size()):
		var block: Rect2i = town_blocks[block_index]
		if block.size.x < 7 or block.size.y < 7:
			continue
		var center: Vector2 = Vector2(
			float(block.position.x) + float(block.size.x) * 0.5,
			float(block.position.y) + float(block.size.y) * 0.5
		)
		var score: float = center.distance_to(target_center)

		# Strongly prefer a block that directly touches the west side of the
		# main road, so the torii / cherry canopy can be seen from the avenue.
		if block.position.x + block.size.x == main_left_edge:
			score -= 24.0
		else:
			score += 60.0

		# Keep the landmark away from the outermost map edge.
		if block.position.y <= 4 or block.position.y + block.size.y >= GRID_HEIGHT - 4:
			score += 30.0

		if score < best_score:
			best_score = score
			best_index = block_index

	# Defensive fallback: there should always be a suitable block in this
	# layout, but never silently lose the featured park if the road grid changes.
	if best_index < 0 and not town_blocks.is_empty():
		best_index = int(town_blocks.size() / 2)
	return best_index

func _build_city_blocks() -> void:
	featured_park_block_index = _choose_featured_park_block_index()
	for block_index: int in range(town_blocks.size()):
		var block: Rect2i = town_blocks[block_index]
		var district: int = _district_for_block(block)

		# Keep one authored shrine park in a guaranteed discoverable location.
		# Other green blocks remain uncommon so the town keeps its dense street
		# walls without hiding the landmark in a random corner.
		var featured_park: bool = block_index == featured_park_block_index
		var park_chance: float = 0.012
		if district == DISTRICT_OVERGROWN:
			park_chance = 0.055
		elif district == DISTRICT_LUXURY:
			park_chance = 0.020

		if featured_park or town_rng.randf() < park_chance:
			_build_green_block(block, block_index, district, featured_park)
			continue

		_build_perimeter_block(block, district, block_index)

func _build_perimeter_block(block: Rect2i, district: int, block_index: int) -> void:
	# Buildings line the four street edges around a rear service court. Each
	# edge is built independently so a reference apartment can reserve the next
	# frontage lot for its future side balconies.
	var strip_depth: int = 2 if mini(block.size.x, block.size.y) >= 7 else 1
	var serial: int = 0
	var x_segments: Array[Vector2i] = _subdivide_frontage(block.position.x, block.size.x)
	var north_lots: Array[Rect2i] = []
	var south_lots: Array[Rect2i] = []
	for segment: Vector2i in x_segments:
		north_lots.append(
			Rect2i(segment.x, block.position.y, segment.y, strip_depth)
		)
		if block.size.y > strip_depth:
			south_lots.append(
				Rect2i(
					segment.x,
					block.position.y + block.size.y - strip_depth,
					segment.y,
					strip_depth
				)
			)

	serial = _build_perimeter_lot_run(
		north_lots, district, block_index, serial, Vector3.RIGHT
	)
	serial = _build_perimeter_lot_run(
		south_lots, district, block_index, serial, Vector3.RIGHT
	)

	var inner_start_y: int = block.position.y + strip_depth
	var inner_length_y: int = block.size.y - strip_depth * 2
	if inner_length_y >= 2:
		var y_segments: Array[Vector2i] = _subdivide_frontage(inner_start_y, inner_length_y)
		var west_lots: Array[Rect2i] = []
		var east_lots: Array[Rect2i] = []
		for segment: Vector2i in y_segments:
			west_lots.append(
				Rect2i(block.position.x, segment.x, strip_depth, segment.y)
			)
			if block.size.x > strip_depth:
				east_lots.append(
					Rect2i(
						block.position.x + block.size.x - strip_depth,
						segment.x,
						strip_depth,
						segment.y
					)
				)

		serial = _build_perimeter_lot_run(
			west_lots, district, block_index, serial, Vector3.BACK
		)
		_build_perimeter_lot_run(
			east_lots, district, block_index, serial, Vector3.BACK
		)


func _build_perimeter_lot_run(
	lots: Array[Rect2i],
	district: int,
	block_index: int,
	serial_start: int,
	clearance_world_direction: Vector3
) -> int:
	var lot_index: int = 0
	var serial: int = serial_start
	while lot_index < lots.size():
		# An apartment is allowed only when a complete neighboring frontage lot
		# exists to reserve. This prevents a building or random prop from ever
		# occupying the side selected for the wraparound balcony modules.
		var can_reserve_next: bool = lot_index + 1 < lots.size()
		var building_type: int = _build_lot(
			lots[lot_index],
			district,
			block_index,
			serial,
			can_reserve_next,
			clearance_world_direction
		)
		serial += 1
		lot_index += 1
		if building_type == BUILDING_APARTMENT:
			# Consume the serial as well as the physical lot so later names remain
			# unique and the empty clearance is explicit in the generated layout.
			serial += 1
			lot_index += 1
	return serial


func _subdivide_frontage(start_cell: int, length_cells: int) -> Array[Vector2i]:
	var segments: Array[Vector2i] = []
	var cursor: int = start_cell
	var remaining: int = length_cells
	while remaining > 0:
		var segment_size: int = 2
		if remaining <= 3:
			segment_size = remaining
		elif remaining % 2 == 1 and remaining <= 5:
			segment_size = 3
		elif town_rng.randf() < 0.26 and remaining >= 5:
			segment_size = 3
		segment_size = mini(segment_size, remaining)
		segments.append(Vector2i(cursor, segment_size))
		cursor += segment_size
		remaining -= segment_size
	return segments

func _district_for_block(block: Rect2i) -> int:
	var center_x: float = float(block.position.x) + float(block.size.x) * 0.5
	var center_y: float = float(block.position.y) + float(block.size.y) * 0.5
	var dx: float = center_x - float(MAIN_ROAD_CENTER)
	var dy: float = center_y - float(MAIN_ROAD_CENTER)

	if absf(dx) < 11.5 and absf(dy) < 11.5:
		return DISTRICT_COMMERCIAL
	if dx > 0.0 and dy < 0.0:
		return DISTRICT_LUXURY
	if dx < 0.0 and dy > 0.0:
		return DISTRICT_TRADITIONAL
	if dx < 0.0 and dy < 0.0:
		return DISTRICT_OVERGROWN
	return DISTRICT_RESIDENTIAL

func _build_lot(
	lot: Rect2i,
	district: int,
	block_index: int,
	lot_serial: int,
	allow_apartment: bool = true,
	apartment_clearance_world_direction: Vector3 = Vector3.RIGHT
) -> int:
	var cell_center: Vector2 = Vector2(
		float(lot.position.x) + float(lot.size.x - 1) * 0.5,
		float(lot.position.y) + float(lot.size.y - 1) * 0.5
	)
	var world_center: Vector3 = _grid_float_to_world(cell_center, 0.0)
	var max_width: float = maxf(3.6, float(lot.size.x) * TILE_SIZE - 0.42)
	var max_depth: float = maxf(3.6, float(lot.size.y) * TILE_SIZE - 0.42)
	var front_yaw: float = _front_yaw_for_lot(cell_center)
	var side_facing: bool = absf(sin(front_yaw)) > 0.5
	var frontage_m: float = max_depth if side_facing else max_width
	var lot_depth_m: float = max_width if side_facing else max_depth
	var width_m: float = clampf(
		frontage_m * town_rng.randf_range(0.90, 0.985),
		minf(4.2, frontage_m), frontage_m
	)
	var depth_m: float = clampf(
		lot_depth_m * town_rng.randf_range(0.88, 0.97),
		minf(4.6, lot_depth_m), lot_depth_m
	)

	# Push facades hard toward the road. Side/rear gaps now read as tiny service
	# alleys rather than lawns around detached procedural buildings.
	var front_direction: Vector3 = Vector3(-sin(front_yaw), 0.0, -cos(front_yaw))
	var front_shift: float = clampf((lot_depth_m - depth_m) * 0.46, 0.0, 0.72)
	world_center += front_direction * front_shift

	var building_type: int = _choose_building_type(district, lot)
	if (
		building_type == BUILDING_APARTMENT
		and (
			not allow_apartment
			or lot_depth_m < APARTMENT_REFERENCE_DEPTH_M
		)
	):
		# Do not squeeze the reference apartment into a one-cell-deep strip.
		# It would distort the 6.60 m footprint or collide with the rear lot run.
		building_type = BUILDING_MODERN
	var building_name: String = "Block%dLot%d" % [block_index, lot_serial]
	var enterable: bool = false
	if building_type == BUILDING_SHOP:
		enterable = town_rng.randf() < ENTERABLE_SHOP_CHANCE
	elif building_type == BUILDING_TRADITIONAL or building_type == BUILDING_MODERN:
		enterable = town_rng.randf() < ENTERABLE_HOUSE_CHANCE

	match building_type:
		BUILDING_TRADITIONAL:
			_build_traditional_house(building_name, world_center, width_m, depth_m, district, front_yaw, enterable)
		BUILDING_MODERN:
			_build_modern_house(building_name, world_center, width_m, depth_m, district, front_yaw, enterable)
		BUILDING_SHOP:
			_build_shop(building_name, world_center, width_m, depth_m, district, front_yaw, enterable)
		BUILDING_APARTMENT:
			var local_right_world: Vector3 = Vector3(cos(front_yaw), 0.0, -sin(front_yaw))
			var balcony_side_sign: float = 1.0
			if local_right_world.dot(apartment_clearance_world_direction) < 0.0:
				balcony_side_sign = -1.0

			# Grow toward the frontage lot already reserved for the side balconies,
			# keeping the opposite party-wall edge fixed. Grow depth only toward
			# the rear, keeping the street-facing façade on its original line.
			var apartment_width_delta: float = APARTMENT_REFERENCE_WIDTH_M - width_m
			var apartment_depth_delta: float = APARTMENT_REFERENCE_DEPTH_M - depth_m
			var apartment_center: Vector3 = (
				world_center
				+ local_right_world
					* (apartment_width_delta * 0.5 * balcony_side_sign)
				- front_direction * (apartment_depth_delta * 0.5)
			)
			_build_apartment(
				building_name,
				apartment_center,
				APARTMENT_REFERENCE_WIDTH_M,
				APARTMENT_REFERENCE_DEPTH_M,
				district,
				front_yaw,
				balcony_side_sign
			)
		BUILDING_TOWER:
			_build_tower(building_name, world_center, width_m, depth_m, front_yaw)

	if (
		district == DISTRICT_OVERGROWN
		and building_type != BUILDING_APARTMENT
		and town_rng.randf() < 0.45
	):
		var plant_count: int = town_rng.randi_range(1, 3)
		for plant_index: int in range(plant_count):
			var plant_pos: Vector3 = world_center + Vector3(
				town_rng.randf_range(-width_m * 0.46, width_m * 0.46),
				0.0,
				town_rng.randf_range(-depth_m * 0.46, depth_m * 0.46)
			)
			_add_shrub(plant_pos, town_rng.randf_range(0.45, 0.88))
	return building_type

func _choose_building_type(district: int, lot: Rect2i) -> int:
	var roll: float = town_rng.randf()
	match district:
		DISTRICT_TRADITIONAL:
			if roll < 0.60:
				return BUILDING_TRADITIONAL
			if roll < 0.92:
				return BUILDING_SHOP
			return BUILDING_MODERN
		DISTRICT_OVERGROWN:
			if roll < 0.42:
				return BUILDING_TRADITIONAL
			if roll < 0.70:
				return BUILDING_MODERN
			if roll < 0.90:
				return BUILDING_SHOP
			return BUILDING_APARTMENT
		DISTRICT_LUXURY:
			return BUILDING_MODERN if roll < 0.76 else BUILDING_APARTMENT
		DISTRICT_COMMERCIAL:
			# Foreground towers were visually overpowering in earlier passes.
			# Commercial streets are now mostly narrow shops/mixed-use blocks;
			# the true high-rise city is handled by the distant skyline.
			if roll < 0.66:
				return BUILDING_SHOP
			if roll < 0.95:
				return BUILDING_APARTMENT
			return BUILDING_TRADITIONAL
		_:
			if roll < 0.38:
				return BUILDING_MODERN
			if roll < 0.68:
				return BUILDING_TRADITIONAL
			if roll < 0.84:
				return BUILDING_SHOP
			return BUILDING_APARTMENT

func _new_building_root(
	building_name: String,
	position_value: Vector3,
	front_yaw: float = 0.0
) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = building_name
	root.position = position_value
	root.rotation.y = front_yaw
	geometry_root.add_child(root)
	return root

func _add_building_collision(
	building_root: Node3D,
	size: Vector3,
	local_center: Vector3
) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	building_root.add_child(body)
	_add_collision_box(body, local_center, size)

func _build_traditional_house(
	building_name: String,
	position_value: Vector3,
	width_m: float,
	depth_m: float,
	district: int,
	front_yaw: float,
	enterable: bool
) -> void:
	var root: Node3D = _new_building_root(building_name, position_value, front_yaw)
	var floors: int = 2 if town_rng.randf() < 0.58 else 1
	var ground_h: float = 2.72
	var upper_h: float = 2.55 if floors > 1 else 0.0
	var height: float = ground_h + upper_h
	var wall_mat: Material = _choose_traditional_wall_material(district)
	var facade_seed: int = int(absf(position_value.x) * 9.0 + absf(position_value.z) * 11.0 + width_m * 19.0)

	if enterable:
		_add_enterable_ground_shell(root, width_m, depth_m, ground_h, wall_mat, 1.28)
		_add_interior_details(root, width_m, depth_m, BUILDING_TRADITIONAL, ground_h)
		if floors > 1:
			_add_local_box(root, "UpperPlaster", Vector3(0.0, ground_h + upper_h * 0.5, 0.0),
				Vector3(width_m, upper_h, depth_m), wall_mat)
			_add_building_collision(root, Vector3(width_m, upper_h, depth_m),
				Vector3(0.0, ground_h + upper_h * 0.5, 0.0))
	else:
		_add_local_box(root, "HouseBody", Vector3(0.0, height * 0.5, 0.0),
			Vector3(width_m, height, depth_m), wall_mat)
		_add_building_collision(root, Vector3(width_m, height, depth_m),
			Vector3(0.0, height * 0.5, 0.0))

	# Timber frame is broken into structural pieces rather than one flat brown facade.
	_add_local_box(root, "FrontBeamLow", Vector3(0.0, 0.25, -depth_m * 0.535),
		Vector3(width_m * 0.95, 0.16, 0.20), mat_dark_wood)
	_add_local_box(root, "FrontBeamHigh", Vector3(0.0, ground_h - 0.18, -depth_m * 0.535),
		Vector3(width_m * 0.98, 0.16, 0.20), mat_dark_wood)
	for post_x: float in [-0.46, -0.22, 0.22, 0.46]:
		_add_local_box(root, "TimberPost", Vector3(width_m * post_x, ground_h * 0.5, -depth_m * 0.545),
			Vector3(0.13, ground_h - 0.18, 0.17), mat_dark_wood)

	# A pronounced floor beam separates the shop/entry scale from the quieter
	# upper room and gives the facade a real layered machiya silhouette.
	if floors > 1:
		_add_facade_detail_box(root, "UpperFloorBeam",
			Vector3(0.0, ground_h + 0.07, -depth_m * 0.548),
			Vector3(width_m * 0.94, 0.13, 0.14), mat_dark_wood)

	# Front glazing/shoji panels leave a real doorway when enterable. Most
	# windows stay dark/reflective; warm occupied rooms become focal accents.
	var window_width: float = maxf(0.78, width_m * 0.17)
	var left_window_mat: Material = _choose_window_material(0.28)
	var right_window_mat: Material = _choose_window_material(0.20)
	_add_front_window(root, "ShojiL", -width_m * 0.28, 1.31, -depth_m * 0.518,
		window_width, 1.30, left_window_mat, mat_dark_wood)
	_add_front_window(root, "ShojiR", width_m * 0.28, 1.31, -depth_m * 0.518,
		window_width, 1.30, right_window_mat, mat_dark_wood)

	# A partial timber/slatted bay prevents every traditional frontage from
	# reading as the same pair of glowing rectangles.
	if town_rng.randf() < 0.72:
		var screen_side: float = -1.0 if town_rng.randf() < 0.5 else 1.0
		var screen_x: float = width_m * 0.39 * screen_side
		_add_local_box(root, "TimberScreenBacking", Vector3(screen_x, 1.26, -depth_m * 0.535),
			Vector3(width_m * 0.17, 1.82, 0.08), mat_dark_wood)
		for slat_index: int in range(4):
			var slat_t: float = (float(slat_index) - 1.5) * width_m * 0.037
			_add_local_box(root, "TimberScreenSlat", Vector3(screen_x + slat_t, 1.27, -depth_m * 0.585),
				Vector3(0.045, 1.72, 0.055), mat_wood)

	if enterable:
		_add_open_door(root, depth_m, 1.12, mat_dark_wood)
		_add_local_box(root, "GenkanStep", Vector3(0.0, 0.12, -depth_m * 0.5 - 0.46),
			Vector3(1.70, 0.20, 0.78), mat_tile)

	if floors > 1:
		for side: float in [-1.0, 1.0]:
			var upper_x: float = width_m * 0.24 * side
			var upper_z: float = -depth_m * 0.516
			var upper_mat: Material = _choose_window_material(0.18 if side < 0.0 else 0.12)
			_add_front_window(root, "UpperWindow", upper_x, ground_h + 1.16,
				upper_z, width_m * 0.18, 0.84, upper_mat, mat_dark_wood)
			if (facade_seed + int(side * 2.0)) % 3 == 0:
				_add_window_blinds(root, "TraditionalUpper", upper_x, ground_h + 1.16, upper_z, width_m * 0.18, 0.84)
			elif upper_mat != mat_window_dark_opaque:
				_add_window_planter_box(root, "TraditionalUpper", upper_x, ground_h + 1.16, upper_z, width_m * 0.18)

	if floors > 1 and town_rng.randf() < 0.58:
		_add_local_box(root, "LowerEave", Vector3(0.0, ground_h + 0.04, -depth_m * 0.5 - 0.36),
			Vector3(width_m * 0.88, 0.12, 0.66), mat_roof, Vector3(deg_to_rad(-7.0), 0.0, 0.0))
		_add_facade_detail_box(root, "LowerEaveFascia",
			Vector3(0.0, ground_h - 0.02, -depth_m * 0.5 - 0.68),
			Vector3(width_m * 0.90, 0.16, 0.10), mat_dark_wood)
	_add_gable_roof(root, width_m, depth_m, height, mat_roof, mat_tile, 27.0, true, wall_mat)
	_add_gutter_downpipe(root, "Traditional", width_m * (-0.43 if facade_seed % 2 == 0 else 0.43),
		height + 0.02, -depth_m * 0.5 - 0.18, maxf(1.5, height - 0.72))
	if floors > 1:
		_add_utility_box_cluster(root, "Traditional", width_m * (0.35 if facade_seed % 4 < 2 else -0.35),
			ground_h + 0.74, -depth_m * 0.5 - 0.010)
	_add_exposed_service_pipe(root, -width_m * 0.43, height * 0.48, -depth_m * 0.535, height * 0.82)

	_add_wall_ac_unit(root, width_m * 0.37, 1.55, -depth_m * 0.515)
	if district == DISTRICT_TRADITIONAL:
		_add_local_box(root, "Lantern", Vector3(-width_m * 0.43, 2.05, -depth_m * 0.62),
			Vector3(0.26, 0.55, 0.26), mat_neon_red)

func _build_modern_house(
	building_name: String,
	position_value: Vector3,
	width_m: float,
	depth_m: float,
	district: int,
	front_yaw: float,
	enterable: bool
) -> void:
	var root: Node3D = _new_building_root(building_name, position_value, front_yaw)
	var floors: int = 2 if town_rng.randf() < 0.78 else 3
	var floor_h: float = 2.88
	var height: float = floor_h * float(floors)
	var body_mat: Material = _choose_modern_body_material(district)
	var facade_seed: int = int(absf(position_value.x) * 8.0 + absf(position_value.z) * 12.0 + width_m * 15.0)

	if enterable:
		_add_enterable_ground_shell(root, width_m, depth_m, floor_h, body_mat, 1.30)
		_add_interior_details(root, width_m, depth_m, BUILDING_MODERN, floor_h)
		var upper_height: float = height - floor_h
		_add_local_box(root, "UpperBody", Vector3(0.0, floor_h + upper_height * 0.5, 0.0),
			Vector3(width_m, upper_height, depth_m), body_mat)
		_add_building_collision(root, Vector3(width_m, upper_height, depth_m),
			Vector3(0.0, floor_h + upper_height * 0.5, 0.0))
		_add_open_door(root, depth_m, 1.14, mat_black_metal)
	else:
		_add_local_box(root, "ModernBody", Vector3(0.0, height * 0.5, 0.0),
			Vector3(width_m, height, depth_m), body_mat)
		_add_building_collision(root, Vector3(width_m, height, depth_m),
			Vector3(0.0, height * 0.5, 0.0))

	# Recessed facade, window frames, balcony rails and service equipment add
	# the small-scale detail visible in real Japanese residential streets.
	for floor_index: int in range(floors):
		var y_value: float = 1.48 + float(floor_index) * floor_h
		var left_x: float = -width_m * 0.25
		var right_x: float = width_m * 0.25
		var window_z: float = -depth_m * 0.518
		if floor_index == 0 and enterable:
			var glass_l: Material = _choose_window_material(0.14)
			var glass_r: Material = _choose_window_material(0.10)
			_add_front_window(root, "GroundGlassL", left_x, y_value,
				window_z, width_m * 0.20, 1.18, glass_l, mat_black_metal)
			_add_front_window(root, "GroundGlassR", right_x, y_value,
				window_z, width_m * 0.20, 1.18, glass_r, mat_black_metal)
		else:
			var left_mat: Material = _choose_window_material(0.18)
			var right_mat: Material = _choose_window_material(0.11)
			_add_front_window(root, "ModernWindowL", left_x, y_value,
				window_z, width_m * 0.20, 1.05, left_mat, mat_black_metal)
			_add_front_window(root, "ModernWindowR", right_x, y_value,
				window_z, width_m * 0.20, 1.05, right_mat, mat_black_metal)
			if (facade_seed + floor_index) % 3 == 0:
				_add_window_blinds(root, "ModernUpper", left_x, y_value, window_z, width_m * 0.20, 1.05)
			if (facade_seed + floor_index) % 3 == 1 and right_mat != mat_window_dark_opaque:
				_add_window_planter_box(root, "ModernUpper", right_x, y_value, window_z, width_m * 0.20)

		if floor_index > 0:
			var balcony_y: float = float(floor_index) * floor_h + 0.12
			var balcony_side: float = -0.16 if floor_index % 2 == 0 else 0.16
			_add_local_box(root, "BalconySlab", Vector3(width_m * balcony_side, balcony_y, -depth_m * 0.5 - 0.38),
				Vector3(width_m * 0.54, 0.12, 0.72), mat_dark_concrete)
			_add_balcony_rail(root, width_m * 0.52, balcony_y + 0.62, -depth_m * 0.5 - 0.72)

	_add_local_box(root, "EntranceCanopy", Vector3(0.0, 2.48, -depth_m * 0.5 - 0.48),
		Vector3(2.05, 0.12, 0.84), mat_black_metal)

	# v10.23a: replace the four flat full-height stripes with a clearer
	# structural hierarchy: edge piers, floor lines and one shallow service bay.
	# The new trim is shadowless and close-range culled.
	for pier_side: float in [-1.0, 1.0]:
		_add_facade_detail_box(root, "FacadeCornerPier",
			Vector3(width_m * 0.455 * pier_side, height * 0.50, -depth_m * 0.535),
			Vector3(0.12, height * 0.92, 0.14), mat_black_metal)
	for floor_line: int in range(1, floors):
		_add_facade_detail_box(root, "FacadeFloorBand",
			Vector3(0.0, float(floor_line) * floor_h + 0.03, -depth_m * 0.542),
			Vector3(width_m * 0.88, 0.10, 0.13), mat_dark_concrete)
	var service_side: float = -1.0 if floors == 2 else 1.0
	_add_facade_detail_box(root, "FacadeServiceBay",
		Vector3(width_m * 0.36 * service_side, height * 0.56, -depth_m * 0.540),
		Vector3(width_m * 0.13, height * 0.56, 0.10), mat_weathered_metal)
	_add_gutter_downpipe(root, "Modern", width_m * (-0.42 if facade_seed % 2 == 0 else 0.42),
		height + 0.02, -depth_m * 0.5 - 0.12, maxf(1.6, height - 0.80))
	_add_utility_box_cluster(root, "Modern", width_m * (0.35 if facade_seed % 4 < 2 else -0.35),
		minf(height - 1.00, 3.78), -depth_m * 0.5 - 0.010)
	_add_wall_ac_unit(root, width_m * 0.40, 1.45, -depth_m * 0.515)

	# Most ordinary Japanese homes get a restrained pitched cap; luxury
	# buildings keep the flat contemporary silhouette.
	if district != DISTRICT_LUXURY and town_rng.randf() < 0.58:
		_add_gable_roof(root, width_m, depth_m, height, mat_roof, mat_tile, 14.0, true, body_mat)
	else:
		_add_rooftop_parapet(root, width_m, depth_m, height)

	if district == DISTRICT_LUXURY:
		_add_local_box(root, "RoofTrim", Vector3(0.0, height + 0.05, -depth_m * 0.51),
			Vector3(width_m, 0.09, 0.09), mat_neon_pink)
		_add_planter_strip(root, width_m, depth_m, height)

func _build_shop(
	building_name: String,
	position_value: Vector3,
	width_m: float,
	depth_m: float,
	district: int,
	front_yaw: float,
	enterable: bool
) -> void:
	var root: Node3D = _new_building_root(building_name, position_value, front_yaw)
	var floors: int = town_rng.randi_range(2, 3)
	var floor_h: float = 2.82
	var height: float = floor_h * float(floors)
	var shop_archetype: int = _choose_shop_archetype(enterable)
	var facade_seed: int = int(absf(position_value.x) * 10.0 + absf(position_value.z) * 7.0 + width_m * 13.0 + depth_m * 17.0)
	var facade_style: int = _choose_shop_facade_style(position_value, district, facade_seed)
	if shop_archetype == SHOP_SHUTTERED:
		facade_style = SHOP_FACADE_HERITAGE

	# Keep the original material-selection RNG draw so the locked seed continues
	# to generate the same town. Renovated façades then override only the visible
	# shell/trim materials with a cooler manufactured palette.
	var body_mat: Material = _shop_body_material(shop_archetype, district)
	var upper_trim_mat: Material = _shop_frame_material(shop_archetype)
	if facade_style == SHOP_FACADE_RENOVATED:
		body_mat = mat_concrete_cool if facade_seed % 2 == 0 else mat_concrete_stained
		upper_trim_mat = mat_black_metal if facade_seed % 3 == 0 else mat_weathered_metal
		root.add_to_group("shinrai_renovated_storefront")
		root.set_meta("shinrai_facade_style", "renovated")
	elif facade_style == SHOP_FACADE_CONTEMPORARY:
		body_mat = mat_contemporary_panel if facade_seed % 2 == 0 else mat_plaster_cool
		upper_trim_mat = mat_contemporary_panel_dark
		root.add_to_group("shinrai_contemporary_storefront")
		root.set_meta("shinrai_facade_style", "contemporary")

	if enterable:
		_add_enterable_ground_shell(root, width_m, depth_m, floor_h, body_mat, 1.30)
		_add_interior_details(root, width_m, depth_m, BUILDING_SHOP, floor_h, shop_archetype)
		var upper_h: float = height - floor_h
		_add_local_box(root, "UpperShopBody", Vector3(0.0, floor_h + upper_h * 0.5, 0.0),
			Vector3(width_m, upper_h, depth_m), body_mat)
		_add_building_collision(root, Vector3(width_m, upper_h, depth_m),
			Vector3(0.0, floor_h + upper_h * 0.5, 0.0))
		_add_shop_open_door_leaf(root, depth_m, 1.12, upper_trim_mat)
	else:
		_add_local_box(root, "ShopBody", Vector3(0.0, height * 0.5, 0.0),
			Vector3(width_m, height, depth_m), body_mat)
		_add_building_collision(root, Vector3(width_m, height, depth_m),
			Vector3(0.0, height * 0.5, 0.0))

	_add_shopfront_facade(root, width_m, depth_m, height, shop_archetype, enterable, facade_style)

	# v10.25d integration test: selected first upper floors use the approved
	# Blender v6 modular window bay instead of the procedural five-box windows.
	# Keep the replacement capped and deterministic so performance and seed
	# behaviour stay easy to compare against v10.25c.
	var upper_window_z: float = -depth_m * 0.5 + 0.010
	var building_used_imported_bay: bool = false
	for floor_index: int in range(1, floors):
		var y_value: float = 1.48 + float(floor_index) * floor_h
		var used_imported_bay: bool = false
		var should_test_imported_bay: bool = (
			floor_index == 1
			and shop_archetype != SHOP_SHUTTERED
			and facade_style != SHOP_FACADE_CONTEMPORARY
			and width_m >= 4.35
			and ((facade_seed + floor_index * 5) % 4 != 0)
		)

		if should_test_imported_bay:
			var bay_width_m: float = 3.0 if width_m >= 6.55 else 2.0
			var bay_x: float = 0.0
			if width_m >= 7.2:
				bay_x = width_m * (0.10 if (facade_seed % 2 == 0) else -0.10)
			used_imported_bay = _add_modular_window_bay(
				root, depth_m, bay_x, y_value, bay_width_m, facade_seed + floor_index * 17
			)
			if used_imported_bay:
				building_used_imported_bay = true

		if not used_imported_bay:
			var window_count: int = 2 if width_m < 6.2 else 3
			var window_width: float = width_m * (0.18 if window_count == 2 else 0.13)
			for column: int in range(window_count):
				var t: float = (float(column) + 0.5) / float(window_count) - 0.5
				var x_value: float = t * width_m * 0.66
				var glass_mat: Material = _choose_window_material(0.16 if column == 0 else 0.09)
				_add_front_window(root, "UpperWindow", x_value, y_value, upper_window_z,
					window_width, 0.90, glass_mat, upper_trim_mat)

				var treatment_roll: int = (facade_seed + floor_index * 3 + column) % 4
				if treatment_roll == 0:
					_add_window_blinds(root, "Upper", x_value, y_value, upper_window_z, window_width, 0.90)
				elif treatment_roll == 1 and glass_mat != mat_window_dark_opaque:
					_add_window_planter_box(root, "Upper", x_value, y_value, upper_window_z, window_width)

		_add_facade_detail_box(root, "UpperShopFloorBand",
			Vector3(0.0, float(floor_index) * floor_h + 0.06, -depth_m * 0.5 - 0.050),
			Vector3(width_m * 0.88, 0.095, 0.12), upper_trim_mat)

		# Keep the existing procedural balcony only on floors that do not use
		# the Blender bay; otherwise its rail can cut across the bay sill/hood.
		if (
			not used_imported_bay
			and floor_index == 1
			and width_m >= 5.6
			and shop_archetype != SHOP_CONVENIENCE
			and shop_archetype != SHOP_SHUTTERED
			and (facade_seed % 4) <= 1
		):
			var balcony_y: float = float(floor_index) * floor_h + 0.12
			var balcony_mat: Material = mat_dark_wood
			if facade_style == SHOP_FACADE_RENOVATED:
				balcony_mat = mat_dark_concrete
			elif facade_style == SHOP_FACADE_CONTEMPORARY:
				balcony_mat = mat_contemporary_panel_dark
			_add_local_box(root, "UpperBalcony", Vector3(0.0, balcony_y, -depth_m * 0.5 - 0.38),
				Vector3(width_m * 0.54, 0.12, 0.70), balcony_mat)
			_add_balcony_rail(root, width_m * 0.50, balcony_y + 0.62, -depth_m * 0.5 - 0.72)
			if (facade_seed + floor_index) % 2 == 0:
				_add_window_planter_box(root, "Balcony", -width_m * 0.14, balcony_y + 0.20, -depth_m * 0.5 - 0.36, 0.62)
				_add_window_planter_box(root, "Balcony", width_m * 0.14, balcony_y + 0.20, -depth_m * 0.5 - 0.36, 0.62)

	# Narrow outer piers visually tie the active ground-floor storefront to the
	# quieter rooms above without changing the enterable shell or collision.
	var upper_center_y: float = floor_h + (height - floor_h) * 0.5
	for upper_side: float in [-1.0, 1.0]:
		_add_facade_detail_box(root, "UpperShopSidePier",
			Vector3(width_m * 0.445 * upper_side, upper_center_y, -depth_m * 0.5 - 0.045),
			Vector3(0.11, maxf(0.5, height - floor_h - 0.18), 0.12), upper_trim_mat)

	if facade_style == SHOP_FACADE_CONTEMPORARY:
		_add_contemporary_upper_facade(root, width_m, depth_m, height, floor_h, floors, facade_seed)

	# v10.25g: keep the same tiny imported-roof candidate set while finishing
	# runtime-driven underside/material calibration. This remains tied to the approved imported-window
	# test so the player can judge the facade kit as one coherent assembly.
	var used_imported_roof: bool = false
	if (
		building_used_imported_bay
		and facade_style != SHOP_FACADE_CONTEMPORARY
		and shop_archetype != SHOP_CONVENIENCE
		and shop_archetype != SHOP_REPAIR
		and shop_archetype != SHOP_SHUTTERED
		and width_m >= 4.15
		and (facade_seed % 3 != 0)
	):
		used_imported_roof = _add_modular_roof_eave(root, depth_m, height, width_m)

	if used_imported_roof:
		# A single recessed wall plate masks tiny facade/roof intersection
		# differences and makes the imported eave read as supported structure,
		# not a separate prop. With the six-roof cap this adds negligible cost.
		_add_facade_detail_box(root, "ImportedRoofWallPlate",
			Vector3(0.0, height - 0.085, -depth_m * 0.5 - 0.045),
			Vector3(width_m * 0.90, 0.17, 0.13), mat_imported_roof_timber_dark)
	else:
		var head_eave_mat: Material = mat_dark_wood
		var head_eave_depth: float = 0.44
		var head_eave_rotation: Vector3 = Vector3(deg_to_rad(-5.0), 0.0, 0.0)
		if facade_style == SHOP_FACADE_RENOVATED:
			head_eave_mat = mat_black_metal
			head_eave_depth = 0.30
			head_eave_rotation = Vector3.ZERO
		elif facade_style == SHOP_FACADE_CONTEMPORARY:
			head_eave_mat = mat_contemporary_panel_dark
			head_eave_depth = 0.22
			head_eave_rotation = Vector3.ZERO
		_add_facade_detail_box(root, "UpperShopHeadEave",
			Vector3(0.0, height - 0.14, -depth_m * 0.5 - 0.18),
			Vector3(width_m * 0.82, 0.09, head_eave_depth), head_eave_mat, head_eave_rotation)

	_add_gutter_downpipe(root, "Shop", width_m * (-0.42 if facade_seed % 2 == 0 else 0.42),
		height - 0.08, -depth_m * 0.5 - 0.16, maxf(1.2, height - floor_h - 0.38))
	_add_utility_box_cluster(root, "Shop", width_m * (0.30 if facade_seed % 3 == 0 else -0.30),
		minf(height - 1.10, floor_h + 0.92), -depth_m * 0.5 - 0.010)
	_add_wall_ac_unit(root, width_m * 0.42, minf(4.0, height - 1.0), -depth_m * 0.515)
	_add_exposed_service_pipe(root, -width_m * 0.43, height * 0.48, -depth_m * 0.5 - 0.055, height * 0.80)
	if shop_archetype != SHOP_SHUTTERED and town_rng.randf() < 0.48:
		var projecting_sign_mat: Material = _shop_sign_material(shop_archetype)
		if facade_style == SHOP_FACADE_RENOVATED:
			projecting_sign_mat = mat_sign_blue
		elif facade_style == SHOP_FACADE_CONTEMPORARY:
			projecting_sign_mat = mat_contemporary_led
		_add_projecting_sign(root, width_m, depth_m, minf(height - 0.9, 3.9), projecting_sign_mat)
	if not used_imported_roof:
		# Preserve the original roof RNG draw even when a fully contemporary
		# façade forces a flat parapet. This keeps downstream procedural output
		# aligned with the locked comparison seed.
		var roof_roll: float = town_rng.randf()
		if facade_style == SHOP_FACADE_CONTEMPORARY:
			_add_rooftop_parapet(root, width_m, depth_m, height)
		elif roof_roll < 0.62:
			_add_gable_roof(root, width_m, depth_m, height, mat_roof, mat_tile, 17.0, true, body_mat)
		else:
			_add_rooftop_parapet(root, width_m, depth_m, height)
	if district == DISTRICT_OVERGROWN:
		_add_planter_strip(root, width_m, depth_m, height)

func _choose_shop_facade_style(
	position_value: Vector3,
	district: int,
	facade_seed: int
) -> int:
	# v10.26b remains deliberately local: modernise the north commercial wall of the
	# locked east/west test corridor while preserving the same road, camera and
	# procedural seed for a clean before/after comparison. No RNG is consumed.
	if not commercial_test_corridor_mode or district != DISTRICT_COMMERCIAL:
		return SHOP_FACADE_HERITAGE

	var corridor_a: Vector3 = _cell_to_world(VISUAL_TEST_CORRIDOR_START, 0.0)
	var corridor_b: Vector3 = _cell_to_world(VISUAL_TEST_CORRIDOR_END, 0.0)
	var min_x: float = minf(corridor_a.x, corridor_b.x) - TILE_SIZE * 0.75
	var max_x: float = maxf(corridor_a.x, corridor_b.x) + TILE_SIZE * 0.75
	var corridor_z: float = (corridor_a.z + corridor_b.z) * 0.5

	var on_north_wall: bool = (
		position_value.z < corridor_z - 0.35
		and position_value.z > corridor_z - TILE_SIZE * 2.75
	)
	var within_corridor: bool = position_value.x >= min_x and position_value.x <= max_x
	if not on_north_wall or not within_corridor:
		return SHOP_FACADE_HERITAGE

	# v10.26b target mix for the locked road: 30% preserved heritage, 50%
	# renovated old shells, 20% fully contemporary commercial frontage. Use a
	# deterministic 20-slot rule so the style choice adds no RNG calls.
	var style_slot: int = abs(facade_seed) % 20
	if style_slot < 6:
		return SHOP_FACADE_HERITAGE
	if style_slot < 16:
		return SHOP_FACADE_RENOVATED
	return SHOP_FACADE_CONTEMPORARY

func _choose_shop_archetype(enterable: bool) -> int:
	if not enterable and town_rng.randf() < 0.72:
		return SHOP_SHUTTERED
	var roll: float = town_rng.randf()
	if roll < 0.24:
		return SHOP_RAMEN
	if roll < 0.45:
		return SHOP_IZAKAYA
	if roll < 0.61:
		return SHOP_CONVENIENCE
	if roll < 0.76:
		return SHOP_REPAIR
	if roll < 0.94:
		return SHOP_RESIDENTIAL_MIX
	return SHOP_SHUTTERED

func _shop_body_material(shop_archetype: int, district: int) -> Material:
	if district == DISTRICT_OVERGROWN:
		return mat_dirty_plaster if town_rng.randf() < 0.58 else mat_plaster_soot
	if shop_archetype == SHOP_RAMEN or shop_archetype == SHOP_IZAKAYA or shop_archetype == SHOP_RESIDENTIAL_MIX:
		var roll: float = town_rng.randf()
		if roll < 0.58:
			return mat_shop_plaster
		if roll < 0.82:
			return mat_plaster_cool
		return mat_plaster_soot
	match shop_archetype:
		SHOP_REPAIR:
			return mat_oxidized_metal if town_rng.randf() < 0.42 else mat_concrete_stained
		SHOP_CONVENIENCE:
			return mat_concrete_cool if town_rng.randf() < 0.52 else mat_concrete_stained
		_:
			return mat_concrete_stained

func _shop_frame_material(shop_archetype: int) -> Material:
	match shop_archetype:
		SHOP_RAMEN, SHOP_IZAKAYA, SHOP_RESIDENTIAL_MIX:
			return mat_weathered_timber
		SHOP_REPAIR:
			return mat_oxidized_metal
		SHOP_CONVENIENCE:
			return mat_weathered_metal
		_:
			return mat_dark_wood

func _shop_sign_material(shop_archetype: int) -> Material:
	match shop_archetype:
		SHOP_RAMEN, SHOP_IZAKAYA:
			return mat_sign_red
		SHOP_CONVENIENCE:
			return mat_sign_blue
		SHOP_REPAIR:
			return mat_sign_warm
		SHOP_RESIDENTIAL_MIX:
			return mat_sign_pink
		_:
			return mat_dark_wood

func _shop_window_material(shop_archetype: int, secondary: bool = false) -> Material:
	# v10.21: active storefronts are glass apertures into the interior, not
	# opaque emissive rectangles. Interior meshes and the existing capped shop
	# lights now provide most of the visible warmth through these panes.
	match shop_archetype:
		SHOP_RAMEN:
			return mat_storefront_glass_warm if not secondary else mat_storefront_glass_dark
		SHOP_IZAKAYA:
			return mat_storefront_glass_warm if not secondary else mat_storefront_glass_dark
		SHOP_CONVENIENCE:
			return mat_storefront_glass_cool if not secondary else mat_storefront_glass_dark
		SHOP_REPAIR:
			return mat_storefront_glass_dark
		SHOP_RESIDENTIAL_MIX:
			return mat_storefront_glass_warm if not secondary else mat_storefront_glass_dark
		_:
			return mat_storefront_glass_dark

func _add_shopfront_facade(
	root: Node3D,
	width_m: float,
	depth_m: float,
	height: float,
	shop_archetype: int,
	enterable: bool,
	facade_style: int = SHOP_FACADE_HERITAGE
) -> void:
	var sign_mat: Material = _shop_sign_material(shop_archetype)
	var frame_mat: Material = _shop_frame_material(shop_archetype)
	if facade_style == SHOP_FACADE_RENOVATED:
		frame_mat = mat_black_metal
		sign_mat = mat_sign_blue if shop_archetype == SHOP_CONVENIENCE or shop_archetype == SHOP_REPAIR else mat_sign_warm
	elif facade_style == SHOP_FACADE_CONTEMPORARY:
		frame_mat = mat_contemporary_panel_dark
		sign_mat = mat_contemporary_led
	var facade_plane_z: float = -depth_m * 0.5
	var doorway_half: float = minf(0.72, width_m * 0.15)

	# v10.25a: the old storefront panes were narrow independent rectangles and
	# their depth origin sat well in front of the actual facade plane. In motion
	# this made some shop windows look like dark panels floating off the wall.
	# Build two proper bays between the outside posts and the central doorway,
	# with glass slightly recessed behind the wall plane and trim only slightly
	# proud of it. The frontage now reads as one construction assembly.
	if shop_archetype != SHOP_SHUTTERED:
		var bay_outer: float = width_m * 0.43 - 0.10
		var bay_inner: float = doorway_half + 0.10
		var bay_width: float = maxf(0.62, bay_outer - bay_inner)
		var bay_center_abs: float = bay_inner + bay_width * 0.5
		var bay_height: float = 1.70
		var bay_center_y: float = 1.40

		var left_glass: Material = _shop_window_material(shop_archetype, false) if enterable else mat_window_dark_opaque
		var right_glass: Material = _shop_window_material(shop_archetype, true) if enterable else mat_window_dark_opaque
		_add_storefront_bay(root, "StoreBayL", -bay_center_abs, bay_center_y, facade_plane_z,
			bay_width, bay_height, left_glass, frame_mat, enterable)
		_add_storefront_bay(root, "StoreBayR", bay_center_abs, bay_center_y, facade_plane_z,
			bay_width, bay_height, right_glass, frame_mat, enterable)
		# Base panels terminate at the doorway instead of running as one bar
		# across the entrance. This visually locks each glazed bay into the wall.
		_add_local_box(root, "StoreBayBaseL", Vector3(-bay_center_abs, 0.30, facade_plane_z - 0.035),
			Vector3(bay_width + 0.08, 0.36, 0.07), frame_mat)
		_add_local_box(root, "StoreBayBaseR", Vector3(bay_center_abs, 0.30, facade_plane_z - 0.035),
			Vector3(bay_width + 0.08, 0.36, 0.07), frame_mat)

	# The frame, entrance and glazed bays now share the same wall reference
	# instead of each using a different percentage of building depth.
	if shop_archetype != SHOP_SHUTTERED:
		for frame_side: float in [-1.0, 1.0]:
			_add_local_box(root, "StorefrontPost",
				Vector3(width_m * 0.43 * frame_side, 1.42, facade_plane_z - 0.055),
				Vector3(0.11, 2.18, 0.11), frame_mat)
		_add_local_box(root, "StorefrontBeam", Vector3(0.0, 2.44, facade_plane_z - 0.055),
			Vector3(width_m * 0.84, 0.12, 0.11), frame_mat)

		for doorway_side: float in [-1.0, 1.0]:
			_add_local_box(root, "EntranceJamb",
				Vector3(doorway_half * doorway_side, 1.30, facade_plane_z - 0.060),
				Vector3(0.085, 2.02, 0.10), frame_mat)
		_add_local_box(root, "EntranceLintel", Vector3(0.0, 2.30, facade_plane_z - 0.060),
			Vector3(doorway_half * 2.0 + 0.14, 0.10, 0.10), frame_mat)
		_add_local_box(root, "StoreThreshold", Vector3(0.0, 0.075, facade_plane_z - 0.085),
			Vector3(doorway_half * 2.0 + 0.10, 0.07, 0.30), frame_mat)
		var storefront_ground_strip: MeshInstance3D = _add_local_box(
			root, "StorefrontWetApron", Vector3(0.0, 0.065, facade_plane_z - 0.32),
			Vector3(width_m * 0.62, 0.025, 0.78),
			mat_storefront_apron
		)
		storefront_ground_strip.add_to_group("shinrai_storefront_ground_strip")
		_add_storefront_reflection_streaks(root, width_m, depth_m, shop_archetype)

	# v10.26g: SHOP_IZAKAYA is the existing yakitori/izakaya food-service
	# archetype. Attach the supplied real-world-scale やきとり hero lantern to
	# every such active frontage, including renovated/contemporary shells. The
	# helper chooses a canopy-safe mount point without rescaling or corrective
	# root rotation, so the asset's authored local -Z lettering faces the street.
	if shop_archetype == SHOP_IZAKAYA:
		_add_yakitori_lantern(root, width_m, facade_plane_z, facade_style)

	if facade_style == SHOP_FACADE_RENOVATED:
		_add_renovated_shopfront_facade(root, width_m, facade_plane_z, sign_mat, frame_mat)
		return
	if facade_style == SHOP_FACADE_CONTEMPORARY:
		_add_contemporary_shopfront_facade(root, width_m, facade_plane_z, sign_mat, frame_mat)
		return

	match shop_archetype:
		SHOP_RAMEN:
			_add_local_box(root, "RamenAwning", Vector3(0.0, 2.48, facade_plane_z - 0.42),
				Vector3(width_m * 0.86, 0.12, 0.82), mat_dark_wood, Vector3(deg_to_rad(-8.0), 0.0, 0.0))
			_add_local_box(root, "RamenHeaderBacking", Vector3(0.0, 2.70, facade_plane_z - 0.075),
				Vector3(width_m * 0.58, 0.40, 0.08), mat_black_metal)
			_add_local_box(root, "RamenHeaderSign", Vector3(0.0, 2.70, facade_plane_z - 0.080),
				Vector3(width_m * 0.54, 0.34, 0.10), sign_mat)
			_add_food_sign_strokes(root, 0.0, 2.70, facade_plane_z - 0.156, width_m * 0.54, 0.34)
			_add_sign_face_frame(root, "RamenSignFrame", 0.0, 2.70, facade_plane_z - 0.135, width_m * 0.54, 0.34, frame_mat)
			_add_local_box(root, "RamenUnderEaveGlow", Vector3(0.0, 2.34, facade_plane_z - 0.22),
				Vector3(width_m * 0.56, 0.035, 0.16), mat_interior_task_warm)
			_add_shop_lantern(root, -width_m * 0.39, 2.10, facade_plane_z - 0.135, mat_neon_red)
		SHOP_IZAKAYA:
			_add_local_box(root, "IzakayaHeaderBacking", Vector3(0.0, 2.68, facade_plane_z - 0.075),
				Vector3(width_m * 0.48, 0.36, 0.08), mat_black_metal)
			_add_local_box(root, "IzakayaHeader", Vector3(0.0, 2.68, facade_plane_z - 0.080),
				Vector3(width_m * 0.44, 0.30, 0.10), sign_mat)
			_add_food_sign_strokes(root, 0.0, 2.68, facade_plane_z - 0.156, width_m * 0.44, 0.30)
			_add_sign_face_frame(root, "IzakayaSignFrame", 0.0, 2.68, facade_plane_z - 0.135, width_m * 0.44, 0.30, frame_mat)
			# Four shorter strips with small gaps read as hanging fabric rather
			# than the large dark rectangular slabs visible in the v10.20 test.
			_add_local_cylinder(root, "NorenRod", Vector3(0.0, 2.38, facade_plane_z - 0.28),
				0.025, minf(1.52, width_m * 0.38), mat_black_metal, Vector3(0.0, 0.0, PI * 0.5))
			for panel: int in range(4):
				var x: float = (float(panel) - 1.5) * 0.33
				var tilt: float = deg_to_rad(-1.5 + float(panel) * 1.0)
				_add_local_box(root, "Noren", Vector3(x, 2.13, facade_plane_z - 0.28),
					Vector3(0.26, 0.44, 0.022), mat_noren_red, Vector3(0.0, 0.0, tilt))
			_add_local_box(root, "IzakayaEntranceGlow", Vector3(0.0, 2.35, facade_plane_z - 0.18),
				Vector3(width_m * 0.34, 0.032, 0.14), mat_interior_bar_warm)
		SHOP_CONVENIENCE:
			_add_local_box(root, "ConvenienceBandBacking", Vector3(0.0, 2.58, facade_plane_z - 0.075),
				Vector3(width_m * 0.84, 0.34, 0.08), mat_black_metal)
			_add_local_box(root, "ConvenienceBand", Vector3(0.0, 2.58, facade_plane_z - 0.080),
				Vector3(width_m * 0.80, 0.28, 0.10), sign_mat)
			_add_local_box(root, "ConvenienceWhiteBand", Vector3(0.0, 2.37, facade_plane_z - 0.085),
				Vector3(width_m * 0.76, 0.08, 0.105), mat_soft_white)
		SHOP_REPAIR:
			_add_local_box(root, "RepairLintelBacking", Vector3(0.0, 2.55, facade_plane_z - 0.075),
				Vector3(width_m * 0.72, 0.34, 0.08), mat_black_metal)
			_add_local_box(root, "RepairLintel", Vector3(0.0, 2.55, facade_plane_z - 0.080),
				Vector3(width_m * 0.68, 0.28, 0.10), sign_mat)
			for rib: int in range(5):
				var x: float = (float(rib) / 4.0 - 0.5) * width_m * 0.70
				_add_local_box(root, "ShutterGuide", Vector3(x, 1.30, facade_plane_z - 0.075),
					Vector3(0.035, 1.78, 0.045), mat_black_metal)
		SHOP_RESIDENTIAL_MIX:
			_add_local_box(root, "MixedAwning", Vector3(0.0, 2.48, facade_plane_z - 0.40),
				Vector3(width_m * 0.70, 0.11, 0.76), mat_dark_wood, Vector3(deg_to_rad(-6.0), 0.0, 0.0))
			_add_local_box(root, "MixedHeaderBacking", Vector3(width_m * 0.16, 2.70, facade_plane_z - 0.075),
				Vector3(width_m * 0.36, 0.34, 0.08), mat_black_metal)
			_add_local_box(root, "MixedHeader", Vector3(width_m * 0.16, 2.70, facade_plane_z - 0.080),
				Vector3(width_m * 0.32, 0.28, 0.10), sign_mat)
		SHOP_SHUTTERED:
			# Closed storefront for visual variety. Never blocks an enterable opening.
			if not enterable:
				_add_local_box(root, "ClosedShutter", Vector3(0.0, 1.35, facade_plane_z - 0.075),
					Vector3(width_m * 0.76, 2.15, 0.08), mat_black_metal)
				for rib_y: int in range(7):
					_add_local_box(root, "ShutterRib", Vector3(0.0, 0.58 + float(rib_y) * 0.25, facade_plane_z - 0.105),
						Vector3(width_m * 0.72, 0.025, 0.025), mat_soft_white)
			_add_local_box(root, "ClosedHeader", Vector3(0.0, 2.58, facade_plane_z - 0.080),
				Vector3(width_m * 0.52, 0.26, 0.10), mat_dark_wood)

func _add_contemporary_shopfront_facade(
	root: Node3D,
	width_m: float,
	facade_plane_z: float,
	sign_mat: Material,
	frame_mat: Material
) -> void:
	# A genuinely new-build commercial frontage rather than a retrofit shell.
	# Flush manufactured panels, a shallow integrated canopy, large glazing
	# framing and neutral digital/service hardware remove the heritage cues while
	# retaining believable human-scale Japanese street proportions.
	_add_local_box(root, "ContemporaryPortalHeader",
		Vector3(0.0, 2.67, facade_plane_z - 0.075),
		Vector3(width_m * 0.88, 0.46, 0.10), mat_contemporary_panel)
	for side: float in [-1.0, 1.0]:
		_add_local_box(root, "ContemporaryPortalBlade",
			Vector3(width_m * 0.435 * side, 1.42, facade_plane_z - 0.080),
			Vector3(0.16, 2.34, 0.12), mat_contemporary_panel_dark)

	# Very shallow manufactured canopy: deliberately not a tiled/wood eave.
	_add_local_box(root, "ContemporaryCanopy",
		Vector3(0.0, 2.47, facade_plane_z - 0.225),
		Vector3(width_m * 0.82, 0.07, 0.34), frame_mat)
	_add_local_box(root, "ContemporaryLinearDiffuser",
		Vector3(0.0, 2.425, facade_plane_z - 0.245),
		Vector3(width_m * 0.62, 0.018, 0.15), mat_contemporary_led)

	# Wide, low-information digital header keeps signage contemporary without
	# turning the street into a wall of neon.
	var header_w: float = width_m * 0.52
	_add_local_box(root, "ContemporaryDigitalHeaderBacking",
		Vector3(-width_m * 0.08, 2.70, facade_plane_z - 0.137),
		Vector3(header_w + 0.06, 0.20, 0.040), frame_mat)
	_add_local_box(root, "ContemporaryDigitalHeader",
		Vector3(-width_m * 0.08, 2.70, facade_plane_z - 0.162),
		Vector3(header_w, 0.135, 0.022), sign_mat)

	# Compact service stack: address/status display, access control and parcel/
	# utility panel. All are geometry/material only in this approval pass.
	var service_x: float = width_m * 0.345
	_add_local_box(root, "ContemporaryServiceSpine",
		Vector3(service_x, 1.48, facade_plane_z - 0.100),
		Vector3(0.36, 1.62, 0.065), mat_contemporary_panel_dark)
	_add_local_box(root, "ContemporaryAddressDisplay",
		Vector3(service_x, 1.91, facade_plane_z - 0.140),
		Vector3(0.24, 0.36, 0.026), mat_contemporary_led)
	_add_local_box(root, "ContemporaryAccessPad",
		Vector3(service_x, 1.56, facade_plane_z - 0.144),
		Vector3(0.16, 0.14, 0.028), mat_soft_white)
	_add_local_box(root, "ContemporaryParcelPanel",
		Vector3(service_x, 0.93, facade_plane_z - 0.142),
		Vector3(0.26, 0.52, 0.028), mat_contemporary_panel)
	for seam: int in range(2):
		_add_local_box(root, "ContemporaryParcelSeam",
			Vector3(service_x, 0.82 + float(seam) * 0.22, facade_plane_z - 0.160),
			Vector3(0.18, 0.018, 0.016), mat_black_metal)

	# Door presence / occupancy sensor bar above the central entry.
	_add_local_box(root, "ContemporaryDoorSensorBar",
		Vector3(0.0, 2.28, facade_plane_z - 0.145),
		Vector3(0.46, 0.055, 0.045), mat_contemporary_panel_dark)
	_add_local_box(root, "ContemporaryDoorSensor",
		Vector3(0.0, 2.275, facade_plane_z - 0.174),
		Vector3(0.10, 0.025, 0.018), mat_contemporary_led)


func _add_contemporary_upper_facade(
	root: Node3D,
	width_m: float,
	depth_m: float,
	height: float,
	floor_h: float,
	floors: int,
	facade_seed: int
) -> void:
	# Carry the new-build language above the shopfront so the future date still
	# reads when the ground-floor signage is out of frame. Keep the geometry
	# shallow and deterministic: metal service spine + manufactured floor hoods.
	var facade_z: float = -depth_m * 0.5 - 0.072
	var upper_height: float = maxf(0.55, height - floor_h - 0.26)
	var spine_x: float = width_m * (0.39 if facade_seed % 2 == 0 else -0.39)
	_add_facade_detail_box(root, "ContemporaryUpperServiceSpine",
		Vector3(spine_x, floor_h + upper_height * 0.5, facade_z),
		Vector3(0.22, upper_height, 0.10), mat_contemporary_panel_dark)

	for floor_index: int in range(1, floors):
		var y_value: float = 1.48 + float(floor_index) * floor_h
		_add_facade_detail_box(root, "ContemporaryWindowHood",
			Vector3(0.0, y_value + 0.58, facade_z - 0.035),
			Vector3(width_m * 0.70, 0.065, 0.20), mat_contemporary_panel_dark)
		# One small neutral status strip per occupied upper floor gives the block
		# a current infrastructure language without adding a real light source.
		_add_facade_detail_box(root, "ContemporaryFloorStatus",
			Vector3(-spine_x * 0.94, y_value + 0.50, facade_z - 0.092),
			Vector3(0.20, 0.045, 0.022), mat_contemporary_led)

func _add_renovated_shopfront_facade(
	root: Node3D,
	width_m: float,
	facade_plane_z: float,
	sign_mat: Material,
	frame_mat: Material
) -> void:
	# Contemporary intervention layered onto the existing Japanese shop shell:
	# aluminium/steel framing, a flat manufactured canopy, composite fascia and
	# restrained digital/e-ink-like signage. It intentionally uses no new real
	# lights so this first art-direction pass cannot disturb the light budget.
	_add_local_box(root, "RenovatedCompositeFascia",
		Vector3(0.0, 2.68, facade_plane_z - 0.070),
		Vector3(width_m * 0.84, 0.42, 0.08), mat_concrete_cool)
	_add_local_box(root, "RenovatedCanopy",
		Vector3(0.0, 2.48, facade_plane_z - 0.31),
		Vector3(width_m * 0.82, 0.085, 0.52), mat_black_metal)
	_add_local_box(root, "RenovatedCanopyDiffuser",
		Vector3(0.0, 2.425, facade_plane_z - 0.34),
		Vector3(width_m * 0.56, 0.022, 0.24), mat_interior_cool)

	var header_x: float = -width_m * 0.12
	var header_w: float = width_m * 0.46
	_add_local_box(root, "RenovatedDigitalHeaderBacking",
		Vector3(header_x, 2.70, facade_plane_z - 0.122),
		Vector3(header_w + 0.08, 0.24, 0.045), frame_mat)
	_add_local_box(root, "RenovatedDigitalHeader",
		Vector3(header_x, 2.70, facade_plane_z - 0.151),
		Vector3(header_w, 0.17, 0.026), sign_mat)
	_add_sign_face_frame(root, "RenovatedHeaderFrame", header_x, 2.70,
		facade_plane_z - 0.174, header_w, 0.17, frame_mat)

	# Narrow address/status panel gives the façade a recognisably contemporary
	# Japanese service layer without turning the street into generic cyberpunk.
	var panel_x: float = width_m * 0.345
	_add_local_box(root, "RenovatedAddressPanelBacking",
		Vector3(panel_x, 1.83, facade_plane_z - 0.105),
		Vector3(0.29, 0.72, 0.06), frame_mat)
	_add_local_box(root, "RenovatedAddressPanel",
		Vector3(panel_x, 1.83, facade_plane_z - 0.142),
		Vector3(0.22, 0.62, 0.026), mat_soft_white)
	_add_local_box(root, "RenovatedAddressStatus",
		Vector3(panel_x, 2.02, facade_plane_z - 0.160),
		Vector3(0.13, 0.055, 0.018), mat_sign_blue)
	for tick: int in range(3):
		_add_local_box(root, "RenovatedAddressTick",
			Vector3(panel_x, 1.88 - float(tick) * 0.13, facade_plane_z - 0.160),
			Vector3(0.11 - float(tick) * 0.015, 0.022, 0.018), mat_black_metal)

	# A small sensor puck and clean service strip sell the retrofit story.
	_add_local_box(root, "RenovatedSensor",
		Vector3(-width_m * 0.35, 2.30, facade_plane_z - 0.145),
		Vector3(0.12, 0.08, 0.08), mat_black_metal)
	_add_local_box(root, "RenovatedLowerServiceStrip",
		Vector3(0.0, 0.43, facade_plane_z - 0.060),
		Vector3(width_m * 0.82, 0.10, 0.07), mat_weathered_metal)

func _add_storefront_reflection_streaks(
	root: Node3D,
	width_m: float,
	depth_m: float,
	shop_archetype: int
) -> void:
	# In Compatibility, emissive signs do not illuminate surrounding geometry
	# without a GI solution. Use at most two faint, close-range alpha streaks on
	# a small number of active storefronts to suggest broken wet reflections.
	if storefront_reflection_shop_count >= MAX_STOREFRONT_REFLECTION_SHOPS:
		return
	if shop_archetype == SHOP_SHUTTERED or shop_archetype == SHOP_REPAIR:
		return

	var reflection_mat: Material = mat_reflection_warm
	if shop_archetype == SHOP_IZAKAYA or shop_archetype == SHOP_RAMEN:
		reflection_mat = mat_reflection_red
	elif shop_archetype == SHOP_CONVENIENCE:
		reflection_mat = mat_reflection_cool

	var front_edge: float = -depth_m * 0.5
	# v10.25c: use three narrower, offset fragments instead of two broad slabs.
	# More of the blue-grey asphalt now stays visible between coloured highlights.
	var main_strip: MeshInstance3D = _add_local_box(root, "WetReflectionMain",
		Vector3(-width_m * 0.12, 0.092, front_edge - 0.68),
		Vector3(maxf(0.18, width_m * 0.090), 0.009, 0.78), reflection_mat,
		Vector3(0.0, deg_to_rad(2.5), 0.0))
	main_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main_strip.visibility_range_end = STOREFRONT_REFLECTION_VISIBILITY_RANGE
	main_strip.visibility_range_end_margin = 4.0
	main_strip.add_to_group("shinrai_wet_ground_reflection")

	var secondary_strip: MeshInstance3D = _add_local_box(root, "WetReflectionBreak",
		Vector3(width_m * 0.10, 0.093, front_edge - 0.96),
		Vector3(maxf(0.12, width_m * 0.055), 0.008, 0.42), reflection_mat,
		Vector3(0.0, deg_to_rad(-4.0), 0.0))
	secondary_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	secondary_strip.visibility_range_end = STOREFRONT_REFLECTION_VISIBILITY_RANGE
	secondary_strip.visibility_range_end_margin = 4.0
	secondary_strip.add_to_group("shinrai_wet_ground_reflection")

	var tertiary_strip: MeshInstance3D = _add_local_box(root, "WetReflectionFragment",
		Vector3(-width_m * 0.02, 0.094, front_edge - 1.20),
		Vector3(maxf(0.10, width_m * 0.042), 0.008, 0.28), reflection_mat,
		Vector3(0.0, deg_to_rad(5.0), 0.0))
	tertiary_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tertiary_strip.visibility_range_end = STOREFRONT_REFLECTION_VISIBILITY_RANGE
	tertiary_strip.visibility_range_end_margin = 4.0
	tertiary_strip.add_to_group("shinrai_wet_ground_reflection")
	storefront_reflection_shop_count += 1

func _add_sign_face_frame(
	root: Node3D,
	prefix: String,
	center_x: float,
	center_y: float,
	front_z: float,
	width_value: float,
	height_value: float,
	frame_material: Material
) -> void:
	# Four slim rails keep illuminated faces visibly physical at night. They
	# are distance-culled meshes and do not add lights or shadow casters.
	var rail_t: float = 0.045
	_add_local_box(root, prefix + "Top", Vector3(center_x, center_y + height_value * 0.5, front_z),
		Vector3(width_value + rail_t, rail_t, 0.035), frame_material)
	_add_local_box(root, prefix + "Bottom", Vector3(center_x, center_y - height_value * 0.5, front_z),
		Vector3(width_value + rail_t, rail_t, 0.035), frame_material)

func _add_food_sign_strokes(
	root: Node3D,
	center_x: float,
	center_y: float,
	front_z: float,
	sign_width: float,
	sign_height: float
) -> void:
	# Three low-cost abstract lettering strokes break the flat emissive rectangle
	# silhouette without introducing fonts, labels or unique sign textures.
	var stroke_h: float = sign_height * 0.48
	_add_local_box(root, "SignStroke",
		Vector3(center_x - sign_width * 0.18, center_y, front_z),
		Vector3(0.035, stroke_h, 0.018), mat_sign_letter)
	_add_local_box(root, "SignStroke",
		Vector3(center_x, center_y + sign_height * 0.10, front_z),
		Vector3(sign_width * 0.16, 0.035, 0.018), mat_sign_letter)
	_add_local_box(root, "SignStroke",
		Vector3(center_x + sign_width * 0.18, center_y - sign_height * 0.08, front_z),
		Vector3(0.035, stroke_h * 0.78, 0.018), mat_sign_letter)

func _configure_yakitori_lantern_tree(node: Node) -> bool:
	var has_imported_light: bool = false
	if node is GeometryInstance3D:
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		geometry.visibility_range_end = YAKITORI_LANTERN_VISIBILITY_RANGE
		geometry.visibility_range_end_margin = YAKITORI_LANTERN_VISIBILITY_MARGIN
	if node is Light3D:
		# Preserve the GLB-authored KHR_lights_punctual colour/intensity/range.
		# glTF does not encode a shadow flag, so do not override Godot's import
		# behaviour here; the documented shadowed fallback is added only when
		# no imported Light3D exists at all.
		var imported_light: Light3D = node as Light3D
		imported_light.add_to_group("shinrai_yakitori_lantern_light")
		has_imported_light = true
	for child: Node in node.get_children():
		if _configure_yakitori_lantern_tree(child):
			has_imported_light = true
	return has_imported_light

func _add_yakitori_lantern(
	root: Node3D,
	width_m: float,
	facade_plane_z: float,
	facade_style: int
) -> void:
	var lantern_root: Node3D = YakitoriLanternScene.instantiate() as Node3D
	if lantern_root == null:
		push_warning("v10.26g yakitori lantern instantiate failed for %s" % root.name)
		return

	# Heritage shops hang the lantern beside the traditional sign/noren. The
	# renovated and contemporary kits reserve +X for service/address hardware,
	# so their lantern shifts to -X and seats directly below the manufactured
	# canopy. These are translations only: the master GLB remains 1:1 scale,
	# Y-up, and unrotated so its authored -Z front continues to face the street.
	var side: float = 1.0
	var mount_y: float = 2.10
	var mount_z: float = facade_plane_z - 0.20
	if facade_style == SHOP_FACADE_RENOVATED:
		side = -1.0
		mount_y = 1.88
		mount_z = facade_plane_z - 0.31
	elif facade_style == SHOP_FACADE_CONTEMPORARY:
		side = -1.0
		mount_y = 1.88
		mount_z = facade_plane_z - 0.225

	lantern_root.name = "YakitoriLantern"
	lantern_root.position = Vector3(width_m * 0.39 * side, mount_y, mount_z)
	root.add_child(lantern_root)
	root.add_to_group("shinrai_yakitori_shop")
	lantern_root.add_to_group("shinrai_yakitori_lantern")

	var has_imported_light: bool = _configure_yakitori_lantern_tree(lantern_root)
	if has_imported_light:
		return

	# AI_HANDOFF fallback contract: local-origin warm orange Omni, ~2.5 m
	# range, shadows enabled. Energy is calibrated to Shinrai's non-physical
	# light scale while the authored emissive PBR material remains untouched.
	var fallback_light: OmniLight3D = OmniLight3D.new()
	fallback_light.name = "YakitoriLanternFallbackLight"
	fallback_light.position = Vector3.ZERO
	fallback_light.light_color = Color(1.0, 0.48, 0.22)
	fallback_light.light_energy = YAKITORI_LANTERN_FALLBACK_LIGHT_ENERGY
	fallback_light.omni_range = YAKITORI_LANTERN_FALLBACK_LIGHT_RANGE
	fallback_light.omni_attenuation = 1.25
	fallback_light.shadow_enabled = true
	lantern_root.add_child(fallback_light)
	fallback_light.add_to_group("shinrai_yakitori_lantern_light")

func _add_shop_lantern(root: Node3D, x: float, y: float, z: float, lantern_mat: Material) -> void:
	_add_local_cylinder(root, "ShopLantern", Vector3(x, y, z), 0.18, 0.46, lantern_mat)
	_add_local_box(root, "LanternCap", Vector3(x, y + 0.25, z), Vector3(0.22, 0.04, 0.22), mat_black_metal)

func _build_apartment(
	building_name: String,
	position_value: Vector3,
	width_m: float,
	depth_m: float,
	_district: int,
	front_yaw: float,
	balcony_side_sign: float = 1.0
) -> void:
	# Reference pass 2 adds the authored balcony system to the approved shell.
	# Loose props, signs, AC units, pipes, plants and furniture remain excluded.
	var root: Node3D = _new_building_root(building_name, position_value, front_yaw)
	root.add_to_group("shinrai_reference_apartment")
	root.set_meta("reference_stage", "reference_dimensions_and_relief_pass")
	root.set_meta("reference_width_m", width_m)
	root.set_meta("reference_depth_m", depth_m)
	root.set_meta("reference_body_height_m", APARTMENT_REFERENCE_BODY_HEIGHT_M)
	root.set_meta("reference_total_height_m", APARTMENT_REFERENCE_BODY_HEIGHT_M + 2.90)
	root.set_meta("balcony_clear_side", balcony_side_sign)
	root.set_meta("balcony_clearance_reserved", true)
	root.set_meta("balcony_module_width_m", 3.0)
	root.set_meta("balcony_module_depth_m", 1.2)
	root.set_meta("balcony_railing_height_m", 1.0)
	var floor_height: float = APARTMENT_REFERENCE_FLOOR_HEIGHT_M
	var floors: int = APARTMENT_REFERENCE_FLOOR_COUNT
	var height: float = APARTMENT_REFERENCE_BODY_HEIGHT_M
	var upper_height: float = height - floor_height
	var wall_t: float = 0.22
	var front_z: float = -depth_m * 0.5
	var rear_z: float = depth_m * 0.5
	# Deepen the façade reveal so the balcony/window bays read as part of the
	# concrete structure instead of modules pasted onto a flat wall.
	var frame_depth: float = clampf(depth_m * 0.15, 0.58, 0.72)
	var recess_z: float = front_z + frame_depth - 0.05
	# Seat the balcony slab slightly farther into that reveal while retaining
	# the authored 1.20 m module depth.
	var front_balcony_anchor_z: float = recess_z + 0.10
	var door_width: float = clampf(width_m * 0.19, 1.28, 1.64)
	# Use the same pier width at ground level and above so the façade corner is
	# one continuous structural line rather than two offset boxes.
	var edge_pier_w: float = clampf(width_m * 0.095, 0.54, 0.78)

	# Preserve a genuinely usable ground-floor entrance. Apartment mode aligns
	# every shell face inside the footprint and extends the ground-level front
	# frame to the same depth as the upper concrete piers.
	_add_enterable_ground_shell(
		root,
		width_m,
		depth_m,
		floor_height,
		mat_apartment_concrete,
		door_width,
		frame_depth,
		edge_pier_w,
		true
	)
	_add_open_door(root, depth_m, door_width, mat_black_metal)
	_add_building_collision(
		root,
		Vector3(width_m, upper_height, depth_m),
		Vector3(0.0, floor_height + upper_height * 0.5, 0.0)
	)

	# Five continuous slabs lock the 3.0 m floor rhythm and supply the strong
	# horizontal concrete edges visible in every reference elevation.
	for slab_level: int in range(1, floors + 1):
		var slab_y: float = float(slab_level) * floor_height
		_add_local_box(
			root,
			"ApartmentFloorSlab_%02d" % slab_level,
			Vector3(0.0, slab_y, 0.0),
			Vector3(width_m, 0.22, depth_m),
			mat_apartment_concrete
		)

	# Broad, almost blank shear walls define the narrow Japanese urban block.
	# Start them behind the front frame instead of overlapping the edge piers.
	# This removes the coplanar faces that produced the jagged left corner.
	var side_wall_depth: float = maxf(0.40, depth_m - frame_depth)
	var side_wall_center_z: float = (
		front_z + frame_depth + side_wall_depth * 0.5
	)
	for side: float in [-1.0, 1.0]:
		_add_local_box(
			root,
			"ApartmentSideShearWall",
			Vector3((width_m * 0.5 - wall_t * 0.5) * side,
				floor_height + upper_height * 0.5, side_wall_center_z),
			Vector3(wall_t, upper_height, side_wall_depth),
			mat_apartment_concrete
		)

	# The reference is carried by substantial full-height outer concrete piers.
	for side: float in [-1.0, 1.0]:
		_add_local_box(
			root,
			"ApartmentFrontEdgePier",
			Vector3((width_m * 0.5 - edge_pier_w * 0.5) * side,
				floor_height + upper_height * 0.5, front_z + frame_depth * 0.5),
			Vector3(edge_pier_w, upper_height, frame_depth),
			mat_apartment_concrete
		)

	# Full-width floor beams, edge piers and the central spine create the same
	# concrete grid as the reference behind the attached balcony modules.
	for level: int in range(1, floors + 1):
		_add_local_box(
			root,
			"ApartmentFrontFloorBeam_%02d" % level,
			Vector3(0.0, float(level) * floor_height, front_z + frame_depth * 0.5),
			Vector3(width_m, 0.28, frame_depth),
			mat_apartment_concrete
		)

	var paired_bays: bool = width_m >= 5.80
	var center_spine_w: float = clampf(width_m * 0.080, 0.46, 0.68) if paired_bays else 0.0
	if paired_bays:
		_add_local_box(
			root,
			"ApartmentFrontCentralSpine",
			Vector3(0.0, floor_height + upper_height * 0.5, front_z + frame_depth * 0.5),
			Vector3(center_spine_w, upper_height, frame_depth),
			mat_apartment_concrete
		)

	var bay_count: int = 2 if paired_bays else 1
	var bay_width: float = (
		(width_m - edge_pier_w * 2.0 - center_spine_w) / float(bay_count)
	)
	var balcony_root: Node3D = Node3D.new()
	balcony_root.name = "ApartmentBalconies"
	balcony_root.add_to_group("shinrai_apartment_balconies")
	root.add_child(balcony_root)
	for residential_level: int in range(1, floors):
		var slab_y: float = float(residential_level) * floor_height
		var opening_y: float = slab_y + 1.50
		for bay_index: int in range(bay_count):
			var bay_x: float = 0.0
			if paired_bays:
				var bay_side: float = -1.0 if bay_index == 0 else 1.0
				bay_x = bay_side * (center_spine_w * 0.5 + bay_width * 0.5)
			var balcony_width: float = clampf(minf(3.0, bay_width * 0.94), 1.55, 3.0)
			var opening_w: float = clampf(
				minf(bay_width * 0.76, balcony_width - 0.42), 0.96, 2.20
			)
			var module_prefix: String = (
				"ApartmentFrontBalcony_%02d_%02d" % [residential_level, bay_index]
			)
			_add_apartment_recessed_window(
				root,
				"ApartmentFrontBay_%02d_%02d" % [residential_level, bay_index],
				bay_x,
				opening_y,
				recess_z,
				opening_w,
				2.18,
				-1.0
			)
			_add_apartment_balcony_timber(
				balcony_root,
				module_prefix,
				Vector3(bay_x, opening_y, recess_z - 0.045),
				Vector3.RIGHT,
				Vector3.FORWARD,
				balcony_width,
				opening_w
			)
			_add_apartment_balcony_module(
				balcony_root,
				module_prefix,
				Vector3(bay_x, 0.0, front_balcony_anchor_z),
				Vector3.RIGHT,
				Vector3.FORWARD,
				balcony_width,
				slab_y,
				true
			)

	# The roof extension completes the timber ceiling above
	# the fourth-floor balcony without adding a fifth railing.
	for roof_bay_index: int in range(bay_count):
		var roof_bay_x: float = 0.0
		if paired_bays:
			var roof_bay_side: float = -1.0 if roof_bay_index == 0 else 1.0
			roof_bay_x = roof_bay_side * (center_spine_w * 0.5 + bay_width * 0.5)
		var roof_balcony_width: float = clampf(minf(3.0, bay_width * 0.94), 1.55, 3.0)
		_add_apartment_balcony_module(
			balcony_root,
			"ApartmentFrontBalconyRoof_%02d" % roof_bay_index,
			Vector3(roof_bay_x, 0.0, front_balcony_anchor_z),
			Vector3.RIGHT,
			Vector3.FORWARD,
			roof_balcony_width,
			height,
			false
		)

	# Reuse the established town façade glazing at ground level because its
	# frame/reveal proportions already match the reference entrance.
	var entrance_side_w: float = maxf(0.52, (width_m - door_width) * 0.5)
	var lobby_window_w: float = maxf(0.58, entrance_side_w * 0.70)
	var lobby_window_x: float = door_width * 0.5 + entrance_side_w * 0.5
	for side: float in [-1.0, 1.0]:
		_add_front_window(
			root,
			"ApartmentLobbyGlass",
			lobby_window_x * side,
			1.44,
			front_z - 0.018,
			lobby_window_w,
			1.78,
			mat_window_warm_dim,
			mat_black_metal
		)

	# The rear keeps broad blank concrete fields around one narrow vertical
	# window stack, matching the rear elevation while leaving balcony work out.
	var rear_bay_w: float = clampf(width_m * 0.38, 1.62, 2.90)
	var rear_field_w: float = maxf(0.42, (width_m - rear_bay_w) * 0.5)
	for side: float in [-1.0, 1.0]:
		_add_local_box(
			root,
			"ApartmentRearConcreteField",
			Vector3((rear_bay_w * 0.5 + rear_field_w * 0.5) * side,
				floor_height + upper_height * 0.5, rear_z - wall_t * 0.5),
			Vector3(rear_field_w, upper_height, wall_t),
			mat_apartment_concrete
		)
	for rear_level: int in range(1, floors):
		var rear_y: float = float(rear_level) * floor_height + 1.50
		_add_apartment_recessed_window(
			root,
			"ApartmentRearBay_%02d" % rear_level,
			0.0,
			rear_y,
			rear_z - 0.34,
			rear_bay_w * 0.72,
			1.86,
			1.0
		)
		_add_local_box(
			root,
			"ApartmentRearFloorBeam_%02d" % rear_level,
			Vector3(0.0, float(rear_level) * floor_height, rear_z - frame_depth * 0.5),
			Vector3(rear_bay_w, 0.24, frame_depth),
			mat_apartment_concrete
		)

	# A second stack wraps onto the deliberately reserved clear side. It uses
	# the same 1.20 m projection and floor rhythm as the front modules.
	var side_outward: Vector3 = Vector3(balcony_side_sign, 0.0, 0.0)
	var side_tangent: Vector3 = Vector3.BACK
	var side_wall_x: float = width_m * 0.5 * balcony_side_sign
	var side_center_z: float = -depth_m * 0.10
	var side_balcony_width: float = clampf(minf(3.0, depth_m * 0.58), 1.70, 3.0)
	var side_opening_w: float = clampf(
		minf(side_balcony_width * 0.64, side_balcony_width - 0.44), 1.02, 1.92
	)
	for side_level: int in range(1, floors):
		var side_slab_y: float = float(side_level) * floor_height
		var side_opening_y: float = side_slab_y + 1.50
		var side_prefix: String = "ApartmentSideBalcony_%02d" % side_level
		_add_apartment_oriented_window(
			balcony_root,
			side_prefix + "Door",
			Vector3(side_wall_x, side_opening_y, side_center_z),
			side_tangent,
			side_outward,
			side_opening_w,
			2.18
		)
		_add_apartment_balcony_timber(
			balcony_root,
			side_prefix,
			Vector3(side_wall_x, side_opening_y, side_center_z),
			side_tangent,
			side_outward,
			side_balcony_width,
			side_opening_w
		)
		_add_apartment_balcony_module(
			balcony_root,
			side_prefix,
			Vector3(side_wall_x, 0.0, side_center_z),
			side_tangent,
			side_outward,
			side_balcony_width,
			side_slab_y,
			true
		)
	_add_apartment_balcony_module(
		balcony_root,
		"ApartmentSideBalconyRoof",
		Vector3(side_wall_x, 0.0, side_center_z),
		side_tangent,
		side_outward,
		side_balcony_width,
		height,
		false
	)

	_add_apartment_reference_roof(root, width_m, depth_m, height)


func _add_apartment_recessed_window(
	root: Node3D,
	prefix: String,
	x_value: float,
	y_value: float,
	z_value: float,
	width_value: float,
	height_value: float,
	outward_sign: float
) -> void:
	# A dark concrete backing gives the bay real depth even before interiors and
	# balcony soffits are introduced. The glazing is reused from the town kit.
	var backing_z: float = z_value - outward_sign * 0.105
	var frame_z: float = z_value + outward_sign * 0.035
	_add_local_box(
		root,
		prefix + "Backing",
		Vector3(x_value, y_value, backing_z),
		Vector3(width_value + 0.28, height_value + 0.24, 0.08),
		mat_apartment_concrete_recess
	)
	_add_local_box(
		root,
		prefix + "Glass",
		Vector3(x_value, y_value, z_value),
		Vector3(width_value, height_value, 0.042),
		mat_window_warm_dim
	)
	var frame_t: float = 0.075
	_add_local_box(
		root,
		prefix + "FrameTop",
		Vector3(x_value, y_value + height_value * 0.5, frame_z),
		Vector3(width_value + 0.10, frame_t, 0.10),
		mat_black_metal
	)
	_add_local_box(
		root,
		prefix + "FrameBottom",
		Vector3(x_value, y_value - height_value * 0.5, frame_z),
		Vector3(width_value + 0.10, frame_t, 0.10),
		mat_black_metal
	)
	for side: float in [-1.0, 1.0]:
		_add_local_box(
			root,
			prefix + "FrameSide",
			Vector3(x_value + width_value * 0.5 * side, y_value, frame_z),
			Vector3(frame_t, height_value, 0.10),
			mat_black_metal
		)
	_add_local_box(
		root,
		prefix + "CenterMullion",
		Vector3(x_value, y_value, frame_z),
		Vector3(0.065, height_value, 0.105),
		mat_black_metal
	)


func _add_apartment_oriented_window(
	root: Node3D,
	prefix: String,
	center_value: Vector3,
	tangent: Vector3,
	outward: Vector3,
	width_value: float,
	height_value: float
) -> void:
	var glass_center: Vector3 = center_value + outward * 0.024
	var frame_center: Vector3 = center_value + outward * 0.060
	var tangent_is_x: bool = absf(tangent.x) > 0.5
	var glass_size: Vector3 = (
		Vector3(width_value, height_value, 0.042)
		if tangent_is_x
		else Vector3(0.042, height_value, width_value)
	)
	var horizontal_frame_size: Vector3 = (
		Vector3(width_value + 0.10, 0.075, 0.10)
		if tangent_is_x
		else Vector3(0.10, 0.075, width_value + 0.10)
	)
	var vertical_frame_size: Vector3 = (
		Vector3(0.075, height_value, 0.10)
		if tangent_is_x
		else Vector3(0.10, height_value, 0.075)
	)
	_add_local_box(root, prefix + "Glass", glass_center, glass_size, mat_window_warm_dim)
	_add_local_box(
		root, prefix + "FrameTop",
		frame_center + Vector3.UP * (height_value * 0.5),
		horizontal_frame_size, mat_black_metal
	)
	_add_local_box(
		root, prefix + "FrameBottom",
		frame_center - Vector3.UP * (height_value * 0.5),
		horizontal_frame_size, mat_black_metal
	)
	for side: float in [-1.0, 1.0]:
		_add_local_box(
			root, prefix + "FrameSide",
			frame_center + tangent * (width_value * 0.5 * side),
			vertical_frame_size, mat_black_metal
		)
	var mullion_size: Vector3 = (
		Vector3(0.065, height_value, 0.105)
		if tangent_is_x
		else Vector3(0.105, height_value, 0.065)
	)
	_add_local_box(root, prefix + "CenterMullion", frame_center, mullion_size, mat_black_metal)


func _add_apartment_balcony_timber(
	root: Node3D,
	prefix: String,
	window_center: Vector3,
	tangent: Vector3,
	outward: Vector3,
	module_width: float,
	opening_width: float
) -> void:
	var tangent_is_x: bool = absf(tangent.x) > 0.5
	var side_zone: float = maxf(0.12, (module_width - opening_width) * 0.5)
	var slats_per_side: int = clampi(roundi(side_zone / 0.105), 2, 4)
	var slat_size: Vector3 = (
		Vector3(0.045, 2.42, 0.075)
		if tangent_is_x
		else Vector3(0.075, 2.42, 0.045)
	)
	for side: float in [-1.0, 1.0]:
		for slat_index: int in range(slats_per_side):
			var slat_offset: float = (
				opening_width * 0.5
				+ side_zone * (float(slat_index) + 0.52) / float(slats_per_side)
			)
			_add_facade_detail_box(
				root,
				prefix + "TimberSlat",
				window_center + tangent * (slat_offset * side) + outward * 0.055,
				slat_size,
				mat_dark_wood
			)
	var lintel_size: Vector3 = (
		Vector3(module_width - 0.10, 0.12, 0.10)
		if tangent_is_x
		else Vector3(0.10, 0.12, module_width - 0.10)
	)
	_add_facade_detail_box(
		root,
		prefix + "TimberLintel",
		window_center + Vector3.UP * 1.18 + outward * 0.050,
		lintel_size,
		mat_dark_wood
	)


func _add_apartment_balcony_module(
	root: Node3D,
	prefix: String,
	wall_anchor: Vector3,
	tangent: Vector3,
	outward: Vector3,
	width_value: float,
	slab_y: float,
	include_railing: bool
) -> void:
	const BALCONY_DEPTH_M: float = 1.20
	const SLAB_THICKNESS_M: float = 0.22
	var tangent_is_x: bool = absf(tangent.x) > 0.5
	var outward_is_x: bool = absf(outward.x) > 0.5
	var slab_center: Vector3 = (
		Vector3(wall_anchor.x, slab_y, wall_anchor.z)
		+ outward * (BALCONY_DEPTH_M * 0.5)
	)
	var slab_size: Vector3 = (
		Vector3(width_value, SLAB_THICKNESS_M, BALCONY_DEPTH_M)
		if tangent_is_x
		else Vector3(BALCONY_DEPTH_M, SLAB_THICKNESS_M, width_value)
	)
	_add_local_box(
		root, prefix + "ConcreteSlab", slab_center, slab_size, mat_apartment_concrete
	)

	# A 220 mm dark painted-steel fascia wraps the exposed slab edges.
	var front_fascia_size: Vector3 = (
		Vector3(width_value, SLAB_THICKNESS_M, 0.085)
		if tangent_is_x
		else Vector3(0.085, SLAB_THICKNESS_M, width_value)
	)
	_add_local_box(
		root,
		prefix + "FrontFascia",
		Vector3(wall_anchor.x, slab_y, wall_anchor.z)
			+ outward * (BALCONY_DEPTH_M - 0.042),
		front_fascia_size,
		mat_weathered_metal
	)
	var side_fascia_size: Vector3 = (
		Vector3(0.085, SLAB_THICKNESS_M, BALCONY_DEPTH_M)
		if tangent_is_x
		else Vector3(BALCONY_DEPTH_M, SLAB_THICKNESS_M, 0.085)
	)
	for side: float in [-1.0, 1.0]:
		_add_local_box(
			root,
			prefix + "SideFascia",
			slab_center + tangent * ((width_value * 0.5 - 0.042) * side),
			side_fascia_size,
			mat_weathered_metal
		)

	# Thin coping completes the dark frame visible around the balcony slab.
	var tangent_coping_size: Vector3 = (
		Vector3(width_value + 0.04, 0.060, 0.075)
		if tangent_is_x
		else Vector3(0.075, 0.060, width_value + 0.04)
	)
	_add_facade_detail_box(
		root,
		prefix + "FrontCoping",
		Vector3(wall_anchor.x, slab_y + 0.135, wall_anchor.z)
			+ outward * (BALCONY_DEPTH_M - 0.035),
		tangent_coping_size,
		mat_black_metal
	)
	var outward_coping_size: Vector3 = (
		Vector3(BALCONY_DEPTH_M, 0.060, 0.075)
		if outward_is_x
		else Vector3(0.075, 0.060, BALCONY_DEPTH_M)
	)
	for side: float in [-1.0, 1.0]:
		_add_facade_detail_box(
			root,
			prefix + "SideCoping",
			slab_center + tangent * ((width_value * 0.5 - 0.035) * side)
				+ Vector3.UP * 0.135,
			outward_coping_size,
			mat_black_metal
		)

	# Six real timber boards form the soffit; narrow gaps preserve the plank read.
	var soffit_board_count: int = 6
	var usable_depth: float = BALCONY_DEPTH_M - 0.10
	var board_depth: float = usable_depth / float(soffit_board_count)
	var board_size: Vector3 = (
		Vector3(width_value - 0.12, 0.035, board_depth - 0.012)
		if tangent_is_x
		else Vector3(board_depth - 0.012, 0.035, width_value - 0.12)
	)
	for board_index: int in range(soffit_board_count):
		var board_distance: float = 0.05 + board_depth * (float(board_index) + 0.5)
		_add_facade_detail_box(
			root,
			prefix + "SoffitBoard",
			Vector3(wall_anchor.x, slab_y - 0.132, wall_anchor.z)
				+ outward * board_distance,
			board_size,
			mat_wood
		)


	if include_railing:
		_add_apartment_balcony_railing(
			root, prefix, wall_anchor, tangent, outward, width_value, slab_y
		)


func _add_apartment_balcony_railing(
	root: Node3D,
	prefix: String,
	wall_anchor: Vector3,
	tangent: Vector3,
	outward: Vector3,
	width_value: float,
	slab_y: float
) -> void:
	const BALCONY_DEPTH_M: float = 1.20
	var tangent_is_x: bool = absf(tangent.x) > 0.5
	var outward_is_x: bool = absf(outward.x) > 0.5
	var deck_top_y: float = slab_y + 0.11
	var rail_top_y: float = deck_top_y + 0.98
	var rail_low_y: float = deck_top_y + 0.16
	var front_line: Vector3 = (
		Vector3(wall_anchor.x, 0.0, wall_anchor.z)
		+ outward * (BALCONY_DEPTH_M - 0.060)
	)
	var tangent_rail_size: Vector3 = (
		Vector3(width_value + 0.06, 0.065, 0.065)
		if tangent_is_x
		else Vector3(0.065, 0.065, width_value + 0.06)
	)
	var outward_rail_size: Vector3 = (
		Vector3(BALCONY_DEPTH_M, 0.065, 0.065)
		if outward_is_x
		else Vector3(0.065, 0.065, BALCONY_DEPTH_M)
	)
	_add_facade_detail_box(
		root, prefix + "RailTopFront",
		Vector3(front_line.x, rail_top_y, front_line.z),
		tangent_rail_size, mat_black_metal
	)
	_add_facade_detail_box(
		root, prefix + "RailLowFront",
		Vector3(front_line.x, rail_low_y, front_line.z),
		tangent_rail_size, mat_black_metal
	)
	for side: float in [-1.0, 1.0]:
		var side_center: Vector3 = (
			Vector3(wall_anchor.x, 0.0, wall_anchor.z)
			+ outward * (BALCONY_DEPTH_M * 0.5)
			+ tangent * ((width_value * 0.5 - 0.040) * side)
		)
		_add_facade_detail_box(
			root, prefix + "RailTopSide",
			Vector3(side_center.x, rail_top_y, side_center.z),
			outward_rail_size, mat_black_metal
		)
		_add_facade_detail_box(
			root, prefix + "RailLowSide",
			Vector3(side_center.x, rail_low_y, side_center.z),
			outward_rail_size, mat_black_metal
		)

	# Four 80 mm structural posts match the supplied railing connection detail.
	var post_height: float = rail_top_y - deck_top_y
	var post_center_y: float = deck_top_y + post_height * 0.5
	for side: float in [-1.0, 1.0]:
		for distance_value: float in [0.075, BALCONY_DEPTH_M - 0.060]:
			var post_position: Vector3 = (
				Vector3(wall_anchor.x, post_center_y, wall_anchor.z)
				+ tangent * ((width_value * 0.5 - 0.040) * side)
				+ outward * distance_value
			)
			_add_facade_detail_box(
				root, prefix + "RailingPost", post_position,
				Vector3(0.080, post_height, 0.080), mat_black_metal
			)

	# Dense 35 mm balusters are batched into one MultiMesh per module.
	var baluster_positions: PackedVector3Array = PackedVector3Array()
	var baluster_bottom_y: float = deck_top_y + 0.10
	var baluster_top_y: float = rail_top_y - 0.050
	var baluster_height: float = baluster_top_y - baluster_bottom_y
	var baluster_y: float = (baluster_bottom_y + baluster_top_y) * 0.5
	var front_intervals: int = clampi(roundi(width_value / 0.18), 10, 18)
	for bar_index: int in range(1, front_intervals):
		var front_t: float = float(bar_index) / float(front_intervals) - 0.5
		baluster_positions.append(
			Vector3(front_line.x, baluster_y, front_line.z)
				+ tangent * (front_t * width_value)
		)
	var side_intervals: int = clampi(roundi(BALCONY_DEPTH_M / 0.18), 6, 8)
	for side: float in [-1.0, 1.0]:
		for bar_index: int in range(1, side_intervals):
			var side_distance: float = (
				BALCONY_DEPTH_M * float(bar_index) / float(side_intervals)
			)
			baluster_positions.append(
				Vector3(wall_anchor.x, baluster_y, wall_anchor.z)
					+ tangent * ((width_value * 0.5 - 0.040) * side)
					+ outward * side_distance
			)
	_add_apartment_baluster_multimesh(
		root, prefix + "Balusters", baluster_positions, baluster_height
	)


func _add_apartment_baluster_multimesh(
	root: Node3D,
	part_name: String,
	positions: PackedVector3Array,
	bar_height: float
) -> void:
	if positions.is_empty():
		return
	var bar_mesh: BoxMesh = BoxMesh.new()
	bar_mesh.size = Vector3(0.035, bar_height, 0.035)
	var bars: MultiMesh = MultiMesh.new()
	bars.transform_format = MultiMesh.TRANSFORM_3D
	bars.mesh = bar_mesh
	bars.instance_count = positions.size()
	for index: int in range(positions.size()):
		bars.set_instance_transform(index, Transform3D(Basis.IDENTITY, positions[index]))
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = part_name
	instance.multimesh = bars
	instance.material_override = mat_black_metal
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = FACADE_DETAIL_VISIBILITY_RANGE
	instance.visibility_range_end_margin = 6.0
	root.add_child(instance)


func _add_apartment_reference_roof(
	root: Node3D,
	width_m: float,
	depth_m: float,
	top_y: float
) -> void:
	var parapet_h: float = 0.62
	var parapet_t: float = 0.20
	var parapet_y: float = top_y + parapet_h * 0.5
	_add_local_box(
		root, "ApartmentRoofParapetFront",
		Vector3(0.0, parapet_y, -depth_m * 0.5 + parapet_t * 0.5),
		Vector3(width_m, parapet_h, parapet_t), mat_apartment_concrete
	)
	_add_local_box(
		root, "ApartmentRoofParapetRear",
		Vector3(0.0, parapet_y, depth_m * 0.5 - parapet_t * 0.5),
		Vector3(width_m, parapet_h, parapet_t), mat_apartment_concrete
	)
	for side: float in [-1.0, 1.0]:
		_add_local_box(
			root, "ApartmentRoofParapetSide",
			Vector3((width_m * 0.5 - parapet_t * 0.5) * side, parapet_y, 0.0),
			Vector3(parapet_t, parapet_h, depth_m), mat_apartment_concrete
		)

	# Thin dark coping is fixed building fabric. Roof rails and equipment remain
	# intentionally absent during this architecture-only pass.
	var cap_y: float = top_y + parapet_h + 0.035
	_add_local_box(
		root, "ApartmentRoofCopingFront",
		Vector3(0.0, cap_y, -depth_m * 0.5),
		Vector3(width_m + 0.04, 0.07, 0.24), mat_black_metal
	)
	_add_local_box(
		root, "ApartmentRoofCopingRear",
		Vector3(0.0, cap_y, depth_m * 0.5),
		Vector3(width_m + 0.04, 0.07, 0.24), mat_black_metal
	)
	for side: float in [-1.0, 1.0]:
		_add_local_box(
			root, "ApartmentRoofCopingSide",
			Vector3(width_m * 0.5 * side, cap_y, 0.0),
			Vector3(0.24, 0.07, depth_m), mat_black_metal
		)

	# The two unequal concrete service cores are the distinctive roof silhouette
	# in the supplied front, side and three-quarter references.
	var core_w: float = clampf(width_m * 0.18, 0.72, 1.28)
	var core_d: float = clampf(depth_m * 0.24, 1.00, 1.65)
	var core_x: float = width_m * 0.28
	_add_local_box(
		root, "ApartmentRoofCoreLeft",
		Vector3(-core_x, top_y + 1.22, depth_m * 0.12),
		Vector3(core_w, 2.44, core_d), mat_apartment_concrete
	)
	_add_local_box(
		root, "ApartmentRoofCoreRight",
		Vector3(core_x, top_y + 1.45, depth_m * 0.16),
		Vector3(core_w * 0.88, 2.90, core_d * 0.90), mat_apartment_concrete
	)


func _build_tower(
	building_name: String,
	position_value: Vector3,
	width_m: float,
	depth_m: float,
	front_yaw: float
) -> void:
	var root: Node3D = _new_building_root(building_name, position_value, front_yaw)
	var tower_width: float = maxf(8.0, width_m * 0.80)
	var tower_depth: float = maxf(8.0, depth_m * 0.80)
	var podium_width: float = tower_width + 2.2
	var podium_depth: float = tower_depth + 1.8
	var podium_h: float = 4.8
	var floors: int = town_rng.randi_range(9, 13)
	var floor_height: float = 2.82
	var height: float = float(floors) * floor_height

	# The commercial skyscraper has an accessible lobby/podium instead of an
	# impenetrable monolith. The office tower above remains closed for now.
	_add_enterable_ground_shell(root, podium_width, podium_depth, podium_h, mat_concrete, 1.72)
	_add_interior_details(root, podium_width, podium_depth, BUILDING_TOWER, podium_h)
	_add_open_door(root, podium_depth, 1.52, mat_black_metal)
	_add_front_window(root, "TowerLobbyGlassL", -podium_width * 0.27, 1.65, -podium_depth * 0.525,
		podium_width * 0.25, 2.10, mat_glass, mat_black_metal)
	_add_front_window(root, "TowerLobbyGlassR", podium_width * 0.27, 1.65, -podium_depth * 0.525,
		podium_width * 0.25, 2.10, mat_glass, mat_black_metal)
	_add_local_box(root, "TowerCanopy", Vector3(0.0, 3.10, -podium_depth * 0.5 - 0.82),
		Vector3(4.2, 0.15, 1.55), mat_black_metal)

	_add_local_box(root, "TowerCore", Vector3(0.0, podium_h + height * 0.5, 0.0),
		Vector3(tower_width, height, tower_depth), mat_dark_concrete)
	_add_building_collision(root, Vector3(tower_width, height, tower_depth),
		Vector3(0.0, podium_h + height * 0.5, 0.0))

	for floor_index: int in range(floors):
		var y_value: float = podium_h + 1.35 + float(floor_index) * floor_height
		for column: int in range(4):
			var x_value: float = (float(column) - 1.5) * tower_width * 0.21
			var glass_mat: Material = mat_window_blue if (floor_index + column) % 9 == 0 else mat_glass
			_add_front_window(root, "TowerWindow", x_value, y_value, -tower_depth * 0.507,
				tower_width * 0.16, 1.20, glass_mat, mat_black_metal)
		if floor_index % 3 == 0:
			_add_local_box(root, "FloorBand", Vector3(0.0, podium_h + float(floor_index) * floor_height,
				-tower_depth * 0.512), Vector3(tower_width, 0.10, 0.10), mat_black_metal)

	for mullion: float in [-0.43, -0.14, 0.14, 0.43]:
		_add_local_box(root, "TowerMullion", Vector3(tower_width * mullion, podium_h + height * 0.52,
			-tower_depth * 0.516), Vector3(0.10, height * 0.94, 0.10), mat_black_metal)

	_add_local_box(root, "TowerRoofPlant", Vector3(0.0, podium_h + height + 0.75, 0.0),
		Vector3(tower_width * 0.45, 1.20, tower_depth * 0.38), mat_black_metal)
	_add_local_box(root, "TowerCrown", Vector3(0.0, podium_h + height + 1.42, 0.0),
		Vector3(tower_width + 0.45, 0.12, tower_depth + 0.45), mat_neon_blue)

func _build_green_block(
	block: Rect2i,
	block_index: int,
	district: int,
	featured: bool = false
) -> void:
	var center_cell: Vector2 = Vector2(
		float(block.position.x) + float(block.size.x - 1) * 0.5,
		float(block.position.y) + float(block.size.y - 1) * 0.5
	)
	var center_world: Vector3 = _grid_float_to_world(center_cell, 0.10)
	var width_m: float = float(block.size.x) * TILE_SIZE - 1.1
	var depth_m: float = float(block.size.y) * TILE_SIZE - 1.1

	_add_collidable_world_box(
		vegetation_root,
		"GreenBlock%d" % block_index,
		center_world,
		Vector3(width_m, 0.18, depth_m),
		mat_green
	)

	if featured:
		_build_featured_shrine_park(center_world, width_m, depth_m, block_index)
		return

	# Ordinary pocket parks stay compact and irregular so they do not read as
	# empty lawns. One short path, a cluster of trees, a bench/shelter and a
	# hard edge keep them visually connected to the surrounding town.
	_add_visual_box(vegetation_root, "PocketParkPath%d" % block_index,
		center_world + Vector3(-width_m * 0.10, 0.14, 0.0),
		Vector3(1.70, 0.07, depth_m * 0.78), mat_stone_dark)
	_add_visual_box(vegetation_root, "PocketParkEdge%d" % block_index,
		center_world + Vector3(0.0, 0.34, -depth_m * 0.46),
		Vector3(width_m * 0.92, 0.48, 0.34), mat_stone_dark)

	var desired_trees: int = clampi(int(float(block.size.x * block.size.y) * 0.10), 4, 9)
	for tree_index: int in range(desired_trees):
		var side_bias: float = -1.0 if tree_index % 2 == 0 else 1.0
		var x_value: float = center_world.x + side_bias * town_rng.randf_range(width_m * 0.18, width_m * 0.40)
		var z_value: float = center_world.z + town_rng.randf_range(-depth_m * 0.38, depth_m * 0.38)
		_add_tree(Vector3(x_value, 0.10, z_value), town_rng.randf_range(0.72, 1.12))

	if town_rng.randf() < 0.50:
		_build_park_shelter(center_world + Vector3(width_m * 0.25, 0.10, -depth_m * 0.18), 0.0,
			"PocketShelter%d" % block_index)
	elif district == DISTRICT_LUXURY:
		_add_visual_box(vegetation_root, "PocketWater%d" % block_index,
			center_world + Vector3(width_m * 0.24, 0.16, 0.0),
			Vector3(width_m * 0.22, 0.05, depth_m * 0.16), mat_water)

func _build_featured_shrine_park(
	center_world: Vector3,
	width_m: float,
	depth_m: float,
	block_index: int
) -> void:
	# The park reference is a layered shrine garden: a strong torii entrance,
	# compressed stone approach, terraced shrine, water, cherry canopy and
	# dense reclaimed edges. It is intentionally authored rather than random.
	var base_top: float = center_world.y + 0.11
	var entrance_z: float = center_world.z + depth_m * 0.43
	var shrine_z: float = center_world.z - depth_m * 0.30
	var entry_gap: float = minf(5.2, width_m * 0.20)
	var wall_h: float = 0.66
	var wall_t: float = 0.42
	var side_wall_length: float = maxf(2.0, (width_m - entry_gap) * 0.5)

	# Low, weathered retaining walls define the garden without closing it off.
	_add_collidable_world_box(vegetation_root, "ParkNorthWall%d" % block_index,
		Vector3(center_world.x, base_top + wall_h * 0.5, center_world.z - depth_m * 0.46),
		Vector3(width_m * 0.94, wall_h, wall_t), mat_stone_dark)
	_add_collidable_world_box(vegetation_root, "ParkWestWall%d" % block_index,
		Vector3(center_world.x - width_m * 0.46, base_top + wall_h * 0.5, center_world.z),
		Vector3(wall_t, wall_h, depth_m * 0.92), mat_stone_dark)
	_add_collidable_world_box(vegetation_root, "ParkEastWall%d" % block_index,
		Vector3(center_world.x + width_m * 0.46, base_top + wall_h * 0.5, center_world.z),
		Vector3(wall_t, wall_h, depth_m * 0.92), mat_stone_dark)
	for side_index: int in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		var wall_x: float = center_world.x + side * (entry_gap * 0.5 + side_wall_length * 0.5)
		_add_collidable_world_box(vegetation_root, "ParkEntryWall%d_%d" % [block_index, side_index],
			Vector3(wall_x, base_top + wall_h * 0.5, center_world.z + depth_m * 0.46),
			Vector3(side_wall_length, wall_h, wall_t), mat_stone_dark)

	# Wet stone approach from the street to the first terrace.
	_add_visual_box(vegetation_root, "ParkApproach%d" % block_index,
		Vector3(center_world.x, base_top + 0.045, center_world.z + depth_m * 0.16),
		Vector3(2.45, 0.07, depth_m * 0.55), mat_stone)
	_add_visual_box(vegetation_root, "ParkCrossPath%d" % block_index,
		Vector3(center_world.x, base_top + 0.05, center_world.z + depth_m * 0.02),
		Vector3(width_m * 0.55, 0.07, 1.45), mat_stone_dark)

	# Main street-facing torii is deliberately oversized enough to act as a
	# navigation landmark while still belonging to the low-rise district.
	_build_torii_gate(Vector3(center_world.x, base_top, entrance_z), 0.0,
		"ParkTorii%d" % block_index, 1.28)

	# A tall corner banner and a few warm lanterns create a readable breadcrumb
	# from the main avenue to the south-facing torii. This is environmental
	# wayfinding rather than a HUD marker, matching the authored-landmark goal.
	var beacon_x: float = center_world.x + width_m * 0.42
	var beacon_z: float = center_world.z + depth_m * 0.43
	_add_visual_box(decoration_root, "ParkBeaconPole%d" % block_index,
		Vector3(beacon_x, base_top + 2.55, beacon_z),
		Vector3(0.14, 5.10, 0.14), mat_black_metal)
	_add_visual_box(decoration_root, "ParkBeaconBanner%d" % block_index,
		Vector3(beacon_x - 0.48, base_top + 3.20, beacon_z),
		Vector3(0.82, 2.35, 0.10), mat_rust)
	_add_visual_box(decoration_root, "ParkBeaconNeon%d" % block_index,
		Vector3(beacon_x - 0.49, base_top + 3.20, beacon_z - 0.065),
		Vector3(0.13, 1.82, 0.035), mat_neon_pink)

	for breadcrumb_index: int in range(3):
		var breadcrumb_x: float = center_world.x + width_m * (0.29 - float(breadcrumb_index) * 0.13)
		_add_stone_lantern(
			Vector3(breadcrumb_x, base_top, entrance_z + 0.18),
			"ParkBreadcrumb%d_%d" % [block_index, breadcrumb_index],
			true
		)

	# One slightly larger cherry canopy at the avenue-facing corner lets the
	# park announce itself above the low-rise street wall before the player
	# reaches the gate.
	_add_cherry_tree(
		Vector3(center_world.x + width_m * 0.34, base_top, center_world.z + depth_m * 0.31),
		1.22
	)

	# A lower terrace and compact stair climb create vertical composition even
	# on the flat procedural town ground.
	var terrace_depth: float = minf(8.8, depth_m * 0.25)
	var terrace_width: float = minf(13.0, width_m * 0.52)
	var terrace_center_z: float = center_world.z - depth_m * 0.19
	var terrace_h: float = 0.54
	_add_collidable_world_box(vegetation_root, "ShrineTerrace%d" % block_index,
		Vector3(center_world.x, base_top + terrace_h * 0.5, terrace_center_z),
		Vector3(terrace_width, terrace_h, terrace_depth), mat_stone_dark)

	var step_count: int = 5
	for step_index: int in range(step_count):
		var t: float = float(step_index + 1) / float(step_count)
		var step_h: float = terrace_h * t
		var step_z: float = center_world.z - depth_m * 0.075 - float(step_index) * 0.62
		_add_collidable_world_box(vegetation_root, "ShrineStep%d_%d" % [block_index, step_index],
			Vector3(center_world.x, base_top + step_h * 0.5, step_z),
			Vector3(2.70, step_h, 0.70), mat_stone)

	_build_torii_gate(Vector3(center_world.x, base_top + terrace_h, center_world.z - depth_m * 0.10),
		0.0, "InnerTorii%d" % block_index, 0.72)
	_build_shrine_pavilion(Vector3(center_world.x, base_top + terrace_h, shrine_z),
		"ParkShrine%d" % block_index)

	# Side pond and stepping stones reference the concept art without taking
	# over the playable approach path.
	var pond_x: float = center_world.x + width_m * 0.25
	var pond_z: float = center_world.z + depth_m * 0.04
	var pond_width: float = minf(8.8, width_m * 0.28)
	var pond_depth: float = minf(7.2, depth_m * 0.23)
	_add_visual_box(vegetation_root, "ParkPondBed%d" % block_index,
		Vector3(pond_x, base_top + 0.01, pond_z),
		Vector3(pond_width + 0.60, 0.10, pond_depth + 0.60), mat_stone_dark)
	_add_visual_box(vegetation_root, "ParkPondWater%d" % block_index,
		Vector3(pond_x, base_top + 0.08, pond_z),
		Vector3(pond_width, 0.05, pond_depth), mat_water)
	for stone_index: int in range(5):
		var stone_t: float = float(stone_index) / 4.0 - 0.5
		_add_visual_box(vegetation_root, "PondStepStone%d_%d" % [block_index, stone_index],
			Vector3(pond_x + stone_t * pond_width * 0.72, base_top + 0.15,
				pond_z + sin(float(stone_index) * 1.7) * 0.28),
			Vector3(0.95, 0.14, 0.72), mat_stone)

	# Warm stone lanterns punctuate the otherwise blue-grey park.
	var lantern_zs: Array[float] = [depth_m * 0.24, depth_m * 0.08, -depth_m * 0.08]
	var lantern_serial: int = 0
	for z_offset: float in lantern_zs:
		for side: float in [-1.0, 1.0]:
			_add_stone_lantern(
				Vector3(center_world.x + side * 2.65, base_top, center_world.z + z_offset),
				"ParkLantern%d_%d" % [block_index, lantern_serial],
				lantern_serial < 4
			)
			lantern_serial += 1

	# Cherry blossom groups are kept muted rather than candy-pink. Dark trees,
	# shrubs and broken growth around them make the area feel reclaimed.
	var cherry_positions: Array[Vector3] = [
		Vector3(-width_m * 0.31, 0.0, depth_m * 0.25),
		Vector3(width_m * 0.34, 0.0, depth_m * 0.28),
		Vector3(-width_m * 0.34, 0.0, -depth_m * 0.10),
		Vector3(width_m * 0.34, 0.0, -depth_m * 0.24),
		Vector3(-width_m * 0.22, 0.0, -depth_m * 0.36),
	]
	for cherry_index: int in range(cherry_positions.size()):
		var local_pos: Vector3 = cherry_positions[cherry_index]
		_add_cherry_tree(
			Vector3(center_world.x + local_pos.x, base_top, center_world.z + local_pos.z),
			0.88 + 0.11 * float(cherry_index % 3)
		)

	var dark_tree_positions: Array[Vector3] = [
		Vector3(-width_m * 0.40, 0.0, depth_m * 0.02),
		Vector3(width_m * 0.41, 0.0, -depth_m * 0.02),
		Vector3(-width_m * 0.38, 0.0, -depth_m * 0.31),
		Vector3(width_m * 0.23, 0.0, -depth_m * 0.40),
	]
	for local_pos: Vector3 in dark_tree_positions:
		_add_tree(Vector3(center_world.x + local_pos.x, base_top, center_world.z + local_pos.z),
			town_rng.randf_range(0.80, 1.10))

	for shrub_index: int in range(18):
		var edge_side: int = shrub_index % 4
		var shrub_x: float = center_world.x
		var shrub_z: float = center_world.z
		if edge_side == 0:
			shrub_x += town_rng.randf_range(-width_m * 0.40, width_m * 0.40)
			shrub_z -= depth_m * 0.39
		elif edge_side == 1:
			shrub_x += town_rng.randf_range(-width_m * 0.40, width_m * 0.40)
			shrub_z += depth_m * 0.38
		elif edge_side == 2:
			shrub_x -= width_m * 0.39
			shrub_z += town_rng.randf_range(-depth_m * 0.34, depth_m * 0.34)
		else:
			shrub_x += width_m * 0.39
			shrub_z += town_rng.randf_range(-depth_m * 0.34, depth_m * 0.34)
		_add_shrub(Vector3(shrub_x, base_top, shrub_z), town_rng.randf_range(0.48, 0.88))

	_build_park_shelter(
		Vector3(center_world.x - width_m * 0.25, base_top, center_world.z + depth_m * 0.03),
		PI * 0.5,
		"ParkShelter%d" % block_index
	)

func _build_park_shelter(position_value: Vector3, yaw: float, shelter_name: String) -> void:
	var root: Node3D = Node3D.new()
	root.name = shelter_name
	root.position = position_value
	root.rotation.y = yaw
	decoration_root.add_child(root)
	for x_value: float in [-1.35, 1.35]:
		for z_value: float in [-0.82, 0.82]:
			_add_local_box(root, "ShelterPost", Vector3(x_value, 1.35, z_value),
				Vector3(0.13, 2.70, 0.13), mat_dark_wood)
	_add_local_box(root, "ShelterRoof", Vector3(0.0, 2.86, 0.0),
		Vector3(3.35, 0.15, 2.25), mat_roof, Vector3(deg_to_rad(-3.0), 0.0, 0.0))
	_add_local_box(root, "ShelterBench", Vector3(0.0, 0.55, 0.20),
		Vector3(1.65, 0.16, 0.52), mat_wood)
	_add_local_box(root, "ShelterBenchLegL", Vector3(-0.82, 0.28, 0.20),
		Vector3(0.13, 0.55, 0.42), mat_dark_wood)
	_add_local_box(root, "ShelterBenchLegR", Vector3(0.82, 0.28, 0.20),
		Vector3(0.13, 0.55, 0.42), mat_dark_wood)

func _add_collidable_world_box(
	parent: Node3D,
	part_name: String,
	position_value: Vector3,
	size: Vector3,
	material: Material
) -> void:
	_add_visual_box(parent, part_name, position_value, size, material)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = part_name + "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	static_root.add_child(body)
	_add_collision_box(body, position_value, size)

func _add_exposed_service_pipe(
	root: Node3D,
	x_value: float,
	y_value: float,
	z_value: float,
	height_value: float
) -> void:
	_add_local_cylinder(root, "FacadeServicePipe", Vector3(x_value, y_value, z_value),
		0.045, height_value, mat_black_metal)
	_add_local_box(root, "FacadePipeBox", Vector3(x_value, maxf(0.55, y_value * 0.58), z_value - 0.035),
		Vector3(0.24, 0.30, 0.11), mat_soft_white)

func _add_projecting_sign(
	root: Node3D,
	width_m: float,
	depth_m: float,
	y_value: float,
	material: Material
) -> void:
	var side: float = -1.0 if town_rng.randf() < 0.5 else 1.0
	var sign_x: float = width_m * 0.42 * side
	_add_local_box(root, "ProjectingSignBracket", Vector3(sign_x, y_value + 0.42, -depth_m * 0.5 - 0.24),
		Vector3(0.08, 0.08, 0.48), mat_black_metal)
	_add_local_box(root, "ProjectingSignBacking", Vector3(sign_x, y_value, -depth_m * 0.5 - 0.39),
		Vector3(0.40, 1.08, 0.48), mat_black_metal)
	_add_local_box(root, "ProjectingSign", Vector3(sign_x, y_value, -depth_m * 0.5 - 0.43),
		Vector3(0.34, 1.00, 0.44), material)

func _build_torii_gate(
	position_value: Vector3,
	yaw: float,
	gate_name: String,
	scale_value: float = 1.0
) -> void:
	var root: Node3D = Node3D.new()
	root.name = gate_name
	root.position = position_value
	root.rotation.y = yaw
	root.scale = Vector3.ONE * scale_value
	geometry_root.add_child(root)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	for side: float in [-1.0, 1.0]:
		var x_value: float = 1.55 * side
		_add_local_box(root, "ToriiPost", Vector3(x_value, 2.25, 0.0), Vector3(0.34, 4.50, 0.34), mat_rust)
		_add_collision_box(body, Vector3(x_value, 2.25, 0.0), Vector3(0.34, 4.50, 0.34))
	_add_local_box(root, "ToriiLowerBeam", Vector3(0.0, 3.82, 0.0), Vector3(3.75, 0.30, 0.34), mat_rust)
	_add_local_box(root, "ToriiTopBeam", Vector3(0.0, 4.45, 0.0), Vector3(4.55, 0.34, 0.46), mat_rust)
	_add_local_box(root, "ToriiCap", Vector3(0.0, 4.70, 0.0), Vector3(4.85, 0.13, 0.55), mat_dark_wood,
		Vector3(0.0, 0.0, deg_to_rad(-1.8)))

func _build_shrine_pavilion(position_value: Vector3, shrine_name: String) -> void:
	var root: Node3D = Node3D.new()
	root.name = shrine_name
	root.position = position_value
	geometry_root.add_child(root)
	_add_local_box(root, "ShrineBase", Vector3(0.0, 0.20, 0.0), Vector3(5.2, 0.38, 4.1), mat_stone_dark)
	_add_local_box(root, "ShrineFloor", Vector3(0.0, 0.46, -0.12), Vector3(4.65, 0.14, 3.45), mat_wood)
	_add_local_box(root, "ShrineBack", Vector3(0.0, 1.72, 1.36), Vector3(4.15, 2.55, 0.20), mat_dirty_plaster)
	for x_value: float in [-1.72, 1.72]:
		for z_value: float in [-1.18, 1.18]:
			_add_local_box(root, "ShrinePost", Vector3(x_value, 1.72, z_value), Vector3(0.20, 2.92, 0.20), mat_dark_wood)
	_add_local_box(root, "ShrineLintel", Vector3(0.0, 2.84, -1.26), Vector3(4.25, 0.24, 0.20), mat_rust)
	_add_local_box(root, "ShrineRail", Vector3(0.0, 0.82, -1.42), Vector3(3.85, 0.12, 0.12), mat_dark_wood)
	for rail_x: float in [-1.72, -0.86, 0.0, 0.86, 1.72]:
		_add_local_box(root, "ShrineRailPost", Vector3(rail_x, 0.69, -1.42), Vector3(0.08, 0.58, 0.08), mat_dark_wood)
	_add_local_box(root, "ShrineWarmPanel", Vector3(0.0, 1.66, 1.23), Vector3(1.15, 1.30, 0.06), mat_window_warm)
	_add_local_box(root, "ShrineOfferBox", Vector3(0.0, 0.78, -1.30), Vector3(0.92, 0.72, 0.58), mat_dark_wood)
	_add_gable_roof(root, 4.85, 3.75, 3.18, mat_roof, mat_tile, 30.0, true)
	_add_local_box(root, "ShrineLowerEave", Vector3(0.0, 2.62, -1.58), Vector3(4.55, 0.12, 0.72), mat_roof,
		Vector3(deg_to_rad(-7.0), 0.0, 0.0))

func _add_stone_lantern(
	position_value: Vector3,
	lantern_name: String,
	with_light: bool = false
) -> void:
	var root: Node3D = Node3D.new()
	root.name = lantern_name
	root.position = position_value
	decoration_root.add_child(root)
	_add_local_box(root, "LanternBase", Vector3(0.0, 0.18, 0.0), Vector3(0.68, 0.28, 0.68), mat_stone)
	_add_local_cylinder(root, "LanternStem", Vector3(0.0, 0.72, 0.0), 0.14, 0.92, mat_stone)
	_add_local_box(root, "LanternHousing", Vector3(0.0, 1.30, 0.0), Vector3(0.62, 0.58, 0.62), mat_stone_dark)
	_add_local_box(root, "LanternGlow", Vector3(0.0, 1.30, -0.316), Vector3(0.34, 0.28, 0.035), mat_window_warm)
	_add_local_box(root, "LanternCap", Vector3(0.0, 1.64, 0.0), Vector3(0.82, 0.12, 0.82), mat_tile)
	if with_light:
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "LanternLight"
		light.position = Vector3(0.0, 1.30, -0.20)
		light.light_color = Color(1.0, 0.63, 0.38)
		light.light_energy = 0.58
		light.omni_range = 4.6
		light.shadow_enabled = false
		root.add_child(light)

func _add_planter_strip(root: Node3D, width_m: float, depth_m: float, height: float) -> void:
	_add_local_box(
		root, "RoofPlanter", Vector3(0.0, height + 0.19, 0.0),
		Vector3(width_m * 0.58, 0.30, depth_m * 0.18), mat_dark_concrete
	)
	_add_local_box(
		root, "RoofGreen", Vector3(0.0, height + 0.38, 0.0),
		Vector3(width_m * 0.52, 0.20, depth_m * 0.14), mat_green
	)

func _front_yaw_for_lot(cell_center: Vector2) -> float:
	var nearest_distance: float = 999999.0
	var facing: Vector3 = Vector3(0.0, 0.0, -1.0)
	for center: int in ROAD_CENTERS:
		var dx: float = absf(cell_center.x - float(center))
		if dx < nearest_distance:
			nearest_distance = dx
			facing = Vector3(1.0 if float(center) > cell_center.x else -1.0, 0.0, 0.0)
		var dy: float = absf(cell_center.y - float(center))
		if dy < nearest_distance:
			nearest_distance = dy
			facing = Vector3(0.0, 0.0, 1.0 if float(center) > cell_center.y else -1.0)
	return atan2(-facing.x, -facing.z)

func _add_enterable_ground_shell(
	root: Node3D,
	width_m: float,
	depth_m: float,
	wall_h: float,
	material: Material,
	door_width: float,
	front_frame_depth: float = -1.0,
	front_edge_post_width: float = 0.18,
	align_inside_footprint: bool = false
) -> void:
	var wall_t: float = 0.16
	var door_h: float = 2.18
	var side_span_w: float = maxf(0.45, (width_m - door_width) * 0.5)
	var effective_front_depth: float = (
		maxf(wall_t, front_frame_depth)
		if front_frame_depth > 0.0
		else wall_t
	)
	var effective_edge_post_w: float = maxf(0.18, front_edge_post_width)
	var visual_segment_w: float = side_span_w
	if align_inside_footprint:
		visual_segment_w = maxf(0.28, side_span_w - effective_edge_post_w)
	var left_x: float = -(door_width * 0.5 + visual_segment_w * 0.5)
	var right_x: float = -left_x
	var collision_left_x: float = -(door_width * 0.5 + side_span_w * 0.5)
	var collision_right_x: float = -collision_left_x
	var front_center_z: float = -depth_m * 0.5
	var back_center_z: float = depth_m * 0.5
	var side_wall_x: float = width_m * 0.5
	var side_wall_depth: float = depth_m
	var side_wall_center_z: float = 0.0
	if align_inside_footprint:
		front_center_z += effective_front_depth * 0.5
		back_center_z -= wall_t * 0.5
		side_wall_x -= wall_t * 0.5
		# The deep front corner posts own the façade junction. Start the thin
		# side walls behind them so no exterior faces overlap or flicker.
		side_wall_depth = maxf(0.40, depth_m - effective_front_depth)
		side_wall_center_z = (
			-depth_m * 0.5
			+ effective_front_depth
			+ side_wall_depth * 0.5
		)

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ShellCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)

	_add_local_box(
		root,
		"BackWall",
		Vector3(0.0, wall_h * 0.5, back_center_z),
		Vector3(width_m, wall_h, wall_t),
		material
	)
	_add_collision_box(
		body,
		Vector3(0.0, wall_h * 0.5, back_center_z),
		Vector3(width_m, wall_h, wall_t)
	)
	for side: float in [-1.0, 1.0]:
		_add_local_box(
			root,
			"SideWall",
			Vector3(side_wall_x * side, wall_h * 0.5, side_wall_center_z),
			Vector3(wall_t, wall_h, side_wall_depth),
			material
		)
		_add_collision_box(
			body,
			Vector3(side_wall_x * side, wall_h * 0.5, side_wall_center_z),
			Vector3(wall_t, wall_h, side_wall_depth)
		)

	# Front facade is not a solid box. It has real glazed bays around the door,
	# so the player can see furniture and warm lighting before walking inside.
	var sill_h: float = 0.46
	for segment_index: int in range(2):
		var x_value: float = left_x if segment_index == 0 else right_x
		var collision_x: float = (
			collision_left_x if segment_index == 0 else collision_right_x
		)
		_add_local_box(
			root,
			"FrontSill",
			Vector3(x_value, sill_h * 0.5, front_center_z),
			Vector3(visual_segment_w, sill_h, effective_front_depth),
			material
		)
		# Invisible collision keeps the glass bay physically solid without
		# putting an opaque wall behind the transparent window material.
		_add_collision_box(
			body,
			Vector3(collision_x, 1.15, front_center_z),
			Vector3(side_span_w, 2.30, effective_front_depth)
		)

	for side: float in [-1.0, 1.0]:
		var edge_post_x: float = (
			(width_m * 0.5 - effective_edge_post_w * 0.5) * side
			if align_inside_footprint
			else (width_m * 0.5 - 0.09) * side
		)
		_add_local_box(
			root,
			"FrontEdgePost",
			Vector3(edge_post_x, wall_h * 0.5, front_center_z),
			Vector3(
				effective_edge_post_w if align_inside_footprint else 0.18,
				wall_h,
				effective_front_depth
			),
			material
		)

	var lintel_h: float = maxf(0.18, wall_h - door_h)
	var header_w: float = (
		maxf(door_width + 0.24, width_m - effective_edge_post_w * 2.0)
		if align_inside_footprint
		else width_m
	)
	_add_local_box(
		root,
		"FrontHeader",
		Vector3(0.0, door_h + lintel_h * 0.5, front_center_z),
		Vector3(header_w, lintel_h, effective_front_depth),
		material
	)
	_add_collision_box(
		body,
		Vector3(0.0, door_h + lintel_h * 0.5, front_center_z),
		Vector3(width_m, lintel_h, effective_front_depth)
	)

	_add_local_box(
		root,
		"InteriorFloor",
		Vector3(0.0, 0.055, 0.0),
		Vector3(width_m - 0.22, 0.10, depth_m - 0.22),
		mat_interior_wood
	)
	_add_local_box(
		root,
		"GroundCeiling",
		Vector3(0.0, wall_h - 0.055, 0.0),
		Vector3(width_m - 0.18, 0.10, depth_m - 0.18),
		mat_soft_white
	)

func _add_shop_open_door_leaf(root: Node3D, depth_m: float, door_width: float, material: Material) -> void:
	# Shopfront already supplies its own jambs/lintel. Only add the leaf here so
	# there is no second depth-scaled door frame hovering in front of the facade.
	var facade_plane_z: float = -depth_m * 0.5
	_add_local_box(root, "ShopOpenDoorLeaf", Vector3(door_width * 0.38, 1.05, facade_plane_z + 0.14),
		Vector3(door_width * 0.76, 2.05, 0.060), material,
		Vector3(0.0, deg_to_rad(67.0), 0.0))

func _add_open_door(root: Node3D, depth_m: float, door_width: float, material: Material) -> void:
	# v10.23a: the frame projects beyond the wall while the leaf sits farther
	# inside the shell. The same three frame meshes now create a much clearer
	# doorway reveal without adding another collision or light.
	_add_local_box(root, "DoorFrameTop", Vector3(0.0, 2.16, -depth_m * 0.545),
		Vector3(door_width + 0.22, 0.11, 0.20), material)
	for side: float in [-1.0, 1.0]:
		_add_local_box(root, "DoorFrameSide", Vector3((door_width * 0.5 + 0.055) * side, 1.08, -depth_m * 0.545),
			Vector3(0.11, 2.16, 0.20), material)
	# Door leaf is visibly swung inward, so the entrance reads as genuinely open.
	_add_local_box(root, "OpenDoorLeaf", Vector3(door_width * 0.38, 1.05, -depth_m * 0.385),
		Vector3(door_width * 0.76, 2.05, 0.065), material,
		Vector3(0.0, deg_to_rad(67.0), 0.0))

func _add_storefront_bay(
	root: Node3D,
	prefix: String,
	x_value: float,
	y_value: float,
	facade_plane_z: float,
	width_value: float,
	height_value: float,
	glass_material: Material,
	frame_material: Material,
	recessed_glass: bool = true
) -> void:
	# Storefront-specific depth convention. Negative Z is the street side, so
	# increasing Z moves the glass into the building while decreasing Z makes
	# the frame project toward the pavement. This avoids the v10.24 floating
	# pane effect while retaining a readable physical reveal.
	var glass_z: float = facade_plane_z + 0.035 if recessed_glass else facade_plane_z - 0.012
	var frame_z: float = facade_plane_z - 0.035
	_add_local_box(root, prefix + "Glass", Vector3(x_value, y_value, glass_z),
		Vector3(width_value, height_value, 0.035), glass_material)

	var frame_t: float = 0.075
	_add_local_box(root, prefix + "Top", Vector3(x_value, y_value + height_value * 0.5, frame_z),
		Vector3(width_value + 0.08, frame_t, 0.075), frame_material)
	_add_local_box(root, prefix + "Bottom", Vector3(x_value, y_value - height_value * 0.5, frame_z),
		Vector3(width_value + 0.08, frame_t, 0.075), frame_material)
	for side: float in [-1.0, 1.0]:
		_add_local_box(root, prefix + "Side", Vector3(x_value + width_value * 0.5 * side, y_value, frame_z),
			Vector3(frame_t, height_value, 0.075), frame_material)

	# One slim mullion gives the larger bay a recognisable old-shop rhythm and
	# prevents it reading as a single dark television-like rectangle.
	_add_local_box(root, prefix + "Mullion", Vector3(x_value, y_value, frame_z - 0.004),
		Vector3(0.055, height_value, 0.080), frame_material)

func _set_imported_window_bay_part(module_root: Node3D, part_name: String, enabled: bool) -> void:
	var part: Node = module_root.find_child(part_name, true, false)
	if part is Node3D:
		(part as Node3D).visible = enabled

func _configure_imported_window_bay_geometry(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.visibility_range_end = IMPORTED_WINDOW_BAY_VISIBILITY_RANGE
		geometry.visibility_range_end_margin = 6.0
	for child: Node in node.get_children():
		_configure_imported_window_bay_geometry(child)

func _add_modular_window_bay(
	building_root: Node3D,
	depth_m: float,
	x_value: float,
	y_value: float,
	module_width_m: float,
	variant_seed: int
) -> bool:
	if imported_window_bay_count >= MAX_IMPORTED_WINDOW_BAYS:
		return false

	var imported_scene: Node3D = WindowBayScene.instantiate() as Node3D
	if imported_scene == null:
		return false

	building_root.add_child(imported_scene)
	imported_scene.name = "ImportedWindowBay"
	imported_scene.position = Vector3(x_value, y_value, -depth_m * 0.5 - 0.010)

	# Blender authored the street/front direction as -Y. glTF converts that
	# to +Z, while BLACKSITE facades face local -Z, so turn the module around.
	imported_scene.rotation.y = PI

	var module_prefix: String = "WindowBay_3m" if module_width_m >= 2.5 else "WindowBay_2m"
	var other_prefix: String = "WindowBay_2m" if module_prefix == "WindowBay_3m" else "WindowBay_3m"
	var module_root: Node3D = imported_scene.find_child(module_prefix + "_Root", true, false) as Node3D
	if module_root == null:
		imported_scene.queue_free()
		return false

	# Both width variants live in one GLB. Recenter the selected root because
	# the review/export file lays the two variants out side-by-side in Blender.
	module_root.position = Vector3.ZERO
	module_root.rotation = Vector3.ZERO
	module_root.scale = Vector3.ONE

	var other_root: Node3D = imported_scene.find_child(other_prefix + "_Root", true, false) as Node3D
	if other_root != null:
		other_root.visible = false
		other_root.queue_free()

	_set_imported_window_bay_part(module_root, module_prefix + "_Base", true)

	# v10.25e: leave more bays bare so the blind/screen silhouettes feel like
	# authored exceptions rather than a repeated procedural stamp.
	var treatment_roll: int = abs(variant_seed) % 8
	_set_imported_window_bay_part(module_root, module_prefix + "_Blind", treatment_roll == 4 or treatment_roll == 5)
	_set_imported_window_bay_part(module_root, module_prefix + "_Screen", treatment_roll == 6 or treatment_roll == 7)

	# Occupancy and service detail stay sparse. Material colour/emission in the
	# imported GLB is also muted in this pass after the first in-game review.
	_set_imported_window_bay_part(module_root, module_prefix + "_InteriorGlow", abs(variant_seed) % 5 == 0)
	_set_imported_window_bay_part(module_root, module_prefix + "_Utility", abs(variant_seed + 1) % 6 == 0)
	_set_imported_window_bay_part(module_root, module_prefix + "_Planter", abs(variant_seed + 2) % 7 == 0)
	_set_imported_window_bay_part(module_root, "COL_" + module_prefix, false)

	_configure_imported_window_bay_geometry(module_root)
	imported_window_bay_count += 1
	return true

func _set_imported_roof_eave_part(module_root: Node3D, part_name: String, enabled: bool) -> void:
	var part: Node = module_root.find_child(part_name, true, false)
	if part is Node3D:
		(part as Node3D).visible = enabled

func _configure_imported_roof_eave_geometry(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.visibility_range_end = IMPORTED_ROOF_EAVE_VISIBILITY_RANGE
		geometry.visibility_range_end_margin = 6.0

		# v10.25f: calibrate the imported kit in Godot rather than sending the
		# approved Blender geometry back for redesign. The original GLB uses a
		# comparatively pale plaster/mortar and warm orange rafters; under the
		# current night key these can read as a detached bright strip.
		var part_name: String = String(geometry.name)
		if part_name.contains("KawaraDark"):
			geometry.material_override = mat_imported_roof_tile_dark
		elif part_name.contains("Kawara"):
			geometry.material_override = mat_imported_roof_tile
		elif part_name.contains("Mortar"):
			geometry.material_override = mat_imported_roof_mortar
		elif part_name.contains("TimberDark"):
			geometry.material_override = mat_imported_roof_timber_dark
		elif part_name.contains("Timber"):
			geometry.material_override = mat_imported_roof_timber
		elif part_name.contains("Rafters"):
			geometry.material_override = mat_imported_roof_rafter
		elif part_name.contains("PlasterBacking"):
			geometry.material_override = mat_imported_roof_plaster
		elif part_name.contains("Gutter"):
			geometry.material_override = mat_imported_roof_gutter
	for child: Node in node.get_children():
		_configure_imported_roof_eave_geometry(child)

func _add_modular_roof_eave(
	building_root: Node3D,
	depth_m: float,
	wall_top_y: float,
	building_width_m: float
) -> bool:
	if imported_roof_eave_count >= MAX_IMPORTED_ROOF_EAVES:
		return false
	if building_width_m < 4.15:
		return false

	var imported_scene: Node3D = RoofEaveScene.instantiate() as Node3D
	if imported_scene == null:
		return false

	building_root.add_child(imported_scene)
	imported_scene.name = "ImportedRoofEave"

	# The v17 GLB was emitted from a Z-up modelling coordinate system rather
	# than Blender's normal glTF axis conversion. Map its local X/Y/Z to the
	# town's -X/+Z/+Y axes so Z remains up and negative source Y faces the road.
	imported_scene.basis = Basis(
		Vector3(-1.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 1.0),
		Vector3(0.0, 1.0, 0.0)
	)

	# v10.25f/v10.25g attachment correction retained. The v17 root origin is below the roof
	# slope, so placing that origin directly on wall_top_y leaves the underside
	# around the actual facade plane visibly above the procedural wall. Seat the
	# roof into the wall by the measured contact drop, and move it slightly
	# inward so the front gutter projects about 0.62 m instead of ~0.74 m.
	imported_scene.position = Vector3(
		0.0,
		wall_top_y - IMPORTED_ROOF_EAVE_WALL_CONTACT_DROP,
		-depth_m * 0.5 + IMPORTED_ROOF_EAVE_ORIGIN_INSET
	)

	var module_prefix: String = "RoofEave_6m" if building_width_m >= 6.20 else "RoofEave_4m"
	var other_prefix: String = "RoofEave_4m" if module_prefix == "RoofEave_6m" else "RoofEave_6m"
	var module_root: Node3D = imported_scene.find_child(module_prefix + "_Root", true, false) as Node3D
	if module_root == null:
		imported_scene.queue_free()
		return false

	module_root.position = Vector3.ZERO
	module_root.rotation = Vector3.ZERO
	module_root.scale = Vector3.ONE

	var other_root: Node3D = imported_scene.find_child(other_prefix + "_Root", true, false) as Node3D
	if other_root != null:
		other_root.visible = false
		other_root.queue_free()

	_set_imported_roof_eave_part(module_root, "COL_" + module_prefix, false)
	_configure_imported_roof_eave_geometry(module_root)
	imported_roof_eave_count += 1
	return true

func _add_front_window(
	root: Node3D,
	prefix: String,
	x_value: float,
	y_value: float,
	z_value: float,
	width_value: float,
	height_value: float,
	glass_material: Material,
	frame_material: Material
) -> void:
	# v10.23a: recess the glass behind a more projecting frame. This changes
	# depth using the existing five meshes, so the entire town gains stronger
	# window reveals without an extra node per opening.
	var glass_z: float = z_value + 0.055
	var frame_z: float = z_value - 0.045
	if glass_material == mat_window_warm:
		var reveal: MeshInstance3D = _add_facade_detail_box(root, prefix + "WarmReveal",
			Vector3(x_value, y_value, z_value - 0.006),
			Vector3(width_value + 0.18, height_value + 0.14, 0.026), mat_window_reveal_warm)
		reveal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_local_box(root, prefix + "Glass", Vector3(x_value, y_value, glass_z),
		Vector3(width_value, height_value, 0.045), glass_material)
	var frame_t: float = 0.080
	_add_local_box(root, prefix + "Top", Vector3(x_value, y_value + height_value * 0.5, frame_z),
		Vector3(width_value + 0.12, frame_t, 0.11), frame_material)
	_add_local_box(root, prefix + "Bottom", Vector3(x_value, y_value - height_value * 0.5, frame_z),
		Vector3(width_value + 0.12, frame_t, 0.11), frame_material)
	for side: float in [-1.0, 1.0]:
		_add_local_box(root, prefix + "Side", Vector3(x_value + width_value * 0.5 * side, y_value, frame_z),
			Vector3(frame_t, height_value, 0.11), frame_material)

func _add_balcony_rail(root: Node3D, width_value: float, y_value: float, z_value: float) -> void:
	_add_local_box(root, "RailTop", Vector3(0.0, y_value + 0.34, z_value),
		Vector3(width_value, 0.07, 0.07), mat_black_metal)
	var posts: int = clampi(int(width_value / 1.2), 3, 8)
	for post_index: int in range(posts + 1):
		var t: float = float(post_index) / float(posts) - 0.5
		_add_local_box(root, "RailPost", Vector3(t * width_value, y_value, z_value),
			Vector3(0.055, 0.72, 0.055), mat_black_metal)

func _add_wall_ac_unit(root: Node3D, x_value: float, y_value: float, z_value: float) -> void:
	# v10.25a: these were being positioned 0.4-0.7 m in front of many facades,
	# and the two dark rectangular grilles could read as a floating window.
	# Keep the condenser tight to the wall and use a circular fan face so its
	# purpose is obvious at gameplay distance. The AC-unit mesh count stays flat.
	_add_local_box(root, "ACBody", Vector3(x_value, y_value, z_value),
		Vector3(0.78, 0.46, 0.20), mat_soft_white)
	_add_local_cylinder(root, "ACFan", Vector3(x_value - 0.10, y_value, z_value - 0.112),
		0.145, 0.028, mat_black_metal, Vector3(PI * 0.5, 0.0, 0.0))
	_add_local_box(root, "ACServicePanel", Vector3(x_value + 0.235, y_value, z_value - 0.112),
		Vector3(0.16, 0.28, 0.028), mat_weathered_metal)
	_add_local_cylinder(root, "DrainPipe", Vector3(x_value + 0.44, y_value * 0.5, z_value + 0.075),
		0.030, maxf(0.6, y_value), mat_soft_white)

func _add_window_blinds(
	root: Node3D,
	prefix: String,
	x_value: float,
	y_value: float,
	z_value: float,
	width_value: float,
	height_value: float
) -> void:
	var blind_drop: float = minf(0.42, height_value * 0.42)
	for slat_index: int in range(4):
		var t: float = float(slat_index) / 3.0
		var slat_y: float = y_value + height_value * 0.24 - blind_drop * t
		_add_facade_detail_box(root, prefix + "BlindSlat",
			Vector3(x_value, slat_y, z_value - 0.060),
			Vector3(width_value * 0.82, 0.030, 0.055), mat_wood)

func _add_window_planter_box(
	root: Node3D,
	prefix: String,
	x_value: float,
	y_value: float,
	z_value: float,
	width_value: float
) -> void:
	var box_width: float = clampf(width_value * 0.46, 0.34, 0.82)
	_add_facade_detail_box(root, prefix + "PlanterBox",
		Vector3(x_value, y_value - 0.48, z_value - 0.070),
		Vector3(box_width, 0.13, 0.20), mat_wood)
	_add_facade_detail_box(root, prefix + "PlanterGreen",
		Vector3(x_value, y_value - 0.40, z_value - 0.070),
		Vector3(box_width * 0.88, 0.10, 0.14), mat_green)

func _add_utility_box_cluster(
	root: Node3D,
	prefix: String,
	x_value: float,
	y_value: float,
	z_value: float
) -> void:
	_add_facade_detail_box(root, prefix + "UtilityBox",
		Vector3(x_value, y_value, z_value - 0.050),
		Vector3(0.34, 0.44, 0.10), mat_soft_white)
	_add_facade_detail_box(root, prefix + "Meter",
		Vector3(x_value + 0.18, y_value - 0.06, z_value - 0.090),
		Vector3(0.11, 0.17, 0.04), mat_black_metal)
	_add_facade_detail_box(root, prefix + "Conduit",
		Vector3(x_value - 0.11, y_value - 0.26, z_value - 0.052),
		Vector3(0.04, 0.56, 0.04), mat_weathered_metal)

func _add_gutter_downpipe(
	root: Node3D,
	prefix: String,
	x_value: float,
	top_y: float,
	z_value: float,
	drop_height: float
) -> void:
	_add_facade_detail_box(root, prefix + "Gutter",
		Vector3(x_value, top_y, z_value - 0.020),
		Vector3(0.14, 0.08, 0.20), mat_weathered_metal)
	_add_facade_detail_box(root, prefix + "Downpipe",
		Vector3(x_value, top_y - drop_height * 0.5, z_value - 0.045),
		Vector3(0.055, drop_height, 0.055), mat_weathered_metal)

func _add_interior_details(
	root: Node3D,
	width_m: float,
	depth_m: float,
	building_type: int,
	ceiling_h: float,
	shop_archetype: int = SHOP_RESIDENTIAL_MIX
) -> void:
	match building_type:
		BUILDING_SHOP:
			_add_shop_interior_lining(root, width_m, depth_m, shop_archetype)
			_add_shop_interior_archetype(root, width_m, depth_m, shop_archetype)
		BUILDING_MODERN:
			_add_local_box(root, "KitchenCounter", Vector3(width_m * 0.25, 0.48, depth_m * 0.30),
				Vector3(width_m * 0.34, 0.90, 0.72), mat_dark_concrete)
			_add_local_box(root, "SofaBase", Vector3(-width_m * 0.20, 0.32, 0.10),
				Vector3(1.75, 0.50, 0.78), mat_dark_concrete)
			_add_local_box(root, "SofaBack", Vector3(-width_m * 0.20, 0.67, 0.42),
				Vector3(1.75, 0.62, 0.16), mat_dark_concrete)
			_add_local_box(root, "CoffeeTable", Vector3(0.30, 0.24, -0.35),
				Vector3(1.00, 0.38, 0.70), mat_wood)
		BUILDING_TRADITIONAL:
			for x_side: float in [-1.0, 1.0]:
				for z_side: float in [-1.0, 1.0]:
					_add_local_box(root, "Tatami", Vector3(width_m * 0.18 * x_side, 0.10, depth_m * 0.18 * z_side),
						Vector3(width_m * 0.34, 0.08, depth_m * 0.34), mat_tatami)
			_add_local_box(root, "LowTable", Vector3(0.0, 0.28, 0.0),
				Vector3(1.25, 0.34, 0.80), mat_dark_wood)
			_add_local_box(root, "ShojiDivider", Vector3(width_m * 0.26, 1.10, depth_m * 0.16),
				Vector3(0.08, 2.0, depth_m * 0.46), mat_plaster)
		BUILDING_APARTMENT:
			_add_local_box(root, "LobbyDesk", Vector3(0.0, 0.55, depth_m * 0.27),
				Vector3(width_m * 0.36, 1.0, 0.72), mat_dark_wood)
			for side: float in [-1.0, 1.0]:
				_add_local_box(root, "LobbyBench", Vector3(width_m * 0.24 * side, 0.30, -depth_m * 0.05),
					Vector3(1.35, 0.46, 0.55), mat_dark_concrete)
			_add_local_box(root, "Mailboxes", Vector3(width_m * 0.37, 1.20, depth_m * 0.24),
				Vector3(0.42, 1.55, 1.30), mat_soft_white)
		BUILDING_TOWER:
			_add_local_box(root, "ReceptionDesk", Vector3(0.0, 0.62, depth_m * 0.24),
				Vector3(width_m * 0.42, 1.12, 0.86), mat_black_metal)
			for side: float in [-1.0, 1.0]:
				_add_local_box(root, "LobbySofa", Vector3(width_m * 0.23 * side, 0.34, -depth_m * 0.08),
					Vector3(1.80, 0.52, 0.75), mat_dark_concrete)
			_add_local_box(root, "SecurityGate", Vector3(0.0, 0.70, depth_m * 0.02),
				Vector3(1.65, 1.22, 0.18), mat_black_metal)

	# v10.20 keeps the exact eight-light budget while making active storefronts
	# first-class lighting identity. Most rooms use emissive fixtures only;
	# selected shops get a real, shadowless light positioned toward the front
	# so some illumination reaches the threshold and pavement.
	var fixture_mat: Material = mat_window_warm_dim
	var fixture_pos: Vector3 = Vector3(0.0, ceiling_h - 0.12, 0.0)
	var fixture_size: Vector3 = Vector3(minf(1.5, width_m * 0.28), 0.05, 0.50)

	if building_type == BUILDING_SHOP:
		match shop_archetype:
			SHOP_RAMEN:
				fixture_mat = mat_interior_task_warm
				fixture_pos = Vector3(0.0, ceiling_h - 0.12, depth_m * 0.08)
				fixture_size = Vector3(minf(1.85, width_m * 0.36), 0.05, 0.62)
			SHOP_IZAKAYA:
				fixture_mat = mat_interior_bar_warm
				fixture_pos = Vector3(-width_m * 0.08, ceiling_h - 0.16, depth_m * 0.14)
				fixture_size = Vector3(minf(1.25, width_m * 0.26), 0.045, 0.42)
			SHOP_CONVENIENCE:
				fixture_mat = mat_interior_cool
				fixture_pos = Vector3(0.0, ceiling_h - 0.12, -depth_m * 0.02)
				fixture_size = Vector3(minf(1.9, width_m * 0.40), 0.05, 0.62)
			SHOP_REPAIR:
				fixture_mat = mat_window_warm_dim
				fixture_pos = Vector3(0.0, ceiling_h - 0.14, depth_m * 0.18)
			SHOP_SHUTTERED:
				# A closed business should interrupt the active rhythm rather
				# than glowing like an occupied room behind the shutter.
				return
			_:
				fixture_mat = mat_window_warm_dim
				fixture_pos = Vector3(0.0, ceiling_h - 0.14, depth_m * 0.02)

	_add_local_box(root, "InteriorLightPanel", fixture_pos, fixture_size, fixture_mat)

	var allow_real_light: bool = false
	if building_type == BUILDING_SHOP and shop_archetype != SHOP_SHUTTERED:
		allow_real_light = shop_interior_light_count < MAX_SHOP_INTERIOR_LIGHTS
	else:
		allow_real_light = other_interior_light_count < MAX_OTHER_INTERIOR_LIGHTS

	if allow_real_light and interior_light_count < MAX_INTERIOR_LIGHTS:
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "InteriorLight"
		var light_color: Color = Color(1.0, 0.70, 0.46)
		var light_energy: float = 0.60
		var light_range: float = minf(6.0, maxf(width_m, depth_m) * 0.62)
		var light_z: float = 0.0

		if building_type == BUILDING_SHOP:
			light_z = -depth_m * 0.08
			match shop_archetype:
				SHOP_RAMEN:
					# Keep the same light inside the shop, but pull it slightly
					# back from the threshold so the road hotspot is less circular.
					light_z = -depth_m * 0.15
					light_color = Color(1.0, 0.66, 0.40)
					light_energy = 0.90
					light_range = minf(6.3, maxf(width_m, depth_m) * 0.70)
				SHOP_IZAKAYA:
					light_z = -depth_m * 0.08
					light_color = Color(1.0, 0.46, 0.25)
					light_energy = 0.58
					light_range = minf(5.4, maxf(width_m, depth_m) * 0.60)
				SHOP_CONVENIENCE:
					light_z = -depth_m * 0.16
					light_color = Color(0.84, 0.90, 0.92)
					light_energy = 0.72
					light_range = minf(5.9, maxf(width_m, depth_m) * 0.65)
				SHOP_REPAIR:
					light_z = depth_m * 0.02
					light_color = Color(0.92, 0.70, 0.50)
					light_energy = 0.50
					light_range = minf(5.0, maxf(width_m, depth_m) * 0.56)
				_:
					light_color = Color(1.0, 0.64, 0.40)
					light_energy = 0.56
					light_range = minf(5.3, maxf(width_m, depth_m) * 0.58)
		else:
			light_energy = 0.46
			light_range = minf(4.8, maxf(width_m, depth_m) * 0.54)

		var light_y: float = ceiling_h - 0.50 if building_type == BUILDING_SHOP else ceiling_h - 0.36
		light.position = Vector3(0.0, light_y, light_z)
		light.light_color = light_color
		light.light_energy = light_energy
		light.omni_range = light_range
		light.shadow_enabled = false
		root.add_child(light)
		light.add_to_group("shinrai_interior_light")
		interior_light_count += 1
		if building_type == BUILDING_SHOP:
			shop_interior_light_count += 1
		else:
			other_interior_light_count += 1

func _add_shop_interior_lining(root: Node3D, width_m: float, depth_m: float, shop_archetype: int) -> void:
	# One thin rear-wall liner per active shop gives the eye a stable warm/cool
	# surface behind counters and shelves. It is not a light and casts no shadow.
	if shop_archetype == SHOP_SHUTTERED:
		return
	var lining_mat: Material = mat_interior_wall_warm
	match shop_archetype:
		SHOP_IZAKAYA:
			lining_mat = mat_interior_wall_dark
		SHOP_CONVENIENCE:
			lining_mat = mat_interior_wall_cool
		SHOP_REPAIR:
			lining_mat = mat_interior_wall_cool
		_:
			lining_mat = mat_interior_wall_warm
	_add_facade_detail_box(root, "ShopRearWallLining",
		Vector3(0.0, 1.30, depth_m * 0.485),
		Vector3(width_m * 0.82, 2.28, 0.045), lining_mat)

func _add_shop_interior_archetype(root: Node3D, width_m: float, depth_m: float, shop_archetype: int) -> void:
	match shop_archetype:
		SHOP_RAMEN:
			_add_ramen_interior(root, width_m, depth_m)
		SHOP_IZAKAYA:
			_add_izakaya_interior(root, width_m, depth_m)
		SHOP_CONVENIENCE:
			_add_convenience_interior(root, width_m, depth_m)
		SHOP_REPAIR:
			_add_repair_interior(root, width_m, depth_m)
		SHOP_SHUTTERED:
			_add_local_box(root, "ClosedStoreShelf", Vector3(width_m * 0.28, 0.95, depth_m * 0.20),
				Vector3(0.42, 1.55, depth_m * 0.42), mat_dark_wood)
		_:
			_add_mixed_shop_interior(root, width_m, depth_m)

func _add_ramen_interior(root: Node3D, width_m: float, depth_m: float) -> void:
	# Bright, compact counter-service layout: customer stools at the front, a
	# readable timber counter, then a practical metal cook/prep line behind it.
	var counter_z: float = depth_m * 0.10
	_add_local_box(root, "RamenCounter", Vector3(0.0, 0.54, counter_z),
		Vector3(width_m * 0.64, 0.96, 0.58), mat_weathered_timber)
	_add_local_box(root, "RamenCounterTop", Vector3(0.0, 1.035, counter_z),
		Vector3(width_m * 0.67, 0.085, 0.66), mat_counter_warm)
	_add_local_box(root, "RamenCounterEdgeLight", Vector3(0.0, 0.91, counter_z - 0.315),
		Vector3(width_m * 0.54, 0.035, 0.035), mat_interior_task_warm)

	var stool_count: int = clampi(int(width_m / 1.45), 3, 5)
	for i: int in range(stool_count):
		var t: float = (float(i) + 0.5) / float(stool_count) - 0.5
		_add_simple_stool(root, "RamenStool", t * width_m * 0.55, 0.0, counter_z - 0.70)

	_add_local_box(root, "RamenCookline", Vector3(0.0, 0.52, depth_m * 0.34),
		Vector3(width_m * 0.56, 0.92, 0.64), mat_weathered_metal)
	_add_local_box(root, "RamenCooklineTop", Vector3(0.0, 1.01, depth_m * 0.34),
		Vector3(width_m * 0.58, 0.07, 0.70), mat_soft_white)
	_add_local_box(root, "RamenKitchenSplash", Vector3(0.0, 1.43, depth_m * 0.445),
		Vector3(width_m * 0.54, 0.82, 0.055), mat_weathered_metal)
	_add_local_box(root, "RamenTaskStrip", Vector3(0.0, 2.30, depth_m * 0.27),
		Vector3(width_m * 0.52, 0.045, 0.20), mat_interior_task_warm)
	_add_local_box(root, "RamenShelfGlow", Vector3(0.0, 1.83, depth_m * 0.425),
		Vector3(width_m * 0.44, 0.035, 0.06), mat_interior_task_warm)

	# Three stock/pot silhouettes are enough to communicate a working kitchen
	# without turning every procedural ramen shop into a high-node prop pile.
	for pot_index: int in range(3):
		var pot_x: float = (float(pot_index) - 1.0) * minf(0.56, width_m * 0.10)
		_add_local_cylinder(root, "RamenStockPot", Vector3(pot_x, 1.14, depth_m * 0.34),
			0.15, 0.18, mat_soft_white)

	_add_local_box(root, "RamenBackShelf", Vector3(-width_m * 0.34, 1.18, depth_m * 0.32),
		Vector3(0.40, 1.72, depth_m * 0.34), mat_wood)
	_add_menu_slats(root, width_m * 0.20, 2.05, depth_m * 0.39, 4)
	if depth_m > 6.0:
		_add_local_box(root, "RamenBooth", Vector3(width_m * 0.27, 0.38, -depth_m * 0.22),
			Vector3(width_m * 0.24, 0.58, 1.10), mat_dark_wood)
		_add_local_box(root, "RamenBoothTable", Vector3(width_m * 0.10, 0.38, -depth_m * 0.22),
			Vector3(0.70, 0.09, 0.62), mat_counter_warm)

func _add_izakaya_interior(root: Node3D, width_m: float, depth_m: float) -> void:
	# The izakaya stays darker than ramen, but the bar top, bottle wall and
	# pendants create a warm readable spine like the supplied reference.
	var bar_z: float = depth_m * 0.14
	_add_local_box(root, "IzakayaBar", Vector3(-width_m * 0.08, 0.56, bar_z),
		Vector3(width_m * 0.64, 1.02, 0.64), mat_dark_wood)
	_add_local_box(root, "IzakayaBarTop", Vector3(-width_m * 0.08, 1.085, bar_z),
		Vector3(width_m * 0.67, 0.085, 0.72), mat_counter_warm)
	_add_local_box(root, "IzakayaBarEdgeGlow", Vector3(-width_m * 0.08, 0.92, bar_z - 0.345),
		Vector3(width_m * 0.48, 0.030, 0.035), mat_interior_bar_warm)

	var stool_count: int = clampi(int(width_m / 1.55), 3, 5)
	for i: int in range(stool_count):
		var t: float = (float(i) + 0.5) / float(stool_count) - 0.5
		_add_simple_stool(root, "BarStool", t * width_m * 0.54 - width_m * 0.08, 0.0, bar_z - 0.74)

	# v10.21: the back bar is now mostly physical dark timber. Narrow warm
	# shelf strips reveal bottles without turning the entire rear wall into a
	# glowing rectangle.
	_add_local_box(root, "BackBarBacking", Vector3(-width_m * 0.18, 1.48, depth_m * 0.405),
		Vector3(width_m * 0.52, 1.32, 0.055), mat_weathered_timber)
	_add_local_box(root, "BottleShelf", Vector3(-width_m * 0.18, 1.38, depth_m * 0.385),
		Vector3(width_m * 0.50, 1.45, 0.16), mat_dark_wood)
	for shelf_index: int in range(3):
		var shelf_y: float = 0.96 + float(shelf_index) * 0.42
		_add_local_box(root, "BottleShelfRail",
			Vector3(-width_m * 0.18, shelf_y, depth_m * 0.285),
			Vector3(width_m * 0.48, 0.055, 0.24), mat_counter_warm)
		_add_local_box(root, "BottleShelfLight",
			Vector3(-width_m * 0.18, shelf_y + 0.075, depth_m * 0.268),
			Vector3(width_m * 0.42, 0.025, 0.025), mat_interior_bar_warm)

	# Industrial pendant rhythm: dark shade + warm lens. These meshes are
	# emissive only and remain inside the existing eight-light performance cap.
	for pendant_index: int in range(3):
		var pendant_t: float = float(pendant_index) / 2.0 - 0.5
		var pendant_x: float = -width_m * 0.08 + pendant_t * width_m * 0.42
		_add_local_cylinder(root, "IzakayaPendantShade", Vector3(pendant_x, 2.34, bar_z - 0.04),
			0.20, 0.11, mat_black_metal)
		_add_local_cylinder(root, "IzakayaPendantLens", Vector3(pendant_x, 2.275, bar_z - 0.04),
			0.12, 0.045, mat_interior_bar_warm)
		_add_local_cylinder(root, "IzakayaPendantStem", Vector3(pendant_x, 2.53, bar_z - 0.04),
			0.018, 0.32, mat_black_metal)

	# A small number of bottle silhouettes keeps the back wall dense without a
	# city-wide prop explosion. Alternate amber and dark glass for variation.
	for bottle_index: int in range(9):
		var bottle_t: float = float(bottle_index) / 8.0 - 0.5
		var bottle_mat: Material = mat_bottle_amber if bottle_index % 2 == 0 else mat_glass
		_add_local_box(root, "Bottle",
			Vector3(-width_m * 0.18 + bottle_t * width_m * 0.40, 1.34 + 0.38 * float(bottle_index % 2), depth_m * 0.275),
			Vector3(0.065, 0.25 + 0.04 * float(bottle_index % 3), 0.065), bottle_mat)

	_add_local_box(root, "IzakayaBackFridge", Vector3(width_m * 0.33, 0.88, depth_m * 0.31),
		Vector3(0.55, 1.62, 0.54), mat_black_metal)
	if depth_m > 5.5:
		_add_local_box(root, "BoothSeat", Vector3(width_m * 0.31, 0.40, -depth_m * 0.18),
			Vector3(width_m * 0.24, 0.62, 1.15), mat_dark_wood)
		_add_local_box(root, "BoothTable", Vector3(width_m * 0.09, 0.38, -depth_m * 0.18),
			Vector3(0.78, 0.10, 0.70), mat_counter_warm)
		_add_local_cylinder(root, "BoothTableLamp", Vector3(width_m * 0.09, 0.57, -depth_m * 0.18),
			0.055, 0.12, mat_interior_bar_warm)
	_add_menu_slats(root, width_m * 0.24, 2.08, depth_m * 0.40, 5)

func _add_convenience_interior(root: Node3D, width_m: float, depth_m: float) -> void:
	_add_local_box(root, "KioskCounter", Vector3(width_m * 0.20, 0.54, depth_m * 0.27),
		Vector3(width_m * 0.36, 0.96, 0.68), mat_soft_white)
	for side: float in [-1.0, 1.0]:
		_add_local_box(root, "AisleShelf", Vector3(width_m * 0.24 * side, 0.72, -depth_m * 0.02),
			Vector3(0.48, 1.20, depth_m * 0.48), mat_soft_white)
	_add_local_box(root, "DrinkFridge", Vector3(-width_m * 0.34, 0.92, depth_m * 0.30),
		Vector3(0.62, 1.70, 0.62), mat_black_metal)

func _add_repair_interior(root: Node3D, width_m: float, depth_m: float) -> void:
	_add_local_box(root, "RepairBench", Vector3(0.0, 0.52, depth_m * 0.29),
		Vector3(width_m * 0.62, 0.92, 0.72), mat_black_metal)
	_add_local_box(root, "ToolWall", Vector3(0.0, 1.45, depth_m * 0.43),
		Vector3(width_m * 0.58, 1.25, 0.10), mat_rust)
	_add_local_box(root, "PartsShelf", Vector3(width_m * 0.34, 1.02, 0.0),
		Vector3(0.46, 1.80, depth_m * 0.46), mat_black_metal)
	_add_local_box(root, "PartsCrate", Vector3(-width_m * 0.26, 0.26, -depth_m * 0.16),
		Vector3(0.86, 0.46, 0.72), mat_wood)

func _add_mixed_shop_interior(root: Node3D, width_m: float, depth_m: float) -> void:
	_add_local_box(root, "MixedCounter", Vector3(0.0, 0.52, depth_m * 0.26),
		Vector3(width_m * 0.48, 0.92, 0.64), mat_dark_wood)
	_add_local_box(root, "MixedShelf", Vector3(width_m * 0.34, 1.00, 0.08),
		Vector3(0.42, 1.72, depth_m * 0.42), mat_wood)
	_add_local_box(root, "MixedDisplay", Vector3(-width_m * 0.16, 0.38, -depth_m * 0.10),
		Vector3(1.20, 0.60, 0.72), mat_concrete)

func _add_simple_stool(root: Node3D, prefix: String, x: float, y: float, z: float) -> void:
	_add_local_cylinder(root, prefix + "Seat", Vector3(x, y + 0.52, z), 0.20, 0.10, mat_dark_wood)
	_add_local_cylinder(root, prefix + "Stem", Vector3(x, y + 0.28, z), 0.045, 0.46, mat_black_metal)

func _add_menu_slats(root: Node3D, center_x: float, y: float, z: float, count: int) -> void:
	for i: int in range(count):
		var x: float = center_x + (float(i) - float(count - 1) * 0.5) * 0.26
		_add_local_box(root, "MenuSlat", Vector3(x, y, z), Vector3(0.20, 0.62, 0.035), mat_menu_paper_warm)

func _choose_window_material(warm_chance: float = 0.14) -> Material:
	var roll: float = town_rng.randf()
	if roll < warm_chance:
		return mat_window_warm
	if roll < warm_chance + 0.040:
		return mat_window_blue
	return mat_window_dark_opaque

func _random_neon_material() -> Material:
	# Project SHINRAI palette: mostly red/pink, with cyan used sparingly.
	# Saturated yellow signage is intentionally excluded from random neon.
	var choice: int = town_rng.randi_range(0, 9)
	if choice <= 4:
		return mat_neon_pink
	if choice <= 7:
		return mat_neon_red
	return mat_neon_blue

func _roadside_hardware_offset(road_center: int) -> float:
	# Physical road edge is half a tile beyond the outer road-centre cell.
	# The tiny positive outset puts poles on the curb/sidewalk seam instead of
	# pushing them deep into the perimeter-building strip.
	return (float(_road_half_width(road_center)) + 0.5) * TILE_SIZE + ROADSIDE_HARDWARE_OUTSET

func _build_utility_poles_and_cables() -> void:
	var cable_material: StandardMaterial3D = _material(Color(0.012, 0.014, 0.017), 0.18, 0.82)

	# Dense overhead services are one of the strongest Japanese-street cues in
	# both the photo reference and the SHINRAI concepts. v10.25i keeps the main
	# pole-to-pole bundles but moves them onto the actual curb line and keeps
	# every conductor on the road-facing half of the crossbar.
	#
	# Previous facade "service drops" used a blind +2.35 m offset into the lot.
	# That could terminate inside a generated building and visibly route a wire
	# through walls/eaves. They are intentionally omitted until service anchors
	# can be derived from the actual generated facade plane.
	var vertical_roads: Array[int] = [4, 16, 36, 48]
	for road_x: int in vertical_roads:
		var previous_top: Vector3 = Vector3.ZERO
		var previous_valid: bool = false
		var pole_serial: int = 0
		for y: int in range(6, GRID_HEIGHT - 5, 6):
			if _is_road_axis(y):
				continue
			var road_center: Vector3 = _cell_to_world(Vector2i(road_x, y), 0.0)
			var side_offset: float = _roadside_hardware_offset(road_x)
			var pole_pos: Vector3 = road_center + Vector3(side_offset, 0.0, 0.0)
			var top: Vector3 = _add_utility_pole(
				pole_pos,
				"UtilityPoleV%d_%d" % [road_x, pole_serial],
				true
			)
			if previous_valid:
				_add_sag_cable(previous_top + Vector3(-0.72, 0.0, 0.0), top + Vector3(-0.72, 0.0, 0.0), cable_material, "CableV%d_%dA" % [road_x, pole_serial])
				_add_sag_cable(previous_top + Vector3(-0.54, -0.10, 0.0), top + Vector3(-0.54, -0.10, 0.0), cable_material, "CableV%d_%dB" % [road_x, pole_serial])
				_add_sag_cable(previous_top + Vector3(-0.36, -0.52, 0.0), top + Vector3(-0.36, -0.52, 0.0), cable_material, "CableV%d_%dC" % [road_x, pole_serial])
				_add_sag_cable(previous_top + Vector3(-0.20, -0.26, 0.0), top + Vector3(-0.20, -0.26, 0.0), cable_material, "CableV%d_%dD" % [road_x, pole_serial])
				_add_sag_cable(previous_top + Vector3(-0.08, -0.38, 0.0), top + Vector3(-0.08, -0.38, 0.0), cable_material, "CableV%d_%dE" % [road_x, pole_serial])
			previous_top = top
			previous_valid = true
			pole_serial += 1

	var horizontal_roads: Array[int] = [4, 16, 36, 48]
	for road_y: int in horizontal_roads:
		var previous_top_h: Vector3 = Vector3.ZERO
		var previous_valid_h: bool = false
		var pole_serial_h: int = 0
		for x: int in range(6, GRID_WIDTH - 5, 6):
			if _is_road_axis(x):
				continue
			var road_center_h: Vector3 = _cell_to_world(Vector2i(x, road_y), 0.0)
			var side_offset_h: float = _roadside_hardware_offset(road_y)
			var pole_pos_h: Vector3 = road_center_h + Vector3(0.0, 0.0, side_offset_h)
			var top_h: Vector3 = _add_utility_pole(
				pole_pos_h,
				"UtilityPoleH%d_%d" % [road_y, pole_serial_h],
				false
			)
			if previous_valid_h:
				_add_sag_cable(previous_top_h + Vector3(0.0, 0.0, -0.72), top_h + Vector3(0.0, 0.0, -0.72), cable_material, "CableH%d_%dA" % [road_y, pole_serial_h])
				_add_sag_cable(previous_top_h + Vector3(0.0, -0.10, -0.54), top_h + Vector3(0.0, -0.10, -0.54), cable_material, "CableH%d_%dB" % [road_y, pole_serial_h])
				_add_sag_cable(previous_top_h + Vector3(0.0, -0.52, -0.36), top_h + Vector3(0.0, -0.52, -0.36), cable_material, "CableH%d_%dC" % [road_y, pole_serial_h])
				_add_sag_cable(previous_top_h + Vector3(0.0, -0.26, -0.20), top_h + Vector3(0.0, -0.26, -0.20), cable_material, "CableH%d_%dD" % [road_y, pole_serial_h])
				_add_sag_cable(previous_top_h + Vector3(0.0, -0.38, -0.08), top_h + Vector3(0.0, -0.38, -0.08), cable_material, "CableH%d_%dE" % [road_y, pole_serial_h])
			previous_top_h = top_h
			previous_valid_h = true
			pole_serial_h += 1

func _add_utility_pole(
	position_value: Vector3,
	pole_name: String,
	road_along_z: bool
) -> Vector3:
	var pole_root: Node3D = Node3D.new()
	pole_root.name = pole_name
	pole_root.position = position_value
	decoration_root.add_child(pole_root)

	_add_local_cylinder(
		pole_root, "Pole", Vector3(0.0, 3.15, 0.0),
		0.11, 6.30, mat_dark_wood
	)

	# Poles are always generated on the positive side of the road. Shift the
	# crossbar/transformer back toward the street, and orient the crossbar
	# perpendicular to the road. This prevents the building-side half of the
	# hardware from entering a facade while preserving the overhead silhouette.
	if road_along_z:
		_add_local_box(
			pole_root, "Crossbar", Vector3(-0.46, 5.62, 0.0),
			Vector3(0.92, 0.11, 0.12), mat_dark_wood
		)
		_add_local_box(
			pole_root, "Transformer", Vector3(-0.24, 4.42, 0.0),
			Vector3(0.42, 0.58, 0.36), mat_dark_concrete
		)
	else:
		_add_local_box(
			pole_root, "Crossbar", Vector3(0.0, 5.62, -0.46),
			Vector3(0.12, 0.11, 0.92), mat_dark_wood
		)
		_add_local_box(
			pole_root, "Transformer", Vector3(0.0, 4.42, -0.24),
			Vector3(0.36, 0.58, 0.42), mat_dark_concrete
		)
	return position_value + Vector3(0.0, 5.76, 0.0)

func _add_sag_cable(
	from_position: Vector3,
	to_position: Vector3,
	material: Material,
	cable_name: String
) -> void:
	var midpoint: Vector3 = (from_position + to_position) * 0.5 + Vector3(0.0, -0.42, 0.0)
	_add_beam_between(decoration_root, cable_name + "A", from_position, midpoint, 0.028, material)
	_add_beam_between(decoration_root, cable_name + "B", midpoint, to_position, 0.028, material)

func _add_beam_between(
	parent: Node3D,
	beam_name: String,
	from_position: Vector3,
	to_position: Vector3,
	thickness: float,
	material: Material
) -> void:
	var delta: Vector3 = to_position - from_position
	var length: float = delta.length()
	if length <= 0.001:
		return
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = beam_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, length)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = (from_position + to_position) * 0.5
	# Hundreds of cable segments were contributing draw and shadow work across
	# the full map. Keep the dense overhead silhouette nearby, but cheaply.
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.visibility_range_end = CABLE_VISIBILITY_RANGE
	mesh_instance.visibility_range_end_margin = 10.0
	parent.add_child(mesh_instance)
	mesh_instance.look_at(to_position, Vector3.UP)

func _build_street_lights() -> void:
	street_light_count = 0
	var light_count: int = 0
	var light_cap: int = MAX_STREET_LIGHTS
	if commercial_test_corridor_mode:
		light_cap -= YAKITORI_CANOPY_LIGHT_COUNT
	for road_x: int in ROAD_CENTERS:
		for road_y: int in ROAD_CENTERS:
			if light_count >= light_cap:
				return
			if (road_x + road_y) % 3 != 0 and not (
				road_x == MAIN_ROAD_CENTER or road_y == MAIN_ROAD_CENTER
			):
				continue
			var intersection: Vector3 = _cell_to_world(Vector2i(road_x, road_y), 0.0)
			# v10.25i: use the physical road edge rather than the old +0.72-tile
			# offset, which could put the pole base inside a corner building.
			var offset: Vector3 = Vector3(
				_roadside_hardware_offset(road_x),
				0.0,
				_roadside_hardware_offset(road_y)
			)
			_add_street_light(intersection + offset, light_count)
			light_count += 1
			street_light_count += 1

func _add_street_light(position_value: Vector3, light_index: int) -> void:
	var root: Node3D = Node3D.new()
	root.name = "StreetLight%d" % light_index
	root.position = position_value
	decoration_root.add_child(root)

	_add_local_cylinder(root, "Pole", Vector3(0.0, 2.55, 0.0), 0.075, 5.10, mat_black_metal)
	# The fixture arm points back toward the intersection, keeping the luminaire
	# over the street instead of above the building corner.
	_add_local_box(root, "Arm", Vector3(0.0, 4.82, -0.42), Vector3(0.08, 0.08, 0.86), mat_black_metal)
	_add_local_box(root, "LampHead", Vector3(0.0, 4.80, -0.86), Vector3(0.40, 0.11, 0.50), mat_soft_white)
	_add_local_box(root, "LampLens", Vector3(0.0, 4.73, -0.87), Vector3(0.30, 0.035, 0.38), mat_sign_warm)

	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, 4.58, -0.84)
	light.light_color = Color(1.0, 0.79, 0.60)
	light.light_energy = 0.70
	light.omni_range = 7.4
	light.shadow_enabled = false
	root.add_child(light)
	light.add_to_group("shinrai_street_light")

func _yakitori_runtime_material(
	authored_model: Node3D,
	mesh_name: String,
	fallback: Material,
	repeat_scale: float,
	roughness_value: float,
	normal_strength: float,
	alpha_value: float = -1.0,
	use_triplanar: bool = true
) -> StandardMaterial3D:
	var target_mesh: MeshInstance3D = authored_model.find_child(
		mesh_name, true, false
	) as MeshInstance3D
	var source: StandardMaterial3D = null
	if target_mesh != null:
		source = target_mesh.get_active_material(0) as StandardMaterial3D
	if source == null:
		source = fallback as StandardMaterial3D

	var material: StandardMaterial3D = StandardMaterial3D.new()
	if source != null:
		material = source.duplicate(true) as StandardMaterial3D
	material.resource_local_to_scene = true
	material.metallic = 0.0
	material.roughness = roughness_value
	material.metallic_specular = 0.28
	material.normal_scale = normal_strength
	material.uv1_scale = Vector3(repeat_scale, repeat_scale, repeat_scale)
	material.uv1_triplanar = use_triplanar
	if alpha_value >= 0.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var alpha_color: Color = material.albedo_color
		alpha_color.a = alpha_value
		material.albedo_color = alpha_color
	if target_mesh != null:
		target_mesh.material_override = material
	return material

func _yakitori_wood_material(
	source: StandardMaterial3D,
	color_factor: Color,
	roughness_value: float,
	repeat_scale: float,
	normal_strength: float,
	use_triplanar: bool
) -> StandardMaterial3D:
	var material: StandardMaterial3D = source.duplicate(true) as StandardMaterial3D
	material.resource_local_to_scene = true
	material.albedo_color = color_factor
	material.metallic = 0.0
	material.metallic_specular = 0.28
	material.roughness = roughness_value
	material.normal_scale = normal_strength
	material.uv1_scale = Vector3(repeat_scale, repeat_scale, repeat_scale)
	material.uv1_triplanar = use_triplanar
	return material

func _yakitori_plaster_material(
	source: StandardMaterial3D,
	use_triplanar: bool
) -> StandardMaterial3D:
	var material: StandardMaterial3D = source.duplicate(true) as StandardMaterial3D
	material.resource_local_to_scene = true
	# The bright night environment lifts the supplied 1K albedo substantially in
	# game. These warmer, lower factors compensate for that exposure so the wall
	# reads near the reference's aged grey instead of clean white plaster.
	material.albedo_color = Color(0.86, 0.83, 0.76, 1.0)
	material.metallic = 0.0
	material.metallic_specular = 0.24
	# ORM green averages 222.016/255. A 0.87291 material factor produces an
	# effective average roughness of 0.760: the middle of the 0.68-0.84 brief.
	material.roughness = 0.90
	material.normal_scale = 0.52
	material.uv1_scale = Vector3(0.60, 0.60, 0.60)
	material.uv1_triplanar = use_triplanar
	return material

func _add_yakitori_x_grain_box(
	parent: Node3D,
	part_name: String,
	position_value: Vector3,
	size: Vector3,
	material: Material
) -> MeshInstance3D:
	return _add_local_box(
		parent,
		part_name,
		position_value,
		Vector3(size.y, size.x, size.z),
		material,
		Vector3(0.0, 0.0, -PI * 0.5)
	)

func _add_yakitori_z_grain_box(
	parent: Node3D,
	part_name: String,
	position_value: Vector3,
	size: Vector3,
	material: Material
) -> MeshInstance3D:
	return _add_local_box(
		parent,
		part_name,
		position_value,
		Vector3(size.x, size.z, size.y),
		material,
		Vector3(PI * 0.5, 0.0, 0.0)
	)

func _yakitori_union_find_root(parents: Array[int], item: int) -> int:
	var root: int = item
	while parents[root] != root:
		root = parents[root]
	var cursor: int = item
	while parents[cursor] != cursor:
		var next_cursor: int = parents[cursor]
		parents[cursor] = root
		cursor = next_cursor
	return root

func _yakitori_union_find_join(
	parents: Array[int],
	component_sizes: Array[int],
	a: int,
	b: int
) -> void:
	var root_a: int = _yakitori_union_find_root(parents, a)
	var root_b: int = _yakitori_union_find_root(parents, b)
	if root_a == root_b:
		return
	if component_sizes[root_a] < component_sizes[root_b]:
		var swap_root: int = root_a
		root_a = root_b
		root_b = swap_root
	parents[root_b] = root_a
	component_sizes[root_a] += component_sizes[root_b]

func _yakitori_remove_mesh_components_above(
	target_mesh: MeshInstance3D,
	component_floor_cutoff: float
) -> int:
	# The supplied one-storey asset combines many bevelled boxes into broad
	# material meshes. Rebuild their index buffers once at startup, grouping
	# triangles by coincident positions, so only complete obsolete components are
	# removed. All vertex attributes, UVs, normals and PBR material assignments
	# remain unchanged on the retained storefront and canopy.
	if target_mesh == null:
		return 0
	var source_mesh: ArrayMesh = target_mesh.mesh as ArrayMesh
	if source_mesh == null:
		return 0

	var filtered_mesh: ArrayMesh = ArrayMesh.new()
	filtered_mesh.resource_local_to_scene = true
	var removed_triangle_count: int = 0

	for surface_index: int in range(source_mesh.get_surface_count()):
		var primitive_type: Mesh.PrimitiveType = source_mesh.surface_get_primitive_type(
			surface_index
		)
		var source_arrays: Array = source_mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = source_arrays[Mesh.ARRAY_INDEX]
		if primitive_type != Mesh.PRIMITIVE_TRIANGLES or indices.is_empty():
			filtered_mesh.add_surface_from_arrays(primitive_type, source_arrays)
			filtered_mesh.surface_set_material(
				filtered_mesh.get_surface_count() - 1,
				source_mesh.surface_get_material(surface_index)
			)
			continue

		var triangle_count: int = indices.size() / 3
		var parents: Array[int] = []
		var component_sizes: Array[int] = []
		parents.resize(triangle_count)
		component_sizes.resize(triangle_count)
		for triangle_index: int in range(triangle_count):
			parents[triangle_index] = triangle_index
			component_sizes[triangle_index] = 1

		# Imported bevels duplicate vertices between faces, so triangle indices
		# alone do not reveal connected pieces. Quantized position keys reconnect
		# those coincident vertices without joining neighbouring separate boards.
		var first_triangle_by_position: Dictionary = {}
		for triangle_index: int in range(triangle_count):
			for corner_index: int in range(3):
				var vertex: Vector3 = vertices[indices[triangle_index * 3 + corner_index]]
				var position_key: Vector3i = Vector3i(
					roundi(vertex.x * 100000.0),
					roundi(vertex.y * 100000.0),
					roundi(vertex.z * 100000.0)
				)
				if first_triangle_by_position.has(position_key):
					_yakitori_union_find_join(
						parents,
						component_sizes,
						triangle_index,
						int(first_triangle_by_position[position_key])
					)
				else:
					first_triangle_by_position[position_key] = triangle_index

		var component_min_y: Dictionary = {}
		for triangle_index: int in range(triangle_count):
			var component_root: int = _yakitori_union_find_root(parents, triangle_index)
			var minimum_y: float = INF
			for corner_index: int in range(3):
				minimum_y = minf(
					minimum_y,
					vertices[indices[triangle_index * 3 + corner_index]].y
				)
			if component_min_y.has(component_root):
				component_min_y[component_root] = minf(
					float(component_min_y[component_root]), minimum_y
				)
			else:
				component_min_y[component_root] = minimum_y

		var kept_indices: PackedInt32Array = PackedInt32Array()
		for triangle_index: int in range(triangle_count):
			var component_root: int = _yakitori_union_find_root(parents, triangle_index)
			if float(component_min_y[component_root]) >= component_floor_cutoff:
				removed_triangle_count += 1
				continue
			kept_indices.append(indices[triangle_index * 3])
			kept_indices.append(indices[triangle_index * 3 + 1])
			kept_indices.append(indices[triangle_index * 3 + 2])

		var filtered_arrays: Array = source_arrays.duplicate(true)
		filtered_arrays[Mesh.ARRAY_INDEX] = kept_indices
		filtered_mesh.add_surface_from_arrays(primitive_type, filtered_arrays)
		var filtered_surface_index: int = filtered_mesh.get_surface_count() - 1
		filtered_mesh.surface_set_material(
			filtered_surface_index,
			source_mesh.surface_get_material(surface_index)
		)
		filtered_mesh.surface_set_name(
			filtered_surface_index,
			source_mesh.surface_get_name(surface_index)
		)

	if removed_triangle_count > 0:
		target_mesh.mesh = filtered_mesh
	return removed_triangle_count

func _yakitori_remove_mesh_components_inside(
	target_mesh: MeshInstance3D,
	selection: AABB
) -> int:
	# Remove only complete disconnected pieces contained by a local-space box.
	# The authored architectural-metal surface combines the two old door pulls
	# with unrelated trim, so filtering whole components preserves every part
	# outside the centre-door hardware zone.
	if target_mesh == null:
		return 0
	var source_mesh: ArrayMesh = target_mesh.mesh as ArrayMesh
	if source_mesh == null:
		return 0

	var filtered_mesh: ArrayMesh = ArrayMesh.new()
	filtered_mesh.resource_local_to_scene = true
	var removed_triangle_count: int = 0
	var selection_end: Vector3 = selection.position + selection.size

	for surface_index: int in range(source_mesh.get_surface_count()):
		var primitive_type: Mesh.PrimitiveType = source_mesh.surface_get_primitive_type(
			surface_index
		)
		var source_arrays: Array = source_mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = source_arrays[Mesh.ARRAY_INDEX]
		if primitive_type != Mesh.PRIMITIVE_TRIANGLES or indices.is_empty():
			filtered_mesh.add_surface_from_arrays(primitive_type, source_arrays)
			filtered_mesh.surface_set_material(
				filtered_mesh.get_surface_count() - 1,
				source_mesh.surface_get_material(surface_index)
			)
			continue

		var triangle_count: int = indices.size() / 3
		var parents: Array[int] = []
		var component_sizes: Array[int] = []
		parents.resize(triangle_count)
		component_sizes.resize(triangle_count)
		for triangle_index: int in range(triangle_count):
			parents[triangle_index] = triangle_index
			component_sizes[triangle_index] = 1

		var first_triangle_by_position: Dictionary = {}
		for triangle_index: int in range(triangle_count):
			for corner_index: int in range(3):
				var vertex: Vector3 = vertices[indices[triangle_index * 3 + corner_index]]
				var position_key: Vector3i = Vector3i(
					roundi(vertex.x * 100000.0),
					roundi(vertex.y * 100000.0),
					roundi(vertex.z * 100000.0)
				)
				if first_triangle_by_position.has(position_key):
					_yakitori_union_find_join(
						parents,
						component_sizes,
						triangle_index,
						int(first_triangle_by_position[position_key])
					)
				else:
					first_triangle_by_position[position_key] = triangle_index

		var component_minimum: Dictionary = {}
		var component_maximum: Dictionary = {}
		for triangle_index: int in range(triangle_count):
			var component_root: int = _yakitori_union_find_root(parents, triangle_index)
			for corner_index: int in range(3):
				var vertex: Vector3 = vertices[indices[triangle_index * 3 + corner_index]]
				if component_minimum.has(component_root):
					var minimum: Vector3 = component_minimum[component_root]
					var maximum: Vector3 = component_maximum[component_root]
					component_minimum[component_root] = minimum.min(vertex)
					component_maximum[component_root] = maximum.max(vertex)
				else:
					component_minimum[component_root] = vertex
					component_maximum[component_root] = vertex

		var kept_indices: PackedInt32Array = PackedInt32Array()
		for triangle_index: int in range(triangle_count):
			var component_root: int = _yakitori_union_find_root(parents, triangle_index)
			var minimum: Vector3 = component_minimum[component_root]
			var maximum: Vector3 = component_maximum[component_root]
			var inside_selection: bool = (
				minimum.x >= selection.position.x
				and minimum.y >= selection.position.y
				and minimum.z >= selection.position.z
				and maximum.x <= selection_end.x
				and maximum.y <= selection_end.y
				and maximum.z <= selection_end.z
			)
			if inside_selection:
				removed_triangle_count += 1
				continue
			kept_indices.append(indices[triangle_index * 3])
			kept_indices.append(indices[triangle_index * 3 + 1])
			kept_indices.append(indices[triangle_index * 3 + 2])

		var filtered_arrays: Array = source_arrays.duplicate(true)
		filtered_arrays[Mesh.ARRAY_INDEX] = kept_indices
		filtered_mesh.add_surface_from_arrays(primitive_type, filtered_arrays)
		var filtered_surface_index: int = filtered_mesh.get_surface_count() - 1
		filtered_mesh.surface_set_material(
			filtered_surface_index,
			source_mesh.surface_get_material(surface_index)
		)
		filtered_mesh.surface_set_name(
			filtered_surface_index,
			source_mesh.surface_get_name(surface_index)
		)

	if removed_triangle_count > 0:
		target_mesh.mesh = filtered_mesh
	return removed_triangle_count

func _upgrade_yakitori_shop_architecture(authored_model: Node3D) -> Node3D:
	# Reuse the authored PBR maps for every new piece so the extension reads as
	# one manufactured building, not a stack of differently shaded primitives.
	var plaster_source: StandardMaterial3D = _yakitori_runtime_material(
		authored_model,
		"SM_YakitoriShop_AgedPlasterShell",
		mat_shop_plaster,
		1.0,
		0.87291,
		0.45,
		-1.0,
		false
	)
	var plaster_authored: StandardMaterial3D = _yakitori_plaster_material(
		plaster_source, false
	)
	var plaster_mesh: MeshInstance3D = authored_model.find_child(
		"SM_YakitoriShop_AgedPlasterShell", true, false
	) as MeshInstance3D
	if plaster_mesh != null:
		plaster_mesh.material_override = plaster_authored
	var plaster: StandardMaterial3D = _yakitori_plaster_material(
		plaster_source, true
	)
	var wall_grime_low: StandardMaterial3D = plaster.duplicate(true) as StandardMaterial3D
	wall_grime_low.resource_local_to_scene = true
	wall_grime_low.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wall_grime_low.albedo_color = Color(0.30, 0.285, 0.255, 0.18)
	wall_grime_low.roughness = 0.96
	wall_grime_low.normal_scale = 0.34
	var wall_grime_high: StandardMaterial3D = wall_grime_low.duplicate(true) as StandardMaterial3D
	wall_grime_high.resource_local_to_scene = true
	wall_grime_high.albedo_color = Color(0.34, 0.325, 0.295, 0.075)
	var wall_joint: StandardMaterial3D = plaster.duplicate(true) as StandardMaterial3D
	wall_joint.resource_local_to_scene = true
	wall_joint.albedo_color = Color(
		plaster.albedo_color.r * 0.82,
		plaster.albedo_color.g * 0.83,
		plaster.albedo_color.b * 0.85,
		1.0
	)
	wall_joint.roughness = 0.84
	wall_joint.normal_scale = 0.20
	wall_joint.uv1_scale = Vector3(0.58, 0.58, 0.58)
	wall_joint.uv1_triplanar = true

	# The source shell uses several bright footing blocks across the frontage.
	# Preserve its stone texture as the source, then replace that segmented mesh
	# with one restrained dark course shared by the threshold and wall perimeter.
	var concrete_base_mesh: MeshInstance3D = authored_model.find_child(
		"SM_YakitoriShop_ConcreteBase", true, false
	) as MeshInstance3D
	var plinth: StandardMaterial3D = StandardMaterial3D.new()
	if concrete_base_mesh != null:
		var concrete_base_source: StandardMaterial3D = concrete_base_mesh.get_active_material(0) as StandardMaterial3D
		if concrete_base_source != null:
			plinth = concrete_base_source.duplicate(true) as StandardMaterial3D
	elif mat_stone != null:
		plinth = mat_stone.duplicate(true) as StandardMaterial3D
	plinth.resource_local_to_scene = true
	plinth.albedo_color = Color(0.54, 0.52, 0.48, 1.0)
	plinth.metallic = 0.0
	plinth.metallic_specular = 0.22
	plinth.roughness = 0.78
	plinth.normal_scale = maxf(plinth.normal_scale, 0.44)
	plinth.uv1_scale = Vector3(0.76, 0.76, 0.76)
	plinth.uv1_triplanar = true
	if concrete_base_mesh != null:
		concrete_base_mesh.visible = false

	var cedar_source: StandardMaterial3D = _yakitori_runtime_material(
		authored_model,
		"SM_YakitoriShop_DarkCedarArchitecture",
		mat_weathered_timber,
		1.0,
		0.62,
		0.62,
		-1.0,
		false
	)
	var cedar_main: StandardMaterial3D = _yakitori_wood_material(
		cedar_source, Color(0.86, 1.00, 1.18, 1.0), 0.62, 0.70, 0.62, false
	)
	var cedar_mesh: MeshInstance3D = authored_model.find_child(
		"SM_YakitoriShop_DarkCedarArchitecture", true, false
	) as MeshInstance3D
	if cedar_mesh != null:
		cedar_mesh.material_override = cedar_main
	var cedar_frame: StandardMaterial3D = _yakitori_wood_material(
		cedar_source, Color(1.04, 1.24, 1.50, 1.0), 0.56, 0.45, 0.64, true
	)
	var cedar_upper: StandardMaterial3D = _yakitori_wood_material(
		cedar_source, Color(1.05, 1.42, 1.75, 1.0), 0.66, 0.70, 0.54, true
	)
	var cedar_eave: StandardMaterial3D = _yakitori_wood_material(
		cedar_source, Color(1.78, 1.93, 2.00, 1.0), 0.54, 0.55, 0.58, true
	)

	var glass: StandardMaterial3D = _yakitori_runtime_material(
		authored_model,
		"SM_YakitoriShop_Glazing",
		mat_storefront_glass_dark,
		1.0,
		0.09,
		0.08,
		0.18,
		false
	)
	# Reference swatch #E6E1D6: warm-neutral, lightly dusty glazing rather than
	# blue-black mirrored panes. Subtle refraction preserves depth without making
	# the storefront visually wavy.
	glass.albedo_color = Color(0.902, 0.882, 0.839, 0.18)
	glass.metallic = 0.0
	glass.metallic_specular = 0.38
	glass.roughness = 0.09
	glass.normal_scale = 0.08
	glass.refraction_enabled = true
	glass.refraction_scale = 0.012
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED

	var interior: StandardMaterial3D = _yakitori_runtime_material(
		authored_model,
		"SM_YakitoriShop_DarkInteriorShell",
		mat_interior_wall_dark,
		1.0,
		0.92,
		0.0,
		-1.0,
		false
	)
	var roof: StandardMaterial3D = _yakitori_runtime_material(
		authored_model,
		"SM_YakitoriShop_RoofAndParapet",
		mat_roof,
		0.82,
		0.55,
		0.0,
		-1.0,
		true
	)
	roof.metallic = 0.06
	var authored_roof_mesh: MeshInstance3D = authored_model.find_child(
		"SM_YakitoriShop_RoofAndParapet", true, false
	) as MeshInstance3D
	var metal: StandardMaterial3D = _yakitori_runtime_material(
		authored_model,
		"SM_YakitoriShop_ArchitecturalMetal",
		mat_black_metal,
		0.80,
		0.42,
		0.0,
		-1.0,
		true
	)
	metal.metallic = 0.86
	metal.metallic_specular = 0.44
	var hardware_metal: StandardMaterial3D = StandardMaterial3D.new()
	hardware_metal.resource_local_to_scene = true
	hardware_metal.albedo_color = Color(0.10, 0.105, 0.11, 1.0)
	hardware_metal.metallic = 0.92
	hardware_metal.metallic_specular = 0.46
	hardware_metal.roughness = 0.36

	# Remove only the two original extra-long pull assemblies. If the supplied
	# asset keeps all handle triangles in one compact mesh instead of separate
	# components, hide that handle-only mesh as a safe fallback.
	var architectural_metal_mesh: MeshInstance3D = authored_model.find_child(
		"SM_YakitoriShop_ArchitecturalMetal", true, false
	) as MeshInstance3D
	var removed_handle_triangles: int = _yakitori_remove_mesh_components_inside(
		architectural_metal_mesh,
		AABB(Vector3(-0.55, 0.55, -1.05), Vector3(1.10, 1.55, 0.55))
	)
	var hidden_handle_only_mesh: bool = false
	if removed_handle_triangles == 0 and architectural_metal_mesh != null:
		var architectural_metal_bounds: AABB = architectural_metal_mesh.get_aabb()
		if (
			architectural_metal_bounds.size.x <= 1.20
			and architectural_metal_bounds.size.y <= 1.80
			and architectural_metal_bounds.size.z <= 0.60
		):
			architectural_metal_mesh.visible = false
			hidden_handle_only_mesh = true

	# The source GLB was originally a one-storey shop. Its upper cedar cladding
	# and roof parapet occupied y=2.67-3.60, becoming a metre-tall belt when the
	# new upper floor was added. Keep the original ground-floor joinery and thin
	# projecting canopy, but remove those two obsolete upper components.
	var removed_cedar_triangles: int = _yakitori_remove_mesh_components_above(
		cedar_mesh, 2.665
	)
	var removed_roof_triangles: int = _yakitori_remove_mesh_components_above(
		authored_roof_mesh, 3.00
	)
	var upper_storey_drop: float = 0.70

	var architecture: Node3D = Node3D.new()
	architecture.name = "YakitoriArchitecture_v10_29a"
	architecture.add_to_group("shinrai_yakitori_architecture")
	architecture.set_meta("removed_legacy_cedar_triangles", removed_cedar_triangles)
	architecture.set_meta("removed_legacy_roof_triangles", removed_roof_triangles)
	architecture.set_meta("removed_legacy_handle_triangles", removed_handle_triangles)
	architecture.set_meta("hidden_legacy_handle_mesh", hidden_handle_only_mesh)
	authored_model.add_child(architecture)

	# Full-depth two-storey masonry shell. The front stays open so the authored
	# recessed storefront and its original glass remain untouched.
	_add_local_box(architecture, "PlasterWall_Left",
		Vector3(-2.02, 3.24 - upper_storey_drop * 0.5, 1.52),
		Vector3(0.18, 6.30 - upper_storey_drop, 4.22), plaster)
	_add_local_box(architecture, "PlasterWall_Right",
		Vector3(2.02, 3.24 - upper_storey_drop * 0.5, 1.52),
		Vector3(0.18, 6.30 - upper_storey_drop, 4.22), plaster)
	_add_local_box(architecture, "PlasterWall_Rear",
		Vector3(0.0, 3.24 - upper_storey_drop * 0.5, 3.56),
		Vector3(4.20, 6.30 - upper_storey_drop, 0.18), plaster)

	# Two very transparent textured passes create a soft ground-contact fade on
	# the side and rear walls. They stop above the stone cap, cast no shadows and
	# do not alter the building silhouette.
	var grime_side_x: Array[float] = [-2.114, 2.114]
	for grime_side_index: int in range(grime_side_x.size()):
		var side_grime_low: MeshInstance3D = _add_local_box(
			architecture, "WallGrimeSideLow_%02d" % grime_side_index,
			Vector3(grime_side_x[grime_side_index], 0.35, 1.52),
			Vector3(0.008, 0.18, 3.96), wall_grime_low
		)
		side_grime_low.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var side_grime_high: MeshInstance3D = _add_local_box(
			architecture, "WallGrimeSideHigh_%02d" % grime_side_index,
			Vector3(grime_side_x[grime_side_index], 0.53, 1.52),
			Vector3(0.008, 0.18, 3.96), wall_grime_high
		)
		side_grime_high.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rear_grime_low: MeshInstance3D = _add_local_box(
		architecture, "WallGrimeRearLow", Vector3(0.0, 0.35, 3.654),
		Vector3(3.96, 0.18, 0.008), wall_grime_low
	)
	rear_grime_low.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rear_grime_high: MeshInstance3D = _add_local_box(
		architecture, "WallGrimeRearHigh", Vector3(0.0, 0.53, 3.654),
		Vector3(3.96, 0.18, 0.008), wall_grime_high
	)
	rear_grime_high.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# A single compact upper-storey rear opening matches the building-only
	# reference. It shares the dedicated glazing response with the front windows;
	# the surrounding cedar and projecting sill complete the architecture.
	var rear_window_x: float = 1.14
	var rear_window_y: float = 4.80 - upper_storey_drop
	_add_local_box(architecture, "RearWindowReveal",
		Vector3(rear_window_x, rear_window_y, 3.658),
		Vector3(0.64, 0.88, 0.020), metal)
	_add_local_box(architecture, "RearWindowGlass",
		Vector3(rear_window_x, rear_window_y, 3.674),
		Vector3(0.46, 0.68, 0.026), glass)
	var rear_window_frame_x: Array[float] = [rear_window_x - 0.28, rear_window_x + 0.28]
	for rear_frame_index: int in range(rear_window_frame_x.size()):
		_add_local_box(architecture, "RearWindowFrameVertical_%02d" % rear_frame_index,
			Vector3(rear_window_frame_x[rear_frame_index], rear_window_y, 3.700),
			Vector3(0.065, 0.82, 0.070), cedar_frame)
	_add_yakitori_x_grain_box(architecture, "RearWindowFrameHead",
		Vector3(rear_window_x, rear_window_y + 0.385, 3.700),
		Vector3(0.625, 0.065, 0.070), cedar_frame)
	_add_yakitori_x_grain_box(architecture, "RearWindowFrameSill",
		Vector3(rear_window_x, rear_window_y - 0.385, 3.725),
		Vector3(0.68, 0.075, 0.12), cedar_frame)

	# Very fine concrete-panel reveals break up the deep blank shell without
	# reading as painted lines. The existing cedar floor ledger supplies the one
	# deliberate horizontal break, so the concrete joints remain vertical only.
	var side_joint_x: Array[float] = [-2.112, 2.112]
	var side_joint_z: Array[float] = [0.34, 1.55, 2.76]
	for side_index: int in range(side_joint_x.size()):
		for joint_index: int in range(side_joint_z.size()):
			_add_local_box(architecture,
				"SideWallVerticalJoint_%02d_%02d" % [side_index, joint_index],
				Vector3(side_joint_x[side_index],
					3.23 - upper_storey_drop * 0.5, side_joint_z[joint_index]),
				Vector3(0.010, 5.72 - upper_storey_drop, 0.012), wall_joint)

	# Keep the formwork seams clear of the new window opening.
	var rear_joint_x: Array[float] = [-0.72, 1.46]
	for joint_index: int in range(rear_joint_x.size()):
		_add_local_box(architecture, "RearWallVerticalJoint_%02d" % joint_index,
			Vector3(rear_joint_x[joint_index],
				3.23 - upper_storey_drop * 0.5, 3.652),
			Vector3(0.012, 5.72 - upper_storey_drop, 0.010), wall_joint)

	# Hairline rear corner profiles and wall-head flashing finish the masonry
	# intersections without competing with the cedar facade or roof silhouette.
	var rear_corner_x: Array[float] = [-2.114, 2.114]
	for corner_index: int in range(rear_corner_x.size()):
		_add_local_box(architecture, "RearCornerProfile_%02d" % corner_index,
			Vector3(rear_corner_x[corner_index],
				3.27 - upper_storey_drop * 0.5, 3.655),
			Vector3(0.030, 5.78 - upper_storey_drop, 0.030), metal)
		_add_yakitori_z_grain_box(architecture,
			"WallHeadSideTrim_%02d" % corner_index,
			Vector3(side_joint_x[corner_index], 6.275 - upper_storey_drop, 1.52),
			Vector3(0.032, 0.040, 4.08), metal)
	_add_yakitori_x_grain_box(architecture, "WallHeadRearTrim",
		Vector3(0.0, 6.275 - upper_storey_drop, 3.655),
		Vector3(4.26, 0.040, 0.032), metal)

	# One slim stone course now runs without gaps around all four sides. A single
	# shallow slab projects beneath the full storefront, replacing the previous
	# cluster of bright, offset blocks visible in the walkaround.
	_add_local_box(architecture, "FoundationPlinthFront",
		Vector3(0.0, 0.10, -0.59), Vector3(4.40, 0.20, 0.28), plinth)
	_add_local_box(architecture, "EntranceThresholdContinuous",
		Vector3(0.0, 0.16, -0.82), Vector3(4.54, 0.12, 0.44), plinth)
	var plinth_side_x: Array[float] = [-2.13, 2.13]
	for plinth_index: int in range(plinth_side_x.size()):
		_add_local_box(architecture, "FoundationPlinthSide_%02d" % plinth_index,
			Vector3(plinth_side_x[plinth_index], 0.10, 1.35),
			Vector3(0.24, 0.20, 4.60), plinth)
		_add_local_box(architecture, "FoundationPlinthCapSide_%02d" % plinth_index,
			Vector3(plinth_side_x[plinth_index], 0.21, 1.35),
			Vector3(0.28, 0.06, 4.64), plinth)
	_add_local_box(architecture, "FoundationPlinthRear",
		Vector3(0.0, 0.10, 3.65), Vector3(4.50, 0.20, 0.24), plinth)
	_add_local_box(architecture, "FoundationPlinthCapRear",
		Vector3(0.0, 0.21, 3.65), Vector3(4.54, 0.06, 0.28), plinth)
	_add_local_box(architecture, "UpperFacade_LeftPier",
		Vector3(-1.96, 4.90 - upper_storey_drop, -0.56),
		Vector3(0.30, 2.58, 0.20), plaster)
	_add_local_box(architecture, "UpperFacade_RightPier",
		Vector3(1.96, 4.90 - upper_storey_drop, -0.56),
		Vector3(0.30, 2.58, 0.20), plaster)
	_add_local_box(architecture, "UpperFacade_Back",
		Vector3(0.0, 4.90 - upper_storey_drop, -0.43),
		Vector3(3.64, 2.56, 0.12), interior)

	# Upper window wall: the facade faces local -Z, so positive local X appears
	# on the viewer's left. Put the screened bay there, followed by a broad
	# centre pane and a slightly narrower pane on the viewer's right.
	_add_local_box(architecture, "UpperGlass_Centre",
		Vector3(-0.045, 4.93 - upper_storey_drop, -0.61),
		Vector3(1.13, 2.08, 0.045), glass)
	_add_local_box(architecture, "UpperGlass_Right",
		Vector3(-1.26, 4.93 - upper_storey_drop, -0.61),
		Vector3(0.92, 2.08, 0.045), glass)
	_add_local_box(architecture, "UpperScreenShadow",
		Vector3(1.20, 4.93 - upper_storey_drop, -0.60),
		Vector3(1.04, 2.08, 0.04), glass)

	_add_yakitori_x_grain_box(architecture, "UpperFrame_Sill",
		Vector3(0.0, 3.78 - upper_storey_drop, -0.70),
		Vector3(3.74, 0.16, 0.16), cedar_upper)
	_add_yakitori_x_grain_box(architecture, "UpperFrame_Head",
		Vector3(0.0, 6.08 - upper_storey_drop, -0.70),
		Vector3(3.74, 0.18, 0.16), cedar_upper)
	var upper_frame_x: Array[float] = [-1.82, -0.70, 0.61, 1.82]
	var upper_frame_width: Array[float] = [0.18, 0.14, 0.14, 0.18]
	for frame_index: int in range(upper_frame_x.size()):
		_add_local_box(architecture, "UpperFrame_%02d" % frame_index,
			Vector3(upper_frame_x[frame_index], 4.93 - upper_storey_drop, -0.70),
			Vector3(upper_frame_width[frame_index], 2.46, 0.16), cedar_frame)
	for slat_index: int in range(8):
		var slat_x: float = 0.715 + float(slat_index) * 0.135
		_add_local_box(architecture, "UpperScreenSlat_%02d" % slat_index,
			Vector3(slat_x, 4.94 - upper_storey_drop, -0.79),
			Vector3(0.055, 2.12, 0.075), cedar_frame)

	# The retained authored canopy is now the single slim break between floors.
	# Lowering the new upper storey closes the former one-metre cladding belt while
	# leaving a narrow, believable timber curb above the flashing.

	# Storefront joinery is deliberately fine and shallow so it enriches the
	# authored sliders rather than rebuilding or covering them.
	_add_yakitori_x_grain_box(architecture, "StorefrontTransomRail",
		Vector3(0.0, 2.30, -0.735), Vector3(3.70, 0.075, 0.055), cedar_frame)
	var transom_positions: Array[float] = [-1.76, -0.60, 0.60, 1.76]
	for transom_index: int in range(transom_positions.size()):
		_add_local_box(architecture, "StorefrontTransom_%02d" % transom_index,
			Vector3(transom_positions[transom_index], 2.43, -0.74),
			Vector3(0.055, 0.25, 0.055), cedar_frame)
	_add_yakitori_x_grain_box(architecture, "StorefrontKickRail",
		Vector3(0.0, 0.49, -0.735), Vector3(3.72, 0.075, 0.06), cedar_frame)

	# Compact paired pull handles replace the long plain bars on the authored
	# sliders. Each handle has two flush rosettes, short stand-offs, and one
	# 240 mm round grip—the proportions shown in the material reference.
	var door_pull_x: Array[float] = [-0.18, 0.18]
	var door_pull_y: float = 1.28
	for pull_index: int in range(door_pull_x.size()):
		var pull_x: float = door_pull_x[pull_index]
		for mount_index: int in range(2):
			var mount_y: float = door_pull_y - 0.10 + float(mount_index) * 0.20
			_add_local_cylinder(
				architecture,
				"DoorPullMount_%02d_%02d" % [pull_index, mount_index],
				Vector3(pull_x, mount_y, -0.765),
				0.030,
				0.018,
				hardware_metal,
				Vector3(PI * 0.5, 0.0, 0.0)
			)
			_add_local_cylinder(
				architecture,
				"DoorPullStandoff_%02d_%02d" % [pull_index, mount_index],
				Vector3(pull_x, mount_y, -0.810),
				0.014,
				0.080,
				hardware_metal,
				Vector3(PI * 0.5, 0.0, 0.0)
			)
		_add_local_cylinder(
			architecture,
			"DoorPullGrip_%02d" % pull_index,
			Vector3(pull_x, door_pull_y, -0.850),
			0.018,
			0.240,
			hardware_metal
		)

	# Upper side ledgers visually lock the new level into the deep shell.
	var side_positions: Array[float] = [-2.13, 2.13]
	for side_index: int in range(side_positions.size()):
		_add_yakitori_z_grain_box(architecture, "SideLedgerLow_%02d" % side_index,
			Vector3(side_positions[side_index], 3.68 - upper_storey_drop, 1.50),
			Vector3(0.11, 0.16, 4.20), cedar_upper)
		_add_yakitori_z_grain_box(architecture, "SideLedgerHigh_%02d" % side_index,
			Vector3(side_positions[side_index], 6.18 - upper_storey_drop, 1.50),
			Vector3(0.11, 0.14, 4.20), cedar_upper)

	# Low-slope roof with a restrained cedar underside and slim metal-capped
	# front edge. The authored reference uses a shallow roof silhouette rather
	# than the earlier stack of heavy wood fascia boards.
	_add_local_box(architecture, "UpperRoofDeck",
		Vector3(0.0, 6.37 - upper_storey_drop, 1.48),
		Vector3(4.42, 0.14, 4.38), roof)
	_add_yakitori_x_grain_box(architecture, "UpperRoofFrontEave",
		Vector3(0.0, 6.31 - upper_storey_drop, -0.82),
		Vector3(4.58, 0.12, 0.34), cedar_eave)
	_add_yakitori_x_grain_box(architecture, "UpperRoofFascia",
		Vector3(0.0, 6.36 - upper_storey_drop, -1.00),
		Vector3(4.66, 0.12, 0.085), metal)
	_add_yakitori_x_grain_box(architecture, "UpperRoofFlashing",
		Vector3(0.0, 6.435 - upper_storey_drop, -0.975),
		Vector3(4.72, 0.045, 0.16), metal)

	# Two compact rear masonry piers rise above the roofline in the reference and
	# visually terminate the deeper side walls.
	var roof_parapet_x: Array[float] = [-1.92, 1.92]
	for parapet_index: int in range(roof_parapet_x.size()):
		_add_local_box(architecture, "RoofParapetPier_%02d" % parapet_index,
			Vector3(roof_parapet_x[parapet_index], 6.76 - upper_storey_drop, 2.98),
			Vector3(0.18, 0.64, 0.22), plaster)
		_add_local_box(architecture, "RoofParapetCap_%02d" % parapet_index,
			Vector3(roof_parapet_x[parapet_index], 7.10 - upper_storey_drop, 2.98),
			Vector3(0.22, 0.045, 0.26), metal)

	# Seat the low safety rail directly on the roof instead of leaving the old
	# posts floating above it. A centre post on each run keeps the thin profile
	# believable without making the roofline busy.
	var rail_post_y: float = 6.65 - upper_storey_drop
	var rail_top_y: float = 6.86 - upper_storey_drop
	var rail_post_x: Array[float] = [-1.72, 0.0, 1.72]
	for rail_index: int in range(rail_post_x.size()):
		_add_local_box(architecture, "RoofRailPostFront_%02d" % rail_index,
			Vector3(rail_post_x[rail_index], rail_post_y, -0.38),
			Vector3(0.055, 0.40, 0.055), metal)
		_add_local_box(architecture, "RoofRailPostRear_%02d" % rail_index,
			Vector3(rail_post_x[rail_index], rail_post_y, 2.86),
			Vector3(0.055, 0.40, 0.055), metal)
	_add_yakitori_x_grain_box(architecture, "RoofRailFront",
		Vector3(0.0, rail_top_y, -0.38), Vector3(3.50, 0.055, 0.055), metal)
	_add_yakitori_x_grain_box(architecture, "RoofRailRear",
		Vector3(0.0, rail_top_y, 2.86), Vector3(3.50, 0.055, 0.055), metal)
	var rail_side_x: Array[float] = [-1.72, 1.72]
	for rail_index: int in range(rail_side_x.size()):
		_add_local_box(architecture, "RoofRailPostSideMid_%02d" % rail_index,
			Vector3(rail_side_x[rail_index], rail_post_y, 1.24),
			Vector3(0.055, 0.40, 0.055), metal)
		_add_yakitori_z_grain_box(architecture, "RoofRailSide_%02d" % rail_index,
			Vector3(rail_side_x[rail_index], rail_top_y, 1.24),
			Vector3(0.055, 0.055, 3.24), metal)

	return architecture

func _replace_visual_test_storefront_with_yakitori_shop() -> void:
	if not commercial_test_corridor_mode:
		return

	var target: Dictionary = _find_visual_test_storefront_target()
	var old_root: Node3D = target.get("root") as Node3D
	var old_threshold: Node3D = target.get("threshold") as Node3D
	var old_lintel: Node3D = target.get("lintel") as Node3D
	if old_root == null or old_threshold == null or old_lintel == null:
		push_warning("v10.29a Yakitori replacement skipped: locked storefront was not found")
		return

	var replacement: Node3D = YakitoriShopBuildingScene.instantiate() as Node3D
	if replacement == null:
		push_error("v10.29a Yakitori replacement failed: authored building scene could not instantiate")
		return

	var authored_model: Node3D = replacement.get_node_or_null("Model") as Node3D
	if authored_model == null:
		replacement.queue_free()
		push_error("v10.29a Yakitori replacement failed: authored Model root is missing")
		return

	# Preserve the exact lot transform, but align the authored entrance to the
	# old procedural threshold. This keeps the 4.20 m building at scale 1 and
	# seats its façade on the established road edge without stretching it to the
	# wider procedural lot.
	var old_name: String = String(old_root.name)
	var old_transform: Transform3D = old_root.transform
	var old_threshold_position: Vector3 = old_threshold.position
	var old_lintel_position: Vector3 = old_lintel.position
	authored_model.position = Vector3(
		old_threshold_position.x,
		0.0,
		old_threshold_position.z - YAKITORI_SHOP_ENTRANCE_LOCAL_Z
	)

	# The generated shop may already own one budgeted interior light. Removing
	# the whole root must release that allocation as well as its geometry.
	var removed_interior_lights: int = 0
	for node: Node in old_root.find_children("*", "Light3D", true, false):
		if node.is_in_group("shinrai_interior_light"):
			removed_interior_lights += 1

	geometry_root.remove_child(old_root)
	old_root.queue_free()

	replacement.name = old_name + "_YakitoriShop"
	replacement.transform = old_transform
	replacement.set_meta("shinrai_facade_style", "heritage")
	replacement.set_meta("shinrai_authored_yakitori_shop", true)
	replacement.add_to_group("shinrai_authored_yakitori_shop")

	# Keep the two direct anchors consumed by the existing capped storefront
	# lighting systems. They are empty nodes only; no procedural façade or prop
	# geometry is rebuilt around the authored shell.
	var threshold_anchor: Node3D = Node3D.new()
	threshold_anchor.name = "StoreThreshold"
	threshold_anchor.position = old_threshold_position
	replacement.add_child(threshold_anchor)

	var lintel_anchor: Node3D = Node3D.new()
	lintel_anchor.name = "EntranceLintel"
	lintel_anchor.position = Vector3(
		old_lintel_position.x,
		2.30,
		old_threshold_position.z - 0.01
	)
	replacement.add_child(lintel_anchor)

	geometry_root.add_child(replacement)
	var architecture: Node3D = authored_model.find_child(
		"ProjectShinrai_YakitoriShop_ArtworkReplica_v5_ROOT", true, false
	) as Node3D
	if architecture == null:
		architecture = authored_model
	architecture.add_to_group("shinrai_yakitori_architecture")
	architecture.add_to_group("shinrai_yakitori_artwork_replica")

	if removed_interior_lights > 0:
		interior_light_count = maxi(0, interior_light_count - removed_interior_lights)
		shop_interior_light_count = maxi(0, shop_interior_light_count - removed_interior_lights)

	print(
		"v10.32a Yakitori artwork replica: installed %s + %s | V5 continuous plaster + closed upper roof junction + rebuilt thin storefront canopy | later-detail sockets ready | released interior lights %d" % [
			replacement.name,
			architecture.name,
			removed_interior_lights,
		]
	)

func _find_visual_test_storefront_target() -> Dictionary:
	var spawn_world: Vector3 = _cell_to_world(VISUAL_TEST_SPAWN_CELL, 0.0)
	# The locked camera faces east. Excluding thresholds well behind the player
	# prevents this diagnostic from silently attaching to a different shop on
	# the west side of the spawn if frontage generation changes later.
	var camera_forward: Vector3 = Vector3(1.0, 0.0, 0.0)
	var best_root: Node3D = null
	var best_threshold: Node3D = null
	var best_lintel: Node3D = null
	var best_distance: float = INF

	for child: Node in geometry_root.get_children():
		var building_root: Node3D = child as Node3D
		if building_root == null:
			continue
		var threshold: Node3D = building_root.get_node_or_null("StoreThreshold") as Node3D
		var lintel: Node3D = building_root.get_node_or_null("EntranceLintel") as Node3D
		if threshold == null or lintel == null:
			continue

		var offset: Vector3 = threshold.global_position - spawn_world
		var horizontal_offset: Vector3 = Vector3(offset.x, 0.0, offset.z)
		var distance_to_spawn: float = horizontal_offset.length()
		# The selected commercial frontage is the north wall of the test street
		# (negative world Z from the road centre). Prefer that exact wall so the
		# light always follows the storefront the fixed start view is judging.
		if threshold.global_position.z >= spawn_world.z - 0.15:
			continue
		if distance_to_spawn > VISUAL_TEST_STOREFRONT_LIGHT_MAX_DISTANCE:
			continue
		if distance_to_spawn > 0.001:
			var forward_dot: float = horizontal_offset.normalized().dot(camera_forward)
			if forward_dot < -0.20:
				continue
		if distance_to_spawn < best_distance:
			best_distance = distance_to_spawn
			best_root = building_root
			best_threshold = threshold
			best_lintel = lintel

	return {
		"root": best_root,
		"threshold": best_threshold,
		"lintel": best_lintel,
		"distance": best_distance,
	}

func _visual_test_storefront_fixture_anchor(
	building_root: Node3D,
	threshold: Node3D,
	lintel: Node3D
) -> Vector3:
	# Reuse the visible storefront's existing fixture/sign geometry as the
	# apparent source. Projecting box signs are checked first because the locked
	# start view's square storefront fixture reads as this kind of wall-mounted
	# luminous box. No fixture mesh or material is changed.
	var fixture_names: Array[String] = [
		"ProjectingSign",
		"YakitoriLantern",
		"ShopLantern",
		"RamenUnderEaveGlow",
		"IzakayaEntranceGlow",
		"ConvenienceWhiteBand",
		"MixedHeader",
		"RepairLintel",
	]
	for fixture_name: String in fixture_names:
		var fixture: Node3D = building_root.get_node_or_null(fixture_name) as Node3D
		if fixture == null:
			continue
		visual_test_storefront_fixture_target = fixture_name
		return Vector3(
			fixture.position.x,
			clampf(fixture.position.y, 1.95, 3.40),
			minf(fixture.position.z, threshold.position.z) - 0.18
		)

	visual_test_storefront_fixture_target = "EntranceLintel"
	return Vector3(
		lintel.position.x,
		2.24,
		minf(threshold.position.z, lintel.position.z) - 0.24
	)

func _build_yakitori_canopy_lights(building_root: Node3D) -> int:
	var architecture: Node3D = building_root.find_child(
		"ProjectShinrai_YakitoriShop_ArtworkReplica_v5_ROOT", true, false
	) as Node3D
	if architecture == null:
		architecture = building_root.find_child(
			"ProjectShinrai_YakitoriShop_ArtworkReplica_v4_ROOT", true, false
		) as Node3D
	if architecture == null:
		architecture = building_root.find_child(
			"ProjectShinrai_YakitoriShop_ArtworkReplica_v3_ROOT", true, false
		) as Node3D
	if architecture == null:
		architecture = building_root.find_child(
			"YakitoriArchitecture_v10_29a", true, false
		) as Node3D
	if architecture == null:
		return 0

	var available_slots: int = maxi(0, MAX_STREET_LIGHTS - street_light_count)
	var light_total: int = mini(YAKITORI_CANOPY_LIGHT_COUNT, available_slots)
	var light_x_positions: Array[float] = [-1.34, 0.0, 1.34]
	for light_index: int in range(light_total):
		var light_parent: Node3D = building_root.find_child(
			"SOCKET_CanopyLight_%02d" % light_index, true, false
		) as Node3D
		if light_parent == null:
			light_parent = architecture

		var light: OmniLight3D = OmniLight3D.new()
		light.name = "YakitoriCanopyDownlight_%02d" % light_index
		if light_parent == architecture:
			var light_x: float = light_x_positions[light_index]
			light.position = Vector3(light_x, 2.49, -1.16)
		else:
			light.position = Vector3.ZERO
		light.light_color = Color(1.0, 0.72, 0.47)
		light.light_energy = YAKITORI_CANOPY_LIGHT_ENERGY
		light.omni_range = YAKITORI_CANOPY_LIGHT_RANGE
		light.omni_attenuation = 1.72
		light.shadow_enabled = false
		light_parent.add_child(light)
		light.add_to_group("shinrai_street_light")
		light.add_to_group("shinrai_visual_test_storefront_light")
		light.add_to_group("shinrai_yakitori_canopy_light")
		if visual_test_storefront_light == null:
			visual_test_storefront_light = light
	return light_total

func _build_visual_test_storefront_lamp_coverage() -> void:
	if not commercial_test_corridor_mode:
		return
	if street_light_count >= MAX_STREET_LIGHTS:
		push_warning("v10.25o storefront lamp coverage skipped: street-light cap already full")
		return

	var target: Dictionary = _find_visual_test_storefront_target()
	var building_root: Node3D = target.get("root") as Node3D
	var threshold: Node3D = target.get("threshold") as Node3D
	var lintel: Node3D = target.get("lintel") as Node3D
	if building_root == null or threshold == null or lintel == null:
		push_warning("v10.25o storefront lamp coverage skipped: no qualifying storefront beside locked start")
		return

	if bool(building_root.get_meta("shinrai_authored_yakitori_shop", false)):
		var canopy_light_count: int = _build_yakitori_canopy_lights(building_root)
		street_light_count += canopy_light_count
		visual_test_storefront_light_target = building_root.name
		visual_test_storefront_fixture_target = "Three artwork-matched recessed canopy downlights"
		print(
			"v10.32a Yakitori canopy lights: %d authored sockets | street pool %d/%d" % [
				canopy_light_count,
				street_light_count,
				MAX_STREET_LIGHTS,
			]
		)
		return

	# Do not add or move any fixture geometry. Place a small shadowless Omni just
	# outside the existing entrance/lamp plane so the same visible square fixture
	# reads as a light source and reaches wall + threshold + a compact pavement
	# patch. Parenting to the building preserves the facade's existing yaw.
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "StartingStorefrontLampLight"
	light.position = _visual_test_storefront_fixture_anchor(building_root, threshold, lintel)
	light.light_color = Color(1.0, 0.72, 0.48)
	light.light_energy = VISUAL_TEST_STOREFRONT_LIGHT_ENERGY
	light.omni_range = VISUAL_TEST_STOREFRONT_LIGHT_RANGE
	light.omni_attenuation = 1.45
	light.shadow_enabled = false
	building_root.add_child(light)
	light.add_to_group("shinrai_street_light")
	light.add_to_group("shinrai_visual_test_storefront_light")

	visual_test_storefront_light = light
	visual_test_storefront_light_target = building_root.name
	street_light_count += 1

	print(
		"v10.25o storefront lamp allocation: %s/%s | target distance %.2f m | energy %.2f | range %.1f m | street pool %d/%d" % [
			visual_test_storefront_light_target,
			visual_test_storefront_fixture_target,
			float(target.get("distance", INF)),
			light.light_energy,
			light.omni_range,
			street_light_count,
			MAX_STREET_LIGHTS,
		]
	)

func _under_eave_led_candidate_style_penalty(building_root: Node3D) -> float:
	# Light 03 belongs to the upgraded city layer. Fully contemporary frontage
	# gets first priority; renovated shells are a close fallback. Heritage shops
	# remain reserved for Light 02.
	if building_root.is_in_group("shinrai_contemporary_storefront"):
		return 0.0
	if building_root.is_in_group("shinrai_renovated_storefront"):
		return 0.8
	return INF

func _under_eave_led_mount_data(building_root: Node3D) -> Dictionary:
	# Both upgraded shopfront kits already provide a thin manufactured canopy.
	# Light 03 is authored with its root exactly on the underside roof plane and
	# its recessed body extending +Y, so seating it on the BoxMesh underside
	# preserves the real 87 mm fixture scale without a visible mounting plate.
	var canopy: MeshInstance3D = building_root.get_node_or_null("ContemporaryCanopy") as MeshInstance3D
	var style_name: String = "contemporary"
	if canopy == null:
		canopy = building_root.get_node_or_null("RenovatedCanopy") as MeshInstance3D
		style_name = "renovated"
	if canopy == null:
		return {}

	var underside_y: float = canopy.position.y - 0.04
	var canopy_box: BoxMesh = canopy.mesh as BoxMesh
	if canopy_box != null:
		underside_y = canopy.position.y - canopy_box.size.y * 0.5

	# Bias the small downlight slightly away from the service/address hardware so
	# it reads as an entrance practical, not as another indicator light.
	var service_node: Node3D = building_root.get_node_or_null("ContemporaryServiceSpine") as Node3D
	if service_node == null:
		service_node = building_root.get_node_or_null("RenovatedAddressPanelBacking") as Node3D
	var mount_x: float = 0.0
	if service_node != null:
		mount_x = clampf(-service_node.position.x * 0.34, -0.58, 0.58)

	return {
		"position": Vector3(mount_x, underside_y, canopy.position.z),
		"support": canopy.name,
		"style": style_name,
	}

func _configure_under_eave_led_fixture_geometry(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.visibility_range_end = UNDER_EAVE_LED_FIXTURE_VISIBILITY_RANGE
		geometry.visibility_range_end_margin = 5.0
	if node is CollisionObject3D:
		var collision_object: CollisionObject3D = node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	for child: Node in node.get_children():
		_configure_under_eave_led_fixture_geometry(child)

func _add_under_eave_led_fixture(building_root: Node3D, fixture_index: int) -> bool:
	if active_under_eave_led_count >= MAX_ACTIVE_UNDER_EAVE_LED_LIGHTS:
		return false
	if street_light_count >= MAX_STREET_LIGHTS:
		return false

	var mount_data: Dictionary = _under_eave_led_mount_data(building_root)
	if mount_data.is_empty():
		return false

	var fixture_root: Node3D = UnderEaveLEDScene.instantiate() as Node3D
	if fixture_root == null:
		push_warning("v10.26e Light 03 fixture instantiate failed for %s" % building_root.name)
		return false
	fixture_root.name = "Light03UnderEaveLED%d" % fixture_index
	fixture_root.position = mount_data.get("position", Vector3.ZERO)
	building_root.add_child(fixture_root)
	fixture_root.add_to_group("shinrai_under_eave_led_fixture")
	_configure_under_eave_led_fixture_geometry(fixture_root)

	var socket_light: Node3D = fixture_root.find_child("SOCKET_Light", true, false) as Node3D
	var socket_aim: Node3D = fixture_root.find_child("SOCKET_Aim", true, false) as Node3D
	if socket_light == null or socket_aim == null:
		push_warning("v10.26e Light 03 sockets missing on %s" % building_root.name)
		fixture_root.queue_free()
		return false

	# The supplied asset contract places SOCKET_Aim one metre below
	# SOCKET_Light along local -Y. SpotLight3D emits along local -Z, therefore a
	# -90 degree local-X rotation follows the authored direction exactly.
	var light: SpotLight3D = SpotLight3D.new()
	light.name = "UnderEaveLEDLight"
	light.position = Vector3.ZERO
	light.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	# v10.26e visibility calibration: preserve the supplied warm LED colour,
	# but drive a stronger/wider practical pool so the tiny recessed fixture
	# reads from the FPS camera through its effect on wall, threshold and road.
	light.light_color = Color(0.9804, 0.8353, 0.5255)
	light.light_energy = UNDER_EAVE_LED_LIGHT_ENERGY
	light.light_specular = 0.46
	light.spot_range = UNDER_EAVE_LED_LIGHT_RANGE
	light.spot_angle = UNDER_EAVE_LED_LIGHT_ANGLE_DEG
	light.spot_attenuation = 1.05
	light.spot_angle_attenuation = 0.82
	light.shadow_enabled = false
	socket_light.add_child(light)
	light.add_to_group("shinrai_street_light")
	light.add_to_group("shinrai_under_eave_led_light")

	building_root.set_meta("shinrai_has_under_eave_led", true)
	active_under_eave_led_count += 1
	street_light_count += 1
	print(
		"v10.26e Light 03 allocation: %s/%s | support=%s | style=%s | energy=%.2f | range=%.1f m | angle=%.1f deg | street pool %d/%d" % [
			building_root.name,
			fixture_root.name,
			str(mount_data.get("support", "canopy")),
			str(mount_data.get("style", "upgraded")),
			light.light_energy,
			light.spot_range,
			light.spot_angle,
			street_light_count,
			MAX_STREET_LIGHTS,
		]
	)
	return true

func _build_commercial_under_eave_led_lighting() -> void:
	active_under_eave_led_count = 0
	if not commercial_test_corridor_mode or street_light_count >= MAX_STREET_LIGHTS:
		return

	var spawn_world: Vector3 = _cell_to_world(VISUAL_TEST_SPAWN_CELL, 0.0)
	var corridor_a: Vector3 = _cell_to_world(VISUAL_TEST_CORRIDOR_START, 0.0)
	var corridor_b: Vector3 = _cell_to_world(VISUAL_TEST_CORRIDOR_END, 0.0)
	var corridor_min_x: float = minf(corridor_a.x, corridor_b.x) - TILE_SIZE
	var corridor_max_x: float = maxf(corridor_a.x, corridor_b.x) + TILE_SIZE
	var selected_roots: Dictionary = {}
	var selected_positions: Array[Vector3] = []
	var requested_count: int = mini(
		MAX_ACTIVE_UNDER_EAVE_LED_LIGHTS,
		MAX_STREET_LIGHTS - street_light_count
	)

	for fixture_index: int in range(requested_count):
		var best_root: Node3D = null
		var best_threshold: Node3D = null
		var best_score: float = INF

		for child: Node in geometry_root.get_children():
			var building_root: Node3D = child as Node3D
			if building_root == null or selected_roots.has(building_root.name):
				continue
			if building_root.name == visual_test_storefront_light_target:
				# Keep the existing starting-storefront diagnostic source isolated.
				continue

			var style_penalty: float = _under_eave_led_candidate_style_penalty(building_root)
			if is_inf(style_penalty):
				continue
			var mount_data: Dictionary = _under_eave_led_mount_data(building_root)
			if mount_data.is_empty():
				continue
			var threshold: Node3D = building_root.get_node_or_null("StoreThreshold") as Node3D
			if threshold == null:
				continue

			var delta: Vector3 = threshold.global_position - spawn_world
			var horizontal_distance: float = Vector2(delta.x, delta.z).length()
			var score: float = horizontal_distance + style_penalty * 2.0

			# Keep the approval pair on the deterministic north commercial wall.
			if threshold.global_position.z < spawn_world.z - 0.15:
				score -= 7.0
			else:
				score += 20.0
			if threshold.global_position.x >= corridor_min_x and threshold.global_position.x <= corridor_max_x:
				score -= 6.0
			else:
				score += 16.0

			for used_position: Vector3 in selected_positions:
				var spacing_delta: Vector3 = threshold.global_position - used_position
				if Vector2(spacing_delta.x, spacing_delta.z).length() < 5.2:
					score += 14.0

			if score < best_score:
				best_score = score
				best_root = building_root
				best_threshold = threshold

		if best_root == null or best_threshold == null:
			break
		selected_roots[best_root.name] = true
		selected_positions.append(best_threshold.global_position)
		_add_under_eave_led_fixture(best_root, fixture_index)

	print(
		"v10.26e Light 03 under-eave LEDs active: %d / %d requested | street pool %d/%d" % [
			active_under_eave_led_count,
			MAX_ACTIVE_UNDER_EAVE_LED_LIGHTS,
			street_light_count,
			MAX_STREET_LIGHTS,
		]
	)

func _modern_wall_light_candidate_style_penalty(building_root: Node3D) -> float:
	# The new fixture is infrastructure for the upgraded city layer, not a
	# replacement for heritage shop lighting. Contemporary new-builds get first
	# priority, renovated shells second, all other façades are ineligible.
	if building_root.is_in_group("shinrai_contemporary_storefront"):
		return 0.0
	if building_root.is_in_group("shinrai_renovated_storefront"):
		return 1.2
	return INF

func _modern_wall_light_mount_data(building_root: Node3D) -> Dictionary:
	var threshold: Node3D = building_root.get_node_or_null("StoreThreshold") as Node3D
	var lintel: Node3D = building_root.get_node_or_null("EntranceLintel") as Node3D
	if threshold == null or lintel == null:
		return {}

	# Mount opposite the existing service/address stack so the fixture reads as
	# a deliberate retrofit/new-build utility rather than another sign. Local
	# -Z is street-facing for every procedural shop before the building yaw is
	# applied, so the same assembly works on every side of the grid.
	var service_node: Node3D = building_root.get_node_or_null("ContemporaryServiceSpine") as Node3D
	if service_node == null:
		service_node = building_root.get_node_or_null("RenovatedAddressPanelBacking") as Node3D
	var mount_x: float = -0.82
	if service_node != null:
		mount_x = -service_node.position.x * 0.78
	mount_x = clampf(mount_x, -1.45, 1.45)

	var facade_reference_z: float = minf(threshold.position.z, lintel.position.z)
	return {
		"position": Vector3(mount_x, 2.33, facade_reference_z - 0.16),
		"facade_z": facade_reference_z,
		"style": str(building_root.get_meta("shinrai_facade_style", "modern")),
	}

func _set_modern_wall_fixture_mesh_rules(mesh: MeshInstance3D) -> void:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visibility_range_end = MODERN_WALL_LIGHT_FIXTURE_VISIBILITY_RANGE
	mesh.visibility_range_end_margin = 6.0

func _add_modern_wall_light_fixture(building_root: Node3D, fixture_index: int) -> bool:
	if active_modern_wall_light_count >= MAX_ACTIVE_MODERN_WALL_LIGHTS:
		return false
	if street_light_count >= MAX_STREET_LIGHTS:
		return false

	var mount_data: Dictionary = _modern_wall_light_mount_data(building_root)
	if mount_data.is_empty():
		return false
	var anchor: Vector3 = mount_data.get("position", Vector3.ZERO)

	# Compact municipal/commercial LED fixture: wall plate, short engineered arm,
	# slim aluminium housing, recessed diffuser and a tiny occupancy/daylight
	# sensor. It is deliberately geometry-light so the final authored lamp asset
	# can replace this assembly later without changing the allocation rules.
	var fixture_root: Node3D = Node3D.new()
	fixture_root.name = "ModernWallLamp%d" % fixture_index
	fixture_root.position = anchor
	building_root.add_child(fixture_root)
	fixture_root.add_to_group("shinrai_modern_wall_lamp_fixture")

	var plate: MeshInstance3D = _add_local_box(
		fixture_root, "MountPlate", Vector3(0.0, 0.0, 0.00),
		Vector3(0.18, 0.28, 0.055), mat_contemporary_panel_dark
	)
	var arm: MeshInstance3D = _add_local_box(
		fixture_root, "ShortArm", Vector3(0.0, 0.03, -0.115),
		Vector3(0.075, 0.075, 0.20), mat_black_metal
	)
	var housing: MeshInstance3D = _add_local_box(
		fixture_root, "LEDHousing", Vector3(0.0, 0.025, -0.255),
		Vector3(0.48, 0.105, 0.24), mat_contemporary_panel_dark
	)
	var diffuser: MeshInstance3D = _add_local_box(
		fixture_root, "LEDDiffuser", Vector3(0.0, -0.038, -0.285),
		Vector3(0.36, 0.018, 0.145), mat_contemporary_led
	)
	var sensor: MeshInstance3D = _add_local_box(
		fixture_root, "Sensor", Vector3(0.145, -0.010, -0.382),
		Vector3(0.075, 0.045, 0.040), mat_soft_white
	)
	for mesh: MeshInstance3D in [plate, arm, housing, diffuser, sensor]:
		_set_modern_wall_fixture_mesh_rules(mesh)

	# SpotLight3D emits along local -Z. A -70 degree X tilt sends the beam mostly
	# downward while retaining a small streetward component, giving the wall,
	# threshold and nearby asphalt a readable pool rather than a floating glow.
	var light: SpotLight3D = SpotLight3D.new()
	light.name = "ModernWallLampLight"
	light.position = Vector3(0.0, -0.085, -0.305)
	light.rotation = Vector3(deg_to_rad(-70.0), 0.0, 0.0)
	light.light_color = Color(1.0, 0.91, 0.78)
	light.light_energy = MODERN_WALL_LIGHT_ENERGY
	light.light_specular = 0.42
	light.spot_range = MODERN_WALL_LIGHT_RANGE
	light.spot_angle = MODERN_WALL_LIGHT_ANGLE_DEG
	light.spot_attenuation = 1.30
	light.spot_angle_attenuation = 1.05
	light.shadow_enabled = false
	fixture_root.add_child(light)
	light.add_to_group("shinrai_street_light")
	light.add_to_group("shinrai_modern_wall_lamp_light")

	active_modern_wall_light_count += 1
	street_light_count += 1
	print(
		"v10.26c modern wall lamp allocation: %s/%s | style=%s | energy=%.2f | range=%.1f m | angle=%.1f deg | street pool %d/%d" % [
			building_root.name,
			fixture_root.name,
			str(mount_data.get("style", "modern")),
			light.light_energy,
			light.spot_range,
			light.spot_angle,
			street_light_count,
			MAX_STREET_LIGHTS,
		]
	)
	return true

func _build_commercial_modern_wall_lighting() -> void:
	active_modern_wall_light_count = 0
	if not commercial_test_corridor_mode or street_light_count >= MAX_STREET_LIGHTS:
		return

	var spawn_world: Vector3 = _cell_to_world(VISUAL_TEST_SPAWN_CELL, 0.0)
	var corridor_a: Vector3 = _cell_to_world(VISUAL_TEST_CORRIDOR_START, 0.0)
	var corridor_b: Vector3 = _cell_to_world(VISUAL_TEST_CORRIDOR_END, 0.0)
	var corridor_min_x: float = minf(corridor_a.x, corridor_b.x) - TILE_SIZE
	var corridor_max_x: float = maxf(corridor_a.x, corridor_b.x) + TILE_SIZE
	var selected_roots: Dictionary = {}
	var selected_positions: Array[Vector3] = []
	var requested_count: int = mini(
		MAX_ACTIVE_MODERN_WALL_LIGHTS,
		MAX_STREET_LIGHTS - street_light_count
	)

	for fixture_index: int in range(requested_count):
		var best_root: Node3D = null
		var best_threshold: Node3D = null
		var best_score: float = INF

		for child: Node in geometry_root.get_children():
			var building_root: Node3D = child as Node3D
			if building_root == null or selected_roots.has(building_root.name):
				continue
			if building_root.name == visual_test_storefront_light_target:
				# Keep the diagnostic source isolated so this pass is easy to
				# compare against v10.26b from exactly the same starting frame.
				continue
			if bool(building_root.get_meta("shinrai_has_under_eave_led", false)):
				# Retained for future use: never stack the wall fixture on a
				# storefront already carrying the recessed Light 03 practical.
				continue

			var style_penalty: float = _modern_wall_light_candidate_style_penalty(building_root)
			if is_inf(style_penalty):
				continue
			var threshold: Node3D = building_root.get_node_or_null("StoreThreshold") as Node3D
			if threshold == null:
				continue

			var delta: Vector3 = threshold.global_position - spawn_world
			var horizontal_distance: float = Vector2(delta.x, delta.z).length()
			var score: float = horizontal_distance + style_penalty * 2.0

			# Keep both approval fixtures on the north commercial wall of the
			# deterministic corridor. Other streets stay untouched in v10.26c.
			if threshold.global_position.z < spawn_world.z - 0.15:
				score -= 7.0
			else:
				score += 20.0
			if threshold.global_position.x >= corridor_min_x and threshold.global_position.x <= corridor_max_x:
				score -= 6.0
			else:
				score += 16.0

			for used_position: Vector3 in selected_positions:
				var spacing_delta: Vector3 = threshold.global_position - used_position
				if Vector2(spacing_delta.x, spacing_delta.z).length() < 5.2:
					score += 14.0

			if score < best_score:
				best_score = score
				best_root = building_root
				best_threshold = threshold

		if best_root == null or best_threshold == null:
			break
		selected_roots[best_root.name] = true
		selected_positions.append(best_threshold.global_position)
		_add_modern_wall_light_fixture(best_root, fixture_index)

	print(
		"v10.26c modern wall lamps active: %d / %d requested | street pool %d/%d" % [
			active_modern_wall_light_count,
			MAX_ACTIVE_MODERN_WALL_LIGHTS,
			street_light_count,
			MAX_STREET_LIGHTS,
		]
	)

func _eave_spot_candidate_style_penalty(building_root: Node3D) -> float:
	# Prefer the traditional/mixed storefronts that visually match the concept
	# sheet, but allow other active shopfronts as deterministic fallbacks so the
	# integration does not silently disappear if one shop archetype changes.
	if building_root.get_node_or_null("RamenAwning") != null:
		return 0.0
	if building_root.get_node_or_null("MixedAwning") != null:
		return 0.4
	if building_root.get_node_or_null("IzakayaHeader") != null:
		return 1.6
	if building_root.get_node_or_null("RepairLintel") != null:
		return 3.6
	if building_root.get_node_or_null("ConvenienceBand") != null:
		return 5.0
	return 8.0

func _eave_spot_mount_data(building_root: Node3D) -> Dictionary:
	# Where a genuine deep storefront awning exists, seat the imported ceiling
	# rose directly against its underside. Otherwise add one very small dark
	# mounting shelf above the entrance so the fixture never floats off a wall.
	for support_name: String in ["RamenAwning", "MixedAwning"]:
		var support: Node3D = building_root.get_node_or_null(support_name) as Node3D
		if support == null:
			continue
		return {
			"position": Vector3(0.0, support.position.y - 0.060, support.position.z),
			"rotation": support.rotation,
			"support": support_name,
			"needs_plate": false,
		}

	var threshold: Node3D = building_root.get_node_or_null("StoreThreshold") as Node3D
	var lintel: Node3D = building_root.get_node_or_null("EntranceLintel") as Node3D
	if threshold == null or lintel == null:
		return {}

	var facade_reference_z: float = minf(threshold.position.z, lintel.position.z)
	return {
		"position": Vector3(0.0, 2.48, facade_reference_z - 0.22),
		"rotation": Vector3.ZERO,
		"support": "EaveSpotMountShelf",
		"needs_plate": true,
	}

func _configure_eave_spot_fixture_geometry(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.visibility_range_end = EAVE_SPOT_FIXTURE_VISIBILITY_RANGE
		geometry.visibility_range_end_margin = 6.0
	if node is CollisionObject3D:
		var collision_object: CollisionObject3D = node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	for child: Node in node.get_children():
		_configure_eave_spot_fixture_geometry(child)

func _add_eave_spot_fixture(building_root: Node3D, fixture_index: int) -> bool:
	if active_eave_spot_count >= MAX_ACTIVE_EAVE_SPOT_LIGHTS:
		return false
	if street_light_count >= MAX_STREET_LIGHTS:
		return false

	var mount_data: Dictionary = _eave_spot_mount_data(building_root)
	if mount_data.is_empty():
		return false
	var mount_position: Vector3 = mount_data.get("position", Vector3.ZERO)

	if bool(mount_data.get("needs_plate", false)):
		# The shelf is intentionally tiny and dark: it reads as part of the
		# fixture installation, not as a new procedural awning design.
		_add_local_box(
			building_root,
			"EaveSpotMountShelf%d" % fixture_index,
			mount_position + Vector3(0.0, 0.025, 0.0),
			Vector3(0.42, 0.05, 0.42),
			mat_black_metal
		)

	var fixture_root: Node3D = EaveSpotScene.instantiate() as Node3D
	if fixture_root == null:
		push_warning("v10.25s Light 02 v3 fixture instantiate failed for %s" % building_root.name)
		return false
	fixture_root.name = "Light02EaveSpot%d" % fixture_index
	fixture_root.position = mount_position
	fixture_root.rotation = mount_data.get("rotation", Vector3.ZERO)
	building_root.add_child(fixture_root)
	fixture_root.add_to_group("shinrai_eave_spot_fixture")
	_configure_eave_spot_fixture_geometry(fixture_root)

	var socket_light: Node3D = fixture_root.find_child("SOCKET_Light", true, false) as Node3D
	var socket_aim: Node3D = fixture_root.find_child("SOCKET_Aim", true, false) as Node3D
	if socket_light == null or socket_aim == null:
		push_warning("v10.25s Light 02 v3 sockets missing on %s" % building_root.name)
		fixture_root.queue_free()
		return false

	# The supplied Light 02 v3 contract places SOCKET_Aim exactly one metre below
	# SOCKET_Light. SpotLight3D emits along local -Z, so -90 degrees around X
	# follows the authored socket direction without altering the fixture model.
	var light: SpotLight3D = SpotLight3D.new()
	light.name = "EaveSpotLight"
	light.position = Vector3.ZERO
	light.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	light.light_color = Color(1.0, 0.70, 0.43)
	light.light_energy = EAVE_SPOT_LIGHT_ENERGY
	light.light_specular = 0.35
	light.spot_range = EAVE_SPOT_LIGHT_RANGE
	light.spot_angle = EAVE_SPOT_LIGHT_ANGLE_DEG
	light.spot_attenuation = 1.35
	light.spot_angle_attenuation = 1.10
	light.shadow_enabled = false
	socket_light.add_child(light)
	light.add_to_group("shinrai_street_light")
	light.add_to_group("shinrai_eave_spot_light")

	active_eave_spot_count += 1
	street_light_count += 1
	print(
		"v10.25s Light 02 v3 allocation: %s/%s | support=%s | energy=%.2f | range=%.1f m | angle=%.1f deg | street pool %d/%d" % [
			building_root.name,
			fixture_root.name,
			str(mount_data.get("support", "unknown")),
			light.light_energy,
			light.spot_range,
			light.spot_angle,
			street_light_count,
			MAX_STREET_LIGHTS,
		]
	)
	return true

func _build_commercial_eave_spot_lighting() -> void:
	active_eave_spot_count = 0
	if street_light_count >= MAX_STREET_LIGHTS:
		return

	var spawn_world: Vector3 = _cell_to_world(VISUAL_TEST_SPAWN_CELL, 0.0)
	var corridor_a: Vector3 = _cell_to_world(VISUAL_TEST_CORRIDOR_START, 0.0)
	var corridor_b: Vector3 = _cell_to_world(VISUAL_TEST_CORRIDOR_END, 0.0)
	var corridor_min_x: float = minf(corridor_a.x, corridor_b.x) - TILE_SIZE
	var corridor_max_x: float = maxf(corridor_a.x, corridor_b.x) + TILE_SIZE
	var selected_roots: Dictionary = {}
	var selected_positions: Array[Vector3] = []
	var requested_count: int = mini(
		MAX_ACTIVE_EAVE_SPOT_LIGHTS,
		MAX_STREET_LIGHTS - street_light_count
	)

	for fixture_index: int in range(requested_count):
		var best_root: Node3D = null
		var best_threshold: Node3D = null
		var best_score: float = INF

		for child: Node in geometry_root.get_children():
			var building_root: Node3D = child as Node3D
			if building_root == null or selected_roots.has(building_root.name):
				continue
			if building_root.name == visual_test_storefront_light_target:
				# Keep the existing square-lamp diagnostic storefront visually
				# distinct instead of stacking two real-time lights together.
				continue
			if (
				building_root.is_in_group("shinrai_renovated_storefront")
				or building_root.is_in_group("shinrai_contemporary_storefront")
			):
				# v10.26c: the bell/eave fixture is now reserved for preserved
				# heritage frontage; upgraded buildings use the neutral wall LED.
				continue

			var threshold: Node3D = building_root.get_node_or_null("StoreThreshold") as Node3D
			var lintel: Node3D = building_root.get_node_or_null("EntranceLintel") as Node3D
			if threshold == null or lintel == null:
				continue

			var delta: Vector3 = threshold.global_position - spawn_world
			var horizontal_distance: float = Vector2(delta.x, delta.z).length()
			var score: float = horizontal_distance + _eave_spot_candidate_style_penalty(building_root) * 2.0

			# Strongly prefer the north commercial wall of the locked corridor,
			# matching the concept-art test street, then use nearby shops as
			# fallbacks instead of depending on new random choices.
			if threshold.global_position.z < spawn_world.z - 0.15:
				score -= 7.0
			else:
				score += 7.0
			if threshold.global_position.x >= corridor_min_x and threshold.global_position.x <= corridor_max_x:
				score -= 5.0
			else:
				score += 5.0

			for used_position: Vector3 in selected_positions:
				var spacing_delta: Vector3 = threshold.global_position - used_position
				if Vector2(spacing_delta.x, spacing_delta.z).length() < 5.0:
					score += 12.0

			if score < best_score:
				best_score = score
				best_root = building_root
				best_threshold = threshold

		if best_root == null or best_threshold == null:
			break

		selected_roots[best_root.name] = true
		selected_positions.append(best_threshold.global_position)
		_add_eave_spot_fixture(best_root, fixture_index)

	print(
		"v10.25s Light 02 v3 eave spots active: %d / %d requested | street pool %d/%d" % [
			active_eave_spot_count,
			MAX_ACTIVE_EAVE_SPOT_LIGHTS,
			street_light_count,
			MAX_STREET_LIGHTS,
		]
	)

func _build_street_furniture() -> void:
	var serial: int = 0
	var placements: Array[Vector3] = []
	# Deterministic clusters on commercial/traditional side streets.
	var cells: Array[Vector2i] = [
		Vector2i(23, 16), Vector2i(30, 16), Vector2i(16, 22), Vector2i(36, 30),
		Vector2i(22, 36), Vector2i(31, 36), Vector2i(16, 41), Vector2i(36, 11)
	]
	for cell: Vector2i in cells:
		var world: Vector3 = _cell_to_world(cell, 0.0)
		var offset: Vector3 = Vector3.ZERO
		var yaw: float = 0.0
		if _is_road_axis(cell.x):
			offset = Vector3((float(_road_half_width(cell.x)) + 0.72) * TILE_SIZE, 0.0, 0.0)
			yaw = -PI * 0.5
		else:
			offset = Vector3(0.0, 0.0, (float(_road_half_width(cell.y)) + 0.72) * TILE_SIZE)
			yaw = PI
		placements.append(world + offset)
		_add_vending_machine(world + offset, yaw, serial)
		serial += 1

	# Narrow bollards and utility boxes make otherwise empty corners believable.
	for road_center: int in [16, 26, 36]:
		var corner: Vector3 = _cell_to_world(Vector2i(road_center, 26), 0.0)
		var edge: float = (float(_road_half_width(road_center)) + 0.68) * TILE_SIZE
		for side: float in [-1.0, 1.0]:
			_add_local_cylinder(decoration_root, "Bollard", corner + Vector3(edge * side, 0.36, -4.1),
				0.075, 0.72, mat_black_metal)

func _add_vending_machine(position_value: Vector3, yaw: float, serial: int) -> void:
	var root: Node3D = Node3D.new()
	root.name = "VendingMachine%d" % serial
	root.position = position_value
	root.rotation.y = yaw
	decoration_root.add_child(root)
	_add_local_box(root, "Body", Vector3(0.0, 0.95, 0.0),
		Vector3(0.92, 1.90, 0.62), mat_soft_white)
	_add_local_box(root, "Display", Vector3(0.0, 1.22, -0.325),
		Vector3(0.70, 0.82, 0.045), mat_window_blue)
	_add_local_box(root, "Payment", Vector3(0.25, 0.68, -0.34),
		Vector3(0.18, 0.28, 0.06), mat_black_metal)
	_add_local_box(root, "Pickup", Vector3(0.0, 0.30, -0.34),
		Vector3(0.46, 0.18, 0.06), mat_black_metal)
	_add_local_box(root, "Header", Vector3(0.0, 1.80, -0.34),
		Vector3(0.72, 0.16, 0.05), mat_neon_blue if serial % 2 == 0 else mat_neon_red)

func _build_vans() -> void:
	for van_index: int in range(van_cells.size()):
		_build_kei_van(
			_cell_to_world(van_cells[van_index], 0.0),
			van_vertical[van_index],
			van_index
		)

func _build_kei_van(position_value: Vector3, vertical: bool, van_index: int) -> void:
	var van: StaticBody3D = StaticBody3D.new()
	van.name = "AbandonedKeiVan%d" % van_index
	van.position = position_value
	van.rotation.y = 0.0 if vertical else PI * 0.5
	van.collision_layer = 1
	van.collision_mask = 0
	static_root.add_child(van)

	# Closer to a Japanese kei microvan: narrow body, short overall length,
	# high roof and almost vertical sides rather than a generic full-size van.
	var van_body_mat: StandardMaterial3D = _material(
		Color(0.52, 0.54, 0.52) if van_index == 0 else Color(0.26, 0.29, 0.31),
		0.05,
		0.72
	)
	_add_local_box(van, "LowerBody", Vector3(0.0, 0.62, 0.0), Vector3(1.48, 0.94, 3.42), van_body_mat)
	_add_local_box(van, "UpperBody", Vector3(0.0, 1.36, 0.12), Vector3(1.44, 0.86, 2.92), van_body_mat)
	_add_local_box(van, "Roof", Vector3(0.0, 1.84, 0.14), Vector3(1.46, 0.12, 3.02), van_body_mat)
	_add_local_box(van, "Windshield", Vector3(0.0, 1.47, -1.48), Vector3(1.20, 0.58, 0.05), mat_glass,
		Vector3(deg_to_rad(-8.0), 0.0, 0.0))
	_add_local_box(van, "RearWindow", Vector3(0.0, 1.45, 1.59), Vector3(1.08, 0.50, 0.05), mat_glass)
	for side: float in [-1.0, 1.0]:
		_add_local_box(van, "FrontSideWindow", Vector3(0.745 * side, 1.45, -0.78),
			Vector3(0.05, 0.54, 0.68), mat_glass)
		_add_local_box(van, "SlidingDoorWindow", Vector3(0.745 * side, 1.43, 0.48),
			Vector3(0.05, 0.48, 0.86), mat_glass)
		_add_local_box(van, "Mirror", Vector3(0.90 * side, 1.38, -1.12),
			Vector3(0.16, 0.19, 0.25), mat_black_metal)
		_add_local_box(van, "DoorSeam", Vector3(0.755 * side, 0.88, 0.37),
			Vector3(0.026, 1.20, 1.42), mat_black_metal)

	_add_local_box(van, "FrontBumper", Vector3(0.0, 0.47, -1.73), Vector3(1.42, 0.18, 0.15), mat_black_metal)
	_add_local_box(van, "RearBumper", Vector3(0.0, 0.47, 1.73), Vector3(1.42, 0.18, 0.15), mat_black_metal)
	_add_local_box(van, "Grille", Vector3(0.0, 0.73, -1.755), Vector3(0.62, 0.22, 0.05), mat_black_metal)
	_add_local_box(van, "HeadlightL", Vector3(-0.46, 0.88, -1.755), Vector3(0.25, 0.20, 0.05), mat_neon_yellow)
	_add_local_box(van, "HeadlightR", Vector3(0.46, 0.88, -1.755), Vector3(0.25, 0.20, 0.05), mat_neon_yellow)
	_add_local_box(van, "PlateFront", Vector3(0.0, 0.55, -1.79), Vector3(0.36, 0.16, 0.025), mat_white)
	_add_local_box(van, "TailLightL", Vector3(-0.51, 0.84, 1.755), Vector3(0.18, 0.30, 0.04), mat_neon_red)
	_add_local_box(van, "TailLightR", Vector3(0.51, 0.84, 1.755), Vector3(0.18, 0.30, 0.04), mat_neon_red)

	# Simple work-van roof rack/cargo silhouette from the vehicle reference.
	_add_local_box(van, "RoofRackFront", Vector3(0.0, 1.99, -0.75), Vector3(1.22, 0.07, 0.07), mat_black_metal)
	_add_local_box(van, "RoofRackRear", Vector3(0.0, 1.99, 0.92), Vector3(1.22, 0.07, 0.07), mat_black_metal)
	for side: float in [-1.0, 1.0]:
		_add_local_box(van, "RoofRackRail", Vector3(0.57 * side, 2.02, 0.08), Vector3(0.06, 0.08, 1.78), mat_black_metal)
	if van_index == 1:
		_add_local_box(van, "RustPanel", Vector3(0.755, 0.70, 0.52), Vector3(0.035, 0.42, 0.80), mat_rust)
		_add_local_box(van, "CargoBox", Vector3(0.12, 2.15, 0.22), Vector3(0.78, 0.28, 0.70), mat_dark_concrete)

	var wheel_z_values: Array[float] = [-1.08, 1.10]
	for z_value: float in wheel_z_values:
		for side: float in [-1.0, 1.0]:
			_add_local_cylinder(van, "Wheel", Vector3(0.74 * side, 0.37, z_value),
				0.30, 0.16, mat_tire, Vector3(0.0, 0.0, PI * 0.5))
			_add_local_cylinder(van, "Hub", Vector3(0.81 * side, 0.37, z_value),
				0.14, 0.05, mat_soft_white, Vector3(0.0, 0.0, PI * 0.5))

	_add_collision_box(van, Vector3(0.0, 0.98, 0.0), Vector3(1.52, 1.96, 3.48))

func _build_distant_mountains() -> void:
	var town_half: float = float(GRID_WIDTH - 1) * TILE_SIZE * 0.5
	var mountain_positions: Array[Vector3] = [
		Vector3(-town_half - 54.0, 12.0, -town_half * 0.58),
		Vector3(-town_half - 66.0, 18.0, town_half * 0.20),
		Vector3(town_half + 58.0, 14.0, -town_half * 0.22),
		Vector3(town_half + 70.0, 20.0, town_half * 0.50),
		Vector3(-town_half * 0.45, 16.0, -town_half - 62.0),
		Vector3(town_half * 0.30, 23.0, -town_half - 74.0),
	]
	var mountain_index: int = 0
	for mountain_pos: Vector3 in mountain_positions:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "DistantMountain%d" % mountain_index
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = town_rng.randf_range(1.0, 3.0)
		mesh.bottom_radius = town_rng.randf_range(24.0, 38.0)
		mesh.height = town_rng.randf_range(38.0, 58.0)
		mesh.radial_segments = 11
		mi.mesh = mesh
		mi.position = mountain_pos
		mi.material_override = mat_mountain
		vegetation_root.add_child(mi)
		mountain_index += 1

func _add_tree(position_value: Vector3, scale_value: float) -> void:
	var root: Node3D = Node3D.new()
	root.position = position_value
	root.scale = Vector3.ONE * scale_value
	vegetation_root.add_child(root)
	_add_local_cylinder(root, "Trunk", Vector3(0.0, 1.55, 0.0), 0.16, 3.10, mat_trunk)
	# Several smaller, desaturated clusters read less like a single cartoon sphere.
	var crown_data: Array[Vector4] = [
		Vector4(0.0, 3.22, 0.0, 0.92),
		Vector4(0.58, 3.12, 0.12, 0.66),
		Vector4(-0.52, 3.08, -0.18, 0.69),
	]
	var crown_index: int = 0
	for item: Vector4 in crown_data:
		_add_local_sphere(root, "Crown%d" % crown_index, Vector3(item.x, item.y, item.z), item.w,
			mat_leaf_dark if crown_index % 2 == 0 else mat_green,
			Vector3(1.15, 0.82 + float(crown_index % 2) * 0.12, 1.0))
		crown_index += 1
	# Visible branch stubs help at close range.
	_add_local_cylinder(root, "BranchA", Vector3(0.18, 2.45, 0.0), 0.075, 1.10, mat_trunk,
		Vector3(0.0, 0.0, deg_to_rad(58.0)))
	_add_local_cylinder(root, "BranchB", Vector3(-0.18, 2.55, 0.05), 0.065, 0.95, mat_trunk,
		Vector3(0.0, 0.0, deg_to_rad(-55.0)))

func _add_cherry_tree(position_value: Vector3, scale_value: float) -> void:
	var root: Node3D = Node3D.new()
	root.position = position_value
	root.scale = Vector3.ONE * scale_value
	vegetation_root.add_child(root)
	_add_local_cylinder(root, "CherryTrunk", Vector3(0.0, 1.55, 0.0), 0.17, 3.10, mat_trunk)
	_add_local_cylinder(root, "CherryBranchL", Vector3(-0.24, 2.45, 0.0), 0.075, 1.25, mat_trunk,
		Vector3(0.0, 0.0, deg_to_rad(-54.0)))
	_add_local_cylinder(root, "CherryBranchR", Vector3(0.28, 2.50, 0.02), 0.070, 1.18, mat_trunk,
		Vector3(0.0, 0.0, deg_to_rad(56.0)))
	var blossom_data: Array[Vector4] = [
		Vector4(0.0, 3.32, 0.0, 0.96),
		Vector4(0.68, 3.18, 0.16, 0.70),
		Vector4(-0.64, 3.16, -0.14, 0.72),
		Vector4(0.02, 3.70, -0.22, 0.62),
	]
	for blossom_index: int in range(blossom_data.size()):
		var item: Vector4 = blossom_data[blossom_index]
		_add_local_sphere(root, "Blossom%d" % blossom_index,
			Vector3(item.x, item.y, item.z), item.w,
			mat_blossom if blossom_index % 3 != 0 else mat_blossom_dark,
			Vector3(1.18, 0.78, 1.0))

func _add_shrub(position_value: Vector3, scale_value: float) -> void:
	var root: Node3D = Node3D.new()
	root.position = position_value
	vegetation_root.add_child(root)
	_add_local_sphere(root, "Shrub", Vector3(0.0, 0.55 * scale_value, 0.0), 0.62 * scale_value, mat_leaf_dark, Vector3(1.2, 0.85, 1.0))

func _road_half_width(center: int) -> int:
	return MAIN_ROAD_HALF_WIDTH if center == MAIN_ROAD_CENTER else SECONDARY_ROAD_HALF_WIDTH

func _cell_to_world(cell: Vector2i, y_value: float) -> Vector3:
	var half_width: float = float(GRID_WIDTH - 1) * TILE_SIZE * 0.5
	var half_depth: float = float(GRID_HEIGHT - 1) * TILE_SIZE * 0.5
	return Vector3(
		float(cell.x) * TILE_SIZE - half_width,
		y_value,
		float(cell.y) * TILE_SIZE - half_depth
	)

func _grid_float_to_world(cell: Vector2, y_value: float) -> Vector3:
	var half_width: float = float(GRID_WIDTH - 1) * TILE_SIZE * 0.5
	var half_depth: float = float(GRID_HEIGHT - 1) * TILE_SIZE * 0.5
	return Vector3(
		cell.x * TILE_SIZE - half_width,
		y_value,
		cell.y * TILE_SIZE - half_depth
	)

func _world_to_navigation_cell(world_position: Vector3) -> Vector2i:
	var half_width: float = float(GRID_WIDTH - 1) * TILE_SIZE * 0.5
	var half_depth: float = float(GRID_HEIGHT - 1) * TILE_SIZE * 0.5
	var x_index: int = clampi(
		roundi((world_position.x + half_width) / TILE_SIZE),
		0,
		GRID_WIDTH - 1
	)
	var y_index: int = clampi(
		roundi((world_position.z + half_depth) / TILE_SIZE),
		0,
		GRID_HEIGHT - 1
	)
	var estimated: Vector2i = Vector2i(x_index, y_index)
	if _is_navigation_walkable(estimated):
		return estimated
	return _nearest_walkable_cell(estimated, true)

func _nearest_walkable_cell(from_cell: Vector2i, navigation_only: bool) -> Vector2i:
	var nearest: Vector2i = player_spawn_cell
	var nearest_distance_sq: float = INF
	for candidate: Vector2i in walkable_cells:
		if navigation_only and blocked_lookup.has(candidate):
			continue
		var dx: float = float(candidate.x - from_cell.x)
		var dy: float = float(candidate.y - from_cell.y)
		var distance_sq: float = dx * dx + dy * dy
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest = candidate
	return nearest

func get_path_world(from_world: Vector3, to_world: Vector3) -> PackedVector3Array:
	var start_cell: Vector2i = _world_to_navigation_cell(from_world)
	var end_cell: Vector2i = _world_to_navigation_cell(to_world)
	var id_path: Array[Vector2i] = path_grid.get_id_path(start_cell, end_cell, true)
	var world_path: PackedVector3Array = PackedVector3Array()
	for cell: Vector2i in id_path:
		world_path.append(_cell_to_world(cell, 0.0))
	return world_path

func get_nearest_walkable_world(world_position: Vector3) -> Vector3:
	var cell: Vector2i = _world_to_navigation_cell(world_position)
	return _cell_to_world(cell, 0.0)

func get_search_positions_world(center_world: Vector3, count: int = 4) -> Array[Vector3]:
	var requested_count: int = maxi(count, 1)
	var center_cell: Vector2i = _world_to_navigation_cell(center_world)
	var positions: Array[Vector3] = [_cell_to_world(center_cell, 0.0)]
	if requested_count <= 1:
		return positions

	var candidates: Array[Vector2i] = []
	for cell: Vector2i in walkable_cells:
		if cell == center_cell or blocked_lookup.has(cell):
			continue
		var path_to_cell: Array[Vector2i] = path_grid.get_id_path(center_cell, cell, true)
		if path_to_cell.size() < 2 or path_to_cell.size() > 12:
			continue
		candidates.append(cell)
	_shuffle_cells(candidates)

	var chosen_cells: Array[Vector2i] = [center_cell]
	for cell: Vector2i in candidates:
		var separated: bool = true
		for existing: Vector2i in chosen_cells:
			if _manhattan(cell, existing) < 3:
				separated = false
				break
		if not separated:
			continue
		chosen_cells.append(cell)
		positions.append(_cell_to_world(cell, 0.0))
		if positions.size() >= requested_count:
			break
	return positions

func build_patrol_route_world(spawn_world: Vector3, desired_points: int = 4) -> Array[Vector3]:
	var requested_points: int = maxi(desired_points, 2)
	var start_cell: Vector2i = _world_to_navigation_cell(spawn_world)
	var route_cells: Array[Vector2i] = [start_cell]
	var candidates: Array[Vector2i] = []

	for cell: Vector2i in walkable_cells:
		if cell == start_cell or cell == player_spawn_cell or blocked_lookup.has(cell):
			continue
		var path_to_cell: Array[Vector2i] = path_grid.get_id_path(start_cell, cell, true)
		if path_to_cell.size() < 5 or path_to_cell.size() > 24:
			continue
		candidates.append(cell)

	_shuffle_cells(candidates)
	for cell: Vector2i in candidates:
		var separated: bool = true
		for existing: Vector2i in route_cells:
			if _manhattan(cell, existing) < 5:
				separated = false
				break
		if not separated:
			continue
		route_cells.append(cell)
		if route_cells.size() >= requested_points:
			break

	if route_cells.size() < 2:
		for cell: Vector2i in walkable_cells:
			if cell == start_cell or blocked_lookup.has(cell):
				continue
			var fallback_path: Array[Vector2i] = path_grid.get_id_path(start_cell, cell, true)
			if fallback_path.size() >= 2:
				route_cells.append(cell)
				break

	var route: Array[Vector3] = []
	for cell: Vector2i in route_cells:
		route.append(_cell_to_world(cell, 0.0))
	return route

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F6:
			dry_ground_comparison = not dry_ground_comparison
			_apply_ground_comparison_mode(dry_ground_comparison)

func _apply_ground_comparison_mode(dry_mode: bool) -> void:
	# The production SHINRAI road is always dry and is not altered by this old
	# comparison hotkey. Keep the existing storefront-strip/reflection control
	# separate so shopfront presentation remains independent from road material.
	for reflection_node: Node in get_tree().get_nodes_in_group("shinrai_wet_ground_reflection"):
		var reflection_geometry: GeometryInstance3D = reflection_node as GeometryInstance3D
		if reflection_geometry != null:
			reflection_geometry.visible = not dry_mode

	var storefront_strip_count: int = 0
	for strip_node: Node in get_tree().get_nodes_in_group("shinrai_storefront_ground_strip"):
		var storefront_strip: MeshInstance3D = strip_node as MeshInstance3D
		if storefront_strip == null:
			continue
		storefront_strip.material_override = mat_storefront_apron_dry if dry_mode else mat_storefront_apron
		storefront_strip_count += 1

	print(
		"SHINRAI road remains DRY | storefront ground comparison: %s | strips: %d" % [
			"DRY" if dry_mode else "WET",
			storefront_strip_count,
		]
	)

func _collect_light_nodes(node: Node, out_lights: Array[Light3D]) -> void:
	for child: Node in node.get_children():
		if child is Light3D:
			out_lights.append(child as Light3D)
		_collect_light_nodes(child, out_lights)

func _audit_light_range(light: Light3D) -> String:
	if light is OmniLight3D:
		return "%.1f m" % (light as OmniLight3D).omni_range
	if light is SpotLight3D:
		return "%.1f m" % (light as SpotLight3D).spot_range
	if light is DirectionalLight3D:
		return "directional"
	return "n/a"

func _horizontal_light_distance(light: Light3D, origin: Vector3) -> float:
	var delta: Vector3 = light.global_position - origin
	return Vector2(delta.x, delta.z).length()

func _print_visual_test_nearby_light_audit(all_lights: Array[Light3D]) -> void:
	if not commercial_test_corridor_mode:
		return
	var origin: Vector3 = _cell_to_world(VISUAL_TEST_SPAWN_CELL, 0.0)
	print(
		"v10.25r nearby-light audit: %.1f m horizontal radius around locked spawn %s" % [
			VISUAL_TEST_NEARBY_LIGHT_AUDIT_RADIUS, str(origin)
		]
	)
	for light: Light3D in all_lights:
		if light is DirectionalLight3D:
			continue
		var distance_value: float = _horizontal_light_distance(light, origin)
		if distance_value > VISUAL_TEST_NEARBY_LIGHT_AUDIT_RADIUS:
			continue
		var allocation: String = "OTHER"
		if light.is_in_group("shinrai_visual_test_storefront_light"):
			allocation = "STOREFRONT/STREET-CAP"
		elif light.is_in_group("shinrai_under_eave_led_light"):
			allocation = "LIGHT03-UNDEREAVE/STREET-CAP"
		elif light.is_in_group("shinrai_modern_wall_lamp_light"):
			allocation = "MODERN-WALL/STREET-CAP"
		elif light.is_in_group("shinrai_eave_spot_light"):
			allocation = "HERITAGE-EAVE/STREET-CAP"
		elif light.is_in_group("shinrai_street_light"):
			allocation = "STREET"
		elif light.is_in_group("shinrai_interior_light"):
			allocation = "INTERIOR"
		print(
			"  NEAR %s | %s | distance=%.2f m | energy=%.2f | range=%s | pos=%s" % [
				allocation,
				str(light.get_path()),
				distance_value,
				light.light_energy,
				_audit_light_range(light),
				str(light.global_position),
			]
		)

func _print_light_budget_audit() -> void:
	# Runtime diagnostic only: no light is added, removed or re-tuned here.
	# v10.25o keeps the capped street/interior allocation report, then enumerates
	# every other Light3D currently in the scene after player + wave spawn. This
	# makes park lanterns, viewmodel fill and zero-energy muzzle lights visible
	# in the audit instead of implying the two capped pools are the whole scene.
	var all_lights: Array[Light3D] = []
	_collect_light_nodes(self, all_lights)

	var runtime_street_count: int = 0
	var runtime_interior_count: int = 0
	var runtime_other_count: int = 0
	var runtime_other_active_count: int = 0
	var runtime_yakitori_lantern_light_count: int = 0

	for light: Light3D in all_lights:
		if light.is_in_group("shinrai_yakitori_lantern_light"):
			runtime_yakitori_lantern_light_count += 1
		if light.is_in_group("shinrai_street_light"):
			runtime_street_count += 1
		elif light.is_in_group("shinrai_interior_light"):
			runtime_interior_count += 1
		else:
			runtime_other_count += 1
			if light.is_visible_in_tree() and light.light_energy > 0.001:
				runtime_other_active_count += 1

	print("--- v10.26g LIGHT BUDGET AUDIT ---")
	print(
		"Street-capped Light3D: %d / %d cap (%d slots unused; includes storefront Omni + Light 03 under-eave LED + heritage Light 02 Spot; v10.26c wall lamp retained but dormant)" % [
			street_light_count, MAX_STREET_LIGHTS, MAX_STREET_LIGHTS - street_light_count
		]
	)
	print(
		"Interior OmniLight3D: %d / %d cap | shops %d / %d | other %d / %d" % [
			interior_light_count, MAX_INTERIOR_LIGHTS,
			shop_interior_light_count, MAX_SHOP_INTERIOR_LIGHTS,
			other_interior_light_count, MAX_OTHER_INTERIOR_LIGHTS,
		]
	)
	print(
		"All scene Light3D nodes after player/wave spawn: %d | street-grouped %d | interior-grouped %d | other/uncapped %d (%d visible with energy > 0)" % [
			all_lights.size(),
			runtime_street_count,
			runtime_interior_count,
			runtime_other_count,
			runtime_other_active_count,
		]
	)
	print(
		"Yakitori lantern internal Light3D: %d | authored/fallback practicals remain in other/uncapped pool with ~2.5 m local range" % runtime_yakitori_lantern_light_count
	)
	print(
        "Environment lighting: ambient color=(0.50, 0.58, 0.72), ambient energy 1.72 | OvercastSun energy 0.80, shadows 72 m | LowWarmFill energy 0.075, no shadows"
	)

	for street_node: Node in get_tree().get_nodes_in_group("shinrai_street_light"):
		var street_light: Light3D = street_node as Light3D
		if street_light == null:
			continue
		print(
			"  STREET %s | type=%s | pos=%s | energy=%.2f | range=%s | visible=%s" % [
				street_light.get_parent().name,
				street_light.get_class(),
				str(street_light.global_position),
				street_light.light_energy,
				_audit_light_range(street_light),
				str(street_light.is_visible_in_tree()),
			]
		)

	for interior_node: Node in get_tree().get_nodes_in_group("shinrai_interior_light"):
		var interior_light: OmniLight3D = interior_node as OmniLight3D
		if interior_light == null:
			continue
		print(
			"  INTERIOR %s | pos=%s | energy=%.2f | range=%.1f | visible=%s" % [
				interior_light.get_parent().name,
				str(interior_light.global_position),
				interior_light.light_energy,
				interior_light.omni_range,
				str(interior_light.is_visible_in_tree()),
			]
		)

	for light: Light3D in all_lights:
		if light.is_in_group("shinrai_street_light") or light.is_in_group("shinrai_interior_light"):
			continue
		print(
			"  OTHER %s | path=%s | type=%s | energy=%.3f | range=%s | visible=%s | shadows=%s | cull_mask=%d" % [
				light.name,
				str(light.get_path()),
				light.get_class(),
				light.light_energy,
				_audit_light_range(light),
				str(light.is_visible_in_tree()),
				str(light.shadow_enabled),
				light.light_cull_mask,
			]
		)
	_print_visual_test_nearby_light_audit(all_lights)
	print("--- END LIGHT BUDGET AUDIT ---")

func _spawn_player() -> void:
	player = PlayerScript.new()
	player.position = _cell_to_world(player_spawn_cell, 0.0)
	player.rotation = Vector3(0.0, _get_player_spawn_yaw(), 0.0)
	add_child(player)
	player.died.connect(_on_player_died)

func _get_player_spawn_yaw() -> float:
	if commercial_test_corridor_mode:
		# Face east along the selected corridor so every launch begins from the
		# same wall/entrance/pavement comparison view.
		return -PI * 0.5
	var spawn_world: Vector3 = _cell_to_world(player_spawn_cell, 0.0)
	for direction: Vector2i in SPAWN_FACING_DIRECTIONS:
		var neighbor: Vector2i = player_spawn_cell + direction
		if not _is_navigation_walkable(neighbor):
			continue
		var neighbor_world: Vector3 = _cell_to_world(neighbor, 0.0)
		var forward: Vector3 = neighbor_world - spawn_world
		return atan2(-forward.x, -forward.z)
	return 0.0

func _get_enemy_spawn_positions(count: int) -> Array[Vector3]:
	var preferred: Array[Vector2i] = []
	var fallback: Array[Vector2i] = []
	var nearby_cell: Vector2i = Vector2i(-1, -1)
	var nearby_score: float = INF
	var player_spawn_world: Vector3 = _cell_to_world(player_spawn_cell, 0.0)

	for cell: Vector2i in walkable_cells:
		if cell == player_spawn_cell or blocked_lookup.has(cell):
			continue
		var path_to_cell: Array[Vector2i] = path_grid.get_id_path(player_spawn_cell, cell, true)
		if path_to_cell.size() < 3:
			continue

		var candidate_world: Vector3 = _cell_to_world(cell, 0.0)
		var horizontal_distance: float = Vector2(
			candidate_world.x - player_spawn_world.x,
			candidate_world.z - player_spawn_world.z
		).length()
		if (
			horizontal_distance >= NEARBY_K17_MIN_DISTANCE_M
			and horizontal_distance <= NEARBY_K17_MAX_DISTANCE_M
		):
			var score: float = absf(horizontal_distance - NEARBY_K17_TARGET_DISTANCE_M)
			if score < nearby_score:
				nearby_score = score
				nearby_cell = cell

		if path_to_cell.size() < 5:
			continue
		fallback.append(cell)
		if path_to_cell.size() >= MIN_ENEMY_PATH_CELLS:
			preferred.append(cell)

	_shuffle_cells(preferred)
	_shuffle_cells(fallback)

	var chosen_cells: Array[Vector2i] = []
	if count > 0 and nearby_score < INF:
		chosen_cells.append(nearby_cell)

	for cell: Vector2i in preferred:
		if chosen_cells.size() >= count:
			break
		var separated: bool = true
		for existing: Vector2i in chosen_cells:
			if _manhattan(cell, existing) < 8:
				separated = false
				break
		if separated:
			chosen_cells.append(cell)

	if chosen_cells.size() < count:
		for cell: Vector2i in fallback:
			if chosen_cells.size() >= count:
				break
			if chosen_cells.has(cell):
				continue
			chosen_cells.append(cell)

	var positions: Array[Vector3] = []
	for cell: Vector2i in chosen_cells:
		positions.append(_cell_to_world(cell, 0.0))
	return positions

func _spawn_wave() -> void:
	if not is_instance_valid(player) or not player.alive:
		return
	player.set_wave(wave)
	var requested_count: int = mini(3 + wave, 9)
	var spawn_positions: Array[Vector3] = _get_enemy_spawn_positions(requested_count)
	for spawn_position: Vector3 in spawn_positions:
		var enemy: CharacterBody3D = EnemyScript.new()
		enemy.position = spawn_position
		var patrol_route: Array[Vector3] = build_patrol_route_world(spawn_position, 4)
		enemy.configure(player, wave, self, patrol_route)
		add_child(enemy)

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not player.alive:
		return
	var enemy_count: int = get_tree().get_nodes_in_group("enemies").size()
	if enemy_count == 0 and next_wave_timer < 0.0:
		next_wave_timer = 2.0
	if next_wave_timer >= 0.0:
		next_wave_timer -= delta
		if next_wave_timer <= 0.0:
			next_wave_timer = -1.0
			wave += 1
			_spawn_wave()

func _on_player_died() -> void:
	next_wave_timer = -1.0

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _shuffle_cells(cells: Array[Vector2i]) -> void:
	if cells.size() < 2:
		return
	for index: int in range(cells.size() - 1, 0, -1):
		var swap_index: int = town_rng.randi_range(0, index)
		var temporary: Vector2i = cells[index]
		cells[index] = cells[swap_index]
		cells[swap_index] = temporary

func _add_visual_box(
	parent: Node3D,
	part_name: String,
	position_value: Vector3,
	size: Vector3,
	material: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = part_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position_value
	mesh_instance.rotation = rotation_value
	mesh_instance.material_override = material
	# Small trim, signs and micro-details do not need to remain visible across
	# the entire procedural map. Distance culling cuts draw calls in dense
	# streets without removing the structural walls/roofs that define the town.
	var max_dim: float = maxf(size.x, maxf(size.y, size.z))
	var volume: float = size.x * size.y * size.z
	if max_dim <= 4.5 and volume <= 5.0:
		mesh_instance.visibility_range_end = DETAIL_VISIBILITY_RANGE
		mesh_instance.visibility_range_end_margin = 8.0
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_local_box(
	parent: Node3D,
	part_name: String,
	position_value: Vector3,
	size: Vector3,
	material: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	return _add_visual_box(
		parent,
		part_name,
		position_value,
		size,
		material,
		rotation_value
	)

func _add_facade_detail_box(
	parent: Node3D,
	part_name: String,
	position_value: Vector3,
	size: Vector3,
	material: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	# Architectural trim should enrich the player's immediate street, not add
	# shadows/draw cost across the whole 53x53 town. Keep these meshes local.
	var detail: MeshInstance3D = _add_visual_box(
		parent, part_name, position_value, size, material, rotation_value
	)
	detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	detail.visibility_range_end = FACADE_DETAIL_VISIBILITY_RANGE
	detail.visibility_range_end_margin = 6.0
	return detail

func _surface_add_double_sided_triangle(
	surface_tool: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> void:
	# Add both windings so the thin gable closure is valid from either side.
	# SurfaceTool generates the matching face normals after all vertices exist.
	# Side-wall UVs use local Z/Y so the existing plaster/concrete detail
	# textures continue naturally onto the closure instead of sampling one texel.
	surface_tool.set_uv(Vector2(a.z, -a.y))
	surface_tool.add_vertex(a)
	surface_tool.set_uv(Vector2(b.z, -b.y))
	surface_tool.add_vertex(b)
	surface_tool.set_uv(Vector2(c.z, -c.y))
	surface_tool.add_vertex(c)
	surface_tool.set_uv(Vector2(c.z, -c.y))
	surface_tool.add_vertex(c)
	surface_tool.set_uv(Vector2(b.z, -b.y))
	surface_tool.add_vertex(b)
	surface_tool.set_uv(Vector2(a.z, -a.y))
	surface_tool.add_vertex(a)

func _add_gable_end_infill(
	parent: Node3D,
	width_m: float,
	depth_m: float,
	wall_top_y: float,
	angle_degrees: float,
	material: Material
) -> void:
	# v10.25j: the procedural wall body is rectangular, while the pitched roof
	# rises above it. Without a gable wall this leaves a genuine open triangle
	# at the two side elevations. Close that space with a tiny two-sided mesh
	# that matches the building's own wall material. It has no collision and
	# casts no extra shadow, so this is a visual closure rather than new mass.
	if material == null:
		return

	var angle: float = deg_to_rad(angle_degrees)
	var roof_overhang_z: float = 0.72
	var eave_center_y: float = wall_top_y + 0.05
	var half_roof_span_z: float = depth_m * 0.5 + roof_overhang_z
	var roof_rise_z: float = tan(angle) * half_roof_span_z

	# RoofFront/RoofBack are 0.18 m thick boxes. Their centre-line is the
	# mathematical slope, so shift the infill top down by roughly half that
	# thickness (projected vertically) and overlap it by a few millimetres.
	# This closes daylight cracks without poking through the visible tiles.
	var roof_half_thickness_vertical: float = 0.09 * cos(angle)
	var seam_overlap: float = 0.012
	var roof_contact_drop: float = maxf(0.045, roof_half_thickness_vertical - seam_overlap)

	var half_wall_depth: float = depth_m * 0.5 + 0.018
	var base_y: float = wall_top_y - 0.035
	var corner_y: float = eave_center_y + tan(angle) * roof_overhang_z - roof_contact_drop
	var peak_y: float = eave_center_y + roof_rise_z - roof_contact_drop

	# Keep the face just outside the side-wall plane to avoid z-fighting. Both
	# side gables live in one MeshInstance, keeping the fix to one tiny draw node
	# per procedural pitched roof rather than several stair-step boxes.
	var side_offset: float = width_m * 0.5 + 0.006
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.set_smooth_group(-1)

	for side_x: float in [-side_offset, side_offset]:
		var p0: Vector3 = Vector3(side_x, base_y, -half_wall_depth)
		var p1: Vector3 = Vector3(side_x, base_y, half_wall_depth)
		var p2: Vector3 = Vector3(side_x, corner_y, half_wall_depth)
		var p3: Vector3 = Vector3(side_x, peak_y, 0.0)
		var p4: Vector3 = Vector3(side_x, corner_y, -half_wall_depth)

		# Five-sided gable profile = lower rectangle/trapezoid + roof triangle.
		_surface_add_double_sided_triangle(surface_tool, p0, p1, p2)
		_surface_add_double_sided_triangle(surface_tool, p0, p2, p3)
		_surface_add_double_sided_triangle(surface_tool, p0, p3, p4)

	surface_tool.generate_normals()
	var generated_mesh: ArrayMesh = surface_tool.commit()
	var gable: MeshInstance3D = MeshInstance3D.new()
	gable.name = "GableEndInfill"
	gable.mesh = generated_mesh
	gable.material_override = material
	gable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(gable)

func _add_gable_roof(
	parent: Node3D,
	width_m: float,
	depth_m: float,
	wall_top_y: float,
	roof_material: Material,
	ridge_material: Material,
	angle_degrees: float,
	ridge_along_width: bool = true,
	gable_material: Material = null
) -> void:
	# Japanese street-facing buildings usually read with a long eave line over
	# the facade. The ridge therefore runs parallel to the frontage (X axis)
	# by default, instead of presenting a western-looking triangular gable to
	# every street. The slope still rises correctly toward the centre ridge.
	var overhang_x: float = 0.58
	var overhang_z: float = 0.72
	var angle: float = deg_to_rad(angle_degrees)
	var eave_y: float = wall_top_y + 0.05

	if ridge_along_width:
		var half_span_z: float = depth_m * 0.5 + overhang_z
		var roof_rise_z: float = tan(angle) * half_span_z
		var slope_length_z: float = half_span_z / cos(angle)
		var center_y_z: float = eave_y + roof_rise_z * 0.5
		var center_z: float = half_span_z * 0.5
		_add_local_box(parent, "RoofFront", Vector3(0.0, center_y_z, -center_z),
			Vector3(width_m + overhang_x * 2.0, 0.18, slope_length_z), roof_material,
			Vector3(-angle, 0.0, 0.0))
		_add_local_box(parent, "RoofBack", Vector3(0.0, center_y_z, center_z),
			Vector3(width_m + overhang_x * 2.0, 0.18, slope_length_z), roof_material,
			Vector3(angle, 0.0, 0.0))
		var ridge_y_z: float = eave_y + roof_rise_z
		_add_local_cylinder(parent, "RoofRidge", Vector3(0.0, ridge_y_z + 0.06, 0.0),
			0.12, width_m + overhang_x * 1.9, ridge_material, Vector3(0.0, 0.0, PI * 0.5))
		_add_local_box(parent, "FrontEaveFascia", Vector3(0.0, eave_y - 0.03, -half_span_z + 0.05),
			Vector3(width_m + overhang_x * 2.0, 0.28, 0.22), mat_dark_wood)
		_add_local_box(parent, "BackEaveFascia", Vector3(0.0, eave_y - 0.03, half_span_z - 0.08),
			Vector3(width_m + overhang_x * 2.0, 0.26, 0.16), mat_dark_wood)
		_add_local_box(parent, "FrontEaveBeam", Vector3(0.0, eave_y - 0.18, -half_span_z + 0.14),
			Vector3(width_m + overhang_x * 1.72, 0.11, 0.18), mat_dark_wood)
		# Thin rafters and tile rows add close-range roof rhythm without a
		# heavy external roof asset. These are structural accents, not clutter.
		for rafter_index: int in range(7):
			var rafter_t: float = float(rafter_index) / 6.0 - 0.5
			_add_local_box(parent, "FrontEaveRafter",
				Vector3(rafter_t * width_m * 0.86, eave_y - 0.22, -half_span_z - 0.02),
				Vector3(0.075, 0.075, 0.48), mat_dark_wood)
		for band_index: int in range(1, 4):
			var band_t: float = float(band_index) / 4.0
			var band_z: float = -half_span_z + half_span_z * band_t
			var band_y: float = eave_y + roof_rise_z * band_t + 0.05
			_add_local_box(parent, "RoofTileBandFront", Vector3(0.0, band_y, band_z),
				Vector3(width_m + overhang_x * 1.8, 0.045, 0.085), ridge_material)
			_add_local_box(parent, "RoofTileBandBack", Vector3(0.0, band_y, -band_z),
				Vector3(width_m + overhang_x * 1.8, 0.045, 0.085), ridge_material)
		if gable_material != null:
			_add_gable_end_infill(parent, width_m, depth_m, wall_top_y, angle_degrees, gable_material)
	else:
		var half_span_x: float = width_m * 0.5 + overhang_x
		var roof_rise_x: float = tan(angle) * half_span_x
		var slope_length_x: float = half_span_x / cos(angle)
		var center_y_x: float = eave_y + roof_rise_x * 0.5
		var center_x: float = half_span_x * 0.5
		_add_local_box(parent, "RoofLeft", Vector3(-center_x, center_y_x, 0.0),
			Vector3(slope_length_x, 0.18, depth_m + overhang_z * 2.0), roof_material,
			Vector3(0.0, 0.0, angle))
		_add_local_box(parent, "RoofRight", Vector3(center_x, center_y_x, 0.0),
			Vector3(slope_length_x, 0.18, depth_m + overhang_z * 2.0), roof_material,
			Vector3(0.0, 0.0, -angle))
		var ridge_y_x: float = eave_y + roof_rise_x
		_add_local_cylinder(parent, "RoofRidge", Vector3(0.0, ridge_y_x + 0.06, 0.0),
			0.12, depth_m + overhang_z * 1.9, ridge_material, Vector3(PI * 0.5, 0.0, 0.0))
		_add_local_box(parent, "EaveLeft", Vector3(-half_span_x + 0.08, eave_y - 0.03, 0.0),
			Vector3(0.16, 0.26, depth_m + overhang_z * 2.0), mat_dark_wood)
		_add_local_box(parent, "EaveRight", Vector3(half_span_x - 0.08, eave_y - 0.03, 0.0),
			Vector3(0.16, 0.26, depth_m + overhang_z * 2.0), mat_dark_wood)
		for band_index: int in range(1, 4):
			var band_t: float = float(band_index) / 4.0
			var band_x: float = -half_span_x + half_span_x * band_t
			var band_y: float = eave_y + roof_rise_x * band_t + 0.05
			_add_local_box(parent, "RoofTileBandLeft", Vector3(band_x, band_y, 0.0),
				Vector3(0.085, 0.045, depth_m + overhang_z * 1.8), ridge_material)
			_add_local_box(parent, "RoofTileBandRight", Vector3(-band_x, band_y, 0.0),
				Vector3(0.085, 0.045, depth_m + overhang_z * 1.8), ridge_material)

func _add_rooftop_parapet(parent: Node3D, width_m: float, depth_m: float, top_y: float) -> void:
	# A slightly taller street-facing parapet gives flat-roof buildings a more
	# authored silhouette without adding rooftop nodes.
	var front_h: float = 0.62
	var side_h: float = 0.44
	var t: float = 0.14
	_add_local_box(parent, "ParapetFront", Vector3(0.0, top_y + front_h * 0.5, -depth_m * 0.5 + t * 0.5),
		Vector3(width_m, front_h, t), mat_dark_concrete)
	_add_local_box(parent, "ParapetBack", Vector3(0.0, top_y + side_h * 0.5, depth_m * 0.5 - t * 0.5),
		Vector3(width_m, side_h, t), mat_dark_concrete)
	_add_local_box(parent, "ParapetLeft", Vector3(-width_m * 0.5 + t * 0.5, top_y + side_h * 0.5, 0.0),
		Vector3(t, side_h, depth_m), mat_dark_concrete)
	_add_local_box(parent, "ParapetRight", Vector3(width_m * 0.5 - t * 0.5, top_y + side_h * 0.5, 0.0),
		Vector3(t, side_h, depth_m), mat_dark_concrete)

func _build_distant_skyline() -> void:
	# Low-rise streets need a clearly separate high-rise horizon. The skyline
	# is authored into two distant clusters so important roads and the shrine
	# garden catch tower silhouettes without towers invading pedestrian blocks.
	var town_half_x: float = float(GRID_WIDTH) * TILE_SIZE * 0.5
	var town_half_z: float = float(GRID_HEIGHT) * TILE_SIZE * 0.5
	var north_z: float = -town_half_z - 24.0
	var north_specs: Array[Vector4] = [
		Vector4(-76.0, 10.0, 58.0, 9.0),
		Vector4(-61.0, 14.0, 82.0, 12.0),
		Vector4(-43.0, 10.0, 69.0, 9.0),
		Vector4(-27.0, 13.0, 96.0, 11.0),
		Vector4(-10.0, 11.0, 78.0, 10.0),
		Vector4(4.0, 15.0, 118.0, 13.0),
		Vector4(23.0, 12.0, 91.0, 10.0),
		Vector4(40.0, 15.0, 104.0, 12.0),
		Vector4(60.0, 12.0, 84.0, 10.0),
		Vector4(77.0, 9.0, 63.0, 9.0),
	]
	for index: int in range(north_specs.size()):
		var spec: Vector4 = north_specs[index]
		var depth_offset: float = float(index % 3) * 7.0
		_add_skyline_landmark(
			Vector3(clampf(spec.x, -town_half_x * 0.98, town_half_x * 0.98), 0.0, north_z - depth_offset),
			spec.y, spec.z, spec.w, index, 0.0
		)

	# Smaller eastern cluster keeps the skyline visible when the player turns
	# across the park or along east-west streets.
	var east_x: float = town_half_x + 31.0
	var east_specs: Array[Vector4] = [
		Vector4(-68.0, 11.0, 62.0, 10.0),
		Vector4(-44.0, 14.0, 88.0, 12.0),
		Vector4(-18.0, 10.0, 73.0, 9.0),
		Vector4(12.0, 13.0, 98.0, 11.0),
		Vector4(42.0, 10.0, 76.0, 9.0),
		Vector4(67.0, 12.0, 66.0, 10.0),
	]
	for side_index: int in range(east_specs.size()):
		var side_spec: Vector4 = east_specs[side_index]
		_add_skyline_landmark(
			Vector3(east_x + float(side_index % 2) * 6.0, 0.0, side_spec.x),
			side_spec.y, side_spec.z, side_spec.w, 20 + side_index, PI * 0.5
		)

func _add_skyline_landmark(
	position_value: Vector3,
	width_value: float,
	height_value: float,
	depth_value: float,
	tower_index: int,
	yaw: float
) -> void:
	var root: Node3D = Node3D.new()
	root.name = "SkylineLandmark%d" % tower_index
	root.position = position_value
	root.rotation.y = yaw
	decoration_root.add_child(root)

	_add_local_box(root, "TowerBase", Vector3(0.0, height_value * 0.38, 0.0),
		Vector3(width_value, height_value * 0.76, depth_value), mat_dark_concrete)
	var upper_width: float = width_value * (0.70 if tower_index % 3 == 0 else 0.82)
	var upper_depth: float = depth_value * 0.78
	_add_local_box(root, "TowerUpper", Vector3(0.0, height_value * 0.83, 0.0),
		Vector3(upper_width, height_value * 0.34, upper_depth), mat_dark_concrete)

	# Sparse vertical light strips create city scale without turning the entire
	# skyline into rainbow neon.
	var strip_mat: Material = mat_neon_red if tower_index % 4 != 1 else mat_neon_blue
	var strip_count: int = 1 if width_value < 11.0 else 2
	for strip_index: int in range(strip_count):
		var strip_x: float = 0.0
		if strip_count > 1:
			strip_x = (-0.18 if strip_index == 0 else 0.18) * width_value
		_add_local_box(root, "TowerLightStrip", Vector3(strip_x, height_value * 0.62, -depth_value * 0.505),
			Vector3(0.11, height_value * 0.34, 0.08), strip_mat)

	_add_local_box(root, "SkylineCrown", Vector3(0.0, height_value + 0.42, 0.0),
		Vector3(upper_width * 0.82, 0.10, upper_depth * 0.82), strip_mat)
	if tower_index % 3 != 0:
		_add_local_cylinder(root, "SkylineAntenna", Vector3(0.0, height_value + 4.25, 0.0),
			0.08, 7.2, mat_black_metal)

func _add_local_cylinder(
	parent: Node3D,
	part_name: String,
	position_value: Vector3,
	radius: float,
	height: float,
	material: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = part_name
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh_instance.mesh = mesh
	mesh_instance.position = position_value
	mesh_instance.rotation = rotation_value
	mesh_instance.material_override = material
	# Cylinders are almost exclusively poles, pipes, branches and other small
	# details. Their individual shadows are expensive and visually negligible.
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.visibility_range_end = DETAIL_VISIBILITY_RANGE
	mesh_instance.visibility_range_end_margin = 8.0
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_local_sphere(
	parent: Node3D,
	part_name: String,
	position_value: Vector3,
	radius: float,
	material: Material,
	scale_value: Vector3 = Vector3.ONE
) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = part_name
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	mesh_instance.mesh = mesh
	mesh_instance.position = position_value
	mesh_instance.scale = scale_value
	mesh_instance.material_override = material
	# Foliage was one of the most expensive primitive groups in v10.16. Use a
	# lower-poly sphere and stop rendering individual leaf clusters once they
	# are too distant to contribute to the street silhouette.
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.visibility_range_end = FOLIAGE_VISIBILITY_RANGE
	mesh_instance.visibility_range_end_margin = 10.0
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_collision_box(
	collision_parent: CollisionObject3D,
	position_value: Vector3,
	size: Vector3
) -> void:
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = position_value
	collision_parent.add_child(shape_node)
