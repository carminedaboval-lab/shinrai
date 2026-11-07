extends RefCounted
## Midori Park biomes (docs/PARK_BIOME_PLAN.md, docs/biome_concepts/).
## One soft map of themed grounds laid over the lapsed park. It runs once the
## raid has finished booting, so no producer's placement or random sequence
## changes. It does three things:
##  1. bakes two look maps (2 m per pixel) the shared ground shader reads,
##  2. injects that look into the ground shader, before the worn-path pass,
##  3. hands each biome's area to its own builder (scripts/biomes/*.gd), which
##     thins what does not belong there and adds what does.
## Edges are feathered and wobbled by noise, never drawn as lines.

const ORIGIN := Vector2(-220.0, -180.0)
const SIZE := Vector2(440.0, 360.0)
const RES := 0.5 # look-map pixels per metre

# Look channels. A: leaf litter, care (0 tended, .5 today, 1 overgrown), moss,
# wet. B: pine needles, meadow straw, petals, peat.
const LOOKS := {
	"momiji": [1.0, 0.55, 0.08, 0.0, 0.0, 0.0, 0.0, 0.0],
	"zoki": [0.22, 0.68, 0.55, 0.05, 0.0, 0.0, 0.0, 0.0],
	"matsu": [0.05, 0.4, 0.04, 0.0, 1.0, 0.0, 0.0, 0.0],
	"koke": [0.05, 0.2, 1.0, 0.1, 0.0, 0.0, 0.0, 0.0],
	"mizube": [0.1, 0.62, 0.45, 0.8, 0.0, 0.0, 0.0, 1.0],
	"hanami": [0.0, 0.22, 0.0, 0.0, 0.0, 0.0, 0.08, 0.0],
	"sando": [0.0, 0.0, 0.2, 0.0, 0.0, 0.0, 0.08, 0.0],
	"harappa": [0.0, 0.72, 0.05, 0.0, 0.0, 0.35, 0.0, 0.0],
	"yard": [0.22, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0],
}

# World metres; north is -z. Feather is the soft edge width in metres.
const REGIONS := [
	{"id":"momiji", "shape":"ellipse", "c":Vector2(110, -148), "r":Vector2(70, 30), "f":14.0},
	{"id":"yard", "shape":"ellipse", "c":Vector2(152, -146), "r":Vector2(24, 16), "f":8.0},
	{"id":"matsu", "shape":"ellipse", "c":Vector2(-150, -62), "r":Vector2(64, 52), "f":15.0},
	{"id":"matsu", "shape":"ellipse", "c":Vector2(-104, -140), "r":Vector2(38, 32), "f":15.0},
	{"id":"matsu", "shape":"ellipse", "c":Vector2(185, 40), "r":Vector2(26, 29), "f":10.0},
	{"id":"zoki", "shape":"rect", "x":Vector2(-86, 40), "z":Vector2(-178, -50), "f":12.0},
	{"id":"koke", "shape":"ellipse", "c":Vector2(-14, 20), "r":Vector2(44, 40), "f":12.0},
	{"id":"koke", "shape":"ellipse", "c":Vector2(24, -114), "r":Vector2(18, 18), "f":6.0},
	{"id":"hanami", "shape":"ellipse", "c":Vector2(20, 138), "r":Vector2(96, 40), "f":15.0},
	{"id":"sando", "shape":"ellipse", "c":Vector2(168, 128), "r":Vector2(46, 40), "f":9.0},
	{"id":"harappa", "shape":"ellipse", "c":Vector2(-152, 104), "r":Vector2(66, 74), "f":15.0},
]
# Later regions win where they overlap earlier ones; the shore band wins over all.
const SHORE_FULL_M := 8.0
const SHORE_EDGE_M := 14.0
# Lake bounds plus the shore band; points outside skip the shoreline search.
const LAKE_NEAR := Rect2(10.0, -155.0, 166.0, 272.0)
const BUILDERS := [
	"res://scripts/biomes/maple_glen.gd",
	"res://scripts/biomes/north_coppice.gd",
	"res://scripts/biomes/pine_woods.gd",
	"res://scripts/biomes/moss_garden.gd",
	"res://scripts/biomes/sakura_lawn.gd",
	"res://scripts/biomes/shrine_approach.gd",
	"res://scripts/biomes/meadow.gd",
	# Last: its thinning is keyed on the shore band and must follow the others.
	"res://scripts/biomes/iris_shore.gd",
]

static var _noise: FastNoiseLite

static func noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 52031
		_noise.frequency = 0.035
		_noise.fractal_octaves = 3
	return _noise

