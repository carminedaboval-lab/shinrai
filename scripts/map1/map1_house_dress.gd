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
const COPING := 0.055                          # the capping stone along a block wall's top
const STEEL := Color(0.52, 0.53, 0.54)
## The name on a gate's plate. Every Japanese front gate carries one, and it is read from closer
## than anything else on the plot. Common surnames, one per house from the house's own dice.
## **Every one of these has to render whole**: `TextMesh` silently drops a letter whose convex
## decomposition fails, and what is left is still a shape, so a plate came out reading 木 for
## 鈴木 until it was caught by eye. `tests/probe_sign_shape.gd` now measures each name's width
## against its letter count and fails if one is missing. Check a new name there before adding it.
const SURNAMES: Array[String] = ["田中", "佐藤", "山田", "高橋", "渡辺", "山本", "中村", "小林", "加藤", "吉田", "松本", "井上", "清水", "石川"]
## How far a gate leaf's ironmongery reaches either side of the leaf's own middle plane. The
## hinges stand out towards the pillar, the handle the other way, and the handle is the longer
## reach of the two — a guard of ±55 mm round the leaf left a 10 mm band of handle outside it.
## Kept here beside `_gate_leaf` so the guard and the parts it guards cannot drift apart.
## (Codex measured the gap out of the source, 2026-11-16.)
## Codex's installed name-plate renderer: it turns a surname and a stone colour into the face
## metadata its shell reads, and gives back nothing for a name or palette it does not hold.
const NameplateAtlas := preload("res://scripts/interior_kit/nameplate_atlas.gd")
const LEAF_TO_PILLAR := 0.052      # hinge: 14.5 mm out of plane, 37.5 mm of half-depth
const LEAF_TO_INSIDE := 0.065      # handle: 40 mm in, 25 mm of half-depth
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


## Every sign text the map can draw, as a set. Taken from where the strings actually live — the
## trade table and the upstairs café — and not by dressing houses to find out: dressing all
## 2,003 of them to collect 26 strings takes 7.7 seconds. `tests/probe_sign_warm_cost.gd` checks
## this set against the one a fully dressed map really produces, so the two cannot drift apart.
## A shape is cached per text AND per coarseness, so the key is the pair: cutting 喫茶 at 2.5
## degrees does nothing for 喫茶 at 16. Keyed "text|step" here and split again when cutting.
static func sign_keys() -> Dictionary:
	var keys := {}
	for what: String in TRADES:
		var trade: Dictionary = TRADES[what]
		var word := str(trade.get("word", ""))
		for text: String in [word, str(trade.get("down", "")), str(trade.get("stand", word))]:
			if text != "": keys[sign_key(text, 2.5)] = true
	for text: String in UpstairsCafe.SIGN_TEXTS: keys[sign_key(text, 2.5)] = true
	# The gate plate's fallback, and only where it can actually be reached: a surname the
	# installed atlas cannot draw in any of its palettes falls back to cut letters at 16
	# degrees. With all fourteen covered this adds nothing; add a name the atlas does not
	# carry and its shape starts being cut at load instead of on the frame it is first seen.
	for surname: String in SURNAMES:
		var covered := false
		for stone: Color in [Color(0.86, 0.84, 0.79), Color(0.20, 0.20, 0.21), Color(0.74, 0.70, 0.62)]:
			if not NameplateAtlas.metadata_for(surname, stone).is_empty(): covered = true
		if not covered: keys[sign_key(surname, 16.0)] = true
	return keys


static func sign_key(text: String, curve_step: float) -> String:
	return "%s|%.1f" % [text, curve_step]


