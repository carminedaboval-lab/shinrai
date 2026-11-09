extends SceneTree
## Memory-fix round, TEXTURES role: same-camera captures of the things whose textures were
## VRAM-compressed (fix 2) and of the near city (runtime BC7 arrays, indexed shells). Boots the
## real main scene with the QA profile like tools/biome_capture.gd, then saves 1920x1080 PNGs:
##   - fixed cameras (near-city facade row and signs; three biome_capture views reproduced with
##     the same maths, so they compare with the integrator's reference captures of those views);
##   - one frame per texture family, framed automatically on the nearest visible mesh whose
##     materials sample a texture under that path key (so the frame follows the asset, not a
##     hard-coded position).
## Usage (through tools/godot_locked.ps1):
##   --path . --disable-vsync --script res://tests/probe_mem_textures_capture.gd -- --out=<abs dir> [--midori-fruit-seed=13]
const SIZE := Vector2i(1920, 1080)
const FIXED := {
	# name: [eye xz (+1.7 over the ground), target (y added to the ground height)]
	"near_city_facades": [Vector3(60, 0, -190), Vector3(60, 5.0, -212)],
	"near_city_row": [Vector3(-5, 0, -194), Vector3(70, 7.0, -212)],
	"near_city_signs_west": [Vector3(-30, 0, -192), Vector3(-30, 6.0, -214)],
	"spawn_street": [Vector3(70, 0, -201), Vector3(85, 1.2, -165)],
	"moss_garden_satellite": [Vector3(5, 0, -98), Vector3(24, 0.8, -114)],
	"maple_glen_pavilion": [Vector3(130, 0, -128), Vector3(152, 1.6, -146)],
}
const FAMILIES := {
	# capture name: [texture path key, camera direction (normalised later), distance factor]
	"kasuga_lantern": ["stone_lantern/kasuga_lantern", Vector3(.7, .35, 1.0), 2.4],
	"pavilion_azumaya": ["pavilion/azumaya", Vector3(.8, .3, 1.0), 1.6],
	"identity2050_bench": ["identity2050/midori_2050_timber_bench", Vector3(.5, .4, 1.0), 2.2],
	"identity2050_planter": ["identity2050/midori_2050_planter", Vector3(.5, .4, 1.0), 2.2],
	"path_lamp": ["main_path_lamp/japanese_path_lamp_2800", Vector3(.6, .2, 1.0), 2.0],
	"market_stall": ["midori_market_stall/market_stall", Vector3(.6, .3, 1.0), 1.8],
	"court_art_vase": ["midori_court_art/haku_stoneware", Vector3(.6, .3, 1.0), 2.4],
	"backpack": ["gear/backpacks/", Vector3(.6, .4, 1.0), 2.6],
	"player_character": ["urban_explorer_2050", Vector3(0.0, .25, 1.0), 2.0],
	"forest_floor_stone": ["forest_floor_20261026/stone_0", Vector3(.5, .5, 1.0), 2.4],
	"medical_item": ["assets/medical/", Vector3(.5, .5, 1.0), 2.6],
}
var scene: Node3D
var out := ""

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i: int in range(n): await process_frame

