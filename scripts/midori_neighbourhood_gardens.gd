extends RefCounted
## Additive metre-scale garden continuity. Call after plant_context and before
## street batching. Existing soil, plants, materials and collisions are retained.
const Landscape = preload("res://scripts/midori_south_street_landscape.gd")
const BakeCache = preload("res://scripts/shinrai_mesh_bake_cache.gd")
const Ground = preload("res://scripts/midori_neighbourhood_ground.gd")
const MeshArrays = preload("res://scripts/midori_south_street_mesh_arrays.gd")
const LOW_SOURCE: String = "Tree EZTree1.Bush006_leaves.006_0"
const TRIANGLE_BUDGET: int = 1800000
const CELL_SIZE: float = 18.0
const ROUTE_CLEARANCE: float = 0.24
const ROOF_CLEARANCE: float = 0.60
const TRUNK_MULCH_RADIUS: float = 0.58
const CONTACT_EMBED: float = 0.002

static func build(street: Node3D, context: Dictionary, neighbourhood: Dictionary) -> Dictionary:
	var context_root: Node3D = context.get("root") as Node3D
	if context_root == null:
		return {"ok": false, "error": "Context root missing; existing gardens retained"}
	if context_root.has_node("NeighbourhoodGardenContinuity"):
		return {"ok": false, "error": "Garden continuity already built; duplicate build refused"}
	var soils: Array[Rect2] = []
	soils.assign(context.get("soil_rectangles", []))
	soils.append_array(neighbourhood.get("soil_rectangles", []))
	if soils.is_empty():
		return {"ok": false, "error": "No measured soil rectangles supplied"}
	var obstacles: Array[Dictionary] = _obstacles(context, neighbourhood)
	var soil_surfaces: Array[Dictionary] = _soil_surfaces(street)
	var existing: Dictionary = _existing_plants(context_root, neighbourhood)
	var sources: Array[Node3D] = [
		Landscape._prototype(Landscape.TREE_PACK, LOW_SOURCE),
		Landscape._prototype(Landscape.TREE_PACK, LOW_SOURCE),
		Landscape._prototype(Landscape.TREE_PACK, Landscape.SHRUB_NAME),
		Landscape._prototype(Landscape.FERN, "")
	]
	# These are the existing court's texture-preserving local leaf finishes.
	# No texture/source asset is modified, and no luminous or flat grass material
	# is introduced. Both low matrices retain the complete source leaf crown.
	Ground._leaf_finish(sources[0], false)
	Ground._leaf_finish(sources[1], true)
	Ground._leaf_finish(sources[2], false)
	var source_rows: Array[Dictionary] = []
	for index: int in range(sources.size()):
		source_rows.append(_measure_source(sources[index], index))
	var beds: Array[Dictionary] = _designed_beds()
	var candidates: Array[Array] = []
	for bed: Dictionary in beds:
		candidates.append(_bed_candidates(bed))
	var root: Node3D = Node3D.new()
	root.name = "NeighbourhoodGardenContinuity"
	root.set_meta("creator_protected", true)
	root.set_meta("creator_editable", false)
	root.set_meta("source_provenance", "Existing realistic_trees_collection Bush006 crowns/branches and midnight_fern; original source geometry, UVs and textures retained")
	context_root.add_child(root)
	var accepted: Array[Dictionary] = []
	var rejected: Array[Dictionary] = []
	var rejected_counts: Dictionary = {}
	var buckets: Dictionary = {}
	var triangles: int = 0
	var maximum_rounds: int = 0
	for items: Array in candidates:
		maximum_rounds = maxi(maximum_rounds, items.size())
	# Interleave beds so the hard cost cap cannot consume one side's allocation
	# before reaching the other. This is bounded authored sampling, not scatter.
	for round_index: int in range(maximum_rounds):
		for bed_index: int in range(beds.size()):
			if round_index >= candidates[bed_index].size():
				continue
			var spec: Dictionary = candidates[bed_index][round_index]
			var source_index: int = int(spec.source)
			var source: Node3D = sources[source_index]
			var source_info: Dictionary = source_rows[source_index]
			if source == null or not bool(source_info.ok):
				_reject(rejected, rejected_counts, spec, "source_unavailable")
				continue
			var cost: int = int(source_info.triangles)
			if triangles + cost > TRIANGLE_BUDGET:
				_reject(rejected, rejected_counts, spec, "triangle_budget")
				continue
			var position: Vector3 = spec.position
			var record: Dictionary = _placement(source, position, float(spec.height), float(spec.spread), float(spec.yaw))
			var box: AABB = record.bounds
			var crown: Rect2 = Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
			var reason: String = _clearance_reason(crown, soils, obstacles, existing)
			if reason.is_empty():
				for previous: Dictionary in accepted:
					var previous_position: Vector3 = previous.position
					if Vector2(previous_position.x, previous_position.z).distance_to(Vector2(position.x, position.z)) < 0.38:
						reason = "duplicate_root_spacing"
						break
			if not reason.is_empty():
				_reject(rejected, rejected_counts, spec, reason)
				continue
			var support: Dictionary = _support_for(crown, soil_surfaces)
			if not bool(support.ok):
				_reject(rejected, rejected_counts, spec, "non_level_or_missing_soil_support")
				continue
			var soil_y: float = float(support.top_y)
			position.y = soil_y - CONTACT_EMBED
			record = _placement(source, position, float(spec.height), float(spec.spread), float(spec.yaw))
			box = record.bounds
			var transform: Transform3D = record.transform
			var row: Dictionary = {
				"plant_id": accepted.size(),
				"bed": str(spec.bed), "source_index": source_index,
				"kind": str(spec.kind), "position": position, "height_m": float(spec.height),
				"spread_m": float(spec.spread), "yaw": float(spec.yaw),
				"bounds": box, "crown_rect": crown, "triangles": cost,
				"soil_top_y": soil_y, "soil_contact_error_m": box.position.y - soil_y,
				"soil_support": support.names, "ground_transform": transform,
				"full_crown_soil_union_checked": true
			}
			accepted.append(row)
			triangles += cost
			beds[bed_index].accepted = int(beds[bed_index].get("accepted", 0)) + 1
			beds[bed_index].crown_area_sum = float(beds[bed_index].get("crown_area_sum", 0.0)) + crown.get_area()
			var cell: Vector2i = Vector2i(floori(position.x / CELL_SIZE), floori(position.z / CELL_SIZE))
			var key: String = "%d_%d_%d" % [source_index, cell.x, cell.y]
			if not buckets.has(key):
				buckets[key] = {"source_index": source_index, "cell": cell, "rows": []}
			buckets[key].rows.append(row)
	var batch_rows: Array[Dictionary] = _make_batches(root, sources, buckets)
	var by_kind: Dictionary = {}
	var max_contact_error: float = 0.0
	var actual_counts: Array[int] = [0, 0, 0, 0]
	for row: Dictionary in accepted:
		by_kind[row.kind] = int(by_kind.get(row.kind, 0)) + 1
		actual_counts[int(row.source_index)] += 1
		max_contact_error = maxf(max_contact_error, absf(float(row.soil_contact_error_m)))
	for index: int in range(sources.size()):
		source_rows[index]["instances"] = actual_counts[index]
		if sources[index] != null:
			sources[index].free()
	var report: Dictionary = {
		"ok": not accepted.is_empty(), "root": str(root.get_path()),
		"plants": accepted, "plant_count": accepted.size(), "counts_by_kind": by_kind,
		"beds": beds, "sources": source_rows, "batches": batch_rows,
		"batch_count": batch_rows.size(), "instanced_triangle_count": triangles,
		"triangle_budget": TRIANGLE_BUDGET, "rejected": rejected,
		"rejection_counts": rejected_counts, "soil_surfaces": soil_surfaces,
		"obstacles": obstacles, "maximum_soil_contact_error_m": max_contact_error,
		"retained_tree_mulch_centres": existing.trees,
		"minimum_mulch_radius_m": TRUNK_MULCH_RADIUS,
		"route_clearance_m": ROUTE_CLEARANCE, "building_footprint_clearance_m": ROOF_CLEARANCE,
		"new_collisions": 0, "existing_plants_changed": 0, "new_tree_count": 0,
		"source_assets_modified": false, "visibility_end_m": 160.0,
		"visibility_end_margin_m": 12.0,
		"composition": "Joined 0.55-0.85m near-walk and inner-road planted shoulders with overlapping tree-bay colonies; purposeful 1.05-1.30m complete woody shrub groups form the second layer; eastern frontage is continuous through the former artificial gap",
		"geometry_policy": "Complete original crowns, moderate horizontal spread and independently controlled height; original source UVs, textures and cutout remain; no generated grass blades or sheets",
		"coverage_note": "crown_area_sum is overlapping conservative AABB sum, not measured visible foliage coverage",
		"acceptance": "Counts and containment are build evidence only; installed player-height day/night inspection and performance review belong to the integrating owner"
	}
	root.set_meta("garden_continuity", report)
	return report

