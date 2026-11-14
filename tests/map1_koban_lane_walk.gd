extends "res://tests/probe_map1_world.gd"
## Walk from the houses across the side streets to the terrace, then across to the neighbourhood map.
func _run() -> void:
	map=Blockout.new()
	map.with_player=false
	root.add_child(map)
	world=map.world
	player=RealPlayer.new()
	player.extraction_mode=true
	map.add_child(player)
	camera=player.camera
	world.set_viewer(camera,player)
	var edges: Array=map.street_edges.filter(func(edge: Node3D)->bool: return edge.get_meta("edge").name=="koban lane")
	_check(edges.size()==2 and map.has_node("KobanLane/Terrace") and map.has_node("KobanLane/PoliceBox"),"both Koban lane plots and both walking edges found in the generated map")
	if failed:
		quit(1)
		return
	var south: Node3D=edges[0]
	var north: Node3D=edges[1]
	_check(south.units>120 and north.units>120 and south.grate_at>=0.0,"both raised walks with a drain: %d and %d kerb units"%[south.units,north.units])
	for x: float in [83,92]:
		for edge: Node3D in edges:
			var s: float=edge.along_of(Vector3(x,0,edge.get_meta("edge").points[0][1]))
			_check(not edge.runs.any(func(run: Vector2)->bool: return s>=run.x and s<=run.y),"side-street mouth clear at x %.0f, side %.0f"%[x,edge.side])
	await _put(map.on_ground(151,415.5,0.30),Vector3.LEFT)
	_check(await _drive([map.on_ground(99,415.5),map.on_ground(76,415.5),map.on_ground(25.0,415.5)],true,40),"player walked along the residential pavement and through the junction to the terrace")
	_check(await _drive([map.on_ground(23.4,416.5),map.on_ground(20.7,416.5),map.on_ground(20.7,420)],false,10),"player could enter the terrace between seats and awning")
	_check(await _drive([map.on_ground(21.2,416.4),map.on_ground(22.2,409.2),map.on_ground(22.2,400.2)],false,12),"player crossed the kerb and reached the neighbourhood map at the police office")
	var bounds: AABB=map.get_node("KobanLane/Terrace").get_child(1).mesh.get_aabb()
	for plot in ["Terrace","PoliceBox"]:
		var model: MeshInstance3D = map.get_node("KobanLane/"+plot).get_child(1)
		_check(model.visibility_range_end==0.0,"%s stays visible down the lane without the former distance cutoff"%plot)
	_check(bounds.size.y>2.8 and bounds.size.x>10,"terrace furniture and canopy are present at street scale")
	print("KOBAN_LANE_DONE passed=",passed," failed=",failed)
	quit(1 if failed else 0)
