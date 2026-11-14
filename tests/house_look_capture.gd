extends SceneTree
## Real pictures of the kit house in the test yard, drawn by the graphics card:
##   godot --path . --resolution 1600x900 --fixed-fps 60 --script res://tests/house_look_capture.gd
## Writes reports/interiors/look_<view>.jpg. The headless probe (tests/probe_house.gd) proves
## the rules; this shows how the house, the stair, the doors and the broken glass really look.
## Camera places are in the house's own metres (x along the front, y up, z back from it).

const YardWorld := preload("res://scripts/test_yard/yard_world.gd")

var yard: Node3D
var house: Node3D
var camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/interiors"))
	yard = YardWorld.new()
	root.add_child(yard)
	yard.build()
	house = yard.get_node("YardHouse")
	var f0: float = house.floor_heights[0]
	var f1: float = house.floor_heights[1]
	camera = Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	# Somebody to work the doors: a point, standing clear of where each leaf swings.
	var hand := Node3D.new()
	yard.add_child(hand)
	for i: int in 30:
		await physics_frame
		await process_frame
	var window: Node3D = house.window("front_living")
	var outside_window := [Vector3(0.2, 1.55, -3.4), Vector3(1.7, 1.15, 0.0), 50.0]

	await _shot("street", Vector3(-2.5, 1.7, -10.5), Vector3(4.4, 2.7, 0.0), 55.0)
	await _shot("window_intact", outside_window[0], outside_window[1], outside_window[2])

	hand.global_position = house.to_global(Vector3(4.18, 0.0, -1.8))
	house.door("front").interact(hand)
	await _wait(1.2)
	await _shot("front_door_open", Vector3(2.3, 1.6, -4.4), Vector3(4.3, 1.2, 0.6), 55.0)
	await _shot("stair_from_below", Vector3(4.62, f0 + 1.55, 1.0), Vector3(3.75, f0 + 1.45, 4.2), 68.0)
	await _shot("landing_and_banister", Vector3(4.7, f1 + 1.55, 6.1), Vector3(4.2, f1 + 0.8, 2.6), 70.0)

	hand.global_position = house.to_global(Vector3(4.65, f1, 1.67))
	house.door("bedroom").interact(hand)
	await _wait(1.2)
	await _shot("upper_room", Vector3(2.75, f1 + 1.55, 6.0), Vector3(1.3, f1 + 1.05, 0.6), 72.0)
	await _shot("locked_door", Vector3(4.55, f1 + 1.55, 2.5), Vector3(5.2, f1 + 1.05, 4.75), 62.0)

	# One bullet from the street, a little off the middle of the pane.
	window.receive_bullet_hit(30.0, null, window.to_global(Vector3(-0.22, 0.28, 0.0)), window.global_basis.z)
	await _wait(0.2)
	await _shot("window_shot", outside_window[0], outside_window[1], outside_window[2])
	await _shot("window_shot_from_inside", Vector3(2.35, f0 + 1.5, 2.7), Vector3(1.6, f0 + 0.75, 0.0), 62.0)
	await _shot("window_shot_shards_close", Vector3(1.25, f0 + 1.75, -0.9), Vector3(1.05, f0 + 1.9, 0.07), 45.0)

	window.knock_out(null)
	await _wait(0.2)
	await _shot("window_knocked_clean", outside_window[0], outside_window[1], outside_window[2])
	print("HOUSE_LOOK_DONE")
	quit(0)


func _wait(seconds: float) -> void:
	for i: int in int(seconds * 60.0):
		await physics_frame
		await process_frame


## One picture: camera at `from`, looking at `at`, both in the house's own metres.
func _shot(view: String, from: Vector3, at: Vector3, fov: float) -> void:
	camera.global_position = house.to_global(from)
	camera.look_at(house.to_global(at))
	camera.fov = fov
	for i: int in 20: await process_frame
	var path := ProjectSettings.globalize_path("res://reports/interiors/look_%s.jpg" % view)
	root.get_texture().get_image().save_jpg(path, 0.92)
	print("HOUSE_LOOK ", path)
