shader_type spatial;
render_mode diffuse_burley, cull_disabled;
// Small road parts that sit on the carriageway: painted text (part 0) and
// cast-iron manhole lids (part 1). Both read world position for their wear, so
// no two copies look stamped.
uniform int part = 0;
uniform vec3 paint_color : source_color = vec3(0.86, 0.855, 0.82);
uniform sampler2D lid_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D lid_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D lid_orm : filter_linear_mipmap_anisotropic;
uniform float night = 0.0;
varying vec3 world;

float hsh(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float nz(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hsh(i), hsh(i + vec2(1, 0)), f.x), mix(hsh(i + vec2(0, 1)), hsh(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	if (part == 0) {
		// Thermoplastic letters, chipped where tyres cross them.
		float wear = nz(p * 3.0) * 0.6 + nz(p * 14.0) * 0.4;
		if (wear > 0.78) discard;
		ALBEDO = paint_color * mix(0.78, 1.0, nz(p * 0.7)) * mix(0.9, 1.0, hsh(floor(p * 60.0)));
		ROUGHNESS = 0.58;
		SPECULAR = 0.45;
		EMISSION = ALBEDO * 0.1 * night;
	} else {
		// UV spans the lid's square texture; the frame ring sits just outside it.
		vec2 c = UV - 0.5;
		float r = length(c);
		if (r > 0.5) discard;
		vec2 lid_uv = c / 0.46 * 0.5 + 0.5;
		float frame = smoothstep(0.455, 0.465, r);
		vec3 lid = texture(lid_albedo, lid_uv).rgb * 1.35;
		vec3 orm = texture(lid_orm, lid_uv).rgb;
		// Polished where wheels roll over it, rusty grit around the edge.
		lid *= mix(1.0, 1.35, smoothstep(0.2, 0.0, abs(c.y)) * 0.6 * nz(p * 9.0));
		vec3 rim = vec3(0.07, 0.068, 0.065) * mix(0.8, 1.2, nz(p * 30.0));
		ALBEDO = mix(lid, rim, frame);
		METALLIC = mix(0.55, 0.3, frame);
		ROUGHNESS = mix(clamp(orm.g, 0.35, 0.8), 0.85, frame);
		NORMAL_MAP = mix(texture(lid_normal, lid_uv).xyz, vec3(0.5, 0.5, 1.0), frame);
		NORMAL_MAP_DEPTH = 0.6;
		AO = mix(orm.r, 1.0, frame);
		EMISSION = ALBEDO * 0.08 * night;
	}
}
