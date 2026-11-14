extends SceneTree
const Map := preload("res://scripts/map1/map1_blockout.gd")
const Rules := preload("res://scripts/map1/map1_house_rules.gd")
const OUT := "res://reports/map1_business/"
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	var map := Map.new()
	map.with_player=false
	root.add_child(map)
	for l: Label3D in map.labels: l.visible=false
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	map.world.set_viewer(cam,null)
	var views := {}
	var distance := {}
	for b: Dictionary in map.data.businesses:
		if Rules.floors_of(map.data.boxes[b.box])>2: continue
		var site: Dictionary=map.world.site(int(b.box))
		if not site.ok or not site.on_road: continue
		var here := Vector2(b.x,b.z).distance_to(Vector2(112,447))
		var key := str(b.what)
		if here < float(distance.get(key,INF)):
			distance[key]=here
			views[key]=site
	var err := 0
	for key: String in ["convenience store","grocer","sushi counter","ramen shop"]:
		if not views.has(key): continue
		var s: Dictionary=views[key]
		var target: Vector3 = s.frame*Vector3(s.size.x*0.5,1.85,0)
		var street: Vector3 = target + s.street_out*minf(11.0,maxf(6.4,target.distance_to(s.street_point)+2.0)) - s.street_along*1.6
		cam.global_position=map.on_ground(street.x,street.z,1.68)
		cam.look_at(target)
		cam.fov=64
		map.world.cut()
		for i: int in 4: await process_frame
		for i: int in 900:
			if not map.world.covered and map.world.fade<=0: break
			await process_frame
		for i: int in 45: await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		var path := ProjectSettings.globalize_path(OUT+"kit_"+key.replace(" ","_")+".jpg")
		if root.get_texture().get_image().save_jpg(path,0.93)!=OK: err+=1
		print("KIT_TENANT ",key," box=",s.index," level=",map.world.level_of(s.index)," features=",s.get("business",{})," ",path)
	quit(1 if err else 0)

