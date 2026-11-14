extends StaticBody3D
## A robot recharge station (docs/GAME_DESIGN.md section 8): a white plinth with two to five
## upright bays and a tall marker post with a light on top. A robot stands in some bays.
##
## It warns before it bites. From HUM_DISTANCE it hums; from WARN_DISTANCE the bay lights
## turn from blue-white to amber and pulse slowly and the hum rises a step; at WAKE_DISTANCE,
## or when the station or a robot in it is shot, the robots in the bays wake and step out.
## Nothing says what any of it is for.
##
## Built from a short description, the same one the map plan gives each of its stations:
##   Station.build({"bays": 4, "robots": 2})
##   Station.from_map_entry([x, z, bays, robots, why])       # encounters.charging_stations
## Place it (position, rotation) and add it to the world. It finds players by itself (the
## group "shinrai_input_players"); a test or the yard hands it one with track().
##
## Its own axes: the bays stand in a row along x and face +z; y is up; the origin is the
## middle of the plinth, on the ground. Distances to a player are measured from the edge of
## the plinth, not from its middle, so a wide station is not easier to creep up on.

const Robot := preload("res://scripts/robots/robot.gd")
const RobotParts := preload("res://scripts/robots/robot_parts.gd")
const RobotMesh := preload("res://scripts/robots/robot_mesh.gd")

enum Lights { CALM, WARNING, AWAKE }

# ---- the owner's rules, with the numbers filled in as defaults ---------------------------
const MIN_BAYS := 2
const MAX_BAYS := 5
## From here in, a steady low hum.
const HUM_DISTANCE := 25.0
## From here in, the lights go amber and pulse, and the hum rises one step.
const WARN_DISTANCE := 12.0
## Here the robots in the bays wake.
const WAKE_DISTANCE := 6.0
## Hum levels, as numbers a test (and later a sound) can read.
const HUM_OFF := 0
const HUM_STEADY := 1
const HUM_RAISED := 2
## The bay lights.
const CALM_COLOUR := Color(0.72, 0.86, 1.0)
const WARN_COLOUR := Color(1.0, 0.62, 0.18)
## How bright they are when steady, and the two ends of the slow warning pulse.
const STEADY_ENERGY := 1.5
const PULSE_LOW := 0.8
const PULSE_HIGH := 2.3
## One full pulse, dim to bright to dim.
const PULSE_SECONDS := 2.4
## Changing from one look to the other takes this long: lights never snap.
const BLEND_SECONDS := 0.8
## A row of robots does not step out as one: each starts this long after the one before.
const WAKE_STAGGER := 0.3
## Nobody closes on a station faster than this (m/s). It sets how long a far station may
## sleep between looks at where the players are.
const FASTEST_APPROACH := 14.0
const LONGEST_SLEEP := 2.0

# ---- its size (metres) -------------------------------------------------------------------
const BAY_WIDTH := 1.1
const POST_BAY := 0.8
const PLINTH_DEPTH := 1.5
const PLINTH_HEIGHT := 0.14
const SPINE_HEIGHT := 2.45
const SPINE_FRONT := -0.46
const SPINE_THICKNESS := 0.2
const POST_HEIGHT := 4.8
const ROBOT_STANDS_AT := -0.05
const SHELL_WHITE := Color(0.93, 0.94, 0.95)
const PLINTH_GREY := Color(0.80, 0.81, 0.82)

signal hum_changed(station: Node3D, level: int)
signal robots_woke(station: Node3D, count: int)

var bays := 0
## One entry per bay: the robot that belongs to it, or null for an empty bay.
var bay_robots: Array = []
var robots: Array[CharacterBody3D] = []
var description: Dictionary = {}
var visuals := true
var width := 0.0

var hum_level := HUM_OFF
var light_state: int = Lights.CALM
var light_colour := CALM_COLOUR
var light_energy := STEADY_ENERGY
## How far the lights swing while they pulse, 0 when steady.
var light_pulse_depth := 0.0
## True while any of its robots is out of its bay and still standing.
var awake := false
var wakes := 0
## To the nearest player, from the plinth's edge. INF when there is nobody.
var nearest_distance := INF
var stats: Dictionary = {}

var _tracked: Array[Node3D] = []
var _sleep := 0.0
var _amber := 0.0
var _pulse := 0.0
var _pulse_clock := 0.0
var _navigation: Object
var _glow: StandardMaterial3D
var _lamp: OmniLight3D


