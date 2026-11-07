extends Node3D

const FINISH_SHADER = preload("res://scripts/r56_surface_finish.gdshader")
const CHANNELS: Array[Vector4] = [
	Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0),
	Vector4(0, 0, 0, 1), Vector4(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0, 0),
]

# Peak-to-peak relief in metres, grain cells/metre, roughness range and grain
# directionality. PBR colour/metallic/roughness remain the imported v2 palette.
const FINISHES := {
	"R56 receiver alloy": {"relief_m": 0.000003, "grain_frequency": 1100.0, "roughness_range": 0.026, "directionality": 0.35},
	"R56 handguard alloy": {"relief_m": 0.000003, "grain_frequency": 1000.0, "roughness_range": 0.026, "directionality": 0.25},
	"R56 lower coating": {"relief_m": 0.000003, "grain_frequency": 1100.0, "roughness_range": 0.022, "directionality": 0.10},
	"R56 black anodized": {"relief_m": 0.000003, "grain_frequency": 1200.0, "roughness_range": 0.023, "directionality": 0.35},
	"R56 black oxide": {"relief_m": 0.000004, "grain_frequency": 1000.0, "roughness_range": 0.026, "directionality": 0.15},
	"R56 exposed steel": {"relief_m": 0.000002, "grain_frequency": 1500.0, "roughness_range": 0.018, "directionality": 0.60},
	"R56 sight oxide": {"relief_m": 0.000002, "grain_frequency": 1100.0, "roughness_range": 0.018, "directionality": 0.15},
	"R56 inset anodized": {"relief_m": 0.000003, "grain_frequency": 1200.0, "roughness_range": 0.022, "directionality": 0.35},
	"R56 stock polymer": {"relief_m": 0.000010, "grain_frequency": 1250.0, "roughness_range": 0.026, "directionality": 0.0},
	"R56 grip polymer": {"relief_m": 0.000012, "grain_frequency": 1000.0, "roughness_range": 0.030, "directionality": 0.0},
	"R56 magazine polymer": {"relief_m": 0.000010, "grain_frequency": 1250.0, "roughness_range": 0.028, "directionality": 0.0},
	"R56 stock rubber": {"relief_m": 0.000008, "grain_frequency": 1500.0, "roughness_range": 0.018, "directionality": 0.0},
}


func _ready() -> void:
	var geometry := get_node_or_null("Geometry")
	if geometry != null:
		apply(geometry)


static func apply(geometry: Node) -> int:
	var changed := 0
	var replacements := {}
	for mesh: MeshInstance3D in geometry.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original == null or not FINISHES.has(original.resource_name) or not _compatible(original):
				continue
			var key := original.get_instance_id()
			if not replacements.has(key):
				replacements[key] = _material(original)
			mesh.set_surface_override_material(surface, replacements[key])
			changed += 1
	return changed


static func _compatible(original: StandardMaterial3D) -> bool:
	# Current R56 materials are opaque/double-sided and have no authored maps.
	# Preserve a future complex authored finish intact instead of dropping it.
	if original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or original.cull_mode != BaseMaterial3D.CULL_DISABLED:
		return false
	if original.next_pass != null or original.uv1_triplanar or original.vertex_color_use_as_albedo:
		return false
	if original.emission_enabled or original.detail_enabled or original.clearcoat_enabled or original.anisotropy_enabled or original.heightmap_enabled:
		return false
	if (original.normal_enabled and original.normal_texture != null) or (original.ao_enabled and original.ao_texture != null):
		return false
	if not original.texture_repeat and (original.albedo_texture != null or original.metallic_texture != null or original.roughness_texture != null):
		return false
	return original.metallic_texture_channel >= 0 and original.metallic_texture_channel < CHANNELS.size() and original.roughness_texture_channel >= 0 and original.roughness_texture_channel < CHANNELS.size()


static func _material(original: StandardMaterial3D) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = FINISH_SHADER
	result.resource_name = original.resource_name
	result.render_priority = original.render_priority
	result.set_meta("r56_surface_finish", true)
	result.set_meta("source_material", original)
	result.set_shader_parameter("source_albedo", original.albedo_color)
	result.set_shader_parameter("source_metallic", original.metallic)
	result.set_shader_parameter("source_roughness", original.roughness)
	result.set_shader_parameter("source_specular", original.metallic_specular)
	result.set_shader_parameter("uv_scale", Vector2(original.uv1_scale.x, original.uv1_scale.y))
	result.set_shader_parameter("uv_offset", Vector2(original.uv1_offset.x, original.uv1_offset.y))
	result.set_shader_parameter("albedo_texture", original.albedo_texture)
	result.set_shader_parameter("metallic_texture", original.metallic_texture)
	result.set_shader_parameter("roughness_texture", original.roughness_texture)
	result.set_shader_parameter("has_albedo_texture", original.albedo_texture != null)
	result.set_shader_parameter("has_metallic_texture", original.metallic_texture != null)
	result.set_shader_parameter("has_roughness_texture", original.roughness_texture != null)
	result.set_shader_parameter("metallic_channel", CHANNELS[original.metallic_texture_channel])
	result.set_shader_parameter("roughness_channel", CHANNELS[original.roughness_texture_channel])
	for parameter: String in FINISHES[original.resource_name]:
		result.set_shader_parameter(parameter, FINISHES[original.resource_name][parameter])
	return result
