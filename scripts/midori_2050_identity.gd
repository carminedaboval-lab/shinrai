extends Node3D
## Real Meshy furniture and measured Midori 2050 finishes, in world metres.
## Original supplied meshes stay untouched; planters batch plants per rest garden.
const Budget = preload("res://scripts/shinrai_loading_budget.gd")
const IRIS = preload("res://assets/shinrai/parks/midori_park/models/plants/iris_japonica/iris_japonica_lod0.glb")
const PLAZA_CENTRE := Vector2(164,136)
@export var complete_plaza := true
@export var complete_entrance := true
@export var asset_root := "res://assets/shinrai/parks/midori_park/models/identity2050"
var asset_prototypes: Dictionary = {}
var installed := false
var park: Node3D
var report: Array[Dictionary] = []
var seats: Array[Dictionary] = []
var plant_report: Array[Dictionary] = []
var landscape_report: Array[Dictionary] = []
var approach_report: Array[Dictionary] = []
var materials: Dictionary = {}
var batches: Dictionary = {}
var batch_root: Node3D
var iris_source: Node3D
var shrub_source: Node3D
var fern_source: Node3D
var plant_batches: Dictionary = {}
var plant_batch_serial := 0
var canopy_arm_cuts: Array[Dictionary] = []
var plaza_floor_layers: Array[Dictionary] = []
var lamp_relocation: Dictionary = {}
var entrance_report: Dictionary = {}

const SURFACE_SHADER := """
shader_type spatial;
render_mode diffuse_burley;
uniform vec4 base_color : source_color = vec4(.2,.2,.2,1);
uniform float kind = 0.0;
varying vec3 local_p;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise3(vec3 p) {
 vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
 mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){local_p=VERTEX;}
void fragment(){
 float fine=noise3(local_p*95.0),macro=noise3(local_p*3.0);
 vec3 c=base_color.rgb;
 if(kind<.5){
  float grain=noise3(vec3(local_p.x*1.8,local_p.y*75.0,local_p.z*75.0));
  float line=sin(local_p.z*540.0+noise3(local_p*8.0)*4.0)*.5+.5;
  c*=.78+.23*grain+.08*line+.07*fine;ROUGHNESS=.58+.16*grain;
 } else if(kind<1.5){
  c*=.82+.19*macro+.16*fine;ROUGHNESS=.83+.10*fine;
 } else {
  vec2 grid=abs(fract(UV*vec2(42.0,18.0))-.5);
  float wire=step(.478,max(grid.x,grid.y));
  c=mix(c*(.84+.18*macro),vec3(.17,.22,.23),wire*.48);
  METALLIC=.64;ROUGHNESS=.32+.08*fine;
 }
 ALBEDO=c;
}
"""

func _ready() -> void:
	await Budget.wait_structure(get_parent())
	call_deferred("install")

func install() -> void:
	if installed: return
	park=get_parent()
	var gardens: Node=park.get_node("MidoriGardenSpots")
	while not gardens.installed: await get_tree().process_frame
	set_as_top_level(true)
	global_transform=Transform3D.IDENTITY
	_make_materials()
	iris_source=_asset_prototype("midori_2050_iris_clump.glb").duplicate()
	# Plain woodland foliage forms the low green mass between iris accents.
	# Keep an owned wrapper so the source root mesh is included when batching.
	shrub_source=Node3D.new()
	shrub_source.add_child(park.forest_floor_bush_prototypes[0].duplicate())
	fern_source=park.midnight_fern_prototype
	# The east court is the first completed area. Other pockets are enabled only
	# after its complete geometry, planting, lighting and circulation review.
	await _plaza_pocket("East",Vector2(190,147),true,"PlazaBench_02")
	if complete_plaza:
		await _plaza_pocket("West",Vector2(143,123),true,"")
		await _plaza_pocket("North",Vector2(164,110.8),false,"PlazaBench_03")
		await _plaza_pocket("Arrival",Vector2(142,149),false,"PlazaBench_01")
		_refine_plaza_finishes()
	if complete_entrance: await _entrance()
	_flush_plants()
	iris_source.free()
	shrub_source.free()
	for prototype: Node3D in asset_prototypes.values(): prototype.free()
	asset_prototypes.clear()
	installed=true
	print("MIDORI_2050_READY ",JSON.stringify({"pockets":report,"seats":seats.size(),"plantings":plant_report.size()}))

func _material(key: String,color: Color,roughness: float,metallic: float=0.0) -> void:
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=color;mat.roughness=roughness;mat.metallic=metallic
	materials[key]=mat

func _make_materials() -> void:
	var shader:=Shader.new();shader.code=SURFACE_SHADER
	for spec: Array in [["timber",Color("#ac7542"),0.0],["stone",Color("#4b504b"),1.0],["soil",Color("#262b22"),1.0],["solar",Color("#253e47"),2.0]]:
		var mat:=ShaderMaterial.new();mat.shader=shader
		mat.set_shader_parameter("base_color",spec[1]);mat.set_shader_parameter("kind",spec[2])
		materials[spec[0]]=mat
	_material("metal",Color("#293432"),.39,.72)
	_material("brass",Color("#8d8060"),.42,.65)
	_material("jade",Color("#538875"),.52,.3)
	_material("roofliner",Color("#5c6c65"),.56,.28)
	_material("warm",Color("#e6bf7f"),.48)
	var warm: StandardMaterial3D=materials.warm
	warm.emission_enabled=true;warm.emission=Color("#ffc87a")
	warm.emission_energy_multiplier=1.2 if park.is_night_mode else 0.0
	park.lamp_emissive_materials.append(warm)
	_material("ink",Color("#bdccad"),.82)

func _begin(group: Node3D) -> void:
	batch_root=group;batches={}

func _append(mesh: Mesh,transform: Transform3D,key: String) -> void:
	if not batches.has(key):
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[key]=surface
	(batches[key] as SurfaceTool).append_from(mesh,0,transform)

func _flush() -> void:
	for key: String in batches:
		var node:=MeshInstance3D.new();node.name="Finish_"+key
		node.mesh=(batches[key] as SurfaceTool).commit()
		node.material_override=materials[key]
		node.visibility_range_end=145;node.visibility_range_end_margin=12
		node.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if key=="warm": node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch_root.add_child(node)
	batches.clear()

func _box(pos: Vector3,size: Vector3,key: String,basis: Basis=Basis.IDENTITY) -> void:
	var mesh:=BoxMesh.new();mesh.size=size
	_append(mesh,Transform3D(basis,pos),key)

func _cylinder(pos: Vector3,radius: float,height: float,key: String) -> void:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius
	mesh.height=height;mesh.radial_segments=16
	_append(mesh,Transform3D(Basis.IDENTITY,pos),key)

func _bevel_slat(pos: Vector3,length: float,depth: float,thick: float,key: String,basis: Basis=Basis.IDENTITY) -> void:
	# Rounded cross-section gives the seat boards and capping a real eased edge.
	var ring:=PackedVector2Array()
	var radius:=minf(.012,minf(depth,thick)*.38)
	for corner: int in range(4):
		var a:=PI*.5*corner
		var centre:=Vector2((depth*.5-radius)*(1 if corner in [0,3] else -1),(thick*.5-radius)*(1 if corner in [0,1] else -1))
		for j: int in range(4):
			var theta:=a+PI*.5*float(j)/3.0
			ring.append(centre+Vector2(cos(theta),sin(theta))*radius)
	var s:=SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(ring.size()):
		var j: int=(i+1)%ring.size()
		var a:=Vector3(-length*.5,ring[i].y,ring[i].x)
		var b:=Vector3(length*.5,ring[i].y,ring[i].x)
		var c:=Vector3(length*.5,ring[j].y,ring[j].x)
		var d:=Vector3(-length*.5,ring[j].y,ring[j].x)
		_quad(s,d,c,b,a,Vector2.ZERO,Vector2(length,1))
		_triangle(s,Vector3(-length*.5,0,0),d,a)
		_triangle(s,Vector3(length*.5,0,0),b,c)
	s.generate_normals()
	_append(s.commit(),Transform3D(basis,pos),key)

func _triangle(s: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,uv_a: Vector2=Vector2.ZERO,uv_b: Vector2=Vector2.RIGHT,uv_c: Vector2=Vector2.ONE) -> void:
	s.set_uv(uv_a);s.add_vertex(a)
	s.set_uv(uv_b);s.add_vertex(b)
	s.set_uv(uv_c);s.add_vertex(c)

func _quad(s: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,uv_a: Vector2=Vector2.ZERO,uv_c: Vector2=Vector2.ONE) -> void:
	_triangle(s,a,b,c,uv_a,Vector2(uv_c.x,uv_a.y),uv_c)
	_triangle(s,a,c,d,uv_a,uv_c,Vector2(uv_a.x,uv_c.y))

func _ribbon(points: PackedVector3Array,width: float,thick: float,key: String) -> void:
	var s:=SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array]=[]
	for i: int in range(points.size()):
		var tangent: Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
		var side:=tangent.cross(Vector3.UP).normalized()*width*.5
		if side.length_squared()<.00001: side=Vector3.RIGHT*width*.5
		var up:=side.normalized().cross(tangent).normalized()*thick*.5
		var p: Vector3=points[i]
		rings.append(PackedVector3Array([p-side-up,p-side+up,p+side+up,p+side-up]))
	for i: int in range(points.size()-1):
		for j: int in range(4):
			var k: int=(j+1)%4
			_quad(s,rings[i][j],rings[i+1][j],rings[i+1][k],rings[i][k])
	_quad(s,rings[0][3],rings[0][2],rings[0][1],rings[0][0])
	var last: int=rings.size()-1
	_quad(s,rings[last][0],rings[last][1],rings[last][2],rings[last][3])
	s.generate_normals()
	_append(s.commit(),Transform3D.IDENTITY,key)

