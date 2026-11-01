shader_type spatial;
// Seamless LED strip: one line of an atlas, sliding along the board for as long as it runs.
uniform float night = 0.0;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 strip = vec4(0.0, 0.0, 1.0, 1.0); // x, y, width, height in the atlas.
uniform float speed = 0.03;
void fragment(){
	vec2 raw = vec2(UV.x + TIME * speed, UV.y);
	vec2 at = strip.xy + vec2(fract(raw.x), raw.y) * strip.zw;
	vec3 face = textureGrad(atlas, at, dFdx(raw) * strip.zw, dFdy(raw) * strip.zw).rgb;
	ALBEDO = vec3(0.01);
	ROUGHNESS = 0.3;
	EMISSION = face * mix(1.0, 1.15, night);
}
