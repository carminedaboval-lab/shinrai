extends RefCounted
## Protected, genuinely enterable ceramics gallery. All dimensions are metres.
## Architecture._materials(street) must already have run. No asset or light writes.
const ORIGIN := Vector3(8.0, .09, 257.5)
const FOOTPRINT := Rect2(3.0, 257.5, 10.0, 10.0)
const BOUNCE_LAYER := 1 << 10
const CHAIR := "res://assets/shinrai/streets/midori_frontage_construction/mori_bentwood_chair.glb"
const CourtFinishes = preload("res://scripts/midori_court_finishes.gd")

static func build(street: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "CeramicsGallery"
	root.position = ORIGIN
	root.set_meta("creator_editable", false)
	root.set_meta("creator_protected", true)
	root.set_meta("creator_object_kind", "building")
	root.set_meta("creator_display_name", "Haku Ceramics Gallery")
	street.add_child(root)
	var exterior := _group(root, "CeramicsGalleryExterior")
	var room := _group(root, "InteriorGalleryRoom")
	var fixtures := _group(room, "InteriorFixtures")
	var sockets_group := _group(room, "InteriorArtSockets")
	var lights_group := _group(room, "InteriorRegisteredLighting")
	var fixture_bounds: Array[Dictionary] = []
	var sockets: Dictionary = {}
	_shell(street, exterior, room)
	_front(street, exterior, room)
	_roof(street, exterior)
	_fit_out(street, fixtures, sockets_group, sockets, fixture_bounds)
	var light_sockets: Array[Dictionary] = []
	for row: Array in [
		["InteriorEntryLight", Vector3(0, 2.40, 1.25), 1.80, 1.60, 5.8],
		["InteriorDisplayLight", Vector3(-2.65, 2.40, 3.65), 1.80, 1.60, 5.8],
		["InteriorBenchLight", Vector3(2.55, 2.40, 8.45), 1.80, 1.60, 5.5],
		["InteriorRoomLight", Vector3(0, 2.40, 6.3), 1.80, 1.60, 6.0]
	]:
		var marker := _socket(lights_group, String(row[0]), row[1], Vector3.ZERO)
		light_sockets.append({"id":row[0], "node":marker, "local_position":marker.position,
			"world_position":ORIGIN + marker.position, "night_energy":row[2], "day_energy":row[3], "range":row[4], "tint":Color("#ffead0")})
		_part(street, lights_group, String(row[0])+"Track", Vector3(marker.position.x, 2.89, marker.position.z), Vector3(.60, .035, .055), "arch_metal")
		_part(street, lights_group, String(row[0])+"CeilingMount", Vector3(marker.position.x, 2.94375, marker.position.z), Vector3(.035, .0725, .035), "arch_metal")
		# Lower practicals spread useful light across displays instead of ceiling pools.
		var housing_y := marker.position.y+.09
		var neck_bottom := housing_y+.085
		_part(street, lights_group, String(row[0])+"HousingNeck", Vector3(marker.position.x, (2.8725+neck_bottom)*.5, marker.position.z), Vector3(.035, 2.8725-neck_bottom, .035), "arch_metal")
		_part(street, lights_group, String(row[0])+"Housing", Vector3(marker.position.x, housing_y, marker.position.z), Vector3(.11, .17, .11), "arch_metal")
		_part(street, lights_group, String(row[0])+"Diffuser", marker.position, Vector3(.085, .012, .085), "warm")
	_name_interior(room)
	_set_exterior_layers(exterior)
	CourtFinishes.apply(street,exterior)
	var counts := _counts(root)
	var route := PackedVector3Array([Vector3(8,.09,255.8),Vector3(8,.09,257.5),Vector3(8,.09,259.0),Vector3(8,.09,261.5),Vector3(8,.09,263.8),Vector3(8,.09,266.2)])
	var door := {"min":Vector3(7.10,.09,257.5),"max":Vector3(8.90,2.49,257.74),"clear_width":1.80,"clear_height":2.40,"plane_z":257.62,"opening_axis":"Z", "leaf":"sliding leaves parked outside clear aperture; static open state"}
	# North sign/cedar trim stand proud of the wall without entering the door void.
	var bounds := AABB(Vector3(-5,-.12,-.06),Vector3(10,5.29,10.06))
	var geometry := {"footprint":FOOTPRINT,"local_bounds":bounds,"world_bounds":AABB(bounds.position+ORIGIN,bounds.size),
		"door_aperture":door,"finished_floor_y":.09,"ceiling_clear_height":2.98,
		"central_clear_aisle":Rect2(6.9,257.84,2.2,8.36),"traversal_waypoints":route,
		"fixture_bounds":fixture_bounds,"mesh_members":counts.meshes,"collision_count":counts.solids,
		"socket_count":sockets.size(),"exterior_revision":"supported weather eave, partial timber screens, contrast sign inset","lights_created":0,"enterable":true,"source_assets_modified":false}
	root.set_meta("ceramics_gallery_construction", geometry)
	return {"ok":true,"id":"CeramicsGallery","root":root,"exterior_group":exterior,"interior_group":room,
		"fixtures_group":fixtures,"sockets_group":sockets_group,"light_group":lights_group,
		"sockets":sockets,"light_sockets":light_sockets,"geometry":geometry,"footprint":FOOTPRINT,
		"local_bounds":bounds,"world_bounds":geometry.world_bounds,"door_aperture":door,
		"traversal_waypoints":route,"fixture_bounds":fixture_bounds,"mesh_members":counts.meshes,
		"collision_count":counts.solids,"finished_floor_y":.09,"enterable":true,"lights_created":0,
		"interior_name_prefix":"Interior","facade_bounce_layer":BOUNCE_LAYER}

static func _group(parent: Node3D, label: String) -> Node3D:
	var group := Node3D.new()
	group.name = label
	parent.add_child(group)
	return group

static func _part(street: Node3D, parent: Node3D, label: String, p: Vector3, size: Vector3, material: String, collide: bool = false) -> MeshInstance3D:
	var part := street.call("_box",parent,label,p,size,material,collide) as MeshInstance3D
	# Repeated sibling labels may become autogenerated node names. Record
	# construction intent at creation, before those names lose their identity.
	if label in ["FrontStonePier","GlazedBayStoneSillWall"]:
		part.set_meta("court_envelope_render",true)
	return part

static func _shell(street: Node3D, exterior: Node3D, room: Node3D) -> void:
	# Finished slab top is local zero: flush to the court's worldY .09 paving.
	_part(street,room,"InteriorContinuousStoneFloor",Vector3(0,-.06,5),Vector3(10,.12,10),"arch_stone",true)
	# Only actual thin wall members collide. No whole-building collision envelope.
	for side: float in [-1.0,1.0]:
		_part(street,exterior,"SideMineralWall",Vector3(side*4.68,1.52,5),Vector3(.24,3.04,9.52),"arch_plaster",true)
		_part(street,room,"InteriorSideFinish",Vector3(side*4.548,1.48,5),Vector3(.024,2.96,9.04),"arch_interior")
		_part(street,room,"InteriorSideSkirting",Vector3(side*4.524,.055,5),Vector3(.024,.11,9.04),"arch_cedar")
	_part(street,exterior,"RearMineralWall",Vector3(0,1.52,9.64),Vector3(9.60,3.04,.24),"arch_plaster",true)
	_part(street,room,"InteriorRearFinish",Vector3(0,1.48,9.508),Vector3(9.10,2.96,.024),"arch_interior")
	_part(street,room,"InteriorRearSkirting",Vector3(0,.055,9.484),Vector3(9.10,.11,.024),"arch_cedar")
	_part(street,room,"InteriorCeiling",Vector3(0,3.04,5),Vector3(9.12,.12,9.04),"arch_interior",true)
	for z: float in [2.1,5.0,7.9]:
		_part(street,room,"InteriorCeilingTimberBeam",Vector3(0,2.995,z),Vector3(9.10,.03,.12),"arch_pale_wood")
	for x: float in [-4.69,4.69]:
		_part(street,exterior,"StoneSidePlinth",Vector3(x,.17,5),Vector3(.25,.34,9.52),"arch_stone")

static func _front(street: Node3D, exterior: Node3D, room: Node3D) -> void:
	# Front wall is explicitly split around two broad glazed bays and an open door.
	for interval: Vector2 in [Vector2(-4.8,-4.4),Vector2(-1.4,-.98),Vector2(.98,1.4),Vector2(4.4,4.8)]:
		_part(street,exterior,"FrontStonePier",Vector3((interval.x+interval.y)*.5,1.52,.12),Vector3(interval.y-interval.x,3.04,.24),"arch_stone",true)
	for x: float in [-2.9,2.9]:
		_part(street,exterior,"GlazedBayStoneSillWall",Vector3(x,.23,.12),Vector3(3.0,.46,.24),"arch_stone",true)
		_part(street,exterior,"GlazedBayHeadWall",Vector3(x,2.79,.12),Vector3(3.0,.50,.24),"arch_plaster",true)
		# 36mm timber frame encloses an actual 10mm glazing pane, not an opaque wall.
		for side: float in [-1.0,1.0]:
			_part(street,exterior,"BayWindowRebatedJamb",Vector3(x+side*1.467,1.50,.105),Vector3(.066,2.08,.15),"arch_cedar")
		for y: float in [.493,2.507]:
			_part(street,exterior,"BayWindowHeadSillFrame",Vector3(x,y,.105),Vector3(3.0,.066,.15),"arch_cedar")
		_part(street,exterior,"BayWindowMullion",Vector3(x,1.5,.105),Vector3(.045,1.948,.13),"arch_metal")
		for side: float in [-1.0,1.0]:
			_part(street,room,"InteriorClearBayGlazing",Vector3(x+side*.728,1.5,.12),Vector3(1.405,1.948,.010),"arch_glass",true)
		_part(street,room,"InteriorBaySill",Vector3(x,.47,.24),Vector3(3.0,.05,.30),"arch_pale_wood")
		_part(street,room,"InteriorBayHeadReveal",Vector3(x,2.55,.24),Vector3(3.0,.025,.24),"arch_interior")
	# Structural opening 1.96m; 80mm reveals stop at +/- .90, leaving 1.80m.
	for side: float in [-1.0,1.0]:
		_part(street,exterior,"DoorTimberJamb",Vector3(side*.94,1.2,.14),Vector3(.08,2.4,.28),"arch_cedar",true)
		# Sliding leaves are permanently parked beside the opening, outside the aisle.
		_part(street,exterior,"ParkedSlidingLeafStile",Vector3(side*1.18,1.20,.29),Vector3(.05,2.36,.055),"arch_cedar")
		_part(street,exterior,"ParkedSlidingLeafOuterStile",Vector3(side*2.04,1.20,.29),Vector3(.05,2.36,.055),"arch_cedar")
		for yy: float in [.045,2.355]:
			_part(street,exterior,"ParkedSlidingLeafRail",Vector3(side*1.61,yy,.29),Vector3(.91,.05,.055),"arch_cedar")
		_part(street,room,"InteriorParkedDoorGlazing",Vector3(side*1.61,1.2,.29),Vector3(.81,2.26,.008),"arch_glass")
		_part(street,exterior,"DoorPull",Vector3(side*1.22,1.14,.25),Vector3(.016,.27,.035),"arch_metal")
	_part(street,exterior,"DoorTimberHead",Vector3(0,2.44,.14),Vector3(1.96,.08,.28),"arch_cedar",true)
	_part(street,exterior,"DoorHeadStonework",Vector3(0,2.76,.12),Vector3(1.96,.56,.24),"arch_plaster",true)
	_part(street,exterior,"SlidingDoorTopTrack",Vector3(0,2.53,.29),Vector3(4.2,.045,.07),"arch_metal")
	# Flush steel sill top remains zero; nothing spans the doorway above the floor.
	_part(street,room,"InteriorFlushThreshold",Vector3(0,-.009,.14),Vector3(1.8,.018,.28),"arch_metal")
	_gallery_frontage(street,exterior)

static func _gallery_frontage(street: Node3D, exterior: Node3D) -> void:
	# A continuous weathering eave is tied to the masonry, with visible cedar
	# soffit and real corbels. No ground-level member enters the door aperture.
	_part(street,exterior,"ContinuousGalleryWeatherEave",Vector3(0,3.015,-.20),Vector3(9.60,.12,.56),"arch_metal")
	_part(street,exterior,"GalleryEaveFrontFascia",Vector3(0,2.97,-.465),Vector3(9.62,.20,.045),"arch_cedar")
	for board: int in range(36):
		_part(street,exterior,"GalleryEaveSoffitBoard",Vector3(-4.66+float(board)*.266,2.94,-.19),Vector3(.260,.03,.52),"arch_cedar")
	for x: float in [-4.56,-1.20,1.20,4.56]:
		_part(street,exterior,"GalleryEaveWallCorbel",Vector3(x,2.81,-.10),Vector3(.10,.28,.30),"arch_cedar")
		_part(street,exterior,"CorbelWallShoe",Vector3(x,2.75,-.015),Vector3(.16,.18,.03),"arch_metal")
	# Quarter-width outer screens preserve the display view and carry their own
	# head/sill rails; the central1.8m sliding-door aperture stays unchanged.
	for side: float in [-1.0,1.0]:
		for y: float in [.50,2.54]:
			_part(street,exterior,"GalleryScreenRail",Vector3(side*4.16,y,-.18),Vector3(.76,.055,.08),"arch_cedar")
			_part(street,exterior,"GalleryScreenPierMount",Vector3(side*4.48,y,-.07),Vector3(.08,.08,.23),"arch_metal")
		for blade: int in range(5):
			_part(street,exterior,"GalleryVerticalScreen",Vector3(side*(3.87+float(blade)*.135),1.52,-.19),Vector3(.045,2.04,.08),"arch_cedar")
		_part(street,exterior,"GalleryDisplaySillNose",Vector3(side*2.9,.46,-.055),Vector3(3.14,.065,.24),"arch_stone")
	# Small entrance ceramic plaque is built by the shop identity pass.
	_gallery_gable_craft(street,exterior)

static func _gallery_gable_craft(street: Node3D, exterior: Node3D) -> void:
	# This thin, non-colliding facade layer turns the plain weather face into a
	# credible ventilated loft without touching the shell, glazing or interior.
	_part(street,exterior,"GalleryGableShadowRail",Vector3(0,4.035,-.105),Vector3(9.12,.055,.045),"arch_metal")
	_part(street,exterior,"GalleryGableVentFrameTop",Vector3(0,4.845,-.125),Vector3(1.46,.055,.050),"arch_cedar")
	_part(street,exterior,"GalleryGableVentFrameBottom",Vector3(0,4.190,-.125),Vector3(1.46,.055,.050),"arch_cedar")
	for side: float in [-1.0,1.0]:
		_part(street,exterior,"GalleryGableVentFrameSide",Vector3(side*.7025,4.5175,-.125),Vector3(.055,.60,.050),"arch_cedar")
	for blade: int in range(7):
		# Real depth leaves a dark reveal either side of every cedar louvre.
		_part(street,exterior,"GalleryGableVentLouvre",Vector3(0,4.245+float(blade)*.09,-.148),Vector3(1.29,.040,.055),"arch_cedar")
	exterior.set_meta("gallery_gable_craft",{"vent_clear_width_m":1.29,"louvre_count":7,"collision_change":0,"shell_unchanged":true})

static func _roof(street: Node3D, exterior: Node3D) -> void:
	# A low loft behind the ceiling gives a 1.5-storey profile; no fake upstairs room.
	for side: float in [-1.0,1.0]:
		_part(street,exterior,"LoftSideWall",Vector3(side*4.68,3.48,5),Vector3(.24,.88,9.52),"arch_plaster")
	for z: float in [.12,9.64]:
		_part(street,exterior,"LoftEndWall",Vector3(0,3.48,z),Vector3(9.60,.88,.24),"arch_plaster")
		_gable(street,exterior,z)
	# Vertical cedar boards provide a real joined field above the shopfront.
	for i: int in range(60):
		_part(street,exterior,"FrontLoftCedarBoard",Vector3(-4.68+float(i)*.158,3.48,-.012),Vector3(.154,.80,.020),"arch_cedar")
	for yy: float in [3.075,3.885]:
		_part(street,exterior,"FrontLoftFieldCap",Vector3(0,yy,-.026),Vector3(9.6,.035,.035),"arch_cedar")
	var run := 4.9
	var rise := 1.1
	var slope := atan2(rise,run)
	var length := sqrt(run*run+rise*rise)
	for side: float in [-1.0,1.0]:
		var plane := _part(street,exterior,"StandingSeamRoof",Vector3(side*run*.5,4.47,5),Vector3(length,.10,9.98),"arch_metal")
		plane.rotation.z = -side*slope
		for seam: int in range(22):
			var rib := _part(street,exterior,"RoofStandingSeam",Vector3(side*run*.5,4.535,.12+float(seam)*.46),Vector3(length,.025,.018),"arch_metal")
			rib.rotation.z = -side*slope
		_part(street,exterior,"EaveSoffit",Vector3(side*4.79,3.84,5),Vector3(.27,.045,9.98),"arch_cedar")
		_part(street,exterior,"EaveFascia",Vector3(side*4.9,3.88,5),Vector3(.055,.17,9.98),"arch_cedar")
		# Open three-sided rain channel, connected to downpipe at the rear corner.
		_part(street,exterior,"GutterChannelBase",Vector3(side*4.955,3.82,5),Vector3(.075,.018,9.80),"arch_metal")
		for edge: float in [-1.0,1.0]:
			_part(street,exterior,"GutterChannelLip",Vector3(side*4.955+edge*.033,3.855,5),Vector3(.009,.07,9.80),"arch_metal")
		_part(street,exterior,"Downpipe",Vector3(side*4.83,1.87,9.48),Vector3(.065,3.74,.065),"arch_metal")
		_part(street,exterior,"GutterOutletOffset",Vector3(side*4.89,3.76,9.48),Vector3(.20,.065,.065),"arch_metal")
		for yy: float in [.65,1.9,3.15]:
			_part(street,exterior,"DownpipeWallClip",Vector3(side*4.82,yy,9.48),Vector3(.10,.035,.10),"arch_metal")
		_part(street,exterior,"DownpipeShoe",Vector3(side*4.83,.07,9.55),Vector3(.065,.10,.20),"arch_metal")
	_part(street,exterior,"RoofRidgeCap",Vector3(0,5.08,5),Vector3(.20,.10,9.98),"arch_metal")
	for z: float in [.045,9.955]:
		for side: float in [-1.0,1.0]:
			var fascia := _part(street,exterior,"GableRakeFascia",Vector3(side*run*.5,4.43,z),Vector3(length,.15,.07),"arch_cedar")
			fascia.rotation.z = -side*slope

static func _gable(street: Node3D, parent: Node3D, z: float) -> void:
	# Closed plaster prism supplies native outward normals, UVs and tangents.
	# The previous two disconnected triangles shaded black under triplanar PBR.
	var panel := PrismMesh.new()
	panel.size = Vector3(9.6,1.08,.24)
	var node := MeshInstance3D.new()
	node.name = "GableMineralClosure"
	node.position = Vector3(0,4.46,z)
	node.mesh = panel
	var mats: Dictionary = street.get("materials")
	node.material_override = mats["arch_plaster"]
	parent.add_child(node)

static func _fit_out(street: Node3D, fixtures: Node3D, sockets_group: Node3D, sockets: Dictionary, bounds: Array[Dictionary]) -> void:
	# Side fixtures leave an uninterrupted 2.2m spine and >1.4m cross aisles.
	_fixture(street,fixtures,bounds,"InteriorHeroPlinth",Vector3(-2.7,.40,3.65),Vector3(.82,.80,.82),"arch_stone")
	_add_art_socket(sockets_group,sockets,"InteriorHeroVaseSocket",Vector3(-2.7,.80,3.65),Vector3(.60,.45,.60),"ceramic_vase_30cm")
	_fixture(street,fixtures,bounds,"InteriorSecondaryPlinth",Vector3(2.7,.31,3.65),Vector3(.65,.62,.65),"arch_stone")
	_add_art_socket(sockets_group,sockets,"InteriorSculptureSocket",Vector3(2.7,.62,3.65),Vector3(.52,.75,.52),"small_sculpture")
	# North window ledges are real display furniture; empty sockets await supplied art.
	for side: float in [-1.0,1.0]:
		var x := side*2.95
		_fixture(street,fixtures,bounds,"InteriorWindowDisplay",Vector3(x,.59,.80),Vector3(2.35,.06,.50),"arch_pale_wood")
		for xx: float in [x-.95,x+.95]:
			_part(street,fixtures,"InteriorWindowDisplayLeg",Vector3(xx,.28,.80),Vector3(.06,.56,.38),"arch_cedar",true)
		for offset: float in [-.67,0,.67]:
			_add_art_socket(sockets_group,sockets,"InteriorWindowCeramicSocket",Vector3(x+offset,.62,.80),Vector3(.40,.42,.40),"display_ceramics")
	# Rear workbench occupies only the east side; legs, top and tool shelf collide.
	_fixture(street,fixtures,bounds,"InteriorWorkbenchTop",Vector3(2.80,.87,8.75),Vector3(2.50,.09,.85),"arch_pale_wood")
	for x: float in [1.68,3.92]:
		for z: float in [8.43,9.06]:
			_part(street,fixtures,"InteriorWorkbenchLeg",Vector3(x,.4125,z),Vector3(.075,.825,.075),"arch_cedar",true)
	_part(street,fixtures,"InteriorWorkbenchLowerShelf",Vector3(2.8,.24,8.75),Vector3(2.35,.035,.72),"arch_cedar",true)
	_add_art_socket(sockets_group,sockets,"InteriorWorkbenchCeramicsSocket",Vector3(2.80,.915,8.75),Vector3(1.6,.40,.60),"works_in_progress")
	# A folded linen pad and stacked boards support craft use without fake pottery.
	_part(street,fixtures,"InteriorWorkbenchLinenPad",Vector3(1.93,.926,8.70),Vector3(.40,.022,.46),"arch_linen")
	for i: int in range(3):
		_part(street,fixtures,"InteriorDryingBoard",Vector3(3.70,.95+float(i)*.024,8.77),Vector3(.36,.018,.50),"arch_pale_wood")
	_fixture(street,fixtures,bounds,"InteriorSideCounter",Vector3(4.14,.47,6.27),Vector3(.72,.94,1.60),"arch_cedar")
	_part(street,fixtures,"InteriorCounterStoneTop",Vector3(4.14,.96,6.27),Vector3(.78,.04,1.68),"arch_stone",true)
	for z: float in [5.91,6.62]:
		_part(street,fixtures,"InteriorCounterDrawerFront",Vector3(3.769,.68,z),Vector3(.025,.25,.65),"arch_pale_wood")
		_part(street,fixtures,"InteriorCounterDrawerPull",Vector3(3.744,.68,z),Vector3(.024,.025,.15),"arch_metal")
	_add_art_socket(sockets_group,sockets,"InteriorCounterDisplaySocket",Vector3(4.14,.98,6.30),Vector3(.58,.40,1.20),"small_ceramics")
	# West wall storage: exact shelf/side panel members, not a solid furniture box.
	for z: float in [5.66,7.94]:
		_fixture(street,fixtures,bounds,"InteriorShelfUpright",Vector3(-4.30,1.02,z),Vector3(.38,2.04,.045),"arch_cedar")
	for yy: float in [.23,.80,1.37,1.94]:
		_fixture(street,fixtures,bounds,"InteriorWallDisplayShelf",Vector3(-4.30,yy,6.80),Vector3(.40,.035,2.30),"arch_pale_wood")
		for zz: float in [6.05,6.80,7.55]:
			_add_art_socket(sockets_group,sockets,"InteriorShelfCeramicSocket",Vector3(-4.30,yy+.0175,zz),Vector3(.32,.43,.48),"display_ceramics")
	# Frames are joinery only. Parent owns painting imagery and art placement.
	for x: float in [-2.9,0]:
		var p := Vector3(x,1.70,9.46)
		_frame(street,fixtures,p,1.12,1.18)
		_add_art_socket(sockets_group,sockets,"InteriorPaintingSocket",p+Vector3(0,0,-.025),Vector3(.99,1.05,.035),"painting_facing_minus_z")
	_chair(street,fixtures,bounds)

static func _fixture(street: Node3D, parent: Node3D, bounds: Array[Dictionary], label: String, p: Vector3, size: Vector3, key: String) -> void:
	_part(street,parent,label,p,size,key,true)
	bounds.append({"name":label,"local_bounds":AABB(p-size*.5,size),"world_bounds":AABB(ORIGIN+p-size*.5,size)})

static func _frame(street: Node3D, parent: Node3D, p: Vector3, w: float, h: float) -> void:
	for side: float in [-1.0,1.0]:
		_part(street,parent,"InteriorPaintingFrameSide",p+Vector3(side*(w-.045)*.5,0,0),Vector3(.045,h,.045),"arch_cedar")
		_part(street,parent,"InteriorPaintingFrameRail",p+Vector3(0,side*(h-.045)*.5,0),Vector3(w-.09,.045,.045),"arch_cedar")

static func _socket(parent: Node3D, label: String, p: Vector3, rotation: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = label
	marker.position = p
	marker.rotation = rotation
	parent.add_child(marker)
	return marker

static func _add_art_socket(parent: Node3D, sockets: Dictionary, label: String, p: Vector3, available_size: Vector3, kind: String) -> void:
	var id := label+"_%02d"%sockets.size()
	var node := _socket(parent,id,p,Vector3.ZERO)
	node.set_meta("art_socket_kind",kind)
	node.set_meta("available_size_m",available_size)
	sockets[id] = {"node":node,"kind":kind,"local_transform":node.transform,"world_position":ORIGIN+p,"available_size_m":available_size,"support_y":ORIGIN.y+p.y}

static func _chair(street: Node3D, parent: Node3D, bounds: Array[Dictionary]) -> void:
	var packed := load(CHAIR) as PackedScene
	if packed == null: return
	var chair := packed.instantiate() as Node3D
	if chair == null: return
	chair.name = "InteriorWorkbenchBentwoodChair"
	var holder := _group(parent,"InteriorWorkbenchSeating")
	holder.position = Vector3(3.20,0,7.72)
	holder.rotation.y = PI
	holder.add_child(chair)
	var raw := _asset_bounds(chair,Transform3D.IDENTITY)
	if raw.size.y>.001:
		var factor := .84/raw.size.y
		chair.scale = Vector3.ONE*factor
		chair.position = Vector3(-raw.get_center().x*factor,-raw.position.y*factor,-raw.get_center().z*factor)
	_name_interior(chair)
	# Retain all imported materials. A conservative seat/leg footprint is separate.
	street.call("_solid",parent,"InteriorChairCollision",Vector3(3.20,.42,7.72),Vector3(.54,.84,.54))
	bounds.append({"name":"InteriorWorkbenchSeating","local_bounds":AABB(Vector3(2.93,0,7.45),Vector3(.54,.84,.54)),"world_bounds":AABB(ORIGIN+Vector3(2.93,0,7.45),Vector3(.54,.84,.54))})

static func _name_interior(node: Node) -> void:
	if not String(node.name).begins_with("Interior"): node.name = "Interior"+String(node.name)
	for child: Node in node.get_children(): _name_interior(child)

static func _asset_bounds(node: Node3D, accumulated: Transform3D) -> AABB:
	var result := AABB()
	var first := true
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result = accumulated*(node as MeshInstance3D).get_aabb()
		first = false
	for child: Node in node.get_children():
		if not child is Node3D: continue
		var box := _asset_bounds(child,accumulated*(child as Node3D).transform)
		if box.size.length_squared()<.000001: continue
		result = box if first else result.merge(box)
		first = false
	return result

static func _set_exterior_layers(node: Node) -> void:
	if node is GeometryInstance3D: (node as GeometryInstance3D).layers |= BOUNCE_LAYER
	for child: Node in node.get_children(): _set_exterior_layers(child)

static func _counts(node: Node) -> Dictionary:
	var result := {"meshes":1 if node is MeshInstance3D else 0,"solids":1 if node is StaticBody3D else 0}
	for child: Node in node.get_children():
		var next := _counts(child)
		result.meshes += int(next.meshes)
		result.solids += int(next.solids)
	return result
