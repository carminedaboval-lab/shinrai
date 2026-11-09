extends RefCounted
## Mesh kit for hand-modelled buildings: every part is real geometry, grouped by
## material. UV is metres on the surface, so textures keep their true scale.
## COLOR.a is baked occlusion, UV2.x how hard rain has streaked the part.
const Hero := preload("res://scripts/midori_near_city_hero.gd")

var _parts := {}
# The part being written keeps its arrays in these members (its entry in _parts holds
# empty stand-ins meanwhile): appending to a member is in place and several times cheaper
# than a Dictionary lookup per value. _part() and _emit() hand the arrays back first, so
# callers that edit a part's arrays directly still see and change the real ones.
# Every part is indexed ("i"): a quad is four corners and six indices, a lone corner
# indexes itself, so the index list always covers every vertex and the triangles drawn
# are exactly those of the six-corner form (a third fewer vertex bytes on the GPU).
var _cur := ""
var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _t := PackedFloat32Array()
var _c := PackedColorArray()
var _u := PackedVector2Array()
var _u2 := PackedVector2Array()
var _i := PackedInt32Array()

func _part(part: String) -> Dictionary:
	_park()
	if not _parts.has(part):
		_parts[part] = {"v":PackedVector3Array(), "n":PackedVector3Array(), "t":PackedFloat32Array(), "c":PackedColorArray(), "u":PackedVector2Array(), "u2":PackedVector2Array(), "i":PackedInt32Array()}
	return _parts[part]

func _park() -> void:
	# Hands the current part's arrays back to its entry in _parts.
	if _cur == "": return
	var target: Dictionary = _parts[_cur]
	target.v = _v
	target.n = _n
	target.t = _t
	target.c = _c
	target.u = _u
	target.u2 = _u2
	target.i = _i
	_v = PackedVector3Array()
	_n = PackedVector3Array()
	_t = PackedFloat32Array()
	_c = PackedColorArray()
	_u = PackedVector2Array()
	_u2 = PackedVector2Array()
	_i = PackedInt32Array()
	_cur = ""

func _use(part: String) -> void:
	# Makes part the one the members write to (creating it, in first-use order, if new).
	if part == _cur: return
	var target := _part(part)
	_v = target.v
	_n = target.n
	_t = target.t
	_c = target.c
	_u = target.u
	_u2 = target.u2
	_i = target.i
	target.v = PackedVector3Array()
	target.n = PackedVector3Array()
	target.t = PackedFloat32Array()
	target.c = PackedColorArray()
	target.u = PackedVector2Array()
	target.u2 = PackedVector2Array()
	target.i = PackedInt32Array()
	_cur = part

func _vx(p: Vector3, n: Vector3, tangent: Vector3, tint: Color, uv: Vector2, uv2: Vector2) -> void:
	# One corner of a plain triangle: it indexes itself.
	_i.append(_v.size())
	_v.append(p)
	_n.append(n)
	_t.append(tangent.x)
	_t.append(tangent.y)
	_t.append(tangent.z)
	_t.append(1.0)
	_c.append(tint)
	_u.append(uv)
	_u2.append(uv2)

func _corner(p: Vector3, n: Vector3, tangent: Vector3, tint: Color, uv: Vector2, uv2: Vector2) -> void:
	# One corner of an indexed quad; the caller writes the indices.
	_v.append(p)
	_n.append(n)
	_t.append(tangent.x)
	_t.append(tangent.y)
	_t.append(tangent.z)
	_t.append(1.0)
	_c.append(tint)
	_u.append(uv)
	_u2.append(uv2)

func _quad_indices(base: int) -> void:
	# Corners base .. base+3 as the triangles 0 1 2 and 0 2 3.
	_i.append(base); _i.append(base + 1); _i.append(base + 2); _i.append(base); _i.append(base + 2); _i.append(base + 3)

func _emit(target: Dictionary, p: Vector3, n: Vector3, tangent: Vector3, tint: Color, uv: Vector2, uv2: Vector2) -> void:
	if _cur != "" and is_same(target, _parts[_cur]): _park()
	target.i.append(target.v.size())
	target.v.append(p)
	target.n.append(n)
	target.t.append(tangent.x)
	target.t.append(tangent.y)
	target.t.append(tangent.z)
	target.t.append(1.0)
	target.c.append(tint)
	target.u.append(uv)
	target.u2.append(uv2)

