extends Node3D
## A small neighbourhood police office and the opposite open-air café terrace.
## All details share one mesh per plot, including the lettering.
const Kit := preload("res://scripts/interior_kit/house_kit.gd")
const EDGE := {"name":"koban lane", "cls":"local", "w":4.8, "pavement":1.35,
	"points":[[11.0,412.25],[181.0,412.25]]}
const CREAM := Color("#e5ded1")
const GREEN := Color("#486353")
const WOOD := Color("#865b3e")
const STEEL := Color("#565e60")
const GLASS := Color("#577275")
const NAVY := Color("#344a54")
const RED := Color("#b64536")
var surface := SurfaceTool.new()
var solid := StaticBody3D.new()
var unit := BoxMesh.new()
var round_piece := CylinderMesh.new()

static func nearby_plot(map: Node3D, kind: String, expected: Vector2) -> Dictionary:
	var nearest := {}
	var distance := 7.0
	for plot: Dictionary in map.data.spaces:
		if plot.kind != kind: continue
		var delta := expected.distance_to(Vector2(plot.x,plot.z))
		if delta < distance:
			nearest = plot
			distance = delta
	return nearest

static func has_plots(map: Node3D) -> bool:
	return not nearby_plot(map,"cafe terrace",Vector2(21.6,421.4)).is_empty() and not nearby_plot(map,"police box",Vector2(20.3,392.9)).is_empty()

static func install(map: Node3D) -> void:
	var cafe := nearby_plot(map,"cafe terrace",Vector2(21.6,421.4))
	var office := nearby_plot(map,"police box",Vector2(20.3,392.9))
	if cafe.is_empty() or office.is_empty(): return
	var streets: Array = map.street_edges.filter(func(e: Node3D)->bool: return e.get_meta("edge").name==EDGE.name)
	if streets.is_empty(): return
	var street: Node3D = streets[0]
	var line: Array = street.get_meta("edge").points
	# The generator places these fixtures at fractions of their plot dimensions.
	# Only dress the two plots facing this street in their supported orientation.
	var specs := [["office",office,"building",Vector2(-0.12,0.16)],["mast",office,"mast",Vector2(0.34,-0.30)],
		["awning",cafe,"small",Vector2(0,0.30)],["table_a",cafe,"small",Vector2(-0.25,-0.10)],
		["table_b",cafe,"small",Vector2(0.05,-0.25)],["table_c",cafe,"small",Vector2(0.28,0.05)]]
	var sources := {}
	var coordinates := {}
	for spec: Array in specs:
		var plot: Dictionary = spec[1]
		var offset: Vector2 = spec[3]
		var expected := Vector2(plot.x-offset.y*plot.d,plot.z+offset.x*plot.w)
		var distance := 0.35
		for i: int in map.data.boxes.size():
			var b: Array = map.data.boxes[i]
			if map.data.kinds[int(b[7])] != spec[2] or absf(b[6]+90.0)>0.1: continue
			var point := Vector2(b[0],b[2])
			var delta := expected.distance_to(point)
			if delta < distance:
				distance = delta
				sources[spec[0]] = i
				coordinates[spec[0]] = point
	if sources.size() != specs.size():
		push_warning("Koban lane plot furniture could not be matched to the generated boxes")
		return
	var lane := Node3D.new()
	lane.name="KobanLane"
	map.add_child(lane)
	for feature: String in ["Terrace","PoliceBox"]:
		var plot := new()
		plot.name=feature
		lane.add_child(plot)
		var anchor: Vector2=coordinates["awning" if feature=="Terrace" else "office"]
		plot.position=map.on_ground(anchor.x,anchor.y)
		plot.begin()
		if feature=="Terrace":
			var tables: Array[Vector3] = []
			for key: String in ["table_a","table_b","table_c"]:
				var point: Vector2 = coordinates[key]
				tables.append(map.on_ground(point.x,point.y)-plot.position)
			plot.terrace(tables)
		else:
			var mast: Vector2 = coordinates.mast
			plot.koban(map.on_ground(mast.x,mast.y)-plot.position,line,Vector2(cafe.x,cafe.z))
		plot.finish()
	# The two service covers follow the road elevation independently.
	for x: float in [60.0,137.0]:
		var drain := new()
		drain.name = "ServiceCover%d" % int(x)
		lane.add_child(drain)
		var along: float = street.along_of(Vector3(x,0,line[0][1]))
		drain.position = street.at(along,-street.side*street.half*0.5)
		drain.begin()
		drain.service_cover()
		drain.finish()
	for key: String in ["awning","table_a","table_b","table_c"]:
		map.set_box_drawn(sources[key],false)
		map.set_box_solid(sources[key],false)

