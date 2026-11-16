extends SceneTree
## Fixed-camera pictures of the Map 1 blockout with its world in it (real Japanese kit houses
## in place of the low open buildings near the viewer, and the robot recharge stations):
##   godot --path . --resolution 1600x900 --fixed-fps 60 --script res://tests/map1_world_capture.gd
##   ... -- --views=modern_street,front_door
## Writes reports/map1_world/look_<view>.jpg. No player, no mouse capture. Each view is a cut:
## the camera is put there, the world makes its houses behind black, and the picture is taken
## once it is shown again.
##
## Views: modern_street, long_street, timber_street, shop_street, front_door, genkan,
## tatami_room, balcony, rooftop, modern_house (the owner's target picture's angle),
## recharge_station, shut_next_to_open; and the businesses the map names, found from its own
## list at run time: shop_ramen, shop_izakaya, shop_konbini, shop_coffee (each from across its
## street at 1.7 m) and shop_row (two or three of them together, down their street).

const Blockout := preload("res://scripts/map1/map1_blockout.gd")
const World := preload("res://scripts/map1/map1_world.gd")
const Dress := preload("res://scripts/map1/map1_house_dress.gd")
const OUT := "reports/map1_world"
## The house street: it runs east along z = 447 to a turning circle at x = 155.
const STREET_Z := 447.0
const HOMES := Vector3(112.0, 0.0, 447.0)
const OLD_TOWN := Vector3(520.0, 0.0, -520.0)
const SHOPS := Vector3(700.0, 0.0, 200.0)

