extends RefCounted
## What makes a Map 1 house one particular Japanese house (called by map1_house_rules.gd
## once its rooms are laid out). All of it by rule, from the house's kind, its box, the
## ground and the neighbours round it, and its own seed:
##
##   kind      "house"   an ordinary newer detached house: pale siding, a tiled gable or hip
##                       roof, aluminium sliding windows, a hinged front door
##             "timber"  an older timber house: dark boards and pale plaster, deep eaves, a
##                       hip-and-gable roof on the bigger ones, a sliding front door, an
##                       engawa edge on the garden side
##             "shop"    a shop-house: the ground floor open to the street behind sliding
##                       glass with a shutter box and a blank sign board over it, home above
##   roof      form by kind, size and seed; the ridge along the longer side (the shorter
##             span), turned on some; a shop's along the street; pitch from the box's height
##   set-back  the upper floor smaller than the ground floor on one or two sides where the
##             rooms and the stair allow, with a lean-to roof (geya) over what is left
##   entrance  a porch cut into the front, or a roof or canopy over the door; inside, a genkan
##   windows   sliding sashes in the sizes they are made in; floor-length ones (hakidashi)
##             onto the balcony and the garden side; small high ones for bath and toilet
##   balcony   on the sunniest wall of the upper floor that has the room
##   indoors   kitchen counter in the biggest ground-floor room, a tatami room with its
##             closet, bath and toilet, a shoe cupboard in the genkan, closets upstairs
##   the plot  air-conditioner unit, water heater and gas meter, mailbox, a block wall with
##             gate pillars, a carport, bicycles: each only where there is room for it
##   a trade   a shop-house the map plan names a business in (c.business = {type, what}) gets
##             that trade's shop front: its sign in its own colours with the trade's word on
##             it, and what such a shop has at its door (TRADES, _shop_front). A shop-house
##             with no business is as it was: a blank sign board.
##
## Everything is a real part with a real size. Nothing is drawn on a surface.

const HouseKit := preload("res://scripts/interior_kit/house_kit.gd")

const T := HouseKit.WALL_OUTER
const P := HouseKit.WALL_INNER * 0.5
const UpstairsCafe := preload("res://scripts/map1/map1_upstairs_cafe.gd")
const L0 := HouseKit.FLOOR_ABOVE_GROUND
const L1 := L0 + HouseKit.CEILING_HEIGHT + HouseKit.FLOOR_BUILD_UP
const EAVE_ONE := L0 + HouseKit.CEILING_HEIGHT + HouseKit.ROOF_PLATE
const EAVE_TWO := EAVE_ONE + HouseKit.CEILING_HEIGHT + HouseKit.FLOOR_BUILD_UP
const SIDES: Array[String] = ["front", "right", "back", "left"]
## The bath and toilet stand in a strip this deep along one side of a room.
const CABIN := 1.75
## Sash widths as they are made (the 069, 119, 165 and 256 sizes).
const SASH_SMALL := 0.73
const SASH_MID := 1.235
const SASH_WIDE := 1.69
const SASH_DOUBLE := 2.6

const WALLS := {
	"house": [Color(0.74, 0.73, 0.69), Color(0.74, 0.73, 0.69), Color(0.76, 0.75, 0.72), Color(0.85, 0.84, 0.80), Color(0.83, 0.82, 0.77), Color(0.79, 0.74, 0.64), Color(0.77, 0.73, 0.65), Color(0.68, 0.69, 0.69), Color(0.66, 0.59, 0.50), Color(0.36, 0.30, 0.25), Color(0.83, 0.79, 0.69), Color(0.60, 0.64, 0.66)],
	"timber": [Color(0.27, 0.21, 0.16), Color(0.33, 0.26, 0.20), Color(0.22, 0.19, 0.17), Color(0.38, 0.30, 0.22), Color(0.30, 0.25, 0.21)],
	"shop": [Color(0.76, 0.74, 0.70), Color(0.70, 0.66, 0.60), Color(0.80, 0.76, 0.66), Color(0.64, 0.65, 0.66), Color(0.84, 0.82, 0.78), Color(0.58, 0.52, 0.46), Color(0.72, 0.71, 0.67)],
}
const PLASTER: Array[Color] = [Color(0.86, 0.84, 0.78), Color(0.80, 0.78, 0.71), Color(0.74, 0.71, 0.64), Color(0.83, 0.80, 0.72)]
const ROOFS: Array[Color] = [Color(0.21, 0.22, 0.23), Color(0.21, 0.22, 0.23), Color(0.24, 0.25, 0.26), Color(0.19, 0.19, 0.20), Color(0.20, 0.17, 0.15), Color(0.23, 0.19, 0.16), Color(0.40, 0.41, 0.42), Color(0.36, 0.37, 0.38), Color(0.31, 0.23, 0.18), Color(0.19, 0.26, 0.34), Color(0.21, 0.30, 0.26)]
const FRAMES: Array[Color] = [Color(0.20, 0.18, 0.17), Color(0.20, 0.18, 0.17), Color(0.17, 0.17, 0.18), Color(0.60, 0.61, 0.62), Color(0.56, 0.57, 0.58), Color(0.84, 0.84, 0.83)]
const FRONT_DOORS: Array[Color] = [Color(0.25, 0.17, 0.12), Color(0.30, 0.22, 0.16), Color(0.22, 0.16, 0.13), Color(0.18, 0.18, 0.19), Color(0.16, 0.22, 0.19), Color(0.45, 0.33, 0.22)]
const GUTTERS: Array[Color] = [Color(0.25, 0.21, 0.18), Color(0.78, 0.78, 0.76), Color(0.42, 0.43, 0.44), Color(0.20, 0.20, 0.21)]
const CURTAINS: Array[Color] = [Color(0.84, 0.82, 0.76), Color(0.78, 0.78, 0.74), Color(0.70, 0.72, 0.70), Color(0.76, 0.70, 0.62)]
const APPLIANCE := Color(0.84, 0.84, 0.82)
const BLOCK_WALL := Color(0.60, 0.60, 0.58)
const STEEL := Color(0.52, 0.53, 0.54)
const FUSUMA := Color(0.87, 0.85, 0.78)
const TATAMI := Color(0.62, 0.61, 0.45)
const CABINET := Color(0.82, 0.80, 0.75)
const SANITARY := Color(0.88, 0.88, 0.86)


## What a house of this kind and size would like to be. The plot and the plan decide later
## how much of it there is room for.
static func wishes(kind: String, size: Vector2, floors: int, dice: RandomNumberGenerator) -> Dictionary:
	var wish := {}
	var short := minf(size.x, size.y)
	var aspect := maxf(size.x, size.y) / short
	var roll := dice.randf()
	match kind:
		"timber": wish["form"] = "irimoya" if (roll < 0.5 and short >= 5.5) else ("gable" if roll < 0.88 else "hip")
		"shop": wish["form"] = "gable" if roll < 0.75 else "hip"
		_: wish["form"] = ("gable" if roll < 0.8 else "hip") if aspect >= 1.35 else ("gable" if roll < 0.55 else "hip")
	roll = dice.randf()
	wish["ridge"] = "long"
	if kind == "shop": wish.ridge = "street" if roll < 0.65 else "long"
	elif aspect < 1.2: wish.ridge = "x" if roll < 0.5 else "z"
	elif roll < 0.12: wish.ridge = "short"
	wish["machiya"] = dice.randf() < 0.45 and kind == "shop"
	wish["front_door"] = "slide" if (kind == "timber" or bool(wish.machiya)) else "hinged"
	wish["slide_inside"] = dice.randf() < (0.7 if kind == "house" else 0.5)
	roll = dice.randf()
	var deep := snappedf(dice.randf_range(0.75, 1.05), 0.05)
	wish["recess"] = deep if ((kind == "house" and roll < 0.4) or (kind == "timber" and roll < 0.3)) else 0.0
	wish["porch"] = dice.randf()
	wish["setback"] = dice.randf() < ({"timber": 0.7, "shop": 0.5}.get(kind, 0.4) as float) and floors == 2
	var sides: Array[String] = ["front", "back", "left", "right"]
	for n: int in range(3, 0, -1):
		var other := dice.randi_range(0, n)
		var held := sides[n]
		sides[n] = sides[other]
		sides[other] = held
	if kind == "shop":
		sides.erase("front")
		sides.push_front("front")
	wish["setback_sides"] = sides
	wish["setback_two"] = dice.randf() < 0.25
	wish["setback_amount"] = snappedf(dice.randf_range(0.9, 1.8), 0.15)
	wish["balcony"] = dice.randf() < ({"timber": 0.4, "shop": 0.35}.get(kind, 0.7) as float) and floors == 2
	roll = dice.randf()
	wish["balcony_kind"] = "wood" if kind == "timber" else ("solid" if roll < 0.6 else "rail")
	return wish


## Along a street the gables do not all face one way: stretch by stretch (9 m at a time)
## the plots turn their gable to the street or their eaves, by where they lie along it.
static func turned_plot(frame: Transform3D, size: Vector2) -> bool:
	var middle: Vector3 = frame * Vector3(size.x * 0.5, 0.0, size.y * 0.5)
	# (The two sides of a street are a row of plots each: the far side's stretches are shifted.)
	var row := posmod(floori(middle.dot(frame.basis.z) / 12.0), 2)
	return posmod(floori((middle.dot(frame.basis.x) + 4.5 * float(row)) / 9.0), 2) == 0


static func dress(c: Dictionary) -> void:
	_colours(c)
	if c.has("business"): _trade_paint(c)
	_uses(c)
	_choose_balcony(c)
	_windows(c)
	_fixtures(c)
	_roof(c)
	_noren_door(c)
	_entrance(c)
	_balcony(c)
	_plot(c)
	if c.has("business"):
		if UpstairsCafe.fits(c):
			UpstairsCafe.fit_out(c)
		else:
			_shop_front(c)
	var f: Dictionary = c.features
	(c.items as Array).sort()
	f["plot"] = ",".join(PackedStringArray(c.items))
	f["sig"] = "%s/%s|%s|%s|%s|%s" % [str(f.roof), str(f.ridge), str(f.setback), str(f.porch), str(f.balcony), str(f.plot)]
	var front: Dictionary = c.doors[0]
	# Does the front door have the wall beside it to slide into (the kit's own rule)?
	if str(front.get("kind", "")) == "slide":
		var notch: Dictionary = c.layout.get("recess", {})
		var from := (0.0 if float(notch.x0) <= T + 0.01 else float(notch.x0) - T) if not notch.is_empty() else 0.0
		var to := ((c.size as Vector2).x if float(notch.x1) >= (c.size as Vector2).x - T - 0.01 else float(notch.x1) + T) if not notch.is_empty() else (c.size as Vector2).x
		var x := float(front.at)
		if x + 1.47 > to - 0.03 and x - 1.47 < from + 0.03:
			front.erase("kind")
			front["style"] = "panel"
			f["front_door"] = "hinged"


## A shop that hangs a noren has a sliding front door, as such shops do: a hinged one would
## swing out through the cloth. Settled before the entrance is built round it; where the wall
## leaves the door no room to slide (the kit's own rule, as in dress()), it stays hinged and
## _shop_front hangs no noren.
static func _noren_door(c: Dictionary) -> void:
	if not c.has("business") or not (TRADES.get(str(c.business.what), {}) as Dictionary).has("noren"): return
	var front: Dictionary = c.doors[0]
	if str(front.get("kind", "")) == "slide": return
	var notch: Dictionary = c.layout.get("recess", {})
	var from := (0.0 if float(notch.x0) <= T + 0.01 else float(notch.x0) - T) if not notch.is_empty() else 0.0
	var to := ((c.size as Vector2).x if float(notch.x1) >= (c.size as Vector2).x - T - 0.01 else float(notch.x1) + T) if not notch.is_empty() else (c.size as Vector2).x
	var x := float(front.at)
	if x + 1.47 > to - 0.03 and x - 1.47 < from + 0.03: return
	front["kind"] = "slide"
	front["style"] = "slide"


# ---- geometry helpers ----------------------------------------------------------------------

## One outer wall of one floor: its outward normal, where its outer face is, the range of
## `at` along it (between the inner faces of the walls it meets).
static func _wall(c: Dictionary, wall: String, level: int) -> Dictionary:
	var size: Vector2 = c.size
	var inset: Dictionary = c.inset
	var left := float(inset.left) if level == 1 else 0.0
	var right := size.x - (float(inset.right) if level == 1 else 0.0)
	var front := float(inset.front) if level == 1 else 0.0
	var back := size.y - (float(inset.back) if level == 1 else 0.0)
	match wall:
		"front": return {"n": Vector2(0, -1), "face": front, "lo": left + T, "hi": right - T, "x": true, "wall": wall}
		"back": return {"n": Vector2(0, 1), "face": back, "lo": left + T, "hi": right - T, "x": true, "wall": wall}
		"left": return {"n": Vector2(-1, 0), "face": left, "lo": front + T, "hi": back - T, "x": false, "wall": wall}
		_: return {"n": Vector2(1, 0), "face": right, "lo": front + T, "hi": back - T, "x": false, "wall": wall}


