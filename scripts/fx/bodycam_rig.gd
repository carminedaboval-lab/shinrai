extends Node
## Bodycam view (F4). The player's existing Camera3D stays the "eye": it aims,
## carries the viewmodel, lean and recoil, and fires along its forward. This
## rig adds a separate "lens" camera clipped to the chest that renders instead:
## it sits ~24 cm below the eye, trails the look direction like a torso does,
## pitches only part of the way, bobs at real step rates and goes through an
## equidistant fisheye. Default mode is untouched (the lens is not current).
## Values: reports/Bodycam camera mode research.md (sourced vs estimated noted).

const LensShader := preload("res://scripts/fx/bodycam_lens.gdshader")
# Small on-screen reticle where the shot will land, mapped through the fisheye
# (Park session's scripts/fx/bodycam_reticle.gd).
const Reticle := preload("res://scripts/fx/bodycam_reticle.gd")

# --- mount -------------------------------------------------------------
const CHEST_DROP := 0.24          # eye to sternum lens (estimate: 25-35 cm, eye sits low in the head node)
const CHEST_FORWARD := 0.11       # lens in front of the chest wall, clear of the hidden torso
const MOUNT_TILT := -0.0524        # -3 deg; duty cameras are clipped tilted slightly down (estimate)
const PITCH_SHARE := 0.7          # the view follows most of the look up and down (user, 2026-11-10: more than 0.45, not full; a real chest follows ~half)
const PITCH_SHARE_AIM := 0.95
const AIM_TILT := 0.0              # level when the gun is up: the aim point sits just above the middle of the picture
const YAW_LAG_RATE := 9.0         # 1/s; torso trails the head (sourced: head leads thorax 13 +/- 11 deg)
const YAW_LAG_MAX := 0.2443        # 14 deg
const PITCH_LAG_RATE := 10.0
# --- lens --------------------------------------------------------------
const LENS_H_DEG := 135.0         # a bit wider again (user, 2026-11-10); was 130, Motorola V700 class (sourced 130 x 73 deg). 120 (VB400) drew the middle of the picture 26 % larger than the normal view and felt zoomed in; 130 is 16 %
# --- how the first-person arms are shown to a chest lens --------------------
# The viewmodel is built for the eye: it sits a hand's width from the eye and
# its arms end at the elbow. Left where it is, the chest lens sits under the
# forearms and sees a gun pressed to the glass and the open ends of the sleeves.
# While the bodycam is on, the whole viewmodel is re-seated on the lens instead
# (picture only: shots still leave along the eye's aim). It keeps the eye's
# direction, so the gun points where the shots go and leads the body in a turn,
# but it pivots about the chest mount, so looking up or down never swings the
# elbows into the picture. Offsets are from the lens, in the eye's axes, metres:
# +x right, +y up, -z forward; (0, 0, 0) would show the gun as the eye sees it.
# (vars, not consts, so tests/bodycam_capture.gd --sweep can try values.)
var vm_rest := Vector3(-0.12, 0.18, 0.33)        # held close in front of the chest, low right
# Pistol up: held out at chest height, sights a few centimetres under the lens
# axis, so the target shows just above the front sight. (Raised to the eye line,
# these arms come up from below and the forearm hides the very spot being aimed
# at; that needs arms with shoulders, i.e. a new player model.)
# 0.085 m further out than the eye pose puts the gun about 0.33 m from the lens:
# what true-size arms can reach from the shoulders, and near enough that the
# upper arms (which end part-way up) run out of the bottom of the picture.
var vm_aim_pistol := Vector3(0.0, -0.035, -0.06)
# Reloading and magazine checks are animated for the eye; show them from the lens
# the same way, a little lower and closer so the wide lens does not see the elbows.
# The reload lifts the gun about 26 cm toward the eye; from the chest that would
# hang both arms in mid-picture, so here it is played low and close instead.
var vm_handling := Vector3(-0.03, -0.13, 0.03)
var vm_aim_long := Vector3(0.06, 0.30, -0.25)    # shouldered: bore right of the sternum, support arm clear of the lens
# --- gait (sourced: step 1.9 Hz walking, 2.8 Hz running; trunk vertical 2.5 cm
# walking to 8.5 cm p-p running; lateral 4.5 cm p-p at 15 km/h) -------------
const STEP_HZ_WALK := 1.9
const STEP_HZ_SPRINT := 2.8
const STEP_HZ_CROUCH := 1.5
const BOB_V_WALK := 0.0125        # half of 2.5 cm p-p
const BOB_V_SPRINT := 0.04
const BOB_L_WALK := 0.009         # estimate; lateral not measured in walking
const BOB_L_SPRINT := 0.022
const ROLL_WALK := 0.0192          # 1.1 deg, estimate
const ROLL_SPRINT := 0.0454        # 2.6 deg
const NOD_WALK := 0.0140           # 0.8 deg; trunk pitch 4-6 deg p-p, mostly absorbed (estimate)
const NOD_SPRINT := 0.0349         # 2.0 deg
const STRAFE_ROLL := 0.0349        # 2.0 deg
const TURN_ROLL := 0.0436          # 2.5 deg

