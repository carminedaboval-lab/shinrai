shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// A blossom spray in a cherry canopy. Each card is lit as part of the round crown,
// not by its own random tilt, so the tree reads as one soft cloud of flowers.
uniform sampler2D blossom : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 pale_pink : source_color = vec3(0.93, 0.80, 0.87);
varying vec3 outward;

void vertex() {
	outward = INSTANCE_CUSTOM.xyz * 2.0 - 1.0;
	float sway = sin(TIME * 1.1 + INSTANCE_CUSTOM.w * 40.0) * 0.012;
	VERTEX += vec3(sway, 0.0, sway * 0.6) * UV.y;
}

void fragment() {
	vec4 flower = texture(blossom, UV);
	// Somei Yoshino is nearly white with a pink blush, and warm sun deepens it further.
	float shade = dot(flower.rgb, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(flower.rgb, pale_pink * clamp(shade * 1.5, 0.55, 1.05), 0.82) * COLOR.rgb;
	ALPHA = flower.a;
	// Mipmapping thins the alpha with distance, so the cut-off eases to hold the cloud together.
	ALPHA_SCISSOR_THRESHOLD = mix(0.42, 0.14, clamp(length(fwidth(UV)) * 22.0, 0.0, 1.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(outward, 0.0)).xyz);
	ROUGHNESS = 0.82;
	SPECULAR = 0.15;
	BACKLIGHT = ALBEDO * 0.22;
}
