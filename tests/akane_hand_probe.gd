extends SceneTree
# Pistol grip fit probe: the hand and finger joints exactly as rendered (the
# viewmodel's own final-pose snapshot, taken while the grip pose is applied),
# printed in the gun's axes in millimetres: +x toward the rear, +y up, +z the
# gun's left. Optional close-up shots of the grip from six sides.
#   godot --fixed-fps 60 --path . --script res://tests/akane_hand_probe.gd -- --out <dir> [--shots] [--aim]
var out_dir := "user://akane_hand_probe"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	world.add_child(floor_body)
	var floor_mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(40, 1, 40)
	floor_mesh.mesh = bm
	floor_body.add_child(floor_mesh)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.58, 0.62)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.62)
	env.environment = e
	world.add_child(env)
	var player: Node = load("res://scripts/player.gd").new()
	player.set("extraction_mode", true)
	player.position = Vector3(0, 0.2, 0)
	world.add_child(player)
	await frames(60)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.set("test_input_override", true)
	player.apply_weapon_loadout("akane", {"optic": "", "ammo": 17, "reserve": 51, "chambered": true, "bolt_locked": false})
	await frames(150)
	var aim := OS.get_cmdline_user_args().has("--aim")
	if aim:
		for f in 120:
			player.ads = true
			await frames(1)
	var vm: Node = player.get("uzi_viewmodel")
	vm.set("_capture_final_pose", true)
	await frames(6)
	var snap: Dictionary = vm.get("_natural_final_pose")
	var assembly: Node3D = vm.get("assembly")
	var inv := assembly.global_transform.affine_inverse()
	for bone_name: String in snap.get("bones", {}):
		if not (bone_name.contains(".R") or bone_name.contains(".L")):
			continue
		if not (bone_name.contains("hand") or bone_name.contains("f_") or bone_name.contains("thumb") or bone_name.contains("palm") or bone_name.contains("forearm")):
			continue
		var v: Array = snap.bones[bone_name]
		var t := Transform3D(Basis(Vector3(v[0][0], v[0][1], v[0][2]), Vector3(v[1][0], v[1][1], v[1][2]), Vector3(v[2][0], v[2][1], v[2][2])), Vector3(v[3][0], v[3][1], v[3][2]))
		print("PROBE_BONE %s gun_mm=%s" % [bone_name, (inv * t.origin * 1000.0).round()])
	# Grip outline: front strap / backstrap x and side z at a few heights.
	for y_mm: float in [-10.0, -25.0, -40.0, -55.0, -70.0, -85.0]:
		var xmin := INF
		var xmax := -INF
		var zmax := -INF
		for mesh: MeshInstance3D in assembly.find_children("*", "MeshInstance3D", true, false):
			if not (String(mesh.name) in ["Receiver", "Magazine"]) or mesh.mesh == null:
				continue
			var to_gun := inv * mesh.global_transform
			for s in mesh.mesh.get_surface_count():
				var verts: PackedVector3Array = mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
				for v in verts:
					var g := to_gun * v * 1000.0
					if absf(g.y - y_mm) < 2.5 and g.x > -8.0:
						xmin = minf(xmin, g.x)
						xmax = maxf(xmax, g.x)
						zmax = maxf(zmax, absf(g.z))
		print("PROBE_GRIP y=%d front_x=%.0f back_x=%.0f half_width=%.0f" % [y_mm, xmin, xmax, zmax])
	if OS.get_cmdline_user_args().has("--shots"):
		var grip := assembly.get_node("GripRight") as Node3D
		var probe := Camera3D.new()
		probe.top_level = true
		probe.fov = 34.0
		probe.near = 0.01
		probe.cull_mask = player.camera.cull_mask
		root.add_child(probe)
		probe.current = true
		var eye_basis: Basis = player.camera.global_transform.basis
		var views := {"left": Vector3(-0.38, 0.03, 0.0), "right": Vector3(0.38, 0.03, 0.0), "top": Vector3(0.0, 0.38, 0.06),
			"below": Vector3(0.0, -0.38, 0.06), "rear": Vector3(0.0, 0.06, 0.40), "front_left": Vector3(-0.26, 0.05, -0.30)}
		for key: String in views:
			var centre: Vector3 = grip.global_position + eye_basis * Vector3(0.0, 0.03, -0.02)
			probe.global_position = centre + eye_basis * views[key]
			probe.look_at(centre, eye_basis.y if absf(views[key].y) < 0.3 else -eye_basis.z)
			await frames(4)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out_dir.path_join(key + ".png"))
		probe.current = false
		player.camera.current = true
		await frames(4)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("player_view.png"))
	quit(0)
