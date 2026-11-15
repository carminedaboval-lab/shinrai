extends "res://tests/probe_map1_world.gd"
## Test the customer's route past the outdoor fittings at each buildable konbini.
func _run() -> void:
	map = Blockout.new()
	map.with_player = false
	root.add_child(map)
	world = map.world
	player = RealPlayer.new()
	map.add_child(player)
	camera = player.camera
	world.set_viewer(camera,player)
	var stores := 0
	var plan_only: Array[int] = []
	for business: Dictionary in map.data.businesses:
		if business.what != "convenience store": continue
		var index := int(business.box)
		var site: Dictionary = world.site(index)
		if not site.get("ok",false): continue
		if not world.candidates.has(index):
			plan_only.append(index)
			continue
		stores += 1
		var front_x := float(site.spec.doors[0].at)
		var frame: Transform3D = site.frame
		var outside := frame * Vector3(front_x,0,-float(site.step_depth)-1.2)
		var approach := frame * Vector3(front_x,0,site.door_z-1.65)
		var inside := frame * Vector3(front_x,0,site.door_z+0.65)
		await _put(outside+Vector3.UP*0.3,frame.basis.z)
		await _frames(20)
		var reached: bool = await _drive([approach],false,8)
		await _frames(30)
		var reachable: bool = reached and world.houses.has(index)
		if not reachable: print("STORE_INFO ",index," candidate=",world.candidates.has(index)," level=",world.level_of(index)," pos=",player.global_position," target=",approach," gap=",world.outline_gap(index,player.global_position)," on_street=",world.fronts_street_of(index,player.global_position)," plan_kind=",site.kind)
		_check(reachable,"reach the entrance at store %d"%index)
		if not reachable: continue
		var door = world.houses[index].door("front")
		var opened: bool = door.interact(player)
		if not opened and door.locked: opened=door.open_with_chip(player)
		await _settle(1.3)
		_check(opened and await _drive([inside],false,8),"open the front door and enter store %d"%index)
		_check(await _drive([approach,outside],false,8),"exit store %d past its outdoor fittings"%index)
	_check(stores>0,"tested the entrances of %d runtime convenience stores"%stores)
	print("KONBINI_PLANNED_ONLY ",plan_only)
	print("KONBINI_WALK_DONE stores=%d passed=%d failed=%d"%[stores,passed,failed])
	quit(1 if failed else 0)
