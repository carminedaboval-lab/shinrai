extends Control
## Operations (HQ main menu) in the field inventory's visual language.
## Used by the early boot menu (source = shinrai_menu_source.gd) and by
## ExtractionHud.show_hq (source = ExtractionRun). The source provides
##   menu_profile() -> Dictionary, menu_world_ready() -> bool,
##   menu_can(action) -> bool, menu_night() -> bool, menu_high_quality() -> bool,
##   menu_last_error() -> String
## and receives the menu's action strings through action_requested. Sources
## without those methods (an ExtractionRun built before FLOW's additions, test
## fakes) are read through their profile/navigation fields instead.
## refresh() updates every label and button in place and keeps focus; the
## DEPLOY label and progress poll ShinraiLoadState while visible.

signal action_requested(action: String)

const Kit = preload("res://scripts/ui/shinrai_menu_kit.gd")
const LoadoutSummary = preload("res://scripts/extraction_loadout_summary.gd")
const NOT_READY := "Opens when the park is ready."
const POLL_SECONDS := 0.2

## False when a host (the HUD) already draws the blurred backdrop.
var with_backdrop := true
## Margins around the screen when the menu owns the whole viewport.
var outer_margin := Vector2(12, 14)
var source: Object
var screen: Kit.MenuScreen
var backdrop: Kit.Backdrop
var deploy_button: Button
var deploy_bar: ProgressBar
var deploy_status: Label
var time_choice: Kit.Segmented
var graphics_choice: Kit.Segmented
var credits_label: Label
var credits_tile: Kit.StatTile
var stash_tile: Kit.StatTile
var extracts_tile: Kit.StatTile
var weapon_title: Label
var weapon_detail: Label
var inventory_button: Button
var inventory_note: Label
var notes: VBoxContainer
var market: Dictionary = {}
var settings_button: Button
var quit_button: Button
var _deploy_action := "deploy"
var _poll := 0.0
var _last_deploy_text := ""

func configure(menu_source: Object) -> void:
	source = menu_source
	name = "OperationsMenu"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not get_parent() is Container:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var frame: Control = self
	if with_backdrop:
		backdrop = Kit.backdrop(self, 3.0, 0.55, 0.50)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", int(outer_margin.x))
		margin.add_theme_constant_override("margin_right", int(outer_margin.x))
		margin.add_theme_constant_override("margin_top", int(outer_margin.y))
		margin.add_theme_constant_override("margin_bottom", int(outer_margin.y))
		add_child(margin)
		frame = margin
	_build(frame)
	refresh()
	if is_inside_tree():
		deploy_button.call_deferred("grab_focus")
	else:
		ready.connect(func() -> void: deploy_button.grab_focus(), CONNECT_ONE_SHOT)
	set_process(true)

