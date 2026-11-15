extends SceneTree
## Proves the Map 1 world (scripts/map1/map1_world.gd): real kit houses in place of the grey
## boxes of the low open buildings, and the robot recharge stations. Headless:
##   godot --headless --path . --fixed-fps 60 --script res://tests/probe_map1_world.gd
##   ... -- --only=counts,street          runs just those scenarios
## One WORLD_PASS or WORLD_FAIL line per check, with the measured numbers; WORLD_INFO lines
## are measurements with no pass mark. Ends with WORLD_DONE passed=N failed=N.
##
## The player is the game's own controller (scripts/player.gd), cut down as tests/
## probe_house.gd does it. The world sees through that player's camera.
##
## "Seen" is checked here apart from the world's own test: every time a box becomes a house
## or a house a box, this probe looks at the building from the camera with far more rays
## than the world uses (a 5 by 5 grid on every wall and the roof, and the shadow), and only
## at points inside the camera's real frustum.

const Blockout := preload("res://scripts/map1/map1_blockout.gd")
const World := preload("res://scripts/map1/map1_world.gd")
const HouseRules := preload("res://scripts/map1/map1_house_rules.gd")
const HouseKit := preload("res://scripts/interior_kit/house_kit.gd")
const Dress := preload("res://scripts/map1/map1_house_dress.gd")
const DT := 1.0 / 60.0
const BOX := World.Level.BOX
const LOOK := World.Level.LOOK
const FULL := World.Level.FULL
## The house street the brief names: it runs east along z = 447 to a turning circle at x = 155.
const STREET_Z := 447.0
const CIRCLE := Vector3(155.0, 0.0, 448.0)


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


