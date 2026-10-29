extends Node
const Catalog = preload("./creator_asset_catalog.gd")
const Registry = preload("./creator_object_registry.gd")
const Store = preload("./creator_layout_store.gd")
const LayoutRuntime = preload("./creator_layout_runtime.gd")
const REACH := 22.0
const MAX_HISTORY := 100
var catalog := Catalog.new()
var registry := Registry.new()
var store := Store.new()
var park: Node3D
var player: CharacterBody3D
var ui: CanvasLayer
var menu_open := false
var busy := false
var dirty := false
var needs_recovery := false
var initialized := false
var selected_id := ""
var target: Dictionary = {}
var protected_target := false
var held_id := ""
var held_new := false
var held_before: Dictionary = {}
var held_base := Transform3D.IDENTITY
var held_local_bounds := AABB()
var placement_valid := false
var placement_reason := ""
var rotation_degrees := 0.0
var height_offset := 0.0
var grid_snap := false
var grid_size := 0.25
var surface_align := false
var history: Array[Dictionary] = []
var history_cursor := 0
var saved_signature := ""
var layout_path := LayoutRuntime.DEFAULT_PATH
var status_text := ""
var status_severity := "info"
var _status_until := 0
var _tick := 0.0
var _block_left := false
var _block_right := false
var _highlight: MeshInstance3D
var _highlight_material: StandardMaterial3D
var _overlay: CanvasLayer
var _toolbar: HBoxContainer
var _dialog: ConfirmationDialog
var _pending_action := ""
var _reticle: Label
var _coverage: Dictionary = {}

func initialize(world: Node3D, rig: CharacterBody3D) -> void:
	park = world
	player = rig
	# Keep text at native window size: the gameplay project's fixed 1080p canvas
	# otherwise shrinks this compact panel when launched in its default 720p window.
	_sync_window_size()
	if not get_tree().root.size_changed.is_connected(_sync_window_size): get_tree().root.size_changed.connect(_sync_window_size)
	var entries: Array[Dictionary] = catalog.build_catalog()
	_coverage = registry.scan_world(world)
	var ui_script: Script = load(get_script().resource_path.get_base_dir().path_join("creator_mode_ui.gd"))
	if ui_script == null:
		park.creator_error = "The asset menu could not be loaded."
		return
	ui = ui_script.new()
	add_child(ui)
	ui.asset_selected.connect(_select_asset)
	ui.action_requested.connect(_action)
	ui.settings_changed.connect(_settings)
	ui.menu_visibility_requested.connect(_set_menu)
	ui.set_catalog(entries)
	_build_overlay()
	_build_highlight()
	get_tree().auto_accept_quit = false
	initialized = true
	_load_initial()
	_set_menu(false)
	if status_text.is_empty(): _message("Look at an object to pick it up. Press B to choose an asset.")
	_update_ui()
	print("CREATOR_READY ", JSON.stringify({"catalog": entries.size(), "objects": _coverage.get("objects", 0), "protected_batches": _coverage.get("unsupported_batches", []).size(), "warnings": _coverage.get("warnings", []), "profile_loaded": false}))

func _sync_window_size() -> void:
	var window := get_tree().root
	if window.content_scale_size != window.size: window.content_scale_size = window.size

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 45
	add_child(_overlay)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(root)
	_reticle = Label.new()
	_reticle.text = "+"
	_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reticle.add_theme_font_size_override("font_size", 20)
	_reticle.add_theme_color_override("font_color", Color(0.90, 0.97, 0.94, 0.85))
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_reticle)
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_reticle.position -= Vector2(10, 12)
	_reticle.size = Vector2(20, 24)
	_toolbar = HBoxContainer.new()
	_toolbar.position = Vector2(16, 16)
	_toolbar.add_theme_constant_override("separation", 8)
	root.add_child(_toolbar)
	for item: Array in [["Day / night", "day"], ["Original layout", "original"], ["Save recovery copy", "recovery"], ["Exit creator", "exit"]]:
		var button := Button.new()
		button.text = str(item[0])
		button.pressed.connect(_action.bind(str(item[1])))
		_toolbar.add_child(button)
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Unsaved park changes"
	_dialog.ok_button_text = "Save and continue"
	_dialog.add_button("Discard changes", false, "discard")
	_dialog.confirmed.connect(_confirm_save)
	_dialog.custom_action.connect(_confirm_custom)
	_dialog.canceled.connect(_cancel_dialog)
	add_child(_dialog)

