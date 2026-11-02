shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded, shadows_disabled, fog_disabled;
// Polished terrazzo, laid over the floor as one quad. The view is bounced off the floor and traced
// up to the ceiling in the building's own metres, so the batten streaks slide as you walk, and any
// machine in the ray's way stays dark: that is how a machine comes to stand on its own reflection.
uniform float ceiling = 2.93;
uniform float machine_top = 2.32;
uniform vec2 lamp_first = vec2(0.0); // Nearest batten, x and z.
uniform vec2 lamp_step = vec2(1.0);
uniform vec2 lamp_half = vec2(0.59, 0.07);
uniform vec4 feet[5]; // Machine footprints: x0, z0, x1, z1.
uniform float lamp_level = 11.0;
uniform float board_level = 0.5;
varying vec3 here;
varying vec3 eye;
float hsh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float nz(vec2 p){ vec2 c = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hsh(c), hsh(c+vec2(1,0)), u.x), mix(hsh(c+vec2(0,1)), hsh(c+vec2(1,1)), u.x), u.y); }
void vertex(){
	here = VERTEX;
	eye = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}
void fragment(){
	vec3 ray = normalize(here - eye);
	float facing = clamp(-ray.y, 0.0, 1.0);
	ray.y = max(-ray.y, 0.02);
	float reach = (ceiling - here.y) / ray.y;
	// Worn lanes and old wax make the polish wander a little.
	vec2 worn = vec2(nz(here.xz * 2.3), nz(here.zx * 2.9 + 4.0)) - 0.5;
	vec2 hit = here.xz + ray.xz * reach + worn * 0.014 * reach;
	vec2 cell = hit - lamp_first;
	cell = abs(cell - lamp_step * clamp(round(cell / lamp_step), vec2(0.0), vec2(2.0, 1.0)));
	float blur = 0.03 + 0.03 * reach;
	vec2 edge = 1.0 - smoothstep(lamp_half - blur, lamp_half + blur, cell);
	float lamp = edge.x * edge.y;
	// Does the ray meet a machine on its way up?
	float open = 1.0;
	vec2 run = hit - here.xz;
	for (int i = 0; i < 5; i++) {
		vec2 low = (feet[i].xy - here.xz) / run;
		vec2 high = (feet[i].zw - here.xz) / run;
		vec2 near = min(low, high);
		vec2 far = max(low, high);
		float enter = max(max(near.x, near.y), 0.0);
		float leave = min(min(far.x, far.y), 1.0);
		float over = smoothstep(machine_top - 0.1, machine_top + 0.1, here.y + (ceiling - here.y) * enter);
		open = min(open, mix(1.0 - smoothstep(0.0, 0.05, leave - enter), 1.0, over));
	}
	float fresnel = 0.05 + 0.95 * pow(1.0 - facing, 5.0);
	float wear = mix(0.8, 1.05, nz(here.xz * 1.4 + 9.0));
	ALBEDO = vec3(0.97, 0.97, 1.0) * (lamp * lamp_level + board_level) * fresnel * open * wear;
}