var map: Node3D
var world: Node3D
var player: CharacterBody3D
var camera: Camera3D
var only: PackedStringArray = []
var passed := 0
var failed := 0
var clock := 0.0
var _label := ""
## What the probe saw happen, gathered from the world's `changing` signal and once a frame.
var seen := {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=").split(",")
	_run.call_deferred()


func _run() -> void:
	var started := Time.get_ticks_msec()
	map = Blockout.new()
	map.name = "Map1Blockout"
	map.with_player = false
	root.add_child(map)
	world = map.world
	player = RealPlayer.new()
	player.name = "ProbePlayer"
	player.extraction_mode = true
	map.add_child(player)
	camera = player.camera
	camera.far = 20000.0
	player.global_position = map.on_ground(93.0, 416.0, 0.1)
	world.set_viewer(camera, player)
	world.changing.connect(_on_changing)
	process_frame.connect(_each_frame)
	_reset_seen()
	print("WORLD_INFO setup: the blockout with its world built in %d ms (%d boxes, %d low open buildings, %d stations)" % [Time.get_ticks_msec() - started, (map.data.boxes as Array).size(), world.candidates.size(), world.stations.size()])
	var scenarios := {
		"counts": _counts, "match": _match, "variety": _variety, "locked": _locked,
		"street": _street, "long_walk": _long_walk, "enter": _enter, "plans": _plans,
		"shut_tall": _shut_tall, "stations": _stations, "rooftop": _rooftop, "same_picture": _same_picture,
		"flight": _flight, "japanese": _japanese, "neighbours": _neighbours, "businesses": _businesses, "kinds": _kinds, "cuts": _cuts,
	}
	for label: String in scenarios:
		if not only.is_empty() and not only.has(label): continue
		_label = label
		print("WORLD_BEGIN ", label)
		await scenarios[label].call()
	print("WORLD_DONE passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("%s %s: %s" % ["WORLD_PASS" if ok else "WORLD_FAIL", _label, text])


func _info(text: String) -> void:
	print("WORLD_INFO %s: %s" % [_label, text])


# ---- watching ----------------------------------------------------------------------------

func _reset_seen() -> void:
	seen = {"swaps": 0, "seen_swaps": 0, "seen_notes": [], "by_why": {}, "from_height": 0, "height_wrong": 0, "same_picture": 0,
		"under_feet": 0, "touched_back": 0, "max_full": 0, "max_look": 0, "grey_seen_frames": 0, "grey_seen_nearest": INF,
		"nearest_swap": INF, "far": 0, "far_wrong": 0, "far_nearest": INF, "grey_not_ready": 0, "door_gap": INF, "fulls_while_fast": 0, "watch_grey": false, "watch_radius": 150.0}
	world.stats.worst_usec = 0
	world.stats.worst_what = ""
	world.stats.frames = 0
	world.stats.work_usec = 0
	world.stats.worst_look_usec = 0
	world.stats.worst_plan_usec = 0
	world.stats.worst_full_usec = 0
	world.stats.worst_refresh_usec = 0


func _eye() -> Vector3:
	return camera.global_position


func _above_ground() -> float:
	return _eye().y - map.ground_height(_eye().x, _eye().z)


func _on_changing(index: int, from: int, to: int, why: int) -> void:
	var label: String = World.Why.keys()[why]
	seen.by_why[label] = int(seen.by_why.get(label, 0)) + 1
	if from == FULL:
		if world.outline_gap(index, player.global_position) <= 0.5: seen.under_feet += 1
		if why == World.Why.SAME_PICTURE and not world._untouched(index): seen.touched_back += 1
	if to == FULL and world.fast: seen.fulls_while_fast += 1
	if from != BOX and to != BOX:
		seen.same_picture += 1
		return
	if why == World.Why.CUT: return
	seen.swaps += 1
	var gap: float = world.centre_of(index).distance_to(_eye())
	seen.nearest_swap = minf(float(seen.nearest_swap), gap)
	if why == World.Why.FAR:
		# In open view, but further off than the eye tells a box from a house.
		seen.far += 1
		seen.far_nearest = minf(float(seen.far_nearest), Vector2(float(map.data.boxes[index][0]) - _eye().x, float(map.data.boxes[index][2]) - _eye().z).length())
		if float(seen.far_nearest) < World.FAR_SWAP - 0.01: seen.far_wrong += 1
		return
	if why == World.Why.FROM_HEIGHT:
		seen.from_height += 1
		if _above_ground() < World.HIGH_EYE or gap < World.HIGH_FAR: seen.height_wrong += 1
		return
	var sight := _sight_lines(index)
	if sight > 0:
		seen.seen_swaps += 1
		if (seen.seen_notes as Array).size() < 6:
			# (When, where in the view, and how the two sight tests compare, for whoever reads it.)
			var since := Engine.get_physics_frames() - int(seen.get("cut_end_frame", Engine.get_physics_frames()))
			var to_it: Vector3 = world.centre_of(index) - _eye()
			var off_centre := rad_to_deg((-camera.global_transform.basis.z).angle_to(to_it))
			(seen.seen_notes as Array).append("box %d at %.0f m, %s, %d open sight lines, said %s, %d frames after the cut ended, %.0f degrees off the view's centre, the world's own test uses %d points; open: %s" % [index, gap, "to a house" if from == BOX else "to a box", sight, label, since, off_centre, world.look_points(index).size(), " | ".join(_open_notes)])


## Which points the last _sight_lines call found open (up to six), for a failure's note.
var _open_notes: PackedStringArray = []

## How many of this probe's own points on a building the camera has a clear line to.
func _sight_lines(index: int) -> int:
	var box: Array = map.data.boxes[index]
	var turn := Basis(Vector3.UP, deg_to_rad(float(box[6])))
	var half := Vector3(float(box[3]) * 0.5 + 0.5, 0.0, float(box[5]) * 0.5 + 0.5)
	var middle := Vector3(float(box[0]), 0.0, float(box[2]))
	var base: float = map.ground_height(middle.x, middle.z) + 0.2
	var top := float(box[1]) + float(box[4])
	var points := PackedVector3Array()
	for i: int in range(5):
		var s := float(i) / 4.0 * 2.0 - 1.0
		for j: int in range(5):
			var t := float(j) / 4.0
			var y := lerpf(base, top, t)
			points.append(middle + turn * Vector3(s * half.x, 0.0, -half.z) + Vector3.UP * y)
			points.append(middle + turn * Vector3(s * half.x, 0.0, half.z) + Vector3.UP * y)
			points.append(middle + turn * Vector3(-half.x, 0.0, s * half.z) + Vector3.UP * y)
			points.append(middle + turn * Vector3(half.x, 0.0, s * half.z) + Vector3.UP * y)
			var u := float(j) / 4.0 * 2.0 - 1.0
			points.append(middle + turn * Vector3(s * half.x, 0.0, u * half.z) + Vector3.UP * (top + 0.05))
	# The shadow of the roof on the ground.
	for i: int in range(3):
		for j: int in range(3):
			var on_roof: Vector3 = middle + turn * Vector3((float(i) - 1.0) * half.x, 0.0, (float(j) - 1.0) * half.z)
			var fallen: Vector3 = on_roof + world._shadow * (top - map.ground_height(on_roof.x, on_roof.z))
			points.append(Vector3(fallen.x, map.ground_height(fallen.x, fallen.z) + 0.15, fallen.z))
	var space := root.get_world_3d().direct_space_state
	var eye := _eye()
	var open := 0
	_open_notes.clear()
	for n: int in points.size():
		var point := points[n]
		if not camera.is_position_in_frustum(point): continue
		var query := PhysicsRayQueryParameters3D.create(eye, point, 1, [player.get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty() or (hit.position as Vector3).distance_to(point) < 0.9 or world.outline_gap(index, hit.position) < 1.6 or not world.hides(hit, eye):
			open += 1
			# (Which of the probe's points it was and why the line counts as open, for a failure's note.)
			if _open_notes.size() < 6:
				var what := "the roof's shadow, point %d of 9" % (n - 125 + 1)
				if n < 125:
					var across := (n / 25) * 0.25
					var up := ((n / 5) % 5) * 0.25
					what = ["the -z wall", "the +z wall", "the -x wall", "the +x wall", "the roof"][n % 5] + " (%.2f across, %.2f %s)" % [across, up, "up" if n % 5 < 4 else "deep"]
				var how := "nothing struck" if hit.is_empty() else ("struck the building itself" if (hit.position as Vector3).distance_to(point) < 0.9 or world.outline_gap(index, hit.position) < 1.6 else "struck something that does not hide: %s, %.0f m from the eye" % [str((hit.collider as Node).get_path()) if hit.collider is Node else str(hit.collider), eye.distance_to(hit.position)])
				_open_notes.append("%s at (%.1f, %.1f, %.1f): %s" % [what, point.x, point.y, point.z, how])
	return open


func _each_frame() -> void:
	if world == null: return
	seen.max_full = maxi(int(seen.max_full), world.houses.size())
	seen.max_look = maxi(int(seen.max_look), world.looks.size())
	if not bool(seen.watch_grey) or world.covered or world.fade >= 0.999: return
	# A grey box of a low open building, in view, within the watched distance?
	var eye := _eye()
	for index: int in world.candidates:
		if world.level_of(index) != BOX: continue
		var gap: float = Vector2(float(map.data.boxes[index][0]) - eye.x, float(map.data.boxes[index][2]) - eye.z).length()
		if gap > float(seen.watch_radius): continue
		if not bool(world.site(index).ok): continue
		if _sight_lines(index) > 0:
			if not world.looks.has(index): seen.grey_not_ready += 1
			seen.grey_seen_frames += 1
			seen.grey_seen_nearest = minf(float(seen.grey_seen_nearest), gap)
			return


# ---- moving the player -------------------------------------------------------------------

func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame
		clock += DT


## Puts the player somewhere else (a cut) and lets the world settle.
func _put(at: Vector3, facing: Vector3 = Vector3.ZERO) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	if facing != Vector3.ZERO: _face(facing)
	world.cut()
	await _frames(2)
	# The picture is black while the first houses are made: wait for it to be shown again.
	var waited := 0
	while world.covered and waited < 1200:
		await physics_frame
		waited += 1
	seen.cover_frames = maxi(int(seen.get("cover_frames", 0)), int(world.stats.cut_frames))
	seen.cover_worst = maxi(int(seen.get("cover_worst", 0)), int(world.stats.cut_worst_usec))
	await _frames(4)


func _face(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length() > 0.001: player.rotation.y = atan2(-direction.x, -direction.z)


## Walks the real player controller through world points (x, z); the ground gives the height.
func _drive(points: Array, sprint: bool = false, limit: float = 60.0) -> bool:
	for goal: Vector3 in points:
		var ticks := 0
		while true:
			var offset := Vector3(goal.x - player.global_position.x, 0.0, goal.z - player.global_position.z)
			if offset.length() < 0.15: break
			_face(offset)
			player._advance_ground_movement(DT, Vector2(0, -1), sprint, false, false)
			await physics_frame
			clock += DT
			ticks += 1
			if ticks > int(limit / DT):
				await _settle(0.3)
				_info("the player did not get to (%.1f, %.1f): stopped at (%.1f, %.1f, height %.2f)" % [goal.x, goal.z, player.global_position.x, player.global_position.z, player.global_position.y])
				return false
		await _settle(0.2)
	return true


func _settle(seconds: float) -> void:
	for tick: int in int(round(seconds / DT)):
		player._advance_ground_movement(DT, Vector2.ZERO, false, false, false)
		await physics_frame
		clock += DT


## Carries the player along a straight line at a speed, as flying does (no collision).
func _glide(to: Vector3, speed: float, look: Vector3 = Vector3.ZERO) -> void:
	var from := player.global_position
	var steps := maxi(1, ceili(from.distance_to(to) / (speed * DT)))
	_face(look if look != Vector3.ZERO else to - from)
	for step: int in range(1, steps + 1):
		player.global_position = from.lerp(to, float(step) / float(steps))
		await physics_frame
		clock += DT


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _box_at(index: int) -> Vector3:
	return Vector3(float(map.data.boxes[index][0]), 0.0, float(map.data.boxes[index][2]))


## The low open buildings a house can be made of, nearest first to a point.
func _makeable_near(point: Vector3, radius: float) -> Array[int]:
	var found: Array[Vector2] = []
	for index: int in world.candidates:
		var gap := _flat(_box_at(index), point)
		if gap <= radius and bool(world.site(index).ok): found.append(Vector2(gap, index))
	found.sort()
	var output: Array[int] = []
	for entry: Vector2 in found: output.append(int(entry.y))
	return output


# ---- how many, and why not ---------------------------------------------------------------

func _counts() -> void:
	var started := Time.get_ticks_msec()
	var can := 0
	var reasons := {}
	var plans := {}
	var floors := {1: 0, 2: 0}
	var lowered := 0
	var on_road := 0
	var with_drop := 0
	for index: int in world.candidates:
		var site: Dictionary = world.site(index)
		if bool(site.ok):
			can += 1
			plans[site.plan] = int(plans.get(site.plan, 0)) + 1
			floors[int(site.floors)] += 1
			if bool(site.one_floor_because_low): lowered += 1
			if bool(site.on_road): on_road += 1
			if float(site.door_drop) > 0.0: with_drop += 1
		else:
			var why := str(site.reason).get_slice(":", 0).get_slice(" (", 0)
			if why.begins_with("the ground falls"): why = "the ground falls too far at the door"
			if why.begins_with("a neighbour stands"): why = "a neighbour stands too close in front of the door"
			reasons[why] = int(reasons.get(why, 0)) + 1
	var total: int = world.candidates.size()
	var took := Time.get_ticks_msec() - started
	_check(total > 2000 and total < 2400, "low open town buildings (house, timber house, shop-house, one or two floors, not shut): %d" % total)
	_check(can + _sum(reasons) == total and can > total * 0.8, "a real house can be made of %d of them (%.1f%%); %d cannot" % [can, 100.0 * can / total, total - can])
	for why: String in reasons: _info("cannot, %d: %s" % [int(reasons[why]), why])
	_info("of the %d: %d have two floors and a stair, %d have one floor (%d of those are boxes the plan counts as two floors but which stand too low above their ground for two); plans %s" % [can, floors[2], floors[1], lowered, JSON.stringify(plans)])
	_info("%d face a road in the ground picture, %d face the most open side (no road within %.0f m); %d stand on a slope and have steps down from the door" % [on_road, can - on_road, HouseRules.REACH, with_drop])
	_info("working all %d plans out took %d ms (%.2f ms each; in play they are worked out one at a time, as the player comes near)" % [total, took, float(took) / total])


func _sum(counts: Dictionary) -> int:
	var total := 0
	for key: Variant in counts: total += int(counts[key])
	return total


# ---- every house matches its box ---------------------------------------------------------

func _match() -> void:
	var checked := 0
	var worst := {"place": 0.0, "size": 0.0, "turn": 0.0, "height": 0.0, "base": 0.0, "step": 0.0, "sunk": 0.0}
	var floor_under := 0
	var door_blocked := 0
	var bad_door_side := 0
	for index: int in world.candidates:
		var site: Dictionary = world.site(index)
		if not bool(site.ok): continue
		checked += 1
		var box: Array = map.data.boxes[index]
		var frame: Transform3D = site.frame
		var size: Vector2 = site.size
		var spec: Dictionary = site.spec
		# Place: the middle of the house's outline against the middle of the box.
		var middle: Vector3 = frame * Vector3(size.x * 0.5, 0.0, size.y * 0.5)
		worst.place = maxf(float(worst.place), _flat(middle, _box_at(index)))
		# Outline: the same two lengths, the same way round or a quarter turn.
		var quarter := int(site.side) % 2 == 1
		var want := Vector2(float(box[5]), float(box[3])) if quarter else Vector2(float(box[3]), float(box[5]))
		worst.size = maxf(float(worst.size), maxf(absf(size.x - want.x), absf(size.y - want.y)))
		# Turn: the house's walls run along the box's walls.
		var off := fposmod(rad_to_deg(frame.basis.get_euler().y) - float(box[6]), 90.0)
		worst.turn = maxf(float(worst.turn), minf(off, 90.0 - off))
		# Height: the ridge is the box's top. Base: the footing ends where the box does.
		worst.height = maxf(float(worst.height), absf(float(site.ridge) - (float(box[1]) + float(box[4]))))
		worst.base = maxf(float(worst.base), absf((frame.origin.y - float(spec.foundation)) - float(box[1])))
		# The floor is not under the ground anywhere beneath the house.
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(0.5, 0.5)]:
			var at: Vector3 = frame * Vector3(size.x * corner.x, 0.0, size.y * corner.y)
			if map.ground_height(at.x, at.z) > frame.origin.y + 0.001: floor_under += 1
		# The doorstep meets the ground at its outer edge.
		var step: Dictionary = spec.steps[0]
		var edge: Vector3 = frame * Vector3(float(step.at), 0.0, -float(step.depth))
		# (A low slab at a genkan door reaches `under` below the house's own ground.)
		var step_gap: float = (frame.origin.y - float(step.get("drop", 0.0)) - float(step.get("under", 0.0))) - map.ground_height(edge.x, edge.z)
		if step_gap > float(worst.step): worst["step_note"] = "box %d drop %.2f depth %.2f gap %+.3f open %.2f" % [index, float(step.get("drop", 0.0)), float(step.depth), step_gap, float(site.door_clear)]
		worst.step = maxf(float(worst.step), step_gap)
		worst.sunk = maxf(float(worst.sunk), -step_gap)
		# The way to the door is open: walk straight out from it, as far as the step and a stride.
		var out: Vector3 = -frame.basis.z
		var door: Vector3 = frame * Vector3(float(step.at), 0.0, 0.0)
		var reach := 0.3
		while reach <= float(step.depth) + 0.3:
			var p := door + out * reach
			if world.solid_at(p.x, p.z, index):
				door_blocked += 1
				break
			reach += 0.25
		# ("entry" is the wall at the back of a porch cut into the front: it faces the same way.)
		if not str(spec.doors[0].wall) in ["front", "entry"] or not bool(spec.doors[0].get("front", false)) or (str(spec.doors[0].wall) == "entry") != spec.has("recess"): bad_door_side += 1
	_check(checked > 0 and float(worst.place) <= 0.01 and float(worst.size) <= 0.01 and float(worst.turn) <= 0.01, "all %d houses stand on their box: the worst is %.3f m off its middle, %.3f m off its width or depth, %.3f degrees off its walls" % [checked, float(worst.place), float(worst.size), float(worst.turn)])
	_check(float(worst.height) <= 0.02 and float(worst.base) <= 0.01, "and are as tall: the worst ridge is %.3f m from its box's top, the worst footing %.3f m from its box's base" % [float(worst.height), float(worst.base)])
	_check(floor_under == 0 and float(worst.step) <= 0.05 and float(worst.sunk) <= 0.3, "the ground floor is never under the ground (%d corners found under it); the doorstep meets the ground: at the worst house its outer edge is %.2f m above the ground, and at the worst the other way %.2f m sunk into ground that rises again" % [floor_under, float(worst.step), float(worst.sunk)])
	_check(door_blocked == 0 and bad_door_side == 0, "every front door is in the wall facing the street side and opens onto clear ground: %d doors with a neighbour inside the doorstep" % door_blocked)
	# And built: the kit's own measure of what it made, for a spread of them.
	var built := 0
	var wrong := 0
	var index_step := maxi(1, world.candidates.size() / 40)
	for n: int in range(0, world.candidates.size(), index_step):
		var index: int = world.candidates[n]
		var site: Dictionary = world.site(index)
		if not bool(site.ok): continue
		var house: Node3D = HouseKit.build(site.spec, false)
		built += 1
		var top: float = float(site.frame.origin.y) + house.bounds.end.y - 0.18
		var box: Array = map.data.boxes[index]
		if absf(top - (float(box[1]) + float(box[4]))) > 0.03 or house.floor_heights.size() != int(site.floors) or house.doors.size() != (site.spec.doors as Array).size() or house.windows.size() != (site.spec.windows as Array).size(): wrong += 1
		house.free()
	_check(built >= 30 and wrong == 0, "%d of them built by the kit: every one came out with its floors, all its doors and windows, and its roof at the box's top (%d wrong)" % [built, wrong])


# ---- no two the same ---------------------------------------------------------------------

func _variety() -> void:
	var near := _makeable_near(CIRCLE, 80.0)
	var twenty: Array[int] = near.slice(0, 20)
	var texts := {}
	var looks := {}
	for index: int in twenty:
		var spec: Dictionary = world.site(index).spec
		texts[HouseRules.signature(spec)] = true
		# What tells them apart from the street, sizes left out: the plan, the stair, how many
		# rooms and windows, where the door is to the nearest half metre, the paint.
		var stair: Dictionary = spec.get("stair", {})
		looks["%s|%s|%d|%d|%.1f|%s|%s|%s" % [str(world.site(index).plan), str(stair.get("dir", "none")), int(world.site(index).rooms), (spec.windows as Array).size(), snappedf(float(spec.doors[0].at), 0.5), (spec.colours.outer_wall as Color).to_html(false), (spec.colours.roof as Color).to_html(false), (spec.colours.front_door as Color).to_html(false)]] = true
	_check(twenty.size() == 20 and texts.size() == 20, "the twenty houses nearest the turning circle: %d different descriptions" % texts.size())
	_check(looks.size() == 20, "and with their sizes left out (plan, stair, rooms, windows, door place, paint): still %d different" % looks.size())
	# Over the whole town.
	var all := {}
	var total := 0
	for index: int in world.candidates:
		var site: Dictionary = world.site(index)
		if not bool(site.ok): continue
		total += 1
		all[HouseRules.signature(site.spec)] = true
	_check(all.size() == total, "over the whole map: %d houses, %d different descriptions" % [total, all.size()])
	# Come back and it is the same house.
	var target: int = twenty[0]
	var plan: Dictionary = world.site(target)
	await _put(plan.door_point + Vector3.UP * 0.2)
	await _frames(40)
	var first := HouseRules.signature(world.houses[target].spec) if world.houses.has(target) else "not built"
	await _put(map.on_ground(-600.0, -100.0, 0.2))
	await _frames(30)
	var gone: bool = not world.houses.has(target) and world.level_of(target) == BOX
	world.sites.erase(target)      # even the plan is worked out again
	await _put(plan.door_point + Vector3.UP * 0.2)
	await _frames(40)
	var second := HouseRules.signature(world.houses[target].spec) if world.houses.has(target) else "not built again"
	_check(gone and first == second and first.length() > 100, "box %d: built, left behind (a grey box again: %s), come back to: the same description to the letter (%d characters)" % [target, str(gone), first.length()])


# ---- locked rooms ------------------------------------------------------------------------

func _locked() -> void:
	var listed := 0
	var listed_one := 0
	var others := 0
	var others_none := 0
	var front_locked := 0
	var one_listed := -1
	var one_other := -1
	for index: int in world.candidates:
		var site: Dictionary = world.site(index)
		if not bool(site.ok): continue
		var count := 0
		for door: Dictionary in site.spec.doors:
			if bool(door.get("locked", false)): count += 1
		if world.has_locked_room(index):
			listed += 1
			if count == 1: listed_one += 1
			if str(site.locked_door) == "front": front_locked += 1
			elif one_listed < 0 and int(site.floors) == 2: one_listed = index
		else:
			others += 1
			if count == 0: others_none += 1
			if one_other < 0 and int(site.floors) == 2: one_other = index
	_check(listed > 0 and listed == listed_one, "%d makeable houses are in the map's locked_doors list: %d of them have exactly one locked door (%d have no room that could be locked on its own, so the front door is the lock)" % [listed, listed_one, front_locked])
	_check(others == others_none, "%d are not in the list: %d of them have no locked door" % [others, others_none])
	# Built, and counted on the real doors.
	var a: Node3D = HouseKit.build(world.site(one_listed).spec, false)
	var b: Node3D = HouseKit.build(world.site(one_other).spec, false)
	var locked_a := 0
	var locked_b := 0
	for label: String in a.doors: locked_a += 1 if a.doors[label].locked else 0
	for label: String in b.doors: locked_b += 1 if b.doors[label].locked else 0
	var loot := 0
	for child: Node in a.get_children():
		if child is Marker3D and str(child.get_meta("loot_tier", "")) == "locked_room": loot += 1
	_check(locked_a == 1 and locked_b == 0 and loot == 1, "built: box %d (listed, tier %s) has %d locked door, the '%s' room upstairs, with %d better-loot marker behind it; box %d (not listed) has %d" % [one_listed, str(world._locked[one_listed]), locked_a, str(world.site(one_listed).locked_door), loot, one_other, locked_b])
	a.free()
	b.free()


# ---- the street --------------------------------------------------------------------------

## The makeable houses whose door faces the house street (z = 447), by the map alone: their
## street point lies on it. Nothing here asks the world which street is which.
func _on_house_street(from_x: float, to_x: float) -> Array[int]:
	var output: Array[int] = []
	for index: int in world.candidates:
		var site: Dictionary = world.site(index)
		if not bool(site.ok): continue
		var point: Vector3 = site.street_point
		if absf(point.z - STREET_Z) <= 3.5 and point.x >= from_x and point.x <= to_x and absf((site.street_out as Vector3).z) > 0.8: output.append(index)
	return output


func _full_of(list: Array[int]) -> int:
	var total := 0
	for index: int in list:
		if world.level_of(index) == FULL: total += 1
	return total


func _street() -> void:
	# Start on the lane that runs south to the house street (a cut: the picture is new).
	_reset_seen()
	await _put(map.on_ground(93.0, 416.0, 0.1), Vector3(0, 0, 1))
	await _frames(30)
	var cut_ms := float(world.stats.cut_usec) / 1000.0
	var ring := _makeable_near(player.global_position, 150.0)
	var grey := 0
	for index: int in ring:
		if world.level_of(index) == BOX: grey += 1
	_check(grey == 0 and world.looks.size() <= World.LOOK_BUDGET, "put down at (93, 416): after the cut every one of the %d makeable houses within 150 m is a house (%d grey); %d stand as their outside in all, within %d m (budget %d); the cut took %.0f ms" % [ring.size(), grey, world.count(LOOK) + world.count(FULL), int(World.LOOK_RADIUS), World.LOOK_BUDGET, cut_ms])
	var street := _on_house_street(40.0, 175.0)
	var before := _full_of(street)
	_info("the house street (z = 447) has %d makeable houses fronting it between x = 40 and the circle; standing on the lane, %d m short of it, %d of them have an inside and %d full houses stand in all" % [street.size(), int(STREET_Z - player.global_position.z), before, world.houses.size()])
	seen.watch_grey = true
	_reset_walk_marks()
	# Down the lane to the corner.
	var reached: bool = await _drive([map.on_ground(93.0, 440.0)])
	var at_corner_before := _full_of(_on_house_street(93.0 - World.FULL_ALONG, 93.0 + World.FULL_ALONG))
	# Round the corner onto the house street, and a second for the insides to be built.
	reached = (await _drive([map.on_ground(93.0, STREET_Z), map.on_ground(97.0, STREET_Z)])) and reached
	await _settle(1.0)
	var here := player.global_position
	var due: Array[int] = []
	for index: int in _on_house_street(here.x - World.FULL_ALONG + 4.0, here.x + World.FULL_ALONG - 4.0):
		if world.fronts_street_of(index, here): due.append(index)
	var have := _full_of(due)
	_check(reached and due.size() >= 6 and have == mini(due.size(), World.FULL_BUDGET), "turned the corner onto the house street at (%.0f, %.0f): %d houses front it within %d m up and down it; %d have their inside now (%d had one while the player was still on the lane); %d full houses in all" % [here.x, here.z, due.size(), int(World.FULL_ALONG), have, at_corner_before, world.houses.size()])
	# Along it to the turning circle.
	var m := {"missing": 0, "checks": 0, "nearest_missing": INF, "worst_due": 0}
	var ok_walk := true
	for x: float in [108.0, 119.0, 130.0, 141.0, 150.0]:
		ok_walk = (await _drive([map.on_ground(x, STREET_Z + 0.5)])) and ok_walk
		await _settle(0.5)
		here = player.global_position
		var fronting := 0
		for index: int in _on_house_street(here.x - World.FULL_ALONG + 4.0, here.x + World.FULL_ALONG - 4.0):
			if not world.fronts_street_of(index, here): continue
			fronting += 1
			m.checks += 1
			if world.level_of(index) != FULL:
				m.missing += 1
				m.nearest_missing = minf(float(m.nearest_missing), _flat(_box_at(index), here))
		m.worst_due = maxi(int(m.worst_due), fronting)
	_check(ok_walk and int(m.missing) == 0 and int(m.checks) > 20, "walked the street to the turning circle, stopping five times: every house fronting it within %d m had its inside each time (%d house-checks, %d without; at most %d fronting at once)" % [int(World.FULL_ALONG), int(m.checks), int(m.missing), int(m.worst_due)])
	_check(float(seen.door_gap) > 2.3, "no door on the street was ever within reach before its house was a full one: the nearest the player came to the door of a house that was not yet full was %s (a door is used from 2.3 m)" % ("never within 15 m" if float(seen.door_gap) == INF else "%.1f m" % float(seen.door_gap)))
	_walk_checks("the walk (lane, corner, street: %.0f m)" % (31.0 + 4.0 + 53.0))


## Marks that only the walks keep: how near the player came to the door of a house that was
## not yet full.
func _reset_walk_marks() -> void:
	seen["door_gap"] = INF
	if not process_frame.is_connected(_door_watch): process_frame.connect(_door_watch)


func _door_watch() -> void:
	if not bool(seen.get("watch_grey", false)): return
	var feet := player.global_position
	for index: int in world.candidates:
		if world.level_of(index) == FULL or not world.sites.has(index) or not bool(world.sites[index].ok): continue
		if _flat(_box_at(index), feet) > 30.0: continue
		seen.door_gap = minf(float(seen.door_gap), _flat(world.sites[index].door_point, feet))


## The checks every walk ends with: nothing changed in view, the budgets, the frame cost.
func _walk_checks(what: String) -> void:
	seen.watch_grey = false
	_check(int(seen.seen_swaps) == 0 and int(seen.far_wrong) == 0, "%s: %d buildings changed between box and house; %d of them in sight nearer than %d m (%d changed in open view further off than that, where a box and a house look the same: the nearest of those %s; %d broke the rule) (%s)%s" % [what, int(seen.swaps), int(seen.seen_swaps), int(World.FAR_SWAP), int(seen.far), "none" if float(seen.far_nearest) == INF else "%.0f m" % float(seen.far_nearest), int(seen.far_wrong), JSON.stringify(seen.by_why), "" if (seen.seen_notes as Array).is_empty() else " " + str(seen.seen_notes)])
	_check(int(seen.max_full) <= World.FULL_BUDGET and int(seen.max_look) <= World.LOOK_BUDGET, "never more than %d full houses alive (budget %d) nor more than %d outsides (budget %d)" % [int(seen.max_full), World.FULL_BUDGET, int(seen.max_look), World.LOOK_BUDGET])
	_check(int(seen.under_feet) == 0 and int(seen.touched_back) == 0, "no full house was taken away from under the player (%d), and none that had been opened or broken was changed in view (%d)" % [int(seen.under_feet), int(seen.touched_back)])
	_check(int(world.stats.worst_usec) < 16000, "the world's worst frame cost %.1f ms (one costly thing a frame: the slowest plan took %.1f ms, the slowest outside %.1f ms, the slowest full house %.1f ms; the slowest look round for who is on which street %.1f ms)" % [float(world.stats.worst_usec) / 1000.0, float(world.stats.worst_plan_usec) / 1000.0, float(world.stats.worst_look_usec) / 1000.0, float(world.stats.worst_full_usec) / 1000.0, float(world.stats.worst_refresh_usec) / 1000.0])
	_info("an ordinary frame of the world cost %.2f ms on average over these %d frames; on average so far an outside took %.1f ms to build (%d built) and a full house %.1f ms (%d built)" % [float(world.stats.work_usec) / maxf(float(world.stats.frames), 1.0) / 1000.0, int(world.stats.frames), float(world.stats.look_usec) / maxf(float(world.stats.looks_built), 1.0) / 1000.0, int(world.stats.looks_built), float(world.stats.full_usec) / maxf(float(world.stats.fulls_built), 1.0) / 1000.0, int(world.stats.fulls_built)])
	_info("%s: a grey box of a makeable house was in view within %d m on %d frames%s; the nearest change between box and house was %s from the camera" % [what, int(seen.watch_radius), int(seen.grey_seen_frames), "" if int(seen.grey_seen_frames) == 0 else " (the nearest %.0f m; on %d of those frames its house was not yet made ready)" % [float(seen.grey_seen_nearest), int(seen.grey_not_ready)], "none" if float(seen.nearest_swap) == INF else "%.0f m" % float(seen.nearest_swap)])


## A longer way at a run, so that many buildings come into range and drop out of it.
func _long_walk() -> void:
	await _put(map.on_ground(30.0, 411.0, 0.1), Vector3(1, 0, 0))
	await _frames(30)
	_reset_seen()
	_reset_walk_marks()
	seen.watch_grey = true
	var from := clock
	var ok: bool = await _drive([map.on_ground(224.5, 411.0), map.on_ground(224.5, 493.0), map.on_ground(83.0, 493.0), map.on_ground(83.0, STREET_Z), map.on_ground(92.0, STREET_Z), map.on_ground(92.0, 411.0), map.on_ground(30.0, 411.0)], true, 120.0)
	_check(ok, "ran a 572 m loop of streets and lanes with six corners (east on z = 411, south, west on z = 493, north up a lane, along the house street, north again, west) in %.0f s" % (clock - from))
	_walk_checks("the 572 m run")


# ---- going in ----------------------------------------------------------------------------

## Opens the front door from outside and follows the plan's own way in and up. Returns what
## was reached: {in, up, top, down, out}.
func _visit(index: int) -> Dictionary:
	var site: Dictionary = world.site(index)
	var frame: Transform3D = site.frame
	var spec: Dictionary = site.spec
	var result := {"in": false, "up": false, "top": 0.0, "down": false, "out": false, "full": false, "genkan": NAN, "hall": NAN}
	var door_x := float(spec.doors[0].at)
	# The door may stand back from the front, in a porch cut into the house.
	var door_z := float(site.door_z)
	await _put(frame * Vector3(door_x, 0.3, -float(site.step_depth) - 1.0), frame.basis.z)
	await _frames(20)
	result.full = world.level_of(index) == FULL
	if not bool(result.full): return result
	var house: Node3D = world.houses[index]
	await _drive([frame * Vector3(door_x, 0.0, door_z - 1.75)], false, 10.0)
	var used: bool = house.door("front").interact(player)
	if not used and bool(spec.doors[0].get("locked", false)):
		house.door("front").open_with_chip(player)
		used = true
	await _settle(1.3)
	var points: Array = site.route
	var up_from := int(site.up_from)
	var floor0: float = house.floor_heights[0]
	var way: Array = []
	var reached := true
	# The first `low_points` of the way are on the lower floor inside the door (the genkan,
	# or a shop's floor); the next one is on the house's own floor, one step up.
	var low_points := int(site.low_points)
	var walked := 0
	for n: int in points.size():
		if points[n] is Array:
			house.door(str(points[n][1])).interact(player)
			await _settle(1.3)
			continue
		var point: Vector2 = points[n]
		way.append(point)
		reached = (await _drive([frame * Vector3(point.x, 0.0, point.y)], false, 12.0)) and reached
		var local: Vector3 = frame.affine_inverse() * player.global_position
		if walked == 0 and low_points > 0: result.genkan = local.y
		if walked == low_points:
			result.hall = local.y
			result["in"] = used and reached and local.z > door_z + 0.15 and absf(local.y - floor0) < 0.06 and (low_points == 0 or absf(float(result.genkan)) < 0.06)
		walked += 1
		result.top = maxf(float(result.top), local.y)
	if int(site.floors) == 2:
		var floor1: float = house.floor_heights[1]
		var local: Vector3 = frame.affine_inverse() * player.global_position
		result.up = reached and absf(local.y - floor1) < 0.06 and player.is_on_floor()
		result["standing_full"] = world.level_of(index) == FULL
		# And back the way it came.
		var back := true
		for n: int in range(way.size() - 2, -1, -1):
			back = (await _drive([frame * Vector3(way[n].x, 0.0, way[n].y)], false, 12.0)) and back
		local = frame.affine_inverse() * player.global_position
		# Back at the first point of the way: in the genkan (the house's own ground level) where
		# there is one, else on the ground floor.
		result.down = back and absf(local.y - (0.0 if low_points > 0 else floor0)) < 0.06
	else:
		result.down = true
	var out: bool = await _drive([frame * Vector3(door_x, 0.0, door_z - 0.5), frame * Vector3(door_x, 0.0, -float(site.step_depth) - 1.2)], false, 12.0)
	var outside: Vector3 = frame.affine_inverse() * player.global_position
	result.out = out and outside.z < -float(site.step_depth)
	result["ground_gap"] = absf(player.global_position.y - map.ground_height(player.global_position.x, player.global_position.z))
	return result


func _enter() -> void:
	# A two-floor house on sloping ground: steps down from its door.
	var chosen := -1
	var steepest := 0.0
	for index: int in world.candidates:
		var site: Dictionary = world.site(index)
		if not bool(site.ok) or int(site.floors) != 2 or bool(site.spec.doors[0].get("locked", false)): continue
		var drop := float(site.door_drop)
		if drop >= 0.35 and drop <= 0.9 and drop > steepest:
			steepest = drop
			chosen = index
	if chosen < 0:
		_check(false, "no two-floor house on sloping ground was found")
		return
	_reset_seen()
	var site: Dictionary = world.site(chosen)
	var box: Array = map.data.boxes[chosen]
	var result: Dictionary = await _visit(chosen)
	_check(bool(result.full) and bool(result["in"]), "box %d at (%.0f, %.0f), a %s on a slope (its footing goes %.1f m down to the box's base; the ground at the door is %.2f m below the floor): put down in front of it, it is a full house; the game's own player climbed the %d steps to the door, opened it and walked in" % [chosen, float(box[0]), float(box[2]), str(site.kind), float(site.spec.foundation), float(site.door_drop), ceili((0.15 + float(site.door_drop)) / 0.18)])
	_check(bool(result.up), "it climbed the stair (plan '%s', stair climbing %s) and stands on the upper floor, %.2f m above the house's ground" % [str(site.plan), str(site.spec.stair.dir), float(result.top)])
	_check(bool(result.get("standing_full", false)) and int(seen.under_feet) == 0, "while it was inside the house stayed a full house (taken from under it: %d times)" % int(seen.under_feet))
	_check(bool(result.down) and bool(result.out) and float(result.ground_gap) < 0.25, "it came back down and out to the street, standing on the ground (%.2f m above it)" % float(result.ground_gap))


## One house of every plan the rules can draw, each way round: walked into and climbed.
func _plans() -> void:
	var wanted := {}
	for index: int in world.candidates:
		var site: Dictionary = world.site(index)
		if not bool(site.ok) or bool(site.spec.doors[0].get("locked", false)) or float(site.door_drop) > 0.0: continue
		var key := "%s %s" % [str(site.plan), str(site.spec.stair.dir) if site.spec.has("stair") else "one floor"]
		if not wanted.has(key): wanted[key] = index
	var good := 0
	var notes: Array[String] = []
	for key: String in wanted:
		var result: Dictionary = await _visit(int(wanted[key]))
		var two: bool = int(world.site(int(wanted[key])).floors) == 2
		var fine: bool = bool(result.full) and bool(result["in"]) and bool(result.out) and bool(result.down) and (bool(result.up) or not two)
		if fine: good += 1
		notes.append("%s (box %d): %s" % [key, int(wanted[key]), "in, up %.2f m, down, out" % float(result.top) if (fine and two) else ("in and out" if fine else "FAILED " + JSON.stringify(result))])
	_check(good == wanted.size() and wanted.size() >= 8, "one house of each plan and stair direction, %d in all: the player opened the door, walked in, climbed the stair where there is one, came down and out at %d of them" % [wanted.size(), good])
	for note: String in notes: _info(note)


# ---- what stays a grey box ---------------------------------------------------------------

func _shut_tall() -> void:
	await _put(map.on_ground(97.0, STREET_Z, 0.1), Vector3(1, 0, 0))
	await _frames(40)
	var kinds: Array = map.data.kinds
	var here := player.global_position
	var shut := -1
	var tall := -1
	var shut_gap := INF
	var tall_gap := INF
	var shut_total := 0
	var shut_wrong := 0
	var tall_total := 0
	var tall_wrong := 0
	for index: int in (map.data.boxes as Array).size():
		var box: Array = map.data.boxes[index]
		var kind: String = kinds[int(box[7])]
		var is_shut := kind.ends_with("-a") or kind.ends_with("-b")
		var is_tall: bool = kind in ["building", "office", "apartment", "luxury", "tall", "slab"] or (kind in ["house", "timber", "shop"] and HouseRules.floors_of(box) > 2)
		if not is_shut and not is_tall: continue
		var gap := _flat(_box_at(index), here)
		var wrong: bool = world.levels.has(index) or world.looks.has(index) or world.houses.has(index) or not map.is_box_drawn(index) or not map.is_box_solid(index) or world.candidates.has(index)
		if is_shut:
			shut_total += 1
			if wrong: shut_wrong += 1
			if gap < shut_gap:
				shut_gap = gap
				shut = index
		else:
			tall_total += 1
			if wrong: tall_wrong += 1
			if gap < tall_gap:
				tall_gap = gap
				tall = index
	_check(shut_total > 500 and shut_wrong == 0, "all %d shut buildings are grey boxes, drawn and solid, and none is on the world's list (%d wrong)" % [shut_total, shut_wrong])
	_check(tall_total > 500 and tall_wrong == 0, "all %d buildings of three floors or more, and every office, block and tower, are grey boxes, drawn and solid (%d wrong)" % [tall_total, tall_wrong])
	# Walk at the nearest shut one, in the middle of the street's full houses.
	for pair: Array in [[shut, "shut building"], [tall, "tall building"]]:
		var index: int = pair[0]
		var box: Array = map.data.boxes[index]
		var to := Vector3(float(box[0]), float(box[1]) + float(box[4]) * 0.5, float(box[2]))
		var from: Vector3 = to + Basis(Vector3.UP, deg_to_rad(float(box[6]))) * Vector3(0.0, 0.0, -float(box[5]) * 0.5 - 0.3)
		var hit := root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, [player.get_rid()]))
		var struck: int = map.shape_box[int(hit.shape)] if (not hit.is_empty() and hit.collider == map.solids) else -1
		_check(struck == index, "the nearest %s (box %d, %s, %.0f m from the player, with %d full houses round him): a ray at its wall is stopped by its own grey box" % [str(pair[1]), index, str(kinds[int(box[7])]), _flat(_box_at(index), here), world.houses.size()])


# ---- the recharge stations ---------------------------------------------------------------

func _stations() -> void:
	var entries: Array = map.data.encounters.charging_stations
	var right := 0
	var worst_place := 0.0
	var worst_ground := 0.0
	var bays := 0
	var robots := 0
	var dormant := 0
	var ticking := 0
	for n: int in world.stations.size():
		var station: Node3D = world.stations[n]
		var entry: Array = entries[n]
		var place := _flat(station.global_position, Vector3(float(entry[0]), 0.0, float(entry[1])))
		worst_place = maxf(worst_place, place)
		worst_ground = maxf(worst_ground, absf(station.global_position.y - map.ground_height(station.global_position.x, station.global_position.z)))
		if int(station.bays) == int(entry[2]) and station.robots.size() == int(entry[3]) and place < 12.0: right += 1
		bays += int(station.bays)
		robots += station.robots.size()
		dormant += station.dormant_count()
		for robot: Node in station.robots:
			if robot.is_physics_processing(): ticking += 1
	# How many stations there are is the map's to say (it changes when the map is rebuilt); what is
	# checked is that every one the map lists stands where it is listed.
	_check(entries.size() >= 15 and world.stations.size() == entries.size() and right == entries.size(), "all %d stations of the map stand at their places with the bays and robots the map gives (%d bays, %d robots in all); the farthest is %.1f m from its listed point (it stands on its own plinth in its plot), the worst is %.2f m off the ground" % [world.stations.size(), bays, robots, worst_place, worst_ground])
	var boxes_left := 0
	for child: Node in map.get_children():
		if str(child.name) in ["Boxes_charger", "Boxes_charger_light", "Boxes_robot"]: boxes_left += 1
	_check(boxes_left == 0, "the grey stand-in boxes of the stations (plinths, bays, robots) are not built any more: %d left" % boxes_left)
	# Far from all of them: what do they cost?
	var far := Vector3.ZERO
	var best := 0.0
	for x: float in [-1000.0, -700.0, -400.0, 0.0, 400.0, 700.0]:
		for z: float in [-1300.0, -900.0, -500.0, 0.0, 500.0, 800.0]:
			var nearest := INF
			for station: Node3D in world.stations: nearest = minf(nearest, _flat(station.global_position, Vector3(x, 0.0, z)))
			if nearest > best:
				best = nearest
				far = Vector3(x, 0.0, z)
	await _put(map.on_ground(far.x, far.z, 0.2))
	await _frames(150)
	var started := Time.get_ticks_usec()
	for tick: int in 2000:
		for station: Node3D in world.stations: station._physics_process(DT)
	var per_tick := float(Time.get_ticks_usec() - started) / 2000.0
	var asleep := 0
	for station: Node3D in world.stations:
		if float(station._sleep) > 0.0 and int(station.hum_level) == 0: asleep += 1
	_check(best >= 300.0 and per_tick < 50.0 and ticking == 0 and dormant == robots and asleep == world.stations.size(), "with the player %.0f m from the nearest station: all %d are asleep and silent, all %d robots stand dormant with no tick of their own, and one tick of all the stations together costs %.1f microseconds (a 60 fps frame is 16,667)" % [best, asleep, robots, per_tick])
	var count := {"nodes": 0, "meshes": 0}
	for station: Node3D in world.stations:
		count.nodes += int(station.stats.nodes)
		count.meshes += int(station.stats.meshes)
	_info("the stations are %d nodes and %d meshes in all, always there (they are not swapped)" % [int(count.nodes), int(count.meshes)])


# ---- from a rooftop ----------------------------------------------------------------------

func _rooftop() -> void:
	# Stand in the street, then fly straight up at fly speed to above the roofs, as F3 does.
	await _put(map.on_ground(119.0, STREET_Z, 0.1), Vector3(1, 0, 0))
	await _frames(40)
	_reset_seen()
	seen.watch_radius = 150.0
	var roof: Vector3 = map.on_ground(119.0, STREET_Z, 14.0)
	await _glide(roof, 20.0, Vector3(1, 0, 0))
	var height := _above_ground()
	seen.watch_grey = true
	# Look all the way round, slowly, and down at the town.
	camera.rotation.x = deg_to_rad(-18.0)
	for step: int in range(360):
		player.rotation.y = deg_to_rad(float(step))
		await physics_frame
	var within := _makeable_near(player.global_position, 150.0)
	var grey := 0
	for index: int in within:
		if world.level_of(index) == BOX: grey += 1
	_check(world.high and int(seen.grey_seen_frames) == 0 and grey == 0, "flown up to %.1f m above the street (the rule changes at %.0f m) and turned all the way round looking down: no grey box of a makeable house was in view within 150 m on any of 360 frames; all %d within 150 m are houses (%d grey), %d as their outside only and %d full" % [height, World.HIGH_EYE, within.size(), grey, world.count(LOOK), world.count(FULL)])
	seen.watch_grey = false
	# Now over the roofs, with new ground coming into view all the time.
	_reset_seen()
	seen.watch_radius = 150.0
	seen.watch_grey = true
	camera.rotation.x = deg_to_rad(-12.0)
	await _glide(map.on_ground(119.0, STREET_Z - 260.0, 14.0), 20.0)
	_check(int(seen.grey_seen_frames) == 0 and int(seen.height_wrong) == 0 and int(seen.seen_swaps) == 0, "flown 260 m north over the roofs at fly speed (20 m/s): a grey box of a makeable house was in view within 150 m on %d frames; %d buildings changed in view under the height rule, every one at least %d m away with the eye at least %.0f m up (%d broke that); %d other changes, %d of them in sight" % [int(seen.grey_seen_frames), int(seen.from_height), int(World.HIGH_FAR), World.HIGH_EYE, int(seen.height_wrong), int(seen.swaps) - int(seen.from_height), int(seen.seen_swaps)])
	_check(int(seen.max_look) <= World.LOOK_BUDGET and int(seen.max_full) <= World.FULL_BUDGET and int(world.stats.worst_usec) < 16000, "from above: at most %d outsides alive (budget %d) and %d full houses; the world's worst frame %.1f ms" % [int(seen.max_look), World.LOOK_BUDGET, int(seen.max_full), float(world.stats.worst_usec) / 1000.0])
	seen.watch_grey = false
	camera.rotation.x = 0.0


# ---- the outside is the same picture -----------------------------------------------------

## Every triangle a node draws, in the space of `frame`: [centre, normal, colour, area].
func _triangles_of(node: Node, frame: Transform3D, glass: bool, into: Array) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and (node as Node3D).is_visible_in_tree():
		var instance := node as MeshInstance3D
		var is_glass: bool = instance.mesh.surface_get_material(0) == preload("res://scripts/interior_kit/window.gd").pane_material() or instance.material_override == preload("res://scripts/interior_kit/window.gd").pane_material()
		if is_glass == glass:
			var to_frame: Transform3D = frame.affine_inverse() * instance.global_transform
			var arrays: Array = instance.mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colours: Variant = arrays[Mesh.ARRAY_COLOR]
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			var total: int = (indices as PackedInt32Array).size() if indices != null else points.size()
			for n: int in range(0, total, 3):
				var ia: int = indices[n] if indices != null else n
				var ib: int = indices[n + 1] if indices != null else n + 1
				var ic: int = indices[n + 2] if indices != null else n + 2
				var a: Vector3 = to_frame * points[ia]
				var b: Vector3 = to_frame * points[ib]
				var c: Vector3 = to_frame * points[ic]
				var cross := (b - a).cross(c - a)
				into.append([(a + b + c) / 3.0, cross.normalized(), (colours[ia] as Color) if (colours != null and not glass) else Color.WHITE, cross.length() * 0.5])
	for child: Node in node.get_children(): _triangles_of(child, frame, glass, into)


## The corners of every pane of glass a node draws, each once, in the space of `frame`, in
## the shape _unmatched() compares.
func _corners_of(node: Node, frame: Transform3D, into: Array = [], known: Dictionary = {}) -> Array:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and (node as Node3D).is_visible_in_tree():
		var instance := node as MeshInstance3D
		var pane: Material = preload("res://scripts/interior_kit/window.gd").pane_material()
		if instance.mesh.surface_get_material(0) == pane or instance.material_override == pane:
			var to_frame: Transform3D = frame.affine_inverse() * instance.global_transform
			for point: Vector3 in (instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var at: Vector3 = to_frame * point
				var key := Vector3i((at / 0.0005).round())
				if known.has(key): continue
				known[key] = true
				into.append([at, Vector3.UP, Color.WHITE, 0.0])
	for child: Node in node.get_children(): _corners_of(child, frame, into, known)
	return into


## How many triangles of one list have no twin in the other (same place, facing, colour, size).
func _unmatched(first: Array, second: Array, by_quad: bool) -> int:
	var cells := {}
	for n: int in second.size():
		var key := Vector3i((second[n][0] as Vector3 / 0.02).floor())
		if not cells.has(key): cells[key] = []
		(cells[key] as Array).append(n)
	var used := {}
	var lonely := 0
	for entry: Array in first:
		var centre: Vector3 = entry[0]
		var home := Vector3i((centre / 0.02).floor())
		var found := -1
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				for dz: int in [-1, 0, 1]:
					if found >= 0: break
					for n: int in cells.get(home + Vector3i(dx, dy, dz), []):
						if used.has(n): continue
						var other: Array = second[n]
						if (other[0] as Vector3).distance_to(centre) > (0.02 if by_quad else 0.0015): continue
						if (other[1] as Vector3).dot(entry[1]) < 0.999: continue
						var ca: Color = other[2]
						var cb: Color = entry[2]
						if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.01: continue
						if not by_quad and absf(float(other[3]) - float(entry[3])) > 0.0005: continue
						found = n
						break
		if found >= 0: used[found] = true
		else: lonely += 1
	return lonely + second.size() - used.size()


func _same_picture() -> void:
	await _put(map.on_ground(119.0, STREET_Z, 0.1), Vector3(1, 0, 0))
	await _frames(60)
	# In the world itself: every full house on the street against the outside it replaced.
	var compared := 0
	var different := 0
	var glass_different := 0
	var triangles := 0
	for index: int in world.houses.keys():
		var house: Node3D = world.houses[index]
		var look: Node3D = world.looks[index]
		var frame: Transform3D = house.global_transform
		var full_solid: Array = []
		var full_glass: Array = []
		_triangles_of(house, frame, false, full_solid)
		_triangles_of(house, frame, true, full_glass)
		look.visible = true
		var look_solid: Array = []
		var look_glass: Array = []
		_triangles_of(look, frame, false, look_solid)
		_triangles_of(look, frame, true, look_glass)
		look.visible = false
		compared += 1
		triangles += look_solid.size() + look_glass.size()
		if full_solid.is_empty() or _unmatched(full_solid, look_solid, false) > 0: different += 1
		# A pane is a box either way, but the two are cut into triangles differently, so the
		# panes are compared by their corners.
		var full_corners := _corners_of(house, frame)
		look.visible = true
		var look_corners := _corners_of(look, frame)
		look.visible = false
		if full_corners.is_empty() or full_corners.size() != look_corners.size() or _unmatched(full_corners, look_corners, false) > 0: glass_different += 1
	var in_world := compared
	# And a spread of houses from all over the map, each built both ways side by side.
	for n: int in range(0, world.candidates.size(), 54):
		var plan: Dictionary = world.site(world.candidates[n])
		if not bool(plan.ok): continue
		var full_house: Node3D = HouseKit.build(plan.spec, true)
		var look_house: Node3D = HouseKit.build_look(plan.spec)
		root.add_child(full_house)
		root.add_child(look_house)
		full_house.global_position = Vector3(3000.0, 0.0, 3000.0)
		look_house.global_position = Vector3(3000.0, 0.0, 3000.0)
		var solid_a: Array = []
		var solid_b: Array = []
		_triangles_of(full_house, full_house.global_transform, false, solid_a)
		_triangles_of(look_house, look_house.global_transform, false, solid_b)
		var glass_a := _corners_of(full_house, full_house.global_transform)
		var glass_b := _corners_of(look_house, look_house.global_transform)
		compared += 1
		triangles += solid_b.size() + glass_b.size() * 12 / 8
		if solid_a.is_empty() or _unmatched(solid_a, solid_b, false) > 0: different += 1
		if glass_a.size() != glass_b.size() or _unmatched(glass_a, glass_b, false) > 0: glass_different += 1
		full_house.free()
		look_house.free()
	_check(in_world >= 5 and compared >= 40 and different == 0 and glass_different == 0, "the %d full houses on the street against the outside-only house each replaced, and %d more from all over the map built both ways: every triangle of one has its twin in the other, in the same place to 1.5 mm, facing the same way, the same colour and size (%d houses differ in walls, doors, stair or roof, %d in glass); %d triangles a house on average, drawn with the same two materials" % [in_world, compared - in_world, different, glass_different, triangles / maxi(compared, 1)])
	# What the outside-only house costs.
	var total_usec := 0
	var total_triangles := 0
	var nodes := 0
	var meshes := 0
	var bytes := 0
	var list := _makeable_near(player.global_position, 120.0).slice(0, 40)
	for index: int in list:
		var look: Node3D = HouseKit.build_look(world.site(index).spec)
		total_usec += int(look.get_meta("build_usec"))
		total_triangles += int(look.get_meta("triangles"))
		nodes += 1 + look.get_child_count()
		for child: Node in look.get_children():
			if child is MeshInstance3D:
				meshes += 1
				var arrays: Array = (child as MeshInstance3D).mesh.surface_get_arrays(0)
				bytes += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 28 + (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() * 4
		look.free()
	var full_usec := 0
	var full_nodes := 0
	for index: int in list.slice(0, 10):
		var house: Node3D = HouseKit.build(world.site(index).spec, true)
		full_usec += int(house.stats.build_usec)
		full_nodes += int(house.stats.nodes)
		house.free()
	var n := float(list.size())
	_check(nodes == list.size() * 3 and meshes == list.size() * 2, "an outside-only house is %d nodes and %d meshes (one for everything solid, one for the glass): no body, no shape, no script; the grey box's own collision keeps it solid" % [nodes / list.size(), meshes / list.size()])
	_info("outside-only, average of %d houses of this street: %.0f triangles, %.1f ms to build, about %.0f kB of mesh; %d of them (the budget) are %.1f million triangles, %d draw calls and about %.0f MB" % [list.size(), total_triangles / n, total_usec / n / 1000.0, bytes / n / 1024.0, World.LOOK_BUDGET, total_triangles / n * World.LOOK_BUDGET / 1.0e6, World.LOOK_BUDGET * 2, bytes / n * World.LOOK_BUDGET / 1048576.0])
	_info("a full house of the same street, average of 10: %d nodes, %.1f ms to build" % [full_nodes / 10, full_usec / 10000.0])


# ---- flying fast -------------------------------------------------------------------------

func _flight() -> void:
	await _put(map.on_ground(-250.0, 430.0, 30.0), Vector3(1, 0, 0))
	await _frames(30)
	_reset_seen()
	var fulls_before := int(world.stats.fulls_built)
	camera.rotation.x = deg_to_rad(-15.0)
	# Across the town at the fastest the player flies, 30 m up, then down the house street
	# at roof height.
	await _glide(map.on_ground(520.0, 430.0, 30.0), 55.0)
	await _glide(map.on_ground(520.0, STREET_Z, 6.0), 55.0)
	await _glide(map.on_ground(20.0, STREET_Z, 3.0), 55.0)
	camera.rotation.x = 0.0
	var built_fast := int(world.stats.fulls_built) - fulls_before
	_check(int(seen.max_look) <= World.LOOK_BUDGET and int(seen.max_full) <= World.FULL_BUDGET and int(seen.fulls_while_fast) == 0, "flown 1,300 m across the town and back down the house street at 55 m/s: never more than %d outsides (budget %d) or %d full houses (budget %d); full houses built while moving that fast: %d (the rule is none; %d were built in the turns)" % [int(seen.max_look), World.LOOK_BUDGET, int(seen.max_full), World.FULL_BUDGET, int(seen.fulls_while_fast), built_fast])
	_check(int(seen.seen_swaps) == 0 and int(seen.height_wrong) == 0, "in that flight %d buildings changed between box and house (%s): %d under the height rule, all far enough and high enough (%d broke it); of the rest %d were in sight" % [int(seen.swaps), JSON.stringify(seen.by_why), int(seen.from_height), int(seen.height_wrong), int(seen.seen_swaps)])
	_check(int(world.stats.worst_usec) < 16000, "the world's worst frame in the flight cost %.1f ms (building a %s)" % [float(world.stats.worst_usec) / 1000.0, str(world.stats.worst_what)])
	await _frames(20)
	# Is every building solid, one way or the other?
	var holes := 0
	var doubled := 0
	var undrawn := 0
	for index: int in world.candidates:
		var level: int = world.level_of(index)
		var full: bool = world.houses.has(index) and is_instance_valid(world.houses[index])
		if level == FULL and not full: holes += 1
		if level != FULL and not map.is_box_solid(index): holes += 1
		if level == FULL and map.is_box_solid(index): doubled += 1
		var drawn: bool = map.is_box_drawn(index)
		var look_shown: bool = world.looks.has(index) and (world.looks[index] as Node3D).visible
		if int(drawn) + int(look_shown) + int(full) != 1:
			undrawn += 1
			if undrawn <= 4: _info("box %d: level %d, box drawn %s, outside shown %s, full %s, has look %s, gap %.0f m" % [index, level, str(drawn), str(look_shown), str(full), str(world.looks.has(index)), _flat(_box_at(index), player.global_position)])
	_check(holes == 0 and doubled == 0 and undrawn == 0, "after it, over all %d low open buildings: none without collision (%d), none with both its box's and its house's (%d), and each drawn as exactly one thing: box, outside or full house (%d wrong)" % [world.candidates.size(), holes, doubled, undrawn])
	# Drop rays down the house street the flight ended on: something solid under every one.
	var missed := 0
	var rays := 0
	var space := root.get_world_3d().direct_space_state
	for index: int in _makeable_near(player.global_position, 120.0):
		var box: Array = map.data.boxes[index]
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(float(box[0]), float(box[1]) + float(box[4]) + 30.0, float(box[2])), Vector3(float(box[0]), float(box[1]), float(box[2])), 1))
		rays += 1
		if hit.is_empty() or (hit.position as Vector3).y < float(box[1]) + float(box[4]) - 3.5: missed += 1
	_check(rays > 20 and missed == 0, "a ray dropped on each of the %d houses near where the flight stopped lands on its roof (%d fell through)" % [rays, missed])


# ---- the houses are Japanese houses ------------------------------------------------------

## Builds a house far from the town, as solid as in play, and lets the physics know it.
func _stand(spec: Dictionary, slot: int) -> Node3D:
	var house: Node3D = HouseKit.build(spec, true)
	root.add_child(house)
	house.global_position = Vector3(3000.0 + float(slot % 8) * 40.0, 0.0, 3000.0 + float(slot / 8) * 40.0)
	return house


## How high the floor is under a point of a house's plan, above the house's own origin.
func _floor_under(house: Node3D, point: Vector2) -> float:
	var from: Vector3 = house.global_transform * Vector3(point.x, 1.2, point.y)
	var hit := root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0, 1))
	return NAN if hit.is_empty() else (hit.position as Vector3).y - house.global_position.y


