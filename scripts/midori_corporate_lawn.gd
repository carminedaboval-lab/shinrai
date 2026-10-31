extends RefCounted
## Real lawn for the corporate pocket gardens: the park's scanned turf as the
## ground, under a stacked shell lawn of fine blades. Each shell is one flat layer
## cut by midori_corporate_grass_shell.gdshader, so the grass reads as a carpet
## instead of separate tufts. It is visual only. Coordinates are district space.
const Turf = preload("res://scripts/midori_corporate_lawn.gdshader")
const Shell = preload("res://scripts/midori_corporate_grass_shell.gdshader")
const MAPS := "res://assets/shinrai/parks/midori_park/materials/vostok_environment_20261028/"
# Must match the PocketGarden slabs and GardenWalk paths in district.gd.
const GARDENS: Array[Rect2] = [Rect2(-35, 72, 70, 40), Rect2(-35, -113, 70, 47)]
const WALK_Z: Array[float] = [92.0, -89.5]
const WALK_HALF := 2.0
const GROUND_Y := .015
const STREAM_X := 15.5
const CHANNEL_WIDTH := 1.8
const POOL_SIZE := Vector2(8.0, 4.4)
const HEATHER_HEIGHT := .3
const HEATHER_SHELLS := 9
const GRASS_HEIGHT := .11
const SHELLS := 21
const CHUNK := 16.0
# Layers are shared out across three meshes, so distance drops every third layer
# while the lawn keeps its full height. [first layer of the three, draw range].
const GROUPS: Array[Vector2] = [Vector2(0, 150), Vector2(1, 40), Vector2(2, 20)]

## The stream north of the walk, in the lawn. It meets the bridge at the walk.
static func channel(garden: Rect2, walk_z: float) -> Rect2:
	var start := garden.position.y + 5.5
	return Rect2(STREAM_X - CHANNEL_WIDTH * .5, start, CHANNEL_WIDTH, walk_z - WALK_HALF - start)

## The three terraced pools south of the walk.
static func pools(walk_z: float) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for i: int in range(3):
		result.append(Rect2(STREAM_X - POOL_SIZE.x * .5, walk_z + 2.2 + float(i) * POOL_SIZE.y, POOL_SIZE.x, POOL_SIZE.y))
	return result

## Bell heather beds just inside the hedges on the long edges.
static func heather_beds(garden: Rect2) -> Array[Rect2]:
	return [Rect2(garden.position.x + 3.0, garden.position.y + 1.7, garden.size.x - 6.0, 1.3), Rect2(garden.position.x + 3.0, garden.end.y - 3.0, garden.size.x - 6.0, 1.3)]

static func surface() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = "CorporateLawnTurf"
	material.shader = Turf
	material.set_shader_parameter("turf_albedo", load(MAPS + "leafy_grass/leafy_grass_diff_2k.jpg"))
	material.set_shader_parameter("turf_normal", load(MAPS + "leafy_grass/leafy_grass_nor_gl_1k.jpg"))
	material.set_shader_parameter("turf_roughness", load(MAPS + "leafy_grass/leafy_grass_rough_1k.jpg"))
	material.set_shader_parameter("soil_albedo", load(MAPS + "dirt/dirt_diff_2k.jpg"))
	return material

static func grow(district: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "CorporateLawnGrass"
	root.set_meta("creator_protected", true)
	district.add_child(root)
	var material := ShaderMaterial.new()
	material.resource_name = "CorporateLawnBlades"
	material.shader = Shell
	material.set_shader_parameter("grass_height", GRASS_HEIGHT)
	var meshes: Array[ArrayMesh] = []
	for group: Vector2 in GROUPS:
		meshes.append(_layers(int(group.x), GROUPS.size(), SHELLS, GRASS_HEIGHT))
	var ranges: Array[float] = []
	for group: Vector2 in GROUPS:
		ranges.append(group.y)
	var heather := _heather_material()
	var heather_mesh: Array[ArrayMesh] = [_layers(0, 1, HEATHER_SHELLS, HEATHER_HEIGHT)]
	var heather_range: Array[float] = [120.0]
	var chunks := 0
	for i: int in range(GARDENS.size()):
		var garden := GARDENS[i]
		var top := WALK_Z[i] - WALK_HALF
		var bottom := WALK_Z[i] + WALK_HALF
		var open: Array[Rect2] = [Rect2(garden.position, Vector2(garden.size.x, top - garden.position.y)), Rect2(garden.position.x, bottom, garden.size.x, garden.end.y - bottom)]
		open = _without(open, channel(garden, WALK_Z[i]))
		for pool: Rect2 in pools(WALK_Z[i]):
			open = _without(open, pool)
		for bed: Rect2 in heather_beds(garden):
			open = _without(open, bed)
			chunks += _cover(root, bed, heather_mesh, heather, heather_range)
		for rect: Rect2 in open:
			chunks += _cover(root, rect, meshes, material, ranges)
	return {"shells":SHELLS, "chunks":chunks, "height_m":GRASS_HEIGHT}

## Low mounded evergreen with pink flower pockets, on the same shell technique.
static func _heather_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = "CorporateBellHeather"
	material.shader = Shell
	material.set_shader_parameter("grass_height", HEATHER_HEIGHT)
	material.set_shader_parameter("blades_per_m", 60.0)
	material.set_shader_parameter("root_color", Color(.08, .12, .06))
	material.set_shader_parameter("tip_color", Color(.24, .34, .17))
	material.set_shader_parameter("dry_color", Color(.62, .40, .52))
	material.set_shader_parameter("dry_amount", .6)
	material.set_shader_parameter("swell", .6)
	return material

## Unit square stacked in height. A chunk scales it in x and z.
static func _layers(first: int, step: int, count: int, height: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var index := first
	while index < count:
		var y := height * (float(index) + 1.0) / float(count)
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(Vector3(corner.x, y, corner.y))
		index += step
	return tool.commit()

static func _without(rects: Array[Rect2], hole: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for rect: Rect2 in rects:
		if not rect.intersects(hole):
			result.append(rect)
			continue
		if hole.position.y > rect.position.y:
			result.append(Rect2(rect.position, Vector2(rect.size.x, hole.position.y - rect.position.y)))
		if hole.end.y < rect.end.y:
			result.append(Rect2(rect.position.x, hole.end.y, rect.size.x, rect.end.y - hole.end.y))
		var z0 := maxf(rect.position.y, hole.position.y)
		var depth := minf(rect.end.y, hole.end.y) - z0
		result.append(Rect2(rect.position.x, z0, hole.position.x - rect.position.x, depth))
		result.append(Rect2(hole.end.x, z0, rect.end.x - hole.end.x, depth))
	return result

static func _cover(root: Node3D, rect: Rect2, meshes: Array[ArrayMesh], material: Material, ranges: Array[float]) -> int:
	var chunks := 0
	var x := rect.position.x
	while x < rect.end.x - .01:
		var width := minf(CHUNK, rect.end.x - x)
		var z := rect.position.y
		while z < rect.end.y - .01:
			var depth := minf(CHUNK, rect.end.y - z)
			for i: int in range(meshes.size()):
				var shell := MeshInstance3D.new()
				shell.name = "LawnShell"
				shell.mesh = meshes[i]
				shell.material_override = material
				shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				shell.visibility_range_end = ranges[i]
				shell.position = Vector3(x, GROUND_Y, z)
				shell.scale = Vector3(width, 1.0, depth)
				root.add_child(shell)
			chunks += 1
			z += depth
		x += width
	return chunks
