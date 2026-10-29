extends RefCounted
## Author-built metre-scale upper rooms. Furnish only the two real window bays.
## The street owns every light; this module supplies physical shade/furniture only.

const CHAIR := "res://assets/shinrai/streets/midori_frontage_construction/mori_bentwood_chair.glb"
const FLOOR := 4.05

static func build(street: Node3D, anchor: Node3D, spec: Dictionary) -> void:
	var w := float(spec.w)
	var h := float(spec.eave)
	var top := minf(6.03,h-.38)
	var bottom := 4.10
	var narrow: bool = spec.roof == "cedar_gable"
	var window_width := 1.28 if narrow else w*.285
	_materials(street)
	var mats: Dictionary = street.get("materials")
	var room := Node3D.new()
	room.name = "UpperRoomFurnishings"
	anchor.add_child(room)
	var authored_chairs := 0
	for side: float in [-1.0,1.0]:
		var x := side*w*.25
		var bay := Node3D.new()
		bay.name = "UpperRoomLeftWindow" if side < 0.0 else "UpperRoomRightWindow"
		room.add_child(bay)
		# Original gathered curtains and pendant locations match the existing lights.
		var curtain_x := x+side*(window_width*.5-.26)
		var curtain_top := top-.06
		var curtain_bottom := bottom+.12
		var cloth := SurfaceTool.new()
		cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
		for strip: int in range(18):
			var xa := curtain_x-.19+float(strip)*.38/18.0
			var xb := curtain_x-.19+float(strip+1)*.38/18.0
			var za := .79+.025*cos(float(strip)*PI*.67)
			var zb := .79+.025*cos(float(strip+1)*PI*.67)
			var normal := Vector3(zb-za,0,xa-xb).normalized()
			_quad(cloth,Vector3(xa,curtain_bottom,za),Vector3(xa,curtain_top,za),Vector3(xb,curtain_top,zb),Vector3(xb,curtain_bottom,zb),normal)
		var fabric := MeshInstance3D.new()
		fabric.name = "GatheredLinenSideCurtain"
		fabric.mesh = cloth.commit()
		fabric.material_override = mats["room_linen"]
		bay.add_child(fabric)
		_b(street,bay,"CurtainTrack",Vector3(x,curtain_top+.035,.80),Vector3(window_width-.12,.024,.026),"arch_metal")
		var lamp_y := top-.25
		_b(street,bay,"PendantFlex",Vector3(x,(h-.25+lamp_y+.15)*.5,1.30),Vector3(.006,maxf(.04,h-.25-lamp_y-.15),.006),"arch_metal")
		var shade := MeshInstance3D.new()
		shade.name = "UpperRoomPendantShade"
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = .10
		cylinder.bottom_radius = .16
		cylinder.height = .20
		cylinder.radial_segments = 24
		cylinder.cap_bottom = false
		shade.mesh = cylinder
		shade.position = Vector3(x,lamp_y+.05,1.30)
		shade.material_override = mats["room_lamp_paper"]
		bay.add_child(shade)
		var furniture := Node3D.new()
		furniture.name="HabitableFloorFurniture"
		furniture.position.y=-.75
		bay.add_child(furniture)
		if _furnish(street,furniture,x,side,window_width,String(spec.id),narrow): authored_chairs += 1
	# Existing two front compositions gain a real rear partition and central passage.
	for side: float in [-1.0,1.0]:
		var span: float = w*.5-.70
		_b(street,anchor,"UpperFlatFrontRoomPartition",Vector3(side*(.70+span*.5),4.39,2.40),Vector3(span,2.18,.10),"arch_interior")
		street.call("_solid",anchor,"UpperFlatPartitionCollision",Vector3(side*(.70+span*.5),4.39,2.40),Vector3(span,2.18,.10))
	anchor.set_meta("upper_room_construction",{
		"rooms":2,"curtains":2,"pendants":2,"window_backing":"real interior geometry",
		"furniture_floor_y":FLOOR-.75,"joinery_desks":2,"authored_chairs":authored_chairs,
		"fallback_chairs":2-authored_chairs,
		"compositions_per_room":3,"detail_scheme":String(spec.id),"lights_created":0,
		"chair_source":CHAIR,"batching":"existing recursive street pipeline"
	})

