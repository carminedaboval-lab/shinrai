extends RefCounted
## Places one accepted, measured GLB. Missing/rejected art never produces a proxy.
## All positions below are world metres, independent of the park's scaled layout.

const STREET_LIGHT_LAYER := 1 << 10
const CENTRE := Vector2(-35.2, 182.8)
const ASPHALT_Y := 0.02
const MAIN_ROAD_SOUTH := 190.0
const WEST_WALK_EAST := -38.5
const INNER_CURB_WEST := -32.5
const SUPPORT_CELL := .28
const MAX_SOURCE_VERTICES := 1600000

static func build(park: Node3D, street: Node3D, asset_path: String, source_forward_positive_z: bool = true) -> Dictionary:
	var report: Dictionary = {
		"ok": false, "sourcepath": asset_path, "rejections": [],
		"coordinates": "world_metres", "new_lights": 0, "per_frame_scripts": 0,
		"source_materials_modified": false, "source_scale_modified": false,
		"collisionpointcount": 0, "support_gap_m": 0.0,
		"navigation_verified": false
	}
	if not is_instance_valid(park) or not is_instance_valid(street) or not park.is_inside_tree():
		return _reject(report, "An installed park and street are required")
	if park.get_node_or_null("OverturnedDeliveryVan") != null:
		return _reject(report, "OverturnedDeliveryVan already exists; refusing a duplicate")
	if not asset_path.begins_with("res://") or not ResourceLoader.exists(asset_path):
		return _reject(report, "Accepted van asset is missing: " + asset_path)
	var packed := load(asset_path) as PackedScene
	if packed == null:
		return _reject(report, "Van asset must be an imported PackedScene")
	var instance := packed.instantiate()
	var asset := instance as Node3D
	if asset == null:
		instance.free()
		return _reject(report, "Van scene has no Node3D root")
	var points := PackedVector3Array()
	var audit: Dictionary = {"mesh_count": 0, "triangles": 0, "unsafe_nodes": [], "invalid_vertices": 0}
	_collect(asset, Transform3D.IDENTITY, points, audit)
	report["source_meshes"] = audit.mesh_count
	report["source_triangles"] = audit.triangles
	report["source_vertices"] = points.size()
	if not audit.unsafe_nodes.is_empty() or int(audit.invalid_vertices) != 0:
		asset.free()
		return _reject(report, "Asset contains scripts, lights, cameras, collision or invalid geometry: " + str(audit.unsafe_nodes))
	if points.size() < 24 or points.size() > MAX_SOURCE_VERTICES:
		asset.free()
		return _reject(report, "Van geometry is empty or exceeds the bounded inspection budget")
	var upright := _bounds(points)
	report["upright_bounds"] = upright
	# Delivery assets arrive in real metres: X width, Y height, Z length, Y=0 floor.
	# Correcting an unsuitable source by stretching it here would hide an art defect.
	var size := upright.size
	if size.x < 1.65 or size.x > 2.10 or size.y < 1.85 or size.y > 2.30 or size.z < 4.40 or size.z > 4.85:
		asset.free()
		return _reject(report, "Expected upright metre-scale delivery van, approximately 1.85 x 2.05 x 4.60 m; received " + str(size))
	if absf(upright.position.y) > 0.06 or absf(upright.get_center().x) > 0.15 or absf(upright.get_center().z) > 0.20:
		asset.free()
		return _reject(report, "Van source must be centred in X/Z with an upright floor origin")
	var yaw := -PI * .75 if source_forward_positive_z else PI * .25
	var roll := PI * .5 if source_forward_positive_z else -PI * .5
	var orientation := Basis(Vector3.UP,yaw) * Basis(Vector3.BACK,roll)
	var rolled := PackedVector3Array()
	rolled.resize(points.size())
	for index: int in range(points.size()): rolled[index] = orientation * points[index]
	var rolled_bounds := _bounds(rolled)
	var origin := Vector3(CENTRE.x-rolled_bounds.get_center().x,0,CENTRE.y-rolled_bounds.get_center().z)
	var footprint := AABB(rolled_bounds.position+origin,rolled_bounds.size)
	# The actual western T-junction's north shoulder: front on soil, rear on road.
	# The old raised north curb starts at X=-32.5; the complete vehicle stays west.
	var main_road_clear := MAIN_ROAD_SOUTH-footprint.end.z
	var west_walk_gap := footprint.position.x-WEST_WALK_EAST
	var inner_curb_gap := INNER_CURB_WEST-footprint.end.x
	if main_road_clear<4.5 or west_walk_gap<.70 or inner_curb_gap<.20 or footprint.position.z<180.20:
		asset.free()
		return _reject(report,"Crash envelope violates the existing T-junction route reservations")
	await park.get_tree().physics_frame
	var support: Dictionary = _ground_support(park,rolled,origin)
	if not support.get("ok",false):
		asset.free()
		return _reject(report,str(support.get("reason","Crash shoulder has no safe physical support")))
	origin.y = float(support.translation_y)
	var world_bounds := AABB(rolled_bounds.position+origin,rolled_bounds.size)
	var hull_points: PackedVector3Array = await _extrema_cloud(rolled, park.get_tree())
	if hull_points.size() < 8:
		asset.free()
		return _reject(report, "Unable to build a fitted non-degenerate collision hull")
	var root := Node3D.new()
	root.name = "OverturnedDeliveryVan"
	root.set_meta("creator_protected", true)
	root.set_meta("creator_editable", false)
	root.set_meta("creator_object_kind", "aftermath_vehicle")
	park.add_child(root)
	root.set_as_top_level(true)
	root.global_transform = Transform3D(Basis.IDENTITY, origin)
	var visual := Node3D.new()
	visual.name = "RolledVanVisual"
	visual.transform = Transform3D(orientation, Vector3.ZERO)
	root.add_child(visual)
	visual.add_child(asset)
	_assign_exterior_layers(asset)
	var body := StaticBody3D.new()
	body.name = "FittedVanCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var shape := ConvexPolygonShape3D.new()
	shape.points = hull_points
	shape.margin = 0.015
	var collision := CollisionShape3D.new()
	collision.name = "MeasuredBodyHull"
	collision.shape = shape
	body.add_child(collision)
	# Scene readiness must not precede the new obstruction's physics registration.
	await park.get_tree().physics_frame
	await park.get_tree().physics_frame
	report["ok"] = true
	report["node"] = str(root.get_path())
	report["collision_node"] = str(body.get_path())
	report["world_bounds"] = world_bounds
	var nose := (orientation*(Vector3.BACK if source_forward_positive_z else Vector3.FORWARD)).normalized()
	var rear := -nose
	var roof := (orientation*Vector3.UP).normalized()
	var centre := world_bounds.get_center()
	var front_point := centre+nose*size.z*.5
	var rear_point := centre+rear*size.z*.5
	report["front_point"] = front_point
	report["nose_direction"] = nose
	report["rear_point"] = rear_point
	report["rear_direction"] = rear
	report["roof_direction"] = roof
	report["underside_direction"] = -roof
	report["rear_approach_point"] = rear_point+rear*1.0
	report["collisionpointcount"] = hull_points.size()
	report["collision_margin_m"] = shape.margin
	report["collision_kind"] = "convex hull of actual transformed directional extrema"
	report["support_gap_m"] = support.minimum_gap_m
	report["support_samples"] = support.samples
	report["support_contact_count"] = support.contact_count
	report["support_contact_band_max_gap_m"] = support.contact_band_max_gap_m
	report["floor_ray_y"] = float(support.highest_ground_y)
	report["clear_road_m"] = main_road_clear
	report["clearroad"] = main_road_clear
	report["west_walk_gap_m"] = west_walk_gap
	report["inner_curb_gap_m"] = inner_curb_gap
	report["curb_margin_m"] = inner_curb_gap
	report["crossing_margin_m"] = -2.0-world_bounds.end.x
	report["crossingmargin"] = -2.0-world_bounds.end.x
	report["junction"] = {"centre":Vector3(-35.5,.02,186.5),"site":"north shoulder of existing western T-junction","nose_surface":"existing supported soil","rear_surface":"existing connected asphalt"}
	report["route_reservations"] = {"west_walk":Rect2(-40.5,182,2,46),"main_road_clear_corridor":Rect2(-38.5,186.0,11.0,4.0),"inner_curb_starts_x":-32.5}
	report["navigation_verified"] = false
	report["navigation_domain_note"] = "Western T-junction is outside fixed scav town graph X[-31,32]; local physical route probes required; navigation code unchanged"
	report["orientation"] = {"nose":"world_north_west","roof":"world_north_east","source_forward_positive_z":source_forward_positive_z,"contact_side":"source_minus_x" if source_forward_positive_z else "source_plus_x","yaw_radians":yaw,"roll_radians":roll,"pitch_radians":0.0}
	root.set_meta("overturned_van_report", report)
	return report

