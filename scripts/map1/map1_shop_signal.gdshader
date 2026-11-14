shader_type spatial;

// Only the live pedestrian figure and red lens are luminous. The casing and
// the unlit lenses stay dark under the same sky as the pole.
void fragment() {
	vec3 c = COLOR.rgb;
	ALBEDO = c;
	ROUGHNESS = 0.78;
	float red_lens = step(0.90, c.r) * step(c.g, 0.40);
	float green_figure = step(0.65, c.g) * step(c.r, c.g * 0.74);
	EMISSION = c * max(red_lens, green_figure) * 0.75;
}
