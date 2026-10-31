shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Plaza paving after Tokyo Midtown: tatami-proportioned 2:1 cream granite, with a
// slim band of black granite after every second row.
uniform vec4 stone_color : source_color = vec4(0.80, 0.76, 0.66, 1.0);
uniform vec4 band_color : source_color = vec4(0.17, 0.17, 0.18, 1.0);
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
	float course = floor(p.y / 2.1);
	float within = p.y - course * 2.1;
	float band = step(1.8, within);
	float depth = mix(0.9, 0.3, band);
	float row = course * 3.0 + floor(min(within, 1.79) / 0.9) + band * 2.0;
	float across = (p.x + mod(row, 2.0) * 0.9) / 1.8;
	vec2 stone = vec2(floor(across), row);
	vec2 cell = vec2(fract(across), mix(fract(within / 0.9), (within - 1.8) / 0.3, band));
	vec2 edge = min(cell, 1.0 - cell) * vec2(1.8, depth);
	float border_distance = min(edge.x, edge.y);
	float edge_aa = max(fwidth(border_distance) * 0.8, 0.003);
	float joint = 1.0 - smoothstep(0.005 - edge_aa, 0.005 + edge_aa, border_distance);
	float slab_tone = mix(0.92, 1.06, hash21(stone));
	vec3 slab_tint = mix(vec3(1.02, 1.0, 0.96), vec3(0.98, 1.0, 1.02), hash21(stone + vec2(7.3, 2.1)));
	// Granite crystal, fading out before it can shimmer at distance.
	float grain = noise21(p * 31.0) * 0.5 + noise21(p * 83.0) * 0.5;
	grain = mix(0.5, grain, 1.0 - smoothstep(0.01, 0.06, fwidth(p.x)));
	float broad = noise21(p * 0.09) * 0.65 + noise21(p * 0.26) * 0.35;
	float stain = smoothstep(0.42, 0.78, broad);
	float puddle = smoothstep(0.34, 0.68, broad) * wetness;
	vec3 base = mix(stone_color.rgb, band_color.rgb, band);
	ALBEDO = base * slab_tint * slab_tone * mix(0.9, 1.08, grain) * (1.0 - stain * 0.1)
		* mix(0.9, 0.56, puddle) * (1.0 - joint * 0.6);
	// Edges fall away into the joint, and no two stones sit perfectly level.
	vec2 away = edge.x < edge.y ? vec2(sign(cell.x - 0.5), 0.0) : vec2(0.0, sign(cell.y - 0.5));
	float bevel = 1.0 - smoothstep(0.003, 0.016, border_distance);
	vec2 tilt = (vec2(hash21(stone + vec2(3.1, 9.2)), hash21(stone + vec2(5.7, 1.4))) - 0.5) * 0.01;
	vec3 world_normal = normalize(vec3(away.x * bevel * 0.5 + tilt.x, 1.0, away.y * bevel * 0.5 + tilt.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	// The black band is honed, the cream stone flamed.
	ROUGHNESS = mix(mix(0.78, 0.46, band), mix(0.28, 0.11, puddle), wetness) + joint * 0.12;
	METALLIC = 0.0;
	SPECULAR = mix(0.3, 0.5, wetness);
	CLEARCOAT = wetness * 0.35 * (1.0 - joint);
	CLEARCOAT_ROUGHNESS = 0.18;
}
