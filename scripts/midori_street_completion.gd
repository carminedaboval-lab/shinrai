extends RefCounted
## One real closed district service building beyond the existing connector turn.
## World metres; add to identity-scaled MidoriSouthStreet, never the park layout.
const SUPPORT := Rect2(177,176,20,21.5)
const FOOTPRINT := Rect2(184,179,10,14)
const CLEAR_ROUTES: Array[Rect2] = [Rect2(38.5,183,124,7),Rect2(162.5,183,12,12),Rect2(174.5,183,2.5,21),Rect2(158.5,197.5,4,6.5)]

static func build(street: Node3D) -> Dictionary:
	if street.has_node("StreetCompletion"):
		return street.get_node("StreetCompletion").get_meta("street_completion",{})
	var root := Node3D.new()
	root.name = "StreetCompletion"
	root.set_meta("creator_protected",true)
	root.set_meta("creator_editable",false)
	street.add_child(root)
	# One narrow new parcel touches the connector at X177 and existing district
	# ground at Z190. It never extends the parent's playable/navigation bounds.
	_part(street,root,"ExchangeSupportedParcel",Vector3(187,-.265,186.75),Vector3(20,.45,21.5),"land_joint",true)
	_part(street,root,"ExchangeApron",Vector3(187,-.005,186.75),Vector3(20,.09,21.5),"arch_stone",true)
	# Two 240mm side walls, back, bearing floor and a west-facing recessed facade.
	_part(street,root,"ExchangeFoundation",Vector3(189,.14,186),Vector3(10.6,.20,14.6),"arch_stone",true)
	for z: float in [179.12,192.88]:
		_part(street,root,"ExchangeSideWall",Vector3(189,4.25,z),Vector3(10,8.1,.24),"arch_mineral",true)
	_part(street,root,"ExchangeRearWall",Vector3(193.88,4.25,186),Vector3(.24,8.1,14),"arch_mineral",true)
	# The inaccessible envelope lies behind the real 360mm front recesses.
	_part(street,root,"ExchangeClosedEnvelope",Vector3(189.3,4.25,186),Vector3(9.16,8.1,13.52),"arch_mineral",true)
	for y: float in [.58,3.5,4.35,7.7]:
		var h := .76 if y == .58 else .5
		_part(street,root,"ExchangeFacadeSpandrel",Vector3(184.12,y,186),Vector3(.24,h,14),"arch_plaster",true)
	for z: float in [179.45,183.0,187.0,191.0,192.65]:
		var width := .7 if z > 192.0 else .9
		_part(street,root,"ExchangeBearingPier",Vector3(184.12,4.25,z),Vector3(.24,8.1,width),"arch_mineral",true)
	for y: float in [2.12,6.10]:
		for z: float in [181.2,185.0,189.0]:
			_window(street,root,y,z)
	# Restrained projecting steel eaves supported by the side walls and piers.
	for y: float in [3.95,8.38]:
		_part(street,root,"ExchangeEave",Vector3(188.85,y,186),Vector3(11.5,.18,15.2),"arch_metal",false)
	_part(street,root,"ExchangeRoofSlab",Vector3(189,8.2,186),Vector3(10.5,.25,14.5),"arch_stone",true)
	# Offset rooftop plant creates a second depth/height step, not a skyline screen.
	_part(street,root,"ExchangeRoofPlant",Vector3(191,9.0,189.5),Vector3(4.2,1.3,4.5),"arch_metal",false)
	for z: float in [188.1,188.8,189.5,190.2,190.9]:
		_part(street,root,"PlantLouver",Vector3(188.86,9.0,z),Vector3(.12,.65,.08),"arch_stone",false)
	# Continuous gutter has two grounded downpipes and visible shoes.
	_part(street,root,"ExchangeGutter",Vector3(183.15,8.34,186),Vector3(.16,.13,15.2),"arch_metal",false)
	for z: float in [179.35,192.65]:
		_part(street,root,"ExchangeDownpipe",Vector3(183.81,3.84,z),Vector3(.10,7.22,.10),"arch_metal",false)
		_part(street,root,"ExchangeGutterOutlet",Vector3(183.15,8.20,z),Vector3(.11,.25,.11),"arch_metal",false)
		var outlet := Vector3(183.15,8.10,z)
		var pipe := Vector3(183.81,7.44,z)
		var offset := _part_mesh(street,root,"ExchangeRainwaterOffset",(outlet+pipe)*.5,Vector3(.10,.10,outlet.distance_to(pipe)),"arch_metal")
		offset.basis = Basis.looking_at((pipe-outlet).normalized(),Vector3.UP)
		_part(street,root,"ExchangePipeSocket",pipe,Vector3(.12,.12,.12),"arch_metal",false)
		_part(street,root,"ExchangeDrainShoe",Vector3(183.65,.23,z),Vector3(.40,.13,.15),"arch_metal",false)
	# Slatted service bay on the north wall has depth and full wall returns.
	for x: float in [187.1,188.0,188.9,189.8,190.7,191.6]:
		_part(street,root,"ServiceBayLouver",Vector3(x,2.5,178.94),Vector3(.55,2.6,.14),"arch_cedar",false)
	# A modest corner destination marker sits on the apron, outside all routes.
	_part(street,root,"ExchangeWayfindingBase",Vector3(180.5,.22,194),Vector3(.75,.36,.75),"arch_stone",true)
	_part(street,root,"ExchangeWayfindingBlade",Vector3(180.5,1.65,194),Vector3(.18,2.5,.85),"arch_metal",false)
	# Northern/rear parcel edges stop at the existing southward district access.
	_part(street,root,"NorthParcelUpstand",Vector3(187,.18,176.15),Vector3(20,.28,.22),"land_curb",true)
	_part(street,root,"EastParcelUpstand",Vector3(196.85,.18,183),Vector3(.22,.28,14),"land_curb",true)
	var counts := _counts(root)
	var result := {"ok":true,"support_rectangles":[SUPPORT],"support_top_y":.04,"building_footprints":[FOOTPRINT],"building_height_m":9.65,"clear_route_rectangles":CLEAR_ROUTES,"meshes":counts.meshes,"colliders":counts.colliders,"maximum_mesh_budget":150,"maximum_collision_budget":35,"new_lights":0,"navigation_bounds_changed":false,"playable_bounds_changed":false,"closed_context_building":true,"purpose":"Two-storey district utilities exchange marks the existing south turn; retained corporate buildings provide deeper layers","source_provenance":"Original metre-scale geometry with existing street architecture materials; no external assets or source edits"}
	root.set_meta("street_completion",result)
	result["support_outside_existing_playable_domain"] = [Rect2(177,176,20,14)]
	result["existing_playable_domain_retained"] = true
	result["doorways"] = []
	root.set_meta("street_completion",result)
	return result

