extends "res://tests/probe_map1_world.gd"
## Walk past the lunch board, ramen shop and café, then both ways across the signal.
func _run() -> void:
	map=Blockout.new()
	map.with_player=false
	root.add_child(map)
	world=map.world
	player=RealPlayer.new()
	map.add_child(player)
	camera=player.camera
	world.set_viewer(camera,player)
	var edges: Array=map.street_edges.filter(func(e: Node3D)->bool: return e.get_meta("edge").name=="shop row")
	var boards: Node3D=map.get_node_or_null("ShopRowBoards")
	_check(edges.size()==2 and boards!=null and boards.get_child_count()==2,"exported shop row and both businesses' pavement boards installed")
	if failed:
		quit(1)
		return
	var cross_x:=-269.4
	check_paving_surfaces()
	await check_west_turns()
	await check_east_ramps()
	_check(map.has_node("ShopRowSignals/North") and map.has_node("ShopRowSignals/South"),"opposing pedestrian heads fitted to the original mapped signal posts")
	for edge: Node3D in map.street_edges:
		if not edge.has_node("Asphalt"): continue
		var asphalt: Mesh=edge.get_node("Asphalt").mesh
		for i: int in asphalt.get_surface_count():
			var material: ShaderMaterial=asphalt.surface_get_material(i)
			var ours: bool=edge.get_meta("edge").name=="shop row"
			_check((material.get_shader_parameter("shop_row_paint")==true)==ours,"paint restricted to shop row: "+str(edge.name)+" surface "+str(i))
			if ours:
				var s: float=material.get_shader_parameter("crossing_s")
				_check(absf(edge.at(s,0).x-cross_x)<0.1,"crosswalk lies west of the two signal posts")
	await _put(map.on_ground(-432,-456.0,0.35),Vector3.RIGHT)
	for name_: String in ["LunchMenu","RamenHours"]:
		var signboard: Node3D=boards.get_node(name_)
		var x:=signboard.global_position.x
		_check(signboard.global_position.z < -457.3,"board stands clear of the through path: "+name_)
		_check(await _drive([map.on_ground(x,-456.0),map.on_ground(x,signboard.global_position.z+0.95)],false,45),"walked up to read "+name_)
		var index: int=signboard.get_meta("business_box")
		var site: Dictionary=world.site(index)
		var door_x: float=site.spec.doors[0].at
		var drain:=map.get_node_or_null(name_+"Drain") as MeshInstance3D
		var flush:=false
		var gap:=INF
		if drain!=null:
			var points: PackedVector3Array=drain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			flush=points.size()>0
			var inverse: Transform3D=site.frame.affine_inverse()
			var sampled:={}
			for p: Vector3 in points:
				var at:=drain.to_global(p)
				var local:=inverse*at
				gap=minf(gap,absf(local.x-door_x))
				var cell:=Vector2i(roundi(at.x*8),roundi(at.z*16))
				if sampled.has(cell): continue
				sampled[cell]=true
				var ground: Vector3=map.on_ground(at.x,at.z)
				var relief:=at.y-ground.y-floor_offset(ground)
				if relief < -0.001 or relief>0.007: flush=false
		_check(flush and gap>=0.84,"slotted drain follows the paving beside %s and leaves its doorway clear (nearest metal %.2f m from centre)"%[name_,gap])
		var outside: Vector3=site.frame*Vector3(door_x,0,site.door_z-1.65)
		var ok:=await _drive([map.on_ground(x,-456.0),map.on_ground(outside.x,-456.0),outside],false,8)
		var door=world.houses[index].door("front") if world.houses.has(index) else null
		_check(ok and door!=null and door.interaction_distance(player)<INF,"shop door still reachable beside "+name_)
		if ok and door!=null:
			var opened: bool=door.interact(player)
			if not opened and door.locked: opened=door.open_with_chip(player)
			await _settle(1.3)
			var inside: Vector3=site.frame*Vector3(door_x,0,site.door_z+0.65)
			_check(opened and await _drive([inside],false,8),"walked through the actual threshold into "+name_)
			_check(await _drive([outside],false,8),"walked back out over the threshold at "+name_)
		_check(await _drive([map.on_ground(outside.x,-456.0)],false,8),"clear return to the walking strip from "+name_)
	_check(await _drive([map.on_ground(player.global_position.x,-456.0),map.on_ground(-315.98,-456.0),map.on_ground(cross_x,-456.0)],true,35),"walked past the café to the crossing")
	_check(await _drive([map.on_ground(cross_x,-439.5)],false,10),"reached the opposite pavement by the zebra")
	_check(await _drive([map.on_ground(cross_x,-456.0)],false,10),"crossed back to the shop pavement")
	if OS.get_cmdline_user_args().has("--check-ramps"):
		for edge: Node3D in edges:
			print("FORECOURT side=",edge.side," depth=",edge.forecourt)
			var s: float=edge.along_of(Vector3(cross_x,0,-448))
			for delta: float in [-1.55,0.0,1.55]:
				var point: Vector3=edge.at(s+delta,edge.half+0.08)
				var lift:=floor_offset(point)
				_check(lift >= -0.005 and lift<0.045,"crossing kerb at x %.1f, z %.1f measures %.3f m"%[point.x,point.z,lift])
			var regular:=floor_offset(edge.at(s-6.0,edge.half+0.08))
			_check(regular>0.105 and regular<0.16,"ordinary kerb retained on side %.0f (%.3f m)"%[edge.side,regular])
		for x: float in [-376.0,-347.0,-314.0]:
			var walk:=floor_offset(map.on_ground(x,-456.97))
			var seam:=floor_offset(map.on_ground(x,-457.03))
			var mid:=floor_offset(map.on_ground(x,-458.25))
			var end:=floor_offset(map.on_ground(x,-459.45))
			_check(absf(walk-0.13)<0.012 and absf(seam-walk)<0.005 and absf(mid-0.071)<0.012 and absf(end-0.014)<0.01,"pavement, seam, midpoint and shop edge at x %.1f measure %.3f / %.3f / %.3f / %.3f m"%[x,walk,seam,mid,end])
		for board: Node3D in boards.get_children():
			var pos:=board.global_position
			var ground: Vector3=map.on_ground(pos.x,pos.z)
			var contact:=floor_offset(ground,(board.get_node("Body") as StaticBody3D).get_rid())
			_check(contact>0.012 and absf(pos.y-ground.y-contact)<0.012,"feet of %s meet the slope (surface %.3f m; gap %.3f m)"%[board.name,contact,pos.y-ground.y-contact])
	print("SHOP_ROW_WALK passed=",passed," failed=",failed)
	quit(1 if failed else 0)

