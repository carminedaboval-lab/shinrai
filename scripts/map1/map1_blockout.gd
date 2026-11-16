extends Node3D
## Map 1 grey blockout: the whole 5 km² plan at true size, to walk and fly through.
## It is a layout test, not art. Everything comes from two generated files
## (tools/map_plan/build_map1_blockout.py, from data/map1/map1_plan.json):
##   data/map1/generated/map1_ground.png      the ground, 1 pixel = 1 metre
##   data/map1/generated/map1_blockout.json   boxes, shapes, trees, bot posts
## Keys: F3 fly (Shift = fast), [ and ] jump between stations, drop-offs and landmarks,
## L labels on/off, Esc frees the mouse.
##
## With `with_world` (the default) scripts/map1/map1_world.gd stands real kit houses in for
## the low open buildings near the viewer and builds the robot recharge stations. Then the
## player also has: E use a door or window (hold E to force a lock or knock glass out), left
## mouse one shot where he looks, C the crowbar stand-in.

const World := preload("res://scripts/map1/map1_world.gd")
const UpperShopfront := preload("res://scripts/map1/map1_upper_shopfront.gd")
const KobanLane := preload("res://scripts/map1/map1_koban_lane.gd")
const ShopRowBoards := preload("res://scripts/map1/map1_shop_row_boards.gd")
const Fuel := preload("res://scripts/map1/map1_fuel.gd")
const CarPark := preload("res://scripts/map1/map1_car_park.gd")
const Plaza := preload("res://scripts/map1/map1_plaza.gd")
const CurveMirrors := preload("res://scripts/map1/map1_curve_mirrors.gd")
var curve_mirrors: Node3D
const Street := preload("res://scripts/map1/map1_street.gd")
## The trial street edge is built on one side only: +1 is the south side of the homes street,
## the right-hand side in the modern_street picture.
const STREET_TRIAL_SIDE := 1.0
## Where the trial is looked at from (the modern_street picture): gates nearest it come first.
const STREET_TRIAL_AT := Vector2(112.0, 447.0)
## The zebra crossing on the shop row road: metres along its exported centre line (x = -269.4).
const SHOP_ROW_CROSSING := 168.6
## The paved apron between a footway and a plaza behind it: it falls from the footway's
## height to the plaza's over this distance (about 1 in 15).
## The ten edges that make Tram street's one continuous pavement, from its straight length through
## the fork and the compound mouth to the diagonal beyond. They share the shop row's footway
## material; everything else keeps its own finish.
const TRAM_PAVED: Array[String] = ["tram street south", "tram fork south", "tram fork island lane",
	"tram fork island stub", "tram mouth tip", "tram mouth point", "tram mouth point diagonal",
	"tram diagonal south a", "tram diagonal south", "tram diagonal south b"]
const PLAZA_APRON := 2.0
const PLAN_PATH := "res://data/map1/map1_plan.json"
const DATA_PATH := "res://data/map1/generated/map1_blockout.json"
const GROUND_PATH := "res://data/map1/generated/map1_ground.png"
const HEIGHT_DIR := "res://data/map1/generated/"
const GROUND_SHADER := "res://scripts/map1/map1_ground.gdshader"
const Player := preload("res://scripts/player.gd")

const KIND_COLOURS := {
	"building": Color(0.62, 0.61, 0.58), "tall": Color(0.66, 0.66, 0.67), "slab": Color(0.70, 0.69, 0.66),
	"house": Color(0.60, 0.56, 0.49), "timber": Color(0.50, 0.42, 0.33), "shop": Color(0.64, 0.58, 0.49), "small": Color(0.56, 0.55, 0.53),
	"shed": Color(0.55, 0.53, 0.50), "hangar": Color(0.58, 0.55, 0.47), "terminal": Color(0.66, 0.69, 0.67),
	"mall": Color(0.68, 0.70, 0.72), "carpark": Color(0.52, 0.52, 0.53), "hall": Color(0.74, 0.75, 0.77),
	"stadium": Color(0.68, 0.70, 0.66), "tower": Color(0.62, 0.50, 0.50), "landmark": Color(0.80, 0.77, 0.66),
	"mast": Color(0.72, 0.30, 0.26), "dam": Color(0.72, 0.56, 0.42), "rock": Color(0.40, 0.39, 0.36),
	"deck": Color(0.66, 0.66, 0.64), "pillar": Color(0.58, 0.58, 0.56), "crane": Color(0.74, 0.58, 0.24),
	"aircraft": Color(0.82, 0.82, 0.80), "tram": Color(0.72, 0.67, 0.50), "charger": Color(0.93, 0.94, 0.95), "vehicle": Color(0.36, 0.42, 0.48), "robot": Color(0.15, 0.17, 0.20), "charger_light": Color(0.45, 0.85, 1.0), "office": Color(0.55, 0.63, 0.72), "apartment": Color(0.74, 0.66, 0.52), "luxury": Color(0.90, 0.88, 0.82), "signal": Color(0.30, 0.31, 0.32), "container0": Color(0.62, 0.32, 0.22), "container1": Color(0.26, 0.38, 0.48),
	"container2": Color(0.34, 0.44, 0.32), "container3": Color(0.66, 0.60, 0.48),
}

var plan: Dictionary = {}
var data: Dictionary = {}
var frame: Rect2
var player: CharacterBody3D
var with_player := true
var labels: Array[Label3D] = []
var viewpoints: Array[Dictionary] = []
var _view_index := -1
var _hud: Label
var report := {}
var heights := PackedFloat32Array()
var height_columns := 0
var height_rows := 0
var height_cell := 2.5
## Real houses and recharge stations (scripts/map1/map1_world.gd). Set false before the
## blockout enters the tree for the plain grey boxes.
var with_world := true
var world: Node3D
## The ground picture, one pixel a metre, as loaded: the world reads roads off it.
var ground_image: Image
var ground_body: StaticBody3D
var street_edges: Array[Node3D] = []
## Every box's collision shape hangs on this one body, in the order of shape_box.
var solids: StaticBody3D
## For each collision shape of `solids`, in order: the box (its place in data.boxes) it is.
var shape_box := PackedInt32Array()
var _box_mesh: Array[MultiMesh] = []
var _box_slot := PackedInt32Array()
var _box_shape: Array[CollisionShape3D] = []
var _boxes_out: Dictionary = {}
var _message := ""
var _message_time := 0.0


func _ready() -> void:
	var started := Time.get_ticks_msec()
	plan = _read_json(PLAN_PATH)
	data = _read_json(DATA_PATH)
	# (A test may name another export to compare builds without touching the map's own:
	# -- --map1-export=<path>.)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map1-export="): data = _read_json(arg.trim_prefix("--map1-export="))
	if plan.is_empty() or data.is_empty():
		push_error("Map 1 blockout: run  python tools/map_plan/build_map1_blockout.py  first")
		return
	var f: Array = plan.frame
	frame = Rect2(f[0], f[1], f[2] - f[0], f[3] - f[1])
	_build_sky()
	_build_ground()
	_build_boxes()
	_build_shapes()
	_build_trees()
	_build_mountains()
	_build_markers()
	_lay_street_edges()        # before the world: the houses are planned up to the footway's back
	if with_world:
		world = World.new()
		world.name = "World"
		add_child(world)
		world.setup(self)
		Fuel.install(self)
		UpperShopfront.install(self)
		KobanLane.install(self)
	_build_street_edges()      # after the world: a lowered kerb goes where a house's gate really is
	CarPark.install(self)      # the ground of a coin car park in a gap of a shop row
	Plaza.install(self)        # the paving and tree pits of a plaza along a built road
	if with_world: ShopRowBoards.install(self)
	curve_mirrors = CurveMirrors.install(self)   # at blind lane corners, clear of gates and lowered kerbs
	if with_player: _spawn_player()
	report = {"boxes": (data.boxes as Array).size(), "trees": (data.trees as Array).size(), "build_ms": Time.get_ticks_msec() - started}
	print("MAP1_BLOCKOUT ", JSON.stringify(report))


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _material(colour: Color, rough := 0.9) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = rough
	return material


func _build_sky() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 420.0
	add_child(sun)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_horizon_color = Color(0.72, 0.76, 0.80)
	sky_material.ground_horizon_color = Color(0.62, 0.66, 0.68)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	# A little haze, so far things look far: distance is what this scene is for.
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.66, 0.72, 0.78)
	environment.fog_density = 0.000022
	environment.fog_sky_affect = 0.0
	var world_environment := WorldEnvironment.new()
	world_environment.name = "Sky"
	world_environment.environment = environment
	add_child(world_environment)


func _build_ground() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(GROUND_PATH))
	ground_image = image
	var centre := Vector3(frame.position.x + frame.size.x * 0.5, 0.0, frame.position.y + frame.size.y * 0.5)
	# The heights: one 32-bit number every `cell` metres, written by the map generator.
	var info: Dictionary = data.get("height", {})
	height_columns = int(info.get("columns", 0))
	height_rows = int(info.get("rows", 0))
	height_cell = float(info.get("cell", 2.5))
	var raw := FileAccess.get_file_as_bytes(HEIGHT_DIR + str(info.get("file", "")))
	if raw.size() == height_columns * height_rows * 4 and height_columns > 1:
		heights = raw.to_float32_array()
	else:
		push_warning("Map 1 blockout: no height file, the ground is flat")
		height_columns = 2
		height_rows = 2
		height_cell = maxf(frame.size.x, frame.size.y)
		heights = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
		raw = heights.to_byte_array()
	var plane := PlaneMesh.new()
	plane.size = Vector2((height_columns - 1) * height_cell, (height_rows - 1) * height_cell)
	plane.subdivide_width = height_columns - 2
	plane.subdivide_depth = height_rows - 2
	plane.custom_aabb = AABB(Vector3(-plane.size.x * 0.5, -10.0, -plane.size.y * 0.5), Vector3(plane.size.x, 200.0, plane.size.y))
	var material := ShaderMaterial.new()
	material.shader = load(GROUND_SHADER)
	material.set_shader_parameter("height_map", ImageTexture.create_from_image(Image.create_from_data(height_columns, height_rows, false, Image.FORMAT_RF, raw)))
	material.set_shader_parameter("grid", Vector2(height_columns, height_rows))
	material.set_shader_parameter("cell", height_cell)
	if image != null:
		image.generate_mipmaps()
		material.set_shader_parameter("ground_map", ImageTexture.create_from_image(image))
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.material_override = material
	ground.position = Vector3(frame.position.x + plane.size.x * 0.5, 0.0, frame.position.y + plane.size.y * 0.5)
	add_child(ground)
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.position = ground.position
	var shape := HeightMapShape3D.new()
	shape.map_width = height_columns
	shape.map_depth = height_rows
	shape.map_data = heights
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.scale = Vector3(height_cell, 1.0, height_cell)
	body.add_child(collision)
	add_child(body)
	ground_body = body
	# The sea beyond the bay and the port, and plain land beyond the other edges.
	var beyond := MeshInstance3D.new()
	beyond.name = "Beyond"
	var wide := PlaneMesh.new()
	wide.size = Vector2(60000, 60000)
	beyond.mesh = wide
	beyond.material_override = _material(Color(0.33, 0.37, 0.30))
	beyond.position = centre + Vector3.DOWN * 0.6
	add_child(beyond)
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var sea_plane := PlaneMesh.new()
	sea_plane.size = Vector2(30000, 30000)
	sea.mesh = sea_plane
	sea.material_override = _material(Color(0.24, 0.34, 0.39), 0.35)
	sea.position = Vector3(frame.end.x + 14700.0, -0.05, frame.end.y + 14400.0)
	add_child(sea)


