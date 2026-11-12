shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

uniform int rounds = 0;
uniform bool magazine_empty = false;
uniform bool bodycam_feed = false;

// Reconstruct the readout a hair above its emitter in the chest-camera feed.
// Local depth gives it parallax as the slide moves; the sights still occlude it.
void vertex() {
	if (bodycam_feed) {
		VERTEX.z += 0.0018;
	}
}

// Clockwise from the top, with the middle bar in bit six.
const int MASKS[10] = {63, 6, 91, 79, 102, 109, 125, 7, 127, 111};

float bar(vec2 p, vec2 center, bool vertical, float half_length) {
	vec2 q = abs(p - center);
	if (vertical) {
		q = q.yx;
	}
	// Narrow the ends so neighbouring segments leave a small diagonal joint.
	return max(q.y - 0.090, q.x + 0.42 * q.y - half_length);
}

float digit(vec2 p, int value) {
	int bits = MASKS[value];
	float d = 2.0;
	if ((bits & 1) != 0)  { d = min(d, bar(p, vec2(0.0, -0.82), false, 0.365)); }
	if ((bits & 2) != 0)  { d = min(d, bar(p, vec2(0.38, -0.41), true, 0.378)); }
	if ((bits & 4) != 0)  { d = min(d, bar(p, vec2(0.38, 0.41), true, 0.378)); }
	if ((bits & 8) != 0)  { d = min(d, bar(p, vec2(0.0, 0.82), false, 0.365)); }
	if ((bits & 16) != 0) { d = min(d, bar(p, vec2(-0.38, 0.41), true, 0.378)); }
	if ((bits & 32) != 0) { d = min(d, bar(p, vec2(-0.38, -0.41), true, 0.378)); }
	if ((bits & 64) != 0) { d = min(d, bar(p, vec2(0.0), false, 0.365)); }
	return d;
}

void fragment() {
	int count = clamp(rounds, 0, 99);
	bool tens = UV.x < 0.5;
	vec2 p = vec2((fract(UV.x * 2.0) - 0.5) * 1.36, (UV.y - 0.405) * 2.48);
	float d = digit(p, tens ? count / 10 : count % 10);
	// Keep the white strokes readable at chest-camera distance. Confine the
	// blue-white optical fringe to the strokes so the plate stays transparent.
	float aa = clamp(0.5 * fwidth(d), 0.008, 0.16);
	float ink = 1.0 - smoothstep(-aa, aa, d);
	float rim = 1.0 - smoothstep(0.008, 0.082 + aa, d);
	vec3 edge = bodycam_feed ? vec3(0.42, 0.77, 0.92) : vec3(0.90);
	vec3 digits = mix(edge, vec3(1.30, 1.35, 1.36), ink);
	float digit_alpha = max(ink, rim * (bodycam_feed ? 0.29 : 0.10));

	// The rear glass is 23 by 14 in the model. Correct its UV aspect for a round lens.
	vec2 lens_uv = (UV - vec2(0.5, 0.862)) * vec2(23.0 / 14.0, 1.0);
	float radius = length(lens_uv);
	float lens_aa = clamp(0.5 * fwidth(radius), 0.002, 0.055);
	float lens = 1.0 - smoothstep(0.087 - lens_aa, 0.087 + lens_aa, radius);
	float center = 1.0 - smoothstep(0.024, 0.085, radius);
	vec3 lens_color = magazine_empty
		? mix(vec3(0.46, 0.007, 0.004), vec3(1.45, 0.027, 0.012), center)
		: mix(vec3(0.055, 0.052, 0.050), vec3(0.015, 0.012, 0.012), center);
	ALBEDO = mix(digits, lens_color, step(digit_alpha, lens));
	ALPHA = max(digit_alpha, lens);
}