## Cut every one of them now, so that no frame in play has to. A sign's glyph outlines are cut
## the first time anything asks for that exact text and kept after, which puts the whole bill on
## whichever frame first builds a house carrying new text: for the upstairs café, six signs at
## once, that was 26.7 ms on the frame a player first came within sight of it. The work does not
## get cheaper here; it stops being paid where anyone can see it.
##
## Where this runs: `map1_world.gd`'s setup calls `cut_words()` while the world is being built,
## before a single house is dressed and before the player exists. So it is inside the Blockout's
## own build time, not in any interactive frame — and not, as an earlier comment of mine claimed,
## inside the 1.6 s black screen of a later cut, which is a different thing entirely.
##
## It is one pass, not one key a frame, for Codex's own reason: a single cold key can cost more
## than a whole frame's budget, so spreading them would turn one stall into several.
##
## `warmed_usec` is the measured cost of the pass and `warmed_slowest_usec` the worst single
## key. Whether the pass really found an empty cache is **counted, not timed**: `warmed_hits`
## and `warmed_misses` are read from the kit's own store key by key as it goes, and
## `tests/probe_sign_warm_cost.gd` fails unless every key was a miss. Elapsed time cannot tell
## 27 cuts from 20 cuts and 7 hits, and a fast enough machine would have read as a failure.
## (Shape and accounting agreed with Codex, 2026-11-16, after it showed the same cold cost
## exists in the pre-atlas implementation: 40.634 ms frozen against 38.535 ms installed.)
static var _signs_cut := false
static var warmed_usec := 0
static var warmed_keys := 0
static var warmed_slowest_usec := 0
static var warmed_hits := 0        # keys already in the kit's cache when this ran
static var warmed_misses := 0      # keys this pass actually cut
static func warm_signs() -> void:
	if _signs_cut: return
	_signs_cut = true
	var keys := sign_keys()
	var began := Time.get_ticks_usec()
	for key: String in keys:
		var split := key.rsplit("|", true, 1)
		var text: String = split[0]
		var step := float(split[1])
		# Whether the kit already holds this shape, read from its own store without touching it.
		# The key rule is mirrored from `HouseKit.sign_shape`: the bare text at the default
		# coarseness, "text/step" otherwise. Mirrored rather than asked for, because the kit is
		# Codex's; if it would rather expose a `has_sign_shape()` this is the one line to change.
		var kept: String = text if is_equal_approx(step, 2.5) else "%s/%.1f" % [text, step]
		if (HouseKit._sign_shapes as Dictionary).has(kept): warmed_hits += 1
		else: warmed_misses += 1
		var one := Time.get_ticks_usec()
		HouseKit.sign_shape(text, step)
		warmed_slowest_usec = maxi(warmed_slowest_usec, Time.get_ticks_usec() - one)
	warmed_usec = Time.get_ticks_usec() - began
	warmed_keys = keys.size()


static func dress(c: Dictionary) -> void:
	warm_signs()
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


