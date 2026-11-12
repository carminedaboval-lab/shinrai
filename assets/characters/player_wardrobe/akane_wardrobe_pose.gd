extends "res://scripts/pistol_candidate_viewmodel.gd"

# AKANE-specific grip. Palms retain donor geometry; fingers are posed
# by joints with natural bind offsets. There are no hand morphs or RBF warps.
const RIGHT_WRIST := Vector3(0.137627639, -0.064484459, -0.038706032)
const LEFT_WRIST := Vector3(0.073350402, -0.064811475, 0.081733273)
const HOLD_EXTENSION := 0.04
const GRIP_POSE_DATA = preload("res://assets/weapons/akane/akane_grip_pose.gd")
# Grip-fit corrections on top of the generated pose (akane_grip_pose.gd), fitted
# against the Glock's measured grip outline (tests/akane_hand_probe.gd):
#  HAND_FIX: rigid move of each hand about its wrist, in the gun's axes
#    (+x rear, +y up, +z the gun's left): [dx, dy, dz mm, rx, ry, rz deg].
#  FINGER_CURL: extra flexion per finger joint [knuckle, middle, tip] in degrees.
# Bone lengths and palm shape are untouched: only where the hand sits and how
# far each joint bends change.
const HAND_FIX := {
	"Right": [-8.6, 3.5, -0.5, -2.4, 6.6, -0.6],
	"Left": [8.3, -3.6, -11.8, 8.0, -2.9, 8.0],
}
const FINGER_CURL := {
	"Right": {"Middle": [8.0, 3.0, 6.0], "Ring": [6.0, 5.0, 18.0], "Pinky": [-6.0, 19.0, 12.0]},
	"Left": {"Index": [2.0, 19.0, -15.0], "Middle": [8.0, 7.0, 21.0], "Ring": [0.0, 25.0, 25.0], "Pinky": [0.0, -12.0, -8.0]},
}
var _natural: Dictionary = {}
var _skin: MeshInstance3D
var _capture_final_pose: bool = false
var _natural_final_pose: Dictionary = {}

func _xform(value: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(value[0][0], value[0][1], value[0][2]), Vector3(value[1][0], value[1][1], value[1][2]), Vector3(value[2][0], value[2][1], value[2][2])), Vector3(value[3][0], value[3][1], value[3][2]))

func _load_bundled_model() -> void:
	super._load_bundled_model()
	if not _fitted:
		return
	_natural = GRIP_POSE_DATA.DATA.duplicate(true)
	_skin = imported_root.find_child("BareArms", true, false) as MeshInstance3D
	# During reload the pistol follows this firing hand with the same relation
	# as the closed grip, rather than the old glove wrist/palm relation.
	_hand_to_assembly = (_hand_fix("Right") * _xform(_natural.hands.Right.hand_gun)).affine_inverse()
	# Extend the pistol relative to the fixed arm roots. Increasing eye relief
	# by the same distance keeps the ADS camera alignment and shoulders stable:
	# only the pistol/hand contact moves forward into a natural two-arm reach.
	var extension := Transform3D(Basis.IDENTITY, Vector3(-HOLD_EXTENSION, 0.0, 0.0))
	body_fit = body_fit * extension
	assembly_reference = assembly_reference * extension
	iron_eye_relief_m += HOLD_EXTENSION
	_update_sight_alignment()

