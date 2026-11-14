shader_type spatial;

// UV is in metres. Positive X points towards the finished kerb.
uniform sampler2D aggregate : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D road_orm : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float edge_line_offset = 2.34;
uniform float line_width = 0.10;
uniform vec4 paint_colour : source_color = vec4(0.81, 0.80, 0.76, 1.0);
// The shop row is measured west to east. Its signal is beyond the east end.
uniform bool shop_row_paint = false;
uniform float crossing_s = 171.0;

// Pixel coverage of a strip; narrow paint fades instead of flickering at distance.
float strip(float distance_to_middle, float half_width, float pixel) {
	return clamp((min(distance_to_middle + pixel * 0.5, half_width) -
		max(distance_to_middle - pixel * 0.5, -half_width)) / pixel, 0.0, 1.0);
}

// Integral of repeating 45 cm bars with 45 cm gaps. Averaging across a pixel
// keeps the far crossing visible even when several bars occupy the same pixel.
float bar_integral(float x) {
	return floor(x / 0.90) * 0.45 + min(mod(x, 0.90), 0.45);
}

void fragment() {
	vec2 tile_uv = UV / 2.0;
	vec3 stone = texture(aggregate, tile_uv).rgb;
	vec3 orm = texture(road_orm, tile_uv).rgb;
	// Turn the texture coordinates on the larger scale so the weathering doesn't repeat
	// in step with the road grain. Both samples use mipmaps as the street recedes.
	float wear = texture(road_orm, UV.yx / 0.79 + vec2(0.23, 0.47)).g;
	float chipped_edge = (wear - 0.86) * 0.08;
	float half_line = 0.5 * line_width - chipped_edge;
	float lateral = UV.x - edge_line_offset;
	float pixel = max(0.001, fwidth(UV.x));
	// Area coverage also dims the stripe when its width falls below one pixel.
	float overlap = min(lateral + pixel * 0.5, half_line) - max(lateral - pixel * 0.5, -half_line);
	float coverage = clamp(overlap / pixel, 0.0, 1.0);
	if (shop_row_paint) {
		float along = UV.y - crossing_s;
		float px_s = max(0.001, fwidth(UV.y));
		float lane_end = 1.0 - smoothstep(-4.18-px_s*0.5, -4.18+px_s*0.5, along);
		float centre = strip(UV.x, 0.075-chipped_edge, pixel) * lane_end;
		// Left-hand traffic: only the northern (eastbound) approach stops here.
		float stop = strip(along+4.0, 0.18-chipped_edge, px_s) *
			strip(UV.x+3.45, 3.25, pixel);
		float bars = (bar_integral(UV.x+0.225+pixel*0.5) -
			bar_integral(UV.x+0.225-pixel*0.5)) / pixel;
		float zebra = strip(along, 1.60-chipped_edge, px_s) *
			strip(UV.x, 6.55, pixel) * clamp(bars, 0.0, 1.0);
		// Two edge lines give way to the crossing, leaving a clear pedestrian entry.
		float edge_gate = 1.0 - strip(along, 2.0, px_s);
		float far_edge = strip(UV.x+6.71, 0.05-chipped_edge, pixel);
		coverage = max(max(coverage,far_edge)*edge_gate, max(centre, max(stop, zebra)));
	}
	float grain = dot(stone, vec3(0.2126, 0.7152, 0.0722));
	float paint = coverage * mix(0.22, 0.94, smoothstep(0.014, 0.045, grain));

	ALBEDO = mix(stone, paint_colour.rgb, paint);
	ROUGHNESS = mix(orm.g, 0.82, paint);
	AO = mix(orm.r, 1.0, paint);
}