## The point `out` metres outside a wall's outer face (inside it, if negative), `at` along it.
static func _pt(g: Dictionary, at: float, out: float) -> Vector2:
	var n: Vector2 = g.n
	if bool(g.x): return Vector2(at, float(g.face) + n.y * out)
	return Vector2(float(g.face) + n.x * out, at)


## A room's stretch along a wall it stands against, or an empty Vector2.
static func _span(g: Dictionary, rect: Rect2) -> Vector2:
	var n: Vector2 = g.n
	var inner := float(g.face) - (n.x + n.y) * T
	var edge: float
	match str(g.wall):
		"front": edge = rect.position.y
		"back": edge = rect.end.y
		"left": edge = rect.position.x
		_: edge = rect.end.x
	if absf(edge - inner) > 0.03: return Vector2.ZERO
	if bool(g.x): return Vector2(maxf(rect.position.x, float(g.lo)), minf(rect.end.x, float(g.hi)))
	return Vector2(maxf(rect.position.y, float(g.lo)), minf(rect.end.y, float(g.hi)))


## How high the ground is at a point of the plot, above the house's own origin.
static func _gy(c: Dictionary, p: Vector2) -> float:
	var at: Vector3 = (c.frame as Transform3D) * Vector3(p.x, 0.0, p.y)
	return float(c.world.ground(at.x, at.z)) - float(c.origin_y) + _paving(c, at)


## How high a built street's paving (a footway, a shop forecourt) stands over the ground at
## a point of the plot: what is stood there stands on the paving.
static func _paving(c: Dictionary, at: Vector3) -> float:
	var map: Object = c.world.get("map")
	if map == null or not map.has_method("paving_lift"): return 0.0
	return float(map.paving_lift(at.x, at.z))


## Is this point of the plot free: no other building on it, no road under it?
static func _free(c: Dictionary, p: Vector2, road_too: bool = true) -> bool:
	var at: Vector3 = (c.frame as Transform3D) * Vector3(p.x, 0.0, p.y)
	if c.world.solid_at(at.x, at.z, int(c.index)): return false
	return not (road_too and c.world.road_at(at.x, at.z))


## How much a wall faces the sun: 1 due south (the map's +z), -1 due north.
static func _sun(c: Dictionary, n: Vector2) -> float:
	return ((c.frame as Transform3D).basis * Vector3(n.x, 0.0, n.y)).z


static func _block(c: Dictionary, centre: Vector3, size: Vector3, colour: Color, solid: bool = false) -> void:
	(c.blocks as Array).append([centre, size, colour, solid, 0.0])


## A box on a wall: `at` along it, its middle `out` from the face and `y` up; `along` long,
## `tall` high, `deep` through.
static func _on_wall(c: Dictionary, g: Dictionary, at: float, out: float, y: float, along: float, tall: float, deep: float, colour: Color, solid: bool = false) -> void:
	var p := _pt(g, at, out)
	_block(c, Vector3(p.x, y, p.y), Vector3(along, tall, deep) if bool(g.x) else Vector3(deep, tall, along), colour, solid)


## A box on the floor plan: the rectangle `rect`, from `y0` to `y1`.
static func _on_plan(c: Dictionary, rect: Rect2, y0: float, y1: float, colour: Color, solid: bool = false) -> void:
	_block(c, Vector3(rect.get_center().x, (y0 + y1) * 0.5, rect.get_center().y), Vector3(rect.size.x, y1 - y0, rect.size.y), colour, solid)


static func _choice(dice: RandomNumberGenerator, list: Array) -> Variant:
	return list[dice.randi_range(0, list.size() - 1)]


## Where a door is on the plan.
static func _door_point(c: Dictionary, door: Dictionary) -> Vector2:
	var at := float(door.at)
	match str(door.wall):
		"front": return Vector2(at, T * 0.5)
		"entry": return Vector2(at, float(c.layout.door_z) + T * 0.5)
	for part: Dictionary in c.partitions:
		if str(part.id) == str(door.wall) and (part.floors as Array).has(int(door.floor)):
			var a: Vector2 = part.a
			var b: Vector2 = part.b
			return Vector2(a.x, at) if is_equal_approx(a.x, b.x) else Vector2(at, a.y)
	return Vector2(at, 0.0)


## Where nothing may stand on a floor: in front of doors, on the way through the house, on
## the lower floor at the door, in front of windows.
static func _keep_clear(c: Dictionary, level: int, tall: bool) -> Array[Rect2]:
	var keep: Array[Rect2] = []
	for door: Dictionary in c.doors:
		if int(door.floor) != level: continue
		var p := _door_point(c, door)
		keep.append(Rect2(p.x - 0.85, p.y - 0.85, 1.7, 1.7))
	var route: Array = c.layout.route
	var up_from := int(c.layout.get("up_from", -1))
	var last := Vector2.INF
	var last_level := -1
	for n: int in route.size():
		if not route[n] is Vector2: continue
		var here: Vector2 = route[n]
		var here_level := 1 if (up_from >= 0 and n >= up_from) else 0
		if here_level == level:
			keep.append(Rect2(here.x - 0.5, here.y - 0.5, 1.0, 1.0))
			if last_level == level:
				var gap := last.distance_to(here)
				for step: int in range(1, int(gap / 0.3) + 1):
					var p := last.lerp(here, float(step) * 0.3 / gap)
					keep.append(Rect2(p.x - 0.5, p.y - 0.5, 1.0, 1.0))
		last = here
		last_level = here_level
	if level == 0:
		for rect: Rect2 in c.layout.low: keep.append(rect.grow(0.15))
	for window: Dictionary in c.windows:
		if int(window.floor) != level: continue
		if not tall and float(window.get("sill", 0.85)) > 0.3: continue
		var g := _wall(c, str(window.wall), level)
		var a := _pt(g, float(window.at) - float(window.width) * 0.5 - 0.1, -T)
		var b := _pt(g, float(window.at) + float(window.width) * 0.5 + 0.1, -T - 0.9)
		keep.append(Rect2(minf(a.x, b.x), minf(a.y, b.y), absf(a.x - b.x), absf(a.y - b.y)))
	return keep


## A place for something `long` by `deep` in a corner of a room, its long side on a wall.
## Returns [Rect2, the way to that wall] or [] when no corner is free.
static func _place(c: Dictionary, room: Rect2, long: float, deep: float, keep: Array[Rect2]) -> Array:
	var first := (c.look as RandomNumberGenerator).randi_range(0, 7)
	for n: int in 8:
		var pick := (first + n) % 8
		var along_x := pick < 4
		var w := long if along_x else deep
		var d := deep if along_x else long
		if w > room.size.x - 0.05 or d > room.size.y - 0.05: continue
		var at_right := pick % 2 == 1
		var at_back := (pick / 2) % 2 == 1
		var rect := Rect2(room.end.x - w if at_right else room.position.x, room.end.y - d if at_back else room.position.y, w, d)
		var blocked := false
		for other: Rect2 in keep:
			if other.intersects(rect.grow(0.04)):
				blocked = true
				break
		if blocked: continue
		var to_wall := Vector2(0, 1 if at_back else -1) if along_x else Vector2(1 if at_right else -1, 0)
		return [rect, to_wall]
	return []


# ---- the paint ------------------------------------------------------------------------------

static func _colours(c: Dictionary) -> void:
	var look: RandomNumberGenerator = c.look
	var kind: String = c.kind
	var tone := look.randf_range(-0.02, 0.02)
	var wall: Color = _choice(look, WALLS.get(kind, WALLS.house))
	wall = Color(wall.r + tone, wall.g + tone, wall.b + tone)
	var frame: Color = _choice(look, FRAMES)
	var colours := {"outer_wall": wall, "roof": _choice(look, ROOFS), "front_door": _choice(look, FRONT_DOORS), "frame": frame, "gutter": _choice(look, GUTTERS), "concrete": Color(0.52 + tone, 0.52 + tone, 0.50 + tone), "door": Color(0.72, 0.62, 0.48), "fusuma": FUSUMA}
	var two_tone := look.randf()
	if kind == "timber":
		# Dark boards below, pale plaster above; some are boarded all the way up.
		var plaster: Color = _choice(look, PLASTER)
		if two_tone < 0.7:
			if int(c.floors) == 2: colours["outer_wall_upper"] = plaster
			colours["gable_wall"] = plaster
		colours["frame"] = Color(0.24, 0.18, 0.14) if look.randf() < 0.7 else Color(0.20, 0.18, 0.17)
		colours["soffit"] = Color(0.36, 0.27, 0.19)
		colours["timber"] = Color(0.34, 0.25, 0.17)
		colours["front_door"] = Color(0.30, 0.22, 0.15)
	elif two_tone < 0.18 and int(c.floors) == 2:
		colours["outer_wall_upper"] = _choice(look, WALLS.house)
	c["colours"] = colours


# ---- what the rooms are -----------------------------------------------------------------------

## Trades whose ground floor is a shop floor seen through a glass front, whatever plan the house has.
const GLASS_FRONT_TRADES: Array[String] = ["convenience store", "grocer", "rice and liquor shop"]

static func _uses(c: Dictionary) -> void:
	var look: RandomNumberGenerator = c.look
	var layout: Dictionary = c.layout
	var ground: Array = []
	for room: Dictionary in c.rooms:
		if int(room.floor) == 0: ground.append(room)
	ground.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.rect as Rect2).get_area() > (b.rect as Rect2).get_area())
	var shop := str(layout.get("shop_room", ""))
	# A convenience store's ground floor is its shop: where the plan names no shop room, the
	# largest room on the front gets the shop's glass front. (It keeps its use in the house, so
	# everything else about the house comes out as it would without the store.)
	# (So for the other trades that sell goods off the shelf, a greengrocer and a rice and liquor
	# shop: what they sell is seen from the pavement through the glass.)
	if shop == "" and c.has("business") and str(c.business.what) in GLASS_FRONT_TRADES:
		for room: Dictionary in ground:
			if _span(_wall(c, "front", 0), room.rect) != Vector2.ZERO and not bool(room.get("entry", false)):
				room["glass_front"] = true
				break
	var living: Dictionary = {}
	for room: Dictionary in ground:
		if str(room.name) == shop: room["use"] = "shop"
		elif living.is_empty():
			living = room
			room["use"] = "living"
	# A room with tatami, entered through a sliding paper door.
	var tatami_roll := look.randf()
	c.features["washitsu"] = false
	for room: Dictionary in ground:
		if room.has("use") or not bool(room.own_door) or bool(room.get("entry", false)) or str(room.door) == str(c.locked_room): continue
		if tatami_roll < ({"timber": 0.85, "shop": 0.4}.get(str(c.kind), 0.6) as float):
			room["use"] = "washitsu"
			c.features["washitsu"] = true
			for door: Dictionary in c.doors:
				if str(door.name) == str(room.door):
					door["kind"] = "slide"
					door["style"] = "fusuma"
		break
	# The bath and the toilet: small rooms of their own, in a strip along one side of a room.
	c.features["wet"] = false
	for room: Dictionary in ground:
		if str(room.get("use", "")) in ["shop", "washitsu"] or str(room.door) == str(c.locked_room): continue
		if _wet(c, room):
			c.features["wet"] = true
			break


