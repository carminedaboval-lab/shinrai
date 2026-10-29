extends RefCounted
## Original courtyard architecture, metre units. Installed helper/material reuse only.
const Architecture = preload("res://scripts/midori_south_street_architecture.gd")
const Windows = preload("res://scripts/midori_upper_construction.gd")
const Access = preload("res://scripts/building_access/geometry.gd")
const CourtFinishes = preload("res://scripts/midori_court_finishes.gd")

static func build(street: Node3D) -> Dictionary:
	var group := Node3D.new()
	group.name = "SouthCourtBuildings"
	group.set_meta("creator_protected",true)
	street.add_child(group)
	var results: Array[Dictionary] = []
	for spec: Dictionary in [
		{"id":"KadoMakerWorkroom","position":Vector3(-20.5,.09,250.5),"rotation":-PI*.5,"w":9.0,"d":9.0,"h":4.1,"roof":"shed","rise":1.15,"wall":"arch_mineral","upper_cedar":false,"footprint":Rect2(-25,246,9,9),"approach":Vector3(-15.65,.09,250.5),"clear":Rect2(-16,249.65,1.8,1.7)},
		{"id":"NishiTownhouse","position":Vector3(-8,.09,262.5),"rotation":0.0,"w":8.0,"d":9.0,"h":6.25,"roof":"gable","rise":1.55,"wall":"arch_plaster","upper_cedar":false,"footprint":Rect2(-12,258,8,9),"approach":Vector3(-8,.09,257.65),"clear":Rect2(-8.85,256.2,1.7,1.8)},
		{"id":"HigashiPorchHome","position":Vector3(21,.09,250.5),"rotation":PI*.5,"w":9.0,"d":8.0,"h":6.45,"roof":"flat","rise":.35,"wall":"arch_plaster","upper_cedar":true,"footprint":Rect2(17,246,8,9),"approach":Vector3(16.65,.09,250.5),"clear":Rect2(15.2,249.65,1.8,1.7)}
	]:
		var house := Node3D.new()
		house.name = spec.id
		house.position = spec.position
		house.rotation.y = float(spec.rotation)
		house.set_meta("creator_protected",true)
		house.set_meta("creator_editable",false)
		house.set_meta("creator_object_kind","building")
		group.add_child(house)
		_shell(street,house,spec)
		_roof(street,house,spec)
		_expression(street,house,spec)
		if str(spec.id)!="KadoMakerWorkroom": Access.finish_house(street,house,str(spec.id),float(spec.w),float(spec.d),-float(spec.d)*.5,0.0,float(spec.h),0.0,-float(spec.d)*.5+(.90 if str(spec.roof)=="flat" else .56))
		else: Access.finish_workroom(street,house,spec)
		CourtFinishes.apply(street,house)
		var counts := _counts(house)
		var door_local := Vector3(0,0,-float(spec.d)*.5)
		var leaf_local := door_local+Vector3(0,0,.90 if String(spec.roof)=="flat" else .56)
		var entry: Vector3 = house.transform*door_local
		var leaf: Vector3 = house.transform*leaf_local
		var local_bounds := AABB(Vector3(-float(spec.w)*.5-.45,-.11,-float(spec.d)*.5-.45),Vector3(float(spec.w)+.90,float(spec.h)+float(spec.rise)+.36,float(spec.d)+.90))
		var meta := {"id":spec.id,"footprint":spec.footprint,"entry_point":entry,"door_leaf_point":leaf,"approach":spec.approach,"clear_approach":spec.clear,"support_y":.09,"local_bounds":local_bounds,"world_bounds":house.transform*local_bounds,"window_count":5 if String(spec.roof)=="shed" else 9,"mesh_members":counts.meshes,"collision_count":counts.collisions,"closed_shell":false,"roof_style":spec.roof}
		if house.has_meta("nishi_frontage_construction"):
			meta["frontage_construction"]=house.get_meta("nishi_frontage_construction")
		house.set_meta("court_building",meta)
		var result := meta.duplicate()
		result["root"] = house
		results.append(result)
	return {"ok":true,"root":group,"buildings":results,"lights_created":0,"new_buildings":3,"source_assets_modified":false,"dependencies":["midori_south_street_architecture.gd","midori_upper_construction.gd","midori_shop_joinery.gd"]}

