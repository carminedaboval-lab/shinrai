extends RefCounted
## Original constructed residential shells. Shared installed materials only.
## build() is a coroutine (a loading-budget turn per house): await it.
const Budget = preload("res://scripts/shinrai_loading_budget.gd")
const Architecture = preload("res://scripts/midori_south_street_architecture.gd")
const Windows = preload("res://scripts/midori_upper_construction.gd")
const CourtFinishes = preload("res://scripts/midori_court_finishes.gd")
const Access = preload("res://scripts/building_access/geometry.gd")
const AokiFrontage = preload("res://scripts/midori_aoki_frontage.gd")

static func build(street: Node3D) -> Dictionary:
	var group := Node3D.new()
	group.name = "SouthNeighbourhoodBuildings"
	group.set_meta("creator_protected",true)
	street.add_child(group)
	var results: Array[Dictionary] = []
	for spec: Dictionary in [
		{"id":"KobayashiHouse","x":-18.0,"z":228.5,"height":6.25,"rise":1.35,"door":-2.25,"wall":"arch_plaster","roof":"gable","cedar":false},
		{"id":"SugiCourtyardHouse","x":-1.0,"z":231.5,"height":6.55,"rise":.32,"door":2.25,"wall":"arch_mineral","roof":"mono","cedar":true},
		{"id":"AokiHouse","x":15.0,"z":228.5,"height":6.40,"rise":1.85,"door":-2.25,"wall":"arch_plaster","roof":"gable","cedar":true}
	]:
		var house := Node3D.new()
		house.name = spec.id
		house.position = Vector3(float(spec.x),.09,float(spec.z))
		house.set_meta("creator_editable",false)
		house.set_meta("creator_protected",true)
		house.set_meta("creator_object_kind","building")
		house.set_meta("creator_display_name",spec.id)
		group.add_child(house)
		_shell(street,house,spec)
		_roof(street,house,spec)
		if String(spec.id) == "AokiHouse":
			AokiFrontage.build(street,house)
		CourtFinishes.apply(street,house)
		var entry := Vector3(float(spec.x)+float(spec.door),.16,float(spec.z)-.38)
		var bounds := AABB(Vector3(-4,0,-.50),Vector3(8,float(spec.height)+float(spec.rise)+.25,10.0))
		var counts := _counts(house)
		var result := {"id":spec.id,"root":house,"entry_point":entry,"door_plane_z":float(spec.z)+.56,"support_y":.16,"threshold_y":.20,"local_bounds":bounds,"world_bounds":AABB(bounds.position+house.position,bounds.size),"mesh_members":counts.meshes,"collision_count":counts.solids,"window_count":13,"enterable":true}
		
		# Avoid a Node reference in persistent metadata.
		house.set_meta("neighbourhood_construction",{"entry_point":entry,"support_y":.16,"threshold_y":.20,"mesh_members":counts.meshes,"collision_count":counts.solids,"local_bounds":bounds,"window_count":13,"enterable":true})
		results.append(result)
		# One loading-budget turn per house (the three took ~1 s in one frame).
		await Budget.checkpoint(street.get("park"))
	return {"ok":true,"root":group,"buildings":results,"entries":results.map(func(item: Dictionary) -> Vector3: return item.entry_point),"new_buildings":3,"lights_created":0,"source_assets_modified":false,"dependencies":["midori_south_street_architecture.gd","midori_upper_construction.gd","midori_shop_joinery.gd"],"ownership":"three protected residential shells; landscape and circulation owned by parent"}

static func _part(street: Node3D, house: Node3D, label: String, p: Vector3, size: Vector3, key: String, collide: bool = false) -> MeshInstance3D:
	return street.call("_box",house,label,p,size,key,collide) as MeshInstance3D

