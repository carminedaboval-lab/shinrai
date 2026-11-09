extends RefCounted
## The world-complete step: everything that used to wake once the raid left
## Phase.BOOT, now run once, in order, before HQ (see the loading contract).
## ExtractionRun._prepare_park awaits run() after navigation and the distance
## boot, before the render budget and before phase = HQ.
##   1. Tokyo roads take their surface on the finished street and corporate roads.
##   2. The late whole-world Bush006 sweep (plaza azalea beds and the like).
##   3. Worn paths painted into the ground shader.
##   4. Biomes: look maps, ground-shader inject, then the eight builders.
##   5. Navigation re-sampled where those builders added, removed or moved
##      layer-1 bodies after the graph was built (AI used to path through
##      biome rocks and trunks).
## Each step yields on the shared, time-based loading budget. Picnic loot
## registration still waits for phase != BOOT on its own (unchanged).
## Creator has no ExtractionRun and never calls this: there the modules keep
## their own no-raid behaviour.
const Budget := preload("res://scripts/shinrai_loading_budget.gd")
const Trace := preload("res://scripts/startup_trace.gd")
const Navigation := preload("res://scripts/extraction_navigation.gd")
const STARTED_META := &"shinrai_world_complete_started"
const RESULT_META := &"shinrai_world_complete"
## What the end-of-boot release_build_data() hook dropped, per module.
const RELEASE_META := &"shinrai_world_release"
## The share of the overall loading bar this step owns (contract milestones).
const FROM := 0.75
const TO := 0.95

static func run(park: Node3D, raid: Node) -> Dictionary:
	if not is_instance_valid(park) or not park.is_inside_tree():
		return {"error": "Park is unavailable", "status": "cancelled"}
	if park.has_meta(RESULT_META): return park.get_meta(RESULT_META)
	var tree := park.get_tree()
	if park.get_meta(STARTED_META, false):
		# A second caller (the legacy watcher) waits for the first one's result.
		while is_instance_valid(park) and not park.has_meta(RESULT_META): await tree.process_frame
		return park.get_meta(RESULT_META) if is_instance_valid(park) else {"status": "cancelled"}
	park.set_meta(STARTED_META, true)
	# The biome builders' scenes and textures load on ResourceLoader's threads
	# while the roads, shrubs and worn paths below run (midori_biomes.prefetch).
	var biomes_script: Script = load("res://scripts/midori_biomes.gd")
	biomes_script.prefetch()
	var started := Time.get_ticks_msec()
	var report := {}
	var steps := {}
	var navigation: Object = raid.get("navigation") if is_instance_valid(raid) else null
	var colliders_before: Dictionary = {}
	var snapshot_tick := Trace.begin()
	if navigation != null and navigation.get("ready") == true:
		colliders_before = await Navigation.collider_snapshot(park)
	Trace.finish("world.collider_snapshot", snapshot_tick)
	var tick := Trace.begin()
	var step_started := Time.get_ticks_msec()

	_progress(park, "Resurfacing the streets", 0.0)
	var roads := park.get_node_or_null("MidoriTokyoRoads")
	if roads != null and roads.has_method("resurface_now"):
		report["tokyo_roads"] = await roads.resurface_now()
	tick = Trace.finish("world.tokyo_roads", tick)
	steps["tokyo_roads"] = Time.get_ticks_msec() - step_started
	if not is_instance_valid(park): return {"status": "cancelled"}

	step_started = Time.get_ticks_msec()
	_progress(park, "Clipping the garden shrubs", 0.04)
	var shrubs: Dictionary = await load("res://scripts/midori_clipped_shrubs.gd").apply_after_boot_now(park)
	report["clipped_shrubs_after_boot"] = {"hidden": shrubs.get("hidden_bush006_nodes", 0), "placed": shrubs.get("clipped_shrubs", 0)}
	tick = Trace.finish("world.clipped_shrubs", tick)
	steps["clipped_shrubs"] = Time.get_ticks_msec() - step_started
	if not is_instance_valid(park): return {"status": "cancelled"}

	step_started = Time.get_ticks_msec()
	_progress(park, "Wearing the paths into the ground", 0.08)
	report["worn_paths"] = await load("res://scripts/midori_worn_paths.gd").install_now(park)
	tick = Trace.finish("world.worn_paths", tick)
	steps["worn_paths"] = Time.get_ticks_msec() - step_started
	if not is_instance_valid(park): return {"status": "cancelled"}

	step_started = Time.get_ticks_msec()
	var biome_progress := func(text: String, part: float) -> void: _progress(park, text, 0.16 + 0.76 * part)
	var biomes: Dictionary = await biomes_script.install_now(park, biome_progress)
	report["biomes"] = {"ms": biomes.get("ms", 0), "bake_ms": biomes.get("bake_ms", 0), "builder_ms": biomes.get("builder_ms", {}), "error": biomes.get("error", "")}
	tick = Trace.finish("world.biomes", tick)
	steps["biomes"] = Time.get_ticks_msec() - step_started
	if not is_instance_valid(park): return {"status": "cancelled"}

	step_started = Time.get_ticks_msec()
	_progress(park, "Refreshing park routes", 0.93)
	if navigation != null and navigation.get("ready") == true and navigation.has_method("refresh_changed_colliders"):
		var colliders_after: Dictionary = await Navigation.collider_snapshot(park)
		report["navigation"] = await navigation.refresh_changed_colliders(colliders_before, colliders_after)
	else:
		report["navigation"] = {"skipped": "navigation not ready"}
	tick = Trace.finish("world.navigation_refresh", tick)
	steps["navigation_refresh"] = Time.get_ticks_msec() - step_started
	if not is_instance_valid(park): return {"status": "cancelled"}

	step_started = Time.get_ticks_msec()
	# Its counts go to their own meta (not into this report: the world fingerprint
	# compares the report field by field).
	park.set_meta(RELEASE_META, _release_build_data(park))
	tick = Trace.finish("world.release_build_data", tick)
	steps["release_build_data"] = Time.get_ticks_msec() - step_started

	_progress(park, "Park complete", 1.0)
	report["step_ms"] = steps
	report["ms"] = Time.get_ticks_msec() - started
	report["status"] = "complete"
	park.set_meta(RESULT_META, report)
	return report

