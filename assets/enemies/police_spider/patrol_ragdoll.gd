extends Node
## Native death physics. The caller stops animation/AI and retires live hitboxes
## before deferred start(); it leaves the skeleton and this helper processing.
const CORPSE_SECONDS := 30.0
const CORPSE_LAYER := 8
const WORLD_AND_PEERS_MASK := 1 | 2
const LEGS: Array[String] = ["FL", "FR", "RL", "RR"]
# Rigid-weighted mesh radial maxima around each segment's authored local +Y.
const LIMB_RADII := {
	"FL": Vector2(.089122, .115997), "FR": Vector2(.093913, .114109),
	"RL": Vector2(.114109, .136173), "RR": Vector2(.159789, .141795)
}
# Foot-influenced mesh bounds in Foot bone space: local Y forward, Z up.
const FOOT_BOUNDS := {
	"FL": [Vector3(.011676, -.016859, -.041587), Vector3(.279165, .271749, .080644)],
	"FR": [Vector3(-.008235, -.012890, -.044968), Vector3(.261461, .275891, .081827)],
	"RL": [Vector3(.004343, -.026904, -.039198), Vector3(.248142, .259479, .089956)],
	"RR": [Vector3(-.012602, -.013792, -.047269), Vector3(.242725, .269556, .085778)]
}

var actor: CharacterBody3D
var skeleton: Skeleton3D
var simulator: PhysicalBoneSimulator3D
var bodies: Array[PhysicalBone3D] = []
var bodies_by_bone: Dictionary = {}
var initial_body_transforms: Array[Transform3D] = []
var initial_bone_poses: Array[Transform3D] = []
var started := false
var start_attempted := false
var failure_reason := ""

