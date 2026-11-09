extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")
const StartupTrace = preload("res://scripts/startup_trace.gd")

# World-space terrain: rendered triangles and collision share the same vertices.
const WATER_Y := 0.102
const STEP := 2.0
const NX := 221
const NZ := 181
const ORIGIN := Vector2(-220,-180)
var auto_install := true
var installed := false
var heights := PackedFloat32Array()
var shoreline := PackedVector2Array()
var islands: Array[Dictionary] = []
var paths: Array[PackedVector2Array] = []
var park: Node3D
var moved_roots := 0
var moved_instances := 0
var draped_walks := 0
var protected_landings: Array[PackedVector2Array] = []
var landing_bounds: Array[Rect2] = []

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	add_to_group("midori_terrain")
	if auto_install: call_deferred("install")

func install() -> void:
	var _boot_tick := StartupTrace.begin()
	park = get_parent()
	# The height grid only reads the finished park structure (lake, routes, bridge
	# landings, islands), not the planting the waits below are for. It is pure
	# math, so it runs on a worker while those services finish. Its inputs are
	# gathered again at the original point; the worker's grid is used only when
	# they are identical (else the grid is computed here, as before).
	var early := _height_inputs()
	early["heights"] = PackedFloat32Array()
	early["queued_usec"] = Time.get_ticks_usec()
	# High priority: every producer waits for the terrain, and low-priority pool
	# work (near-city mips and shells) otherwise queued ahead of it for ~8 s.
	_height_task = WorkerThreadPool.add_task(_compute_heights.bind(early), true, "MidoriTerrain height grid")
	# Let the supplied planting/groundcover services finish on the original datum.
	for frame in range(16): await get_tree().process_frame
	# Incremental planting can span more than sixteen frames; its datum must precede draping.
	if park.get_meta("shinrai_incremental_loading",false):
		while not park.has_meta("woodland_diversity"):
			await get_tree().process_frame
	_boot_tick = StartupTrace.finish("terrain.wait_services",_boot_tick)
	await LoadingBudget.checkpoint(park)
	var inputs := _height_inputs()
	shoreline = inputs.shoreline
	paths = inputs.paths
	protected_landings = inputs.protected_landings
	landing_bounds = inputs.landing_bounds
	islands = inputs.islands
	while not WorkerThreadPool.is_task_completed(_height_task): await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(_height_task)
	_height_task = -1
	if StartupTrace.enabled and early.has("worker_finished_usec"):
		print("TERRAIN_HEIGHT_WORKER queued_ms=%d ran_ms=%d done_at_s=%.1f" % [(int(early.worker_started_usec) - int(early.queued_usec)) / 1000, (int(early.worker_finished_usec) - int(early.worker_started_usec)) / 1000, float(early.worker_finished_usec) / 1000000.0])
	var early_heights: PackedFloat32Array = early.heights
	var tile_arrays: Array = []
	if early_heights.size() == NX * NZ and early.shoreline == inputs.shoreline and early.landing_bounds == inputs.landing_bounds and early.islands == inputs.islands and int(early.path_edges) == int(inputs.path_edges):
		heights = early_heights
		# The worker also built the tile arrays from these same heights.
		tile_arrays = early.get("tiles", [])
	else:
		push_warning("MIDORI_TERRAIN: height inputs changed during the planting wait; height grid recomputed")
		heights.resize(NX * NZ)
		for z in range(NZ):
			await LoadingBudget.checkpoint(park)
			for x in range(NX): heights[z*NX+x] = raw_height(ORIGIN + Vector2(x,z)*STEP)
	_boot_tick = StartupTrace.finish("terrain.height_grid",_boot_tick)
	var ground: StaticBody3D = park.find_child("ParkGround_220x180m",true,false)
	var material: Material
	for child in ground.get_children():
		await _turn()
		if child is MeshInstance3D: material = child.material_override
	# Keep the old material resource so the day/night service keeps updating it.
	var soil := _soil_material()
	await _build_tiles(material, soil, tile_arrays)
	_boot_tick = StartupTrace.finish("terrain.mesh_collision",_boot_tick)
	ground.collision_layer = 0
	ground.hide()
	var shadow_budget:=park.get_node_or_null("MidoriNearPlantShadows")
	if shadow_budget!=null and shadow_budget.has_method("before_source_change"):shadow_budget.before_source_change()
	# Group roots retain supplied model hierarchies; batches are adjusted per item.
	for child in park.get_children():
		await _turn()
		if child == self or child.name == "ParkScaleReviewPlayer" or child.name == "ExtractionRun": continue
		await _drape(child)
	# Batch lifts computed on workers during the walk are written back here, in
	# walk order, before anything that waits for the terrain can read them.
	await _apply_lifts()
	_boot_tick = StartupTrace.finish("terrain.drape",_boot_tick)
	_extend_piers()
	_boot_tick = StartupTrace.finish("terrain.piers",_boot_tick)
	installed = true
	if is_instance_valid(shadow_budget) and shadow_budget.has_method("after_source_change"):shadow_budget.after_source_change()
	print("MIDORI_TERRAIN_READY: range=",Array(heights).min(),"..",Array(heights).max()," roots=",moved_roots," instances=",moved_instances," islands=",islands.size()," draped_walks=",draped_walks)

