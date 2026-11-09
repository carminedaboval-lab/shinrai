extends RefCounted
## Real shells for the buildings closest to the park: rounded corners, window
## openings with true reveals, sills and aluminium frames, so sun and shadow fall
## on actual depth. Merged per chunk; the buildings behind stay shader boxes.
const CORNER_STEPS := 4
const FRAME := .05
const SHOP_UNIT := 6.0

## Surfaces of every key but the one being written, as {"v","n","t","c","u","u2","i"} arrays.
## Quads are indexed (4 corners + 6 indices): the same triangles with the same corner data
## as the six-corner form, a third fewer vertex bytes on the GPU.
var _walls := {}
var _glass := {}
## Keys in the order they were first written, so walls() and glass() list them as before.
var _keys: Array[int] = []
var _key := -1
# The key being written keeps its arrays in members: appending to a member is in place and
# several times cheaper than going through a Dictionary for every vertex.
var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _t := PackedFloat32Array()
var _c := PackedColorArray()
var _u := PackedVector2Array()
var _u2 := PackedVector2Array()
var _i := PackedInt32Array()
var _gv := PackedVector3Array()
var _gn := PackedVector3Array()
var _gt := PackedFloat32Array()
var _gc := PackedColorArray()
var _gu := PackedVector2Array()
var _gu2 := PackedVector2Array()
var _gi := PackedInt32Array()

func add(centre: Vector2, base: float, size: Vector3, front: int, key: int, spec: Dictionary) -> void:
	_select(key)
	var glass := {}
	var dirs: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
	var back := front + 1 if front % 2 == 0 else front - 1
	var radius: float = spec.radius
	var middle := Vector3(centre.x, base, centre.y)
	for i: int in range(4):
		var n := dirs[i]
		var along := size.z if absf(n.x) > .5 else size.x
		var deep := size.x if absf(n.x) > .5 else size.z
		var role := 0 if i == front else (1 if i == back else 2)
		# Exposed flanks are glazed like a front on about half of buildings.
		if role == 2 and fposmod(float(spec.seed) * (43.0 + float(i) * 17.0), 1.0) < .55: role = 3
		_face(middle + n * deep * .5, n, along, size.y, role, spec, glass)
	# Corners, swept between each pair of faces.
	var steps := CORNER_STEPS if radius > .3 else 1
	for sign_x: float in [-1.0, 1.0]:
		for sign_z: float in [-1.0, 1.0]:
			var pivot := middle + Vector3(sign_x * (size.x * .5 - radius), 0, sign_z * (size.z * .5 - radius))
			for step: int in range(steps):
				var a := float(step) / float(steps) * PI * .5
				var b := float(step + 1) / float(steps) * PI * .5
				var n1 := Vector3(sign_x * cos(a), 0, sign_z * sin(a))
				var n2 := Vector3(sign_x * cos(b), 0, sign_z * sin(b))
				var p1 := pivot + n1 * radius
				var p2 := pivot + n2 * radius
				_quad(p1, p1 + Vector3.UP * size.y, p2 + Vector3.UP * size.y, p2, n1, n2, spec.tint, 0.0, 0.0)
	_roof(middle, size, radius, spec)

func _outline(middle: Vector3, half: Vector2, radius: float, steps: int) -> PackedVector3Array:
	# Plan outline, clockwise from above, with each corner swept.
	var points := PackedVector3Array()
	for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]:
		var pivot := Vector3(corner.x * (half.x - radius), 0, corner.y * (half.y - radius))
		for step: int in range(steps + 1):
			var a := float(step) / float(steps) * PI * .5
			var turn := Vector3(corner.x * cos(a), 0, corner.y * sin(a)) if corner.x * corner.y < 0.0 else Vector3(corner.x * sin(a), 0, corner.y * cos(a))
			points.append(middle + pivot + turn * radius)
	return points

