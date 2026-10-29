extends RefCounted

# Fit the existing illuminated walk to each original bridge's actual front tread.
# World-space vertices avoid inheriting the park's two-times horizontal scale.
static func install(parent: Node3D, node_name: String, start: Vector2, mouth: Vector2, into_bridge: Vector2, bridge_width: float, tread_height: float, material: Material, existing_walks: Array[Dictionary] = []) -> Dictionary:
	var points: Array[Vector3] = []
	var widths: Array[float] = []
	var distances: Array[float] = []
	var lateral_offset := absf((start-mouth).dot(Vector2(-into_bridge.y,into_bridge.x)))
	var control := mouth-into_bridge*maxf(4.0,lateral_offset*0.60)
	var travelled := 0.0
	for index: int in range(97):
		var t := float(index)/96.0
		var p := start*(1.0-t)*(1.0-t)+control*2.0*t*(1.0-t)+mouth*t*t
		var height := lerpf(0.116,tread_height+0.006,smoothstep(0.0,1.0,t))
		points.append(Vector3(p.x,height,p.y))
		widths.append(lerpf(3.2,bridge_width-0.60,smoothstep(0.50,1.0,t)))
		if index > 0:
			travelled += Vector2(points[index].x-points[index-1].x,points[index].z-points[index-1].z).length()
		distances.append(travelled)
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for index: int in range(points.size()):
		var tangent := points[mini(index+1,points.size()-1)]-points[maxi(index-1,0)]
		tangent.y = 0.0
		if index == points.size()-1:
			tangent = Vector3(into_bridge.x,0,into_bridge.y)
		tangent = tangent.normalized()
		var side := Vector3(-tangent.z,0,tangent.x)*widths[index]*0.5
		left.append(points[index]-side)
		right.append(points[index]+side)
	# The branch sits flush on existing paving at a junction. Its slight reveal
	# avoids flicker while removing the raised lip/shadow across the promenade.
	for index: int in range(points.size()):
		for edge: Array[Vector3] in [left,right]:
			var p := edge[index]
			var paving_height := existing_height(existing_walks,Vector2(p.x,p.z))
			if paving_height > 0.0:
				# Keep the junction flush, then rise continuously to the actual tread.
				# Flattening the mouth itself would create a lip at a nearby promenade.
				var remaining := (mouth-Vector2(p.x,p.z)).dot(into_bridge)
				var tread_blend := 1.0-smoothstep(0.35,2.0,remaining)
				p.y = lerpf(paving_height+0.0015,p.y,tread_blend)
				edge[index] = p
		points[index].y = (left[index].y+right[index].y)*0.5
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var floor_faces := PackedVector3Array()
	for index: int in range(points.size()-1):
		var a := left[index]
		var b := right[index]
		var c := left[index+1]
		var d := right[index+1]
		var uv_a := Vector2(distances[index]/2.0,0)
		var uv_b := Vector2(distances[index]/2.0,1)
		var uv_c := Vector2(distances[index+1]/2.0,0)
		var uv_d := Vector2(distances[index+1]/2.0,1)
		var color_a := junction_color(existing_walks,a)
		var color_b := junction_color(existing_walks,b)
		var color_c := junction_color(existing_walks,c)
		var color_d := junction_color(existing_walks,d)
		triangle(surface,a,c,d,uv_a,uv_c,uv_d,PackedColorArray([color_a,color_c,color_d]))
		triangle(surface,a,d,b,uv_a,uv_d,uv_b,PackedColorArray([color_a,color_d,color_b]))
		floor_faces.append_array(PackedVector3Array([a,c,d,a,d,b]))
		skirt(surface,a,c,uv_a,uv_c,existing_walks)
		skirt(surface,d,b,uv_d,uv_b,existing_walks)
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.top_level = true
	visual.mesh = surface.commit()
	visual.material_override = material
	parent.add_child(visual)
	visual.global_transform = Transform3D.IDENTITY
	# A concealed shallow toe joins the current ground collision to the 11.6cm walk.
	var approach := (points[1]-points[0]).normalized()
	approach.y = 0.0
	approach = approach.normalized()
	var low_left := left[0]-approach*2.0
	var low_right := right[0]-approach*2.0
	low_left.y = 0.0
	low_right.y = 0.0
	floor_faces.append_array(PackedVector3Array([low_left,left[0],right[0],low_left,right[0],low_right]))
	var body := StaticBody3D.new()
	body.name = node_name+"_WalkSurface"
	body.top_level = true
	body.collision_layer = 1
	body.add_to_group("midori_walk_surface")
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(floor_faces)
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.global_transform = Transform3D.IDENTITY
	points.push_front((low_left+low_right)*0.5)
	widths.push_front(3.2)
	var bounds := Rect2(Vector2(points[0].x,points[0].z),Vector2.ZERO)
	for p: Vector3 in left+right+[low_left,low_right]:
		bounds = bounds.expand(Vector2(p.x,p.z))
	var footprint := PackedVector2Array([Vector2(low_left.x,low_left.z)])
	for p: Vector3 in left:
		footprint.append(Vector2(p.x,p.z))
	for index: int in range(right.size()-1,-1,-1):
		footprint.append(Vector2(right[index].x,right[index].z))
	footprint.append(Vector2(low_right.x,low_right.z))
	return {"points":points,"widths":widths,"floor":body,"bounds":bounds.grow(0.01),"floor_faces":floor_faces,"footprint":footprint}

