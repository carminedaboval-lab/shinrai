extends Node3D
## Small neighbourhood filling station. The front faces local +Z, towards the street.
## The shell is one mesh per station; only fixed obstacles have physics shapes.
const IVORY := Color("#e4e4d8")
const RED := Color("#ae392f")
const GOLD := Color("#f4b945")
const INK := Color("#26343a")
const STEEL := Color("#87979a")
const GLASS := Color("#436868")
var surface := SurfaceTool.new()
var unit := BoxMesh.new()
var station_style := 0 # 0: tyre shop, 1: highway self-service, 2: harbour service
var solid := StaticBody3D.new()

## Plot positions are reserved by the map generator before it fills neighbouring land.
static func install(map: Node3D) -> void:
	var group := Node3D.new()
	group.name = "FuelForecourts"
	map.add_child(group)
	for plot: Dictionary in map.data.get("fuel_stations", []):
		var station := new()
		station.name = str(plot.id).validate_node_name()
		group.add_child(station)
		station.position = map.on_ground(float(plot.x), float(plot.z))
		station.rotation.y = deg_to_rad(float(plot.yaw))
		var hint := (str(plot.id) + " " + str(plot.get("road", ""))).to_lower()
		station.station_style = 1 if ("airport" in hint or "expressway" in hint) else (2 if ("port" in hint or "dock" in hint or "west avenue" in hint) else 0)
		station.build(minf(float(plot.w) - 2.0, 25.0), minf(float(plot.d) - 1.0, 20.0))

