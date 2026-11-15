extends RefCounted
## Turns one grey box of the Map 1 blockout into the description of a real house for the
## interior kit (scripts/interior_kit/house_kit.gd), by rule. Nothing here is random at run
## time: every choice comes from a seed taken from the box's own position, so a house is the
## same house every time you come back to it, and no two boxes get the same seed.
##
##   var site := HouseRules.plan(world, box_index)
##   site.ok       false when the kit cannot make a house of this box; site.reason says why
##   site.spec     the kit's description
##   site.frame    where the kit house stands (its own origin is a corner of its outline)
##   site.features what it was given, in words (roof, set-back, porch, balcony, plot)
##
## What follows from the box: the outline (the box's own), the floors (what fits under the
## box's top), the roof's height (its ridge is the box's top), the street side (the side with
## a road in front of it, or else the most open side), the footing (down to the box's base)
## and the doorstep (down to the ground at the door). What follows from the seed: where the
## hall and the stair are, how the rooms are cut, the doors and windows, and everything that
## makes it one particular house (scripts/map1/map1_house_dress.gd): the roof's form and
## which way its ridge runs, whether the upper floor is set back, the porch, the balcony,
## what stands on the plot, the paint.
##
## The houses are Japanese in plan: a genkan inside the front door, its floor one step
## (0.15 m) below the hall's; the stair in the hall; a room with tatami on many ground
## floors; a bath and a toilet as small rooms of their own.
##
## `world` is scripts/map1/map1_world.gd: it answers ground(x, z), solid_at(x, z, skip) and
## road_at(x, z), and knows which boxes have a locked room.

const HouseKit := preload("res://scripts/interior_kit/house_kit.gd")
const Dress := preload("res://scripts/map1/map1_house_dress.gd")

const LOW_KINDS: Array[String] = ["house", "timber", "shop"]
## The kit's own sizes, as the layouts need them.
const T := HouseKit.WALL_OUTER
const P := HouseKit.WALL_INNER * 0.5
## A hall is as wide as the yard house's: the stair's lane, its banister, and room to walk by.
const HALL := 1.88
const GOING := HouseKit.STAIR_GOING
const RUN := 2.64                 # twelve goings: thirteen risers to the floor above
const LANDING := 1.0              # clear floor wanted at the head of a stair
const DOOR_HALF := 0.5            # half a door with its lining, and a finger of wall
const ROOM_MIN := 2.2             # no room narrower or shallower than this
const ROOM_SMALL := 1.8           # but an upper room cut short by a set-back may be this
## A genkan: this deep from the door wall, or the least where the house is small.
const GENKAN := 1.2
const GENKAN_LEAST := 0.9
## The least a box must measure for each plan (outer metres: along the street, front to back).
const SIDE_HALL_MIN := Vector2(4.4, 5.2)
const CENTRE_HALL_MIN := Vector2(6.5, 5.2)
const BACK_HALL_MIN := Vector2(5.1, 4.4)
const ONE_ROOM_MIN := Vector2(3.0, 3.0)
const BUNGALOW_HALL_MIN := Vector2(4.4, 4.0)
## Height the kit needs under the box's top: its eave for that many floors, and a little roof.
const EAVE_ONE := HouseKit.FLOOR_ABOVE_GROUND + HouseKit.CEILING_HEIGHT + HouseKit.ROOF_PLATE
const EAVE_TWO := EAVE_ONE + HouseKit.CEILING_HEIGHT + HouseKit.FLOOR_BUILD_UP
const RIDGE_CAP := HouseKit.RIDGE_TOP
const ROOF_LEAST := 0.09
## The door needs this much open ground in front of it, and no more than this fall to it.
const FRONT_CLEAR_MIN := 1.0
const DROP_MAX := 1.3
const STEP_GOING := 0.31
const REACH := 10.0
## The four sides of a box, in its own axes: the way out, and the way along the wall.
const OUTWARD: Array[Vector3] = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
const ALONG: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]


## How many floors the map plan counts for a box (tools/map_plan/encounters.py floors_of).
static func floors_of(box: Array) -> int:
	return maxi(1, roundi((float(box[4]) - 0.9) / 3.1))


## A low town building the player may enter: a house, a timber house or a shop-house of one
## or two floors that is not one of the shut ones.
static func is_low_open(kind: String, box: Array) -> bool:
	return LOW_KINDS.has(kind) and floors_of(box) <= 2


static func seed_of(box: Array) -> int:
	return hash([roundi(float(box[0]) * 100.0), roundi(float(box[2]) * 100.0)])


## The box's own axes on the ground: x along its width, z along its depth.
static func box_basis(box: Array) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(float(box[6])))


## How far a house's front stands behind a real footway's back edge: the least of it along the
## front and a little past each end (a house seldom stands quite square to its street, and its
## wall runs past its corners). INF where no built footway runs in front.
static func _plot_gap(world: Object, frame: Transform3D, wide: float) -> float:
	var map: Object = world.get("map")
	if map == null or not map.has_method("footway_gap"): return INF
	var gap := INF
	# Also a little ahead of the front, towards the street, taking off how far ahead: on a
	# straight footway square to the house that comes to the same, but where the footway curves
	# (round a turning circle) or the house stands turned to it, the garden's front corners
	# come nearer the footway than the house's own front does.
	for x: float in [-0.75, wide * 0.25, wide * 0.5, wide * 0.75, wide + 0.75]:
		for ahead: float in [0.0, 1.0, 2.0]:
			var g := float(map.footway_gap(frame * Vector3(x, 0.0, -ahead)))
			if g < INF: gap = minf(gap, g + ahead)
	return gap


