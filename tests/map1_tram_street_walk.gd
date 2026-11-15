extends "res://tests/map1_side_street_walk.gd"
## Follow the residential lane into the traffic lane and inspect all four mouths on the tram street.
func _run() -> void:
	map = Blockout.new()
	map.with_player = false
	root.add_child(map)
	world = map.world
	player = RealPlayer.new()
	map.add_child(player)
	camera = player.camera
	world.set_viewer(camera,player)
	var road := road_triangles(481,499,40,180)
	for x: float in [48.31,69.83,81.63,120.17,151.48,175.08]:
		var clean := true
		for z: float in [484.31,485.37,486.98,487.02,488.04,490.17,492.98,493.02,494.57,495.71]:
			var hits := surface_hits(map.on_ground(x,z),road)
			var bed := absf(z-490.0)<3.0
			clean = clean and (hits.is_empty() if bed else hits.size()==1 and absf(hits[0]-0.012)<0.012)
		_check(clean,"two paved traffic lanes and clear six-metre rail bed at x %.2f"%x)
	for entry: Vector2 in [Vector2(69.84,1),Vector2(81.63,-1),Vector2(151.49,1),Vector2(175.08,-1)]:
		var x := entry.x
		var side := entry.y
		var lane_z := 490.0+8.0*side
		var complete := true
		for dx: float in [-1.12,0.17,1.08]:
			for dz: float in [-0.03,0.03,-1.9,-2.03]:
				var hits := surface_hits(map.on_ground(x+dx,lane_z+dz*side),road)
				complete = complete and hits.size()==1 and absf(hits[0]-0.012)<0.012
		_check(complete,"continuous asphalt into branch at x %.2f"%x)
		var a: Vector3 = map.on_ground(x,lane_z+side*4.0)
		var b: Vector3 = map.on_ground(x,490+side*4.5)
		for turn: float in [-1,1]:
			var c: Vector3 = map.on_ground(x+turn*4.0,b.z)
			await _put(a+Vector3.UP*0.25)
			_check(await _drive([b,c,b,a],false,8),"walk from lane at %.2f onto tram street, turn %.0f and return"%[x,turn])
	var paths := [
		[Vector2(78.45,459),Vector2(78.45,475),Vector2(78.45,480)],
		[Vector2(84.72,459),Vector2(84.72,469.4),Vector2(83.24,470.1),Vector2(83.24,480)]]
	for path: Array in paths:
		var route := []
		for pos: Vector2 in path: route.append(map.on_ground(pos.x,pos.y))
		await _put(route[0]+Vector3.UP*0.25)
		var forward := await _drive(route,false,12)
		route.reverse()
		_check(forward and await _drive(route,false,12),"lane 82 across old block boundary and past shop 1716 at x %.2f"%path[0].x)
	for side: float in [-1.0,1.0]:
		var route := []
		for mark: Vector2 in [Vector2(466,3.16),Vector2(469.7,3.16),Vector2(470.6,1.7),Vector2(480.65,1.7),Vector2(483,1.7),Vector2(485.5,1.7)]:
			route.append(map.on_ground(175.0875+side*mark.y,mark.x))
		await _put(route[0]+Vector3.UP*0.25)
		var forward := await _drive(route,false,8)
		route.reverse()
		_check(forward and await _drive(route,false,8),"leave the pavement before the lane 175 shop pinch, walk to the tram street and return on side %.0f"%side)
	print("TRAM_STREET_DONE passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)
