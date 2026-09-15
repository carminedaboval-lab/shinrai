shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D source_albedo : source_color;
uniform sampler2D source_normal : hint_normal;
uniform bool use_source_normal = false;
uniform vec2 crop_origin = vec2(0.400390625, 0.576171875);
uniform vec2 crop_size = vec2(0.17578125, 0.17578125);
uniform vec2 tile_count = vec2(6.0, 2.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.88;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.55;

vec2 mirrored_crop_uv(vec2 base_uv) {
	vec2 tiled = base_uv * tile_count;
	vec2 cell = floor(tiled);
	vec2 local_uv = fract(tiled);
	if (mod(cell.x, 2.0) >= 1.0) {
		local_uv.x = 1.0 - local_uv.x;
	}
	if (mod(cell.y, 2.0) >= 1.0) {
		local_uv.y = 1.0 - local_uv.y;
	}
	return crop_origin + local_uv * crop_size;
}

void fragment() {
	vec2 source_uv = mirrored_crop_uv(UV);
	vec4 base = texture(source_albedo, source_uv);
	ALBEDO = base.rgb;
	METALLIC = 0.0;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.28;
	if (use_source_normal) {
		NORMAL_MAP = texture(source_normal, source_uv).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
}
