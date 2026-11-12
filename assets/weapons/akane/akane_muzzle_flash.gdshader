shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float life : hint_range(0.0, 1.0) = 0.0;
uniform float shot_seed = 0.0;
varying vec2 muzzle_offset;
varying vec2 bore_projection;

void vertex() {
	// Project the bore onto the flash card so its jet foreshortens in ADS.
	vec3 bore = -normalize(MODEL_MATRIX[2].xyz);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	bore_projection = vec2(dot(bore, right), dot(bore, up));
	float centre = 0.060;
	muzzle_offset = VERTEX.xy + bore_projection * centre;
	vec4 origin = vec4(MODEL_MATRIX[3].xyz + bore * centre, 1.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), INV_VIEW_MATRIX[2], origin);
}

float cell(vec2 p) {
	vec3 h = fract(p.xyx * vec3(0.1031, 0.1030, 0.0973));
	h += dot(h, h.yzx + 33.33);
	return fract((h.x + h.y) * h.z);
}

float turbulence(vec2 p) {
	vec2 i = floor(p);
	vec2 w = fract(p);
	w = w * w * (3.0 - 2.0 * w);
	return mix(mix(cell(i), cell(i + vec2(1, 0)), w.x),
			mix(cell(i + vec2(0, 1)), cell(i + vec2(1)), w.x), w.y);
}

void fragment() {
	// Integrate the brief, irregular gas envelope across a bodycam exposure.
	// The core stays at the bore; weaker burning gas travels down its axis.
	float age = 1.0 - life;
	vec2 seed = vec2(sin(shot_seed * 1.71), cos(shot_seed * 3.15));
	vec2 p = muzzle_offset;
	vec2 axis = bore_projection;
	float side_view = length(axis);
	vec2 along = side_view > 0.001 ? axis / side_view : vec2(0.0, 1.0);
	vec2 across = vec2(-along.y, along.x);
	vec2 centre = axis * (0.026 + 0.028 * age) + seed * 0.004;
	vec2 rel = p - centre;
	float stretch = 1.0 + 1.35 * side_view;
	vec2 gas_point = vec2(dot(rel, across), dot(rel, along) / stretch);
	float grain = turbulence(p * 105.0 + seed * 13.0 + age * 0.7);
	float fine = turbulence(p * 245.0 - seed * 7.0);
	float outline = 0.035 + 0.019 * (grain - 0.5) + 0.008 * (fine - 0.5);
	float distance_to_edge = length(gas_point) / outline;
	float envelope = 1.0 - smoothstep(0.27, 1.58, distance_to_edge);
	float core = 1.0 - smoothstep(0.006, 0.030, length(gas_point));
	float jet = 1.0 - smoothstep(0.004, 0.018, length(p - axis * (0.067 + age * 0.015)));
	float hot = max(core, jet * 0.85);
	float exposure = smoothstep(0.0, 0.85, life);
	vec3 amber = vec3(1.0, 0.47, 0.16);
	vec3 ivory = vec3(1.0, 0.94, 0.78);
	vec3 flame = mix(amber, ivory, hot);
	ALBEDO = flame;
	EMISSION = flame * (0.48 + 2.35 * hot);
	ALPHA = max(hot, envelope * (0.48 + 0.48 * grain)) * exposure;
}
