extends Node
## Scoped integration with the real Shinrai player. No replacement player controller.
const GameInput = preload("res://scripts/shinrai_input.gd")
const RAID_PHASE := 2
const MOTION_PROPERTIES := ["floor_snap_length", "floor_max_angle", "floor_constant_speed", "floor_stop_on_slope", "safe_margin", "platform_floor_layers", "platform_on_leave"]

class MovementBridge:
	extends RefCounted
	var original: RefCounted
	var owner_ref: WeakRef
	func _init(delegate: RefCounted, owner: Node) -> void:
		original = delegate
		owner_ref = weakref(owner)
	func advance(actor: CharacterBody3D, delta: float, movement: Vector2, sprint: bool, crouch: bool, jump: bool) -> bool:
		var service: Node = owner_ref.get_ref()
		if is_instance_valid(service) and service.advance_ladder(actor, delta, movement):
			return true
		return original.advance(actor, delta, movement, sprint, crouch, jump)
	func update_visuals(actor: CharacterBody3D) -> void:
		original.update_visuals(actor)
	func reset(actor: CharacterBody3D) -> void:
		var service: Node = owner_ref.get_ref()
		if is_instance_valid(service):
			# reset_survival already chose the new weapon posture; do not restore
			# posture cached from an earlier raid over that freshly reset state.
			service.cancel_ladder(false)
		original.reset(actor)

var park: Node3D
var tower: Node3D
var raid: Node
var actor: CharacterBody3D
var _bridge: MovementBridge
var _original_movement: RefCounted
var _lifts: Array[Node] = []
var _ladders: Array[Node] = []
var _active_ladder: Node
var _ready_for_player := false
var _motion_saved: Dictionary = {}
var _weapon_guard := false
var _saved_weapon_lock := false
var _saved_weapon_lowered := false
var _ui_was_open := false
var _prompt_layer: CanvasLayer
var _prompt: Label

func configure(source_park: Node3D, building: Node3D) -> void:
	park = source_park
	tower = building
	if is_inside_tree():
		_try_bind()

func _ready() -> void:
	add_to_group("corporate_shinrai_interactions")
	# Set locks and menu state before the lift (-10), player (0), and raid (10).
	process_physics_priority = -20
	_build_prompt()
	_try_bind()

func _try_bind() -> void:
	if _ready_for_player or not is_instance_valid(park) or not is_instance_valid(tower):
		return
	actor = park.get_node_or_null("ParkScaleReviewPlayer") as CharacterBody3D
	raid = park.get_node_or_null("ExtractionRun")
	if actor == null or raid == null or actor.get("body_collision") == null:
		return
	var existing: Variant = actor.get("swim_controller")
	if not existing is RefCounted or not existing.has_method("advance") or not existing.has_method("reset"):
		push_error("Corporate interactions require the existing Shinrai movement-mode delegate.")
		return
	_lifts.clear()
	_ladders.clear()
	for lift in get_tree().get_nodes_in_group("cantilever_elevator"):
		if tower.is_ancestor_of(lift):
			_lifts.append(lift)
	for ladder in get_tree().get_nodes_in_group("cantilever_ladder"):
		if tower.is_ancestor_of(ladder):
			_ladders.append(ladder)
	_ready_for_player = not _lifts.is_empty() and not _ladders.is_empty()
	if _ready_for_player:
		_original_movement = existing
		_bridge = MovementBridge.new(_original_movement, self)
		actor.set("swim_controller", _bridge)
		print("SHINRAI_CORPORATE_INTERACTIONS_READY actor=", actor.get_path(), " lifts=", _lifts.size(), " ladders=", _ladders.size())

func _raid_active() -> bool:
	return is_instance_valid(raid) and is_instance_valid(actor) and int(raid.get("phase")) == RAID_PHASE and bool(actor.get("alive"))

func _modal_active() -> bool:
	return not _raid_active() or bool(raid.get("inventory_open")) or not str(raid.get("pending_cache_id")).is_empty() or bool(raid.get("deployment_pending"))

func _can_interact() -> bool:
	return _ready_for_player and not _modal_active() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and GameInput.application_focused() and GameInput.gameplay_ready() and not bool(actor.get("fly_mode")) and not bool(actor.get("mantle_active")) and not bool(actor.get("is_swimming")) and not bool(actor.get("reloading")) and not bool(actor.get("healing_active"))

