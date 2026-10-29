shader_type spatial;
render_mode cull_disabled;

// Scoped mineral render: sourced albedo, OpenGL normal and roughness.
// World phase is identical across separate wall members and roof closures.
uniform sampler2D mineral_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mineral_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mineral_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 mineral_tint : source_color = vec4(0.7804,0.7529,0.6863,1.0);
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
	// Provider specifies one metre of physical coverage per repeat.
	vec3 p = world_position;
	vec2 ux = p.zy;
	vec2 uy = p.xz;
	vec2 uz = p.xy;
	vec3 photo = texture(mineral_color,ux).rgb*weight.x
		+texture(mineral_color,uy).rgb*weight.y
		+texture(mineral_color,uz).rgb*weight.z;
	vec3 mean_surface = max(textureLod(mineral_color,vec2(0.5),10.0).rgb,vec3(0.03));
	// Keep the source's fine mineral detail while quieting broad discoloration.
	vec3 broad = textureLod(mineral_color,ux,5.0).rgb*weight.x
		+textureLod(mineral_color,uy,5.0).rgb*weight.y
		+textureLod(mineral_color,uz,5.0).rgb*weight.z;
	vec3 macro_detail = mix(vec3(1.0),broad/mean_surface,0.22);
	vec3 fine_detail = mix(vec3(1.0),photo/max(broad,vec3(0.03)),0.62);
	vec3 detail = clamp(macro_detail*fine_detail,vec3(0.84),vec3(1.16));
	ALBEDO = mineral_tint.rgb*detail;
	vec3 nx = texture(mineral_normal,ux).xyz*2.0-1.0;
	vec3 ny = texture(mineral_normal,uy).xyz*2.0-1.0;
	vec3 nz = texture(mineral_normal,uz).xyz*2.0-1.0;
	nx.xy *= 0.18;
	ny.xy *= 0.18;
	nz.xy *= 0.18;
	vec3 normal_world = normalize(vec3(nx.z*sign(n.x),nx.y,nx.x)*weight.x
		+vec3(ny.x,ny.z*sign(n.y),ny.y)*weight.y
		+vec3(nz.x,nz.y,nz.z*sign(n.z))*weight.z);
	NORMAL = normalize(mat3(VIEW_MATRIX)*normal_world);
	float rough = texture(mineral_roughness,ux).r*weight.x
		+texture(mineral_roughness,uy).r*weight.y
		+texture(mineral_roughness,uz).r*weight.z;
	ROUGHNESS = clamp(0.70+rough*0.25,0.80,0.96);
	SPECULAR = 0.23;
}
