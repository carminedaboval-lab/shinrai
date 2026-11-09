extends RefCounted
## Shared main-thread budget. Geometry, physics queries and RNG order stay native.
## checkpoint() yields once this frame's share is spent. The share adapts:
## INTERACTIVE_BUDGET_USEC while a menu is visible and the player is using it
## (set_interactive(true) from the boot flow / UI, plus recent input), else
## FRAME_BUDGET_USEC (opaque loading screen or an idle menu).
const LoadState := preload("res://scripts/shinrai_load_state.gd")
## Idle menu / opaque cover: nothing on screen moves, so a frame may do more
## work (fewer frames, less per-frame overhead). Input drops it to 14 ms at once.
const FRAME_BUDGET_USEC := 100000
const INTERACTIVE_BUDGET_USEC := 14000
## An open menu with no input for this long counts as idle (the larger budget).
const IDLE_AFTER_USEC := 4000000

static var interactive := false
static var _last_input_usec := 0
static var _frame := -1
static var _frame_start := 0

## FLOW / UI: true while a menu the player can use is visible over the build.
static func set_interactive(value: bool) -> void:
	interactive = value
	if value: _last_input_usec = Time.get_ticks_usec()

## Called by the boot host at the very start of each frame (first process_frame
## listener), so a frame's share also counts the work that resumed from a plain
## `await process_frame` before the first checkpoint. Without it (no boot host),
## the share is measured from the first checkpoint of the frame.
static func frame_started() -> void:
	_frame = Engine.get_process_frames()
	_frame_start = Time.get_ticks_usec()

## UI may call this from _input; checkpoint() also polls buttons and the mouse.
static func note_input() -> void:
	_last_input_usec = Time.get_ticks_usec()

## QA only: --loading-budget-ms=<n> replaces the idle/opaque share (measuring
## how much of the build time is per-frame overhead). The default is unchanged.
static var _idle_budget_usec := _read_idle_budget()
static func _read_idle_budget() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--loading-budget-ms="): return int(arg.get_slice("=", 1)) * 1000
	return FRAME_BUDGET_USEC

static func frame_budget_usec() -> int:
	if not interactive: return _idle_budget_usec
	var now := Time.get_ticks_usec()
	if Input.is_anything_pressed() or Input.get_last_mouse_velocity().length_squared() > 1.0:
		_last_input_usec = now
	return INTERACTIVE_BUDGET_USEC if now - _last_input_usec < IDLE_AFTER_USEC else _idle_budget_usec

static func wait_structure(park: Node) -> void:
	while is_instance_valid(park) and park.get_meta("shinrai_structure_pending",false):
		await park.get_tree().process_frame
	# The near city now builds in budgeted slices and may still be laying tiles
	# here. Only alley life reads its contents (alleys, hand-built list) and it
	# waits for `built` itself; Tokyo roads only reads its constant clear zones.
	# Everything waiting here used to wake in the same frame and run its
	# synchronous body there (an ~8 s frame). Same order, but one budget at a time.
	await checkpoint(park)

static func stage(park: Node, text: String, at_least: float = -1.0) -> void:
	LoadState.report(text, at_least)
	if not is_instance_valid(park) or not park.is_inside_tree(): return
	var ui:=park.get_tree().get_first_node_in_group("shinrai_loading_ui")
	if ui!=null: ui.set_stage(text)

## Yields to the next frame once this frame's budget is spent. A no-op outside
## incremental loading (tests that load the park scene directly), unless forced.
static func checkpoint(park: Node, force: bool = false) -> void:
	if not is_instance_valid(park): return
	if not force and not park.get_meta("shinrai_incremental_loading",false): return
	if PROFILE: _note_slice()
	while is_instance_valid(park) and park.is_inside_tree():
		var frame:=Engine.get_process_frames()
		if _frame!=frame:
			_frame=frame
			_frame_start=Time.get_ticks_usec()
		if Time.get_ticks_usec()-_frame_start<frame_budget_usec(): return
		await park.get_tree().process_frame
		if PROFILE: _note_slice()

