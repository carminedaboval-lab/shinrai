extends "district_geometry.gd"
## A bounded, walkable district around the existing Cantilever Command tower.
var pavement:StandardMaterial3D
var asphalt:Material
var pale:StandardMaterial3D
var dark:StandardMaterial3D
var white:StandardMaterial3D
var cyan:StandardMaterial3D
var amber:StandardMaterial3D
var leaf:StandardMaterial3D
var garage:Node3D
var police:Node3D
var context_buildings := 0
var _street_lights:Array[OmniLight3D]=[]

func _ready() -> void:
	add_to_group("cantilever_district")
	pavement=mat(Color("65706f"),.93)
	asphalt=mat(Color("29323b"),.89)
	pale=mat(Color("a7b2b1"),.84)
	dark=mat(Color("243643"),.55)
	white=mat(Color("d4d6cb"),.8)
	cyan=mat(Color("64e3f4"),.45,1.3)
	amber=mat(Color("f9bd69"),.6,.65)
	leaf=mat(Color("354d40"),.95)
	_build_streets()
	_build_plazas()
	_build_neighbourhood()
	_build_street_details()
	garage=load("res://assets/shinrai/districts/corporate_command/corporate_garage.tscn").instantiate()
	garage.position=Vector3(83,0,0); garage.name="CorporateGarage"; add_child(garage)
	police=load("res://assets/shinrai/districts/corporate_command/police_station.tscn").instantiate()
	police.position=Vector3(-83,0,0); police.name="PoliceStation"; add_child(police)
	print("CORPORATE_DISTRICT_READY context_buildings=",context_buildings," garage_levels=3 police_station=1 geometry=",geometry_count," colliders=",collider_count)

func _build_streets() -> void:
	# Flush crossings keep the 1.8m player capsule moving without curb-jump tricks.
	for x in [-51.5,51.5]:
		slab("NorthSouthRoad",x-6,x+6,-124,124,-.018,asphalt,.035)
		for z in range(-119,120,8):
			if absf(z-55)<11 or absf(z+50)<11: continue
			box("LaneCentre",Vector3(.13,.015,3.1),Vector3(x,-.001,z),amber,false)
		for side in [-1.0,1.0]:
			slab("NorthSouthSidewalk",x+side*8-1.9,x+side*8+1.9,-124,124,0,pavement,.04)
	for z in [-50.0,55.0]:
		slab("DistrictAvenue",-148,148,z-6,z+6,-.015,asphalt,.04)
		for x in range(-144,145,8):
			if absf(absf(x)-51.5)<11: continue
			box("AvenueCentre",Vector3(3.1,.015,.13),Vector3(x,.001,z),amber,false)
		for side in [-1.0,1.0]:
			slab("AvenueSidewalk",-148,148,z+side*8-1.9,z+side*8+1.9,0,pavement,.04)
	for x in [-51.5,51.5]:
		_crossing(Vector3(x,.01,34),false)
		for z in [-50.0,55.0]:
			_crossing(Vector3(x-9.7,.01,z),true)
			_crossing(Vector3(x+9.7,.01,z),true)
	# Garage drive: a clear apron joins the street without intersecting walking bays.
	slab("GarageAccessDrive",76,90,22,49,-.012,asphalt,.04)
	for x in [76.4,89.6]: box("DriveEdge",Vector3(.12,.02,25),Vector3(x,.006,35.5),white,false)
	for z in [40.0,44.0]: _road_arrow(Vector3(80,.012,z),0)
	_road_arrow(Vector3(86,.012,42),PI)
	_crossing(Vector3(83,.013,34),false)
	# Police side court has its own approach, kept separate from the public door.
	slab("PolicePatrolDrive",-71,-61,18,49,-.012,asphalt,.04)
	_crossing(Vector3(-66,.014,34),false,10)

func _crossing(at:Vector3,rotate90:bool,width:float=12) -> void:
	for i in range(int(width/1.4)):
		var offset:float=-width*.5+.5+i*1.4
		var size := Vector3(.7,.018,3.4) if not rotate90 else Vector3(3.4,.018,.7)
		var p := at+Vector3(offset,0,0) if not rotate90 else at+Vector3(0,0,offset)
		box("PedestrianCrossing",size,p,white,false)

