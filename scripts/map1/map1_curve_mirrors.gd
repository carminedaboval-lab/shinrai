extends Node3D

const Street := preload("res://scripts/map1/map1_street.gd")
## Curve mirrors (ã‚«ãƒ¼ãƒ–ãƒŸãƒ©ãƒ¼) at blind lane corners (agreed with Codex, 2026-11-14): the
## orange-poled round road mirror a Japanese town puts where a lane comes out onto a street
## between buildings, so a driver can see along the street before pulling out.
##
## Where: at every lane mouth on a built street, each of its two corners is blind when a
## building's footprint comes within BLIND of the corner where the street's footway back and the
## lane's meet, inside that corner. A mouth with a blind corner gets one mirror per hidden arm of
## the street. It stands across the street, on the far footway, facing back into the lane and
## aimed between the lane and the arm it shows: at the lane's middle where the far side has a
## footway there (a T), or at the far side's corner on the hidden arm's side (a crossroads).
## Never where the far footway is too narrow to leave a walking route behind the pole, nor within
## CLEAR of a lowered kerb, a gate, the utility pole or anything small standing on the footway.
##
## The mirror face is a bright metal surface lit by the sky, not a live view: a live reflection
## of what is round the corner would be a gameplay feature, and is the owner's call.

const BLIND := 2.5             # a building this near the corner, inside it, hides the street
const BEHIND_KERB := 0.4       # the pole's middle, behind the kerb's road face
const WALK := 0.9              # the walking route left behind the pole
const CLEAR := 1.2             # from a lowered kerb, a gate, a pole, a bench
const INTO_RUN := 3.6          # at a crossroads, along the far side's straight footway past its corner
const POLE_HIGH := 2.95
const POLE_R0 := 0.045         # at the foot
const POLE_R1 := 0.038         # at the top
const HEAD_AT := 2.55          # the mirror's middle above the footway
const HEAD_R := 0.30           # a 600 mm mirror
const TILT := 5.0              # degrees, face turned down towards the road
const ARM := 0.16              # from the pole's middle to the mirror's back
const ORANGE := Color(0.93, 0.42, 0.10)
const BACK := Color(0.20, 0.20, 0.21)

## Each mirror: {"at": Vector3 (the pole's foot), "heads": [Vector3 aim, ...], "street": name,
## "lane": crossing, "why": "T" or "crossroads"}.
var sites: Array = []
## Mouths with a blind corner where no mirror could stand, and why.
var skipped: Array = []


static func install(map: Node3D) -> Node3D:
	var made := new()
	made.name = "CurveMirrors"
	map.add_child(made)
	made._find(map)
	made._build(map)
	return made


func _find(map: Node3D) -> void:
	for street: Node3D in map.street_edges:
		if street.is_round: continue
		var edge: Dictionary = street.get_meta("edge")
		var far: Node3D = null
		for other: Node3D in map.street_edges:
			if other != street and other.get_meta("edge") == edge and is_equal_approx(float(other.side), -float(street.side)): far = other
		if far == null: continue
		for crossing: Dictionary in edge.get("crossings", []):
			var mine: Dictionary = {}
			var theirs: Dictionary = {}
			for entry: Dictionary in crossing.sides:
				if is_equal_approx(float(entry.side), float(street.side)): mine = entry
				elif is_equal_approx(float(entry.side), float(far.side)): theirs = entry
			if mine.is_empty(): continue
			var from := float(mine.from)
			var to := float(mine.to)
			for arm: Array in [[from, -1.0], [to, 1.0]]:
				var corner: Vector3 = street.at(float(arm[0]), float(street.half) + float(street.footway_wide))
				var blocker := _blocker(map, street, corner, float(arm[1]))
				if blocker < 0: continue
				_place(map, street, far, crossing, from, to, theirs, float(arm[1]), blocker)


