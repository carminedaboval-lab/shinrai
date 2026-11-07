extends Node3D
## Additive forest-floor planting. Authored paths, trees and terrain are retained.
const Budget = preload("res://scripts/shinrai_loading_budget.gd")
const ASSETS := "res://assets/shinrai/parks/midori_park/models/forest_floor_20261026/"
const CELL := 16.0
const TRIANGLE_BUDGET := 18000000
var installed := false
var park: Node3D
var terrain: Node
var trails: Node
var detail: Node
var rng := RandomNumberGenerator.new()
var sources: Array[Dictionary] = []
var groups: Dictionary = {}
var audit: Array[Dictionary] = []
var counts: Dictionary = {}
var occupied: Dictionary = {}
var trunks: Dictionary = {}
var additions: Dictionary = {}
var instanced_triangles := 0
var batches := 0
var lod_adjusted_batches := 0
var scanned_roots := 0
var gap_pockets := 0
var report: Dictionary = {}

func imported_lod_info(mesh: Mesh) -> Dictionary:
	var result := {"surfaces": 0, "levels": 0}
	if not mesh is ArrayMesh: return result
	# Imported ArrayMesh surfaces retain alternating error/packed-index LOD data.
	# Inspect the actual duplicated mesh, not just its import settings.
	var stored: Variant = mesh.get("_surfaces")
	if not stored is Array: return result
	for surface: Dictionary in stored:
		var lods: Variant = surface.get("lods", [])
		if not lods is Array or lods.size()%2 != 0: continue
		var levels := 0
		for i: int in range(1, lods.size(), 2):
			if lods[i] is PackedByteArray and not lods[i].is_empty(): levels += 1
		if levels > 0:
			result.surfaces += 1
			result.levels += levels
	return result

func part_lod_bias(label: String, has_lods: bool) -> float:
	if not has_lods: return 1.0
	if label in ["groundcover", "fern", "grass"]: return 0.45
	if label in ["stone", "branch"]: return 0.30
	return 1.0

func source_lod_stats() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in range(sources.size()):
		var s: Dictionary = sources[i]
		var enabled := 0
		var surfaces := 0
		var levels := 0
		for part: Dictionary in s.parts:
			if float(part.get("lod_bias", 1.0)) < 1.0: enabled += 1
			surfaces += int(part.get("lod_surfaces", 0))
			levels += int(part.get("lod_levels", 0))
		result.append({"kind": i, "label": s.label, "parts": s.parts.size(), "base_triangles": s.triangles, "lod_enabled_parts": enabled, "lod_surfaces": surfaces, "lod_levels": levels})
	return result

func _ready() -> void:
	await Budget.wait_structure(get_parent())
	park = get_parent()
	detail = get_tree().root.get_node("MidoriGrassDetail")
	terrain = park.get_node("MidoriTerrain")
	while not terrain.installed: await get_tree().process_frame
	while park.get_node_or_null("MidoriDesirePaths") == null: await get_tree().process_frame
	trails = park.get_node("MidoriDesirePaths")
	while not trails.finished: await get_tree().process_frame
	var sparse: Node = park.get_node("MidoriSparseVegetation")
	while not sparse.installed: await get_tree().process_frame
	await install()

func source(node: Node3D, label: String, distance: float) -> int:
	var parts: Array[Dictionary] = []
	var bounds := AABB()
	var first := true
	var triangles := 0
	var nodes: Array[Node] = [node]
	nodes.append_array(node.find_children("*", "MeshInstance3D", true, false))
	for child: Node in nodes:
		if not child is MeshInstance3D: continue
		var part := child as MeshInstance3D
		if part.mesh == null: continue
		var relative: Transform3D = park._vegetation_relative_transform(part, node)
		var mesh := part.mesh.duplicate() as Mesh
		for surface: int in range(mesh.get_surface_count()):
			var original := part.get_active_material(surface)
			var material := original.duplicate() as Material if original != null else null
			if material is StandardMaterial3D:
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				if label in ["groundcover", "fern", "grass"]:
					material.roughness = maxf(material.roughness, .85)
					material.metallic_specular = .16
					if material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
						material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
						material.alpha_scissor_threshold = .35
			mesh.surface_set_material(surface, material)
			var arrays := mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			triangles += indices.size()/3 if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3
		var box := relative * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		var lod_info := imported_lod_info(mesh)
		parts.append({"mesh": mesh, "relative": relative, "lod_surfaces": lod_info.surfaces, "lod_levels": lod_info.levels, "lod_bias": part_lod_bias(label, int(lod_info.levels)>0)})
	if first or bounds.size.y <= .00001: return -1
	sources.append({"parts": parts, "box": bounds, "label": label, "distance": distance, "triangles": triangles})
	return sources.size()-1