func edge_distance(p: Vector2, polygon: PackedVector2Array) -> float:
	var distance := INF
	for i in range(polygon.size()):
		distance = minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,polygon[i],polygon[(i+1)%polygon.size()])))
	return distance

func water_at(p: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(p,shoreline): return false
	for island in islands:
		if Geometry2D.is_point_in_polygon(p,island.points): return false
	return true

func raw_height(p: Vector2) -> float:
	return _raw_height_from(p,shoreline,islands,landing_bounds)

## Inputs of the height grid, as the park structure holds them now. Typed like
## the members they are copied into.
func _height_inputs() -> Dictionary:
	var shore := PackedVector2Array()
	for p: Vector2 in park.lake_contour: shore.append(p * park.LAYOUT_SCALE)
	var lines: Array[PackedVector2Array] = []
	for name in ["OUTER_CIRCUIT","LAKE_PROMENADE_LOOP","SOUTH_ARRIVAL_ROUTE","WEST_DESTINATION_ROUTE","PLAZA_PAVED_ROUTE","NORTH_ENTRY_ROUTE","EAST_DECK_ROUTE","SPORTS_LINK_ROUTE","PLAYGROUND_LOOP","NORTH_WOODLAND_LOOP","SOUTH_BRIDGE_APPROACH","PAVILION_LINK_ROUTE","VIEWING_DECK_APPROACH_ROUTE","FUTURE_BRIDGE_WEST","FUTURE_BRIDGE_NORTH_EAST","FUTURE_BRIDGE_SOUTH"]:
		var line := PackedVector2Array()
		for p: Vector2 in park.get(name): line.append(p * park.LAYOUT_SCALE)
		lines.append(line)
	# Authored bridge treads and their fitted approaches keep their exact datum.
	var landings: Array[PackedVector2Array] = []
	var bounds: Array[Rect2] = []
	for walk: Dictionary in park._bridge_walk_surfaces:
		if walk.kind == "landing":
			landings.append(walk.spec.footprint)
			bounds.append(walk.spec.bounds)
	var isl: Array[Dictionary] = []
	var lake: Node3D = park.find_child("ArtworkContinuousLake*",true,false)
	for child in lake.get_children():
		if child is MeshInstance3D and "Isl" in String(child.name) and not "Bank" in String(child.name):
			var points := PackedVector2Array()
			for v: Vector3 in child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var world: Vector3 = child.global_transform * v
				points.append(Vector2(world.x,world.z))
			isl.append({"points":Geometry2D.convex_hull(points),"top":(child.global_transform * child.get_aabb().get_center()).y})
	var edges: Variant = park.get("_path_edge_cells")
	return {"shoreline":shore,"paths":lines,"protected_landings":landings,"landing_bounds":bounds,"islands":isl,"path_edges":(edges as Dictionary).hash() if edges is Dictionary else 0}

## WorkerThreadPool task: the same raw_height per grid point, in the same order,
## on copies of its inputs (the entrance lift reads the park's fixed path index).
func _compute_heights(inputs: Dictionary) -> void:
	inputs["worker_started_usec"] = Time.get_ticks_usec()
	var grid := PackedFloat32Array()
	grid.resize(NX * NZ)
	var shore: PackedVector2Array = inputs.shoreline
	var isl: Array = inputs.islands
	var bounds: Array = inputs.landing_bounds
	for z in range(NZ):
		for x in range(NX): grid[z*NX+x] = _raw_height_from(ORIGIN + Vector2(x,z)*STEP,shore,isl,bounds)
	# The tile vertex/normal/uv arrays are pure maths on this grid: build them here
	# too (used only when this grid is the one installed).
	var tiles: Array = []
	for tz in range(0,NZ-1,16):
		for tx in range(0,NX-1,16): tiles.append(_tile_arrays(grid,tx,tz))
	inputs["tiles"] = tiles
	inputs["heights"] = grid
	inputs["worker_finished_usec"] = Time.get_ticks_usec()

## One 16x16 tile's triangle arrays (vertices, normals, uv), from a height grid.
## The same loop _build_tiles ran, with _point on the given grid.
static func _tile_arrays(grid: PackedFloat32Array, tx: int, tz: int) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	for z in range(tz,mini(tz+16,NZ-1)):
		for x in range(tx,mini(tx+16,NX-1)):
			for index in [Vector2i(x,z),Vector2i(x+1,z),Vector2i(x,z+1),Vector2i(x+1,z),Vector2i(x+1,z+1),Vector2i(x,z+1)]:
				var v := _grid_point(grid,index.x,index.y)
				vertices.append(v)
				var dx := _grid_point(grid,mini(index.x+1,NX-1),index.y)-_grid_point(grid,maxi(index.x-1,0),index.y)
				var dz := _grid_point(grid,index.x,mini(index.y+1,NZ-1))-_grid_point(grid,index.x,maxi(index.y-1,0))
				normals.append(dz.cross(dx).normalized())
				uv.append(Vector2(v.x,v.z)*0.5)
	return [vertices,normals,uv]

static func _grid_point(grid: PackedFloat32Array, x: int, z: int) -> Vector3:
	return Vector3(ORIGIN.x+x*STEP,grid[z*NX+x],ORIGIN.y+z*STEP)

## Every producer waits for the terrain, so behind the boot menu it does not
## queue for the frame's shared budget (it resumed after the near city and alley
## life had spent it, and waited ~30 s for 0.5 s of work): it also takes a turn
## of its own of up to TURN_USEC in each frame. Same work in the same order; it
## only yields less often. A no-op outside incremental loading, like checkpoint().
const TURN_USEC := 25000
var _turn_frame := -1
var _turn_start := 0
func _turn() -> void:
	if not is_instance_valid(park) or not park.get_meta("shinrai_incremental_loading",false): return
	var now := Time.get_ticks_usec()
	var frame := Engine.get_process_frames()
	if frame != _turn_frame:
		_turn_frame = frame
		_turn_start = now
	if now - _turn_start < TURN_USEC or not LoadingBudget.over_budget(): return
	await get_tree().process_frame
	_turn_frame = Engine.get_process_frames()
	_turn_start = Time.get_ticks_usec()

var _height_task := -1
func _exit_tree() -> void:
	if _height_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_height_task)
		_height_task = -1
	for task: int in _lift_groups: WorkerThreadPool.wait_for_group_task_completion(task)
	_lift_groups.clear()
	_lift_jobs.clear()
	_lift_waiting.clear()
	_lift_pending.clear()

