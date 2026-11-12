extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")
const StartupTrace = preload("res://scripts/startup_trace.gd")

# Runtime-only surface overrides on the supplied small grass clumps. The mesh,
# imported material, textures, collision and object transforms are not edited.
# Godot 4.7.2 does not expose BaseMaterial3D.get_shader_rid to scripts, so this
# deliberately supports only the common PBR properties verified in these assets.
const TARGET_ROOTS := ["WatersideVegetation_36Reed_9DenseGrass", "MainlandMeadowTransitions", "MainlandEmeraldGrassClusters"]
const SUPPORTED_PROPERTIES := [
	"resource_name", "resource_local_to_scene", "render_priority", "transparency",
	"alpha_scissor_threshold", "alpha_hash_scale", "alpha_antialiasing_mode", "alpha_antialiasing_edge", "cull_mode", "albedo_color", "albedo_texture",
	"metallic", "metallic_specular", "metallic_texture", "metallic_texture_channel",
	"roughness", "roughness_texture", "roughness_texture_channel",
	"normal_enabled", "normal_scale", "normal_texture", "ao_enabled", "ao_light_affect", "ao_texture", "ao_texture_channel",
	"backlight_enabled", "backlight", "backlight_texture",
	"uv1_scale", "uv1_offset", "texture_filter", "texture_repeat",
]

@export_range(0.0, 1.0, 0.01) var motion_amount := 1.0:
	set(value):
		motion_amount = clampf(value, 0.0, 1.0)
		for material: ShaderMaterial in _material_cache.values():
			material.set_shader_parameter("motion_amount", motion_amount)
@export_range(0.0, 0.04, 0.001) var tip_displacement_m := 0.03
@export var include_emerald_clumps := true

var installed := false
var report: Dictionary = {}
var _material_cache: Dictionary = {}
var _shader_cache: Dictionary = {}
var _default_material := StandardMaterial3D.new()

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	call_deferred("install")

func install() -> void:
	if installed or get_parent() == null:
		return
	installed = true
	var _bt := StartupTrace.begin()
	report = {"target_roots": 0, "meshes": 0, "changed_surfaces": 0, "skipped_surfaces": 0, "unique_materials": 0, "skip_reasons": {}, "max_world_displacement_m": clampf(tip_displacement_m, 0.0, 0.04)}
	for root_name: String in TARGET_ROOTS:
		if root_name == "MainlandEmeraldGrassClusters" and not include_emerald_clumps:
			continue
		for target: Node in get_parent().find_children(root_name, "Node3D", true, false):
			report.target_roots += 1
			var meshes := target.find_children("*", "MeshInstance3D", true, false)
			for index: int in range(meshes.size()):
				# Same meshes in the same order; the loading budget only splits frames.
				if index % 8 == 7: await LoadingBudget.checkpoint(get_parent())
				if is_instance_valid(meshes[index]): _configure_mesh(meshes[index] as MeshInstance3D)
			await LoadingBudget.checkpoint(get_parent())
	report.unique_materials = _material_cache.size()
	StartupTrace.finish("breeze.install", _bt)
	print("MIDORI_BREEZE: ", JSON.stringify(report))

## End-of-boot hook (shinrai_world_complete.gd). The shader-code cache only
## serves install() (its Shaders live on in the materials); the material cache
## stays: the motion_amount setter updates the live materials through it.
func release_build_data() -> Dictionary:
	if not installed: return {"skipped": "not installed"}
	var freed := {"shader_codes": _shader_cache.size()}
	_shader_cache = {}
	return freed

func _skip(reason: String, count := 1) -> void:
	report.skipped_surfaces += count
	report.skip_reasons[reason] = int(report.skip_reasons.get(reason, 0)) + count

