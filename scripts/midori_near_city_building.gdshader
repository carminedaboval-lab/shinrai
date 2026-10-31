shader_type spatial;
// Near-city facades on plain boxes. Windows are recessed by parallax and open onto
// a real room by ray-cast interior mapping, so a box reads as a built facade.
// INSTANCE_CUSTOM: x = kind + front * 10 + seed, yzw = size / 1000.
// Kinds: 0 zakkyo, 1 mansion, 2 office, 3 glass, 4 low-rise, 5 garage, 6 danchi,
// 7 upper storeys (no shopfront), 8 solid stair core, 9 convenience store.
uniform float night = 0.0;
uniform sampler2DArray wall_maps : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray wall_normals : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
const float SCALE[9] = {2.4, 3.0, 2.6, 3.2, 2.2, 2.0, 1.1, 3.4, 1.0};
// Pale tile sets the tone, but neighbours differ: terracotta, black, teal, mustard, raw concrete.
const vec3 PALETTE[16] = {vec3(.96,.92,.84), vec3(.9,.84,.74), vec3(.97,.96,.93), vec3(.84,.84,.83),
	vec3(.8,.72,.62), vec3(.62,.36,.26), vec3(.48,.24,.2), vec3(.15,.16,.17),
	vec3(.08,.08,.09), vec3(.28,.36,.44), vec3(.3,.48,.46), vec3(.56,.62,.52),
	vec3(.72,.58,.3), vec3(.78,.56,.48), vec3(.42,.42,.42), vec3(.56,.55,.53)};
