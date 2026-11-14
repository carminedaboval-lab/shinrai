extends RefCounted
## Roofs for the interior kit, as real Japanese houses have them:
##   gable (kirizuma)        two planes and two gable walls
##   hip (yosemune)          four planes meeting in hip ridges
##   hip-and-gable (irimoya) a hipped skirt all round, a gable above it
##   lean-to (geya, hisashi) one plane against a wall: over a ground floor the upper floor is
##                           set back from, over a porch, over a shop front
## Every plane is a plate TILE thick with upright edges, so an eave reads as tile on its
## boards and not as a sheet. The ridge is a course of ridge tiles standing RIDGE above the
## planes; hips get a lower course. Nothing is drawn on a plane: no rows, no ribs.

const ShellMesh := preload("res://scripts/interior_kit/shell_mesh.gd")

const TILE := 0.14
const RIDGE := 0.14
## From the roof's underside at the ridge line to the top of the ridge tiles.
const RIDGE_TOP := TILE + RIDGE


## The main roof over the rectangle `rect` (x, z of the outer walls), whose underside meets
## the outer wall faces at height `y`. Returns {rise, plates (each one's corners, for
## collision), eaves ([a, b, out, wall_a, wall_b]: the low edges, for gutters)}.
static func main(shell: ShellMesh, rect: Rect2, y: float, opt: Dictionary, paint: Dictionary) -> Dictionary:
	var form := str(opt.get("form", "gable"))
	var along_x := str(opt.get("ridge", "x")) == "x"
	var pitch := float(opt.get("pitch", 0.45))
	var o := float(opt.get("eave", 0.45))
	var g := float(opt.get("gable", 0.30))
	var wall := float(opt.get("wall", 0.15))
	# A tiled roof, or (opt.thick, opt.ridge_high) a thin sheet-metal one with a low ridge cap.
	var tile := float(opt.get("thick", TILE))
	var ridge_high := float(opt.get("ridge_high", RIDGE))
	var length := rect.size.x if along_x else rect.size.y
	var span := rect.size.y if along_x else rect.size.x
	if form != "gable" and length < span:
		along_x = not along_x
		var swap := length
		length = span
		span = swap
	var half := span * 0.5
	var rise := half * pitch
	var inset := clampf(half * 0.5, 0.6, half - 0.3)
	if form == "irimoya" and length - inset * 2.0 < 1.0: form = "hip"
	var at := func(u: float, v: float, h: float) -> Vector3:
		return Vector3(rect.position.x + u, h, rect.position.y + v) if along_x else Vector3(rect.position.x + v, h, rect.position.y + u)
	# Height of each of the four planes' undersides at a point.
	var height := func(side: int, u: float, v: float) -> float:
		match side:
			0: return y + pitch * v
			1: return y + pitch * (span - v)
			2: return y + pitch * u
			_: return y + pitch * (length - u)
	var plates: Array = []
	var outlines: Array = []      # [side, [Vector2 ...]]
	var ridge_from := -g
	var ridge_to := length + g
	var hips: Array = []          # [side, Vector2 low, Vector2 high]
	match form:
		"hip":
			outlines.append([0, [Vector2(-o, -o), Vector2(length + o, -o), Vector2(length - half, half), Vector2(half, half)]])
			outlines.append([1, [Vector2(-o, span + o), Vector2(length + o, span + o), Vector2(length - half, half), Vector2(half, half)]])
			outlines.append([2, [Vector2(-o, -o), Vector2(-o, span + o), Vector2(half, half)]])
			outlines.append([3, [Vector2(length + o, -o), Vector2(length + o, span + o), Vector2(length - half, half)]])
			ridge_from = half
			ridge_to = length - half
			for corner: Vector2 in [Vector2(-o, -o), Vector2(-o, span + o)]: hips.append([2, corner, Vector2(half, half)])
			for corner: Vector2 in [Vector2(length + o, -o), Vector2(length + o, span + o)]: hips.append([3, corner, Vector2(length - half, half)])
		"irimoya":
			outlines.append([0, [Vector2(-o, -o), Vector2(length + o, -o), Vector2(length - inset, inset), Vector2(inset, inset)]])
			outlines.append([1, [Vector2(-o, span + o), Vector2(length + o, span + o), Vector2(length - inset, span - inset), Vector2(inset, span - inset)]])
			outlines.append([0, [Vector2(inset - g, inset), Vector2(length - inset + g, inset), Vector2(length - inset + g, half), Vector2(inset - g, half)]])
			outlines.append([1, [Vector2(inset - g, span - inset), Vector2(length - inset + g, span - inset), Vector2(length - inset + g, half), Vector2(inset - g, half)]])
			outlines.append([2, [Vector2(-o, -o), Vector2(-o, span + o), Vector2(inset, span - inset), Vector2(inset, inset)]])
			outlines.append([3, [Vector2(length + o, -o), Vector2(length + o, span + o), Vector2(length - inset, span - inset), Vector2(length - inset, inset)]])
			ridge_from = inset - g
			ridge_to = length - inset + g
			for corner: Vector2 in [Vector2(-o, -o), Vector2(-o, span + o)]: hips.append([2, corner, Vector2(inset, inset if corner.y < half else span - inset)])
			for corner: Vector2 in [Vector2(length + o, -o), Vector2(length + o, span + o)]: hips.append([3, corner, Vector2(length - inset, inset if corner.y < half else span - inset)])
			for end: Array in [[inset, 1.0], [length - inset, -1.0]]:
				var u := float(end[0])
				shell.wedge(at.call(u, inset, y + pitch * inset), at.call(u, span - inset, y + pitch * inset), at.call(u, half, y + rise), (at.call(u + wall * float(end[1]), 0.0, 0.0) as Vector3) - (at.call(u, 0.0, 0.0) as Vector3), paint.inner_wall, paint.gable_wall)
		_:
			outlines.append([0, [Vector2(-g, -o), Vector2(length + g, -o), Vector2(length + g, half), Vector2(-g, half)]])
			outlines.append([1, [Vector2(-g, span + o), Vector2(length + g, span + o), Vector2(length + g, half), Vector2(-g, half)]])
			for end: Array in [[0.0, 1.0], [length, -1.0]]:
				var u := float(end[0])
				shell.wedge(at.call(u, 0.0, y), at.call(u, span, y), at.call(u, half, y + rise), (at.call(u + wall * float(end[1]), 0.0, 0.0) as Vector3) - (at.call(u, 0.0, 0.0) as Vector3), paint.inner_wall, paint.gable_wall)
	var edge: Color = (paint.roof as Color).darkened(0.18)
	for outline: Array in outlines:
		var under := PackedVector3Array()
		for point: Vector2 in outline[1]: under.append(at.call(point.x, point.y, height.call(int(outline[0]), point.x, point.y)))
		shell.slab(under, tile, paint.roof, paint.soffit, edge)
		plates.append(under)
	# The ridge course, and its end tiles on an older roof.
	var ridge_wide := float(opt.get("ridge_wide", 0.24))
	var ridge_a: Vector3 = at.call(ridge_from, half, y + rise + tile + ridge_high * 0.5)
	var ridge_b: Vector3 = at.call(ridge_to, half, y + rise + tile + ridge_high * 0.5)
	if ridge_a.distance_to(ridge_b) > 0.05: bar(shell, ridge_a, ridge_b, ridge_wide, ridge_high, edge)
	if bool(opt.get("ridge_ends", false)):
		for end: Vector3 in [ridge_a, ridge_b]:
			var inward := (ridge_b - ridge_a).normalized() * (0.06 if end == ridge_a else -0.06)
			bar(shell, end + inward - (ridge_b - ridge_a).normalized() * 0.05 + Vector3.UP * 0.03, end + inward + (ridge_b - ridge_a).normalized() * 0.05 + Vector3.UP * 0.03, ridge_wide + 0.10, ridge_high + 0.12, edge)
	for hip: Array in hips:
		var low: Vector2 = hip[1]
		var high: Vector2 = hip[2]
		var a: Vector3 = at.call(low.x, low.y, height.call(int(hip[0]), low.x, low.y) + tile + 0.03)
		var b: Vector3 = at.call(high.x, high.y, height.call(int(hip[0]), high.x, high.y) + tile + 0.03)
		bar(shell, a, b, 0.17, 0.08, edge)
	if form == "gable" and bool(opt.get("verge", true)):
		# The verge course along each sloping edge of a gable.
		for u: float in [-g + 0.07, length + g - 0.07]:
			for side: int in [0, 1]:
				var v := -o if side == 0 else span + o
				bar(shell, at.call(u, v, height.call(side, u, v) + tile + 0.02), at.call(u, half, y + rise + tile + 0.02), 0.14, 0.05, edge)
	# The low edges.
	var eaves: Array = []
	var runs: Array = [[0, Vector2(-g if form == "gable" else -o, -o), Vector2(length + (g if form == "gable" else o), -o), Vector2(0, -1)], [1, Vector2(-g if form == "gable" else -o, span + o), Vector2(length + (g if form == "gable" else o), span + o), Vector2(0, 1)]]
	if form != "gable":
		runs.append([2, Vector2(-o, -o), Vector2(-o, span + o), Vector2(-1, 0)])
		runs.append([3, Vector2(length + o, -o), Vector2(length + o, span + o), Vector2(1, 0)])
	for run: Array in runs:
		var a2: Vector2 = run[1]
		var b2: Vector2 = run[2]
		var out2: Vector2 = run[3]
		var out: Vector3 = (at.call(out2.x, out2.y, 0.0) as Vector3) - (at.call(0.0, 0.0, 0.0) as Vector3)
		var low_y: float = height.call(int(run[0]), a2.x, a2.y)
		var wall_a := Vector2(clampf(a2.x, 0.12, length - 0.12), clampf(a2.y, 0.0, span)) if int(run[0]) < 2 else Vector2(clampf(a2.x, 0.0, length), clampf(a2.y, 0.12, span - 0.12))
		var wall_b := Vector2(clampf(b2.x, 0.12, length - 0.12), clampf(b2.y, 0.0, span)) if int(run[0]) < 2 else Vector2(clampf(b2.x, 0.0, length), clampf(b2.y, 0.12, span - 0.12))
		eaves.append([at.call(a2.x, a2.y, low_y), at.call(b2.x, b2.y, low_y), out, at.call(wall_a.x, wall_a.y, low_y), at.call(wall_b.x, wall_b.y, low_y)])
	return {"top": tile + ridge_high, "thick": tile, "rise": rise, "plates": plates, "eaves": eaves, "form": form, "ridge": "x" if along_x else "z"}


