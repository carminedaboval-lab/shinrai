extends RefCounted
# Original metre-scale court construction; root owns the earlier Z<242 connection.
const Landscape = preload("res://scripts/midori_south_street_landscape.gd")
const GardenEdges = preload("res://scripts/midori_court_garden_edges.gd")
const IRIS := "res://assets/shinrai/parks/midori_park/models/identity2050/midori_2050_iris_clump.glb"
const AZALEA := "res://assets/shinrai/parks/midori_park/models/plants/iris_japonica/red_azalea_lod1.glb"
const AREA := Rect2(-27.5,242,55,28)
const BENCH := "res://assets/shinrai/parks/midori_park/models/identity2050/midori_2050_timber_bench.glb"
const RACK := "res://assets/shinrai/parks/midori_park/models/furniture/ambient/bicycle_rack/midori_bicycle_rack.glb"

static func build(street: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "CourtGround"
	root.set_meta("creator_protected",true)
	street.add_child(root)
	_soil_material(street)
	var footprints: Array[Rect2] = [Rect2(-25,246,9,9),Rect2(-12,258,8,9),Rect2(3,257.5,10,10),Rect2(17,246,8,9)]
	var paving: Array[Rect2] = [Rect2(-8,242,2.4,3),Rect2(5,242,2.4,3),Rect2(-13,245,27,11),Rect2(-16,249.6,3,1.8),Rect2(14,249.6,3,1.8),Rect2(-8.9,256,1.8,2),Rect2(6.9,256,2.2,1.5)]
	var court_pockets: Array[Rect2] = [Rect2(-2,245,3,3),Rect2(-2.5,253.5,4,2.5)]
	var cut_paving: Array[Rect2] = []
	for rectangle: Rect2 in paving: cut_paving.append_array(_subtract(rectangle,court_pockets))
	paving=cut_paving
	var pocket_rims: Array[Rect2] = []
	for pocket: Rect2 in court_pockets:
		pocket_rims.append_array([Rect2(pocket.position.x,pocket.position.y,pocket.size.x,.06),Rect2(pocket.position.x,pocket.end.y-.06,pocket.size.x,.06),Rect2(pocket.position.x,pocket.position.y+.06,.06,pocket.size.y-.12),Rect2(pocket.end.x-.06,pocket.position.y+.06,.06,pocket.size.y-.12)])
	var routes: Array[Rect2] = [Rect2(-8,242,2.4,8.5),Rect2(5,242,2.4,8.5),Rect2(-16,249.65,33,1.7),Rect2(-8.85,251.35,1.7,6.65),Rect2(6.9,251.35,2.2,6.15)]
	_box(street,root,"ContinuousCourtFoundation",Vector3(0,-.16,256),Vector3(55,.28,28),"land_joint",true)
	var supports: Array[Dictionary] = [{"rect":AREA,"top_y":-.02,"role":"foundation"}]
	var tiles := 0
	for i: int in range(paving.size()):
		tiles += Landscape._paving(street,root,paving[i],880+i)
		supports.append({"rect":paving[i],"top_y":.09,"role":"paving"})
	var exclusions: Array[Rect2] = footprints.duplicate()
	exclusions.append_array(paving)
	var soils := _subtract(AREA,exclusions)
	for i: int in range(soils.size()):
		var r := soils[i]
		_box(street,root,"CourtSoil_%02d" % i,Vector3(r.get_center().x,-.005,r.get_center().y),Vector3(r.size.x,.05,r.size.y),"court_forest_soil",false)
	# Quiet continuous timber screens terminate the view; separate cap/posts show construction.
	for side: float in [-1.0,1.0]:
		_screen(street,root,Vector3(side*27.35,0,256),28,true)
	_screen(street,root,Vector3(0,0,269.85),54.4,false)
	var vegetation := Node3D.new()
	vegetation.name = "CourtRootedPlanting"
	root.add_child(vegetation)
	var plants: Array[Dictionary] = []
	var props: Array[Dictionary] = []
	_prop(street,root,BENCH,"CourtBenchFacingGallery",Vector3(-.5,.09,252.8),.98,PI,props)
	_prop(street,root,RACK,"CourtBicycleRack",Vector3(11.8,.09,246.4),.78,0,props)
	var planting_obstacles: Array[Rect2] = footprints.duplicate()
	planting_obstacles.append_array(paving)
	planting_obstacles.append_array(pocket_rims)
	planting_obstacles.append(Rect2(-1.625,252.395,2.25,.80978))
	var planting_finish := _finish_soil_beds(street,vegetation,soils,planting_obstacles,plants,48,37)
	var report := {"bounds":AREA,"supports":supports,"clear_routes":routes,"paving_rectangles":paving,"building_footprints":footprints,"court_pockets":court_pockets,"pocket_rims":pocket_rims,"soil_rectangles":soils,"plants":plants,"planting_finish":planting_finish,"props":props,"paver_count":tiles,"light_sockets":[Vector3(-10,3.1,246.2),Vector3(11.5,3.1,254.8),Vector3(-1,3.1,263)],"root":str(root.get_path()),"scope":"Z>=242 only; no lights or building changes"}
	GardenEdges.build(street,root,report)
	root.set_meta("court_ground",report)
	return report

static func _box(street: Node3D,parent: Node3D,label: String,p: Vector3,size: Vector3,key: String,solid: bool=false) -> void:
	street.call("_box",parent,label,p,size,key,solid)

static func _screen(street: Node3D,parent: Node3D,p: Vector3,length: float,along_z: bool) -> void:
	var size := Vector3(length,1.8,.045)
	if along_z: size=Vector3(.045,1.8,length)
	_box(street,parent,"CourtTimberScreen",p+Vector3(0,.93,0),size,"arch_cedar",true)
	var cap := Vector3(length,.06,.10)
	if along_z: cap=Vector3(.10,.06,length)
	_box(street,parent,"ScreenWeatherCap",p+Vector3(0,1.86,0),cap,"arch_metal")
	var count := ceili(length/2.4)
	for i: int in range(count+1):
		var t := -length*.5+length*float(i)/float(count)
		var post := p+Vector3(t,.975,0)
		if along_z: post=p+Vector3(0,.975,t)
		_box(street,parent,"ScreenPost",post,Vector3(.09,1.95,.09),"arch_cedar")

static func _prop(street: Node3D,parent: Node3D,path: String,label: String,p: Vector3,height: float,yaw: float,rows: Array[Dictionary]) -> void:
	var source := Landscape._prototype(path,"")
	if source==null:
		rows.append({"id":label,"asset":path,"loaded":false})
		return
	var anchor := Node3D.new()
	anchor.name=label
	parent.add_child(anchor)
	var bounds := Landscape._instance(source,anchor,p,height,yaw,true)
	source.free()
	# One conservative physical envelope, never a collider per ornament/hoop.
	street.call("_solid",anchor,label+"Support",bounds.get_center(),bounds.size)
	anchor.set_meta("prop_bounds",bounds)
	rows.append({"id":label,"asset":path,"loaded":true,"bounds":bounds,"position":p,"height_m":height,"yaw":yaw,"collision":"single bounds envelope"})

static func _subtract(area: Rect2,cuts: Array[Rect2]) -> Array[Rect2]:
	var pieces: Array[Rect2] = [area]
	for cut: Rect2 in cuts:
		var next: Array[Rect2] = []
		for piece: Rect2 in pieces:
			var overlap := piece.intersection(cut)
			if not overlap.has_area():
				next.append(piece)
				continue
			for r: Rect2 in [Rect2(piece.position,Vector2(piece.size.x,overlap.position.y-piece.position.y)),Rect2(piece.position.x,overlap.end.y,piece.size.x,piece.end.y-overlap.end.y),Rect2(piece.position.x,overlap.position.y,overlap.position.x-piece.position.x,overlap.size.y),Rect2(overlap.end.x,overlap.position.y,piece.end.x-overlap.end.x,overlap.size.y)]:
				if r.size.x>.001 and r.size.y>.001: next.append(r)
		pieces=next
	return pieces


static func _finish_soil_beds(_street: Node3D, parent: Node3D, soils: Array[Rect2], blocked: Array[Rect2], rows: Array[Dictionary], patch_budget: int, seed: int,physical_soils: Array[Rect2]=[]) -> Dictionary:
	# Original textured foliage only: no authored blade mesh, flat grass sheet or new material.
	var rng := RandomNumberGenerator.new()
	rng.seed=seed*9109+42
	var sources: Array[Node3D] = [Landscape._prototype(Landscape.TREE_PACK,"Tree EZTree1.Bush006_leaves.006_0"),Landscape._prototype(Landscape.FERN,""),Landscape._prototype(Landscape.TREE_PACK,Landscape.TREE_NAME),Landscape._prototype(Landscape.TREE_PACK,Landscape.SHRUB_NAME),Landscape._prototype(IRIS,""),_flowering_azalea(),Landscape._prototype(Landscape.TREE_PACK,"Tree EZTree1.Bush006_leaves.006_0")]
	var transforms: Array = [[],[],[],[],[],[],[]]
	var source_labels: Array[String] = ["Bush006_leaves.006_0",Landscape.FERN,Landscape.TREE_NAME,Landscape.SHRUB_NAME,IRIS,"coral_azalea_original_sprigs_on_Bush006","Bush006_leaves_sage_local_copy"]
	_leaf_finish(sources[0],false)
	_leaf_finish(sources[2],false)
	_leaf_finish(sources[3],false)
	_leaf_finish(sources[6],true)
	var triangle_costs: Array[int] = []
	for source: Node3D in sources:
		var triangles := 0
		if source!=null:
			for visual: MeshInstance3D in source.get_children():
				for surface: int in range(visual.mesh.get_surface_count()):
					var arrays := visual.mesh.surface_get_arrays(surface)
					var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
					var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
					triangles+=indices.size()/3 if not indices.is_empty() else vertices.size()/3
					# Cache indexed/rendered bounds once, excluding unused accessor/LOD vertices.
					var rendered := AABB()
					var first_vertex := not visual.has_meta("referenced_vertex_bounds")
					if not first_vertex: rendered=visual.get_meta("referenced_vertex_bounds")
					var count := indices.size() if not indices.is_empty() else vertices.size()
					for k: int in range(count):
						var point: Vector3=vertices[indices[k] if not indices.is_empty() else k]
						rendered=AABB(point,Vector3.ZERO) if first_vertex else rendered.expand(point)
						first_vertex=false
					visual.set_meta("referenced_vertex_bounds",rendered)
		triangle_costs.append(triangles)
		if source!=null:
			var all_referenced := AABB()
			var first_mesh := true
			for visual: MeshInstance3D in source.get_children():
				var local_box: AABB=visual.get_meta("referenced_vertex_bounds")
				var box: AABB=visual.transform*local_box
				all_referenced=box if first_mesh else all_referenced.merge(box)
				first_mesh=false
			source.set_meta("source_bounds",all_referenced)
	var centres: Array[Dictionary] = []
	for soil: Rect2 in soils:
		if soil.get_area()<.8: continue
		var centre := soil.get_center()
		var visibility_weight := .35
		if seed==73 and absf(centre.x)<16: visibility_weight=4.0
		if seed==37 and absf(centre.x)<19 and centre.y<260: visibility_weight=4.0
		if Rect2(-2,245,3,3).has_point(centre) or Rect2(-2.5,253.5,4,2.5).has_point(centre): visibility_weight=24.0
		if minf(soil.size.x,soil.size.y)<1.2: visibility_weight*=12.0
		centres.append({"rect":soil,"weight":(soil.get_area()+soil.size.length()*3.0)*visibility_weight,"accepted":0,"crown_area_sum":0.0})
	var triangles_used := 0
	var rejected := 0
	var tree_positions: Array[Vector3] = []
	if seed==37:
		tree_positions.assign([Vector3(-22.5,.021,262),Vector3(-17,.021,263),Vector3(19.5,.021,263),Vector3(24,.021,259.5),Vector3(-.95,.021,254.75)])
	else:
		tree_positions.assign([Vector3(-24.7,.021,234.5),Vector3(24,.021,235)])
	for p: Vector3 in tree_positions:
		var h := 3.15+rng.randf()*.40
		var yaw := rng.randf()*TAU
		var crown_scale := Vector3.ONE
		if p.z>254 and p.z<255 and absf(p.x)<2:
			h=3.0
			yaw=0
			crown_scale=Vector3(1,1,.78)
		var record := _foliage_transform(sources[2],p,h,yaw,crown_scale)
		if record.is_empty() or not _plant_bounds_clear(record.bounds,soils,blocked):
			rejected+=1
			continue
		transforms[2].append(record.transform)
		rows.append({"position":p,"height_m":h,"kind":"tree","bounds":record.bounds,"source":Landscape.TREE_NAME,"crown_scale":crown_scale,"added_finish_pass":true})
		triangles_used+=triangle_costs[2]
	var desired := patch_budget*11+80
	var total_weight := 0.0
	for zone: Dictionary in centres: total_weight+=float(zone.weight)
	var added := 0
	var iris_accepted := 0
	var iris_clump_centres: Array[Vector2] = []
	if seed==73:
		iris_clump_centres.assign([Vector2(-10.2,232),Vector2(-9.8,238.5),Vector2(-3.4,229.5),Vector2(9.2,232.2),Vector2(9.2,238.4)])
	else:
		iris_clump_centres.assign([Vector2(-14.5,247.5),Vector2(15.4,247.5),Vector2(1.7,260),Vector2(14.8,260.5)])
	var iris_clump_counts: Array[int] = []
	iris_clump_counts.resize(iris_clump_centres.size())
	iris_clump_counts.fill(0)
	var azalea_accepted := 0
	var shrubs := 0
	var ferns := 0
	for attempt: int in range(desired*32):
		if added>=desired or centres.is_empty(): break
		# Perimeter-weighted whole-bed sampling fills connector margins and corners.
		var pick := rng.randf()*total_weight
		var zone_index := centres.size()-1
		for j: int in range(centres.size()):
			pick-=float(centres[j].weight)
			if pick<=0:
				zone_index=j
				break
		var zone: Dictionary=centres[zone_index]
		var bed: Rect2=zone.rect
		var point := bed.position+Vector2(rng.randf()*bed.size.x,rng.randf()*bed.size.y)
		var source_index := 0
		var height := rng.randf_range(.34,.50)
		var kind := "low_groundcover_cluster"
		var roll := rng.randf()
		if roll>.97:
			source_index=1
			height=rng.randf_range(.34,.52)
			kind="fern"
		elif roll>.88:
			source_index=3
			height=rng.randf_range(.60,.90)
			kind="garden_accent_shrub"
		if Rect2(-2,245,3,3).has_point(point):
			source_index=0
			height=rng.randf_range(.25,.55)
			kind="low_groundcover_cluster"
		if minf(bed.size.x,bed.size.y)<1.2:
			source_index=0
			height=rng.randf_range(.20,.30)
			kind="low_groundcover_cluster"
			# Keep roots near the narrow-bed centreline, with irregular lateral offsets.
			if bed.size.x<bed.size.y: point.x=bed.get_center().x+rng.randf_range(-.06,.06)
			else: point.y=bed.get_center().y+rng.randf_range(-.06,.06)
		# Readable colonies follow real beds, never one flower scattered in every bed.
		var iris_patch := false
		var azalea_patch := false
		if seed==73:
			for patch: Rect2 in [Rect2(-12.5,230.5,4.5,3),Rect2(-5.6,228.2,4.4,3),Rect2(7.4,230.5,4,3),Rect2(7.4,237,3,3),Rect2(-11,237,3,3)]:
				if patch.has_point(point): iris_patch=true
			for patch: Rect2 in [Rect2(-13.5,234,5,3),Rect2(8,234,3,3),Rect2(-4.4,240.5,7,1.4)]:
				if patch.has_point(point): azalea_patch=true
		else:
			for patch: Rect2 in [Rect2(-2,245,3,3),Rect2(-.1,253.5,1.6,2.5),Rect2(-16,245.4,3,3.5),Rect2(14,245.4,3,3.4),Rect2(1,258,2,4),Rect2(13,257.5,3,4)]:
				if patch.has_point(point): iris_patch=true
			for patch: Rect2 in [Rect2(-2.5,253.5,2.2,2.5),Rect2(-16,252,3,3.7),Rect2(14,252,3,3.7),Rect2(.5,262,2.5,4),Rect2(13,262,3,4)]:
				if patch.has_point(point): azalea_patch=true
		if minf(bed.size.x,bed.size.y)>=1.2:
			if iris_patch and rng.randf()<.58:
				source_index=4
				height=rng.randf_range(.34,.42)
				kind="flowering_iris"
			elif azalea_patch and rng.randf()<.40:
				source_index=5
				height=rng.randf_range(.52,.72)
				kind="flowering_azalea"
			elif source_index==0 and sin(point.x*.73+point.y*.49)>.10:
				source_index=6
		elif source_index==0 and sin(point.y*.55)>.20:
			source_index=6
		if (source_index==4 and iris_accepted>=(44 if seed==37 else 28)) or (source_index==5 and azalea_accepted>=(12 if seed==37 else 8)):
			source_index=6
			height=rng.randf_range(.30,.45)
			kind="low_groundcover_cluster"
		var iris_group := -1
		var keep_pocket_mass := seed==37 and (Rect2(-2,245,3,3).has_point(point) or Rect2(-2.5,253.5,4,2.5).has_point(point))
		if source_index==4 and not keep_pocket_mass:
			# Fill a small group before opening the next; avoid isolated marching specimens.
			for j: int in range(iris_clump_counts.size()):
				if iris_clump_counts[j]<6:
					iris_group=j
					break
			if iris_group<0:
				source_index=6
				height=rng.randf_range(.30,.45)
				kind="low_groundcover_cluster"
			else:
				var angle := rng.randf()*TAU
				var distance := sqrt(rng.randf())*.57
				point=iris_clump_centres[iris_group]+Vector2(cos(angle),sin(angle)*.77)*distance
		if triangles_used+triangle_costs[source_index]>2400000: continue
		var p := Vector3(point.x,.021,point.y)
		var record := _foliage_transform(sources[source_index],p,height,rng.randf()*TAU)
		if record.is_empty() or not _plant_bounds_clear(record.bounds,soils,blocked):
			rejected+=1
			continue
		# Close, overlapping crowns read as drifts; keep roots irregular without duplicated positions.
		var separate := true
		for previous: Dictionary in rows:
			if previous.position.distance_to(p)<(.13 if source_index==4 else .19): separate=false; break
		if not separate: continue
		if iris_group>=0:
			for j: int in range(centres.size()):
				var actual_bed: Rect2=centres[j].rect
				if actual_bed.has_point(point):
					zone_index=j
					break
		transforms[source_index].append(record.transform)
		rows.append({"position":p,"height_m":height,"kind":kind,"bounds":record.bounds,"source":source_labels[source_index],"flower":source_index==4 or source_index==5,"iris_clump":iris_group,"added_finish_pass":true})
		centres[zone_index].accepted=int(centres[zone_index].accepted)+1
		centres[zone_index].crown_area_sum=float(centres[zone_index].crown_area_sum)+record.bounds.size.x*record.bounds.size.z
		added+=1
		if source_index==4:
			iris_accepted+=1
			if iris_group>=0: iris_clump_counts[iris_group]+=1
		if source_index==5: azalea_accepted+=1
		if kind=="garden_accent_shrub": shrubs+=1
		if source_index==1: ferns+=1
		triangles_used+=triangle_costs[source_index]
	var grounding := _infill_groundcover(sources,transforms,rows,source_labels,triangle_costs,physical_soils if not physical_soils.is_empty() else soils,blocked,seed,triangles_used)
	triangles_used=int(grounding.instanced_triangle_count)
	for zone: Dictionary in centres:
		zone.accepted=0
		zone.crown_area_sum=0.0
	for row: Dictionary in rows:
		if row.kind=="tree": continue
		var point: Vector3=row.position
		for zone: Dictionary in centres:
			var area: Rect2=zone.rect
			if area.has_point(Vector2(point.x,point.z)):
				zone.accepted=int(zone.accepted)+1
				zone.crown_area_sum=float(zone.crown_area_sum)+row.bounds.size.x*row.bounds.size.z
				break
	var by_kind: Dictionary = {}
	for row: Dictionary in rows: by_kind[row.kind]=int(by_kind.get(row.kind,0))+1
	var batches := 0
	for i: int in range(sources.size()):
		if sources[i]==null: continue
		if not transforms[i].is_empty():
			for visual: MeshInstance3D in sources[i].get_children():
				# Copy only the mesh container to retain EXACT existing active material references.
				var render_mesh := visual.mesh.duplicate() as ArrayMesh
				for surface: int in range(render_mesh.get_surface_count()): render_mesh.surface_set_material(surface,visual.get_active_material(surface))
				var mm := MultiMesh.new()
				mm.transform_format=MultiMesh.TRANSFORM_3D
				mm.mesh=render_mesh
				mm.instance_count=transforms[i].size()
				for j: int in range(transforms[i].size()): mm.set_instance_transform(j,transforms[i][j]*visual.transform)
				var batch := MultiMeshInstance3D.new()
				batch.name="OriginalGardenFoliage_%02d" % batches
				batch.multimesh=mm
				batch.set_meta("authored_instance_transforms",transforms[i])
				parent.add_child(batch)
				batches+=1
		sources[i].free()
	return {"grounding":grounding,"low_clusters_added":int(by_kind.get("low_groundcover_cluster",0)),"accent_shrubs_added":shrubs,"ferns_added":ferns,"trees_added":transforms[2].size(),"actual_plant_count":rows.size(),"counts_by_kind":by_kind,"iris_clump_centres":iris_clump_centres,"iris_clump_counts":iris_clump_counts,"flowering_iris_added":int(by_kind.get("flowering_iris",0)),"flowering_azalea_added":int(by_kind.get("flowering_azalea",0)),"source_labels":source_labels,"material_policy":"local leaf-only gain/backlight copies; original textures/cutout/PBR/bark/flowers preserved; no emission","distribution_areas":centres,"triangle_budget":2400000,"non_multimesh_plants_added":0,"cluster_budget":desired,"grass_tuft_instances":0,"grass_multimesh_nodes":0,"foliage_multimesh_nodes":batches,"source_triangles_per_instance":triangle_costs,"instanced_triangle_count":triangles_used,"rejected_bounds":rejected,"root_y":.021,"collisions_created":0,"palette_changed":true,"path_policy":"every complete conservative original-mesh AABB remains in soil and >=.08m outside paths and buildings","composition":"perimeter-weighted whole-bed overlapping foliage, full source stemmed shrubs, rare ferns; no lattice/procedural grass; crown_area_sum is overlapping AABB sum NOT measured union coverage"}

static func _foliage_transform(source: Node3D,p: Vector3,height: float,yaw: float,shape_scale: Vector3=Vector3.ONE) -> Dictionary:
	if source==null: return {}
	var raw: AABB=source.get_meta("source_bounds")
	var factor := height/maxf(raw.size.y,.001)
	var pivot := Vector3(raw.get_center().x,raw.position.y,raw.get_center().z)
	var basis := Basis(Vector3.UP,yaw).scaled(Vector3.ONE*factor*shape_scale)
	var transform := Transform3D(basis,p-basis*pivot)
	var bounds := AABB()
	var first := true
	for visual: MeshInstance3D in source.get_children():
		var referenced: AABB=visual.get_meta("referenced_vertex_bounds")
		var box: AABB=transform*visual.transform*referenced
		bounds=box if first else bounds.merge(box)
		first=false
	return {"transform":transform,"bounds":bounds}

static func _plant_bounds_clear(bounds: AABB,soils: Array[Rect2],blocked: Array[Rect2]) -> bool:
	var crown := Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z)
	for obstacle: Rect2 in blocked:
		if obstacle.grow(.08).intersects(crown): return false
	for point: Vector2 in [crown.position,Vector2(crown.end.x,crown.position.y),crown.end,Vector2(crown.position.x,crown.end.y),crown.get_center()]:
		var found := false
		for soil: Rect2 in soils:
			if soil.grow(.0001).has_point(point): found=true; break
		if not found: return false
	return true

