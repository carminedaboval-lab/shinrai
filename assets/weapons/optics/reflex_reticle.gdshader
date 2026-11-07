shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// Collimated on the physical rear glass: never disable depth testing.
uniform vec3 sight_axis = vec3(0.0, 0.0, -1.0);
uniform float dot_diameter_moa : hint_range(1.0, 8.0) = 3.5;
uniform float illumination : hint_range(0.0, 1.0) = 0.95;
varying vec3 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 ray = normalize(world_point - CAMERA_POSITION_WORLD);
	vec3 axis = normalize(sight_axis);
	float radial_angle = length(cross(ray, axis));
	// Keep angular sizing when resolvable, with a compact 3-4 pixel core at
	// normal view resolutions. Derivatives set coverage, never its aim point.
	float pixel_angle = max(length(dFdx(ray)), length(dFdy(ray)));
	float radius = max(tan(dot_diameter_moa * 0.000290888209 * 0.5), pixel_angle * 1.75);
	float aa = max(pixel_angle * 0.45, 0.000001);
	float facing = step(0.0, dot(ray, axis));
	float core = (1.0 - smoothstep(radius - aa, radius + aa, radial_angle)) * facing;
	// Faint optical scatter fades completely by about 7 pixels diameter at
	// the resolution floor. It scales with an actually resolved angular dot.
	float halo_radius = max(radius * 2.0, pixel_angle * 3.6);
	float halo_distance = radial_angle / max(halo_radius, 0.000001);
	float halo = exp(-4.0 * halo_distance * halo_distance);
	halo *= (1.0 - smoothstep(halo_radius - aa, halo_radius, radial_angle)) * facing;
	float core_alpha = core * illumination;
	float halo_alpha = halo * illumination * 0.12 * (1.0 - core);
	float coverage = core_alpha + halo_alpha;
	float core_weight = core_alpha / max(coverage, 0.000001);
	// Coverage is applied once through alpha. The compact red core is brighter
	// than its restrained halo, without whitening or tinting the whole lens.
	ALBEDO = vec3(1.0, 0.008, 0.002);
	EMISSION = vec3(1.0, 0.006, 0.001) * illumination * mix(1.5, 5.0, core_weight);
	// The physical front pane supplies neutral glass; leave the rear window
	// fully transparent outside the reticle instead of adding a green veil.
	ALPHA = coverage;
}