static func _wet(c: Dictionary, host: Dictionary) -> bool:
	var rect: Rect2 = host.rect
	var keep := _keep_clear(c, 0, true)
	var first := (c.look as RandomNumberGenerator).randi_range(0, 3)
	for n: int in 4:
		var side := (first + n) % 4       # 0 the room's front edge, 1 its right, 2 its back, 3 its left
		var along_x := side % 2 == 0
		var length := rect.size.x if along_x else rect.size.y
		var across := rect.size.y if along_x else rect.size.x
		if length < 2.95 or across < CABIN + P * 2.0 + 2.5: continue
		var strip: Rect2
		match side:
			0: strip = Rect2(rect.position, Vector2(rect.size.x, CABIN))
			1: strip = Rect2(rect.end.x - CABIN, rect.position.y, CABIN, rect.size.y)
			2: strip = Rect2(rect.position.x, rect.end.y - CABIN, rect.size.x, CABIN)
			_: strip = Rect2(rect.position, Vector2(CABIN, rect.size.y))
		var blocked := false
		for other: Rect2 in keep:
			if other.intersects(strip.grow(0.25)): blocked = true
		if blocked: continue
		# The wall between the strip and the room, with the doors in it. It runs so that the
		# room is on its first side: the doors open into the room.
		var into: Vector2 = [Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0)][side]
		var line: float = [strip.end.y + P, strip.position.x - P, strip.position.y - P, strip.end.x + P][side]
		var lo := rect.position.x if along_x else rect.position.y
		var hi := lo + length
		var forward := (into.y if along_x else -into.x) > 0.0
		var from := lo if forward else hi
		var to := hi if forward else lo
		(c.partitions as Array).append({"id": "wet", "floors": [0], "a": Vector2(from, line) if along_x else Vector2(line, from), "b": Vector2(to, line) if along_x else Vector2(line, to)})
		var cells: Array = [["bath", lo, lo + 1.7]]
		if length - 1.82 >= 1.1 + P * 2.0 + 1.2:
			cells.append(["toilet", lo + 1.82, lo + 2.92])
			cells.append(["store", lo + 3.04, hi])
		else:
			cells.append(["toilet", lo + 1.82, hi])
		var back_low: bool = side == 0 or side == 3       # the strip's own wall is at its low edge
		for index: int in cells.size():
			var cell: Array = cells[index]
			var a0: float = cell[1]
			var a1: float = cell[2]
			if index > 0:
				var at: float = a0 - P
				(c.partitions as Array).append({"id": "wet_%d" % index, "floors": [0], "a": Vector2(at, strip.position.y) if along_x else Vector2(strip.position.x, at), "b": Vector2(at, strip.end.y) if along_x else Vector2(strip.end.x, at)})
			var cell_rect := Rect2(a0, strip.position.y, a1 - a0, CABIN) if along_x else Rect2(strip.position.x, a0, CABIN, a1 - a0)
			(c.doors as Array).append({"name": str(cell[0]), "wall": "wet", "floor": 0, "at": (a0 + a1) * 0.5, "swing": 1, "hinge": "low", "style": "flush"})
			(c.rooms as Array).append({"name": str(cell[0]), "floor": 0, "rect": cell_rect, "door": str(cell[0]), "own_door": true, "leads_on": false, "small": true, "use": str(cell[0])})
			# What is fixed in them, against the strip's own wall.
			var parts: Array = []      # [from along, to along, from the wall, to it, y0, y1]
			match str(cell[0]):
				"bath": parts = [[a0 + 0.05, a1 - 0.05, 0.03, 0.78, L0, L0 + 0.55]]
				"toilet": parts = [[(a0 + a1) * 0.5 - 0.19, (a0 + a1) * 0.5 + 0.19, 0.22, 0.78, L0, L0 + 0.40], [(a0 + a1) * 0.5 - 0.21, (a0 + a1) * 0.5 + 0.21, 0.03, 0.22, L0, L0 + 0.80]]
				_: parts = [[a0 + 0.05, a1 - 0.05, 0.03, 0.43, L0 + 0.75, L0 + 0.79], [a0 + 0.05, a1 - 0.05, 0.03, 0.43, L0 + 1.35, L0 + 1.39]]
			for part: Array in parts:
				var d0: float = (strip.position.y if along_x else strip.position.x) + float(part[2]) if back_low else (strip.end.y if along_x else strip.end.x) - float(part[3])
				var depth: float = float(part[3]) - float(part[2])
				var box := Rect2(float(part[0]), d0, float(part[1]) - float(part[0]), depth) if along_x else Rect2(d0, float(part[0]), depth, float(part[1]) - float(part[0]))
				_on_plan(c, box, float(part[4]), float(part[5]), CABINET if str(cell[0]) == "store" else SANITARY, true)
		match side:
			0: host["rect"] = Rect2(rect.position.x, rect.position.y + CABIN + P * 2.0, rect.size.x, rect.size.y - CABIN - P * 2.0)
			1: host["rect"] = Rect2(rect.position, Vector2(rect.size.x - CABIN - P * 2.0, rect.size.y))
			2: host["rect"] = Rect2(rect.position, Vector2(rect.size.x, rect.size.y - CABIN - P * 2.0))
			_: host["rect"] = Rect2(rect.position.x + CABIN + P * 2.0, rect.position.y, rect.size.x - CABIN - P * 2.0, rect.size.y)
		host["leads_on"] = true
		return true
	return false


# ---- windows ----------------------------------------------------------------------------------

## The stretches of a wall where no window can go.
static func _blocked(c: Dictionary, wall: String, level: int) -> Array:
	var out: Array = []
	if level != 0: return out
	var layout: Dictionary = c.layout
	var size: Vector2 = c.size
	if layout.has("recess"):
		var notch: Dictionary = layout.recess
		if wall == "front": out.append(Vector2(float(notch.x0) - T - 0.25, float(notch.x1) + T + 0.25))
		if wall == "left" and float(notch.x0) <= T + 0.01: out.append(Vector2(0.0, float(notch.depth) + T + 0.3))
		if wall == "right" and float(notch.x1) >= size.x - T - 0.01: out.append(Vector2(0.0, float(notch.depth) + T + 0.3))
	elif wall == "front":
		# (A sliding front door runs into the wall beside it: no window there.)
		var beside := 1.6 if str(c.doors[0].get("kind", "")) == "slide" else 0.8
		out.append(Vector2(float(layout.door_x) - beside, float(layout.door_x) + beside))
	return out


## The longest free stretch between `from` and `to`.
static func _longest(from: float, to: float, blocked: Array) -> Vector2:
	var best := Vector2.ZERO
	for piece: Vector2 in _minus(from, to, blocked):
		if piece.y - piece.x > best.y - best.x: best = piece
	return best


## What is left of `from`..`to` with the blocked stretches taken out.
static func _minus(from: float, to: float, blocked: Array) -> Array:
	var free: Array = [Vector2(from, to)]
	if to <= from: return []
	for gap: Vector2 in blocked:
		var next: Array = []
		for piece: Vector2 in free:
			if gap.y <= piece.x or gap.x >= piece.y:
				next.append(piece)
				continue
			if gap.x > piece.x: next.append(Vector2(piece.x, gap.x))
			if gap.y < piece.y: next.append(Vector2(gap.y, piece.y))
		free = next
	return free


## The balcony: on the sunniest upper wall that is not set back, has a room behind it wide
## enough for a floor-length window, and open air in front.
static func _choose_balcony(c: Dictionary) -> void:
	c.features["balcony"] = "none"
	if int(c.floors) != 2 or not bool(c.wish.balcony): return
	var best := {}
	var best_sun := -0.35
	for wall: String in SIDES:
		if float(c.inset[wall]) > 0.0 or float(c.open[wall]) < 1.7: continue
		var g := _wall(c, wall, 1)
		var sun := _sun(c, g.n)
		if sun <= best_sun: continue
		for room: Dictionary in c.rooms:
			if int(room.floor) != 1: continue
			var span := _span(g, room.rect)
			if span.y - span.x < 2.3: continue
			var width := clampf(span.y - span.x - 0.2, 2.3, 3.6)
			best = {"wall": wall, "room": str(room.name), "at": clampf((span.x + span.y) * 0.5, float(g.lo) + width * 0.5 - 0.1, float(g.hi) - width * 0.5 + 0.1), "width": width}
			best_sun = sun
			break
	if not best.is_empty(): c["balcony"] = best


static func _windows(c: Dictionary) -> void:
	var look: RandomNumberGenerator = c.look
	var layout: Dictionary = c.layout
	var windows: Array = c.windows
	var size: Vector2 = c.size
	var sliding := 0
	var balcony: Dictionary = c.get("balcony", {})
	var living_windows: Array = []
	for room: Dictionary in c.rooms:
		var level := int(room.floor)
		var use := str(room.get("use", ""))
		var small := bool(room.get("small", false))
		var got_small := false
		for wall: String in ["front", "back", "left", "right"]:
			var g := _wall(c, wall, level)
			var span := _span(g, room.rect)
			var roll := look.randf()
			var size_roll := look.randf()
			var place_roll := look.randf()
			if span == Vector2.ZERO or use == "store": continue
			var free := _longest(span.x + 0.3, span.y - 0.3, _blocked(c, wall, level))
			var room_left := free.y - free.x
			var entry := {"name": "%s_%s" % [str(room.name), wall], "wall": wall, "floor": level, "panes": 2, "head": 2.0}
			var clear_needed := 1.2
			if not balcony.is_empty() and str(balcony.room) == str(room.name) and str(balcony.wall) == wall:
				# The floor-length sliding door onto the balcony.
				entry.merge({"at": float(balcony.at), "width": SASH_WIDE, "sill": 0.0})
				windows.append(entry)
				sliding += 1
				continue
			if (use == "shop" or bool(room.get("glass_front", false))) and wall == "front":
				# The shop front: sliding glass from the floor up, either side of the door.
				var door_x := float(layout.door_x)
				var beside := 1.55 if str(c.doors[0].get("kind", "")) == "slide" else 0.62
				for stretch: Vector2 in [Vector2(span.x + 0.2, door_x - beside), Vector2(door_x + beside, span.y - 0.2)]:
					# (Only within this room's own front: the door may be in a hall beside it.)
					stretch = Vector2(maxf(stretch.x, span.x + 0.2), minf(stretch.y, span.y - 0.2))
					var wide := minf(stretch.y - stretch.x, 3.4)
					if wide < 1.0: continue
					var front := entry.duplicate()
					front.merge({"name": "shop_%d" % windows.size(), "at": stretch.x + wide * 0.5 if stretch.x > door_x else stretch.y - wide * 0.5, "width": wide, "sill": 0.0, "head": 2.15, "sunk": L0, "panes": maxi(2, roundi(wide / 0.85))}, true)
					windows.append(front)
					sliding += 1
				continue
			if small:
				# A small high window for the bath and for the toilet.
				if got_small or room_left < SASH_SMALL + 0.1 or float(c.open[wall]) < 0.6: continue
				got_small = true
				entry.merge({"at": (free.x + free.y) * 0.5, "width": SASH_SMALL, "sill": 1.43})
				windows.append(entry)
				sliding += 1
				continue
			var wanted := 1.0 if wall == "front" else (0.75 if wall == "back" else 0.6)
			if roll > wanted or room_left < SASH_SMALL + 0.3: continue
			var width := SASH_SMALL
			if room_left >= SASH_DOUBLE + 0.5 and size_roll < 0.2: width = SASH_DOUBLE
			elif room_left >= SASH_WIDE + 0.3: width = SASH_WIDE
			elif room_left >= SASH_MID + 0.3: width = SASH_MID
			var at := snappedf(lerpf(free.x + width * 0.5 + 0.1, free.y - width * 0.5 - 0.1, place_roll), 0.05)
			at = clampf(at, free.x + width * 0.5, free.y - width * 0.5)
			var clear: float = (c.clear as Callable).call(c.world, int(c.index), c.frame, size, wall, at)
			if clear + (float(c.inset[wall]) if level == 1 else 0.0) < clear_needed: continue
			entry.merge({"at": at, "width": width, "sill": 1.03 if (width == SASH_SMALL or size_roll > 0.6) else 0.83})
			if width == SASH_DOUBLE: entry["panes"] = 4
			windows.append(entry)
			sliding += 1
			if use == "living" and width >= SASH_WIDE: living_windows.append(entry)
	# The living room's window on the garden side reaches the floor, with a step outside it
	# (on an older house, an engawa edge): on its sunniest wall where the ground is level.
	var garden: Dictionary = {}
	var garden_sun := -2.0
	for entry: Dictionary in living_windows:
		var wall := str(entry.wall)
		var g := _wall(c, wall, 0)
		if float(c.open[wall]) < 1.8 or (wall == "front" and (float(c.drop) > 0.0 or absf(float(entry.at) - float(layout.door_x)) < float(entry.width) * 0.5 + 1.1)): continue
		var foot := _gy(c, _pt(g, float(entry.at), 0.6))
		if foot < -0.10 or not _free(c, _pt(g, float(entry.at), 0.9), false): continue
		if _sun(c, g.n) > garden_sun:
			garden_sun = _sun(c, g.n)
			garden = entry
	c.features["garden_door"] = "none"
	if not garden.is_empty():
		garden["sill"] = 0.0
		var deck: bool = str(c.kind) == "timber"
		(c.steps as Array).append({"wall": garden.wall, "at": float(garden.at), "width": float(garden.width) + (0.5 if deck else 0.1), "depth": 0.75 if deck else 0.45, "under": 0.12, "deck": deck})
		c.features["garden_door"] = str(garden.wall)
		c["garden"] = garden
		var g := _wall(c, str(garden.wall), 0)
		if deck:
			# The case the storm shutters slide into, beside the window.
			var side := 1.0 if float(garden.at) + float(garden.width) * 0.5 + 0.75 < float(g.hi) else -1.0
			if float(garden.at) + side * (float(garden.width) * 0.5 + 0.75) > float(g.lo): _on_wall(c, g, float(garden.at) + side * (float(garden.width) * 0.5 + 0.36), 0.05, L0 + 1.0, 0.62, 2.0, 0.10, c.colours.get("timber", HouseKit.COLOURS.timber))
		else:
			# The box the roller shutter is wound into, over the window.
			_on_wall(c, g, float(garden.at), 0.06, L0 + 2.13, float(garden.width) + 0.06, 0.22, 0.12, c.colours.frame)
	# The upstairs hall: a small window over the front door, and one at the back.
	var hall: Rect2 = layout.hall
	if hall.has_area() and int(c.floors) == 2 and str(layout.plan) != "back":
		var front := _wall(c, "front", 1)
		var at := hall.get_center().x
		var front_roll := look.randf()
		var back_roll := look.randf()
		if bool(layout.hall_front_free) and front_roll < 0.8 and at > float(front.lo) + 0.6 and at < float(front.hi) - 0.6:
			windows.append({"name": "hall_front", "wall": "front", "floor": 1, "at": at, "width": SASH_SMALL, "sill": 1.03, "head": 2.0, "panes": 2})
			sliding += 1
		if str(layout.stair.dir) == "+z" and back_roll < 0.6 and float(c.open.back) + float(c.inset.back) >= 1.2 and at > float(front.lo) + 0.6 and at < float(front.hi) - 0.6:
			windows.append({"name": "hall_back", "wall": "back", "floor": 1, "at": at, "width": SASH_SMALL, "sill": 1.03, "head": 2.0, "panes": 2})
			sliding += 1
	c.features["sliding_windows"] = sliding
	# Curtains drawn behind some of them.
	for entry: Dictionary in windows:
		var roll := look.randf()
		var shade: Color = _choice(look, CURTAINS)
		if float(entry.get("sill", 0.85)) < 0.3 or roll > 0.4 or str(entry.name).begins_with("shop"): continue
		var level := int(entry.floor)
		var floor_y := L1 if level == 1 else L0
		var g := _wall(c, str(entry.wall), level)
		_on_wall(c, g, float(entry.at), -T - 0.05, floor_y + (float(entry.sill) + float(entry.head)) * 0.5, float(entry.width) - 0.10, float(entry.head) - float(entry.sill) - 0.08, 0.02, shade)


