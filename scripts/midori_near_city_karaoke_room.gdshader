shader_type spatial;
// A karaoke room seen through tinted glass. No picture: sky on the pane by day, and by night the
// room worked out per pixel, its screen, its coloured wash breathing slowly, the mirror-ball dots.
// UV is metres from the window centre, COLOR.r a number for this room.
uniform float night = 0.0;
varying vec3 world;
varying vec3 world_normal;
float hsh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float nz(vec2 p){ vec2 c = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hsh(c), hsh(c+vec2(1,0)), u.x), mix(hsh(c+vec2(0,1)), hsh(c+vec2(1,1)), u.x), u.y); }
vec3 mood(float t){
	if (t < 0.25) return vec3(1.0, 0.16, 0.5);
	if (t < 0.5) return vec3(0.2, 0.62, 1.0);
	if (t < 0.75) return vec3(0.5, 1.0, 0.3);
	return vec3(0.7, 0.3, 1.0);
}
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
	vec2 box = vec2(1.5, 1.2);
	vec2 sides = (sign(rd.xy) * box - p) / rd.xy;
	float d = min(min(sides.x, sides.y), 3.0);
	vec3 hit = vec3(p, 0.0) + rd * d;
	float shade = 0.34;
	float screen = 0.0;
	if (d == sides.y) shade = rd.y > 0.0 ? 0.2 : 0.1;
	else if (d == sides.x) shade = 0.3;
	else screen = step(abs(hit.x), 0.74) * step(-0.25, hit.y) * step(hit.y, 0.55);
	float wash = COLOR.g;
	float speed = 0.3 + 0.5 * hsh(vec2(cell, 11.0));
	vec3 tone = mix(mood(wash), mood(fract(wash + 0.31)), 0.5 + 0.5 * sin(TIME * speed + cell * 37.0));
	float dots = step(0.8, nz(hit.xy * 7.0 + hit.z * 5.0 + vec2(TIME * 0.12, 0.0)));
	float lit = step(0.6, hsh(vec2(cell, 9.0)));
	vec3 room = tone * (shade + dots * 0.32) + vec3(0.8, 0.9, 1.0) * screen * (0.55 + 0.25 * sin(TIME * 2.0 + cell * 9.0));
	vec3 inside = room * mix(0.02, lit * 0.8, night);
	vec3 lean = n + t * (hsh(vec2(cell, 1.0)) - 0.5) * 0.05 + vec3(0.0, (hsh(vec2(cell, 2.0)) - 0.5) * 0.04, 0.0);
	vec3 mirror = reflect(wv, normalize(lean));
	float skyline = smoothstep(0.02, 0.2, mirror.y + (nz(mirror.xz * 11.0) - 0.5) * 0.14);
	vec3 mirrored = mix(vec3(0.2, 0.21, 0.22), mix(vec3(0.74, 0.79, 0.84), vec3(0.42, 0.55, 0.72), clamp(mirror.y * 1.4, 0.0, 1.0)), skyline);
	float fresnel = 0.22 + 0.78 * pow(1.0 - clamp(dot(-wv, n), 0.0, 1.0), 3.0);
	// A roller blind each party leaves wherever it fell.
	float drop = mix(0.95, -0.2, hsh(vec2(cell, 13.0)));
	float cover = step(drop, p.y) * step(0.3, hsh(vec2(cell, 17.0)));
	float slat = 0.86 + 0.14 * step(0.5, fract(p.y * 9.0));
	vec3 blind = vec3(0.56, 0.58, 0.56) * slat;
	ALBEDO = mix(vec3(0.015, 0.02, 0.024), blind * 0.5, cover);
	ROUGHNESS = 0.8;
	SPECULAR = 0.12;
	EMISSION = mix(inside + mirrored * fresnel * mix(0.9, 0.08, night), blind * tone * lit * 0.26 * night + mirrored * fresnel * 0.28 * (1.0 - night), cover);
	float haze = 1.0 - exp(-length(world - CAMERA_POSITION_WORLD) * mix(0.00105, 0.00075, night));
	FOG = vec4(mix(vec3(0.66, 0.69, 0.74), vec3(0.035, 0.03, 0.055), night), haze);
}
