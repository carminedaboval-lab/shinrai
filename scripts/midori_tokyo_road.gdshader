shader_type spatial;
render_mode diffuse_burley, cull_disabled;
// Tokyo carriageway: one surface for asphalt, wear, repairs, gutters and paint.
//
// Mesh attributes (written by midori_tokyo_roads.gd):
//   UV       (u, v): u across the road from the centre line, + to the right of
//            travel along +v; v along the road from its start, in metres.
//   UV2      (lamp_u, lamp_strength): street-light pool line, or lamp_u > 50 for none.
//   COLOR    r = kind / 8. Segments: g = start junction / 4, b = end junction / 4.
//            Junction 0 none, 1 stop (minor road), 2 signalised, 3 priority road
//            through an unsignalised junction. Boxes: g = gutter edges / 16.
//   CUSTOM0  (length, half width, lamp spacing, lamp offset).
// Kinds: 0 ring and 1 arterial have four 3.25 m lanes; 2 is a two-lane road with
// cycle shoulders; 3 is a junction box. Japan drives on the left, so traffic
// along +v uses u < 0.
uniform sampler2D aggregate_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D aggregate_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D aggregate_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 asphalt_color : source_color = vec3(0.4, 0.395, 0.385);
uniform vec3 gutter_color : source_color = vec3(0.56, 0.555, 0.53);
uniform vec3 white_paint : source_color = vec3(0.86, 0.855, 0.82);
uniform vec3 yellow_paint : source_color = vec3(0.86, 0.62, 0.16);
uniform vec3 blue_paint : source_color = vec3(0.16, 0.38, 0.66);
uniform float night = 0.0;
// Resurfacing an existing road box instead of a built segment: x is its long
// local axis (0 = x, 1 = z), y its half width, z its length. Such roads keep
// their own kerbs and paint, so this mode (kind 5) draws asphalt only.
instance uniform vec4 road_frame = vec4(-1.0, 0.0, 0.0, 0.0);
instance uniform vec2 road_centre = vec2(0.0);

varying vec3 world;
varying vec2 road;
varying vec2 lamp;
varying vec4 flags;
varying vec4 seg;

const float LANE = 3.25;
const float J0 = 1.0;      // From the junction box to the crossing.
const float ZEBRA = 4.0;   // Crossing width.

float hsh(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float nz(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hsh(i), hsh(i + vec2(1, 0)), f.x), mix(hsh(i + vec2(0, 1)), hsh(i + vec2(1, 1)), f.x), f.y);
}
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
// Share of the pixel covered by the line. The footprint never drops below the old 2.4 cm soft edge,
// so close up it looks the same; far away a line keeps its true share of the pixel instead of flickering.
float band(float x, float centre, float half_width) { float d = x - centre; float f = max(fwidth(x), 0.024); return (clamp(d + 0.5 * f, -half_width, half_width) - clamp(d - 0.5 * f, -half_width, half_width)) / f; }
float seg_dist(vec2 p, vec2 a, vec2 b) { vec2 pa = p - a; vec2 ba = b - a; float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return length(pa - ba * h); }
float box_dist(vec2 p, vec2 half_size) { vec2 d = abs(p) - half_size; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }

// Lane arrows in lane space: x to the driver's right, y toward the junction,
// head ending at y = 2.5. Straight, plus an optional left branch.
float arrow(vec2 q, bool left) {
	float shaft = 1.0 - smoothstep(0.13, 0.15, seg_dist(q, vec2(0.0, -2.6), vec2(0.0, 1.3)));
	float head = step(1.2, q.y) * step(q.y, 2.5) * step(abs(q.x), (2.5 - q.y) * 0.42);
	float mark = max(shaft, head);
	if (left) {
		vec2 s = q - vec2(0.0, -0.6);
		float branch = 1.0 - smoothstep(0.13, 0.15, seg_dist(s, vec2(0.0, 0.0), vec2(-0.75, 1.1)));
		vec2 h = s - vec2(-0.75, 1.1);
		h = rot(0.6) * h;
		float tip = step(-0.25, h.y) * step(h.y, 0.85) * step(abs(h.x), (0.85 - h.y) * 0.5);
		mark = max(mark, max(branch, tip));
	}
	return mark;
}