static func _shell(street: Node3D, house: Node3D, spec: Dictionary) -> void:
	var h := float(spec.height)
	var door := float(spec.door)
	var wall := String(spec.wall)
	# Physical 240mm exterior construction, 180mm mineral plinth and copings.
	_part(street,house,"RaisedConcretePlinth",Vector3(0,-.015,4.5),Vector3(7.2,.19,9),"arch_stone",true)
	_connector_rear(street,house,h,wall)
	for side: float in [-1.0,1.0]:
		_connector_side(street,house,side,h,wall,bool(spec.cedar))
		_part(street,house,"SidePlinthUpstand",Vector3(side*3.51,.19,4.5),Vector3(.20,.30,9),"arch_stone")
		_part(street,house,"SidePlinthCoping",Vector3(side*3.51,.36,4.5),Vector3(.23,.045,9.05),"arch_stone")
		_part(street,house,"CornerCover",Vector3(side*3.57,h*.5,.04),Vector3(.075,h,.22),"arch_cedar")
	# Real accessible front openings; no whole-volume envelope behind the facade.
	var ground_window: float = 1.30 if door<0 else -1.30
	var breached_entry: bool = Access.window_only(str(spec.id))
	var window_bottom: float = .77 if breached_entry else .85
	var window_top: float = 2.89 if breached_entry else 2.35
	var front_openings: Array[Dictionary] = [
		{"x":door,"w":1.16,"bottom":.09,"top":2.35,"door":true},
		{"x":ground_window,"w":2.0,"bottom":window_bottom,"top":window_top,"door":false},
		{"x":-1.85,"w":1.8,"bottom":3.95,"top":5.55,"door":false},
		{"x":1.85,"w":1.8,"bottom":3.95,"top":5.55,"door":false}
	]
	var face := Access.elevation(street,house,"AccessibleFrontElevation",Vector3.ZERO,0.0,7.2,h,front_openings,wall)
	for opening: Dictionary in front_openings:
		if bool(opening.door): continue
		Access.window(street,face,float(opening.x),float(opening.bottom),float(opening.top),float(opening.w),"GroundEntryWindow" if breached_entry and float(opening.bottom)<1.0 else "OperableWindow")
	_part(street,house,"StoreyBand",Vector3(0,3.10,-.01),Vector3(7.2,.40,.045),"arch_cedar")
	_door(street,house,door,str(spec.id))
	# Secondary boarded field carries real 20mm boards plus drained backing.
	Architecture._clad_wall(street,house,"ResidentialCedarFrontField",Vector3(door,3.62,-.10),Vector3(1.4,.50,.16))
	for y: float in [3.345,3.895]:
		_part(street,house,"CedarFieldTermination",Vector3(door,y,-.18),Vector3(1.48,.06,.09),"arch_cedar")
	# The front plinth stops at the door; no stone member blocks the approach.
	for interval: Vector2 in [Vector2(-3.6,door-.68),Vector2(door+.68,3.6)]:
		_part(street,house,"FrontPlinthCoping",Vector3((interval.x+interval.y)*.5,.36,-.025),Vector3(interval.y-interval.x,.045,.22),"arch_stone")
	# Low entrance boundary wall/cap contained within the parcel.
	var wall_x := -3.73 if door<0 else 3.73
	_part(street,house,"EntranceBoundaryWall",Vector3(wall_x,.42,.75),Vector3(.15,.84,1.5),wall,true)
	_part(street,house,"BoundaryStoneCoping",Vector3(wall_x,.855,.75),Vector3(.22,.07,1.56),"arch_stone")
	Access.finish_house(street,house,str(spec.id),7.2,9.0,0.0,.08,h,door,.61)

static func _window(street: Node3D, house: Node3D, x: float, bottom: float, top: float, width: float, narrow: bool) -> void:
	Access.window(street,house,x,bottom,top,width)

