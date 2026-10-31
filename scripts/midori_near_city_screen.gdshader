shader_type spatial;
// Rooftop micro-LED wall: seamless, with no lamp or module visible from the street. Stills
// come from a sheet and are kept alive here: a slow drift, a light sweep, a running ticker.
uniform float night = 0.0;
uniform sampler2D frames : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float still_a = 0.0;
uniform float still_b = 0.0;
uniform float wipe = 0.0;
const vec2 SHEET = vec2(2.0, 5.0); // Stills across and down, in the upper part of the sheet.
const vec2 CELL = vec2(1024.0, 341.0);
const vec2 STILL = vec2(1008.0, 336.0);
const float SHEET_SIZE = 2048.0;
const vec4 TICKER = vec4(0.0, 1720.0, 2048.0, 72.0); // Strip that runs along the foot of the wall.
const float TICKER_HEIGHT = 0.13;
varying vec3 world;
void vertex(){
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
vec3 still(float index, vec2 uv){
	vec2 cell = vec2(mod(index, SHEET.x), floor(index / SHEET.x));
	vec2 at = cell * CELL + (CELL - STILL) * 0.5 + uv * STILL;
	return texture(frames, at / SHEET_SIZE).rgb;
}
void fragment(){
	// The picture breathes: never quite still, never enough to notice the move.
	vec2 drift = vec2(sin(TIME * 0.11), cos(TIME * 0.07)) * 0.012;
	vec2 uv = 0.5 + (UV - 0.5) * 0.955 + drift;
	float edge = UV.x * 0.8 + UV.y * 0.2;
	float gate = smoothstep(edge - 0.05, edge + 0.05, wipe * 1.15 - 0.075);
	vec3 color = mix(still(still_a, uv), still(still_b, uv), gate);
	float front = exp(-pow((edge - wipe * 1.15 + 0.075) * 26.0, 2.0)) * step(0.001, wipe) * step(wipe, 0.999);
	color += vec3(0.35, 0.8, 1.0) * front;
	float sweep = exp(-pow((edge - fract(TIME * 0.07) * 1.6 + 0.3) * 7.0, 2.0));
	color *= 1.0 + 0.16 * sweep;
	if (UV.y > 1.0 - TICKER_HEIGHT) {
		float v = (UV.y - (1.0 - TICKER_HEIGHT)) / TICKER_HEIGHT;
		float u = fract(TIME * 0.035 + UV.x * 0.34);
		color = texture(frames, vec2(TICKER.x + u * TICKER.z, TICKER.y + v * TICKER.w) / SHEET_SIZE).rgb;
	}
	ALBEDO = vec3(0.01);
	ROUGHNESS = 0.2;
	SPECULAR = 0.35;
	EMISSION = color * mix(1.2, 0.62, night);
	float haze = 1.0 - exp(-length(world - CAMERA_POSITION_WORLD) * mix(0.00105, 0.00035, night));
	FOG = vec4(mix(vec3(0.66, 0.69, 0.74), vec3(0.035, 0.03, 0.055), night), haze);
}
