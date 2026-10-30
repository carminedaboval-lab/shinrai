extends RefCounted
## World-metre street ground and layered planting. Only a sampled existing-path
## stone skin enters Z174..180; finished park objects are never moved or removed.
const FoliageMaterials = preload("res://scripts/midori_foliage_materials.gd")
const TREE_PACK := "res://assets/shinrai/parks/midori_park/models/vegetation/vendor/realistic_trees_collection/scene.glb"
const TREE_NAME := "Tree EZTree0.Medium011"
const SHRUB_NAME := "Tree EZTree1.Bush006"
const FERN := "res://assets/shinrai/parks/midori_park/models/vegetation/vendor/midnight_fern/midnight_fern.glb"
const PINE_PACK := "res://assets/shinrai/parks/midori_park/models/vegetation/vendor/pine_trees_pack/scene.glb"
const PAVEMENT_Y := 0.09
const ROAD_Y := 0.02

static func build(street: Node3D) -> Dictionary:
	_materials(street)
	var ground := Node3D.new()
	ground.name = "StreetStructure"
	ground.set_meta("creator_protected", true)
	street.add_child(ground)
	# The original terrain ends at Z180. This floor also supports end planting.
	_b(street, ground, "ContinuousFoundation", Vector3(0,-.17,192.5), Vector3(65,.3,25), "land_joint", true)
	_b(street, ground, "RoughAsphalt", Vector3(0,0,186.5), Vector3(55,.04,7), "land_asphalt", true)
	for side: float in [-1.0,1.0]:
		_b(street, ground, "ShortRoadContinuation", Vector3(side*30,0,186.5), Vector3(5,.04,7), "land_asphalt", true)
	var slab_count := 0
	for rect: Rect2 in [Rect2(-32.5,180,29.5,3),Rect2(3,180,29.5,3),Rect2(-3,180,6,2),Rect2(-32.5,190,29.5,4),Rect2(3,190,29.5,4),Rect2(-3,191,6,3),Rect2(-3,194,6,11)]:
		slab_count += _paving(street,ground,rect,slab_count)
	# Plot ground is lower than the pavement and never coplanar with slab tops.
	for side: float in [-1.0,1.0]:
		_b(street,ground,"CourtyardPlotBase",Vector3(side*17.75,.01,199.5),Vector3(29.5,.04,11),"land_soil",true)
	_ramp(street,ground,"NorthDroppedCurb",182,183,PAVEMENT_Y,ROAD_Y)
	_ramp(street,ground,"SouthDroppedCurb",190,191,ROAD_Y,PAVEMENT_Y)
	for side: float in [-1.0,1.0]:
		for z: float in [182.93,190.07]:
			_b(street,ground,"HewnCurb",Vector3(side*17.75,.066,z),Vector3(29.5,.132,.14),"land_curb",true)
		for z: float in [183.17,189.83]:
			_b(street,ground,"StoneGutter",Vector3(side*17.75,.022,z),Vector3(29.5,.012,.22),"land_gutter")
		# The former 29.5m "DrainageChannel" strip read as one stretched drain; the
		# gutter units and jointed gullies from StreetEdge/_drain carry the drainage now.
		for z: float in [183.55,189.45]:
			_b(street,ground,"QuietRoadEdge",Vector3(side*16.75,.024,z),Vector3(21.5,.004,.065),"land_paint")
	for i: int in range(8):
		_b(street,ground,"CrossingStripe_%02d" % i,Vector3(0,.024,183.4+i*.88),Vector3(4,.006,.43),"land_paint")
	# A restrained broken centre line makes the main two-way street legible.
	for side: float in [-1.0,1.0]:
		for i: int in range(6):
			_b(street,ground,"TwoWayCentreMark",Vector3(side*(6.0+float(i)*4.0),.027,186.5),Vector3(1.5,.004,.10),"land_paint")
	_tactile(street,ground,181.68)
	_tactile(street,ground,191.32)
	# Narrow approach gutters also continue across the dropped kerbs. The gutter
	# dish meets the curb face (Z183.00/190.00), so its centre line is 0.11m out.
	for z: float in [183.11,189.89]:
		_b(street,ground,"CrossingGutter",Vector3(0,.021,z),Vector3(6,.005,.22),"land_gutter")
	for x: float in [-25,-12,-3.55,3.55,12,25]:
		_drain(street,ground,Vector3(x,0,189.89))
		_drain(street,ground,Vector3(x,0,183.11))
	# Two sewer covers in the carriageway, clear of the crossing, centre marks and
	# the shader's photographed fracture regions.
	for pos: Vector3 in [Vector3(-16.0,0,185.0),Vector3(13.0,0,188.1)]:
		_manhole(street,ground,pos)
	# Extend real support under the new planted courtyard, not a floating backdrop.
	_b(street,ground,"CourtyardExtensionFoundation",Vector3(0,-.17,212.5),Vector3(28,.3,15),"land_joint",true)
	_b(street,ground,"CourtyardExtensionSoil",Vector3(0,.005,212.5),Vector3(28,.05,15),"land_soil",true)
	slab_count += _paving(street,ground,Rect2(-3,205,6,10),slab_count)
	slab_count += _paving(street,ground,Rect2(-6.6,215,13.2,1.5),slab_count)
	# A supported 3.2m opening connects the courtyard to the residential lane.
	slab_count += _paving(street,ground,Rect2(-1.6,216.5,3.2,3),slab_count)
	for side: float in [-1.0,1.0]:
		_b(street,ground,"CourtyardFarBoundary",Vector3(side*7.8,.36,218.4),Vector3(12.4,.72,.2),"land_pot",true)
	for side: float in [-1.0,1.0]:
		_b(street,ground,"CourtyardSideBoundary",Vector3(side*13.9,.28,211.75),Vector3(.2,.56,13.5),"land_pot",true)
		_b(street,ground,"CrosspathEndSeatWall",Vector3(side*6.72,.26,215.75),Vector3(.24,.52,1.5),"land_pot",true)
	var approach := _approach_paving(street,ground)
	var plants := _planting(street)
	var minimum_z: float = minf(float(approach.get("minimum_z",180.0)),float(plants.get("foreground_visual_minimum_z",180.0)))
	var world_bounds := Rect2(-32.5,minimum_z,65,220.0-minimum_z)
	return {"owner":"ground_landscape", "world_bounds":world_bounds,"bounds":world_bounds,
		"frontage_m":55.0,"road":Rect2(-27.5,183,55,7),"passage":Rect2(-3,194,6,11),
		"rear_walk":Rect2(-3,205,6,10),"rear_crosspath":Rect2(-6.6,215,13.2,1.5),
		"supported_ground":[Rect2(-32.5,180,65,25),Rect2(-14,205,28,15)],
		"approach_paving":approach,"slabs":slab_count,"planting":plants,"light_sockets":[],
		"dependencies":[TREE_PACK,FERN,PINE_PACK,"res://scripts/midori_foliage_materials.gd","res://scripts/midori_sidewalk_limestone.gdshader","res://assets/procedural_textures/concrete_detail.png"],
		"road_surface":"Common physical-scale PBR aggregate with localized sourced fracture detail and integrated resurfacing", "drawn_crack_meshes":0,"sloped_paving_construction":ground.get_meta("sloped_paving_construction",[]),"asphalt_material_sources":street.get_meta("asphalt_material_sources",{}),
		"existing_park_objects_changed":false}

static func _materials(street: Node3D) -> void:
	_asphalt_materials(street)
	street.call("_material","detail_vine_stem",Color("#53543a"),.95)
	# Reference palette: cream limestone, quiet sand and neutral warm-gray stone.
	# Existing per-stone five-way assignment/cutouts/UVs remain exactly as built.
	var shades: Array[Color] = [Color("#b7b2a4"),Color("#b9b2a1"),Color("#aeaca1"),Color("#bbb6a9"),Color("#b3b1a6")]
	for i: int in range(shades.size()):
		_mineral_material(street,"land_slab_%d" % i,shades[i],.92,.12,115.0)
	_mineral_material(street,"land_ramp",Color("#b4afa0"),.93,.12,115.0)
	_mineral_material(street,"land_curb",Color("#bab8aa"),.92,.075,95.0)
	_mineral_material(street,"land_gutter",Color("#929489"),.95,.085,105.0)
	for row: Array in [["land_joint",Color("#615f55"),.98,"",1.0],
		["land_channel",Color("#3e4943"),.98,"",1.0],
		["land_void",Color("#0a0c0b"),1.0,"",1.0],
		["land_soil",Color("#3e3c30"),1.0,"concrete_detail.png",2.8],
		["land_pot",Color("#747c70"),.94,"concrete_detail.png",1.6],
		["land_tactile",Color("#b8aa7b"),.88,"concrete_detail.png",2.0]]:
		street.call("_material",row[0],row[1],row[2],row[3],row[4])
	_iron_and_cover_materials(street)
	_scanned_earth(street)

