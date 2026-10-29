shader_type spatial;
render_mode cull_disabled;

// Existing CC0 mineral maps, physical metre projection, property-owned colours.
// One world-height paint break wraps every opening/corner, including after
// static mesh batching. No duplicate wall planes or extra geometry.
uniform sampler2D mineral_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mineral_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mineral_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 upper_tint : source_color = vec4(0.8,0.78,0.72,1.0);
uniform vec4 lower_tint : source_color = vec4(0.7,0.68,0.62,1.0);
uniform float paint_line_world_y = 3.39;
// One repeat remains the provider's documented one metre. No fake masonry grid.
uniform float mineral_normal_strength = 0.52;
uniform float mineral_fine_contrast = 0.94;
uniform float mineral_macro_contrast = 0.10;
uniform float mineral_roughness_center = 0.82;
uniform float mineral_roughness_variation = 0.32;
uniform float ground_world_y = -100.0;
uniform float base_splash_strength = 0.035;
varying vec3 world_position;
varying vec3 world_surface_normal;

void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_surface_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment() {
	vec3 n = normalize(world_surface_normal);
	vec3 weight = pow(abs(n),vec3(16.0));
	weight /= max(weight.x+weight.y+weight.z,0.0001);
	vec2 ux = world_position.zy;
	vec2 uy = world_position.xz;
	vec2 uz = world_position.xy;
	vec3 photo = texture(mineral_color,ux).rgb*weight.x
		+texture(mineral_color,uy).rgb*weight.y
		+texture(mineral_color,uz).rgb*weight.z;
	vec3 mean_surface = max(textureLod(mineral_color,vec2(0.5),10.0).rgb,vec3(0.03));
	vec3 broad = textureLod(mineral_color,ux,5.0).rgb*weight.x
		+textureLod(mineral_color,uy,5.0).rgb*weight.y
		+textureLod(mineral_color,uz,5.0).rgb*weight.z;
	vec3 macro_detail = mix(vec3(1.0),broad/mean_surface,mineral_macro_contrast);
	vec3 fine_detail = mix(vec3(1.0),photo/max(broad,vec3(0.03)),mineral_fine_contrast);
	vec3 detail = clamp(macro_detail*fine_detail,vec3(0.72),vec3(1.28));
	// Antialias a crisp painter's line over about one screen pixel, not a gradient.
	float edge = max(fwidth(world_position.y),0.0005);
	float upper = smoothstep(paint_line_world_y-edge,paint_line_world_y+edge,world_position.y);
	// A slight measured ground splash zone only; protected wall centres stay clean.
	float splash = (1.0-smoothstep(0.04,0.34,world_position.y-ground_world_y))*base_splash_strength;
	ALBEDO = mix(lower_tint.rgb,upper_tint.rgb,upper)*detail*(1.0-splash);
	vec3 nx = texture(mineral_normal,ux).xyz*2.0-1.0;
	vec3 ny = texture(mineral_normal,uy).xyz*2.0-1.0;
	vec3 nz = texture(mineral_normal,uz).xyz*2.0-1.0;
	nx.xy *= mineral_normal_strength;
	ny.xy *= mineral_normal_strength;
	nz.xy *= mineral_normal_strength;
	vec3 normal_world = normalize(vec3(nx.z*sign(n.x),nx.y,nx.x)*weight.x
		+vec3(ny.x,ny.z*sign(n.y),ny.y)*weight.y
		+vec3(nz.x,nz.y,nz.z*sign(n.z))*weight.z);
	NORMAL = normalize(mat3(VIEW_MATRIX)*normal_world);
	float rough = texture(mineral_roughness,ux).r*weight.x
		+texture(mineral_roughness,uy).r*weight.y
		+texture(mineral_roughness,uz).r*weight.z;
	ROUGHNESS = clamp(mineral_roughness_center+(rough-0.5)*mineral_roughness_variation+splash,0.63,0.97);
	SPECULAR = 0.23;
}
