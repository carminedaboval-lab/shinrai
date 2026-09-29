extends Node

const SakuraScene: PackedScene = preload("res://assets/shinrai/vegetation/sakura/jogoss_sakura_01/Sakura.fbx")
const BlossomTexture: Texture2D = preload("res://assets/shinrai/vegetation/sakura/jogoss_sakura_01/Sakura_RGBA.png")
const IMPORT_SCALE := 15.0
const VISIBILITY_RANGE_M := 150.0
const REPLACED_META: StringName = &"midori_jogoss_sakura"

# Keep the added blossom clusters close to the canopy so they read as branch-tip
# flowers instead of detached floating clumps.
const EXTRA_BLOSSOM_CARD_SIZE := 0.014
const EXTRA_BLOSSOM_TIPS := [
	Vector3(0.000, 0.335, 0.000),
	Vector3(0.095, 0.315, 0.030),
	Vector3(-0.095, 0.315, -0.020),
	Vector3(0.150, 0.290, 0.045),
	Vector3(-0.150, 0.290, 0.040),
	Vector3(0.120, 0.285, -0.095),
	Vector3(-0.120, 0.285, -0.095),
	Vector3(0.050, 0.305, 0.135),
	Vector3(-0.055, 0.305, 0.135),
	Vector3(0.015, 0.280, -0.150),
]

# A small looping GPU particle system handles the intentionally detached petals.
# Each petal falls from the canopy, fades near ground level, expires, and is
# automatically emitted again by GPUParticles3D.
const FALLING_PETAL_AMOUNT := 12
const FALLING_PETAL_LIFETIME := 5.0
const FALLING_PETAL_CARD_SIZE := Vector2(0.0045, 0.0065)

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
	_add_falling_petals(new_tree)
	_configure_visibility(new_tree)
	old_tree.queue_free()

func _make_blossom_material(resource_name_value: String) -> StandardMaterial3D:
	var blossom_material := StandardMaterial3D.new()
	blossom_material.resource_name = resource_name_value
	blossom_material.albedo_texture = BlossomTexture
	blossom_material.roughness = 0.72
	blossom_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	blossom_material.alpha_scissor_threshold = 0.42
	blossom_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	blossom_material.vertex_color_use_as_albedo = true
	return blossom_material

func _add_tip_blossoms(tree_root: Node3D) -> void:
	var blossom_material := _make_blossom_material("SHINRAI_Midori_ExtraTipBlossoms")

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
	blossom_cards.name = "AttachedBranchTipBlossoms"
	blossom_cards.multimesh = multimesh
	blossom_cards.visibility_range_end = VISIBILITY_RANGE_M
	tree_root.add_child(blossom_cards)

func _add_falling_petals(tree_root: Node3D) -> void:
	var petal_material := _make_blossom_material("SHINRAI_Midori_FallingPetals")

	var petal_mesh := QuadMesh.new()
	petal_mesh.size = FALLING_PETAL_CARD_SIZE
	petal_mesh.material = petal_material

	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = Vector3(0.18, 0.025, 0.18)
	particle_material.direction = Vector3(0.10, -1.0, 0.05)
	particle_material.spread = 32.0
	particle_material.initial_velocity_min = 0.018
	particle_material.initial_velocity_max = 0.040
	particle_material.gravity = Vector3(0.0045, -0.014, 0.0025)
	particle_material.angular_velocity_min = -1.8
	particle_material.angular_velocity_max = 1.8
	particle_material.scale_min = 0.72
	particle_material.scale_max = 1.15

	# Fade in quickly, stay visible through the fall, then fade out near the
	# ground before the particle lifetime resets it back into the canopy.
	var fade_gradient := Gradient.new()
	fade_gradient.offsets = PackedFloat32Array([0.0, 0.08, 0.78, 1.0])
	fade_gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.92),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade_gradient
	particle_material.color_ramp = fade_texture

	var petals := GPUParticles3D.new()
	petals.name = "LoopingFallingSakuraPetals"
	petals.position = Vector3(0.0, 0.315, 0.0)
	petals.amount = FALLING_PETAL_AMOUNT
	petals.lifetime = FALLING_PETAL_LIFETIME
	petals.randomness = 0.65
	petals.preprocess = 4.0
	petals.one_shot = false
	petals.emitting = true
	petals.local_coords = true
	petals.process_material = particle_material
	petals.draw_pass_1 = petal_mesh
	petals.visibility_aabb = AABB(Vector3(-0.35, -0.38, -0.35), Vector3(0.70, 0.72, 0.70))
	petals.visibility_range_end = VISIBILITY_RANGE_M
	tree_root.add_child(petals)

func _configure_visibility(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).visibility_range_end = VISIBILITY_RANGE_M
	for child: Node in node.get_children():
		_configure_visibility(child)
