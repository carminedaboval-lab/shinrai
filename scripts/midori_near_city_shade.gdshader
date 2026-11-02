shader_type spatial;
render_mode blend_mul, depth_draw_never, cull_back, unshaded, shadows_disabled, fog_disabled;
// The dark a heavy thing keeps round its foot, where the room's lamps cast no shadow of their
// own. Multiplied over the floor, shine and all. COLOR.a is how much light gets through.
void fragment(){
	ALBEDO = vec3(smoothstep(0.0, 1.0, COLOR.a));
}