func file_source(filename: String, label: String, distance: float) -> void:
	var resource := load(ASSETS+filename) as PackedScene
	if resource == null: return
	var node := resource.instantiate() as Node3D
	source(node, label, distance)
	node.free()

func cell(p: Vector2, size: float = 2.0) -> Vector2i:
	return Vector2i(floori(p.x/size), floori(p.y/size))

func near_trunk(p: Vector2) -> float:
	var key := cell(p, 8.0)
	var distance := 24.0
	for z: int in range(-2,3):
		for x: int in range(-2,3):
			for trunk: Vector2 in trunks.get(key+Vector2i(x,z), []): distance=minf(distance,p.distance_to(trunk))
	return distance

func safe(p: Vector2, radius: float, ground: bool = false) -> bool:
	if absf(p.x)>211.0-radius or absf(p.y)>169.0-radius: return false
	if terrain.water_at(p): return false
	# Entry and inland terrain can be dry below the lake elevation. Keep the
	# conservative support-height test only beside the actual shoreline.
	if terrain.height_at(p)<.115 and terrain.edge_distance(p,terrain.shoreline)<12.0: return false
	if not detail._is_lawn_position(p.x,p.y): return false
	if not park._is_vegetation_clear(Vector3(p.x*.5,0,p.y*.5),radius*.5+.12): return false
	if trails.distance_to_path(p)<radius+1.25: return false
	if near_trunk(p)<radius+(.45 if ground else .70): return false
	for side: int in range(8):
		var q := p+Vector2(radius+.08,0).rotated(side*TAU/8.0)
		if terrain.water_at(q) or not detail._is_lawn_position(q.x,q.y): return false
		if terrain.height_at(q)<.108 and terrain.edge_distance(q,terrain.shoreline)<12.0: return false
	return true

func scan_planting() -> void:
	for p: Vector2 in park.occupied_tree_positions:
		var world := p*2.0
		var key := cell(world,8.0)
		if not trunks.has(key): trunks[key]=[]
		trunks[key].append(world)
	# Source roots are read even when the distance service has hidden its originals.
	# Skip LOD copies and use only substantial plants, not tiny lawn blades.
	for node: MultiMeshInstance3D in park.find_children("*", "MultiMeshInstance3D", true, false):
		var path := String(node.get_path()).to_lower()
		if "midoridistancedetail" in path or "lod1" in path or "lod2" in path: continue
		if not ("woodlandfilllod0" in path or "sparseunderstory" in path or "companion" in path or "diversity" in path or "forestgrassdrift" in path): continue
		var mm := node.multimesh
		if mm == null or mm.mesh == null: continue
		var box := mm.mesh.get_aabb()
		var anchor := Vector3(box.get_center().x,box.position.y,box.get_center().z)
		for index: int in range(mm.instance_count):
			if index%512==0: await Budget.checkpoint(park)
			var t := node.global_transform*mm.get_instance_transform(index)
			if (t*box).size.y < .12: continue
			var root := t*anchor
			var key := cell(Vector2(root.x,root.z))
			occupied[key]=int(occupied.get(key,0))+1
			scanned_roots+=1

func crowding(p: Vector2) -> int:
	var key := cell(p)
	return int(occupied.get(key,0))