func _roof(middle: Vector3, size: Vector3, radius: float, spec: Dictionary) -> void:
	# Membrane roof inside a parapet that follows the corners, capped with coping.
	var top := Vector3.UP * size.y
	var half := Vector2(size.x, size.z) * .5
	var wall: float = spec.get("parapet", .9)
	# Both rings need the same point count, so the inner one follows the outer steps.
	var steps := CORNER_STEPS if radius > .3 else 1
	var outer := _outline(middle + top, half, radius, steps)
	var inner := _outline(middle + top, half - Vector2(.22, .22), maxf(radius - .22, .02), steps)
	var membrane := Color(.3, .3, .31, 3.0 / 8.0)
	var coping := Color(.62, .61, .58, 3.0 / 8.0)
	var count := outer.size()
	var lift := Vector3.UP * wall
	var mid := middle + top
	for i: int in range(count):
		var next := (i + 1) % count
		var n := (outer[i] + outer[next] - inner[i] - inner[next]).normalized()
		_quad(mid, inner[i], inner[next], inner[next], Vector3.UP, Vector3.UP, membrane, 0.0, 0.0)
		if wall < .05: continue
		_quad(outer[i], outer[i] + lift, outer[next] + lift, outer[next], n, n, spec.tint, 0.0, .3)
		_quad(inner[next], inner[next] + lift, inner[i] + lift, inner[i], -n, -n, spec.tint, 0.0, 0.0)
		_quad(outer[i] + lift, inner[i] + lift, inner[next] + lift, outer[next] + lift, Vector3.UP, Vector3.UP, coping, 0.0, 0.0)

func walls() -> Dictionary:
	_select(-1)
	var out := {}
	for key: int in _keys: out[key] = _walls[key]
	return out

func glass() -> Dictionary:
	_select(-1)
	var out := {}
	for key: int in _keys: out[key] = _glass[key]
	return out

func _select(key: int) -> void:
	# Parks the current key's arrays in the tables and takes key's out of them.
	if key == _key: return
	if _key >= 0:
		_walls[_key] = {"v":_v, "n":_n, "t":_t, "c":_c, "u":_u, "u2":_u2, "i":_i}
		_glass[_key] = {"v":_gv, "n":_gn, "t":_gt, "c":_gc, "u":_gu, "u2":_gu2, "i":_gi}
	_key = key
	var wall: Dictionary = _walls.get(key, {})
	var pane: Dictionary = _glass.get(key, {})
	if key >= 0 and not _keys.has(key): _keys.append(key)
	_v = wall.get("v", PackedVector3Array())
	_n = wall.get("n", PackedVector3Array())
	_t = wall.get("t", PackedFloat32Array())
	_c = wall.get("c", PackedColorArray())
	_u = wall.get("u", PackedVector2Array())
	_u2 = wall.get("u2", PackedVector2Array())
	_i = wall.get("i", PackedInt32Array())
	_gv = pane.get("v", PackedVector3Array())
	_gn = pane.get("n", PackedVector3Array())
	_gt = pane.get("t", PackedFloat32Array())
	_gc = pane.get("c", PackedColorArray())
	_gu = pane.get("u", PackedVector2Array())
	_gu2 = pane.get("u2", PackedVector2Array())
	_gi = pane.get("i", PackedInt32Array())
	# Only the members hold the arrays once this returns, so appends never copy them.
	if key >= 0:
		_walls.erase(key)
		_glass.erase(key)

static func _tangent(n: Vector3) -> Vector3:
	var t := Vector3.UP.cross(n)
	if t.length_squared() < .01: t = Vector3.RIGHT
	return t.normalized()

