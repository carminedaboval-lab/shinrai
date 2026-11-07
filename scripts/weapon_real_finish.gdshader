shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// Real-counterpart weapon finishes. Everything is evaluated in the mesh's own
// space (metres) so texture and wear ride with moving slides, bolts and mags.
// pattern:
//   0 moulded polymer (fine EDM matte texture)   1 Gen5-style raised grip texture
//   2 stipple / textured polymer or gel coat     3 parkerised / phosphate / nitride steel
//   4 blued / polished steel (directional polish) 5 wood (laminate when ply_mm > 0)
//   6 hard-anodised aluminium                   7 rubber
//   8 plain (paint, markings, brass): wear only
// Wear is driven by signed surface curvature measured from the interpolated
// normal: tight convex bevels wear (bare metal under coatings, scuffs on
// polymer, varnish rubbed off wood), tight concave fillets collect dust, and
// gently rounded surfaces pick up a handling polish in broad patches. Nothing
// here is periodic except the moulded Gen5 grid, which is on the real gun.
uniform vec4 albedo_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform int pattern = 0;
uniform float pitch = 0.0016;
uniform float bump = 1.0;
uniform float grain = 1.0;
uniform float edge_wear : hint_range(0.0, 1.0) = 0.0;
uniform vec3 wear_color : source_color = vec3(0.32, 0.33, 0.34);
uniform vec3 grain_axis = vec3(1.0, 0.0, 0.0);
uniform vec3 ply_axis = vec3(0.0, 0.0, 1.0);
uniform float ply_mm = 0.0;
uniform float mottle = 1.0;
uniform float dust = 0.5;
uniform float polish = 0.5;

varying vec3 p_obj;
varying vec3 n_obj;

float h3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm2(vec3 p) {
	return noise3(p) * 0.65 + noise3(p * 2.03 + vec3(1.7)) * 0.35;
}

float fbm(vec3 p) {
	return noise3(p) * 0.55 + noise3(p * 2.03) * 0.28 + noise3(p * 4.11) * 0.17;
}

// Noise stretched along an axis: polish marks, wood fibres.
float stretched(vec3 p, vec3 a, float along, float across) {
	float t = dot(p, a);
	return noise3((p - a * t) * across + a * (t * along));
}

// Raised truncated pyramids on a square grid, like moulded grip texture.
float pyramids(vec2 uv) {
	vec2 c = fract(uv) - 0.5;
	float d = max(abs(c.x), abs(c.y));
	return 1.0 - smoothstep(0.18, 0.42, d);
}

void vertex() {
	p_obj = VERTEX;
	n_obj = NORMAL;
}

