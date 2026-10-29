extends Node
## Shared runtime bindings. Gameplay callers use semantic names, without sr_.
const DEADZONE: float=.20
const TRIGGER_THRESHOLD: float=.5
const ACTIONS: Array[String]=["move_left","move_right","move_forward","move_back","look_left","look_right","look_up","look_down","fire","aim","jump","crouch","sprint","reload","weapon_next","interact","eat","heal","lower_weapon","inventory","pause","map","track","inspect","lean_left","lean_right","ui_section_prev","ui_section_next","ui_details","mag_check"]
const REARM_ACTIONS: Array[String]=["fire","aim","jump","interact","eat","heal","reload","weapon_next","lower_weapon","inspect","crouch","sprint","lean_left","lean_right","mag_check"]
static var release_epoch: int=0
static var _configured: bool=false
static var _release_required: bool=false
static var _focused: bool=true
static var _last_pad: bool=false
static var _last_pad_device: int=-1
static var _event_id: int=-1
static var _trigger_down: Dictionary={}
static var _trigger_press: Dictionary={}
static var _trigger_release: Dictionary={}

static func ensure_actions() -> void:
	if _configured: return
	_configured=true
	for name: String in ACTIONS:
		if not InputMap.has_action("sr_"+name): InputMap.add_action("sr_"+name,TRIGGER_THRESHOLD if name in ["fire","aim"] else DEADZONE)
	var keys: Dictionary={"move_left":KEY_A,"move_right":KEY_D,"move_forward":KEY_W,"move_back":KEY_S,"jump":KEY_SPACE,"crouch":KEY_CTRL,"sprint":KEY_SHIFT,"reload":KEY_R,"weapon_next":KEY_Y,"interact":KEY_E,"eat":KEY_F,"heal":KEY_H,"lower_weapon":KEY_B,"inventory":KEY_I,"pause":KEY_ESCAPE,"map":KEY_M,"track":KEY_T,"inspect":KEY_V,"lean_left":KEY_Q,"lean_right":KEY_C,"mag_check":KEY_J}
	for name: String in keys:
		var key:=InputEventKey.new(); key.device=-1; key.physical_keycode=int(keys[name]); _bind("sr_"+name,key)
		var logical:=InputEventKey.new(); logical.device=-1; logical.keycode=int(keys[name]); _bind("sr_"+name,logical)
	var tab:=InputEventKey.new(); tab.device=-1; tab.physical_keycode=KEY_TAB; _bind("sr_map",tab)
	var logical_tab:=InputEventKey.new(); logical_tab.device=-1; logical_tab.keycode=KEY_TAB; _bind("sr_map",logical_tab)
	for name: String in ["fire","aim"]:
		var mouse:=InputEventMouseButton.new(); mouse.device=-1; mouse.button_index=MOUSE_BUTTON_LEFT if name=="fire" else MOUSE_BUTTON_RIGHT; _bind("sr_"+name,mouse)
	var buttons: Dictionary={"jump":JOY_BUTTON_A,"crouch":JOY_BUTTON_B,"sprint":JOY_BUTTON_LEFT_STICK,"reload":JOY_BUTTON_X,"weapon_next":JOY_BUTTON_Y,"interact":JOY_BUTTON_RIGHT_SHOULDER,"heal":JOY_BUTTON_LEFT_SHOULDER,"eat":JOY_BUTTON_DPAD_UP,"lower_weapon":JOY_BUTTON_DPAD_DOWN,"inventory":JOY_BUTTON_BACK,"pause":JOY_BUTTON_START,"inspect":JOY_BUTTON_RIGHT_STICK,"lean_left":JOY_BUTTON_DPAD_LEFT,"lean_right":JOY_BUTTON_DPAD_RIGHT,"ui_section_prev":JOY_BUTTON_LEFT_SHOULDER,"ui_section_next":JOY_BUTTON_RIGHT_SHOULDER,"ui_details":JOY_BUTTON_Y}
	for name: String in buttons:
		var button:=InputEventJoypadButton.new(); button.device=-1; button.button_index=int(buttons[name]); _bind("sr_"+name,button)
	var axes: Dictionary={"move_left":[JOY_AXIS_LEFT_X,-1.0],"move_right":[JOY_AXIS_LEFT_X,1.0],"move_forward":[JOY_AXIS_LEFT_Y,-1.0],"move_back":[JOY_AXIS_LEFT_Y,1.0],"look_left":[JOY_AXIS_RIGHT_X,-1.0],"look_right":[JOY_AXIS_RIGHT_X,1.0],"look_up":[JOY_AXIS_RIGHT_Y,-1.0],"look_down":[JOY_AXIS_RIGHT_Y,1.0],"fire":[JOY_AXIS_TRIGGER_RIGHT,1.0],"aim":[JOY_AXIS_TRIGGER_LEFT,1.0]}
	for name: String in axes:
		var motion:=InputEventJoypadMotion.new(); motion.device=-1; motion.axis=int(axes[name][0]); motion.axis_value=float(axes[name][1]); _bind("sr_"+name,motion)
	# Keep Godot's normal keyboard UI bindings, adding standard Xbox navigation.
	var ui_buttons: Dictionary={"ui_accept":JOY_BUTTON_A,"ui_cancel":JOY_BUTTON_B,"ui_left":JOY_BUTTON_DPAD_LEFT,"ui_right":JOY_BUTTON_DPAD_RIGHT,"ui_up":JOY_BUTTON_DPAD_UP,"ui_down":JOY_BUTTON_DPAD_DOWN}
	for name: String in ui_buttons:
		if not InputMap.has_action(name): InputMap.add_action(name,DEADZONE)
		var button:=InputEventJoypadButton.new(); button.device=-1; button.button_index=int(ui_buttons[name]); _bind(name,button)
	for pair: Array in [["ui_left",JOY_AXIS_LEFT_X,-1.0],["ui_right",JOY_AXIS_LEFT_X,1.0],["ui_up",JOY_AXIS_LEFT_Y,-1.0],["ui_down",JOY_AXIS_LEFT_Y,1.0]]:
		var motion:=InputEventJoypadMotion.new(); motion.device=-1; motion.axis=int(pair[1]); motion.axis_value=float(pair[2]); _bind(String(pair[0]),motion)

