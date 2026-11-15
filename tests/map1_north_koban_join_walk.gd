extends "res://tests/map1_side_street_walk.gd"
## Follow the formerly overlapping lanes through the z378 crossing and old z400 cut.
const LANE_X := 84.7206

func _run() -> void:
	map = Blockout.new()
	map.with_player = false
	root.add_child(map)
	world = map.world
	player = RealPlayer.new()
	map.add_child(player)
	camera = player.camera
	world.set_viewer(camera,player)
	var triangles := road_triangles(366,405,80,89)
	for z: float in [367.91,371.43,371.46,374.10,374.13,378.27,382.36,382.39,384.86,384.89,387.88,387.92,393.86,393.89,399.99,400.01]:
		var correct := true
		for dx: float in [-1.83,-0.81,0.13,0.92,1.83]:
			var point: Vector3 = map.on_ground(LANE_X+dx,z)
			var hits := surface_hits(point,triangles)
			correct = correct and hits.size()==1 and absf(hits[0]-0.012)<0.01
		_check(correct,"one asphalt surface across lane 85 at z %.2f"%z)
	for dx: float in [-2.9,-1.45,0.13,1.45,2.9]:
		# Both pavements are full width at the former block cut.
		var near: Vector3 = map.on_ground(LANE_X+dx,395.0)
		var far_end: Vector3 = map.on_ground(LANE_X+dx,405.0)
		await _put(near+Vector3.UP*0.25)
		_check(await _drive([far_end,near],false,8),"cross the old block cut both ways at offset %.2f"%dx)
	var north: Vector3 = map.on_ground(LANE_X,366)
	var south: Vector3 = map.on_ground(LANE_X,406)
	await _put(north+Vector3.UP*0.25)
	_check(await _drive([south,north],false,30),"walk the length of the overlap through the crossroads and back")
	print("NORTH_KOBAN_JOIN_DONE passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)
