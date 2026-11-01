shader_type spatial;
render_mode cull_disabled;
// Paper-thin cut shapes with a hard edge: UV is atlas space, the atlas's alpha trims them.
uniform float night = 0.0;
uniform float glow = 0.0;
uniform float day_glow = 0.0;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
void fragment(){
	vec4 face = texture(atlas, UV);
	ALBEDO = face.rgb * COLOR.rgb * mix(vec3(1.0), vec3(0.62, 0.5, 0.42), night);
	ROUGHNESS = 0.6;
	EMISSION = face.rgb * COLOR.rgb * mix(day_glow, glow, night);
	ALPHA = face.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
