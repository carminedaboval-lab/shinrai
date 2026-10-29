shader_type spatial;
render_mode cull_disabled;

// Metre-scaled fine mineral grain; no broad cloudy concrete texture.
uniform vec4 mineral_color : source_color = vec4(0.62, 0.61, 0.57, 1.0);
uniform float grain_strength : hint_range(0.0, 0.5) = 0.08;
uniform float aggregate_scale = 95.0;
uniform float surface_roughness = 0.94;
uniform float paint_wear : hint_range(0.0, 1.0) = 0.0;
uniform float stone_weather = 0.0;
uniform float road_weather = 0.0;
varying vec3 world_position;

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
}

void fragment() {
	// Keep coordinates local and rotate the lattice: large world-space hash
	// products lost float precision and produced straight streaks in the game.
	vec2 local_p = world_position.xz - vec2(0.0, 174.0);
	vec2 p = vec2(local_p.x * 0.81915 - local_p.y * 0.57358,
		local_p.x * 0.57358 + local_p.y * 0.81915);
	vec2 grain_uv = p * aggregate_scale;
	// Fade subpixel grain to its mean to prevent distant sparkle or moire.
	float grain_visibility = 1.0 - smoothstep(0.6, 1.7, max(length(dFdx(grain_uv)), length(dFdy(grain_uv))));
	float fine = mix(0.5, mineral_noise(grain_uv), grain_visibility);
	vec2 aggregate_uv = p * 23.0;
	float aggregate_visibility = 1.0 - smoothstep(0.6, 1.7, max(length(dFdx(aggregate_uv)), length(dFdy(aggregate_uv))));
	float aggregate = mix(0.5, mineral_noise(aggregate_uv), aggregate_visibility);
	float grain = ((fine - 0.5) * 1.6 + (aggregate - 0.5) * 0.65) * grain_strength;
	vec2 wear_uv = p * 34.0;
	float wear_visibility = 1.0 - smoothstep(0.6, 1.7, max(length(dFdx(wear_uv)), length(dFdy(wear_uv))));
	float wear = mix(0.12, smoothstep(0.63, 0.88, mineral_noise(wear_uv)), wear_visibility) * paint_wear;
	// UVs belong to each stone before batching, so weathering follows its edges.
	float edge_distance = min(min(UV.x, 1.0 - UV.x) * 0.60, min(UV.y, 1.0 - UV.y) * 0.80);
	float edge = 1.0 - smoothstep(0.002, 0.027, edge_distance);
	float stone_stain = smoothstep(0.57, 0.85, mineral_noise(p * 1.8 + vec2(31.0, 9.0)));
	float weather = stone_weather * (edge * (0.10 + 0.06 * mineral_noise(p * 9.0)) + stone_stain * 0.085);
	// Dirt gathers along the two actual road gutters rather than everywhere.
	float gutter_distance = min(abs(world_position.z - 184.17), abs(world_position.z - 189.83));
	float gutter_dirt = (1.0 - smoothstep(0.05, 0.42, gutter_distance)) * (0.04 + 0.09 * mineral_noise(p * 4.5));
	float local_paint_wear = smoothstep(0.53, 0.82, mineral_noise(p * 3.1 + vec2(17.0, 4.0)));
	ALBEDO = mineral_color.rgb * (1.0 + grain) * (1.0 - wear * (0.12 + 0.24 * local_paint_wear) - weather - road_weather * gutter_dirt);
	// Small physical surface relief using screen-space surface gradients;
	// works on batched meshes without requiring a tangent vertex channel.
	float relief = ((fine - 0.5) * 0.55 + (aggregate - 0.5)) * grain_strength * 0.004;
	vec3 view_position = (VIEW_MATRIX * vec4(world_position, 1.0)).xyz;
	vec3 dx = dFdx(view_position);
	vec3 dy = dFdy(view_position);
	vec3 rx = cross(dy, NORMAL);
	vec3 ry = cross(NORMAL, dx);
	float determinant = dot(dx, rx);
	vec3 gradient = sign(determinant) * (dFdx(relief) * rx + dFdy(relief) * ry);
	NORMAL = normalize(max(abs(determinant), 0.00000001) * NORMAL - gradient);
	ROUGHNESS = clamp(surface_roughness + (aggregate - 0.5) * 0.07, 0.7, 1.0);
	SPECULAR = 0.22;
}
