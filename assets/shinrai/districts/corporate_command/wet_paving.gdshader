shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Honed plaza stone: 1.2 x 0.6 m in running bond with bevelled edges, cut close
// to the main street's stone tone so the district does not read as black slabs.
uniform vec4 stone_color : source_color = vec4(0.60, 0.59, 0.555, 1.0);
// Dry by default; a future rain system can raise this.
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
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
	float row = floor(p.y / 0.6);
	vec2 slab = vec2(p.x + mod(row, 2.0) * 0.6, p.y) / vec2(1.2, 0.6);
	vec2 stone = floor(slab);
	vec2 cell = fract(slab);
	vec2 edge = min(cell, 1.0 - cell) * vec2(1.2, 0.6);
	float border_distance = min(edge.x, edge.y);
	float edge_aa = max(fwidth(border_distance) * 0.8, 0.003);
	float joint = 1.0 - smoothstep(0.006 - edge_aa, 0.006 + edge_aa, border_distance);
	float slab_tone = mix(0.84, 1.1, hash21(stone));
	vec3 slab_tint = mix(vec3(1.03, 1.0, 0.95), vec3(0.97, 1.0, 1.03), hash21(stone + vec2(7.3, 2.1)));
	// Mineral grain fades out before it can shimmer at distance.
	float grain = noise21(p * 9.0) * 0.5 + noise21(p * 23.0) * 0.3 + noise21(p * 61.0) * 0.2;
	grain = mix(0.5, grain, 1.0 - smoothstep(0.015, 0.09, fwidth(p.x)));
	float broad = noise21(p * 0.09) * 0.65 + noise21(p * 0.26) * 0.35;
	float stain = smoothstep(0.38, 0.74, broad);
	float puddle = smoothstep(0.34, 0.68, broad) * wetness;
	ALBEDO = stone_color.rgb * slab_tint * slab_tone * mix(0.86, 1.1, grain) * (1.0 - stain * 0.13)
		* mix(0.9, 0.56, puddle) * (1.0 - joint * 0.68);
	// Edges fall away into the joint, and no two stones sit perfectly level.
	vec2 away = edge.x < edge.y ? vec2(sign(cell.x - 0.5), 0.0) : vec2(0.0, sign(cell.y - 0.5));
	float bevel = 1.0 - smoothstep(0.004, 0.022, border_distance);
	vec2 tilt = (vec2(hash21(stone + vec2(3.1, 9.2)), hash21(stone + vec2(5.7, 1.4))) - 0.5) * 0.012;
	vec3 world_normal = normalize(vec3(away.x * bevel * 0.5 + tilt.x, 1.0, away.y * bevel * 0.5 + tilt.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	ROUGHNESS = mix(0.8, mix(0.28, 0.11, puddle), wetness) + joint * 0.12;
	METALLIC = 0.0;
	SPECULAR = mix(0.3, 0.5, wetness);
	CLEARCOAT = wetness * 0.35 * (1.0 - joint);
	CLEARCOAT_ROUGHNESS = 0.18;
}
