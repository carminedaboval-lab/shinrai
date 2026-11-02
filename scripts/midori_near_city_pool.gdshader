shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded, shadows_disabled, fog_disabled;
// Light that lands from a lamp or a screen that is never off, so it reads the same at any hour:
// there is no night here. UV 0-1 across the patch, v = 0 at its top edge; COLOR.rgb is the source.
// fan 0: a round pool under a dome, brightest in the middle.
// fan 1: thrown from the top edge, narrow at the source: a wall scallop, or a screen's spill.
uniform float fan = 0.0;
void fragment(){
	vec2 p = (UV - 0.5) * 2.0;
	float pool = pow(clamp(1.0 - length(p), 0.0, 1.0), 1.6);
	float spread = 0.2 + 0.8 * UV.y;
	float beam = exp(-p.x * p.x / (spread * spread) * 2.4);
	beam *= pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.5) * smoothstep(0.0, 0.06, UV.y);
	ALBEDO = COLOR.rgb * mix(pool, beam, fan);
}
