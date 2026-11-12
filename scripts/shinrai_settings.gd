extends RefCounted

## Player settings that outlive a session (user://shinrai_settings.cfg). Today: how edges are
## smoothed. Static, loaded by path like shinrai_load_state.gd; no autoload.
##
## Anti-aliasing is fixed for a session: the boot applies the saved choice before any park
## material exists, so the game prepares one set of render pipelines and no more. On this
## driver the temporal mode's motion-vector pipelines cost about 5 GB of memory in the park,
## which is why the mode is a setting. The edge filter is a cheap post-process and applies at once.

const PATH := "user://shinrai_settings.cfg"
const AA_MODES: Array[String] = ["off", "msaa2", "msaa4", "msaa8", "msaa9", "msaa12", "taa"]
const AA_LABELS: Array[String] = ["OFF", "2X", "4X", "8X", "9X", "12X", "TAA"]
const FILTERS: Array[String] = ["none", "fxaa", "smaa"]
const FILTER_LABELS: Array[String] = ["NONE", "FXAA", "SMAA"]
const DEFAULT_AA := "msaa4"
## FXAA by default: measured in the park it cuts leaf and cut-out shimmer by about a quarter
## on top of 4X at no frame cost (tests/probe_shimmer.gd, 2026-11-11).
const DEFAULT_FILTER := "fxaa"

## What the menu shows and the file holds.
static var saved_aa := DEFAULT_AA
static var saved_filter := DEFAULT_FILTER
## What this session renders with (set once, at boot).
static var session_aa := DEFAULT_AA
static var _loaded := false


static func load_settings() -> void:
	if _loaded: return
	_loaded = true
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		var aa := str(file.get_value("graphics", "anti_aliasing", DEFAULT_AA))
		var filter := str(file.get_value("graphics", "edge_filter", DEFAULT_FILTER))
		saved_aa = aa if AA_MODES.has(aa) else DEFAULT_AA
		saved_filter = filter if FILTERS.has(filter) else DEFAULT_FILTER
	session_aa = saved_aa


static func _save() -> void:
	var file := ConfigFile.new()
	file.load(PATH)
	file.set_value("graphics", "anti_aliasing", saved_aa)
	file.set_value("graphics", "edge_filter", saved_filter)
	file.save(PATH)


static func aa_index() -> int:
	load_settings()
	return maxi(0, AA_MODES.find(saved_aa))


static func filter_index() -> int:
	load_settings()
	return maxi(0, FILTERS.find(saved_filter))


## Saved now, used from the next launch.
static func set_aa(index: int) -> void:
	load_settings()
	saved_aa = AA_MODES[clampi(index, 0, AA_MODES.size() - 1)]
	_save()


## Saved and applied to the main view at once.
static func set_filter(index: int) -> void:
	load_settings()
	saved_filter = FILTERS[clampi(index, 0, FILTERS.size() - 1)]
	_save()
	var loop := Engine.get_main_loop() as SceneTree
	if loop != null: apply(loop.root)


static func session_uses_taa() -> bool:
	load_settings()
	return session_aa == "taa"


static func session_msaa() -> int:
	load_settings()
	return {"msaa2": Viewport.MSAA_2X, "msaa4": Viewport.MSAA_4X, "msaa8": Viewport.MSAA_8X, "msaa9": Viewport.MSAA_8X, "msaa12": Viewport.MSAA_8X}.get(session_aa, Viewport.MSAA_DISABLED)


## Graphics cards stop at 8 samples a pixel. 9X and 12X reach their sample counts by also
## drawing the picture larger and shrinking it: 8 samples on 1.125 or 1.5 times the pixels.
static func session_scale() -> float:
	load_settings()
	return {"msaa9": sqrt(9.0 / 8.0), "msaa12": sqrt(12.0 / 8.0)}.get(session_aa, 1.0)


## Writes this session's smoothing to a view (the main view at boot, and wherever the
## park re-asserts its render settings).
static func apply(view: Viewport) -> void:
	if view == null: return
	load_settings()
	var msaa := session_msaa()
	var taa := session_uses_taa()
	var filter: int = {"fxaa": Viewport.SCREEN_SPACE_AA_FXAA, "smaa": Viewport.SCREEN_SPACE_AA_SMAA}.get(saved_filter, Viewport.SCREEN_SPACE_AA_DISABLED)
	if view.msaa_3d != msaa: view.msaa_3d = msaa
	if view.use_taa != taa: view.use_taa = taa
	if view.screen_space_aa != filter: view.screen_space_aa = filter
