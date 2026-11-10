extends SceneTree
## Same cameras as the before shots, after the biome pass. Views come from
## the BIOME_VIEWS env var (comma list of names) or all.
var scene: Node3D
const VIEWS := {
	"maple_glen": [Vector3(118, 0, -126), Vector3(140, 1.5, -158)],
	"pine_woods": [Vector3(-112, 0, -40), Vector3(-160, 1.5, -70)],
	"north_coppice": [Vector3(-10, 0, -60), Vector3(-30, 1.5, -120)],
	"moss_garden": [Vector3(18, 0, 30), Vector3(-20, 1.0, 18)],
	"iris_shore": [Vector3(40, 0, 70), Vector3(70, 0.4, 50)],
	"sakura_lawn": [Vector3(0, 0, 165), Vector3(10, 2.0, 120)],
	"shrine_approach": [Vector3(164, 0, 95), Vector3(164, 2.5, 136)],
	"meadow": [Vector3(-150, 0, 55), Vector3(-150, 1.0, 100)],
	"spawn_street": [Vector3(70, 0, -201), Vector3(85, 1.2, -165)],
	"maple_glen_west": [Vector3(52, 0, -150), Vector3(110, 1.6, -145)],
	"maple_glen_pavilion": [Vector3(130, 0, -128), Vector3(152, 1.6, -146)],
	"maple_glen_east": [Vector3(178, 0, -138), Vector3(120, 1.6, -158)],
	"north_coppice_deep": [Vector3(25, 0, -150), Vector3(-35, 1.4, -128)],
	"north_coppice_west": [Vector3(-75, 0, -100), Vector3(0, 1.4, -92)],
	"pine_woods_reverse": [Vector3(-185, 0, -95), Vector3(-130, 1.8, -45)],
	"pine_woods_court": [Vector3(-95, 0, -118), Vector3(-110, 1.6, -160)],
	"pine_woods_east_stand": [Vector3(186, 0, 68), Vector3(184, 1.8, 20)],
	"moss_garden_north": [Vector3(-14, 0, -12), Vector3(-14, 1.0, 40)],
	"moss_garden_west": [Vector3(-48, 0, 42), Vector3(0, 1.0, 12)],
	"moss_garden_satellite": [Vector3(5, 0, -98), Vector3(24, 0.8, -114)],
	"sakura_lawn_west": [Vector3(-70, 0, 125), Vector3(30, 2.0, 140)],
	"sakura_lawn_east": [Vector3(100, 0, 112), Vector3(20, 2.0, 140)],
	"shrine_approach_reverse": [Vector3(164, 0, 165), Vector3(164, 2.5, 110)],
	"meadow_north": [Vector3(-118, 0, 150), Vector3(-172, 1.0, 88)],
	"meadow_west": [Vector3(-205, 0, 78), Vector3(-130, 1.0, 118)],
	"iris_shore_east": [Vector3(150.8, 0, 17.2), Vector3(134.1, 0.3, 45.3)],
	"iris_shore_north": [Vector3(71, 0, -97), Vector3(39.6, 0.3, -105.9)],
	"iris_shore_inlet": [Vector3(122.2, 0, -129.8), Vector3(121.7, 0.3, -97.1)],
	"maple_glen_floor": [Vector3(96, 0, -150), Vector3(104, -0.6, -156)],
	# Corporate district (origin 220, 0, 330): close, at the stairs, and from ~190 m.
	"corporate_near": [Vector3(196, 0, 292), Vector3(226, 6.0, 336)],
	"corporate_stairs": [Vector3(238, 0, 312), Vector3(222, 12.0, 336)],
	"corporate_far": [Vector3(120, 0, 170), Vector3(220, 10.0, 330)],
}

const ROOTS := {
	"north_coppice": "BiomeNorthCoppice",
	"iris_shore": "BiomeIrisShore",
	"shrine_approach": "BiomeShrineApproach",
	"maple_glen": "BiomeMapleGlen",
	"meadow": "BiomeMeadow",
	"pine_woods": "BiomePineWoods",
}
const BIOMES := preload("res://scripts/midori_biomes.gd")
const SIZE := Vector2i(1920, 1080)

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i: int in range(n): await process_frame

func measure() -> Dictionary:
	await frames(70)
	var samples: Array[float] = []
	for i: int in range(3):
		var start := Time.get_ticks_usec()
		await frames(40)
		samples.append((Time.get_ticks_usec() - start) / 40000.0)
	var sorted := samples.duplicate()
	sorted.sort()
	return {"samples_ms": samples, "median_ms": sorted[1]}