static func _box(street: Node3D, parent: Node3D, label: String, p: Vector3, size: Vector3, key: String, collide: bool=false) -> MeshInstance3D:
	return street.call("_box",parent,label,p,size,key,collide) as MeshInstance3D

static func _shell(street: Node3D, house: Node3D, spec: Dictionary) -> void:
	var w := float(spec.w)
	var d := float(spec.d)
	var h := float(spec.h)
	var maker := String(spec.roof)=="shed"
	var porch := String(spec.roof)=="flat"
	# Flush finished floor at worldY .09; solid foundation extends into ground.
	_box(street,house,"GroundedPlinth",Vector3(0,-.055,0),Vector3(w,.11,d),"arch_stone",true)
	var openings: Array[Dictionary] = [{"x":0.0,"w":1.28 if maker else (2.4 if porch else 1.16),"bottom":0.0,"top":2.35,"door":true}]
	if maker:
		openings.append({"x":-2.65,"w":2.0,"bottom":.85,"top":2.75,"door":false})
		openings.append({"x":2.65,"w":2.0,"bottom":.85,"top":2.75,"door":false})
		openings.append({"x":0.0,"w":2.1,"bottom":3.15,"top":3.85,"door":false})
	else:
		for x: float in [-2.55,2.55]:
			openings.append({"x":x,"w":1.7,"bottom":.90,"top":2.45,"door":false})
		for x: float in [-2.4,0,2.4]:
			openings.append({"x":x,"w":1.5,"bottom":4.0,"top":5.60,"door":false})
	var front := _elevation(street,house,"CourtFront",Vector3(0,0,-d*.5),0,w,h,openings,String(spec.wall),bool(spec.upper_cedar))
	_door(street,front,porch,maker)
	for side: float in [-1.0,1.0]:
		var side_windows: Array[Dictionary] = []
		if maker:
			side_windows.append({"x":0.0,"w":2.2,"bottom":2.70,"top":3.65,"door":false})
		else:
			for yy: float in [1.0,4.0]:
				side_windows.append({"x":0.0,"w":1.4,"bottom":yy,"top":yy+1.45,"door":false})
		_elevation(street,house,"CourtSide",Vector3(side*w*.5,0,0),-side*PI*.5,d-.48,h,side_windows,String(spec.wall),bool(spec.upper_cedar))
		_box(street,house,"SidePlinthCoping",Vector3(side*(w*.5-.02),.21,0),Vector3(.12,.06,d-.06),"arch_stone")
		for zz: float in [-d*.5+.10,d*.5-.10]:
			_box(street,house,"ProudTimberCorner",Vector3(side*(w*.5-.025),h*.5,zz),Vector3(.10,h,.28),"arch_cedar")
	_elevation(street,house,"CourtRear",Vector3(0,0,d*.5),PI,w,h,[],String(spec.wall),bool(spec.upper_cedar))
	# Closed envelope leaves 1.15m of shallow window/porch depth at the front.
	# Modest surface-mounted service box, meter and two fixing rails on rear.
	_box(street,house,"RearServiceCabinet",Vector3(w*.28,1.12,d*.5+.08),Vector3(.42,.60,.16),"arch_metal")
	_box(street,house,"MeterFace",Vector3(w*.28,1.20,d*.5+.17),Vector3(.19,.15,.025),"arch_linen")
	for yy: float in [.88,1.36]:
		_box(street,house,"UtilityMountRail",Vector3(w*.28,yy,d*.5+.015),Vector3(.50,.035,.035),"arch_metal")
	if maker:
		# Workshop door surround: visible loadbearing posts, deep header and apron.
		for x: float in [-.86,.86]:
			_box(street,front,"WorkroomPortalPost",Vector3(x,1.30,-.14),Vector3(.14,2.60,.22),"arch_cedar")
		_box(street,front,"WorkroomPortalLintel",Vector3(0,2.66,-.14),Vector3(1.86,.18,.22),"arch_cedar")
	else:
		_box(street,front,"StoreyLedger",Vector3(0,3.25,-.055),Vector3(w,.16,.10),"arch_cedar")

