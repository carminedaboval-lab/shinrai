extends Node3D
## Fixtures of the four-space coin lot immediately east of the shop-row café.
const Shell := preload("res://scripts/interior_kit/shell_mesh.gd")
const Kit := preload("res://scripts/interior_kit/house_kit.gd")
const CarPark := preload("res://scripts/map1/map1_car_park.gd")
const PAINT := Color("#dedccd")
const STEEL := Color("#717877")
const CAST := Color("#394144")
const YELLOW := Color("#edba45")
const BLUE := Color("#234659")
const ENAMEL := Color("#dedbc9")
const BAY_WIDTH := 2.5
const BAY_DEPTH := 5.0

var shell := Shell.new()
var solid := StaticBody3D.new()

static func install(map: Node3D) -> void:
	for lot: Dictionary in map.data.spaces:
		if lot.kind != "coin car park" or absf(lot.x + 306.05) > 2.0: continue
		if not lot.get("row_gap",false) or lot.street[1] < 0.999: continue
		var front: float = lot.z + lot.d * 0.5
		if absf(front + 459.5) > 3.0 or lot.w < 11.8 or lot.d < 10.5: continue
		build_lot(map, lot)
		return

static func build_lot(map: Node3D, lot: Dictionary) -> Node3D:
	var fixtures := new()
	fixtures.name = "ShopRowCoinParking"
	map.add_child(fixtures)
	fixtures.position = map.on_ground(lot.x, lot.z + lot.d * 0.5)
	fixtures.solid.name = "Fixtures"
	fixtures.solid.collision_layer = 1
	fixtures.solid.collision_mask = 0
	fixtures.add_child(fixtures.solid)
	var right: float = lot.w * 0.5 - 0.48
	# Keep the aisle clear and leave a kerb's width behind the parking paint.
	var bay_front := -minf(6.0,lot.d - CarPark.UPSTAND_WIDE - 0.04 - BAY_DEPTH)
	for i in 5:
		var x := right - (4 - i) * BAY_WIDTH
		fixtures.stripe(map, x - 0.045, x + 0.045, bay_front - BAY_DEPTH, bay_front)
		if i == 4: break
		var centre := x + BAY_WIDTH * 0.5
		fixtures.stripe(map, x + 0.045, x + BAY_WIDTH - 0.045, bay_front - BAY_DEPTH, bay_front - BAY_DEPTH + 0.09)
		var plate := fixtures.base(map, centre, bay_front - 2.5)
		fixtures.flap(plate, i + 1)
		var mark := fixtures.base(map, centre, bay_front - 0.72)
		mark.basis = Basis(Vector3.RIGHT, -PI * 0.5)
		fixtures.letters(mark.translated(Vector3.UP * 0.005), str(i+1), Vector2(0.56,0.74), PAINT)
	var west: float = -lot.w * 0.5
	fixtures.machine(fixtures.base(map, west + 1.05, -3.3))
	fixtures.tariff(fixtures.base(map, right - 0.55, -1.1))
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "ParkingFurniture"
	mesh_instance.mesh = fixtures.shell.commit()
	fixtures.add_child(mesh_instance)
	return fixtures

func base(map: Node3D, x: float, z: float) -> Transform3D:
	var p := position + Vector3(x,0,z)
	var top: Vector3 = map.on_ground(p.x,p.z,CarPark.LIFT)
	return Transform3D(Basis.IDENTITY, top-position)

func stripe(map: Node3D, left: float, right: float, back: float, front: float) -> void:
	var corners := PackedVector3Array()
	for p: Vector2 in [Vector2(left,back),Vector2(right,back),Vector2(right,front),Vector2(left,front)]:
		corners.append(base(map,p.x,p.y).origin + Vector3.UP * 0.003)
	shell.quad(corners[0],corners[1],corners[2],corners[3],Vector3.UP,PAINT)

