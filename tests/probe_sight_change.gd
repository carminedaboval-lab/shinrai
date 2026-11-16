extends SceneTree
## Did the world really call a visible building hidden, or was its answer simply old?
##   godot --headless --path . --script res://tests/probe_sight_change.gd
##
## One run of the world suite saw box 4324 swap from grey box to house 39 frames after a cut,
## at 212 m and 32 degrees off the view's centre, while the world had called it HIDDEN. It has
## not happened again, so this stands in the same place deliberately rather than waiting for it:
## the cut at (93, 416) facing +z, then turned right round, which is what the suite does.
##
## Two explanations were left after reading `look_points()` (which does sample roof shadows —
## my first diagnosis was wrong):
##   1. the probe's open sight lines clear something all twenty-one of the world's points do not;
##   2. the world was right when it answered, and the view turned before the swap landed.
## They are told apart by WHEN, so that is what this records: the verdict and the frame it was
## given on, against the frame the building actually changed and where the eye was pointing then.
## Prints SIGHT_ lines and SIGHT_DONE.

const Blockout := preload("res://scripts/map1/map1_blockout.gd")
const WATCH := 4324
const CUT_AT := Vector2(93.0, 416.0)

var map: Node3D
var world: Node3D
var camera: Camera3D
var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("SIGHT_%s %s" % ["PASS" if ok else "FAIL", text])


func _frames(many: int) -> void:
	for i: int in many: await physics_frame


## Where the eye is and which way it looks, as the world sees it.
func _put(at: Vector3, facing: Vector3) -> void:
	camera.global_position = at + Vector3.UP * 1.6
	camera.look_at(at + Vector3.UP * 1.6 + facing, Vector3.UP)
	world.set_viewer(camera, null)


func _run() -> void:
	map = Blockout.new()
	map.with_player = false
	root.add_child(map)
	await _frames(4)
	world = map.world
	camera = Camera3D.new()
	root.add_child(camera)
	# Far away first, so everything near the cut has to be made anew, exactly as the suite does.
	await _put(map.on_ground(-600.0, -100.0, 0.2), Vector3(1, 0, 0))
	await _frames(20)
	var here: Vector3 = map.on_ground(CUT_AT.x, CUT_AT.y, 0.1)
	await _put(here, Vector3(0, 0, 1))
	var cut_frame := Engine.get_physics_frames()
	# Let the cut settle the way the suite does, then turn right round.
	await _frames(2)
	await _put(here, Vector3(0, 0, -1))
	var turned := Engine.get_physics_frames()
	# Watch the building frame by frame: when does the world answer, and when does it change?
	var answered := -1
	var answer := false
	var changed := -1
	var was: int = world.level_of(WATCH)
	var off_centre := 0.0
	for i: int in 240:
		await physics_frame
		var now: int = world.level_of(WATCH)
		# The world's own verdict, asked with the world's own eye, this frame.
		var verdict: bool = world._hidden(WATCH)
		if answered < 0 or verdict != answer:
			answered = Engine.get_physics_frames()
			answer = verdict
		if now != was and changed < 0:
			changed = Engine.get_physics_frames()
			var to: Vector3 = Vector3(map.data.boxes[WATCH][0], 0.0, map.data.boxes[WATCH][2])
			var look := -camera.global_transform.basis.z
			var at := (to - camera.global_position)
			at.y = 0.0
			off_centre = rad_to_deg(look.normalized().angle_to(at.normalized()))
			print("SIGHT_INFO box %d changed from %d to %d on frame %d, %d frames after the turn, %.0f m away, %.0f degrees off centre; the world's answer that frame: %s" % [
				WATCH, was, now, changed, changed - turned, at.length(), off_centre, "HIDDEN" if verdict else "in sight"])
			was = now
	print("SIGHT_INFO cut on frame %d, turned on %d; the world's last answer for box %d was %s, settled on frame %d" % [
		cut_frame, turned, WATCH, "HIDDEN" if answer else "in sight", answered])
	# The fault is a building changing **while it is in front of you**. A change at 92 degrees
	# off centre is behind your shoulder and is exactly what the world is supposed to do, so a
	# check that fails on any post-turn change would fail on correct behaviour — which the
	# first version of this line did. The original sighting was 32 degrees off centre, inside
	# the view, so that is the condition: in the cone, and the world calling it hidden.
	var in_view: bool = changed >= 0 and off_centre < 35.0
	_check(not in_view, "no change happened while the building was inside the view cone: %s" % [
		"none seen" if changed < 0 else "changed %.0f degrees off centre, %s" % [off_centre, "which is outside it" if off_centre >= 35.0 else "INSIDE it"]])
	print("SIGHT_DONE passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)
