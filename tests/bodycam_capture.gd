extends SceneTree
# Bodycam view check in one raid boot: the normal view (hip, aimed), the same
# shots through the chest lens, a motion series (look up/down, mid-turn, walk,
# sprint, aim while walking), the lens at three strengths, then the normal view
# again after switching the bodycam off. Prints which camera is current for
# every shot and the lens transform, so the pictures can be read against numbers.
#   godot --path . --script res://tests/bodycam_capture.gd -- --out <dir> [--guns a,b] [--sweep] [--raid --no-consolidate]
# Default is a small test yard (seconds to load); --raid uses the real park.
# The player is driven through player.test_input_override, so the real mouse
# pointer is not captured while this runs.
const ControllerInput = preload("res://scripts/shinrai_input.gd")
var out_dir := "user://bodycam_capture"
var want_ads := false
var want_forward := false
var player: Node

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func shot(label: String, settle := 4) -> void:
	if settle > 0:
		await frames(settle)
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(label + ".png")
	root.get_texture().get_image().save_png(path)
	var cam := root.get_camera_3d()
	var line := "BODYCAM_SHOT %s camera=%s fov=%.1f" % [label, cam.name if cam != null else "none", cam.fov if cam != null else 0.0]
	if is_instance_valid(player):
		var eye: Camera3D = player.camera
		line += " eye_pos=%s eye_fov=%.1f" % [eye.global_position, eye.fov]
		if cam != null and cam != eye:
			var d: Vector3 = cam.global_position - eye.global_position
			var fwd_eye := -eye.global_transform.basis.z
			var fwd_lens := -cam.global_transform.basis.z
			line += " lens_minus_eye=%s yaw_gap=%.1f pitch_eye=%.1f pitch_lens=%.1f roll_lens=%.1f" % [d,
				rad_to_deg(wrapf(atan2(-fwd_lens.x, -fwd_lens.z) - atan2(-fwd_eye.x, -fwd_eye.z), -PI, PI)),
				rad_to_deg(asin(clampf(fwd_eye.y, -1.0, 1.0))), rad_to_deg(asin(clampf(fwd_lens.y, -1.0, 1.0))),
				rad_to_deg(cam.global_transform.basis.get_euler().z)]
		line += " ads_blend=%.2f sprint=%s speed=%.2f crosshair=%s tactical=%s" % [float(player.ads_blend), str(player.sprinting),
			Vector2(player.velocity.x, player.velocity.z).length(),
			str(player.crosshair.visible) if is_instance_valid(player.get("crosshair")) else "n/a",
			str(player.tactical_crosshair.visible) if is_instance_valid(player.get("tactical_crosshair")) else "n/a"]
	print(line)

func equip(id: String) -> bool:
	var ok: bool = player.apply_weapon_loadout(id, {"optic": "", "ammo": 20, "reserve": 60, "chambered": true, "bolt_locked": false})
	if not ok:
		print("BODYCAM_FAIL: could not equip ", id)
	await frames(150)
	return ok

func aim(on: bool) -> void:
	want_ads = on
	player.ads = on
	if on:
		for f in 200:
			await frames(1)
			if player.ads_blend >= 0.999 and f > 40:
				break
	else:
		await frames(40)

func face(yaw: float, pitch: float) -> void:
	player.rotation.y = yaw
	if player.head != null:
		player.head.rotation.x = pitch
	await frames(30)

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, checker: Texture2D = null) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if checker != null:
		mat.albedo_texture = checker
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3(0.5, 0.5, 0.5)   # one tile per 2 m
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mesh.material_override = mat
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	parent.add_child(body)

