extends CharacterBody3D

const ControllerInput = preload("./shinrai_input.gd")
const Lean = preload("./player_lean.gd")
var lean_controller = Lean.new()
const CONTROLLER_LOOK_SPEED: float = 2.4
var _controller_crouch := false
var _controller_sprint := false
var _controller_epoch: int = 0

const Medical = preload("./extraction_medical.gd")
var medical := Medical.new()

const Swimming = preload("res://scripts/player_swimming.gd")
var swim_controller = Swimming.new()
var is_swimming := false
var is_underwater := false

const UziViewmodelScript = preload("res://scripts/uzi_viewmodel.gd")
const WeaponCatalog = preload("res://scripts/extraction_weapon_catalog.gd")
const MagazineRecord = preload("./extraction_magazine_record.gd")
const WeaponAudio = preload("./extraction_weapon_audio.gd")
const FieldHandling = preload("./extraction_field_handling.gd")
var field_handling = FieldHandling.new()
var _weapon_audio: Node
var _dry_fire_latched := false
var _bolt_open_played := false
var physical_magazines := false
var physical_reload_handler: Callable
var equipped_clothing: Dictionary = {}
var weapon_id := "uzi"
var weapon_definition: Dictionary = WeaponCatalog.weapon("uzi")
var weapon_input_locked := false
var weapon_transition_pending := false
const AUTO_FIRE_INTERVAL: float = 0.095
# v10.5 recoil: the UZI is a light 9 mm SMG, so the camera climb is deliberately
# modest. Recoil is applied to the actual look direction rather than faking the
# gun downward; sustained automatic fire therefore needs a gentle mouse-down
# correction just like a conventional FPS spray.
const ADS_RECOIL_DEGREES_PER_SHOT: float = 0.18
const HIP_RECOIL_DEGREES_PER_SHOT: float = 0.28
const FLY_SPEED: float = 20.0
const FLY_BOOST_SPEED: float = 55.0
const STUN_MOVE_MULTIPLIER: float = 0.36
const STUN_RECOVERY_IMMUNITY: float = 3.0
const DRONE_STUN_AIM_MULTIPLIER: float = 0.75
const DRONE_STUN_MAX_DURATION: float = 3.0
const LEGACY_STUN_STATUS: String = "STUNNED — movement and weapon disrupted"
const DRONE_STUN_STATUS: String = "DRONE STUN — aim slowed; ADS and sprint unavailable"

signal died
signal shot_fired
signal damage_received(amount: float)
signal healing_cancelled
var extraction_mode := false

# Extraction survival movement. Review mode retains its unrestricted controls.
const STAMINA_DRAIN := 18.0
const STAMINA_RECOVERY := 22.0
const STAMINA_RECOVERY_DELAY := 1.25
const SPRINT_RESTART_STAMINA := 20.0
const JUMP_STAMINA_COST := 12.0
const MANTLE_STAMINA_COST := 18.0
const STANDING_CAPSULE_HEIGHT := 1.75
const CROUCH_CAPSULE_HEIGHT := 1.10
const STANDING_HEAD_HEIGHT := 1.58
const CROUCH_HEAD_HEIGHT := 0.93
const CROUCH_SPEED := 2.10
const PRONE_CAPSULE_HEIGHT := 0.72
const PRONE_HEAD_HEIGHT := 0.34
const PRONE_SPEED := 1.05
const PRONE_PAD_HOLD := 0.45
const STRAFE_SPEED_MULTIPLIER := 0.88
const BACKPEDAL_SPEED_MULTIPLIER := 0.72
const AIR_STEERING_ACCELERATION := 2.0
const JUMP_GROUND_SETTLE := 0.075
const LANDING_JUMP_LOCK := 0.26
const STEP_HEIGHT := 0.32
const CORNER_LOCK_TICKS := 3
const CORNER_LOCK_TRAVEL := 0.0002
const CORNER_LOCK_NUDGE := 0.02
const CORNER_LOCK_SPEED := 0.25
const HEADROOM_RADIUS := 0.35 # Under the body's 0.36: a wall touching your shoulder is not a low ceiling.

var _corner_lock_ticks := 0
var _ground_contact_time := 0.0
var _landing_recovery := 0.0
var _jump_recovery := 0.0
var _air_speed_limit := 0.0
var _movement_was_grounded := false

var stamina := 100.0
var max_stamina := 100.0
var coffee_boost_remaining := 0.0
var _coffee_base_max := 100.0
var sprinting := false
var crouching := false
## Prone is a lower crouch: crouching stays true, so stealth, recoil and the
## existing no-sprint, no-jump and no-mantle rules all apply unchanged.
var prone := false
var _prone_requested := false
var _pad_crouch_hold := 0.0
var _pad_prone_fired := false
var healing_active := false
var cargo_load_ratio := 0.0
var body_collision: CollisionShape3D
var body_capsule: CapsuleShape3D
var _stamina_recovery_delay := 0.0
var _sprint_exhausted := false

var mouse_sensitivity: float = 0.00215
var ads_mouse_multiplier: float = 0.55
var walk_speed: float = 3.85
var sprint_speed: float = 6.65
var acceleration: float = 14.0
var friction: float = 19.0
var jump_velocity: float = 5.1
var gravity: float = 18.0

const MANTLE_MIN_HEIGHT: float = 0.55
const MANTLE_MAX_HEIGHT: float = 1.70
const MANTLE_REACH: float = 0.95
var mantle_active: bool = false
var mantle_start: Vector3 = Vector3.ZERO
var mantle_target: Vector3 = Vector3.ZERO
var mantle_corner: Vector3 = Vector3.ZERO
var mantle_elapsed: float = 0.0
var mantle_duration: float = 0.28
var mantle_saved_layer: int = 1
var mantle_saved_mask: int = 3
var jump_was_down: bool = false
var fly_mode: bool = false
var fly_saved_layer: int = 1
var fly_saved_mask: int = 3

var health: float = 100.0
var ammo: int = 30
var reserve: int = 150
var mag_size: int = 30
var chambered := false
var magazine_inserted := true
var inserted_magazine: Dictionary = {}
var bolt_locked := false
var bolt_cycle_active := false
var bolt_cycle_elapsed := 0.0
var bolt_cycle_duration := 0.0
var _bolt_cycle_weapon_id := ""
var _reload_mag_out := false
var _reload_mag_in := false
var _reload_bolt_released := false
var _reload_chamber_only := false
var kills: int = 0
var wave: int = 1

var weapon_lowered:=false
var weapon_lower_blend:=0.0
var weapon_posture: Node3D
var ads: bool = false
var ads_blend: float = 0.0
var reloading: bool = false
var reload_time: float = 0.0
var reload_duration: float = 2.80
var reload_empty: bool = false
var fire_cooldown: float = 0.0
var recoil_pitch: float = 0.0
var recoil_velocity: float = 0.0
var recoil_burst_shots: int = 0
var recoil_yaw: float = 0.0
var _recoil_idle_time: float = 10.0
var _fire_requested := false
var _trigger_was_down := false
var _sprint_fire_delay := 0.0
var _semi_buffer_remaining := 0.0
var _sprint_pose := 0.0
var weapon_kick: float = 0.0
var muzzle_timer: float = 0.0
var hit_marker: float = 0.0
var damage_flash: float = 0.0
var stun_remaining: float = 0.0
var stun_immunity_remaining: float = 0.0
var drone_stun_active: bool = false
var drone_stun_fx: CanvasLayer
const FaceDroneLatch = preload("player_drone_face_latch.gd")
var face_drone_latch: FaceDroneLatch
var bob_phase: float = 0.0
var alive: bool = true

var head: Node3D
var camera: Camera3D
var aim_focus: CameraAttributesPractical
var weapon: Node3D
var weapon_body: Node3D
var magazine: Node3D
var fresh_magazine: Node3D
var vest_pouch: Node3D
var right_hand: Node3D
var left_hand: Node3D
var left_finger_roots: Array[Node3D] = []
var left_finger_mids: Array[Node3D] = []
var left_finger_tips: Array[Node3D] = []
var left_finger_base_rots: Array[Vector3] = []
var left_finger_curl_bias: Array[float] = []
var right_trigger_root: Node3D
var right_trigger_mid: Node3D
var right_trigger_tip: Node3D
var right_trigger_base_rot: Vector3 = Vector3.ZERO
var left_hand_base_pos: Vector3 = Vector3(-0.135, -0.125, -0.70)
var left_hand_base_rot: Vector3 = Vector3(-0.06, 0.10, 0.12)
var magazine_default_pos: Vector3 = Vector3(0.0, -0.2, -0.25)
var magazine_default_rot: Vector3 = Vector3(-0.12, 0.0, 0.0)
var vest_mag_pos: Vector3 = Vector3(-0.90, -0.22, 0.26)
var vest_mag_rot: Vector3 = Vector3(-0.48, 0.18, -0.42)
var muzzle_light: OmniLight3D
var red_dot: MeshInstance3D
var hud_health: Label
var hud_ammo: Label
var hud_kills: Label
var hud_wave: Label
var hud_status: Label
var crosshair: Label
var ads_dot: Label
var hit_cross: Control
var damage_rect: ColorRect
var uzi_viewmodel: Node3D
const TacticalCrosshair := preload("res://scripts/hud/tactical_crosshair.gd")
const DamageDirection := preload("res://scripts/hud/damage_direction.gd")
const ImpactFX := preload("res://scripts/fx/combat_impact_fx.gd")
const CameraTrauma := preload("res://scripts/fx/camera_trauma.gd")
var tactical_crosshair: TacticalCrosshair
var damage_direction: DamageDirection
var impact_fx: ImpactFX
var camera_trauma: CameraTrauma

# Real WRAD first-person arms. The GLB is CC0 and downloaded once from the
# official GitHub repository, then cached in user:// so later launches are local.
const WRAD_ARMS_URL: String = "https://raw.githubusercontent.com/wwwriks/wrad-arms/main/arms.glb"
const WRAD_ARMS_CACHE: String = "user://wrad_arms.glb"
var real_arms_holder: Node3D
var real_arms_root: Node3D
var real_skeleton: Skeleton3D
var arms_http: HTTPRequest
var real_arms_loaded: bool = false
# Viewmodel-specific rig transforms. Hip fire deliberately shows substantially
# more arm; ADS tucks the rig down just enough to preserve a clean sight picture.
var real_arms_hip_pos: Vector3 = Vector3(-0.18, -0.20, 0.24)
var real_arms_ads_pos: Vector3 = Vector3(-0.02, -0.30, 0.21)
var real_arms_hip_rot: Vector3 = Vector3(deg_to_rad(-1.5), deg_to_rad(180.0), deg_to_rad(1.5))
var real_arms_ads_rot: Vector3 = Vector3(deg_to_rad(-4.0), deg_to_rad(180.0), 0.0)
var real_arms_hip_scale: float = 0.145
var real_arms_ads_scale: float = 0.135
var rig_bones: Dictionary = {}
var rig_base_rotations: Dictionary = {}
var rig_download_failed: bool = false

var hip_weapon_pos: Vector3 = Vector3(0.39, -0.365, -0.84)
var ads_weapon_pos: Vector3 = Vector3(0.0, -0.245, -0.625)

func _ready() -> void:
    ControllerInput.ensure_actions()
    add_to_group("shinrai_input_players")
    _controller_epoch = ControllerInput.release_epoch
    collision_layer = 1
    collision_mask = 1 | 2
    fly_saved_layer = collision_layer
    fly_saved_mask = collision_mask
    _build_collision()
    _build_camera()
    _build_weapon()
    _build_weapon_posture()
    _build_hud()
    camera_trauma = CameraTrauma.new()
    camera_trauma.name = "CameraTrauma"
    add_child(camera_trauma)
    camera_trauma.bind(camera)
    _ensure_impact_fx.call_deferred()
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    _update_hud()
    add_child(preload("res://scripts/urban_explorer_body.gd").new())

func _build_weapon_posture() -> void:
    weapon_posture=Node3D.new()
    weapon_posture.name="WeaponPosture"
    camera.add_child(weapon_posture)
    weapon.reparent(weapon_posture)
    if is_instance_valid(uzi_viewmodel): uzi_viewmodel.reparent(weapon_posture)

func is_weapon_lowered() -> bool:
    return weapon_lowered and weapon_lower_blend>.85

func set_weapon_lowered(value: bool) -> void:
    weapon_lowered=value
    if value:
        ads=false
        field_handling.cancel(self)

func _tick_weapon_posture(delta: float) -> void:
    if not _weapon_handling_allowed(): _reset_weapon_handling()
    weapon_lower_blend=move_toward(weapon_lower_blend,1.0 if weapon_lowered else 0.0,delta*4.5)
    _sprint_pose = lerpf(_sprint_pose, 1.0 if sprinting else 0.0, 1.0 - exp(-16.0 * delta))
    if is_instance_valid(weapon_posture):
        weapon_posture.rotation = Vector3(-0.85, 0.08, 0.12) * weapon_lower_blend + Vector3(-0.28, 0.08, 0.09) * _sprint_pose * (1.0 - weapon_lower_blend)
        weapon_posture.position = Vector3(0, -0.16, 0.04) * weapon_lower_blend + Vector3(0.025, -0.045, 0.03) * _sprint_pose
        weapon_posture.rotation += field_handling.check.rotation_offset
        weapon_posture.position += field_handling.check.position_offset

func _build_collision() -> void:
    floor_snap_length = STEP_HEIGHT + 0.03
    floor_constant_speed = true
    floor_stop_on_slope = true
    var shape_node := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.36
    capsule.height = 1.75
    shape_node.shape = capsule
    shape_node.position = Vector3(0, 0.9, 0)
    add_child(shape_node)
    body_collision = shape_node
    body_capsule = capsule

func _build_camera() -> void:
    head = Node3D.new()
    head.name = "Head"
    head.position = Vector3(0, 1.58, 0)
    add_child(head)

    camera = Camera3D.new()
    camera.name = "Camera3D"
    camera.current = true
    camera.fov = 73.0
    camera.near = 0.012
    # Aim focus: with iron sights the eye focuses on the front sight, so the
    # rear sight a few centimetres away goes soft (the "ghost ring" every
    # shooter shows). Off unless aiming on irons; see _update_aim_focus().
    aim_focus = CameraAttributesPractical.new()
    aim_focus.dof_blur_near_enabled = false
    aim_focus.dof_blur_far_enabled = false
    camera.attributes = aim_focus
    head.add_child(camera)

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.5) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metallic
    mat.roughness = roughness
    return mat

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.position = pos
    mi.rotation = rot
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi

func _capsule(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    mi.mesh = mesh
    mi.position = pos
    mi.rotation = rot
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi

func _ellipsoid(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi: MeshInstance3D = MeshInstance3D.new()
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mi.mesh = mesh
    mi.position = pos
    mi.rotation = rot
    mi.scale = size
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi

func _tapered_arm(parent: Node3D, top_radius: float, bottom_radius: float, height: float, pos: Vector3, mat: Material, rot: Vector3) -> MeshInstance3D:
    var mi: MeshInstance3D = MeshInstance3D.new()
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = top_radius
    mesh.bottom_radius = bottom_radius
    mesh.height = height
    mesh.radial_segments = 20
    mi.mesh = mesh
    mi.position = pos
    mi.rotation = rot
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi

func _finger_segment(parent: Node3D, length: float, radius: float, mat: Material) -> MeshInstance3D:
    var mi: MeshInstance3D = _capsule(parent, radius, length, Vector3(0.0, 0.0, -length * 0.50), mat, Vector3(PI * 0.5, 0.0, 0.0))
    return mi

func _add_static_finger(parent: Node3D, base_pos: Vector3, base_rot: Vector3, lengths: Vector3, radius: float, curls: Vector3, skin_mat: Material, nail_mat: Material) -> void:
    var root_pivot: Node3D = Node3D.new()
    root_pivot.position = base_pos
    root_pivot.rotation = base_rot + Vector3(curls.x, 0.0, 0.0)
    parent.add_child(root_pivot)
    _finger_segment(root_pivot, lengths.x, radius, skin_mat)
    _ellipsoid(root_pivot, Vector3(radius * 2.25, radius * 1.85, radius * 2.1), Vector3.ZERO, skin_mat)

    var mid_pivot: Node3D = Node3D.new()
    mid_pivot.position = Vector3(0.0, 0.0, -lengths.x * 0.91)
    mid_pivot.rotation = Vector3(curls.y, 0.0, 0.0)
    root_pivot.add_child(mid_pivot)
    _finger_segment(mid_pivot, lengths.y, radius * 0.92, skin_mat)
    _ellipsoid(mid_pivot, Vector3(radius * 2.0, radius * 1.65, radius * 1.9), Vector3.ZERO, skin_mat)

    var tip_pivot: Node3D = Node3D.new()
    tip_pivot.position = Vector3(0.0, 0.0, -lengths.y * 0.90)
    tip_pivot.rotation = Vector3(curls.z, 0.0, 0.0)
    mid_pivot.add_child(tip_pivot)
    _finger_segment(tip_pivot, lengths.z, radius * 0.84, skin_mat)

    var nail: MeshInstance3D = _ellipsoid(tip_pivot, Vector3(radius * 1.25, radius * 0.28, lengths.z * 0.40), Vector3(0.0, radius * 0.78, -lengths.z * 0.72), nail_mat, Vector3(0.18, 0.0, 0.0))
    nail.scale.z = maxf(nail.scale.z, 0.012)

func _add_left_finger_chain(base_pos: Vector3, base_rot: Vector3, lengths: Vector3, radius: float, curl_bias: float, skin_mat: Material, nail_mat: Material) -> void:
    var root_pivot: Node3D = Node3D.new()
    root_pivot.position = base_pos
    root_pivot.rotation = base_rot
    left_hand.add_child(root_pivot)
    _finger_segment(root_pivot, lengths.x, radius, skin_mat)
    _ellipsoid(root_pivot, Vector3(radius * 2.25, radius * 1.85, radius * 2.1), Vector3.ZERO, skin_mat)

    var mid_pivot: Node3D = Node3D.new()
    mid_pivot.position = Vector3(0.0, 0.0, -lengths.x * 0.91)
    root_pivot.add_child(mid_pivot)
    _finger_segment(mid_pivot, lengths.y, radius * 0.92, skin_mat)
    _ellipsoid(mid_pivot, Vector3(radius * 2.0, radius * 1.65, radius * 1.9), Vector3.ZERO, skin_mat)

    var tip_pivot: Node3D = Node3D.new()
    tip_pivot.position = Vector3(0.0, 0.0, -lengths.y * 0.90)
    mid_pivot.add_child(tip_pivot)
    _finger_segment(tip_pivot, lengths.z, radius * 0.84, skin_mat)
    _ellipsoid(tip_pivot, Vector3(radius * 1.22, radius * 0.26, lengths.z * 0.40), Vector3(0.0, radius * 0.78, -lengths.z * 0.72), nail_mat, Vector3(0.18, 0.0, 0.0))

    left_finger_roots.append(root_pivot)
    left_finger_mids.append(mid_pivot)
    left_finger_tips.append(tip_pivot)
    left_finger_base_rots.append(base_rot)
    left_finger_curl_bias.append(curl_bias)

func _build_weapon() -> void:
    weapon = Node3D.new()
    weapon.name = "Weapon"
    weapon.position = hip_weapon_pos
    camera.add_child(weapon)

    weapon_body = Node3D.new()
    weapon.add_child(weapon_body)

    var dark := _material(Color(0.055, 0.065, 0.078), 0.6, 0.28)
    var metal := _material(Color(0.12, 0.14, 0.17), 0.75, 0.22)
    var grip_mat := _material(Color(0.025, 0.03, 0.035), 0.15, 0.65)

    _box(weapon_body, Vector3(0.24, 0.18, 0.52), Vector3(0, 0, -0.08), metal)
    _box(weapon_body, Vector3(0.18, 0.14, 0.62), Vector3(0, 0.015, -0.62), dark)
    _box(weapon_body, Vector3(0.07, 0.07, 0.52), Vector3(0, 0.02, -1.14), metal)
    _box(weapon_body, Vector3(0.11, 0.1, 0.18), Vector3(0, 0.02, -1.47), dark)
    _box(weapon_body, Vector3(0.13, 0.32, 0.13), Vector3(-0.01, -0.22, -0.02), grip_mat, Vector3(-0.22, 0, 0))
    _box(weapon_body, Vector3(0.22, 0.13, 0.34), Vector3(0, 0.0, 0.37), dark)

    magazine = Node3D.new()
    magazine.name = "InsertedMagazine"
    magazine.position = magazine_default_pos
    magazine.rotation = magazine_default_rot
    weapon_body.add_child(magazine)
    _box(magazine, Vector3(0.14, 0.34, 0.18), Vector3.ZERO, dark, Vector3(-0.12, 0, 0))

    # Separate fresh magazine used by the reload animation. It begins hidden
    # near the lower-left chest/vest area and only appears once the support
    # hand has reached that location.
    fresh_magazine = Node3D.new()
    fresh_magazine.name = "FreshMagazine"
    fresh_magazine.position = vest_mag_pos
    fresh_magazine.rotation = vest_mag_rot
    fresh_magazine.visible = false
    weapon_body.add_child(fresh_magazine)
    _box(fresh_magazine, Vector3(0.14, 0.34, 0.18), Vector3.ZERO, dark, Vector3(-0.12, 0, 0))

    var optic := Node3D.new()
    optic.position = Vector3(0, 0.16, -0.42)
    weapon_body.add_child(optic)
    _box(optic, Vector3(0.18, 0.06, 0.23), Vector3(0, -0.01, 0), dark)
    _box(optic, Vector3(0.028, 0.19, 0.028), Vector3(-0.075, 0.105, -0.01), dark)
    _box(optic, Vector3(0.028, 0.19, 0.028), Vector3(0.075, 0.105, -0.01), dark)
    _box(optic, Vector3(0.18, 0.028, 0.028), Vector3(0, 0.19, -0.01), dark)

    var lens := MeshInstance3D.new()
    var lens_mesh := QuadMesh.new()
    lens_mesh.size = Vector2(0.135, 0.135)
    lens.mesh = lens_mesh
    lens.position = Vector3(0, 0.105, -0.025)
    lens.rotation = Vector3(0, PI, 0)
    var lens_mat := StandardMaterial3D.new()
    lens_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    lens_mat.albedo_color = Color(0.15, 0.42, 0.5, 0.11)
    lens_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    lens.material_override = lens_mat
    optic.add_child(lens)

    red_dot = MeshInstance3D.new()
    var dot_mesh := SphereMesh.new()
    dot_mesh.radius = 0.006
    dot_mesh.height = 0.012
    red_dot.mesh = dot_mesh
    red_dot.position = Vector3(0, 0.105, -0.045)
    var dot_mat := StandardMaterial3D.new()
    dot_mat.albedo_color = Color(1.0, 0.02, 0.01)
    dot_mat.emission_enabled = true
    dot_mat.emission = Color(1.0, 0.02, 0.01)
    dot_mat.emission_energy_multiplier = 8.0
    dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    red_dot.material_override = dot_mat
    optic.add_child(red_dot)

    # A small chest-rig pouch edge appears only during the vest-grab portion of
    # reloads. It gives the off-screen hand motion a readable physical source.
    vest_pouch = Node3D.new()
    vest_pouch.name = "VestPouch"
    vest_pouch.position = Vector3(-0.48, -0.58, -0.60)
    vest_pouch.rotation = Vector3(-0.18, 0.16, -0.10)
    vest_pouch.visible = false
    camera.add_child(vest_pouch)
    var vest_mat: Material = _material(Color(0.12, 0.14, 0.095), 0.02, 0.92)
    var webbing_mat: Material = _material(Color(0.075, 0.085, 0.060), 0.02, 0.96)
    _box(vest_pouch, Vector3(0.30, 0.30, 0.16), Vector3.ZERO, vest_mat, Vector3(-0.08, 0.0, 0.0))
    _box(vest_pouch, Vector3(0.25, 0.055, 0.18), Vector3(0.0, 0.13, -0.015), webbing_mat)
    _box(vest_pouch, Vector3(0.035, 0.27, 0.185), Vector3(-0.095, 0.0, -0.01), webbing_mat)
    _box(vest_pouch, Vector3(0.035, 0.27, 0.185), Vector3(0.095, 0.0, -0.01), webbing_mat)

    _hide_legacy_viewmodel_meshes(weapon_body)
    _build_uzi_viewmodel()

    muzzle_light = OmniLight3D.new()
    muzzle_light.position = Vector3(0, 0.03, -1.58)
    muzzle_light.light_color = Color(1.0, 0.48, 0.12)
    muzzle_light.light_energy = 0.0
    muzzle_light.omni_range = 5.0
    weapon_body.add_child(muzzle_light)

func _hide_legacy_viewmodel_meshes(node: Node) -> void:
    if node is MeshInstance3D:
        (node as MeshInstance3D).visible = false
    for child: Node in node.get_children():
        _hide_legacy_viewmodel_meshes(child)

func _build_uzi_viewmodel() -> void:
    if is_instance_valid(vest_pouch):
        _hide_legacy_viewmodel_meshes(vest_pouch)
        vest_pouch.visible = false
    uzi_viewmodel = UziViewmodelScript.new() as Node3D
    if uzi_viewmodel == null:
        return
    camera.add_child(uzi_viewmodel)
    uzi_viewmodel.call("configure_handling", weapon_definition)
    uzi_viewmodel.connect("status_changed", Callable(self, "_on_uzi_status_changed"))

func _weapon_handling_allowed() -> bool:
    return not field_handling.check.active and _controller_gameplay_allowed() and not weapon_id.is_empty() and not weapon_input_locked and not weapon_transition_pending and not weapon_lowered and not reloading and not bolt_cycle_active and not sprinting and not healing_active and not mantle_active and not fly_mode and not is_swimming and stun_remaining <= 0.0

func _forward_weapon_look(radians: Vector2) -> void:
    if _weapon_handling_allowed() and is_instance_valid(uzi_viewmodel) and uzi_viewmodel.has_method("add_handling_look_delta"):
        uzi_viewmodel.call("add_handling_look_delta", radians)

func _reset_weapon_handling() -> void:
    if is_instance_valid(uzi_viewmodel) and uzi_viewmodel.has_method("reset_handling"):
        uzi_viewmodel.call("reset_handling")

func _reset_weapon_feedback() -> void:
    field_handling.cancel(self)
    _reset_weapon_handling()
    _dry_fire_latched = false
    if is_instance_valid(_weapon_audio): _weapon_audio.call("reset")

func _play_weapon_sound(event_name: String) -> bool:
    if weapon_id.is_empty() or not is_inside_tree(): return false
    if not is_instance_valid(_weapon_audio):
        _weapon_audio = WeaponAudio.new()
        _weapon_audio.name = "WeaponMechanicsAudio"
        add_child(_weapon_audio)
    return bool(_weapon_audio.call("play_event", event_name, weapon_id))

func _on_uzi_status_changed(text: String) -> void:
    if is_instance_valid(hud_status):
        hud_status.text = text

func can_equip_weapon(id: String) -> bool:
    if id == "uzi":
        return true
    if not WeaponCatalog.available(id):
        return false
    var scene := load(WeaponCatalog.WEAPONS[id].scene) as PackedScene
    if scene == null:
        return false
    var candidate := scene.instantiate() as Node3D
    if candidate == null:
        return false
    var valid := true
    for method: String in ["set_ads_blend", "set_move_speed", "play_fire", "play_reload", "get_reload_duration", "set_optic"]:
        valid = valid and candidate.has_method(method)
    candidate.free()
    return valid

func unequip_weapon() -> bool:
    if weapon_transition_pending: return false
    _cancel_bolt_cycle()
    if not _cancel_physical_reload(): return false
    _reset_recoil()
    _reset_weapon_feedback()
    _fire_requested = false
    _semi_buffer_remaining = 0.0
    weapon_id = ""
    inserted_magazine.clear()
    ammo = 0
    reserve = 0
    chambered = false
    reloading = false
    reload_time = 0.0
    ads = false
    ads_blend = 0.0
    muzzle_timer = 0.0
    if is_instance_valid(uzi_viewmodel): uzi_viewmodel.hide()
    if is_instance_valid(weapon_posture): weapon_posture.hide()
    return true

func hud_weapon_state() -> Dictionary:
    if weapon_id.is_empty(): return {"name":"UNARMED","magazine_capacity":1,"fire_mode":"FIND A WEAPON","reload_ratio":-1.0}
    return {"name": str(weapon_definition.title), "magazine_capacity": mag_size,
        "fire_mode": "BOLT" if _uses_manual_bolt() else ("AUTO" if weapon_definition.mode == "auto" else "SEMI"),
        "bolt_cycle_active": bolt_cycle_active,
        "bolt_cycle_ratio": clampf(bolt_cycle_elapsed / maxf(bolt_cycle_duration, 0.001), 0.0, 1.0) if bolt_cycle_active else -1.0,
        "reload_ratio": clampf(reload_time / maxf(reload_duration, 0.001), 0.0, 1.0) if reloading else -1.0}

func apply_weapon_loadout(id: String, record: Dictionary) -> bool:
    if weapon_transition_pending:
        return false
    if not can_equip_weapon(id):
        return false
    _cancel_bolt_cycle()
    if not _cancel_physical_reload(): return false
    if id != weapon_id:
        var candidate: Node3D
        if id == "uzi":
            candidate = UziViewmodelScript.new()
        else:
            candidate = (load(WeaponCatalog.WEAPONS[id].scene) as PackedScene).instantiate() as Node3D
        if candidate == null:
            return false
        if id != "uzi" and not bool(candidate.call("set_optic", str(record.optic))):
            candidate.free()
            return false
        var previous: Node3D = uzi_viewmodel
        weapon_transition_pending = true
        if candidate.has_method("hold_presentation"):
            candidate.call("hold_presentation", true)
        weapon_posture.add_child(candidate)
        candidate.hide()
        uzi_viewmodel = candidate
        call_deferred("_complete_weapon_transition", previous, candidate)
        if candidate.has_signal("status_changed"):
            candidate.connect("status_changed", Callable(self, "_on_uzi_status_changed"))
        reloading = false
        reload_time = 0.0
        reload_empty = false
        ads = false
        ads_blend = 0.0
        weapon_kick = 0.0
        recoil_pitch = 0.0
        recoil_velocity = 0.0
        recoil_burst_shots = 0
        recoil_yaw = 0.0
        _sprint_fire_delay = 0.0
        _semi_buffer_remaining = 0.0
        _recoil_idle_time = 10.0
        _fire_requested = false
        fire_cooldown = maxf(fire_cooldown, 0.25)
    elif id != "uzi" and not bool(uzi_viewmodel.call("set_optic", str(record.optic))):
        return false
    if is_instance_valid(weapon_posture): weapon_posture.show()
    physical_magazines = bool(record.get("physical_magazines",false))
    weapon_id = id
    weapon_definition = WeaponCatalog.effective(id, str(record.optic))
    _reset_weapon_feedback()
    if is_instance_valid(uzi_viewmodel) and uzi_viewmodel.has_method("configure_handling"):
        uzi_viewmodel.call("configure_handling", weapon_definition)
    mag_size = int(weapon_definition.magazine)
    chambered = bool(record.get("chambered", int(record.ammo) > 0)) and id != "uzi"
    magazine_inserted = bool(record.get("magazine_inserted", true))
    bolt_locked = bool(record.get("bolt_locked", int(record.ammo) == 0)) and id != "uzi" and not chambered
    ammo = clampi(int(record.ammo), 0, mag_size + int(chambered) if magazine_inserted else int(chambered))
    chambered = chambered and ammo > 0
    reserve = clampi(int(record.reserve), 0, 999)
    inserted_magazine = MagazineRecord.normalize(id,record.get("inserted_magazine",{}),maxi(0,ammo-int(chambered))) if physical_magazines and magazine_inserted else {}
    _sync_weapon_magazine()
    return true

func _complete_weapon_transition(previous: Node3D, candidate: Node3D) -> void:
    if is_instance_valid(previous):
        if previous.has_method("play_holster"):
            previous.call("play_holster")
        else:
            create_tween().tween_property(previous, "position:y", previous.position.y - 0.32, 0.22)
        await get_tree().create_timer(0.70 if previous.has_method("play_holster") else 0.28).timeout
        if is_instance_valid(previous):
            previous.hide()
            previous.queue_free()
    if is_instance_valid(candidate):
        if candidate.has_method("hold_presentation"):
            candidate.call("hold_presentation", false)
            candidate.call("play_equip")
        else:
            candidate.show()
    weapon_transition_pending = false

func _weapon_ready_for_input() -> bool:
    if weapon_id.is_empty(): return false
    if bolt_cycle_active: return false
    if weapon_transition_pending:
        return false
    if is_instance_valid(uzi_viewmodel) and uzi_viewmodel.has_method("is_ready_for_input"):
        return bool(uzi_viewmodel.call("is_ready_for_input"))
    return true

func _build_real_arms_system() -> void:
    real_arms_holder = Node3D.new()
    real_arms_holder.name = "RealViewmodelArms"
    # WRAD is authored at a larger Blender scale than this viewmodel. This
    # transform places the shoulders below the camera and the hands around the
    # weapon. Fine tuning can be done here without touching the imported rig.
    # The previous build placed the rig too far below the camera. These values
    # intentionally bring the shoulders/forearms into frame in hip fire while
    # leaving the optic unobstructed once ADS is blended in.
    real_arms_holder.position = real_arms_hip_pos
    real_arms_holder.rotation = real_arms_hip_rot
    real_arms_holder.scale = Vector3.ONE * real_arms_hip_scale
    weapon_body.add_child(real_arms_holder)

    arms_http = HTTPRequest.new()
    arms_http.name = "WRADArmsDownload"
    add_child(arms_http)
    arms_http.request_completed.connect(_on_arms_download_completed)

    if FileAccess.file_exists(WRAD_ARMS_CACHE):
        call_deferred("_load_real_arms_from_cache")
    else:
        var err: Error = arms_http.request(WRAD_ARMS_URL)
        if err != OK:
            rig_download_failed = true

func _on_arms_download_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300 or body.size() < 10000:
        rig_download_failed = true
        if is_instance_valid(hud_status):
            hud_status.text = "Could not download CC0 arm rig — check internet and restart"
        return
    var file: FileAccess = FileAccess.open(WRAD_ARMS_CACHE, FileAccess.WRITE)
    if file == null:
        rig_download_failed = true
        return
    file.store_buffer(body)
    file.close()
    _load_real_arms_from_cache()

func _load_real_arms_from_cache() -> void:
    if real_arms_loaded or not FileAccess.file_exists(WRAD_ARMS_CACHE):
        return
    var document: GLTFDocument = GLTFDocument.new()
    var state: GLTFState = GLTFState.new()
    var err: Error = document.append_from_file(WRAD_ARMS_CACHE, state)
    if err != OK:
        rig_download_failed = true
        return
    var scene: Node = document.generate_scene(state)
    if scene == null:
        rig_download_failed = true
        return
    real_arms_root = scene as Node3D
    if real_arms_root == null:
        scene.queue_free()
        rig_download_failed = true
        return
    real_arms_root.name = "WRAD_Arms_CC0"
    real_arms_holder.add_child(real_arms_root)
    _prepare_real_arm_nodes(real_arms_root)
    real_skeleton = _find_first_skeleton(real_arms_root)
    if real_skeleton == null:
        rig_download_failed = true
        return
    _register_real_arm_bones()
    real_arms_loaded = true
    if is_instance_valid(hud_status):
        hud_status.text = "UZI viewmodel ready · LMB fire · RMB ADS · R reload"

func _prepare_real_arm_nodes(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_node: MeshInstance3D = node as MeshInstance3D
        mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for child: Node in node.get_children():
        _prepare_real_arm_nodes(child)

func _find_first_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child: Node in node.get_children():
        var found: Skeleton3D = _find_first_skeleton(child)
        if found != null:
            return found
    return null

func _bone_side(name_lower: String) -> String:
    if name_lower.ends_with(".l") or name_lower.ends_with("_l") or name_lower.contains("left"):
        return "l"
    if name_lower.ends_with(".r") or name_lower.ends_with("_r") or name_lower.contains("right"):
        return "r"
    return ""

func _register_real_arm_bones() -> void:
    rig_bones.clear()
    rig_base_rotations.clear()
    if real_skeleton == null:
        return
    var bone_count: int = real_skeleton.get_bone_count()
    for i: int in range(bone_count):
        var bone_name: String = String(real_skeleton.get_bone_name(i))
        var lower: String = bone_name.to_lower()
        var side: String = _bone_side(lower)
        if side == "":
            continue
        var key: String = ""
        if lower.contains("wrist") or lower.contains("hand"):
            key = "wrist_" + side
        elif lower.contains("forearm") or lower.contains("lowerarm") or lower.contains("lower_arm"):
            key = "forearm_" + side
        elif lower.contains("upperarm") or lower.contains("upper_arm") or lower.contains("upper arm"):
            key = "upperarm_" + side
        elif lower.contains("finger_index1"):
            key = "index1_" + side
        elif lower.contains("finger_index2"):
            key = "index2_" + side
        elif lower.contains("finger_index3"):
            key = "index3_" + side
        elif lower.contains("finger_middle1"):
            key = "middle1_" + side
        elif lower.contains("finger_middle2"):
            key = "middle2_" + side
        elif lower.contains("finger_middle3"):
            key = "middle3_" + side
        elif lower.contains("finger_ring1"):
            key = "ring1_" + side
        elif lower.contains("finger_ring2"):
            key = "ring2_" + side
        elif lower.contains("finger_ring3"):
            key = "ring3_" + side
        elif lower.contains("finger_pinky1"):
            key = "pinky1_" + side
        elif lower.contains("finger_pinky2"):
            key = "pinky2_" + side
        elif lower.contains("finger_pinky3"):
            key = "pinky3_" + side
        elif lower.contains("finger_thumb1"):
            key = "thumb1_" + side
        elif lower.contains("finger_thumb2"):
            key = "thumb2_" + side
        elif lower.contains("finger_thumb3"):
            key = "thumb3_" + side
        if key != "":
            rig_bones[key] = i
            rig_base_rotations[key] = real_skeleton.get_bone_pose_rotation(i)

func _set_rig_bone_delta(key: String, euler_delta: Vector3, weight: float = 1.0) -> void:
    if real_skeleton == null or not rig_bones.has(key) or not rig_base_rotations.has(key):
        return
    var bone_idx: int = int(rig_bones[key])
    var base_q: Quaternion = rig_base_rotations[key] as Quaternion
    var delta_q: Quaternion = Quaternion.from_euler(euler_delta * clampf(weight, 0.0, 1.0))
    real_skeleton.set_bone_pose_rotation(bone_idx, base_q * delta_q)

func _curl_real_finger(prefix: String, side: String, curl: float) -> void:
    var c: float = clampf(curl, 0.0, 1.0)
    _set_rig_bone_delta(prefix + "1_" + side, Vector3(0.62 * c, 0.0, 0.0))
    _set_rig_bone_delta(prefix + "2_" + side, Vector3(0.82 * c, 0.0, 0.0))
    _set_rig_bone_delta(prefix + "3_" + side, Vector3(0.58 * c, 0.0, 0.0))

func _apply_real_hand_grip(side: String, grip: float, trigger_pull: float = 0.0) -> void:
    var g: float = clampf(grip, 0.0, 1.0)
    _curl_real_finger("middle", side, g)
    _curl_real_finger("ring", side, g * 1.03)
    _curl_real_finger("pinky", side, g * 1.08)
    var index_curl: float = g
    if side == "r":
        index_curl = 0.34 + clampf(trigger_pull, 0.0, 1.0) * 0.48
    _curl_real_finger("index", side, index_curl)
    _set_rig_bone_delta("thumb1_" + side, Vector3(0.25 * g, 0.20 * g, -0.12 * g))
    _set_rig_bone_delta("thumb2_" + side, Vector3(0.34 * g, 0.0, 0.0))
    _set_rig_bone_delta("thumb3_" + side, Vector3(0.22 * g, 0.0, 0.0))

func _animate_real_arm_rig() -> void:
    if not real_arms_loaded or real_skeleton == null:
        return

    # Keep the real rig readable in both stances. The rifle itself continues to
    # use the existing weapon transform, so this only changes the arms and does
    # not disturb the red-dot / firing-ray alignment.
    var arms_pos: Vector3 = real_arms_hip_pos.lerp(real_arms_ads_pos, ads_blend)
    var arms_rot: Vector3 = real_arms_hip_rot.lerp(real_arms_ads_rot, ads_blend)
    var arms_scale: float = lerpf(real_arms_hip_scale, real_arms_ads_scale, ads_blend)
    real_arms_holder.position = arms_pos
    real_arms_holder.rotation = arms_rot
    real_arms_holder.scale = Vector3.ONE * arms_scale

    var trigger_pull: float = 0.0
    if muzzle_timer > 0.0:
        trigger_pull = sin(clampf(muzzle_timer / 0.055, 0.0, 1.0) * PI)
    _apply_real_hand_grip("r", 1.0, trigger_pull)

    var left_grip: float = 1.0
    var left_upper_delta: Vector3 = Vector3.ZERO
    var left_forearm_delta: Vector3 = Vector3.ZERO
    var left_wrist_delta: Vector3 = Vector3(-0.10, 0.06, 0.10)

    if reloading:
        var t: float = clampf(reload_time / reload_duration, 0.0, 1.0)
        # The support arm arcs down-left toward the player's vest, grabs a fresh
        # magazine, then comes back up. Bone rotations create the hand travel;
        # the magazine animation remains synchronized with the same timeline.
        var reach_vest: float = _stage(t, 0.18, 0.56) * (1.0 - _stage(t, 0.67, 0.84))
        var insert_mag: float = _stage(t, 0.65, 0.82) * (1.0 - _stage(t, 0.86, 0.98))
        var grab_mag: float = _stage(t, 0.54, 0.65)
        left_upper_delta = Vector3(-0.62 * reach_vest + 0.18 * insert_mag, -0.16 * insert_mag, 0.78 * reach_vest - 0.28 * insert_mag)
        left_forearm_delta = Vector3(0.95 * reach_vest - 0.46 * insert_mag, -0.34 * reach_vest, -0.22 * insert_mag)
        left_wrist_delta = Vector3(-0.25 - 0.38 * reach_vest + 0.24 * insert_mag, -0.16 * reach_vest, 0.42 * reach_vest + 0.18 * insert_mag)
        left_grip = 1.0 - 0.72 * reach_vest
        left_grip = maxf(left_grip, grab_mag)
        if reload_empty and t > 0.88:
            var bolt_action: float = _stage(t, 0.88, 0.95) * (1.0 - _stage(t, 0.96, 1.0))
            left_upper_delta += Vector3(0.12, -0.18, -0.22) * bolt_action
            left_forearm_delta += Vector3(-0.20, 0.34, 0.08) * bolt_action
            left_wrist_delta += Vector3(0.16, 0.18, -0.20) * bolt_action
            left_grip = lerpf(left_grip, 0.52, bolt_action)

    _apply_real_hand_grip("l", left_grip)
    _set_rig_bone_delta("upperarm_l", left_upper_delta)
    _set_rig_bone_delta("forearm_l", left_forearm_delta)
    _set_rig_bone_delta("wrist_l", left_wrist_delta)

    # Right arm remains anchored to the pistol grip; ADS straightens it a little
    # while recoil gives a tiny believable wrist/forearm impulse.
    var ads_w: float = ads_blend
    _set_rig_bone_delta("wrist_r", Vector3(-0.08 - recoil_pitch * 0.8, -0.04 * ads_w, -0.10 + 0.06 * ads_w))
    _set_rig_bone_delta("forearm_r", Vector3(-0.08 * ads_w, 0.0, 0.05 * ads_w))

func _build_hands(_glove_mat: Material, sleeve_mat: Material, skin_mat: Material) -> void:
    # Cyberpunk-inspired first-person pose: the weapon sits low/right at hip fire,
    # while both hands remain readable. ADS centers the optic, but the wrists and
    # fingers stay underneath the sight picture instead of obscuring the target.
    var nail_mat: Material = _material(Color(0.62, 0.42, 0.32), 0.0, 0.58)
    var seam_mat: Material = _material(Color(0.055, 0.065, 0.075), 0.18, 0.52)
    var cuff_mat: Material = _material(Color(0.045, 0.055, 0.065), 0.12, 0.76)

    right_hand = Node3D.new()
    right_hand.name = "RightHand"
    right_hand.position = Vector3(0.105, -0.205, 0.045)
    right_hand.rotation = Vector3(-0.08, 0.02, -0.08)
    weapon_body.add_child(right_hand)

    # Anatomical palm/back-of-hand volumes instead of a single capsule.
    _ellipsoid(right_hand, Vector3(0.145, 0.072, 0.175), Vector3(0.0, -0.006, -0.010), skin_mat, Vector3(-0.08, 0.0, -0.06))
    _ellipsoid(right_hand, Vector3(0.128, 0.052, 0.135), Vector3(0.0, 0.035, -0.020), skin_mat, Vector3(-0.05, 0.0, -0.06))
    _ellipsoid(right_hand, Vector3(0.105, 0.095, 0.095), Vector3(0.010, -0.040, 0.078), skin_mat)

    # Middle/ring/pinky wrap around the pistol grip. The index finger stays less
    # curled and reads as a separate trigger finger.
    _add_static_finger(right_hand, Vector3(-0.048, 0.010, -0.075), Vector3(0.20, 0.10, -0.12), Vector3(0.062, 0.045, 0.034), 0.0145, Vector3(0.78, 0.70, 0.60), skin_mat, nail_mat)
    _add_static_finger(right_hand, Vector3(-0.014, 0.014, -0.083), Vector3(0.16, 0.04, -0.05), Vector3(0.066, 0.047, 0.035), 0.0148, Vector3(0.82, 0.74, 0.62), skin_mat, nail_mat)
    _add_static_finger(right_hand, Vector3(0.021, 0.012, -0.078), Vector3(0.14, -0.04, 0.03), Vector3(0.062, 0.044, 0.033), 0.0143, Vector3(0.86, 0.76, 0.65), skin_mat, nail_mat)

    # Trigger/index finger is a retained three-joint chain for subtle firing flex.
    right_trigger_root = Node3D.new()
    right_trigger_root.position = Vector3(0.052, 0.020, -0.060)
    right_trigger_base_rot = Vector3(0.06, -0.10, 0.10)
    right_trigger_root.rotation = right_trigger_base_rot + Vector3(0.22, 0.0, 0.0)
    right_hand.add_child(right_trigger_root)
    _finger_segment(right_trigger_root, 0.069, 0.0142, skin_mat)
    right_trigger_mid = Node3D.new()
    right_trigger_mid.position = Vector3(0.0, 0.0, -0.063)
    right_trigger_mid.rotation = Vector3(0.22, 0.0, 0.0)
    right_trigger_root.add_child(right_trigger_mid)
    _finger_segment(right_trigger_mid, 0.048, 0.0130, skin_mat)
    right_trigger_tip = Node3D.new()
    right_trigger_tip.position = Vector3(0.0, 0.0, -0.043)
    right_trigger_tip.rotation = Vector3(0.12, 0.0, 0.0)
    right_trigger_mid.add_child(right_trigger_tip)
    _finger_segment(right_trigger_tip, 0.035, 0.0117, skin_mat)
    _ellipsoid(right_trigger_tip, Vector3(0.017, 0.004, 0.017), Vector3(0.0, 0.011, -0.027), nail_mat, Vector3(0.18, 0.0, 0.0))

    # Thumb wraps across the back of the pistol grip.
    _add_static_finger(right_hand, Vector3(0.071, -0.014, 0.010), Vector3(-0.08, 0.72, -0.58), Vector3(0.054, 0.040, 0.030), 0.0160, Vector3(0.30, 0.48, 0.38), skin_mat, nail_mat)

    # Wrist cuff and tapered forearm: these remain visible at the lower-right in
    # hip fire and slide naturally downward during ADS.
    _tapered_arm(right_hand, 0.058, 0.086, 0.60, Vector3(0.145, -0.250, 0.345), sleeve_mat, Vector3(-0.94, 0.06, -0.20))
    _tapered_arm(right_hand, 0.072, 0.090, 0.22, Vector3(0.215, -0.425, 0.585), sleeve_mat, Vector3(-0.94, 0.06, -0.20))
    _tapered_arm(right_hand, 0.062, 0.067, 0.085, Vector3(0.045, -0.078, 0.120), cuff_mat, Vector3(-0.94, 0.06, -0.20))

    # Small cyberware-style seam plates keep the look modern without copying
    # any specific Cyberpunk model or texture.
    _box(right_hand, Vector3(0.008, 0.004, 0.075), Vector3(-0.030, 0.069, -0.012), seam_mat, Vector3(0.0, 0.18, -0.12))
    _box(right_hand, Vector3(0.008, 0.004, 0.058), Vector3(0.020, 0.067, -0.006), seam_mat, Vector3(0.0, -0.10, 0.08))

    left_hand = Node3D.new()
    left_hand.name = "LeftHand"
    left_hand.position = left_hand_base_pos
    left_hand.rotation = left_hand_base_rot
    weapon_body.add_child(left_hand)

    _ellipsoid(left_hand, Vector3(0.150, 0.075, 0.182), Vector3(0.0, -0.004, -0.006), skin_mat, Vector3(0.04, 0.04, 0.08))
    _ellipsoid(left_hand, Vector3(0.128, 0.052, 0.140), Vector3(-0.006, 0.036, -0.015), skin_mat, Vector3(0.02, 0.03, 0.08))
    _ellipsoid(left_hand, Vector3(0.108, 0.095, 0.098), Vector3(-0.008, -0.043, 0.082), skin_mat)

    left_finger_roots.clear()
    left_finger_mids.clear()
    left_finger_tips.clear()
    left_finger_base_rots.clear()
    left_finger_curl_bias.clear()

    # Four support fingers visibly curl around the handguard. Their independent
    # joints open during the vest reach and close around the fresh magazine.
    _add_left_finger_chain(Vector3(-0.050, 0.010, -0.078), Vector3(0.08, 0.62, -0.18), Vector3(0.064, 0.046, 0.034), 0.0146, 0.96, skin_mat, nail_mat)
    _add_left_finger_chain(Vector3(-0.017, 0.014, -0.086), Vector3(0.06, 0.56, -0.07), Vector3(0.068, 0.048, 0.035), 0.0149, 1.00, skin_mat, nail_mat)
    _add_left_finger_chain(Vector3(0.018, 0.012, -0.082), Vector3(0.05, 0.48, 0.04), Vector3(0.064, 0.045, 0.034), 0.0145, 0.94, skin_mat, nail_mat)
    _add_left_finger_chain(Vector3(0.050, 0.006, -0.071), Vector3(0.04, 0.40, 0.14), Vector3(0.058, 0.041, 0.031), 0.0138, 0.86, skin_mat, nail_mat)
    # Thumb opposes the fingers around the handguard/magazine.
    _add_left_finger_chain(Vector3(0.066, -0.022, 0.015), Vector3(-0.12, -0.64, 0.62), Vector3(0.052, 0.038, 0.028), 0.0160, 0.72, skin_mat, nail_mat)

    _tapered_arm(left_hand, 0.060, 0.088, 0.66, Vector3(-0.135, -0.270, 0.365), sleeve_mat, Vector3(-0.88, -0.04, 0.22))
    _tapered_arm(left_hand, 0.074, 0.093, 0.24, Vector3(-0.220, -0.470, 0.635), sleeve_mat, Vector3(-0.88, -0.04, 0.22))
    _tapered_arm(left_hand, 0.062, 0.068, 0.090, Vector3(-0.045, -0.083, 0.125), cuff_mat, Vector3(-0.88, -0.04, 0.22))
    _box(left_hand, Vector3(0.008, 0.004, 0.074), Vector3(-0.024, 0.069, -0.010), seam_mat, Vector3(0.0, 0.15, -0.08))

    _set_left_finger_grip(1.0)

func _set_left_finger_grip(grip: float) -> void:
    var g: float = clampf(grip, 0.0, 1.0)
    var open_amount: float = 1.0 - g
    var count: int = left_finger_roots.size()
    for i: int in range(count):
        var root_pivot: Node3D = left_finger_roots[i]
        var mid_pivot: Node3D = left_finger_mids[i]
        var tip_pivot: Node3D = left_finger_tips[i]
        var base_rot: Vector3 = left_finger_base_rots[i]
        var bias: float = left_finger_curl_bias[i]
        var is_thumb: bool = i == count - 1
        var spread: float = float(i - 2) * 0.055 * open_amount
        if is_thumb:
            root_pivot.rotation = base_rot + Vector3(0.18 + 0.38 * g, -0.34 * open_amount, -0.30 * open_amount)
            mid_pivot.rotation = Vector3(0.20 + 0.38 * g, 0.0, 0.0)
            tip_pivot.rotation = Vector3(0.12 + 0.26 * g, 0.0, 0.0)
        else:
            root_pivot.rotation = base_rot + Vector3((0.18 + 0.58 * g) * bias, spread, -0.08 * open_amount)
            mid_pivot.rotation = Vector3((0.14 + 0.72 * g) * bias, 0.0, 0.0)
            tip_pivot.rotation = Vector3((0.10 + 0.60 * g) * bias, 0.0, 0.0)

func _animate_trigger_finger() -> void:
    if not is_instance_valid(right_trigger_root):
        return
    var pull: float = clampf(muzzle_timer / 0.055, 0.0, 1.0)
    var eased: float = sin(pull * PI)
    right_trigger_root.rotation = right_trigger_base_rot + Vector3(0.22 + 0.14 * eased, 0.0, 0.0)
    if is_instance_valid(right_trigger_mid):
        right_trigger_mid.rotation = Vector3(0.22 + 0.20 * eased, 0.0, 0.0)
    if is_instance_valid(right_trigger_tip):
        right_trigger_tip.rotation = Vector3(0.12 + 0.16 * eased, 0.0, 0.0)

func _quad_bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
    var u: float = 1.0 - clampf(t, 0.0, 1.0)
    var tt: float = 1.0 - u
    return a * u * u + b * 2.0 * u * tt + c * tt * tt

func _build_hud() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)

    var top := HBoxContainer.new()
    top.position = Vector2(24, 18)
    top.add_theme_constant_override("separation", 24)
    canvas.add_child(top)

    hud_health = Label.new()
    hud_ammo = Label.new()
    hud_kills = Label.new()
    hud_wave = Label.new()
    for label in [hud_health, hud_ammo, hud_kills, hud_wave]:
        label.add_theme_font_size_override("font_size", 20)
        top.add_child(label)

    hud_status = Label.new()
    hud_status.anchor_left = 0.5
    hud_status.anchor_right = 0.5
    hud_status.anchor_top = 1.0
    hud_status.anchor_bottom = 1.0
    hud_status.offset_left = -180
    hud_status.offset_right = 180
    hud_status.offset_top = -62
    hud_status.offset_bottom = -30
    hud_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hud_status.add_theme_font_size_override("font_size", 18)
    hud_status.text = "F3 fly mode · LMB fire · RMB ADS · R reload · WASD move"
    canvas.add_child(hud_status)

    crosshair = Label.new()
    crosshair.text = "+"
    crosshair.anchor_left = 0.5
    crosshair.anchor_right = 0.5
    crosshair.anchor_top = 0.5
    crosshair.anchor_bottom = 0.5
    crosshair.offset_left = -8
    crosshair.offset_right = 8
    crosshair.offset_top = -16
    crosshair.offset_bottom = 16
    crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    crosshair.add_theme_font_size_override("font_size", 22)
    crosshair.name = "Crosshair"
    canvas.add_child(crosshair)

    ads_dot = Label.new()
    ads_dot.text = "•"
    ads_dot.anchor_left = 0.5
    ads_dot.anchor_right = 0.5
    ads_dot.anchor_top = 0.5
    ads_dot.anchor_bottom = 0.5
    ads_dot.offset_left = -10
    ads_dot.offset_right = 10
    ads_dot.offset_top = -18
    ads_dot.offset_bottom = 18
    ads_dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ads_dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    ads_dot.add_theme_font_size_override("font_size", 28)
    ads_dot.add_theme_color_override("font_color", Color(1.0, 0.035, 0.015))
    ads_dot.add_theme_color_override("font_shadow_color", Color(0.35, 0.0, 0.0, 0.75))
    ads_dot.add_theme_constant_override("shadow_offset_x", 1)
    ads_dot.add_theme_constant_override("shadow_offset_y", 1)
    ads_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ads_dot.visible = false
    ads_dot.name = "ADSDot"
    canvas.add_child(ads_dot)

    # Use geometry instead of a font glyph for the hit marker. A Label's glyph
    # bearing/baseline made the visible × sit a few pixels off the camera ray
    # even though its Control rect was centered. These four diagonal strokes
    # are symmetric around the exact viewport center at every resolution.
    hit_cross = Control.new()
    hit_cross.name = "HitMarker"
    hit_cross.anchor_left = 0.5
    hit_cross.anchor_right = 0.5
    hit_cross.anchor_top = 0.5
    hit_cross.anchor_bottom = 0.5
    hit_cross.offset_left = -14.0
    hit_cross.offset_right = 14.0
    hit_cross.offset_top = -14.0
    hit_cross.offset_bottom = 14.0
    hit_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _add_hit_marker_stroke(hit_cross, Vector2(6.0, 6.0), Vector2(10.0, 10.0))
    _add_hit_marker_stroke(hit_cross, Vector2(22.0, 6.0), Vector2(18.0, 10.0))
    _add_hit_marker_stroke(hit_cross, Vector2(6.0, 22.0), Vector2(10.0, 18.0))
    _add_hit_marker_stroke(hit_cross, Vector2(22.0, 22.0), Vector2(18.0, 18.0))
    var hit_mod: Color = hit_cross.modulate
    hit_mod.a = 0.0
    hit_cross.modulate = hit_mod
    canvas.add_child(hit_cross)

    damage_rect = ColorRect.new()
    damage_rect.color = Color(0.7, 0.0, 0.0, 0.0)
    damage_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    damage_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(damage_rect)

    # The drawn crosshair and its markers replace the "+" glyph and the stroke
    # marker. The old nodes stay hidden because their visibility is still the
    # single source of truth for when the crosshair should show.
    crosshair.self_modulate.a = 0.0
    hit_cross.visible = false
    tactical_crosshair = TacticalCrosshair.new()
    canvas.add_child(tactical_crosshair)
    damage_direction = DamageDirection.new()
    canvas.add_child(damage_direction)

func _ensure_impact_fx() -> void:
    if is_instance_valid(impact_fx) or not is_inside_tree() or get_parent() == null:
        return
    impact_fx = ImpactFX.new()
    get_parent().add_child(impact_fx)

func _add_camera_trauma(amount: float) -> void:
    if not is_instance_valid(camera_trauma):
        return
    camera_trauma.reduced_motion = bool(get_meta("reduced_motion", false))
    camera_trauma.add_trauma(amount)

func _show_impact(result: Dictionary) -> void:
    var collider: Object = result.get("collider") as Object
    if not is_instance_valid(impact_fx) or collider == null:
        return
    var actor: bool = collider.has_method("receive_bullet_hit") or collider.has_method("take_damage") or collider is CharacterBody3D
    # Trigger volumes without damage handling are not surfaces.
    if collider is Area3D and not actor:
        return
    # Actors get no bullet hole, since decals would not follow them. Machines
    # spark; people show a puff instead.
    var surface := ImpactFX.Surface.DUST
    if actor and not _is_human_target(collider as Node):
        surface = ImpactFX.Surface.METAL
    var normal: Vector3 = result.get("normal", -camera.global_transform.basis.z)
    if normal.length_squared() < 0.0001:
        normal = -camera.global_transform.basis.z
    impact_fx.spawn_impact(result.position, normal, surface, not actor)

func _is_human_target(node: Node) -> bool:
    var current := node
    for depth in 6:
        if current == null:
            return false
        if current.is_in_group("human_scavs"):
            return true
        current = current.get_parent()
    return false

func register_damage_source(world_position: Vector3, strength: float = 1.0) -> void:
    if alive and is_instance_valid(damage_direction):
        damage_direction.add_source(world_position, strength)

func _add_hit_marker_stroke(parent: Control, start: Vector2, finish: Vector2) -> void:
    var stroke: Line2D = Line2D.new()
    stroke.width = 2.0
    stroke.default_color = Color.WHITE
    stroke.points = PackedVector2Array([start, finish])
    parent.add_child(stroke)

func _input(event: InputEvent) -> void:
    if is_instance_valid(face_drone_latch) and face_drone_latch.consume_space_event(event):
        get_viewport().set_input_as_handled()

func _update_aim_focus() -> void:
    if aim_focus == null:
        return
    var relief := 1.0
    var irons := is_instance_valid(uzi_viewmodel) and str(uzi_viewmodel.get("optic_id") if "optic_id" in uzi_viewmodel else "").is_empty()
    if irons and uzi_viewmodel.has_method("get_ads_eye_relief"):
        relief = float(uzi_viewmodel.call("get_ads_eye_relief"))
    # Only a rear sight close to the eye blurs; long-relief sights (pistol,
    # SVD tangent sight) stay crisp, and optics never blur their reticle.
    var focus := smoothstep(0.55, 1.0, ads_blend) if irons and relief < 0.2 and not weapon_id.is_empty() else 0.0
    aim_focus.dof_blur_near_enabled = focus > 0.001
    if focus > 0.001:
        aim_focus.dof_blur_near_distance = relief + 0.13
        aim_focus.dof_blur_near_transition = 0.11
        aim_focus.dof_blur_amount = 0.07 * focus

func reset_controller_intents() -> void:
    field_handling.cancel(self)
    _cancel_bolt_cycle()
    _reset_weapon_feedback()
    _controller_crouch = false
    _controller_sprint = false
    _pad_crouch_hold = 0.0
    _pad_prone_fired = false
    _fire_requested = false
    _trigger_was_down = false
    _semi_buffer_remaining = 0.0
    sprinting = false
    ads = false
    jump_was_down = false
    _controller_epoch = ControllerInput.release_epoch

func _controller_gameplay_allowed() -> bool:
    return alive and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and ControllerInput.gameplay_ready()

func _apply_controller_look(delta: float) -> void:
    if not _controller_gameplay_allowed() or not is_instance_valid(head): return
    var stick: Vector2 = ControllerInput.look()
    var speed: float = CONTROLLER_LOOK_SPEED * lerpf(1.0, 0.5, smoothstep(0.0, 1.0, ads_blend))
    if drone_stun_active and stun_remaining > 0.0: speed *= DRONE_STUN_AIM_MULTIPLIER
    rotate_y(-stick.x * speed * delta)
    head.rotate_x(-stick.y * speed * delta)
    _forward_weapon_look(-stick * speed * delta)
    var head_rot: Vector3 = head.rotation
    var pitch_limit: float = 89.5 if fly_mode else 84.0
    head_rot.x = clampf(head_rot.x, deg_to_rad(-pitch_limit), deg_to_rad(pitch_limit))
    head.rotation = head_rot

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE and not extraction_mode:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)
            ControllerInput.require_release()
            reset_controller_intents()
        elif event.keycode == KEY_F3 and not extraction_mode:
            _set_fly_mode(not fly_mode)
    if ControllerInput.released(event,"aim"): ads = false
    if not _controller_gameplay_allowed(): return
    if event is InputEventMouseMotion:
        var sens: float = mouse_sensitivity * lerpf(1.0, ads_mouse_multiplier, smoothstep(0.0, 1.0, ads_blend))
        if drone_stun_active and stun_remaining > 0.0: sens *= DRONE_STUN_AIM_MULTIPLIER
        rotate_y(-event.relative.x * sens)
        head.rotate_x(-event.relative.y * sens)
        _forward_weapon_look(-event.relative * sens)
        var head_rot: Vector3 = head.rotation
        var pitch_limit: float = 89.5 if fly_mode else 84.0
        head_rot.x = clampf(head_rot.x, deg_to_rad(-pitch_limit), deg_to_rad(pitch_limit))
        head.rotation = head_rot
    if event is InputEventJoypadButton:
        # B is held to dive while swimming, toggled only for ground stance.
        if ControllerInput.pressed(event,"crouch") and not is_swimming:
            _controller_crouch = not _controller_crouch
            if _controller_crouch: _controller_sprint = false
        if ControllerInput.pressed(event,"sprint"):
            _controller_sprint = not _controller_sprint
            if _controller_sprint: _controller_crouch = false
    if ControllerInput.pressed(event,"prone") and extraction_mode and not is_swimming:
        _prone_requested = not _prone_requested
    if ControllerInput.pressed(event,"lower_weapon") and extraction_mode and not weapon_input_locked and not reloading:
        set_weapon_lowered(not weapon_lowered)
    if fly_mode: return
    if ControllerInput.pressed(event,"mag_check"):
        field_handling.begin(self)
    if ControllerInput.pressed(event,"reload"):
        if event is InputEventJoypadButton and ControllerInput.down("inspect"):
            field_handling.begin(self)
        else:
            _cancel_healing_for_weapon_action()
            start_reload()
    if ControllerInput.pressed(event,"fire"):
        if field_handling.check.active:
            field_handling.cancel(self)
            _sprint_fire_delay = maxf(_sprint_fire_delay, 0.18)
        _cancel_healing_for_weapon_action()
        _fire_requested = true
    if ControllerInput.pressed(event,"aim"):
        field_handling.cancel(self)
        set_weapon_lowered(false)
        ads = not weapon_id.is_empty() and not weapon_input_locked and not reloading and not bolt_cycle_active and stun_remaining <= 0.0 and not (extraction_mode and (healing_active or mantle_active))
        if is_instance_valid(crosshair) and ads: crosshair.visible = false

func _physics_process(delta: float) -> void:
    if _controller_epoch != ControllerInput.release_epoch or not _controller_gameplay_allowed():
        reset_controller_intents()
    _apply_controller_look(delta)
    if not ControllerInput.down("aim"): ads = false
    if is_instance_valid(face_drone_latch) and (face_drone_latch.is_active() or face_drone_latch.blocks_jump()):
        face_drone_latch.tick(delta)
    if not alive:
        if drone_stun_active or stun_remaining > 0.0:
            clear_stun()
        return

    _tick_coffee_boost(delta)
    var was_stunned := stun_remaining > 0.0
    stun_remaining = maxf(0.0, stun_remaining - delta)
    stun_immunity_remaining = maxf(0.0, stun_immunity_remaining - delta)
    if drone_stun_active:
        if is_instance_valid(drone_stun_fx):
            drone_stun_fx.call("update_remaining", stun_remaining)
        if stun_remaining <= 0.0:
            drone_stun_active = false
    if was_stunned and stun_remaining <= 0.0:
        _restore_stun_status()
    if stun_remaining > 0.0 or bolt_cycle_active or field_handling.check.active or (extraction_mode and healing_active):
        ads = false

    if fly_mode:
        _tick_blocked_weapon(delta)
        _process_fly_mode(delta)
        return

    var jump_down: bool = _controller_gameplay_allowed() and ControllerInput.down("jump") and (extraction_mode or not _is_legacy_stunned())
    if mantle_active:
        _tick_blocked_weapon(delta)
        if extraction_mode:
            sprinting = false
            _tick_stamina(delta, false, false)
        _process_mantle(delta)
        jump_was_down = jump_down
        return

    muzzle_timer = maxf(0.0, muzzle_timer - delta)
    hit_marker = maxf(0.0, hit_marker - delta)
    damage_flash = maxf(0.0, damage_flash - delta * 2.5)
    muzzle_light.light_energy = 9.0 if muzzle_timer > 0.0 and weapon_id == "uzi" else 0.0
    _animate_trigger_finger()
    var hit_mod: Color = hit_cross.modulate
    hit_mod.a = clampf(hit_marker * 9.0, 0.0, 1.0)
    hit_cross.modulate = hit_mod
    var damage_color := Color(0.7, 0.0, 0.0, clampf(damage_flash * 0.22, 0.0, 0.24))
    if _is_legacy_stunned() and damage_flash < 0.25:
        damage_color = Color(0.09, 0.31, 0.72, minf(0.13, stun_remaining * 0.12))
    damage_rect.color = damage_color
    if is_instance_valid(tactical_crosshair):
        tactical_crosshair.ticks_visible = is_instance_valid(crosshair) and crosshair.visible
        if not weapon_id.is_empty():
            tactical_crosshair.set_spread(_get_shot_spread(), camera.fov)

    if reloading:
        reload_time += delta
        _advance_reload_events(reload_time / maxf(reload_duration, 0.001))
        if reload_time >= reload_duration:
            _finish_reload()

    ads_blend = move_toward(ads_blend, 1.0 if ads and not reloading else 0.0, delta * float(weapon_definition.ads_speed))
    # Eased like other shooters' aim-in, so the zoom settles instead of stopping dead.
    camera.fov = lerpf(73.0, float(weapon_definition.ads_fov), smoothstep(0.0, 1.0, ads_blend))
    _update_aim_focus()

    var gameplay_allowed: bool = _controller_gameplay_allowed()
    var input_vec: Vector2 = ControllerInput.movement() if gameplay_allowed else Vector2.ZERO
    if sprinting:
        _sprint_fire_delay = float(weapon_definition.get("sprint_to_fire", 0.24))
    else:
        _sprint_fire_delay = maxf(0.0, _sprint_fire_delay - delta)
    var wants_weapon: bool = _fire_requested or (gameplay_allowed and ControllerInput.down("fire"))
    if wants_weapon or ads: _controller_sprint = false
    var sprint_requested: bool = gameplay_allowed and not wants_weapon and (Input.is_key_pressed(KEY_SHIFT) or _controller_sprint)
    var crouch_requested: bool = gameplay_allowed and (ControllerInput.down("crouch") if is_swimming else (Input.is_key_pressed(KEY_CTRL) or _controller_crouch))
    if is_swimming:
        _controller_crouch = false
        _prone_requested = false
    _tick_pad_prone(delta, gameplay_allowed)
    if jump_down and not jump_was_down: _prone_requested = false
    if sprint_requested and field_handling.check.active:
        field_handling.cancel(self)
    if _advance_ground_movement(delta, input_vec, sprint_requested, crouch_requested, jump_down):
        _tick_blocked_weapon(delta)
        return

    lean_controller.tick(self, delta)
    field_handling.tick(self, delta)
    _tick_weapon_posture(delta)
    _advance_weapon_fire(delta)
    var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
    bob_phase += horizontal_speed * delta * 1.8

    _tick_recoil(delta)
    weapon_kick = move_toward(weapon_kick, 0.0, delta * 5.8)

    _animate_weapon(horizontal_speed)
    if is_instance_valid(uzi_viewmodel):
        uzi_viewmodel.call("set_ads_blend", ads_blend)
        uzi_viewmodel.call("set_move_speed", horizontal_speed)
    _update_hud()
    jump_was_down = jump_down

func reset_survival() -> void:
    reset_controller_intents()
    field_handling.reset(self)
    _reset_recoil()
    _sprint_fire_delay = 0.0
    _sprint_pose = 0.0
    lean_controller.reset(self)
    set_weapon_lowered(false)
    weapon_lower_blend=0.0
    reset_medical()
    if is_instance_valid(face_drone_latch):
        face_drone_latch.release(null, "reset")
    clear_coffee_boost()
    swim_controller.reset(self)
    stamina = max_stamina
    sprinting = false
    crouching = false
    prone = false
    _prone_requested = false
    healing_active = false
    cargo_load_ratio = 0.0
    _stamina_recovery_delay = 0.0
    _sprint_exhausted = false
    jump_was_down = false
    _ground_contact_time = 0.0
    _landing_recovery = 0.0
    _jump_recovery = 0.0
    _air_speed_limit = 0.0
    _movement_was_grounded = false
    if mantle_active:
        collision_layer = mantle_saved_layer
        collision_mask = mantle_saved_mask
    mantle_active = false
    _set_crouch_state(false)
    if is_instance_valid(head):
        head.position.y = STANDING_HEAD_HEIGHT

func set_cargo_mass(used_kg: float, limit_kg: float) -> void:
    cargo_load_ratio = clampf(used_kg / maxf(0.001, limit_kg), 0.0, 1.0)

func set_cargo_load(used: int, capacity: int) -> void:
    cargo_load_ratio = clampf(float(used) / float(maxi(1, capacity)), 0.0, 1.0)

func set_medical_active(value: bool) -> void:
    healing_active = value and extraction_mode and alive
    if healing_active:
        field_handling.cancel(self)
        _cancel_bolt_cycle()
        ads = false
        sprinting = false

func _cancel_healing_for_weapon_action() -> void:
    if extraction_mode and healing_active:
        healing_active = false
        healing_cancelled.emit()

func _can_sprint(input_vec: Vector2) -> bool:
    if extraction_mode and medical.leg_impaired(): return false
    return is_on_floor() and input_vec.y < -0.55 and _landing_recovery <= 0.0 and not ads and ads_blend < 0.25 and not reloading and not healing_active and not crouching and stun_remaining <= 0.0 and not mantle_active

func _tick_stamina(delta: float, wants_sprint: bool, eligible: bool) -> void:
    delta = maxf(delta, 0.0)
    stamina = clampf(stamina, 0.0, max_stamina)
    if stamina <= 0.0:
        _sprint_exhausted = true
    if _sprint_exhausted and stamina >= SPRINT_RESTART_STAMINA:
        _sprint_exhausted = false
    sprinting = wants_sprint and eligible and not _sprint_exhausted and stamina > 0.0
    if sprinting:
        stamina = maxf(0.0, stamina - STAMINA_DRAIN * lerpf(1.0, 1.30, cargo_load_ratio) * delta)
        _stamina_recovery_delay = STAMINA_RECOVERY_DELAY
        if stamina <= 0.0:
            sprinting = false
            _sprint_exhausted = true
    else:
        # Recover only the part of this frame that falls after the delay.
        var recovery_time := maxf(0.0, delta - _stamina_recovery_delay)
        _stamina_recovery_delay = maxf(0.0, _stamina_recovery_delay - delta)
        stamina = minf(max_stamina, stamina + STAMINA_RECOVERY * (1.04 if coffee_boost_remaining > 0.0 else 1.0) * recovery_time)

func _spend_stamina(amount: float) -> void:
    stamina = maxf(0.0, stamina - amount)
    _stamina_recovery_delay = STAMINA_RECOVERY_DELAY
    if stamina <= 0.0:
        _sprint_exhausted = true
        sprinting = false

func movement_speed() -> float:
    var speed := sprint_speed if sprinting else walk_speed
    if extraction_mode:
        if prone:
            speed = PRONE_SPEED
        elif crouching:
            speed = CROUCH_SPEED
        elif sprinting:
            speed *= lerpf(1.0, 0.85, cargo_load_ratio)
        else:
            speed *= lerpf(1.0, 0.90, cargo_load_ratio)
    if ads_blend > 0.5:
        speed *= 0.72
    if extraction_mode and medical.leg_impaired():
        speed *= 0.55
    if extraction_mode and healing_active:
        speed *= 0.55
    if _is_legacy_stunned():
        speed *= STUN_MOVE_MULTIPLIER
    if _landing_recovery > 0.0:
        speed *= 0.78
    return speed

func _set_crouch_state(value: bool) -> void:
    crouching = value
    if not value: prone = false
    _apply_stance_capsule()

func _set_prone_state(value: bool) -> void:
    prone = value
    if value: crouching = true
    _apply_stance_capsule()

func _apply_stance_capsule() -> void:
    if body_capsule == null or not is_instance_valid(body_collision):
        return
    var height := PRONE_CAPSULE_HEIGHT if prone else (CROUCH_CAPSULE_HEIGHT if crouching else STANDING_CAPSULE_HEIGHT)
    body_capsule.height = height
    # The 25 mm lift matches the standing and crouch capsule offsets.
    body_collision.position.y = height * 0.5 + 0.025

func _crouch_capsule_clear() -> bool:
    if not is_inside_tree():
        return false
    var shape := CapsuleShape3D.new()
    shape.radius = HEADROOM_RADIUS
    shape.height = CROUCH_CAPSULE_HEIGHT
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = shape
    query.transform = Transform3D(global_transform.basis, global_position + Vector3.UP * 0.005) * Transform3D(Basis.IDENTITY, Vector3(0.0, CROUCH_CAPSULE_HEIGHT * 0.5 + 0.025, 0.0))
    query.collision_mask = collision_mask
    query.exclude = [get_rid()]
    query.margin = 0.001
    return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

## Controller: tap B crouches, hold it to go prone. The tap toggle has already
## run on the press, so the hold undoes it to keep both stances independent.
func _tick_pad_prone(delta: float, gameplay_allowed: bool) -> void:
    if not extraction_mode or not gameplay_allowed or is_swimming or not ControllerInput.gamepad_active() or not ControllerInput.down("crouch"):
        _pad_crouch_hold = 0.0
        _pad_prone_fired = false
        return
    _pad_crouch_hold += delta
    if _pad_crouch_hold >= PRONE_PAD_HOLD and not _pad_prone_fired:
        _pad_prone_fired = true
        _controller_crouch = not _controller_crouch
        _prone_requested = not _prone_requested

func _standing_capsule_clear(at: Vector3) -> bool:
    if not is_inside_tree():
        return false
    var shape := CapsuleShape3D.new()
    shape.radius = HEADROOM_RADIUS
    shape.height = STANDING_CAPSULE_HEIGHT
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = shape
    # Floor contact can put the capsule bottom exactly on its support surface.
    # A 5 mm upward query allowance avoids mistaking that floor for a ceiling.
    query.transform = Transform3D(global_transform.basis, at + Vector3.UP * 0.005) * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.90, 0.0))
    query.collision_mask = collision_mask
    query.exclude = [get_rid()]
    query.margin = 0.001
    return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _can_stand() -> bool:
    return _standing_capsule_clear(global_position)