static func _bind(action: String, event: InputEvent) -> void:
	if not InputMap.action_has_event(action,event): InputMap.action_add_event(action,event)

static func _is_ui(name: String) -> bool:
	return name in ["pause","inventory","map"] or name.begins_with("ui_")

static func down(name: String) -> bool:
	ensure_actions()
	return _focused and (_is_ui(name) or gameplay_ready()) and Input.is_action_pressed("sr_"+name)

static func pressed(event: InputEvent, name: String) -> bool:
	ensure_actions(); _observe(event)
	if not _focused or (not _is_ui(name) and not gameplay_ready()): return false
	if event is InputEventJoypadMotion and name in ["fire","aim"]: return bool(_trigger_press.get(name,false))
	return event.is_action_pressed("sr_"+name,false)

static func released(event: InputEvent, name: String) -> bool:
	ensure_actions(); _observe(event)
	# Releases are delivered even while the gameplay guard is armed.
	if event is InputEventJoypadMotion and name in ["fire","aim"]: return bool(_trigger_release.get(name,false))
	return event.is_action_released("sr_"+name)

static func movement() -> Vector2:
	ensure_actions()
	if not gameplay_ready(): return Vector2.ZERO
	return Input.get_vector("sr_move_left","sr_move_right","sr_move_forward","sr_move_back",DEADZONE)

static func look() -> Vector2:
	ensure_actions()
	if not gameplay_ready(): return Vector2.ZERO
	return Input.get_vector("sr_look_left","sr_look_right","sr_look_up","sr_look_down",DEADZONE)

static func application_focused() -> bool:
	return _focused

static func gamepad_active() -> bool:
	return _last_pad

static func hint(key: String) -> String:
	if not _last_pad: return key
	var labels: Dictionary={"E":"RB","F":"D-pad Up","H":"LB","B":"D-pad Down","I":"View","V":"R3","R":"X","Y":"Y","SPACE":"A","SHIFT":"L3","CTRL":"B","LMB":"RT","RMB":"LT","Q":"D-pad Left","C":"D-pad Right","lean_left":"D-pad Left","lean_right":"D-pad Right","ESC":"Menu","TAB":"Pause: Map","M":"Pause: Map","T":"Pause: Objectives","J":"R3 + X","mag_check":"R3 + X","interact":"RB","eat":"D-pad Up","heal":"LB","lower_weapon":"D-pad Down","inventory":"View","inspect":"R3","reload":"X","weapon_next":"Y","jump":"A","sprint":"L3","crouch":"B","fire":"RT","aim":"LT","pause":"Menu","map":"Pause: Map","track":"Pause: Objectives"}
	return String(labels.get(key,labels.get(key.to_upper(),key)))

