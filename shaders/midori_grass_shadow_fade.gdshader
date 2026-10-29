
shader_type spatial;

uniform vec3 midori_sc_main_camera;
uniform vec2 midori_sc_fade_distances = vec2(14.0,24.0);
varying vec3 midori_sc_rest_world;
float midori_sc_noise(vec3 world) {
    return fract(sin(dot(floor(world * 64.0), vec3(127.1,311.7,74.7))) * 43758.5453);
}

render_mode cull_disabled, diffuse_burley;
// Material-only ageing; all mesh vertices, density and LODs remain intact.
uniform float variation_strength : hint_range(0.0,1.0) = 1.0;
varying vec2 grass_world;
varying vec2 grass_root;
void vertex() {
    midori_sc_rest_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;

    grass_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz;
    grass_root = MODEL_MATRIX[3].xz;
}

float hash21(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float smooth_noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1.0,0.0)),f.x),mix(hash21(i+vec2(0.0,1.0)),hash21(i+vec2(1.0)),f.x),f.y);
}
void fragment() {
    float midori_sc_distance = distance(midori_sc_rest_world.xz, midori_sc_main_camera.xz);
    float midori_sc_coverage = 1.0 - smoothstep(midori_sc_fade_distances.x,midori_sc_fade_distances.y,midori_sc_distance);
    if (midori_sc_coverage <= 0.0) { discard; }
    if (midori_sc_coverage < 1.0 && midori_sc_noise(midori_sc_rest_world) >= midori_sc_coverage) { discard; }

	float grain=smooth_noise(UV*vec2(31.0,240.0));
	float mottling=smooth_noise(UV*vec2(5.0,17.0)+COLOR.rg*117.0);
	float veins=sin(UV.x*94.2478+0.16*sin(UV.y*12.0));
	float centre=exp(-abs(UV.x-0.5)*60.0);
	float edge=pow(abs(UV.x*2.0-1.0),10.0);
	float root=smoothstep(0.01,0.30,UV.y);
	vec3 green=COLOR.rgb*vec3(0.67,0.80,0.70);
	green*=mix(0.48,1.0,root)*(0.92+0.12*mottling+0.04*grain+0.035*veins);
	green=mix(green,green*vec3(1.18,1.06,0.85),centre*0.27+edge*0.12);
	float dry_tip=smoothstep(0.92,1.0,UV.y)*step(0.72,hash21(COLOR.rg*77.0));
	ALBEDO=mix(green,vec3(0.19,0.20,0.055),dry_tip*0.35);

    // Broad, softly blended age zones break up repeated patch appearance.
    // Finer tuft variation avoids tinting every leaf in a bed identically.
    float age_zone=smooth_noise(grass_world*0.075+vec2(17.3,8.1));
    float soil_zone=smooth_noise(grass_world*0.22+vec2(4.7,31.2));
    float tuft=hash21(grass_root*1.73+vec2(19.0,7.0));
    float age=clamp(age_zone*0.78+soil_zone*0.22,0.0,1.0);
    float mature=smoothstep(0.40,0.73,age);
    float fresh=1.0-smoothstep(0.24,0.49,age);
    vec3 varied=ALBEDO*mix(vec3(0.83,0.89,0.79),vec3(1.12,1.07,0.91),soil_zone);
    varied=mix(varied,varied*vec3(0.85,1.07,0.85),fresh*0.55);
    varied=mix(varied,vec3(0.155,0.171,0.052),mature*0.32);
    // Older individual blades retain green bases and acquire tawny tips.
    float tired=smoothstep(0.52,0.79,age)*smoothstep(0.40,0.86,tuft);
    float aged_tip=smoothstep(0.58,0.98,UV.y)*tired;
    float sun_fade=smoothstep(0.64,0.91,UV.y)*step(0.86,tuft)*(0.35+mature*0.65);
    varied=mix(varied,vec3(0.25,0.205,0.082),clamp(aged_tip*0.68+sun_fade*0.28,0.0,0.7));
    varied*=mix(0.92,1.04,tuft);
    ALBEDO=mix(ALBEDO,varied,variation_strength);
    // Preserve every blade and its age variation while restraining the lime
    // cast that dominates the shoreline foreground in daylight.
    ALBEDO*=vec3(.88,.90,1.08);
    ROUGHNESS=clamp(0.60+grain*0.16+edge*0.04+variation_strength*(mature*0.12+aged_tip*0.06),0.0,1.0);
	SPECULAR=0.24;
	AO=mix(0.52,1.0,root);
	AO_LIGHT_AFFECT=0.35;
	NORMAL_MAP=vec3(0.5+veins*0.035,0.5+(grain-0.5)*0.025,1.0);
	NORMAL_MAP_DEPTH=0.28;
	BACKLIGHT=green*0.10*root;
}
