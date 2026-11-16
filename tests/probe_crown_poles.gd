extends SceneTree
## Staging check for a crown that does not submit its zero-area pole triangles:
##   godot --headless --path . --script res://tests/probe_crown_poles.gd
##
## The crown is built as a ring-and-segment grid. At the top ring every quad's two upper
## corners are the same point, and at the bottom ring its two lower corners are, so one of each
## quad's two triangles there has no area at all: 16 of the 80 submitted triangles draw nothing.
## Dropping them takes a tree from 110 triangles to 94 — about 156,000 across the map's 9,776 —
## and changes no pixel, because a triangle with no area covers none.
##
## **This is a staging check, not the change.** `map1_blockout.gd` is held for Codex's pavement
## comparison, so the candidate builder below is a copy of the real one with two `continue`s
## added, and this compares the two. When the hold lifts, the two lines move into the real
## builder and this copy must be deleted rather than left to drift — it has no way of knowing
## if the original changes under it, which is the whole weakness of a staged duplicate.
##
## What is proved here is what Codex asked for: every triangle with area survives with its
## positions in the same order (so the same winding) and the same normals. A pole triangle
## contributes nothing to a face normal, but `generate_normals()` averages per vertex, so
## whether dropping them disturbs their neighbours' smoothing is a real question and not an
## assumption — it is measured below.
## Prints POLE_ lines and POLE_DONE passed=N failed=M.

