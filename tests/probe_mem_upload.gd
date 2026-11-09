extends SceneTree

# Micro-benchmark (investigation probe): how much process private memory one GPU upload costs
# on this driver. Loads nothing from the game. Phases 6 s apart, each line stamped with engine time:
#   idle, rgba8 (64 x 2048^2 RGBA8 + mips), bc (64 x 2048^2 DXT5 + mips), mesh (40 x 400k-vertex
#   ArrayMesh), free_rgba8 (drop the RGBA8 set), free_all.
# Sample the process from outside (private bytes, GPU process memory) and align by time.
#   godot --path . --script res://tests/probe_mem_upload.gd [--rendering-driver d3d12]

var keep_rgba: Array = []
var keep_bc: Array = []
var keep_mesh: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _mark(label: String) -> void:
	print("UPLOAD %s t=%.1f static_mb=%.1f video_mb=%.1f tex_mb=%.1f buf_mb=%.1f" % [label, Time.get_ticks_msec() / 1000.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0])

func _wait(sec: float) -> void:
	var until := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < until: await process_frame

func _run() -> void:
	await _wait(6.0)
	_mark("idle")
	var img := Image.create(2048, 2048, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.5, 0.2, 0.9))
	for y: int in range(0, 2048, 7):
		for x: int in range(0, 2048, 13): img.set_pixel(x, y, Color(randf(), randf(), randf(), 1.0))
	img.generate_mipmaps()
	for i: int in 64: keep_rgba.append(ImageTexture.create_from_image(img))
	await _wait(6.0)
	_mark("rgba8_64x2048")
	var bc := img.duplicate() as Image
	bc.compress(Image.COMPRESS_S3TC)
	for i: int in 64: keep_bc.append(ImageTexture.create_from_image(bc))
	await _wait(6.0)
	_mark("dxt5_64x2048 fmt=%d" % bc.get_format())
	var verts := PackedVector3Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array()
	verts.resize(400000); normals.resize(400000); uvs.resize(400000)
	for i: int in 400000:
		verts[i] = Vector3(randf(), randf(), randf()); normals[i] = Vector3.UP; uvs[i] = Vector2(randf(), randf())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_TEX_UV] = uvs
	for i: int in 40:
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		keep_mesh.append(m)
	await _wait(6.0)
	_mark("mesh_40x400k")
	keep_rgba.clear()
	await _wait(6.0)
	_mark("free_rgba8")
	keep_bc.clear(); keep_mesh.clear()
	await _wait(6.0)
	_mark("free_all")
	quit(0)