## Weight 0..1 of one region at a world point, feathered and wobbled.
static func region_weight(region: Dictionary, p: Vector2) -> float:
	var outside: float
	if region.shape == "ellipse":
		var r: Vector2 = region.r
		var c: Vector2 = region.c
		var d: float = ((p - c) / r).length()
		outside = (d - 1.0) * (r.x + r.y) * 0.5
	else:
		var x: Vector2 = region.x
		var z: Vector2 = region.z
		var q := Vector2(maxf(x.x - p.x, p.x - x.y), maxf(z.x - p.y, p.y - z.y))
		outside = Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)
	var f: float = region.f
	outside += noise().get_noise_2dv(p) * f * 0.45
	return 1.0 - smoothstep(-f * 0.5, f * 0.5, outside)

## Per-biome weights at a world point. Missing ids are zero; "base" gets the rest.
static func weights_at(p: Vector2, terrain: Node = null) -> Dictionary:
	var out := {}
	var left := 1.0
	if terrain != null and terrain.shoreline.size() > 2 and LAKE_NEAR.has_point(p) and not terrain.water_at(p):
		var shore: float = terrain.edge_distance(p, terrain.shoreline)
		shore += noise().get_noise_2dv(p * 1.7) * 3.0
		var w := 1.0 - smoothstep(SHORE_FULL_M, SHORE_EDGE_M, shore)
		if w > 0.0:
			out["mizube"] = w
			left -= w
	var stack := {}
	for region: Dictionary in REGIONS:
		var w: float = region_weight(region, p)
		if w <= 0.0: continue
		var id: String = region.id
		# Later regions take their share from earlier ones.
		for key: String in stack.keys(): stack[key] *= 1.0 - w
		stack[id] = maxf(float(stack.get(id, 0.0)), w)
	for id: String in stack:
		out[id] = float(out.get(id, 0.0)) + stack[id] * left
	var used := 0.0
	for id: String in out: used += out[id]
	out["base"] = maxf(0.0, 1.0 - used)
	return out

static func weight(p: Vector2, id: String, terrain: Node = null) -> float:
	return float(weights_at(p, terrain).get(id, 0.0))

## A dithered yes/no from position: species and thinning interleave at edges
## instead of switching on a line. Uses no RNG.
static func pick(p: Vector2, w: float, salt: int = 0) -> bool:
	var h := absi(hash(Vector3i(floori(p.x * 4.0), floori(p.y * 4.0), salt))) % 10007
	return float(h) / 10007.0 < w

const GROUND_UNIFORMS := """
uniform sampler2D biome_look_a : repeat_disable, filter_linear;
uniform sampler2D biome_look_b : repeat_disable, filter_linear;
uniform sampler2D biome_coppice_weight : repeat_disable, filter_linear;
uniform sampler2D biome_coppice_litter : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool biome_ready = false;
"""

## Value noise is laid on a square grid; read at two rotations with a warp so
## no axis-aligned blocks show in the fine leaf layers.
const GROUND_FUNCTIONS := """
float biome_noise(vec2 p) {
	vec2 w = vec2(midori_floor_noise(p * 0.37 + vec2(5.1, 1.7)), midori_floor_noise(p * 0.37 + vec2(2.9, 8.3))) - 0.5;
	p += w * 1.6;
	float a = midori_floor_noise(mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p);
	float b = midori_floor_noise(mat2(vec2(0.28, -0.96), vec2(0.96, 0.28)) * p * 1.31 + vec2(17.3, 4.1));
	return a * 0.55 + b * 0.45;
}
"""