func build(w: float, d: float) -> void:
	var back := -d * 0.5 + 1.1
	var span := w - 1.6
	var stripe: Color = [Color("#ac4534"), Color("#186a71"), Color("#304e73")][station_style]
	var brand: String = ["MARU  /  TYRE SERVICE", "HAYATE   /   SELF", "MINATO   /   MOTOR OIL"][station_style]
	add_child(solid)
	solid.collision_layer = 1
	solid.collision_mask = 0
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	box(Vector3(0, 0.005, 0), Vector3(w, 0.028, d), Color("#8e8d85"))
	# Low cashier kiosk with a wraparound horizontal band and a glazed, framed service window.
	box(Vector3(0, 1.37, back), Vector3(span - 1.3, 2.74, 1.95), IVORY, true)
	box(Vector3(0, 2.65, back), Vector3(span - 1.12, 0.18, 2.05), INK)
	box(Vector3(0.55, 1.63, back + 0.99), Vector3(span * 0.55, 1.36, 0.05), GLASS)
	for k: int in 4:
		box(Vector3(0.55 + (k / 3.0 - 0.5) * span * 0.55, 1.63, back + 1.03), Vector3(0.055, 1.4, 0.05), STEEL)
	box(Vector3(0.55, 0.91, back + 1.06), Vector3(span * 0.58, 0.10, 0.17), INK)
	# Canopy, stripe and exposed edge. Supports share the islands; the centre aisle stays clear.
	if station_style == 1:
		# Two detached pump canopies, leaving daylight above the drive between them.
		for side: int in [-1,1]:
			var cx := side * span * 0.245
			var wing := span * 0.40
			box(Vector3(cx,3.94,0.65),Vector3(wing,0.30,d*0.53),IVORY,true)
			box(Vector3(cx,4.19,0.65),Vector3(wing+0.06,0.50,d*0.53+0.06),stripe)
			box(Vector3(cx,3.98,0.65),Vector3(wing+0.08,0.075,d*0.53+0.08),GOLD)
			label("HAYATE" if side < 0 else "SELF  /  24H",Vector3(cx,4.20,0.70+d*0.265),0.34)
	else:
		box(Vector3(0, 3.94, 0.65), Vector3(span, 0.30, d * 0.53), IVORY, true)
		box(Vector3(0, 4.16, 0.65), Vector3(span + 0.06, 0.58, d * 0.53 + 0.06), stripe)
		box(Vector3(0, 3.91, 0.65), Vector3(span + 0.08, 0.07, d * 0.53 + 0.08), GOLD)
		label(brand, Vector3(0, 4.19, 0.70 + d * 0.265), 0.38)
		if station_style == 2:
			# Two tall brick service-bay end walls and a stepped clerestory over the oil shop.
			for end: int in [-1,1]:
				box(Vector3(end*(span*0.5-1.02),2.33,back),Vector3(0.46,4.66,2.08),Color("#915e48"),true)
			box(Vector3(0,3.21,back),Vector3(span-2.1,1.05,1.86),GLASS)
			box(Vector3(0,3.81,back),Vector3(span-1.81,0.18,2.04),INK)
			for k: int in 9:
				box(Vector3((k/8.0-0.5)*(span-2.12),3.21,back+0.96),Vector3(0.13,1.08,0.09),STEEL)
	for side: int in [-1, 1]:
		var x := side * span * 0.245
		box(Vector3(x, 0.10, 0.55), Vector3(1.24, 0.2, 3.05), Color("#bbbbac"), true)
		box(Vector3(x, 1.95, -0.48), Vector3(0.25, 3.85, 0.29), STEEL, true)
		box(Vector3(x, 0.86, 0.97), Vector3(0.81, 1.32, 0.52), stripe, true)
		box(Vector3(x, 1.54, 0.97), Vector3(0.94, 0.59, 0.58), IVORY, true)
		box(Vector3(x, 1.61, 1.27), Vector3(0.58, 0.24, 0.035), INK)
		box(Vector3(x, 1.63, 1.30), Vector3(0.36, 0.09, 0.018), Color("#9ec9af"))
		box(Vector3(x, 1.20, 1.245), Vector3(0.67, 0.12, 0.04), GOLD)
		for h: float in [0.33,0.54]:
			box(Vector3(x + side * h, 0.91, 0.94), Vector3(0.057, 0.78, 0.065), INK)
		box(Vector3(x + side * 0.43, 0.52, 0.94), Vector3(0.26, 0.072, 0.074), INK)
		box(Vector3(x + side * 0.53, 1.30, 0.94), Vector3(0.13, 0.26, 0.12), Color("#467450"))
		for k: int in [-1,1]:
			box(Vector3(x + k * 0.88, 0.024, 0.65), Vector3(0.10, 0.012, 3.55), IVORY)
	# Street pylon is outside the central approach; sign faces approaching traffic both ways.
	var pole := Vector3(w * 0.5 - 1.15, 0, d * 0.5 - 0.62)
	var sign_y := 5.20 if station_style == 1 else 3.90
	box(pole + Vector3.UP * (sign_y * 0.5), Vector3(0.20, sign_y, 0.20), STEEL, true)
	box(pole + Vector3.UP * sign_y, Vector3(2.06, 1.05, 0.24), stripe)
	for face: int in [-1,1]:
		label("FUEL", pole + Vector3(0,sign_y,face * 0.127), 0.49, PI if face < 0 else 0.0)
	box(pole + Vector3.UP * (sign_y - 0.58), Vector3(2.10, 0.10, 0.27), GOLD)
	if station_style == 1:
		box(pole + Vector3.UP * (sign_y-1.57),Vector3(1.85,1.85,0.22),INK)
		for j: int in 3:
			var y := sign_y - 1.02 - 0.49 * j
			box(pole + Vector3(-0.69,y,0.12), Vector3(0.16,0.22,0.03), [RED,GOLD,Color("#42a88b")][j])
			label(["REG  168","HI    179","D     146"][j],pole + Vector3(0.12,y,0.128),0.24)
	# A ribbed soffit, long recessed lamps, fascia divisions and rain downpipes break the
	# bright roof up at walking distance. Nothing hangs low enough to affect the drive.
	for n: int in 7:
		var rib_x := (n/6.0 - 0.5) * (span-0.22)
		if station_style == 1 and (n == 3 or n == 0 or n == 6): continue
		box(Vector3(rib_x,3.772,0.65),Vector3(0.055,0.08,d*0.51),STEEL)
		if n != 3:
			box(Vector3(rib_x,4.17,0.69+d*0.265),Vector3(0.024,0.45,0.022),stripe.darkened(0.30))
	for n: int in [-1,1]:
		box(Vector3(n * span*0.25,3.748,1.85),Vector3(2.02,0.07,0.33),INK)
		box(Vector3(n * span*0.25,3.706,1.85),Vector3(1.86,0.028,0.22),Color("#f9ecd1"))
		box(Vector3(n * (span*0.245+0.22),1.91,-0.52),Vector3(0.10,3.79,0.11),STEEL)
	# Kiosk entrance is recessed visually in a dark frame beside the customer window.
	var door_x := span*0.39
	box(Vector3(door_x,1.10,back+0.997),Vector3(1.25,2.20,0.05),INK)
	box(Vector3(door_x,1.31,back+1.039),Vector3(1.07,1.58,0.035),GLASS)
	box(Vector3(door_x-0.39,1.02,back+1.076),Vector3(0.048,0.32,0.06),IVORY)
	box(Vector3(door_x,2.4,back+1.31),Vector3(1.68,0.10,0.74),stripe)
	box(Vector3(door_x-1.6,0.56,back+1.32),Vector3(0.66,1.12,0.55),RED,true)
	box(Vector3(door_x-1.6,1.18,back+1.32),Vector3(0.75,0.12,0.63),IVORY)
	for panel: int in 4:
		box(Vector3(0.55 + (panel-1.5)*span*0.13,2.12,back+1.055),Vector3(span*0.125,0.18,0.024),GLASS.lightened(0.18))
	# The service window, corrugated shutter and its stock are street-facing; details stay
	# against the kiosk to preserve the two drive lanes. Each trade has a different silhouette.
	var sx := -span * 0.35
	var front := back + 1.03
	box(Vector3(sx,1.19,front),Vector3(3.15,2.35,0.075),INK)
	for j: int in 12:
		box(Vector3(sx,0.20 + j * 0.163,front + 0.055),Vector3(2.95,0.12,0.035),STEEL)
	box(Vector3(sx,2.44,front + 0.11),Vector3(3.42,0.44,0.27),stripe)
	label(["TYRE  /  AIR","PAY  HERE","LUBE  BAY"][station_style],Vector3(sx,2.45,front + 0.255),0.29)
	var meter := Vector3(sx+2.08,0,front+0.45)
	if station_style == 0:
		# Display tyres on a metal rack, with circular holes through the rubber.
		box(Vector3(sx,0.46,front+0.67),Vector3(2.62,0.16,0.62),INK,true)
		for k: int in 3:
			var tyre := TorusMesh.new()
			tyre.inner_radius = 0.205
			tyre.outer_radius = 0.405
			tyre.rings = 18
			tyre.ring_segments = 8
			add_shape(tyre,Transform3D(Basis(Vector3.RIGHT, PI*0.5),Vector3(sx+(k-1)*0.82,0.93,front+0.68)),Color("#262928"))
		box(meter+Vector3.UP*0.65,Vector3(0.30,1.30,0.32),stripe,true)
		box(meter+Vector3.UP*1.32,Vector3(0.52,0.40,0.32),IVORY)
		box(meter+Vector3(0.0,1.32,0.17),Vector3(0.30,0.19,0.04),GLASS)
	elif station_style == 1:
		# Weather hood over the payment terminal.
		box(meter+Vector3.UP*0.95,Vector3(1.0,1.90,0.49),stripe,true)
		box(meter+Vector3(0,1.42,0.255),Vector3(0.67,0.46,0.035),INK)
		box(meter+Vector3(0,1.43,0.28),Vector3(0.52,0.31,0.025),Color("#64aaa4"))
		box(meter+Vector3(0,1.99,0.10),Vector3(1.18,0.10,0.84),IVORY)
	else:
		# Workshop oil drums, with rolled steel hoops.
		for k: int in 3:
			var drum_at := Vector3(sx+(k-1)*0.72,0.48,front+0.57)
			var barrel := CylinderMesh.new()
			barrel.top_radius = 0.28
			barrel.bottom_radius = 0.28
			barrel.height = 0.91
			barrel.radial_segments = 16
			add_shape(barrel, Transform3D(Basis.IDENTITY,drum_at),stripe)
			barrel.top_radius = 0.292
			barrel.bottom_radius = 0.292
			barrel.height = 0.05
			for dy: float in [-0.27,0.22,0.45]:
				add_shape(barrel,Transform3D(Basis.IDENTITY,drum_at+Vector3.UP*dy),IVORY)
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = surface.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.83
	mesh_node.material_override = mat
	add_child(mesh_node)

func box(at: Vector3, size: Vector3, tint: Color, collision := false) -> void:
	add_shape(unit, Transform3D(Basis.from_scale(size), at), tint)
	if collision:
		var shape := BoxShape3D.new()
		shape.size = size
		var node := CollisionShape3D.new()
		node.shape = shape
		node.position = at
		solid.add_child(node)

func add_shape(primitive: PrimitiveMesh, xf: Transform3D, tint: Color) -> void:
	var arr := primitive.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for i: int in arr[Mesh.ARRAY_INDEX]:
		surface.set_color(tint)
		surface.set_normal((xf.basis * norms[i]).normalized())
		surface.add_vertex(xf * verts[i])

func label(words: String, at: Vector3, height: float, angle := 0.0) -> void:
	var letters := Label3D.new()
	letters.text = words
	letters.font_size = 64
	letters.pixel_size = height / 48.0
	letters.outline_size = 0
	letters.double_sided = false
	letters.position = at
	letters.rotation.y = angle
	letters.visibility_range_end = 145
	add_child(letters)