// Outline diamond warning of a crossing ahead.
float diamond(vec2 q) {
	float d = abs(q.x) / 0.75 + abs(q.y) / 2.5;
	return step(d, 1.0) * (1.0 - step(d, 1.0 - 0.15 / 0.75));
}

// Blue cycle-lane chevron pointing along y.
float chevron(vec2 q) {
	q.x = abs(q.x);
	float body = 1.0 - smoothstep(0.075, 0.09, seg_dist(q, vec2(0.0, 0.35), vec2(0.36, -0.35)));
	return body * step(q.x, 0.38);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (road_frame.x >= 0.0) {
		vec2 local = VERTEX.xz - road_centre;
		road = road_frame.x < 0.5 ? vec2(local.y, local.x + road_frame.z * 0.5) : vec2(-local.x, local.y + road_frame.z * 0.5);
		lamp = vec2(99.0, 0.0);
		flags = vec4(5.0 / 8.0, 0.0, 0.0, 1.0);
		seg = vec4(road_frame.z, road_frame.y, 0.0, 0.0);
	} else {
		road = UV;
		lamp = UV2;
		flags = COLOR;
		seg = CUSTOM0;
	}
}

void fragment() {
	vec2 p = world.xz;
	float u = road.x;
	float v = road.y;
	float len = seg.x;
	float hw = seg.y;
	int kind = int(round(flags.r * 8.0));
	bool box = kind == 3;
	float au = abs(u);
	float seed = fract(len * 0.1371 + hw * 0.31 + floor(p.x * 0.01) * 0.17);

	// Aggregate, broken up by two rotated scales so the 2 m tile never repeats.
	vec2 uv1 = (rot(0.26) * p) / 2.1;
	vec2 uv2 = (rot(-0.61) * p) / 3.3 + 0.37;
	float mixer = smoothstep(0.3, 0.7, nz(p * 0.07));
	vec3 agg = mix(texture(aggregate_albedo, uv1).rgb, texture(aggregate_albedo, uv2).rgb, mixer);
	vec3 agg_mean = mix(textureLod(aggregate_albedo, uv1, 9.0).rgb, textureLod(aggregate_albedo, uv2, 9.0).rgb, mixer);
	float grain = dot(agg, vec3(0.2126, 0.7152, 0.0722)) / max(dot(agg_mean, vec3(0.2126, 0.7152, 0.0722)), 0.0005);
	vec3 nrm = mix(texture(aggregate_normal, uv1).xyz, texture(aggregate_normal, uv2).xyz, mixer) * 2.0 - 1.0;
	float rough = mix(texture(aggregate_orm, uv1).g, texture(aggregate_orm, uv2).g, mixer);
	float occlusion = mix(texture(aggregate_orm, uv1).r, texture(aggregate_orm, uv2).r, mixer);

	// Resurfacing history: blocks laid at different times, joints straight across,
	// and sometimes only one carriageway redone. New asphalt is dark and fine.
	float run = floor((v + seed * 47.0) / 68.0);
	float age = hsh(vec2(run, seed * 91.0));
	if (hsh(vec2(run + 3.0, seed)) > 0.62) age = hsh(vec2(run, u < 0.0 ? 7.0 : 11.0) + seed);
	if (box) age = hsh(floor(p / 14.0) + 5.0);
	float tone = nz(p * 0.045) * 0.6 + nz(p * 0.21) * 0.4;
	float brightness = mix(0.62, 1.16, age) * mix(0.88, 1.1, tone);
	float texture_depth = mix(0.55, 1.0, age);
	vec3 asphalt = asphalt_color * brightness * mix(1.0, clamp(grain, 0.2, 2.6), texture_depth);
	asphalt = mix(asphalt, asphalt * vec3(1.03, 1.0, 0.95), age * 0.6);
	rough = mix(0.74, clamp(rough + 0.08, 0.75, 1.0), age);
	float joint = abs(fract((v + seed * 47.0) / 68.0) - 0.0);
	joint = min(joint, 1.0 - joint) * 68.0;
	float joint_line = (1.0 - smoothstep(0.015, 0.05, joint + (nz(vec2(u * 3.0, run)) - 0.5) * 0.03)) * (box ? 0.0 : 1.0);

	bool bare = kind == 5;
	float carriage = kind == 2 ? 3.4 : (bare ? hw : 6.5);
	float lane_w = bare ? max(hw, 2.5) : LANE;
	float lane_pos = mod(au, lane_w) - lane_w * 0.5;
	bool in_lane = !box && au < (kind == 2 ? LANE : (bare ? hw : 2.0 * LANE));

	// Tyres strip binder from two tracks per lane, so they read lighter; oil
	// drips darken the band down the middle.
	float track = in_lane ? (1.0 - smoothstep(0.16, 0.42, abs(abs(lane_pos) - 0.86))) : 0.0;
	float drip = in_lane ? (1.0 - smoothstep(0.08, 0.42, abs(lane_pos))) * smoothstep(0.35, 0.85, nz(vec2(v * 0.6, u * 1.7))) : 0.0;
	asphalt *= 1.0 + 0.1 * track * (0.4 + 0.6 * age);
	asphalt *= 1.0 - drip * 0.22;
	rough -= track * 0.06 + drip * 0.08;

	// Cracks, mostly along the old paving joints, then sealed with glossy binder.
	float lane_joint = (kind == 2 || bare) ? 0.0 : LANE;
	float wobble = (nz(vec2(v * 0.35, seed * 9.0)) - 0.5) * 0.12 + (nz(vec2(v * 2.1, 3.0)) - 0.5) * 0.03;
	float along_crack = (1.0 - smoothstep(0.004, 0.018, abs(au - lane_joint - 0.12 + wobble))) * step(0.42, nz(vec2(v * 0.05, seed * 13.0))) * age;
	float cell = floor(v / 9.0);
	float across_at = cell * 9.0 + hsh(vec2(cell, seed)) * 9.0;
	float across_crack = (1.0 - smoothstep(0.004, 0.018, abs(v - across_at - (nz(vec2(u * 0.9, cell)) - 0.5) * 0.35))) * step(0.74, hsh(vec2(cell, seed + 1.0))) * age * (box ? 0.0 : 1.0);
	float sealed = max(along_crack, across_crack) * step(0.45, hsh(vec2(cell, 9.0)));
	float seal_band = (1.0 - smoothstep(0.02, 0.055, abs(au - lane_joint - 0.12 + wobble))) * step(0.42, nz(vec2(v * 0.05, seed * 13.0))) * age * step(0.45, hsh(vec2(cell, 9.0)));
	asphalt *= 1.0 - max(along_crack, across_crack) * 0.55;
	asphalt = mix(asphalt, asphalt_color * 0.45, seal_band * 0.85);
	rough = mix(rough, 0.48, seal_band);

	// Utility cuts: trench across the road, or a long patch down one lane.
	float pcell = floor(v / 26.0);
	float roll = hsh(vec2(pcell, seed * 5.0));
	float cut_d = 99.0;
	if (!box && roll > 0.66) {
		float centre = pcell * 26.0 + 6.0 + hsh(vec2(pcell, 2.0)) * 14.0;
		if (roll > 0.8) cut_d = box_dist(vec2(u, v - centre), vec2(carriage, 0.55 + hsh(vec2(pcell, 4.0)) * 0.4));
		else {
			float lane_c = (hsh(vec2(pcell, 6.0)) > 0.5 ? 1.0 : -1.0) * (kind == 2 ? 1.6 : (bare ? hw * 0.5 : 4.9));
			cut_d = box_dist(vec2(u - lane_c, v - centre), vec2(0.5, 2.5 + hsh(vec2(pcell, 8.0)) * 6.0));
		}
	}
	if (box && hsh(floor(p / 7.0)) > 0.7) cut_d = box_dist(fract(p / 7.0) * 7.0 - 3.5, vec2(1.6, 0.6));
	cut_d += (nz(p * 30.0) - 0.5) * 0.03;
	float patched = 1.0 - smoothstep(-0.01, 0.02, cut_d);
	float cut_edge = 1.0 - smoothstep(0.01, 0.06, abs(cut_d));
	asphalt = mix(asphalt, asphalt_color * 0.84 * mix(0.9, 1.08, tone) * mix(1.0, clamp(grain, 0.3, 2.0), 0.6), patched);
	asphalt *= 1.0 - cut_edge * 0.22;
	rough = mix(rough, 0.8, patched);
	asphalt *= 1.0 - joint_line * 0.35;

	// Concrete gutter and steel grates at the kerb.
	float gutter_mask = 0.0;
	if (!box && !bare) gutter_mask = step(hw - 0.5, au);
	else {
		int edges = int(round(flags.g * 16.0));
		vec2 local = vec2(u, v - len * 0.5);
		if ((edges & 1) != 0 && u < -hw + 0.5) gutter_mask = 1.0;
		if ((edges & 2) != 0 && u > hw - 0.5) gutter_mask = 1.0;
		if ((edges & 4) != 0 && v < 0.5) gutter_mask = 1.0;
		if ((edges & 8) != 0 && v > len - 0.5) gutter_mask = 1.0;
	}
	vec3 surface = asphalt;
	if (gutter_mask > 0.5) {
		float gv = box ? (abs(u) > hw - 0.5 ? v : u) : v;
		float gx = box ? (abs(u) > hw - 0.5 ? hw - au : (v < 0.5 ? v : len - v)) : hw - au;
		float slab = 1.0 - smoothstep(0.004, 0.012, abs(fract(gv / 2.0) - 0.5) * 2.0 - 0.995);
		vec3 concrete = gutter_color * mix(0.82, 1.06, nz(p * 2.3)) * mix(1.0, clamp(grain, 0.6, 1.4), 0.25);
		concrete *= 1.0 - (1.0 - smoothstep(0.0, 0.18, 0.5 - gx)) * 0.28; // Grime where it meets the asphalt.
		concrete *= 1.0 - smoothstep(0.35, 0.6, nz(vec2(gv * 0.4, gx * 3.0))) * 0.18;
		concrete *= 1.0 - (1.0 - slab) * 0.5;
		float grate_at = abs(mod(gv + 7.5, 15.0) - 7.5);
		if (!box && grate_at < 0.45 && gx > 0.1 && gx < 0.42) {
			float bar = step(0.42, fract(gv / 0.032));
			concrete = mix(vec3(0.012), vec3(0.09, 0.095, 0.1), bar);
			rough = mix(0.9, 0.55, bar);
			if (grate_at > 0.41 || gx < 0.13 || gx > 0.39) concrete = vec3(0.11, 0.115, 0.12);
		} else rough = 0.9;
		surface = concrete;
		nrm.xy *= 0.4;
	}

	// Paint: white lines, yellow no-lane-change near junctions, crossings, stop
	// lines, arrows, crossing diamonds and blue cycle chevrons.
	float white = 0.0;
	float yellow = 0.0;
	float blue = 0.0;
	float wheel_wear = track;
	if (!box && !bare && gutter_mask < 0.5) {
		int start_j = int(round(flags.g * 4.0));
		int end_j = int(round(flags.b * 4.0));
		// Distance to the junction this lane approaches, and its type.
		bool toward_end = u < 0.0;
		float dj = toward_end ? len - v : v;
		int approach = toward_end ? end_j : start_j;
		float near_junction = approach > 0 ? 1.0 - step(30.0, dj) : 0.0;
		bool in_crossing = (start_j > 0 && v > J0 && v < J0 + ZEBRA) || (end_j > 0 && len - v > J0 && len - v < J0 + ZEBRA);
		if (in_crossing) {
			// Share of the pixel that is bar: hard-edged up close, an even half-white once bars are finer than a pixel.
			float zebra_w = max(fwidth(u) / 0.9, 0.0001);
			float zebra_a = u / 0.9 + 0.25 - 0.5 * zebra_w;
			float zebra_b = u / 0.9 + 0.25 + 0.5 * zebra_w;
			float zebra = 1.0 - ((floor(zebra_b) - floor(zebra_a)) * 0.5 + min(fract(zebra_b), 0.5) - min(fract(zebra_a), 0.5)) / zebra_w;
			if (au < hw - 0.55) white = max(white, clamp(zebra, 0.0, 1.0));
		} else {
			if (kind != 2) {
				white = max(white, band(u, 0.0, 0.075));
				float dash = step(fract(v / 10.0), 0.5);
				float lane_line = band(au, LANE, 0.075);
				if (near_junction > 0.5 && dj > J0 + ZEBRA) yellow = max(yellow, lane_line);
				else white = max(white, lane_line * dash);
				white = max(white, band(au, 2.0 * LANE - 0.15, 0.075));
			} else {
				float dash = step(fract(v / 10.0), 0.5);
				white = max(white, band(u, 0.0, 0.075) * (near_junction > 0.5 ? 1.0 : dash));
				white = max(white, band(au, 3.5, 0.075));
				// Cycle shoulder: chevron every 10 m, pictogram every 40 m.
				vec2 c = vec2(au - 4.6, (toward_end ? 1.0 : -1.0) * (mod(v, 10.0) - 5.0));
				if (dj > 8.0) blue = max(blue, chevron(c));
			}
			if (approach > 0 && au < carriage) {
				float stop_at = J0 + ZEBRA + 1.6;
				// Stop line across the lanes heading into the junction; a priority
				// road through an unsignalised junction has none.
				if (approach != 3) {
					float stop_f = max(fwidth(v), 0.0001);
					white = max(white, (clamp(dj + 0.5 * stop_f, stop_at, stop_at + 0.45) - clamp(dj - 0.5 * stop_f, stop_at, stop_at + 0.45)) / stop_f);
				}
				// Arrows in each inbound lane.
				float lanes = kind == 2 ? 1.0 : 2.0;
				for (int lane_i = 0; lane_i < 2; lane_i++) {
					if (float(lane_i) >= lanes) break;
					float lc = (float(lane_i) + 0.5) * LANE;
					float lx = au - lc; // + toward the kerb = driver's left.
					bool outer = lane_i == int(lanes) - 1;
					for (int k = 0; k < 2; k++) {
						if (approach != 2) break;
						float at = k == 0 ? stop_at + 9.0 : stop_at + 29.0;
						vec2 q = vec2(-lx, (at - dj));
						if (abs(q.y) < 3.0 && abs(q.x) < 1.2) white = max(white, arrow(q, outer));
					}
					if (approach != 2) {
						for (int k = 0; k < 2; k++) {
							float at = k == 0 ? 30.0 : 50.0;
							vec2 q = vec2(lx, dj - at);
							if (abs(q.y) < 2.7) white = max(white, diamond(q));
						}
					}
				}
			}
		}
	}
	// Paint wears in the wheel tracks and breaks up over the coarse stones.
	float paint = max(white, max(yellow, blue));
	float wear = smoothstep(0.5, 0.95, nz(p * 2.8) * 0.65 + nz(p * 11.0) * 0.35 + wheel_wear * 0.32 + (1.0 - age) * -0.15);
	float chips = smoothstep(0.75, 0.4, grain) * 0.75;
	float cover = paint * (1.0 - wear * 0.8) * (1.0 - chips * 0.55);
	vec3 paint_color = white > 0.0 ? white_paint : (yellow > 0.0 ? yellow_paint : blue_paint);
	paint_color *= mix(0.8, 1.0, nz(p * 0.6)) * mix(0.93, 1.0, grain);
	surface = mix(surface, paint_color, cover);
	rough = mix(rough, 0.58, cover);
	nrm.xy *= 1.0 - cover * 0.7;

	ALBEDO = surface;
	ROUGHNESS = clamp(rough, 0.35, 1.0);
	SPECULAR = mix(0.3, 0.45, cover);
	AO = mix(1.0, occlusion, 0.6);
	vec3 world_normal = normalize(vec3(nrm.x * 0.5, 1.0, nrm.y * 0.5));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	// Street lights: a pool on the road under each head after dark.
	if (lamp.x < 50.0 && seg.z > 0.0) {
		float lv = mod(v - seg.w + seg.z * 0.5, seg.z) - seg.z * 0.5;
		float d2 = dot(vec2(u - lamp.x, lv), vec2(u - lamp.x, lv));
		float pool = exp(-d2 / (2.0 * 6.0 * 6.0)) * lamp.y;
		EMISSION = surface * vec3(1.0, 0.95, 0.86) * pool * 1.6 * night;
	}
	EMISSION += surface * 0.1 * night;
}
