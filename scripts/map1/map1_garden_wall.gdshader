shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// One shared material for HouseKit's opaque wall and nameplate faces.
// Other ShellMesh consumers retain ShellMesh.material(). No UV/custom data.
// Contract: wall_surface_contract.md. Encoded alpha=.2+.3*box_height;
// unmarked opaque alpha=1; current marked range=.20..74, never >=.9.
// Alpha is vertex data only. This shader never writes the opacity output.

// Optional existing asset, not a new texture:
// res://assets/procedural_textures/concrete_detail.png
// Its current import has no mipmaps. Enable only when that exact map is bound;
// the fine modulation fades before unresolved texels can shimmer at distance.
uniform sampler2D concrete_detail : source_color, repeat_enable, filter_linear, hint_default_white;
uniform bool use_concrete_detail = false;
uniform float concrete_detail_tile_metres = 1.20;
uniform float concrete_detail_strength : hint_range(0.0, 0.30) = 0.16;
uniform float base_dirt_strength : hint_range(0.0, 1.0) = 0.65;
uniform float base_dirt_height_metres : hint_range(0.1, 0.8) = 0.55;
uniform float mortar_darkening : hint_range(0.0, 0.50) = 0.38;
uniform float cast_batch_strength : hint_range(0.0, 0.08) = 0.035;


// Nameplate extension. Atlas face alpha=.8; RGB carries normalized
// atlas endpoints and a palette byte. Other vertex colours keep the native path.
uniform sampler2D nameplate_coverage : filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 stone_0;
uniform vec3 stone_1;
uniform vec3 stone_2;
uniform vec3 ink_0;
uniform vec3 ink_1;
uniform vec3 ink_2;

vec3 atlas_srgb_color(vec3 encoded) {
    if (OUTPUT_IS_SRGB) { return encoded; }
    return mix(pow((encoded + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)),
        encoded * (1.0 / 12.92), lessThan(encoded, vec3(0.04045)));
}

varying vec3 wall_world_position;
varying vec3 wall_world_normal;

// Integral of a repeating joint centred on each modular boundary. Integrating
// over the pixel footprint preserves average mortar coverage at distance.
float joint_integral(float position_metres, float module_metres, float width_metres) {
	float shifted = position_metres + width_metres * 0.5;
	return floor(shifted / module_metres) * width_metres +
		min(mod(shifted, module_metres), width_metres);
}

float joint_coverage(float position_metres, float module_metres, float width_metres, float pixel_metres) {
	float pixel = max(0.00001, pixel_metres);
	return clamp((joint_integral(position_metres + pixel * 0.5, module_metres, width_metres) -
		joint_integral(position_metres - pixel * 0.5, module_metres, width_metres)) / pixel, 0.0, 1.0);
}

void vertex() {
	wall_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wall_world_normal = MODEL_NORMAL_MATRIX * NORMAL;
	// Match StandardMaterial3D.vertex_color_is_srgb, converting RGB only.
	// Match the expression in Godot 4.7.2's generated material verbatim.
	if (!OUTPUT_IS_SRGB && abs(COLOR.a - 0.8) >= 0.01) {
		COLOR.rgb = mix(
			pow((COLOR.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)),
			COLOR.rgb * (1.0 / 12.92),
			lessThan(COLOR.rgb, vec3(0.04045)));
	}
}

