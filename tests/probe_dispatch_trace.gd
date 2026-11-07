extends SceneTree

# Second-by-second trace of a dispatched pack: where the leader slows or stops,
# what it is steering at, and which followers never leave.
# godot --headless --path . --script res://tests/probe_dispatch_trace.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_dispatch_trace_qa.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 300000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	raid.start_run()
	raid.player.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 20:
		await physics_frame
	var director: Node = scene.get_node("PoliceDroneGroups")
	var packs: Array = director.groups
	var caller: Node3D = packs[1]
	var point: Vector3 = caller.living_members()[0].global_position
	director.backup_ready_at = 0.0
	director.request_backup(caller, point)
	var responder: Node3D = null
	for candidate: Node3D in packs:
		if candidate.backup_goal.is_finite(): responder = candidate
	if responder == null:
		print("TRACE no responder")
		quit(1)
		return
	var goal: Vector3 = responder.backup_goal
	var last: Vector3 = responder.leader.global_position
	var seen: Dictionary = {}
	var streak: Dictionary = {}
	var worst: Dictionary = {}
	for second: int in 270:
		await _wait(1.0)
		if not is_instance_valid(responder.leader): break
		for member: CharacterBody3D in responder.living_members():
			var was: Vector3 = seen.get(member, member.global_position)
			seen[member] = member.global_position
			streak[member] = int(streak.get(member, 0)) + 1 if was.distance_to(member.global_position) < .3 and responder.backup_goal.is_finite() else 0
			worst[member] = maxi(int(worst.get(member, 0)), int(streak[member]))
		var lead: CharacterBody3D = responder.leader
		var step: float = lead.global_position.distance_to(last)
		last = lead.global_position
		var next: Vector3 = lead.nav_path[0] if not lead.nav_path.is_empty() else Vector3.INF
		var to_next: float = lead.global_position.distance_to(next) if next.is_finite() else -1.0
		var local: Vector3 = lead.global_basis.inverse() * (next - lead.global_position) if next.is_finite() else Vector3.ZERO
		print("TRACE t=%d pos=(%.0f,%.0f) step=%.1f st=%s path=%d detour=%d esc=%s next=%.1f yaw=%.2f spd=%.2f turn=%.2f stalls=%d left=%.0f stl=%.1f" % [second + 1, lead.global_position.x, lead.global_position.z, step, lead.nav_status, lead.nav_path.size(), lead.nav_detour_points, lead.nav_escape_point.is_finite(), to_next, atan2(local.x, local.z), lead.desired_speed, lead.desired_turn, lead.nav_stall_replans, lead.global_position.distance_to(goal), float(responder.backup_stall_seconds)])
		if second % 10 == 9:
			var rows: Array[String] = []
			for member: CharacterBody3D in responder.living_members():
				var ahead: Vector3 = member.global_basis.inverse() * (member.nav_path[0] - member.global_position) if not member.nav_path.is_empty() else Vector3.ZERO
				var hop: float = member.global_position.distance_to(member.nav_path[0]) if not member.nav_path.is_empty() else -1.0
				rows.append("%s (%.0f,%.0f) %s path=%d stalls=%d det=%d esc=%s veto=%s urgent=%s mob=%.1f hop=%.1f yaw=%.2f spd=%.2f turn=%.2f vel=%.2f wait=%s goal=%.0f" % [member.name, member.global_position.x, member.global_position.z, member.nav_status, member.nav_path.size(), member.nav_stall_replans, member.nav_detour_points, member.nav_escape_point.is_finite(), member.nav_turn_vetoed, member.nav_urgent, member.mobility, hop, atan2(ahead.x, ahead.z), member.desired_speed, member.desired_turn, Vector2(member.velocity.x, member.velocity.z).length(), member._block_wait_active(), member.global_position.distance_to(goal)])
			print("MEMBERS t=%d %s" % [second + 1, " | ".join(rows)])
		if not responder.backup_goal.is_finite():
			print("TRACE dispatch ended t=%d" % (second + 1))
			var report: Array[String] = []
			for member: CharacterBody3D in responder.living_members():
				report.append("%s stuck=%ds left=%.0fm" % [str(member.name).replace("PoliceDrone_", ""), int(worst.get(member, 0)), member.global_position.distance_to(goal)])
			print("TRACE_PACK ", " | ".join(report))
			break
	print("TRACE_DONE")
	quit(0)

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
