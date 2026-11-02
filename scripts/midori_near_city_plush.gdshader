shader_type spatial;
// Soft toys: short fur that breaks up the colour, dark where toys press together, and a pale
// fuzz along each edge. A face prints into the cloth from the atlas, weighted by UV2.x so that
// it stays on the front. COLOR.rgb is the fabric; a crane machine's lamps stand in for glow.
uniform float night = 0.0;
uniform float glow = 0.62;
uniform float day_glow = 0.44;
uniform sampler2D faces : source_color, filter_linear_mipmap_anisotropic;
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
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec2 at = world.xy + world.zz * vec2(.7, -.4);
	float fur = nz(at * vec2(170.0, 110.0)) * .55 + nz(at * vec2(70.0, 44.0)) * .45;
	vec3 cloth = COLOR.rgb * mix(.82, 1.1, fur);
	vec4 print = texture(faces, UV);
	cloth = mix(cloth, print.rgb * mix(.94, 1.04, fur), print.a * smoothstep(.12, .4, UV2.x));
	float under = mix(.5, 1.0, smoothstep(-.75, .45, n.y));
	float fold = mix(.62, 1.0, smoothstep(.05, .55, facing));
	float fuzz = pow(1.0 - facing, 2.4) * .4;
	vec3 lit = cloth * under * fold;
	ALBEDO = lit;
	ROUGHNESS = 1.0;
	SPECULAR = .12;
	EMISSION = (lit + cloth * fuzz) * mix(day_glow, glow, night);
}