func _raw_height_from(p: Vector2, shore_in: PackedVector2Array, islands_in: Array, bounds_in: Array) -> float:
	if Geometry2D.is_point_in_polygon(p,shore_in):
		var distance := edge_distance(p,shore_in)
		var edge_y := 0.0
		for island in islands_in:
			if Geometry2D.is_point_in_polygon(p,island.points): return float(island.top)
			var d := edge_distance(p,island.points)
			if d < distance:
				distance = d
				edge_y = island.top
		# Broad walkable littoral shelf slopes into uneven 4â€“5 m pockets.
		var depth := 4.5 + 0.45*sin(p.x*0.047)*sin(p.y*0.039)
		return edge_y - depth * smoothstep(0.0,18.0,distance)
	# Kiyosumi-inspired proportions, inferred rather than surveyed: a low bank
	# rises inland over about 10 m; broad lawn relief carries through the walks.
	# Keep the original shoreline and underwater profile, including its grid cells.
	var shore_distance := edge_distance(p,shore_in)
	var bank := smoothstep(2.0,12.0,shore_distance)
	var hill := 0.60 + 0.10*sin(p.x*0.022)*cos(p.y*0.018)
	# The inland shoulder rises above the lakeside walk without sharp new hills.
	hill += 0.50*smoothstep(12.0,26.0,shore_distance)*(1.0-smoothstep(32.0,65.0,shore_distance))
	for mound in [Vector4(-108,24,60,1.10),Vector4(-60,-108,55,0.90),Vector4(-34,103,60,1.00),Vector4(-172,-12,48,0.55),Vector4(3,-70,45,0.70)]:
		var r: float = p.distance_to(Vector2(mound.x,mound.y))/mound.z
		hill += mound.w * pow(maxf(0.0,1.0-r*r),2.0)
	# One readable wooded knoll behind the west promenade: inferred crest about
	# 2.8 m and 46 m radius. The extra rise begins inland of the lakeside walk.
	var knoll_radius := p.distance_to(Vector2(-16.0,22.0))/46.0
	hill += 1.85*pow(maxf(0.0,1.0-knoll_radius*knoll_radius),2.0)*smoothstep(16.0,34.0,shore_distance)
	# Fade to the existing entry and boundary datum over 18 m. Activity pads and
	# complete bridge landing footprints retain a level apron, with gentle joins.
	var clearance := minf(220.0-absf(p.x),180.0-absf(p.y)) - 7.0
	for rect in [Rect2(-133,-66,14,18),Rect2(-166,-108,52,44),Rect2(-108,-150,36,24),Rect2(-180,58,72,64),Rect2(123,105,85,63),Rect2(127,-167,50,42)]:
		var q := p.clamp(rect.position,rect.end)
		clearance = minf(clearance,p.distance_to(q))
	# Bounds are deliberately conservative and avoid scanning hundreds of tiny
	# approach-edge segments for every terrain grid point.
	for rect in bounds_in:
		clearance = minf(clearance,p.distance_to(p.clamp(rect.position,rect.end)))
	return hill * bank * smoothstep(3.0,25.0,clearance) + _entrance_bank_lift(p)


