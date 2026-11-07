extends Control

# Four-tick crosshair whose gap follows weapon spread, plus hit and kill
# markers. Ticks hide while aiming; markers still show so ADS hits register.

const TICK_LENGTH := 7.0
const TICK_WIDTH := 2.0
const MIN_GAP := 5.0
const HIT_TIME := 0.16
const KILL_TIME := 0.42
const INK := Color(0.0, 0.0, 0.0, 0.55)
const TICK := Color(0.93, 0.96, 0.93, 0.92)
const HIT := Color(1.0, 1.0, 1.0)
const KILL := Color(1.0, 0.28, 0.22)

var ticks_visible := true
var _gap := MIN_GAP
var _target_gap := MIN_GAP
var _hit := 0.0
var _kill := 0.0

func _ready() -> void:
	name = "TacticalCrosshair"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_spread(spread_radians: float, camera_fov_degrees: float) -> void:
	# Convert cone half-angle to pixels at the current vertical FOV.
	var half_height := get_viewport_rect().size.y * 0.5
	var pixels := tan(spread_radians) * half_height / maxf(tan(deg_to_rad(camera_fov_degrees) * 0.5), 0.01)
	_target_gap = clampf(MIN_GAP + pixels, MIN_GAP, 90.0)

func show_hit(kill: bool = false) -> void:
	if kill:
		_kill = KILL_TIME
	_hit = HIT_TIME

func _process(delta: float) -> void:
	_gap = lerpf(_gap, _target_gap, minf(1.0, delta * 18.0))
	_hit = maxf(0.0, _hit - delta)
	_kill = maxf(0.0, _kill - delta)
	queue_redraw()

func _draw() -> void:
	var center := (size * 0.5).round()
	if ticks_visible:
		for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var a := center + dir * _gap
			var b := center + dir * (_gap + TICK_LENGTH)
			draw_line(a - dir, b + dir, INK, TICK_WIDTH + 2.0)
			draw_line(a, b, TICK, TICK_WIDTH)
		draw_circle(center, 2.0, INK)
		draw_circle(center, 1.1, TICK)
	if _hit <= 0.0 and _kill <= 0.0:
		return
	var killing := _kill > 0.0
	var life := (_kill / KILL_TIME) if killing else (_hit / HIT_TIME)
	var color := KILL if killing else HIT
	color.a = clampf(life * 1.6, 0.0, 1.0)
	# Markers pop outward slightly as they fade.
	var inner := 7.0 + (1.0 - life) * 4.0
	var outer := inner + (11.0 if killing else 8.0)
	var width := 3.0 if killing else 2.0
	for diagonal: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var d := diagonal.normalized()
		draw_line(center + d * inner, center + d * outer, Color(0, 0, 0, color.a * 0.5), width + 2.0)
		draw_line(center + d * inner, center + d * outer, color, width)
