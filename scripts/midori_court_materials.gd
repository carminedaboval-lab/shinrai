extends RefCounted

# Formal plaza finish uses the park's existing stone maps at metre scale.
# No new mesh, texture, collision, lighting pass or scatter is added.
const STONE_ROOT := "res://assets/shinrai/buildings/yakitori_shop/artwork_replica_v5/ProjectShinrai_YakitoriShop_ArtworkReplica_v5_Stone_"
const ShaderPool := preload("res://scripts/shinrai_shader_pool.gd")
# Both plaza finishes (warm stone, charcoal border) share one pooled shader; the
# tint and slab size are uniforms on their own materials.
static func build(dark_border: bool = false) -> ShaderMaterial:
 var shader := ShaderPool.shader("""
shader_type spatial;
uniform sampler2D stone_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D stone_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D stone_orm : repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 stone_tint = vec3(1.28,1.23,1.12);
uniform vec2 slab_size = vec2(1.2,.6);
uniform float wetness = 0.0;
varying vec3 world_position;
varying vec3 world_normal;
float slab_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() {
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
 vec2 p=world_position.xz;
 vec3 grain=texture(stone_albedo,p/1.3).rgb;
 vec2 courses=p/slab_size;
 courses.x+=mod(floor(courses.y),2.0)*.5;
 vec2 cell=floor(courses);
 vec2 centre_distance=min(fract(courses),1.0-fract(courses))*slab_size;
 vec2 aa=max(fwidth(courses)*slab_size,vec2(.001));
 float joint=1.0-min(smoothstep(.0025,.0025+aa.x,centre_distance.x),smoothstep(.0025,.0025+aa.y,centre_distance.y));
 float variation=mix(.93,1.07,slab_hash(cell));
 ALBEDO=grain*stone_tint*variation*(1.0-joint*.26);
 vec3 orm=texture(stone_orm,p/1.3).rgb;
 ROUGHNESS=clamp(orm.g*.18+.73+joint*.06,.78,.95);
 SPECULAR=.20; METALLIC=0.0; AO=mix(1.0,orm.r,.16);
 vec3 n=normalize(world_normal);
 if(abs(n.y)>.5) {
  vec3 detail=texture(stone_normal,p/1.3).rgb*2.0-1.0;
  vec3 relief=vec3(detail.x*.25,0.0,detail.y*.25);
  relief-=n*dot(relief,n);
  n=normalize(n*max(detail.z,.6)+relief);
 }
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
 // Rain film: the open plaza holds the most water in the park.
 float pool=smoothstep(.34,.5,texture(stone_albedo,p/37.0+vec2(.41,.23)).r+texture(stone_albedo,p/11.0).r*.25);
 float film=wetness*(.6+.4*pool);
 ALBEDO*=1.0-.55*film;
 ROUGHNESS=mix(ROUGHNESS,mix(.24,.04,pool),film);
 SPECULAR=mix(SPECULAR,.62,film);
 NORMAL=normalize(mix(NORMAL,(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz,wetness*pool*.9));
}
""")
 var mat := ShaderMaterial.new()
 mat.shader=shader
 mat.resource_name="MidoriPlaza_CharcoalMineral" if dark_border else "MidoriPlaza_WarmHonedStone"
 mat.set_shader_parameter("stone_albedo",load(STONE_ROOT+"BaseColor.png"))
 mat.set_shader_parameter("stone_normal",load(STONE_ROOT+"NormalGL.png"))
 mat.set_shader_parameter("stone_orm",load(STONE_ROOT+"ORM.png"))
 mat.set_shader_parameter("stone_tint",Vector3(.60,.66,.65) if dark_border else Vector3(1.28,1.23,1.12))
 mat.set_shader_parameter("slab_size",Vector2(.6,.6) if dark_border else Vector2(1.2,.6))
 return mat
