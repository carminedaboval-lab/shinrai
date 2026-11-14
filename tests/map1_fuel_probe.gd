extends SceneTree
## Run with -- --model for the isolated sample, or without it to verify generated plots on
## Map 1. A graphical run also takes a player-height picture; headless only checks physics.
const Fuel := preload("res://scripts/map1/map1_fuel.gd")
const Map := preload("res://scripts/map1/map1_blockout.gd")
const OUT := "res://reports/map1_business/"
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func run() -> void:
	var sample := OS.get_cmdline_user_args().has("--model")
	var graphical := DisplayServer.get_name() != "headless"
	if graphical: DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	var group: Node3D
	var map
	if sample:
		group = Node3D.new()
		root.add_child(group)
		var station := Fuel.new()
		station.name = "Model"
		group.add_child(station)
		station.build(25,20)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-48,-33,0)
		sun.shadow_enabled = true
		root.add_child(sun)
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("#a5bbca")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color.WHITE
		env.ambient_light_energy = 0.65
		var sky := WorldEnvironment.new()
		sky.environment = env
		root.add_child(sky)
	else:
		map = Map.new()
		map.with_player = false
		root.add_child(map)
		group = map.get_node("FuelForecourts")
		for label: Label3D in map.labels: label.visible = false
	expect(group.get_child_count() > 0, "No forecourt built")
	await physics_frame
	await physics_frame
	var requested := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--plot="): requested = "Fuel " + arg.trim_prefix("--plot=")
	var nearest: Node3D
	var best := INF
	for station: Node3D in group.get_children():
		var space := station.get_world_3d().direct_space_state
		var pos := station.global_position
		var gap := Vector2(pos.x-112,pos.z-447).length()
		if gap < best and (requested.is_empty() or requested == str(station.name)):
			best = gap
			nearest = station
		var aisle := PhysicsRayQueryParameters3D.create(station.to_global(Vector3(0,1,10)), station.to_global(Vector3(0,1,-3)), 1)
		expect(space.intersect_ray(aisle).is_empty(), str(station.name)+" centre entrance blocked")
		for dx: float in [-3.25,3.25]:
			var lane := PhysicsRayQueryParameters3D.create(station.to_global(Vector3(dx,0.8,14)),station.to_global(Vector3(dx,0.8,-3)),1)
			expect(space.intersect_ray(lane).is_empty(), str(station.name)+" drive lane blocked")
		var head_x := 4.0 if station.station_style == 1 else 0.0
		var head := PhysicsRayQueryParameters3D.create(station.to_global(Vector3(head_x,1,0)), station.to_global(Vector3(head_x,5,0)),1)
		var hit := space.intersect_ray(head)
		expect(not hit.is_empty() and hit.collider == station.solid, str(station.name)+" missing canopy collision")
		if not sample:
			var reach := false
			for r: int in range(10,45):
				var road := station.to_global(Vector3(0,0,r))
				if map.world.road_at(road.x,road.z):
					reach = true
					break
			expect(reach, str(station.name)+" does not face a road")
		print("FUEL_PLOT ", station.name, " ", pos)
	if graphical and nearest != null:
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.global_position = nearest.to_global(Vector3(-8,1.68,20))
		if not sample:
			camera.position.y = float(map.ground_height(camera.position.x,camera.position.z)) + 1.68
		camera.look_at(nearest.to_global(Vector3(0,2.25,-1)))
		camera.fov = 63.0
		camera.make_current()
		if not sample:
			map.world.set_viewer(camera,null)
			map.world.cut()
		for i: int in 8: await process_frame
		if not sample:
			for i: int in 900:
				if not map.world.covered and map.world.fade <= 0: break
				await process_frame
		for i: int in (3 if sample else 35): await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		var path := OUT + ("fuel_model.jpg" if sample else ("fuel_street.jpg" if requested.is_empty() else requested.replace(" ","_")+".jpg"))
		expect(root.get_texture().get_image().save_jpg(ProjectSettings.globalize_path(path),0.92) == OK, "capture failed")
	print("FUEL_RESULT model=",sample," plots=",group.get_child_count()," failures=",failures)
	quit(1 if failures else 0)