static func plan(world: Object, index: int) -> Dictionary:
	var box: Array = world.boxes[index]
	var kind: String = world.kind_of(index)
	var site := {"ok": false, "reason": "", "index": index, "kind": kind, "plan_floors": floors_of(box)}
	var centre := Vector3(float(box[0]), 0.0, float(box[2]))
	var turn := box_basis(box)
	var w := float(box[3])
	var d := float(box[5])
	# The house's floor stands on the highest ground under it (and a stride round it), so the
	# ground never comes up through the floor; its footing reaches down to the box's base.
	var high := -INF
	var steps_x := maxi(2, ceili((w + 2.4) / 1.25))
	var steps_z := maxi(2, ceili((d + 2.4) / 1.25))
	for i: int in range(steps_x + 1):
		for j: int in range(steps_z + 1):
			var at: Vector3 = centre + turn * Vector3((float(i) / float(steps_x) - 0.5) * (w + 2.4), 0.0, (float(j) / float(steps_z) - 0.5) * (d + 2.4))
			high = maxf(high, world.ground(at.x, at.z))
	var origin_y := high + 0.03
	var box_top := float(box[1]) + float(box[4])
	var above := box_top - origin_y
	site["origin_y"] = origin_y
	site["above_ground"] = above
	var floors := 2 if (int(site.plan_floors) >= 2 and above >= EAVE_TWO + RIDGE_CAP + ROOF_LEAST) else 1
	if above < EAVE_ONE + RIDGE_CAP + ROOF_LEAST:
		site.reason = "too low: the box stands %.1f m above its ground and one storey with a roof needs %.1f m" % [above, EAVE_ONE + RIDGE_CAP + ROOF_LEAST]
		return site
	site["floors"] = floors
	site["one_floor_because_low"] = floors == 1 and int(site.plan_floors) >= 2

	# Which side is the street? Look out from each side: a road in front wins, the nearer the
	# better; with no road anywhere, the most open side.
	var sides: Array = []
	for side: int in range(4):
		var out: Vector3 = turn * OUTWARD[side]
		var along: Vector3 = turn * ALONG[side]
		var span := w if side % 2 == 0 else d
		var deep := d if side % 2 == 0 else w
		var clear := REACH
		var road := INF
		for share: float in [-0.3, 0.0, 0.3]:
			var from: Vector3 = centre + out * deep * 0.5 + along * span * share
			var look := _look_out(world, index, from, out)
			clear = minf(clear, float(look.clear))
			road = minf(road, float(look.road))
		sides.append({"side": side, "clear": clear, "road": road, "span": span, "deep": deep})
	sides.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_road: bool = float(a.road) < REACH
		var b_road: bool = float(b.road) < REACH
		if a_road != b_road: return a_road
		if a_road and absf(float(a.road) - float(b.road)) > 0.01: return float(a.road) < float(b.road)
		if absf(float(a.clear) - float(b.clear)) > 0.01: return float(a.clear) > float(b.clear)
		return int(a.side) < int(b.side))
	var locked: bool = world.has_locked_room(index)
	var reasons: Array[String] = []
	var walled := 0
	for candidate: Dictionary in sides:
		if float(candidate.clear) < FRONT_CLEAR_MIN:
			walled += 1
			continue
		var made := _on_side(world, site, box, candidate, kind, floors, locked)
		if bool(made.ok): return made
		if not reasons.has(str(made.reason)): reasons.append(str(made.reason))
	if walled == 4: site.reason = "walled in: no side has %.1f m of open ground for a door" % FRONT_CLEAR_MIN
	else: site.reason = reasons[0] if not reasons.is_empty() else "no side works"
	return site


## Walks out from a point on a wall. `clear`: how far before another building is met.
## `road`: how far to the first road, if one comes before that.
static func _look_out(world: Object, index: int, from: Vector3, out: Vector3) -> Dictionary:
	var road := INF
	var reach := 0.4
	while reach <= REACH:
		var at := from + out * reach
		if world.solid_at(at.x, at.z, index): return {"clear": reach - 0.4, "road": road}
		if road == INF and world.road_at(at.x, at.z): road = reach
		reach += 0.6
	return {"clear": REACH, "road": road}