## Build paired kerbs, gutters and footways. The first side owns the carriageway surface.
func _lay_street_edges() -> void:
	var edges: Array = data.get("street_edges", []).duplicate()
	if with_world and KobanLane.has_plots(self) and not edges.any(func(e: Dictionary) -> bool: return e.name == KobanLane.EDGE.name):
		edges.append(KobanLane.EDGE)
	for edge: Dictionary in edges:
		for side: float in [STREET_TRIAL_SIDE, -STREET_TRIAL_SIDE]:
			var street := Street.new()
			street.name = "StreetEdge%s" % ("" if side == STREET_TRIAL_SIDE else "Other")
			if edge.name == KobanLane.EDGE.name:
				street.name = "KobanSouth" if side == STREET_TRIAL_SIDE else "KobanNorth"
			elif edge.name == "shop row":
				street.name = "ShopRowEdge" if side == STREET_TRIAL_SIDE else "ShopRowEdgeOther"
			elif edge.name == "homes link lane":
				street.name = "LinkLaneEdge" if side == STREET_TRIAL_SIDE else "LinkLaneEdgeOther"
			elif edge.name == "tram street south":
				street.name = "TramSouthEdge" if side == STREET_TRIAL_SIDE else "TramSouthEdgeOther"
			elif bool(edge.get("exact", false)):
				street.name = "%s%s" % [str(edge.name).capitalize().replace(" ", ""), "Edge" if side == STREET_TRIAL_SIDE else "EdgeOther"]
			add_child(street)
			street.lay(self, edge, side)
			street.set_meta("edge", edge)
			# (A kerb laid as one side of a narrow strip, the tram fork's south kerb: the other side is not there.)
			if edge.has("only_side"):
				if not is_equal_approx(side, float(edge.only_side)):
					street.runs.clear()
					street.corners.clear()
				elif street.end_patch.is_empty():
					for point: Array in edge.get("end_patch", []): street.end_patch.append(Vector2(float(point[0]), float(point[1])))
			elif edge.name == "tram street south" and side == STREET_TRIAL_SIDE:
				# (The road round the inside of the fork's bend, past the street's end: laid with its road.)
				for point: Array in edge.get("end_patch", []): street.end_patch.append(Vector2(float(point[0]), float(point[1])))
			street.median = float(edge.get("median", 0.0))
			# A lane has a footway only where there is room for one: where a building stands
			# nearer its kerb than the footway is wide, the footway is as wide as the room, and
			# under 60 cm of room that side has the kerb alone, as a narrow lane does.
			# (Where the map has measured the room along the lane and cut it into pieces by it, that
			# width is taken as it is.)
			if bool(edge.get("exact", false)) and edge.has("footway"):
				street.footway_wide = float((edge.footway as Array)[0 if side == STREET_TRIAL_SIDE else 1])
			elif bool(edge.get("exact", false)):
				var room := _room_behind(street)
				if room < float(street.footway_wide) + 0.05:
					street.footway_wide = (room - 0.05) if room - 0.05 >= 0.6 else Street.KERB_WIDE
			if edge.name == "shop row":
				street.forecourt = _forecourt_deep(street)
				# Where a plaza lies behind this side, an apron falls from the footway to it.
				for entry: Dictionary in data.get("spaces", []):
					if bool(entry.get("row_plaza", false)) and float(street.out_of(Vector3(float(entry.x), 0.0, float(entry.back) + float(entry.side)))) > float(street.half):
						street.forecourt = PLAZA_APRON
				# Codex's paving materials for this road's footway and shop forecourt.
				if ResourceLoader.exists("res://scripts/map1/map1_shop_footway.tres"): street.footway_material = load("res://scripts/map1/map1_shop_footway.tres")
				if ResourceLoader.exists("res://scripts/map1/map1_shop_forecourt.tres"): street.forecourt_material = load("res://scripts/map1/map1_shop_forecourt.tres")
				# Its east end (agreed with Codex, 2026-11-14): both footways come down to the road
				# where people step off, by the tram track on one side and onto the painted pavement
				# that carries on on the other; the road's surface runs on to the tram bed's edge.
				if not street.runs.is_empty(): street.low_end_at = (street.runs[street.runs.size() - 1] as Vector2).y
				for point: Array in edge.get("end_patch", []): street.end_patch.append(Vector2(float(point[0]), float(point[1])))
			elif str(edge.name) in TRAM_PAVED:
				# Tram street and its fork take the same fine asphalt footway as the shop row: it is
				# a main street, and the residential lanes it meets keep their plainer finish, so the
				# change at lane x 224's mouth is a real boundary between two kinds of street rather
				# than a seam. (Scope agreed with Codex, 2026-11-16.)
				if ResourceLoader.exists("res://scripts/map1/map1_shop_footway.tres"): street.footway_material = load("res://scripts/map1/map1_shop_footway.tres")
				street.flat_paving = true
			elif edge.name == "shop row west":
				# The shop row carried on to the Outer ring: the same paving, no shops, so no forecourt.
				if ResourceLoader.exists("res://scripts/map1/map1_shop_footway.tres"): street.footway_material = load("res://scripts/map1/map1_shop_footway.tres")
			# The kerb's own surface, on every street. The shared material is Codex's, the height
			# marking it reads out of the vertex alpha and the casting tones round the curves are
			# this side's; all three default off, so this assignment is the only thing that turns
			# them on anywhere. It began on Tram street's ten edges alone and was accepted there
			# on both sides, which left every other kerb in the city flat grey beside a street
			# that looked like precast concrete — a worse mismatch than the one it fixed. Judged
			# again on three streets of other kinds before it was widened. (2026-11-16.)
			if ResourceLoader.exists("res://scripts/map1/map1_kerb_surface.tres"):
				street.kerb_surface_material = load("res://scripts/map1/map1_kerb_surface.tres")
				street.marked_kerb = true
				street.cast_corner_tones = true
			if edge.has("end_corner_r"):
				# Its far end turns a quarter round into the cross road's kerb line and stops there.
				var length := 0.0
				for i: int in range(1, edge.points.size()):
					length += Vector2(float(edge.points[i - 1][0]), float(edge.points[i - 1][1])).distance_to(Vector2(float(edge.points[i][0]), float(edge.points[i][1])))
				street.fillet_at = length
				street.fillet_r = float(edge.end_corner_r)
				street.fillet_angle = PI * 0.5
				street.fillet_end = true
				# (The road's surface runs on to the cross road's kerb line, where its gutter's outer edge is.)
				street.ribbon_end = length + street.fillet_r + Street.GUTTER_WIDE
			if edge.has("end_fillet") and not street.runs.is_empty() and (not edge.has("end_fillet_side") or is_equal_approx(side, float(edge.end_fillet_side))):
				# A kerb that turns round a rounded tip at its end and hands on to another (the
				# tram fork's island): radius, degrees turned, pieces round it.
				street.fillet_at = (street.runs[street.runs.size() - 1] as Vector2).y
				street.fillet_r = float(edge.end_fillet[0])
				street.fillet_angle = deg_to_rad(float(edge.end_fillet[1]))
				street.fillet_steps = int(edge.end_fillet[2])
				if edge.has("end_fillet_footway"): street.fillet_footway = float(edge.end_fillet_footway)
			street_edges.append(street)
		var south: Node3D = street_edges[-2]
		var north: Node3D = street_edges[-1]
		south.opposite_runs = north.runs
		south.opposite_zones = north.mouth_zones()
		if edge.name == "homes street trial": _turning_circle(edge, south, north)
	_islands()
	_cache_edge_reach()


## Where a street ends in a turning circle (the map's space of that kind at its last point):
## each side's straight kerb flares out on a curve into a kerb round the circle, with the
## footway outside it.
const CIRCLE_KERB_R := 9.0
const CIRCLE_FLARE_R := 3.0
var circle_edge: Node3D
## The two street sides that run into the circle, kept from where they are built.
var circle_sides: Array[Node3D] = []