func _japanese() -> void:
	var kinds := ["house", "timber", "shop"]
	var tally := {}
	for kind: String in kinds: tally[kind] = {"n": 0, "genkan": 0, "recess": 0, "sliding_door": 0, "no_sliding_window": 0, "setback": 0, "setback_wished": 0, "two": 0, "balcony": 0, "washitsu": 0, "wet": 0, "forms": {}, "ridge_x": 0, "form_wrong": 0, "porch": {}, "pitch_low": 1.0, "pitch_high": 0.0}
	var samples := {}
	for index: int in world.candidates:
		var site: Dictionary = world.site(index)
		if not bool(site.ok): continue
		var spec: Dictionary = site.spec
		var f: Dictionary = site.features
		var t: Dictionary = tally[str(site.kind)]
		t.n += 1
		if bool(f.genkan): t.genkan += 1
		if spec.has("recess"): t.recess += 1
		if str(f.front_door) == "slide": t.sliding_door += 1
		var sliding := 0
		for window: Dictionary in spec.windows:
			if int(window.get("panes", 1)) >= 2: sliding += 1
		if sliding == 0 and not (spec.windows as Array).is_empty(): t.no_sliding_window += 1
		if (spec.windows as Array).is_empty(): t["windowless"] = int(t.get("windowless", 0)) + 1
		if int(site.floors) == 2: t.two += 1
		if str(f.setback) != "none": t.setback += 1
		if str(f.balcony) != "none": t.balcony += 1
		if bool(f.washitsu): t.washitsu += 1
		if bool(f.wet): t.wet += 1
		t.forms[f.roof] = int(t.forms.get(f.roof, 0)) + 1
		t.porch[f.porch] = int(t.porch.get(f.porch, 0)) + 1
		if str(f.ridge) == "x": t.ridge_x += 1
		t.pitch_low = minf(float(t.pitch_low), float(f.pitch))
		t.pitch_high = maxf(float(t.pitch_high), float(f.pitch))
		if float(f.pitch) < 0.25: t["flat"] = int(t.get("flat", 0)) + 1
		if str(f.roofing) != "tile": t["sheet"] = int(t.get("sheet", 0)) + 1
		if str(f.roofing) == "tile" and float(f.pitch) < 0.3 - 0.0001: t.form_wrong += 1      # tiles are never laid flatter than 3 in 10
		# The rule, worked out again here from the box alone: the form the seed wishes for a
		# house of this kind and size (a hip-and-gable roof too short for its gable is a hip).
		var dice := RandomNumberGenerator.new()
		dice.seed = HouseRules.seed_of(map.data.boxes[index]) ^ 0x5bd1e995
		var wish: Dictionary = Dress.wishes(str(site.kind), site.size, int(site.floors), dice)
		if bool(wish.setback): t.setback_wished += 1
		var turned: bool = Dress.turned_plot(site.frame, site.size) and str(site.kind) != "shop" and str(wish.form) != "irimoya"
		if turned: wish["form"] = "gable"
		if str(wish.form) != str(f.roof) and not (str(wish.form) == "irimoya" and str(f.roof) == "hip"): t.form_wrong += 1
		if str(site.kind) == "house" and str(f.roof) == "irimoya": t.form_wrong += 1
		if str(f.setback) != "none" and not bool(wish.setback): t.form_wrong += 1
		# Houses to build and measure: of each kind some with a porch cut in, some set back.
		var key := "%s %s %s %s" % [str(site.kind), "recess" if spec.has("recess") else "flat", "setback" if str(f.setback) != "none" else "full", str(f.roof)]
		if not samples.has(key): samples[key] = []
		if (samples[key] as Array).size() < 2 and float(site.door_drop) == 0.0: (samples[key] as Array).append(index)
	var total := 0
	var all_genkan := 0
	var none_sliding := 0
	var wrong := 0
	for kind: String in kinds:
		var t: Dictionary = tally[kind]
		total += int(t.n)
		all_genkan += int(t.genkan)
		none_sliding += int(t.no_sliding_window)
		wrong += int(t.form_wrong)
		_info("%s: %d houses (%d of two floors). Roofs %s, tiled on %d and sheet metal on a low pitch on %d; ridge along the street on %d, across it on %d; pitch %.2f to %.2f (%d flatter than 0.25: their boxes stand under 0.9 m above their eaves). Upper floor set back on %d (wished on %d; the rooms and the stair allowed it on those). Entrance: porch cut into the front on %d, else %s; sliding front door on %d. Genkan in %d. Balcony on %d. A tatami room in %d, bath and toilet rooms in %d" % [kind, int(t.n), int(t.two), JSON.stringify(t.forms), int(t.n) - int(t.get("sheet", 0)), int(t.get("sheet", 0)), int(t.ridge_x), int(t.n) - int(t.ridge_x), float(t.pitch_low), float(t.pitch_high), int(t.get("flat", 0)), int(t.setback), int(t.setback_wished), int(t.recess), JSON.stringify(t.porch), int(t.sliding_door), int(t.genkan), int(t.balcony), int(t.washitsu), int(t.wet)])
	_check(all_genkan >= total * 0.9, "a genkan (a lower floor inside the front door) in %d of %d houses; the %d without are too small for one (a room under 3.6 m deep, or an entry room too shallow)" % [all_genkan, total, total - all_genkan])
	_check(none_sliding == 0, "every house with windows has sliding windows with their meeting stiles built (%d have none); %d houses have no window at all (a neighbour within 1.2 m of every wall a room has)" % [none_sliding, int(tally.house.get("windowless", 0)) + int(tally.timber.get("windowless", 0)) + int(tally.shop.get("windowless", 0))])
	_check(wrong == 0 and int(tally.timber.forms.get("irimoya", 0)) > 50 and int(tally.house.forms.get("gable", 0)) > 100 and int(tally.house.forms.get("hip", 0)) > 100, "the roof's form is the one the rule gives for the kind, the size and the seed at every house (%d are not); hip-and-gable roofs only on timber houses (%d of them)" % [wrong, int(tally.timber.forms.get("irimoya", 0))])
	_check(int(tally.timber.sliding_door) >= int(tally.timber.n) * 0.95 and int(tally.house.sliding_door) == 0, "front doors: sliding on %d of the %d timber houses (the others have no wall beside the door for it to slide into) and on %d of the %d shop-houses (the old-fronted ones), hinged on all %d newer houses" % [int(tally.timber.sliding_door), int(tally.timber.n), int(tally.shop.sliding_door), int(tally.shop.n), int(tally.house.n)])
	_check(int(tally.house.setback) > 50 and int(tally.timber.setback) > 50 and int(tally.house.recess) > 50 and int(tally.timber.recess) > 20 and int(tally.shop.recess) == 0, "upper floor set back at %d houses, %d timber houses and %d shop-houses; a porch cut into the front at %d houses and %d timber houses, at no shop-house" % [int(tally.house.setback), int(tally.timber.setback), int(tally.shop.setback), int(tally.house.recess), int(tally.timber.recess)])
	# Built, and measured on what was built.
	var built: Array = []
	for key: String in samples:
		for index: int in samples[key]: built.append([index, _stand(world.site(index).spec, built.size())])
	await _frames(3)
	var m := {"step_n": 0, "step_wrong": 0, "step_low": INF, "step_high": -INF, "recess_n": 0, "recess_wrong": 0, "recess_least": INF, "roof_wrong": 0, "ridge_wrong": 0, "set_n": 0, "set_wrong": 0, "slide_wrong": 0, "slides": 0, "inner_slides": 0, "hinged_for_room": 0}
	for pair: Array in built:
		var index: int = pair[0]
		var house: Node3D = pair[1]
		var site: Dictionary = world.site(index)
		var spec: Dictionary = site.spec
		var f: Dictionary = site.features
		# The genkan step: the floor under the first point of the way in, and under the next.
		if int(site.low_points) > 0:
			var points: Array = []
			for point: Variant in site.route:
				if point is Vector2: points.append(point)
			var low := _floor_under(house, points[0])
			var high := _floor_under(house, points[int(site.low_points)] + Vector2(0.0, 0.25))
			m.step_n += 1
			m.step_low = minf(float(m.step_low), high - low)
			m.step_high = maxf(float(m.step_high), high - low)
			if is_nan(low) or is_nan(high) or absf(high - low - HouseKit.FLOOR_ABOVE_GROUND) > 0.004 or absf(low) > 0.004: m.step_wrong += 1
		# The door stands back from the front by the porch's depth.
		var door: Node3D = house.door("front")
		if spec.has("recess"):
			m.recess_n += 1
			m.recess_least = minf(float(m.recess_least), door.position.z)
			if absf(door.position.z - float(spec.recess.depth) - HouseKit.WALL_OUTER * 0.5) > 0.002 or float(spec.recess.depth) < 0.75: m.recess_wrong += 1
		elif absf(door.position.z - HouseKit.WALL_OUTER * 0.5) > 0.002: m.recess_wrong += 1
		if (str(f.front_door) == "slide") != bool(door.slides): m.slide_wrong += 1
		for label: String in house.doors:
			if bool(house.doors[label].slides): m.slides += 1
		# The roof, from the mesh: where its highest corners are, and how far they spread.
		var arrays: Array = (house.get_node("ShellMesh") as MeshInstance3D).mesh.surface_get_arrays(0)
		var points3: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var top := -INF
		for point: Vector3 in points3: top = maxf(top, point.y)
		var low_corner := Vector3(INF, 0, INF)
		var high_corner := Vector3(-INF, 0, -INF)
		for point: Vector3 in points3:
			if point.y < top - 0.02: continue
			low_corner = Vector3(minf(low_corner.x, point.x), 0, minf(low_corner.z, point.z))
			high_corner = Vector3(maxf(high_corner.x, point.x), 0, maxf(high_corner.z, point.z))
		var ridge_axis := "x" if high_corner.x - low_corner.x >= high_corner.z - low_corner.z else "z"
		var ridge_length := maxf(high_corner.x - low_corner.x, high_corner.z - low_corner.z)
		var inset: Dictionary = spec.get("upper", {})
		var roof_w: float = float(site.size.x) - float(inset.get("left", 0.0)) - float(inset.get("right", 0.0))
		var roof_d: float = float(site.size.y) - float(inset.get("front", 0.0)) - float(inset.get("back", 0.0))
		var along := roof_w if ridge_axis == "x" else roof_d
		var across := roof_d if ridge_axis == "x" else roof_w
		# A gable's ridge is longer than the house, a hip's shorter by the house's width, a
		# hip-and-gable's in between.
		var form := "gable" if ridge_length > along - 0.05 else ("hip" if ridge_length < along - across * 0.75 else "irimoya")
		if absf(along - across) > 0.3 or form == "gable":
			if ridge_axis != str(f.ridge): m.ridge_wrong += 1
		if form != str(f.roof) or str(house.roof.form) != str(f.roof): m.roof_wrong += 1
		# The upper floor's walls, from the upstairs windows: each stands in a wall that is set
		# back by what the description says.
		if str(f.setback) != "none":
			m.set_n += 1
			var seen_walls := {}
			for window: Dictionary in spec.windows:
				if int(window.floor) != 1: continue
				var pane: Node3D = house.window(str(window.name))
				var want := 0.0
				var have := 0.0
				match str(window.wall):
					"front":
						want = float(inset.front) + HouseKit.WALL_OUTER * 0.5
						have = pane.position.z
					"back":
						want = float(site.size.y) - float(inset.back) - HouseKit.WALL_OUTER * 0.5
						have = pane.position.z
					"left":
						want = float(inset.left) + HouseKit.WALL_OUTER * 0.5
						have = pane.position.x
					_:
						want = float(site.size.x) - float(inset.right) - HouseKit.WALL_OUTER * 0.5
						have = pane.position.x
				seen_walls[window.wall] = true
				if absf(want - have) > 0.002: m.set_wrong += 1
			# And the solid upper floor is as much smaller: a ray dropped just outside the upper
			# wall lands on the lean-to roof, not on the main roof.
			for wall: String in ["front", "back", "left", "right"]:
				if float(inset[wall]) <= 0.0: continue
				var at := Vector2(float(site.size.x) * 0.5, float(inset.front) * 0.5) if wall == "front" else (Vector2(float(site.size.x) * 0.5, float(site.size.y) - float(inset.back) * 0.5) if wall == "back" else (Vector2(float(inset.left) * 0.5, float(site.size.y) * 0.5) if wall == "left" else Vector2(float(site.size.x) - float(inset.right) * 0.5, float(site.size.y) * 0.5)))
				var from: Vector3 = house.global_transform * Vector3(at.x, 4.55, at.y)      # under the main roof's eave
				var hit := root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 6.0, 1))
				var landed: float = NAN if hit.is_empty() else (hit.position as Vector3).y - house.global_position.y
				if is_nan(landed) or landed < 2.7 or landed > 3.6: m.set_wrong += 1
	_check(int(m.step_n) >= 12 and int(m.step_wrong) == 0, "%d houses built: at every one with a genkan (%d) its floor is at the house's own ground level and the hall's is one step up: %.3f to %.3f m (the rule is %.2f m)" % [built.size(), int(m.step_n), float(m.step_low), float(m.step_high), HouseKit.FLOOR_ABOVE_GROUND])
	_check(int(m.recess_n) >= 6 and int(m.recess_wrong) == 0, "the front door stands back from the front wall by the porch's depth at all %d built with a porch cut in (the least %.2f m), and in the front wall at the others (%d wrong)" % [int(m.recess_n), float(m.recess_least) - HouseKit.WALL_OUTER * 0.5, int(m.recess_wrong)])
	_check(int(m.roof_wrong) == 0 and int(m.ridge_wrong) == 0, "the roofs as built, read from their meshes (how long the ridge is against the house, and which way it runs): the form and the ridge's direction are what the rule gave at all %d (%d forms wrong, %d directions wrong)" % [built.size(), int(m.roof_wrong), int(m.ridge_wrong)])
	_check(int(m.set_n) >= 6 and int(m.set_wrong) == 0, "the upper floor as built is set back where the rule says, at all %d built with one: every upstairs window stands in a wall set back by the right amount, and a ray dropped between the two walls lands on a lean-to roof 2.7 to 3.6 m up (%d wrong)" % [int(m.set_n), int(m.set_wrong)])
	_check(int(m.slide_wrong) == 0 and int(m.slides) > built.size(), "sliding doors as built: the front door slides exactly where the rule says (%d wrong); %d doors in these %d houses slide into the wall beside them" % [int(m.slide_wrong), int(m.slides), built.size()])
	for pair: Array in built: (pair[1] as Node).free()