var player: CharacterBody3D
var lens: Camera3D
var overlay: CanvasLayer
var lens_rect: ColorRect
var enabled := false
## Comfort: 0 = no body motion (lag, bob, roll), 1 = measured amplitudes.
var motion_scale := 0.644          # 0.7 less 8 % (user, 2026-11-10)
## 0 = rectilinear 120 deg, 1 = full equidistant fisheye.
var lens_strength := 0.9           # 10 % less fisheye than full equidistant (user, 2026-11-10)
## The fisheye magnifies the middle of the picture about 2x, so the 3D image is
## rendered larger while the bodycam is on (1 = off). Costs frame time.
var render_scale := 1.62            # 1.5 + 8 % less blur (user, 2026-11-10)
## Aiming aid: with no sights and no crosshair there is nothing to aim by, so
## while the gun is up a small laser dot marks where the shot will land (the
## eye's aim, which is what the game fires along). Off = pure point shooting.
## Show the player's own torso to the chest lens (the normal view hides it and
## seats the body behind the eye). Head and the body's own arms stay hidden: the
## first-person arms hold the gun.
var show_body := true
var body_seat_z := 0.12            # where the body model sits when seen from outside
var aim_laser := true               # traces the aim point; the reticle draws it
var show_laser_dot := false          # the old red 3D dot, replaced by the reticle
var reticle: CanvasLayer
var laser_color := Color(1.0, 0.08, 0.05)

var _yaw := 0.0
var _pitch := 0.0
var _phase := 0.0
var _gait := 0.0
var _sprint := 0.0
var _roll := 0.0
var _land := 0.0
var _land_vel := 0.0
var _was_on_floor := true
var _last_body_yaw := 0.0
var _tan_src_h := 2.25
var _saved_scale := 1.0
var _vm_written := Vector3.INF     # posture position as we last left it
var _vm_offset := Vector3.ZERO     # the shift inside that value
var _laser: MeshInstance3D
var _laser_mat: StandardMaterial3D
var _laser_hit := Vector3.ZERO
var _laser_has_hit := false
var _handling := 0.0

func bind(target: CharacterBody3D) -> void:
	player = target
	process_priority = 1000   # after the player has moved, looked and leaned this frame
	process_physics_priority = 1000   # after the player has posed the weapon this tick
	lens = Camera3D.new()
	lens.name = "BodycamLens"
	lens.top_level = true
	lens.near = 0.02
	lens.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(lens)
	overlay = CanvasLayer.new()
	overlay.name = "BodycamLensPass"
	overlay.layer = -1        # after the 3D image, before every HUD layer
	overlay.visible = false
	add_child(overlay)
	lens_rect = ColorRect.new()
	lens_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	lens_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = LensShader
	lens_rect.material = mat
	overlay.add_child(lens_rect)
	_build_laser()
	reticle = Reticle.new()
	add_child(reticle)
	# Quiet, see-through mark (user: not annoying or out of place, a bit see-through).
	reticle.color = Color(1.0, 1.0, 1.0, 0.42)
	reticle.outline = Color(0.0, 0.0, 0.0, 0.22)
	reticle.size_px = 8.0
	reticle.aim_size_px = 6.0