func _physics_process(_delta: float) -> void:
	if not _ready_for_player:
		_try_bind()
		return
	if not is_instance_valid(actor) or not is_instance_valid(raid):
		_cleanup()
		return
	var running := _raid_active()
	for lift in _lifts:
		# Raid pause disables the player, not the whole SceneTree. Freeze moving cabs too.
		lift.set_physics_process(running)
		if _modal_active() and lift.is_ui_open():
			lift.close_ui(false)
	if not bool(actor.get("alive")) or (int(raid.get("phase")) != RAID_PHASE and int(raid.get("phase")) != 3):
		cancel_ladder()
	_sync_motion_settings(running)
	var ui_open := _lift_ui_open()
	if _ui_was_open and not ui_open:
		GameInput.require_release()
		actor.reset_controller_intents()
	_ui_was_open = ui_open
	if ui_open or is_instance_valid(_active_ladder):
		_claim_weapons()
	else:
		_restore_weapons()

func _process(_delta: float) -> void:
	if not is_instance_valid(_prompt):
		return
	_prompt.visible = false
	if not _ready_for_player or _modal_active() or _lift_ui_open():
		return
	var target := _candidate()
	if target != null:
		var caption: String = target.get_prompt(actor)
		caption = caption.replace("E ·", GameInput.hint("E") + " ·").replace("E  ",GameInput.hint("E") + "  ")
		if GameInput.gamepad_active():
			caption = caption.replace("W / S", "LS up / down")
		_prompt.text = caption
		_prompt.visible = not caption.is_empty()

func _input(event: InputEvent) -> void:
	if not _ready_for_player or not GameInput.application_focused():
		return
	if _lift_ui_open():
		# The raid handles Escape/inventory in _input, earlier than the lift's
		# standalone _unhandled_key_input. This later-installed child owns this modal.
		var close_requested := GameInput.pressed(event,"pause") or GameInput.pressed(event,"map") or GameInput.pressed(event,"inventory") or event.is_action_pressed("ui_cancel")
		if close_requested:
			_close_lift_ui(true)
			get_viewport().set_input_as_handled()
			return
		if GameInput.pressed(event,"interact"):
			GameInput.require_release()
			actor.reset_controller_intents()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey or event is InputEventJoypadButton:
			var gui_action := false
			for action in ["ui_accept","ui_left","ui_right","ui_up","ui_down"]:
				gui_action = gui_action or event.is_action(action)
			if not gui_action:
				get_viewport().set_input_as_handled()
		return
	if not _can_interact() or not GameInput.pressed(event,"interact"):
		return
	var target := _candidate()
	if target == null:
		return
	if target in _ladders and not target.is_climbing(actor):
		if not bool(actor.call("_can_stand")):
			return
		actor.call("_set_crouch_state",false)
		target.interact(actor)
		if target.is_climbing(actor):
			_active_ladder = target
			_claim_weapons()
	else:
		target.interact(actor)
		if _lift_ui_open():
			_claim_weapons()
			_ui_was_open = true
	# Event consumption alone cannot stop the raid's polled hold-E interactions.
	GameInput.require_release()
	actor.reset_controller_intents()
	get_viewport().set_input_as_handled()

func _candidate() -> Node:
	if is_instance_valid(_active_ladder) and _active_ladder.is_climbing(actor):
		return _active_ladder
	var nearest: Node
	var distance := INF
	for target in _lifts + _ladders:
		if not is_instance_valid(target) or str(target.get_prompt(actor)).is_empty():
			continue
		var candidate_distance: float = target.get_interaction_distance(actor)
		if candidate_distance < distance:
			distance = candidate_distance
			nearest = target
	if nearest != null and _competing_distance() < distance:
		return null
	return nearest

func _competing_distance() -> float:
	var nearest := INF
	if not is_instance_valid(raid):
		return nearest
	var site: Dictionary = raid.nearest_site()
	if not site.is_empty():
		nearest = float(raid.call("_distance",site.position))
	var harvest: Variant = raid.get("fruit_harvest")
	if harvest != null:
		var fruit: Dictionary = harvest.find_target(raid)
		nearest = minf(nearest,float(fruit.get("distance",INF)))
	var doors: Variant = raid.get("clubhouse_doors")
	if is_instance_valid(doors):
		nearest = minf(nearest,doors.interaction_distance(actor))
	var gate: Variant = raid.get("pitch_gate")
	if is_instance_valid(gate) and gate.reachable(actor.global_position):
		nearest = minf(nearest,absf(gate.to_local(actor.global_position).z))
	return nearest

