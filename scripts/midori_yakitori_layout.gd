extends RefCounted
## Shop-local visual layout; floor top Y=.11. No collision or lights.
const Details = preload("res://scripts/midori_south_street_details.gd")
const Interiors = preload("res://scripts/midori_shop_interiors.gd")

static func build(street: Node3D, shop: Node3D, root: Node3D) -> Dictionary:
	var fixtures: Array[Dictionary] = []
	var counter := _fixture(root,fixtures,"SixSeatDiningCounter",Rect2(.06,2.0,.84,4.3),"customer_counter")
	_b(street,counter,"SolidTimberCountertop",Vector3(.575,1.075,4.15),Vector3(.65,.07,4.3),"detail_wood")
	# Staff-side cupboards and narrow bearer leave an honest knee recess.
	for z: float in [2.22,4.15,6.08]:
		_b(street,counter,"CounterEndSupport",Vector3(.74,.575,z),Vector3(.25,.93,.10),"detail_darkwood")
	_b(street,counter,"CounterStaffSidePanel",Vector3(.845,.575,4.15),Vector3(.025,.93,4.10),"detail_darkwood")
	_b(street,counter,"CounterLongitudinalBearer",Vector3(.61,.995,4.15),Vector3(.38,.09,4.12),"detail_darkwood")
	Details._rod(street,counter,"CustomerBrassFootrail",Vector3(.08,.33,2.14),Vector3(.08,.33,6.16),.018,"detail_metal")
	for z: float in [2.20,4.15,6.10]:
		Details._rod(street,counter,"FootrailBracket",Vector3(.08,.33,z),Vector3(.74,.33,z),.012,"detail_metal")
	for i: int in range(6):
		var z := 2.50+float(i)*.65
		var stool := _fixture(root,fixtures,"DiningStool%d"%i,Rect2(-.47,z-.22,.44,.44),"customer_seat_facing_positive_x")
		Details._cylinder(street,stool,"RoundTimberSeat",Vector3(-.25,.805,z),.215,.055,"detail_wood")
		for dx: float in [-.13,.13]:
			for dz: float in [-.13,.13]:
				Details._rod(street,stool,"StoolSplayedLeg",Vector3(-.25+dx*1.25,.11,z+dz*1.25),Vector3(-.25+dx,.778,z+dz),.018,"detail_darkwood")
		for dx: float in [-.16,.16]:
			Details._rod(street,stool,"StoolFootRest",Vector3(-.25+dx,.34,z-.16),Vector3(-.25+dx,.34,z+.16),.011,"detail_metal")
		_plate(street,counter,Vector3(.48,1.110,z))
		_cup(street,counter,Vector3(.72,1.110,z+.18))
		for dz: float in [-.016,.016]:
			_b(street,counter,"Chopstick",Vector3(.47,1.128,z+.17+dz),Vector3(.20,.006,.006),"detail_darkwood")
	var prep := _fixture(root,fixtures,"StaffPrepAndWashRun",Rect2(2.04,2.5,.48,1.75),"staff_prep_sink")
	_cabinet(street,prep,3.375,1.75)
	# Worktop made as four rim pieces around a real open sink void.
	_b(street,prep,"PrepTop",Vector3(2.28,1.025,2.86),Vector3(.48,.04,.72),"detail_metal")
	for x: float in [2.065,2.495]:
		_b(street,prep,"SinkTopRimSide",Vector3(x,1.025,3.72),Vector3(.05,.04,.94),"detail_metal")
	for z: float in [3.28,4.19]:
		_b(street,prep,"SinkTopRimEnd",Vector3(2.28,1.025,z),Vector3(.38,.04,.06),"detail_metal")
	_b(street,prep,"SinkBasinBottom",Vector3(2.28,.855,3.73),Vector3(.38,.018,.82),"detail_metal")
	for x: float in [2.095,2.465]:
		_b(street,prep,"SinkBasinSide",Vector3(x,.94,3.73),Vector3(.018,.17,.82),"detail_metal")
	for z: float in [3.33,4.13]:
		_b(street,prep,"SinkBasinEnd",Vector3(2.28,.94,z),Vector3(.38,.17,.018),"detail_metal")
	Details._rod(street,prep,"TapUpright",Vector3(2.46,1.045,3.80),Vector3(2.46,1.32,3.80),.012,"detail_metal")
	Details._rod(street,prep,"TapSpout",Vector3(2.46,1.32,3.80),Vector3(2.20,1.32,3.80),.012,"detail_metal")
	_b(street,prep,"CuttingBoard",Vector3(2.27,1.057,2.89),Vector3(.34,.025,.44),"detail_wood")
	var grill := _fixture(root,fixtures,"CharcoalYakitoriGrillAndExtract",Rect2(2.04,4.45,.48,1.85),"staff_grill")
	_cabinet(street,grill,5.375,1.85)
	_b(street,grill,"FireboxBase",Vector3(2.28,1.045,5.375),Vector3(.45,.025,1.80),"detail_metal")
	for x: float in [2.055,2.505]:
		_b(street,grill,"FireboxLip",Vector3(x,1.13,5.375),Vector3(.025,.17,1.82),"detail_metal")
	for z: float in [4.475,6.275]:
		_b(street,grill,"FireboxEnd",Vector3(2.28,1.13,z),Vector3(.45,.17,.025),"detail_metal")
	for i: int in range(15):
		var z := 4.54+float(i)*.119
		Details._rod(street,grill,"ActualGrillGrate",Vector3(2.07,1.21,z),Vector3(2.49,1.21,z),.006,"detail_metal")
	for x: float in [2.10,2.46]:
		Details._rod(street,grill,"GrateLongRail",Vector3(x,1.21,4.50),Vector3(x,1.21,6.25),.009,"detail_metal")
	for i: int in range(7):
		var z := 4.70+float(i)*.20
		Details._rod(street,grill,"BambooYakitoriSkewer",Vector3(2.035,1.238,z),Vector3(2.47,1.238,z),.004,"detail_wood")
		for x: float in [2.17,2.27,2.37]:
			Details._soft_block(street,grill,"GrilledChickenPiece",Vector3(x,1.262,z),Vector3(.065,.045,.07),"detail_cake")
	# Folded sheet hood, open underside, grease baffles and a connected riser.
	_b(street,grill,"ExtractHoodTop",Vector3(2.225,2.43,5.375),Vector3(.575,.025,2.02),"detail_metal")
	for x: float in [1.95,2.50]:
		_b(street,grill,"ExtractHoodFoldedSide",Vector3(x,2.32,5.375),Vector3(.025,.22,2.02),"detail_metal")
	for z: float in [4.365,6.385]:
		_b(street,grill,"ExtractHoodEnd",Vector3(2.225,2.32,z),Vector3(.575,.22,.025),"detail_metal")
	for z: float in [4.7,5.05,5.4,5.75,6.1]:
		_b(street,grill,"HoodGreaseBaffle",Vector3(2.25,2.38,z),Vector3(.50,.025,.23),"detail_ink")
	_b(street,grill,"ExtractDuctToCeiling",Vector3(2.31,2.72,5.375),Vector3(.32,.55,.40),"detail_metal")
	var rack := _fixture(root,fixtures,"PrepWallDishRack",Rect2(2.23,2.50,.30,1.65),"overhead_staff_storage")
	for y: float in [1.56,1.95]:
		_b(street,rack,"WallRackShelf",Vector3(2.385,y,3.30),Vector3(.29,.025,1.60),"detail_wood")
		for z: float in [2.60,4.0]:
			_b(street,rack,"ShelfWallPlate",Vector3(2.52,y-.07,z),Vector3(.02,.16,.035),"detail_metal")
			_b(street,rack,"ShelfSupport",Vector3(2.39,y-.025,z),Vector3(.27,.025,.025),"detail_metal")
	for i: int in range(5):
		_plate(street,rack,Vector3(2.36,1.573+float(i)*.012,2.75))
		_cup(street,rack,Vector3(2.36,1.963,3.13+float(i)*.16))
	var stock := _fixture(root,fixtures,"RearStockCupboard",Rect2(1.72,7.31,.78,.28),"rear_stock")
	for y: float in [.30,.82,1.34,1.86]:
		_b(street,stock,"StockShelf",Vector3(2.11,y,7.45),Vector3(.78,.025,.28),"detail_wood")
	for x: float in [1.73,2.49]:
		_b(street,stock,"StockUpright",Vector3(x,1.0,7.45),Vector3(.025,1.78,.28),"detail_darkwood")
	for x: float in [1.87,2.13,2.37]:
		Details._jar(street,stock,Vector3(x,.832,7.45),0)
	var door := _fixture(root,fixtures,"RearServiceDoor",Rect2(-.50,7.66,1.0,.055),"visual_service_door")
	_b(street,door,"ServiceDoorLeaf",Vector3(0,1.16,7.69),Vector3(.91,2.10,.035),"detail_darkwood")
	for x: float in [-.49,.49]:
		_b(street,door,"ServiceDoorJamb",Vector3(x,1.18,7.675),Vector3(.055,2.14,.065),"detail_wood")
	_b(street,door,"ServiceDoorLintel",Vector3(0,2.25,7.675),Vector3(1.035,.06,.065),"detail_wood")
	_b(street,door,"ServiceDoorHandle",Vector3(.34,1.14,7.64),Vector3(.025,.14,.035),"detail_metal")
	# Translation preserves sink depth, cabinet engineering and round crockery.
	counter.position.x = -.15
	for child: Node in root.get_children():
		if child is Node3D and str(child.name).begins_with("DiningStool"):
			(child as Node3D).position.x = -.15
	for assembly: Node3D in [prep,grill,rack,stock]:
		assembly.position.x = -.24
	# Bounds are measured from actual transformed visual members, including
	# counter footrail and overhead extraction rather than a guessed footprint.
	for fixture: Dictionary in fixtures:
		var assembly := root.get_node(String(fixture["name"])) as Node3D
		var fitted := _visual_bounds(assembly)
		assembly.set_meta("fixture_bounds",fitted)
		fixture["bounds"] = fitted
	return {"ok":true,"name":str(shop.name),"fixtures":fixtures,"clear_routes":[Rect2(-2.1,0,1.1,7.3),Rect2(-1.0,0,3.0,1.7),Rect2(.83,1.7,.95,5.35),Rect2(-1.0,6.45,2.48,.86)],"staff_route":Rect2(.83,1.7,.95,5.35),"customer_route":Rect2(-2.1,0,1.1,7.3),"lights_created":0,"collision_created":false,"seat_count":6,"floor_top_y":.11}

