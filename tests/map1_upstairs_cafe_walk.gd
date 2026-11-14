extends "res://tests/probe_map1_world.gd"
## Walk the ordinary player through both doors, round the stairwell, to the seats and back.
func _run() -> void:
	map = Blockout.new()
	map.with_player = false
	root.add_child(map)
	world = map.world
	player = RealPlayer.new()
	map.add_child(player)
	camera = player.camera
	world.set_viewer(camera, player)
	var index := -1
	for tenant: Dictionary in map.data.businesses:
		if Vector2(tenant.x,tenant.z).distance_to(Vector2(175.07,503.43)) < 0.15:
			index = int(tenant.box)
	if index < 0:
		quit(1)
		return
	var site: Dictionary = world.site(index)
	var frame: Transform3D = site.frame
	var entry: float = site.spec.doors[0].at
	await _put(frame * Vector3(entry,0.3,-3.0),frame.basis.z)
	await _frames(20)
	_check(world.level_of(index)==FULL and site.features.get("cafe_floor",0)==2,"upstairs cafe fitted and loaded")
	if failed:
		quit(1)
		return
	var house: Node3D = world.houses[index]
	await _drive([frame*Vector3(entry,0,-1.75)],false,6)
	print("ENTRY ",house.door("front").interaction_prompt(player)," distance=",house.door("front").interaction_distance(player)," actor=",frame.affine_inverse()*player.global_position)
	_check(house.door("front").interact(player),"opened the street door")
	await _settle(1.3)
	var hall: Array = []
	for pt: Vector2 in site.route:
		hall.append(frame*Vector3(pt.x,0,pt.y))
	_check(await _drive(hall,false,6),"walked from street to stair landing")
	var aisle: Array = []
	for pt: Vector2 in [Vector2(5.5,6.05),Vector2(5.5,1.45),Vector2(4.60,1.45)]:
		aisle.append(frame*Vector3(pt.x,0,pt.y))
	_check(await _drive(aisle,false,6),"walked along the upstairs hall to cafe door")
	_check(house.door("west1_0").interact(player),"opened cafe door")
	await _settle(1.3)
	var counter := frame*Vector3(1.85,0,1.73)
	var inside := frame*Vector3(3.08,0,1.45)
	_check(await _drive([inside,counter],false,6),"reached window seats")
	var local := frame.affine_inverse()*player.global_position
	_check(absf(local.y - float(house.floor_heights[1])) < 0.08 and player.is_on_floor(),"standing on upper floor at "+str(local))
	aisle.reverse()
	hall.reverse()
	_check(await _drive([inside]+aisle+hall+[frame*Vector3(entry,0,-2.5)],false,6),"returned down the stair and out to the street")
	print("CAFE_WALK passed=",passed," failed=",failed)
	quit(1 if failed else 0)
