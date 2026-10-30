extends RefCounted
## Small geometry helpers shared by the park activity areas. Tubes share one
## unit mesh per radius so a fence or climbing frame stays cheap to draw.

static var _unit_tubes: Dictionary = {}

static func mat(color: Color, roughness := .75, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

static func glow(color: Color) -> StandardMaterial3D:
	var material := mat(color.darkened(.55), .35, .1)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.0
	return material

static func box(parent: Node3D, label: String, size: Vector3, position: Vector3, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation = rotation
	parent.add_child(instance)
	return instance

static func disc(parent: Node3D, label: String, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance

static func tube(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var key := snappedf(radius, .001)
	if not _unit_tubes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = 1.0
		mesh.radial_segments = 10
		mesh.rings = 1
		_unit_tubes[key] = mesh
	var span := b - a
	var up := span.normalized()
	if up.dot(Vector3.UP) < -.999: up = -up
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = _unit_tubes[key]
	instance.material_override = material
	instance.basis = Basis(Quaternion(Vector3.UP, up)) * Basis.from_scale(Vector3(1.0, span.length(), 1.0))
	instance.position = (a + b) * .5
	parent.add_child(instance)
	return instance

static func solid(parent: Node3D, label: String, size: Vector3, position: Vector3, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = position
	body.rotation.y = yaw
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	parent.add_child(body)
	return body

static func flood(parent: Node3D, label: String, position: Vector3, target: Vector3, color: Color, energy: float, reach: float) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.name = label
	light.light_color = color
	light.light_energy = energy
	light.spot_range = reach
	light.spot_angle = 58.0
	light.spot_attenuation = .8
	light.shadow_enabled = false
	light.light_specular = .25
	light.distance_fade_enabled = true
	light.distance_fade_begin = 90.0
	light.distance_fade_length = 30.0
	# Local to the parent, so aim survives the area being moved or rotated.
	light.position = position
	light.basis = Basis.looking_at(target - position)
	parent.add_child(light)
	return light
