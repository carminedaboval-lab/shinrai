shader_type spatial;
// A pod's round window. There is no picture here: sky on the glass, the white cabin behind
// it worked out per pixel, and the fan blind each tenant leaves wherever they like.
// UV is metres from the window centre, COLOR.r a number for this pod.
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
	float cell = COLOR.r;
	vec3 n = normalize(world_normal);
	vec3 t = normalize(cross(vec3(0.0, 1.0, 0.0), n));
	vec3 wv = normalize(world - CAMERA_POSITION_WORLD);
	float deep = max(-dot(wv, n), 0.08);
	vec3 rd = vec3(dot(wv, t) / deep + 1e-4, wv.y / deep + 1e-4, 1.0);
	vec2 p = vec2(UV.x, -UV.y);
	// The cabin: two metres square, a bed along one wall, a door at the far end.
	vec2 sides = (sign(rd.xy) - p) / rd.xy;
	float d = min(min(sides.x, sides.y), 2.4);
	vec3 hit = vec3(p, 0.0) + rd * d;
	float shade = 0.62;
	if (d == sides.y) {
		// From the street it is mostly the ceiling you see: a round lamp, and the panels round it.
		float from_lamp = length(hit.xz - vec2(0.0, 1.1));
		float panels = 0.82 + 0.18 * step(0.08, fract(hit.z * 1.6)) * step(0.08, fract(hit.x * 1.6));
		shade = rd.y > 0.0 ? (0.16 + 1.1 * exp(-from_lamp * from_lamp * 2.4)) * panels : 0.3;
	}
	else if (d == sides.x) shade = 0.5 + 0.3 * step(0.55, fract(hit.z * 1.3));
	else shade = 0.5 + 0.35 * step(abs(hit.x), 0.34) * step(hit.y, 0.7);
	float lit = step(0.5, hsh(vec2(cell, 9.0)));
	float level = 0.45 + 0.55 * hsh(vec2(cell, 5.0));
	vec3 lamp = mix(vec3(1.0, 0.78, 0.52), vec3(0.74, 0.86, 1.0), step(0.86, hsh(vec2(cell, 4.0))));
	vec3 inside = lamp * shade * mix(0.1, lit * level * 0.62, night);
	// The sky and the street opposite in the glass; each sits slightly out of true.
	vec3 lean = n + t * (hsh(vec2(cell, 1.0)) - 0.5) * 0.09 + vec3(0.0, (hsh(vec2(cell, 2.0)) - 0.5) * 0.07, 0.0);
	vec3 mirror = reflect(wv, normalize(lean));
	float skyline = smoothstep(0.02, 0.2, mirror.y + (nz(mirror.xz * 11.0) - 0.5) * 0.14);
	vec3 mirrored = mix(vec3(0.2, 0.21, 0.22), mix(vec3(0.74, 0.79, 0.84), vec3(0.42, 0.55, 0.72), clamp(mirror.y * 1.4, 0.0, 1.0)), skyline);
	float fresnel = 0.1 + 0.9 * pow(1.0 - clamp(dot(-wv, n), 0.0, 1.0), 4.0);
	vec3 glass = inside + mirrored * fresnel * mix(1.0, 0.07, night);
	// Fan blind, pleated from a pivot at the foot of the window.
	float kind = hsh(vec2(cell, 13.0));
	vec2 q = p - vec2(0.0, -0.5);
	float angle = atan(q.x, q.y);
	float edge = mix(-1.1, 1.1, hsh(vec2(cell, 17.0)));
	float flip = step(0.5, hsh(vec2(cell, 19.0))) * 2.0 - 1.0;
	float cover = 0.0;
	if (kind > 0.32) cover = kind > 0.78 ? 1.0 : step(angle * flip, edge);
	float pleat = 0.78 + 0.22 * step(0.5, fract(angle * 8.0));
	vec3 blind = mix(vec3(0.8, 0.77, 0.68), vec3(0.62, 0.64, 0.64), step(0.5, hsh(vec2(cell, 21.0)))) * pleat;
	ALBEDO = mix(vec3(0.02, 0.026, 0.032), blind * 0.42, cover);
	ROUGHNESS = 0.8;
	SPECULAR = 0.12;
	EMISSION = mix(glass, blind * lamp * lit * level * 0.42 * night + mirrored * fresnel * 0.4 * (1.0 - night), cover);
	float haze = 1.0 - exp(-length(world - CAMERA_POSITION_WORLD) * mix(0.00105, 0.00075, night));
	FOG = vec4(mix(vec3(0.66, 0.69, 0.74), vec3(0.035, 0.03, 0.055), night), haze);
}
