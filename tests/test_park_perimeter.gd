extends SceneTree
## Fence, gates, prone holes, cover spacing and wildlife, in the real park scene.
## Headless: godot --headless --path . --script res://tests/test_park_perimeter.gd
## Screenshots: omit --headless and append -- --render (saved to user://perimeter_qa/).

var failures: Array[String] = []
var render := false
var scene: Node3D
var raid: Node
var fence: Node3D
var cover: Node3D
var wildlife: Node3D

func _initialize() -> void:
	render = OS.get_cmdline_user_args().has("--render")
	call_deferred("run_tests")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error("TEST FAILED: " + description)

func wait_frames(count: int) -> void:
	for i: int in range(count): await physics_frame

func run_tests() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	scene = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_perimeter_automated_test.json"
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(scene.profile_path + suffix)
	root.add_child(scene)
	current_scene = scene
	raid = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 240000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	check(raid.phase == raid.Phase.HQ, "Park prepares and reaches HQ")
	fence = scene.get_node("MidoriParkFence")
	cover = scene.get_node("MidoriParkCover")
	wildlife = scene.get_node("MidoriParkWildlife")
	check(fence.installed, "Fence installed")
	check(cover.installed, "Cover installed")
	check(wildlife.installed, "Wildlife installed")
	print("PERIMETER_REPORT fence=", fence.report, " cover=", cover.report, " wildlife=", wildlife.report)
	check(int(fence.report.get("holes", 0)) == 7, "Exactly seven fence holes built")
	check(int(fence.report.get("gates", 0)) == 4, "Four gates built")
	check_cover_spacing()
	await check_day()
	await check_night()
	await check_cut()
	await check_birds()
	if render: await capture()
	print("PERIMETER_TEST_RESULT: ", failures.size(), " failures")
	for failure: String in failures: print("FAILED: ", failure)
	quit(1 if failures.size() > 0 else 0)

func check_cover_spacing() -> void:
	check(cover.placements.size() >= 30, "Cover pieces placed across the lawns (%d)" % cover.placements.size())
	var tall := 0
	var worst := 0.0
	for a: Dictionary in cover.placements:
		if a.tall: tall += 1
		var nearest := INF
		for b: Dictionary in cover.placements:
			if a != b: nearest = minf(nearest, (a.position as Vector3).distance_to(b.position))
		worst = maxf(worst, nearest)
	check(tall >= 10, "Sight-blocking tall pieces placed (%d)" % tall)
	print("COVER_SPACING worst_nearest_neighbour_m=", worst)
	var total := 0.0
	for a: Dictionary in cover.placements:
		var nearest := INF
		for b: Dictionary in cover.placements:
			if a != b: nearest = minf(nearest, (a.position as Vector3).distance_to(b.position))
		total += nearest
	var mean := total / float(cover.placements.size())
	print("COVER_SPACING mean_nearest_neighbour_m=", mean)
	check(mean > 24.0 and mean < 46.0, "Mean cover spacing is near the 36 m target (%.1f m)" % mean)

func ray_clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [raid.player.get_rid()])
	return raid.player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func gate_named(id: String) -> Dictionary:
	for gate: Dictionary in fence._gates:
		if gate.id == id: return gate
	return {}

func set_time(night: bool) -> void:
	scene.is_night_mode = night
	scene._apply_time_of_day()
	await wait_frames(3)

func gate_through(id: String, height: float) -> bool:
	var root_node: Node3D = gate_named(id).root
	return ray_clear(root_node.to_global(Vector3(0.9, height, 1.2)), root_node.to_global(Vector3(0.9, height, -1.2)))

