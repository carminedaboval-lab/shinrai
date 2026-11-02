shader_type spatial;
render_mode unshaded, shadows_disabled;
// A booth's globe: opal glass with a lamp inside. The heart burns out and the rim falls away to a
// soft grey, the same at any hour, so it reads as a ball of light and not a white disc.
uniform float heart = 2.4;
uniform float rim = 0.58;
void fragment(){
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = COLOR.rgb * mix(rim, heart, smoothstep(0.05, 0.8, facing));
}