static func _elevation(street: Node3D, house: Node3D, label: String, pos: Vector3, angle: float, width: float, height: float, openings: Array[Dictionary], wall: String, cedar: bool) -> Node3D:
	var elevation := Node3D.new()
	elevation.name = label
	elevation.position = pos
	elevation.rotation.y = angle
	house.add_child(elevation)
	var fields: Array[Rect2] = [Rect2(-width*.5,0,width,height)]
	for opening: Dictionary in openings:
		fields = _cut(fields,Rect2(float(opening.x)-float(opening.w)*.5,float(opening.bottom),float(opening.w),float(opening.top)-float(opening.bottom)))
	# Split at storey boundary so cedar fields never hide wall openings.
	if cedar:
		var upper: Array[Rect2] = []
		var lower: Array[Rect2] = []
		for rect: Rect2 in fields:
			var low := rect.intersection(Rect2(-width*.5,0,width,3.35))
			var high := rect.intersection(Rect2(-width*.5,3.35,width,height-3.35))
			if low.has_area(): lower.append(low)
			if high.has_area(): upper.append(high)
		for rect: Rect2 in upper:
			street.call("_solid",elevation,"CedarWallCollision",Vector3(rect.get_center().x,rect.get_center().y,.12),Vector3(rect.size.x,rect.size.y,.24))
			Architecture._clad_wall(street,elevation,"CourtCedarField",Vector3(rect.get_center().x,rect.get_center().y,.12),Vector3(rect.size.x,rect.size.y,.24))
		fields = lower
	for rect: Rect2 in fields:
		_box(street,elevation,"WallAroundOpening",Vector3(rect.get_center().x,rect.get_center().y,.12),Vector3(rect.size.x,rect.size.y,.24),wall,true)
	for opening: Dictionary in openings:
		if bool(opening.door): continue
		var x := float(opening.x)
		var bottom := float(opening.bottom)
		var top := float(opening.top)
		var span := float(opening.w)
		Access.window(street,elevation,x,bottom,top,span)
	return elevation

static func _window_room(street: Node3D, parent: Node3D, x: float, bottom: float, top: float, width: float) -> void:
	var cy := (bottom+top)*.5
	_box(street,parent,"RecessRoomBack",Vector3(x,cy,.95),Vector3(width,top-bottom,.06),"arch_shadow")
	for yy: float in [bottom+.025,top-.025]:
		_box(street,parent,"RecessRoomFloorCeiling",Vector3(x,yy,.69),Vector3(width,.05,.50),"arch_interior")
	for side: float in [-1.0,1.0]:
		_box(street,parent,"RecessSide",Vector3(x+side*(width*.5-.025),cy,.69),Vector3(.05,top-bottom,.50),"arch_interior")
		for fold: int in range(3):
			_box(street,parent,"LinenCurtainFold",Vector3(x+side*(width*.5-.18)+float(fold)*.035,cy,.70+float(fold%2)*.025),Vector3(.035,top-bottom-.15,.045),"arch_linen")
	_box(street,parent,"InteriorTimberShelf",Vector3(x,bottom+.25,.82),Vector3(width*.65,.035,.20),"arch_cedar")
	for item: int in range(3):
		_box(street,parent,"SmallRoomObject",Vector3(x-.12+float(item)*.12,bottom+.37,.83),Vector3(.075,.20,.08),"arch_sage" if item%2==0 else "arch_linen")

