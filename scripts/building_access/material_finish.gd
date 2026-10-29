extends RefCounted
## Post-construction, pre-batch tactile finish. Never creates geometry/collisions.
const Wall = preload("res://scripts/midori_house_paint.gdshader")
const Timber = preload("res://scripts/midori_court_timber.gdshader")
const FineTimber = preload("res://scripts/midori_fine_timber.gd")
const MINERAL := "res://assets/shinrai/streets/midori_court_materials/"
const WOOD := "res://assets/shinrai/streets/midori_frontage_construction/"

static func build(street: Node3D) -> Dictionary:
	if street.has_meta("building_material_finish"): return street.get_meta("building_material_finish")
	var source: Dictionary = street.get("materials")
	var report := {"properties":0,"mineral":0,"timber":0,"foundation":0,"metal":0,"unique_materials":0,"positions_unchanged":true,"collision_unchanged":true,"source_maps_unchanged":true,"plaster_repeat_m":1.0,"timber_coverage_m":Vector2(.90,2.4)}
	for node: Node in street.find_children("*","Node3D",true,false):
		if not node.has_meta("building_access"): continue
		var root := node as Node3D
		var coatings: Dictionary = {}
		_finish(root,root,source,coatings,report)
		report.unique_materials += coatings.size()
		report.properties += 1
	street.set_meta("building_material_finish",report)
	return report

static func _finish(node: Node, root: Node3D, source: Dictionary, cache: Dictionary, report: Dictionary) -> void:
	var label := String(node.name)
	# Never repaint identity substrates/lettering, imported hero props, interiors,
	# glazing, or content behind windows. Access door/window components remain live.
	if label == "BuildingAccessInterior": return
	if label in ["IndependentShopIdentity","ShopfrontIdentity2050"] or label.contains("Identity"): return
	if label.begins_with("Interior") or label.begins_with("Room") or label.begins_with("RecessShelf") or label.begins_with("ShelfObject"): return
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		var original := visual.material_override
		if original != null and visual.mesh != null:
			var role := _role(original,source)
			if not role.is_empty():
				var key := str(original.get_instance_id())+"/"+role
				if not cache.has(key): cache[key] = _coating(original,role,root)
				visual.material_override = cache[key]
				if role == "timber" and original is StandardMaterial3D:
					visual.mesh = _physical_uvs(visual.mesh)
				visual.set_meta("building_material_role",role)
				report[role] += 1
	for child: Node in node.get_children(): _finish(child,root,source,cache,report)

static func _role(material: Material, source: Dictionary) -> String:
	if material is ShaderMaterial:
		var sm := material as ShaderMaterial
		if sm.shader == null: return ""
		var path := sm.shader.resource_path
		if path.ends_with("midori_house_paint.gdshader") or path.ends_with("midori_court_render.gdshader"): return "mineral"
		if path.ends_with("midori_court_timber.gdshader"): return "timber"
		return ""
	if material == source.get("arch_plaster") or material == source.get("arch_mineral"): return "mineral"
	for key: String in ["arch_cedar","arch_pale_wood","joinery_arch_cedar","joinery_arch_pale_wood","joinery_arch_cladding"]:
		if material == source.get(key): return "timber"
	if material == source.get("arch_stone"): return "foundation"
	if material == source.get("arch_metal") or material.resource_name.ends_with("_CoatedRoofRainwater"): return "metal"
	return ""

static func _coating(original: Material, role: String, root: Node3D) -> Material:
	if role == "mineral":
		var material := ShaderMaterial.new()
		material.shader = Wall
		material.resource_name = String(root.name)+"_TactileMineral"
		for channel: String in ["color","normal","roughness"]:
			var suffix := {"color":"diff_1k.jpg","normal":"nor_gl_1k.png","roughness":"rough_1k.jpg"}
			material.set_shader_parameter("mineral_"+channel,load(MINERAL+"white_plaster_02_"+suffix[channel]))
		var tint := Color("#c6bda8")
		if original is ShaderMaterial:
			var sm := original as ShaderMaterial
			if sm.shader.resource_path.ends_with("midori_house_paint.gdshader"):
				for uniform: String in ["upper_tint","lower_tint","paint_line_world_y"]: material.set_shader_parameter(uniform,sm.get_shader_parameter(uniform))
			else:
				var value: Variant = sm.get_shader_parameter("mineral_tint")
				if value is Color: tint = value
				material.set_shader_parameter("upper_tint",tint)
				material.set_shader_parameter("lower_tint",tint)
		else:
			# Existing shop palettes, without carrying photo-map HDR multipliers.
			if String(root.name)=="HinataDaily": tint=Color("#bcb49f")
			material.set_shader_parameter("upper_tint",tint)
			material.set_shader_parameter("lower_tint",tint)
		var access: Dictionary = root.get_meta("building_access",{})
		var dimensions: Dictionary = access.get("dimensions",{})
		material.set_shader_parameter("ground_world_y",root.global_position.y+float(dimensions.get("ground_floor_m",0.0)))
		return material
	if role == "timber":
		var material: ShaderMaterial
		if original is ShaderMaterial:
			material = original.duplicate() as ShaderMaterial
		else:
			material = ShaderMaterial.new()
			material.shader = Timber
			material.set_shader_parameter("timber_grain",FineTimber.grain())
			material.set_shader_parameter("timber_normal",load(WOOD+"fine_grained_wood_nor_gl_2k.png"))
			material.set_shader_parameter("timber_roughness_map",load(WOOD+"fine_grained_wood_rough_2k.jpg"))
			material.set_shader_parameter("timber_tint",FineTimber.legacy_tint(1.0,.62))
		material.resource_name = String(root.name)+"_TactileTimber"
		var prior: Variant = material.get_shader_parameter("timber_contrast")
		var painted := prior is float and float(prior)<.15
		material.set_shader_parameter("timber_contrast",.18 if painted else .43)
		material.set_shader_parameter("normal_depth",.20 if painted else .34)
		return material
	var standard := original.duplicate() as StandardMaterial3D
	standard.resource_name = String(root.name)+"_"+role+"_Finish"
	if role == "foundation":
		standard.normal_enabled = true
		standard.normal_scale = .64
		standard.roughness = .94
		standard.metallic_specular = .25
	else:
		# Coated metal remains dielectric at the surface; moderate glints make
		# folded edges/readily modelled rainwater goods distinct from mineral walls.
		standard.roughness = .39
		standard.metallic = .12
		standard.metallic_specular = .42
	return standard

static func _physical_uvs(original: Mesh) -> ArrayMesh:
	var result := ArrayMesh.new()
	var along := original.get_aabb().size.max_axis_index()
	for surface: int in range(original.get_surface_count()):
		var arrays := original.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv := PackedVector2Array()
		for index: int in range(positions.size()):
			var face := normals[index].abs().max_axis_index()
			var across := (along+1)%3
			for axis: int in range(3):
				if axis != along and axis != face: across=axis
			var length_axis := along
			if face == along: length_axis=(along+2)%3
			uv.append(Vector2(positions[index][across],positions[index][length_axis]))
		arrays[Mesh.ARRAY_TEX_UV] = uv
		var temp := ArrayMesh.new()
		temp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var tool := SurfaceTool.new()
		tool.create_from(temp,0)
		tool.generate_tangents()
		tool.commit(result)
		result.surface_set_material(surface,original.surface_get_material(surface))
	return result