## A station from a description: {"bays": n, "robots": m}. Optional: "seed" (which bays are
## occupied), "occupied" (the bay numbers, instead of the seed), "loadouts" (one list of
## parts per robot; a station robot gives a power cell).
static func build(what: Dictionary, with_visuals: bool = true) -> StaticBody3D:
	var started := Time.get_ticks_usec()
	var station: StaticBody3D = new()
	station.visuals = with_visuals
	station._build(what)
	station.stats["build_usec"] = Time.get_ticks_usec() - started
	return station


## A station from one row of encounters.charging_stations in the map's blockout file:
## [x, z, bays, robots, why]. It is placed at (x, 0, z); the caller turns it to face its street.
static func from_map_entry(entry: Array, with_visuals: bool = true) -> StaticBody3D:
	var station := build({"bays": int(entry[2]), "robots": int(entry[3]), "seed": hash([float(entry[0]), float(entry[1])]), "why": str(entry[4]) if entry.size() > 4 else ""}, with_visuals)
	station.position = Vector3(float(entry[0]), 0.0, float(entry[1]))
	return station


func track(body: Node3D) -> void:
	if body != null and not _tracked.has(body): _tracked.append(body)
	_sleep = 0.0


func untrack(body: Node3D) -> void:
	_tracked.erase(body)


## Gives its robots a way round obstacles: anything with get_path_world() or path().
func set_navigation(source: Object) -> void:
	_navigation = source
	for robot: CharacterBody3D in robots:
		if is_instance_valid(robot): robot.navigation_source = source


func bay_point(index: int) -> Vector3:
	return Vector3(-width * 0.5 + POST_BAY + (float(index) + 0.5) * BAY_WIDTH, PLINTH_HEIGHT, ROBOT_STANDS_AT)


## Robots standing dormant in their bays.
func dormant_count() -> int:
	var total := 0
	for robot: CharacterBody3D in robots:
		if is_instance_valid(robot) and robot.is_dormant(): total += 1
	return total


## How far `point` is from the edge of the plinth, along the ground.
func distance_to(point: Vector3) -> float:
	var local := to_local(point)
	var out := Vector2(maxf(absf(local.x) - width * 0.5, 0.0), maxf(absf(local.z) - PLINTH_DEPTH * 0.5, 0.0))
	return out.length()


## Wakes every robot standing in a bay. `who` is who they go for: the one who came too close
## or fired. Returns how many woke. An empty station wakes nothing.
func wake(who: Node = null) -> int:
	var prey: Node3D = who as Node3D if is_instance_valid(who) and who is Node3D else _nearest_player()
	var count := 0
	for robot: CharacterBody3D in robots:
		if not is_instance_valid(robot) or not robot.is_dormant(): continue
		if robot.wake(prey, float(count) * WAKE_STAGGER): count += 1
	if count > 0:
		wakes += 1
		_sleep = 0.0
		robots_woke.emit(self, count)
	return count


## A bullet in the station itself wakes what is in it.
func receive_bullet_hit(damage: float, source: Node, _at: Vector3, _direction: Vector3) -> bool:
	if damage <= 0.0: return false
	wake(source)
	return true


## A robot tells its station when it changes what it is doing.
func robot_changed(_robot: Node3D) -> void:
	_sleep = 0.0


# ---- the tick ----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	# A station with nobody near does nothing but count down to its next look.
	_sleep -= delta
	if _sleep > 0.0: return
	nearest_distance = _nearest_distance()
	awake = false
	for robot: CharacterBody3D in robots:
		if is_instance_valid(robot) and robot.is_out(): awake = true
	if nearest_distance <= WAKE_DISTANCE and dormant_count() > 0: wake(_nearest_player())
	var level := HUM_OFF
	if awake or nearest_distance <= WARN_DISTANCE: level = HUM_RAISED
	elif nearest_distance <= HUM_DISTANCE: level = HUM_STEADY
	if level != hum_level:
		hum_level = level
		# STATION HUM: the sound hook (scripts/robots/robot_parts.gd, ROBOT_SOUND_HOOK).
		RobotParts.sound(&"station_hum", global_position, level)
		hum_changed.emit(self, level)
	light_state = Lights.AWAKE if awake else (Lights.WARNING if nearest_distance <= WARN_DISTANCE else Lights.CALM)
	var settled := _light(delta)
	if awake or light_state != Lights.CALM or not settled: return
	# Calm and steady: sleep until a player could first reach the next ring.
	var gap := INF
	for ring: float in [HUM_DISTANCE, WARN_DISTANCE, WAKE_DISTANCE]: gap = minf(gap, absf(nearest_distance - ring))
	_sleep = clampf(gap / FASTEST_APPROACH - 0.05, 0.0, LONGEST_SLEEP)