func _solid(parent: Node3D,label: String,pos: Vector3,size: Vector3,basis: Basis=Basis.IDENTITY) -> void:
	var body:=StaticBody3D.new();body.name=label
	body.collision_layer=1;body.collision_mask=1
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size
	shape.shape=box;body.add_child(shape);parent.add_child(body)
	body.transform=Transform3D(basis,pos)

func _ground(p: Vector2) -> float:
	# Read only the walkable layers, never a tree or a piece of furniture.
	var height: float=park.get_node("MidoriTerrain").height_at(p)
	if plaza_floor_layers.is_empty():
		for label: String in ["PlazaGroundingCourt","PlazaOuterStoneTerrace","PlazaMainStoneCourt","PlazaInnerDarkStoneRing","PlazaCenterpieceSocketCap_12mWorld"]:
			var floor_mesh:=park.find_child(label,true,false) as MeshInstance3D
			if floor_mesh==null: continue
			var bounds: AABB=floor_mesh.global_transform*floor_mesh.get_aabb()
			plaza_floor_layers.append({"centre":Vector2(bounds.get_center().x,bounds.get_center().z),"radius":Vector2(bounds.size.x,bounds.size.z)*.5,"height":bounds.end.y})
	for layer: Dictionary in plaza_floor_layers:
		var delta: Vector2=(p-layer.centre)/layer.radius
		if delta.length_squared()<=1.0: height=maxf(height,float(layer.height))
	return height

func _plaza_pocket(id: String,p: Vector2,canopy: bool,cache_id: String) -> void:
	var toward: Vector2=(PLAZA_CENTRE-p).normalized()
	if id=="Arrival": toward=Vector2(-.8,.6)
	await _rest_pocket(id,p,canopy,cache_id,toward,false)

func _rest_pocket(id: String,p: Vector2,canopy: bool,cache_id: String,toward: Vector2,paved: bool) -> void:
	var group:=Node3D.new();group.name="Plaza"+id+"RestGarden"
	add_child(group)
	group.position=Vector3(p.x,maxf(.136,_ground(p)+.002) if paved else _ground(p)+.002,p.y)
	group.rotation.y=atan2(toward.x,toward.y)
	if paved: _rest_pad(group,12.0 if canopy else 8.4,6.0 if canopy else 5.0)
	_begin(group)
	var count:=3 if canopy else 2
	var xs: Array=[-3.0,0.0,3.0] if canopy else [-1.65,1.65]
	for i: int in range(count):
		var bench_name:=cache_id if i==1 and not cache_id.is_empty() else "RestSeat_"+id+"_%02d"%i
		_bench(group,Vector3(xs[i],0,0),bench_name)
	_planter(group,Vector3(0,0,-1.25),Vector2(10.1 if canopy else 7.2,1.48),.57,id+"Back")
	for x: float in ([-4.65,-1.5,1.5,4.65] if canopy else [-3.35,0,3.35]):
		_planter(group,Vector3(x,0,.02),Vector2(.70,1.10),.56,id+"Front"+str(x))
	if canopy: _leaf_canopy(group)
	_leaf_badge(Vector3(4.65 if canopy else 3.35,.85,.585),.23)
	_flush()
	if canopy:
		_night_light(group,Vector3(-2.6,.27,.55),3.7,.66)
		_night_light(group,Vector3(2.6,.27,.55),3.7,.66)
		_night_light(group,Vector3(2.4,2.9,-.6),5,.46)
	else: _night_light(group,Vector3(0,.25,.55),4,.65)
	_retire_original(cache_id)
	_flush_plants(group.global_position)
	report.append({"id":id,"node":group.get_path(),"centre":p,"benches":count,"canopy":canopy,"front_open_depth_m":2.1,"width_m":10.8 if canopy else 7.9,"apron":group.get_meta("apron",{})})
	await Budget.checkpoint(park)

func _retire_original(cache_id: String) -> void:
	if cache_id.is_empty(): return
	var furniture:=park.find_child("LandmarkPlazaFurniture_3Benches_4PathLamps",true,false)
	if furniture==null: return
	var old:=furniture.get_node_or_null(NodePath(cache_id))
	if old!=null: old.free()
	var collision:=furniture.get_node_or_null(NodePath(cache_id.replace("PlazaBench_","PlazaBenchCollision_")))
	if collision!=null: collision.free()

func _refine_plaza_finishes() -> void:
	_relocate_foreground_lamp()
	# Quiet jade inlays replace the bright blue in this court alone.
	park.mat_plaza_inlay.albedo_color=Color("#588c77")
	park.mat_plaza_inlay.emission=Color("#619d82")
	# Leaf banners use the existing lamp poles, never extra posts in a walkway.
	var group:=Node3D.new();group.name="PlazaLeafWayfinding"
	add_child(group);_begin(group)
	for i: int in range(1,5):
		var lamp: Node3D=park.find_child("PlazaHaloLamp_%02d"%i,true,false)
		if lamp==null: continue
		for mi: MeshInstance3D in lamp.find_children("*","MeshInstance3D",true,false):
			for surface: int in range(mi.mesh.get_surface_count()):
				var material:=mi.get_active_material(surface) as StandardMaterial3D
				if material!=null and material.emission_enabled:
					var jade:=material.duplicate() as StandardMaterial3D
					jade.emission=Color("#95c4a7");mi.set_surface_override_material(surface,jade)
					park.lamp_emissive_materials.append(jade)
		for prefix: String in ["BlueHaloArea_","BlueSlitPathLine_"]:
			var light:=park.find_child(prefix+"%02d"%(i+10),true,false) as Light3D
			if light!=null: light.light_color=Color("#ffd5a4")
		var projection:=park.find_child("BlueSlitProjection_%02d"%(i+10),true,false) as Node3D
		if projection!=null:
			projection.remove_from_group("midori_night_effect");projection.hide()
		var p: Vector3=lamp.global_position+Vector3(.14,2.25,0)
		_box(p,Vector3(.32,.91,.025),"metal")
		_leaf_badge(p+Vector3(0,.05,.017),.24)
	_flush()

func _relocate_foreground_lamp() -> void:
	var lamp:=park.find_child("PlazaHaloLamp_01",true,false) as Node3D
	if lamp==null: return
	var before: Vector3=lamp.global_position
	var target:=Vector2(134,150)
	for candidate: Vector2 in [Vector2(134,150),Vector2(132,146),Vector2(132,140)]:
		if park._is_tree_spaced(Vector3(candidate.x/park.LAYOUT_SCALE,0,candidate.y/park.LAYOUT_SCALE),1.4):
			target=candidate;break
	var root:=Node3D.new();root.name="PlazaArrivalLampPerimeter"
	add_child(root)
	var moved: Array[String]=[]
	for label: String in ["PlazaHaloLamp_01","PlazaHaloLampCollision_01","BlueHaloArea_11","BlueSlitPathLine_11","BlueSlitProjection_11"]:
		var part:=park.find_child(label,true,false) as Node3D
		if part==null: continue
		part.reparent(root,true);moved.append(label)
	root.position=Vector3(target.x,park.get_node("MidoriTerrain").height_at(target),target.y)-before
	lamp_relocation={"from":before,"to":lamp.global_position,"parts":moved}

func _asset_prototype(filename: String) -> Node3D:
	if asset_prototypes.has(filename): return asset_prototypes[filename]
	var path: String=asset_root.path_join(filename)
	var model: Node3D
	if path.begins_with("res://"):
		model=(load(path) as PackedScene).instantiate()
	else:
		# Candidate review reads the exact staged GLB through Godot's native
		# importer. Production uses the installed imported PackedScene above.
		var document:=GLTFDocument.new();var state:=GLTFState.new()
		var error:=document.append_from_file(path,state)
		assert(error==OK,"Cannot read measured Midori asset: "+path)
		model=document.generate_scene(state)
	if filename=="midori_2050_leaf_canopy.glb": _glaze_canopy(model)
	asset_prototypes[filename]=model
	return model

func _glaze_canopy(model: Node3D) -> void:
	# Replace the ragged generated roof skin, preserving the real timber below
	# a smooth fitted underside. All construction is cached on this prototype.
	var source_mesh: MeshInstance3D=model.find_child("Midori2050_LeafCanopy",true,false) as MeshInstance3D
	assert(source_mesh!=null,"Missing source canopy support")
	var source:=source_mesh.get_active_material(0)
	var arrays: Array=source_mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var footprint:=PackedVector2Array()
	for p: Vector3 in vertices:
		if p.y>2.6: footprint.append(Vector2(p.x,p.z))
	# Broaden only the two tapered shoulders to shelter each complete bench.
	# Source bench bounds plus .425m allow smoothing while retaining >=.35m
	# drip margin. Bench Z is +.25 in canopy-local space; outer bounds stay fixed.
	for x: float in [-3.0,0.0,3.0]:
		for side_x: float in [-1.0,1.0]:
			for side_z: float in [-1.0,1.0]:
				footprint.append(Vector2(x+side_x*(1.125+.425),.25+side_z*(.40489003+.425)))
	var boundary:=_smooth_canopy_outline(Geometry2D.convex_hull(footprint))
	var glass:=StandardMaterial3D.new()
	glass.resource_name="MidoriCanopyClearGlass"
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color=Color(.78,.88,.94,.20)
	glass.roughness=.14;glass.metallic=0.0
	glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	var charcoal:=StandardMaterial3D.new()
	charcoal.resource_name="MidoriCanopyCharcoalFrame"
	charcoal.albedo_color=Color("#273432");charcoal.roughness=.42;charcoal.metallic=.25
	charcoal.cull_mode=BaseMaterial3D.CULL_DISABLED
	_prepare_canopy_arm_cuts(arrays)
	var support_report: Dictionary=_trim_canopy_support(source_mesh,arrays,source)
	for mi: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mi!=source_mesh: mi.free()
	var cover:=MeshInstance3D.new();cover.name="MidoriCanopySmoothGlass"
	cover.mesh=_smooth_canopy_glass(boundary);cover.material_override=glass
	cover.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(cover)
	var frame:=MeshInstance3D.new();frame.name="MidoriCanopyCleanFrame"
	frame.mesh=_clean_canopy_frame(boundary);frame.material_override=charcoal
	model.add_child(frame)
	var joints: Dictionary=_build_canopy_joints(model,arrays,boundary,charcoal)
	model.set_meta("midori_canopy_glass_policy","smooth_leaf_glass_rebuild_v3")
	model.set_meta("midori_canopy_rebuild",{"source_support":support_report,"outline_vertices":boundary.size(),"footprint_min":Vector2(-4.9,-2.5),"footprint_max":Vector2(4.9,2.5),"glass_aabb_position":cover.mesh.get_aabb().position,"glass_aabb_size":cover.mesh.get_aabb().size,"glass_rings":12,"support_trim_depth":.18,"perimeter_width":.08,"spar_width":.05,"frame_depth":.20,"repair_mesh_removed":true,"engineered_joints":joints})

