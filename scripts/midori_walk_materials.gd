extends RefCounted
const STONE_ROOT := "res://assets/shinrai/buildings/yakitori_shop/artwork_replica_v5/ProjectShinrai_YakitoriShop_ArtworkReplica_v5_Stone_"
static var _materials:Dictionary={}
static var _secondary:Dictionary={}

## Secondary park walk: compacted decomposed granite (真砂土), the warm fine
## grit of Japanese park side paths. No slab joints; it sits flush and its rim
## breaks unevenly into the lawn so it reads as part of the ground.
static func build_secondary(width:float)->ShaderMaterial:
	if _secondary.has(width):return _secondary[width]
	var shader:=Shader.new()
	shader.code="""
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D stone_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D stone_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float path_width=2.5;
uniform float night_emission=0.0;
uniform float wetness=0.0;
varying vec3 world_position;
varying vec3 world_normal;
float hsh(vec2 q){ return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 q){ vec2 i = floor(q); vec2 f = fract(q); f = f*f*(3.0-2.0*f);
	return mix(mix(hsh(i), hsh(i+vec2(1,0)), f.x), mix(hsh(i+vec2(0,1)), hsh(i+vec2(1,1)), f.x), f.y); }
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 vec2 p=world_position.xz;
 float edge=min(UV.y,1.0-UV.y)*path_width;
 float ragged=vn(p*0.9)*0.65+vn(p*2.6)*0.35;
 // The lawn creeps over the rim in broad, uneven bites.
 if(edge<0.3*ragged)discard;
 // Grit at three real scales, each from the stone photo so it is irregular.
 vec3 fine=texture(stone_albedo,p/0.45).rgb;
 vec3 mid=texture(stone_albedo,p/1.7+vec2(.37,.11)).rgb;
 float g_fine=dot(fine,vec3(.333));
 float g_mid=dot(mid,vec3(.333));
 // Weathered masado: a dull warm grey-brown, darker than sand.
 vec3 masado=vec3(.4,.35,.285)*(.72+.5*g_fine)*(.88+.24*g_mid);
 // Broad tone: damp, darker patches and drier, slightly paler stretches.
 float broad=vn(p*.12)*0.55+vn(p*.45)*0.3+vn(p*1.4)*0.15;
 masado*=.8+.34*broad;
 float damp=smoothstep(.55,.8,vn(p*.33+vec2(4.1,1.7)));
 masado=mix(masado,masado*vec3(.62,.6,.56),damp*.6);
 // Small stones: bright and dark specks shaped by the photo, not by a grid.
 float stones=smoothstep(.68,.8,g_fine)*step(.45,vn(p*7.0));
 masado=mix(masado,vec3(.5,.48,.44)*(.8+.4*g_mid),stones*.45);
 masado*=1.0-smoothstep(.0,.25,.32-g_fine)*.2;
 // Leaf litter blown onto the walk, thicker near the rim.
 float rim=1.0-smoothstep(.0,.6,edge-0.3*ragged);
 float litter=step(.82,vn(p*9.0+vec2(2.3,.7)))*(.35+.65*rim);
 masado=mix(masado,vec3(.24,.17,.08)*(.8+.4*g_mid),litter*.7);
 // The rim darkens into soil before the grass takes over.
 masado=mix(masado,vec3(.14,.12,.085),rim*.55);
 ALBEDO=masado*(1.0-.4*wetness);
 AO=mix(.85,1.0,g_fine);
 vec3 n=normalize(world_normal);
 if(n.y<0.0)n=-n;
 vec3 detail=texture(stone_normal,p/0.45).rgb*2.0-1.0;
 vec3 detail2=texture(stone_normal,p/1.7+vec2(.37,.11)).rgb*2.0-1.0;
 n=normalize(n+vec3(detail.x+detail2.x*.6,0.0,detail.y+detail2.y*.6)*.3);
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
 ROUGHNESS=mix(.97,.45,max(wetness,damp*.25));SPECULAR=.08;METALLIC=0.0;
}
"""
	var mat:=ShaderMaterial.new();mat.shader=shader
	mat.resource_name="Midori_MasadoWalk_"+str(width)
	mat.set_shader_parameter("stone_albedo",load(STONE_ROOT+"BaseColor.png"))
	mat.set_shader_parameter("stone_normal",load(STONE_ROOT+"NormalGL.png"))
	mat.set_shader_parameter("path_width",width)
	_secondary[width]=mat
	return mat
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
uniform float wetness=0.0;
varying vec3 world_position;
varying vec3 world_normal;
float hs(vec2 q){ return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
float nz(vec2 q){ vec2 i = floor(q); vec2 f = fract(q); f = f*f*(3.0-2.0*f);
 return mix(mix(hs(i), hs(i+vec2(1,0)), f.x), mix(hs(i+vec2(0,1)), hs(i+vec2(1,1)), f.x), f.y); }
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 vec2 p=world_position.xz;
 float edge=min(UV.y,1.0-UV.y)*path_width;
 // Weathered mineral walk: one continuous surface, no joints and no inserts.
 // Two rotated reads of the stone scan and broad noise keep it from tiling.
 mat2 rot=mat2(vec2(.819,.574),vec2(-.574,.819));
 vec3 grain_a=texture(stone_albedo,p/1.6).rgb;
 vec3 grain_b=texture(stone_albedo,rot*p/2.3+vec2(.41,.17)).rgb;
 float mixer=smoothstep(.3,.7,nz(p*.23));
 vec3 grain=mix(grain_a,grain_b,mixer);
 float broad=nz(p*.07)*.55+nz(p*.31)*.3+nz(p*1.3)*.15;
 // The rim crumbles: soil and grass from the worn shoulder show through.
 float fray=nz(p*1.1+vec2(2.0,6.0))*.65+nz(p*3.4+vec2(8.0,1.0))*.35;
 if(edge<.26*fray)discard;
 float arrival=1.0-smoothstep(22.0,42.0,length(p-vec2(0.0,168.0)));
 // Weathered to the land's value: warm, slightly dirty grey, not clean stone.
 vec3 color=grain*mix(vec3(.86,.82,.74),vec3(.98,.98,.94),arrival)*(.78+.34*broad);
 float luma=dot(color,vec3(.299,.587,.114));
 color=mix(vec3(luma)*vec3(1.04,1.0,.9),color,.7);
 // Feet polish the middle a touch paler; dirt and moss gather toward the rim.
 float middle=smoothstep(.5,path_width*.4,edge);
 color*=mix(.9,1.06,middle*smoothstep(.35,.7,nz(p*.5+vec2(3.0,1.0))));
 // Grime creeps in from the edge, deepest where the paving breaks up.
 float rim=1.0-smoothstep(.26*fray,.9+.5*nz(p*1.7),edge);
 vec3 soil=grain*vec3(.42,.37,.28);
 color=mix(color,soil,rim*.7);
 float moss=smoothstep(.55,.8,nz(p*2.1+vec2(9.0,4.0)))*rim;
 color=mix(color,color*vec3(.62,.78,.48),moss*.6);
 // Damp stains and fallen leaves, scattered irregularly.
 float stain=smoothstep(.6,.85,nz(p*.45+vec2(5.0,8.0)));
 color*=1.0-stain*.18;
 float leaf=smoothstep(.8,.9,nz(p*13.0+vec2(1.3,2.9))*.7+nz(p*29.0+vec2(4.1,.3))*.3)*smoothstep(.45,.7,nz(p*.6+vec2(7.0,2.0)))*(.4+.6*rim);
 color=mix(color,vec3(.2,.14,.08)*(.8+.4*broad),leaf*.55);
 ALBEDO=color;
 EMISSION=vec3(0.0);
 vec3 orm=texture(stone_orm,p/1.6).rgb;
 ROUGHNESS=clamp(orm.g*.25+.70,.82,.96);
 SPECULAR=.16;METALLIC=0.0;AO=mix(1.0,orm.r,.12);
 vec3 n=normalize(world_normal);
 if(abs(n.y)>.5){
  vec3 detail=mix(texture(stone_normal,p/1.6).rgb,texture(stone_normal,rot*p/2.3+vec2(.41,.17)).rgb,mixer)*2.0-1.0;
  vec3 relief=vec3(detail.x*.22,0.0,detail.y*.22);
  relief-=n*dot(relief,n);
  n=normalize(n*max(detail.z,.6)+relief);
 }
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
 // Rain film: broad damp stone with shallow standing water.
 float pool=smoothstep(.34,.52,texture(stone_albedo,p/31.0+vec2(.17,.63)).r+texture(stone_albedo,p/9.0).r*.25);
 float film=wetness*(.55+.45*pool);
 ALBEDO*=1.0-.5*film;
 ROUGHNESS=mix(ROUGHNESS,mix(.3,.06,pool),film);
 SPECULAR=mix(SPECULAR,.58,film);
 NORMAL=normalize(mix(NORMAL,(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz,wetness*pool*.85));
}
"""
	var mat:=ShaderMaterial.new();mat.shader=shader
	mat.resource_name="Midori2050_MineralWalk_"+str(width)
	mat.set_shader_parameter("stone_albedo",load(STONE_ROOT+"BaseColor.png"))
	mat.set_shader_parameter("stone_normal",load(STONE_ROOT+"NormalGL.png"))
	mat.set_shader_parameter("stone_orm",load(STONE_ROOT+"ORM.png"))
	mat.set_shader_parameter("path_width",width)
	mat.set_shader_parameter("wayfinding_strength",0.0)
	mat.set_shader_parameter("marker_period",length/maxf(1.0,roundf(length/18.0)) if closed and length>0.0 else 18.0)
	_materials[key]=mat
	return mat
