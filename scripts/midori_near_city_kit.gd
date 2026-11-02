extends RefCounted
## Mesh kit for hand-modelled buildings: every part is real geometry, grouped by
## material. UV is metres on the surface, so textures keep their true scale.
## COLOR.a is baked occlusion, UV2.x how hard rain has streaked the part.
const Hero := preload("res://scripts/midori_near_city_hero.gd")

var _parts := {}

func _part(part: String) -> Dictionary:
	if not _parts.has(part):
		_parts[part] = {"v":PackedVector3Array(), "n":PackedVector3Array(), "t":PackedFloat32Array(), "c":PackedColorArray(), "u":PackedVector2Array(), "u2":PackedVector2Array()}
	return _parts[part]

func _emit(target: Dictionary, p: Vector3, n: Vector3, tangent: Vector3, tint: Color, uv: Vector2, uv2: Vector2) -> void:
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
	var target := _part(part)
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
	for row: Array in [[a, ua, low], [b, ub, high], [c, uc, high], [a, ua, low], [c, uc, high], [d, ud, low]]:
		_emit(target, row[0], n, tangent, _shaded(tint, row[2]), row[1], rain)

func smooth(part: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, tint: Color, ao := 1.0) -> void:
	# As quad, with a normal per corner; winding follows the normals.
	if (d - a).cross(b - a).dot(na + nb + nc + nd) < 0.0:
		var far := b
		b = d
		d = far
		var far_n := nb
		nb = nd
		nd = far_n
	var target := _part(part)
	var tangent := (d - a).normalized()
	var shaded := _shaded(tint, ao)
	for row: Array in [[a, na], [b, nb], [c, nc], [a, na], [c, nc], [d, nd]]:
		_emit(target, row[0], row[1], tangent, shaded, Vector2((row[0] as Vector3).x + (row[0] as Vector3).z, (row[0] as Vector3).y), Vector2.ZERO)

func mapped(part: String, points: Array[Vector3], normals: Array[Vector3], prints: Array[Vector2], marks: Array[float], tint: Color, ao := 1.0) -> void:
	# As smooth, with an atlas position and a shader weight (UV2.x) at each of the four corners.
	var order: Array[int] = [0, 1, 2, 0, 2, 3]
	if (points[3] - points[0]).cross(points[1] - points[0]).dot(normals[0] + normals[1] + normals[2] + normals[3]) < 0.0:
		order = [0, 3, 2, 0, 2, 1]
	var target := _part(part)
	var tangent := (points[3] - points[0]).normalized()
	var shaded := _shaded(tint, ao)
	for i: int in order:
		_emit(target, points[i], normals[i], tangent, shaded, prints[i], Vector2(marks[i], 0))

func atlas(part: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, rect: Rect2, tint := Color.WHITE, ao := 1.0, streak := 0.0) -> void:
	# A quad showing one panel of an atlas; rect is in 0-1 texture space.
	var target := _part(part)
	var n := (d - a).cross(b - a).normalized()
	var tangent := (d - a).normalized()
	var shaded := _shaded(tint, ao)
	var rain := Vector2(streak, 0)
	var ua := rect.position + Vector2(0, rect.size.y)
	var ub := rect.position
	var uc := rect.position + Vector2(rect.size.x, 0)
	var ud := rect.position + rect.size
	for row: Array in [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]:
		_emit(target, row[0], n, tangent, shaded, row[1], rain)

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
	var target := _part(part)
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
			for row: Array in [[d, n1, Vector2(u1, v0)], [c, n1, Vector2(u1, v1)], [b, n0, Vector2(u0, v1)], [d, n1, Vector2(u1, v0)], [b, n0, Vector2(u0, v1)], [a, n0, Vector2(u0, v0)]]:
				_emit(target, row[0], row[1], tangent, shaded, row[2], Vector2.ZERO)

func disc(part: String, centre: Vector3, right: Vector3, up: Vector3, radius: float, tint: Color, rect := Rect2()) -> void:
	# Flat round face; with rect, a square atlas panel shows on it.
	var target := _part(part)
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
		for row: Array in [[centre, middle], [centre + (right * ring0.x + up * ring0.y) * radius, uv0], [centre + (right * ring1.x + up * ring1.y) * radius, uv1]]:
			_emit(target, row[0], n, right, shaded, row[1], Vector2.ZERO)

func pane(part: String, xf: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, cell: float) -> void:
	# A window for the shared glass shader: UV is metres from its centre.
	var target := _part(part)
	var half := Vector2((x1 - x0) * .5, (y1 - y0) * .5)
	var info := Vector2(cell, floorf(half.x * 100.0) + half.y * .1)
	var n := xf.basis.z.normalized()
	var tangent := xf.basis.x.normalized()
	var a := xf * Vector3(x0, y0, z)
	var b := xf * Vector3(x0, y1, z)
	var c := xf * Vector3(x1, y1, z)
	var d := xf * Vector3(x1, y0, z)
	for row: Array in [[a, Vector2(-half.x, -half.y)], [b, Vector2(-half.x, half.y)], [c, half], [a, Vector2(-half.x, -half.y)], [c, half], [d, Vector2(half.x, -half.y)]]:
		_emit(target, row[0], n, tangent, Color.WHITE, row[1], info)

func commit(parent: Node3D, looks: Dictionary, unshadowed: Array[String]) -> void:
	for part: String in _parts:
		var instance := MeshInstance3D.new()
		instance.name = "Part_" + part
		instance.mesh = Hero.mesh_of(_parts[part])
		instance.material_override = looks[part]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if part in unshadowed else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		parent.add_child(instance)
	_parts.clear()