# ---- what is fixed indoors ---------------------------------------------------------------------

static func _fixtures(c: Dictionary) -> void:
	var layout: Dictionary = c.layout
	# The shoe cupboard, on the genkan's free side.
	if layout.has("genkan") and not is_nan(float(layout.get("genkan_free_x", NAN))):
		var genkan: Rect2 = layout.genkan
		var x := float(layout.genkan_free_x)
		if genkan.size.y >= 0.85:
			_on_plan(c, Rect2(x, genkan.position.y + 0.06, 0.35, minf(genkan.size.y - 0.12, 1.1)), 0.0, 0.92, CABINET, true)
			c.features["shoe_cupboard"] = true
	for level: int in int(c.floors):
		var keep := _keep_clear(c, level, true)
		var floor_y := L1 if level == 1 else L0
		for room: Dictionary in c.rooms:
			if int(room.floor) != level or bool(room.get("small", false)): continue
			var rect: Rect2 = room.rect
			match str(room.get("use", "bedroom" if level == 1 else "room")):
				"living":
					# The kitchen: a counter along a wall, and the cupboards over it.
					var spot := _place(c, rect, 2.4, 0.62, keep)
					if spot.is_empty(): spot = _place(c, rect, 1.8, 0.62, keep)
					if not spot.is_empty():
						var at: Rect2 = spot[0]
						var to_wall: Vector2 = spot[1]
						_on_plan(c, at, floor_y, floor_y + 0.82, CABINET, true)
						_on_plan(c, at.grow(0.01), floor_y + 0.82, floor_y + 0.86, STEEL)
						var over := Rect2(at.position.x, at.position.y + (at.size.y - 0.35 if to_wall.y > 0.0 else 0.0), at.size.x, 0.35) if to_wall.x == 0.0 else Rect2(at.position.x + (at.size.x - 0.35 if to_wall.x > 0.0 else 0.0), at.position.y, 0.35, at.size.y)
						_on_plan(c, over, floor_y + 1.45, floor_y + 2.05, CABINET)
						keep.append(at.grow(0.5))
						c.features["kitchen"] = true
				"washitsu":
					# Tatami on the floor, and the closet (oshiire) behind sliding panels.
					_on_plan(c, rect.grow(-0.02), floor_y, floor_y + 0.012, TATAMI)
					var spot := _place(c, rect, 1.7, 0.85, keep)
					if not spot.is_empty():
						var at: Rect2 = spot[0]
						_on_plan(c, at, floor_y, floor_y + 1.8, FUSUMA, true)
						_on_plan(c, at.grow(0.012), floor_y + 1.8, floor_y + 1.86, c.colours.get("timber", HouseKit.COLOURS.timber))
						_on_plan(c, at, floor_y + 1.86, floor_y + 2.38, FUSUMA, true)
						keep.append(at.grow(0.3))
				"bedroom":
					var spot := _place(c, rect, 1.6, 0.6, keep)
					if not spot.is_empty():
						_on_plan(c, spot[0], floor_y, floor_y + 2.3, CABINET, true)
						keep.append((spot[0] as Rect2).grow(0.3))


# ---- the roof ----------------------------------------------------------------------------------

static func _roof(c: Dictionary) -> void:
	var wish: Dictionary = c.wish
	var size: Vector2 = c.size
	var inset: Dictionary = c.inset
	var open: Dictionary = c.open
	var kind: String = c.kind
	var width := size.x - float(inset.left) - float(inset.right)
	var depth := size.y - float(inset.front) - float(inset.back)
	var rise: float = c.rise
	var form := str(wish.form)
	var long_axis := "x" if width >= depth else "z"
	var axis := long_axis
	match str(wish.ridge):
		"street", "x": axis = "x"
		"z": axis = "z"
		"short": axis = "z" if long_axis == "x" else "x"
	# Along a street the gables do not all face one way (turned_plot).
	var turned := turned_plot(c.frame, size) and kind != "shop" and form != "irimoya"
	if turned:
		form = "gable"
		axis = "z"
	elif kind != "shop" and form == "gable" and str(wish.ridge) == "long" and long_axis == "z" and rise / (depth * 0.5) >= 0.3:
		# The stretches between show their eaves to the street, on a deep plot too, where the
		# box stands high enough over its eaves for tiles on the longer span. (Without this a
		# street of narrow deep plots had every gable end to the street.)
		axis = "x"
	# A ridge the box's height would lay nearly flat is turned the other way.
	var steepest := 0.5 if kind == "house" else 0.55
	var half := (depth if axis == "x" else width) * 0.5
	var other := (width if axis == "x" else depth) * 0.5
	if (rise / half < (0.08 if turned else 0.24) and rise / other > rise / half and rise / other <= steepest + 0.25) or (rise / half > steepest + 0.3 and rise / other >= 0.24):
		axis = "z" if axis == "x" else "x"
		half = other
	if form != "gable":
		axis = long_axis
		half = minf(width, depth) * 0.5
		# A hip-and-gable roof needs length for its gable; a short one is a plain hip.
		if form == "irimoya" and maxf(width, depth) - clampf(half * 0.5, 0.6, half - 0.3) * 2.0 < 1.0: form = "hip"
	# Tiles need a slope. Where the box stands too low over its eaves for one, the roof is
	# sheet metal on a low pitch, as such houses have: thin, with a low ridge cap.
	var sheet := rise / half < 0.3
	var roof_top := HouseKit.RIDGE_TOP
	if sheet:
		roof_top = 0.10
		rise += HouseKit.RIDGE_TOP - roof_top
		c.colours["roof"] = _choice(c.look, [Color(0.22, 0.23, 0.24), Color(0.27, 0.20, 0.17), Color(0.24, 0.31, 0.31), Color(0.33, 0.34, 0.35), Color(0.20, 0.25, 0.31), Color(0.30, 0.24, 0.20)])
	c["roof_top"] = roof_top
	c.features["roofing"] = "sheet metal" if sheet else "tile"
	var pitch := rise / half
	var wall_extra := 0.0
	if pitch > steepest:
		pitch = steepest
		wall_extra = rise - pitch * half
	# Eaves as deep as the kind has them, and never into a neighbour.
	var eave_wish := 0.85 if kind == "timber" else 0.5
	var gable_wish := 0.45 if kind == "timber" else 0.3
	var room := {}
	for wall: String in SIDES: room[wall] = float(open[wall]) + float(inset[wall]) - 0.1
	var eave: float
	var gable: float
	if form != "gable":
		eave = clampf(minf(minf(float(room.front), float(room.back)), minf(float(room.left), float(room.right))), 0.05, eave_wish)
		gable = eave
	elif axis == "x":
		eave = clampf(minf(float(room.front), float(room.back)), 0.05, eave_wish)
		gable = clampf(minf(float(room.left), float(room.right)), 0.03, gable_wish)
	else:
		eave = clampf(minf(float(room.left), float(room.right)), 0.05, eave_wish)
		gable = clampf(minf(float(room.front), float(room.back)), 0.03, gable_wish)
	c["roof"] = {"form": form, "ridge": axis, "pitch": pitch, "wall_extra": wall_extra, "eave": eave, "gable": gable, "ridge_ends": kind == "timber" and not sheet, "ridge_wide": 0.30 if (kind == "timber" and not sheet) else (0.18 if sheet else 0.24)}
	if sheet:
		c.roof["thick"] = 0.05
		c.roof["ridge_high"] = 0.05
	c["roof_half"] = half
	c.features["roof"] = form
	# The one downpipe: at one end of one of the eaves.
	# (Which end: by the house's number among its neighbours, so next-door houses differ.)
	var pipe := ((c.look as RandomNumberGenerator).randi_range(0, 1) * 4 + int(c.world.cell_rank(int(c.index)))) % 8
	c["pipe"] = pipe
	(c.items as Array).append("downpipe at corner %d" % (pipe % (4 if form == "gable" else 8)))
	c.features["ridge"] = axis
	c.features["pitch"] = pitch
	# The lean-to roof over the ground floor wherever the upper floor is set back.
	var names: Array[String] = []
	var lines := {
		"front": [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, 1), "left", "right"],
		"right": [Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(-1, 0), "front", "back"],
		"back": [Vector2(size.x, size.y), Vector2(0, size.y), Vector2(0, -1), "right", "left"],
		"left": [Vector2(0, size.y), Vector2(0, 0), Vector2(1, 0), "back", "front"],
	}
	for wall: String in SIDES:
		var run := float(inset[wall])
		if run <= 0.0: continue
		names.append(wall)
		var line: Array = lines[wall]
		var over := clampf(float(open[wall]) - 0.1, 0.05, eave_wish)
		var ends: Array = []
		var cheeks: Array = []
		for neighbour: String in [str(line[3]), str(line[4])]:
			var beside := float(inset[neighbour])
			if beside > 0.0:
				ends.append_array([clampf(float(open[neighbour]) - 0.1, 0.05, eave_wish), -beside])
				cheeks.append(false)
			else:
				var past := clampf(float(open[neighbour]) - 0.1, 0.03, 0.2)
				ends.append_array([past, past])
				cheeks.append(true)
		(c.lean_tos as Array).append({"a": line[0], "b": line[1], "inward": line[2], "run": run, "y": L1, "pitch": minf(0.42, 0.5 / run), "eave": over, "ends": ends, "cheeks": cheeks, "gutter": true})
	c.features["setback"] = "+".join(PackedStringArray(names)) if not names.is_empty() else "none"


# ---- the entrance ---------------------------------------------------------------------------------

