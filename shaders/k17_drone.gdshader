shader_type spatial;

// K17 drone hull. The supplied mesh has no UVs or textures, so panel seams are
// projected in model space and a state-coloured rim keeps the silhouette
// readable when the drone is backlit.

uniform vec4 base_color : source_color = vec4(0.36, 0.38, 0.4, 1.0);
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.3;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.48;
uniform float panel_scale = 3.2;
uniform vec4 rim_color : source_color = vec4(0.3, 0.85, 1.0, 1.0);
uniform float rim_strength = 0.55;
uniform float rim_power = 3.2;
uniform vec4 flash_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float flash = 0.0;

varying vec3 object_position;
varying vec3 object_normal;

void vertex() {
	object_position = VERTEX;
	object_normal = NORMAL;
}

float seam_lines(vec3 p, vec3 n) {
	vec3 weight = abs(normalize(n));
	weight /= max(weight.x + weight.y + weight.z, 0.0001);
	vec3 cell = abs(fract(p * panel_scale) - 0.5);
	float on_x = smoothstep(0.465, 0.492, max(cell.y, cell.z));
	float on_y = smoothstep(0.465, 0.492, max(cell.x, cell.z));
	float on_z = smoothstep(0.465, 0.492, max(cell.x, cell.y));
	return on_x * weight.x + on_y * weight.y + on_z * weight.z;
}

void fragment() {
	float seam = seam_lines(object_position, object_normal);
	ALBEDO = base_color.rgb * (1.0 - seam * 0.5);
	METALLIC = metallic_amount;
	ROUGHNESS = clamp(roughness_amount + seam * 0.3, 0.0, 1.0);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color.rgb * fresnel * rim_strength + flash_color.rgb * flash;
}
