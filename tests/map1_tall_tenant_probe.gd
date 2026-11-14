extends SceneTree
const Map := preload("res://scripts/map1/map1_blockout.gd")
const Rules := preload("res://scripts/map1/map1_house_rules.gd")
const OUT := "res://reports/map1_business/"
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var map := Map.new()
	map.with_player = false
	root.add_child(map)
	for l: Label3D in map.labels: l.visible=false
	var group: Node3D = map.get_node("TallShopfronts")
	var wanted := {}
	var coffee := 0
	var food := 0
	for b: Dictionary in map.data.businesses:
		var tall := Rules.floors_of(map.data.boxes[b.box]) > 2
		if tall or not bool(map.world.site(int(b.box)).ok):
			wanted[int(b.box)] = str(b.what)
			if tall and b.type=="restaurant": food+=1
	var errors := 0
	var signed_faces := 0
	var road := 0
	var views := {}
	var nearest := {}
	for f in group.get_children():
		if not wanted.has(f.building) or wanted.get(f.building)!=f.trade or f.blocks.is_empty(): errors+=1
		wanted.erase(f.building)
		if f.trade=="coffee shop": coffee+=1
		# Inspect the built geometry on the fascia and both perpendicular blade faces.
		# A missing/mirrored side leaves pedestrians approaching from one direction without a sign.
		var detail: MeshInstance3D = null
		for child in f.get_children():
			if child is MeshInstance3D: detail=child
			if child is Label3D: errors+=1
		var found := [false,false,false]
		if detail != null:
			var arrays:=detail.mesh.surface_get_arrays(0)
			var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			for i: int in verts.size():
				var v:=verts[i]
				if absf(v.z-0.262)<0.001 and absf(v.y-2.73)<0.17 and norms[i].z>0.99: found[0]=true
				for side: int in [-1,1]:
					if absf(v.x-(f.frontage*0.44+side*0.068))<0.001 and absf(v.z-0.49)<0.36 and absf(v.y-2.5)<0.16 and norms[i].x*side>0.99:
						found[1 if side<0 else 2]=true
		signed_faces+=found.count(true)
		if found.has(false):
			print("SIGN_FACE_MISSING ",f.building," ",found)
			errors+=1
		if f.street_reached:
			road+=1
			var gap: float = Vector2(f.position.x-112,f.position.z-447).length()
			if gap < float(nearest.get(f.trade,INF)):
				nearest[f.trade]=gap
				views[f.trade]=f
	if not wanted.is_empty() or not views.has("coffee shop") or not views.has("ramen shop"): errors+=1
	print("EXTERIOR_TENANTS built=",group.get_child_count()," food=",food," cafes=",coffee," road_found=",road," verified_sign_faces=",signed_faces," errors=",errors)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.make_current()
		map.world.set_viewer(cam,null)
		for key: String in ["coffee shop","ramen shop"]:
			if not views.has(key): continue
			var f: Node3D=views[key]
			var eye := f.to_global(Vector3(-1.5,0,8.8))
			cam.global_position=map.on_ground(eye.x,eye.z,1.68)
			cam.look_at(f.to_global(Vector3(0,3.25,0)))
			cam.fov=66
			map.world.cut()
			for i: int in 4: await process_frame
			for i: int in 900:
				if not map.world.covered and map.world.fade <=0: break
				await process_frame
			for i: int in 40: await process_frame
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
			var path := ProjectSettings.globalize_path(OUT+"tall_"+key.split(" ")[0]+".jpg")
			if root.get_texture().get_image().save_jpg(path,0.94)!=OK: errors+=1
			print("TALL_CAPTURE ",path," building=",f.get("building")," at=",f.position)
	quit(1 if errors else 0)