# Two modest planted shoulders around the entrance canopy, in WORLD metres.
# Part of the shared height grid: visible ground, collision and planted roots agree.
func _entrance_bank_lift(p: Vector2) -> float:
	if p.x < -11.0 or p.x > 29.0 or p.y < 140.0 or p.y > 165.0: return 0.0
	var apron := Rect2(2.0,151.15,12.0,6.0).grow(2.1)
	var ramp := Rect2(3.8,157.15,8.4,2.0).grow(2.1)
	var clear: float=minf(p.distance_to(p.clamp(apron.position,apron.end)),p.distance_to(p.clamp(ramp.position,ramp.end)))
	# The extra 2.1m zero band also protects interpolation across the 2m grid.
	var route: float=park.path_edge_distance_world(p)
	if clear <= 0.0 or route <= 2.9: return 0.0
	var lift := 0.0
	for mound: Vector4 in [Vector4(-4.0,152.0,6.5,.78),Vector4(20.5,152.8,7.0,.84)]:
		var q := Vector2((p.x-mound.x)/mound.z,(p.y-mound.y)/10.0)
		lift=maxf(lift,mound.w*pow(maxf(0.0,1.0-q.length_squared()),2.0))
	return lift*smoothstep(0.0,3.0,clear)*smoothstep(2.9,5.0,route)

func height_at(p: Vector2) -> float:
	if heights.is_empty(): return 0.0
	var q := ((p-ORIGIN)/STEP).clamp(Vector2.ZERO,Vector2(NX-1.001,NZ-1.001))
	var x := int(q.x)
	var z := int(q.y)
	var f := q - Vector2(x,z)
	var a := heights[z*NX+x]
	var b := heights[z*NX+x+1]
	var c := heights[(z+1)*NX+x]
	var d := heights[(z+1)*NX+x+1]
	return a+(b-a)*f.x+(c-a)*f.y if f.x+f.y<=1.0 else d+(c-d)*(1.0-f.x)+(b-d)*(1.0-f.y)

