extends Node3D
# One local dry-bank ecotone. Uses authored shoreline, terrain and supplied grass.
# Attach as direct park child after MidoriTerrain and MidoriDesirePaths exist.
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")
const Meadow = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_swaying_meadow_grass_v1.glb")
var installed := false
var park: Node3D
var terrain: Node3D
var trails: Node
var edge := Vector2.ZERO
var tangent := Vector2.RIGHT
var outward := Vector2.DOWN
var plant_positions: Array[Vector2] = []
var authored_edge := Vector2.ZERO

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	park=get_parent()
	terrain=park.get_node("MidoriTerrain")
	while not terrain.installed: await get_tree().process_frame
	while park.get_node_or_null("MidoriDesirePaths")==null: await get_tree().process_frame
	trails=park.get_node("MidoriDesirePaths")
	while not trails.finished: await get_tree().process_frame
	install()

func safe(p: Vector2, margin: float, min_y: float = .117) -> bool:
	if terrain.water_at(p) or terrain.height_at(p)<min_y: return false
	if trails.distance_to_path(p)<margin+1.5: return false
	if not park._waterside_bridge_clear(p/park.LAYOUT_SCALE): return false
	for path: PackedVector2Array in terrain.paths:
		for i in range(path.size()-1):
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,path[i],path[i+1]))<margin+2.2: return false
	if park.any_trunk_within(p,margin+1.0): return false
	return true

func install() -> void:
	if installed or park.has_meta("shore_ecotone"): return
	# Project the review point onto the actual west/southwest mainland contour.
	var target := Vector2(31,37)
	var nearest := INF
	var polygon: PackedVector2Array = terrain.shoreline
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		var q := Geometry2D.get_closest_point_to_segment(target,a,b)
		if q.distance_to(target)<nearest:
			nearest=q.distance_to(target)
			edge=q
			tangent=(b-a).normalized()
	outward=Vector2(-tangent.y,tangent.x)
	if terrain.water_at(edge+outward*1.0): outward=-outward
	authored_edge=edge
	# The lake polygon is not the visible contact: the 2 m terrain shelf remains
	# below the actual .102 m water plane for several metres inland.
	edge=contact_at(0.0).p
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := 0
	for u in range(-20,20):
		var along := float(u)*.5
		var ca: Dictionary = contact_at(along)
		var cb: Dictionary = contact_at(along+.5)
		var taper := smoothstep(0.0,2.8,10.0-absf(along+.25))
		var width := (1.3+.40*sin(along*.83)+.25*cos(along*1.37))*taper
		for v in range(5):
			var depth := float(v)*.4
			if depth+.4>width: continue
			var a: Vector2 = ca.p+ca.normal*(.06+depth)
			var b: Vector2 = cb.p+cb.normal*(.06+depth)
			var c: Vector2 = ca.p+ca.normal*(.46+depth)
			var d: Vector2 = cb.p+cb.normal*(.46+depth)
			# Every vertex and cell centre is exposed above the real water plane.
			if not safe(a,.12,.104) or not safe(b,.12,.104) or not safe(c,.12,.104) or not safe(d,.12,.104) or not safe((a+b+c+d)*.25,.12,.104): continue
			for p: Vector2 in [a,c,b,b,c,d]:
				var across := p.distance_to(Geometry2D.get_closest_point_to_segment(p,ca.p,cb.p))
				var blend := taper*smoothstep(0.0,.24,across)*(1.0-smoothstep(maxf(.3,width-.55),width,across))
				surface.set_color(Color(blend,blend,blend,1.0))
				surface.set_normal(Vector3.UP)
				surface.set_uv(p*.5)
				surface.add_vertex(Vector3(p.x,terrain.height_at(p)+.003,p.y))
			triangles+=2
	if triangles>0:
		var soil_material := textured_soil_material()
		if soil_material!=null:
			var soil := MeshInstance3D.new()
			soil.name="ShoreDampSoil"
			soil.mesh=surface.commit()
			soil.material_override=soil_material
			soil.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(soil)
		else:
			triangles=0
	var source := Meadow.instantiate() as Node3D
	var boxes: Dictionary = park._vegetation_visual_bounds(source)
	var bounds: AABB = boxes.bounds
	var root := Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	var transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed=2050102603
	# Unequal drifts and open windows, with sparse low plants at each end.
	for cluster in range(5):
		var along: float = [-8.0,-4.6,-1.7,3.4,7.2][cluster]
		var count: int = [9,17,13,21,8][cluster]
		var budget := count*8
		for attempt in range(budget):
			if transforms.size()>=68: break
			var offset := Vector2(rng.randf_range(-1.9,1.9),rng.randf_range(.35,2.8))
			var contact: Dictionary = contact_at(along+offset.x)
			var p: Vector2 = contact.p+contact.normal*offset.y
			if not safe(p,.65): continue
			var crowded := false
			for prior in plant_positions:
				if p.distance_to(prior)<.56: crowded=true; break
			if crowded: continue
			# Dry bank grass forms only: keep original meadow material and roots above water.
			var height := rng.randf_range(.48,.92)
			var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*height/maxf(bounds.size.y,.001))
			var t := Transform3D(basis,Vector3(p.x,terrain.height_at(p)+.003,p.y)-basis*root)
			transforms.append(t)
			plant_positions.append(p)
			count-=1
			if count<=0: break
	for part: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		if part.mesh==null: continue
		var mesh := part.mesh.duplicate() as Mesh
		for s in range(mesh.get_surface_count()): mesh.surface_set_material(s,part.get_active_material(s))
		var relative: Transform3D = park._vegetation_relative_transform(part,source)
		var mm := MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=mesh
		mm.instance_count=transforms.size()
		for i in range(transforms.size()): mm.set_instance_transform(i,transforms[i]*relative)
		var batch := MultiMeshInstance3D.new()
		batch.name="ShoreMeadow_%02d"%get_child_count()
		batch.multimesh=mm
		batch.visibility_range_end=100
		batch.visibility_range_end_margin=15
		batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
	source.free()
	installed=true
	park.set_meta("shore_ecotone",{"edge":edge,"authored_edge":authored_edge,"water_y":.102,"minimum_plant_root_y":.117,"plants":transforms.size(),"soil_triangles":triangles,"new_collisions":0,"source":"midori_swaying_meadow_grass_v1.glb"})
	print("SHORE_ECOTONE plants=",transforms.size()," soil_triangles=",triangles," edge=",edge)

