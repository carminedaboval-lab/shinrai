extends SceneTree

var failures: Array[String] = []
var render := false

func _initialize() -> void:
	render = OS.get_cmdline_user_args().has("--render")
	call_deferred("run_tests")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error("TEST FAILED: " + description)

func run_tests() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_salvage_choice_test.json"
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(scene.profile_path + suffix)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 30000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	check(raid.phase == raid.Phase.HQ, "Park reaches HQ")
	if raid.phase != raid.Phase.HQ:
		quit(1)
		return
	raid.start_run()
	check(raid.phase == raid.Phase.RAID, "Raid starts")
	var caches: Array = raid.sites.filter(func(site: Dictionary) -> bool: return site.kind == "cache")
	check(caches.size() >= 2, "Two existing bench caches are available")
	if caches.size() < 2:
		quit(1)
		return
	var first: Dictionary = caches[0]
	first.loot = raid.ITEMS[0].duplicate()
	raid.player.position = first.position + Vector3(2, 0.2, 0)
	check(raid.open_cache_choice(first), "Bench search opens a choice")
	check(raid.phase == raid.Phase.PAUSED and raid.bag.is_empty() and first.discovered and not first.done, "Discovery pauses the raid without awarding loot")
	var first_loot: Dictionary = first.loot.duplicate(true)
	check(raid.resolve_cache_choice("leave"), "Leave closes the choice")
	check(raid.phase == raid.Phase.RAID and not first.done and first.loot == first_loot, "Leaving retains the same unclaimed item")
	check(raid.open_cache_choice(first), "Left item can be inspected again")
	check(raid.resolve_cache_choice("take"), "Take adds the found item")
	check(first.done and raid.bag.size() == 1 and raid.bag[0].id == first_loot.id, "Taken cache closes and fills one slot")
	check(not raid.open_cache_choice(first) and not raid.resolve_cache_choice("take") and raid.bag.size() == 1, "Taken item cannot be duplicated")
	var second: Dictionary = caches[1]
	second.loot = raid.ITEMS[3].duplicate()
	raid.profile.data.pack_level = 2 # Exercise the ten-slot UI without touching a player profile.
	check(raid.capacity() == 10, "Choice UI is tested at maximum cargo capacity")
	while raid.bag.size() < raid.capacity():
		raid.bag.append(raid.ITEMS[1].duplicate())
	var old_first: Dictionary = raid.bag[0].duplicate(true)
	var old_second: Dictionary = raid.bag[1].duplicate(true)
	raid.player.position = second.position + Vector3(2, 0.2, 0)
	check(raid.open_cache_choice(second), "Full cargo still permits inspecting a cache")
	var choices: Array[Node] = raid.hud.panel_content.find_children("*", "Button", true, false)
	var has_take := false
	var has_leave := false
	var has_swap := false
	for control: Node in choices:
		var button := control as Button
		if button.text == "CARGO FULL" and button.disabled:
			has_take = true
		elif button.text == "LEAVE IN COMPARTMENT":
			has_leave = true
		elif button.text.begins_with("SLOT 2"):
			has_swap = true
	check(has_take and has_leave and has_swap, "Choice UI shows disabled Take, Leave and targeted Swap")
	if render:
		await capture("salvage_full_cargo")
	check(not raid.resolve_cache_choice("take") and not raid.resolve_cache_choice("swap", 999), "Full-bag Take and invalid slot do not mutate cargo")
	check(raid.phase == raid.Phase.PAUSED and raid.bag[1] == old_second and not second.done, "Rejected choice keeps cache open")
	check(raid.resolve_cache_choice("swap", 1), "Swap targets the selected cargo slot")
	check(raid.phase == raid.Phase.RAID and second.done and raid.bag.size() == raid.capacity(), "Swap closes cache without changing bag size")
	check(raid.bag[0] == old_first and raid.bag[1].id == "archive", "Swap preserves other slots and replaces only slot two")
	check(not raid.open_cache_choice(second) and not raid.resolve_cache_choice("swap", 1), "Swapped item cannot be claimed again")
	check(raid.profile.data.stash.is_empty(), "Unextracted cargo is absent from saved stash")
	var relay: Dictionary = raid.sites.filter(func(site: Dictionary) -> bool: return site.kind == "relay")[0]
	raid.player.position = relay.position + Vector3(2, 0.2, 0)
	check(raid.complete_site(relay), "One relay enables extraction")
	raid.finish_run(true, "Salvage choice test extracted")
	check(raid.profile.data.stash.get("archive", 0) == 1 and raid.profile.data.stash.get("circuit", 0) == 1, "Only accepted cargo is banked on extraction")
	check(raid.profile.data.stash.get("optics", 0) == raid.capacity() - 2, "Replaced item is not banked")
	print("SALVAGE_CHOICE_TEST_RESULT: ", failures.size(), " failures")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(scene.profile_path + suffix)
	quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	for frame: int in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://extraction_qa")
	var path := "user://extraction_qa/" + label + ".png"
	root.get_texture().get_image().save_png(path)
	print("SALVAGE_UI_CAPTURE: ", ProjectSettings.globalize_path(path))