## Whether a box of space on the plot has nothing of the plot's own standing in it. The wall and
## its pillars are passed over: they carry the wall marker in their colour's alpha, and whatever
## asks this question is being hung on them. Everything else — a carport post, a laundry pole, a
## planter, a bicycle, a hedge length — counts.
static func _slab_free(c: Dictionary, centre: Vector3, size: Vector3) -> bool:
	for entry: Array in (c.blocks as Array):
		if absf(float((entry[2] as Color).a) - 0.5) < 0.01: continue
		var at: Vector3 = entry[0]
		var theirs: Vector3 = entry[1]
		var clear := false
		for axis: int in 3:
			if (size[axis] + theirs[axis]) * 0.5 - absf(centre[axis] - at[axis]) <= 0.0: clear = true
		if not clear: return false
	return true


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
	# No two front walls on a street are the same grey: they were rendered in different years by
	# different people, and they weather on the side the rain comes from. One tone per house, from
	# the house's own dice, so a run of plots reads as a row of separate properties and not as one
	# long wall painted in a single go.
	var wall_tone := BLOCK_WALL.lerp(Color(0.52, 0.51, 0.47), look.randf() * 0.55).lightened(look.randf() * 0.10 - 0.03)
	# Marked for the wall surface: the kit replaces this alpha with the vertex's height above the
	# block's own foot, so the shader can run concrete courses up it and lay dirt along its base.
	# 0.5 in, 0.20 to 0.74 out; 0.9 and over stays "not a wall". The material is opaque, so the
	# mark changes nothing until that shader exists. (Codex's encoding, agreed 2026-11-16.)
	wall_tone.a = 0.5
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
		# Nearly every plot on a Japanese residential street is bounded: a block wall, or a wall with
		# a railing on it, right at the pavement. Ours bounded under a quarter of them, which is the
		# largest single thing still missing against the street the owner set as the mark. A plot only
		# goes unwalled where there is genuinely no room for one.
		if yard >= 1.0 and wall_roll < 0.88:
			var x0 := -minf(float(open.left) * 0.5, 0.6)
			var x1 := size.x + minf(float(open.right) * 0.5, 0.6)
			# The gateway, and then the gate pillars standing at its edges. A pillar is 28 cm
			# square and its inner face is where the wall used to start, so the wall's first
			# 28 cm — and the coping and the railing on top of it — ran straight through the
			# pillar. 1,297 rails crossed a pillar on 738 plots, by as much as 151 mm, and from
			# the gate you could see a fence rail going into a concrete post and out the other
			# side. A real railing stops at the pillar. So the gap is widened to the pillar's
			# OUTER face wherever a pillar will actually stand, and the pillar fills what the
			# wall gives up. Where the ground refuses a pillar the wall closes up as before.
			# (Found by tests/probe_gate_clear.gd, 2026-11-16.)
			var pillar_sides: Array[float] = []
			if str(c.kind) != "shop":
				for side: float in [-1.0, 1.0]:
					if _free(c, Vector2(door_x + side * 0.94, -line)): pillar_sides.append(side)
			var gaps: Array = [Vector2(door_x - (1.08 if pillar_sides.has(-1.0) else 0.8), door_x + (1.08 if pillar_sides.has(1.0) else 0.8))]
			if port != Vector2.ZERO: gaps.append(port)
			var built := 0
			var railed := look.randf() < 0.62
			var planted := look.randf() < 0.72
			var rail_dice := RandomNumberGenerator.new()
			rail_dice.seed = look.seed ^ 0x5A17
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
						_block(c, Vector3(middle.x, foot - 0.1 + (wall_height + 0.1) * 0.5, middle.y), Vector3(to - from, wall_height + 0.1, 0.12), wall_tone, true)
						# The capping stone along its top: a little wider than the wall and a shade paler,
						# which is what a block wall is finished with and what a railing is bolted through.
						# Without it the wall ends in a bare cut edge, which shows at a gate.
						_block(c, Vector3(middle.x, foot + wall_height + COPING * 0.5, middle.y), Vector3(to - from, COPING, 0.17), _capping(wall_tone), true)
						built += 1
				if planted and stretch.y - stretch.x >= 0.8:
					_planting(c, stretch.x, stretch.y, line, _gy(c, Vector2((stretch.x + stretch.y) * 0.5, -line)) + wall_height, rail_dice)
				if railed and stretch.y - stretch.x >= 0.6:
					var rail_foot := _gy(c, Vector2((stretch.x + stretch.y) * 0.5, -line)) + wall_height + COPING
					_railing(c, stretch.x, stretch.y, -line, rail_foot, rail_dice)
			if built >= 2:
				items.append(("block wall with a railing" if railed else "block wall") + (", planted" if planted else ""))
				# The pillars themselves, on the sides the wall already made room for.
				for side: float in pillar_sides:
					var p := Vector2(door_x + side * 0.94, -line)
					var foot := _gy(c, p)
					_block(c, Vector3(p.x, foot - 0.1 + (wall_height + 0.35) * 0.5, p.y), Vector3(0.28, wall_height + 0.35, 0.28), wall_tone.darkened(0.04), true)
					gate = true
					if side > 0.0 and mail_roll < 0.85:
						_block(c, Vector3(p.x, foot + 1.0, p.y - 0.17), Vector3(0.24, 0.20, 0.08), STEEL)
						items.append("mailbox at the gate")
					# The other pillar carries the name plate and the intercom. That is where they go on
					# a Japanese front gate and what you stand in front of at one: the post box on the
					# one pillar, these two on the other.
					if side < 0.0:
						var plate_dice := RandomNumberGenerator.new()
						plate_dice.seed = look.seed ^ 0x51A7
						var plate_y := foot + minf(wall_height + 0.05, 1.35)
						var stone: Color = _choice(plate_dice, [Color(0.86, 0.84, 0.79), Color(0.20, 0.20, 0.21), Color(0.74, 0.70, 0.62)])
						var plate_at: int = (c.blocks as Array).size()
						_block(c, Vector3(p.x, plate_y, p.y - 0.146), Vector3(0.17, 0.085, 0.014), stone)
						var ink := Color(0.10, 0.10, 0.11) if stone.get_luminance() > 0.4 else Color(0.88, 0.87, 0.84)
						# The name is chosen once, in the same order off the same dice as before, so no
						# plot's surname changes. Codex's installed renderer draws it from a font atlas
						# off the plate's own face, which costs the house no triangles at all: the
						# lettering was 260 of them a plate, about 95,000 across the ring. Where the
						# atlas does not know a name or a palette it hands back nothing, and the cut
						# letters are built exactly as they were. (Its interface, its call order,
						# agreed 2026-11-16.)
						var surname := str(_choice(plate_dice, SURNAMES))
						var plate_faces: Dictionary = NameplateAtlas.metadata_for(surname, stone)
						if plate_faces.is_empty():
							# Cut coarsely: at 12.5 cm a stroke's curve is a pixel, and the fine cut
							# costs 76 triangles a plate for a picture nobody can tell apart.
							_words(c, surname, Vector3(p.x, plate_y, p.y - 0.154), PI, 0.125, 0.052, ink, 16.0)
						else:
							((c.blocks as Array)[plate_at] as Array).append(plate_faces)
						# The intercom below it, with the dark of its speaker panel.
						_block(c, Vector3(p.x, plate_y - 0.26, p.y - 0.152), Vector3(0.085, 0.125, 0.026), Color(0.84, 0.83, 0.79))
						_block(c, Vector3(p.x, plate_y - 0.295, p.y - 0.166), Vector3(0.050, 0.030, 0.008), Color(0.26, 0.26, 0.27))
						items.append("name plate and intercom")
				if gate:
					items.append("gate pillars")
					# And a leaf hung in the gateway. Two pillars with nothing between them is a
					# gateway, not a gate, and it is the first thing you see standing at one.
					# Its own dice, so hanging it shifts nothing else on the street.
					var gate_dice := RandomNumberGenerator.new()
					gate_dice.seed = look.seed ^ 0x6A7E
					# A leaf hangs on a pillar, so it is hung only where a pillar was actually built:
					# one side's ground can refuse its pillar while the other takes it, and a leaf on
					# the refused side would be hinged to nothing. (Codex caught this, 2026-11-16.)
					# And a gate in use stands open: a shut leaf would seal the one way in off the
					# street, since the wall runs the whole frontage and 1.0 to 1.45 m of block with a
					# railing on top is not something the player's 32 cm step gets over. Open against
					# its own pillar needs 1.05 m of yard to swing into; a shallower plot keeps its
					# bare pillars rather than fold a leaf out over the footway.
					if gate_dice.randf() < 0.74 and line >= 1.05:
						var leaf_tone: Color = _choice(gate_dice, [Color(0.58, 0.59, 0.60), Color(0.33, 0.29, 0.25), Color(0.44, 0.44, 0.42)])
						var leaf_high := snappedf(gate_dice.randf_range(0.95, 1.15), 0.05)
						var leaf_foot := _gy(c, Vector2(door_x, -line))
						var leaves := 0
						for side: float in pillar_sides:
							# Hung on the pillar's inner face and standing in at a right angle, so its
							# hanging edge is inside the pillar's own depth and the hinges have something
							# to bridge to. 77 cm out leaves the paved path from the gate untouched.
							var base := Vector2(door_x + side * 0.77, -line - 0.10)
							var along := Vector2(0.0, 1.0)
							var through := Vector2(side, 0.0)
							var clear := true
							for u: float in [0.30, 0.55, 0.76]:
								if not _free(c, base + along * u, false): clear = false
							# `_free` asks the WORLD whether a building stands there. It knows nothing
							# about what this plot has already put down, and a leaf sweeps 68 cm into a
							# yard that may already hold a carport post, a laundry pole or a planter. So
							# the leaf's own slab is asked of the plot's blocks too: anything standing in
							# it that is not the wall or a pillar means no leaf on that side, because a
							# hinge is let into its pillar on purpose and nothing else belongs there.
							# (tests/probe_gate_clear.gd found a stile through a 3.86 m pole, 2026-11-16.)
							# The envelope is the leaf's own reach, not a round number: the handle
							# stands 65 mm inward and the hinges 52 mm towards the pillar, so a
							# symmetric guard of ±55 mm left a 10 mm band of handle unguarded.
							var span := LEAF_TO_PILLAR + LEAF_TO_INSIDE
							var off := (LEAF_TO_PILLAR - LEAF_TO_INSIDE) * 0.5 * side
							if clear and not _slab_free(c, Vector3(base.x + off, leaf_foot + 0.62, -line - 0.10 + 0.39), Vector3(span, 1.24, 0.80)): clear = false
							if not clear: continue
							var first_block: int = (c.blocks as Array).size()
							_gate_leaf(c, base, along, through, leaf_foot, leaf_high, railed, leaf_tone)
							# Which blocks that leaf just became, so a check never has to guess.
							(c.gate_leaves as Array).append({"side": side, "at": door_x, "line": line,
								"plane": base.x, "foot": leaf_foot, "from": first_block, "to": (c.blocks as Array).size()})
							leaves += 1
						if leaves > 0:
							items.append("gate %s, %d leaf open against its pillar" % ["barred" if railed else "panelled", leaves])
					# And a paved path from the gate in to the door. Nobody walks up bare earth to their
					# own front door, and the hedge already leaves this gap for it. It stops short of the
					# wall line so the gate's own threshold shows, and the doorstep sits on its far end.
					if line > 0.45 and _free(c, Vector2(door_x, -line * 0.5)):
						_on_plan(c, Rect2(door_x - 0.72, -line + 0.08, 1.44, line - 0.08), -0.12, 0.0, HouseKit.COLOURS.concrete)
						items.append("path from the gate")
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


