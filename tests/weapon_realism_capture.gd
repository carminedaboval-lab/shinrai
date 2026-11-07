extends SceneTree

# Close-range weapon turntable for realism review. Loads each weapon assembly
# on its own (no park boot), lights it like a neutral product shot and saves
# fixed cameras so before/after renders line up pixel for pixel.
#   godot --path . --script res://tests/weapon_realism_capture.gd -- --tag before [--only akane,kite]
# Weapon convention: metres, -X forward (muzzle), +Y up, right side = -Z.

const OUT_DIR := "res://docs/weapon_realism_20261107/renders"
const SIZE := Vector2i(1600, 1000)
const WEAPONS := {
	"akane": "res://assets/weapons/akane/akane_weapon.tscn",
	"uzi": "res://assets/uzi/scene.gltf",
	"shigure": "res://assets/weapons/shigure/shigure_weapon.tscn",
	"kite": "res://assets/weapons/kite/kite_weapon.tscn",
	"raiden_r56": "res://assets/weapons/raiden_r56/raiden_r56_weapon.tscn",
	"tobikage": "res://assets/weapons/tobikage/tobikage_weapon.tscn",
	"hayate": "res://assets/weapons/hayate/hayate_weapon.tscn",
	"yuzuru": "res://assets/weapons/yuzuru/yuzuru_weapon.tscn",
	"optic_reflex": "res://assets/weapons/optics/ame_reflex.tscn",
	"optic_prism": "res://assets/weapons/optics/tobi_prism.tscn",
	"optic_scope": "res://assets/weapons/kasumi_scope/kasumi_scope.tscn",
}
const UZI_PARTS := ["object_1084", "object_1085"]

var viewport: SubViewport
var camera: Camera3D
var stage: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _arg(name: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--" + name)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback

func _run() -> void:
	var tag := _arg("tag", "before")
	var only := _arg("only", "")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build_stage()
	for key: String in WEAPONS:
		if not only.is_empty() and key not in only.split(","):
			continue
		await _capture(key, tag)
	print("WEAPON_CAPTURE_DONE")
	quit(0)

func _build_stage() -> void:
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_8X
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.55, 0.58, 0.62)
	sky_mat.sky_horizon_color = Color(0.72, 0.72, 0.70)
	sky_mat.ground_bottom_color = Color(0.20, 0.19, 0.18)
	sky_mat.ground_horizon_color = Color(0.45, 0.44, 0.42)
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.37, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_radius = 0.02
	env.ssao_intensity = 1.2
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48, 35, 0)
	key_light.light_energy = 1.9
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = 4.0
	stage.add_child(key_light)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.9
	rim.light_color = Color(0.86, 0.91, 1.0)
	stage.add_child(rim)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -60, 0)
	fill.light_energy = 0.45
	stage.add_child(fill)
	camera = Camera3D.new()
	camera.near = 0.005
	camera.far = 20.0
	stage.add_child(camera)
	camera.current = true

func _instance(key: String) -> Node3D:
	var path: String = WEAPONS[key]
	# --assets-root renders an archived copy of the weapon folders (the "before"
	# assets) without swapping them back into the game.
	var root := _arg("assets-root", "")
	if not root.is_empty() and path.begins_with("res://assets/weapons/"):
		var archived := path.replace("res://assets/weapons/", root.trim_suffix("/") + "/")
		if ResourceLoader.exists(archived):
			path = archived
	var packed := load(path) as PackedScene
	var node := packed.instantiate() as Node3D
	stage.add_child(node)
	if key == "uzi":
		_isolate_uzi(node)
	_hide_glass(node)
	if OS.get_cmdline_user_args().has("--no-lod"):
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			mesh.lod_bias = 128.0
	return node

func _isolate_uzi(node: Node) -> void:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mesh.visible = str(mesh.name).to_lower() in UZI_PARTS
		if mesh.visible:
			preload("res://scripts/weapon_surface_detail.gd").apply_baked_materials(mesh)
	for light: Light3D in node.find_children("*", "Light3D", true, false):
		light.visible = false
	for player: AnimationPlayer in node.find_children("*", "AnimationPlayer", true, false):
		var names := player.get_animation_list()
		for clip: String in names:
			if clip.to_lower().contains("idle"):
				player.play(clip)
				player.advance(0.1)
				player.pause()
				break

func _hide_glass(node: Node) -> void:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if str(mesh.name).contains("OpticGlass"):
			var glass := StandardMaterial3D.new()
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.albedo_color = Color(0.5, 0.55, 0.6, 0.12)
			glass.roughness = 0.05
			mesh.material_override = glass

func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var local := mesh.get_aabb()
		if mesh.skin != null:
			continue
		var world := mesh.global_transform * local
		box = world if first else box.merge(world)
		first = false
	if first:
		# Skinned-only weapon: fall back to bone-driven world positions.
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			if mesh.is_visible_in_tree() and mesh.mesh != null:
				var world := mesh.global_transform * mesh.get_aabb()
				box = world if first else box.merge(world)
				first = false
	return box

