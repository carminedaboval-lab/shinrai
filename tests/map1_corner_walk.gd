extends "res://tests/probe_map1_world.gd"
## Check each installed kerb return from the physics world, including the open roadway.
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
	var count := 0
	var routes := {}
	for edge: Node3D in map.street_edges:
		var street: String = edge.get_meta("edge").name
		print("CORNER_COUNT ",street," side=",edge.side," returns=",edge.corners.size())
		for corner: Dictionary in edge.corners:
			count += 1
			var dir: float = corner.dir
			var mouth: float = corner.mouth
			var radius := minf(edge.CORNER_R,absf(mouth-corner.from))
			var start := mouth-dir*radius
			var outer: float = edge.half+radius
			var heights := PackedFloat32Array()
			var expected := PackedFloat32Array()
			for angle: float in [0.0,PI/8,PI/4,3*PI/8,PI/2]:
				# The physics edge spans four chords. Probe 18 cm inside and 30 cm
				# outside the intended kerb face, beyond the gutter.
				for r: float in [radius-0.18,radius+0.30]:
					var point: Vector3 = edge.at(start+dir*r*sin(angle),outer-r*cos(angle))
					heights.append(relief(point))
					if r < radius:
						# A dropped entrance comes back up from 3 to 13 cm in 1.2 m.
						var along := start+dir*r*sin(angle)
						var height := 0.13
						for drop: Vector2 in edge.drops:
							var gap := absf(along-clampf(along,drop.x,drop.y))
							height=minf(height,lerpf(0.03,0.13,clampf(gap/1.2,0,1)))
						expected.append(height)
			var raised := true
			var clear := true
			for i in range(0,heights.size(),2):
				raised = raised and absf(heights[i]-expected[i >> 1])<0.015
				clear = clear and absf(heights[i+1])<0.03
			var site := "%s side %.0f at %.2f m"%[street,edge.side,mouth]
			var centre: Vector3 = edge.at(start,outer)
			var concrete := nearby_faces(edge.get_node("Edge"),centre,radius+0.4)
			var asphalt := nearby_faces(edge.get_node("MouthAsphalt"),centre,radius+0.4)
			var failed_pieces := PackedInt32Array()
			for piece in 4:
				var angle := (piece+0.5)*PI/8
				var along := dir*sin(angle)
				var outward := -cos(angle)
				# Locate the rendered concrete lip independently of the road builder.
				var low := radius+0.10
				var high := radius+0.25
				if not covers(edge.at(start+along*low,outer+outward*low),concrete) or covers(edge.at(start+along*high,outer+outward*high),concrete):
					failed_pieces.append(piece)
					continue
				for step in 9:
					var middle := (low+high)*0.5
					if covers(edge.at(start+along*middle,outer+outward*middle),concrete): low=middle
					else: high=middle
				var inner: Vector3 = edge.at(start+along*(low-0.010),outer+outward*(low-0.010))
				var road: Vector3 = edge.at(start+along*(high+0.010),outer+outward*(high+0.010))
				if covers(inner,asphalt) or not covers(road,asphalt): failed_pieces.append(piece)
			_check(failed_pieces.is_empty(),"asphalt meets four measured gutter lips on "+site+", failed pieces "+str(failed_pieces))
			_check(raised,"walkable top follows the entire turn on "+site)
			_check(clear,"open road outside the curve on "+site)
			# Walk one representative return per built street, going out and back.
			if routes.has(street) and street!="shop row": continue
			routes[street] = true
			var approach: Vector3 = edge.at(start-dir*0.9,edge.half+0.53)
			var bend: Vector3 = edge.at(start+dir*(radius-0.45)*sin(PI/4),outer-(radius-0.45)*cos(PI/4))
			var side_walk: Vector3 = edge.at(mouth-dir*0.48,edge.half+edge.footway_wide-0.10)
			await _put(approach+Vector3.UP*0.25)
			_check(await _drive([bend,side_walk,bend,approach],false,5),"player turned onto the side street and returned on "+site)
			if street=="shop row":
				print("SIGNAL_CURVE inside heights ",[heights[0],heights[2],heights[4],heights[6],heights[8]])
		if street=="shop row" and edge.side<0:
			var across: Vector3 = map.on_ground(-274,-456,0.25)
			await _put(across)
			var finish: Vector3 = map.on_ground(-238,-456)
			var joined := true
			for x in range(-274,-237):
				var top := relief(map.on_ground(x,-456))
				joined = joined and top>=0.025 and top<=0.14
			_check(joined and await _drive([finish,across],false,18),"continuous north pavement past the whole signal junction, walked both ways")
	_check(count>0,"found built corner returns for the collision review")
	print("CORNER_WALK_DONE corners=%d passed=%d failed=%d"%[count,passed,failed])
	quit(1 if failed else 0)

func relief(point: Vector3) -> float:
	var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.4,point-Vector3.UP*0.15,1,[player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
	return INF if hit.is_empty() else hit.position.y-point.y

func nearby_faces(instance: MeshInstance3D,centre: Vector3,extent: float) -> PackedVector3Array:
	var faces := instance.global_transform*instance.mesh.get_faces()
	var result := PackedVector3Array()
	for i in range(0,faces.size(),3):
		var box := AABB(faces[i],Vector3.ZERO).expand(faces[i+1]).expand(faces[i+2])
		if absf(centre.x-box.get_center().x)<=extent+box.size.x*0.5 and absf(centre.z-box.get_center().z)<=extent+box.size.z*0.5:
			result.append_array(faces.slice(i,i+3))
	return result

func covers(point: Vector3,faces: PackedVector3Array) -> bool:
	for i in range(0,faces.size(),3):
		if Geometry3D.ray_intersects_triangle(point+Vector3.UP,Vector3.DOWN,faces[i],faces[i+1],faces[i+2])!=null: return true
	return false