## Gully gratings and inlet lintels use the street's cast-iron shader (the same
## finish as the pavement inspection cover) instead of a flat tinted material.
## The sewer covers reuse the project's unused SHINRAI manhole PBR sets.
static func _iron_and_cover_materials(street: Node3D) -> void:
	var mats: Dictionary = street.get("materials")
	var iron := ShaderMaterial.new()
	iron.resource_name = "SouthStreet_land_iron"
	iron.shader = preload("res://scripts/midori_street_iron.gdshader")
	iron.set_shader_parameter("iron_color",Color("#3a413d"))
	iron.set_shader_parameter("base_roughness",.82)
	iron.set_shader_parameter("metalness",.42)
	mats.land_iron = iron
	var repairs := "res://assets/environment/roads/shinrai_road/repairs/"
	for pair: Array in [["road_manhole_cover","M_SHINRAI_ManholeCover.tres"],["road_manhole_cut","M_SHINRAI_ManholeCut.tres"]]:
		if ResourceLoader.exists(repairs+pair[1]):
			mats[pair[0]] = load(repairs+pair[1])

## The wide foundation and courtyard soil beds were flat tinted boxes. Dress
## them in the park's scanned compacted earth (world triplanar) so the ground
## between the park paving and the shops reads as soil, not an untextured plane.
static func _scanned_earth(street: Node3D) -> void:
	var root := "res://assets/shinrai/parks/midori_park/materials/vostok_environment_20261028/dirt/"
	if not ResourceLoader.exists(root+"dirt_diff_2k.jpg"): return
	var mats: Dictionary = street.get("materials")
	for key: String in ["land_joint","land_soil"]:
		var mat := mats.get(key) as StandardMaterial3D
		if mat == null: continue
		mat.albedo_texture = load(root+"dirt_diff_2k.jpg")
		mat.albedo_color = Color("#8d8676") if key=="land_joint" else Color("#6f6a55")
		mat.normal_enabled = true
		mat.normal_texture = load(root+"dirt_nor_gl_1k.jpg")
		mat.normal_scale = 0.8
		mat.roughness_texture = load(root+"dirt_rough_1k.jpg")
		mat.roughness = 1.0
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE * 0.45
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

static func _asphalt_materials(street: Node3D) -> void:
	var material := ShaderMaterial.new()
	material.resource_name = "SouthStreet_MaintainedAsphaltAndLocalWear"
	material.shader = preload("res://scripts/midori_street_asphalt.gdshader")
	var original := "res://assets/environment/roads/shinrai_road/textures/"
	var wear := "res://assets/shinrai/streets/midori_asphalt/"
	material.set_shader_parameter("aggregate_albedo",load(original+"SHINRAI_Road_FineAggregate_BaseColor_2K.png"))
	material.set_shader_parameter("aggregate_normal",load(original+"SHINRAI_Road_RealisticDry_NormalGL_2K.png"))
	material.set_shader_parameter("aggregate_orm",load(original+"SHINRAI_Road_RealisticDry_ORM_2K.png"))
	material.set_shader_parameter("worn_albedo",load(wear+"Asphalt008_2K-JPG_Color.jpg"))
	material.set_shader_parameter("worn_normal",load(wear+"Asphalt008_2K-JPG_NormalGL.jpg"))
	material.set_shader_parameter("worn_roughness",load(wear+"Asphalt008_2K-JPG_Roughness.jpg"))
	material.set_shader_parameter("worn_gain",Vector3(0.410004,0.348344,0.229495))
	var mats: Dictionary = street.get("materials")
	mats.land_asphalt = material
	var paint := material.duplicate() as ShaderMaterial
	paint.resource_name = "SouthStreet_WornRoadPaint"
	paint.set_shader_parameter("paint_surface",1.0)
	mats.land_paint = paint
	var sources: Dictionary = {}
	for parameter: String in ["aggregate_albedo","aggregate_normal","aggregate_orm","worn_albedo","worn_normal","worn_roughness"]:
		var texture := material.get_shader_parameter(parameter) as Texture2D
		sources[parameter]=texture.resource_path if texture!=null else ""
	street.set_meta("asphalt_material_sources",{"textures":sources,"aggregate_repeat_m":2.0,"repair_repeat_m":2.0,"photo_regions_world":[Rect2(3.8,184.22,2.6,2.4),Rect2(-7.9,186.4,2.5,2.2)],"fracture_mode":"only sourced dark photo fissures; continuous common asphalt aggregate beneath","generated_crack_paths":false,"geometry_or_collision_modified":false})

static func _mineral_material(street: Node3D,key: String,color: Color,roughness: float,grain: float,scale: float,wear: float=0.0) -> void:
	var material := ShaderMaterial.new()
	material.resource_name = "SouthStreet_"+key
	material.shader = preload("res://scripts/midori_sidewalk_limestone.gdshader")
	material.set_shader_parameter("mineral_color",color)
	material.set_shader_parameter("surface_roughness",roughness)
	material.set_shader_parameter("grain_strength",grain)
	material.set_shader_parameter("aggregate_scale",scale)
	material.set_shader_parameter("paint_wear",wear)
	material.set_shader_parameter("stone_weather",1.0 if key.begins_with("land_slab_") else 0.0)
	material.set_shader_parameter("road_weather",1.0 if key in ["land_asphalt","land_resurfaced","land_repair","land_gutter","land_paint"] else 0.0)
	# Reuse inspected project-owned precast maps; normalized measured linear
	# luma keeps their pore texture without importing their darker gray palette.
	var base := "res://assets/shinrai/drain_hgu150/ProjectShinrai_HGU150_Drain_GameReady_SHINRAI_"
	var curb: bool = key in ["land_curb","land_gutter"]
	material.set_shader_parameter("precast_albedo",load(base+("PrecastCurb" if curb else "PrecastPaver")+"_BaseColor_1K.png"))
	material.set_shader_parameter("precast_normal",load(base+"PrecastExterior_NormalGL_1K.png"))
	material.set_shader_parameter("precast_orm",load(base+"PrecastExterior_ORM_1K.png"))
	material.set_shader_parameter("texture_neutral_luma",.118534 if curb else .136050)
	material.set_shader_parameter("texture_repeats_per_metre",.85)
	material.set_shader_parameter("texture_color_strength",.50)
	material.set_shader_parameter("texture_normal_strength",.38)
	var mats: Dictionary = street.get("materials")
	mats[key] = material

static func _b(street: Node3D,parent: Node3D,label: String,pos: Vector3,size: Vector3,key: String,collide: bool=false) -> void:
	street.call("_box",parent,label,pos,size,key,collide)

static func _paving(street: Node3D,parent: Node3D,rect: Rect2,seed_value: int) -> int:
	var centre := rect.get_center()
	_b(street,parent,"PavingJointBed",Vector3(centre.x,.025,centre.y),Vector3(rect.size.x,.1,rect.size.y),"land_joint")
	# Collision has the same top as the slabs; joints remain shallow visual recesses.
	street.call("_solid",parent,"ContinuousPavementSupport",Vector3(centre.x,.035,centre.y),Vector3(rect.size.x,.11,rect.size.y))
	var count := 0
	var z := rect.position.y
	var row := 0
	while z < rect.end.y-.001:
		var dz := minf(.8,rect.end.y-z)
		var x := rect.position.x
		var column := 0
		while x < rect.end.x-.001:
			var dx := minf(.6 if column > 0 or row%2 == 0 else .3,rect.end.x-x)
			var shade := posmod((seed_value+row*71+column*127)^(row*column*31),5)
			var tile := Rect2(x+.005,z+.005,maxf(dx-.010,.01),maxf(dz-.010,.01))
			for piece: PackedVector2Array in _paver_cutouts(tile):
				_paver_piece(street,parent,piece,tile,"land_slab_%d" % shade)
			x += dx
			column += 1
			count += 1
		z += dz
		row += 1
	# Sealed expansion joints every eight 0.6m courses (4.8m) across long walks:
	# a 14mm bitumen-filled joint 1mm proud, cut straight through the running bond.
	if rect.size.x > 6.0:
		var joint_x := rect.position.x + 4.8
		while joint_x < rect.end.x - 1.2:
			_b(street,parent,"PavingExpansionJoint",Vector3(joint_x,.0895,centre.y),Vector3(.014,.003,rect.size.y),"land_channel")
			joint_x += 4.8
	return count

static func _paver_cutouts(tile: Rect2) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [PackedVector2Array([tile.position,Vector2(tile.end.x,tile.position.y),tile.end,Vector2(tile.position.x,tile.end.y)])]
	# Shared exact footprints: the garden soil genuinely replaces the paving.
	# These planting polygons are larger than a tile, so no interior-hole rings
	# can be produced inside one piece by the polygon difference operation.
	var cuts := _arrival_garden_outlines()
	# The actual cover and recessed lifting pockets replace paving, not overlay it.
	cuts.append(PackedVector2Array([Vector2(4.18,181.58),Vector2(4.82,181.58),Vector2(4.82,182.22),Vector2(4.18,182.22)]))
	for garden: PackedVector2Array in cuts:
		var remaining: Array[PackedVector2Array] = []
		for piece: PackedVector2Array in pieces:
			for clipped: PackedVector2Array in Geometry2D.clip_polygons(piece,garden):
				if clipped.size() >= 3: remaining.append(clipped)
		pieces = remaining
		if pieces.is_empty(): break
	return pieces

