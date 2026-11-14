shader_type spatial;

// Claude's pavement mesh carries metres across and along each street edge.
// Both finishes use existing material samples; no height displacement or painted seams.
uniform sampler2D surface_color : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_orm : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float sample_metres = 1.0;
uniform vec3 color_gain = vec3(1.0);
uniform vec3 binder = vec3(0.0);
uniform float patina_strength = 0.14;

float random_at(vec2 cell) {
	vec3 p = fract(vec3(cell.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float mottling(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(random_at(cell), random_at(cell+vec2(1.0,0.0)), f.x),
	           mix(random_at(cell+vec2(0.0,1.0)), random_at(cell+vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV / sample_metres;
	vec3 grain = texture(surface_color, p).rgb;
	vec3 orm = texture(surface_orm, p).rgb;
	// Uneven weathering across several metres, with finer worn patches over it.
	float patch = 0.72 * mottling(UV * 0.38) + 0.28 * mottling(UV * 1.41 + 11.7);
	float stain = smoothstep(0.35, 0.79, patch);
	ALBEDO = (grain * color_gain + binder) * (1.0 - patina_strength * stain);
	ROUGHNESS = clamp(0.4 + 0.56 * orm.g - 0.055 * stain, 0.65, 0.97);
	AO = mix(1.0, orm.r, 0.35);
}
