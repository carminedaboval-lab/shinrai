extends Node3D
## Neon metropolis around the island park. Far beyond the playable area with no
## collision: every tower shares one MultiMesh and one shader, so the whole
## skyline costs a handful of draws. The shader does its own aerial haze because
## scene fog would swallow the lights at this distance.
const RNG_SEED := 20500118
const STAGE_CHANCE := .55
# Direction from the park (degrees), distance, width, tower count, tallest tower.
const DISTRICTS := [
	{"dir":118.0, "dist":1650.0, "width":1500.0, "towers":150, "peak":380.0},
	{"dir":62.0, "dist":1500.0, "width":1100.0, "towers":90, "peak":240.0},
	{"dir":178.0, "dist":1550.0, "width":1200.0, "towers":90, "peak":260.0},
	{"dir":242.0, "dist":1700.0, "width":1300.0, "towers":100, "peak":300.0},
	{"dir":318.0, "dist":1600.0, "width":1100.0, "towers":80, "peak":220.0},
]

const TOWER_SHADER := """
shader_type spatial;
render_mode fog_disabled;
uniform float night = 0.0;
uniform vec3 haze_day = vec3(0.80, 0.76, 0.70);
uniform vec3 haze_night = vec3(0.045, 0.04, 0.09);
varying vec3 size;
varying vec3 local;
varying vec3 local_normal;
varying vec3 world;
varying float tower_seed;
float hsh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex(){
	tower_seed = INSTANCE_CUSTOM.x;
	size = INSTANCE_CUSTOM.yzw * 1000.0;
	local = (VERTEX + vec3(0.0, 0.5, 0.0)) * size;
	local_normal = NORMAL;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment(){
	vec3 an = abs(local_normal);
	float roof = step(0.5, an.y);
	float across = an.x > 0.5 ? local.z : local.x;
	float width = an.x > 0.5 ? size.z : size.x;
	float s = tower_seed;
	// Lit floor blocks, sized to survive 1.5 km: a block is several real windows.
	vec2 cell = floor(vec2(across / 7.0, local.y / 6.0));
	vec2 f = fract(vec2(across / 7.0, local.y / 6.0));
	float pane = step(0.14, f.x) * step(f.x, 0.86) * step(0.2, f.y) * step(f.y, 0.8);
	float far = smoothstep(0.35, 1.0, fwidth(across) / 7.0);
	float lit = step(0.56 - s * 0.12, hsh(cell + s * 91.0));
	vec3 tint = mix(vec3(1.0, 0.76, 0.48), vec3(0.62, 0.84, 1.0), step(0.62, hsh(cell.yx + s * 17.0)));
	float glass = mix(pane, 0.72, far);
	vec3 windows = tint * lit * mix(pane, 0.62, far) * 0.62;
	// Neon: corner tubes, a crown ring and scrolling advert panels on some towers.
	vec3 hue = s < 0.36 ? vec3(1.0, 0.1, 0.46) : (s < 0.7 ? vec3(0.1, 0.85, 1.0) : vec3(0.62, 0.22, 1.0));
	float corner = step(0.42, s) * (1.0 - smoothstep(1.0, 3.0, width * 0.5 - abs(across)));
	float crown = step(size.y - 7.0, local.y) * step(local.y, size.y - 2.0);
	float pulse = 0.82 + 0.18 * sin(TIME * (0.7 + s * 1.3) + s * 40.0);
	vec2 panel = vec2(abs(across) / max(width * 0.34, 1.0), abs(local.y - size.y * (0.52 + s * 0.28)) / max(size.y * 0.13, 12.0));
	float has_panel = step(0.55, fract(s * 7.31)) * (1.0 - step(1.0, max(panel.x, panel.y)));
	float bars = 0.55 + 0.45 * sin(local.y * 0.11 + TIME * (0.6 + s) + sin(across * 0.08 + s * 30.0) * 2.0);
	vec3 advert = mix(hue, hue.gbr, smoothstep(0.2, 0.8, sin(local.y * 0.02 - TIME * 0.3 + s * 9.0) * 0.5 + 0.5)) * bars * 1.3;
	vec3 emission = mix(windows, advert, has_panel) + hue * (corner + crown) * 1.7 * pulse;
	emission *= 1.0 - roof;
	vec3 day = mix(vec3(0.17, 0.2, 0.25), vec3(0.3, 0.33, 0.37), glass * (0.5 + 0.5 * hsh(vec2(s, 3.0))));
	day = mix(day, vec3(0.22), roof);
	float dist = length(world - CAMERA_POSITION_WORLD);
	float haze = 1.0 - exp(-dist * mix(0.00085, 0.00022, night));
	vec3 hazed = mix(day * mix(1.0, 0.14, night), mix(haze_day, haze_night, night), haze);
	ALBEDO = night > 0.5 ? vec3(0.0) : hazed;
	EMISSION = (night > 0.5 ? hazed * 0.35 : vec3(0.0)) + emission * night * mix(1.0, 0.62, haze);
	ROUGHNESS = 0.6;
	METALLIC = 0.0;
	SPECULAR = 0.2;
}
"""