static func _leaf_finish(source: Node3D,sage: bool) -> void:
	if source==null: return
	var copies: Dictionary = {}
	for visual: MeshInstance3D in source.get_children():
		for surface: int in range(visual.mesh.get_surface_count()):
			var original := visual.get_active_material(surface) as StandardMaterial3D
			if original==null or not (str(original.resource_name).to_lower().contains("leave") or str(visual.name).to_lower().contains("leave")): continue
			if not copies.has(original):
				var leaf := original.duplicate() as StandardMaterial3D
				leaf.resource_name="CourtSageLeafLocal" if sage else "CourtMediumGreenLeafLocal"
				# Small texture-preserving linear gain plus physically lit transmitted light.
				leaf.albedo_color=original.albedo_color*(Color(1.04,1.06,1.06) if sage else Color(1.02,1.06,0.94))
				leaf.backlight_enabled=true
				leaf.backlight=Color(.08,.10,.05) if not sage else Color(.09,.11,.09)
				leaf.emission_enabled=false
				copies[original]=leaf
			visual.set_surface_override_material(surface,copies[original])

static func _flowering_azalea() -> Node3D:
	var bush := Landscape._prototype(Landscape.TREE_PACK,Landscape.SHRUB_NAME)
	var sprig := Landscape._prototype(AZALEA,"")
	if bush==null or sprig==null:
		if bush!=null: bush.free()
		if sprig!=null: sprig.free()
		return null
	var result := Node3D.new()
	result.name="OriginalCoralAzaleaSprigsOnStemmedShrub"
	# A complete stemmed woody crown supports five original scanned flowering tips.
	var raw := _referenced_bounds(bush)
	var factor := 1.0/maxf(raw.size.y,.001)
	var pivot := Vector3(raw.get_center().x,raw.position.y,raw.get_center().z)
	var base := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*factor),-pivot*factor)
	for visual: MeshInstance3D in bush.get_children():
		var copy := visual.duplicate(7) as MeshInstance3D
		copy.transform=base*visual.transform
		result.add_child(copy)
	var flower_raw := _referenced_bounds(sprig)
	var flower_scale := .19/maxf(flower_raw.size.y,.001)
	var flower_pivot := Vector3(flower_raw.get_center().x,flower_raw.position.y,flower_raw.get_center().z)
	for i: int in range(5):
		var angle := float(i)*2.399963
		var basis := Basis(Vector3.UP,angle).scaled(Vector3.ONE*flower_scale)
		var origin := Vector3(cos(angle)*.34,.76+.055*sin(angle*1.7),sin(angle)*.34)
		var transform := Transform3D(basis,origin-basis*flower_pivot)
		for visual: MeshInstance3D in sprig.get_children():
			var copy := visual.duplicate(7) as MeshInstance3D
			copy.transform=transform*visual.transform
			result.add_child(copy)
	bush.free()
	sprig.free()
	result.set_meta("source_bounds",_referenced_bounds(result))
	return result

