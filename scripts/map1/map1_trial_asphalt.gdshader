shader_type spatial;

// UV is in metres. Positive X points towards the finished kerb.
uniform sampler2D aggregate : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D road_orm : repeat_enable, filter_linear_mipmap_anisotropic;
// Linear surface-coverage data, thresholded BEFORE its mipmaps were generated.
// Independent grayscale endpoints store light/heavy wear; no source_color hint.
uniform sampler2D paint_coverage_light : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D paint_coverage_heavy : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float edge_line_offset = 2.34;
uniform float line_width = 0.10;
uniform vec4 paint_colour : source_color = vec4(0.81, 0.80, 0.76, 1.0);
// The shop row is measured west to east. Its signal is beyond the east end.
uniform bool shop_row_paint = false;
uniform float crossing_s = 171.0;
// Metres: corridor-centre magnitude (0 for a narrow shared lane), median half-width.
// A negative centre disables traffic wear on unrelated asphalt patches.
uniform vec2 traffic_wear_layout = vec2(-1.0, 0.0);

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

// Mix independently filtered scalar coverage endpoints as an authored mixture.
// This is not the exact intermediate nonlinear threshold curve. Never threshold
// filtered data or add a camera-dependent opacity/near-far material blend.
float coverage_at_damage(float light, float heavy, float damage) {
	return mix(light, heavy, clamp(damage, 0.0, 1.0));
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
	// Surface coverage remains anchored to the road's metre UVs at every view.
	// These fields approximate accumulated wear; they are not measured aging.
	float footprint = max(fwidth(UV.x), fwidth(UV.y));
	float patch_lod = max(6.0, log2(max(0.001, footprint) * 2048.0 / 21.0));
	vec3 patch_stone = textureLod(aggregate,
		UV.yx / vec2(37.0, 21.0) + vec2(0.19, 0.43), patch_lod).rgb;
	float patch_grain = dot(patch_stone, vec3(0.2126, 0.7152, 0.0722));
	float patch_wear = smoothstep(0.0263, 0.0305, patch_grain);
	float damage = 0.15 + 0.50 * patch_wear;
	float wheel_flow = 0.0;
	if (shop_row_paint && traffic_wear_layout.x >= 0.0) {
		// Same measured1.4m track and corridor bounds as v2. Strong abrasion
		// belongs only where vehicles cross paint near this known crossing.
		float lane_out = abs(UV.x) - traffic_wear_layout.x;
		float wheel_distance = abs(abs(lane_out) - 0.70);
		float wheels = 1.0 - smoothstep(0.16, 0.45, wheel_distance);
		float braking = 1.0 - smoothstep(3.0, 16.0, abs(UV.y - crossing_s));
		float carriageway = step(traffic_wear_layout.y, abs(UV.x));
		wheel_flow = wheels * braking * carriageway;
		damage = clamp(damage + 0.20 * wheel_flow, 0.0, 1.0);
	}
	// About1.5..4.5cm chips, rather than v2's smaller8m-period grain.
	// Native anisotropic mip filtering averages the actual retained paint.
	float fine_light = texture(paint_coverage_light, UV.yx / 12.0 + vec2(0.37, 0.63)).r;
	float fine_heavy = texture(paint_coverage_heavy, UV.yx / 12.0 + vec2(0.37, 0.63)).r;
	float retained_paint = coverage_at_damage(fine_light, fine_heavy, damage);
	if (shop_row_paint && traffic_wear_layout.x >= 0.0) {
		// A second scale groups missing paint into roughly8..25cm scars.
		// Within a wheel core, absent coarse coverage exposes bare asphalt;
		// intact islands retain the finer chips. No screen-distance blend.
		float coarse_light = texture(paint_coverage_light,
			UV.yx / 64.0 + vec2(0.13, 0.79)).r;
		float coarse_heavy = texture(paint_coverage_heavy,
			UV.yx / 64.0 + vec2(0.13, 0.79)).r;
		float coarse_damage = 0.65 + 0.35 * patch_wear;
		float coarse_retained = coverage_at_damage(coarse_light, coarse_heavy, coarse_damage);
		retained_paint *= mix(1.0, coarse_retained, wheel_flow);
	}
	float paint = coverage * 0.94 * retained_paint;

	ALBEDO = mix(stone, paint_colour.rgb, paint);
	ROUGHNESS = mix(orm.g, 0.82, paint);
	AO = mix(orm.r, 1.0, paint);
}