func _standing_capsule_sweep_clear(start: Vector3, finish: Vector3) -> bool:
    if not _standing_capsule_clear(start) or not _standing_capsule_clear(finish):
        return false
    var motion := finish - start
    if motion.length_squared() < 0.000001:
        return true
    var shape := CapsuleShape3D.new()
    shape.radius = 0.36
    shape.height = STANDING_CAPSULE_HEIGHT
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = shape
    query.transform = Transform3D(global_transform.basis, start + Vector3.UP * 0.005) * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.90, 0.0))
    query.collision_mask = collision_mask
    query.exclude = [get_rid()]
    query.margin = 0.001
    query.motion = motion
    var clearance := get_world_3d().direct_space_state.cast_motion(query)
    return clearance.size() >= 2 and clearance[0] >= 0.999

func _update_stance(delta: float, requested: bool) -> void:
    if _prone_requested:
        if not prone:
            _set_prone_state(true)
    elif prone and _crouch_capsule_clear():
        # Low cover, such as a fence hole, keeps the player down until clear.
        _set_prone_state(false)
    if not prone:
        if requested:
            if not crouching:
                _set_crouch_state(true)
        elif crouching and _can_stand():
            _set_crouch_state(false)
    if is_instance_valid(head):
        var target := PRONE_HEAD_HEIGHT if prone else (CROUCH_HEAD_HEIGHT if crouching else STANDING_HEAD_HEIGHT)
        head.position.y = move_toward(head.position.y, target, maxf(delta, 0.0) * 4.40)