func place(kind: int, p: Vector2, height: float, width: float = -1.0) -> bool:
	if kind<0 or kind>=sources.size(): return false
	var s: Dictionary = sources[kind]
	if instanced_triangles+int(s.triangles)>TRIANGLE_BUDGET: return false
	var box: AABB = s.box
	var scale_y := height/box.size.y
	var scale_x := width/maxf(box.size.x,box.size.z) if width>0.0 else scale_y
	var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(scale_x,scale_y,scale_x))
	var footprint := Transform3D(basis,Vector3.ZERO)*box
	var radius := Vector2(footprint.size.x,footprint.size.z).length()*.5
	var label: String = s.label
	var ground := label in ["stone","branch","leaf","paper","can"]
	if not safe(p,radius,ground): return false
	var key := cell(p,1.0)
	if not ground and additions.has(key): return false
	var y: float = terrain.height_at(p)
	# Seat the whole footprint on the sampled terrain; reject unsupported ridges.
	var low := y
	var high := y
	for side: int in range(8):
		var q := p+Vector2(radius*.85,0).rotated(side*TAU/8.0)
		var h: float = terrain.height_at(q)
		low=minf(low,h); high=maxf(high,h)
	if high-low>(.035 if ground else .11): return false
	var anchor := Vector3(footprint.get_center().x,footprint.position.y,footprint.get_center().z)
	var embed := minf(height*.18,.025) if label=="stone" else .003
	var contact := high-embed
	var t := Transform3D(basis,Vector3(p.x,contact,p.y)-anchor)
	var grid := cell(p,CELL)
	var group_key := str(kind)+":"+str(grid)
	if not groups.has(group_key): groups[group_key]={"kind":kind,"cell":grid,"transforms":[]}
	groups[group_key].transforms.append(t)
	audit.append({"p":p,"kind":kind,"label":label,"height":height,"radius":radius,"contact":contact,"ground_height":y,"terrain_span":high-low})
	counts[label]=int(counts.get(label,0))+1
	instanced_triangles+=int(s.triangles)
	if not ground: additions[key]=true
	return true

func variants(label: String) -> Array[int]:
	var result: Array[int] = []
	for i: int in range(sources.size()):
		if sources[i].label==label: result.append(i)
	return result

