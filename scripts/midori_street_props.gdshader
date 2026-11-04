shader_type spatial;
render_mode diffuse_burley, cull_disabled;
// Merged street clutter. COLOR.rgb is the sRGB base colour; UV2.x is how far a
// vertex is free to move in the wind (metres at full gust); UV2.y is how bright
// it glows (vending fronts, lamps), with UV2.y > 1 marking a night-only light.
#include "res://scripts/midori_wind.gdshaderinc"
uniform float night = 0.0;
varying vec3 tint;
varying vec3 world;
varying float glow;

float hsh(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float nz(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hsh(i), hsh(i + vec3(1, 0, 0)), f.x), mix(hsh(i + vec3(0, 1, 0)), hsh(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hsh(i + vec3(0, 0, 1)), hsh(i + vec3(1, 0, 1)), f.x), mix(hsh(i + vec3(0, 1, 1)), hsh(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (UV2.x > 0.0) {
		VERTEX += (inverse(MODEL_MATRIX) * vec4(midori_wind(w, TIME) * UV2.x, 0.0)).xyz;
	}
	world = w;
	tint = pow(COLOR.rgb, vec3(2.2));
	glow = UV2.y;
}

void fragment() {
	float grain = nz(world * 31.0);
	float blotch = nz(world * 2.3) * 0.6 + nz(world * 7.0) * 0.4;
	// Damp and dirt climb the bottom 40 cm of everything that stands outside.
	float grime = smoothstep(0.45, 0.0, world.y + (blotch - 0.5) * 0.3) * 0.45;
	vec3 color = tint * (0.82 + 0.3 * blotch) * (0.94 + 0.1 * grain);
	color = mix(color, color * vec3(0.55, 0.52, 0.46), grime);
	ALBEDO = color;
	// Night lamps are frosted glass and milky acrylic, not mirrors.
	ROUGHNESS = glow > 1.0 ? 0.38 : 0.82 - glow * 0.3;
	SPECULAR = 0.3;
	float day_glow = glow > 1.0 ? 0.0 : glow * 0.55;
	float night_glow = glow > 1.0 ? (glow - 1.0) * 4.0 : glow * 2.6;
	EMISSION = tint * mix(day_glow, night_glow, night);
}
