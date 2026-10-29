extends RefCounted
## Candidate only. Call once after landscape build and before static batching.
const Landscape = preload("res://scripts/midori_south_street_landscape.gd")
const SOURCE := "Tree EZTree0.Medium011_leaves.011_0"

static func build(street: Node3D, _landscape: Dictionary) -> Dictionary:
	var report := {"scope":"visual foliage only", "climbers":[], "entry_crowns":[], "triangles":0, "source_pack":Landscape.TREE_PACK, "climber_source":SOURCE, "climber_texture":"leaves.011_baseColor.png", "rejected_texture":"leaves.006_baseColor.png is conifer spray, not a climber atlas", "new_collisions":0}
	var prototype: Node3D = Landscape._prototype(Landscape.TREE_PACK,SOURCE)
	if prototype == null or prototype.get_child_count() == 0:
		report["error"] = "Broadleaf source missing; existing foliage retained"
		if prototype != null: prototype.free()
		return report
	var source := prototype.get_child(0) as MeshInstance3D
	var material := _cutout(source.get_active_material(0))
	if material == null:
		prototype.free()
		report["error"] = "Source cutout material missing; existing foliage retained"
		return report
	# Source inspection confirmed full [0,1] UV oak branch sprays, two triangles
	# per card, with authored normals. This is a textured branch, not one leaf.
	var source_arrays: Array = source.mesh.surface_get_arrays(0)
	var uv: PackedVector2Array = source_arrays[Mesh.ARRAY_TEX_UV]
	var source_indices: PackedInt32Array = source_arrays[Mesh.ARRAY_INDEX]
	var uv_contract := uv.size() >= 6 and source_indices.size() >= 6
	if not uv_contract:
		prototype.free()
		report["error"] = "Source UV contract failed; existing foliage retained"
		return report
	var pending: Array[Node] = [street]
	while not pending.is_empty():
		var queued: Variant = pending.pop_back()
		if not is_instance_valid(queued): continue
		var node := queued as Node
		pending.append_array(node.get_children())
		if node is Node3D and str(node.name).begins_with("PassageClimber"):
			var old := node.get_node_or_null("BatchedFoldedClimberLeaves") as MeshInstance3D
			if old != null:
				var row := _climber(node as Node3D,old,material)
				report.climbers.append(row)
				report.triangles += row.triangles
		if node is Node3D and str(node.name) in ["RecessedArrivalGarden_0","RecessedArrivalGarden_1"]:
			var rows := _entry_crown(node as Node3D)
			report.entry_crowns.append_array(rows)
	prototype.free()
	report["climber_batches"] = report.climbers.size()
	report["climber_sprays"] = report.climbers.size()*275
	report["climber_triangles"] = report.climbers.size()*35200
	report["uv"] = "source full-card UV orientation, no atlas guessing; source texture resource reused"
	report["acceptance"] = "native counts and visual QA required; build report alone is not acceptance"
	return report

static func _cutout(source: Material) -> StandardMaterial3D:
	if not source is StandardMaterial3D: return null
	var result := source.duplicate() as StandardMaterial3D
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	result.alpha_scissor_threshold = .36
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.roughness = .86
	result.metallic = 0.0
	result.emission_enabled = false
	# Retain the source albedo/normal textures and UV settings. Avoid alpha blend
	# sorting errors and allow the same cutout silhouette to cast native shadows.
	return result