## Applied after the layered ground and before worn paths, so trails still wear
## through the biome floor.
const GROUND_FRAGMENT := """
	if (biome_ready && landscape_ready) {
		vec2 biome_uv = (world_pos.xz + vec2(220.0, 180.0)) / vec2(440.0, 360.0);
		vec4 la = texture(biome_look_a, biome_uv);
		vec4 lb = texture(biome_look_b, biome_uv);
		vec3 base = ALBEDO / max(scene_light_factor, 0.01);
		float base_luma = dot(base, vec3(0.299, 0.587, 0.114));
		float b_broad = midori_floor_noise(world_pos.xz * 0.21 + vec2(4.4, 6.6));
		float b_mid = midori_floor_noise(world_pos.xz * 1.7 + vec2(2.3, 9.1));
		float coppice = texture(biome_coppice_weight, biome_uv).r;
		float leaf_cover = smoothstep(0.12, 0.62, la.r * (0.7 + 0.5 * b_mid) + (b_broad - 0.5) * 0.25);
		// Inside the coppice, its opaque litter replaces these other looks.
		if (coppice < 1.0) {
			float b_fine = biome_noise(world_pos.xz * 7.9 + vec2(7.7, 1.9));
			float b_leaf = biome_noise(world_pos.xz * 15.0 + vec2(3.3, 0.7));
			// Care: below .5 a richer, darker kept turf; above .5 drier, straw olive.
			float care = la.g - 0.5;
			vec3 kept = base * vec3(0.84, 0.98, 0.78);
			vec3 dry = mix(base, vec3(base_luma) * vec3(1.22, 1.1, 0.72), 0.55);
			base = care < 0.0 ? mix(base, kept, -care * 2.0) : mix(base, dry, care * 2.0);
			// Moss carpet, patchy at low strength and nearly whole at full.
			float moss_cover = smoothstep(0.15, 0.55, la.b * (0.7 + 0.5 * b_mid) - (1.0 - b_broad) * 0.15);
			vec3 moss = vec3(0.105, 0.15, 0.048) * mix(0.75, 1.2, b_fine) * mix(0.85, 1.1, b_broad);
			base = mix(base, moss, moss_cover * 0.92);
			// Pine duff: grey-brown needles, fine speckle.
			float needle_cover = smoothstep(0.1, 0.6, lb.r * (0.75 + 0.4 * b_mid));
			vec3 needles = mix(vec3(0.22, 0.15, 0.10), vec3(0.32, 0.22, 0.15), b_fine) * mix(0.85, 1.08, b_broad);
			base = mix(base, needles, needle_cover * 0.9);
			// Leaf litter: rust, tan, dun and old brown leaves in overlapping drifts,
			// dark gaps between them, the ground's own relief kept underneath.
			float l_a = biome_noise(world_pos.xz * 9.0 + vec2(1.3, 8.2));
			float l_b = biome_noise(world_pos.xz * 23.0 + vec2(6.1, 2.4));
			float l_c = biome_noise(world_pos.xz * 57.0 + vec2(3.7, 9.9));
			vec3 leaves = mix(vec3(0.25, 0.105, 0.04), vec3(0.33, 0.215, 0.095), smoothstep(0.35, 0.65, l_a));
			leaves = mix(leaves, vec3(0.16, 0.095, 0.05), smoothstep(0.6, 0.85, l_b) * 0.8);
			leaves = mix(leaves, vec3(0.23, 0.2, 0.095), smoothstep(0.72, 0.92, b_leaf) * 0.6);
			leaves *= mix(0.62, 1.0, smoothstep(0.15, 0.6, l_c));
			leaves *= mix(0.78, 1.06, b_broad) * mix(0.85, 1.12, base_luma / max(base_luma + 0.12, 0.01) * 1.6);
			base = mix(base, leaves, leaf_cover * 0.94);
			// Meadow: the soil under long grass reads straw and dun.
			float straw = lb.g * smoothstep(0.2, 0.7, b_mid + 0.2);
			base = mix(base, vec3(base_luma) * vec3(1.28, 1.12, 0.66), straw * 0.45);
			// Fallen petals dusting short turf.
			float petal = lb.b * smoothstep(0.8, 0.93, b_leaf) * smoothstep(0.35, 0.7, b_broad);
			base = mix(base, vec3(0.78, 0.6, 0.62), petal * 0.6);
			// Shore peat: dark damp soil in blobs.
			float peat = lb.a * smoothstep(0.25, 0.65, b_mid + 0.15);
			base = mix(base, base * vec3(0.62, 0.6, 0.55), peat * 0.75);
		}
		// Retain individual oak leaves and moss between the three-dimensional
		// drifts. Two orientations break the repeating texture at middle distance.
		if (coppice > 0.0) {
			vec2 uv = world_pos.xz / 2.9;
			mat2 turn = mat2(vec2(0.6, 0.8), vec2(-0.8, 0.6));
			vec3 litter_a = texture(biome_coppice_litter, uv).rgb;
			vec3 litter_b = texture(biome_coppice_litter, turn * uv * 0.83 + vec2(0.37, 0.11)).rgb;
			vec3 woodland = mix(litter_a, litter_b, smoothstep(0.39, 0.60, b_broad));
			vec3 moss_tint = mix(vec3(0.94, 0.94, 0.85), vec3(0.70, 0.91, 0.67), b_broad);
			base = mix(base, woodland * moss_tint * mix(0.78, 1.04, b_mid), coppice);
			NORMAL_MAP = mix(NORMAL_MAP, source_normal, coppice);
			NORMAL_MAP_DEPTH = mix(NORMAL_MAP_DEPTH, 0.29, coppice);
		}
		ALBEDO = base * scene_light_factor;
		float wet = la.a * smoothstep(0.35, 0.75, b_broad);
		ROUGHNESS = mix(ROUGHNESS, ROUGHNESS - 0.18, wet);
		ROUGHNESS = mix(ROUGHNESS, 0.95, leaf_cover * 0.6);
	}
"""

