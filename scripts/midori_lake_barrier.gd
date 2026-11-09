extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")
# Metric Meshy posts on a broad bank-side loop, with independent continuous ropes.
var installed := false
var posts: Array[Vector3] = []
var spans: Array[Vector2i] = []
var rejected := 0
var terrain: Node3D
var park: Node3D
const POST = preload("res://assets/park/kiyosumi_barrier/kiyosumi_meshy_post.glb")

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	call_deferred("install")

func clear_at(p: Vector2) -> bool:
	if terrain.water_at(p): return false
	if is_finite(park.bridge_surface_height(p)): return false
	for polygon in terrain.protected_landings:
		if Geometry2D.is_point_in_polygon(p,polygon) or terrain.edge_distance(p,polygon)<0.65: return false
	# Leave generous crossings at all three bridges and the east viewing deck.
	for key in ["FUTURE_BRIDGE_WEST","FUTURE_BRIDGE_NORTH_EAST","FUTURE_BRIDGE_SOUTH","VIEWING_DECK_APPROACH_ROUTE","SOUTH_BRIDGE_APPROACH"]:
		var line = park.get(key)
		for i in range(line.size()-1):
			if Geometry2D.get_closest_point_to_segment(p,line[i]*2.0,line[i+1]*2.0).distance_to(p)<3.0: return false
	return true

func find_mesh(node: Node, accumulated: Transform3D) -> Dictionary:
	if node is Node3D: accumulated = accumulated * node.transform
	if node is MeshInstance3D: return {"mesh":node.mesh,"transform":accumulated}
	for child in node.get_children():
		var result := find_mesh(child,accumulated)
		if not result.is_empty(): return result
	return {}

func install() -> void:
	park = get_parent()
	terrain = park.get_node("MidoriTerrain")
	while not terrain.installed: await get_tree().process_frame
	# Everything waiting on the terrain wakes in one frame: take a budget turn first.
	await LoadingBudget.checkpoint(park)
	var _ft := preload("res://scripts/startup_trace.gd").begin()
	var broad := PackedVector2Array()
	var authored = park.get("LAKE_PROMENADE_LOOP")
	for i in range(authored.size()-1): broad.append(authored[i]*2.0)
	# Broad promenade geometry deliberately ignores the water's small indentations.
	var offsets := Geometry2D.offset_polygon(broad,-3.4,Geometry2D.JOIN_ROUND)
	if offsets.is_empty(): push_error("LAKE_BARRIER: no perimeter"); return
	var route: PackedVector2Array = offsets[0]
	var previous := -1
	var first := -1
	var first_valid := false
	for edge in range(route.size()):
		var a := route[edge]
		var b := route[(edge+1)%route.size()]
		var count := maxi(1,ceili(a.distance_to(b)/1.45))
		for step in range(count):
			var p := a.lerp(b,float(step)/count)
			# Test the entire rope span, not just its endpoint posts.
			var valid := clear_at(p)
			if previous>=0:
				var last := Vector2(posts[previous].x,posts[previous].z)
				for sample in range(1,5): valid = valid and clear_at(last.lerp(p,float(sample)/5.0))
			if not valid:
				previous = -1
				rejected += 1
				continue
			var index := posts.size()
			posts.append(Vector3(p.x,terrain.height_at(p)-0.008,p.y))
			if edge==0 and step==0: first=index; first_valid=true
			if previous>=0: spans.append(Vector2i(previous,index))
			previous=index
	if first_valid and previous>=0:
		var a := Vector2(posts[previous].x,posts[previous].z)
		var b := Vector2(posts[first].x,posts[first].z)
		if a.distance_to(b)<1.5 and clear_at(a.lerp(b,0.5)): spans.append(Vector2i(previous,first))
	var original := POST.instantiate()
	var data := find_mesh(original,Transform3D.IDENTITY)
	var mm := MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=data.mesh
	mm.instance_count=posts.size()
	for i in range(posts.size()):
		mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,posts[i])*data.transform)
	var timber := MultiMeshInstance3D.new()
	timber.name="TexturedMeshyTimberPosts"
	timber.multimesh=mm
	add_child(timber)
	original.free()
	var rope := StandardMaterial3D.new()
	rope.albedo_color=Color(0.105,0.082,0.055)
	rope.roughness=0.98
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(rope)
	for span in spans:
		for level in [0.25,0.48]:
			add_rope(surface,posts[span.x]+Vector3.UP*level,posts[span.y]+Vector3.UP*level)
	var ropes := MeshInstance3D.new()
	ropes.name="ContinuousBankRopes"
	surface.generate_normals()
	ropes.mesh=surface.commit()
	add_child(ropes)
	preload("res://scripts/startup_trace.gd").finish("feature.lake_barrier", _ft)
	installed=true
	print("LAKE_BARRIER_INSTALLED posts=",posts.size()," spans=",spans.size()," openings_samples=",rejected)

func add_rope(surface: SurfaceTool,a: Vector3,b: Vector3) -> void:
	var direction := (b-a).normalized()
	var side := direction.cross(Vector3.UP).normalized()
	var up := side.cross(direction).normalized()
	for section in range(6):
		var t0 := float(section)/6.0
		var t1 := float(section+1)/6.0
		var c0 := a.lerp(b,t0)-Vector3.UP*sin(t0*PI)*0.025
		var c1 := a.lerp(b,t1)-Vector3.UP*sin(t1*PI)*0.025
		for face in range(8):
			var n0 := (side*cos(face*TAU/8.0)+up*sin(face*TAU/8.0))*0.008
			var n1 := (side*cos((face+1)*TAU/8.0)+up*sin((face+1)*TAU/8.0))*0.008
			for v in [c0+n0,c1+n0,c1+n1,c0+n0,c1+n1,c0+n1]: surface.add_vertex(v)
