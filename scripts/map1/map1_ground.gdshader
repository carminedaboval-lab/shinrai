shader_type spatial;
// The Map 1 blockout's ground: a flat grid lifted to the generated heights, with the
// generated ground picture (1 pixel = 1 metre) laid over it.

uniform sampler2D height_map : filter_nearest, repeat_disable;
uniform sampler2D ground_map : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 grid = vec2(2.0, 2.0);
uniform float cell = 2.5;

float height_at(ivec2 point) {
	return texelFetch(height_map, clamp(point, ivec2(0), ivec2(grid) - ivec2(1)), 0).r;
}

void vertex() {
	ivec2 point = ivec2(round(UV * (grid - vec2(1.0))));
	VERTEX.y = height_at(point);
	NORMAL = normalize(vec3(
		height_at(point - ivec2(1, 0)) - height_at(point + ivec2(1, 0)),
		2.0 * cell,
		height_at(point - ivec2(0, 1)) - height_at(point + ivec2(0, 1))));
}

void fragment() {
	ALBEDO = texture(ground_map, UV).rgb;
	ROUGHNESS = 0.95;
}
