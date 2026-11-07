extends SceneTree

# Times each police-drone component per physics tick by driving their
# _physics_process calls manually. Headless; no game code is modified.
# godot --headless --path . --script res://tests/probe_drone_cost.gd

const PATHS := {
	"actor": "patrol_actor.gd",
	"awareness": "patrol_awareness.gd",
	"combat": "patrol_combat.gd",
	"pack": "patrol_pack.gd",
	"face": "patrol_face_attachment.gd",
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_drone_probe_qa.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 300000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	raid.start_run()
	raid.player.global_position = Vector3(-164, 0.2, -40)
	for i in 120:
		await physics_frame
	var nodes := {}
	for key: String in PATHS:
		nodes[key] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var script: Script = node.get_script()
		if script == null or not node.is_physics_processing(): continue
		for key: String in PATHS:
			if script.resource_path.ends_with(PATHS[key]):
				nodes[key].append(node)
	for key: String in nodes:
		for node: Node in nodes[key]:
			node.set_physics_process(false)
	for actor: Node in nodes["actor"]:
		var awareness := actor.get_node_or_null("Awareness")
		print("DRONE %s dist=%.0fm mode=%s state=%s" % [actor.name, actor.global_position.distance_to(raid.player.global_position), actor.get("mode"), awareness.get("state") if awareness else "?"])
	var totals := {}
	var per_actor := {}
	var ticks := 0
	var delta := 1.0 / 60.0
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 8000:
		await physics_frame
		ticks += 1
		for key: String in nodes:
			for node: Node in nodes[key]:
				if not is_instance_valid(node): continue
				var t0 := Time.get_ticks_usec()
				node._physics_process(delta)
				var spent := Time.get_ticks_usec() - t0
				totals[key] = int(totals.get(key, 0)) + spent
				if key == "actor":
					per_actor[node.name] = int(per_actor.get(node.name, 0)) + spent
	print("DRONE_TICKS %d" % ticks)
	for key: String in totals:
		print("DRONE_COST %-10s n=%d  %.2f ms per tick total" % [key, nodes[key].size(), totals[key] / 1000.0 / ticks])
	for name: String in per_actor:
		print("DRONE_ACTOR %-30s %.2f ms per tick" % [name, per_actor[name] / 1000.0 / ticks])
	quit()