## The building (its index in the map's boxes) inside the corner at `corner`, within BLIND of it,
## or -1. `away` is the way along the street from the mouth to the plot side of that corner.
func _blocker(map: Node3D, street: Node3D, corner: Vector3, away: float) -> int:
	var ahead: Vector3 = (street.at(1.0, 0.0) - street.at(0.0, 0.0)).normalized()
	var out: Vector3 = (street.at(0.0, 1.0) - street.at(0.0, 0.0)).normalized()
	var best := -1
	var nearest := BLIND
	for index: int in map.data.boxes.size():
		var box: Array = map.data.boxes[index]
		if float(box[3]) < 3.0 or float(box[5]) < 3.0: continue      # a post, a signal: not a building
		if absf(float(box[0]) - corner.x) > 20.0 or absf(float(box[2]) - corner.z) > 20.0: continue
		var points := _footprint(box)
		for k: int in 4:
			var near := Geometry2D.get_closest_point_to_segment(Vector2(corner.x, corner.z), points[k], points[(k + 1) % 4])
			var rel := Vector3(near.x - corner.x, 0.0, near.y - corner.z)
			if rel.dot(out) < -0.05 or rel.dot(ahead) * away < -0.05: continue      # not inside the corner
			var gap := rel.length()
			if gap <= nearest:
				nearest = gap
				best = index
	return best


static func _footprint(box: Array) -> PackedVector2Array:
	var turn := deg_to_rad(float(box[6]))
	var c := cos(turn)
	var s := sin(turn)
	var points: PackedVector2Array = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var lx := corner.x * float(box[3]) * 0.5
		var lz := corner.y * float(box[5]) * 0.5
		points.append(Vector2(float(box[0]) + lx * c + lz * s, float(box[2]) - lx * s + lz * c))
	return points


func _place(map: Node3D, street: Node3D, far: Node3D, crossing: Dictionary, from: float, to: float, theirs: Dictionary, away: float, blocker: int) -> void:
	var middle := (from + to) * 0.5
	var s := middle
	var why := "T"
	if not _on_footway(far, s):
		# A crossroads: the far side is the lane's own carrying on. The far side's corner on the
		# hidden arm's side, a little back from where its curve begins.
		why = "crossroads"
		# (Where that side's straight footway starts again past its corner curve: INTO_RUN in, so
		# the line people walk round the corner, half a metre behind the kerb, stays open.)
		var best := INF
		for run: Vector2 in far.runs:
			if run.y - run.x < INTO_RUN + 0.6: continue
			var end := run.y - INTO_RUN if away < 0.0 else run.x + INTO_RUN
			var edge_s := float(theirs.from) if away < 0.0 and not theirs.is_empty() else float(theirs.to) if not theirs.is_empty() else middle
			var past := (edge_s - end) if away < 0.0 else (end - edge_s)
			if past >= 0.0 and past < INTO_RUN + 6.0 and past < best:
				best = past
				s = end
	s = _off_shop_front(map, far, s)
	var label := "%s at %s, %s arm" % [str(street.get_meta("edge").name), str(crossing.get("with", "?")), "back" if away < 0.0 else "on"]
	if not _on_footway(far, s):
		skipped.append("%s: no far footway there" % label)
		return
	if float(far.footway_wide) < BEHIND_KERB + POLE_R0 + WALK:
		skipped.append("%s: far footway %.2f m, no walking route behind a pole" % [label, float(far.footway_wide)])
		return
	var foot: Vector3 = far.at(s, float(far.half) + BEHIND_KERB)
	foot.y = float(far.top(s))      # (on the footway's top)
	var problem := _crowded(map, far, s, foot)
	if problem != "":
		skipped.append("%s: %s" % [label, problem])
		return
	# The face: between the way back into the lane and the way along the hidden arm.
	var lane_mouth: Vector3 = street.at(middle, float(street.half))
	var to_lane := Vector3(lane_mouth.x - foot.x, 0.0, lane_mouth.z - foot.z).normalized()
	var along: Vector3 = street.at(middle + away * 10.0, 0.0) - street.at(middle, 0.0)
	var arm := Vector3(along.x, 0.0, along.z).normalized()
	var aim := (to_lane + arm).normalized()
	# One pole carries both heads where both arms are hidden from one place.
	for site: Dictionary in sites:
		if (site.at as Vector3).distance_to(foot) < 0.05:
			(site.heads as Array).append(aim)
			return
	sites.append({"at": foot, "heads": [aim], "street": str(street.get_meta("edge").name), "lane": str(crossing.get("with", "?")), "why": why, "blocker": blocker, "far_side": float(far.side), "s": s})


