shader_type spatial;
// Wall finish for the near-city shells. COLOR.rgb is the building's tint, COLOR.a its
// material layer (eighths), or 1.0 for bare aluminium. UV.x carries sill streaking.
uniform float night = 0.0;
uniform sampler2DArray wall_maps : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray wall_normals : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
const float SCALE[9] = {2.4, 3.0, 2.6, 3.2, 2.2, 2.0, 1.1, 3.4, 1.0};
varying vec3 world;
varying vec3 world_normal;
float hsh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float nz(vec2 p){ vec2 c = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hsh(c), hsh(c+vec2(1,0)), u.x), mix(hsh(c+vec2(0,1)), hsh(c+vec2(1,1)), u.x), u.y); }
void vertex(){
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}
void fragment(){
	vec3 an = abs(world_normal);
	bool flat_face = an.y > 0.7;
	vec2 metres = flat_face ? world.xz : (an.x > an.z ? world.zy : world.xy);
	vec3 color;
	float rough = 0.88;
	float depth = 1.0;
	if (COLOR.a > 0.98) {
		color = COLOR.rgb;
		rough = 0.42;
		depth = 0.0;
	} else {
		float layer = floor(COLOR.a * 8.0 + 0.5);
		// Glazed tile and polished stone catch the sky; render and concrete do not.
		if (layer == 6.0 || layer == 8.0 || layer == 0.0) rough = 0.5;
		else if (layer == 1.0) rough = 0.34;
		vec2 uv = metres / SCALE[int(layer)];
		color = texture(wall_maps, vec3(uv, layer)).rgb;
		vec3 mean = textureLod(wall_maps, vec3(uv, layer), 9.0).rgb;
		color = (mean + (color - mean) * 1.05) / max(dot(mean, vec3(0.3, 0.6, 0.1)), 0.02) * 0.62;
		color = mix(vec3(dot(color, vec3(0.3, 0.6, 0.1))), color, 0.3) * COLOR.rgb;
		// Weather: rain streaks falling from every ledge, darker near the street.
		float streak = nz(vec2(metres.x * 2.3, metres.y * 0.12));
		float patchy = nz(metres * vec2(0.22, 0.07));
		float macro = nz(metres * vec2(0.9, 0.35));
		color *= mix(0.68, 1.08, patchy) * mix(0.9, 1.06, macro) * (1.0 - 0.5 * UV.x * streak) * (1.0 - 0.2 * pow(streak, 3.0));
		color *= 0.9 + 0.2 * hsh(floor(metres / vec2(1.8, 2.6)));
		// Panel joints where the wall is cast or rendered in sections.
		if (layer == 3.0 || layer == 7.0) {
			vec2 joint = abs(fract(metres / vec2(2.4, 3.2)) - 0.5);
			float thin = fwidth(metres.x) / 2.4 + fwidth(metres.y) / 3.2;
			color *= 1.0 - 0.4 * step(0.492 - thin, max(joint.x, joint.y)) * step(thin, 0.04);
		}
		color *= mix(0.62, 1.0, smoothstep(0.0, 2.8, world.y));
		color *= mix(0.72, 1.0, smoothstep(0.0, 20.0, world.y));
		NORMAL_MAP = texture(wall_normals, vec3(uv, layer)).xyz;
		NORMAL_MAP_DEPTH = 1.2;
	}
	vec3 fill = mix(vec3(0.15, 0.11, 0.09), vec3(0.03, 0.035, 0.052), smoothstep(0.0, 20.0, world.y));
	vec3 hue = mix(vec3(1.0, 0.22, 0.5), vec3(0.2, 0.62, 1.0), nz(metres * 0.06));
	EMISSION = color * (fill + hue * exp(-world.y * 0.16) * 0.3) * night + color * vec3(0.09, 0.07, 0.04) * (1.0 - night);
	ALBEDO = color * mix(vec3(1.0), vec3(0.42, 0.34, 0.27), night);
	ROUGHNESS = rough;
	SPECULAR = 0.45;
	float haze = 1.0 - exp(-length(world - CAMERA_POSITION_WORLD) * mix(0.00105, 0.00075, night));
	FOG = vec4(mix(vec3(0.66, 0.69, 0.74), vec3(0.035, 0.03, 0.055), night), haze);
}
