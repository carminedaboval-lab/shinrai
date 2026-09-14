shader_type spatial;

// Apartment-only exposed concrete matched to the supplied reference sheet.
// The existing neutral concrete texture is sampled at three world-space scales:
// broad curing clouds, formwork-scale grain, and fine aggregate. All procedural
// marks remain restrained so the façade reads as cast concrete, not scribbles.
uniform sampler2D concrete_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 concrete_tint : source_color = vec4(0.305, 0.270, 0.225, 1.0);
uniform vec4 grime_tint : source_color = vec4(0.055, 0.047, 0.035, 1.0);
uniform vec4 efflorescence_tint : source_color = vec4(0.43, 0.40, 0.34, 1.0);
uniform vec4 algae_tint : source_color = vec4(0.070, 0.073, 0.045, 1.0);
uniform float texture_scale : hint_range(0.10, 1.50, 0.01) = 0.58;
uniform float panel_width_m : hint_range(1.00, 3.50, 0.01) = 2.10;
uniform float panel_height_m : hint_range(0.80, 2.50, 0.01) = 1.42;
uniform float panel_strength : hint_range(0.0, 0.50, 0.01) = 0.12;
uniform float tie_strength : hint_range(0.0, 1.0, 0.01) = 0.24;
uniform float pore_strength : hint_range(0.0, 1.0, 0.01) = 0.32;
uniform float crack_strength : hint_range(0.0, 0.20, 0.005) = 0.050;
uniform float rain_strength : hint_range(0.0, 0.20, 0.005) = 0.050;
uniform float efflorescence_strength : hint_range(0.0, 0.30, 0.005) = 0.075;
uniform float grime_strength : hint_range(0.0, 0.80, 0.01) = 0.42;
uniform float algae_strength : hint_range(0.0, 0.30, 0.005) = 0.10;
uniform float grime_height_m : hint_range(0.20, 2.50, 0.01) = 1.18;
uniform float detail_normal_strength : hint_range(0.0, 1.0, 0.01) = 0.36;
uniform float ambient_lift : hint_range(0.0, 0.08, 0.002) = 0.006;

varying vec3 world_position;
varying vec3 world_normal;

