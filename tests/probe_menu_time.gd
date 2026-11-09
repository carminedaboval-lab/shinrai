extends SceneTree

# Times the real startup path (the main scene, shinrai_bootstrap.tscn), windowed,
# with a throwaway QA profile (never the player's save).
#   godot --path . --script res://tests/probe_menu_time.gd -- [--profile-startup]
#         [--deploy-immediately] [--no-deploy] [--second-deploy]
# Stamps (each with the worst frame of the segment since the previous stamp):
#   first_frame, menu_visible (first drawn frame with the Operations menu up),
#   park_in_tree, run_created, world_ready, menu_idle_5s, deploy_pressed,
#   raid_view, raid_5s, and with --second-deploy: hq_return, deploy2_pressed, raid2_view.
# Default: wait for world_ready, idle 5 s in the menu, then DEPLOY.
# --deploy-immediately: press DEPLOY on the first menu frame (queued deploy).

const LoadState = preload("res://scripts/shinrai_load_state.gd")
const Budget = preload("res://scripts/shinrai_loading_budget.gd")
const QA_PROFILE := "user://shinrai_menu_probe_timing.json"
const LIMIT_MSEC := 900000

var started := 0
var worst_frame_ms := 0.0
var frames := 0
var last_frame := 0
var args := PackedStringArray()

func _initialize() -> void:
	started = Time.get_ticks_msec()
	args = OS.get_cmdline_user_args()
	simulate_input = "--simulate-input" in args
	_run.call_deferred()

## Segment statistics (reset by every stamp) and the whole-build "menu up" view:
## frames while the Operations menu is visible and usable over an unfinished world.
var seg_frames := 0
var seg_ms := 0.0
var seg_over := [0, 0, 0] # > 250 ms, > 500 ms, > 1000 ms
var seg_physics_ms := 0.0
var seg_steps := 0
var menu_worst_ms := 0.0
var menu_worst_stage := ""
var menu_frames := 0
var menu_over := [0, 0, 0]
var _physics_first := 0
var _steps_this_frame := 0
var _stage_before := ""

func _physics_process(_delta: float) -> bool:
	if _physics_first == 0: _physics_first = Time.get_ticks_usec()
	_steps_this_frame += 1
	return false

func _menu_up() -> bool:
	if not LoadState.menu_shown or LoadState.world_ready: return false
	var loading := get_first_node_in_group("shinrai_loading_ui")
	return loading == null or not bool(loading.get("active"))

## --simulate-input: a player moving the mouse over the menu every frame of the
## build (the loading budget's smaller interactive share is then in force).
var simulate_input := false
var _sim_t := 0.0
func _simulate_menu_input() -> void:
	_sim_t += 0.05
	var motion := InputEventMouseMotion.new()
	var at := Vector2(960.0 + 600.0 * sin(_sim_t), 540.0 + 300.0 * sin(_sim_t * 0.7))
	motion.position = at
	motion.global_position = at
	motion.relative = Vector2(30.0 * cos(_sim_t), 21.0 * cos(_sim_t * 0.7))
	motion.velocity = motion.relative * 60.0
	Input.parse_input_event(motion)
	Budget.note_input()

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	var menu_up := _menu_up()
	if simulate_input and menu_up: _simulate_menu_input()
	if last_frame > 0:
		var ms := (now - last_frame) / 1000.0
		worst_frame_ms = maxf(worst_frame_ms, ms)
		seg_frames += 1
		seg_ms += ms
		for i: int in 3:
			if ms > [250.0, 500.0, 1000.0][i]: seg_over[i] += 1
		# Physics steps run before _process in the same main-loop iteration.
		if _physics_first > 0: seg_physics_ms += (now - _physics_first) / 1000.0
		seg_steps += _steps_this_frame
		if menu_up:
			menu_frames += 1
			for i: int in 3:
				if ms > [250.0, 500.0, 1000.0][i]: menu_over[i] += 1
			if ms > menu_worst_ms:
				menu_worst_ms = ms
				menu_worst_stage = "%s -> %s" % [_stage_before, LoadState.stage]
		if ms > 1000.0:
			print("MENU_PROBE_LONG %.0f ms at %.1f s menu_up=%s stage '%s' -> '%s' load=%.0f%%" % [ms, (Time.get_ticks_msec() - started) / 1000.0, menu_up, _stage_before, LoadState.stage, LoadState.fraction * 100.0])
	_physics_first = 0
	_steps_this_frame = 0
	_stage_before = LoadState.stage
	last_frame = now
	frames += 1
	return false

func _stamp(label: String) -> void:
	var info := "pipelines(canvas=%d mesh=%d surface=%d draw=%d spec=%d)" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]
	print("MENU_PROBE %s at %.1f s  frames=%d worst_frame=%.0f ms  load=%.0f%% '%s'  %s" % [label, (Time.get_ticks_msec() - started) / 1000.0, frames, worst_frame_ms, LoadState.fraction * 100.0, LoadState.stage, info])
	if seg_frames > 0:
		print("MENU_PROBE_SEGMENT %s frames=%d avg=%.1f ms physics=%.1f ms/frame steps=%.2f/frame over250=%d over500=%d over1000=%d" % [label, seg_frames, seg_ms / seg_frames, seg_physics_ms / seg_frames, float(seg_steps) / seg_frames, seg_over[0], seg_over[1], seg_over[2]])
	worst_frame_ms = 0.0
	seg_frames = 0
	seg_ms = 0.0
	seg_over = [0, 0, 0]
	seg_physics_ms = 0.0
	seg_steps = 0

