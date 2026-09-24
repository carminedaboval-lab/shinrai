extends Node

# Midori Park lawn surface. This only replaces the flat ground material; it does
# not touch the existing 3D grass blades, sakura, shrubs, paths, or park layout.
# When the Poly Haven PBR maps are present they are tiled at their authored 2 m
# real-world size. The previous procedural material remains as a safe fallback
# while Godot is importing the downloaded images.

const TARGET_SCENE_NAME := "MidoriParkSizeBlockout"
const TARGET_GROUND_NAME := "ParkGround_220x180m"
const TEXTURE_WORLD_SIZE_M := 2.0

const DIFFUSE_PATH := "res://assets/shinrai/parks/midori_park/materials/forrest_ground_01/forrest_ground_01_diff_2k.jpg"
const NORMAL_PATH := "res://assets/shinrai/parks/midori_park/materials/forrest_ground_01/forrest_ground_01_nor_gl_2k.jpg"
const ROUGHNESS_PATH := "res://assets/shinrai/parks/midori_park/materials/forrest_ground_01/forrest_ground_01_rough_2k.jpg"

var _installed := false
var _night_mode := true
var _active_ground_material: ShaderMaterial


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_try_install")


func _on_node_added(_node: Node) -> void:
	if not _installed:
		call_deferred("_try_install")


func _try_install() -> void:
	if _installed:
		return

	var scene := get_tree().current_scene
	if scene == null or String(scene.name) != TARGET_SCENE_NAME:
		return

	var ground := scene.find_child(TARGET_GROUND_NAME, true, false)
	if ground == null:
		return

	var ground_mesh: MeshInstance3D = null
	for child: Node in ground.get_children():
		if child is MeshInstance3D:
			ground_mesh = child as MeshInstance3D
			break
	if ground_mesh == null:
		return

	var material := _build_ground_material()
	ground_mesh.material_override = material
	if material is ShaderMaterial:
		_active_ground_material = material as ShaderMaterial
		_apply_time_factor()
	_installed = true


func set_night_mode(value: bool) -> void:
	_night_mode = value
	_apply_time_factor()


func _apply_time_factor() -> void:
	if _active_ground_material != null:
		_active_ground_material.set_shader_parameter("scene_light_factor", 0.60 if _night_mode else 1.0)


func _build_ground_material() -> Material:
	if (
		ResourceLoader.exists(DIFFUSE_PATH)
		and ResourceLoader.exists(NORMAL_PATH)
		and ResourceLoader.exists(ROUGHNESS_PATH)
	):
		var diffuse := load(DIFFUSE_PATH) as Texture2D
		var normal := load(NORMAL_PATH) as Texture2D
		var roughness := load(ROUGHNESS_PATH) as Texture2D
		if diffuse != null and normal != null and roughness != null:
			return _build_poly_haven_material(diffuse, normal, roughness)

	return _build_procedural_fallback()


func _build_poly_haven_material(diffuse: Texture2D, normal: Texture2D, roughness: Texture2D) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float texture_world_size_m = 2.0;
uniform float scene_light_factor = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 ground_uv = world_pos.xz / texture_world_size_m;
	vec3 ground_color = texture(albedo_tex, ground_uv).rgb;
	float source_roughness = texture(roughness_tex, ground_uv).r;
	vec3 source_normal = texture(normal_tex, ground_uv).rgb;

	// The source scan contains baked daylight. Darken its midtones and reduce
	// specular response before the park's real-time sun and ambient are added.
	ALBEDO = pow(ground_color, vec3(1.20)) * vec3(0.44, 0.60, 0.35) * scene_light_factor;
	ROUGHNESS = clamp(source_roughness * 0.96 + 0.035, 0.70, 1.0);
	SPECULAR = 0.12;
	NORMAL_MAP = source_normal;
	NORMAL_MAP_DEPTH = 0.52;
}
"""

	var material := ShaderMaterial.new()
	material.resource_name = "SHINRAI_Midori_ForestGround01_PBR"
	material.shader = shader
	material.set_shader_parameter("albedo_tex", diffuse)
	material.set_shader_parameter("normal_tex", normal)
	material.set_shader_parameter("roughness_tex", roughness)
	material.set_shader_parameter("texture_world_size_m", TEXTURE_WORLD_SIZE_M)
	return material


func _build_procedural_fallback() -> ShaderMaterial:
	var macro_noise := FastNoiseLite.new()
	macro_noise.seed = 31027
	macro_noise.frequency = 0.018
	macro_noise.fractal_octaves = 5

	var macro_texture := NoiseTexture2D.new()
	macro_texture.width = 512
	macro_texture.height = 512
	macro_texture.seamless = true
	macro_texture.normalize = true
	macro_texture.noise = macro_noise

	var fine_noise := FastNoiseLite.new()
	fine_noise.seed = 88104
	fine_noise.frequency = 0.085
	fine_noise.fractal_octaves = 4

	var fine_texture := NoiseTexture2D.new()
	fine_texture.width = 512
	fine_texture.height = 512
	fine_texture.seamless = true
	fine_texture.normalize = true
	fine_texture.noise = fine_noise

	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform sampler2D macro_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D fine_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float scene_light_factor = 1.0;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float broad = texture(macro_tex, p * 0.018).r;
	float patch = texture(macro_tex, p * 0.072 + vec2(0.37, 0.19)).r;
	float detail = texture(fine_tex, p * 0.42).r;
	float soil = smoothstep(0.53, 0.80, (1.0 - broad) * 0.72 + (1.0 - patch) * 0.28);
	float dry_grass = smoothstep(0.47, 0.74, patch + (1.0 - broad) * 0.22);
	float lush = smoothstep(0.43, 0.72, broad);

	vec3 color = mix(vec3(0.31, 0.43, 0.20), vec3(0.40, 0.51, 0.25), lush * 0.62);
	color = mix(color, vec3(0.48, 0.42, 0.27), dry_grass * 0.38);
	color = mix(color, vec3(0.28, 0.23, 0.15), soil * 0.28);
	color *= mix(0.66, 0.86, detail);
	ALBEDO = color * scene_light_factor;
	ROUGHNESS = clamp(0.84 + soil * 0.10 + (1.0 - detail) * 0.05, 0.80, 0.98);
}
"""

	var material := ShaderMaterial.new()
	material.resource_name = "SHINRAI_Midori_WornGrassGround_Fallback"
	material.shader = shader
	material.set_shader_parameter("macro_tex", macro_texture)
	material.set_shader_parameter("fine_tex", fine_texture)
	return material