func _road_arrow(at:Vector3,yaw:float) -> void:
	var forward := Vector3(sin(yaw),0,cos(yaw))
	var sideways := Vector3(forward.z,0,-forward.x)
	beam("DirectionArrow",at-forward*1.5,at+forward*1.5,.12,white)
	beam("DirectionArrow",at+forward*1.5,at+sideways*.75+forward*.5,.12,white)
	beam("DirectionArrow",at+forward*1.5,at-sideways*.75+forward*.5,.12,white)

func _build_plazas() -> void:
	# The central strip is a continuous pedestrian route between all three sites.
	for bounds in [Vector2(-113,-57.5),Vector2(-45.5,45.5),Vector2(57.5,114)]:
		slab("DistrictPedestrianSpine",bounds.x,bounds.y,30,38,0,pavement,.045)
	# Soft landscape defines the blocks, leaving the tower front and ladder clear.
	for area in [Rect2(-35,72,70,40),Rect2(-35,-113,70,47)]:
		slab("PocketGarden",area.position.x,area.end.x,area.position.y,area.end.y,.015,leaf,.08)
		for x in [-29.0,29.0]:
			for z in [area.position.y+7,area.end.y-7]: tree(Vector3(x,.02,z),1.4)
		var path_z:float=area.position.y+area.size.y*.5
		slab("GardenWalk",-35,35,path_z-2,path_z+2,.025,pavement,.06)
		for x in [-23.0,-9.0,9.0,23.0]: _bench(Vector3(x,.03,path_z+5),PI)
	# Low water table and sculptural fins in the southern lunch garden.
	slab("GardenWaterBasin",-6,6,98,105,.08,dark,.18)
	slab("StillWater",-5.7,5.7,98.3,104.7,.12,mat(Color("315768"),.12),.03)
	for x in [-2.0,0.0,2.0]:
		var fin := box("GardenSculpture",Vector3(.25,4.2,1.1),Vector3(x,2.2,101.5),pale,false)
		fin.rotation.z=.24
	for x in [-34.0,34.0]:
		for z in [41.5,-40.0]:
			box("TowerTreePlanter",Vector3(5,.35,3),Vector3(x,.17,z),dark)
			tree(Vector3(x,.36,z),1.35)
	_direction_sign(Vector3(30,0,35.5),"POLICE  <     COMMAND     >  PARKING","PARKING  <     COMMAND     >  POLICE")
	_direction_sign(Vector3(-30,0,35.5),"POLICE  <     PUBLIC WALK     >  P","P  <     PUBLIC WALK     >  POLICE")

func _build_neighbourhood() -> void:
	# Modest neighbours keep the 55m cantilever as the district landmark.
	_build_block(Vector3(-106,0,88),Vector3(34,18,34),"AOBA RESIDENCES",Color("aaafa5"),PI,0)
	_build_block(Vector3(-72,0,91),Vector3(22,13,28),"MORI CLINIC",Color("849692"),PI,1)
	_build_block(Vector3(77,0,90),Vector3(26,17,34),"KASUMI WORKS",Color("82959e"),PI,2)
	_build_block(Vector3(112,0,88),Vector3(31,23,37),"HIKARI LIVING",Color("aab0ad"),PI,3)
	_build_block(Vector3(-108,0,-88),Vector3(33,24,34),"NORTH COURT",Color("82918c"),0,4)
	_build_block(Vector3(-74,0,-87),Vector3(22,16,31),"YORU STUDIO",Color("938e83"),0,5)
	_build_block(Vector3(76,0,-87),Vector3(25,21,33),"SHIRO LABS",Color("939eaa"),0,6)
	_build_block(Vector3(111,0,-89),Vector3(30,16,36),"MINATO HOMES",Color("c1b4a1"),0,7)
	_build_block(Vector3(-132,0,-19),Vector3(18,12,39),"EVERYDAY MARKET",Color("a09d8c"),PI*.5,8)
	_build_block(Vector3(-132,0,24),Vector3(18,9,30),"NEIGHBOURHOOD CAFE",Color("ab9985"),PI*.5,9)
	_build_block(Vector3(134,0,-20),Vector3(18,20,36),"SORA APARTMENTS",Color("8c9c9a"),-PI*.5,10)
	_build_block(Vector3(134,0,24),Vector3(18,12,30),"CORPORATE SERVICES",Color("aba9a1"),-PI*.5,11)

