class_name ShinraiLoadState
extends RefCounted
## Shared, static world-build progress for the boot flow, the Operations menu and
## the queued-deploy cover. Static-only: nothing here owns nodes.
## Milestones (set by the boot flow): resources 0->0.20, park structure 0.20->0.45,
## producers 0.45->0.65, navigation 0.65->0.75, world-complete 0.75->0.95,
## warm-up 0.95->1.0. Prefer preload("res://scripts/shinrai_load_state.gd") over the
## class name in scripts that may run before the editor refreshed its class cache.

const WARMUP_PATH := "res://scripts/shinrai_shader_warmup.gd"
const WORLD_COMPLETE_PATH := "res://scripts/shinrai_world_complete.gd"
const OPERATIONS_MENU_PATH := "res://scripts/ui/shinrai_operations_menu.gd"

static var fraction := 0.0
static var stage := ""
static var world_ready := false
static var first_launch_shaders := false
## True from the first drawn frame of the Operations menu (early or HQ).
static var menu_shown := false
## Engine msec of the last report() (watchdog: real progress, not the creep).
static var last_report_ms := 0
static var _band_start := 0.0
static var _band_end := 0.0
static var _band_seconds := 0.0
static var _band_started_ms := 0

static func report(stage_text: String, at_least: float = -1.0) -> void:
	if not stage_text.is_empty(): stage = stage_text
	if at_least >= 0.0: fraction = maxf(fraction, clampf(at_least, 0.0, 1.0))
	last_report_ms = Time.get_ticks_msec()

## Starts a progress band: tick() creeps toward `end` (never reaching it) with
## the given expected duration, so the bar keeps moving through long steps.
static func band(stage_text: String, start: float, end: float, expected_seconds: float) -> void:
	report(stage_text, start)
	_band_start = maxf(fraction, start)
	_band_end = maxf(_band_start, end)
	_band_seconds = maxf(0.1, expected_seconds)
	_band_started_ms = Time.get_ticks_msec()

static func tick() -> void:
	if _band_end <= _band_start or world_ready: return
	var elapsed := (Time.get_ticks_msec() - _band_started_ms) / 1000.0
	var eased := 0.92 * (1.0 - exp(-elapsed / _band_seconds))
	fraction = maxf(fraction, _band_start + (_band_end - _band_start) * eased)

static func reset() -> void:
	fraction = 0.0
	stage = ""
	world_ready = false
	first_launch_shaders = false
	menu_shown = false
	last_report_ms = Time.get_ticks_msec()
	_band_start = 0.0
	_band_end = 0.0

static func mark_world_ready() -> void:
	fraction = 1.0
	world_ready = true
	stage = "Park ready"
	last_report_ms = Time.get_ticks_msec()

## Optional collaborators, loaded at runtime so a missing or half-finished file
## degrades to the previous behaviour instead of breaking the parse of callers.
static func optional_script(path: String) -> Script:
	if not ResourceLoader.exists(path): return null
	var script := load(path) as Script
	if script == null or not script.can_instantiate(): return null
	return script

static func warmup_script() -> Script:
	return optional_script(WARMUP_PATH)

static func script_has(script: Script, method: String) -> bool:
	if script == null: return false
	for entry: Dictionary in script.get_script_method_list():
		if str(entry.get("name", "")) == method: return true
	return false

## Loading-screen calls through the owner-token API, tolerant of the older
## single-owner screen while it is being replaced.
static func ui_begin(ui: Object, text: String, owner: StringName) -> void:
	if ui == null: return
	if ui.get_method_argument_count("begin") >= 2: ui.call("begin", text, owner)
	else: ui.call("begin", text)

static func ui_finish(ui: Object, owner: StringName) -> void:
	if ui == null: return
	if ui.get_method_argument_count("finish") >= 1: ui.call("finish", owner)
	else: ui.call("finish")

static func ui_show_cancel(ui: Object, enabled: bool) -> void:
	if ui != null and ui.has_method("show_cancel"): ui.call("show_cancel", enabled)

## Text for a cover that waits on the world build ("Preparing the park · <stage>").
static func waiting_text() -> String:
	return "Preparing the park  ·  %s" % stage if not stage.is_empty() else "Preparing the park"
