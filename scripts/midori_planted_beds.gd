extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")

@export_file("*.gd") var lily_source_path := "res://scripts/midori_water_lily.gd"

# Existing supplied plants, grouped into wider beds across the empty lawn panels.
# This child uses world coordinates; generator clearance queries use layout units.
const BED_CENTERS: Array[Vector2] = [
	Vector2(-86,-16),Vector2(-63,-14),Vector2(-86,17),Vector2(-63,18),
	Vector2(-28,61),Vector2(23,63),Vector2(-18,-66),Vector2(4,-69),
	Vector2(-82,-50),Vector2(-70,-35),Vector2(-30,-51),Vector2(-28,-18),
	Vector2(-27,13),Vector2(-15,37),Vector2(0,-34),Vector2(3,36),
	Vector2(91,-30),Vector2(91,45),Vector2(-91,-3),Vector2(-78,47),
	Vector2(-53,-47),Vector2(-43,40),Vector2(-18,-5),Vector2(-8,18),
	Vector2(1,-53),Vector2(5,53),Vector2(94,2),Vector2(101,69),
	Vector2(-96,-43),Vector2(-43,-46),Vector2(-72,-62),
	Vector2(-61,63),Vector2(-48,70),Vector2(15,39),Vector2(28,52),
	Vector2(76,52),Vector2(85,11),Vector2(20,-43),Vector2(34,-70),
	Vector2(-58,11),Vector2(-33,30),Vector2(-12,47),Vector2(11,66),
	Vector2(15,25),Vector2(2,20),Vector2(10,12),Vector2(-12,70),
]
var park: Node3D
var planted_positions: Array[Vector3] = []
var plant_counts := {"fern":0,"fountain_grass":0,"flowering_shrub":0}
var batch_count := 0
var pond_positions: Array[Vector3] = []

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	call_deferred("_install")

func _install() -> void:
	park = get_parent() as Node3D
	if park == null or not "midnight_fern_prototype" in park:
		return
	if park.midnight_fern_prototype == null:
		await get_tree().process_frame
	var sources: Array[Node3D] = [park.midnight_fern_prototype,park.emerald_fountain_grass_prototype]
	for shrub: Node3D in park.lilac_prototypes:
		sources.append(shrub)
	if sources.size() < 4 or sources[0] == null or sources[1] == null:
		push_error("Midori planted beds: existing plant sources unavailable")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20501005
	var accepted_beds := 0
	for bed_index in range(BED_CENTERS.size()):
		var center := BED_CENTERS[bed_index]
		var groups: Array = [[],[],[],[]]
		var bed_positions: Array[Vector3] = []
		var angle := rng.randf_range(0.0,TAU)
		var radius_x := rng.randf_range(3.1,4.5)
		var radius_z := rng.randf_range(1.9,3.0)
		for attempt in range(200):
			if bed_positions.size() >= 44:
				break
			var theta := rng.randf_range(0.0,TAU)
			var radius := sqrt(rng.randf())
			var offset := Vector2(cos(theta)*radius_x,sin(theta)*radius_z)*radius
			offset = offset.rotated(angle)
			var layout := center + offset
			var source_index := 0
			var choice := rng.randf()
			if choice > 0.84:
				source_index = 2 + rng.randi_range(0,1)
			elif choice > 0.62:
				source_index = 1
			# Clear the complete low plant footprint from routes and activity areas.
			var clearance := 0.65 if source_index >= 2 else 0.45
			if not park._is_vegetation_clear(Vector3(layout.x,0,layout.y),clearance):
				continue
			var world := Vector3(layout.x*2.0,-0.016,layout.y*2.0)
			var too_close := false
			for trunk: Vector2 in park.occupied_tree_positions:
				if Vector2(world.x,world.z).distance_squared_to(trunk*2.0) < 0.80*0.80:
					too_close = true
					break
			if too_close:
				continue
			for previous: Vector3 in bed_positions:
				if world.distance_squared_to(previous) < 0.78*0.78:
					too_close = true
					break
			if too_close:
				continue
			var scale_value := rng.randf_range(0.50,0.78)
			if source_index >= 2:
				scale_value = rng.randf_range(0.48,0.68)
			elif source_index == 1:
				scale_value = rng.randf_range(0.58,0.85)
			var basis := Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3.ONE*scale_value)
			groups[source_index].append(Transform3D(basis,world))
			bed_positions.append(world)
			planted_positions.append(world)
			var kind := "fern" if source_index == 0 else ("fountain_grass" if source_index == 1 else "flowering_shrub")
			plant_counts[kind] += 1
		if bed_positions.is_empty():
			continue
		accepted_beds += 1
		for source_index in range(sources.size()):
			if not groups[source_index].is_empty():
				_batch_source(sources[source_index],groups[source_index],bed_index,source_index)
	if _add_low_lawn_pocket(sources) > 0:
		accepted_beds += 1
	set_meta("planting_counts",plant_counts)
	set_meta("planting_positions",planted_positions)
	set_meta("planting_beds",accepted_beds)
	print("MIDORI_PLANTED_BEDS: ",JSON.stringify({"beds":accepted_beds,"plants":planted_positions.size(),"types":plant_counts,"mesh_batches":batch_count,"new_collisions":0}))
	_build_pond_pockets()