static func _materials(street: Node3D) -> void:
	var mats: Dictionary = street.get("materials")
	for row: Array in [
		["room_linen",Color("#b9b3a1"),.94],
		["room_lamp_paper",Color("#ded3b6"),.86],
		["room_ceramic",Color("#78837a"),.65],
		["room_book_ochre",Color("#9b774a"),.87],
		["room_book_olive",Color("#59634c"),.89],
		["room_book_indigo",Color("#47575d"),.86],
		["room_book_clay",Color("#985e4c"),.90],
		["room_paper",Color("#c9bfa5"),.97],
		["room_soil",Color("#302b21"),1.0],
		["room_leaf",Color("#465b38"),.86],
		["room_leaf_light",Color("#6a794a"),.88]
	]:
		if not mats.has(row[0]): street.call("_material",row[0],row[1],row[2])

static func _furnish(street: Node3D, room: Node3D, x: float, side: float, width: float, scheme: String, narrow: bool) -> bool:
	# Three readable groups: working desk/chair, one rear storage/art group, plant.
	# No geometry occupies the curtain or window recess (z <= 1.0).
	var desk_x := x-side*(.12 if narrow else .36)
	var desk_width := .90 if narrow else 1.16
	_desk(street,room,desk_x,desk_width,side)
	var authored_chair := _chair(street,room,Vector3(desk_x-side*.08,FLOOR,1.99))
	_b(street,room,"RearTimberSkirting",Vector3(x,FLOOR+.055,2.318),Vector3(width+.15,.11,.028),"arch_cedar")
	if scheme == "UedaBooks":
		_shelf(street,room,x+side*.88,.65,1.36,"books")
		_book(street,room,Vector3(desk_x-.15,4.824,1.47),.25,.035,.18,"room_book_indigo",true)
		_b(street,room,"OpenReadingPage",Vector3(desk_x-.15,4.862,1.47),Vector3(.23,.006,.17),"room_paper")
		_plant(street,room,Vector3(desk_x+.34,4.81,1.58),.34)
	elif scheme == "MoriCoffee":
		_shelf(street,room,x+side*.88,.65,.83,"coffee")
		_b(street,room,"Notebook",Vector3(desk_x-.17,4.825,1.47),Vector3(.22,.03,.16),"room_book_olive")
		_cup(street,room,Vector3(desk_x+.20,4.81,1.47))
		_plant(street,room,Vector3(x+side*.88,FLOOR+.83,2.10),.55)
		_frame(street,room,x+side*.88,5.24,.42,.36,"room_book_ochre")
	elif scheme == "HinataDaily":
		_shelf(street,room,x+side*.87,.66,1.12,"linen")
		_b(street,room,"HouseholdLedger",Vector3(desk_x-.16,4.825,1.47),Vector3(.25,.03,.18),"room_book_clay")
		_plant(street,room,Vector3(desk_x+.32,4.81,1.57),.43)
		_frame(street,room,desk_x,5.44,.48,.40,"room_leaf")
	else:
		# The cedar-gable rooms have lower ceilings and 1.28m openings.
		_b(street,room,"WallShelfBoard",Vector3(x,5.14,2.17),Vector3(.87,.028,.30),"arch_pale_wood")
		for dx: float in [-.29,.29]:
			_b(street,room,"WallShelfBracketUpright",Vector3(x+dx,5.055,2.316),Vector3(.024,.17,.028),"arch_metal")
			_b(street,room,"WallShelfBracketArm",Vector3(x+dx,5.075,2.19),Vector3(.024,.022,.27),"arch_metal")
		for dx: float in [-.24,-.07]:
			_cylinder(street,room,"StonewareStorageJar",Vector3(x+dx,5.245,2.16),.065,.055,.18,"room_ceramic")
			_cylinder(street,room,"JarTimberLid",Vector3(x+dx,5.342,2.16),.068,.068,.014,"arch_cedar")
		_plant(street,room,Vector3(x+.24,5.154,2.16),.23)
		_b(street,room,"ClosedHouseLedger",Vector3(desk_x-.19,4.825,1.48),Vector3(.23,.03,.17),"room_book_clay")
		_cup(street,room,Vector3(desk_x+.20,4.81,1.48))
	return authored_chair

