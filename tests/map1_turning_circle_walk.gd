extends "res://tests/map1_side_street_walk.gd"
## Follow the two approaches and the whole circle without resetting the player at a seam.
func _run() -> void:
	map = Blockout.new()
	map.with_player = false
	root.add_child(map)
	world = map.world
	player = RealPlayer.new()
	map.add_child(player)
	camera = player.camera
	world.set_viewer(camera,player)
	await physics_frame
	var ring: Node3D = map.circle_edge
	var flares: Array[Node3D] = []
	for street: Node3D in map.street_edges:
		if street.fillet_r > 0.0: flares.append(street)
	_check(ring != null and flares.size() == 2,"circle has two approaches")
	if ring == null or flares.size() != 2:
		quit(1)
		return
	var circle_road := faces(map.get_node("StreetEdge/CircleAsphalt"))
	var street_road := faces(map.get_node("StreetEdge/Asphalt"))
	var ring_length: float = ring.runs[0].y
	var start: Vector3 = ring.at(0,ring.half)
	if flare_point(flares[1],1,0).distance_to(start) < flare_point(flares[0],1,0).distance_to(start):
		flares.reverse()
	for inset: float in [0.75,-0.85]:
		var route := approach(flares[0],inset)
		for i in range(1,ceili(ring_length)):
			route.append(ring.at(i,ring.half+inset))
		var finish := approach(flares[1],inset)
		finish.reverse()
		route.append_array(finish)
		var label := "footway" if inset>0 else "road"
		await _put(route[0]+Vector3.UP*0.25)
		_check(await _drive(route,false,5),"both joins and whole circle on the "+label)
		route.reverse()
		_check(await _drive(route,false,5),"return on the "+label)
	var concrete := nearby_faces(ring)
	var count := 0
	var faults := []
	for street: Node3D in flares:
		var flare_concrete := nearby_faces(street)
		var pieces: int = street.fillet_pieces()
		for i in pieces:
			var a := flare_point(street,float(i)/pieces,-street.GUTTER_WIDE)
			var b := flare_point(street,float(i+1)/pieces,-street.GUTTER_WIDE)
			var roadward := flare_point(street,(i+0.5)/pieces,-1.0)-flare_point(street,(i+0.5)/pieces,0.0)
			if not lip_ok(a,b,roadward,flare_concrete,circle_road): faults.append([street.name,i])
			count += 1
	var s := 0.0
	while s < ring_length-0.001:
		var end := minf(s+ring.UNIT,ring_length)
		var a: Vector3 = ring.at(s,ring.half-ring.GUTTER_WIDE)
		var b: Vector3 = ring.at(end,ring.half-ring.GUTTER_WIDE)
		var roadward: Vector3 = ring.at((s+end)*0.5,0.0)-(a+b)*0.5
		if not lip_ok(a,b,roadward,concrete,circle_road): faults.append([ring.name,s])
		count += 1
		s=end
	_check(faults.is_empty(),"%d gutter chords have concrete and asphalt 1 cm either side of the lip, faults %s"%[count,faults])
	var seam_ok := true
	for lateral: float in [-2.11,-1.37,0.24,1.19,2.13]:
		for ds: float in [-0.012,0.012]:
			var p: Vector3 = flares[0].at(flares[0].fillet_at+ds,lateral)
			var ribbon := surface_hits(p,street_road)
			var circle := surface_hits(p,circle_road)
			var expected := ribbon if ds<0 else circle
			seam_ok = seam_ok and ribbon.size()+circle.size()==1 and expected.size()==1 and absf(expected[0]-0.012)<0.01
	_check(seam_ok,"street asphalt joins circle at grade across five lines")
	print("CIRCLE_REVIEW_DONE passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)

func approach(edge: Node3D,inset: float) -> Array:
	var path := [edge.at(edge.fillet_at-3,edge.half+inset)]
	for i in 7: path.append(flare_point(edge,i/6.0,inset))
	return path

func flare_point(edge: Node3D,fraction: float,inset: float) -> Vector3:
	var p: Vector2 = edge.fillet_point(edge.fillet_r-inset,edge.fillet_angle*fraction)
	return edge.at(p.x,p.y)

func faces(node: MeshInstance3D) -> PackedVector3Array:
	return node.global_transform*node.mesh.get_faces()

func nearby_faces(edge: Node3D) -> PackedVector3Array:
	var mesh := faces(edge.get_node("Edge"))
	var nearby := PackedVector3Array()
	for i in range(0,mesh.size(),3):
		if maxf(mesh[i].x,maxf(mesh[i+1].x,mesh[i+2].x))<143: continue
		for j in 3: nearby.append(mesh[i+j])
	return nearby

func lip_ok(a: Vector3,b: Vector3,roadward: Vector3,concrete: PackedVector3Array,road: PackedVector3Array) -> bool:
	var mid := (a+b)*0.5
	roadward.y=0
	var step := roadward.normalized()*0.01
	var inner: Vector3 = map.on_ground(mid.x-step.x,mid.z-step.z)
	var outer: Vector3 = map.on_ground(mid.x+step.x,mid.z+step.z)
	return not surface_hits(inner,concrete).is_empty() and surface_hits(inner,road).is_empty() and surface_hits(outer,concrete).is_empty() and surface_hits(outer,road).size()==1