func _point(x: int,z: int) -> Vector3:
	return Vector3(ORIGIN.x+x*STEP,heights[z*NX+x],ORIGIN.y+z*STEP)

func _build_tiles(grass: Material,soil: Material,prebuilt: Array = []) -> void:
	var tile_index := 0
	var tile_total := range(0,NX-1,16).size()*range(0,NZ-1,16).size()
	for tz in range(0,NZ-1,16):
		await _turn()
		for tx in range(0,NX-1,16):
			await _turn()
			var built: Array = prebuilt[tile_index] if prebuilt.size() == tile_total else _tile_arrays(heights,tx,tz)
			tile_index += 1
			var vertices: PackedVector3Array = built[0]
			var normals: PackedVector3Array = built[1]
			var uv: PackedVector2Array = built[2]
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=vertices
			arrays[Mesh.ARRAY_NORMAL]=normals
			arrays[Mesh.ARRAY_TEX_UV]=uv
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var visual := MeshInstance3D.new()
			visual.name = "Terrain_%d_%d" % [tx,tz]
			visual.mesh = mesh
			# Reuse the existing ground texture with a submerged-soil tint.
			# Collision uses these same visible triangles.
			visual.material_override = soil
			add_child(visual)
			var body := StaticBody3D.new()
			body.add_to_group("midori_terrain_floor")
			visual.add_child(body)
			var collision := CollisionShape3D.new()
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = true
			shape.set_faces(vertices)
			collision.shape = shape
			body.add_child(collision)
	# Use the supplied terrain's material and inject only a submerged-soil tint.
	if grass is ShaderMaterial:
		for child in get_children():
			await _turn()
			if child is MeshInstance3D: child.material_override = grass
		var parameters := {}
		for uniform in grass.shader.get_shader_uniform_list():
			await _turn()
			parameters[uniform.name] = grass.get_shader_parameter(uniform.name)
		var code: String = grass.shader.code
		# Ground texture service has its own uniforms; keep that exact resource live.
		if code.contains("ALBEDO ="):
			var closing := code.rfind("}")
			code = code.insert(closing,"\n    float silt = 1.0 - smoothstep(-0.65, 0.03, world_pos.y);\n    ALBEDO = mix(ALBEDO, vec3(0.037,0.028,0.018), silt);\n")
			var terrain_shader := Shader.new()
			terrain_shader.code = code
			grass.shader = terrain_shader
			for key in parameters: grass.set_shader_parameter(key,parameters[key])

func _soil_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = "Midori_DampEarth_TerrainFallback"
	mat.albedo_color = Color(0.075,0.055,0.034)
	mat.roughness = 0.97
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _drape(node: Node) -> void:
	var label := String(node.name)
	if label.begins_with("ParkGround") or label.begins_with("ArtworkContinuousLake") or node is Camera3D or node is DirectionalLight3D or node is ReflectionProbe: return
	# Main paths are authored around the origin: translating their root cannot
	# fit a slope. Subdivide and drape their existing surfaces and UVs instead.
	if node is MeshInstance3D and String(node.get_parent().name) in ["FinalDestinationLedPathHierarchy","ApprovedLakePromenadeLoop"]:
		# Each walk is subdivided and given a trimesh: one shared budget per walk
		# (they all used to run in a single ~4 s frame under the boot menu).
		await _turn()
		if is_instance_valid(node): await _drape_walk(node)
		return
	if node is MultiMeshInstance3D and node.multimesh != null:
		# Preserve each supplied mesh; only raise instance anchors on dry terrain.
		var multi: MultiMesh = node.multimesh
		# A batch resource seen again must read the lifts already made to it.
		if _lift_pending.has(multi): await _apply_lifts()
		if _queue_lift(node, multi): return
		for i in range(multi.instance_count):
			if i % 256 == 0: await _turn()
			var t := multi.get_instance_transform(i)
			var world: Vector3 = node.global_transform*t.origin
			var h := land_lift_at(Vector2(world.x,world.z))
			if h > 0.001:
				t.origin += node.global_basis.inverse()*Vector3(0,h,0)
				multi.set_instance_transform(i,t)
				moved_instances += 1
		return
	if node is Node3D and Vector2(node.position.x,node.position.z).length_squared()>0.001:
		# Containers with batches must be walked per instance, not lifted as a slab.
		var has_batch := not node.find_children("*","MultiMeshInstance3D",true,false).is_empty()
		# Sakura replacements contain attached blossom batches. They are a rigid
		# supplied tree hierarchy, so lift its trunk and all attachments together.
		if not has_batch or node.has_meta("midori_jogoss_sakura"):
			var p: Vector3 = node.global_position
			var h := land_lift_at(Vector2(p.x,p.z))
			if h>0.001:
				node.global_position.y += h
				moved_roots += 1
			return
	# Large containers (thousands of rooted props) were walked in one frame after
	# the last batch checkpoint: ~4 s under the boot menu. Time-based, so cheap.
	for child in node.get_children():
		await _turn()
		if is_instance_valid(child): await _drape(child)

