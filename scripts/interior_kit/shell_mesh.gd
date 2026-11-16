extends RefCounted
## Collects flat, vertex-coloured faces into ONE mesh, so a whole house shell (walls, floors,
## roof, stair, frames) is a single draw call with a single shared material. A door leaf uses
## the same builder and the same material.
##
## Colours are plain: no textures, no painted detail. Every face is a real surface of a box
## or a prism.

var points := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()

static var _material: StandardMaterial3D

## The corners of a unit box (centre 0, half size 1) and, for each of its six sides, the four
## that go round it, the axis it faces along and its name in a `faces` dictionary.
const _CORNERS: Array[Vector3] = [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]
const _SIDES: Array[Array] = [[1, 2, 6, 5, 0, 1.0, "+x"], [0, 4, 7, 3, 0, -1.0, "-x"], [3, 7, 6, 2, 1, 1.0, "+y"], [0, 1, 5, 4, 1, -1.0, "-y"], [4, 5, 6, 7, 2, 1.0, "+z"], [0, 3, 2, 1, 2, -1.0, "-z"]]


## The one material every kit mesh shares (so houses batch together).
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.88
	return _material


## A flat four-cornered face. The corners go round it; `outward` is the side it is seen from.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color) -> void:
	var normal := outward.normalized()
	var first := points.size()
	points.push_back(a)
	points.push_back(b)
	points.push_back(c)
	points.push_back(d)
	for i: int in 4:
		normals.push_back(normal)
		colors.push_back(color)
	# Godot draws clockwise triangles as fronts.
	if (c - a).cross(b - a).dot(normal) >= 0.0:
		indices.push_back(first)
		indices.push_back(first + 1)
		indices.push_back(first + 2)
		indices.push_back(first)
		indices.push_back(first + 2)
		indices.push_back(first + 3)
	else:
		indices.push_back(first)
		indices.push_back(first + 2)
		indices.push_back(first + 1)
		indices.push_back(first)
		indices.push_back(first + 3)
		indices.push_back(first + 2)


func triangle(a: Vector3, b: Vector3, c: Vector3, outward: Vector3, color: Color) -> void:
	var normal := outward.normalized()
	var first := points.size()
	points.push_back(a)
	points.push_back(b)
	points.push_back(c)
	for i: int in 3:
		normals.push_back(normal)
		colors.push_back(color)
	if (c - a).cross(b - a).dot(normal) >= 0.0:
		indices.push_back(first)
		indices.push_back(first + 1)
		indices.push_back(first + 2)
	else:
		indices.push_back(first)
		indices.push_back(first + 2)
		indices.push_back(first + 1)


## A box of `size` centred on `centre`, both in the space of `frame`. `faces` may give a
## different colour to one side: keys "+x" "-x" "+y" "-y" "+z" "-z" (the frame's own axes).
func box(frame: Transform3D, centre: Vector3, size: Vector3, color: Color, faces: Dictionary = {}, encode_wall_height: bool = false) -> void:
	var h := size * 0.5
	var at: Array[Vector3] = []
	at.resize(8)
	for n: int in 8: at[n] = frame * (centre + _CORNERS[n] * h)
	var plain := faces.is_empty()
	# Explicit plate metadata only. Other box output keeps the native path.
	var plate_ticks := Rect2i()
	var plate_palette := -1
	if faces.has("_nameplate"):
		var metadata: Variant = faces["_nameplate"]
		if not encode_wall_height and metadata is Dictionary and str(metadata.get("face", "")) == "-z" and metadata.get("ticks") is Rect2i:
			plate_ticks = metadata.ticks
			plate_palette = int(metadata.get("palette", -1))
			if plate_ticks.position.x < 0 or plate_ticks.position.y < 0 or plate_ticks.end.x > 255 or plate_ticks.end.y > 255 or plate_ticks.size.x <= 0 or plate_ticks.size.y <= 0 or plate_palette < 0 or plate_palette > 2:
				plate_palette = -1
		if plate_palette < 0:
			push_error("Nameplate metadata requires an unmarked -z face, valid byte-grid ticks and palette0..2")
	for side: Array in _SIDES:
		var normal: Vector3 = frame.basis[int(side[4])] * float(side[5])
		var paint: Color = color if plain else faces.get(side[6], color)
		var plate_face := plate_palette >= 0 and str(side[6]) == "-z"
		var first := points.size()
		points.push_back(at[side[0]])
		points.push_back(at[side[1]])
		points.push_back(at[side[2]])
		points.push_back(at[side[3]])
		for i: int in 4:
			normals.push_back(normal)
			var vertex_colour := paint
			if encode_wall_height:
				var height := (_CORNERS[int(side[i])].y + 1.0) * h.y
				vertex_colour.a = 0.2 + 0.3 * height
			elif plate_face:
				var corner: Vector3 = _CORNERS[int(side[i])]
				var u := plate_ticks.end.x if corner.x < 0.0 else plate_ticks.position.x
				var v := plate_ticks.position.y if corner.y > 0.0 else plate_ticks.end.y
				# Prebias preserves the intended endpoint bytes through RGBA8 truncation.
				vertex_colour = Color((float(u) + 0.5) / 255.0, (float(v) + 0.5) / 255.0, (float(plate_palette) + 0.5) / 255.0, 0.8)
			colors.push_back(vertex_colour)
		indices.push_back(first)
		indices.push_back(first + 2)
		indices.push_back(first + 1)
		indices.push_back(first)
		indices.push_back(first + 3)
		indices.push_back(first + 2)


