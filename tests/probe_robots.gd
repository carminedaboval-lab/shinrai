extends SceneTree
## Proves the recharge station and robot rules in the test yard (headless, no park boot):
##   godot --headless --path . --fixed-fps 60 --script res://tests/probe_robots.gd
##   ... -- --only=approach,strip     runs just those scenarios
## Each scenario builds a fresh yard with a station in it, plays a scripted "player" at it and
## prints one ROBOT_PASS or ROBOT_FAIL line per rule, with the measured number. ROBOT_INFO
## lines are measurements with no pass mark. Ends with ROBOT_DONE passed=N failed=N.
## "m from the station" is measured from the edge of its plinth, the way the station does.

const YardWorld := preload("res://scripts/test_yard/yard_world.gd")
const YardRaid := preload("res://scripts/test_yard/yard_raid.gd")
const Squad := preload("res://scripts/scav_squad.gd")
const Target := preload("res://tests/ai_probe_target.gd")
const BirdManager := preload("res://scripts/wildlife/bird_manager.gd")
const KitDoor := preload("res://scripts/interior_kit/door.gd")
const KitNoise := preload("res://scripts/interior_kit/noise.gd")
const Station := preload("res://scripts/robots/station.gd")
const Robot := preload("res://scripts/robots/robot.gd")
const RobotParts := preload("res://scripts/robots/robot_parts.gd")
const YardRobots := preload("res://scripts/robots/yard_robots.gd")
const DT := 1.0 / 60.0
## The game's own player speeds (scripts/player.gd): walk, run, and backing away.
const PLAYER_WALK := 3.85
const PLAYER_RUN := 6.65
const PLAYER_BACK := 3.85 * 0.72
const WALK_SPAWN := Vector3(0.0, 0.0, 6.0) # where scripts/test_yard/yard_walk.gd starts
const MAP_FILE := "res://data/map1/generated/map1_blockout.json"
const ONE_ROBOT := {"id": "RechargeStation", "bays": 2, "robots": 1, "occupied": [0], "loadouts": [RobotParts.FIRST_ROBOT]}


## A raid whose scavs cannot see: only what they HEAR is being tested.
class BlindRaid extends "res://scripts/test_yard/yard_raid.gd":
	func insertion_grace() -> bool:
		return true


## Something that hears noises: counts the ones that reach it.
class Ear extends Node3D:
	var heard := 0
	func on_noise(point: Vector3, radius: float) -> void:
		if global_position.distance_to(point) <= radius: heard += 1


var yard: Node3D
var station: StaticBody3D
var body: CharacterBody3D
var raid: Node
var crew: Node3D
var manager: BirdManager
var only: PackedStringArray = []
var passed := 0
var failed := 0
var clock := 0.0
var drawn := false
var _label := ""
var _seen: Dictionary = {}
var _watch := {"jump": 0.0, "lost": 0, "hidden": 0, "ticks": 0}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=").split(",")
	_run.call_deferred()


