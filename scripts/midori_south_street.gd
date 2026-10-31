extends Node3D
## One bounded visual street outside the south park edge. Coordinates are WORLD
## metres: this producer is a direct child of the park, never its scaled layout.
const Budget = preload("res://scripts/shinrai_loading_budget.gd")
const StreetCompletion = preload("res://scripts/midori_street_completion.gd")
const KobayashiFrontage = preload("res://scripts/midori_kobayashi_frontage.gd")
const SurfaceReadability = preload("res://scripts/midori_surface_readability.gd")
const ShoreEcotone = preload("res://scripts/midori_shore_ecotone.gd")
const YAKITORI := "res://assets/shinrai/buildings/yakitori_shop/artwork_replica_v6/ProjectShinrai_YakitoriShop_ArtworkReplica_v6.tscn"
const Architecture = preload("res://scripts/midori_south_street_architecture.gd")
const Landscape = preload("res://scripts/midori_south_street_landscape.gd")
const Details = preload("res://scripts/midori_south_street_details.gd")
const Joinery = preload("res://scripts/midori_shop_joinery.gd")
const Layouts = preload("res://scripts/midori_shop_layouts.gd")
const NeighbourhoodBuildings = preload("res://scripts/midori_neighbourhood_buildings.gd")
const StartupTrace = preload("res://scripts/startup_trace.gd")
const NeighbourhoodGround = preload("res://scripts/midori_neighbourhood_ground.gd")
const CourtBuildings = preload("res://scripts/midori_court_buildings.gd")
const CourtGround = preload("res://scripts/midori_court_ground.gd")
const CeramicsGallery = preload("res://scripts/midori_ceramics_gallery.gd")
const InteriorPaintings = preload("res://scripts/midori_interior_paintings.gd")
const CourtArt = preload("res://scripts/midori_court_art.gd")
const StreetEdge = preload("res://scripts/midori_street_edge.gd")
const ConnectedContext = preload("res://scripts/midori_neighbourhood_context.gd")
const FoliageFinish = preload("res://scripts/midori_neighbourhood_foliage.gd")
const ShopIdentity = preload("res://scripts/midori_shop_identity.gd")
const DisplayLighting = preload("res://scripts/midori_display_lighting.gd")
const GardenContinuity = preload("res://scripts/midori_neighbourhood_gardens.gd")
const ResidentialFrontage = preload("res://scripts/midori_residential_frontage.gd")
const HomeGardens = preload("res://scripts/midori_home_gardens.gd")
const ShopfrontIdentity = preload("res://scripts/midori_shopfront_identity.gd")
const AccessGeometry = preload("res://scripts/building_access/geometry.gd")
const GalleryAccess = preload("res://scripts/building_access/gallery_sliding.gd")
const MaterialFinish = preload("res://scripts/building_access/material_finish.gd")
const ReferenceDetails = preload("res://scripts/building_access/reference_details.gd")
const HousePersonality = preload("res://scripts/midori_house_personality.gd")
const ResidentParking = preload("res://scripts/midori_resident_parking.gd")
const StreetFurniture = preload("res://scripts/midori_street_furniture.gd")
const TEXTURES := "res://assets/procedural_textures/"
const FACADE_PROPS := "res://assets/shinrai/streets/midori_facade/"
const MARKET_STALL := "res://assets/shinrai/streets/midori_market_stall/market_stall_lod0.glb"
const MESHY_ORNAMENT := "res://assets/shinrai/streets/midori_meshy_ornament/roof_scroll_endcap.glb"
var installed := false
var park: Node3D
var materials: Dictionary = {}
var report: Dictionary = {}
var light_members: Array[Light3D] = []
var last_night := false
var emissive_materials: Array[StandardMaterial3D] = []
var street_day_bounce: DirectionalLight3D
const STREET_LIGHT_LAYER := 1 << 10