static func _door(street: Node3D, front: Node3D, porch: bool, maker: bool) -> void:
	var depth := .90 if porch else .56
	var bay_width := 2.4 if porch else (1.28 if maker else 1.16)
	var width := 1.28 if maker else 1.16
	# Supports align exactly with ground paving top .09, no raised invisible step.
	_box(street,front,"FlushEntryApron",Vector3(0,-.035,-.02),Vector3(1.7,.07,.76),"arch_stone",true)
	_box(street,front,"FlushThreshold",Vector3(0,-.025,depth*.5),Vector3(width,.05,depth+.08),"arch_stone",true)
	for side: float in [-1.0,1.0]:
		_box(street,front,"DoorRevealSide",Vector3(side*(bay_width*.5-.04),1.18,depth*.5),Vector3(.08,2.36,depth),"arch_interior")
		_box(street,front,"DoorFrameJamb",Vector3(side*(width*.5-.09),1.16,depth-.035),Vector3(.075,2.32,.13),"arch_cedar")
	_box(street,front,"DoorRevealHead",Vector3(0,2.31,depth*.5),Vector3(bay_width,.08,depth),"arch_cedar")
	Access.door(street,front,Vector3(0,0,depth),Vector2(width-.23,2.26),false,"ResidentialEntranceDoor")
	_box(street,front,"Doorbell",Vector3(width*.5+.16,1.35,-.025),Vector3(.07,.11,.04),"arch_metal")
	if porch or maker:
		var canopy_depth := 1.18 if porch else .72
		_box(street,front,"EntranceCanopy",Vector3(0,2.57,.20),Vector3(2.15,.14,canopy_depth),"arch_metal")
		_box(street,front,"CanopyTimberSoffit",Vector3(0,2.48,.20),Vector3(2.05,.04,canopy_depth-.04),"arch_cedar")
		for side: float in [-1.0,1.0]:
			_box(street,front,"CanopyWallBracket",Vector3(side*.77,2.35,.19),Vector3(.065,.23,.36),"arch_metal")
	if porch:
		for side: float in [-1.0,1.0]:
			_box(street,front,"PorchRearReturn",Vector3(side*.89,1.17,1.01),Vector3(.62,2.34,.12),"arch_interior")
		_box(street,front,"PorchReturnSeat",Vector3(.88,.34,.58),Vector3(.32,.10,.54),"arch_cedar")
		for y: float in [.16,.28]:
			_box(street,front,"PorchScreenRail",Vector3(.86,y,.55),Vector3(.09,.05,.65),"arch_cedar")