func _canopy_roof_height(p: Vector2) -> float:
	# Robust quadratic fit to the supplied roof skin, in source local metres.
	return 3.41056761-.04316560*p.x+.24121471*p.y-.00280262*p.x*p.x-.01037093*p.x*p.y-.01122948*p.y*p.y

func _canopy_roof_normal(p: Vector2) -> Vector3:
	var dx: float=-.04316560-.00560524*p.x-.01037093*p.y
	var dz: float=.24121471-.01037093*p.x-.02245896*p.y
	return Vector3(-dx,1,-dz).normalized()

func _smooth_canopy_outline(hull: PackedVector2Array) -> PackedVector2Array:
	if hull[0].is_equal_approx(hull[-1]): hull.remove_at(hull.size()-1)
	var perimeter:=0.0
	for i: int in range(hull.size()): perimeter+=hull[i].distance_to(hull[(i+1)%hull.size()])
	var outline:=PackedVector2Array()
	var edge:=0;var traversed:=0.0
	for i: int in range(48):
		var target: float=perimeter*float(i)/48.0
		var length: float=hull[edge].distance_to(hull[(edge+1)%hull.size()])
		while traversed+length<target:
			traversed+=length;edge+=1
			length=hull[edge].distance_to(hull[(edge+1)%hull.size()])
		outline.append(hull[edge].lerp(hull[(edge+1)%hull.size()],(target-traversed)/maxf(length,.000001)))
	for iteration: int in range(2):
		var smooth:=PackedVector2Array()
		for i: int in range(outline.size()):
			var next: Vector2=outline[(i+1)%outline.size()]
			smooth.append(outline[i]*.75+next*.25);smooth.append(outline[i]*.25+next*.75)
		outline=smooth
	var lo:=Vector2(INF,INF);var hi:=Vector2(-INF,-INF)
	for p: Vector2 in outline: lo=lo.min(p);hi=hi.max(p)
	for i: int in range(outline.size()): outline[i]=(outline[i]-lo)/(hi-lo)*Vector2(9.8,5.0)+Vector2(-4.9,-2.5)
	return outline

func _trim_canopy_support(mi: MeshInstance3D,arrays: Array,source: Material) -> Dictionary:
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var support:=SurfaceTool.new();support.begin(Mesh.PRIMITIVE_TRIANGLES)
	var removed:=0;var clipped:=0;var retained:=0
	for triangle: int in range(0,indices.size(),3):
		var polygon: Array[Dictionary]=[]
		for corner: int in range(3):
			var i: int=indices[triangle+corner]
			polygon.append({"p":vertices[i],"n":normals[i],"uv":uvs[i]})
		var result: Array[Dictionary]=[]
		for edge: int in range(3):
			var a: Dictionary=polygon[edge];var b: Dictionary=polygon[(edge+1)%3]
			var a_in: bool=_canopy_support_inside(a.p)
			var b_in: bool=_canopy_support_inside(b.p)
			if a_in: result.append(a)
			if a_in!=b_in:
				var low:=0.0;var high:=1.0
				for step: int in range(14):
					var middle: float=(low+high)*.5
					if _canopy_support_inside((a.p as Vector3).lerp(b.p,middle))==a_in: low=middle
					else: high=middle
				var t: float=(low+high)*.5
				result.append({"p":(a.p as Vector3).lerp(b.p,t),"n":(a.n as Vector3).lerp(b.n,t).normalized(),"uv":(a.uv as Vector2).lerp(b.uv,t)})
		if result.size()<3: removed+=1;continue
		if result.size()!=3 or not (_canopy_support_inside(polygon[0].p) and _canopy_support_inside(polygon[1].p) and _canopy_support_inside(polygon[2].p)): clipped+=1
		for fan: int in range(1,result.size()-1):
			for row: Dictionary in [result[0],result[fan],result[fan+1]]:
				support.set_normal(row.n);support.set_uv(row.uv);support.add_vertex(row.p)
			retained+=1
	support.generate_tangents()
	var support_mesh:=support.commit();support_mesh.surface_set_material(0,source)
	mi.mesh=support_mesh
	return {"original_triangles":indices.size()/3,"removed_triangles":removed,"clipped_source_triangles":clipped,"retained_support_triangles":retained}

func _canopy_support_inside(p: Vector3) -> bool:
	if p.y>_canopy_roof_height(Vector2(p.x,p.z))-.18: return false
	if p.y<1.8 or canopy_arm_cuts.is_empty(): return true
	var joint: int=_nearest_canopy_arm(Vector2(p.x,p.z))
	return (p-(canopy_arm_cuts[joint].origin as Vector3)).dot(canopy_arm_cuts[joint].axis)<=0.0

func _nearest_canopy_arm(p: Vector2) -> int:
	var nearest:=0;var distance:=INF
	for i: int in range(canopy_arm_cuts.size()):
		var candidate: float=p.distance_squared_to(canopy_arm_cuts[i].landmark)
		if candidate<distance: distance=candidate;nearest=i
	return nearest

func _prepare_canopy_arm_cuts(arrays: Array) -> void:
	var centres: Array[Vector2]=[Vector2(4.037,-.462),Vector2(.491,-1.054),Vector2(2.496,-.175),Vector2(1.252,-2.069),Vector2(3.104,-1.695)]
	var upper: Array[PackedVector2Array]=_canopy_contact_sections(arrays,.18,centres)
	var lower: Array[PackedVector2Array]=_canopy_contact_sections(arrays,.38,centres)
	canopy_arm_cuts.clear()
	for i: int in range(centres.size()):
		var first:=Vector3.ZERO;var second:=Vector3.ZERO
		for point: Vector2 in upper[i]: first+=Vector3(point.x,_canopy_roof_height(point)-.18,point.y)
		for point: Vector2 in lower[i]: second+=Vector3(point.x,_canopy_roof_height(point)-.38,point.y)
		first/=float(upper[i].size());second/=float(lower[i].size())
		var axis: Vector3=(first-second).normalized()
		var u: Vector3=axis.cross(Vector3.UP).normalized()
		if u.length_squared()<.01: u=Vector3.RIGHT
		var v: Vector3=axis.cross(u).normalized()
		canopy_arm_cuts.append({"landmark":centres[i],"origin":second,"axis":axis,"u":u,"v":v})

func _smooth_canopy_glass(boundary: PackedVector2Array) -> ArrayMesh:
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uvs:=PackedVector2Array();var indices:=PackedInt32Array()
	var centre:=Vector2.ZERO
	for p: Vector2 in boundary: centre+=p
	centre/=float(boundary.size())
	vertices.append(Vector3(centre.x,_canopy_roof_height(centre),centre.y));normals.append(_canopy_roof_normal(centre));uvs.append(centre)
	for ring: int in range(1,13):
		for p: Vector2 in boundary:
			var point: Vector2=centre.lerp(p,float(ring)/12.0)
			vertices.append(Vector3(point.x,_canopy_roof_height(point),point.y));normals.append(_canopy_roof_normal(point));uvs.append(point)
	var count: int=boundary.size()
	for i: int in range(count): indices.append_array(PackedInt32Array([0,1+(i+1)%count,1+i]))
	for ring: int in range(1,12):
		for i: int in range(count):
			var a: int=1+(ring-1)*count+i;var b: int=1+(ring-1)*count+(i+1)%count;var c: int=1+ring*count+i;var d: int=1+ring*count+(i+1)%count
			indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _clean_canopy_frame(boundary: PackedVector2Array) -> ArrayMesh:
	var frame:=SurfaceTool.new();frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	var perimeter:=PackedVector3Array()
	for p: Vector2 in boundary: perimeter.append(Vector3(p.x,_canopy_roof_height(p)+.018,p.y))
	perimeter.append(perimeter[0]);_canopy_frame_beam(frame,perimeter,.08,.20)
	for x: float in [-3.2,-1.6,0.0,1.6,3.2]: _canopy_grid_spar(frame,boundary,x,true)
	for z: float in [-.85,.80]: _canopy_grid_spar(frame,boundary,z,false)
	frame.generate_normals()
	return frame.commit()

func _canopy_grid_spar(frame: SurfaceTool,boundary: PackedVector2Array,value: float,along_z: bool) -> void:
	var intersections: Array[float]=[]
	for i: int in range(boundary.size()):
		var a: Vector2=boundary[i];var b: Vector2=boundary[(i+1)%boundary.size()]
		var first: float=a.x if along_z else a.y;var second: float=b.x if along_z else b.y
		if (first<=value and second>value) or (second<=value and first>value):
			var p: Vector2=a.lerp(b,(value-first)/(second-first));intersections.append(p.y if along_z else p.x)
	if intersections.size()<2: return
	intersections.sort()
	var path:=PackedVector3Array()
	for i: int in range(33):
		var distance: float=lerpf(intersections[0],intersections[-1],float(i)/32.0)
		var p:=Vector2(value,distance) if along_z else Vector2(distance,value)
		path.append(Vector3(p.x,_canopy_roof_height(p)+.018,p.y))
	_canopy_frame_beam(frame,path,.05,.20)

