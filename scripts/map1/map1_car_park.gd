extends Node3D
## The ground of a coin car park that fills a gap in a row of shop-houses: its own asphalt,
## and a low cast-concrete upstand along the two neighbours and the back. The street side is
## open; the kerb there is lowered by the street edge itself (it finds the car-park grey in
## the ground picture). What stands on the lot (bays, flap locks, pay machine, price sign) is
## Codex's, in its own script.
##
## Built from the map's spaces that carry "row_gap" (tools/map_plan/businesses.py,
## fill_row_gaps): the lot's middle, its width along the row, its depth, its turn, and the
## direction of the street.

const SURFACE := "res://scripts/map1/map1_shop_footway.tres"   # Codex's fine asphalt, UV in metres
const LIFT := 0.012            # the asphalt above the painted ground
const UPSTAND_WIDE := 0.12
const UPSTAND_HIGH := 0.12
const WALL_HIGH := 1.5         # the wall along the back, to the plot behind
const FOOT := 0.05
const CONCRETE := Color(0.47, 0.46, 0.43)
const PLAIN := Color(0.17, 0.17, 0.18)

var space: Dictionary
var surface_height := 0.0      # the asphalt's height at the lot's middle, for whoever stands things on it


static func install(map: Node3D) -> Array:
	var lots: Array = []
	for entry: Dictionary in map.data.get("spaces", []):
		if not bool(entry.get("row_gap", false)): continue
		var lot := new()
		lot.name = "CoinCarPark%d" % lots.size()
		lot.space = entry
		map.add_child(lot)
		lot._build(map)
		lots.append(lot)
	return lots


## A point of the lot: `across` metres along the row from its middle, `back` metres from the
## building line away from the street.
func spot(map: Node3D, across: float, back: float, lift := 0.0) -> Vector3:
	var street := Vector2(float(space.street[0]), float(space.street[1]))
	var along := Vector2(street.y, -street.x)
	var line := Vector2(float(space.x), float(space.z)) + street * float(space.d) * 0.5
	var flat := line + along * across - street * back
	return map.on_ground(flat.x, flat.y, lift)


func _build(map: Node3D) -> void:
	var wide := float(space.w)
	var deep := float(space.d)
	surface_height = spot(map, 0.0, deep * 0.5, LIFT).y
	# The asphalt, a metre at a time so it follows the ground.
	var columns := int(ceil(wide))
	var rows := int(ceil(deep))
	var ground := MeshInstance3D.new()
	ground.name = "Asphalt"
	# (Built facing up: if the first order of corners faces down, the other is used.)
	for order: Array in [[0, 1, 2, 0, 2, 3], [0, 2, 1, 0, 3, 2]]:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i: int in columns:
			for j: int in rows:
				var a0 := -wide * 0.5 + wide * float(i) / float(columns)
				var a1 := -wide * 0.5 + wide * float(i + 1) / float(columns)
				var b0 := deep * float(j) / float(rows)
				var b1 := deep * float(j + 1) / float(rows)
				var corners: Array = [[a0, b0], [a1, b0], [a1, b1], [a0, b1]]
				for index: int in order:
					tool.set_uv(Vector2(float(corners[index][0]), float(corners[index][1])))
					tool.set_color(PLAIN)
					tool.add_vertex(spot(map, float(corners[index][0]), float(corners[index][1]), LIFT))
		tool.generate_normals()
		ground.mesh = tool.commit()
		var facing := (ground.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_NORMAL] as PackedVector3Array
		if facing.size() > 0 and facing[0].y > 0.0: break
	if ResourceLoader.exists(SURFACE):
		ground.material_override = load(SURFACE)
	else:
		var plain := StandardMaterial3D.new()
		plain.vertex_color_use_as_albedo = true
		plain.vertex_color_is_srgb = true
		plain.roughness = 0.95
		ground.material_override = plain
	add_child(ground)
	# The upstand: along each neighbour from the building line to the back, and across the back.
	var edge := SurfaceTool.new()
	edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	edge.set_smooth_group(-1)
	edge.set_color(CONCRETE)
	var body := StaticBody3D.new()
	body.name = "Upstand"
	var half := wide * 0.5
	for piece: Array in [[-half, 0.0, -half + UPSTAND_WIDE, deep], [half - UPSTAND_WIDE, 0.0, half, deep], [-half + UPSTAND_WIDE, deep - UPSTAND_WIDE, half - UPSTAND_WIDE, deep]]:
		_block(map, edge, body, float(piece[0]), float(piece[1]), float(piece[2]), float(piece[3]))
	# The back is the boundary with the plot behind: a rendered wall on the upstand, with a
	# coping a little wider than the wall, as such boundaries have.
	_block(map, edge, body, -half, deep - UPSTAND_WIDE, half, deep, UPSTAND_HIGH, WALL_HIGH)
	edge.set_color(CONCRETE.lightened(0.08))
	_block(map, edge, body, -half, deep - UPSTAND_WIDE - 0.03, half, deep + 0.03, WALL_HIGH, WALL_HIGH + 0.06)
	edge.set_color(CONCRETE)
	edge.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.92
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var upstand := MeshInstance3D.new()
	upstand.name = "UpstandMesh"
	upstand.mesh = edge.commit()
	upstand.material_override = material
	add_child(upstand)
	add_child(body)


## One straight length of upstand between two corners of the lot, with its collision.
func _block(map: Node3D, tool: SurfaceTool, body: StaticBody3D, a0: float, b0: float, a1: float, b1: float, from := -FOOT, to := UPSTAND_HIGH) -> void:
	var low: Array[Vector3] = [spot(map, a0, b0, from), spot(map, a1, b0, from), spot(map, a1, b1, from), spot(map, a0, b1, from)]
	var high: Array[Vector3] = [spot(map, a0, b0, to), spot(map, a1, b0, to), spot(map, a1, b1, to), spot(map, a0, b1, to)]
	for i: int in 4:
		var n := (i + 1) % 4
		for point: Vector3 in [low[i], high[i], high[n], low[i], high[n], low[n]]: tool.add_vertex(point)
	for point: Vector3 in [high[0], high[1], high[2], high[0], high[2], high[3]]: tool.add_vertex(point)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var middle := (low[0] + high[2]) * 0.5
	box.size = Vector3(low[0].distance_to(low[1]), to - from, low[1].distance_to(low[2]))
	shape.shape = box
	shape.transform = Transform3D(Basis(Vector3.UP, atan2(-(low[1] - low[0]).z, (low[1] - low[0]).x)), middle)
	body.add_child(shape)