func _shaded(tint: Color, ao: float) -> Color:
	return Color(tint.r, tint.g, tint.b, ao)

func quad(part: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color, low := 1.0, high := 1.0, streak := 0.0, uv := Vector2.ZERO) -> void:
	# a, b, c, d run bottom-left, top-left, top-right, bottom-right seen from outside.
	_use(part)
	var n := (d - a).cross(b - a).normalized()
	var tangent := (d - a).normalized()
	var wide := a.distance_to(d)
	var left := a.distance_to(b)
	var right := d.distance_to(c)
	var rain := Vector2(streak, 0)
	var ua := uv
	var ub := uv + Vector2(0, -left)
	var uc := uv + Vector2(wide, -right)
	var ud := uv + Vector2(wide, 0)
	var dim := _shaded(tint, low)
	var lit := _shaded(tint, high)
	# The four corners a b c d, written out, drawn as a b c and a c d: the commonest call in every building.
	var base := _v.size()
	_v.append(a); _v.append(b); _v.append(c); _v.append(d)
	_n.append(n); _n.append(n); _n.append(n); _n.append(n)
	var tx := tangent.x
	var ty := tangent.y
	var tz := tangent.z
	_t.append(tx); _t.append(ty); _t.append(tz); _t.append(1.0)
	_t.append(tx); _t.append(ty); _t.append(tz); _t.append(1.0)
	_t.append(tx); _t.append(ty); _t.append(tz); _t.append(1.0)
	_t.append(tx); _t.append(ty); _t.append(tz); _t.append(1.0)
	_c.append(dim); _c.append(lit); _c.append(lit); _c.append(dim)
	_u.append(ua); _u.append(ub); _u.append(uc); _u.append(ud)
	_u2.append(rain); _u2.append(rain); _u2.append(rain); _u2.append(rain)
	_quad_indices(base)

func smooth(part: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, tint: Color, ao := 1.0) -> void:
	# As quad, with a normal per corner; winding follows the normals.
	if (d - a).cross(b - a).dot(na + nb + nc + nd) < 0.0:
		var far := b
		b = d
		d = far
		var far_n := nb
		nb = nd
		nd = far_n
	_use(part)
	var tangent := (d - a).normalized()
	var shaded := _shaded(tint, ao)
	var uva := Vector2(a.x + a.z, a.y)
	var uvc := Vector2(c.x + c.z, c.y)
	# The four corners a b c d, drawn as a b c and a c d (tubes and lathes come through here).
	var base := _v.size()
	_v.append(a); _v.append(b); _v.append(c); _v.append(d)
	_n.append(na); _n.append(nb); _n.append(nc); _n.append(nd)
	var tx := tangent.x
	var ty := tangent.y
	var tz := tangent.z
	_t.append(tx); _t.append(ty); _t.append(tz); _t.append(1.0)
	_t.append(tx); _t.append(ty); _t.append(tz); _t.append(1.0)
	_t.append(tx); _t.append(ty); _t.append(tz); _t.append(1.0)
	_t.append(tx); _t.append(ty); _t.append(tz); _t.append(1.0)
	_c.append(shaded); _c.append(shaded); _c.append(shaded); _c.append(shaded)
	_u.append(uva); _u.append(Vector2(b.x + b.z, b.y)); _u.append(uvc); _u.append(Vector2(d.x + d.z, d.y))
	_u2.resize(_u2.size() + 4)
	_quad_indices(base)

func mapped(part: String, points: Array[Vector3], normals: Array[Vector3], prints: Array[Vector2], marks: Array[float], tint: Color, ao := 1.0) -> void:
	# As smooth, with an atlas position and a shader weight (UV2.x) at each of the four corners.
	var order: Array[int] = [0, 1, 2, 0, 2, 3]
	if (points[3] - points[0]).cross(points[1] - points[0]).dot(normals[0] + normals[1] + normals[2] + normals[3]) < 0.0:
		order = [0, 3, 2, 0, 2, 1]
	_use(part)
	var tangent := (points[3] - points[0]).normalized()
	var shaded := _shaded(tint, ao)
	var base := _v.size()
	for i: int in range(4):
		_corner(points[i], normals[i], tangent, shaded, prints[i], Vector2(marks[i], 0))
	for i: int in order: _i.append(base + i)