func _views(box: AABB) -> Array[Dictionary]:
	var c := box.get_center()
	var s := box.size
	var length := maxf(s.x, maxf(s.y, s.z))
	var pad := 1.12
	return [
		{"name": "left", "ortho": true, "size": maxf(s.x * pad * SIZE.y / SIZE.x, s.y * pad), "pos": c + Vector3(0, 0, 2.0), "target": c, "up": Vector3.UP},
		{"name": "right", "ortho": true, "size": maxf(s.x * pad * SIZE.y / SIZE.x, s.y * pad), "pos": c + Vector3(0, 0, -2.0), "target": c, "up": Vector3.UP},
		{"name": "top", "ortho": true, "size": maxf(s.x * pad * SIZE.y / SIZE.x, s.z * pad * 1.6), "pos": c + Vector3(0, 2.0, 0), "target": c, "up": Vector3(0, 0, -1)},
		{"name": "fp34", "ortho": false, "fov": 38.0, "pos": c + Vector3(s.x * 0.62, s.y * 0.9 + 0.04, -s.x * 0.30), "target": c + Vector3(-s.x * 0.12, 0, 0), "up": Vector3.UP},
		{"name": "muzzle", "ortho": false, "fov": 30.0, "pos": c + Vector3(-s.x * 0.5 - length * 0.55, s.y * 0.25, -length * 0.28), "target": Vector3(box.position.x + s.x * 0.15, c.y, c.z), "up": Vector3.UP},
	]

func _capture(key: String, tag: String) -> void:
	var node := _instance(key)
	for frame: int in range(4):
		await process_frame
	var box := _bounds(node)
	if key == "uzi":
		# Skinned to the arms rig: re-seat the rig so the receiver bone sits at
		# the origin with the gun's own axes, then frame a real Uzi's size.
		var skel := node.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var bone := skel.find_bone("UZI Body_0725")
		var bone_world := skel.global_transform * skel.get_bone_global_pose(bone)
		# The receiver bone runs along +Z; turn it to the -X-forward convention.
		node.global_transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3.ZERO) * bone_world.affine_inverse() * node.global_transform
		for frame: int in range(3):
			await process_frame
		box = AABB(Vector3(-0.33, -0.2, -0.04), Vector3(0.66, 0.34, 0.08))
	var live := box
	print("LIVE ", key, " ", JSON.stringify([live.position.x, live.position.y, live.position.z, live.size.x, live.size.y, live.size.z]))
	# Later passes reuse the first pass's framing so the cameras never move.
	var locked := ProjectSettings.globalize_path("%s/%s_camera.json" % [OUT_DIR, key])
	if FileAccess.file_exists(locked):
		var saved: Array = JSON.parse_string(FileAccess.get_file_as_string(locked))
		box = AABB(Vector3(saved[0], saved[1], saved[2]), Vector3(saved[3], saved[4], saved[5]))
	else:
		var out := FileAccess.open(locked, FileAccess.WRITE)
		out.store_string(JSON.stringify([box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z]))
		out.close()
	print("WEAPON ", key, " bounds ", box)
	var views := _views(box)
	# Muzzle view: looks back into the crown from just ahead of the bore. The
	# target is stored once (from the rebuilt gun) so before/after share it.
	var mfile := ProjectSettings.globalize_path("%s/%s_muzzle.json" % [OUT_DIR, key])
	var mpos := Vector3.ZERO
	var have_muzzle := false
	if FileAccess.file_exists(mfile):
		var mv: Array = JSON.parse_string(FileAccess.get_file_as_string(mfile))
		mpos = Vector3(mv[0], mv[1], mv[2])
		have_muzzle = true
	elif node.get_node_or_null("Muzzle") is Node3D:
		mpos = (node.get_node("Muzzle") as Node3D).global_position
		var mo := FileAccess.open(mfile, FileAccess.WRITE)
		mo.store_string(JSON.stringify([mpos.x, mpos.y, mpos.z]))
		mo.close()
		have_muzzle = true
	if have_muzzle:
		var reach := clampf(0.10 + box.size.x * 0.06, 0.11, 0.18)
		for i: int in views.size():
			if views[i].name == "muzzle":
				views[i] = {"name": "muzzle", "ortho": false, "fov": 34.0, "pos": mpos + Vector3(-reach, reach * 0.22, -reach * 0.38), "target": mpos + Vector3(0.02, -0.012, 0.0), "up": Vector3.UP}
	# Review-only close-ups framed on the current model (not part of before/after).
	var muzzle := node.get_node_or_null("Muzzle") as Node3D
	var rear := node.get_node_or_null("IronRearSight") as Node3D
	var front := node.get_node_or_null("IronFrontSight") as Node3D
	var h := maxf(live.size.y, 0.12)
	if muzzle != null:
		var m := muzzle.global_position
		views.append({"name": "muzzle_live", "ortho": false, "fov": 34.0, "pos": m + Vector3(-h * 0.55, h * 0.12, -h * 0.30), "target": m + Vector3(0.0, -h * 0.12, 0.0), "up": Vector3.UP})
	if rear != null and front != null:
		var r := rear.global_position
		var f := front.global_position
		var span := r.distance_to(f)
		views.append({"name": "sights_live", "ortho": false, "fov": 24.0, "pos": r + Vector3(span * 0.55, 0.006, 0.0), "target": f, "up": Vector3.UP})
		views.append({"name": "fp34_live", "ortho": false, "fov": 42.0, "pos": r + Vector3(span * 0.5, span * 0.28, -span * 0.38), "target": r.lerp(f, 0.45) + Vector3(0, -h * 0.22, 0), "up": Vector3.UP})
	for view: Dictionary in views:
		if view.ortho:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = view.size
		else:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = view.fov
		camera.global_position = view.pos
		camera.look_at(view.target, view.up)
		for frame: int in range(6):
			await process_frame
		var image := viewport.get_texture().get_image()
		var path := "%s/%s_%s_%s.png" % [OUT_DIR, key, view.name, tag]
		image.save_png(ProjectSettings.globalize_path(path))
	node.queue_free()
	await process_frame
