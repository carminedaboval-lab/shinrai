extends SceneTree
## Every dead end's wall on Map 1: how far past the lane's end it stands, and which house's door
## made it stand back, if any. Headless:
##   godot --headless --path . --script res://tests/survey_end_walls.gd
## Prints END_WALL lines and END_WALLS_DONE walls=<n> set_back=<n>.

const Blockout := preload("res://scripts/map1/map1_blockout.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var map: Node3D = Blockout.new()
	map.name = "Map1Blockout"
	map.with_player = false
	root.add_child(map)
	for i: int in 4: await process_frame
	var moved := 0
	var keys: Array = map.end_wall_backs.keys()
	keys.sort()
	for key: String in keys:
		var entry: Dictionary = map.end_wall_backs[key]
		var back := float(entry.back)
		if back > 0.0: moved += 1
		var door: Vector3 = entry.door
		print("END_WALL %s: %s%s" % [key, ("at the lane's end" if back <= 0.0 else "%.1f m past the end" % back), ("" if int(entry.house) < 0 else ", for the door of house %d at (%.2f, %.2f)" % [int(entry.house), door.x, door.z])])
	print("END_WALLS_DONE walls=%d set_back=%d" % [keys.size(), moved])
	quit()
