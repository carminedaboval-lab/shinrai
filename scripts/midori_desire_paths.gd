extends Node
# Cleared woodland corridors with visible, terrain-following worn earth.
# All coordinates and widths here are world metres, independent of park scale.
# Trail centre lines stay 3.25m from the actual paving footprint. This
# includes room for their 0.825m shoulders and rounded grid corners.
const PAVING_CLEARANCE := 3.25
const LINKS := [
	{"name":"Map and picnic stop", "a":Vector2(-49,119), "b":Vector2(-23,151)},
	{"name":"Playground woodland lookout", "a":Vector2(-111,81), "b":Vector2(-100,108)},
	{"name":"Clubhouse woodland lookout", "a":Vector2(-164,-28), "b":Vector2(-124,-36)},
	{"name":"Wooded rise garden", "a":Vector2(-25,30), "b":Vector2(0,29)},
	{"name":"Northern iris pocket", "a":Vector2(31,-126), "b":Vector2(27,-106)},
]
var routes: Array[Dictionary] = []
var installed := false
var finished := false
var park: Node3D
var terrain: Node
var density: Dictionary = {}
var obstacles: Array[Rect2] = []
var route_cells: Dictionary = {}
var paving_cells: Dictionary = {}
var paving_blocked: Dictionary = {}

func _ready() -> void:
	call_deferred("install")

func install() -> void:
	park = get_parent()
	terrain = park.get_node_or_null("MidoriTerrain")
	for frame in range(600):
		if park.has_meta("woodland_diversity") and (terrain == null or terrain.installed): break
		await get_tree().process_frame
	if not park.has_meta("woodland_diversity") or (terrain != null and not terrain.installed):
		finished = true
		push_error("DESIRE_PATHS: planting/terrain did not finish")
		return
	if installed: return
	_index_scene()
	for link: Dictionary in LINKS:
		var points := _route(link.a,link.b)
		if points.is_empty():
			push_error("DESIRE_PATHS: no clear route for "+link.name)
			continue
		routes.append({"name":link.name,"points":points,"destination":link.b})
		for i in range(points.size()-1):
			var p: Vector2=points[i]
			var segment:=PackedVector2Array([p,points[i+1]])
			var cell := Vector2i(floori(p.x/4),floori(p.y/4))
			for z in range(-1,2):
				for x in range(-1,2):
					var key := cell+Vector2i(x,z)
					if not route_cells.has(key): route_cells[key]=[]
					route_cells[key].append(segment)
	var removed := 0
	var before := 0
	for batch: MultiMeshInstance3D in park.find_children("*","MultiMeshInstance3D",true,false):
		var label := String(batch.name)
		var grass := label.begins_with("JapaneseForestGrass") or label.begins_with("ForestGrassLOD") or label.begins_with("WoodlandFillLOD") or label.contains("UprightGrass")
		var companion := String(batch.get_parent().name) in ["WoodlandCompanionPockets","WoodlandDiversity"]
		if not grass and not companion: continue
		var mm := batch.multimesh
		if mm == null: continue
		var kept: Array[int] = []
		var box := mm.mesh.get_aabb()
		var anchor := Vector3(box.get_center().x,box.position.y,box.get_center().z)
		before += mm.instance_count
		for i in range(mm.instance_count):
			var t := batch.global_transform*mm.get_instance_transform(i)
			var p3 := t*anchor
			var p := Vector2(p3.x,p3.z)
			var footprint := t.basis.x.abs()*box.size.x+t.basis.y.abs()*box.size.y+t.basis.z.abs()*box.size.z
			var radius := minf(1.15,maxf(absf(footprint.x),absf(footprint.z))*.5)
			var d := minf(distance_to_path(p),maxf(0.0,p.distance_to(Vector2(-20,154))-2.5))
			var edge := .72 + .08*sin(p.x*.43+p.y*.27) + .06*cos(p.y*.62)
			# Keep the centre readable, then break up the shoulders deterministically.
			var fringe := .5+.5*sin(p.x*12.9898+p.y*78.233)
			if d < edge+radius or (d < edge+radius+.35 and fringe > (d-edge-radius)/.35):
				removed += 1
			else: kept.append(i)
		if kept.size() == mm.instance_count: continue
		var trimmed := MultiMesh.new()
		trimmed.transform_format = mm.transform_format
		trimmed.use_colors = mm.use_colors
		trimmed.use_custom_data = mm.use_custom_data
		trimmed.mesh = mm.mesh
		trimmed.instance_count = kept.size()
		for j in range(kept.size()):
			trimmed.set_instance_transform(j,mm.get_instance_transform(kept[j]))
			if mm.use_colors: trimmed.set_instance_color(j,mm.get_instance_color(kept[j]))
			if mm.use_custom_data: trimmed.set_instance_custom_data(j,mm.get_instance_custom_data(kept[j]))
		batch.multimesh = trimmed
	var picnic = load(get_script().resource_path.get_base_dir()+"/midori_path_picnic.gd").new()
	picnic.name = "WoodlandPicnicStop"
	park.add_child(picnic)
	picnic.install(park,routes)
	await load(get_script().resource_path.get_base_dir()+"/midori_trail_surface.gd").new().install(park,terrain,routes)
	await load(get_script().resource_path.get_base_dir()+"/midori_path_shoulders.gd").new().install(park,terrain,self)
	installed = true
	finished = true
	park.set_meta("desire_paths",{"routes":routes.size(),"removed_lod_instances":removed,"original_lod_instances":before,"retained_fraction":1.0-float(removed)/maxi(before,1)})
	print("DESIRE_PATHS_READY ",JSON.stringify(park.get_meta("desire_paths")))