func _run() -> void:
	var scenarios := {
		"approach": _approach, "wake": _wake, "back_off": _back_off, "shot": _shot,
		"empty": _empty, "strike_and_chase": _strike_and_chase, "shoot_down": _shoot_down,
		"strip": _strip, "map_station": _map_station, "drawn": _drawn, "cost": _cost,
	}
	for label: String in scenarios:
		if not only.is_empty() and not only.has(label): continue
		_label = label
		print("ROBOT_BEGIN ", label)
		await scenarios[label].call()
		await _end()
	_label = "all"
	if int(_watch.ticks) > 0:
		_check(int(_watch.lost) == 0 and int(_watch.hidden) == 0 and float(_watch.jump) <= 0.12, "nothing popped in or out: over %d ticks no robot left the world (%d), none was hidden (%d), and the largest move in one tick was %.3f m" % [int(_watch.ticks), int(_watch.lost), int(_watch.hidden), float(_watch.jump)])
	print("ROBOT_DONE passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)


# ---- world -------------------------------------------------------------------------------

## A fresh yard. With no `spec` it is the yard as the owner gets it (its own station); with
## one, that station stands in the same place instead. `far` is where the player waits.
func _begin(spec: Dictionary = {}, with_raid: bool = false, crew_anchor: Vector3 = Vector3.INF, bird_setup: Callable = Callable()) -> void:
	_seen.clear()
	yard = YardWorld.new()
	yard.visuals = drawn or DisplayServer.get_name() != "headless"
	yard.birds = false
	yard.robots = spec.is_empty()
	root.add_child(yard)
	yard.build()
	station = yard.get_node("RechargeStation") if spec.is_empty() else YardRobots.populate(yard, spec)
	manager = null
	if bird_setup.is_valid():
		manager = BirdManager.new()
		manager.name = "Wildlife"
		manager.rng.seed = 7
		yard.add_child(manager)
		bird_setup.call(manager)
	body = Target.new()
	body.name = "ProbePlayer"
	yard.add_child(body)
	body.global_position = Vector3(-40.0, 0.05, -40.0)
	station.track(body)
	if manager != null: manager.add_player(body)
	await physics_frame
	await physics_frame
	raid = null
	crew = null
	if with_raid:
		raid = BlindRaid.new()
		raid.name = "YardRaid"
		yard.add_child(raid)
		raid.setup(yard, body, YardWorld.HALF)
		if crew_anchor.is_finite():
			crew = Squad.new()
			crew.name = "ScavPatrolCrew"
			crew.raid = raid
			crew.spawn_anchor = crew_anchor
			yard.add_child(crew)
			var guard := 0
			while not crew.ready_for_use and guard < 600:
				await physics_frame
				guard += 1
			for actor: CharacterBody3D in crew.members: raid.navigation.exclude(actor)
	for i: int in 20: await physics_frame


func _end() -> void:
	if is_instance_valid(yard): yard.queue_free()
	yard = null
	station = null
	manager = null
	await process_frame
	await process_frame


func _step(seconds: float, until: Callable = Callable()) -> bool:
	var frames := int(round(seconds / DT))
	for i: int in frames:
		await physics_frame
		clock += DT
		_watch_robots()
		if until.is_valid() and until.call(): return true
	return false


## Every tick, for every robot: it must still be in the world and drawn, and it may never
## jump from one place to another.
func _watch_robots() -> void:
	if not is_instance_valid(station): return
	_watch.ticks = int(_watch.ticks) + 1
	for robot: CharacterBody3D in station.robots:
		if not is_instance_valid(robot) or not robot.is_inside_tree():
			_watch.lost = int(_watch.lost) + 1
			continue
		if not robot.is_visible_in_tree(): _watch.hidden = int(_watch.hidden) + 1
		if _seen.has(robot): _watch.jump = maxf(float(_watch.jump), robot.global_position.distance_to(_seen[robot]))
		_seen[robot] = robot.global_position


func _check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("%s %s: %s" % ["ROBOT_PASS" if ok else "ROBOT_FAIL", _label, text])


func _info(text: String) -> void:
	print("ROBOT_INFO %s: %s" % [_label, text])


## The point `metres` in front of the station's plinth, `along` metres along its row.
func _front(metres: float, along: float = 0.0) -> Vector3:
	return station.to_global(Vector3(along, 0.0, Station.PLINTH_DEPTH * 0.5 + metres))


func _gap() -> float:
	return station.distance_to(body.global_position)


## Stands the player `metres` in front of the station (put there, not walked).
func _place(metres: float) -> void:
	body.halt()
	var point := _front(metres)
	body.global_position = Vector3(point.x, 0.05, point.z)
	station.track(body) # a body that is PUT somewhere is looked at straight away
	await _step(0.2)


func _walk(metres: float, speed: float, until: Callable = Callable(), limit: float = 60.0) -> bool:
	body.walk_to(_front(metres), speed)
	var stopped: bool = await _step(limit, func() -> bool: return body.arrived() or (until.is_valid() and until.call()))
	body.halt()
	return stopped


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _in_state(wanted: int) -> int:
	var total := 0
	for robot: CharacterBody3D in station.robots:
		if robot.state == wanted: total += 1
	return total


func _state_name(robot: CharacterBody3D) -> String:
	return str(Robot.State.keys()[robot.state])


func _colour_gap(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _colour_text(colour: Color) -> String:
	return "(%.2f, %.2f, %.2f)" % [colour.r, colour.g, colour.b]


## A bullet, fired the way player.gd fires one: a ray, and receive_bullet_hit() on what it hits.
func _shoot(at: Vector3) -> Dictionary:
	var from := body.global_position + Vector3.UP * 1.5
	var direction := (at - from).normalized()
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * 120.0, 1 | 2 | 4 | 8, [body.get_rid()])
	var result := yard.get_world_3d().direct_space_state.intersect_ray(query)
	var counted := false
	if not result.is_empty() and result.collider.has_method("receive_bullet_hit"):
		counted = result.collider.receive_bullet_hit(30.0, body, result.position, direction)
	return {"collider": result.get("collider"), "counted": counted}


func _ear(at: Vector3) -> Ear:
	var ear := Ear.new()
	ear.add_to_group(KitNoise.LISTENER_GROUP)
	yard.add_child(ear)
	ear.global_position = at
	return ear


func _sounds() -> int:
	var total := KitNoise.sounds_total()
	for kind: StringName in RobotParts.sounds_wanted: total += int(RobotParts.sounds_wanted[kind])
	return total


# ---- the warnings ------------------------------------------------------------------------

func _approach() -> void:
	await _begin()
	var fresh: Node3D = YardWorld.new()
	var default_on: bool = fresh.robots
	fresh.free()
	var from_spawn := _flat(station.global_position, WALK_SPAWN)
	_check(default_on and station != null and from_spawn > 30.0, "a station is on by default in the yard: %d bays, %d robots, %.1f m from where the owner starts (rule: more than 30)" % [station.bays, station.robots.size(), from_spawn])
	await _place(30.0)
	await _step(1.0)
	_check(station.hum_level == Station.HUM_OFF and station.light_state == Station.Lights.CALM and station.light_pulse_depth == 0.0 and _colour_gap(station.light_colour, Station.CALM_COLOUR) < 0.001, "player %.1f m away: hum level %d, lights calm, colour %s (blue-white), steady at %.2f" % [_gap(), station.hum_level, _colour_text(station.light_colour), station.light_energy])
	# Walk in. Note the distance at which the hum starts.
	var m := {"hum_at": -1.0, "warn_at": -1.0, "hum_before": -1, "calm_at": -1.0, "off_at": -1.0}
	await _walk(13.0, 1.6, func() -> bool:
		if float(m.hum_at) < 0.0 and station.hum_level > 0: m.hum_at = _gap()
		return false)
	await _step(1.0)
	_check(float(m.hum_at) > Station.HUM_DISTANCE - 0.2 and float(m.hum_at) <= Station.HUM_DISTANCE, "walking in, the hum started at %.2f m (rule: %.0f)" % [float(m.hum_at), Station.HUM_DISTANCE])
	_check(station.hum_level == Station.HUM_STEADY and station.light_state == Station.Lights.CALM and station.light_pulse_depth == 0.0, "standing %.1f m away: hum level %d (above 0), lights still calm and steady" % [_gap(), station.hum_level])
	m.hum_before = station.hum_level
	await _walk(8.0, 1.6, func() -> bool:
		if float(m.warn_at) < 0.0 and station.light_state == Station.Lights.WARNING: m.warn_at = _gap()
		return false)
	_check(float(m.warn_at) > Station.WARN_DISTANCE - 0.2 and float(m.warn_at) <= Station.WARN_DISTANCE and station.hum_level > int(m.hum_before), "the warning started at %.2f m (rule: %.0f) and the hum rose from level %d to %d" % [float(m.warn_at), Station.WARN_DISTANCE, int(m.hum_before), station.hum_level])
	# Stand in the warning and read the lights for three pulses.
	await _step(1.5)
	var low := INF
	var high := -INF
	var peaks: Array[float] = []
	var before: float = station.light_energy
	var rising := false
	for tick: int in int(7.2 / DT):
		await _step(DT)
		var now: float = station.light_energy
		low = minf(low, now)
		high = maxf(high, now)
		if rising and now < before: peaks.append(clock)
		rising = now > before
		before = now
	var period := (peaks[-1] - peaks[0]) / float(peaks.size() - 1) if peaks.size() >= 2 else -1.0
	_check(_colour_gap(station.light_colour, Station.WARN_COLOUR) < 0.001 and station.light_colour.r > station.light_colour.b, "in the warning, %.1f m away, the lights are amber: colour %s (calm was %s)" % [_gap(), _colour_text(station.light_colour), _colour_text(Station.CALM_COLOUR)])
	_check(absf(low - Station.PULSE_LOW) < 0.02 and absf(high - Station.PULSE_HIGH) < 0.02 and absf(period - Station.PULSE_SECONDS) < 0.05, "and they pulse slowly: brightness swings from %.2f to %.2f, one pulse every %.2f s (rule: %.2f to %.2f, every %.1f s)" % [low, high, period, Station.PULSE_LOW, Station.PULSE_HIGH, Station.PULSE_SECONDS])
	_check(station.dormant_count() == station.robots.size() and station.wakes == 0, "it is a warning, not an alarm: after %.0f s in it, all %d robots are still dormant" % [8.7, station.robots.size()])
	# Back out.
	await _walk(15.0, 1.6, func() -> bool:
		if float(m.calm_at) < 0.0 and station.light_state == Station.Lights.CALM: m.calm_at = _gap()
		return false)
	await _step(1.5)
	_check(float(m.calm_at) > Station.WARN_DISTANCE and float(m.calm_at) < Station.WARN_DISTANCE + 0.2 and station.light_pulse_depth == 0.0 and _colour_gap(station.light_colour, Station.CALM_COLOUR) < 0.001 and station.hum_level == Station.HUM_STEADY, "backing out, it settled past %.2f m: %.1f s later the lights are blue-white %s and steady again, hum back to level %d" % [float(m.calm_at), 1.5, _colour_text(station.light_colour), station.hum_level])
	await _walk(29.0, PLAYER_RUN, func() -> bool:
		if float(m.off_at) < 0.0 and station.hum_level == Station.HUM_OFF: m.off_at = _gap()
		return false)
	await _step(0.5)
	_check(station.hum_level == Station.HUM_OFF and float(m.off_at) > Station.HUM_DISTANCE and float(m.off_at) < Station.HUM_DISTANCE + 0.3, "running away, the hum stopped at %.2f m; at %.1f m it is level %d" % [float(m.off_at), _gap(), station.hum_level])
	_check(int(RobotParts.sounds_wanted.get(&"station_hum", 0)) >= 4, "the sound hook was asked for the hum each time its level changed: %d times (nothing plays: no sound is approved)" % int(RobotParts.sounds_wanted.get(&"station_hum", 0)))


# ---- waking ------------------------------------------------------------------------------

func _wake() -> void:
	await _begin()
	await _place(6.5)
	await _step(5.0)
	_check(station.wakes == 0 and station.dormant_count() == station.robots.size(), "player standing %.2f m away for 5 s: the robots do not wake (%d of %d dormant)" % [_gap(), station.dormant_count(), station.robots.size()])
	var m := {"at": -1.0}
	await _walk(4.0, 0.8, func() -> bool:
		if station.wakes > 0:
			m.at = _gap()
			return true
		return false)
	var woke_at := clock
	var count: int = station.robots.size() - station.dormant_count()
	_check(float(m.at) > Station.WAKE_DISTANCE - 0.1 and float(m.at) <= Station.WAKE_DISTANCE and count == station.robots.size(), "creeping in, they woke at %.2f m (rule: %.0f): %d of %d robots" % [float(m.at), Station.WAKE_DISTANCE, count, station.robots.size()])
	# How long each takes to stand clear of its bay.
	var out := {}
	await _step(5.0, func() -> bool:
		for robot: CharacterBody3D in station.robots:
			if not out.has(robot) and robot.state == Robot.State.CHASE: out[robot] = clock - woke_at
		return out.size() == station.robots.size())
	var times: Array[String] = []
	var first := INF
	var last := 0.0
	for robot: CharacterBody3D in station.robots:
		var took: float = out.get(robot, -1.0)
		times.append("%.2f s" % took)
		first = minf(first, took)
		last = maxf(last, took)
	_check(first >= 1.8 and first <= 2.3 and last <= Robot.WAKE_SECONDS + Station.WAKE_STAGGER * float(station.robots.size()), "they take about 2 s to step out: %s (rule: %.1f s, each %.1f s after the one before so they do not move as one)" % [", ".join(times), Robot.WAKE_SECONDS, Station.WAKE_STAGGER])
	_check(body.hits_taken.is_empty(), "nobody is struck while they step out (%d hits)" % body.hits_taken.size())
	var empty_bays := 0
	for entry: Variant in station.bay_robots:
		if entry == null: empty_bays += 1
	_check(station.bays == 3 and empty_bays == 1 and get_nodes_in_group("robots").size() == 2, "the empty bay produced nothing: %d bays, %d empty, %d robots in the world after the wake" % [station.bays, empty_bays, get_nodes_in_group("robots").size()])


func _back_off() -> void:
	await _begin()
	await _place(7.0)
	await _walk(4.0, 1.6, func() -> bool: return station.wakes > 0)
	var woke_gap := _gap()
	# Turn and walk away at once, at the player's plain walk.
	body.walk_to(_front(70.0), PLAYER_WALK)
	var m := {"out_gap": -1.0, "closest": INF}
	await _step(14.0, func() -> bool:
		var all_out := _in_state(Robot.State.WAKING) == 0
		if all_out and float(m.out_gap) < 0.0: m.out_gap = _gap()
		for robot: CharacterBody3D in station.robots: m.closest = minf(float(m.closest), _flat(robot.global_position, body.global_position))
		return false)
	body.halt()
	_check(body.hits_taken.is_empty() and float(m.out_gap) > woke_gap, "woke them at %.2f m and walked away at once (%.2f m/s): %.1f m away by the time they were out of their bays, never closer than %.1f m to one after that, struck %d times in 14 s" % [woke_gap, PLAYER_WALK, float(m.out_gap), float(m.closest), body.hits_taken.size()])
	await _end()
	# For the owner: backing away while facing them is slower than they walk.
	await _begin()
	await _place(7.0)
	await _walk(4.0, 1.6, func() -> bool: return station.wakes > 0)
	body.walk_to(_front(70.0), PLAYER_BACK)
	await _step(Robot.WAKE_SECONDS + Station.WAKE_STAGGER + 2.0)
	var lead := _flat(station.robots[0].global_position, body.global_position)
	await _step(10.0)
	var lead_after := _flat(station.robots[0].global_position, body.global_position)
	_info("backing away while facing them (%.2f m/s, slower than their %.1f m/s walk): the nearest robot gained %.1f m in 10 s (from %.1f m behind to %.1f), so it catches a player who only backs away" % [PLAYER_BACK, Robot.WALK_SPEED, lead - lead_after, lead, lead_after])


func _shot() -> void:
	await _begin()
	await _place(20.0)
	await _step(1.0)
	var calm: bool = station.wakes == 0 and station.dormant_count() == 2
	# A bullet in the back wall of the empty middle bay.
	var hit: Dictionary = _shoot(station.to_global(station.bay_point(1) + Vector3(0.0, 1.3, -0.4)))
	await _step(0.2)
	_check(calm and hit.collider == station and bool(hit.counted) and station.wakes == 1 and station.dormant_count() == 0, "a shot at the station from %.1f m (it hit the %s) woke them: %d of %d robots awake, where a moment before all were dormant" % [_gap(), "station" if hit.collider == station else str(hit.collider), station.robots.size() - station.dormant_count(), station.robots.size()])
	await _step(1.5)
	_check(station.awake and station.hum_level == Station.HUM_RAISED and station.light_state == Station.Lights.AWAKE and _colour_gap(station.light_colour, Station.WARN_COLOUR) < 0.001, "with its robots out the station shows it: hum level %d, lights amber %s and steady, though the player is %.0f m away" % [station.hum_level, _colour_text(station.light_colour), _gap()])
	await _end()
	# A bullet in a robot standing in its bay.
	await _begin()
	await _place(20.0)
	await _step(1.0)
	var robot: CharacterBody3D = station.robots[1]
	hit = _shoot(robot.global_position + Vector3.UP * 1.3)
	await _step(0.2)
	_check(hit.collider == robot and bool(hit.counted) and station.dormant_count() == 0 and robot.health < Robot.HEALTH, "a shot at a robot in its bay from %.1f m wakes them all too (%d of %d awake), and hurt it: %.0f of %.0f left" % [_gap(), station.robots.size() - station.dormant_count(), station.robots.size(), robot.health, Robot.HEALTH])


func _empty() -> void:
	await _begin({"id": "RechargeStation", "bays": 3, "robots": 0})
	await _place(30.0)
	await _walk(0.6, 1.6)
	await _step(2.0)
	var warned: bool = station.light_state == Station.Lights.WARNING and station.hum_level == Station.HUM_RAISED
	var hit: Dictionary = _shoot(station.to_global(station.bay_point(1) + Vector3(0.0, 1.3, -0.4)))
	await _step(4.0)
	_check(station.robots.is_empty() and get_nodes_in_group("robots").is_empty() and station.wakes == 0 and not station.awake and body.hits_taken.is_empty(), "a station with 0 robots (%d bays): the player walked to %.1f m and shot it (hit: %s): nothing woke, %d robots exist, nobody was struck" % [station.bays, _gap(), str(hit.collider == station), get_nodes_in_group("robots").size()])
	_check(warned, "it still hums and warns like any other, so only its empty bays say it is safe: hum level %d, lights %s" % [station.hum_level, str(Station.Lights.keys()[station.light_state]).to_lower()])


# ---- what a woken robot does -------------------------------------------------------------

func _strike_and_chase() -> void:
	await _begin(ONE_ROBOT)
	var robot: CharacterBody3D = station.robots[0]
	await _place(7.0)
	await _walk(4.0, 1.6, func() -> bool: return station.wakes > 0)
	var woke_at := clock
	var stood := _gap()
	var struck: bool = await _step(15.0, func() -> bool: return not body.hits_taken.is_empty())
	var first := clock - woke_at
	var damage: float = body.hits_taken[0].amount if struck else 0.0
	_check(struck and damage == Robot.STRIKE_DAMAGE, "a player who stands %.2f m from the station is reached and struck %.2f s after it woke, for %.0f damage (it is %.2f m from the player when the blow lands; it has no gun)" % [stood, first, damage, _flat(robot.global_position, body.global_position)])
	await _step(6.0)
	var blows: int = body.hits_taken.size()
	_info("left standing there for 6 s more it is struck %d times in all: one blow every %.2f s, %.0f damage each" % [blows, (float(body.hits_taken[-1].time) - float(body.hits_taken[0].time)) / maxf(1.0, float(blows - 1)), Robot.STRIKE_DAMAGE])
	# Run. The lane west of the station is 75 m of open ground.
	var run_from := body.global_position
	var robot_from := robot.global_position
	var run_at := clock
	body.walk_to(_front(79.0), PLAYER_RUN)
	var m := {"late_hits": 0, "seen": blows, "lost_at": -1.0, "robot_moved": 0.0, "player_moved": 0.0}
	await _step(30.0, func() -> bool:
		if body.hits_taken.size() > int(m.seen):
			m.seen = body.hits_taken.size()
			if clock - run_at > 0.5: m.late_hits = int(m.late_hits) + 1
		if robot.state == Robot.State.HOLD:
			m.lost_at = clock
			m.robot_moved = _flat(robot.global_position, robot_from)
			m.player_moved = _flat(body.global_position, run_from)
			return true
		return false)
	var ran := float(m.lost_at) - run_at
	var robot_speed := float(m.robot_moved) / maxf(ran, 0.01)
	var player_speed := float(m.player_moved) / maxf(ran, 0.01)
	_check(float(m.lost_at) > 0.0 and int(m.late_hits) == 0 and robot_speed < player_speed, "a running player gets away: over %.1f s the robot made %.2f m/s and the player %.2f m/s; the gap opened to %.1f m and the robot stopped; struck %d more times, none after the first half second" % [ran, robot_speed, player_speed, _flat(robot.global_position, body.global_position), body.hits_taken.size() - blows])
	# Stay away. It waits LOSE_SECONDS, then walks home.
	var held_from := clock
	var nearest := {"gap": INF}
	var turned: bool = await _step(30.0, func() -> bool:
		nearest.gap = minf(float(nearest.gap), _flat(robot.global_position, body.global_position))
		return robot.state == Robot.State.RETURN)
	var waited := clock - held_from
	_check(turned and absf(waited - Robot.LOSE_SECONDS) < 0.3 and float(nearest.gap) > Robot.LOSE_DISTANCE, "with the player never nearer than %.1f m (rule: beyond %.0f) it stood and waited %.2f s (rule: %.0f), then turned for home" % [float(nearest.gap), Robot.LOSE_DISTANCE, waited, Robot.LOSE_SECONDS])
	var walk_from := clock
	var home: bool = await _step(60.0, func() -> bool: return robot.is_dormant())
	await _step(1.5)
	var off: float = robot.global_position.distance_to(robot.home_point())
	_check(home and off < 0.01 and not robot.is_physics_processing() and not robot.is_in_group("extraction_hostiles") and not station.awake, "it walked back and went dormant in its own bay: %.1f s after turning, %.3f m from where it stood at the start, facing out, no longer ticking; the station is calm again (hum level %d at %.0f m)" % [clock - walk_from - 1.5, off, station.hum_level, _gap()])
	await _place(5.0)
	await _step(0.5)
	_check(robot.state == Robot.State.WAKING and station.wakes == 2, "and it can be woken again: a player at %.1f m, and it is %s" % [_gap(), _state_name(robot).to_lower()])


func _shoot_down() -> void:
	await _begin(ONE_ROBOT)
	var robot: CharacterBody3D = station.robots[0]
	await _place(15.0)
	_shoot(station.to_global(station.bay_point(1) + Vector3(0.0, 1.3, -0.4)))
	await _step(Robot.WAKE_SECONDS + 0.3)
	var shots := 0
	var misses := 0
	while not robot.is_down() and shots + misses < 40:
		var hit: Dictionary = _shoot(robot.global_position + Vector3.UP * 1.25)
		if hit.collider == robot: shots += 1
		else: misses += 1
		await _step(0.25)
	var fell_at := robot.global_position
	var gap_then := _flat(fell_at, body.global_position)
	_check(robot.is_down() and misses == 0 and shots == int(ceil(Robot.HEALTH / 30.0)), "it can be shot down: %d body shots of 30 damage (it has %.0f health), %.1f m short of the player, having struck %d times" % [shots, Robot.HEALTH, gap_then, body.hits_taken.size()])
	await _step(Robot.FALL_SECONDS + 0.2)
	var lying: bool = robot.fallen and not robot.is_physics_processing()
	var through: Dictionary = _shoot(fell_at + Vector3.UP * 1.25)
	await _step(35.0)
	var moved := robot.global_position.distance_to(fell_at)
	_check(lying and is_instance_valid(robot) and robot.is_inside_tree() and robot.is_visible_in_tree() and moved < 0.001 and robot.is_down() and through.collider != robot and not robot.is_in_group("extraction_hostiles"), "it stays where it fell: 36 s later it is still there, %.3f m from where it went down, lying still; a bullet where it stood now passes through; the station is calm (lights %s)" % [moved, str(Station.Lights.keys()[station.light_state]).to_lower()])
	await _end()
	# The head is where the sensor is.
	await _begin(ONE_ROBOT)
	robot = station.robots[0]
	await _place(15.0)
	shots = 0
	while not robot.is_down() and shots < 40:
		_shoot(robot.global_position + Vector3.UP * 1.82)
		shots += 1
		await _step(0.1)
	_info("shot in the head (the sensor) it goes down in %d shots: a head hit counts %.0f times over" % [shots, Robot.HEAD_MULTIPLIER])


# ---- stripping it, and the chip ----------------------------------------------------------

func _perched(flock: BirdManager.Flock) -> int:
	var total := 0
	for bird: BirdManager.Bird in flock.birds:
		if bird.state == BirdManager.State.PERCHED: total += 1
	return total


func _crew_states() -> String:
	var parts: Array[String] = []
	for actor: CharacterBody3D in crew.members:
		if is_instance_valid(actor): parts.append("%s %s" % [actor.role, actor.AIState.keys()[actor.state]])
	return ", ".join(parts)


func _nearest_scav(point: Vector3) -> float:
	var best := INF
	for actor: CharacterBody3D in crew.members:
		if is_instance_valid(actor) and not actor.dead: best = minf(best, actor.global_position.distance_to(point))
	return best


## Where the yard station's one robot will lie once it is shot as it steps out.
func _lying_place() -> Vector3:
	var turn := Basis(Vector3.UP, YardRobots.TURN)
	var probe: StaticBody3D = Station.build(ONE_ROBOT, false)
	var local: Vector3 = probe.robots[0].out_local + Vector3(0.0, 0.0, Robot.HEIGHT * 0.45)
	probe.free()
	return YardRobots.POSITION + turn * local


func _strip() -> void:
	var lies := _lying_place()
	var near_birds := lies + Vector3(-9.7, 0.0, -17.4) # 20 m
	var far_birds := lies + Vector3(-42.0, 0.0, -16.0).normalized() * 45.0
	await _begin(ONE_ROBOT, true, Vector3(26.0, 0.2, 29.0), func(birds: BirdManager) -> void:
		var pigeon: int = BirdManager.Kind.PIGEON
		birds.add_flock(pigeon, birds.add_ground_site(near_birds, 1.2, [pigeon]), 6)
		birds.add_flock(pigeon, birds.add_ground_site(far_birds, 1.2, [pigeon]), 6))
	var robot: CharacterBody3D = station.robots[0]
	var house: Node3D = yard.get_node("YardHouse")
	var door: KitDoor = house.door("locked")
	var landing: Vector3 = house.to_global(Vector3(4.52, float(house.floor_heights[1]) + 0.02, 4.65))
	# First, the locked door without a chip.
	body.global_position = landing
	await _step(0.3)
	var pressed: bool = door.interact(body)
	await _step(1.0)
	_check(not pressed and door.locked and not door.opened and not RobotParts.has_chip(body), "without the chip the house's locked door does not open when used (the prompt reads \"%s\")" % door.interaction_prompt(body))
	# Wake the robot, and put it down as it steps clear of its bay.
	await _place(7.0)
	await _walk(4.0, 1.6, func() -> bool: return station.wakes > 0)
	await _step(4.0, func() -> bool: return robot.state == Robot.State.CHASE)
	robot.take_damage(Robot.HEALTH, body)
	await _step(Robot.FALL_SECONDS + 0.3)
	var centre: Vector3 = robot.body_centre()
	body.global_position = Vector3(centre.x, 0.05, centre.z + 1.2)
	await _step(0.3)
	var near_ear := _ear(centre + Vector3(0.0, 0.0, 20.0))
	var far_ear := _ear(centre + Vector3(-40.0, 0.0, 0.0))
	var close: BirdManager.Flock = manager.flocks[0]
	var distant: BirdManager.Flock = manager.flocks[1]
	var birds_down: bool = _perched(close) == close.birds.size() and _perched(distant) == distant.birds.size()
	var crew_gap := _nearest_scav(centre)
	var crew_before := _crew_states()
	var prompt: String = robot.interaction_prompt(body)
	_check(robot.is_down() and robot.fallen and robot.is_in_group("building_access_targets") and robot.interaction_distance(body) < INF and _flat(centre, lies) < 0.5, "the downed robot can be stripped through the yard's own interaction: standing %.1f m from it the prompt reads \"%s\"" % [robot.interaction_distance(body), prompt])
	# Nothing without holding.
	var tapped: bool = robot.interact(body)
	await _step(6.0)
	_check(not tapped and robot.parts.size() == 3 and RobotParts.carried(body).is_empty() and near_ear.heard == 0, "nothing without holding: a press does nothing, and 6 s of standing by it gives no part and makes no noise (%d parts still in it)" % robot.parts.size())
	# A hold that is let go counts for nothing.
	for tick: int in 180:
		robot.hold_interact(body, DT)
		await _step(DT)
	await _step(0.2)
	var after_let_go: int = robot.parts.size()
	var heard_first := near_ear.heard
	var flushed: bool = _perched(close) == 0
	var stayed: bool = _perched(distant) == distant.birds.size()
	# Now hold until it is empty, noting when each part comes out.
	var got: Array = []
	var at: Array[float] = []
	var m := {"ticks": 0, "none_at_3_9": false}
	while not robot.parts.is_empty() and int(m.ticks) < 1200:
		var done: float = robot.hold_interact(body, DT)
		m.ticks = int(m.ticks) + 1
		if int(m.ticks) == 234: m.none_at_3_9 = robot.stripped.is_empty()
		if done >= 1.0:
			got.append(str(robot.stripped[-1]))
			at.append(float(int(m.ticks)) * DT)
		await _step(DT)
	var even := at.size() == 3 and absf(at[0] - 4.0) < 0.05 and absf(at[1] - 8.0) < 0.05 and absf(at[2] - 12.0) < 0.05
	_check(after_let_go == 3 and bool(m.none_at_3_9) and even, "a part every %.0f s of holding: they came out at %s s; at 3.90 s there was none yet; 3 s of holding before that, let go, counted for nothing" % [Robot.STRIP_SECONDS, ", ".join(at.map(func(value: float) -> String: return "%.2f" % value))])
	var carried := RobotParts.carried(body)
	_check(got == ["power_cell", "servo", "access_chip"] and int(carried.get(RobotParts.POWER_CELL, 0)) == 1 and int(carried.get(RobotParts.SERVO, 0)) == 1 and int(carried.get(RobotParts.ACCESS_CHIP, 0)) == 1 and RobotParts.has_chip(body), "the player ends up with a power cell, a servo and the chip: carrying %s" % RobotParts.carried_text(body))
	_check(heard_first > 0 and far_ear.heard == 0, "stripping is noisy: heard at %.0f m (%d times in all) and not at %.0f m (it carries %.0f m)" % [near_ear.global_position.distance_to(centre), near_ear.heard, far_ear.global_position.distance_to(centre), Robot.STRIP_NOISE_RADIUS])
	_check(birds_down and flushed and stayed, "it sends up the birds %.0f m away (all %d pigeons left the ground) and not the ones %.0f m away (all %d stayed)" % [near_birds.distance_to(centre), close.birds.size(), far_birds.distance_to(centre), distant.birds.size()])
	var looking := 0
	for actor: CharacterBody3D in crew.members:
		if actor.state != actor.AIState.PATROL: looking += 1
	_check(crew_gap < 65.0 and not crew.on_guard() and not crew.hostile, "a scav crew %.0f m away does not treat it as gunfire: not on guard, not hostile (before: %s; after: %s)" % [crew_gap, crew_before, _crew_states()])
	_info("that crew was %s the %.0f m the noise carries: %d of %d went to look" % ["inside" if crew_gap <= Robot.STRIP_NOISE_RADIUS else "outside", Robot.STRIP_NOISE_RADIUS, looking, crew.members.size()])
	await _step(1.0)
	_check(robot.parts.is_empty() and robot.interaction_distance(body) == INF and not robot.is_in_group("building_access_targets") and robot.is_inside_tree() and robot.is_visible_in_tree(), "the stripped robot has nothing more to give and still lies where it fell")
	# The chip at the locked door.
	body.global_position = landing
	await _step(0.3)
	var ear := _ear(door.lock_point() + Vector3(-3.0, 0.0, 0.0))
	var sounds := _sounds()
	var chip_prompt: String = door.interaction_prompt(body)
	var used: bool = door.interact(body)
	var at_once: bool = not door.locked
	var from := clock
	await _step(2.0, func() -> bool: return door.opened)
	_check(used and at_once and door.opened and door.opened_with == "chip" and not door.forced, "with the chip the same door opens when it is used: unlocked at once, swung open in %.2f s, lock left whole (the prompt read \"%s\")" % [clock - from, chip_prompt])
	_check(ear.heard == 0 and _sounds() == sounds, "and silently: a listener %.0f m away heard nothing, and no sound was asked for" % ear.global_position.distance_to(door.lock_point()))
	# The same crew does react to a real shot: the two paths are separate.
	body.global_position = Vector3(centre.x, 0.05, centre.z + 1.2)
	await _step(0.3)
	raid.on_shot()
	await _step(1.0)
	_info("a gunshot from beside the robot, for comparison: crew hostile %s, on guard %s (%s)" % [str(crew.hostile), str(crew.on_guard()), _crew_states()])


# ---- from the map's description ----------------------------------------------------------

func _map_station() -> void:
	var five: StaticBody3D = Station.build({"bays": 5, "robots": 3}, false)
	five.position = Vector3(0.0, 0.0, 400.0)
	root.add_child(five)
	await _step(0.2)
	var standing := 0
	for entry: Variant in five.bay_robots:
		if entry != null: standing += 1
	_check(five.bays == 5 and five.robots.size() == 3 and standing == 3 and five.bay_robots.size() == 5 and five.dormant_count() == 3, "a station built from the description {bays: 5, robots: 3} has %d bays and %d robots, each dormant in a bay of its own (%.1f m wide)" % [five.bays, five.robots.size(), five.width])
	five.queue_free()
	var text := FileAccess.get_file_as_string(MAP_FILE)
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	var rows: Array = []
	if parsed is Dictionary and (parsed as Dictionary).get("encounters") is Dictionary: rows = parsed.encounters.get("charging_stations", [])
	var right := 0
	var bay_total := 0
	var robot_total := 0
	var layouts := {}
	for row: Array in rows:
		var one: StaticBody3D = Station.from_map_entry(row, false)
		if one.bays == int(row[2]) and one.robots.size() == int(row[3]) and absf(one.position.x - float(row[0])) < 0.01 and absf(one.position.z - float(row[1])) < 0.01: right += 1
		bay_total += one.bays
		robot_total += one.robots.size()
		var occupied: Array[int] = []
		for robot: CharacterBody3D in one.robots: occupied.append(robot.bay)
		layouts["%d:%s" % [one.bays, str(occupied)]] = true
		one.free()
	_check(rows.size() > 0 and right == rows.size(), "every station in the map plan builds as described: %d of %d rows of encounters.charging_stations, %d bays and %d robots in all, %d different arrangements of full and empty bays (the map file was only read)" % [right, rows.size(), bay_total, robot_total, layouts.size()])
	var odd: StaticBody3D = Station.build({"bays": 9, "robots": 12}, false)
	var small: StaticBody3D = Station.build({"bays": 1, "robots": 0}, false)
	_check(odd.bays == Station.MAX_BAYS and odd.robots.size() == Station.MAX_BAYS and small.bays == Station.MIN_BAYS and small.robots.is_empty(), "a description outside the rule is held to it: 9 bays and 12 robots builds %d and %d; 1 bay builds %d (rule: %d to %d bays)" % [odd.bays, odd.robots.size(), small.bays, Station.MIN_BAYS, Station.MAX_BAYS])
	odd.free()
	small.free()


# ---- what is drawn -----------------------------------------------------------------------

func _triangles(node: Node) -> int:
	var mesh: Mesh = (node as MeshInstance3D).mesh if node is MeshInstance3D else null
	return mesh.surface_get_array_index_len(0) / 3 if mesh != null and mesh.get_surface_count() > 0 else 0


## The same station with its meshes built (the other scenarios run without them): what is
## drawn follows what the rules say.
func _drawn() -> void:
	drawn = true
	await _begin(ONE_ROBOT)
	drawn = false
	var robot: CharacterBody3D = station.robots[0]
	var shell := station.get_node_or_null("Shell") as MeshInstance3D
	var lights := station.get_node_or_null("Lights") as MeshInstance3D
	var glow: StandardMaterial3D = lights.mesh.surface_get_material(0) if lights != null else null
	await _place(30.0)
	await _step(0.5)
	var box: AABB = shell.mesh.get_aabb() if shell != null else AABB()
	_check(shell != null and glow != null and _colour_gap(glow.emission, Station.CALM_COLOUR) < 0.001, "the station is drawn as two meshes: everything white (%d triangles, %.1f m wide, the post %.1f m tall) and everything that glows (%d triangles), glowing %s" % [_triangles(shell), box.size.x, box.end.y, _triangles(lights), _colour_text(glow.emission) if glow != null else "?"])
	var top: float = robot.head.global_position.y + 0.28 - robot.global_position.y
	_check(robot.rig != null and robot.mesh_count == 11 and absf(top - Robot.HEIGHT) < 0.05 and robot.lens.material_override.emission_enabled == false and robot.head.rotation.x < -0.1, "a dormant robot stands in its bay: %d meshes, %d triangles, %.2f m tall, head bowed %.0f degrees, sensor dark" % [robot.mesh_count, robot.triangles, top, absf(rad_to_deg(robot.head.rotation.x))])
	await _place(9.0)
	await _step(2.0)
	_check(_colour_gap(glow.emission, Station.WARN_COLOUR) < 0.001 and absf(glow.emission_energy_multiplier - station.light_energy) < 0.001, "in the warning the drawn lights are amber %s and follow the pulse (brightness %.2f now)" % [_colour_text(glow.emission), glow.emission_energy_multiplier])
	await _walk(4.0, 1.6, func() -> bool: return station.wakes > 0)
	var m := {"lowest": INF, "highest": -INF, "knee": 0.0}
	await _step(Robot.WAKE_SECONDS + 0.1, func() -> bool:
		m.lowest = minf(float(m.lowest), robot.hips.position.y)
		m.highest = maxf(float(m.highest), robot.hips.position.y)
		m.knee = maxf(float(m.knee), absf(robot._shins[0].rotation.x))
		return false)
	var lens: StandardMaterial3D = robot.lens.material_override
	_check(lens.emission_enabled and lens.emission_energy_multiplier > 3.0 and absf(robot.head.rotation.x) < 0.01 and float(m.knee) > 0.4, "stepping out, its sensor lights up (brightness %.1f), its head comes up, and its legs really step: a knee bends up to %.0f degrees and the hips dip %.0f mm with each step" % [lens.emission_energy_multiplier, rad_to_deg(float(m.knee)), (float(m.highest) - float(m.lowest)) * 1000.0])
	robot.take_damage(Robot.HEALTH, body)
	await _step(Robot.FALL_SECONDS + 0.3)
	var head_up: float = robot.head.global_position.y
	_check(robot.fallen and robot.rig.rotation.x < -1.4 and head_up < 0.45 and robot.lens.material_override.emission_enabled == false, "a downed robot is drawn lying on its front: tipped %.0f degrees, its head %.2f m above the ground, sensor dark" % [absf(rad_to_deg(robot.rig.rotation.x)), head_up])


# ---- cost --------------------------------------------------------------------------------

func _cost() -> void:
	for what: Array in [[3, 2], [5, 3], [2, 0]]:
		var total := 0
		var stats := {}
		for index: int in 5:
			var one: StaticBody3D = Station.build({"bays": what[0], "robots": what[1]}, true)
			total += int(one.stats.build_usec)
			stats = one.stats
			one.free()
		_info("a station with %d bays and %d robots, as drawn: %d nodes, %d physics bodies with %d collision shapes, %d meshes (= draw calls at most), %d light, %d triangles; built in %.1f ms (average of 5)" % [int(stats.bays), int(stats.robots), int(stats.nodes), int(stats.bodies), int(stats.collision_shapes), int(stats.meshes), int(stats.lights), int(stats.triangles), float(total) / 5000.0])
	drawn = true
	await _begin()
	drawn = false
	var ticking := 0
	for robot: CharacterBody3D in station.robots:
		if robot.is_physics_processing(): ticking += 1
	_check(ticking == 0 and station.dormant_count() == 2, "a dormant robot does not tick at all: %d of %d robots have their tick switched on" % [ticking, station.robots.size()])
	# The station's own tick, with the player far off: called 20,000 times in a row, which
	# is 333 s of game time, so it includes every look it takes at where the players are.
	body.set_physics_process(false)
	body.global_position = _front(70.0) + Vector3.UP * 0.05
	await _step(0.3)
	var started := Time.get_ticks_usec()
	for index: int in 20000: station._physics_process(DT)
	var far := float(Time.get_ticks_usec() - started) / 20000.0
	_check(far < 3.0 and station.hum_level == Station.HUM_OFF, "a dormant station far from any player costs almost nothing: %.3f microseconds a tick, so the map's 21 cost %.2f of a frame's 16,667" % [far, far * 21.0])
	body.global_position = _front(9.0) + Vector3.UP * 0.05
	station.track(body)
	await _step(1.5)
	started = Time.get_ticks_usec()
	for index: int in 20000: station._physics_process(DT)
	var warning := float(Time.get_ticks_usec() - started) / 20000.0
	_info("the same station with a player in its warning ring (lights pulsing): %.2f microseconds a tick" % warning)
	# A robot awake and walking after a player it will not reach in the time measured.
	body.global_position = _front(38.0) + Vector3.UP * 0.05
	station.wake(body)
	await _step(Robot.WAKE_SECONDS + Station.WAKE_STAGGER + 0.2)
	var robot: CharacterBody3D = station.robots[0]
	started = Time.get_ticks_usec()
	for index: int in 400: robot._physics_process(DT)
	var walking := float(Time.get_ticks_usec() - started) / 400.0
	_info("one robot awake and walking, limbs posed every tick: %.1f microseconds a tick (state %s)" % [walking, _state_name(robot).to_lower()])
