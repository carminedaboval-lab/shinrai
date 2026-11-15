extends "res://tests/probe_map1_world.gd"
## The north block's corner shop (tools/map_plan/businesses.py, PLACED): the real player walks
## from the middle of lane z378, the block's farthest point from any other shop, to the shop's
## door and back, and the walked distance is measured. Headless:
##   godot --headless --path . --fixed-fps 60 --script res://tests/map1_corner_shop_walk.gd
## Prints WORLD_PASS / WORLD_FAIL lines and CORNER_SHOP_DONE.

const FROM := Vector3(111.0, 0.0, 378.24)      # the middle of lane z378
const LANE_Z := 378.24


func _run() -> void:
	map = Blockout.new()
	map.with_player = false
	root.add_child(map)
	world = map.world
	player = RealPlayer.new()
	map.add_child(player)
	camera = player.camera
	world.set_viewer(camera, player)
	_label = "corner shop"
	var index := -1
	for entry: Dictionary in map.data.get("businesses", []):
		if str(entry.get("why", "")).begins_with("the north block's crossroads"): index = int(entry.box)
	_check(index >= 0, "the map names a corner shop at the north block's crossroads")
	if index < 0:
		print("CORNER_SHOP_DONE passed=", passed, " failed=", failed)
		quit(1)
		return
	var site: Dictionary = world.site(index)
	_check(bool(site.ok) and str(site.features.get("business", "")) != "", "its house is made as a shop: %s, with %s" % [str(site.features.get("business", "none")), str(site.features.get("shop_front", []))])
	var door: Vector3 = site.door_point
	var out: Vector3 = site.street_out
	# In front of the door: a step out from it; then out to the lane it faces; then along lane z378.
	var at_door := door + out * 0.7
	var on_street := door + out * 2.4
	var turn := Vector3(on_street.x, 0.0, LANE_Z)
	var there: Array = [turn, on_street, at_door]
	var walked := 0.0
	var last := FROM
	for point: Vector3 in there:
		walked += Vector2(point.x - last.x, point.z - last.z).length()
		last = point
	await _put(map.on_ground(FROM.x, FROM.z, 0.25))
	_check(await _drive(there, false, 60.0), "walked from the middle of lane z378 (%.0f, %.0f) to the shop's door at (%.1f, %.1f): %.0f m on foot" % [FROM.x, FROM.z, door.x, door.z, walked])
	var gap := Vector2(player.global_position.x - door.x, player.global_position.z - door.z).length()
	_check(gap < 1.2, "stands %.2f m from the door" % gap)
	_check(await _drive([on_street, turn, FROM], false, 60.0), "and walked back the same way")
	_info("straight line from (%.0f, %.0f) to the door: %.0f m; walked: %.0f m" % [FROM.x, FROM.z, Vector2(FROM.x - door.x, FROM.z - door.z).length(), walked])
	print("CORNER_SHOP_DONE passed=", passed, " failed=", failed)
	quit(1 if failed else 0)
