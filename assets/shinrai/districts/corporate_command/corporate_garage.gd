extends "res://assets/shinrai/districts/corporate_command/district_geometry.gd"
## Metre-scale, three-deck corporate parking with open vehicle/stair slab voids.
const DECKS: Array[float] = [0.22, 3.72, 7.22]
const BAY_ROWS: Array[float] = [-13.5, -2.5, 2.5, 13.5]
const GATEWAY := Vector3(0, 0, 27)
const ROOF_MEETING := Vector3(0, 7.22, 18.2)
var parking_bay_count := 0
var vehicle_count := 0
var charger_count := 0
var vehicle_ramp_count := 0
var stair_flight_count := 0
var _concrete: StandardMaterial3D
var _ceramic: StandardMaterial3D
var _asphalt: StandardMaterial3D
var _metal: StandardMaterial3D
var _white: StandardMaterial3D
var _cyan: StandardMaterial3D
var _amber: StandardMaterial3D
var _solar: StandardMaterial3D

func _ready() -> void:
	add_to_group("corporate_garage")
	add_to_group("cantilever_garage")
	_concrete = mat(Color("858e93"), 0.88)
	_ceramic = mat(Color("d4dad7"), 0.56)
	_asphalt = mat(Color("333e46"), 0.96)
	_metal = mat(Color("293b47"), 0.43)
	_metal.metallic = 0.5
	_white = mat(Color("e1e3d6"), 0.8)
	_cyan = mat(Color("44dbed"), 0.35, 0.9)
	_amber = mat(Color("eab76b"), 0.4, 0.5)
	_solar = mat(Color("132d46"), 0.3)
	_solar.metallic = 0.4
	_build_decks()
	_build_structure()
	_build_vehicle_ramps()
	_build_stairs()
	_build_parking()
	_build_solar_canopy()
	_build_frontage()
	print("CORPORATE_GARAGE_READY decks=3 bays=", parking_bay_count, " cars=", vehicle_count,
		" chargers=", charger_count, " vehicle_ramps=", vehicle_ramp_count,
		" stair_flights=", stair_flight_count, " meshes=", geometry_count, " colliders=", collider_count)

func _build_decks() -> void:
	# The ground apron rises inside the 48 x 44 m footprint; there is no .22 m kerb.
	slab("GroundDeck", -24, 24, -22, 19, DECKS[0], _asphalt)
	ramp("AccessibleEntranceApron", Vector3(0, 0, 22), Vector3(0, 0.22, 19), 48, _asphalt)
	for level in range(1, 3):
		var y := DECKS[level]
		# West void [-22,-14] x [-15,15] leaves each complete inclined roadway open.
		# East void [19,24] x [9.4,14.8] leaves both pedestrian flights open.
		slab("Deck%dMain" % level, -14, 19, -22, 22, y, _asphalt)
		slab("Deck%dWestEdge" % level, -24, -22, -22, 22, y, _asphalt)
		slab("Deck%dRampRearLanding" % level, -22, -14, -22, -15, y, _asphalt)
		slab("Deck%dRampFrontLanding" % level, -22, -14, 15, 22, y, _asphalt)
		slab("Deck%dEastRear" % level, 19, 24, -22, 9.4, y, _asphalt)
		slab("Deck%dStairFrontLanding" % level, 19, 24, 14.8, 22, y, _asphalt)
	for level in range(3):
		var y := DECKS[level]
		for x in [-23.78, 23.78]:
			box("PaleSideFascia", Vector3(0.3, 0.33, 44), Vector3(x, y-0.12, 0), _ceramic, false)
		if level > 0:
			for z in [-21.87, 21.87]:
				box("PaleDeckFascia", Vector3(48, 0.33, 0.25), Vector3(0, y-0.12, z), _ceramic, false)
			box("CyanFrontReveal", Vector3(43, 0.045, 0.035), Vector3(-1, y-0.02, 22.015), _cyan, false)
			for x in [-23.65, 23.65]:
				rail(Vector3(x, y, -21.65), Vector3(x, y, 21.65), _metal)
			for z in [-21.65, 21.65]:
				rail(Vector3(-23.65, y, z), Vector3(23.65, y, z), _metal)
			# Guard the open sides of the vehicle void, but keep front/rear turning pads open.
			for x in [-22.0, -14.0]:
				rail(Vector3(x, y, -15), Vector3(x, y, 15), _metal)
			# Side of the stair opening facing the parking deck.
			rail(Vector3(19.05, y, 9.4), Vector3(19.05, y, 14.8), _metal)
			rail(Vector3(19.05, y, 9.4), Vector3(23.65, y, 9.4), _metal)

