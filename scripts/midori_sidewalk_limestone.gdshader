shader_type spatial;
render_mode cull_disabled;

// Street-only limestone/precast response. No world displacement, cracks,
// emissive lift, baked sunlight or changes to the existing geometry/joint UVs.
uniform vec4 mineral_color : source_color = vec4(0.725, 0.702, 0.639, 1.0);
uniform float grain_strength : hint_range(0.0, 0.5) = 0.12;
uniform float aggregate_scale = 115.0;
uniform float surface_roughness = 0.92;
uniform float paint_wear : hint_range(0.0, 1.0) = 0.0;
uniform float stone_weather = 0.0;
uniform float road_weather = 0.0;
uniform sampler2D precast_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D precast_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D precast_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float texture_neutral_luma = 0.136050;
uniform float texture_repeats_per_metre = 0.85;
uniform float texture_color_strength : hint_range(0.0, 1.0) = 0.50;
uniform float texture_normal_strength : hint_range(0.0, 1.0) = 0.38;
uniform float wetness = 0.0;
varying vec3 world_position;
varying vec3 world_normal;

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.x, p.y, p.x) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float mineral_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// Original precision-safe rotated grain and derivative fade are retained.
	vec2 local_p = world_position.xz - vec2(0.0, 174.0);
	vec2 p = vec2(local_p.x * 0.81915 - local_p.y * 0.57358,
		local_p.x * 0.57358 + local_p.y * 0.81915);
	vec2 grain_uv = p * aggregate_scale;
	float grain_visibility = 1.0 - smoothstep(0.6, 1.7, max(length(dFdx(grain_uv)), length(dFdy(grain_uv))));
	float fine = mix(0.5, mineral_noise(grain_uv), grain_visibility);
	vec2 aggregate_uv = p * 23.0;
	float aggregate_visibility = 1.0 - smoothstep(0.6, 1.7, max(length(dFdx(aggregate_uv)), length(dFdy(aggregate_uv))));
	float aggregate = mix(0.5, mineral_noise(aggregate_uv), aggregate_visibility);
	float grain = ((fine - 0.5) * 1.6 + (aggregate - 0.5) * 0.65) * grain_strength;

	// Dominant-axis projection covers paving tops AND real vertical kerb faces.
	// Explicit surface bases need no tangent vertex stream after street batching.
	vec3 n = normalize(world_normal);
	vec3 an = abs(n);
	vec3 local_position = world_position - vec3(0.0, 0.0, 174.0);
	vec2 source_uv;
	vec3 tangent_axis;
	vec3 bitangent_axis;
	if (an.y >= an.x && an.y >= an.z) {
		source_uv = vec2(local_position.x, -local_position.z * sign(n.y));
		tangent_axis = vec3(1.0, 0.0, 0.0);
		bitangent_axis = vec3(0.0, 0.0, -sign(n.y));
	} else if (an.x >= an.z) {
		source_uv = vec2(-local_position.z * sign(n.x), local_position.y);
		tangent_axis = vec3(0.0, 0.0, -sign(n.x));
		bitangent_axis = vec3(0.0, 1.0, 0.0);
	} else {
		source_uv = vec2(local_position.x * sign(n.z), local_position.y);
		tangent_axis = vec3(sign(n.z), 0.0, 0.0);
		bitangent_axis = vec3(0.0, 1.0, 0.0);
	}
	source_uv *= texture_repeats_per_metre;
	vec3 sampled_albedo = texture(precast_albedo, source_uv).rgb;
	float source_luma = dot(sampled_albedo, vec3(0.2126, 0.7152, 0.0722));
	// Remove the source's gray mean while retaining its measured mineral pores.
	// Palette remains stone-specific; this is not a colored light overlay.
	float source_detail = mix(1.0, clamp(source_luma / texture_neutral_luma, 0.78, 1.22), texture_color_strength);
	vec3 orm = texture(precast_orm, source_uv).rgb;
	// Existing Godot normal import uses two-channel normal compression. Recover
	// positive Z from RG rather than relying on an unavailable blue channel.
	vec2 source_normal_xy = texture(precast_normal, source_uv).rg * 2.0 - 1.0;
	vec3 source_normal = vec3(source_normal_xy, sqrt(max(1.0 - dot(source_normal_xy, source_normal_xy), 0.0001)));
	vec3 bumped_world_normal = normalize(tangent_axis * source_normal.x * texture_normal_strength
		+ bitangent_axis * source_normal.y * texture_normal_strength + n * source_normal.z);
	NORMAL = normalize(mat3(VIEW_MATRIX) * bumped_world_normal);

	// Real per-stone UV boundaries survive batching. Fine soil at edges and a
	// lightly abraded 3mm arris replace broad dark outlines. No invented cracks.
	float edge_distance = min(min(UV.x, 1.0 - UV.x) * 0.60, min(UV.y, 1.0 - UV.y) * 0.80);
	float edge = 1.0 - smoothstep(0.003, 0.018, edge_distance);
	float arris = 1.0 - smoothstep(0.000, 0.003, edge_distance);
	float edge_soil = edge * (0.035 + 0.040 * mineral_noise(p * 9.0));
	float stone_stain = smoothstep(0.60, 0.87, mineral_noise(p * 1.8 + vec2(31.0, 9.0)));
	float weather = stone_weather * (edge_soil + stone_stain * 0.035 - arris * 0.025);
	float gutter_distance = min(abs(world_position.z - 183.11), abs(world_position.z - 189.89));
	float gutter_dirt = (1.0 - smoothstep(0.05, 0.42, gutter_distance)) * (0.04 + 0.09 * mineral_noise(p * 4.5));
	vec2 wear_uv = p * 34.0;
	float wear_visibility = 1.0 - smoothstep(0.6, 1.7, max(length(dFdx(wear_uv)), length(dFdy(wear_uv))));
	float wear = mix(0.12, smoothstep(0.63, 0.88, mineral_noise(wear_uv)), wear_visibility) * paint_wear;
	ALBEDO = mineral_color.rgb * source_detail * (1.0 + grain) * (1.0 - weather - road_weather * gutter_dirt - wear * 0.20);
	// Retain the original submillimetre tangentless surface-gradient microrelief.
	float relief = ((fine - 0.5) * 0.55 + (aggregate - 0.5)) * grain_strength * 0.004;
	vec3 view_position = (VIEW_MATRIX * vec4(world_position, 1.0)).xyz;
	vec3 dx = dFdx(view_position);
	vec3 dy = dFdy(view_position);
	vec3 rx = cross(dy, NORMAL);
	vec3 ry = cross(NORMAL, dx);
	float determinant = dot(dx, rx);
	vec3 gradient = sign(determinant) * (dFdx(relief) * rx + dFdy(relief) * ry);
	NORMAL = normalize(max(abs(determinant), 0.00000001) * NORMAL - gradient);
	ROUGHNESS = clamp(mix(surface_roughness, orm.g, 0.30) + (aggregate - 0.5) * 0.04, 0.78, 0.98);
	AO = mix(1.0, orm.r, 0.55);
	METALLIC = 0.0;
	SPECULAR = 0.24;
	// Rain film. Paving drains better than the road, so it stays satin.
	float puddle = smoothstep(0.56, 0.7, mineral_noise(p * 0.5 + vec2(7.0, 3.0)));
	float film = wetness * (0.5 + 0.5 * puddle);
	ALBEDO *= 1.0 - 0.42 * film;
	ROUGHNESS = mix(ROUGHNESS, mix(0.34, 0.1, puddle), film);
	SPECULAR = mix(SPECULAR, 0.55, film);
}