## A steel railing along the top of a block wall: a rail under the cap, another at the bars'
## feet, upright bars between them, and a stouter post at each end. What a Japanese front wall
## nearly always carries, and what ours were missing against the street the owner set as the mark
## (docs/art_targets/street_target_01.webp).
## A clipped hedge in the strip between the front wall and the house, showing over the wall. A
## Japanese front garden is nearly always planted and ours were bare ground. It is built as a run
## of lengths with no gaps between them, each its own width, height and depth, because that is
## what a clipped hedge is: one mass with an uneven top, not a row of separate balls. (It was a
## row of prisms first. Twelve of them per frontage cost 462 triangles a house and still read as
## separate blobs; this reads better and costs a tenth of it.)
static func _planting(c: Dictionary, from_x: float, to_x: float, line: float, wall_top: float, dice: RandomNumberGenerator) -> void:
	var room: float = line - 0.30
	if room < 0.44 or to_x - from_x < 0.8: return            # no strip to plant, or no run to plant it along
	var deep: float = clampf(room, 0.30, 0.75)
	var out: float = line - 0.06 - deep * 0.5                # just inside the wall
	var at: float = from_x + 0.05
	var far: float = to_x - 0.05
	while at < far - 0.25:
		var wide: float = minf(dice.randf_range(0.45, 0.95), far - at)
		var middle := Vector2(at + wide * 0.5, -out)
		if _free(c, middle):
			var foot: float = _gy(c, middle)
			# Clipped to the wall, which is what "clipped" means: a front hedge in a half-metre
			# strip is kept at the wall's own height and a little over, because the point of it
			# is to show above the coping, not to hide the house. It stood up to 80 cm proud of a
			# 1.45 m wall before, which from the gate read as a flat green slab taller than the
			# pillars, and a 2.25 m hedge in a 60 cm bed is not a thing anyone grows.
			var top: float = minf(wall_top + dice.randf_range(0.05, 0.42), wall_top + 0.45)
			var green: Color = SHRUB.lightened(dice.randf() * 0.18 - 0.06)
			# Its own depth and its own set-out, so the face of the run is broken instead of one flat
			# plane: at a gate you stand two metres from it and a plane is the giveaway.
			var thick: float = deep * dice.randf_range(0.55, 1.0)
			var shift: float = (deep - thick) * dice.randf_range(-0.5, 0.5)
			_block(c, Vector3(middle.x, foot + (top - foot) * 0.5, middle.y + shift),
				Vector3(wide, top - foot, thick), green)
		at += wide