# ---- no two neighbours alike ---------------------------------------------------------------

func _neighbours() -> void:
	var places := [["the turning circle of the house street", CIRCLE], ["the old town", Vector3(520.0, 0.0, -520.0)], ["the family homes further east", Vector3(420.0, 0.0, 400.0)], ["the shop-houses on the east side", Vector3(700.0, 0.0, 200.0)]]
	for place: Array in places:
		var near := _makeable_near(place[1], 200.0).slice(0, 40)
		var sigs := {}
		var twins: Array[String] = []
		for index: int in near:
			var sig := str(world.site(index).features.sig)
			if sigs.has(sig): twins.append("box %d and box %d: %s" % [int(sigs[sig]), index, sig])
			sigs[sig] = index
		var kinds := {}
		for index: int in near: kinds[world.site(index).kind] = int(kinds.get(world.site(index).kind, 0)) + 1
		_check(near.size() == 40 and twins.is_empty(), "the 40 houses nearest %s (%s): no two share roof form and ridge direction + set-back + entrance + balcony + what stands on the plot (%d different of 40)%s" % [str(place[0]), JSON.stringify(kinds), sigs.size(), "" if twins.is_empty() else " " + str(twins.slice(0, 3))])
	# Neighbours of the same size: the nearest pair of houses within 12 m of each other whose
	# boxes measure the same to 0.3 m.
	var pairs := 0
	var alike := 0
	var notes: Array[String] = []
	var list := _makeable_near(Vector3(100.0, 0.0, 100.0), 900.0)
	for a: int in list.size():
		for b: int in range(a + 1, mini(a + 60, list.size())):
			var box_a: Array = map.data.boxes[list[a]]
			var box_b: Array = map.data.boxes[list[b]]
			if _flat(_box_at(list[a]), _box_at(list[b])) > 16.0: continue
			if absf(float(box_a[3]) - float(box_b[3])) > 0.5 or absf(float(box_a[5]) - float(box_b[5])) > 0.5 or absf(float(box_a[4]) - float(box_b[4])) > 0.5: continue
			pairs += 1
			if str(world.site(list[a]).features.sig) == str(world.site(list[b]).features.sig):
				alike += 1
				if notes.size() < 3: notes.append("box %d and %d" % [list[a], list[b]])
	_check(pairs >= 15 and alike == 0, "next-door houses of the same size (%d pairs within 16 m whose boxes measure the same to 0.5 m): every pair differs in roof, set-back, entrance, balcony or plot (%d alike%s)" % [pairs, alike, "" if notes.is_empty() else ": " + str(notes)])
	# The ridges along one street.
	for street: Array in [["the house street (z = 447)", _on_house_street(40.0, 175.0)], ["the long road north of it (z = 411)", _on_street_z(411.0, 20.0, 200.0)]]:
		var along := 0
		var across := 0
		for index: int in street[1]:
			if str(world.site(index).features.ridge) == "x": along += 1
			else: across += 1
		var forms: Array[String] = []
		for index: int in street[1]: forms.append("%s %s" % [str(world.site(index).features.roof), "along" if str(world.site(index).features.ridge) == "x" else "across"])
		_check(along > 0 and across > 0, "%s: of the %d houses fronting it the ridge runs along the street on %d and across it (gable or hip end to the street) on %d (%s)" % [str(street[0]), (street[1] as Array).size(), along, across, ", ".join(PackedStringArray(forms))])