func set_enabled(value: bool) -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.camera):
		return
	if value == enabled:
		return
	enabled = value
	overlay.visible = value
	var vp := get_viewport()
	if value:
		_snap()
		lens.cull_mask = player.camera.cull_mask
		lens.current = true
		if vp != null:
			_saved_scale = vp.scaling_3d_scale
			vp.scaling_3d_scale = maxf(_saved_scale, clampf(render_scale, 1.0, 2.0))
		_set_body_for_lens(show_body)
	else:
		player.camera.current = true
		if vp != null:
			vp.scaling_3d_scale = _saved_scale
		_clear_viewmodel_shift()
		_set_body_for_lens(false)
		if is_instance_valid(_laser):
			_laser.visible = false
		if reticle != null:
			reticle.place(lens, Vector3.ZERO, 1.0, 1.0, 1.0, 1.0, false, 0.0)
	if "tactical_crosshair" in player and is_instance_valid(player.tactical_crosshair):
		player.tactical_crosshair.visible = not value   # no crosshair on a chest camera

func toggle() -> void:
	set_enabled(not enabled)

func _snap() -> void:
	_yaw = player.global_rotation.y
	_pitch = player.head.rotation.x if is_instance_valid(player.head) else 0.0
	_last_body_yaw = _yaw
	_roll = 0.0
	_land = 0.0
	_land_vel = 0.0

## Picture-only shift of the first-person arms and gun (see vm_* above). The
## player re-poses WeaponPosture from scratch every physics tick, so the shift
## is added once per tick, after it, and never piles up.
func _physics_process(_delta: float) -> void:
	if not enabled or not is_instance_valid(player):
		return
	var posture: Node3D = player.weapon_posture if "weapon_posture" in player else null
	if not is_instance_valid(posture):
		return
	if posture.position.is_equal_approx(_vm_written):
		return   # not re-posed since our last shift (player paused or dead)
	var aiming := smoothstep(0.0, 1.0, clampf(float(player.ads_blend), 0.0, 1.0))
	var category := ""
	if "weapon_definition" in player and player.weapon_definition is Dictionary:
		category = str(player.weapon_definition.get("category", ""))
	var aim_shift := vm_aim_pistol if category == "pistol" else vm_aim_long
	# Chest mount relative to the eye (no gait bob: the hands steady the gun while
	# the chest bounces), turned into the eye camera's axes.
	var mount := Vector3.DOWN * CHEST_DROP + Basis(Vector3.UP, _yaw) * Vector3(0.0, 0.0, -CHEST_FORWARD)
	var busy: bool = bool(player.get("reloading"))
	if "field_handling" in player and player.field_handling != null and player.field_handling.get("check") != null:
		busy = busy or bool(player.field_handling.check.get("active"))
	_handling = move_toward(_handling, 1.0 if busy else 0.0, get_physics_process_delta_time() * 5.0)
	var pose := vm_rest.lerp(aim_shift, aiming).lerp(vm_handling, smoothstep(0.0, 1.0, _handling))
	# Looking up swings the elbows toward the lens; draw the gun in a little so the
	# cut-off upper arms stay below the picture.
	var head_pitch: float = player.head.rotation.x if is_instance_valid(player.head) else 0.0
	pose += Vector3(0.0, -0.02, 0.06) * clampf(head_pitch / 0.6, 0.0, 1.0) * aiming
	_vm_offset = pose + player.camera.global_transform.basis.orthonormalized().inverse() * mount
	posture.position += _vm_offset
	_vm_written = posture.position
	_trace_laser()

func _clear_viewmodel_shift() -> void:
	if is_instance_valid(player) and "weapon_posture" in player and is_instance_valid(player.weapon_posture):
		var posture: Node3D = player.weapon_posture
		if posture.position.is_equal_approx(_vm_written):
			posture.position -= _vm_offset
	_vm_written = Vector3.INF
	_vm_offset = Vector3.ZERO

## The body model is set up for the eye: pushed 32 cm back with head, arms and
## upper torso drawn as shadows only. For the chest lens, seat it where it really
## is and draw the torso; restore the eye set-up when the bodycam goes off.
func _set_body_for_lens(on: bool) -> void:
	if not is_instance_valid(player):
		return
	var body := player.get_node_or_null("UrbanExplorerBody")
	if body == null or not (body.get("model") is Node3D):
		return
	if not on:
		body.call("set_first_person", bool(body.get("first_person")))
		return
	(body.get("model") as Node3D).position.z = body_seat_z
	for mesh: MeshInstance3D in body.get("_parts"):
		var part := String(mesh.name)
		var hidden := part.begins_with("Body_Head") or part.begins_with("Body_Arms")
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if hidden else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _build_laser() -> void:
	_laser = MeshInstance3D.new()
	_laser.name = "BodycamAimDot"
	_laser.top_level = true
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(0.042, 0.042)    # with fixed_size: about 2.4 deg across at any range (~24 px at 1600 wide), a small ring and dot
	_laser.mesh = quad
	# Small reticle: centre dot, clear gap, thin ring (radial gradient from centre).
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(1, 1, 1, 0))
	for pt: Array in [[0.14, 1.0], [0.22, 0.0], [0.58, 0.0], [0.66, 1.0], [0.82, 1.0], [0.90, 0.0]]:
		grad.add_point(pt[0], Color(1, 1, 1, pt[1]))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_laser_mat = StandardMaterial3D.new()
	_laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_laser_mat.fixed_size = true
	_laser_mat.albedo_texture = tex
	_laser_mat.no_depth_test = false
	_laser.material_override = _laser_mat
	_laser.visible = false
	add_child(_laser)