func distance_to_path(p: Vector2) -> float:
	var cell := Vector2i(floori(p.x/4),floori(p.y/4))
	var result := INF
	for segment: PackedVector2Array in route_cells.get(cell,[]):
		result=minf(result,p.distance_to(Geometry2D.get_closest_point_to_segment(p,segment[0],segment[1])))
	return result

func _index_scene() -> void:
	# Use the installed rounded mesh, rather than its approximate authoring
	# centre line. Keep the same separation from visible and physical paving.
	for body in get_tree().get_nodes_in_group("midori_terrain_paving"):
		for shape in body.get_children():
			if not shape is CollisionShape3D or not shape.shape is ConcavePolygonShape3D: continue
			var faces: PackedVector3Array = shape.shape.get_faces()
			for i in range(0,faces.size(),3):
				var tri := PackedVector2Array()
				for j in range(3):
					var v: Vector3 = shape.global_transform*faces[i+j]
					tri.append(Vector2(v.x,v.z))
				if absf((tri[1]-tri[0]).cross(tri[2]-tri[0])) < .00001: continue
				var low: Vector2 = tri[0].min(tri[1]).min(tri[2])-Vector2.ONE*PAVING_CLEARANCE
				var high: Vector2 = tri[0].max(tri[1]).max(tri[2])+Vector2.ONE*PAVING_CLEARANCE
				for z in range(floori(low.y/4),floori(high.y/4)+1):
					for x in range(floori(low.x/4),floori(high.x/4)+1):
						var key := Vector2i(x,z)
						if not paving_cells.has(key): paving_cells[key]=[]
						paving_cells[key].append(tri)
	# Density guides the routes toward existing gaps, not straight cuts through beds.
	for batch: MultiMeshInstance3D in park.find_children("WoodlandFillLOD0_*","MultiMeshInstance3D",true,false):
		var mm := batch.multimesh
		for i in range(0,mm.instance_count,4):
			var p: Vector3 = batch.global_transform*mm.get_instance_transform(i).origin
			var key := Vector2i(floori(p.x/2),floori(p.z/2))
			density[key]=int(density.get(key,0))+1
	for shape: CollisionShape3D in park.find_children("*","CollisionShape3D",true,false):
		if shape.disabled or shape.shape==null or not shape.get_parent() is StaticBody3D: continue
		if terrain != null and terrain.is_ancestor_of(shape): continue
		if shape.get_parent().name == "ParkGround_220x180m": continue
		var box: AABB = shape.global_transform*shape.shape.get_debug_mesh().get_aabb()
		if box.size.y < .4 or box.position.y > 3.5: continue
		obstacles.append(Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(1.65))

func _route(a: Vector2,b: Vector2) -> PackedVector2Array:
	var grid := AStarGrid2D.new()
	var low := a.min(b)-Vector2(24,24)
	var high := a.max(b)+Vector2(24,24)
	grid.region=Rect2i(Vector2i(low),Vector2i(high-low)+Vector2i.ONE)
	grid.cell_size=Vector2.ONE
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for z in range(grid.region.position.y,grid.region.end.y):
		for x in range(grid.region.position.x,grid.region.end.x):
			var id := Vector2i(x,z)
			var p := Vector2(id)
			var blocked := _near_paving(p)
			for rect in obstacles:
				if rect.has_point(p):
					blocked=true
					break
			if terrain != null and terrain.water_at(p): blocked=true
			for trunk: Vector2 in park.occupied_tree_positions:
				if p.distance_squared_to(trunk*2)<6.25:
					blocked=true
					break
			grid.set_point_solid(id,blocked)
			var weight := 1.0+.20*int(density.get(Vector2i(floori(p.x/2),floori(p.y/2)),0))
			grid.set_point_weight_scale(id,weight)
	# Detached discovery points and destination approaches must both be clear.
	var start:=_free_endpoint(grid,Vector2i(a))
	var finish:=_free_endpoint(grid,Vector2i(b))
	if start==Vector2i(99999,99999) or finish==Vector2i(99999,99999):return PackedVector2Array()
	return grid.get_point_path(start,finish)



func _free_endpoint(grid:AStarGrid2D,p:Vector2i)->Vector2i:
	if grid.region.has_point(p) and not grid.is_point_solid(p):return p
	var result:=Vector2i(99999,99999)
	var best:=INF
	for z in range(-5,6):
		for x in range(-5,6):
			var q:=p+Vector2i(x,z)
			if not grid.region.has_point(q) or grid.is_point_solid(q):continue
			var score:float=Vector2(x,z).length_squared()+grid.get_point_weight_scale(q)*.2
			if score<best:best=score;result=q
	return result


func _near_paving(p: Vector2) -> bool:
	var id := Vector2i(p)
	if paving_blocked.has(id): return paving_blocked[id]
	var blocked := paving_distance(p) < PAVING_CLEARANCE
	paving_blocked[id] = blocked
	return blocked

func paving_distance(p: Vector2) -> float:
	var result := INF
	for tri: PackedVector2Array in paving_cells.get(Vector2i(floori(p.x/4),floori(p.y/4)),[]):
		if Geometry2D.is_point_in_polygon(p,tri): return 0.0
		for j in range(3):
			result=minf(result,p.distance_to(Geometry2D.get_closest_point_to_segment(p,tri[j],tri[(j+1)%3])))
	return result
