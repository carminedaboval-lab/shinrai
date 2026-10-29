extends Node
## Apply a committed arrangement before gameplay navigation/render caches exist.
const Runtime = preload("./creator_layout_runtime.gd")
const Registry = preload("./creator_object_registry.gd")
const Catalog = preload("./creator_asset_catalog.gd")
const Store = preload("./creator_layout_store.gd")
var registry: RefCounted
var park: Node3D
var last_night := false

static func layout_exists(path: String = Runtime.DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")

static func prepare_world(world: Node3D, path: String = Runtime.DEFAULT_PATH) -> void:
	if not layout_exists(path): return
	world.set_meta("creator_layout_path", path)
	var identity := world.get_node_or_null("Midori2050Identity")
	if identity != null:
		var adapter: Script = load("res://scripts/creator/creator_identity_adapter.gd")
		if adapter == null or FileAccess.get_sha256("res://scripts/midori_2050_identity.gd") != str(adapter.get_script_constant_map().get("COMPATIBILITY_SOURCE_SHA256", "")):
			world.set_meta("creator_preparation_error", "The park furniture has changed. Your layout is preserved; update Creator Mode before applying it.")
			return
		identity.set_script(adapter)

static func apply_before_navigation(world: Node3D) -> Dictionary:
	if world.has_meta("creator_preparation_error"): return {"ok": false, "error": str(world.get_meta("creator_preparation_error"))}
	var path := str(world.get_meta("creator_layout_path", Runtime.DEFAULT_PATH))
	if not layout_exists(path): return {"ok": true, "applied": false}
	var deadline := Time.get_ticks_msec() + 150000
	var producer_check = preload("res://scripts/midori_distance_boot.gd")
	while true:
		var pending: Array[String] = producer_check.pending_producers(world)
		if pending.is_empty(): break
		if Time.get_ticks_msec() >= deadline: return {"ok": false, "error": "Your layout was preserved, but the park was not ready to apply it."}
		await world.get_tree().process_frame
	await world.get_tree().physics_frame
	await world.get_tree().physics_frame
	var store := Store.new()
	var loaded: Dictionary = store.load_layout(path)
	if not loaded.get("ok", false): return loaded
	var object_registry := Registry.new()
	object_registry.scan_world(world)
	var catalog := Catalog.new()
	catalog.build_catalog()
	var result := Runtime.apply_layout(loaded.layout, world, object_registry, catalog, store)
	result["applied"] = bool(result.get("ok", false))
	if result.applied:
		# Gameplay needs at least one visible relay prop to remain completable.
		var relay_available := false
		for prop: Node3D in world.find_children("*", "Node3D", true, false):
			if (str(prop.name).begins_with("JapanesePathLamp_") or str(prop.name) in ["EmeraldHaloLamp_01", "EmeraldHaloLamp_05", "EmeraldHaloLamp_10"]) and prop.is_visible_in_tree():
				relay_available = true
				break
		if not relay_available:
			Runtime.reset_world(object_registry)
			await world.get_tree().physics_frame
			await world.get_tree().physics_frame
			return {"ok": false, "applied": false, "error": "This arrangement removes every mission relay. It is kept for Creator Mode; gameplay will use the original park."}
		var service := load("res://scripts/creator/creator_game_integration.gd").new() as Node
		service.name = "CreatorLayoutLighting"
		service.park = world
		service.registry = object_registry
		world.add_child(service)
		service._sync()
	if loaded.get("recovered", false): result["warning"] = str(loaded.get("warning", "Recovered the last good layout. The damaged file is preserved."))
	await world.get_tree().physics_frame
	await world.get_tree().physics_frame
	return result

static func show_report(raid: Node, report: Dictionary) -> void:
	var message := str(report.get("error", "")) if not report.get("ok", false) else str(report.get("warning", ""))
	if message.is_empty(): return
	var popup := AcceptDialog.new()
	popup.title = "Saved park layout"
	popup.dialog_text = message
	popup.ok_button_text = "Continue"
	raid.add_child(popup)
	popup.popup_centered(Vector2i(580, 200))
	popup.confirmed.connect(popup.queue_free)

func _process(_delta: float) -> void:
	if is_instance_valid(park) and (park.get("is_night_mode") == true) != last_night: _sync()

func _sync() -> void:
	last_night = park.get("is_night_mode") == true
	registry.sync_night_effects(last_night)