static func _designed_beds() -> Array[Dictionary]:
	var beds: Array[Dictionary] = []
	for side: float in [-1.0, 1.0]:
		var side_name: String = "west" if side < 0.0 else "east"
		# Front beds take priority over distant north/rear borders. The east plot
		# has no workshop, so it must not inherit the west building's empty gap.
		if side > 0.0:
			beds.append(_bed("east_continuous_walk", Vector2(43.05, 184.9), Vector2(43.05, 224.6), 2.45, 3, 0.96, 0.69, 1.76, 0))
			beds.append(_bed("east_middle_tree_bed", Vector2(47.70, 204.6), Vector2(47.70, 215.6), 2.80, 3, 1.00, 0.72, 1.80, 1))
		else:
			beds.append(_bed("west_walk_north", Vector2(-43.05, 184.9), Vector2(-43.05, 205.5), 2.45, 3, 0.94, 0.69, 1.76, 0))
			beds.append(_bed("west_walk_south", Vector2(-43.05, 216.2), Vector2(-43.05, 224.6), 2.45, 3, 0.91, 0.69, 1.76, 0))
		beds.append(_bed(side_name + "_tree_bay_north", Vector2(side * 47.75, 188.8), Vector2(side * 47.75, 203.1), 2.65, 3, 1.05, 0.72, 1.80, 1))
		beds.append(_bed(side_name + "_tree_bay_south", Vector2(side * 48.10, 217.2), Vector2(side * 48.10, 224.2), 2.80, 3, 1.04, 0.72, 1.80, 1))
		beds.append(_bed(side_name + "_inner_road", Vector2(side * 30.00, 195.4), Vector2(side * 30.00, 219.7), 1.60, 3, 0.90, 0.60, 1.70, 0))
		beds.append(_bed(side_name + "_lane_return", Vector2(side * 30.30, 229.4), Vector2(side * 30.30, 240.0), 2.35, 3, 0.96, 0.62, 1.65, 1))
		# Clusters of complete woody crowns make an actual second planting layer.
		# Groups stay on the outer garden side, away from the corner sightlines.
		var woody_points: Array[Vector2] = [
			Vector2(side * 45.8, 197.3), Vector2(side * 47.0, 197.7), Vector2(side * 48.1, 198.2),
			Vector2(side * 48.4, 202.8), Vector2(side * 49.65, 203.2),
			Vector2(side * 46.5, 217.9), Vector2(side * 47.7, 218.3), Vector2(side * 48.8, 218.2),
			Vector2(side * 47.6, 223.8), Vector2(side * 48.9, 224.0)
		]
		if side > 0.0:
			woody_points.append_array([Vector2(46.8, 207.5), Vector2(48.0, 207.8), Vector2(46.6, 211.4), Vector2(47.8, 211.9), Vector2(49.0, 212.1)])
		beds.append({"id": side_name + "_woody_groups", "source": 2, "kind": "stemmed_shrub", "points": woody_points, "height": 1.17, "spread": 1.45})
		beds.append({"id": side_name + "_fern_group", "source": 3, "kind": "fern_accent", "points": [Vector2(side * 44.8, 218.4), Vector2(side * 45.45, 218.8)], "height": 0.62, "spread": 1.04})
	return beds