func _ready() -> void:
	park = get_parent() as Node3D
	await Budget.wait_structure(park)
	var terrain := park.get_node_or_null("MidoriTerrain")
	while terrain != null and terrain.get("installed") != true:
		await get_tree().process_frame
	var _st := StartupTrace.begin()
	_make_materials()
	_st = StartupTrace.finish("south_street._make_materials", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var architecture: Dictionary = Architecture.build(self)
	_st = StartupTrace.finish("south_street.Architecture", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	_adapt_architecture_collisions(architecture)
	_st = StartupTrace.finish("south_street._adapt_architecture_collisions", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	await Budget.checkpoint(park)
	var landscape: Dictionary = Landscape.build(self)
	_st = StartupTrace.finish("south_street.Landscape", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var foliage_finish: Dictionary = FoliageFinish.build(self,landscape)
	_st = StartupTrace.finish("south_street.FoliageFinish", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var street_edge: Dictionary = StreetEdge.build(self)
	_st = StartupTrace.finish("south_street.StreetEdge", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	await Budget.checkpoint(park)
	var details: Dictionary = Details.build(self,false)
	_st = StartupTrace.finish("south_street.Details", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var interiors: Dictionary = Layouts.build(self)
	_st = StartupTrace.finish("south_street.Layouts", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	AccessGeometry.reconcile_shop_fixtures(self)
	_st = StartupTrace.finish("south_street.AccessGeometry", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var interior_paintings: Dictionary = InteriorPaintings.build(self)
	_st = StartupTrace.finish("south_street.InteriorPaintings", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	details["artisan_models_loaded"] = interiors.get("artisan_models_loaded",0)
	details["layout_replaced"] = true
	var neighbourhood_buildings: Dictionary = NeighbourhoodBuildings.build(self)
	_st = StartupTrace.finish("south_street.NeighbourhoodBuildings", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var neighbourhood_ground: Dictionary = NeighbourhoodGround.build(self)
	_st = StartupTrace.finish("south_street.NeighbourhoodGround", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var resident_parking: Dictionary = ResidentParking.build(self,neighbourhood_ground)
	_st = StartupTrace.finish("south_street.ResidentParking", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var opened_connections := _open_connected_lane()
	var connected_context: Dictionary = ConnectedContext.build(self,landscape,neighbourhood_ground)
	_st = StartupTrace.finish("south_street.ConnectedContext", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var street_completion: Dictionary = StreetCompletion.build(self)
	_st = StartupTrace.finish("south_street.StreetCompletion", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	connected_context["removed_lane_end_members"] = opened_connections
	connected_context["planting"] = FoliageFinish.plant_context(self,connected_context)
	var garden_continuity: Dictionary = GardenContinuity.build(self,connected_context,neighbourhood_ground)
	_st = StartupTrace.finish("south_street.GardenContinuity", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var residential_frontage: Dictionary = ResidentialFrontage.build(self,connected_context,neighbourhood_ground)
	_st = StartupTrace.finish("south_street.ResidentialFrontage", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var court_buildings: Dictionary = CourtBuildings.build(self)
	_st = StartupTrace.finish("south_street.CourtBuildings", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var household_details: Dictionary = HousePersonality.build(self)
	_st = StartupTrace.finish("south_street.HousePersonality", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var kobayashi_frontage: Dictionary = KobayashiFrontage.build(self)
	_st = StartupTrace.finish("south_street.KobayashiFrontage", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var court_ground: Dictionary = CourtGround.build(self)
	_st = StartupTrace.finish("south_street.CourtGround", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var home_gardens: Dictionary = HomeGardens.build(self,connected_context,neighbourhood_ground,court_ground,garden_continuity)
	_st = StartupTrace.finish("south_street.HomeGardens", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var gallery_report: Dictionary = CeramicsGallery.build(self)
	_st = StartupTrace.finish("south_street.CeramicsGallery", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var court_art: Dictionary = CourtArt.build(self,gallery_report)
	_st = StartupTrace.finish("south_street.CourtArt", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var shop_identity: Dictionary = ShopIdentity.build(self,gallery_report)
	_st = StartupTrace.finish("south_street.ShopIdentity", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var shopfront_identity: Dictionary = ShopfrontIdentity.build(self)
	_st = StartupTrace.finish("south_street.ShopfrontIdentity", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var gallery_access: Dictionary = GalleryAccess.install(self)
	_st = StartupTrace.finish("south_street.GalleryAccess", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var material_finish: Dictionary = MaterialFinish.build(self)
	_st = StartupTrace.finish("south_street.MaterialFinish", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var reference_details: Dictionary = ReferenceDetails.build(self)
	_st = StartupTrace.finish("south_street.ReferenceDetails", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	set_meta("building_reference_details",reference_details)
	set_meta("building_material_finish",material_finish)
	set_meta("building_access_gallery",gallery_access)
	var court_lighting: Dictionary = _build_court_lighting(court_ground,gallery_report)
	_build_neighbourhood_lights()
	_st = StartupTrace.finish("south_street._build_neighbourhood_lights", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var ornament_count := _build_meshy_ornaments()
	_build_shared_stall()
	_st = StartupTrace.finish("south_street._build_shared_stall", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	_build_street_lights()
	_st = StartupTrace.finish("south_street._build_street_lights", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var street_furniture: Dictionary = StreetFurniture.build(self)
	_st = StartupTrace.finish("south_street.StreetFurniture", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	_build_shop_lighting()
	_st = StartupTrace.finish("south_street._build_shop_lighting", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var display_lighting: Dictionary = DisplayLighting.build(self,gallery_report)
	_st = StartupTrace.finish("south_street.DisplayLighting", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var surface_readability: Dictionary = SurfaceReadability.build(self)
	_st = StartupTrace.finish("south_street.SurfaceReadability", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	var window_readability: Dictionary = SurfaceReadability.build_gallery(self,gallery_report)
	_st = StartupTrace.finish("south_street.SurfaceReadability", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	# Finish this bounded shoreline before distance boot captures producers.
	var shore := ShoreEcotone.new()
	shore.name = "MidoriShoreEcotone"
	park.add_child(shore)
	while not shore.installed: await get_tree().process_frame
	_assign_day_bounce_layers(self)
	_st = StartupTrace.finish("south_street._assign_day_bounce_layers", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	# Keep repeated trim/slab geometry economical without merging object ownership.
	for anchor: Node in get_children():
		if anchor is Node3D: _batch_tree(anchor)
	_st = StartupTrace.finish("south_street.batch_tree", _st)
	StartupTrace.finish("south_street.batch_stats sources=%d verts=%d" % [_batch_stats[0],_batch_stats[1]], StartupTrace.begin())
	interiors["rendered_batches"] = Layouts.audit_after_batching(self)
	_build_local_day_bounce()
	_st = StartupTrace.finish("south_street._build_local_day_bounce", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	last_night = park.get("is_night_mode") == true
	_sync_lighting()
	_st = StartupTrace.finish("south_street._sync_lighting", _st)
	await Budget.checkpoint(park)
	_st = StartupTrace.begin()
	report = {"world_bounds": landscape.get("world_bounds",Rect2(-32.5,174,65,46)).merge(neighbourhood_ground.bounds).merge(court_ground.bounds), "frontage_m":55.0,
		"road":Rect2(-27.5,183,55,7),"crossing":Rect2(-2,183,4,7),"interior_paintings":interior_paintings,
		"central_passage":Rect2(-3,194,6,11),"shops":4,"street_lamps":3,
		"art_reference":"midori_street_art_target_v1","architecture":architecture,"landscape":landscape,"details":details,"interiors":interiors,"constructed_street_edge":street_edge,
		"home_gardens":home_gardens,"shopfront_identity":shopfront_identity,"household_details":household_details,"garden_continuity":garden_continuity,"residential_frontage":residential_frontage,"resident_parking":resident_parking,"connected_context":connected_context,"foliage_finish":foliage_finish,"shop_identity":shop_identity,"display_lighting":display_lighting,
		"neighbourhood_buildings":neighbourhood_buildings,"neighbourhood_ground":neighbourhood_ground,"neighbourhood_lamps":2,
		"court_buildings":court_buildings,"court_ground":court_ground,"ceramics_gallery":gallery_report,"court_art":court_art,"court_lighting":court_lighting,"court_lamps":court_lighting.courtyard_lamps,"gallery_lights":court_lighting.gallery_lights,"court_added_buildings":4,
		"reused_meshy_stalls":1,"meshy_roof_ornaments":ornament_count,"new_asset_jobs":1,"coordinates":"world_metres","enemy_navigation_changed":false}
	report["street_completion"] = street_completion
	report["street_furniture"] = street_furniture
	report["kobayashi_frontage"] = kobayashi_frontage
	report["surface_readability"] = surface_readability
	report["window_readability"] = window_readability
	set_meta("south_street_report",report)
	installed = true
	print("MIDORI_SOUTH_STREET_READY: shops=4 frontage=55m lamps=3")

func _process(_delta: float) -> void:
	if not installed: return
	var night: bool = park.get("is_night_mode") == true
	if night != last_night:
		last_night = night
		_sync_lighting()

func _material(key: String, color: Color, roughness: float, texture_name: String = "", tile_scale: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = "SouthStreet_" + key
	mat.albedo_color = color
	mat.roughness = roughness
	if not texture_name.is_empty():
		mat.albedo_texture = load(TEXTURES + texture_name)
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE * tile_scale
	materials[key] = mat
	return mat

func _make_materials() -> void:
	_material("asphalt",Color("#727a7c"),.94,"asphalt_detail.png",.6)
	_material("paving",Color("#a2a39b"),.91,"concrete_detail.png",.7)
	_material("curb",Color("#a0a39c"),.85,"concrete_detail.png",1.1)
	_material("plaster",Color("#b7b5a4"),.91,"plaster_detail.png",.7)
	_material("putty",Color("#969b91"),.92,"plaster_detail.png",.8)
	_material("wood",Color("#866644"),.66,"wood_detail.png",1.5)
	_material("metal",Color("#293532"),.46).metallic = .62
	_material("roof",Color("#414b49"),.72).metallic = .35
	_material("sage",Color("#536f62"),.89)
	_material("ink",Color("#202a28"),.82)
	_material("joint",Color("#656f6c"),.95)
	_material("paint",Color("#ddd9c9"),.88)
	_material("glass",Color("#293e40"),.22).metallic = .3
	_material("glass_warm",Color("#665c43"),.31).metallic = .16
	_material("paper",Color("#c9bb93"),.91)
	_material("red",Color("#805849"),.85)
	var warm := _material("warm",Color("#cbb38a"),.6)
	warm.emission_enabled = true
	warm.emission = Color("#ffd29a")
	emissive_materials.append(warm)

func _box(parent: Node3D, label: String, pos: Vector3, size: Vector3, key: String, collide: bool = false) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	if Joinery.applies(key,label):
		visual.mesh = Joinery.mesh(size,(label+str(pos)).hash())
		visual.material_override = Joinery.material(self,key)
	else:
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
		visual.material_override = materials[key]
	visual.position = pos
	parent.add_child(visual)
	if collide: _solid(parent,label + "Collision",pos,size)
	return visual

func _solid(parent: Node3D, label: String, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)

func _root(label: String, pos: Vector3, display_name: String, kind: String) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = label
	anchor.position = pos
	anchor.set_meta("creator_editable",true)
	anchor.set_meta("creator_display_name",display_name)
	anchor.set_meta("creator_object_kind",kind)
	add_child(anchor)
	return anchor

var _batch_stats := [0,0,0]
func _batch_direct_geometry(anchor: Node3D) -> void:
	var layers: Dictionary = {}
	var sources: Array[MeshInstance3D] = []
	for child: Node in anchor.get_children():
		if not child is MeshInstance3D: continue
		var visual := child as MeshInstance3D
		if visual.mesh == null or visual.material_override == null: continue
		# Hidden, range-limited or parenting pieces cannot be represented by a merged mesh.
		if not visual.visible or visual.visibility_range_end > 0.0 or visual.get_child_count() > 0: continue
		var slot := Vector2i(visual.layers,visual.cast_shadow)
		if not layers.has(slot): layers[slot] = {}
		var groups: Dictionary = layers[slot]
		var mat: Material = visual.material_override
		# Shaders read UVs and vertex colours, so never mix meshes lacking them.
		var key := "%d:%d" % [mat.get_instance_id(),_vertex_format(visual.mesh)]
		if not groups.has(key):
			var group_tool := SurfaceTool.new()
			group_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			group_tool.set_material(mat)
			groups[key] = group_tool
		var tool: SurfaceTool = groups[key]
		for surface: int in range(visual.mesh.get_surface_count()):
			tool.append_from(visual.mesh,surface,visual.transform)
		sources.append(visual)
	if sources.is_empty(): return
	_batch_stats[0]+=sources.size()
	for slot: Vector2i in layers:
		var combined := ArrayMesh.new()
		for key: Variant in layers[slot]:
			var tool: SurfaceTool = layers[slot][key]
			tool.commit(combined)
		# Only ArrayMesh has surface_get_array_len; sources may be primitive meshes.
		for surface: int in range(combined.get_surface_count()):
			_batch_stats[1]+=combined.surface_get_array_len(surface)
		var node := MeshInstance3D.new()
		node.name = "CompleteOwnedGeometry"
		node.mesh = combined
		node.layers = slot.x
		node.cast_shadow = slot.y as GeometryInstance3D.ShadowCastingSetting
		anchor.add_child(node)
	for source: MeshInstance3D in sources:
		anchor.remove_child(source)
		source.queue_free()

func _vertex_format(mesh: Mesh) -> int:
	const ATTRIBUTES := Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT | Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TEX_UV2
	if mesh is ArrayMesh and mesh.get_surface_count() > 0:
		return (mesh as ArrayMesh).surface_get_format(0) & ATTRIBUTES
	# Primitive meshes always provide normals, tangents and UVs.
	return Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT | Mesh.ARRAY_FORMAT_TEX_UV

func _prop(parent: Node3D, filename: String, label: String, pos: Vector3) -> void:
	var packed := load(FACADE_PROPS + filename) as PackedScene
	if packed == null: return
	var model := packed.instantiate() as Node3D
	model.name = label
	model.position = pos
	parent.add_child(model)

func _ramp(parent: Node3D, label: String, start_z: float, end_z: float, start_y: float, end_y: float) -> void:
	var vertices := PackedVector3Array([Vector3(-3,start_y,start_z),Vector3(3,start_y,start_z),Vector3(-3,end_y,end_z),Vector3(3,start_y,start_z),Vector3(3,end_y,end_z),Vector3(-3,end_y,end_z)])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Vector3 in vertices: surface.add_vertex(v)
	surface.generate_normals()
	var mesh := surface.commit()
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = materials.paving
	parent.add_child(node)
	var body := StaticBody3D.new()
	body.name = label + "Collision"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	parent.add_child(body)

func _text(parent: Node3D, label: String, words: String, pos: Vector3, scale_m: float, color: Color) -> void:
	var node := Label3D.new()
	node.name = label
	node.text = words
	node.font_size = 48
	node.pixel_size = scale_m / 48.0
	node.modulate = color
	node.outline_size = 0
	node.no_depth_test = false
	node.shaded = true
	node.position = pos
	node.rotation.y = PI
	parent.add_child(node)

func _build_street_lights() -> void:
	for i: int in range(3):
		var x: float = [-24.5,10.5,24.5][i]
		var anchor := _root("StreetLamp_%02d" % i,Vector3(x,.08,190.55),"South Street Lamp","lamp")
		_box(anchor,"Base",Vector3(0,.11,0),Vector3(.24,.22,.24),"metal",true)
		_box(anchor,"Pole",Vector3(0,2.55,0),Vector3(.09,5.1,.09),"metal")
		_box(anchor,"Arm",Vector3(0,5.08,-.45),Vector3(.10,.10,1),"metal")
		_box(anchor,"LampHead",Vector3(0,5,-.94),Vector3(.44,.09,.65),"metal")
		_box(anchor,"LampDiffuser",Vector3(0,4.94,-.94),Vector3(.35,.025,.5),"warm")
		_omni(anchor,Vector3(0,4.65,-.85),1.7,8.5)

func _omni(parent: Node3D, pos: Vector3, energy: float, reach: float, day_energy: float = 0.0, tint: Color = Color("#ffd39d")) -> void:
	var light := OmniLight3D.new()
	light.name = "WarmStreetLight"
	light.position = pos
	light.light_color = tint
	light.light_energy = energy
	light.set_meta("street_night_energy",energy)
	light.set_meta("street_day_energy",day_energy)
	light.omni_range = reach
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	# The park hides this group in daylight; shop fill/interior lights stay active.
	if day_energy <= 0.0: light.add_to_group("midori_night_effect")
	parent.add_child(light)
	light_members.append(light)

func _sync_lighting() -> void:
	# Energy only: Creator Mode owns visibility for hidden and held whole objects.
	for light: Light3D in light_members:
		light.light_energy = float(light.get_meta("street_night_energy")) if last_night else float(light.get_meta("street_day_energy",0.0))
	for mat: StandardMaterial3D in emissive_materials:
		mat.emission_energy_multiplier = .55 if last_night else 0.0
	if street_day_bounce != null:
		street_day_bounce.light_energy = 0.0 if last_night else .62

func _build_local_day_bounce() -> void:
	# A street-only sky bounce lifts the north-facing facades without changing
	# the established park sun, environment, shadows, or exposure.
	street_day_bounce = DirectionalLight3D.new()
	street_day_bounce.name = "StreetOnlyDaySkyBounce"
	street_day_bounce.light_cull_mask = STREET_LIGHT_LAYER
	street_day_bounce.light_color = Color("#f6edda")
	street_day_bounce.rotation_degrees = Vector3(-35,180,0)
	street_day_bounce.shadow_enabled = false
	street_day_bounce.light_volumetric_fog_energy = 0.0
	add_child(street_day_bounce)

func _assign_day_bounce_layers(node: Node, indoors: bool = false, building: bool = false, gallery_scope: bool = false) -> void:
	# Shadowless facade bounce must not wash out the real sun's leaf shadows
	# on pavement, asphalt or plants. Base layer1 still receives park lighting.
	var label := str(node.name)
	gallery_scope = gallery_scope or label == "CeramicsGallery"
	var exterior: bool = building or node.get_meta("creator_object_kind","")=="building" or label in ["UedaBooks","MoriCoffee","HinataDaily","YakitoriShop","MarketStall","SouthNeighbourhoodBuildings","SouthCourtBuildings","CeramicsGallery"]
	var room := indoors or label.begins_with("RecessRoom") or label.begins_with("RecessSide") or label.begins_with("LinenCurtain") or label.begins_with("SmallRoomObject") or label.begins_with("GroundInterior") or label.begins_with("UpperRoom") or label.begins_with("Interior") or label.begins_with("Room") or label.begins_with("Curtain") or label.begins_with("RecessShelf") or label.begins_with("ShelfObject") or label in ["GroundRoomSideReveal","DetailCounter","DetailBackShelves","DetailWindowLeft","DetailWindowRight"]
	if node is GeometryInstance3D:
		var visual := node as GeometryInstance3D
		if gallery_scope and room: visual.layers |= 1 << 11
		var glazed: bool = node is MeshInstance3D and (node as MeshInstance3D).material_override == materials.get("arch_glass")
		if exterior and not room and not glazed: visual.layers |= STREET_LIGHT_LAYER
		else: visual.layers &= ~STREET_LIGHT_LAYER
	for child: Node in node.get_children(): _assign_day_bounce_layers(child,room,exterior,gallery_scope)

func _batch_tree(anchor: Node3D) -> void:
	for child: Node in anchor.get_children():
		if child is Node3D and not child is MeshInstance3D and not child is Light3D and not child is CollisionObject3D:
			_batch_tree(child)
	_batch_direct_geometry(anchor)

func _build_shared_stall() -> void:
	var stall := _root("MarketStall",Vector3(-15.4,.08,196.7),"Neighbourhood Market Stall","stall")
	var asset := load(MARKET_STALL) as PackedScene
	if asset != null:
		stall.add_child(asset.instantiate())
		_solid(stall,"StallCounterCollision",Vector3(0,.72,0),Vector3(2.2,1.44,1.94))
		_box(stall,"CleanSignCover",Vector3(0,1.52,-.835),Vector3(1.30,.30,.018),"metal")
	_omni(stall,Vector3(0,1.75,-.3),.5,3.4,.25)

func _build_meshy_ornaments() -> int:
	var scene := load(MESHY_ORNAMENT) as PackedScene
	if scene == null: return 0
	var count := 0
	for shop_name: String in ["UedaBooks","HinataDaily"]:
		var shop := get_node(NodePath(shop_name)) as Node3D
		for socket_name: String in ["RoofRidgeEndLeft","RoofRidgeEndRight"]:
			var socket := shop.get_node_or_null(NodePath(socket_name)) as Node3D
			if socket == null: continue
			var ornament := scene.instantiate() as Node3D
			ornament.name = "MeshyCeramicScrollEndcap"
			ornament.position.y = .10
			socket.add_child(ornament)
			count += 1
	return count

func _build_shop_lighting() -> void:
	for shop_name: String in ["UedaBooks","MoriCoffee","HinataDaily","YakitoriShop"]:
		var shop := get_node_or_null(NodePath(shop_name)) as Node3D
		if shop == null: continue
		# Local sky-bounce fill preserves the park's established global day/night setup.
		_omni(shop,Vector3(0,3.6,-3.0),0.0,10.0,.40,Color("#e9e3d5"))
		light_members.back().light_cull_mask = STREET_LIGHT_LAYER
		for socket_name: String in ["LightInterior","LightEntrance"]:
			var socket := shop.get_node_or_null(NodePath(socket_name)) as Node3D
			if socket != null:
				var position := Vector3(0,2.65,3.9) if socket_name == "LightInterior" else socket.position
				_omni(shop,position,1.05 if socket_name == "LightInterior" else .45,4.2,.60 if socket_name == "LightInterior" else .20)

		# Window-local sources sit beneath the constructed upper pendant shades.
		var width := 11.0 if shop_name == "UedaBooks" else (5.2 if shop_name == "YakitoriShop" else 10.0)
		var eave := 6.35 if shop_name == "UedaBooks" else (6.8 if shop_name == "MoriCoffee" else (6.4 if shop_name == "HinataDaily" else 5.75))
		for side: float in [-1.0,1.0]:
			_omni(shop,Vector3(side*width*.25,minf(6.03,eave-.38)-.35,1.30),.72,2.65,.50,Color("#ffdfb4"))
			light_members.back().name = "UpperRoomPendantLight"

		# Each practical follows its real counter or browsing/seating zone.
		for point: Vector3 in Layouts.practical_points(shop_name):
			_omni(shop,point,1.0,3.6,.75,Color("#ffd5a3"))
			light_members.back().name = "ShopWorkingPendant"

func _adapt_architecture_collisions(architecture: Dictionary) -> void:
	for row: Dictionary in architecture.get("buildings",[]):
		var building := row.get("root") as Node3D
		if building != null:
			var height := float(row.ridge)
			if not building.has_meta("building_access"):
				_solid(building,"VisualShopEnvelopeCollision",Vector3(0,height*.5,4),Vector3(float(row.width),height,8))
			row["root_path"] = str(building.get_path())
		row.erase("root")
		for socket_data: Dictionary in row.get("sockets",{}).values():
			socket_data.erase("node")

func _build_neighbourhood_lights() -> void:
	for x: float in [-13.0,8.0]:
		var lamp := _root("NeighbourhoodLaneLamp",Vector3(x,.09,227.7),"Residential lane lamp","light")
		_box(lamp,"Footplate",Vector3(0,.025,0),Vector3(.24,.05,.24),"metal")
		_box(lamp,"Post",Vector3(0,1.45,0),Vector3(.075,2.9,.075),"metal")
		_box(lamp,"CappedHousing",Vector3(0,2.94,0),Vector3(.33,.13,.33),"metal")
		_box(lamp,"RecessedDiffuser",Vector3(0,2.865,0),Vector3(.23,.025,.23),"warm")
		_omni(lamp,Vector3(0,2.77,0),1.2,8.0)

func _build_court_lighting(court_ground: Dictionary, gallery: Dictionary) -> Dictionary:
	var before := light_members.size()
	var courtyard_count := 0
	var gallery_count := 0
	var rows: Array[Dictionary] = []
	for point: Vector3 in court_ground.get("light_sockets",[]):
		var lamp := _root("CourtyardRegisteredLamp",Vector3(point.x,.09,point.z),"Courtyard lamp","light")
		lamp.set_meta("creator_protected",true)
		lamp.set_meta("creator_editable",false)
		_box(lamp,"CourtLampFooting",Vector3(0,-.02,0),Vector3(.24,.10,.24),"arch_stone")
		var local_y := point.y-.09
		_box(lamp,"CourtLampPost",Vector3(0,local_y*.5,0),Vector3(.075,local_y,.075),"arch_metal",true)
		_box(lamp,"CourtLampHousing",Vector3(0,local_y+.10,0),Vector3(.34,.14,.34),"arch_metal")
		_box(lamp,"CourtLampDiffuser",Vector3(0,local_y+.015,0),Vector3(.25,.025,.25),"warm")
		_omni(lamp,Vector3(0,local_y,0),1.10,7.5,0.0,Color("#ffdfb5"))
		light_members.back().name = "CourtyardNightPractical"
		rows.append({"id":"CourtyardLamp%02d"%courtyard_count,"position":point,"night_energy":1.10,"day_energy":0.0,"range":7.5,"registered":true,"interior":false})
		courtyard_count += 1
	for row: Dictionary in gallery.get("light_sockets",[]):
		var socket := row.get("node") as Node3D
		if socket == null: continue
		_omni(socket,Vector3.ZERO,float(row.night_energy),float(row.range),float(row.day_energy),row.get("tint",Color("#ffdfb5")))
		light_members.back().name = String(row.id)+"RegisteredPractical"
		light_members.back().light_cull_mask = 1 << 11
		rows.append({"id":row.id,"position":row.world_position,"night_energy":row.night_energy,"day_energy":row.day_energy,"range":row.range,"registered":true,"interior":true})
		gallery_count += 1
	return {"courtyard_lamps":courtyard_count,"gallery_lights":gallery_count,"registered_added":light_members.size()-before,"sockets":rows,"global_environment_changed":false,"night_sync":"existing street light registry","day_bounce":"exact court building and gallery exterior roots; Interior ancestry excluded"}


func _open_connected_lane() -> int:
	# Match actual dimensions/position, not duplicate sibling names assigned by Godot.
	var ground := get_node("NeighbourhoodGround")
	var removed := 0
	for child: Node in ground.get_children():
		if not child is Node3D: continue
		var point: Vector3 = child.position
		if absf(absf(point.x)-27.35)>.001 or absf(point.y-.23)>.001 or absf(point.z-224.25)>.001: continue
		var size := Vector3.ZERO
		if child is MeshInstance3D and child.mesh is BoxMesh: size=child.mesh.size
		if child is StaticBody3D and child.get_child_count()==1:
			var shape := child.get_child(0) as CollisionShape3D
			if shape!=null and shape.shape is BoxShape3D: size=shape.shape.size
		if not size.is_equal_approx(Vector3(.30,.50,4.5)): continue
		ground.remove_child(child)
		child.free()
		removed+=1
	return removed
