extends RefCounted
## Called by boot integration after PlacementHelper.build_candidate(park, models).
const SITE_ID := "pitch_east_yellow_backpack"

static func register_layout(raid: Node, layout: Dictionary) -> bool:
	if not bool(layout.get("ok", false)):
		return false
	var root := layout.get("root") as Node3D
	var model := layout.get("yellow_model") as Node3D
	var valid := is_instance_valid(root) and is_instance_valid(model)
	valid = valid and root.is_inside_tree() and model.is_inside_tree() and root.is_ancestor_of(model)
	valid = valid and str(layout.get("site_id", "")) == SITE_ID
	valid = valid and is_instance_valid(raid) and raid.has_method("register_loot_container_pickup")
	if valid:
		# Replaying an accepted result must preserve its already registered cluster.
		# Consult the actual site rather than trusting a marker on the result dictionary.
		for site: Dictionary in raid.sites:
			if str(site.get("id", "")) == SITE_ID and site.get("pickup_node") == model:
				return true
	if valid and raid.register_loot_container_pickup(SITE_ID, model):
		return true
	if is_instance_valid(root) and is_instance_valid(raid) and raid.has_method("register_loot_container_pickup"):
		for site: Dictionary in raid.sites:
			var registered := site.get("pickup_node") as Node3D
			if is_instance_valid(registered) and (registered == root or root.is_ancestor_of(registered)):
				return false # Invalid replay must not dispose any registered container.
	# A successfully built cluster belongs to this attempted installation.
	# Failed registration must not leave unlootable/duplicate dressing in the park.
	if is_instance_valid(root):
		if root.get_parent() != null: root.get_parent().remove_child(root)
		root.queue_free()
	return false