void fragment() {
	vec3 p = p_obj;
	vec3 dpx = dFdx(p);
	vec3 dpy = dFdy(p);
	float d2 = dot(dpx, dpx) + dot(dpy, dpy);
	float span = sqrt(max(dot(dpx, dpx), dot(dpy, dpy)));
	// Signed mean curvature (1/radius, object metres): + convex, - concave.
	float k = (dot(dFdx(n_obj), dpx) + dot(dFdy(n_obj), dpy)) / max(d2, 1e-14);
	// Bevels run ~1.2 mm on machined metal up to ~5 mm on moulded stocks.
	float convex = smoothstep(150.0, 700.0, k);
	float concave = smoothstep(180.0, 700.0, -k);
	float rounded = smoothstep(12.0, 90.0, k) * (1.0 - convex);

	// Shared low-frequency fields: tone drift and where hands and gear rub.
	float broad = fbm2(p * 45.0);
	float region = fbm2(p * 13.0 + vec3(11.7, 3.3, 7.9));
	float fine = noise3(p * 2300.0);

	vec3 colour = albedo_color.rgb * (1.0 + (broad - 0.5) * 0.12 * grain);
	float rough = roughness + (broad - 0.5) * 0.10 * grain;
	float metal = metallic;
	float height = 0.0;
	float amp = 0.0;
	float vis_fine = 1.0 - smoothstep(0.00006, 0.00025, span);
	// Bevels and fillets are ~1 mm: once a pixel covers about that much the
	// curvature estimate breaks into per-quad dashes, so wear and dust fade
	// out with on-screen size instead of drawing stitched outlines.
	float vis_edge = 1.0 - smoothstep(0.0007, 0.0018, span);
	convex *= vis_edge;
	concave *= vis_edge;

	if (pattern == 0) {
		// Injection moulding: EDM-textured mould gives a fine even matte.
		height = noise3(p * 5500.0);
		amp = 0.000010 * bump;
		rough += (height - 0.5) * 0.06 * vis_fine;
	} else if (pattern == 1) {
		vec3 w = abs(normalize(n_obj));
		w = pow(w, vec3(4.0));
		w /= (w.x + w.y + w.z);
		float hx = pyramids(p.yz / pitch);
		float hy = pyramids(p.xz / pitch);
		float hz = pyramids(p.xy / pitch);
		float vis = 1.0 - smoothstep(pitch * 0.15, pitch * 0.45, span);
		height = ((hx * w.x + hy * w.y + hz * w.z) * 0.85 + noise3(p * 9000.0) * 0.15) * vis;
		amp = 0.00022 * bump;
		// Tops of the texture are polished by hands.
		rough -= height * 0.10;
		colour *= 1.0 + height * 0.07;
	} else if (pattern == 2) {
		float vis = 1.0 - smoothstep(pitch * 0.15, pitch * 0.45, span);
		height = (smoothstep(0.35, 0.75, noise3(p / pitch)) + noise3(p * 7000.0) * 0.2) * vis;
		amp = 0.00012 * bump;
		rough += (height - 0.5) * 0.05;
	} else if (pattern == 3) {
		// Phosphate crystals: matte, grey-black, blotchy where the bath and
		// the oil soaked in unevenly.
		float blotch = fbm(p * 70.0 + vec3(5.1));
		colour *= mix(0.8, 1.16, blotch * mottle + 0.5 * (1.0 - mottle));
		colour = mix(colour, colour * vec3(0.96, 1.0, 0.97), smoothstep(0.55, 0.8, region) * mottle);
		height = noise3(p * 11000.0);
		amp = 0.000006 * bump * grain;
		rough += (height - 0.5) * 0.12 * vis_fine;
		rough -= smoothstep(0.55, 0.85, fbm2(p * 24.0 + vec3(2.2))) * 0.10 * mottle;
	} else if (pattern == 4) {
		// Blued / nitrided steel: a faint directional polish under the colour.
		vec3 a = normalize(grain_axis);
		height = stretched(p, a, 260.0, 7000.0);
		amp = 0.000004 * bump * grain;
		rough += (height - 0.5) * 0.06 * grain * vis_fine;
		colour *= 1.0 + (fbm2(p * 90.0) - 0.5) * 0.05;
	} else if (pattern == 5) {
		vec3 a = normalize(grain_axis);
		float t = dot(p, a);
		vec3 q = p - a * t;
		float warp = noise3(p * 60.0) - 0.5;
		// Fibre streaks follow the grain; figure bands wander across it.
		float fibres = noise3((q + vec3(warp * 0.003)) * 1300.0 + a * (t * 40.0));
		float figure = fbm2(q * 200.0 + a * (t * 7.0) + vec3(warp * 1.5));
		float pores = smoothstep(0.72, 0.92, noise3(q * 3600.0 + a * (t * 300.0))) * vis_fine;
		colour *= mix(0.74, 1.16, figure) * mix(0.9, 1.06, fibres) * (1.0 - pores * 0.18);
		if (ply_mm > 0.0) {
			// Parallel-laminated veneer: where the shaped surface cuts across
			// the plies each layer shows its own stain uptake, separated by a
			// thin dark glue line; plies wander slightly so the contours do.
			vec3 pa = normalize(ply_axis);
			float layer = dot(p, pa) * 1000.0 / ply_mm + (fbm2(p * 22.0) - 0.5) * 2.0;
			float id = floor(layer);
			float f = fract(layer);
			colour *= mix(0.72, 1.14, h3(vec3(id * 1.37, 7.1, id * 0.61)));
			float glue = 1.0 - smoothstep(0.0, 0.06, min(f, 1.0 - f));
			float vis_ply = 1.0 - smoothstep(ply_mm * 0.0002, ply_mm * 0.0006, span);
			colour *= 1.0 - glue * 0.45 * vis_ply;
		}
		height = fibres * 0.6 + pores * 0.4;
		amp = 0.000008 * bump;
		// Varnish: sheen varies with build-up and rubbing.
		rough += (figure - 0.5) * 0.06 + pores * 0.12;
	} else if (pattern == 6) {
		// Bead-blasted then hard-anodised: uniform satin-matte with a very
		// fine grain and a faint dye-lot drift.
		colour *= 1.0 + (fbm2(p * 32.0 + vec3(9.0)) - 0.5) * 0.12 * mottle;
		height = noise3(p * 8000.0);
		amp = 0.000005 * bump;
		rough += (height - 0.5) * 0.07 * vis_fine;
	} else if (pattern == 7) {
		// Rubber: soft matte micro-texture, a light bloom of dust and lint.
		float vis = 1.0 - smoothstep(pitch * 0.15, pitch * 0.45, span);
		height = (smoothstep(0.3, 0.8, noise3(p / pitch)) * 0.7 + noise3(p * 6000.0) * 0.3) * vis;
		amp = 0.00010 * bump;
		colour = mix(colour, vec3(0.30, 0.29, 0.27), smoothstep(0.5, 0.85, fbm2(p * 40.0)) * 0.10 * dust);
		rough += (height - 0.5) * 0.05;
	}

	// Smudges, oil and handling: breaks up reflections on every finish.
	float smudge = fbm2(p * 26.0 + vec3(4.4, 1.2, 8.3));
	rough += (smudge - 0.5) * 0.16 * grain;

	// Edge wear on tight convex bevels: every edge lightens a little, the
	// ones in high-contact patches go through to the base material.
	float contact = smoothstep(0.38, 0.72, region);
	float chips = smoothstep(0.2, 0.8, fine);
	float worn = edge_wear * convex * mix(0.35, 1.0, contact) * mix(0.55, 1.0, chips);
	bool coated_metal = pattern == 3 || pattern == 4 || pattern == 6 || (pattern == 8 && metallic > 0.5);
	if (coated_metal) {
		float bare = smoothstep(0.25, 0.75, worn);
		vec3 thin = colour * 1.7 + vec3(0.03);
		colour = mix(colour, mix(thin, wear_color, bare), min(worn * 2.0, 1.0));
		metal = mix(metal, 1.0, bare);
		rough = mix(rough, 0.34, bare);
	} else if (pattern == 5) {
		// Varnish rubbed off: paler, drier wood.
		colour = mix(colour, colour * 1.35 + vec3(0.02, 0.012, 0.006), worn);
		rough = mix(rough, 0.68, worn);
	} else {
		// Polymer and rubber scuff paler and rub glossier.
		colour = mix(colour, colour * 1.4 + vec3(0.025), worn * 0.7);
		rough = mix(rough, rough - 0.16, worn);
	}

	// Every rounded edge is burnished a little by hands, holsters and slings:
	// a slightly paler, smoother rim that catches the light and draws the form.
	rough -= convex * 0.14;
	colour *= 1.0 + convex * 0.10;

	// Handling polish: broad patches on rounded surfaces get a little sheen.
	float handled = polish * rounded * smoothstep(0.5, 0.78, region);
	rough -= handled * 0.12;
	colour *= 1.0 + handled * (coated_metal ? 0.06 : 0.03);

	// Dust and old oil in tight concave fillets.
	float dusty = dust * concave * mix(0.5, 1.0, fine);
	colour = mix(colour, vec3(0.34, 0.32, 0.28), dusty * 0.28);
	rough = mix(rough, 0.85, dusty * 0.5);
	metal *= 1.0 - dusty * 0.5;
	AO = 1.0 - concave * 0.35;
	AO_LIGHT_AFFECT = 0.25;

	ALBEDO = colour;
	METALLIC = clamp(metal, 0.0, 1.0);
	ROUGHNESS = clamp(rough, 0.08, 0.98);

	// Bump from the height field via screen-space derivatives; sub-pixel
	// micro-texture fades out instead of sparkling.
	if (pattern == 0 || (pattern >= 3 && pattern <= 6)) {
		amp *= vis_fine;
	}
	float hh = height * amp;
	vec3 nn = normalize(NORMAL);
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 cy = cross(sy, nn);
	vec3 cx = cross(nn, sx);
	float det = dot(sx, cy);
	vec3 grad = dFdx(hh) * cy + dFdy(hh) * cx;
	NORMAL = normalize(nn - sign(det) * grad / max(abs(det), 1e-12));
}
