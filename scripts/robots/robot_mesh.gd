extends RefCounted
## Joins solids into ONE vertex-coloured mesh, so a rigid piece of a robot or a whole station
## is a single draw call. Plain solids (boxes, capsules, cylinders, balls) and three shaped
## ones: a box with rounded edges, a lofted shell (a moulded casing drawn through a row of
## cross-sections) and a tube along a path (a cable). Every face is a real surface of a solid:
## no textures and no painted detail.

var points := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()

static var _shell: StandardMaterial3D


## The one material every robot and station mesh shares: a smooth moulded shell, coloured
## per vertex (white casing, dark joints).
static func shell_material() -> StandardMaterial3D:
	if _shell == null:
		_shell = StandardMaterial3D.new()
		_shell.vertex_color_use_as_albedo = true
		_shell.vertex_color_is_srgb = true
		_shell.roughness = 0.42
		_shell.metallic_specular = 0.55
	return _shell


## Adds a ready-made solid, placed by `frame`.
func solid(mesh: PrimitiveMesh, frame: Transform3D, color: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var first := points.size()
	var turn := frame.basis.inverse().transposed()
	for index: int in range(source.size()):
		points.append(frame * source[index])
		normals.append((turn * source_normals[index]).normalized())
		colors.append(color)
	for index: int in source_indices: indices.append(first + index)


func box(centre: Vector3, size: Vector3, color: Color, turn: Basis = Basis.IDENTITY) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	solid(mesh, Transform3D(turn, centre), color)


## An upright capsule `height` tall (ends included). `squash` scales it across (x) and
## front to back (z); `turn` tilts it.
func capsule(centre: Vector3, radius: float, height: float, color: Color, squash: Vector2 = Vector2.ONE, turn: Basis = Basis.IDENTITY) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 12
	mesh.rings = 3
	solid(mesh, Transform3D(turn * Basis.from_scale(Vector3(squash.x, 1.0, squash.y)), centre), color)


func cylinder(centre: Vector3, bottom: float, top: float, height: float, color: Color, turn: Basis = Basis.IDENTITY, sides: int = 14) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	solid(mesh, Transform3D(turn, centre), color)


## A ball, stretched by `size` (its three full widths). `sides` is how finely it is cut:
## a small joint needs far fewer faces than a head.
func ball(centre: Vector3, size: Vector3, color: Color, sides: int = 10, turn: Basis = Basis.IDENTITY) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = sides
	mesh.rings = maxi(sides / 2, 3)
	solid(mesh, Transform3D(turn * Basis.from_scale(size), centre), color)


## One triangle between three points already added. It is dropped when it has no area, and
## turned to face the way its corners' normals point (Godot draws the clockwise side).
func _tri(a: int, b: int, c: int) -> void:
	var facing := (points[b] - points[a]).cross(points[c] - points[a])
	if facing.length_squared() < 1e-15: return
	indices.append(a)
	if facing.dot(normals[a] + normals[b] + normals[c]) > 0.0:
		indices.append(c)
		indices.append(b)
	else:
		indices.append(b)
		indices.append(c)


## A box whose edges and corners are rounded off by `radius`: a cast or moulded block, not
## a folded sheet. `cut` is how many faces go round each edge (1 = a plain bevel).
func rounded_box(centre: Vector3, size: Vector3, radius: float, color: Color, turn: Basis = Basis.IDENTITY, cut: int = 1) -> void:
	var half := size * 0.5
	var r := minf(radius, minf(half.x, minf(half.y, half.z)))
	var inner := half - Vector3(r, r, r)
	var first := points.size()
	var columns := 4 * (cut + 1)
	var rings := 2 * (cut + 1)
	var sign_x := [1.0, -1.0, -1.0, 1.0]
	var sign_z := [1.0, 1.0, -1.0, -1.0]
	for ring: int in rings:
		var upper := ring <= cut
		var phi := (float(ring) if upper else float(ring - 1)) / float(cut) * PI * 0.5
		for column: int in columns:
			var quarter := column / (cut + 1)
			var theta := (float(quarter) + float(column % (cut + 1)) / float(cut)) * PI * 0.5
			var way := Vector3(cos(theta) * sin(phi), cos(phi), sin(theta) * sin(phi))
			var corner := Vector3(float(sign_x[quarter]) * inner.x, inner.y if upper else -inner.y, float(sign_z[quarter]) * inner.z)
			points.append(centre + turn * (corner + way * r))
			normals.append((turn * way).normalized())
			colors.append(color)
	for ring: int in rings - 1:
		for column: int in columns:
			var a := first + ring * columns + column
			var b := first + ring * columns + (column + 1) % columns
			var c := a + columns
			var d := b + columns
			_tri(a, b, c)
			_tri(b, d, c)
	# The flat top and bottom, between the four corners of the first and last ring.
	for ring: int in [0, rings - 1]:
		var at := first + ring * columns
		_tri(at, at + (cut + 1), at + 2 * (cut + 1))
		_tri(at, at + 2 * (cut + 1), at + 3 * (cut + 1))


## A moulded shell drawn through a row of cross-sections along its own y. Each section is
## [y, half width (x), half depth (z), z of its middle (0), squareness (2)]: squareness 2 is
## an ellipse, higher is a rounded rectangle. Both ends are closed flat, so a shell whose
## last sections step in a little shows a bevelled edge with real thickness. `frame` places
## and turns it.
func loft(sections: Array, color: Color, frame: Transform3D = Transform3D.IDENTITY, sides: int = 12) -> void:
	var rings := sections.size()
	if rings < 2: return
	var grid := PackedVector3Array()
	var middles := PackedVector3Array()
	for section: Array in sections:
		var y := float(section[0])
		var rx := float(section[1])
		var rz := float(section[2])
		var cz := float(section[3]) if section.size() > 3 else 0.0
		var power := 2.0 / (float(section[4]) if section.size() > 4 else 2.0)
		for side: int in sides:
			var angle := TAU * float(side) / float(sides)
			var c := cos(angle)
			var s := sin(angle)
			grid.append(Vector3(rx * signf(c) * pow(absf(c), power), y, cz + rz * signf(s) * pow(absf(s), power)))
		middles.append(Vector3(0.0, y, cz))
	var upward := 1.0 if float(sections[rings - 1][0]) >= float(sections[0][0]) else -1.0
	var turn := frame.basis.inverse().transposed()
	var first := points.size()
	for ring: int in rings:
		for side: int in sides:
			var here := grid[ring * sides + side]
			var around := grid[ring * sides + (side + 1) % sides] - grid[ring * sides + (side + sides - 1) % sides]
			var along := grid[mini(ring + 1, rings - 1) * sides + side] - grid[maxi(ring - 1, 0) * sides + side]
			var normal := along.cross(around) * upward
			if normal.length_squared() < 1e-18: normal = here - middles[ring]
			if normal.length_squared() < 1e-18: normal = Vector3.UP
			points.append(frame * here)
			normals.append((turn * normal).normalized())
			colors.append(color)
	for ring: int in rings - 1:
		for side: int in sides:
			var a := first + ring * sides + side
			var b := first + ring * sides + (side + 1) % sides
			var c := a + sides
			var d := b + sides
			_tri(a, b, c)
			_tri(b, d, c)
	# The two flat ends.
	for end: int in [0, rings - 1]:
		var out := (turn * Vector3(0.0, -upward if end == 0 else upward, 0.0)).normalized()
		var centre := points.size()
		points.append(frame * middles[end])
		normals.append(out)
		colors.append(color)
		for side: int in sides:
			points.append(frame * grid[end * sides + side])
			normals.append(out)
			colors.append(color)
		for side: int in sides:
			_tri(centre, centre + 1 + side, centre + 1 + (side + 1) % sides)


## A round tube through `path`: a cable or a pipe. Its ends are left open; they are meant to
## run into whatever the cable plugs into.
func tube(path: PackedVector3Array, radius: float, color: Color, sides: int = 6) -> void:
	if path.size() < 2: return
	var first := points.size()
	var across := Vector3.ZERO
	for index: int in path.size():
		var ahead := (path[mini(index + 1, path.size() - 1)] - path[maxi(index - 1, 0)]).normalized()
		if index == 0:
			across = ahead.cross(Vector3.UP)
			if across.length_squared() < 0.0001: across = ahead.cross(Vector3.RIGHT)
		across = (across - ahead * across.dot(ahead)).normalized()
		var other := ahead.cross(across)
		for side: int in sides:
			var angle := TAU * float(side) / float(sides)
			var way := across * cos(angle) + other * sin(angle)
			points.append(path[index] + way * radius)
			normals.append(way)
			colors.append(color)
	for index: int in path.size() - 1:
		for side: int in sides:
			var a := first + index * sides + side
			var b := first + index * sides + (side + 1) % sides
			var c := a + sides
			var d := b + sides
			_tri(a, b, c)
			_tri(b, d, c)


func triangle_count() -> int:
	return indices.size() / 3


func _arrays() -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


func commit(material: Material = null) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays())
	mesh.surface_set_material(0, material if material != null else shell_material())
	return mesh


## Adds what was joined here to `mesh` as one more surface (one more draw call), for the
## few faces that need a material of their own: a light.
func commit_onto(mesh: ArrayMesh, material: Material) -> void:
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays())
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
