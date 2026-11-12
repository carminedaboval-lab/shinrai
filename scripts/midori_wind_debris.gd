extends GPUParticles3D
## Dry leaves and scraps of paper skittering past wherever the camera is,
## blown along the same direction as the shared Midori breeze. GPU only: one
## emitter follows the active camera, and particles stay where they fly.
const WIND_DIR := Vector3(0.94, 0.0, 0.34)
const DAY_RATIO := 1.0
const NIGHT_RATIO := 0.35

func _ready() -> void:
	add_to_group("midori_horizon")
	top_level = true
	amount = 70
	lifetime = 7.0
	preprocess = 7.0
	fixed_fps = 30
	local_coords = false
	visibility_aabb = AABB(Vector3(-40, -4, -40), Vector3(80, 10, 80))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	process_material = _motion()
	draw_pass_1 = _flake()
	var park := get_parent()
	set_night_mode(park != null and park.get("is_night_mode") == true)

func set_night_mode(value: bool) -> void:
	amount_ratio = NIGHT_RATIO if value else DAY_RATIO

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	# Emit upwind of the camera, close to the ground, so pieces blow into view.
	global_position = camera.global_position - WIND_DIR * 9.0 + Vector3.DOWN * 1.45

func _motion() -> ParticleProcessMaterial:
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(20.0, 0.5, 20.0)
	motion.direction = Vector3(0.94, 0.12, 0.34)
	motion.spread = 22.0
	motion.initial_velocity_min = 1.0
	motion.initial_velocity_max = 2.8
	motion.gravity = Vector3(0, -0.5, 0)
	motion.damping_min = 0.2
	motion.damping_max = 0.5
	motion.angle_min = 0.0
	motion.angle_max = 360.0
	motion.angular_velocity_min = -220.0
	motion.angular_velocity_max = 220.0
	motion.scale_min = 0.6
	motion.scale_max = 1.25
	motion.turbulence_enabled = true
	motion.turbulence_noise_strength = 1.6
	motion.turbulence_noise_scale = 3.5
	motion.turbulence_influence_min = 0.12
	motion.turbulence_influence_max = 0.32
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.55, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color("#7a5a32"), Color("#a07a3e"), Color("#c9a24a"), Color("#6f6a3a"), Color("#e9e5da")])
	var texture := GradientTexture1D.new()
	texture.gradient = ramp
	motion.color_initial_ramp = texture
	# Cut-out leaves cannot fade, so they grow in and shrink away instead.
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.0))
	grow.add_point(Vector2(0.1, 1.0))
	grow.add_point(Vector2(0.88, 1.0))
	grow.add_point(Vector2(1.0, 0.0))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	motion.scale_curve = grow_texture
	return motion

func _flake() -> QuadMesh:
	# A small leaf silhouette, drawn once into a texture.
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in range(32):
		for x: int in range(32):
			var p := Vector2(float(x) - 15.5, float(y) - 15.5) / 15.5
			var inside := pow(p.x / 0.55, 2.0) + pow(p.y, 2.0) < 1.0 - 0.15 * absf(p.y)
			image.set_pixel(x, y, Color(1, 1, 1, 1) if inside else Color(1, 1, 1, 0))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	# With MSAA there is no temporal smoothing, so hard cut-out flakes blink as they shrink
	# towards a pixel. Fade the edge through the MSAA samples instead; the half-covered
	# outline stays where the 0.5 cut was. TAA and Off sessions keep the plain cut-out.
	if preload("res://scripts/shinrai_settings.gd").session_msaa() != Viewport.MSAA_DISABLED:
		image.generate_mipmaps()
		material.albedo_texture = ImageTexture.create_from_image(image)
		material.alpha_scissor_threshold = 0.25
		material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
		material.alpha_antialiasing_edge = 0.25
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	quad.material = material
	return quad