func _advance_ground_movement(delta: float, input_vec: Vector2, sprint_requested: bool, crouch_requested: bool, jump_down: bool) -> bool:
    delta = maxf(0.0, delta)
    _landing_recovery = maxf(0.0, _landing_recovery - delta)
    _jump_recovery = maxf(0.0, _jump_recovery - delta)
    if drone_stun_active and stun_remaining > 0.0:
        sprint_requested = false
    if mantle_active:
        if extraction_mode:
            _tick_stamina(delta, false, false)
        _process_mantle(delta)
        jump_was_down = jump_down
        return true
    if swim_controller.advance(self, delta, input_vec, sprint_requested, crouch_requested, jump_down):
        _ground_contact_time = 0.0
        _movement_was_grounded = false
        _air_speed_limit = Vector2(velocity.x, velocity.z).length()
        return false
    # Consumed latch presses block ground jump/mantle; swimming retains its raw Space input.
    if is_instance_valid(face_drone_latch) and face_drone_latch.blocks_jump():
        jump_down = false
    input_vec = input_vec.limit_length(1.0)
    var grounded := is_on_floor()
    _ground_contact_time = _ground_contact_time + delta if grounded else 0.0
    if not grounded and _movement_was_grounded:
        _air_speed_limit = Vector2(velocity.x, velocity.z).length()
    var stamina_before_move := stamina
    var recovery_delay_before_move := _stamina_recovery_delay
    var exhausted_before_move := _sprint_exhausted
    if extraction_mode:
        _update_stance(delta, crouch_requested)
        _tick_stamina(delta, sprint_requested, _can_sprint(input_vec))
    else:
        sprinting = sprint_requested and _can_sprint(input_vec)
    var basis := global_transform.basis
    var wish := basis.x * input_vec.x + basis.z * input_vec.y
    wish.y = 0.0
    wish = wish.normalized() * input_vec.length()
    var speed := movement_speed() * _directional_speed_multiplier(input_vec)
    var horizontal := _advance_horizontal_velocity(Vector2(velocity.x, velocity.z), Vector2(wish.x, wish.z) * speed, grounded, delta)
    velocity.x = horizontal.x
    velocity.z = horizontal.y
    var jump_pressed := jump_down and not jump_was_down
    var jumped_this_tick := false
    if jump_pressed and _jump_recovery <= 0.0 and _try_start_mantle(wish):
        jump_was_down = jump_down
        return true
    if not grounded:
        velocity.y -= gravity * delta
    else:
        var can_jump := jump_pressed and _jump_recovery <= 0.0 and _ground_contact_time >= JUMP_GROUND_SETTLE
        if extraction_mode:
            can_jump = can_jump and not crouching and not healing_active and not medical.leg_impaired() and not _is_legacy_stunned() and stamina >= JUMP_STAMINA_COST
        if can_jump:
            jumped_this_tick = true
            velocity.y = jump_velocity * (lerpf(1.0, 0.88, cargo_load_ratio) if extraction_mode else 1.0)
            # Jumping preserves takeoff momentum, but never creates a speed boost.
            _air_speed_limit = horizontal.length()
            _ground_contact_time = 0.0
            sprinting = false
            if extraction_mode:
                _spend_stamina(JUMP_STAMINA_COST)
        else:
            velocity.y = 0.0
            if wish.length_squared() > 0.01:
                _try_step_up(Vector3(velocity.x, 0.0, velocity.z) * delta)
    var impact_speed := maxf(0.0, -velocity.y)
    var moved_from := global_position
    move_and_slide()
    _free_corner_lock(wish, moved_from)
    if grounded and Vector2(velocity.x, velocity.z).length_squared() < 0.01:
        # Holding sprint into a wall must not spend stamina or keep the weapon in
        # its sprint pose. Preserve pre-frame recovery state when no sprint occurred.
        if extraction_mode and stamina < stamina_before_move and not jumped_this_tick:
            stamina = stamina_before_move
            _stamina_recovery_delay = recovery_delay_before_move
            _sprint_exhausted = exhausted_before_move
        sprinting = false
    if not grounded and is_on_floor() and impact_speed > 3.0:
        var severity := clampf((impact_speed - 3.0) / 9.0, 0.0, 1.0)
        _landing_recovery = lerpf(0.14, 0.38, severity)
        _jump_recovery = LANDING_JUMP_LOCK + severity * 0.12
        velocity.x *= lerpf(0.96, 0.82, severity)
        velocity.z *= lerpf(0.96, 0.82, severity)
        _ground_contact_time = 0.0
        sprinting = false
    _movement_was_grounded = grounded
    jump_was_down = jump_down
    return false