static func _paver_piece(street: Node3D,parent: Node3D,outline: PackedVector2Array,tile: Rect2,key: String,walk_triangles: Array[PackedVector3Array]=[]) -> void:
	var points := PackedVector3Array()
	# Pavers stay dead flat at the walking plane: sub-millimetre lips were tried and
	# cast long shadow stripes under the low sun that read as dirt, not bedding.
	for point: Vector2 in outline:
		var y := PAVEMENT_Y if walk_triangles.is_empty() else _walk_height(point,walk_triangles)+.014
		if not is_finite(y): return
		points.append(Vector3(point.x,y,point.y))
	var indices := Geometry2D.triangulate_polygon(outline)
	if indices.is_empty(): return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in indices:
		tool.set_normal(Vector3.UP)
		tool.set_uv((outline[index]-tile.position)/tile.size)
		tool.add_vertex(points[index])
	# The shallow sides expose real joints and the lowered soil, without steps
	# or new collision over the original supported entrance.
	for i: int in range(points.size()):
		var j := (i+1)%points.size()
		var tangent := points[j]-points[i]
		var outward := Vector3(tangent.z,0,-tangent.x).normalized()
		for vertex: Vector3 in [points[i],points[j],points[j]+Vector3.DOWN*.014,points[i],points[j]+Vector3.DOWN*.014,points[i]+Vector3.DOWN*.014]:
			tool.set_normal(outward)
			tool.set_uv((Vector2(vertex.x,vertex.z)-tile.position)/tile.size)
			tool.add_vertex(vertex)
	var visual := MeshInstance3D.new()
	visual.name = "GardenFittedMineralSlab"
	visual.mesh = tool.commit()
	var mats: Dictionary = street.get("materials")
	visual.material_override = mats[key]
	parent.add_child(visual)

static func _ramp(street: Node3D,parent: Node3D,label: String,start_z: float,end_z: float,start_y: float,end_y: float) -> void:
	# This original six-vertex mesh remains the collision, byte-for-byte in
	# coordinate order. Only the visible paving is subdivided into real stones.
	var vertices := PackedVector3Array([Vector3(-3,start_y,start_z),Vector3(3,start_y,start_z),Vector3(-3,end_y,end_z),Vector3(3,start_y,start_z),Vector3(3,end_y,end_z),Vector3(-3,end_y,end_z)])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := Vector3(0,1,(start_y-end_y)/(end_z-start_z)).normalized()
	for vertex: Vector3 in vertices:
		surface.set_normal(normal)
		surface.set_uv(Vector2(vertex.x,vertex.z))
		surface.add_vertex(vertex)
	var collision_mesh := surface.commit()
	var mats: Dictionary = street.get("materials")
	var tools: Array[SurfaceTool] = []
	for shade: int in range(6):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(mats["land_slab_%d"%shade] if shade<5 else mats.land_joint)
		tools.append(tool)
	# A supported joint bed sits 14mm below the unchanged walking plane.
	for vertex: Vector3 in vertices:
		tools[5].set_normal(normal)
		tools[5].set_uv(Vector2(vertex.x,vertex.z))
		tools[5].add_vertex(vertex+Vector3.DOWN*.014)
	var tiles: Array[Dictionary] = []
	var z := start_z
	var grid_origin := 180.0 if start_z<185.0 else 190.0
	while z<end_z-.001:
		var row := int(floor((z-grid_origin+.0001)/.8))
		var next_z := minf(end_z,grid_origin+float(row+1)*.8)
		var x := -3.0
		var column := 0
		while x<3.0-.001:
			var dx := minf(.3 if column==0 and row%2!=0 else .6,3.0-x)
			var tile := Rect2(x+.005,z+.005,dx-.010,next_z-z-.010)
			var shade := posmod((row*71+column*127+17)^(row*column*31),5)
			var points := PackedVector3Array()
			for corner: Vector2 in [tile.position,Vector2(tile.end.x,tile.position.y),tile.end,Vector2(tile.position.x,tile.end.y)]:
				points.append(Vector3(corner.x,lerpf(start_y,end_y,(corner.y-start_z)/(end_z-start_z)),corner.y))
			for index: int in [0,1,3,1,2,3]:
				tools[shade].set_normal(normal)
				tools[shade].set_uv((Vector2(points[index].x,points[index].z)-tile.position)/tile.size)
				tools[shade].add_vertex(points[index])
			for side: int in range(4):
				var a := points[side]
				var b := points[(side+1)%4]
				var edge := b-a
				var outward := Vector3(edge.z,0,-edge.x).normalized()
				for vertex: Vector3 in [a,b,b+Vector3.DOWN*.014,a,b+Vector3.DOWN*.014,a+Vector3.DOWN*.014]:
					tools[shade].set_normal(outward)
					tools[shade].set_uv(Vector2(vertex.x,vertex.z))
					tools[shade].add_vertex(vertex)
			var bounds := AABB(points[0],Vector3.ZERO)
			for point: Vector3 in points:
				bounds=bounds.expand(point).expand(point+Vector3.DOWN*.014)
			tiles.append({"rect":tile,"bounds":bounds,"top_corners":points,"material":"land_slab_%d"%shade})
			x+=dx
			column+=1
		z=next_z
	var mesh := ArrayMesh.new()
	for tool: SurfaceTool in tools:
		tool.commit(mesh)
	var visual := MeshInstance3D.new()
	visual.name=label
	visual.mesh=mesh
	parent.add_child(visual)
	var body := StaticBody3D.new()
	body.name=label+"Collision"
	body.collision_mask=0
	var shape := CollisionShape3D.new()
	var floor_shape := collision_mesh.create_trimesh_shape()
	floor_shape.backface_collision=true
	shape.shape=floor_shape
	body.add_child(shape)
	parent.add_child(body)
	var report := {"id":label,"rect":Rect2(-3,start_z,6,end_z-start_z),"start_y":start_y,"end_y":end_y,
		"collision_vertices":vertices,"collision_faces":floor_shape.get_faces(),"collision_count":1,
		"visual_bounds":visual.transform*visual.get_aabb(),"tiles":tiles,"tile_count":tiles.size(),
		"course_pitch_m":Vector2(.6,.8),"joint_m":.010,"joint_recess_m":.014,"walking_plane_unchanged":true,
		"material_sources":["res://assets/shinrai/drain_hgu150/ProjectShinrai_HGU150_Drain_GameReady_SHINRAI_PrecastPaver_BaseColor_1K.png","res://assets/shinrai/drain_hgu150/ProjectShinrai_HGU150_Drain_GameReady_SHINRAI_PrecastExterior_NormalGL_1K.png","res://assets/shinrai/drain_hgu150/ProjectShinrai_HGU150_Drain_GameReady_SHINRAI_PrecastExterior_ORM_1K.png"]}
	visual.set_meta("sloped_paving_construction",report)
	var ramps: Array = parent.get_meta("sloped_paving_construction",[])
	ramps.append(report)
	parent.set_meta("sloped_paving_construction",ramps)

static func _tactile(street: Node3D,parent: Node3D,z: float) -> void:
	_b(street,parent,"TactileCrossingStrip",Vector3(0,.092,z),Vector3(6,.004,.52),"land_tactile")
	var mats: Dictionary = street.get("materials")
	var dot_mesh := CylinderMesh.new()
	dot_mesh.top_radius = .022
	dot_mesh.bottom_radius = .027
	dot_mesh.height = .005
	dot_mesh.radial_segments = 6
	for row: int in range(3):
		for column: int in range(35):
			var dot := MeshInstance3D.new()
			dot.name = "TactileStud"
			dot.mesh = dot_mesh
			dot.material_override = mats.land_tactile
			dot.position = Vector3(-2.89+column*.17,.0965,z-.17+row*.17)
			parent.add_child(dot)

## Cast-iron gully set into the gutter dish, centred on the dish (pos.z).
## 600x240mm frame bedded on a concrete haunch, 6mm proud of the gutter lips
## (y.028 -> .034) like a real bedded casting; 13 bars with 20mm slots over a
## black sump so the slots read as depth; a curb inlet above it catches sheet flow.
static func _drain(street: Node3D,parent: Node3D,pos: Vector3) -> void:
	var toward_curb: float = -1.0 if pos.z < 187.0 else 1.0
	_b(street,parent,"GullyBed",pos+Vector3(0,.024,0),Vector3(.64,.008,.26),"land_gutter")
	_b(street,parent,"GullySump",pos+Vector3(0,.0275,0),Vector3(.56,.003,.20),"land_void")
	for z: float in [-.105,.105]:
		_b(street,parent,"GullyFrameSide",pos+Vector3(0,.031,z),Vector3(.60,.006,.03),"land_iron")
	for x: float in [-.285,.285]:
		_b(street,parent,"GullyFrameEnd",pos+Vector3(x,.031,0),Vector3(.03,.006,.24),"land_iron")
	for i: int in range(13):
		_b(street,parent,"GullyBar",pos+Vector3(-.252+float(i)*.042,.030,0),Vector3(.022,.004,.18),"land_iron")
	for z: float in [-.03,.03]:
		_b(street,parent,"GullyTie",pos+Vector3(0,.0305,z),Vector3(.54,.003,.012),"land_iron")
	# Inlet opening through the curb face (Z183.00/190.00), 460x56mm, with a
	# cast lintel at the curb's chamfer line.
	var face_z: float = pos.z+toward_curb*.112
	_b(street,parent,"CurbInletOpening",Vector3(pos.x,.062,face_z),Vector3(.46,.056,.008),"land_void")
	_b(street,parent,"CurbInletLintel",Vector3(pos.x,.094,face_z+toward_curb*(-.003)),Vector3(.50,.008,.014),"land_iron")