static func _desk(street: Node3D, room: Node3D, x: float, width: float, side: float) -> void:
	_b(street,room,"WritingDeskTop",Vector3(x,4.79,1.48),Vector3(width,.04,.50),"arch_pale_wood")
	# 36mm square legs meet the underside; aprons tie the four joints together.
	for dx: float in [-width*.5+.055,width*.5-.055]:
		for z: float in [1.285,1.675]:
			_b(street,room,"WritingDeskLeg",Vector3(x+dx,FLOOR+.36,z),Vector3(.036,.72,.036),"arch_cedar")
		_b(street,room,"DeskSideApron",Vector3(x+dx,4.70,1.48),Vector3(.025,.13,.39),"arch_cedar")
	_b(street,room,"DeskRearApron",Vector3(x,4.70,1.675),Vector3(width-.09,.13,.025),"arch_cedar")
	var drawer_x := x+side*(width*.5-.20)
	_b(street,room,"DeskDrawerCarcase",Vector3(drawer_x,4.67,1.46),Vector3(.30,.17,.40),"arch_cedar")
	_b(street,room,"DeskInsetDrawerFront",Vector3(drawer_x,4.67,1.252),Vector3(.282,.146,.018),"arch_pale_wood")
	for dx: float in [-.042,.042]:
		_b(street,room,"DrawerHandleFixing",Vector3(drawer_x+dx,4.67,1.234),Vector3(.011,.011,.025),"arch_metal")
	_b(street,room,"DeskDrawerPull",Vector3(drawer_x,4.67,1.218),Vector3(.095,.012,.012),"arch_metal")

static func _chair(street: Node3D, room: Node3D, at: Vector3) -> bool:
	if ResourceLoader.exists(CHAIR):
		var scene := load(CHAIR) as PackedScene
		if scene != null:
			var model := scene.instantiate() as Node3D
			model.name = "UpperRoomAuthoredBentwoodChair"
			model.position = at
			model.set_meta("upper_room_chair",{"loaded_authored":true,"source":CHAIR,"scale":1.0})
			room.add_child(model)
			_chair_batch_materials(model)
			return true
	# Asset-independent structural fallback, retaining proper 440mm seat height.
	var fallback := Node3D.new()
	fallback.name = "UpperRoomFallbackChair"
	fallback.set_meta("upper_room_chair",{"loaded_authored":false,"source":"structural fallback","scale":1.0})
	room.add_child(fallback)
	# Keep its geometry in the same existing room batch, while the marker reports status.
	_b(street,room,"ChairSeat",at+Vector3(0,.44,0),Vector3(.40,.028,.38),"arch_cedar")
	for dx: float in [-.16,.16]:
		for z: float in [-.14,.14]:
			_b(street,room,"ChairLeg",at+Vector3(dx,.213,z),Vector3(.028,.426,.028),"arch_cedar")
		_b(street,room,"ChairBackStile",at+Vector3(dx,.60,.15),Vector3(.028,.36,.028),"arch_cedar")
		_b(street,room,"ChairSideStretcher",at+Vector3(dx,.20,0),Vector3(.02,.025,.28),"arch_cedar")
	for y: float in [.61,.75]:
		_b(street,room,"ChairBackRail",at+Vector3(0,y,.15),Vector3(.32,.075,.025),"arch_cedar")
	return false

static func _chair_batch_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null and mesh_node.mesh.get_surface_count() == 1:
			mesh_node.material_override = mesh_node.mesh.surface_get_material(0)
	for child: Node in node.get_children(): _chair_batch_materials(child)