static func _bed(id: String, start: Vector2, end: Vector2, width: float, layers: int, spacing: float, height: float, spread: float, source: int) -> Dictionary:
	return {"id": id, "start": start, "end": end, "width": width, "layers": layers, "spacing": spacing, "height": height, "spread": spread, "source": source, "kind": "low_groundcover_drift", "accepted": 0, "crown_area_sum": 0.0}

static func _bed_candidates(bed: Dictionary) -> Array:
	var result: Array = []
	var source: int = int(bed.source)
	if bed.has("points"):
		var points: Array = bed.points
		for index: int in range(points.size()):
			var point: Vector2 = points[index]
			var height: float = float(bed.height) + (0.12 * sin(float(index) * 1.71) if source == 2 else 0.0)
			result.append({"bed": bed.id, "source": source, "kind": bed.kind, "position": Vector3(point.x, 0.0, point.y), "height": height, "spread": float(bed.spread), "yaw": float(index) * 1.71})
		return result
	var start: Vector2 = bed.start
	var end: Vector2 = bed.end
	var direction: Vector2 = (end - start).normalized()
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var length: float = start.distance_to(end)
	var count: int = mini(40, maxi(2, floori(length / float(bed.spacing)) + 1))
	var layers: int = int(bed.layers)
	# Keep neighbouring crowns close enough to merge. Small analytic waves
	# soften each shared bed edge; no independently scattered plants are added.
	for along: int in range(count):
		var progress: float = float(along) / float(count - 1)
		var envelope: float = 0.72 + 0.28 * sin(PI * progress)
		for layer: int in range(layers):
			var across: float = float(layer) / float(maxi(1, layers - 1)) - 0.5
			var phase: float = float(along) * 1.13 + float(layer) * 2.1 + float(source) * 0.57
			var point: Vector2 = start.lerp(end, progress)
			point += perpendicular * (across * float(bed.width) * envelope + 0.13 * sin(phase * 0.71))
			point += direction * (0.18 * sin(phase) + 0.20 * float(layer % 2))
			var height: float = clampf(float(bed.height) + 0.065 * sin(phase * 0.43) + 0.035 * across, 0.50, 0.85)
			var spread: float = float(bed.spread) * (0.92 + 0.08 * sin(PI * progress))
			result.append({"bed": bed.id, "source": source, "kind": bed.kind, "position": Vector3(point.x, 0.0, point.y), "height": height, "spread": spread, "yaw": phase * 0.72})
	# A low discrepancy traversal fills the whole ribbon before increasing
	# density. Thus budget truncation cannot leave the far ends abandoned.
	var ordered: Array = []
	var used: Dictionary = {}
	for iteration: int in range(result.size()):
		var index: int = (iteration * 37) % result.size()
		if used.has(index):
			for fallback: int in range(result.size()):
				if not used.has(fallback):
					index = fallback
					break
		used[index] = true
		ordered.append(result[index])
	return ordered