func _build_block(at:Vector3,size:Vector3,title:String,tone:Color,yaw:float,seed_id:int) -> void:
	context_buildings+=1
	var facade := mat(tone,.87)
	var glass := mat(Color("243c49"),.27)
	var warm := mat(Color("cfaa73"),.65,.38)
	var shop := mat(Color("9c8e70"),.72,.18)
	box("NeighbourBuilding",size,at+Vector3.UP*(size.y*.5),facade)
	box("RecessedShopBase",Vector3(size.x+.1,3.6,size.z+.1),at+Vector3.UP*1.8,dark,false)
	box("RoofCap",Vector3(size.x+.7,.32,size.z+.7),at+Vector3.UP*(size.y+.16),pale,false)
	for xside in [-1.0,1.0]:
		box("CornerPier",Vector3(.45,size.y,.5),at+Vector3(xside*(size.x*.5-.3),size.y*.5,size.z*.5+.08),dark,false)
	var floors := int(floor((size.y-3.8)/3.4))
	for row in range(floors):
		var y:float=5.1+row*3.4
		for side in [-1.0,1.0]:
			for col in range(int((size.x-2)/3.6)):
				var x:float=-size.x*.5+2.5+col*3.6
				box("WindowBay",Vector3(2.7,2.0,.13),at+Vector3(x,y,side*(size.z*.5+.08)),warm if (col+row*3+seed_id)%5==0 else glass,false)
			box("FloorRibbon",Vector3(size.x+.25,.12,.3),at+Vector3(0,y-1.2,side*(size.z*.5+.1)),dark,false)
			for col in range(int((size.z-2)/3.6)):
				var z:float=-size.z*.5+2.5+col*3.6
				box("SideWindowBay",Vector3(.13,2.0,2.7),at+Vector3(side*(size.x*.5+.08),y,z),warm if (col*2+row+seed_id)%6==0 else glass,false)
	var front := Vector3(sin(yaw),0,cos(yaw))
	var width:float=size.x if absf(front.z)>.5 else size.z
	var depth:float=size.z if absf(front.z)>.5 else size.x
	var centre := at+front*(depth*.5+.18)
	var sideways := Vector3(cos(yaw),0,-sin(yaw))
	# Residential balconies and commercial fins break up the repeated bay rhythm.
	if seed_id in [0,3,7,10]:
		for row in range(floors):
			for col in range(int(width/7.2)):
				var p := centre+sideways*(-width*.5+4.3+col*7.2)+Vector3.UP*(3.9+row*3.4)
				var balcony := box("ResidentialBalcony",Vector3(3.2,.16,1.2),p+front*.45,pale,false)
				balcony.rotation.y=yaw
				beam("BalconyTopRail",p-sideways*1.5+front+Vector3.UP*1.05,p+sideways*1.5+front+Vector3.UP*1.05,.055,dark)
				beam("BalconyMidRail",p-sideways*1.5+front+Vector3.UP*.55,p+sideways*1.5+front+Vector3.UP*.55,.035,dark)
				for edge in [-1.5,1.5]:
					box("BalconyPost",Vector3(.055,1.1,.055),p+sideways*edge+front+Vector3.UP*.55,dark,false)
	else:
		for edge in [-.42,.42]:
			var fin := box("CommercialFacadeBlade",Vector3(.25,size.y-3.8,.8),centre+sideways*(width*edge)+Vector3.UP*((size.y+3.8)*.5),facade,false)
			fin.rotation.y=yaw+.18
	var bar := box("ShopSignFascia",Vector3(width*.86,.9,.18),centre+Vector3.UP*3.1,dark,false)
	bar.rotation.y=yaw
	sign_text(title,centre+front*.16+Vector3.UP*3.15,yaw,width*.7,Color("dcebe2"))
	for i in range(int(width/4)-1):
		var shop_x:float=-width*.5+4+i*4
		var pane := box("RetailGlazing",Vector3(3.25,2.1,.15),centre+sideways*shop_x+Vector3.UP*1.45,shop,false)
		pane.rotation.y=yaw
	var awning := box("ContinuousAwning",Vector3(width+.5,.18,1.9),centre+front*.6+Vector3.UP*3.85,facade,false)
	awning.rotation.y=yaw
	for i in range(3):
		box("RooftopMechanical",Vector3(2.3,1.1,2.8),at+Vector3(-size.x*.3+i*3.8,size.y+.8,0),dark,false)
	for side in [-1.0,1.0]:
		box("RoofParapet",Vector3(size.x,.5,.2),at+Vector3(0,size.y+.48,side*(size.z*.5-.15)),facade,false)
		box("RoofParapetReturn",Vector3(.2,.5,size.z),at+Vector3(side*(size.x*.5-.15),size.y+.48,0),facade,false)
	box("RoofAccessHouse",Vector3(3.4,2.3,4.4),at+Vector3(size.x*.28,size.y+1.45,-size.z*.24),facade,false)
	for i in range(4):
		var solar := box("NeighbourSolarPanel",Vector3(2.1,.09,3.4),at+Vector3(-size.x*.3+i*2.4,size.y+.62,size.z*.25),glass,false)
		solar.rotation.x=-.15
	var strip := box("NeighbourAccent",Vector3(width*.55,.06,.07),centre+front*.2+Vector3.UP*3.66,cyan if seed_id%3==0 else amber,false)
	strip.rotation.y=yaw