## A pole does not stand in front of a shop's door or window: where `s` on `street` lies along the
## front of one of the map's businesses that stands at the footway, it moves to the nearer end of
## that front (the wall between it and its neighbour), if that is within SHIFT and still on the
## footway. Otherwise it stays.
const SHIFT := 5.0
func _off_shop_front(map: Node3D, street: Node3D, s: float) -> float:
	for business: Dictionary in map.data.get("businesses", []):
		var box: Array = map.data.boxes[int(business.box)]
		if absf(float(box[0]) - float(street.at(s, 0.0).x)) > 30.0 or absf(float(box[2]) - float(street.at(s, 0.0).z)) > 30.0: continue
		var low := INF
		var high := -INF
		var near := INF
		for point: Vector2 in _footprint(box):
			var spot := Vector3(point.x, 0.0, point.y)
			var along := float(street.along_of(spot))
			low = minf(low, along)
			high = maxf(high, along)
			near = minf(near, float(street.out_of(spot)))
		# (On this side, its front within 2.5 m of the footway's back, and the pole along its front.)
		if near < float(street.half) or near > float(street.half) + float(street.footway_wide) + 2.5: continue
		if s <= low or s >= high: continue
		var ends: Array[float] = [low - 0.3, high + 0.3]
		ends.sort_custom(func(a: float, b: float) -> bool: return absf(a - s) < absf(b - s))
		for end: float in ends:
			if absf(end - s) <= SHIFT and _on_footway(street, end): return end
	return s


func _on_footway(street: Node3D, s: float) -> bool:
	for run: Vector2 in street.runs:
		if s >= run.x + 0.3 and s <= run.y - 0.3: return true
	return false


## What stands too near a pole at `foot` on `street` at `s`, or "".
func _crowded(map: Node3D, street: Node3D, s: float, foot: Vector3) -> String:
	var ramp := float(Street.RAMP_UNITS) * Street.UNIT
	for drop: Vector2 in street.drops:
		if s > drop.x - ramp - CLEAR and s < drop.y + ramp + CLEAR: return "a lowered kerb at %.1f to %.1f m" % [drop.x, drop.y]
	if float(street.pole_at) >= 0.0 and absf(float(street.pole_at) - s) < CLEAR: return "the utility pole"
	# (A gate's way in crosses the footway in front of it: kept clear along the street.)
	for gate: Vector3 in map._gates_near(street.get_meta("edge")):
		var out := float(street.out_of(gate))
		if out < float(street.half) or out > float(street.half) + float(street.footway_wide) + 6.0: continue
		if absf(float(street.along_of(gate)) - s) < CLEAR + 0.9: return "the way in to a gate"
	for box: Array in map.data.boxes:
		if float(box[3]) >= 3.0 and float(box[5]) >= 3.0: continue
		if Vector2(float(box[0]) - foot.x, float(box[2]) - foot.z).length() < CLEAR + maxf(float(box[3]), float(box[5])) * 0.5: return "a %s" % str(map.data.kinds[int(box[7])])
	for site: Dictionary in sites:
		var other: Vector3 = site.at
		if other.distance_to(foot) > 0.05 and other.distance_to(foot) < CLEAR * 3.0: return "another mirror"
	return ""


func _build(map: Node3D) -> void:
	if sites.is_empty(): return
	var paint := SurfaceTool.new()
	paint.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	body.name = "CurveMirrorBody"
	for site: Dictionary in sites:
		var foot: Vector3 = site.at
		var root := foot
		_cylinder(paint, root, POLE_R0, POLE_R1, POLE_HIGH, 10, ORANGE)
		_cap(paint, root + Vector3.UP * POLE_HIGH, POLE_R1, 10, ORANGE)
		var shape := CollisionShape3D.new()
		var post := CylinderShape3D.new()
		post.radius = POLE_R0
		post.height = POLE_HIGH
		shape.shape = post
		shape.position = root + Vector3.UP * POLE_HIGH * 0.5
		body.add_child(shape)
		var heads: Array = site.heads
		for k: int in heads.size():
			var aim: Vector3 = heads[k]
			var centre := root + Vector3.UP * (HEAD_AT + 0.05 * float(k)) + aim * ARM
			_head(paint, glass, centre, aim, root + Vector3.UP * (HEAD_AT + 0.05 * float(k)))
	var mesh := ArrayMesh.new()
	paint.generate_normals()
	paint.commit(mesh)
	var painted := StandardMaterial3D.new()
	painted.vertex_color_use_as_albedo = true
	painted.vertex_color_is_srgb = true
	painted.roughness = 0.55
	mesh.surface_set_material(0, painted)
	glass.generate_normals()
	glass.commit(mesh)
	var mirror := StandardMaterial3D.new()
	mirror.albedo_color = Color(0.82, 0.84, 0.86)
	mirror.metallic = 1.0
	mirror.roughness = 0.06
	mesh.surface_set_material(1, mirror)
	var instance := MeshInstance3D.new()
	instance.name = "CurveMirrorMesh"
	instance.mesh = mesh
	add_child(instance)
	add_child(body)