func _drape_walk(walk: MeshInstance3D) -> void:
	var result := ArrayMesh.new()
	for surface_index in range(walk.mesh.get_surface_count()):
		await _turn()
		if not is_instance_valid(walk): return
		var source := SurfaceTool.new()
		source.create_from(walk.mesh,surface_index)
		source.deindex()
		var arrays := source.commit_to_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var output := SurfaceTool.new()
		output.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(0,vertices.size(),3):
			# The output SurfaceTool is local; the walk keeps its old mesh until the end.
			if i % 384 == 0 and i > 0:
				await _turn()
				if not is_instance_valid(walk): return
			var triangle: Array = []
			for j in range(3):
				triangle.append([walk.global_transform*vertices[i+j],uvs[i+j],colors[i+j] if not colors.is_empty() else Color.WHITE])
			_drape_triangle(output,walk.global_transform.affine_inverse(),triangle,0)
		output.generate_normals()
		output.commit(result)
		result.surface_set_material(surface_index,walk.mesh.surface_get_material(surface_index))
	await _turn()
	if not is_instance_valid(walk): return
	walk.mesh = result
	# The pavement and physics use the same tessellated mesh, including edges.
	var body := StaticBody3D.new()
	body.name = "TerrainConformedPaving"
	body.add_to_group("midori_terrain_paving")
	# Keep floor collision under this terrain service. Woodland route indexing
	# excludes its floors; a sloped path AABB must not become a giant obstacle.
	add_child(body)
	body.global_transform = walk.global_transform
	body.set_meta("terrain_walk",walk)
	var collision := CollisionShape3D.new()
	collision.shape = result.create_trimesh_shape()
	body.add_child(collision)
	draped_walks += 1

func _drape_triangle(output: SurfaceTool, inverse: Transform3D, tri: Array, depth: int) -> void:
	var longest := 0.0
	var edge := 0
	for i in range(3):
		var a: Vector3 = tri[i][0]
		var b: Vector3 = tri[(i+1)%3][0]
		var distance := Vector2(a.x,a.z).distance_squared_to(Vector2(b.x,b.z))
		if distance > longest:
			longest = distance
			edge = i
	if longest > 2.25 and depth < 16:
		var a: Array = tri[edge]
		var b: Array = tri[(edge+1)%3]
		var c: Array = tri[(edge+2)%3]
		var midpoint := [(a[0]+b[0])*0.5,(a[1]+b[1])*0.5,(a[2]+b[2])*0.5]
		_drape_triangle(output,inverse,[a,midpoint,c],depth+1)
		_drape_triangle(output,inverse,[midpoint,b,c],depth+1)
		return
	for vertex: Array in tri:
		var p: Vector3 = vertex[0]
		p.y += land_lift_at(Vector2(p.x,p.z))
		output.set_uv(vertex[1])
		output.set_color(vertex[2])
		output.add_vertex(inverse*p)

func land_lift_at(p: Vector2) -> float:
	return 0.0 if Geometry2D.is_point_in_polygon(p,shoreline) else maxf(0.0,height_at(p))

