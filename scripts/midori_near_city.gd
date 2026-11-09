extends Node3D
## Dense Tokyo district hugging the park, beyond the soft raid boundary. Visual
## only: no collision and no effect on routes. Mostly tightly packed low and
## mid-rise lots, with towers held to two clusters. Bodies are boxes given depth by
## midori_near_city_building.gdshader; balconies, signs and rooftop plant are real
## geometry. Each layer is split into culled MultiMesh chunks.
const RNG_SEED := 20500702
## The fixed city: every lot, pavement and tower with the random state it was laid out from.
## Built by tests/city_layout_tool.gd; without it the generator lays the city out live.
const LAYOUT_PATH := "res://assets/shinrai/near_city/city_layout.json"
const HALF_EXTENT := 640.0
const BLOCK := 64.0
const ROAD := 7.0 # Half road width; the grid centres roads on block lines.
const WALK := 3.0
const PARK := Rect2(-222, -182, 444, 364)
const CLEAR_ZONES: Array[Rect2] = [Rect2(-60, 168, 125, 112), Rect2(52, 180, 342, 300), Rect2(520, -120, 56, 56)]
const PARK_MARGIN := 24.0
const MIN_LOT := 5.0
const CHUNK := 320.0
const NEAR_TIER := 150.0
const MID_TIER := 340.0
const STOREY := 3.2
const SHOP_FLOOR := 4.2
const CLUSTERS: Array[Vector2] = [Vector2(-470, -420), Vector2(470, -250)]
const CLUSTER_RADIUS := 150.0
const BUILDING_SHADER := preload("res://scripts/midori_near_city_building.gdshader")
const SHELL_SHADER := preload("res://scripts/midori_near_city_shell.gdshader")
const GLASS_SHADER := preload("res://scripts/midori_near_city_glass.gdshader")
const Hero := preload("res://scripts/midori_near_city_hero.gd")
const Budget := preload("res://scripts/shinrai_loading_budget.gd")
const StartupTrace := preload("res://scripts/startup_trace.gd")
const Prefetch := preload("res://scripts/midori_near_city_prefetch.gd")
const GyozaShop := preload("res://scripts/midori_near_city_gyoza.gd")
const PencilBuilding := preload("res://scripts/midori_near_city_pencil.gd")
const KonbiniBlock := preload("res://scripts/midori_near_city_konbini.gd")
const ZakkyoTower := preload("res://scripts/midori_near_city_zakkyo.gd")
const CornerChemist := preload("res://scripts/midori_near_city_drugstore.gd")
const CoinLaundry := preload("res://scripts/midori_near_city_laundry.gd")
const FamilyClinic := preload("res://scripts/midori_near_city_clinic.gd")
const CapsuleTower := preload("res://scripts/midori_near_city_capsule.gd")
const PachinkoHall := preload("res://scripts/midori_near_city_pachinko.gd")
const StardustLane := preload("res://scripts/midori_near_city_lane.gd")
const KaraokeTower := preload("res://scripts/midori_near_city_karaoke.gd")
const PoliceBox := preload("res://scripts/midori_near_city_koban.gd")
const GameCentre := preload("res://scripts/midori_near_city_arcade.gd")
const RamenShop := preload("res://scripts/midori_near_city_ramen.gd")
const EstateOffice := preload("res://scripts/midori_near_city_fudosan.gd")
const FlowerShop := preload("res://scripts/midori_near_city_flower.gd")
const UsedBooks := preload("res://scripts/midori_near_city_books.gd")
const PublicBath := preload("res://scripts/midori_near_city_sento.gd")
const BarberShop := preload("res://scripts/midori_near_city_barber.gd")
const WagashiShop := preload("res://scripts/midori_near_city_wagashi.gd")
const BusinessHotel := preload("res://scripts/midori_near_city_hotel.gd")
const BicycleShop := preload("res://scripts/midori_near_city_cycle.gd")
const Greengrocer := preload("res://scripts/midori_near_city_yaoya.gd")
const SnackBuilding := preload("res://scripts/midori_near_city_snack.gd")
const HandViaduct := preload("res://scripts/midori_near_city_viaduct.gd")
const ClearedLot := preload("res://scripts/midori_near_city_handmade.gd") # Built over by its neighbour; adds nothing itself.
# Lots given over to hand-modelled buildings, by a point inside each.
const HANDMADE: Array[Array] = [[Vector2(33.5, -210.75), GyozaShop], [Vector2(40.5, -210.9), PencilBuilding], [Vector2(49.0, -211.0), KonbiniBlock], [Vector2(25.0, -211.0), ZakkyoTower], [Vector2(12.6, -208.0), CornerChemist], [Vector2(18.5, -209.0), CoinLaundry], [Vector2(12.6, -216.0), FamilyClinic], [Vector2(-19.8, -209.0), CapsuleTower], [Vector2(-13.0, -209.0), ClearedLot], [Vector2(-19.0, -219.0), ClearedLot], [Vector2(-12.5, -219.0), ClearedLot], [Vector2(-26.4, -210.0), PachinkoHall], [Vector2(-31.5, -210.0), ClearedLot], [Vector2(-35.7, -210.0), ClearedLot], [Vector2(-41.8, -210.0), StardustLane], [Vector2(-42.0, -219.0), ClearedLot], [Vector2(-42.0, -229.0), ClearedLot], [Vector2(-42.0, -240.0), ClearedLot], [Vector2(-49.5, -210.0), KaraokeTower], [Vector2(77.0, -210.0), PoliceBox], [Vector2(84.0, -210.0), GameCentre], [Vector2(90.4, -210.0), RamenShop], [Vector2(96.4, -210.0), EstateOffice], [Vector2(102.0, -210.0), FlowerShop], [Vector2(107.3, -210.0), UsedBooks], [Vector2(114.4, -210.0), PublicBath], [Vector2(140.2, -209.0), BarberShop], [Vector2(145.6, -209.0), WagashiShop], [Vector2(153.11, -212.0), BusinessHotel], [Vector2(160.625, -209.0), BicycleShop], [Vector2(169.59, -209.0), Greengrocer], [Vector2(178.635, -209.0), SnackBuilding]]
const HERO_RANGE := 130.0 # Buildings this close to the park get full real shells.
const SHELL_RANGE := 300.0 # Out to here shells stay real but drop their finest parts.
const PALETTE: Array[Color] = [Color(.96,.92,.84), Color(.9,.84,.74), Color(.97,.96,.93), Color(.84,.84,.83), Color(.8,.72,.62), Color(.62,.36,.26), Color(.48,.24,.2), Color(.15,.16,.17),
	Color(.08,.08,.09), Color(.28,.36,.44), Color(.3,.48,.46), Color(.56,.62,.52), Color(.72,.58,.3), Color(.78,.56,.48), Color(.42,.42,.42), Color(.56,.55,.53)]
const TEXTURES := "res://assets/shinrai/near_city/textures/"
const SIGN_ATLAS := "res://assets/shinrai/near_city/signs_atlas.png"
const ROAD_ALBEDO := "res://assets/environment/roads/shinrai_road/textures/SHINRAI_Road_FineAggregate_BaseColor_2K.png"
const PAVER_ALBEDO := "res://assets/shinrai/drain_hgu150/ProjectShinrai_HGU150_Drain_GameReady_SHINRAI_PrecastPaver_BaseColor_1K.png"
const WALLS: Array[String] = ["rectangular_facade_tiles", "concrete_tile_facade", "exterior_wall_cladding", "precast_concrete_wall", "corrugated_iron_02", "painted_metal_shutter", "long_white_tiles", "white_stucco", "square_tiled_wall"]
enum Kind { ZAKKYO, MANSION, OFFICE, GLASS, LOW, GARAGE, DANCHI, UPPER, CORE, KONBINI }
const EXPRESSWAY_Z := -256.0
const EXPRESSWAY_Y := 15.0
const VIADUCT_X := 320.0
const VIADUCT_Y := 8.0
const TOWER_SITE := Vector2(548, -92)
const TOWER_HEIGHT := 262.0
const TOWER_LEVELS := 15
const KONBINI_STRIPES: Array[Array] = [[Color("#1c7f4b"), Color("#f2f2ee")], [Color("#1d55a8"), Color("#f2f2ee")], [Color("#d9561c"), Color("#2a7a4a")]]
enum Pattern { SOLID, BARS, LOUVRE, FROSTED, SOLAR, ROOF_TILE, AC_UNIT, RIBBED, AWNING }
# The shader's PALETTE at wall brightness, so trim matches the building it sits on.
const TONES: Array[Color] = [Color(.54,.52,.47), Color(.5,.47,.41), Color(.54,.54,.52), Color(.47,.47,.46), Color(.45,.4,.35), Color(.35,.2,.15), Color(.27,.13,.11), Color(.08,.09,.1),
	Color(.05,.05,.05), Color(.16,.2,.25), Color(.17,.27,.26), Color(.31,.35,.29), Color(.4,.32,.17), Color(.44,.31,.27), Color(.24,.24,.24), Color(.31,.31,.3)]
const KAWARA: Array[Color] = [Color("#3b3e42"), Color("#4a4d50"), Color("#3c3532"), Color("#2c3640"), Color("#5a5148")]
const BUSINESSES := 128 # Each has a wide and a tall board in the atlas.
const STEEL := Color("#5b5f63")
const CONCRETE := Color("#8d8c88")
const AWNINGS: Array[Color] = [Color("#7c1d22"), Color("#1f4f3a"), Color("#24406e"), Color("#b98a2d"), Color("#3a3a40")]
const ROOFS: Array[Color] = [Color("#3a3f45"), Color("#4a3a33"), Color("#2f4a4c"), Color("#555250")]

const GROUND_SHADER := """
shader_type spatial;
uniform float night = 0.0;
uniform vec2 park_half = vec2(222.0, 182.0);
uniform float block = 64.0;
uniform float road = 7.0;
uniform sampler2D asphalt_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paver_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world;
float hsh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float nz(vec2 p){ vec2 c = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hsh(c), hsh(c+vec2(1,0)), u.x), mix(hsh(c+vec2(0,1)), hsh(c+vec2(1,1)), u.x), u.y); }
void vertex(){ world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 p = world.xz;
	vec2 d = abs(p) - park_half;
	float ring = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
	if (ring < 0.0) discard;
	// Distance to the nearest grid road centre, on each axis.
	vec2 g = abs(mod(p + block * 0.5, block) - block * 0.5);
	float grid = min(g.x, g.y);
	bool on_ring = ring < 14.0;
	float road_mask = (grid < road || on_ring) ? 1.0 : 0.0;
	float walk_mask = (grid < road + 3.0 || ring < 34.0) ? 1.0 : 0.0;
	float tone = nz(p * 0.13) * 0.6 + nz(p * 0.9) * 0.4;
	vec3 asphalt = texture(asphalt_map, p / 7.0).rgb * vec3(0.52, 0.52, 0.56) * mix(0.75, 1.15, tone);
	vec3 paving = texture(paver_map, p / 2.4).rgb * mix(0.62, 0.9, tone);
	vec3 lot = paving * 0.6;
	vec3 c = mix(mix(lot, paving, walk_mask), asphalt, road_mask);
	// Trench repairs, tyre polish in the wheel lines, and a solid edge line.
	float patch_mask = step(0.8, hsh(floor(p / vec2(13.0, 5.0)))) * road_mask;
	c *= 1.0 - 0.22 * patch_mask;
	float lane = abs(fract((on_ring ? ring : grid) / 3.5) - 0.5);
	c *= 1.0 + 0.1 * road_mask * (1.0 - smoothstep(0.0, 0.24, lane)) * nz(p * 0.7);
	float edge = (grid < road && abs(grid - (road - 0.45)) < 0.07) ? 1.0 : 0.0;
	c = mix(c, vec3(0.52, 0.51, 0.47), edge * road_mask * step(road + 4.0, max(g.x, g.y)));
	// Kerb line between pavement and carriageway.
	float kerb = (ring > 0.0 && abs((on_ring ? ring : grid) - (on_ring ? 14.0 : road)) < 0.16) ? 1.0 : 0.0;
	c = mix(c, vec3(0.42, 0.41, 0.39), kerb);
	// Centre dashes on grid roads and on the ring road.
	float along = g.x < g.y ? p.y : p.x;
	float clear_of_junction = step(road + 4.0, max(g.x, g.y));
	float dash = step(0.55, fract(along / 9.0)) * (1.0 - smoothstep(0.08, 0.14, grid)) * clear_of_junction;
	if (on_ring) dash = step(0.55, fract((p.x + p.y) / 9.0)) * (1.0 - smoothstep(0.08, 0.14, abs(ring - 7.0)));
	c = mix(c, vec3(0.62, 0.6, 0.52), dash * road_mask);
	// Zebra crossings across each arm of a junction.
	float bar_x = step(road + 0.5, g.y) * step(g.y, road + 3.4) * step(g.x, road - 0.5) * step(0.5, fract(p.x / 1.5));
	float bar_z = step(road + 0.5, g.x) * step(g.x, road + 3.4) * step(g.y, road - 0.5) * step(0.5, fract(p.y / 1.5));
	if (!on_ring) c = mix(c, vec3(0.6, 0.6, 0.57), max(bar_x, bar_z) * (0.65 + 0.35 * tone));
	// Concrete gutter along the kerb, and the yellow tactile guide strip for the blind.
	if (ring > 14.0 && ring < 14.55) c = mix(c, vec3(0.34, 0.33, 0.31), 0.85);
	if (ring > 16.7 && ring < 17.0) {
		vec2 stud = abs(fract(vec2(p.x + p.y, ring) / 0.075) - 0.5);
		c = vec3(0.62, 0.5, 0.1) * (0.82 + 0.26 * step(length(stud), 0.3));
	}
	ALBEDO = c;
	ROUGHNESS = mix(0.85, 0.7, road_mask);
	SPECULAR = 0.3;
	// Shop light spilling onto the pavements after dark.
	float spill = walk_mask * (1.0 - road_mask) * (0.5 + 0.5 * nz(p * 0.09));
	vec3 hue = mix(vec3(1.0, 0.25, 0.5), vec3(0.2, 0.7, 1.0), nz(p * 0.05 + 3.0));
	EMISSION = hue * spill * 0.03 * night + c * vec3(0.3, 0.26, 0.24) * night;
}
"""