## The capping stone's colour: the wall's own tone a shade paler, and **not** marked for the wall
## surface. A coping is a smooth cast stone, not blockwork: it carries no courses, and because the
## mark also encodes height above a piece's own foot, leaving it on a 55 mm slab would read as the
## very bottom of a wall and come out the dirtiest thing on the plot. (Codex caught this, 2026-11-16.)
static func _capping(tone: Color) -> Color:
	var pale := tone.lightened(0.07)
	pale.a = 1.0
	return pale


static func _railing(c: Dictionary, from_x: float, to_x: float, z: float, foot: float, dice: RandomNumberGenerator) -> void:
	var span := to_x - from_x
	if span < 0.4: return
	var tall := snappedf(dice.randf_range(0.55, 0.85), 0.05)
	var bar := 0.014
	var post := 0.032
	for high: float in [foot + 0.05, foot + tall]:
		_block(c, Vector3((from_x + to_x) * 0.5, high, z), Vector3(span, bar * 1.6, bar * 1.6), STEEL)
	# 140 mm between bars, not 110. A real wall-top railing is made anywhere between about 100
	# and 140, so both are right, but at 110 the bars cost 513 triangles a house — more than the
	# gate leaves, the name plates and all their lettering put together, and 267,000 across the
	# 520-house ring against the 120,471 the ring is over by. The two look the same from the
	# street; the triangles do not. (Measured by tests/probe_house_cost.gd, 2026-11-16.)
	var count := maxi(int(round(span / 0.14)), 2)
	for i: int in range(1, count):
		var at := lerpf(from_x, to_x, float(i) / float(count))
		_block(c, Vector3(at, foot + (0.05 + tall) * 0.5, z), Vector3(bar, tall - 0.05, bar), STEEL)
	for at: float in [from_x + post * 0.5, to_x - post * 0.5]:
		_block(c, Vector3(at, foot + tall * 0.5, z), Vector3(post, tall, post), STEEL)