func _face(origin: Vector3, n: Vector3, width: float, height: float, role: int, spec: Dictionary, glass: Dictionary) -> void:
	var t := Vector3.UP.cross(n)
	var run := width * .5 - float(spec.radius)
	var ground: float = spec.ground
	var storey: float = spec.storey
	var bay: float = width / maxf(1.0, floorf(width / float(spec.bay) + .5))
	var pane := Vector2(bay * float(spec.pane_x), float(spec.pane_y))
	if role == 1 and spec.mansion: pane = Vector2(.5, .62)
	var plain: bool = spec.get("deck", false)
	var y := 0.0
	var floor_index := 0
	if ground > 0.0:
		if role == 0:
			var units := maxf(1.0, floorf(width / SHOP_UNIT + .5))
			var unit := width / units
			var entry := 0 if fposmod(float(spec.seed) * 19.0, 1.0) < .5 else int(units) - 1
			var openings: Array[Vector3] = []
			for i: int in range(int(units)):
				var u := -width * .5 + unit * (float(i) + .5)
				# One bay is the deep stair lobby for the tenants upstairs.
				if i == entry and spec.get("lobby", false): openings.append(Vector3(u, minf(.95, unit * .3), 1.2))
				else: openings.append(Vector3(u, unit * .45, .14))
			_row(origin, n, t, run, 0.0, ground, .12, 3.05, openings, spec, glass, 1.0)
			if spec.get("lobby", false):
				_box(origin + t * openings[entry].x + Vector3.UP * 3.0 + n * .55, t, n, Vector2(2.4, 1.1), .1, Color(.34, .35, .37, 1.0))
		else:
			_quad_flat(origin, n, t, -run, run, 0.0, ground, spec.tint, 0.0, 0.0)
		y = ground
	elif spec.get("undercroft", false) and role != 2:
		# Flats raised over open parking: columns every other bay, dark behind.
		var openings: Array[Vector3] = []
		var span := bay * 2.0
		var cells := int(floorf(width / span))
		for i: int in range(cells): openings.append(Vector3(-width * .5 + span * (float(i) + .5), span * .5 - .3, 4.0))
		_row(origin, n, t, run, 0.0, storey, .02, storey - .5, openings, spec, glass, -1.0)
		y = storey
		floor_index = 1
	while y + storey <= height - .3:
		var openings: Array[Vector3] = []
		var tall := pane.y
		var recess: float = spec.recess
		if plain:
			openings.append(Vector3(0.0, run - .35, recess))
		elif role == 2:
			# Party walls stay blank, bar the odd stair or bathroom window.
			tall = .5
			if floor_index % 3 == 1: openings.append(Vector3(sin(float(spec.seed) * 90.0) * run * .5, .36, .1))
		else:
			var cells := int(floorf(width / bay + .5))
			for i: int in range(cells): openings.append(Vector3(-width * .5 + bay * (float(i) + .5), pane.x, recess))
		var centre_y: float = y + storey * float(spec.sill)
		_row(origin, n, t, run, y, y + storey, centre_y - tall, centre_y + tall, openings, spec, glass, 0.0)
		if role != 2 or floor_index % 2 == 0: _ledge(origin, n, t, run, y, spec.tint)
		y += storey
		floor_index += 1
	if y < height: _quad_flat(origin, n, t, -run, run, y, height, spec.get("band", spec.tint), 0.0, 0.0)
	if ground <= 0.0 and not spec.get("undercroft", false): _plinth(origin, n, t, run)
	if role != 2 and spec.parapet > .1: _cornice(origin, n, t, run, height, spec.tint)
	if role == 0 and int(spec.detail) == 0 and spec.get("quoin", false) and (bay * .5 - pane.x) > .8:
		for side: float in [-1.0, 1.0]:
			var mid := side * (run - .4)
			_box(origin + t * mid + Vector3.UP * (ground + height) * .5, t, n, Vector2(.8, .14), height - ground, spec.tint.darkened(.08))

func _plinth(origin: Vector3, n: Vector3, t: Vector3, run: float) -> void:
	# Polished stone skirting, where a wall meets the pavement.
	var stone := Color(.34, .34, .36, 1.0 / 8.0)
	_quad_flat(origin + n * .04, n, t, -run, run, 0.0, .72, stone, 0.0, 0.0)
	_quad(origin + n * .04 + t * -run + Vector3.UP * .72, origin + t * -run + Vector3.UP * .72, origin + t * run + Vector3.UP * .72, origin + n * .04 + t * run + Vector3.UP * .72, Vector3.UP, Vector3.UP, stone, 0.0, 0.0)

func _cornice(origin: Vector3, n: Vector3, t: Vector3, run: float, y: float, tint: Color) -> void:
	var band := tint.lightened(.08)
	var proud := n * .16
	var low := Vector3.UP * (y - .34)
	var high := Vector3.UP * y
	_quad(origin + proud + t * -run + low, origin + proud + t * -run + high, origin + proud + t * run + high, origin + proud + t * run + low, n, n, band, 0.0, .2)
	_quad(origin + t * -run + low, origin + proud + t * -run + low, origin + proud + t * run + low, origin + t * run + low, Vector3.DOWN, Vector3.DOWN, tint.darkened(.25), 0.0, 0.0)
	_quad(origin + proud + t * -run + high, origin + t * -run + high, origin + t * run + high, origin + proud + t * run + high, Vector3.UP, Vector3.UP, band, 0.0, 0.0)

