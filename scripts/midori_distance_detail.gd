extends RefCounted
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")
const StartupTrace = preload("res://scripts/startup_trace.gd")
## Reuse supplied meshes and placements; cull distant detail in small spatial cells.
## 12 m cells keep culling well inside the 38-52 m fade while issuing roughly
## a ninth of the draw calls that 4 m cells did (each cell is one draw per pass).
const CELL := 12.0

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

## Floats per instance in MultiMesh.buffer: a 3x4 row-major transform, then RGBA
## colour and RGBA custom data when used (the layout the renderer stores).
static func _stride(use_colors: bool, use_custom: bool) -> int:
	return 12 + (4 if use_colors else 0) + (4 if use_custom else 0)

## The instance transform exactly as MultiMesh.get_instance_transform returns it
## (the same stored float32 values; basis rows are buffer rows).
static func _buffer_transform(buffer: PackedFloat32Array, o: int) -> Transform3D:
	return Transform3D(Vector3(buffer[o], buffer[o+4], buffer[o+8]), Vector3(buffer[o+1], buffer[o+5], buffer[o+9]), Vector3(buffer[o+2], buffer[o+6], buffer[o+10]), Vector3(buffer[o+3], buffer[o+7], buffer[o+11]))

## The first count instances in MultiMesh.buffer layout, read through
## get_instance_transform / color / custom_data (main thread).
static func _instance_buffer(mm: MultiMesh, count: int, stride: int) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(count * stride)
	for i: int in range(count):
		var t := mm.get_instance_transform(i)
		var o := i * stride
		buffer[o] = t.basis.x.x; buffer[o+1] = t.basis.y.x; buffer[o+2] = t.basis.z.x; buffer[o+3] = t.origin.x
		buffer[o+4] = t.basis.x.y; buffer[o+5] = t.basis.y.y; buffer[o+6] = t.basis.z.y; buffer[o+7] = t.origin.y
		buffer[o+8] = t.basis.x.z; buffer[o+9] = t.basis.y.z; buffer[o+10] = t.basis.z.z; buffer[o+11] = t.origin.z
		var c := o + 12
		if mm.use_colors:
			var color := mm.get_instance_color(i)
			buffer[c] = color.r; buffer[c+1] = color.g; buffer[c+2] = color.b; buffer[c+3] = color.a
			c += 4
		if mm.use_custom_data:
			var data := mm.get_instance_custom_data(i)
			buffer[c] = data.r; buffer[c+1] = data.g; buffer[c+2] = data.b; buffer[c+3] = data.a
	return buffer

## WorkerThreadPool task (pure data): one contiguous run of sources, grouped by
## (signature id, cell) in first-seen order, exactly as the sequential loop did.
static func _group_sources(chunk: int, jobs: Array, ranges: Array, results: Array) -> void:
	var groups: Dictionary = results[chunk]
	var span: Vector2i = ranges[chunk]
	for job_index: int in range(span.x, span.y):
		var job: Dictionary = jobs[job_index]
		var buffer: PackedFloat32Array = job.buffer
		var source_transform: Transform3D = job.transform
		var signature_id: int = job.signature_id
		var use_colors: bool = job.use_colors
		var use_custom: bool = job.use_custom
		var stride: int = job.stride
		for i: int in range(int(job.count)):
			var o := i * stride
			var world: Transform3D = source_transform * _buffer_transform(buffer, o)
			var cell := Vector2i(floori(world.origin.x/CELL),floori(world.origin.z/CELL))
			var key := Vector3i(signature_id,cell.x,cell.y)
			var row: Dictionary = groups.get(key, {})
			if row.is_empty():
				row = {"job":job_index,"cell":cell,"transforms":[],"colors":[],"custom":[]}
				groups[key] = row
			row.transforms.append(world)
			if use_colors: row.colors.append(Color(buffer[o+12], buffer[o+13], buffer[o+14], buffer[o+15]))
			if use_custom:
				var c := o + (16 if use_colors else 12)
				row.custom.append(Color(buffer[c], buffer[c+1], buffer[c+2], buffer[c+3]))

