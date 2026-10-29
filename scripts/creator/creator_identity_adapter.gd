extends "res://scripts/midori_2050_identity.gd"
## Keep each existing bench and complete planter independently editable.
## Installation/source-revision owner must check this compatibility hash before
## replacing Midori2050Identity's script, before it enters the scene tree.

const COMPATIBILITY_SOURCE_SHA256 := "5897e7dbeb8f49e668d97241a8a548916f6e1f617b3456f4a538bead7a703d5a"

func _bench(group: Node3D, pos: Vector3, label: String) -> void:
	# Exact source constructor, with the warm strip owned by its bench instead
	# of disappearing into the rest garden's shared Finish_warm geometry.
	var anchor := Node3D.new()
	anchor.name = label
	anchor.position = pos
	group.add_child(anchor)
	_mark_editable(anchor, "Midori Timber Bench", "bench")
	_asset(anchor, "midori_2050_timber_bench.glb", Vector3.ZERO, "MeshyTimberBench")
	_solid(anchor, "SeatCollision", Vector3(0, .235, .015), Vector3(2.23, .46, .77))
	_solid(anchor, "BackCollision", Vector3(0, .72, -.29), Vector3(2.08, .48, .13), Basis(Vector3.RIGHT, -.18))
	for x: float in [-1.065, 1.065]:
		_solid(anchor, "SideFrame", Vector3(x, .355, .015), Vector3(.12, .70, .78))
	var strip := MeshInstance3D.new()
	strip.name = "BenchWarmLightStrip"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.96, .012, .009)
	strip.mesh = mesh
	strip.material_override = materials.warm
	strip.position = Vector3(0, .390, .398)
	strip.visibility_range_end = 145
	strip.visibility_range_end_margin = 12
	strip.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anchor.add_child(strip)
	seats.append({"name": label, "node": anchor.get_path(), "world_position": anchor.global_position,
		"seat_height_m": .46, "width_m": 2.25, "facing": group.global_basis.z,
		"asset": "midori_2050_timber_bench.glb"})

func _planter(group: Node3D, pos: Vector3, size: Vector2, height: float, id: String) -> void:
	var prior_children: Dictionary = {}
	for child: Node in group.get_children():
		prior_children[child.get_instance_id()] = true
	# The source constructor remains authoritative for shell dimensions,
	# diffuser materials, every planted transform and the canopy-column gap.
	var outer_plant_batches: Dictionary = plant_batches
	plant_batches = {}
	super._planter(group, pos, size, height, id)
	var owned_plant_batches: Dictionary = plant_batches
	plant_batches = outer_plant_batches
	var owned_nodes: Array[Node3D] = []
	for child: Node in group.get_children():
		if child is Node3D and not prior_children.has(child.get_instance_id()):
			owned_nodes.append(child as Node3D)
	var anchor := Node3D.new()
	anchor.name = ("CreatorPlanter_" + id.replace(".", "_")).validate_node_name()
	anchor.position = pos
	group.add_child(anchor)
	_mark_editable(anchor, "Midori Rear Planter" if size.x > 1.0 else "Midori Planter", "planter")
	anchor.set_meta("creator_original_planter_id", id)
	for member: Node3D in owned_nodes:
		member.reparent(anchor, true)
	var to_anchor := anchor.global_transform.affine_inverse()
	var local_serial := 0
	for key: String in owned_plant_batches:
		var row: Dictionary = owned_plant_batches[key]
		var node := MultiMeshInstance3D.new()
		node.name = "PlanterPlants_%02d" % local_serial
		var mesh: Mesh = row.mesh.duplicate()
		for surface: int in range(row.overrides.size()):
			mesh.surface_set_material(surface, row.overrides[surface])
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = row.transforms.size()
		var local_transforms: Array[Transform3D] = []
		for index: int in range(multimesh.instance_count):
			var local_transform := to_anchor * (row.transforms[index] as Transform3D)
			local_transforms.append(local_transform)
			multimesh.set_instance_transform(index, local_transform)
		node.multimesh = multimesh
		# Native headless rendering discards MultiMesh data. Keep the exact
		# authored CPU transforms for deterministic fixtures and introspection;
		# production still uploads these same transforms to the real renderer.
		node.set_meta("creator_authored_local_transforms", local_transforms)
		node.visibility_range_end = 75
		node.visibility_range_end_margin = 8
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		anchor.add_child(node)
		local_serial += 1
		plant_batch_serial += 1

func _mark_editable(anchor: Node3D, display_name: String, kind: String) -> void:
	anchor.set_meta("creator_editable", true)
	anchor.set_meta("creator_display_name", display_name)
	anchor.set_meta("creator_object_kind", kind)