## Tries to stand the house with its front on one side of the box.
static func _on_side(world: Object, base: Dictionary, box: Array, facing: Dictionary, kind: String, floors: int, locked: bool) -> Dictionary:
	var site: Dictionary = base.duplicate()
	var turn := box_basis(box)
	var side := int(facing.side)
	var out: Vector3 = turn * OUTWARD[side]
	var size := Vector2(float(facing.span), float(facing.deep))
	# The kit's own axes: z runs indoors from the front wall, x along the front.
	var yaw := atan2(-out.x, -out.z)
	var kit_basis := Basis(Vector3.UP, yaw)
	var origin_y := float(site.origin_y)
	var corner: Vector3 = Vector3(float(box[0]), origin_y, float(box[2])) - kit_basis.x * size.x * 0.5 - kit_basis.z * size.y * 0.5
	var frame := Transform3D(kit_basis, corner)
	site["frame"] = frame
	site["side"] = side
	site["size"] = size
	var two := floors == 2
	var plans: Array[String] = []
	if two:
		if size.x >= SIDE_HALL_MIN.x and size.y >= SIDE_HALL_MIN.y: plans.append_array(["side_left", "side_right"])
		if size.x >= CENTRE_HALL_MIN.x and size.y >= CENTRE_HALL_MIN.y: plans.append_array(["centre", "centre"])
		if size.x >= BACK_HALL_MIN.x and size.y >= BACK_HALL_MIN.y: plans.append_array(["back", "back"] if kind == "shop" else ["back"])
		if plans.is_empty():
			site.reason = "too small for a stair: %.1f m along the street by %.1f m deep; a stair with a room beside it needs %.1f by %.1f m, or %.1f by %.1f m with the stair across the back" % [size.x, size.y, SIDE_HALL_MIN.x, SIDE_HALL_MIN.y, BACK_HALL_MIN.x, BACK_HALL_MIN.y]
			return site
	else:
		if size.x >= BUNGALOW_HALL_MIN.x and size.y >= BUNGALOW_HALL_MIN.y: plans.append_array(["side_left", "side_right"])
		if size.x >= CENTRE_HALL_MIN.x and size.y >= BUNGALOW_HALL_MIN.y: plans.append("centre")
		if size.x >= BACK_HALL_MIN.x and size.y >= BACK_HALL_MIN.y: plans.append("back")
		if plans.is_empty():
			if size.x >= ONE_ROOM_MIN.x and size.y >= ONE_ROOM_MIN.y: plans.append("one_room")
			else:
				site.reason = "too small for a room: %.1f by %.1f m (the least is %.1f by %.1f m)" % [size.x, size.y, ONE_ROOM_MIN.x, ONE_ROOM_MIN.y]
				return site
	var seed_value := seed_of(box)
	# What this house would like to be (the seed's wishes; the plot decides what it gets).
	var wish_dice := RandomNumberGenerator.new()
	wish_dice.seed = seed_value ^ 0x5bd1e995
	var wish: Dictionary = Dress.wishes(kind, size, floors, wish_dice)
	var failure := ""
	for attempt: int in range(10):
		var dice := RandomNumberGenerator.new()
		dice.seed = seed_value + attempt * 7919
		var which: String = plans[dice.randi_range(0, plans.size() - 1)]
		# The porch cut into the front, and the genkan: as wished at first, then smaller.
		var recess := float(wish.recess) if attempt < 4 else 0.0
		var genkan := GENKAN if attempt < 7 else GENKAN_LEAST
		var layout: Dictionary
		match which:
			"centre", "side_left", "side_right": layout = _hall_plan(which, size, floors, dice, recess, genkan)
			"back": layout = _back_plan(size, floors, dice, recess, genkan, kind == "shop")
			_: layout = _one_room(size, dice)
		if layout.is_empty():
			failure = "the rooms did not fit round the stair"
			continue
		# The doorstep: is the way to the door open, and how far below the floor is the ground?
		var door_x := float(layout.door_x)
		var door_out: Vector3 = frame * Vector3(door_x, 0.0, 0.0)
		var look := _look_out(world, int(site.index), door_out, out)
		var open := float(look.clear)
		# A house with a genkan is entered at the level of its own ground: the porch is the
		# house's slab. A house without one keeps its floor's height at the door.
		var has_low: bool = not (layout.low as Array).is_empty()
		var top := 0.0 if has_low else HouseKit.FLOOR_ABOVE_GROUND
		var porch := float(layout.door_z)
		var landing := 0.0 if porch >= 0.7 else (0.9 if str(wish.front_door) == "slide" else HouseKit.STEP_LANDING)
		# On level ground a low slab. Where the ground at its outer edge lies lower, a landing
		# and steps down, as long as it takes to reach the ground.
		var drop := 0.0
		var depth := clampf(open - 0.4, 0.6, 1.2) if not has_low else clampf(open - 0.4, 0.5, 0.9)
		var sloped := false
		# (The step stands in the porch's mouth, which need not be straight out from the door.)
		var width := 1.6
		var step_x := door_x
		if porch > 0.0:
			width = minf(1.6, float(layout.recess.x1) - float(layout.recess.x0) - 0.1)
			step_x = clampf(door_x, float(layout.recess.x0) + width * 0.5, float(layout.recess.x1) - width * 0.5)
		var step_out: Vector3 = frame * Vector3(step_x, 0.0, 0.0)
		for pass_index: int in range(5):
			var edge := step_out + out * depth
			var fall := maxf(origin_y - world.ground(edge.x, edge.z), 0.0)
			if not sloped and fall <= (0.10 if has_low else 0.04): break
			sloped = true
			drop = maxf(fall, 0.05)
			var wanted := landing + float(ceili((top + drop) / HouseKit.STEP_RISE_OUTSIDE)) * STEP_GOING
			if is_equal_approx(wanted, depth): break
			depth = wanted
		if sloped:
			# The steps end where they end: measure the ground there once more.
			var foot := step_out + out * depth
			drop = maxf(origin_y - world.ground(foot.x, foot.z), 0.05)
		if drop > DROP_MAX:
			failure = "the ground falls %.1f m at the door (the most a doorstep takes is %.1f m)" % [drop, DROP_MAX]
			continue
		if open < depth + (0.4 if drop == 0.0 else STEP_GOING + 0.3):
			failure = "a neighbour stands %.1f m in front of the door; the doorstep needs %.1f m" % [open, depth + 0.4]
			continue
		var step := {"wall": "front", "at": step_x, "width": width, "depth": depth, "top": top}
		if drop > 0.0:
			step["drop"] = drop
			step["landing"] = landing
		elif has_low: step["under"] = 0.12
		var steps: Array = [step]
		site["plan"] = which
		site["door_drop"] = drop
		site["door_clear"] = open
		site["step_depth"] = depth
		site["door_z"] = porch
		site["road_gap"] = float(look.road)
		_finish(world, site, box, layout, kind, floors, locked, dice, steps, drop, wish)
		site["door_point"] = door_out + out * (depth + 0.6)
		# The street this house fronts: the strip its door faces.
		var road := float(look.road)
		site["on_road"] = road < REACH
		site["street_point"] = door_out + out * ((road + 1.5) if road < REACH else minf(open * 0.5, 3.0))
		site["street_along"] = kit_basis.x
		site["street_out"] = out
		site.ok = true
		return site
	site.reason = failure
	return site


# ---- the plans ---------------------------------------------------------------------------

static func _snap(value: float) -> float:
	return snappedf(value, 0.05)


static func _pick(dice: RandomNumberGenerator, low: float, high: float) -> float:
	if high <= low: return low
	return clampf(_snap(dice.randf_range(low, high)), low, high)


## A point in one of the stretches, or NAN when none of them overlaps low..high.
static func _pick_in(dice: RandomNumberGenerator, stretches: Array, low: float, high: float) -> float:
	var fits: Array = []
	for stretch: Vector2 in stretches:
		var a := maxf(stretch.x, low)
		var b := minf(stretch.y, high)
		if b >= a: fits.append(Vector2(a, b))
	if fits.is_empty(): return NAN
	var chosen: Vector2 = fits[dice.randi_range(0, fits.size() - 1)]
	return _pick(dice, chosen.x, chosen.y)


