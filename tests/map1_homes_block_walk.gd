extends "res://tests/probe_map1_world.gd"
## Walk each exported pavement through the homes block, including its side-road
## mouths. The street list comes from the live map; names only label results.
const HOMES := Rect2(40.0,400.0,140.0,125.0)
const NORTH_KOBAN := Rect2(40.0,330.0,175.0,95.0)

const EAST_BLOCK := Rect2(240.0,395.0,160.0,135.0)
## Distances measured at the collision faces where the lane ends beside a doorway.
const WALL_SETBACK := {
	"homes lane 219 a -1": 0.60,
	"homes lane z405 a +1": 0.80,
	"homes lane 329 b 2 +1": 0.40,
	"homes lane 378 a -1": 0.20,
}

func in_review_area(point: Vector3) -> bool:
	var flat := Vector2(point.x,point.z)
	return HOMES.has_point(flat) or NORTH_KOBAN.has_point(flat) or EAST_BLOCK.has_point(flat)

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
	var sides := 0
	var mouths := 0
	for edge: Node3D in map.street_edges:
		var data: Dictionary = edge.get_meta("edge")
		var has_pavement: bool = edge.footway_wide>=0.6
		var offset: float = edge.half + (0.5*edge.footway_wide if has_pavement else -0.65)
		var path := PackedVector3Array()
		var support_errors := PackedFloat32Array()
		var length := 0.0
		var breaks: Array[float] = [0.0]
		for i in range(1,data.points.size()):
			var a: Array = data.points[i-1]
			var b: Array = data.points[i]
			length += Vector2(a[0],a[1]).distance_to(Vector2(b[0],b[1]))
			breaks.append(length)
		if edge.is_round:
			length = edge.runs[0].y
			breaks = [0.0,length]
		elif edge.fillet_r>0.0:
			length = edge.fillet_at
			breaks = breaks.filter(func(d: float)->bool: return d<length)
			breaks.append(length)
		for i in range(1,ceili(length)):
			breaks.append(float(i))
		breaks.sort()
		var label := "%s side %.0f"%[data.name,edge.side]
		if not has_pavement: label += " (along the road beside the kerb)"
		var ends: Array = data.get("ends",[])
		if ends.size()==2:
			for end_index in 2:
				if ends[end_index]!="dead" and ends[end_index]!="cut": continue
				var sign_out := -1.0 if end_index==0 else 1.0
				var end_station := 0.0 if end_index==0 else length
				var closed: bool = ends[end_index]=="dead"
				var setback: float = WALL_SETBACK.get("%s %+d" % [data.name, int(sign_out)], 0.0)
				var house_side: bool = data.name == "homes lane 219 a" and end_index == 0 and edge.side > 0
				if house_side:
					await _put(edge.at(end_station - sign_out * 2.0, 0.0, 0.25))
				var correct := true
				for lateral: float in [0.08,edge.half*0.8,edge.half+0.5*edge.KERB_WIDE,edge.half+0.5*edge.footway_wide]:
					var from: Vector3 = edge.at(end_station-sign_out*0.6,lateral,0.75)
					var to: Vector3 = edge.at(end_station+sign_out*(setback+0.6),lateral,0.75)
					var query := PhysicsRayQueryParameters3D.create(from,to,1,[player.get_rid()])
					var contact := player.get_world_3d().direct_space_state.intersect_ray(query)
					var on_shared_pavement: bool = edge.has_meta("island_partner") and lateral>edge.half+edge.KERB_WIDE
					if house_side and lateral >= edge.half * 0.79:
						# The house closes this part of the lane. Its angled facade and usable
						# front door meet the rays at different distances from the end line.
						var house: Node3D = world.houses.get(1662)
						var facade: bool = lateral < edge.half
						var part := "Shell" if facade else "Door_front/HingedLeaf"
						var depth := 0.63 if facade else 0.14
						correct = correct and house != null and not contact.is_empty() and contact.collider == house.get_node_or_null(part) and absf(from.distance_to(contact.position)-0.6-depth)<0.04
					elif closed and not on_shared_pavement:
						correct = correct and not contact.is_empty() and contact.collider.get_parent()==edge and str(contact.collider.name).begins_with("EndWallBody") and absf(from.distance_to(contact.position)-0.6-setback)<0.04
					else:
						correct = correct and contact.is_empty()
				_check(correct,"end collision matches %s on %s"%[ends[end_index],label])
				if not closed and edge.side>0:
					var start: Vector3 = edge.at(end_station-sign_out*1.5,0)
					var beyond: Vector3 = edge.at(end_station+sign_out*1.5,0)
					await _put(start+Vector3.UP*0.25)
					_check(await _drive([beyond,start],false,5),"walk through block boundary and back on "+label)
		var path_end := length
		# A person leaves a pavement before it ends flush against a shop wall.
		# The tram walk covers the continuous step down and return on both sides.
		if has_pavement and ends.size()==2 and ends[1]=="on":
			var last_centre: Vector3 = edge.at(length,0.0)
			for next: Node3D in map.street_edges:
				if next.side!=edge.side or next.footway_wide>=0.6: continue
				if last_centre.distance_to(next.at(0.0,0.0))<0.02:
					path_end=maxf(0.0,length-0.65)
					break
		var inspected := false

		for station: float in breaks:
			# A walking waypoint represents the centre of the player capsule.
			# Keep it inside a closed boundary even when entering from the dead end.
			if ends.size()==2:
				station=minf(station,path_end)
				if ends[0]=="dead": station=maxf(station,0.65)
				if ends[1]=="dead": station=minf(station,length-0.65)
			var point: Vector3 = edge.at(station,offset)
			if not in_review_area(point):
				if not path.is_empty():
					await walk_section(path,label)
					path.clear()
				continue
			inspected = true
			if path.is_empty() or path[-1].distance_to(point)>0.04: path.append(point)
			if not has_pavement: continue
			for run: Vector2 in edge.runs:
				if station<=run.x+0.2 or station>=run.y-0.2: continue
				var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.6,point-Vector3.UP*0.15,1,[player.get_rid()])
				var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
				if hit.is_empty() or hit.collider!=edge.get_node_or_null("EdgeBody"): support_errors.append(station)
				break
		if not path.is_empty(): await walk_section(path,label)
		if not inspected: continue
		sides += 1
		if has_pavement: _check(support_errors.is_empty(),"pavement collision on "+label+", unsupported stations "+str(support_errors))
		for crossing: Dictionary in data.get("crossings",[]):
			var entries: Array = crossing.sides
			if entries.is_empty(): continue
			for entry: Dictionary in entries:
				if not entry.built or entry.side!=edge.side: continue
				for corner: Dictionary in edge.corners:
					if minf(absf(corner.mouth-entry.from),absf(corner.mouth-entry.to))>0.02: continue
					var radius := minf(edge.CORNER_R,absf(corner.mouth-corner.from))
					var along: float = corner.mouth-corner.dir*radius
					var centre_out: float = edge.half+radius
					var approach: Vector3 = edge.at(along-2.0*corner.dir,edge.half+0.5)
					var bend: Vector3 = edge.at(along+corner.dir*(radius-0.5)*sin(PI/4),centre_out-(radius-0.5)*cos(PI/4))
					var branch: Vector3 = edge.at(corner.mouth-corner.dir*0.5,edge.half+edge.footway_wide+2.2)
					if not in_review_area(branch): continue
					# At a kerb-only branch step down onto the near edge of the road.
					# Match the outgoing kerb by position so mirrored junctions work too.
					var face: Vector3 = edge.at(corner.mouth,edge.half+edge.footway_wide+2.2)
					for other: Node3D in map.street_edges:
						if other==edge or other.footway_wide>=0.6: continue
						var station: float = other.along_of(face)
						if face.distance_to(other.at(station,other.half))>0.03: continue
						branch=other.at(station,other.half-0.65)
						bend=edge.at(corner.mouth+corner.dir*0.65,edge.half-0.65)
						break
					await _put(approach+Vector3.UP*0.25)
					_check(await _drive([bend,branch,bend,approach],false,6),"pavement turn and return on %s at %.2f"%[label,corner.mouth])
		for zone: Vector2 in edge.mouth_zones():
			var along := 0.5*(zone.x+zone.y)
			var main: Vector3 = edge.at(along,0)
			var branch: Vector3 = edge.at(along,offset+0.5*edge.footway_wide+0.5)
			if not in_review_area(branch) or not in_review_area(main): continue
			await _put(main+Vector3.UP*0.2)
			_check(await _drive([branch,main],false,8),"walk into branch and back on %s at %.2f"%[label,along])
			mouths += 1
	_check(sides>0 and mouths>0,"inspected %d street sides and %d side-road mouths"%[sides,mouths])
	# The wall beside 1662 and the raised pavement at 4454 each blocked the return
	# trip even when a player could enter. Exercise both doors with collisions on.
	for index: int in [1662, 4454]:
		var visit: Dictionary = await _visit(index)
		_check(visit["in"] and visit.up and visit.down and visit.out,
			"house %d at the dead end: entered, used the stairs and returned to the street" % index)
	print("HOMES_BLOCK_WALK_DONE sides=%d mouths=%d passed=%d failed=%d"%[sides,mouths,passed,failed])
	quit(1 if failed else 0)

func walk_section(path: PackedVector3Array,label: String) -> void:
	if path.size()<2: return
	await _put(path[0]+Vector3.UP*0.25)
	var route := []
	# Keep all turns, with a waypoint every six metres on a straight.
	var last := path[0]
	for i in range(1,path.size()-1):
		var before := path[i]-path[i-1]
		var after := path[i+1]-path[i]
		var turn := absf(Vector2(before.x,before.z).angle_to(Vector2(after.x,after.z)))
		if path[i].distance_to(last)>=6 or turn>0.015:
			last=path[i]
			route.append(last)
	route.append(path[-1])
	_check(await _drive(route,false,8),"walk route through block on "+label)