static func _visual_bounds(group: Node3D) -> Rect2:
	var points: Array[Vector3] = []
	_collect_points(group,Transform3D.IDENTITY,points)
	var result := Rect2(Vector2(points[0].x,points[0].z),Vector2.ZERO)
	for p: Vector3 in points:
		result = result.expand(Vector2(p.x,p.z))
	return result

static func _collect_points(node: Node3D, ancestor: Transform3D, points: Array[Vector3]) -> void:
	var current := ancestor * node.transform
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		var box := visual.get_aabb()
		for i: int in range(8):
			points.append(current * box.get_endpoint(i))
	for child: Node in node.get_children():
		if child is Node3D: _collect_points(child as Node3D,current,points)

static func _fixture(root: Node3D, fixtures: Array[Dictionary], label: String, bounds: Rect2, role: String) -> Node3D:
	var group := Node3D.new()
	group.name = label
	group.set_meta("fixture_bounds",bounds)
	group.set_meta("fixture_role",role)
	root.add_child(group)
	fixtures.append({"name":label,"node_path":str(root.get_path())+"/"+label,"bounds":bounds,"role":role})
	return group

static func _b(street: Node3D, parent: Node3D, label: String, pos: Vector3, size: Vector3, key: String) -> MeshInstance3D:
	return Details._b(street,parent,label,pos,size,key)

static func _cabinet(street: Node3D, parent: Node3D, z: float, length: float) -> void:
	var cabinet := Node3D.new()
	cabinet.name = "StaffFacingConstructedCabinet"
	cabinet.position = Vector3(2.28,0,z)
	cabinet.rotation.y = PI*.5
	parent.add_child(cabinet)
	Interiors._cabinet(street,cabinet,Vector3(0,.555,0),Vector3(length,.89,.44),true)

static func _plate(street: Node3D, parent: Node3D, pos: Vector3) -> void:
	Details._lathe(street,parent,"OpenCeramicServingDish",[Vector2(0,0),Vector2(.055,0),Vector2(.105,.012),Vector2(.12,.025),Vector2(.115,.030),Vector2(.095,.020),Vector2(0,.009)],pos,1.0,"detail_ceramic")

static func _cup(street: Node3D, parent: Node3D, pos: Vector3) -> void:
	Details._lathe(street,parent,"OpenSakeCup",[Vector2(0,0),Vector2(.020,0),Vector2(.032,.045),Vector2(.030,.052),Vector2(.025,.052),Vector2(.018,.008),Vector2(0,.008)],pos,1.0,"detail_ceramic")