static func _window(street: Node3D,root: Node3D,y: float,z: float) -> void:
	# Dark glass sits 360mm behind the outer wall; jambs, sill and head bridge it.
	_part(street,root,"ExchangeWindowBacking",Vector3(184.61,y,z),Vector3(.045,2.15,2.5),"arch_cladding_backing",false)
	_part(street,root,"ExchangeRecessedGlass",Vector3(184.49,y,z),Vector3(.045,2.15,2.5),"arch_glass",false)
	for edge: float in [-1.0,1.0]:
		_part(street,root,"ExchangeWindowJamb",Vector3(184.30,y,z+edge*1.28),Vector3(.40,2.3,.08),"arch_metal",false)
		_part(street,root,"ExchangeWindowReveal",Vector3(184.30,y+edge*1.12,z),Vector3(.40,.08,2.65),"arch_stone",false)
	_part(street,root,"ExchangeWindowMullion",Vector3(184.43,y,z),Vector3(.10,2.15,.055),"arch_metal",false)

static func _part(street: Node3D,parent: Node3D,label: String,p: Vector3,size: Vector3,key: String,collision: bool) -> void:
	street.call("_box",parent,label,p,size,key,collision)

static func _part_mesh(street: Node3D,parent: Node3D,label: String,p: Vector3,size: Vector3,key: String) -> MeshInstance3D:
	return street.call("_box",parent,label,p,size,key,false) as MeshInstance3D

static func _counts(node: Node) -> Dictionary:
	var result := {"meshes":int(node is MeshInstance3D),"colliders":int(node is StaticBody3D)}
	for child: Node in node.get_children():
		var sub := _counts(child)
		result.meshes += int(sub.meshes)
		result.colliders += int(sub.colliders)
	return result
