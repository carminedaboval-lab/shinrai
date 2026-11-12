shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec2 surface_mm;
varying float edge;
varying float skirt;

void vertex() {
	surface_mm = VERTEX.xy * 1000.0;
	// The narrow sloping perimeter exposes a little more of the underlying metal.
	edge = 1.0 - smoothstep(0.68, 0.98, abs(NORMAL.z));
	skirt = 1.0 - smoothstep(0.025, 0.14, abs(NORMAL.z));
}

float hash(vec2 cell) {
	vec3 h = fract(cell.xyx * vec3(0.1031, 0.1030, 0.0973));
	h += dot(h, h.yzx + 33.33);
	return fract((h.x + h.y) * h.z);
}

float grain_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), f.x),
			mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1)), f.x), f.y);
}

// Shallow scuffs cross the finer lengthwise brushing at irregular angles.
float scuffs(vec2 p, float pixel_width) {
	vec2 spacing = vec2(9.2, 2.0);
	vec2 tile = p / spacing;
	vec2 cell = floor(tile);
	vec2 local = (fract(tile) - 0.5) * spacing;
	float seed = hash(cell + vec2(5.0, 13.0));
	float taper = max(0.0, 1.0 - abs(local.x) / (1.6 + 2.6 * seed));
	float slope = (hash(cell) - 0.5) * 0.34;
	float offset = (seed - 0.5) * 0.34 + local.x * slope + 0.003 * local.x * local.x;
	float aa = 0.5 * (pixel_width + abs(slope) * fwidth(p.x));
	float width = (0.025 + 0.060 * seed) * taper;
	float coverage = 1.0 - smoothstep(max(0.0, width - aa), width + aa, abs(local.y - offset));
	return coverage * min(1.0, width / max(aa, 0.001)) * smoothstep(0.56, 0.84, seed);
}

void fragment() {
	float pixel_width = max(0.001, fwidth(surface_mm.y));
	float brushing = grain_noise(surface_mm * vec2(0.12, 4.0)) - 0.5;
	brushing *= 1.0 - smoothstep(0.10, 0.45, pixel_width);
	float patina = grain_noise(surface_mm * vec2(0.04, 0.34)) - 0.5;
	float scratch = scuffs(surface_mm, pixel_width);
	// The two upper facets retain more of their graphite finish than the long sill.
	float upper = step(15.0, surface_mm.y);
	vec3 finish = mix(vec3(0.143, 0.135, 0.130), vec3(0.120, 0.115, 0.111), upper);
	vec3 exposed = vec3(0.36, 0.34, 0.32);
	vec3 brushed_face = mix(finish * (1.0 + 0.30 * brushing + 0.12 * patina),
			exposed, clamp(0.30 * edge + 0.86 * scratch, 0.0, 1.0));
	// The return inside the serrations is blackened and stays in shadow.
	ALBEDO = mix(brushed_face, vec3(0.027, 0.025, 0.024), skirt);
	METALLIC = mix(0.80, 0.35, skirt);
	ROUGHNESS = mix(0.46 + 0.14 * brushing + 0.08 * patina - 0.10 * edge - 0.10 * scratch, 0.67, skirt);
	ANISOTROPY = 0.42;
	ANISOTROPY_FLOW = vec2(1.0, 0.0);

	// Black vertices mark the recessed seam between the strip and the slide.
	if (COLOR.r < 0.5) {
		ALBEDO = vec3(0.007, 0.008, 0.009);
		METALLIC = 0.12;
		ROUGHNESS = 0.81;
		SPECULAR = 0.18;
		ANISOTROPY = 0.0;
		AO = 0.45;
		AO_LIGHT_AFFECT = 0.45;
	}
}
