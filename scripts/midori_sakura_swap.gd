extends Node

const SakuraScene: PackedScene = preload("res://assets/shinrai/vegetation/sakura/jogoss_sakura_01/Sakura.fbx")
const IMPORT_SCALE := 10.8
const VISIBILITY_RANGE_M := 150.0
const REPLACED_META: StringName = &"midori_jogoss_sakura"

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_replace_existing")

func _on_node_added(node: Node) -> void:
	if _is_old_midori_sakura(node):
		call_deferred("_replace_tree", node)

func _replace_existing() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		_walk(scene)

func _walk(node: Node) -> void:
	if _is_old_midori_sakura(node):
		_replace_tree(node)
		return
	for child: Node in node.get_children():
		if is_instance_valid(child):
			_walk(child)

func _is_old_midori_sakura(node: Node) -> bool:
	return (
		is_instance_valid(node)
		and node is Node3D
		and String(node.name).begins_with("DenseSakura_")
		and not node.has_meta(REPLACED_META)
	)

func _replace_tree(old_tree: Node) -> void:
	if not _is_old_midori_sakura(old_tree):
		return
	var parent := old_tree.get_parent()
	if parent == null:
		return

	var old_3d := old_tree as Node3D
	var new_tree := SakuraScene.instantiate() as Node3D
	if new_tree == null:
		return

	new_tree.name = old_tree.name
	new_tree.transform = old_3d.transform
	new_tree.scale = old_3d.scale * IMPORT_SCALE
	new_tree.set_meta(REPLACED_META, true)

	var old_index := old_tree.get_index()
	parent.add_child(new_tree)
	parent.move_child(new_tree, old_index)
	_configure_visibility(new_tree)
	old_tree.queue_free()

func _configure_visibility(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).visibility_range_end = VISIBILITY_RANGE_M
	for child: Node in node.get_children():
		_configure_visibility(child)
