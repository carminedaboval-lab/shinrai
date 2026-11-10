extends SceneTree
## What one small GPU buffer really costs on the current driver. No park.
##   godot [--rendering-driver d3d12] --path . --script res://tests/probe_mem_small_buffers.gd -- [--count=20000]
## Creates `count` tiny MultiMeshes (16 instances, 768 bytes of data each), then
## `count` tiny meshes (one quad), and prints the renderer's video / buffer
## memory after each step. If video memory grows far more than buffer memory,
## the driver rounds every buffer up (Direct3D 12 places buffers on 64 KB
## boundaries), and the park's tens of thousands of small batches pay for it.

func _initialize() -> void:
	call_deferred("run")

func _info() -> Dictionary:
	return {
		"video_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		"buffer_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0,
		"texture_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
	}

func _line(label: String, now: Dictionary, before: Dictionary, count: int) -> void:
	print("SMALLBUF %s video=%.1f MB (+%.1f) buffer=%.1f MB (+%.1f) per_object_video=%.1f KB per_object_buffer=%.2f KB" % [
		label, now.video_mb, now.video_mb - before.video_mb, now.buffer_mb, now.buffer_mb - before.buffer_mb,
		(now.video_mb - before.video_mb) * 1024.0 / maxi(1, count), (now.buffer_mb - before.buffer_mb) * 1024.0 / maxi(1, count)])

func run() -> void:
	var count := 20000
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--count="): count = int(arg.get_slice("=", 1))
	for i: int in range(10): await process_frame
	print("SMALLBUF driver=%s count=%d" % [RenderingServer.get_current_rendering_driver_name(), count])
	var start := _info()
	_line("start", start, start, 1)
	var quad := QuadMesh.new()
	var keep: Array = []
	for i: int in range(count):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = quad
		mm.instance_count = 16
		for j: int in range(16): mm.set_instance_transform(j, Transform3D(Basis.IDENTITY, Vector3(i, 0, j)))
		keep.append(mm)
	for i: int in range(10): await process_frame
	var after_mm := _info()
	_line("multimeshes", after_mm, start, count)
	for i: int in range(count):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for corner: Vector3 in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)]:
			st.set_normal(Vector3.BACK)
			st.set_uv(Vector2(corner.x, corner.y))
			st.add_vertex(corner + Vector3(i, 0, 0))
		for index: int in [0, 1, 2, 0, 2, 3]: st.add_index(index)
		keep.append(st.commit())
	for i: int in range(10): await process_frame
	var after_mesh := _info()
	_line("meshes", after_mesh, after_mm, count)
	# Hold for an outside sampler (private bytes, GPU committed) to read the end state.
	await create_timer(6.0).timeout
	print("SMALLBUF_DONE")
	quit()