func _turning_circle(edge: Dictionary, first: Node3D, second: Node3D) -> void:
	var last: Array = edge.points[edge.points.size() - 1]
	var centre := Vector2(float(last[0]), float(last[1]))
	var found := false
	for space: Dictionary in data.get("spaces", []):
		if str(space.kind) == "turning circle" and Vector2(float(space.x), float(space.z)).distance_to(centre) < 1.0: found = true
	if not found: return
	var length := 0.0
	for i: int in range(1, edge.points.size()):
		length += Vector2(float(edge.points[i - 1][0]), float(edge.points[i - 1][1])).distance_to(Vector2(float(edge.points[i][0]), float(edge.points[i][1])))
	var angles: Array[float] = []
	for street: Node3D in [first, second]:
		var out_f := float(street.half) + CIRCLE_FLARE_R
		var reach := sqrt(pow(CIRCLE_KERB_R + CIRCLE_FLARE_R, 2.0) - out_f * out_f)
		street.fillet_at = length - reach
		street.fillet_r = CIRCLE_FLARE_R
		street.fillet_angle = acos(out_f / (CIRCLE_KERB_R + CIRCLE_FLARE_R))
		var run: Vector2 = street.runs[street.runs.size() - 1]
		street.runs[street.runs.size() - 1] = Vector2(run.x, minf(run.y, street.fillet_at))
		street.fillet_at = street.runs[street.runs.size() - 1].y
		street.ribbon_end = street.fillet_at
		var meet: Vector2 = street.fillet_point(CIRCLE_FLARE_R, street.fillet_angle)
		var world: Vector3 = street.at(meet.x, meet.y)
		angles.append(atan2(world.z - centre.y, world.x - centre.x))
	var from_angle := minf(angles[0], angles[1])
	var to_angle := maxf(angles[0], angles[1])
	# (Round the far side of the circle, away from the street.)
	var towards := (centre - Vector2(float(edge.points[edge.points.size() - 2][0]), float(edge.points[edge.points.size() - 2][1]))).normalized()
	var mid := (from_angle + to_angle) * 0.5
	if Vector2(cos(mid), sin(mid)).dot(towards) < 0.0:
		var keep := from_angle
		from_angle = to_angle
		to_angle = keep + TAU
	var ring := Street.new()
	ring.name = "TurningCircleEdge"
	# The round carrier is built by its own path and so never saw the kerb assignment the other
	# 95 families get — one plain kerb in a city of precast ones, which is the mismatch the
	# widening existed to remove. It takes the same three properties, set here before the arc is
	# made. `make_round` feeds the arc through `_unit`, which already writes each exposed
	# vertex's height above the ground sampled at the kerb face and resets the caps and footway
	# to alpha 1, so no Street change is needed; and because the ring never touches `_piece`,
	# `cast_corner_tones` adds no colour of its own here. (Codex checked that path before
	# clearing this, 2026-11-16; the ring gets its own native pair.)
	if ResourceLoader.exists("res://scripts/map1/map1_kerb_surface.tres"):
		ring.kerb_surface_material = load("res://scripts/map1/map1_kerb_surface.tres")
		ring.marked_kerb = true
		ring.cast_corner_tones = true
	add_child(ring)
	ring.make_round(self, centre, CIRCLE_KERB_R, from_angle, to_angle, float(first.footway_wide))
	var room := _room_behind(ring)
	if room < float(ring.footway_wide) + 0.05: ring.footway_wide = maxf(room - 0.05, Street.KERB_WIDE)
	ring.set_meta("edge", {"name": "turning circle", "exact": false, "points": [[centre.x - 12.0, centre.y - 12.0], [centre.x + 12.0, centre.y + 12.0]]})
	street_edges.append(ring)
	circle_edge = ring
	# The two sides that actually run into this circle, kept because they are known here and
	# nowhere else. `_circle_asphalt()` used to look for them by gathering every edge in the map
	# with `fillet_at >= 0` and giving up unless exactly two came back — but `end_corner_r` and
	# `end_fillet` set that same flag on shop and tram corners that have nothing to do with the
	# circle. Nine edges carry it, so the selector gave up every time and the circle's road was
	# never laid: flat picture ground beside textured approaches, for want of knowing which two.
	# (Codex spotted the selector, 2026-11-16; tests/probe_circle_asphalt.gd counted the nine.)
	circle_sides = [first, second]
	# The ring and its own two approaches take Codex's local asphalt footway: the approved
	# street photograph has a dark granular footway here and ours is still flat FOOTWAY vertex
	# colour, which is what shows beside the textured road in the circle views. Not the shop
	# row's tiles — this is a residential end, and it keeps its own finish. The three of them
	# get the material, the vertex tone for it to tint from, and flat shading, and nothing else
	# in the map changes. Guarded, so a checkout without Codex's resource still builds.
	# (Its interface request, 2026-11-16; the shader and material are its own.)
	if ResourceLoader.exists("res://scripts/map1/map1_local_footway_asphalt.tres"):
		for street: Node3D in [ring, first, second]:
			street.footway_material = load("res://scripts/map1/map1_local_footway_asphalt.tres")
			street.retain_footway_color = true
			street.flat_paving = true


## The circle's road surface, after both sides and the ring are built.
func _circle_asphalt() -> void:
	if circle_edge == null: return
	# The circle's own two approach sides, recorded where they were known, rather than every
	# edge in the map that happens to carry a fillet.
	var sides: Array[Node3D] = circle_sides
	if sides.size() != 2: return
	var lays: Node3D = sides[0] if sides[0].side == STREET_TRIAL_SIDE else sides[1]
	var other: Node3D = sides[1] if lays == sides[0] else sides[0]
	var g := Street.GUTTER_WIDE
	var outline := PackedVector3Array()
	# This side's flare, from the ribbon's end out to the circle.
	for k: int in lays.fillet_pieces() + 1:
		var p: Vector2 = lays.fillet_point(float(lays.fillet_r) + g, float(lays.fillet_angle) * float(k) / float(lays.fillet_pieces()))
		outline.append(lays.at(p.x, p.y))
	# Round the circle, from this side's end of the ring to the other's, at every unit's end.
	var run: Vector2 = circle_edge.runs[0]
	var marks: Array[float] = []
	var s := run.x
	while s < run.y - 0.001:
		marks.append(s)
		s += Street.UNIT
	marks.append(run.y)
	var near_lays := (circle_edge.at(run.x, float(circle_edge.half)) as Vector3).distance_to(outline[outline.size() - 1]) < (circle_edge.at(run.y, float(circle_edge.half)) as Vector3).distance_to(outline[outline.size() - 1])
	if not near_lays: marks.reverse()
	for m: float in marks: outline.append(circle_edge.at(m, float(circle_edge.half) - g))
	# The other side's flare, back to its ribbon's end.
	for k: int in range(other.fillet_pieces(), -1, -1):
		var p: Vector2 = other.fillet_point(float(other.fillet_r) + g, float(other.fillet_angle) * float(k) / float(other.fillet_pieces()))
		outline.append(other.at(p.x, p.y))
	var last: Array = (lays.get_meta("edge") as Dictionary).points
	var centre: Array = last[last.size() - 1]
	lays.circle_asphalt(outline, Vector3(float(centre[0]), 0.0, float(centre[1])))


## Where two lanes run side by side, the ground between them. Narrower than two footways: one
## island, the wider lane's footway across it and the other lane's kerb alone along its other
## edge, rounded off as one nose where it meets a street. Wider, but by under three metres:
## the strip between the two footways is paved, so it is not a trench.
func _islands() -> void:
	var exact: Array[Node3D] = []
	for street: Node3D in street_edges:
		var its: Dictionary = street.get_meta("edge")
		# (Not a kerb laid on its own: it is no lane with a neighbour.)
		if bool(its.get("exact", false)) and not street.runs.is_empty() and not its.has("only_side"): exact.append(street)
	var narrow: Array = []
	var wide: Array = []
	for a: Node3D in exact:
		for b: Node3D in exact:
			if a.get_instance_id() >= b.get_instance_id() or (a.get_meta("edge") as Dictionary).name == (b.get_meta("edge") as Dictionary).name: continue
			var overlap := _side_by_side(a, b)
			if overlap.is_empty(): continue
			var gap := float(overlap.gap)
			if gap < float(a.footway_wide) + float(b.footway_wide) + 0.05: narrow.append([a, b, overlap])
			elif gap - float(a.footway_wide) - float(b.footway_wide) < 3.0: wide.append([a, b])
	for entry: Array in narrow:
		var a: Node3D = entry[0]
		var b: Node3D = entry[1]
		var keeper: Node3D = a if float(a.half) >= float(b.half) else b
		var other: Node3D = b if keeper == a else a
		var gap := float(entry[2].gap)
		keeper.footway_wide = gap - Street.KERB_WIDE
		keeper.nose_radius = gap * 0.5
		keeper.set_meta("island_partner", other)
		other.footway_wide = Street.KERB_WIDE
		other.set_meta("island_keeper", keeper)
	for entry: Array in wide:
		var a: Node3D = entry[0]
		var b: Node3D = entry[1]
		var overlap := _side_by_side(a, b)
		if overlap.is_empty(): continue
		var gap := float(overlap.gap)
		if gap - float(a.footway_wide) - float(b.footway_wide) < 0.05: continue
		var pairs: Array = a.get_meta("infill", [])
		pairs.append({"s0": float(overlap.lo), "s1": float(overlap.hi), "out0": float(a.half) + float(a.footway_wide), "out1": float(a.half) + gap - float(b.footway_wide)})
		a.set_meta("infill", pairs)


## How far out the wall across a dead end reaches on one side: to the footway's back, and on
## across any paved strip between lanes that ends on the same line; short of any building.
func _end_wall_reach(street: Node3D, dir: float, back: float = 0.0) -> float:
	var run: Vector2 = street.runs[street.runs.size() - 1] if dir > 0.0 else street.runs[0]
	var end_s: float = (run.y if dir > 0.0 else run.x) + dir * back
	var origin: Vector3 = street.at(end_s, 0.0)
	var heading: Vector3 = (street.at(end_s + 1.0, 0.0) - origin).normalized()
	var reach := float(street.half) + float(street.footway_wide)
	# (A side whose footway is an island shared with the lane beside it: the wall closes this lane's
	# road and kerb only, and the island stays open to walk along from the other lane.)
	if street.has_meta("island_partner"): reach = float(street.half) + Street.KERB_WIDE
	for other: Node3D in street_edges:
		for piece: Dictionary in other.get_meta("infill", []):
			for s: float in [float(piece.s0), float(piece.s1)]:
				var p0: Vector3 = other.at(s, float(piece.out0))
				var p1: Vector3 = other.at(s, float(piece.out1))
				if absf((p0 - origin).dot(heading)) > 0.1 or absf((p1 - origin).dot(heading)) > 0.1: continue
				var o0 := float(street.out_of(p0))
				var o1 := float(street.out_of(p1))
				if minf(o0, o1) > float(street.half) and minf(o0, o1) < reach + 0.1: reach = maxf(reach, maxf(o0, o1))
	# Short of any building standing across the line.
	# (A centimetre at a time, so the wall meets the building's face; its coping may run into it.)
	# (Never off the kerb, though: where a building stands on the kerb's back, the wall's end tucks
	# into it.)
	# (A wall set back past the end has no kerb to keep to: it stops at the building's face.)
	var least := (float(street.half) + Street.KERB_WIDE) if back <= 0.0 else 0.0
	while reach > least + 0.001 and _in_a_building(street.at(end_s + dir * Street.END_WALL_THICK * 0.5, reach)):
		reach -= 0.01
	return reach


