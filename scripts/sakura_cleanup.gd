extends Node

# Replaces the legacy procedural sakura roots with the licensed Jogoss FBX.
# The old town generator still calls _add_cherry_tree(), which creates a root
# containing CherryTrunk. We use that marker as the exact authored placement,
# preserve its position/scale variation, then swap in the imported model.
#
# The replacement path is loaded dynamically so the project still opens while
# the binary asset is being copied into the repository. If the asset is absent,
# legacy procedural sakura are removed rather than shown.

const SAKURA_SCENE_PATH: String = "res://assets/shinrai/vegetation/sakura/jogoss_sakura_01/Sakura.fbx"
const BARK_ALBEDO_PATH: String = "res://assets/shinrai/vegetation/sakura/jogoss_sakura_01/Bark_Albedo.jpg"
const BARK_NORMAL_PATH: String = "res://assets/shinrai/vegetation/sakura/jogoss_sakura_01/Bark_Normal.png"
const BARK_ROUGHNESS_PATH: String = "res://assets/shinrai/vegetation/sakura/jogoss_sakura_01/Bark_Roughness.png"
const BLOSSOM_RGBA_PATH: String = "res://assets/shinrai/vegetation/sakura/jogoss_sakura_01/Sakura_RGBA.png"

# The source FBX is Maya-centimeter authored and measures about 0.417 m after
# Godot ufbx unit conversion. 10.8x brings the base tree to roughly 4.5 m tall;
# the existing procedural root scale (0.88-1.22 in the featured park) remains
# intact, producing believable 4.0-5.5 m variation without touching town RNG.
const IMPORT_SCALE: float = 10.8
const VISIBILITY_RANGE_M: float = 74.0
const REPLACED_META: StringName = &"shinrai_sakura_replaced"

var _sakura_scene: PackedScene
var _bark_material: StandardMaterial3D
var _blossom_material: StandardMaterial3D


func _ready() -> void:
	_load_sakura_resources()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_replace_existing_sakura")


func _load_sakura_resources() -> void:
	if ResourceLoader.exists(SAKURA_SCENE_PATH):
		_sakura_scene = load(SAKURA_SCENE_PATH) as PackedScene

	var bark_albedo: Texture2D = _load_texture(BARK_ALBEDO_PATH)
	var bark_normal: Texture2D = _load_texture(BARK_NORMAL_PATH)
	var bark_roughness: Texture2D = _load_texture(BARK_ROUGHNESS_PATH)
	var blossom_rgba: Texture2D = _load_texture(BLOSSOM_RGBA_PATH)

	if bark_albedo != null:
		_bark_material = StandardMaterial3D.new()
		_bark_material.resource_name = "SHINRAI_SakuraJogoss_Bark"
		_bark_material.albedo_texture = bark_albedo
		_bark_material.roughness = 0.82
		if bark_roughness != null:
			_bark_material.roughness_texture = bark_roughness
			_bark_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		if bark_normal != null:
			_bark_material.normal_enabled = true
			_bark_material.normal_texture = bark_normal

	if blossom_rgba != null:
		_blossom_material = StandardMaterial3D.new()
		_blossom_material.resource_name = "SHINRAI_SakuraJogoss_Blossom"
		_blossom_material.albedo_texture = blossom_rgba
		_blossom_material.roughness = 0.72
		_blossom_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_blossom_material.alpha_scissor_threshold = 0.42
		_blossom_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _on_node_added(node: Node) -> void:
	# The generator adds the root first and its CherryTrunk immediately after.
	# Defer so the marker exists before evaluating the candidate.
	call_deferred("_replace_candidate", node)


func _replace_candidate(node: Node) -> void:
	if not is_instance_valid(node):
		return

	var parent: Node = node.get_parent()
	if parent != null and _is_legacy_sakura_root(parent):
		_replace_legacy_sakura(parent)
	elif _is_legacy_sakura_root(node):
		_replace_legacy_sakura(node)


func _replace_existing_sakura() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null:
		_walk_tree(scene)


func _walk_tree(node: Node) -> void:
	if _is_legacy_sakura_root(node):
		_replace_legacy_sakura(node)
		return

	for child: Node in node.get_children():
		if is_instance_valid(child):
			_walk_tree(child)


func _is_legacy_sakura_root(node: Node) -> bool:
	return (
		is_instance_valid(node)
		and not node.has_meta(REPLACED_META)
		and node.get_node_or_null("CherryTrunk") != null
	)


func _replace_legacy_sakura(legacy_root: Node) -> void:
	if not is_instance_valid(legacy_root) or legacy_root.has_meta(REPLACED_META):
		return
	legacy_root.set_meta(REPLACED_META, true)

	var parent: Node = legacy_root.get_parent()
	if parent == null:
		legacy_root.queue_free()
		return

	# If the binary asset has not been copied yet, keep the old procedural tree
	# suppressed. Once the asset exists, every authored cherry placement becomes
	# the imported Jogoss tree automatically on the next launch.
	if _sakura_scene == null:
		legacy_root.queue_free()
		return

	var wrapper: Node3D = Node3D.new()
	wrapper.name = "SakuraTree_Jogoss"
	wrapper.add_to_group("shinrai_sakura")
	wrapper.set_meta(&"source_asset", "Jogoss_Sakura_Tree_01")

	if legacy_root is Node3D:
		wrapper.transform = (legacy_root as Node3D).transform

	var old_index: int = legacy_root.get_index()
	parent.add_child(wrapper)
	parent.move_child(wrapper, old_index)

	var imported_tree: Node = _sakura_scene.instantiate()
	wrapper.add_child(imported_tree)
	if imported_tree is Node3D:
		var imported_root: Node3D = imported_tree as Node3D
		imported_root.scale = Vector3.ONE * IMPORT_SCALE
		imported_root.rotation.y = _stable_yaw(wrapper.global_position)

	_configure_imported_tree(imported_tree)
	legacy_root.queue_free()


func _stable_yaw(world_position: Vector3) -> float:
	# Deterministic orientation variety without consuming the town RNG stream.
	var value: float = sin(world_position.x * 12.9898 + world_position.z * 78.233) * 43758.5453
	return fposmod(value, 1.0) * TAU


func _configure_imported_tree(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		mesh_instance.visibility_range_end = VISIBILITY_RANGE_M
		mesh_instance.visibility_range_end_margin = 10.0

		var mesh: Mesh = mesh_instance.mesh
		if mesh != null:
			for surface_index: int in range(mesh.get_surface_count()):
				var source_material: Material = mesh.surface_get_material(surface_index)
				var material_name: String = ""
				if source_material != null:
					material_name = source_material.resource_name.to_lower()

				var is_blossom: bool = (
					material_name.contains("sakura")
					or material_name.contains("blossom")
					or material_name.contains("leaf")
					or (material_name.is_empty() and surface_index > 0)
				)
				var is_bark: bool = material_name.contains("bark") or surface_index == 0

				if is_blossom and _blossom_material != null:
					mesh_instance.set_surface_override_material(surface_index, _blossom_material)
				elif is_bark and _bark_material != null:
					mesh_instance.set_surface_override_material(surface_index, _bark_material)

	for child: Node in node.get_children():
		_configure_imported_tree(child)