func _build_structure() -> void:
	for x in [-23.4, -13.8, 2.5, 19.0, 23.4]:
		for z in [-19.6, -6.25, 6.25, 19.6]:
			# The east pedestrian entry stays broad and completely open.
			if x > 19.0 and z > 19.0:
				continue
			box("ConcretePier", Vector3(0.40, 7.2, 0.40), Vector3(x, 3.82, z), _concrete)
			box("PierImpactStripe", Vector3(0.43, 0.32, 0.43), Vector3(x, 0.9, z), _amber, false)
	for level in range(1, 3):
		for z in [-19.6, 19.6]:
			box("CrossDeckGirder", Vector3(47, 0.28, 0.3), Vector3(0, DECKS[level]-0.35, z), _concrete)
	# Repeated ceramic fins and diagonal corner structure give the open-sided shell its silhouette.
	for side in [-1.0, 1.0]:
		for z in [-17.5, -10.0, 0.0, 10.0, 17.5]:
			if side > 0 and z == 10.0:
				continue
			var fin := box("CeramicVentFin", Vector3(0.24, 6.45, 1.25), Vector3(side*23.86, 3.67, z), _ceramic, false)
			fin.rotation.y = side * 0.22
		beam("CornerDiagonal", Vector3(side*23.4, 0.5, -19.6), Vector3(side*23.4, 7.0, -14.8), 0.24, _metal, false)
		beam("CornerDiagonal", Vector3(side*23.4, 0.5, -10.0), Vector3(side*23.4, 7.0, -14.8), 0.24, _metal, false)

func _build_vehicle_ramps() -> void:
	for level in range(2):
		var a := Vector3(-18, DECKS[level], 15)
		var b := Vector3(-18, DECKS[level+1], -15)
		ramp("VehicleRamp%d" % level, a, b, 6.0, _asphalt)
		vehicle_ramp_count += 1
		for x in [-21.0, -15.0]:
			rail(Vector3(x, a.y, 15), Vector3(x, b.y, -15), _metal, 0.95)
		for strip in range(15):
			var t0 := float(strip) / 15.0
			var t1 := minf(1.0, t0 + 0.025)
			beam("RampCentreDash", a.lerp(b, t0)+Vector3.UP*0.012, a.lerp(b, t1)+Vector3.UP*0.012, 0.065, _white)
		# Edge lines follow the slope rather than floating above it.
		for x in [-20.7, -15.3]:
			beam("RampEdgeLine", Vector3(x, a.y+0.012, 15), Vector3(x, b.y+0.012, -15), 0.07, _amber)
		box("RampWayfindingBoard", Vector3(4.4, 0.55, 0.08), Vector3(-18, a.y+2.67, 16.1), _metal, false)
		sign_text("%02d  /  RAMP UP" % (level+2), Vector3(-18, a.y+2.67, 16.16), 0, 3.8, Color("8ce7ef"))

func _stair_flight(label: String, a: Vector3, b: Vector3) -> void:
	ramp(label+"SmoothCollision", a, b, 1.7, _concrete)
	stair_flight_count += 1
	# Thin open treads retain the stair silhouette over the continuous walking plane.
	for tread in range(10):
		var p := a.lerp(b, (float(tread)+0.5)/10.0)
		p.y += 0.025
		box(label+"Tread", Vector3(1.7, 0.055, 0.40), p, _ceramic, false)
		var edge := p + Vector3(0, 0.035, signf(a.z-b.z)*0.18)
		box(label+"Nosing", Vector3(1.55, 0.018, 0.035), edge, _amber, false)
	for dx in [-0.9, 0.9]:
		rail(a+Vector3(dx,0,0), b+Vector3(dx,0,0), _metal, 1.05)

func _build_stairs() -> void:
	for level in range(2):
		var y := DECKS[level]
		_stair_flight("Stair%dA" % level, Vector3(20.35,y,14.8), Vector3(20.35,y+1.75,10.8))
		slab("Stair%dMidLanding" % level, 19.4,23.6,9.4,10.8,y+1.75,_concrete,0.18)
		_stair_flight("Stair%dB" % level, Vector3(22.65,y+1.75,10.8), Vector3(22.65,y+3.5,14.8))
		rail(Vector3(19.4,y+1.75,9.4),Vector3(23.6,y+1.75,9.4),_metal)
		for x in [19.4,23.6]:
			rail(Vector3(x,y+1.75,9.4),Vector3(x,y+1.75,10.8),_metal)
	for level in range(3):
		var y := DECKS[level]
		box("StairEntryFloorAccent",Vector3(4.1,0.01,0.20),Vector3(21.5,y+0.012,16.2),_cyan,false)
		sign_text("%02d  /  STAIRS" % (level+1),Vector3(23.6,y+2.0,16.8),-PI*.5,2.0,Color("9cebf2"))
		light(Vector3(21.6,y+2.65,15.6),Color("c3e0ed"),2.2,4.8,false)

func _bay_line(a: Vector3,b: Vector3) -> void:
	beam("ParkingBayLine",a,b,0.055,_white)