static func _referenced_bounds(source: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for visual: MeshInstance3D in source.get_children():
		for surface: int in range(visual.mesh.get_surface_count()):
			var arrays: Array=visual.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for i: int in range(count):
				var point: Vector3=visual.transform*vertices[indices[i] if not indices.is_empty() else i]
				bounds=AABB(point,Vector3.ZERO) if first else bounds.expand(point)
				first=false
	return bounds
static func _soil_material(street: Node3D) -> void:
	var mats: Dictionary=street.get("materials")
	if mats.has("court_forest_soil"): return
	var folder := "res://assets/shinrai/parks/midori_park/materials/forrest_ground_01/"
	var soil := StandardMaterial3D.new()
	soil.resource_name="CourtExistingCC0ForestGround01"
	soil.albedo_texture=load(folder+"forrest_ground_01_diff_2k.jpg")
	soil.normal_enabled=true
	soil.normal_texture=load(folder+"forrest_ground_01_nor_gl_2k.jpg")
	soil.normal_scale=.65
	soil.roughness_texture=load(folder+"forrest_ground_01_rough_2k.jpg")
	soil.roughness=1.0
	soil.albedo_color=Color(.84,.79,.68)
	soil.uv1_triplanar=true
	soil.uv1_world_triplanar=true
	soil.uv1_scale=Vector3.ONE*.5
	soil.set_meta("provenance","Poly Haven ForestGround01, Rob Tuytel, CC0; existing ATTRIBUTION.md; 2m repeat matches midori_ground_texture.gd TEXTURE_WORLD_SIZE_M")
	mats["court_forest_soil"]=soil

static func _infill_groundcover(sources: Array[Node3D],transforms: Array,rows: Array[Dictionary],labels: Array[String],costs: Array[int],soils: Array[Rect2],blocked: Array[Rect2],seed: int,triangles: int) -> Dictionary:
	var zones: Array[Rect2] = []
	if seed==73:
		zones.assign([Rect2(-5.6,228.5,6.05,3),Rect2(-5.6,231.5,1,6),Rect2(2.6,231.5,2.4,6),Rect2(2.05,228.5,2.95,3)])
	else:
		zones.assign([Rect2(-.8,258,3.8,8.8),Rect2(13,257.6,3.8,9)])
	var holes: Array[Rect2] = []
	if seed==73: holes.assign([Rect2(-4.94,239.72,.32,.38),Rect2(2.62,239.72,.32,.38)])
	var obstacles: Array[Rect2]=blocked.duplicate()
	obstacles.append_array(holes)
	var original := transforms.duplicate(true)
	var cursors: Array[int]=[]
	cursors.resize(sources.size())
	cursors.fill(0)
	for i: int in range(transforms.size()): transforms[i]=[]
	var keep: Array[Dictionary] = []
	var removed := 0
	var protected_conflicts: Array = []
	for row: Dictionary in rows:
		var index := labels.find(str(row.source))
		var transform: Transform3D=original[index][cursors[index]]
		cursors[index]+=1
		var p: Vector3=row.position
		var in_focus := false
		for zone: Rect2 in zones:
			if zone.has_point(Vector2(p.x,p.z)): in_focus=true
		var pocket := seed==37 and (Rect2(-2,245,3,3).has_point(Vector2(p.x,p.z)) or Rect2(-2.5,253.5,4,2.5).has_point(Vector2(p.x,p.z)))
		var hits_hole := false
		var bounds: AABB=row.bounds
		for hole: Rect2 in holes:
			if hole.grow(.08).intersects(Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z)): hits_hole=true
		var low := str(row.kind)=="low_groundcover_cluster"
		if low and (hits_hole or (not in_focus and not pocket and float(row.height_m)>.30 and removed<(120 if seed==37 else 60))):
			triangles-=costs[index]
			removed+=1
			continue
		if hits_hole: protected_conflicts.append(row)
		row["ground_transform"]=transform
		row["source_index"]=index
		transforms[index].append(transform)
		keep.append(row)
	rows.clear()
	rows.append_array(keep)
	var rng := RandomNumberGenerator.new()
	rng.seed=seed*8087+112
	var added := 0
	var zone_added: Array[int]=[]
	zone_added.resize(zones.size())
	zone_added.fill(0)
	for attempt: int in range(18000):
		if added>=(260 if seed==37 else 440): break
		var index := 0 if rng.randf()<.55 else 6
		if triangles+costs[index]>2400000: continue
		var z := rng.randi_range(0,zones.size()-1)
		var zone: Rect2=zones[z]
		var point := zone.position+Vector2(rng.randf()*zone.size.x,rng.randf()*zone.size.y)
		var height := rng.randf_range(.25,.39)
		if minf(zone.size.x,zone.size.y)<1.2:
			height=rng.randf_range(.20,.28)
			point.x=zone.get_center().x+rng.randf_range(-.06,.06)
		var p := Vector3(point.x,.021,point.y)
		var record := _foliage_transform(sources[index],p,height,rng.randf()*TAU)
		if record.is_empty() or not _plant_bounds_clear(record.bounds,soils,obstacles): continue
		var crowded := false
		for previous: Dictionary in rows:
			if previous.position.distance_to(p)<.19: crowded=true; break
		if crowded: continue
		transforms[index].append(record.transform)
		rows.append({"position":p,"height_m":height,"kind":"low_groundcover_cluster","bounds":record.bounds,"source":labels[index],"flower":false,"iris_clump":-1,"added_finish_pass":true,"grounding_infill":true,"ground_transform":record.transform,"source_index":index})
		added+=1
		zone_added[z]+=1
		triangles+=costs[index]
	# Projecting every leaf triangle is an explicit review audit, never normal boot work.
	var coverage: Array[Dictionary] = []
	if OS.get_cmdline_user_args().has("--court-ground-coverage"):
		coverage = _projected_coverage(rows,sources,zones,soils)
	return {"zones":zones,"zone_added":zone_added,"removed_remote_low_cover":removed,"added_low_cover":added,"instanced_triangle_count":triangles,"protected_drain_conflicts":protected_conflicts,"coverage":coverage,"method":"unchanged original flower/tree pass, separate seeded low-only infill; overlap irregularly, preserve mulch gaps; 2.4m strict total triangle cap"}