func atlas(part: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, rect: Rect2, tint := Color.WHITE, ao := 1.0, streak := 0.0) -> void:
	# A quad showing one panel of an atlas; rect is in 0-1 texture space.
	_use(part)
	var n := (d - a).cross(b - a).normalized()
	var tangent := (d - a).normalized()
	var shaded := _shaded(tint, ao)
	var rain := Vector2(streak, 0)
	var ua := rect.position + Vector2(0, rect.size.y)
	var ub := rect.position
	var uc := rect.position + Vector2(rect.size.x, 0)
	var ud := rect.position + rect.size
	var base := _v.size()
	_corner(a, n, tangent, shaded, ua, rain)
	_corner(b, n, tangent, shaded, ub, rain)
	_corner(c, n, tangent, shaded, uc, rain)
	_corner(d, n, tangent, shaded, ud, rain)
	_quad_indices(base)

func block(part: String, xf: Transform3D, size: Vector3, tint: Color, low := 1.0, high := 1.0, streak := 0.0, uv := Vector2.ZERO) -> void:
	# Six faces around xf.origin; low and high shade its underside and top ends.
	var half := size * .5
	var lbf := xf * Vector3(-half.x, -half.y, half.z)
	var ltf := xf * Vector3(-half.x, half.y, half.z)
	var rtf := xf * Vector3(half.x, half.y, half.z)
	var rbf := xf * Vector3(half.x, -half.y, half.z)
	var lbb := xf * Vector3(-half.x, -half.y, -half.z)
	var ltb := xf * Vector3(-half.x, half.y, -half.z)
	var rtb := xf * Vector3(half.x, half.y, -half.z)
	var rbb := xf * Vector3(half.x, -half.y, -half.z)
	quad(part, lbf, ltf, rtf, rbf, tint, low, high, streak, uv)
	quad(part, rbb, rtb, ltb, lbb, tint, low, high, streak, uv)
	quad(part, rbf, rtf, rtb, rbb, tint, low, high, streak, uv)
	quad(part, lbb, ltb, ltf, lbf, tint, low, high, streak, uv)
	quad(part, ltf, ltb, rtb, rtf, tint, high, high, 0.0, uv)
	quad(part, lbb, lbf, rbf, rbb, tint, low * .7, low * .7, 0.0, uv)

func beam(part: String, from: Vector3, to: Vector3, wide: float, thick: float, up: Vector3, tint: Color, ao := 1.0) -> void:
	# Square section between two points; up sets which way its thickness faces.
	var along := (to - from).normalized()
	var x := up.cross(along).normalized()
	var y := along.cross(x)
	block(part, Transform3D(Basis(x, y, along), (from + to) * .5), Vector3(wide, thick, from.distance_to(to)), tint, ao, ao)

func tube(part: String, points: Array[Vector3], radius: float, tint: Color, sides := 6, ao := 1.0) -> void:
	# Round section swept through points, carrying its frame round each bend.
	var side := Vector3.ZERO
	var ring_before := PackedVector3Array()
	var normals_before := PackedVector3Array()
	for i: int in range(points.size()):
		var dir := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		if side == Vector3.ZERO: side = (Vector3.RIGHT if absf(dir.x) < .8 else Vector3.BACK).cross(dir).normalized()
		side = (side - dir * side.dot(dir)).normalized()
		var over := dir.cross(side)
		var ring := PackedVector3Array()
		var normals := PackedVector3Array()
		for k: int in range(sides):
			var angle := TAU * float(k) / float(sides)
			var n := side * cos(angle) + over * sin(angle)
			normals.append(n)
			ring.append(points[i] + n * radius)
		if i > 0:
			for k: int in range(sides):
				var next := (k + 1) % sides
				smooth(part, ring_before[k], ring[k], ring[next], ring_before[next], normals_before[k], normals[k], normals[next], normals_before[next], tint, ao)
		ring_before = ring
		normals_before = normals

