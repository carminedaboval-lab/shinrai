extends Node
## Balanced atmosphere preset. Kept separate from procedural geometry.

func _ready() -> void:
	for child in get_parent().get_children():
		if child is WorldEnvironment:
			_apply_environment(child.environment)
		elif child is DirectionalLight3D and child.name == "OvercastSun":
			child.light_angular_distance = 1.5
			child.directional_shadow_max_distance = 65.0
			child.light_volumetric_fog_energy = 0.35
	_configure_lights.call_deferred(get_parent())
	_configure_visibility.call_deferred(get_parent())

func _apply_environment(env: Environment) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.10, 0.15, 0.22)
	sky_material.sky_horizon_color = Color(0.32, 0.37, 0.42)
	sky_material.ground_bottom_color = Color(0.055, 0.065, 0.08)
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.sky_energy_multiplier = 0.65
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_color = Color(0.62, 0.68, 0.78)
	env.ambient_light_energy = 1.9
	# Depth fog reaches full opacity before the camera's far clip.
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 25.0
	env.fog_depth_end = 125.0
	env.fog_depth_curve = 1.5
	env.fog_density = 1.0
	env.fog_light_color = Color(0.32, 0.38, 0.45)
	env.fog_sky_affect = 0.35
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		return
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.009
	env.volumetric_fog_length = 80.0
	env.volumetric_fog_albedo = Color(0.72, 0.79, 0.86)
	env.volumetric_fog_ambient_inject = 0.25
	env.volumetric_fog_sky_affect = 0.35
	env.ssao_enabled = true
	env.ssao_radius = 0.7
	env.ssao_intensity = 1.2
	env.ssao_power = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.18
	env.glow_hdr_threshold = 1.4
	env.glow_bloom = 0.0

func _configure_lights(node: Node, moving: bool = false) -> void:
	moving = moving or node is CharacterBody3D
	for child in node.get_children():
		if child is OmniLight3D or child is SpotLight3D:
			# Fade local light work with distance; preserve architectural silhouettes.
			child.distance_fade_enabled = true
			child.distance_fade_begin = 32.0
			child.distance_fade_length = 16.0
			# Moving weapon lights must not leave temporal trails in the fog.
			child.light_volumetric_fog_energy = 0.0 if moving else 0.15
		_configure_lights(child, moving)

func _configure_visibility(node: Node, apartment: bool = false) -> void:
	apartment = apartment or node.is_in_group("shinrai_reference_apartment")
	# Structural details must not disappear independently in readable space.
	# The camera clips geometry only after depth fog is fully opaque.
	if node is GeometryInstance3D and node.visibility_range_end > 0.0:
		if apartment:
			node.visibility_range_end = 0.0
			node.visibility_range_end_margin = 0.0
		else:
			node.visibility_range_end = maxf(node.visibility_range_end, 80.0)
			node.visibility_range_end_margin = 15.0
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if node is Camera3D:
		node.far = 130.0
	for child in node.get_children():
		_configure_visibility(child, apartment)