static func height_at(spec: Dictionary, p: Vector2) -> float:
	if not (spec.bounds as Rect2).has_point(p):
		return -INF
	var faces: PackedVector3Array = spec.floor_faces
	var result := -INF
	for index: int in range(0,faces.size(),3):
		var a := faces[index]
		var b := faces[index+1]
		var c := faces[index+2]
		var denominator := (b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
		if absf(denominator)<0.000001:
			continue
		var u := ((b.z-c.z)*(p.x-c.x)+(c.x-b.x)*(p.y-c.z))/denominator
		var v := ((c.z-a.z)*(p.x-c.x)+(a.x-c.x)*(p.y-c.z))/denominator
		var w := 1.0-u-v
		if minf(u,minf(v,w)) >= -0.00001:
			result = maxf(result,u*a.y+v*b.y+w*c.y)
	return result

static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, colors: PackedColorArray = PackedColorArray()) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.y < 0.0:
		normal = -normal
	var items: Array = [[a,uv_a],[b,uv_b],[c,uv_c]]
	for index: int in range(3):
		var item: Array = items[index]
		surface.set_normal(normal)
		surface.set_uv(item[1])
		surface.set_color(colors[index] if colors.size() == 3 else Color.WHITE)
		surface.add_vertex(item[0])

static func junction_color(walks: Array[Dictionary], p: Vector3) -> Color:
	# At a fork, the landing's atlas border joins the existing stone surface.
	# Fade over a small edge band rather than drawing a hard black cut across it.
	var point := Vector2(p.x,p.z)
	var overlap := 0.0
	for offset: Vector2 in [Vector2.ZERO,Vector2(0.22,0),Vector2(-0.22,0),Vector2(0,0.22),Vector2(0,-0.22)]:
		if existing_height(walks,point+offset) > 0.0:
			overlap += 1.0
	var keep_trim := 1.0-overlap/5.0
	return Color(keep_trim,1.0,1.0,1.0)

static func skirt(surface: SurfaceTool, a: Vector3, b: Vector3, uv_a: Vector2, uv_b: Vector2, existing_walks: Array[Dictionary]) -> void:
	# Edging ends on the promenade surface at a fork, rather than cutting through it.
	var existing_a := existing_height(existing_walks,Vector2(a.x,a.z))
	var existing_b := existing_height(existing_walks,Vector2(b.x,b.z))
	var low_a := Vector3(a.x,minf(a.y,existing_a),a.z)
	var low_b := Vector3(b.x,minf(b.y,existing_b),b.z)
	if existing_a > 0.0 and existing_b > 0.0 and a.y-existing_a < 0.015 and b.y-existing_b < 0.015:
		return
	if a.distance_to(low_a) < 0.003 and b.distance_to(low_b) < 0.003:
		return
	triangle(surface,a,low_a,low_b,uv_a,uv_a,uv_b)
	triangle(surface,a,low_b,b,uv_a,uv_b,uv_b)

static func collect_existing_walks(park: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node: Node in park.find_children("*", "MeshInstance3D", true, false):
		var visual := node as MeshInstance3D
		var material := visual.get_active_material(0)
		if material == null or not material.resource_name.begins_with("Midori_2050_InlaidWalk"):
			continue
		var faces := PackedVector3Array()
		var arrays := visual.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		var bounds := Rect2(Vector2(visual.global_position.x,visual.global_position.z),Vector2.ZERO)
		for index: int in range(0,count,3):
			var first := indices[index] if not indices.is_empty() else index
			if normals[first].y < 0.5:
				continue
			for corner: int in range(3):
				var vertex := indices[index+corner] if not indices.is_empty() else index+corner
				var p := visual.global_transform*vertices[vertex]
				faces.append(p)
				bounds = bounds.expand(Vector2(p.x,p.z))
		result.append({"bounds":bounds.grow(0.002),"floor_faces":faces})
	return result

static func existing_height(walks: Array[Dictionary], p: Vector2) -> float:
	var height := 0.0
	for walk: Dictionary in walks:
		height = maxf(height,height_at(walk,p))
	return height