void fragment() {
	// Exact intended unmarked material path. Native same-pixel verification
	// against StandardMaterial3D is required before this candidate is accepted.
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.88;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	AO = 1.0;

	vec3 world_normal = normalize(wall_world_normal);
	vec3 horizontal_tangent = cross(vec3(0.0, 1.0, 0.0), world_normal);
	float tangent_length = length(horizontal_tangent);
	// Horizontal caps/undersides must never normalize a zero cross product.
	if (tangent_length > 0.0001) {
		horizontal_tangent /= tangent_length;
	} else {
		horizontal_tangent = vec3(1.0, 0.0, 0.0);
	}
	float along_wall = dot(wall_world_position, horizontal_tangent);
	// Derivatives are evaluated outside the marked-face branch. Courses use
	// world coordinates, not byte-packed height or the view-space NORMAL.
	float pixel_u = max(0.00001, fwidth(along_wall));
	float pixel_y = max(0.00001, fwidth(wall_world_position.y));
	float footprint = max(pixel_u, pixel_y);
	vec2 detail_uv = vec2(along_wall, wall_world_position.y) /
		max(0.01, concrete_detail_tile_metres);
	vec2 detail_dx = dFdx(detail_uv);
	vec2 detail_dy = dFdy(detail_uv);
	vec2 nameplate_dx = dFdx(COLOR.rg);
	vec2 nameplate_dy = dFdy(COLOR.rg);
	bool nameplate_face = abs(COLOR.a - 0.8) < 0.01;
	bool marked_wall = COLOR.a < 0.9 && !nameplate_face;
	bool vertical_face = abs(world_normal.y) < 0.20;
	if (nameplate_face) {
        // No rounding of interpolated coordinates: the byte endpoints were
        // decoded before perspective interpolation. Coverage is linear R8.
        float palette = COLOR.b * 255.0;
        vec3 stone = palette < 0.5 ? stone_0 : (palette < 1.5 ? stone_1 : stone_2);
        vec3 ink = palette < 0.5 ? ink_0 : (palette < 1.5 ? ink_1 : ink_2);
        float coverage = textureGrad(nameplate_coverage, COLOR.rg, nameplate_dx, nameplate_dy).r;
        ALBEDO = mix(atlas_srgb_color(stone), atlas_srgb_color(ink), coverage);
    } else if (marked_wall && vertical_face) {
		// A nominal400x200mm block module with10mm mortar joints. Running
		// bond shifts alternate courses by200mm. These lines depict actual
		// concrete-block joints and are restricted to the marked wall faces.
		float row = floor(wall_world_position.y / 0.20);
		float bond_offset = mod(row, 2.0) * 0.20;
		float bed_joint = joint_coverage(wall_world_position.y, 0.20, 0.010, pixel_y);
		float head_joint = joint_coverage(along_wall + bond_offset, 0.40, 0.010, pixel_u);
		// A pixel spanning several rows sees both bond offsets. Use their
		// mean instead of allowing the alternating offset to alias.
		head_joint = mix(head_joint, 0.010 / 0.40, smoothstep(0.05, 0.20, pixel_y));
		float mortar = bed_joint + head_joint * (1.0 - bed_joint);

		vec3 wall_albedo = COLOR.rgb;
		// A quiet casting-lot tone shared by six blocks across two courses.
		// This assigns one of five tones per coherent lot, not per-pixel noise.
		float block_column = floor((along_wall + bond_offset) / 0.40);
		ivec2 cast_lot = ivec2(floor(vec2(block_column / 6.0, row / 2.0)));
		uint lot_key = uint(cast_lot.x) * 1597334677u ^ uint(cast_lot.y) * 3812015801u;
		lot_key = (lot_key ^ (lot_key >> 16u)) * 2246822519u;
		lot_key = lot_key ^ (lot_key >> 13u);
		float lot_tone = float(lot_key % 5u) * 0.5 - 1.0;
		wall_albedo *= 1.0 + cast_batch_strength * lot_tone;
		if (use_concrete_detail) {
			float detail_luma = dot(textureGrad(concrete_detail, detail_uv, detail_dx, detail_dy).rgb,
				vec3(0.2126, 0.7152, 0.0722));
			// Mean linear grey=.69468 from4096 sampled texels of that asset.
			// The compatibility path retains encoded source colour instead.
			float detail_mean = OUTPUT_IS_SRGB ? 0.850 : 0.69468;
			float texel_metres = max(0.01, concrete_detail_tile_metres) / 512.0;
			float resolved_detail = 1.0 - smoothstep(texel_metres * 0.5,
				texel_metres * 2.0, footprint);
			float grain_scale = clamp(1.0 + concrete_detail_strength *
				(detail_luma / detail_mean - 1.0), 0.90, 1.04);
			wall_albedo *= mix(1.0, grain_scale, resolved_detail);
		}

		// Decode height above this specific box's bottom, then remove its
		//100mm ground embed. A broad capillary/contact-dirt falloff follows
		// each wall foot on sloped plots. No world-Y dirt band or random noise.
		float visible_height = max(0.0, (COLOR.a - 0.20) / 0.30 - 0.10);
		float base_contact = 1.0 - smoothstep(0.025, base_dirt_height_metres, visible_height);
		vec3 contact_tint = mix(vec3(1.0), vec3(0.30, 0.35, 0.27),
			clamp(base_dirt_strength, 0.0, 1.0) * base_contact);
		wall_albedo *= contact_tint;
		ALBEDO = wall_albedo * (1.0 - mortar_darkening * mortar);
		ROUGHNESS = mix(0.92, 0.96, mortar);
		AO = mix(1.0, 0.90, mortar);
	}
}
