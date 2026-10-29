extends RefCounted
const Catalog = preload("./creator_asset_catalog.gd")
const Registry = preload("./creator_object_registry.gd")
const Store = preload("./creator_layout_store.gd")
const DEFAULT_PATH := "user://creator_layouts/midori_default.json"
static var _revision_cache := ""

static func world_revision() -> String:
	if not _revision_cache.is_empty(): return _revision_cache
	var source := "creator-world-v3-producer-membership\n"
	var paths: Array[String] = ["res://scenes/shinrai_extraction.tscn", "res://scripts/creator/creator_identity_adapter.gd", "res://scripts/creator/creator_object_registry.gd", "res://scripts/creator/creator_asset_catalog.gd", "res://scripts/creator/creator_asset_catalog.json"]
	# Grass seeds and late trimming affect instance identity as much as the main
	# scene. Include every park producer and cache only for this built-world session.
	for filename: String in DirAccess.get_files_at("res://scripts"):
		if filename.begins_with("midori") and filename.ends_with(".gd"): paths.append("res://scripts/" + filename)
	paths.sort()
	for path: String in paths:
		source += path + ":" + (FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "unavailable") + "\n"
	_revision_cache = source.sha256_text()
	return _revision_cache

static func capture(registry: RefCounted, store: RefCounted, camera: Dictionary = {}) -> Dictionary:
	var additions: Array = []
	for record: Dictionary in registry.get_records():
		if bool(record.get("added", false)) and bool(record.get("visible", false)):
			additions.append({"id": str(record.id), "asset_id": str(record.asset_id), "transform": store.encode_transform(record.transform), "visible": true})
	return {"version": 1, "world_revision": world_revision(), "layout_name": "Midori Park", "overrides": registry.export_overrides(), "additions": additions, "camera": camera}

static func validate_world(layout: Dictionary, registry: RefCounted, catalog: RefCounted) -> Dictionary:
	if str(layout.get("world_revision", "")) != world_revision():
		return {"ok": false, "error": "The park has changed since this layout was saved. Your saved layout is preserved; review it before applying."}
	for override: Dictionary in layout.get("overrides", []):
		var record: Dictionary = registry.get_record(str(override.id))
		if record.is_empty() or bool(record.get("added", false)):
			return {"ok": false, "error": "A saved object is unavailable: " + str(override.id)}
	for added: Dictionary in layout.get("additions", []):
		var id := str(added.id)
		var existing: Dictionary = registry.get_record(id)
		if not id.begins_with("added_") or (not existing.is_empty() and not bool(existing.get("added", false))):
			return {"ok": false, "error": "A saved addition has an invalid or conflicting identity."}
		var entry: Dictionary = catalog.get_entry(str(added.asset_id))
		if entry.is_empty() or not bool(entry.get("placeable", false)):
			return {"ok": false, "error": "A saved asset is unavailable: " + str(added.asset_id)}
	return {"ok": true, "error": ""}

static func apply_layout(layout: Dictionary, world: Node3D, registry: RefCounted, catalog: RefCounted, store: RefCounted) -> Dictionary:
	var valid: Dictionary = store.validate_layout(layout)
	if not bool(valid.get("ok", false)): return valid
	valid = validate_world(layout, registry, catalog)
	if not valid.ok: return valid
	var previous := capture(registry, store)
	var result := _apply_once(layout, world, registry, catalog, store)
	if not bool(result.get("ok", false)) and bool(result.get("changed", false)):
		var rollback := _apply_once(previous, world, registry, catalog, store)
		result["error"] = str(result.get("error", "Layout failed.")) + (" The previous arrangement was restored." if rollback.get("ok", false) else " Restore the last saved layout before continuing.")
	return result

static func _apply_once(layout: Dictionary, world: Node3D, registry: RefCounted, catalog: RefCounted, store: RefCounted) -> Dictionary:
	# Prepare every resource before altering the current scene, so load failures
	# cannot leave a half-applied layout. Factories cannot run gameplay scripts.
	var prepared: Array[Node3D] = []
	for added: Dictionary in layout.additions:
		var instance: Node3D = catalog.instantiate_asset(str(added.asset_id))
		if instance == null:
			for item: Node3D in prepared: item.free()
			return {"ok": false, "error": "Could not load " + str(added.asset_id) + ". The current layout is unchanged."}
		prepared.append(instance)
	reset_world(registry)
	var result: Dictionary = registry.apply_overrides(layout.overrides)
	if result.has("ok") and not result.ok:
		for item: Node3D in prepared: item.free()
		result["changed"] = true
		return result
	for index: int in range(prepared.size()):
		var added: Dictionary = layout.additions[index]
		var node := prepared[index]
		world.add_child(node)
		node.global_transform = store.decode_transform(added.transform)
		if registry.register_added(node, str(added.asset_id), str(added.id)) != str(added.id):
			world.remove_child(node)
			node.queue_free()
			for pending: int in range(index + 1, prepared.size()): prepared[pending].free()
			return {"ok": false, "changed": true, "error": "A saved object could not be registered."}
		registry.set_visible(str(added.id), bool(added.visible))
	return {"ok": true, "error": "", "additions": prepared.size(), "overrides": layout.overrides.size()}

static func reset_world(registry: RefCounted) -> void:
	for record: Dictionary in registry.get_records():
		var id := str(record.id)
		if bool(record.get("added", false)):
			registry.unregister_added(id)
		else:
			if record.get("held", false): registry.set_held(id, false)
			if not record.transform.is_equal_approx(record.original_transform): registry.set_transform(id, record.original_transform)
			if record.visible != record.get("original_visible", true): registry.set_visible(id, bool(record.get("original_visible", true)))

static func apply_saved_to_game(world: Node3D) -> Dictionary:
	if not FileAccess.file_exists(DEFAULT_PATH) and not FileAccess.file_exists(DEFAULT_PATH + ".bak"): return {"ok": true, "applied": false}
	var store := Store.new()
	var loaded: Dictionary = store.load_layout(DEFAULT_PATH)
	if not bool(loaded.get("ok", false)): return loaded
	var registry := Registry.new()
	registry.scan_world(world)
	var catalog := Catalog.new()
	catalog.build_catalog()
	var result := apply_layout(loaded.layout, world, registry, catalog, store)
	result["applied"] = bool(result.get("ok", false))
	if loaded.get("recovered", false): result["warning"] = str(loaded.get("warning", "Recovered the last good layout; the damaged file was preserved."))
	return result