## Moves the lights towards what they should show. Returns true once nothing is changing.
func _light(delta: float) -> bool:
	var want_amber := 0.0 if light_state == Lights.CALM else 1.0
	var want_pulse := 1.0 if light_state == Lights.WARNING else 0.0
	_amber = move_toward(_amber, want_amber, delta / BLEND_SECONDS)
	_pulse = move_toward(_pulse, want_pulse, delta / BLEND_SECONDS)
	if _pulse > 0.0: _pulse_clock += delta
	else: _pulse_clock = 0.0
	var wave := 0.5 - 0.5 * cos(TAU * _pulse_clock / PULSE_SECONDS)
	light_colour = CALM_COLOUR.lerp(WARN_COLOUR, _amber)
	light_energy = lerpf(STEADY_ENERGY, lerpf(PULSE_LOW, PULSE_HIGH, wave), _pulse)
	light_pulse_depth = (PULSE_HIGH - PULSE_LOW) * _pulse
	if _glow != null:
		_glow.emission = light_colour
		_glow.emission_energy_multiplier = light_energy
		_glow.albedo_color = Color(0.86, 0.88, 0.9).lerp(light_colour, 0.35)
	if _lamp != null:
		_lamp.light_color = light_colour
		_lamp.light_energy = light_energy * 0.55
	return is_equal_approx(_amber, want_amber) and is_equal_approx(_pulse, want_pulse) and _pulse <= 0.0


func _players() -> Array[Node3D]:
	var output: Array[Node3D] = []
	for index: int in range(_tracked.size() - 1, -1, -1):
		if is_instance_valid(_tracked[index]) and _tracked[index].is_inside_tree(): output.append(_tracked[index])
		elif not is_instance_valid(_tracked[index]): _tracked.remove_at(index)
	for body: Node in get_tree().get_nodes_in_group("shinrai_input_players"):
		if body is Node3D and not output.has(body): output.append(body as Node3D)
	return output


func _nearest_distance() -> float:
	var best := INF
	for body: Node3D in _players(): best = minf(best, distance_to(body.global_position))
	return best


func _nearest_player() -> Node3D:
	var best: Node3D = null
	var gap := INF
	for body: Node3D in _players():
		var d := distance_to(body.global_position)
		if d < gap:
			gap = d
			best = body
	return best


# ---- building it -------------------------------------------------------------------------

func _build(what: Dictionary) -> void:
	description = what.duplicate(true)
	name = str(what.get("id", "RechargeStation"))
	bays = clampi(int(what.get("bays", MIN_BAYS)), MIN_BAYS, MAX_BAYS)
	var robot_count := clampi(int(what.get("robots", 0)), 0, bays)
	width = POST_BAY + float(bays) * BAY_WIDTH
	collision_layer = 1
	collision_mask = 0
	var block_x := POST_BAY * 0.5 # the middle of the row of bays
	var block_width := float(bays) * BAY_WIDTH
	_solid(Vector3(0.0, PLINTH_HEIGHT * 0.5, 0.0), Vector3(width, PLINTH_HEIGHT, PLINTH_DEPTH))
	_solid(Vector3(block_x, PLINTH_HEIGHT + SPINE_HEIGHT * 0.5, SPINE_FRONT - SPINE_THICKNESS * 0.5), Vector3(block_width, SPINE_HEIGHT, SPINE_THICKNESS))
	_solid(Vector3(-width * 0.5 + POST_BAY * 0.5, POST_HEIGHT * 0.5, 0.0), Vector3(0.14, POST_HEIGHT, 0.14))
	# Which bays have a robot in them.
	var order: Array = range(bays)
	if what.has("occupied"):
		order = (what.occupied as Array).duplicate()
	else:
		var dice := RandomNumberGenerator.new()
		dice.seed = int(what.get("seed", bays * 31 + robot_count))
		for index: int in range(bays - 1, 0, -1):
			var other := dice.randi_range(0, index)
			var keep: int = order[index]
			order[index] = order[other]
			order[other] = keep
	var chosen: Array = order.slice(0, robot_count)
	chosen.sort()
	bay_robots.resize(bays)
	var loadouts: Array = what.get("loadouts", [])
	for bay: int in chosen:
		var robot: CharacterBody3D = Robot.new()
		robot.name = "Robot%d" % (robots.size() + 1)
		robot.station = self
		robot.bay = bay
		robot.visuals = visuals
		robot.home_local = bay_point(bay)
		robot.out_local = Vector3(robot.home_local.x, 0.0, robot.home_local.z + Robot.STEP_OUT_DISTANCE)
		robot.home_yaw_local = PI # it faces out of the bay: the station's +z
		var loadout: Array = loadouts[robots.size()] if robots.size() < loadouts.size() else RobotParts.STATION_ROBOT
		for part: Variant in loadout: robot.parts.append(StringName(str(part)))
		robot.position = robot.home_local
		robot.rotation.y = PI
		add_child(robot)
		if visuals: robot.build_rig()
		robots.append(robot)
		bay_robots[bay] = robot
	var triangles := 0
	var meshes := 0
	if visuals:
		triangles = _build_look(block_x, block_width)
		meshes = 2
	for robot: CharacterBody3D in robots:
		triangles += robot.triangles
		meshes += robot.mesh_count
	_light(0.0)
	var counted := _count(self)
	stats = {"bays": bays, "robots": robots.size(), "nodes": counted.nodes, "bodies": 1 + robots.size(), "collision_shapes": counted.shapes, "meshes": meshes, "lights": 1 if _lamp != null else 0, "triangles": triangles}


