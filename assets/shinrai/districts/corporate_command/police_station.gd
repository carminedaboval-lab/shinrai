extends "district_geometry.gd"
## Civic exterior with a usable ground-floor public lobby. Upper offices are shell volumes.
const PUBLIC_FLOOR := 0.22
var white: StandardMaterial3D
var concrete: StandardMaterial3D
var blue: StandardMaterial3D
var dark: StandardMaterial3D
var cyan: StandardMaterial3D
var glass: StandardMaterial3D
var timber: StandardMaterial3D
var paving: StandardMaterial3D

func _ready() -> void:
	add_to_group("cantilever_police")
	add_to_group("district_police_station")
	white = mat(Color("d8dedb"), .72)
	concrete = mat(Color("8f999b"), .82)
	blue = mat(Color("123851"), .48)
	dark = mat(Color("20303a"), .55)
	cyan = mat(Color("38b6ce"), .38, 2.2)
	timber = mat(Color("967451"), .7)
	paving = mat(Color("59666b"), .86)
	glass = mat(Color(.24,.47,.56,.20), .18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_build_station()
	_build_lobby()
	_build_plaza()
	_build_patrol_court()
	_build_identity()
	set_meta("public_lobby_floor", PUBLIC_FLOOR)
	set_meta("interior_scope", "Public ground-floor lobby only; upper office volumes are exterior shells.")
	set_meta("gateway_local", Vector3(-4,0,24))
	print("DISTRICT_POLICE_READY lobby_floor=0.22 entry_clear_width=4 upper_offices=exterior_shell")

func _build_station() -> void:
	# Main station is 32 x 24 m, offset west to keep a separate patrol court.
	slab("PublicFloor",-20,12,-15,9,PUBLIC_FLOOR,paving,.24)
	box("WestWall",Vector3(.28,4.05,24),Vector3(-19.86,2.245,-3),white)
	box("EastWall",Vector3(.28,4.05,24),Vector3(11.86,2.245,-3),white)
	box("StaffRearVolume",Vector3(31.44,4.05,9.7),Vector3(-4,2.245,-10.01),concrete)
	box("StaffWallBlueFace",Vector3(31.42,3.8,.08),Vector3(-4,2.12,-5.12),blue,false)
	box("LobbyCeiling",Vector3(32,.24,24),Vector3(-4,4.39,-3),white)
	box("UpperOfficeVolume",Vector3(32,3.9,24),Vector3(-4,6.46,-3),blue)
	box("UpperWhiteFascia",Vector3(32.5,.36,24.5),Vector3(-4,8.55,-3),white)
	box("SetbackOfficeVolume",Vector3(22,2.65,16),Vector3(-8,10.055,-7),blue)
	box("SetbackRoof",Vector3(22.6,.3,16.6),Vector3(-8,11.53,-7),white)
	# Deep upper-window recesses read as offices without promising usable floors.
	for index in range(8):
		var x := -18.0 + index * 4.0
		box("UpperFrontWindow",Vector3(3.25,2.38,.075),Vector3(x,6.52,9.045),dark,false)
		box("UpperFrontGlass",Vector3(2.91,2.05,.035),Vector3(x,6.53,9.095),mat(Color("42717f"),.23),false)
		box("UpperWindowMullion",Vector3(.06,2.1,.07),Vector3(x,6.53,9.14),white,false)
	for index in range(5):
		box("SetbackWindow",Vector3(3.5,1.5,.07),Vector3(-17.1+index*4.5,10.0,1.04),mat(Color("42636d"),.28),false)
	for side in [-1.0,1.0]:
		var x := -19.99 if side < 0 else 11.99
		for index in range(4):
			box("SideOfficeWindow",Vector3(.06,2.35,3.8),Vector3(x,6.5,-11.8+index*5.8),dark,false)
	box("WestFacadeBlade",Vector3(.62,9.75,1.55),Vector3(-20.15,5.095,7.7),white)
	box("EastFacadeBlade",Vector3(.62,7.75,1.55),Vector3(12.15,4.095,7.7),white)
	box("UpperCyanBand",Vector3(31.1,.055,.06),Vector3(-4,8.25,9.27),cyan,false)
	# Front glazing remains collision-backed, with a genuine four-metre door gap.
	box("FrontWestGlazing",Vector3(13.7,3.82,.10),Vector3(-12.85,2.13,9.0),glass)
	box("FrontEastGlazing",Vector3(13.7,3.82,.10),Vector3(4.85,2.13,9.0),glass)
	for x in [-19.7,-15.15,-10.6,-6.05,-1.95,2.6,7.15,11.7]:
		box("FrontGlazingMullion",Vector3(.09,3.9,.16),Vector3(x,2.17,9.045),white)
	box("EntryHeader",Vector3(4,.22,.24),Vector3(-4,3.94,9.03),blue)
	# The diagonal canopy has a wide recess beneath it and keeps the doorway clear.
	var canopy := box("AngledEntryCanopy",Vector3(20,.28,4.4),Vector3(-4,4.68,10.7),white)
	canopy.rotation.z = deg_to_rad(-3.8)
	beam("CanopyCyanLip",Vector3(-13.98,5.20,12.93),Vector3(5.98,3.88,12.93),.075,cyan,false)
	beam("CanopyBlueEdge",Vector3(-13.98,5.36,12.91),Vector3(5.98,4.04,12.91),.16,blue,false)
	box("CanopyLeftSupport",Vector3(.28,4.42,.28),Vector3(-13.2,2.43,11.7),blue)
	box("CanopyRightSupport",Vector3(.28,3.39,.28),Vector3(5.2,1.915,11.7),blue)
	slab("EntryPorch",-14,6,8.85,12.1,PUBLIC_FLOOR,paving)
	ramp("PublicApproachRamp",Vector3(-4,0,18),Vector3(-4,PUBLIC_FLOOR,11.6),4.8,paving)
	# Two modest practical lights supplement material emission; no broad floodlight.
	light(Vector3(-4,3.72,8.0),Color("b5e6ed"),2.2,7,false)
	light(Vector3(-7,3.7,1.8),Color("ffdfad"),2.5,9,false)
	light(Vector3(6,3.7,1.8),Color("e0edf1"),2.0,7,false)

func _build_lobby() -> void:
	# Low counter creates a public side and a visible staff side. Both ends remain open.
	box("ReceptionCounter",Vector3(9.2,1.05,1.35),Vector3(-3.3,.745,.55),white)
	box("ReceptionCounterTop",Vector3(9.6,.10,1.55),Vector3(-3.3,1.32,.55),timber)
	box("AccessibleCounter",Vector3(2.2,.70,1.35),Vector3(-9.1,.57,.55),blue)
	box("AccessibleCounterTop",Vector3(2.35,.08,1.52),Vector3(-9.1,.96,.55),timber)
	box("CounterCyanInlay",Vector3(7.9,.035,.025),Vector3(-3.3,1.08,1.235),cyan,false)
	for x in [-5.8,-1.3]:
		box("DeskDisplay",Vector3(.78,.48,.06),Vector3(x,1.61,.38),dark,false)
		box("DisplayStand",Vector3(.07,.24,.10),Vector3(x,1.40,.38),dark,false)
		box("StaffSeat",Vector3(.65,.08,.65),Vector3(x,.69,-1.35),dark)
		box("StaffSeatBack",Vector3(.65,.75,.10),Vector3(x,1.05,-1.64),dark)
	# Public reporting tables and fixed seating are placed outside the entry route.
	for z in [2.6,5.6]:
		box("WaitingSeat",Vector3(4.3,.18,.72),Vector3(-15.6,.73,z),blue)
		box("WaitingSeatBack",Vector3(4.3,.65,.12),Vector3(-15.6,1.05,z-.31),white)
		for x in [-17.2,-14.0]:
			box("WaitingSeatFoot",Vector3(.12,.4,.52),Vector3(x,.42,z),dark)
	box("ReportingDeskTop",Vector3(3.4,.10,1.2),Vector3(7.65,1.02,1.75),timber)
	for x in [6.3,9.0]:
		box("ReportingDeskLeg",Vector3(.12,.75,.82),Vector3(x,.62,1.75),dark)
		box("ReportingChair",Vector3(.65,.10,.65),Vector3(x,.72,3.05),blue)
		box("ReportingChairBack",Vector3(.65,.75,.10),Vector3(x,1.04,3.34),dark)
	box("InformationKiosk",Vector3(.65,1.18,.45),Vector3(4.5,.81,6.9),white)
	box("InformationScreen",Vector3(.54,.62,.03),Vector3(4.5,1.25,7.14),dark,false)
	box("PublicNoticePanel",Vector3(3.3,1.9,.08),Vector3(8.9,2.1,-5.02),white,false)
	for index in range(3):
		box("NoticeCard",Vector3(.83,1.25,.025),Vector3(7.8+index*1.08,2.1,-4.965),mat(Color("809fa3"),.85),false)
	for x in [-16.5,6.9]:
		box("LobbyLinearLight",Vector3(5.2,.035,.12),Vector3(x,4.245,2.5),mat(Color("f2e8cc"),.5,1.4),false)
	sign_text("PUBLIC ENQUIRIES",Vector3(-4,2.8,-5.02),0,7.7,Color("dcebf0"))
	sign_text("INFORMATION",Vector3(4.5,1.77,7.18),0,1.55,Color("b4e6ed"))
	sign_text("REPORTING",Vector3(7.5,2.75,-4.96),0,2.7,Color("193b53"))

func _build_plaza() -> void:
	slab("StationForecourt",-22,22,-19,25,0,paving,.16)
	# Fine paving joints are visual only; the public approach has no small obstacles.
	for z in [14.0,18.0,22.0]:
		box("ForecourtJoint",Vector3(42,.008,.025),Vector3(0,.006,z),dark,false)
	for x in [-20.7,10.8]:
		box("ForecourtPlanter",Vector3(1.15,.62,5.4),Vector3(x,.31,18.2),concrete)
		box("PlanterGreen",Vector3(.94,.17,5.15),Vector3(x,.705,18.2),mat(Color("4a6454"),.95),false)
	for x in [-15.7,5.4]:
		box("PlazaBench",Vector3(3.5,.16,.66),Vector3(x,.52,19.3),timber)
		for side in [-1.0,1.0]:
			box("BenchBase",Vector3(.2,.45,.52),Vector3(x+side*1.28,.225,19.3),blue)
	for x in [-10.0,2.0]:
		box("EntryBollard",Vector3(.17,.78,.17),Vector3(x,.39,15.2),blue)
		box("BollardLight",Vector3(.175,.045,.175),Vector3(x,.71,15.2),cyan,false)
	box("PolicePylon",Vector3(1.15,3.5,.34),Vector3(-18.1,1.75,22.0),blue)
	box("PylonCyanTop",Vector3(1.17,.08,.36),Vector3(-18.1,3.36,22),cyan,false)
	sign_text("POLICE",Vector3(-18.1,2.75,22.19),0,2.6,Color("e8f4f3"))
	sign_text("24H",Vector3(-18.1,1.65,22.19),0,1.1,Color("8fdbeb"))

func _build_patrol_court() -> void:
	slab("PatrolCourt",12.45,22,-18.8,14.0,.015,dark,.18)
	for z in [-8.5,.3]:
		for side in [-1.0,1.0]:
			box("PatrolBayStripe",Vector3(6.6,.012,.07),Vector3(18.0,.028,z+side*2.0),white,false)
		box("PatrolBayStop",Vector3(.12,.10,2.5),Vector3(21.3,.065,z),concrete)
		parked_car(Vector3(17.9,.015,z),Color("d9e2e3"),PI*.5)
		# A restrained fixed red bar makes these recognisable parked patrol vehicles.
		box("PatrolRedLightBar",Vector3(.25,.10,1.12),Vector3(17.8,1.585,z),mat(Color("a72b36"),.45,1.1),false)
		box("PatrolBlueDoorMark",Vector3(.8,.16,.035),Vector3(18.2,.70,z+.935),blue,false)
	rail(Vector3(21.9,.015,-18.5),Vector3(21.9,.015,9.8),concrete,.85)
	rail(Vector3(12.5,.015,-18.5),Vector3(21.9,.015,-18.5),concrete,.85)
	sign_text("PATROL",Vector3(18.0,1.8,-17.9),0,3.6,Color("b8d8df"))
	light(Vector3(12.7,5.5,-5),Color("b9d4e2"),1.5,9,false)

func _build_identity() -> void:
	box("PoliceSignPanel",Vector3(13.6,1.15,.18),Vector3(-4,7.8,9.26),blue,false)
	sign_text("POLICE",Vector3(-4,7.82,9.39),0,10.9,Color("e5f3f1"))
	sign_text("KOBAN  /  DISTRICT 05",Vector3(-4,3.25,9.17),0,3.7,Color("d3edf0"))
	# Japanese glyphs are used only when the installed fallback font supplies them.
	var font := ThemeDB.fallback_font
	if font != null and font.has_char(0x8b66) and font.has_char(0x5bdf):
		sign_text("警察",Vector3(8.6,3.1,9.19),0,2.1,Color("d3edf0"))
	box("RoofBeaconBase",Vector3(.72,.3,.72),Vector3(-16.4,11.83,-4.8),dark)
	box("RoofPoliceBeacon",Vector3(.4,.32,.4),Vector3(-16.4,12.14,-4.8),mat(Color("ae3341"),.35,2.0),false)
	light(Vector3(-16.4,12.32,-4.8),Color("d94655"),.65,3,false)
	beam("RadioAntenna",Vector3(-12,11.68,-10),Vector3(-12,12.85,-10),.055,dark,false)

func get_route_waypoints(route: String) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if route != "lobby":
		return points
	# Visit the public side of reception, pass its accessible end, then seating.
	# Return to the same gateway so district tests can chain both street journeys.
	var local: Array[Vector3] = [Vector3(-4,0,24),Vector3(-4,0,18.2),
		Vector3(-4,PUBLIC_FLOOR,11.5),Vector3(-4,PUBLIC_FLOOR,7.7),
		Vector3(-4,PUBLIC_FLOOR,2.2),Vector3(-11.4,PUBLIC_FLOOR,2.2),
		Vector3(-11.4,PUBLIC_FLOOR,-2.4),Vector3(-12.3,PUBLIC_FLOOR,-2.4),
		Vector3(-12.3,PUBLIC_FLOOR,4.0),Vector3(-9.0,PUBLIC_FLOOR,4.0),
		Vector3(-4,PUBLIC_FLOOR,4.0),Vector3(-4,PUBLIC_FLOOR,11.5),
		Vector3(-4,0,18.2),Vector3(-4,0,24)]
	for point in local:
		points.append(to_global(point))
	return points

func get_review_points() -> Dictionary:
	return {"front_spawn":to_global(Vector3(-4,.05,23.4)),
		"front_look":to_global(Vector3(-4,5.2,4)),
		"lobby_spawn":to_global(Vector3(-4,.24,7.7)),
		"lobby_look":to_global(Vector3(-5,1.7,.6)),
		"patrol_spawn":to_global(Vector3(14.1,.05,12.8)),
		"patrol_look":to_global(Vector3(18,1.1,-6))}
