shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// Collimated on the physical rear glass: never disable depth testing.
uniform vec3 sight_axis = vec3(0.0, 0.0, -1.0);
uniform float dot_diameter_moa : hint_range(1.0, 8.0) = 3.5;
uniform float illumination : hint_range(0.0, 1.0) = 0.85;
varying vec3 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 ray = normalize(world_point - CAMERA_POSITION_WORLD);
	vec3 axis = normalize(sight_axis);
	float radial_angle = length(cross(ray, axis));
	// A subpixel 3.5 MOA dot previously vanished between pixel centres at
	// common resolutions. Preserve its angular size with a tiny coverage floor.
	float pixel_angle = max(length(dFdx(ray)), length(dFdy(ray)));
	float radius = max(tan(dot_diameter_moa * 0.000290888209 * 0.5), pixel_angle * 1.05);
	float aa = max(pixel_angle * 0.65, 0.000001);
	float dot_mask = (1.0 - smoothstep(radius - aa, radius + aa, radial_angle)) * step(0.0, dot(ray, axis));
	float lit = dot_mask * illumination;
	// Coverage belongs in alpha only. Multiplying it into colour and emission
	// as well darkened the small dot twice, making it unreadable in daylight.
	float on_dot = step(0.001, dot_mask);
	ALBEDO = mix(vec3(0.22, 0.31, 0.30), vec3(1.0, 0.025, 0.008), on_dot);
	EMISSION = vec3(1.0, 0.015, 0.004) * on_dot * illumination * 2.5;
	ALPHA = max(0.018, lit);
}
