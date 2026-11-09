extends RefCounted

# Authored locally for Shinrai. No generated/downloaded replacement assets.
const ShaderPool := preload("res://scripts/shinrai_shader_pool.gd")
const CENTER := Vector3(-140,.15,-86)
const DECK := Vector2(39.8,21.1)
const FIELD := Vector2(34,16.8)
const GOAL_HALF := 1.54 # 3.00m clear between 80mm posts.
const GOAL_TOP := 2.04 # 2.00m clear below 80mm crossbar.
const NET_STEP := .10
const ROPE_RADIUS := .002

static func build_visuals(parent: Node3D) -> Node3D:
	var assembly := Node3D.new()
	assembly.name = "ACT03_RemasteredFootballPitch"
	parent.add_child(assembly)
	# Parent may be park's scaled layout; preserve actual metre coordinates.
	assembly.transform = parent.global_transform.affine_inverse()*Transform3D(Basis.IDENTITY,CENTER)
	var carpet := MeshInstance3D.new()
	carpet.name = "LevelSyntheticTurfAndIntegratedLines"
	var plane := PlaneMesh.new()
	plane.size = DECK
	plane.material = _turf_material()
	carpet.mesh = plane
	carpet.position.y = .002
	carpet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	assembly.add_child(carpet)
	_short_pile(assembly)
	_goal(assembly,-1.0)
	_goal(assembly,1.0)
	var stats := _statistics(assembly)
	stats["court_m"] = FIELD
	stats["deck_m"] = DECK
	stats["surface_world_y"] = CENTER.y+.002
	stats["goal_clear_opening_m"] = Vector2(3,2)
	stats["net_depth_top_bottom_m"] = Vector2(.35,1.05)
	stats["net_spacing_m"] = NET_STEP
	stats["net_rope_diameter_m"] = ROPE_RADIUS*2
	stats["nets_blocking"] = false
	assembly.set_meta("pitch_remaster_report",stats)
	print("PITCH_REMASTER_BUILT ",JSON.stringify(stats))
	return assembly