## Round sewer cover in the carriageway: a 1.0m square asphalt cut (its own
## sourced texture, 1mm proud) and a 600mm cast lid 2.5mm proud of the road.
static func _manhole(street: Node3D,parent: Node3D,pos: Vector3) -> void:
	var mats: Dictionary = street.get("materials")
	if not mats.has("road_manhole_cover") or not mats.has("road_manhole_cut"): return
	var cut := SurfaceTool.new()
	cut.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]
	for index: int in [0,1,2,0,2,3]:
		var corner: Vector2 = corners[index]
		cut.set_normal(Vector3.UP)
		cut.set_uv(corner+Vector2(.5,.5))
		cut.add_vertex(Vector3(corner.x,0,corner.y))
	_fitted(street,parent,"ManholeAsphaltCut",cut.commit(),pos+Vector3(0,ROAD_Y+.001,0),"road_manhole_cut")
	var lid := SurfaceTool.new()
	lid.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius := .30
	var segments := 28
	for i: int in range(segments):
		var a := TAU*float(i)/float(segments)
		var b := TAU*float(i+1)/float(segments)
		# Godot front faces wind clockwise seen from outside (cross product opposite the normal).
		for point: Vector2 in [Vector2.ZERO,Vector2(cos(a),sin(a))*radius,Vector2(cos(b),sin(b))*radius]:
			lid.set_normal(Vector3.UP)
			lid.set_uv(Vector2(.5,.5)+point/(radius*2.0))
			lid.add_vertex(Vector3(point.x,0,point.y))
	# A short rim face so the lid reads as a solid casting from low angles.
	for i: int in range(segments):
		var a := TAU*float(i)/float(segments)
		var b := TAU*float(i+1)/float(segments)
		var pa := Vector3(cos(a),0,sin(a))*radius
		var pb := Vector3(cos(b),0,sin(b))*radius
		for vertex: Vector3 in [pa,pb+Vector3.DOWN*.004,pb,pa,pa+Vector3.DOWN*.004,pb+Vector3.DOWN*.004]:
			lid.set_normal((vertex*Vector3(1,0,1)).normalized())
			lid.set_uv(Vector2(.5,.5))
			lid.add_vertex(vertex)
	_fitted(street,parent,"ManholeCastLid",lid.commit(),pos+Vector3(0,ROAD_Y+.0025,0),"road_manhole_cover")

static func _fitted(street: Node3D,parent: Node3D,label: String,mesh: Mesh,pos: Vector3,key: String) -> void:
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.position = pos
	var mats: Dictionary = street.get("materials")
	visual.material_override = mats[key]
	parent.add_child(visual)

static func _approach_paving(street: Node3D,parent: Node3D) -> Dictionary:
	# The visible entrance apron is ABOVE the route mesh: MainSouthEntrance top
	# .14 versus SouthEntranceToLake .111. Sample both and use the upper surface.
	var park := street.get_parent()
	var sources: Array[MeshInstance3D] = []
	var source_names: Array[String] = []
	for name: String in ["SouthEntranceToLake","MainSouthEntrance"]:
		var existing := park.find_child(name,true,false) as MeshInstance3D
		if existing != null and existing.mesh != null:
			sources.append(existing)
			source_names.append(name)
	if sources.is_empty():
		return {"status":"omitted_no_existing_path_mesh","slabs":0,"minimum_z":180.0}
	var triangles: Array[PackedVector3Array] = []
	for walk: MeshInstance3D in sources:
		for surface: int in range(walk.mesh.get_surface_count()):
			var arrays: Array = walk.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for i: int in range(0,count,3):
				var triangle := PackedVector3Array()
				for j: int in range(3):
					triangle.append(walk.global_transform*vertices[indices[i+j] if not indices.is_empty() else i+j])
				if maxf(triangle[0].z,maxf(triangle[1].z,triangle[2].z)) < 174.0: continue
				if minf(triangle[0].z,minf(triangle[1].z,triangle[2].z)) > 180.0: continue
				triangles.append(triangle)
	var built := 0
	var minimum_z := 180.0
	for row: int in range(8):
		var z0 := 174.0+row*.75
		var z1 := z0+.75
		for column: int in range(41):
			var cell_start := -12.0+column*.6-(.3 if row%2 == 1 else 0.0)
			var u0 := maxf(-12.0,cell_start)+.004
			var u1 := minf(12.0,cell_start+.6)-.004
			if u1 <= u0: continue
			var valid := true
			for corner: Vector2 in [Vector2(u0,z0+.005),Vector2(u1,z0+.005),Vector2(u0,z1-.005),Vector2(u1,z1-.005)]:
				var x := corner.x
				var height := _walk_height(Vector2(x,corner.y),triangles)
				if not is_finite(height):
					valid = false
					break
			if not valid: continue
			var tile := Rect2(u0,z0+.005,u1-u0,.74)
			var shade := posmod((row*71+column*127)^(row*column*31),5)
			for piece: PackedVector2Array in _paver_cutouts(tile):
				_paver_piece(street,parent,piece,tile,"land_slab_%d" % shade,triangles)
			# The existing pad supports feet14mm below this decorative stone skin.
			# Extra collision here falsely rejects the existing path-lantern socket.
			minimum_z = minf(minimum_z,z0+.005)
			built += 1
	return {"status":"sampled_uppermost_existing_entrance_apron","slabs":built,"minimum_z":minimum_z,
		"sampled_sources":source_names,"surface_lift_m":.014,"width_m":24.0,"garden_cutouts":4,
		"collision_support":"unchanged existing entrance pad and path",
		"existing_path_mesh_modified":false,"foreground_plants_added":true,"paver_nominal_m":Vector2(.6,.75),"staggered":true}