func check_east_ramps() -> void:
	for z: float in [-456.0,-440.0]:
		var start: Vector3 = map.on_ground(-235.0,z)
		var beyond: Vector3 = map.on_ground(-226.0,z)
		await _put(start+Vector3.UP*0.3,Vector3.RIGHT)
		_check(await _drive([beyond],false,6),"walked down the east ramp at z %.1f"%z)
		_check(await _drive([start],false,6),"walked up the east ramp at z %.1f"%z)
		for across: float in [-0.72,0.0,0.72]:
			var heights := PackedFloat32Array()
			for x: float in [-233.5,-232.8,-231.65,-231.55]:
				heights.append(floor_offset(map.on_ground(x,z+across)))
			var correct := true
			var expected := PackedFloat32Array([0.13,0.08,0.03,0.0])
			for i in expected.size():
				if absf(heights[i]-expected[i])>0.012: correct=false
			_check(correct,"east ramp at z %.2f, heights from pavement to ground %s"%[z+across,heights])

func floor_offset(point: Vector3, ignore:=RID()) -> float:
	var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.45,point-Vector3.UP*0.6,1)
	var excluded: Array[RID]=[player.get_rid()]
	if ignore.is_valid(): excluded.append(ignore)
	query.exclude=excluded
	var hit:=root.world_3d.direct_space_state.intersect_ray(query)
	return hit.position.y-point.y if not hit.is_empty() else -INF

## Follow the clear side of each signal post with the actual player, then turn back.
func check_west_turns() -> void:
	for sign_z: float in [-1.0,1.0]:
		var cz:=-448.0+12.5*sign_z
		var route: Array=[map.on_ground(-460.0,cz-sign_z*4.2)]
		for i in range(9):
			var angle:=PI*0.5*i/8.0
			route.append(map.on_ground(-462.5-4.2*sin(angle),cz-sign_z*4.2*cos(angle)))
		await _put(route[0]+Vector3.UP*0.3,Vector3.LEFT)
		_check(await _drive(route.slice(1),false,4),"walk around west signal post to the ring, z %.1f"%cz)
		route.reverse()
		_check(await _drive(route.slice(1),false,4),"walk around west signal post back to shops, z %.1f"%cz)

## Verify what Godot will draw (including overrides), not merely that a material file exists.
func check_paving_surfaces() -> void:
	var foot:=preload("res://scripts/map1/map1_shop_footway.tres")
	var concrete:=preload("res://scripts/map1/map1_shop_forecourt.tres")
	for edge: Node3D in map.street_edges:
		var row: bool=edge.get_meta("edge").name=="shop row"
		var west: bool=edge.get_meta("edge").name=="shop row west"
		var direction: float=-1.0 if west else 1.0
		var counts:=[0,0]
		var spans:=[0.0,0.0]
		var metric:=true
		for item in edge.find_children("*","MeshInstance3D",true,false):
			var node:=item as MeshInstance3D
			for i: int in node.mesh.get_surface_count():
				var mat:=node.get_active_material(i)
				if mat!=foot and mat!=concrete: continue
				var type:=0 if mat==foot else 1
				counts[type]+=1
				var a:=node.mesh.surface_get_arrays(i)
				var pts: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
				var uvs: PackedVector2Array=a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
				if pts.size()!=uvs.size() or pts.size()<3:
					metric=false
					continue
				var uv0:=uvs[0]
				var p0:=node.to_global(pts[0])
				var lo:=uv0.y
				var hi:=uv0.y
				for j: int in pts.size():
					var p:=node.to_global(pts[j])
					var du:=uvs[j]-uv0
					if absf(du.y-direction*(p.x-p0.x))>0.025 or absf(du.x-direction*(p.z-p0.z)*float(edge.side))>0.025: metric=false
					lo=minf(lo,uvs[j].y)
					hi=maxf(hi,uvs[j].y)
				spans[type]=maxf(spans[type],hi-lo)
		if row:
			var shops: bool=edge.forecourt>0
			_check(counts[0]>0 and spans[0]>160 and (counts[1]>0 and spans[1]>160 if shops else counts[1]==0) and metric,
				"DETAIL metre-scale pavement and forecourt on %s: surfaces %s spans %s UV valid %s"%[edge.name,counts,spans,metric])
		elif west:
			_check(counts[0]>0 and spans[0]>=24.4 and metric and counts[1]==0 and is_zero_approx(edge.forecourt),
				"west extension carries metre-scale footway paving and no shop forecourt: "+str(edge.name))
		else:
			_check(counts==[0,0],"shop paving not applied to "+str(edge.name))