var map: Node3D
var world: Node3D
var camera: Camera3D
var only: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--views="): only = arg.trim_prefix("--views=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + OUT))
	# (--plain-blades: every tall-building shop front keeps its ordinary blade sign, for comparison.)
	if "--plain-blades" in OS.get_cmdline_user_args(): load("res://scripts/map1/map1_upper_shopfront.gd").plain_blades = true
	map = Blockout.new()
	map.name = "Map1Blockout"
	map.with_player = false
	root.add_child(map)
	world = map.world
	for label: Label3D in map.labels: label.visible = false
	# (--dusk: the sun and the sky turned down, to see what gives its own light. Pictures get _dusk.)
	if "--dusk" in OS.get_cmdline_user_args():
		for found: Node in map.find_children("*", "DirectionalLight3D", true, false): (found as DirectionalLight3D).light_energy *= 0.06
		for found: Node in map.find_children("*", "WorldEnvironment", true, false):
			var env: Environment = (found as WorldEnvironment).environment
			if env != null:
				env.background_energy_multiplier *= 0.10
				env.ambient_light_energy *= 0.25
	# (--no-mirrors: the same views without the curve mirrors, for a before picture.)
	if "--no-mirrors" in OS.get_cmdline_user_args() and map.curve_mirrors != null: map.curve_mirrors.visible = false
	camera = Camera3D.new()
	camera.far = 20000.0
	root.add_child(camera)
	camera.make_current()
	world.set_viewer(camera, null)
	for i: int in 12: await process_frame

	# A street of newer houses, towards the turning circle.
	await _shot("modern_street", map.on_ground(99.0, STREET_Z + 0.5, 1.7), map.on_ground(155.0, 448.0, 2.5), 73.0)
	# The lowered kerb at the gate of the house at x 133, from the road at player height.
	await _shot("trial_entrance", map.on_ground(123.2, 449.0, 1.7), map.on_ground(129.2, 451.7, 0.5), 70.0)
	# A long straight street, looking down it: houses all the way, none grey.
	await _shot("long_street", map.on_ground(34.0, 411.0, 1.7), map.on_ground(190.0, 411.0, 3.0), 73.0)
	# The same streets from a rooftop.
	await _shot("rooftop", map.on_ground(96.0, 470.0, 15.0), map.on_ground(128.0, STREET_Z - 6.0, 2.0), 70.0)

	# An old-town street of timber houses, and a street with shop-houses.
	for pair: Array in [["timber_street", "timber", OLD_TOWN], ["shop_street", "shop", SHOPS]]:
		var index := _find(pair[2], func(site: Dictionary) -> bool: return str(site.kind) == str(pair[1]) and bool(site.on_road) and int(site.floors) == 2)
		if index < 0: continue
		var site: Dictionary = world.site(index)
		var along: Vector3 = site.street_along
		var street: Vector3 = site.street_point
		await _shot(pair[0], _eye(street - along * 16.0, 1.7), _eye(street + along * 14.0, 2.6), 73.0)
		# And that house from across its street.
		await _shot(str(pair[1]) + "_house", _eye(street + (site.street_out as Vector3) * 5.5 - along * 5.0, 1.7), _eye((site.frame as Transform3D) * Vector3(float(site.size.x) * 0.5, 0.0, 0.0), 3.0), 70.0)

	# The restaurants and corner shops, found from the map's own list of businesses: a ramen
	# shop, an izakaya, a convenience store and a coffee shop, each from across its street.
	for pair: Array in [["shop_ramen", "ramen shop"], ["shop_izakaya", "izakaya"], ["shop_konbini", "convenience store"], ["shop_coffee", "coffee shop"]]:
		var index := _business(str(pair[1]))
		if index < 0:
			print("MAP1_WORLD_CAPTURE no %s among the map's businesses that a house can be made of" % str(pair[1]))
			continue
		var site: Dictionary = world.site(index)
		var front := _front_of(site)
		var out: Vector3 = site.street_out
		var along: Vector3 = site.street_along
		# As far back as the street is wide (a neighbour opposite, or eight metres), a step to one side.
		var back := clampf(float(site.door_clear) - 0.8, 4.0, 8.0)
		while back > 3.0 and world.solid_at(front.x + out.x * back + along.x * 1.5, front.z + out.z * back + along.z * 1.5): back -= 0.5
		print("MAP1_WORLD_CAPTURE %s is box %d at %.0f, %.0f: %s" % [str(pair[0]), index, front.x, front.z, ", ".join(PackedStringArray(site.features.get("shop_front", [])))])
		await _shot(str(pair[0]), _eye(front + out * back + along * 1.5, 1.7), _eye(front, 2.3), 66.0)
	# Two or three businesses together, down their street.
	var row := _business_row()
	if row.size() >= 2:
		var site: Dictionary = world.site(row[0])
		var street: Vector3 = site.street_point
		var along: Vector3 = site.street_along
		var low := INF
		var high := -INF
		var first_front := street
		var last_front := street
		var trades: Array[String] = []
		for index: int in row:
			var front := _front_of(world.site(index))
			var t := (front - street).dot(along)
			if t < low:
				low = t
				first_front = front
			if t > high:
				high = t
				last_front = front
			trades.append("%s (box %d)" % [str(world.site(index).business.what), index])
		# From the middle of the street a few steps short of the nearest, looking at the farthest.
		var from := street + along * (low - 8.0)
		var to := last_front
		if world.solid_at(from.x, from.z):
			from = street + along * (high + 8.0)
			to = first_front
		print("MAP1_WORLD_CAPTURE shop_row shows %s" % ", ".join(PackedStringArray(trades)))
		await _shot("shop_row", _eye(from, 1.7), _eye(to, 2.4), 70.0)
	else:
		print("MAP1_WORLD_CAPTURE no two businesses stand on one street within 40 m of each other")
	# The first wide road (the shop row): down the road, along the shop pavement, and the crossing.
	# A corner of the trial homes street into a side street: from the road, and from above the footway.
	await _shot("corner_kerb", _eye(Vector3(75.5, 0.0, 448.6), 1.7), _eye(Vector3(79.6, 0.0, 451.4), 0.1), 60.0)
	await _shot("corner_island", _eye(Vector3(86.0, 0.0, 446.6), 1.7), _eye(Vector3(86.0, 0.0, 451.6), 0.1), 70.0)
	await _shot("wide_junction", _eye(Vector3(-276.0, 0.0, -449.0), 1.7), _eye(Vector3(-262.0, 0.0, -441.5), 0.2), 70.0)
	await _shot("wide_plaza", _eye(Vector3(-330.0, 0.0, -452.0), 1.7), _eye(Vector3(-352.0, 0.0, -436.0), 1.2), 75.0)
	await _shot("plaza_pit", _eye(Vector3(-347.0, 0.0, -441.5), 1.7), _eye(Vector3(-352.5, 0.0, -436.5), 0.1), 70.0)
	# The shop row's west end, where it meets the Outer ring: each corner from the road, and the
	# south one from its own footway, past the signal post.
	await _shot("ring_corner_south", _eye(Vector3(-455.0, 0.0, -449.5), 1.7), _eye(Vector3(-466.0, 0.0, -457.0), 0.1), 70.0)
	await _shot("ring_corner_north", _eye(Vector3(-455.0, 0.0, -446.5), 1.7), _eye(Vector3(-466.0, 0.0, -439.0), 0.1), 70.0)
	await _shot("ring_corner_walk", _eye(Vector3(-450.0, 0.0, -456.0), 1.7), _eye(Vector3(-468.0, 0.0, -461.0), 1.0), 70.0)
	# The shop row's east end, where the tram track comes in across the north footway and a rail
	# line crosses the south one: each end from the road, and the north footway walked east.
	await _shot("rail_end_north", _eye(Vector3(-240.0, 0.0, -449.0), 1.7), _eye(Vector3(-229.0, 0.0, -441.0), 0.1), 70.0)
	await _shot("rail_end_south", _eye(Vector3(-240.0, 0.0, -447.0), 1.7), _eye(Vector3(-229.0, 0.0, -455.5), 0.1), 70.0)
	await _shot("rail_end_walk", _eye(Vector3(-246.0, 0.0, -440.0), 1.7), _eye(Vector3(-222.0, 0.0, -440.0), 0.8), 70.0)
	# Curve mirrors at blind lane corners: coming up the lane at x 168 to the koban lane, coming
	# down the lane at x 175 to tram street south (two heads), and along the koban lane's north
	# footway past one.
	await _shot("mirror_koban_lane", _eye(Vector3(168.4, 0.0, 426.0), 1.7), _eye(Vector3(172.3, 0.0, 409.9), 2.4), 60.0)
	await _shot("mirror_tram_south", _eye(Vector3(175.1, 0.0, 472.0), 1.7), _eye(Vector3(175.1, 0.0, 496.4), 2.4), 60.0)
	await _shot("mirror_footway", _eye(Vector3(162.0, 0.0, 409.6), 1.6), _eye(Vector3(178.0, 0.0, 409.6), 1.6), 65.0)
	# The tram fork's approach (stage A): along lane z 497 to the two lanes that cross it side by
	# side; up through both mouths from the south; the dead end of lane x 219 by house 1662's door;
	# and the tram street's new end, towards the fork.
	await _shot("fork_lane_east", _eye(Vector3(205.0, 0.0, 496.6), 1.7), _eye(Vector3(232.0, 0.0, 496.8), 0.6), 70.0)
	await _shot("fork_mouths_north", _eye(Vector3(221.5, 0.0, 506.5), 1.7), _eye(Vector3(221.5, 0.0, 488.0), 0.5), 75.0)
	await _shot("fork_dead_end", _eye(Vector3(219.0, 0.0, 495.5), 1.7), _eye(Vector3(218.2, 0.0, 487.5), 0.9), 70.0)
	await _shot("fork_tram_end", _eye(Vector3(170.0, 0.0, 493.5), 1.7), _eye(Vector3(196.0, 0.0, 491.0), 0.4), 70.0)
	# The tram fork's south kerb (stage B): from the street looking east along it, from the lane
	# looking back west, and across it from the road towards house 1661's door.
	await _shot("fork_south_east", _eye(Vector3(180.0, 0.0, 494.6), 1.7), _eye(Vector3(198.0, 0.0, 498.6), 0.3), 70.0)
	await _shot("fork_south_west", _eye(Vector3(205.0, 0.0, 496.8), 1.7), _eye(Vector3(187.0, 0.0, 496.2), 0.3), 70.0)
	await _shot("fork_south_1661", _eye(Vector3(190.0, 0.0, 492.5), 1.7), _eye(Vector3(187.5, 0.0, 498.5), 0.6), 75.0)
	# The island at the fork: its tip from the road west of it, from above, and its stub end.
	await _shot("fork_island_tip", _eye(Vector3(190.5, 0.0, 495.0), 1.7), _eye(Vector3(197.5, 0.0, 493.2), 0.2), 60.0)
	await _shot("fork_island_above", _eye(Vector3(194.0, 0.0, 496.5), 6.0), _eye(Vector3(198.0, 0.0, 492.8), 0.0), 60.0)
	# The inside of the bend, by the curry shop: along the north pavement, from above, and from the diagonal.
	await _shot("fork_inner_walk", _eye(Vector3(182.5, 0.0, 483.0), 1.7), _eye(Vector3(190.0, 0.0, 482.8), 0.2), 65.0)
	await _shot("fork_inner_above", _eye(Vector3(188.5, 0.0, 487.5), 6.5), _eye(Vector3(189.2, 0.0, 483.0), 0.0), 60.0)
	await _shot("fork_inner_back", _eye(Vector3(194.5, 0.0, 484.5), 1.7), _eye(Vector3(189.0, 0.0, 483.2), 0.2), 65.0)
	# The diagonal past the fork, south-east kerb: along it from the island, back from its far end, and from above the join.
	await _shot("diagonal_south_along", _eye(Vector3(199.5, 0.0, 492.3), 1.7), _eye(Vector3(212.0, 0.0, 478.5), 0.3), 70.0)
	await _shot("diagonal_south_back", _eye(Vector3(220.5, 0.0, 471.5), 1.7), _eye(Vector3(206.0, 0.0, 484.5), 0.3), 70.0)
	await _shot("diagonal_south_join", _eye(Vector3(197.0, 0.0, 487.0), 7.0), _eye(Vector3(201.0, 0.0, 489.5), 0.0), 60.0)
	# The compound mouth's tip, where the diagonal meets lane x 224.
	await _shot("mouth_tip_above", _eye(Vector3(217.5, 0.0, 474.0), 6.0), _eye(Vector3(221.3, 0.0, 469.3), 0.0), 60.0)
	await _shot("mouth_tip_eye", _eye(Vector3(216.0, 0.0, 466.5), 1.7), _eye(Vector3(221.4, 0.0, 470.0), 0.3), 65.0)
	# Lane x 224 past house 4474: along the narrow east side, and the lowered kerb at its front door.
	await _shot("mouth_x224_along", _eye(Vector3(224.2, 0.0, 470.5), 1.7), _eye(Vector3(224.6, 0.0, 482.0), 0.6), 70.0)
	await _shot("mouth_x224_door", _eye(Vector3(222.6, 0.0, 476.6), 1.7), _eye(Vector3(227.2, 0.0, 474.2), 0.1), 65.0)
	# Lane z 466's new western length, and the whole mouth from above.
	await _shot("mouth_z466_along", _eye(Vector3(228.0, 0.0, 466.3), 1.7), _eye(Vector3(242.0, 0.0, 466.6), 0.5), 70.0)
	await _shot("mouth_z466_west", _eye(Vector3(238.0, 0.0, 467.5), 1.7), _eye(Vector3(224.0, 0.0, 466.0), 0.4), 70.0)
	await _shot("mouth_wide", _eye(Vector3(214.0, 0.0, 480.0), 30.0), _eye(Vector3(228.0, 0.0, 468.0), 0.0), 60.0)
	# A frontage with a walled, railed plot on it, to judge the wall and railing work against
	# docs/art_targets/street_target_01.webp.
	await _shot("frontage_wall", _eye(Vector3(140.0, 0.0, 487.0), 1.7), _eye(Vector3(134.0, 0.0, 481.0), 1.1), 60.0)
	# Standing at a gate, which is how close a player gets to a frontage: the test of the wall,
	# railing, hedge, path and door together against docs/art_targets/street_target_01.webp.
	await _shot("frontage_gate", _eye(Vector3(132.0, 0.0, 485.4), 1.65), _eye(Vector3(133.6, 0.0, 481.2), 1.2), 58.0)
	# A gate with its leaves hung and standing open, which the frontage_gate plot's yard is too
	# shallow for. Plot 156 on the south row: a railed wall, so a barred gate, with two leaves.
	# (tests/probe_find_gates.gd lists the plots that have one.)
	await _shot("gate_leaf", _eye(Vector3(-408.2, 0.0, -690.2), 1.65), _eye(Vector3(-408.2, 0.0, -683.8), 1.0), 52.0)
	await _shot("mouth_tip_wide",_eye(Vector3(212.0, 0.0, 478.0), 22.0), _eye(Vector3(221.0, 0.0, 470.0), 0.0), 60.0)
	await _shot("fork_island_stub",_eye(Vector3(201.5, 0.0, 488.5), 1.7), _eye(Vector3(197.5, 0.0, 492.6), 0.2), 65.0)
	# Lane z 405's dead end, from the doorstep of house 4454, whose door's line the wall's end stood on.
	await _shot("dead_end_z405_door", _eye(Vector3(310.45, 0.0, 399.7), 1.6), _eye(Vector3(310.45, 0.0, 405.0), 0.7), 75.0)
	# --approach=box,box: each of those businesses as someone walking along its pavement sees it,
	# 14 m before its front and 1.8 m out from it, looking along the frontage (look_approach_<box>).
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--approach="): continue
		for text: String in arg.trim_prefix("--approach=").split(","):
			var index := int(text)
			var site: Dictionary = world.site(index)
			var front := Vector3.ZERO
			var out := Vector3.ZERO
			var along := Vector3.ZERO
			# (A street-level tenant of a tall or shut building has no house plan: its own shop front
			# says where it stands and which way it faces.)
			var tenant: Node3D = map.get_node_or_null("TallShopfronts/Tenant_%d" % index)
			if tenant != null:
				front = tenant.global_position
				out = tenant.global_transform.basis.z.normalized()
				along = Vector3(out.z, 0.0, -out.x)
			elif bool(site.ok):
				front = _front_of(site)
				out = site.street_out
				along = site.street_along
			else: continue
			for way: float in [-1.0, 1.0]:
				var view := "approach_%d_%s" % [index, "a" if way < 0.0 else "b"]
				only.append(view)
				# (Where a walker would be: the nearest place on a pavement, built or painted, from 14 m
				# along and nearer; failing that the edge of a road, on a shared street; failing that
				# the approach is left out and said so. Never open ground or a plot.)
				var best := Vector3.ZERO
				var best_kind := 0
				var best_note := ""
				var back := 14.0
				while back >= 5.0 and best_kind < 2:
					for wide: float in [1.8, 1.3, 0.9, 2.5, 3.5, 5.0, 6.5, 8.0]:
						var stand := front + out * wide + along * back * way
						if world.solid_at(stand.x, stand.z): continue
						var kind := _walked(stand)
						if kind > best_kind:
							best_kind = kind
							best = stand
							best_note = "%.1f m along, %.1f m out, on %s" % [back, wide, "a pavement" if kind == 2 else "the road's edge"]
						if best_kind == 2: break
					back -= 0.5
				if best_kind == 0:
					print("MAP1_WORLD_CAPTURE %s skipped: no pavement or road within 14 m along that approach" % view)
					continue
				print("MAP1_WORLD_CAPTURE %s from %s" % [view, best_note])
				await _shot(view, _eye(best, 1.6), _eye(front + out * 0.6, 1.4), 65.0)
			# And its front, from across the street (a wide view, not a walker's approach).
			only.append("approach_%d_front" % index)
			await _shot("approach_%d_front" % index, _eye(front + out * 7.0, 1.6), _eye(front, 2.6), 60.0)
	await _shot("link_lane", _eye(Vector3(91.6, 0.0, 449.5), 1.7), _eye(Vector3(90.6, 0.0, 425.0), 0.6), 70.0)
	await _shot("link_lane_north", _eye(Vector3(89.5, 0.0, 411.6), 1.7), _eye(Vector3(89.6, 0.0, 424.0), 0.3), 75.0)
	# The homes block's two clean crossroads.
	await _shot("cross_168", _eye(Vector3(159.0, 0.0, 413.6), 1.7), _eye(Vector3(168.4, 0.0, 412.4), 0.2), 75.0)
	await _shot("cross_82", _eye(Vector3(72.5, 0.0, 448.9), 1.7), _eye(Vector3(81.6, 0.0, 447.6), 0.2), 75.0)
	await _shot("arm_north", _eye(Vector3(89.4, 0.0, 414.6), 1.7), _eye(Vector3(89.8, 0.0, 404.0), 0.3), 75.0)
	await _shot("arm_south", _eye(Vector3(91.8, 0.0, 446.8), 1.7), _eye(Vector3(90.6, 0.0, 457.5), 0.3), 75.0)
	await _shot("island_south", _eye(Vector3(86.4, 0.0, 411.4), 1.7), _eye(Vector3(87.4, 0.0, 420.0), 0.2), 70.0)
	await _shot("island_north", _eye(Vector3(88.4, 0.0, 414.6), 1.7), _eye(Vector3(87.6, 0.0, 405.0), 0.2), 70.0)
	await _shot("island_trench", _eye(Vector3(86.2, 0.0, 449.8), 1.7), _eye(Vector3(86.2, 0.0, 457.0), 0.0), 70.0)
	await _shot("dead_end_91c", _eye(Vector3(89.6, 0.0, 449.6), 1.7), _eye(Vector3(89.0, 0.0, 458.6), 0.6), 70.0)
	await _shot("dead_end_168b", _eye(Vector3(168.0, 0.0, 416.0), 1.7), _eye(Vector3(168.4, 0.0, 427.4), 0.6), 70.0)
	await _shot("turning_circle", _eye(Vector3(138.0, 0.0, 447.0), 1.7), _eye(Vector3(156.0, 0.0, 448.2), 0.0), 70.0)
	await _shot("turning_flare", _eye(Vector3(150.5, 0.0, 445.2), 1.7), _eye(Vector3(146.0, 0.0, 452.2), 0.0), 70.0)
	# The homes block's south: Tram street south with its rail bed, and the lanes that meet it.
	await _shot("tram_t_82", _eye(Vector3(73.0, 0.0, 492.5), 1.7), _eye(Vector3(81.6, 0.0, 480.0), 0.3), 75.0)
	await _shot("tram_street", _eye(Vector3(60.0, 0.0, 485.5), 1.7), _eye(Vector3(110.0, 0.0, 490.0), 0.5), 70.0)
	await _shot("lane_82b_narrow", _eye(Vector3(82.6, 0.0, 462.0), 1.7), _eye(Vector3(83.5, 0.0, 480.0), 0.3), 70.0)
	await _shot("lane_cross_292", _eye(Vector3(283.0, 0.0, 403.6), 1.7), _eye(Vector3(292.0, 0.0, 405.4), 0.2), 75.0)
	await _shot("lane_t_300", _eye(Vector3(296.0, 0.0, 445.5), 1.7), _eye(Vector3(299.8, 0.0, 434.0), 0.2), 75.0)
	await _shot("grid_378", _eye(Vector3(368.0, 0.0, 494.0), 1.7), _eye(Vector3(377.7, 0.0, 497.0), 0.2), 75.0)
	await _shot("grid_370", _eye(Vector3(370.6, 0.0, 450.0), 1.7), _eye(Vector3(370.0, 0.0, 436.0), 0.2), 75.0)
	await _shot("north_378", _eye(Vector3(76.0, 0.0, 376.0), 1.7), _eye(Vector3(84.7, 0.0, 378.6), 0.2), 75.0)
	await _shot("koban_189", _eye(Vector3(180.0, 0.0, 411.8), 1.7), _eye(Vector3(188.7, 0.0, 413.4), 0.2), 75.0)
	await _shot("wide_road", _eye(Vector3(-300.0, 0.0, -451.0), 1.7), _eye(Vector3(-360.0, 0.0, -456.0), 1.6), 70.0)
	await _shot("wide_pavement", _eye(Vector3(-352.0, 0.0, -456.2), 1.7), _eye(Vector3(-375.0, 0.0, -458.2), 1.0), 70.0)
	await _shot("wide_crossing", _eye(Vector3(-285.0, 0.0, -445.0), 1.7), _eye(Vector3(-268.0, 0.0, -450.0), 1.2), 70.0)

	# A newer house at the angle of the owner's target picture: its front and one side.
	var plain := _find(HOMES, func(site: Dictionary) -> bool: return str(site.kind) == "house" and int(site.floors) == 2 and str(site.features.roof) == "gable" and str(site.features.ridge) == "x" and str(site.features.setback) == "none" and not (site.spec as Dictionary).has("recess"))
	if plain >= 0:
		var site: Dictionary = world.site(plain)
		var frame: Transform3D = site.frame
		await _shot("modern_house", _eye(frame * Vector3(float(site.size.x) + 5.0, 0.0, -9.0), 1.7), _eye(frame * Vector3(float(site.size.x) * 0.5, 0.0, float(site.size.y) * 0.3), 3.2), 60.0)

	# A front door with its porch, from the pavement; then the genkan from the hall.
	var porch := _find(HOMES, func(site: Dictionary) -> bool: return str(site.kind) == "house" and int(site.floors) == 2 and (site.spec as Dictionary).has("recess") and bool(site.features.genkan) and str(site.plan) != "back" and float(site.door_drop) == 0.0)
	if porch >= 0:
		var site: Dictionary = world.site(porch)
		var frame: Transform3D = site.frame
		var door_x := float(site.spec.doors[0].at)
		var door_z := float(site.door_z)
		await _shot("front_door", _eye(frame * Vector3(door_x + 1.3, 0.0, -3.6), 1.6), frame * Vector3(door_x, 1.2, door_z), 60.0)
		await _shot("genkan", frame * Vector3(door_x, 1.75, door_z + 4.3), frame * Vector3(door_x, 0.5, door_z + 0.6), 78.0, true)

	# A tatami room: found by its mats.
	var washitsu := _find(HOMES, func(site: Dictionary) -> bool: return bool(site.features.washitsu) and not _tatami(site).is_empty())
	if washitsu >= 0:
		var site: Dictionary = world.site(washitsu)
		var mats: Array = _tatami(site)
		var middle: Vector3 = mats[0]
		var size: Vector3 = mats[1]
		var frame: Transform3D = site.frame
		await _shot("tatami_room", frame * (middle + Vector3(size.x * 0.5 - 0.35, 1.5, size.z * 0.5 - 0.35)), frame * (middle + Vector3(-size.x * 0.3, 0.5, -size.z * 0.3)), 85.0, true)

	# A balcony over the street.
	var balcony := _find(HOMES, func(site: Dictionary) -> bool: return str(site.features.balcony).begins_with("front") and bool(site.on_road))
	if balcony >= 0:
		var site: Dictionary = world.site(balcony)
		var frame: Transform3D = site.frame
		await _shot("balcony", _eye(frame * Vector3(float(site.size.x) * 0.5 + 4.0, 0.0, -6.5), 1.7), frame * Vector3(float(site.size.x) * 0.5, 3.4, 0.0), 62.0)

	# A recharge station at a tram stop, with real houses behind.
	var station: Node3D = null
	for candidate: Node3D in world.stations:
		if "tram stop S6" in str(candidate.description.get("why", "")): station = candidate
	if station == null and not world.stations.is_empty(): station = world.stations[0]
	if station != null:
		var front: Vector3 = station.global_basis.z
		var side: Vector3 = station.global_basis.x
		await _shot("recharge_station", station.global_position + front * 9.0 + side * 4.0 + Vector3.UP * 1.7, station.global_position + Vector3.UP * 1.5, 65.0)

	# A shut building next to an open one.
	var shut := _nearest_shut(map.on_ground(110.0, STREET_Z))
	if shut >= 0:
		var box: Array = map.data.boxes[shut]
		var at := Vector3(float(box[0]), 0.0, float(box[2]))
		var stand: Vector3 = map.on_ground(at.x - 9.0, STREET_Z + 0.5, 1.7)
		if absf(at.z - STREET_Z) < 4.0: stand = map.on_ground(at.x - 12.0, at.z + 9.0, 1.7)
		await _shot("shut_next_to_open", stand, Vector3(at.x, float(box[1]) + float(box[4]) * 0.5, at.z), 70.0)

	print("MAP1_WORLD_CAPTURE_DONE outsides=%d full=%d stations=%d draw_calls=%d static_mem_mb=%d" % [world.count(World.Level.LOOK), world.count(World.Level.FULL), world.stations.size(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)])
	quit(0)