static func _walk_height(point: Vector2,triangles: Array[PackedVector3Array]) -> float:
	var height := -INF
	for triangle: PackedVector3Array in triangles:
		var a: Vector3 = triangle[0]
		var b: Vector3 = triangle[1]
		var c: Vector3 = triangle[2]
		var denominator := (b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
		if absf(denominator) < .000001: continue
		var u := ((b.z-c.z)*(point.x-c.x)+(c.x-b.x)*(point.y-c.z))/denominator
		var v := ((c.z-a.z)*(point.x-c.x)+(a.x-c.x)*(point.y-c.z))/denominator
		var w := 1.0-u-v
		if u >= -.0001 and v >= -.0001 and w >= -.0001:
			height = maxf(height,u*a.y+v*b.y+w*c.y)
	return height

static func _planting(street: Node3D) -> Dictionary:
	var tree := _prototype(TREE_PACK,TREE_NAME)
	var shop_tree := _prototype(TREE_PACK,"Tree EZTree0.Medium010")
	var frame_tree := _prototype(TREE_PACK,"Tree EZTree1.Large001")
	var leaf_mass := _prototype(TREE_PACK,"Tree EZTree1.Bush006_leaves.006_0")
	_prune_frame_crown(frame_tree,.41,1.15/8.3)
	street.call("_material","foliage_grass",Color("#536b3d"),.95)
	street.call("_material","foliage_flower",Color("#d6d8b8"),.92)
	var mats: Dictionary = street.get("materials")
	(mats.foliage_grass as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	# Exact green source subset used by park.forest_floor_bush_prototypes[0].
	var shrub := _prototype(TREE_PACK,SHRUB_NAME)
	var fern := _prototype(FERN,"")
	var backdrop_pine := _prototype(PINE_PACK,"Pine_big_1_LOD1")
	var placements: Array[Dictionary] = []
	var trees := 0
	var shrubs := 0
	var ferns := 0
	var leaf_masses := 0
	var flower_clusters := 0
	var framing_bounds: Array[AABB] = []
	var backdrop_bounds: Array[AABB] = []
	var courtyard_groundcover := 0
	var foreground_minimum_z := 174.25
	for side: float in [-1.0,1.0]:
		var suffix := "West" if side < 0.0 else "East"
		var foreground := _corner_garden(street,side)
		var frame_bound := _instance(frame_tree,foreground,Vector3(.3 if side < 0.0 else -.3,0,2.1 if side < 0.0 else 1.75),8.4 if side < 0.0 else 8.0,side*.15,true)
		if frame_bound.size.length_squared() > .001:
			framing_bounds.append(frame_bound)
			foreground_minimum_z = minf(foreground_minimum_z,frame_bound.position.z)
		trees += 1
		# Dense, overlapping layers follow an irregular footprint; taller masses
		# stay toward the outside, while ferns and fine blades soften the path edge.
		for i: int in range(42):
			var angle := i*2.399963+side*.3
			var radial := sqrt((i+.45)/42.0)
			var px := cos(angle)*3.0*radial
			var pz := sin(angle)*2.27*radial
			var world_x := side*6.6+px
			var band := clampf((absf(world_x)-4.1)/4.3,0.0,1.0)
			var plant_height := clampf(.48+.50*band+.07*sin(i*2.1),.45,1.05)
			# Exact source XZ/height ratios cap inner plants before the6m path.
			var radius_per_height := .5*(1.592*absf(cos(angle))+1.508*absf(sin(angle)))
			plant_height = minf(plant_height,(absf(world_x)-3.06)/maxf(radius_per_height,.1))
			_instance(leaf_mass,foreground,Vector3(px,0,pz),plant_height,angle)
			leaf_masses += 1
		for i: int in range(17):
			var angle := i*2.399963+1.1
			var radial := .35+.6*sqrt((i+.3)/17.0)
			var px := cos(angle)*3.1*radial
			var pz := sin(angle)*2.15*radial
			_instance(fern,foreground,Vector3(px,-.006,pz),.50+.065*(i%4),angle)
			ferns += 1
			if i%2 == 0:
				_grass_tuft(foreground,Vector3(px+.18,0,pz-.12),.35+.045*(i%3),mats.foliage_grass,i)
			if i%6 == 0:
				_tiny_flowers(foreground,Vector3(px-.16,0,pz+.19),mats.foliage_grass,mats.foliage_flower,i)
				flower_clusters += 1
		# Fine spreading patches interrupt the dominant round-leaf silhouette.
		for i: int in range(24):
			var angle := i*2.399963+.7*side
			var radial := sqrt((i+.35)/24.0)
			var px := cos(angle)*2.95*radial
			var pz := sin(angle)*2.2*radial
			_grass_tuft(foreground,Vector3(px,0,pz),.29+.055*(i%4),mats.foliage_grass,i*3)
			if i%2 == 0:
				_instance(leaf_mass,foreground,Vector3(px+.12,-.012,pz-.1),.24+.035*(i%3),angle+.8)
				leaf_masses += 1
		# Low decorative tips enter the camera's lower corners. All roots/stone
		# remain outsideX+-3; only noncolliding leaves reach towardX+-2.70.
		for i: int in range(5):
			_instance(fern,foreground,Vector3(-side*3.36,-.006,-1.9+i*.7),.66+.02*(i%3),PI*.25)
			_instance(leaf_mass,foreground,Vector3(-side*3.24,0,-1.45+i*.7),.60,PI*.25)
			ferns += 1
			leaf_masses += 1
		placements.append({"kind":"grounded_foreground_garden","outline":_arrival_garden_outlines()[0 if side < 0.0 else 1],"soil_world_y":.143,"collision":false,"frame_tree_height":8.4 if side < 0.0 else 8.0,"minimum_leaf_crown_world_y":3.42,"leaf_coverage_target":.80})
		var north := _arrival_soil_garden(street,2 if side < 0.0 else 3)
		for i: int in range(9):
			_instance(leaf_mass,north,Vector3(-2.05+i*.49,0,.34*sin(i*2.1)),.38+.06*(i%4),i*1.7)
			leaf_masses += 1
		for i: int in range(8):
			_instance(fern,north,Vector3(-1.99+i*.56,-.005,-.34+.17*cos(i*1.8)),.36+.06*(i%3),i*.85)
			ferns += 1
		for i: int in range(12):
			_grass_tuft(north,Vector3(-2.08+i*.38,0,.26*sin(i*1.8)),.24+.04*(i%4),mats.foliage_grass,i)
		placements.append({"kind":"grounded_near_road_garden","outline":_arrival_garden_outlines()[2 if side < 0.0 else 3],"soil_world_y":.078,"collision":false})
		var end := _bed(street,"ShopEndGarden"+suffix,Vector3(side*28.5,.03,196.3),Vector2(3.0,3.6),.34)
		_instance(tree,end,Vector3(side*.13,.32,.18),4.2,side*.65)
		trees += 1
		for i: int in range(4):
			_instance(shrub,end,Vector3(-.97+i*.64,.32,-1.05),.58+.06*(i%2),i*1.8)
			shrubs += 1
		placements.append({"kind":"shop_end_garden","bounds":Rect2(side*28.5-1.5,194.5,3,3.6),"tree_height_m":4.2})
		var rear := _bed(street,"PassageRearGarden"+suffix,Vector3(side*5.8,.03,205.3),Vector2(3.5,3.2),.32)
		_instance(tree,rear,Vector3(side*.2,.30,0),4.0,side*.3)
		trees += 1
		for i: int in range(3):
			_instance(shrub,rear,Vector3(-1.02+i*1.02,.30,-.94),.69+.08*(i%2),i*1.5)
			shrubs += 1
		for i: int in range(3):
			_instance(fern,rear,Vector3(-1.05+i*1.05,.29,.75),.47,i*1.2)
			ferns += 1
		placements.append({"kind":"rear_passage_garden","bounds":Rect2(side*5.8-1.75,203.7,3.5,3.2),"tree_height_m":4.0})
		var pot := _bed(street,"ServiceSliverPlanter"+suffix,Vector3(side*13.53,.03,194.55),Vector2(.72,.84),.56)
		# Bush006 is broader than the rejected flower sprig. Keep the pot canopy
		# inside the one-metre intershop sliver with a smaller uniform scale.
		_instance(shrub,pot,Vector3(0,.54,0),.42,side)
		shrubs += 1
		placements.append({"kind":"intershop_planter","bounds":Rect2(side*13.53-.36,194.13,.72,.84),"plant_height_m":.42})
		# Distinct small trees bring green height into the broad front view. The
		# measured crowns end before awnings; a 2m strip remains beside storefronts.
		for slot: int in range(2):
			var x := side*(4.9 if slot == 0 else 13.5)
			var front_z := 191.1 if slot == 1 else 191.55
			var tree_height := (3.1 if side < 0.0 else 2.9) if slot == 1 else (2.45 if side < 0.0 else 2.75)
			var front := _bed(street,"StorefrontTree"+suffix+str(slot),Vector3(x,PAVEMENT_Y,front_z),Vector2(.9,.9),.48)
			_instance(shop_tree if slot == 1 else tree,front,Vector3(0,.46,0),tree_height,side*.12)
			_instance(fern,front,Vector3(-.23,.44,-.18),.28,slot)
			_instance(fern,front,Vector3(.22,.44,.17),.32,slot+.8)
			trees += 1
			ferns += 2
			placements.append({"kind":"storefront_tree","bounds":Rect2(x-.45,front_z-.45,.9,.9),"tree_height_m":tree_height,"varied_source":slot == 1})
		var outer := _bed(street,"OuterShopCluster"+suffix,Vector3(side*24.55,PAVEMENT_Y,193.35),Vector2(1.15,.85),.38)
		_instance(shrub,outer,Vector3(-.22,.36,.06),.43,side*.4)
		_instance(fern,outer,Vector3(.32,.35,-.10),.47,side)
		shrubs += 1
		ferns += 1
		placements.append({"kind":"outer_shop_cluster","bounds":Rect2(side*24.55-.575,192.925,1.15,.85)})
		# A confirmed balcony slab supports each entire planter, independently of
		# architecture ownership: local floor4.0 + building root.08 = world4.08.
		var balcony := _bed(street,"BalconyGarden"+suffix,Vector3(side*8,4.08,192.80),Vector2(2.0,.30),.37)
		for i: int in range(5):
			_instance(fern,balcony,Vector3(-.76+i*.38,.35,0),.36+.045*(i%3),i*.7)
			ferns += 1
		for i: int in range(3):
			_instance(shrub,balcony,Vector3(-.65+i*.65,.35,0),.23,i*.4)
			shrubs += 1
		placements.append({"kind":"balcony_garden","bounds":Rect2(side*8-1,192.65,2,.30),"base_y":4.08,"soil_y":4.42})
		for grove: int in range(2):
			var gx := side*(7.7 if grove == 0 else 9.6)
			var gz := 209.0 if grove == 0 else 215.0
			var grove_size := Vector2(5.4,6.2) if grove == 0 else Vector2(5.0,5.8)
			var garden := _bed(street,"CourtyardGrove"+suffix+str(grove),Vector3(gx,.03,gz),grove_size,.28)
			_instance(tree,garden,Vector3(0,.26,.12),4.8 if grove == 0 else 5.0,side*.3)
			trees += 1
			for i: int in range(5):
				var px := -1.67+(i%3)*1.6
				var pz := -1.9+floorf(i/3.0)*3.4
				_instance(shrub,garden,Vector3(px,.26,pz),.73+.09*(i%3),i*.9+side)
				shrubs += 1
			for i: int in range(4):
				_instance(fern,garden,Vector3(-1.65+i*1.05,.25,-.4+.6*sin(i*2.0)),.51+.04*(i%2),i)
				ferns += 1
			# Reuse grounded park plants to break up the bare soil around the trees.
			# Every root remains in the existing grove; the central walk stays clear.
			for patch: int in range(26):
				var px := -2.05+float(patch%6)*.79
				var pz := -2.35+float(patch/6)*1.05+.16*sin(float(patch)*2.1)
				_grass_tuft(garden,Vector3(px,.25,pz),.24+.04*float(patch%3),mats.foliage_grass,patch+grove*31)
				if patch%3 == 0:
					_instance(leaf_mass,garden,Vector3(px,.25,pz),.28+.035*float(patch%4),float(patch)*1.9)
					leaf_masses += 1
				courtyard_groundcover += 1
			placements.append({"kind":"courtyard_grove","bounds":Rect2(gx-grove_size.x*.5,gz-grove_size.y*.5,grove_size.x,grove_size.y),"tree_height_m":4.8 if grove == 0 else 5.0})
	# Paired rooted beds frame the new walk rather than block the centre.
	for side: float in [-1.0,1.0]:
		var backdrop := _bed(street,"CourtyardOpeningGarden"+("L" if side<0 else "R"),Vector3(side*4.1,.03,217.4),Vector2(5.0,1.8),.75)
		for i: int in range(5):
			_instance(shrub,backdrop,Vector3(-1.95+i*.975,.72,.05),1.18,float(i)*.3)
			shrubs += 1
		var bound := _instance(tree,backdrop,Vector3(side*.5,.72,.10),5.9 if side<0 else 5.7,side*.9,true)
		backdrop_bounds.append(bound)
		trees += 1
		placements.append({"kind":"courtyard_opening_garden","bounds":Rect2(side*4.1-2.5,216.5,5,1.8),"clear_central_route_width_m":3.2,"hedge_total_height_m":1.94})
	var threshold_groups := _threshold_planting(street,shrub,fern)
	for group: Dictionary in threshold_groups:
		for container: Rect2 in group.container_bounds:
			placements.append({"kind":"layered_threshold_container","group":group.name,"bounds":container,"base_y":.09})
	shrubs += 3
	ferns += 6
	flower_clusters += 3
	var trellis := _passage_trellises(street,leaf_mass)
	leaf_masses += int(trellis.leaf_clusters)

	if tree != null: tree.free()
	if shop_tree != null: shop_tree.free()
	if frame_tree != null: frame_tree.free()
	if leaf_mass != null: leaf_mass.free()
	if shrub != null: shrub.free()
	if fern != null: fern.free()
	if backdrop_pine != null: backdrop_pine.free()
	return {"trees":trees,"shrubs":shrubs,"leaf_masses":leaf_masses,"ferns":ferns,"tiny_flower_clusters":flower_clusters,"beds":placements.size(),"placement_bounds":placements,
		"tree_source_triangles":6806,"shrub_source_triangles":15972,
		"fern_source_triangles":8921,
		"backdrop_tree_world_bounds":backdrop_bounds,"courtyard_groundcover_patches":courtyard_groundcover,"passage_trellises":trellis,"threshold_groups":threshold_groups,
		"arrival_garden_outlines":_arrival_garden_outlines(),"arrival_garden_new_collisions":0,
		"arrival_plant_roots_inside_soil":true,
		"foreground_new_collisions":0,"foreground_tree_shadows":"native cutout leaf and branch geometry, cast_shadow ON",
		"foreground_tree_world_bounds":framing_bounds,"foreground_visual_minimum_z":foreground_minimum_z,
		"geometry_normalization":"uniform target height, visual bounds centered XZ and minimum Y grounded"}

# Three deliberate pairs at facade ends, outside doors and the six-metre route.
# Existing storefront trees and all court/lane/arrival garden memberships survive.
static func _threshold_planting(street: Node3D, shrub: Node3D, fern: Node3D) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var mats: Dictionary = street.get("materials")
	for row: Array in [["DailyPassage",-3.88,193.28,-1.0],["CoffeePassage",3.88,193.23,1.0],["BooksOuter",25.75,192.72,1.0]]:
		var label: String = row[0]
		var x: float = row[1]
		var z: float = row[2]
		var side: float = row[3]
		var bounds: Array[AABB] = []
		var tall := _bed(street,"ThresholdMedium"+label,Vector3(x,.09,z),Vector2(.54,.62),.43)
		bounds.append(_instance(shrub,tall,Vector3(0,.40,0),.72,side*.65,true))
		bounds.append(_instance(fern,tall,Vector3(side*.10,.40,-.11),.30,side,true))
		var low := _bed(street,"ThresholdLow"+label,Vector3(x+side*.62,.09,z-.23),Vector2(.48,.48),.27)
		bounds.append(_instance(fern,low,Vector3(0,.24,0),.49,side*1.3,true))
		_tiny_flowers(low,Vector3(-side*.10,.24,-.06),mats.foliage_grass,mats.foliage_flower,groups.size()+19)
		tall.set_meta("layered_greenery_group",label)
		low.set_meta("layered_greenery_group",label)
		groups.append({"name":label,"containers":2,"shrubs":1,"ferns":2,"flower_clusters":1,"plant_world_bounds":bounds,"container_bounds": [Rect2(x-.27,z-.31,.54,.62),Rect2(x+side*.62-.24,z-.47,.48,.48)],"base_world_y":.09,"soil_top_world_y":[.49,.33],"root_world_y":[.49,.33],"door_and_passage_clear":true})
	return groups

# Narrow rooted climbers connect bare passage walls to the courtyard greenery.
# Steel rails are stood off the wall, vines follow the rails, and leaf masses
# stay at the wall edge; the central 5.2m-wide passage remains unobstructed.
static func _passage_trellises(street: Node3D, leaf_mass: Node3D) -> Dictionary:
	var leaf_count := 0
	var roots: Array[Vector3] = []
	var frame_count := 0
	var frame_bounds: Array[AABB] = []
	for side: float in [-1.0,1.0]:
		for slot: int in range(2):
			var center_z := 197.2+float(slot)*3.1
			var root := _bed(street,"PassageClimber"+str(side)+str(slot),Vector3(side*2.80,.09,center_z),Vector2(.30,1.72),.27)
			# Forty-five millimetre real substrate gap from planter wall to root.
			roots.append(Vector3(side*2.80,.32,center_z))
			for z: float in [-.76,.76]:
				_trellis_rod(street,root,Vector3(0,.25,z),Vector3(0,2.62,z),.012,"arch_metal")
				for y: float in [.48,2.48]:
					_b(street,root,"TrellisWallStandOff",Vector3(side*.085,y,z),Vector3(.17,.028,.028),"arch_metal")
					_b(street,root,"TrellisWallPlate",Vector3(side*.185,y,z),Vector3(.012,.09,.075),"arch_metal")
			for y: float in [.48,1.13,1.78,2.48]:
				_trellis_rod(street,root,Vector3(0,y,-.76),Vector3(0,y,.76),.006,"arch_metal")
			var leaves := SurfaceTool.new()
			leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
			for vine: int in range(5):
				var previous := Vector3(-side*.025,.24,-.64+float(vine)*.32)
				for joint: int in range(11):
					var point := Vector3(-side*.028,.37+float(joint)*.215,-.64+float(vine)*.32+.09*sin(float(joint)*1.8+vine))
					_trellis_rod(street,root,previous,point,.0045,"detail_vine_stem")
					_climber_leaf_cluster(street,root,point+Vector3(-side*.035,-.025,0),side,joint+vine*11,leaves)
					leaf_count += 1
					previous = point
			var visual := MeshInstance3D.new()
			visual.name = "BatchedFoldedClimberLeaves"
			visual.mesh = leaves.commit()
			visual.material_override = street.get("materials")["foliage_grass"]
			root.add_child(visual)
			frame_bounds.append(visual.global_transform*visual.get_aabb())
			root.set_meta("layered_greenery_membership",{"rooted_vines":5,"clusters":55,"leaves":550,"leaf_meshes":1})
			frame_count += 1
	return {"frames":frame_count,"leaf_clusters":leaf_count,"root_world_positions":roots,"minimum_clear_passage_m":5.2,"wall_mounts_per_frame":4,"leaf_world_bounds":frame_bounds,"rooted_vines":20,"leaves":2200,"leaf_triangles":22000,"leaf_meshes":4,"root_soil_world_y":.33,"maximum_leaf_projection_m":.18}

static func _trellis_rod(street: Node3D, parent: Node3D, a: Vector3, b: Vector3, radius: float, key: String) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	mesh.rings = 1
	var rod := MeshInstance3D.new()
	rod.name = ("ClimbingStem" if key == "detail_vine_stem" else "MountedTrellisRod")+"_%03d"%parent.get_child_count()
	rod.mesh = mesh
	rod.material_override = street.get("materials")[key]
	rod.position = (a+b)*.5
	rod.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	parent.add_child(rod)

static func _climber_leaf_cluster(street: Node3D, parent: Node3D, origin: Vector3, side: float, seed_value: int, tool: SurfaceTool) -> void:
	# Small folded, lobed leaves use one hundred triangles per cluster, avoiding
	# dozens of full shrub meshes for a narrow wall climber.
	var outline := PackedVector2Array([Vector2(0,0),Vector2(-.24,.27),Vector2(-.48,.40),Vector2(-.27,.59),Vector2(-.31,.78),Vector2(0,1),Vector2(.31,.78),Vector2(.27,.59),Vector2(.48,.40),Vector2(.24,.27)])
	for leaf: int in range(10):
		var angle := float(leaf)*2.399+float(seed_value)*.37
		var length := .125+.012*float((leaf+seed_value)%4)
		var shift := Vector3(-side*(.01+.009*float(leaf%3)),.075*sin(angle),.105*cos(angle))
		var leaf_origin := origin+shift
		var along := Vector3(-side*.20,cos(angle*.45),sin(angle*.45)).normalized()
		var across := Vector3(0,-along.z,along.y).normalized()
		var ridge := leaf_origin+along*length*.49+Vector3(-side*.014,0,0)
		for i: int in range(outline.size()):
			var a := leaf_origin+across*outline[i].x*length+along*outline[i].y*length
			var next := outline[(i+1)%outline.size()]
			var b := leaf_origin+across*next.x*length+along*next.y*length
			var normal := (a-ridge).cross(b-ridge).normalized()
			if normal.x*side > 0.0: normal = -normal
			var tri := [ridge,a,b]
			if (a-ridge).cross(b-ridge).dot(normal) > 0: tri = [ridge,b,a]
			for vertex: Vector3 in tri:
				tool.set_normal(normal)
				tool.add_vertex(vertex)

static func _arrival_garden_outlines() -> Array[PackedVector2Array]:
	# WORLD XZ. One contract for root's paving cutouts and these recessed soils.
	return [
		PackedVector2Array([Vector2(-10.05,174.35),Vector2(-8.7,174.1),Vector2(-6,174.12),Vector2(-4.1,174.55),Vector2(-3.15,175.2),Vector2(-3.16,176.4),Vector2(-3.38,177.55),Vector2(-3.22,178.65),Vector2(-4.35,179.55),Vector2(-6.8,179.68),Vector2(-8.8,179.32),Vector2(-10,178.4),Vector2(-10.2,176.35)]),
		PackedVector2Array([Vector2(3.15,174.55),Vector2(4.65,174.12),Vector2(7.3,174.25),Vector2(9.6,174.65),Vector2(10.1,175.75),Vector2(10,177.75),Vector2(8.8,179.25),Vector2(6.5,179.62),Vector2(4.45,179.38),Vector2(3.2,178.55),Vector2(3.38,177.35),Vector2(3.16,176)]),
		PackedVector2Array([Vector2(-11,180.28),Vector2(-9.6,180.2),Vector2(-7.6,180.32),Vector2(-6.08,180.22),Vector2(-5.85,180.68),Vector2(-6.12,181.42),Vector2(-7.7,181.72),Vector2(-9.9,181.62),Vector2(-11.05,181.1)]),
		PackedVector2Array([Vector2(6.1,180.34),Vector2(7.7,180.22),Vector2(9.9,180.3),Vector2(11.1,180.72),Vector2(10.9,181.35),Vector2(9.7,181.74),Vector2(7.75,181.6),Vector2(5.95,181.42),Vector2(5.8,180.82)])
	]

static func _corner_garden(street: Node3D,side: float) -> Node3D:
	return _arrival_soil_garden(street,0 if side < 0.0 else 1)

static func _arrival_soil_garden(street: Node3D,index: int) -> Node3D:
	var foreground := index < 2
	var side := -1.0 if index%2 == 0 else 1.0
	var origin := Vector3(side*(6.6 if foreground else 8.5),.143 if foreground else .078,176.9 if foreground else 181.0)
	var root: Node3D = street.call("_root","RecessedArrivalGarden_%d" % index,origin,"Grounded Arrival Garden","garden")
	var world_outline: PackedVector2Array = _arrival_garden_outlines()[index]
	var outline := PackedVector2Array()
	for point: Vector2 in world_outline: outline.append(point-Vector2(origin.x,origin.z))
	var mats: Dictionary = street.get("materials")
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(outline)
	for soil_index: int in indices:
		var point := outline[soil_index]
		tool.set_normal(Vector3.UP)
		tool.set_uv(point)
		tool.add_vertex(Vector3(point.x,0,point.y))
	var soil := MeshInstance3D.new()
	soil.name = "IrregularRecessedSoil"
	soil.mesh = tool.commit()
	var soil_material := (mats.land_soil as StandardMaterial3D).duplicate() as StandardMaterial3D
	soil_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	soil.material_override = soil_material
	root.add_child(soil)
	var serial := 0
	for i: int in range(outline.size()):
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		var delta := b-a
		var distance := .10
		while distance < delta.length()-.12:
			var length := minf(.47+.035*(serial%3),delta.length()-distance-.08)
			if serial%3 != 1 and length > .12:
				var point := a+delta.normalized()*(distance+length*.5)
				var edge: MeshInstance3D = street.call("_box",root,"InterruptedFlushStone",Vector3(point.x,.002,point.y),Vector3(length,.08,.10),"land_pot",false)
				edge.rotation.y = -atan2(delta.y,delta.x)
			distance += length+.19
			serial += 1
	# A few irregular exposed caps, mostly buried. All existing ground collision
	# remains untouched; these four gardens contain no CollisionObject at all.
	for i: int in range(4 if foreground else 2):
		var corner := outline[(i*3+index+2)%outline.size()]
		var point := corner*.82
		var source := SphereMesh.new()
		source.radius = .20+.025*(i%2)
		source.height = .26
		source.radial_segments = 7
		source.rings = 3
		var arrays: Array = source.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex: int in range(vertices.size()):
			vertices[vertex] *= .88+.16*sin(vertices[vertex].x*31+vertices[vertex].z*47+i*1.8)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var stone_mesh := ArrayMesh.new()
		stone_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var rock := MeshInstance3D.new()
		rock.name = "PartlyExposedGardenStone"
		rock.mesh = stone_mesh
		rock.material_override = mats.land_pot
		rock.position = Vector3(point.x,.024,point.y)
		rock.scale = Vector3(1.25,.72,1.05)
		rock.rotation.y = i*1.7+index
		root.add_child(rock)
	root.set_meta("foreground_collision_free",true)
	root.set_meta("arrival_outline_world",world_outline)
	root.set_meta("soil_world_y",origin.y)
	root.set_meta("adjacent_paving_y",.154 if foreground else .09)
	root.set_meta("edge_top_world_y",origin.y+.042)
	root.set_meta("ground_level_garden",true)
	root.set_meta("exclude_facade_fill",true)
	return root

static func _prune_frame_crown(prototype: Node3D,minimum_fraction: float,trunk_radius_fraction: float) -> void:
	if prototype == null: return
	var bounds: AABB = prototype.get_meta("source_bounds")
	var cut := bounds.position.y+bounds.size.y*minimum_fraction
	var pivot := Vector2(bounds.get_center().x,bounds.get_center().z)
	var trunk_radius := bounds.size.y*trunk_radius_fraction
	for visual: MeshInstance3D in prototype.get_children():
		var source_mesh := visual.mesh
		var trimmed := ArrayMesh.new()
		var leaf_part := str(visual.name).to_lower().contains("leav")
		for surface: int in range(source_mesh.get_surface_count()):
			var arrays: Array = source_mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var input: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := input.size() if not input.is_empty() else vertices.size()
			var parents := PackedInt32Array()
			var dropped: Dictionary = {}
			var connected_cards := false
			if leaf_part:
				parents.resize(vertices.size())
				for vertex: int in range(vertices.size()): parents[vertex] = vertex
				for i: int in range(0,count,3):
					var a: int = input[i] if not input.is_empty() else i
					for j: int in range(1,3):
						var b: int = input[i+j] if not input.is_empty() else i+j
						parents[_union_root(parents,b)] = _union_root(parents,a)
				var groups: Dictionary = {}
				for i: int in range(count):
					var index: int = input[i] if not input.is_empty() else i
					var group := _union_root(parents,index)
					var point: Vector3 = visual.transform*vertices[index]
					if not groups.has(group): groups[group] = {"minimum":point.y,"sum":Vector3.ZERO,"count":0}
					var row: Dictionary = groups[group]
					row.minimum = minf(float(row.minimum),point.y)
					row.sum += point
					row.count += 1
				connected_cards = groups.size() > 4
				if connected_cards:
					for group: int in groups:
						var row: Dictionary = groups[group]
						var centre: Vector3 = row.sum/float(row.count)
						var n := (centre-bounds.position)/bounds.size.y
						var nx := (centre.x-bounds.get_center().x)/bounds.size.y
						var nz := (centre.z-bounds.get_center().z)/bounds.size.y
						# Two coherent bough openings, never random triangle removal.
						var opening := pow((nx-.13)/.085,2)+pow((n.y-.70)/.09,2)<1.0 and nz<.10
						opening = opening or (pow((nx+.20)/.07,2)+pow((n.y-.86)/.065,2)<1.0 and nz>0)
						if float(row.minimum) < cut or opening: dropped[group] = true
			var retained := PackedInt32Array()
			for i: int in range(0,count,3):
				var keep := true
				if leaf_part and connected_cards:
					keep = not dropped.has(_union_root(parents,input[i] if not input.is_empty() else i))
				else:
					for j: int in range(3):
						var index: int = input[i+j] if not input.is_empty() else i+j
						var point: Vector3 = visual.transform*vertices[index]
						if point.y < cut and (leaf_part or Vector2(point.x,point.z).distance_to(pivot) > trunk_radius): keep = false
				if keep:
					for j: int in range(3): retained.append(input[i+j] if not input.is_empty() else i+j)
			if retained.is_empty(): continue
			arrays[Mesh.ARRAY_INDEX] = retained
			trimmed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			trimmed.surface_set_material(trimmed.get_surface_count()-1,visual.get_active_material(surface))
		visual.mesh = trimmed
		for surface: int in range(trimmed.get_surface_count()): visual.set_surface_override_material(surface,null)
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Bounds remain authored: trunk/base and uniform metric normalization survive.

static func _union_root(parents: PackedInt32Array,index: int) -> int:
	while parents[index] != index: index = parents[index]
	return index

static func _soil_point(parent: Node3D,pos: Vector3) -> Vector3:
	if not parent.get_meta("ground_level_garden",false): return pos
	var outline: PackedVector2Array = parent.get_meta("arrival_outline_world")
	for attempt: int in range(24):
		var world: Vector3 = parent.global_transform*pos
		var point := Vector2(world.x,world.z)
		var edge_distance := INF
		for i: int in range(outline.size()):
			edge_distance = minf(edge_distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,outline[i],outline[(i+1)%outline.size()])))
		if Geometry2D.is_point_in_polygon(point,outline) and edge_distance >= .035: return pos
		pos.x *= .92
		pos.z *= .92
	# These four source-confirmed garden centers are inside their soil polygons.
	return Vector3(0,pos.y,0)

