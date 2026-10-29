extends SkeletonModifier3D
var viewmodel: Node3D

func _process_modification_with_delta(_delta: float) -> void:
	if is_instance_valid(viewmodel):
		viewmodel.update_supplied_pose(get_skeleton(),_delta)
