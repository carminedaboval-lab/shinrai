extends SceneTree

# Standalone check for the combat FX, K17 look and HUD widgets. It builds a
# tiny scene rather than loading the park, so it runs in seconds.
# Headless: godot --headless --path . --script res://tests/test_visual_fx.gd
# Render capture: omit --headless and append -- --render

const ImpactFX := preload("res://scripts/fx/combat_impact_fx.gd")
const CameraTrauma := preload("res://scripts/fx/camera_trauma.gd")
const K17Look := preload("res://scripts/fx/k17_look.gd")
const UIStyle := preload("res://scripts/hud/shinrai_ui_style.gd")
const Crosshair := preload("res://scripts/hud/tactical_crosshair.gd")
const DamageDirection := preload("res://scripts/hud/damage_direction.gd")

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)

func _run() -> void:
	var render := "--render" in OS.get_cmdline_user_args()
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ProceduralSkyMaterial.new()
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 150, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.42, 0.45, 0.36)
	floor_mesh.material_override = floor_material
	world.add_child(floor_mesh)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4, 2.4, 0.3)
	wall.mesh = box
	wall.position = Vector3(1.6, 1.2, -4.2)
	world.add_child(wall)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.6, 1.2)
	camera.fov = 73.0
	world.add_child(camera)
	camera.look_at(Vector3(0, 1.0, -3.0))
	camera.current = true

	# K17 stand-in: a capsule + box drone silhouette sharing one material.
	var drone := Node3D.new()
	drone.position = Vector3(-1.4, 0.0, -3.4)
	world.add_child(drone)
	var hull := MeshInstance3D.new()
	hull.mesh = CapsuleMesh.new()
	hull.position.y = 1.0
	drone.add_child(hull)
	var arm := MeshInstance3D.new()
	var arm_box := BoxMesh.new()
	arm_box.size = Vector3(1.4, 0.3, 0.4)
	arm.mesh = arm_box
	arm.position.y = 0.9
	drone.add_child(arm)
	var look = K17Look.new()
	look.apply(drone)
	_check(hull.material_override == look.material and arm.material_override == look.material, "k17 material applied to every mesh")
	look.notify_hit()
	look.update(0.016, 2, 0.1, false)
	_check(float(look.material.get_shader_parameter("flash")) > 0.5, "k17 hit flash raises shader flash")
	_check(float(look.material.get_shader_parameter("rim_strength")) > 1.0, "k17 wind-up brightens rim before a shot")
	for i in 30:
		look.update(0.05, 2, 1.0, false)
	_check(float(look.material.get_shader_parameter("flash")) == 0.0, "k17 hit flash decays")
	var rim: Color = look.material.get_shader_parameter("rim_color")
	_check(rim.r > 0.9 and rim.g < 0.35, "k17 combat rim turns red")

	var fx = ImpactFX.new()
	world.add_child(fx)
	await process_frame
	for i in 70:
		fx.spawn_impact(Vector3(randf_range(0.6, 2.6), randf_range(0.6, 2.0), -4.04), Vector3.BACK)
	fx.spawn_impact(Vector3(-1.4, 1.1, -2.9), Vector3.BACK, ImpactFX.Surface.METAL, false)
	var visible_decals := 0
	for child in fx.get_children():
		if child is Decal and child.visible:
			visible_decals += 1
	_check(visible_decals == ImpactFX.MAX_DECALS, "decal pool caps at %d (got %d)" % [ImpactFX.MAX_DECALS, visible_decals])
	_check(fx.get_child_count() == ImpactFX.MAX_DECALS + ImpactFX.MAX_BURSTS * 2 + 1, "impact fx node count is fixed")
	fx.show_muzzle_flare(camera.global_position + Vector3(0.25, -0.2, -0.8), Vector3.FORWARD)
	_check(fx.get_node("MuzzleFlare").visible, "muzzle flare shows")
	var basis: Basis = ImpactFX._basis_from_normal(Vector3(0.3, 0.2, 0.9))
	_check(basis.y.is_equal_approx(Vector3(0.3, 0.2, 0.9).normalized()) and basis.determinant() > 0.99, "impact basis follows normal and is right-handed")

	var trauma = CameraTrauma.new()
	world.add_child(trauma)
	trauma.bind(camera)
	trauma.add_trauma(0.8)
	await process_frame
	await process_frame
	_check(absf(camera.h_offset) + absf(camera.v_offset) > 0.0, "camera trauma offsets the camera")
	for i in 90:
		await process_frame
	_check(camera.h_offset == 0.0 and camera.v_offset == 0.0, "camera trauma settles to zero")

	var canvas := CanvasLayer.new()
	world.add_child(canvas)
	var theme := Theme.new()
	UIStyle.apply_fonts(theme)
	_check(theme.default_font != null, "ui style sets a default font")
	var crosshair = Crosshair.new()
	canvas.add_child(crosshair)
	crosshair.theme = theme
	crosshair.set_spread(0.02, 73.0)
	crosshair.show_hit(true)
	var damage = DamageDirection.new()
	canvas.add_child(damage)
	damage.add_source(Vector3(3, 1, 0))
	damage.add_source(Vector3(3.2, 1, 0))
	damage.add_source(Vector3(-4, 1, 2))
	_check(damage._marks.size() == 2, "damage arcs merge nearby sources")
	var title := UIStyle.heading(Label.new(), 30)
	title.text = "FIELD OPERATIONS"
	title.position = Vector2(40, 30)
	canvas.add_child(title)
	var button := Button.new()
	button.text = "DEPLOY"
	button.theme = theme
	button.position = Vector2(40, 90)
	canvas.add_child(button)
	UIStyle.animate_button(button)
	UIStyle.reveal(button, button)

	if render:
		for i in 3:
			fx.spawn_impact(Vector3(-1.4 + randf_range(-0.2, 0.2), 1.1, -2.9), Vector3.BACK, ImpactFX.Surface.METAL, false)
			fx.spawn_impact(Vector3(0.6, 0.02, -2.6), Vector3.UP)
		fx.show_muzzle_flare(camera.global_position + camera.global_transform.basis * Vector3(0.22, -0.18, -0.7), -camera.global_transform.basis.z)
		look.update(0.0, 2, 0.05, false)
		for i in 6:
			await process_frame
		for i in 3:
			fx.spawn_impact(Vector3(-1.4 + randf_range(-0.2, 0.2), 1.1, -2.9), Vector3.BACK, ImpactFX.Surface.METAL, false)
		fx.show_muzzle_flare(camera.global_position + camera.global_transform.basis * Vector3(0.22, -0.18, -0.7), -camera.global_transform.basis.z)
		# Hold the flare for the capture; first frames can exceed its 50 ms life.
		fx._flare_time = 1.0
		crosshair.show_hit(true)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("user://visual_fx_qa")
		var path := ProjectSettings.globalize_path("user://visual_fx_qa/visual_fx.png")
		image.save_png(path)
		print("VISUAL_FX_CAPTURE ", path)

	print("VISUAL_FX_TEST_RESULT: %d failures" % failures)
	quit(1 if failures > 0 else 0)