static func _shelf(street: Node3D, room: Node3D, x: float, width: float, height: float, contents: String) -> void:
	var y := FLOOR+.065
	_b(street,room,"CabinetRearPanel",Vector3(x,FLOOR+height*.5,2.315),Vector3(width-.025,height-.02,.025),"arch_cedar")
	for dx: float in [-width*.5+.014,width*.5-.014]:
		_b(street,room,"CabinetSide",Vector3(x+dx,FLOOR+height*.5,2.16),Vector3(.028,height,.30),"arch_cedar")
	for level: int in range(4):
		var shelf_y := y+float(level)*(height-.08)/3.0
		_b(street,room,"CabinetShelfWithFrontEdge",Vector3(x,shelf_y,2.16),Vector3(width-.04,.026,.30),"arch_pale_wood")
		if level == 3: continue
		if contents == "books":
			for i: int in range(5):
				var keys := ["room_book_ochre","room_book_olive","room_book_indigo","room_book_clay"]
				var bh := .20+float((i+level)%3)*.035
				_book(street,room,Vector3(x-width*.5+.10+float(i)*.072,shelf_y+.013,2.12),.055,bh,.20,keys[(i+level)%4],false)
		elif contents == "linen":
			for fold: int in range(2):
				_b(street,room,"FoldedLinen",Vector3(x-.12,shelf_y+.043+float(fold)*.047,2.13),Vector3(.28,.043,.22),"room_linen")
			_cylinder(street,room,"HouseholdCeramicJar",Vector3(x+.19,shelf_y+.10,2.14),.055,.048,.17,"room_ceramic")
		else:
			_book(street,room,Vector3(x-.13,shelf_y+.013,2.12),.14,.045,.20,"room_book_olive",true)
			_cup(street,room,Vector3(x+.13,shelf_y+.013,2.12))

static func _book(street: Node3D, room: Node3D, at: Vector3, width: float, height: float, depth: float, key: String, flat: bool) -> void:
	_b(street,room,"BoundBook",at+Vector3(0,height*.5,0),Vector3(width,height,depth),key)
	if not flat:
		_b(street,room,"BookSpineBand",at+Vector3(0,height*.71,-depth*.5-.001),Vector3(width*.80,.009,.002),"room_paper")

static func _cup(street: Node3D, room: Node3D, at: Vector3) -> void:
	_cylinder(street,room,"CupSaucer",at+Vector3(0,.008,0),.061,.061,.016,"room_ceramic")
	_vessel(street,room,"CeramicCupWithRolledRim",at+Vector3(0,.013,0),.032,.039,.074,.003,"room_paper")
	_cylinder(street,room,"CupDarkInterior",at+Vector3(0,.083,0),.035,.035,.002,"room_soil")
	_b(street,room,"CupHandleTop",at+Vector3(.044,.068,0),Vector3(.025,.012,.012),"room_paper")
	_b(street,room,"CupHandleOuter",at+Vector3(.054,.049,0),Vector3(.012,.038,.012),"room_paper")
	_b(street,room,"CupHandleBottom",at+Vector3(.044,.030,0),Vector3(.025,.012,.012),"room_paper")

static func _frame(street: Node3D, room: Node3D, x: float, y: float, width: float, height: float, ink: String) -> void:
	_b(street,room,"PrintPaper",Vector3(x,y,2.306),Vector3(width,height,.012),"room_paper")
	for side: float in [-1.0,1.0]:
		_b(street,room,"PictureFrameSide",Vector3(x+side*(width*.5+.009),y,2.293),Vector3(.018,height+.036,.027),"arch_cedar")
		_b(street,room,"PictureFrameRail",Vector3(x,y+side*(height*.5+.009),2.293),Vector3(width,.018,.027),"arch_cedar")
	# Three restrained ink fields read as an authored print rather than a blank tile.
	for i: int in range(3):
		_b(street,room,"PrintInkField",Vector3(x-width*.23+float(i)*width*.23,y-height*.12+float(i%2)*height*.18,2.298),Vector3(width*.14,height*(.34-float(i)*.055),.003),ink)