## A capsule square to a box's upright corner can lock solid in the motion test,
## stopped dead with nothing in the way. The nudge lands only where the whole
## capsule fits, so a wall the player is simply walking into never gives way.
func _free_corner_lock(wish: Vector3, moved_from: Vector3) -> void:
    if wish.length_squared() < 0.01 or global_position.distance_to(moved_from) > CORNER_LOCK_TRAVEL:
        _corner_lock_ticks = 0
        return
    _corner_lock_ticks += 1
    if _corner_lock_ticks < CORNER_LOCK_TICKS:
        return
    _corner_lock_ticks = 0
    # A wall takes the speed away; a locked capsule keeps it and goes nowhere.
    var locked := Vector2(velocity.x, velocity.z).length() > CORNER_LOCK_SPEED
    var turns: Array[float] = [0.0, -PI * 0.25, PI * 0.25]
    if locked:
        turns.append_array([-PI * 0.5, PI * 0.5, -PI * 0.75, PI * 0.75, PI])
    for turn: float in turns:
        var at := global_position + wish.normalized().rotated(Vector3.UP, turn) * CORNER_LOCK_NUDGE
        if _body_capsule_clear(at):
            global_position = at
            return
        # On a ramp the way up only fits lifted; floor snap takes it straight back down.
        at += Vector3.UP * CORNER_LOCK_NUDGE
        if locked and _body_capsule_clear(at):
            global_position = at
            return

