extends SceneTree
## What a business's house was made with: its shop front pieces and the facts that decide them.
##   godot --headless --path . --script res://tests/probe_business_site.gd -- --boxes=1728,1727
## Prints SITE lines and SITE_DONE.

const Blockout := preload("res://scripts/map1/map1_blockout.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var boxes: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--boxes="): boxes = arg.trim_prefix("--boxes=").split(",")
	var map: Node3D = Blockout.new()
	map.name = "Map1Blockout"
	map.with_player = false
	root.add_child(map)
	for i: int in 4: await process_frame
	for text: String in boxes:
		var site: Dictionary = map.world.site(int(text))
		if not bool(site.get("ok", false)):
			print("SITE %s not made" % text)
			continue
		var spec: Dictionary = site.get("spec", {})
		var front_upper: Array = []
		for entry: Dictionary in spec.get("windows", []):
			if str(entry.wall) == "front": front_upper.append("floor %d at %.2f w %.2f" % [int(entry.floor), float(entry.at), float(entry.width)])
		print("SITE %s %s floors=%s size=%s inset=%s open=%s porch=%s balcony=%s front windows=%s pieces=%s" % [text, str(site.features.get("business", "?")), str(site.get("floors", spec.get("floors", "?"))), str(spec.get("size", "?")), str(spec.get("inset", "?")), str(spec.get("open", "?")), str(site.features.get("porch", "?")), str(spec.get("balcony", {}).get("wall", "none")) if spec.get("balcony") is Dictionary else "none", str(front_upper), str(site.features.get("shop_front", []))])
		print("SITE %s open=%s upper=%s road_gap=%s door_clear=%s" % [text, str(site.get("open")), str(spec.get("upper")), str(site.get("road_gap")), str(site.get("door_clear"))])
	# (--tenants=trade: every street-level tenant of that trade in a tall or shut building.)
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--tenants="): continue
		var want := arg.trim_prefix("--tenants=").replace("_", " ")
		var group: Node = map.get_node_or_null("TallShopfronts")
		var count := 0
		if group != null:
			for face: Node in group.get_children():
				if str(face.trade) != want: continue
				count += 1
				var lamps := face.find_children("CaseLamp", "OmniLight3D", true, false).size()
				print("TENANT %s box %d at (%.1f, %.1f) floors %d, frontage %.1f m, tall blade %s, case lamps %d" % [want, int(face.building), float(face.position.x), float(face.position.z), int(face.floors), float(face.frontage), str(bool(face.hemmed_in) and float(face.box_height) >= 4.7), lamps])
		print("TENANT_COUNT %s %d" % [want, count])
	# (--glass: every business of a trade that sells goods behind glass: the plan its house drew,
	# and whether its glass front comes from the plan's own shop room or from the goods-trade rule.)
	if "--glass" in OS.get_cmdline_user_args():
		for entry: Dictionary in map.data.get("businesses", []):
			if not str(entry.what) in ["convenience store", "grocer", "rice and liquor shop"]: continue
			var site: Dictionary = map.world.site(int(entry.box))
			if not bool(site.get("ok", false)):
				print("GLASS %s box %d at (%.0f, %.0f): no house made of it (%s)" % [str(entry.what), int(entry.box), float(entry.x), float(entry.z), "a street-level tenant front" if map.get_node_or_null("TallShopfronts/Tenant_%d" % int(entry.box)) != null else str(site.get("reason", "?"))])
				continue
			var panes := 0
			for window: Dictionary in (site.spec as Dictionary).get("windows", []):
				if int(window.floor) == 0 and str(window.wall) == "front" and float(window.sill) == 0.0 and float(window.width) >= 1.0: panes += 1
			# (Only the plan with the stair across the back has a shop room of its own.)
			var shop_room: bool = str(site.get("plan", "")) == "back"
			print("GLASS %s box %d at (%.0f, %.0f): plan %s, %d floor-length panes, %s" % [str(entry.what), int(entry.box), float(entry.x), float(entry.z), str(site.get("plan", "?")), panes, "the plan's own shop room" if shop_room else ("from the goods-trade rule" if panes > 0 else "NO glass front")])
	# (--piece=name: every business whose front has that piece.)
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--piece="): continue
		var want := arg.trim_prefix("--piece=").replace("_", " ")      # (underscores for spaces)
		var found := 0
		for entry: Dictionary in map.data.get("businesses", []):
			var site: Dictionary = map.world.site(int(entry.box))
			if not bool(site.get("ok", false)): continue
			if want in (site.features.get("shop_front", []) as Array):
				found += 1
				print("SITE_WITH %s box %d %s at (%.1f, %.1f)" % [want, int(entry.box), str(entry.what), float(entry.x), float(entry.z)])
		print("SITE_WITH_COUNT %s %d" % [want, found])
	print("SITE_DONE")
	quit()
