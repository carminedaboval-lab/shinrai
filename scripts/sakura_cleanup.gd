extends Node

# Remove the legacy procedural sakura completely.
# The old generator creates a root that contains a child named CherryTrunk.
# New imported sakura assets will not use that marker, so they are unaffected.

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_remove_existing_sakura")


func _on_node_added(node: Node) -> void:
	# Defer one tick so newly generated procedural trees have time to receive
	# their CherryTrunk child before we test and remove the whole tree root.
	call_deferred("_remove_candidate", node)


func _remove_candidate(node: Node) -> void:
	if not is_instance_valid(node):
		return

	var parent: Node = node.get_parent()
	if parent != null and _is_legacy_sakura_root(parent):
		parent.queue_free()
	elif _is_legacy_sakura_root(node):
		node.queue_free()


func _remove_existing_sakura() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null:
		_walk_tree(scene)


func _walk_tree(node: Node) -> void:
	if _is_legacy_sakura_root(node):
		node.queue_free()
		return

	for child: Node in node.get_children():
		if is_instance_valid(child):
			_walk_tree(child)


func _is_legacy_sakura_root(node: Node) -> bool:
	return node.get_node_or_null("CherryTrunk") != null
