extends Node3D

const SOURCE_SCENE: PackedScene = preload("res://assets/environment/roads/long_paved_walkway/LongPavedWalkway_GameReady_GodotYUp_1K.glb")

@onready var pavers: MeshInstance3D = $Pavers

func _ready() -> void:
	var source_root: Node = SOURCE_SCENE.instantiate()
	if source_root == null:
		push_error("SpawnRoadPavers: could not instantiate the source walkway GLB")
		return

	var source_material: BaseMaterial3D = _find_paving_material(source_root)
	if source_material == null or source_material.albedo_texture == null:
		source_root.free()
		push_error("SpawnRoadPavers: could not find the original textured_0 paving material")
		return

	var shader_material: ShaderMaterial = pavers.material_override as ShaderMaterial
	if shader_material == null:
		source_root.free()
		push_error("SpawnRoadPavers: overlay material is not a ShaderMaterial")
		return

	shader_material = shader_material.duplicate() as ShaderMaterial
	pavers.material_override = shader_material
	shader_material.set_shader_parameter("source_albedo", source_material.albedo_texture)
	shader_material.set_shader_parameter("roughness_value", source_material.roughness)

	if source_material.normal_texture != null:
		shader_material.set_shader_parameter("source_normal", source_material.normal_texture)
		shader_material.set_shader_parameter("use_source_normal", true)

	source_root.free()

func _find_paving_material(root: Node) -> BaseMaterial3D:
	var materials: Array[BaseMaterial3D] = []
	_collect_materials(root, materials)

	for material: BaseMaterial3D in materials:
		if material.resource_name == "textured_0":
			return material

	for material: BaseMaterial3D in materials:
		if material.albedo_texture != null and not material.resource_name.contains(".001"):
			return material

	for material: BaseMaterial3D in materials:
		if material.albedo_texture != null:
			return material

	return null

func _collect_materials(node: Node, output: Array[BaseMaterial3D]) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
				var material: Material = mesh_instance.get_surface_override_material(surface_index)
				if material == null:
					material = mesh_instance.mesh.surface_get_material(surface_index)
				if material is BaseMaterial3D:
					var base_material: BaseMaterial3D = material as BaseMaterial3D
					if not output.has(base_material):
						output.append(base_material)

	for child: Node in node.get_children():
		_collect_materials(child, output)
