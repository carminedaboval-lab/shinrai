shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// Reference-inspired etched prism pattern, attached to real rear glass.
// This shader draws the reticle/eye shadow, not a magnified world image.
uniform vec3 sight_axis = vec3(0.0, 0.0, -1.0);
uniform vec3 sight_right = vec3(1.0, 0.0, 0.0);
uniform vec3 sight_up = vec3(0.0, 1.0, 0.0);
uniform vec3 sight_origin = vec3(0.0);
uniform float eye_relief_m = 0.10;
uniform float eye_relief_tolerance_m = 0.055;
uniform float eye_box_radius_m = 0.008;
uniform float aperture_radius_m = 0.0118;
uniform float reticle_scale = 0.008;
uniform float illumination : hint_range(0.0, 1.0) = 0.55;
uniform sampler2D scoped_view : source_color, filter_linear, repeat_disable;
uniform bool scoped_view_ready = false;
uniform vec2 outside_half_tangent = vec2(0.35, 0.23);
varying vec3 world_point;

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(p - a - ab * clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0));
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 axis = normalize(sight_axis);
	vec3 right = normalize(sight_right);
	vec3 up = normalize(sight_up);
	vec3 ray = normalize(world_point - CAMERA_POSITION_WORLD);
	float forward = dot(ray, axis);
	vec2 tangent = vec2(dot(ray, right), dot(ray, up)) / max(forward, 0.001);
	vec2 p = tangent / reticle_scale;
	float aa = max(length(fwidth(p)) * 0.5, 0.001);
	// Open horseshoe, pointed chevron (tip is the aim point), fine lower stadia.
	float horseshoe = max(abs(length(p) - 1.0) - 0.065, -0.48 - p.y);
	float chevron = min(segment_distance(p, vec2(-0.22, -0.20), vec2(0.0)), segment_distance(p, vec2(0.0), vec2(0.22, -0.20))) - 0.028;
	float lit_distance = min(horseshoe, chevron);
	float etched_distance = segment_distance(p, vec2(0.0, -0.38), vec2(0.0, -1.72)) - 0.014;
	for (int i = 0; i < 3; i++) {
		float y = -0.72 - float(i) * 0.48;
		float w = 0.26 - float(i) * 0.055;
		etched_distance = min(etched_distance, segment_distance(p, vec2(-w, y), vec2(w, y)) - 0.014);
	}
	float lit_pattern = 1.0 - smoothstep(-aa, aa, lit_distance);
	float etched = 1.0 - smoothstep(-aa, aa, min(lit_distance, etched_distance));
	vec3 eye = CAMERA_POSITION_WORLD - sight_origin;
	float relief = -dot(eye, axis);
	vec2 offset = vec2(dot(eye, right), dot(eye, up)) / max(eye_box_radius_m, 0.0001);
	vec3 surface = world_point - sight_origin;
	vec2 aperture = vec2(dot(surface, right), dot(surface, up)) / aperture_radius_m;
	float relief_error = abs(relief - eye_relief_m) / max(eye_relief_tolerance_m, 0.0001);
	float pupil_radius = 1.14 - max(0.0, relief_error - 0.45) * 0.4;
	float pupil = (1.0 - smoothstep(pupil_radius - 0.12, pupil_radius, length(aperture + offset))) * step(0.0, relief);
	float shadow = 1.0 - pupil;
	float lit = lit_pattern * illumination * pupil * step(0.0, forward);
	vec2 image_uv = vec2(0.5) + tangent / (2.0 * outside_half_tangent) * vec2(1.0, -1.0);
	float image_valid = step(0.0, image_uv.x) * step(image_uv.x, 1.0) * step(0.0, image_uv.y) * step(image_uv.y, 1.0);
	vec3 sight_picture = texture(scoped_view, image_uv).rgb * pupil * image_valid;
	vec3 etched_color = mix(vec3(0.006, 0.008, 0.009), vec3(0.92, 0.10, 0.025), lit);
	ALBEDO = scoped_view_ready ? mix(sight_picture, etched_color, max(shadow, etched)) : etched_color;
	EMISSION = vec3(1.0, 0.045, 0.008) * lit * 0.65;
	ALPHA = scoped_view_ready ? 1.0 : max(shadow, etched * pupil * step(0.0, forward));
}
