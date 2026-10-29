extends SceneTree

const Run = preload("res://scripts/extraction_run.gd")
const Hud = preload("res://scripts/extraction_hud.gd")
const Inventory = preload("res://scripts/extraction_inventory.gd")
var checks := 0
var failures: Array[String] = []
var actions: Array[String] = []
var run: Node
var hud: CanvasLayer

class FakePlayer extends CharacterBody3D:
	var health := 72.0
	var ammo := 19
	var reserve := 80

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	root.size = Vector2i(1920, 1080)
	run = Run.new()
	run.player = FakePlayer.new()
	run.profile.save_path = "user://inventory_ui_test.json"
	run.profile.data.credits = 1000
	run.profile.data.stash = {"circuit": 3, "optics": 1, "archive": 2}
	run.phase = Run.Phase.HQ
	hud = Hud.new()
	run.hud = hud
	root.add_child(hud)
	hud.action_requested.connect(func(action: String) -> void: actions.append(action))
	hud.action_requested.connect(run._on_action)
	run.open_inventory()
	await process_frame
	await process_frame
	var panel = _panel()
	_check(panel != null and panel.in_hq, "actual HUD builds HQ inventory")
	var bounds: Rect2 = panel.get_global_rect()
	print("INVENTORY_UI_LAYOUT: logical viewport=%s, panel=%s" % [root.size, bounds])
	_check(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= 1920 and bounds.end.y <= 1080, "inventory panel fits actual 1920x1080 logical viewport")
	_check(panel.entries.size() == 3 and panel.entries[0].quantity == 3 and panel.entries[2].quantity == 2, "HQ tiles represent grouped persisted quantities")
	panel.tiles[2].pressed.emit()
	_check(panel.selected == 2, "tile press selects archive details")
	var sell_one := _button(panel.detail, "SELL ONE")
	_check(sell_one != null and not sell_one.disabled, "selected details expose enabled individual sale")
	if sell_one != null:
		sell_one.pressed.emit()
	_check(actions.back() == "sell_item:archive:1" and run.profile.data.stash.archive == 1 and run.profile.data.credits == 1220, "HUD sale routes selected id and quantity into profile transaction")
	panel = _panel()
	_check(panel.entries[panel.selected].id == "archive", "sale refresh restores selected item")
	panel.tiles[0].pressed.emit()
	var sell_all := _button(panel.detail, "SELL ×3")
	_check(sell_all != null, "stacked details expose exact quantity sale")
	if sell_all != null:
		sell_all.pressed.emit()
	_check(actions.back() == "sell_item:circuit:3" and not run.profile.data.stash.has("circuit") and run.profile.data.credits == 1475, "sell-stack routes precise item and amount")
	panel = _panel()
	panel.search.text = "OPTICAL"
	panel.search.text_changed.emit(panel.search.text)
	_check(panel.tiles[0].visible and not panel.tiles[1].visible and panel.empty_label.text == "1 matching item", "search signal filters case-insensitively")
	panel.search.text_changed.emit("   encrypted   ")
	_check(not panel.tiles[0].visible and panel.tiles[1].visible, "search trims query whitespace")
	panel.search.text_changed.emit("unfindable")
	_check(not panel.tiles[0].visible and not panel.tiles[1].visible and panel.empty_label.text == "0 matching items", "unmatched search presents empty result count")
	panel.search.text_changed.emit("")
	_check(panel.tiles[0].visible and panel.tiles[1].visible, "clearing search restores tiles")
	var stash_before: Dictionary = run.profile.data.stash.duplicate(true)
	_button(panel, "SORT").pressed.emit()
	_check(panel.entries[0].id == "archive" and panel.entries[1].id == "optics", "HQ sort reorders visible stash tiles alphabetically")
	_check(run.profile.data.stash == stash_before, "HQ local sort does not mutate stash quantities")
	run.profile.last_error = "Test save error"
	hud.show_inventory(run)
	panel = _panel()
	_check(_button(panel.detail, "SELL ONE").disabled, "save failure disables sale control")
	_check(_button(panel, "EXTRA MEDKIT").disabled and _button(panel, "EXPAND CARGO").disabled, "save failure disables loadout purchases")
	run.profile.last_error = ""
	run.phase = Run.Phase.PAUSED
	run.inventory_open = true
	run.medkits = 2
	run.bag.assign([Run.ITEMS[3].duplicate(), Run.ITEMS[0].duplicate(), Run.ITEMS[1].duplicate(), Run.ITEMS[0].duplicate()])
	hud.show_inventory(run)
	panel = _panel()
	_check(not panel.in_hq and panel.entries.size() == 4 and panel.grid.get_child_count() == run.capacity(), "field UI presents every occupied and empty capacity slot")
	panel.search.text_changed.emit("optical")
	_check(panel.tiles[2].visible and not panel.tiles[0].visible, "field search preserves source tile identities")
	panel.tiles[2].pressed.emit()
	var bag_before: Array = run.bag.duplicate(true)
	var action_count := actions.size()
	_button(panel.detail, "DISCARD ITEM").pressed.emit()
	_check(actions.size() == action_count and run.bag == bag_before, "discard first press opens confirmation without mutating cargo")
	_check(_button(panel.detail, "KEEP ITEM") != null and _button(panel.detail, "CONFIRM DISCARD") != null, "discard confirmation exposes keep and confirm")
	_button(panel.detail, "KEEP ITEM").pressed.emit()
	_check(actions.size() == action_count and run.bag == bag_before and _button(panel.detail, "DISCARD ITEM") != null, "keep cancels discard without changing cargo")
	_button(panel.detail, "DISCARD ITEM").pressed.emit()
	_button(panel.detail, "CONFIRM DISCARD").pressed.emit()
	_check(actions.back() == "discard_item:2" and run.bag.size() == 3, "filtered discard routes original cargo slot index")
	_check(run.bag[0].id == "archive" and run.bag[1].id == "circuit" and run.bag[2].id == "circuit", "filtered indexed discard preserves all other cargo")
	panel = _panel()
	_check(panel.entries.size() == 3 and panel.grid.get_child_count() == run.capacity(), "discard refresh updates occupied and empty slots")
	_button(panel, "SORT").pressed.emit()
	_check(actions.back() == "sort_cargo" and run.bag[0].id == "circuit" and run.bag[1].id == "circuit" and run.bag[2].id == "archive", "field sort action updates actual cargo order")
	panel = _panel()
	_check(_button(panel, "FIELD MAP") != null and _button(panel, "RESUME RAID") != null, "field inventory exposes return actions")
	run.phase = Run.Phase.HQ
	run.profile.data.stash = {"circuit": 3, "optics": 2, "cell": 1, "archive": 4, "future_item": 5}
	hud.show_inventory(run)
	await process_frame
	await process_frame
	panel = _panel()
	_check_tile_price_bounds(panel)
	run.phase = Run.Phase.HQ
	run.profile.data.stash = {"future_item": 5}
	hud.show_inventory(run)
	panel = _panel()
	_check(panel.entries.size() == 1 and panel.entries[0].id == "future_item" and panel.entries[0].quantity == 5, "unknown banked content remains visible in stash")
	_check(_button(panel.detail, "SELL ONE").disabled, "unknown content has no unsupported sale action")
	# Finish on empty HQ inventory to cover keyboard focus and empty details.
	run.phase = Run.Phase.HQ
	run.profile.data.stash.clear()
	hud.show_inventory(run)
	panel = _panel()
	await process_frame
	_check(panel.entries.is_empty() and panel.selected == -1 and panel.tiles.is_empty(), "empty stash creates no fabricated items")
	_check(panel.search.has_focus(), "empty inventory focuses usable search input")
	_check(_button(panel.detail, "SELL ONE") == null, "empty details expose no invalid item transaction")
	hud.queue_free()
	run.player.free()
	run.free()
	await process_frame
	print("INVENTORY_UI_TEST_RESULT: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures:
		print("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _panel():
	for child: Node in hud.panel_content.get_children():
		if child is Inventory:
			return child
	return null

func _button(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix):
		return node
	for child: Node in node.get_children():
		var candidate := _button(child, prefix)
		if candidate != null:
			return candidate
	return null

func _check_tile_price_bounds(panel: Control) -> void:
	for index: int in range(panel.tiles.size()):
		var tile: Button = panel.tiles[index]
		if not tile.is_visible_in_tree():
			continue
		var value: int = panel.entries[index].value
		var price := _label_with_text(tile, "%d CR" % value)
		_check(price != null, "tile exposes price label for " + str(panel.entries[index].id))
		if price == null:
			continue
		var tile_rect := tile.get_global_rect().grow(0.5)
		var price_rect := price.get_global_rect()
		_check(tile_rect.encloses(price_rect), "tile contains full price label after layout for " + str(panel.entries[index].id))
		print("INVENTORY_TILE_LAYOUT: %s tile=%s price=%s" % [panel.entries[index].id, tile.get_global_rect(), price_rect])

func _label_with_text(node: Node, text: String) -> Label:
	if node is Label and node.text == text:
		return node
	for child: Node in node.get_children():
		var candidate := _label_with_text(child, text)
		if candidate != null:
			return candidate
	return null