func _on_street_z(z: float, from_x: float, to_x: float) -> Array[int]:
	var output: Array[int] = []
	for index: int in world.candidates:
		var site: Dictionary = world.site(index)
		if not bool(site.ok): continue
		var point: Vector3 = site.street_point
		if absf(point.z - z) <= 4.5 and point.x >= from_x and point.x <= to_x and absf((site.street_out as Vector3).z) > 0.8: output.append(index)
	return output


# ---- every kind of house is walked into ---------------------------------------------------------

func _kinds() -> void:
	# One house of every kind, roof, set-back and entrance that the rules make, on level
	# ground; and of each kind one on a slope.
	var wanted := {}
	var sloped := {}
	for index: int in world.candidates:
		var site: Dictionary = world.site(index)
		if not bool(site.ok) or bool(site.spec.doors[0].get("locked", false)): continue
		var f: Dictionary = site.features
		if float(site.door_drop) > 0.0:
			if float(site.door_drop) >= 0.2 and float(site.door_drop) <= 1.0 and (not sloped.has(site.kind) or (int(site.floors) == 2 and int(world.site(int(sloped[site.kind])).floors) == 1)): sloped[site.kind] = index
			continue
		var key := "%s, %s roof ridge %s, %s, %s, %s" % [str(site.kind), str(f.roof), str(f.ridge), "upper floor set back " + str(f.setback) if str(f.setback) != "none" else ("two floors" if int(site.floors) == 2 else "one floor"), "porch cut in" if site.spec.has("recess") else "door in the front wall", str(site.plan)]
		var short := "%s|%s|%s|%s|%s" % [str(site.kind), str(f.roof), "set" if str(f.setback) != "none" else str(site.floors), "recess" if site.spec.has("recess") else "flat", str(site.plan).get_slice("_", 0)]
		if not wanted.has(short): wanted[short] = [index, key]
	var good := 0
	var notes: Array[String] = []
	var total := 0
	for short: String in wanted:
		var index: int = wanted[short][0]
		var result: Dictionary = await _visit(index)
		var two: bool = int(world.site(index).floors) == 2
		var fine: bool = bool(result.full) and bool(result["in"]) and bool(result.out) and bool(result.down) and (bool(result.up) or not two)
		total += 1
		if fine: good += 1
		else: notes.append("FAILED box %d (%s): %s" % [index, str(wanted[short][1]), JSON.stringify(result)])
	_check(good == total and total >= 30, "%d houses, one of every kind, roof form, set-back, entrance and plan the rules make, on level ground: the game's own player went in through the genkan, up the stair where there is one, down and out at %d of them" % [total, good])
	for note: String in notes.slice(0, 8): _info(note)
	var slope_good := 0
	for kind: String in sloped:
		var result: Dictionary = await _visit(int(sloped[kind]))
		var fine: bool = bool(result.full) and bool(result["in"]) and bool(result.out) and bool(result.down) and (bool(result.up) or int(world.site(int(sloped[kind])).floors) == 1)
		if fine: slope_good += 1
		else: _info("FAILED on a slope: box %d (%s): %s" % [int(sloped[kind]), kind, JSON.stringify(result)])
	_check(slope_good == sloped.size() and sloped.size() >= 2, "and one house of each kind that has a plot falling 0.2 to 1.0 m at the door (steps down from it; boxes %s): in, up, down and out at %d of %d" % [JSON.stringify(sloped), slope_good, sloped.size()])


