extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")
const BakeCache = preload("res://scripts/shinrai_mesh_bake_cache.gd")
# Supplied assets only. Install after all original terrain and route services.
var installed := false
var park: Node3D
var terrain: Node3D
var trails: Node
var detail: Node
var tree_audit: Array[Dictionary] = []
var height_audit: Array[Dictionary] = []
var plant_audit: Array[Dictionary] = []
var trees: Array[Node3D] = []
var centres: Array[Vector2] = []
var rng := RandomNumberGenerator.new()
var total_trees := 0
var baseline_trees := 0

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	call_deferred("install")

func tree_root(node: Node3D) -> bool:
	if node.has_meta("midori_jogoss_sakura"): return true
	var label := String(node.name)
	for prefix in ["ReferenceBroadleaf_","ReferencePine_","MicroGrove","MainlandPineSapling_","IslandTree_","DenseSakura_","Free3DJapaneseMaple_","SparseGapTree_"]:
		if label.begins_with(prefix): return true
	return false

func clear(p: Vector2,radius: float) -> bool:
	if not detail._is_lawn_position(p.x,p.y): return false
	if not park._is_vegetation_clear(Vector3(p.x/2.0,0,p.y/2.0),radius*.5+.20): return false
	if trails.distance_to_path(p)<radius+1.8: return false
	for side in range(8):
		var q := p+Vector2(radius,0).rotated(side*TAU/8.0)
		if not detail._is_lawn_position(q.x,q.y): return false
	# One probe sphere per radius (a new Shape3D per call created and freed a
	# physics shape each time); the query itself is unchanged.
	var probe_radius := minf(.35,radius)
	if not _probe_spheres.has(probe_radius):
		var sphere := SphereShape3D.new()
		sphere.radius=probe_radius
		_probe_spheres[probe_radius]=sphere
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=_probe_spheres[probe_radius]
	query.collision_mask=1
	query.transform.origin=Vector3(p.x,terrain.height_at(p)+.65,p.y)
	return park.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

var _probe_spheres: Dictionary = {}
## Ground positions of `trees`, read once when each tree joins the list (nothing
## moves them while this synchronous install runs), plus a 8 m grid of them.
var tree_points := PackedVector2Array()
var _tree_grid: Dictionary = {}
var _tree_grid_count := -1
const TREE_CELL_M := 8.0

func _add_tree(tree: Node3D) -> void:
	trees.append(tree)
	tree_points.append(Vector2(tree.global_position.x,tree.global_position.z))

func nearest_tree(p: Vector2) -> float:
	var nearest := INF
	for q: Vector2 in tree_points: nearest=minf(nearest,p.distance_to(q))
	return nearest

## nearest_tree(p) < limit, from the grid: a tree closer than `limit` lies in a
## cell of the square of half-side limit + 1 m round p. Same distances compared.
func tree_within(p: Vector2, limit: float) -> bool:
	if _tree_grid_count != tree_points.size():
		_tree_grid.clear()
		for q: Vector2 in tree_points:
			var key := Vector2i(floori(q.x/TREE_CELL_M),floori(q.y/TREE_CELL_M))
			if not _tree_grid.has(key): _tree_grid[key]=[]
			_tree_grid[key].append(q)
		_tree_grid_count = tree_points.size()
	var reach := limit+1.0
	for z in range(floori((p.y-reach)/TREE_CELL_M),floori((p.y+reach)/TREE_CELL_M)+1):
		for x in range(floori((p.x-reach)/TREE_CELL_M),floori((p.x+reach)/TREE_CELL_M)+1):
			for q: Vector2 in _tree_grid.get(Vector2i(x,z),[]):
				if p.distance_to(q)<limit: return true
	return false