static func _roof(street: Node3D, house: Node3D, spec: Dictionary) -> void:
	var w := float(spec.w)
	var d := float(spec.d)
	var h := float(spec.h)
	var rise := float(spec.rise)
	var roof := String(spec.roof)
	if roof=="flat":
		_box(street,house,"FlatRoofDeck",Vector3(0,h+.055,0),Vector3(w+.28,.11,d+.28),"arch_metal")
		for side: float in [-1.0,1.0]:
			_box(street,house,"ParapetSide",Vector3(side*(w*.5-.06),h+.20,0),Vector3(.12,.30,d+.08),"arch_mineral")
			_box(street,house,"ParapetSideCoping",Vector3(side*(w*.5-.06),h+.37,0),Vector3(.20,.05,d+.16),"arch_metal")
		for z: float in [-d*.5,d*.5]:
			_box(street,house,"ParapetEnd",Vector3(0,h+.20,z),Vector3(w-.24,.30,.12),"arch_mineral")
			_box(street,house,"ParapetEndCoping",Vector3(0,h+.37,z),Vector3(w-.04,.05,.20),"arch_metal")
	else:
		var half := w*.5+.32
		var depth := d+.64
		if String(spec.id)=="NishiTownhouse": depth=d+.86
		if roof=="gable":
			var pitch := atan2(rise,half)
			for side: float in [-1.0,1.0]:
				var length := sqrt(half*half+rise*rise)
				var sheet := _box(street,house,"GableRoofSheet",Vector3(side*half*.5,h+rise*.5,0),Vector3(length,.12,depth),"arch_metal")
				sheet.rotation.z = -side*pitch
				for seam: int in range(22):
					var strip := _box(street,house,"StandingRoofSeam",Vector3(side*half*.5,h+rise*.5+.075,-d*.5-.25+float(seam)*(d+.5)/21),Vector3(length,.022,.022),"arch_metal")
					strip.rotation.z = -side*pitch
			_box(street,house,"RidgeFoldedCap",Vector3(0,h+rise+.07,0),Vector3(.20,.10,depth+.02),"arch_metal")
			if String(spec.id)=="NishiTownhouse":
				for side: float in [-1.0,1.0]:
					var rake := _box(street,house,"NishiFrontGableRake",Vector3(side*half*.5,h+rise*.5-.04,-d*.5-.38),Vector3(sqrt(half*half+rise*rise),.18,.10),"arch_cedar")
					rake.rotation.z=-side*pitch
					_nishi_roof_record(house,rake,"RakeWest" if side<0 else "RakeEast")
					var soffit := _box(street,house,"NishiFrontGableSoffit",Vector3(side*half*.5,h+rise*.5-.075,-d*.5-.21),Vector3(sqrt(half*half+rise*rise),.045,.42),"arch_cedar")
					soffit.rotation.z=-side*pitch
					_nishi_roof_record(house,soffit,"SoffitWest" if side<0 else "SoffitEast")
				for x: float in [-3.6,-1.8,0,1.8,3.6]:
					var roof_y := h+rise*(1.0-absf(x)/half)
					var rafter := _box(street,house,"NishiFrontEaveRafter",Vector3(x,roof_y-.16,-d*.5-.21),Vector3(.075,.16,.42),"arch_cedar")
					_nishi_roof_record(house,rafter,"FrontRafter_"+str(x))
		else:
			var pitch := atan2(rise,half*2)
			var sheet := _box(street,house,"WorkroomShedRoof",Vector3(0,h+rise*.5,0),Vector3(sqrt(half*half*4+rise*rise),.12,depth),"arch_metal")
			sheet.rotation.z = pitch
			for seam: int in range(22):
				var strip := _box(street,house,"ShedRoofStandingSeam",Vector3(0,h+rise*.5+.075,-d*.5-.25+float(seam)*(d+.5)/21),Vector3(half*2,.022,.022),"arch_metal")
				strip.rotation.z = pitch
		_roof_closure(street,house,w,d,h,rise,roof)
		for side: float in [-1.0,1.0]:
			var ey := h
			if roof=="shed": ey += rise*(side+1)*.5
			_box(street,house,"EaveFascia",Vector3(side*(half-.02),ey-.06,0),Vector3(.08,.18,depth),"arch_cedar")
			_box(street,house,"EaveSoffit",Vector3(side*(w*.5+.13),ey-.11,0),Vector3(.30,.045,depth-.06),"arch_cedar")
			_box(street,house,"GutterBase",Vector3(side*(half+.035),ey-.14,0),Vector3(.08,.022,depth),"arch_metal")
			for edge: float in [-1.0,1.0]:
				_box(street,house,"GutterRaisedLip",Vector3(side*(half+.035)+edge*.034,ey-.10,0),Vector3(.012,.08,depth),"arch_metal")
	# Real drainpipes have clips, outlet elbows, and shoes down to the plinth.
	for side: float in [-1.0,1.0]:
		var pipe_y := h+.16 if roof=="flat" else h-.16
		if roof=="shed": pipe_y += rise*(side+1)*.5
		_box(street,house,"Downpipe",Vector3(side*(w*.5+.045),pipe_y*.5,d*.5-.22),Vector3(.065,pipe_y,.065),"arch_metal")
		_box(street,house,"RoofOutletElbow",Vector3(side*(w*.5+.12),pipe_y,d*.5-.22),Vector3(.24,.065,.065),"arch_metal")
		_box(street,house,"DownpipeShoe",Vector3(side*(w*.5+.045),.055,d*.5-.30),Vector3(.08,.11,.22),"arch_metal")
		for yy: float in [.6,2.4,3.8]:
			_box(street,house,"PipeFixingClip",Vector3(side*(w*.5+.025),yy,d*.5-.22),Vector3(.11,.035,.10),"arch_metal")

