extends Node3D

# Metric enclosure shared by the remastered pitch and interactive gate.
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
// Half-width of one wire in pattern units: where the old cut-out sat
// (smoothstep(0.035, 0.095, d) crossing the 0.45 threshold).
const float HALF_WIRE = 0.067;
// Share of a pixel footprint of width w, centred on x, that one family of
// wires covers: the exact box filter of a wire on every half-integer.
float wire_cover(float x, float w) {
	float f = fract(x - 0.5 * w);
	float e = f + w;
	float lo = 0.5 - HALF_WIRE;
	float c0 = clamp(f - lo, 0.0, 2.0 * HALF_WIRE);
	float c1 = floor(e) * 2.0 * HALF_WIRE + clamp(fract(e) - lo, 0.0, 2.0 * HALF_WIRE);
	return clamp((c1 - c0) / w, 0.0, 1.0);
}
void fragment() {
	float sa = UV.x + UV.y;
	float sb = UV.x - UV.y;
	float wa = max(length(vec2(dFdx(sa), dFdy(sa))), 0.0001);
	float wb = max(length(vec2(dFdx(sb), dFdy(sb))), 0.0001);
	// Near: a one-pixel soft wire edge. Far: each diagonal settles on its true
	// average cover, so the net reads as its real 25 % veil instead of moire.
	float ca = mix(wire_cover(sa, wa), 2.0 * HALF_WIRE, smoothstep(0.25, 0.6, wa));
	float cb = mix(wire_cover(sb, wb), 2.0 * HALF_WIRE, smoothstep(0.25, 0.6, wb));
	ALBEDO = vec3(0.32, 0.39, 0.38);
	METALLIC = 0.08;
	ROUGHNESS = 0.82;
	// Blended, no scissor: depth_prepass_alpha still writes depth for solid wire.
	ALPHA = 1.0 - (1.0 - ca) * (1.0 - cb);
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
	# Thin rebound boards now align with the existing 130 mm fence collider.
	# The old bulky plinth is unnecessary after retiring the ragged source mesh.
	var midpoint := (start + finish) * 0.5
	var plinth := MeshInstance3D.new()
	plinth.name = label + "_Kickboard"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(start.distance_to(finish), NET_BOTTOM, 0.13)
	var material := _frame_material.duplicate() as StandardMaterial3D
	material.albedo_color = Color("#293633")
	mesh.material = material
	plinth.mesh = mesh
	plinth.position = midpoint + Vector3.UP * (NET_BOTTOM * 0.5)
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