const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 tint = vec3(1.0, 0.2, 0.6);
uniform float night = 0.0;
void fragment(){
	float across = 1.0 - smoothstep(0.1, 1.0, abs(UV.x - 0.5) * 2.0);
	// UV.y is 0 at the top of the quad: fade to nothing well before that edge.
	float rise = smoothstep(0.0, 0.85, UV.y);
	ALBEDO = mix(tint.brg * 0.6 + vec3(0.12, 0.05, 0.3), tint, rise) * across * rise * rise * 0.42 * night;
}
"""

const BEACON_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled;
uniform float night = 0.0;
varying float phase;
void vertex(){ phase = INSTANCE_CUSTOM.x; }
void fragment(){
	float blink = step(0.72, fract(TIME * 0.45 + phase));
	ALBEDO = vec3(0.0);
	EMISSION = vec3(1.0, 0.1, 0.06) * blink * night * 6.0;
}
"""

var _materials: Array[ShaderMaterial] = []
var _glows: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("midori_horizon")
	_build()
	var horizon := get_parent()
	var park := horizon.get_parent() if horizon != null else null
	set_night_mode(park != null and park.get("is_night_mode") == true)

func set_night_mode(value: bool) -> void:
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("night", 1.0 if value else 0.0)
	for glow: MeshInstance3D in _glows:
		glow.visible = value

