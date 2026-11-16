shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// STAGING DRAFT: local asphalt footway top only, via Street.footway_material.
// Requires the explicit retain_footway_color route on its selected native carrier.
// Keep actual packed FOOTWAY colour. World XZ metres keep grain phase and scale
// continuous across straight/flare/ring carriers; native metre UVs remain intact.
// No paint, tile joints,
// displacement, alpha marker, opacity write or colour-based face classification.
uniform sampler2D aggregate : source_color, repeat_enable, filter_linear_mipmap_anisotropic, hint_default_white;
uniform float sample_metres = 2.0;
// Exact full-image means are supplied by local_footway_texture_metrics.json.
uniform float aggregate_mean_linear = 0.028271220954791766;
uniform float aggregate_mean_srgb = 0.1764264895801918;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.45;

varying vec2 footway_world_metres;

void vertex() {
	footway_world_metres = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

vec3 native_color(vec3 srgb) {
	return OUTPUT_IS_SRGB ? srgb : mix(
		pow((srgb + vec3(0.055)) / 1.055, vec3(2.4)),
		srgb / 12.92, lessThan(srgb, vec3(0.04045)));
}

void fragment() {
	float grain = dot(texture(aggregate, footway_world_metres / max(0.01, sample_metres)).rgb,
		vec3(0.2126, 0.7152, 0.0722));
	float average = OUTPUT_IS_SRGB ? aggregate_mean_srgb : aggregate_mean_linear;
	float detail = clamp(1.0 + grain_strength * (grain / max(0.00001, average) - 1.0), 0.80, 1.20);
	ALBEDO = native_color(COLOR.rgb) * detail;
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	AO = 1.0;
}
