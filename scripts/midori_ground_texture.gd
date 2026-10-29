extends Node

# Midori Park forest floor. This only replaces the ground material; it does
# not touch the existing 3D grass blades, sakura, shrubs, paths, or park layout.
# When the Poly Haven PBR maps are present they are tiled at their authored 2 m
# real-world size. The previous procedural material remains as a safe fallback
# while Godot is importing the downloaded images.

const TARGET_SCENE_NAME := "MidoriParkSizeBlockout"
const TARGET_GROUND_NAME := "ParkGround_220x180m"
const TEXTURE_WORLD_SIZE_M := 2.0
# Trail overlays and paved shoulders retain their established forest-floor
# palette. Include the 1 m mask's bilinear footprint outside their visible edge.
const PATH_LAYER_FADE_M := Vector2(1.5, 3.0)
# Trails are at most .825 m wide on each side; rounding the 1 m route grid can
# shift their centre by .283 m. Bilinear filtering can include a sample up to
# a full 1.414 m cell diagonal away, so the hold covers all contributing texels.
const TRAIL_LAYER_FADE_M := Vector2(2.6, 3.8)

const DIFFUSE_PATH := "res://assets/shinrai/parks/midori_park/materials/forrest_ground_01/forrest_ground_01_diff_2k.jpg"
const NORMAL_PATH := "res://assets/shinrai/parks/midori_park/materials/forrest_ground_01/forrest_ground_01_nor_gl_2k.jpg"
const ROUGHNESS_PATH := "res://assets/shinrai/parks/midori_park/materials/forrest_ground_01/forrest_ground_01_rough_2k.jpg"
# Independent CC0 scanned turf and compacted earth, both authored at 2 m.
# The established forest-floor scan remains the woodland and bank surface.
const GROUND_LAYER_ROOT := "res://assets/shinrai/parks/midori_park/materials/vostok_environment_20261028/"
const GROUND_LAYER_MAPS := {
    "turf_albedo_tex": "leafy_grass/leafy_grass_diff_2k.jpg",
    "turf_normal_tex": "leafy_grass/leafy_grass_nor_gl_1k.jpg",
    "turf_roughness_tex": "leafy_grass/leafy_grass_rough_1k.jpg",
    "soil_albedo_tex": "dirt/dirt_diff_2k.jpg",
    "soil_normal_tex": "dirt/dirt_nor_gl_1k.jpg",
    "soil_roughness_tex": "dirt/dirt_rough_1k.jpg"
}

# Shared with the island/bank material by its owner: identical world-space
# palette at dry joins, while each material keeps its own wetness and normals.
const EARTH_PALETTE_GLSL := """
float midori_floor_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float midori_floor_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(midori_floor_hash(cell), midori_floor_hash(cell + vec2(1.0, 0.0)), u.x),
		mix(midori_floor_hash(cell + vec2(0.0, 1.0)), midori_floor_hash(cell + vec2(1.0, 1.0)), u.x), u.y);
}
vec3 midori_forest_floor(vec3 scan_rgb, vec2 p) {
	vec2 drift = vec2(midori_floor_noise(p * 0.075 + vec2(11.4, 3.7)), midori_floor_noise(p * 0.075 + vec2(2.6, 21.8)));
	float broad = midori_floor_noise(p * 0.045 + drift * 0.65 + vec2(7.3, 2.8));
	float middle = midori_floor_noise(p * 0.16 + vec2(31.2, 17.6));
	float fine_patch = midori_floor_noise(p * 0.53 + vec2(5.7, 43.1));
	float luma = dot(scan_rgb, vec3(0.2126, 0.7152, 0.0722));
	// Preserve scanned litter contrast with muted brown soil and sparse olive growth.
	vec3 earth = mix(scan_rgb, luma * vec3(1.12, 0.86, 0.66), 0.90);
	vec3 muted_growth = luma * vec3(0.61, 0.70, 0.48);
	float scanned_green = smoothstep(0.012, 0.075, scan_rgb.g - max(scan_rgb.r * 0.98, scan_rgb.b * 1.5));
	float growth_patch = smoothstep(0.59, 0.79, broad * 0.52 + middle * 0.35 + fine_patch * 0.13);
	float growth = clamp(growth_patch * 0.25 + scanned_green * 0.06, 0.0, 0.35);
	float moisture = mix(0.78, 0.98, middle * 0.65 + fine_patch * 0.35);
	return mix(earth, muted_growth, growth) * moisture * 0.58;
}
"""

