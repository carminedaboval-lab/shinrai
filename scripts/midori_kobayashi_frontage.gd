extends RefCounted
## One original window shelter; all dimensions in metres. Build before batching.
const HOUSE := "SouthNeighbourhoodBuildings/KobayashiHouse"
const ADDED_BOUNDS := AABB(Vector3(-.02,.94,-.47),Vector3(2.64,1.68,.55))

static func build(street: Node3D) -> Dictionary:
	var house := street.get_node_or_null(HOUSE) as Node3D
	if house == null:
		return {"ok":false,"reason":"KobayashiHouse absent"}
	if house.has_node("KobayashiWindowShelter"):
		return house.get_node("KobayashiWindowShelter").get_meta("frontage_construction",{})
	var band := house.get_node_or_null("StoreyBand") as MeshInstance3D
	if band == null:
		return {"ok":false,"reason":"Expected unbatched StoreyBand absent; build earlier"}
	# The physical 400mm band stays intact. Only this house's render material is
	# brought into its own existing painted wall family, retaining all geometry.
	var reference := house.get_node_or_null("UpperSillWall") as MeshInstance3D
	if reference == null:
		return {"ok":false,"reason":"Existing painted UpperSillWall absent"}
	var previous_material := band.material_override
	var previous_bounds := band.get_aabb()
	band.material_override = reference.material_override
	var root := Node3D.new()
	root.name = "KobayashiWindowShelter"
	root.set_meta("creator_protected",true)
	root.set_meta("creator_editable",false)
	house.add_child(root)
	# Shelter over the existing ground sitting-room opening X.3..2.3/Y.85..2.35.
	# Rear flashing embeds into solid head masonry, not the window or glass.
	_part(street,root,"WindowShelterHeadFlashing",Vector3(1.3,2.55,.025),Vector3(2.60,.14,.045),"arch_metal")
	var roof := _part(street,root,"WindowShelterFallingPan",Vector3(1.3,2.48,-.205),Vector3(2.60,.024,.50),"arch_metal")
	roof.rotation.x = -atan2(.027,.50)
	_part(street,root,"WindowShelterCedarSoffit",Vector3(1.3,2.449,-.20),Vector3(2.50,.018,.44),"arch_pale_wood")
	_part(street,root,"WindowShelterFrontDripHem",Vector3(1.3,2.443,-.46),Vector3(2.64,.035,.020),"arch_metal")
	for x: float in [.01,2.59]:
		_part(street,root,"WindowShelterFoldedEnd",Vector3(x,2.48,-.205),Vector3(.018,.045,.50),"arch_metal")
	# The narrow supports stand outside the original two-metre opening. Each
	# strut joins a wall plate below and a soffit arm above; no floating brackets.
	for x: float in [.04,2.56]:
		_part(street,root,"ShelterWallAnchor",Vector3(x,2.27,-.012),Vector3(.07,.39,.032),"arch_metal")
		_part(street,root,"ShelterCantileverArm",Vector3(x,2.422,-.205),Vector3(.035,.032,.42),"arch_metal")
		_beam(street,root,"ShelterDiagonalBrace",Vector3(x,2.09,-.025),Vector3(x,2.405,-.39),.025)
	# One side privacy return provides a legible asymmetry without covering the
	# existing pane. 35mm timber slats sit perpendicular to the facade, outside
	# the right-hand reveal. Both end rails bear on wall/soffit anchors.
	_part(street,root,"PrivacyWallStile",Vector3(2.51,1.67,-.01),Vector3(.045,1.40,.045),"arch_metal")
	_part(street,root,"PrivacyOuterStile",Vector3(2.51,1.67,-.425),Vector3(.035,1.40,.035),"arch_metal")
	for y: float in [1.0,2.34]:
		_part(street,root,"PrivacyReturnRail",Vector3(2.51,y,-.2175),Vector3(.045,.035,.46),"arch_metal")
	for i: int in range(10):
		_part(street,root,"PrivacyReturnTimberSlat",Vector3(2.51,1.055+float(i)*.137,-.2175),Vector3(.035,.040,.40),"arch_cedar")
	for y: float in [1.08,2.23]:
		_part(street,root,"PrivacyPierFixingPlate",Vector3(2.51,y,.015),Vector3(.09,.10,.035),"arch_metal")
	_part(street,root,"PrivacySoffitTie",Vector3(2.51,2.385,-.425),Vector3(.035,.10,.035),"arch_metal")
	var result := {"ok":true,"house":HOUSE,"modified_existing_members":["StoreyBand"],"material_reference":"UpperSillWall.material_override","previous_material_resource":previous_material.resource_path if previous_material != null else "","existing_band_bounds_before":previous_bounds,"existing_band_bounds_after":band.get_aabb(),"added_local_bounds":ADDED_BOUNDS,"added_world_bounds":house.global_transform*ADDED_BOUNDS,"existing_house_bounds_preserved":true,"ground_window_opening":Rect2(.3,.85,2,1.5),"entrance_clearance_local_x":Vector2(-3.0,-1.5),"added_minimum_y":.94,"max_projection_m":.47,"meshes_added":root.get_child_count(),"colliders_added":0,"lights_added":0,"glass_added":0,"existing_openings_preserved":13,"existing_glass_preserved":26,"rainwater":"27mm falling metal pan, embedded head flashing, front downstand drip; drains onto existing exterior ground without new pipe or ground obstruction","original_assets_modified":false}
	root.set_meta("frontage_construction",result)
	return result

static func _part(street: Node3D,root: Node3D,label: String,p: Vector3,size: Vector3,key: String) -> MeshInstance3D:
	return street.call("_box",root,label,p,size,key,false) as MeshInstance3D

static func _beam(street: Node3D,root: Node3D,label: String,a: Vector3,b: Vector3,width: float) -> void:
	var visual := _part(street,root,label,(a+b)*.5,Vector3(width,width,a.distance_to(b)),"arch_metal")
	visual.basis = Basis.looking_at((b-a).normalized(),Vector3.UP)
