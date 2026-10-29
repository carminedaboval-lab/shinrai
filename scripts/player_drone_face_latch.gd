extends Node
const GameInput=preload("./shinrai_input.gd")
## Player-side state only. The actor prepares/restores its own physical attachment.
## The combat owner applies the initial hit; this helper applies only attached DOT.
## The player forwards Space events and calls tick() only while active/blocked.

const ESCAPE_PRESSES: int = 12
const DAMAGE_PER_SECOND: float = 2.0

var _configured: bool = false
var _shutting_down: bool = false
var _releasing: bool = false
var _tick_in_progress: bool = false
var _active: bool = false
var _epoch: int = 0
var _player_ref: WeakRef
var _bot_ref: WeakRef
var _health_ref: WeakRef
var _release_callback: Callable
var _bot_exit_callback: Callable
var _bot_destroyed_callback: Callable
var _space_down: bool = false
var _block_until_space_release: bool = false
var _escape_press_count: int = 0
var _attached_seconds: float = 0.0
var _prompt_layer: CanvasLayer
var _prompt_panel: PanelContainer
var _prompt_label: Label


## The player owns this helper as a child; no automatic input/process callbacks.
func setup(player: Node3D) -> void:
	if _configured or _shutting_down:
		return
	if not is_instance_valid(player):
		push_warning("Face latch helper requires a valid player.")
		return
	_player_ref = weakref(player)
	set_process(false)
	set_physics_process(false)
	_create_prompt()
	_configured = true
	player.tree_exiting.connect(_on_player_tree_exiting)


func can_accept(bot: Node3D = null) -> bool:
	if not _configured or _shutting_down or _releasing or _active:
		return false
	if not is_inside_tree() or not _player_is_alive():
		return false
	return bot == null or _bot_is_alive(bot)


## release_callback(reason) must restore actor state and tolerate repeated cleanup.
## No initial damage occurs here. Only a complete ticked second earns a DOT hit.
func begin(bot: Node3D, release_callback: Callable) -> bool:
	if not is_instance_valid(bot) or not release_callback.is_valid() or not can_accept(bot):
		return false
	_epoch += 1
	_bot_ref = weakref(bot)
	_release_callback = release_callback
	_escape_press_count = 0
	_attached_seconds = 0.0
	_space_down = Input.is_physical_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SPACE) or Input.is_action_pressed("sr_jump")
	_block_until_space_release = false
	_active = true
	_connect_bot_lifecycle(bot, _epoch)
	_update_prompt()
	return true


## A non-null bot scopes cleanup to that identity; null is owner-wide cleanup.
## Active state, DOT and signal hooks are cleared before invoking actor restoration.
func release(bot: Node3D = null, reason: String = "external") -> void:
	if not _active:
		return
	var attached_bot: Node3D = _get_node(_bot_ref)
	if bot != null and bot != attached_bot:
		return
	var callback: Callable = _release_callback
	var self_ref: WeakRef = weakref(self)
	_releasing = true
	_epoch += 1
	_active = false
	_attached_seconds = 0.0
	if _space_down:
		_block_until_space_release = true
	_disconnect_bot_lifecycle(attached_bot)
	_bot_ref = null
	_release_callback = Callable()
	_hide_prompt()
	if callback.is_valid():
		callback.call(reason)
	if not is_instance_valid(self_ref.get_ref()):
		return
	_releasing = false


func is_attached_to(bot: Node3D) -> bool:
	return _active and is_instance_valid(bot) and _get_node(_bot_ref) == bot


func is_active() -> bool:
	return _active


## Last count is retained after detach for diagnostics; begin/reset clears it.
func get_escape_press_count() -> int:
	return _escape_press_count


