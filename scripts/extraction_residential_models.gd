extends RefCounted
## Freeze the existing weapon assemblies into plain world meshes. No viewmodel,
## hands, animation, extra lighting, physics processing or substitute geometry.
const Catalog = preload("./extraction_weapon_catalog.gd")

static func build(weapon_id: String, magazine_only: bool) -> Node3D:
	if not Catalog.available(weapon_id): return null
	var path := "res://assets/uzi/scene.gltf" if weapon_id == "uzi" else str(Catalog.WEAPONS[weapon_id].scene).replace("_viewmodel.tscn", "_weapon.tscn")
	if not ResourceLoader.exists(path): return null
	var packed := load(path) as PackedScene
	if packed == null: return null
	var source := packed.instantiate() as Node3D
	if source == null: return null
	var output := Node3D.new()
	output.name = "Magazine" if magazine_only else "Weapon"
	var magazine: Node = null
	if source.has_meta("magazine_node_path"):
		magazine = source.get_node_or_null(NodePath(str(source.get_meta("magazine_node_path"))))
	if magazine == null:
		for label: String in ["Shigure_Magazine", "Kite_Magazine", "Magazine", "Object_1085"]:
			magazine = source.find_child(label, true, false)
			if magazine != null: break
	if magazine_only and magazine == null:
		source.free(); output.free(); return null
	for node: Node in source.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null: continue
		var in_magazine := magazine != null and (mesh_node == magazine or magazine.is_ancestor_of(mesh_node))
		if in_magazine != magazine_only: continue
		if weapon_id == "uzi" and str(mesh_node.name) not in ["Object_1084", "Object_1085"]: continue
		var copy := MeshInstance3D.new()
		copy.name = mesh_node.name
		if mesh_node.skin == null:
			copy.mesh = mesh_node.mesh
			copy.transform = _relative(mesh_node, source)
		else:
			var skeleton := mesh_node.get_node_or_null(mesh_node.skeleton) as Skeleton3D
			if skeleton == null:
				copy.free(); continue
			copy.mesh = _freeze_skin(mesh_node, skeleton)
			copy.transform = _relative(skeleton, source)
		if copy.mesh == null:
			copy.free(); continue
		copy.material_override = mesh_node.material_override
		for surface in range(copy.mesh.get_surface_count()):
			copy.set_surface_override_material(surface, mesh_node.get_active_material(surface))
		copy.layers = 1
		output.add_child(copy)
	source.free()
	if output.get_child_count() == 0:
		output.free(); return null
	var initial := bounds(output)
	# Lay the thinnest model dimension against the support surface.
	var turn := Basis.IDENTITY
	if initial.size.z <= initial.size.x and initial.size.z < initial.size.y:
		turn = Basis(Vector3.RIGHT, PI * .5)
	elif initial.size.x < initial.size.y:
		turn = Basis(Vector3.FORWARD, PI * .5)
	for child: Node3D in output.get_children(): child.transform = Transform3D(turn, Vector3.ZERO) * child.transform
	var flat := bounds(output)
	var offset := Vector3(-flat.get_center().x, -flat.position.y + .008, -flat.get_center().z)
	for child: Node3D in output.get_children(): child.position += offset
	output.set_meta("residential_model_size", flat.size)
	return output

static func _relative(node: Node3D, root: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != null and parent != root:
		if parent is Node3D: result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result

static func bounds(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null: continue
		var box: AABB = _relative(mesh_node, model) * mesh_node.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

static func _freeze_skin(source: MeshInstance3D, rig: Skeleton3D) -> ArrayMesh:
	# CPU skin freezing also works in headless verification. Imported bind poses
	# retain original units. Empty magazines omit the separately weighted bullets.
	var transforms: Array[Transform3D] = []
	var bullet_binds: Array[bool] = []
	for slot in range(source.skin.get_bind_count()):
		var label := str(source.skin.get_bind_name(slot))
		var bone := rig.find_bone(label) if not label.is_empty() else source.skin.get_bind_bone(slot)
		if bone < 0 or bone >= rig.get_bone_count(): return null
		transforms.append(rig.get_bone_global_rest(bone) * source.skin.get_bind_pose(slot))
		bullet_binds.append(str(rig.get_bone_name(bone)).contains("Bullet"))
	var result := ArrayMesh.new()
	for surface in range(source.mesh.get_surface_count()):
		var arrays: Array = source.mesh.surface_get_arrays(surface).duplicate(true)
		if arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null: return null
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		if vertices.is_empty() or bones.size() != weights.size(): return null
		var influences := int(bones.size() / vertices.size())
		if influences not in [4, 8]: return null
		var keep: Array[bool] = []
		for vertex in range(vertices.size()):
			var point := Vector3.ZERO
			var normal := Vector3.ZERO
			var tangent := Vector3.ZERO
			var bullet_weight := 0.0
			for influence in range(influences):
				var index := vertex * influences + influence
				var slot := bones[index]
				var weight := weights[index]
				if weight <= 0.0: continue
				if slot < 0 or slot >= transforms.size(): return null
				point += (transforms[slot] * vertices[vertex]) * weight
				if not normals.is_empty(): normal += (transforms[slot].basis * normals[vertex]) * weight
				if not tangents.is_empty(): tangent += (transforms[slot].basis * Vector3(tangents[vertex * 4], tangents[vertex * 4 + 1], tangents[vertex * 4 + 2])) * weight
				if bullet_binds[slot]: bullet_weight += weight
			vertices[vertex] = point
			if not normals.is_empty(): normals[vertex] = normal.normalized()
			if not tangents.is_empty():
				tangent = tangent.normalized()
				tangents[vertex * 4] = tangent.x; tangents[vertex * 4 + 1] = tangent.y; tangents[vertex * 4 + 2] = tangent.z
			keep.append(bullet_weight < .5)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for vertex in range(vertices.size()): indices.append(vertex)
		var kept := PackedInt32Array()
		for triangle in range(0, indices.size() - 2, 3):
			if keep[indices[triangle]] and keep[indices[triangle + 1]] and keep[indices[triangle + 2]]:
				kept.append(indices[triangle]); kept.append(indices[triangle + 1]); kept.append(indices[triangle + 2])
		if kept.is_empty(): return null
		# Mesh AABBs include unreferenced vertices; park removed bullet vertices
		# on a retained vertex so they cannot inflate the physical loot footprint.
		var retained_point := vertices[kept[0]]
		for vertex in range(vertices.size()):
			if not keep[vertex]: vertices[vertex] = retained_point
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals if not normals.is_empty() else null
		arrays[Mesh.ARRAY_TANGENT] = tangents if not tangents.is_empty() else null
		arrays[Mesh.ARRAY_BONES] = null; arrays[Mesh.ARRAY_WEIGHTS] = null; arrays[Mesh.ARRAY_INDEX] = kept
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(surface, source.get_active_material(surface))
	return result
