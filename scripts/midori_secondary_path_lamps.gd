extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")
const StartupTrace = preload("res://scripts/startup_trace.gd")
# Standalone staged module. All placement coordinates/distances are world metres.
@export var auto_install := true
@export_file("*.glb") var model_path := "res://assets/shinrai/parks/midori_park/models/secondary_path_lamps/midori_secondary_bollard.glb"
const HEIGHT := 1.15
const FOOTPRINT := Vector3(.36,1.15,.34)
const SPACING := 16.0
const MAX_LAMPS := 48
const EDGE_SETBACK := .80
const FULL_FOOTPRINT_RADIUS := .2476
const WALKER_RADIUS := .36
const CLEAR_MARGIN := .10
const SECONDARY_NAMES := ["PlaygroundWoodlandLoop","NorthWoodlandLoop","PavilionGardenLink"]
var park: Node3D
var terrain: Node
var routes: Array[Dictionary] = []
var all_routes: Array[Dictionary] = []
var placements: Array[Dictionary] = []
var rejected: Dictionary = {}
var installed := false
var night := false
var _poll := 0.0
var _prototype: PackedScene
var _lens: StandardMaterial3D
var _lights: Array[SpotLight3D] = []
var _excluded: Array[RID] = []
var _planting: Array[Rect2] = []
var _main_positions: Array[Vector2] = []

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	if auto_install:call_deferred("_install_when_ready")

func _install_when_ready() -> void:
	var target:=get_parent() as Node3D
	if target==null:
		push_error("Secondary lamps require a park Node3D parent");return
	while is_inside_tree() and not installed:
		var ground:=target.get_node_or_null("MidoriTerrain")
		var trails:=target.get_node_or_null("MidoriDesirePaths")
		var main_lamps:=target.get_node_or_null("MidoriJapanesePathLamps")
		if ground!=null and bool(ground.get("installed")) and (trails==null or bool(trails.get("finished"))) and (main_lamps==null or bool(main_lamps.get("installed"))):
			await install(target);return
		await get_tree().process_frame

func install(target:Node3D,route_override:Array[Dictionary]=[]) -> void:
	assert(not installed,"Secondary lamp module is installed once")
	park=target;terrain=park.get_node_or_null("MidoriTerrain")
	global_transform=Transform3D.IDENTITY
	if terrain==null or not bool(terrain.get("installed")):
		push_error("Secondary lamps require installed terrain");return
	var trails:=park.get_node_or_null("MidoriDesirePaths")
	if trails!=null and not bool(trails.get("finished")):
		push_error("Secondary lamps require finished desire paths");return
	await get_tree().physics_frame;await get_tree().physics_frame
	var _boot_tick := StartupTrace.begin()
	_load_model()
	_boot_tick = StartupTrace.finish("secondary_lamps.model",_boot_tick)
	_collect_routes()
	_boot_tick = StartupTrace.finish("secondary_lamps.routes",_boot_tick)
	_index_occupied_shoulders()
	_boot_tick = StartupTrace.finish("secondary_lamps.plant_index",_boot_tick)
	if not route_override.is_empty():
		routes=route_override.duplicate(true)
		all_routes.append_array(routes)
	for body:Node in park.find_children("*","CollisionObject3D",true,false):
		if body.is_in_group("midori_terrain_floor") or body.is_in_group("midori_trail_walk") or body.is_in_group("midori_terrain_paving") or body.is_in_group("midori_walk_surface"):
			_excluded.append(body.get_rid())
	_place_routes_fairly()
	_boot_tick = StartupTrace.finish("secondary_lamps.placement",_boot_tick)
	installed=true
	set_night_mode(bool(park.get("is_night_mode")))
	set_meta("secondary_lamp_report",report())
	print("SECONDARY_LAMPS_READY ",JSON.stringify(report()))

func _load_model() -> void:
	var path:String=model_path
	var doc:=GLTFDocument.new();var state:=GLTFState.new()
	assert(doc.append_from_file(path,state)==OK,"Bollard GLB must parse")
	var source:=doc.generate_scene(state)
	for mesh:MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		mesh.visibility_range_end=80.0;mesh.visibility_range_end_margin=8.0
		for surface:int in range(mesh.mesh.get_surface_count()):
			var mat:=mesh.get_active_material(surface)
			if mat is StandardMaterial3D and mat.resource_name=="RecessedWarmDiffuser":
				_lens=mat.duplicate();_lens.emission_enabled=true;_lens.emission=Color("#ffe5bd");_lens.emission_energy_multiplier=0.0
				mesh.set_surface_override_material(surface,_lens)
				mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_prototype=PackedScene.new();assert(_prototype.pack(source)==OK);source.free()
	assert(_lens!=null,"Measured asset must retain separate recessed diffuser")

