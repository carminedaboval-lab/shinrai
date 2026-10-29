extends RefCounted
## Original Shinrai handling balance. Independent from locomotion stamina.
## The player applies rotation_offset to its sight camera before resolving shots.
const MAX_VALUE := 100.0
const REFERENCE_MASS_KG := 3.25
const READY_DRAIN := 0.50
const AIM_DRAIN := 2.0
const LOWERED_RECOVERY := 10.0
const FATIGUE_START := 70.0
const MAX_DRIFT_RADIANS := 0.0095993109 # 0.55 degrees, combined pitch/yaw.
const PHASE_PERIOD := TAU * 10.0

var value := MAX_VALUE
var max_value := MAX_VALUE
var mass_kg := REFERENCE_MASS_KG
var mass_multiplier := 1.0
var rotation_offset := Vector2.ZERO
var _phase := 0.0

func configure(spec: Dictionary) -> void:
	mass_kg = clampf(_number(spec.get("handling_total_mass_kg", spec.get("handling_mass_kg", REFERENCE_MASS_KG)), REFERENCE_MASS_KG), 0.5, 12.0)
	mass_multiplier = clampf(sqrt(mass_kg / REFERENCE_MASS_KG), 0.7, 1.7)
	# Equipping another weapon changes effort, never restores endurance.
	rotation_offset = Vector2.ZERO

func reset() -> void:
	value = MAX_VALUE
	max_value = MAX_VALUE
	rotation_offset = Vector2.ZERO
	_phase = 0.0

func advance(delta: float, context: Dictionary) -> void:
	value = clampf(_number(value, MAX_VALUE), 0.0, MAX_VALUE)
	max_value = MAX_VALUE
	if not is_finite(delta) or delta <= 0.0 or not bool(context.get("active", false)):
		rotation_offset = Vector2.ZERO
		return
	var aim := clampf(_number(context.get("aiming", 0.0), 0.0), 0.0, 1.0)
	var lowered := bool(context.get("lowered", false))
	var busy := bool(context.get("busy", false))
	var sprinting := bool(context.get("sprinting", false))
	var crouching := bool(context.get("crouching", false))
	var impaired := bool(context.get("arm_impaired", false))
	var cargo := clampf(_number(context.get("cargo_load_ratio", 0.0), 0.0), 0.0, 1.0)
	var food := clampf(_number(context.get("food", MAX_VALUE), MAX_VALUE), 0.0, MAX_VALUE)
	var water := clampf(_number(context.get("hydration", MAX_VALUE), MAX_VALUE), 0.0, MAX_VALUE)
	var energy := clampf(_number(context.get("energy", MAX_VALUE), MAX_VALUE), 0.0, MAX_VALUE)
	var deficit := (1.0 - minf(food, 35.0) / 35.0) * 0.20 + (1.0 - minf(water, 35.0) / 35.0) * 0.35 + (1.0 - minf(energy, 25.0) / 25.0) * 0.15
	# Sprinting/reload/inspection still occupy the arms. A lowered flag during one
	# of those actions cannot become an instant recovery shortcut.
	if lowered and not busy and not sprinting:
		var recovery := LOWERED_RECOVERY / (1.0 + deficit) * (0.75 if impaired else 1.0)
		value = minf(MAX_VALUE, value + recovery * delta)
	else:
		var effort := lerpf(READY_DRAIN, AIM_DRAIN, aim)
		if busy: effort = maxf(effort, 0.65)
		if sprinting: effort = maxf(effort, 0.80)
		effort *= mass_multiplier * (1.0 + deficit) * (1.30 if impaired else 1.0) * (1.0 + cargo * 0.20)
		if crouching and not sprinting: effort *= 0.82
		value = maxf(0.0, value - effort * delta)
	_phase = fposmod(_phase + fposmod(delta, PHASE_PERIOD), PHASE_PERIOD)
	if lowered or busy or sprinting or aim <= 0.0:
		rotation_offset = Vector2.ZERO
		return
	var fatigue := smoothstep(0.0, FATIGUE_START, FATIGUE_START - value)
	var amplitude := deg_to_rad(0.45) * fatigue * aim * (0.78 if crouching else 1.0) * (1.20 if impaired else 1.0)
	var wave := Vector2(sin(_phase * 1.3) * 0.80 + sin(_phase * 2.1) * 0.20, cos(_phase * 1.9) * 0.70 + sin(_phase * 2.7) * 0.30)
	rotation_offset = (wave * amplitude).limit_length(MAX_DRIFT_RADIANS)

static func _number(raw: Variant, fallback: float) -> float:
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT: return fallback
	var result := float(raw)
	return result if is_finite(result) else fallback
