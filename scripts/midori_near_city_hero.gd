extends RefCounted
## Real shells for the buildings closest to the park: rounded corners, window
## openings with true reveals, sills and aluminium frames, so sun and shadow fall
## on actual depth. Merged per chunk; the buildings behind stay shader boxes.
const CORNER_STEPS := 4
const FRAME := .05
const SHOP_UNIT := 6.0

var _walls := {}
var _glass := {}
var _part: Dictionary

func add(centre: Vector2, base: float, size: Vector3, front: int, key: int, spec: Dictionary) -> void:
	_part = _surface(_walls, key)
	var glass := _surface(_glass, key)
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
	# Roof, floored in dark membrane.
	var y := base + size.y
	var half := Vector2(size.x, size.z) * .5
	_quad(Vector3(centre.x - half.x, y, centre.y - half.y), Vector3(centre.x - half.x, y, centre.y + half.y), Vector3(centre.x + half.x, y, centre.y + half.y), Vector3(centre.x + half.x, y, centre.y - half.y), Vector3.UP, Vector3.UP, Color(.36, .36, .36, 3.0 / 8.0), 0.0, 0.0)

func walls() -> Dictionary:
	return _walls

func glass() -> Dictionary:
	return _glass

func _surface(table: Dictionary, key: int) -> Dictionary:
	if not table.has(key):
		table[key] = {"v":PackedVector3Array(), "n":PackedVector3Array(), "t":PackedFloat32Array(), "c":PackedColorArray(), "u":PackedVector2Array(), "u2":PackedVector2Array()}
	return table[key]

func _face(origin: Vector3, n: Vector3, width: float, height: float, role: int, spec: Dictionary, glass: Dictionary) -> void:
	var t := Vector3.UP.cross(n)
	var run := width * .5 - float(spec.radius)
	var ground: float = spec.ground
	var storey: float = spec.storey
	var bay: float = width / maxf(1.0, floorf(width / float(spec.bay) + .5))
	var pane := Vector2(bay * float(spec.pane_x), float(spec.pane_y))
	if role == 1 and spec.mansion: pane = Vector2(.5, .62)
	var y := 0.0
	if ground > 0.0:
		if role == 0:
			var units := maxf(1.0, floorf(width / SHOP_UNIT + .5))
			var unit := width / units
			var openings: Array[float] = []
			for i: int in range(int(units)): openings.append(-width * .5 + unit * (float(i) + .5))
			_row(origin, n, t, run, 0.0, ground, .12, 3.05, openings, unit * .45, .14, spec, glass, 1.0)
		else:
			_quad_flat(origin, n, t, -run, run, 0.0, ground, spec.tint, 0.0, 0.0)
		y = ground
	var floor_index := 0
	while y + storey <= height - .3:
		var openings: Array[float] = []
		var half_pane := pane.x
		var tall := pane.y
		if role == 2:
			# Party walls stay blank, bar the odd stair or bathroom window.
			half_pane = .36
			tall = .5
			if floor_index % 3 == 1: openings.append(sin(float(spec.seed) * 90.0) * run * .5)
		else:
			var cells := int(floorf(width / bay + .5))
			for i: int in range(cells): openings.append(-width * .5 + bay * (float(i) + .5))
		var centre_y: float = y + storey * float(spec.sill)
		_row(origin, n, t, run, y, y + storey, centre_y - tall, centre_y + tall, openings, half_pane, spec.recess, spec, glass, 0.0)
		if role != 2 or floor_index % 2 == 0: _ledge(origin, n, t, run, y, spec.tint)
		y += storey
		floor_index += 1
	if y < height: _quad_flat(origin, n, t, -run, run, y, height, spec.tint, 0.0, 0.0)

