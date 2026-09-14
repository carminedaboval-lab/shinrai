shader_type spatial;

// Apartment concrete matched to the supplied exposed-formwork reference.
// World-space triplanar projection keeps the grain at one real-world scale on
// every procedural box and prevents stretched marks on tall or narrow pieces.
uniform sampler2D concrete_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 concrete_tint : source_color = vec4(0.365, 0.342, 0.310, 1.0);
uniform vec4 grime_tint : source_color = vec4(0.075, 0.068, 0.057, 1.0);
uniform float texture_scale : hint_range(0.10, 1.50, 0.01) = 0.54;
uniform float panel_width_m : hint_range(1.00, 3.50, 0.01) = 2.05;
uniform float panel_height_m : hint_range(0.80, 2.50, 0.01) = 1.36;
uniform float panel_strength : hint_range(0.0, 0.50, 0.01) = 0.24;
uniform float tie_strength : hint_range(0.0, 1.0, 0.01) = 0.76;
uniform float rain_strength : hint_range(0.0, 0.20, 0.005) = 0.05;
uniform float grime_strength : hint_range(0.0, 0.80, 0.01) = 0.42;
uniform float grime_height_m : hint_range(0.20, 2.50, 0.01) = 1.22;
uniform float ambient_lift : hint_range(0.0, 0.08, 0.002) = 0.02;

varying vec3 world_position;
varying vec3 world_normal;

float hash21(vec2 value) {
	vec2 p = fract(value * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec3 sample_concrete_triplanar(vec3 position_value, vec3 normal_value) {
	vec3 weights = pow(abs(normalize(normal_value)), vec3(8.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	vec3 x_sample = texture(concrete_texture, position_value.zy * texture_scale).rgb;
	vec3 y_sample = texture(concrete_texture, position_value.xz * texture_scale).rgb;
	vec3 z_sample = texture(concrete_texture, position_value.xy * texture_scale).rgb;
	return x_sample * weights.x + y_sample * weights.y + z_sample * weights.z;
}

float seam_line(float panel_coordinate) {
	float edge_distance = min(fract(panel_coordinate), 1.0 - fract(panel_coordinate));
	float antialias_width = max(fwidth(panel_coordinate) * 1.20, 0.0015);
	return 1.0 - smoothstep(
		0.006 + antialias_width,
		0.014 + antialias_width,
		edge_distance
	);
}

float circle_mask(vec2 position_value, vec2 center_value, float radius_value) {
	float distance_value = length(position_value - center_value);
	float antialias_width = max(fwidth(distance_value) * 1.35, 0.0015);
	return 1.0 - smoothstep(
		radius_value - antialias_width,
		radius_value + antialias_width,
		distance_value
	);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 normal_abs = abs(normalize(world_normal));
	float vertical_surface = 1.0 - smoothstep(0.48, 0.82, normal_abs.y);
	float front_or_back = step(normal_abs.x, normal_abs.z);
	vec2 facade_position = mix(world_position.zy, world_position.xy, front_or_back);
	vec2 panel_uv = vec2(
		facade_position.x / panel_width_m,
		world_position.y / panel_height_m
	);
	vec2 panel_cell = floor(panel_uv);
	vec2 panel_position_m = fract(panel_uv) * vec2(panel_width_m, panel_height_m);

	vec3 texture_value = sample_concrete_triplanar(world_position, world_normal);
	float texture_luma = dot(texture_value, vec3(0.299, 0.587, 0.114));
	float grain = clamp(1.0 + (texture_luma - 0.50) * 0.24, 0.89, 1.11);
	float panel_variation = mix(0.955, 1.035, hash21(panel_cell + vec2(7.3, 2.1)));
	vec3 surface_color = concrete_tint.rgb * grain * panel_variation;

	// Thin formwork joints follow the panel rhythm in the detail sheet.
	float seam = max(seam_line(panel_uv.x), seam_line(panel_uv.y)) * vertical_surface;
	surface_color *= 1.0 - seam * panel_strength;

	// Two small alternating form-tie holes per panel avoid a mechanical grid.
	float diagonal = step(0.5, hash21(panel_cell + vec2(19.7, 41.3)));
	vec2 tie_a = mix(
		vec2(0.285, 0.265),
		vec2(0.285, panel_height_m - 0.265),
		diagonal
	);
	vec2 tie_b = mix(
		vec2(panel_width_m - 0.285, panel_height_m - 0.265),
		vec2(panel_width_m - 0.285, 0.265),
		diagonal
	);
	float tie_core = max(
		circle_mask(panel_position_m, tie_a, 0.026),
		circle_mask(panel_position_m, tie_b, 0.026)
	) * vertical_surface;
	float tie_halo = max(
		circle_mask(panel_position_m, tie_a, 0.052),
		circle_mask(panel_position_m, tie_b, 0.052)
	) * vertical_surface;
	surface_color *= 1.0 - tie_halo * tie_strength * 0.22;
	surface_color = mix(surface_color, grime_tint.rgb * 0.42, tie_core * tie_strength);

	// Sparse low-contrast runoff replaces the oversized crack/scribble pattern.
	float streak_frequency = 1.72;
	float streak_lane = floor(facade_position.x * streak_frequency);
	float streak_seed = hash21(vec2(streak_lane, 83.6));
	float streak_distance = abs(fract(facade_position.x * streak_frequency) - 0.5);
	float streak_shape = 1.0 - smoothstep(0.055, 0.22, streak_distance);
	float streak_presence = smoothstep(0.73, 0.96, streak_seed);
	float streak_breakup = mix(0.45, 1.0, texture_luma);
	float rain_streak = streak_shape * streak_presence * streak_breakup * vertical_surface;
	surface_color *= 1.0 - rain_streak * rain_strength;

	// Damp splashback and urban grime build naturally from the pavement upward.
	float ground_mask = 1.0 - smoothstep(0.10, grime_height_m, world_position.y);
	float grime_variation = mix(0.58, 1.0, 1.0 - texture_luma);
	float ground_grime = ground_mask * grime_variation * vertical_surface;
	surface_color = mix(
		surface_color,
		grime_tint.rgb,
		ground_grime * grime_strength
	);

	ALBEDO = surface_color;
	METALLIC = 0.0;
	ROUGHNESS = clamp(0.925 + seam * 0.035 + ground_grime * 0.035, 0.90, 0.99);
	SPECULAR = 0.22;
	AO = clamp(1.0 - seam * 0.10 - tie_halo * 0.34 - ground_grime * 0.12, 0.42, 1.0);
	EMISSION = surface_color * ambient_lift;
}
