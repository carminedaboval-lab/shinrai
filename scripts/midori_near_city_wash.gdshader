shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded, shadows_disabled;
// Light thrown up a wall from a small lamp at its foot, after dark. UV 0-1 across the wall
// patch, with v = 0 at the top; COLOR.rgb is the lamp.
uniform float night = 0.0;
uniform float day_level = 0.0; // Above 0, the lamp stays on by day too, this strong.
uniform float throat = 0.16; // How wide the light already is at the lamp: a downlight well off the wall starts broad.
void fragment(){
	float u = (UV.x - 0.5) * 2.0;
	float v = 1.0 - UV.y;
	float spread = throat + (1.0 - throat) * v;
	float beam = exp(-u * u / (spread * spread) * 2.4);
	float fade = pow(clamp(1.0 - v, 0.0, 1.0), 1.5) * smoothstep(0.0, 0.05, v);
	ALBEDO = COLOR.rgb * beam * fade * max(night, day_level);
}