func validation_error(meta: Dictionary, only: PackedStringArray, off: bool) -> String:
	if off:
		if not only.is_empty() or meta != {"disabled": true}:
			return "OFF expects an empty ONLY setting and disabled metadata"
		return ""
	if meta.has("error") or meta.has("disabled") or not meta.has("look_maps"):
		return "Ground look maps or enabled metadata missing"
	var known: Array[String] = []
	for path: String in BIOMES.BUILDERS:
		var builder := path.get_file().get_basename()
		known.append(builder)
		var selected := only.is_empty() or only.has(builder)
		if meta.has(builder) != selected:
			return "Unexpected builder selection: " + builder
		if selected:
			var result: Variant = meta[builder]
			if not result is Dictionary or result.is_empty() or result.has("error"):
				return "Builder report missing or failed: " + builder
			if ROOTS.has(builder) and scene.get_node_or_null(NodePath(ROOTS[builder])) == null:
				return "Expected biome root missing: " + builder
	for name: String in only:
		if not known.has(name):
			return "Unknown requested builder: " + name
	return ""

func fail(reason: String) -> void:
	printerr("ROUND4_FAILED ", reason)
	quit(1)

func run() -> void:
	var out := OS.get_environment("ROUND4_CAPTURE_DIR")
	if not out.is_absolute_path() or DirAccess.make_dir_recursive_absolute(out) != OK:
		fail("Missing or inaccessible ROUND4_CAPTURE_DIR")
		return
	var wanted := OS.get_environment("BIOME_VIEWS").split(",", false)
	for name: String in wanted:
		if not VIEWS.has(name):
			fail("Unknown requested camera: " + name)
			return
	root.size = SIZE
	root.content_scale_size = root.size
	scene = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_perf_probe.json"
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var started := Time.get_ticks_msec()
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() - started < 900000:
		await process_frame
	if raid.phase != raid.Phase.HQ:
		fail("Raid failed to finish boot into HQ")
		return
	while not scene.has_meta("midori_biomes") and Time.get_ticks_msec() - started < 1200000:
		await process_frame
	if not scene.has_meta("midori_biomes"):
		fail("Timed out waiting for biome installation")
		return
	var meta: Dictionary = scene.get_meta("midori_biomes")
	print("BIOMES_META ", JSON.stringify(meta))
	var only := OS.get_environment("MIDORI_BIOMES_ONLY").split(",", false)
	var off := OS.get_environment("MIDORI_BIOMES_OFF") == "1"
	var error := validation_error(meta, only, off)
	if not error.is_empty():
		fail(error)
		return
	raid.hud.hide()
	if raid.get("player") != null and is_instance_valid(raid.player): raid.player.visible = false
	# BIOME_NIGHT=1 / =0 forces night or day for the shots (unset: as the park booted).
	var night := OS.get_environment("BIOME_NIGHT")
	if night == "1" or night == "0":
		scene.set("is_night_mode", night == "1")
		scene.call("_apply_time_of_day")
		print("BIOME_NIGHT ", scene.get("is_night_mode"))
	await frames(90)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.fov = 70
	camera.make_current()
	var terrain: Node = scene.get_node("MidoriTerrain")
	var results := {}
	for name: String in VIEWS:
		if not wanted.is_empty() and not wanted.has(name): continue
		var view: Array = VIEWS[name]
		var eye: Vector3 = view[0]
		eye.y = terrain.height_at(Vector2(eye.x, eye.z)) + 1.7
		var target: Vector3 = view[1]
		target.y += terrain.height_at(Vector2(target.x, target.z))
		camera.global_position = eye
		camera.look_at(target)
		var measured := await measure()
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if image == null or image.get_size() != SIZE:
			fail("Expected 1920x1080 viewport image at " + name)
			return
		var saved := image.save_png(out.path_join(name + ".png"))
		if saved != OK:
			fail("PNG save failed at %s: %s" % [name, error_string(saved)])
			return
		var steady: float = 1000.0 / measured.median_ms
		print("SHOT ", name, " steady_fps=", snappedf(steady, 0.1))
		var row := {"view": name, "width": image.get_width(), "height": image.get_height(),
				"png_saved": true, "visible": measured}
		for area: String in ROOTS:
			if (name == area or name.begins_with(area + "_")) and meta.has(area):
				# In-place tree replacements and baked terrain persist while this node is hidden.
				var area_root := scene.get_node(NodePath(ROOTS[area])) as Node3D
				if not area_root.visible:
					fail("Expected a visible root for " + area)
					return
				area_root.visible = false
				row["own_root_hidden"] = await measure()
				area_root.visible = true
				break
		print("ROUND4 ", JSON.stringify(row))
		results[name] = row
	var requested_views: Array = VIEWS.keys() if wanted.is_empty() else Array(wanted)
	var record := {"off": off, "only": Array(only), "requested_views": requested_views, "views": results}
	var manifest := FileAccess.open(out.path_join("capture.json"), FileAccess.WRITE)
	if manifest == null:
		fail("Could not open capture manifest")
		return
	manifest.store_string(JSON.stringify(record, "\t"))
	manifest.flush()
	var written := manifest.get_error()
	manifest.close()
	if written != OK:
		fail("Could not write capture manifest")
		return
	print("BUILD_DONE")
	quit()