func _body_capsule_clear(at: Vector3) -> bool:
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = body_capsule
    # The same 5 mm allowance as the stance checks, so the floor doesn't count.
    query.transform = Transform3D(global_transform.basis, at + Vector3.UP * 0.005) * body_collision.transform
    query.collision_mask = collision_mask
    query.exclude = [get_rid()]
    query.margin = 0.001
    return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _directional_speed_multiplier(input_vec: Vector2) -> float:
    if input_vec.length_squared() < 0.0001:
        return 1.0
    var direction := input_vec.normalized()
    # An ellipse keeps diagonals between their forward/back and strafe limits.
    var longitudinal := BACKPEDAL_SPEED_MULTIPLIER if direction.y > 0.0 else 1.0
    return 1.0 / sqrt(pow(direction.x / STRAFE_SPEED_MULTIPLIER, 2.0) + pow(direction.y / longitudinal, 2.0))

func _advance_horizontal_velocity(current: Vector2, target: Vector2, grounded: bool, delta: float) -> Vector2:
    if not grounded:
        # Small course corrections only. Looking/strafe input cannot build air speed.
        if target.length_squared() < 0.0001:
            return current
        var air_target := target.limit_length(_air_speed_limit)
        return current.move_toward(air_target, AIR_STEERING_ACCELERATION * delta).limit_length(maxf(_air_speed_limit, current.length()))
    var rate := acceleration
    if target.length_squared() < 0.0001 or current.dot(target) < 0.0:
        rate = friction
    if extraction_mode:
        rate *= lerpf(1.0, 0.76, cargo_load_ratio)
    if crouching:
        rate *= 0.85
    # A single vector step avoids faster diagonal acceleration and braking.
    return current.move_toward(target, rate * delta)

func _try_step_up(horizontal_motion: Vector3) -> bool:
    if horizontal_motion.length_squared() < 0.000001 or not is_on_floor():
        return false
    var obstacle := KinematicCollision3D.new()
    if not test_move(global_transform, horizontal_motion, obstacle) or obstacle.get_normal().y > cos(floor_max_angle):
        return false
    var raised := global_transform
    if test_move(raised, Vector3.UP * STEP_HEIGHT):
        return false
    raised.origin.y += STEP_HEIGHT
    if test_move(raised, horizontal_motion):
        return false
    # A capsule hits a stair corner with a diagonal normal even when its tread is
    # flat. Read the actual tread beneath the leading foot, not that corner normal.
    var probe := global_position + horizontal_motion.normalized() * (body_capsule.radius + 0.08)
    var query := PhysicsRayQueryParameters3D.create(probe + Vector3.UP * (STEP_HEIGHT + 0.04), probe + Vector3.DOWN * 0.02, collision_mask, [get_rid()])
    var support := get_world_3d().direct_space_state.intersect_ray(query)
    if support.is_empty() or Vector3(support.normal).dot(Vector3.UP) < cos(floor_max_angle):
        return false
    var foot_offset := body_collision.position.y - body_capsule.height * 0.5
    var lift: float = support.position.y - global_position.y - foot_offset + 0.002
    if lift <= 0.015 or lift > STEP_HEIGHT:
        return false
    global_position.y += lift
    # Keep the eye position continuous; stance smoothing catches up after the step.
    if extraction_mode and is_instance_valid(head):
        head.position.y -= lift
    return true

func _set_fly_mode(enabled: bool) -> void:
    _cancel_bolt_cycle()
    _cancel_physical_reload()
    swim_controller.reset(self)
    fly_mode = enabled
    lean_controller.reset(self)
    velocity = Vector3.ZERO
    mantle_active = false
    ads = false
    reloading = false
    jump_was_down = false
    _ground_contact_time = 0.0
    _landing_recovery = 0.0
    _jump_recovery = 0.0
    _air_speed_limit = 0.0
    _movement_was_grounded = false
    if fly_mode:
        fly_saved_layer = collision_layer
        fly_saved_mask = collision_mask
        collision_layer = 0
        collision_mask = 0
        motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
    else:
        collision_layer = fly_saved_layer
        collision_mask = fly_saved_mask
        motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
    if is_instance_valid(weapon):
        weapon.visible = not fly_mode
    if is_instance_valid(uzi_viewmodel):
        uzi_viewmodel.visible = not fly_mode
    if is_instance_valid(crosshair):
        crosshair.visible = not fly_mode
    if is_instance_valid(ads_dot):
        ads_dot.visible = false
    if is_instance_valid(hud_status):
        hud_status.text = (
            "FLY MODE · WASD move · Space/E rise · Ctrl/Q descend · Shift boost · F3 exit"
            if fly_mode
            else "F3 fly mode · LMB fire · RMB ADS · R reload · WASD move"
        )

func _process_fly_mode(delta: float) -> void:
    var input_vec := Vector2.ZERO
    if Input.is_key_pressed(KEY_W): input_vec.y -= 1.0
    if Input.is_key_pressed(KEY_S): input_vec.y += 1.0
    if Input.is_key_pressed(KEY_A): input_vec.x -= 1.0
    if Input.is_key_pressed(KEY_D): input_vec.x += 1.0
    input_vec = input_vec.normalized()

    var basis := global_transform.basis
    var fly_direction := basis.x * input_vec.x + basis.z * input_vec.y
    if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E):
        fly_direction.y += 1.0
    if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_Q):
        fly_direction.y -= 1.0
    if fly_direction.length_squared() > 0.0001:
        fly_direction = fly_direction.normalized()
    var speed := FLY_BOOST_SPEED if Input.is_key_pressed(KEY_SHIFT) else FLY_SPEED
    global_position += fly_direction * speed * delta
    velocity = Vector3.ZERO

func _try_start_mantle(wish: Vector3) -> bool:
    if _jump_recovery > 0.0 or velocity.y < -3.5:
        return false
    if extraction_mode and (crouching or healing_active or reloading or medical.leg_impaired() or _is_legacy_stunned() or stamina < MANTLE_STAMINA_COST):
        return false
    var forward: Vector3 = wish
    if forward.length_squared() < 0.01:
        forward = -global_transform.basis.z
    forward.y = 0.0
    forward = forward.normalized()

    var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var wall_from: Vector3 = global_position + Vector3.UP * 0.65
    var wall_query := PhysicsRayQueryParameters3D.create(
        wall_from, wall_from + forward * MANTLE_REACH
    )
    wall_query.exclude = [get_rid()]
    wall_query.collision_mask = collision_mask
    var wall_hit: Dictionary = space_state.intersect_ray(wall_query)
    if wall_hit.is_empty():
        return false

    var clear_from: Vector3 = global_position + Vector3.UP * 1.82
    var clear_query := PhysicsRayQueryParameters3D.create(
        clear_from, clear_from + forward * (MANTLE_REACH + 0.20)
    )
    clear_query.exclude = [get_rid()]
    clear_query.collision_mask = collision_mask
    if not space_state.intersect_ray(clear_query).is_empty():
        return false

    var beyond_wall: Vector3 = global_position + forward * (MANTLE_REACH + 0.22)
    var down_query := PhysicsRayQueryParameters3D.create(
        beyond_wall + Vector3.UP * (MANTLE_MAX_HEIGHT + 0.35),
        beyond_wall + Vector3.UP * 0.20
    )
    down_query.exclude = [get_rid()]
    down_query.collision_mask = collision_mask
    var top_hit: Dictionary = space_state.intersect_ray(down_query)
    if top_hit.is_empty():
        return false

    var ledge_position: Vector3 = top_hit.position
    if Vector3(top_hit.normal).dot(Vector3.UP) < cos(floor_max_angle):
        return false
    var ledge_height: float = ledge_position.y - global_position.y
    if ledge_height < MANTLE_MIN_HEIGHT or ledge_height > MANTLE_MAX_HEIGHT:
        return false

    var landing := ledge_position + forward * 0.32 + Vector3.UP * 0.06
    var corner := Vector3(global_position.x, landing.y, global_position.z)
    if extraction_mode:
        # Lift the whole standing capsule before crossing the lip; a diagonal
        # collision-disabled interpolation would travel through the ledge wall.
        if not _standing_capsule_sweep_clear(global_position, corner) or not _standing_capsule_sweep_clear(corner, landing):
            return false
    if extraction_mode:
        _spend_stamina(MANTLE_STAMINA_COST)
        sprinting = false
    mantle_start = global_position
    mantle_target = landing
    mantle_corner = corner
    mantle_elapsed = 0.0
    mantle_duration = lerpf(0.48, 0.95, inverse_lerp(MANTLE_MIN_HEIGHT, MANTLE_MAX_HEIGHT, ledge_height))
    if extraction_mode:
        mantle_duration *= lerpf(1.0, 1.18, cargo_load_ratio)
    mantle_saved_layer = collision_layer
    mantle_saved_mask = collision_mask
    collision_layer = 0
    collision_mask = 0
    velocity = Vector3.ZERO
    mantle_active = true
    return true

func _process_mantle(delta: float) -> void:
    mantle_elapsed += delta
    var amount: float = clampf(mantle_elapsed / mantle_duration, 0.0, 1.0)
    var smooth_amount: float = amount * amount * (3.0 - 2.0 * amount)
    if extraction_mode:
        if amount < 0.55:
            global_position = mantle_start.lerp(mantle_corner, _smooth01(amount / 0.55))
        else:
            global_position = mantle_corner.lerp(mantle_target, _smooth01((amount - 0.55) / 0.45))
    else:
        global_position = mantle_start.lerp(mantle_target, smooth_amount)
        global_position.y += sin(amount * PI) * 0.14
    if amount >= 1.0:
        global_position = mantle_target
        collision_layer = mantle_saved_layer
        collision_mask = mantle_saved_mask
        mantle_active = false
        _landing_recovery = 0.12
        _jump_recovery = LANDING_JUMP_LOCK
        _ground_contact_time = 0.0
        velocity = Vector3.ZERO

func _smooth01(value: float) -> float:
    var x: float = clampf(value, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)

func _stage(value: float, start_t: float, end_t: float) -> float:
    if end_t <= start_t:
        return 1.0 if value >= end_t else 0.0
    return _smooth01((value - start_t) / (end_t - start_t))

func _animate_weapon(horizontal_speed: float) -> void:
    if is_instance_valid(crosshair):
        crosshair.visible = not weapon_id.is_empty() and not weapon_lowered and weapon_lower_blend < 0.05 and not ads and ads_blend < 0.05 and not reloading and not field_handling.check.active
    if is_instance_valid(ads_dot): ads_dot.visible = false
    # Authored models own the complete magazine exchange. Never run the legacy
    # block-magazine choreography over the supplied animated weapon and hands.
    if is_instance_valid(uzi_viewmodel) and bool(uzi_viewmodel.get("loaded")):
        if is_instance_valid(weapon_body): _hide_legacy_viewmodel_meshes(weapon_body)
        if is_instance_valid(vest_pouch): vest_pouch.hide()
        return
    var bob_strength: float = clampf(horizontal_speed / sprint_speed, 0.0, 1.0) * (1.0 - ads_blend * 0.9)
    var bob: Vector3 = Vector3(sin(bob_phase * 5.5) * 0.018, abs(cos(bob_phase * 5.5)) * 0.015, 0.0) * bob_strength
    var target_pos: Vector3 = hip_weapon_pos.lerp(ads_weapon_pos, ads_blend) + bob
    target_pos.z += weapon_kick * 0.07
    target_pos.y += recoil_pitch * 0.18

    var reload_rot: Vector3 = Vector3.ZERO
    var mag_pos: Vector3 = magazine_default_pos
    var mag_rot: Vector3 = magazine_default_rot
    var left_target_pos: Vector3 = left_hand_base_pos
    var left_target_rot: Vector3 = left_hand_base_rot
    if is_instance_valid(magazine):
        magazine.visible = true

    if reloading:
        var t: float = clampf(reload_time / reload_duration, 0.0, 1.0)
        var raise_in: float = _stage(t, 0.00, 0.12)
        var settle_start: float = 0.90 if reload_empty else 0.87
        var settle_out: float = _stage(t, settle_start, 1.00)
        var manipulate: float = raise_in * (1.0 - settle_out)
        reload_rot = Vector3(-0.075 * manipulate, -0.14 * manipulate, 0.30 * manipulate)
        target_pos += Vector3(0.085 * manipulate, 0.038 * manipulate, 0.050 * manipulate)

        var mag_grab: Vector3 = Vector3(-0.105, -0.275, -0.215)
        var old_mag_low: Vector3 = Vector3(-0.24, -0.62, 0.09)
        # This is intentionally much farther left/down/back than the old reload
        # path. It sends the hand toward the player's chest rig / vest and partly
        # out of frame before a fresh magazine appears in the hand.
        var vest_hand: Vector3 = Vector3(-0.93, -0.18, 0.28)
        var vest_control: Vector3 = Vector3(-0.62, -0.50, 0.18)
        var insert_control: Vector3 = Vector3(-0.22, -0.46, -0.06)
        var hand_insert: Vector3 = Vector3(-0.09, -0.285, -0.215)
        var bolt_press: Vector3 = Vector3(-0.18, -0.02, -0.06)

        # Default visibility while a reload is active. Old and fresh magazines
        # are independent so neither has to teleport.
        if is_instance_valid(fresh_magazine):
            fresh_magazine.visible = false
            fresh_magazine.position = vest_mag_pos
            fresh_magazine.rotation = vest_mag_rot
        if is_instance_valid(magazine) and t >= 0.36:
            magazine.visible = false
        if is_instance_valid(vest_pouch):
            # Fade-in is not available on this simple procedural mesh, so show
            # the pouch only around the actual chest-rig reach/grab window.
            vest_pouch.visible = t >= 0.32 and t <= 0.72

        var finger_grip: float = 1.0

        # 1) Support hand leaves the handguard and closes around the inserted mag.
        if t < 0.22:
            var hand_to_mag: float = _stage(t, 0.07, 0.22)
            left_target_pos = left_hand_base_pos.lerp(mag_grab, hand_to_mag)
            left_target_rot = left_hand_base_rot.lerp(Vector3(-0.28, -0.18, 0.34), hand_to_mag)
            finger_grip = 0.72 + 0.28 * hand_to_mag

        # 2) Pull the old magazine down and clear of the magwell.
        elif t < 0.36:
            var pull_old: float = _stage(t, 0.22, 0.36)
            left_target_pos = mag_grab.lerp(old_mag_low, pull_old)
            left_target_rot = Vector3(-0.28, -0.18, 0.34).lerp(Vector3(-0.10, -0.38, 0.16), pull_old)
            mag_pos = magazine_default_pos.lerp(old_mag_low + Vector3(0.08, 0.04, -0.03), pull_old)
            mag_rot = magazine_default_rot.lerp(Vector3(-0.44, 0.12, -0.24), pull_old)
            finger_grip = 1.0

        # 3) Old mag goes out of frame. The open support hand reaches down and
        # inward toward a chest/vest pouch instead of waiting beneath the rifle.
        elif t < 0.56:
            var to_vest: float = _stage(t, 0.36, 0.56)
            left_target_pos = _quad_bezier(old_mag_low, vest_control, vest_hand, to_vest)
            left_target_rot = Vector3(-0.10, -0.38, 0.16).lerp(Vector3(0.14, -0.42, -0.40), to_vest)
            if is_instance_valid(magazine):
                magazine.visible = false
            # Fingers relax while the hand approaches the pouch.
            finger_grip = 1.0 - 0.72 * _stage(to_vest, 0.20, 0.88)

        # 4) Brief vest grab: hand pauses low-left, fingers close, and the fresh
        # magazine becomes visible only as it is being pulled from the pouch.
        elif t < 0.66:
            var vest_grab: float = _stage(t, 0.56, 0.66)
            left_target_pos = vest_hand + Vector3(0.018 * sin(vest_grab * PI), 0.010 * sin(vest_grab * PI), -0.012 * sin(vest_grab * PI))
            left_target_rot = Vector3(0.14, -0.42, -0.40).lerp(Vector3(-0.18, -0.22, 0.18), vest_grab)
            finger_grip = _smooth01(vest_grab)
            if is_instance_valid(fresh_magazine):
                fresh_magazine.visible = vest_grab > 0.18
                fresh_magazine.position = vest_mag_pos + Vector3(0.035 * vest_grab, 0.055 * vest_grab, -0.025 * vest_grab)
                fresh_magazine.rotation = vest_mag_rot.lerp(Vector3(-0.30, 0.05, -0.20), vest_grab)

        # 5) Fresh magazine comes out of the vest along a curved path, rotating
        # into the correct insertion angle while the hand stays wrapped around it.
        elif t < 0.80:
            var bring_new: float = _stage(t, 0.66, 0.80)
            left_target_pos = _quad_bezier(vest_hand, insert_control, hand_insert, bring_new)
            left_target_rot = Vector3(-0.18, -0.22, 0.18).lerp(Vector3(-0.30, -0.10, 0.30), bring_new)
            finger_grip = 1.0
            if is_instance_valid(fresh_magazine):
                fresh_magazine.visible = true
                fresh_magazine.position = _quad_bezier(vest_mag_pos + Vector3(0.035, 0.055, -0.025), insert_control + Vector3(0.08, 0.05, -0.02), magazine_default_pos, bring_new)
                fresh_magazine.rotation = Vector3(-0.30, 0.05, -0.20).lerp(magazine_default_rot, bring_new)

        # 6) Seat the fresh magazine with a firm upward push.
        elif t < 0.86:
            var seat: float = _stage(t, 0.80, 0.86)
            left_target_pos = hand_insert + Vector3(0.0, 0.042 * sin(seat * PI), -0.012)
            left_target_rot = Vector3(-0.30, -0.10, 0.30)
            finger_grip = 1.0
            if is_instance_valid(fresh_magazine):
                fresh_magazine.visible = true
                fresh_magazine.position = magazine_default_pos + Vector3(0.0, 0.020 * sin(seat * PI), 0.0)
                fresh_magazine.rotation = magazine_default_rot

        elif reload_empty:
            # 7A) Empty reload: fresh magazine is now effectively inserted; the
            # support hand reaches to the bolt release before returning forward.
            if is_instance_valid(fresh_magazine):
                fresh_magazine.visible = true
                fresh_magazine.position = magazine_default_pos
                fresh_magazine.rotation = magazine_default_rot
            if t < 0.93:
                var to_bolt: float = _stage(t, 0.86, 0.93)
                left_target_pos = hand_insert.lerp(bolt_press, to_bolt)
                left_target_rot = Vector3(-0.30, -0.10, 0.30).lerp(Vector3(-0.02, -0.34, 0.56), to_bolt)
                finger_grip = 1.0 - 0.45 * to_bolt
            elif t < 0.96:
                var press: float = _stage(t, 0.93, 0.96)
                left_target_pos = bolt_press + Vector3(0.018 * sin(press * PI), 0.0, -0.015 * sin(press * PI))
                left_target_rot = Vector3(-0.02, -0.34, 0.56)
                target_pos.z += 0.018 * sin(press * PI)
                reload_rot.x -= 0.025 * sin(press * PI)
                finger_grip = 0.55
            else:
                var return_hand_empty: float = _stage(t, 0.96, 1.0)
                left_target_pos = bolt_press.lerp(left_hand_base_pos, return_hand_empty)
                left_target_rot = Vector3(-0.02, -0.34, 0.56).lerp(left_hand_base_rot, return_hand_empty)
                finger_grip = 0.55 + 0.45 * return_hand_empty
        else:
            # 7B) Tactical reload: return directly to the handguard once seated.
            if is_instance_valid(fresh_magazine):
                fresh_magazine.visible = true
                fresh_magazine.position = magazine_default_pos
                fresh_magazine.rotation = magazine_default_rot
            var return_hand: float = _stage(t, 0.86, 1.0)
            left_target_pos = hand_insert.lerp(left_hand_base_pos, return_hand)
            left_target_rot = Vector3(-0.30, -0.10, 0.30).lerp(left_hand_base_rot, return_hand)
            finger_grip = 0.85 + 0.15 * return_hand

        _set_left_finger_grip(finger_grip)
    else:
        _set_left_finger_grip(1.0)
        if is_instance_valid(fresh_magazine):
            fresh_magazine.visible = false
        if is_instance_valid(vest_pouch):
            vest_pouch.visible = false

    if is_instance_valid(left_hand):
        left_hand.position = left_target_pos
        left_hand.rotation = left_target_rot

    weapon.position = weapon.position.lerp(target_pos, 0.26)
    weapon.rotation = weapon.rotation.lerp(reload_rot + Vector3(-recoil_pitch * 0.65, 0, 0), 0.24)
    if is_instance_valid(magazine):
        magazine.position = mag_pos
        magazine.rotation = mag_rot

    if is_instance_valid(crosshair):
        crosshair.visible = not weapon_lowered and weapon_lower_blend<.05 and not ads and ads_blend < 0.05 and not reloading and not field_handling.check.active
    if is_instance_valid(ads_dot):
        # The authored UZI now uses its physical iron sights for ADS. Keeping
        # a screen-space dot would hide alignment errors and does not match the
        # requested iron-sight reference.
        ads_dot.visible = false