## Where the eye's aim meets the world (the same ray the game fires along).
func _trace_laser() -> void:
	_laser_has_hit = false
	if not aim_laser or not is_instance_valid(player) or not is_instance_valid(player.camera):
		return
	var eye: Transform3D = player.camera.global_transform
	var from := eye.origin
	var to := from - eye.basis.z * 150.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		hit = {"position": to}   # open sky: keep the reticle on the aim line
	# Sit just off the surface, toward the eye, so the dot never z-fights it.
	_laser_hit = hit.position + (from - hit.position).normalized() * 0.01
	_laser_has_hit = true

func _update_laser() -> void:
	var aiming := clampf(float(player.ads_blend), 0.0, 1.0) if is_instance_valid(player) else 0.0
	var show := enabled and aim_laser and _laser_has_hit and show_laser_dot
	_laser.visible = show
	if show:
		_laser.global_position = _laser_hit
		# Brighter than white paper under the tonemapper, and mixed (not added) so it
		# still shows on a sunlit white wall.
		# A little fainter at the hip, full when the gun is up.
		_laser_mat.albedo_color = Color(laser_color.r * 2.5, laser_color.g * 2.5, laser_color.b * 2.5, lerpf(0.6, 1.0, smoothstep(0.2, 0.9, aiming)))

func _source_tan(aspect: float) -> float:
	# Smallest rectilinear overscan that keeps an equidistant lens' corners
	# filled: tan(src_h) = tan(theta_corner) * a / sqrt(a^2 + 1).
	var half_h := deg_to_rad(LENS_H_DEG) * 0.5
	var theta_c := minf(half_h * sqrt(1.0 + 1.0 / (aspect * aspect)), deg_to_rad(84.0))
	var t_full := tan(theta_c) * aspect / sqrt(aspect * aspect + 1.0)
	# Strength 0 needs no overscan; blend so the centre isn't softened for nothing.
	return lerpf(tan(half_h), t_full, clampf(lens_strength, 0.0, 1.0))