## Drape of one batch on a worker: its transform buffer (3x4 rows per instance,
## origin at 3/7/11, as park_floor's scan reads it) is copied here, the same
## per-instance lift is computed on the worker, and _apply_lifts writes the buffer
## back (only when an instance moved, as the per-instance loop only wrote those).
## False (the per-instance loop runs) for any other buffer layout.
## Jobs are [multimesh, input, result], in walk order. They are handed to the pool
## in groups of at least LIFT_GROUP_INSTANCES instances, one group at a time, on
## at most LIFT_THREADS threads (the main thread and other producers keep cores).
const LIFT_GROUP_INSTANCES := 40000
const LIFT_THREADS := 3
var _lift_jobs: Array = []
var _lift_waiting: Array = []
var _lift_waiting_instances := 0
var _lift_groups: Array = []
var _lift_pending: Dictionary = {}
func _queue_lift(node: MultiMeshInstance3D, multi: MultiMesh) -> bool:
	if multi.transform_format != MultiMesh.TRANSFORM_3D or multi.instance_count == 0: return false
	var stride := 12 + (4 if multi.use_colors else 0) + (4 if multi.use_custom_data else 0)
	# The row layout is checked once per run on a throwaway MultiMesh, not with
	# get_instance_transform(0) on every batch: that read made the renderer keep a
	# CPU copy of the whole buffer for the MultiMesh's life (thousands of batches).
	if not _buffer_rows_verified(): return false
	var buffer := multi.buffer
	if buffer.size() != stride * multi.instance_count: return false
	var input := {"buffer": buffer, "stride": stride, "count": multi.instance_count, "xform": node.global_transform, "lift": node.global_basis.inverse(), "heights": heights, "shoreline": shoreline}
	var job := [multi, input, {}, node]
	_lift_jobs.append(job)
	_lift_waiting.append(job)
	_lift_waiting_instances += multi.instance_count
	_lift_pending[multi] = true
	if _lift_waiting_instances >= LIFT_GROUP_INSTANCES and (_lift_groups.is_empty() or WorkerThreadPool.is_group_task_completed(int(_lift_groups[-1]))):
		_launch_lifts()
	return true

## TRANSFORM_3D rows are the three basis rows with the origin component as each
## row's fourth float (origin at 3/7/11, as _lift_batch reads it). Verified once on
## a one-instance MultiMesh: the row is written as a buffer (the way the lift
## writes its result back) and read back as the instance transform. The probe has
## no mesh, so it never reaches the renderer's AABB rebuild (which would log an
## error for a mesh-less MultiMesh when an instance is set one at a time). False
## (per-instance path, as before) under a renderer that does not expose the
## buffer this way (headless dummy renderer).
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
	_rows_ok = probe.get_instance_transform(0) == t and probe.buffer == rows
	return _rows_ok

func _launch_lifts() -> void:
	if _lift_waiting.is_empty(): return
	var group := _lift_waiting
	_lift_waiting = []
	_lift_waiting_instances = 0
	_lift_groups.append(WorkerThreadPool.add_group_task(_lift_group.bind(group), group.size(), mini(LIFT_THREADS, group.size()), true, "MidoriTerrain drape lift"))

static func _lift_group(index: int, group: Array) -> void:
	_lift_batch(group[index][1], group[index][2])

func _apply_lifts() -> void:
	_launch_lifts()
	while not _lift_groups.is_empty():
		var task := int(_lift_groups[0])
		while not WorkerThreadPool.is_group_task_completed(task):
			await get_tree().process_frame
			# _exit_tree waited for and dropped every group.
			if _lift_groups.is_empty() or int(_lift_groups[0]) != task: return
		_lift_groups.pop_front()
		WorkerThreadPool.wait_for_group_task_completion(task)
	for job: Array in _lift_jobs:
		var multi: MultiMesh = job[0]
		var input: Dictionary = job[1]
		var result: Dictionary = job[2]
		var stride := 12 + (4 if multi.use_colors else 0) + (4 if multi.use_custom_data else 0)
		if multi.instance_count != int(input.count) or stride != int(input.stride) or multi.transform_format != MultiMesh.TRANSFORM_3D:
			# The batch was resized or re-laid out after its snapshot: writing the
			# snapshot back would drop that edit (or be rejected). Lift the live batch
			# per instance instead, as before the worker path existed.
			push_warning("MidoriTerrain: batch changed during drape; lifting it per instance")
			await _lift_live(job[3] as MultiMeshInstance3D, multi, input.xform, input.lift)
		elif int(result.moved) > 0:
			multi.buffer = result.buffer
			moved_instances += int(result.moved)
		await _turn()
	_lift_jobs.clear()
	_lift_pending.clear()