func _add_low_lawn_pocket(sources: Array[Node3D]) -> int:
	# This small triangle lies inside the old broad prop exclusion shoulders.
	# Measure the visible walk triangles and reserve the complete plant radius.
	var walk_triangles: Array[PackedVector2Array] = []
	for walk_name in ["OuterWalkingCircuit","SouthEntranceToLake","SouthEntranceToPlaza","WestEntranceToBridgeLanding","NorthEntranceToLake","EastEntranceToBridgeLanding","SportsConnector","PlaygroundWoodlandLoop","NorthWoodlandLoop","PlazaToSouthBridgeLanding","PavilionGardenLink","EastPromenadeToViewingDeck","ContinuousLakePromenade"]:
		var walk := park.find_child(walk_name,true,false) as MeshInstance3D
		if walk == null or walk.mesh == null:
			continue
		for surface in range(walk.mesh.get_surface_count()):
			var arrays := walk.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for vertex in range(vertices.size()):
					indices.append(vertex)
			for i in range(0,indices.size(),3):
				var triangle := PackedVector2Array()
				for offset in range(3):
					var p: Vector3 = walk.global_transform * vertices[indices[i+offset]]
					triangle.append(Vector2(p.x,p.z))
				walk_triangles.append(triangle)
	if walk_triangles.is_empty():
		push_error("Midori low bed: actual walk geometry unavailable")
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20501007
	var groups: Array = [[],[]]
	var placed: Array[Vector3] = []
	for attempt in range(240):
		if placed.size() >= 36:
			break
		var theta := rng.randf_range(0.0,TAU)
		var r := sqrt(rng.randf())
		var point := Vector2(32,57)+Vector2(cos(theta)*3.8,sin(theta)*2.7)*r
		var layout := point*0.5
		if park._is_point_in_or_near_lake(layout,0.4) or park._is_near_future_bridge_corridor(layout,0.25):
			continue
		var clear := true
		for triangle in walk_triangles:
			if Geometry2D.is_point_in_polygon(point,triangle):
				clear = false
				break
			for edge in range(3):
				if point.distance_to(Geometry2D.get_closest_point_to_segment(point,triangle[edge],triangle[(edge+1)%3])) < 0.64:
					clear = false
					break
			if not clear:
				break
		if not clear:
			continue
		var world := Vector3(point.x,-0.016,point.y)
		for previous: Vector3 in placed:
			if world.distance_squared_to(previous) < 0.53*0.53:
				clear = false
				break
		if not clear:
			continue
		var kind := rng.randi_range(0,1)
		var scale_value := rng.randf_range(0.42,0.54)
		var basis := Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3.ONE*scale_value)
		groups[kind].append(Transform3D(basis,world))
		placed.append(world)
		planted_positions.append(world)
		plant_counts["fern" if kind == 0 else "fountain_grass"] += 1
	for kind in range(2):
		if not groups[kind].is_empty():
			_batch_source(sources[kind],groups[kind],99,kind)
	set_meta("low_lawn_pocket_positions",placed)
	print("MIDORI_LOW_LAWN_BED: ",placed.size()," plants, actual walk mesh clearance >=0.64m")
	return placed.size()