## How far past a dead end its wall has to stand so that it does not cut off the way in to a
## house: the door of a made house, from a step inside its wall out to where one stands in front of it, with room for
## a person either side. 0 where no door is near (the wall stands at the end, as it always has);
## further back, in steps, until both halves of the wall clear every door, to END_WALL_BACK_MOST.
## (Found at lane x 219's north end, 2026-11-15: house 1662 stands at 45 degrees with its door on
## the wall facing the lane's end, and the wall ran into the door.)
## Every dead end's wall: "<edge name> <+1 or -1>" -> {"back": metres past the end, "house": the box whose door it
## clears (-1 if none), "door": that door's point}. For checks and surveys.
var end_wall_backs: Dictionary = {}
const END_WALL_BACK_MOST := 3.0
const DOOR_CLEAR := 0.75      # room for a person to pass the wall's end and turn into the door; 0.45 left house 1662's walk out failing (Codex, 2026-11-15)
func _end_wall_back(street: Node3D, dir: float) -> float:
	if world == null: return 0.0
	var run: Vector2 = street.runs[street.runs.size() - 1] if dir > 0.0 else street.runs[0]
	var end_s: float = run.y if dir > 0.0 else run.x
	var full := float(street.half) + 2.0
	var near: Vector3 = street.at(end_s, 0.0)
	var ways: Array = []          # each door's way in: [from, to, the house's box] on the ground
	var key := "%s %+d" % [str(street.get_meta("edge").name), int(dir)]
	end_wall_backs[key] = {"back": 0.0, "house": -1, "door": Vector3.ZERO}
	for index: int in world.candidates:
		var box: Array = data.boxes[index]
		if Vector2(float(box[0]) - near.x, float(box[2]) - near.z).length() > 25.0: continue
		var site: Dictionary = world.site(index)
		if not bool(site.ok): continue
		var door: Vector3 = site.door_point
		var out: Vector3 = site.street_out
		# (From inside the door to where one stands in front of it, and no further: past that point a person steps round a wall's end, as at lane z 405's dead end, where nothing was ever in the way.)
		ways.append([Vector2(door.x - out.x * 1.6, door.z - out.z * 1.6), Vector2(door.x, door.z), index, door])
	if ways.is_empty(): return 0.0
	var back := 0.0
	while back <= END_WALL_BACK_MOST + 0.001:
		var s := end_s + dir * (back + Street.END_WALL_THICK * 0.5)
		var a: Vector3 = street.at(s, -full)
		var b: Vector3 = street.at(s, full)
		var cut := false
		for way: Array in ways:
			for step: int in 13:
				var p: Vector2 = (way[0] as Vector2).lerp(way[1], float(step) / 12.0)
				var on_wall := Geometry2D.get_closest_point_to_segment(p, Vector2(a.x, a.z), Vector2(b.x, b.z))
				# (Only where the wall would really stand: not where a building takes its place.)
				if p.distance_to(on_wall) < DOOR_CLEAR and not _in_a_building(Vector3(on_wall.x, 0.0, on_wall.y)):
					cut = true
					if back == 0.0: end_wall_backs[key] = {"back": 0.0, "house": int(way[2]), "door": way[3]}
		if not cut:
			(end_wall_backs[key] as Dictionary)["back"] = back
			return back
		back += 0.2
	return 0.0


func _in_a_building(p: Vector3) -> bool:
	for box: Array in data.boxes:
		if float(box[3]) < 3.0 or float(box[5]) < 3.0: continue
		var local := Basis(Vector3.UP, deg_to_rad(float(box[6]))).inverse() * Vector3(p.x - float(box[0]), 0.0, p.z - float(box[2]))
		if absf(local.x) <= float(box[3]) * 0.5 and absf(local.z) <= float(box[5]) * 0.5: return true
	return false


## Whether two lanes' sides face each other across a strip of ground, and if so how wide it is
## (kerb face to kerb face) and over what stretch of the first, in its metres along.
func _side_by_side(a: Node3D, b: Node3D) -> Dictionary:
	var b_run: Vector2 = b.runs[0]
	var b_mid := (b_run.x + b_run.y) * 0.5
	var b_face: Vector3 = b.at(b_mid, float(b.half))
	var b_out: Vector3 = b.at(b_mid, float(b.half) + 1.0) - b_face
	var a_s := float(a.along_of(b_face))
	var a_face: Vector3 = a.at(a_s, float(a.half))
	var a_out: Vector3 = a.at(a_s, float(a.half) + 1.0) - a_face
	if a_out.dot(b_out) > -0.95: return {}
	var gap := float(a.out_of(b_face)) - float(a.half)
	if gap <= 0.0 or gap > 8.0: return {}
	var a_run: Vector2 = a.runs[0]
	var e0 := float(a.along_of(b.at(b_run.x, float(b.half))))
	var e1 := float(a.along_of(b.at(b_run.y, float(b.half))))
	var lo := maxf(minf(e0, e1), a_run.x)
	var hi := minf(maxf(e0, e1), a_run.y)
	if hi - lo < 0.5: return {}
	return {"gap": gap, "lo": lo, "hi": hi}


## A footway end that no other street's corner comes round to meet gets a rounded nose, and
## the street whose mouth it stands in cuts its asphalt round it. Worked out before anything
## is built, since the two streets are built in turn.
func _find_noses() -> void:
	for street: Node3D in street_edges:
		var edge: Dictionary = street.get_meta("edge")
		if not bool(edge.get("exact", false)): continue
		var length := Vector2(float(edge.points[0][0]), float(edge.points[0][1])).distance_to(Vector2(float(edge.points[1][0]), float(edge.points[1][1])))
		var kinds: Array = edge.get("ends", ["joined", "joined"])
		for end: Array in [[0.0, -1.0, kinds[0]], [length, 1.0, kinds[1]]]:
			# (Only an end that reaches another built street: a dead end or the block's edge just stops.)
			if str(end[2]) != "joined": continue
			var face: Vector3 = street.at(float(end[0]), float(street.half))
			var met := false
			for other: Node3D in street_edges:
				if other == street: continue
				for corner: Dictionary in other.corners:
					if (other.at(float(corner.mouth), float(other.half) + float(other.footway_wide)) as Vector3).distance_to(face) < 0.15: met = true
			if met: continue
			# (A side that is only the kerb of an island does not get one: the island's nose is
			# its footway side's, and this kerb runs on to meet it.)
			if street.has_meta("island_keeper") or float(street.footway_wide) <= Street.KERB_WIDE + 0.01: continue
			street.noses.append(float(end[1]))
			# The nose's half circle: its middle is half the island out from the kerb's face; its
			# tip reaches the kerb line of the street it stands in, whose footway back this end is on.
			var radius := float(street.nose_radius) if float(street.nose_radius) > 0.0 else float(street.footway_wide) * 0.5
			var whole: float = (street.runs[0] as Vector2).x if float(end[1]) < 0.0 else (street.runs[street.runs.size() - 1] as Vector2).y
			var base: Vector3 = street.at(whole, float(street.half) + radius)
			var heading: Vector3 = (street.at(whole + 1.0, float(street.half)) - street.at(whole, float(street.half))).normalized()
			var host: Node3D = null
			for other: Node3D in street_edges:
				if other == street or (other.get_meta("edge") as Dictionary).name == edge.name: continue
				var across: Vector3 = (other.at(1.0, float(other.half)) - other.at(0.0, float(other.half))).normalized()
				if absf(across.dot(heading)) > 0.3: continue
				if absf(float(other.out_of(base)) - float(other.half) - float(other.footway_wide)) < 0.15:
					host = other
					break
			var reach := float(host.footway_wide) if host != null else radius * 2.0
			street.nose_reach = reach
			var middle: Vector3 = street.at(whole + float(end[1]) * (reach - radius), float(street.half) + radius)
			var kerb_at: Vector3 = street.at(whole + float(end[1]) * (reach - radius), float(street.half))
			var partner: Node3D = street.get_meta("island_partner", null)
			if host != null:
				host.mouth_holes.append({"s": float(host.along_of(middle)), "out": float(host.out_of(middle)), "radius": radius,
					"kerb": signf(float(host.along_of(kerb_at)) - float(host.along_of(middle))), "closed": partner != null})
			# The island's other kerb runs on to where the half circle meets it.
			if partner != null:
				var run: Vector2 = partner.runs[0]
				var near_start: bool = (partner.at(run.x, float(partner.half)) as Vector3).distance_to(middle) < (partner.at(run.y, float(partner.half)) as Vector3).distance_to(middle)
				var from_s: float = run.x if near_start else run.y
				var p0: Vector3 = partner.at(from_s, float(partner.half))
				var forward: Vector3 = (partner.at(from_s + 1.0, float(partner.half)) - p0).normalized()
				var shift := (middle - p0).dot(forward)
				partner.runs[0] = Vector2(run.x + shift, run.y) if near_start else Vector2(run.x, run.y + shift)


## Lowered kerbs go where a car crosses the footway: at a house's carport and at a plot cars
## are parked on. A footpath gate keeps the full kerb, but for the one gate of the first trial.
func _build_street_edges() -> void:
	_find_noses()
	for street: Node3D in street_edges:
		_build_one(street)
		# One traced paved surface, where footways would overlap or a wall stands in the way (the tram
		# fork's island and the inside of its bend): built with the side that carries it.
		var edge: Dictionary = street.get_meta("edge")
		if edge.has("paving") and not street.runs.is_empty() and is_equal_approx(float(street.side), float(edge.get("paving_side", edge.get("only_side", 1.0)))):
			var outline := PackedVector2Array()
			for point: Array in edge.paving: outline.append(Vector2(float(point[0]), float(point[1])))
			var faces := PackedInt32Array()
			for index: Variant in edge.get("paving_faces", []): faces.append(int(index))
			street.paving(outline, faces)
	_circle_asphalt()