static func _grass_tuft(parent: Node3D,pos: Vector3,height: float,material: Material,seed_value: int) -> void:
	pos = _soil_point(parent,pos)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade: int in range(9):
		var angle := blade*2.399963+seed_value
		var foot := Vector3(cos(angle),0,sin(angle))*(.035+.014*(blade%4))
		foot = _soil_point(parent,pos+foot)-pos
		var across := Vector3(cos(angle),0,sin(angle))*.013
		var tip := foot+Vector3(cos(angle)*.13,height*(.72+.09*(blade%4)),sin(angle)*.13)
		for vertex: Vector3 in [foot-across,foot+across,tip]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(vertex)
	var visual := MeshInstance3D.new()
	visual.name = "FineBladeGroundcover"
	visual.mesh = tool.commit()
	visual.material_override = material
	visual.position = pos
	parent.add_child(visual)

static func _tiny_flowers(parent: Node3D,pos: Vector3,green: Material,cream: Material,seed_value: int) -> void:
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = .0025
	stem_mesh.bottom_radius = .003
	stem_mesh.height = .18
	stem_mesh.radial_segments = 5
	var petal_mesh := SphereMesh.new()
	petal_mesh.radius = .012
	petal_mesh.height = .010
	petal_mesh.radial_segments = 6
	petal_mesh.rings = 3
	for flower: int in range(3):
		var foot := pos+Vector3(cos(flower*2.1+seed_value)*.09,0,sin(flower*2.1+seed_value)*.09)
		foot = _soil_point(parent,foot)
		var stem := MeshInstance3D.new()
		stem.name = "SmallFlowerStem"
		stem.mesh = stem_mesh
		stem.material_override = green
		stem.position = foot+Vector3.UP*.09
		parent.add_child(stem)
		for petal: int in range(5):
			var dot := MeshInstance3D.new()
			dot.name = "TinyCreamPetal"
			dot.mesh = petal_mesh
			dot.material_override = cream
			dot.position = foot+Vector3(cos(petal*TAU/5)*.013,.18,sin(petal*TAU/5)*.013)
			parent.add_child(dot)