func check_day() -> void:
	await set_time(false)
	for id: String in ["south", "north", "west", "east"]:
		check(gate_through(id, 1.0), "Day: %s gate stands open" % id)
	for centre: Vector3 in fence.hole_positions():
		var inward := -centre.normalized() * Vector3(1, 0, 1)
		var normal := Vector3(signf(inward.x), 0, 0) if absf(centre.x) > 218.0 else Vector3(0, 0, signf(inward.z))
		check(not ray_clear(centre + Vector3.UP * 0.4 + normal, centre + Vector3.UP * 0.4 - normal), "Day: fence is intact at %s" % centre)
		check(not ray_clear(centre + Vector3.UP * 1.3 + normal, centre + Vector3.UP * 1.3 - normal), "Day: fence is solid high at %s" % centre)

func check_night() -> void:
	await set_time(true)
	for id: String in ["north", "west", "east"]:
		check(not gate_through(id, 1.0), "Night: %s gate is shut" % id)
		check(gate_named(id).locked, "Night: %s gate is chained" % id)
	check(not gate_named("south").locked, "Night: south gate has no chain")
	var south := gate_named("south")
	check(gate_through("south", 1.0), "Night: smashed south gate can be walked through")
	var hanging: Dictionary = south.panels[0]
	var lying: Dictionary = south.panels[1]
	var pivot: Node3D = hanging.pivot
	var hanging_tilt := absf((pivot.global_basis.x.normalized()).y)
	check(hanging_tilt > 0.05, "Night: one south panel hangs crooked (%.3f)" % hanging_tilt)
	check(pivot.position.y > fence.HEIGHT, "Night: hanging panel lifted off its lower hinge")
	check((lying.shape as CollisionShape3D).disabled, "Night: fallen panel can be walked over")
	var lying_body: Node3D = lying.body
	check(lying_body.global_position.y < 2.2 and absf((lying.pivot as Node3D).global_basis.y.normalized().y) < 0.1, "Night: other south panel lies flat on the ground")
	var player: CharacterBody3D = raid.player
	raid.start_run()
	await wait_frames(30)
	check(raid.phase == raid.Phase.RAID, "Raid starts at night")
	player._prone_requested = true
	await wait_frames(5)
	check(player.prone and player.crouching, "Requesting prone lowers the player")
	check(is_equal_approx(player.body_capsule.height, player.PRONE_CAPSULE_HEIGHT), "Prone capsule is 0.72 m")
	check(player.movement_speed() < player.CROUCH_SPEED, "Prone is slower than crouching")
	player._prone_requested = false
	await wait_frames(5)
	for centre: Vector3 in fence.hole_positions():
		await crawl_hole(player, centre)
	player._prone_requested = false

func crawl_hole(player: CharacterBody3D, centre: Vector3) -> void:
	var normal := Vector3(signf(centre.x), 0, 0) if absf(centre.x) > 218.0 else Vector3(0, 0, signf(centre.z))
	var inside := centre - normal * 1.2
	var outside := centre + normal * 1.2
	# Capsules match the player's radius and stance heights exactly.
	check(not sweep_fits(player, player.STANDING_CAPSULE_HEIGHT, inside, outside), "Standing player cannot pass hole at %s" % centre)
	check(not sweep_fits(player, player.CROUCH_CAPSULE_HEIGHT, inside, outside), "Crouched player cannot fit through hole at %s" % centre)
	check(sweep_fits(player, player.PRONE_CAPSULE_HEIGHT, inside, outside), "Prone player crawls through hole at %s" % centre)
	var along := Vector3(normal.z, 0, normal.x)
	check(not sweep_fits(player, player.PRONE_CAPSULE_HEIGHT, inside + along * 1.3, outside + along * 1.3), "Prone player is still blocked beside hole at %s" % centre)
	var far_side := outside + Vector3.UP * 0.1
	check(raid._inside_playable_area(far_side), "Far side of hole at %s is playable" % centre)
	var floor_hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(far_side + Vector3.UP, far_side + Vector3.DOWN * 3.0, 1, [player.get_rid()]))
	check(not floor_hit.is_empty(), "Far side of hole at %s has ground" % centre)
	# The real stance code: releasing prone under the wire must keep you down.
	player._prone_requested = true
	player.global_position = centre + Vector3.UP * 0.08
	player.velocity = Vector3.ZERO
	await wait_frames(4)
	check(player.prone, "Player goes prone at hole %s" % centre)
	check(fence._hole_prompt(player).is_empty(), "No crawl prompt once prone at %s" % centre)
	check(not player._crouch_capsule_clear(), "Crouch stance is refused while under the wire at %s" % centre)
	player._prone_requested = false
	await wait_frames(4)
	check(player.prone, "Player stays prone under the wire at %s" % centre)
	player.global_position = inside + Vector3.UP * 0.08
	player.velocity = Vector3.ZERO
	await wait_frames(20)
	check(not player.prone and not player.crouching, "Player stands once clear of the wire at %s" % centre)
	check("crawl" in fence._hole_prompt(player), "Standing near hole %s shows the crawl prompt" % centre)
	check(is_equal_approx(player.body_capsule.height, player.STANDING_CAPSULE_HEIGHT), "Standing capsule restored at %s" % centre)