static func require_release() -> void:
	_release_required=true
	release_epoch+=1

static func gameplay_ready() -> bool:
	if not _focused: return false
	if _release_required and buttons_released(): _release_required=false
	return not _release_required

static func buttons_released() -> bool:
	ensure_actions()
	for name: String in REARM_ACTIONS:
		if Input.is_action_pressed("sr_"+name): return false
	var devices: Array=Input.get_connected_joypads()
	if _last_pad_device>=0 and not devices.has(_last_pad_device): devices.append(_last_pad_device)
	for device: int in devices:
		for button: int in range(JOY_BUTTON_MAX):
			if Input.is_joy_button_pressed(device,button): return false
		if Vector2(Input.get_joy_axis(device,JOY_AXIS_LEFT_X),Input.get_joy_axis(device,JOY_AXIS_LEFT_Y)).length()>DEADZONE: return false
		if Vector2(Input.get_joy_axis(device,JOY_AXIS_RIGHT_X),Input.get_joy_axis(device,JOY_AXIS_RIGHT_Y)).length()>DEADZONE: return false
		if Input.get_joy_axis(device,JOY_AXIS_TRIGGER_LEFT)>TRIGGER_THRESHOLD or Input.get_joy_axis(device,JOY_AXIS_TRIGGER_RIGHT)>TRIGGER_THRESHOLD: return false
	return true

static func _observe(event: InputEvent) -> void:
	if event.get_instance_id()==_event_id: return
	_event_id=event.get_instance_id()
	_trigger_press.clear(); _trigger_release.clear()
	if event is InputEventJoypadButton and event.pressed:
		_last_pad=true; _last_pad_device=event.device
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value)>DEADZONE:
			_last_pad=true; _last_pad_device=event.device
		if event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
			var name: String="fire" if event.axis==JOY_AXIS_TRIGGER_RIGHT else "aim"
			var identity: String=str(event.device)+":"+name
			var was_down: bool=bool(_trigger_down.get(identity,false))
			var now_down: bool=event.axis_value>TRIGGER_THRESHOLD
			_trigger_down[identity]=now_down
			_trigger_press[name]=now_down and not was_down
			_trigger_release[name]=was_down and not now_down
	elif (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		_last_pad=false
	elif event is InputEventMouseMotion and event.relative.length_squared()>1.0:
		_last_pad=false

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	ensure_actions()
	if not Input.joy_connection_changed.is_connected(_joy_connection_changed): Input.joy_connection_changed.connect(_joy_connection_changed)

func _input(event: InputEvent) -> void:
	_observe(event)
	# Native Control actions also need the application focus boundary.
	if not _focused and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused=false; _cancel_intents()
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused=true; require_release()

func _joy_connection_changed(device: int, connected: bool) -> void:
	if connected: return
	if device==_last_pad_device: _last_pad_device=-1; _last_pad=false
	_trigger_down.clear()
	_clear_joy_actions()
	_cancel_intents()

func _clear_joy_actions() -> void:
	# Disconnect does not guarantee a release event for every held control.
	# Clear only mapped pad actions, retaining physically held keyboard/mouse
	# bindings for that action. This also handles synthetic disconnect fixtures.
	var actions: Array[String]=[]
	for name: String in ACTIONS: actions.append("sr_"+name)
	actions.append_array(["ui_accept","ui_cancel","ui_left","ui_right","ui_up","ui_down"])
	for action: String in actions:
		var has_pad: bool=false
		var keyboard_held: bool=false
		for binding: InputEvent in InputMap.action_get_events(action):
			if binding is InputEventJoypadButton or binding is InputEventJoypadMotion: has_pad=true
			elif binding is InputEventKey:
				if (binding.physical_keycode!=0 and Input.is_physical_key_pressed(binding.physical_keycode)) or (binding.keycode!=0 and Input.is_key_pressed(binding.keycode)): keyboard_held=true
			elif binding is InputEventMouseButton and Input.is_mouse_button_pressed(binding.button_index): keyboard_held=true
		if has_pad and not keyboard_held: Input.action_release(action)

func _cancel_intents() -> void:
	require_release()
	if is_inside_tree(): get_tree().call_group("shinrai_input_players","reset_controller_intents")