func _build(frame: Control) -> void:
	screen = Kit.screen(frame, "OPERATIONS", "HQ")
	Kit.status_text(screen, "HQ  ·  SECURED")
	credits_label = Kit.status_text(screen, "0 CR", Kit.AMBER, 17)
	settings_button = Kit.bar_button(screen, "SETTINGS")
	settings_button.pressed.connect(func() -> void: screen.open_side())
	quit_button = Kit.bar_button(screen, "QUIT TO DESKTOP")
	quit_button.pressed.connect(func() -> void: _emit("quit_confirm"))
	Kit.caption(screen, "OPERATIONS  /  Starter kit is free. Carried items are lost on death.", "Banked stash and upgrades stay at HQ between runs.")
	# No "Back" on the root menu (nothing to go back to); the settings drawer adds
	# its own "Esc / B  Close settings" hint while open.
	Kit.key_hints(screen, [["Enter / A", "Select"], ["Arrows / Dpad", "Navigate"]])
	# Left: contract + deployment.
	var left := Kit.column(screen.body, 640, 8)
	Kit.section(left, "CONTRACT")
	var contract := Kit.card(left, "OPERATION 01   ·   MIDORI PARK", 18, 10)
	Kit.text(contract, "THE QUIET EXIT", 50, Color("f3eee2"), true)
	Kit.wrapped(Kit.text(contract, "Recover the park's telemetry. Search for salvage. Get out alive. One relay opens extraction. All three earn the full contract bonus.", 18, Kit.PAPER), 560)
	var tags := Kit.hbox(contract, 6)
	for tag: String in ["UP TO 2 HOURS", "SOLO PvE", "BASE CARGO 6–10 SLOTS"]:
		Kit.chip(tags, tag, 14, Kit.MUTED)
	# Deployment sits at the foot of the column, where the eye ends up.
	Kit.spacer(left, 16, true)
	Kit.section(left, "DEPLOYMENT")
	var deploy := Kit.card(left, "INSERTION WINDOW", 18, 10)
	time_choice = Kit.segmented(deploy, ["GOLDEN HOUR", "NIGHT"], 0, func(_index: int) -> void: _emit("time"), 17)
	deploy_button = Kit.primary_button(deploy, "DEPLOY", 26)
	deploy_button.name = "DeployButton"
	deploy_button.custom_minimum_size.y = 72
	deploy_button.pressed.connect(func() -> void: _emit(_deploy_action))
	deploy_bar = Kit.progress_bar(deploy, 4)
	deploy_status = Kit.text(deploy, "", 14, Kit.DIM)
	deploy_status.clip_text = true
	notes = Kit.vbox(left, 4)
	# Middle: the scene stays visible, as the operator does in the inventory.
	Kit.spacer(screen.body, 0, true).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Right: loadout, record, market.
	var right := Kit.column(screen.body, 580, 8)
	Kit.section(right, "LOADOUT")
	var kit_card := Kit.card(right, "FIELD KIT", 16, 6)
	weapon_title = Kit.text(kit_card, "", 22, Kit.PAPER, true)
	weapon_detail = Kit.wrapped(Kit.text(kit_card, "", 15, Kit.MUTED), 520)
	Kit.spacer(kit_card, 4)
	inventory_button = Kit.secondary_button(kit_card, "LOADOUT & INVENTORY", 18)
	inventory_button.name = "InventoryButton"
	inventory_button.pressed.connect(func() -> void: _emit("inventory"))
	inventory_note = Kit.text(kit_card, NOT_READY, 13, Kit.DIM)
	Kit.section(right, "RECORD", 16)
	var tiles := Kit.hbox(right, 8)
	credits_tile = Kit.stat_tile(tiles, "CREDITS", "0", "CR", Kit.AMBER)
	stash_tile = Kit.stat_tile(tiles, "STASH", "0", "items")
	extracts_tile = Kit.stat_tile(tiles, "EXTRACTS", "0", "/ 0")
	Kit.spacer(right, 16, true)
	Kit.section(right, "MARKET")
	var row := Kit.hbox(right, 8)
	for spec: Array in [["sell", "SELL STASH"], ["medkit", "EXTRA MEDKIT"], ["upgrade", "CARGO UPGRADE"]]:
		market[spec[0]] = _market_tile(row, str(spec[0]), str(spec[1]))
	# Settings drawer: graphics + controls help.
	var drawer := Kit.side_panel(screen, "SETTINGS", 600)
	graphics_choice = Kit.settings_contents(drawer, false, func() -> void: _emit("graphics"))

class MarketTile extends Button:
	var chrome: Control
	var price: Label
	var detail: Label

func _market_tile(parent: Node, action: String, title: String) -> MarketTile:
	var tile := MarketTile.new()
	tile.name = "Market_" + action
	tile.focus_mode = Control.FOCUS_ALL
	tile.custom_minimum_size = Vector2(0, 124)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	tile.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	tile.add_theme_stylebox_override("hover", Kit.style(Color("748e902e"), Kit.TEAL, 0))
	tile.add_theme_stylebox_override("pressed", Kit.style(Color("8a7d5a40"), Kit.AMBER, 0))
	tile.add_theme_stylebox_override("focus", Kit.style(Color.TRANSPARENT, Kit.PAPER, 0, 2))
	parent.add_child(tile)
	var chrome := Kit.CardChrome.new()
	chrome.tab_text = title
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.show_behind_parent = true
	tile.add_child(chrome)
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tile.chrome = chrome
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	tile.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_right = -8
	box.offset_top = 28
	box.offset_bottom = -8
	tile.price = Kit.text(box, "", 24, Kit.PAPER, true)
	tile.detail = Kit.text(box, "", 13, Kit.DIM)
	tile.detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.detail.max_lines_visible = 2
	tile.pressed.connect(func() -> void: _emit(action))
	return tile

# ---------------------------------------------------------------- source access

func _profile() -> Dictionary:
	if source == null: return {}
	if source.has_method("menu_profile"): return source.call("menu_profile")
	var profile: Variant = source.get("profile")
	if profile is Object and (profile as Object).get("data") is Dictionary: return (profile as Object).get("data")
	return {}