static func _roof_closure(street: Node3D, house: Node3D, w: float, d: float, h: float, rise: float, roof: String) -> void:
	var half := w*.5+.32
	var low := rise*(1.0-w*.5/half) if roof=="gable" else rise*(.5-w*.5/half*.5)
	var high := rise if roof=="gable" else rise*(.5+w*.5/half*.5)
	var mats: Dictionary=street.get("materials")
	for end: float in [-1.0,1.0]:
		var z := end*(d*.5-.12)
		_box(street,house,"RoofSpringFrieze",Vector3(0,h+low*.5,z),Vector3(w,low,.24),"arch_plaster")
		var prism := PrismMesh.new()
		prism.left_to_right=.5 if roof=="gable" else 1.0
		prism.size=Vector3(w,high-low,.24)
		var node := MeshInstance3D.new()
		node.name="NativeClosedRoofPrism"
		node.position=Vector3(0,h+low+(high-low)*.5,z)
		node.mesh=prism
		node.material_override=mats.arch_plaster
		house.add_child(node)
	if roof=="shed":
		_box(street,house,"ShedHighSideClosure",Vector3(w*.5-.12,h+rise*.48,0),Vector3(.24,rise*.96,d-.48),"arch_mineral")

static func _expression(street: Node3D, house: Node3D, spec: Dictionary) -> void:
	var w := float(spec.w)
	var d := float(spec.d)
	var front := house.get_node("CourtFront") as Node3D
	var maker := String(spec.roof)=="shed"
	var porch := String(spec.roof)=="flat"
	if maker:
		# Workroom header joins the two broad working windows and entry portal.
		_box(street,front,"WorkroomContinuousLintel",Vector3(0,2.91,-.095),Vector3(w-.36,.18,.19),"arch_cedar")
		for x: float in [-3.68,-1.62,1.62,3.68]:
			_box(street,front,"WorkroomLintelCorbel",Vector3(x,2.76,-.10),Vector3(.10,.25,.22),"arch_cedar")
		for side: float in [-1.0,1.0]:
			_box(street,front,"WorkroomStoneSill",Vector3(side*2.65,.78,-.08),Vector3(2.12,.075,.26),"arch_stone")
		return
	if not porch:
		_nishi_frontage(street,house,front)
		return
	else:
		# The porch's side panel stands within its existing recessed2.4m bay.
		for y: float in [.24,2.20]:
			_box(street,front,"RecessedPorchScreenRail",Vector3(.94,y,.47),Vector3(.11,.06,.74),"arch_cedar")
		for slat: int in range(6):
			_box(street,front,"RecessedPorchScreenBlade",Vector3(.94,1.22,.14+float(slat)*.125),Vector3(.05,1.96,.045),"arch_cedar")
		for side: float in [-1.0,1.0]:
			_box(street,front,"PorchCanopyWallCorbel",Vector3(side*.92,2.34,.19),Vector3(.08,.30,.35),"arch_cedar")


