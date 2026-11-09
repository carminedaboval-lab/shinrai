extends RefCounted
## Optional diagnostic output, activated only with --profile-startup after -- (see PROFILE_STARTUP.cmd).
static var enabled := "--profile-startup" in OS.get_cmdline_user_args()
static var events: Array[Dictionary] = []

static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0

static func finish(stage: String, started: int) -> int:
	if not enabled: return 0
	var now := Time.get_ticks_usec()
	var event := {"stage":stage,"duration_ms":float(now-started)/1000.0,"engine_elapsed_ms":float(now)/1000.0}
	events.append(event)
	print("STARTUP_PROFILE ",JSON.stringify(event))
	# Also append to a file in the project so the profile survives a hard close.
	var log := FileAccess.open("res://startup_profile_events.log", FileAccess.READ_WRITE if FileAccess.file_exists("res://startup_profile_events.log") else FileAccess.WRITE)
	if log != null:
		log.seek_end()
		log.store_line(JSON.stringify(event))
		log.close()
	return now

## Profiling watchdog: every two seconds, record which park feature nodes have
## not finished installing, and the slowest frame seen since the last sample.
static var _watch_last_sample := 0
static var _watch_worst_frame := 0.0
static var _watch_prev_tick := 0
static func watch(park: Node) -> void:
	if not enabled or not is_instance_valid(park): return
	var now := Time.get_ticks_usec()
	if _watch_prev_tick > 0:
		_watch_worst_frame = maxf(_watch_worst_frame, float(now - _watch_prev_tick) / 1000.0)
	_watch_prev_tick = now
	if now - _watch_last_sample < 2_000_000: return
	_watch_last_sample = now
	var pending: Array[String] = []
	for child: Node in park.get_children():
		# Only bool flags count: some nodes have a `finished` signal, and comparing a
		# Signal with a bool raises an error that aborted every sample.
		var state: Variant = child.get("installed")
		var done: Variant = child.get("finished")
		if state is bool and not state: pending.append(child.name)
		elif done is bool and not done: pending.append(child.name)
	var ui := park.get_tree().get_first_node_in_group("shinrai_loading_ui")
	var stage := str(ui.stage_label.text) if ui != null and ui.get("stage_label") != null else ""
	var event := {"watch": true, "engine_elapsed_ms": float(now) / 1000.0, "worst_frame_ms": _watch_worst_frame, "stage": stage, "pending": pending}
	_watch_worst_frame = 0.0
	var log := FileAccess.open("res://startup_profile_events.log", FileAccess.READ_WRITE if FileAccess.file_exists("res://startup_profile_events.log") else FileAccess.WRITE)
	if log != null:
		log.seek_end(); log.store_line(JSON.stringify(event)); log.close()