## One plane against a wall. `a` -> `b` is its low line on the plan, `inward` the way it
## climbs, `run` how far; its underside is `y_low` high on the low line. `eave` overhangs the
## low line. `ends` = [low_a, high_a, low_b, high_b]: how far the low and the high edge carry
## on past a and past b (a mitred corner: low +eave, high -the neighbour's run).
static func lean(shell: ShellMesh, a: Vector2, b: Vector2, inward: Vector2, run: float, y_low: float, pitch: float, eave: float, ends: Array, paint: Dictionary, roof_colour: Color, thick: float = TILE) -> Dictionary:
	var dir := (b - a).normalized()
	var corners: Array[Vector2] = [a - dir * float(ends[0]) - inward * eave, b + dir * float(ends[2]) - inward * eave, b + dir * float(ends[3]) + inward * run, a - dir * float(ends[1]) + inward * run]
	var under := PackedVector3Array()
	for corner: Vector2 in corners: under.append(Vector3(corner.x, y_low + pitch * (corner - a).dot(inward), corner.y))
	shell.slab(under, thick, roof_colour, paint.soffit, roof_colour.darkened(0.18))
	var out := Vector3(-inward.x, 0.0, -inward.y)
	return {"plate": under, "eave": [under[0], under[1], out, under[0], under[1]]}