func _build_canopy_joints(model: Node3D,arrays: Array,boundary: PackedVector2Array,charcoal: Material) -> Dictionary:
	var names: Array[String]=["RightArch","LeftArch","CentralProng","FrontArm","SideArm"]
	var sections: Array[PackedVector2Array]=_canopy_perpendicular_sections(arrays)
	var caps:=SurfaceTool.new();caps.begin(Mesh.PRIMITIVE_TRIANGLES)
	var metal:=SurfaceTool.new();metal.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fasteners:=SurfaceTool.new();fasteners.begin(Mesh.PRIMITIVE_TRIANGLES)
	var head:=CylinderMesh.new();head.top_radius=.014;head.bottom_radius=.014;head.height=.010;head.radial_segments=6
	var seat:=BoxMesh.new();seat.size=Vector3(.14,.16,.045)
	var reports: Array[Dictionary]=[]
	for joint: int in range(names.size()):
		var cut: Dictionary=canopy_arm_cuts[joint]
		var origin: Vector3=cut.origin;var axis: Vector3=cut.axis;var u: Vector3=cut.u;var v: Vector3=cut.v
		assert(sections[joint].size()>=3,"Missing perpendicular arm cross-section")
		var cap: PackedVector2Array=Geometry2D.convex_hull(sections[joint])
		if cap[0].is_equal_approx(cap[-1]): cap.remove_at(cap.size()-1)
		var centre:=Vector2.ZERO;var lo:=Vector2(INF,INF);var hi:=Vector2(-INF,-INF)
		for point: Vector2 in cap: centre+=point;lo=lo.min(point);hi=hi.max(point)
		centre/=float(cap.size())
		var mounting: Vector3=origin+u*centre.x+v*centre.y
		var cap_centre: Vector3=mounting+axis*.002
		for i: int in range(cap.size()):
			var first: Vector2=cap[i];var second: Vector2=cap[(i+1)%cap.size()]
			for point: Vector3 in [cap_centre,origin+u*second.x+v*second.y+axis*.002,origin+u*first.x+v*first.y+axis*.002]: caps.add_vertex(point)
		metal.append_from(seat,0,Transform3D(Basis(u,v,axis),mounting+axis*.026))
		var connection: Dictionary=_connect_canopy_arm(metal,mounting+axis*.045,boundary)
		for x: float in [-.045,.045]:
			for y: float in [-.05,.05]:
				var position: Vector3=mounting+u*x+v*y+axis*.053
				fasteners.append_from(head,0,Transform3D(Basis(Quaternion(Vector3.UP,axis)),position))
		reports.append({"id":names[joint],"cut_centroid_xz":cut.landmark,"terminal_finish":"perpendicular_timber_end_with_compact_seat","cap_plane_origin":origin,"cap_plane_axis":axis,"cap_section_size":hi-lo,"cap_closed":true,"metal_seat_size":seat.size,"bolt_heads":4,"connection":connection})
	caps.generate_normals();metal.generate_normals();fasteners.generate_normals()
	var wood:=StandardMaterial3D.new();wood.resource_name="MidoriCanopyTimberEndgrain";wood.albedo_color=Color("#9f784d");wood.roughness=.68;wood.cull_mode=BaseMaterial3D.CULL_DISABLED
	var cap_mesh:=caps.commit();var seat_mesh:=metal.commit();var joined:=ArrayMesh.new()
	joined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,cap_mesh.surface_get_arrays(0));joined.surface_set_material(0,wood);joined.surface_set_name(0,"TimberEndgrainCaps")
	joined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,seat_mesh.surface_get_arrays(0));joined.surface_set_material(1,charcoal);joined.surface_set_name(1,"CompactFrameSeats")
	var shoes:=MeshInstance3D.new();shoes.name="MidoriCanopyFittedJoints";shoes.mesh=joined;model.add_child(shoes)
	var steel:=StandardMaterial3D.new();steel.resource_name="MidoriCanopyJointSteel";steel.albedo_color=Color("#77817e");steel.metallic=.75;steel.roughness=.38
	var bolts:=MeshInstance3D.new();bolts.name="MidoriCanopyJointFasteners";bolts.mesh=fasteners.commit();bolts.material_override=steel;model.add_child(bolts)
	return {"count":reports.size(),"contacts":reports,"source_contour_fit":true,"joint_family":"arm_aligned_caps_and_frame_links"}

func _canopy_perpendicular_sections(arrays: Array) -> Array[PackedVector2Array]:
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var sections: Array[PackedVector2Array]=[]
	for cut: Dictionary in canopy_arm_cuts: sections.append(PackedVector2Array())
	for joint: int in range(canopy_arm_cuts.size()):
		var cut: Dictionary=canopy_arm_cuts[joint]
		var origin: Vector3=cut.origin;var axis: Vector3=cut.axis
		for triangle: int in range(0,indices.size(),3):
			for edge: int in range(3):
				var a: Vector3=vertices[indices[triangle+edge]];var b: Vector3=vertices[indices[triangle+(edge+1)%3]]
				var first: float=(a-origin).dot(axis);var second: float=(b-origin).dot(axis)
				if (first<=0)==(second<=0): continue
				var point: Vector3=a.lerp(b,first/(first-second))
				if point.y<1.8 or point.y>_canopy_roof_height(Vector2(point.x,point.z))-.18: continue
				if _nearest_canopy_arm(Vector2(point.x,point.z))!=joint: continue
				var relative: Vector3=point-origin
				sections[joint].append(Vector2(relative.dot(cut.u),relative.dot(cut.v)))
	return sections

func _connect_canopy_arm(metal: SurfaceTool,start: Vector3,boundary: PackedVector2Array) -> Dictionary:
	var best:=INF;var finish:=start
	for x: float in [-3.2,-1.6,0.0,1.6,3.2]:
		var point:=Vector2(x,start.z)
		if not Geometry2D.is_point_in_polygon(point,boundary): continue
		var target:=Vector3(point.x,_canopy_roof_height(point)-.10,point.y)
		if start.distance_to(target)<best: best=start.distance_to(target);finish=target
	for z: float in [-.85,.80]:
		var point:=Vector2(start.x,z)
		if not Geometry2D.is_point_in_polygon(point,boundary): continue
		var target:=Vector3(point.x,_canopy_roof_height(point)-.10,point.y)
		if start.distance_to(target)<best: best=start.distance_to(target);finish=target
	var link:=CylinderMesh.new();link.top_radius=.035;link.bottom_radius=.035;link.height=best+.025;link.radial_segments=12
	var direction: Vector3=(finish-start).normalized()
	metal.append_from(link,0,Transform3D(Basis(Quaternion(Vector3.UP,direction)),(start+finish)*.5))
	return {"kind":"arm_aligned_frame_link","start_point":start,"end_point":finish,"length_m":best,"radius_m":.035,"overlap_m":.0125}

func _canopy_contact_sections(arrays: Array,depth: float,centres: Array[Vector2]) -> Array[PackedVector2Array]:
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var sections: Array[PackedVector2Array]=[]
	for centre: Vector2 in centres: sections.append(PackedVector2Array())
	var signed:=PackedFloat32Array()
	for point: Vector3 in vertices: signed.append(point.y-_canopy_roof_height(Vector2(point.x,point.z))+depth)
	for triangle: int in range(0,indices.size(),3):
		for edge: int in range(3):
			var a: int=indices[triangle+edge];var b: int=indices[triangle+(edge+1)%3]
			if (signed[a]<=0)==(signed[b]<=0): continue
			var low:=0.0;var high:=1.0
			for step: int in range(14):
				var middle: float=(low+high)*.5
				var point: Vector3=vertices[a].lerp(vertices[b],middle)
				var inside: bool=point.y<=_canopy_roof_height(Vector2(point.x,point.z))-depth
				if inside==(signed[a]<=0): low=middle
				else: high=middle
			var point: Vector3=vertices[a].lerp(vertices[b],(low+high)*.5)
			var xz:=Vector2(point.x,point.z);var nearest:=0;var distance:=INF
			for i: int in range(centres.size()):
				var candidate: float=xz.distance_squared_to(centres[i])
				if candidate<distance: distance=candidate;nearest=i
			sections[nearest].append(xz)
	return sections

func _canopy_frame_beam(surface: SurfaceTool,path: PackedVector3Array,width: float,depth: float) -> void:
	var rings: Array[PackedVector3Array]=[]
	for i: int in range(path.size()):
		var tangent: Vector3=path[mini(i+1,path.size()-1)]-path[maxi(i-1,0)]
		var side:=Vector3(-tangent.z,0,tangent.x).normalized()*width*.5
		rings.append(PackedVector3Array([path[i]+side,path[i]-side,path[i]-side-Vector3.UP*depth,path[i]+side-Vector3.UP*depth]))
	for i: int in range(path.size()-1):
		for face: int in range(4):
			var next: int=(face+1)%4
			for p: Vector3 in [rings[i][face],rings[i+1][face],rings[i][next],rings[i][next],rings[i+1][face],rings[i+1][next]]: surface.add_vertex(p)

func _asset(group: Node3D,filename: String,pos: Vector3,label: String) -> Node3D:
	# Clone the rebuilt canopy tree as it stands, without reinstantiating the
	# imported PackedScene and resurrecting its deliberately removed roof mesh.
	var prototype:=_asset_prototype(filename)
	var flags: int=7 if filename=="midori_2050_leaf_canopy.glb" else 15
	var model:=prototype.duplicate(flags) as Node3D
	model.name=label;model.position=pos;group.add_child(model)
	for mi: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		mi.visibility_range_end=145;mi.visibility_range_end_margin=12
		mi.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return model

