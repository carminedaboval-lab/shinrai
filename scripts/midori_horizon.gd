extends Node3D
## Distant horizon for Midori Park: an outer sea, two rings of hills and a
## city skyline across the water. Everything here is far beyond the playable
## area, has no collision, and relies on the scene fog for aerial perspective.
const StartupTrace = preload("res://scripts/startup_trace.gd")

const SEA_RADIUS_M := 3900.0
const SEA_Y := 0.06
const NEAR_HILL_RADIUS_M := 1900.0
const FAR_HILL_RADIUS_M := 3100.0
const CITY_DIRECTION_DEG := 118.0 # Roughly south-east, across the water.
const CITY_DISTANCE_M := 1650.0
const RNG_SEED := 20261029

var _night := false
var _sea_material: ShaderMaterial
var _city_window_material: StandardMaterial3D
var _hill_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	add_to_group("midori_horizon")
	call_deferred("_build")

func _build() -> void:
	var tick := StartupTrace.begin()
	_build_sea()
	_build_hill_ring("FarHills", FAR_HILL_RADIUS_M, 260.0, 620.0, 96, 7, Color("#45536a"))
	_build_hill_ring("NearHills", NEAR_HILL_RADIUS_M, 70.0, 230.0, 112, 11, Color("#33472f"))
	_build_city()
	var park := get_parent()
	if park != null and park.get("is_night_mode") != null:
		set_night_mode(bool(park.get("is_night_mode")))
	StartupTrace.finish("horizon.build", tick)

func set_night_mode(value: bool) -> void:
	_night = value
	if _city_window_material != null:
		_city_window_material.emission_energy_multiplier = 2.6 if value else 0.0
	if _sea_material != null:
		_sea_material.set_shader_parameter("night", 1.0 if value else 0.0)

# ---------------------------------------------------------------- sea