## The closed end of a lean-to that stops at a wall running on: the little triangle of wall
## between the lower wall's top and the roof.
static func lean_cheek(shell: ShellMesh, at: Vector2, inward: Vector2, run: float, y_low: float, pitch: float, push: Vector2, paint: Dictionary) -> void:
	var foot := Vector3(at.x, y_low, at.y)
	var back := foot + Vector3(inward.x, 0.0, inward.y) * run
	shell.wedge(foot, back, back + Vector3.UP * pitch * run, Vector3(push.x, 0.0, push.y), paint.inner_wall, paint.gable_wall)


## A rain gutter under a low edge.
static func gutter(shell: ShellMesh, eave: Array, colour: Color) -> void:
	var out: Vector3 = eave[2]
	var shift := out * 0.055 + Vector3.UP * 0.035
	bar(shell, (eave[0] as Vector3) + shift, (eave[1] as Vector3) + shift, 0.11, 0.09, colour)


## A straight bar of rectangular section from a to b.
static func bar(shell: ShellMesh, a: Vector3, b: Vector3, width: float, height: float, colour: Color) -> void:
	var length := a.distance_to(b)
	if length < 0.001: return
	var z := (b - a) / length
	var x := Vector3.UP.cross(z)
	if x.length_squared() < 1e-6: x = Vector3.RIGHT
	x = x.normalized()
	shell.box(Transform3D(Basis(x, z.cross(x), z), (a + b) * 0.5), Vector3.ZERO, Vector3(width, height, length), colour)
