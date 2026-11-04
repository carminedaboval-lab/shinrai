shader_type spatial;
render_mode diffuse_burley, cull_disabled;
// Clipped garden shrub (刈り込み): satsuki azalea, boxwood, holly. A dense core
// and two leaf shells; each shell keeps only some of its small leaves, so the
// silhouette is leafy and the core shows through as shade between them.
// Instance COLOR.rgb is the species' leaf colour, COLOR.a how much autumn bronze.
uniform float shell = 0.0;
uniform float leaf_size = 0.028;
varying vec3 world;
varying vec4 tint;

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tint = COLOR;
}

void fragment() {
	// Nearest leaf: a jittered cell in world space, so leaves stay leaf-sized
	// whatever the shrub's scale.
	vec3 p = world / leaf_size;
	vec3 cell = floor(p);
	float best = 8.0;
	float second = 8.0;
	vec3 id = cell;
	for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) for (int z = -1; z <= 1; z++) {
		vec3 c = cell + vec3(float(x), float(y), float(z));
		vec3 o = c + hash3(c) * 0.9 + 0.05;
		float d = length(p - o);
		if (d < best) { second = best; best = d; id = c; }
		else if (d < second) { second = d; }
	}
	vec3 h = hash3(id + 17.0);
	float edge = smoothstep(0.0, 0.22, second - best);
	vec3 leaf = tint.rgb * mix(0.7, 1.25, h.x);
	// Autumn: some leaves turn bronze and red on azaleas.
	leaf = mix(leaf, vec3(0.3, 0.1, 0.045) * mix(0.8, 1.2, h.x), step(1.0 - tint.a, h.y) * 0.8);
	// Fresh tips are a touch lighter and yellower on the outer shell.
	leaf = mix(leaf, leaf * vec3(1.2, 1.25, 0.9), shell * 0.2 * h.z);
	if (shell > 0.5) {
		float keep = shell > 1.5 ? 0.38 : 0.62;
		if (h.z > keep || best > 0.48) discard;
	}
	float depth = shell > 0.5 ? 1.0 : 0.42;
	ALBEDO = leaf * mix(0.45, 1.0, edge) * depth;
	// Each leaf faces its own way: tilt the normal by the leaf's hash.
	vec3 tilt = (h - 0.5) * 1.3;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(tilt, 0.0)).xyz);
	ROUGHNESS = mix(0.42, 0.7, h.y);
	SPECULAR = 0.45;
	BACKLIGHT = leaf * 0.35;
}
