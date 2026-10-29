extends Node3D
## Additive, measured civic wayfinding and fitted canopy luminaires.
## All coordinates are world metres; original Meshy assets are never modified.
const Budget = preload("res://scripts/shinrai_loading_budget.gd")
const TOTEM_PATH := "res://assets/shinrai/parks/midori_park/models/identity2050/midori_2050_totem.glb"
const ART_ROOT := "res://assets/shinrai/signage/civic2050/"
const CANOPIES := ["PlazaEntranceRestGarden", "PlazaEastRestGarden", "PlazaWestRestGarden"]
const SIGN_SPECS := [
	{"id":"east", "point":Vector2(211.5,-34), "yaw_degrees":108.434949},
	{"id":"north", "point":Vector2(-49,-168), "yaw_degrees":-119.744881},
	{"id":"sports", "point":Vector2(-120,-43), "yaw_degrees":0.0},
]
var installed := false
var park: Node3D
var terrain: Node
var path_lamps: Node
var identity: Node3D
var report: Dictionary = {"signs":[], "canopies":[], "lights":[], "rejections":[], "global_environment_changed":false, "source_assets_preserved":true, "new_light_count":0, "night":false}
var _materials: Dictionary = {}
var _emissive: Array[Dictionary] = []
var _lights: Array[Dictionary] = []
var _floor_placements: Array = []
var _night := false
var _clock := 0.0

func _ready() -> void:
	park = get_parent() as Node3D
	await Budget.wait_structure(park)
	for node_name: String in ["MidoriTerrain", "MidoriJapanesePathLamps", "MidoriSecondaryPathLamps", "Midori2050Identity", "MidoriSouthStreet"]:
		var producer: Node = park.get_node_or_null(NodePath(node_name))
		if producer == null:
			report.rejections.append({"id":node_name,"reason":"required producer unavailable"})
			_finish()
			return
		while producer.get("installed") != true:
			await get_tree().process_frame
	# Floor planting is optional in older scene variants, but if present its
	# final footprints must exist before we choose a clear new sign shoulder.
	var floor_detail: Node = park.get_node_or_null("MidoriParkFloor")
	if floor_detail != null:
		while floor_detail.get("installed") != true: await get_tree().process_frame
		_floor_placements = floor_detail.get("audit")
	terrain = park.get_node("MidoriTerrain")
	path_lamps = park.get_node("MidoriJapanesePathLamps")
	identity = park.get_node("Midori2050Identity") as Node3D
	set_as_top_level(true)
	global_transform = Transform3D.IDENTITY
	_make_materials()
	await get_tree().physics_frame
	await get_tree().physics_frame
	for canopy_name: String in CANOPIES:
		_fit_canopy(canopy_name)
		await Budget.checkpoint(park)
	_south_companion()
	for spec: Dictionary in SIGN_SPECS:
		_install_sign(spec)
		await Budget.checkpoint(park)
	_finish()

func _finish() -> void:
	_night = park.get("is_night_mode") == true
	_sync_lighting()
	report.new_light_count = _lights.size()
	installed = true
	set_meta("civic_lighting_report", report)
	park.set_meta("civic_lighting_report", report)
	print("MIDORI_CIVIC_LIGHTING_READY ", JSON.stringify(report))

func _process(delta: float) -> void:
	if not installed or not is_instance_valid(park): return
	_clock += delta
	if _clock < .25: return
	_clock = 0.0
	var value: bool = park.get("is_night_mode") == true
	if value != _night:
		_night = value
		_sync_lighting()

func _sync_lighting() -> void:
	for row: Dictionary in _emissive:
		var material: StandardMaterial3D = row.material
		material.emission_energy_multiplier = float(row.night) if _night else float(row.day)
	for row: Dictionary in _lights:
		var light: Light3D = row.light
		if is_instance_valid(light): light.light_energy = float(row.night) if _night else 0.0
	report.night = _night
	report.rib_emission_energy = 1.5 if _night else .12
	report.warm_lens_emission_energy = 1.2 if _night else .0