float hash21(vec2 value) {
	vec2 p = fract(value * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float luminance(vec3 value) {
	return dot(value, vec3(0.299, 0.587, 0.114));
}

vec3 sample_concrete_triplanar(
	vec3 position_value,
	vec3 normal_value,
	float scale_value
) {
	vec3 weights = pow(abs(normalize(normal_value)), vec3(8.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	vec3 x_sample = texture(concrete_texture, position_value.zy * scale_value).rgb;
	vec3 y_sample = texture(concrete_texture, position_value.xz * scale_value).rgb;
	vec3 z_sample = texture(concrete_texture, position_value.xy * scale_value).rgb;
	return x_sample * weights.x + y_sample * weights.y + z_sample * weights.z;
}

float seam_line(float panel_coordinate) {
	float edge_distance = min(fract(panel_coordinate), 1.0 - fract(panel_coordinate));
	float antialias_width = max(fwidth(panel_coordinate) * 0.72, 0.0007);
	float seam_half_width = 0.0034;
	return 1.0 - smoothstep(
		seam_half_width,
		seam_half_width + antialias_width,
		edge_distance
	);
}

float circle_mask(vec2 position_value, vec2 center_value, float radius_value) {
	float distance_value = length(position_value - center_value);
	float antialias_width = max(fwidth(distance_value) * 1.25, 0.0015);
	return 1.0 - smoothstep(
		radius_value - antialias_width,
		radius_value + antialias_width,
		distance_value
	);
}

float hairline_crack_mask(vec2 position_value) {
	// One short crack may appear in a large 5.8 x 5.2 m region. It is thin,
	// softly antialiased and deliberately too sparse to become a scribble field.
	vec2 crack_cell_size = vec2(5.8, 5.2);
	vec2 crack_cell = floor(position_value / crack_cell_size);
	vec2 crack_local = fract(position_value / crack_cell_size);
	float crack_seed = hash21(crack_cell + vec2(61.4, 13.7));
	float crack_presence = smoothstep(0.91, 0.985, crack_seed);
	float crack_path = (
		0.48
		+ sin(crack_local.y * 18.0 + crack_seed * 5.0) * 0.050
		+ sin(crack_local.y * 41.0 + crack_seed * 11.0) * 0.018
	);
	float crack_distance = abs(crack_local.x - crack_path);
	float crack_aa = max(fwidth(crack_local.x) * 0.85, 0.0012);
	float crack_line = 1.0 - smoothstep(
		0.0015,
		0.0030 + crack_aa,
		crack_distance
	);
	float crack_length = (
		smoothstep(0.16, 0.25, crack_local.y)
		* (1.0 - smoothstep(0.70, 0.82, crack_local.y))
	);
	return crack_line * crack_length * crack_presence;
}

vec3 perturb_world_normal(
	vec3 position_value,
	vec3 normal_value,
	float height_value,
	float strength_value
) {
	vec3 position_dx = dFdx(position_value);
	vec3 position_dy = dFdy(position_value);
	vec3 cross_x = cross(position_dy, normal_value);
	vec3 cross_y = cross(normal_value, position_dx);
	float determinant = dot(position_dx, cross_x);
	vec3 height_gradient = (
		dFdx(height_value) * cross_x + dFdy(height_value) * cross_y
	) * sign(determinant);
	return normalize(
		abs(determinant) * normal_value - height_gradient * strength_value
	);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 normal_world = normalize(world_normal);
	vec3 normal_abs = abs(normal_world);
	float vertical_surface = 1.0 - smoothstep(0.48, 0.82, normal_abs.y);
	float front_or_back = step(normal_abs.x, normal_abs.z);
	vec2 facade_position = mix(world_position.zy, world_position.xy, front_or_back);
	vec2 panel_uv = vec2(
		facade_position.x / panel_width_m,
		world_position.y / panel_height_m
	);
	vec2 panel_cell = floor(panel_uv);
	vec2 panel_position_m = fract(panel_uv) * vec2(panel_width_m, panel_height_m);

	// The source image is intentionally pale. Centre it near its real value
	// instead of subtracting 0.5, which previously flattened almost every texel.
	vec3 macro_texture = sample_concrete_triplanar(
		world_position, normal_world, texture_scale * 0.30
	);
	vec3 base_texture = sample_concrete_triplanar(
		world_position, normal_world, texture_scale
	);
	vec3 fine_texture = sample_concrete_triplanar(
		world_position, normal_world, texture_scale * 3.20
	);
	float macro_luma = luminance(macro_texture);
	float base_luma = luminance(base_texture);
	float fine_luma = luminance(fine_texture);
	float grain = clamp(
		1.0
			+ (macro_luma - 0.94) * 0.78
			+ (base_luma - 0.94) * 1.28
			+ (fine_luma - 0.94) * 0.56,
		0.84,
		1.12
	);
	float panel_variation = mix(
		0.958,
		1.035,
		hash21(panel_cell + vec2(7.3, 2.1))
	);
	vec3 surface_color = concrete_tint.rgb * grain * panel_variation;

	// Thin, slightly recessed formwork joints reproduce the large poured panels.
	float seam = max(seam_line(panel_uv.x), seam_line(panel_uv.y)) * vertical_surface;
	surface_color *= 1.0 - seam * panel_strength;

	// Two aligned form-tie holes per panel follow the reference's calm grid.
	// Their halos are shallow and warm-grey rather than pitch-black dots.
	float tie_y = panel_height_m * 0.50;
	vec2 tie_a = vec2(0.30, tie_y);
	vec2 tie_b = vec2(panel_width_m - 0.30, tie_y);
	float tie_core = max(
		circle_mask(panel_position_m, tie_a, 0.009),
		circle_mask(panel_position_m, tie_b, 0.009)
	) * vertical_surface;
	float tie_halo = max(
		circle_mask(panel_position_m, tie_a, 0.021),
		circle_mask(panel_position_m, tie_b, 0.021)
	) * vertical_surface;
	float tie_outer = max(
		circle_mask(panel_position_m, tie_a, 0.029),
		circle_mask(panel_position_m, tie_b, 0.029)
	) * vertical_surface;
	float tie_rim = max(tie_outer - tie_halo, 0.0);
	surface_color = mix(
		surface_color,
		efflorescence_tint.rgb,
		tie_rim * tie_strength * 0.10
	);
	surface_color *= 1.0 - tie_halo * tie_strength * 0.11;
	surface_color = mix(
		surface_color,
		grime_tint.rgb * 0.92,
		tie_core * tie_strength * 0.62
	);

	// Millimetre-scale aggregate pores remain irregular and distance-safe.
	vec2 pore_grid = facade_position / 0.058;
	vec2 pore_cell = floor(pore_grid);
	vec2 pore_local = fract(pore_grid);
	float pore_seed = hash21(pore_cell + vec2(31.7, 9.2));
	vec2 pore_center = vec2(
		hash21(pore_cell + vec2(4.1, 17.8)),
		hash21(pore_cell + vec2(23.6, 5.7))
	) * 0.66 + 0.17;
	float pore_radius = mix(
		0.030,
		0.070,
		hash21(pore_cell + vec2(12.5, 28.4))
	);
	float pore_distance = length(pore_local - pore_center);
	float pore_aa = max(fwidth(pore_distance) * 1.25, 0.004);
	float pore_shape = 1.0 - smoothstep(
		pore_radius,
		pore_radius + pore_aa,
		pore_distance
	);
	float pore_presence = smoothstep(0.90, 0.985, pore_seed);
	float pore_footprint = max(fwidth(pore_grid.x), fwidth(pore_grid.y));
	float pore_distance_fade = 1.0 - smoothstep(0.22, 0.62, pore_footprint);
	float pore_mask = (
		pore_shape * pore_presence * pore_distance_fade * vertical_surface
	);
	surface_color *= 1.0 - pore_mask * pore_strength * 0.42;

	// Restrained vertical runoff follows the broad texture variation. There are
	// no generated crack paths, keeping the wall free of the old scribble look.
	float streak_frequency = 1.38;
	float streak_lane = floor(facade_position.x * streak_frequency);
	float streak_seed = hash21(vec2(streak_lane, 83.6));
	float streak_distance = abs(fract(facade_position.x * streak_frequency) - 0.5);
	float streak_shape = 1.0 - smoothstep(0.075, 0.28, streak_distance);
	float streak_presence = smoothstep(0.68, 0.95, streak_seed);
	float streak_breakup = mix(0.48, 1.0, base_luma);
	float rain_streak = (
		streak_shape * streak_presence * streak_breakup * vertical_surface
	);
	surface_color *= 1.0 - rain_streak * rain_strength;

	// Sparse pale mineral runoff sits beside, rather than directly over, the
	// dark rain lanes. This creates the reference's subtle efflorescence.
	float mineral_frequency = 0.92;
	float mineral_lane = floor((facade_position.x + 1.73) * mineral_frequency);
	float mineral_seed = hash21(vec2(mineral_lane, 37.2));
	float mineral_distance = abs(
		fract((facade_position.x + 1.73) * mineral_frequency) - 0.5
	);
	float mineral_shape = 1.0 - smoothstep(0.10, 0.34, mineral_distance);
	float mineral_presence = smoothstep(0.76, 0.97, mineral_seed);
	float mineral_breakup = mix(0.38, 1.0, macro_luma);
	float efflorescence = (
		mineral_shape
		* mineral_presence
		* mineral_breakup
		* vertical_surface
	);
	surface_color = mix(
		surface_color,
		efflorescence_tint.rgb,
		efflorescence * efflorescence_strength
	);

	float hairline_crack = hairline_crack_mask(facade_position) * vertical_surface;
	surface_color *= 1.0 - hairline_crack * crack_strength;

	// Damp splashback builds from the pavement upward with irregular aggregate
	// breakup, matching the reference's ground-contact weathering.
	float ground_mask = 1.0 - smoothstep(0.08, grime_height_m, world_position.y);
	float grime_variation = mix(
		0.48,
		1.0,
		clamp((0.96 - macro_luma) * 5.0, 0.0, 1.0)
	);
	float ground_grime = ground_mask * grime_variation * vertical_surface;
	surface_color = mix(
		surface_color,
		grime_tint.rgb,
		ground_grime * grime_strength
	);
	float algae_patch = (
		ground_mask
		* smoothstep(0.22, 0.78, 1.0 - macro_luma)
		* mix(
			0.30,
			1.0,
			hash21(vec2(floor(facade_position.x * 0.42), 91.7))
		)
		* vertical_surface
	);
	surface_color = mix(
		surface_color,
		algae_tint.rgb,
		algae_patch * algae_strength
	);

	// Derivative-based relief works on every box face without UV stretching.
	// Seams, tie recesses, aggregate and the real texture all contribute.
	float relief_height = (
		(base_luma - 0.94) * 0.030
		+ (fine_luma - 0.94) * 0.012
		- seam * 0.032
		- tie_halo * 0.024
		- tie_core * 0.038
		- pore_mask * 0.020
		- hairline_crack * 0.012
	);
	vec3 bumped_world_normal = perturb_world_normal(
		world_position,
		normal_world,
		relief_height,
		mix(0.12, detail_normal_strength, vertical_surface)
	);
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped_world_normal, 0.0)).xyz);

	float roughness_variation = clamp((0.94 - fine_luma) * 0.22, -0.025, 0.040);
	ALBEDO = surface_color;
	METALLIC = 0.0;
	ROUGHNESS = clamp(
		0.925 + roughness_variation + seam * 0.025 + ground_grime * 0.030,
		0.89,
		0.995
	);
	SPECULAR = 0.16;
	AO = clamp(
		1.0
			- seam * 0.075
			- tie_halo * 0.16
			- pore_mask * 0.10
			- hairline_crack * 0.06
			- ground_grime * 0.12
			- algae_patch * 0.05,
		0.54,
		1.0
	);
	EMISSION = surface_color * ambient_lift;
}