func _menu_summary() -> void:
	print("MENU_PROBE_MENU_UP frames=%d worst=%.0f ms (%s) over250=%d over500=%d over1000=%d simulated_input=%s" % [menu_frames, menu_worst_ms, menu_worst_stage, menu_over[0], menu_over[1], menu_over[2], simulate_input])
	# Target: no frame over 0.5 s while the menu is usable. Printed every run;
	# --strict makes a miss fail the probe (exit code 2) so a regression cannot pass.
	print("MENU_PROBE_TARGET menu_over500=%d (target 0) %s" % [menu_over[1], "MET" if menu_over[1] == 0 else "MISSED"])
	if menu_over[1] > 0 and "--strict" in args: _strict_failed = true
var _strict_failed := false

func _timed_out() -> bool:
	return Time.get_ticks_msec() - started > LIMIT_MSEC

func _find_raid() -> Node:
	var park := root.get_node_or_null("ShinraiExtraction")
	if park == null:
		for child: Node in root.get_children():
			if child.get_node_or_null("ExtractionRun") != null: park = child
	return park.get_node_or_null("ExtractionRun") if park != null else null

func _find_park() -> Node:
	for child: Node in root.get_children():
		if child is Node3D and child.has_method("_apply_time_of_day"): return child
	return null

func _fail(label: String) -> void:
	_stamp(label)
	quit(1)

func _run() -> void:
	var boot: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	# Never touch the player's real save: use a throwaway QA profile.
	if not "profile_path" in boot:
		_fail("NO_PROFILE_PATH")
		return
	boot.profile_path = QA_PROFILE
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_PROFILE + suffix))
	root.add_child(boot)
	current_scene = boot
	await RenderingServer.frame_post_draw
	_stamp("first_frame")
	var immediate := "--deploy-immediately" in args
	var deploy := not "--no-deploy" in args
	var raid: Node = null
	var park_seen := false
	var deploy_pressed := false
	var menu_seen := false
	while not _timed_out():
		if not menu_seen and LoadState.menu_shown:
			menu_seen = true
			_stamp("menu_visible")
			if immediate and deploy and is_instance_valid(boot) and boot.has_method("press_menu_action"):
				boot.press_menu_action("deploy")
				deploy_pressed = true
				_stamp("deploy_pressed")
		if not park_seen and _find_park() != null:
			park_seen = true
			_stamp("park_in_tree")
		if raid == null:
			raid = _find_raid()
			if raid != null: _stamp("run_created")
		if raid != null and raid.world_ready(): break
		var loading := get_first_node_in_group("shinrai_loading_ui")
		var retry: Variant = loading.get("retry_button") if loading != null else null
		if retry is Control and (retry as Control).is_visible_in_tree():
			_fail("BOOT_FAILED")
			return
		await process_frame
	if raid == null or not raid.world_ready():
		_fail("TIMEOUT")
		return
	_stamp("world_ready")
	_menu_summary()
	if not deploy:
		await _idle(5000)
		_stamp("menu_idle_5s")
		quit(2 if _strict_failed else 0)
		return
	if not deploy_pressed:
		# Let the menu settle and measure its smoothness, then DEPLOY.
		await _idle(5000)
		_stamp("menu_idle_5s")
		raid.start_run()
		_stamp("deploy_pressed")
	var deploy_started := Time.get_ticks_msec()
	while not _deployed(raid) and Time.get_ticks_msec() - deploy_started < 180000: await process_frame
	if not _deployed(raid):
		_fail("DEPLOY_TIMEOUT")
		return
	_stamp("raid_view")
	_resume_if_paused(raid)
	await _idle(5000)
	_stamp("raid_5s")
	if "--second-deploy" in args:
		raid.finish_run(false, "Probe returned to HQ.")
		var result_wait := Time.get_ticks_msec()
		while raid.phase != raid.Phase.RESULT and Time.get_ticks_msec() - result_wait < 10000: await process_frame
		raid._on_action("hq")
		await _idle(2000)
		_stamp("hq_return")
		raid.start_run()
		_stamp("deploy2_pressed")
		var second := Time.get_ticks_msec()
		while not _deployed(raid) and Time.get_ticks_msec() - second < 60000: await process_frame
		_stamp("raid2_view" if _deployed(raid) else "DEPLOY2_TIMEOUT")
		print("MENU_PROBE second_deploy_seconds %.2f" % ((Time.get_ticks_msec() - second) / 1000.0))
	quit(2 if _strict_failed else 0)

## A window without OS focus (background QA run) deploys straight into PAUSED:
## focus loss while a deploy is queued/pending pauses the new raid by design.
func _deployed(raid: Node) -> bool:
	return raid.phase == raid.Phase.RAID or (raid.phase == raid.Phase.PAUSED and not bool(raid.get("deployment_pending")))

func _resume_if_paused(raid: Node) -> void:
	if raid.phase != raid.Phase.PAUSED: return
	print("MENU_PROBE note: deployed into PAUSED (window focused=%s); resuming to time the raid" % DisplayServer.window_is_focused())
	raid.resume_run()

func _idle(msec: int) -> void:
	var until := Time.get_ticks_msec() + msec
	while Time.get_ticks_msec() < until: await process_frame