func _build_highlight() -> void:
	_highlight = MeshInstance3D.new()
	_highlight.name = "CreatorSelectionOutline"
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_highlight_material = StandardMaterial3D.new()
	_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight_material.albedo_color = Color("85dfc4")
	_highlight_material.no_depth_test = false
	_highlight.material_override = _highlight_material
	park.add_child(_highlight)
	_highlight.hide()

func _process(delta: float) -> void:
	if not initialized: return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): _block_left = false
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): _block_right = false
	_tick += delta
	if _tick < 0.075: return
	_tick = 0.0
	if not menu_open and not busy and not _dialog.visible:
		if held_id.is_empty(): _update_target()
		else: _update_placement()
	if _status_until > 0 and Time.get_ticks_msec() > _status_until:
		status_text = ""
		_status_until = 0
	_update_ui()

func _input(event: InputEvent) -> void:
	# Observe release even when a UI control consumes it. A quick release/press
	# between rendered frames must not leave a newly pressed click suppressed.
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: _block_left = false
		if event.button_index == MOUSE_BUTTON_RIGHT: _block_right = false

func _unhandled_input(event: InputEvent) -> void:
	if not initialized or busy or _dialog.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if event.ctrl_pressed:
			match key:
				KEY_Z: _action("undo")
				KEY_Y: _action("redo")
				KEY_S: _action("save")
				_: return
		elif menu_open:
			if key == KEY_ESCAPE: _set_menu(false)
			else: return
		else:
			match key:
				KEY_B: _set_menu(true)
				KEY_E: _action("pick_up")
				KEY_DELETE: _action("remove")
				KEY_ESCAPE:
					if not held_id.is_empty(): _cancel_placement()
					else: _set_menu(true)
				KEY_F9: _action("exit")
				KEY_N: _action("day")
				KEY_PAGEUP: _settings({"height_offset": height_offset + 0.1})
				KEY_PAGEDOWN: _settings({"height_offset": height_offset - 0.1})
				_: return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not menu_open:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if not _block_left: _action("place")
			MOUSE_BUTTON_RIGHT:
				if not _block_right: _cancel_placement()
			MOUSE_BUTTON_WHEEL_UP: _settings({"rotation_degrees": rotation_degrees + 15.0})
			MOUSE_BUTTON_WHEEL_DOWN: _settings({"rotation_degrees": rotation_degrees - 15.0})
			_: return
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if not initialized: return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_placement()
		_set_menu(true)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_action("exit")

func _exit_tree() -> void:
	if not held_id.is_empty() and is_instance_valid(park): _cancel_placement()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _set_menu(open: bool) -> void:
	menu_open = open
	_block_left = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_block_right = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	player.set_controls_enabled(not open and not busy and not _dialog.visible)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(_toolbar): _toolbar.visible = open
	if is_instance_valid(_reticle): _reticle.visible = not open
	_update_ui()

func _message(message: String, severity: String = "info") -> void:
	status_text = message
	status_severity = severity
	_status_until = Time.get_ticks_msec() + 6000 if severity in ["info", "success"] else 0

func _update_target() -> void:
	var origin: Vector3 = player.camera.global_position
	var direction: Vector3 = -player.camera.global_basis.z
	var hit := _surface_hit(origin, direction, [])
	var distance := REACH
	if not hit.is_empty(): distance = minf(distance, origin.distance_to(hit.position) + 0.02)
	target = registry.ray_pick(origin, direction, distance)
	protected_target = target.is_empty() and not hit.is_empty()
	if target.is_empty():
		_highlight.hide()
	else:
		_draw_bounds(registry.get_bounds(str(target.id)), Color("85dfc4"))

func _surface_hit(origin: Vector3, direction: Vector3, exclude: Array[RID]) -> Dictionary:
	var excluded: Array[RID] = [player.get_rid()]
	excluded.append_array(exclude)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * REACH, 3, excluded)
	query.hit_back_faces = false
	return park.get_world_3d().direct_space_state.intersect_ray(query)

