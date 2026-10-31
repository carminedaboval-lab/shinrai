shader_type spatial;
render_mode blend_mix, depth_draw_never;
// Lettering stuck to glass or a wall: UV is atlas space, the atlas's alpha cuts the letters.
uniform float night = 0.0;
uniform float glow = 0.0;
uniform float day_glow = 0.0;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
void fragment(){
	vec4 face = texture(atlas, UV);
	ALBEDO = face.rgb * COLOR.rgb * mix(vec3(1.0), vec3(0.42, 0.34, 0.27), night);
	ROUGHNESS = 0.6;
	EMISSION = face.rgb * COLOR.rgb * mix(day_glow, glow, night);
	ALPHA = face.a * COLOR.a;
}