# ---- the start and a jump -------------------------------------------------------------------------

func _cuts() -> void:
	var notes: Array[String] = []
	var worst := 0.0
	var longest := 0
	var grey_after := 0
	for place: Array in [["the start (the lane off the house street)", map.on_ground(93.0, 416.0, 0.1), Vector3(0, 0, 1)], ["a jump to the old town", map.on_ground(520.0, -520.0, 0.1), Vector3(1, 0, 0)], ["a jump to the long road", map.on_ground(34.0, 411.0, 0.1), Vector3(1, 0, 0)], ["a jump to the east homes", map.on_ground(420.0, 400.0, 0.1), Vector3(0, 0, -1)]]:
		# From far away, so every house there has to be made anew.
		await _put(map.on_ground(-600.0, -100.0, 0.2))
		await _frames(20)
		_reset_seen()
		seen.watch_grey = true
		await _put(place[1], place[2])
		seen["cut_end_frame"] = Engine.get_physics_frames()
		var frames := int(world.stats.cut_frames)
		var worst_here := float(world.stats.cut_worst_usec) / 1000.0
		# Turn right round at once: nothing grey may show within 150 m.
		for step: int in range(0, 360, 6):
			player.rotation.y += deg_to_rad(6.0)
			await physics_frame
		await _frames(30)
		seen.watch_grey = false
		worst = maxf(worst, worst_here)
		longest = maxi(longest, frames)
		grey_after += int(seen.grey_seen_frames)
		notes.append("%s: black for %d frames (%.2f s at 60 a second) while %d houses were made, %.0f ms of work in all, the worst frame %.1f ms; then turned right round: a grey box in view within 150 m on %d frames, %d changes in sight nearer than %d m" % [str(place[0]), frames, float(frames) / 60.0 + World.FADE_SECONDS, int(world.stats.cut_looks), float(world.stats.cut_usec) / 1000.0, worst_here, int(seen.grey_seen_frames), int(seen.seen_swaps), int(World.FAR_SWAP)])
		if int(seen.seen_swaps) > 0:
			grey_after += 1000
			# (Which buildings changed in sight, for whoever reads the failure.)
			notes.append("%s: changed in sight: %s" % [str(place[0]), "; ".join(PackedStringArray(seen.seen_notes))])
	_check(worst < 25.0 and longest <= 90, "the start and three jumps: the worst single frame cost %.1f ms (it was up to 1,400 ms in one frame); the picture is black for at most %d frames (%.2f s with the fade), and the game answers all the while" % [worst, longest, float(longest) / 60.0 + World.FADE_SECONDS])
	_check(grey_after == 0, "after each, turning right round at once: no grey box of a makeable house in view within 150 m, and no change in sight (%d)" % grey_after)
	for note: String in notes: _info(note)
	# What the ring costs: every outside alive now, counted.
	var triangles := 0
	var bytes := 0
	for index: int in world.looks:
		var look: Node3D = world.looks[index]
		triangles += int(look.get_meta("triangles", 0))
	bytes = triangles * 52
	_check(world.looks.size() <= World.LOOK_BUDGET and triangles <= World.LOOK_BUDGET * 5000, "the ring of outsides now: %d houses, %.2f million triangles, about %d MB of mesh, %d draw calls if all were in view (budget: %d houses, %.1f million triangles, about %d MB)" % [world.looks.size(), triangles / 1.0e6, bytes / 1048576, world.looks.size() * 2, World.LOOK_BUDGET, World.LOOK_BUDGET * 5000 / 1.0e6, World.LOOK_BUDGET * 5000 * 52 / 1048576])


