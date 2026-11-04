shader_type spatial;
render_mode diffuse_burley, cull_disabled;
// Japanese traffic and pedestrian signal lenses, timed entirely on the GPU.
// COLOR.r = role / 8: 0 green ("blue"), 1 amber, 2 red, 3 walk-red, 4 walk-green.
// COLOR.g = flow: 0 the main road, 1 the side road.
// COLOR.b = this junction's offset in the shared 60 s cycle.
uniform float night = 0.0;
varying vec3 tint;
varying float lit;

const float CYCLE = 60.0;

// Main road: green 0-27, amber 27-30, all red 30-32. Side road: green 32-55,
// amber 55-58, all red 58-60. Pedestrians walk beside the green of their flow.
float state(int role, int flow, float t) {
	float start = flow == 0 ? 0.0 : 32.0;
	float green_end = start + (flow == 0 ? 27.0 : 23.0);
	float amber_end = green_end + 3.0;
	bool green = t >= start && t < green_end;
	bool amber = t >= green_end && t < amber_end;
	if (role == 0) return green ? 1.0 : 0.0;
	if (role == 1) return amber ? 1.0 : 0.0;
	if (role == 2) return (!green && !amber) ? 1.0 : 0.0;
	// Pedestrians cross beside the flow that runs parallel to them.
	bool walk = t >= start + 1.0 && t < green_end - 1.0;
	bool flash = t >= green_end - 6.0 && t < green_end - 1.0;
	if (role == 4) return walk ? (flash ? step(0.5, fract(t * 2.0)) : 1.0) : 0.0;
	return walk ? 0.0 : 1.0;
}

void vertex() {
	int role = int(round(COLOR.r * 8.0));
	int flow = int(round(COLOR.g));
	float t = mod(TIME + COLOR.b * CYCLE, CYCLE);
	lit = state(role, flow, t);
	tint = role == 0 ? vec3(0.0, 0.85, 0.62) : (role == 1 ? vec3(1.0, 0.62, 0.0) : (role == 2 || role == 3 ? vec3(1.0, 0.07, 0.04) : vec3(0.05, 0.85, 0.75)));
}

void fragment() {
	// An unlit LED lens still shows its colour faintly through the diffuser.
	ALBEDO = mix(tint * 0.06 + vec3(0.02), tint * 0.2, lit);
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
	EMISSION = tint * lit * mix(3.2, 5.5, night);
}
