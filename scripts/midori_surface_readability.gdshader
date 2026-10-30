shader_type spatial;
render_mode cull_disabled;

// Maintained aggregate and sourced fracture detail share one road surface.
// No line meshes or generated crack paths are used.
uniform sampler2D aggregate_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D aggregate_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D aggregate_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D worn_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D worn_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D worn_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float aggregate_gain = 4.2;
uniform vec3 worn_gain = vec3(0.410004,0.348344,0.229495);
uniform float paint_surface = 0.0;
uniform float wetness = 0.0;
varying vec3 world_position;

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.x, p.y, p.x) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float edge_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1.0,0.0)),f.x),
		mix(hash21(i+vec2(0.0,1.0)),hash21(i+vec2(1.0,1.0)),f.x),f.y);
}

float repair_distance(vec2 p, vec2 center, vec2 half_size) {
	vec2 d = abs(p-center)-half_size;
	// Centimetres of broken aggregate along a cut edge, never a drawn crack.
	return max(d.x,d.y)+(edge_noise(p*39.0)-0.5)*0.036+(edge_noise(p*8.0)-0.5)*0.028;
}

float photo_footprint(vec2 uv) {
	vec2 a = smoothstep(vec2(0.03),vec2(0.23),uv);
	vec2 b = 1.0-smoothstep(vec2(0.77),vec2(0.98),uv);
	return a.x*a.y*b.x*b.y;
}

float photo_luma(vec2 uv) {
	return dot(texture(worn_albedo,uv).rgb*worn_gain,vec3(0.2126,0.7152,0.0722));
}

void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz-vec2(0.0,184.0);
	vec2 grain_uv = vec2(p.x*0.966-p.y*0.259,p.x*0.259+p.y*0.966)/2.0;
	vec3 dry = texture(aggregate_albedo,grain_uv).rgb*aggregate_gain;
	vec3 n_dry = texture(aggregate_normal,grain_uv).xyz*2.0-1.0;
	float rough = texture(aggregate_orm,grain_uv).g;
	// Local source textures occur once beside the crossing, not as repeating strips.
	vec2 uv_a = (p-vec2(3.8,0.22))/vec2(2.6,2.4);
	vec2 uv_b = vec2(p.y-2.4,-p.x-5.4)/vec2(2.2,2.5);
	float mask_a = photo_footprint(uv_a);
	float mask_b = photo_footprint(uv_b)*0.60;
	vec2 photo_uv = mask_a>=mask_b ? uv_a : uv_b;
	float damage = max(mask_a,mask_b);
	// Preserve the photographed fracture itself, not the photograph's blue
	// background or differently sized aggregate. Neighbour samples separate
	// its dark fissures from the local exposed-stone mean without inventing paths.
	float neighbourhood = (photo_luma(photo_uv+vec2(.022,0.0))
		+photo_luma(photo_uv-vec2(.022,0.0))
		+photo_luma(photo_uv+vec2(0.0,.022))
		+photo_luma(photo_uv-vec2(0.0,.022))
		+photo_luma(photo_uv+vec2(.016,.016))
		+photo_luma(photo_uv-vec2(.016,.016)))*0.1666667;
	float fracture = (1.0-smoothstep(.55,.88,photo_luma(photo_uv)/max(neighbourhood,.0001)))*damage;
	vec3 n_photo = texture(worn_normal,photo_uv).xyz*2.0-1.0;
	if (mask_b>mask_a) n_photo.xy=vec2(-n_photo.y,n_photo.x);
	float r_photo = texture(worn_roughness,photo_uv).r;
	vec3 road = dry*(1.0-fracture*.32);
	vec3 n = n_dry;
	n.xy += n_photo.xy*fracture*.45;
	rough = mix(rough,r_photo,fracture*.35);
	// Three coherent maintenance areas. Their edge is part of the same opaque
	// asphalt, so patches cannot float, overlap or carry a raised black outline.
	// Small maintenance cuts sit against existing iron drain frames.
	float crossing = repair_distance(p,vec2(-12.0,-.66),vec2(.64,.22));
	float service = repair_distance(p,vec2(12.0,5.66),vec2(.64,.22));
	float older = repair_distance(p,vec2(25.0,-.66),vec2(.62,.22));
	// Rear lane: resurfacing directly meets the existing dropped crossing ramp.
	float rear = repair_distance(p,vec2(0.0,36.78),vec2(1.58,.24));
	float cut_distance = min(rear,min(crossing,min(service,older)));
	float repair = 1.0-smoothstep(-0.035,0.075,cut_distance);
	// The same physical two-metre source repeat is retained across the cut.
	vec2 patch_uv = grain_uv+vec2(4.2,1.7);
	vec3 patch = texture(aggregate_albedo,patch_uv).rgb*aggregate_gain;
	patch *= crossing<min(service,older) ? 0.92 : 0.88;
	road = mix(road,patch,repair);
	n = mix(n,texture(aggregate_normal,patch_uv).xyz*2.0-1.0,repair);
	rough = mix(rough,texture(aggregate_orm,patch_uv).g,repair);
	// Exposed binder between aggregates is narrow and broken at the cut.
	float edge = (1.0-smoothstep(0.015,0.075,abs(cut_distance)))*(0.25+0.75*edge_noise(p*70.0));
	road *= 1.0-edge*0.045;
	float gutter_distance = world_position.z>210.0 ? min(abs(world_position.z-220.62),abs(world_position.z-226.38)) : min(abs(world_position.z-183.17),abs(world_position.z-189.83));
	float gutter = 1.0-smoothstep(0.04,0.38,gutter_distance);
	road *= 1.0-gutter*(0.06+0.08*edge_noise(p*5.0));
	road = mix(road,vec3(dot(road,vec3(0.2126,0.7152,0.0722))),0.75);
	// Paint exposes the identical road material through small worn aggregate pits.
	float pigment = dot(texture(aggregate_albedo,grain_uv).rgb,vec3(0.3333));
	float chips = (1.0-smoothstep(0.006,0.021,pigment))*(0.20+0.80*edge_noise(p*4.1));
	ALBEDO = mix(road,mix(vec3(0.61,0.60,0.54),road,chips*0.72),paint_surface);
	vec2 normal_xy = n.xy*0.10;
	vec3 world_normal = normalize(vec3(normal_xy.x,1.0,normal_xy.y));
	NORMAL = normalize((VIEW_MATRIX*vec4(world_normal,0.0)).xyz);
	ROUGHNESS = clamp(mix(rough,0.94,repair*0.4)+0.03,0.78,1.0);
	SPECULAR = 0.20;
	// Rain film at night: damp everywhere, near-mirror standing water in low spots.
	float puddle = smoothstep(0.4,0.56,edge_noise(p*0.42)*0.75+edge_noise(p*1.9)*0.25);
	float film = wetness*(0.6+0.4*puddle);
	ALBEDO *= 1.0-0.62*film;
	ROUGHNESS = mix(ROUGHNESS,mix(0.26,0.03,puddle),min(film*1.5,1.0));
	SPECULAR = mix(SPECULAR,0.62,film);
	NORMAL = normalize(mix(NORMAL,(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz,wetness*puddle*0.9));
}