static func install(park: Node3D) -> void:
	var tree := park.get_tree()
	var raid := park.get_node_or_null("ExtractionRun")
	while is_instance_valid(raid) and raid.phase == raid.Phase.BOOT:
		await tree.process_frame
	if not is_instance_valid(park) or park.has_meta("midori_biomes"): return
	if OS.get_environment("MIDORI_BIOMES_OFF") == "1":
		park.set_meta("midori_biomes", {"disabled": true})
		return
	var started := Time.get_ticks_msec()
	var terrain := park.get_node_or_null("MidoriTerrain")
	var material := _ground_material(park)
	var report := {}
	if material != null:
		var maps := await bake(park, terrain)
		_inject(material, maps[0], maps[1], maps[2])
		report["look_maps"] = maps[0].get_size()
	else:
		report["error"] = "ground shader unavailable"
	# MIDORI_BIOMES_ONLY=sakura_lawn,meadow runs just those builders (for checks).
	var only := OS.get_environment("MIDORI_BIOMES_ONLY").split(",", false)
	for path: String in BUILDERS:
		if not only.is_empty() and not only.has(path.get_file().get_basename()): continue
		if not ResourceLoader.exists(path): continue
		var builder: Script = load(path)
		var result = await builder.build(park, terrain)
		report[path.get_file().get_basename()] = result
		if not is_instance_valid(park): return
	report["ms"] = Time.get_ticks_msec() - started
	park.set_meta("midori_biomes", report)
	print("MIDORI_BIOMES ", JSON.stringify(report))

static func _ground_material(park: Node3D) -> ShaderMaterial:
	var terrain := park.get_node_or_null("MidoriTerrain")
	if terrain == null: return null
	for child: Node in terrain.get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial:
			var material: ShaderMaterial = child.material_override
			if material.shader.code.contains("uniform sampler2D landscape_tex"): return material
	return null

static func bake(park: Node3D, terrain: Node) -> Array[Image]:
	var w := int(SIZE.x * RES)
	var h := int(SIZE.y * RES)
	var a := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var b := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var coppice := Image.create(w, h, false, Image.FORMAT_R8)
	for y: int in range(h):
		for x: int in range(w):
			var p := ORIGIN + (Vector2(x, y) + Vector2(0.5, 0.5)) / RES
			var weights := weights_at(p, terrain)
			var look := [0.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
			for id: String in weights:
				if id == "base" or not LOOKS.has(id): continue
				var wt: float = weights[id]
				var values: Array = LOOKS[id]
				for k: int in range(8): look[k] += (float(values[k]) - (0.5 if k == 1 else 0.0)) * wt
			a.set_pixel(x, y, Color(look[0], look[1], look[2], look[3]))
			b.set_pixel(x, y, Color(look[4], look[5], look[6], look[7]))
			coppice.set_pixel(x, y, Color(float(weights.get("zoki", 0.0)), 0.0, 0.0))
		if y % 6 == 0:
			await park.get_tree().process_frame
			if not is_instance_valid(park): return [a, b, coppice]
	return [a, b, coppice]

static func _inject(material: ShaderMaterial, a: Image, b: Image, coppice: Image) -> void:
	if not material.shader.code.contains("uniform bool biome_ready"):
		var parameters := {}
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			parameters[uniform.name] = material.get_shader_parameter(uniform.name)
		var code: String = material.shader.code
		code = code.replace("varying vec3 world_pos;", GROUND_UNIFORMS + "varying vec3 world_pos;")
		code = code.replace("void vertex()", GROUND_FUNCTIONS + "void vertex()")
		# Before the worn-path pass when it is already there, else at the end.
		var at := code.find("\tif (worn_ready) {")
		if at < 0: at = code.rfind("}")
		code = code.insert(at, GROUND_FRAGMENT)
		var shader := Shader.new()
		shader.code = code
		material.shader = shader
		for key: String in parameters: material.set_shader_parameter(key, parameters[key])
	material.set_shader_parameter("biome_look_a", ImageTexture.create_from_image(a))
	material.set_shader_parameter("biome_look_b", ImageTexture.create_from_image(b))
	material.set_shader_parameter("biome_coppice_weight", ImageTexture.create_from_image(coppice))
	material.set_shader_parameter("biome_coppice_litter", preload("res://assets/shinrai/parks/midori_park/materials/coppice_litter/coppice_litter.png"))
	material.set_shader_parameter("biome_ready", true)