func _box(at: Vector3, t: Vector3, n: Vector3, plan: Vector2, tall: float, tint: Color) -> void:
	# Plain block in the shell: plan.x along the wall, plan.y out from it.
	var half := Vector3.UP * tall * .5
	var x := t * plan.x * .5
	var z := n * plan.y * .5
	_quad(at - x + z - half, at - x + z + half, at + x + z + half, at + x + z - half, n, n, tint, 0.0, 0.0)
	_quad(at - x - z - half, at - x - z + half, at - x + z + half, at - x + z - half, -t, -t, tint, 0.0, 0.0)
	_quad(at + x + z - half, at + x + z + half, at + x - z + half, at + x - z - half, t, t, tint, 0.0, 0.0)
	_quad(at - x - z + half, at + x - z + half, at + x + z + half, at - x + z + half, Vector3.UP, Vector3.UP, tint, 0.0, 0.0)
	_quad(at - x - z - half, at - x + z - half, at + x + z - half, at + x - z - half, Vector3.DOWN, Vector3.DOWN, tint, 0.0, 0.0)

func _at(origin: Vector3, t: Vector3, n: Vector3, x: float, y: float, d: float) -> Vector3:
	return origin + t * x + Vector3.UP * y - n * d

func _pane(origin: Vector3, t: Vector3, n: Vector3, u: float, left: float, right: float, sill: float, head: float, half: float, recess: float, spec: Dictionary, _unused_glass: Dictionary, shop: float) -> void:
	# UV is metres from the pane centre, for the room behind.
	var cell := fposmod(float(spec.seed) * 37.0 + u * .73 + sill * 1.31, 1.0)
	var extent := Vector2(half, (head - sill) * .5)
	var info := Vector2(cell + shop * 2.0, floorf(extent.x * 100.0) + extent.y * .1)
	var ls := _at(origin, t, n, left, sill, recess)
	var lh := _at(origin, t, n, left, head, recess)
	var rh := _at(origin, t, n, right, head, recess)
	var rs := _at(origin, t, n, right, sill, recess)
	var low := Vector2(-extent.x, -extent.y)
	var high := Vector2(extent.x, extent.y)
	# Four corners ls lh rh rs, drawn as the triangles ls lh rh and ls rh rs.
	var base := _gv.size()
	_gv.append(ls); _gv.append(lh); _gv.append(rh); _gv.append(rs)
	for i: int in range(4): _gn.append(n)
	var tangent := _tangent(n)
	var tx := tangent.x
	var ty := tangent.y
	var tz := tangent.z
	for i: int in range(4):
		_gt.append(tx); _gt.append(ty); _gt.append(tz); _gt.append(1.0)
		_gc.append(Color.WHITE)
		_gu2.append(info)
	_gu.append(low); _gu.append(Vector2(-extent.x, extent.y)); _gu.append(high); _gu.append(Vector2(extent.x, -extent.y))
	_gi.append(base); _gi.append(base + 1); _gi.append(base + 2); _gi.append(base); _gi.append(base + 2); _gi.append(base + 3)

func _ledge(origin: Vector3, n: Vector3, t: Vector3, run: float, y: float, tint: Color) -> void:
	# A slab edge standing just proud of the wall, so each floor throws a real shadow.
	var band := tint.darkened(.06)
	var proud := n * .07
	if y < .1: return
	_quad(origin + proud + t * -run + Vector3.UP * (y - .09), origin + proud + t * -run + Vector3.UP * (y + .09), origin + proud + t * run + Vector3.UP * (y + .09), origin + proud + t * run + Vector3.UP * (y - .09), n, n, band, 0.0, .2)
	_quad(origin + proud + t * -run + Vector3.UP * (y + .09), origin + t * -run + Vector3.UP * (y + .09), origin + t * run + Vector3.UP * (y + .09), origin + proud + t * run + Vector3.UP * (y + .09), Vector3.UP, Vector3.UP, band, 0.0, 0.0)
	_quad(origin + t * -run + Vector3.UP * (y - .09), origin + proud + t * -run + Vector3.UP * (y - .09), origin + proud + t * run + Vector3.UP * (y - .09), origin + t * run + Vector3.UP * (y - .09), Vector3.DOWN, Vector3.DOWN, band, 0.0, 0.0)

