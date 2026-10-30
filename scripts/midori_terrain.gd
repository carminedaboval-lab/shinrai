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
	# Let the supplied planting/groundcover services finish on the original datum.
	for frame in range(16): await get_tree().process_frame
	# Incremental planting can span more than sixteen frames; its datum must precede draping.
	if park.get_meta("shinrai_incremental_loading",false):
		while not park.has_meta("woodland_diversity"):
			await get_tree().process_frame
	_boot_tick = StartupTrace.finish("terrain.wait_services",_boot_tick)
	for p: Vector2 in park.lake_contour: shoreline.append(p * park.LAYOUT_SCALE)
	for name in ["OUTER_CIRCUIT","LAKE_PROMENADE_LOOP","SOUTH_ARRIVAL_ROUTE","WEST_DESTINATION_ROUTE","PLAZA_PAVED_ROUTE","NORTH_ENTRY_ROUTE","EAST_DECK_ROUTE","SPORTS_LINK_ROUTE","PLAYGROUND_LOOP","NORTH_WOODLAND_LOOP","SOUTH_BRIDGE_APPROACH","PAVILION_LINK_ROUTE","VIEWING_DECK_APPROACH_ROUTE","FUTURE_BRIDGE_WEST","FUTURE_BRIDGE_NORTH_EAST","FUTURE_BRIDGE_SOUTH"]:
		await LoadingBudget.checkpoint(park)
		var line := PackedVector2Array()
		for p: Vector2 in park.get(name): line.append(p * park.LAYOUT_SCALE)
		paths.append(line)
	# Authored bridge treads and their fitted approaches keep their exact datum.
	for walk: Dictionary in park._bridge_walk_surfaces:
		await LoadingBudget.checkpoint(park)
		if walk.kind == "landing":
			protected_landings.append(walk.spec.footprint)
			landing_bounds.append(walk.spec.bounds)
	var lake: Node3D = park.find_child("ArtworkContinuousLake*",true,false)
	for child in lake.get_children():
		await LoadingBudget.checkpoint(park)
		if child is MeshInstance3D and "Isl" in String(child.name) and not "Bank" in String(child.name):
			var points := PackedVector2Array()
			for v: Vector3 in child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var world: Vector3 = child.global_transform * v
				points.append(Vector2(world.x,world.z))
			islands.append({"points":Geometry2D.convex_hull(points),"top":(child.global_transform * child.get_aabb().get_center()).y})
	heights.resize(NX * NZ)
	for z in range(NZ):
		await LoadingBudget.checkpoint(park)
		for x in range(NX): heights[z*NX+x] = raw_height(ORIGIN + Vector2(x,z)*STEP)
	_boot_tick = StartupTrace.finish("terrain.height_grid",_boot_tick)
	var ground: StaticBody3D = park.find_child("ParkGround_220x180m",true,false)
	var material: Material
	for child in ground.get_children():
		await LoadingBudget.checkpoint(park)
		if child is MeshInstance3D: material = child.material_override
	# Keep the old material resource so the day/night service keeps updating it.
	var soil := _soil_material()
	await _build_tiles(material, soil)
	_boot_tick = StartupTrace.finish("terrain.mesh_collision",_boot_tick)
	ground.collision_layer = 0
	ground.hide()
	var shadow_budget:=park.get_node_or_null("MidoriNearPlantShadows")
	if shadow_budget!=null and shadow_budget.has_method("before_source_change"):shadow_budget.before_source_change()
	# Group roots retain supplied model hierarchies; batches are adjusted per item.
	for child in park.get_children():
		await LoadingBudget.checkpoint(park)
		if child == self or child.name == "ParkScaleReviewPlayer" or child.name == "ExtractionRun": continue
		await _drape(child)
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
	if Geometry2D.is_point_in_polygon(p,shoreline):
		var distance := edge_distance(p,shoreline)
		var edge_y := 0.0
		for island in islands:
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
	var shore_distance := edge_distance(p,shoreline)
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
	for rect in landing_bounds:
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

func _build_tiles(grass: Material,soil: Material) -> void:
	for tz in range(0,NZ-1,16):
		await LoadingBudget.checkpoint(park)
		for tx in range(0,NX-1,16):
			await LoadingBudget.checkpoint(park)
			var vertices := PackedVector3Array()
			var normals := PackedVector3Array()
			var uv := PackedVector2Array()
			for z in range(tz,mini(tz+16,NZ-1)):
				for x in range(tx,mini(tx+16,NX-1)):
					for index in [Vector2i(x,z),Vector2i(x+1,z),Vector2i(x,z+1),Vector2i(x+1,z),Vector2i(x+1,z+1),Vector2i(x,z+1)]:
						var v := _point(index.x,index.y)
						vertices.append(v)
						var dx := _point(mini(index.x+1,NX-1),index.y)-_point(maxi(index.x-1,0),index.y)
						var dz := _point(index.x,mini(index.y+1,NZ-1))-_point(index.x,maxi(index.y-1,0))
						normals.append(dz.cross(dx).normalized())
						uv.append(Vector2(v.x,v.z)*0.5)
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
			await LoadingBudget.checkpoint(park)
			if child is MeshInstance3D: child.material_override = grass
		var parameters := {}
		for uniform in grass.shader.get_shader_uniform_list():
			await LoadingBudget.checkpoint(park)
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
		_drape_walk(node)
		return
	if node is MultiMeshInstance3D and node.multimesh != null:
		# Preserve each supplied mesh; only raise instance anchors on dry terrain.
		var multi: MultiMesh = node.multimesh
		for i in range(multi.instance_count):
			if i % 256 == 0: await LoadingBudget.checkpoint(park)
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
	for child in node.get_children(): await _drape(child)

func _drape_walk(walk: MeshInstance3D) -> void:
	var result := ArrayMesh.new()
	for surface_index in range(walk.mesh.get_surface_count()):
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
			var triangle: Array = []
			for j in range(3):
				triangle.append([walk.global_transform*vertices[i+j],uvs[i+j],colors[i+j] if not colors.is_empty() else Color.WHITE])
			_drape_triangle(output,walk.global_transform.affine_inverse(),triangle,0)
		output.generate_normals()
		output.commit(result)
		result.surface_set_material(surface_index,walk.mesh.surface_get_material(surface_index))
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