func install() -> void:
	if installed: return
	var started := Time.get_ticks_msec()
	rng.seed=2050102607
	for i: int in range(6): file_source("stone_%02d.glb"%i,"stone",60.0)
	for i: int in range(3): file_source("branch_%02d.glb"%i,"branch",35.0)
	for i: int in range(6): file_source("groundcover_%02d.glb"%i,"groundcover",58.0)
	for i: int in range(3): file_source("leaf_%02d.glb"%i,"leaf",24.0)
	file_source("paper_00.glb","paper",28.0)
	file_source("can_00.glb","can",28.0)
	var fern := source(park.midnight_fern_prototype,"fern",65.0)
	var grass := source(park.emerald_fountain_grass_prototype,"grass",72.0)
	await scan_planting()
	var flowers := variants("groundcover")
	var stones := variants("stone")
	var branches := variants("branch")
	var leaves := variants("leaf")
	# Where open lawn gets a few settled stones: loose patches, not an even spread.
	var lawn_stones := FastNoiseLite.new()
	lawn_stones.seed = 4127
	lawn_stones.frequency = 0.045
	# A coprime traversal gives every park sector a share of the budget. Coherent
	# lobes connect beds; density measurements avoid adding to existing carpets.
	for step: int in range(38*31):
		await Budget.checkpoint(park)
		var serial := (step*347)%(38*31)
		var centre := Vector2(-203.5+(serial%38)*11.0,-159.5+int(serial/38)*10.5)
		centre+=Vector2(rng.randf_range(-2.8,2.8),rng.randf_range(-2.8,2.8))
		if not safe(centre,.75): continue
		var distance := near_trunk(centre)
		var shade := distance<11.0
		var dense := crowding(centre)>3
		var placed := 0
		if not dense:
			for j: int in range(25):
				var angle := rng.randf_range(0,TAU)
				var r := sqrt(rng.randf())
				var p := centre+Vector2(cos(angle)*4.6*r,sin(angle)*3.3*r)
				var wave := .5+.25*sin(p.x*.18+p.y*.12)+.25*cos(p.y*.23-p.x*.09)
				if wave<.28 or crowding(p)>2: continue
				var kind: int = flowers[(serial+j)%flowers.size()]
				var height := rng.randf_range(.16,.29)
				var width := rng.randf_range(.36,.64)
				if j%9==0 and shade:
					kind=fern; height=rng.randf_range(.34,.64); width=-1.0
				elif j%11==0:
					kind=grass; height=rng.randf_range(.40,.69); width=-1.0
				if place(kind,p,height,width): placed+=1
		if placed>0: gap_pockets+=1
		# Natural objects collect around planting and trunks, rather than covering
		# the park uniformly. Lawn interiors keep a deliberately quieter treatment.
		if shade or placed>0:
			for j: int in range(7 if shade else 3):
				var p := centre+Vector2(rng.randf_range(-4.8,4.8),rng.randf_range(-3.8,3.8))
				if j<3: place(stones[(serial+j)%stones.size()],p,rng.randf_range(.035,.13))
				elif j==3 and serial%3==0: place(branches[serial%branches.size()],p,rng.randf_range(.035,.11))
				else: place(leaves[(serial+j)%leaves.size()],p,rng.randf_range(.010,.021))
		elif lawn_stones.get_noise_2dv(centre)>-.05:
			# Open lawn: a small cluster of stones half sunk in the turf, a couple of
			# low tufts at its foot and a few fallen leaves, so bare lawn has texture.
			var seed_p := centre+Vector2(rng.randf_range(-4.0,4.0),rng.randf_range(-3.0,3.0))
			for j: int in range(rng.randi_range(3,7)):
				var a := rng.randf_range(0,TAU)
				place(stones[(serial+j)%stones.size()],seed_p+Vector2(cos(a),sin(a))*rng.randf_range(.3,1.4),rng.randf_range(.06,.18))
			if rng.randf()<.3: place(stones[serial%stones.size()],seed_p,rng.randf_range(.22,.38))
			for j: int in range(rng.randi_range(1,3)):
				var a := rng.randf_range(0,TAU)
				place(flowers[(serial+j)%flowers.size()],seed_p+Vector2(cos(a),sin(a))*rng.randf_range(.5,1.6),rng.randf_range(.14,.24),rng.randf_range(.3,.5))
			for j: int in range(2):
				place(leaves[(serial+j)%leaves.size()],seed_p+Vector2(rng.randf_range(-1.5,1.5),rng.randf_range(-1.5,1.5)),rng.randf_range(.010,.021))
		if placed>5 and serial%9==0:
			place(stones[serial%stones.size()],centre+Vector2(1.2,.7),rng.randf_range(.18,.32))
	# Small litter near existing human-use destinations, confined to dry soil.
	var destinations: Array[Vector2]=[Vector2(-49,119),Vector2(-23,151),Vector2(-111,81),Vector2(-100,108),Vector2(-124,-36),Vector2(-25,30),Vector2(31,-126),Vector2(0,160)]
	var papers := variants("paper")
	var cans := variants("can")
	for c: Vector2 in destinations:
		for attempt: int in range(12):
			var p := c+Vector2(rng.randf_range(-6,6),rng.randf_range(-6,6))
			if place(papers[0] if attempt%3 else cans[0],p,.016 if attempt%3 else .065): break
	await build_batches()
	installed=true
	report={"counts":counts,"gap_pockets":gap_pockets,"scanned_existing_roots":scanned_roots,"batches":batches,"instanced_triangles":instanced_triangles,"triangle_budget":TRIANGLE_BUDGET,"new_collisions":0,"elapsed_ms":Time.get_ticks_msec()-started,"seed":2050102607,"source_variants":sources.size(),"batch_cell_m":CELL,"lod_adjusted_batches":lod_adjusted_batches,"source_lod_stats":source_lod_stats()}
	park.set_meta("park_floor",report)
	print("PARK_FLOOR_READY ",JSON.stringify(report))

func build_batches() -> void:
	for key: String in groups:
		await Budget.checkpoint(park)
		var row: Dictionary = groups[key]
		var s: Dictionary = sources[row.kind]
		var grid: Vector2i = row.cell
		var origin := Vector3((grid.x+.5)*CELL,0,(grid.y+.5)*CELL)
		for part: Dictionary in s.parts:
			var mm := MultiMesh.new()
			mm.transform_format=MultiMesh.TRANSFORM_3D
			mm.mesh=part.mesh
			mm.instance_count=row.transforms.size()
			for index: int in range(mm.instance_count):
				var t: Transform3D=row.transforms[index]*part.relative
				t.origin-=origin
				mm.set_instance_transform(index,t)
			var batch := MultiMeshInstance3D.new()
			batch.name="ParkFloor_%s_%04d"%[s.label,batches]
			batch.position=origin
			batch.multimesh=mm
			batch.lod_bias=float(part.get("lod_bias",1.0))
			if batch.lod_bias<1.0: lod_adjusted_batches+=1
			batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.visibility_range_end=s.distance
			batch.visibility_range_end_margin=8.0
			batch.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(batch)
			batches+=1
	groups.clear()
