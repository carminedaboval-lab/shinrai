extends "res://tests/probe_shader_warmup.gd"

# Checks the raid clock in the real park (QA profile, never the player's save; no mouse capture):
#   godot --path . --fixed-fps 60 --script res://tests/raid_clock_check.gd
# The raid starts aboard the tram; the clock is then jumped forward to each mark to check
# rising threat, the two drone reinforcements, the warnings, the last tram leaving and the
# lockdown. Prints RAID_CLOCK lines and RAID_CLOCK RESULT pass/fail.

var failures: Array[String] = []
var raid: Node
var rail: Node3D
var notices: Array[String] = []


func _check(ok: bool, what: String) -> void:
	print("RAID_CLOCK %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok: failures.append(what)


func _seconds(duration: float) -> void:
	for i: int in int(duration * 60.0):
		await physics_frame
		var text := str(raid.get("notice"))
		if not text.is_empty() and (notices.is_empty() or notices[notices.size() - 1] != text):
			notices.append(text)
			print("RAID_CLOCK notice: ", text)


func _jump_to_elapsed(elapsed: float) -> void:
	raid.set("remaining", float(raid.RAID_SECONDS) - elapsed)
	await _seconds(1.0)


func _run() -> void:
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
	physics_frame.connect(func() -> void:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	raid.start_run()
	for i: int in 1800:
		if int(raid.get("phase")) == 2: break
		await process_frame
	_check(int(raid.get("phase")) == 2, "raid started")
	rail = raid.get("rail")
	var player: Node = raid.get("player")
	player.set("test_input_override", true)
	_check(is_equal_approx(float(raid.RAID_SECONDS), 2400.0), "raid length is 40 minutes")
	# Wait for the arrival stop, which starts the clock.
	for i: int in 60 * 60:
		if int(rail.mode) == rail.Mode.DWELL: break
		await physics_frame
	_check(float(raid.get("remaining")) > 2390.0, "clock starts full at the arrival stop (%.0f s)" % float(raid.get("remaining")))
	# Walk off so the tram resumes service, and keep the player out of every fight.
	player.global_position = rail.stop_ground(rail.arrival_stop) + Vector3.UP * 0.3
	player.set("alive", true)
	var t0: float = raid.threat_level()
	_check(t0 < 0.01, "threat starts at zero (%.2f)" % t0)
	var director: Node = get_first_node_in_group("police_drone_directors")
	var packs_before: int = director.groups.size() if director != null else -1
	await _jump_to_elapsed(905.0)
	await _seconds(2.0)
	var t1: float = raid.threat_level()
	_check(t1 > 0.2 and t1 < 0.6, "threat at 15 min is mid-range (%.2f)" % t1)
	_check(director != null and director.groups.size() == packs_before + 1, "first reinforcement pack arrived (%d -> %d)" % [packs_before, director.groups.size() if director != null else -1])
	await _jump_to_elapsed(1685.0)
	await _seconds(2.0)
	_check(director != null and director.groups.size() == packs_before + 2, "second reinforcement pack arrived")
	# The rest checks the tram and the clock only: keep the sweeps from ending the test early.
	raid._clear_enemies()
	await _jump_to_elapsed(float(raid.RAID_SECONDS) - 595.0)
	await _jump_to_elapsed(float(raid.RAID_SECONDS) - 295.0)
	await _jump_to_elapsed(float(raid.RAID_SECONDS) - 175.0)
	_check(bool(rail.final_run), "last tram called at 3 minutes")
	var t2: float = raid.threat_level()
	_check(t2 > 0.95, "threat near maximum at the end (%.2f)" % t2)
	# Hold the clock above zero while the last tram finishes its stop and leaves.
	for i: int in 60 * 120:
		if bool(rail.service_over): break
		if i % 60 == 0: raid.set("remaining", maxf(float(raid.get("remaining")), 120.0))
		await physics_frame
		if i % 30 == 0:
			var text := str(raid.get("notice"))
			if not text.is_empty() and (notices.is_empty() or notices[notices.size() - 1] != text):
				notices.append(text)
				print("RAID_CLOCK notice: ", text)
	_check(bool(rail.service_over), "the last tram left the city")
	await _seconds(9.0)
	_check(not rail.tram.visible, "tram gone after leaving")
	var joined := "\n".join(notices)
	for phrase: String in ["ten minutes", "five minutes", "LAST TRAM", "last tram has left"]:
		_check(joined.containsn(phrase), "warning shown: %s" % phrase)
	raid.set("remaining", 0.5)
	for i: int in 300:
		if int(raid.get("phase")) != 2: break
		await physics_frame
	var result: Dictionary = raid.get("pending_result_save")
	_check(int(raid.get("phase")) != 2, "lockdown ended the raid")
	print("RAID_CLOCK result ", JSON.stringify(result), " profile_error=", raid.profile.last_error)
	print("RAID_CLOCK RESULT %s (%d failed)" % ["pass" if failures.is_empty() else "fail", failures.size()])
	quit(0 if failures.is_empty() else 1)
