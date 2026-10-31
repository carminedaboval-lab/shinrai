shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// World-space stone for the gardens. kind 0 is poured permeable path, kind 1 is
// granite, kind 2 is moving water.
uniform int kind = 0;
uniform vec4 tone : source_color = vec4(0.62, 0.56, 0.46, 1.0);
varying vec3 world_position;
varying vec3 world_normal;

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
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = abs(world_normal.y) > 0.5 ? world_position.xz : abs(world_normal.x) > 0.5 ? world_position.zy : world_position.xy;
	float fine = 1.0 - smoothstep(0.01, 0.06, fwidth(p.x));
	if (kind == 2) {
		vec2 flow = vec2(0.0, TIME * 0.35);
		float ripple_a = noise21((p + flow) * 13.0) - 0.5;
		float ripple_b = noise21((p - flow * 0.6) * 29.0) - 0.5;
		vec3 n = normalize(vec3(ripple_a * 0.022, 1.0, ripple_b * 0.022));
		ALBEDO = tone.rgb * 0.22;
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
		ROUGHNESS = 0.16;
		SPECULAR = 0.42;
	} else if (kind == 1) {
		float crystal = noise21(p * 47.0) * 0.5 + noise21(p * 120.0) * 0.5;
		ALBEDO = tone.rgb * mix(1.0, mix(0.84, 1.14, crystal), fine) * mix(0.94, 1.04, noise21(p * 0.9));
		ROUGHNESS = 0.52;
		SPECULAR = 0.4;
	} else {
		// Resin-bound gravel: small warm stones with panel joints every six metres.
		float gravel = noise21(p * 70.0) * 0.6 + noise21(p * 170.0) * 0.4;
		float dark = 1.0 - smoothstep(0.34, 0.46, noise21(p * 110.0));
		float joint = 1.0 - smoothstep(0.004, 0.012, abs(fract(p.x / 6.0) - 0.5) * 6.0 - 2.99);
		vec3 stone = tone.rgb * mix(1.0, mix(0.82, 1.16, gravel) * (1.0 - dark * 0.2), fine);
		ALBEDO = stone * mix(0.93, 1.05, noise21(p * 0.4)) * (1.0 - joint * 0.5);
		ROUGHNESS = 0.9;
		SPECULAR = 0.2;
	}
}