var _installed := false
var _night_mode := true
var _active_ground_material: ShaderMaterial
var landscape_ready := false
var landscape_report: Dictionary = {}


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_try_install")


func _on_node_added(_node: Node) -> void:
	if not _installed:
		call_deferred("_try_install")


func _try_install() -> void:
	if _installed:
		return

	var scene := get_tree().current_scene
	if scene == null or String(scene.name) != TARGET_SCENE_NAME:
		return

	var ground := scene.find_child(TARGET_GROUND_NAME, true, false)
	if ground == null:
		return

	var ground_mesh: MeshInstance3D = null
	for child: Node in ground.get_children():
		if child is MeshInstance3D:
			ground_mesh = child as MeshInstance3D
			break
	if ground_mesh == null:
		return

	var material := _build_ground_material()
	ground_mesh.material_override = material
	if material is ShaderMaterial:
		_active_ground_material = material as ShaderMaterial
		_apply_time_factor()
	_installed = true
	call_deferred("_install_landscape_mask",scene)


func set_night_mode(value: bool) -> void:
	_night_mode = value
	_apply_time_factor()


func _apply_time_factor() -> void:
	if _active_ground_material != null:
		# Surface reflectance stays constant; the scene's actual lighting owns time
		# of day. Avoid an extra daylight boost on the supplied forest-floor scan.
		_active_ground_material.set_shader_parameter("scene_light_factor", 1.0)


func _build_ground_material() -> Material:
	if (
		ResourceLoader.exists(DIFFUSE_PATH)
		and ResourceLoader.exists(NORMAL_PATH)
		and ResourceLoader.exists(ROUGHNESS_PATH)
	):
		var diffuse := load(DIFFUSE_PATH) as Texture2D
		var normal := load(NORMAL_PATH) as Texture2D
		var roughness := load(ROUGHNESS_PATH) as Texture2D
		if diffuse != null and normal != null and roughness != null:
			return _build_poly_haven_material(diffuse, normal, roughness)

	return _build_procedural_fallback()


