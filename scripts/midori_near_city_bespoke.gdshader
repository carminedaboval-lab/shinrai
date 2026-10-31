shader_type spatial;
// Hand-modelled buildings. UV is metres on the surface (or atlas space, with tile 1),
// COLOR.rgb the paint, COLOR.a baked occlusion, UV2.x how hard rain has streaked a part.
uniform float night = 0.0;
uniform float tile = 1.0;
uniform float rough_scale = 1.0;
uniform float metal = 0.0;
uniform vec2 tile_size = vec2(0.0); // Glazed tile in running bond, when set.
uniform float chroma = 1.0; // Below 1, greys a texture that came out too bright.
uniform float glow = 0.0; // Lit from within after dark.
uniform float day_glow = 0.0;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world;
float hsh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float nz(vec2 p){ vec2 c = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hsh(c), hsh(c+vec2(1,0)), u.x), mix(hsh(c+vec2(0,1)), hsh(c+vec2(1,1)), u.x), u.y); }
void vertex(){
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment(){
	vec2 uv = UV / tile;
	vec3 face = texture(albedo_map, uv).rgb;
	face = mix(vec3(dot(face, vec3(0.3, 0.6, 0.1))), face, chroma);
	vec3 color = face * COLOR.rgb;
	// Weather: broad staining, then rain running down from each ledge.
	float broad = nz(world.xy * 0.45 + world.z * 0.31);
	float streak = nz(vec2((world.x + world.z) * 3.1, world.y * 0.16));
	color *= mix(0.8, 1.08, broad);
	color *= 1.0 - UV2.x * (0.18 + 0.62 * streak * streak);
	color *= mix(0.74, 1.0, smoothstep(0.0, 0.9, world.y));
	float ao = COLOR.a;
	vec3 normal_tex = texture(normal_map, uv).xyz;
	if (tile_size.x > 0.0) {
		// Each tile its own: a touch off in tone and tilt, with a recessed joint, all
		// easing into an average once the courses are too fine to see.
		float row = floor(UV.y / tile_size.y);
		vec2 at = vec2(UV.x / tile_size.x + 0.5 * mod(row, 2.0), UV.y / tile_size.y);
		vec2 id = floor(at);
		vec2 edge = (0.5 - abs(fract(at) - 0.5)) * tile_size;
		float joint = 1.0 - smoothstep(0.0015, 0.006, min(edge.x, edge.y));
		float near = 1.0 - smoothstep(0.2, 0.65, fwidth(at.y));
		color *= mix(0.96, (0.9 + 0.17 * hsh(id)) * (1.0 - 0.5 * joint), near);
		normal_tex = mix(normal_tex, vec3(0.5 + (hsh(id + 3.0) - 0.5) * 0.04, 0.5 + (hsh(id + 7.0) - 0.5) * 0.04, 1.0), near);
	}
	NORMAL_MAP = normal_tex;
	NORMAL_MAP_DEPTH = 1.1;
	ROUGHNESS = clamp(texture(rough_map, uv).r * rough_scale, 0.04, 1.0);
	METALLIC = metal;
	AO = ao;
	AO_LIGHT_AFFECT = 0.25;
	vec3 fill = mix(vec3(0.15, 0.11, 0.09), vec3(0.03, 0.035, 0.052), smoothstep(0.0, 20.0, world.y));
	EMISSION = color * ao * fill * night + color * ao * vec3(0.09, 0.07, 0.04) * (1.0 - night);
	EMISSION += face * COLOR.rgb * mix(day_glow, glow, night);
	ALBEDO = color * mix(1.0, ao, 0.45) * mix(vec3(1.0), vec3(0.42, 0.34, 0.27), night);
	float haze = 1.0 - exp(-length(world - CAMERA_POSITION_WORLD) * mix(0.00105, 0.00075, night));
	FOG = vec4(mix(vec3(0.66, 0.69, 0.74), vec3(0.035, 0.03, 0.055), night), haze);
}