## A flat three-cornered slab (a gable end): the triangle a, b, c pushed `depth` along
## `push`. `face` colours the front (the side `push` points away from).
func wedge(a: Vector3, b: Vector3, c: Vector3, push: Vector3, color: Color, face: Color) -> void:
	var back := [a + push, b + push, c + push]
	triangle(a, b, c, -push, face)
	triangle(back[0], back[1], back[2], push, color)
	var middle := (a + b + c) / 3.0
	var front := [a, b, c]
	for i: int in range(3):
		var j := (i + 1) % 3
		var edge_middle: Vector3 = (front[i] + front[j]) * 0.5
		quad(front[i], front[j], back[j], back[i], edge_middle - middle, color)


## A flat plate with any convex outline (a roof plane): `under` are the corners of its
## underside, going round; the top is `thickness` straight above. Its edges stand upright.
func slab(under: PackedVector3Array, thickness: float, top: Color, bottom: Color, edge: Color) -> void:
	var count := under.size()
	if count < 3: return
	var lift := Vector3.UP * thickness
	var normal := (under[1] - under[0]).cross(under[2] - under[0]).normalized()
	if normal.y < 0.0: normal = -normal
	var middle := Vector3.ZERO
	for point: Vector3 in under: middle += point
	middle /= float(count)
	for n: int in range(1, count - 1):
		if (under[n] - under[0]).cross(under[n + 1] - under[0]).length_squared() < 1e-10: continue
		triangle(under[0] + lift, under[n] + lift, under[n + 1] + lift, normal, top)
		triangle(under[0], under[n], under[n + 1], -normal, bottom)
	for n: int in count:
		var a := under[n]
		var b := under[(n + 1) % count]
		if a.distance_squared_to(b) < 1e-8: continue
		var out := (a + b) * 0.5 - middle
		out.y = 0.0
		var along := b - a
		var flat := Vector3(along.z, 0.0, -along.x)
		if flat.dot(out) < 0.0: flat = -flat
		quad(a, b, b + lift, a + lift, flat, edge)


## A wheel's tyre: a ring standing upright in `frame` (its axle along the frame's x), with
## `sides` flat faces round it.
func ring(frame: Transform3D, radius: float, band: float, width: float, sides: int, color: Color) -> void:
	var half := width * 0.5
	for n: int in sides:
		var a0 := TAU * float(n) / float(sides)
		var a1 := TAU * float(n + 1) / float(sides)
		var out0 := Vector3(0.0, cos(a0), sin(a0))
		var out1 := Vector3(0.0, cos(a1), sin(a1))
		var middle := (out0 + out1).normalized()
		quad(frame * (out0 * radius + Vector3(-half, 0, 0)), frame * (out0 * radius + Vector3(half, 0, 0)), frame * (out1 * radius + Vector3(half, 0, 0)), frame * (out1 * radius + Vector3(-half, 0, 0)), frame.basis * middle, color)
		for side: float in [-1.0, 1.0]:
			var x := Vector3(side * half, 0, 0)
			quad(frame * (out0 * radius + x), frame * (out1 * radius + x), frame * (out1 * (radius - band) + x), frame * (out0 * (radius - band) + x), frame.basis * Vector3(side, 0, 0), color)


## An upright prism with `sides` flat faces round it (a paper lantern, a bowl): its middle at
## the frame's origin, its axis the frame's y.
func drum(frame: Transform3D, radius: float, height: float, sides: int, color: Color) -> void:
	var up := Vector3(0.0, height * 0.5, 0.0)
	for n: int in sides:
		var a0 := TAU * float(n) / float(sides)
		var a1 := TAU * float(n + 1) / float(sides)
		var p0 := Vector3(cos(a0), 0.0, sin(a0)) * radius
		var p1 := Vector3(cos(a1), 0.0, sin(a1)) * radius
		quad(frame * (p0 - up), frame * (p1 - up), frame * (p1 + up), frame * (p0 + up), frame.basis * (p0 + p1), color)
		triangle(frame * up, frame * (p0 + up), frame * (p1 + up), frame.basis.y, color)
		triangle(frame * -up, frame * (p0 - up), frame * (p1 - up), -frame.basis.y, color)


## Flat shapes given as loose triangles (three corners each) in the frame's own x and y, made
## `scale` times as big and seen from the frame's +z: the letters of a sign.
func flat(frame: Transform3D, corners: PackedVector3Array, scale: float, color: Color) -> void:
	var normal := frame.basis.z.normalized()
	for n: int in range(0, corners.size() - 2, 3):
		triangle(frame * (corners[n] * scale), frame * (corners[n + 1] * scale), frame * (corners[n + 2] * scale), normal, color)


func triangle_count() -> int:
	return indices.size() / 3


func is_empty() -> bool:
	return indices.is_empty()


func commit() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	return mesh