static func _entrance(c: Dictionary) -> void:
	var layout: Dictionary = c.layout
	var size: Vector2 = c.size
	var kind: String = c.kind
	var door_x := float(layout.door_x)
	var wall_colour: Color = c.colours.outer_wall
	var porch := "none"
	var front := _wall(c, "front", 0)
	if layout.has("recess"):
		porch = "recess"
		var notch: Dictionary = layout.recess
		# A post where the porch takes the corner of the house away.
		if float(notch.x0) <= T + 0.01: _block(c, Vector3(0.07, (L0 + HouseKit.RECESS_HEAD) * 0.5, 0.07), Vector3(0.14, L0 + HouseKit.RECESS_HEAD, 0.14), wall_colour, true)
		if float(notch.x1) >= size.x - T - 0.01: _block(c, Vector3(size.x - 0.07, (L0 + HouseKit.RECESS_HEAD) * 0.5, 0.07), Vector3(0.14, L0 + HouseKit.RECESS_HEAD, 0.14), wall_colour, true)
		# The lamp in the porch ceiling's edge, over the door.
		_block(c, Vector3(door_x, L0 + 2.12, float(notch.depth) - 0.06), Vector3(0.16, 0.07, 0.10), APPLIANCE)
	elif kind == "shop":
		# Over the shop front: the shutter box, the sign board (blank), and on some a pent roof.
		var x0 := 0.25
		var x1 := size.x - 0.25
		_on_wall(c, front, (x0 + x1) * 0.5, 0.14, 2.31, x1 - x0, 0.26, 0.26, c.colours.frame)
		var with_roof: bool = float(c.wish.porch) < 0.5 and float(c.open.front) >= 1.3 and float(c.inset.front) == 0.0
		if int(c.floors) == 1: porch = "shutter box"
		elif bool(c.wish.machiya) or with_roof:
			if float(c.inset.front) == 0.0 and float(c.open.front) >= 1.3:
				(c.lean_tos as Array).append({"a": Vector2(x0 - 0.2, -0.85), "b": Vector2(x1 + 0.2, -0.85), "inward": Vector2(0, 1), "run": 0.85, "y": 2.46, "pitch": 0.28, "eave": 0.1, "ends": [0.0, 0.0, 0.0, 0.0], "gutter": false})
				porch = "pent roof"
		if porch == "none":
			# (A shop with a trade hangs its own sign there: _shop_front.)
			if not c.has("business"): _on_wall(c, front, (x0 + x1) * 0.5, 0.05, 2.44 + 0.30, x1 - x0 - 0.3, 0.52, 0.08, (c.colours.frame as Color).lerp(wall_colour, 0.55))
			porch = "sign board"
	else:
		var roll := float(c.wish.porch)
		var x0 := maxf(door_x - 0.95, 0.05)
		var x1 := minf(door_x + 0.95, size.x - 0.05)
		var level_ground := float(c.drop) == 0.0 and float(c.open.front) >= 1.6
		if kind == "timber" and roll < 0.8 and level_ground and int(c.floors) == 2 and float(c.inset.front) == 0.0:
			# A tiled roof over the door, on two posts.
			(c.lean_tos as Array).append({"a": Vector2(x0, -0.95), "b": Vector2(x1, -0.95), "inward": Vector2(0, 1), "run": 0.95, "y": 2.22, "pitch": 0.30, "eave": 0.15, "ends": [0.1, 0.1, 0.1, 0.1], "gutter": false})
			for x: float in [x0 + 0.06, x1 - 0.06]:
				var foot := _gy(c, Vector2(x, -0.89))
				_block(c, Vector3(x, (2.22 + foot) * 0.5, -0.89), Vector3(0.11, 2.22 - foot, 0.11), c.colours.get("timber", HouseKit.COLOURS.timber), true)
			porch = "porch roof"
		elif roll < 0.55 and float(c.open.front) >= 1.0:
			# A canopy over the door.
			_on_wall(c, front, door_x, 0.33, L0 + 2.14, 1.4, 0.05, 0.66, c.colours.frame)
			porch = "canopy"
		_on_wall(c, front, door_x + (0.72 if door_x + 0.9 < size.x else -0.72), 0.05, L0 + 1.80, 0.10, 0.14, 0.09, APPLIANCE)
	c.features["porch"] = porch
	c.features["recess"] = float(layout.door_z)
	c.features["genkan"] = layout.has("genkan") or layout.has("shop_room")
	c.features["front_door"] = str(c.doors[0].get("kind", "hinged"))
	# Real bars in front of a window: the lattice front of an old shop-house only.
	if kind == "shop" and bool(c.wish.machiya):
		for entry: Dictionary in c.windows:
			if int(entry.floor) != 1 or str(entry.wall) != "front": continue
			var g := _wall(c, "front", 1)
			var w := float(entry.width) + 0.24
			var y0 := L1 + float(entry.sill) - 0.12
			var y1 := L1 + float(entry.head) + 0.10
			for y: float in [y0 + 0.025, y1 - 0.025]: _on_wall(c, g, float(entry.at), 0.13, y, w, 0.05, 0.05, c.colours.frame)
			var bars := int(w / 0.105)
			for n: int in bars:
				_on_wall(c, g, float(entry.at) - w * 0.5 + (float(n) + 0.5) * w / float(bars), 0.13, (y0 + y1) * 0.5, 0.03, y1 - y0 - 0.1, 0.035, c.colours.frame)
			c.features["lattice"] = true
			break


# ---- the balcony -------------------------------------------------------------------------------------

static func _balcony(c: Dictionary) -> void:
	if not c.has("balcony"): return
	var b: Dictionary = c.balcony
	var g := _wall(c, str(b.wall), 1)
	var at := float(b.at)
	var w := float(b.width)
	var deep := 0.95
	# A balcony may not hang over the public road: on a front that faces a built footway it is
	# no deeper than the plot in front of the upper wall, and with under 60 cm there is none.
	if str(b.wall) == "front" and float(c.get("plot_gap", INF)) < 20.0:
		var room := float(c.plot_gap) + float(c.inset.front) - 0.05
		if room < 0.6:
			c.erase("balcony")
			return
		deep = minf(deep, snappedf(room - 0.025, 0.05))
	var kind := str(c.wish.balcony_kind)
	var wall_colour: Color = c.colours.get("outer_wall_upper", c.colours.outer_wall)
	var metal: Color = c.colours.frame
	var timber: Color = c.colours.get("timber", HouseKit.COLOURS.timber)
	# The floor.
	_on_wall(c, g, at, deep * 0.5, L1 - 0.08, w, 0.12, deep, timber if kind == "wood" else wall_colour.darkened(0.08), true)
	var top := L1 + 1.08
	match kind:
		"solid":
			_on_wall(c, g, at, deep - 0.04, (L1 - 0.14 + top) * 0.5, w, top - L1 + 0.14, 0.08, wall_colour, true)
			for side: float in [-1.0, 1.0]: _on_wall(c, g, at + side * (w * 0.5 - 0.04), (deep - 0.08) * 0.5, (L1 - 0.14 + top) * 0.5, 0.08, top - L1 + 0.14, deep - 0.08, wall_colour, true)
			_on_wall(c, g, at, deep - 0.04, top + 0.02, w + 0.04, 0.04, 0.13, metal)
		"rail":
			for side: float in [-1.0, 1.0]:
				_on_wall(c, g, at + side * (w * 0.5 - 0.025), deep - 0.025, L1 + 0.52, 0.05, 1.12, 0.05, metal, true)
				_on_wall(c, g, at + side * (w * 0.5 - 0.025), (deep - 0.05) * 0.5, top, 0.05, 0.05, deep - 0.05, metal, true)
				_on_wall(c, g, at + side * (w * 0.5 - 0.025), (deep - 0.05) * 0.5, L1 + 0.10, 0.03, 0.03, deep - 0.05, metal)
				for n: int in int((deep - 0.1) / 0.115): _on_wall(c, g, at + side * (w * 0.5 - 0.025), 0.08 + float(n) * 0.115, L1 + 0.58, 0.018, 0.94, 0.018, metal)
			_on_wall(c, g, at, deep - 0.025, top, w, 0.05, 0.05, metal, true)
			_on_wall(c, g, at, deep - 0.025, L1 + 0.10, w, 0.03, 0.03, metal)
			var bars := int((w - 0.1) / 0.115)
			for n: int in bars: _on_wall(c, g, at - w * 0.5 + 0.05 + (float(n) + 0.5) * (w - 0.1) / float(bars), deep - 0.025, L1 + 0.58, 0.018, 0.94, 0.018, metal)
		_:
			# Timber: posts to the ground at the outer corners, a top rail and a middle rail.
			for side: float in [-1.0, 1.0]:
				var p := _pt(g, at + side * (w * 0.5 - 0.05), deep - 0.05)
				var foot := minf(_gy(c, p), 0.0)
				_block(c, Vector3(p.x, (top + foot) * 0.5, p.y), Vector3(0.10, top - foot, 0.10), timber, true)
				for y: float in [top - 0.035, L1 + 0.52]: _on_wall(c, g, at + side * (w * 0.5 - 0.05), (deep - 0.1) * 0.5, y, 0.06, 0.07, deep - 0.1, timber, y > L1 + 0.8)
			for y: float in [top - 0.035, L1 + 0.52]: _on_wall(c, g, at, deep - 0.05, y, w - 0.2, 0.07, 0.06, timber, y > L1 + 0.8)
	# The laundry pole on its two arms.
	if (c.look as RandomNumberGenerator).randf() < 0.8:
		for side: float in [-1.0, 1.0]: _on_wall(c, g, at + side * (w * 0.5 - 0.35), 0.33, L1 + 1.95, 0.03, 0.03, 0.66, STEEL)
		_on_wall(c, g, at, 0.55, L1 + 1.98, w - 0.3, 0.03, 0.03, STEEL)
		(c.items as Array).append("laundry pole")
	c.features["balcony"] = "%s %s" % [str(b.wall), kind]


# ---- the plot -------------------------------------------------------------------------------------------

