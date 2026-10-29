extends SceneTree
const Hud = preload("res://scripts/extraction_hud.gd")
const Run = preload("res://scripts/extraction_run.gd")
class FakePlayer extends CharacterBody3D:
	var health := 67.0
	var ammo := 21
	var reserve := 90
var failures := 0
func _initialize() -> void:
	call_deferred("review")
func button(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix): return node
	for child: Node in node.get_children():
		var result := button(child, prefix)
		if result != null: return result
	return null
func check(value: bool, text: String) -> void:
	print("PASS: " if value else "FAIL: ", text)
	if not value: failures += 1
func capture(label: String) -> void:
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHINRAI_UI_QA").path_join(label + ".png"))
func review() -> void:
	root.size = Vector2i(1920,1080)
	root.content_scale_size = root.size
	var run := Run.new()
	run.player = FakePlayer.new()
	run.profile.data.stash = {"circuit":3,"optics":2,"cell":4,"archive":1,"coffee_cup":2,"park_map":1}
	run.profile.data.credits = 1600
	run.phase = Run.Phase.HQ
	var hud := Hud.new()
	root.add_child(hud)
	hud.show_inventory(run)
	var inventory: Control = hud.panel_content.get_child(0)
	inventory._select(4)
	await capture("final_stash_cup_1080")
	var clip: Control = inventory.detail.get_parent()
	for text: String in ["SELL ONE", "SELL ×2"]:
		var action := button(inventory.detail,text)
		check(action != null and clip.get_global_rect().encloses(action.get_global_rect()), "HQ cup action visible without scroll: " + text)
	root.size = Vector2i(1280,720)
	await capture("final_stash_cup_720")
	root.size = Vector2i(1920,1080)
	run.phase = Run.Phase.PAUSED
	run.inventory_open = true
	for item: Dictionary in Run.ITEMS: run.bag.append(item.duplicate(true))
	hud.show_inventory(run)
	inventory = hud.panel_content.get_child(0)
	inventory._select(4)
	await capture("final_field_cup_1080")
	clip = inventory.detail.get_parent()
	for text: String in ["DRINK COFFEE", "DISCARD ITEM"]:
		var action := button(inventory.detail,text)
		check(action != null and clip.get_global_rect().encloses(action.get_global_rect()), "Field cup action visible without scroll: " + text)
	root.size = Vector2i(1280,720)
	await capture("final_field_cup_720")
	hud.queue_free()
	run.player.free()
	run.free()
	await process_frame
	print("UI_LAYOUT_RESULT: 4 action bounds, ", failures, " failures")
	quit(1 if failures > 0 else 0)
