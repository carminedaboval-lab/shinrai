extends "res://tests/probe_shader_warmup.gd"

# Rides the tram in the real park and takes pictures (uses a QA profile, never the player's save,
# and never holds the mouse):
#   godot --path . --fixed-fps 60 --script res://tests/train_ride_capture.gd -- --out=<folder> [--night]
# Checks: the raid starts aboard, the tram stops and opens, the player can stand inside and on the
# ramp, the tram leaves, and staying aboard at the next stop with a relay ends the raid as extracted.
# Prints RAIL_TEST lines and a final RAIL_TEST RESULT pass/fail.

const Track := preload("res://scripts/shinrai_rail_track.gd")
const Tram := preload("res://scripts/shinrai_rail_tram.gd")

var out := "user://train_ride"
var raid: Node
var rail: Node3D
var player: CharacterBody3D
var free_camera: Camera3D
var failures: Array[String] = []
var last_mode := -1


func _check(ok: bool, what: String) -> void:
	print("RAIL_TEST %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok: failures.append(what)


func _shot(shot_name: String) -> void:
	for i: int in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, shot_name])
	print("RAIL_TEST shot ", shot_name)


func _seconds(duration: float) -> void:
	var frames := int(duration * 60.0)
	for i: int in frames: await physics_frame


func _wait_mode(wanted: int, limit_seconds: float) -> bool:
	var frames := int(limit_seconds * 60.0)
	for i: int in frames:
		if int(rail.mode) == wanted: return true
		await physics_frame
	return int(rail.mode) == wanted


## A camera on the road looking back at the tram, for outside pictures.
func _outside_view(ahead: float, across: float, height: float) -> void:
	var car: Node3D = rail.tram.cars[0]
	var eye: Vector3 = car.global_transform * Vector3(across, height, -ahead * float(rail.direction))
	var target: Vector3 = car.global_transform * Vector3(0.0, 1.5, 4.0 * float(rail.direction))
	free_camera.look_at_from_position(eye, target)
	free_camera.make_current()