## --profile-startup only: a stretch of > 250 ms between two checkpoint calls
## (from any module) is printed with where the previous call returned to (the
## code that then ran on: the culprit) and where the next call came from.
static var PROFILE := "--profile-startup" in OS.get_cmdline_user_args()
static var _last_checkpoint_usec := 0
static var _last_where := ""
static func _note_slice() -> void:
	var now := Time.get_ticks_usec()
	var where := ""
	if Engine.has_method("capture_script_backtraces"):
		for trace: Variant in Engine.call("capture_script_backtraces"):
			var count: int = trace.get_frame_count()
			for i: int in range(2, mini(count, 6)):
				where += "%s:%d %s < " % [str(trace.get_frame_file(i)).get_file(), trace.get_frame_line(i), trace.get_frame_function(i)]
			break
	var frame := Engine.get_process_frames()
	# CPU tally per module: the work between two checkpoints in the same frame is
	# charged to the code the earlier checkpoint returned to (see the doc's note:
	# coroutines resuming from a plain frame wait are charged to it too).
	if _last_checkpoint_usec > 0 and frame == _last_profile_frame:
		# An empty "after" is a coroutine that resumed from an await (no script
		# stack): the code that ran is most often the one that reached this
		# checkpoint, so it is charged to that site as "(resumed) file".
		var key := _last_where.get_slice(":", 0) if not _last_where.is_empty() else ("(resumed) " + where.get_slice(":", 0) if not where.is_empty() else "(frame start)")
		_cpu_by_module[key] = int(_cpu_by_module.get(key, 0)) + (now - _last_checkpoint_usec)
		# The same, by checkpoint site (file:line function): finds the hot loop.
		var site := _last_where.get_slice(" < ", 0) if not _last_where.is_empty() else ("(resumed) " + where.get_slice(" < ", 0) if not where.is_empty() else "(frame start)")
		_cpu_by_site[site] = int(_cpu_by_site.get(site, 0)) + (now - _last_checkpoint_usec)
	if now - _last_cpu_print_usec > 20000000:
		var sites := _cpu_by_site.keys()
		sites.sort_custom(func(a: String, b: String) -> bool: return int(_cpu_by_site[a]) > int(_cpu_by_site[b]))
		var hot := {}
		for i: int in range(mini(30, sites.size())): hot[sites[i]] = int(_cpu_by_site[sites[i]]) / 1000
		print("BUDGET_CPU_SITES_MS ", JSON.stringify(hot))
		_last_cpu_print_usec = now
		var keys := _cpu_by_module.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return int(_cpu_by_module[a]) > int(_cpu_by_module[b]))
		var top := {}
		for i: int in range(mini(14, keys.size())): top[keys[i]] = int(_cpu_by_module[keys[i]]) / 1000
		print("BUDGET_CPU_MS ", JSON.stringify(top))
	# Only stretches inside one frame, or across a single frame boundary, are work.
	if _last_checkpoint_usec > 0 and now - _last_checkpoint_usec > 250000 and frame - _last_profile_frame <= 1:
		print("LONG_SLICE ", JSON.stringify({"ms": (now - _last_checkpoint_usec) / 1000, "frame": frame, "after": _last_where, "next": where}))
	_last_checkpoint_usec = Time.get_ticks_usec()
	_last_profile_frame = frame
	_last_where = where
static var _last_profile_frame := -1
static var _cpu_by_module: Dictionary = {}
static var _cpu_by_site: Dictionary = {}

## --profile-startup only: restart the per-site tally (a stage measures itself).
static func reset_site_profile() -> void:
	_cpu_by_site.clear()

## --profile-startup only: print the hottest checkpoint sites since the last reset.
static func print_site_profile(label: String, count: int = 40) -> void:
	if not PROFILE: return
	var sites := _cpu_by_site.keys()
	sites.sort_custom(func(a: String, b: String) -> bool: return int(_cpu_by_site[a]) > int(_cpu_by_site[b]))
	var total := 0
	for site: String in sites: total += int(_cpu_by_site[site])
	print("SITE_PROFILE %s total_ms=%d" % [label, total / 1000])
	for i: int in range(mini(count, sites.size())):
		print("SITE_PROFILE %s %6d ms  %s" % [label, int(_cpu_by_site[sites[i]]) / 1000, sites[i]])
static var _last_cpu_print_usec := 0

## True when this frame's budget is spent (for loops that yield themselves).
static func over_budget() -> bool:
	if _frame!=Engine.get_process_frames(): return false
	return Time.get_ticks_usec()-_frame_start>=frame_budget_usec()