static func _door(street: Node3D, house: Node3D, x: float, id: String) -> void:
	_part(street,house,"EntranceApron",Vector3(x,.035,-.06),Vector3(1.50,.07,.78),"arch_stone",true)
	_part(street,house,"DoorThreshold",Vector3(x,.09,.40),Vector3(1.18,.04,.38),"arch_stone",true)
	for side: float in [-1.0,1.0]:
		_part(street,house,"EntranceReveal",Vector3(x+side*.555,1.22,.36),Vector3(.05,2.26,.48),"arch_cedar")
		_part(street,house,"DoorFrame",Vector3(x+side*.52,1.22,.53),Vector3(.075,2.26,.14),"arch_cedar")
	_part(street,house,"DoorRevealHead",Vector3(x,2.31,.36),Vector3(1.16,.08,.48),"arch_cedar")
	Access.door(street,house,Vector3(x,.12,.61),Vector2(.96,2.15),Access.window_only(id),"ResidentialEntranceDoor")
	_part(street,house,"EntranceCanopy",Vector3(x,2.53,.03),Vector3(1.72,.12,1.0),"arch_metal")
	_part(street,house,"CanopySoffit",Vector3(x,2.455,.03),Vector3(1.64,.035,.94),"arch_cedar")
	for side: float in [-1.0,1.0]:
		_part(street,house,"CanopyBracket",Vector3(x+side*.61,2.37,.24),Vector3(.05,.24,.38),"arch_metal")
	_part(street,house,"DoorbellPlate",Vector3(x+.72,1.38,-.018),Vector3(.08,.13,.035),"arch_metal")

static func _roof(street: Node3D, house: Node3D, spec: Dictionary) -> void:
	var h := float(spec.height)
	var rise := float(spec.rise)
	var half := 3.94
	var depth := 9.78
	if String(spec.roof)=="gable":
		var angle := atan2(rise,half)
		for side: float in [-1.0,1.0]:
			var roof := _part(street,house,"PitchedStandingSeamRoof",Vector3(side*half*.5,h+rise*.5,4.5),Vector3(sqrt(half*half+rise*rise),.13,depth),"arch_metal")
			roof.rotation.z = -side*angle
			# Individual standing seams on the built roof planes, spaced 450mm.
			for seam: int in range(22):
				var strip := _part(street,house,"RaisedRoofSeam",Vector3(side*half*.5,h+rise*.5+.078,-.33+float(seam)*.46),Vector3(sqrt(half*half+rise*rise),.025,.025),"arch_metal")
				strip.rotation.z = -side*angle
		_part(street,house,"RidgeCap",Vector3(0,h+rise+.09,4.5),Vector3(.20,.11,depth+.04),"arch_metal")
		for z: float in [-.29,9.29]:
			_gable(street,house,h,rise,z,String(spec.wall))
			# Close the short underside between the projecting gable and wall head.
			_part(street,house,"GableBaseSoffit",Vector3(0,h-.025,-.05 if z<0 else 9.05),Vector3(7.88,.05,.58),"arch_cedar")
			for side: float in [-1.0,1.0]:
				var fascia := _part(street,house,"GableRakeFascia",Vector3(side*half*.5,h+rise*.5-.05,z),Vector3(sqrt(half*half+rise*rise),.19,.09),"arch_cedar")
				fascia.rotation.z = -side*angle
	else:
		var angle := atan2(rise,7.88)
		var roof := _part(street,house,"LowMonoPitchMetalRoof",Vector3(0,h+rise*.5,4.5),Vector3(sqrt(7.88*7.88+rise*rise),.14,depth),"arch_metal")
		roof.rotation.z = angle
		# Closed wedge, rather than a floating flat roof.
		_mono_closure(street,house,h,rise,String(spec.wall))
		_part(street,house,"MonoPitchUpperShadowBand",Vector3(0,h+.06,4.5),Vector3(7.2,.12,9),"arch_shadow")
		for side: float in [-1.0,1.0]:
			_part(street,house,"MonoRoofEdgeFascia",Vector3(side*3.91,h+rise*(side+1)*.5-.04,4.5),Vector3(.10,.22,depth),"arch_cedar")
		for seam: int in range(22):
			var strip := _part(street,house,"MonoRoofSeam",Vector3(0,h+rise*.5+.085,-.33+float(seam)*.46),Vector3(7.89,.025,.025),"arch_metal")
			strip.rotation.z = angle
	# Side eaves, gutters with open channel cross-section and square downpipes.
	for side: float in [-1.0,1.0]:
		var ey := h
		if String(spec.roof)=="mono": ey += rise*(side+1)*.5
		_part(street,house,"EaveSoffit",Vector3(side*3.73,ey-.13,4.5),Vector3(.44,.06,9.62),"arch_cedar")
		_part(street,house,"EaveFascia",Vector3(side*3.92,ey-.075,4.5),Vector3(.08,.21,depth),"arch_cedar")
		_part(street,house,"GutterChannelBase",Vector3(side*3.96,ey-.16,4.5),Vector3(.075,.025,9.68),"arch_metal")
		for edge: float in [-1.0,1.0]:
			_part(street,house,"GutterChannelLip",Vector3(side*3.96+edge*.034,ey-.12,4.5),Vector3(.012,.08,9.68),"arch_metal")
		_part(street,house,"Downpipe",Vector3(side*3.66,(ey-.24)*.5,8.70),Vector3(.065,ey-.24,.065),"arch_metal")
		_part(street,house,"GutterOutletOffset",Vector3(side*3.81,ey-.21,8.70),Vector3(.36,.065,.065),"arch_metal")
		for yy: float in [.7,2.6,4.7]:
			_part(street,house,"PipeWallClip",Vector3(side*3.64,yy,8.70),Vector3(.12,.035,.10),"arch_metal")
		_part(street,house,"DrainShoe",Vector3(side*3.66,.09,8.58),Vector3(.09,.10,.28),"arch_metal")

