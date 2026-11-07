extends Control

# Red arcs around screen centre pointing toward whoever hit the player. Each
# arc tracks its source position as the player turns, then fades.

const LIFETIME := 1.6
const RADIUS := 128.0
const HALF_ARC := 0.3
const MAX_MARKS := 6

var _marks: Array[Dictionary] = []

func _ready() -> void:
	name = "DamageDirection"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func add_source(world_position: Vector3, strength: float = 1.0) -> void:
	# Merge repeat hits from the same spot instead of stacking arcs.
	for mark: Dictionary in _marks:
		if (mark.position as Vector3).distance_to(world_position) < 1.5:
			mark.position = world_position
			mark.life = LIFETIME
			mark.strength = maxf(float(mark.strength), strength)
			return
	if _marks.size() >= MAX_MARKS:
		_marks.pop_front()
	_marks.append({"position": world_position, "life": LIFETIME, "strength": clampf(strength, 0.3, 1.0)})

func clear() -> void:
	_marks.clear()
	queue_redraw()

func _process(delta: float) -> void:
	if _marks.is_empty():
		return
	for mark: Dictionary in _marks:
		mark.life = float(mark.life) - delta
	_marks = _marks.filter(func(mark: Dictionary) -> bool: return float(mark.life) > 0.0)
	queue_redraw()

func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var center := size * 0.5
	var inverse := camera.global_transform.affine_inverse()
	for mark: Dictionary in _marks:
		var local: Vector3 = inverse * (mark.position as Vector3)
		# 0 is straight ahead, positive is to the right; screen up is ahead.
		var bearing := atan2(local.x, -local.z)
		var screen_angle := bearing - PI * 0.5
		var fade := clampf(float(mark.life) / LIFETIME, 0.0, 1.0)
		var alpha := fade * fade * float(mark.strength)
		draw_arc(center, RADIUS, screen_angle - HALF_ARC, screen_angle + HALF_ARC, 24, Color(0, 0, 0, alpha * 0.45), 12.0, true)
		draw_arc(center, RADIUS, screen_angle - HALF_ARC, screen_angle + HALF_ARC, 24, Color(0.95, 0.12, 0.08, alpha * 0.9), 8.0, true)
		var tip_dir := Vector2(cos(screen_angle), sin(screen_angle))
		var side := Vector2(-tip_dir.y, tip_dir.x)
		var base := center + tip_dir * (RADIUS + 8.0)
		draw_colored_polygon(PackedVector2Array([
			base + tip_dir * 14.0, base + side * 9.0, base - side * 9.0,
		]), Color(0.95, 0.12, 0.08, alpha))