func _build_pond_pockets() -> void:
	var lily_source = load(lily_source_path)
	if lily_source == null:
		push_error("Midori pond planting: water-lily prototype unavailable")
		return
	var water := park.find_child("LakeWaterSurface",true,false) as MeshInstance3D
	if water == null:
		push_error("Midori pond planting: actual lake surface unavailable")
		return
	# Mizumoto reference: a connected leafy shore mass, scalloped outer bays,
	# much quieter secondary patches, and occasional mostly white flowers.
	# Fractions address the existing shoreline anchors; every sample is snapped
	# to the CURRENT rounded contour. All distances below are world metres.
	var specs: Array[Dictionary] = [
		{"id":"WestBankRaft","first":8.55,"last":10.05,"width":6.22,"bay":0.34,"cut":0.65,"phase":0.4,"cap":260,"triangle_budget":1300000,"hero":Vector2(35,6),"connection":0.22,"channel":[0.64,0.705],"lobes":[{"at":0.20,"spread":0.085,"depth":4.2},{"at":0.48,"spread":0.095,"depth":6.0},{"at":0.82,"spread":0.060,"depth":3.15}]},
		{"id":"EastBankRaft","first":18.35,"last":19.65,"width":1.85,"bay":0.38,"cut":0.90,"phase":2.1,"cap":96,"triangle_budget":440000,"hero":Vector2(149,24)},
		{"id":"NorthWestIslandPocket","first":3.20,"last":3.85,"width":1.30,"bay":0.72,"cut":0.70,"phase":4.3,"cap":52,"triangle_budget":260000,"hero":Vector2(64,-97)},
		{"id":"SouthWestShelteredPocket","first":11.05,"last":11.80,"width":2.65,"bay":0.40,"cut":1.05,"phase":3.7,"cap":80,"triangle_budget":400000,"hero":Vector2(52,56)},
		{"id":"NorthEastShelteredPocket","first":24.15,"last":24.95,"width":2.20,"bay":0.57,"cut":0.95,"phase":5.2,"cap":72,"triangle_budget":360000,"hero":Vector2(143,-94)},
		{"id":"NorthShelteredPocket","first":26.05,"last":26.75,"width":2.10,"bay":0.43,"cut":0.90,"phase":1.8,"cap":56,"triangle_budget":250000,"hero":Vector2(124,-123)},
	]
	var water_bounds: AABB = water.global_transform * water.get_aabb()
	var water_y := water_bounds.position.y
	var rng := RandomNumberGenerator.new()
	rng.seed = 20501006
	var pockets := Node3D.new()
	pockets.name = "WaterLilyPockets"
	add_child(pockets)
	var variants: Array[Node3D] = []
	var stats: Array[Dictionary] = []
	var widest_radius := 0.0
	for variant in range(5):
		var prototype: Node3D = lily_source.build(variant)
		variants.append(prototype)
		var measured := _pond_prototype_stats(prototype)
		stats.append(measured)
		widest_radius = maxf(widest_radius,float(measured.radius))
	var island_bounds: Array[AABB] = []
	for island: MeshInstance3D in park.find_children("Lake*","MeshInstance3D",true,false):
		if not ("Island" in island.name or "Islet" in island.name) or "SoftBank" in island.name:
			continue
		island_bounds.append(island.global_transform * island.get_aabb())
	var report := {"reference":"Mizumoto Park, mori-sanpo, 2011-06-11","water_y":water_y,"rafts":[],"variant_counts":[0,0,0,0,0],"prototype_stats":stats,"clusters":0,"pads":0,"flowers":0,"buds":0,"foliage_clusters":0,"drawn_triangles":0,"triangle_budget":3010000,"cluster_cap":616,"island_masks":island_bounds.size(),"minimum_full_footprint_bank_gap_m":1.4,"bridge_padding_world_m":1.2,"new_collisions":0,"rejected":{"shore":0,"bridge":0,"island":0,"spacing":0,"budget":0}}
	for spec: Dictionary in specs:
		var groups: Array = [[],[],[],[],[]]
		var positions: Array[Vector3] = []
		var counts: Array[int] = [0,0,0,0,0]
		var triangles := 0
		var minimum_gap := INF
		var bounds_min := Vector3(INF,INF,INF)
		var bounds_max := Vector3(-INF,-INF,-INF)
		var candidates := _pond_raft_candidates(spec,widest_radius,rng)
		for layout_world: Vector2 in candidates:
			if positions.size() >= int(spec.cap):
				break
			# Three pads per cluster: 18% flowering clusters = one blossom per
			# about 16.7 pads, i.e. roughly 6% flowers relative to pad count.
			# Ivory dominates; another 12% of clusters carry closed buds.
			var choice := rng.randf()
			var variant := 0 if choice < .025 else (1 if choice < .18 else (2 if choice < .30 else (3 if choice < .74 else 4)))
			if positions.is_empty():
				variant = 1
			var cost: int = stats[variant].triangles
			if triangles + cost > int(spec.triangle_budget):
				report.rejected.budget += 1
				continue
			var scale_value := rng.randf_range(.88,1.12)
			var footprint_radius: float = stats[variant].radius * scale_value
			var layout: Vector2 = layout_world / float(park.LAYOUT_SCALE)
			if not Geometry2D.is_point_in_polygon(layout,PackedVector2Array(park.lake_contour)):
				report.rejected.shore += 1
				continue
			var gap := _pond_bank_distance(layout_world) - footprint_radius
			if gap < 1.4:
				report.rejected.shore += 1
				continue
			if park._is_near_future_bridge_corridor(layout,.6+footprint_radius/float(park.LAYOUT_SCALE)) or _pond_touches_bridge(layout_world,footprint_radius):
				report.rejected.bridge += 1
				continue
			var blocked := false
			for bounds: AABB in island_bounds:
				var padding := 1.4 + footprint_radius
				if layout_world.x > bounds.position.x-padding and layout_world.x < bounds.end.x+padding and layout_world.y > bounds.position.z-padding and layout_world.y < bounds.end.z+padding:
					blocked = true
					break
			if blocked:
				report.rejected.island += 1
				continue
			# Closely packed foliage merges visually into a raft. Full bank/
			# island/bridge masks use the measured maximum radius at this scale.
			for previous: Vector3 in pond_positions:
				if layout_world.distance_squared_to(Vector2(previous.x,previous.z)) < pow(1.17 if String(spec.id).ends_with("ShelteredPocket") else .49, 2):
					blocked = true
					break
			if blocked:
				report.rejected.spacing += 1
				continue
			var world := Vector3(layout_world.x,water_y,layout_world.y)
			var basis := Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3.ONE*scale_value)
			groups[variant].append(Transform3D(basis,world))
			positions.append(world)
			pond_positions.append(world)
			counts[variant] += 1
			report.variant_counts[variant] += 1
			triangles += cost
			minimum_gap = minf(minimum_gap,gap)
			bounds_min = bounds_min.min(world+Vector3(-footprint_radius,float(stats[variant].minimum_y)*scale_value,-footprint_radius))
			bounds_max = bounds_max.max(world+Vector3(footprint_radius,float(stats[variant].maximum_y)*scale_value,footprint_radius))
			# The first accepted point is near this raft's hero target and ivory.
			if variant == 1 and not has_meta("pond_flower_anchor"):
				set_meta("pond_flower_anchor",world)
		for variant in range(5):
			if groups[variant].is_empty():
				continue
			for part: MeshInstance3D in variants[variant].get_children():
				if part.mesh == null:
					continue
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = part.mesh
				mm.instance_count = groups[variant].size()
				for i in range(groups[variant].size()):
					mm.set_instance_transform(i,groups[variant][i]*part.transform)
				var batch := MultiMeshInstance3D.new()
				batch.name = "Pond_%s_%d_%s" % [String(spec.id),variant,part.name]
				batch.multimesh = mm
				batch.cast_shadow = part.cast_shadow
				batch.visibility_range_end = 100.0
				batch.visibility_range_end_margin = 15.0
				batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				pockets.add_child(batch)
		var raft := {"id":spec.id,"authored_shore_anchor_fractions":[spec.first,spec.last],"nominal_band_width_world_m":spec.width,"maximum_authored_band_width_world_m":float(spec.width)+.45,"outer_bay_fraction":spec.bay,"outer_bay_cut_world_m":spec.cut,"cluster_cap":spec.cap,"triangle_budget":spec.triangle_budget,"clusters":positions.size(),"pads":positions.size()*3,"flowers":counts[0]+counts[1],"buds":counts[2],"foliage_clusters":counts[3]+counts[4],"variant_counts":counts,"drawn_triangles":triangles,"candidates":candidates.size(),"bank_full_footprint_gap_m":minimum_gap if not positions.is_empty() else -1.0}
		if spec.has("lobes"):
			raft["authored_lobes"] = spec.lobes
			raft["connecting_band_world_m"] = spec.connection
			raft["open_water_channel_fraction"] = spec.channel
		if not positions.is_empty():
			raft["world_bounds_min"] = [bounds_min.x,bounds_min.y,bounds_min.z]
			raft["world_bounds_max"] = [bounds_max.x,bounds_max.y,bounds_max.z]
		report.rafts.append(raft)
		report.drawn_triangles += triangles
	for prototype in variants:
		prototype.free()
	report.clusters = pond_positions.size()
	report.pads = pond_positions.size()*3
	report.flowers = report.variant_counts[0]+report.variant_counts[1]
	report.buds = report.variant_counts[2]
	report.foliage_clusters = report.variant_counts[3]+report.variant_counts[4]
	report["pads_per_open_flower"] = float(report.pads)/float(report.flowers) if report.flowers > 0 else 0.0
	set_meta("pond_positions",pond_positions)
	set_meta("reference_pond_report",report)
	print("MIDORI_POND_PLANTING: ",JSON.stringify(report))

