extends Node3D
## The test yard: 90 m of flat ground with plain cover of real sizes (a house-sized block,
## head-high walls, waist-high walls, crates, car-sized blocks). It exists to try enemies in
## seconds instead of after a park boot. Plain grey on purpose: it is a test room, not art.

const HALF := 44
const TALL := 2.4
const LOW := 1.0

## [centre x, centre z, size x, height, size z, kind]
const PIECES: Array = [
	[-18.0, -8.0, 10.0, 3.0, 7.0, "building"],
	[20.0, 6.0, 8.0, 3.0, 12.0, "building"],
	[0.0, -6.0, 6.0, TALL, 0.3, "wall"],
	[-6.0, 10.0, 0.3, TALL, 7.0, "wall"],
	[10.0, -18.0, 5.0, TALL, 0.3, "wall"],
	[-24.0, 20.0, 7.0, TALL, 0.3, "wall"],
	[4.0, 4.0, 5.0, LOW, 0.3, "low_wall"],
	[-12.0, 2.0, 0.3, LOW, 5.0, "low_wall"],
	[12.0, -8.0, 4.0, LOW, 0.3, "low_wall"],
	[-2.0, 18.0, 6.0, LOW, 0.3, "low_wall"],
	[26.0, -20.0, 0.3, LOW, 6.0, "low_wall"],
	[-3.0, -12.0, 1.2, 1.2, 1.2, "crate"],
	[6.0, -11.0, 1.2, 1.2, 1.2, "crate"],
	[-9.0, -18.0, 1.2, 1.2, 1.2, "crate"],
	[14.0, -2.0, 1.2, 1.2, 1.2, "crate"],
	[-14.0, 14.0, 1.2, 1.2, 1.2, "crate"],
	[8.0, 14.0, 1.2, 1.2, 1.2, "crate"],
	[2.0, -20.0, 1.2, 2.4, 1.2, "crate"],
	[-20.0, 4.0, 1.2, 2.4, 1.2, "crate"],
	[-4.0, -2.0, 4.4, 1.4, 1.8, "car"],
	[9.0, 22.0, 1.8, 1.4, 4.4, "car"],
	[-22.0, -22.0, 4.4, 1.4, 1.8, "car"],
	[18.0, -26.0, 4.4, 1.4, 1.8, "car"],
]

var visuals := true


func build() -> void:
	name = "TestYard"
	_box("Ground", Vector3(0, -0.5, 0), Vector3(HALF * 2 + 12, 1.0, HALF * 2 + 12), Color(0.36, 0.37, 0.35))
	for side: float in [-1.0, 1.0]:
		_box("Edge", Vector3(side * (HALF + 1.0), 1.5, 0), Vector3(0.4, 3.0, HALF * 2 + 4), Color(0.30, 0.30, 0.29))
		_box("Edge", Vector3(0, 1.5, side * (HALF + 1.0)), Vector3(HALF * 2 + 4, 3.0, 0.4), Color(0.30, 0.30, 0.29))
	for piece: Array in PIECES:
		var colour := Color(0.52, 0.51, 0.48)
		match str(piece[5]):
			"building": colour = Color(0.58, 0.56, 0.52)
			"crate": colour = Color(0.45, 0.38, 0.29)
			"car": colour = Color(0.30, 0.34, 0.38)
		_box(str(piece[5]).capitalize(), Vector3(piece[0], float(piece[3]) * 0.5, piece[1]), Vector3(piece[2], piece[3], piece[4]), colour)
	if not visuals: return
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)


func _box(label: String, centre: Vector3, size: Vector3, colour: Color) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = centre
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	if visuals:
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_instance.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 0.9
		mesh_instance.material_override = material
		body.add_child(mesh_instance)
	add_child(body, true)
