extends Node
# Cleared woodland corridors with visible, terrain-following worn earth.
# All coordinates and widths here are world metres, independent of park scale.
# Trail centre lines stay 3.25m from the actual paving footprint. This
# includes room for their 0.825m shoulders and rounded grid corners.
const PAVING_CLEARANCE := 3.25
const LoadingBudget := preload("res://scripts/shinrai_loading_budget.gd")
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
	# Time-based cap, not 600 frames: budgeted loading splits work into many more frames.
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if park.has_meta("woodland_diversity") and (terrain == null or terrain.installed): break
		await get_tree().process_frame
	if not park.has_meta("woodland_diversity") or (terrain != null and not terrain.installed):
		finished = true
		push_error("DESIRE_PATHS: planting/terrain did not finish")
		return
	if installed: return
	# Everything waiting on the terrain wakes in one frame: take a budget turn first.
	await LoadingBudget.checkpoint(park)
	if installed: return
	var _dt := preload("res://scripts/startup_trace.gd").begin()
	# Same work in the same order; the shared loading budget only splits frames.
	await _index_scene()
	await LoadingBudget.checkpoint(park)
	_index_obstacles()
	_dt = preload("res://scripts/startup_trace.gd").finish("desire.index_scene", _dt)
	for link: Dictionary in LINKS:
		await LoadingBudget.checkpoint(park)
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
	_dt = preload("res://scripts/startup_trace.gd").finish("desire.routes", _dt)
	var removed := 0
	var before := 0
	for batch: MultiMeshInstance3D in park.find_children("*","MultiMeshInstance3D",true,false):
		await LoadingBudget.checkpoint(park)
		if not is_instance_valid(batch): continue
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
		if not _may_touch_routes(batch, mm): continue
		var batch_transform := batch.global_transform
		# The batch's float32 buffer, read once. Per-instance reads (get_instance_transform)
		# make the renderer keep a CPU copy of the whole buffer for the MultiMesh's life
		# and the trimmed copy, built per instance, kept another; the rows are the same
		# floats, so the decisions and the kept rows below are bit-identical.
		var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
		var buffer: PackedFloat32Array = mm.buffer if mm.transform_format == MultiMesh.TRANSFORM_3D else PackedFloat32Array()
		var packed := buffer.size() == stride * mm.instance_count and _buffer_rows_verified()
		for i in range(mm.instance_count):
			var t := batch_transform*(_row_transform(buffer, i*stride) if packed else mm.get_instance_transform(i))
			var p3 := t*anchor
			var p := Vector2(p3.x,p3.z)
			# No segment in this cell (distance_to_path is INF) and far from the
			# picnic point: d > 3 m, beyond the widest cut (2.36 m). Kept.
			if not route_cells.has(Vector2i(floori(p.x/4),floori(p.y/4))) and p.distance_to(Vector2(-20,154)) > 5.5:
				kept.append(i)
				continue
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
		if packed and kept.size() > 0:
			# Whole rows (transform, colour, custom data) copied as they are, assigned once.
			var rows := PackedFloat32Array()
			rows.resize(kept.size() * stride)
			for j in range(kept.size()):
				var from := kept[j] * stride
				var to := j * stride
				for k in range(stride): rows[to + k] = buffer[from + k]
			trimmed.buffer = rows
		else:
			for j in range(kept.size()):
				trimmed.set_instance_transform(j,mm.get_instance_transform(kept[j]))
				if mm.use_colors: trimmed.set_instance_color(j,mm.get_instance_color(kept[j]))
				if mm.use_custom_data: trimmed.set_instance_custom_data(j,mm.get_instance_custom_data(kept[j]))
		batch.multimesh = trimmed
	_dt = preload("res://scripts/startup_trace.gd").finish("desire.trim_grass", _dt)
	# The shoulders' pure candidate sweep runs on a worker during the picnic stop
	# and trail surface below; its install takes the result (same order, same RNG).
	var shoulders = load(get_script().resource_path.get_base_dir()+"/midori_path_shoulders.gd").new()
	shoulders.start_scan(park)
	var picnic = load(get_script().resource_path.get_base_dir()+"/midori_path_picnic.gd").new()
	picnic.name = "WoodlandPicnicStop"
	park.add_child(picnic)
	picnic.install(park,routes)
	await load(get_script().resource_path.get_base_dir()+"/midori_trail_surface.gd").new().install(park,terrain,routes)
	await shoulders.install(park,terrain,self)
	_dt = preload("res://scripts/startup_trace.gd").finish("desire.surface_shoulders", _dt)
	installed = true
	finished = true
	park.set_meta("desire_paths",{"routes":routes.size(),"removed_lod_instances":removed,"original_lod_instances":before,"retained_fraction":1.0-float(removed)/maxi(before,1)})
	print("DESIRE_PATHS_READY ",JSON.stringify(park.get_meta("desire_paths")))