func _update_placement() -> void:
	var record: Dictionary = registry.get_record(held_id)
	if record.is_empty():
		held_id = ""
		placement_valid = false
		_message("That object is no longer available.", "error")
		return
	var excluded: Array[RID] = registry.get_excluded_rids(held_id)
	var hit := _surface_hit(player.camera.global_position, -player.camera.global_basis.z, excluded)
	placement_valid = false
	placement_reason = "Aim at a surface within reach."
	if hit.is_empty():
		_draw_bounds(registry.get_bounds(held_id), Color("ef9b8c"))
		return
	if float(hit.normal.y) < 0.45:
		placement_reason = "Aim at the ground or a gently sloping surface."
		_draw_bounds(registry.get_bounds(held_id), Color("ef9b8c"))
		return
	var basis := Basis(Vector3.UP, deg_to_rad(rotation_degrees)) * held_base.basis
	if surface_align:
		var normal: Vector3 = hit.normal.normalized()
		var tangent := Vector3.FORWARD.slide(normal).normalized()
		if tangent.length_squared() < 0.01: tangent = Vector3.RIGHT.slide(normal).normalized()
		basis = Basis(tangent.cross(normal).normalized(), normal, -tangent) * Basis(Vector3.UP, deg_to_rad(rotation_degrees)) * Basis.from_scale(held_base.basis.get_scale())
	var point: Vector3 = hit.position
	var support_normal: Vector3 = hit.normal.normalized()
	if grid_snap:
		point.x = snappedf(point.x, grid_size)
		point.z = snappedf(point.z, grid_size)
		point.y = hit.position.y - support_normal.dot(point - hit.position) / support_normal.y
		var support_query := PhysicsRayQueryParameters3D.create(point + support_normal * 0.2, point - support_normal * 0.2, 3, excluded + [player.get_rid()])
		var snapped_support := park.get_world_3d().direct_space_state.intersect_ray(support_query)
		if snapped_support.is_empty() or snapped_support.normal.dot(support_normal) < 0.95:
			placement_reason = "The grid point needs a supporting surface."
			_draw_bounds(registry.get_bounds(held_id), Color("ef9b8c"))
			return
	# Project every local bound corner onto the surface normal. This keeps rotated
	# and aligned objects above the support plane, including on gentle slopes.
	var minimum := INF
	for corner: int in range(8):
		minimum = minf(minimum, support_normal.dot(basis * held_local_bounds.get_endpoint(corner)))
	var candidate := Transform3D(basis, point + support_normal * (height_offset - minimum + 0.012))
	if not registry.set_transform(held_id, candidate):
		placement_reason = "This object has changed. Cancel and pick it up again."
		return
	var bounds: AABB = registry.get_bounds(held_id)
	placement_reason = _placement_obstruction(bounds, hit, excluded)
	placement_valid = placement_reason.is_empty()
	_draw_bounds(bounds, Color("85dfc4") if placement_valid else Color("ef9b8c"))

func _placement_obstruction(bounds: AABB, support: Dictionary, excluded: Array[RID]) -> String:
	if not bounds.position.is_finite() or not bounds.size.is_finite(): return "This object has invalid dimensions."
	if bounds.size.length() > 150.0: return "This object is too large to place here."
	var body := AABB(player.global_position + Vector3(-0.38, 0.04, -0.38), Vector3(0.76, 1.68, 0.76))
	if bounds.intersects(body): return "Move a little farther from the object."
	var pose: Transform3D = registry.get_record(held_id).transform
	var extent := held_local_bounds.size * pose.basis.get_scale().abs()
	var size := Vector3(maxf(extent.x - 0.04, 0.01), maxf(extent.y - 0.04, 0.01), maxf(extent.z - 0.04, 0.01))
	var shape := BoxShape3D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(pose.basis.orthonormalized(), pose * held_local_bounds.get_center())
	query.collision_mask = 3
	query.exclude = excluded.duplicate()
	query.exclude.append(player.get_rid())
	# Do not exclude the support body: its other surfaces may obstruct placement.
	if not park.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return "There is not enough clear space here."
	return ""

