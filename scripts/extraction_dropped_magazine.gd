extends RefCounted
const Supply = preload("res://scripts/extraction_weapon_supplies.gd")
## A physical, recoverable raid drop. The caller retains ownership until true.
## Uses the fitted viewmodel magazine geometry; unsupported or unavailable
## geometry/ground returns false rather than consuming the item.

static func drop(raid: Node, item: Dictionary) -> bool:
	var uid := str(item.get("magazine_uid", ""))
	if uid.is_empty() or not item.has("rounds"):
		return false
	var player := raid.get("player") as Node3D
	var park := raid.get("park") as Node3D
	var sites: Variant = raid.get("sites")
	if not is_instance_valid(player) or not player.is_inside_tree() or not is_instance_valid(park) or not park.is_inside_tree() or not sites is Array:
		return false
	var weapon_id := str(player.get("weapon_id"))
	if weapon_id.is_empty() or str(Supply.MAGAZINES.get(str(item.get("id", "")), "")) != weapon_id:
		return false
	for site: Variant in sites:
		if site is Dictionary and not bool(site.get("done", false)) and str(site.get("loot", {}).get("magazine_uid", "")) == uid:
			return false
	var viewmodel: Variant = player.get("uzi_viewmodel")
	if not is_instance_valid(viewmodel):
		return false
	var property_name := "_uzi_magazine_exchange" if weapon_id == "uzi" else "magazine_exchange"
	var has_exchange := false
	for property: Dictionary in viewmodel.get_property_list():
		if str(property.get("name", "")) == property_name:
			has_exchange = true
			break
	if not has_exchange:
		return false
	if weapon_id != "uzi" and str(viewmodel.get("weapon_key")) != weapon_id:
		return false
	var exchange: Variant = viewmodel.get(property_name)
	if exchange == null:
		return false
	var source: Variant = exchange.get("current")
	if not is_instance_valid(source) or not source is Node3D:
		return false
	var visual := source.duplicate() as Node3D
	if visual == null:
		return false
	# Bake while source meshes still have their registered live skeleton. Godot's
	# bake omits materials, so transfer each active surface material explicitly.
	if not _bake_skinned(source, visual):
		visual.free()
		return false
	visual.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5).scaled(source.global_basis.get_scale()), Vector3.ZERO)
	visual.show()
	var bounds := {"valid": false, "unsupported": false, "min": Vector3.ZERO, "max": Vector3.ZERO}
	_measure(visual, Transform3D.IDENTITY, bounds)
	if bool(bounds.unsupported) or not bool(bounds.valid):
		visual.free()
		return false
	var size: Vector3 = bounds.max - bounds.min
	if size.x <= 0.001 or size.y <= 0.001 or size.z <= 0.001 or size.length() > 1.5:
		visual.free()
		return false
	var camera: Variant = player.get("camera")
	if not is_instance_valid(camera) or not camera is Camera3D:
		visual.free()
		return false
	var point := _ground_point(player, camera, size)
	if point.is_empty():
		visual.free()
		return false
	var root := Node3D.new()
	root.name = "DroppedMagazine_%d" % root.get_instance_id()
	root.add_child(visual)
	# A baked skinned mesh can have vertices far from its node's origin. Center
	# its measured horizontal bounds on the pickup, and ground its lowest point.
	var centre: Vector3 = (bounds.min + bounds.max) * 0.5
	visual.position = Vector3(-centre.x, -float(bounds.min.y) + 0.008, -centre.z)
	var body := StaticBody3D.new()
	body.collision_layer = 2 # Do not obstruct world/visibility rays on layer 1.
	body.collision_mask = 0
	root.add_child(body)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = centre + visual.position
	body.add_child(shape_node)
	park.add_child(root)
	root.global_position = point.position
	var entry := item.duplicate(true)
	var site_id := "dropped_magazine_%d" % root.get_instance_id()
	sites.append({"id": site_id, "title": "Recover " + str(entry.get("title", "magazine")),
		"kind": "cache", "position": point.position + Vector3.UP * (size.y * 0.5 + 0.008),
		"done": false, "spawned": true, "discovered": true, "pickup_node": root,
		"ammo_bonus": 0, "loot": entry, "fixed_loot": entry.duplicate(true),
		"raid_drop": true, "requires_drop_los": true})
	return true

static func _bake_skinned(original: Node3D, clone: Node3D) -> bool:
	if original is MeshInstance3D:
		var source_mesh := original as MeshInstance3D
		var cloned_mesh := clone as MeshInstance3D
		if source_mesh.skin != null:
			if source_mesh.mesh == null or source_mesh.get_skin_reference() == null:
				return false
			var baked := source_mesh.bake_mesh_from_current_skeleton_pose()
			if baked == null or baked.get_surface_count() != source_mesh.mesh.get_surface_count() or baked.get_surface_count() == 0:
				return false
			for surface in range(baked.get_surface_count()):
				baked.surface_set_material(surface, source_mesh.get_active_material(surface))
			cloned_mesh.mesh = baked
			cloned_mesh.skin = null
			cloned_mesh.skeleton = NodePath("")
	var originals := original.get_children()
	var clones := clone.get_children()
	if originals.size() != clones.size():
		return false
	for index in range(originals.size()):
		if originals[index] is Node3D:
			if not clones[index] is Node3D or not _bake_skinned(originals[index], clones[index]):
				return false
	return true

static func _measure(node: Node3D, parent_transform: Transform3D, result: Dictionary) -> void:
	var transform := parent_transform * node.transform
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.skin != null:
			result.unsupported = true
			return
		if mesh_node.mesh != null:
			mesh_node.layers = 1
			var box := mesh_node.mesh.get_aabb()
			for x in [0.0, 1.0]:
				for y in [0.0, 1.0]:
					for z in [0.0, 1.0]:
						var p := transform * (box.position + box.size * Vector3(x, y, z))
						if not result.valid:
							result.min = p
							result.max = p
							result.valid = true
						else:
							result.min = result.min.min(p)
							result.max = result.max.max(p)
	for child: Node in node.get_children():
		if child is Node3D:
			_measure(child, transform, result)

static func _ground_point(player: Node3D, camera: Camera3D, size: Vector3) -> Dictionary:
	var world := player.get_world_3d()
	if world == null or not player is CollisionObject3D:
		return {}
	var exclude: Array[RID] = [(player as CollisionObject3D).get_rid()]
	var forward := -camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = -player.global_basis.z
		forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return {}
	forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	for offset: Vector3 in [forward * 0.65, right * 0.65, -right * 0.65, -forward * 0.65]:
		var anchor := player.global_position + offset
		var down := PhysicsRayQueryParameters3D.create(anchor + Vector3.UP * 1.0, anchor - Vector3.UP * 2.0, 1, exclude)
		var hit := world.direct_space_state.intersect_ray(down)
		if hit.is_empty() or (hit.normal as Vector3).dot(Vector3.UP) < 0.7:
			continue
		var target: Vector3 = hit.position + Vector3.UP * (size.y * 0.5 + 0.008)
		var sight := PhysicsRayQueryParameters3D.create(camera.global_position, target, 1, exclude)
		if world.direct_space_state.intersect_ray(sight).is_empty():
			return {"position": hit.position}
	return {}
