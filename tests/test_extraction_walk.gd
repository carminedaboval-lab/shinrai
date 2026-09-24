extends SceneTree

# Physical input-driven traversal, not a substitute for a manual playthrough.
# Does not teleport, disable collision, call complete_site, or force extraction.
var raid: Node
var save_path := "user://shinrai_walk_qa_%d.json" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("run")

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = save_path
	root.add_child(scene)
	current_scene = scene
	raid = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 60000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	if raid.phase != raid.Phase.HQ:
		finish(false, "Park did not reach HQ")
		return
	raid.start_run()
	if raid.phase != raid.Phase.RAID:
		finish(false, "Deployment failed")
		return
	var relays: Array = raid.sites.filter(func(site: Dictionary) -> bool: return site.kind == "relay")
	if relays.is_empty():
		finish(false, "No relay registered")
		return
	var relay: Dictionary = relays[0]
	raid.selected_destination = relay.id
	raid.refresh_guidance()
	if not await walk(raid.guidance_path, "insertion to " + String(relay.title)):
		finish(false, "Relay approach failed")
		return
	key(KEY_E, true)
	for frame: int in range(Engine.physics_ticks_per_second * 6):
		await physics_frame
		if relay.done or raid.phase != raid.Phase.RAID:
			break
	key(KEY_E, false)
	if not relay.done:
		finish(false, "Hold E did not recover relay at %s" % raid.player.global_position)
		return
	var exit_id := "west" if OS.get_cmdline_user_args().has("--west") else "south"
	raid.selected_destination = exit_id
	raid.refresh_guidance()
	if not await walk(raid.guidance_path, String(relay.title) + " to " + exit_id):
		finish(false, "Extraction approach failed")
		return
	for frame: int in range(Engine.physics_ticks_per_second * 18):
		await physics_frame
		if raid.phase != raid.Phase.RAID:
			break
	finish(raid.phase == raid.Phase.RESULT and raid.result_extracted and raid.result_saved, "Insertion → relay → %s extraction" % exit_id)

func walk(route: PackedVector3Array, label: String) -> bool:
	if route.is_empty():
		print("WALK_BLOCKED: no route for ", label)
		return false
	# Raid guidance is rebuilt every second; hold an independent waypoint copy.
	var waypoints := route.duplicate()
	print("WALK_START: ", label, " at ", raid.player.global_position)
	# Walk, rather than sprint, so small waypoints can be reached without overshoot.
	for index: int in range(waypoints.size()):
		var target := waypoints[index]
		var checkpoint: Vector3 = raid.player.global_position
		var reached := false
		for frame: int in range(Engine.physics_ticks_per_second * 12):
			var position: Vector3 = raid.player.global_position
			var distance := Vector2(position.x, position.z).distance_to(Vector2(target.x, target.z))
			if distance <= (0.12 if index == waypoints.size() - 1 else 0.45):
				reached = true
				break
			if raid.phase != raid.Phase.RAID:
				key(KEY_W, false)
				return raid.phase == raid.Phase.RESULT and raid.result_extracted
			raid.player.look_at(Vector3(target.x, position.y, target.z))
			key(KEY_W, true)
			await physics_frame
			if frame > 0 and frame % (Engine.physics_ticks_per_second * 3) == 0:
				if raid.player.global_position.distance_to(checkpoint) < 0.25:
					print("WALK_SNAG: ", label, " position=", raid.player.global_position, " target=", target)
					for collision_index: int in range(raid.player.get_slide_collision_count()):
						var hit: KinematicCollision3D = raid.player.get_slide_collision(collision_index)
						print("WALK_COLLIDER: ", hit.get_collider().get_path(), " normal=", hit.get_normal())
					key(KEY_W, false)
					return false
				checkpoint = raid.player.global_position
		key(KEY_W, false)
		if not reached:
			print("WALK_TIMEOUT: position=", raid.player.global_position, " target=", target)
			return false
	# Let normal friction settle the controller before holding an interaction key.
	for frame: int in range(Engine.physics_ticks_per_second / 2):
		await physics_frame
	print("WALK_END: ", label, " at ", raid.player.global_position)
	return true

func finish(passed: bool, message: String) -> void:
	for code: Key in [KEY_W, KEY_E]:
		key(code, false)
	print("EXTRACTION_WALK_RESULT: ", "PASS " if passed else "FAIL ", message)
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(save_path + suffix)
	quit(0 if passed else 1)