## Physical Space is preferred; logical Space supports equivalent key events.
## Releases rearm the edge gate. Echo and duplicate non-echo down events never count.
func consume_space_event(event: InputEvent) -> bool:
	var keyboard: bool=event is InputEventKey and (event.physical_keycode==KEY_SPACE or event.keycode==KEY_SPACE)
	var pad: bool=event is InputEventJoypadButton and event.button_index==JOY_BUTTON_A
	if not keyboard and not pad:return false
	if not _active and not _block_until_space_release:
		return false
	if not event.pressed:
		_space_down = false
		_block_until_space_release = false
		return true
	if event is InputEventKey and event.echo:
		_space_down = true
		return true
	if _space_down:
		return true
	_space_down = true
	if _active:
		_escape_press_count += 1
		_update_prompt()
		if _escape_press_count >= ESCAPE_PRESSES:
			# Arm before release/callback: the twelfth held press cannot become jump.
			_block_until_space_release = true
			release(null, "escaped")
	return true


## Side-effect-free: do not sample/rearm inside the current twelfth input event.
func blocks_jump() -> bool:
	return _active or _block_until_space_release


## Owner calls this during active/blocked state, including before its alive guard.
## Key-up sampling recovers releases missed during pause/focus; it never counts.
func tick(delta: float) -> void:
	if _shutting_down or _tick_in_progress:
		return
	_resync_released_space()
	if not _active:
		return
	if not _player_is_alive():
		release(null, "player_died")
		return
	var bot: Node3D = _get_node(_bot_ref)
	if not _bot_is_alive(bot):
		release(null, "bot_died")
		return
	if not is_finite(delta) or delta <= 0.0:
		return
	var player: Node3D = _get_node(_player_ref)
	if not player.has_method("take_damage"):
		release(null, "invalid_player")
		return
	var tick_epoch: int = _epoch
	var self_ref: WeakRef = weakref(self)
	_tick_in_progress = true
	_attached_seconds += delta
	while _attached_seconds >= 1.0:
		if tick_epoch != _epoch or not _active or _shutting_down:
			break
		if not _player_is_alive():
			release(null, "player_died")
			break
		if not _bot_is_alive(_get_node(_bot_ref)):
			release(null, "bot_died")
			break
		_attached_seconds -= 1.0
		player.call("take_damage", DAMAGE_PER_SECOND)
		if not is_instance_valid(self_ref.get_ref()):
			return
		# damage_received may release this bot and begin another attachment.
		# Never spend the old hitch remainder on that new attachment.
		if tick_epoch != _epoch or not _active or _shutting_down:
			break
		if not _player_is_alive():
			release(null, "player_died")
			break
	_tick_in_progress = false


func reset() -> void:
	var self_ref: WeakRef = weakref(self)
	release(null, "reset")
	if not is_instance_valid(self_ref.get_ref()):
		return
	_epoch += 1
	_attached_seconds = 0.0
	_escape_press_count = 0
	_resync_released_space()
	_hide_prompt()


func shutdown() -> void:
	if _shutting_down:
		return
	var self_ref: WeakRef = weakref(self)
	_shutting_down = true
	release(null, "shutdown")
	if not is_instance_valid(self_ref.get_ref()):
		return
	_epoch += 1
	var player: Node3D = _get_node(_player_ref)
	if player != null and player.tree_exiting.is_connected(_on_player_tree_exiting):
		player.tree_exiting.disconnect(_on_player_tree_exiting)
	_player_ref = null
	_space_down = false
	_block_until_space_release = false
	_attached_seconds = 0.0
	_escape_press_count = 0
	_hide_prompt()
	if is_instance_valid(_prompt_layer):
		_prompt_layer.queue_free()


func _resync_released_space() -> void:
	# Logical fallback must also be up before rearming a keycode-only event.
	if not Input.is_physical_key_pressed(KEY_SPACE) and not Input.is_key_pressed(KEY_SPACE) and not Input.is_action_pressed("sr_jump"):
		_space_down = false
		_block_until_space_release = false