func _select_asset(asset_id: String) -> void:
	if not held_id.is_empty() and not held_new:
		_message("Place or cancel the held object first.", "warning")
		return
	var entry: Dictionary = catalog.get_entry(asset_id)
	if entry.is_empty() or not bool(entry.get("placeable", false)):
		_message(str(entry.get("reason", "This asset cannot be placed.")), "warning")
		return
	_cancel_placement()
	var instance: Node3D = catalog.instantiate_asset(asset_id)
	if instance == null:
		_message("This asset could not be loaded. Choose another asset.", "error")
		return
	selected_id = asset_id
	park.add_child(instance)
	instance.global_position = player.global_position + -player.global_basis.z * 4.0
	var id := "added_" + Crypto.new().generate_random_bytes(12).hex_encode()
	if registry.register_added(instance, asset_id, id) != id:
		park.remove_child(instance)
		instance.queue_free()
		_message("This asset could not be prepared. Choose another asset.", "error")
		return
	_begin_hold(id, true)
	_set_menu(false)
	_update_placement()

func _begin_hold(id: String, is_new: bool) -> void:
	var record: Dictionary = registry.get_record(id)
	if record.is_empty(): return
	if not registry.set_held(id, true):
		_message("This object has changed. Aim at it again.", "warning")
		return
	held_id = id
	held_new = is_new
	held_before = _snapshot(id)
	held_base = record.transform
	held_local_bounds = registry.get_local_bounds(id)
	rotation_degrees = 0.0
	height_offset = 0.0
	placement_valid = false
	target = {}
	protected_target = false
	_message("Point to a clear surface. Left-click to place; right-click to cancel.")

func _cancel_placement() -> void:
	if held_id.is_empty(): return
	if held_new:
		registry.unregister_added(held_id)
	else:
		registry.set_transform(held_id, store.decode_transform(held_before.transform))
		registry.set_held(held_id, false)
		registry.set_visible(held_id, bool(held_before.visible))
	held_id = ""
	held_before = {}
	held_new = false
	placement_valid = false
	if is_instance_valid(_highlight): _highlight.hide()
	_update_ui()

func _commit_placement() -> void:
	if held_id.is_empty(): return
	if not menu_open: _update_placement()
	if not placement_valid:
		_message(placement_reason, "warning")
		return
	var id := held_id
	var before := held_before.duplicate(true)
	if held_new: before["visible"] = false
	registry.set_held(id, false)
	var after := _snapshot(id)
	var verb := "Placed" if held_new else "Moved"
	held_id = ""
	held_new = false
	held_before = {}
	placement_valid = false
	_push_history(id, before, after, verb)
	_message(verb + " " + str(registry.get_record(id).get("name", "object")) + ". Ctrl+Z to undo.", "success")
	_refresh_world()

func _snapshot(id: String) -> Dictionary:
	var record: Dictionary = registry.get_record(id)
	return {"transform": store.encode_transform(record.transform), "visible": bool(record.visible)} if not record.is_empty() else {}

func _push_history(id: String, before: Dictionary, after: Dictionary, label: String) -> void:
	while history.size() > history_cursor: history.pop_back()
	history.append({"id": id, "before": before, "after": after, "label": label})
	if history.size() > MAX_HISTORY: history.pop_front()
	history_cursor = history.size()
	_prune_unreferenced_additions()
	_update_dirty()

func _prune_unreferenced_additions() -> void:
	var retained: Dictionary = {}
	for command: Dictionary in history: retained[str(command.id)] = true
	for record: Dictionary in registry.get_records():
		if record.added and not record.visible and not retained.has(str(record.id)) and str(record.id) != held_id:
			registry.unregister_added(str(record.id))

func _history_step(redo: bool) -> void:
	_cancel_placement()
	if (redo and history_cursor >= history.size()) or (not redo and history_cursor <= 0): return
	var next_cursor := history_cursor if redo else history_cursor - 1
	var command: Dictionary = history[next_cursor]
	var state: Dictionary = command.after if redo else command.before
	if not registry.set_transform(str(command.id), store.decode_transform(state.transform)) or not registry.set_visible(str(command.id), bool(state.visible)):
		_message("This object is no longer available. Reload a saved layout to continue.", "error")
		return
	history_cursor = next_cursor + 1 if redo else next_cursor
	_update_dirty()
	_refresh_world()
	_message(("Redid: " if redo else "Undid: ") + str(command.label), "success")