func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(player) or not is_instance_valid(player.camera):
		return
	if not lens.current:
		# Only reclaim the view from the eye camera (e.g. after a respawn reset);
		# a death cam or cutscene camera keeps it.
		if get_viewport().get_camera_3d() == player.camera:
			lens.current = true
		else:
			return
	delta = clampf(delta, 0.0, 0.1)
	var eye: Transform3D = player.camera.global_transform
	var aiming: float = clampf(float(player.ads_blend), 0.0, 1.0) if "ads_blend" in player else 0.0
	var m := clampf(motion_scale, 0.0, 1.0)

	# ---- torso orientation: yaw trails the look, pitch follows partly ----
	var body_yaw: float = player.global_rotation.y
	var yaw_err := wrapf(body_yaw - _yaw, -PI, PI)
	_yaw += yaw_err * (1.0 - exp(-lerpf(40.0, YAW_LAG_RATE, m) * delta))
	yaw_err = wrapf(body_yaw - _yaw, -PI, PI)
	if absf(yaw_err) > YAW_LAG_MAX:
		_yaw = body_yaw - signf(yaw_err) * YAW_LAG_MAX
	var head_pitch: float = player.head.rotation.x if is_instance_valid(player.head) else 0.0
	var share := lerpf(PITCH_SHARE, PITCH_SHARE_AIM, aiming)
	var tilt := lerpf(MOUNT_TILT, AIM_TILT, aiming)
	var pitch_target := head_pitch * share + tilt
	_pitch += (pitch_target - _pitch) * (1.0 - exp(-PITCH_LAG_RATE * delta))

	# ---- gait: cadence from the movement state, not from raw speed --------
	var hv := Vector2(player.velocity.x, player.velocity.z)
	var speed := hv.length()
	var on_floor: bool = player.is_on_floor()
	var moving := on_floor and speed > 0.25
	_gait = lerpf(_gait, 1.0 if moving else 0.0, 1.0 - exp(-8.0 * delta))
	_sprint = lerpf(_sprint, 1.0 if bool(player.sprinting) else 0.0, 1.0 - exp(-6.0 * delta))
	var crouched: bool = bool(player.crouching) if "crouching" in player else false
	var hz := lerpf(STEP_HZ_WALK, STEP_HZ_SPRINT, _sprint)
	if crouched:
		hz = STEP_HZ_CROUCH
	if moving:
		_phase = fmod(_phase + hz * delta, 2.0)   # one unit per step, two per stride
	var g := _gait * m * (1.0 - 0.6 * aiming)
	var bob_v := lerpf(BOB_V_WALK, BOB_V_SPRINT, _sprint) * g
	var bob_l := lerpf(BOB_L_WALK, BOB_L_SPRINT, _sprint) * g
	var roll_amp := lerpf(ROLL_WALK, ROLL_SPRINT, _sprint) * g
	var nod_amp := lerpf(NOD_WALK, NOD_SPRINT, _sprint) * g
	var step := TAU * _phase            # vertical: once per step
	var stride := PI * _phase           # lateral and roll: once per stride
	var v_off := -bob_v * cos(step)
	var l_off := bob_l * sin(stride)
	var gait_roll := roll_amp * sin(stride)
	var gait_nod := nod_amp * sin(step + 0.6)

	# ---- landing: a damped dip when the feet come back down ---------------
	if on_floor and not _was_on_floor:
		_land_vel -= clampf(-player.velocity.y * 0.02, 0.0, 0.12) * m
	_was_on_floor = on_floor
	var k := 120.0
	var c := 2.0 * sqrt(k) * 0.55
	_land_vel += (-k * _land - c * _land_vel) * delta
	_land += _land_vel * delta

	# ---- roll from strafing and turning ----------------------------------
	var basis_y := Basis(Vector3.UP, body_yaw)
	var local_v: Vector3 = basis_y.inverse() * player.velocity
	var turn_rate := wrapf(body_yaw - _last_body_yaw, -PI, PI) / maxf(delta, 1e-4)
	_last_body_yaw = body_yaw
	var roll_target := (-clampf(local_v.x / 4.0, -1.0, 1.0) * STRAFE_ROLL + clampf(turn_rate / 6.0, -1.0, 1.0) * TURN_ROLL) * m
	_roll += (roll_target - _roll) * (1.0 - exp(-6.0 * delta))

	# ---- lean: the eye's position already carries the shoulder shift; the
	# chest takes most of the lean's roll too ----------------------------------
	var lean_roll: float = player.camera.rotation.z

	# ---- assemble ---------------------------------------------------------
	var yaw_basis := Basis(Vector3.UP, _yaw)
	var chest := eye.origin - Vector3.UP * CHEST_DROP + yaw_basis * Vector3(0.0, 0.0, -CHEST_FORWARD)
	chest += yaw_basis * Vector3(l_off, v_off + _land, 0.0)
	var rot := yaw_basis * Basis(Vector3.RIGHT, _pitch + gait_nod) * Basis(Vector3.FORWARD, -(gait_roll + _roll) + lean_roll * 0.8)
	lens.global_transform = Transform3D(rot.orthonormalized(), chest)
	lens.h_offset = player.camera.h_offset   # firing / hit trauma
	lens.v_offset = player.camera.v_offset

	# ---- lens pass ---------------------------------------------------------
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	_tan_src_h = _source_tan(aspect)
	lens.fov = rad_to_deg(2.0 * atan(_tan_src_h / aspect))   # vertical FOV (KEEP_HEIGHT)
	var mat := lens_rect.material as ShaderMaterial
	mat.set_shader_parameter("half_fov_h", deg_to_rad(LENS_H_DEG) * 0.5)
	mat.set_shader_parameter("tan_src_h", _tan_src_h)
	mat.set_shader_parameter("aspect", aspect)
	mat.set_shader_parameter("strength", lens_strength)
	_update_laser()
	if reticle != null:
		reticle.place(lens, _laser_hit, deg_to_rad(LENS_H_DEG) * 0.5, _tan_src_h, aspect, lens_strength, enabled and aim_laser and _laser_has_hit, aiming)
