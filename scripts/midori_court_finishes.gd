extends RefCounted
## Court-only surface treatment. Never changes shared architecture resources.
## Source maps remain unchanged; outer envelopes and collision stay intact.
const TIMBER := "res://assets/shinrai/streets/midori_frontage_construction/"
const MINERAL := "res://assets/shinrai/streets/midori_court_materials/"
const FineTimber = preload("res://scripts/midori_fine_timber.gd")
const ResidentialPaint = preload("res://scripts/midori_house_paint.gd")

static func apply(street: Node3D, root: Node3D) -> Dictionary:
	var source: Dictionary = street.get("materials")
	var render := ShaderMaterial.new()
	render.resource_name = "Court_WarmIvoryMineralRender"
	render.shader = preload("res://scripts/midori_court_render.gdshader")
	# Poly Haven White Plaster 02, Rob Tuytel, CC0, documented 1m coverage.
	# Original downloaded bytes and provenance are retained alongside the maps.
	render.set_shader_parameter("mineral_color",load(MINERAL+"white_plaster_02_diff_1k.jpg"))
	render.set_shader_parameter("mineral_normal",load(MINERAL+"white_plaster_02_nor_gl_1k.png"))
	render.set_shader_parameter("mineral_roughness",load(MINERAL+"white_plaster_02_rough_1k.jpg"))
	var wood := ShaderMaterial.new()
	wood.resource_name = "Court_FineGrainedTimber"
	wood.shader = preload("res://scripts/midori_court_timber.gdshader")
	wood.set_shader_parameter("timber_grain",FineTimber.grain())
	wood.set_shader_parameter("timber_normal",load(TIMBER+"fine_grained_wood_nor_gl_2k.png"))
	wood.set_shader_parameter("timber_roughness_map",load(TIMBER+"fine_grained_wood_rough_2k.jpg"))
	var stats := {"render_members":0,"timber_members":0,"interior_excluded":true,"envelope_unchanged":true,"cladding_end_bevel_limit_m":.006,"cladding_end_bevel_members":0}
	_finish(root,source,render,wood,stats)
	ResidentialPaint.apply(street,root)
	root.set_meta("court_surface_finish",stats)
	return stats

static func _finish(node: Node, source: Dictionary, render: ShaderMaterial, wood: ShaderMaterial, stats: Dictionary) -> void:
	var label := String(node.name)
	# The gallery room is a hard ancestry boundary; shallow residential contents
	# also retain their authored materials, including shelves and furnishings.
	if label.begins_with("Interior") or label in ["RecessShelf","ShelfObject","SmallRoomObject"]:
		return
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var material := mesh_node.material_override
		if material != null and (material in [source.get("arch_plaster"),source.get("arch_mineral")] or mesh_node.get_meta("court_envelope_render",false)):
			mesh_node.material_override = render
			stats.render_members += 1
		elif material != null and _is_timber(material,source):
			# Physical positions supply UVs, including phase shared by adjacent
			# clipped fields. Only the ≤6mm board-end bevel at artificial field
			# cuts is flattened; outer bounds/openings/board counts stay intact.
			var vertical := mesh_node.has_meta("constructed_cladding")
			mesh_node.set_meta("court_finish_source_mesh",mesh_node.mesh)
			mesh_node.set_meta("court_finish_bevel_allowed",vertical)
			mesh_node.mesh = _metre_uvs(mesh_node.mesh,mesh_node.transform,vertical)
			if vertical:
				stats.cladding_end_bevel_members += 1
			mesh_node.material_override = wood
			stats.timber_members += 1
	for child: Node in node.get_children():
		_finish(child,source,render,wood,stats)

static func _is_timber(material: Material, source: Dictionary) -> bool:
	for key: String in ["arch_cedar","arch_pale_wood","joinery_arch_cedar","joinery_arch_pale_wood","joinery_arch_cladding"]:
		if source.has(key) and source[key] == material:
			return true
	return false

static func _metre_uvs(original: Mesh, placement: Transform3D, vertical: bool) -> ArrayMesh:
	var result := ArrayMesh.new()
	var along := 1 if vertical else original.get_aabb().size.max_axis_index()
	var along_vector := Vector3.ZERO
	along_vector[along] = 1.0
	along_vector = (placement.basis * along_vector).normalized()
	for surface: int in range(original.get_surface_count()):
		var arrays := original.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if vertical:
			var bounds := original.get_aabb()
			# Every opening cut previously bevelled the ends of otherwise
			# continuous vertical boards, creating a false horizontal V joint.
			# Fill only that notch within the existing field AABB; no board is
			# lengthened past a window, storey/corner limit or outer envelope.
			for vertex: int in range(positions.size()):
				var point := positions[vertex]
				if point.y < bounds.position.y+.006:
					point.y = bounds.position.y
				elif point.y > bounds.end.y-.006:
					point.y = bounds.end.y
				positions[vertex] = point
			arrays[Mesh.ARRAY_VERTEX] = positions
		var uvs := PackedVector2Array()
		for index: int in range(positions.size()):
			var face := normals[index].abs().max_axis_index()
			var across := (along+1)%3
			for axis: int in range(3):
				if axis != along and axis != face:
					across = axis
			if face == along:
				across = (along+1)%3
			var across_vector := Vector3.ZERO
			across_vector[across] = 1.0
			across_vector = (placement.basis*across_vector).normalized()
			var p := placement*positions[index]
			var length_vector := along_vector
			if face == along:
				var end_axis := (along+2)%3
				length_vector = Vector3.ZERO
				length_vector[end_axis] = 1.0
				length_vector = (placement.basis*length_vector).normalized()
			uvs.append(Vector2(p.dot(across_vector),p.dot(length_vector)))
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var temporary := ArrayMesh.new()
		temporary.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var tool := SurfaceTool.new()
		tool.create_from(temporary,0)
		tool.generate_tangents()
		tool.commit(result)
		result.surface_set_material(surface,original.surface_get_material(surface))
	return result