static func _progress(park: Node, text: String, part: float) -> void:
	Budget.stage(park, text, lerpf(FROM, TO, clampf(part, 0.0, 1.0)))

## End of the boot build: data that only the build read is dropped (memory, not
## look: no node, buffer, material or setting changes). Every top-level park
## module and every autoload with a release_build_data() method is asked once,
## here, after the last step above that could still read that data; so are the
## static helpers with such a method (clipped shrubs), the navigation's shape
## bounds cache and the biome thinning helper's park walk. Synchronous.
const RELEASE_SCRIPTS := ["res://scripts/midori_clipped_shrubs.gd", "res://scripts/midori_south_street.gd"]
## Modules that are not direct children of the park (the near city hangs under
## the horizon backdrop: midori_horizon.gd creates it).
const RELEASE_PATHS := ["MidoriHorizon/NearCity"]
static func _release_build_data(park: Node3D) -> Dictionary:
	var out := {}
	for module: Node in park.get_children():
		if module.has_method("release_build_data"): out[String(module.name)] = module.release_build_data()
	for path: String in RELEASE_PATHS:
		var module := park.get_node_or_null(path)
		if module != null and module.has_method("release_build_data"): out[path] = module.release_build_data()
	var root := park.get_tree().root
	for autoload: Node in root.get_children():
		if autoload != park and not autoload.is_ancestor_of(park) and autoload.has_method("release_build_data"):
			out[String(autoload.name)] = autoload.release_build_data()
	for path: String in RELEASE_SCRIPTS:
		if not ResourceLoader.exists(path): continue
		var script: Script = load(path)
		for method: Dictionary in script.get_script_method_list():
			if String(method.name) == "release_build_data" and (int(method.flags) & METHOD_FLAG_STATIC) != 0:
				out[path.get_file()] = script.call("release_build_data")
				break
	out["navigation"] = Navigation.release_build_data()
	var thin_all: Script = load("res://scripts/biomes/thin_all.gd")
	thin_all.track(park, false)
	thin_all.forget()
	return out

## Safety net for a raid that reaches HQ without calling run() (an older or
## half-updated ExtractionRun): runs the step once the phase leaves BOOT, as
## the modules used to. Returns at once when run() was called before HQ, when
## there is no raid, or when the park goes away; it never runs anything twice.
static func run_if_skipped(park: Node3D) -> void:
	if not is_instance_valid(park): return
	var tree := park.get_tree()
	while is_instance_valid(park) and park.is_inside_tree():
		if park.get_meta(STARTED_META, false): return
		var raid := park.get_node_or_null("ExtractionRun")
		if raid == null: return
		if int(raid.get("phase")) != 0:
			push_warning("SHINRAI_WORLD_COMPLETE: the raid reached HQ without the world-complete step; running it now")
			await run(park, raid)
			return
		await tree.process_frame
