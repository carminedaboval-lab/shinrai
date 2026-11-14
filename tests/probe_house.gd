extends SceneTree
## Proves the house rules in the test yard (headless, no park boot):
##   godot --headless --path . --fixed-fps 60 --script res://tests/probe_house.gd
##   ... -- --only=window_shot,locked_crowbar     runs just those scenarios
## Each scenario builds a fresh yard with the kit house in it, plays a scripted "player" at
## it and prints one HOUSE_PASS or HOUSE_FAIL line per rule, with the measured number.
## HOUSE_INFO lines are measurements with no pass mark. Ends with HOUSE_DONE passed=N failed=N.
## Positions in the messages are in the house's own metres: x along the front, z from the
## front wall back, heights above the yard's ground.

const YardWorld := preload("res://scripts/test_yard/yard_world.gd")
const YardRaid := preload("res://scripts/test_yard/yard_raid.gd")
const Squad := preload("res://scripts/scav_squad.gd")
const BirdManager := preload("res://scripts/wildlife/bird_manager.gd")
const HouseKit := preload("res://scripts/interior_kit/house_kit.gd")
const YardHouse := preload("res://scripts/interior_kit/yard_house.gd")
const KitDoor := preload("res://scripts/interior_kit/door.gd")
const KitWindow := preload("res://scripts/interior_kit/window.gd")
const KitNoise := preload("res://scripts/interior_kit/noise.gd")
const DT := 1.0 / 60.0
const LIMBS: Array[String] = ["left_arm", "right_arm", "left_leg", "right_leg"]
const SMASH_SEED := 20261113
const SMASH_TRIES := 300

## A second, different house, to show the kit builds from a description and not just the one
## in the yard: another size, the stair along the front wall climbing the other way, rooms at
## the back, the door at one end.
const OTHER_SPEC := {
	"id": "OtherHouse",
	"size": Vector2(9.0, 6.0),
	"floors": 2,
	"stair": {"x": 7.0, "z": 0.15, "dir": "-x"},
	"partitions": [
		{"id": "mid", "floors": [0, 1], "a": Vector2(0.15, 3.0), "b": Vector2(8.85, 3.0)},
		{"id": "split", "floors": [0, 1], "a": Vector2(4.5, 3.06), "b": Vector2(4.5, 5.85)},
	],
	"doors": [
		{"name": "front", "wall": "right", "floor": 0, "at": 2.0, "swing": -1, "hinge": "low", "front": true},
		{"name": "back_left", "wall": "mid", "floor": 0, "at": 2.0, "swing": 1, "hinge": "low"},
		{"name": "back_right", "wall": "mid", "floor": 0, "at": 6.5, "swing": 1, "hinge": "high"},
		{"name": "up_left", "wall": "mid", "floor": 1, "at": 2.0, "swing": 1, "hinge": "low"},
		{"name": "up_right", "wall": "mid", "floor": 1, "at": 6.5, "swing": 1, "hinge": "high", "locked": true},
	],
	"windows": [
		{"name": "front", "wall": "front", "floor": 0, "at": 2.2, "width": 1.6, "sill": 0.0},
		{"name": "back", "wall": "back", "floor": 0, "at": 6.6, "width": 1.2},
		{"name": "up_front", "wall": "front", "floor": 1, "at": 2.2, "width": 1.6},
		{"name": "up_back", "wall": "back", "floor": 1, "at": 2.2, "width": 1.2},
	],
	"steps": [{"wall": "right", "at": 2.0, "width": 1.5, "depth": 1.0}],
	"loot": [{"floor": 1, "at": Vector2(6.8, 4.6), "tier": "locked_room"}],
}


## The scripted player of the scav and bird probes, plus the two things a house asks of a
## player: the medical record a cut is written to, and whether a crowbar is carried.
class Body extends "res://tests/ai_probe_target.gd":
	var medical: RefCounted = preload("res://scripts/extraction_medical.gd").new()
	var has_crowbar := false


## Something that hears noises: counts the ones that reach it.
class Ear extends Node3D:
	var heard := 0
	func on_noise(point: Vector3, radius: float) -> void:
		if global_position.distance_to(point) <= radius: heard += 1


## The game's own player controller, cut down the way tests/test_mantle_physics.gd does it:
## the real body and the real movement code, no weapon and no HUD.
class RealPlayer extends "res://scripts/player.gd":
	func _ready() -> void:
		collision_layer = 1
		collision_mask = 3
		add_to_group("shinrai_input_players")
		_build_collision()
		_build_camera()
		set_physics_process(false)
		set_process(false)
		set_process_unhandled_input(false)


var yard: Node3D
var house: Node3D
var body: CharacterBody3D
var raid: Node
var crew: Node3D
var manager: BirdManager
var only: PackedStringArray = []
var passed := 0
var failed := 0
var clock := 0.0
var f0 := 0.0
var f1 := 0.0
## True builds the yard with its meshes even when headless (the "drawn" scenario).
var drawn := false
var _label := ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=").split(",")
	_run.call_deferred()


func _run() -> void:
	var scenarios := {
		"sizes": _sizes, "walk_through": _walk_through, "locked_crowbar": _locked_crowbar,
		"locked_other_ways": _locked_other_ways, "window_intact": _window_intact,
		"window_shot": _window_shot, "window_knock_out": _window_knock_out,
		"window_smash": _window_smash, "noise": _noise, "noise_near_scavs": _noise_near_scavs,
		"real_player": _real_player, "drawn": _drawn, "other_house": _other_house, "cost": _cost,
	}
	for label: String in scenarios:
		if not only.is_empty() and not only.has(label): continue
		_label = label
		print("HOUSE_BEGIN ", label)
		await scenarios[label].call()
		await _end()
	print("HOUSE_DONE passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)


# ---- world -------------------------------------------------------------------------------

## `start_far` puts the player in the far corner of the yard while the crew is placed (a crew
## will not start within 35 m of the player).
func _begin(with_raid: bool = false, crew_anchor: Vector3 = Vector3.INF, bird_setup: Callable = Callable(), start_far: bool = false) -> void:
	yard = YardWorld.new()
	yard.visuals = drawn or DisplayServer.get_name() != "headless"
	yard.birds = false
	root.add_child(yard)
	yard.build()
	house = yard.get_node("YardHouse")
	f0 = house.floor_heights[0]
	f1 = house.floor_heights[1]
	manager = null
	if bird_setup.is_valid():
		manager = BirdManager.new()
		manager.name = "Wildlife"
		manager.rng.seed = 7
		yard.add_child(manager)
		bird_setup.call(manager)
	body = Body.new()
	body.name = "ProbePlayer"
	yard.add_child(body)
	body.global_position = Vector3(-40.0, 0.05, 40.0) if start_far else _w(4.18, -3.5, 0.05)
	house.track(body)
	if manager != null: manager.add_player(body)
	await physics_frame
	await physics_frame
	raid = null
	crew = null
	if with_raid:
		raid = YardRaid.new()
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
	manager = null
	await process_frame
	await process_frame


func _step(seconds: float, until: Callable = Callable()) -> bool:
	var frames := int(round(seconds / DT))
	for i: int in frames:
		await physics_frame
		clock += DT
		if until.is_valid() and until.call(): return true
	return false


func _check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("%s %s: %s" % ["HOUSE_PASS" if ok else "HOUSE_FAIL", _label, text])


func _info(text: String) -> void:
	print("HOUSE_INFO %s: %s" % [_label, text])


## A point given in the house's own metres (x along the front, z back from it, y up), in the world.
func _w(x: float, z: float, y: float = 0.0) -> Vector3:
	return house.to_global(Vector3(x, y, z))


## Where a body is, in the house's own metres.
func _at(who: Node3D = null) -> Vector3:
	return house.to_local((who if who != null else body).global_position)


## Walks the scripted player through the points (house x, z) in turn.
func _walk(points: Array, speed: float = 1.6, limit: float = 25.0) -> bool:
	var route := PackedVector3Array()
	for point: Vector2 in points: route.append(_w(point.x, point.y))
	body.follow(route, speed)
	var done: bool = await _step(limit, func() -> bool: return body.arrived())
	body.halt()
	return done


func _put(x: float, z: float, y: float) -> void:
	body.halt()
	body.global_position = _w(x, z, y + 0.02)
	await _step(0.25)


## A bullet, fired the way player.gd fires one: a ray, and receive_bullet_hit() on what it hits.
func _shoot(from: Vector3, at: Vector3) -> Dictionary:
	var direction := (at - from).normalized()
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * 60.0, 1 | 2 | 4 | 8, [body.get_rid()])
	query.collide_with_areas = true
	var result := yard.get_world_3d().direct_space_state.intersect_ray(query)
	var counted := false
	if not result.is_empty() and result.collider.has_method("receive_bullet_hit"):
		counted = result.collider.receive_bullet_hit(30.0, body, result.position, direction)
	return {"collider": result.get("collider"), "counted": counted}


