extends RefCounted
## Original whole-rig inspection presentation. The caller owns action eligibility,
## ammunition feedback and cancellation. This helper never moves ammunition.

const READ_FRACTION := 0.48
const RAISE_END := 0.25
const RETURN_START := 0.70

var active := false
var elapsed := 0.0
var duration := 1.90
var rotation_offset := Vector3.ZERO
var position_offset := Vector3.ZERO
var checked_weapon_id := ""
var profile := "rifle"
var _read_reported := false
var _target_rotation := Vector3.ZERO
var _target_position := Vector3.ZERO

func start(weapon_id: String, spec: Dictionary) -> bool:
	if active or weapon_id.is_empty():
		return false
	checked_weapon_id = weapon_id
	profile = str(spec.get("category", "rifle"))
	# Keep long barrels and their attached hands farther from the camera. The
	# posture parent carries the complete authored rig as a single assembly.
	match profile:
		"pistol":
			duration = 1.65
			_target_rotation = Vector3(deg_to_rad(-8.0), deg_to_rad(12.0), deg_to_rad(23.0))
			_target_position = Vector3(-0.025, 0.018, 0.015)
		"smg":
			duration = 1.75
			_target_rotation = Vector3(deg_to_rad(-6.0), deg_to_rad(10.0), deg_to_rad(19.0))
			_target_position = Vector3(-0.030, 0.015, 0.010)
		"dmr", "sniper_rifle":
			profile = "precision"
			duration = 2.00
			_target_rotation = Vector3(deg_to_rad(-4.0), deg_to_rad(6.0), deg_to_rad(12.0))
			_target_position = Vector3(-0.020, 0.008, -0.010)
		_:
			profile = "rifle"
			duration = 1.90
			_target_rotation = Vector3(deg_to_rad(-5.0), deg_to_rad(8.0), deg_to_rad(16.0))
			_target_position = Vector3(-0.025, 0.012, 0.0)
	elapsed = 0.0
	_read_reported = false
	rotation_offset = Vector3.ZERO
	position_offset = Vector3.ZERO
	active = true
	return true

func cancel() -> void:
	active = false
	elapsed = 0.0
	checked_weapon_id = ""
	_read_reported = false
	rotation_offset = Vector3.ZERO
	position_offset = Vector3.ZERO

func advance(delta: float) -> bool:
	if not active or not is_finite(delta) or delta <= 0.0:
		return false
	elapsed = minf(duration, elapsed + delta)
	var fraction := clampf(elapsed / duration, 0.0, 1.0)
	var report := not _read_reported and fraction + 0.000001 >= READ_FRACTION
	if report:
		_read_reported = true
	if elapsed + 0.000001 >= duration:
		elapsed = duration
		active = false
		rotation_offset = Vector3.ZERO
		position_offset = Vector3.ZERO
		return report
	var amount := smoothstep(0.0, RAISE_END, fraction) * (1.0 - smoothstep(RETURN_START, 1.0, fraction))
	rotation_offset = _target_rotation * amount
	position_offset = _target_position * amount
	return report
