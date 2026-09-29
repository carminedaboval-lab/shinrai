extends Node3D

# Replaces the irregular perimeter net in the supplied one-mesh pitch GLB.
# Dimensions are world metres; the caller cancels the park's 2x layout scale.
const HALF_LENGTH := 19.9
const HALF_WIDTH := 10.55
const HEIGHT := 4.45
const NET_BOTTOM := 1.24
const GATE_HALF_WIDTH := 1.35
const PANEL_SPAN := 2.75
const HOLE_SIZE := 0.105

var _net_material: ShaderMaterial
var _frame_material: StandardMaterial3D
var _body: StaticBody3D
var _post_positions: Array[Vector3] = []

func build() -> void:
	_net_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
void fragment() {
	float diagonal_a = abs(fract(UV.x + UV.y) - 0.5);
	float diagonal_b = abs(fract(UV.x - UV.y) - 0.5);
	float distance_to_wire = min(diagonal_a, diagonal_b);
	float wire = 1.0 - smoothstep(0.035, 0.095, distance_to_wire);
	ALBEDO = vec3(0.32, 0.39, 0.38);
	METALLIC = 0.08;
	ROUGHNESS = 0.82;
	ALPHA = wire;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
}
"""
	_net_material.shader = shader
	_frame_material = StandardMaterial3D.new()
	_frame_material.albedo_color = Color("#34413f")
	_frame_material.metallic = 0.16
	_frame_material.roughness = 0.75
	_body = StaticBody3D.new()
	_body.name = "PitchPerimeterCollision"
	_body.collision_layer = 1
	add_child(_body)

	# The north touchline faces the park path. Its central 2.7 m gap is a real
	# entrance in both the render mesh and collision, so the pitch is playable.
	_add_span("South", Vector3(-HALF_LENGTH, 0, -HALF_WIDTH), Vector3(HALF_LENGTH, 0, -HALF_WIDTH))
	_add_span("NorthLeft", Vector3(-HALF_LENGTH, 0, HALF_WIDTH), Vector3(-GATE_HALF_WIDTH, 0, HALF_WIDTH))
	_add_span("NorthRight", Vector3(GATE_HALF_WIDTH, 0, HALF_WIDTH), Vector3(HALF_LENGTH, 0, HALF_WIDTH))
	_add_span("WestGoalEnd", Vector3(-HALF_LENGTH, 0, -HALF_WIDTH), Vector3(-HALF_LENGTH, 0, HALF_WIDTH))
	_add_span("EastGoalEnd", Vector3(HALF_LENGTH, 0, -HALF_WIDTH), Vector3(HALF_LENGTH, 0, HALF_WIDTH))
	_add_bar("GateHeader", Vector3(-GATE_HALF_WIDTH, HEIGHT, HALF_WIDTH), Vector3(GATE_HALF_WIDTH, HEIGHT, HALF_WIDTH), 0.10)
	_add_posts()

func _add_span(label: String, start: Vector3, finish: Vector3) -> void:
	var length := start.distance_to(finish)
	var sections := maxi(1, ceili(length / PANEL_SPAN))
	for index: int in range(sections):
		var a := start.lerp(finish, float(index) / float(sections))
		var b := start.lerp(finish, float(index + 1) / float(sections))
		_add_net_panel("%s_Net_%02d" % [label, index + 1], a, b)
		_register_post(a)
		_register_post(b)
	_add_bar(label + "_TopRail", start + Vector3.UP * HEIGHT, finish + Vector3.UP * HEIGHT, 0.095)
	_add_bar(label + "_BaseRail", start + Vector3.UP * NET_BOTTOM, finish + Vector3.UP * NET_BOTTOM, 0.11)
	_add_kickboard(label, start, finish)
	var collision := CollisionShape3D.new()
	collision.name = label + "_FenceCollider"
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, HEIGHT, 0.13)
	collision.shape = shape
	collision.position = (start + finish) * 0.5 + Vector3.UP * (HEIGHT * 0.5)
	collision.rotation.y = -atan2(finish.z - start.z, finish.x - start.x)
	_body.add_child(collision)

func _add_kickboard(label: String, start: Vector3, finish: Vector3) -> void:
	# The source model has a ragged low stone/net skirt. A solid inner-facing
	# plinth covers it on both sides and anchors the new regular mesh visually.
	var midpoint := (start + finish) * 0.5
	var inward := Vector3(-midpoint.x, 0.0, -midpoint.z).normalized()
	var plinth := MeshInstance3D.new()
	plinth.name = label + "_Kickboard"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(start.distance_to(finish), NET_BOTTOM, 1.6)
	var material := _frame_material.duplicate() as StandardMaterial3D
	material.albedo_color = Color("#293633")
	mesh.material = material
	plinth.mesh = mesh
	plinth.position = midpoint + inward * 0.55 + Vector3.UP * (NET_BOTTOM * 0.5)
	plinth.rotation.y = -atan2(finish.z - start.z, finish.x - start.x)
	add_child(plinth)

func _add_net_panel(label: String, start: Vector3, finish: Vector3) -> void:
	var length := start.distance_to(finish)
	var vertices := PackedVector3Array([
		start + Vector3.UP * NET_BOTTOM,
		finish + Vector3.UP * NET_BOTTOM,
		finish + Vector3.UP * (HEIGHT - 0.05),
		start + Vector3.UP * (HEIGHT - 0.05),
	])
	var uvs := PackedVector2Array([
		Vector2.ZERO,
		Vector2(length / HOLE_SIZE, 0),
		Vector2(length / HOLE_SIZE, (HEIGHT - NET_BOTTOM) / HOLE_SIZE),
		Vector2(0, (HEIGHT - NET_BOTTOM) / HOLE_SIZE),
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _net_material)
	var panel := MeshInstance3D.new()
	panel.name = label
	panel.mesh = mesh
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(panel)

func _add_bar(label: String, start: Vector3, finish: Vector3, thickness: float) -> void:
	var bar := MeshInstance3D.new()
	bar.name = label
	var mesh := BoxMesh.new()
	mesh.size = Vector3(start.distance_to(finish), thickness, thickness)
	mesh.material = _frame_material
	bar.mesh = mesh
	bar.position = (start + finish) * 0.5
	bar.rotation.y = -atan2(finish.z - start.z, finish.x - start.x)
	add_child(bar)

func _register_post(position_value: Vector3) -> void:
	for existing: Vector3 in _post_positions:
		if existing.distance_squared_to(position_value) < 0.0001:
			return
	_post_positions.append(position_value)

func _add_posts() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.13, HEIGHT, 0.13)
	mesh.material = _frame_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = _post_positions.size()
	for index: int in range(_post_positions.size()):
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, _post_positions[index] + Vector3.UP * (HEIGHT * 0.5)))
	var posts := MultiMeshInstance3D.new()
	posts.name = "PitchSteelPosts"
	posts.multimesh = multimesh
	add_child(posts)