func _configure_mesh(visual: MeshInstance3D) -> void:
	if visual.mesh == null:
		return
	var surfaces := visual.mesh.get_surface_count()
	if visual.skin != null or visual.mesh.get_blend_shape_count() > 0 or visual.material_overlay != null:
		_skip("skinned, blendshape or overlay mesh", surfaces)
		return
	# Supplied clumps are upright. Skip tilted/singular meshes rather than bending
	# along a wrong root axis or magnifying displacement through a degenerate basis.
	var basis := visual.global_basis
	if absf(basis.determinant()) < 0.0000001 or basis.y.normalized().dot(Vector3.UP) < 0.999:
		_skip("non-upright or singular transform", surfaces)
		return
	var bounds := visual.mesh.get_aabb()
	if bounds.size.y <= 0.0001:
		_skip("no vertical extent", surfaces)
		return
	var changed := 0
	if visual.material_override != null:
		var replacement := _build_material(visual.material_override)
		if replacement != null:
			visual.material_override = replacement
			changed = surfaces
		else:
			_skip("unsupported whole-mesh material", surfaces)
	else:
		for surface: int in range(surfaces):
			var replacement := _build_material(visual.get_active_material(surface))
			if replacement == null:
				_skip("unsupported surface material")
				continue
			visual.set_surface_override_material(surface, replacement)
			changed += 1
	if changed > 0:
		visual.set_instance_shader_parameter("breeze_bounds", Vector4(bounds.position.y, bounds.size.y, clampf(tip_displacement_m, 0.0, 0.04), 0.0))
		visual.extra_cull_margin = maxf(visual.extra_cull_margin, 0.04)
		report.meshes += 1
		report.changed_surfaces += changed