## WorkerThreadPool task (pure data): one cell's MultiMesh buffer, with each
## instance relative to the cell centre, plus the round-trip error of that copy
## (a stored float32 transform reads back exactly as written).
static func _build_cell(index: int, rows: Array) -> void:
	var row: Dictionary = rows[index]
	var cell: Vector2i = row.cell
	var origin := Vector3((cell.x+.5)*CELL,0,(cell.y+.5)*CELL)
	var transforms: Array = row.transforms
	var colors: Array = row.colors
	var custom: Array = row.custom
	var use_colors: bool = row.use_colors
	var use_custom: bool = row.use_custom
	var stride := _stride(use_colors, use_custom)
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * stride)
	var max_world := 0.0
	var max_basis := 0.0
	for i: int in range(transforms.size()):
		var world: Transform3D = transforms[i]
		var local := world
		local.origin -= origin
		var o := i * stride
		var b := local.basis
		buffer[o] = b.x.x; buffer[o+1] = b.y.x; buffer[o+2] = b.z.x; buffer[o+3] = local.origin.x
		buffer[o+4] = b.x.y; buffer[o+5] = b.y.y; buffer[o+6] = b.z.y; buffer[o+7] = local.origin.y
		buffer[o+8] = b.x.z; buffer[o+9] = b.y.z; buffer[o+10] = b.z.z; buffer[o+11] = local.origin.z
		var c := o + 12
		if use_colors:
			var color: Color = colors[i]
			buffer[c] = color.r; buffer[c+1] = color.g; buffer[c+2] = color.b; buffer[c+3] = color.a
			c += 4
		if use_custom:
			var data: Color = custom[i]
			buffer[c] = data.r; buffer[c+1] = data.g; buffer[c+2] = data.b; buffer[c+3] = data.a
		var roundtrip := _buffer_transform(buffer, o)
		roundtrip.origin += origin
		max_world = maxf(max_world, roundtrip.origin.distance_to(world.origin))
		for axis in 3: max_basis = maxf(max_basis, roundtrip.basis[axis].distance_to(world.basis[axis]))
	# Each task writes only its own row (no shared container is written).
	row["built"] = [buffer, max_world, max_basis, transforms.size()]

## Runs a group task on the worker pool while the main thread keeps its frames.
static func _await_group(park: Node, task: Callable, elements: int) -> void:
	if elements <= 0: return
	var id := WorkerThreadPool.add_group_task(task, elements, -1, true, "MidoriDistanceDetail")
	while not WorkerThreadPool.is_group_task_completed(id):
		if is_instance_valid(park) and park.is_inside_tree(): await park.get_tree().process_frame
		else: OS.delay_msec(1)
	WorkerThreadPool.wait_for_group_task_completion(id)

