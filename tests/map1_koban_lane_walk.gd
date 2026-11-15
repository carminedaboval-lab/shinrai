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
	await check_mirror_routes()
	print("KOBAN_LANE_DONE passed=",passed," failed=",failed)
	quit(1 if failed else 0)

func check_mirror_routes() -> void:
	var reviewed := 0
	for site: Dictionary in map.curve_mirrors.sites:
		var koban: bool = site.street=="koban lane"
		if not koban and site.heads.size()!=2: continue
		var foot: Vector3 = site.at
		var edge: Node3D
		for candidate: Node3D in map.street_edges:
			if candidate.get_meta("edge").name==site.street and candidate.side==site.far_side:
				edge=candidate
				break
		if edge==null:
			_check(false,"mirror has a matching walking edge")
			continue
		reviewed+=1
		var route_offset: float = (edge.out_of(foot)+edge.half+edge.footway_wide)*0.5
		var from: Vector3 = edge.at(site.s-2.5,route_offset)
		var to: Vector3 = edge.at(site.s+2.5,route_offset)
		await _put(from+Vector3.UP*0.3)
		_check(await _drive([to,from],false,6),"walked both ways behind the mirror at %s"%foot)
		if koban:
			var separation := INF
			for model: MeshInstance3D in map.get_node("KobanLane").find_children("*","MeshInstance3D",true,false):
				var box: AABB = model.global_transform*model.get_aabb()
				var nearest := Vector2(clampf(foot.x,box.position.x,box.end.x),clampf(foot.z,box.position.z,box.end.z))
				separation=minf(separation,nearest.distance_to(Vector2(foot.x,foot.z)))
			_check(is_finite(separation) and separation>1.25,"mirror clears terrace and police-box furniture bounds by %.2f m"%separation)
		else:
			await check_nearest_gate(foot)
	_check(reviewed==3,"reviewed the two koban mirror positions and the two-head tram mirror")

func check_nearest_gate(foot: Vector3) -> void:
	var nearest := INF
	var centre := Vector3.ZERO
	var approach := Vector3.ZERO
	var inside := Vector3.ZERO
	for index: int in world.candidates:
		var plot: Dictionary = world.site(index)
		if not plot.ok or not plot.on_road or not "gate pillars" in str(plot.features.plot): continue
		var wall_z := INF
		for block: Array in plot.spec.blocks:
			var size: Vector3 = block[1]
			var pos: Vector3 = block[0]
			if is_equal_approx(size.x,0.28) and is_equal_approx(size.z,0.28) and pos.z < -0.2:
				wall_z=pos.z
				break
		if not is_finite(wall_z): continue
		var gate_local := Vector3(plot.spec.doors[0].at,0,wall_z)
		var gate: Vector3 = plot.frame*gate_local
		var gap := Vector2(gate.x-foot.x,gate.z-foot.z).length()
		if gap<nearest:
			nearest=gap
			centre=gate
			approach=plot.frame*(gate_local+Vector3.FORWARD*1.4)
			inside=plot.frame*(gate_local+Vector3.BACK*0.6)
	if not is_finite(nearest):
		_check(false,"located a gate near the two-head mirror")
		return
	var start: Vector3 = map.on_ground(approach.x,approach.z)
	await _put(start+Vector3.UP*0.3)
	_check(await _drive([map.on_ground(inside.x,inside.z),start],false,6),"walked through the nearest gate at %s (%.2f m from mirror) and back"%[centre,nearest])
