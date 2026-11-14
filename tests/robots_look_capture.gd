extends SceneTree
## Real pictures of the recharge station and its robots in the test yard, drawn by the
## graphics card:
##   godot --path . --resolution 1600x900 --fixed-fps 60 --script res://tests/robots_look_capture.gd
## Writes reports/robots/look_<view>.jpg. The headless probe (tests/probe_robots.gd) proves
## the rules; this shows how the station, its lights and the robots really look.
## Camera places are in the station's own metres: x along the row of bays, y up, z out in
## front of it (so z = 30 is 30 m down the street it faces).

const YardWorld := preload("res://scripts/test_yard/yard_world.gd")
const Station := preload("res://scripts/robots/station.gd")
const Robot := preload("res://scripts/robots/robot.gd")

var yard: Node3D
var station: Node3D
var camera: Camera3D
## Stands in for the player: the station measures its distance to this point.
var visitor: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/robots"))
	yard = YardWorld.new()
	root.add_child(yard)
	yard.build()
	station = yard.get_node("RechargeStation")
	camera = Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	visitor = Node3D.new()
	yard.add_child(visitor)
	station.track(visitor)
	var robot: CharacterBody3D = station.robots[0]
	var bay: Vector3 = station.bay_point(robot.bay)
	_stand(34.0)
	await _wait(1.0)

	# The station as it is first seen, from the street.
	await _shot("street_30m", Vector3(2.5, 1.7, 30.0), Vector3(0.0, 1.9, 0.0), 38.0)
	await _shot("street_30m_wide", Vector3(2.5, 1.7, 30.0), Vector3(0.0, 2.4, 0.0), 62.0)
	# The bays close up, with a robot standing in one.
	await _shot("bays_close", Vector3(bay.x + 1.9, 1.65, 4.3), Vector3(bay.x + 0.3, 1.25, 0.0), 50.0)
	await _shot("robot_in_bay", Vector3(bay.x + 0.9, 1.6, 2.6), Vector3(bay.x, 1.2, 0.0), 45.0)
	await _shot("robot_at_10m", Vector3(bay.x + 1.0, 1.7, 10.0), Vector3(bay.x, 1.2, 0.0), 30.0)
	# The lights, calm: the visitor is 20 m away.
	_stand(20.0)
	await _wait(1.5)
	await _shot("lights_calm", Vector3(-0.6, 1.7, 8.0), Vector3(0.2, 1.5, 0.0), 48.0)
	# The lights in the warning: the visitor is 9 m away. Taken at the bright end of a pulse
	# and again at the dim end.
	_stand(9.0)
	await _wait(1.5)
	await _until(func() -> bool: return station.light_energy > Station.PULSE_HIGH - 0.05)
	await _shot("lights_warning", Vector3(-0.6, 1.7, 8.0), Vector3(0.2, 1.5, 0.0), 48.0, true)
	await _until(func() -> bool: return station.light_energy < Station.PULSE_LOW + 0.05)
	await _shot("lights_warning_dim", Vector3(-0.6, 1.7, 8.0), Vector3(0.2, 1.5, 0.0), 48.0, true)
	# A robot stepping out: the visitor comes to 5.5 m, and the picture is taken mid-step.
	_stand(5.5)
	await _until(func() -> bool: return robot.state == Robot.State.WAKING and robot.state_time > 1.25)
	await _shot("robot_stepping_out", Vector3(bay.x + 2.4, 1.5, 3.4), Vector3(bay.x, 1.05, 0.7), 48.0, true)
	await _until(func() -> bool: return robot.state == Robot.State.CHASE and robot.state_time > 0.7)
	var walking: Vector3 = station.to_local(robot.global_position)
	await _shot("robot_walking", walking + Vector3(2.6, 1.5, 2.2), walking + Vector3(0.0, 1.05, 0.4), 48.0, true)
	# A downed robot.
	robot.take_damage(Robot.HEALTH, null)
	await _wait(Robot.FALL_SECONDS * 0.45)
	var falling: Vector3 = station.to_local(robot.global_position)
	await _shot("robot_falling", falling + Vector3(2.8, 1.4, 1.6), falling + Vector3(0.0, 0.8, 0.6), 50.0, true)
	await _wait(Robot.FALL_SECONDS)
	var lying: Vector3 = station.to_local(robot.body_centre())
	await _shot("robot_down", lying + Vector3(2.4, 1.6, 2.2), lying + Vector3(0.0, 0.15, 0.0), 50.0)
	await _shot("robot_down_from_street", Vector3(lying.x + 1.0, 1.7, lying.z + 9.0), lying + Vector3(0.0, 0.6, -0.8), 40.0)
	print("ROBOT_LOOK_DONE")
	quit(0)


## Puts the visitor `metres` in front of the station.
func _stand(metres: float) -> void:
	visitor.global_position = station.to_global(Vector3(0.0, 0.0, Station.PLINTH_DEPTH * 0.5 + metres))
	station.track(visitor)


func _wait(seconds: float) -> void:
	for i: int in int(seconds * 60.0):
		await physics_frame
		await process_frame


func _until(done: Callable, limit: float = 12.0) -> void:
	for i: int in int(limit * 60.0):
		if done.call(): return
		await physics_frame
		await process_frame


## One picture: camera at `from`, looking at `at`, both in the station's own metres. With
## `frozen` the station and its robots are held still while the picture is taken, so a
## moment in the middle of a movement is what is drawn.
func _shot(view: String, from: Vector3, at: Vector3, fov: float, frozen: bool = false) -> void:
	if frozen: station.process_mode = Node.PROCESS_MODE_DISABLED
	camera.global_position = station.to_global(from)
	camera.look_at(station.to_global(at))
	camera.fov = fov
	for i: int in 20: await process_frame
	var path := ProjectSettings.globalize_path("res://reports/robots/look_%s.jpg" % view)
	root.get_texture().get_image().save_jpg(path, 0.92)
	if frozen: station.process_mode = Node.PROCESS_MODE_INHERIT
	print("ROBOT_LOOK ", path)