static func _ground_support(park: Node3D,rolled: PackedVector3Array,origin: Vector3) -> Dictionary:
	# One actual lowest mesh vertex per small footprint cell. Unlike an AABB
	# corner test this does not invent body contact in the van's empty wheel wells.
	var cells: Dictionary = {}
	var global_low := INF
	for point: Vector3 in rolled:
		global_low = minf(global_low,point.y)
		var key := Vector2i(floori(point.x/SUPPORT_CELL),floori(point.z/SUPPORT_CELL))
		if not cells.has(key) or point.y<(cells[key] as Vector3).y: cells[key]=point
	var samples: Array[Dictionary] = []
	var translation_y := -INF
	var highest_ground := -INF
	for point: Vector3 in cells.values():
		var sample := point+origin
		var query := PhysicsRayQueryParameters3D.create(Vector3(sample.x,1.5,sample.z),Vector3(sample.x,-.60,sample.z),1)
		var hit: Dictionary = park.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():return {"ok":false,"reason":"Crash support ray missed at "+str(sample)}
		if hit.normal.y<.90 or hit.position.y<-.06 or hit.position.y>.17:
			return {"ok":false,"reason":"Crash footprint meets an existing obstacle instead of soil/road: "+str(hit.collider.get_path())}
		translation_y = maxf(translation_y,float(hit.position.y)-point.y)
		highest_ground = maxf(highest_ground,float(hit.position.y))
		samples.append({"local_vertex":point,"ground_position":hit.position,"ground_normal":hit.normal,"collider":str(hit.collider.get_path()),"contact_band":point.y<=global_low+.045})
	var minimum_gap := INF
	var contact_band_max_gap := 0.0
	var contacts := 0
	for row: Dictionary in samples:
		var world_vertex: Vector3=row.local_vertex+Vector3(origin.x,translation_y,origin.z)
		var gap: float=world_vertex.y-(row.ground_position as Vector3).y
		row["world_vertex"]=world_vertex;row["gap_m"]=gap
		minimum_gap=minf(minimum_gap,gap)
		if gap<=.012:contacts+=1
		if row.contact_band:contact_band_max_gap=maxf(contact_band_max_gap,gap)
	if contacts<1 or minimum_gap<-.002 or contact_band_max_gap>.10:
		return {"ok":false,"reason":"Actual crash contact cannot be supported cleanly across soil and road"}
	return {"ok":true,"translation_y":translation_y,"minimum_gap_m":minimum_gap,"contact_band_max_gap_m":contact_band_max_gap,"contact_count":contacts,"samples":samples,"highest_ground_y":highest_ground}