static func _turf_material(pile_pass: bool = false) -> ShaderMaterial:
	# Carpet and pile share one pooled shader; pile_pass is a uniform.
	var shader := ShaderPool.shader("""
shader_type spatial;
render_mode cull_disabled;
uniform bool pile_pass=false;
varying vec2 metre;
varying float tip;
varying float seed;
float hash21(vec2 p){vec3 q=fract(vec3(p.x,p.y,p.x)*vec3(.1031,.1030,.0973));q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);}
float noise2(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);}
float border(vec2 p,vec2 halfsize){vec2 q=abs(p)-halfsize;return length(max(q,vec2(0)))+min(max(q.x,q.y),0.0);}
void vertex(){
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 metre=world.xz-vec2(-140.0,-86.0); tip=UV.y;seed=COLOR.r;
 if(pile_pass){float pile_visibility=1.0-smoothstep(4.0,8.0,distance(world.xz,CAMERA_POSITION_WORLD.xz));VERTEX.y=VERTEX.y*pile_visibility-tip*.001*(1.0-pile_visibility);}
}
void fragment(){
 vec2 p=metre; vec2 a=abs(p);
 float pixel=max(length(dFdx(p)),length(dFdy(p)));
 float aa=max(pixel*.65,.001);
 float distance_line=abs(border(p,vec2(17.0,8.4)));
 if(a.y<=8.4)distance_line=min(distance_line,a.x);
 distance_line=min(distance_line,abs(length(p)-3.0));
 // Consistent small-sided penalty arcs:6m radius around the posts,
 // joined by straight segment. All markings are material, never raised mesh.
 if(a.x<=17.0 && a.x>=10.95){
   if(a.y>=1.58)distance_line=min(distance_line,abs(length(vec2(a.x-17.0,a.y-1.58))-6.0));
   else distance_line=min(distance_line,abs(a.x-11.0));
 }
 if(a.x<=17.0 && a.y<=8.4){
   distance_line=min(distance_line,abs(length(vec2(a.x-17.0,a.y-8.4))-.25));
 }
 float fringe=.0015*sin(p.x*913.0+p.y*719.0);
 float paint=1.0-smoothstep(.04-aa+fringe,.04+aa+fringe,distance_line);
 float spot=max(1.0-smoothstep(.055-aa,.055+aa,length(p)),max(1.0-smoothstep(.055-aa,.055+aa,length(vec2(a.x-11.0,p.y))),1.0-smoothstep(.055-aa,.055+aa,length(vec2(a.x-7.0,p.y)))));
 paint=max(paint,spot);
 // Continuous waves avoid the V1 hash-grid colour discontinuities.
 float macro=(noise2(p*.63)*2.0-1.0);
 float meso=(noise2(p*43.0)*2.0-1.0);
 float fine=(noise2(p*vec2(550.0,190.0))*2.0-1.0);
 float fade=1.0-smoothstep(.002,.016,pixel);
 float band=tanh(sin(p.x*1.4783965)*5.0);
 vec3 grass=vec3(.064,.155,.051)*(1.0+band*.085+macro*.045+meso*.095+fine*.13*fade);
 vec3 white=vec3(.66,.69,.60)*(1.0+meso*.055+fine*.07*fade);
 ALBEDO=mix(grass,white,paint);
 if(pile_pass){ALBEDO*=mix(.80,1.20,tip)*mix(.84,1.15,seed);NORMAL=normalize((VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz);}
 ROUGHNESS=clamp(.87+meso*.04,.80,.95);
 METALLIC=0.0;SPECULAR=.18;
 NORMAL_MAP=vec3(.5+fine*.09*fade,.5+meso*.04*fade,1.0);
 NORMAL_MAP_DEPTH=pile_pass ? 0.0 : .55;

}
""")
	var material := ShaderMaterial.new()
	material.resource_name = "MutedSyntheticPileWithInlaidWhiteFibres"
	material.shader = shader
	material.set_shader_parameter("pile_pass",pile_pass)
	return material

static func _metal() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "SatinOffWhitePowderCoatedGoal"
	material.albedo_color = Color(.77,.79,.75)
	material.metallic = .12
	material.roughness = .49
	return material

static func _rope() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "OffWhiteThreeMillimetreGoalRope"
	material.albedo_color = Color(.65,.67,.59)
	material.roughness = .95
	material.metallic = 0
	return material