static func _gable(street: Node3D, house: Node3D, h: float, rise: float, z: float, key: String) -> void:
	var panel := PrismMesh.new()
	panel.size = Vector3(7.88,rise,.08)
	var mesh := MeshInstance3D.new()
	mesh.name = "ConstructedPlasterGable"
	mesh.position = Vector3(0,h+rise*.5,z)
	mesh.mesh = panel
	var mats: Dictionary = street.get("materials")
	mesh.material_override = mats[key]
	house.add_child(mesh)

static func _counts(node: Node) -> Dictionary:
	var result := {"meshes":0,"solids":0}
	for child: Node in node.get_children():
		if child is MeshInstance3D: result.meshes += 1
		if child is StaticBody3D: result.solids += 1
		var nested := _counts(child)
		result.meshes += int(nested.meshes)
		result.solids += int(nested.solids)
	return result


static func _mono_closure(street: Node3D, house: Node3D, h: float, rise: float, key: String) -> void:
	var low := rise*(.5-3.6/7.88)
	var high := rise*(.5+3.6/7.88)
	for z: float in [.12,8.88]:
		_part(street,house,"MonoSpringFrieze",Vector3(0,h+low*.5,z),Vector3(7.2,low,.24),key)
		var panel := PrismMesh.new()
		panel.left_to_right=1.0
		panel.size=Vector3(7.2,high-low,.24)
		var node := MeshInstance3D.new()
		node.name="NativeMonoRoofClosure"
		node.position=Vector3(0,h+low+(high-low)*.5,z)
		node.mesh=panel
		var mats: Dictionary=street.get("materials")
		node.material_override=mats[key]
		house.add_child(node)
	_part(street,house,"MonoHighSideWallClosure",Vector3(3.48,h+rise*.47,4.5),Vector3(.24,rise*.94,8.52),key)

static func _connector_rear(street: Node3D, house: Node3D, h: float, wall: String) -> void:
	var rear := Node3D.new()
	rear.name="CourtFacingRearBays"
	rear.position=Vector3(0,0,9)
	rear.rotation.y=PI
	house.add_child(rear)
	var openings: Array[Rect2]=[]
	for x: float in [-1.8,1.8]:
		openings.append(Rect2(x-.9,.90,1.8,1.55))
		openings.append(Rect2(x-.9,3.95,1.8,1.60))
	_connector_wall(street,rear,7.2,h,openings,wall,false)
	for x: float in [-1.8,1.8]:
		_window(street,rear,x,.90,2.45,1.8,false)
		_window(street,rear,x,3.95,5.55,1.8,false)
		_bay_hood(street,rear,x,2.57,1.98)
	_part(street,rear,"RearServiceMeter",Vector3(3.05,1.12,-.07),Vector3(.24,.36,.14),"arch_metal")
	_part(street,rear,"RearStoreyCedarLedger",Vector3(0,3.20,-.045),Vector3(7.2,.14,.09),"arch_cedar")