const SIGN_SHADER := """
shader_type spatial;
uniform float night = 0.0;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
varying flat float cell;
varying vec3 box;
varying vec3 box_normal;
varying vec3 world;
varying flat float powered;
void vertex(){
	cell = INSTANCE_CUSTOM.x; box = VERTEX; box_normal = NORMAL; world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// A good share of tenants have shut for the night.
	powered = step(0.42, fract(sin(dot(MODEL_MATRIX[3].xz + cell, vec2(127.1, 311.7))) * 43758.5453));
}
void fragment(){
	if (abs(box_normal.z) < 0.5) {
		ALBEDO = vec3(0.08, 0.085, 0.09);
		ROUGHNESS = 0.5;
	} else {
		float u = box_normal.z > 0.0 ? box.x + 0.5 : 0.5 - box.x;
		vec2 uv = vec2(u, 0.5 - box.y);
		vec2 base; vec2 span;
		if (cell < 127.5) { base = vec2(mod(cell, 8.0) * 0.125, floor(cell / 8.0) * 0.03125); span = vec2(0.125, 0.03125); }
		else { float c = cell - 128.0; base = vec2(mod(c, 32.0) * 0.03125, 0.5 + floor(c / 32.0) * 0.125); span = vec2(0.03125, 0.125); }
		vec3 face = texture(atlas, base + uv * span).rgb;
		face *= 0.8 + 0.2 * smoothstep(0.0, 0.6, uv.y) * (0.8 + 0.2 * sin(uv.x * 19.0 + cell));
		ALBEDO = face * 0.62;
		ROUGHNESS = 0.62;
		// Lightboxes burn hotter in the middle of the panel.
		float falloff = 0.7 + 0.3 * (1.0 - abs(uv.y * 2.0 - 1.0));
		EMISSION = face * falloff * mix(0.02, mix(0.07, 0.72, powered), night);
	}
	// Lit signs punch through the haze at night.
	float haze = 1.0 - exp(-length(world - CAMERA_POSITION_WORLD) * mix(0.00105, 0.00035, night));
	FOG = vec4(mix(vec3(0.66, 0.69, 0.74), vec3(0.035, 0.03, 0.055), night), haze);
}
"""

const TRIM_SHADER := """
shader_type spatial;
uniform float night = 0.0;
varying flat float pattern;
varying flat vec2 span;
varying vec3 box;
varying vec3 box_normal;
varying vec3 world;
float hsh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float nz(vec2 p){ vec2 c = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hsh(c), hsh(c+vec2(1,0)), u.x), mix(hsh(c+vec2(0,1)), hsh(c+vec2(1,1)), u.x), u.y); }
void vertex(){
	pattern = INSTANCE_CUSTOM.x;
	span = INSTANCE_CUSTOM.yz;
	box = VERTEX;
	box_normal = NORMAL;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment(){
	int p = int(pattern + 0.5);
	vec3 c = COLOR.rgb * mix(0.68, 1.06, nz(world.xz * 0.8 + world.y * vec2(0.9, 0.4)));
	float rough = 0.74;
	vec2 at = (box.xy + 0.5) * span;
	if (p == 1) {
		// Balustrade: bars between a top rail and a kick rail.
		bool rail = box.y > 0.42 || box.y < -0.45;
		if (!rail && abs(box_normal.z) > 0.5 && fract(at.x / 0.13) > 0.3) discard;
	} else if (p == 2) {
		c *= 0.5 + 0.5 * step(0.4, fract(at.y / 0.14));
	} else if (p == 5) {
		// Courses of roof tile, with a slight per-tile shift.
		float course = fract(world.y / 0.2);
		float tile = hsh(vec2(floor(world.y / 0.2), floor((world.x + world.z) / 0.3)));
		c *= (0.62 + 0.38 * smoothstep(0.0, 0.3, course)) * (0.88 + 0.2 * tile);
		rough = 0.5;
	} else if (p == 6) {
		// Outdoor unit: louvred casing with a round fan guard on the face.
		vec2 face = box.xy * span - vec2(span.x * 0.14, 0.0);
		float ring = length(face);
		c = COLOR.rgb * (0.82 + 0.18 * step(0.3, fract((box.x + box.y * 0.02) * span.x / 0.05)));
		if (box_normal.z > 0.5 && ring < span.y * 0.4) c = vec3(0.04) + vec3(0.2) * step(0.5, fract(ring / 0.045)) * step(0.05, ring);
		rough = 0.5;
	} else if (p == 7) {
		// Riveted tank bands.
		c *= 0.8 + 0.2 * step(0.1, fract(world.y / 0.55));
		rough = 0.45;
	} else if (p == 8) {
		c = mix(c, vec3(0.86, 0.84, 0.78), step(0.5, fract(at.x / 0.6)));
	} else if (p == 3) {
		c = mix(c, vec3(0.5, 0.56, 0.6), 0.6);
		rough = 0.22;
	} else if (p == 4) {
		c = vec3(0.03, 0.05, 0.09) * (0.8 + 0.5 * step(0.08, fract(at.x / 1.0)) * step(0.08, fract(at.y / 1.6)));
		rough = 0.2;
	}
	// Grime from rain, darkest low on each piece.
	c *= mix(0.78, 1.0, smoothstep(-0.5, 0.2, box.y));
	c *= mix(0.6, 1.0, smoothstep(0.0, 20.0, world.y));
	ALBEDO = c * mix(vec3(1.0), vec3(0.42, 0.34, 0.27), night);
	EMISSION = c * mix(vec3(0.15, 0.11, 0.09), vec3(0.03, 0.035, 0.052), smoothstep(0.0, 20.0, world.y)) * night + c * vec3(0.09, 0.07, 0.04) * (1.0 - night);
	ROUGHNESS = rough;
	float haze = 1.0 - exp(-length(world - CAMERA_POSITION_WORLD) * mix(0.00105, 0.00075, night));
	FOG = vec4(mix(vec3(0.66, 0.69, 0.74), vec3(0.035, 0.03, 0.055), night), haze);
}
"""

