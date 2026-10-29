extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")

# Attach once as a child of the park root. Never replaces its procedural sky.
const CLOUD_SHADER = preload("res://scripts/midori_calm_clouds.gdshader")
@export_range(0.0, 1.0) var coverage := 0.46
@export_range(0.0, 2.0) var drift_metres_per_second := 0.35
@export_range(0.0, 1.5) var daylight_cloud_brightness := 0.64
var material: ShaderMaterial
var dome: MeshInstance3D
var _host_has_night := false
var _host_has_sun := false
var _night := false

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	material = ShaderMaterial.new()
	material.shader = CLOUD_SHADER
	material.render_priority = -100
	material.set_shader_parameter("coverage", coverage)
	material.set_shader_parameter("drift_speed", drift_metres_per_second)
	material.set_shader_parameter("daylight_brightness", daylight_cloud_brightness)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	sphere.flip_faces = true
	dome = MeshInstance3D.new()
	dome.name = "CalmCloudDome"
	dome.mesh = sphere
	dome.material_override = material
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(dome)
	for property: Dictionary in get_parent().get_property_list():
		_host_has_night = _host_has_night or property.name == "is_night_mode"
		_host_has_sun = _host_has_sun or property.name == "park_directional_light"
	set_night_mode(_night)

func set_night_mode(enabled: bool) -> void:
	_night = enabled
	if material != null:
		material.set_shader_parameter("night_amount", 1.0 if enabled else 0.0)

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or dome == null:
		return
	global_position = camera.global_position
	# Inside the far plane, behind the park; scale is independent of doubled root.
	global_basis = Basis.IDENTITY
	dome.scale = Vector3.ONE * maxf(camera.far * 0.94, 10.0)
	if _host_has_night:
		var enabled := bool(get_parent().get("is_night_mode"))
		if enabled != _night:
			set_night_mode(enabled)
	if _host_has_sun:
		var light := get_parent().get("park_directional_light") as DirectionalLight3D
		if is_instance_valid(light):
			material.set_shader_parameter("sun_direction", light.global_basis.z.normalized())