func _build_one(street: Node3D) -> void:
	var edge: Dictionary = street.get_meta("edge")
	var first: bool = street.side == STREET_TRIAL_SIDE
	var entrances: Array = _carports_near(edge)
	entrances.append_array(street.car_parks(4.2))
	# A lowered kerb the map asks for by name: at a front door that opens straight onto a lane too
	# narrow for a footway, so the kerb's top meets the house's own doorstep (lane x 224, house 4474).
	for entry: Dictionary in edge.get("entrances", []):
		entrances.append({"at": Vector3(float(entry.x), 0.0, float(entry.z)), "wide": float(entry.get("wide", 1.8)), "what": str(entry.get("what", "door"))})
	if edge.name == KobanLane.EDGE.name:
		# A drain and a walking edge serve the terrace. The existing police beacon is the landmark here.
		if first: street.build(entrances, ["grate","asphalt"])
		else: street.build(entrances, [])
	elif edge.name == "turning circle":
		street.build(entrances, [])
	elif edge.has("only_side"):
		# A kerb on its own (the tram fork's south kerb): no ribbon of road, but the patch of road
		# given with it; and behind its footway a wedge of paving where the footway it carries on
		# from is wider, narrowing to nothing at its far end.
		if street.runs.is_empty(): return
		var kit: Array = ["patch", "pole"]
		if bool(edge.get("grate", false)): kit.append("grate")
		street.build(entrances, kit)
		var wider := float(edge.get("footway_from", float(street.footway_wide))) - float(street.footway_wide)
		if wider > 0.02:
			var run: Vector2 = street.runs[0]
			var back := float(street.half) + float(street.footway_wide)
			street.wedge(run.x, run.y, back, back + wider, back)
		# (Or the other way: the footway it hands on to is wider, and the wedge grows to it.)
		var grows := float(edge.get("footway_to", float(street.footway_wide))) - float(street.footway_wide)
		if grows > 0.02:
			var run: Vector2 = street.runs[0]
			var back := float(street.half) + float(street.footway_wide)
			street.wedge(run.x, run.y, back, back, back + grows)
	elif edge.name == "shop row west":
		# The shop row's road carried on: its edge line too. The first side lays the road.
		if first: street.build(entrances, ["asphalt"])
		else: street.build(entrances, [])
	elif bool(edge.get("exact", false)):
		# A lane laid between built streets: too narrow for an edge line.
		# (The pole line goes down one side of a lane, as it does on a real one: the first side.)
		if first: street.build(entrances, ["asphalt", "no line", "pole"])
		else: street.build(entrances, [])
		for piece: Dictionary in street.get_meta("infill", []):
			street.infill(float(piece.s0), float(piece.s1), float(piece.out0), float(piece.out1))
		var kinds: Array = edge.get("ends", ["joined", "joined"])
		for end: Array in [[-1.0, kinds[0]], [1.0, kinds[1]]]:
			if str(end[1]) == "dead":
				# (Both sides of the lane find the same distance back: the test takes the whole wall.)
				var back := _end_wall_back(street, float(end[0]))
				var reach := _end_wall_reach(street, float(end[0]), back)
				street.end_wall(float(end[0]), reach, back)
				# The ground between the lane's end and a wall set back from it is paved at the footway's
				# height right across, up to the wall: so the footway carries on flush to the wall and
				# its raised end is not left as a corner in front of the door the wall stood back for.
				# (House 4454 at lane z 405's end: the player's shoulder caught that corner. Codex, 2026-11-15.)
				if back > 0.0 and reach > 0.05:
					var run: Vector2 = street.runs[street.runs.size() - 1] if float(end[0]) > 0.0 else street.runs[0]
					var end_s: float = run.y if float(end[0]) > 0.0 else run.x
					street.infill(minf(end_s, end_s + float(end[0]) * back), maxf(end_s, end_s + float(end[0]) * back), 0.0, reach, true)
	elif edge.name == "shop row":
		# The first wide road: shops stand at the footway, so no gate; the first side lays the road.
		# The kerb is lowered on both sides where the zebra crossing meets it (six units, 3.6 m,
		# from 166.8 to 170.4 m along; the zebra is 3.2 m wide).
		entrances.append({"at": street.at(SHOP_ROW_CROSSING, float(street.half) + 1.0), "wide": 3.6, "what": "crossing"})
		if first: street.build(entrances)
		else: street.build(entrances, [])
	elif first:
		for gate: Vector3 in _gates_near(edge):
			if float(street.plot_gap(gate)) < INF:
				entrances.append({"at": gate, "wide": 1.8, "what": "gate"})
				break
		street.build(entrances)
	else:
		street.build(entrances, [])