func _action(action: String) -> void:
	if busy: return
	match action:
		"pick_up":
			if not held_id.is_empty(): return
			if not menu_open: _update_target()
			if target.is_empty(): return
			_begin_hold(str(target.id), false)
			_set_menu(false)
		"place": _commit_placement()
		"cancel_placement": _cancel_placement()
		"remove":
			if not held_id.is_empty():
				_message("Place or cancel the held object first.", "warning")
				return
			if not menu_open: _update_target()
			if target.is_empty(): return
			var id := str(target.id)
			var before := _snapshot(id)
			if registry.set_visible(id, false):
				_push_history(id, before, _snapshot(id), "Removed " + str(target.get("name", "object")))
				target = {}
				_highlight.hide()
				_refresh_world()
		"undo": _history_step(false)
		"redo": _history_step(true)
		"save": _save()
		"recovery": _save_recovery()
		"reload", "original", "exit": _request_destructive(action)
		"day":
			park.is_night_mode = not park.is_night_mode
			park._apply_time_of_day()
			_refresh_world()
	_update_ui()

func _settings(options: Dictionary) -> void:
	if options.has("rotation_degrees"): rotation_degrees = wrapf(float(options.rotation_degrees), -180, 180)
	if options.has("height_offset"): height_offset = clampf(float(options.height_offset), -2.0, 20.0)
	if options.has("grid_snap"): grid_snap = bool(options.grid_snap)
	if options.has("grid_size"): grid_size = clampf(float(options.grid_size), 0.01, 5.0)
	if options.has("surface_align"): surface_align = bool(options.surface_align)
	if not held_id.is_empty(): _update_placement()
	_update_ui()

func _layout() -> Dictionary:
	return LayoutRuntime.capture(registry, store, player.camera_state())

func _signature() -> String:
	var layout := _layout()
	layout.erase("camera")
	return JSON.stringify(layout).sha256_text()

func _update_dirty() -> void:
	dirty = needs_recovery or _signature() != saved_signature

func _save() -> bool:
	if not held_id.is_empty():
		_message("Place or cancel the held object before saving.", "warning")
		return false
	var result: Dictionary = store.save_layout(layout_path, _layout())
	if not bool(result.get("ok", false)):
		_message(str(result.get("error", "Could not save the layout.")) + " You can save a recovery copy from the menu.", "error")
		return false
	saved_signature = _signature()
	needs_recovery = false
	dirty = false
	_message("Park layout saved.", "success")
	return true

func _save_recovery() -> void:
	if not held_id.is_empty():
		_message("Place or cancel the held object before saving.", "warning")
		return
	var recovery_path := "user://creator_layouts/recovery_%d.json" % Time.get_unix_time_from_system()
	var result: Dictionary = store.save_layout(recovery_path, _layout())
	if bool(result.get("ok", false)):
		_message("Recovery copy saved. The active layout has not been replaced.", "success")
	else: _message(str(result.get("error", "Could not save a recovery copy.")), "error")

func _load_initial() -> void:
	saved_signature = _signature()
	if not FileAccess.file_exists(layout_path) and not FileAccess.file_exists(layout_path + ".bak"): return
	_reload()

func _reload() -> bool:
	var loaded: Dictionary = store.load_layout(layout_path)
	if not bool(loaded.get("ok", false)):
		_message(str(loaded.get("error", "Could not read the saved layout.")), "error")
		return false
	var applied: Dictionary = LayoutRuntime.apply_layout(loaded.layout, park, registry, catalog, store)
	if not bool(applied.get("ok", false)):
		_message(str(applied.get("error", "Could not restore the layout.")), "error")
		return false
	history.clear()
	history_cursor = 0
	player.restore_camera(loaded.layout.get("camera", {}))
	saved_signature = _signature()
	needs_recovery = bool(loaded.get("recovered", false))
	dirty = needs_recovery
	_refresh_world()
	var warning := str(loaded.get("warning", ""))
	_message(warning if not warning.is_empty() else "Saved layout restored.", "warning" if dirty else "success")
	return true

func _request_destructive(action: String) -> void:
	_cancel_placement()
	if action == "original" or dirty:
		_pending_action = action
		_dialog.title = "Restore original park?" if action == "original" else "Unsaved park changes"
		_dialog.dialog_text = "Choose what to do with your current arrangement before continuing."
		_set_menu(true)
		player.set_controls_enabled(false)
		_dialog.popup_centered(Vector2i(480, 180))
	else: _perform(action)