## True when a player-sized capsule can travel the whole way without touching.
func sweep_fits(player: CharacterBody3D, height: float, from: Vector3, to: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	query.margin = 0.001
	query.transform = Transform3D(Basis.IDENTITY, from + Vector3.UP * (height * 0.5 + 0.03))
	query.motion = to - from
	var result: PackedFloat32Array = player.get_world_3d().direct_space_state.cast_motion(query)
	return result.size() >= 2 and result[0] >= 0.999

func check_cut() -> void:
	var player: CharacterBody3D = raid.player
	var gate := gate_named("north")
	var root_node: Node3D = gate.root
	player.global_position = root_node.to_global(Vector3(0, 0.1, 1.2))
	await wait_frames(2)
	var refused: String = fence.consume_interaction(raid, player, INF, true, false, 0.016)
	check("bolt cutters" in refused, "Chain asks for bolt cutters without the tool")
	raid.bag.append({"id":"bolt_cutters", "title":"Bolt cutters", "value":38, "mass_kg":1.4})
	var ready_prompt: String = fence.consume_interaction(raid, player, INF, true, false, 0.016)
	check("Cut gate chain" in ready_prompt, "Chain offers to cut with the tool")
	for i: int in range(180):
		fence.consume_interaction(raid, player, INF, true, true, 0.016)
		if not gate.locked: break
	check(not gate.locked, "Holding E cuts the chain")
	await wait_frames(100)
	check(gate.open, "Cut gate swings open")
	check(gate_through("north", 1.0), "Cut gate no longer blocks the way")
	fence.reset_for_raid()
	check(gate.locked, "A new raid chains the gate again")

func check_birds() -> void:
	await set_time(false)
	var flock: Dictionary = wildlife._flocks[0]
	var bird: Dictionary = flock.birds[0]
	var player: CharacterBody3D = raid.player
	player.global_position = Vector3(bird.position) + Vector3(2, 0.5, 0)
	await wait_frames(30)
	check(flock.alarmed or int(bird.state) != wildlife.State.GROUND, "Birds scatter when the player walks close")
	player.global_position = Vector3(0, 0.3, 160)
	var origin_site: Vector3 = wildlife._sites[int(flock.site)]
	for step: int in range(6000):
		for entry: Variant in flock.birds:
			if int(entry.state) != wildlife.State.GROUND: wildlife._step_flight(entry, 0.05)
		if not flock.alarmed: break
	check(not flock.alarmed, "A scattered flock lands again")
	check(Vector3(bird.position).distance_to(origin_site) < 12.0, "The flock lands at its new site")
	check(not wildlife._is_water(Vector2(bird.position.x, bird.position.z)), "Birds do not land on the lake")

func snapshot(label: String, eye: Vector3, target: Vector3) -> void:
	var camera: Camera3D = Camera3D.new()
	scene.add_child(camera)
	camera.global_position = eye
	camera.look_at(target)
	camera.fov = 62
	camera.make_current()
	raid.hud.hide()
	await wait_frames(40)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://perimeter_qa/%s.png" % label)
	print("CAPTURE ", ProjectSettings.globalize_path("user://perimeter_qa/%s.png" % label))
	camera.queue_free()

func capture() -> void:
	DirAccess.make_dir_recursive_absolute("user://perimeter_qa")
	raid.player.process_mode = Node.PROCESS_MODE_DISABLED
	await set_time(false)
	await snapshot("south_gate_day", Vector3(10, 2.4, 170), Vector3(0, 1.0, 180))
	await snapshot("north_gate_day", Vector3(-70, 2.0, -172), Vector3(-76, 1.0, -180))
	var p: Dictionary = cover.placements[cover.placements.size() / 2]
	await snapshot("cover_day", Vector3(p.position) + Vector3(9, 2.2, 9), Vector3(p.position) + Vector3.UP)
	var c: Vector3 = cover.camps[0]
	await snapshot("camp_day", c + Vector3(7, 3.0, 7), c + Vector3.UP * 0.5)
	for kind: String in ["jersey_chevron", "sandbag_corner", "draped_barriers", "cable_drums", "tarp_screen", "relief_crates", "portable_cabins", "water_tanks"]:
		for entry: Dictionary in cover.placements:
			if entry.kind == kind:
				await snapshot("kind_" + kind, Vector3(entry.position) + Vector3(5, 2.0, 4), Vector3(entry.position) + Vector3.UP * 0.9)
				break
	var bird_at: Vector3 = wildlife._birds[wildlife._flocks[1].birds.size() + 2].position
	await snapshot("birds_day", bird_at + Vector3(1.7, 0.8, 1.2), bird_at + Vector3.UP * 0.1)
	var crow_at: Vector3 = wildlife._flocks[2].birds[0].position
	await snapshot("crow_day", crow_at + Vector3(1.4, 0.7, 1.3), crow_at + Vector3.UP * 0.12)
	var flyer: Dictionary = wildlife._flocks[3]
	wildlife._scatter(flyer, Vector3(flyer.birds[0].position) + Vector3(3, 0, 0))
	await wait_frames(45)
	# The snapshot settles for 40 frames, so aim where the flock will be by then.
	var flock_at: Vector3 = Vector3(flyer.birds[1].position) + Vector3(flyer.birds[1].velocity) * 0.7
	await snapshot("birds_flying", flock_at + Vector3(11, -5.0, 13), flock_at)
	var shore: Vector3 = wildlife._shore_points()[8]
	await snapshot("koi_day", shore + Vector3(1.5, 3.2, 2.5), shore)
	await set_time(true)
	await snapshot("fireflies_night", wildlife._ground(wildlife.GROVES[1] + Vector2(-5, -5)) * Vector3.UP + Vector3(wildlife.GROVES[1].x - 5, 1.6, wildlife.GROVES[1].y - 5), wildlife._ground(wildlife.GROVES[1]) * Vector3.UP + Vector3(wildlife.GROVES[1].x, 1.1, wildlife.GROVES[1].y))
	var low: Vector3 = fence.hole_positions()[1]
	var low_normal := Vector3(signf(low.x), 0, 0) if absf(low.x) > 218.0 else Vector3(0, 0, signf(low.z))
	await snapshot("hole_outside_night", low + low_normal * 3.2 + Vector3.UP * 0.9, low + Vector3.UP * 0.35)
	await snapshot("south_gate_night", Vector3(-6, 1.8, 170), Vector3(0, 1.0, 180))
	await snapshot("north_gate_night", Vector3(-73, 1.8, -175), Vector3(-76, 1.0, -180))
	var h: Vector3 = fence.hole_positions()[0]
	var n := Vector3(signf(h.x), 0, 0) if absf(h.x) > 218.0 else Vector3(0, 0, signf(h.z))
	await snapshot("hole_night", h - n * 3.0 + Vector3.UP * 1.0, h + Vector3.UP * 0.3)
	await snapshot("camp_night", c + Vector3(7, 3.0, 7), c + Vector3.UP * 0.5)
