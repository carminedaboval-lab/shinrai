shader_type spatial;
uniform vec4 iron_color : source_color = vec4(.38,.40,.37,1.0);
uniform float base_roughness=.85;
uniform float metalness=.35;
varying vec3 metre_position;
float hash21(vec2 p) {
	vec3 q=fract(vec3(p.x,p.y,p.x)*.1031);
	q+=dot(q,q.yzx+33.33);
	return fract((q.x+q.y)*q.z);
}
void vertex() { metre_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p=(metre_position.xz-vec2(4.5,182.9))*620.0;
	float visibility=1.0-smoothstep(.55,1.5,max(length(dFdx(p)),length(dFdy(p))));
	float grain=mix(.5,hash21(floor(p)),visibility);
	ALBEDO=iron_color.rgb*(.96+.08*grain);
	ROUGHNESS=clamp(base_roughness+(grain-.5)*.08,.6,1.0);
	METALLIC=metalness;
	SPECULAR=.3;
}
