extends RefCounted

# Original Shinrai presentation tuning, not extracted firearm or GZW values.
# Only the viewmodel moves: input rotation and the authoritative camera stay
# immediate. The complete overlay is removed before precision ADS is ready.
const MAX_ANGLE := 0.027925268 # 1.6 degrees across yaw/pitch together.
const MAX_TRANSLATION := 0.004
const ADS_FADE_START := 0.35
const ADS_SETTLED := 0.90
const MAX_LOOK_RATE := 12.0

var mass_kg := 3.25
var rotation_offset := Vector3.ZERO
var position_offset := Vector3.ZERO
var _pending_look := Vector2.ZERO
var _lag := Vector2.ZERO

func configure(spec: Dictionary) -> void:
	var requested := float(spec.get("handling_total_mass_kg", spec.get("handling_mass_kg", 3.25)))
	mass_kg = clampf(requested, 0.5, 15.0) if is_finite(requested) else 3.25
	reset()

func add_look_delta(radians: Vector2) -> void:
	# x is applied camera yaw, y is applied camera pitch. Accumulate all mouse
	# and controller events so the effect does not depend on event frequency.
	if radians.is_finite():
		_pending_look = (_pending_look + radians).limit_length(PI)

func reset() -> void:
	_pending_look = Vector2.ZERO
	_lag = Vector2.ZERO
	rotation_offset = Vector3.ZERO
	position_offset = Vector3.ZERO

func advance(delta: float, aiming: float, allowed: bool = true) -> void:
	if not allowed or not is_finite(delta) or delta <= 0.0 or delta > 0.25 or not is_finite(aiming) or aiming >= ADS_SETTLED:
		reset()
		return
	var look_rate := (_pending_look / delta).limit_length(MAX_LOOK_RATE)
	_pending_look = Vector2.ZERO
	var lag_seconds := 0.010 + mass_kg * 0.0015
	var target := (-look_rate * lag_seconds).limit_length(MAX_ANGLE)
	var response_rate := 20.0 / sqrt(mass_kg / 3.25)
	# Exact first-order response for a constant angular velocity within a frame.
	_lag = _lag.lerp(target, 1.0 - exp(-response_rate * delta))
	var weight := 1.0 - smoothstep(ADS_FADE_START, ADS_SETTLED, clampf(aiming, 0.0, 1.0))
	rotation_offset = Vector3(_lag.y, _lag.x, _lag.x * 0.20) * weight
	position_offset = Vector3(-_lag.x * 0.12, _lag.y * 0.08, 0.0).limit_length(MAX_TRANSLATION) * weight