## A point on the plan, `lift` above the ground there.
## What a walker stands on at a point: 2 a pavement (a built street's footway, or the ground
## picture's pavement colour on a street not built yet), 1 a road, 0 anything else.
func _walked(point: Vector3) -> int:
	for street: Node3D in map.street_edges:
		var out := float(street.out_of(point))
		if out < float(street.half) + 0.15 or out > float(street.half) + float(street.footway_wide): continue
		var s := float(street.along_of(point))
		if not bool(street.beside(point, s)): continue
		for run: Vector2 in street.runs:
			if s >= run.x and s <= run.y: return 2
	var image: Image = map.ground_image
	if image != null:
		var frame: Rect2 = map.frame
		var pixel := image.get_pixel(clampi(int(point.x - frame.position.x), 0, image.get_width() - 1), clampi(int(point.z - frame.position.y), 0, image.get_height() - 1))
		if pixel.is_equal_approx(Color8(148, 146, 140)): return 2
	return 1 if world.road_at(point.x, point.z) else 0


func _eye(at: Vector3, lift: float) -> Vector3:
	return map.on_ground(at.x, at.z, lift)


func _shot(view: String, eye: Vector3, target: Vector3, fov: float, indoors: bool = false) -> void:
	if not only.is_empty() and not only.has(view): return
	camera.global_position = eye
	camera.look_at(target)
	camera.fov = fov
	camera.near = 0.05 if indoors else 0.1
	world.cut()
	# The world makes the houses behind black, over some frames; then the insides of the
	# street's houses follow, and the far ring.
	for i: int in 4: await process_frame
	var waited := 0
	while (world.covered or world.fade > 0.0) and waited < 900:
		await process_frame
		waited += 1
	for i: int in 150: await process_frame
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://%s/look_%s.jpg" % [OUT, view])
	image.save_jpg(path, 0.9)
	print("MAP1_WORLD_CAPTURE %s  outsides=%d full=%d black_frames=%d" % [path, world.count(World.Level.LOOK), world.count(World.Level.FULL), waited])


