extends RefCounted
## Shared fitted core volume from the existing mesh's rigid Body vertices.
## Locomotion clearance and limb damage volumes remain separate.
static var core_shape: ConvexPolygonShape3D
static var core_rest_transform := Transform3D.IDENTITY

static func from_visual(visual: Node3D) -> ConvexPolygonShape3D:
	if core_shape != null: return core_shape
	var skeleton: Skeleton3D = visual.get("skeleton")
	var body_id: int = skeleton.find_bone("Body")
	var points := PackedVector3Array()
	for node: Node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		var mesh: Mesh = mesh_node.mesh
		var skin: Skin = mesh_node.skin
		if mesh == null or skin == null: continue
		var body_binds: Array[int] = []
		for bind: int in skin.get_bind_count():
			var bind_name: StringName = skin.get_bind_name(bind)
			if bind_name == &"Body" or (bind_name.is_empty() and skin.get_bind_bone(bind) == body_id):
				body_binds.append(bind)
		if body_binds.is_empty(): continue
		var to_skeleton: Transform3D = skeleton.global_transform.affine_inverse() * mesh_node.global_transform
		for surface: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or bones.is_empty(): continue
			var stride: int = bones.size() / vertices.size()
			for index: int in vertices.size():
				var body_weight := 0.0
				for slot: int in stride:
					var offset: int = index * stride + slot
					if bones[offset] in body_binds: body_weight += weights[offset]
				if body_weight >= .99999: points.append(to_skeleton * vertices[index])
	if points.size() < 4:
		push_error("Police drone core has no rigid Body geometry")
		return null
	var bounds := AABB(points[0],Vector3.ZERO)
	for point: Vector3 in points: bounds=bounds.expand(point)
	core_rest_transform.origin=bounds.get_center()
	for index: int in points.size(): points[index]-=core_rest_transform.origin
	core_shape = ConvexPolygonShape3D.new()
	core_shape.points = points
	return core_shape