func _bench(group: Node3D,pos: Vector3,label: String) -> void:
	var anchor:=Node3D.new();anchor.name=label;anchor.position=pos;group.add_child(anchor)
	_asset(anchor,"midori_2050_timber_bench.glb",Vector3.ZERO,"MeshyTimberBench")
	# The Meshy model has a real stone plinth. Match its solid base, raked back
	# and arms, rather than filling the entire silhouette with one box.
	_solid(anchor,"SeatCollision",Vector3(0,.235,.015),Vector3(2.23,.46,.77))
	_solid(anchor,"BackCollision",Vector3(0,.72,-.29),Vector3(2.08,.48,.13),Basis(Vector3.RIGHT,-.18))
	for x: float in [-1.065,1.065]:
		_solid(anchor,"SideFrame",Vector3(x,.355,.015),Vector3(.12,.70,.78))
	_box(pos+Vector3(0,.390,.398),Vector3(1.96,.012,.009),"warm")
	seats.append({"name":label,"node":anchor.get_path(),"world_position":anchor.global_position,"seat_height_m":.46,"width_m":2.25,"facing":group.global_basis.z,"asset":"midori_2050_timber_bench.glb"})

func _planter(group: Node3D,pos: Vector3,size: Vector2,height: float,id: String) -> void:
	# Rear beds repeat measured Meshy stone shells in useful construction
	# lengths. Foreground divider modules retain their exact .70 x 1.10m size.
	var pieces:=maxi(1,ceili(size.x/3.4))
	var width: float=size.x/float(pieces)
	for piece: int in range(pieces):
		var point:=pos+Vector3(-size.x*.5+width*(float(piece)+.5),0,0)
		var rear: bool=width>1.0
		var shell:=_asset(group,"midori_2050_rear_planter.glb" if rear else "midori_2050_planter.glb",point,"MeshyPlanter_"+id+"_%02d"%piece)
		shell.scale=Vector3((width-.018)/(3.35 if rear else .70),height/(.57 if rear else .56),size.y/(1.48 if rear else 1.10))
		var diffuser:=shell.find_child("MidoriRearPlanterLightDiffuser" if rear else "MidoriPlanterLightDiffuser",true,false) as MeshInstance3D
		if diffuser!=null: diffuser.set_surface_override_material(0,materials.warm)
	_solid(group,"Planter_"+id,pos+Vector3(0,height*.5,0),Vector3(size.x,height,size.y))
	var count:=maxi(3,int(size.x*size.y*3.0))
	for i: int in range(count):
		var x: float=(fmod(float(i)*.61803398875,1.0)-.5)*(size.x-.32)
		var z: float=(fmod(float(i)*.41421356237,1.0)-.5)*(size.y-.31)
		var point:=pos+Vector3(x,height-.045,z)
		# Leave the generated timber column shoe and root clear of foliage.
		if id.ends_with("Back") and Vector2(point.x,point.z).distance_to(Vector2(2.2115,-1.7427))<.65: continue
		# Keep slot IDs, soil positions and the column clearance unchanged.
		# One iris per four slots breaks up the continuous band above the seats.
		var flowering: bool=i%4==0
		var source: Node3D=iris_source if flowering else (shrub_source if i%2==0 else fern_source)
		var rear_bed: bool=size.x>1.0
		var green_height: float=.53 if rear_bed else .37
		var green_variation: float=.05 if rear_bed else .03
		var h: float=(.40+.045*sin(float(i)*1.7)) if flowering else (green_height+green_variation*sin(float(i)*2.3))
		# Broaden only low divider greens, keeping rear foliage off the seats.
		var spread: float=1.15 if not flowering and not rear_bed else 1.0
		_add_plant(group,source,point,h,float(i)*2.4,id+"_%02d"%i,flowering,spread)

func _add_plant(group: Node3D,source: Node3D,p: Vector3,height: float,yaw: float,id: String,flowering: bool,horizontal_multiplier: float=1.0) -> void:
	var bounds: AABB=park._vegetation_visual_bounds(source).bounds
	var scale_value: float=height/maxf(.001,bounds.size.y)
	var centre:=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	var plant_scale:=Vector3(scale_value*horizontal_multiplier,scale_value,scale_value*horizontal_multiplier)
	var xf:=Transform3D(Basis(Vector3.UP,yaw).scaled(plant_scale),p)
	xf.origin-=xf.basis*centre
	for mi: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		if mi.mesh==null: continue
		var relative: Transform3D=source.transform.affine_inverse()*_local_to_root(mi,source)
		var key:=str(mi.mesh.get_instance_id())
		if not plant_batches.has(key): plant_batches[key]={"mesh":mi.mesh,"transforms":[],"overrides":_overrides(mi)}
		plant_batches[key].transforms.append(group.global_transform*xf*relative)
	for child: MultiMeshInstance3D in source.find_children("*","MultiMeshInstance3D",true,false):
		var mm:=child.multimesh
		if mm==null: continue
		var relative:=source.transform.affine_inverse()*_local_to_root(child,source)
		var key:=str(mm.mesh.get_instance_id())
		if not plant_batches.has(key): plant_batches[key]={"mesh":mm.mesh,"transforms":[],"overrides":[]}
		for i: int in range(mm.instance_count): plant_batches[key].transforms.append(group.global_transform*xf*relative*mm.get_instance_transform(i))
	plant_report.append({"id":id,"height_m":height,"flower":flowering,"position":group.to_global(p)})

func _local_to_root(node: Node3D,root_node: Node3D) -> Transform3D:
	var transform:=node.transform
	var cursor:=node.get_parent()
	while cursor is Node3D and cursor!=root_node:
		transform=(cursor as Node3D).transform*transform;cursor=cursor.get_parent()
	return root_node.transform*transform

func _overrides(node: MeshInstance3D) -> Array:
	var result: Array=[]
	for i: int in range(node.mesh.get_surface_count()): result.append(node.get_active_material(i))
	return result

func _flush_plants(origin: Vector3=Vector3.ZERO) -> void:
	for key: String in plant_batches:
		var row: Dictionary=plant_batches[key]
		var node:=MultiMeshInstance3D.new();node.name="PocketFlowerDrift_%02d"%plant_batch_serial
		var mesh: Mesh=row.mesh.duplicate()
		for i: int in range(row.overrides.size()): mesh.surface_set_material(i,row.overrides[i])
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh
		mm.instance_count=row.transforms.size()
		for i: int in range(mm.instance_count):
			var xf: Transform3D=row.transforms[i]
			xf.origin-=origin;mm.set_instance_transform(i,xf)
		node.multimesh=mm;node.visibility_range_end=75;node.visibility_range_end_margin=8
		node.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.position=origin;add_child(node);plant_batch_serial+=1
	plant_batches.clear()

func _leaf_canopy(group: Node3D) -> void:
	var canopy:=_asset(group,"midori_2050_leaf_canopy.glb",Vector3(0,0,-.25),"MeshyLeafCanopy")
	# The measured derivative's real steel shoe is at (2.2115, 0, -1.4927).
	# Keep the low column collision precise; the roof remains overhead.
	var body:=StaticBody3D.new();body.name="CanopyColumnCollision";group.add_child(body)
	var shape:=CollisionShape3D.new();var cap:=CapsuleShape3D.new()
	cap.radius=.31;cap.height=2.55;shape.shape=cap;body.add_child(shape)
	body.position=Vector3(2.2115,1.275,-1.7427)
	var roof_body:=StaticBody3D.new();roof_body.name="CanopyRoofCollision";group.add_child(roof_body)
	var upper:=PackedVector3Array()
	for mi: MeshInstance3D in canopy.find_children("*","MeshInstance3D",true,false):
		for i: int in range(mi.mesh.get_surface_count()):
			var vertices: PackedVector3Array=mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var point: Vector3=group.to_local(mi.to_global(vertex))
				if point.y>3.25: upper.append(point)
	if not upper.is_empty():
		var roof_shape:=CollisionShape3D.new();var hull:=ConvexPolygonShape3D.new();hull.points=upper;roof_shape.shape=hull;roof_body.add_child(roof_shape)

func _leaf_badge(pos: Vector3,size: float) -> void:
	_box(pos,Vector3(size*1.6,size*2.0,.025),"metal")
	var curve:=PackedVector3Array()
	for i: int in range(17):
		var t:=float(i)/16.0
		curve.append(pos+Vector3((t-.5)*size*.72,(t-.5)*size*1.5,.019))
	_ribbon(curve,.016,.010,"jade")
	for side: float in [-1,1]:
		for j: int in range(1,5):
			var t:=float(j)/6.0
			var p:=pos+Vector3((t-.5)*size*.72,(t-.5)*size*1.5,.021)
			_ribbon(PackedVector3Array([p,p+Vector3(side*size*.28,size*.13,.002)]),.014,.008,"jade")

func _night_light(group: Node3D,pos: Vector3,distance: float,energy: float) -> void:
	var light:=OmniLight3D.new();light.name="ShieldedWarmLight"
	light.position=pos;light.light_color=Color("#ffcf94");light.light_energy=energy
	light.omni_range=distance;light.omni_attenuation=1.6;light.shadow_enabled=false
	light.light_volumetric_fog_energy=0;light.distance_fade_enabled=true
	light.distance_fade_begin=32;light.distance_fade_length=10
	group.add_child(light);light.add_to_group("midori_night_effect");light.visible=park.is_night_mode