static func _plot(c: Dictionary) -> void:
	var look: RandomNumberGenerator = c.look
	var layout: Dictionary = c.layout
	var size: Vector2 = c.size
	var open: Dictionary = c.open
	var items: Array = c.items
	var door_x := float(layout.door_x)
	var front := _wall(c, "front", 0)
	# Stretches of the front that must stay clear: the way to the door, a step at a window.
	var front_taken: Array = [Vector2(door_x - 1.0, door_x + 1.0)]
	if layout.has("recess"): front_taken.append(Vector2(float(layout.recess.x0) - 0.2, float(layout.recess.x1) + 0.2))
	var taken := {"front": front_taken, "back": [], "left": [], "right": []}
	if c.has("garden"): (taken[str(c.garden.wall)] as Array).append(Vector2(float(c.garden.at) - float(c.garden.width) * 0.5 - 0.6, float(c.garden.at) + float(c.garden.width) * 0.5 + 0.6))
	if str(c.kind) == "shop": front_taken.append(Vector2(0.0, size.x))

	# The air conditioner's outdoor unit on the ground against a wall, its pipe up the wall.
	var unit_roll := look.randf()
	var unit_place := look.randf()
	var unit_first := look.randi_range(0, 2)
	var unit_wall := ""
	if unit_roll < 0.88:
		for n: int in 4:
			var wall: String = (["left", "right", "back"][(unit_first + n) % 3]) if n < 3 else "front"
			if float(open[wall]) < 0.9: continue
			var g := _wall(c, wall, 0)
			var free := _longest(float(g.lo) + 0.5, float(g.hi) - 0.5, taken[wall])
			if free.y - free.x < 1.0: continue
			var at := lerpf(free.x + 0.45, free.y - 0.45, unit_place)
			var p := _pt(g, at, 0.32)
			var foot := _gy(c, p)
			if foot < -0.8 or not _free(c, p, false) or not _free(c, _pt(g, at, 0.6), false): continue
			_on_wall(c, g, at, 0.32, foot + 0.09 + 0.28, 0.80, 0.56, 0.30, APPLIANCE, true)
			for side: float in [-1.0, 1.0]: _on_wall(c, g, at + side * 0.28, 0.32, foot + 0.045, 0.08, 0.09, 0.34, STEEL)
			var up := L1 + 2.1 if (int(c.floors) == 2 and float(c.inset[wall]) == 0.0 and look.randf() < 0.4) else L0 + 2.1
			_on_wall(c, g, at + 0.30, 0.035, (foot + 0.5 + up) * 0.5, 0.07, up - foot - 0.5, 0.07, APPLIANCE)
			(taken[wall] as Array).append(Vector2(at - 0.8, at + 0.8))
			unit_wall = wall
			items.append("air conditioner %s, %s" % [wall, "at its near end" if unit_place < 0.34 else ("at its far end" if unit_place > 0.66 else "in its middle")])
			break
	# The water heater on a side wall, the gas meter below it.
	var heater_roll := look.randf()
	if heater_roll < 0.9:
		for wall: String in (["right", "left", "back"] if unit_wall == "left" else ["left", "right", "back"]):
			if float(open[wall]) < 0.7: continue
			var g := _wall(c, wall, 0)
			var free := _longest(float(g.lo) + 0.3, float(g.hi) - 0.3, taken[wall])
			if free.y - free.x < 1.3: continue
			var at := free.x + 0.45 if wall != "back" else free.y - 0.45
			var p := _pt(g, at, 0.3)
			if not _free(c, p, false): continue
			var foot := _gy(c, p)
			_on_wall(c, g, at, 0.115, L0 + 1.25, 0.36, 0.62, 0.23, APPLIANCE)
			_on_wall(c, g, at, 0.03, (foot + L0 + 0.94) * 0.5, 0.04, L0 + 0.94 - foot, 0.04, STEEL)
			_on_wall(c, g, at + 0.6, 0.08, L0 + 0.62, 0.24, 0.30, 0.16, STEEL)
			_on_wall(c, g, at + 0.6, 0.03, (foot + L0 + 0.47) * 0.5, 0.035, L0 + 0.47 - foot, 0.035, STEEL)
			(taken[wall] as Array).append(Vector2(at - 0.5, at + 1.0))
			items.append("water heater %s" % wall)
			break
	# In front of the house: a block wall with gate pillars along the street, a carport,
	# bicycles. Only on level ground, and only as far as the plot goes.
	# The ground picture is drawn a metre to the dot, so where the road begins is only known
	# to about a metre: the plot is taken to end well short of it, and to leave a way through
	# in front of whatever stands opposite.
	var yard := minf(float(c.road_gap) - 1.05, float(c.door_clear) - 3.0 if float(c.door_clear) < 9.9 else 99.0)
	# A real footway in front: the wall stands at its back edge, its pillars' faces flush with
	# it, and the yard is what is left. A car then fits in a little less depth.
	var kerbed := float(c.get("plot_gap", INF)) < 20.0
	if kerbed: yard = minf(yard, float(c.plot_gap) - 0.14 + 0.25)
	var port_needs := 2.7 if kerbed else 2.9
	var has_street := float(c.road_gap) < 10.0
	var wall_roll := look.randf()
	var wall_height := snappedf(look.randf_range(1.0, 1.45), 0.05)
	var port_roll := look.randf()
	var bike_roll := look.randf()
	var bike_place := look.randf()
	var mail_roll := look.randf()
	var level_ground := float(c.drop) == 0.0
	var gate := false
	if str(c.kind) != "shop" and has_street and level_ground:
		var line := yard - 0.25      # how far out the wall stands
		# The carport first: it needs the most room.
		var port := Vector2.ZERO
		if yard >= port_needs and port_roll < 0.5:
			var free := _longest(-minf(float(open.left), 0.5), size.x + minf(float(open.right), 0.5), front_taken)
			if free.y - free.x >= 5.2:
				var x0 := free.x + 0.1 if free.x < door_x else free.y - 5.1
				var deep := minf(yard - 0.5, 2.6)
				var flat := true
				for corner: Vector2 in [Vector2(x0, -0.3), Vector2(x0 + 5.0, -0.3), Vector2(x0, -0.3 - deep), Vector2(x0 + 5.0, -0.3 - deep)]:
					if absf(_gy(c, corner) + 0.03) > 0.10 or not _free(c, corner): flat = false
				if flat:
					port = Vector2(x0, x0 + 5.0)
					(c.lean_tos as Array).append({"a": Vector2(x0, -0.3 - deep), "b": Vector2(x0 + 5.0, -0.3 - deep), "inward": Vector2(0, 1), "run": deep, "y": 2.18, "pitch": 0.05, "eave": 0.0, "ends": [0.0, 0.0, 0.0, 0.0], "gutter": false, "colour": Color(0.50, 0.52, 0.53)})
					for x: float in [x0 + 0.6, x0 + 4.4]: _block(c, Vector3(x, 1.12, -0.42), Vector3(0.10, 2.34, 0.10), STEEL, true)
					_on_plan(c, Rect2(x0, -0.3 - deep, 5.0, deep), -0.12, 0.0, HouseKit.COLOURS.concrete)
					front_taken.append(port)
					items.append("carport")
		if yard >= 1.4 and wall_roll < 0.6:
			var x0 := -minf(float(open.left) * 0.5, 0.6)
			var x1 := size.x + minf(float(open.right) * 0.5, 0.6)
			var gaps: Array = [Vector2(door_x - 0.8, door_x + 0.8)]
			if port != Vector2.ZERO: gaps.append(port)
			var built := 0
			for stretch: Vector2 in _minus(x0, x1, gaps):
				# In lengths that each stand on their own ground, as a block wall steps.
				var pieces := maxi(1, ceili((stretch.y - stretch.x) / 1.8))
				if stretch.y - stretch.x < 0.3: continue
				for n: int in pieces:
					var from := lerpf(stretch.x, stretch.y, float(n) / float(pieces))
					var to := lerpf(stretch.x, stretch.y, float(n + 1) / float(pieces))
					var middle := Vector2((from + to) * 0.5, -line)
					var foot := _gy(c, middle)
					if _free(c, middle) and foot > -0.5:
						_block(c, Vector3(middle.x, foot - 0.1 + (wall_height + 0.1) * 0.5, middle.y), Vector3(to - from, wall_height + 0.1, 0.12), BLOCK_WALL, true)
						built += 1
			if built >= 2:
				items.append("block wall")
				for side: float in [-1.0, 1.0]:
					var p := Vector2(door_x + side * 0.94, -line)
					if not _free(c, p): continue
					var foot := _gy(c, p)
					_block(c, Vector3(p.x, foot - 0.1 + (wall_height + 0.35) * 0.5, p.y), Vector3(0.28, wall_height + 0.35, 0.28), BLOCK_WALL, true)
					gate = true
					if side > 0.0 and mail_roll < 0.85:
						_block(c, Vector3(p.x, foot + 1.0, p.y - 0.17), Vector3(0.24, 0.20, 0.08), STEEL)
						items.append("mailbox at the gate")
				if gate: items.append("gate pillars")
	if not gate and mail_roll < 0.8 and str(c.kind) != "shop" and not layout.has("recess"):
		var side := -1.0 if door_x - 0.9 > 0.2 else 1.0
		_on_wall(c, front, door_x + side * 0.72, 0.06, L0 + 1.05, 0.30, 0.22, 0.11, STEEL)
		items.append("mailbox on the wall %s of the door" % ("left" if side < 0.0 else "right"))
	# Bicycles against the front wall.
	if bike_roll < 0.45 and level_ground and has_street and yard >= 1.1:
		var count := 1 if bike_roll > 0.15 else 2
		var free := _longest(0.3, size.x - 0.3, front_taken)
		var placed := 0
		for n: int in count:
			if free.y - free.x < 2.0 + float(n) * 0.5: break
			var at := lerpf(free.x + 0.95, free.y - 0.95, bike_place)
			var out := 0.32 + float(n) * 0.42
			var foot := _gy(c, Vector2(at, -out))
			if absf(foot + 0.03) > 0.12 or not _free(c, Vector2(at, -out), false): break
			_bicycle(c, Vector3(at + float(n) * 0.12, foot, -out), look)
			placed += 1
		if placed > 0: items.append("bicycles %d" % placed)


## A town bicycle (mamachari) standing along the wall: two tyres, a frame, a basket.
static func _bicycle(c: Dictionary, at: Vector3, look: RandomNumberGenerator) -> void:
	var paint: Color = _choice(look, [Color(0.20, 0.22, 0.25), Color(0.55, 0.56, 0.57), Color(0.30, 0.20, 0.18), Color(0.24, 0.30, 0.34), Color(0.74, 0.73, 0.70)])
	var dark := Color(0.10, 0.10, 0.10)
	for side: float in [-1.0, 1.0]: (c.wheels as Array).append([at + Vector3(side * 0.53, 0.33, 0.0), 0.33, PI * 0.5, dark])
	_block(c, at + Vector3(0.0, 0.36, 0.0), Vector3(1.06, 0.03, 0.03), paint)             # chain stays and down tube
	_block(c, at + Vector3(-0.08, 0.58, 0.0), Vector3(0.03, 0.46, 0.03), paint)           # seat tube
	_block(c, at + Vector3(0.20, 0.62, 0.0), Vector3(0.56, 0.03, 0.03), paint)            # top tube
	_block(c, at + Vector3(0.50, 0.68, 0.0), Vector3(0.03, 0.72, 0.03), paint)            # fork and head tube
	_block(c, at + Vector3(0.48, 1.04, 0.0), Vector3(0.03, 0.03, 0.52), STEEL)            # handlebar
	_block(c, at + Vector3(-0.10, 0.84, 0.0), Vector3(0.26, 0.05, 0.16), dark)            # saddle
	_block(c, at + Vector3(0.72, 0.86, 0.0), Vector3(0.28, 0.20, 0.34), STEEL)            # basket
	_block(c, at + Vector3(-0.52, 0.70, 0.0), Vector3(0.34, 0.02, 0.14), STEEL)           # rear rack
	_block(c, at + Vector3(-0.30, 0.18, 0.10), Vector3(0.03, 0.36, 0.03), STEEL)          # stand


# ---- a trade's shop front -----------------------------------------------------------------------------

const PAPER := Color(0.92, 0.89, 0.80)
## Bottle glass on a liquor shop's window stand: brown, green, a pale sake blue and a dark amber.
const BOTTLES: Array[Color] = [Color(0.33, 0.20, 0.10), Color(0.16, 0.34, 0.22), Color(0.62, 0.74, 0.78), Color(0.45, 0.27, 0.08)]
const LANTERN_RED := Color(0.74, 0.13, 0.10)
const SOOT := Color(0.10, 0.09, 0.09)
const BLACKBOARD := Color(0.13, 0.15, 0.14)
const SHRUB := Color(0.30, 0.36, 0.24)
const CRATE_WOOD := Color(0.72, 0.60, 0.42)
const PLANTER := Color(0.36, 0.27, 0.21)
## Dishes in a display case, bottles in a crate, what a greengrocer puts out.
const DISHES: Array[Color] = [Color(0.62, 0.40, 0.20), Color(0.88, 0.86, 0.80), Color(0.74, 0.55, 0.18), Color(0.42, 0.50, 0.30), Color(0.70, 0.30, 0.18), Color(0.86, 0.80, 0.62)]
const PRODUCE: Array[Color] = [Color(0.52, 0.60, 0.40), Color(0.82, 0.50, 0.18), Color(0.86, 0.85, 0.78), Color(0.62, 0.24, 0.18)]
const BEER_CRATES: Array[Color] = [Color(0.82, 0.66, 0.15), Color(0.58, 0.13, 0.10), Color(0.82, 0.66, 0.15)]

## What tells each trade's shop from the street. Every trade has a sign of its own: `board`
## its colour, `ink` the colour of the word on it, `word` the trade in Japanese as it is
## written on such a sign (no shop names, no brands), `down` the same word for a sign that
## reads downwards (one letter to a row; the long mark of ラーメン and カレー stands upright
## there, as it does in upright writing), on a board that sticks out from the upper floor.
##   wall      the ground floor is clad in this (dark boards, pale timber)
##   noren     a split cloth across the door, this colour, hanging `noren_drop` down
##   lanterns  red paper lanterns beside the door
##   awning    a cloth awning over the front, with the word on its hanging edge (`awning_ink`)
##             where there is no room for the sign board above it
##   full      the sign board runs the whole width of the front
##   out_front what stands at the front, in the order it is given room
const TRADES := {
	"ramen shop": {"word": "ラーメン", "down": "ラ\n｜\nメ\nン", "board": Color(0.88, 0.69, 0.12), "ink": Color(0.58, 0.08, 0.06), "noren": Color(0.66, 0.11, 0.09), "noren_drop": 0.45, "lanterns": 1, "out_front": ["menu board"]},
	"izakaya": {"word": "居酒屋", "down": "居\n酒\n屋", "board": Color(0.55, 0.09, 0.08), "ink": Color(0.93, 0.90, 0.82), "wall": Color(0.20, 0.15, 0.11), "noren": Color(0.30, 0.14, 0.16), "noren_drop": 0.45, "lanterns": 2, "lattice": true, "out_front": ["beer crates"]},
	"yakitori bar": {"word": "焼鳥", "down": "焼\n鳥", "board": Color(0.13, 0.10, 0.09), "ink": Color(0.88, 0.67, 0.20), "wall": Color(0.25, 0.18, 0.13), "noren": Color(0.72, 0.64, 0.50), "noren_drop": 0.40, "lanterns": 1, "hood": true, "out_front": ["beer crates"]},
	"soba shop": {"word": "そば", "down": "", "stand": "そ\nば", "board": Color(0.13, 0.19, 0.36), "ink": Color(0.92, 0.91, 0.87), "wall": Color(0.70, 0.58, 0.42), "noren": Color(0.13, 0.19, 0.36), "noren_drop": 0.45, "out_front": ["sign lantern"]},
	"sushi counter": {"word": "寿司", "down": "", "stand": "寿\n司", "board": Color(0.91, 0.90, 0.86), "ink": Color(0.09, 0.09, 0.10), "wall": Color(0.77, 0.67, 0.51), "noren": Color(0.90, 0.89, 0.85), "noren_drop": 0.85, "out_front": ["sign lantern", "planter"]},
	"set-meal diner": {"word": "定食", "down": "定\n食", "board": Color(0.22, 0.42, 0.30), "ink": Color(0.90, 0.85, 0.70), "awning": Color(0.22, 0.42, 0.30), "awning_ink": Color(0.90, 0.85, 0.70), "out_front": ["display case", "menu board"]},
	"curry shop": {"word": "カレー", "down": "カ\nレ\n｜", "board": Color(0.38, 0.20, 0.10), "ink": Color(0.90, 0.68, 0.16), "awning": Color(0.84, 0.63, 0.14), "awning_ink": Color(0.36, 0.18, 0.08), "out_front": ["display case", "menu board"]},
	"coffee shop": {"word": "珈琲", "down": "珈\n琲", "down_tall": 0.85, "board": Color(0.82, 0.72, 0.52), "ink": Color(0.26, 0.15, 0.09), "wall": Color(0.23, 0.17, 0.13), "out_front": ["bench", "planter", "menu board"]},
	"convenience store": {"word": "コンビニ", "down": "コ\nン\nビ\nニ", "board": Color(0.93, 0.93, 0.91), "ink": Color(0.04, 0.44, 0.50), "full": true, "out_front": ["bins", "paper rack"]},
	"grocer": {"word": "青果", "down": "", "board": Color(0.33, 0.52, 0.66), "ink": Color(0.93, 0.93, 0.90), "awning": Color(0.33, 0.52, 0.66), "awning_ink": Color(0.93, 0.93, 0.90), "out_front": ["trestle", "crates"]},
	"rice and liquor shop": {"word": "酒", "down": "酒", "down_tall": 0.60, "board": Color(0.42, 0.12, 0.38), "ink": Color(0.92, 0.89, 0.80), "awning": Color(0.42, 0.12, 0.38), "awning_ink": Color(0.92, 0.89, 0.80), "out_front": ["vending machine", "beer crates"]},
	"tobacco and sweets shop": {"word": "たばこ", "down": "た\nば\nこ", "down_tall": 1.0, "board": Color(0.85, 0.30, 0.10), "ink": Color(0.94, 0.93, 0.90), "counter": true, "out_front": ["vending machine", "ash stand"]},
}