## One leaf of a front gate, built as a flat frame standing in its own plane. `base` is the point
## on the leaf's middle plane at its hanging end and on the ground, `along` the way its width runs
## and `through` the way its thickness does — both axis unit vectors in the plot's own x/z, so
## every member below is a plain box and none has to be turned.
##
## A Japanese residential gate is an aluminium or bronzed frame about a metre high: two stiles, a
## rail top and bottom, and either uprights or a sheet between them. Which it is follows the wall
## it hangs on. A plot whose wall carries a railing had a fabricator in to make that railing, and
## the gate came off the same van, so it is barred to match; a plain wall takes the panelled gate.
static func _gate_leaf(c: Dictionary, base: Vector2, along: Vector2, through: Vector2, foot: float, high: float, barred: bool, tone: Color) -> void:
	var wide := 0.78
	var thick := 0.045
	var stile := 0.05
	var rail := 0.055
	var low := foot + 0.11                      # the gap a gate is hung with, so it swings clear of the ground
	var top := foot + high
	# A box `w` along the leaf, `h` high and `d` through it, `u` metres from the hanging end and
	# `shift` out of the leaf's middle plane.
	var put := func(u: float, y: float, w: float, h: float, d: float, shift: float, colour: Color, solid: bool) -> void:
		var p: Vector2 = base + along * u + through * shift
		_block(c, Vector3(p.x, y, p.y),
			Vector3(absf(along.x) * w + absf(through.x) * d, h, absf(along.y) * w + absf(through.y) * d),
			colour, solid)
	put.call(stile * 0.5, (low + top) * 0.5, stile, top - low, thick, 0.0, tone, true)
	put.call(wide - stile * 0.5, (low + top) * 0.5, stile, top - low, thick, 0.0, tone, true)
	put.call(wide * 0.5, top - rail * 0.5, wide, rail, thick, 0.0, tone, true)
	put.call(wide * 0.5, low + rail * 0.5, wide, rail, thick, 0.0, tone, true)
	var inner_lo := low + rail
	var inner_hi := top - rail
	if barred:
		for i: int in range(1, 6):
			put.call(lerpf(stile, wide - stile, float(i) / 6.0), (inner_lo + inner_hi) * 0.5, 0.018, inner_hi - inner_lo, 0.018, 0.0, tone, false)
	else:
		# The panelled gate: a sheet across the lower half, a mid rail, and uprights above it. The
		# top is left open because you want to see who is at your gate before you reach it, which
		# is why a gate solid to its full height is a thing you hardly ever see on a house.
		var mid := lerpf(inner_lo, inner_hi, 0.46)
		put.call(wide * 0.5, (inner_lo + mid) * 0.5, wide - stile * 2.0, mid - inner_lo, thick * 0.55, 0.0, tone.lightened(0.03), false)
		put.call(wide * 0.5, mid, wide, rail * 0.8, thick, 0.0, tone, false)
		# The uprights run from the mid rail's own top to the top rail's underside. They used to
		# be set out from the mid rail's middle plus four tenths of a rail, which left their feet
		# 22 mm above the rail they are supposed to be welded to — a gate with its bars hanging in
		# the air. Taking the interval from the rail's actual top closes it and changes nothing
		# else: same frame, same silhouette, same three bars. (Codex read this out of the source,
		# 2026-11-16; no screenshot would have shown 22 mm.)
		var above := mid + rail * 0.4
		for i: int in range(1, 4):
			put.call(lerpf(stile, wide - stile, float(i) / 4.0), (above + inner_hi) * 0.5, 0.018, inner_hi - above, 0.018, 0.0, tone, false)
	# Two hinges at the hanging end and a handle at the other. Without them a gate is a frame
	# leaning in a gap: the ironmongery is what says it swings. Each hinge reaches from inside the
	# leaf's own stile across the 20 mm knuckle gap and 22 mm into the pillar's face, because a
	# hinge that stops short of its post is a hinge bolted to the air. (Codex measured mine
	# floating 31.6 mm clear of the pillar, 2026-11-16: the span was wrong, not the triangles.)
	for y: float in [low + 0.08, top - 0.12]:
		put.call(stile * 0.5, y, 0.07, 0.05, 0.075, 0.0145, tone.darkened(0.12), false)
	put.call(wide - stile * 0.5, low + (top - low) * 0.52, 0.04, 0.16, 0.05, -0.04, tone.darkened(0.05), false)


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


## The name `map1_world.gd`'s setup calls, kept so its call site does not change. It is now one
## entry into the single guarded pass below, because there were two: this one cut 22 trade keys
## and `warm_signs()` cut 27, which left the second measuring only its own remainder and me
## reporting that as the whole cost. One implementation, one set, one number. (Codex read the
## call order out of the source and caught it, 2026-11-16.)
static func cut_words() -> void:
	warm_signs()


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
static func _words(c: Dictionary, text: String, centre: Vector3, yaw: float, wide: float, tall: float, colour: Color, curve_step := 2.5) -> void:
	(c.signs as Array).append([text, centre, yaw, wide, tall, colour, curve_step])


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