func _build_street_details() -> void:
	for x in [-61.0,-42.0,42.0,61.0]:
		for z in [-109.0,-67.0,-28.0,19.0,74.0,113.0]:
			if absf(x)==61 and absf(z)<30: continue
			_street_lamp(Vector3(x,0,z))
	for z in [-60.0,65.0]:
		for x in [-134.0,-100.0,-25.0,25.0,100.0,134.0]:
			_street_lamp(Vector3(x,0,z))
	for x in [-113.0,115.0]:
		for z in [-30.0,-13.0,5.0,22.0,42.0]:
			box("StreetPlanter",Vector3(2.5,.45,2.5),Vector3(x,.2,z),dark)
			tree(Vector3(x,.45,z),1.1)
	# Bus shelter, cycle parking and utility details sit beyond the crossing spine.
	_bus_stop(Vector3(15,0,65))
	for x in [19.0,20.2,21.4,22.6,23.8]:
		beam("CycleStand",Vector3(x,.02,39.5),Vector3(x,.85,39.5),.06,dark)
		beam("CycleStand",Vector3(x,.85,39.5),Vector3(x,.85,41),.06,dark)
		beam("CycleStand",Vector3(x,.85,41),Vector3(x,.02,41),.06,dark)
	for x in [-27.0,28.0]:
		box("PublicBin",Vector3(.65,1,.65),Vector3(x,.5,39.5),dark)
	for at in [Vector3(-112,0,47),Vector3(112,0,-42),Vector3(-32,0,-60)]:
		box("StreetUtility",Vector3(1.2,1.5,.6),at+Vector3.UP*.75,pale)
	# Static street vehicles suggest daily use without implying traffic simulation.
	parked_car(Vector3(-137,0,43),Color("c1c5c3"),PI*.5)
	parked_car(Vector3(-121,0,43),Color("485e72"),PI*.5)
	parked_car(Vector3(119,0,-38),Color("87968c"),-PI*.5)
	parked_car(Vector3(133,0,-38),Color("c2aa83"),-PI*.5)
	for z in [-50.0,55.0]:
		for x in [-51.5,51.5]: _junction_sign(Vector3(x+9,0,z-9))

