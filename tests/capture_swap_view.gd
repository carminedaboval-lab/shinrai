extends "res://tests/probe_map1_world.gd"
## What the player sees when a far building changes from its grey box to its house on a cold
## start: the old-town jump of the cuts check, turning round as it does, stopped the moment the
## watched box is about to change. Two pictures from the same fixed camera, one with the box and
## one with the house, and the same pair zoomed in on the building.
##   godot --path . --fixed-fps 60 --script res://tests/capture_swap_view.gd -- --box=1758
## Writes reports/map1_world/swap_<box>_box.png, _house.png, _zoom_box.png, _zoom_house.png and
## prints SWAP_VIEW lines. Not headless: it needs the pictures.

const OUT_DIR := "reports/map1_world"

var _watched := 1758
var _caught := false
var _why := ""


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--box="): _watched = int(arg.trim_prefix("--box="))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	map = Blockout.new()
	map.with_player = false
	root.add_child(map)
	world = map.world
	player = RealPlayer.new()
	map.add_child(player)
	camera = player.camera
	world.set_viewer(camera, player)
	for label: Label3D in map.labels: label.visible = false
	world.changing.connect(_seen_changing)
	# As the cuts check does it: from far away, then the jump, then turn right round.
	await _put(map.on_ground(-600.0, -100.0, 0.2))
	await _frames(20)
	_reset_seen()
	await _put(map.on_ground(520.0, -520.0, 0.1), Vector3(1, 0, 0))
	var turned := 0
	while turned < 360 and not _caught:
		player.rotation.y += deg_to_rad(6.0)
		turned += 6
		await physics_frame
	if not _caught:
		print("SWAP_VIEW box %d did not change during the turn; nothing to picture" % _watched)
		quit(1)
		return
	# The camera stays as it is from here on.
	var eye: Vector3 = camera.global_position
	var centre: Vector3 = world.centre_of(_watched)
	print("SWAP_VIEW box %d changed after turning %d degrees, said %s; eye (%.1f, %.1f, %.1f), the building %.0f m away, %.0f degrees off the view's centre, field of view %.0f" % [
		_watched, turned, _why, eye.x, eye.y, eye.z, centre.distance_to(eye), rad_to_deg((-camera.global_transform.basis.z).angle_to(centre - eye)), camera.fov])
	await _frames(3)
	await _save("swap_%d_house.png" % _watched)
	_show_box(true)
	await _frames(3)
	await _save("swap_%d_box.png" % _watched)
	# The same pair, zoomed on the building (not what the player sees: for looking closely).
	var keep := camera.global_transform
	var keep_fov := camera.fov
	camera.look_at(centre + Vector3.UP * 2.0)
	camera.fov = 6.0
	await _frames(3)
	await _save("swap_%d_zoom_box.png" % _watched)
	_show_box(false)
	await _frames(3)
	await _save("swap_%d_zoom_house.png" % _watched)
	camera.global_transform = keep
	camera.fov = keep_fov
	print("SWAP_VIEW_DONE")
	quit()


func _seen_changing(index: int, from: int, to: int, why: int) -> void:
	if index != _watched or from != BOX or _caught: return
	_caught = true
	_why = World.Why.keys()[why]


## The watched building drawn as its grey box (true) or as its house (false), nothing else changed.
func _show_box(as_box: bool) -> void:
	if world.looks.has(_watched): (world.looks[_watched] as Node3D).visible = not as_box
	map.set_box_drawn(_watched, as_box)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + OUT_DIR))
	image.save_png(ProjectSettings.globalize_path("res://%s/%s" % [OUT_DIR, name]))
	print("SWAP_VIEW saved %s" % name)
