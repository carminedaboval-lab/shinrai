shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// One layer of a stacked lawn. Every layer cuts the same field of fine blades at
// its own height, so together they read as one continuous carpet of grass.
uniform float grass_height = 0.08;
uniform vec3 root_color : source_color = vec3(0.13, 0.20, 0.08);
uniform vec3 tip_color : source_color = vec3(0.34, 0.45, 0.21);
uniform vec3 dry_color : source_color = vec3(0.52, 0.52, 0.29);
const float BLADES_PER_M = 150.0;
varying vec3 world_position;
varying float layer;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise21(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x), f.y);
}

// Returns the blade's own random value when this point is inside a blade at
// height h, or -1.0 when it is not. A blade narrows to nothing at its tip.
float blade(vec2 p, float h, float reach) {
	vec2 cell = floor(p);
	float value = hash21(cell);
	float tall = mix(0.5, 1.0, value) * reach;
	if (h > tall) return -1.0;
	vec2 centre = vec2(hash21(cell + vec2(3.7, 1.3)), hash21(cell + vec2(8.1, 5.9))) * 0.6 + 0.2;
	float width = 0.2 + 0.32 * (1.0 - h / tall);
	return length(fract(p) - centre) < width ? value : -1.0;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	layer = VERTEX.y / grass_height;
}

void fragment() {
	vec2 p = world_position.xz;
	float h = layer;
	// Blades bend over as they rise, in directions that drift across the lawn.
	float bend = noise21(p * 1.6) * 6.2832 + noise21(p * 7.0) * 2.0;
	vec2 lean = vec2(cos(bend), sin(bend));
	// Turned off the world axes, so the blade grid never shows as rows.
	vec2 q = mat2(vec2(0.857, 0.515), vec2(-0.515, 0.857)) * (p + lean * 0.016 * h * h);
	float reach = mix(0.9, 1.0, noise21(p * 0.8) * 0.6 + noise21(p * 4.0) * 0.4);
	// Blade size doubles in steps as they shrink below a pixel, dithered between steps.
	float pixel = sqrt(max(length(dFdx(p)) * length(dFdy(p)), 0.00000001));
	float level = clamp(log2(max(pixel * BLADES_PER_M * 1.3, 1.0)), 0.0, 5.0);
	float step_down = floor(level);
	step_down += hash21(q * 97.0) < level - step_down ? 1.0 : 0.0;
	float scale = BLADES_PER_M / pow(2.0, step_down);
	float value = blade(q * scale, h, reach);
	if (value < 0.0) value = blade(q * scale * 1.6 + vec2(19.0, 7.0), h * 1.08, reach);
	if (value < 0.0) discard;
	float rise = h / reach;
	float age = noise21(p * 0.13 + vec2(4.0, 9.0)) * 0.7 + value * 0.3;
	vec3 tip = mix(tip_color, dry_color, smoothstep(0.5, 0.85, age) * 0.45);
	vec3 colour = mix(root_color, tip, smoothstep(0.1, 0.95, rise));
	colour *= mix(0.72, 1.18, value) * mix(0.82, 1.12, noise21(p * 0.09) * 0.6 + noise21(p * 0.31) * 0.4);
	ALBEDO = colour;
	// A gentle tilt only: under a low sun a stronger one reads as dark blotches.
	vec3 world_normal = normalize(vec3(lean.x * (0.05 + h * 0.12), 1.0, lean.y * (0.05 + h * 0.12)));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	ROUGHNESS = 0.68;
	SPECULAR = 0.22;
	AO = mix(0.3, 1.0, smoothstep(0.0, 0.8, rise));
	AO_LIGHT_AFFECT = 0.5;
	BACKLIGHT = colour * 0.45;
}