func _street_lamp(at:Vector3) -> void:
	box("StreetLightPole",Vector3(.13,6.1,.13),at+Vector3.UP*3.05,dark,false)
	box("StreetLightHead",Vector3(1.5,.12,.5),at+Vector3(0,6.15,0),pale,false)
	box("StreetLightLens",Vector3(1.25,.04,.35),at+Vector3(0,6.07,0),mat(Color("c6e1e4"),.5,1.1),false)
	_street_lights.append(light(at+Vector3.UP*5.85,Color("cadde4"),3.5,14,false))

func _bench(at:Vector3,yaw:float) -> void:
	var seat := box("PublicBench",Vector3(2.6,.15,.65),at+Vector3.UP*.49,mat(Color("8b7151"),.9))
	seat.rotation.y=yaw
	for dx in [-1.0,1.0]: box("BenchLeg",Vector3(.15,.42,.5),at+Vector3(dx,.21,0),dark,false)

func _direction_sign(at:Vector3,text:String,back_text:String) -> void:
	for dx in [-2.2,2.2]:
		box("WayfindingPost",Vector3(.08,2.7,.08),at+Vector3(dx,1.35,0),pale,false)
	box("WayfindingBoard",Vector3(4.9,.48,.05),at+Vector3.UP*2.42,dark,false)
	sign_text(text,at+Vector3(0,2.42,.035),0,4.6,Color("c7eee8"))
	sign_text(back_text,at+Vector3(0,2.42,-.035),PI,4.6,Color("c7eee8"))

func _junction_sign(at:Vector3) -> void:
	box("JunctionPole",Vector3(.1,3.3,.1),at+Vector3.UP*1.65,dark,false)
	box("JunctionPanel",Vector3(3.2,.65,.15),at+Vector3.UP*3,pale,false)
	sign_text("COMMAND AVENUE",at+Vector3(0,3,.1),0,2.9,Color("163b50"))

func _bus_stop(at:Vector3) -> void:
	box("BusShelterRoof",Vector3(7,.15,2.6),at+Vector3.UP*2.7,dark,false)
	for x in [-3.2,3.2]: box("BusShelterPost",Vector3(.1,2.7,.1),at+Vector3(x,1.35,0),pale)
	_bench(at+Vector3(0,0,.4),PI)
	box("BusStopDisplay",Vector3(.8,1.4,.15),at+Vector3(2.7,1.5,.7),dark,false)
	sign_text("COMMAND\nLOCAL 04",at+Vector3(2.7,1.5,.81),0,.68,Color("b9f4ea"))
	sign_text("CORPORATE DISTRICT",at+Vector3(0,2.5,-1.32),PI,5.8,Color("dfebdf"))

func get_route_waypoints(route:String) -> Array[Vector3]:
	var points:Array[Vector3]=[]
	if route in ["tower_to_garage","garage_to_tower"]:
		points=[Vector3(20.15,0,27.5),Vector3(20.15,0,34),Vector3(83,0,34),Vector3(83,0,27)]
	elif route in ["tower_to_police","police_to_tower"]:
		points=[Vector3(20.15,0,27.5),Vector3(20.15,0,34),Vector3(-87,0,34),Vector3(-87,0,24)]
	if route in ["garage_to_tower","police_to_tower"]: points.reverse()
	var world_points:Array[Vector3]=[]
	for p in points: world_points.append(to_global(p))
	return world_points

func get_spawn(name:String) -> Vector3:
	match name:
		"district": return to_global(Vector3(20.15,.12,36))
		"garage": return to_global(Vector3(83,.12,28))
		"police": return to_global(Vector3(-87,.12,25))
	return Vector3.INF

func get_look(name:String) -> Vector3:
	match name:
		"garage": return to_global(Vector3(83,3,0))
		"police": return to_global(Vector3(-87,2,0))
	return to_global(Vector3(8,20,0))

func set_night_enabled(enabled:bool) -> void:
	for lamp in _street_lights: lamp.visible=enabled