static func install(park: Node3D, mode: String = "distance") -> Dictionary:
	if park.has_meta("midori_distance_detail"): return park.get_meta("midori_distance_detail")
	var container := Node3D.new()
	container.name = "MidoriDistanceDetail"
	container.hide()
	park.add_child(container)
	container.top_level = true
	container.global_transform = Transform3D.IDENTITY
	var hidden: Array[MultiMeshInstance3D] = []
	var instance_count := 0
	var max_world_error := 0.0
	var max_basis_error := 0.0
	var source_count := 0
	var trace := StartupTrace.begin()
	var sources := park.find_children("*","MultiMeshInstance3D",true,false)
	trace = StartupTrace.finish("distance.scan", trace)
	# Group key: (signature id, cell). One id per distinct signature string, so the
	# groups and their first-seen order are exactly those of signature+":"+cell.
	var signature_ids: Dictionary = {}
	# Main thread: which sources are copied, in order, with a copy of each one's
	# instance buffer. Workers then group the instances (pure data).
	var jobs: Array = []
	var job_sources: Array[MultiMeshInstance3D] = []
	var job_kinds: Array[String] = []
	await LoadingBudget.checkpoint(park)
	for source_index: int in range(sources.size()):
		# Same sources in the same order; the loading budget only splits frames.
		if source_index % 64 == 63: await LoadingBudget.checkpoint(park)
		var source := sources[source_index] as MultiMeshInstance3D
		if not is_instance_valid(source): continue
		var kind := plant_kind(source)
		if kind not in ["grass","flowers","other_planting"] or not source.is_visible_in_tree(): continue
		var mm := source.multimesh
		if mm==null or mm.mesh==null or mm.transform_format!=MultiMesh.TRANSFORM_3D: continue
		if source.visibility_parent!=NodePath(): continue
		if source.get_script()!=null: continue
		var material_id := source.material_override.get_instance_id() if source.material_override!=null else 0
		var overlay_id := source.material_overlay.get_instance_id() if source.material_overlay!=null else 0
		# Batches built from a shared baked mesh carry their former private copy's
		# identity (shinrai_mesh_bake_cache.gd GROUP_META), so grouping is unchanged.
		var mesh_identity: Variant = source.get_meta(&"bake_group", mm.mesh.get_instance_id())
		var signature := str([kind,mesh_identity,material_id,overlay_id,source.layers,source.cast_shadow,source.gi_mode,source.transparency,source.sorting_offset,source.sorting_use_aabb_center,source.visibility_range_begin,source.visibility_range_end,source.visibility_range_begin_margin,source.visibility_range_end_margin,source.visibility_range_fade_mode,source.lod_bias,source.extra_cull_margin,source.ignore_occlusion_culling,mm.use_colors,mm.use_custom_data])
		var count := mm.instance_count if mm.visible_instance_count<0 else mm.visible_instance_count
		if not signature_ids.has(signature): signature_ids[signature] = signature_ids.size()
		if count > 0:
			var stride := _stride(mm.use_colors,mm.use_custom_data)
			var buffer: PackedFloat32Array = mm.buffer
			# No readable buffer (the headless dummy renderer keeps none): the same
			# layout from the per-instance getters the sequential loop used.
			if buffer.size() < count * stride: buffer = _instance_buffer(mm, count, stride)
			jobs.append({"buffer":buffer,"transform":source.global_transform,"signature_id":signature_ids[signature],"count":count,"use_colors":mm.use_colors,"use_custom":mm.use_custom_data,"stride":stride})
			job_sources.append(source)
			job_kinds.append(kind)
			instance_count += count
		hidden.append(source)
		source_count+=1
	trace = StartupTrace.finish("distance.sources", trace)
	# Contiguous runs of sources of about equal instance totals, one per worker.
	# The merge below walks them in order, so the result never depends on how
	# many runs there are or which finishes first.
	var runs := clampi(OS.get_processor_count() - 1, 1, 8)
	var ranges: Array = []
	var results: Array = []
	var start := 0
	var done := 0
	for run_index: int in range(runs):
		var target := int(ceil(float(instance_count) * float(run_index + 1) / float(runs)))
		var stop := start
		while stop < jobs.size() and (done < target or stop == start):
			done += int(jobs[stop].count)
			stop += 1
		if run_index == runs - 1: stop = jobs.size()
		if stop > start:
			ranges.append(Vector2i(start, stop))
			results.append({})
		start = stop
	await _await_group(park, _group_sources.bind(jobs, ranges, results), ranges.size())
	# Merge: first-seen key order across the runs in source order; each group's
	# instances concatenated in the same order (identical to one sequential pass).
	var groups: Dictionary = {}
	for part: Dictionary in results:
		for key: Vector3i in part:
			var row: Dictionary = part[key]
			var merged: Dictionary = groups.get(key, {})
			if merged.is_empty():
				var job: Dictionary = jobs[int(row.job)]
				groups[key] = {"source":job_sources[int(row.job)],"kind":job_kinds[int(row.job)],"cell":row.cell,"transforms":row.transforms,"colors":row.colors,"custom":row.custom,"use_colors":job.use_colors,"use_custom":job.use_custom}
			else:
				merged.transforms.append_array(row.transforms)
				merged.colors.append_array(row.colors)
				merged.custom.append_array(row.custom)
	jobs.clear()
	results.clear()
	trace = StartupTrace.finish("distance.group", trace)
	var rows: Array = groups.values()
	await _await_group(park, _build_cell.bind(rows), rows.size())
	trace = StartupTrace.finish("distance.cell_buffers", trace)
	var chunks := 0
	var restored_instances := 0
	for row_index: int in range(rows.size()):
		await LoadingBudget.checkpoint(park)
		var row: Dictionary=rows[row_index]
		var cell_data: Array = row.built
		var source: MultiMeshInstance3D=row.source
		var original := source.multimesh
		var origin := Vector3((row.cell.x+.5)*CELL,0,(row.cell.y+.5)*CELL)
		var mesh := MultiMesh.new()
		mesh.transform_format=MultiMesh.TRANSFORM_3D
		mesh.use_colors=original.use_colors
		mesh.use_custom_data=original.use_custom_data
		mesh.mesh=original.mesh
		mesh.instance_count=int(cell_data[3])
		mesh.buffer=cell_data[0]
		max_world_error=maxf(max_world_error,float(cell_data[1]))
		max_basis_error=maxf(max_basis_error,float(cell_data[2]))
		restored_instances+=int(cell_data[3])
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
	trace = StartupTrace.finish("distance.chunks", trace)
	if instance_count!=restored_instances or max_world_error>.0001 or max_basis_error>.0001:
		container.queue_free()
		return {"error":"Candidate transform validation failed","source_instances":instance_count,"copied_instances":restored_instances,"max_world_position_error_m":max_world_error,"max_world_basis_error":max_basis_error}
	# Publish only after parity validates: no yields during source/chunk visibility swap.
	for source in hidden: source.hide()
	container.show()
	# The copied sources, as instance ids: the end-of-boot consolidation
	# (scripts/shinrai_consolidate.gd) releases exactly these, nothing re-derived.
	park.set_meta(&"midori_distance_hidden_sources", PackedInt64Array(hidden.map(func(node: MultiMeshInstance3D) -> int: return node.get_instance_id())))
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