func _collect_routes() -> void:
	for mesh:MeshInstance3D in park.find_children("*","MeshInstance3D",true,false):
		if mesh.has_meta("midori_path_centres_world") and mesh.has_meta("midori_path_width_m"):
			var points:PackedVector3Array=mesh.get_meta("midori_path_centres_world")
			var role:=str(mesh.get_meta("midori_path_role",""))
			var route:Dictionary={"name":str(mesh.name),"points":points,"half_width":float(mesh.get_meta("midori_path_width_m"))*.5,"source":"rendered path metadata"}
			if mesh.has_meta("midori_path_widths_world"):
				var full_widths:PackedFloat32Array=mesh.get_meta("midori_path_widths_world")
				if full_widths.size()==points.size():
					var half_widths:=PackedFloat32Array()
					for width:float in full_widths:half_widths.append(width*.5)
					route["widths"]=half_widths
			all_routes.append(route)
			if role=="secondary" or (role.is_empty() and str(mesh.name) in SECONDARY_NAMES):routes.append(route)
	var woodland:=park.get_node_or_null("VisibleWoodlandTrails")
	if woodland!=null:
		for mesh:MeshInstance3D in woodland.get_children():
			var route:=_trail_route(mesh)
			if not route.is_empty():routes.append(route);all_routes.append(route)

func _trail_route(mesh:MeshInstance3D) -> Dictionary:
	# UV.x stores actual rendered arc-length, UV.y the five cross-section fractions.
	# Group triangle duplicates by arc-length, not approximate route control points.
	var sections:Dictionary={}
	for surface:int in range(mesh.mesh.get_surface_count()):
		var arrays:=mesh.mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		if uvs.size()!=vertices.size():return {}
		for i:int in range(vertices.size()):
			var key:=roundi(uvs[i].x*10000)
			if not sections.has(key):sections[key]={}
			sections[key][roundi(uvs[i].y*4.0)]=mesh.global_transform*vertices[i]
	var keys:=sections.keys();keys.sort()
	var points:=PackedVector3Array();var widths:=PackedFloat32Array()
	for key:int in keys:
		var section:Dictionary=sections[key]
		if not section.has(0) or not section.has(2) or not section.has(4):continue
		points.append(section[2]);widths.append(maxf(Vector2(section[0].x-section[2].x,section[0].z-section[2].z).length(),Vector2(section[4].x-section[2].x,section[4].z-section[2].z).length()))
	if points.size()<2:return {}
	return {"name":str(mesh.name),"points":points,"widths":widths,"source":"actual VisibleWoodlandTrails cross-sections"}

func _sample(route:Dictionary,distance:float) -> Dictionary:
	var points:PackedVector3Array=route.points
	var travelled:=0.0
	for i:int in range(points.size()-1):
		var a:=Vector2(points[i].x,points[i].z);var b:=Vector2(points[i+1].x,points[i+1].z);var length:=a.distance_to(b)
		if length<.0001:continue
		if travelled+length>=distance:
			var t:=clampf((distance-travelled)/length,0,1)
			var width:float=route.get("half_width",.8)
			if route.has("widths"):width=lerpf(route.widths[i],route.widths[i+1],t)
			return {"p":a.lerp(b,t),"tangent":(b-a)/length,"half_width":width}
		travelled+=length
	return {}

func _index_occupied_shoulders() -> void:
	var main:=park.get_node_or_null("MidoriJapanesePathLamps")
	if main!=null:
		for item:Dictionary in main.get("placements"):
			var p:Vector3=item.position
			_main_positions.append(Vector2(p.x,p.z))
	for batch:MultiMeshInstance3D in park.find_children("*","MultiMeshInstance3D",true,false):
		var node:Node=batch
		var relevant:=false
		while node!=null and node!=park:
			if str(node.name) in ["WoodlandCompanionPockets","WoodlandDiversity","MidoriPlantedBeds","FullerWalkShoulders"]:relevant=true;break
			node=node.get_parent()
		if not relevant or batch.multimesh==null or batch.multimesh.mesh==null:continue
		var mm:=batch.multimesh
		for i:int in range(mm.instance_count):
			var box:AABB=(batch.global_transform*mm.get_instance_transform(i))*mm.mesh.get_aabb()
			if box.size.y<.12:continue
			_planting.append(Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(FULL_FOOTPRINT_RADIUS+.10))

