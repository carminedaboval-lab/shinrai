extends SceneTree
func _initialize() -> void:
	call_deferred("render_item")
func bounds(node: Node3D) -> AABB:
	var result := AABB()
	if node is MeshInstance3D and node.mesh != null:
		result = node.global_transform * node.mesh.get_aabb()
	for child: Node in node.get_children():
		if child is Node3D:
			var box := bounds(child)
			if box.size.length() > 0:
				result = box if result.size.length() == 0 else result.merge(box)
	return result
func render_item() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var studio := Node3D.new()
	viewport.add_child(studio)
	var cup: Node3D = load("res://assets/shinrai/parks/midori_park/models/furniture/ambient/takeaway_cup/midori_takeaway_cup.glb").instantiate()
	studio.add_child(cup)
	var box := bounds(cup)
	cup.position -= box.get_center()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c3d6e6")
	env.environment.ambient_light_energy = 0.7
	studio.add_child(env)
	for spec: Vector3 in [Vector3(2, 3, 4), Vector3(-3, 1, -2)]:
		var light := DirectionalLight3D.new()
		studio.add_child(light)
		light.position = spec
		light.look_at(Vector3.ZERO)
		light.light_energy = 1.5
	var camera := Camera3D.new()
	studio.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = box.size.length() * 1.1
	camera.near = 0.001
	camera.position = Vector3(.17, .10, .28).normalized() * maxf(box.size.length() * 3, 1)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	for frame: int in range(20): await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("SHINRAI_THUMBNAIL")
	var error := viewport.get_texture().get_image().save_png(output)
	print("THUMBNAIL_RESULT: ", error, " source_bounds=", box, " output=", output)
	quit(error)
