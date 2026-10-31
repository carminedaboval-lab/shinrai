shader_type spatial;
// One pane of the near-city shells: sky in the glass, and a ray-cast room behind it.
// UV is metres from the pane centre. UV2.x = cell id + 2 for a shopfront,
// UV2.y = half width in centimetres + half height / 10.
uniform float night = 0.0;
varying vec3 world;
varying vec3 world_normal;
varying flat vec2 info;
float hsh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float nz(vec2 p){ vec2 c = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hsh(c), hsh(c+vec2(1,0)), u.x), mix(hsh(c+vec2(0,1)), hsh(c+vec2(1,1)), u.x), u.y); }
void vertex(){
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	info = UV2;
}
void fragment(){
	vec3 n = normalize(world_normal);
	vec3 t = normalize(cross(vec3(0.0, 1.0, 0.0), n));
	vec3 wv = normalize(world - CAMERA_POSITION_WORLD);
	float deep = max(-dot(wv, n), 0.08);
	vec3 rd = vec3(dot(wv, t) / deep + 1e-4, wv.y / deep + 1e-4, 1.0);
	bool shop = info.x > 1.5;
	float cell = fract(info.x);
	vec2 half_size = vec2(floor(info.y) * 0.01, fract(info.y) * 10.0);
	// Room behind the glass.
	vec2 room = half_size + vec2(0.5, 0.45);
	float room_depth = 3.0 + hsh(vec2(cell, 3.0)) * 3.5;
	vec3 ro = vec3(UV, 0.0);
	vec2 hit_side = (sign(rd.xy) * room - ro.xy) / rd.xy;
	float d = min(min(hit_side.x, hit_side.y), room_depth);
	vec3 hit = ro + rd * d;
	float shade = 0.72;
	if (d == hit_side.y) shade = rd.y > 0.0 ? 1.0 : 0.3;
	else if (d == hit_side.x) shade = 0.55;
	else shade = 0.7 + 0.2 * step(0.5, hsh(floor(hit.xy * 0.8) + cell));
	float lamp_fall = 1.0 / (1.0 + dot(hit.xz - vec2(0.0, 2.0), hit.xz - vec2(0.0, 2.0)) * 0.06);
	float roll = hsh(vec2(cell, 9.0));
	float lit = step(shop ? 0.5 : 0.78, roll);
	float level = 0.22 + 0.78 * hsh(vec2(cell, 5.0));
	level *= level;
	vec3 lamp = roll > 0.9 ? vec3(0.78, 0.9, 1.0) : vec3(1.0, 0.78, 0.5);
	if (shop) {
		shade *= 0.72 + 0.4 * step(0.45, fract(hit.y * 1.7)) * hsh(floor(hit.xz * 2.5) + cell);
		lamp = mix(vec3(1.0, 0.86, 0.62), 0.5 + 0.5 * cos(6.283 * (cell + vec3(0.0, 0.33, 0.67))), 0.55);
		level = 1.0;
	}
	vec3 room_glow = lamp * shade * lamp_fall;
	// Curtains behind the glass on some rooms.
	float drape_roll = hsh(vec2(cell, 13.0));
	float gap = half_size.x * (0.25 + 0.6 * hsh(vec2(cell, 17.0)));
	float drape = shop ? 0.0 : (drape_roll < 0.22 ? step(gap, abs(UV.x)) : (drape_roll < 0.32 ? 1.0 : 0.0));
	vec3 drape_tint = mix(vec3(0.74, 0.7, 0.62), vec3(0.5, 0.54, 0.58), step(0.5, hsh(vec2(cell, 21.0))));
	float folds = 0.88 + 0.12 * sin(UV.x * 24.0);
	// Sky and the street opposite in the glass; each pane sits slightly out of true.
	vec3 lean = n + t * (hsh(vec2(cell, 1.0)) - 0.5) * 0.05 + vec3(0.0, (hsh(vec2(cell, 2.0)) - 0.5) * 0.04, 0.0);
	vec3 mirror = reflect(wv, normalize(lean));
	float skyline = smoothstep(0.02, 0.2, mirror.y + (nz(mirror.xz * 11.0) - 0.5) * 0.14);
	vec3 mirrored = mix(vec3(0.24, 0.25, 0.26), mix(vec3(0.74, 0.79, 0.84), vec3(0.42, 0.55, 0.72), clamp(mirror.y * 1.4, 0.0, 1.0)), skyline);
	mirrored *= 0.86 + 0.28 * hsh(vec2(cell, 11.0));
	float fresnel = 0.42 + 0.58 * pow(1.0 - clamp(dot(-wv, n), 0.0, 1.0), 4.0);
	float head_shade = 1.0 - 0.5 * smoothstep(half_size.y - 0.3, half_size.y, UV.y);
	float shutter = (shop && hsh(vec2(cell, 7.0)) < mix(0.08, 0.62, night)) ? 1.0 : 0.0;
	vec3 inside = room_glow * mix(1.5, 0.6, drape) * mix(shop ? 0.16 : 0.04, shop ? 0.9 * lit : 0.78 * lit * level, night);
	ALBEDO = mix(vec3(0.02, 0.026, 0.032), drape_tint * folds * 0.3, drape);
	ROUGHNESS = 0.06;
	SPECULAR = 0.5;
	EMISSION = inside + mirrored * fresnel * head_shade * mix(1.0, 0.07, night);
	if (shutter > 0.5) {
		float slat = 0.8 + 0.2 * step(0.4, fract(UV.y / 0.11));
		ALBEDO = vec3(0.46, 0.48, 0.5) * slat * mix(1.0, 0.45, night);
		ROUGHNESS = 0.55;
		EMISSION = vec3(0.0);
	}
	// Frame and meeting stile; close shells also carry these as real geometry.
	vec2 edge = half_size - abs(UV);
	float frame = 1.0 - smoothstep(0.04, 0.08, min(edge.x, edge.y));
	if (!shop) frame = max(frame, 1.0 - smoothstep(0.02, 0.04, abs(UV.x)));
	ALBEDO = mix(ALBEDO, vec3(0.32, 0.33, 0.34) * mix(1.0, 0.4, night), frame);
	EMISSION *= 1.0 - frame;
	ROUGHNESS = mix(ROUGHNESS, 0.45, frame);
	float haze = 1.0 - exp(-length(world - CAMERA_POSITION_WORLD) * mix(0.00105, 0.00075, night));
	FOG = vec4(mix(vec3(0.66, 0.69, 0.74), vec3(0.035, 0.03, 0.055), night), haze);
}