## A small test yard instead of the park (seconds to load, about 1 GB): a tiled
## floor and straight walls so the lens bend is readable, a doorway, a
## person-sized board at 10 m and posts at 5 / 20 / 50 m straight ahead.
func build_arena() -> Node3D:
	var world := Node3D.new()
	world.name = "BodycamArena"
	root.add_child(world)
	current_scene = world
	var img := Image.create(64, 64, true, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var edge := x < 2 or y < 2
			var dark := ((x / 32) + (y / 32)) % 2 == 0
			img.set_pixel(x, y, Color(0.18, 0.18, 0.18) if edge else (Color(0.62, 0.62, 0.6) if dark else Color(0.78, 0.78, 0.76)))
	img.generate_mipmaps()
	var checker := ImageTexture.create_from_image(img)
	_box(world, Vector3(240, 1, 240), Vector3(0, -0.5, -60), Color.WHITE, checker)
	_box(world, Vector3(1, 6, 240), Vector3(-9, 3, -60), Color(0.85, 0.8, 0.72), checker)
	_box(world, Vector3(1, 6, 240), Vector3(9, 3, -60), Color(0.72, 0.8, 0.85), checker)
	# Doorway 4 m ahead: 1.2 m wide, 2.1 m high.
	_box(world, Vector3(0.3, 2.4, 0.3), Vector3(-0.75, 1.2, -4), Color(0.5, 0.32, 0.2))
	_box(world, Vector3(0.3, 2.4, 0.3), Vector3(0.75, 1.2, -4), Color(0.5, 0.32, 0.2))
	_box(world, Vector3(1.8, 0.3, 0.3), Vector3(0, 2.25, -4), Color(0.5, 0.32, 0.2))
	# Person-sized board at 10 m, posts at 5 / 20 / 50 m with a red band at 1.5 m.
	_box(world, Vector3(0.5, 1.8, 0.1), Vector3(2.0, 0.9, -10), Color(0.2, 0.35, 0.6))
	for d: float in [5.0, 20.0, 50.0]:
		_box(world, Vector3(0.12, 3.0, 0.12), Vector3(0, 1.5, -d), Color(0.9, 0.9, 0.9))
		_box(world, Vector3(0.2, 0.1, 0.2), Vector3(0, 1.5, -d), Color(0.9, 0.1, 0.1))
	# A wall to stand against (lens-through-wall check), off to the side.
	_box(world, Vector3(6, 3, 0.4), Vector3(-30, 1.5, 20), Color(0.7, 0.7, 0.7), checker)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	return world

func run() -> void:
	# Do not take keyboard focus from whoever is using the PC while this runs.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	var raid: Node = null
	if OS.get_cmdline_user_args().has("--raid"):
		var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
		scene.profile_path = out_dir.path_join("bodycam_profile.json")
		root.add_child(scene)
		current_scene = scene
		raid = scene.get_node("ExtractionRun")
		var deadline := Time.get_ticks_msec() + 240000
		while raid.phase != raid.Phase.HQ and Time.get_ticks_msec() < deadline:
			await process_frame
		await frames(30)
		for attempt in 5:
			raid.start_run()
			await frames(30)
			if raid.phase == raid.Phase.RAID:
				break
		print("BODYCAM_PHASE ", raid.phase, " (RAID=", raid.Phase.RAID, ")")
		raid._clear_enemies()
		await frames(90)
		player = raid.player
	else:
		var world := build_arena()
		player = load("res://scripts/player.gd").new()
		player.name = "BodycamTestPlayer"
		player.set("extraction_mode", true)
		player.position = Vector3(0, 0.2, 6)
		world.add_child(player)
		await frames(60)
		print("BODYCAM_ARENA ready")
	var base_yaw := 0.6 if raid != null else 0.0
	# Drive the player without taking the real mouse pointer.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.set("test_input_override", true)
	var rig: Node = player.get("bodycam")
	if rig == null:
		print("BODYCAM_FAIL: player has no bodycam rig")
		quit(1)
		return
	# A scripted window has no focus: hold inputs the way held buttons would.
	physics_frame.connect(func() -> void:
		if not is_instance_valid(player):
			return
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # the player captures it on _ready
		ControllerInput._focused = true
		ControllerInput._release_required = false
		if want_ads:
			Input.action_press("sr_aim")
			player.ads = true
		else:
			Input.action_release("sr_aim")
		if want_forward:
			Input.action_press("sr_move_forward")
		else:
			Input.action_release("sr_move_forward"))
	var start_pos: Vector3 = player.global_position
	await face(base_yaw, 0.0)

	# --hands: close-ups of the hands on the pistol from six sides (normal pose,
	# bodycam off), to judge the grip fit and any clipping.
	if OS.get_cmdline_user_args().has("--hands"):
		if not await equip("akane"):
			quit(1)
			return
		var vm: Node3D = player.get("uzi_viewmodel")
		var assembly: Node3D = vm.get("assembly") if vm != null else null
		var grip: Node3D = assembly.get_node_or_null("GripRight") if assembly != null else null
		if grip == null:
			print("BODYCAM_FAIL: no GripRight marker")
			quit(1)
			return
		# Numbers behind the pictures: gun parts and finger bones in the gun's own
		# axes (millimetres), hand size, and how far up the arm the sleeves reach.
		var inv := assembly.global_transform.affine_inverse()
		print("HANDS_GUN scale=", assembly.global_basis.get_scale(), " markers GripRight=", (inv * grip.global_position * 1000.0).round(),
			" GripLeft=", (inv * (assembly.get_node("GripLeft") as Node3D).global_position * 1000.0).round(),
			" Muzzle=", (inv * (assembly.get_node("Muzzle") as Node3D).global_position * 1000.0).round(),
			" RearSight=", (inv * (assembly.get_node("IronRearSight") as Node3D).global_position * 1000.0).round())
		for mesh: MeshInstance3D in assembly.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = (inv * mesh.global_transform) * mesh.get_aabb()
			print("HANDS_PART %s min=%s max=%s visible=%s" % [mesh.name, (box.position * 1000.0).round(), (box.end * 1000.0).round(), str(mesh.is_visible_in_tree())])
		var rig_skel: Skeleton3D = vm.get("skeleton")
		if rig_skel != null:
			var world_scale: float = rig_skel.global_basis.get_scale().x
			for b in rig_skel.get_bone_count():
				var bn := rig_skel.get_bone_name(b)
				if not bn.begins_with("DEF-"):
					continue
				if bn.contains("f_") or bn.contains("thumb") or bn.contains("hand") or bn.contains("arm") or bn.contains("shoulder") or bn.contains("palm"):
					var wp: Vector3 = rig_skel.global_transform * rig_skel.get_bone_global_pose(b).origin
					var parent := rig_skel.get_bone_parent(b)
					var seg := 0.0
					if parent >= 0:
						seg = wp.distance_to(rig_skel.global_transform * rig_skel.get_bone_global_pose(parent).origin)
					print("HANDS_BONE %s gun_mm=%s seg_mm=%d eye_local_mm=%s" % [bn, (inv * wp * 1000.0).round(), int(round(seg * 1000.0)), (player.camera.global_transform.affine_inverse() * wp * 1000.0).round()])
			print("HANDS_RIG world_scale=", world_scale)
			for mesh: MeshInstance3D in vm.find_children("*", "MeshInstance3D", true, false):
				if assembly.is_ancestor_of(mesh) or not mesh.is_visible_in_tree():
					continue
				var mbox: AABB = (player.camera.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
				print("HANDS_MESH %s eye_local_min_mm=%s max_mm=%s skin=%s" % [mesh.name, (mbox.position * 1000.0).round(), (mbox.end * 1000.0).round(), str(mesh.skin != null)])
		var probe := Camera3D.new()
		probe.top_level = true
		probe.fov = 34.0
		probe.near = 0.01
		probe.cull_mask = player.camera.cull_mask
		root.add_child(probe)
		probe.current = true
		var eye_basis: Basis = player.camera.global_transform.basis
		var views := {"left": Vector3(-0.38, 0.03, 0.0), "right": Vector3(0.38, 0.03, 0.0), "top": Vector3(0.0, 0.38, 0.06),
			"below": Vector3(0.0, -0.38, 0.06), "rear": Vector3(0.0, 0.06, 0.40), "front_left": Vector3(-0.26, 0.05, -0.30)}
		for key: String in views:
			var centre: Vector3 = grip.global_position + eye_basis * Vector3(0.0, 0.03, -0.02)
			probe.global_position = centre + eye_basis * views[key]
			probe.look_at(centre, eye_basis.y if absf(views[key].y) < 0.3 else -eye_basis.z)
			await shot("hands_" + key)
		# The whole arms from outside: how far up do the sleeves go, and how do they end?
		probe.fov = 50.0
		var wide := {"arms_right": Vector3(1.1, 0.1, 0.25), "arms_left": Vector3(-1.1, 0.1, 0.25), "arms_above": Vector3(0.0, 1.2, 0.3), "arms_behind": Vector3(0.0, 0.25, 1.3), "arms_front": Vector3(0.3, 0.2, -1.2)}
		for key: String in wide:
			var mid: Vector3 = grip.global_position + eye_basis * Vector3(0.0, -0.05, 0.25)
			probe.global_position = mid + eye_basis * wide[key]
			probe.look_at(mid, eye_basis.y if absf(wide[key].y) < 0.9 else -eye_basis.z)
			await shot(key)
		quit(0)
		return
	# --body: what does the chest lens see of the player's own body, and do the
	# first-person arms meet its shoulders? Lens shots plus outside views.
	if OS.get_cmdline_user_args().has("--body"):
		rig.call("set_enabled", true)
		if not await equip("akane"):
			quit(1)
			return
		var body_node := player.get_node_or_null("UrbanExplorerBody")
		if body_node != null:
			for mesh: MeshInstance3D in body_node.get("_parts"):
				print("BODY_PART ", mesh.name, " shadow_mode=", mesh.cast_shadow)
		for pitch: float in [0.0, -30.0, -55.0, -80.0]:
			await face(base_yaw, deg_to_rad(pitch))
			await shot("body_rest_pitch_%d" % int(absf(pitch)))
		await face(base_yaw, 0.0)
		await aim(true)
		await shot("body_aim")
		await face(base_yaw, deg_to_rad(-30.0))
		await shot("body_aim_down30")
		await face(base_yaw, 0.0)
		var outside := Camera3D.new()
		outside.top_level = true
		outside.fov = 50.0
		outside.cull_mask = player.camera.cull_mask
		root.add_child(outside)
		var eb: Basis = player.camera.global_transform.basis
		var chest: Vector3 = player.camera.global_position - Vector3.UP * 0.3
		for pair: Array in [["right", Vector3(1.6, 0.1, -0.2)], ["front", Vector3(0.3, 0.2, -1.7)], ["above", Vector3(0.0, 1.8, -0.1)], ["left_front", Vector3(-1.1, 0.3, -1.2)]]:
			outside.global_position = chest + eb * pair[1]
			outside.look_at(chest + eb * Vector3(0, 0, -0.25), eb.y if absf(pair[1].y) < 1.0 else -eb.z)
			outside.current = true
			await shot("body_outside_aim_" + pair[0])
		await aim(false)
		await shot("body_outside_rest_left_front")
		quit(0)
		return
	# --reload: the pistol reload as a strip of frames, normal view then bodycam.
	if OS.get_cmdline_user_args().has("--reload"):
		if not await equip("akane"):
			quit(1)
			return
		for view: String in ["normal", "bodycam"]:
			rig.call("set_enabled", view == "bodycam")
			await frames(30)
			for kind: String in ["partial", "empty"]:
				# Partial: two rounds gone. Empty: shoot the magazine dry first.
				var shots := 2 if kind == "partial" else 40
				for i in shots:
					if int(player.ammo) <= 0 and kind == "empty":
						break
					player.set("_fire_requested", true)
					await frames(8)
				await frames(30)
				player.call("start_reload")
				await frames(1)
				print("RELOAD_BEGIN %s %s duration=%.2f reloading=%s empty=%s ammo=%d" % [view, kind, float(player.reload_duration), str(player.reloading), str(player.reload_empty), int(player.ammo)])
				var index := 0
				while bool(player.reloading) and index < 24:
					var ratio: float = float(player.reload_time) / maxf(float(player.reload_duration), 0.001)
					await shot("reload_%s_%s_%02d" % [view, kind, index], 0)
					print("RELOAD_FRAME %s %s %02d ratio=%.3f" % [view, kind, index, ratio])
					index += 1
					await frames(8)
				await frames(20)
				await shot("reload_%s_%s_done" % [view, kind], 0)
				print("RELOAD_END %s %s ammo=%d frames=%d" % [view, kind, int(player.ammo), index])
		quit(0)
		return
	# --reticle: check the bodycam reticle (scripts/fx/bodycam_reticle.gd) without
	# the rig knowing about it yet. Green crosses are drawn where the mapping says
	# known points of the yard should appear; they must sit on those points. The
	# reticle itself is driven from the eye's aim, as the rig will do.
	if OS.get_cmdline_user_args().has("--reticle"):
		rig.call("set_enabled", true)
		if not await equip("akane"):
			quit(1)
			return
		var Reticle: GDScript = load("res://scripts/fx/bodycam_reticle.gd")
		var reticle: CanvasLayer = Reticle.new()
		root.add_child(reticle)
		var consts: Dictionary = (rig.get_script() as GDScript).get_script_constant_map()
		var half_fov: float = deg_to_rad(float(consts.get("LENS_H_DEG", 130.0))) * 0.5
		var marks := [Vector3(0, 1.5, -5), Vector3(0, 1.5, -20), Vector3(0, 1.5, -50), Vector3(-0.9, 2.4, -4), Vector3(0.9, 2.4, -4),
			Vector3(1.75, 1.8, -10), Vector3(2.25, 0.0, -10), Vector3(-8.5, 2.0, -10), Vector3(8.5, 2.0, -10), Vector3(-8.5, 0.0, 2), Vector3(8.5, 4.0, 2), Vector3(-8.5, 6.0, -30)]
		var debug_layer := CanvasLayer.new()
		debug_layer.layer = 1
		root.add_child(debug_layer)
		var debug := Control.new()
		debug.set_anchors_preset(Control.PRESET_FULL_RECT)
		debug_layer.add_child(debug)
		var state := {"hit": Vector3.ZERO, "has": false}
		debug.draw.connect(func() -> void:
			var lens: Camera3D = rig.get("lens")
			var view := root.get_visible_rect().size
			for m: Vector3 in marks:
				var at: Vector2 = Reticle.screen_point(lens, m, half_fov, float(rig.get("_tan_src_h")), view.x / view.y, float(rig.get("lens_strength")), view)
				if at != Vector2.INF:
					debug.draw_line(at - Vector2(7, 0), at + Vector2(7, 0), Color(0.1, 1.0, 0.2), 1.5)
					debug.draw_line(at - Vector2(0, 7), at + Vector2(0, 7), Color(0.1, 1.0, 0.2), 1.5))
		physics_frame.connect(func() -> void:
			if not is_instance_valid(player):
				return
			var eye: Transform3D = player.camera.global_transform
			var query := PhysicsRayQueryParameters3D.create(eye.origin, eye.origin - eye.basis.z * 150.0)
			query.exclude = [player.get_rid()]
			var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
			state.has = not hit.is_empty()
			if state.has:
				state.hit = hit.position)
		process_frame.connect(func() -> void:
			if not is_instance_valid(player):
				return
			var view := root.get_visible_rect().size
			reticle.call("place", rig.get("lens"), state.hit, half_fov, float(rig.get("_tan_src_h")), view.x / view.y, float(rig.get("lens_strength")), bool(state.has), float(player.ads_blend))
			debug.queue_redraw())
		await frames(20)
		await shot("reticle_rest")
		await aim(true)
		await shot("reticle_aim")
		var eye2: Vector3 = player.camera.global_position
		var tb: Vector3 = Vector3(2.0, 1.2, -10.0) - eye2
		await face(atan2(-tb.x, -tb.z), atan2(tb.y, Vector2(tb.x, tb.z).length()))
		await shot("reticle_aim_board")
		await aim(false)
		await face(base_yaw + 0.5, deg_to_rad(12.0))
		await shot("reticle_rest_left_up")
		for i in 6:
			player.rotation.y -= deg_to_rad(6.0)
			await frames(1)
		await shot("reticle_turning", 0)
		await face(base_yaw - 0.6, deg_to_rad(-15.0))
		await shot("reticle_rest_right_down")
		quit(0)
		return
	# --pistol: does the handgun work through the chest lens? Aim, fire, reload.
	if OS.get_cmdline_user_args().has("--pistol"):
		rig.call("set_enabled", true)
		if not await equip("akane"):
			quit(1)
			return
		await shot("pistol_rest")
		await aim(true)
		await shot("pistol_aim")
		for pitch: float in [25.0, 45.0, -25.0]:
			await face(base_yaw, deg_to_rad(pitch))
			await shot("pistol_aim_pitch_%s%d" % ["up" if pitch > 0.0 else "down", int(absf(pitch))])
		player.rotation.y = base_yaw + 0.5
		await frames(3)
		await shot("pistol_aim_turning", 0)
		await face(base_yaw, 0.0)
		print("BODYCAM_PISTOL ammo_before=", player.ammo, " laser_hit=", rig.get("_laser_hit"), " laser_on=", rig.get("_laser_has_hit"))
		# One shot: the frames right after the trigger (flash, slide, recoil).
		player.set("_fire_requested", true)
		await frames(1)
		await shot("pistol_fire_f1", 0)
		await frames(1)
		await shot("pistol_fire_f2", 0)
		await frames(3)
		await shot("pistol_fire_f5", 0)
		await frames(30)
		print("BODYCAM_PISTOL ammo_after_one=", player.ammo)
		# Five more, then where did they land? (impact marks on the 5 m post / far wall)
		for i in 5:
			player.set("_fire_requested", true)
			await frames(14)
		print("BODYCAM_PISTOL ammo_after_six=", player.ammo)
		await shot("pistol_after_six")
		# Aim at the person-sized board (2 m right, 16 m ahead) and fire three.
		var eye_now: Vector3 = player.camera.global_position
		var to_board: Vector3 = Vector3(2.0, 1.2, -10.0) - eye_now
		await face(atan2(-to_board.x, -to_board.z), atan2(to_board.y, Vector2(to_board.x, to_board.z).length()))
		await shot("pistol_aim_board")
		for i in 3:
			player.set("_fire_requested", true)
			await frames(14)
		await shot("pistol_board_after_three")
		await face(base_yaw, 0.0)
		# Reload while aiming drops the aim; capture through the reload.
		await aim(false)
		player.call("start_reload")
		for i in 6:
			await frames(18)
			await shot("pistol_reload_%d" % i, 0)
		await frames(120)
		print("BODYCAM_PISTOL ammo_after_reload=", player.ammo, " reloading=", player.get("reloading"))
		await shot("pistol_after_reload")
		# Hip fire.
		player.set("_fire_requested", true)
		await frames(2)
		await shot("pistol_hipfire_f2", 0)
		await frames(30)
		# The same aimed frame in the normal view, for the before/after sheet.
		rig.call("set_enabled", false)
		await aim(true)
		await shot("pistol_aim_normal")
		await aim(false)
		await shot("pistol_rest_normal")
		quit(0)
		return

	# --sweep: aimed shots for several arm placements, one run, then quit.
	if OS.get_cmdline_user_args().has("--sweep"):
		rig.call("set_enabled", true)
		var long_shifts := {"A": Vector3(0.10, 0.28, -0.19), "B": Vector3(0.14, 0.26, -0.12), "C": Vector3(0.06, 0.30, -0.26),
			"D": Vector3(0.12, 0.22, -0.19), "E": Vector3(0.18, 0.30, -0.19), "F": Vector3(0.10, 0.34, -0.14)}
		var pistol_shifts := {"A": Vector3(0.0, 0.24, -0.17), "B": Vector3(0.0, 0.20, -0.17), "C": Vector3(0.0, 0.24, -0.11),
			"D": Vector3(0.0, 0.28, -0.20), "E": Vector3(0.03, 0.22, -0.14), "F": Vector3(0.0, 0.17, -0.20)}
		for pair: Array in [["raiden_r56", "vm_aim_long", long_shifts], ["akane", "vm_aim_pistol", pistol_shifts]]:
			if not await equip(pair[0]):
				continue
			await aim(true)
			for key: String in pair[2]:
				rig.set(pair[1], pair[2][key])
				await face(base_yaw, 0.0)
				await shot("sweep_%s_%s" % [pair[0], key])
				await face(base_yaw, deg_to_rad(25.0))
				await shot("sweep_%s_%s_up25" % [pair[0], key])
				await face(base_yaw, deg_to_rad(-25.0))
				await shot("sweep_%s_%s_down25" % [pair[0], key])
			await aim(false)
		quit(0)
		return

	var guns: Array = ["tobikage", "hayate", "yuzuru", "shigure", "kite", "raiden_r56", "akane"]
	var user_args := OS.get_cmdline_user_args()
	var gi := user_args.find("--guns")
	if gi >= 0 and gi + 1 < user_args.size():
		guns = Array(user_args[gi + 1].split(","))
	for id: String in guns:
		if not await equip(id):
			continue
		# Normal view (two guns are enough to show it is unchanged).
		rig.call("set_enabled", false)
		await aim(false)
		if id == "raiden_r56" or id == "akane":
			await shot(id + "_default_hip")
			await aim(true)
			await shot(id + "_default_ads")
			await aim(false)
		# Same spot through the chest lens.
		rig.call("set_enabled", true)
		await frames(30)
		await shot(id + "_bodycam_hip")
		await aim(true)
		await shot(id + "_bodycam_ads")
		await aim(false)

	# ---- motion series, bodycam on, pistol in hand -------------------------
	await face(base_yaw, deg_to_rad(30.0))
	await shot("motion_look_up30")
	await face(base_yaw, deg_to_rad(-30.0))
	await shot("motion_look_down30")
	await face(base_yaw, 0.0)
	# Mid-turn: 60 degrees in a third of a second, captured while still turning.
	for i in 20:
		player.rotation.y -= deg_to_rad(3.0)
		await frames(1)
		if i == 12:
			await shot("motion_mid_turn", 0)
	await frames(40)
	await shot("motion_after_turn")
	await face(base_yaw, 0.0)
	# Walk: four shots spread over a stride (1.9 steps a second).
	if raid == null:
		player.global_position = Vector3(4, 0.2, 6)   # a clear lane beside the posts
		player.velocity = Vector3.ZERO
		await frames(10)
	want_forward = true
	await frames(60)
	for i in 4:
		await shot("motion_walk_%d" % i, 8)
	# Aim while walking.
	await aim(true)
	await shot("motion_walk_aim")
	await aim(false)
	# Sprint.
	player.set("_controller_sprint", true)
	await frames(60)
	for i in 4:
		await shot("motion_sprint_%d" % i, 5)
	player.set("_controller_sprint", false)
	want_forward = false
	await frames(60)
	await shot("motion_stopped")

	# ---- lens strengths and motion scale, back at the start ------------------
	player.global_position = start_pos
	player.velocity = Vector3.ZERO
	await face(base_yaw, 0.0)
	for s: float in [0.0, 0.5, 1.0]:
		rig.set("lens_strength", s)
		await frames(10)
		await shot("lens_strength_%d" % int(s * 100.0))
	rig.set("lens_strength", 1.0)

	# ---- lens against a wall (arena only): must not see through it ---------------
	if raid == null:
		player.global_position = Vector3(-30, 0.2, 20.75)   # 0.55 m from the wall face
		player.velocity = Vector3.ZERO
		await face(0.0, 0.0)
		await frames(40)
		await shot("wall_close_bodycam")
		rig.call("set_enabled", false)
		await frames(20)
		await shot("wall_close_default")
		rig.call("set_enabled", true)
		player.global_position = start_pos
		await face(base_yaw, 0.0)

	# ---- off again: the normal view must come back ---------------------------
	rig.call("set_enabled", false)
	await frames(30)
	await shot("akane_default_hip_after")
	await aim(true)
	await shot("akane_default_ads_after")
	await aim(false)
	if raid != null:
		raid.finish_run(false, "Bodycam capture")
	quit(0)