func begin() -> void:
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	add_child(solid)
	solid.collision_layer=1
	solid.collision_mask=0
	round_piece.top_radius=0.5
	round_piece.bottom_radius=0.5
	round_piece.height=1
	round_piece.radial_segments=16
	round_piece.rings=1

func shape(mesh: PrimitiveMesh, at: Vector3, size: Vector3, tint: Color, basis:=Basis.IDENTITY) -> void:
	var arrays:=mesh.get_mesh_arrays()
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	for idx: int in arrays[Mesh.ARRAY_INDEX]:
		surface.set_normal((basis*(normals[idx]/size)).normalized())
		surface.set_color(tint)
		surface.add_vertex(at+basis*(size*vertices[idx]))

func box(at: Vector3,size: Vector3,tint: Color,collides:=false,basis:=Basis.IDENTITY) -> void:
	shape(unit,at,size,tint,basis)
	if collides: obstacle(at,size,basis)

func obstacle(at: Vector3,size: Vector3,basis:=Basis.IDENTITY) -> void:
	var collision:=CollisionShape3D.new()
	var cube:=BoxShape3D.new()
	cube.size=size
	collision.shape=cube
	collision.transform=Transform3D(basis,at)
	solid.add_child(collision)

func letters(words: String, fallback: String, at: Vector3, yaw: float, wide: float, tall: float, tint: Color) -> void:
	var glyphs:=Kit.sign_shape(words)
	if glyphs.corners.is_empty(): glyphs=Kit.sign_shape(fallback)
	if glyphs.corners.is_empty(): return
	var scale_factor:=minf(wide/glyphs.size.x,tall/glyphs.size.y)
	var turn:=Basis(Vector3.UP,yaw)
	for p: Vector3 in glyphs.corners:
		surface.set_normal(turn.z)
		surface.set_color(tint)
		surface.add_vertex(at+turn*(p*scale_factor))

func terrace(tables: Array[Vector3]) -> void:
	# Narrow canvas roof follows the original north-south footprint. Cross beams,
	# downpipes and the rolled hem make its construction readable from the lane.
	for z: float in [-4.72,0.0,4.72]:
		for x: float in [-1.05,1.05]:
			box(Vector3(x,1.38,z),Vector3(0.095,2.76,0.095),GREEN,true)
		box(Vector3(0,2.72,z),Vector3(2.34,0.10,0.12),WOOD)
	var lean:=Basis(Vector3.BACK,deg_to_rad(-6))
	box(Vector3(0,2.82,0),Vector3(2.62,0.065,10.50),GREEN,true,lean)
	box(Vector3(1.28,2.59,0),Vector3(0.035,0.20,10.50),GREEN)
	box(Vector3(0,2.68,-5.23),Vector3(2.62,0.31,0.08),GREEN)
	letters("喫茶  こみち","KOMICHI COFFEE",Vector3(0,2.68,-5.275),PI,2.28,0.25,CREAM)
	for i: int in tables.size():
		var table := tables[i]
		var chair_turn := Basis(Vector3.UP,deg_to_rad([12.0,-28.0,41.0][i]))
		shape(round_piece,table+Vector3.UP*0.74,Vector3(0.96,0.07,0.96),WOOD)
		shape(round_piece,table+Vector3.UP*0.35,Vector3(0.09,0.70,0.09),STEEL)
		shape(round_piece,table+Vector3.UP*0.045,Vector3(0.58,0.07,0.58),STEEL)
		obstacle(table+Vector3.UP*0.38,Vector3(0.72,0.76,0.72))
		for side: int in [-1,1]:
			var reach := 1.04 if i==1 and side==1 else 0.83
			var seat:=table+chair_turn*Vector3(0,0,side*reach)
			box(seat+Vector3.UP*0.46,Vector3(0.42,0.07,0.42),GREEN,false,chair_turn)
			box(seat+chair_turn*Vector3(0,0.70,side*0.19),Vector3(0.42,0.38,0.055),WOOD,false,chair_turn)
			for dx: float in [-0.16,0.16]:
				for dz: float in [-0.16,0.16]:
					box(seat+chair_turn*Vector3(dx,0.22,dz),Vector3(0.038,0.44,0.038),STEEL,false,chair_turn)
			obstacle(seat+Vector3.UP*0.29,Vector3(0.39,0.58,0.39),chair_turn)
	# Short service counter beneath the awning with stacked saucers and a coffee urn.
	box(Vector3(0,0.48,0.5),Vector3(1.18,0.96,2.68),WOOD,true)
	box(Vector3(0,0.99,0.5),Vector3(1.35,0.08,2.82),CREAM)
	for i: int in 4:
		shape(round_piece,Vector3(0.2,1.046+i*0.024,0.05),Vector3(0.20,0.022,0.20),CREAM)
	shape(round_piece,Vector3(0,1.23,1.12),Vector3(0.30,0.40,0.30),STEEL)
	box(Vector3(0.15,1.18,1.12),Vector3(0.14,0.06,0.06),NAVY)