static func _bed(street: Node3D,label: String,pos: Vector3,size: Vector2,height: float) -> Node3D:
	var root: Node3D = street.call("_root",label,pos,"South Street Garden","planter")
	var physical := pos.z >= 180.0
	# A complete container/soil/plant root keeps ownership intact after batching.
	for side: float in [-1.0,1.0]:
		_b(street,root,"StonePlanterSide",Vector3(side*(size.x*.5-.055),height*.5,0),Vector3(.11,height,size.y),"land_pot",physical)
		_b(street,root,"StonePlanterEnd",Vector3(0,height*.5,side*(size.y*.5-.055)),Vector3(size.x-.22,height,.11),"land_pot",physical)
	_b(street,root,"RecessedSoil",Vector3(0,height-.055,0),Vector3(size.x-.22,.05,size.y-.22),"land_soil")
	return root

static func _prototype(path: String,source_name: String) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null: return null
	var source := packed.instantiate() as Node3D
	if source == null: return null
	var selected: Node3D = source if source_name.is_empty() else _find_source(source,source_name)
	if selected == null:
		push_warning("Street landscape source missing: "+source_name)
		source.free()
		return null
	var transform := selected.transform
	var ancestor := selected.get_parent()
	while ancestor != null:
		if ancestor is Node3D: transform = ancestor.transform * transform
		if ancestor == source: break
		ancestor = ancestor.get_parent()
	var result := Node3D.new()
	_collect(selected,result,transform)
	source.free()
	var bounds := AABB()
	var first := true
	for child: MeshInstance3D in result.get_children():
		var box: AABB = child.transform * child.get_aabb()
		if source_name.contains("Bush006_leaves"):
			# Imported accessors may retain unused vertices/LODs. Normalize this
			# low crown from the triangles actually referenced by the chosen mesh.
			var first_vertex := true
			for surface: int in range(child.mesh.get_surface_count()):
				var arrays: Array = child.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var count := indices.size() if not indices.is_empty() else vertices.size()
				for i: int in range(count):
					var point: Vector3 = child.transform*vertices[indices[i] if not indices.is_empty() else i]
					box = AABB(point,Vector3.ZERO) if first_vertex else box.expand(point)
					first_vertex = false
		bounds = box if first else bounds.merge(box)
		first = false
	result.set_meta("source_bounds",bounds)
	return result

