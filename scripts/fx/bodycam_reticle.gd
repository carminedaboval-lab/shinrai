extends CanvasLayer
## Small aiming mark for the bodycam view. It sits on the point the shot will
## land on (the same point the game fires at), so it follows the gun as it is
## moved around the picture, and it stays honest away from the centre because it
## goes through the same fisheye mapping as the picture itself.
##
## The bodycam rig calls place() once a frame, after it has set the lens shader:
##   reticle.place(lens, hit_point, half_fov_h, tan_src_h, aspect, lens_strength, show, aiming)
## See scripts/fx/bodycam_lens.gdshader for the mapping being inverted here.

var size_px := 9.0                 # radius of the ring at rest, in screen pixels
var aim_size_px := 5.0             # tighter while aiming
var color := Color(1.0, 1.0, 1.0, 0.72)
var outline := Color(0.0, 0.0, 0.0, 0.45)
var follow_rate := 28.0            # 1/s; takes the jitter out of the hit point without lagging the gun

var _mark: Control
var _target := Vector2.ZERO
var _shown := Vector2.ZERO
var _alpha := 0.0
var _want := false
var _aiming := 0.0
var _snap := true

func _ready() -> void:
	name = "BodycamReticle"
	layer = 0                      # above the lens pass (-1), under the HUD layers
	_mark = Control.new()
	_mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.draw.connect(_draw_mark)
	add_child(_mark)
	visible = false

## Where on the screen (pixels) a world point appears after the lens pass.
## Returns Vector2.INF when the point is behind the lens or outside the picture.
static func screen_point(lens: Camera3D, world_point: Vector3, half_fov_h: float, tan_src_h: float, aspect: float, strength: float, view_size: Vector2) -> Vector2:
	if lens == null or lens.is_position_behind(world_point):
		return Vector2.INF
	# Position in the plain (rectilinear) render, as -1..1 across the width and
	# the same scale down the height, which is the shader's "p * k".
	var plain := lens.unproject_position(world_point)
	var q := Vector2(plain.x / view_size.x * 2.0 - 1.0, (plain.y / view_size.y * 2.0 - 1.0) / aspect)
	var q_len := q.length()
	if q_len < 1e-5:
		return view_size * 0.5
	# The shader maps an output radius r to a source radius
	#   q(r) = mix(tan(half_fov_h) * r, tan(min(r * half_fov_h, 1.55)), strength) / tan_src_h
	# which only grows with r, so find the r that gives this q by bisection.
	var k_lin := tan(half_fov_h) / tan_src_h
	var s := clampf(strength, 0.0, 1.0)
	var low := 0.0
	var high := 1.55 / maxf(half_fov_h, 0.01)
	for i in 24:
		var mid := (low + high) * 0.5
		var mapped := lerpf(k_lin * mid, tan(minf(mid * half_fov_h, 1.55)) / tan_src_h, s)
		if mapped < q_len:
			low = mid
		else:
			high = mid
	var p := q * ((low + high) * 0.5 / q_len)
	var uv := Vector2(0.5 + 0.5 * p.x, 0.5 + 0.5 * p.y * aspect)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return Vector2.INF
	return uv * view_size

func place(lens: Camera3D, world_point: Vector3, half_fov_h: float, tan_src_h: float, aspect: float, strength: float, show: bool, aiming: float) -> void:
	var view_size := get_viewport().get_visible_rect().size
	var at := screen_point(lens, world_point, half_fov_h, tan_src_h, aspect, strength, view_size) if show else Vector2.INF
	_want = show and at != Vector2.INF
	_aiming = clampf(aiming, 0.0, 1.0)
	if _want:
		_target = at
		if _snap or _alpha <= 0.01:
			_shown = at            # appear on the spot, do not slide in from the last place
			_snap = false

func _process(delta: float) -> void:
	_alpha = move_toward(_alpha, 1.0 if _want else 0.0, delta * (10.0 if _want else 6.0))
	visible = _alpha > 0.01
	if not visible:
		_snap = true
		return
	_shown = _shown.lerp(_target, 1.0 - exp(-follow_rate * delta))
	_mark.queue_redraw()

func _draw_mark() -> void:
	var radius := lerpf(size_px, aim_size_px, _aiming)
	var tint := Color(color.r, color.g, color.b, color.a * _alpha)
	var dark := Color(outline.r, outline.g, outline.b, outline.a * _alpha)
	# A thin ring with a centre point: readable on bright and dark ground alike
	# thanks to the dark edge, and small enough not to hide the target.
	_mark.draw_arc(_shown, radius + 1.0, 0.0, TAU, 40, dark, 3.0, true)
	_mark.draw_arc(_shown, radius, 0.0, TAU, 40, tint, 1.4, true)
	_mark.draw_circle(_shown, 2.2, dark)
	_mark.draw_circle(_shown, 1.3, tint)
