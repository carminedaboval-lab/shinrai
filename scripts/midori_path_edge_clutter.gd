extends RefCounted
# Bend a few copies of the installed grass mesh; source planting is untouched.
static func apply(parent: Node3D, park: Node3D, paths: Array[Dictionary], terrain: Node) -> void:
	var beds := park.find_children("JapaneseForestGrassDrift_*","MultiMeshInstance3D",true,false)
	if beds.is_empty(): return
	var source: Mesh = beds[0].multimesh.mesh
	var box := source.get_aabb()
	var anchor := Vector3(box.get_center().x,box.position.y,box.get_center().z)
	var folded: Array[ArrayMesh] = []
	for strength: float in [.65,1.1,1.5]: folded.append(_bend(source,strength))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2050100626
	var edge_count := 0
	var outer_count := 0
	for route: Dictionary in paths:
		var points: PackedVector2Array = route.points
		for index in range(9,points.size()-6,18):
			var tangent := (points[index+1]-points[index-1]).normalized()
			var side := 1.0 if edge_count%2==0 else -1.0
			var normal := Vector2(-tangent.y,tangent.x)*side
			var p := points[index]+normal*rng.randf_range(3.3,3.8)
			var along_side := (tangent if edge_count%3==0 else normal)
			var yaw := atan2(-along_side.y,along_side.x)+rng.randf_range(-.22,.22)
			var edge_plant := _place(parent,folded[edge_count%3],box,anchor,p,yaw,rng.randf_range(.48,.64),rng.randf_range(.65,.85),terrain,"PathEdgeFoldedGrass_%02d"%edge_count,paths,normal,park)
			if edge_plant == null: continue
			edge_count += 1
			if edge_count%2==0:
				p = points[index]+normal*rng.randf_range(5.0,6.0)+tangent*rng.randf_range(-1.0,1.0)
				if terrain != null and terrain.water_at(p): continue
				var outer_plant := _place(parent,folded[2],box,anchor,p,rng.randf_range(0,TAU),rng.randf_range(.42,.57),rng.randf_range(.60,.80),terrain,"WoodlandFoldedGrass_%02d"%outer_count,paths,normal,park)
				if outer_plant == null: continue
				outer_count += 1
	print("PATH_EDGE_FOLDS_READY edge=",edge_count," woodland=",outer_count)

static func _place(parent: Node3D,mesh: Mesh,box: AABB,anchor: Vector3,p: Vector2,yaw: float,height: float,width: float,terrain: Node,label: String,paths: Array[Dictionary],outward: Vector2,park: Node3D) -> MeshInstance3D:
	var scale := Vector3(width/maxf(box.size.x,box.size.z),height/box.size.y,width/maxf(box.size.x,box.size.z))
	var basis := Basis(Vector3.UP,yaw)*Basis.from_scale(scale)
	for attempt in range(10):
		var ground: float = terrain.height_at(p) if terrain != null else .01
		var transform := Transform3D(basis,Vector3(p.x,ground+.003,p.y)-basis*anchor)
		var dry: bool = terrain == null or not terrain.water_at(p)
		var lawn: bool = not park.has_method("_is_vegetation_clear") or park._is_vegetation_clear(Vector3(p.x*.5,0,p.y*.5),.45)
		var margin := path_margin(transform*mesh.get_aabb(),paths)
		if dry and lawn and margin >= 2.35:
			var instance := MeshInstance3D.new()
			instance.name = label
			instance.mesh = mesh
			parent.add_child(instance)
			instance.global_transform = transform
			instance.set_meta("root_world",Vector3(p.x,ground+.003,p.y))
			instance.set_meta("path_clearance_m",margin)
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.visibility_range_end = 45.0
			instance.visibility_range_end_margin = 5.0
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			return instance
		p += outward*.35
	return null

# Conservative footprint clearance includes every blade, not just its root.
static func path_margin(box: AABB,paths: Array[Dictionary]) -> float:
	var center := Vector2(box.get_center().x,box.get_center().z)
	var radius := Vector2(box.size.x,box.size.z).length()*.5
	var distance := INF
	for route: Dictionary in paths:
		var points: PackedVector2Array = route.points
		for index in range(1,points.size()):
			distance = minf(distance,center.distance_to(Geometry2D.get_closest_point_to_segment(center,points[index-1],points[index])))
	return distance-radius

static func _bend(source: Mesh,strength: float) -> ArrayMesh:
	var result := ArrayMesh.new()
	var box := source.get_aabb()
	var height := maxf(box.size.y,.001)
	var drop := minf(.42,.10+.22*strength)
	for surface in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface).duplicate(true)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		for i in range(vertices.size()):
			var h := maxf(0.0,vertices[i].y-box.position.y)
			var sx := 2.0*strength*h/height
			var sy := 1.0-2.0*drop*h/height
			vertices[i] += Vector3(strength*h*h/height,-drop*h*h/height,0)
			if normals.size()>i:
				var n := normals[i]
				normals[i] = Vector3(n.x,(n.y-sx*n.x)/sy,n.z).normalized()
			if tangents.size()>=i*4+4:
				var t := Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
				t = Vector3(t.x+sx*t.y,sy*t.y,t.z).normalized()
				tangents[i*4]=t.x; tangents[i*4+1]=t.y; tangents[i*4+2]=t.z
		arrays[Mesh.ARRAY_VERTEX]=vertices
		if not normals.is_empty(): arrays[Mesh.ARRAY_NORMAL]=normals
		if not tangents.is_empty(): arrays[Mesh.ARRAY_TANGENT]=tangents
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface),arrays)
		result.surface_set_material(surface,source.surface_get_material(surface))
	return result
