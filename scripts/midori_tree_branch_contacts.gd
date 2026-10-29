extends RefCounted
# STAGED ONLY. Eight measured broadleaf proposals; visually approve after grass.
# Leaf samples and projected branch hulls are separate; no exact contact claim.
const SOURCE_ASSET := "res://assets/shinrai/parks/midori_park/models/vegetation/vendor/realistic_trees_collection/scene.glb"
const SOURCE_SHA256 := "9a5e73b75c7a9c17da4f51f8a347d37466d626ab4ed6973bfce18771e62d0b85"
const MOVES: Array[Dictionary] = [
	{"name": "ReferenceBroadleaf_000", "before": Vector3(-174.62522888, -0.03500000, -170.00000000), "after": Vector3(-173.81967062, -0.03500000, -170.15376627)},
	{"name": "ReferenceBroadleaf_21408", "before": Vector3(-23.56474495, -0.03500000, -69.14664459), "after": Vector3(-23.99996046, -0.03500000, -69.95767820)},
	{"name": "ReferenceBroadleaf_2101", "before": Vector3(-108.21186066, -0.03500000, -114.18365479), "after": Vector3(-109.21339982, -0.03500000, -114.49279427)},
	{"name": "ReferenceBroadleaf_2802", "before": Vector3(178.00465393, -0.03500000, 63.51347351), "after": Vector3(178.40209697, -0.03500000, 62.37935697)},
	{"name": "ReferenceBroadleaf_20104", "before": Vector3(-126.98643494, -0.03500000, -36.41835403), "after": Vector3(-128.09291811, -0.03500000, -37.02687343)},
	{"name": "ReferenceBroadleaf_21237", "before": Vector3(-28.32608223, -0.03500000, 43.67628479), "after": Vector3(-27.01511859, -0.03500000, 43.10991020)},
	{"name": "ReferenceBroadleaf_2609", "before": Vector3(-13.17849731, -0.03500000, 111.18360901), "after": Vector3(-13.51926240, -0.03500000, 109.80005500)},
	{"name": "ReferenceBroadleaf_21113", "before": Vector3(-77.48593140, -0.03500000, -27.29854774), "after": Vector3(-78.42872024, -0.03500000, -28.41376500)},
]

static func apply(park: Node3D) -> void:
	if FileAccess.get_sha256(SOURCE_ASSET) != SOURCE_SHA256:
		push_warning("TREE_BRANCH_CONTACT: source model changed; proposal skipped")
		return
	var applied := 0
	for spec: Dictionary in MOVES:
		var tree := park.find_child(spec.name, true, false) as Node3D
		if tree == null or tree.global_position.distance_to(spec.before) > 0.025:
			push_warning("TREE_BRANCH_CONTACT: baseline placement changed: " + str(spec.name))
			continue
		var old_point := Vector2(tree.position.x, tree.position.z)
		var next_position: Vector3 = tree.get_parent().to_local(spec.after)
		var next_point := Vector2(next_position.x, next_position.z)
		var clear: bool = park._is_vegetation_clear(next_position, 3.2)
		for cover_point: Vector2 in park.TREE_COVER_CLEARINGS:
			if next_point.distance_to(cover_point) < 4.05:
				clear = false
		var old_index := -1
		for i: int in range(park.occupied_tree_positions.size()):
			var point: Vector2 = park.occupied_tree_positions[i]
			if point.distance_to(old_point) < 0.001:
				old_index = i
			elif point.distance_to(next_point) < park.MATURE_TREE_MIN_SPACING_M:
				clear = false
		if not clear or old_index < 0:
			push_warning("TREE_BRANCH_CONTACT: reserved clearance prevented " + str(spec.name))
			continue
		tree.global_position = spec.after
		park.occupied_tree_positions[old_index] = next_point
		if park._occupied_tree_crowns.has(old_point):
			var radius: float = park._occupied_tree_crowns[old_point]
			park._occupied_tree_crowns.erase(old_point)
			park._occupied_tree_crowns[next_point] = radius
		applied += 1
	park.set_meta("tree_branch_contact_applied", applied)
	print("TREE_BRANCH_CONTACT applied=", applied, " expected=", MOVES.size())
