extends RefCounted
const Walk = preload("res://scripts/midori_walk_materials.gd")
const FLOOR := "res://assets/shinrai/parks/midori_park/materials/forrest_ground_01/forrest_ground_01_diff_2k.jpg"

func install(park: Node3D, terrain: Node, routes: Array[Dictionary]) -> void:
	for frame in range(2):await park.get_tree().physics_frame
	
	var parent := Node3D.new()
	parent.name="VisibleWoodlandTrails"
	park.add_child(parent)
	parent.global_transform=Transform3D.IDENTITY
	var shader:=Shader.new()
	shader.code="""
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D stone : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D stone_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D stone_orm : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D floor_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
varying vec3 p;
varying vec3 world_normal;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 float edge=abs(UV.y*2.0-1.0);
 float waviness=0.035*sin(p.x*6.7+p.z*4.9)+0.025*sin(p.z*16.0-p.x*12.0);
 float speckle=fract(sin(dot(p.xz,vec2(12.9898,78.233)))*43758.5453);
 if(COLOR.g<=.001 || speckle>COLOR.g || edge>0.95+waviness)discard;
 vec3 grain=texture(stone,p.xz/1.35).rgb;
 vec3 floor_color=texture(floor_map,p.xz/2.2).rgb;
 float wear=texture(stone,p.xz/9.3).r;
 vec3 earth=grain*vec3(1.12,0.90,0.64)*(0.90+wear*0.32);
 vec3 soil=mix(earth,floor_color,smoothstep(0.65,1.0,edge)*0.84);
 vec3 mineral=texture(stone,p.xz/1.6).rgb;
 float variation=dot(texture(stone,p.xz/13.7+vec2(.31,.71)).rgb,vec3(.333));
 vec3 paving=mineral*vec3(1.06,1.0,.88)*(.90+.28*variation);
 float blend=smoothstep(.030,.065,COLOR.r);
 ALBEDO=mix(soil,paving,blend);
 vec3 n=normalize(world_normal);
 if(n.y<0.0)n=-n;
 vec3 detail=texture(stone_normal,p.xz/1.6).rgb*2.0-1.0;
 vec3 relief=vec3(detail.x*.24,0.0,detail.y*.24)*blend;
 relief-=n*dot(relief,n);
 n=normalize(n*mix(1.0,max(detail.z,.6),blend)+relief);
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
 ROUGHNESS=mix(.98,clamp(texture(stone_orm,p.xz/1.6).g*.25+.72,.86,.98),blend); SPECULAR=mix(.12,.18,blend); METALLIC=0.0;
}
"""
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	mat.set_shader_parameter("stone",load(Walk.STONE_ROOT+"BaseColor.png"))
	mat.set_shader_parameter("floor_map",load(FLOOR))
	mat.set_shader_parameter("stone_normal",load(Walk.STONE_ROOT+"NormalGL.png"))
	mat.set_shader_parameter("stone_orm",load(Walk.STONE_ROOT+"ORM.png"))
	for route: Dictionary in routes:
		var raw: PackedVector2Array=route.points
		var smooth:=raw.duplicate()
		# Only round grid corners slightly, staying inside the cleared corridor.
		for i in range(1,raw.size()-1): smooth[i]=raw[i]*0.6+(raw[i-1]+raw[i+1])*0.2
		var points:=PackedVector2Array()
		for i in range(smooth.size()-1):
			var steps:=maxi(1,ceili(smooth[i].distance_to(smooth[i+1])/.45))
			for j in range(steps): points.append(smooth[i].lerp(smooth[i+1],float(j)/steps))
		points.append(smooth[-1])
		var strips:Array[PackedVector3Array]=[]
		var length:=0.0
		var lengths:=PackedFloat32Array()
		for i in range(points.size()):
			if i>0:length+=points[i].distance_to(points[i-1])
			lengths.append(length)
			var direction:Vector2=points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]
			var side:=Vector2(-direction.y,direction.x).normalized()
			var half_width:=.70+.08*sin(length*.47)+.045*cos(length*1.37)
			var strip:=PackedVector3Array()
			# Five cross-sections keep the overlay close to the actual terrain.
			for k in range(5):
				var p:Vector2=points[i]+side*half_width*(float(k)/2.0-1.0)
				strip.append(Vector3(p.x,_surface_height(p,terrain),p.y))
			strips.append(strip)
		var st:=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(strips.size()-1):
			for k in range(4):
				for pair:Vector2i in [Vector2i(i,k),Vector2i(i,k+1),Vector2i(i+1,k),Vector2i(i,k+1),Vector2i(i+1,k+1),Vector2i(i+1,k)]:
					var v:Vector3=strips[pair.x][pair.y]
					var blend:float=v.y-terrain.height_at(Vector2(v.x,v.z))
					# Soft worn-earth tips inside a genuinely detached mesh.
					var visible:float=smoothstep(0.0,2.5,minf(lengths[pair.x],length-lengths[pair.x]))
					st.set_color(Color(blend,visible,0,1))
					st.set_uv(Vector2(lengths[pair.x],float(pair.y)/4.0))
					st.add_vertex(strips[pair.x][pair.y])
		st.generate_normals()
		var mesh:=MeshInstance3D.new()
		mesh.name=String(route.name).replace(" ","_")
		mesh.mesh=st.commit()
		mesh.material_override=mat
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mesh)
		mesh.set_meta("trail_length",length)
		var body:=StaticBody3D.new()
		body.add_to_group("midori_trail_walk")
		mesh.add_child(body)
		var collision:=CollisionShape3D.new()
		var shape:=ConcavePolygonShape3D.new()
		shape.backface_collision=true
		shape.set_faces(mesh.mesh.get_faces())
		collision.shape=shape
		body.add_child(collision)
	print("WOODLAND_TRAIL_SURFACES routes=",parent.get_child_count())

func _surface_height(p:Vector2,terrain:Node)->float:
	# Woodland earth follows the ground; it never ramps onto raised paving.
	return terrain.height_at(p)+.012
