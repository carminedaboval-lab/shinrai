extends "res://tests/probe_map1_world.gd"
## Reach every plaza seat from the pedestrian crossing and walk the public footway.
func _run() -> void:
	map = Blockout.new()
	map.with_player = false
	root.add_child(map)
	world = map.world
	player = RealPlayer.new()
	map.add_child(player)
	camera = player.camera
	world.set_viewer(camera,player)
	var plaza := map.get_node_or_null("Plaza0")
	var furniture := map.get_node_or_null("Plaza0/Furniture") as StaticBody3D
	_check(furniture!=null and plaza.has_node("TreePits") and plaza.space.trees.size()==19,"furniture installed on the paved plaza with 19 tree pits")
	if failed:
		quit(1)
		return
	var seats := furniture.find_children("Seat*","CollisionShape3D",false,false).filter(func(n): return not str(n.name).begins_with("SeatBack"))
	var posts := furniture.find_children("LampPost*","CollisionShape3D",false,false)
	_check(seats.size()==6 and posts.size()==5,"six seats and five lamp posts installed")
	var toe: float = plaza.space.back+2.0
	var pit_clearance := INF
	for tree: Array in plaza.space.trees:
		var pit: Rect2 = plaza._pit_square(tree[0],tree[1])
		pit_clearance = minf(pit_clearance,pit.position.y-toe)
	_check(pit_clearance>=-0.001,"all 19 tree pits clear the 2 m slope; nearest edging starts %.2f m beyond its toe"%pit_clearance)
	var bench_clearance := INF
	for seat: CollisionShape3D in seats:
		bench_clearance = minf(bench_clearance,seat.global_position.z-0.245-toe)
	var lamp_clearance := INF
	for post: CollisionShape3D in posts:
		lamp_clearance = minf(lamp_clearance,post.global_position.z-0.17-toe)
	_check(bench_clearance>=3.05 and lamp_clearance>=2.62,"bench feet clear the toe by %.3f m and lamp bases by %.3f m"%[bench_clearance,lamp_clearance])
	var aisle_z: float = seats[0].global_position.z+1.5
	await _put(map.on_ground(-269.4,-456,0.3),Vector3.BACK)
	_check(await _drive([map.on_ground(-269.4,-440),map.on_ground(-269.4,aisle_z)],false,15),"reached plaza from shops via zebra crossing")
	for x: float in [-427,-352,-290,-269.4]:
		check_apron(x,plaza.space.back)
	for x: float in [-269.4,-352]:
		var top: Vector3 = map.on_ground(x,plaza.space.back-0.5)
		var bottom: Vector3 = map.on_ground(x,plaza.space.back+2.4)
		await _put(top+Vector3.UP*0.15)
		_check(await _drive([bottom,top],false,6),"walked down and back up the plaza apron at x %.1f"%x)
	await _put(map.on_ground(-269.4,aisle_z,0.15))
	seats.reverse()
	for seat: CollisionShape3D in seats:
		var p := seat.global_position
		# Approach from the plaza side, around the end of the seat to its front.
		var route := [map.on_ground(p.x+1.5,aisle_z),map.on_ground(p.x+1.5,p.z-0.8),map.on_ground(p.x,p.z-0.8)]
		_check(await _drive(route,false,19),"walked to the front of "+str(seat.name))
		_check(await _drive([route[1],route[0]],false,6),"walked back out beside "+str(seat.name))
	for prop: CollisionShape3D in seats+posts:
		var p := prop.global_position
		var surface: Vector3 = map.on_ground(p.x,p.z)
		var ray := PhysicsRayQueryParameters3D.create(surface+Vector3(0,0.30,-0.7),surface+Vector3(0,0.30,0),1,[player.get_rid()])
		var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
		_check(not hit.is_empty() and hit.collider==furniture and p.z-prop.shape.size.z*0.5>plaza.space.back,"solid fixture clear of the footway: "+str(prop.name))
	_check(await _drive([map.on_ground(-427,aisle_z),map.on_ground(-427,-440),map.on_ground(-269.4,-440)],true,60),"walked the full furnished frontage on the through pavement")
	print("PLAZA_WALK passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)

func check_apron(x: float, back: float) -> void:
	var heights := PackedFloat32Array()
	var offsets: Array[float] = [-0.02,0.02,0.25,0.5,0.75,1.0,1.25,1.5,1.75,1.98,2.02]
	for offset: float in offsets:
		var p: Vector3 = map.on_ground(x,back+offset)
		var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.35,p-Vector3.UP*0.12,1,[player.get_rid()])
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		heights.append(INF if hit.is_empty() else hit.position.y-p.y)
	var crest := 0.03 if is_equal_approx(x,-269.4) else 0.13
	var fits := absf(heights[0]-crest)<0.005 and absf(heights[10])<0.018
	for i in range(1,10):
		fits = fits and absf(heights[i]-lerpf(crest,0.012,offsets[i]/2.0))<0.006
	_check(fits and absf(heights[0]-heights[1])<0.005 and absf(heights[9]-heights[10])<0.016,
		"2 m apron at x %.1f, measured footway / midpoint / toe / plaza %.3f / %.3f / %.3f / %.3f m"%[x,heights[0],heights[5],heights[9],heights[10]])
