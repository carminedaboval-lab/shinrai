extends SceneTree

# Splits frame time at one view: no 3D at all, then each big render feature off.
# godot --path . --script res://tests/probe_render_split.gd -- --view=grove

const VIEWS := {
	"grove": [Vector2(-82, -20), Vector2(-65, -12)],
	"lawn": [Vector2(-35, 54), Vector2(-21, 45)],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var view_name := "grove"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--view="): view_name = arg.substr(7)
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_split_probe_qa.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 300000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	raid.start_run()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	raid.player.process_mode = Node.PROCESS_MODE_DISABLED
	var view: Array = VIEWS[view_name]
	raid.player.global_position = Vector3(view[0].x * 2.0, 0.2, view[0].y * 2.0)
	raid.player.look_at(Vector3(view[1].x * 2.0, 0.2, view[1].y * 2.0))
	await _wait(6.0)
	await _sample("base")
	var vp := root.get_viewport()
	vp.disable_3d = true
	await _wait(1.0)
	await _sample("no 3D at all")
	vp.disable_3d = false
	await _wait(1.0)
	await _sample("base again")
	var lights: Array[Light3D] = []
	var shadowed: Array[Light3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is OmniLight3D or node is SpotLight3D:
			if (node as Light3D).is_visible_in_tree():
				lights.append(node)
				if (node as Light3D).shadow_enabled: shadowed.append(node)
	var lit := 0
	for light: Light3D in lights:
		if light.light_energy > 0.0: lit += 1
	print("SPLIT positional_lights=%d lit=%d with_shadows=%d" % [lights.size(), lit, shadowed.size()])
	for light: Light3D in shadowed: light.shadow_enabled = false
	await _wait(1.0)
	await _sample("positional shadows off")
	for light: Light3D in shadowed: light.shadow_enabled = true
	for light: Light3D in lights: light.visible = false
	await _wait(1.0)
	await _sample("all positional lights off")
	for light: Light3D in lights: light.visible = true
	var sun: DirectionalLight3D = scene.park_directional_light
	var mode := sun.directional_shadow_mode
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	await _wait(1.0)
	await _sample("sun one cascade")
	sun.directional_shadow_mode = mode
	sun.shadow_enabled = false
	await _wait(1.0)
	await _sample("sun shadows off")
	sun.shadow_enabled = true
	var env: Environment = scene.park_environment
	var refl := scene.find_children("*", "ReflectionProbe", true, false)
	for probe: Node in refl: (probe as Node3D).visible = false
	await _wait(1.0)
	await _sample("reflection probes off (%d)" % refl.size())
	for probe: Node in refl: (probe as Node3D).visible = true
	env.glow_enabled = false
	await _wait(1.0)
	await _sample("glow off")
	env.glow_enabled = true
	await _sample("base end")
	quit()

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

func _sample(label: String) -> void:
	var samples := PackedFloat64Array()
	var previous := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
	samples.sort()
	var median := samples[samples.size() / 2]
	print("SPLIT %-34s median=%.1fms (%.0f fps) frames=%d" % [label, median, 1000.0 / median, samples.size()])