static func _measure_source(source: Node3D, index: int) -> Dictionary:
	var labels: Array[String] = [LOW_SOURCE + " court green", LOW_SOURCE + " court sage", Landscape.SHRUB_NAME + " complete branches and leaves", Landscape.FERN]
	if source == null:
		return {"ok": false, "index": index, "source": labels[index], "triangles": 0}
	var bounds: AABB = AABB()
	var first: bool = true
	var triangles: int = 0
	var surfaces: int = 0
	var material_names: Array[String] = []
	for child: Node in source.get_children():
		var visual: MeshInstance3D = child as MeshInstance3D
		if visual == null or visual.mesh == null:
			continue
		var referenced: AABB = AABB()
		var first_mesh: bool = true
		for surface: int in range(visual.mesh.get_surface_count()):
			var arrays: Array = MeshArrays.read(visual.mesh,surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			triangles += count / 3
			surfaces += 1
			var material: Material = visual.get_active_material(surface)
			material_names.append(str(material.resource_name) if material != null else "missing")
			for cursor: int in range(count):
				var vertex: Vector3 = vertices[indices[cursor] if not indices.is_empty() else cursor]
				referenced = AABB(vertex, Vector3.ZERO) if first_mesh else referenced.expand(vertex)
				first_mesh = false
				var point: Vector3 = visual.transform * vertex
				bounds = AABB(point, Vector3.ZERO) if first else bounds.expand(point)
				first = false
		visual.set_meta("garden_referenced_bounds", referenced)
	source.set_meta("garden_source_bounds", bounds)
	return {"ok": not first and triangles > 0, "index": index, "source": labels[index], "triangles": triangles, "mesh_children": source.get_child_count(), "surface_count": surfaces, "bounds": bounds, "material_names": material_names}

static func _placement(source: Node3D, position: Vector3, height: float, spread: float, yaw: float) -> Dictionary:
	var raw: AABB = source.get_meta("garden_source_bounds")
	var horizontal: float = spread / maxf(maxf(raw.size.x, raw.size.z), 0.001)
	var vertical: float = height / maxf(raw.size.y, 0.001)
	var pivot: Vector3 = Vector3(raw.get_center().x, raw.position.y, raw.get_center().z)
	var basis: Basis = Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(horizontal, vertical, horizontal))
	var transform: Transform3D = Transform3D(basis, position - basis * pivot)
	var bounds: AABB = AABB()
	var first: bool = true
	for child: Node in source.get_children():
		var visual: MeshInstance3D = child as MeshInstance3D
		if visual == null or not visual.has_meta("garden_referenced_bounds"):
			continue
		var referenced: AABB = visual.get_meta("garden_referenced_bounds")
		var box: AABB = transform * visual.transform * referenced
		bounds = box if first else bounds.merge(box)
		first = false
	return {"transform": transform, "bounds": bounds}