func _row(origin: Vector3, n: Vector3, t: Vector3, run: float, y0: float, y1: float, sill: float, head: float, openings: Array[Vector3], spec: Dictionary, glass: Dictionary, shop: float) -> void:
	var tint: Color = spec.tint
	var band: Color = spec.get("band", tint)
	var metal: Color = spec.metal
	var pier := Color(.3, .3, .32, 1.0 / 8.0) if shop > .5 else tint
	var hollow: bool = shop < -.5 or spec.get("deck", false)
	_quad_flat(origin, n, t, -run, run, y0, sill, band, 0.0, .3)
	_quad_flat(origin, n, t, -run, run, head, y1, band, 0.0, 0.0)
	var previous := -run
	for opening: Vector3 in openings:
		var u := opening.x
		var half := opening.y
		var recess := opening.z
		if absf(u) + half > run - .08:
			continue
		_quad_flat(origin, n, t, previous, u - half, sill, head, pier, .1, .1)
		previous = u + half
		var left := u - half
		var right := u + half
		var reveal := pier.darkened(.08)
		_quad(_at(origin, t, n, left, sill, 0.0), _at(origin, t, n, left, head, 0.0), _at(origin, t, n, left, head, recess), _at(origin, t, n, left, sill, recess), t, t, reveal, 0.0, 0.0)
		_quad(_at(origin, t, n, right, sill, recess), _at(origin, t, n, right, head, recess), _at(origin, t, n, right, head, 0.0), _at(origin, t, n, right, sill, 0.0), -t, -t, reveal, 0.0, 0.0)
		_quad(_at(origin, t, n, left, head, 0.0), _at(origin, t, n, left, head, recess), _at(origin, t, n, right, head, recess), _at(origin, t, n, right, head, 0.0), Vector3.DOWN, Vector3.DOWN, reveal, 0.0, 0.0)
		_quad(_at(origin, t, n, left, sill, recess), _at(origin, t, n, left, sill, 0.0), _at(origin, t, n, right, sill, 0.0), _at(origin, t, n, right, sill, recess), Vector3.UP, Vector3.UP, reveal, 0.0, 0.0)
		if hollow:
			# Open deck or undercroft: dark void behind, a guard rail on parking decks.
			_quad_flat(origin - n * recess, n, t, left, right, sill, head, Color(.03, .03, .035, 3.0 / 8.0), 0.0, 0.0)
			if shop > -.5: _quad_flat(origin - n * .2, n, t, left, right, sill + .5, sill + .62, metal, 0.0, 0.0)
			continue
		if int(spec.detail) > 0:
			_pane(origin, t, n, u, left, right, sill, head, half, recess, spec, glass, shop)
			continue
		if shop < .5:
			# Pre-cast sill proud of the wall.
			var ledge := tint.lightened(.12)
			_quad(_at(origin, t, n, left - .05, sill - .07, -.06), _at(origin, t, n, left - .05, sill, -.06), _at(origin, t, n, right + .05, sill, -.06), _at(origin, t, n, right + .05, sill - .07, -.06), n, n, ledge, 0.0, 0.0)
			_quad(_at(origin, t, n, left - .05, sill, -.06), _at(origin, t, n, left - .05, sill, 0.0), _at(origin, t, n, right + .05, sill, 0.0), _at(origin, t, n, right + .05, sill, -.06), Vector3.UP, Vector3.UP, ledge, 0.0, 0.0)
		# Aluminium frame and the central meeting stile of a sliding sash.
		var plane := recess - .06
		_quad_flat(origin - n * plane, n, t, left, right, head - FRAME, head, metal, 0.0, 0.0)
		_quad_flat(origin - n * plane, n, t, left, right, sill, sill + FRAME, metal, 0.0, 0.0)
		_quad_flat(origin - n * plane, n, t, left, left + FRAME, sill, head, metal, 0.0, 0.0)
		_quad_flat(origin - n * plane, n, t, right - FRAME, right, sill, head, metal, 0.0, 0.0)
		if shop < .5: _quad_flat(origin - n * plane, n, t, u - FRAME * .5, u + FRAME * .5, sill, head, metal, 0.0, 0.0)
		_pane(origin, t, n, u, left, right, sill, head, half, recess, spec, glass, shop)
		# Security grille over small or low windows, standard on Japanese stairs and baths.
		if shop < .5 and (half < .4 or y0 < .1) and recess < .25:
			var rods := int(half * 2.0 / .14)
			for rod: int in range(1, rods):
				var at_x := left + float(rod) * half * 2.0 / float(rods)
				_quad_flat(origin + n * .03, n, t, at_x - .012, at_x + .012, sill - .04, head + .04, metal, 0.0, 0.0)
			_quad_flat(origin + n * .03, n, t, left - .03, right + .03, head + .01, head + .05, metal, 0.0, 0.0)
			_quad_flat(origin + n * .03, n, t, left - .03, right + .03, sill - .05, sill - .01, metal, 0.0, 0.0)
	_quad_flat(origin, n, t, previous, run, sill, head, pier, .1, .1)

