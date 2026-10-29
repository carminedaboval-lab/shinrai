extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")
const StartupTrace = preload("res://scripts/startup_trace.gd")
# Metric Meshy lanterns beside the real rounded paving, never along hidden trails.
const MODEL := "res://assets/shinrai/parks/midori_park/models/main_path_lamp/japanese_path_lamp_2800.glb"
const SPACING := 16.0
const WARM_WHITE := Color("#ffe0b5")
const ROUTES := [
	["SOUTH_ARRIVAL_ROUTE",4.0], ["WEST_DESTINATION_ROUTE",4.0],
	["NORTH_ENTRY_ROUTE",3.8], ["EAST_DECK_ROUTE",3.8],
	["PLAZA_PAVED_ROUTE",4.0], ["SPORTS_LINK_ROUTE",3.0],
	["LAKE_PROMENADE_LOOP",3.6], ["OUTER_CIRCUIT",3.8],
	["SOUTH_BRIDGE_APPROACH",3.2], ["PAVILION_LINK_ROUTE",2.8],
	["VIEWING_DECK_APPROACH_ROUTE",3.0],
]
var installed := false
var park: Node3D
var terrain: Node
var desire: Node
var routes: Array[Dictionary] = []
var placements: Array[Dictionary] = []
var lights: Array[Light3D] = []
var material: ShaderMaterial
var obstacle_cells: Dictionary = {}
var skipped := 0
var _night := false

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	call_deferred("install")

func install() -> void:
	if installed: return
	park = get_parent()
	terrain = park.get_node("MidoriTerrain")
	while not terrain.installed: await get_tree().process_frame
	while park.get_node_or_null("MidoriDesirePaths")==null: await get_tree().process_frame
	desire = park.get_node("MidoriDesirePaths")
	while not desire.finished: await get_tree().process_frame
	var stone := park.get_node_or_null("MidoriStoneLanterns")
	while stone!=null and not stone.installed: await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	set_as_top_level(true)
	global_transform = Transform3D.IDENTITY
	var _boot_tick := StartupTrace.begin()
	_build_routes()
	_boot_tick = StartupTrace.finish("lamps.routes",_boot_tick)
	_index_planting()
	_boot_tick = StartupTrace.finish("lamps.plant_index",_boot_tick)
	var source := load(MODEL) as PackedScene
	assert(source!=null,"Approved Meshy path lamp missing")
	for route: Dictionary in routes:
		var distance := 5.0
		var serial := 0
		while distance<route.length-2.0:
			var sample := _sample(route,distance)
			var placement := _find_position(route,distance,serial)
			if not placement.is_empty(): _add_lamp(source,placement,route.name)
			elif not _near_existing(sample.p,10.0): skipped+=1
			distance+=SPACING
			serial+=1
	_boot_tick = StartupTrace.finish("lamps.placement",_boot_tick)
	_trim_base_grass()
	_boot_tick = StartupTrace.finish("lamps.trim_grass",_boot_tick)
	set_night_mode(bool(park.is_night_mode))
	installed = true
	print("JAPANESE_PATH_LAMPS_READY ",JSON.stringify({"count":placements.size(),"skipped":skipped,"world_scale":global_basis.get_scale(),"spacing_m":SPACING,"color":"warm white 3000K direction"}))

