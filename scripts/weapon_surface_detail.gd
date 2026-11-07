extends Node3D

const DETAIL_SHADER = preload("res://scripts/weapon_surface_detail.gdshader")
@export var baked_pbr := false
@export_range(0.0, 1.0) var finish_detail := 0.0

# The imported textures supply colour and wear. These profiles distinguish the
# exposed substrate and its finish, without replacing that authored artwork.
const PROFILES := {
	"steel": {"metallic": 0.92, "roughness": 0.25, "relief": 0.000018, "machining": 0.75, "variation": 0.055},
	"dark_steel": {"metallic": 0.85, "roughness": 0.35, "relief": 0.000022, "machining": 0.55, "variation": 0.065},
	"anodized": {"metallic": 0.72, "roughness": 0.34, "relief": 0.000025, "machining": 0.22, "variation": 0.075},
	"coating": {"metallic": 0.06, "roughness": 0.52, "relief": 0.000035, "machining": 0.08, "variation": 0.070},
	"polymer": {"metallic": 0.0, "roughness": 0.69, "relief": 0.000070, "machining": 0.0, "variation": 0.075},
	"grip": {"metallic": 0.0, "roughness": 0.78, "relief": 0.000090, "machining": 0.0, "variation": 0.065},
	"rubber": {"metallic": 0.0, "roughness": 0.88, "relief": 0.000055, "machining": 0.0, "variation": 0.045},
	"laminate": {"metallic": 0.0, "roughness": 0.51, "relief": 0.000020, "machining": 0.0, "variation": 0.045},
}

const MATERIAL_KIND := {
	"Graphite": "anodized",
	"Steel": "steel",
	"Ceramic": "coating",
	"FieldOlive": "polymer",
	"Rubber": "rubber",
	"MagPolymer": "polymer",
	"T65 pebbled polymer": "grip",
	"T65 satin nitrided steel": "steel",
	"T65 ceramic graphite": "coating",
	"T65 Laminate charcoal brown": "laminate",
	"T65 rubber recoil pad": "rubber",
	"Polished steel contacts": "steel",
	"Parkerised charcoal steel": "dark_steel",
	"Black oxide fasteners": "dark_steel",
	"Faded olive glass-filled polymer": "polymer",
	"Olive moulded grip texture": "grip",
	"Rubber contact pad": "rubber",
	"Warm graphite ceramic coat": "coating",
}

func _ready() -> void:
	var geometry := get_node("Geometry")
	if baked_pbr:
		for mesh: MeshInstance3D in geometry.find_children("*", "MeshInstance3D", true, false):
			apply_baked_materials(mesh)
	else:
		apply(geometry, finish_detail)

static func apply_baked_materials(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	for surface in mesh.mesh.get_surface_count():
		var original := mesh.get_active_material(surface) as BaseMaterial3D
		if original == null or original.has_meta("weapon_surface_finish"):
			continue
		# Preserve authored colour, packed metal/roughness and normal maps.
		var finish := original.duplicate() as BaseMaterial3D
		finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if finish.normal_enabled:
			finish.normal_scale = original.normal_scale * 1.15
		finish.set_meta("weapon_surface_finish", true)
		mesh.set_surface_override_material(surface, finish)

static func apply(geometry: Node, detail: float = 0.0) -> int:
	var changed := 0
	var replacements := {}
	for mesh: MeshInstance3D in geometry.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original == null or not MATERIAL_KIND.has(original.resource_name):
				continue
			var key := original.get_instance_id()
			if not replacements.has(key):
				replacements[key] = _material(original, detail)
			mesh.set_surface_override_material(surface, replacements[key])
			changed += 1
	return changed

static func _material(original: StandardMaterial3D, detail: float) -> ShaderMaterial:
	var profile: Dictionary = PROFILES[MATERIAL_KIND[original.resource_name]]
	var finish := ShaderMaterial.new()
	finish.resource_name = original.resource_name
	finish.shader = DETAIL_SHADER
	finish.set_shader_parameter("albedo_color", original.albedo_color)
	finish.set_shader_parameter("albedo_texture", original.albedo_texture)
	finish.set_shader_parameter("has_albedo_texture", original.albedo_texture != null)
	finish.set_shader_parameter("uv_scale", Vector2(original.uv1_scale.x, original.uv1_scale.y))
	finish.set_shader_parameter("uv_offset", Vector2(original.uv1_offset.x, original.uv1_offset.y))
	finish.set_shader_parameter("finish_detail", detail)
	for parameter: String in profile:
		finish.set_shader_parameter(parameter, profile[parameter])
	return finish