static func _goal(root: Node3D, direction: float) -> void:
	var goal := Node3D.new()
	goal.name = "WestGoal" if direction<0 else "EastGoal"
	root.add_child(goal)
	goal.position.x = direction*17.0
	var frame := SurfaceTool.new()
	frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nets := SurfaceTool.new()
	nets.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	body.name = "AnchoredGoalFrameCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	goal.add_child(body)
	for side: float in [-1.0,1.0]:
		_frame_bar(frame,body,Vector3(0,0,side*GOAL_HALF),Vector3(0,GOAL_TOP,side*GOAL_HALF),.04)
		_frame_bar(frame,body,Vector3(0,.04,side*GOAL_HALF),Vector3(direction*1.05,.04,side*GOAL_HALF),.025)
		_frame_bar(frame,body,Vector3(0,GOAL_TOP,side*GOAL_HALF),Vector3(direction*.35,GOAL_TOP,side*GOAL_HALF),.022)
		_frame_bar(frame,body,Vector3(direction*.35,GOAL_TOP,side*GOAL_HALF),Vector3(direction*1.05,.04,side*GOAL_HALF),.022)
	_frame_bar(frame,body,Vector3(0,GOAL_TOP,-GOAL_HALF),Vector3(0,GOAL_TOP,GOAL_HALF),.04)
	_frame_bar(frame,body,Vector3(direction*1.05,.04,-GOAL_HALF),Vector3(direction*1.05,.04,GOAL_HALF),.025)
	_frame_bar(frame,body,Vector3(direction*.35,GOAL_TOP,-GOAL_HALF),Vector3(direction*.35,GOAL_TOP,GOAL_HALF),.022)
	_publish(goal,"PowderCoatedFrame",frame,_metal())
	# Back plane and side planes share every boundary; slight interior slack
	# fades to zero at frame attachments. Continuous cords, no opaque net sheets.
	for i: int in range(21):
		var t := float(i)/20.0
		_curve(nets,func(u: float) -> Vector3: return _net_back(direction,u,t))
	for i: int in range(32):
		var t := float(i)/31.0
		_curve(nets,func(u: float) -> Vector3: return _net_back(direction,t,u))
	for side: float in [-1.0,1.0]:
		for i: int in range(21):
			var t := float(i)/20.0
			_curve(nets,func(u: float) -> Vector3: return _net_side(direction,side,u,t))
		for i: int in range(12):
			var t := float(i)/11.0
			_curve(nets,func(u: float) -> Vector3: return _net_side(direction,side,t,u))
	for i: int in range(32):
		var t := float(i)/31.0
		_curve(nets,func(u: float) -> Vector3: return Vector3(direction*.35*u,GOAL_TOP-.016*sin(u*PI)*sin(t*PI),lerpf(-GOAL_HALF,GOAL_HALF,t)))
	for i: int in range(5):
		var t := float(i)/4.0
		_curve(nets,func(u: float) -> Vector3: return Vector3(direction*.35*t,GOAL_TOP-.016*sin(u*PI)*sin(t*PI),lerpf(-GOAL_HALF,GOAL_HALF,u)))
	_publish(goal,"AttachedSlackRopeNet",nets,_rope())
	_anchors(goal,direction)
	goal.set_meta("clear_width_m",3.0)
	goal.set_meta("clear_height_m",2.0)
	goal.set_meta("net_nonblocking",true)

static func _net_back(direction: float,u: float,v: float) -> Vector3:
	return Vector3(direction*(lerpf(1.05,.35,v)+.022*sin(u*PI)*sin(v*PI)),lerpf(.04,GOAL_TOP,v),lerpf(-GOAL_HALF,GOAL_HALF,u))

static func _net_side(direction: float,side: float,u: float,v: float) -> Vector3:
	return Vector3(direction*lerpf(1.05,.35,v)*u,lerpf(.04,GOAL_TOP,v),side*(GOAL_HALF+.012*sin(u*PI)*sin(v*PI)))

static func _curve(surface: SurfaceTool,at: Callable) -> void:
	for i: int in range(4):
		_tube(surface,at.call(float(i)/4),at.call(float(i+1)/4),ROPE_RADIUS,5)

static func _tube(surface: SurfaceTool,a: Vector3,b: Vector3,radius: float,sides: int) -> void:
	var delta := b-a
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = delta.length()
	cylinder.radial_segments = sides
	cylinder.rings = 0
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	surface.append_from(cylinder,0,Transform3D(Basis(Quaternion(Vector3.UP,delta.normalized())),(a+b)*.5))

static func _frame_bar(surface: SurfaceTool,body: StaticBody3D,a: Vector3,b: Vector3,radius: float) -> void:
	_tube(surface,a,b,radius,16)
	var collider := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = a.distance_to(b)
	collider.shape = cylinder
	collider.transform = Transform3D(Basis(Quaternion(Vector3.UP,(b-a).normalized())),(a+b)*.5)
	body.add_child(collider)

