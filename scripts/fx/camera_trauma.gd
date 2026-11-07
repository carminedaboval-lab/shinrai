extends Node

# Short camera shake for firing and taking hits. It moves the camera's h/v
# offsets only, so it never fights mouse look, recoil or lean, which all drive
# rotation. Trauma is squared so small kicks stay subtle and big hits read.

const MAX_OFFSET := 0.03
const DECAY := 2.4

var camera: Camera3D
var reduced_motion := false
var trauma := 0.0
var _time := 0.0

func bind(target_camera: Camera3D, use_reduced_motion: bool = false) -> void:
	camera = target_camera
	reduced_motion = use_reduced_motion

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func clear() -> void:
	trauma = 0.0
	if is_instance_valid(camera):
		camera.h_offset = 0.0
		camera.v_offset = 0.0

func _process(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	_time += delta
	if trauma <= 0.0:
		return
	trauma = maxf(0.0, trauma - delta * DECAY)
	var shake := trauma * trauma * (0.3 if reduced_motion else 1.0)
	camera.h_offset = (sin(_time * 57.0) + sin(_time * 23.0) * 0.6) * 0.62 * MAX_OFFSET * shake
	camera.v_offset = (cos(_time * 49.0) + sin(_time * 31.0) * 0.5) * 0.66 * MAX_OFFSET * shake
	if trauma <= 0.0:
		clear()
