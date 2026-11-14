extends "res://tests/probe_map1_world.gd"
## A physics walk alone passes on the ground picture. Also inspect the drawn
## asphalt triangles to catch a missing strip or two surfaces in the same place.
const Asphalt := preload("res://scripts/map1/map1_trial_asphalt.gdshader")

func _run() -> void:
	map = Blockout.new()
	map.with_player = false
	root.add_child(map)
	world = map.world
	player = RealPlayer.new()
	map.add_child(player)
	camera = player.camera
	world.set_viewer(camera,player)
	var triangles := road_triangles()
	var link_gutters := link_gutter_triangles()
	for x: float in [81.5,90.5]:
		for side: float in [-1,1]:
			var missing := 0
			var stacked := 0
			var off_grade := 0
			for across: float in [-1.21,0.073,1.14]:
				for out: float in [2.48,2.61,2.66,2.85,3.51,4.24,5.03]:
					var ground: Vector3 = map.on_ground(x+across,448.23+side*out)
					var hits := 0
					for i in range(0,triangles.size(),3):
						var hit = Geometry3D.ray_intersects_triangle(ground+Vector3.UP,Vector3.DOWN,triangles[i],triangles[i+1],triangles[i+2])
						if hit==null: continue
						hits += 1
						if absf(hit.y-ground.y-0.012)>0.01: off_grade += 1
					if hits==0: missing += 1
					if hits>1: stacked += 1
			var label := "x %.1f, side %.0f"%[x,side]
			_check(missing==0 and stacked==0 and off_grade==0,"asphalt across the join and into the street at %s: %d missing, %d overlapping, %d off grade"%[label,missing,stacked,off_grade])
			var main: Vector3 = map.on_ground(x,448.23+side*0.9)
			var branch: Vector3 = map.on_ground(x,448.23+side*5.1)
			await _put(main+Vector3.UP*0.20)
			_check(await _drive([branch,main],false,6),"player walked into the side street and returned at "+label)
	for edge: Node3D in map.street_edges:
		if edge.get_meta("edge").name!="homes street trial": continue
		for corner: Dictionary in edge.corners:
			# Beyond the end of the gutter the full throat should be paved,
			# including the narrow strip previously occupied by the gutter.
			var missing := PackedFloat32Array()
			for offset: float in [0.015,0.045,0.085,0.155,0.205,0.225,0.255,0.305]:
				var p: Vector3=edge.at(corner.mouth+corner.dir*offset,edge.half+edge.footway_wide+0.67)
				var built_gutter: bool = corner.get("deep",3.0)==0.0 and offset<0.22
				var road_hits := surface_hits(p,triangles)
				var gutter_hits: Array = surface_hits(p,link_gutters) if built_gutter else []
				if built_gutter:
					if not road_hits.is_empty() or gutter_hits.size()!=1 or absf(gutter_hits[0]-lerpf(0.008,0.02,offset/0.22))>0.004: missing.append(offset)
				elif road_hits.size()!=1: missing.append(offset)
			_check(missing.is_empty(),"correct asphalt or continuing concrete gutter at %.2f m on side %.0f, incorrect offsets %s"%[corner.mouth,edge.side,missing])
	print("SIDE_STREET_DONE passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)

func surface_hits(p: Vector3, tris: PackedVector3Array) -> Array[float]:
	var hits: Array[float] = []
	for i in range(0,tris.size(),3):
		var hit = Geometry3D.ray_intersects_triangle(p+Vector3.UP,Vector3.DOWN,tris[i],tris[i+1],tris[i+2])
		if hit!=null: hits.append(hit.y-p.y)
	return hits

func link_gutter_triangles() -> PackedVector3Array:
	var points := PackedVector3Array()
	for edge: Node3D in map.street_edges:
		if edge.get_meta("edge").name=="homes link lane":
			var node: MeshInstance3D=edge.get_node("Edge")
			points.append_array(node.global_transform*node.mesh.get_faces())
	return points

func road_triangles(z_min := 442.0,z_max := 454.0) -> PackedVector3Array:
	var points := PackedVector3Array()
	for node: MeshInstance3D in map.find_children("*","MeshInstance3D",true,false):
		if node.mesh==null: continue
		var bounds: AABB = node.global_transform*node.get_aabb()
		if bounds.end.x<79 or bounds.position.x>94 or bounds.end.z<z_min or bounds.position.z>z_max: continue
		for surface in node.mesh.get_surface_count():
			var material := node.get_active_material(surface) as ShaderMaterial
			if material==null or material.shader!=Asphalt: continue
			var arrays := node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices = arrays[Mesh.ARRAY_INDEX]
			if indices==null or indices.is_empty():
				points.append_array(node.global_transform*vertices)
			else:
				for index: int in indices:
					points.append(node.to_global(vertices[index]))
	return points