func start(owner_actor: CharacterBody3D, core_shape: Shape3D, core_transform: Transform3D,
		initial_velocity: Vector3 = Vector3.INF, initial_angular_velocity: Vector3 = Vector3.INF) -> bool:
	if start_attempted: return false
	start_attempted = true
	actor = owner_actor
	if not is_instance_valid(actor) or not is_inside_tree() or not actor.is_ancestor_of(self):
		return _fail("ragdoll helper must be a child of its live actor")
	var visual: Node3D = actor.get("visual") as Node3D
	if not is_instance_valid(visual): return _fail("missing robot visual")
	skeleton = visual.get("skeleton") as Skeleton3D
	if not is_instance_valid(skeleton) or skeleton.get_bone_count() != 13:
		return _fail("expected the existing thirteen-bone robot skeleton")
	if skeleton.has_node("DeathPhysics"): return _fail("death simulation already exists")
	if core_shape == null or not core_transform.is_finite() or not core_transform.basis.get_scale().is_equal_approx(Vector3.ONE):
		return _fail("invalid fitted core shape or transform")
	if not skeleton.global_basis.get_scale().is_equal_approx(Vector3.ONE):
		return _fail("ragdoll skeleton must retain its measured unit scale")
	var body_id: int = skeleton.find_bone("Body")
	if body_id < 0 or skeleton.get_bone_parent(body_id) != -1: return _fail("missing root Body bone")
	for id: int in skeleton.get_bone_count():
		var pose: Transform3D = skeleton.get_bone_global_pose(id)
		if not pose.is_finite() or not pose.basis.get_scale().is_equal_approx(Vector3.ONE):
			return _fail("invalid or scaled current bone pose")
		initial_bone_poses.append(pose)
	for leg: String in LEGS:
		var upper: int = skeleton.find_bone(leg + "_Upper")
		var lower: int = skeleton.find_bone(leg + "_Lower")
		var foot: int = skeleton.find_bone(leg + "_Foot")
		if upper < 0 or lower < 0 or foot < 0: return _fail("incomplete leg chain: " + leg)
		if skeleton.get_bone_parent(upper) != body_id or skeleton.get_bone_parent(lower) != upper or skeleton.get_bone_parent(foot) != lower:
			return _fail("unexpected leg hierarchy: " + leg)
		if _rest_end(upper, lower).length() < .01 or _rest_end(lower, foot).length() < .01:
			return _fail("degenerate rest segment: " + leg)
	var linear: Vector3 = actor.velocity if initial_velocity == Vector3.INF else initial_velocity
	var angular: Vector3 = Vector3.UP * float(actor.get("turn_rate")) if initial_angular_velocity == Vector3.INF else initial_angular_velocity
	if not linear.is_finite() or not angular.is_finite(): return _fail("invalid inherited velocity")

	simulator = PhysicalBoneSimulator3D.new()
	simulator.name = "DeathPhysics"
	simulator.active = false
	skeleton.add_child(simulator)
	# The core geometry can be a fitted convex shape. Its coordinate system is
	# supplied by the caller; never assume Body's local Z is forward or Y is up.
	var core_world: Transform3D = actor.global_transform * core_transform
	var body_world: Transform3D = skeleton.global_transform * initial_bone_poses[body_id]
	_make_body("Body", core_shape, body_world.affine_inverse() * core_world, Transform3D.IDENTITY, 8.0)
	for leg: String in LEGS:
		var upper: int = skeleton.find_bone(leg + "_Upper")
		var lower: int = skeleton.find_bone(leg + "_Lower")
		var foot: int = skeleton.find_bone(leg + "_Foot")
		var radii: Vector2 = LIMB_RADII[leg]
		_make_segment(leg + "_Upper", _rest_end(upper, lower), radii.x, .65)
		_make_segment(leg + "_Lower", _rest_end(lower, foot), radii.y, .45)
		_add_foot_shape(leg, lower, foot)
	for body: PhysicalBone3D in bodies:
		if body.get_bone_id() < 0: return _fail("physical bone did not bind: " + str(body.name))
		body.add_collision_exception_with(actor)
		for other: PhysicalBone3D in bodies:
			if other != body: body.add_collision_exception_with(other)
	# Configure joints only after every parent body has its current pose. Godot
	# clamps joint_offset.origin to the actual bone origin (inverse body_offset).
	for leg: String in LEGS:
		_configure_leg_joints(leg)
	for body: PhysicalBone3D in bodies:
		initial_body_transforms.append(body.global_transform)
		body.collision_layer = CORPSE_LAYER
		body.collision_mask = WORLD_AND_PEERS_MASK
	simulator.active = true
	simulator.physical_bones_start_simulation()
	for body: PhysicalBone3D in bodies:
		# Transfer rigid actor momentum once, including tangential yaw velocity.
		# No invented explosion/limb impulses and no ongoing transform writes.
		body.linear_velocity = linear + angular.cross(body.global_position - actor.global_position)
		body.angular_velocity = angular
	started = true
	var expiry := Timer.new()
	expiry.name = "CorpseLifetime"
	expiry.one_shot = true
	expiry.wait_time = CORPSE_SECONDS
	add_child(expiry)
	expiry.timeout.connect(_expire)
	expiry.start()
	return true

func _rest_end(from_id: int, to_id: int) -> Vector3:
	return skeleton.get_bone_global_rest(from_id).affine_inverse() * skeleton.get_bone_global_rest(to_id).origin

func _make_segment(bone_name: String, end: Vector3, radius: float, mass: float) -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = end.length() + radius * 2.0
	var shape_basis := Basis(Quaternion(Vector3.UP, end.normalized()))
	_make_body(bone_name, capsule, Transform3D(Basis.IDENTITY, end * .5), Transform3D(shape_basis, Vector3.ZERO), mass)

func _add_foot_shape(leg: String, lower_id: int, foot_id: int) -> void:
	var lower: PhysicalBone3D = bodies_by_bone[leg + "_Lower"]
	var box := BoxShape3D.new()
	box.size = FOOT_BOUNDS[leg][1]
	var collision := CollisionShape3D.new()
	collision.name = "CapturedFootCollision"
	collision.shape = box
	# Foot has no separate physical body. Its frozen local ankle pose and this
	# compound shape both follow Lower, retaining the exact death-pose transform.
	var foot_in_lower: Transform3D = initial_bone_poses[lower_id].affine_inverse() * initial_bone_poses[foot_id]
	collision.transform = lower.body_offset.affine_inverse() * foot_in_lower * Transform3D(Basis.IDENTITY, FOOT_BOUNDS[leg][0])
	lower.add_child(collision)