static func _climber(root: Node3D, old: MeshInstance3D, material: StandardMaterial3D) -> Dictionary:
	var bounds := old.get_aabb()
	var side := -1.0 if root.position.x < 0.0 else 1.0
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vine: int in range(5):
		for joint: int in range(11):
			var point := Vector3(-side*.063,.345+float(joint)*.215,-.64+float(vine)*.32+.09*sin(float(joint)*1.8+vine))
			for spray: int in range(5):
				var phase := float(spray)*2.399+float(joint+vine*11)*.37
				var origin := point+Vector3(-side*(.006+.006*(spray%3)),.054*sin(phase),.072*cos(phase))
				var along := Vector3(-side*.13,cos(phase*.45),sin(phase*.45)).normalized()
				var across := Vector3(0,-along.z,along.y).normalized()
				var facing := across.cross(along).normalized()
				if facing.x*side > 0.0: facing = -facing
				var length := .205+.012*float((spray+joint)%4)
				# 8x8 is actual curved geometry, 128 triangles per branch spray.
				for y: int in range(8):
					for x: int in range(8):
						var a := Vector2(float(x)/8.0,float(y)/8.0)
						var b := a+Vector2(0,.125)
						var c := a+Vector2(.125,.125)
						var d := a+Vector2(.125,0)
						for coord: Vector2 in [a,b,c,a,c,d]:
							var u := coord.x
							var v := 1.0-coord.y
							var cup := .022*sin(PI*u)*sin(PI*v)
							var vertex := origin+across*(u-.5)*length*.77+along*v*length+facing*cup
							# Preserve the previous physical projection and full local AABB.
							vertex = vertex.clamp(bounds.position,bounds.end)
							var du := across*length*.77+facing*(.022*PI*cos(PI*u)*sin(PI*v))
							var dv := along*length+facing*(.022*PI*sin(PI*u)*cos(PI*v))
							var normal := du.cross(dv).normalized()
							if normal.dot(facing)<0.0: normal = -normal
							tool.set_normal(normal)
							tool.set_uv(coord)
							tool.add_vertex(vertex)
	tool.index()
	var mesh: ArrayMesh = tool.commit()
	var visual := MeshInstance3D.new()
	visual.name = "BatchedTexturedBroadleafClimber"
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.remove_child(old)
	old.free()
	root.add_child(visual)
	var row := {"root":str(root.get_path()),"rooted_vines":5,"sprays":275,"triangles":35200,"vertices":mesh.surface_get_array_len(0),"batches":1,"previous_local_bounds":bounds,"local_bounds":mesh.get_aabb(),"world_bounds":visual.global_transform*mesh.get_aabb(),"source_texture":material.albedo_texture.resource_path,"alpha_scissor":material.alpha_scissor_threshold,"cast_shadow":"ON","uv_range":Rect2(0,0,1,1)}
	root.set_meta("layered_greenery_membership",row)
	root.set_meta("neighbourhood_textured_climber",true)
	return row

static func _entry_crown(root: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if not node is MeshInstance3D: continue
		var visual := node as MeshInstance3D
		var label := str(visual.name).to_lower().replace(" ","").replace(".","").replace("_","")
		if not label.begins_with("treeeztree1large001leaves0010"): continue
		if visual.has_meta("neighbourhood_cupped_crown"): continue
		var mesh: ArrayMesh = ArrayMesh.new()
		var old_count := 0
		var new_count := 0
		for surface: int in range(visual.mesh.get_surface_count()):
			var material := _cutout(visual.get_active_material(surface))
			if material == null: continue
			var arrays: Array = visual.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i: int in range(0,count,3):
				var ids: Array[int] = []
				for j: int in range(3): ids.append(indices[i+j] if not indices.is_empty() else i+j)
				var a: Vector3 = vertices[ids[0]]
				var b: Vector3 = vertices[ids[1]]
				var c: Vector3 = vertices[ids[2]]
				var amplitude := minf(a.distance_to(b),a.distance_to(c))*.035
				# Four triangles per original triangle, preserving existing card UVs
				# and authored normals with a subtle smooth bowl inside the card.
				var bary: Array[Vector3] = [Vector3(1,0,0),Vector3(.5,.5,0),Vector3(.5,0,.5),Vector3(0,1,0),Vector3(0,.5,.5),Vector3(0,0,1)]
				for k: int in [0,1,2,1,3,4,2,4,5,1,4,2]:
					var w: Vector3 = bary[k]
					var tex: Vector2 = uv[ids[0]]*w.x+uv[ids[1]]*w.y+uv[ids[2]]*w.z
					var normal: Vector3 = (normals[ids[0]]*w.x+normals[ids[1]]*w.y+normals[ids[2]]*w.z).normalized()
					var point: Vector3 = a*w.x+b*w.y+c*w.z+normal*amplitude*sin(PI*tex.x)*sin(PI*tex.y)
					tool.set_uv(tex)
					tool.set_normal(normal)
					tool.add_vertex(point)
			old_count += count/3
			new_count += count/3*4
			tool.index()
			tool.generate_normals()
			var part: ArrayMesh = tool.commit()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.surface_get_arrays(0))
			mesh.surface_set_material(mesh.get_surface_count()-1,material)
		if mesh.get_surface_count() == 0: continue
		visual.mesh = mesh
		visual.material_override = null
		for surface: int in range(mesh.get_surface_count()): visual.set_surface_override_material(surface,null)
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		visual.set_meta("neighbourhood_cupped_crown",true)
		result.append({"root":str(root.get_path()),"mesh":str(visual.get_path()),"source":"Tree EZTree1.Large001 existing retained crown", "texture":"leaves.001_baseColor.png","previous_triangles":old_count,"triangles":new_count,"world_bounds":_rendered_world_bounds(visual),"branches_preserved":true,"placement_preserved":true,"alpha_scissor":.36})
	return result