## A hall running from the front to the back with the stair in it, and rooms on one side
## ("side_left", "side_right") or on both ("centre"). The front of the hall is the genkan;
## with `recess` the door stands that far back from the front, in a porch as wide as the hall.
static func _hall_plan(which: String, size: Vector2, floors: int, dice: RandomNumberGenerator, recess: float, genkan: float) -> Dictionary:
	var two := floors == 2
	var zg := recess + T + genkan      # where the genkan ends and the hall's floor begins
	if size.y < zg + (3.0 if recess > 0.0 else 1.6): return {}
	var west_face: float      # the hall's two faces
	match which:
		"side_left": west_face = T
		"side_right": west_face = size.x - T - HALL
		_: west_face = _pick(dice, T + ROOM_MIN + P * 2.0, size.x - T - ROOM_MIN - P * 2.0 - HALL)
	var east_face := west_face + HALL
	var west_strip := which != "side_left"
	var east_strip := which != "side_right"
	var partitions: Array = []
	if west_strip: partitions.append({"id": "west", "floors": [0, 1], "a": Vector2(west_face - P, T), "b": Vector2(west_face - P, size.y - T)})
	if east_strip: partitions.append({"id": "east", "floors": [0, 1], "a": Vector2(east_face + P, T), "b": Vector2(east_face + P, size.y - T)})
	var whole: Array = [Vector2(0.85, size.y - 0.85)]
	var west_doors: Array = whole
	var east_doors: Array = whole
	var layout := {"partitions": partitions, "doors": [], "rooms": [], "route": [], "plan": which, "front_clip": recess + T if recess > 0.0 else 0.0}
	# The door stands to one side of the hall, so the shoe cupboard has the other.
	var door_west := dice.randf() < 0.5
	var door_x := 0.0
	var route: Array = []
	if two:
		var east_stair := dice.randf() < 0.5
		for attempt: int in range(2):
			if east_stair:
				# Against the east face, climbing towards the front: you walk past it to its foot.
				var low := maxf(T + LANDING + RUN + 0.1, zg + RUN + 0.1)
				var high := size.y - T - GOING - 0.9
				if high < low:
					east_stair = false
					continue
				var start := _pick(dice, low, high)
				layout["stair"] = {"x": east_face, "z": start, "dir": "-z"}
				east_doors = [Vector2(0.85, start - RUN - 0.6), Vector2(start + GOING + 0.65, size.y - 0.85)]
				door_x = west_face + 0.52
				route = [Vector2(door_x, recess + T + 0.55), Vector2(west_face + 0.5, zg + 0.5), Vector2(west_face + 0.5, start + GOING + 0.5), Vector2(east_face - 0.4, start + GOING + 0.5), Vector2(east_face - 0.4, start - RUN - 0.5)]
				layout["up_from"] = 4
				break
			else:
				# Against the west face, climbing towards the back.
				var low := maxf(2.3 if west_strip else 1.3, zg + 1.25)
				var high := size.y - T - LANDING - RUN
				if high < low:
					east_stair = true
					continue
				var start := _pick(dice, low, high)
				layout["stair"] = {"x": west_face, "z": start, "dir": "+z"}
				west_doors = [Vector2(0.85, start - 1.05), Vector2(start + RUN + 0.65, size.y - 0.85)]
				door_x = west_face + 0.52 if door_west else east_face - 0.52
				route = [Vector2(door_x, recess + T + 0.55), Vector2(door_x, zg + 0.5), Vector2(west_face + 0.4, start - GOING - 0.5), Vector2(west_face + 0.4, start + RUN + 0.5)]
				layout["up_from"] = 3
				break
		if not layout.has("stair"): return {}
	else:
		door_x = west_face + 0.52 if door_west else east_face - 0.52
		route = [Vector2(door_x, recess + T + 0.55), Vector2(door_x, zg + 0.5), Vector2((west_face + east_face) * 0.5, maxf(size.y * 0.5, zg + 0.9))]
	layout["door_x"] = door_x
	layout["door_z"] = recess
	layout["route"] = route
	layout["low_points"] = 1
	layout["hall"] = Rect2(west_face, T, HALL, size.y - T * 2.0)
	layout["hall_front_free"] = not two or str(layout.stair.dir) == "+z" or float(layout.stair.z) - RUN - T >= 1.0
	layout["genkan"] = Rect2(west_face, recess + T, HALL, genkan)
	layout["genkan_free_x"] = east_face - 0.36 if door_x < west_face + HALL * 0.5 else west_face + 0.01
	var low_parts: Array = [layout.genkan, Rect2(door_x - 0.47, recess, 0.94, T)]
	if recess > 0.0:
		var notch := {"x0": 0.0 if which == "side_left" else west_face, "x1": size.x if which == "side_right" else east_face, "depth": recess}
		layout["recess"] = notch
		low_parts.append(Rect2(float(notch.x0), 0.0, float(notch.x1) - float(notch.x0), recess))
	layout["low"] = low_parts
	layout["ramps"] = [{"at": Vector2(west_face + HALL * 0.5, zg), "width": HALL, "dir": "+z"}]
	layout["kamachi"] = [[Vector2(west_face, zg - 0.015), Vector2(east_face, zg - 0.015)]]
	for strip: String in ["west", "east"]:
		if (strip == "west" and not west_strip) or (strip == "east" and not east_strip): continue
		var x0 := T if strip == "west" else east_face + P * 2.0
		var x1 := west_face - P * 2.0 if strip == "west" else size.x - T
		if not _strip_rooms(layout, strip, x0, x1, size, floors, west_doors if strip == "west" else east_doors, dice, zg + 0.6): return {}
	return layout


