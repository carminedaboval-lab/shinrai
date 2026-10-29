extends RefCounted
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")
## Reuse supplied meshes and placements; cull distant detail in small spatial cells.
const CELL := 4.0

static func category(path: String) -> String:
	var p := path.to_lower()
	if "grass" in p or "woodlandfilllod" in p: return "grass"
	if "broadleaf" in p or "pine" in p or "sakura" in p or "maple" in p: return "trees"
	if "woodland" in p or "fern" in p or "lilac" in p or "plantedbed" in p or "sparseunderstory" in p: return "other_planting"
	if "policedrone" in p or "park_scale_review" in p: return "actors"
	return "other"

static func plant_kind(node: Node) -> String:
	var path := str(node.get_path()).to_lower()
	if "japaneseflowers" in path or "iris" in path or "azalea" in path: return "flowers"
	return category(path)

static func install(park: Node3D, mode: String = "distance") -> Dictionary:
	if park.has_meta("midori_distance_detail"): return park.get_meta("midori_distance_detail")
	var container := Node3D.new()
	container.name = "MidoriDistanceDetail"
	container.hide()
	park.add_child(container)
	container.top_level = true
	container.global_transform = Transform3D.IDENTITY
	var groups: Dictionary = {}
	var hidden: Array[MultiMeshInstance3D] = []
	var instance_count := 0
	var max_world_error := 0.0
	var max_basis_error := 0.0
	var source_count := 0
	for source: MultiMeshInstance3D in park.find_children("*","MultiMeshInstance3D",true,false):
		var kind := plant_kind(source)
		if kind not in ["grass","flowers","other_planting"] or not source.is_visible_in_tree(): continue
		var mm := source.multimesh
		if mm==null or mm.mesh==null or mm.transform_format!=MultiMesh.TRANSFORM_3D: continue
		if source.visibility_parent!=NodePath(): continue
		if source.get_script()!=null: continue
		var material_id := source.material_override.get_instance_id() if source.material_override!=null else 0
		var overlay_id := source.material_overlay.get_instance_id() if source.material_overlay!=null else 0
		var signature := str([kind,mm.mesh.get_instance_id(),material_id,overlay_id,source.layers,source.cast_shadow,source.gi_mode,source.transparency,source.sorting_offset,source.sorting_use_aabb_center,source.visibility_range_begin,source.visibility_range_end,source.visibility_range_begin_margin,source.visibility_range_end_margin,source.visibility_range_fade_mode,source.lod_bias,source.extra_cull_margin,source.ignore_occlusion_culling,mm.use_colors,mm.use_custom_data])
		var count := mm.instance_count if mm.visible_instance_count<0 else mm.visible_instance_count
		for i in count:
			if i % 256 == 0: await LoadingBudget.checkpoint(park)
			var world: Transform3D=source.global_transform*mm.get_instance_transform(i)
			var cell := Vector2i(floori(world.origin.x/CELL),floori(world.origin.z/CELL))
			var key := signature+":"+str(cell)
			if not groups.has(key):
				groups[key]={"source":source,"kind":kind,"cell":cell,"transforms":[],"colors":[],"custom":[]}
			var row: Dictionary=groups[key]
			row.transforms.append(world)
			if mm.use_colors: row.colors.append(mm.get_instance_color(i))
			if mm.use_custom_data: row.custom.append(mm.get_instance_custom_data(i))
			instance_count+=1
		hidden.append(source)
		source_count+=1
	var chunks := 0
	var restored_instances := 0
	for key in groups:
		await LoadingBudget.checkpoint(park)
		var row: Dictionary=groups[key]
		var source: MultiMeshInstance3D=row.source
		var original := source.multimesh
		var origin := Vector3((row.cell.x+.5)*CELL,0,(row.cell.y+.5)*CELL)
		var mesh := MultiMesh.new()
		mesh.transform_format=MultiMesh.TRANSFORM_3D
		mesh.use_colors=original.use_colors
		mesh.use_custom_data=original.use_custom_data
		mesh.mesh=original.mesh
		mesh.instance_count=row.transforms.size()
		for i in mesh.instance_count:
			if i % 256 == 0: await LoadingBudget.checkpoint(park)
			var world: Transform3D=row.transforms[i]
			var local := world
			local.origin-=origin
			mesh.set_instance_transform(i,local)
			if mesh.use_colors: mesh.set_instance_color(i,row.colors[i])
			if mesh.use_custom_data: mesh.set_instance_custom_data(i,row.custom[i])
			var roundtrip := mesh.get_instance_transform(i)
			roundtrip.origin+=origin
			max_world_error=maxf(max_world_error,roundtrip.origin.distance_to(world.origin))
			for axis in 3: max_basis_error=maxf(max_basis_error,roundtrip.basis[axis].distance_to(world.basis[axis]))
			restored_instances+=1
		var chunk := MultiMeshInstance3D.new()
		chunk.name="%s_Cell_%d" % [row.kind,chunks]
		chunk.multimesh=mesh
		chunk.position=origin
		chunk.material_override=source.material_override
		chunk.material_overlay=source.material_overlay
		chunk.layers=source.layers
		chunk.cast_shadow=source.cast_shadow
		chunk.gi_mode=source.gi_mode
		chunk.lod_bias=source.lod_bias
		chunk.extra_cull_margin=source.extra_cull_margin
		chunk.transparency=source.transparency
		chunk.sorting_offset=source.sorting_offset
		chunk.sorting_use_aabb_center=source.sorting_use_aabb_center
		chunk.ignore_occlusion_culling=source.ignore_occlusion_culling
		chunk.visibility_range_begin=source.visibility_range_begin
		chunk.visibility_range_end=source.visibility_range_end
		chunk.visibility_range_begin_margin=source.visibility_range_begin_margin
		chunk.visibility_range_end_margin=source.visibility_range_end_margin
		chunk.visibility_range_fade_mode=source.visibility_range_fade_mode
		if mode!="partition":
			var maximum := 44.0 if row.kind=="grass" else (38.0 if row.kind=="flowers" else 52.0)
			if chunk.visibility_range_end==0 or chunk.visibility_range_end>maximum: chunk.visibility_range_end=maximum
			# Preserve the existing near/mid meshes and thresholds; only shorten far detail.
			# Retain the source fade/hysteresis width at the existing far cutoff.
			chunk.visibility_range_end_margin=source.visibility_range_end_margin
			if chunk.visibility_range_end<=chunk.visibility_range_begin:
				chunk.visibility_range_end=chunk.visibility_range_begin+6.0
		container.add_child(chunk)
		chunks+=1
	if instance_count!=restored_instances or max_world_error>.0001 or max_basis_error>.0001:
		container.queue_free()
		return {"error":"Candidate transform validation failed","source_instances":instance_count,"copied_instances":restored_instances,"max_world_position_error_m":max_world_error,"max_world_basis_error":max_basis_error}
	# Publish only after parity validates: no yields during source/chunk visibility swap.
	for source in hidden: source.hide()
	container.show()
	var shadow_faded := 0
	if mode!="partition":
		for light: Light3D in park.find_children("WarmWhitePathPool","Light3D",true,false):
			light.distance_fade_enabled=true
			light.distance_fade_begin=65.0
			light.distance_fade_shadow=25.0
			light.distance_fade_length=15.0
			shadow_faded+=1
	var report: Dictionary={"cell_m":CELL,"source_batches":source_count,"chunks":chunks,"source_instances":instance_count,"copied_instances":restored_instances,"max_world_position_error_m":max_world_error,"max_world_basis_error":max_basis_error,"shadow_faded_main_lamps":shadow_faded,"near_meshes_unchanged":true,"native_screen_resolution_unchanged":true}
	park.set_meta("midori_distance_detail",report)
	return report