func _build_parking() -> void:
	var colours: Array[Color] = [Color("dce4e3"),Color("4e8e99"),Color("b36652"),Color("313d4b"),Color("c7c1a8"),Color("71938a")]
	for level in range(3):
		var y := DECKS[level]
		for row in range(BAY_ROWS.size()):
			var x0 := BAY_ROWS[row]
			for boundary in range(12):
				var z := -13.75+boundary*2.5
				_bay_line(Vector3(x0,y+0.012,z),Vector3(x0+5,y+0.012,z))
			_bay_line(Vector3(x0,y+0.012,-13.75),Vector3(x0,y+0.012,13.75))
			_bay_line(Vector3(x0+5,y+0.012,-13.75),Vector3(x0+5,y+0.012,13.75))
			parking_bay_count += 11
		# Both drive aisles remain six metres clear; cars are wholly inside marked bays.
		for aisle_x in [-5.5,10.5]:
			for z in [-10.0,0.0,10.0]:
				_floor_arrow(Vector3(aisle_x,y+0.015,z),1.0 if aisle_x<0 else -1.0)
		for car_index in range(4):
			var row := (car_index+level)%4
			var z: float = [-10.0,-2.5,5.0,10.0][car_index]
			var yaw := PI*.5 if row in [0,2] else -PI*.5
			parked_car(Vector3(BAY_ROWS[row]+2.5,y,float(z)),colours[(level*2+car_index)%colours.size()],yaw)
			vehicle_count += 1
		for z in [-10.0,-7.5]:
			_ev_charger(Vector3(18.85,y,z))
		# Restrained warm practicals under the decks; top parking uses canopy downlights.
		if level<2:
			for x in [-5.5,10.5]:
				for z in [-10.0,2.0,13.0]:
					box("AisleLuminaire",Vector3(.4,.06,2.0),Vector3(x,y+3.16,z),_white,false)
					light(Vector3(x,y+3.0,z),Color("f2ddbb"),2.7,7.5,false)
		box("LevelBoard",Vector3(3.5,.9,.08),Vector3(-10.7,y+2.35,15.2),_metal,false)
		sign_text("P%02d / EV PARKING" % (level+1),Vector3(-10.7,y+2.35,15.25),0,3.0,Color("a4e9ef"))

func _floor_arrow(at: Vector3,direction: float) -> void:
	box("TrafficArrowShaft",Vector3(.15,.012,1.3),at,_white,false)
	var tip := at+Vector3(0,0,direction*.9)
	for side in [-1.0,1.0]:
		beam("TrafficArrowHead",tip,at+Vector3(side*.45,0,direction*.3),.13,_white)

func _ev_charger(at: Vector3) -> void:
	box("EVCharger",Vector3(.32,1.15,.5),at+Vector3.UP*.575,_metal)
	box("EVChargerDisplay",Vector3(.035,.24,.32),at+Vector3(-.18,.9,0),_cyan,false)
	box("ChargeStatus",Vector3(.035,.04,.36),at+Vector3(-.18,1.08,0),_white,false)
	beam("ChargeCable",at+Vector3(-.2,.78,.16),at+Vector3(-.45,.25,.20),.035,_metal)
	beam("ChargeCableReturn",at+Vector3(-.45,.25,.20),at+Vector3(-.22,.58,-.12),.035,_metal)
	charger_count += 1

func _build_solar_canopy() -> void:
	for x in [-13.8,19.0]:
		for z in [-14.7,14.7]:
			box("CanopyPier",Vector3(.22,3.3,.22),Vector3(x,8.87,z),_metal)
	for z in [-14.7,14.7]:
		beam("CanopyTrussTop",Vector3(-13.8,10.4,z),Vector3(19,10.7,z),.15,_metal)
		beam("CanopyTrussBottom",Vector3(-13.8,9.95,z),Vector3(19,10.25,z),.15,_metal)
		for cell in range(8):
			var x := -13.8+cell*4.1
			var a := Vector3(x,9.95+float(cell)*.0375,z)
			beam("CanopyTrussWeb",a,a+Vector3(2.05,.47,0),.075,_metal)
			beam("CanopyTrussWeb",a+Vector3(2.05,.47,0),a+Vector3(4.1,.0375,0),.075,_metal)
	for column in range(10):
		var x := -12.1+column*3.1
		beam("CanopyPurlin",Vector3(x,10.38,-14.7),Vector3(x,10.38,14.7),.10,_metal)
		for row in range(8):
			var panel := box("SolarCassette",Vector3(2.95,.085,3.35),Vector3(x,10.45,-12.25+row*3.5),_solar,false)
			panel.rotation.z = -.025
			for split in [-.75,0.0,.75]:
				box("SolarCellSeam",Vector3(.012,.008,3.25),Vector3(x+split,10.51,-12.25+row*3.5),_metal,false)
	for x in [-5.5,10.5]:
		for z in [-9.0,5.0]:
			light(Vector3(x,9.8,z),Color("e9ddc4"),2.6,7.5,false)

