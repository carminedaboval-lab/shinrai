extends "res://tests/map1_side_street_walk.gd"
## Check both sides of each east-block crossing and the raised strip between the two close lanes.
func _run() -> void:
	map = Blockout.new()
	map.with_player = false
	root.add_child(map)
	world = map.world
	player = RealPlayer.new()
	map.add_child(player)
	camera = player.camera
	world.set_viewer(camera,player)
	var asphalt := road_triangles(394,531,239,401)
	var junctions := [
		Vector2(285.37,404.74), Vector2(291.97,404.76),
		Vector2(291.88,435.22), Vector2(299.78,435.25), Vector2(370.15,435.46),
		Vector2(294.91,496.87), Vector2(329.23,496.97), Vector2(377.73,497.12),
	]
	for junction: Vector2 in junctions:
		for side: float in [-1.0,1.0]:
			var open := true
			for across: float in [-1.1,0.13,1.04]:
				for along: float in [0.47,2.19,2.61,3.92,4.04,5.10]:
					var p: Vector3 = map.on_ground(junction.x+across,junction.y+side*along)
					var hits := surface_hits(p,asphalt)
					open = open and hits.size()==1 and absf(hits[0]-0.012)<0.012
			_check(open,"asphalt joins the lane at %s on side %.0f"%[junction,side])
			var arm: Vector3 = map.on_ground(junction.x,junction.y+side*5.75)
			var mid: Vector3 = map.on_ground(junction.x,junction.y)
			await _put(arm+Vector3.UP*0.25)
			for turn: float in [-1.0,1.0]:
				var end: Vector3 = map.on_ground(junction.x+turn*4.5,junction.y)
				_check(await _drive([mid,end,mid,arm],false,7),"turn %.0f and return to arm %.0f at %s"%[turn,side,junction])
	for z: float in [398.6,410.5]:
		var a: Vector3 = map.on_ground(285.37,z)
		var b: Vector3 = map.on_ground(291.96,z)
		var mid: Vector3 = map.on_ground(288.55,z)
		var ray := PhysicsRayQueryParameters3D.create(mid+Vector3.UP*0.5,mid-Vector3.UP*0.1,1,[player.get_rid()])
		var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
		_check(not hit.is_empty() and absf(hit.position.y-mid.y-0.13)<0.02,"raised island between lanes at z %.2f"%z)
		await _put(a+Vector3.UP*0.25)
		_check(await _drive([mid,b,mid,a],false,7),"cross the island between 285 and 292 and return at z %.2f"%z)
	var start: Vector3 = map.on_ground(377.67,515.0)
	var cross: Vector3 = map.on_ground(377.73,497.12)
	var east: Vector3 = map.on_ground(402.0,497.19)
	await _put(start+Vector3.UP*0.25)
	_check(await _drive([cross,east,cross,start],false,18),"walk from lane 378 beyond the east cut and return")
	print("EAST_LANE_DONE passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)