func advance_ladder(player: CharacterBody3D, delta: float, movement: Vector2) -> bool:
	if player != actor or not is_instance_valid(_active_ladder):
		return false
	if not _active_ladder.is_climbing(actor):
		_active_ladder = null
		GameInput.require_release()
		actor.reset_controller_intents()
		return false
	if not _raid_active():
		return true
	actor.call("_update_stance",delta,false)
	actor.call("_tick_stamina",delta,false,false)
	# The player continues its normal physics callback/timers, but this delegated
	# mode consumes ground movement exactly as its existing swimming mode does.
	var consumed: bool = _active_ladder.physics_actor(actor,delta,-movement.y)
	if not _active_ladder.is_climbing(actor):
		_active_ladder = null
		GameInput.require_release()
		actor.reset_controller_intents()
	return consumed

func cancel_ladder(restore_posture: bool = true) -> void:
	if is_instance_valid(_active_ladder):
		_active_ladder.cancel_actor(actor)
	_active_ladder = null
	_restore_weapons(restore_posture)

func _lift_ui_open() -> bool:
	for lift in _lifts:
		if is_instance_valid(lift) and lift.is_ui_open():
			return true
	return false

func _close_lift_ui(restore_mouse: bool) -> void:
	for lift in _lifts:
		if is_instance_valid(lift) and lift.is_ui_open():
			lift.close_ui(restore_mouse)
	GameInput.require_release()
	if is_instance_valid(actor):
		actor.reset_controller_intents()

func _claim_weapons() -> void:
	if not _weapon_guard:
		_saved_weapon_lock = bool(actor.get("weapon_input_locked"))
		_saved_weapon_lowered = bool(actor.get("weapon_lowered"))
		_weapon_guard = true
	actor.set("weapon_input_locked",true)
	actor.set("ads",false)
	actor.set_weapon_lowered(true)

func _restore_weapons(restore_posture: bool = true) -> void:
	if not _weapon_guard:
		return
	if not is_instance_valid(actor):
		_weapon_guard = false
		return
	var run_locked := _modal_active() or bool(raid.get("cache_input_release_pending"))
	actor.set("weapon_input_locked",_saved_weapon_lock or run_locked)
	if restore_posture:
		actor.set_weapon_lowered(_saved_weapon_lowered)
	_weapon_guard = false

func _sync_motion_settings(running: bool) -> void:
	var inside := false
	if running and is_instance_valid(tower):
		var local := tower.to_local(actor.global_position)
		inside = absf(local.x) <= 165 and absf(local.z) <= 145 and local.y >= -4 and local.y <= 76
	if inside:
		if _motion_saved.is_empty():
			for property in MOTION_PROPERTIES:
				_motion_saved[property] = actor.get(property)
		actor.floor_snap_length = .32
		actor.floor_max_angle = maxf(float(_motion_saved.floor_max_angle),deg_to_rad(46))
		actor.floor_constant_speed = true
		actor.floor_stop_on_slope = true
		actor.safe_margin = .015
		actor.platform_floor_layers = int(_motion_saved.platform_floor_layers) | 1
		actor.platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	else:
		_restore_motion_settings()

func _restore_motion_settings() -> void:
	if is_instance_valid(actor):
		for property in _motion_saved:
			actor.set(property,_motion_saved[property])
	_motion_saved.clear()

func _build_prompt() -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "CorporateInteractionPrompt"
	_prompt_layer.layer = 18
	add_child(_prompt_layer)
	_prompt = Label.new()
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -350
	_prompt.offset_right = 350
	_prompt.offset_top = -110
	_prompt.offset_bottom = -65
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size",21)
	_prompt.add_theme_color_override("font_color",Color("e2f1eb"))
	_prompt.add_theme_color_override("font_shadow_color",Color("0c171d"))
	_prompt.add_theme_constant_override("shadow_offset_x",2)
	_prompt.add_theme_constant_override("shadow_offset_y",2)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_layer.add_child(_prompt)
	_prompt.hide()

func get_actor() -> CharacterBody3D:
	return actor

func get_integration_state() -> Dictionary:
	var target: Node = _candidate() if _ready_for_player and is_instance_valid(actor) else null
	return {"ready":_ready_for_player,"bridge_installed":is_instance_valid(actor) and actor.get("swim_controller")==_bridge,
		"raid_active":_raid_active(),"ladder_active":is_instance_valid(_active_ladder),"lift_ui_open":_lift_ui_open(),
		"target_path":str(target.get_path()) if target else "","prompt":str(target.get_prompt(actor)) if target else "",
		"scoped_motion_settings":not _motion_saved.is_empty(),"weapon_guard":_weapon_guard}

func _cleanup() -> void:
	_close_lift_ui(false)
	cancel_ladder()
	_restore_motion_settings()
	if is_instance_valid(actor) and actor.get("swim_controller") == _bridge:
		actor.set("swim_controller",_original_movement)
	_ready_for_player = false
	_ui_was_open = false

func _exit_tree() -> void:
	_cleanup()