func _route_distances(route:Dictionary) -> Array[float]:
	var points:PackedVector3Array=route.points
	if points.size()<2:return []
	var length:=0.0
	for i:int in range(points.size()-1):length+=Vector2(points[i].x-points[i+1].x,points[i].z-points[i+1].z).length()
	var distances:Array[float]=[]
	var distance:=4.0
	while distance<length-4.0:distances.append(distance);distance+=SPACING
	# Add meaningful bends only if separated from regular guides by at least8m.
	var travelled:=0.0
	for i:int in range(1,points.size()-1):
		travelled+=Vector2(points[i].x-points[i-1].x,points[i].z-points[i-1].z).length()
		var a:=Vector2(points[i].x-points[i-1].x,points[i].z-points[i-1].z).normalized()
		var b:=Vector2(points[i+1].x-points[i].x,points[i+1].z-points[i].z).normalized()
		if a.dot(b)>.866 or travelled<4.0 or travelled>length-4.0:continue
		var close:=false
		for d:float in distances:close=close or absf(d-travelled)<8.0
		if not close:distances.append(travelled)
	distances.sort()
	return distances

func _place_routes_fairly() -> void:
	var plans:Array[Dictionary]=[]
	var rounds:=0
	for route:Dictionary in routes:
		var distances:=_route_distances(route)
		plans.append({"route":route,"distances":distances})
		rounds=maxi(rounds,distances.size())
	# One opportunity per route per round; long early routes cannot consume the cap.
	for index:int in range(rounds):
		for plan:Dictionary in plans:
			if placements.size()>=MAX_LAMPS:return
			if index<plan.distances.size():_place_at(plan.route,plan.distances[index],index)

func _place_at(route:Dictionary,distance:float,index:int) -> void:
	var accepted:=false
	for shift:float in [0,2,-2]:
		if accepted:break
		var sample:=_sample(route,distance+shift)
		if sample.is_empty():continue
		for side:float in [1 if index%2==0 else -1,-1 if index%2==0 else 1]:
			if accepted:break
			for extra:float in [0,.25,.55]:
				var normal:=Vector2(-sample.tangent.y,sample.tangent.x)*side
				var p:Vector2=sample.p+normal*(sample.half_width+EDGE_SETBACK+extra)
				var reason:=_reject(p,route,sample.half_width,-normal)
				if not reason.is_empty():rejected[reason]=int(rejected.get(reason,0))+1;continue
				_add_lamp(p,-normal,str(route.name),sample.half_width,EDGE_SETBACK+extra)
				accepted=true;break