## Cuts one strip beside the hall into rooms on every floor and hangs each on a door. On the
## ground floor no door opens onto the genkan: the first is `low0` from the front.
static func _strip_rooms(layout: Dictionary, strip: String, x0: float, x1: float, size: Vector2, floors: int, stretches: Array, dice: RandomNumberGenerator, low0: float) -> bool:
	var inside := size.y - T * 2.0
	var cut_at := _pick(dice, maxf(size.y * 0.40, T + ROOM_MIN + P), minf(size.y * 0.60, size.y - T - ROOM_MIN - P))
	var can_cut := inside >= ROOM_MIN * 2.0 + P * 2.0
	var cut_floors: Array = []
	for level: int in range(floors):
		if can_cut and dice.randf() < 0.75: cut_floors.append(level)
	if not cut_floors.is_empty():
		(layout.partitions as Array).append({"id": strip + "_cross", "floors": cut_floors, "a": Vector2(x0, cut_at), "b": Vector2(x1, cut_at)})
	var hall_swing := 1 if strip == "west" else -1
	var hall_hinge := "low" if strip == "west" else "high"
	for level: int in range(floors):
		var spans: Array = [Vector2(T, size.y - T)]
		if cut_floors.has(level): spans = [Vector2(T, cut_at - P), Vector2(cut_at + P, size.y - T)]
		var entries: Array = []
		for span: Vector2 in spans: entries.append(_pick_in(dice, stretches, maxf(span.x + 0.6, low0 if level == 0 else 0.0), span.y - 0.6))
		for index: int in range(spans.size()):
			var span: Vector2 = spans[index]
			var label := "%s%d_%d" % [strip, level, index]
			var room := {"name": label, "floor": level, "rect": Rect2(x0, span.x, x1 - x0, span.y - span.x), "door": label, "own_door": true, "leads_on": false}
			if not is_nan(float(entries[index])):
				(layout.doors as Array).append({"name": label, "wall": strip, "floor": level, "at": float(entries[index]), "swing": hall_swing, "hinge": hall_hinge})
			else:
				# No stretch of the hall wall is free here (the stair runs along it, or the
				# genkan lies in front of it): this room is reached through the one next to it.
				var other := 1 - index
				if spans.size() < 2 or is_nan(float(entries[other])): return false
				var back := index == 1
				(layout.doors as Array).append({"name": label, "wall": strip + "_cross", "floor": level, "at": _pick(dice, x0 + 0.6, x1 - 0.6), "swing": 1 if back else -1, "hinge": "low" if back else "high"})
				room.own_door = false
			(layout.rooms as Array).append(room)
		# A room that another is reached through is not one to lock.
		if spans.size() == 2:
			var rooms: Array = layout.rooms
			for index: int in range(2):
				if not bool(rooms[rooms.size() - 2 + index].own_door): rooms[rooms.size() - 1 - index].leads_on = true
	return true


## The hall and the stair across the back; the rooms at the front, on the street. On the
## ground floor you come in through a front room. In a house its corner at the door is the
## genkan. In a shop-house that room is the shop: its whole floor lies at the level of the
## street, and the step up into the house is at the door behind it.
static func _back_plan(size: Vector2, floors: int, dice: RandomNumberGenerator, recess: float, genkan: float, shop: bool) -> Dictionary:
	var two := floors == 2
	var mid := size.y - T - HALL - P
	var layout := {"partitions": [{"id": "mid", "floors": [0, 1], "a": Vector2(T, mid), "b": Vector2(size.x - T, mid)}], "doors": [], "rooms": [], "route": [], "plan": "back", "front_clip": 0.0}
	var walk := mid + P + 0.5
	var start := 0.0
	if two:
		var low := 1.3
		var high := size.x - T - LANDING - RUN
		if high < low: return {}
		start = _pick(dice, low, high)
		layout["stair"] = {"x": start, "z": size.y - T, "dir": "+x"}
	layout["hall"] = Rect2(T, mid + P, size.x - T * 2.0, HALL)
	layout["hall_front_free"] = false
	var inside := size.x - T * 2.0
	var count := 1
	if inside >= ROOM_MIN * 2.0 + P * 2.0 + 0.6: count = 2 if dice.randf() < 0.8 else 1
	if inside >= 9.0 and dice.randf() < 0.5: count = 3
	var entry_x := 0.0
	var entry_door := ""
	var entry_rect := Rect2()
	for level: int in range(floors):
		var here := count if (level == 0 or dice.randf() < 0.7) else maxi(1, count - 1)
		var edges: Array = [T]
		for index: int in range(1, here):
			var even := T + inside * float(index) / float(here)
			edges.append(_pick(dice, even - 0.5, even + 0.5))
		edges.append(size.x - T)
		for index: int in range(1, here):
			(layout.partitions as Array).append({"id": "split%d_%d" % [level, index], "floors": [level], "a": Vector2(float(edges[index]), T), "b": Vector2(float(edges[index]), mid - P)})
		var entered := dice.randi_range(0, here - 1)
		for index: int in range(here):
			var x0 := float(edges[index]) + (P if index > 0 else 0.0)
			var x1 := float(edges[index + 1]) - (P if index < here - 1 else 0.0)
			if x1 - x0 < ROOM_MIN - 0.01: return {}
			var label := "front%d_%d" % [level, index]
			var at := _pick(dice, x0 + 0.6, x1 - 0.6)
			(layout.doors as Array).append({"name": label, "wall": "mid", "floor": level, "at": at, "swing": -1, "hinge": "high"})
			var is_entry := level == 0 and index == entered
			(layout.rooms as Array).append({"name": label, "floor": level, "rect": Rect2(x0, T, x1 - x0, mid - P - T), "door": label, "own_door": true, "leads_on": is_entry, "entry": is_entry})
			if is_entry:
				layout["door_x"] = _pick(dice, x0 + 0.6, x1 - 0.6)
				entry_x = at
				entry_door = label
				entry_rect = Rect2(x0, T, x1 - x0, mid - P - T)
	var door_x := float(layout.door_x)
	var route: Array = []
	layout["low"] = []
	layout["door_z"] = 0.0
	layout["low_points"] = 0
	if shop:
		layout["low"] = [entry_rect, Rect2(door_x - 0.47, 0.0, 0.94, T), Rect2(entry_x - 0.47, mid - P, 0.94, P * 2.0)]
		layout["ramps"] = [{"at": Vector2(entry_x, mid + P), "width": 0.94, "dir": "+z"}]
		layout["sunk_doors"] = [entry_door]
		layout["shop_room"] = entry_door
		layout["low_points"] = 2
		route = [Vector2(door_x, 0.8), Vector2(entry_x, maxf(mid - 1.9, 0.75)), ["open", entry_door], Vector2(entry_x, walk)]
	else:
		# The genkan: a corner of the entry room at the door, as deep as the room allows.
		var porch := recess
		if entry_rect.size.x < 1.7 + T * 2.0 + 1.3: porch = 0.0
		var deep := genkan
		if mid - 1.9 < porch + T + deep + 0.45: porch = 0.0
		if mid - 1.9 < T + deep + 0.45: deep = GENKAN_LEAST
		if mid - 1.9 < T + deep + 0.45: deep = 0.0
		if deep > 0.0:
			if porch > 0.0: door_x = _pick(dice, entry_rect.position.x + 0.85 + T + 0.65, entry_rect.end.x - 0.85 - T - 0.65)
			else: door_x = clampf(door_x, entry_rect.position.x + 0.52, entry_rect.end.x - 0.52)
			layout["door_x"] = door_x
			var zg := porch + T + deep
			var sides := _genkan_in_room(layout, entry_rect, door_x, porch, deep)
			if porch > 0.0:
				layout["recess"] = {"x0": float(sides.x), "x1": float(sides.y), "depth": porch}
				(layout.low as Array).append(Rect2(float(sides.x), 0.0, float(sides.y) - float(sides.x), porch))
				layout["door_z"] = porch
			layout["low_points"] = 1
			route = [Vector2(door_x, porch + T + 0.5), Vector2(door_x, zg + 0.5), Vector2(entry_x, maxf(mid - 1.9, zg + 0.5)), ["open", entry_door], Vector2(entry_x, walk)]
		else:
			route = [Vector2(door_x, 0.8), Vector2(entry_x, maxf(mid - 1.9, 0.75)), ["open", entry_door], Vector2(entry_x, walk)]
	layout["up_from"] = -1
	if two:
		route.append_array([Vector2(start - GOING - 0.5, walk), Vector2(start - GOING - 0.5, size.y - T - 0.4), Vector2(start + RUN + 0.5, size.y - T - 0.4)])
		layout["up_from"] = route.size() - 1
	layout["route"] = route
	return layout