static func _plant(street: Node3D, room: Node3D, base: Vector3, height: float) -> void:
	var pot_h := height*.27
	var radius := height*.19
	var wall := maxf(.0025,radius*.055)
	_vessel(street,room,"InteriorCeramicPlantPotWithOpenRim",base,radius*.75,radius,pot_h,wall,"room_ceramic")
	var soil_y := pot_h-.012
	var soil_radius := lerpf(radius*.75-wall,radius-wall,(soil_y-wall)/(pot_h-.004-wall))*.98
	_cylinder(street,room,"RecessedPotSoil",base+Vector3(0,soil_y,0),soil_radius,soil_radius,.003,"room_soil")
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for branch: int in range(3):
		var angle := float(branch)*TAU/3.0+.4
		var tip := base+Vector3(cos(angle)*height*.12,height*(.88+float(branch)*.06),sin(angle)*height*.12)
		_rod(street,room,"InteriorPlantStem",base+Vector3(0,pot_h,0),tip,.004,"arch_cedar")
		for leaf: int in range(4):
			var t := .40+float(leaf)*.14
			var center := (base+Vector3(0,pot_h,0)).lerp(tip,t)
			var a := angle+float(leaf)*2.4
			var length := height*(.23-float(leaf)*.025)
			var end := center+Vector3(cos(a)*length,length*.32,sin(a)*length)
			var spread := Vector3(-sin(a),.16,cos(a))*length*.24
			var middle := center.lerp(end,.48)
			var normal := (end-center).cross(spread).normalized()
			_quad(mesh,center,middle+spread,end,middle-spread,normal)
	var foliage := MeshInstance3D.new()
	foliage.name = "InteriorPlantLeafSilhouette"
	foliage.mesh = mesh.commit()
	var mats: Dictionary = street.get("materials")
	var material := mats["room_leaf"] as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	foliage.material_override = material
	room.add_child(foliage)

static func _vessel(street: Node3D, room: Node3D, label: String, base: Vector3, bottom_radius: float, top_radius: float, height: float, wall: float, key: String) -> void:
	# A continuous lathe profile forms the base, tapered outer wall, annular lip,
	# inner wall and inner floor. The opening contains no cap or solid rim disk.
	var profile: Array[Vector2] = [
		Vector2(0,0),Vector2(bottom_radius,0),
		Vector2(top_radius,height-.007),Vector2(top_radius+.002,height-.003),
		Vector2(top_radius+.002,height+.002),Vector2(top_radius-wall,height+.002),
		Vector2(top_radius-wall,height-.004),Vector2(bottom_radius-wall,wall),Vector2(0,wall)
	]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment: int in range(24):
		var angle_a := float(segment)*TAU/24.0
		var angle_b := float(segment+1)*TAU/24.0
		var middle := (angle_a+angle_b)*.5
		for edge: int in range(profile.size()-1):
			var low := profile[edge]
			var high := profile[edge+1]
			var normal := Vector3(cos(middle)*(high.y-low.y),low.x-high.x,sin(middle)*(high.y-low.y)).normalized()
			_quad(tool,
				Vector3(cos(angle_a)*low.x,low.y,sin(angle_a)*low.x),
				Vector3(cos(angle_a)*high.x,high.y,sin(angle_a)*high.x),
				Vector3(cos(angle_b)*high.x,high.y,sin(angle_b)*high.x),
				Vector3(cos(angle_b)*low.x,low.y,sin(angle_b)*low.x),normal)
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = tool.commit()
	node.position = base
	var mats: Dictionary = street.get("materials")
	node.material_override = mats[key]
	room.add_child(node)

static func _rod(street: Node3D, room: Node3D, label: String, a: Vector3, b: Vector3, radius: float, key: String) -> void:
	var node := _cylinder(street,room,label,(a+b)*.5,radius,radius,a.distance_to(b),key)
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

static func _cylinder(street: Node3D, parent: Node3D, label: String, position: Vector3, top: float, bottom: float, height: float, key: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = position
	var mats: Dictionary = street.get("materials")
	node.material_override = mats[key]
	parent.add_child(node)
	return node

static func _b(street: Node3D, parent: Node3D, label: String, position: Vector3, size: Vector3, key: String) -> void:
	street.call("_box",parent,label,position,size,key,false)

static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	var vertices := [a,b,c,a,c,d]
	if (b-a).cross(c-a).dot(normal) > 0.0: vertices = [a,c,b,a,d,c]
	for vertex: Vector3 in vertices:
		tool.set_normal(normal)
		tool.set_uv(Vector2(vertex.x,vertex.y))
		tool.add_vertex(vertex)