func _ledge(origin: Vector3, n: Vector3, t: Vector3, run: float, y: float, tint: Color) -> void:
	# A slab edge standing just proud of the wall, so each floor throws a real shadow.
	var band := tint.darkened(.06)
	var proud := n * .07
	_quad(origin + proud + t * -run + Vector3.UP * (y - .09), origin + proud + t * -run + Vector3.UP * (y + .09), origin + proud + t * run + Vector3.UP * (y + .09), origin + proud + t * run + Vector3.UP * (y - .09), n, n, band, 0.0, .2)
	_quad(origin + proud + t * -run + Vector3.UP * (y + .09), origin + t * -run + Vector3.UP * (y + .09), origin + t * run + Vector3.UP * (y + .09), origin + proud + t * run + Vector3.UP * (y + .09), Vector3.UP, Vector3.UP, band, 0.0, 0.0)
	_quad(origin + t * -run + Vector3.UP * (y - .09), origin + proud + t * -run + Vector3.UP * (y - .09), origin + proud + t * run + Vector3.UP * (y - .09), origin + t * run + Vector3.UP * (y - .09), Vector3.DOWN, Vector3.DOWN, band, 0.0, 0.0)

func _row(origin: Vector3, n: Vector3, t: Vector3, run: float, y0: float, y1: float, sill: float, head: float, openings: Array[float], half: float, recess: float, spec: Dictionary, glass: Dictionary, shop: float) -> void:
	var tint: Color = spec.tint
	var metal: Color = spec.metal
	_quad_flat(origin, n, t, -run, run, y0, sill, tint, 0.0, .3)
	_quad_flat(origin, n, t, -run, run, head, y1, tint, 0.0, 0.0)
	var previous := -run
	for u: float in openings:
		if absf(u) + half > run - .08:
			continue
		_quad_flat(origin, n, t, previous, u - half, sill, head, tint, .1, .1)
		previous = u + half
		var left := u - half
		var right := u + half
		var reveal := tint.darkened(.08)
		var at := func(x: float, y: float, d: float) -> Vector3: return origin + t * x + Vector3.UP * y - n * d
		_quad(at.call(left, sill, 0.0), at.call(left, head, 0.0), at.call(left, head, recess), at.call(left, sill, recess), t, t, reveal, 0.0, 0.0)
		_quad(at.call(right, sill, recess), at.call(right, head, recess), at.call(right, head, 0.0), at.call(right, sill, 0.0), -t, -t, reveal, 0.0, 0.0)
		_quad(at.call(left, head, 0.0), at.call(left, head, recess), at.call(right, head, recess), at.call(right, head, 0.0), Vector3.DOWN, Vector3.DOWN, reveal, 0.0, 0.0)
		_quad(at.call(left, sill, recess), at.call(left, sill, 0.0), at.call(right, sill, 0.0), at.call(right, sill, recess), Vector3.UP, Vector3.UP, reveal, 0.0, 0.0)
		# Pre-cast sill proud of the wall.
		var ledge := tint.lightened(.12)
		_quad(at.call(left - .05, sill - .07, -.06), at.call(left - .05, sill, -.06), at.call(right + .05, sill, -.06), at.call(right + .05, sill - .07, -.06), n, n, ledge, 0.0, 0.0)
		_quad(at.call(left - .05, sill, -.06), at.call(left - .05, sill, 0.0), at.call(right + .05, sill, 0.0), at.call(right + .05, sill, -.06), Vector3.UP, Vector3.UP, ledge, 0.0, 0.0)
		# Aluminium frame and the central meeting stile of a sliding sash.
		var plane := recess - .06
		_quad_flat(origin - n * plane, n, t, left, right, head - FRAME, head, metal, 0.0, 0.0)
		_quad_flat(origin - n * plane, n, t, left, right, sill, sill + FRAME, metal, 0.0, 0.0)
		_quad_flat(origin - n * plane, n, t, left, left + FRAME, sill, head, metal, 0.0, 0.0)
		_quad_flat(origin - n * plane, n, t, right - FRAME, right, sill, head, metal, 0.0, 0.0)
		if shop < .5: _quad_flat(origin - n * plane, n, t, u - FRAME * .5, u + FRAME * .5, sill, head, metal, 0.0, 0.0)
		# The pane itself; its UV is metres from the pane centre, for the room behind.
		var cell := fposmod(float(spec.seed) * 37.0 + u * .73 + sill * 1.31, 1.0)
		var middle := (sill + head) * .5
		var extent := Vector2(half, (head - sill) * .5)
		var info := Vector2(cell + shop * 2.0, floorf(extent.x * 100.0) + extent.y * .1)
		var saved := _part
		_part = glass
		_vertex(at.call(left, sill, recess), n, Color.WHITE, Vector2(-extent.x, -extent.y), info)
		_vertex(at.call(left, head, recess), n, Color.WHITE, Vector2(-extent.x, extent.y), info)
		_vertex(at.call(right, head, recess), n, Color.WHITE, Vector2(extent.x, extent.y), info)
		_vertex(at.call(left, sill, recess), n, Color.WHITE, Vector2(-extent.x, -extent.y), info)
		_vertex(at.call(right, head, recess), n, Color.WHITE, Vector2(extent.x, extent.y), info)
		_vertex(at.call(right, sill, recess), n, Color.WHITE, Vector2(extent.x, -extent.y), info)
		_part = saved
		if middle < 0.0: push_error("pane below ground")
	_quad_flat(origin, n, t, previous, run, sill, head, tint, .1, .1)

