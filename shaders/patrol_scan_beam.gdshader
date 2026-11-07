shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Drone searchlight cone. UV.y runs from the apex (0) to the open end (1).

uniform vec4 beam_color : source_color = vec4(.8, .9, 1.0, 1.0);
uniform float strength = .16;

void fragment() {
	float along = 1.0 - smoothstep(.0, 1.0, UV.y);
	float facing = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.6);
	ALBEDO = beam_color.rgb;
	ALPHA = along * facing * strength;
}
