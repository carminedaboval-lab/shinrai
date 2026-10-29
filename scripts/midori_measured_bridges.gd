extends RefCounted

const Walks = preload("res://scripts/midori_bridge_walks.gd")
const Landings = preload("res://scripts/midori_bridge_landings.gd")

func build(park, parent: Node3D, bundle: Resource, display_script: Script) -> Array[Node]:
	var full: Dictionary = bundle.get_meta("full_scenes")
	var distant: Dictionary = bundle.get_meta("distant_scenes")
	var support_art: Dictionary = bundle.get_meta("support_scenes")
	var support_plan: Dictionary = bundle.get_meta("support_plan")
	park._bridge_walk_surfaces.clear()
	park._bridge_join_walks = Landings.collect_existing_walks(park)
	var artwork := Node3D.new()
	artwork.name = "ArtworkLakeBridges"
	parent.add_child(artwork)
	var displays: Array[Node] = []
	for crossing: Dictionary in [
		{"id":"Main","route":park.FUTURE_BRIDGE_WEST,"width":6.0},
		{"id":"North","route":park.FUTURE_BRIDGE_NORTH_EAST,"width":5.6},
		{"id":"South","route":park.FUTURE_BRIDGE_SOUTH,"width":5.6},
	]:
		var route: Array[Vector2] = crossing.route
		var a := route[0]
		var b := route[-1]
		var centre := (a+b)*.5
		var yaw := -rad_to_deg(atan2((b-a).y,(b-a).x))
		var width: float = crossing.width
		var bridge: Node3D = park._instance_park_asset(artwork,full[crossing.id],"Bridge_"+crossing.id,Vector3(centre.x,0,centre.y),yaw,Vector3.ONE)
		var world_a: Vector2 = a*park.LAYOUT_SCALE
		var world_b: Vector2 = b*park.LAYOUT_SCALE
		await Walks.align_front_tread(bridge,world_a,world_b,width-.6,.18,park)
		var supports: Dictionary = support_plan.bridge_sets[crossing.id.to_lower()]
		var reference_y: float = supports.bridge_world_y_offset_m
		if absf(bridge.global_position.y-reference_y)>.0002:
			push_error("Measured bridge artwork differs from its bearing reference")
			park.get_tree().quit(1)
			return displays
		bridge.global_position.y = reference_y
		var deck: Dictionary = await Walks.install_deck(bridge,artwork,crossing.id,world_a,world_b,width-.6,park)
		park._bridge_walk_surfaces.append({"kind":"deck","spec":deck})
		park._build_bridge_landings(artwork,crossing.id,world_a,world_b,width,deck)
		var count := 0
		for category: String in ["piers","abutments","wingwalls"]:
			for placement: Dictionary in supports[category]:
				var module: Node3D = support_art[placement.file].instantiate()
				artwork.add_child(module)
				var relative := Vector3(float(placement.position_m[0]),0,float(placement.position_m[2]))
				var origin := bridge.global_position+bridge.global_basis*relative
				# Manifest bearing Y already includes the calibrated bridge offset.
				origin.y = float(placement.position_m[1])
				module.global_transform = Transform3D(Basis(Vector3.UP,bridge.global_rotation.y+deg_to_rad(float(placement.rotation_y_deg))),origin)
				module.set_meta("midori_bridge_support",placement.file)
				count += 1
		var far: Node3D = park._instance_park_asset(artwork,distant[crossing.id],"BridgeDistant_"+crossing.id,Vector3(centre.x,0,centre.y),yaw,Vector3.ONE)
		far.global_transform = bridge.global_transform
		var display := Node.new()
		display.name = "BridgeDisplay_"+crossing.id
		display.set_script(display_script)
		artwork.add_child(display)
		display.configure(bridge,far)
		displays.append(display)
		print("MIDORI_MEASURED_BRIDGE: ",crossing.id," world_scale=",bridge.global_basis.get_scale()," support_instances=",count)
	return displays
