extends Node
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")
const StartupTrace = preload("res://scripts/startup_trace.gd")
# Placement only: reuse the installed grass meshes, materials and LOD settings.
# The bounded beds fill woodland gaps while preserving functional clearings.
const MAX_ADDED_BEDS := 620

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	var park := get_parent() as Node3D
	for frame in range(180):
		if not park.find_children("JapaneseForestGrassDrift_*","MultiMeshInstance3D",true,false).is_empty():
			await apply(park)
			var companions := preload("res://scripts/midori_woodland_companions.gd").new()
			companions.name = "WoodlandCompanionPockets"
			park.add_child(companions)
			var paths := preload("res://scripts/midori_desire_paths.gd").new()
			paths.name = "MidoriDesirePaths"
			park.add_child(paths)
			return
		await get_tree().process_frame
	push_warning("UNDERSTORY_PLACEMENT: approved grass not available")

static func apply(park: Node3D) -> Dictionary:
	var _boot_tick := StartupTrace.begin()
	if park.has_meta("understory_placement"):
		return park.get_meta("understory_placement")
	var detail: Node=park.get_tree().root.get_node("MidoriGrassDetail")
	var beds:=park.find_children("JapaneseForestGrassDrift_*","MultiMeshInstance3D",true,false)
	if beds.is_empty():
		return {}
	var templates:Array[MultiMeshInstance3D]=[beds[0],park.find_child("ForestGrassLOD1_000",true,false),park.find_child("ForestGrassLOD2_000",true,false)]
	if templates.has(null):
		return {}
	var parent:=beds[0].get_parent() as Node3D
	var bounds:=templates[0].multimesh.mesh.get_aabb()
	var anchor:=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	var centres:Array[Vector2]=[]
	for bed:MultiMeshInstance3D in beds:
		await LoadingBudget.checkpoint(park)
		centres.append(Vector2(bed.global_position.x,bed.global_position.z))
	var rng:=RandomNumberGenerator.new()
	rng.seed=205010059
	var trees:Array=park.occupied_tree_positions
	var world_trunks:Array[Vector2]=[]
	for trunk:Vector2 in trees:world_trunks.append(trunk*2.0)
	var trunk_index:=_build_trunk_index(world_trunks)
	var added:=0
	var mounds:=0
	var minimum_trunk:=INF
	var added_positions:Array[Vector2]=[]
	var new_fill_centres:Array[Vector2]=[]
	var asset_sockets:Array[Vector2]=[]
	var sockets:=park.find_child('PlannedPropSockets',true,false)
	if sockets!=null:
		for marker:Node3D in sockets.get_children(): asset_sockets.append(Vector2(marker.global_position.x,marker.global_position.z))
	# Placement is deterministic (fixed seed, fixed park), so the result is cached
	# on disk. The key covers every input: trees, existing beds, sockets and the
	# source of each script whose predicates decide placement.
	var cache_key := _cache_key(trees,centres,asset_sockets)
	var cached: Variant = _load_cache(cache_key)
	var recorded: Array = []
	if cached != null:
		for bed: Dictionary in cached.beds:
			var cached_transforms: Array[Transform3D] = []
			cached_transforms.assign(bed.transforms)
			var cached_positions: Array[Vector2] = []
			cached_positions.assign(bed.positions)
			_add_bed(park,parent,templates,bed.centre,cached_transforms,added,bed.get("buffer",PackedFloat32Array()))
			centres.append(bed.centre)
			if bed.gap_fill: new_fill_centres.append(bed.centre)
			added_positions.append_array(cached_positions)
			_index_positions(detail,cached_positions)
			added+=1
			mounds+=cached_transforms.size()
			await LoadingBudget.checkpoint(park)
		minimum_trunk=float(cached.minimum_trunk)
	# Coprime stepping spreads the budget across the entire tree registry.
	for step in range(0 if cached != null else trees.size()*3+28*22):
		await LoadingBudget.checkpoint(park)
		var tree:Vector2=trees[(step*137)%trees.size()]*2.0
		var angle:=rng.randf_range(0,TAU)
		var centre:=tree+Vector2(2.8,0).rotated(angle)
		var gap_fill:=step>=trees.size()*3
		if gap_fill:
			var cell:=(step-trees.size()*3)*137%(28*22)
			centre=Vector2(-196+14*(cell%28),-147+14*int(cell/28))+Vector2(rng.randf_range(-5,5),rng.randf_range(-5,5))
		var crowded:=false
		for prior in centres:
			if centre.distance_to(prior)<(12.0 if gap_fill else 6.0):
				crowded=true
				break
		if crowded or not detail._is_lawn_position(centre.x,centre.y):
			continue
		if gap_fill:
			for socket in asset_sockets:
				if centre.distance_to(socket)<11.0: crowded=true
			if crowded: continue
		var transforms:Array[Transform3D]=[]
		var positions:Array[Vector2]=[]
		for z in range(-10,11):
			for x in range(-14,15):
				# Scattered, not planted in rows: wide jitter, random gaps, and a bed
				# that thins out toward its rim instead of ending in a hard ellipse.
				var offset:=Vector2(x*.52+rng.randf_range(-.40,.40),z*.52+rng.randf_range(-.40,.40))
				if rng.randf()<.28:
					continue
				var edge:=pow(offset.x/7.2,2)+pow(offset.y/5.2,2)
				var scallop:=.12*sin(offset.x*1.6+angle)+.10*cos(offset.y*2.1-angle)
				if edge>rng.randf_range(.85,1.10)+scallop:
					continue
				if edge>.45 and rng.randf()<(edge-.45)*.9:
					continue
				var p:=centre+offset.rotated(angle)
				if not detail._is_lawn_position(p.x,p.y) or not park._is_vegetation_clear(Vector3(p.x/2.0,0,p.y/2.0),.45):
					continue
				var clear:=true
				var nearest:=_nearest_indexed_trunk(p,trunk_index)
				if nearest<1.15:
					continue
				# Check the full mound footprint against lawn exclusions as well.
				for side in range(8):
					var q:=p+Vector2(.60,0).rotated(float(side)*TAU/8.0)
					if not detail._is_lawn_position(q.x,q.y):
						clear=false
						break
				if not clear or detail._inside_forest_mound(p):
					continue
				var height:=rng.randf_range(.45,.62)*lerpf(1.0,.8,clampf(edge,0,1))
				var width:=rng.randf_range(.82,1.12)/maxf(bounds.size.x,bounds.size.z)
				var basis:=Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(width,height/bounds.size.y,width))
				transforms.append(Transform3D(basis,Vector3(p.x-centre.x,detail.GROUND_SURFACE_Y+.004,p.y-centre.y)-basis*anchor))
				positions.append(p)
				minimum_trunk=minf(minimum_trunk,nearest)
		if transforms.size()<24:
			continue
		var buffer:=_add_bed(park,parent,templates,centre,transforms,added)
		recorded.append({"centre":centre,"transforms":transforms,"positions":positions,"gap_fill":gap_fill,"buffer":buffer})
		centres.append(centre)
		if gap_fill: new_fill_centres.append(centre)
		added_positions.append_array(positions)
		_index_positions(detail,positions)
		added+=1
		mounds+=transforms.size()
		if added>=MAX_ADDED_BEDS:
			break
	StartupTrace.finish("understory.placement", _boot_tick)
	var _rm := StartupTrace.begin()
	if cached == null:
		_save_cache(cache_key,{"beds":recorded,"minimum_trunk":minimum_trunk})
	# Remove overlapping old lawn roots; all source meshes stay unchanged.
	var removed:=0
	for node in parent.get_children():
		await LoadingBudget.checkpoint(park)
		if not node is MultiMeshInstance3D or not (str(node.name).begins_with("UprightGrass") or str(node.name).begins_with("ThinUprightGrass")):
			continue
		var mm:MultiMesh=node.multimesh
		var box:=mm.mesh.get_aabb()
		var root_anchor:=Vector3(box.get_center().x,box.position.y,box.get_center().z)
		var keep:Array[Transform3D]=[]
		await LoadingBudget.checkpoint(park)
		for j in range(mm.instance_count):
			var t:=mm.get_instance_transform(j)
			var pos:Vector3=node.global_transform*t*root_anchor
			if detail._inside_forest_mound(Vector2(pos.x,pos.z)):
				removed+=1
			else:
				keep.append(t)
		mm.instance_count=keep.size()
		for j in range(keep.size()):
			mm.set_instance_transform(j,keep[j])
	StartupTrace.finish("understory.remove_old_roots", _rm)
	var report:={"added_beds":added,"gap_fill_beds":new_fill_centres.size(),"gap_fill_centres":new_fill_centres,"added_mounds":mounds,"removed_old_roots":removed,"minimum_trunk_m":minimum_trunk,"new_collisions":0,"shared_meshes_and_materials":true}
	park.set_meta("understory_placement",report)
	_boot_tick = StartupTrace.finish("vegetation.understory",_boot_tick)
	print("UNDERSTORY_PLACEMENT ",JSON.stringify(report))
	return report