static func _connector_side(street: Node3D, house: Node3D, side: float, h: float, wall: String, cedar: bool) -> void:
	var elevation := Node3D.new()
	elevation.name="ConnectorSideWindowBays"
	elevation.position=Vector3(side*3.6,0,4.5)
	elevation.rotation.y=-side*PI*.5
	house.add_child(elevation)
	var openings: Array[Rect2]=[Rect2(-.85,1.0,1.7,1.50),Rect2(-2.65,3.95,1.7,1.60),Rect2(.95,3.95,1.7,1.60)]
	_connector_wall(street,elevation,8.52,h,openings,wall,cedar)
	_window(street,elevation,0,1.0,2.50,1.7,cedar)
	for x: float in [-1.8,1.8]: _window(street,elevation,x,3.95,5.55,1.7,cedar)
	_bay_hood(street,elevation,0,2.62,1.92)
	# Partial upper privacy screen has solid top/bottom rails and wall stand-offs.
	for y: float in [4.05,5.45]:
		_part(street,elevation,"PrivacyScreenRail",Vector3(-1.8,y,-.17),Vector3(1.82,.055,.065),"arch_cedar")
	for index: int in range(7):
		_part(street,elevation,"PrivacyScreenBlade",Vector3(-2.55+float(index)*.14,4.75,-.19),Vector3(.045,1.40,.07),"arch_cedar")
	for y: float in [4.05,5.45]:
		for x: float in [-2.60,-1.0]:
			_part(street,elevation,"ScreenWallMount",Vector3(x,y,-.07),Vector3(.055,.055,.18),"arch_metal")

static func _connector_wall(street: Node3D, elevation: Node3D, w: float, h: float, openings: Array[Rect2], wall: String, cedar: bool) -> void:
	var fields: Array[Rect2]=[Rect2(-w*.5,0,w,h)]
	for opening: Rect2 in openings:
		var next: Array[Rect2]=[]
		for field: Rect2 in fields:
			var cut := field.intersection(opening)
			if not cut.has_area():
				next.append(field)
				continue
			for piece: Rect2 in [Rect2(field.position,Vector2(field.size.x,cut.position.y-field.position.y)),Rect2(field.position.x,cut.end.y,field.size.x,field.end.y-cut.end.y),Rect2(field.position.x,cut.position.y,cut.position.x-field.position.x,cut.size.y),Rect2(cut.end.x,cut.position.y,field.end.x-cut.end.x,cut.size.y)]:
				if piece.size.x>.001 and piece.size.y>.001: next.append(piece)
		fields=next
	for field: Rect2 in fields:
		var pos := Vector3(field.get_center().x,field.get_center().y,.12)
		var size := Vector3(field.size.x,field.size.y,.24)
		street.call("_solid",elevation,"PerimeterWallCollision",pos,size)
		if cedar: Architecture._clad_wall(street,elevation,"ConnectorCedarField",pos,size)
		else: _part(street,elevation,"MineralWallAroundBay",pos,size,wall)

static func _bay_hood(street: Node3D, elevation: Node3D, x: float, y: float, width: float) -> void:
	_part(street,elevation,"WindowRainHood",Vector3(x,y,-.16),Vector3(width,.075,.40),"arch_metal")
	_part(street,elevation,"WindowHoodSoffit",Vector3(x,y-.055,-.16),Vector3(width-.08,.035,.36),"arch_cedar")
	for side: float in [-1.0,1.0]:
		_part(street,elevation,"HoodWallBracket",Vector3(x+side*(width*.5-.18),y-.15,-.08),Vector3(.05,.20,.22),"arch_metal")