func _pond_prototype_stats(prototype: Node3D) -> Dictionary:
	var radius := 0.0
	var minimum_y := 0.0
	var maximum_y := 0.0
	var triangles := 0
	for part: MeshInstance3D in prototype.get_children():
		if part.mesh == null:
			continue
		for surface in range(part.mesh.get_surface_count()):
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices = arrays[Mesh.ARRAY_INDEX]
			triangles += int((indices.size() if not indices.is_empty() else vertices.size()) / 3)
			for vertex: Vector3 in vertices:
				var point: Vector3 = part.transform * vertex
				radius = maxf(radius,Vector2(point.x,point.z).length())
				minimum_y = minf(minimum_y,point.y)
				maximum_y = maxf(maximum_y,point.y)
	return {"radius":radius,"height":maximum_y-minimum_y,"minimum_y":minimum_y,"maximum_y":maximum_y,"triangles":triangles,"pads":3}

func _pond_shore_frame(fraction: float) -> Dictionary:
	var count: int = park.LAKE_SHORELINE.size()
	var first := posmod(int(floor(fraction)),count)
	var second := (first+1)%count
	var a: Vector2 = park.LAKE_SHORELINE[first]
	var b: Vector2 = park.LAKE_SHORELINE[second]
	var query := a.lerp(b,fraction-floor(fraction))
	var point := query
	var tangent := Vector2.RIGHT
	var distance := INF
	for edge in range(park.lake_contour.size()):
		var start: Vector2 = park.lake_contour[edge]
		var finish: Vector2 = park.lake_contour[(edge+1)%park.lake_contour.size()]
		var nearest := Geometry2D.get_closest_point_to_segment(query,start,finish)
		var squared := nearest.distance_squared_to(query)
		if squared < distance:
			distance = squared
			point = nearest
			tangent = (finish-start).normalized()
	var inward := Vector2(-tangent.y,tangent.x)
	if not Geometry2D.is_point_in_polygon(point+inward*.1,PackedVector2Array(park.lake_contour)):
		inward = -inward
	return {"point":point*float(park.LAYOUT_SCALE),"tangent":tangent,"inward":inward}