static func _rendered_world_bounds(visual: MeshInstance3D) -> AABB:
	# A rotated local AABB is conservative. Report the actual transformed,
	# referenced vertices so renderer evidence can compare exact native bounds.
	var result := AABB()
	var first := true
	for surface: int in range(visual.mesh.get_surface_count()):
		var arrays: Array = visual.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		for index: int in range(indices.size() if not indices.is_empty() else vertices.size()):
			var point: Vector3 = visual.global_transform*vertices[indices[index] if not indices.is_empty() else index]
			result=AABB(point,Vector3.ZERO) if first else result.expand(point)
			first=false
	return result

static func plant_context(street: Node3D, context: Dictionary) -> Dictionary:
	var parent: Node3D = context.get("root")
	if parent == null: return {"error":"Context root missing", "plants":[]}
	var root := Node3D.new()
	root.name = "ContextGardenPlanting"
	root.set_meta("creator_protected",true)
	root.set_meta("creator_editable",false)
	parent.add_child(root)
	var sources: Array[Node3D] = [Landscape._prototype(Landscape.TREE_PACK,Landscape.TREE_NAME),Landscape._prototype(Landscape.TREE_PACK,"Tree EZTree1.Bush006_leaves.006_0"),Landscape._prototype(Landscape.FERN,""),Landscape._prototype("res://assets/shinrai/parks/midori_park/models/identity2050/midori_2050_iris_clump.glb","")]
	# Imported source accessors contain vertices not referenced by the chosen
	# surface. Derive metric normalization and soil contact from retained geometry.
	for prototype: Node3D in sources:
		if prototype == null: continue
		var bounds := AABB()
		var first := true
		for child: Node in prototype.get_children():
			if not child is MeshInstance3D: continue
			var visual := child as MeshInstance3D
			for surface: int in range(visual.mesh.get_surface_count()):
				var arrays: Array = visual.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var count: int = indices.size() if not indices.is_empty() else vertices.size()
				for i: int in range(count):
					var vertex: Vector3 = visual.transform*vertices[indices[i] if not indices.is_empty() else i]
					bounds = AABB(vertex,Vector3.ZERO) if first else bounds.expand(vertex)
					first = false
		if not first: prototype.set_meta("source_bounds",bounds)
	var labels: Array[String] = ["oak","shrub","fern","iris"]
	var rows: Array[Dictionary] = []
	var rejected: Array[Dictionary] = []
	var triangles := 0
	var specs: Array[Vector4] = []
	# Four broadleaf trees per parcel frame the houses and approach. Height
	# variation follows the street sequence rather than random tree scattering.
	for spec: Vector4 in [Vector4(0,30.8,231.5,5.5),Vector4(0,-46.8,192.5,3.8),Vector4(0,-45.8,201.7,4.4),Vector4(0,-45.8,220.0,4.9),Vector4(0,49.1,240.1,3.1),Vector4(0,46.8,192.5,4.8),Vector4(0,45.8,201.5,3.7),Vector4(0,46.8,222.3,6.6)]:
		specs.append(spec)
	for side: float in [-1.0,1.0]:
		# Shallow, overlapping crescents form garden masses at five intentional
		# bays. The source is a complete small shrub crown, never a whole bush
		# replicated per leaf. Ferns and iris are sparse accents within the mass.
		for bay: int in range(5):
			var z: float = [181.0,193.0,201.0,219.0,240.0][bay]
			for slot: int in range(10):
				var t := float(slot)/9.0
				var x := 43.3+6.3*t
				var dz := -.9+1.65*sin(PI*t)
				var kind := 2 if slot == 2 else (3 if slot == 6 else 1)
				var height := (.53 if kind == 2 else (.44 if kind == 3 else .67+.13*sin(PI*t)))
				specs.append(Vector4(kind,side*x,z+dz,height))
		# Short low drifts occupy the inner road parcels in the corner views;
		# openings between them retain visible soil and low junction sightlines.
		for bay: int in range(4):
			var z: float = [198.0,208.0,217.8,239.0][bay]
			for slot: int in range(8):
				var x := 28.7+float(slot%3)*.84
				var dz := float(slot/3)*.82-.82
				var kind := 2 if slot == 4 else 1
				specs.append(Vector4(kind,side*x,z+dz,.47 if kind == 2 else .52+.06*float(slot%3)))
	# Low rooted groups reinforce the new lane and residential tree anchors.
	for center: Vector2 in [Vector2(30.8,231.5),Vector2(49.1,240.1),Vector2(46.8,222.3)]:
		for slot: int in range(4):
			var x := center.x-.7+float(slot%2)*1.1
			var z := center.y-.7+float(slot/2)*1.1
			specs.append(Vector4(2 if slot == 0 else 1,x,z,.46 if slot == 0 else .57))
	for spec: Vector4 in specs:
		var kind := int(spec.x)
		if sources[kind] == null: continue
		var before := root.get_child_count()
		var box: AABB = Landscape._instance(sources[kind],root,Vector3(spec.y,-.015,spec.z),spec.w,float(before)*.8,true)
		var crown := Rect2(box.position.x,box.position.z,box.size.x,box.size.z)
		var clear := false
		for soil: Rect2 in context.get("soil_rectangles",[]):
			if soil.encloses(crown): clear = true
		for path: Rect2 in context.get("paved_rectangles",[]):
			if path.grow(.75).intersects(crown): clear = false
		for road: Rect2 in context.get("road_rectangles",[]):
			if road.grow(.75).intersects(crown): clear = false
		for footprint: Rect2 in context.get("building_footprints",[]):
			if footprint.grow(.75).intersects(crown): clear = false
		var plant := root.get_child(before) as Node3D
		if not clear:
			rejected.append({"kind":labels[kind],"bounds":box,"reason":"full crown does not fit actual soil plus route/building clearance"})
			root.remove_child(plant)
			plant.free()
			continue
		var count := _triangles(plant)
		if triangles+count > 800000:
			rejected.append({"kind":labels[kind],"bounds":box,"reason":"800000 context triangle budget"})
			root.remove_child(plant)
			plant.free()
			continue
		triangles += count
		rows.append({"kind":labels[kind],"root":plant.position,"world_bounds":box,"triangles":count,"height_m":spec.w})
	for source: Node3D in sources:
		if source != null: source.free()
	var accepted_trees := 0
	for row: Dictionary in rows:
		if row.kind == "oak": accepted_trees += 1
	var report := {"plants":rows,"rejected":rejected,"triangles":triangles,"accepted_trees":accepted_trees,"planned_trees":8,"planned_lower_plants":176,"triangle_budget":800000,"new_collisions":0,"soil_world_y":-.015,"clearance_from_paved_and_road_edges_m":.75,"placement":"eight tree anchors, five curved outer garden masses per side and four low inner parcel drifts per side; actual crown containment and route gaps preserved", "batching":"root static batcher owns final mesh batching"}
	root.set_meta("context_planting",report)
	return report

static func _triangles(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		for surface: int in range(visual.mesh.get_surface_count()):
			var indices: int = visual.mesh.surface_get_array_index_len(surface)
			count += (indices if indices > 0 else visual.mesh.surface_get_array_len(surface))/3
	for child: Node in node.get_children(): count += _triangles(child)
	return count
