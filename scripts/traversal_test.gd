extends Node3D

const PlayerScript = preload("res://scripts/player.gd")

var concrete: StandardMaterial3D
var climb_surface: StandardMaterial3D
var route_surface: StandardMaterial3D

func _ready() -> void:
	_build_materials()
	_build_environment()
	_build_course()
	_spawn_player()
	_build_instructions()

func _build_materials() -> void:
	concrete = _material(Color(0.20, 0.23, 0.27), 0.88)
	climb_surface = _material(Color(0.12, 0.42, 0.52), 0.72)
	route_surface = _material(Color(0.50, 0.20, 0.10), 0.76)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.075, 0.105)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.64, 0.70, 0.82)
	environment.ambient_light_energy = 1.45
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color(0.78, 0.86, 1.0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	add_child(sun)

func _build_course() -> void:
	_add_box("Ground", Vector3(18.0, 0.50, 38.0), Vector3(0.0, -0.25, -2.0), concrete)
	_add_box("VaultBarrier", Vector3(5.0, 0.90, 0.55), Vector3(0.0, 0.45, 7.0), climb_surface)
	_add_label("VAULT", Vector3(0.0, 1.45, 7.0))
	_add_box("LowRoof", Vector3(5.0, 1.35, 3.0), Vector3(0.0, 0.675, 2.0), route_surface)
	_add_label("CLIMB", Vector3(0.0, 2.05, 2.0))
	_add_box("HighRoof", Vector3(5.0, 2.55, 3.0), Vector3(0.0, 1.275, -2.7), concrete)
	_add_box("GapRoof", Vector3(5.0, 2.55, 4.0), Vector3(0.0, 1.275, -9.0), route_surface)
	_add_label("ROOFTOP GAP", Vector3(0.0, 3.25, -6.0))
	_add_box("WindowLeft", Vector3(1.75, 3.2, 0.35), Vector3(-1.65, 4.15, -11.15), concrete)
	_add_box("WindowRight", Vector3(1.75, 3.2, 0.35), Vector3(1.65, 4.15, -11.15), concrete)
	_add_box("WindowTop", Vector3(1.55, 0.45, 0.35), Vector3(0.0, 5.525, -11.15), concrete)
	_add_box("WindowSill", Vector3(1.55, 0.55, 0.45), Vector3(0.0, 3.025, -11.15), climb_surface)
	_add_box("LandingRoof", Vector3(5.0, 2.55, 4.0), Vector3(0.0, 1.275, -14.0), concrete)

func _add_box(part_name: String, size: Vector3, position_value: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = part_name
	body.position = position_value
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _add_label(text_value: String, position_value: Vector3) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.font_size = 54
	label.outline_size = 10
	label.modulate = Color(0.80, 0.94, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _spawn_player() -> void:
	var player := CharacterBody3D.new()
	player.name = "TraversalPlayer"
	player.set_script(PlayerScript)
	player.position = Vector3(0.0, 0.05, 12.5)
	add_child(player)

func _build_instructions() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := ColorRect.new()
	panel.position = Vector2(18.0, 72.0)
	panel.size = Vector2(550.0, 74.0)
	panel.color = Color(0.02, 0.025, 0.04, 0.78)
	canvas.add_child(panel)
	var label := Label.new()
	label.position = Vector2(16.0, 10.0)
	label.text = "TRAVERSAL BLOCKOUT\nWASD + Shift · Space jump / vault / climb · F7 return"
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F7:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
