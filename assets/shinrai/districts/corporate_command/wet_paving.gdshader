shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 stone_color : source_color = vec4(0.25, 0.265, 0.28, 1.0);
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
	float row = floor(p.y / 1.5);
	vec2 slab = vec2(p.x + mod(row, 2.0) * 1.5, p.y) / vec2(3.0, 1.5);
	vec2 cell = fract(slab);
	vec2 edge = min(cell, 1.0 - cell) * vec2(3.0, 1.5);
	float border_distance = min(edge.x, edge.y);
	float edge_aa = max(fwidth(border_distance) * 0.8, 0.004);
	float joint = 1.0 - smoothstep(0.014 - edge_aa, 0.014 + edge_aa, border_distance);
	float slab_tone = mix(0.8, 1.12, hash21(floor(slab)));
	float broad = noise21(p * 0.09) * 0.65 + noise21(p * 0.26) * 0.35;
	float puddle = smoothstep(0.34, 0.68, broad) * wetness;
	ALBEDO = stone_color.rgb * slab_tone * mix(0.9, 0.56, puddle) * (1.0 - joint * 0.46);
	ROUGHNESS = mix(0.82, mix(0.28, 0.11, puddle), wetness) + joint * 0.12;
	METALLIC = 0.0;
	SPECULAR = mix(0.25, 0.5, wetness);
	CLEARCOAT = wetness * 0.35 * (1.0 - joint);
	CLEARCOAT_ROUGHNESS = 0.18;
}
