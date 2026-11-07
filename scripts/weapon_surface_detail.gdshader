shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo_texture = false;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform float relief = 0.000025;
uniform float machining : hint_range(0.0, 1.0) = 0.0;
uniform float variation : hint_range(0.0, 0.2) = 0.06;
uniform float finish_detail : hint_range(0.0, 1.0) = 0.0;

varying vec3 surface_position;

float grain_hash(vec3 point) {
	point = fract(point * 0.1031);
	point += dot(point, point.yzx + 33.33);
	return fract((point.x + point.y) * point.z);
}

float grain_noise(vec3 point) {
	vec3 cell = floor(point);
	vec3 blend = fract(point);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(
		mix(mix(grain_hash(cell), grain_hash(cell + vec3(1, 0, 0)), blend.x),
			mix(grain_hash(cell + vec3(0, 1, 0)), grain_hash(cell + vec3(1, 1, 0)), blend.x), blend.y),
		mix(mix(grain_hash(cell + vec3(0, 0, 1)), grain_hash(cell + vec3(1, 0, 1)), blend.x),
			mix(grain_hash(cell + vec3(0, 1, 1)), grain_hash(cell + vec3(1, 1, 1)), blend.x), blend.y), blend.z);
}

void vertex() {
	// Local coordinates keep the grain fixed to each moving magazine and bolt.
	surface_position = VERTEX;
}

void fragment() {
	vec3 normal = normalize(NORMAL);
	if (!FRONT_FACING) {
		normal = -normal;
	}
	vec3 colour = albedo_color.rgb;
	if (has_albedo_texture) {
		colour *= texture(albedo_texture, UV * uv_scale + uv_offset).rgb;
	}

	float broad_grain = grain_noise(surface_position * 65.0);
	float fine_grain = grain_noise(surface_position * mix(620.0, 360.0, finish_detail));
	float pixel_span = max(length(dFdx(surface_position)), length(dFdy(surface_position)));
	float detail_visible = 1.0 - smoothstep(mix(0.0009, 0.0016, finish_detail), mix(0.003, 0.006, finish_detail), pixel_span);
	float mill_marks = sin(surface_position.x * 2600.0 + surface_position.z * 1700.0 + broad_grain * 3.0);
	float fine_detail = mix(fine_grain - 0.5, mill_marks * 0.35, machining) * detail_visible;

	vec3 screen_x = dFdx(VERTEX);
	vec3 screen_y = dFdy(VERTEX);
	// Wear follows the small bevels already present on metal, while long shallow
	// scuffs break up broad receiver panels. Both remain fixed to the model.
	float curvature = length(dFdx(normal)) / max(length(screen_x), 0.0001);
	curvature += length(dFdy(normal)) / max(length(screen_y), 0.0001);
	float exposed_metal = smoothstep(0.5, 0.85, metallic);
	float worn_edge = smoothstep(45.0, 240.0, curvature) * smoothstep(0.22, 0.72, broad_grain);
	worn_edge *= exposed_metal * finish_detail * (1.0 - smoothstep(0.80, 0.92, metallic));
	float scuff = grain_noise(surface_position * vec3(24.0, 370.0, 370.0));
	scuff = smoothstep(0.67, 0.88, scuff) * exposed_metal * finish_detail * detail_visible;

	ALBEDO = colour * (1.0 + (broad_grain - 0.5) * (0.055 - finish_detail * 0.0125));
	ALBEDO = mix(ALBEDO, vec3(0.22, 0.24, 0.26), worn_edge * 0.32 + scuff * 0.12);
	METALLIC = metallic;
	ROUGHNESS = clamp(roughness + (broad_grain - 0.5) * variation * (1.0 - finish_detail * 0.55) + fine_detail * variation - worn_edge * 0.12 - scuff * 0.055, 0.19, 0.96);
	SPECULAR = 0.5;

	// Micrometre relief changes reflected light without changing geometry.
	float height = fine_detail * relief * (1.0 + 2.5 * finish_detail);
	vec3 cross_y = cross(screen_y, normal);
	vec3 cross_x = cross(normal, screen_x);
	float determinant = dot(screen_x, cross_y);
	vec3 gradient = dFdx(height) * cross_y + dFdy(height) * cross_x;
	NORMAL = normalize(normal - sign(determinant) * gradient / max(abs(determinant), 0.0000000001));
}