func contact_at(along: float) -> Dictionary:
	var target := authored_edge+tangent*along
	var polygon: PackedVector2Array = terrain.shoreline
	var point := authored_edge
	var normal := outward
	var nearest := INF
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		var q := Geometry2D.get_closest_point_to_segment(target,a,b)
		if q.distance_to(target)<nearest:
			nearest=q.distance_to(target)
			point=q
			var direction := (b-a).normalized()
			normal=Vector2(-direction.y,direction.x)
			if terrain.water_at(point+normal*.5): normal=-normal
	var lower := 0.0
	var upper := 24.0
	for step in range(49):
		var distance := float(step)*.5
		var p := point+normal*distance
		if not terrain.water_at(p) and terrain.height_at(p)>=.106:
			upper=distance
			lower=maxf(0.0,distance-.5)
			break
	for step in range(10):
		var middle := (lower+upper)*.5
		if terrain.height_at(point+normal*middle)>=.106: upper=middle
		else: lower=middle
	return {"p":point+normal*upper,"normal":normal}

func textured_soil_material() -> Material:
	# Keep the installed ground texture, world UVs, normals and all live parameters.
	# Only tint a vertex-weighted film; boundaries converge to the original ground.
	for child: Node in terrain.get_children():
		if not child is MeshInstance3D: continue
		var source := child.material_override as ShaderMaterial
		if source==null or source.shader==null: continue
		var code: String = source.shader.code
		var closing := code.rfind("}")
		if closing<0 or not code.contains("ALBEDO"): continue
		var parameters: Dictionary = {}
		for uniform: Dictionary in source.shader.get_shader_uniform_list():
			parameters[uniform.name]=source.get_shader_parameter(uniform.name)
		var shader := Shader.new()
		shader.code=code.insert(closing,"
    ALBEDO = mix(ALBEDO, ALBEDO * vec3(0.68,0.57,0.41), COLOR.r * 0.72);
")
		var result := source.duplicate() as ShaderMaterial
		result.shader=shader
		for key: Variant in parameters: result.set_shader_parameter(key,parameters[key])
		return result
	return null