# Input is collected by events; physical shots are dispatched only in the physics
# step. A signed timer carries fractional intervals across ticks (no RPM rounding).
func _advance_weapon_fire(delta: float) -> void:
    if fire_cooldown > 0.0:
        fire_cooldown -= delta
    var held: bool = _controller_gameplay_allowed() and ControllerInput.down("fire")
    var pressed: bool = _fire_requested or (held and not _trigger_was_down)
    if pressed or not held: _dry_fire_latched = false
    _fire_requested = false
    _trigger_was_down = held
    if bolt_cycle_active:
        _semi_buffer_remaining = 0.0
        _advance_bolt_cycle(delta)
        # Presses during a bolt action are discarded, including its final frame.
        # Holding the trigger through cycling never fires the next round.
        fire_cooldown = maxf(0.0, fire_cooldown)
        return
    var automatic: bool = str(weapon_definition.mode) == "auto"
    if pressed and not automatic:
        _semi_buffer_remaining = clampf(maxf(0.10, _sprint_fire_delay + 0.05), 0.10, 0.40)
    elif not held:
        _semi_buffer_remaining = 0.0
    else:
        _semi_buffer_remaining = maxf(0.0, _semi_buffer_remaining - delta)
    if field_handling.check.active:
        _semi_buffer_remaining = 0.0
        return
    if reloading or weapon_input_locked or mantle_active or is_swimming or not alive:
        _semi_buffer_remaining = 0.0
    var wants_shot: bool = held if automatic else (pressed or (held and _semi_buffer_remaining > 0.0))
    # A click can begin and end between physics ticks.
    wants_shot = wants_shot or pressed
    if not wants_shot or not _controller_gameplay_allowed():
        fire_cooldown = maxf(0.0, fire_cooldown)
        return
    var count := 0
    while fire_cooldown <= 0.000001 and count < 3:
        var previous_ammo := ammo
        shoot()
        if ammo == previous_ammo:
            fire_cooldown = maxf(0.0, fire_cooldown)
            break
        count += 1
        _semi_buffer_remaining = 0.0
        if str(weapon_definition.mode) != "auto": break
    # Long stalls must not create a backlog that sprays several future ticks.
    if count == 3: fire_cooldown = maxf(0.0, fire_cooldown)

func _tick_blocked_weapon(delta: float) -> void:
    field_handling.cancel(self)
    field_handling.tick(self, delta)
    _tick_weapon_posture(delta)
    # Traversal owns the hands. A click during a vault is discarded, never
    # replayed after landing; passive recovery still follows elapsed time.
    _fire_requested = false
    _reset_weapon_handling()
    _cancel_bolt_cycle()
    lean_controller.tick(self, delta)
    _semi_buffer_remaining = 0.0
    _trigger_was_down = ControllerInput.down("fire")
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    _sprint_fire_delay = maxf(0.0, _sprint_fire_delay - delta)
    _tick_recoil(delta)
    weapon_kick = move_toward(weapon_kick, 0.0, delta * 5.8)
    muzzle_timer = maxf(0.0, muzzle_timer - delta)

func _uses_manual_bolt() -> bool:
    return str(weapon_definition.get("mode", "")) == "bolt"

func _bolt_cycle_allowed() -> bool:
    # Presentation readiness is deliberately excluded: the adapter is busy while
    # this authoritative action runs. Its animation never chambers ammunition.
    return _uses_manual_bolt() and not weapon_id.is_empty() and alive and not weapon_transition_pending and not weapon_input_locked and not reloading and not fly_mode and not mantle_active and not is_swimming and not is_underwater and not sprinting and not healing_active and not _is_legacy_stunned() and _controller_gameplay_allowed()

func _start_bolt_cycle(allow_empty: bool = false) -> bool:
    if bolt_cycle_active or chambered or not _bolt_cycle_allowed():
        return false
    if not allow_empty and (ammo <= 0 or not magazine_inserted):
        return false
    bolt_cycle_active = true
    _reset_weapon_handling()
    _bolt_open_played = false
    bolt_cycle_elapsed = 0.0
    bolt_cycle_duration = maxf(0.10, float(weapon_definition.get("bolt_cycle", weapon_definition.get("manual_cycle_seconds", 1.35))))
    _bolt_cycle_weapon_id = weapon_id
    bolt_locked = true
    ads = false
    _semi_buffer_remaining = 0.0
    _fire_requested = false
    if is_instance_valid(uzi_viewmodel) and uzi_viewmodel.has_method("play_cycle"):
        uzi_viewmodel.call("play_cycle", bolt_cycle_duration)
    if is_instance_valid(hud_status): hud_status.text = "Cycling bolt…"
    return true

func _advance_bolt_cycle(delta: float) -> void:
    if not bolt_cycle_active:
        return
    if _bolt_cycle_weapon_id != weapon_id or not _bolt_cycle_allowed():
        _cancel_bolt_cycle()
        return
    bolt_cycle_elapsed += maxf(0.0, delta)
    if not _bolt_open_played and bolt_cycle_elapsed >= bolt_cycle_duration * 0.20:
        _play_weapon_sound("bolt_open")
        _bolt_open_played = true
    if bolt_cycle_elapsed + 0.000001 < bolt_cycle_duration:
        return
    # Ammo already includes all loaded rounds. Chambering only changes their
    # location, never the count or reserve; an absent/empty magazine stays empty.
    chambered = magazine_inserted and ammo > 0
    bolt_locked = not chambered
    _sync_inserted_magazine_record()
    bolt_cycle_active = false
    _play_weapon_sound("bolt_close")
    bolt_cycle_elapsed = 0.0
    _bolt_cycle_weapon_id = ""
    _semi_buffer_remaining = 0.0
    _fire_requested = false
    _sync_weapon_magazine()
    if is_instance_valid(hud_status): hud_status.text = "Ready" if chambered else "EMPTY — press R"

func _cancel_bolt_cycle() -> void:
    if not bolt_cycle_active:
        return
    bolt_cycle_active = false
    if is_instance_valid(_weapon_audio): _weapon_audio.call("reset")
    bolt_cycle_elapsed = 0.0
    _bolt_cycle_weapon_id = ""
    _semi_buffer_remaining = 0.0
    _fire_requested = false
    # The live/save chamber flag remains false until a whole action completes.
    # Re-equipping or resuming cannot turn a cancelled visual cycle into a round.
    if is_instance_valid(uzi_viewmodel) and uzi_viewmodel.has_method("cancel_cycle"):
        uzi_viewmodel.call("cancel_cycle")

func _reset_recoil() -> void:
    recoil_pitch = 0.0
    recoil_velocity = 0.0
    recoil_yaw = 0.0
    recoil_burst_shots = 0
    _recoil_idle_time = 10.0

func _tick_recoil(delta: float) -> void:
    _recoil_idle_time += delta
    if _recoil_idle_time >= float(weapon_definition.get("burst_reset", 0.28)):
        recoil_burst_shots = 0
    # Exact critically damped spring integration: identical recovery at 30/60/144Hz.
    var frequency: float = float(weapon_definition.get("recoil_recovery", 20.0))
    var decay: float = exp(-frequency * delta)
    var spring: float = recoil_velocity + frequency * recoil_pitch
    recoil_pitch = maxf(0.0, (recoil_pitch + spring * delta) * decay)
    recoil_velocity = (recoil_velocity - frequency * spring * delta) * decay
    recoil_yaw *= exp(-12.0 * delta)

func _apply_shot_recoil() -> void:
    var aiming: float = smoothstep(0.0, 1.0, ads_blend)
    var vertical: float = lerpf(float(weapon_definition.recoil_hip), float(weapon_definition.recoil_ads), aiming)
    var settled: float = lerpf(1.0, 0.82, float(crouching))
    var fatigue: float = 1.0 + (1.0 - clampf(stamina / maxf(max_stamina, 1.0), 0.0, 1.0)) * 0.15
    var burst: float = 1.0 + minf(float(recoil_burst_shots), 8.0) * float(weapon_definition.get("recoil_growth", 0.035))
    if recoil_burst_shots == 0: burst *= float(weapon_definition.get("first_shot_multiplier", 1.12))
    var pattern: Array = weapon_definition.get("recoil_pattern", [-0.3, 0.2, 0.6, 0.3, -0.5, -0.7, -0.2, 0.4])
    var lateral: float = float(pattern[recoil_burst_shots % pattern.size()]) * float(weapon_definition.get("recoil_horizontal", 0.12))
    lateral *= lerpf(1.25, 1.0, aiming) * settled * fatigue
    # Permanent aim displacement belongs to the player; visual spring recovery
    # never drags a mouse correction back toward an old aim angle.
    head.rotation.x = clampf(head.rotation.x + deg_to_rad(vertical * settled * fatigue * burst), deg_to_rad(-84.0), deg_to_rad(84.0))
    rotate_y(deg_to_rad(lateral))
    recoil_yaw += deg_to_rad(lateral)
    recoil_velocity += float(weapon_definition.get("visual_recoil_impulse", 0.5)) * lerpf(1.25, 1.0, aiming)
    recoil_burst_shots += 1
    _recoil_idle_time = 0.0

func _get_shot_spread() -> float:
    var aiming: float = smoothstep(0.92, 1.0, ads_blend)
    if is_instance_valid(uzi_viewmodel) and uzi_viewmodel.has_method("is_sight_aligned") and not bool(uzi_viewmodel.call("is_sight_aligned")):
        aiming = 0.0
    var spread: float = lerpf(float(weapon_definition.spread_hip), float(weapon_definition.spread_ads), aiming)
    var speed_ratio: float = clampf(Vector2(velocity.x, velocity.z).length() / maxf(walk_speed, 0.1), 0.0, 1.8)
    spread += speed_ratio * lerpf(0.0045, 0.0011, aiming)
    if not is_on_floor(): spread += lerpf(0.018, 0.008, aiming)
    spread += minf(float(recoil_burst_shots), 10.0) * float(weapon_definition.get("spread_growth", 0.00010)) * lerpf(1.0, 0.35, aiming)
    if crouching: spread *= 0.80
    if extraction_mode and medical.arm_impaired(): spread += 0.006
    return spread

func _bullet_exclusions() -> Array[RID]:
    var excluded: Array[RID] = [get_rid()]
    for proxy: Node in get_tree().get_nodes_in_group("weapon_proxy_bodies"):
        if proxy is CollisionObject3D: excluded.append(proxy.get_rid())
    return excluded

func _trace_bullet(origin: Vector3, end: Vector3, excluded: Array[RID]) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(origin, end, 1 | 2 | 4 | 8, excluded)
    query.collide_with_areas = true
    return get_world_3d().direct_space_state.intersect_ray(query)