func _make_body(bone_name: String, shape: Shape3D, offset: Transform3D, shape_offset: Transform3D, mass: float) -> void:
	var body := PhysicalBone3D.new()
	body.name = "Physical_" + bone_name
	body.set("bone_name", bone_name)
	body.body_offset = offset
	body.collision_layer = 0
	body.collision_mask = 0
	body.mass = mass
	body.friction = .8
	body.bounce = 0.0
	body.linear_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
	body.linear_damp = .25
	body.angular_damp = 1.8
	body.can_sleep = true
	var collision := CollisionShape3D.new()
	collision.name = "FittedCollision"
	collision.shape = shape
	collision.transform = shape_offset
	body.add_child(collision)
	simulator.add_child(body)
	bodies.append(body)
	bodies_by_bone[bone_name] = body

func _configure_leg_joints(leg: String) -> void:
	var upper_id: int = skeleton.find_bone(leg + "_Upper")
	var lower_id: int = skeleton.find_bone(leg + "_Lower")
	var foot_id: int = skeleton.find_bone(leg + "_Foot")
	var upper_pose: Transform3D = skeleton.global_transform * initial_bone_poses[upper_id]
	var lower_pose: Transform3D = skeleton.global_transform * initial_bone_poses[lower_id]
	var foot_pose: Transform3D = skeleton.global_transform * initial_bone_poses[foot_id]
	var upper_axis: Vector3 = (lower_pose.origin - upper_pose.origin).normalized()
	var lower_axis: Vector3 = (foot_pose.origin - lower_pose.origin).normalized()
	var upper: PhysicalBone3D = bodies_by_bone[leg + "_Upper"]
	var lower: PhysicalBone3D = bodies_by_bone[leg + "_Lower"]
	# Cone twist uses joint-local X; the capsule itself remains along bone Y.
	var hip_world := Transform3D(Basis(Quaternion(Vector3.RIGHT, upper_axis)), upper_pose.origin)
	upper.joint_offset = upper.global_transform.affine_inverse() * hip_world
	upper.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
	# PhysicalBone3D's dynamic joint constraint properties take DEGREES.
	upper.set("joint_constraints/swing_span", 45.0)
	upper.set("joint_constraints/twist_span", 20.0)
	# Hinge local Z is perpendicular to this knee's current bend plane. If the
	# leg is straight, retain its authored bend plane transformed with Lower.
	var hinge_axis: Vector3 = upper_axis.cross(lower_axis)
	if hinge_axis.length_squared() < .000001:
		var upper_rest: Transform3D = skeleton.get_bone_global_rest(upper_id)
		var lower_rest: Transform3D = skeleton.get_bone_global_rest(lower_id)
		var foot_rest: Transform3D = skeleton.get_bone_global_rest(foot_id)
		var rest_axis: Vector3 = (lower_rest.origin - upper_rest.origin).cross(foot_rest.origin - lower_rest.origin).normalized()
		hinge_axis = lower_pose.basis * lower_rest.basis.inverse() * rest_axis
	if hinge_axis.length_squared() < .000001: hinge_axis = lower_pose.basis.z
	var knee_world := Transform3D(Basis(Quaternion(Vector3.BACK, hinge_axis.normalized())), lower_pose.origin)
	lower.joint_offset = lower.global_transform.affine_inverse() * knee_world
	lower.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
	lower.set("joint_constraints/angular_limit_enabled", true)
	# Limits are centered on the captured death pose, avoiding a rest-pose kick.
	lower.set("joint_constraints/angular_limit_lower", -55.0)
	lower.set("joint_constraints/angular_limit_upper", 55.0)

func _expire() -> void:
	if is_instance_valid(actor): actor.queue_free()

func _fail(reason: String) -> bool:
	failure_reason = reason
	if is_instance_valid(simulator): simulator.free()
	bodies.clear()
	bodies_by_bone.clear()
	push_error("Robot ragdoll: " + reason)
	return false

func _exit_tree() -> void:
	# Both helper and simulator normally disappear with actor; also handle a
	# separately removed helper without leaving physical bodies behind.
	if is_instance_valid(simulator) and not simulator.is_queued_for_deletion(): simulator.queue_free()