const Blockout := preload("res://scripts/map1/map1_blockout.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("POLE_%s %s" % ["PASS" if ok else "FAIL", text])


## The proposed crown: the real builder with the two pole triangles left unsubmitted. Kept
## character for character otherwise, so a difference in the comparison means the skips and
## nothing else.
static func _candidate_crown() -> ArrayMesh:
	var radial := 8
	var rings := 5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var point := func(ring: int, seg: int) -> Vector3:
		var phi: float = PI * float(ring) / float(rings)
		var theta: float = TAU * float(seg % radial) / float(radial)
		var belly: float = 1.0 + 0.18 * Blockout._tree_wobble(ring, 11)
		var out: float = sin(phi) * 2.5 * belly * (1.0 + 0.16 * Blockout._tree_wobble(ring, seg % radial))
		var up: float = cos(phi) * 2.1
		if phi > PI * 0.55: up -= 0.35 * sin(phi)
		return Vector3(cos(theta) * out, up, sin(theta) * out)
	for ring: int in rings:
		for seg: int in radial:
			var a: Vector3 = point.call(ring, seg)
			var b: Vector3 = point.call(ring + 1, seg)
			var c: Vector3 = point.call(ring + 1, seg + 1)
			var d: Vector3 = point.call(ring, seg + 1)
			# At the TOP ring (phi 0) a and d are the same point, so `[a, c, d]` is the flat one
			# and `[a, b, c]` is real; at the BOTTOM ring b and c are the same point, so it is
			# the other way about. Written the other way round first, this skipped the two good
			# triangles and kept the two flat ones — the check below is what said so.
			if ring < rings - 1:
				for v: Vector3 in [a, b, c]: tool.add_vertex(v)
			if ring > 0:
				for v: Vector3 in [a, c, d]: tool.add_vertex(v)
	tool.generate_normals()
	return tool.commit()


## Every face of a mesh as [v0, v1, v2, n0, n1, n2], in submitted order, with its area.
func _faces_of(mesh: ArrayMesh) -> Array:
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var index: Variant = arrays[Mesh.ARRAY_INDEX]
	var total: int = (index as PackedInt32Array).size() if index != null else points.size()
	var out: Array = []
	for n: int in range(0, total, 3):
		var i0: int = index[n] if index != null else n
		var i1: int = index[n + 1] if index != null else n + 1
		var i2: int = index[n + 2] if index != null else n + 2
		var area: float = (points[i1] - points[i0]).cross(points[i2] - points[i0]).length() * 0.5
		out.append([points[i0], points[i1], points[i2], normals[i0], normals[i1], normals[i2], area])
	return out


## A face as a string, cut fine enough to compare but not so fine that float noise separates
## two identical ones. Order is kept, so this distinguishes a winding from its mirror.
func _key(face: Array) -> String:
	var parts := PackedStringArray()
	for n: int in 6: parts.append("%.5f,%.5f,%.5f" % [(face[n] as Vector3).x, (face[n] as Vector3).y, (face[n] as Vector3).z])
	return "|".join(parts)


func _run() -> void:
	var now: Array = _faces_of(Blockout._tree_crown_mesh())
	var proposed: Array = _faces_of(_candidate_crown())
	var flat: Array = []
	var solid: Array = []
	for face: Array in now:
		if float(face[6]) < 1e-9: flat.append(face)
		else: solid.append(face)
	_check(flat.size() == 16, "the crown as built submits %d triangles, %d of them with no area at all" % [now.size(), flat.size()])
	_check(proposed.size() == now.size() - flat.size(), "the candidate submits %d, which is %d fewer" % [proposed.size(), now.size() - proposed.size()])
	var none_flat := 0
	for face: Array in proposed:
		if float(face[6]) < 1e-9: none_flat += 1
	_check(none_flat == 0, "and none of the candidate's own triangles has zero area: %d" % none_flat)
	# The real question: is every surviving triangle untouched, normals included?
	var mine := {}
	for face: Array in proposed: mine[_key(face)] = true
	var lost: Array = []
	for face: Array in solid:
		if not mine.has(_key(face)): lost.append(face)
	_check(lost.is_empty(), "every triangle with area survives with the same corners in the same order and the same normals: %d of %d changed" % [lost.size(), solid.size()])
	if not lost.is_empty():
		# Positions alone, to separate "the shape moved" from "only the smoothing moved".
		var places := {}
		for face: Array in proposed:
			places["%.5f,%.5f,%.5f|%.5f,%.5f,%.5f|%.5f,%.5f,%.5f" % [
				(face[0] as Vector3).x, (face[0] as Vector3).y, (face[0] as Vector3).z,
				(face[1] as Vector3).x, (face[1] as Vector3).y, (face[1] as Vector3).z,
				(face[2] as Vector3).x, (face[2] as Vector3).y, (face[2] as Vector3).z]] = true
		var moved := 0
		for face: Array in lost:
			if not places.has("%.5f,%.5f,%.5f|%.5f,%.5f,%.5f|%.5f,%.5f,%.5f" % [
				(face[0] as Vector3).x, (face[0] as Vector3).y, (face[0] as Vector3).z,
				(face[1] as Vector3).x, (face[1] as Vector3).y, (face[1] as Vector3).z,
				(face[2] as Vector3).x, (face[2] as Vector3).y, (face[2] as Vector3).z]): moved += 1
		print("POLE_INFO of the %d that changed, %d moved and %d kept their corners but changed normals" % [lost.size(), moved, lost.size() - moved])
		# How far the normals actually turned. Float noise and a visible change in shading are
		# both "different", and only one of them matters — so this is in degrees, not a verdict.
		var by_place := {}
		for face: Array in proposed:
			by_place["%.5f,%.5f,%.5f|%.5f,%.5f,%.5f|%.5f,%.5f,%.5f" % [
				(face[0] as Vector3).x, (face[0] as Vector3).y, (face[0] as Vector3).z,
				(face[1] as Vector3).x, (face[1] as Vector3).y, (face[1] as Vector3).z,
				(face[2] as Vector3).x, (face[2] as Vector3).y, (face[2] as Vector3).z]] = face
		var worst := 0.0
		for face: Array in lost:
			var same: Variant = by_place.get("%.5f,%.5f,%.5f|%.5f,%.5f,%.5f|%.5f,%.5f,%.5f" % [
				(face[0] as Vector3).x, (face[0] as Vector3).y, (face[0] as Vector3).z,
				(face[1] as Vector3).x, (face[1] as Vector3).y, (face[1] as Vector3).z,
				(face[2] as Vector3).x, (face[2] as Vector3).y, (face[2] as Vector3).z])
			if same == null: continue
			for n: int in range(3, 6):
				var was: Vector3 = face[n]
				var now_n: Vector3 = (same as Array)[n]
				if was.length() < 1e-9 or now_n.length() < 1e-9: continue
				worst = maxf(worst, rad_to_deg(was.normalized().angle_to(now_n.normalized())))
		print("POLE_INFO the worst a surviving normal turns is %.3f degrees" % worst)
	print("POLE_INFO a tree would go from %d triangles to %d; across 9,776 trees, %d fewer" % [
		now.size() + 30, proposed.size() + 30, (now.size() - proposed.size()) * 9776])
	print("POLE_DONE passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)