func install() -> void:
	park=get_parent()
	terrain=park.get_node("MidoriTerrain")
	detail=get_tree().root.get_node("MidoriGrassDetail")
	while not terrain.installed: await get_tree().process_frame
	while park.get_node_or_null("MidoriDesirePaths")==null: await get_tree().process_frame
	trails=park.get_node("MidoriDesirePaths")
	while not trails.finished: await get_tree().process_frame
	# Flowers and island roots also finish before we measure sparse areas. This
	# used to be 20 physics frames (one per frame while loading, ~10 s behind a
	# busy menu); wait for the two producers themselves, then let their stone
	# collisions reach the physics space before the overlap queries below.
	for producer_name: String in ["MidoriJapaneseFlowers", "MidoriIslandNature"]:
		var producer := park.get_node_or_null(producer_name)
		var deadline := Time.get_ticks_msec() + 180000
		while is_instance_valid(producer) and producer.get("installed") != true and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
	for frame in range(3): await get_tree().physics_frame
	rng.seed=205010067
	for node: Node3D in park.find_children("*","Node3D",true,false):
		if tree_root(node) and not node.is_queued_for_deletion(): _add_tree(node)
	baseline_trees=trees.size()
	var candidates: Array[Dictionary] = []
	for z in range(-154,155,10):
		for x in range(-199,200,10):
			var p := Vector2(x+rng.randf_range(-2,2),z+rng.randf_range(-2,2))
			if not clear(p,2.5): continue
			var nearest := nearest_tree(p)
			if nearest<10.0: continue
			candidates.append({"p":p,"score":nearest})
	candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.score>b.score)
	for candidate in candidates:
		if tree_audit.size()>=72: break
		var p: Vector2 = candidate.p
		var nearest := nearest_tree(p)
		if nearest<10.0: continue
		var serial := tree_audit.size()
		var pine := serial%4==1 or serial%7==3
		var sources: Array = park.pine_prototypes if pine else park.broadleaf_prototypes
		var prototype: Node3D = sources[serial%sources.size()]
		var size := .87+float(serial%5)*.035
		var radius: float = park._tree_crown_radius(prototype,size)
		var local := Vector3(p.x/2.0,0,p.y/2.0)
		if not park._is_tree_canopy_spaced(local,radius): continue
		var tree := prototype.duplicate() as Node3D
		tree.name="SparseGapTree_%03d"%serial
		tree.scale=Vector3.ONE*size
		tree.rotation.y=rng.randf_range(0,TAU)
		tree.position=Vector3(p.x,terrain.height_at(p)-.035,p.y)
		add_child(tree)
		for mesh: MeshInstance3D in tree.find_children("*","MeshInstance3D",true,false):
			mesh.visibility_range_end=180
			mesh.visibility_range_end_margin=20
		var body := StaticBody3D.new()
		body.name="TrunkCollision"
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius=.20 if pine else .28
		cylinder.height=2.5
		shape.shape=cylinder
		shape.position.y=1.25
		body.add_child(shape)
		tree.add_child(body)
		_add_tree(tree)
		park.occupied_tree_positions.append(Vector2(local.x,local.z))
		park.occupied_tree_is_skinny.append(pine)
		park._occupied_tree_crowns[Vector2(local.x,local.z)]=radius
		tree_audit.append({"p":p,"radius":radius,"nearest_before":nearest,"node":tree,"pine":pine})
		centres.append(p)
	# Fill genuinely sparse ground patches as well as the new groves.
	var bed_centres: Array[Vector2] = []
	for bed: MultiMeshInstance3D in park.find_children("WoodlandFillLOD0_*","MultiMeshInstance3D",true,false):
		bed_centres.append(Vector2(bed.global_position.x,bed.global_position.z))
	var ground: Array[Dictionary] = []
	for candidate in candidates:
		var p: Vector2 = candidate.p
		var distance := INF
		for bed in bed_centres: distance=minf(distance,bed.distance_to(p))
		if distance>8.5: ground.append({"p":p,"score":distance})
	ground.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.score>b.score)
	for candidate in ground:
		if centres.size()>=144: break
		var p: Vector2 = candidate.p
		var crowded := false
		for centre in centres:
			if p.distance_to(centre)<10: crowded=true; break
		if not crowded: centres.append(p)
	add_understory()
	naturalize_review_grove()
	# Deterministic selection over the final installed tree population.
	trees.sort_custom(func(a:Node3D,b:Node3D)->bool:return ("%.3f,%.3f"%[a.global_position.x,a.global_position.z]).sha256_text()<("%.3f,%.3f"%[b.global_position.x,b.global_position.z]).sha256_text())
	total_trees=trees.size()
	for i in range(roundi(total_trees*.12)):
		var tree := trees[i]
		var before: Vector3 = tree.scale
		var position_before := tree.global_position
		tree.scale.y*=1.07
		tree.set_meta("seven_percent_taller",true)
		height_audit.append({"node":tree,"before":before,"position":position_before})
	installed=true
	print("SPARSE_VEGETATION_READY baseline_trees=",baseline_trees," added_trees=",tree_audit.size()," final_trees=",total_trees," taller_trees=",height_audit.size()," height_factor=1.07 plants=",plant_audit.size()," pockets=",centres.size())

