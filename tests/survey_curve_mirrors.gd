extends SceneTree
## Lists the curve mirrors the map puts at blind lane corners, and the blind corners that got
## none, with why. Headless:
##   godot --headless --path . --script res://tests/survey_curve_mirrors.gd
## Prints MIRROR lines (pole foot, heads' aims, street, lane, T or crossroads, the building that
## hides the corner), SKIPPED lines, and MIRRORS_DONE.

const Blockout := preload("res://scripts/map1/map1_blockout.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var map: Node3D = Blockout.new()
	map.name = "Map1Blockout"
	map.with_player = false
	root.add_child(map)
	for i: int in 4: await process_frame
	var mirrors: Node3D = map.curve_mirrors
	var count := 0
	for site: Dictionary in mirrors.sites:
		var foot: Vector3 = site.at
		var aims: PackedStringArray = []
		for aim: Vector3 in site.heads: aims.append("%.0f deg" % rad_to_deg(atan2(aim.x, aim.z)))
		print("MIRROR at (%.2f, %.2f, %.2f) on %s side %+.0f at %.1f m, %s %s, heads %s, hidden by box %d" % [foot.x, foot.y, foot.z, str(site.street), float(site.far_side), float(site.s), str(site.why), str(site.lane), ", ".join(aims), int(site.blocker)])
		count += (site.heads as Array).size()
	for line: String in mirrors.skipped: print("SKIPPED ", line)
	print("MIRRORS_DONE poles=%d heads=%d skipped=%d" % [mirrors.sites.size(), count, mirrors.skipped.size()])
	quit()