func shoot() -> void:
    if field_handling.check.active: return
    if weapon_lowered:
        set_weapon_lowered(false)
        fire_cooldown = maxf(fire_cooldown, 0.3)
        return
    if weapon_lower_blend > 0.05 or not _weapon_ready_for_input(): return
    if weapon_input_locked or is_swimming or is_underwater or not alive or reloading or fire_cooldown > 0.000001 or _is_legacy_stunned() or sprinting or _sprint_fire_delay > 0.0 or (extraction_mode and (healing_active or mantle_active)):
        return
    if _uses_manual_bolt() and not chambered and ammo > 0 and magazine_inserted:
        _start_bolt_cycle()
        return
    if ammo <= 0 or (bool(weapon_definition.get("closed_bolt", weapon_id != "uzi")) and not chambered):
        if not _dry_fire_latched:
            _play_weapon_sound("dry_fire")
            _dry_fire_latched = true
        if is_instance_valid(hud_status): hud_status.text = "EMPTY — press R"
        return

    # Resolve the sight picture BEFORE the recoil impulse from this shot.
    var origin: Vector3 = camera.global_position
    var spread: float = _get_shot_spread()
    var angle: float = randf() * TAU
    var radius: float = sqrt(randf()) * spread
    var basis: Basis = camera.global_transform.basis
    var direction: Vector3 = (-basis.z + basis.x * cos(angle) * radius + basis.y * sin(angle) * radius).normalized()
    var end: Vector3 = origin + direction * float(weapon_definition.get("range", 180.0))
    var excluded: Array[RID] = _bullet_exclusions()
    var sight_result: Dictionary = _trace_bullet(origin, end, excluded)
    var target: Vector3 = sight_result.get("position", end)
    var muzzle: Vector3 = origin
    if is_instance_valid(uzi_viewmodel) and uzi_viewmodel.has_method("get_muzzle_world_position"):
        muzzle = uzi_viewmodel.call("get_muzzle_world_position")
    # A camera can see over cover while its barrel is blocked. Test the near
    # segment too, so a clipped barrel cannot fire through a thin wall.
    var result: Dictionary = _trace_bullet(origin, muzzle, excluded) if origin.distance_to(muzzle) > 0.001 else {}
    if result.is_empty():
        var muzzle_direction: Vector3 = (target - muzzle).normalized()
        result = _trace_bullet(muzzle, target + muzzle_direction * 0.01, excluded)
        direction = muzzle_direction

    field_handling.clear_readout()
    ammo -= 1
    _dry_fire_latched = false
    if _uses_manual_bolt():
        chambered = false
        bolt_locked = true
    elif bool(weapon_definition.get("closed_bolt", weapon_id != "uzi")):
        chambered = ammo > 0 and magazine_inserted
        bolt_locked = not chambered
    _sync_inserted_magazine_record()
    if is_instance_valid(uzi_viewmodel) and uzi_viewmodel.has_method("set_bolt_locked"):
        uzi_viewmodel.call("set_bolt_locked", bolt_locked)
    fire_cooldown += 60.0 / maxf(float(weapon_definition.rpm), 1.0)
    muzzle_timer = 0.055
    weapon_kick = 1.0
    if not result.is_empty():
        var collider: Object = result.get("collider") as Object
        var damage: float = randf_range(float(weapon_definition.damage_min), float(weapon_definition.damage_max))
        if collider and collider.has_method("receive_bullet_hit"):
            if collider.receive_bullet_hit(damage, self, result.position, direction): hit_marker = 0.14
        elif collider and collider.has_method("take_damage"):
            collider.take_damage(damage, self)
            hit_marker = 0.14
        if hit_marker >= 0.14 and is_instance_valid(tactical_crosshair):
            tactical_crosshair.show_hit()
        _show_impact(result)
    # Other viewmodels draw their own flash on the viewmodel layer.
    if weapon_id == "uzi" and is_instance_valid(impact_fx):
        impact_fx.show_muzzle_flare(muzzle, direction)
    _add_camera_trauma(0.1)
    _apply_shot_recoil()
    if is_instance_valid(uzi_viewmodel): uzi_viewmodel.call("play_fire")
    if _uses_manual_bolt(): _start_bolt_cycle(true)
    shot_fired.emit()
    _update_hud()

func _cancel_physical_reload() -> bool:
    var was_reloading := reloading
    var can_complete := true
    if physical_magazines and physical_reload_handler.is_valid():
        can_complete = bool(physical_reload_handler.call("cancel"))
    if was_reloading and is_instance_valid(uzi_viewmodel):
        if uzi_viewmodel.has_method("cancel_reload_presentation"):
            uzi_viewmodel.call("cancel_reload_presentation")
        elif uzi_viewmodel.has_method("cancel_action"):
            uzi_viewmodel.call("cancel_action")
    if was_reloading:
        _reset_weapon_feedback()
    reloading = false
    reload_time = 0.0
    _sync_weapon_magazine()
    return can_complete

func start_reload() -> void:
    field_handling.cancel(self)
    if not _weapon_ready_for_input():
        return
    if weapon_input_locked or not alive or reloading or (extraction_mode and (healing_active or mantle_active or _is_legacy_stunned())):
        return
    if _uses_manual_bolt() and not chambered and ammo > 0 and magazine_inserted:
        _start_bolt_cycle()
        return
    _reload_chamber_only = weapon_id != "uzi" and magazine_inserted and ammo > 0 and not chambered
    if physical_magazines and not _reload_chamber_only:
        if not physical_reload_handler.is_valid() or not physical_reload_handler.call("begin"): return
    if not physical_magazines and not _reload_chamber_only and (ammo >= mag_size + int(chambered) or reserve <= 0):
        return
    reload_empty = not chambered if weapon_id != "uzi" else ammo <= 0
    _reload_mag_out = false
    _reload_mag_in = false
    _reload_bolt_released = false
    reload_duration = float(weapon_definition.reload_empty) if reload_empty else float(weapon_definition.reload_partial)
    if _reload_chamber_only:
        reload_duration = 0.95 if weapon_id == "shigure" else 1.1
        if is_instance_valid(uzi_viewmodel):
            uzi_viewmodel.call("play_chamber", reload_duration)
    elif is_instance_valid(uzi_viewmodel):
        var authored_duration: Variant = uzi_viewmodel.call("get_reload_duration", reload_empty)
        if authored_duration is float:
            reload_duration = maxf(float(authored_duration), 1.0)
        uzi_viewmodel.call("play_reload", reload_empty)
    reloading = true
    _reset_weapon_handling()
    ads = false
    reload_time = 0.0
    hud_status.text = "Empty reload…" if reload_empty else "Reloading…"

func _sync_inserted_magazine_record() -> void:
    if not physical_magazines or weapon_id.is_empty() or not magazine_inserted:
        inserted_magazine.clear()
        return
    inserted_magazine = MagazineRecord.normalize(weapon_id,inserted_magazine,maxi(0,ammo-int(chambered)))

func _sync_weapon_magazine() -> void:
    _sync_inserted_magazine_record()
    if is_instance_valid(uzi_viewmodel) and uzi_viewmodel.has_method("set_magazine_inserted"):
        uzi_viewmodel.call("set_magazine_inserted", magazine_inserted)
    if is_instance_valid(uzi_viewmodel) and uzi_viewmodel.has_method("set_bolt_locked"):
        uzi_viewmodel.call("set_bolt_locked", bolt_locked)

func _advance_reload_events(ratio: float) -> bool:
    if not reloading: return false
    if physical_magazines:
        if not _reload_chamber_only:
            if not _reload_mag_out and ratio >= (0.08 if reload_empty else 0.16):
                var had_magazine := magazine_inserted
                if not bool(physical_reload_handler.call("eject")):
                    _cancel_physical_reload()
                    return false
                _reload_mag_out = true
                if had_magazine: _play_weapon_sound("magazine_out")
            if not _reload_mag_in and ratio >= (0.40 if reload_empty else 0.65):
                if not bool(physical_reload_handler.call("insert")):
                    _cancel_physical_reload()
                    return false
                _reload_mag_in = true
                _play_weapon_sound("magazine_in")
        if weapon_id!="uzi" and reload_empty and not _reload_bolt_released and ratio >= (0.30 if _reload_chamber_only else 0.72):
            chambered=magazine_inserted and ammo>0
            bolt_locked=not chambered
            _reload_bolt_released=true
            if chambered: _play_weapon_sound("bolt_close")
        if weapon_id == "uzi" and reload_empty and _reload_mag_in and not _reload_bolt_released and ratio >= 0.72:
            _reload_bolt_released = true
            _play_weapon_sound("bolt_open")
        _sync_weapon_magazine()
        return true
    if weapon_id == "uzi":
        # Legacy pool mode still follows the visible magazine action; its round
        # transfer remains at completion, as before this feedback pass.
        if not _reload_mag_out and ratio >= (0.08 if reload_empty else 0.16):
            _reload_mag_out = true
            if magazine_inserted: _play_weapon_sound("magazine_out")
        if not _reload_mag_in and ratio >= (0.40 if reload_empty else 0.65):
            _reload_mag_in = true
            _play_weapon_sound("magazine_in")
        if reload_empty and not _reload_bolt_released and ratio >= 0.72:
            _reload_bolt_released = true
            _play_weapon_sound("bolt_open")
        return true
    if not _reload_chamber_only:
        if not _reload_mag_out and ratio >= (0.08 if reload_empty else 0.16):
            # The retained old magazine returns its rounds to the reserve pool.
            # A closed-bolt tactical reload preserves the separate chamber round.
            var had_magazine := magazine_inserted
            var retained := int(chambered)
            reserve += maxi(0, ammo - retained)
            ammo = retained
            magazine_inserted = false
            _reload_mag_out = true
            if had_magazine: _play_weapon_sound("magazine_out")
        if not _reload_mag_in and ratio >= (0.40 if reload_empty else 0.65):
            var moved := mini(mag_size, reserve)
            ammo += moved
            reserve -= moved
            magazine_inserted = true
            _reload_mag_in = true
            _play_weapon_sound("magazine_in")
    if reload_empty and not _reload_bolt_released and ratio >= (0.30 if _reload_chamber_only else 0.72):
        chambered = magazine_inserted and ammo > 0
        bolt_locked = not chambered
        _reload_bolt_released = true
        if chambered: _play_weapon_sound("bolt_close")
    _sync_weapon_magazine()
    return true

func _finish_reload() -> void:
    if physical_magazines:
        if not _advance_reload_events(1.0): return
    elif weapon_id == "uzi":
        var needed: int = mag_size - ammo
        var moved: int = mini(needed, reserve)
        ammo += moved
        reserve -= moved
    else:
        _advance_reload_events(1.0)
    reloading = false
    reload_time = 0.0
    reload_empty = false
    _sync_weapon_magazine()
    if is_instance_valid(magazine):
        magazine.visible = true
        magazine.position = magazine_default_pos
        magazine.rotation = magazine_default_rot
    if is_instance_valid(fresh_magazine):
        fresh_magazine.visible = false
        fresh_magazine.position = vest_mag_pos
        fresh_magazine.rotation = vest_mag_rot
    if is_instance_valid(vest_pouch):
        vest_pouch.visible = false
    _set_left_finger_grip(1.0)
    if is_instance_valid(left_hand):
        left_hand.position = left_hand_base_pos
        left_hand.rotation = left_hand_base_rot
    hud_status.text = "Ready"

func can_accept_face_drone() -> bool:
    if not alive or not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(camera):
        return false
    return not is_instance_valid(face_drone_latch) or face_drone_latch.can_accept()

func begin_face_drone(bot: Node3D, release_callback: Callable) -> bool:
    if not can_accept_face_drone():
        return false
    if not is_instance_valid(face_drone_latch):
        face_drone_latch = FaceDroneLatch.new()
        face_drone_latch.name = "FaceDroneLatch"
        add_child(face_drone_latch)
        face_drone_latch.setup(self)
    # Combat owns the single initial 12HP; this state owns only full-second DOT.
    return face_drone_latch.begin(bot, release_callback)

func release_face_drone(bot: Node3D, reason: String = "external") -> void:
    if is_instance_valid(face_drone_latch):
        face_drone_latch.release(bot, reason)

func is_face_drone_attached_to(bot: Node3D) -> bool:
    return is_instance_valid(face_drone_latch) and face_drone_latch.is_attached_to(bot)

func get_face_drone_anchor() -> Node3D:
    return camera if is_instance_valid(camera) and camera.is_inside_tree() else null

func _exit_tree() -> void:
    if is_instance_valid(face_drone_latch):
        face_drone_latch.shutdown()

func is_combat_alive() -> bool:
    return alive

func take_damage(amount: float, body_part: String = "") -> void:
    if not alive or not is_finite(amount) or amount <= 0.0:
        return
    if extraction_mode:
        var part := Medical.hit_part(randf()) if body_part.is_empty() else body_part
        if not medical.hp.has(part): return
        amount=preload("./extraction_clothing.gd").protected_damage(equipped_clothing,part,amount)
        medical.damage(part, amount, randf(), randf())
        health = medical.effective_hp()
    else:
        health = maxf(0.0, health - amount)
    damage_received.emit(amount)
    damage_flash = 0.75
    _add_camera_trauma(clampf(amount / 18.0, 0.25, 0.6))
    if health <= 0.0: _eliminate()
    _update_hud()

func apply_stun(duration: float) -> bool:
    if not alive or stun_immunity_remaining > 0.0:
        return false
    stun_remaining = clampf(duration, 0.25, 2.5)
    stun_immunity_remaining = stun_remaining + STUN_RECOVERY_IMMUNITY
    drone_stun_active = false
    if is_instance_valid(drone_stun_fx):
        drone_stun_fx.call("clear")
    ads = false
    if is_instance_valid(hud_status):
        hud_status.text = LEGACY_STUN_STATUS
    return true

func apply_drone_stun(duration: float = 3.0) -> bool:
    if not alive or stun_remaining > 0.0 or stun_immunity_remaining > 0.0 or not is_finite(duration):
        return false
    stun_remaining = clampf(duration, 0.25, DRONE_STUN_MAX_DURATION)
    stun_immunity_remaining = stun_remaining + STUN_RECOVERY_IMMUNITY
    drone_stun_active = true
    ads = false
    ads_blend = 0.0
    sprinting = false
    if is_instance_valid(camera):
        camera.fov = 73.0
    if is_instance_valid(uzi_viewmodel):
        uzi_viewmodel.call("set_ads_blend", 0.0)
    if not is_instance_valid(drone_stun_fx):
        drone_stun_fx = preload("player_drone_stun_fx.gd").new()
        drone_stun_fx.name = "DroneStunFX"
        add_child(drone_stun_fx)
    drone_stun_fx.call("bind_camera", camera, bool(get_meta("reduced_motion", false)))
    drone_stun_fx.call("begin", stun_remaining)
    if is_instance_valid(hud_status) and not reloading and not healing_active:
        hud_status.text = DRONE_STUN_STATUS
    return true

func _is_legacy_stunned() -> bool:
    return stun_remaining > 0.0 and not drone_stun_active

func _restore_stun_status() -> void:
    if is_instance_valid(hud_status) and alive and not reloading and not healing_active:
        if hud_status.text == LEGACY_STUN_STATUS or hud_status.text == DRONE_STUN_STATUS:
            hud_status.text = "Ready"

func clear_stun() -> void:
    stun_remaining = 0.0
    stun_immunity_remaining = 0.0
    drone_stun_active = false
    if is_instance_valid(drone_stun_fx):
        drone_stun_fx.call("clear")
    _restore_stun_status()

func notify_kill() -> void:
    kills += 1
    reserve += mini(6, maxi(0, 240 - reserve))
    hit_marker = 0.18
    if is_instance_valid(tactical_crosshair):
        tactical_crosshair.show_hit(true)
    _update_hud()

func set_wave(value: int) -> void:
    wave = value
    _update_hud()

func _process(_delta: float) -> void:
    if not extraction_mode and not alive and Input.is_key_pressed(KEY_ENTER):
        get_tree().reload_current_scene()

func _update_hud() -> void:
    if not hud_health:
        return
    # Extraction hides the entire legacy row; normal modes still update it.
    if extraction_mode and not hud_health.is_visible_in_tree():
        return
    hud_health.text = "HP %d" % int(ceil(health))
    hud_ammo.text = "AMMO %d / %d" % [ammo, reserve]
    hud_kills.text = "KILLS %d" % kills
    hud_wave.text = "WAVE %d" % wave

func apply_coffee_boost() -> void:
    if coffee_boost_remaining <= 0.0:
        _coffee_base_max = max_stamina
    coffee_boost_remaining = 180.0
    max_stamina = _coffee_base_max * 1.04

func clear_coffee_boost() -> void:
    if coffee_boost_remaining > 0.0:
        max_stamina = _coffee_base_max
    coffee_boost_remaining = 0.0
    stamina = minf(stamina, max_stamina)

func _tick_coffee_boost(delta: float) -> void:
    if coffee_boost_remaining <= 0.0:
        return
    if delta >= coffee_boost_remaining:
        clear_coffee_boost()
    else:
        coffee_boost_remaining -= delta

func max_health() -> float:
    return Medical.TOTAL_HP if extraction_mode else 100.0

func health_ratio() -> float:
    return clampf(health / max_health(), 0.0, 1.0)

func reset_medical() -> void:
    medical.reset()
    health = max_health()

func advance_medical(delta: float, recover_blood: bool = false, blood_multiplier: float = 1.0, tissue_rate: float = 0.0) -> void:
    if not extraction_mode or not alive: return
    if not is_zero_approx(medical.tick(delta, recover_blood, blood_multiplier, tissue_rate)):
        _sync_medical_health()

func _sync_medical_health() -> void:
    health = medical.effective_hp()
    if medical.is_dead() and alive:
        _eliminate()

func _eliminate() -> void:
    _cancel_bolt_cycle()
    health = 0.0
    alive = false
    if is_instance_valid(face_drone_latch):
        face_drone_latch.release(null, "player_died")
    clear_stun()
    ads = false
    if is_instance_valid(ads_dot): ads_dot.visible = false
    if is_instance_valid(hud_status): hud_status.text = "You were eliminated — press Enter to restart"
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    died.emit()