func _make_materials() -> void:
	for row: Array in [["metal", Color("#263c39"), .38, .65], ["trim", Color("#7b9489"), .32, .65], ["jade", Color("#b2eddb"), .26, .12], ["warm", Color("#ffe3b7"), .35, .0], ["dark", Color("#0f2423"), .52, .15]]:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = row[1]
		material.roughness = float(row[2])
		material.metallic = float(row[3])
		_materials[row[0]] = material
	for key: String in ["jade", "warm"]:
		var material: StandardMaterial3D = _materials[key]
		material.emission_enabled = true
		material.emission = Color("#64d8b3") if key == "jade" else material.albedo_color
		_emissive.append({"material":material,"night":1.5 if key == "jade" else 1.2,"day":.12 if key == "jade" else .0})

func _fit_canopy(id: String) -> void:
	var host: Node3D = identity.get_node_or_null(NodePath(id)) as Node3D
	if host == null:
		report.rejections.append({"id":id,"reason":"canopy host missing"})
		return
	var source: MeshInstance3D = host.find_child("MidoriCanopySmoothGlass", true, false) as MeshInstance3D
	var source_frame: MeshInstance3D = host.find_child("MidoriCanopyCleanFrame", true, false) as MeshInstance3D
	if source == null or source.mesh == null or source_frame == null or source_frame.mesh == null:
		report.rejections.append({"id":id,"reason":"fitted canopy surface missing"})
		return
	var root: Node3D = Node3D.new()
	root.name = "CivicFittedLightRibs"
	host.add_child(root)
	root.transform = host.global_transform.affine_inverse() * source.global_transform
	root.set_meta("creator_protected", true)
	var surface: Array = source.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = surface[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = surface[Mesh.ARRAY_INDEX]
	var frame_surface: Array = source_frame.mesh.surface_get_arrays(0)
	var frame_vertices: PackedVector3Array = frame_surface[Mesh.ARRAY_VERTEX]
	var frame_indices: PackedInt32Array = frame_surface[Mesh.ARRAY_INDEX] if frame_surface[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var bounds: AABB = source.mesh.get_aabb()
	var count: int = 0
	var rib_count: int = 0
	var fit_error: float = 0.0
	var fit_comparisons: int = 0
	# Follow the two real transverse steel spars. Their bottom sits 182mm below
	# the glass. A 55mm channel meets that bottom. Its continuous 26mm optical
	# lens sits flush below the housing, remaining readable at normal distance.
	for z: float in [-.85, .80]:
		var points: PackedVector3Array = PackedVector3Array()
		for i: int in range(81):
			var x: float = lerpf(bounds.position.x + .25, bounds.end.x - .25, float(i) / 80.0)
			var sample: Dictionary = _height_on_mesh(Vector2(x,z), vertices, indices)
			if sample.is_empty(): continue
			# Keep the luminaire ends 180mm back from the curved roof perimeter.
			if _height_on_mesh(Vector2(x-.18,z), vertices, indices).is_empty() or _height_on_mesh(Vector2(x+.18,z), vertices, indices).is_empty(): continue
			points.append(Vector3(x,float(sample.y)-.210,z))
			# Independently compare our attachment plane against the actual steel
			# mesh underside; barycentric XZ reconstruction alone proves nothing.
			if i % 16 == 0:
				var steel: Dictionary = _height_on_mesh(Vector2(x,z),frame_vertices,frame_indices,true)
				if not steel.is_empty():
					fit_error = maxf(fit_error,absf((float(sample.y)-.182)-float(steel.y)))
					fit_comparisons += 1
		if points.size() < 3: continue
		_ribbon(root,"AluminiumChannel%02d" % rib_count,points,.066,.055,_materials.metal)
		var lens_points: PackedVector3Array = PackedVector3Array()
		for point: Vector3 in points: lens_points.append(point-Vector3(0,.042,0))
		_ribbon(root,"JadeDiffuser%02d" % rib_count,lens_points,.045,.026,_materials.jade)
		for endpoint: Vector3 in [points[0], points[-1]]:
			_box(root,"SealedEndCap",endpoint,Vector3(.045,.065,.070),_materials.trim)
		for i: int in range(4,points.size()-3,16):
			_box(root,"ChannelSaddle",points[i]+Vector3(0,.014,0),Vector3(.055,.028,.078),_materials.trim)
		count += points.size()
		rib_count += 1
	# The existing upper omni is retained but disabled; replace its diffuse wash
	# with one downlight fixed to the central spar. Existing seat lights remain.
	var old_light: OmniLight3D
	# Repeated original names can become @OmniLight3D@... on add_child. Match
	# by native type and actual host-local height, not the first readable name.
	for candidate: Node in host.find_children("*", "OmniLight3D", true, false):
		var omni: OmniLight3D = candidate as OmniLight3D
		if host.to_local(omni.global_position).y > 2.0:
			old_light = omni
			break
	var spot_path: String = ""
	var centre: Dictionary = _height_on_mesh(Vector2(0,.8),vertices,indices)
	if not centre.is_empty() and rib_count > 0:
		var light_point: Vector3 = Vector3(0,float(centre.y)-.295,.8)
		_box(root,"DownlightSparBracket",light_point+Vector3(0,.065,0),Vector3(.15,.13,.13),_materials.metal)
		_cylinder(root,"RecessedDownlightHousing",light_point,.093,.072,_materials.metal)
		_cylinder(root,"WarmOpticalLens",light_point-Vector3(0,.039,0),.073,.008,_materials.warm)
		var spot: SpotLight3D = SpotLight3D.new()
		spot.name = "WarmCanopyDownlight"
		root.add_child(spot)
		spot.position = light_point-Vector3(0,.044,0)
		spot.rotation_degrees.x = -90.0
		spot.light_color = Color("#ffdfb5")
		spot.light_energy = .95
		spot.spot_range = 4.6
		spot.spot_angle = 66.0
		spot.spot_attenuation = 1.25
		spot.spot_angle_attenuation = 1.2
		spot.shadow_enabled = false
		spot.light_volumetric_fog_energy = 0.0
		spot.distance_fade_enabled = true
		spot.distance_fade_begin = 32.0
		spot.distance_fade_length = 12.0
		_lights.append({"light":spot,"night":.95})
		spot_path = str(spot.get_path())
		report.lights.append({"id":id,"node":spot_path,"position":spot.global_position,"kind":"shielded warm downlight","night_energy":.95,"day_energy":.0,"range_m":4.6,"shadow":false})
		if old_light != null:
			old_light.set_meta("civic_previous_energy",old_light.light_energy)
			old_light.light_energy = 0.0
	root.set_meta("civic_canopy_fit",{"source":str(source.get_path()),"samples":count,"max_error_m":fit_error,"rib_count":rib_count})
	report.canopies.append({"id":id,"node":str(root.get_path()),"source_mesh_path":str(source.get_path()),"source_frame_path":str(source_frame.get_path()),"rib_count":rib_count,"sampled_points":count,"fit_max_error_m":fit_error,"fit_comparisons":fit_comparisons,"fit_definition":"actual glass-minus-182mm vs actual steel underside","source_bounds":bounds,"light_node":spot_path,"retained_original_light_node":str(old_light.get_path()) if old_light != null else "","source_transform_preserved":true})

func _height_on_mesh(point: Vector2, vertices: PackedVector3Array, indices: PackedInt32Array, lowest: bool = false) -> Dictionary:
	var total: int = indices.size() if not indices.is_empty() else vertices.size()
	var lowest_sample: Dictionary = {}
	for i: int in range(0,total-2,3):
		var a: Vector3 = vertices[indices[i] if not indices.is_empty() else i]
		var b: Vector3 = vertices[indices[i+1] if not indices.is_empty() else i+1]
		var c: Vector3 = vertices[indices[i+2] if not indices.is_empty() else i+2]
		var av: Vector2 = Vector2(a.x,a.z)
		var bv: Vector2 = Vector2(b.x,b.z)
		var cv: Vector2 = Vector2(c.x,c.z)
		var divisor: float = (bv-av).cross(cv-av)
		if absf(divisor) < .000001: continue
		var u: float = (point-av).cross(cv-av)/divisor
		var v: float = (bv-av).cross(point-av)/divisor
		if u < -.00001 or v < -.00001 or u+v > 1.00001: continue
		var fitted: Vector3 = a*(1.0-u-v)+b*u+c*v
		var result: Dictionary = {"y":fitted.y,"error":Vector2(fitted.x,fitted.z).distance_to(point)}
		if not lowest: return result
		if lowest_sample.is_empty() or fitted.y < float(lowest_sample.y): lowest_sample = result
	return lowest_sample

func _south_companion() -> void:
	var host: Node3D = identity.get_node_or_null("SouthGateWayfinding") as Node3D
	if host == null:
		report.rejections.append({"id":"south","reason":"existing map totem missing"})
		return
	var face: Vector3 = host.to_global(Vector3(.78,1.065,.098))
	var margin: float = _path_margin(Vector2(face.x,face.z))-.40
	if margin < .35:
		report.rejections.append({"id":"south","reason":"companion wing path clearance","path_margin_m":margin})
		return
	var root: Node3D = Node3D.new()
	root.name = "CivicSouthDirectionalWing"
	host.add_child(root)
	root.set_meta("creator_protected",true)
	# Twin structural arms fasten the lightweight display to the existing post.
	for y: float in [.68,1.45]:
		_box(root,"TwinPostBracket",Vector3(.48,y,-.025),Vector3(.62,.065,.09),_materials.metal)
		_cylinder(root,"BracketFastener",Vector3(.30,y+.037,-.025),.017,.009,_materials.trim)
	_box(root,"DisplayHousing",Vector3(.78,1.065,.058),Vector3(.61,1.24,.11),_materials.metal)
	_box(root,"RaisedHeaderLens",Vector3(.78,1.70,.119),Vector3(.49,.028,.014),_materials.jade)
	_add_face(root,"south",Vector3(.78,1.065,.119))
	_collision(root,Vector3(.78,1.065,.058),Vector3(.61,1.24,.11))
	report.signs.append({"id":"south","node":str(root.get_path()),"position":root.global_position,"face_position":face,"yaw":host.global_rotation.y,"texture":ART_ROOT+"south.svg","path_margin_m":margin,"tree_margin_m":-1.0,"ground_spread_m":0.0,"face_normal_world":host.global_basis.z.normalized(),"width_m":.61,"height_m":1.24,"depth_m":.11,"mounted_to_existing_map":true,"existing_map_preserved":true})

func _install_sign(spec: Dictionary) -> void:
	var id: String = spec.id
	var fit: Dictionary = _find_sign_fit(spec)
	if fit.is_empty():
		report.rejections.append({"id":id,"reason":"no clear grounded junction shoulder found","candidate":spec.point})
		return
	var packed: PackedScene = load(TOTEM_PATH) as PackedScene
	if packed == null:
		report.rejections.append({"id":id,"reason":"existing Meshy source unavailable"})
		return
	var root: Node3D = Node3D.new()
	root.name = "CivicWayfinding_"+id.capitalize()
	add_child(root)
	root.position = Vector3(fit.point.x,fit.ground_y,fit.point.y)
	# Artwork arrows were checked against this orientation. Search translations
	# do not rotate the panel and silently change its route semantics.
	root.rotation.y = deg_to_rad(float(spec.yaw_degrees))
	root.set_meta("creator_editable",true)
	root.set_meta("creator_display_name",id.capitalize()+" Gate Wayfinding")
	root.set_meta("creator_object_kind","sign")
	var model: Node3D = packed.instantiate() as Node3D
	model.name = "MeasuredMeshyTotem"
	root.add_child(model)
	var panel: MeshInstance3D = model.find_child("MidoriEInkPanel",true,false) as MeshInstance3D
	if panel != null: panel.hide()
	_add_face(root,id,Vector3(0,1.065,.098))
	_box(root,"RecessedCivicHeader",Vector3(0,1.735,.10),Vector3(.52,.031,.020),_materials.jade)
	_box(root,"LowerStatusBar",Vector3(0,.448,.101),Vector3(.42,.020,.017),_materials.jade)
	# A sunken shoe closes small terrain variation without floating base corners.
	_box(root,"CastBaseShoe",Vector3(0,-.015,0),Vector3(.79,.16,.30),_materials.metal)
	_collision(root,Vector3(0,1.05,0),Vector3(.74,2.10,.18))
	root.set_meta("civic_sign_id",id)
	var approach: Vector3 = root.to_global(Vector3(0,0,5.0))
	report.signs.append({"id":id,"node":str(root.get_path()),"position":root.global_position,"face_position":root.to_global(Vector3(0,1.065,.098)),"approach":Vector2(approach.x,approach.z),"yaw":root.rotation.y,"texture":ART_ROOT+id+".svg","path_margin_m":fit.path_margin_m,"tree_margin_m":fit.tree_margin_m,"ground_spread_m":fit.ground_spread_m,"face_normal_world":root.global_basis.z.normalized(),"width_m":.74,"height_m":2.10,"depth_m":.18,"source_asset":TOTEM_PATH,"mounted_to_existing_map":false})

func _find_sign_fit(spec: Dictionary) -> Dictionary:
	var origin: Vector2 = spec.point
	var angle: float = deg_to_rad(float(spec.yaw_degrees))
	var direction: Vector2 = Vector2(sin(angle),cos(angle))
	var along: Vector2 = Vector2(-direction.y,direction.x)
	for shift: float in [.0,-.75,.75,-1.5,1.5,-2.25,2.25]:
		for setback: float in [.0,.45,.9]:
			var point: Vector2 = origin+along*shift-direction*setback
			var fit: Dictionary = _clear_sign(point)
			if not fit.is_empty(): return fit
	return {}

func _clear_sign(point: Vector2) -> Dictionary:
	var margin: float = _path_margin(point)-.44
	if margin < .40 or margin > 4.5: return {}
	if bool(terrain.call("water_at",point)): return {}
	var tree_margin: float = 1000.0
	for trunk: Vector2 in park.get("occupied_tree_positions"):
		tree_margin = minf(tree_margin,point.distance_to(trunk*2.0)-.8)
	if tree_margin < .65: return {}
	# Existing shrub footprints and the just-finished floor pass have no solid
	# collider. Explicitly keep new signs out of their substantial foliage.
	var cell: Vector2i = Vector2i(floori(point.x/4.0),floori(point.y/4.0))
	var planting_cells: Dictionary = path_lamps.get("obstacle_cells")
	for rect: Rect2 in planting_cells.get(cell,[]):
		if rect.grow(.44).has_point(point): return {}
	for planted: Dictionary in _floor_placements:
		if float(planted.get("height",0.0)) < .30: continue
		if point.distance_to(planted.p) < float(planted.get("radius",.0))+.56: return {}
	var low: float = float(terrain.call("height_at",point))
	var high: float = low
	for offset: Vector2 in [Vector2(-.40,-.18),Vector2(.40,-.18),Vector2(-.40,.18),Vector2(.40,.18)]:
		var sample: Vector2 = point+offset
		if bool(terrain.call("water_at",sample)): return {}
		var y: float = float(terrain.call("height_at",sample))
		low = minf(low,y)
		high = maxf(high,y)
	if high-low > .075: return {}
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(.90,2.15,.90)
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY,Vector3(point.x,high+1.14,point.y))
	query.collision_mask = 1
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return {}
	return {"point":point,"ground_y":high-.005,"ground_spread_m":high-low,"path_margin_m":margin,"tree_margin_m":tree_margin}

func _path_margin(point: Vector2) -> float:
	return float(path_lamps.call("paving_edge_distance",point))

func _add_face(parent: Node3D,id: String,point: Vector3) -> void:
	var path: String = ART_ROOT+id+".svg"
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		report.rejections.append({"id":id,"reason":"directional artwork unavailable","path":path})
		return
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = Color(.83,.91,.87)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = .65
	var panel: MeshInstance3D = MeshInstance3D.new()
	panel.name = "ReadableDirectionalFace"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(.52,1.13)
	panel.mesh = quad
	panel.material_override = material
	panel.position = point
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(panel)

func _collision(parent: Node3D,point: Vector3,size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "CivicSignCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	parent.add_child(body)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = point
	body.add_child(shape)

func _box(parent: Node3D,id: String,point: Vector3,size: Vector3,material: Material) -> MeshInstance3D:
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = id
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	visual.mesh = box
	visual.material_override = material
	visual.position = point
	parent.add_child(visual)
	return visual

func _cylinder(parent: Node3D,id: String,point: Vector3,radius: float,height: float,material: Material) -> void:
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = id
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 24
	visual.mesh = cylinder
	visual.material_override = material
	visual.position = point
	parent.add_child(visual)

func _ribbon(parent: Node3D,id: String,points: PackedVector3Array,width: float,depth: float,material: Material) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(points.size()-1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i+1]
		var tangent: Vector3 = (b-a).normalized()
		var across: Vector3 = tangent.cross(Vector3.UP).normalized()
		var up: Vector3 = across.cross(tangent).normalized()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(a.distance_to(b)+.002,depth,width)
		surface.append_from(box,0,Transform3D(Basis(tangent,up,across),(a+b)*.5))
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = id
	visual.mesh = surface.commit()
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.visibility_range_end = 145.0
	visual.visibility_range_end_margin = 12.0
	parent.add_child(visual)
