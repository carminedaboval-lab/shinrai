extends RefCounted
## Chamfered decorative joinery, with grain mapped along each physical member.
## Its overall box size is unchanged; existing collisions remain owned by caller.
const TIMBER_PATH := "res://assets/shinrai/streets/midori_frontage_construction/"
const FineTimber = preload("res://scripts/midori_fine_timber.gd")
const MeshArrays = preload("res://scripts/midori_south_street_mesh_arrays.gd")
const TIMBER_NORMAL := TIMBER_PATH+"fine_grained_wood_nor_gl_2k.png"
const TIMBER_ROUGH := TIMBER_PATH+"fine_grained_wood_rough_2k.jpg"

static func applies(key: String, label: String) -> bool:
	return key in ["arch_cedar","arch_cladding","arch_pale_wood","arch_floor","detail_wood","detail_darkwood"]

static func material(street: Node3D, key: String) -> ShaderMaterial:
	var mats: Dictionary = street.get("materials")
	var cache_key := "joinery_"+key
	if mats.has(cache_key): return mats[cache_key] as ShaderMaterial
	var mat := ShaderMaterial.new()
	mat.resource_name = "SouthStreet_"+cache_key
	mat.shader = preload("res://scripts/midori_court_timber.gdshader")
	mat.set_shader_parameter("timber_grain",FineTimber.grain())
	mat.set_shader_parameter("timber_normal",load(TIMBER_NORMAL))
	mat.set_shader_parameter("timber_roughness_map",load(TIMBER_ROUGH))
	var brightness := .34
	var contrast := .36
	if key == "arch_cladding": brightness = .52
	elif key == "arch_cedar": brightness = .54
	elif key == "arch_pale_wood": brightness = .60
	elif key == "arch_floor": brightness = .38
	elif key == "detail_wood": brightness = .65
	elif key == "detail_darkwood": brightness = .32
	if key == "detail_wood": contrast = .55
	elif key in ["arch_cladding","arch_cedar","arch_pale_wood"]: contrast = .28
	var chroma := .78 if key in ["arch_cladding","arch_cedar","arch_pale_wood"] else 1.0
	mat.set_shader_parameter("timber_tint",FineTimber.legacy_tint(brightness,chroma))
	mat.set_shader_parameter("timber_contrast",contrast)
	mat.set_shader_parameter("length_in_u",true)
	mat.set_shader_parameter("vertical_cladding",key=="arch_cladding")
	mat.set_shader_parameter("normal_depth",.08)
	mats[cache_key] = mat
	return mat

static func mesh(size: Vector3, seed_value: int, bevel_limit: float=.006, grain_axis: int=-1) -> ArrayMesh:
	return MeshArrays.commit(_member(size,seed_value,bevel_limit,grain_axis))

## The member mesh() builds, as a SurfaceTool.append_from() source for members
## merged into a larger assembly: never uploaded as its own mesh nor read back
## from the GPU (each read-back stalls the render device).
static func member_source(size: Vector3, seed_value: int, bevel_limit: float=.006, grain_axis: int=-1) -> Mesh:
	return MeshArrays.tool_source(_member(size,seed_value,bevel_limit,grain_axis))