func _confirm_save() -> void:
	if _save():
		var action := _pending_action
		_pending_action = ""
		_perform(action)
	else:
		_pending_action = ""
		_set_menu(true)

func _confirm_custom(action: StringName) -> void:
	if action != &"discard": return
	_dialog.hide()
	var requested := _pending_action
	_pending_action = ""
	_perform(requested)

func _cancel_dialog() -> void:
	_pending_action = ""
	_set_menu(true)

func _perform(action: String) -> void:
	match action:
		"reload": _reload()
		"original":
			LayoutRuntime.reset_world(registry)
			history.clear()
			history_cursor = 0
			_update_dirty()
			_refresh_world()
			_message("Original park restored. Save to keep this layout.", "success")
		"exit":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().quit()
	_set_menu(true)

func _refresh_world() -> void:
	if registry.has_method("sync_night_effects"):
		registry.sync_night_effects(park.get("is_night_mode") == true)
	# Creator uses original geometry, so no distance/shadow copy can remain stale.
	# A normal deployment applies saved overrides before nav/renderer construction.
	for probe: Node in park.find_children("*", "ReflectionProbe", true, false):
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
	if park.has_method("_queue_reflection_refresh"): park.call("_queue_reflection_refresh")

func _update_ui() -> void:
	if not is_instance_valid(ui): return
	var held: Dictionary = registry.get_record(held_id) if not held_id.is_empty() else {}
	var entry: Dictionary = catalog.get_entry(selected_id)
	ui.set_creator_state({"active": true, "menu_open": menu_open, "selected_asset_id": selected_id,
		"selected_asset_name": str(entry.get("name", "")), "target_name": str(target.get("name", "Fixed scenery" if protected_target else "")),
		"target_editable": not target.is_empty(), "target_reason": "This surface is part of the fixed park." if protected_target else "", "placement_valid": placement_valid,
		"placement_reason": placement_reason, "can_undo": history_cursor > 0, "can_redo": history_cursor < history.size(),
		"dirty": dirty, "busy": busy, "rotation_degrees": rotation_degrees, "height_offset": height_offset,
		"grid_snap": grid_snap, "grid_size": grid_size, "surface_align": surface_align, "layout_name": "Midori Park",
		"status_text": status_text, "status_severity": status_severity,
		"interaction_mode": ("new_preview" if held_new else "holding") if not held_id.is_empty() else "browse",
		"held_object_name": str(held.get("name", "")), "can_pick_up": held_id.is_empty() and not target.is_empty(),
		"can_cancel_placement": not held_id.is_empty(), "can_change_asset": held_id.is_empty() or held_new,
		"primary_action_label": "Place here" if not held_id.is_empty() else "Pick up",
		"primary_action_hint": "Left-click: place" if not held_id.is_empty() else "E: pick up",
		"bindings": {"place": "LMB", "pick_up": "E", "cancel_placement": "RMB / Esc", "remove": "Delete", "menu": "B", "undo": "Ctrl+Z", "redo": "Ctrl+Y", "save": "Ctrl+S", "exit": "F9"}})

func _draw_bounds(bounds: AABB, color: Color) -> void:
	if bounds.size.length_squared() < 0.000001:
		_highlight.hide()
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var p := bounds.position - Vector3.ONE * 0.015
	var s := bounds.size + Vector3.ONE * 0.03
	var points: Array[Vector3] = []
	for x: int in range(2):
		for y: int in range(2):
			for z: int in range(2): points.append(p + s * Vector3(x, y, z))
	for pair: Vector2i in [Vector2i(0,1),Vector2i(0,2),Vector2i(0,4),Vector2i(1,3),Vector2i(1,5),Vector2i(2,3),Vector2i(2,6),Vector2i(3,7),Vector2i(4,5),Vector2i(4,6),Vector2i(5,7),Vector2i(6,7)]:
		mesh.surface_add_vertex(points[pair.x])
		mesh.surface_add_vertex(points[pair.y])
	mesh.surface_end()
	_highlight.mesh = mesh
	_highlight.global_transform = Transform3D.IDENTITY
	_highlight_material.albedo_color = color
	_highlight.show()