static func _projected_coverage(rows: Array[Dictionary],sources: Array[Node3D],zones: Array[Rect2],soils: Array[Rect2]) -> Array[Dictionary]:
	# Real referenced triangle projections with sampled texture alpha, not AABB areas.
	var result: Array[Dictionary]=[]
	var images: Dictionary={}
	var step := .18
	for zone: Rect2 in zones:
		var nx := ceili(zone.size.x/step)
		var nz := ceili(zone.size.y/step)
		var soil_samples: Dictionary={}
		var covered: Dictionary={}
		for iz: int in range(nz):
			for ix: int in range(nx):
				var p := zone.position+Vector2((ix+.5)*step,(iz+.5)*step)
				if not zone.has_point(p): continue
				for soil: Rect2 in soils:
					if soil.has_point(p): soil_samples[ix+iz*nx]=true; break
		for row: Dictionary in rows:
			if row.kind=="tree": continue
			var box: AABB=row.bounds
			if not zone.intersects(Rect2(box.position.x,box.position.z,box.size.x,box.size.z)): continue
			var source: Node3D=sources[int(row.source_index)]
			var placement: Transform3D=row.ground_transform
			for visual: MeshInstance3D in source.get_children():
				var matrix := placement*visual.transform
				for surface: int in range(visual.mesh.get_surface_count()):
					var arrays: Array=visual.mesh.surface_get_arrays(surface)
					var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
					var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
					var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
					var count := indices.size() if not indices.is_empty() else vertices.size()
					var material := visual.get_active_material(surface) as StandardMaterial3D
					var image: Image=null
					if material!=null and material.albedo_texture!=null and material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:
						var texture: Texture2D=material.albedo_texture
						if not images.has(texture):
							var pixels := texture.get_image()
							if pixels!=null and pixels.is_compressed(): pixels.decompress()
							images[texture]=pixels
						image=images[texture]
					for k: int in range(0,count,3):
						var ids := [indices[k],indices[k+1],indices[k+2]] if not indices.is_empty() else [k,k+1,k+2]
						var a3: Vector3=matrix*vertices[ids[0]]
						var b3: Vector3=matrix*vertices[ids[1]]
						var c3: Vector3=matrix*vertices[ids[2]]
						var a := Vector2(a3.x,a3.z)
						var b := Vector2(b3.x,b3.z)
						var c := Vector2(c3.x,c3.z)
						var determinant := (b-a).cross(c-a)
						if absf(determinant)<.000001: continue
						var minx := maxi(0,floori((minf(a.x,minf(b.x,c.x))-zone.position.x)/step))
						var maxx := mini(nx-1,floori((maxf(a.x,maxf(b.x,c.x))-zone.position.x)/step))
						var minz := maxi(0,floori((minf(a.y,minf(b.y,c.y))-zone.position.y)/step))
						var maxz := mini(nz-1,floori((maxf(a.y,maxf(b.y,c.y))-zone.position.y)/step))
						for iz: int in range(minz,maxz+1):
							for ix: int in range(minx,maxx+1):
								var key := ix+iz*nx
								if covered.has(key) or not soil_samples.has(key): continue
								var point := zone.position+Vector2((ix+.5)*step,(iz+.5)*step)
								var v := (point-a).cross(c-a)/determinant
								var w := (b-a).cross(point-a)/determinant
								if v<0 or w<0 or v+w>1: continue
								if image!=null and not uv.is_empty():
									var sample_uv: Vector2=uv[ids[0]]*(1-v-w)+uv[ids[1]]*v+uv[ids[2]]*w
									var alpha := image.get_pixel(posmod(floori(sample_uv.x*image.get_width()),image.get_width()),posmod(floori(sample_uv.y*image.get_height()),image.get_height())).a
									if alpha<.35: continue
								covered[key]=true
		result.append({"rect":zone,"sample_step_m":step,"soil_samples":soil_samples.size(),"covered_samples":covered.size(),"projected_foliage_fraction":float(covered.size())/maxi(1,soil_samples.size()),"scope":"sampled orthographic referenced-triangle/texture-alpha footprint, excludes trees; not screenshot segmentation or AABB sum"})
	return result