static func _obstacles(context: Dictionary, neighbourhood: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in ["paved_rectangles", "road_rectangles", "garden_edge_rectangles"]:
		for rect: Rect2 in context.get(key, []):
			result.append({"rect": rect.grow(ROUTE_CLEARANCE), "reason": "context_" + key})
	for key: String in ["paving_rectangles", "clear_routes", "drain_holes"]:
		for rect: Rect2 in neighbourhood.get(key, []):
			result.append({"rect": rect.grow(ROUTE_CLEARANCE), "reason": "neighbourhood_" + key})
	for report: Dictionary in [context, neighbourhood]:
		for rect: Rect2 in report.get("building_footprints", []):
			# Roof/gutter projection is <= 0.40m beyond these shell footprints;
			# retain another 0.20m of visible dry edge around every full crown.
			result.append({"rect": rect.grow(ROOF_CLEARANCE), "reason": "building_and_roof_clearance"})
	# Context soil extends beneath the original cross-street mesh. Its paving
	# and asphalt remain an explicit exclusion rather than trusting new soil.
	result.append({"rect": Rect2(-32.5, 180.0, 65.0, 14.0).grow(ROUTE_CLEARANCE), "reason": "retained_cross_street_road_and_paving"})
	for side: float in [-1.0, 1.0]:
		result.append({"rect": Rect2(side * 51.85 - 0.19, 174.0, 0.38, 68.0), "reason": "outer_parcel_coping"})
		result.append({"rect": Rect2(side * 27.35 - 0.24, 228.0, 0.48, 14.0), "reason": "retained_garden_boundary"})
	return result

static func _existing_plants(context_root: Node3D, neighbourhood: Dictionary) -> Dictionary:
	var trees: Array[Vector2] = []
	var roots: Array[Vector2] = []
	var retained: Node = context_root.get_node_or_null("ContextGardenPlanting")
	var planting: Dictionary = retained.get_meta("context_planting", {}) if retained != null else {}
	for row: Dictionary in planting.get("plants", []):
		var point: Vector3 = row.root
		roots.append(Vector2(point.x, point.z))
		if str(row.kind) == "oak":
			trees.append(Vector2(point.x, point.z))
	for row: Dictionary in neighbourhood.get("plants", []):
		var point: Vector3 = row.position
		roots.append(Vector2(point.x, point.z))
		if str(row.kind) == "tree":
			trees.append(Vector2(point.x, point.z))
	return {"trees": trees, "roots": roots}

static func _clearance_reason(crown: Rect2, soils: Array[Rect2], obstacles: Array[Dictionary], existing: Dictionary) -> String:
	for obstacle: Dictionary in obstacles:
		var blocked: Rect2 = obstacle.rect
		if blocked.intersects(crown):
			return str(obstacle.reason)
	# Subtract every soil piece from the full crown rectangle. Checking corners
	# alone misses narrow holes and L-shaped concavities inside a crown.
	if not Ground._difference_rects(crown, soils).is_empty():
		return "full_crown_outside_soil_union"
	for tree: Vector2 in existing.trees:
		var nearest: Vector2 = tree.clamp(crown.position, crown.end)
		if nearest.distance_to(tree) < TRUNK_MULCH_RADIUS:
			return "retained_tree_mulch_circle"
	for point: Vector2 in existing.roots:
		if crown.get_center().distance_to(point) < 0.28:
			return "retained_plant_root_spacing"
	return ""

static func _soil_surfaces(street: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pending: Array[Node] = [street]
	var street_inverse: Transform3D = street.global_transform.affine_inverse()
	while not pending.is_empty():
		var node: Node = pending.pop_back() as Node
		pending.append_array(node.get_children())
		var visual: MeshInstance3D = node as MeshInstance3D
		if visual == null or visual.mesh == null:
			continue
		var bounds: AABB = street_inverse * visual.global_transform * visual.get_aabb()
		# Godot gives duplicate sibling meshes generated @MeshInstance names.
		# Material identity and flat low slab bounds find BOTH original plot
		# soils; relying on CourtyardPlotBase's name only found the west slab.
		if bounds.end.y > 0.10 or bounds.end.y < -0.025 or bounds.size.y > 0.10 or bounds.size.x <= 0.001 or bounds.size.z <= 0.001:
			continue
		var soil_material: bool = false
		for surface: int in range(visual.mesh.get_surface_count()):
			var material: StandardMaterial3D = visual.get_active_material(surface) as StandardMaterial3D
			if material == null:
				continue
			if str(material.resource_name) == "SouthStreet_land_soil":
				soil_material = true
			elif material.albedo_texture != null and material.albedo_texture.resource_path.contains("forrest_ground_01_diff"):
				soil_material = true
		if not soil_material:
			continue
		result.append({"name": str(visual.get_path()), "rect": Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z), "top_y": bounds.end.y})
	return result

static func _support_for(crown: Rect2, surfaces: Array[Dictionary]) -> Dictionary:
	var highest: float = -INF
	for surface: Dictionary in surfaces:
		var rect: Rect2 = surface.rect
		if rect.intersects(crown):
			highest = maxf(highest, float(surface.top_y))
	if highest == -INF:
		return {"ok": false}
	var level_rects: Array[Rect2] = []
	var names: Array[String] = []
	for surface: Dictionary in surfaces:
		var rect: Rect2 = surface.rect
		if absf(float(surface.top_y) - highest) < 0.001 and rect.intersects(crown):
			level_rects.append(rect)
			names.append(str(surface.name))
	return {"ok": Ground._difference_rects(crown, level_rects).is_empty(), "top_y": highest, "names": names}

static func _reject(rows: Array[Dictionary], counts: Dictionary, spec: Dictionary, reason: String) -> void:
	counts[reason] = int(counts.get(reason, 0)) + 1
	rows.append({"bed": str(spec.bed), "position": spec.position, "kind": str(spec.kind), "reason": reason})

static func _make_batches(parent: Node3D, sources: Array[Node3D], buckets: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in buckets:
		var bucket: Dictionary = buckets[key]
		var source_index: int = int(bucket.source_index)
		var source: Node3D = sources[source_index]
		var cell: Vector2i = bucket.cell
		var cell_origin: Vector3 = Vector3((float(cell.x) + 0.5) * CELL_SIZE, 0.0, (float(cell.y) + 0.5) * CELL_SIZE)
		var rows: Array = bucket.rows
		for child: Node in source.get_children():
			var visual: MeshInstance3D = child as MeshInstance3D
			if visual == null or visual.mesh == null:
				continue
			# One baked copy (mesh + the part's active materials) shared by every
			# bucket of this part, instead of a GPU copy per bucket.
			var render_mesh: ArrayMesh = BakeCache.baked_from(visual) as ArrayMesh
			var multimesh: MultiMesh = MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = render_mesh
			multimesh.instance_count = rows.size()
			var custom_bounds: AABB = AABB()
			var first: bool = true
			var plant_ids: Array[int] = []
			for index: int in range(rows.size()):
				var row: Dictionary = rows[index]
				var placement: Transform3D = row.ground_transform
				var local: Transform3D = Transform3D(Basis.IDENTITY, -cell_origin) * placement * visual.transform
				multimesh.set_instance_transform(index, local)
				plant_ids.append(int(row.plant_id))
				var referenced: AABB = visual.get_meta("garden_referenced_bounds")
				var box: AABB = local * referenced
				custom_bounds = box if first else custom_bounds.merge(box)
				first = false
			multimesh.custom_aabb = custom_bounds.grow(0.05)
			var batch: MultiMeshInstance3D = MultiMeshInstance3D.new()
			batch.name = "GardenContinuity_%03d" % result.size()
			batch.position = cell_origin
			batch.multimesh = multimesh
			BakeCache.tag(batch, BakeCache.group_key())
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			batch.visibility_range_end = 160.0
			batch.visibility_range_end_margin = 12.0
			batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			# (No "authored_instance_transforms" meta: nothing read it, and it kept a
			# second copy of every instance transform alive; the MultiMesh has them.)
			batch.set_meta("garden_continuity_plant_ids", plant_ids)
			batch.set_meta("garden_continuity_source_index", source_index)
			batch.set_meta("creator_protected", true)
			parent.add_child(batch)
			result.append({"path": str(batch.get_path()), "source_index": source_index, "source_mesh": str(visual.name), "cell": cell, "instances": rows.size(), "plant_ids": plant_ids, "local_bounds": custom_bounds, "street_bounds": AABB(custom_bounds.position + cell_origin, custom_bounds.size), "surface_count": render_mesh.get_surface_count()})
	return result