func _quad_flat(origin: Vector3, n: Vector3, t: Vector3, u0: float, u1: float, y0: float, y1: float, tint: Color, grime_low: float, grime_high: float) -> void:
	if u1 - u0 < .001 or y1 - y0 < .001: return
	var a := origin + t * u0 + Vector3.UP * y0
	var b := origin + t * u0 + Vector3.UP * y1
	var c := origin + t * u1 + Vector3.UP * y1
	var d := origin + t * u1 + Vector3.UP * y0
	_quad(a, b, c, d, n, n, tint, grime_low, grime_high)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n1: Vector3, n2: Vector3, tint: Color, low: float, high: float) -> void:
	# Godot faces are clockwise from outside; fix up whichever order arrived.
	# Four corners a b c d, written straight into the wall arrays: a and b carry normal 1
	# (uv low / high), c and d normal 2 (uv high / low); each normal's tangent is worked
	# out once. The two triangles are indexed: a b c, a c d, or a c b, a d c when flipped.
	var flip := (b - a).cross(c - a).dot(n1 + n2) > 0.0
	var t1 := _tangent(n1)
	var t2 := t1 if n2 == n1 else _tangent(n2)
	var ul := Vector2(low, 0)
	var uh := Vector2(high, 0)
	var x1 := t1.x
	var y1 := t1.y
	var z1 := t1.z
	var x2 := t2.x
	var y2 := t2.y
	var z2 := t2.z
	var base := _v.size()
	_v.append(a); _v.append(b); _v.append(c); _v.append(d)
	_n.append(n1); _n.append(n1); _n.append(n2); _n.append(n2)
	_t.append(x1); _t.append(y1); _t.append(z1); _t.append(1.0)
	_t.append(x1); _t.append(y1); _t.append(z1); _t.append(1.0)
	_t.append(x2); _t.append(y2); _t.append(z2); _t.append(1.0)
	_t.append(x2); _t.append(y2); _t.append(z2); _t.append(1.0)
	_u.append(ul); _u.append(uh); _u.append(uh); _u.append(ul)
	if flip:
		_i.append(base); _i.append(base + 2); _i.append(base + 1); _i.append(base); _i.append(base + 3); _i.append(base + 2)
	else:
		_i.append(base); _i.append(base + 1); _i.append(base + 2); _i.append(base); _i.append(base + 2); _i.append(base + 3)
	_c.append(tint); _c.append(tint); _c.append(tint); _c.append(tint)
	_u2.resize(_u2.size() + 4)

static func mesh_of(part: Dictionary) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = part.v
	arrays[Mesh.ARRAY_NORMAL] = part.n
	arrays[Mesh.ARRAY_TANGENT] = part.t
	arrays[Mesh.ARRAY_COLOR] = part.c
	arrays[Mesh.ARRAY_TEX_UV] = part.u
	arrays[Mesh.ARRAY_TEX_UV2] = part.u2
	# Indexed when the emitter wrote indices (every corner is covered); plain triangles otherwise.
	if part.has("i") and not (part.i as PackedInt32Array).is_empty(): arrays[Mesh.ARRAY_INDEX] = part.i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