func _entrance() -> void:
	# These beds sit behind the north edge of the plaza branch. The main
	# south/lake walk and eastbound path remain continuous in front of them.
	await _rest_pocket("Entrance",Vector2(8,153.8),true,"",Vector2(0,1),true)
	await _rest_pocket("LakeApproach",Vector2(-27.5,142.1),false,"",Vector2(.832,-.555),true)
	var props: Node=park.get_node("MidoriParkProps")
	while not props.installed: await get_tree().process_frame
	var original: Node3D=props.get_node_or_null("MainInformationBoard")
	var original_position:=Vector3(-14,0,158)
	if original!=null:
		original_position=original.global_position;original.free()
	var socket:=Node3D.new();socket.name="SouthGateWayfinding";add_child(socket)
	socket.position=Vector3(-14.8,_ground(Vector2(-14.8,158))+.002,158)
	socket.rotation.y=.20
	var model:=_asset(socket,"midori_2050_totem.glb",Vector3.ZERO,"MainInformationBoard")
	var panel:=model.find_child("MidoriEInkPanel",true,false) as MeshInstance3D
	assert(panel!=null,"Measured totem display missing")
	var ink:=StandardMaterial3D.new();ink.albedo_texture=_park_map();ink.albedo_color=Color(.54,.59,.52)
	ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ink.roughness=.92
	panel.set_surface_override_material(0,ink)
	_label(socket,"MIDORI PARK",Vector3(0,1.85,.096),.00115,48,Color("#d8e5c9"))
	_label(socket,"SOUTH GATE",Vector3(0,1.48,.091),.00095,46,Color("#14291c"))
	_label(socket,"100 m",Vector3(-.10,.845,.091),.00083,34,Color("#14291c"))
	_label(socket,"YOU ARE HERE",Vector3(0,.765,.091),.00088,34,Color("#754023"))
	_label(socket,"SHINRAI / 2050",Vector3(0,.64,.091),.00092,38,Color("#14291c"))
	_label(socket,"LAKE WALK   PLAZA",Vector3(0,.575,.091),.00089,32,Color("#14291c"))
	_begin(socket);_leaf_badge(Vector3(0,2.015,.10),.055);_flush()
	_solid(socket,"TotemCollision",Vector3(0,1.05,0),Vector3(.74,2.10,.18))
	_night_light(socket,Vector3(0,1.6,.28),2,.20)
	entrance_report={"original_board":original_position,"totem":socket.global_position,"display":"MidoriEInkPanel","map":"Actual production park route constants and lake contour","main_walk_clear_width_m":4.0}
	await _blend_entrance_landscape()
	await _build_south_approach()

func _build_south_approach() -> void:
	var terrain: Node=park.get_node("MidoriTerrain")
	var entrance:=get_node("PlazaEntranceRestGarden") as Node3D
	var obstacles: Array[Rect2]=_entrance_landscape_obstacles(Vector3(-12,0,149))
	var paving: Array[PackedVector2Array]=[]
	for node: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		if node.name!="MineralRestApron" and node.name!="FlushAccessThreshold": continue
		var box: AABB=node.get_aabb();var points:=PackedVector2Array()
		for corner: int in range(8):
			var world: Vector3=node.global_transform*box.get_endpoint(corner)
			points.append(Vector2(world.x,world.z))
		paving.append(Geometry2D.convex_hull(points))
	var sources: Dictionary={"shrub":shrub_source,"fern":fern_source}
	var geometry: Dictionary={}
	for key: String in sources: geometry[key]=park._vegetation_visual_bounds(sources[key]).bounds
	var rocks: Array[Node3D]=[]
	for i: int in range(6):
		var rock: Node3D=(load("res://assets/shinrai/parks/midori_park/models/island_nature/rock_%02d.glb"%i) as PackedScene).instantiate()
		rocks.append(rock);sources["rock_%02d"%i]=rock;geometry["rock_%02d"%i]=park._vegetation_visual_bounds(rock).bounds
	var occupied: Array[Dictionary]=[]
	for bed: Dictionary in landscape_report:
		for plant: Dictionary in bed.plants: occupied.append({"p":Vector2(plant.position.x,plant.position.z),"radius":plant.visual_radius_m})
	var beds: Array[Dictionary]=[
		{"id":"ArrivalEast","group":"Arrival","area":Rect2(-4.5,148,9,5.5),"stones":1},
		{"id":"ArrivalWest","group":"Arrival","area":Rect2(-14.5,156.5,9,4.5),"stones":1},
		{"id":"MiddleEast","group":"Middle","area":Rect2(-13.5,142,7,7),"stones":1},
		{"id":"MiddleWest","group":"Middle","area":Rect2(-25.5,148,7,6),"stones":1},
		{"id":"LakeNorth","group":"Destination","area":Rect2(-33,146,9,5),"stones":2},
		{"id":"LakeSouth","group":"Destination","area":Rect2(-29,134.5,8,4),"stones":2}]
	for i: int in range(beds.size()):
		_south_approach_drift(beds[i],i,entrance,sources,geometry,obstacles,paving,occupied,terrain)
		await Budget.checkpoint(park)
	for rock: Node3D in rocks: rock.free()

func _south_approach_drift(spec: Dictionary,bed_index: int,entrance: Node3D,sources: Dictionary,geometry: Dictionary,obstacles: Array[Rect2],paving: Array[PackedVector2Array],occupied: Array[Dictionary],terrain: Node) -> void:
	var anchor:=Node3D.new();anchor.name="SouthApproach_"+str(spec.id);add_child(anchor)
	var area: Rect2=spec.area
	anchor.position=Vector3(area.get_center().x,terrain.height_at(area.get_center()),area.get_center().y)
	anchor.set_meta("creator_editable",true);anchor.set_meta("creator_display_name","South Approach "+str(spec.id));anchor.set_meta("creator_object_kind","landscape")
	anchor.set_meta("south_approach_drift_id",spec.id)
	var outer_batches: Dictionary=plant_batches;var outer_report: Array[Dictionary]=plant_report
	plant_batches={};plant_report=[]
	var plants: Array[Dictionary]=[];var stones: Array[Dictionary]=[];var rejected: Dictionary={};var attempts:=0
	for stone_pass: bool in [true,false]:
		var target: int=int(spec.stones) if stone_pass else 24
		for attempt: int in range(target*50):
			var count: int=stones.size() if stone_pass else plants.size()
			if count>=target: break
			attempts+=1
			var seed: float=float(attempt)+.5+float(bed_index)*.137+(3.1 if stone_pass else 0.0)
			var point:=area.position+Vector2(fmod(seed*.61803398875,1.0),fmod(seed*.41421356237,1.0))*area.size
			var kind: String=("rock_%02d"%((bed_index+count*2)%6)) if stone_pass else ("shrub" if count%3!=1 else "fern")
			var bounds: AABB=geometry[kind]
			var height: float=(.59+.10*sin(float(count)*1.3+float(bed_index))) if kind=="shrub" else (.42+.065*sin(float(count)*1.7+float(bed_index)))
			if stone_pass: height=minf(.42,(.90+.25*sin(float(count)+float(bed_index)))*bounds.size.y/maxf(.001,maxf(bounds.size.x,bounds.size.z)))
			var scale_value: float=height/maxf(.001,bounds.size.y)
			var radius: float=Vector2(bounds.size.x,bounds.size.z).length()*.5*scale_value
			var check: Dictionary=_south_approach_clearance(point,radius,entrance,obstacles,paving,occupied,terrain,stone_pass)
			if not check["pass"]:
				rejected[check.reason]=int(rejected.get(check.reason,0))+1;continue
			var ground: float=terrain.height_at(point)
			var embedded: float=height*.16 if stone_pass else 0.0
			var world:=Vector3(point.x,ground-embedded+.002,point.y)
			_add_plant(anchor,sources[kind],anchor.to_local(world),height,seed*2.399963,"SouthApproach_"+str(spec.id)+("_Stone_" if stone_pass else "_Plant_")+"%02d"%count,false)
			var row: Dictionary=plant_report[-1]
			row.merge({"node":anchor.get_path(),"ground_y":ground,"source_kind":kind,"visual_radius_m":radius,"clearance_m":check.clearance,"route_clearance_m":check.route,"apron_clearance_m":check.apron,"ramp_clearance_m":check.ramp,"prop_clearance_m":check.prop,"pocket_clearance_m":check.pocket,"view_clearance_m":check.view})
			if stone_pass:
				row.merge({"source_asset":"res://assets/shinrai/parks/midori_park/models/island_nature/"+kind+".glb","embedded_depth_m":embedded,"visual_only":true});stones.append(row)
			else: plants.append(row)
			occupied.append({"p":point,"radius":radius,"stone":stone_pass})
	var owned: Dictionary=plant_batches
	plant_batches=outer_batches;plant_report=outer_report
	var to_anchor: Transform3D=anchor.global_transform.affine_inverse();var serial:=0
	for key: String in owned:
		var row: Dictionary=owned[key]
		var node:=MultiMeshInstance3D.new();node.name="ApproachVisuals_%02d"%serial
		var mesh: Mesh=row.mesh.duplicate()
		for surface: int in range(row.overrides.size()): mesh.surface_set_material(surface,row.overrides[surface])
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=row.transforms.size()
		var transforms: Array[Transform3D]=[]
		for i: int in range(mm.instance_count):
			var local_transform: Transform3D=to_anchor*(row.transforms[i] as Transform3D)
			transforms.append(local_transform);mm.set_instance_transform(i,local_transform)
		node.multimesh=mm;node.set_meta("creator_authored_local_transforms",transforms)
		node.visibility_range_end=100;node.visibility_range_end_margin=8;node.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		anchor.add_child(node);serial+=1
	approach_report.append({"id":spec.id,"group":spec.group,"node":anchor.get_path(),"plants":plants,"stones":stones,"count":plants.size()+stones.size(),"plant_count":plants.size(),"stone_count":stones.size(),"attempts":attempts,"rejected":rejected,"world_area":area,"requested_plants":24,"requested_stones":spec.stones})