## The makeable house nearest a point that the test accepts, or -1.
func _find(near: Vector3, accept: Callable) -> int:
	var best := -1
	var gap := INF
	for index: int in world.candidates:
		var here := Vector2(float(map.data.boxes[index][0]) - near.x, float(map.data.boxes[index][2]) - near.z).length()
		if here >= gap or here > 400.0: continue
		var site: Dictionary = world.site(index)
		if not bool(site.ok) or not bool(accept.call(site)): continue
		gap = here
		best = index
	return best


## The middle of a house's front wall, on the plan.
func _front_of(site: Dictionary) -> Vector3:
	return (site.frame as Transform3D) * Vector3(float(site.size.x) * 0.5, 0.0, 0.0)


## The boxes of the map's businesses that a house can be made of ([box index, the trade]).
func _businesses() -> Array:
	var found: Array = []
	for entry: Dictionary in map.data.get("businesses", []):
		var index := int(entry.box)
		if not (world.candidates as PackedInt32Array).has(index): continue
		var site: Dictionary = world.site(index)
		if bool(site.ok) and site.has("business"): found.append([index, str(entry.what)])
	return found


## The shop of one trade that shows the most: on a road, with room to stand back, with the
## most pieces at its front. -1 when the map has none a house can be made of.
func _business(what: String) -> int:
	var best := -1
	var most := -1.0
	for entry: Array in _businesses():
		if str(entry[1]) != what: continue
		var site: Dictionary = world.site(int(entry[0]))
		var score := float((site.features.get("shop_front", []) as Array).size()) + (2.0 if bool(site.on_road) else 0.0) + minf(float(site.door_clear), 8.0) * 0.25 + (1.0 if int(site.floors) == 2 else 0.0)
		if score > most:
			most = score
			best = int(entry[0])
	return best


