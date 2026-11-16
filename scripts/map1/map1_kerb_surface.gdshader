shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Staged material contract, pending agreement with the native Street owner:
// marked concrete alpha=.20+2.0*local road-relative height in metres;
// all other faces alpha=1. Alpha is data; opacity is never written.
// Existing physical joints, casting RGB, normals and geometry are retained.
uniform sampler2D cast_detail : source_color, repeat_enable, filter_linear_mipmap_anisotropic, hint_default_white;
uniform float detail_tile_metres = 1.0;
uniform float detail_linear_mean = 0.118523;
uniform float detail_strength : hint_range(0.0, 0.4) = 0.22;
uniform float contact_height_metres = 0.04;
uniform float contact_strength : hint_range(0.0, 0.6) = 0.25;
uniform vec3 contact_tint = vec3(0.40, 0.43, 0.36);

varying vec3 kerb_world_position;
varying vec3 kerb_world_normal;

void vertex() {
	kerb_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	kerb_world_normal = MODEL_NORMAL_MATRIX * NORMAL;
	// Same RGB conversion as the native StandardMaterial3D; alpha stays data.
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = mix(
			pow((COLOR.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)),
			COLOR.rgb * (1.0 / 12.92),
			lessThan(COLOR.rgb, vec3(0.04045)));
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	AO = 1.0;

	vec3 normal_world = normalize(kerb_world_normal);
	vec3 tangent_world = vec3(normal_world.z, 0.0, -normal_world.x);
	tangent_world = length(tangent_world) > 0.00001 ? normalize(tangent_world) : vec3(1.0, 0.0, 0.0);
	vec2 projection = abs(normal_world.y) > 0.5 ? kerb_world_position.xz :
		vec2(dot(kerb_world_position, tangent_world), kerb_world_position.y);
	vec2 detail_uv = projection / max(0.01, detail_tile_metres);
	vec2 detail_dx = dFdx(detail_uv);
	vec2 detail_dy = dFdy(detail_uv);
	if (COLOR.a < 0.9) {
		float sample_luma = dot(textureGrad(cast_detail, detail_uv, detail_dx, detail_dy).rgb,
			vec3(0.2126, 0.7152, 0.0722));
		// Whole-image measured means of the existing 1024x1024 asset.
		float source_mean = OUTPUT_IS_SRGB ? 0.37848594 : detail_linear_mean;
		float casting_detail = clamp(1.0 + detail_strength *
			(sample_luma / max(0.001, source_mean) - 1.0), 0.88, 1.08);
		float road_relative_height = (COLOR.a - 0.20) * 0.5;
		float contact = 1.0 - smoothstep(0.0, max(0.001, contact_height_metres),
			max(0.0, road_relative_height));
		vec3 contact_colour = mix(vec3(1.0), contact_tint, contact_strength * contact);
		ALBEDO = COLOR.rgb * casting_detail * contact_colour;
	}
}