func _build_poly_haven_material(diffuse: Texture2D, normal: Texture2D, roughness: Texture2D) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float texture_world_size_m = 2.0;
uniform bool independent_layers_ready = false;
uniform sampler2D turf_albedo_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D turf_normal_tex : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D turf_roughness_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_albedo_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_normal_tex : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_roughness_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float independent_layer_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 grass_handoff_distances = vec2(48.0, 74.0);
uniform float grass_handoff_strength : hint_range(0.0, 1.0) = 0.35;
uniform sampler2D landscape_tex : repeat_disable, filter_linear;
uniform bool landscape_ready = false;
uniform float scene_light_factor = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 ground_uv = world_pos.xz / texture_world_size_m;
	// Evaluate gradients before the varying protected-zone branch so all six
	// optional samples keep defined mip selection at the mask boundary.
	vec2 ground_uv_dx = dFdx(ground_uv);
	vec2 ground_uv_dy = dFdy(ground_uv);
	vec3 ground_color = texture(albedo_tex, ground_uv).rgb;
	float source_roughness = texture(roughness_tex, ground_uv).r;
	vec3 source_normal = texture(normal_tex, ground_uv).rgb;

	vec3 earth = midori_forest_floor(ground_color, world_pos.xz);
	vec4 zones = texture(landscape_tex, (world_pos.xz + vec2(220.0,180.0)) / vec2(440.0,360.0));
	float broad = midori_floor_noise(world_pos.xz*.085 + vec2(18.3,7.1));
	float fine = midori_floor_noise(world_pos.xz*.68 + vec2(7.0,31.0));
	float patch = smoothstep(.22,.68,broad*.78+fine*.22);
	// Retain real scanned grass, moss, twigs and leaves at their authored scale.
	// Open turf and shaded litter share this supplied scan; no synthetic texture.
	float luma = dot(ground_color,vec3(.2126,.7152,.0722));
	float scanned_growth = smoothstep(.004,.055,ground_color.g-max(ground_color.r*.94,ground_color.b*1.35));
	vec3 turf = mix(luma*vec3(.43,.62,.29),ground_color*vec3(.65,.83,.56),.45+scanned_growth*.40);
	turf *= mix(.72,.92,patch);
	vec3 litter = mix(earth,ground_color*vec3(.68,.61,.47),.40);
 // Shaded woodland retains warm scanned litter; exposed soil gently varies
 // with moisture instead of making a repeated uniform band at paved edges.
 litter*=mix(vec3(.94,.96,.93),vec3(1.08,1.02,.94),broad)*mix(1.0,.96,zones.g);
	float cover = zones.r*mix(.70,1.0,patch);
	vec3 landscape = mix(litter,turf,cover);
	landscape = mix(landscape,earth,zones.b);
	ALBEDO = (landscape_ready ? landscape : earth) * scene_light_factor;
	ROUGHNESS = clamp(source_roughness * 0.94 + 0.06, 0.78, 1.0);
	SPECULAR = 0.08;
	NORMAL_MAP = source_normal;
	NORMAL_MAP_DEPTH = 0.32;
    // Alpha independently fades the new scans outside established path/trail
    // shoulders. RGB keeps the original turf/canopy/bank distribution unchanged.
    float layer_strength = independent_layer_strength * zones.a;
    // Protected banks and held path shoulders keep the exact baseline outputs
    // above, including normals, and skip all six additional texture reads.
    if (landscape_ready && independent_layers_ready && zones.b < 1.0 && layer_strength > 0.0) {
        // Material choice follows existing canopy/worn-edge/shore masks.
        // Offset UVs break alignment between scans without rotating tangent normals.
        vec2 turf_uv = ground_uv + vec2(0.31, 0.67);
        vec2 soil_uv = ground_uv + vec2(0.71, 0.23);
        vec3 turf_scan = textureGrad(turf_albedo_tex, turf_uv, ground_uv_dx, ground_uv_dy).rgb;
        vec3 soil_scan = textureGrad(soil_albedo_tex, soil_uv, ground_uv_dx, ground_uv_dy).rgb;
        vec3 turf_normal = textureGrad(turf_normal_tex, turf_uv, ground_uv_dx, ground_uv_dy).rgb * 2.0 - 1.0;
        vec3 soil_normal = textureGrad(soil_normal_tex, soil_uv, ground_uv_dx, ground_uv_dy).rgb * 2.0 - 1.0;
        float turf_roughness = textureGrad(turf_roughness_tex, turf_uv, ground_uv_dx, ground_uv_dy).r;
        float soil_roughness = textureGrad(soil_roughness_tex, soil_uv, ground_uv_dx, ground_uv_dy).r;
        // Anti-tiling: blend a rotated, rescaled second read of the same scan.
        // The 2 m repeat no longer lines up into a visible grid across open lawn.
        mat2 rot = mat2(vec2(0.819, 0.574), vec2(-0.574, 0.819));
        vec2 turf_uv2 = rot * ground_uv * 0.61 + vec2(3.17, 1.42);
        vec2 soil_uv2 = rot * ground_uv * 0.73 + vec2(1.93, 4.21);
        float tile_mix = smoothstep(0.35, 0.65, midori_floor_noise(world_pos.xz * 0.21 + vec2(13.0, 9.0)));
        turf_scan = mix(turf_scan, textureGrad(turf_albedo_tex, turf_uv2, ground_uv_dx * 0.61, ground_uv_dy * 0.61).rgb, tile_mix);
        soil_scan = mix(soil_scan, textureGrad(soil_albedo_tex, soil_uv2, ground_uv_dx * 0.73, ground_uv_dy * 0.73).rgb, tile_mix);
        // Lawn colour field shared with the upright grass blades: lush low
        // pockets and sun-dried rises instead of one uniform green.
        float lawn_field = broad * 0.6 + midori_floor_noise(world_pos.xz * 0.16 + vec2(31.2, 17.6)) * 0.4;
        vec3 lawn_tint = mix(vec3(0.80, 0.98, 0.82), vec3(1.08, 1.00, 0.72), smoothstep(0.30, 0.75, lawn_field));
        vec3 scanned_turf = turf_scan * vec3(0.80, 0.88, 0.72) * lawn_tint * mix(0.90, 1.08, patch);
        vec3 scanned_soil = soil_scan * vec3(0.82, 0.82, 0.78) * mix(0.90, 1.04, broad);
        // Thin moss creeping into the turf/soil join and under canopy.
        float moss = smoothstep(0.55, 0.85, midori_floor_noise(world_pos.xz * 0.38 + vec2(41.0, 5.0))) * zones.g * 0.55;
        scanned_soil = mix(scanned_soil, scanned_soil * vec3(0.72, 0.98, 0.62), moss);
        // Canopy selects litter, open cover selects turf, and worn shoulders
        // select soil. The protected shoreline/apron band keeps its accepted material.
        float supported = 1.0 - zones.b;
        float soil_weight = smoothstep(0.15, 0.75, (1.0 - zones.r) * (1.0 - zones.g)) * supported;
        float turf_weight = cover * supported;
        vec3 layered = mix(litter, scanned_turf, turf_weight);
        layered = mix(layered, scanned_soil, soil_weight);
        layered = mix(layered, earth, zones.b);
        // Match the darker average coverage of upright grass as its geometry fades.
        // Broad patch variation remains; this is a subtle handoff, not a flat color.
        float ground_distance = length(CAMERA_POSITION_WORLD.xz - world_pos.xz);
        float far_grass = smoothstep(grass_handoff_distances.x, grass_handoff_distances.y, ground_distance);
        far_grass *= grass_handoff_strength * turf_weight * (1.0 - soil_weight);
        layered = mix(layered, scanned_turf * vec3(0.82, 0.90, 0.78), far_grass);
        vec3 layered_normal = mix(source_normal * 2.0 - 1.0, turf_normal, turf_weight);
        layered_normal = mix(layered_normal, soil_normal, soil_weight);
        layered_normal = mix(layered_normal, source_normal * 2.0 - 1.0, zones.b);
        float layered_roughness = mix(source_roughness, turf_roughness, turf_weight);
        layered_roughness = mix(layered_roughness, soil_roughness, soil_weight);
        layered_roughness = mix(layered_roughness, source_roughness, zones.b);
        ALBEDO = mix(landscape, layered, layer_strength) * scene_light_factor;
        vec3 final_normal = mix(source_normal * 2.0 - 1.0, normalize(layered_normal), layer_strength);
        NORMAL_MAP = normalize(final_normal) * 0.5 + 0.5;
        ROUGHNESS = mix(ROUGHNESS, clamp(layered_roughness * 0.94 + 0.06, 0.72, 1.0), layer_strength);
        NORMAL_MAP_DEPTH = mix(0.32, 0.42, max(turf_weight, soil_weight) * layer_strength);
    }
}
"""
	shader.code = shader.code.replace("void vertex()", EARTH_PALETTE_GLSL + "\nvoid vertex()")

	var material := ShaderMaterial.new()
	material.resource_name = "SHINRAI_Midori_TurfLitterSoil_ScannedLayers_V4"
	material.shader = shader
	material.set_shader_parameter("albedo_tex", diffuse)
	material.set_shader_parameter("normal_tex", normal)
	material.set_shader_parameter("roughness_tex", roughness)
	material.set_shader_parameter("texture_world_size_m", TEXTURE_WORLD_SIZE_M)
	var layers: Dictionary = {}
	for parameter: String in GROUND_LAYER_MAPS:
		var path: String = GROUND_LAYER_ROOT + GROUND_LAYER_MAPS[parameter]
		if not ResourceLoader.exists(path):
			push_warning("Midori ground layers unavailable; preserving established forest-floor material")
			return material
		var texture := load(path) as Texture2D
		if texture == null: return material
		layers[parameter] = texture
	for parameter: String in layers:
		material.set_shader_parameter(parameter, layers[parameter])
	material.set_shader_parameter("independent_layers_ready", true)
	return material


func _build_procedural_fallback() -> ShaderMaterial:
	var macro_noise := FastNoiseLite.new()
	macro_noise.seed = 31027
	macro_noise.frequency = 0.018
	macro_noise.fractal_octaves = 5

	var macro_texture := NoiseTexture2D.new()
	macro_texture.width = 512
	macro_texture.height = 512
	macro_texture.seamless = true
	macro_texture.normalize = true
	macro_texture.noise = macro_noise

	var fine_noise := FastNoiseLite.new()
	fine_noise.seed = 88104
	fine_noise.frequency = 0.085
	fine_noise.fractal_octaves = 4

	var fine_texture := NoiseTexture2D.new()
	fine_texture.width = 512
	fine_texture.height = 512
	fine_texture.seamless = true
	fine_texture.normalize = true
	fine_texture.noise = fine_noise

	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform sampler2D macro_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D fine_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float scene_light_factor = 1.0;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float broad = texture(macro_tex, p * 0.018).r;
	float patch = texture(macro_tex, p * 0.072 + vec2(0.37, 0.19)).r;
	float detail = texture(fine_tex, p * 0.42).r;
	float soil = 1.0 - smoothstep(0.54, 0.75, broad * 0.65 + patch * 0.35);
	vec3 color = mix(vec3(0.080, 0.059, 0.041), vec3(0.135, 0.103, 0.073), patch);
	color = mix(color, vec3(0.064, 0.076, 0.048), (1.0 - soil) * 0.45);
	color *= mix(0.73, 0.98, detail);
	ALBEDO = color * scene_light_factor;
	ROUGHNESS = clamp(0.84 + soil * 0.10 + (1.0 - detail) * 0.05, 0.80, 0.98);
}
"""

	var material := ShaderMaterial.new()
	material.resource_name = "SHINRAI_Midori_MutedBrownForestFloor_Fallback_V2"
	material.shader = shader
	material.set_shader_parameter("macro_tex", macro_texture)
	material.set_shader_parameter("fine_tex", fine_texture)
	return material