## The trim tests each instance at t * anchor, inside the MultiMesh's world AABB.
## An instance is only removed when its own 4 m route cell holds a segment
## (distance_to_path is INF elsewhere) or it is within 2.5 + 2.36 m of the
## picnic point (edge <= .86, radius <= 1.15, fringe .35). A batch whose grown
## bounds reach neither keeps every instance, as the full walk would decide.
## Unknown bounds (custom AABB, or a renderer that does not compute them) walk.
func _may_touch_routes(batch: MultiMeshInstance3D, mm: MultiMesh) -> bool:
	if mm.custom_aabb != AABB(): return true
	var local := mm.get_aabb()
	if local.size == Vector3.ZERO: return true
	var box: AABB = (batch.global_transform*local).grow(1.0)
	var flat := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
	if flat.grow(6.0).has_point(Vector2(-20,154)): return true
	for z in range(floori(box.position.z/4),floori(box.end.z/4)+1):
		for x in range(floori(box.position.x/4),floori(box.end.x/4)+1):
			if route_cells.has(Vector2i(x,z)): return true
	return false

## One instance's Transform3D from its float32 buffer row (TRANSFORM_3D: the three
## basis rows with the origin component as each row's fourth float), the same
## floats get_instance_transform returns.
static func _row_transform(buffer: PackedFloat32Array, o: int) -> Transform3D:
	return Transform3D(Basis(Vector3(buffer[o], buffer[o + 4], buffer[o + 8]), Vector3(buffer[o + 1], buffer[o + 5], buffer[o + 9]), Vector3(buffer[o + 2], buffer[o + 6], buffer[o + 10])), Vector3(buffer[o + 3], buffer[o + 7], buffer[o + 11]))

## Checked once per run on a throwaway one-instance MultiMesh: a row written as
## a buffer (the way the trimmed batch is written) reads back as the instance
## transform _row_transform builds from it. The probe has no mesh, so it never
## reaches the renderer's AABB rebuild (which would log an error for a mesh-less
## MultiMesh when an instance is set one at a time). False (every batch takes
## the per-instance path, as before) under a renderer that does not expose the
## buffer this way, such as the headless dummy renderer.
static var _rows_checked := false
static var _rows_ok := false
static func _buffer_rows_verified() -> bool:
	if _rows_checked: return _rows_ok
	_rows_checked = true
	var probe := MultiMesh.new()
	probe.transform_format = MultiMesh.TRANSFORM_3D
	probe.instance_count = 1
	var rows := PackedFloat32Array([1.5, 2.5, 3.5, 10.5, 4.5, 5.5, 6.5, 11.5, 7.5, 8.5, 9.5, 12.5])
	probe.buffer = rows
	var t := Transform3D(Basis(Vector3(1.5, 4.5, 7.5), Vector3(2.5, 5.5, 8.5), Vector3(3.5, 6.5, 9.5)), Vector3(10.5, 11.5, 12.5))
	_rows_ok = probe.get_instance_transform(0) == t and _row_transform(rows, 0) == t and probe.buffer == rows
	return _rows_ok

## End-of-boot hook (shinrai_world_complete.gd): the route-finding scratch data
## is dead once the trails, shoulders, picnic stop and worn paths are installed.
## route_cells and routes stay (distance_to_path: biomes, lamps, flowers);
## obstacle_hit (shoulders, boot only) answers false afterwards.
## paving_cells (the largest script table of the boot) goes too: its readers are
## _route, which only install() calls, and the ground texture's landscape-mask
## job. It is rebound, never cleared, so a job that took the table keeps its own
## reference; and it stays while that job has not finished, in case it has not
## taken the table yet. paving_distance answers INF afterwards.
func release_build_data() -> Dictionary:
	if not finished: return {"skipped": "not finished"}
	var freed := {"density": density.size(), "obstacles": obstacles.size(), "obstacle_cells": _obstacle_grid.size(), "paving_blocked": paving_blocked.size(), "debug_bounds": _debug_bounds_cache.size()}
	density = {}
	obstacles = []
	_obstacle_grid = {}
	paving_blocked = {}
	_debug_bounds_cache = {}
	if _ground_mask_pending():
		freed["paving_cells_kept"] = "ground mask not finished"
	else:
		freed["paving_cells"] = paving_cells.size()
		paving_cells = {}
	return freed

## True while the ground texture autoload still owes its landscape mask. It
## builds that mask once per process (its install never repeats), so "ready"
## means no job will read paving_cells again; without the autoload nothing does.
func _ground_mask_pending() -> bool:
	var ground := get_tree().root.get_node_or_null("MidoriGroundTexture")
	return ground != null and ground.get("landscape_ready") != true