const LAMP_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform float night = 0.0;
varying float head;
void vertex(){ head = INSTANCE_CUSTOM.x; }
void fragment(){ ALBEDO = mix(vec3(0.05, 0.055, 0.06), mix(vec3(0.5), vec3(1.0, 0.86, 0.66) * 1.4, night), head); }
"""

var _materials: Array[ShaderMaterial] = []
var _rng := RandomNumberGenerator.new()
var _rows := {"bodies":{}, "trim":{}, "signs":{}, "tanks":{}, "roofs":{}, "slabs":{}, "wedges":{}, "detail":{}, "domes":{}}
var _count := 0
var _hero := Hero.new()
var _trim_layer := "trim"
var _deck: Array[int] = []
var _dealt := 0
var _muted := false # Lays a lot out unseen, so the rest of the city keeps its random sequence.
var _handmade: Array[Node3D] = []
## The gaps _split leaves between lots, for the alley dresser to furnish. Read only.
var alleys: Array[Dictionary] = []
## Set before _ready to lay the city out with the generator and keep every step in `layout`.
var record_layout := false
## Replayable steps, filled while recording. `layout_decks` holds the business decks they refer to.
var layout: Array[Dictionary] = []
var layout_decks: Array = []
## Tests set this to checksum every laid-out part per layer, so two cities can be compared.
var keep_build_data := false
var build_audit := {}
var slow_steps: Array[String] = []
## The city is built in tiles of CHUNK metres, each its own node; while one is being
## built, everything laid out goes to it.
var tiles := {}
var _tile_key := -1
var _tile: Node3D
var _layer_looks := {}
var _shell_look: ShaderMaterial
var _glass_look: ShaderMaterial
## Streaming: tiles closer than load_radius to the camera are built, a few
## milliseconds a frame, nearest first; tiles beyond unload_radius are freed.
var load_radius := 900.0
var unload_radius := 1100.0
var build_budget_ms := 3.0
var _steps_by_tile := {}
var _decks: Array = []
var _queue: Array[int] = []
var _building := -1
var _build_index := 0
var _next_check := 0.0
var _night := false
var _pinned := {}

## False while the boot build is still laying tiles in budgeted slices. Alley
## life (reads alleys and the hand-built list) and the distance boot (scans the
## finished park) wait for it.
var built := false
## Steps laid per slice before the shared loading budget decides whether to yield.
const BOOT_SLICE_MS := 6.0
var _boot_park: Node = null
## Boot only: real shells are generated on WorkerThreadPool, a tile at a time. Each lot
## step queues its shell here; the tile waits in _parked (with its MultiMesh rows) until
## its worker is done, then commits exactly what a synchronous build would have.
var _defer_hero := false
var _hero_jobs: Array = []
var _parked: Array[Dictionary] = []
var _layout_task := -1
var _layout_data: Array = [null]
## Textures the build will load, loaded ahead on a worker (Prefetch.PATHS); held until
## the tiles are laid, so the build's own load() calls find them cached.
var _prefetch_thread: Thread = null
var _prefetched: Array = []
var _prefetch_stop: Array = [false]

func _ready() -> void:
	add_to_group("midori_horizon")
	var started := Time.get_ticks_msec()
	var memory := OS.get_static_memory_usage()
	var horizon := get_parent()
	var park := horizon.get_parent() if horizon != null else null
	# Without incremental loading (tests, tools) checkpoint() never yields, so the
	# city is built in this call exactly as before.
	_boot_park = park
	# Streaming must not lay or begin tiles between the boot slices.
	set_process(false)
	_rng.seed = RNG_SEED
	for i: int in range(BUSINESSES): _deck.append(i)
	_tile = self
	var from_file := not record_layout and FileAccess.file_exists(LAYOUT_PATH)
	# A Thread of its own, not a WorkerThreadPool task: the loader leaks its load tokens
	# for loads made from inside a pool task (74 at exit, measured).
	_prefetch_thread = Thread.new()
	_prefetch_thread.start(Prefetch.run.bind(_prefetched, _prefetch_stop))
	# The layout file is parsed on a worker while the looks are prepared.
	if from_file: _layout_task = WorkerThreadPool.add_task(_parse_layout.bind(_layout_data), false, "near_city.layout_parse")
	var tick := StartupTrace.begin()
	await _prepare_looks()
	StartupTrace.finish("near_city.looks", tick)
	_build_ground()
	await _boot_checkpoint()
	tick = StartupTrace.begin()
	if not from_file: _build_blocks()
	else: await _build_from_layout()
	StartupTrace.finish("near_city.tiles", tick)
	if not is_inside_tree(): return
	# Everything that loads them has been built: the cache keeps what is still in use.
	if _sliced():
		while is_inside_tree() and _prefetch_thread.is_alive(): await get_tree().process_frame
	_prefetch_thread.wait_to_finish()
	_prefetch_thread = null
	_prefetched.clear()
	if not is_inside_tree(): return
	var laid_out := Time.get_ticks_msec()
	tick = StartupTrace.begin()
	_build_ring_street()
	await _boot_checkpoint()
	_build_expressway()
	await _boot_checkpoint()
	_build_viaduct()
	await _boot_checkpoint()
	_build_landmark()
	await _boot_checkpoint()
	_commit_layers()
	StartupTrace.finish("near_city.extras", tick)
	if not is_inside_tree(): return
	set_night_mode(park != null and park.get("is_night_mode") == true)
	built = true
	set_process(true)
	print("MIDORI_NEAR_CITY: buildings %d, lots laid out in %d ms, built in %d ms, %d MB" % [_count, laid_out - started, Time.get_ticks_msec() - started, (OS.get_static_memory_usage() - memory) / 1048576])

func _notification(what: int) -> void:
	# Every WorkerThreadPool task must be waited for, even if the city is freed mid-boot.
	if what == NOTIFICATION_PREDELETE:
		_prefetch_stop[0] = true
		if _prefetch_thread != null: _prefetch_thread.wait_to_finish()
		_prefetch_thread = null
		if _layout_task >= 0: WorkerThreadPool.wait_for_task_completion(_layout_task)
		_layout_task = -1
		for job: Dictionary in _parked:
			if int(job.task) >= 0: WorkerThreadPool.wait_for_task_completion(int(job.task))
		_parked.clear()

func _boot_checkpoint() -> void:
	if is_instance_valid(_boot_park): await Budget.checkpoint(_boot_park)

func _sliced() -> bool:
	return is_instance_valid(_boot_park) and bool(_boot_park.get_meta("shinrai_incremental_loading", false))

static func _parse_layout(out: Array) -> void:
	# Worker: pure file read and JSON parse; the result is only read after the task is waited for.
	out[0] = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))

func _wait_task(task: int) -> void:
	# Lets the frame go while a worker runs (the budget is not spent on spinning), then joins it.
	if _sliced():
		while is_inside_tree() and not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)

func _process(delta: float) -> void:
	if _steps_by_tile.is_empty(): return
	_next_check -= delta
	if _next_check <= 0.0:
		_next_check = .5
		update_streaming(_focus())
	if _building < 0 and not _queue.is_empty(): _begin_tile(_queue.pop_front())
	if _building >= 0: _lay_tile(build_budget_ms)

func _focus() -> Vector2:
	# Where the player looks from, in the city's frame; the park centre before there is a camera.
	var eye := get_viewport().get_camera_3d() if is_inside_tree() else null
	if eye == null: return Vector2.ZERO
	var at := to_local(eye.global_position)
	return Vector2(at.x, at.z)

## Queues every tile within load_radius of focus and frees those beyond unload_radius.
func update_streaming(focus: Vector2) -> void:
	for key: int in _steps_by_tile:
		var distance := _tile_distance(key, focus)
		if distance < load_radius and not tiles.has(key) and key != _building and not _queue.has(key):
			_queue.append(key)
		elif distance > unload_radius:
			_queue.erase(key)
			if tiles.has(key) and key != _building and not _pinned.has(key): _unload_tile(key)
	_queue.sort_custom(func(a: int, b: int) -> bool: return _tile_distance(a, focus) < _tile_distance(b, focus))

## True once nothing is queued or half built.
func is_streaming_idle() -> bool:
	return _building < 0 and _queue.is_empty()

## End-of-boot hook (shinrai_world_complete.gd): drops the layout steps and business decks.
## Every tile lies within ~680 m of the centre while load_radius is 900 and unload_radius
## 1100, so once the boot build is done nothing ever streams in or out again and the parsed
## layout (10-30x the 2.6 MB JSON as Dictionaries) is dead weight. Re-parse LAYOUT_PATH from
## disk if streaming is ever needed. Returns the counts freed, for the record only.
func release_build_data() -> Dictionary:
	if not built or _building >= 0 or not _queue.is_empty() or not _parked.is_empty(): return {"skipped": "building"}
	var freed := {"steps_by_tile": _steps_by_tile.size(), "decks": _decks.size()}
	_steps_by_tile = {}
	_decks = []
	set_process(false) # _process only ever streamed tiles from _steps_by_tile.
	return freed

func _tile_distance(key: int, focus: Vector2) -> float:
	var centre := _tile_centre(key)
	var d := (focus - centre).abs() - Vector2(CHUNK, CHUNK) * .5
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length()

func _unload_tile(key: int) -> void:
	var tile: Node3D = tiles[key]
	tiles.erase(key)
	for building: Node3D in _handmade.duplicate():
		if building.get_parent() == tile: _handmade.erase(building)
	tile.queue_free()

func set_night_mode(value: bool) -> void:
	_night = value
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("night", 1.0 if value else 0.0)
	for building: Node3D in _handmade:
		building.set_night_mode(value)

func _material(code: String, label: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	return _shader_material(shader, label)

func _shader_material(shader: Shader, label: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.resource_name = label
	_materials.append(material)
	return material

static func _mip(image: Image) -> void:
	# Pure Image work, safe on a worker: the same steps on the same pixels give the same maps.
	# The wall textures and sign atlas are imported BC7 with mipmaps (fix 2), which is exactly
	# what the arrays need: nothing to do. Anything else is decoded, mipmapped and then BC7
	# compressed here, so the GPU holds a quarter of the RGBA8 bytes either way.
	if image.is_compressed() and image.has_mipmaps(): return
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.generate_mipmaps()
	image.compress(Image.COMPRESS_BPTC)

func _mipped_all(paths: Array[String]) -> Array:
	# Textures are fetched on the main thread (that talks to the renderer); decompressing,
	# converting and mipping them runs on workers while the next ones are fetched. The
	# main thread leaves each image alone until its task is joined.
	var images: Array = []
	var tasks: Array[int] = []
	for path: String in paths:
		var image: Image = (load(path) as Texture2D).get_image()
		images.append(image)
		tasks.append(WorkerThreadPool.add_task(_mip.bind(image), false, "near_city.mip"))
		await _boot_checkpoint()
	for task: int in tasks: await _wait_task(task)
	return images

func _wall_array(images: Array) -> Texture2DArray:
	var typed: Array[Image] = []
	for image: Image in images: typed.append(image)
	var array := Texture2DArray.new()
	array.create_from_images(typed)
	return array

func _chunk_key(at: Vector2) -> int:
	return int((at.x + HALF_EXTENT) / CHUNK) + 100 * int((at.y + HALF_EXTENT) / CHUNK)

func _put(layer: String, at: Vector3, xform: Transform3D, custom := Color(), color := Color.WHITE) -> void:
	if _muted: return
	if keep_build_data: _audit(layer, [xform, custom, color])
	var key := _tile_key if _tile_key >= 0 else _chunk_key(Vector2(at.x, at.z))
	var table: Dictionary = _rows[layer]
	if not table.has(key): table[key] = []
	table[key].append([xform, custom, color])

func _note_slow(what: String, started: int) -> void:
	var ms := (Time.get_ticks_usec() - started) / 1000.0
	if ms > 30.0: slow_steps.append("%s %.0f ms" % [what, ms])

func _audit(layer: String, row: Array) -> void:
	# Order-free checksum per layer, so cities grouped differently still compare.
	var h := hash(row)
	var sums: Array = build_audit.get(layer, [0, 0, 0])
	sums[0] += 1
	sums[1] += h
	sums[2] = sums[2] ^ h
	build_audit[layer] = sums

func _prepare_looks() -> void:
	var paths: Array[String] = [SIGN_ATLAS]
	for id: String in WALLS: paths.append(TEXTURES + id + "_diff.jpg")
	for id: String in WALLS: paths.append(TEXTURES + id + "_nor.jpg")
	var images: Array = await _mipped_all(paths)
	var trim_look := _material(TRIM_SHADER, "SHINRAI_NearCityTrim")
	var slab_look := StandardMaterial3D.new()
	slab_look.albedo_texture = load(PAVER_ALBEDO)
	slab_look.albedo_color = Color(.82, .81, .8)
	slab_look.uv1_triplanar = true
	slab_look.uv1_world_triplanar = true
	slab_look.uv1_scale = Vector3.ONE * .4
	slab_look.roughness = .86
	var sign_look := _material(SIGN_SHADER, "SHINRAI_NearCitySigns")
	sign_look.set_shader_parameter("atlas", ImageTexture.create_from_image(images[0]))
	var body_look := _shader_material(BUILDING_SHADER, "SHINRAI_NearCityBuildings")
	await _boot_checkpoint()
	var wall_maps: Texture2DArray = _wall_array(images.slice(1, 1 + WALLS.size()))
	await _boot_checkpoint()
	var wall_normals: Texture2DArray = _wall_array(images.slice(1 + WALLS.size()))
	images.clear() # The GPU has them; the CPU copies go before the tiles start.
	body_look.set_shader_parameter("wall_maps", wall_maps)
	body_look.set_shader_parameter("wall_normals", wall_normals)
	_shell_look = _shader_material(SHELL_SHADER, "SHINRAI_NearCityShell")
	_shell_look.set_shader_parameter("wall_maps", wall_maps)
	_shell_look.set_shader_parameter("wall_normals", wall_normals)
	_glass_look = _shader_material(GLASS_SHADER, "SHINRAI_NearCityGlass")
	var tank := CylinderMesh.new()
	tank.radial_segments = 14
	tank.rings = 1
	tank.top_radius = .5
	tank.bottom_radius = .5
	tank.height = 1.0
	var dome := SphereMesh.new()
	dome.radial_segments = 12
	dome.rings = 5
	dome.radius = .5
	dome.height = 1.0
	var wedge := PrismMesh.new()
	wedge.left_to_right = 0.0
	# Layer: mesh, look, casts shadows.
	_layer_looks = {"bodies":[BoxMesh.new(), body_look, true], "trim":[BoxMesh.new(), trim_look, false], "detail":[BoxMesh.new(), trim_look, true],
		"domes":[dome, trim_look, false], "signs":[BoxMesh.new(), sign_look, false], "tanks":[tank, trim_look, false],
		"roofs":[PrismMesh.new(), trim_look, true], "slabs":[BoxMesh.new(), slab_look, false], "wedges":[wedge, trim_look, true]}

func _commit_layers(parent: Node3D = self) -> void:
	# Commits everything laid out so far under parent, then starts the tables afresh.
	_commit_hero(parent)
	for layer: String in _layer_looks:
		var look: Array = _layer_looks[layer]
		_commit_layer(layer, look[0], look[1], look[2], parent)
		_rows[layer] = {}

func _commit_hero(parent: Node3D) -> void:
	_commit_shells(_hero, parent)
	_hero = Hero.new()

static func _run_shells(job: Dictionary) -> void:
	# Worker: a fresh Hero over the tile's shells in the order the steps queued them, so
	# its arrays are exactly what adding them one by one on the main thread made.
	var hero: Hero = job.hero
	for row: Array in job.adds:
		hero.add(row[0], row[1], row[2], row[3], row[4], row[5])

func _park_tile() -> void:
	# The tile's steps are laid; its shells go to a worker and the tile commits once they are done.
	var job := {"tile":_tile, "key":_building, "rows":_rows, "adds":_hero_jobs, "hero":Hero.new()}
	job.task = WorkerThreadPool.add_task(_run_shells.bind(job), false, "near_city.shells")
	_parked.append(job)
	_hero_jobs = []
	_rows = {}
	for layer: String in _layer_looks: _rows[layer] = {}

func _commit_parked(wait: bool, at_most := 1 << 30) -> void:
	# Commits parked tiles whose shells are done (waiting for them when wait is set), in the
	# order they were parked: shells first, then each layer, as _commit_layers does.
	var left := at_most
	while not _parked.is_empty() and left > 0:
		left -= 1
		var job: Dictionary = _parked[0]
		if not wait and not WorkerThreadPool.is_task_completed(int(job.task)): return
		WorkerThreadPool.wait_for_task_completion(int(job.task))
		job.task = -1
		_parked.pop_front()
		var tile: Node3D = job.tile
		if not is_instance_valid(tile): continue
		var commit_started := Time.get_ticks_usec()
		var live_rows := _rows
		_rows = job.rows
		_commit_shells(job.hero, tile)
		for layer: String in _layer_looks:
			var look: Array = _layer_looks[layer]
			_commit_layer(layer, look[0], look[1], look[2], tile)
		_rows = live_rows
		if keep_build_data: _note_slow("tile %d commit" % int(job.key), commit_started)

func _commit_shells(hero: Hero, parent: Node3D) -> void:
	var walls: Dictionary = hero.walls()
	var panes: Dictionary = hero.glass()
	for key: int in walls:
		_commit_part("NearCityShell_%d" % key, Hero.mesh_of(walls[key]), _shell_look, true, parent)
		if panes.has(key) and not panes[key].v.is_empty():
			_commit_part("NearCityPanes_%d" % key, Hero.mesh_of(panes[key]), _glass_look, false, parent)

func _commit_part(label: String, mesh: Mesh, material: Material, shadows: bool, parent: Node3D = self) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)

func _hero_spec(kind: int, seed_value: float, storey: float, ground: float) -> Dictionary:
	# A building's look follows from one seed, so its parts all agree.
	var pick := fposmod(seed_value * 97.0, 1.0)
	var index := int(fposmod(seed_value * 23.0, 1.0) * 16.0)
	var pale := fposmod(seed_value * 7.3, 1.0)
	var layer: int = 6 if pale < .3 else (7 if pale < .5 else (8 if pale < .68 else (0 if pale < .84 else 3)))
	var spec := {"seed":seed_value, "storey":storey, "ground":ground, "mansion":kind == Kind.MANSION, "metal":Color(.5, .52, .54, 1.0),
		"radius":.06, "bay":3.2, "pane_x":.3, "pane_y":.8, "sill":.5, "recess":.2, "detail":0}
	if fposmod(seed_value * 151.0, 1.0) < .3: spec.radius = 1.0 + fposmod(seed_value * 211.0, 1.0) * 1.4
	if kind == Kind.LOW:
		spec.bay = 2.6 + fposmod(seed_value * 13.0, 1.0)
		spec.pane_x = .22
		spec.pane_y = .58
		spec.sill = .55
		spec.recess = .08
		layer = 2 if pale < .5 else (7 if pale < .82 else 4)
	elif kind == Kind.KONBINI:
		layer = 7
		index = 2
		spec.parapet = .3
	elif kind == Kind.GARAGE:
		spec.deck = true
		spec.pane_y = .62
		spec.sill = .6
		spec.recess = .9
		layer = 3
		index = 15
	elif kind == Kind.MANSION or kind == Kind.DANCHI:
		spec.bay = 3.0 + fposmod(seed_value * 13.0, 1.0)
		spec.mansion = true
		if kind == Kind.DANCHI:
			layer = 7
			index = 2
		spec.pane_x = .42
		spec.pane_y = 1.12
		spec.sill = .42
		spec.recess = .16
		spec.radius = .06
	elif pick < .2:
		spec.bay = 1.7
		spec.pane_x = .46
		spec.pane_y = .72
		spec.recess = .12
	elif pick < .36:
		spec.bay = 2.8
		spec.pane_x = .42
		spec.pane_y = storey * .4
		spec.recess = .7
		layer = 3
		index = 15
	elif pick < .5:
		spec.bay = 1.9
		spec.pane_x = .12
		spec.pane_y = storey * .42
		spec.recess = .26
		layer = 4 if pick < .43 else 2
		index = 7 if pick < .43 else 8
		spec.metal = Color(.1, .1, .11, 1.0)
	elif pick < .66:
		spec.bay = 5.0
		spec.pane_x = .38
		spec.pane_y = 1.05
	elif pick < .82:
		spec.bay = 2.2
		spec.pane_x = .3
		spec.pane_y = .62
	var tint: Color = PALETTE[index]
	tint.a = float(layer) / 8.0
	spec["tint"] = tint
	spec.lobby = kind == Kind.ZAKKYO or kind == Kind.OFFICE
	spec.quoin = fposmod(seed_value * 127.0, 1.0) < .35
	spec.undercroft = (kind == Kind.MANSION or kind == Kind.DANCHI) and fposmod(seed_value * 53.0, 1.0) < .45
	if kind != Kind.MANSION and kind != Kind.DANCHI and (pick < .2 or (pick >= .66 and pick < .82)):
		# Spandrels in their own finish: dark panel on pale, or pale on dark.
		var contrast: Color = PALETTE[14] if tint.get_luminance() > .5 else PALETTE[3]
		contrast.a = 1.0 / 8.0 if tint.get_luminance() > .5 else 7.0 / 8.0
		spec.band = contrast
	return spec

func _place_body(centre: Vector2, base: float, size: Vector3, kind: int, front: int, seed_value: float, storey: float, ground: float, distance: float, flat_roof := true) -> bool:
	# True when the body became a real shell rather than a shader box.
	var eligible := kind != Kind.GLASS and kind != Kind.CORE
	if distance > SHELL_RANGE or not eligible:
		_box_body(centre, base, size, kind, front, seed_value)
		return false
	var key := _tile_key if _tile_key >= 0 else _chunk_key(centre)
	var spec := _hero_spec(kind, seed_value, storey, ground)
	spec.detail = 0 if distance < HERO_RANGE else 1
	# A rounded corner must stay a corner, never turn a slim building into a drum.
	spec.radius = minf(spec.radius, minf(size.x, size.z) * .16)
	spec.parapet = spec.get("parapet", .9) if flat_roof else 0.0
	if not _muted:
		if keep_build_data: _audit("shells", [centre, base, size, front, spec])
		if _defer_hero: _hero_jobs.append([centre, base, size, front, key, spec])
		else: _hero.add(centre, base, size, front, key, spec)
	return true

func _commit_layer(layer: String, mesh: Mesh, material: Material, shadows: bool, parent: Node3D = self) -> void:
	var table: Dictionary = _rows[layer]
	for key: int in table:
		var rows: Array = table[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.use_colors = true
		multimesh.mesh = mesh
		multimesh.instance_count = rows.size()
		for i: int in range(rows.size()):
			var row: Array = rows[i]
			multimesh.set_instance_transform(i, row[0])
			multimesh.set_instance_custom_data(i, row[1])
			multimesh.set_instance_color(i, row[2])
		var instance := MultiMeshInstance3D.new()
		instance.name = "NearCity_%s_%d" % [layer, key]
		instance.multimesh = multimesh
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		parent.add_child(instance)

func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF_EXTENT * 2.0 + 40.0, HALF_EXTENT * 2.0 + 40.0)
	var ground := MeshInstance3D.new()
	ground.name = "NearCityGround"
	ground.mesh = plane
	var look := _material(GROUND_SHADER, "SHINRAI_NearCityGround")
	look.set_shader_parameter("asphalt_map", load(ROAD_ALBEDO))
	look.set_shader_parameter("paver_map", load(PAVER_ALBEDO))
	ground.material_override = look
	ground.position.y = -.08
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

func _fit_lot(lot: Rect2) -> Rect2:
	# Trims a lot back from the ring road, so park-side blocks build up to it.
	var limit := PARK.grow(PARK_MARGIN)
	if not limit.intersects(lot): return lot
	var fitted := lot
	if lot.position.x < limit.position.x and lot.end.x > limit.position.x: fitted.end.x = limit.position.x
	elif lot.end.x > limit.end.x and lot.position.x < limit.end.x: fitted.position.x = limit.end.x; fitted.size.x = lot.end.x - limit.end.x
	elif lot.position.y < limit.position.y and lot.end.y > limit.position.y: fitted.end.y = limit.position.y
	elif lot.end.y > limit.end.y and lot.position.y < limit.end.y: fitted.position.y = limit.end.y; fitted.size.y = lot.end.y - limit.end.y
	return fitted

func _clear_of_reserved(lot: Rect2) -> bool:
	if PARK.grow(PARK_MARGIN).intersects(lot): return false
	for zone: Rect2 in CLEAR_ZONES:
		if zone.intersects(lot): return false
	return true

func _park_distance(p: Vector2) -> float:
	var d := p.abs() - PARK.size * .5
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length()

func _in_cluster(p: Vector2) -> bool:
	for centre: Vector2 in CLUSTERS:
		if centre.distance_to(p) < CLUSTER_RADIUS: return true
	return false

func _build_blocks() -> void:
	var inner := BLOCK - (ROAD + WALK) * 2.0
	var count := int(HALF_EXTENT * 2.0 / BLOCK)
	for j: int in range(count):
		for i: int in range(count):
			var origin := (Vector2(-HALF_EXTENT + BLOCK * float(i), -HALF_EXTENT + BLOCK * float(j)) / BLOCK).floor() * BLOCK + Vector2(ROAD + WALK, ROAD + WALK)
			var block := _fit_lot(Rect2(origin, Vector2(inner, inner)))
			if block.size.x < MIN_LOT or block.size.y < MIN_LOT: continue
			_record({"t":"pave", "block":_rect_data(block)})
			_add_pavement(block)
			var centre := block.get_center()
			if _in_cluster(centre) and _rng.randf() < .55:
				if _clear_of_reserved(block):
					_record({"t":"tower", "block":_rect_data(block)})
					_add_tower(block)
				continue
			# Arterials and the park edge are commercial; the rest is back streets.
			var commercial := i % 4 == 0 or j % 4 == 0 or _park_distance(centre) < 50.0
			_split(block, block, commercial)

func _add_pavement(block: Rect2) -> void:
	# Raised slab with a real kerb.
	var slab := block.grow(WALK)
	if PARK.grow(18.0).intersects(slab): return
	for zone: Rect2 in CLEAR_ZONES:
		if zone.intersects(slab): return
	var mid := slab.get_center()
	_put("slabs", Vector3(mid.x, 0, mid.y), _xform(Vector3(mid.x, -.02, mid.y), Vector3(slab.size.x, .2, slab.size.y)))
	if _park_distance(mid) < 240.0:
		_pole_line(Vector2(slab.position.x, slab.end.y), slab.end, Vector2(0, 1))
		_pole_line(Vector2(slab.end.x, slab.position.y), slab.end, Vector2(1, 0))

func _pole_line(a: Vector2, b: Vector2, outward: Vector2) -> void:
	# Concrete poles on every street, carrying sagging lines and service drops.
	var run := (b - a).normalized()
	var bar := Vector3(outward.x, 0, outward.y)
	var steps := maxi(1, int(a.distance_to(b) / 15.0))
	var previous := Vector3.ZERO
	for i: int in range(steps + 1):
		var p := a.lerp(b, float(i) / float(steps)) - outward * .35
		var top := Vector3(p.x, 10.0, p.y)
		_put("tanks", top, _xform(Vector3(p.x, 5.0, p.y), Vector3(.3, 10.0, .3)), Color(), Color("#6f6e68"))
		_put("trim", top, Transform3D(Basis(bar * 1.5, Vector3.UP * .09, Vector3.UP.cross(bar) * .09), top - Vector3.UP * .5), Color(), Color("#3a3a38"))
		if i % 2 == 0: _put("tanks", top, _xform(top - Vector3(0, 2.0, 0) + bar * .3, Vector3(.5, .95, .5)), Color(), Color("#6f7472"))
		if i > 0:
			for offset: float in [-.6, 0.0, .6]:
				_wire(previous - Vector3.UP * .42 + bar * offset, top - Vector3.UP * .42 + bar * offset)
			# A thicker telecom bundle hangs lower on the pole.
			_wire(previous - Vector3.UP * 3.4, top - Vector3.UP * 3.4)
		# Service drop across the pavement to the nearest frontage.
		var drop := top - Vector3.UP * .42 - bar * 3.4 + Vector3(run.x, 0, run.y) * _rng.randf_range(-3.0, 3.0) + Vector3.DOWN * _rng.randf_range(2.0, 3.5)
		_wire(top - Vector3.UP * .42, drop)
		previous = top

func _split(rect: Rect2, block: Rect2, commercial: bool) -> void:
	var limit := _rng.randf_range(6.5, 12.0) if commercial else _rng.randf_range(8.0, 15.0)
	if rect.size.x <= limit and rect.size.y <= limit * 1.7:
		_record({"t":"lot", "rect":_rect_data(rect), "block":_rect_data(block), "commercial":commercial})
		_lay_lot(rect, block, commercial)
		return
	var cut := _rng.randf_range(.38, .62)
	var alley := _rng.randf_range(.3, 1.4) * .5
	if rect.size.x * 1.25 >= rect.size.y:
		var at := rect.size.x * cut
		alleys.append({"rect":Rect2(rect.position.x + at - alley, rect.position.y, alley * 2.0, rect.size.y), "commercial":commercial})
		_split(Rect2(rect.position, Vector2(at - alley, rect.size.y)), block, commercial)
		_split(Rect2(rect.position + Vector2(at + alley, 0), Vector2(rect.size.x - at - alley, rect.size.y)), block, commercial)
	else:
		var at := rect.size.y * cut
		alleys.append({"rect":Rect2(rect.position.x, rect.position.y + at - alley, rect.size.x, alley * 2.0), "commercial":commercial})
		_split(Rect2(rect.position, Vector2(rect.size.x, at - alley)), block, commercial)
		_split(Rect2(rect.position + Vector2(0, at + alley), Vector2(rect.size.x, rect.size.y - at - alley)), block, commercial)

func _lay_lot(rect: Rect2, block: Rect2, commercial: bool) -> void:
	var design := _design_for(rect)
	_muted = design != null
	_lot(rect, block, commercial)
	_muted = false
	if design != null:
		var building: Node3D = design.new()
		building.position = Vector3(rect.get_center().x, .08, rect.end.y)
		_tile.add_child(building)
		_handmade.append(building)
		if _night: building.set_night_mode(true)
		# Hand-built buildings take up to 1.5 s each to build, too long for a frame,
		# so their tiles stay once built. Only generic tiles stream.
		if _tile_key >= 0: _pinned[_tile_key] = true

func _record(step: Dictionary) -> void:
	# Keeps the random state and business deck each step starts from, so replaying
	# it from the file builds exactly what the generator built, in any order.
	if not record_layout: return
	if layout_decks.is_empty() or layout_decks[-1] != _deck: layout_decks.append(_deck.duplicate())
	step.rng = str(_rng.state)
	step.deck = layout_decks.size() - 1
	step.dealt = _dealt
	layout.append(step)

func _build_from_layout() -> void:
	await _wait_task(_layout_task)
	_layout_task = -1
	var data: Variant = _layout_data[0]
	_layout_data[0] = null
	if not data is Dictionary:
		push_error("City layout unreadable, laying the city out live: " + LAYOUT_PATH)
		_build_blocks()
		return
	for values: Array in data.decks:
		var deck: Array[int] = []
		for value: Variant in values: deck.append(int(value))
		_decks.append(deck)
	# Each step belongs to the tile its lot or block centre falls in.
	for step: Dictionary in data.steps:
		var anchor := _rect_of(step.rect if step.t == "lot" else step.block)
		var key := _chunk_key(anchor.get_center())
		if not _steps_by_tile.has(key): _steps_by_tile[key] = []
		_steps_by_tile[key].append(step)
	for alley: Dictionary in data.alleys:
		alleys.append({"rect":_rect_of(alley.rect), "commercial":bool(alley.commercial)})
	# Everything in reach of the park is built now, nearest first, so the city is whole
	# when the raid starts; the rest streams in as the camera moves.
	# Steps restore their own random state and deck, so laying a tile across
	# several frames builds exactly what one call did (same tiles, same order).
	update_streaming(Vector2.ZERO)
	# Shells are generated on workers while the main thread lays the next tiles.
	_defer_hero = true
	while not _queue.is_empty():
		_begin_tile(_queue.pop_front())
		var sliced := _sliced()
		while _building >= 0:
			_lay_tile(BOOT_SLICE_MS if sliced else 0.0)
			if _building >= 0: await _boot_checkpoint()
			if not is_inside_tree():
				_defer_hero = false
				return
		# A finished tile commits between slices; unsliced builds (tests, tools) commit at the end.
		if sliced: _commit_parked(false, 1)
		await _boot_checkpoint()
	_defer_hero = false
	# The last tiles' shells: let frames go while the workers finish, then commit.
	while not _parked.is_empty():
		if not _sliced():
			_commit_parked(true)
			break
		if not WorkerThreadPool.is_task_completed(int(_parked[0].task)):
			await get_tree().process_frame
			if not is_inside_tree(): return
			continue
		_commit_parked(false, 1)
		await _boot_checkpoint()

func _tile_centre(key: int) -> Vector2:
	return Vector2((float(key % 100) + .5) * CHUNK - HALF_EXTENT, (floorf(key / 100.0) + .5) * CHUNK - HALF_EXTENT)

func _begin_tile(key: int) -> void:
	var tile := Node3D.new()
	tile.name = "NearCityTile_%d" % key
	add_child(tile)
	tiles[key] = tile
	_tile = tile
	_tile_key = key
	_building = key
	_build_index = 0

func _lay_tile(budget_ms: float) -> void:
	# Lays the tile's steps until the budget is spent (0: all of them), then commits it.
	var steps: Array = _steps_by_tile[_building]
	var until := Time.get_ticks_usec() + int(budget_ms * 1000.0)
	while _build_index < steps.size():
		var step: Dictionary = steps[_build_index]
		_build_index += 1
		# Every step starts from the random state and deck it was laid out from.
		_rng.state = str(step.rng).to_int()
		_deck.assign(_decks[int(step.deck)])
		_dealt = int(step.dealt)
		var step_started := Time.get_ticks_usec()
		match str(step.t):
			"pave": _add_pavement(_rect_of(step.block))
			"tower": _add_tower(_rect_of(step.block))
			"lot": _lay_lot(_rect_of(step.rect), _rect_of(step.block), bool(step.commercial))
		if keep_build_data:
			var design := _design_for(_rect_of(step.rect)) if step.t == "lot" else null
			_note_slow("tile %d %s %s" % [_building, step.t, design.resource_path.get_file() if design != null else "generic"], step_started)
		if budget_ms > 0.0 and Time.get_ticks_usec() > until: return
	if _defer_hero:
		_park_tile()
	else:
		var commit_started := Time.get_ticks_usec()
		_commit_layers(_tile)
		if keep_build_data: _note_slow("tile %d commit" % _building, commit_started)
	_tile = self
	_tile_key = -1
	_building = -1

func _rect_data(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _rect_of(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))

func _design_for(rect: Rect2) -> GDScript:
	for row: Array in HANDMADE:
		if rect.has_point(row[0]): return row[1]
	return null

func _lot(lot: Rect2, block: Rect2, commercial: bool) -> void:
	if lot.size.x < MIN_LOT or lot.size.y < MIN_LOT or not _clear_of_reserved(lot): return
	var roll := _rng.randf()
	var kind := Kind.LOW
	var floors := 2
	if commercial:
		# Old two-storey infill survives between tall neighbours.
		if roll < .42: kind = Kind.ZAKKYO; floors = _rng.randi_range(3, 10)
		elif roll < .6: kind = Kind.OFFICE; floors = _rng.randi_range(4, 12)
		elif roll < .74: kind = Kind.MANSION; floors = _rng.randi_range(5, 13)
		elif roll < .8: kind = Kind.GARAGE; floors = _rng.randi_range(3, 6)
		elif lot.size.x > 9.0 and lot.size.y > 8.0 and roll < .86: kind = Kind.KONBINI; floors = 1
		else: kind = Kind.LOW; floors = _rng.randi_range(2, 3)
	else:
		if roll < .6:
			_add_house(lot, block)
			return
		elif roll < .84: kind = Kind.MANSION; floors = _rng.randi_range(4, 9)
		elif roll < .92: kind = Kind.DANCHI; floors = _rng.randi_range(4, 7)
		else: kind = Kind.ZAKKYO; floors = _rng.randi_range(3, 5)
	_add_building(lot, block, kind, floors)

func _add_house(lot: Rect2, block: Rect2) -> void:
	# Detached two-storey house inside a block wall, with a tiled roof and a pent roof.
	var plot := lot
	var house := lot.grow(-1.0)
	if house.size.x < 5.0 or house.size.y < 5.0: house = lot
	var b := _add_building(house, block, Kind.LOW, 2, true)
	var pos: Vector2 = b.pos
	var key := Vector3(pos.x, 0, pos.y)
	var fence := Color("#77766f")
	var mid := plot.get_center()
	for row: Array in [[Vector3(mid.x, .65, plot.position.y), Vector3(plot.size.x, 1.3, .14)], [Vector3(mid.x, .65, plot.end.y), Vector3(plot.size.x, 1.3, .14)], [Vector3(plot.position.x, .65, mid.y), Vector3(.14, 1.3, plot.size.y)], [Vector3(plot.end.x, .65, mid.y), Vector3(.14, 1.3, plot.size.y)]]:
		_put("trim", key, _xform(row[0], row[1]), Color(), fence)
	if _park_distance(pos) > NEAR_TIER: return
	var width: float = b.across
	var colour: Color = KAWARA[_rng.randi_range(0, KAWARA.size() - 1)]
	# Pent roof over the ground floor.
	var at := _front_at(b, 0.0, 3.05, .55)
	var pent := Basis(b.out * 1.2, Vector3.UP * .55, b.right * -(width * .8))
	_put("wedges", at, Transform3D(pent, at), Color(Pattern.ROOF_TILE, 0, 0, 0), colour)
	# Sheet hoods over the upper windows, and a small drying balcony.
	var bay := width / maxf(1.0, floorf(width / (2.6 + fposmod(float(b.seed) * 13.0, 1.0)) + .5))
	for i: int in range(int(round(width / bay))):
		_trim(b, -width * .5 + bay * (float(i) + .5), 5.0, .22, Vector3(1.4, .05, .44), Color("#8d8f8c"))
	if _rng.randf() < .5:
		_trim(b, 0.0, 3.18, .45, Vector3(width * .5, .12, .9), Color("#a9a9a4"))
		_trim(b, 0.0, 3.7, .88, Vector3(width * .5, .9, .05), Color("#7c8083"), Pattern.BARS)

func _add_tower(block: Rect2) -> void:
	var podium := block.grow(-1.0)
	var low := _add_building(podium, block, Kind.OFFICE, _rng.randi_range(4, 7))
	var pos: Vector2 = low.pos
	var key := Vector3(pos.x, 0, pos.y)
	# Heights differ and shafts step in, so no two towers read as a matched pair.
	var base := float(low.height)
	var size := Vector3(podium.size.x * _rng.randf_range(.52, .8), 0.0, podium.size.y * _rng.randf_range(.52, .8))
	var total := _rng.randf_range(28.0, 112.0)
	var kind := Kind.GLASS if _rng.randf() < .6 else Kind.OFFICE
	var stages := _rng.randi_range(1, 3)
	for stage: int in range(stages):
		size.y = total * (1.0 / float(stages)) * _rng.randf_range(.8, 1.2)
		_box_body(pos, base, size, kind, low.front, _rng.randf())
		base += size.y
		size.x *= _rng.randf_range(.68, .86)
		size.z *= _rng.randf_range(.68, .86)
	var crown := Vector3(size.x * .6, _rng.randf_range(2.5, 6.0), size.z * .6)
	_put("trim", key, _xform(Vector3(pos.x, base + crown.y * .5, pos.y), crown), Color(), Color("#20262c"))
	if _rng.randf() < .5:
		_put("trim", key, _xform(Vector3(pos.x, base + crown.y + 6.0, pos.y), Vector3(.5, 12.0, .5)), Color(), STEEL)

func _box_body(pos: Vector2, base: float, size: Vector3, kind: int, front: int, seed_value: float) -> void:
	var code := float(kind) + float(front) * 10.0 + seed_value * .998
	var at := Vector3(pos.x, base + size.y * .5, pos.y)
	_put("bodies", at, _xform(at, size), Color(code, size.x / 1000.0, size.y / 1000.0, size.z / 1000.0))

func _xform(at: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), at)

func _bay(width: float, seed_value: float) -> float:
	# Mirrors the shader, so balcony fins land on its window grid.
	var base := 3.0 + fposmod(seed_value * 13.0, 1.0)
	return width / maxf(1.0, floorf(width / base + .5))

func _add_building(lot: Rect2, block: Rect2, kind: int, floors: int, house := false) -> Dictionary:
	var centre := lot.get_center()
	var gaps: Array[float] = [block.end.x - lot.end.x, lot.position.x - block.position.x, block.end.y - lot.end.y, lot.position.y - block.position.y]
	var front := gaps.find(gaps.min())
	# Where a lot touches the park road, its front addresses the park.
	var edge := centre.abs() - PARK.size * .5
	if maxf(edge.x, edge.y) < 44.0 + maxf(lot.size.x, lot.size.y) * .5:
		var toward: int = (2 if centre.y > 0.0 else 3) if edge.y > edge.x else (0 if centre.x > 0.0 else 1)
		if gaps[toward] < 3.0: front = toward
	var out: Vector3 = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD][front]
	var shop_floor := kind == Kind.ZAKKYO or kind == Kind.OFFICE or kind == Kind.LOW or kind == Kind.KONBINI
	var seed_value := _rng.randf() * .998
	var storey := 2.9 if kind == Kind.LOW else (3.0 if kind == Kind.GARAGE else STOREY)
	# Mirrors the shader: each commercial building has its own floor height.
	if kind == Kind.ZAKKYO or kind == Kind.OFFICE: storey = 3.0 + fposmod(seed_value * 71.0, 1.0) * .9
	# Sky-exposure rules cut the top storeys back from the street on most mid-rise.
	var upper := 0
	if floors >= 5 and kind != Kind.GARAGE and kind != Kind.DANCHI and kind != Kind.GLASS and _rng.randf() < .55:
		upper = _rng.randi_range(1, mini(3, floors - 3))
	var height := (SHOP_FLOOR if shop_floor else storey) + float(floors - upper - 1) * storey + .9
	var distance := _park_distance(centre)
	if house: height = storey * 2.0 + .9
	var pitched := kind == Kind.LOW and (house or _rng.randf() < .7)
	var ground := SHOP_FLOOR if shop_floor and not house else 0.0
	if kind == Kind.LOW and fposmod(seed_value * 5.0, 1.0) < .3: ground = 0.0
	var hero := _place_body(centre, 0.0, Vector3(lot.size.x, height - (.9 if pitched else 0.0), lot.size.y), kind, front, seed_value, storey, ground, distance, not pitched)
	_count += 1
	var on_x := absf(out.x) > .5
	var b := {"pos":centre, "height":height, "kind":kind, "floors":floors, "storey":storey, "front":front, "seed":seed_value, "out":out, "right":Vector3.UP.cross(out),
		"across":lot.size.y if on_x else lot.size.x, "depth":lot.size.x if on_x else lot.size.y, "size":lot.size, "hero":hero, "pitched":pitched}
	var tier := 0 if distance < NEAR_TIER else (1 if distance < MID_TIER else 2)
	# Close-range parts catch and cast real shadows; further out they stay cheap.
	_trim_layer = "detail" if distance < HERO_RANGE else "trim"
	_dress_roof(b, tier)
	if upper > 0:
		var cut := float(b.depth) * _rng.randf_range(.22, .38)
		var shift := Vector2(out.x, out.z) * -cut * .5
		var top_size := lot.size - Vector2(absf(out.x), absf(out.z)) * cut
		var top_height := float(upper) * storey + .9
		var top_kind := Kind.MANSION if kind == Kind.MANSION else Kind.UPPER
		if kind != Kind.MANSION and _rng.randf() < .45:
			# Sunlight rules plane the street side back as one raked slope.
			var rake_at := Vector3(centre.x + shift.x, height - .9 + top_height * .5, centre.y + shift.y) + out * cut * .5
			var rake := Basis(out * (float(b.depth)), Vector3.UP * top_height, b.right * -float(b.across))
			_put("wedges", rake_at, Transform3D(rake, rake_at), Color(Pattern.ROOF_TILE, 0, 0, 0), TONES[int(fposmod(seed_value * 23.0, 1.0) * 16.0)].darkened(.2))
		else:
			var crown_hero := _place_body(centre + shift, height - .9, Vector3(top_size.x, top_height, top_size.y), top_kind, front, seed_value, storey, 0.0, distance)
			var crown := b.duplicate()
			crown.hero = crown_hero
			crown.pitched = false
			crown.pos = centre + shift
			crown.size = top_size
			crown.height = height - .9 + top_height
			crown.depth = float(b.depth) - cut
			crown.kind = Kind.UPPER
			_dress_roof(crown, tier)
	if tier < 2 and floors >= 5 and (kind == Kind.OFFICE or kind == Kind.MANSION) and _rng.randf() < .4:
		# Stair and lift shaft expressed on the flank.
		var flank := -1.0 if _rng.randf() < .5 else 1.0
		var shaft := Vector3(2.8, height + 2.4, 3.4)
		var at: Vector3 = Vector3(centre.x, 0, centre.y) + b.right * flank * (float(b.across) * .5 + .7) - out * float(b.depth) * .2
		var core_size := Vector3(absf(b.right.x) * 1.4 + absf(out.x) * shaft.z, shaft.y, absf(b.right.z) * 1.4 + absf(out.z) * shaft.z)
		_box_body(Vector2(at.x, at.z), 0.0, core_size, Kind.CORE, front, seed_value)
	if tier == 0: _dress_side_walls(b)
	if tier < 2:
		match kind:
			Kind.MANSION, Kind.DANCHI:
				_dress_balconies(b, tier)
				_dress_corridor(b)
			Kind.ZAKKYO: _dress_signs(b, tier)
			Kind.OFFICE: _dress_office(b, tier)
		if kind == Kind.KONBINI: _dress_konbini(b)
		if tier == 0 and shop_floor: _dress_shopfront(b)
	return b

func _business() -> int:
	# Dealt from a deck, so a name cannot recur until every other one has been used.
	if _dealt % BUSINESSES == 0:
		for i: int in range(BUSINESSES - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var held := _deck[i]
			_deck[i] = _deck[j]
			_deck[j] = held
	_dealt += 1
	return _deck[_dealt % BUSINESSES]

func _front_at(b: Dictionary, along: float, y: float, proud: float) -> Vector3:
	var pos: Vector2 = b.pos
	return Vector3(pos.x, y, pos.y) + b.out * (float(b.depth) * .5 + proud) + b.right * along

func _trim(b: Dictionary, along: float, y: float, proud: float, size: Vector3, color: Color, pattern := 0) -> void:
	var at := _front_at(b, along, y, proud)
	_put(_trim_layer, at, Transform3D(Basis(b.right * size.x, Vector3.UP * size.y, b.out * size.z), at), Color(float(pattern), size.x, size.y, 0), color)

func _pipe(b: Dictionary, along: float, proud: float, height: float, color: Color) -> void:
	var at := _front_at(b, along, height * .5, proud)
	_put("tanks", at, _xform(at, Vector3(.1, height, .1)), Color(), color)

func _flat_sign(b: Dictionary, along: float, y: float, proud: float, size: Vector3, cell: int) -> void:
	var at := _front_at(b, along, y, proud)
	_put("signs", at, Transform3D(Basis(b.right * size.x, Vector3.UP * size.y, b.out * size.z), at), Color(float(cell), 0, 0, 0))

func _blade_sign(b: Dictionary, along: float, y: float, proud: float, size: Vector3, cell: int) -> void:
	# Stands out from the wall, so its faces read along the street.
	var at := _front_at(b, along, y, proud)
	_put("signs", at, Transform3D(Basis(b.out * size.x, Vector3.UP * size.y, b.right * -size.z), at), Color(float(cell), 0, 0, 0))

func _dress_roof(b: Dictionary, tier: int) -> void:
	var pos: Vector2 = b.pos
	var size: Vector2 = b.size
	var top := float(b.height)
	var kind: int = b.kind
	if b.get("pitched", false):
		# Pitched roof, ridge along the longer side.
		var rise := _rng.randf_range(1.2, 2.4)
		var along_x := size.x > size.y
		var basis := Basis(Vector3.UP, PI * .5) if along_x else Basis.IDENTITY
		var at := Vector3(pos.x, top - .9 + rise * .5, pos.y)
		var scale_size := Vector3(size.y if along_x else size.x, rise, size.x if along_x else size.y) + Vector3(1.0, 0, .8)
		_put("roofs", at, Transform3D(basis * Basis.from_scale(scale_size), at), Color(Pattern.ROOF_TILE, 0, 0, 0), KAWARA[_rng.randi_range(0, KAWARA.size() - 1)])
		return
	# Parapet ring; rounded shells run their own wall up to the roof line instead.
	var wall := TONES[int(fposmod(float(b.seed) * 23.0, 1.0) * 16.0)].darkened(.06)
	var y := top + .3
	var key := Vector3(pos.x, 0, pos.y)
	var ringed: bool = not b.get("hero", false)
	if ringed:
		_put("trim", key, _xform(Vector3(pos.x, y, pos.y - size.y * .5 + .1), Vector3(size.x, .9, .2)), Color(), wall)
		_put("trim", key, _xform(Vector3(pos.x, y, pos.y + size.y * .5 - .1), Vector3(size.x, .9, .2)), Color(), wall)
		_put("trim", key, _xform(Vector3(pos.x - size.x * .5 + .1, y, pos.y), Vector3(.2, .9, size.y)), Color(), wall)
		_put("trim", key, _xform(Vector3(pos.x + size.x * .5 - .1, y, pos.y), Vector3(.2, .9, size.y)), Color(), wall)
	# Lift overrun and stair head.
	if _rng.randf() < .75:
		var hut := Vector3(_rng.randf_range(2.4, 3.6), _rng.randf_range(2.4, 3.4), _rng.randf_range(2.6, 4.2))
		var offset := Vector2(_rng.randf_range(-.26, .26) * size.x, _rng.randf_range(-.26, .26) * size.y)
		_put("trim", key, _xform(Vector3(pos.x + offset.x, top + hut.y * .5, pos.y + offset.y), hut), Color(), wall.darkened(.1))
	if tier > 1: return
	if _rng.randf() < .4:
		# Safety fence around a usable roof.
		var fence := Color("#596a5e")
		var post := top + 1.5
		for row: Array in [[Vector3(pos.x, post, pos.y - size.y * .5 + .1), Vector3(size.x, 1.5, .04), size.x], [Vector3(pos.x, post, pos.y + size.y * .5 - .1), Vector3(size.x, 1.5, .04), size.x]]:
			_put("trim", key, _xform(row[0], row[1]), Color(Pattern.BARS, float(row[2]), 1.5, 0), fence)
	if _rng.randf() < .3 and size.x > 9.0:
		# Cooling tower, louvred.
		var tower := Vector3(2.4, 2.2, 2.4)
		_put("trim", key, _xform(Vector3(pos.x - size.x * .22, top + 1.1, pos.y + size.y * .2), tower), Color(Pattern.LOUVRE, tower.x, tower.y, 0), Color("#a2a6a4"))
	elif _rng.randf() < .25 and size.x > 8.0:
		# Solar array, tilted south.
		var panel := Vector3(size.x * .55, .06, 1.7)
		var tilt := Basis(Vector3.RIGHT, -.35) * Basis.from_scale(panel)
		for row: int in range(2):
			_put("trim", key, Transform3D(tilt, Vector3(pos.x, top + .7, pos.y + float(row) * 2.2 - 1.1)), Color(Pattern.SOLAR, panel.x, panel.z, 0), Color.WHITE)
	# Water tank on a steel stand.
	if _rng.randf() < .6:
		var spot := Vector2(_rng.randf_range(-.3, .3) * size.x, _rng.randf_range(-.3, .3) * size.y)
		var height := _rng.randf_range(1.6, 2.6)
		var at := Vector3(pos.x + spot.x, top + 1.5 + height * .5, pos.y + spot.y)
		var tank_paint := Color("#9aa09f") if _rng.randf() < .6 else Color("#4f6f8a")
		_put("tanks", at, _xform(at, Vector3(1.9, height, 1.9)), Color(Pattern.RIBBED, 0, 0, 0), tank_paint)
		var cap := at + Vector3.UP * height * .5
		_put("domes", cap, _xform(cap, Vector3(1.9, .5, 1.9)), Color(), tank_paint)
		var stand: Array[Vector2] = [Vector2(-.7, -.7), Vector2(.7, -.7), Vector2(.7, .7), Vector2(-.7, .7)]
		for i: int in range(4):
			var foot := Vector3(at.x + stand[i].x, top, at.z + stand[i].y)
			var other := Vector3(at.x + stand[(i + 1) % 4].x, top + 1.5, at.z + stand[(i + 1) % 4].y)
			_put("trim", key, _xform(foot + Vector3.UP * .75, Vector3(.1, 1.5, .1)), Color(), STEEL)
			if tier == 0: _beam(foot, other, .03, STEEL)
		if tier == 0:
			# Inlet pipe and access ladder.
			_put("tanks", at, _xform(Vector3(at.x + .98, top + 1.5, at.z), Vector3(.07, 3.0, .07)), Color(), Color("#6c6f70"))
	if tier == 0:
		for i: int in range(_rng.randi_range(2, 6)):
			var unit := Vector2(_rng.randf_range(-.4, .4) * size.x, _rng.randf_range(-.4, .4) * size.y)
			_put("detail" if tier == 0 else "trim", key, _xform(Vector3(pos.x + unit.x, top + .35, pos.y + unit.y), Vector3(.9, .66, .32)), Color(Pattern.AC_UNIT, .9, .66, 0), Color("#c0c0b8"))
		if _rng.randf() < .4:
			_put("trim", key, _xform(Vector3(pos.x, top + 3.0, pos.y), Vector3(.07, 6.0, .07)), Color(), STEEL)
	var near_edge := _park_distance(pos) < 90.0 and (kind == Kind.ZAKKYO or kind == Kind.OFFICE)
	if near_edge and _rng.randf() < .14:
		# Roof sign on an exposed steel frame.
		var wide := minf(float(b.across) * .85, 13.0)
		var tall := wide * .25
		_trim(b, 0.0, top + 1.2, -.8, Vector3(wide * .9, 2.4, .12), STEEL)
		_flat_sign(b, 0.0, top + 1.4 + tall * .5, -.6, Vector3(wide, tall, .25), _business())

func _dress_corridor(b: Dictionary) -> void:
	# Open access gallery along the rear, the signature of a Japanese apartment block.
	var width: float = b.across
	var depth: float = b.depth
	var pale := TONES[int(fposmod(float(b.seed) * 23.0, 1.0) * 16.0)]
	var pos: Vector2 = b.pos
	var right: Vector3 = b.right
	var back: Vector3 = -b.out
	for floor_index: int in range(1, int(b.floors)):
		var y := float(floor_index) * STOREY
		var span := width
		var centre := pos
		# This fixed-layout mansion's lower rear galleries otherwise penetrate
		# Fukumaru's 202 bedroom and 301 bath. Stop at its rear masonry, keeping
		# the rest of each gallery and all floors above Fukumaru's roof.
		if floor_index <= 2 and pos.distance_squared_to(Vector2(84.2028, -218.0927)) < .01:
			var north_end := pos.y - width * .5
			var south_end := minf(pos.y + width * .5, -215.30)
			span = south_end - north_end
			centre.y = (north_end + south_end) * .5
		var at := Vector3(centre.x, y, centre.y) + back * (depth * .5 + .6)
		_put("trim", at, Transform3D(Basis(right * span, Vector3.UP * .18, back * 1.2), at), Color(), pale.darkened(.12))
		var rail := at + back * .6 + Vector3.UP * .58
		_put("trim", rail, Transform3D(Basis(-right * span, Vector3.UP * 1.1, back * .06), rail), Color(Pattern.BARS, span, 1.1, 0), pale.darkened(.25))

func _dress_side_walls(b: Dictionary) -> void:
	# Pipes, outdoor units and a fire stair on the exposed flanks.
	var pos: Vector2 = b.pos
	var height: float = b.height
	var depth: float = b.depth
	var right: Vector3 = b.right
	var out: Vector3 = b.out
	var half := float(b.across) * .5
	for flank: float in [-1.0, 1.0]:
		var normal := right * flank
		var wall := Vector3(pos.x, 0, pos.y) + normal * half
		_put("trim", wall, Transform3D(Basis(right * .12, Vector3.UP * height, out * .12), wall + normal * .08 + out * _rng.randf_range(-.4, .4) * depth + Vector3.UP * height * .5), Color(), Color("#65696a"))
		for i: int in range(_rng.randi_range(1, 5)):
			var y := _rng.randf_range(4.0, maxf(height - 2.0, 4.5))
			_put("trim", wall, Transform3D(Basis(right * .34, Vector3.UP * .62, out * .82), wall + normal * .2 + out * _rng.randf_range(-.42, .42) * depth + Vector3.UP * y), Color(), Color("#aeaea6"))
	if height > 18.0 and _rng.randf() < .08:
		# Tall banner sign hung on a blank flank.
		var flank := -1.0 if _rng.randf() < .5 else 1.0
		var normal := right * flank
		var tall := minf(height * .6, 16.0)
		var at := Vector3(pos.x, height - tall * .5 - 2.0, pos.y) + normal * (half + .12)
		_put("signs", at, Transform3D(Basis(Vector3.UP.cross(normal) * tall * .25, Vector3.UP * tall, normal * .12), at), Color(float(BUSINESSES + _business()), 0, 0, 0))
	if height < 14.0 or _rng.randf() > .4: return
	# Open steel fire stair at the rear, landing per storey.
	var side := -1.0 if _rng.randf() < .5 else 1.0
	var back := Vector3(pos.x, 0, pos.y) - out * (depth * .5 + .6) + right * side * (half - 1.5)
	var y := STOREY
	while y < height - 1.0:
		_put("trim", back, Transform3D(Basis(right * 2.6, Vector3.UP * .08, out * 1.1), back + Vector3.UP * y), Color(), Color("#3d4043"))
		_put("trim", back, Transform3D(Basis(right * 2.6, Vector3.UP * .9, out * .05), back + Vector3.UP * (y + .5) - out * .54), Color(), Color("#2e3033"))
		var rise := Basis(out, .85) * Basis(right * 3.6, Vector3.UP * .08, out * .8)
		_put("detail", back, Transform3D(rise, back + Vector3.UP * (y + STOREY * .5)), Color(), Color("#35383a"))
		var guard := Basis(out, .85) * Basis(right * 3.6, Vector3.UP * .9, out * .04)
		_put("detail", back, Transform3D(guard, back + Vector3.UP * (y + STOREY * .5 + .45) - out * .42), Color(Pattern.BARS, 3.6, .9, 0), Color("#2e3033"))
		y += STOREY

func _dress_balconies(b: Dictionary, tier: int) -> void:
	var width: float = b.across
	var bay := _bay(width, b.seed)
	var floors: int = b.floors
	var pale := TONES[int(fposmod(float(b.seed) * 23.0, 1.0) * 16.0)]
	var glass_front: bool = b.kind == Kind.MANSION and _rng.randf() < .4
	var barred: bool = not glass_front and _rng.randf() < .55
	for floor_index: int in range(1, floors):
		var y := float(floor_index) * STOREY
		_trim(b, 0.0, y - .06, .62, Vector3(width, .16, 1.24), pale.darkened(.15))
		if barred: _trim(b, 0.0, y + .58, 1.2, Vector3(width, 1.12, .05), Color("#4d5154"), Pattern.BARS)
		else: _trim(b, 0.0, y + .58, 1.2, Vector3(width, 1.12, .07), Color("#6d7f8a") if glass_front else pale, Pattern.FROSTED if glass_front else Pattern.SOLID)
		if tier > 0: continue
		_trim(b, 0.0, y + 1.16, 1.2, Vector3(width, .05, .1), STEEL)
		_trim(b, 0.0, y - .16, 1.2, Vector3(width, .05, .08), pale.darkened(.3))
		# Drying poles strung across the bay, on brackets from the slab above.
		_trim(b, 0.0, y + 2.25, .92, Vector3(width, .03, .03), Color("#b9bab6"))
		for i: int in range(int(round(width / bay)) + 1):
			var along := -width * .5 + bay * float(i)
			# Exposed frame: full columns at each end and every other bay, thin party fins between.
			var column := i % 2 == 0
			_trim(b, along, y + 1.6, .66 if column else .62, Vector3(.5 if column else .1, STOREY, 1.32 if column else 1.24), pale.darkened(.05))
			if i == int(round(width / bay)): continue
			var roll := _rng.randf()
			var mid := along + bay * .5
			if roll < .4:
				_trim(b, mid + bay * .28, y + .39, .9, Vector3(.8, .58, .28), Color("#c4c4bc"), Pattern.AC_UNIT)
				_trim(b, mid + bay * .28 + .46, y + .9, .2, Vector3(.05, 1.3, .05), Color("#d6d4cc"))
			elif roll < .6:
				# Washing hung over the rail.
				_trim(b, mid - bay * .1, y + .95, 1.26, Vector3(bay * .4, .72, .03), [Color("#d8d4cb"), Color("#7f93a8"), Color("#a86a62")][_rng.randi_range(0, 2)])
			elif roll < .72:
				# Potted plants along the rail.
				_trim(b, mid, y + .3, .95, Vector3(bay * .5, .42, .3), Color("#3f5a34"))

func _dress_signs(b: Dictionary, tier: int) -> void:
	# One tidy tenant directory per building: a floor's board names who is on that
	# floor, a vacant floor shows a blank panel, and plenty of buildings carry none.
	var width: float = b.across
	var floors: int = b.floors
	var storey: float = b.storey
	var count := floors - 1
	var side := -1.0 if fposmod(float(b.seed) * 61.0, 1.0) < .5 else 1.0
	var along := side * (width * .5 - .35)
	if tier == 0:
		_pipe(b, -along, .09, float(b.height), Color("#6c6f70"))
		_trim(b, -side * width * .32, float(b.height) * .5, .05, Vector3(.05, float(b.height), .05), Color("#1f2022"))
		for i: int in range(count):
			if _rng.randf() < .35:
				_trim(b, (float(i % 3) - 1.0) * width * .3, SHOP_FLOOR + float(i) * storey + .4, .16, Vector3(.5, .32, .3), Color("#8e8f8c"), Pattern.LOUVRE)
	if _rng.randf() > (.62 if tier == 0 else .35): return
	var lettered := tier == 0 and width > 9.0 and _rng.randf() < .3
	_trim(b, along, SHOP_FLOOR + float(count) * storey * .5, .08, Vector3(.1, float(count) * storey, .16), STEEL)
	for i: int in range(count):
		var y := SHOP_FLOOR + (float(i) + .5) * storey
		if _rng.randf() < .2:
			_trim(b, along, y, .58, Vector3(.2, storey - .2, .9), Color("#c9c9c2"))
			continue
		var tenant := _business()
		_blade_sign(b, along, y, .58, Vector3(.78, storey - .3, .18), BUSINESSES + tenant)
		# Some landlords also allow the tenant's name on the spandrel, centred and matched.
		if lettered: _flat_sign(b, 0.0, SHOP_FLOOR + float(i) * storey + .22, .1, Vector3(2.6, .65, .08), tenant)

func _dress_office(b: Dictionary, tier: int) -> void:
	# Precast fins give the long elevation a rhythm.
	if tier > 0 or _rng.randf() < .4: return
	var width: float = b.across
	var height: float = b.height
	var bays := maxi(1, int(width / 3.6))
	for i: int in range(bays + 1):
		_trim(b, -width * .5 + width * float(i) / float(bays), SHOP_FLOOR + (height - SHOP_FLOOR) * .5, .2, Vector3(.22, height - SHOP_FLOOR, .4), CONCRETE)

func _dress_konbini(b: Dictionary) -> void:
	# Corporate colour bands wrapped round the fascia, and a pole sign by the kerb.
	var width: float = b.across
	var stripes: Array = KONBINI_STRIPES[_rng.randi_range(0, KONBINI_STRIPES.size() - 1)]
	_trim(b, 0.0, 4.5, .12, Vector3(width, .38, .2), stripes[0])
	_trim(b, 0.0, 4.14, .12, Vector3(width, .22, .2), stripes[1])
	_trim(b, 0.0, 3.3, .7, Vector3(width, .14, 1.4), Color("#d8d8d2"))

func _dress_shopfront(b: Dictionary) -> void:
	var width: float = b.across
	var units := maxi(1, int(floorf(width / 6.0 + .5)))
	var bay := width / float(units)
	for i: int in range(units):
		var along := -width * .5 + bay * (float(i) + .5)
		_flat_sign(b, along, 3.72, .18, Vector3(minf(bay - .3, 3.9), .95, .16), _business())
		if _rng.randf() < .55:
			var color: Color = AWNINGS[_rng.randi_range(0, AWNINGS.size() - 1)]
			var at := _front_at(b, along, 3.0, .7)
			var slope := Basis(b.right, .34) * Basis(b.right * (bay - .3), Vector3.UP * .05, b.out * 1.5)
			_put("detail", at, Transform3D(slope, at), Color(Pattern.AWNING, bay - .3, .05, 0), color)
		_trim(b, along, 3.22, .12, Vector3(bay - .4, .26, .24), Color("#7d7f80"))

func _build_ring_street() -> void:
	var half := PARK.size * .5 + Vector2(16.0, 16.0)
	var lamp_rows: Array = []
	var sides: Array[Array] = [[Vector2(-half.x, -half.y), Vector2(half.x, -half.y)], [Vector2(half.x, -half.y), Vector2(half.x, 164.0)], [Vector2(-half.x, -half.y), Vector2(-half.x, half.y)]]
	for side: Array in sides:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var steps := int(a.distance_to(b) / 32.0)
		var outward := (a + b).normalized()
		outward = Vector2(signf(outward.x), 0.0) if absf(outward.x) > absf(outward.y) else Vector2(0.0, signf(outward.y))
		var previous := Vector3.ZERO
		for i: int in range(steps + 1):
			var p := a.lerp(b, float(i) / float(steps))
			var at := Vector3(p.x, 3.5, p.y)
			_put("tanks", at, _xform(Vector3(p.x, 4.0, p.y), Vector3(.18, 8.0, .18)), Color(), Color("#5e6366"))
			var reach := Vector3(-outward.x, 0, -outward.y)
			var bend := Vector3(p.x, 8.0, p.y)
			var tip := bend + reach * 2.4 + Vector3.UP * .55
			_beam(bend, bend + reach * 1.1 + Vector3.UP * .42, .05, Color("#5e6366"))
			_beam(bend + reach * 1.1 + Vector3.UP * .42, tip, .05, Color("#5e6366"))
			var head_size := Vector3(.26 + absf(reach.x) * .6, .09, .26 + absf(reach.z) * .6)
			lamp_rows.append([_xform(tip, head_size), Color(1, 0, 0, 0), Color.WHITE])
			# Concrete utility pole on the outer kerb, with sagging lines to the next.
			var pole := p + outward * 3.0 + (b - a).normalized() * 12.0
			var top := Vector3(pole.x, 10.5, pole.y)
			_put("tanks", top, _xform(Vector3(pole.x, 5.25, pole.y), Vector3(.32, 10.5, .32)), Color(), Color("#77766f"))
			var bar := Vector3((b - a).normalized().y, 0, -(b - a).normalized().x)
			_put("trim", top, Transform3D(Basis(bar * 1.9, Vector3.UP * .1, Vector3.UP.cross(bar) * .1), top - Vector3.UP * .5), Color(), Color("#3a3a38"))
			_put("tanks", top, _xform(top - Vector3(0, 2.0, 0) + bar * .35, Vector3(.55, 1.0, .55)), Color(), Color("#6f7472"))
			if i > 0:
				for offset: float in [-.8, 0.0, .8]:
					_wire(previous - Vector3.UP * .45 + bar * offset, top - Vector3.UP * .45 + bar * offset)
			# Pedestrian guard rail along the park road.
			if i < steps:
				var run := (b - a).normalized()
				# Rails run in short sections and stop at the mouths of side roads.
				for section: float in [5.5, 16.0, 26.5]:
					var rail := p + run * section + outward * -1.6
					var along_road := rail.x if absf(run.x) > .5 else rail.y
					if absf(fposmod(along_road + BLOCK * .5, BLOCK) - BLOCK * .5) < ROAD + 7.0: continue
					var rail_at := Vector3(rail.x, .42, rail.y)
					var rail_basis := Basis(Vector3(run.x, 0, run.y) * 10.0, Vector3.UP * .8, Vector3(-run.y, 0, run.x) * .05)
					if rail_basis.determinant() < 0.0: rail_basis.z = -rail_basis.z
					_put("trim", rail_at, Transform3D(rail_basis, rail_at), Color(Pattern.BARS, 10.0, .8, 0), Color("#b9bcb8"))
			previous = top
	_rows["lamps"] = {0:lamp_rows}
	_commit_layer("lamps", BoxMesh.new(), _material(LAMP_SHADER, "SHINRAI_NearCityLamps"), false)
	_rows.erase("lamps")

func _beam(a: Vector3, b: Vector3, thick: float, color: Color, pattern := 0) -> void:
	var along := b - a
	var side := along.cross(Vector3.UP if absf(along.normalized().y) < .9 else Vector3.RIGHT).normalized() * thick
	var lift := side.cross(along).normalized() * thick
	_put("trim", a, Transform3D(Basis(side, lift, along), (a + b) * .5), Color(float(pattern), 0, 0, 0), color)

func _build_expressway() -> void:
	# Elevated expressway on T-piers, carried over a grid road like the Shuto.
	var concrete := Color("#6e6d68")
	var parapet := Color("#7d7c76")
	var half := 8.5
	var x := -1000.0
	while x < 1000.0:
		var key := Vector3(x, 0, EXPRESSWAY_Z)
		var deck := Vector3(x + 16.0, EXPRESSWAY_Y, EXPRESSWAY_Z)
		_put("trim", deck, _xform(deck, Vector3(32.0, .9, half * 2.0)), Color(), Color("#3a3a3a"))
		_put("trim", deck, _xform(deck - Vector3(0, .65, 0), Vector3(32.0, .4, half * 1.9)), Color(), concrete.darkened(.1))
		# Exposed steel girders and cross-frames, as seen from the road below.
		for girder: float in [-6.0, -3.0, 0.0, 3.0, 6.0]:
			var run := deck + Vector3(0, -1.5, girder)
			_put("trim", run, _xform(run, Vector3(32.0, 1.3, .36)), Color(), concrete.darkened(.22))
		for frame: float in [-8.0, 0.0, 8.0]:
			var cross := deck + Vector3(frame, -1.4, 0)
			_put("trim", cross, _xform(cross, Vector3(.3, .9, half * 1.5)), Color(), concrete.darkened(.3))
		for side: float in [-1.0, 1.0]:
			var edge := deck + Vector3(0, 1.0, side * half)
			_put("trim", edge, _xform(edge, Vector3(32.0, 1.2, .3)), Color(), parapet)
			# Noise barrier, in long frosted bays.
			if absf(x) < 640.0:
				var wall := edge + Vector3(0, 2.1, 0)
				_put("trim", wall, _xform(wall, Vector3(31.2, 3.0, .1)), Color(Pattern.FROSTED, 0, 0, 0), Color("#8a9a9c"))
		if absf(x - VIADUCT_X) > 9.0:
			_put("trim", key, _xform(Vector3(x, (EXPRESSWAY_Y - 1.6) * .5, EXPRESSWAY_Z), Vector3(2.6, EXPRESSWAY_Y - 1.6, 2.6)), Color(), concrete)
			_put("trim", key, _xform(Vector3(x, EXPRESSWAY_Y - 2.2, EXPRESSWAY_Z), Vector3(2.6, 1.8, half * 1.9)), Color(), concrete)
		if int(x + 1000.0) % 64 == 0:
			var mast := Vector3(x, EXPRESSWAY_Y + 5.0, EXPRESSWAY_Z)
			_put("trim", mast, _xform(mast + Vector3(0, 0, half), Vector3(.2, 9.0, .2)), Color(), Color("#55585a"))
			_put("trim", mast, _xform(mast + Vector3(0, 0, -half), Vector3(.2, 9.0, .2)), Color(), Color("#55585a"))
		x += 32.0

func _build_viaduct() -> void:
	# Commuter line on concrete arches, with catenary portals over the tracks.
	var concrete := Color("#77736a")
	var z := -1000.0
	var count := 0
	while z < HandViaduct.Z_START:
		var centre := Vector3(VIADUCT_X, VIADUCT_Y, z + 6.0)
		_put("trim", centre, _xform(centre, Vector3(11.0, .9, 12.0)), Color(), concrete)
		for side: float in [-1.0, 1.0]:
			var edge := centre + Vector3(side * 5.4, 1.0, 0)
			_put("trim", edge, _xform(edge, Vector3(.28, 1.3, 12.0)), Color(), concrete.lightened(.08))
		for rail: float in [-2.6, -1.0, 1.0, 2.6]:
			var line := centre + Vector3(rail, .55, 0)
			_put("trim", line, _xform(line, Vector3(.16, .16, 12.0)), Color(), Color("#3c3a38"))
		var pier := Vector3(VIADUCT_X, (VIADUCT_Y - .5) * .5, z)
		_put("trim", pier, _xform(pier, Vector3(10.0, VIADUCT_Y - .5, 1.4)), Color(), concrete.darkened(.12))
		# The arch opening, dark under the deck.
		var arch := Vector3(VIADUCT_X, VIADUCT_Y - 1.1, z + 6.0)
		_put("trim", arch, _xform(arch, Vector3(10.0, 1.4, 10.6)), Color(), concrete.darkened(.25))
		if count % 4 == 0:
			var top := VIADUCT_Y + 7.0
			for side: float in [-1.0, 1.0]:
				var post := Vector3(VIADUCT_X + side * 5.2, VIADUCT_Y + 3.5, z)
				_put("trim", post, _xform(post, Vector3(.24, 7.0, .24)), Color(), Color("#5b5f63"))
			var head := Vector3(VIADUCT_X, top, z)
			_put("trim", head, _xform(head, Vector3(10.6, .3, .3)), Color(), Color("#5b5f63"))
			for rail: float in [-1.8, 1.8]:
				_wire(head + Vector3(rail, -1.0, 0), head + Vector3(rail, -1.0, 48.0))
		z += 12.0
		count += 1
	var by_hand: Node3D = HandViaduct.new()
	by_hand.position = Vector3(VIADUCT_X, 0, 0)
	add_child(by_hand)
	_handmade.append(by_hand)

func _build_landmark() -> void:
	# Fictional lattice broadcast tower, in aviation orange and white bands.
	var base := Vector3(TOWER_SITE.x, 0, TOWER_SITE.y)
	var orange := Color("#b5431a")
	var white := Color("#c9c6bd")
	var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var previous := 26.0
	for level: int in range(TOWER_LEVELS):
		var low := TOWER_HEIGHT * float(level) / float(TOWER_LEVELS)
		var high := TOWER_HEIGHT * float(level + 1) / float(TOWER_LEVELS)
		var next := 26.0 * pow(1.0 - float(level + 1) / float(TOWER_LEVELS), 1.7) + 1.4
		var color := orange if level % 2 == 0 else white
		for i: int in range(4):
			var a := corners[i]
			var b := corners[(i + 1) % 4]
			var a_low := base + Vector3(a.x * previous, low, a.y * previous)
			var b_low := base + Vector3(b.x * previous, low, b.y * previous)
			var a_high := base + Vector3(a.x * next, high, a.y * next)
			var b_high := base + Vector3(b.x * next, high, b.y * next)
			_beam(a_low, a_high, .55, color)
			_beam(a_high, b_high, .3, color)
			_beam(a_low, b_high, .2, color)
			_beam(b_low, a_high, .2, color)
		previous = next
	# Two observation decks and the broadcast mast.
	for deck: Array in [[.3, 15.0, 7.0], [.58, 9.0, 4.5]]:
		var y := TOWER_HEIGHT * float(deck[0])
		var at := base + Vector3(0, y, 0)
		_put("tanks", at, _xform(at, Vector3(float(deck[1]) * 2.0, float(deck[2]), float(deck[1]) * 2.0)), Color(), Color("#9aa3a8"))
	var mast := base + Vector3(0, TOWER_HEIGHT + 22.0, 0)
	_put("trim", mast, _xform(mast, Vector3(1.0, 44.0, 1.0)), Color(), white)

func _wire(a: Vector3, b: Vector3) -> void:
	var points: Array[Vector3] = []
	for i: int in range(5):
		var t := float(i) / 4.0
		points.append(a.lerp(b, t) + Vector3.DOWN * (4.0 * t * (1.0 - t)) * .7)
	for i: int in range(4):
		var from := points[i]
		var to := points[i + 1]
		var along := to - from
		var side := along.cross(Vector3.UP).normalized() * .035
		var lift := side.cross(along).normalized() * .035
		_put("trim", from, Transform3D(Basis(side, lift, along), (from + to) * .5), Color(), Color("#141414"))