func _south_approach_clearance(point: Vector2,radius: float,entrance: Node3D,obstacles: Array[Rect2],paving: Array[PackedVector2Array],occupied: Array[Dictionary],terrain: Node,stone_pass: bool) -> Dictionary:
	var local3: Vector3=entrance.to_local(Vector3(point.x,entrance.global_position.y,point.y))
	var result: Dictionary=_entrance_landscape_clearance(Vector2(local3.x,local3.z),point,radius,obstacles,occupied,terrain)
	var pocket:=1000.0
	for polygon: PackedVector2Array in paving: pocket=minf(pocket,_south_polygon_distance(point,polygon)-radius)
	var view: float=point.distance_to(Geometry2D.get_closest_point_to_segment(point,Vector2(-14.8,158),Vector2(-8,160)))-1.0-radius
	view=minf(view,point.distance_to(Vector2(-14.8,158))-1.6-radius)
	var fork:=PackedVector2Array([Vector2(-15,158),Vector2(-8,160),Vector2(-12,153)])
	view=minf(view,_south_polygon_distance(point,fork)-radius)
	result.pocket=pocket;result.view=view;result.clearance=minf(float(result.clearance),minf(pocket,view))
	if pocket<.20: result["pass"]=false;result.reason="pocket"
	elif view<.20: result["pass"]=false;result.reason="sightline"
	for prior: Dictionary in occupied:
		if (stone_pass or prior.get("stone",false)) and point.distance_to(prior.p)<radius+float(prior.radius)+.08: result["pass"]=false;result.reason="stone_spacing";break
	return result

func _south_polygon_distance(point: Vector2,polygon: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(point,polygon): return 0.0
	var distance:=INF
	for i: int in range(polygon.size()): distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])))
	return distance

func _blend_entrance_landscape() -> void:
	var entrance:=get_node("PlazaEntranceRestGarden") as Node3D
	var terrain: Node=park.get_node("MidoriTerrain")
	var obstacles: Array[Rect2]=_entrance_landscape_obstacles(entrance.global_position)
	var carpet:=Node3D.new()
	carpet.add_child((load("res://assets/shinrai/parks/midori_park/models/forest_floor_20261026/groundcover_00.glb") as PackedScene).instantiate())
	var sources: Dictionary={"shrub":shrub_source,"fern":fern_source,"iris":iris_source,"carpet":carpet}
	var geometry: Dictionary={}
	for key: String in sources: geometry[key]=park._vegetation_visual_bounds(sources[key]).bounds
	var occupied: Array[Dictionary]=[]
	var beds: Array[Dictionary]=[
		{"id":"Rear","role":"rear","area":Rect2(-5.8,-4.5,11.6,1.45),"target":28},
		{"id":"Left","role":"side","area":Rect2(-7.35,-2.8,1.10,6.05),"target":10},
		{"id":"Right","role":"side","area":Rect2(6.25,-2.8,1.10,6.05),"target":10},
		{"id":"RampLeft","role":"ramp","area":Rect2(-6.0,3.6,1.40,1.55),"target":6},
		{"id":"RampRight","role":"ramp","area":Rect2(4.6,3.6,1.40,1.55),"target":6},
		# Connected side drifts: low fern edge, fuller evergreen body, occasional iris.
		{"id":"BankLeft","role":"bank","area":Rect2(-15.0,-7.0,7.0,12.0),"target":106,"woody":36},
		{"id":"BankRight","role":"bank","area":Rect2(8.0,-7.0,9.0,12.0),"target":110,"woody":40}]
	for spec: Dictionary in beds:
		_entrance_landscape_bed(entrance,spec,sources,geometry,obstacles,occupied,terrain)
		await Budget.checkpoint(park)
	carpet.free()

func _entrance_landscape_bed(entrance: Node3D,spec: Dictionary,sources: Dictionary,geometry: Dictionary,obstacles: Array[Rect2],occupied: Array[Dictionary],terrain: Node) -> void:
	var anchor:=Node3D.new();anchor.name="EntranceLandscape_"+str(spec.id)
	add_child(anchor);anchor.global_transform=entrance.global_transform
	anchor.set_meta("creator_editable",true)
	anchor.set_meta("creator_display_name","Entrance "+str(spec.id)+" Planting")
	anchor.set_meta("creator_object_kind","plant")
	anchor.set_meta("entrance_landscape_bed_id",spec.id)
	# The original 270 planter records/batches/serials are never mixed with beds.
	var outer_batches: Dictionary=plant_batches
	var outer_report: Array[Dictionary]=plant_report
	plant_batches={};plant_report=[]
	var rejected: Dictionary={};var attempts:=0;var flowers:=0
	for attempt: int in range(int(spec.target)*28):
		if plant_report.size()>=int(spec.target): break
		attempts+=1
		var area: Rect2=spec.area
		var local:=area.position+Vector2(fmod((float(attempt)+.5)*.61803398875,1.0),fmod((float(attempt)+.5)*.41421356237,1.0))*area.size
		if spec.role=="bank":
			# Linked irregular drift, rather than uniformly scattered specimens.
			var q: Vector2=(local-area.get_center())/(area.size*.5)
			q.x+=.15*sin(q.y*4.0)
			if q.length_squared()>1.0: continue
		var slot: int=plant_report.size()
		var flowering: bool=spec.role!="rear" and attempt%9==4 and flowers<maxi(1,int(float(spec.target)*.12))
		var kind: String="iris" if flowering else ("shrub" if (spec.role=="rear" and slot%3!=1) or (spec.role=="side" and slot%3==0) else "fern")
		var height: float=.375+.02*sin(float(slot)*1.7)
		if not flowering:
			if spec.role=="rear": height=(.80+.14*sin(float(slot)*1.3)) if kind=="shrub" else (.375+.065*sin(float(slot)*1.7))
			elif spec.role=="side": height=lerpf(.42,.28,inverse_lerp(-2.8,3.25,local.y))+.02*sin(float(slot)*1.7)
			else: height=.25+.06*sin(float(slot)*1.7)
		if spec.role=="bank":
			var outer: float=clampf((absf(local.x)-7.5)/7.0,0.0,1.0)
			kind="iris" if flowering else ("shrub" if slot%4!=1 else "fern")
			height=(lerpf(.52,.90,outer)+.09*sin(float(slot)*1.7)) if kind=="shrub" else (.38+.07*sin(float(slot)*1.3))
			if flowering: height=.38
		var spread:=1.0
		if spec.role=="bank":
			spread=1.5 if kind=="shrub" else 1.12
			if slot>=int(spec.woody):
				kind="carpet";flowering=false
				height=.24+.055*sin(float(slot)*1.7)
				var carpet_bounds: AABB=geometry.carpet
				var width: float=.95+.2*sin(float(slot)*2.1)
				spread=width/(maxf(carpet_bounds.size.x,carpet_bounds.size.z)*height/carpet_bounds.size.y)
		var bounds: AABB=geometry[kind]
		var scale_value: float=height/maxf(.001,bounds.size.y)
		var radius: float=Vector2(bounds.size.x,bounds.size.z).length()*.5*scale_value*spread
		var world: Vector3=entrance.to_global(Vector3(local.x,0,local.y))
		var point:=Vector2(world.x,world.z)
		var check: Dictionary=_entrance_landscape_clearance(local,point,radius,obstacles,occupied,terrain,.40 if spec.role=="bank" else .16)
		if not check["pass"]:
			rejected[check.reason]=int(rejected.get(check.reason,0))+1
			continue
		var ground: float=terrain.height_at(point)
		# Seat the plant's low foliage slightly into the slope instead of floating.
		world.y=ground-.035 if spec.role=="bank" else ground+.002
		_add_plant(anchor,sources[kind],anchor.to_local(world),height,float(attempt)*2.399963,"EntranceLandscape_"+str(spec.id)+"_%02d"%slot,flowering,spread)
		var row: Dictionary=plant_report[-1]
		row.merge({"node":anchor.get_path(),"ground_y":ground,"source_kind":kind,"visual_radius_m":radius,"clearance_m":check.clearance,"route_clearance_m":check.route,"apron_clearance_m":check.apron,"ramp_clearance_m":check.ramp,"prop_clearance_m":check.prop})
		if flowering: flowers+=1
		occupied.append({"p":point,"radius":radius})
	var owned: Dictionary=plant_batches
	var rows: Array[Dictionary]=plant_report
	plant_batches=outer_batches;plant_report=outer_report
	var to_anchor: Transform3D=anchor.global_transform.affine_inverse()
	var serial:=0
	for key: String in owned:
		var row: Dictionary=owned[key]
		var node:=MultiMeshInstance3D.new();node.name="LandscapePlants_%02d"%serial
		var mesh: Mesh=row.mesh.duplicate()
		for surface: int in range(row.overrides.size()): mesh.surface_set_material(surface,row.overrides[surface])
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=row.transforms.size()
		var transforms: Array[Transform3D]=[]
		for i: int in range(mm.instance_count):
			var local_transform: Transform3D=to_anchor*(row.transforms[i] as Transform3D)
			transforms.append(local_transform);mm.set_instance_transform(i,local_transform)
		node.multimesh=mm;node.set_meta("creator_authored_local_transforms",transforms)
		node.visibility_range_end=75;node.visibility_range_end_margin=8;node.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		anchor.add_child(node);serial+=1
	landscape_report.append({"id":spec.id,"node":anchor.get_path(),"role":spec.role,"count":rows.size(),"attempts":attempts,"rejected":rejected,"plants":rows,"local_area":spec.area,"requested_count":spec.target})

