extends Node

const SakuraScene: PackedScene = preload("res://assets/shinrai/vegetation/sakura/jogoss_sakura_01/Sakura.fbx")
const BlossomTexture: Texture2D = preload("res://assets/shinrai/vegetation/sakura/jogoss_sakura_01/Sakura_RGBA.png")
const IMPORT_SCALE := 15.0
const VISIBILITY_RANGE_M := 150.0
const REPLACED_META: StringName = &"midori_jogoss_sakura"
const EXTRA_BLOSSOM_CARD_SIZE := 0.016
const EXTRA_BLOSSOM_TIPS := [
	Vector3(0.00, 0.395, 0.00),
	Vector3(0.105, 0.365, 0.035),
	Vector3(-0.105, 0.365, -0.025),
	Vector3(0.185, 0.325, 0.060),
	Vector3(-0.185, 0.325, 0.050),
	Vector3(0.155, 0.310, -0.120),
	Vector3(-0.150, 0.310, -0.125),
	Vector3(0.060, 0.345, 0.175),
	Vector3(-0.065, 0.345, 0.175),
	Vector3(0.225, 0.285, -0.015),
	Vector3(-0.225, 0.285, 0.005),
	Vector3(0.125, 0.275, 0.205),
	Vector3(-0.125, 0.275, 0.205),
	Vector3(0.020, 0.300, -0.220),
]

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
	_add_tip_blossoms(new_tree)
	_configure_visibility(new_tree)
	old_tree.queue_free()

func _add_tip_blossoms(tree_root: Node3D) -> void:
	var blossom_material := StandardMaterial3D.new()
	blossom_material.resource_name = "SHINRAI_Midori_ExtraTipBlossoms"
	blossom_material.albedo_texture = BlossomTexture
	blossom_material.roughness = 0.72
	blossom_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	blossom_material.alpha_scissor_threshold = 0.42
	blossom_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var card_mesh := QuadMesh.new()
	card_mesh.size = Vector2(EXTRA_BLOSSOM_CARD_SIZE, EXTRA_BLOSSOM_CARD_SIZE)
	card_mesh.material = blossom_material

	var cards_per_tip := 3
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = card_mesh
	multimesh.instance_count = EXTRA_BLOSSOM_TIPS.size() * cards_per_tip

	var card_index := 0
	for tip_index: int in range(EXTRA_BLOSSOM_TIPS.size()):
		var tip_position: Vector3 = EXTRA_BLOSSOM_TIPS[tip_index]
		var size_variation := 0.88 + float(tip_index % 4) * 0.07
		for card_variant: int in range(cards_per_tip):
			var basis := Basis.IDENTITY
			if card_variant == 0:
				basis = Basis.from_euler(Vector3(0.0, deg_to_rad(float(tip_index) * 23.0), 0.0))
			elif card_variant == 1:
				basis = Basis.from_euler(Vector3(0.0, deg_to_rad(60.0 + float(tip_index) * 17.0), 0.0))
			else:
				basis = Basis.from_euler(Vector3(deg_to_rad(55.0), deg_to_rad(30.0 + float(tip_index) * 19.0), 0.0))
			basis = basis.scaled(Vector3.ONE * size_variation)
			multimesh.set_instance_transform(card_index, Transform3D(basis, tip_position))
			card_index += 1

	var blossom_cards := MultiMeshInstance3D.new()
	blossom_cards.name = "ExtraBranchTipBlossoms"
	blossom_cards.multimesh = multimesh
	blossom_cards.visibility_range_end = VISIBILITY_RANGE_M
	tree_root.add_child(blossom_cards)

func _configure_visibility(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).visibility_range_end = VISIBILITY_RANGE_M
	for child: Node in node.get_children():
		_configure_visibility(child)