func _quad_flat(origin: Vector3, n: Vector3, t: Vector3, u0: float, u1: float, y0: float, y1: float, tint: Color, grime_low: float, grime_high: float) -> void:
	if u1 - u0 < .001 or y1 - y0 < .001: return
	var a := origin + t * u0 + Vector3.UP * y0
	var b := origin + t * u0 + Vector3.UP * y1
	var c := origin + t * u1 + Vector3.UP * y1
	var d := origin + t * u1 + Vector3.UP * y0
	_quad(a, b, c, d, n, n, tint, grime_low, grime_high)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n1: Vector3, n2: Vector3, tint: Color, low: float, high: float) -> void:
	# Godot faces are clockwise from outside; fix up whichever order arrived.
	var flip := (b - a).cross(c - a).dot(n1 + n2) > 0.0
	if flip:
		_vertex(a, n1, tint, Vector2(low, 0), Vector2.ZERO)
		_vertex(c, n2, tint, Vector2(high, 0), Vector2.ZERO)
		_vertex(b, n1, tint, Vector2(high, 0), Vector2.ZERO)
		_vertex(a, n1, tint, Vector2(low, 0), Vector2.ZERO)
		_vertex(d, n2, tint, Vector2(low, 0), Vector2.ZERO)
		_vertex(c, n2, tint, Vector2(high, 0), Vector2.ZERO)
	else:
		_vertex(a, n1, tint, Vector2(low, 0), Vector2.ZERO)
		_vertex(b, n1, tint, Vector2(high, 0), Vector2.ZERO)
		_vertex(c, n2, tint, Vector2(high, 0), Vector2.ZERO)
		_vertex(a, n1, tint, Vector2(low, 0), Vector2.ZERO)
		_vertex(c, n2, tint, Vector2(high, 0), Vector2.ZERO)
		_vertex(d, n2, tint, Vector2(low, 0), Vector2.ZERO)

func _vertex(p: Vector3, n: Vector3, color: Color, uv: Vector2, uv2: Vector2) -> void:
	var part := _part
	part.v.append(p)
	part.n.append(n)
	var t := Vector3.UP.cross(n)
	if t.length_squared() < .01: t = Vector3.RIGHT
	t = t.normalized()
	part.t.append(t.x)
	part.t.append(t.y)
	part.t.append(t.z)
	part.t.append(1.0)
	part.c.append(color)
	part.u.append(uv)
	part.u2.append(uv2)

static func mesh_of(part: Dictionary) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = part.v
	arrays[Mesh.ARRAY_NORMAL] = part.n
	arrays[Mesh.ARRAY_TANGENT] = part.t
	arrays[Mesh.ARRAY_COLOR] = part.c
	arrays[Mesh.ARRAY_TEX_UV] = part.u
	arrays[Mesh.ARRAY_TEX_UV2] = part.u2
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
