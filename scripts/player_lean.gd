extends RefCounted
## Deliberate grounded peeking. Camera and weapon move together; the body stays put.
const Controls = preload("./shinrai_input.gd")
const DISTANCE := 0.22
const ROLL := deg_to_rad(7.0)
const RESPONSE := 10.0
const CLEARANCE_RADIUS := 0.12
var amount := 0.0
var _camera: Camera3D
var _rest_position := Vector3.ZERO
var _rest_roll := 0.0
var _clearance := SphereShape3D.new()

func _bind(player: CharacterBody3D) -> bool:
    if not is_instance_valid(player.camera):
        return false
    if _camera != player.camera:
        _camera = player.camera
        _rest_position = _camera.position
        _rest_roll = _camera.rotation.z
        amount = 0.0
        _clearance.radius = CLEARANCE_RADIUS
    return true

func allowed(player: CharacterBody3D) -> bool:
    return player.alive and player._controller_gameplay_allowed() and player.is_on_floor() and not player.sprinting and not player.mantle_active and not player.is_swimming and not player.fly_mode and not player.healing_active and not player.weapon_input_locked and player.stun_remaining <= 0.0

func tick(player: CharacterBody3D, delta: float) -> void:
    if not _bind(player):
        return
    var requested := 0.0
    if allowed(player):
        requested = float(Controls.down("lean_right")) - float(Controls.down("lean_left"))
    var next := lerpf(amount, requested, 1.0 - exp(-RESPONSE * maxf(0.0, delta)))
    if absf(next) < 0.0001:
        next = 0.0
    # Recheck the whole path every tick, including recentring and a moving wall.
    # Collision limits take effect immediately; only intentional input is smoothed.
    amount = _safe_amount(player, next)
    _camera.position = _rest_position + Vector3.RIGHT * DISTANCE * amount
    _camera.rotation.z = _rest_roll - ROLL * amount

func _safe_amount(player: CharacterBody3D, desired: float) -> float:
    if is_zero_approx(desired) or not player.is_inside_tree():
        return 0.0
    var camera_parent := _camera.get_parent() as Node3D
    if camera_parent == null:
        return 0.0
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = _clearance
    query.transform = Transform3D(Basis.IDENTITY, camera_parent.to_global(_rest_position))
    query.collision_mask = player.collision_mask if player.collision_mask != 0 else 3
    query.exclude = [player.get_rid()]
    query.margin = 0.008
    var space := player.get_world_3d().direct_space_state
    if not space.intersect_shape(query, 1).is_empty():
        return 0.0
    query.motion = camera_parent.global_basis.x.normalized() * DISTANCE * desired
    var result := space.cast_motion(query)
    if result.size() < 2:
        return 0.0
    var safe := desired * clampf(result[0] - (0.015 if result[0] < 1.0 else 0.0), 0.0, 1.0)
    return safe

func reset(player: CharacterBody3D) -> void:
    if not _bind(player):
        return
    amount = 0.0
    _camera.position = _rest_position
    _camera.rotation.z = _rest_roll
