extends RefCounted
## Metre-scale, source-owned access conversion. No input/global environment edits.
const Door = preload("res://scripts/building_access/door.gd")
const AccessWindow = preload("res://scripts/building_access/window.gd")
const WINDOW_ONLY: Array[String] = []

static func window_only(id: String) -> bool:
	return id in WINDOW_ONLY

static func part(street: Node3D,parent: Node3D,label: String,p: Vector3,size: Vector3,key: String,solid: bool=false) -> MeshInstance3D:
	return street.call("_box",parent,label,p,size,key,solid) as MeshInstance3D

static func group(parent: Node3D,label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.set_meta("creator_protected",true)
	node.set_meta("creator_editable",false)
	parent.add_child(node)
	return node

static func door(street: Node3D,parent: Node3D,p: Vector3,size: Vector2,locked: bool,label: String,glazed: bool=false) -> Node3D:
	var component := Door.new()
	component.name = label
	component.position = p
	component.set_meta("creator_protected",true)
	parent.add_child(component)
	if glazed: component.glazing_material=street.get("materials")["arch_glass"]
	component.configure(Vector3(size.x,size.y,.055),street.get("materials")["arch_cedar"],locked,label)
	component.title = "rear door" if label == "RearServiceDoor" else "flat door" if label == "PrivateFlatStairDoor" else "front door"
	component.allow_inside_unlock = locked
	return component

static func window(street: Node3D,parent: Node3D,x: float,bottom: float,top: float,width: float,label: String="OperableWindow") -> Node3D:
	var height: float = top-bottom
	var cy: float = (top+bottom)*.5
	# Four stationary jambs leave one clear, unobstructed movable sash.
	for side: float in [-1.0,1.0]:
		part(street,parent,"AccessWindowJamb",Vector3(x+side*(width*.5-.04),cy,.28),Vector3(.08,height,.16),"arch_cedar")
		part(street,parent,"AccessWindowHeadSill",Vector3(x,cy+side*(height*.5-.04),.28),Vector3(width-.16,.08,.16),"arch_cedar")
	var component := AccessWindow.new()
	component.name = label
	component.position = Vector3(x,cy,.34)
	component.set_meta("creator_protected",true)
	parent.add_child(component)
	component.configure(Vector3(width-.16,height-.16,.012),street.get("materials")["arch_glass"],true,label)
	component.title = "window"
	component.set_meta("clear_aperture",Vector2(width-.16,height-.16))
	component.set_meta("finished_sill_y",bottom+.08)
	return component

static func cut(fields: Array[Rect2],opening: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for rect: Rect2 in fields:
		var hit: Rect2 = rect.intersection(opening)
		if not hit.has_area():
			result.append(rect)
			continue
		for piece: Rect2 in [Rect2(rect.position,Vector2(rect.size.x,hit.position.y-rect.position.y)),Rect2(rect.position.x,hit.end.y,rect.size.x,rect.end.y-hit.end.y),Rect2(rect.position.x,hit.position.y,hit.position.x-rect.position.x,hit.size.y),Rect2(hit.end.x,hit.position.y,rect.end.x-hit.end.x,hit.size.y)]:
			if piece.size.x>.001 and piece.size.y>.001: result.append(piece)
	return result

static func elevation(street: Node3D,parent: Node3D,label: String,origin: Vector3,yaw: float,width: float,height: float,openings: Array[Dictionary],material: String,visual: bool=true) -> Node3D:
	var face := group(parent,label)
	face.position = origin
	face.rotation.y = yaw
	var fields: Array[Rect2] = [Rect2(-width*.5,0,width,height)]
	for opening: Dictionary in openings:
		fields = cut(fields,Rect2(float(opening.x)-float(opening.w)*.5,float(opening.bottom),float(opening.w),float(opening.top)-float(opening.bottom)))
	for rect: Rect2 in fields:
		var p := Vector3(rect.get_center().x,rect.get_center().y,.12)
		var size := Vector3(rect.size.x,rect.size.y,.24)
		if visual: part(street,face,"MasonryAroundRealOpening",p,size,material,true)
		else: street.call("_solid",face,"WallAroundRealOpening",p,size)
	return face

static func finish_house(street: Node3D,house: Node3D,id: String,width: float,depth: float,front_z: float,ground_y: float,height: float,door_x: float,door_z: float) -> void:
	var normal: bool = not window_only(id)
	var root := group(house,"BuildingAccessInterior")
	var floor_y: float = 3.25
	root.set_meta("residential_inner_bounds",AABB(Vector3(-width*.5+.24,ground_y,front_z+.24),Vector3(width-.48,height-ground_y-.20,depth-.48)))
	var stair_x: float = -width*.5+.40
	var stair_z: float = minf(front_z+4.10,front_z+depth-4.05)
	var stairs: Array[Vector3] = floors(street,root,width-.48,depth-.48,front_z+.24,ground_y,floor_y,true,stair_x,stair_z)
	part(street,root,"HabitableCeiling",Vector3(0,height-.15,front_z+depth*.5),Vector3(width-.48,.10,depth-.48),"arch_interior",true)
	furnish(street,root,width,depth,front_z,ground_y,floor_y,false)
	var points: Array[Vector3] = [Vector3(door_x,ground_y,door_z-1.4),Vector3(door_x,ground_y,door_z-.75),Vector3(door_x,ground_y,door_z+1.15)]
	# Turn only after clearing the full open leaf and standing capsule radius.
	points.append(Vector3(door_x,ground_y,front_z+2.35))
	points.append(Vector3(stair_x+.55,ground_y,front_z+2.35))
	points.append(stairs[0])
	var window_points: Array[Vector3] = []
	var window_ref := ""
	if not normal:
		var entry_x: float = 1.30
		window_points = ground_window_landing(street,root,Vector3(entry_x,0,front_z),0.0,ground_y,.85)
		for node: Node in house.find_children("GroundEntryWindow*","StaticBody3D",true,false): window_ref=str(node.get_path())
	register(street,house,id,normal,floor_y,points,stairs,window_points,window_ref,{"capsule":Vector2(.72,1.75),"upper_floor_m":floor_y,"ground_floor_m":ground_y,"width_m":width,"depth_m":depth,"front_z_m":front_z,"height_m":height,"clear_window_aperture_m":Vector2(1.84,1.96) if not normal else Vector2.ZERO,"window_finished_sill_m":.85 if not normal else 0.0})

static func floors(street: Node3D,root: Node3D,width: float,depth: float,z_start: float,ground_y: float,upper_y: float,normal: bool,stair_x: float,stair_z: float,render_ground: bool=true) -> Array[Vector3]:
	if render_ground:
		var ground_visual := part(street,root,"WalkableGroundFloor",Vector3(0,ground_y-.065,z_start+depth*.5),Vector3(width,.13,depth),"arch_floor",true)
		# _box creates a sibling collider; raise only the render mesh above the plinth.
		ground_visual.position.y += .003
	else:
		# Shops already render their authored joinery floor at this same height.
		street.call("_solid",root,"WalkableGroundFloorCollision",Vector3(0,ground_y-.065,z_start+depth*.5),Vector3(width,.13,depth))
	var fields: Array[Rect2] = [Rect2(-width*.5,z_start,width,depth)]
	if normal: fields=cut(fields,Rect2(stair_x,stair_z,2.35,3.62))
	for rect: Rect2 in fields:
		part(street,root,"UpperFloorAroundStairOpening",Vector3(rect.get_center().x,upper_y-.09,rect.get_center().y),Vector3(rect.size.x,.18,rect.size.y),"arch_floor",true)
	if normal: return stair(street,root,stair_x,stair_z,ground_y,upper_y)
	return []

static func ramp(parent: Node3D,label: String,x: float,width: float,z0: float,z1: float,y0: float,y1: float) -> void:
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for xx: float in [x-width*.5,x+width*.5]:
		points.append(Vector3(xx,minf(y0,y1)-.12,z0))
		points.append(Vector3(xx,y0,z0))
		points.append(Vector3(xx,y1,z1))
		points.append(Vector3(xx,minf(y0,y1)-.12,z1))
	shape.points = points
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

static func stair(street: Node3D,root: Node3D,x0: float,z0: float,ground_y: float,upper_y: float) -> Array[Vector3]:
	var mid: float = (ground_y+upper_y)*.5
	var rise: float = (upper_y-ground_y)/18.0
	var left: float = x0+.55
	var right: float = x0+1.80
	for i: int in range(9):
		var lower_top: float = ground_y+rise*float(i+1)
		var upper_top: float = mid+rise*float(i+1)
		part(street,root,"LowerStairTread",Vector3(left,(ground_y+lower_top-rise*.5)*.5,z0-.28+(float(i)+.5)*.28),Vector3(1.10,lower_top-ground_y-rise*.5,.28),"arch_cedar")
		part(street,root,"UpperStairTread",Vector3(right,(mid+upper_top-rise*.5)*.5,z0+2.80-(float(i)+.5)*.28),Vector3(1.10,upper_top-mid-rise*.5,.28),"arch_cedar")
	ramp(root,"LowerContinuousStairRamp",left,1.10,z0-.28,z0+2.26,ground_y,mid)
	ramp(root,"UpperContinuousStairRamp",right,1.10,z0+2.80,z0+.28,mid,upper_y)
	part(street,root,"StairTurningLanding",Vector3(x0+1.175,mid-.07,z0+2.93),Vector3(2.35,.14,1.38),"arch_floor",true)
	part(street,root,"StairUpperExitNosing",Vector3(right,upper_y-.07,z0+.14),Vector3(1.10,.14,.28),"arch_floor",true)
	# Fixed guards around the open floor, preserving the upper-flight exit gap.
	for zz: float in [z0+.12,z0+1.81,z0+3.50]:
		part(street,root,"StairVoidGuardPost",Vector3(x0+2.35,upper_y+.53,zz),Vector3(.045,1.06,.045),"arch_cedar",true)
	part(street,root,"StairVoidHandrail",Vector3(x0+2.35,upper_y+1.05,z0+1.81),Vector3(.065,.06,3.62),"arch_cedar",true)
	part(street,root,"StairVoidLowerGuard",Vector3(x0+2.35,upper_y+.50,z0+1.81),Vector3(.045,.045,3.62),"arch_cedar",true)
	part(street,root,"StairFrontGuard",Vector3(left,upper_y+.55,z0),Vector3(1.10,1.10,.035),"arch_cedar",true)
	return [Vector3(left,ground_y,z0-.65),Vector3(left,mid,z0+2.24),Vector3(left,mid,z0+3.08),Vector3(right,mid,z0+3.08),Vector3(right,mid,z0+2.80),Vector3(right,upper_y,z0+.28),Vector3(right,upper_y,z0-.55),Vector3(.5,upper_y,z0-.8)]

static func ground_window_landing(street: Node3D,root: Node3D,origin: Vector3,yaw: float,ground_y: float,sill_y: float,depth: float=1.45) -> Array[Vector3]:
	var landing := group(root,"GroundWindowInnerLanding")
	landing.position = origin
	landing.rotation.y = yaw
	part(street,landing,"SupportedWindowLanding",Vector3(0,(ground_y+sill_y)*.5,.175+.325),Vector3(1.08,sill_y-ground_y,.65),"arch_floor",true)
	ramp(landing,"WindowLandingDescent",0.0,1.08,.825,1.825,sill_y,ground_y)
	var points: Array[Vector3] = [Vector3(0,ground_y,-1.4),Vector3(0,ground_y,-.65),Vector3(0,sill_y+.06,.83),Vector3(0,ground_y,depth+.75)]
	var result: Array[Vector3] = []
	for point: Vector3 in points: result.append(landing.transform*point)
	return result

static func loot_anchor(parent: Node3D,house_id: String,label: String,at: Vector3,extent: Vector2,upper: bool,clearance: float=.60,yaw: float=0.0,approach: Vector3=Vector3.INF) -> void:
	var marker := Marker3D.new()
	marker.name = label
	marker.position = at
	marker.rotation.y = yaw
	marker.set_meta("creator_protected",true)
	marker.set_meta("residential_loot_anchor",true)
	marker.set_meta("residential_house_id",house_id)
	marker.set_meta("residential_surface",label)
	marker.set_meta("residential_upper_floor",upper)
	marker.set_meta("support_extent",extent)
	marker.set_meta("clearance_height",clearance)
	if approach.is_finite(): marker.set_meta("approach_local",approach)
	parent.add_child(marker)
	marker.add_to_group("residential_loot_sites")

static func furnish(street: Node3D,root: Node3D,width: float,depth: float,front_z: float,ground_y: float,upper_y: float,shop: bool) -> void:
	# Spawn anchors belong to actual, colliding household surfaces. Shop fronts
	# receive only upstairs flat anchors; no commercial-ground-floor loot sites.
	var anchors := group(root,"ResidentialLootAnchors")
	var house_id: String = str(root.get_parent().name)
	var x: float = width*.5-1.25
	var bed_z: float = front_z+minf(5.15,depth-2.0)
	part(street,root,"UpstairsTimberBed",Vector3(x,upper_y+.20,bed_z),Vector3(1.35,.40,2.02),"arch_cedar",true)
	part(street,root,"UpstairsMattress",Vector3(x,upper_y+.46,bed_z),Vector3(1.27,.16,1.94),"arch_linen",true)
	part(street,root,"UpstairsPillow",Vector3(x,upper_y+.58,bed_z+.70),Vector3(.65,.12,.36),"arch_linen")
	part(street,root,"UpstairsWardrobe",Vector3(-.25,upper_y+.90,front_z+depth-.65),Vector3(1.10,1.80,.48),"arch_pale_wood",true)
	loot_anchor(anchors,house_id,"bed_top",Vector3(x,upper_y+.54,bed_z-.22),Vector2(1.23,1.42),true,.60,0.0,Vector3(x-1.20,upper_y,bed_z))
	loot_anchor(anchors,house_id,"bedside_floor",Vector3(x-1.20,upper_y,bed_z),Vector2(1.80,.85),true,.60,PI*.5,Vector3(x-1.20,upper_y,bed_z-1.20))
	# Kept ahead of the stair void, clear of the main upper exit and furnishings.
	loot_anchor(anchors,house_id,"upstairs_floor",Vector3(width*.5-1.25,upper_y,front_z+3.45),Vector2(1.50,.70),true,.60,0.0,Vector3(x-1.0,upper_y,front_z+3.45))
	if shop: return
	# Front entry and the left-hand stair approach stay clear. Small homes share
	# furniture dimensions, with their rear fixtures adjusted to actual depth.
	# Hidden stand-ins keep collision and loot surfaces; models are dressed over them.
	part(street,root,"HomeLowSofa",Vector3(width*.5-1.35,ground_y+.38,front_z+3.30),Vector3(1.65,.76,.70),"arch_linen",true).visible=false
	var table_x: float = .25
	var table_z: float = front_z+3.20
	part(street,root,"HomeDiningTable",Vector3(table_x,ground_y+.71,table_z),Vector3(1.50,.08,.85),"arch_cedar",true).visible=false
	for dx: float in [-.66,.66]:
		for dz: float in [-.335,.335]:
			part(street,root,"DiningTableLeg",Vector3(table_x+dx,ground_y+.335,table_z+dz),Vector3(.06,.67,.06),"arch_cedar",true).visible=false
	loot_anchor(anchors,house_id,"table_top",Vector3(table_x,ground_y+.75,table_z),Vector2(1.46,.81),false,.60,0.0,Vector3(table_x,ground_y,front_z+1.90))
	loot_anchor(anchors,house_id,"under_table",Vector3(table_x,ground_y,table_z),Vector2(1.20,.55),false,.63,0.0,Vector3(table_x,ground_y,front_z+1.90))
	var kitchen_x: float = width*.5-.67
	var kitchen_z: float = front_z+depth-1.20
	part(street,root,"HomeKitchenCabinet",Vector3(kitchen_x,ground_y+.44,kitchen_z),Vector3(.80,.88,1.80),"arch_pale_wood",true)
	part(street,root,"KitchenCounterTop",Vector3(kitchen_x,ground_y+.91,kitchen_z+.41),Vector3(.86,.06,.92),"arch_stone",true)
	loot_anchor(anchors,house_id,"kitchen_counter",Vector3(kitchen_x,ground_y+.94,kitchen_z+.41),Vector2(.80,.84),false,.60,0.0,Vector3(kitchen_x-1.05,ground_y,kitchen_z+.41))
	# A shallow basin recessed below its four metal rims, with a supported
	# draining board for small pickups beside the bowl, not floating over it.
	var sink_z: float = kitchen_z-.47
	part(street,root,"SinkBasinBottom",Vector3(kitchen_x,ground_y+.885,sink_z),Vector3(.62,.025,.55),"arch_metal",true)
	for dx: float in [-.37,.37]:
		part(street,root,"SinkSideRim",Vector3(kitchen_x+dx,ground_y+.925,sink_z),Vector3(.08,.05,.78),"arch_metal",true)
	for dz: float in [-.35,.35]:
		part(street,root,"SinkEndRim",Vector3(kitchen_x,ground_y+.925,sink_z+dz),Vector3(.66,.05,.08),"arch_metal",true)
	part(street,root,"SinkTapStem",Vector3(kitchen_x+.28,ground_y+1.075,sink_z+.25),Vector3(.035,.25,.035),"arch_metal")
	part(street,root,"SinkTapSpout",Vector3(kitchen_x+.20,ground_y+1.19,sink_z+.25),Vector3(.19,.035,.035),"arch_metal")
	loot_anchor(anchors,house_id,"kitchen_sink",Vector3(kitchen_x,ground_y+.8975,sink_z),Vector2(.58,.51),false,.24,0.0,Vector3(kitchen_x-1.05,ground_y,sink_z))
	var toilet_x: float = .15
	var toilet_z: float = front_z+depth-1.0
	part(street,root,"ToiletPedestal",Vector3(toilet_x,ground_y+.20,toilet_z),Vector3(.29,.40,.41),"arch_linen",true)
	part(street,root,"ToiletClosedLid",Vector3(toilet_x,ground_y+.445,toilet_z-.08),Vector3(.43,.07,.57),"arch_linen",true)
	part(street,root,"ToiletCistern",Vector3(toilet_x,ground_y+.57,toilet_z+.27),Vector3(.45,.60,.19),"arch_linen",true)
	part(street,root,"ToiletFlushButton",Vector3(toilet_x+.12,ground_y+.881,toilet_z+.27),Vector3(.04,.022,.04),"arch_metal")
	loot_anchor(anchors,house_id,"toilet",Vector3(toilet_x,ground_y+.48,toilet_z-.10),Vector2(.39,.49),false,.45,0.0,Vector3(toilet_x+.90,ground_y,toilet_z-.10))

static func register(street: Node3D,house: Node3D,id: String,normal: bool,floor_y: float,entry: Array[Vector3],stairs: Array[Vector3],windows: Array[Vector3],window_ref: String,dimensions: Dictionary) -> void:
	var doors: Array[String] = []
	var panes: Array[String] = []
	for node: Node in house.find_children("*","Node3D",true,false):
		if node.get_meta("building_access_kind","")=="door": doors.append(str(node.get_path()))
		if node.get_meta("building_access_kind","")=="window": panes.append(str(node.get_path()))
	if not window_ref.is_empty():
		var entry_pane := house.get_node_or_null(NodePath(window_ref))
		if entry_pane!=null: entry_pane.can_open = id not in ["WestCornerWorkshopResidence","YakitoriShop"]
	var world_entry: Array[Vector3] = []
	var world_stairs: Array[Vector3] = []
	var world_windows: Array[Vector3] = []
	for point: Vector3 in entry: world_entry.append(house.to_global(point))
	for point: Vector3 in stairs: world_stairs.append(house.to_global(point))
	for point: Vector3 in windows: world_windows.append(house.to_global(point))
	var probe_z: float = float(dimensions.front_z_m)+1.0
	var half_width: float = float(dimensions.width_m)*.5
	var solid_probes: Array = []
	for side: float in [-1.0,1.0]:
		solid_probes.append([house.to_global(Vector3(side*(half_width+.50),1.20,probe_z)),house.to_global(Vector3(side*(half_width-.50),1.20,probe_z))])
	var report := {"solid_wall_probe_pairs_world":solid_probes,"id":id,"root_path":str(house.get_path()),"access_mode":"normal_stairs" if normal else "window_initial_locked","initial_window_required":not normal,"initial_window_openable":id not in ["WestCornerWorkshopResidence","YakitoriShop"],"upper_floor_local_y":floor_y,"doors":doors,"windows":panes,"entry_window":window_ref,"entry_waypoints_local":entry,"stair_waypoints_local":stairs,"window_waypoints_local":windows,"entry_waypoints_world":world_entry,"stair_waypoints_world":world_stairs,"window_waypoints_world":world_windows,"dimensions":dimensions,"stairs":true,"whole_volume_collision_removed":true,"furnished":true}
	house.set_meta("building_access",report)
	var registry: Array = street.get_meta("building_access_registry",[])
	registry.append(report)
	street.set_meta("building_access_registry",registry)

static func finish_shop(street: Node3D,shop: Node3D,spec: Dictionary) -> void:
	var id: String = str(spec.id)
	var w: float = float(spec.w)
	var normal: bool = not window_only(id)
	var root := group(shop,"BuildingAccessInterior")
	var upper: float = 3.30
	root.set_meta("residential_inner_bounds",AABB(Vector3(-w*.5+.25,upper,.24),Vector3(w-.50,float(spec.eave)-upper-.22,7.50)))
	var stairs: Array[Vector3] = []
	if id=="YakitoriShop":
		stairs = straight_shop_stair(street,root,upper)
	else:
		stairs = floors(street,root,w-.50,7.50,.24,.11,upper,true,-w*.5+.50,4.10,false)
	furnish(street,root,w,8.0,0,.11,upper,true)
	part(street,root,"HabitableUpperCeiling",Vector3(0,float(spec.eave)-.22,4.0),Vector3(w-.50,.08,7.50),"arch_interior",true)
	# Rear wall is genuinely split for a useful ground-level rear service door.
	var rear_x: float = w*.5-1.05 if id in ["UedaBooks","HinataDaily"] else 0.0
	var rear_openings: Array[Dictionary] = [{"x":-rear_x,"w":1.10,"bottom":.11,"top":2.30}]
	var rear := elevation(street,root,"ShopRearWallWithDoor",Vector3(0,0,7.80),PI,w,float(spec.eave),rear_openings,str(spec.wall))
	door(street,rear,Vector3(-rear_x,.11,.20),Vector2(1.02,2.15),false,"RearServiceDoor")
	# Front collisions follow the real shop glazing and 970mm entrance leaf.
	var span: float = w*.5-.965
	var fronts: Array[Dictionary] = [{"x":-.31,"w":.97,"bottom":.11,"top":2.30},{"x":.5075,"w":.535,"bottom":.19,"top":2.67}]
	for side: float in [-1.0,1.0]:
		fronts.append({"x":side*(.865+span*.5),"w":span-.07,"bottom":.51,"top":2.81})
		fronts.append({"x":side*w*.25,"w":1.28 if w<6 else w*.285,"bottom":4.10,"top":minf(6.03,float(spec.eave)-.38)})
	elevation(street,root,"ShopFrontPerimeterCollision",Vector3.ZERO,0,w,float(spec.eave),fronts,str(spec.wall),false)
	var window_points: Array[Vector3] = []
	var window_ref := ""
	if not normal:
		private_stair_hall(street,root,id,w,upper)
		var entry_z: float = 5.80 if id=="YakitoriShop" else 3.15
		var side_origin := Vector3(-w*.5,0,entry_z)
		if id=="YakitoriShop":
			# Window exits directly onto the real rising stair; no solid block or
			# descent ramp crosses the separate flat private-door landing at z7.10.
			var platform := group(root,"GroundWindowInnerLanding")
			platform.position=side_origin
			platform.rotation.y=PI*.5
			part(street,platform,"ShallowWindowSillLanding",Vector3(0,.77,.30),Vector3(1.04,.16,.60),"arch_floor",true)
			window_points=[Vector3(-w*.5-1.4,.11,5.80),Vector3(-w*.5-.65,.11,5.80),Vector3(-1.725,.85,5.80)]
			stairs[0]=Vector3(-1.725,.69,5.80)
		else:
			window_points=ground_window_landing(street,root,side_origin,PI*.5,.11,.85)
			window_points.remove_at(window_points.size()-1)
			window_points.append(Vector3(-w*.5+1.05,.85,3.15))
		if id=="HinataDaily":
			# Begin on the actual sill landing, descend inward (+X), then
			# approach the first flight from its unobstructed ground-floor toe.
			stairs[0]=Vector3(-w*.5+1.05,.326,4.15)
			stairs.insert(0,Vector3(-w*.5+2.18,.11,4.15))
			stairs.insert(0,Vector3(-w*.5+2.18,.11,3.15))
			stairs.insert(0,Vector3(-w*.5+1.825,.11,3.15))
			stairs.insert(0,Vector3(-w*.5+.825,.85,3.15))
			stairs.insert(0,Vector3(-w*.5+.50,.85,3.15))
		for node: Node in shop.find_children("GroundEntryWindow*","StaticBody3D",true,false): window_ref=str(node.get_path())
	register(street,shop,id,normal,upper,[Vector3(-.31,.11,-1.0),Vector3(-.31,.11,-.50),Vector3(-.31,.11,1.5)],stairs,window_points,window_ref,{"capsule":Vector2(.72,1.75),"upper_floor_m":upper,"ground_floor_m":.11,"width_m":w,"depth_m":8.0,"front_z_m":0.0,"height_m":float(spec.eave),"clear_window_aperture_m":Vector2(1.04,1.98) if not normal else Vector2.ZERO,"window_finished_sill_m":.85 if not normal else 0.0,"ground_shop_door_unlocked":true,"private_stair_hall_locked":not normal})
	# Measured connector routes go around existing visual shop fixtures as well
	# as the colliding structural stair; they do not phase through the displays.
	var connector: Array[Vector3] = [Vector3(-.31,.11,1.5)]
	if id == "MoriCoffee":
		connector.append_array([Vector3(-.31,.11,1.70),Vector3(-2.60,.11,1.70),Vector3(-2.60,.11,.90),Vector3(-4.20,.11,.90),Vector3(-4.20,.11,3.45)])
	elif id == "UedaBooks":
		connector.append_array([Vector3(-.31,.11,1.90),Vector3(-4.45,.11,1.90)])
	elif id == "HinataDaily":
		connector.append_array([Vector3(-.31,.11,2.25),Vector3(-3.80,.11,2.25),Vector3(-3.80,.11,3.45)])
	else:
		connector.append_array([Vector3(-.31,.11,1.75),Vector3(-.75,.11,1.75),Vector3(-.75,.11,7.05),Vector3(-1.725,.11,7.05)])
	connector.append(stairs[0])
	var world_connector: Array[Vector3] = []
	for point: Vector3 in connector: world_connector.append(shop.to_global(point))
	var record: Dictionary = shop.get_meta("building_access")
	record["entry_to_stairs_waypoints_local"] = connector
	record["entry_to_stairs_waypoints_world"] = world_connector
	shop.set_meta("building_access",record)

static func straight_shop_stair(street: Node3D,root: Node3D,upper: float) -> Array[Vector3]:
	# Narrow Yakitori has a genuine straight private stair against its left wall.
	street.call("_solid",root,"WalkableGroundFloorCollision",Vector3(0,.045,3.99),Vector3(4.70,.13,7.50))
	var fields: Array[Rect2] = cut([Rect2(-2.35,.24,4.70,7.50)],Rect2(-2.30,2.19,1.15,4.41))
	for rect: Rect2 in fields:
		part(street,root,"UpperFloorAroundStraightStair",Vector3(rect.get_center().x,upper-.09,rect.get_center().y),Vector3(rect.size.x,.18,rect.size.y),"arch_floor",true)
	var rise: float = (upper-.11)/18.0
	for i: int in range(18):
		var top: float = .11+(float(i)+.5)*rise
		part(street,root,"StraightPrivateStairTread",Vector3(-1.725,(.11+top)*.5,6.60-(float(i)+.5)*.245),Vector3(1.15,top-.11,.245),"arch_cedar")
	ramp(root,"StraightPrivateStairRamp",-1.725,1.15,6.60,2.19,.11,upper)
	part(street,root,"StraightStairExitNosing",Vector3(-1.725,upper-.07,2.065),Vector3(1.15,.14,.25),"arch_floor",true)
	for z: float in [2.25,4.35,6.50]: part(street,root,"StraightStairVoidPost",Vector3(-1.15,upper+.52,z),Vector3(.04,1.04,.04),"arch_cedar",true)
	part(street,root,"StraightStairVoidHandrail",Vector3(-1.15,upper+1.04,4.395),Vector3(.06,.055,4.41),"arch_cedar",true)
	part(street,root,"PrivateStairBottomLanding",Vector3(-1.725,.11-.06,7.12),Vector3(1.15,.12,1.04),"arch_floor",true)
	# Split the old upper partition around the actual stair exit doorway.
	var shop: Node3D=root.get_parent()
	for child: Node in shop.get_children():
		if child is Node3D and absf(child.position.z-2.40)<.001 and absf(child.position.y-4.39)<.001 and child.position.x<0: child.free()
	var gaps: Array[Dictionary]=[{"x":-.075,"w":1.16,"bottom":0.0,"top":2.02}]
	elevation(street,root,"UpperFlatPartitionWithStairDoorway",Vector3(-1.65,upper,2.40),0.0,1.90,2.18,gaps,"arch_interior")
	return [Vector3(-1.725,.11,6.70),Vector3(-1.725,upper,2.19),Vector3(-1.725,upper,1.65)]

static func private_stair_hall(street: Node3D,root: Node3D,id: String,width: float,upper: float) -> void:
	var right: float = -1.10 if id=="YakitoriShop" else -width*.5+3.10
	var front: float = 1.50 if id=="YakitoriShop" else 2.30
	var center_z: float = (front+7.80)*.5
	var door_z: float = 7.10 if id=="YakitoriShop" else 3.15
	var openings: Array[Dictionary] = [{"x":door_z-center_z,"w":1.10,"bottom":.11,"top":2.35}]
	var wall := elevation(street,root,"PrivateStairHallSide",Vector3(right,0,center_z),-PI*.5,7.80-front,upper-.18,openings,"arch_interior")
	door(street,wall,Vector3(door_z-center_z,.11,.10),Vector2(1.02,2.15),true,"PrivateFlatStairDoor")
	part(street,root,"PrivateStairHallFrontWall",Vector3((-width*.5+right)*.5,(upper-.18)*.5,front),Vector3(right+width*.5,upper-.18,.10),"arch_interior",true)

static func finish_workroom(street: Node3D,house: Node3D,spec: Dictionary) -> void:
	var root := group(house,"WorkroomAccessInterior")
	part(street,root,"WorkroomWalkingFloor",Vector3(0,-.065,0),Vector3(float(spec.w)-.48,.13,float(spec.d)-.48),"arch_floor",true)
	part(street,root,"WorkroomCeiling",Vector3(0,float(spec.h)-.15,0),Vector3(float(spec.w)-.48,.10,float(spec.d)-.48),"arch_interior",true)
	# A supported work surface on the back wall; entrance and broad windows stay clear.
	part(street,root,"WorkroomTimberBenchTop",Vector3(1.80,.88,3.35),Vector3(2.40,.08,.70),"arch_cedar")
	for x: float in [.72,2.88]:
		for z: float in [3.10,3.60]: part(street,root,"WorkroomBenchLeg",Vector3(x,.42,z),Vector3(.07,.84,.07),"arch_cedar")
	var row := {"id":str(spec.id),"root_path":str(house.get_path()),"residential":false,"floors":1,"stairs":false,"enterable":true,"whole_volume_collision_removed":true}
	var entry: Array[Vector3] = [Vector3(0,0,-float(spec.d)*.5-1.4),Vector3(0,0,-float(spec.d)*.5-.45),Vector3(0,0,-float(spec.d)*.5+2.30)]
	var world_entry: Array[Vector3] = []
	for point: Vector3 in entry: world_entry.append(house.to_global(point))
	row["entry_waypoints_local"] = entry
	row["entry_waypoints_world"] = world_entry
	house.set_meta("building_access",row)
	var extra: Array=street.get_meta("building_access_nonresidential",[])
	extra.append(row)
	street.set_meta("building_access_nonresidential",extra)

static func _shift_fixture(root: Node3D,name: String,delta: Vector3) -> void:
	var fixture := root.get_node_or_null(name) as Node3D
	if fixture==null: return
	fixture.position+=delta
	if fixture.has_meta("fixture_bounds"):
		var bounds: Rect2=fixture.get_meta("fixture_bounds")
		bounds.position+=Vector2(delta.x,delta.z)
		fixture.set_meta("fixture_bounds",bounds)

static func reconcile_shop_fixtures(street: Node3D) -> void:
	for id: String in ["MoriCoffee","UedaBooks","HinataDaily","YakitoriShop"]:
		var shop := street.get_node_or_null(id) as Node3D
		if shop==null: continue
		var root := shop.get_node_or_null("InteriorConstructedShop") as Node3D
		if root==null: continue
		if id=="MoriCoffee":
			_shift_fixture(root,"MoriRearSupplyCupboard",Vector3(3.9,0,0))
			_shift_fixture(root,"MoriRearMenu",Vector3(2.0,0,0))
		elif id in ["UedaBooks","HinataDaily"]:
			var shelf := root.get_node_or_null("BooksLeftWallShelves" if id=="UedaBooks" else "GroceryLeftWallShelves") as Node3D
			if shelf!=null:
				shelf.scale.x=2.0/4.8 if id=="UedaBooks" else 1.2/4.4
				shelf.position.z=2.70 if id=="UedaBooks" else 2.40
				shelf.set_meta("fixture_bounds",Rect2(-5.18 if id=="UedaBooks" else -4.68,1.70 if id=="UedaBooks" else 1.8,.34 if id=="UedaBooks" else .43,2.0 if id=="UedaBooks" else 1.2))
			if id=="HinataDaily": _shift_fixture(root,"LowFrontProduce",Vector3(0,0,-.65))
			var shift: float=1.60 if id=="UedaBooks" else 1.80
			for name: String in ["RearStockCabinet","BackBookWall"]: _shift_fixture(root,name,Vector3(shift,0,0))
		elif id == "YakitoriShop":
			# Preserve a 0.80m customer passage beside the new private stair.
			for index: int in range(6): _shift_fixture(root,"DiningStool%d" % index,Vector3(.12,0,0))
		# Retire only decorative closed leaves replaced by real rear-door components.
		var obsolete := root.get_node_or_null("StaffStockDoor" if id in ["UedaBooks","HinataDaily"] else "RearServiceDoor")
		if obsolete!=null and str(obsolete.get_meta("fixture_role","")) in ["staff_door","visual_service_door"]: obsolete.free()
		var plan: Dictionary=shop.get_meta("logical_shop_plan",{})
		for fixture: Dictionary in plan.get("fixtures",[]):
			var node := root.get_node_or_null(str(fixture.get("name",""))) as Node3D
			if node!=null and node.has_meta("fixture_bounds"): fixture["bounds"]=node.get_meta("fixture_bounds")
		shop.set_meta("logical_shop_plan",plan)
	street.set_meta("building_access_fixture_reconciliation",{"mori_rear_cupboard_shift_x":3.9,"ueda_left_shelf_span":2.0,"hinata_left_shelf_span":1.2,"yakitori_stool_shift_x":.12,"hero_props_modified":false})