## A genkan in the corner of a room, in front of the door: its rectangle, the lower floor,
## the ramp at its inner edge and the edge boards on its open sides. Returns its x range.
static func _genkan_in_room(layout: Dictionary, room: Rect2, door_x: float, porch: float, deep: float) -> Vector2:
	var x0 := door_x - 0.85
	var x1 := door_x + 0.85
	var open_left := true
	var open_right := true
	if porch == 0.0:
		if x0 - room.position.x < 0.5:
			x0 = room.position.x
			open_left = false
		if room.end.x - x1 < 0.5:
			x1 = room.end.x
			open_right = false
	var z0 := porch + T
	var zg := z0 + deep
	layout["genkan"] = Rect2(x0, z0, x1 - x0, deep)
	layout["genkan_free_x"] = (x1 - 0.36 if door_x - x0 < x1 - door_x else x0 + 0.01) if (not open_left or not open_right or porch > 0.0) else NAN
	(layout.low as Array).append_array([layout.genkan, Rect2(door_x - 0.47, porch, 0.94, T)])
	layout["ramps"] = [{"at": Vector2((x0 + x1) * 0.5, zg), "width": x1 - x0, "dir": "+z"}]
	var boards: Array = [[Vector2(x0, zg - 0.015), Vector2(x1, zg - 0.015)]]
	if open_left and porch == 0.0: boards.append([Vector2(x0 + 0.015, z0), Vector2(x0 + 0.015, zg)])
	if open_right and porch == 0.0: boards.append([Vector2(x1 - 0.015, z0), Vector2(x1 - 0.015, zg)])
	layout["kamachi"] = boards
	return Vector2(x0, x1)


static func _one_room(size: Vector2, dice: RandomNumberGenerator) -> Dictionary:
	var door_x := _pick(dice, T + 0.6, size.x - T - 0.6)
	var room := Rect2(T, T, size.x - T * 2.0, size.y - T * 2.0)
	var layout := {"partitions": [], "doors": [], "rooms": [{"name": "room", "floor": 0, "rect": room, "door": "front", "own_door": true, "leads_on": false, "entry": true}],
		"route": [Vector2(door_x, 0.8), Vector2(size.x * 0.5, size.y * 0.5)], "plan": "one_room", "door_x": door_x, "door_z": 0.0, "up_from": -1, "hall": Rect2(), "hall_front_free": false, "low": [], "low_points": 0, "front_clip": 0.0}
	if size.y >= 3.6:
		_genkan_in_room(layout, room, door_x, 0.0, GENKAN_LEAST)
		layout["route"] = [Vector2(door_x, T + 0.5), Vector2(size.x * 0.5, maxf(size.y * 0.5, T + GENKAN_LEAST + 0.6))]
		layout["low_points"] = 1
	return layout


# ---- the upper floor set back -------------------------------------------------------------