func _run() -> void:
	var night := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg == "--night": night = true
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	Warmup.suppressed = true
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	var park := (load(WORLD) as PackedScene).instantiate() as Node3D
	park.set("profile_path", PROFILE)
	preload("res://scripts/creator/creator_game_integration.gd").prepare_world(park, LAYOUT)
	root.add_child(park)
	current_scene = park
	var deadline := Time.get_ticks_msec() + 900000
	while Time.get_ticks_msec() < deadline:
		raid = park.get_node_or_null("ExtractionRun")
		if raid != null and int(raid.get("phase")) == 1 and raid.world_ready(): break
		await process_frame
	_check(raid != null and raid.world_ready(), "park reached the HQ menu")
	if raid == null:
		quit(1); return
	if night:
		park.set("is_night_mode", true)
		park.call("_apply_time_of_day")
	physics_frame.connect(func() -> void:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if is_instance_valid(rail) and int(rail.mode) != last_mode:
			last_mode = int(rail.mode)
			print("RAIL_TEST mode %d s=%.1f speed=%.1f stop=%d dir=%d" % [last_mode, rail.s, rail.speed, rail.next_stop, rail.direction]))
	for i: int in 30: await process_frame
	raid.start_run()
	for i: int in 1800:
		if int(raid.get("phase")) == 2: break
		await process_frame
	_check(int(raid.get("phase")) == 2, "raid started")
	rail = raid.get("rail")
	player = raid.get("player")
	if rail == null or int(raid.get("phase")) != 2:
		print("RAIL_TEST RESULT fail"); quit(1); return
	player.set("test_input_override", true)
	raid._clear_enemies()
	free_camera = Camera3D.new()
	free_camera.fov = 65.0
	free_camera.far = 900.0
	park.add_child(free_camera)
	var stations: Array = raid.exits.filter(func(exit_point: Dictionary) -> bool: return exit_point.get("kind", "") == "station")
	_check(stations.size() == 10, "ten tram stops are on the map as exits")
	print("RAIL_TEST arrival stop=%d (%s) dir=%d" % [rail.arrival_stop, rail.STOP_NAMES[rail.arrival_stop], rail.direction])
	_check(rail.tram.car_holding(player.global_position) != null, "player starts aboard")

	# Riding in.
	await _seconds(1.5)
	var drift := 0.0
	var car: Node3D = rail.tram.cars[0]
	var local_start: Vector3 = car.global_transform.affine_inverse() * player.global_position
	await _shot("1_riding_in")
	for i: int in 120:
		await physics_frame
		drift = maxf(drift, (car.global_transform.affine_inverse() * player.global_position).distance_to(local_start))
	_check(drift < 0.05, "rider stays put while the tram moves (drift %.3f m)" % drift)
	_outside_view(22.0, -4.5, 1.7)
	await _shot("2_tram_approaching")
	player.camera.make_current()

	# Stop and doors.
	_check(await _wait_mode(rail.Mode.DWELL, 40.0), "tram stopped and opened at the chosen stop")
	_check(absf(rail.s - rail.stops[rail.arrival_stop]) < 0.1, "stopped on the mark")
	_check(rail.rider == null, "rider released when the doors opened")
	await _seconds(1.0)
	await _shot("3_doors_open_inside")
	_check(player.is_on_floor(), "player stands on the tram floor")
	var floor_y := player.global_position.y
	# On the ramp.
	player.global_position = car.global_transform * Vector3(Tram.HALF_W + 0.75, Tram.FLOOR_Y + 0.3, Tram.DOOR_Z[0])
	player.velocity = Vector3.ZERO
	await _seconds(1.0)
	var ramp_y := player.global_position.y
	_check(ramp_y < floor_y - 0.05 and ramp_y > floor_y - 0.42 and player.is_on_floor(), "boarding ramp holds the player (floor %.2f, ramp %.2f)" % [floor_y, ramp_y])
	# On the ground outside.
	player.global_position = rail.stop_ground(rail.arrival_stop) + Vector3.UP * 0.3
	player.velocity = Vector3.ZERO
	await _seconds(1.0)
	_check(player.is_on_floor() and raid._inside_playable_area(player.global_position), "stop is on playable ground (y %.2f)" % player.global_position.y)
	var look: Vector3 = car.global_transform * Vector3(0.0, 1.4, 0.0)
	player.look_at(Vector3(look.x, player.global_position.y, look.z))
	await _shot("4_stepped_off")
	_outside_view(13.0, 5.2, 1.65)
	await _shot("5_tram_at_stop")
	_outside_view(9.0, -6.0, 2.4)
	await _shot("6_tram_road_side")

	# Leaving.
	_check(await _wait_mode(rail.Mode.RUN, 70.0), "tram closed its doors and left without the player")
	await _seconds(2.5)
	await _shot("7_tram_leaving")
	player.camera.make_current()

	# Ride out: a relay in hand, aboard at the next stop when the doors close.
	raid.set("relays", 1)
	_check(await _wait_mode(rail.Mode.DWELL, 90.0), "tram reached the next stop")
	car = rail.tram.cars[0]
	player.global_position = car.global_transform * Vector3(0.0, Tram.FLOOR_Y + 0.2, 0.5)
	player.velocity = Vector3.ZERO
	look = car.global_transform * Vector3(3.0, 1.4, Tram.DOOR_Z[0])
	player.look_at(Vector3(look.x, player.global_position.y, look.z))
	await _seconds(1.0)
	print("RAIL_TEST prompt aboard: ", raid.get("prompt_text"))
	_check(str(raid.get("prompt_text")).contains("Stay aboard"), "prompt tells the player to stay aboard")
	await _shot("8_aboard_to_leave")
	rail.set("timer", rail.DWELL_SECONDS - 0.5)
	_check(await _wait_mode(rail.Mode.EXTRACT, 20.0), "doors closed with the player aboard")
	await _seconds(2.0)
	await _shot("9_riding_out")
	for i: int in 900:
		if int(raid.get("phase")) != 2: break
		await physics_frame
	var result: Dictionary = raid.get("pending_result_save")
	_check(int(raid.get("phase")) != 2, "raid ended")
	print("RAIL_TEST result ", JSON.stringify(result), " profile_error=", raid.profile.last_error)
	await _seconds(1.0)
	await _shot("10_result")
	print("RAIL_TEST RESULT %s (%d failed)" % ["pass" if failures.is_empty() else "fail", failures.size()])
	quit(0 if failures.is_empty() else 1)
