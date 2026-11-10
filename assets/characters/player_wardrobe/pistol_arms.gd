extends RefCounted

## Replace only the visible arm surfaces. The weapon keeps ownership of the rig and its animations.
static func attach(model_root: Node3D, wardrobe: PackedScene) -> bool:
	var pieces := wardrobe.instantiate() as Node3D
	if pieces == null:
		return false
	var rigs := model_root.find_children("*", "Skeleton3D", true, false)
	var target := rigs.front() as Skeleton3D if not rigs.is_empty() else null
	var glove := model_root.find_child("Object_13", true, false) as MeshInstance3D
	var arms := pieces.find_child("BareArms", true, false) as MeshInstance3D
	var sleeves := pieces.find_child("ShortSleeves", true, false) as MeshInstance3D
	if target == null or glove == null or arms == null or sleeves == null:
		pieces.free()
		return false
	for part: MeshInstance3D in [arms, sleeves]:
		if part.mesh == null or part.skin == null or part.skin.get_bind_count() == 0:
			pieces.free()
			return false
		for bind in part.skin.get_bind_count():
			if target.find_bone(part.skin.get_bind_name(bind)) == -1:
				pieces.free()
				return false
	for part: MeshInstance3D in [arms, sleeves]:
		# The wardrobe GLB is imported with named skins and both meshes directly under its rig.
		part.owner = null
		part.reparent(target, false)
		part.skeleton = NodePath("..")
		part.layers = glove.layers
		part.cast_shadow = glove.cast_shadow
		part.extra_cull_margin = glove.extra_cull_margin
	for part_name: String in ["Object_9", "Object_10", "Object_11", "Object_12", "Object_13"]:
		var old := model_root.find_child(part_name, true, false) as MeshInstance3D
		if old != null:
			old.hide()
	pieces.free()
	return true