func world_ready() -> bool:
	if source == null: return false
	if source.has_method("menu_world_ready"): return bool(source.call("menu_world_ready"))
	if source.has_method("world_ready"): return bool(source.call("world_ready"))
	var navigation: Variant = source.get("navigation")
	return navigation is Object and _truthy((navigation as Object).get("ready"))

func _can(action: String) -> bool:
	if source != null and source.has_method("menu_can"): return bool(source.call("menu_can", action))
	if action in ["inventory"]: return world_ready() or _phase_is_hq()
	return true

func _phase_is_hq() -> bool:
	var phase: Variant = source.get("phase") if source != null else null
	return phase != null and int(phase) == 1

func _night() -> bool:
	if source == null: return false
	if source.has_method("menu_night"): return bool(source.call("menu_night"))
	return _truthy(source.get("night_deployment"))

func _high_quality() -> bool:
	if source == null: return false
	if source.has_method("menu_high_quality"): return bool(source.call("menu_high_quality"))
	var park: Variant = source.get_parent() if source is Node else null
	return park is Object and _truthy((park as Object).get("high_render_quality"))

func _last_error() -> String:
	if source == null: return ""
	if source.has_method("menu_last_error"): return str(source.call("menu_last_error"))
	var profile: Variant = source.get("profile")
	return str((profile as Object).get("last_error")) if profile is Object and (profile as Object).get("last_error") != null else ""

func _retry_deploy() -> bool:
	if source == null: return false
	if source.has_method("can_retry_deployment_save"): return bool(source.call("can_retry_deployment_save"))
	return false

func _truthy(value: Variant) -> bool:
	return value is bool and value

func _prices() -> Dictionary:
	var prices: Variant = source.get("PRICES") if source != null else null
	return prices if prices is Dictionary else {}

# ---------------------------------------------------------------------- refresh

func refresh() -> void:
	if screen == null: return
	var d := _profile()
	var error := _last_error()
	var credits := int(d.get("credits", 0))
	var stash: Dictionary = d.get("stash", {}) if d.get("stash", {}) is Dictionary else {}
	var stash_count := 0
	for amount: Variant in stash.values(): stash_count += int(amount)
	credits_label.text = "%s CR" % Kit.number(credits)
	credits_tile.set_value(Kit.number(credits), "CR", Kit.AMBER)
	stash_tile.set_value(str(stash_count), "item" if stash_count == 1 else "items")
	extracts_tile.set_value(str(int(d.get("extracts", 0))), "/ %d runs" % int(d.get("runs", 0)))
	# Loadout.
	var summary := LoadoutSummary.describe(d) if not d.is_empty() else "LOADOUT  —\nProfile loading."
	var lines := summary.split("\n")
	weapon_title.text = lines[0].trim_prefix("LOADOUT").strip_edges()
	weapon_detail.text = lines[1] if lines.size() > 1 else ""
	inventory_button.text = "LOADOUT & INVENTORY   ·   %d banked item%s" % [stash_count, "" if stash_count == 1 else "s"]
	var inventory_open := _can("inventory")
	inventory_button.disabled = not inventory_open
	inventory_button.tooltip_text = "" if inventory_open else NOT_READY
	inventory_note.visible = not inventory_open
	# Time of day.
	time_choice.select(1 if _night() else 0)
	var time_ok := _can("time")
	for button: Button in time_choice.buttons: button.disabled = not time_ok
	graphics_choice.select(1 if _high_quality() else 0)
	var graphics_ok := _can("graphics")
	for button: Button in graphics_choice.buttons: button.disabled = not graphics_ok
	# Market.
	var action_error := error
	if action_error.is_empty() and bool(d.get("active_run", false)):
		action_error = "Available after the current run ends."
	var sell_value := 0
	var prices := _prices()
	for item_id: Variant in stash:
		var price := int(prices.get(str(item_id), 0))
		if price > 0: sell_value += int(stash[item_id]) * price
	var level := int(d.get("pack_level", 0))
	var upgrade_price := 450 * (level + 1)
	var prepared := bool(d.get("prepared_medkit", false))
	var sell_reason := action_error
	if sell_reason.is_empty() and not _can("sell"): sell_reason = NOT_READY
	if sell_reason.is_empty() and sell_value <= 0 and not prices.is_empty(): sell_reason = "No sellable items in your stash."
	_set_market("sell", "+%s CR" % Kit.number(sell_value) if sell_value > 0 else "—", sell_reason if not sell_reason.is_empty() else "Priced items only; the rest stay banked.", sell_reason)
	var medkit_reason := action_error
	if medkit_reason.is_empty() and not _can("medkit"): medkit_reason = NOT_READY
	if medkit_reason.is_empty():
		if prepared: medkit_reason = "Prepared for the next deployment."
		elif credits < 120: medkit_reason = "Need 120 CR; you have %s." % Kit.number(credits)
	_set_market("medkit", "READY" if prepared else "120 CR", medkit_reason if not medkit_reason.is_empty() else "One extra medkit for the next deployment.", medkit_reason)
	var upgrade_reason := action_error
	if upgrade_reason.is_empty() and not _can("upgrade"): upgrade_reason = NOT_READY
	if upgrade_reason.is_empty():
		if level >= 2: upgrade_reason = "Base cargo capacity is fully upgraded."
		elif credits < upgrade_price: upgrade_reason = "Need %s CR; you have %s." % [Kit.number(upgrade_price), Kit.number(credits)]
	_set_market("upgrade", "MAX" if level >= 2 else "%s CR" % Kit.number(upgrade_price), upgrade_reason if not upgrade_reason.is_empty() else "Adds 2 base cargo slots.", upgrade_reason)
	# Notes under the deploy card.
	for child: Node in notes.get_children():
		notes.remove_child(child)
		child.queue_free()
	var profile_object: Variant = source.get("profile") if source != null else null
	if profile_object is Object and _truthy((profile_object as Object).get("recovered_interrupted_run")):
		Kit.wrapped(Kit.text(notes, "Last run was interrupted. Unbanked cargo was lost; your stash is safe.", 15, Kit.AMBER), 620)
	if source != null and "enemy_visual" in source and source.get("enemy_visual") == null and world_ready():
		Kit.wrapped(Kit.text(notes, "RECON BUILD: K17 model pending. Hostile spawning is disabled.", 15, Kit.AMBER), 620)
	if not error.is_empty():
		Kit.wrapped(Kit.text(notes, error, 15, Kit.DANGER), 620)
	_refresh_deploy()