func independent_layer_support(path_edge: float, trail_centre: float, paving_edge: float = INF) -> float:
	# The installed paving triangles also cover rounded corners that the authoring
	# centre-line distance approximates. These distances affect only mask alpha.
	var shoulder := minf(path_edge, paving_edge)
	return smoothstep(PATH_LAYER_FADE_M.x, PATH_LAYER_FADE_M.y, shoulder) * smoothstep(TRAIL_LAYER_FADE_M.x, TRAIL_LAYER_FADE_M.y, trail_centre)


func _install_landscape_mask(scene: Node3D) -> void:
	# Build material distribution after all real paths and trees exist. This
	# never changes terrain vertices, collisions, supplied scans or bank materials.
	var terrain:Node=scene.get_node_or_null("MidoriTerrain")
	while terrain==null or not terrain.installed:
		await get_tree().process_frame
		if not is_instance_valid(scene):return
		terrain=scene.get_node_or_null("MidoriTerrain")
	var trails:Node=scene.get_node_or_null("MidoriDesirePaths")
	while trails==null or not trails.finished:
		await get_tree().process_frame
		if not is_instance_valid(scene):return
		trails=scene.get_node_or_null("MidoriDesirePaths")
	if _active_ground_material==null:return
	if not _active_ground_material.shader.code.contains("uniform sampler2D landscape_tex"):
		landscape_report={"version":0,"fallback":true,"reason":"Supplied ground maps unavailable"}
		landscape_ready=true
		return
	var trees:Dictionary={}
	for local:Vector2 in scene.occupied_tree_positions:
		var p:Vector2=local*2.0
		var cell:=Vector2i(floori(p.x/12.0),floori(p.y/12.0))
		if not trees.has(cell):trees[cell]=[]
		trees[cell].append(p)
	var map:=Image.create(440,360,false,Image.FORMAT_RGBA8)
	var lawn:=0;var woodland:=0;var worn:=0
	var held_shoulders:=0;var blended_shoulders:=0
	var apron_rects:Array[Rect2]=[Rect2(-133,-66,14,22),Rect2(-168,-110,56,48),Rect2(-180,58,72,64),Rect2(123,105,85,63),Rect2(127,-167,50,42)]
	for z:int in range(360):
		for x:int in range(440):
			var p:=Vector2(x-219.5,z-179.5)
			var cell:=Vector2i(floori(p.x/12.0),floori(p.y/12.0))
			var tree_distance:=20.0
			for dz:int in range(-1,2):
				for dx:int in range(-1,2):
					for tree:Vector2 in trees.get(cell+Vector2i(dx,dz),[]):tree_distance=minf(tree_distance,p.distance_to(tree))
			var canopy:=1.0-smoothstep(1.0,6.5,tree_distance)
			var cover:=lerpf(.94,.26,canopy)
			var edge:float=scene.path_edge_distance_world(p)
			# Narrow worn shoulder, then a soft transition into the planted ground.
			cover*=smoothstep(.15,1.65,edge)
			var trail_distance:float=trails.distance_to_path(p)
			cover*=smoothstep(.90,1.80,trail_distance)
			var shore:float=terrain.edge_distance(p,terrain.shoreline)
			var material_support:=smoothstep(2.0,7.0,shore)
			if terrain.water_at(p):material_support=0.0
			for rect:Rect2 in apron_rects:
				var d:=p.distance_to(p.clamp(rect.position,rect.end))
				material_support*=smoothstep(0.0,2.5,d)
			cover*=material_support
			# Reuse the completed trail producer's spatial index of actual paving.
			# Old RGB mask values are untouched; only optional layer support uses A.
			var layer_support:=independent_layer_support(edge,trail_distance,trails.paving_distance(p))
			map.set_pixel(x,z,Color(cover,canopy,1.0-material_support,layer_support))
			if layer_support<=0.0:held_shoulders+=1
			elif layer_support<1.0:blended_shoulders+=1
			if cover>.6:lawn+=1
			elif canopy>.5:woodland+=1
			else:worn+=1
		if z%24==0:
			await get_tree().process_frame
			if not is_instance_valid(scene) or not is_instance_valid(terrain) or not is_instance_valid(trails):return
	_active_ground_material.set_shader_parameter("landscape_tex",ImageTexture.create_from_image(map))
	_active_ground_material.set_shader_parameter("landscape_ready",true)
	landscape_report={"version":4,"independent_ground_layers":_active_ground_material.get_shader_parameter("independent_layers_ready") == true,"map_resolution":Vector2i(440,360),"lawn_samples":lawn,"woodland_samples":woodland,"worn_or_protected_samples":worn,"source_world_scale_m":TEXTURE_WORLD_SIZE_M,"geometry_changes":0,"tree_count":scene.occupied_tree_positions.size(),"held_shoulder_samples":held_shoulders,"blended_shoulder_samples":blended_shoulders,"path_layer_fade_m":PATH_LAYER_FADE_M,"trail_layer_fade_m":TRAIL_LAYER_FADE_M}
	landscape_ready=true
	print("MIDORI_GROUND_LANDSCAPE_READY ",JSON.stringify(landscape_report))