## Same answer as testing every obstacle rect (any-hit), from the 4 m obstacle
## grid: a rect grown by `radius` that contains p has a point within `radius`
## of p on each axis, and that point's cell is one the rect is indexed in.
func obstacle_hit(p: Vector2, radius: float) -> bool:
	var reach := radius + 1.0
	for z in range(floori((p.y-reach)/OBSTACLE_CELL_M),floori((p.y+reach)/OBSTACLE_CELL_M)+1):
		for x in range(floori((p.x-reach)/OBSTACLE_CELL_M),floori((p.x+reach)/OBSTACLE_CELL_M)+1):
			for rect: Rect2 in _obstacle_grid.get(Vector2i(x,z),[]):
				if rect.grow(radius).has_point(p): return true
	return false

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
		await LoadingBudget.checkpoint(park)
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
		var batch_transform := batch.global_transform
		for i in range(0,mm.instance_count,4):
			var p: Vector3 = batch_transform*mm.get_instance_transform(i).origin
			var key := Vector2i(floori(p.x/2),floori(p.z/2))
			density[key]=int(density.get(key,0))+1
	for shape: CollisionShape3D in park.find_children("*","CollisionShape3D",true,false):
		if shape.disabled or shape.shape==null or not shape.get_parent() is StaticBody3D: continue
		if terrain != null and terrain.is_ancestor_of(shape): continue
		if shape.get_parent().name == "ParkGround_220x180m": continue
		var box: AABB = shape.global_transform*_debug_bounds(shape.shape)
		if box.size.y < .4 or box.position.y > 3.5: continue
		obstacles.append(Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(1.65))

## shape.get_debug_mesh().get_aabb(), without building a debug mesh for every
## Shape3D resource (that build was most of this index's cost):
## - BoxShape3D: the mesh is the box's edges, corners at +-size/2, so its AABB is
##   AABB(-size/2, size) exactly (checked equal for every box in the park).
## - Sphere, capsule, cylinder: a pure function of the shape's parameters, asked
##   once per parameter set.
## - Convex and concave shapes: a pure function of their point / face array,
##   asked once per distinct array (hashed, then compared with ==, so a hit is
##   always the same data and so the same AABB).
## Anything else (or a scripted shape) asks its own debug mesh, as before.
var _debug_bounds_cache: Dictionary = {}
func _debug_bounds(shape: Shape3D) -> AABB:
	if shape.get_script() != null: return shape.get_debug_mesh().get_aabb()
	if shape is BoxShape3D: return AABB(-shape.size*.5, shape.size)
	if shape is ConvexPolygonShape3D or shape is ConcavePolygonShape3D:
		var data: PackedVector3Array = shape.points if shape is ConvexPolygonShape3D else shape.get_faces()
		var content_key := [shape.get_class(), shape.get("debug_fill"), data.size(), hash(data)]
		var entries: Array = _debug_bounds_cache.get(content_key, [])
		for entry: Array in entries:
			if entry[0] == data: return entry[1]
		var measured: AABB = shape.get_debug_mesh().get_aabb()
		entries.append([data, measured])
		_debug_bounds_cache[content_key] = entries
		return measured
	if not (shape is SphereShape3D or shape is CapsuleShape3D or shape is CylinderShape3D):
		return shape.get_debug_mesh().get_aabb()
	var key := [shape.get_class(), shape.get("size"), shape.get("radius"), shape.get("height"), shape.get("debug_fill")]
	if not _debug_bounds_cache.has(key): _debug_bounds_cache[key] = shape.get_debug_mesh().get_aabb()
	return _debug_bounds_cache[key]

## Obstacle rectangles bucketed by cell, so each route cell only tests the
## few obstacles that can contain it (identical results to testing them all).
const OBSTACLE_CELL_M := 4.0
var _obstacle_grid: Dictionary = {}

func _index_obstacles() -> void:
	_obstacle_grid.clear()
	for rect: Rect2 in obstacles:
		for z in range(floori(rect.position.y/OBSTACLE_CELL_M),floori(rect.end.y/OBSTACLE_CELL_M)+1):
			for x in range(floori(rect.position.x/OBSTACLE_CELL_M),floori(rect.end.x/OBSTACLE_CELL_M)+1):
				var key:=Vector2i(x,z)
				if not _obstacle_grid.has(key): _obstacle_grid[key]=[]
				_obstacle_grid[key].append(rect)

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
			if not blocked:
				for rect: Rect2 in _obstacle_grid.get(Vector2i(floori(p.x/OBSTACLE_CELL_M),floori(p.y/OBSTACLE_CELL_M)),[]):
					if rect.has_point(p):
						blocked=true
						break
			if terrain != null and terrain.water_at(p): blocked=true
			if not blocked and park.any_trunk_within(p,2.5): blocked=true
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