func _player_is_alive() -> bool:
	var player: Node3D = _get_node(_player_ref)
	return player != null and player.is_inside_tree() and not player.is_queued_for_deletion() and bool(player.get("alive"))


func _bot_is_alive(bot: Node3D) -> bool:
	return is_instance_valid(bot) and bot.is_inside_tree() and not bot.is_queued_for_deletion() and not bool(bot.get("dead"))


func _connect_bot_lifecycle(bot: Node3D, attach_epoch: int) -> void:
	_bot_exit_callback = _on_bot_tree_exiting.bind(attach_epoch)
	bot.tree_exiting.connect(_bot_exit_callback)
	var health_candidate: Variant = bot.get("health")
	if health_candidate is Object:
		var health_object: Object = health_candidate as Object
		if is_instance_valid(health_object) and health_object.has_signal("destroyed"):
			_health_ref = weakref(health_object)
			_bot_destroyed_callback = _on_bot_destroyed.bind(attach_epoch)
			health_object.connect("destroyed", _bot_destroyed_callback)


func _disconnect_bot_lifecycle(bot: Node3D) -> void:
	if is_instance_valid(bot) and _bot_exit_callback.is_valid():
		if bot.tree_exiting.is_connected(_bot_exit_callback):
			bot.tree_exiting.disconnect(_bot_exit_callback)
	var health_object: Object = null
	if _health_ref != null:
		health_object = _health_ref.get_ref() as Object
	if is_instance_valid(health_object) and _bot_destroyed_callback.is_valid():
		if health_object.has_signal("destroyed") and health_object.is_connected("destroyed", _bot_destroyed_callback):
			health_object.disconnect("destroyed", _bot_destroyed_callback)
	_health_ref = null
	_bot_exit_callback = Callable()
	_bot_destroyed_callback = Callable()


func _on_bot_tree_exiting(attach_epoch: int) -> void:
	if _active and attach_epoch == _epoch:
		release(null, "bot_exited")


func _on_bot_destroyed(attach_epoch: int) -> void:
	if _active and attach_epoch == _epoch:
		release(null, "bot_died")


func _on_player_tree_exiting() -> void:
	shutdown()


func _exit_tree() -> void:
	if _configured:
		shutdown()


func _get_node(reference: WeakRef) -> Node3D:
	if reference == null:
		return null
	return reference.get_ref() as Node3D


func _create_prompt() -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "FaceDroneLatchPrompt"
	_prompt_layer.layer = 20
	add_child(_prompt_layer)
	_prompt_panel = PanelContainer.new()
	_prompt_panel.name = "PromptPanel"
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_panel.anchor_top = 0.74
	_prompt_panel.anchor_bottom = 0.74
	_prompt_panel.offset_left = -120.0
	_prompt_panel.offset_right = 120.0
	_prompt_panel.offset_top = -22.0
	_prompt_panel.offset_bottom = 22.0
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.focus_mode = Control.FOCUS_NONE
	var backing: StyleBoxFlat = StyleBoxFlat.new()
	backing.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	_prompt_panel.add_theme_stylebox_override("panel", backing)
	_prompt_layer.add_child(_prompt_panel)
	_prompt_label = Label.new()
	_prompt_label.name = "PromptText"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label.focus_mode = Control.FOCUS_NONE
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_color", Color.WHITE)
	_prompt_label.add_theme_constant_override("outline_size", 2)
	_prompt_label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.04, 1.0))
	_prompt_panel.add_child(_prompt_label)
	_update_prompt()


func _update_prompt() -> void:
	if is_instance_valid(_prompt_label):
		_prompt_label.text = "Mash %s   %d / 12" % ["A" if GameInput.gamepad_active() else "SPACE",_escape_press_count]
	if is_instance_valid(_prompt_panel):
		_prompt_panel.visible = _active


func _hide_prompt() -> void:
	if is_instance_valid(_prompt_panel):
		_prompt_panel.hide()