func update_supplied_pose(rig: Skeleton3D, delta: float = 0.0) -> void:
	super.update_supplied_pose(rig, delta)
	if not _fitted or _natural.is_empty() or rig == null:
		return
	var clip := str(animation_player.assigned_animation).to_lower()
	var reloading := clip.contains("reload")
	var left_held := 1.0 - maxf(_pistol_magazine_contact_weight, _pistol_release_weight) if reloading else 1.0
	var neutral_weight := 1.0
	if reloading:
		var phase := animation_player.current_animation_position / maxf(animation_player.current_animation_length, 0.001)
		neutral_weight = 1.0 - smoothstep(0.0, 0.12, phase) * (1.0 - smoothstep(0.82, 0.98, phase))
	var to_rig := rig.global_transform.affine_inverse() * assembly.global_transform
	for side: String in ["Right", "Left"]:
		var spec: Dictionary = _natural.hands[side]
		var chain_ids: Array[int] = right_bones if side == "Right" else left_bones
		var held: float = 1.0 if side == "Right" else left_held
		# Save the original local rotations before overriding the wrist. These
		# retarget magazine/open-hand animation onto the natural finger lengths.
		var animated: Dictionary = {}
		for finger: Dictionary in spec.fingers:
			for bone: Dictionary in finger.bones:
				var id := rig.find_bone(bone.name)
				var parent_id := rig.find_bone(bone.parent_name)
				animated[bone.name] = rig.get_bone_global_pose(parent_id).affine_inverse() * rig.get_bone_global_pose(id)
		var desired: Transform3D = to_rig * _hand_fix(side) * _xform(spec.hand_gun)
		var original_hand := rig.get_bone_global_pose(chain_ids[4])
		if side == "Left" and held < 1.0:
			desired = original_hand.interpolate_with(desired, held)
		var chain: Array[Transform3D] = []
		var shoulder_offset: Array = spec.get("shoulder_offset_gun", [0.0, 0.0, 0.0])
		var arm_shift := to_rig.basis * Vector3(shoulder_offset[0], shoulder_offset[1], shoulder_offset[2]) * neutral_weight * held
		for id in chain_ids:
			var shifted := rig.get_bone_global_pose(id)
			shifted.origin += arm_shift
			chain.append(shifted)
		chain[4].basis = desired.basis
		var palm_axis := Vector3.ZERO
		for finger: Dictionary in spec.fingers:
			if finger.name == "Middle":
				palm_axis = desired.basis * _xform(finger.bones[0].rest_local).origin
		_solve_natural_arm(rig, chain_ids, chain, desired.origin, palm_axis.normalized(), neutral_weight * held)
		for finger: Dictionary in spec.fingers:
			var curl: Array = FINGER_CURL[side].get(finger.name, [])
			for joint in finger.bones.size():
				var bone: Dictionary = finger.bones[joint]
				var id := rig.find_bone(bone.name)
				var parent_id := rig.find_bone(bone.parent_name)
				var rest := _xform(bone.rest_local)
				var grip := _xform(bone.grip_local)
				if joint < curl.size() and curl[joint] != 0.0:
					grip.basis = grip.basis * Basis(Vector3.UP, deg_to_rad(float(curl[joint])))   # bones run along local X; Y is the hinge
				var native_rest := _xform(bone.native_rest_local)
				var authored: Transform3D = animated[bone.name]
				var opened := rest
				opened.basis = rest.basis * native_rest.basis.inverse() * authored.basis
				var local := opened.interpolate_with(grip, held)
				# Translation is fixed to the donor bind offset: every segment keeps
				# its real length through aiming, recoil and reload transitions.
				local.origin = rest.origin
				rig.set_bone_global_pose(id, rig.get_bone_global_pose(parent_id) * local)
	# SkeletonModifier3D restores authored poses after its render update. Capture
	# here when the preview requests it, while the actual skin palette is active.
	if _capture_final_pose and is_instance_valid(_skin) and _skin.skin != null:
		var snapshot := {"gun": _pack_transform(assembly.global_transform), "bones": {}}
		for index in _skin.skin.get_bind_count():
			var bone_name: String = _skin.skin.get_bind_name(index)
			var bone_id := rig.find_bone(bone_name)
			snapshot.bones[bone_name] = _pack_transform(rig.global_transform * rig.get_bone_global_pose(bone_id))
		_natural_final_pose = snapshot

## Rigid grip correction for one hand (HAND_FIX), as a gun-space transform that
## turns the hand about its own wrist and then shifts it.
func _hand_fix(side: String) -> Transform3D:
	var f: Array = HAND_FIX.get(side, [])
	if f.size() < 6:
		return Transform3D.IDENTITY
	var wrist := _xform(_natural.hands[side].hand_gun).origin
	var turn := Basis.from_euler(Vector3(deg_to_rad(f[3]), deg_to_rad(f[4]), deg_to_rad(f[5])), EULER_ORDER_XYZ)
	var shift := Vector3(f[0], f[1], f[2]) * 0.001
	return Transform3D(Basis.IDENTITY, wrist + shift) * Transform3D(turn, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -wrist)