static func _nishi_frontage(street: Node3D, house: Node3D, front: Node3D) -> void:
	var frame := Node3D.new()
	frame.name="NishiSupportedFrontage"
	front.add_child(frame)
	var parts: Array[Dictionary] = []
	# Four bearing columns frame the existing closed door and lower windows.
	# Keep the original two physical posts exactly; additions are visual only.
	for side: float in [-1.0,1.0]:
		_box(street,front,"TownhousePorchPost",Vector3(side*1.03,1.32,-.08),Vector3(.10,2.64,.16),"arch_cedar",true)
		for x: float in [side*1.03,side*3.62]:
			var z := -.10 if absf(x)<2 else -.23
			_nishi_part(street,frame,parts,"Footing","soil contact",Vector3(x,-.02,z),Vector3(.26,.10,.26),"arch_stone")
			_nishi_part(street,frame,parts,"Column","footing to beam",Vector3(x,1.32,z),Vector3(.18,2.64,.22),"arch_cedar")
			_nishi_part(street,frame,parts,"ColumnShoe","protected timber end",Vector3(x,.07,z),Vector3(.21,.14,.24),"arch_metal")
			_nishi_part(street,frame,parts,"PostCap","column to beam bearing",Vector3(x,2.60,-.20),Vector3(.28,.12,.38),"arch_cedar")
	_nishi_part(street,frame,parts,"FrontBeam","continuous supported lintel",Vector3(0,2.67,-.26),Vector3(7.72,.18,.18),"arch_cedar")
	_nishi_part(street,frame,parts,"WallLedger","masonry bearing",Vector3(0,2.70,.115),Vector3(7.72,.14,.15),"arch_cedar")
	for x: float in [-3.62,-2.40,-1.03,0,1.03,2.40,3.62]:
		_nishi_part(street,frame,parts,"RoofJoist","ledger to front beam",Vector3(x,2.73,-.10),Vector3(.075,.10,.68),"arch_cedar")
	_nishi_part(street,frame,parts,"CanopyDeck","closed weather roof",Vector3(0,2.805,-.10),Vector3(7.72,.065,.68),"arch_metal")
	_nishi_part(street,frame,parts,"TimberSoffit","closed underside",Vector3(0,2.755,-.10),Vector3(7.62,.035,.66),"arch_cedar")
	_nishi_part(street,frame,parts,"FoldedFrontDrip","drip into open gutter",Vector3(0,2.76,-.438),Vector3(7.76,.16,.018),"arch_metal")
	for side: float in [-1.0,1.0]:
		_nishi_part(street,frame,parts,"RoofEndFascia","closed canopy end",Vector3(side*3.84,2.76,-.10),Vector3(.04,.16,.68),"arch_cedar")
	_nishi_part(street,frame,parts,"OpenGutterBase","open rain channel",Vector3(0,2.627,-.405),Vector3(7.70,.018,.075),"arch_metal")
	for z: float in [-.440,-.371]:
		_nishi_part(street,frame,parts,"GutterLip","open channel wall",Vector3(0,2.660,z),Vector3(7.70,.070,.012),"arch_metal")
	for side: float in [-1.0,1.0]:
		_nishi_part(street,frame,parts,"GutterEndCap","sealed gutter end",Vector3(side*3.844,2.657,-.405),Vector3(.012,.060,.075),"arch_metal")
	_nishi_part(street,frame,parts,"RainwaterOutlet","channel to pipe offset",Vector3(3.62,2.60,-.39),Vector3(.065,.065,.12),"arch_metal")
	_nishi_part(street,frame,parts,"Downpipe","continuous pipe",Vector3(3.62,1.30,-.37),Vector3(.065,2.56,.065),"arch_metal")
	_nishi_part(street,frame,parts,"PipeShoe","open discharge over splash block",Vector3(3.62,0,-.38),Vector3(.065,.06,.10),"arch_metal")
	_nishi_part(street,frame,parts,"SplashBlock","soil support",Vector3(3.62,-.06,-.36),Vector3(.24,.02,.14),"arch_stone")
	for y: float in [.50,1.70,2.40]:
		_nishi_part(street,frame,parts,"PipeClip","pipe to column fastening",Vector3(3.62,y,-.34),Vector3(.10,.035,.07),"arch_metal")
	# Shared head shade groups the three real 460mm-deep upper window bays.
	_nishi_part(street,frame,parts,"UpperWindowVisor","shared upper head flashing",Vector3(0,5.77,-.09),Vector3(6.90,.075,.42),"arch_metal")
	for x: float in [-3.30,-1.20,1.20,3.30]:
		_nishi_part(street,frame,parts,"VisorCorbel","shade to masonry bearing",Vector3(x,5.64,-.03),Vector3(.06,.22,.28),"arch_cedar")
	for y: float in [4.05,5.55]:
		_nishi_part(street,frame,parts,"PrivacyRail","centre-bay screen rail",Vector3(0,y,-.16),Vector3(1.62,.06,.08),"arch_cedar")
	for slat: int in range(11):
		_nishi_part(street,frame,parts,"PrivacySlat","balanced centre-bay privacy",Vector3(-.65+float(slat)*.13,4.80,-.20),Vector3(.035,1.50,.08),"arch_cedar")
	for x: float in [-.71,.71]:
		for y: float in [4.05,5.55]:
			_nishi_part(street,frame,parts,"ScreenStandOff","screen to reveal-side fixing",Vector3(x,y,-.075),Vector3(.065,.065,.19),"arch_metal")
	var contacts: Array[Dictionary] = []
	for index: int in range(parts.size()):
		var current: AABB = parts[index].local_bounds
		for previous: int in range(index):
			var other: AABB = parts[previous].local_bounds
			if current.intersects(other):
				contacts.append({"a":parts[index].id,"b":parts[previous].id,"overlap":current.intersection(other)})
	var records := {"id":"NishiSupportedFrontage","root":str(frame.get_path()),"members":parts,"contacts":contacts,
		"construction_type":"supported shallow rain canopy, not an occupied veranda or balcony","roof_members":house.get_meta("nishi_roof_members",[]),
		"approach_clear_world":Rect2(-8.85,256.2,1.70,1.80),"ground_support_y":.02,
		"canopy_deck_world_bounds":AABB(Vector3(-11.86,2.8625,257.56),Vector3(7.72,.065,.68)),
		"existing_post_colliders_retained":2,"new_colliders":0,"upper_window_count_unchanged":3,
		"maximum_front_projection_m":.450,"main_roof_front_overhang_m":.43,
		"load_path":"soil -> footing -> column/shoe -> post cap/front beam -> joists/deck; ledger bears at masonry",
		"rainwater_path":"drip -> open gutter -> offset -> clipped pipe -> shoe -> soil-supported splash block",
		"closed_shell":false,"footprint_unchanged":true,"geometry_units":"metres"}
	frame.set_meta("frontage_construction",records)
	house.set_meta("nishi_frontage_construction",records)

