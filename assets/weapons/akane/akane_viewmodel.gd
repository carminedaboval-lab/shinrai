extends "res://assets/characters/player_wardrobe/akane_wardrobe_pose.gd"

# Critically damped presentation spring. A fresh impulse peaks after about 53 ms.
const RETURN_RATE := 19.0
const SHOT_IMPULSE := 51.65

@onready var _counter: MeshInstance3D = $RearCounter
var _loaded_rounds := -1
var _magazine_empty := false
var _bodycam_projection := false
var _lift := 0.0
var _lift_velocity := 0.0
var _hand_follow := 0.0
var _grip_kick := Transform3D.IDENTITY
var _wrist_frame := Transform3D.IDENTITY

## The Glock read a little small on screen (user, 2026-11-12): hold it closer
## rather than scaling it. Hip: 4.5 cm nearer the eye (~7-8 % larger).
const HIP_CLOSER := 0.045

func _load_bundled_model() -> void:
	super._load_bundled_model()
	if _fitted:
		hip_pos.z += HIP_CLOSER
	if not _fitted or _counter.get_parent() == slide_mesh:
		return
	_wrist_frame = assembly_reference.translated_local(RIGHT_WRIST)
	var plate_pose := _counter.transform
	_counter.reparent(slide_mesh, false)
	_counter.transform = slide_rest.affine_inverse() * plate_pose
	_update_counter()

func set_loaded_rounds(count: int, magazine_empty: bool = false) -> void:
	var empty := magazine_empty or count == 0
	if count == _loaded_rounds and empty == _magazine_empty:
		return
	_loaded_rounds = count
	_magazine_empty = empty
	_update_counter()

func _update_counter() -> void:
	if not is_instance_valid(_counter) or not _fitted or _loaded_rounds < 0:
		return
	var material := _counter.material_override as ShaderMaterial
	material.set_shader_parameter("rounds", _loaded_rounds)
	material.set_shader_parameter("magazine_empty", _magazine_empty)
	_counter.show()

func _build_fire_effect() -> void:
	super._build_fire_effect()
	# Start at the bore. The material projects the jet ahead of the muzzle.
	_flash.position = Vector3.ZERO
	(_flash.mesh as QuadMesh).size = Vector2(0.26, 0.26)
	_flash.extra_cull_margin = 0.08
	_flash_material.shader = preload("res://assets/weapons/akane/akane_muzzle_flash.gdshader")
	_flash_material.set_shader_parameter("life", 0.0)

func _play_fire_motion() -> void:
	_flash_frame_pending = true
	_lift_velocity += SHOT_IMPULSE

func _process(delta: float) -> void:
	super._process(delta)
	var active_lens := get_viewport().get_camera_3d()
	var feed := active_lens != null and active_lens.is_in_group(&"bodycam_lens")
	if feed != _bodycam_projection:
		_bodycam_projection = feed
		(_counter.material_override as ShaderMaterial).set_shader_parameter("bodycam_feed", feed)
	if _lift == 0.0 and _lift_velocity == 0.0 and _hand_follow == 0.0:
		return
	if not is_ready_for_input():
		_lift = 0.0
		_lift_velocity = 0.0
		_hand_follow = 0.0
		return
	var slope := _lift_velocity + RETURN_RATE * _lift
	var decay := exp(-RETURN_RATE * delta)
	_lift = (_lift + slope * delta) * decay
	_lift_velocity = (_lift_velocity - RETURN_RATE * slope * delta) * decay
	_hand_follow = lerpf(_hand_follow, _lift, 1.0 - exp(-16.0 * delta))
	if _lift < 0.0001 and absf(_lift_velocity) < 0.002:
		_lift = 0.0
		_lift_velocity = 0.0
		if _hand_follow < 0.0001:
			_hand_follow = 0.0

func _held_rig_pose() -> Transform3D:
	var base := super._held_rig_pose()
	if _hand_follow == 0.0:
		return base
	# Both forearms absorb a few millimetres after the initial slide impulse.
	var amount := minf(_hand_follow, 1.65)
	var follow := Transform3D(Basis(Vector3.BACK, -deg_to_rad(1.2) * amount),
			Vector3(lerpf(0.008, 0.006, ads_blend) * amount, 0, 0))
	return _wrist_frame * follow * _wrist_frame.affine_inverse() * base

func _held_assembly_pose(rest: Transform3D) -> Transform3D:
	_grip_kick = Transform3D.IDENTITY
	if _lift > 0.0:
		var amount := minf(_lift, 1.65)
		var pitch := deg_to_rad(lerpf(7.3, 4.8, ads_blend)) * amount
		var turn := Basis(Vector3.BACK, -pitch)
		var travel := Vector3(lerpf(0.012, 0.008, ads_blend) * amount, 0, 0)
		# The held-wrist IK follows the grip while the elbows absorb the movement.
		_grip_kick = Transform3D(turn, RIGHT_WRIST - turn * RIGHT_WRIST + travel)
	return rest * _grip_kick

# Shot queries use the rig before its cosmetic kick, including when the render
# and physics ticks fall on different frames.
func _shot_reference_point(world_point: Vector3) -> Vector3:
	if not _fitted or str(animation_player.assigned_animation).to_lower().contains("reload"):
		return world_point
	var rested_gun_point := assembly.global_transform * (_grip_kick.affine_inverse() * assembly.to_local(world_point))
	return to_global(super._held_rig_pose() * imported_root.to_local(rested_gun_point))