## Can the upper floor's walls stand `inset` in from the ground floor's (front, back, left,
## right)? The stair, its landing, every upper room and its door must still fit. With
## `apply` the layout's upper rooms and inner walls are cut to the smaller floor.
static func fit_upper(layout: Dictionary, size: Vector2, inset: Dictionary, apply: bool) -> bool:
	var inner := Rect2(float(inset.left) + T, float(inset.front) + T, size.x - float(inset.left) - float(inset.right) - T * 2.0, size.y - float(inset.front) - float(inset.back) - T * 2.0)
	var old := Rect2(T, T, size.x - T * 2.0, size.y - T * 2.0)
	if layout.has("stair"):
		var stair: Dictionary = layout.stair
		var sx := float(stair.x)
		var sz := float(stair.z)
		var well: Rect2
		match str(stair.dir):
			"+z": well = Rect2(sx, sz - GOING, 0.89, RUN + GOING + LANDING)
			"-z": well = Rect2(sx - 0.89, sz - RUN - LANDING, 0.89, RUN + GOING + LANDING)
			_: well = Rect2(sx - GOING, sz - 0.89, RUN + GOING + LANDING, 0.89)
		if not inner.grow(0.005).encloses(well): return _no(layout, 1)
	var route: Array = layout.route
	for n: int in range(maxi(int(layout.get("up_from", -1)), 0), route.size()):
		if int(layout.get("up_from", -1)) < 0: break
		if route[n] is Vector2 and not inner.grow(-0.3).has_point(route[n]): return _no(layout, 2)
	var walls := {}
	for part: Dictionary in layout.partitions:
		if not (part.floors as Array).has(1): continue
		var a: Vector2 = part.a
		var b: Vector2 = part.b
		if is_equal_approx(a.x, b.x):
			if a.x < inner.position.x + ROOM_SMALL and a.x > old.position.x + 0.5 and float(inset.left) > 0.0: return _no(layout, 3)
			if a.x > inner.end.x - ROOM_SMALL and a.x < old.end.x - 0.5 and float(inset.right) > 0.0: return _no(layout, 4)
			if a.x <= inner.position.x or a.x >= inner.end.x: return _no(layout, 5)
			a.y = clampf(a.y, inner.position.y, inner.end.y)
			b.y = clampf(b.y, inner.position.y, inner.end.y)
		else:
			if a.y < inner.position.y + ROOM_SMALL and float(inset.front) > 0.0: return _no(layout, 6)
			if a.y > inner.end.y - ROOM_SMALL and float(inset.back) > 0.0: return _no(layout, 7)
			a.x = clampf(a.x, inner.position.x, inner.end.x)
			b.x = clampf(b.x, inner.position.x, inner.end.x)
		if a.distance_to(b) < 0.6: return _no(layout, 8)
		walls[str(part.id)] = [a, b]
	var rooms: Array = []
	for room: Dictionary in layout.rooms:
		if int(room.floor) != 1: continue
		var rect: Rect2 = (room.rect as Rect2).intersection(inner)
		if rect.size.x < ROOM_SMALL or rect.size.y < ROOM_SMALL: return _no(layout, 9)
		rooms.append([room, rect])
	for door: Dictionary in layout.doors:
		if int(door.floor) != 1 or not walls.has(str(door.wall)): continue
		var line: Array = walls[str(door.wall)]
		var along_z := is_equal_approx((line[0] as Vector2).x, (line[1] as Vector2).x)
		var from := minf(line[0].y, line[1].y) if along_z else minf(line[0].x, line[1].x)
		var to := maxf(line[0].y, line[1].y) if along_z else maxf(line[0].x, line[1].x)
		if float(door.at) < from + 0.58 or float(door.at) > to - 0.58: return _no(layout, 10)
	if apply:
		layout["upper_walls"] = walls
		for pair: Array in rooms: pair[0]["rect"] = pair[1]
	return true


static func _no(layout: Dictionary, why: int) -> bool:
	layout["fit_fail"] = why
	return false


# ---- from a plan to the kit's description ------------------------------------------------

