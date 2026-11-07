shader_type spatial;
// Apartment finishes use the existing measured-scale PBR maps, without the
// outdoor shader's rain staining, night colour multiplier or self-lighting.
uniform float night = 0.0;
uniform float tile = 1.0;
uniform float rough_scale = 0.85;
uniform float chroma = 0.3;
uniform float normal_depth = 0.35;
uniform float gain = 1.0;
uniform float lightness = 1.0;
uniform bool floor_joints = false;
uniform sampler2D albedo_map : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

void fragment() {
	vec2 uv = UV / tile;
	vec3 pigment = texture(albedo_map, uv).rgb;
	float luminance = dot(pigment, vec3(0.2126, 0.7152, 0.0722));
	pigment = mix(vec3(luminance), pigment, chroma);
	ALBEDO = clamp(pow(max(pigment, vec3(0.001)), vec3(lightness)) * gain * COLOR.rgb, vec3(0.0), vec3(0.94));
	NORMAL_MAP = texture(normal_map, uv).xyz;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = clamp(texture(rough_map, uv).r * rough_scale, 0.30, 0.96);
	if (floor_joints) {
		// Narrow staggered end joints, in metres. Filter subpixel seams so the
		// floor stays stable in motion; framed artwork never uses this branch.
		float board = floor(UV.x / .20);
		float offset = fract(sin(board * 127.1) * 43758.5453);
		float end = abs(fract((UV.y + offset * 1.45) / 1.45) - .5) * 1.45;
		float footprint = max(fwidth(UV.y), .0005);
		float seam = 1.0 - smoothstep(.0007, .0014 + footprint, end);
		ALBEDO *= (1.0 - .15 * seam) * mix(.97, 1.025, offset);
		ROUGHNESS = clamp(ROUGHNESS + .035 * offset + seam * .12, .30, .94);
	}
	SPECULAR = 0.34;
	AO = COLOR.a;
	AO_LIGHT_AFFECT = 0.20;
}
