extends Node
## Menu-only focus/routing. B belongs exclusively to ExtractionRun's modal stack.
const GameInput=preload("./shinrai_input.gd")
var raid: Node
func setup(run: Node) -> void:
	raid=run;process_mode=Node.PROCESS_MODE_ALWAYS;GameInput.ensure_actions()
func _surface() -> Control:
	if not is_instance_valid(raid):return null
	var hud: Node=raid.get("hud")
	if not is_instance_valid(hud):return null
	var loot: Control=hud.get("loot_view")
	if is_instance_valid(loot) and loot.is_visible_in_tree():return loot
	var overlay: Control=hud.get("overlay")
	if is_instance_valid(overlay) and overlay.is_visible_in_tree():return hud.get("panel_content") as Control
	return null
func _input(event: InputEvent) -> void:
	if not GameInput.application_focused() and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		get_viewport().set_input_as_handled();return
	var surface:=_surface()
	if surface==null:return
	if event is InputEventMouseMotion and event.relative.length()>1.0 or event is InputEventMouseButton:
		if Input.mouse_mode==Input.MOUSE_MODE_HIDDEN:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		return
	var meaningful: bool=(event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value)>.55)
	if not meaningful:return
	if Input.mouse_mode==Input.MOUSE_MODE_VISIBLE:Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
	# Dpad/A pass to native Controls. Section/Y hooks are inventory presentation only.
	for node: Node in surface.find_children("*","",true,false):
		if node is Control and node.is_visible_in_tree() and node.has_method("controller_event"):
			if node.controller_event(event):get_viewport().set_input_as_handled();return
	call_deferred("_ensure_focus")
func _ensure_focus() -> void:
	var surface:=_surface()
	if surface==null or not GameInput.gamepad_active():return
	var focused:=get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and focused.is_visible_in_tree() and (focused==surface or surface.is_ancestor_of(focused)):return
	for control: Node in surface.find_children("*","",true,false):
		if control is Button and control.is_visible_in_tree() and not control.disabled:
			control.grab_focus();return

func cancel_topmost() -> bool:
	var surface:=_surface()
	if surface==null:return false
	for node: Node in surface.find_children("*","",true,false):
		if node is Control and node.is_visible_in_tree() and node.has_method("controller_cancel"):
			if node.controller_cancel():return true
	return false