static func _reject(report: Dictionary, reason: String) -> Dictionary:
	report.rejections.append(reason)
	return report

static func _collect(node: Node, parent_transform: Transform3D, points: PackedVector3Array, audit: Dictionary) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform = parent_transform * (node as Node3D).transform
	if node.get_script() != null or node is CollisionObject3D or node is Light3D or node is Camera3D:
		audit.unsafe_nodes.append(str(node.name))
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		if visual.mesh != null:
			audit.mesh_count += 1
			for surface: int in range(visual.mesh.get_surface_count()):
				var arrays: Array = visual.mesh.surface_get_arrays(surface)
				if arrays.is_empty() or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
					continue
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
				if visual.mesh.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES:
					audit.triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
				for vertex: Vector3 in vertices:
					var point := transform * vertex
					if not point.is_finite():
						audit.invalid_vertices += 1
					elif points.size() <= MAX_SOURCE_VERTICES:
						points.append(point)
	for child: Node in node.get_children():
		_collect(child, transform, points, audit)

static func _bounds(points: PackedVector3Array) -> AABB:
	var result := AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points:
		result = result.expand(point)
	return result

static func _extrema_cloud(points: PackedVector3Array, tree: SceneTree) -> PackedVector3Array:
	# Bounded 98-direction hull input, retaining real vertices, including every
	# axial extreme. Added 2:1 slopes retain the rounded roof and body shoulders.
	var cloud := PackedVector3Array()
	var seen: Dictionary = {}
	var directions: Array[Vector3] = []
	for x: int in range(-2, 3):
		for y: int in range(-2, 3):
			for z: int in range(-2, 3):
				if maxi(absi(x), maxi(absi(y), absi(z))) == 2:
					directions.append(Vector3(x, y, z).normalized())
	for index: int in range(directions.size()):
		var direction: Vector3 = directions[index]
		var maximum := -INF
		var extreme := Vector3.ZERO
		for point: Vector3 in points:
			var distance := direction.dot(point)
			if distance > maximum:
				maximum = distance
				extreme = point
		var key := Vector3i(roundi(extreme.x * 10000.0), roundi(extreme.y * 10000.0), roundi(extreme.z * 10000.0))
		if not seen.has(key):
			seen[key] = true
			cloud.append(extreme)
		if index % 8 == 7:
			await tree.process_frame
	return cloud

static func _assign_exterior_layers(node: Node) -> void:
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		var glazed := false
		if visual.mesh != null:
			for surface: int in range(visual.mesh.get_surface_count()):
				var material := visual.get_active_material(surface)
				if material == null:
					continue
				var label := material.resource_name.to_lower()
				if "glass" in label or "glaz" in label or "window" in label:
					glazed = true
				if material is BaseMaterial3D and (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					glazed = true
		if glazed:
			visual.layers &= ~STREET_LIGHT_LAYER
		else:
			visual.layers |= STREET_LIGHT_LAYER
	for child: Node in node.get_children():
		_assign_exterior_layers(child)