# ---- the restaurants and corner shops ----------------------------------------------------------------

## Shop-houses the map plan names no business in, and what each was described as before the
## trades got their shop fronts (taken 2026-11-14): [box, its x, its z, the md5 of
## HouseRules.signature]. A box that is no longer at that place is left out (the map was made
## again). If the house rules or the dress are changed on purpose, take these again.
const PLAIN_SHOPS: Array[Array] = [
	[189, -296.25, -464.0, "b7f767c81081a5d87418e327a39abc19"], [1318, 708.47, 184.61, "e40e2c33ba14dda9ffc77e63d798432f"],
	[1695, -217.11, 403.16, "b21ae34e4e923e64bde8af9f71a3a5e8"], [2061, 44.94, 311.93, "1a1a553e442496818afbf6e56a716d7a"],
	[2184, 1.28, 718.64, "1c159d7819d59828e20765c11a7cc568"], [2333, -687.05, 233.16, "ca93d7f1bad378a0fb7f93544e748bc8"],
]


## The plan of a box dressed as the trade `what` (with no business for ""), whatever the map
## names there. The world is left as it was.
func _plan_as(index: int, what: String) -> Dictionary:
	var had: bool = world.businesses.has(index)
	var kept: Dictionary = world.businesses.get(index, {})
	if what == "": world.businesses.erase(index)
	else: world.businesses[index] = {"type": "", "what": what}
	var plan: Dictionary = HouseRules.plan(world, index)
	if had: world.businesses[index] = kept
	else: world.businesses.erase(index)
	return plan


## As _unmatched() with the same measures (same place to 1.5 mm, facing, colour, size), but
## each triangle is paired with the NEAREST free one that fits, not the first found. The
## letters of a sign are many small triangles closer together than 1.5 mm; paired with the
## first found, one may take its neighbour's twin and leave a third without any.
func _unmatched_nearest(first: Array, second: Array) -> int:
	var cells := {}
	for n: int in second.size():
		var key := Vector3i((second[n][0] as Vector3 / 0.02).floor())
		if not cells.has(key): cells[key] = []
		(cells[key] as Array).append(n)
	var used := {}
	var lonely := 0
	for entry: Array in first:
		var centre: Vector3 = entry[0]
		var home := Vector3i((centre / 0.02).floor())
		var found := -1
		var nearest := 0.0015
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				for dz: int in [-1, 0, 1]:
					for n: int in cells.get(home + Vector3i(dx, dy, dz), []):
						if used.has(n): continue
						var other: Array = second[n]
						var gap := (other[0] as Vector3).distance_to(centre)
						if gap > nearest or (found >= 0 and gap == nearest): continue
						if (other[1] as Vector3).dot(entry[1]) < 0.999: continue
						var ca: Color = other[2]
						var cb: Color = entry[2]
						if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.01: continue
						if absf(float(other[3]) - float(entry[3])) > 0.0005: continue
						found = n
						nearest = gap
		if found >= 0: used[found] = true
		else: lonely += 1
	return lonely + second.size() - used.size()


func _same_colour(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.004


## What a trade's shop front lacks of what the trade is told by, in words ("" for nothing).
func _trade_faults(plan: Dictionary, what: String) -> String:
	var trade: Dictionary = Dress.TRADES[what]
	var spec: Dictionary = plan.spec
	var pieces: Array = plan.features.get("shop_front", [])
	var faults: Array[String] = []
	var size: Vector2 = plan.size
	# The sign: the trade's word in the trade's ink, on something of the trade's colour.
	var word_seen := false
	for entry: Array in spec.get("signs", []):
		if str(entry[0]) == str(trade.word) and (_same_colour(entry[5], trade.ink) or (trade.has("awning_ink") and _same_colour(entry[5], trade.awning_ink))): word_seen = true
	if not word_seen: faults.append("the word %s is not on it" % str(trade.word))
	var boards := 0
	var cloths: Array = []
	var bars: Array[float] = []
	var timber: Color = spec.colours.get("timber", HouseKit.COLOURS.timber)
	for block: Array in spec.blocks:
		var colour: Color = block[2]
		var extent: Vector3 = block[1]
		if _same_colour(colour, trade.board) and extent.x >= 0.06 and extent.y >= 0.2: boards += 1
		if trade.has("noren") and _same_colour(colour, trade.noren) and is_equal_approx(extent.z, 0.008): cloths.append(block)
		if _same_colour(colour, timber) and is_equal_approx(extent.x, 0.03) and is_equal_approx(extent.z, 0.03) and extent.y > 0.5: bars.append((block[0] as Vector3).x)
	var awning := false
	for lean: Dictionary in spec.lean_tos:
		if trade.has("awning") and lean.has("colour") and _same_colour(lean.colour, trade.awning): awning = true
	if boards == 0 and not awning: faults.append("nothing in its sign's colour")
	if pieces.size() < 3: faults.append("only %d pieces" % pieces.size())
	# The noren: one cloth along the rod and three panels under it, with a real slit between each two.
	if trade.has("noren"):
		var panels: Array = cloths.filter(func(block: Array) -> bool: return (block[1] as Vector3).y > 0.2)
		panels.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector3).x < (b[0] as Vector3).x)
		var slits := 0
		for n: int in range(1, panels.size()):
			var gap: float = ((panels[n][0] as Vector3).x - (panels[n][1] as Vector3).x * 0.5) - ((panels[n - 1][0] as Vector3).x + (panels[n - 1][1] as Vector3).x * 0.5)
			if gap > 0.01 and gap < 0.05: slits += 1
		if cloths.size() != 4 or panels.size() != 3 or slits != 2: faults.append("the noren is %d cloths with %d slits" % [cloths.size(), slits])
	if trade.has("lanterns"):
		var red := 0
		for drum: Array in spec.get("drums", []):
			if _same_colour(drum[4], Dress.LANTERN_RED): red += 1
		if red < 3 or red % 3 != 0 or red > 3 * int(trade.lanterns): faults.append("%d lantern parts" % red)
	if trade.has("wall") and not _same_colour(spec.colours.outer_wall, trade.wall): faults.append("the ground floor is not clad")
	if bool(trade.get("lattice", false)):
		var glazed := 0
		for window: Dictionary in spec.windows:
			if int(window.floor) == 0 and str(window.wall) == "front": glazed += 1
		bars.sort()
		var touching := 0
		for n: int in range(1, bars.size()):
			if bars[n] - bars[n - 1] < 0.06: touching += 1
		if glazed > 0 and (bars.size() < 6 or touching > 0): faults.append("the lattice is %d bars, %d of them touching" % [bars.size(), touching])
	if bool(trade.get("hood", false)) and size.x >= 4.0 and not pieces.has("extractor hood"): faults.append("no extractor hood")
	if trade.has("awning") and not awning and str(plan.features.porch) != "pent roof" and int(plan.floors) == 2 and float(plan.open.front) >= 1.6: faults.append("no awning")
	if bool(trade.get("counter", false)) and not pieces.has("counter"):
		for window: Dictionary in spec.windows:
			if int(window.floor) == 0 and str(window.wall) == "front":
				faults.append("no counter")
				break
	# What stands out front: at least the first thing, where the road does not run along the wall.
	var stood := 0
	for item: String in trade.get("out_front", []):
		if pieces.has(item): stood += 1
	if stood == 0 and float(plan.road_gap) >= 0.9 and float(plan.door_drop) == 0.0 and size.x >= 4.5: faults.append("nothing stands at the front")
	return "; ".join(PackedStringArray(faults))


