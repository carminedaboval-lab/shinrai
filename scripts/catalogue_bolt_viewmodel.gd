extends "res://scripts/catalogue_rifle_viewmodel.gd"

# Presentation only. The player must separately own chamber state and shot gate.
# Rebased from the historical Hayate candidate; resolves the actual new action
# instead of assuming a root BoltAssembly and never enables a live catalog row.
signal bolt_cycle_visual_finished

var _cycle_active := false
var _cycle_elapsed := 0.0
var _cycle_duration := 1.35
var _pending_case := false

func _process(delta: float) -> void:
	super._process(delta)
	if not _cycle_active:
		return
	_cycle_elapsed = minf(_cycle_duration, _cycle_elapsed + maxf(delta, 0.0))
	if _pending_case and _cycle_elapsed >= _cycle_duration * 0.38:
		_pending_case = false
		super._eject_case()
	if _cycle_elapsed >= _cycle_duration:
		_cycle_active = false
		_reset_action()
		bolt_cycle_visual_finished.emit()

func play_fire() -> void:
	if not is_ready_for_input():
		return
	super.play_fire()
	# The authoritative player calls play_cycle(duration) after committing the
	# shot. Presentation must never silently start or finish chamber state.

func _eject_case() -> void:
	# Delayed to the extraction portion of the visible manual cycle.
	_pending_case = true

func _begin_cycle(duration: float) -> void:
	_cycle_duration = maxf(duration, 0.1)
	_cycle_elapsed = 0.0
	_cycle_active = true

func play_cycle(duration: float) -> void:
	if not loaded or not _fitted or failed or _presentation_hold:
		return
	_ads_idle_held = false
	_chamber_presentation = false
	if animation_player != null:
		animation_player.speed_scale = 1.0
		animation_player.play(idle_anim_name, 0.04)
	_begin_cycle(duration)

func is_cycle_active() -> bool:
	return _cycle_active

func cancel_cycle() -> void:
	_cycle_active = false
	_cycle_elapsed = 0.0
	_reset_action()
	# Keep a not-yet-extracted case pending so a resumed cycle ejects it once.

func cancel_bolt_cycle() -> void:
	cancel_cycle()

func cancel_reload_presentation() -> void:
	cancel_cycle()
	super.cancel_reload_presentation()

func hold_presentation(value: bool) -> void:
	if value:
		cancel_cycle()
	super.hold_presentation(value)

func play_holster() -> void:
	cancel_cycle()
	super.play_holster()

func play_reload(empty: bool) -> void:
	cancel_cycle()
	super.play_reload(empty)

func play_chamber(duration: float) -> void:
	play_cycle(duration)

func _is_action_animation_playing() -> bool:
	return _cycle_active or super._is_action_animation_playing()

func is_ready_for_input() -> bool:
	return not _cycle_active and super.is_ready_for_input()

func update_supplied_pose(rig: Skeleton3D, delta: float = 0.0) -> void:
	super.update_supplied_pose(rig, delta)
	if not _fitted or not is_instance_valid(action_mesh):
		return
	var t := -1.0
	if _cycle_active:
		t = clampf(_cycle_elapsed / _cycle_duration, 0.0, 1.0)
	else:
		var clip := str(animation_player.assigned_animation).to_lower()
		if clip.contains("reload") and clip.contains("empty"):
			var length := animation_player.get_animation(animation_player.assigned_animation).length
			var ratio := animation_player.current_animation_position / maxf(length, 0.001)
			if ratio >= 0.52:
				t = clampf((ratio - 0.52) / 0.48, 0.0, 1.0)
				if _pending_case and t >= 0.38:
					_pending_case = false
					super._eject_case()
	if t < 0.0:
		_reset_action()
		return
	var lift := smoothstep(0.12, 0.25, t) * (1.0 - smoothstep(0.78, 0.90, t))
	var pull := smoothstep(0.25, 0.45, t) * (1.0 - smoothstep(0.54, 0.76, t))
	var travel := float(Catalog.WEAPONS[weapon_key].get("action_travel_m", 0.075))
	var lift_degrees := float(Catalog.WEAPONS[weapon_key].get("bolt_lift_degrees", -55.0))
	action_mesh.global_transform = assembly.global_transform * action_rest
	action_mesh.global_position += assembly.global_basis.x * travel * pull
	action_mesh.global_basis = assembly.global_basis * Basis(Vector3.RIGHT, deg_to_rad(lift_degrees) * lift) * action_rest.basis
	var contact := smoothstep(0.03, 0.14, t) * (1.0 - smoothstep(0.89, 1.0, t))
	var right_poses: Array[Transform3D] = []
	for id: int in right_bones:
		right_poses.append(rig.get_bone_global_pose(id))
	var palm_offset := rig.global_basis * right_poses[4].basis * RIGHT_PALM_CONTACT
	var grip: Vector3 = assembly.get_node("GripRight").global_position
	var target := grip.lerp(get_action_grip_world(), contact) - palm_offset
	_solve_arm(rig, right_bones, right_poses, rig.global_transform.affine_inverse() * target, true)
	var left_poses: Array[Transform3D] = []
	for id: int in left_bones:
		left_poses.append(rig.get_bone_global_pose(id))
	var support: Vector3 = assembly.get_node("GripLeft").global_position
	_solve_arm(rig, left_bones, left_poses, rig.global_transform.affine_inverse() * support)
