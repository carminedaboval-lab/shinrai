shader_type spatial;

// Poly Haven smoked walnut, mapped at its documented 1m source size.
uniform sampler2D timber_grain : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D timber_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D timber_roughness_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float timber_brightness = 1.2;
uniform float timber_contrast = 0.5;
uniform float timber_chroma = 1.0;

void fragment() {
	vec3 source = texture(timber_grain,UV).rgb;
	// Preserve sourced grain while letting the finish, joinery and silhouette
	// carry scale. The coarse mip provides the same wood's mean colour.
	vec3 mean_wood = textureLod(timber_grain,UV,10.0).rgb;
	vec3 finish = mix(mean_wood,source,timber_contrast);
	finish = mix(vec3(dot(finish,vec3(0.2126,0.7152,0.0722))),finish,timber_chroma);
	ALBEDO = finish*timber_brightness;
	ROUGHNESS = clamp(texture(timber_roughness_map,UV).r*.55+.30,.50,.90);
	NORMAL_MAP = texture(timber_normal,UV).rgb;
	NORMAL_MAP_DEPTH = 0.08;
	SPECULAR = 0.25;
}
