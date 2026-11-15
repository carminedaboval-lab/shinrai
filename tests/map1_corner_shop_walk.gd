extends "res://tests/probe_map1_world.gd"
## The corner shops placed by hand (tools/map_plan/businesses.py, PLACED): for each, the real
## player walks from the point of its block that was farthest from any shop to the shop's door
## and back, along the lanes, and the length of that route is given. Headless:
##   godot --headless --path . --fixed-fps 60 --script res://tests/map1_corner_shop_walk.gd
## Prints WORLD_PASS / WORLD_FAIL lines and CORNER_SHOP_DONE.

## Each: how the map's entry for the shop begins, and the walks to it: where from, then the
## lane corners to turn at on the way (the last stretch to the door is worked out from the shop).
const SHOPS: Array = [
	{"why": "the north block's crossroads", "walks": [
		{"from": Vector3(111.0, 0.0, 378.24), "via": [], "name": "the middle of lane z378"}]},
	{"why": "the east grid's crossroads", "walks": [
		{"from": Vector3(312.0, 0.0, 496.7), "via": [], "name": "the middle of lane z497"}]},
	# The nearest shop already there that can be walked to from the middle of lane z435: the sushi
	# counter on the grid's east edge (box 2146), along the lane to its east end and up the street
	# it faces. Traced to say how far lane z435 really is from a shop.
	{"box": 2146, "why": "lane z435's nearest shop", "walks": [
		{"from": Vector3(314.0, 0.0, 435.1), "via": [], "name": "the middle of lane z435"}]},
	# (Not walked: lane z435 to the east grid's own shop. Lanes x 329 and x 370 are dead ends between lane z435 and lane z497,
	# so inside the grid there is no way from one to the other; this shop serves lane z497, and
	# lane z435 is still far from a shop on foot. Found 2026-11-15 by trying that walk: the player
	# stopped at the end of lane x 370, at (370.2, 476.4).)
]


func _run() -> void:
	map = Blockout.new()
	map.with_player = false
	root.add_child(map)
	world = map.world
	player = RealPlayer.new()
	map.add_child(player)
	camera = player.camera
	world.set_viewer(camera, player)
	for shop: Dictionary in SHOPS:
		_label = str(shop.why)
		var index := int(shop.get("box", -1))
		for entry: Dictionary in map.data.get("businesses", []):
			if index < 0 and str(entry.get("why", "")).begins_with(str(shop.why)): index = int(entry.box)
		_check(index >= 0, "the map names a corner shop there")
		if index < 0: continue
		var site: Dictionary = world.site(index)
		_check(bool(site.ok) and str(site.features.get("business", "")) != "", "its house is made as a shop: %s, with %s" % [str(site.features.get("business", "none")), str(site.features.get("shop_front", []))])
		if not bool(site.ok): continue
		var door: Vector3 = site.door_point
		var out: Vector3 = site.street_out
		var at_door := door + out * 0.7
		var on_street := door + out * 2.4
		for walk: Dictionary in shop.walks:
			var from: Vector3 = walk.from
			var there: Array = (walk.via as Array).duplicate()
			# The last lane corner: level with the street point, on the lane the walk arrives by.
			var before: Vector3 = there[there.size() - 1] if not there.is_empty() else from
			there.append(Vector3(on_street.x, 0.0, before.z))
			there.append(on_street)
			there.append(at_door)
			var length := 0.0
			var last := from
			for point: Vector3 in there:
				length += Vector2(point.x - last.x, point.z - last.z).length()
				last = point
			await _put(map.on_ground(from.x, from.z, 0.25))
			var reached := await _drive(there, false, 120.0)
			_check(reached, "walked from %s (%.0f, %.0f) to the door at (%.1f, %.1f): a route of %.0f m (straight line %.0f m)" % [str(walk.name), from.x, from.z, door.x, door.z, length, Vector2(from.x - door.x, from.z - door.z).length()])
			if not reached: continue
			_check(Vector2(player.global_position.x - door.x, player.global_position.z - door.z).length() < 1.2, "and stands within 1.2 m of the door")
			var back: Array = there.duplicate()
			back.reverse()
			back.remove_at(0)
			back.append(from)
			_check(await _drive(back, false, 120.0), "and walked back the same way")
	print("CORNER_SHOP_DONE passed=", passed, " failed=", failed)
	quit(1 if failed else 0)