func _pond_raft_candidates(spec: Dictionary, radius: float, rng: RandomNumberGenerator) -> Array[Vector2]:
	var length_world := 0.0
	var previous: Vector2 = _pond_shore_frame(float(spec.first)).point
	for sample in range(1,49):
		var fraction := lerpf(float(spec.first),float(spec.last),float(sample)/48.0)
		var current: Vector2 = _pond_shore_frame(fraction).point
		length_world += previous.distance_to(current)
		previous = current
	var columns := clampi(int(ceil(length_world/.54)),8,100)
	var candidates: Array[Vector2] = []
	var base_gap := 1.4 + radius*1.12 + .07
	for column in range(columns+1):
		var u := float(column)/float(columns)
		var frame := _pond_shore_frame(lerpf(float(spec.first),float(spec.last),u))
		var taper := pow(maxf(0.0,sin(PI*u)),.42)
		var width := float(spec.width)*taper
		width += (.28*sin(u*17.0+float(spec.phase))+.17*sin(u*31.0+float(spec.phase)*1.7))*taper
		# A broad incursion in the outer edge leaves a water bay, while a
		# narrower second notch and asymmetric shoulders prevent oval islands.
		width -= float(spec.cut)*exp(-pow((u-float(spec.bay))/.065,2.0))
		width = maxf(0.0,width)
		if spec.has("lobes"):
			# Three unequal broad masses share a thin connecting portion. Using
			# the largest lobe profile, rather than summing overlapping lobes,
			# keeps the valleys deep instead of reconstructing a uniform band.
			var lobe_width := 0.0
			for lobe: Dictionary in spec.lobes:
				lobe_width = maxf(lobe_width,float(lobe.depth)*exp(-pow((u-float(lobe.at))/float(lobe.spread),2.0)))
			var end_taper := smoothstep(0.0,.08,u)*smoothstep(0.0,.07,1.0-u)
			width = (float(spec.connection)+lobe_width)*end_taper
			width += (.13*sin(u*19.0+float(spec.phase))+.08*sin(u*37.0))*end_taper
			width -= float(spec.cut)*exp(-pow((u-float(spec.bay))/.050,2.0))
			var channel: Array = spec.channel
			if u > float(channel[0]) and u < float(channel[1]):
				width = 0.0
			width = maxf(0.0,width)
		var row_limit := 14 if spec.has("lobes") else 7
		for row in range(row_limit):
			var depth := .16 + float(row)*.52 + rng.randf_range(-.10,.10)
			if depth > width:
				continue
			var stagger := .20 if row%2 == 1 else -.10
			var along := stagger+rng.randf_range(-.13,.13)
			var point: Vector2 = frame.point + frame.inward*(base_gap+depth) + frame.tangent*along
			candidates.append(point)
	# Fixed bounded sampling, no repeated random attempts or blanket carpet.
	for index in range(candidates.size()-1,0,-1):
		var other := rng.randi_range(0,index)
		var saved := candidates[index]
		candidates[index] = candidates[other]
		candidates[other] = saved
	var closest := INF
	var hero_index := -1
	var hero: Vector2 = spec.hero
	for index in range(candidates.size()):
		var distance := candidates[index].distance_squared_to(hero)
		if distance < closest:
			closest = distance
			hero_index = index
	if hero_index > 0:
		var saved := candidates[0]
		candidates[0] = candidates[hero_index]
		candidates[hero_index] = saved
	return candidates