func _solid(centre: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = centre
	add_child(collision)


func _count(node: Node) -> Dictionary:
	var total := {"nodes": 1, "shapes": 1 if node is CollisionShape3D else 0}
	for child: Node in node.get_children():
		var inner := _count(child)
		total.nodes += int(inner.nodes)
		total.shapes += int(inner.shapes)
	return total


## The look, first pass, made in code: one mesh for everything white, one for everything
## that glows. Returns the triangles.
func _build_look(block_x: float, block_width: float) -> int:
	var shell := RobotMesh.new()
	var glow := RobotMesh.new()
	var left := block_x - block_width * 0.5
	var top := PLINTH_HEIGHT + SPINE_HEIGHT
	shell.box(Vector3(0.0, PLINTH_HEIGHT * 0.5, 0.0), Vector3(width, PLINTH_HEIGHT, PLINTH_DEPTH), PLINTH_GREY)
	shell.box(Vector3(block_x, PLINTH_HEIGHT + SPINE_HEIGHT * 0.5, SPINE_FRONT - SPINE_THICKNESS * 0.5), Vector3(block_width, SPINE_HEIGHT, SPINE_THICKNESS), SHELL_WHITE)
	# The hood over the row, and the fins that part one bay from the next.
	shell.box(Vector3(block_x, top - 0.06, -0.2), Vector3(block_width + 0.06, 0.12, 0.92), SHELL_WHITE)
	for index: int in range(bays + 1):
		shell.box(Vector3(left + float(index) * BAY_WIDTH, PLINTH_HEIGHT + (SPINE_HEIGHT - 0.12) * 0.5, -0.18), Vector3(0.06, SPINE_HEIGHT - 0.12, 0.56), SHELL_WHITE)
	for index: int in range(bays):
		var x := bay_point(index).x
		# The tall panel a robot stands against, and the lamp in the hood above it.
		glow.box(Vector3(x, PLINTH_HEIGHT + 1.16, SPINE_FRONT + 0.011), Vector3(0.62, 1.72, 0.022), Color.WHITE)
		glow.box(Vector3(x, top - 0.126, 0.0), Vector3(0.62, 0.012, 0.34), Color.WHITE)
	# The marker post, with its light on top under a small cap.
	var post_x := -width * 0.5 + POST_BAY * 0.5
	shell.box(Vector3(post_x, POST_HEIGHT * 0.5, 0.0), Vector3(0.14, POST_HEIGHT, 0.14), SHELL_WHITE)
	glow.cylinder(Vector3(post_x, POST_HEIGHT + 0.16, 0.0), 0.11, 0.11, 0.32, Color.WHITE)
	shell.cylinder(Vector3(post_x, POST_HEIGHT + 0.34, 0.0), 0.15, 0.13, 0.04, SHELL_WHITE)
	var body := MeshInstance3D.new()
	body.name = "Shell"
	body.mesh = shell.commit()
	add_child(body)
	_glow = StandardMaterial3D.new()
	_glow.roughness = 0.3
	_glow.emission_enabled = true
	var lights := MeshInstance3D.new()
	lights.name = "Lights"
	lights.mesh = glow.commit(_glow)
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lights)
	# One soft lamp so the glow reaches the robots and the pavement. It fades out with
	# distance instead of switching off.
	_lamp = OmniLight3D.new()
	_lamp.name = "Lamp"
	_lamp.position = Vector3(block_x, PLINTH_HEIGHT + 1.7, 0.75)
	_lamp.omni_range = 5.5
	_lamp.shadow_enabled = false
	_lamp.distance_fade_enabled = true
	_lamp.distance_fade_begin = 45.0
	_lamp.distance_fade_length = 15.0
	add_child(_lamp)
	return shell.triangle_count() + glow.triangle_count()
