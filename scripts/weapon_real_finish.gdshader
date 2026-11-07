shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// Real-counterpart weapon finishes. Everything is evaluated in the mesh's own
// space so texture rides with moving slides, bolts and magazines.
// pattern: 0 smooth moulding/coating, 1 Gen5-style raised grip texture,
// 2 stipple, 3 parkerised/phosphate steel, 4 machined/blued steel, 5 wood.
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

float fbm(vec3 p) {
	return noise3(p) * 0.55 + noise3(p * 2.03) * 0.28 + noise3(p * 4.11) * 0.17;
}

// Raised truncated pyramids on a square grid, like moulded grip texture.
float pyramids(vec2 uv) {
	vec2 c = fract(uv) - 0.5;
	float d = max(abs(c.x), abs(c.y));
	return 1.0 - smoothstep(0.18, 0.42, d);
}

float pattern_height(vec3 p, vec3 w) {
	if (pattern == 1) {
		float hx = pyramids(p.yz / pitch);
		float hy = pyramids(p.xz / pitch);
		float hz = pyramids(p.xy / pitch);
		return (hx * w.x + hy * w.y + hz * w.z) * 0.85 + noise3(p * 9000.0) * 0.15;
	}
	if (pattern == 2) {
		return smoothstep(0.35, 0.75, noise3(p / pitch)) + noise3(p * 7000.0) * 0.2;
	}
	if (pattern == 3) {
		return noise3(p * 14000.0) * 0.6 + noise3(p * 5200.0) * 0.4;
	}
	if (pattern == 4) {
		// Fine directional polish grain along grain_axis.
		vec3 a = normalize(grain_axis);
		vec3 q = p - a * dot(p, a);
		return noise3(q * 9000.0 + a * dot(p, a) * 180.0);
	}
	if (pattern == 5) {
		vec3 a = normalize(grain_axis);
		float along = dot(p, a);
		vec3 q = p - a * along;
		float rings = fbm(q * 380.0 + vec3(along * 9.0)) * 0.7 + fbm(q * 1400.0 + vec3(along * 30.0)) * 0.3;
		return rings;
	}
	return noise3(p * 6000.0);
}

void vertex() {
	p_obj = VERTEX;
	n_obj = NORMAL;
}

void fragment() {
	vec3 w = abs(normalize(n_obj));
	w = pow(w, vec3(4.0));
	w /= (w.x + w.y + w.z);
	float span = max(length(dFdx(p_obj)), length(dFdy(p_obj)));
	// Detail fades out once a pattern cell is smaller than a couple of pixels.
	float cell = pattern == 1 || pattern == 2 ? pitch : 0.0004;
	float visible = 1.0 - smoothstep(cell * 0.25, cell * 0.8, span);
	float height = pattern_height(p_obj, w);
	float broad = fbm(p_obj * 55.0);

	vec3 colour = albedo_color.rgb * (1.0 + (broad - 0.5) * 0.10 * grain);
	float smudge = fbm(p_obj * 160.0 + vec3(3.1));
	float rough = roughness + (broad - 0.5) * 0.14 * grain + (smudge - 0.5) * 0.10 * grain;
	if (pattern == 1) {
		// Tops of the texture are polished by hands.
		rough -= height * 0.10 * visible;
		colour *= 1.0 + height * 0.07 * visible;
	} else if (pattern == 5) {
		colour *= mix(0.48, 1.32, smoothstep(0.2, 0.8, height));
		rough += (height - 0.5) * 0.12;
	} else {
		rough += (height - 0.5) * 0.07 * grain * visible;
	}

	// Edge wear from screen-space curvature: bevels on metal go bright first.
	vec3 nn = normalize(NORMAL);
	float curvature = (length(dFdx(nn)) + length(dFdy(nn))) / max(span * 2.0, 0.00001);
	float worn = smoothstep(70.0, 420.0, curvature) * smoothstep(0.2, 0.7, noise3(p_obj * 520.0)) * edge_wear;
	colour = mix(colour, wear_color, worn);
	rough = mix(rough, 0.32, worn);

	ALBEDO = colour;
	METALLIC = mix(metallic, max(metallic, 0.9), worn);
	ROUGHNESS = clamp(rough, 0.08, 0.98);

	float amp = pattern == 1 ? 0.00022 * bump : pattern == 2 ? 0.00012 * bump : 0.000012 * bump * grain;
	float hh = height * amp * visible;
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 cy = cross(sy, nn);
	vec3 cx = cross(nn, sx);
	float det = dot(sx, cy);
	vec3 grad = dFdx(hh) * cy + dFdy(hh) * cx;
	NORMAL = normalize(nn - sign(det) * grad / max(abs(det), 1e-12));
}
