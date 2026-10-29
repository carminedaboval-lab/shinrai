extends RefCounted
const STONE_ROOT := "res://assets/shinrai/buildings/yakitori_shop/artwork_replica_v5/ProjectShinrai_YakitoriShop_ArtworkReplica_v5_Stone_"
static var _materials:Dictionary={}
static func build(width:float,length:float=0.0,closed:bool=false)->ShaderMaterial:
	# Per-width shared materials keep the edge detail at a real metre scale.
	var key:=Vector3(width,roundf(length),1.0 if closed else 0.0)
	if _materials.has(key):return _materials[key]
	var shader:=Shader.new()
	shader.code="""
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D stone_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D stone_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D stone_orm : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float path_width=5.0;
uniform float marker_period=18.0;
uniform float wayfinding_strength=0.0;
uniform float night_emission=0.0;
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 vec2 p=world_position.xz;
 vec3 grain=texture(stone_albedo,p/1.6).rgb;
 vec3 broad=texture(stone_albedo,p/13.7+vec2(.31,.71)).rgb;
 float variation=dot(broad,vec3(.333));
 float edge=min(UV.y,1.0-UV.y)*path_width;
 float along=UV.x*2.0;
 // Fine mineral paving and intermittent flush wayfinding inserts: no lit border.
 // Arrival paving is a cooler, dressed mineral finish; ordinary walks retain
 // their established warmer stone. The blend is local and continuous.
 float arrival=1.0-smoothstep(22.0,42.0,length(p-vec2(0.0,168.0)));
 ALBEDO=grain*mix(vec3(1.03,1.0,.92),vec3(1.12,1.14,1.10),arrival)*(.91+.25*variation);
 float joint_distance=abs(mod(along+1.2,2.4)-1.2);
 float joint_aa=max(fwidth(along),.001);
 float joint=(1.0-smoothstep(.003,.003+joint_aa,joint_distance))*smoothstep(.20,.28,edge);
 ALBEDO*=1.0-joint*.13;
 vec2 slab=vec2(along/1.2,UV.y*path_width/.6);
 slab.x+=mod(floor(slab.y),2.0)*.5;
 vec2 seam=min(fract(slab),1.0-fract(slab))*vec2(1.2,.6);
 vec2 seam_aa=max(fwidth(slab)*vec2(1.2,.6),vec2(.001));
 float dressed_joint=1.0-min(smoothstep(.0025,.0025+seam_aa.x,seam.x),smoothstep(.0025,.0025+seam_aa.y,seam.y));
 ALBEDO*=1.0-dressed_joint*.19*arrival;
 float shoulder=1.0-smoothstep(.02,.20,edge);
 ALBEDO=mix(ALBEDO,grain*vec3(.79,.77,.65),shoulder*.25);
 float run=abs(mod(along+marker_period*.5,marker_period)-marker_period*.5);
 float aa=max(fwidth(edge),.002);
 float marker=(1.0-smoothstep(.055,.055+aa,abs(edge-.32)))*(1.0-smoothstep(.11,.12+joint_aa,run))*wayfinding_strength;
 vec3 guide=vec3(.34,.57,.55);
 ALBEDO=mix(ALBEDO,guide*.5,marker);
 EMISSION=guide*marker*night_emission*.48;
 vec3 orm=texture(stone_orm,p/1.6).rgb;
 ROUGHNESS=mix(clamp(orm.g*.25+.70,.82,.96),.50,marker);
 SPECULAR=.18;METALLIC=0.0;AO=mix(1.0,orm.r,.12);
 vec3 n=normalize(world_normal);
 if(abs(n.y)>.5){
  vec3 detail=texture(stone_normal,p/1.6).rgb*2.0-1.0;
  vec3 relief=vec3(detail.x*.20,0.0,detail.y*.20);
  relief-=n*dot(relief,n);
  n=normalize(n*max(detail.z,.6)+relief);
 }
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
}
"""
	var mat:=ShaderMaterial.new();mat.shader=shader
	mat.resource_name="Midori2050_MineralWalk_"+str(width)
	mat.set_shader_parameter("stone_albedo",load(STONE_ROOT+"BaseColor.png"))
	mat.set_shader_parameter("stone_normal",load(STONE_ROOT+"NormalGL.png"))
	mat.set_shader_parameter("stone_orm",load(STONE_ROOT+"ORM.png"))
	mat.set_shader_parameter("path_width",width)
	mat.set_shader_parameter("wayfinding_strength",1.0 if length>0.0 else 0.0)
	mat.set_shader_parameter("marker_period",length/maxf(1.0,roundf(length/18.0)) if closed and length>0.0 else 18.0)
	_materials[key]=mat
	return mat
