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
			for x: float in [88.81,89.128,89.132,90.89,92.27,92.90]:
				var p: Vector3=map.on_ground(x,seam+dz)
				var hits := surface_hits(p,tris)
				if hits.size()!=1 or absf(hits[0]-0.012)>0.008: bad.append([x,p.z,hits])
		_check(bad.is_empty(),"36 asphalt samples across seam z %.3f at grade, exactly one surface: %s"%[seam,bad])
	for x: float in [90.86,87.80,93.90]:
		var home: Vector3=map.on_ground(x,448.23)
		var koban: Vector3=map.on_ground(x,412.96)
		await _put(home+Vector3.UP*0.25)
		var checkpoints := [map.on_ground(x,444.0),map.on_ground(x,430.0),map.on_ground(x,417.3),koban]
		_check(await _drive(checkpoints,false,12),"player reached Koban from homes along x %.2f"%x)
		checkpoints.reverse()
		checkpoints.append(home)
		_check(await _drive(checkpoints,false,12),"player returned to homes along x %.2f"%x)
	# A rounded nose should support a foot at its tip and sides, but pavement
	# must not extend into the stub or carriageway beyond the radius.
	var west: Node3D=map.get_node("LinkLaneEdge")
	var cx := 87.808
	var cz := 416.346
	for deg: float in [-72,-36,0,36,72]:
		var dir := Vector2(sin(deg_to_rad(deg)),-cos(deg_to_rad(deg)))
		var inside: Vector3=map.on_ground(cx+dir.x*0.63,cz+dir.y*0.63)
		var outside: Vector3=map.on_ground(cx+dir.x*1.04,cz+dir.y*1.04)
		var inner := cast_foot(inside)
		var outer := cast_foot(outside)
		var raised: bool = not inner.is_empty() and inner.collider==west.get_node("EdgeBody") and absf(inner.position.y-inside.y-0.13)<0.015
		var clear: bool = outer.is_empty() or outer.position.y-outside.y<0.03
		_check(raised and clear,"rounded island supports inside and leaves outside open at %.0f degrees"%deg)
	# The north mouth may have been paved as one rectangle across the island.
	# A 12 mm road surface can poke through the low side of its 8-20 mm channel.
	var nose_edges := link_gutter_triangles()
	for dz: float in [0.22,0.51]:
		var p: Vector3=map.on_ground(88.60,cz+dz)
		var gutter := surface_hits(p,nose_edges)
		var road := surface_hits(p,tris)
		_check(gutter.size()==1 and (road.is_empty() or road.max()<gutter[0]-0.001),"round island gutter is visible above road at (%.2f,%.3f): gutter %s road %s"%[p.x,p.z,gutter,road])
	# Find the outer lip in the rendered mesh first. Asphalt should start just
	# outside that lip, including halfway along each of the seven cast pieces.
	for degrees: float in [-77.14,-51.43,-25.71,0.0,25.71,51.43,77.14]:
		var direction := Vector2(sin(deg_to_rad(degrees)),-cos(deg_to_rad(degrees)))
		var last_concrete := 0.0
		for mm in range(925,980,2):
			var radius := mm / 1000.0
			var p: Vector3 = map.on_ground(cx+direction.x*radius,cz+direction.y*radius)
			if not surface_hits(p,nose_edges).is_empty(): last_concrete = radius
		var outside_radius := last_concrete + 0.010
		var outside: Vector3 = map.on_ground(cx+direction.x*outside_radius,cz+direction.y*outside_radius)
		var hits := surface_hits(outside,tris)
		_check(last_concrete>0.93 and hits.size()==1,"asphalt 10 mm beyond rendered gutter at %.2f degrees, lip radius %.3f, road %s"%[degrees,last_concrete,hits])
	var stub: Vector3=map.on_ground(85.3,418.8)
	var lane: Vector3=map.on_ground(90.86,418.8)
	await _put(stub+Vector3.UP*0.2)
	_check(await _drive([lane,stub],false,6),"player crosses the island's plain back edge from the stub and returns")
	print("LINK_WALK_DONE passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)

func cast_foot(p: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.4,p-Vector3.UP*0.15,1,[player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(ray)