func letters(at: Transform3D, words: String, bounds: Vector2, color: Color) -> void:
	var glyph := Kit.sign_shape(words)
	if glyph.corners.is_empty(): return
	shell.flat(at,glyph.corners,minf(bounds.x/glyph.size.x,bounds.y/glyph.size.y),color)

func part(at: Transform3D, centre: Vector3, size: Vector3, color: Color) -> void:
	shell.box(at,centre,size,color)

func collider(at: Transform3D, centre: Vector3, size: Vector3, label: String) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var node := CollisionShape3D.new()
	node.name = label
	node.shape = shape
	node.transform = at.translated_local(centre)
	solid.add_child(node)

func flap(at: Transform3D, number: int) -> void:
	# The plate is folded down. Its long edge pivots on two bearings beside the drive housing.
	part(at,Vector3(0,0.018,0),Vector3(1.58,0.036,0.42),CAST)
	part(at,Vector3(-0.09,0.043,0.018),Vector3(1.16,0.025,0.33),STEEL)
	for x: float in [-0.58,0.40]:
		part(at,Vector3(x,0.055,-0.154),Vector3(0.14,0.06,0.095),CAST)
	part(at,Vector3(0.655,0.064,0),Vector3(0.25,0.12,0.40),YELLOW)
	collider(at,Vector3(-0.13,0.029,0),Vector3(1.31,0.058,0.42),"Plate%d"%number)
	collider(at,Vector3(0.655,0.064,0),Vector3(0.25,0.12,0.40),"Drive%d"%number)

func machine(at: Transform3D) -> void:
	part(at,Vector3(0,0.075,0),Vector3(0.80,0.15,0.65),STEEL)
	part(at,Vector3(0,0.88,0),Vector3(0.67,1.46,0.46),ENAMEL)
	part(at,Vector3(0,1.65,0.045),Vector3(0.76,0.09,0.64),BLUE)
	part(at,Vector3(0,1.30,0.239),Vector3(0.51,0.30,0.028),CAST)
	letters(at.translated_local(Vector3(0,1.31,0.255)),"車室番号",Vector2(0.40,0.11),Color("#b6d0a9"))
	for row in 4:
		for column in 3:
			var key := Vector3(-0.19 + column*0.068,1.04 - row*0.067,0.252)
			var label := str(1+3*row+column) if row<3 else ["消","0","確"][column] as String
			part(at,key,Vector3(0.052,0.049,0.035),STEEL)
			letters(at.translated_local(key + Vector3(0,0,0.018)),label,Vector2(0.030,0.034),ENAMEL)
	part(at,Vector3(0.165,1.0,0.24),Vector3(0.12,0.15,0.032),STEEL)
	part(at,Vector3(0.165,1.0,0.258),Vector3(0.013,0.09,0.009),CAST)
	part(at,Vector3(0,0.65,0.241),Vector3(0.31,0.067,0.026),CAST)
	part(at,Vector3(0,0.605,0.269),Vector3(0.34,0.025,0.092),STEEL)
	collider(at,Vector3(0,0.81,0),Vector3(0.69,1.62,0.49),"PayMachine")

func tariff(at: Transform3D) -> void:
	part(at,Vector3(0,1.18,0),Vector3(0.14,2.36,0.14),STEEL)
	collider(at,Vector3(0,1.18,0),Vector3(0.14,2.36,0.14),"TariffPost")
	# The sign projects towards the street and can be read from either end of the row.
	var board := at.rotated_local(Vector3.UP,PI*0.5)
	part(board,Vector3(0,2.70,0),Vector3(1.02,0.96,0.095),YELLOW)
	collider(board,Vector3(0,2.70,0),Vector3(1.02,0.96,0.095),"TariffBoard")
	for yaw: float in [0.0,PI]:
		var face := board.rotated_local(Vector3.UP,yaw)
		letters(face.translated_local(Vector3(0,2.86,0.050)),"P",Vector2(0.54,0.49),BLUE)
		letters(face.translated_local(Vector3(0,2.45,0.050)),"30分 200円",Vector2(0.89,0.19),BLUE)
