extends SceneTree
## Where the gates with leaves are, so one can be looked at:
##   godot --headless --path . --script res://tests/probe_find_gates.gd
## Prints GATES_AT lines (plot, where in the world, which way the frontage faces, what it has)
## and a tally of how many plots got walls, pillars and leaves.

const Blockout := preload("res://scripts/map1/map1_blockout.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var map: Node3D = Blockout.new()
	map.with_player = false
	root.add_child(map)
	for i: int in 4: await physics_frame
	var world: Node3D = map.world
	var walled := 0
	var pillared := 0
	var leafed := 0
	var one_leaf := 0
	var plots := 0
	var shown := 0
	for index: int in world.candidates:
		var plan: Dictionary = world.site(index)
		if not bool(plan.ok): continue
		plots += 1
		var items := str((plan.get("features", {}) as Dictionary).get("plot", ""))
		if "block wall" in items: walled += 1
		if "gate pillars" in items: pillared += 1
		if "leaf open against its pillar" in items:
			leafed += 1
			if "1 leaf open" in items: one_leaf += 1
			if shown < 8:
				shown += 1
				# Ready to paste into map1_world_capture.gd: standing on the footway a little to
				# one side of the gate, looking in at the door. The plot's own frame decides which
				# way that is, which guessing from the world coordinates does not.
				var frame: Transform3D = plan.frame
				var middle := float(plan.spec.size.x) * 0.5
				var eye: Vector3 = frame * Vector3(middle - 1.1, 0.0, -3.4)
				var at: Vector3 = frame * Vector3(middle, 0.0, 0.2)
				print("GATES_AT plot %d: _eye(Vector3(%.1f, 0.0, %.1f), 1.65), _eye(Vector3(%.1f, 0.0, %.1f), 1.0) — %s" % [index, eye.x, eye.z, at.x, at.z, items])
	print("GATES_DONE %d plots, %d walled, %d with pillars, %d with a leaf (%d of those with one leaf only)" % [plots, walled, pillared, leafed, one_leaf])
	quit(0)
