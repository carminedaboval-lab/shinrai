shader_type spatial;

// Court-only finish. Original installed Fine Grained Wood source maps are
// unchanged. UVs are physical metres: U across the board, V along its grain.
uniform sampler2D timber_grain : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D timber_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D timber_roughness_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 timber_tint : source_color = vec4(0.557,0.522,0.455,1.0);
uniform float timber_contrast = 0.30;
uniform bool length_in_u = false;
uniform bool vertical_cladding = false;
uniform float normal_depth = 0.19;
varying vec3 timber_position;
varying vec3 timber_face_normal;

void vertex() {
	timber_position = VERTEX;
	timber_face_normal = NORMAL;
}

void fragment() {
	// The sourced fine fibres run vertically. A 0.90m x 2.4m sample
	// supplies fine grain without metre-wide walnut swirls on 155mm boards.
	vec2 physical_uv = length_in_u ? UV.yx : UV;
	if (vertical_cladding) {
		// Merged board fields already contain construction positions. Keep
		// grain vertical even on short cuts, and phase continuous at openings.
		physical_uv = vec2(abs(timber_face_normal.x)>abs(timber_face_normal.z)
			? timber_position.z : timber_position.x,timber_position.y);
	}
	vec2 grain_uv = physical_uv / vec2(0.90,2.4);
	vec3 source = texture(timber_grain,grain_uv).rgb;
	vec3 mean_wood = max(textureLod(timber_grain,grain_uv,10.0).rgb,vec3(0.015));
	vec3 grain = clamp(mix(vec3(1.0),source/mean_wood,timber_contrast),vec3(0.40),vec3(1.65));
	ALBEDO = timber_tint.rgb*grain;
	ROUGHNESS = clamp(0.54+texture(timber_roughness_map,grain_uv).r*0.30,0.58,0.86);
	vec3 normal_sample = texture(timber_normal,grain_uv).rgb;
	NORMAL_MAP = length_in_u ? normal_sample.grb : normal_sample;
	NORMAL_MAP_DEPTH = normal_depth;
	SPECULAR = 0.24;
}