static func _finish(world: Object, site: Dictionary, box: Array, layout: Dictionary, kind: String, floors: int, locked: bool, dice: RandomNumberGenerator, steps: Array, drop: float, wish: Dictionary) -> void:
	var size: Vector2 = site.size
	var frame: Transform3D = site.frame
	var index := int(site.index)
	var look := RandomNumberGenerator.new()
	look.seed = seed_of(box) ^ 0x2545f491
	var has_low: bool = not (layout.low as Array).is_empty()
	var front := {"name": "front", "wall": "entry" if float(layout.door_z) > 0.0 else "front", "floor": 0, "at": float(layout.door_x), "swing": -1, "hinge": "high", "front": true}
	if has_low: front["sunk"] = HouseKit.FLOOR_ABOVE_GROUND
	if str(wish.front_door) == "slide":
		front["kind"] = "slide"
		front["style"] = "slide"
	var doors: Array = [front]
	for door: Dictionary in layout.doors:
		door["style"] = "flush"
		if (layout.get("sunk_doors", []) as Array).has(str(door.name)): door["sunk"] = HouseKit.FLOOR_ABOVE_GROUND
		# Sliding doors indoors where a Japanese house has them: all through an older house,
		# on the ground floor of a newer one.
		if kind == "timber" or (int(door.floor) == 0 and bool(wish.slide_inside)):
			door["kind"] = "slide"
			door["style"] = "slide"
		doors.append(door)
	# How open each side is, for windows, eaves, the balcony and what stands on the plot.
	var open := {}
	for wall: String in ["front", "right", "back", "left"]:
		var least := REACH
		for share: float in [0.25, 0.5, 0.75]:
			least = minf(least, wall_clear(world, index, frame, size, wall, share * (size.x if wall in ["front", "back"] else size.y)))
		open[wall] = least
	# The upper floor set back, on the sides the seed wishes and the plan allows.
	var inset := {"front": 0.0, "back": 0.0, "left": 0.0, "right": 0.0}
	if floors == 2 and bool(wish.setback):
		var given := 0
		for side: String in wish.setback_sides:
			if given >= (2 if bool(wish.setback_two) else 1): break
			for amount: float in [float(wish.setback_amount), 0.9]:
				var trial: Dictionary = inset.duplicate()
				trial[side] = amount
				if fit_upper(layout, size, trial, false):
					inset = trial
					given += 1
					break
	if floors == 2 and not fit_upper(layout, size, inset, true):
		# (Cannot happen for walls that are not set back; kept so a house is never left half made.)
		inset = {"front": 0.0, "back": 0.0, "left": 0.0, "right": 0.0}
		layout["upper_walls"] = {}
	# The inner walls, floor by floor: the ground floor's stop at a porch cut into the front,
	# the upper floor's at its own walls.
	var partitions: Array = []
	var clip := float(layout.front_clip)
	for part: Dictionary in layout.partitions:
		var levels: Array = part.floors
		if levels.has(0):
			var a: Vector2 = part.a
			var b: Vector2 = part.b
			if clip > 0.0 and is_equal_approx(a.x, b.x):
				a.y = maxf(a.y, clip)
				b.y = maxf(b.y, clip)
			partitions.append({"id": part.id, "floors": [0], "a": a, "b": b})
		if levels.has(1) and floors == 2 and (layout.upper_walls as Dictionary).has(str(part.id)):
			var line: Array = layout.upper_walls[str(part.id)]
			partitions.append({"id": part.id, "floors": [1], "a": line[0], "b": line[1]})
	# Which room is locked: one of the top floor's rooms with a door of its own off the hall.
	var locked_room := ""
	if locked:
		var choices: Array = []
		for room: Dictionary in layout.rooms:
			if int(room.floor) == floors - 1 and bool(room.own_door) and not bool(room.leads_on) and str(room.door) != "front": choices.append(room)
		if choices.is_empty():
			for room: Dictionary in layout.rooms:
				if bool(room.own_door) and not bool(room.leads_on) and str(room.door) != "front": choices.append(room)
		if choices.is_empty(): locked_room = "front"      # a one-room house: the house is the room
		else: locked_room = str(choices[dice.randi_range(0, choices.size() - 1)].door)
		for door: Dictionary in doors:
			if str(door.name) == locked_room: door["locked"] = true
	# Everything that makes it this house and no other.
	var rise := float(site.above_ground) - (EAVE_TWO if floors == 2 else EAVE_ONE) - RIDGE_CAP
	var c := {
		"world": world, "index": index, "frame": frame, "size": size, "floors": floors, "kind": kind, "wish": wish, "look": look,
		"layout": layout, "doors": doors, "partitions": partitions, "rooms": layout.rooms, "steps": steps, "drop": drop,
		"open": open, "inset": inset, "origin_y": float(site.origin_y), "rise": rise, "locked_room": locked_room,
		"road_gap": float(site.road_gap), "door_clear": float(site.door_clear), "step_depth": float(site.step_depth),
		# Where a street has a real footway, the plot ends at the footway's back: how far that is
		# from the house's front (INF where there is none).
		"plot_gap": _plot_gap(world, frame, size.x),
		"windows": [], "blocks": [], "wheels": [], "lean_tos": [], "items": [], "features": {}, "clear": wall_clear,
		"drums": [], "signs": [],
	}
	# A shop-house the map plan names a business in is dressed as that trade's shop.
	var business: Dictionary = world.business_of(index) if world.has_method("business_of") else {}
	if kind == "shop" and not business.is_empty(): c["business"] = {"type": str(business.get("type", "")), "what": str(business.get("what", ""))}
	Dress.dress(c)
	var loot: Array = []
	for room: Dictionary in layout.rooms:
		if bool(room.get("small", false)): continue
		var rect: Rect2 = room.rect
		loot.append({"floor": int(room.floor), "at": rect.get_center(), "tier": "locked_room" if (locked and str(room.door) == locked_room) else "ordinary"})
	var spec := {
		"id": "House_%d" % index, "size": size, "floors": floors, "partitions": c.partitions,
		"doors": doors, "windows": c.windows, "steps": steps, "loot": loot, "roof": c.roof,
		"foundation": float(site.origin_y) - float(box[1]), "colours": c.colours,
		"blocks": c.blocks, "wheels": c.wheels, "lean_tos": c.lean_tos, "gutter": {"pipe": int(c.pipe)},
	}
	if floors == 2: spec["upper"] = inset
	# (Only a business has these: a house without one is described exactly as before.)
	if not (c.drums as Array).is_empty(): spec["drums"] = c.drums
	if not (c.signs as Array).is_empty(): spec["signs"] = c.signs
	if c.has("business"): site["business"] = c.business
	if has_low:
		spec["low"] = layout.low
		spec["ramps"] = layout.get("ramps", [])
		spec["kamachi"] = layout.get("kamachi", [])
	if layout.has("recess"): spec["recess"] = layout.recess
	if layout.has("stair"): spec["stair"] = layout.stair
	site["spec"] = spec
	site["route"] = layout.route
	site["up_from"] = int(layout.get("up_from", -1))
	site["low_points"] = int(layout.get("low_points", 0))
	site["locked_door"] = locked_room
	site["rooms"] = (layout.rooms as Array).size()
	site["open"] = open
	site["features"] = c.features
	site["ridge"] = float(site.origin_y) + (EAVE_TWO if floors == 2 else EAVE_ONE) + float(c.roof.wall_extra) + float(c.roof.pitch) * float(c.roof_half) + float(c.roof_top)


## How far it is from a point on one of the house's outer walls to the next building.
static func wall_clear(world: Object, index: int, frame: Transform3D, size: Vector2, wall: String, at: float) -> float:
	var from: Vector3
	var out: Vector3
	match wall:
		"front":
			from = Vector3(at, 0.0, 0.0)
			out = Vector3(0, 0, -1)
		"back":
			from = Vector3(at, 0.0, size.y)
			out = Vector3(0, 0, 1)
		"left":
			from = Vector3(0.0, 0.0, at)
			out = Vector3(-1, 0, 0)
		_:
			from = Vector3(size.x, 0.0, at)
			out = Vector3(1, 0, 0)
	return float(_look_out(world, index, frame * from, frame.basis * out).clear)


## The description as text, to tell two houses apart: everything but the name.
static func signature(spec: Dictionary) -> String:
	var copy: Dictionary = spec.duplicate()
	copy.erase("id")
	return var_to_str(copy)
