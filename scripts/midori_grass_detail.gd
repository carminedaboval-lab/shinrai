extends Node

# Lightweight near-camera 3D grass/leaf tufts for the Midori Park review scene.
# The flat park material remains the base; this adds small living blades above it
# with deterministic placement and a gentle wind sway. Paths, water and the
# current zone placeholders are excluded so the tufts only appear on lawn.

const PARK_HALF := Vector2(110.0, 90.0)
const GRASS_INSTANCE_COUNT := 4200
const GRASS_Y := 0.018
const VISIBILITY_RANGE_M := 38.0
const VISIBILITY_MARGIN_M := 10.0
const RNG_SEED := 20260916

var _installed := false


func _ready() -> void:
	call_deferred("_install_grass")


func _install_grass() -> void:
	if _installed:
		return
	var scene := get_tree().current_scene
	if scene == null:
		call_deferred("_install_grass")
		return
	if String(scene.name) != "MidoriParkSizeBlockout":
		return

	var existing := scene.get_node_or_null("MidoriGrassDetail")
	if existing != null:
		_installed = true
		return

	var grass_mesh := _build_grass_clump_mesh()
	if grass_mesh == null:
		return

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = grass_mesh
	multimesh.instance_count = GRASS_INSTANCE_COUNT

	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	var placed := 0
	var attempts := 0
	var max_attempts := GRASS_INSTANCE_COUNT * 18

	while placed < GRASS_INSTANCE_COUNT and attempts < max_attempts:
		attempts += 1
		var x := rng.randf_range(-PARK_HALF.x + 2.0, PARK_HALF.x - 2.0)
		var z := rng.randf_range(-PARK_HALF.y + 2.0, PARK_HALF.y - 2.0)
		if not _is_lawn_position(x, z):
			continue

		var yaw := rng.randf_range(0.0, TAU)
		var width_scale := rng.randf_range(0.72, 1.25)
		var height_scale := rng.randf_range(0.70, 1.38)
		var basis := Basis(Vector3.UP, yaw)
		basis = basis.scaled(Vector3(width_scale, height_scale, width_scale))
		var position := Vector3(x, GRASS_Y + rng.randf_range(-0.002, 0.004), z)
		multimesh.set_instance_transform(placed, Transform3D(basis, position))
		placed += 1

	# In the unlikely event exclusions prevent filling every slot, hide leftovers
	# under the park rather than leaving identity transforms at the origin.
	for index: int in range(placed, GRASS_INSTANCE_COUNT):
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(0.0, -100.0, 0.0)))

	var grass := MultiMeshInstance3D.new()
	grass.name = "MidoriGrassDetail"
	grass.multimesh = multimesh
	grass.visibility_range_end = VISIBILITY_RANGE_M
	grass.visibility_range_end_margin = VISIBILITY_MARGIN_M
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(grass)
	_installed = true


func _build_grass_clump_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var height := 0.070
	var half_width := 0.010
	for blade_index: int in range(3):
		var angle := float(blade_index) * PI / 3.0
		var side := Vector3(cos(angle), 0.0, sin(angle)) * half_width
		var lean := Vector3(cos(angle + 1.1), 0.0, sin(angle + 1.1)) * (0.006 + float(blade_index) * 0.0015)
		var blade_height := height * (0.88 + float(blade_index) * 0.07)
		var p0 := -side
		var p1 := side
		var p2 := side + Vector3(0.0, blade_height, 0.0) + lean
		var p3 := -side + Vector3(0.0, blade_height, 0.0) + lean
		_add_triangle(surface, p0, p1, p2, Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0))
		_add_triangle(surface, p0, p2, p3, Vector2(0.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0))

	surface.generate_normals()
	var mesh := surface.commit()
	if mesh == null:
		return null

	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec4 grass_color : source_color = vec4(0.22, 0.39, 0.16, 1.0);
uniform float sway_amount = 0.0075;
uniform float sway_speed = 1.35;

void vertex() {
	float tip = clamp(VERTEX.y / 0.075, 0.0, 1.0);
	float phase = MODEL_MATRIX[3].x * 0.21 + MODEL_MATRIX[3].z * 0.17;
	float wave = sin(TIME * sway_speed + phase) * sway_amount * tip * tip;
	VERTEX.x += wave;
	VERTEX.z += cos(TIME * (sway_speed * 0.82) + phase * 1.7) * sway_amount * 0.45 * tip * tip;
}

void fragment() {
	float height_tint = clamp(UV.y, 0.0, 1.0);
	vec3 base_col = grass_color.rgb * mix(1.12, 0.72, height_tint);
	ALBEDO = base_col;
	ROUGHNESS = 0.93;
}
"""
	mesh.surface_set_material(0, material)
	return mesh


func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	surface.set_uv(uv_a)
	surface.add_vertex(a)
	surface.set_uv(uv_b)
	surface.add_vertex(b)
	surface.set_uv(uv_c)
	surface.add_vertex(c)


func _is_lawn_position(x: float, z: float) -> bool:
	# Perimeter loop path.
	if abs(z + 77.0) < 3.4 and abs(x) < 99.5:
		return false
	if abs(z - 77.0) < 3.4 and abs(x) < 99.5:
		return false
	if abs(x + 97.0) < 3.4 and abs(z) < 79.5:
		return false
	if abs(x - 97.0) < 3.4 and abs(z) < 79.5:
		return false

	# Main cross paths.
	if abs(x + 37.0) < 3.2 and abs(z) < 77.0:
		return false
	if abs(z - 42.0) < 3.2 and abs(x) < 97.0:
		return false

	# Lake lobes, with a little safety margin around their visible surfaces.
	if _inside_ellipse(x, z, 27.0, -10.0, 57.0, 38.0):
		return false
	if _inside_ellipse(x, z, 47.0, -42.0, 37.0, 26.0):
		return false
	if _inside_ellipse(x, z, 8.0, 20.0, 33.0, 23.0):
		return false

	# Current colored zone placeholders. These can be relaxed later when the
	# blockout becomes final terrain.
	if _inside_box(x, z, -70.0, -43.0, 59.0, 40.0):
		return false
	if _inside_box(x, z, -72.0, 45.0, 36.0, 30.0):
		return false
	if _inside_box(x, z, 62.0, 51.0, 48.0, 38.0):
		return false
	if _inside_box(x, z, 76.0, -64.0, 24.0, 18.0):
		return false

	return true


func _inside_ellipse(x: float, z: float, center_x: float, center_z: float, radius_x: float, radius_z: float) -> bool:
	var dx := (x - center_x) / radius_x
	var dz := (z - center_z) / radius_z
	return dx * dx + dz * dz <= 1.0


func _inside_box(x: float, z: float, center_x: float, center_z: float, width: float, depth: float) -> bool:
	return abs(x - center_x) <= width * 0.5 and abs(z - center_z) <= depth * 0.5