func fail(reason: String) -> void:
	printerr("TEXCAP_FAILED ", reason)
	quit(1)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.get_slice("=", 1)
	if out == "" or not out.is_absolute_path() or DirAccess.make_dir_recursive_absolute(out) != OK:
		fail("Missing or inaccessible --out=<abs dir>")
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
	print("TEXCAP world ready at %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	raid.hud.hide()
	var player: Node3D = raid.get("player") if raid.get("player") is Node3D and is_instance_valid(raid.get("player")) else null
	await frames(90)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.fov = 70
	camera.make_current()
	var terrain: Node = scene.get_node("MidoriTerrain")
	var shots := 0
	# Fixed cameras, player hidden as in biome_capture.
	if player != null: player.visible = false
	for name: String in FIXED:
		var view: Array = FIXED[name]
		var eye: Vector3 = view[0]
		eye.y = terrain.height_at(Vector2(eye.x, eye.z)) + 1.7
		var target: Vector3 = view[1]
		target.y += terrain.height_at(Vector2(target.x, target.z))
		camera.global_position = eye
		camera.look_at(target)
		if await _shoot(camera, name): shots += 1
	# Texture families: frame the nearest visible user of each texture path key.
	var users := _texture_users()
	for name: String in FAMILIES:
		var row: Array = FAMILIES[name]
		var key: String = row[0]
		var show_player := key == "urban_explorer_2050"
		if player != null: player.visible = show_player
		var best: GeometryInstance3D = null
		var best_box := AABB()
		var best_d := INF
		for g: GeometryInstance3D in users.get(key, []):
			if not is_instance_valid(g) or not g.is_inside_tree(): continue
			if not show_player and player != null and (g == player or player.is_ancestor_of(g)): continue
			var box := _world_box(g)
			if box.size.length() < .05 or box.size.length() > 200.0: continue
			var d := Vector2(box.get_center().x, box.get_center().z).length()
			if d < best_d: best_d = d; best = g; best_box = box
		if best == null:
			print("TEXCAP_MISSING %s (no visible mesh samples '%s')" % [name, key])
			continue
		var centre := best_box.get_center()
		var radius := maxf(best_box.size.length() * .5, .3)
		var dir: Vector3 = (row[1] as Vector3).normalized()
		var eye := centre + dir * (radius * float(row[2]) + .6)
		var ground: float = terrain.height_at(Vector2(eye.x, eye.z))
		if eye.y < ground + .4: eye.y = ground + .4
		camera.global_position = eye
		camera.look_at(centre)
		print("TEXCAP frame %s -> %s at %s size %s" % [name, best.get_path(), centre, best_box.size])
		if await _shoot(camera, name): shots += 1
	if player != null: player.visible = true
	var manifest := FileAccess.open(out.path_join("capture.json"), FileAccess.WRITE)
	if manifest != null:
		manifest.store_string(JSON.stringify({"shots": shots, "fixed": FIXED.keys(), "families": FAMILIES.keys()}, "\t"))
		manifest.close()
	print("TEXCAP_DONE shots=%d" % shots)
	quit()

func _shoot(camera: Camera3D, name: String) -> bool:
	await frames(70)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != SIZE:
		print("TEXCAP_FAILED_SHOT %s: no 1920x1080 image" % name)
		return false
	var saved := image.save_png(out.path_join(name + ".png"))
	if saved != OK:
		print("TEXCAP_FAILED_SHOT %s: %s" % [name, error_string(saved)])
		return false
	print("SHOT %s eye=%s" % [name, camera.global_position])
	return true

func _world_box(g: GeometryInstance3D) -> AABB:
	if g is MultiMeshInstance3D:
		var mm: MultiMesh = (g as MultiMeshInstance3D).multimesh
		if mm != null and mm.mesh != null and mm.instance_count > 0:
			return g.global_transform * (mm.get_instance_transform(0) * mm.mesh.get_aabb())
	return g.global_transform * g.get_aabb()

## Every visible GeometryInstance3D in the scene, keyed by the FAMILIES texture path keys its
## materials sample (BaseMaterial3D texture slots and ShaderMaterial texture uniforms).
func _texture_users() -> Dictionary:
	var keys: Array[String] = []
	for name: String in FAMILIES: keys.append(FAMILIES[name][0])
	var users := {}
	var stack: Array[Node] = [scene]
	var mat_keys := {}
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children(): stack.append(child)
		if not node is GeometryInstance3D: continue
		var g := node as GeometryInstance3D
		if not g.is_visible_in_tree() and not (g.get_class() == "MeshInstance3D" and g.name.begins_with("Body")): continue
		var mesh: Mesh = null
		if g is MeshInstance3D: mesh = (g as MeshInstance3D).mesh
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null: mesh = (g as MultiMeshInstance3D).multimesh.mesh
		var materials: Array[Material] = []
		if g.material_override != null: materials.append(g.material_override)
		if mesh != null:
			for s: int in range(mesh.get_surface_count()):
				var m: Material = null
				if g is MeshInstance3D: m = (g as MeshInstance3D).get_surface_override_material(s)
				if m == null: m = mesh.surface_get_material(s)
				if m != null: materials.append(m)
		for m: Material in materials:
			var id := m.get_instance_id()
			if not mat_keys.has(id): mat_keys[id] = _material_keys(m, keys)
			for key: String in mat_keys[id]:
				if not users.has(key): users[key] = []
				users[key].append(g)
	return users

func _material_keys(m: Material, keys: Array[String]) -> Array[String]:
	var paths: Array[String] = []
	var cursor: Material = m
	var guard := 0
	while cursor != null and guard < 4:
		guard += 1
		if cursor is BaseMaterial3D:
			for slot: String in ["albedo_texture", "normal_texture", "metallic_texture", "roughness_texture", "emission_texture", "ao_texture", "orm_texture", "detail_albedo", "detail_normal"]:
				var t: Variant = cursor.get(slot)
				if t is Texture and (t as Texture).resource_path != "": paths.append((t as Texture).resource_path)
		elif cursor is ShaderMaterial and (cursor as ShaderMaterial).shader != null:
			for u: Dictionary in (cursor as ShaderMaterial).shader.get_shader_uniform_list():
				if int(u.type) != TYPE_OBJECT: continue
				var t: Variant = (cursor as ShaderMaterial).get_shader_parameter(String(u.name))
				if t is Texture and (t as Texture).resource_path != "": paths.append((t as Texture).resource_path)
		cursor = cursor.next_pass
	var found: Array[String] = []
	for key: String in keys:
		for p: String in paths:
			if p.contains(key):
				found.append(key)
				break
	return found