func _businesses() -> void:
	var entries: Array = map.data.get("businesses", [])
	var low := 0
	var planned := 0
	var given := 0
	var signed := 0
	var own_fit_out := 0
	var unknown := {}
	var by_trade := {}
	var planned_boxes: Array[int] = []
	for entry: Dictionary in entries:
		var index := int(entry.box)
		var what := str(entry.what)
		if not Dress.TRADES.has(what): unknown[what] = true
		if not world.candidates.has(index): continue
		low += 1
		var site: Dictionary = world.site(index)
		if not bool(site.ok): continue
		planned += 1
		planned_boxes.append(index)
		var pieces: Array = site.features.get("shop_front", [])
		if str((site.get("business", {}) as Dictionary).get("what", "")) == what and str(site.features.get("business", "")) == what and str((site.get("business", {}) as Dictionary).get("type", "")) == str(entry.type): given += 1
		# (One shop may be fitted out by a module of its own instead of the trade's shop front:
		# scripts/map1/map1_upstairs_cafe.gd marks its café with features.cafe_floor. It still
		# has to carry words; what it is made of is that module's to check.)
		if site.features.has("cafe_floor"):
			own_fit_out += 1
			if not ((site.spec as Dictionary).get("signs", []) as Array).is_empty(): signed += 1
			continue
		if pieces.has("sign board") or pieces.has("word on the awning"): signed += 1
		if not by_trade.has(what): by_trade[what] = []
		(by_trade[what] as Array).append(index)
	_check(entries.size() >= 100 and unknown.is_empty() and planned >= 40 and given == planned and signed == planned and own_fit_out <= 3, "the map plan names %d businesses; %d are in low open buildings and a house can be made of %d of those: %d of the %d have their business in their plan and %d have its sign (%d of them fitted out by a module of their own, not the trade's shop front; %d are in taller buildings, which this file does not dress; %d are in boxes too small for the kit; trades the dress does not know: %d)" % [entries.size(), low, planned, given, planned, signed, own_fit_out, entries.size() - low, low - planned, unknown.size()])

	# Each trade's own pieces. A trade no low open box has is tried on two shops that have another.
	var stand_ins: Array[int] = []
	for want_floors: int in [2, 1]:
		for index: int in planned_boxes:
			var site: Dictionary = world.site(index)
			if int(site.floors) == want_floors and (want_floors == 1 or (str(site.features.porch) == "sign board" and str(site.features.setback) == "none")) and float(site.road_gap) >= 0.9 and float(site.size.x) >= 5.0:
				stand_ins.append(index)
				break
	var wrong: Array[String] = []
	var tally: Array[String] = []
	var samples := 0
	var sample_of := {}
	for what: String in Dress.TRADES:
		var plans: Array = []
		for index: int in by_trade.get(what, []): plans.append(world.site(index))
		var stood_in := plans.is_empty()
		if stood_in:
			for index: int in stand_ins: plans.append(_plan_as(index, what))
		for plan: Dictionary in plans:
			samples += 1
			var faults := _trade_faults(plan, what)
			if faults != "": wrong.append("box %d as a %s: %s" % [int(plan.index), what, faults])
		if not plans.is_empty(): sample_of[what] = plans[0]
		tally.append("%s %d%s" % [what, plans.size(), " (in no low open box: tried on two other shops)" if stood_in else ""])
	_check(samples >= planned - own_fit_out and sample_of.size() == Dress.TRADES.size() and wrong.is_empty(), "every one of %d shop fronts of the %d trades has what its trade is told by: its word in its own ink on a sign of its own colour, at least three pieces, and the trade's own (a noren of four cloths with two real slits, red lanterns, a clad ground floor, a lattice of separate bars, an extractor hood, an awning, a counter, something standing at the front): %d wrong%s" % [samples, Dress.TRADES.size(), wrong.size(), "" if wrong.is_empty() else ": " + " | ".join(PackedStringArray(wrong.slice(0, 6)))])
	_info("shop fronts by trade: " + ", ".join(PackedStringArray(tally)))
	for what: String in sample_of:
		var plan: Dictionary = sample_of[what]
		_info("%s, box %d (%d floor%s, %s): %s" % [what, int(plan.index), int(plan.floors), "s" if int(plan.floors) == 2 else "", str(plan.features.porch), ", ".join(PackedStringArray(plan.features.shop_front))])
	# No two trades have the same sign: the board's colour or the ink's differs plainly.
	var names: Array = Dress.TRADES.keys()
	var alike: Array[String] = []
	for a: int in names.size():
		for b: int in range(a + 1, names.size()):
			var first: Dictionary = Dress.TRADES[names[a]]
			var second: Dictionary = Dress.TRADES[names[b]]
			var board_gap: float = absf(first.board.r - second.board.r) + absf(first.board.g - second.board.g) + absf(first.board.b - second.board.b)
			var ink_gap: float = absf(first.ink.r - second.ink.r) + absf(first.ink.g - second.ink.g) + absf(first.ink.b - second.ink.b)
			if (board_gap < 0.3 and ink_gap < 0.3) or str(first.word) == str(second.word): alike.append("%s / %s" % [names[a], names[b]])
	_check(alike.is_empty(), "the %d trades' signs: no two have the same word, and no two the same colours (board and ink each differ by less than 0.3 in %d pairs of %d)" % [names.size(), alike.size(), names.size() * (names.size() - 1) / 2])

	# The words: cut from a Japanese font of this computer into the house's own mesh.
	var blank: Array[String] = []
	var shapes := {}
	var texts := 0
	var seen_texts := {}
	var letter_triangles := 0
	for what: String in Dress.TRADES:
		for key: String in ["word", "down", "stand"]:
			var text := str((Dress.TRADES[what] as Dictionary).get(key, ""))
			if text == "" or seen_texts.has(text): continue
			seen_texts[text] = true
			texts += 1
			var shape: Dictionary = HouseKit.sign_shape(text)
			var corners: PackedVector3Array = shape.corners
			if corners.is_empty(): blank.append(text.replace("\n", ""))
			else:
				shapes["%d/%.3f/%.3f" % [corners.size() / 3, float(shape.size.x), float(shape.size.y)]] = true
				letter_triangles += corners.size() / 3
	if blank.size() == texts:
		_info("this computer has no font with Japanese letters (tried %s): the signs are blank, and told by colour and shape alone" % ", ".join(PackedStringArray(HouseKit.SIGN_FONTS)))
	else:
		var font_file := ""
		for font_name: String in HouseKit.SIGN_FONTS:
			if font_file == "": font_file = OS.get_system_font_path(font_name, 700).get_file()
		_check(blank.is_empty() and shapes.size() == texts, "the words on the signs: all %d texts have every letter in this computer's font (%s) and are cut into shapes, each text a different shape (%d different), %d triangles a text on average; without letters: %d %s" % [texts, font_file, shapes.size(), letter_triangles / maxi(texts - blank.size(), 1), blank.size(), " ".join(PackedStringArray(blank))])

	# A shop-house with no business is what it was.
	var compared := 0
	var moved := 0
	var differ: Array[int] = []
	for entry: Array in PLAIN_SHOPS:
		var index := int(entry[0])
		if index >= (map.data.boxes as Array).size() or absf(float(map.data.boxes[index][0]) - float(entry[1])) > 0.006 or absf(float(map.data.boxes[index][2]) - float(entry[2])) > 0.006 or world.kind_of(index) != "shop" or world.businesses.has(index):
			moved += 1
			continue
		var site: Dictionary = world.site(index)
		compared += 1
		if not bool(site.ok) or HouseRules.signature(site.spec).md5_text() != str(entry[3]) or site.has("business"): differ.append(index)
	var plain_shops := 0
	var marked := 0
	for index: int in world.candidates:
		if world.kind_of(index) != "shop" or world.businesses.has(index): continue
		var site: Dictionary = world.site(index)
		if not bool(site.ok): continue
		plain_shops += 1
		if site.has("business") or site.features.has("business") or site.features.has("shop_front") or (site.spec as Dictionary).has("signs") or (site.spec as Dictionary).has("drums"): marked += 1
	_check((compared >= 3 or moved == PLAIN_SHOPS.size()) and differ.is_empty() and plain_shops > 100 and marked == 0, "a shop-house with no business is as it was: %d sampled ones are described to the letter as before the trades were made (%d differ%s; %d left out, their box has moved), and none of all %d has a sign's words, a lantern or a trade (%d have)" % [compared, differ.size(), "" if differ.is_empty() else ": boxes " + str(differ), moved, plain_shops, marked])
	# And a business changes nothing of the house but its front: the same rooms, doors, stair,
	# windows and roof. The one planned exception: a trade that hangs a noren has a sliding front
	# door where the wall leaves it room (a hinged one would swing out through the cloth), so
	# for those the front door may differ in how it opens and in nothing else. And a convenience
	# store's ground floor is its shop, behind a glass front: its ground-floor front windows may
	# differ and must include floor-length glass a metre wide or more; every other window is
	# compared exactly.
	var replanned := 0
	var planning_differs := 0
	var noren_doors := 0
	var differing: Array[String] = []
	var glass_fronts := 0
	# (2026-11-15: the glass front, first the convenience store's alone, is every goods trade's: Dress.GLASS_FRONT_TRADES.)
	# (The three are named here, not read from the game's own list: if the game drops one, this
	# check must fail for it, not shrink.)
	var glass_trades: Array[String] = ["convenience store", "grocer", "rice and liquor shop"]
	var glass_wanted := 0
	for trade: String in glass_trades:
		if sample_of.has(trade): glass_wanted += 1
	for what: String in sample_of:
		var dressed: Dictionary = sample_of[what]
		var bare := _plan_as(int(dressed.index), "")
		replanned += 1
		var noren := (Dress.TRADES.get(what, {}) as Dictionary).has("noren")
		for key: String in ["size", "floors", "partitions", "doors", "windows", "steps", "roof", "stair", "upper", "low", "recess", "loot", "gutter", "foundation"]:
			var mine: Variant = (dressed.spec as Dictionary).get(key)
			var theirs: Variant = (bare.spec as Dictionary).get(key)
			if key == "doors" and noren:
				mine = (mine as Array).duplicate(true)
				theirs = (theirs as Array).duplicate(true)
				if str((mine[0] as Dictionary).get("kind", "")) != str((theirs[0] as Dictionary).get("kind", "")): noren_doors += 1
				for door: Dictionary in [mine[0], theirs[0]]:
					door.erase("kind")
					door.erase("style")
			if key == "windows" and what in glass_trades:
				var front_glass := (mine as Array).filter(func(w: Dictionary) -> bool: return int(w.floor) == 0 and str(w.wall) == "front")
				# (Another room on the same wall, a bathroom say, may keep its small high window.)
				if front_glass.any(func(w: Dictionary) -> bool: return float(w.sill) == 0.0 and float(w.width) >= 1.0): glass_fronts += 1
				else: differing.append("%s: no glass front" % what)
				# Only the display room's own stretch of the front is set aside: the glass itself, and the
				# bare house's windows that stood where the glass now is. A front window of another room
				# (a bathroom's, say) is still compared exactly, like every other window.
				var glass := front_glass.filter(func(w: Dictionary) -> bool: return float(w.sill) == 0.0 and float(w.width) >= 1.0)
				var pane_low := INF
				var pane_high := -INF
				for pane: Dictionary in glass:
					pane_low = minf(pane_low, float(pane.at) - float(pane.width) * 0.5)
					pane_high = maxf(pane_high, float(pane.at) + float(pane.width) * 0.5)
				var in_display := func(w: Dictionary) -> bool: return int(w.floor) == 0 and str(w.wall) == "front" and float(w.at) > pane_low - 0.3 and float(w.at) < pane_high + 0.3
				mine = (mine as Array).filter(func(w: Dictionary) -> bool: return not in_display.call(w))
				theirs = (theirs as Array).filter(func(w: Dictionary) -> bool: return not in_display.call(w))
			if var_to_str(mine) != var_to_str(theirs):
				planning_differs += 1
				differing.append("%s: %s" % [what, key])
				break
	_check(replanned == Dress.TRADES.size() and planning_differs == 0 and glass_fronts == glass_wanted, "one shop of each trade planned again with its business taken away: the same rooms, doors, stair, windows, steps and roof in all %d (%d differ); only the front's fittings, signs and paint are the trade's, and on %d noren trades the front door slides, and %d of the %d trades that sell goods behind glass (convenience store, grocer, rice and liquor shop) have a glass front of floor-length windows%s" % [replanned, planning_differs, noren_doors, glass_fronts, glass_wanted, "" if differing.is_empty() else " (" + ", ".join(differing) + ")"])

	# The same picture both ways, and the same two draw calls: one shop of each trade built as
	# the outside-only house and as the full one.
	var built := 0
	var different := 0
	var glass_different := 0
	var two_meshes := 0
	var added := 0
	var most_added := 0
	var most_what := ""
	var total_triangles := 0
	for what: String in sample_of:
		var plan: Dictionary = sample_of[what]
		var full_house: Node3D = HouseKit.build(plan.spec, true)
		var look_house: Node3D = HouseKit.build_look(plan.spec)
		root.add_child(full_house)
		root.add_child(look_house)
		full_house.global_position = Vector3(3000.0, 0.0, 3000.0)
		look_house.global_position = Vector3(3000.0, 0.0, 3000.0)
		var solid_a: Array = []
		var solid_b: Array = []
		_triangles_of(full_house, full_house.global_transform, false, solid_a)
		_triangles_of(look_house, look_house.global_transform, false, solid_b)
		var glass_a := _corners_of(full_house, full_house.global_transform)
		var glass_b := _corners_of(look_house, look_house.global_transform)
		built += 1
		var lonely := _unmatched_nearest(solid_a, solid_b)
		if solid_a.is_empty() or lonely > 0:
			different += 1
			_info("%s, box %d: %d triangles without a twin (%d by the first-found pairing), of %d and %d" % [what, int(plan.index), lonely, _unmatched(solid_a, solid_b, false), solid_a.size(), solid_b.size()])
		if glass_a.size() != glass_b.size() or _unmatched(glass_a, glass_b, false) > 0: glass_different += 1
		var meshes := 0
		for child: Node in look_house.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh.get_surface_count() == 1: meshes += 1
		if look_house.get_child_count() == 2 and meshes == 2: two_meshes += 1
		var plain_look: Node3D = HouseKit.build_look(_plan_as(int(plan.index), "").spec)
		var more := int(look_house.get_meta("triangles")) - int(plain_look.get_meta("triangles"))
		plain_look.free()
		added += more
		total_triangles += int(look_house.get_meta("triangles"))
		if more > most_added:
			most_added = more
			most_what = what
		full_house.free()
		look_house.free()
	_check(built == Dress.TRADES.size() and different == 0 and glass_different == 0, "one shop of each of the %d trades built both ways: every triangle of the full house's outside (the sign's letters, the lanterns, the noren, the lattice too) has its twin in the outside-only house, in the same place to 1.5 mm, the same colour and size (%d differ in what is solid, %d in glass)" % [built, different, glass_different])
	_check(two_meshes == built, "and each outside-only shop is still two meshes of one surface each, so two draw calls as the header says (one for everything solid, the words on the signs in it; one for the glass): %d of %d. A trade's front adds %d triangles on average to a house of %d (the most: %d, the %s); no draw call, no material, no texture" % [two_meshes, built, added / maxi(built, 1), total_triangles / maxi(built, 1), most_added, most_what])