func add_understory() -> void:
	var sources: Array = [park.forest_floor_bush_prototypes[0],park.midnight_fern_prototype,park.emerald_fountain_grass_prototype,park.lilac_prototypes[1]]
	var groups: Array = [[],[],[],[]]
	var boxes: Array[AABB] = []
	for source: Node3D in sources: boxes.append(park._vegetation_visual_bounds(source).bounds)
	for centre in centres:
		var placed := 0
		for attempt in range(180):
			if placed>=32: break
			var kind: int = [0,1,1,2,0,1,2,3][placed%8]
			var box := boxes[kind]
			var height: float = [.95,.65,.75,1.1][kind]*rng.randf_range(.85,1.15)
			var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*height/box.size.y)
			var footprint := Transform3D(basis,Vector3.ZERO)*box
			var radius := Vector2(footprint.size.x,footprint.size.z).length()*.5
			var p := centre+Vector2(rng.randf_range(-6.5,6.5),rng.randf_range(-5,5))
			if tree_within(p,radius+.8) or not clear(p,radius+.15): continue
			var crowded := false
			for prior in plant_audit:
				if p.distance_to(prior.p)<maxf(.7,(radius+prior.radius)*.58): crowded=true; break
			if crowded: continue
			var anchor := Vector3(footprint.get_center().x,footprint.position.y,footprint.get_center().z)
			var t := Transform3D(basis,Vector3(p.x,terrain.height_at(p)+.012,p.y)-anchor)
			groups[kind].append(t)
			plant_audit.append({"p":p,"radius":radius,"height":height,"kind":kind})
			placed+=1
	for kind in range(sources.size()):
		var cells: Dictionary = {}
		for t: Transform3D in groups[kind]:
			var cell := Vector2i(floori(t.origin.x/32.0),floori(t.origin.z/32.0))
			if not cells.has(cell): cells[cell]=[]
			cells[cell].append(t)
		for part: MeshInstance3D in sources[kind].find_children("*","MeshInstance3D",true,false):
			if part.mesh==null or groups[kind].is_empty(): continue
			var shared := BakeCache.baked_from(part)
			var bake_key := BakeCache.group_key()
			var relative: Transform3D = park._vegetation_relative_transform(part,sources[kind])
			for cell: Vector2i in cells:
				var origin := Vector3(cell.x*32+16,0,cell.y*32+16)
				var mm := MultiMesh.new()
				mm.transform_format=MultiMesh.TRANSFORM_3D
				mm.mesh=shared
				mm.instance_count=cells[cell].size()
				for i in range(mm.instance_count):
					var t: Transform3D = cells[cell][i]*relative
					t.origin-=origin
					mm.set_instance_transform(i,t)
				var batch := MultiMeshInstance3D.new()
				batch.name="SparseUnderstory_%s_%d"%[kind,get_child_count()]
				batch.multimesh=mm
				BakeCache.tag(batch,bake_key)
				batch.position=origin
				batch.visibility_range_end=115
				batch.visibility_range_end_margin=15
				add_child(batch)

# Bounded placement correction of the actual .52 m lattice producer.
# Derive LOD decisions from LOD0 roots, so no LOD changes density or jumps position.
func naturalize_review_grove() -> void:
	var pivot := Vector2(-164.0,-40.0)
	var changed := 0
	var removed := 0
	var generator := RandomNumberGenerator.new()
	generator.seed=2050102602
	for source: MultiMeshInstance3D in park.find_children("WoodlandFillLOD0_*","MultiMeshInstance3D",true,false):
		var original := source.multimesh
		if original==null: continue
		var bounds := original.mesh.get_aabb()
		var anchor := Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
		var edits: Dictionary = {}
		for index in range(original.instance_count):
			var t := original.get_instance_transform(index)
			var root := source.global_transform*t*anchor
			var p := Vector2(root.x,root.z)
			if p.distance_to(pivot)>24.0: continue
			# Coherent density lobes leave open leaf-litter windows, with a soft outer taper.
			var lobe := .5+.25*sin(p.x*.31+p.y*.17)+.25*cos(p.y*.37-p.x*.13)
			var chance := lerpf(.48,.90,lobe)
			if generator.randf()>chance:
				edits[index]=null
				removed+=1
				continue
			var q := p+Vector2(generator.randf_range(-.27,.27),generator.randf_range(-.27,.27))
			if q.distance_to(pivot)>24.0 or not clear(q,.62) or tree_within(q,1.35):
				# Keep a safe authored root when a displaced candidate fails.
				q=p
			var yaw := generator.randf_range(-PI,PI)
			var old_scale := t.basis.get_scale()
			var factor := generator.randf_range(.76,1.0)
			var basis := Basis(Vector3.UP,yaw).scaled(old_scale*factor)
			var target := Vector3(q.x,terrain.height_at(q)+.012,q.y)
			var local_root := source.to_local(target)
			edits[index]=Transform3D(basis,local_root-basis*anchor)
			changed+=1
		if edits.is_empty(): continue
		for lod in range(3):
			var label := String(source.name).replace("LOD0_","LOD%d_"%lod)
			var batch := source.get_parent().get_node_or_null(NodePath(label)) as MultiMeshInstance3D
			if batch==null or batch.multimesh.instance_count!=original.instance_count: continue
			var copy := batch.multimesh.duplicate() as MultiMesh
			var transforms: Array[Transform3D] = []
			for index in range(copy.instance_count):
				if edits.has(index):
					if edits[index]!=null: transforms.append(edits[index])
				else: transforms.append(copy.get_instance_transform(index))
			copy.instance_count=transforms.size()
			for index in range(transforms.size()): copy.set_instance_transform(index,transforms[index])
			batch.multimesh=copy
	park.set_meta("natural_grove_review",{"pivot":pivot,"radius":24.0,"changed":changed,"removed":removed,"added":0})
	print("NATURAL_GROVE_REVIEW changed=",changed," removed=",removed," added=0 radius=24")
