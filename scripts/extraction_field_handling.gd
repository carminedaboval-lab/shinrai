extends RefCounted
## Original field actions. Presentation observes ammunition; it never transfers it.
const ArmEndurance = preload("./extraction_arm_endurance.gd")
const MagazineCheck = preload("./extraction_magazine_check.gd")
var endurance = ArmEndurance.new()
var check = MagazineCheck.new()
var nutrition := {"food":100.0, "hydration":100.0, "energy":100.0}
var result_text := ""
var result_remaining := 0.0
var checked_magazine_uid := ""
var _camera: Camera3D
var _camera_rest := Vector2.ZERO

func _bind_camera(player: Node) -> void:
    if is_instance_valid(player.camera) and _camera != player.camera:
        _camera = player.camera
        _camera_rest = Vector2(_camera.rotation.x, _camera.rotation.y)

func clear_offset(player: Node) -> void:
    _bind_camera(player)
    if is_instance_valid(_camera):
        _camera.rotation.x = _camera_rest.x
        _camera.rotation.y = _camera_rest.y

func clear_readout() -> void:
    result_text = ""
    result_remaining = 0.0
    checked_magazine_uid = ""

func cancel(player: Node, clear_result: bool = true) -> void:
    check.cancel()
    if clear_result:
        clear_readout()
    clear_offset(player)

func reset(player: Node) -> void:
    cancel(player)
    endurance.reset()
    nutrition = {"food":100.0, "hydration":100.0, "energy":100.0}

func can_check(player: Node) -> bool:
    return player.extraction_mode and player.alive and player._controller_gameplay_allowed() and not player.weapon_id.is_empty() and not player.weapon_input_locked and not player.weapon_transition_pending and not player.reloading and not player.bolt_cycle_active and not player.sprinting and not player.healing_active and not player.mantle_active and not player.fly_mode and not player.is_swimming and not player.is_underwater and player.stun_remaining <= 0.0

func begin(player: Node) -> bool:
    if check.active or not can_check(player) or not player._weapon_ready_for_input():
        return false
    cancel(player)
    player._reset_weapon_handling()
    player.set_weapon_lowered(false)
    player.ads = false
    player._fire_requested = false
    player._semi_buffer_remaining = 0.0
    return check.start(player.weapon_id, player.weapon_definition)

func _read_magazine(player: Node) -> void:
    # ammo includes the chamber. Reading must not normalize or replace a record.
    if not player.magazine_inserted:
        result_text = "NO MAGAZINE FITTED"
        checked_magazine_uid = ""
    else:
        var rounds := maxi(0, int(player.ammo) - int(player.chambered))
        result_text = "MAGAZINE  %d / %d" % [rounds, int(player.mag_size)]
        checked_magazine_uid = str(player.inserted_magazine.get("magazine_uid", ""))
    result_remaining = 2.5

func tick(player: Node, delta: float) -> void:
    if not is_finite(delta) or delta <= 0.0:
        return
    _bind_camera(player)
    var active: bool = player.extraction_mode and player.alive and player._controller_gameplay_allowed() and not player.weapon_input_locked and not player.weapon_transition_pending and not player.fly_mode and not player.mantle_active and not player.is_swimming and not player.is_underwater
    if check.active and (not can_check(player) or player.weapon_lowered or check.checked_weapon_id != player.weapon_id):
        cancel(player)
    result_remaining = maxf(0.0, result_remaining - delta)
    if result_remaining <= 0.0:
        result_text = ""
    if check.active:
        player.ads = false
        if check.advance(delta):
            _read_magazine(player)
    endurance.configure(player.weapon_definition)
    var context: Dictionary = nutrition.duplicate()
    context.merge({"active":active, "aiming":player.ads_blend if player.ads and not check.active else 0.0,
        "lowered":player.weapon_lowered and player.weapon_lower_blend > 0.85,
        "sprinting":player.sprinting, "crouching":player.crouching,
        "busy":check.active or player.reloading or player.bolt_cycle_active or player.healing_active or player.weapon_id.is_empty(),
        "arm_impaired":player.medical.arm_impaired() if player.extraction_mode else false,
        "cargo_load_ratio":player.cargo_load_ratio}, true)
    # Empty hands recover naturally without manufacturing sprint stamina.
    if player.weapon_id.is_empty():
        context.lowered = true
        context.busy = false
    endurance.advance(delta, context)
    var offset: Vector2 = endurance.rotation_offset if active and not check.active and not player.reloading and not player.bolt_cycle_active and not player.healing_active and player.stun_remaining <= 0.0 else Vector2.ZERO
    if is_instance_valid(_camera):
        # The weapon and the authoritative sight ray share this camera. Lean owns z.
        _camera.rotation.x = _camera_rest.x + offset.x
        _camera.rotation.y = _camera_rest.y + offset.y

func hud_state() -> Dictionary:
    return {"checking":check.active, "check_ratio":clampf(check.elapsed / maxf(check.duration, 0.001), 0.0, 1.0),
        "message":result_text if not result_text.is_empty() else ("CHECKING MAGAZINE…" if check.active else ""),
        "arms":endurance.value}
