shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec4 source_albedo : source_color = vec4(1.0);
uniform float source_metallic = 0.0;
uniform float source_roughness = 0.6;
uniform float source_specular = 0.5;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metallic_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo_texture = false;
uniform bool has_metallic_texture = false;
uniform bool has_roughness_texture = false;
uniform vec4 metallic_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 roughness_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform float relief_m = 0.000003;
uniform float grain_frequency = 1100.0;
uniform float roughness_range = 0.026;
uniform float directionality = 0.0;

varying vec3 finish_position;

float finish_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float finish_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	vec3 w = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(finish_hash(cell), finish_hash(cell + vec3(1, 0, 0)), w.x),
			mix(finish_hash(cell + vec3(0, 1, 0)), finish_hash(cell + vec3(1, 1, 0)), w.x), w.y),
		mix(mix(finish_hash(cell + vec3(0, 0, 1)), finish_hash(cell + vec3(1, 0, 1)), w.x),
			mix(finish_hash(cell + vec3(0, 1, 1)), finish_hash(cell + vec3(1, 1, 1)), w.x), w.y), w.z);
}

float resolved_detail(vec3 coordinates) {
	float footprint = max(length(dFdx(coordinates)), length(dFdy(coordinates)));
	// Fade before noise cells shrink below roughly two pixels. Nothing temporal
	// or camera-relative enters the pattern, including on the moving magazine.
	return 1.0 - smoothstep(0.45, 0.95, footprint);
}

void vertex() {
	finish_position = VERTEX;
}

void fragment() {
	vec2 source_uv = UV * uv_scale + uv_offset;
	vec3 colour = source_albedo.rgb;
	if (has_albedo_texture) {
		colour *= texture(albedo_texture, source_uv).rgb;
	}
	float metal = source_metallic;
	if (has_metallic_texture) {
		metal *= dot(texture(metallic_texture, source_uv), metallic_channel);
	}
	float rough = source_roughness;
	if (has_roughness_texture) {
		rough *= dot(texture(roughness_texture, source_uv), roughness_channel);
	}

	vec3 fine_coordinates = finish_position * grain_frequency;
	vec3 satin_scale = mix(vec3(0.42), vec3(0.12, 0.62, 0.62), directionality);
	vec3 satin_coordinates = fine_coordinates * satin_scale + vec3(7.1, 2.3, 5.7);
	float fine = (finish_noise(fine_coordinates) - 0.5) * resolved_detail(fine_coordinates);
	float satin = (finish_noise(satin_coordinates) - 0.5) * resolved_detail(satin_coordinates);
	float surface_detail = mix(fine, satin, directionality * 0.35);

	// Keep the exact authored colour and metal response. Only small, zero-centred
	// roughness/normal changes describe finish: no albedo mottling or edge masks.
	ALBEDO = colour;
	METALLIC = metal;
	SPECULAR = source_specular;
	ROUGHNESS = clamp(rough + (fine * 0.65 + satin * 0.35) * roughness_range, 0.0, 1.0);

	vec3 normal = normalize(NORMAL);
	if (!FRONT_FACING) {
		normal = -normal;
	}
	float height = surface_detail * relief_m;
	vec3 screen_x = dFdx(VERTEX);
	vec3 screen_y = dFdy(VERTEX);
	vec3 cross_y = cross(screen_y, normal);
	vec3 cross_x = cross(normal, screen_x);
	float determinant = dot(screen_x, cross_y);
	vec3 gradient = (dFdx(height) * cross_y + dFdy(height) * cross_x) * sign(determinant) / max(abs(determinant), 0.000000000001);
	// A grazing or extremely small triangle must never generate a normal spike.
	gradient *= min(1.0, 0.08 / max(length(gradient), 0.000001));
	NORMAL = normalize(normal - gradient);
}