## One head: an orange rim and back round a slightly domed mirror, a hood over its top, and a
## short bracket back to the pole, its face towards `aim` and turned down by TILT.
func _head(paint: SurfaceTool, glass: SurfaceTool, centre: Vector3, aim: Vector3, on_pole: Vector3) -> void:
	var face := aim.rotated(aim.cross(Vector3.UP).normalized(), -deg_to_rad(TILT)).normalized()
	var right := Vector3.UP.cross(face).normalized()
	var up := face.cross(right).normalized()
	var pieces := 24
	var rim := HEAD_R + 0.025
	var depth := 0.07
	for i: int in pieces:
		var a0 := TAU * float(i) / float(pieces)
		var a1 := TAU * float(i + 1) / float(pieces)
		var r0 := right * cos(a0) + up * sin(a0)
		var r1 := right * cos(a1) + up * sin(a1)
		# The mirror: a shallow dome, its edge at the rim's inner lip.
		var dome := centre + face * 0.03
		_tri(glass, dome, centre + r1 * HEAD_R, centre + r0 * HEAD_R, face)
		# The rim's front ring, its side, and the back.
		_quad(paint, centre + r0 * HEAD_R, centre + r1 * HEAD_R, centre + r1 * rim, centre + r0 * rim, face, ORANGE)
		_quad(paint, centre + r0 * rim, centre + r1 * rim, centre + r1 * rim - face * depth, centre + r0 * rim - face * depth, r0, ORANGE)
		_tri_c(paint, centre - face * depth, centre + r0 * rim - face * depth, centre + r1 * rim - face * depth, -face, BACK)
		# The hood over the top third.
		if sin(a0) > 0.45 and sin(a1) > 0.45:
			var h0 := centre + r0 * (rim + 0.01)
			var h1 := centre + r1 * (rim + 0.01)
			_quad(paint, h0, h1, h1 + face * 0.12, h0 + face * 0.12, r0, ORANGE)
	# The bracket from the head's back to the pole.
	var back := centre - face * depth
	_box(paint, (back + on_pole) * 0.5, back.distance_to(on_pole) + 0.04, 0.05, 0.05, face, ORANGE)


func _cylinder(tool: SurfaceTool, base: Vector3, r0: float, r1: float, high: float, sides: int, colour: Color) -> void:
	for i: int in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		_quad(tool, base + d0 * r0, base + d1 * r0, base + d1 * r1 + Vector3.UP * high, base + d0 * r1 + Vector3.UP * high, (d0 + d1).normalized(), colour)


func _cap(tool: SurfaceTool, top: Vector3, r: float, sides: int, colour: Color) -> void:
	for i: int in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		_tri_c(tool, top, top + Vector3(cos(a0), 0.0, sin(a0)) * r, top + Vector3(cos(a1), 0.0, sin(a1)) * r, Vector3.UP, colour)


func _box(tool: SurfaceTool, middle: Vector3, long: float, wide: float, high: float, along: Vector3, colour: Color) -> void:
	var x := along.normalized() * long * 0.5
	var z := Vector3.UP.cross(along).normalized() * wide * 0.5
	var y := Vector3.UP * high * 0.5
	for f: Array in [[x, y, z], [-x, y, -z], [z, y, -x], [-z, y, x], [y, z, x], [-y, z, -x]]:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		_quad(tool, middle + n - u - v, middle + n - u + v, middle + n + u + v, middle + n + u - v, n, colour)


## A quad turned to face `toward`.
func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, colour: Color) -> void:
	_tri_c(tool, a, b, c, toward, colour)
	_tri_c(tool, a, c, d, toward, colour)


func _tri_c(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, toward: Vector3, colour: Color) -> void:
	tool.set_color(colour)
	_tri(tool, a, b, c, toward)


## Godot's front faces wind clockwise seen from the front.
func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, toward: Vector3) -> void:
	tool.add_vertex(a)
	if (b - a).cross(c - a).dot(toward) > 0.0:
		tool.add_vertex(c)
		tool.add_vertex(b)
	else:
		tool.add_vertex(b)
		tool.add_vertex(c)