func _build_frontage() -> void:
	box("ParkingIdentityBlade",Vector3(1.15,8.1,0.36),Vector3(-22.4,4.05,21.5),_metal)
	box("IdentityCyanReveal",Vector3(.06,7.6,.04),Vector3(-22.98,4.0,21.71),_cyan,false)
	for index in range(3):
		sign_text("P" if index==0 else ("EV" if index==1 else "2050"),Vector3(-22.4,6.6-index*1.7,21.72),0,.83,Color("bdeef1"))
	box("CorporateHeader",Vector3(15,.72,.15),Vector3(0,7.8,21.55),_metal,false)
	sign_text("CANTILEVER  /  PARKING",Vector3(0,7.8,21.65),0,13.5,Color("e4efec"))
	for data in [[-5.5,"ENTRY",_cyan],[10.5,"EXIT",_amber]]:
		var x := float(data[0])
		box("LaneHeader",Vector3(5.0,.5,.12),Vector3(x,2.65,20.4),_metal,false)
		sign_text(str(data[1]),Vector3(x,2.65,20.48),0,2.0,Color("8ee6ef") if x<0 else Color("efd3a1"))
		box("LaneStatusBand",Vector3(4.4,.055,.035),Vector3(x,2.37,20.48),data[2],false)
	# Planters occupy unused rear/east margin, outside aisles and the stair route.
	var leaf := mat(Color("52715b"),.95)
	for z in [-18.0,-1.0]:
		box("Planter",Vector3(2.1,.52,1.3),Vector3(21.6,.48,z),_ceramic)
		for offset in [-.55,0.0,.55]:
			box("ClippedPlant",Vector3(.52,.52,.68),Vector3(21.6+offset,.98,z),leaf,false)

func _approach() -> Array[Vector3]:
	return [GATEWAY,Vector3(0,0,22.2),Vector3(0,.22,18.2)]

func _stairs_up_local() -> Array[Vector3]:
	var points := _approach()
	points.append(Vector3(21.6,.22,18.2))
	for level in range(2):
		var y := DECKS[level]
		points.append(Vector3(20.35,y,16.3))
		points.append(Vector3(20.35,y,14.8))
		points.append(Vector3(20.35,y+1.75,10.8))
		points.append(Vector3(20.35,y+1.75,10.1))
		points.append(Vector3(22.65,y+1.75,10.1))
		points.append(Vector3(22.65,y+1.75,10.8))
		points.append(Vector3(22.65,y+3.5,14.8))
		points.append(Vector3(22.65,y+3.5,16.3))
	points.append(Vector3(21.6,7.22,18.2))
	points.append(ROOF_MEETING)
	return points

func _ramp_up_local() -> Array[Vector3]:
	var points := _approach()
	points.append(Vector3(-18,.22,18.2))
	for level in range(2):
		var y := DECKS[level]
		points.append(Vector3(-18,y,15))
		points.append(Vector3(-18,y+3.5,-15))
		points.append(Vector3(-18,y+3.5,-18.5))
		points.append(Vector3(-5.5,y+3.5,-18.5))
		points.append(Vector3(-5.5,y+3.5,18.2))
		if level==0:
			points.append(Vector3(-18,y+3.5,18.2))
	points.append(ROOF_MEETING)
	return points

func get_route_waypoints(route: String) -> Array[Vector3]:
	var local_points: Array[Vector3] = []
	match route:
		"stairs_up", "stairs_down":
			local_points = _stairs_up_local()
		"ramp_up", "ramp_down":
			local_points = _ramp_up_local()
		_:
			return []
	if route.ends_with("_down"):
		local_points.reverse()
	var global_points: Array[Vector3] = []
	for point in local_points:
		global_points.append(to_global(point))
	return global_points

func get_review_points() -> Dictionary:
	return {"gateway":to_global(GATEWAY),"roof_meeting":to_global(ROOF_MEETING),
		"front_camera":to_global(Vector3(39,19,48)),"front_target":to_global(Vector3(0,3.8,0)),
		"interior_camera":to_global(Vector3(-5.5,1.9,17)),"interior_target":to_global(Vector3(-5.5,1.9,-10)),
		"roof_camera":to_global(Vector3(20,9.5,18)),"roof_target":to_global(Vector3(0,8,0)),
		"deck_tops":DECKS,"parking_bays":parking_bay_count,"parked_evs":vehicle_count,"chargers":charger_count,
		"ramp_width_m":6.0,"ramp_run_m":30.0,"ramp_rise_m":3.5,"bay_width_m":2.5,"bay_depth_m":5.0,"aisle_width_m":6.0}
