extends RefCounted
## Real stone pavers for the corporate district and connector walks, matching
## the main street: 0.6 x 0.8 m stones in running bond, 10 mm joints, five
## stone shades and the same paving shader. The walks were flat slabs carrying
## a texture, which read as paint. Stones sit on the slabs as visual geometry
## only, so collision, routes and navigation are unchanged.
## Each chunk is one mesh and one draw call: the shade is a vertex colour, and
## a few chunk meshes are reused along the runs. Junctions are also resurfaced,
## because the sidewalk slabs run straight across the roads there.
const Paving = preload("res://scripts/midori_paving_readability.gdshader")
const STONE := Vector2(.6, .8)
const JOINT := .010
const LIFT := .015        # stone top above the slab top
const BED_BELOW := .012   # dark joint bed under the stone top
const CHUNK := 24.0       # 40 stones long
const VARIANTS := 3
const DRAW_RANGE := 170.0
const SHADES: Array[Color] = [Color("#b7b2a4"), Color("#b9b2a1"), Color("#aeaca1"), Color("#bbb6a9"), Color("#b3b1a6")]
const LUMINANCE: Array[float] = [.97, 1.025, .955, 1.04, .985]
const BED := Color("#2b2a26")

static func build(corporate: Node3D, street: Node3D, parcel: Node3D, district: Node3D) -> Dictionary:
	var totals := {"chunks":0, "unique_meshes":0, "stones":0, "junction_patches":0}
	var material := _material(street)
	if material == null: return totals
	var cache := {}
	var local := Node3D.new()
	local.name = "CorporateWalkPaving"
	local.set_meta("creator_protected", true)
	parcel.add_child(local)
	for run: Array in _district_runs():
		_lay(local, run[0], run[1], material, cache, totals)
	var world := Node3D.new()
	world.name = "ConnectorWalkPaving"
	world.set_meta("creator_protected", true)
	corporate.add_child(world)
	for run: Array in _connector_runs():
		_lay(world, run[0], run[1], material, cache, totals)
	_resurface_junctions(local, district.get("asphalt") as Material, totals)
	return totals

## [Rect2 in x/z, slab top]. Corner squares belong to the north-south walks, so
## the avenue runs stop short of them, and no run crosses a road.
static func _district_runs() -> Array:
	var runs: Array = []
	for xr: float in [-51.5, 51.5]:
		for side: float in [-1.0, 1.0]:
			var x0: float = minf(xr + side * 6.1, xr + side * 9.9)
			for span: Vector2 in [Vector2(-124, -56.1), Vector2(-43.9, 48.9), Vector2(61.1, 124)]:
				runs.append([Rect2(x0, span.x, 3.8, span.y - span.x), 0.0])
	for za: float in [-50.0, 55.0]:
		for side: float in [-1.0, 1.0]:
			var z0: float = minf(za + side * 6.1, za + side * 9.9)
			for span: Vector2 in [Vector2(-148, -61.4), Vector2(-41.6, 41.6), Vector2(61.4, 148)]:
				runs.append([Rect2(span.x, z0, span.y - span.x, 3.8), 0.0])
	# The pedestrian spine between the three sites, stopping at the walks it joins.
	for span: Vector2 in [Vector2(-113, -61.4), Vector2(-41.6, 41.6), Vector2(61.4, 114)]:
		runs.append([Rect2(span.x, 30, span.y - span.x, 8), 0.0])
	for path_z: float in [92.0, -89.5]:
		runs.append([Rect2(-35, path_z - 2.0, 70, 4), .025])
	return runs

## World metres. Road-side edges stop at the curb back from the street edge pass.
static func _connector_runs() -> Array:
	return [
		[Rect2(32.5, 180.5, 6, 2.5), .09],
		[Rect2(38.5, 180.5, 2, 1.5), .09],
		[Rect2(40.5, 180.5, 109.5, 2.36), .09],
		[Rect2(150, 180.5, 27, 2.5), .09],
		[Rect2(174.5, 183, 2.5, 21), .09],
		[Rect2(158.5, 197.5, 4, 6.5), .09],
		[Rect2(38.5, 191, 2, 1.5), .09],
		[Rect2(40.5, 190.14, 109.5, 2.36), .09],
	]

static func _material(street: Node3D) -> ShaderMaterial:
	if street == null: return null
	var mats: Dictionary = street.get("materials")
	var source := mats.get("land_slab_0") as ShaderMaterial
	if source == null: return null
	var material := source.duplicate() as ShaderMaterial
	material.resource_name = "CorporateWalkStone"
	material.shader = Paving
	material.set_shader_parameter("mineral_color", Color.WHITE)
	material.set_shader_parameter("stone_luminance", 1.0)
	material.set_shader_parameter("stone_weather", 1.0)
	return material