varying flat float kind;
varying flat float front;
varying flat float seed;
varying vec3 size;
varying vec3 local;
varying vec3 axis_normal;
varying vec3 world;
float hsh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float nz(vec2 p){ vec2 c = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hsh(c), hsh(c+vec2(1,0)), u.x), mix(hsh(c+vec2(0,1)), hsh(c+vec2(1,1)), u.x), u.y); }
float box_mask(vec2 q, vec2 half_size, float px){
	vec2 d = abs(q) - half_size;
	return (1.0 - smoothstep(-px, px, d.x)) * (1.0 - smoothstep(-px, px, d.y));
}
void vertex(){
	float code = INSTANCE_CUSTOM.x;
	kind = mod(floor(code), 10.0);
	front = floor(code / 10.0);
	seed = fract(code);
	size = INSTANCE_CUSTOM.yzw * 1000.0;
	local = (VERTEX + vec3(0.5)) * size;
	axis_normal = NORMAL;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment(){
	vec3 an = abs(axis_normal);
	if (an.y > 0.5) {
		vec3 tar = texture(wall_maps, vec3(local.xz / 3.2, 3.0)).rgb;
		ALBEDO = tar * vec3(0.5, 0.5, 0.52) * mix(0.7, 1.05, nz(local.xz * 0.4));
		ROUGHNESS = 0.92;
		EMISSION = ALBEDO * vec3(0.045, 0.05, 0.07) * night;
		float roof_haze = 1.0 - exp(-length(world - CAMERA_POSITION_WORLD) * mix(0.00105, 0.00075, night));
		FOG = vec4(mix(vec3(0.66, 0.69, 0.74), vec3(0.035, 0.03, 0.055), night), roof_haze);
	} else {
		bool on_x = an.x > 0.5;
		float across = on_x ? local.z : local.x;
		float width = on_x ? size.z : size.x;
		float face = on_x ? (axis_normal.x > 0.0 ? 0.0 : 1.0) : (axis_normal.z > 0.0 ? 2.0 : 3.0);
		bool is_front = abs(face - front) < 0.5;
		bool is_back = abs(face - (mod(front, 2.0) < 0.5 ? front + 1.0 : front - 1.0)) < 0.5;
		bool is_side = !is_front && !is_back;
		int k = int(kind + 0.5);
		float pick = fract(seed * 7.3);
		// Per-kind facade recipe.
		float layer = pick < 0.3 ? 6.0 : (pick < 0.5 ? 7.0 : (pick < 0.68 ? 8.0 : (pick < 0.84 ? 0.0 : 3.0)));
		float base_bay = 3.0 + fract(seed * 13.0);
		float storey = 3.2;
		float ground = 0.0;
		float wide_win = 0.26 + fract(seed * 29.0) * 0.17;
		vec2 half_pane = vec2(wide_win * base_bay, 0.62 + fract(seed * 37.0) * 0.32);
		float sill = 0.52;
		float recess = 0.16;
		bool open_deck = false;
		bool glazed = false;
		float wall_rough = 0.9;
		if (k == 1) { half_pane = is_front ? vec2(0.42 * base_bay, 1.12) : (is_back ? vec2(0.46, 1.02) : vec2(0.26 * base_bay, 0.62)); sill = (is_front || is_back) ? 0.4 : 0.58; }
		else if (k == 2) { layer = pick < 0.4 ? 3.0 : (pick < 0.7 ? 7.0 : 1.0); base_bay = 2.1 + fract(seed * 13.0) * 0.9; half_pane = vec2(0.44 * base_bay, 0.74); recess = 0.22; }
		else if (k == 3) { base_bay = 1.7; storey = 3.8; half_pane = vec2(0.47 * base_bay, 1.55); recess = 0.06; glazed = true; wall_rough = 0.14; }
		else if (k == 4) { layer = pick < 0.5 ? 2.0 : (pick < 0.82 ? 7.0 : 4.0); base_bay = 2.6 + fract(seed * 13.0); storey = 2.9; half_pane = vec2(0.55, 0.58); recess = 0.08; }
		else if (k == 5) { layer = pick < 0.6 ? 3.0 : 4.0; base_bay = 5.0; storey = 3.0; half_pane = vec2(2.7, 0.62); open_deck = true; recess = 0.9; sill = 0.6; }
		else if (k == 8) { layer = 7.0; base_bay = 2.4; half_pane = vec2(0.26, 1.0); }
		else if (k == 6) { layer = 7.0; half_pane = is_front ? vec2(0.42 * base_bay, 1.05) : (is_back ? vec2(0.46, 1.02) : vec2(0.3 * base_bay, 0.6)); sill = (is_front || is_back) ? 0.4 : 0.45; }
		// Commercial buildings each follow one of ten separate designs.
		float style = -1.0;
		bool round_windows = false;
		bool fin_screen = false;
		bool tie_holes = false;
		float tint_index = fract(seed * 23.0) * 16.0;
		if (k == 0 || k == 2 || k == 7) {
			style = floor(fract(seed * 97.0) * 10.0);
			storey = 3.0 + fract(seed * 71.0) * 0.9;
			float stripe = fract(seed * 83.0);
			if (style < 0.5 && !is_side) { base_bay = 1.5; half_pane = vec2(0.48 * base_bay, storey * 0.45); recess = 0.05; glazed = true; wall_rough = 0.14; }
			else if (style < 1.5) { base_bay = 1.4; half_pane = vec2(0.52 * base_bay, 0.6 + stripe * 0.25); recess = 0.1; }
			else if (style < 2.5) { layer = 3.0; tint_index = 15.0; base_bay = 2.7; half_pane = vec2(1.08, storey * 0.38); recess = 0.8; }
			else if (style < 3.5) { layer = stripe < 0.5 ? 4.0 : 2.0; tint_index = stripe < 0.5 ? 7.0 : 8.0; base_bay = 1.8; half_pane = vec2(0.2, storey * 0.42); recess = 0.2; }
			else if (style < 4.5) { base_bay = 5.0; half_pane = vec2(1.95, 0.98); }
			else if (style < 5.5) { fin_screen = true; base_bay = 3.0; half_pane = vec2(1.3, storey * 0.42); recess = 0.25; tint_index = 8.0 + floor(stripe * 3.0); }
			else if (style < 6.5) { round_windows = true; base_bay = 2.5; half_pane = vec2(0.72); sill = 0.52; }
			else if (style < 7.5) { layer = 3.0; tint_index = 15.0; tie_holes = true; base_bay = 4.4; half_pane = vec2(0.85, 1.05); }
			else if (style < 8.5) { base_bay = 2.0; half_pane = vec2(0.45, 0.55); layer = 8.0; }
		}
		bool shop = is_front && (k == 0 || k == 9 || (k == 2 && seed > 0.4) || (k == 4 && fract(seed * 5.0) > 0.3));
		if (shop) ground = 4.2;
		bool in_shop = shop && local.y < ground;
		float bay = width / max(1.0, floor(width / base_bay + 0.5));
		vec2 dims = vec2(bay, storey);
		float up = local.y - ground;
		if (in_shop) {
			bay = width / max(1.0, floor(width / 6.0 + 0.5));
			dims = vec2(bay, ground);
			up = local.y;
			half_pane = vec2(bay * 0.45, 1.42);
			sill = 0.39;
			recess = 0.1;
		}
		vec2 grid = vec2(across / bay, up / dims.y);
		vec2 cell = floor(grid);
		vec2 q = (fract(grid) - vec2(0.5, sill)) * dims;
		float exists = 1.0;
		if (is_side && (k == 0 || k == 1 || k == 4 || k == 6)) {
			// Party walls: mostly blank, with the odd small stair window.
			exists = step(0.82, hsh(cell * 1.7 + seed * 31.0));
			half_pane = vec2(0.42, 0.52);
		}
		if (k == 8) exists = step(0.45, hsh(cell.xx + seed * 9.0));
		// A stair core runs up the front of some buildings, breaking the window grid.
		if (is_front && !in_shop && (k == 0 || k == 2 || k == 7) && fract(seed * 41.0) < 0.6) {
			float core = floor(fract(seed * 43.0) * max(width / bay, 1.0));
			if (abs(cell.x - core) < 0.5) { half_pane = vec2(0.3, 1.15); sill = 0.5; q = (fract(grid) - vec2(0.5, sill)) * dims; }
		}
		if (local.y > size.y - 0.9) exists = 0.0;
		// Tenants differ floor by floor: wider glass, narrower glass, some floors bricked up.
		if (!is_side && !in_shop && (k == 0 || k == 7)) {
			float tenant = hsh(vec2(cell.y, seed * 77.0));
			half_pane.x *= tenant < 0.3 ? 1.32 : (tenant < 0.6 ? 1.0 : 0.82);
			if (tenant > 0.93) exists = 0.0;
		}
		float px = max(fwidth(across), fwidth(local.y)) * 1.2;
		float aa = max(fwidth(grid.x), fwidth(grid.y));
		float far = smoothstep(0.28, 0.85, aa);
		// Tangent-space view: metres moved per metre travelled into the wall.
		vec3 wv = normalize(world - CAMERA_POSITION_WORLD);
		float deep = max(abs(on_x ? wv.x : wv.z), 0.08);
		vec2 slope = vec2(on_x ? wv.z : wv.x, wv.y) / deep;
		vec2 g = q + slope * recess;
		float opening = box_mask(q, half_pane, px) * exists;
		float inner = box_mask(g, half_pane, px);
		if (round_windows && !in_shop) {
			opening = (1.0 - smoothstep(half_pane.x - px, half_pane.x + px, length(q))) * exists;
			inner = 1.0 - smoothstep(half_pane.x - px, half_pane.x + px, length(g));
		}
		// Raw concrete shows only about half its bays glazed; alternate floors pair up on others.
		if (style > 6.5 && style < 7.5 && hsh(cell + seed * 7.0) < 0.45) { opening = 0.0; exists = 0.0; }
		if (style > 7.5 && style < 8.5 && mod(cell.y, 2.0) > 0.5) { opening = 0.0; exists = 0.0; }
		float roofline = smoothstep(size.y - 7.0, size.y, local.y);
		// Wall: real material, tinted per building, stained under each sill.
		vec2 wall_uv = vec2(across, local.y) / SCALE[int(layer)] + seed * 17.0;
		vec3 wall = texture(wall_maps, vec3(wall_uv, layer)).rgb;
		// Levelled by each map's own average, so the finish comes from the tint and not the photo.
		vec3 mean = textureLod(wall_maps, vec3(wall_uv, layer), 9.0).rgb;
		wall = (mean + (wall - mean) * 0.72) / max(dot(mean, vec3(0.3, 0.6, 0.1)), 0.02) * 0.66;
		wall = mix(vec3(dot(wall, vec3(0.3, 0.6, 0.1))), wall, 0.3);
		vec3 tint = PALETTE[int(tint_index)];
		if (layer > 3.5) tint = mix(tint, vec3(0.4, 0.44, 0.46), 0.6);
		if (k == 6) tint = vec3(0.9, 0.89, 0.85);
		wall *= tint;
		// Repairs and repaints: each bay has aged a little differently.
		wall *= 0.93 + 0.14 * hsh(floor(vec2(across / 1.8, local.y / 2.6)) + seed * 13.0);
		if (layer > 2.5 && layer < 3.5) {
			vec2 joint = abs(fract(vec2(across / 2.4, local.y / 3.2)) - 0.5);
			wall *= 1.0 - 0.35 * step(0.49, max(joint.x, joint.y)) * step(px, 0.03);
		}
		// Spandrels in a contrasting finish on some facades; a plinth at street level.
		if (!is_side && (k == 0 || k == 2 || k == 7) && abs(q.y) > half_pane.y && fract(seed * 19.0) < 0.5) wall *= 0.78;
		if (!shop && local.y < 1.1 && world.y < 1.2) wall = wall * 0.5 + vec3(0.03);
		if (roofline > 0.9 && k != 3) wall *= 0.92;
		if (tie_holes) {
			// Fair-faced concrete: formwork panels with their tie holes.
			vec2 board = vec2(across / 1.8, local.y / 0.9);
			vec2 tie = abs(fract(board * vec2(1.0, 1.0)) - 0.5) * vec2(1.8, 0.9);
			wall *= 1.0 - 0.5 * step(length(tie - vec2(0.72, 0.28)), 0.035) * step(px, 0.02);
			wall *= 1.0 - 0.14 * step(0.47, abs(fract(board.y) - 0.5)) * step(px, 0.03);
		}
		if (glazed) wall = mix(vec3(0.03, 0.05, 0.07), vec3(0.05, 0.08, 0.1), fract(seed * 3.0));
		float streak = nz(vec2(across * 2.3 + seed * 40.0, local.y * 0.12));
		float below = (1.0 - smoothstep(half_pane.x - 0.1, half_pane.x + 0.15, abs(q.x))) * step(q.y, -half_pane.y) * smoothstep(-half_pane.y - 1.5, -half_pane.y, q.y);
		float weather = nz(vec2(across * 0.22, local.y * 0.07) + seed * 50.0);
		wall *= (1.0 - 0.38 * below * streak * exists) * mix(0.72, 1.06, weather) * (1.0 - 0.25 * roofline * streak);
		wall *= mix(0.62, 1.0, smoothstep(0.0, 2.8, world.y));
		// Ambient shadow pooling in the street canyon; sky reaches the upper floors.
		wall *= mix(0.56, 1.0, smoothstep(0.0, 20.0, world.y));
		// Floor line, where the slab edge shows on plain facades.
		if (k != 3 && !is_side) {
			float slab = fract(up / dims.y);
			wall *= 1.0 - 0.3 * (1.0 - smoothstep(0.0, 0.03 + px / dims.y, slab)) * (1.0 - far);
		}
		// The room behind the glass, by ray against its four inner faces.
		float lit_roll = hsh(cell + seed * 91.0 + face * 7.0);
		// Offices and tenants light in runs along a floor, homes one room at a time.
		if (k == 2 || k == 3 || k == 0 || k == 7) lit_roll = mix(hsh(vec2(floor(cell.x / 4.0), cell.y) + seed * 91.0 + face * 7.0), lit_roll, mix(0.18, 1.0, far));
		float lit = step(in_shop ? (k == 9 ? -1.0 : 0.5) : (k == 2 || k == 3 ? 0.74 : 0.8), lit_roll);
		// No two rooms burn alike: a lamp, a television, a full ceiling light.
		float level = 0.22 + 0.78 * hsh(cell * 3.1 + seed * 5.0);
		level *= level;
		vec3 lamp = lit_roll > 0.82 ? vec3(0.78, 0.9, 1.0) : vec3(1.0, 0.78, 0.5);
		vec3 rd = vec3(slope + vec2(1e-4), 1.0);
		vec3 ro = vec3(g, 0.0);
		vec2 room = vec2(bay * 0.5, dims.y * 0.5);
		float room_depth = 3.0 + hsh(cell.yx + seed) * 3.5;
		vec2 hit_side = (sign(rd.xy) * room - ro.xy) / rd.xy;
		float t = min(min(hit_side.x, hit_side.y), room_depth);
		vec3 hit = ro + rd * t;
		float shade = 0.72;
		if (t == hit_side.y) shade = rd.y > 0.0 ? 1.0 : 0.3;
		else if (t == hit_side.x) shade = 0.55;
		else shade = 0.7 + 0.2 * step(0.5, hsh(floor(hit.xy * 0.8) + cell));
		float ceiling_light = 1.0 / (1.0 + dot(hit.xz - vec2(0.0, 2.0), hit.xz - vec2(0.0, 2.0)) * 0.06);
		if (in_shop) {
			// Stocked shelves on the back and side walls.
			shade *= 0.72 + 0.4 * step(0.45, fract(hit.y * 1.7)) * hsh(floor(hit.xz * 2.5) + cell);
			lamp = mix(vec3(1.0, 0.86, 0.62), 0.5 + 0.5 * cos(6.283 * (hsh(cell + seed) + vec3(0.0, 0.33, 0.67))), 0.55);
			if (k == 9) lamp = vec3(0.92, 0.97, 1.0);
		}
		vec3 room_glow = lamp * shade * ceiling_light;
		// Curtains and blinds sit on the glass plane.
		float drape_roll = hsh(cell * 1.3 + seed * 11.0);
		float gap = half_pane.x * (0.25 + 0.6 * hsh(cell * 2.1 + seed));
		float drape = (!in_shop && !open_deck) ? ((drape_roll < 0.22) ? step(gap, abs(g.x)) : ((drape_roll < 0.34) ? 1.0 : 0.0)) : 0.0;
		float slats = (drape_roll > 0.22 && drape_roll < 0.34) ? (0.8 + 0.2 * step(0.5, fract(g.y * 7.0))) : (0.88 + 0.12 * sin(g.x * 24.0));
		vec3 drape_tint = mix(vec3(0.74, 0.7, 0.62), vec3(0.5, 0.54, 0.58), step(0.5, hsh(cell + 5.0)));
		vec3 pane = mix(vec3(0.02, 0.026, 0.032), drape_tint * slats * 0.3, drape);
		// Open by day; most drop their shutters at night. Convenience stores never close.
		float shutter = (in_shop && k != 9 && hsh(cell + seed * 3.0) < mix(0.08, 0.62, night)) ? 1.0 : 0.0;
		if (shutter > 0.5) pane = texture(wall_maps, vec3(vec2(across, local.y) / 2.0, 5.0)).rgb * vec3(0.8, 0.82, 0.84);
		// Open access corridor at the rear: steel flat doors, frosted bathroom glass between.
		if (is_back && (k == 1 || k == 6)) {
			if (mod(cell.x, 2.0) < 0.5) { pane = vec3(0.3, 0.32, 0.35); shutter = 1.0; }
			else drape = 1.0;
		}
		// Aluminium frame and a central sash stile.
		vec2 edge = half_pane - abs(g);
		float frame = 1.0 - smoothstep(0.03, 0.06 + px, round_windows ? half_pane.x - length(g) : min(edge.x, edge.y));
		float stile = open_deck ? 0.0 : 1.0 - smoothstep(0.02, 0.04 + px, abs(g.x));
		float metal = max(frame, stile) * (1.0 - far);
		vec3 metal_tint = glazed ? vec3(0.08) : vec3(0.32, 0.33, 0.34);
		pane = mix(pane, metal_tint, metal);
		float pane_rough = mix(mix(0.05, 0.7, drape), 0.45, metal);
		if (shutter > 0.5) pane_rough = 0.55;
		vec3 reveal = wall * (slope.y > 0.0 ? 0.42 : 0.62);
		if (open_deck) { pane = vec3(0.025) + vec3(0.08) * shade; pane_rough = 0.9; }
		// Sky and the street opposite in the glass, broken by each pane sitting slightly out of true.
		vec2 tilt = vec2(hsh(cell + 3.0), hsh(cell + 7.0)) - 0.5;
		vec3 mirror = reflect(wv, normalize(axis_normal + vec3(tilt.x * 0.05, tilt.y * 0.04, tilt.y * 0.05)));
		float skyline = smoothstep(0.02, 0.2, mirror.y + (nz(mirror.xz * 11.0) - 0.5) * 0.14);
		vec3 mirrored = mix(vec3(0.24, 0.25, 0.26), mix(vec3(0.74, 0.79, 0.84), vec3(0.42, 0.55, 0.72), clamp(mirror.y * 1.4, 0.0, 1.0)), skyline);
		// Old float glass waves a little, so each pane bends the reflection differently.
		mirrored *= 0.86 + 0.28 * hsh(cell + 11.0);
		float head_shade = 1.0 - 0.55 * smoothstep(half_pane.y - 0.34, half_pane.y, g.y);
		float fresnel = 0.42 + 0.58 * pow(1.0 - clamp(dot(-wv, axis_normal), 0.0, 1.0), 4.0);
		vec3 body = mix(wall, mix(reveal, pane, inner), opening);
		float rough = mix(wall_rough, mix(0.8, pane_rough, inner), opening);
		vec3 glow = vec3(0.0);
		float clear_glass = inner * opening * (1.0 - metal) * (1.0 - shutter);
		if (!open_deck) {
			vec3 room_seen = room_glow * mix(1.5, 0.6, drape);
			float day_room = in_shop ? (k == 9 ? 0.5 : 0.16) : 0.04;
			glow = room_seen * clear_glass * mix(day_room, in_shop ? 0.9 * lit : 0.78 * lit * level, night);
		} else {
			glow = vec3(0.9, 1.0, 0.95) * clear_glass * step(0.35, fract(across / 7.0)) * 0.1 * night;
		}
		if (!open_deck && shutter < 0.5) glow += mirrored * fresnel * head_shade * inner * opening * (1.0 - metal) * mix(1.0, 0.07, night);
		// Screen of vertical fins standing proud of the glass.
		if (fin_screen && !in_shop && !is_side) {
			float fin = step(0.5, fract(across / 0.55));
			body = mix(body, wall * mix(0.75, 1.1, fin), fin * (1.0 - far));
			glow *= 1.0 - fin;
		}
		// Parking undercroft beneath a raised block of flats.
		if ((k == 1 || k == 6) && fract(seed * 53.0) < 0.45 && world.y < 3.0) {
			float column = abs(fract(across / (bay * 2.0)) - 0.5) * bay * 2.0;
			if (column > 0.4) { body = vec3(0.018, 0.018, 0.02); rough = 0.9; glow = vec3(0.0); }
		}
		// Dark fascia band over shopfronts; bright signs on it are real geometry.
		if (in_shop && local.y > 3.2) { body = vec3(0.05, 0.055, 0.06); rough = 0.5; glow = vec3(0.0); }
		// Beyond resolving range: average the cell, keeping which rooms are lit.
		float cover = exists * (half_pane.x * half_pane.y * 4.0) / (dims.x * dims.y);
		vec3 far_body = mix(wall, vec3(0.05, 0.06, 0.075) + mirrored * 0.5 * (1.0 - night), cover);
		if ((k == 1 || k == 6) && is_front) far_body = mix(far_body, wall * 1.15, step(fract(grid.y), 0.34));
		body = mix(body, far_body, far);
		rough = mix(rough, mix(wall_rough, 0.25, cover), far);
		glow = mix(glow, lamp * lit * level * cover * (in_shop ? 0.8 : 0.5), far * night);
		// Street neon washing up the lower storeys after dark.
		vec3 wash_hue = mix(vec3(1.0, 0.22, 0.5), vec3(0.2, 0.62, 1.0), nz(vec2(across * 0.06 + seed * 20.0, face)));
		glow += body * wash_hue * exp(-local.y * 0.16) * (is_front ? 0.5 : 0.22) * night;
		// After dark the city lights its own walls: warm street light low down, cool sky
		// glow above, stronger on some faces, so material and form still read.
		vec3 fill = mix(vec3(0.15, 0.11, 0.09), vec3(0.03, 0.035, 0.052), smoothstep(0.0, 20.0, world.y));
		float side_light = 0.62 + 0.55 * abs(dot(axis_normal, vec3(0.8682, 0.0, 0.4961)));
		glow += body * fill * side_light * night;
		glow += body * vec3(0.09, 0.07, 0.04) * (1.0 - night);
		// The night ambient is strongly blue; pale walls must not catch all of it.
		ALBEDO = body * mix(vec3(1.0), vec3(0.42, 0.34, 0.27), night);
		ROUGHNESS = rough;
		SPECULAR = 0.5;
		EMISSION = glow;
		vec3 surface = texture(wall_normals, vec3(wall_uv, layer)).xyz;
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), surface, (1.0 - opening) * (1.0 - far) * (glazed ? 0.0 : 1.0));
		NORMAL_MAP_DEPTH = 1.2;
		float haze = 1.0 - exp(-length(world - CAMERA_POSITION_WORLD) * mix(0.00105, 0.00075, night));
		FOG = vec4(mix(vec3(0.66, 0.69, 0.74), vec3(0.035, 0.03, 0.055), night), haze);
	}
}