# Build once per apply from the current registry. No persistent scene cache or RNG.
static func _build_trunk_index(points: Array[Vector2], depth: int=0) -> Dictionary:
	if points.size()<=16:return {"points":points}
	var axis:=depth%2
	points.sort_custom(func(a:Vector2,b:Vector2)->bool:return a[axis]<b[axis])
	var middle:=points.size()/2
	var lower:=points[0];var upper:=points[0]
	for point:Vector2 in points:lower=lower.min(point);upper=upper.max(point)
	return {"bounds":Rect2(lower,upper-lower),"axis":axis,"split":points[middle][axis],"left":_build_trunk_index(points.slice(0,middle),depth+1),"right":_build_trunk_index(points.slice(middle),depth+1)}

static func _nearest_indexed_trunk(p:Vector2,node:Dictionary,best:float=INF) -> float:
	if node.has("bounds"):
		var bounds:Rect2=node.bounds
		if p.distance_to(p.clamp(bounds.position,bounds.end))>best+.001:return best
	if node.has("points"):
		for trunk:Vector2 in node.points:best=minf(best,p.distance_to(trunk))
		return best
	var offset:float=p[int(node.axis)]-float(node.split)
	var first:Dictionary=node.left if offset<0 else node.right
	var second:Dictionary=node.right if offset<0 else node.left
	best=_nearest_indexed_trunk(p,first,best)
	# Conservative extra millimetre protects branch pruning at float boundaries.
	# Candidate distances retain the original Vector2.distance_to operation.
	if absf(offset)<=best+.001:best=_nearest_indexed_trunk(p,second,best)
	return best

