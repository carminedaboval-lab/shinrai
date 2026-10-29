extends Node

# Keep physical floors and rail bodies active when changing artwork detail.
const ENTER_DISTANCE := 55.0
const LEAVE_DISTANCE := 65.0
var detailed: Node3D
var distant: Node3D
var world_bounds := AABB()
var using_detail := true

func configure(full_art: Node3D, far_art: Node3D) -> void:
	detailed = full_art
	distant = far_art
	var found := false
	for node: Node in detailed.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var bounds: AABB = mesh_node.global_transform * mesh_node.get_aabb()
		world_bounds = bounds if not found else world_bounds.merge(bounds)
		found = true
	assert(found, "Bridge detail switching requires actual artwork bounds")
	distant.hide()

func distance_to_span(observer: Vector3) -> float:
	# The entrance can be 72 metres from the pivot while still underfoot.
	var nearest := Vector2(
		clampf(observer.x, world_bounds.position.x, world_bounds.end.x),
		clampf(observer.z, world_bounds.position.z, world_bounds.end.z))
	return Vector2(observer.x, observer.z).distance_to(nearest)

func update_for_observer(observer: Vector3) -> void:
	var distance := distance_to_span(observer)
	if using_detail and distance > LEAVE_DISTANCE:
		using_detail = false
	elif not using_detail and distance < ENTER_DISTANCE:
		using_detail = true
	detailed.visible = using_detail
	distant.visible = not using_detail

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if is_instance_valid(camera):
		update_for_observer(camera.global_position)