func _build_sea() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_back, depth_draw_opaque;
uniform float night = 0.0;
varying vec3 world_pos;
float hsh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float nz(vec2 p){ vec2 c = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hsh(c), hsh(c+vec2(1,0)), u.x), mix(hsh(c+vec2(0,1)), hsh(c+vec2(1,1)), u.x), u.y); }
void vertex(){ world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 p = world_pos.xz;
	float swell = nz(p * 0.012 + vec2(TIME * 0.02, TIME * 0.011)) * 0.6 + nz(p * 0.05 - vec2(TIME * 0.03, 0.0)) * 0.4;
	vec3 day = mix(vec3(0.10, 0.21, 0.28), vec3(0.16, 0.30, 0.36), swell);
	vec3 nightc = mix(vec3(0.015, 0.03, 0.06), vec3(0.03, 0.05, 0.09), swell);
	ALBEDO = mix(day, nightc, night);
	// Small normal wobble so the sun lays a glitter path on the water.
	vec3 n = normalize(vec3(nz(p * 0.9 + TIME * 0.15) - 0.5, 6.0, nz(p * 0.9 - TIME * 0.12) - 0.5));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
"""
	_sea_material = ShaderMaterial.new()
	_sea_material.shader = shader
	_sea_material.resource_name = "SHINRAI_OuterSea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(SEA_RADIUS_M * 2.0, SEA_RADIUS_M * 2.0)
	plane.subdivide_depth = 8
	plane.subdivide_width = 8
	var sea := MeshInstance3D.new()
	sea.name = "OuterSea"
	sea.mesh = plane
	sea.material_override = _sea_material
	sea.position = Vector3(0.0, SEA_Y, 0.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(sea)

# -------------------------------------------------------------- hills

func _build_hill_ring(ring_name: String, radius: float, min_height: float, max_height: float, segments: int, gap_segments: int, tint: Color) -> void:
	# A closed ring of peaks around the park, broken where the city sits so
	# the skyline reads against open sky.
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED + ring_name.hash()
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.9
	noise.fractal_octaves = 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var city_angle := deg_to_rad(CITY_DIRECTION_DEG)
	var depth := radius * 0.22
	var profile: Array[float] = []
	for i in range(segments):
		var t := float(i) / float(segments)
		var a := t * TAU
		var gap := absf(angle_difference(a, city_angle)) < (float(gap_segments) / float(segments)) * PI
		var h := lerpf(min_height, max_height, clampf((noise.get_noise_1d(t * 40.0) * 0.5 + 0.5) * 1.3 - 0.1, 0.0, 1.0))
		h += noise.get_noise_1d(t * 160.0 + 7.0) * (max_height - min_height) * 0.18
		if gap:
			h = min_height * 0.25
		profile.append(h)
	# Two bands: a ridge line and a lower front skirt, so the silhouette has a
	# foothill step instead of a single sawtooth.
	for i in range(segments):
		var i2 := (i + 1) % segments
		var a1 := float(i) / float(segments) * TAU
		var a2 := float(i2) / float(segments) * TAU
		var h1 := profile[i]
		var h2 := profile[i2]
		var r_in := radius
		var r_out := radius + depth
		var base1 := Vector3(cos(a1) * r_out, -4.0, sin(a1) * r_out)
		var base2 := Vector3(cos(a2) * r_out, -4.0, sin(a2) * r_out)
		var peak1 := Vector3(cos(a1) * (r_in + depth * 0.55), h1, sin(a1) * (r_in + depth * 0.55))
		var peak2 := Vector3(cos(a2) * (r_in + depth * 0.55), h2, sin(a2) * (r_in + depth * 0.55))
		var foot1 := Vector3(cos(a1) * r_in, -4.0, sin(a1) * r_in)
		var foot2 := Vector3(cos(a2) * r_in, -4.0, sin(a2) * r_in)
		var skirt1 := Vector3(cos(a1) * (r_in + depth * 0.22), h1 * 0.38, sin(a1) * (r_in + depth * 0.22))
		var skirt2 := Vector3(cos(a2) * (r_in + depth * 0.22), h2 * 0.38, sin(a2) * (r_in + depth * 0.22))
		# Front face (toward the park): foot -> skirt -> peak.
		_quad(st, foot1, foot2, skirt2, skirt1)
		_quad(st, skirt1, skirt2, peak2, peak1)
		# Back face so nothing is see-through from odd angles.
		_quad(st, peak1, peak2, base2, base1)
	st.generate_normals()
	var mesh := st.commit()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform vec4 base_tint : source_color = vec4(0.2, 0.28, 0.18, 1.0);
uniform float tree_line = 180.0;
varying vec3 world_pos;
varying vec3 world_normal;
float hsh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float nz(vec2 p){ vec2 c = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hsh(c), hsh(c+vec2(1,0)), u.x), mix(hsh(c+vec2(0,1)), hsh(c+vec2(1,1)), u.x), u.y); }
void vertex(){ world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; world_normal = normalize((MODEL_MATRIX * vec4(NORMAL,0.0)).xyz); }
void fragment(){
	// Forested lower slopes, rocky upper slopes, a little snow on the highest peaks.
	float n = nz(world_pos.xz * 0.004) * 0.6 + nz(world_pos.xz * 0.02) * 0.4;
	vec3 forest = base_tint.rgb * mix(0.8, 1.15, n);
	vec3 rock = vec3(0.36, 0.36, 0.38) * mix(0.75, 1.1, n);
	float h = world_pos.y + (n - 0.5) * 90.0;
	vec3 c = mix(forest, rock, smoothstep(tree_line * 0.8, tree_line * 1.3, h));
	c = mix(c, vec3(0.86, 0.88, 0.92), smoothstep(tree_line * 2.1, tree_line * 2.6, h) * step(0.55, world_normal.y));
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.resource_name = "SHINRAI_Horizon_" + ring_name
	material.set_shader_parameter("base_tint", tint)
	material.set_shader_parameter("tree_line", max_height * 0.42)
	_hill_materials.append(material)
	var instance := MeshInstance3D.new()
	instance.name = ring_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(instance)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
	st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)

# --------------------------------------------------------------- city

func _build_city() -> void:
	# A cluster of tower blocks on a low spit of land across the water. Boxes
	# only: at 1.6 km they read as silhouette and lit windows, nothing more.
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED + 77
	var root := Node3D.new()
	root.name = "DistantCity"
	var angle := deg_to_rad(CITY_DIRECTION_DEG)
	root.position = Vector3(cos(angle) * CITY_DISTANCE_M, 0.0, sin(angle) * CITY_DISTANCE_M)
	root.rotation.y = -angle
	add_child(root)
	var ground := BoxMesh.new()
	ground.size = Vector3(1500.0, 10.0, 420.0)
	var land := MeshInstance3D.new()
	land.name = "CitySpit"
	land.mesh = ground
	var land_material := StandardMaterial3D.new()
	land_material.albedo_color = Color("#3a4350")
	land_material.roughness = 1.0
	land.material_override = land_material
	land.position = Vector3(0.0, -2.0, 0.0)
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(land)

	var body_material := StandardMaterial3D.new()
	body_material.resource_name = "SHINRAI_CityBlock"
	body_material.albedo_color = Color("#6b7684")
	body_material.roughness = 0.85
	_city_window_material = StandardMaterial3D.new()
	_city_window_material.resource_name = "SHINRAI_CityWindows"
	_city_window_material.albedo_color = Color("#2a313b")
	_city_window_material.emission_enabled = true
	_city_window_material.emission = Color("#ffc98a")
	_city_window_material.emission_energy_multiplier = 0.0
	_city_window_material.roughness = 0.6

	var blocks := MultiMesh.new()
	blocks.transform_format = MultiMesh.TRANSFORM_3D
	blocks.mesh = BoxMesh.new()
	var windows := MultiMesh.new()
	windows.transform_format = MultiMesh.TRANSFORM_3D
	windows.mesh = BoxMesh.new()
	var count := 64
	blocks.instance_count = count
	windows.instance_count = count
	for i in range(count):
		# Taller toward the middle of the cluster, like a real CBD.
		var x := rng.randf_range(-620.0, 620.0)
		var z := rng.randf_range(-150.0, 150.0)
		var centre := 1.0 - clampf(absf(x) / 620.0, 0.0, 1.0)
		var h := rng.randf_range(40.0, 90.0) + centre * centre * rng.randf_range(80.0, 260.0)
		var w := rng.randf_range(28.0, 60.0)
		var d := rng.randf_range(28.0, 60.0)
		var basis := Basis(Vector3.UP, rng.randf_range(-0.12, 0.12)).scaled(Vector3(w, h, d))
		blocks.set_instance_transform(i, Transform3D(basis, Vector3(x, h * 0.5, z)))
		# Window band: a slightly smaller box inset on the lit faces.
		var wb := Basis(basis.get_rotation_quaternion()).scaled(Vector3(w * 1.02, h * 0.92, d * 0.985))
		windows.set_instance_transform(i, Transform3D(wb, Vector3(x, h * 0.5, z)))
	var block_instance := MultiMeshInstance3D.new()
	block_instance.name = "CityBlocks"
	block_instance.multimesh = blocks
	block_instance.material_override = body_material
	block_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(block_instance)
	var window_instance := MultiMeshInstance3D.new()
	window_instance.name = "CityWindows"
	window_instance.multimesh = windows
	window_instance.material_override = _city_window_material
	window_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(window_instance)