func _supported(source: StandardMaterial3D) -> bool:
	if source.next_pass != null or source.albedo_texture == null:
		return false
	if source.transparency not in [BaseMaterial3D.TRANSPARENCY_DISABLED, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH]:
		return false
	# Fail closed if a future asset uses another non-default material feature.
	for property: Dictionary in source.get_property_list():
		var key := String(property.name)
		if (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0 or key.begins_with("metadata/") or key in SUPPORTED_PROPERTIES:
			continue
		if source.get(key) != _default_material.get(key):
			return false
	return true

func _build_material(source: Material) -> ShaderMaterial:
	# A cached source already passed _supported (materials do not change here):
	# skip re-walking its whole property list for every mesh that shares it.
	if _material_cache.has(source):
		return _material_cache[source] as ShaderMaterial
	if not source is StandardMaterial3D or not _supported(source as StandardMaterial3D):
		return null
	var original := source as StandardMaterial3D
	# Materials whose generated code is identical share one Shader: each new
	# Shader compiled its code again (~0.1 s apiece, a ~0.75 s frame per eight
	# meshes behind the menu). Same code, same uniforms, own material each.
	var code := _shader_code(original)
	var shader: Shader = _shader_cache.get(code)
	if shader == null:
		shader = Shader.new()
		shader.code = code
		_shader_cache[code] = shader
	var material := ShaderMaterial.new()
	material.resource_name = original.resource_name + "_RootedBreeze"
	material.render_priority = original.render_priority
	material.shader = shader
	for key: String in ["albedo_color", "albedo_texture", "metallic", "metallic_specular", "metallic_texture", "roughness", "roughness_texture", "normal_scale", "normal_texture", "ao_light_affect", "ao_texture", "backlight", "backlight_texture", "alpha_scissor_threshold", "alpha_hash_scale", "uv1_scale", "uv1_offset"]:
		material.set_shader_parameter(key, original.get(key))
	material.set_shader_parameter("metallic_channel", _channel(original.metallic_texture_channel))
	material.set_shader_parameter("roughness_channel", _channel(original.roughness_texture_channel))
	material.set_shader_parameter("ao_channel", _channel(original.ao_texture_channel))
	material.set_shader_parameter("motion_amount", motion_amount)
	material.set_meta("midori_breeze_source_material", source)
	_material_cache[source] = material
	return material

func _channel(channel: int) -> Vector4:
	if channel == BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE:
		return Vector4(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0, 0.0)
	var mask := Vector4.ZERO
	mask[channel] = 1.0
	return mask

func _shader_code(source: StandardMaterial3D) -> String:
	var filters := ["filter_nearest", "filter_linear", "filter_nearest_mipmap", "filter_linear_mipmap", "filter_nearest_mipmap_anisotropic", "filter_linear_mipmap_anisotropic"]
	var sampler := String(filters[source.texture_filter]) + (", repeat_enable" if source.texture_repeat else ", repeat_disable")
	var roughness_hint := ["hint_roughness_r", "hint_roughness_g", "hint_roughness_b", "hint_roughness_a", "hint_roughness_gray"][source.roughness_texture_channel] as String
	var cull := ["cull_back", "cull_front", "cull_disabled"][source.cull_mode] as String
	var code := "shader_type spatial;\nrender_mode blend_mix, depth_draw_opaque, %s, diffuse_burley, specular_schlick_ggx;\n" % cull
	code += "uniform vec4 albedo_color : source_color;\nuniform sampler2D albedo_texture : source_color, %s;\n" % sampler
	code += "uniform float metallic;\nuniform float metallic_specular;\nuniform float roughness;\nuniform float normal_scale;\nuniform float ao_light_affect;\n"
	code += "uniform vec4 backlight : source_color;\nuniform sampler2D backlight_texture : source_color, %s;\n" % sampler
	code += "uniform sampler2D metallic_texture : %s;\nuniform sampler2D roughness_texture : %s, %s;\nuniform sampler2D normal_texture : hint_roughness_normal, %s;\nuniform sampler2D ao_texture : %s;\n" % [sampler, roughness_hint, sampler, sampler, sampler]
	code += "uniform vec4 metallic_channel;\nuniform vec4 roughness_channel;\nuniform vec4 ao_channel;\nuniform float alpha_scissor_threshold;\nuniform float alpha_hash_scale;\nuniform vec3 uv1_scale;\nuniform vec3 uv1_offset;\nuniform float motion_amount : hint_range(0.0, 1.0) = 1.0;\ninstance uniform vec4 breeze_bounds = vec4(-0.5, 1.0, 0.03, 0.0);\n"
	code += """
void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	float height_fraction = clamp((VERTEX.y - breeze_bounds.x) / max(breeze_bounds.y, 0.0001), 0.0, 1.0);
	float rooted_fraction = max((height_fraction - 0.18) / 0.82, 0.0);
	vec2 origin = MODEL_MATRIX[3].xz;
	float phase = dot(origin, vec2(0.043, 0.031));
	float clump_variation = fract(sin(dot(origin, vec2(12.9898, 78.233))) * 43758.5453);
	float local_speed = mix(0.86, 1.12, clump_variation);
	float main_wave = sin(TIME * 0.52 * local_speed + phase);
	float fine_wave = sin(TIME * 0.89 + phase * 1.47 + clump_variation * 3.0);
	// Reuse the existing two oscillators for quiet intervals and small gusts.
	// Different clumps retain their own timing; roots and the maximum world
	// displacement stay unchanged, with no extra vertex trigonometry.
	float gust = 0.70 + 0.30 * fine_wave * fine_wave;
	float wave = main_wave * 0.84 + fine_wave * 0.16;
	float amplitude = clamp(breeze_bounds.z, 0.0, 0.04) * clamp(motion_amount, 0.0, 1.0) * wave * gust;
	vec3 local_direction = inverse(mat3(MODEL_MATRIX)) * vec3(0.83205, 0.0, 0.55470);
	VERTEX += local_direction * (rooted_fraction * rooted_fraction * amplitude);
	// The shear derivative rotates lighting vectors with the tiny bend. At zero
	// motion no lighting-vector operations occur, enabling a frozen parity check.
	if (abs(amplitude) > 0.000001) {
		float slope = 2.0 * rooted_fraction * amplitude / (0.82 * max(breeze_bounds.y, 0.0001));
		NORMAL.y -= dot(NORMAL, local_direction) * slope;
		NORMAL = normalize(NORMAL);
		TANGENT = normalize(TANGENT + local_direction * TANGENT.y * slope);
		BINORMAL = normalize(BINORMAL + local_direction * BINORMAL.y * slope);
	}
}
void fragment() {
	vec4 albedo_tex = texture(albedo_texture, UV);
	ALBEDO = albedo_color.rgb * albedo_tex.rgb;
	SPECULAR = metallic_specular;
"""
	code += "\tMETALLIC = metallic" + (" * dot(texture(metallic_texture, UV), metallic_channel)" if source.metallic_texture != null else "") + ";\n"
	code += "\tROUGHNESS = roughness" + (" * dot(texture(roughness_texture, UV), roughness_channel)" if source.roughness_texture != null else "") + ";\n"
	if source.normal_enabled and source.normal_texture != null:
		code += "\tNORMAL_MAP = texture(normal_texture, UV).rgb;\n\tNORMAL_MAP_DEPTH = normal_scale;\n"
	if source.ao_enabled and source.ao_texture != null:
		code += "\tAO = dot(texture(ao_texture, UV), ao_channel);\n\tAO_LIGHT_AFFECT = ao_light_affect;\n"
	if source.backlight_enabled:
		code += "\tBACKLIGHT = backlight.rgb" + (" + texture(backlight_texture, UV).rgb" if source.backlight_texture != null else "") + ";\n"
	if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		code += "\tALPHA = albedo_tex.a * albedo_color.a;\n\tALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;\n"
	elif source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH:
		code += "\tALPHA = albedo_tex.a * albedo_color.a;\n\tALPHA_HASH_SCALE = alpha_hash_scale;\n"
	return code + "}\n"
