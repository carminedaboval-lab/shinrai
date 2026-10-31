shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// The park's scanned turf at two scales, so it never shows a repeat, with
// mown tone drifting across the lawn and thin worn patches of soil.
uniform sampler2D turf_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D turf_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D turf_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 turf_tint : source_color = vec3(0.30, 0.42, 0.19);
varying vec3 world_position;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise21(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	vec2 near_uv = vec2(p.x * 0.966 - p.y * 0.259, p.x * 0.259 + p.y * 0.966) / 2.0;
	vec2 far_uv = vec2(p.x * 0.819 + p.y * 0.574, -p.x * 0.574 + p.y * 0.819) / 5.3;
	float drift = noise21(p * 0.07) * 0.6 + noise21(p * 0.23) * 0.4;
	float blend = smoothstep(0.3, 0.7, noise21(p * 0.17 + vec2(11.0, 4.0)));
	vec3 turf = mix(texture(turf_albedo, near_uv).rgb, texture(turf_albedo, far_uv).rgb, blend);
	// The scan is mostly leaf litter. Keep its detail but take its colour from living grass.
	float detail = dot(turf, vec3(0.2126, 0.7152, 0.0722));
	turf = mix(turf, turf_tint * clamp(detail * 2.6, 0.45, 1.5), 0.86) * mix(0.8, 1.12, drift);
	turf = mix(turf, turf * vec3(1.14, 1.04, 0.74), smoothstep(0.55, 0.8, noise21(p * 0.11 + vec2(3.0, 19.0))) * 0.35);
	float wear = smoothstep(0.76, 0.86, noise21(p * 0.31) * 0.7 + noise21(p * 1.7) * 0.3);
	ALBEDO = mix(turf, texture(soil_albedo, near_uv).rgb * 0.8, wear * 0.3);
	vec3 n = mix(texture(turf_normal, near_uv).xyz, texture(turf_normal, far_uv).xyz, blend) * 2.0 - 1.0;
	vec3 world_normal = normalize(vec3(n.x * 0.7, 1.0, n.y * 0.7));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	ROUGHNESS = clamp(texture(turf_roughness, near_uv).r + 0.08, 0.72, 1.0);
	SPECULAR = 0.22;
}
