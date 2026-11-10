extends SceneTree

# Micro-benchmark (investigation probe): how much process memory each renderer feature adds per
# shader on this driver. Loads nothing from the game. 150 boxes, each with its own spatial shader,
# are drawn with one feature set chosen on the command line; sample the process from outside.
#   godot --path . --script res://tests/probe_mem_pipeline_features.gd -- --mode=<name>
# Modes: base | taa | ssao | ssr | probe | omni | spot | fog | all
# (base = one sun with shadows, no post effects; each other mode adds one feature to base).

const COUNT := 150

func _initialize() -> void:
	_run.call_deferred()

func _pipes() -> String:
	return "mesh=%d surface=%d draw=%d spec=%d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]

func _wait(sec: float) -> void:
	var until := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < until: await process_frame

func _run() -> void:
	var mode := "base"
	var settle := 12.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--wait="): settle = float(arg.trim_prefix("--wait="))
	var all := mode == "all"
	root.use_taa = all or mode == "taa"
	var holder := Node3D.new()
	root.add_child(holder)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.35, 0.4)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.4, 0.4)
	env.ssao_enabled = all or mode == "ssao"
	env.ssr_enabled = all or mode == "ssr"
	env.volumetric_fog_enabled = all or mode == "fog"
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	holder.add_child(world_env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 40)
	holder.add_child(cam)
	cam.make_current()
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, 30, 0)
	holder.add_child(sun)
	if all or mode == "omni":
		var omni := OmniLight3D.new()
		omni.shadow_enabled = true
		omni.omni_range = 60.0
		omni.position = Vector3(0, 0, 12)
		holder.add_child(omni)
	if all or mode == "spot":
		var spot := SpotLight3D.new()
		spot.shadow_enabled = true
		spot.spot_range = 80.0
		spot.position = Vector3(0, 0, 30)
		holder.add_child(spot)
	if all or mode == "probe":
		var probe := ReflectionProbe.new()
		probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
		probe.size = Vector3(80, 60, 40)
		probe.enable_shadows = true
		holder.add_child(probe)
	var box := BoxMesh.new()
	await _wait(4.0)
	print("FEATURES %s idle t=%.1f %s" % [mode, Time.get_ticks_msec() / 1000.0, _pipes()])
	for n: int in COUNT:
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nuniform float k%d = %d.0;\nvoid vertex() { VERTEX += NORMAL * 0.0%d * k%d; }\nvoid fragment() { ALBEDO = vec3(fract(k%d * 0.0137), 0.4, fract(UV.x * %d.0)); ROUGHNESS = 0.%d; }\n" % [n, n, n % 10, n, n, n % 7 + 1, n % 9 + 1]
		var mat := ShaderMaterial.new()
		mat.shader = sh
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = mat
		mi.position = Vector3((n % 15) - 7, int(n / 15) - 5, 0) * 1.6
		holder.add_child(mi)
	# Wait until the counters stop moving (a slow compiler needs longer than the settle time).
	var last := ""
	var waited := 0.0
	while waited < 240.0:
		await _wait(settle)
		waited += settle
		var now := _pipes()
		if now == last and not now.contains("surface=0"): break
		last = now
	print("FEATURES %s done t=%.1f shaders=%d %s" % [mode, Time.get_ticks_msec() / 1000.0, COUNT, _pipes()])
	quit(0)
