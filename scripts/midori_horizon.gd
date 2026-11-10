extends Node3D
## Distant horizon for Midori Park: an outer sea, two rings of hills and a
## city skyline across the water. Everything here is far beyond the playable
## area, has no collision, and relies on the scene fog for aerial perspective.
const StartupTrace = preload("res://scripts/startup_trace.gd")
const ShaderPool = preload("res://scripts/shinrai_shader_pool.gd")

const SEA_RADIUS_M := 3900.0
const SEA_Y := -0.2 # Below the level activity pads, which sit at datum 0.
const NEAR_HILL_RADIUS_M := 1900.0
const FAR_HILL_RADIUS_M := 3100.0
const CITY_DIRECTION_DEG := 118.0 # Roughly south-east, across the water.
const CITY_DISTANCE_M := 1650.0
const RNG_SEED := 20261029

var _night := false
var _sea_material: ShaderMaterial
var _hill_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	add_to_group("midori_horizon")
	call_deferred("_build")

func _build() -> void:
	var tick := StartupTrace.begin()
	_build_sea()
	# Behind the boot menu each piece gets its own frame (it all ran in the park's
	# add_child frame, the worst frame behind the menu). Same pieces, same order,
	# each with its own seed; a no-op outside the boot.
	await _budget_turn()
	_build_hill_ring("FarHills", FAR_HILL_RADIUS_M, 260.0, 620.0, 384, 28, Color("#45536a"))
	await _budget_turn()
	_build_hill_ring("NearHills", NEAR_HILL_RADIUS_M, 70.0, 230.0, 448, 44, Color("#33472f"))
	await _budget_turn()
	if not is_inside_tree(): return
	var city := Node3D.new()
	city.name = "NeonCity"
	city.set_script(preload("res://scripts/midori_neon_city.gd"))
	add_child(city)
	await _budget_turn()
	if not is_inside_tree(): return
	var near_city := Node3D.new()
	near_city.name = "NearCity"
	near_city.set_script(preload("res://scripts/midori_near_city.gd"))
	add_child(near_city)
	var park := get_parent()
	if park != null and park.get("is_night_mode") != null:
		set_night_mode(bool(park.get("is_night_mode")))
	StartupTrace.finish("horizon.build", tick)

## One frame, not a loading-budget turn: the budget is first come, first served and
## the park's own build (resumed first every frame) would hold the city back for
## ~15 s (measured), moving when the near city builds relative to everything else.
func _budget_turn() -> void:
	var park := get_parent()
	if park != null and park.is_inside_tree() and park.get_meta("shinrai_incremental_loading", false):
		await get_tree().process_frame

func set_night_mode(value: bool) -> void:
	_night = value
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
	st.set_smooth_group(0)
	var city_angle := deg_to_rad(CITY_DIRECTION_DEG)
	var depth := radius * 0.22
	var profile: Array[float] = []
	for i in range(segments):
		var t := float(i) / float(segments)
		var a := t * TAU
		var gap := absf(angle_difference(a, city_angle)) < (float(gap_segments) / float(segments)) * PI
		var h := lerpf(min_height, max_height, clampf((noise.get_noise_1d(t * 40.0) * 0.5 + 0.5) * 1.3 - 0.1, 0.0, 1.0))
		h += noise.get_noise_1d(t * 160.0 + 7.0) * (max_height - min_height) * 0.18
		# Sharp secondary ridges and fine scree break up the long smooth facets.
		h += (1.0 - absf(noise.get_noise_1d(t * 420.0 + 3.0)) * 2.0) * (max_height - min_height) * 0.07
		h += noise.get_noise_1d(t * 1500.0 + 11.0) * (max_height - min_height) * 0.022
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
	# Pooled: both hill rings share one shader (tint and tree line are uniforms).
	var shader := ShaderPool.shader("""
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
""")
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
