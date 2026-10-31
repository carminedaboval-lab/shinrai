shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
// Clear shop glass: the sky and the street lie on it, the real room shows through it.
uniform float night = 0.0;
varying vec3 world;
varying vec3 world_normal;
float hsh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float nz(vec2 p){ vec2 c = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hsh(c), hsh(c+vec2(1,0)), u.x), mix(hsh(c+vec2(0,1)), hsh(c+vec2(1,1)), u.x), u.y); }
void vertex(){
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}
void fragment(){
	vec3 n = normalize(world_normal);
	vec3 wv = normalize(world - CAMERA_POSITION_WORLD);
	vec3 mirror = reflect(wv, n);
	float skyline = smoothstep(0.02, 0.2, mirror.y + (nz(mirror.xz * 11.0) - 0.5) * 0.14);
	vec3 mirrored = mix(vec3(0.24, 0.25, 0.26), mix(vec3(0.74, 0.79, 0.84), vec3(0.42, 0.55, 0.72), clamp(mirror.y * 1.4, 0.0, 1.0)), skyline);
	float fresnel = 0.12 + 0.88 * pow(1.0 - clamp(dot(-wv, n), 0.0, 1.0), 4.0);
	// Old glass collects a little film towards its lower edge.
	float film = 0.04 + 0.05 * nz(world.xy * vec2(1.6, 0.8));
	ALBEDO = vec3(0.02);
	ROUGHNESS = 0.08;
	SPECULAR = 0.5;
	EMISSION = mirrored * fresnel * mix(1.0, 0.08, night);
	ALPHA = clamp(fresnel * mix(1.0, 0.35, night) + film, 0.0, 1.0);
}