## Cuts the letters of every trade's signs now (a few milliseconds each, once), so that the
## first shop made in play does not wait for them.
static func cut_words() -> void:
	for what: String in TRADES:
		for key: String in ["word", "down", "stand"]:
			var text := str((TRADES[what] as Dictionary).get(key, ""))
			if text != "": HouseKit.sign_shape(text)


## Cladding: the ground floor of some trades is boarded (an izakaya's dark boards, a sushi
## counter's pale timber). The upper floor keeps the house's own wall.
static func _trade_paint(c: Dictionary) -> void:
	var trade: Dictionary = TRADES.get(str(c.business.what), {})
	if not trade.has("wall"): return
	var colours: Dictionary = c.colours
	if not colours.has("outer_wall_upper") and int(c.floors) == 2: colours["outer_wall_upper"] = colours.outer_wall
	if not colours.has("gable_wall"): colours["gable_wall"] = colours.outer_wall
	colours["outer_wall"] = trade.wall


## The words of a sign: fitted into `wide` by `tall` round `centre`, seen from the way `yaw`
## turns +z (HouseKit.sign_shape cuts the letters).
static func _words(c: Dictionary, text: String, centre: Vector3, yaw: float, wide: float, tall: float, colour: Color) -> void:
	(c.signs as Array).append([text, centre, yaw, wide, tall, colour])


## Room at the front for something `wide` along the wall and `deep` out from it: the next
## free place on one side of the door (`first`, then the other), going outwards from the
## door. Returns where its middle is along the front, or NAN. Only on level ground that no
## other building stands on, and not where the road runs along the wall itself.
static func _spot(c: Dictionary, cursor: Dictionary, wide: float, deep: float, first: int) -> float:
	var size: Vector2 = c.size
	if float(c.drop) > 0.0 or float(c.road_gap) < 0.9: return NAN
	for side: int in [first, -first]:
		var from: float = cursor[side]
		var x := from + float(side) * wide * 0.5
		if x - wide * 0.5 < 0.12 or x + wide * 0.5 > size.x - 0.12: continue
		var good := true
		for p: Vector2 in [Vector2(x - wide * 0.5, -deep), Vector2(x + wide * 0.5, -deep), Vector2(x, -deep * 0.5)]:
			if not _free(c, p, false) or absf(_gy(c, p) + 0.03) > 0.12: good = false
		if not good: continue
		cursor[side] = from + float(side) * (wide + 0.12)
		return x
	return NAN


