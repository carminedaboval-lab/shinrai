extends Node3D

# Reuse the supplied rock asset. No generated visible meshes or proxy art.
# Coordinates are world metres; the original park/review layout is untouched.
const ANCHORS: Array[Vector3] = [
	Vector3(-44, 0, 141), Vector3(-76, 0, 142), Vector3(-112, 0, 139),
	Vector3(-154, 0, 132), Vector3(-178, 0, 107), Vector3(-186, 0, 62),
	Vector3(-179, 0, 24), Vector3(-128, 0, -136), Vector3(-84, 0, -141),
	Vector3(181, 0, -35), Vector3(185, 0, 27), Vector3(188, 0, 69)]
var placements: Array[Vector3] = []
var rejected := 0

func build(park: Node3D) -> void:
	name = "ExtractionApproachCover"
	var prototype: Node3D = park.MossyBoulderScene.instantiate()
	prototype.transform = Transform3D.IDENTITY
	var info: Dictionary = park._vegetation_visual_bounds(prototype)
	if not info.valid:
		prototype.free()
		return
	var bounds: AABB = info.bounds
	var factor := 4.6 / maxf(bounds.size.x, bounds.size.z)
	var meshes: Array[Node] = prototype.find_children("*", "MeshInstance3D", true, false)
	if prototype is MeshInstance3D:
		meshes.append(prototype)
	# Cache each supplied mesh's exact static collision once, not per instance.
	var collision_shapes: Array[Dictionary] = []
	for mesh_node: MeshInstance3D in meshes:
		if mesh_node.mesh != null:
			collision_shapes.append({"transform": park._vegetation_relative_transform(mesh_node, prototype), "shape": mesh_node.mesh.create_trimesh_shape()})
	for index: int in range(ANCHORS.size()):
		var candidate := _clear_candidate(park, ANCHORS[index])
		if not candidate.valid:
			rejected += 1
			continue
		var cluster := Node3D.new()
		cluster.name = "ApproachBoulders_%02d" % (index + 1)
		add_child(cluster)
		cluster.position = candidate.position
		cluster.rotation.y = deg_to_rad(float(index * 137 % 360))
		cluster.scale = Vector3.ONE * factor
		var offset := Vector3(-bounds.get_center().x, -bounds.position.y - 0.04 / factor, -bounds.get_center().z)
		var visual := prototype.duplicate() as Node3D
		visual.position += offset
		cluster.add_child(visual)
		for spec: Dictionary in collision_shapes:
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.transform = spec.transform
			body.position += offset
			cluster.add_child(body)
			var collision := CollisionShape3D.new()
			collision.shape = spec.shape
			body.add_child(collision)
		placements.append(candidate.position)
	prototype.free()
	print("Extraction approach cover: ", placements.size(), " supplied rock clusters; ", rejected, " anchors rejected for clearance")

func _clear_candidate(park: Node3D, anchor: Vector3) -> Dictionary:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.5
	query.shape = shape
	query.collision_mask = 1
	query.exclude = [park.get_node("ParkScaleReviewPlayer").get_rid()]
	for offset: Vector3 in [Vector3.ZERO, Vector3(-6, 0, 0), Vector3(6, 0, 0), Vector3(0, 0, -6), Vector3(0, 0, 6)]:
		var p := anchor + offset
		# Park reservations use half-scale coordinates. Keep a 2.8m shoulder.
		if not park._is_vegetation_clear(Vector3(p.x / 2.0, 0, p.z / 2.0), 1.4):
			continue
		var near_site := false
		for prop: Node3D in park.find_children("*", "Node3D", true, false):
			if String(prop.name).begins_with("EmeraldHaloLamp_") or "Bench_" in String(prop.name):
				if prop.global_position.distance_to(p) < 9.0:
					near_site = true
					break
		if near_site:
			continue
		query.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 2.8)
		if not park.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			continue
		return {"valid": true, "position": p}
	return {"valid": false}
