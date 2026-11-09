extends SceneTree

# Micro-benchmark (investigation probe): process memory cost of compiling many distinct render
# pipelines on this driver. Loads nothing from the game. A camera looks at a grid of boxes; each
# step adds 200 boxes with their own unique spatial shader (forcing new shader variants and
# pipelines), waits 6 s, and prints pipeline compilation counts with a timestamp. Sample the
# process from outside and align by time.
#   godot --path . --script res://tests/probe_mem_pipelines.gd [--rendering-driver d3d12]

var n := 0
var holder: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _pipes() -> String:
	return "canvas=%d mesh=%d surface=%d draw=%d spec=%d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]

func _mark(label: String) -> void:
	print("PIPES %s t=%.1f shaders=%d static_mb=%.1f video_mb=%.1f %s" % [label, Time.get_ticks_msec() / 1000.0, n,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, _pipes()])

func _wait(sec: float) -> void:
	var until := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < until: await process_frame

func _run() -> void:
	holder = Node3D.new()
	root.add_child(holder)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 60)
	holder.add_child(cam)
	cam.make_current()
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, 30, 0)
	holder.add_child(sun)
	var box := BoxMesh.new()
	await _wait(6.0)
	_mark("idle")
	for step: int in 5:
		for i: int in 200:
			var sh := Shader.new()
			sh.code = "shader_type spatial;\nuniform float k%d = %d.0;\nvoid vertex() { VERTEX += NORMAL * 0.0%d * k%d; }\nvoid fragment() { ALBEDO = vec3(fract(k%d * 0.0137), 0.4, fract(UV.x * %d.0)); ROUGHNESS = 0.%d; }\n" % [n, n, n % 10, n, n, n % 7 + 1, n % 9 + 1]
			var mat := ShaderMaterial.new()
			mat.shader = sh
			var mi := MeshInstance3D.new()
			mi.mesh = box
			mi.material_override = mat
			mi.position = Vector3((n % 40) - 20, int(n / 40) % 25 - 12, 0) * 1.5
			holder.add_child(mi)
			n += 1
		await _wait(6.0)
		_mark("step%d" % step)
	holder.queue_free()
	await _wait(6.0)
	_mark("freed")
	quit(0)