const CACHE_DIR := "user://shinrai_cache/"
const CACHE_VERSION := 1

static func _add_bed(park: Node3D, parent: Node3D, templates: Array[MultiMeshInstance3D], centre: Vector2, transforms: Array[Transform3D], index: int, buffer: PackedFloat32Array = PackedFloat32Array()) -> PackedFloat32Array:
	for lod in range(3):
		var template:=templates[lod]
		var batch:=MultiMeshInstance3D.new()
		batch.name="WoodlandFillLOD%d_%03d"%[lod,index]
		var mm:=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=template.multimesh.mesh
		mm.instance_count=transforms.size()
		if buffer.size()==transforms.size()*12:
			mm.buffer=buffer
		else:
			for j in range(transforms.size()):
				mm.set_instance_transform(j,transforms[j])
			buffer=mm.buffer
		batch.multimesh=mm
		batch.material_override=template.material_override
		batch.position=Vector3(centre.x,0,centre.y)
		batch.cast_shadow=template.cast_shadow
		batch.visibility_range_begin=template.visibility_range_begin
		batch.visibility_range_end=template.visibility_range_end
		batch.visibility_range_begin_margin=template.visibility_range_begin_margin
		batch.visibility_range_end_margin=template.visibility_range_end_margin
		batch.visibility_range_fade_mode=template.visibility_range_fade_mode
		parent.add_child(batch)
	return buffer

static func _index_positions(detail: Node, positions: Array[Vector2]) -> void:
	for p in positions:
		var cell:=Vector2i(floori(p.x/2.0),floori(p.y/2.0))
		if not detail._forest_cells.has(cell):
			detail._forest_cells[cell]=[]
		detail._forest_cells[cell].append(p)

static func _cache_key(trees: Array, centres: Array[Vector2], sockets: Array[Vector2]) -> String:
	var ctx:=HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes([CACHE_VERSION,MAX_ADDED_BEDS,trees,centres,sockets]))
	for path: String in ["res://scripts/midori_understory_placement.gd","res://scripts/midori_grass_detail.gd","res://scripts/midori_park_size_blockout.gd","res://scripts/vegetation_clearance_cache.gd","res://scripts/midori_measured_bridges.gd","res://scripts/midori_bridge_walks.gd","res://scripts/midori_bridge_landings.gd"]:
		ctx.update(FileAccess.get_sha256(path).to_utf8_buffer())
	return ctx.finish().hex_encode()

static func _load_cache(key: String) -> Variant:
	var path:=CACHE_DIR+"understory_"+key+".bin"
	if not FileAccess.file_exists(path): return null
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null: return null
	var data: Variant=file.get_var()
	file.close()
	if typeof(data)!=TYPE_DICTIONARY or not data.has("beds"): return null
	return data

static func _save_cache(key: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	# One entry per park version: drop stale caches first.
	for name: String in DirAccess.get_files_at(CACHE_DIR):
		if name.begins_with("understory_"): DirAccess.remove_absolute(CACHE_DIR+name)
	var file:=FileAccess.open(CACHE_DIR+"understory_"+key+".bin",FileAccess.WRITE)
	if file==null: return
	file.store_var(data)
	file.close()