## The per-instance loop of _drape on a live batch, with the node transform the
## batch was queued with.
func _lift_live(_node: MultiMeshInstance3D, multi: MultiMesh, xform: Transform3D, lift: Basis) -> void:
	for i in range(multi.instance_count):
		if i % 256 == 0: await _turn()
		var t := multi.get_instance_transform(i)
		var world: Vector3 = xform*t.origin
		var h := land_lift_at(Vector2(world.x,world.z))
		if h > 0.001:
			t.origin += lift*Vector3(0,h,0)
			multi.set_instance_transform(i,t)
			moved_instances += 1

## WORKER: the per-instance loop of _drape on a copy of one batch's buffer.
static func _lift_batch(input: Dictionary, result: Dictionary) -> void:
	var b: PackedFloat32Array = input.buffer
	var stride: int = input.stride
	var xform: Transform3D = input.xform
	var lift: Basis = input.lift
	var grid: PackedFloat32Array = input.heights
	var shore: PackedVector2Array = input.shoreline
	var moved := 0
	for i in range(int(input.count)):
		var o := i*stride
		var origin := Vector3(b[o+3],b[o+7],b[o+11])
		var world: Vector3 = xform*origin
		var p := Vector2(world.x,world.z)
		var h := 0.0 if Geometry2D.is_point_in_polygon(p,shore) else maxf(0.0,_grid_height(grid,p))
		if h > 0.001:
			origin += lift*Vector3(0,h,0)
			b[o+3] = origin.x
			b[o+7] = origin.y
			b[o+11] = origin.z
			moved += 1
	result["buffer"] = b
	result["moved"] = moved

## height_at on a given grid (same expression).
static func _grid_height(grid: PackedFloat32Array, p: Vector2) -> float:
	if grid.is_empty(): return 0.0
	var q := ((p-ORIGIN)/STEP).clamp(Vector2.ZERO,Vector2(NX-1.001,NZ-1.001))
	var x := int(q.x)
	var z := int(q.y)
	var f := q - Vector2(x,z)
	var a := grid[z*NX+x]
	var b := grid[z*NX+x+1]
	var c := grid[(z+1)*NX+x]
	var d := grid[(z+1)*NX+x+1]
	return a+(b-a)*f.x+(c-a)*f.y if f.x+f.y<=1.0 else d+(c-d)*(1.0-f.x)+(b-d)*(1.0-f.y)

func _extend_piers() -> void:
	var count := 0
	for support in park.find_children("*","Node3D",true,false):
		if not String(support.get_meta("midori_bridge_support","")).begins_with("PierPortal"): continue
		var bounds := AABB()
		var first := true
		var material: Material
		for part in support.find_children("*","MeshInstance3D",true,false):
			var relative: Transform3D = support.global_transform.affine_inverse()*part.global_transform
			var box: AABB = relative*part.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
			if material == null: material = part.get_active_material(0)
		for side in [-1.0,1.0]:
			var foot: Vector3 = support.global_transform*Vector3(0,bounds.position.y,side*(bounds.size.z*0.5-0.18))
			var bed := height_at(Vector2(foot.x,foot.z))-0.20
			var height := foot.y-bed+0.025
			if height<0.05: continue
			var extension := MeshInstance3D.new()
			extension.name="SubmergedPierExtension_%02d" % count
			var box := BoxMesh.new()
			box.size=Vector3(0.36,height,0.36)
			extension.mesh=box
			extension.material_override=material
			add_child(extension)
			extension.global_transform=Transform3D(support.global_basis.orthonormalized(),Vector3(foot.x,bed+height*0.5,foot.z))
			var body := StaticBody3D.new()
			extension.add_child(body)
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size=box.size
			collision.shape=shape
			body.add_child(collision)
			count+=1
	print("TERRAIN_PIER_FOUNDATIONS ",count)


