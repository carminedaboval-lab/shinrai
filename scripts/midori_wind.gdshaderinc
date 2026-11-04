// Shared Midori breeze. Everything that sways reads the same field, so a gust
// visibly travels down a street instead of each object twitching on its own.
// wind_strength: 1 by day, about 0.45 at night.
uniform float wind_strength = 1.0;

const vec2 WIND_DIR = vec2(0.94, 0.34);

// Offset in metres for a fully flexible point; scale by how free it is to move.
vec3 midori_wind(vec3 p, float t) {
	float travel = dot(p.xz, WIND_DIR);
	// Slow gusts roll through at about 4 m/s; flutter rides on top of them.
	float gust = 0.55 + 0.45 * sin(t * 0.45 - travel * 0.11) * sin(t * 0.17 - travel * 0.031 + 1.3);
	float flutter = sin(t * 3.3 + p.y * 2.1 + travel * 0.9) * 0.6 + sin(t * 5.7 + p.x * 1.9 - p.z * 1.3) * 0.4;
	vec3 push = vec3(WIND_DIR.x, 0.0, WIND_DIR.y) * (gust * 0.75 + flutter * 0.18 * gust);
	vec3 side = vec3(-WIND_DIR.y, 0.0, WIND_DIR.x) * flutter * 0.22 * gust;
	return (push + side + vec3(0.0, flutter * 0.06 * gust, 0.0)) * wind_strength;
}