func _ray(from: Vector3, to: Vector3, skip: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = skip
	return yard.get_world_3d().direct_space_state.intersect_ray(query)


## How far it is from `from` to the first solid thing towards `to` (house metres). -1: nothing.
func _gap(from: Vector3, to: Vector3, skip: Array[RID] = []) -> float:
	var a := house.to_global(from)
	var hit := _ray(a, house.to_global(to), skip)
	return a.distance_to(hit.position) if not hit.is_empty() else -1.0


func _bleeding() -> Dictionary:
	var output := {}
	for part: String in body.medical.PARTS:
		if int(body.medical.bleeding[part]) > 0: output[part] = int(body.medical.bleeding[part])
	return output


func _ear(at: Vector3) -> Ear:
	var ear := Ear.new()
	ear.add_to_group(KitNoise.LISTENER_GROUP)
	yard.add_child(ear)
	ear.global_position = at
	return ear


func _near(a: float, b: float, slack: float = 0.011) -> bool:
	return absf(a - b) <= slack


# ---- the sizes ---------------------------------------------------------------------------

## Measures the built house with rays against the brief's real sizes.
func _sizes() -> void:
	await _begin()
	var size: Vector2 = house.spec.size
	_check(size.x >= 8.0 and size.x <= 9.0 and size.y >= 6.0 and size.y <= 7.0 and house.floor_heights.size() == 2, "the house is %.1f m by %.1f m with %d floors (brief: about 8-9 by 6-7, two floors)" % [size.x, size.y, house.floor_heights.size()])
	var low := _gap(Vector3(1.6, f0 + 0.05, 3.0), Vector3(1.6, f0 + 4.0, 3.0)) + 0.05
	var high := _gap(Vector3(1.6, f1 + 0.05, 3.0), Vector3(1.6, f1 + 4.0, 3.0)) + 0.05
	_check(_near(low, 2.4) and _near(high, 2.4), "ceilings: %.2f m downstairs, %.2f m upstairs (brief: about 2.4); floor to floor %.2f m" % [low, high, f1 - f0])
	var front: KitDoor = house.door("front")
	var leaf: Array[RID] = [front.leaf.get_rid()]
	var across := _gap(Vector3(4.2, f0 + 1.0, 0.075), Vector3(2.0, f0 + 1.0, 0.075), leaf) + _gap(Vector3(4.2, f0 + 1.0, 0.075), Vector3(6.4, f0 + 1.0, 0.075), leaf)
	var up := _gap(Vector3(4.2, f0 + 0.1, 0.075), Vector3(4.2, f0 + 4.0, 0.075), leaf) + 0.1
	_check(front.size.x >= 0.85 and front.size.x <= 0.9 and _near(front.size.y, 2.0, 0.02), "front door: the leaf is %.2f m wide and %.2f m high (brief: 0.85-0.9 by 2.0), in a hole %.2f by %.2f m that the lining takes 0.02 m of on each side" % [front.size.x, front.size.y, across, up])
	var stair: Dictionary = house.stair
	var mid_y := f0 + (4.0 - 2.58) * (f1 - f0) / (5.44 - 2.58) + 0.5
	var lane := _gap(Vector3(3.66, mid_y, 4.0), Vector3(1.0, mid_y, 4.0)) + _gap(Vector3(3.66, mid_y, 4.0), Vector3(6.0, mid_y, 4.0))
	_check(_near(float(stair.rise), 0.20, 0.006) and _near(float(stair.going), 0.22) and _near(lane, 0.8), "stair: %d risers of %.3f m, going %.2f m, %.2f m clear between the wall and the banister (brief: about 0.20, 0.22, 0.8); it climbs at %.1f degrees" % [int(stair.risers), float(stair.rise), float(stair.going), lane, float(stair.slope_degrees)])
	_check(float(stair.slope_degrees) < rad_to_deg(body.floor_max_angle) - 1.0, "the ramp under the steps is %.1f degrees: under the %.0f degree limit of a walking body" % [float(stair.slope_degrees), rad_to_deg(body.floor_max_angle)])
	# West wall, waist window: drop a ray down the middle of its opening onto the sill.
	var window: KitWindow = house.window("west_living")
	var pane: Array[RID] = [window.get_rid()]
	var sill := f0 + 1.5 - _gap(Vector3(0.075, f0 + 1.5, 4.1), Vector3(0.075, f0 - 1.0, 4.1), pane) - f0
	var head := 1.5 + _gap(Vector3(0.075, f0 + 1.5, 4.1), Vector3(0.075, f0 + 4.0, 4.1), pane)
	_check(sill >= 0.84 and sill <= 0.91, "window sill %.2f m above the floor, head at %.2f m, level with the door heads (brief: sills about 0.85-0.9)" % [sill, head])
	# A wall's thickness: the distance between two points either side of it, less the two gaps.
	var outer := 2.0 - _gap(Vector3(-1.0, f0 + 1.0, 2.0), Vector3(1.0, f0 + 1.0, 2.0)) - _gap(Vector3(1.0, f0 + 1.0, 2.0), Vector3(-1.0, f0 + 1.0, 2.0))
	var inner := 1.4 - _gap(Vector3(4.6, f0 + 1.0, 5.6), Vector3(6.0, f0 + 1.0, 5.6)) - _gap(Vector3(6.0, f0 + 1.0, 5.6), Vector3(4.6, f0 + 1.0, 5.6))
	_check(outer >= 0.12 and outer <= 0.18 and inner >= 0.12 and inner <= 0.18, "walls: outer %.2f m thick, inner %.2f m (brief: 0.12-0.18)" % [outer, inner])
	var per_floor := [0, 0]
	var locked := 0
	for entry: Dictionary in house.spec.doors:
		if bool(entry.get("front", false)): continue
		per_floor[int(entry.floor)] += 1
		if bool(entry.get("locked", false)): locked += 1
	_check(per_floor[0] >= 2 and per_floor[1] >= 2 and locked == 1, "several rooms on each floor: %d room doors off the hall downstairs, %d off the landing upstairs, %d of them locked" % [per_floor[0], per_floor[1], locked])


# ---- walking through it ------------------------------------------------------------------

func _walk_through() -> void:
	await _begin()
	var front: KitDoor = house.door("front")
	body.walk_to(_w(4.18, 1.3), 1.6)
	await _step(3.0)
	body.halt()
	var at := _at()
	_check(at.z < 0.0 and not front.opened, "the closed front door stops the player: after walking at it for 3 s the body is %.2f m outside the door" % (0.075 - at.z))
	await _walk([Vector2(4.18, -1.8)])
	var used: bool = front.interact(body)
	var from := clock
	await _step(2.0, func() -> bool: return front.opened)
	_check(used and front.opened, "the front door swings open when it is used (%.2f s)" % (clock - from))
	from = clock
	var arrived: bool = await _walk([Vector2(4.18, -0.6), Vector2(4.18, 1.3)])
	at = _at()
	_check(arrived and at.z > 0.15 and _near(at.y, f0, 0.03), "walked in through the front door, up the step: now %.2f m inside, standing on the hall floor %.2f m above the ground (%.1f s from the step)" % [at.z - 0.15, at.y, clock - from])
	# A ground-floor room: the living room, through its door off the hall.
	await _walk([Vector2(4.3, 1.67)])
	var living: KitDoor = house.door("living")
	used = living.interact(body)
	await _step(2.0, func() -> bool: return living.opened)
	arrived = await _walk([Vector2(2.6, 1.67), Vector2(1.6, 3.0)])
	at = _at()
	_check(used and arrived and at.x < 3.14 and at.x > 0.15 and _near(at.y, f0, 0.03), "reached a ground-floor room: in the living room at (%.1f, %.1f), through its own door" % [at.x, at.z])
	# Up the stair.
	await _walk([Vector2(2.6, 1.67), Vector2(4.3, 1.67), Vector2(3.66, 1.85)])
	var m := {"top": -1.0, "start": clock, "highest": -INF}
	body.follow(PackedVector3Array([_w(3.66, 5.9)]), 1.6)
	arrived = await _step(20.0, func() -> bool:
		var height := _at().y
		m.highest = maxf(float(m.highest), height)
		if float(m.top) < 0.0 and height >= f1 - 0.02: m.top = clock - float(m.start)
		return body.arrived())
	body.halt()
	await _step(0.3)
	at = _at()
	var stair: Dictionary = house.stair
	_check(arrived and float(m.top) > 0.0 and _near(at.y, f1, 0.03) and body.is_on_floor(), "climbed the stair and stands on the upper floor: height reached %.2f m above the ground (the upper floor is at %.2f m), %.2f m above the hall; the climb took %.1f s at a walk; %d risers of %.3f m, %.1f degrees" % [at.y, f1, at.y - f0, float(m.top), int(stair.risers), float(stair.rise), float(stair.slope_degrees)])
	# Round the landing. The banister has to hold.
	await _walk([Vector2(4.65, 5.9), Vector2(4.65, 4.0)])
	body.walk_to(_w(3.66, 4.0), 1.6)
	await _step(2.0)
	body.halt()
	at = _at()
	_check(at.x > 4.15 + 0.3 and _near(at.y, f1, 0.03), "the banister holds: walking at the stairwell for 2 s leaves the body %.2f m from the edge, still on the upper floor at %.2f m" % [at.x - 4.15, at.y])
	# An upper room: the bedroom at the front.
	await _walk([Vector2(4.65, 4.0), Vector2(4.65, 1.67)])
	var bedroom: KitDoor = house.door("bedroom")
	used = bedroom.interact(body)
	await _step(2.0, func() -> bool: return bedroom.opened)
	arrived = await _walk([Vector2(2.6, 1.67), Vector2(1.6, 3.2)])
	at = _at()
	_check(used and arrived and at.x < 3.14 and _near(at.y, f1, 0.03), "walked round the landing to an upper room: in the bedroom at (%.1f, %.1f), %.2f m up" % [at.x, at.z, at.y])
	# And back down.
	await _walk([Vector2(2.6, 1.67), Vector2(4.65, 1.67), Vector2(4.65, 5.9), Vector2(3.66, 5.9)])
	var d := {"drop": 0.0, "before": _at().y, "start": clock}
	body.follow(PackedVector3Array([_w(3.66, 1.85), _w(4.18, 1.3)]), 1.6)
	arrived = await _step(20.0, func() -> bool:
		var height := _at().y
		d.drop = maxf(float(d.drop), float(d.before) - height)
		d.before = height
		return body.arrived())
	body.halt()
	at = _at()
	_check(arrived and _near(at.y, f0, 0.03) and float(d.drop) < 0.06, "came back down the stair: on the hall floor at %.2f m after %.1f s; never fell (the largest drop in one tick was %.3f m)" % [at.y, clock - float(d.start), float(d.drop)])
	arrived = await _walk([Vector2(4.18, -0.6), Vector2(4.18, -3.0)])
	at = _at()
	_check(arrived and at.z < -2.5 and _near(at.y, 0.0, 0.03), "walked back out of the front door to the street")


# ---- the locked door ---------------------------------------------------------------------

## Stands the player on the landing, at the locked door.
func _to_locked_door() -> KitDoor:
	await _put(4.52, 4.65, f1)
	return house.door("locked")


func _locked_crowbar() -> void:
	await _begin()
	var door: KitDoor = await _to_locked_door()
	body.walk_to(_w(6.9, 4.65), 1.6)
	await _step(2.5)
	body.halt()
	var at := _at()
	_check(at.x < 5.14 and door.locked and not door.opened, "the locked door stops the player: after walking at it for 2.5 s the body is still on the landing, %.2f m short of the room" % (5.26 - at.x))
	await _walk([Vector2(4.52, 4.65)])
	var lock := door.lock_point()
	var near_ear := _ear(lock + Vector3(-30.0, 0.0, 0.0))
	var far_ear := _ear(lock + Vector3(-50.0, 0.0, 0.0))
	# No crowbar.
	var pressed: bool = door.interact(body)
	for tick: int in 360:
		door.hold_interact(body, DT)
		await physics_frame
	_check(not pressed and door.locked and not door.opened and door.pry_seconds == 0.0 and near_ear.heard == 0, "without a crowbar it cannot be opened: a press does nothing, and 6 s of holding leaves it locked, with no noise made")
	# With one. First a hold that is let go, to show the count starts again.
	body.has_crowbar = true
	for tick: int in 180:
		door.hold_interact(body, DT)
		await physics_frame
	for tick: int in 6: await physics_frame
	var m := {"ticks": 0, "locked_at_4_9": false}
	while door.locked and int(m.ticks) < 600:
		door.hold_interact(body, DT)
		m.ticks = int(m.ticks) + 1
		if int(m.ticks) == 294: m.locked_at_4_9 = door.locked
		await physics_frame
	var held := float(int(m.ticks)) * DT
	_check(not door.locked and bool(m.locked_at_4_9) and absf(held - KitDoor.CROWBAR_SECONDS) <= 0.05 and door.opened_with == "crowbar", "with a crowbar the lock gave after %.2f s of holding (rule: %.0f s); at 4.90 s it was still locked; 3 s of holding before that, let go, counted for nothing" % [held, KitDoor.CROWBAR_SECONDS])
	_check(near_ear.heard > 0 and far_ear.heard == 0, "forcing it was heard at %.0f m (%d times) and not at %.0f m (it carries %.0f m)" % [near_ear.global_position.distance_to(lock), near_ear.heard, far_ear.global_position.distance_to(lock), KitDoor.CROWBAR_NOISE_RADIUS])
	await _step(2.0, func() -> bool: return door.opened)
	var arrived: bool = await _walk([Vector2(5.9, 4.63), Vector2(6.9, 5.0)])
	at = _at()
	_check(door.opened and arrived and at.x > 5.26 and at.z > 3.36, "the forced door swung open and the player walked into the locked room, to (%.1f, %.1f)" % [at.x, at.z])
	var inside := 0
	var elsewhere := 0
	for marker: Node in get_nodes_in_group(HouseKit.LOOT_GROUP):
		var p: Vector3 = house.to_local((marker as Node3D).global_position)
		var in_room: bool = p.x > 5.26 and p.z > 3.36 and _near(p.y, f1)
		if str(marker.get_meta("loot_tier")) == "locked_room":
			if in_room: inside += 1
			else: elsewhere += 100
		elif in_room: elsewhere += 100
		else: elsewhere += 1
	_check(inside == 1 and elsewhere < 100, "the better loot is behind the locked door: %d 'locked_room' loot marker in that room, %d ordinary markers in the open rooms, none the wrong way round" % [inside, elsewhere])


func _locked_other_ways() -> void:
	# Shooting the lock.
	await _begin()
	var door: KitDoor = await _to_locked_door()
	var eye := body.global_position + Vector3.UP * 1.5
	var panel: Dictionary = _shoot(eye, door.leaf.to_global(Vector3(0.3, 0.5, 0.0)))
	_check(panel.collider == door.leaf and not bool(panel.counted) and door.lock_hits == 0, "a bullet in the door panel, away from the lock, does not count")
	_shoot(eye, door.lock_point())
	_shoot(eye, door.lock_point())
	_check(door.locked and door.lock_hits == 2 and not door.opened, "two hits on the lock: still locked")
	var third: Dictionary = _shoot(eye, door.lock_point())
	await _step(2.0, func() -> bool: return door.opened)
	_check(bool(third.counted) and not door.locked and door.opened and door.opened_with == "shots" and door.forced, "the third hit on the lock breaks it and the door swings open (rule: %d hits)" % KitDoor.LOCK_SHOTS)
	await _end()
	# The access chip.
	await _begin()
	door = await _to_locked_door()
	var ear := _ear(door.lock_point() + Vector3(-3.0, 0.0, 0.0))
	var ear_gap := ear.global_position.distance_to(door.lock_point())
	var sounds := KitNoise.sounds_total()
	var chipped: bool = door.open_with_chip(body)
	var at_once: bool = not door.locked
	await _step(2.0, func() -> bool: return door.opened)
	_check(chipped and at_once and door.opened and not door.forced, "the access-chip call unlocks it at once and it swings open, with the lock left whole")
	_check(ear.heard == 0 and KitNoise.sounds_total() == sounds, "and silently: a listener %.0f m away heard nothing, and no sound was asked for" % ear_gap)
	await _end()
	# From inside the room.
	await _begin()
	door = house.door("locked")
	await _put(6.8, 4.65, f1) # clear of where the leaf swings to
	var turned: bool = door.interact(body)
	await _step(2.0, func() -> bool: return door.opened)
	_check(turned and door.opened and door.opened_with == "inside" and not door.forced, "from inside the locked room the door just unlocks and opens (a thumb turn)")


# ---- the window --------------------------------------------------------------------------

func _big_window() -> KitWindow:
	return house.window("front_living")


func _shoot_window(window: KitWindow) -> Dictionary:
	return _shoot(body.global_position + Vector3.UP * 1.5, window.global_position)


func _window_intact() -> void:
	await _begin()
	var window := _big_window()
	await _put(1.7, -2.5, 0.0)
	body.walk_to(_w(1.7, 2.5), 1.6)
	await _step(4.0)
	body.halt()
	var at := _at()
	_check(at.z < 0.075 and window.glass == KitWindow.Glass.INTACT and window.passes == 0, "an intact window stops a walking player: after 4 s of walking at it the body's middle is %.2f m outside the glass, on the step, and the pane is whole" % (0.075 - at.z))


func _window_shot() -> void:
	await _begin()
	var window := _big_window()
	await _put(1.7, -2.2, 0.0)
	var shot: Dictionary = _shoot_window(window)
	await _step(0.1)
	_check(shot.collider == window and bool(shot.counted) and window.glass == KitWindow.Glass.SHOT and not window.pane.visible and window.collision_layer == 0, "one shot: the pane is gone (state SHOT, pane hidden, nothing solid left in the opening)")
	var again: Dictionary = _shoot_window(window)
	_check(again.collider != window, "a second bullet goes through the opening and hits %s" % ("the " + str(again.collider.name) if again.collider != null else "nothing"))
	_check(window.shard_count > 0 and window.shard_reach.y <= KitWindow.SHARD_RING + 0.001 and window.shard_reach.y >= 0.08, "a ring of shards is left in the frame: %d shards, reaching from %.2f to %.2f m in from its edge (rule: about %.2f m); %d pieces lie on the floor inside, the way the bullet went" % [window.shard_count, window.shard_reach.x, window.shard_reach.y, KitWindow.SHARD_RING, window.floor_pieces])
	var radius: float = KitWindow.body_radius(body)
	var clear := window.clear_half_width(radius)
	var passes := 0
	for index: int in 30:
		if await _walk([Vector2(1.7, 1.6 if index % 2 == 0 else -1.6)], 1.6, 10.0): passes += 1
	_check(passes == 30 and window.passes == 30 and window.cuts == 0 and _bleeding().is_empty(), "walked through the middle of it %d times, in and out: %d bleeds (the body is %.2f m wide in an opening %.2f m wide; the clear middle leaves it %.2f m to spare each side)" % [window.passes, window.cuts, radius * 2.0, window.dimensions.x, clear])
	# Now with a shoulder in the shards.
	var off := 0.36
	await _walk([Vector2(1.7 + off, -1.6)])
	var counts := {}
	var wrong := 0
	var cut := 0
	for index: int in 10:
		body.medical.reset()
		await _walk([Vector2(1.7 + off, 1.6 if index % 2 == 0 else -1.6)], 1.6, 10.0)
		var wounds := _bleeding()
		if wounds.size() == 1 and int(wounds.values()[0]) == 1 and LIMBS.has(str(wounds.keys()[0])):
			cut += 1
			counts[wounds.keys()[0]] = int(counts.get(wounds.keys()[0], 0)) + 1
		else: wrong += 1
	_check(cut == 10 and wrong == 0, "walked through %.2f m off the middle, a shoulder %.2f m into the ring, 10 times: a light bleed every time, always on an arm or a leg %s" % [off, off + radius - (window.dimensions.x * 0.5 - KitWindow.SHARD_RING), JSON.stringify(counts)])


func _window_knock_out() -> void:
	await _begin()
	var window := _big_window()
	await _put(1.7, -1.0, 0.0)
	_shoot_window(window)
	await _step(0.1)
	var m := {"ticks": 0, "ring_at_1_9": false}
	while window.glass != KitWindow.Glass.CLEAN and int(m.ticks) < 400:
		window.hold_interact(body, DT)
		m.ticks = int(m.ticks) + 1
		if int(m.ticks) == 114: m.ring_at_1_9 = window.glass == KitWindow.Glass.SHOT and window.shard_count > 0
		await physics_frame
	var held := float(int(m.ticks)) * DT
	_check(window.glass == KitWindow.Glass.CLEAN and bool(m.ring_at_1_9) and absf(held - KitWindow.KNOCK_OUT_SECONDS) <= 0.05 and window.shard_count == 0, "knocking the rest out took %.2f s of holding (rule: %.0f s); at 1.90 s the ring was still there; afterwards no shard is left in the frame" % [held, KitWindow.KNOCK_OUT_SECONDS])
	var off := 0.36
	await _walk([Vector2(1.7 + off, -1.6)])
	var passes := 0
	for index: int in 10:
		if await _walk([Vector2(1.7 + off, 1.6 if index % 2 == 0 else -1.6)], 1.6, 10.0): passes += 1
	_check(passes == 10 and window.cuts == 0 and _bleeding().is_empty() and window.interaction_distance(body) == INF, "after that, brushing the frame does nothing: %d passes %.2f m off the middle, %d bleeds; the window is safe for good" % [passes, off, window.cuts])


func _window_smash() -> void:
	await _begin()
	var window := _big_window()
	window.rng.seed = SMASH_SEED
	body.set_physics_process(false)
	var broken := 0
	var bled := 0
	var not_light := 0
	var not_limb := 0
	var parts := {}
	for index: int in SMASH_TRIES:
		window.repair()
		body.medical.reset()
		await physics_frame
		# Carried straight through the glass, the way a vault or a mantle carries a body.
		var way := 1.0 if index % 2 == 0 else -1.0
		for stride: int in 5:
			body.global_position = _w(1.7, (-0.6 + 0.3 * float(stride)) * way, f0)
			await physics_frame
		if window.glass == KitWindow.Glass.SMASHED and not window.pane.visible and window.collision_layer == 0: broken += 1
		var wounds := _bleeding()
		if wounds.is_empty(): continue
		bled += 1
		for part: String in wounds:
			parts[part] = int(parts.get(part, 0)) + 1
			if int(wounds[part]) != 1: not_light += 1
			if not LIMBS.has(part): not_limb += 1
		if wounds.size() != 1: not_light += 1
	var rate := float(bled) / float(SMASH_TRIES)
	_check(broken == SMASH_TRIES, "going through intact glass %d times (seed %d): the pane was broken every time (%d of %d)" % [SMASH_TRIES, SMASH_SEED, broken, SMASH_TRIES])
	_check(rate >= 0.52 and rate <= 0.68, "the body bled %d times of %d: %.1f%% (rule: %.0f%%; pass between 52%% and 68%%)" % [bled, SMASH_TRIES, rate * 100.0, KitWindow.SMASH_BLEED_CHANCE * 100.0])
	_check(not_light == 0 and not_limb == 0 and bled > 0, "every one of those bleeds was a single light bleed, on an arm or a leg: %s" % JSON.stringify(parts))
	# By hand: the blow does not cut; going through what is left is the same gamble.
	window.repair()
	body.medical.reset()
	await physics_frame
	body.global_position = _w(1.7, -0.9, f0)
	await physics_frame
	var by_hand: bool = window.interact(body)
	await physics_frame
	_check(by_hand and window.glass == KitWindow.Glass.SMASHED and _bleeding().is_empty(), "smashed by hand from outside: the pane breaks and the blow itself does not cut")
	bled = 0
	for index: int in 100:
		body.medical.reset()
		var way := 1.0 if index % 2 == 0 else -1.0
		for stride: int in 5:
			body.global_position = _w(1.7, (-0.6 + 0.3 * float(stride)) * way, f0)
			await physics_frame
		if not _bleeding().is_empty(): bled += 1
	_info("going through that smashed window 100 more times, without knocking it clean: %d bleeds" % bled)
	# 300 tries is a small sample. The same dice, thrown many more times (no walking, just the rule):
	var outside := _w(1.7, -0.3, f0)
	var inside := _w(1.7, 0.3, f0)
	var before := window.cuts
	for index: int in 10000: window.body_moved(body, outside if index % 2 == 0 else inside, inside if index % 2 == 0 else outside)
	_info("the same dice over 10,000 more passes: %.1f%% bled" % (float(window.cuts - before) / 100.0))


# ---- noise -------------------------------------------------------------------------------

## Two pigeon flocks on open ground, 20 m and 45 m from the big window.
func _two_flocks(birds: BirdManager) -> void:
	var here := _big_window().global_position
	here.y = 0.0
	var pigeon: int = BirdManager.Kind.PIGEON
	birds.add_flock(pigeon, birds.add_ground_site(here + Vector3(-13.6, 0.0, -14.67).normalized() * 20.0, 1.2, [pigeon]), 6)
	birds.add_flock(pigeon, birds.add_ground_site(here + Vector3(-43.1, 0.0, 11.2).normalized() * 45.0, 1.2, [pigeon]), 6)


func _perched(flock: BirdManager.Flock) -> int:
	var total := 0
	for bird: BirdManager.Bird in flock.birds:
		if bird.state == BirdManager.State.PERCHED: total += 1
	return total


func _nearest_bird(flock: BirdManager.Flock, point: Vector3) -> Vector2:
	var span := Vector2(INF, 0.0)
	for bird: BirdManager.Bird in flock.birds:
		var gap := bird.pos.distance_to(point)
		span = Vector2(minf(span.x, gap), maxf(span.y, gap))
	return span


func _nearest_scav(point: Vector3) -> float:
	var best := INF
	for actor: CharacterBody3D in crew.members:
		if is_instance_valid(actor) and not actor.dead: best = minf(best, actor.global_position.distance_to(point))
	return best


func _crew_states() -> String:
	var parts: Array[String] = []
	for actor: CharacterBody3D in crew.members:
		if is_instance_valid(actor): parts.append("%s %s" % [actor.role, actor.AIState.keys()[actor.state]])
	return ", ".join(parts)


func _noise() -> void:
	# The crew is where the scav probe puts it, about 43 m from the window.
	await _begin(true, Vector3(0, 0.2, 20), _two_flocks)
	var window := _big_window()
	var here := window.global_position
	# The player is upstairs, out of everybody's sight: only the noise is being tested.
	await _put(1.6, 4.5, f1)
	await _step(2.0)
	var close: BirdManager.Flock = manager.flocks[0]
	var distant: BirdManager.Flock = manager.flocks[1]
	var close_gap := _nearest_bird(close, here)
	var distant_gap := _nearest_bird(distant, here)
	var settled: bool = _perched(close) == close.birds.size() and _perched(distant) == distant.birds.size()
	var scav_gap := _nearest_scav(here)
	window.smash(null)
	await _step(0.6)
	_check(settled and _perched(close) == 0, "breaking glass sends up the birds %.0f m away: all %d pigeons (%.1f to %.1f m from the window) left the ground" % [(close_gap.x + close_gap.y) * 0.5, close.birds.size(), close_gap.x, close_gap.y])
	_check(_perched(distant) == distant.birds.size(), "and not the ones %.0f m away: all %d pigeons (%.1f to %.1f m) stayed down (glass carries %.0f m)" % [(distant_gap.x + distant_gap.y) * 0.5, distant.birds.size(), distant_gap.x, distant_gap.y, KitWindow.GLASS_NOISE_RADIUS])
	await _step(3.0)
	var calm := true
	for actor: CharacterBody3D in crew.members:
		if actor.state != actor.AIState.PATROL: calm = false
	_check(not crew.on_guard() and not crew.hostile and not crew.warning_active and calm, "the scav crew, %.0f m from the window, was not put on guard: not on guard, not hostile, all still on patrol (%s)" % [scav_gap, _crew_states()])
	# The same crew does react to a real shot from the same house: the two paths are separate.
	raid.on_shot()
	await _step(1.0)
	_info("a gunshot from inside the same house, for comparison: crew hostile %s, on guard %s (%s)" % [str(crew.hostile), str(crew.on_guard()), _crew_states()])


func _noise_near_scavs() -> void:
	# A crew that starts about 17 m from the window: inside the 30 m the glass carries.
	var anchor := YardHouse.POSITION + Vector3(-15.5, 0.2, -9.0)
	await _begin(true, anchor, Callable(), true)
	var window := _big_window()
	var here := window.global_position
	await _put(1.6, 4.5, f1)
	await _step(2.0)
	var gap := _nearest_scav(here)
	var before := _crew_states()
	window.smash(null)
	await _step(1.5)
	var looking := 0
	for actor: CharacterBody3D in crew.members:
		if actor.state != actor.AIState.PATROL: looking += 1
	_check(gap < KitWindow.GLASS_NOISE_RADIUS and not crew.on_guard() and not crew.hostile, "a scav crew %.0f m from the breaking glass, close enough to hear it, does not treat it as gunfire: not on guard, not hostile" % gap)
	_check(looking > 0, "it heard it as a noise instead and went to look: before %s; 1.5 s after %s (%d of %d)" % [before, _crew_states(), looking, crew.members.size()])


# ---- the game's own player controller ----------------------------------------------------

func _real_player() -> void:
	await _begin()
	var player := RealPlayer.new()
	player.name = "RealPlayer"
	player.extraction_mode = true
	yard.add_child(player)
	player.global_position = _w(4.18, -3.0, 0.1)
	body.global_position = _w(4.18, -12.0, 0.05) # the scripted body waits out in the yard
	await physics_frame
	await physics_frame
	await _drive(player, [Vector2(4.18, -1.8)])
	var front: KitDoor = house.door("front")
	var used: bool = front.interact(player)
	await _settle(player, 1.2)
	await _drive(player, [Vector2(4.18, -0.6), Vector2(4.18, 1.3)])
	var at := _at(player)
	_check(used and front.opened and at.z > 0.15 and _near(at.y, f0, 0.06), "the game's own player controller (player.gd, %.2f m/s walk, %.2f m wide): opened the front door and walked in, to %.2f m inside" % [player.walk_speed, player.body_capsule.radius * 2.0, at.z - 0.15])
	await _drive(player, [Vector2(4.3, 1.67)])
	used = house.door("living").interact(player)
	await _settle(player, 1.2)
	await _drive(player, [Vector2(2.6, 1.67), Vector2(1.6, 3.0)])
	at = _at(player)
	_check(used and at.x < 3.14 and _near(at.y, f0, 0.06), "it reached the living room, at (%.1f, %.1f)" % [at.x, at.z])
	await _drive(player, [Vector2(2.6, 1.67), Vector2(4.3, 1.67), Vector2(3.66, 1.85)])
	var from := clock
	var up: bool = await _drive(player, [Vector2(3.66, 5.9)])
	var took := clock - from
	at = _at(player)
	_check(up and _near(at.y, f1, 0.06) and player.is_on_floor(), "it climbed the stair to the upper floor: %.2f m above the ground (floor at %.2f m), in %.1f s; its limits are a %.0f degree slope and a %.2f m step, the stair asks %.1f degrees" % [at.y, f1, took, rad_to_deg(player.floor_max_angle), player.STEP_HEIGHT, float(house.stair.slope_degrees)])
	await _drive(player, [Vector2(4.65, 5.9), Vector2(4.65, 1.67)])
	used = house.door("bedroom").interact(player)
	await _settle(player, 1.2)
	await _drive(player, [Vector2(2.6, 1.67), Vector2(1.6, 3.2)])
	at = _at(player)
	_check(used and at.x < 3.14 and _near(at.y, f1, 0.06), "it walked round the landing into the bedroom upstairs, at (%.1f, %.1f)" % [at.x, at.z])
	await _drive(player, [Vector2(2.6, 1.67), Vector2(4.65, 1.67), Vector2(4.65, 5.9), Vector2(3.66, 5.9)])
	var down: bool = await _drive(player, [Vector2(3.66, 1.85), Vector2(4.18, 1.3), Vector2(4.18, -0.6), Vector2(4.18, -3.0)])
	at = _at(player)
	_check(down and at.z < -2.5 and _near(at.y, 0.0, 0.06), "it came back down the stair and out of the front door to the street")
	# The big window, with the real medical record.
	var window := _big_window()
	await _drive(player, [Vector2(1.7, -3.0), Vector2(1.7, -1.9)])
	await _drive(player, [Vector2(1.7, 1.5)], 3.0)
	at = _at(player)
	_check(at.z < 0.075 and window.glass == KitWindow.Glass.INTACT, "the intact window stops it too (%.2f m outside the glass)" % (0.075 - at.z))
	await _drive(player, [Vector2(1.7, -1.9)])
	window.receive_bullet_hit(30.0, player, window.global_position, window.global_basis.z)
	await _settle(player, 0.2)
	await _drive(player, [Vector2(1.7, 1.6)])
	var clean: bool = player.medical.summary() == "HEALTHY" and window.passes == 1
	await _drive(player, [Vector2(2.03, 1.6), Vector2(2.03, -1.8)])
	var wounds := {}
	for part: String in player.medical.PARTS:
		if int(player.medical.bleeding[part]) > 0: wounds[part] = int(player.medical.bleeding[part])
	_check(clean and window.passes == 2 and wounds.size() == 1 and int(wounds.values()[0]) == 1 and LIMBS.has(str(wounds.keys()[0])), "through the shot-out window: in by the middle with no bleed, out 0.33 m off the middle and its own medical record now reads \"%s\" %s" % [player.medical.summary(), JSON.stringify(wounds)])
	# What the player cannot do yet.
	var waist: KitWindow = house.window("west_living")
	waist.receive_bullet_hit(30.0, player, waist.global_position, waist.global_basis.z)
	waist.knock_out(null)
	player.global_position = _w(-0.75, 4.1, 0.0)
	await _settle(player, 0.4)
	var inward: Vector3 = house.global_basis * Vector3.RIGHT
	player.rotation.y = atan2(-inward.x, -inward.z)
	player.stamina = player.max_stamina
	var climbed: bool = player._try_start_mantle(inward)
	_info("a waist-high window, glass knocked clean, player standing at it: the existing mantle %s (it wants a ledge to stand on and standing headroom above it; a climb-through-a-window move is not built)" % ("started" if climbed else "does not start"))
	player.queue_free()


## Walks the real player controller through the points: face the next one, walk, stop there.
func _drive(player: CharacterBody3D, points: Array, limit: float = 12.0) -> bool:
	for point: Vector2 in points:
		var goal := _w(point.x, point.y)
		var ticks := 0
		while true:
			var offset := Vector3(goal.x - player.global_position.x, 0.0, goal.z - player.global_position.z)
			if offset.length() < 0.15: break
			player.rotation.y = atan2(-offset.x, -offset.z)
			player._advance_ground_movement(DT, Vector2(0, -1), false, false, false)
			await physics_frame
			clock += DT
			ticks += 1
			if ticks > int(limit / DT):
				await _settle(player, 0.3)
				return false
		await _settle(player, 0.25)
	return true


func _settle(player: CharacterBody3D, seconds: float) -> void:
	for tick: int in int(round(seconds / DT)):
		player._advance_ground_movement(DT, Vector2.ZERO, false, false, false)
		await physics_frame
		clock += DT


# ---- what is drawn -----------------------------------------------------------------------

func _triangles(node: Node) -> int:
	var mesh: Mesh = (node as MeshInstance3D).mesh if node is MeshInstance3D else null
	return mesh.surface_get_array_index_len(0) / 3 if mesh != null and mesh.get_surface_count() > 0 else 0


## The same house with its meshes built (the other scenarios run without them): the broken
## glass is really there to be seen, and it is where it should be.
func _drawn() -> void:
	drawn = true
	await _begin()
	drawn = false
	var window := _big_window()
	await _put(1.7, -2.2, 0.0)
	_check(window.pane.mesh != null and window.pane.visible and window.get_node_or_null("ShardsInFrame") == null, "whole window: one pane is drawn, and no broken glass exists yet")
	_shoot_window(window)
	await _step(0.1)
	var ring := window.get_node_or_null("ShardsInFrame") as MeshInstance3D
	var litter := window.get_node_or_null("GlassOnFloor") as MeshInstance3D
	_check(not window.pane.visible and ring != null and _triangles(ring) >= window.shard_count, "after the shot the pane is not drawn and the shards in the frame are: %d shards, %d triangles" % [window.shard_count, _triangles(ring)])
	var ring_box: AABB = ring.mesh.get_aabb() if ring != null else AABB()
	var half := Vector2(window.dimensions.x, window.dimensions.y) * 0.5
	var inside_frame: bool = ring_box.position.x >= -half.x - 0.001 and ring_box.end.x <= half.x + 0.001 and ring_box.position.y >= -half.y - 0.001 and ring_box.end.y <= half.y + 0.001 and absf(ring_box.size.z) < 0.001
	_check(inside_frame, "the shards sit in the plane of the pane and inside its frame (they span %.2f by %.2f m; the pane was %.2f by %.2f m)" % [ring_box.size.x, ring_box.size.y, window.dimensions.x, window.dimensions.y])
	var floor_box: AABB = litter.mesh.get_aabb() if litter != null else AABB()
	var low: float = house.to_local(window.to_global(floor_box.position)).y
	var high: float = house.to_local(window.to_global(floor_box.end)).y
	var depth_in: float = floor_box.position.z
	_check(litter != null and _triangles(litter) >= window.floor_pieces and low > f0 and high < f0 + 0.01 and depth_in > 0.0, "the pieces on the floor are drawn too: %d pieces lying flat on the living-room floor (%.3f m above it), from %.2f to %.2f m inside the wall" % [window.floor_pieces, low - f0, depth_in, floor_box.end.z])
	window.knock_out(body)
	await _step(0.1)
	var more := 0
	for child: Node in window.get_children():
		if str(child.name).begins_with("GlassOnFloor"): more += 1
	_check(window.get_node_or_null("ShardsInFrame") == null and more == 2, "knocked clean: the shards in the frame are gone and what fell is on the floor (%d pieces in all)" % window.floor_pieces)
	var front: KitDoor = house.door("front")
	var leaf_mesh := front.leaf.get_node_or_null("Leaf")
	_check(leaf_mesh != null and _triangles(leaf_mesh) == front.triangles and house.get_node_or_null("ShellMesh") != null, "each door leaf is drawn as one mesh (%d triangles) and the rest of the house as one (%d triangles)" % [front.triangles, _triangles(house.get_node_or_null("ShellMesh"))])


# ---- it is a kit -------------------------------------------------------------------------

func _other_house() -> void:
	# No yard here: the house stands on its own slab, away from everything.
	var other: Node3D = HouseKit.build(OTHER_SPEC, false)
	other.position = Vector3(0.0, 0.0, 300.0)
	root.add_child(other)
	var g0: float = other.floor_heights[0]
	var g1: float = other.floor_heights[1]
	var walker := Body.new()
	root.add_child(walker)
	walker.global_position = other.to_global(Vector3(8.0, g0 + 0.02, 2.0))
	await _step(0.3)
	var route := PackedVector3Array()
	for point: Vector2 in [Vector2(7.75, 0.55), Vector2(3.8, 0.55), Vector2(3.8, 2.0), Vector2(6.5, 2.0)]: route.append(other.to_global(Vector3(point.x, 0.0, point.y)))
	walker.follow(route, 1.6)
	var arrived: bool = await _step(40.0, func() -> bool: return walker.arrived())
	var at: Vector3 = other.to_local(walker.global_position)
	var size: Vector2 = OTHER_SPEC.size
	_check(arrived and _near(at.y, g1, 0.03) and at.x > 6.0, "a second house from a different description (%.1f by %.1f m, the stair along the front wall and climbing the other way, %d doors, %d windows) built in %.1f ms; the player walked from its hall up its stair and along its landing, to (%.1f, %.1f), %.2f m up" % [size.x, size.y, int(other.stats.doors), int(other.stats.windows), float(other.stats.build_usec) / 1000.0, at.x, at.z, at.y])
	var locked: KitDoor = other.door("up_right")
	_check(locked.locked and other.window("front").glass == KitWindow.Glass.INTACT, "its locked door and its windows are the same kit parts (locked: %s)" % str(locked.locked))
	var flat: Dictionary = OTHER_SPEC.duplicate(true)
	flat.id = "Bungalow"
	flat.floors = 1
	var bungalow: Node3D = HouseKit.build(flat, true)
	_check(bungalow.floor_heights.size() == 1 and bungalow.stair.is_empty() and bungalow.doors.size() == 3 and bungalow.windows.size() == 2, "the same description with one floor builds a bungalow: no stair, %d doors, %d windows, %d nodes, %d triangles" % [bungalow.doors.size(), bungalow.windows.size(), int(bungalow.stats.nodes), int(bungalow.stats.triangles)])
	bungalow.free()
	walker.queue_free()
	other.queue_free()
	await process_frame
	# The map is 2 km across and its houses stand at every angle. A stair must still be
	# climbable far from the world's origin and turned any way (the first version of the ramp
	# jammed the body at the top step, 300 m out).
	var climbed := 0
	var worst := 0.0
	var places: Array = [[Vector3(1203.7, 0.0, -871.3), 0.613], [Vector3(-640.2, 0.0, 1510.9), 2.417], [Vector3(97.3, 0.0, -44.1), -1.9], [Vector3(-2011.5, 0.0, -1987.25), 4.02], [Vector3(15.0, 0.0, 300.0), PI * 0.5]]
	var dice := RandomNumberGenerator.new()
	dice.seed = SMASH_SEED
	for index: int in 7: places.append([Vector3(dice.randf_range(-2000.0, 2000.0), 0.0, dice.randf_range(-2000.0, 2000.0)), dice.randf() * TAU])
	for place: Array in places:
		var house_there: Node3D = HouseKit.build(YardHouse.SPEC, false)
		house_there.position = place[0]
		house_there.rotation.y = place[1]
		root.add_child(house_there)
		var climber := Body.new()
		root.add_child(climber)
		climber.global_position = house_there.to_global(Vector3(4.3, g0 + 0.02, 1.6))
		await _step(0.3)
		var way := PackedVector3Array()
		for point: Vector2 in [Vector2(3.66, 1.85), Vector2(3.66, 5.9), Vector2(4.65, 5.9), Vector2(4.65, 2.0), Vector2(4.65, 5.9), Vector2(3.66, 5.9), Vector2(3.66, 1.85)]: way.append(house_there.to_global(Vector3(point.x, 0.0, point.y)))
		climber.follow(way, 1.6)
		var m := {"top": 0.0}
		var back: bool = await _step(60.0, func() -> bool:
			m.top = maxf(float(m.top), house_there.to_local(climber.global_position).y)
			return climber.arrived())
		var ended: Vector3 = house_there.to_local(climber.global_position)
		if back and _near(float(m.top), g1, 0.03) and _near(ended.y, g0, 0.03): climbed += 1
		else: _info("at %s turned %.2f rad the body ended at (%.2f, %.2f), %.2f m up, after reaching %.2f m" % [str(place[0]), float(place[1]), ended.x, ended.z, ended.y, float(m.top)])
		worst = maxf(worst, Vector2(place[0].x, place[0].z).length())
		climber.queue_free()
		house_there.queue_free()
		await process_frame
	_check(climbed == places.size(), "the yard house built at %d other places, up to %.0f m from the world's origin and each turned to a different angle: the stair was climbed to the top and walked back down at %d of %d" % [places.size(), worst, climbed, places.size()])


# ---- cost --------------------------------------------------------------------------------

func _cost() -> void:
	# Five houses built on their own, as they would be drawn (meshes and all).
	var total := 0
	var stats := {}
	for index: int in 5:
		var one: Node3D = HouseKit.build(YardHouse.SPEC, true)
		total += int(one.stats.build_usec)
		stats = one.stats
		one.free()
	_info("one house, %d doors and %d windows: %d nodes, %d physics bodies with %d collision shapes, %d meshes (= draw calls with everything whole), %d triangles (shell %d, doors %d, panes %d), %d scripts" % [int(stats.doors), int(stats.windows), int(stats.nodes), int(stats.bodies), int(stats.collision_shapes), int(stats.meshes), int(stats.triangles), int(stats.shell_triangles), int(stats.door_triangles), int(stats.pane_triangles), int(stats.scripts)])
	_info("building it takes %.1f ms (average of 5, headless, one core)" % (float(total) / 5000.0))
	_check(int(stats.meshes) == 1 + int(stats.doors) + int(stats.windows), "the whole fixed house is one mesh; each door leaf and each pane is one more (%d meshes in all)" % int(stats.meshes))
	await _begin()
	var window := _big_window()
	window.receive_bullet_hit(30.0, null, window.global_position, window.global_basis.z)
	await _step(0.1)
	_info("a shot-out window adds 2 meshes (the shards in the frame, the pieces on the floor): %d shards, %d floor pieces" % [window.shard_count, window.floor_pieces])
	# The only thing that ticks: the house watching nearby bodies for its windows.
	body.set_physics_process(false)
	body.global_position = _w(4.18, -60.0, 0.05)
	await _step(0.2)
	var started := Time.get_ticks_usec()
	for index: int in 20000: house._physics_process(DT)
	var far := float(Time.get_ticks_usec() - started) / 20000.0
	body.global_position = _w(2.0, 3.0, f0)
	await _step(0.2)
	started = Time.get_ticks_usec()
	for index: int in 20000:
		body.global_position.x += 0.0001
		house._physics_process(DT)
	var near := float(Time.get_ticks_usec() - started) / 20000.0
	_info("the house's tick: %.2f microseconds with nobody near, %.2f with a body moving about inside (a 60 fps frame is 16,667); doors tick only while they swing" % [far, near])
