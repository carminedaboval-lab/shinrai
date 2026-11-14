extends Node3D
## A tree-lined plaza along one side of a built road (owner's choice, 2026-11-14, for the
## south side of the shop row road): the paving of the open ground, and a tree pit round each
## street tree. The trees themselves are the map's own trees; benches, lamps and the like are
## Codex's, in its own script.
##
## Built from the map's spaces that carry "row_plaza" (tools/map_plan/businesses.py,
## plant_plaza). The paving covers the ground picture's own plaza colour and nothing else, so
## it stops where the picture has a road, a building's plot or grass.

const SURFACE := "res://scripts/map1/map1_shop_forecourt.tres"   # Codex's cast concrete, UV in metres
const LIFT := 0.012
const PIT := 1.3               # a tree pit's side
const EDGING := 0.10           # the stone edging round it
const EDGING_HIGH := 0.03
const SOIL := Color(0.16, 0.13, 0.10)
const STONE := Color(0.50, 0.49, 0.46)
const PLAIN := Color(0.36, 0.355, 0.34)
const STRIP := 8.0             # the paving is laid in pieces no longer than this, to follow the ground

var space: Dictionary
var paved_area := 0.0          # square metres


static func install(map: Node3D) -> Array:
	var made: Array = []
	for entry: Dictionary in map.data.get("spaces", []):
		if not bool(entry.get("row_plaza", false)): continue
		var plaza := new()
		plaza.name = "Plaza%d" % made.size()
		plaza.space = entry
		map.add_child(plaza)
		plaza._build(map)
		made.append(plaza)
	return made


func _build(map: Node3D) -> void:
	var image: Image = map.ground_image
	if image == null: return
	var frame: Rect2 = map.frame
	var side := float(space.side)
	var back := float(space.back)
	var x0 := int(floor(float(space.x) - float(space.w) * 0.5))
	var x1 := int(ceil(float(space.x) + float(space.w) * 0.5))
	var deep := int(float(space.d))
	# The plaza's colour: the picture's, three metres behind the footway at the middle.
	var want := image.get_pixel(int(float(space.x) - frame.position.x), int(back + side * 3.0 - frame.position.y))
	# And the picture's strip of pavement colour between the built footway and the plaza: it is
	# part of the same paved ground.
	var strip := image.get_pixel(int(float(space.x) - frame.position.x), int(back + side * 0.5 - frame.position.y))
	var pits: Array = space.get("trees", [])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	for row: int in deep:
		# One metre-deep row of the picture: z from za to zb.
		var za := back + side * float(row)
		var zb := back + side * float(row + 1)
		var z_low := minf(za, zb)
		var none := x0 - 1      # (x is negative here, so 'no stretch begun' cannot be -1)
		var from := none
		for x: int in range(x0, x1 + 1):
			var colour := image.get_pixel(int(float(x) + 0.5 - frame.position.x), int(z_low + 0.5 - frame.position.y))
			var here := x < x1 and (colour.is_equal_approx(want) or colour.is_equal_approx(strip)) and not _in_pit(pits, float(x) + 0.5, z_low + 0.5)
			if here and from == none: from = x
			elif (not here or float(x - from) >= STRIP) and from != none:
				_slab(map, tool, float(from), float(x), z_low, z_low + 1.0)
				paved_area += float(x - from)
				from = x if here else none
	if paved_area > 0.0:
		var ground := MeshInstance3D.new()
		ground.name = "Paving"
		ground.mesh = tool.commit()
		if ResourceLoader.exists(SURFACE):
			ground.material_override = load(SURFACE)
		else:
			var plain := StandardMaterial3D.new()
			plain.albedo_color = PLAIN
			plain.roughness = 0.95
			ground.material_override = plain
		add_child(ground)
	# The tree pits: bare soil in a stone edging, a whole number of picture squares so the
	# paving meets them.
	if pits.is_empty(): return
	var edge := SurfaceTool.new()
	edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	edge.set_smooth_group(-1)
	for tree: Array in pits:
		var square := _pit_square(float(tree[0]), float(tree[1]))
		edge.set_color(SOIL)
		_box(map, edge, square.position.x + EDGING, square.position.y + EDGING, square.end.x - EDGING, square.end.y - EDGING, LIFT)
		edge.set_color(STONE)
		for bar: Array in [
				[square.position.x, square.position.y, square.end.x, square.position.y + EDGING],
				[square.position.x, square.end.y - EDGING, square.end.x, square.end.y],
				[square.position.x, square.position.y + EDGING, square.position.x + EDGING, square.end.y - EDGING],
				[square.end.x - EDGING, square.position.y + EDGING, square.end.x, square.end.y - EDGING]]:
			_box(map, edge, float(bar[0]), float(bar[1]), float(bar[2]), float(bar[3]), EDGING_HIGH)
	edge.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pit_mesh := MeshInstance3D.new()
	pit_mesh.name = "TreePits"
	pit_mesh.mesh = edge.commit()
	pit_mesh.material_override = material
	add_child(pit_mesh)


## The square of ground a tree's pit takes: whole picture squares round the trunk.
func _pit_square(x: float, z: float) -> Rect2:
	var low := Vector2(floor(x - PIT * 0.5), floor(z - PIT * 0.5))
	var high := Vector2(ceil(x + PIT * 0.5), ceil(z + PIT * 0.5))
	return Rect2(low, high - low)


func _in_pit(pits: Array, x: float, z: float) -> bool:
	for tree: Array in pits:
		if _pit_square(float(tree[0]), float(tree[1])).has_point(Vector2(x, z)): return true
	return false


## One piece of paving, facing up, UV in metres of the world.
func _slab(map: Node3D, tool: SurfaceTool, xa: float, xb: float, za: float, zb: float) -> void:
	var corners: Array[Vector3] = [map.on_ground(xa, za, LIFT), map.on_ground(xb, za, LIFT), map.on_ground(xb, zb, LIFT), map.on_ground(xa, zb, LIFT)]
	var order := PackedInt32Array([0, 1, 2, 0, 2, 3])
	if (corners[1] - corners[0]).cross(corners[2] - corners[0]).y > 0.0: order = PackedInt32Array([0, 2, 1, 0, 3, 2])
	for index: int in order:
		tool.set_uv(Vector2(corners[index].x, corners[index].z))
		tool.add_vertex(corners[index])


## A low flat box on the ground from (xa, za) to (xb, zb), `high` above it: its top and sides.
func _box(map: Node3D, tool: SurfaceTool, xa: float, za: float, xb: float, zb: float, high: float) -> void:
	var low: Array[Vector3] = [map.on_ground(xa, za), map.on_ground(xb, za), map.on_ground(xb, zb), map.on_ground(xa, zb)]
	var top: Array[Vector3] = []
	for point: Vector3 in low: top.append(point + Vector3.UP * high)
	for point: Vector3 in [top[0], top[1], top[2], top[0], top[2], top[3]]: tool.add_vertex(point)
	for i: int in 4:
		var n := (i + 1) % 4
		for point: Vector3 in [low[i], top[i], top[n], low[i], top[n], low[n]]: tool.add_vertex(point)
