extends RefCounted
## Real lawn for the corporate pocket gardens: the park's scanned turf on the
## ground and the park's own grass blades growing on it. Blades are visual only.
## Coordinates are district space.
const Turf = preload("res://scripts/midori_corporate_lawn.gdshader")
const MAPS := "res://assets/shinrai/parks/midori_park/materials/vostok_environment_20261028/"
# Must match the PocketGarden slabs, GardenWalk paths and water basin in district.gd.
const GARDENS: Array[Rect2] = [Rect2(-35, 72, 70, 40), Rect2(-35, -113, 70, 47)]
const WALK_Z: Array[float] = [92.0, -89.5]
const WALK_CLEARANCE := 2.15
const WATER_BASIN := Rect2(-6.4, 97.6, 12.8, 7.8)
const GROUND_Y := .015
const BLADES_PER_M2 := 9.0
const BROAD_FRACTION := .08
const BLADE_GREEN := Color(.46, .66, .38)
const CHUNK := 14.0
const DRAW_RANGE := 70.0
const WAIT_SECONDS := 90
const RNG_SEED := 20261031

static func surface() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = "CorporateLawnTurf"
	material.shader = Turf
	material.set_shader_parameter("turf_albedo", load(MAPS + "leafy_grass/leafy_grass_diff_2k.jpg"))
	material.set_shader_parameter("turf_normal", load(MAPS + "leafy_grass/leafy_grass_nor_gl_1k.jpg"))
	material.set_shader_parameter("turf_roughness", load(MAPS + "leafy_grass/leafy_grass_rough_1k.jpg"))
	material.set_shader_parameter("soil_albedo", load(MAPS + "dirt/dirt_diff_2k.jpg"))
	return material

## The park builds its grass on its own schedule, so this waits for it without
## holding up the district, then borrows the park's meshes and materials.
static func grow(park: Node, district: Node3D) -> void:
	var thin: MultiMeshInstance3D = null
	var broad: MultiMeshInstance3D = null
	for second: int in range(WAIT_SECONDS):
		if not is_instance_valid(park) or not is_instance_valid(district) or not district.is_inside_tree(): return
		thin = _park_grass(park, "ThinUprightGrass_*")
		broad = _park_grass(park, "UprightGrass_*")
		if thin != null and broad != null: break
		await district.get_tree().create_timer(1.0).timeout
	if thin == null or broad == null:
		push_warning("Corporate lawn: park grass not found, keeping turf only")
		return
	var root := Node3D.new()
	root.name = "CorporateLawnGrass"
	root.set_meta("creator_protected", true)
	district.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	var spots: Array[Vector4] = district.get("tree_spots")
	var kinds := {
		0: {"mesh":thin.multimesh.mesh, "material":_mown_green(thin.material_override)},
		1: {"mesh":broad.multimesh.mesh, "material":_mown_green(broad.material_override)},
	}
	var planted := 0
	for i: int in range(GARDENS.size()):
		planted += _plant(root, GARDENS[i], WALK_Z[i], spots, kinds, rng)
	root.set_meta("blades", planted)

## The park's blades are tuned for long dry grass and go yellow in full sun on a
## mown lawn, so the gardens use a greener copy with less light through the leaf.
static func _mown_green(source: Material) -> Material:
	var material := source.duplicate() as Material
	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		var albedo: Color = shader_material.get_shader_parameter("source_albedo")
		shader_material.set_shader_parameter("source_albedo", albedo * BLADE_GREEN)
		var backlight: Color = shader_material.get_shader_parameter("source_backlight")
		shader_material.set_shader_parameter("source_backlight", backlight * .6)
	elif material is StandardMaterial3D:
		(material as StandardMaterial3D).albedo_color *= BLADE_GREEN
	return material

static func _park_grass(park: Node, pattern: String) -> MultiMeshInstance3D:
	var found := park.find_children(pattern, "MultiMeshInstance3D", true, false)
	return found[0] as MultiMeshInstance3D if not found.is_empty() else null

static func _plant(root: Node3D, garden: Rect2, walk_z: float, spots: Array[Vector4], kinds: Dictionary, rng: RandomNumberGenerator) -> int:
	var buckets := {}
	var count := int(garden.get_area() * BLADES_PER_M2)
	var planted := 0
	for i: int in range(count):
		var x := rng.randf_range(garden.position.x + .1, garden.end.x - .1)
		var z := rng.randf_range(garden.position.y + .1, garden.end.y - .1)
		if absf(z - walk_z) < WALK_CLEARANCE or WATER_BASIN.has_point(Vector2(x, z)) or _at_trunk(x, z, spots):
			continue
		var use_broad := rng.randf() < BROAD_FRACTION
		var mesh: Mesh = kinds[1 if use_broad else 0].mesh
		var bounds := mesh.get_aabb()
		var height := rng.randf_range(.22, .34) if use_broad else rng.randf_range(.12, .24)
		var upright := height / bounds.size.y
		var wide := upright * rng.randf_range(1.0, 1.35)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(wide, upright, wide))
		var anchor := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		var cell := Vector2i(floori(x / CHUNK), floori(z / CHUNK))
		var key := Vector3i(cell.x, cell.y, 1 if use_broad else 0)
		if not buckets.has(key): buckets[key] = []
		var centre := (Vector2(cell) + Vector2(.5, .5)) * CHUNK
		buckets[key].append(Transform3D(basis, Vector3(x - centre.x, GROUND_Y + .004, z - centre.y) - basis * anchor))
		planted += 1
	for key: Vector3i in buckets:
		_chunk(root, key, buckets[key], kinds[key.z])
	return planted

static func _at_trunk(x: float, z: float, spots: Array[Vector4]) -> bool:
	for spot: Vector4 in spots:
		if Vector2(x - spot.x, z - spot.z).length_squared() < .16: return true
	return false

static func _chunk(root: Node3D, key: Vector3i, transforms: Array, kind: Dictionary) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = kind.mesh
	multimesh.instance_count = transforms.size()
	multimesh.custom_aabb = AABB(Vector3(-CHUNK * .5 - 1.0, -.02, -CHUNK * .5 - 1.0), Vector3(CHUNK + 2.0, .5, CHUNK + 2.0))
	for i: int in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])
	var grass := MultiMeshInstance3D.new()
	grass.name = "LawnGrass"
	grass.position = Vector3((float(key.x) + .5) * CHUNK, 0, (float(key.y) + .5) * CHUNK)
	grass.multimesh = multimesh
	grass.material_override = kind.material
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.visibility_range_end = DRAW_RANGE
	grass.visibility_range_end_margin = 16.0
	grass.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	root.add_child(grass)