func _material(code: String, label: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	material.resource_name = label
	_materials.append(material)
	return material

func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	var towers: Array[Dictionary] = []
	var beacons: Array[Dictionary] = []
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color("#10131a")
	ground.roughness = 1.0
	ground.disable_fog = true
	for district: Dictionary in DISTRICTS:
		var angle := deg_to_rad(float(district.dir))
		# Local X runs along the shoreline, local +Z points away from the park.
		var root := Transform3D(Basis(Vector3.UP, PI * .5 - angle), Vector3(cos(angle), 0.0, sin(angle)) * float(district.dist))
		var half := float(district.width) * .5
		_add_land(root, float(district.width), ground)
		_add_glow(root, float(district.width), float(district.peak), rng.randf())
		for i: int in range(int(district.towers)):
			# Taller toward the middle, like a real business district.
			var x := rng.randf_range(-half, half) * .92
			var z := rng.randf_range(-170.0, 170.0)
			var centre := 1.0 - clampf(absf(x) / half, 0.0, 1.0)
			var height := rng.randf_range(45.0, 95.0) + centre * centre * rng.randf_range(.3, 1.0) * float(district.peak)
			_add_tower(root, Vector3(x, 0.0, z), height, rng, towers, beacons)
	_commit_towers(towers)
	_commit_beacons(beacons)

func _add_tower(root: Transform3D, at: Vector3, height: float, rng: RandomNumberGenerator, towers: Array[Dictionary], beacons: Array[Dictionary]) -> void:
	var tower_seed := rng.randf()
	var yaw := rng.randf_range(-.1, .1)
	var size := Vector3(rng.randf_range(32.0, 62.0), height, rng.randf_range(32.0, 62.0))
	var base := 0.0
	# Setbacks give stepped silhouettes rather than a row of plain slabs.
	var stages := 1 if rng.randf() > STAGE_CHANCE or height < 110.0 else rng.randi_range(2, 3)
	for stage: int in range(stages):
		var share := 1.0 if stage == stages - 1 else rng.randf_range(.42, .62)
		var stage_height := (height - base) * share
		var part := Vector3(size.x, stage_height, size.z)
		var basis := root.basis * Basis(Vector3.UP, yaw) * Basis.from_scale(part)
		var origin: Vector3 = root * (at + Vector3.UP * (base + stage_height * .5))
		towers.append({"transform":Transform3D(basis, origin), "custom":Color(tower_seed, part.x / 1000.0, part.y / 1000.0, part.z / 1000.0)})
		base += stage_height
		size *= Vector3(rng.randf_range(.62, .8), 1.0, rng.randf_range(.62, .8))
	if height > 150.0:
		var spire := rng.randf_range(18.0, 52.0)
		var top := at + Vector3.UP * base
		var basis := root.basis * Basis.from_scale(Vector3(3.0, spire, 3.0))
		towers.append({"transform":Transform3D(basis, root * (top + Vector3.UP * spire * .5)), "custom":Color(.99, .003, spire / 1000.0, .003)})
		beacons.append({"position":root * (top + Vector3.UP * spire), "phase":rng.randf()})

func _commit_towers(towers: Array[Dictionary]) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = towers.size()
	for i: int in range(towers.size()):
		multimesh.set_instance_transform(i, towers[i].transform)
		multimesh.set_instance_custom_data(i, towers[i].custom)
	var instance := MultiMeshInstance3D.new()
	instance.name = "NeonTowers"
	instance.multimesh = multimesh
	instance.material_override = _material(TOWER_SHADER, "SHINRAI_NeonTowers")
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(instance)

func _commit_beacons(beacons: Array[Dictionary]) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	var mesh := BoxMesh.new()
	mesh.size = Vector3(5.0, 5.0, 5.0)
	multimesh.mesh = mesh
	multimesh.instance_count = beacons.size()
	for i: int in range(beacons.size()):
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, beacons[i].position))
		multimesh.set_instance_custom_data(i, Color(beacons[i].phase, 0, 0, 0))
	var instance := MultiMeshInstance3D.new()
	instance.name = "AviationBeacons"
	instance.multimesh = multimesh
	instance.material_override = _material(BEACON_SHADER, "SHINRAI_Beacons")
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _add_land(root: Transform3D, width: float, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 10.0, 420.0)
	var land := MeshInstance3D.new()
	land.name = "CityLand"
	land.mesh = mesh
	land.material_override = material
	land.transform = root * Transform3D(Basis.IDENTITY, Vector3(0.0, -2.0, 0.0))
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(land)

func _add_glow(root: Transform3D, width: float, peak: float, shade: float) -> void:
	# Light pollution rising off the district, facing the park.
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width * 1.5, peak * 2.4 + 320.0)
	var glow := MeshInstance3D.new()
	glow.name = "CitySkyGlow"
	glow.mesh = mesh
	var material := _material(GLOW_SHADER, "SHINRAI_CitySkyGlow")
	material.set_shader_parameter("tint", Color("#ff2f8a").lerp(Color("#3a7bff"), shade))
	glow.material_override = material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.transform = root * Transform3D(Basis.IDENTITY, Vector3(0.0, mesh.size.y * .5 - 6.0, 240.0))
	add_child(glow)
	_glows.append(glow)