func _build_routes() -> void:
	# New path passes publish their actual rendered centreline and metre width.
	# Never infer widened edges from the legacy layout-space constants.
	var names := {"OuterWalkingCircuit":"OUTER_CIRCUIT","SouthEntranceToLake":"SOUTH_ARRIVAL_ROUTE","SouthEntranceToPlaza":"PLAZA_PAVED_ROUTE","WestEntranceToBridgeLanding":"WEST_DESTINATION_ROUTE","NorthEntranceToLake":"NORTH_ENTRY_ROUTE","EastEntranceToBridgeLanding":"EAST_DECK_ROUTE","SportsConnector":"SPORTS_LINK_ROUTE","ContinuousLakePromenade":"LAKE_PROMENADE_LOOP","PlazaToSouthBridgeLanding":"SOUTH_BRIDGE_APPROACH","PavilionGardenLink":"PAVILION_LINK_ROUTE","EastPromenadeToViewingDeck":"VIEWING_DECK_APPROACH_ROUTE"}
	for walk: MeshInstance3D in park.find_children("*","MeshInstance3D",true,false):
		if not walk.has_meta("midori_path_centres_world") or not walk.has_meta("midori_path_width_m"): continue
		var role := str(walk.get_meta("midori_path_role","main"))
		var name_key := str(walk.name)
		if role in ["secondary","woodland","trail","desire"] and name_key!="ContinuousLakePromenade": continue
		if not names.has(name_key): continue
		var points := PackedVector2Array()
		for point: Variant in walk.get_meta("midori_path_centres_world"):
			if point is Vector3: points.append(Vector2(point.x,point.z))
			elif point is Vector2: points.append(point)
		if points.size()<2: continue
		var length := 0.0
		for i: int in range(points.size()-1): length+=points[i].distance_to(points[i+1])
		var widths: PackedFloat32Array = walk.get_meta("midori_path_widths_world",PackedFloat32Array())
		if widths.size()!=points.size():
			widths.resize(points.size())
			widths.fill(float(walk.get_meta("midori_path_width_m")))
		routes.append({"name":names[name_key],"points":points,"widths":widths,"half_width":float(walk.get_meta("midori_path_width_m"))*.5,"length":length})
	if not routes.is_empty(): return
	# The paving generator uses this same rounded curve and width conversion.
	for spec: Array in ROUTES:
		var anchors: Array[Vector2] = park.get(spec[0]).duplicate()
		var closed := anchors[0].is_equal_approx(anchors[-1])
		if not closed:
			while anchors.size()>2 and anchors[-2].distance_to(anchors[-1])<3.0: anchors.remove_at(anchors.size()-2)
		var curve: Array[Vector2] = park._rounded_contour(anchors,closed,4.0)
		var points := PackedVector2Array()
		var length := 0.0
		for p: Vector2 in curve: points.append(p*park.LAYOUT_SCALE)
		for i: int in range(points.size()-1): length+=points[i].distance_to(points[i+1])
		var width_factor := .55 if spec[0]=="LAKE_PROMENADE_LOOP" else .46
		routes.append({"name":spec[0],"points":points,"half_width":float(spec[1])*width_factor*park.LAYOUT_SCALE*.5,"length":length})

func _sample(route: Dictionary, distance: float) -> Dictionary:
	var points: PackedVector2Array = route.points
	for i: int in range(points.size()-1):
		var length := points[i].distance_to(points[i+1])
		if distance<=length and length>.0001:
			var half: float = route.half_width
			if route.has("widths"): half=lerpf(route.widths[i],route.widths[i+1],distance/length)*.5
			return {"p":points[i].lerp(points[i+1],distance/length),"tangent":(points[i+1]-points[i])/length,"half_width":half}
		distance-=length
	return {"p":points[-1],"tangent":(points[-1]-points[-2]).normalized(),"half_width":float(route.widths[-1])*.5 if route.has("widths") else float(route.half_width)}

func paving_edge_distance(p: Vector2) -> float:
	if park.has_method("path_edge_distance_world"): return float(park.path_edge_distance_world(p))
	var distance := INF
	for route: Dictionary in routes:
		var points: PackedVector2Array = route.points
		for i: int in range(points.size()-1):
			var q := Geometry2D.get_closest_point_to_segment(p,points[i],points[i+1])
			var half: float = route.half_width
			if route.has("widths"):
				var t := points[i].distance_to(q)/maxf(.001,points[i].distance_to(points[i+1]))
				half=lerpf(route.widths[i],route.widths[i+1],t)*.5
			distance=minf(distance,p.distance_to(q)-half)
	return distance

func _near_existing(p: Vector2,radius: float) -> bool:
	for prior: Dictionary in placements:
		if p.distance_to(Vector2(prior.position.x,prior.position.z))<radius: return true
	return false

func _find_position(route: Dictionary,distance: float,serial: int) -> Dictionary:
	for shift: float in [0.0,2.0,-2.0,4.0,-4.0,6.0,-6.0]:
		var sample := _sample(route,clampf(distance+shift,1.0,route.length-1.0))
		var normal := Vector2(-sample.tangent.y,sample.tangent.x)
		for side: float in [1.0 if serial%2==0 else -1.0,-1.0 if serial%2==0 else 1.0]:
			for setback: float in [.65,.95,1.25]:
				var p: Vector2 = sample.p+normal*side*(float(sample.half_width)+setback)
				if _near_existing(p,10.0): continue
				var fit := _clear(p,sample.p)
				if not fit.is_empty():
					return {"p":p,"path":sample.p,"base_y":fit.base_y,"spread":fit.spread,"edge_clearance":paving_edge_distance(p)}
	return {}