static func _lay(parent: Node3D, rect: Rect2, top: float, material: Material, cache: Dictionary, totals: Dictionary) -> void:
	var along_x := rect.size.x >= rect.size.y
	var length: float = rect.size.x if along_x else rect.size.y
	var width: float = rect.size.y if along_x else rect.size.x
	var start := 0.0
	var index := 0
	while start < length - .01:
		var span := minf(CHUNK, length - start)
		# Absorb a short remainder, so no thin chunk appears at the end of a run.
		if length - start - span < 1.2: span = length - start
		var chunk := MeshInstance3D.new()
		chunk.name = "WalkStones"
		chunk.mesh = _chunk(span, width, index % VARIANTS, cache, totals)
		chunk.material_override = material
		chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk.visibility_range_end = DRAW_RANGE
		var middle := start + span * .5
		if along_x:
			chunk.position = Vector3(rect.position.x + middle, top + LIFT, rect.get_center().y)
		else:
			chunk.position = Vector3(rect.get_center().x, top + LIFT, rect.position.y + middle)
			chunk.rotation.y = PI * .5
		parent.add_child(chunk)
		totals.chunks += 1
		start += span
		index += 1

static func _chunk(length: float, width: float, variant: int, cache: Dictionary, totals: Dictionary) -> ArrayMesh:
	var key := "%.2f|%.2f|%d" % [length, width, variant]
	if cache.has(key): return cache[key]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var half := Vector2(length, width) * .5
	var bed_y := -BED_BELOW
	# Dark bed shows through every joint.
	_quad(verts, normals, uvs, colors, [Vector3(-half.x, bed_y, -half.y), Vector3(half.x, bed_y, -half.y), Vector3(half.x, bed_y, half.y), Vector3(-half.x, bed_y, half.y)], Vector3.UP, [Vector2(.5, .5), Vector2(.5, .5), Vector2(.5, .5), Vector2(.5, .5)], BED.srgb_to_linear())
	var z := -half.y
	var row := 0
	while z < half.y - .001:
		var dz := minf(STONE.y, half.y - z)
		var x := -half.x
		var column := 0
		while x < half.x - .001:
			var dx := minf(STONE.x if column > 0 or row % 2 == 0 else STONE.x * .5, half.x - x)
			if dx > JOINT * 3.0 and dz > JOINT * 3.0:
				var shade := posmod((variant * 37 + row * 71 + column * 127) ^ (row * column * 31), 5)
				var tint := SHADES[shade].srgb_to_linear()
				tint = Color(tint.r * LUMINANCE[shade], tint.g * LUMINANCE[shade], tint.b * LUMINANCE[shade])
				_stone(verts, normals, uvs, colors, Rect2(x + JOINT * .5, z + JOINT * .5, dx - JOINT, dz - JOINT), tint)
				totals.stones += 1
			x += dx
			column += 1
		z += dz
		row += 1
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	cache[key] = mesh
	totals.unique_meshes += 1
	return mesh

## Top face plus four short sides. UVs run 0..1 across each stone, which is what
## the paving shader reads for edge soil and the worn arris.
static func _stone(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, tile: Rect2, tint: Color) -> void:
	var corners: Array[Vector3] = [Vector3(tile.position.x, 0, tile.position.y), Vector3(tile.end.x, 0, tile.position.y), Vector3(tile.end.x, 0, tile.end.y), Vector3(tile.position.x, 0, tile.end.y)]
	var corner_uv: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	_quad(verts, normals, uvs, colors, corners, Vector3.UP, corner_uv, tint)
	var drop := Vector3.DOWN * (BED_BELOW + .001)
	for side: int in range(4):
		var a: Vector3 = corners[side]
		var b: Vector3 = corners[(side + 1) % 4]
		var edge := b - a
		var outward := Vector3(edge.z, 0, -edge.x).normalized()
		_quad(verts, normals, uvs, colors, [a, b, b + drop, a + drop], outward, [corner_uv[side], corner_uv[(side + 1) % 4], corner_uv[(side + 1) % 4], corner_uv[side]], tint * .8)

static func _quad(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, points: Array, normal: Vector3, quad_uvs: Array, tint: Color) -> void:
	for index: int in [0, 1, 3, 1, 2, 3]:
		verts.append(points[index])
		normals.append(normal)
		uvs.append(quad_uvs[index])
		colors.append(tint)

## The sidewalk slabs run straight across each junction as tan bands. A thin
## visual skin of the road's own material turns them back into road; the zebra
## crossings sit above it and collision stays on the slabs below.
static func _resurface_junctions(parent: Node3D, asphalt: Material, totals: Dictionary) -> void:
	if asphalt == null: return
	var skin_y := .0005
	for xr: float in [-51.5, 51.5]:
		for za: float in [-50.0, 55.0]:
			for side: float in [-1.0, 1.0]:
				_skin(parent, Vector3(xr + side * 8.0, skin_y, za), Vector3(3.9, .003, 12.2), asphalt)
				_skin(parent, Vector3(xr, skin_y, za + side * 8.0), Vector3(12.2, .003, 3.9), asphalt)
				totals.junction_patches += 2

static func _skin(parent: Node3D, centre: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var skin := MeshInstance3D.new()
	skin.name = "JunctionRoadSkin"
	skin.mesh = mesh
	skin.material_override = material
	skin.position = centre
	skin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(skin)
