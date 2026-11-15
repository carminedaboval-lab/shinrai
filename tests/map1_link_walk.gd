extends "res://tests/map1_side_street_walk.gd"
## Walk the built homes link from street centre to street centre and check the
## drawn surfaces on either side of the seams. Physics alone cannot see asphalt.
func _run() -> void:
	map = Blockout.new()
	map.with_player = false
	root.add_child(map)
	world = map.world
	player = RealPlayer.new()
	map.add_child(player)
	camera = player.camera
	world.set_viewer(camera,player)
	var tris := road_triangles(408,452)
	for seam: float in [417.096,444.100]:
		var bad := []
		for dz: float in [-0.67,-0.05,-0.007,0.007,0.05,0.67]:
			for x: float in [88.81,89.128,89.132,90.89,92.27,92.899,92.901]:
				var p: Vector3=map.on_ground(x,seam+dz)
				var hits := surface_hits(p,tris)
				if hits.size()!=1 or absf(hits[0]-0.012)>0.008: bad.append([x,p.z,hits])
		_check(bad.is_empty(),"42 asphalt samples across seam z %.3f at grade, exactly one surface: %s"%[seam,bad])
	for x: float in [90.86,87.80,93.90]:
		var home: Vector3=map.on_ground(x,448.23)
		var koban: Vector3=map.on_ground(x,412.96)
		await _put(home+Vector3.UP*0.25)
		var checkpoints := [map.on_ground(x,444.0),map.on_ground(x,430.0),map.on_ground(x,417.3),koban]
		_check(await _drive(checkpoints,false,12),"player reached Koban from homes along x %.2f"%x)
		checkpoints.reverse()
		checkpoints.append(home)
		_check(await _drive(checkpoints,false,12),"player returned to homes along x %.2f"%x)
	var concrete := lane_gutter_triangles()
	for side: float in [-1.0,1.0]:
		var centre_z := 412.965 + side*3.483
		for piece in 8:
			var angle := -PI/2 + (piece+0.5)*PI/8
			var direction := Vector2(sin(angle),-side*cos(angle))
			# Use the rendered lip to locate the seam independently of the asphalt cuts.
			var low := 1.00
			var high := 1.10
			for iteration in 9:
				var middle := (low+high)*0.5
				var sample := island_point(centre_z,direction,middle)
				if surface_hits(sample,concrete).is_empty(): high=middle
				else: low=middle
			var inner := island_point(centre_z,direction,low-0.01)
			var outer := island_point(centre_z,direction,high+0.01)
			var top := island_point(centre_z,direction,0.68)
			var stand := cast_foot(top)
			var supported: bool = not stand.is_empty() and absf(stand.position.y-top.y-0.13)<0.015
			var joined := low>1.02 and high<1.09 and not surface_hits(inner,concrete).is_empty() and surface_hits(inner,tris).is_empty() and surface_hits(outer,tris).size()==1
			_check(supported and joined,"raised island and asphalt meet at piece %d, side %.0f, measured lip %.3f"%[piece+1,side,low])
		var z := centre_z+side*1.91
		var west: Vector3=map.on_ground(84.721,z)
		var east: Vector3=map.on_ground(90.861,z)
		await _put(west+Vector3.UP*0.2)
		_check(await _drive([east,west],false,6),"walk between both lanes across island and return, side %.0f"%side)
		for x: float in [84.721,90.861]:
			var main: Vector3=map.on_ground(x,412.965)
			var arm: Vector3=map.on_ground(x,412.965+side*8.3)
			await _put(main+Vector3.UP*0.2)
			_check(await _drive([arm,main],false,7),"enter individual branch at x %.3f on side %.0f and return"%[x,side])
	for z: float in [441.07,455.34]:
		var previous := -INF
		var continuous := true
		for i in 27:
			var p: Vector3=map.on_ground(84.32+i*0.15,z)
			var hit := cast_foot(p)
			if hit.is_empty():
				continuous=false
				continue
			var height: float=hit.position.y-p.y
			if height<0.025 or height>0.15 or (previous!=-INF and absf(height-previous)>0.012): continuous=false
			previous=height
		var a: Vector3=map.on_ground(84.32,z)
		var b: Vector3=map.on_ground(88.22,z)
		await _put(a+Vector3.UP*0.25)
		_check(continuous and await _drive([b,a],false,5),"level paved route across former trench at z %.2f"%z)
	print("LINK_WALK_DONE passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)

func island_point(centre_z: float,direction: Vector2,radius: float) -> Vector3:
	return map.on_ground(87.706+direction.x*radius,centre_z+direction.y*radius)

func cast_foot(p: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.4,p-Vector3.UP*0.15,1,[player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(ray)