func _clear(p: Vector2,path: Vector2) -> Dictionary:
	if absf(p.x)>216.0 or absf(p.y)>176.0: return {}
	# Reserve the existing neon/halo monument composition.
	if p.distance_to(park.PLAZA_CENTER*park.LAYOUT_SCALE)<19.0: return {}
	if terrain.water_at(p) or terrain.edge_distance(p,terrain.shoreline)<.8: return {}
	if paving_edge_distance(p)<.42: return {}
	if desire.distance_to_path(p)<1.5: return {}
	for trunk: Vector2 in park.occupied_tree_positions:
		if p.distance_to(trunk*park.LAYOUT_SCALE)<1.15: return {}
	var gardens := park.get_node_or_null("MidoriGardenSpots")
	if gardens!=null:
		for footprint: Dictionary in gardens.footprints:
			if p.distance_to(footprint.p)<float(footprint.radius)+.35: return {}
	for walk: Dictionary in park._bridge_walk_surfaces:
		if walk.kind!="landing": continue
		var polygon: PackedVector2Array = walk.spec.footprint
		if Geometry2D.is_point_in_polygon(p,polygon) or terrain.edge_distance(p,polygon)<.6: return {}
	var cell := Vector2i(floori(p.x/4.0),floori(p.y/4.0))
	for rect: Rect2 in obstacle_cells.get(cell,[]):
		if rect.has_point(p): return {}
	var low: float = terrain.height_at(p)
	var high := low
	for i: int in range(8):
		var q := p+Vector2(.22,0).rotated(i*TAU/8.0)
		if terrain.water_at(q): return {}
		var y: float = terrain.height_at(q)
		low=minf(low,y)
		high=maxf(high,y)
	if high-low>.025: return {}
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.48,2.65,.48)
	query.shape=box
	query.transform=Transform3D(Basis.IDENTITY,Vector3(p.x,high+1.42,p.y))
	query.collision_mask=1
	var player := park.get_node_or_null("ParkScaleReviewPlayer")
	if player is CollisionObject3D: query.exclude=[player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return {}
	# Keep the light-to-walk link clear of solid props, not merely the pole socket.
	var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x,high+2.02,p.y),Vector3(path.x,high+.25,path.y),1)
	if player is CollisionObject3D: ray.exclude=[player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return {}
	return {"base_y":low-.004,"spread":high-low}

func _index_planting() -> void:
	for batch: MultiMeshInstance3D in park.find_children("*","MultiMeshInstance3D",true,false):
		var node: Node = batch
		var relevant := false
		while node!=null and node!=park:
			if String(node.name) in ["WoodlandCompanionPockets","WoodlandDiversity","MidoriPlantedBeds","FullerWalkShoulders"]: relevant=true;break
			node=node.get_parent()
		if not relevant or batch.multimesh==null or batch.multimesh.mesh==null: continue
		var mm := batch.multimesh
		for i: int in range(mm.instance_count):
			var box: AABB = (batch.global_transform*mm.get_instance_transform(i))*mm.mesh.get_aabb()
			if box.size.y<.12: continue
			var rect := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(.25)
			# _clear only queries candidates within +/-216 x +/-176 metres.
			# Some source foliage bounds extend kilometres outside the park;
			# indexing unqueryable cells would allocate billions of entries.
			for z: int in range(maxi(-44,floori(rect.position.y/4.0)),mini(44,floori(rect.end.y/4.0))+1):
				for x: int in range(maxi(-54,floori(rect.position.x/4.0)),mini(54,floori(rect.end.x/4.0))+1):
					var cell := Vector2i(x,z)
					if not obstacle_cells.has(cell): obstacle_cells[cell]=[]
					obstacle_cells[cell].append(rect)

func _add_lamp(source: PackedScene,fit: Dictionary,route_name: String) -> void:
	var lamp := Node3D.new()
	lamp.name="JapanesePathLamp_%03d" % (placements.size()+1)
	add_child(lamp)
	lamp.position=Vector3(fit.p.x,fit.base_y,fit.p.y)
	var toward: Vector2 = fit.path-fit.p
	lamp.rotation.y=atan2(toward.x,toward.y)
	var model := source.instantiate() as Node3D
	model.name="MeasuredMeshyLamp"
	lamp.add_child(model)
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if material==null: material=_make_material(mesh.get_active_material(0))
		mesh.material_override=material
	var body := StaticBody3D.new()
	body.name="LampCollision"
	body.collision_layer=1
	body.collision_mask=1
	lamp.add_child(body)
	for part: Array in [[Vector3(0,.17,0),Vector3(.346,.34,.346)],[Vector3(0,1.13,0),Vector3(.158,1.58,.158)],[Vector3(0,2.2,0),Vector3(.332,.56,.332)],[Vector3(0,2.575,0),Vector3(.59,.19,.59)],[Vector3(0,2.735,0),Vector3(.215,.13,.215)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size=part[1]
		shape.shape=box
		shape.position=part[0]
		body.add_child(shape)
	var spill := SpotLight3D.new()
	spill.name="WarmWhitePathPool"
	lamp.add_child(spill)
	spill.position=Vector3(0,1.90,.17)
	spill.light_color=WARM_WHITE
	spill.light_energy=2.2
	spill.spot_range=14.0
	spill.spot_angle=77.0
	spill.spot_attenuation=.8
	spill.light_size=.14
	spill.shadow_enabled=true
	spill.light_volumetric_fog_energy=1.1
	spill.look_at(Vector3(fit.path.x,fit.base_y+.12,fit.path.y),Vector3.FORWARD)
	spill.add_to_group("midori_night_effect")
	lights.append(spill)
	var glow := OmniLight3D.new()
	glow.name="WarmWhiteLanternGlow"
	lamp.add_child(glow)
	glow.position=Vector3(0,2.3,0)
	glow.light_color=WARM_WHITE
	glow.light_energy=.22
	glow.omni_range=2.8
	glow.shadow_enabled=false
	glow.light_volumetric_fog_energy=2.4
	glow.add_to_group("midori_night_effect")
	lights.append(glow)
	placements.append({"name":lamp.name,"route":route_name,"position":lamp.position,"path":fit.path,"edge_clearance_m":fit.edge_clearance,"ground_spread_m":fit.spread})

func _make_material(source: StandardMaterial3D) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code="""
shader_type spatial;
uniform sampler2D base_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_map : filter_linear_mipmap, repeat_enable;
uniform float night_strength = 0.0;
varying float metric_height;
void vertex(){metric_height=VERTEX.y;}
void fragment(){
    vec3 base=texture(base_map,UV).rgb;
    vec3 orm=texture(orm_map,UV).rgb;
    ALBEDO=base;
    METALLIC=orm.b;
    ROUGHNESS=clamp(orm.g,.22,.95);
    NORMAL_MAP=texture(normal_map,UV).rgb;
    float panel_height=smoothstep(2.025,2.05,metric_height)*(1.0-smoothstep(2.52,2.55,metric_height));
    float opal=smoothstep(.52,.78,min(base.r,min(base.g,base.b)));
    // Paper grain modulates the diffuser; ground spill remains unchanged.
    EMISSION=vec3(1.0,.72,.38)*panel_height*opal*night_strength*.42*mix(.58,1.0,dot(base,vec3(.333333)));
}
"""
	var result := ShaderMaterial.new()
	result.shader=shader
	result.set_shader_parameter("base_map",source.albedo_texture)
	result.set_shader_parameter("normal_map",source.normal_texture)
	result.set_shader_parameter("orm_map",source.roughness_texture)
	return result

func _trim_base_grass() -> void:
	# Only individual grass roots inside the metal foot are removed; shrubs remain.
	var lamp_cells := _lamp_footprint_index()
	for batch: MultiMeshInstance3D in park.find_children("*","MultiMeshInstance3D",true,false):
		var label := String(batch.name)
		if not (label.begins_with("JapaneseForestGrass") or label.begins_with("ForestGrassLOD") or label.begins_with("WoodlandFillLOD") or label.contains("UprightGrass")): continue
		var mm := batch.multimesh
		if mm==null or mm.mesh==null: continue
		var bounds := mm.mesh.get_aabb()
		var anchor := Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
		var world_transform := batch.global_transform
		for i: int in range(mm.instance_count):
			var transform := mm.get_instance_transform(i)
			var world: Vector3 = world_transform*transform*anchor
			var cell := Vector2i(floori(world.x/4.0),floori(world.z/4.0))
			for lamp: Dictionary in lamp_cells.get(cell,[]):
				if Vector2(world.x-lamp.position.x,world.z-lamp.position.z).length()<.23:
					transform.basis=Basis.from_scale(Vector3.ZERO)
					mm.set_instance_transform(i,transform)
					break

func _lamp_footprint_index() -> Dictionary:
	var cells: Dictionary={}
	for lamp: Dictionary in placements:
		var p: Vector3=lamp.position
		# Conservative candidate bounds; keep the original strict .23 m test above.
		for z in range(floori((p.z-.231)/4.0),floori((p.z+.231)/4.0)+1):
			for x in range(floori((p.x-.231)/4.0),floori((p.x+.231)/4.0)+1):
				var key:=Vector2i(x,z)
				if not cells.has(key): cells[key]=[]
				cells[key].append(lamp)
	return cells

func set_night_mode(enabled: bool) -> void:
	_night=enabled
	if material!=null: material.set_shader_parameter("night_strength",1.0 if enabled else 0.0)
	for light: Light3D in lights: light.visible=enabled

func _process(_delta: float) -> void:
	if installed and bool(park.is_night_mode)!=_night: set_night_mode(bool(park.is_night_mode))