## The businesses that stand closest together along one street: up to three box indexes, the
## first the one whose street it is. Fewer than two when none are within 40 m of another.
func _business_row() -> Array[int]:
	var all := _businesses()
	var best: Array[int] = []
	var tightest := INF
	for entry: Array in all:
		var site: Dictionary = world.site(int(entry[0]))
		if not bool(site.on_road): continue
		var street: Vector3 = site.street_point
		var near: Array[Vector2] = []
		for other: Array in all:
			if int(other[0]) == int(entry[0]): continue
			var offset := _front_of(world.site(int(other[0]))) - street
			if absf(offset.dot(site.street_out)) <= 12.0 and absf(offset.dot(site.street_along)) <= 40.0: near.append(Vector2(absf(offset.dot(site.street_along)), int(other[0])))
		near.sort()
		var members: Array[int] = [int(entry[0])]
		for pick: Vector2 in near.slice(0, 2): members.append(int(pick.y))
		var spread := near[mini(near.size(), 2) - 1].x if not near.is_empty() else INF
		if members.size() > best.size() or (members.size() == best.size() and spread < tightest):
			best = members
			tightest = spread
	return best


## The tatami of a house's tatami room: [middle, size] in the house's own metres, or [].
func _tatami(site: Dictionary) -> Array:
	for block: Array in site.spec.blocks:
		if (block[2] as Color).is_equal_approx(Dress.TATAMI) and (block[1] as Vector3).y < 0.05: return [block[0], block[1]]
	return []


func _nearest_shut(point: Vector3) -> int:
	var kinds: Array = map.data.kinds
	var best := -1
	var gap := INF
	for index: int in (map.data.boxes as Array).size():
		var box: Array = map.data.boxes[index]
		var kind: String = kinds[int(box[7])]
		if not (kind.ends_with("-a") or kind.ends_with("-b")): continue
		var here := Vector2(float(box[0]) - point.x, float(box[2]) - point.z).length()
		if here < gap:
			gap = here
			best = index
	return best