static func _publish(parent: Node3D,label: String,surface: SurfaceTool,material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = surface.commit()
	instance.material_override = material
	parent.add_child(instance)

static func _anchors(goal: Node3D,direction: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0,1.0]:
		for depth: float in [0.0,1.05]:
			var plate := BoxMesh.new()
			plate.size = Vector3(.13,.012,.14)
			surface.append_from(plate,0,Transform3D(Basis.IDENTITY,Vector3(direction*depth,.007,side*GOAL_HALF)))
			for x: float in [-.045,.045]:
				for z: float in [-.05,.05]:
					var bolt := CylinderMesh.new()
					bolt.top_radius = .008
					bolt.bottom_radius = .008
					bolt.height = .009
					bolt.radial_segments = 6
					bolt.rings = 0
					surface.append_from(bolt,0,Transform3D(Basis.IDENTITY,Vector3(direction*depth+x,.017,side*GOAL_HALF+z)))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.18,.20,.19)
	material.metallic = .65
	material.roughness = .65
	_publish(goal,"GroundAnchorPlates",surface,material)

static func _statistics(root: Node) -> Dictionary:
	var count := 0
	var surfaces := 0
	var triangles := 0
	# The 60 pile chunks share one mesh: its arrays (read back from the renderer)
	# are counted once and the same count is added per chunk, as before.
	var counted := {}
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		count+=1
		surfaces+=mesh.mesh.get_surface_count()
		var key := mesh.mesh.get_instance_id()
		if not counted.has(key):
			var mesh_triangles := 0
			for index: int in range(mesh.mesh.get_surface_count()):
				var arrays := mesh.mesh.surface_get_arrays(index)
				var indices := PackedInt32Array()
				if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
				mesh_triangles+=(indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
			counted[key] = mesh_triangles
		triangles+=int(counted[key])
	return {"mesh_instances":count,"draw_surfaces":surfaces,"triangles":triangles,"collision_bodies":root.find_children("*","StaticBody3D",true,false).size(),"collision_shapes":root.find_children("*","CollisionShape3D",true,false).size()}


static func _short_pile(root: Node3D) -> void:
	# Shared tile mesh, spatially culled at 11 m; blades taper to the material
	# between 4 and 8 m. No wind, physics, dynamic lights or alpha overdraw.
	var tile := Vector2(DECK.x/10.0,DECK.y/6.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 205017
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blade_count := 14000
	for index: int in range(blade_count):
		var x := rng.randf_range(-tile.x*.5+.012,tile.x*.5-.012)
		var z := rng.randf_range(-tile.y*.5+.012,tile.y*.5-.012)
		var angle := rng.randf()*TAU
		var width := rng.randf_range(.003,.005)
		var height := rng.randf_range(.016,.028)
		var across := Vector3(cos(angle),0,sin(angle))*width*.5
		var base := Vector3(x,0,z)
		var lean := Vector3(sin(angle),0,cos(angle))*height*.35
		var normal := Vector3(0,1,0)
		var colour := Color(rng.randf(),0,0,1)
		for vertex: int in range(3):
			surface.set_normal(normal);surface.set_color(colour)
			surface.set_uv(Vector2(float(vertex)*.5,1.0 if vertex==2 else 0.0))
			surface.add_vertex(base-across if vertex==0 else (base+across if vertex==1 else base+lean+Vector3.UP*height))
	surface.generate_tangents()
	surface.index()
	var mesh := surface.commit()
	mesh.surface_set_material(0,_turf_material(true))
	for x: int in range(10):
		for z: int in range(6):
			var chunk := MeshInstance3D.new()
			chunk.name = "ShortPile_%02d_%02d" % [x,z]
			chunk.mesh=mesh
			chunk.position=Vector3(-DECK.x*.5+(float(x)+.5)*tile.x,.002,-DECK.y*.5+(float(z)+.5)*tile.y)
			chunk.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk.visibility_range_end=11.0
			chunk.extra_cull_margin=.05
			root.add_child(chunk)
	root.set_meta("short_pile_budget",{"chunks":60,"shared_tile_triangles":blade_count,"total_instanced_triangles":blade_count*60,"height_m":[.016,.028],"fade_m":[4,8],"cull_m":11,"collisions":0})