func _pond_bank_distance(point: Vector2) -> float:
	var nearest := INF
	for edge in range(park.lake_contour.size()):
		var a: Vector2 = park.lake_contour[edge]*float(park.LAYOUT_SCALE)
		var b: Vector2 = park.lake_contour[(edge+1)%park.lake_contour.size()]*float(park.LAYOUT_SCALE)
		nearest = minf(nearest,point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b)))
	return nearest

func _pond_touches_bridge(point: Vector2, radius: float) -> bool:
	if is_finite(float(park.bridge_surface_height(point))):
		return true
	for sample in range(8):
		var angle := TAU*float(sample)/8.0
		if is_finite(float(park.bridge_surface_height(point+Vector2(cos(angle),sin(angle))*(radius+1.2)))):
			return true
	return false

func _batch_source(source: Node3D, transforms: Array, bed_index: int, source_index: int) -> void:
	for part: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		if part.mesh == null:
			continue
		var mesh: Mesh = part.mesh
		# Preserve supplied geometry and the configured material of every surface.
		var shared_mesh := mesh.duplicate() as Mesh
		for surface in range(mesh.get_surface_count()):
			shared_mesh.surface_set_material(surface,part.get_active_material(surface))
		var relative: Transform3D = park._vegetation_relative_transform(part,source)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = shared_mesh
		mm.instance_count = transforms.size()
		for i in range(transforms.size()):
			mm.set_instance_transform(i,transforms[i]*relative)
		var batch := MultiMeshInstance3D.new()
		batch.name = "Bed_%02d_Plant_%d_%d" % [bed_index,source_index,batch_count]
		batch.multimesh = mm
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		batch.visibility_range_end = 95.0
		batch.visibility_range_end_margin = 15.0
		batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(batch)
		batch_count += 1