func _solve_natural_arm(rig: Skeleton3D, bones: Array[int], poses: Array[Transform3D], target: Vector3, hand_direction: Vector3, weight: float) -> void:
	var shoulder := poses[0].origin
	var elbow := poses[2].origin
	var wrist := poses[4].origin
	var upper_length := shoulder.distance_to(elbow)
	var lower_length := elbow.distance_to(wrist)
	var distance := clampf(shoulder.distance_to(target), absf(upper_length - lower_length) + 0.001, upper_length + lower_length - 0.001)
	var direction := (target - shoulder).normalized()
	var inherited := elbow - shoulder - direction * (elbow - shoulder).dot(direction)
	if inherited.length_squared() < 0.000001:
		inherited = direction.cross(Vector3.RIGHT)
	if inherited.length_squared() < 0.000001:
		inherited = direction.cross(Vector3.UP)
	inherited = inherited.normalized()
	# The valid elbow positions form a circle. Its closest point to the desired
	# straight continuation of the hand is opposite the hand-axis projection.
	# This minimizes wrist bend without changing either arm segment length.
	var neutral := -(hand_direction - direction * hand_direction.dot(direction))
	var bend := inherited
	if neutral.length_squared() > 0.000001:
		neutral = neutral.normalized()
		var along_for_pole := (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
		var radius := sqrt(maxf(0.0, upper_length * upper_length - along_for_pole * along_for_pole))
		neutral = _anatomical_elbow_pole(rig, bones, shoulder + direction * along_for_pole, radius, direction, neutral, target)
		var angle := atan2(inherited.cross(neutral).dot(direction), clampf(inherited.dot(neutral), -1.0, 1.0))
		bend = inherited.rotated(direction, angle * weight).normalized()
	var along := (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var next_elbow := shoulder + direction * along + bend * height
	var next_wrist := shoulder + direction * distance
	var upper_rotation := Basis(Quaternion((elbow - shoulder).normalized(), (next_elbow - shoulder).normalized()))
	var lower_rotation := Basis(Quaternion((wrist - elbow).normalized(), (next_wrist - next_elbow).normalized()))
	for index in range(5):
		var pose := poses[index]
		if index < 2:
			pose.origin = shoulder + upper_rotation * (pose.origin - shoulder)
			pose.basis = upper_rotation * pose.basis
		elif index < 4:
			pose.origin = next_elbow + lower_rotation * (pose.origin - elbow)
			pose.basis = lower_rotation * pose.basis
		else:
			pose.origin = next_wrist
		rig.set_bone_global_pose(bones[index], pose)

func _anatomical_elbow_pole(rig: Skeleton3D, bones: Array[int], centre: Vector3, radius: float, direction: Vector3, neutral: Vector3, wrist: Vector3) -> Vector3:
	if radius < 0.00001:
		return neutral
	var to_gun := assembly.global_transform.affine_inverse() * rig.global_transform
	var c := to_gun * centre
	var u := to_gun.basis * neutral * radius
	var perpendicular := direction.cross(neutral).normalized()
	var v := to_gun.basis * perpendicular * radius
	var wrist_gun := to_gun * wrist
	# Keep each elbow on its own side, below the wrist. This avoids a crossed
	# arm or an elbow lifted into the wide bodycam lens by a pure angle minimum.
	var sign_side := 1.0 if bones[4] == right_bones[4] else -1.0
	var constraints: Array[Vector3] = [
		Vector3(sign_side * u.z, sign_side * v.z, -0.10 - sign_side * c.z),
		Vector3(u.y, v.y, wrist_gun.y - 0.045 - c.y),
	]
	var candidates: Array[float] = [0.0, PI]
	for constraint in constraints:
		var amplitude := Vector2(constraint.x, constraint.y).length()
		if amplitude > 0.00001 and absf(constraint.z) <= amplitude:
			var centre_angle := atan2(constraint.y, constraint.x)
			var half_arc := acos(clampf(constraint.z / amplitude, -1.0, 1.0))
			candidates.append(centre_angle + half_arc)
			candidates.append(centre_angle - half_arc)
	var best_angle := 0.0
	var best_cost := INF
	for angle in candidates:
		var cost := 1.0 - cos(angle)
		for constraint in constraints:
			var violation := maxf(0.0, constraint.x * cos(angle) + constraint.y * sin(angle) - constraint.z)
			cost += violation * violation * 100000.0
		if cost < best_cost:
			best_cost = cost
			best_angle = angle
	return (neutral * cos(best_angle) + perpendicular * sin(best_angle)).normalized()

func _pack_transform(value: Transform3D) -> Array:
	return [
		[value.basis.x.x, value.basis.x.y, value.basis.x.z],
		[value.basis.y.x, value.basis.y.y, value.basis.y.z],
		[value.basis.z.x, value.basis.z.y, value.basis.z.z],
		[value.origin.x, value.origin.y, value.origin.z],
	]