static func _find_source(root: Node,source_name: String) -> Node3D:
	# glTF import may sanitize dots/spaces; match the same identity as the park.
	var wanted := source_name.to_lower().replace(" ","").replace(".","").replace("_","").replace("-","")
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		var normalized := str(node.name).to_lower().replace(" ","").replace(".","").replace("_","").replace("-","")
		if node is Node3D and normalized == wanted: return node as Node3D
		pending.append_array(node.get_children())
	return null

static func _collect(source: Node,parent: Node3D,transform: Transform3D) -> void:
	if source is MeshInstance3D and source.mesh != null:
		var visual := MeshInstance3D.new()
		visual.name = str(source.name)
		visual.mesh = source.mesh
		visual.material_override = source.material_override
		for surface: int in range(source.mesh.get_surface_count()):
			visual.set_surface_override_material(surface,source.get_surface_override_material(surface))
		visual.transform = transform
		visual.visibility_range_end = 0.0
		FoliageMaterials.configure_mesh(visual)
		parent.add_child(visual)
	for child: Node in source.get_children():
		var next: Transform3D = transform * child.transform if child is Node3D else transform
		_collect(child,parent,next)

static func _instance(prototype: Node3D,parent: Node3D,pos: Vector3,height: float,yaw: float,capture_bounds: bool=false) -> AABB:
	if prototype == null: return AABB()
	pos = _soil_point(parent,pos)
	var instance := prototype.duplicate() as Node3D
	var bounds: AABB = prototype.get_meta("source_bounds")
	var factor := height/maxf(bounds.size.y,.001)
	var pivot := Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	var content := Node3D.new()
	content.name = "MeasuredPlant"
	content.position = pos
	content.rotation.y = yaw
	parent.add_child(content)
	instance.scale = Vector3.ONE * factor
	instance.position = -pivot * factor
	content.add_child(instance)
	var measured := AABB()
	var first := true
	if capture_bounds:
		# Count only referenced retained vertices after crown pruning, at the actual
		# placed transform. Root can expand its visual envelope without guessing.
		for visual: MeshInstance3D in instance.get_children():
			for surface: int in range(visual.mesh.get_surface_count()):
				var arrays: Array = visual.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var count := indices.size() if not indices.is_empty() else vertices.size()
				for i: int in range(count):
					var point: Vector3 = visual.global_transform*vertices[indices[i] if not indices.is_empty() else i]
					measured = AABB(point,Vector3.ZERO) if first else measured.expand(point)
					first = false
	return measured