static func _nishi_part(street: Node3D, frame: Node3D, records: Array[Dictionary], label: String, role: String, p: Vector3, size: Vector3, material: String) -> void:
	var id := "Nishi"+label+"_%02d"%records.size()
	var member := _box(street,frame,id,p,size,material)
	var local: AABB = member.transform*member.get_aabb()
	local.position+=(frame.get_parent() as Node3D).position
	var house := frame.get_parent().get_parent() as Node3D
	member.set_meta("nishi_structural_member",id)
	records.append({"id":id,"role":role,"local_bounds":local,"world_bounds":house.transform*local,"material":material})

static func _nishi_roof_record(house: Node3D, member: MeshInstance3D, id: String) -> void:
	var rows: Array = house.get_meta("nishi_roof_members",[])
	var local: AABB = member.transform*member.get_aabb()
	member.set_meta("nishi_roof_member",id)
	rows.append({"id":id,"local_bounds":local,"world_bounds":house.transform*local})
	house.set_meta("nishi_roof_members",rows)

static func _cut(fields: Array[Rect2], cut: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for field: Rect2 in fields:
		var overlap := field.intersection(cut)
		if not overlap.has_area():
			result.append(field)
			continue
		for rect: Rect2 in [Rect2(field.position,Vector2(field.size.x,overlap.position.y-field.position.y)),Rect2(field.position.x,overlap.end.y,field.size.x,field.end.y-overlap.end.y),Rect2(field.position.x,overlap.position.y,overlap.position.x-field.position.x,overlap.size.y),Rect2(overlap.end.x,overlap.position.y,field.end.x-overlap.end.x,overlap.size.y)]:
			if rect.size.x>.001 and rect.size.y>.001: result.append(rect)
	return result

static func _counts(node: Node) -> Dictionary:
	var result := {"meshes":0,"collisions":0}
	for child: Node in node.get_children():
		if child is MeshInstance3D: result.meshes += 1
		if child is StaticBody3D: result.collisions += 1
		var nested := _counts(child)
		result.meshes += int(nested.meshes)
		result.collisions += int(nested.collisions)
	return result