func lathe(part: String, base: Vector3, profile: Array[Vector2], tint: Color, sides := 12, rect := Rect2()) -> void:
	# Turned shape: profile is radius and height. With rect, it wraps an atlas panel.
	_use(part)
	var shaded := _shaded(tint, 1.0)
	var bottom := profile[0].y
	var span := maxf(profile[profile.size() - 1].y - bottom, .001)
	for j: int in range(profile.size() - 1):
		var p0 := profile[j]
		var p1 := profile[j + 1]
		var slope := Vector2(p1.y - p0.y, p0.x - p1.x).normalized()
		for k: int in range(sides):
			var a0 := TAU * float(k) / float(sides)
			var a1 := TAU * float(k + 1) / float(sides)
			var dir0 := Vector3(cos(a0), 0, sin(a0))
			var dir1 := Vector3(cos(a1), 0, sin(a1))
			var n0 := (dir0 * slope.x + Vector3.UP * slope.y).normalized()
			var n1 := (dir1 * slope.x + Vector3.UP * slope.y).normalized()
			var a := base + dir0 * p0.x + Vector3.UP * p0.y
			var b := base + dir0 * p1.x + Vector3.UP * p1.y
			var c := base + dir1 * p1.x + Vector3.UP * p1.y
			var d := base + dir1 * p0.x + Vector3.UP * p0.y
			if rect.size == Vector2.ZERO:
				smooth(part, a, b, c, d, n0, n0, n1, n1, tint)
				continue
			var u0 := rect.end.x - rect.size.x * float(k) / float(sides)
			var u1 := rect.end.x - rect.size.x * float(k + 1) / float(sides)
			var v0 := rect.position.y + rect.size.y * (1.0 - (p0.y - bottom) / span)
			var v1 := rect.position.y + rect.size.y * (1.0 - (p1.y - bottom) / span)
			var tangent := (d - a).normalized()
			var uvd := Vector2(u1, v0)
			var uvb := Vector2(u0, v1)
			# Corners d c b a, drawn as d c b and d b a.
			var first := _v.size()
			_corner(d, n1, tangent, shaded, uvd, Vector2.ZERO)
			_corner(c, n1, tangent, shaded, Vector2(u1, v1), Vector2.ZERO)
			_corner(b, n0, tangent, shaded, uvb, Vector2.ZERO)
			_corner(a, n0, tangent, shaded, Vector2(u0, v0), Vector2.ZERO)
			_quad_indices(first)

func disc(part: String, centre: Vector3, right: Vector3, up: Vector3, radius: float, tint: Color, rect := Rect2()) -> void:
	# Flat round face; with rect, a square atlas panel shows on it.
	_use(part)
	var n := right.cross(up).normalized()
	var shaded := _shaded(tint, 1.0)
	var steps := 24
	var middle := rect.get_center()
	for i: int in range(steps):
		var a0 := -TAU * float(i) / float(steps)
		var a1 := -TAU * float(i + 1) / float(steps)
		var ring0 := Vector2(cos(a0), sin(a0))
		var ring1 := Vector2(cos(a1), sin(a1))
		var uv0 := middle + Vector2(ring0.x, -ring0.y) * rect.size * .5
		var uv1 := middle + Vector2(ring1.x, -ring1.y) * rect.size * .5
		_vx(centre, n, right, shaded, middle, Vector2.ZERO)
		_vx(centre + (right * ring0.x + up * ring0.y) * radius, n, right, shaded, uv0, Vector2.ZERO)
		_vx(centre + (right * ring1.x + up * ring1.y) * radius, n, right, shaded, uv1, Vector2.ZERO)

func pane(part: String, xf: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, cell: float) -> void:
	# A window for the shared glass shader: UV is metres from its centre.
	_use(part)
	var half := Vector2((x1 - x0) * .5, (y1 - y0) * .5)
	var info := Vector2(cell, floorf(half.x * 100.0) + half.y * .1)
	var n := xf.basis.z.normalized()
	var tangent := xf.basis.x.normalized()
	var a := xf * Vector3(x0, y0, z)
	var b := xf * Vector3(x0, y1, z)
	var c := xf * Vector3(x1, y1, z)
	var d := xf * Vector3(x1, y0, z)
	var low := Vector2(-half.x, -half.y)
	var base := _v.size()
	_corner(a, n, tangent, Color.WHITE, low, info)
	_corner(b, n, tangent, Color.WHITE, Vector2(-half.x, half.y), info)
	_corner(c, n, tangent, Color.WHITE, half, info)
	_corner(d, n, tangent, Color.WHITE, Vector2(half.x, -half.y), info)
	_quad_indices(base)

func commit(parent: Node3D, looks: Dictionary, unshadowed: Array[String]) -> void:
	_park()
	for part: String in _parts:
		var instance := MeshInstance3D.new()
		instance.name = "Part_" + part
		instance.mesh = Hero.mesh_of(_parts[part])
		instance.material_override = looks[part]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if part in unshadowed else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		parent.add_child(instance)
	_parts.clear()