func _set_market(action: String, price_text: String, detail_text: String, reason: String) -> void:
	var tile: MarketTile = market[action]
	tile.price.text = price_text
	tile.detail.text = detail_text
	tile.disabled = not reason.is_empty()
	tile.tooltip_text = detail_text
	tile.modulate = Color(1, 1, 1, 0.62) if tile.disabled else Color.WHITE
	tile.price.add_theme_color_override("font_color", Kit.MUTED if tile.disabled else (Kit.AMBER if action != "sell" else Kit.TEAL))

func _refresh_deploy() -> void:
	var error := _last_error()
	var retry := _retry_deploy()
	var ready_now := world_ready()
	var fraction := clampf(float(Kit.load_value("fraction", 0.0)), 0.0, 1.0)
	var stage := str(Kit.load_value("stage", ""))
	var label := ""
	if retry:
		_deploy_action = "retry_deploy"
		label = "RETRY SAVE & DEPLOY"
	else:
		_deploy_action = "deploy"
		if ready_now:
			label = "DEPLOY   ·   " + ("NIGHT" if _night() else "GOLDEN HOUR")
		elif source != null and _truthy(source.get("deploy_queued")):
			label = "DEPLOY QUEUED   ·   %d%%" % roundi(fraction * 100.0)
		else:
			label = "DEPLOY   ·   PREPARING PARK %d%%" % roundi(fraction * 100.0)
	if label != _last_deploy_text:
		deploy_button.text = label
		_last_deploy_text = label
	deploy_button.disabled = (not error.is_empty() and not retry) or (ready_now and not _can("deploy") and not retry)
	deploy_bar.visible = not ready_now
	deploy_bar.value = fraction
	if ready_now:
		deploy_status.text = "Park ready.  Insertion at " + ("night." if _night() else "golden hour.")
	else:
		deploy_status.text = ("Building the park" if stage.is_empty() else stage) + "   ·   DEPLOY now to enter as soon as it is ready."

func _process(delta: float) -> void:
	if screen == null or not is_visible_in_tree(): return
	_poll -= delta
	if _poll > 0.0: return
	_poll = POLL_SECONDS
	_refresh_deploy()

func _emit(action: String) -> void:
	action_requested.emit(action)

## Pad B / Esc closes the settings drawer first (ShinraiControllerUi hook).
func controller_cancel() -> bool:
	return screen != null and screen.controller_cancel()