static func _shop_front(c: Dictionary) -> void:
	var business: Dictionary = c.business
	var pieces: Array[String] = []
	c.features["business"] = str(business.what)
	c.features["shop_front"] = pieces
	var trade: Dictionary = TRADES.get(str(business.what), {})
	var layout: Dictionary = c.layout
	if trade.is_empty() or layout.has("recess"): return
	var size: Vector2 = c.size
	var front := _wall(c, "front", 0)
	var door_x := float(layout.door_x)
	var porch := str(c.features.porch)
	var board: Color = trade.board
	var ink: Color = trade.ink
	var word := str(trade.word)
	var timber: Color = c.colours.get("timber", HouseKit.COLOURS.timber)
	# Is the upper floor's wall straight above the shop's? Does a low roof's eave hang over it?
	var flush: bool = int(c.floors) == 2 and float(c.inset.front) == 0.0
	var eave_front: bool = int(c.floors) == 1 and (str(c.roof.form) != "gable" or str(c.roof.ridge) == "x")
	var eave_y := EAVE_ONE + float(c.roof.wall_extra)
	var mid := size.x * 0.5
	var x0 := 0.25
	var x1 := size.x - 0.25
	var wide := (x1 - x0) if bool(trade.get("full", false)) else minf(x1 - x0 - 0.3, 3.4)

	# The awning: cloth on a frame fixed along the top of the shutter box, with a hanging edge.
	var canopy: bool = trade.has("awning") and porch != "pent roof" and float(c.open.front) >= 1.6
	if canopy and eave_front and eave_y - float(c.roof.pitch) * float(c.roof.eave) < 2.56: canopy = false
	# The sign board with the trade's word: on the wall over the shutter box where the wall
	# goes straight up; else hung on the front of the shutter box, under whatever roof is there.
	var high := porch == "sign board" and flush
	if high:
		_on_wall(c, front, mid, 0.05, 2.74, wide, 0.52, 0.08, board)
		_words(c, word, Vector3(mid, 2.74, -0.094), PI, wide * 0.84, 0.38, ink)
		pieces.append("sign board")
	elif not canopy:
		# (Its top is no higher than the edge of the roof over it, so all of it is seen from the street.)
		var top := 2.58
		if porch == "pent roof": top = 2.44
		elif float(c.inset.front) > 0.0: top = 2.52
		elif eave_front: top = clampf(eave_y - float(c.roof.pitch) * float(c.roof.eave) - 0.02, 2.36, 2.58)
		_on_wall(c, front, mid, 0.29, (2.04 + top) * 0.5, wide, top - 2.04, 0.04, board)
		_words(c, word, Vector3(mid, (2.04 + top) * 0.5, -0.314), PI, wide * 0.84, (top - 2.04) * 0.64, ink)
		pieces.append("sign board")
	if canopy:
		var cloth: Color = trade.awning
		(c.lean_tos as Array).append({"a": Vector2(0.15, -1.02), "b": Vector2(size.x - 0.15, -1.02), "inward": Vector2(0, 1), "run": 0.75, "y": 2.33, "pitch": 0.15, "eave": 0.0, "ends": [0.0, 0.0, 0.0, 0.0], "gutter": false, "colour": cloth, "thick": 0.03})
		# Its hanging edge carries the word where there is no board above.
		var hang := 0.20 if high else 0.30
		_on_wall(c, front, mid, 1.012, 2.33 - hang * 0.5, size.x - 0.3, hang, 0.012, cloth)
		if not high:
			_words(c, word, Vector3(mid, 2.33 - hang * 0.5, -1.022), PI, minf(size.x - 0.6, 2.4), hang * 0.72, trade.awning_ink)
			pieces.append("word on the awning")
		pieces.append("awning")

	# The sign that sticks out from the upper floor and reads downwards, for the street's length.
	var down := str(trade.get("down", ""))
	if down != "" and flush and float(c.open.front) >= 1.5 and not (c.has("balcony") and str(c.balcony.wall) == "front"):
		var x := 0.35 if float(c.open.left) >= float(c.open.right) else size.x - 0.35
		var clear := true
		for entry: Dictionary in c.windows:
			if int(entry.floor) == 1 and str(entry.wall) == "front" and absf(float(entry.at) - x) < float(entry.width) * 0.5 + 0.2: clear = false
		if clear:
			var tall := float(trade.get("down_tall", 1.3))
			var y0 := 3.12
			_block(c, Vector3(x, y0 + tall * 0.5, -0.36), Vector3(0.07, tall, 0.52), board)
			# The two steel arms that hold it to the wall.
			for y: float in [y0 - 0.02, y0 + tall + 0.02]: _block(c, Vector3(x, y, -0.31), Vector3(0.04, 0.04, 0.62), STEEL)
			for side: float in [-1.0, 1.0]: _words(c, down, Vector3(x + side * 0.039, y0 + tall * 0.5, -0.36), side * PI * 0.5, 0.42, tall - 0.14, ink)
			pieces.append("hanging sign")

	# The noren: a rod on two brackets over the door, the cloth joined along its top and
	# hanging in panels with slits between them.
	if trade.has("noren") and str((c.doors[0] as Dictionary).get("kind", "")) == "slide":
		var head := L0 - float(c.doors[0].get("sunk", 0.0)) + HouseKit.DOOR_HEIGHT
		var rod := minf(head + 0.05, 2.13)
		var cloth: Color = trade.noren
		var drop := float(trade.noren_drop)
		_on_wall(c, front, door_x, 0.07, rod, 1.44, 0.025, 0.025, timber)
		for side: float in [-1.0, 1.0]: _on_wall(c, front, door_x + side * 0.70, 0.04, rod, 0.03, 0.03, 0.08, timber)
		_on_wall(c, front, door_x, 0.07, rod - 0.0125 - 0.06, 1.32, 0.12, 0.008, cloth)
		var panels := 3
		var each := (1.32 - 0.02 * float(panels - 1)) / float(panels)
		for n: int in panels:
			_on_wall(c, front, door_x - 0.66 + each * 0.5 + float(n) * (each + 0.02), 0.07, rod - 0.0125 - 0.12 - (drop - 0.12) * 0.5, each, drop - 0.12, 0.008, cloth)
		pieces.append("noren")

	# Red paper lanterns on an arm beside the door: the first on the side with more wall.
	var roomy := 1 if size.x - door_x >= door_x else -1
	var hung := 0
	for n: int in int(trade.get("lanterns", 0)):
		var x := door_x + float(roomy if n == 0 else -roomy) * 0.86
		if x < 0.3 or x > size.x - 0.3: continue
		_on_wall(c, front, x, 0.22, 2.0, 0.025, 0.025, 0.44, SOOT)
		_lantern(c, Vector3(x, 1.985, -0.36))
		hung += 1
	if hung > 0: pieces.append("red lantern" if hung == 1 else "red lanterns")

	# Real bars in front of the ground-floor windows: an izakaya's lattice front.
	if bool(trade.get("lattice", false)):
		var latticed := false
		for entry: Dictionary in c.windows:
			if int(entry.floor) != 0 or str(entry.wall) != "front": continue
			var base := L0 - float(entry.get("sunk", 0.0))
			var w := float(entry.width) + 0.10
			var y0 := base + float(entry.sill) - (0.05 if float(entry.sill) > 0.0 else 0.0)
			var y1 := base + float(entry.head) + 0.02
			for y: float in [y0 + 0.025, y1 - 0.025]: _on_wall(c, front, float(entry.at), 0.02, y, w, 0.05, 0.03, timber)
			var bars := int(w / 0.105)
			for n: int in bars: _on_wall(c, front, float(entry.at) - w * 0.5 + (float(n) + 0.5) * w / float(bars), 0.02, (y0 + y1) * 0.5, 0.03, y1 - y0 - 0.1, 0.03, timber)
			latticed = true
		if latticed: pieces.append("lattice")

	# The extractor's outlet from the grill: a duct through the wall and its hood, on the
	# side of the door away from the lantern.
	if bool(trade.get("hood", false)):
		for side: int in [-roomy, roomy]:
			var x := door_x + float(side) * 1.25
			if x < 0.45 or x > size.x - 0.45: continue
			_on_wall(c, front, x, 0.10, 1.93, 0.24, 0.24, 0.20, STEEL)
			_on_wall(c, front, x, 0.31, 1.88, 0.38, 0.36, 0.24, STEEL.darkened(0.25))
			pieces.append("extractor hood")
			break

	# What stands at the front has the room each side of the door, going outwards from it.
	var cursor := {-1: door_x - 1.1, 1: door_x + 1.1}
	# A counter to be served at, at the first shop window: a ledge, and a boarded front under it.
	if bool(trade.get("counter", false)):
		for entry: Dictionary in c.windows:
			if int(entry.floor) != 0 or str(entry.wall) != "front": continue
			var w := minf(float(entry.width), 1.1)
			var at := float(entry.at)
			var ledge := maxf(L0 - float(entry.get("sunk", 0.0)) + float(entry.sill), 1.0)
			_on_wall(c, front, at, 0.14, ledge + 0.02, w, 0.04, 0.28, timber)
			if float(entry.sill) < 0.3: _on_wall(c, front, at, 0.03, ledge * 0.5, w, ledge, 0.04, board)
			# (Nothing is stood in front of it.)
			if at > door_x: cursor[1] = maxf(float(cursor[1]), at + w * 0.5 + 0.15)
			else: cursor[-1] = minf(float(cursor[-1]), at - w * 0.5 - 0.15)
			pieces.append("counter")
			break

	# A rice and liquor shop's window: where its front is glass, a low stepped stand stands just
	# inside the panes with rows of bottles on it, so the trade is read from the pavement by what
	# is for sale and the footway stays clear. (Inside the room's front strip, clear of the door.)
	if str(business.what) == "rice and liquor shop":
		var pane_from := INF
		var pane_to := -INF
		for entry: Dictionary in c.windows:
			if int(entry.floor) != 0 or str(entry.wall) != "front" or float(entry.sill) != 0.0 or float(entry.width) < 1.0: continue
			pane_from = minf(pane_from, float(entry.at) - float(entry.width) * 0.5)
			pane_to = maxf(pane_to, float(entry.at) + float(entry.width) * 0.5)
		if pane_to - pane_from >= 1.4:
			var stand_mid := (pane_from + pane_to) * 0.5
			var stand_wide := pane_to - pane_from - 0.30
			# Two steps: the lower at the glass, the higher behind it.
			var steps: Array = [[0.42, 0.30], [0.74, 0.58]]      # [how far inside the wall's outer face, how high]
			for n: int in steps.size():
				var inside: float = steps[n][0]
				var step_high: float = steps[n][1]
				_block(c, Vector3(stand_mid, L0 + step_high * 0.5, inside), Vector3(stand_wide, step_high, 0.32), timber.darkened(0.15), true)
				var count := int(floor((stand_wide - 0.10) / 0.17))
				for k: int in count:
					var x := stand_mid + (float(k) - float(count - 1) * 0.5) * 0.17
					var glass: Color = BOTTLES[(k + n * 2) % BOTTLES.size()]
					# The body, the shoulder's neck, and a paper label round the body.
					(c.drums as Array).append([Vector3(x, L0 + step_high + 0.115, inside), 0.042, 0.23, 8, glass])
					(c.drums as Array).append([Vector3(x, L0 + step_high + 0.275, inside), 0.015, 0.09, 6, glass])
					(c.drums as Array).append([Vector3(x, L0 + step_high + 0.105, inside), 0.0435, 0.085, 8, PAPER])
			pieces.append("window display")

	for item: String in trade.get("out_front", []):
		match item:
			"menu board":
				var x := _spot(c, cursor, 0.66, 0.42, roomy)
				if is_nan(x): continue
				var foot := _gy(c, Vector2(x, -0.22))
				for side: float in [-1.0, 1.0]:
					_on_wall(c, front, x + side * 0.27, 0.22, foot + 0.02, 0.05, 0.04, 0.36, timber)
					_on_wall(c, front, x + side * 0.27, 0.22, foot + 0.52, 0.04, 0.96, 0.04, timber)
				_on_wall(c, front, x, 0.22, foot + 0.62, 0.50, 0.70, 0.025, BLACKBOARD)
			"display case":
				# Dishes on shelves in an open-fronted case against the wall.
				var x := _spot(c, cursor, 1.14, 0.38, roomy)
				if is_nan(x): continue
				var foot := _gy(c, Vector2(x, -0.2))
				_on_wall(c, front, x, 0.035, foot + 0.80, 1.10, 1.60, 0.03, timber.darkened(0.25))
				for side: float in [-1.0, 1.0]: _on_wall(c, front, x + side * 0.535, 0.20, foot + 0.80, 0.03, 1.60, 0.33, timber)
				_on_wall(c, front, x, 0.20, foot + 1.62, 1.14, 0.04, 0.37, timber)
				_on_wall(c, front, x, 0.20, foot + 0.25, 1.04, 0.50, 0.30, timber, true)
				var shelves: Array[float] = [0.50, 0.90, 1.25]
				for level: int in 3:
					if level > 0: _on_wall(c, front, x, 0.20, foot + shelves[level] - 0.01, 1.04, 0.02, 0.30, CABINET)
					for n: int in 3: (c.drums as Array).append([Vector3(x + float(n - 1) * 0.33, foot + shelves[level] + 0.025, -0.22), 0.085, 0.05, 6, DISHES[(level * 3 + n) % DISHES.size()]])
			"sign lantern":
				# A paper sign box on a timber frame, standing at the door, with the word on it.
				var x := _spot(c, cursor, 0.46, 0.50, roomy)
				if is_nan(x): continue
				var foot := _gy(c, Vector2(x, -0.28))
				for side: float in [-1.0, 1.0]:
					for out: float in [0.14, 0.42]: _on_wall(c, front, x + side * 0.14, out, foot + 0.50, 0.03, 1.0, 0.03, timber)
				_on_wall(c, front, x, 0.28, foot + 0.68, 0.25, 0.60, 0.25, PAPER)
				_on_wall(c, front, x, 0.28, foot + 1.02, 0.36, 0.04, 0.36, timber)
				_words(c, str(trade.get("stand", word)), Vector3(x, foot + 0.68, -0.409), PI, 0.20, 0.50, SOOT)
			"planter":
				# A clipped evergreen in a planter box.
				var x := _spot(c, cursor, 0.78, 0.36, roomy)
				if is_nan(x): continue
				var foot := _gy(c, Vector2(x, -0.2))
				_on_wall(c, front, x, 0.20, foot + 0.20, 0.72, 0.40, 0.30, PLANTER, true)
				_on_wall(c, front, x, 0.20, foot + 0.61, 0.62, 0.42, 0.22, SHRUB)
			"bench":
				var x := _spot(c, cursor, 1.26, 0.42, roomy)
				if is_nan(x): continue
				var foot := _gy(c, Vector2(x, -0.22))
				_on_wall(c, front, x, 0.22, foot + 0.43, 1.20, 0.045, 0.34, timber, true)
				for side: float in [-1.0, 1.0]: _on_wall(c, front, x + side * 0.50, 0.22, foot + 0.205, 0.05, 0.41, 0.30, timber)
			"bins":
				# Three rubbish bins in a row, each with its lid.
				var x := _spot(c, cursor, 1.40, 0.46, roomy)
				if is_nan(x): continue
				var foot := _gy(c, Vector2(x, -0.22))
				var lids: Array[Color] = [Color(0.25, 0.38, 0.50), Color(0.28, 0.42, 0.33), Color(0.40, 0.40, 0.41)]
				for n: int in 3:
					_on_wall(c, front, x + float(n - 1) * 0.46, 0.22, foot + 0.40, 0.42, 0.80, 0.40, APPLIANCE, n == 1)
					_on_wall(c, front, x + float(n - 1) * 0.46, 0.22, foot + 0.825, 0.44, 0.05, 0.42, lids[n])
			"paper rack":
				# The stand of newspapers and magazines: three shelves, a pile on each.
				var x := _spot(c, cursor, 0.64, 0.36, roomy)
				if is_nan(x): continue
				var foot := _gy(c, Vector2(x, -0.18))
				for side: float in [-1.0, 1.0]: _on_wall(c, front, x + side * 0.29, 0.18, foot + 0.575, 0.025, 1.15, 0.30, STEEL)
				for y: float in [0.25, 0.60, 0.95]:
					_on_wall(c, front, x, 0.18, foot + y, 0.555, 0.02, 0.30, STEEL)
					_on_wall(c, front, x, 0.18, foot + y + 0.045, 0.46, 0.07, 0.24, PAPER)
			"trestle":
				# A greengrocer's table at the front: crates on it, each heaped with one thing.
				var x := _spot(c, cursor, 1.66, 0.60, roomy)
				if is_nan(x): continue
				var foot := _gy(c, Vector2(x, -0.32))
				_on_wall(c, front, x, 0.32, foot + 0.47, 1.60, 0.04, 0.50, CRATE_WOOD, true)
				for side: float in [-1.0, 1.0]:
					for out: float in [0.13, 0.51]: _on_wall(c, front, x + side * 0.72, out, foot + 0.225, 0.05, 0.45, 0.05, CRATE_WOOD)
				for n: int in 3:
					_on_wall(c, front, x + float(n - 1) * 0.52, 0.32, foot + 0.59, 0.46, 0.20, 0.38, CRATE_WOOD.darkened(0.12))
					_on_wall(c, front, x + float(n - 1) * 0.52, 0.32, foot + 0.72, 0.40, 0.07, 0.32, PRODUCE[n])
			"crates":
				# Two more crates on the ground, one on the other.
				var x := _spot(c, cursor, 0.50, 0.44, roomy)
				if is_nan(x): continue
				var foot := _gy(c, Vector2(x, -0.22))
				_on_wall(c, front, x, 0.22, foot + 0.10, 0.46, 0.20, 0.38, CRATE_WOOD.darkened(0.12), true)
				_on_wall(c, front, x, 0.22, foot + 0.30, 0.46, 0.20, 0.38, CRATE_WOOD)
				_on_wall(c, front, x, 0.22, foot + 0.43, 0.40, 0.07, 0.32, PRODUCE[3])
			"beer crates":
				# Bottle crates stacked by the door: three, of two breweries.
				var x := _spot(c, cursor, 0.44, 0.40, -roomy)
				if is_nan(x): continue
				var foot := _gy(c, Vector2(x, -0.2))
				for n: int in 3: _on_wall(c, front, x, 0.20, foot + 0.14 + float(n) * 0.28, 0.40, 0.28, 0.33, BEER_CRATES[n], n == 0)
			"ash stand":
				# A standing ashtray: a steel drum with a wider rim.
				var x := _spot(c, cursor, 0.32, 0.34, roomy)
				if is_nan(x): continue
				var foot := _gy(c, Vector2(x, -0.2))
				(c.drums as Array).append([Vector3(x, foot + 0.31, -0.20), 0.10, 0.62, 8, STEEL.darkened(0.3)])
				(c.drums as Array).append([Vector3(x, foot + 0.635, -0.20), 0.125, 0.03, 8, STEEL])
			"vending machine":
				# A drinks machine: its cabinet, and on the front the frame round the window the
				# sample cans stand in.
				var x := _spot(c, cursor, 1.04, 0.72, roomy)
				if is_nan(x): continue
				var foot := _gy(c, Vector2(x, -0.3))
				_on_wall(c, front, x, 0.30, foot + 0.915, 1.0, 1.83, 0.56, APPLIANCE, true)
				_on_wall(c, front, x, 0.61, foot + 1.69, 1.0, 0.28, 0.06, board)
				_on_wall(c, front, x, 0.61, foot + 0.26, 1.0, 0.52, 0.06, board)
				for side: float in [-1.0, 1.0]: _on_wall(c, front, x + side * 0.47, 0.61, foot + 1.035, 0.06, 1.03, 0.06, APPLIANCE)
				_on_wall(c, front, x, 0.585, foot + 1.035, 0.88, 1.03, 0.01, Color(0.16, 0.17, 0.19))
				for y: float in [0.80, 1.15]:
					_on_wall(c, front, x, 0.61, foot + y, 0.88, 0.015, 0.04, APPLIANCE)
					for n: int in 6: (c.drums as Array).append([Vector3(x - 0.35 + float(n) * 0.14, foot + y + 0.0075 + 0.06, -0.61), 0.033, 0.12, 6, DISHES[(n + int(y * 10.0)) % DISHES.size()]])
		pieces.append(item)


## A red paper lantern hanging from `top`: wide in the middle, narrower above and below, a
## black ring at each end.
static func _lantern(c: Dictionary, top: Vector3) -> void:
	var y := top.y
	for part: Array in [[0.07, 0.03, SOOT], [0.125, 0.07, LANTERN_RED], [0.16, 0.20, LANTERN_RED], [0.125, 0.07, LANTERN_RED], [0.07, 0.03, SOOT]]:
		(c.drums as Array).append([Vector3(top.x, y - float(part[1]) * 0.5, top.z), float(part[0]), float(part[1]), 8, part[2]])
		y -= float(part[1])