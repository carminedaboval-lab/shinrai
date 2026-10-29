shader_type spatial;
render_mode cull_disabled;

// The source bench combines timber and charcoal metal in one BakedMaterial
// atlas. Preserve its original UVs and metal pixels; replace warm wood only.
uniform sampler2D original_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D source_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D source_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D source_metallic : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 source_color_factor : source_color = vec4(1.0);
uniform float source_normal_depth = 1.0;
uniform float source_roughness_factor = 1.0;
uniform float source_metallic_factor = 1.0;
uniform float source_specular = 0.5;
uniform sampler2D timber_grain : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D timber_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D timber_roughness_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 timber_tint : source_color = vec4(0.72,0.54,0.34,1.0);
varying vec3 metre_position;
varying vec3 source_surface_normal;
varying mat3 source_to_view;

void vertex() {
	metre_position = VERTEX;
	source_surface_normal = NORMAL;
	source_to_view = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec3 original = texture(original_albedo,UV).rgb*source_color_factor.rgb;
	// Inspected source metal is neutral charcoal; timber is distinctly warm.
	// Use original colour, never the new finish colour, for eligibility.
	float warmth = (original.r-original.b)/max(original.r,0.005);
	float wood = smoothstep(0.12,0.26,warmth)
		*smoothstep(1.04,1.12,original.r/max(original.g,0.005));
	vec3 n = normalize(source_surface_normal);
	bool top = abs(n.y)>abs(n.z);
	bool end = abs(n.x)>max(abs(n.y),abs(n.z));
	vec2 metres = vec2(top ? metre_position.z : metre_position.y,metre_position.x);
	if (end) metres=metre_position.zy;
	vec2 grain_uv = metres/vec2(0.90,2.4);
	vec3 grain_source = texture(timber_grain,grain_uv).rgb;
	vec3 grain_mean = max(textureLod(timber_grain,grain_uv,10.0).rgb,vec3(0.015));
	vec3 grain = clamp(mix(vec3(1.0),grain_source/grain_mean,0.90),vec3(0.40),vec3(1.65));
	ALBEDO = mix(original,timber_tint.rgb*grain,wood);
	float old_rough = texture(source_roughness,UV).g*source_roughness_factor;
	float new_rough = clamp(0.54+texture(timber_roughness_map,grain_uv).r*0.30,0.58,0.86);
	ROUGHNESS = mix(old_rough,new_rough,wood);
	METALLIC = texture(source_metallic,UV).b*source_metallic_factor*(1.0-wood);
	SPECULAR = mix(source_specular,0.24,wood);
	// Normal imports may retain only RG. Never treat a missing/repurposed
	// blue channel as negative Z: reconstruct the positive tangent hemisphere.
	vec2 old_xy = (texture(source_normal,UV).rg*2.0-1.0)*source_normal_depth;
	vec3 old_map = vec3(old_xy,sqrt(max(0.00001,1.0-dot(old_xy,old_xy))));
	vec3 old_view = normalize(TANGENT*old_map.x+BINORMAL*old_map.y+NORMAL*old_map.z);
	vec2 new_xy = (texture(timber_normal,grain_uv).rg*2.0-1.0)*0.19;
	vec3 new_map = vec3(new_xy,sqrt(max(0.00001,1.0-dot(new_xy,new_xy))));
	vec3 new_local = top ? vec3(new_map.y,new_map.z*sign(n.y),new_map.x)
		: vec3(new_map.y,new_map.x,new_map.z*sign(n.z));
	if (end) new_local=vec3(new_map.z*sign(n.x),new_map.y,new_map.x);
	NORMAL = normalize(mix(old_view,normalize(source_to_view*new_local),wood));
}