## How far the nearest building stands behind the kerb's road face along one side of a laid
## edge (INF if none within six metres).
func _room_behind(street: Node3D) -> float:
	var room := INF
	var length := 0.0
	for run: Vector2 in street.runs: length = maxf(length, run.y)
	for box: Array in data.boxes:
		if float(box[3]) < 3.0 or float(box[5]) < 3.0: continue
		var middle := Vector3(float(box[0]), 0.0, float(box[2]))
		if absf(float(street.out_of(middle))) > 30.0: continue
		var turn := Basis(Vector3.UP, deg_to_rad(float(box[6])))
		var half_box := Vector3(float(box[3]) * 0.5, 0.0, float(box[5]) * 0.5)
		for corner: Vector3 in [Vector3(1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(-1, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			var point := middle + turn * (half_box * corner)
			var along := float(street.along_of(point))
			var out := float(street.out_of(point)) - float(street.half)
			# (along_of holds a point past either end at that end: such a point is beside it only
			# if it is truly level with the edge.)
			var beside: Vector3 = street.at(along, float(street.half) + out)
			if beside.distance_to(Vector3(point.x, beside.y, point.z)) > 0.3: continue
			if along < -0.01 or along > length + 0.01 or out <= 0.0 or out > 6.0: continue
			room = minf(room, out)
	return room


## How deep a shop forecourt is on one side of a street: from the footway's back to the
## nearest building face that stands within six metres of it (0 if none does).
func _forecourt_deep(street: Node3D) -> float:
	var deep := INF
	for box: Array in data.boxes:
		var middle := Vector3(float(box[0]), 0.0, float(box[2]))
		if float(box[3]) < 3.0 or float(box[5]) < 3.0: continue      # a post, a signal: not a building
		if absf(float(street.out_of(middle))) > 40.0: continue
		var turn := Basis(Vector3.UP, deg_to_rad(float(box[6])))
		for face: Vector3 in [Vector3(float(box[3]) * 0.5, 0, 0), Vector3(-float(box[3]) * 0.5, 0, 0), Vector3(0, 0, float(box[5]) * 0.5), Vector3(0, 0, -float(box[5]) * 0.5)]:
			var gap := float(street.plot_gap(middle + turn * face))
			if gap > 0.3 and gap < 6.0: deep = minf(deep, gap)
	return 0.0 if deep == INF else deep


## How high the paving of a built street stands above the ground at a point (0 off it).
## The reach of each built edge, worked out once, so a room query does not run the full
## calculation against every street in the map. These are conservative bounds and nothing more:
## whatever they let through is still decided by the edge's own `plot_gap` and `lift_at`, which
## are unchanged. (Asked for by Codex 2026-11-16, after its count showed these two queries scan
## every side in the map for every house. The bounds are built only after `_lay_street_edges` has
## finished, because `_islands` and the forecourt rules change widths during that setup.)
## On the map as it stands that is 191 sides: 183 with a box and 8 always asked.
##
## A straight edge and a round one get a box; a bent one gets none and is always asked, because
## at an internal bend `beside` combines one segment's frame with the next one's tangent, and a
## box round the centre line grown by the lateral reach is not provably conservative there.
## Bounds are inclusive at both ends, not Rect2's half-open maximum.
var _gap_reach: Array = []        # [street, min_x, min_z, max_x, max_z]
var _lift_reach: Array = []
var _gap_always: Array[Node3D] = []
var _lift_always: Array[Node3D] = []
const GAP_BEYOND := 12.0          # plot_gap answers out to half + footway + this
## And a box must reach past the centre line's own ends as well as out to its side: `beside`
## lets a point stand `along_tolerance` (0.2 m) beyond an end and still count, so a rotated
## frontage can be answered by a cap that a radius-only box would have rejected. 1 mm of slack
## on top for the arithmetic. (Codex's correction, 2026-11-16.)
const BESIDE_SLACK := 0.201

func _cache_edge_reach() -> void:
	_gap_reach.clear()
	_lift_reach.clear()
	_gap_always.clear()
	_lift_always.clear()
	for street: Node3D in street_edges:
		var gap_out := float(street.half) + float(street.footway_wide) + GAP_BEYOND
		var lift_out := float(street.half) + float(street.footway_wide) + float(street.forecourt)
		var does_lift: bool = float(street.forecourt) > 0.0      # lift_at returns 0 without one
		if bool(street.is_round):
			var middle: Vector2 = street.round_centre
			_gap_reach.append([street, middle.x - gap_out, middle.y - gap_out, middle.x + gap_out, middle.y + gap_out])
			if does_lift: _lift_reach.append([street, middle.x - lift_out, middle.y - lift_out, middle.x + lift_out, middle.y + lift_out])
			continue
		var edge: Dictionary = street.get_meta("edge", {})
		var pts: Array = edge.get("points", [])
		if pts.size() != 2:
			_gap_always.append(street)
			if does_lift: _lift_always.append(street)
			continue
		var ax := float(pts[0][0])
		var az := float(pts[0][1])
		var bx := float(pts[1][0])
		var bz := float(pts[1][1])
		# A line of no length is not a straight edge we can certify: hand it to the always-asked
		# list and let the unchanged narrow phase keep whatever it answers today.
		if absf(bx - ax) < 1e-6 and absf(bz - az) < 1e-6:
			_gap_always.append(street)
			if does_lift: _lift_always.append(street)
			continue
		gap_out += BESIDE_SLACK
		lift_out += BESIDE_SLACK
		_gap_reach.append([street, minf(ax, bx) - gap_out, minf(az, bz) - gap_out, maxf(ax, bx) + gap_out, maxf(az, bz) + gap_out])
		if does_lift: _lift_reach.append([street, minf(ax, bx) - lift_out, minf(az, bz) - lift_out, maxf(ax, bx) + lift_out, maxf(az, bz) + lift_out])


func paving_lift(x: float, z: float) -> float:
	var lift := 0.0
	var point := Vector3(x, 0.0, z)
	for entry: Array in _lift_reach:
		if x < float(entry[1]) or x > float(entry[3]) or z < float(entry[2]) or z > float(entry[4]): continue
		lift = maxf(lift, float((entry[0] as Node3D).lift_at(point)))
	for street: Node3D in _lift_always: lift = maxf(lift, float(street.lift_at(point)))
	return lift


## How far a house's front stands behind the footway of a built street edge, or INF if no
## built edge runs in front of it.
func footway_gap(front: Vector3) -> float:
	var gap := INF
	for entry: Array in _gap_reach:
		if front.x < float(entry[1]) or front.x > float(entry[3]) or front.z < float(entry[2]) or front.z > float(entry[4]): continue
		gap = minf(gap, float((entry[0] as Node3D).plot_gap(front)))
	for street: Node3D in _gap_always: gap = minf(gap, float(street.plot_gap(front)))
	return gap


## The carports of the makeable houses along a street: the middle of each, 5 m wide.
func _carports_near(edge: Dictionary) -> Array:
	var found: Array = []
	if world == null: return found
	for index: int in _houses_near(edge):
		var site: Dictionary = world.site(index)
		if not bool(site.ok) or not bool(site.on_road) or not "carport" in str(site.features.plot): continue
		for lean: Dictionary in (site.spec as Dictionary).get("lean_tos", []):
			var a: Vector2 = lean.a
			var b: Vector2 = lean.b
			if a.y < -0.2 and is_equal_approx(absf(b.x - a.x), 5.0):
				found.append({"at": (site.frame as Transform3D) * Vector3((a.x + b.x) * 0.5, 0.0, 0.0), "wide": 5.0, "what": "carport"})
	return found


## The makeable houses within reach of a street's line.
func _houses_near(edge: Dictionary) -> PackedInt32Array:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point: Array in edge.points:
		low = low.min(Vector2(float(point[0]), float(point[1])))
		high = high.max(Vector2(float(point[0]), float(point[1])))
	var reach := Rect2(low, high - low).grow(18.0)
	var found := PackedInt32Array()
	for index: int in world.candidates:
		var box: Array = data.boxes[index]
		if reach.has_point(Vector2(float(box[0]), float(box[2]))): found.append(index)
	return found

## The gates of the makeable houses along a street, nearest the trial point first: the middle
## of the opening between each house's gate pillars, as the house's own plan places it.
## None without the world (it holds the house plans).
func _gates_near(edge: Dictionary) -> Array:
	if world == null: return []
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point: Array in edge.points:
		low = low.min(Vector2(float(point[0]), float(point[1])))
		high = high.max(Vector2(float(point[0]), float(point[1])))
	var reach := Rect2(low, high - low).grow(18.0)
	var gates: Array = []
	for index: int in world.candidates:
		var box: Array = data.boxes[index]
		if not reach.has_point(Vector2(float(box[0]), float(box[2]))): continue
		var site: Dictionary = world.site(index)
		if not bool(site.ok) or not bool(site.on_road) or not "gate pillars" in str(site.features.plot): continue
		# The gate stands in line with the front door, on the plot's wall towards the street.
		var door: Vector3 = (site.frame as Transform3D) * Vector3(float(site.spec.doors[0].at), 0.0, 0.0)
		gates.append(door)
	gates.sort_custom(func(a: Vector3, b: Vector3) -> bool: return Vector2(a.x - STREET_TRIAL_AT.x, a.z - STREET_TRIAL_AT.y).length() < Vector2(b.x - STREET_TRIAL_AT.x, b.z - STREET_TRIAL_AT.y).length())
	return gates


## Height of the ground at a point, from the same samples the ground mesh is drawn with.
func ground_height(x: float, z: float) -> float:
	if heights.is_empty(): return 0.0
	var fx := clampf((x - frame.position.x) / height_cell, 0.0, height_columns - 1.001)
	var fz := clampf((z - frame.position.y) / height_cell, 0.0, height_rows - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var top := lerpf(heights[j * height_columns + i], heights[j * height_columns + i + 1], tx)
	var bottom := lerpf(heights[(j + 1) * height_columns + i], heights[(j + 1) * height_columns + i + 1], tx)
	return lerpf(top, bottom, tz)


func on_ground(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, ground_height(x, z) + lift, z)


func _build_boxes() -> void:
	var kinds: Array = data.kinds
	var boxes: Array = data.boxes
	var grouped: Dictionary = {}
	for index: int in boxes.size():
		var kind: String = kinds[int(boxes[index][7])]
		# The world builds the recharge stations for real: their stand-in boxes are left out.
		if with_world and World.STATION_KINDS.has(kind): continue
		if not grouped.has(kind): grouped[kind] = []
		grouped[kind].append(index)
	var body := StaticBody3D.new()
	body.name = "Solids"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	solids = body
	_box_mesh.resize(boxes.size())
	_box_slot.resize(boxes.size())
	_box_shape.resize(boxes.size())
	var unit := BoxMesh.new()
	for kind: String in grouped:
		var list: Array = grouped[kind]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = unit
		multimesh.instance_count = list.size()
		for i: int in list.size():
			var b: Array = boxes[int(list[i])]
			var size := Vector3(b[3], b[4], b[5])
			var turn := Basis(Vector3.UP, deg_to_rad(float(b[6])))
			var at := Vector3(b[0], float(b[1]) + size.y * 0.5, b[2])
			multimesh.set_instance_transform(i, Transform3D(turn * Basis.from_scale(size), at))
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = size
			collision.shape = shape
			collision.transform = Transform3D(turn, at)
			body.add_child(collision)
			# Where this box is drawn and what makes it solid, so one box can be taken out
			# and put back (set_box_drawn, set_box_solid) without building anything again.
			_box_mesh[int(list[i])] = multimesh
			_box_slot[int(list[i])] = i
			_box_shape[int(list[i])] = collision
			shape_box.append(int(list[i]))
		var instance := MultiMeshInstance3D.new()
		instance.name = "Boxes_" + kind.replace("-", "_shut")
		instance.multimesh = multimesh
		# A kind ending in -a or -b is a building that stays shut (15% of the town), in one of
		# its two looks: darkened two ways, so the ones you cannot enter show at a glance.
		var colour: Color = KIND_COLOURS.get(kind.get_slice("-", 0), Color(0.6, 0.6, 0.6))
		if kind.ends_with("-a"): colour = colour.lerp(Color(0.12, 0.13, 0.15), 0.62)
		elif kind.ends_with("-b"): colour = colour.lerp(Color(0.22, 0.15, 0.10), 0.62)
		var skin := _material(colour)
		if kind == "charger_light":      # the soft light of a robot recharge station
			skin.emission_enabled = true
			skin.emission = Color(0.45, 0.85, 1.0)
			skin.emission_energy_multiplier = 3.0
		instance.material_override = skin
		add_child(instance)


## Draws one box or takes it out of the picture. A box that is out has no size.
func set_box_drawn(index: int, drawn: bool) -> void:
	var multimesh: MultiMesh = _box_mesh[index]
	if multimesh == null: return
	var b: Array = data.boxes[index]
	var size := Vector3(b[3], b[4], b[5]) if drawn else Vector3.ZERO
	if drawn: _boxes_out.erase(index)
	else: _boxes_out[index] = true
	multimesh.set_instance_transform(_box_slot[index], Transform3D(Basis(Vector3.UP, deg_to_rad(float(b[6]))) * Basis.from_scale(size), Vector3(b[0], float(b[1]) + float(b[4]) * 0.5, b[2])))


## (Kept here, not read back from the MultiMesh: a headless run stores no instance data.)
func is_box_drawn(index: int) -> bool:
	return _box_mesh[index] != null and not _boxes_out.has(index)


## Makes one box solid or not.
func set_box_solid(index: int, solid: bool) -> void:
	if _box_shape[index] != null: _box_shape[index].disabled = not solid


func is_box_solid(index: int) -> bool:
	return _box_shape[index] != null and not _box_shape[index].disabled


func _build_shapes() -> void:
	var glass := _material(Color(0.62, 0.74, 0.78), 0.15)
	glass.metallic = 0.3
	for shape: Dictionary in data.shapes:
		var instance := MeshInstance3D.new()
		var at := Vector3(shape.x, float(shape.y), shape.z)
		var height: float = shape.height
		var size: float = shape.size
		match str(shape.shape):
			"pyramid":
				var mesh := CylinderMesh.new()
				mesh.top_radius = 0.0
				mesh.bottom_radius = size * 0.7071
				mesh.height = height
				mesh.radial_segments = 4
				instance.mesh = mesh
				instance.rotation.y = PI * 0.25
				instance.position = at + Vector3.UP * height * 0.5
			"dome":
				var mesh := SphereMesh.new()
				mesh.radius = size * 0.5
				mesh.height = height
				mesh.is_hemisphere = true
				instance.mesh = mesh
				instance.position = at
			_:
				var mesh := CylinderMesh.new()
				mesh.top_radius = size * 0.5
				mesh.bottom_radius = size * 0.5
				mesh.height = height
				mesh.radial_segments = 20
				instance.mesh = mesh
				instance.position = at + Vector3.UP * height * 0.5
		instance.material_override = glass if str(shape.kind) == "glass" else _material(KIND_COLOURS.get(str(shape.kind), Color(0.66, 0.64, 0.58)))
		add_child(instance)
		# Something solid to walk into: a box as wide as the shape.
		var body := StaticBody3D.new()
		body.position = at + Vector3.UP * height * 0.5
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(size * 0.8, height, size * 0.8)
		collision.shape = box
		body.add_child(collision)
		add_child(body)


## A fixed wobble, so the one mesh every tree shares is not symmetrical. Deterministic, because
## 9,776 instances share it: the variety between trees comes from their own turn, scale and
## squash, and this only has to stop each single tree from being a solid of revolution.
static func _tree_wobble(a: int, b: int) -> float:
	var n: float = sin(float(a) * 12.9898 + float(b) * 78.233) * 43758.5453
	return (n - floor(n)) - 0.5


## The crown. It was a sphere — 8 segments by 5 rings, 2.5 m across and 6.4 m tall, which is a
## balloon on a stick and reads as one from any angle. Same ring and segment counts, so the same
## 80 triangles for 9,776 instances, but the profile is pushed about: each ring takes its own
## radius, every vertex is nudged in and out, and the whole thing is flattened to 4.2 m because
## a street tree is broader than it is tall. The outline is what tells you it is not a ball, and
## the outline costs nothing. (Street trees, agreed split with Codex, 2026-11-16.)
static func _tree_crown_mesh() -> ArrayMesh:
	var radial := 8
	var rings := 5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var point := func(ring: int, seg: int) -> Vector3:
		var phi: float = PI * float(ring) / float(rings)
		var theta: float = TAU * float(seg % radial) / float(radial)
		# Each ring its own width, so the mass is uneven up the tree rather than tapering evenly.
		var belly: float = 1.0 + 0.18 * _tree_wobble(ring, 11)
		var out: float = sin(phi) * 2.5 * belly * (1.0 + 0.16 * _tree_wobble(ring, seg % radial))
		var up: float = cos(phi) * 2.1
		# The lower edge droops, as foliage does under its own weight.
		if phi > PI * 0.55: up -= 0.35 * sin(phi)
		return Vector3(cos(theta) * out, up, sin(theta) * out)
	for ring: int in rings:
		for seg: int in radial:
			var a: Vector3 = point.call(ring, seg)
			var b: Vector3 = point.call(ring + 1, seg)
			var c: Vector3 = point.call(ring + 1, seg + 1)
			var d: Vector3 = point.call(ring, seg + 1)
			for v: Vector3 in [a, b, c]: tool.add_vertex(v)
			for v: Vector3 in [a, c, d]: tool.add_vertex(v)
	tool.generate_normals()
	return tool.commit()


## The trunk: five sided, tapered, with a flare where it meets the ground, and no cap on top
## because the crown sits over it. 30 triangles against the six-sided cylinder's 36.
##
## The two triangles of each band are wound `a, c, b` and `a, d, c`, which is the opposite hand
## from the crown's. Written the crown's way first, every one of the thirty faces and all ninety
## normals pointed **inward** and the trunk was inside out — invisible in a 1600x900 street shot,
## obvious to a mesh check. (Codex, 2026-11-16, which also said not to reach for double-sided
## culling to hide it: the winding was wrong, not the convention.)
static func _tree_trunk_mesh() -> ArrayMesh:
	var sides := 5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var rung: Array[float] = [-1.6, -1.1, 0.4, 1.6]          # metres about the trunk's middle
	var wide: Array[float] = [0.38, 0.26, 0.20, 0.15]        # the flare, then a steady taper
	var point := func(level: int, seg: int) -> Vector3:
		var theta: float = TAU * float(seg % sides) / float(sides)
		var out: float = wide[level] * (1.0 + 0.10 * _tree_wobble(level, seg % sides))
		return Vector3(cos(theta) * out, rung[level], sin(theta) * out)
	for level: int in rung.size() - 1:
		for seg: int in sides:
			var a: Vector3 = point.call(level, seg)
			var b: Vector3 = point.call(level + 1, seg)
			var c: Vector3 = point.call(level + 1, seg + 1)
			var d: Vector3 = point.call(level, seg + 1)
			for v: Vector3 in [a, c, b]: tool.add_vertex(v)
			for v: Vector3 in [a, d, c]: tool.add_vertex(v)
	tool.generate_normals()
	return tool.commit()


func _build_trees() -> void:
	var list: Array = data.trees
	if list.is_empty(): return
	var trunk_mesh := _tree_trunk_mesh()
	var crown_mesh := _tree_crown_mesh()
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = trunk_mesh
	trunks.instance_count = list.size()
	var crowns := MultiMesh.new()
	crowns.transform_format = MultiMesh.TRANSFORM_3D
	crowns.use_colors = true
	crowns.mesh = crown_mesh
	crowns.instance_count = list.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113
	for i: int in list.size():
		var tree: Array = list[i]
		var scale: float = tree[2]
		var at := on_ground(float(tree[0]), float(tree[1]), -0.15)
		var turn := Basis(Vector3.UP, rng.randf() * TAU)
		trunks.set_instance_transform(i, Transform3D(turn * Basis.from_scale(Vector3(scale, scale, scale)), at + Vector3.UP * 1.6 * scale))
		var squash := Vector3(scale * rng.randf_range(0.85, 1.2), scale * rng.randf_range(0.85, 1.25), scale * rng.randf_range(0.85, 1.2))
		# The crown is 4.2 m tall now rather than 6.4, so it sits lower to keep its underside
		# overlapping the trunk's top by about the same amount as before.
		crowns.set_instance_transform(i, Transform3D(turn * Basis.from_scale(squash), at + Vector3.UP * (3.0 * scale + 1.5 * squash.y)))
		# Every crown was one muted olive within 0.035 of its neighbour, which at nine thousand
		# instances reads as a plantation of one clone. A real run of trees varies in how deep
		# the green is and in how warm it is — a sycamore beside a zelkova beside something
		# half in shade — so both move here, independently: how light the whole crown is, and
		# how far it leans to yellow or to blue-green. The spread is wide enough to break the
		# clone and narrow enough that none of them stops looking like a tree.
		# One draw from the stream, as the single `tone` draw was, and the second value from a
		# hash of the tree's own index. Two draws would advance the stream twice and every tree
		# after the first would get a different turn and squash than it had — a silent re-roll
		# of the whole map's poses, smuggled in by a colour change. (Codex, 2026-11-16.)
		var light := rng.randf_range(0.78, 1.28)
		var warm := lerpf(-0.035, 0.055, _tree_wobble(i, 7) + 0.5)
		crowns.set_instance_color(i, Color((0.27 + warm) * light, 0.33 * light, (0.20 - warm * 0.6) * light))
	var trunk_instance := MultiMeshInstance3D.new()
	trunk_instance.name = "TreeTrunks"
	trunk_instance.multimesh = trunks
	trunk_instance.material_override = _material(Color(0.25, 0.20, 0.16))
	add_child(trunk_instance)
	var crown_material := _material(Color.WHITE, 1.0)
	crown_material.vertex_color_use_as_albedo = true
	var crown_instance := MultiMeshInstance3D.new()
	crown_instance.name = "TreeCrowns"
	crown_instance.multimesh = crowns
	crown_instance.material_override = crown_material
	add_child(crown_instance)


## The mountains are the wall of the map: they rise outside the west and north-west edges.
func _build_mountains() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.0021
	noise.fractal_octaves = 4
	var cell := 60.0
	var x0 := frame.position.x - 1500.0
	var x1 := frame.end.x + 900.0
	var z0 := frame.position.y - 1300.0
	var z1 := frame.end.y + 700.0
	var columns := int((x1 - x0) / cell)
	var rows := int((z1 - z0) / cell)
	var tops := PackedFloat32Array()
	tops.resize((columns + 1) * (rows + 1))
	for j: int in rows + 1:
		for i: int in columns + 1:
			var x := x0 + i * cell
			var z := z0 + j * cell
			var out_west := maxf(frame.position.x - x, 0.0)
			var out_north := maxf(frame.position.y - z, 0.0)
			var out_east := maxf(x - frame.end.x, 0.0)
			var out_south := maxf(z - frame.end.y, 0.0)
			# High in the west and north-west, low hills north of the airport, flat towards the sea.
			var west_share := clampf(1.0 - (x - frame.position.x) / 900.0, 0.0, 1.0)
			var tall := smoothstep(0.0, 620.0, out_west) * 430.0
			tall = maxf(tall, smoothstep(0.0, 560.0, out_north) * lerpf(90.0, 400.0, west_share))
			tall = maxf(tall, smoothstep(0.0, 500.0, out_south) * 200.0 * clampf(1.0 - (x - frame.position.x) / 700.0, 0.0, 1.0))
			tall = maxf(tall, smoothstep(0.0, 700.0, out_east) * 60.0 * clampf(1.0 - (z + 200.0) / 500.0, 0.0, 1.0))
			# The land outside carries on from the height of the map's own edge, so the
			# valley slope and the dam's hills run straight into the mountains.
			var edge := ground_height(clampf(x, frame.position.x, frame.end.x), clampf(z, frame.position.y, frame.end.y))
			var outside := out_west + out_north + out_east + out_south > 0.0
			tops[j * (columns + 1) + i] = (edge + tall * (0.62 + 0.55 * (noise.get_noise_2d(x, z) * 0.5 + 0.5))) if outside else -1.0
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in rows:
		for i: int in columns:
			var a := tops[j * (columns + 1) + i]
			var b := tops[j * (columns + 1) + i + 1]
			var c := tops[(j + 1) * (columns + 1) + i]
			var d := tops[(j + 1) * (columns + 1) + i + 1]
			# Skip the cells inside the map, and the open sea beyond the bay.
			if a < 0.0 or b < 0.0 or c < 0.0 or d < 0.0: continue
			if a <= 0.2 and b <= 0.2 and c <= 0.2 and d <= 0.2: continue
			var pa := Vector3(x0 + i * cell, a, z0 + j * cell)
			var pb := Vector3(x0 + (i + 1) * cell, b, z0 + j * cell)
			var pc := Vector3(x0 + i * cell, c, z0 + (j + 1) * cell)
			var pd := Vector3(x0 + (i + 1) * cell, d, z0 + (j + 1) * cell)
			for corner: Vector3 in [pa, pb, pc, pb, pd, pc]:
				surface.add_vertex(corner)
	surface.generate_normals()
	var mountains := MeshInstance3D.new()
	mountains.name = "Mountains"
	mountains.mesh = surface.commit()
	mountains.material_override = _material(Color(0.33, 0.36, 0.28), 1.0)
	add_child(mountains)


func _build_markers() -> void:
	for station: Dictionary in data.get("stations", plan.stations):
		var at := on_ground(float(station.x), float(station.z))
		_marker_box(at + Vector3.UP * 0.3, Vector3(44, 0.6, 5), Color(0.82, 0.82, 0.80))
		_marker_box(at + Vector3(0, 4.0, 3.2), Vector3(0.3, 8.0, 0.3), Color(0.9, 0.9, 0.9))
		_label(at + Vector3.UP * 9.5, "%s  %s" % [station.id, station.serves], Color(1, 1, 1))
		viewpoints.append({"name": "Station %s: %s" % [station.id, station.serves], "at": at + Vector3(0, 0.4, 4.5)})
	for drop: Dictionary in plan.drops:
		var at := on_ground(float(drop.x), float(drop.z))
		_marker_box(at + Vector3.UP * 9.0, Vector3(0.5, 18.0, 0.5), Color(1, 1, 1))
		_label(at + Vector3.UP * 20.0, "%s  drop-off: %s" % [drop.id, drop.area], Color(1, 1, 1))
		viewpoints.append({"name": "Drop-off %s: %s" % [drop.id, drop.area], "at": at + Vector3(2.5, 0.4, 0)})
	for post: Dictionary in data.posts:
		var at := on_ground(float(post.x), float(post.z))
		_marker_box(at + Vector3.UP * 5.0, Vector3(0.5, 10.0, 0.5), Color(0.78, 0.22, 0.2))
		_label(at + Vector3.UP * 11.5, "bot post %s" % post.between, Color(1.0, 0.62, 0.58))
	for mark: Dictionary in data.get("landmarks", plan.landmarks):
		var lift: float = float(mark.get("height", 6.0)) + 8.0
		_label(on_ground(float(mark.x), float(mark.z), lift), str(mark.name), Color(0.96, 0.92, 0.78))
		viewpoints.append({"name": str(mark.name), "at": on_ground(float(mark.x) + 60.0, float(mark.z) + 80.0, 0.4), "look": on_ground(float(mark.x), float(mark.z), lift * 0.4)})
	# What a player meets between fights: scav coves and their patrols, houses a scav may
	# live in, buildings a robot may lie dormant in, streets a robot work site may close.
	var meet: Dictionary = data.get("encounters", {})
	var rust := Color(0.91, 0.47, 0.28)
	var steel := Color(0.43, 0.74, 0.92)
	for cove: Dictionary in meet.get("coves", []):
		var at := on_ground(float(cove.x), float(cove.z))
		_marker_box(at + Vector3.UP * 45.0, Vector3(1.2, 90.0, 1.2), rust)
		_label(at + Vector3.UP * 94.0, "SCAV COVE: %s (crew of %d)" % [cove.name, int(cove.crew)], Color(1.0, 0.74, 0.60), 0.0006)
		viewpoints.append({"name": "Scav cove: %s" % cove.name, "at": on_ground(float(cove.x) + float(cove.radius) + 30.0, float(cove.z) + 24.0, 0.4), "look": at + Vector3.UP * 5.0})
		for step: Array in cove.patrol:
			_marker_box(on_ground(float(step[0]), float(step[1]), 1.1), Vector3(0.5, 2.2, 0.5), rust)
		for post: Array in cove.lookouts:
			_marker_box(on_ground(float(post[0]), float(post[1]), 40.0), Vector3(2.0, 2.0, 2.0), Color(1, 1, 1))
	for home: Array in meet.get("scav_homes", []):
		_marker_box(on_ground(float(home[0]), float(home[1]), 14.0), Vector3(0.7, 5.0, 0.7), rust)
	for nest: Array in meet.get("robot_nests", []):
		_marker_box(on_ground(float(nest[0]), float(nest[1]), 34.0), Vector3(2.4, 2.4, 2.4), steel)
	for station: Array in meet.get("charging_stations", []):
		var at := on_ground(float(station[0]), float(station[1]))
		_label(at + Vector3.UP * 8.0, "robot recharge station: %d bays, %d robots\n%s" % [int(station[2]), int(station[3]), str(station[4]) if station.size() > 4 else ""], Color(0.70, 0.90, 1.0))
		viewpoints.append({"name": "Robot recharge station", "at": at + Vector3(7.0, 0.4, 7.0), "look": at + Vector3.UP * 1.4})
	for site: Array in meet.get("work_sites", []):
		_marker_box(on_ground(float(site[0]), float(site[1]), 1.4), Vector3(4.5, 2.8, 4.5), steel)
	# The named squares and parks are places to jump to as well.
	for space: Dictionary in data.get("spaces", []):
		if not space.has("name"): continue
		_label(on_ground(float(space.x), float(space.z), 9.0), str(space.name), Color(0.86, 0.94, 0.82))
		viewpoints.append({"name": str(space.name), "at": on_ground(float(space.x) - float(space.w) * 0.5 - 4.0, float(space.z) + float(space.d) * 0.5 + 4.0, 0.4), "look": on_ground(float(space.x), float(space.z), 1.5)})
	for district: Dictionary in plan.districts:
		var rect: Array = district.rects[0]
		_label(on_ground((float(rect[0]) + float(rect[2])) * 0.5, (float(rect[1]) + float(rect[3])) * 0.5, 70.0), str(district.name).to_upper(), Color(1, 1, 1), 0.00075)


func _marker_box(at: Vector3, size: Vector3, colour: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material := _material(colour)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _label(at: Vector3, text: String, colour: Color, pixel := 0.00042) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = pixel
	label.font_size = 32
	label.outline_size = 10
	label.modulate = colour
	label.no_depth_test = true
	add_child(label)
	labels.append(label)


func _spawn_player() -> void:
	player = Player.new()
	player.name = "BlockoutPlayer"
	player.extraction_mode = false
	player.position = on_ground(0.0, -424.0, 0.4)
	var turn := PI  # look south, down the north avenue to the park
	# "-- --spawn=x,z,turn" starts somewhere else (turn in degrees: 0 looks north, -90 east).
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--spawn="): continue
		var parts := arg.trim_prefix("--spawn=").split(",")
		if parts.size() >= 2: player.position = on_ground(float(parts[0]), float(parts[1]), 0.4)
		if parts.size() >= 3: turn = deg_to_rad(float(parts[2]))
	add_child(player)
	player.rotation.y = turn
	var camera: Camera3D = player.get("camera")
	if camera != null: camera.far = 20000.0
	if world != null:
		world.set_viewer(camera if camera != null else player, player)
		for station: Node3D in world.stations:
			for robot: Node in station.robots:
				robot.struck.connect(func(_robot: Node3D, victim: Node3D, damage: float) -> void:
					if victim == player: _say("A robot strikes you: %d damage" % int(damage)))
				robot.downed.connect(func(_robot: Node3D) -> void: _say("The robot is down. Hold E on it to strip it."))
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(18, 14)
	_hud.add_theme_font_size_override("font_size", 17)
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud)


func district_at(point: Vector3) -> String:
	for district: Dictionary in plan.districts:
		for rect: Array in district.rects:
			if point.x >= float(rect[0]) and point.x < float(rect[2]) and point.z >= float(rect[1]) and point.z < float(rect[3]):
				return str(district.name)
	return "outside the map"


func _process(delta: float) -> void:
	if _hud == null or not is_instance_valid(player): return
	var at := player.global_position
	var nearest := ""
	var best := INF
	for station: Dictionary in data.get("stations", plan.stations):
		var gap := Vector2(at.x - float(station.x), at.z - float(station.z)).length()
		if gap < best: best = gap; nearest = str(station.id)
	var text := "MAP 1 BLOCKOUT  ·  layout test, not art\n%s   x %.0f  z %.0f\nNearest station %s: %.0f m (about %.1f min on foot)\nF3 fly · Shift fast · [ ] jump to places · L labels · Esc mouse" % [district_at(at), at.x, at.z, nearest, best, best * 1.3 / 3.85 / 60.0]
	if world != null:
		# Doors and windows of the real houses, used the way the test yard uses them.
		_message_time = maxf(_message_time - delta, 0.0)
		var prompt := ""
		var target := _nearest_target()
		if target != null and not player.fly_mode:
			prompt = str(target.interaction_prompt(player)) if target.has_method("interaction_prompt") else ""
			if Input.is_key_pressed(KEY_E) and target.has_method("hold_interact"):
				var done: float = target.hold_interact(player, delta)
				if done > 0.0 and done < 1.0: prompt += "   %d%%" % int(done * 100.0)
		text += "\nE use / hold · left mouse shoot · C crowbar (%s)   ·   houses with insides %d, seen from outside %d\n%s\n%s" % [
			"carried" if bool(player.get_meta("has_crowbar", false)) else "not carried", world.count(World.Level.FULL), world.count(World.Level.LOOK), prompt, _message if _message_time > 0.0 else ""]
	_hud.text = text


func _say(text: String) -> void:
	_message = text
	_message_time = 4.0


## The door, window or downed robot the player could use from where he stands.
func _nearest_target() -> Node3D:
	var best: Node3D = null
	var gap := INF
	for target: Node in get_tree().get_nodes_in_group("building_access_targets"):
		if not target.has_method("interaction_distance"): continue
		var d: float = target.interaction_distance(player)
		if d < gap:
			gap = d
			best = target
	return best


## One shot along the view, the way the test yard fires one: a ray, and the hit thing is told.
func _shoot() -> void:
	var camera: Camera3D = player.get("camera")
	if camera == null: return
	var from := camera.global_position
	var direction := -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * 120.0)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	get_tree().call_group("gunfire_listeners", "on_gunfire", from)
	if hit.is_empty(): return
	var what: Object = hit.collider
	for _step: int in 3:      # the thing hit, or what it belongs to
		if what == null: return
		if what.has_method("receive_bullet_hit"):
			what.receive_bullet_hit(30.0, player, hit.position, direction)
			return
		if what.has_method("bullet_hit"):
			what.bullet_hit(30.0, player, hit.position, direction)
			return
		what = (what as Node).get_parent() if what is Node else null


func _unhandled_input(event: InputEvent) -> void:
	if world != null and is_instance_valid(player) and not player.fly_mode and event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_shoot()
		return
	if not (event is InputEventKey and event.pressed and not event.echo): return
	match (event as InputEventKey).keycode:
		KEY_L:
			for label: Label3D in labels: label.visible = not label.visible
		KEY_BRACKETRIGHT: _jump(1)
		KEY_BRACKETLEFT: _jump(-1)
		KEY_E:
			if world != null and is_instance_valid(player) and not player.fly_mode:
				var target := _nearest_target()
				if target != null and target.has_method("interact"): target.interact(player)
		KEY_C:
			if world != null and is_instance_valid(player): player.set_meta("has_crowbar", not bool(player.get_meta("has_crowbar", false)))


func _jump(step: int) -> void:
	if viewpoints.is_empty() or not is_instance_valid(player): return
	_view_index = posmod(_view_index + step, viewpoints.size())
	var view: Dictionary = viewpoints[_view_index]
	player.global_position = view.at
	player.velocity = Vector3.ZERO
	if world != null: world.cut()
	if view.has("look"):
		var flat: Vector3 = (view.look as Vector3) - player.global_position
		player.rotation.y = atan2(-flat.x, -flat.z)
	print("MAP1_BLOCKOUT at ", view.name)