func koban(mast: Vector3, line: Array, cafe: Vector2) -> void:
	# The actual office is retained. Its street façade faces south (+Z), 3.5 m
	# from its centre. Fixtures sit on that wall rather than on the public footway.
	box(Vector3(0,2.68,3.69),Vector3(5.6,0.36,0.61),NAVY)
	letters("交番","KOBAN",Vector3(0,2.67,4.005),0,1.12,0.28,CREAM)
	box(Vector3(-0.72,1.16,3.57),Vector3(1.10,2.27,0.09),NAVY)
	box(Vector3(-0.72,1.45,3.63),Vector3(0.91,1.48,0.035),GLASS)
	box(Vector3(-1.07,1.09,3.67),Vector3(0.048,0.27,0.045),CREAM)
	for y: float in [1.56,4.38]:
		for x: float in [0.77,1.89]:
			box(Vector3(x,y,3.56),Vector3(1.03,1.12,0.10),NAVY)
			box(Vector3(x,y,3.62),Vector3(0.92,1.00,0.04),GLASS)
			box(Vector3(x,y,3.65),Vector3(0.043,1.00,0.024),CREAM)
	# Koban beacon and framed neighbourhood map on the approach side of the mast.
	shape(round_piece,mast+Vector3.UP*4.24,Vector3(0.40,0.09,0.40),STEEL)
	shape(round_piece,mast+Vector3.UP*4.42,Vector3(0.29,0.31,0.29),RED)
	box(mast+Vector3(0,3.51,0),Vector3(0.93,0.44,0.27),NAVY)
	letters("交番","KOBAN",mast+Vector3(0,3.51,0.145),0,0.72,0.32,CREAM)
	var board:=mast+Vector3(-1.94,1.36,-0.01)
	for dx: float in [-0.74,0.74]:
		box(board+Vector3(dx,-0.53,0),Vector3(0.08,1.66,0.10),STEEL,true)
	box(board,Vector3(1.66,1.03,0.105),NAVY,true)
	box(board+Vector3(0,-0.10,0.06),Vector3(1.53,0.69,0.022),Color("#d5d3bd"))
	letters("町内案内","AREA MAP",board+Vector3(0,0.37,0.065),0,1.33,0.19,CREAM)
	# Face-on, east is right and north is up. Draw this actual lane, its two
	# junctions and the café opposite the viewer's red location dot.
	var street_y:=-0.14
	var start_x: float = line.front()[0]
	var road_z: float = line.front()[1]
	var per_m: float = 1.40/(line.back()[0]-start_x)
	box(board+Vector3(0,street_y,0.080),Vector3(1.45,0.045,0.012),CREAM)
	for junction_x: float in [88.1,169.1]:
		box(board+Vector3((junction_x-start_x)*per_m-0.70,-0.10,0.084),Vector3(0.052,0.59,0.012),CREAM)
	var cafe_x:=(cafe.x-start_x)*per_m-0.70
	box(board+Vector3(cafe_x,street_y-(cafe.y-road_z)*per_m,0.093),Vector3(0.09,0.07,0.012),GREEN)
	var here:=Vector3((position.x+board.x-start_x)*per_m-0.70,street_y-(position.z+board.z-road_z)*per_m,0.101)
	shape(round_piece,board+here,Vector3(0.075,0.014,0.075),RED,Basis(Vector3.RIGHT,PI/2))

## A hatch within a saw-cut repair in the wheel track. Raised by millimetres
## above the road ribbon and flush for the player and wheel collisions.
func service_cover() -> void:
	var seam:=Color("#424341")
	var iron:=Color("#625c53")
	var patch:=Color("#484947")
	box(Vector3(0,0.013,0),Vector3(1.14,0.004,0.99),seam)
	box(Vector3(0,0.016,0),Vector3(1.09,0.004,0.94),patch)
	shape(round_piece,Vector3(0,0.020,0),Vector3(0.70,0.005,0.70),iron)
	shape(round_piece,Vector3(0,0.024,0),Vector3(0.61,0.004,0.61),seam)
	for j: int in 12:
		var angle:=j*TAU/12.0
		var turn:=Basis(Vector3.UP,angle)
		box(turn*Vector3(0,0.027,0.215),Vector3(0.018,0.004,0.11),iron,false,turn)
	shape(round_piece,Vector3(0,0.027,0),Vector3(0.20,0.004,0.20),iron)

func finish() -> void:
	surface.index()
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.vertex_color_is_srgb=true
	material.roughness=0.88
	var mesh_node:=MeshInstance3D.new()
	mesh_node.mesh=surface.commit()
	mesh_node.material_override=material
	add_child(mesh_node)