func _reject(p:Vector2,own:Dictionary,half_width:float,facing:=Vector2(0,1)) -> String:
	for main_position:Vector2 in _main_positions:
		if p.distance_to(main_position)<8.0:return "main_lamp_spacing"
	for bed:Rect2 in _planting:
		if bed.has_point(p):return "planting"
	if park.get("lake_contour")!=null:
		var contour:=PackedVector2Array()
		var scale_value:float=park.get("LAYOUT_SCALE")
		for point:Vector2 in park.get("lake_contour"):contour.append(point*scale_value)
		if Geometry2D.is_point_in_polygon(p,contour):return "water"
		for i:int in range(contour.size()):
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,contour[i],contour[(i+1)%contour.size()]))<2.0:return "shore"
	if park.get("occupied_tree_positions")!=null:
		var scale_value:float=park.get("LAYOUT_SCALE")
		for trunk:Vector2 in park.get("occupied_tree_positions"):
			if p.distance_to(trunk*scale_value)<1.4:return "tree"
	for placed:Dictionary in placements:
		if p.distance_to(Vector2(placed.position.x,placed.position.z))<8.0:return "spacing"
	for route:Dictionary in all_routes:
		var points:PackedVector3Array=route.points
		for i:int in range(points.size()-1):
			var w:float=maxf(route.widths[i],route.widths[i+1]) if route.has("widths") else float(route.get("half_width",1.4))
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,Vector2(points[i].x,points[i].z),Vector2(points[i+1].x,points[i+1].z)))<w+FULL_FOOTPRINT_RADIUS+WALKER_RADIUS+CLEAR_MARGIN:return "path_clearance"
	var heights:Array[float]=[]
	var yaw:=atan2(facing.x,facing.y)
	for corner:Vector2 in [Vector2(-.18,-.17),Vector2(.18,-.17),Vector2(-.18,.17),Vector2(.18,.17)]:
		var rotated:=Vector2(cos(yaw)*corner.x+sin(yaw)*corner.y,-sin(yaw)*corner.x+cos(yaw)*corner.y)
		heights.append(terrain.height_at(p+rotated))
	heights.append(terrain.height_at(p))
	if heights.max()-heights.min()>.025:return "slope"
	var y:float=terrain.height_at(p)
	var query:=PhysicsShapeQueryParameters3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.70,1.4,.70);query.shape=shape
	query.transform=Transform3D(Basis.IDENTITY,Vector3(p.x,y+.70,p.y));query.collision_mask=1;query.exclude=_excluded
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return "obstacle"
	var ray:=PhysicsRayQueryParameters3D.create(Vector3(p.x,y+2,p.y),Vector3(p.x,y-.2,p.y),1)
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or not (hit.collider as Node).is_in_group("midori_terrain_floor"):return "ground"
	if absf(hit.position.y-y)>.015:return "terrain_disagreement"
	return ""

func _add_lamp(p:Vector2,facing:Vector2,route_name:String,half_width:float,setback:float) -> void:
	var unit:=Node3D.new();unit.name="SecondaryBollard_%02d"%(placements.size()+1);add_child(unit)
	var ground_y:float=terrain.height_at(p)
	unit.position=Vector3(p.x,ground_y-.008,p.y);unit.rotation.y=atan2(facing.x,facing.y)
	var visual:=_prototype.instantiate() as Node3D;visual.name="MeasuredBollard";unit.add_child(visual)
	var body:=StaticBody3D.new();body.name="BollardCollision";unit.add_child(body)
	var collider:=CollisionShape3D.new();collider.name="MeasuredBollardShape";var box:=BoxShape3D.new();box.size=FOOTPRINT;collider.shape=box;collider.position.y=HEIGHT*.5;body.add_child(collider)
	var light:=SpotLight3D.new();light.name="ShieldedWarmDownlight";unit.add_child(light)
	# Outside the post (Z<=.07), beneath the panel (Z<=.09), before cutoff lip.
	light.position=Vector3(0,.795,.085);light.light_color=Color("#ffe5bd");light.light_energy=.8;light.spot_range=3.8;light.spot_angle=55;light.spot_angle_attenuation=1.7;light.shadow_enabled=true
	light.distance_fade_enabled=true;light.distance_fade_begin=22;light.distance_fade_length=10
	light.look_at(unit.to_global(Vector3(0,.01,1.1)),Vector3.UP);_lights.append(light)
	placements.append({"name":str(unit.name),"route":route_name,"position":unit.position,"height_m":HEIGHT,"path_half_width_m":half_width,"edge_setback_m":setback,"ground_y":ground_y,"foundation_embed_m":.008,"yaw":unit.rotation.y})

func set_night_mode(enabled:bool) -> void:
	night=enabled
	if _lens!=null:_lens.emission_energy_multiplier=.65 if night else 0.0
	for light:SpotLight3D in _lights:light.visible=night

func _process(delta:float) -> void:
	if not installed:return
	_poll+=delta
	if _poll<.25:return
	_poll=0
	var value:=bool(park.get("is_night_mode"))
	if value!=night:set_night_mode(value)

func report() -> Dictionary:
	var route_counts:Dictionary={}
	for route:Dictionary in routes:route_counts[str(route.name)]=0
	for placement:Dictionary in placements:route_counts[placement.route]=int(route_counts.get(placement.route,0))+1
	return {"lamps":placements.size(),"route_count":routes.size(),"route_counts":route_counts,"height_m":HEIGHT,"spacing_target_m":SPACING,"max_lamps":MAX_LAMPS,"world_identity":global_transform.is_equal_approx(Transform3D.IDENTITY),"rejected":rejected,"placements":placements,"visual_acceptance":"pending installed review of fairness and unblocked night beam"}

