extends Node

# Keep procedural sakura trees as bare woody structures only.
# The current cherry-tree generator names the retained geometry CherryTrunk
# and CherryBranch*. Everything else directly under that tree root is removed.

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_clean_existing_sakura")


func _on_node_added(node: Node) -> void:
	# Defer one tick so a newly created cherry root has time to receive its trunk.
	call_deferred("_clean_candidate", node)


func _clean_candidate(node: Node) -> void:
	if not is_instance_valid(node):
		return

	var parent: Node = node.get_parent()
	if parent != null and _is_sakura_root(parent):
		_clean_sakura_root(parent)
	elif _is_sakura_root(node):
		_clean_sakura_root(node)


func _clean_existing_sakura() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null:
		_walk_tree(scene)


func _walk_tree(node: Node) -> void:
	if _is_sakura_root(node):
		_clean_sakura_root(node)

	# Duplicate the list because cleanup can queue children for deletion.
	for child: Node in node.get_children():
		if is_instance_valid(child):
			_walk_tree(child)


func _is_sakura_root(node: Node) -> bool:
	return node.get_node_or_null("CherryTrunk") != null


func _clean_sakura_root(root: Node) -> void:
	for child: Node in root.get_children():
		var child_name: String = String(child.name)
		if child_name == "CherryTrunk" or child_name.begins_with("CherryBranch"):
			continue

		# Removes blossom/leaf meshes and any other detached fragment from sakura.
		child.queue_free()
