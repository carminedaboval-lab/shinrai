shader_type canvas_item;
// Bodycam lens: remaps the rectilinear 3D render into an equidistant (f-theta)
// fisheye, the projection real duty cameras' published angles fit (Motorola
// V700 130/73/149 deg). Lateral chromatic aberration grows with radius and the
// image falls off toward the edge like a short wide lens. Runs on a canvas
// layer below the HUD, so only the 3D image is warped.
// See reports/Bodycam camera mode research.md.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float half_fov_h = 1.0472;      // target half horizontal angle (rad): 60 deg = 120 deg lens
uniform float tan_src_h = 2.25;         // tan of the source camera's half horizontal FOV
uniform float aspect = 1.7778;
uniform float strength = 1.0;           // 0 = plain rectilinear, 1 = full fisheye
uniform float aberration = 0.006;       // lateral CA at the horizontal edge (fraction of angle)
uniform float vignette = 0.45;          // 0..1 mix of cos^4 falloff
uniform float corner_dark = 0.35;       // extra darkening of the lens housing in the corners
uniform float sharpen = 0.45;           // in-camera edge sharpening; also offsets the fisheye's centre magnification

vec2 source_uv(vec2 p, float scale) {
	// p: output position, x in [-1, 1] across the width, y scaled by 1/aspect.
	float r = length(p);
	if (r < 1e-5) return vec2(0.5);
	float theta = r * half_fov_h * scale;
	float k = tan(min(theta, 1.55)) / (tan_src_h * r);
	// Rectilinear view of the same output (strength 0) is a uniform scale.
	float k_lin = tan(half_fov_h) / tan_src_h;
	k = mix(k_lin, k, strength);
	vec2 ndc = p * k;
	return vec2(0.5 + 0.5 * ndc.x, 0.5 + 0.5 * ndc.y * aspect);
}

void fragment() {
	vec2 p = vec2(SCREEN_UV.x * 2.0 - 1.0, (SCREEN_UV.y * 2.0 - 1.0) / aspect);
	float r = length(p);
	float ca = aberration * r * r * strength;
	vec2 uv_g = source_uv(p, 1.0);
	vec3 col;
	col.r = textureLod(screen_tex, source_uv(p, 1.0 + ca), 0.0).r;
	col.g = textureLod(screen_tex, uv_g, 0.0).g;
	col.b = textureLod(screen_tex, source_uv(p, 1.0 - ca), 0.0).b;
	// Unsharp mask on the source image: the difference from a 4-tap neighbourhood,
	// taken in output pixels so the halo width matches what a recorder bakes in.
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 around = textureLod(screen_tex, uv_g + vec2(px.x, 0.0), 0.0).rgb
		+ textureLod(screen_tex, uv_g - vec2(px.x, 0.0), 0.0).rgb
		+ textureLod(screen_tex, uv_g + vec2(0.0, px.y), 0.0).rgb
		+ textureLod(screen_tex, uv_g - vec2(0.0, px.y), 0.0).rgb;
	vec3 centre = textureLod(screen_tex, uv_g, 0.0).rgb;
	col = max(col + (centre - around * 0.25) * sharpen * strength, vec3(0.0));
	float theta = r * half_fov_h;
	float c = cos(min(theta, 1.5));
	float fall = mix(1.0, c * c * c * c, vignette * strength);
	float corner = smoothstep(0.92, 1.18, r);
	fall *= 1.0 - corner_dark * corner * strength;
	// Outside the source frame (only when strength pushes past the overscan).
	float inside = step(0.0, uv_g.x) * step(uv_g.x, 1.0) * step(0.0, uv_g.y) * step(uv_g.y, 1.0);
	COLOR = vec4(col * fall * inside, 1.0);
}