func _entrance_landscape_clearance(local: Vector2,point: Vector2,radius: float,obstacles: Array[Rect2],occupied: Array[Dictionary],terrain: Node,max_ground_spread: float=.16) -> Dictionary:
	var apron: float=_landscape_rect_distance(local,Rect2(-6,-2.65,12,6))-radius
	var ramp: float=_landscape_rect_distance(local,Rect2(-4.2,3.35,8.4,2))-radius
	var route: float=park.path_edge_distance_world(point)-radius
	for path: PackedVector2Array in terrain.paths:
		for i: int in range(path.size()-1): route=minf(route,point.distance_to(Geometry2D.get_closest_point_to_segment(point,path[i],path[i+1]))-1.25-radius)
	var desire: Node=park.get_node_or_null("MidoriDesirePaths")
	if desire!=null: route=minf(route,float(desire.distance_to_path(point))-1.0-radius)
	var prop:=1000.0
	for obstacle: Rect2 in obstacles: prop=minf(prop,_landscape_rect_distance(point,obstacle)-radius)
	var clearance: float=minf(minf(apron,ramp),minf(route,prop))
	var result: Dictionary={"pass":false,"reason":"","apron":apron,"ramp":ramp,"route":route,"prop":prop,"clearance":clearance}
	for key: String in ["apron","ramp","route","prop"]:
		if float(result[key])<.20: result.reason=key;return result
	if terrain.water_at(point): result.reason="water";return result
	var low:=INF;var high:=-INF
	for side: int in range(8):
		var sample: Vector2=point+Vector2(radius,0).rotated(float(side)*TAU/8.0)
		if terrain.water_at(sample): result.reason="water";return result
		var height: float=terrain.height_at(sample)
		low=minf(low,height);high=maxf(high,height)
	if high-low>max_ground_spread: result.reason="slope";return result
	for prior: Dictionary in occupied:
		if point.distance_to(prior.p)<maxf(.24,(radius+float(prior.radius))*.35): result.reason="spacing";return result
	result["pass"]=true
	return result

func _landscape_rect_distance(point: Vector2,rect: Rect2) -> float:
	return point.distance_to(point.clamp(rect.position,rect.end))

func _entrance_landscape_obstacles(centre: Vector3) -> Array[Rect2]:
	var obstacles: Array[Rect2]=[]
	var terrain: Node=park.get_node("MidoriTerrain")
	for shape: CollisionShape3D in park.find_children("*","CollisionShape3D",true,false):
		if shape.disabled or shape.shape==null: continue
		if Vector2(shape.global_position.x-centre.x,shape.global_position.z-centre.z).length()>25.0: continue
		var obstacle_owner: Node=shape.get_parent()
		if obstacle_owner is CollisionObject3D and (obstacle_owner as CollisionObject3D).collision_layer==0: continue
		if shape.shape is ConcavePolygonShape3D or shape.shape is HeightMapShape3D: continue
		var debug_mesh: ArrayMesh=shape.shape.get_debug_mesh()
		var box: AABB=shape.global_transform*debug_mesh.get_aabb()
		var point:=Vector2(box.get_center().x,box.get_center().z)
		var ground: float=terrain.height_at(point)
		# Ignore walk/foundation slabs and overhead-only roof hulls; apron/ramp
		# and the actual path-edge service have their own complete exclusions.
		if box.end.y<ground+.30 or box.position.y>ground+1.25: continue
		if box.size.x*box.size.z>120.0: continue
		obstacles.append(Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)))
	return obstacles

func _rest_pad(group: Node3D,width: float,depth: float) -> void:
	# A level seat apron has a real foundation down to this rolling terrain.
	# Its short access ramp meets the existing walk rather than hovering above it.
	var highest: float=group.position.y
	var lowest: float=group.position.y
	for x: float in [-width*.5,0,width*.5]:
		for z: float in [-depth*.5+.35,depth*.5+.35]:
			var p:=group.to_global(Vector3(x,0,z))
			var ground:=_ground(Vector2(p.x,p.z))
			highest=maxf(highest,ground+.015);lowest=minf(lowest,ground-.03)
	group.position.y=highest
	var foundation_depth:=maxf(.12,highest-lowest)
	var floor_mesh:=MeshInstance3D.new();floor_mesh.name="MineralRestApron"
	var mesh:=BoxMesh.new();mesh.size=Vector3(width,foundation_depth,depth)
	floor_mesh.mesh=mesh;floor_mesh.position=Vector3(0,-foundation_depth*.5-.002,.35)
	# Use the same real mineral texture set as the existing arrival walks.
	floor_mesh.material_override=park.WalkMaterials.build(width)
	group.add_child(floor_mesh)
	var floor_body:=StaticBody3D.new();floor_body.name="RestApronWalkSurface"
	group.add_child(floor_body);floor_body.add_to_group("midori_walk_surface")
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=mesh.size
	shape.shape=box;shape.position=floor_mesh.position;floor_body.add_child(shape)
	# A two-metre sloping threshold has independently grounded outer corners.
	var threshold:=MeshInstance3D.new();threshold.name="FlushAccessThreshold"
	var half_width: float=width*.35
	var near_z: float=depth*.5+.35
	var far_z: float=near_z+2.0
	var a:=Vector3(-half_width,-.002,near_z);var b:=Vector3(half_width,-.002,near_z)
	var c:=Vector3(half_width,0,far_z);var d:=Vector3(-half_width,0,far_z)
	var far_c:=group.to_global(c);var far_d:=group.to_global(d)
	c.y=_ground(Vector2(far_c.x,far_c.z))+.12-group.position.y
	d.y=_ground(Vector2(far_d.x,far_d.z))+.12-group.position.y
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal((d-a).cross(b-a).normalized())
	_triangle(surface,a,b,c,Vector2.ZERO,Vector2(0,1),Vector2.ONE)
	_triangle(surface,a,c,d,Vector2.ZERO,Vector2.ONE,Vector2(1,0))
	# Grounded side cheeks close the access wedge; there is no hollow black gap.
	var below_a:=a-Vector3(0,foundation_depth,0)
	var below_b:=b-Vector3(0,foundation_depth,0)
	var below_c:=c-Vector3(0,.12,0);var below_d:=d-Vector3(0,.12,0)
	surface.set_normal(Vector3.LEFT);_quad(surface,a,d,below_d,below_a)
	surface.set_normal(Vector3.RIGHT);_quad(surface,c,b,below_b,below_c)
	surface.set_normal(Vector3.BACK);_quad(surface,d,c,below_c,below_d)
	threshold.mesh=surface.commit()
	threshold.material_override=park.WalkMaterials.build(width*.70);group.add_child(threshold)
	var link_shape:=CollisionShape3D.new();var link_shape_mesh:=ConcavePolygonShape3D.new()
	link_shape_mesh.backface_collision=true
	link_shape_mesh.set_faces(PackedVector3Array([a,b,c,a,c,d]));link_shape.shape=link_shape_mesh;floor_body.add_child(link_shape)
	group.set_meta("apron",{"foundation_depth_m":foundation_depth,"ramp_drop_m":[c.y,d.y],"width_m":width,"level_top_y":group.position.y})

func _label(parent: Node3D,text: String,pos: Vector3,pixel: float,size: int,color: Color) -> void:
	var label:=Label3D.new();label.name="ParkLettering";label.text=text;label.position=pos
	label.pixel_size=pixel;label.font_size=size;label.modulate=color;label.outline_size=0
	label.no_depth_test=false;label.shaded=false;label.double_sided=false
	parent.add_child(label)

func _park_map() -> Texture2D:
	# Geometry is derived from this deployed park, in world metres. No fictional
	# street grid or generated pseudo lettering is printed on the e-ink display.
	var svg: String='<svg xmlns="http://www.w3.org/2000/svg" width="768" height="1664" viewBox="0 0 768 1664"><rect width="768" height="1664" fill="#d4dfc4"/><rect x="44" y="290" width="680" height="710" rx="16" fill="#acbd9a" stroke="#53735c" stroke-width="4"/>'
	var lake: PackedVector2Array=park.LakeGeometry.contour()
	var points: PackedStringArray=[]
	for p: Vector2 in lake: points.append("%.2f,%.2f"%[_map_point(p*2).x,_map_point(p*2).y])
	svg+='<polygon points="%s" fill="#719d99" stroke="#466f65" stroke-width="4"/>'%" ".join(points)
	for route: Array[Vector2] in [park.OUTER_CIRCUIT,park.SOUTH_ARRIVAL_ROUTE,park.WEST_DESTINATION_ROUTE,park.NORTH_ENTRY_ROUTE,park.EAST_DECK_ROUTE,park.PLAZA_PAVED_ROUTE,park.LAKE_PROMENADE_LOOP,park.PLAYGROUND_LOOP,park.NORTH_WOODLAND_LOOP,park.SOUTH_BRIDGE_APPROACH]:
		points=[]
		for p: Vector2 in route:
			var v:=_map_point(p*2);points.append("%.2f,%.2f"%[v.x,v.y])
		svg+='<polyline points="%s" fill="none" stroke="#f1edd7" stroke-width="7" stroke-linejoin="round" stroke-linecap="round"/>'%" ".join(points)
	var plaza:=_map_point(PLAZA_CENTRE)
	svg+='<circle cx="%.2f" cy="%.2f" r="24" fill="#b7b995" stroke="#4c6954" stroke-width="4"/>'%[plaza.x,plaza.y]
	var here:=_map_point(Vector2(-14.8,158))
	svg+='<circle cx="%.2f" cy="%.2f" r="14" fill="#b7663d" stroke="#fff9df" stroke-width="5"/>'%[here.x,here.y]
	# A simple north arrow and scale bar remain geometry, with real 100m length.
	svg+='<path d="M650 245 L660 215 L670 245 L660 237 Z" fill="#345642"/><path d="M93 1100 H243 M93 1090 V1110 M243 1090 V1110" fill="none" stroke="#345642" stroke-width="5"/></svg>'
	var image:=Image.new();assert(image.load_svg_from_string(svg)==OK)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _map_point(p: Vector2) -> Vector2:
	return Vector2(384+p.x*1.5,645+p.y*1.5)