static func _member(size: Vector3, seed_value: int, bevel_limit: float, grain_axis: int) -> SurfaceTool:
	var half := size*.5
	var radius := minf(bevel_limit,minf(size.x,minf(size.y,size.z))*.14)
	var inner := half-Vector3.ONE*radius
	var along := grain_axis if grain_axis>=0 else size.max_axis_index()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Six full flat faces terminate at the tiny physical edge bevel.
	for axis: int in range(3):
		var u := (axis+1)%3
		var v := (axis+2)%3
		for sign_value: float in [-1.0,1.0]:
			var n := Vector3.ZERO
			n[axis] = sign_value
			var points := PackedVector3Array()
			for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var p := Vector3.ZERO
				p[axis] = half[axis]*sign_value
				p[u] = inner[u]*corner.x
				p[v] = inner[v]*corner.y
				points.append(p)
			_face(tool,points,n,size,along,seed_value)
	# Twelve chamfer strips catch the existing light without a fake highlight.
	for pair: Vector2i in [Vector2i(0,1),Vector2i(0,2),Vector2i(1,2)]:
		var a := pair.x
		var b := pair.y
		var c := 3-a-b
		for sa: float in [-1.0,1.0]:
			for sb: float in [-1.0,1.0]:
				var points := PackedVector3Array()
				for row: Vector2 in [Vector2(0,-1),Vector2(1,-1),Vector2(1,1),Vector2(0,1)]:
					var p := Vector3.ZERO
					p[a] = (half[a] if row.x == 0 else inner[a])*sa
					p[b] = (inner[b] if row.x == 0 else half[b])*sb
					p[c] = inner[c]*row.y
					points.append(p)
				var n := Vector3.ZERO
				n[a] = sa
				n[b] = sb
				_face(tool,points,n.normalized(),size,along,seed_value)
	# Eight small triangular corner faces close the bevels.
	for sx: float in [-1.0,1.0]:
		for sy: float in [-1.0,1.0]:
			for sz: float in [-1.0,1.0]:
				var signs := Vector3(sx,sy,sz)
				var points := PackedVector3Array()
				for axis: int in range(3):
					var p := inner*signs
					p[axis] = half[axis]*signs[axis]
					points.append(p)
				_face(tool,points,signs.normalized(),size,along,seed_value)
	tool.index()
	tool.generate_tangents()
	return tool

static func floor_mesh(size: Vector3) -> ArrayMesh:
	# One merged visual, original outer bounds/top unchanged. 18mm timber
	# boards sit over a continuous subfloor; 2mm joints are actual openings
	# between boards, not painted stripes on a monolithic wooden sheet.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var board_depth := minf(.018,size.y*.35)
	var base_size := Vector3(size.x,size.y-board_depth,size.z)
	tool.append_from(member_source(base_size,31,.0007),0,Transform3D(Basis.IDENTITY,Vector3(0,-board_depth*.5,0)))
	var pitch := .160
	var rows := ceili(size.z/pitch)
	for row: int in range(rows):
		var z0 := -size.z*.5+float(row)*pitch
		var z1 := minf(size.z*.5,z0+pitch)
		var shift := float(row%3)*.60
		var start := -size.x*.5-shift
		var board := 0
		while start < size.x*.5-.001:
			var x0 := maxf(-size.x*.5,start)
			var x1 := minf(size.x*.5,start+1.80)
			if x1-x0>.004:
				var member_size := Vector3(x1-x0-.002,board_depth,z1-z0-.002)
				var p := Vector3((x0+x1)*.5,(size.y-board_depth)*.5,(z0+z1)*.5)
				tool.append_from(member_source(member_size,row*97+board*13,.0007,0),0,Transform3D(Basis.IDENTITY,p))
			start += 1.80
			board += 1
	tool.index()
	tool.generate_tangents()
	return MeshArrays.commit(tool)

static func _face(tool: SurfaceTool, points: PackedVector3Array, normal: Vector3, size: Vector3, along: int, seed_value: int) -> void:
	# Godot's front faces use clockwise winding.
	if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal) > 0.0: points.reverse()
	var face_axis := normal.abs().max_axis_index()
	var across := 0
	for axis: int in range(3):
		if axis != along and axis != face_axis: across = axis
	if face_axis == along: across = (along+2)%3
	var offset := float(posmod(int(seed_value/8),197))/197.0
	for i: int in range(1,points.size()-1):
		for index: int in [0,i,i+1]:
			var p := points[index]
			var cross_uv := p[across]/1.0+float(posmod(seed_value,137))/137.0
			var length_uv := p[along]/1.0+offset
			if face_axis == along:
				length_uv = p[(along+1)%3]/1.0+offset
			tool.set_normal(normal)
			tool.set_uv(Vector2(length_uv,cross_uv))
			tool.add_vertex(p)

static func upright_profile(source: ArrayMesh) -> ArrayMesh:
	# Profiled jamb vertices already carry their construction position. Use
	# physical metre UVs along the upright, including the rebate faces.
	var arrays := source.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs := PackedVector2Array()
	for i: int in range(positions.size()):
		var p := positions[i]
		var n := normals[i].abs()
		uvs.append(Vector2(p.z if n.y > .9 else p.y,p.z if n.x > n.z else p.x)/1.0)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var tool := SurfaceTool.new()
	tool.create_from(mesh,0)
	tool.generate_tangents()
	return MeshArrays.commit(tool)
