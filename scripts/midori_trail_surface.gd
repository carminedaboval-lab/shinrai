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
	# Worn earth: packed, darker and less saturated than the forest floor down the
	# middle, its rim breaking into irregular patches where grass creeps back.
	# No hard band and no fringe colour: the trail is the ground, trodden.
	shader.code="""
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D stone_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D floor_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
varying vec3 p;
varying vec3 world_normal;
float hsh(vec2 q){ return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 q){ vec2 i = floor(q); vec2 f = fract(q); f = f*f*(3.0-2.0*f);
	return mix(mix(hsh(i), hsh(i+vec2(1,0)), f.x), mix(hsh(i+vec2(0,1)), hsh(i+vec2(1,1)), f.x), f.y); }
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 float edge=abs(UV.y*2.0-1.0);
 float patches=vn(p.xz*1.7)*0.55+vn(p.xz*5.3)*0.3+vn(p.xz*13.0)*0.15;
 // Where bare earth gives way to grass: breathes along the trail, closes at the ends.
 float reach=(0.5+0.42*patches)*COLOR.g;
 if(edge>reach)discard;
 vec3 ground=texture(floor_map,p.xz/1.9).rgb;
 vec3 broad=texture(floor_map,p.xz/11.0).rgb;
 float grey=dot(ground,vec3(0.333));
 vec3 packed_earth=mix(vec3(grey)*vec3(0.78,0.7,0.6),ground,0.35)*0.82;
 float trodden=smoothstep(reach,reach*0.25,edge);
 vec3 color=mix(ground*vec3(0.92,0.88,0.8),packed_earth,trodden);
 color*=0.88+0.24*dot(broad,vec3(0.333));
 ALBEDO=color;
 vec3 n=normalize(world_normal);
 if(n.y<0.0)n=-n;
 vec3 detail=texture(stone_normal,p.xz/0.9).rgb*2.0-1.0;
 n=normalize(n+vec3(detail.x,0.0,detail.y)*0.12);
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
 ROUGHNESS=0.96; SPECULAR=0.1; METALLIC=0.0;
}
"""
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	mat.set_shader_parameter("floor_map",load(FLOOR))
	mat.set_shader_parameter("stone_normal",load(Walk.STONE_ROOT+"NormalGL.png"))
	for route: Dictionary in routes:
		var raw: PackedVector2Array=route.points
		# The route comes off a pathfinding grid in stair steps. Drop the steps,
		# then round what is left into the easy curves feet actually wear.
		var smooth:=_simplify(raw,0.9)
		for pass_index in range(3): smooth=_chaikin(smooth)
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
			var half_width:=.95+.1*sin(length*.31)+.06*cos(length*1.13)
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

## Ramer-Douglas-Peucker: keep only the points that bend the line by more than `tolerance`.
func _simplify(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if points.size() < 3: return points
	var worst := 0.0
	var index := 0
	var a := points[0]
	var b := points[points.size() - 1]
	for i in range(1, points.size() - 1):
		var d := Geometry2D.get_closest_point_to_segment(points[i], a, b).distance_to(points[i])
		if d > worst:
			worst = d
			index = i
	if worst <= tolerance: return PackedVector2Array([a, b])
	var left := _simplify(points.slice(0, index + 1), tolerance)
	var right := _simplify(points.slice(index), tolerance)
	left.resize(left.size() - 1)
	left.append_array(right)
	return left

## One round of Chaikin corner cutting; the ends stay put.
func _chaikin(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3: return points
	var out := PackedVector2Array([points[0]])
	for i in range(points.size() - 1):
		out.append(points[i].lerp(points[i + 1], 0.25))
		out.append(points[i].lerp(points[i + 1], 0.75))
	out.append(points[points.size() - 1])
	return out
