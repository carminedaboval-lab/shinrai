extends Node

# Adds the worn grass/soil base material to Midori Park without touching the
# existing 3D grass detail system. This is a lightweight procedural fallback
# that gives the lawn the same kind of green/brown variation as the planned
# Grass Ground material while keeping the blade scatter unchanged.

const TARGET_SCENE_NAME := "MidoriParkSizeBlockout"
const TARGET_GROUND_NAME := "ParkGround_220x180m"

var _installed := false


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

	ground_mesh.material_override = _build_ground_material()
	_installed = true


func _build_ground_material() -> ShaderMaterial:
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

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;

	float broad = texture(macro_tex, p * 0.018).r;
	float patch = texture(macro_tex, p * 0.072 + vec2(0.37, 0.19)).r;
	float detail = texture(fine_tex, p * 0.42).r;
	float micro = texture(fine_tex, p * 0.95 + vec2(0.51, 0.73)).r;

	float soil = smoothstep(0.53, 0.80, (1.0 - broad) * 0.72 + (1.0 - patch) * 0.28);
	float dry_grass = smoothstep(0.47, 0.74, patch + (1.0 - broad) * 0.22);
	float lush = smoothstep(0.43, 0.72, broad);

	vec3 base_green = vec3(0.31, 0.43, 0.20);
	vec3 fresh_green = vec3(0.40, 0.51, 0.25);
	vec3 dry_tan = vec3(0.48, 0.42, 0.27);
	vec3 exposed_soil = vec3(0.28, 0.23, 0.15);

	vec3 color = mix(base_green, fresh_green, lush * 0.62);
	color = mix(color, dry_tan, dry_grass * 0.38);
	color = mix(color, exposed_soil, soil * 0.28);
	color *= mix(0.90, 1.11, detail);
	color *= mix(0.96, 1.04, micro);

	ALBEDO = color;
	ROUGHNESS = clamp(0.84 + soil * 0.10 + (1.0 - detail) * 0.05, 0.80, 0.98);
}
"""

	var material := ShaderMaterial.new()
	material.resource_name = "SHINRAI_Midori_WornGrassGround"
	material.shader = shader
	material.set_shader_parameter("macro_tex", macro_texture)
	material.set_shader_parameter("fine_tex", fine_texture)
	return material
