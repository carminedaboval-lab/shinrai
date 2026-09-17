extends CharacterBody3D

const UziViewmodelScript = preload("res://scripts/uzi_viewmodel.gd")
const AUTO_FIRE_INTERVAL: float = 0.095
# v10.5 recoil: the UZI is a light 9 mm SMG, so the camera climb is deliberately
# modest. Recoil is applied to the actual look direction rather than faking the
# gun downward; sustained automatic fire therefore needs a gentle mouse-down
# correction just like a conventional FPS spray.
const ADS_RECOIL_DEGREES_PER_SHOT: float = 0.18
const HIP_RECOIL_DEGREES_PER_SHOT: float = 0.28
const FLY_SPEED: float = 20.0
const FLY_BOOST_SPEED: float = 55.0

signal died

var mouse_sensitivity: float = 0.00215
var ads_mouse_multiplier: float = 0.55
var walk_speed: float = 5.0
var sprint_speed: float = 8.0
var acceleration: float = 18.0
var friction: float = 22.0
var jump_velocity: float = 6.2
var gravity: float = 18.0

const MANTLE_MIN_HEIGHT: float = 0.55
const MANTLE_MAX_HEIGHT: float = 1.70
const MANTLE_REACH: float = 0.95
var mantle_active: bool = false
var mantle_start: Vector3 = Vector3.ZERO
var mantle_target: Vector3 = Vector3.ZERO
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
var kills: int = 0
var wave: int = 1

var ads: bool = false
var ads_blend: float = 0.0
var reloading: bool = false
var reload_time: float = 0.0
var reload_duration: float = 2.80
var reload_empty: bool = false
var fire_cooldown: float = 0.0
var recoil_pitch: float = 0.0
var recoil_velocity: float = 0.0
var weapon_kick: float = 0.0
var muzzle_timer: float = 0.0
var hit_marker: float = 0.0
var damage_flash: float = 0.0
var bob_phase: float = 0.0
var alive: bool = true

var head: Node3D
var camera: Camera3D
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
    collision_layer = 1
    collision_mask = 1 | 2
    fly_saved_layer = collision_layer
    fly_saved_mask = collision_mask
    _build_collision()
    _build_camera()
    _build_weapon()
    _build_hud()
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    _update_hud()

func _build_collision() -> void:
    var shape_node := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.36
    capsule.height = 1.75
    shape_node.shape = capsule
    shape_node.position = Vector3(0, 0.9, 0)
    add_child(shape_node)

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
    uzi_viewmodel.connect("status_changed", Callable(self, "_on_uzi_status_changed"))

func _on_uzi_status_changed(text: String) -> void:
    if is_instance_valid(hud_status):
        hud_status.text = text

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

func _add_hit_marker_stroke(parent: Control, start: Vector2, finish: Vector2) -> void:
    var stroke: Line2D = Line2D.new()
    stroke.width = 2.0
    stroke.default_color = Color.WHITE
    stroke.points = PackedVector2Array([start, finish])
    parent.add_child(stroke)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
                Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
            else:
                Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        elif event.keycode == KEY_F3:
            _set_fly_mode(not fly_mode)
        elif event.keycode == KEY_R and not fly_mode:
            start_reload()

    if not alive:
        return

    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        var sens: float = mouse_sensitivity * (ads_mouse_multiplier if ads_blend > 0.5 else 1.0)
        rotate_y(-event.relative.x * sens)
        head.rotate_x(-event.relative.y * sens)
        var head_rot: Vector3 = head.rotation
        var pitch_limit := 89.5 if fly_mode else 84.0
        head_rot.x = clampf(head_rot.x, deg_to_rad(-pitch_limit), deg_to_rad(pitch_limit))
        head.rotation = head_rot

    if event is InputEventMouseButton:
        if fly_mode:
            return
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            shoot()
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            ads = event.pressed and not reloading
            if is_instance_valid(crosshair) and ads:
                crosshair.visible = false

func _physics_process(delta: float) -> void:
    if not alive:
        return

    if fly_mode:
        _process_fly_mode(delta)
        return

    var jump_down: bool = Input.is_key_pressed(KEY_SPACE)
    if mantle_active:
        _process_mantle(delta)
        jump_was_down = jump_down
        return

    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        shoot()
    muzzle_timer = maxf(0.0, muzzle_timer - delta)
    hit_marker = maxf(0.0, hit_marker - delta)
    damage_flash = maxf(0.0, damage_flash - delta * 2.5)
    muzzle_light.light_energy = 9.0 if muzzle_timer > 0.0 else 0.0
    _animate_trigger_finger()
    var hit_mod: Color = hit_cross.modulate
    hit_mod.a = clampf(hit_marker * 9.0, 0.0, 1.0)
    hit_cross.modulate = hit_mod
    var damage_color: Color = damage_rect.color
    damage_color.a = clampf(damage_flash * 0.22, 0.0, 0.24)
    damage_rect.color = damage_color

    if reloading:
        reload_time += delta
        if reload_time >= reload_duration:
            _finish_reload()

    ads_blend = move_toward(ads_blend, 1.0 if ads and not reloading else 0.0, delta * 7.5)
    camera.fov = lerpf(73.0, 50.0, ads_blend)

    var input_vec: Vector2 = Vector2.ZERO
    if Input.is_key_pressed(KEY_W): input_vec.y -= 1.0
    if Input.is_key_pressed(KEY_S): input_vec.y += 1.0
    if Input.is_key_pressed(KEY_A): input_vec.x -= 1.0
    if Input.is_key_pressed(KEY_D): input_vec.x += 1.0
    input_vec = input_vec.normalized()

    var basis: Basis = global_transform.basis
    var wish: Vector3 = basis.x * input_vec.x + basis.z * input_vec.y
    wish.y = 0.0
    wish = wish.normalized()

    var sprinting: bool = Input.is_key_pressed(KEY_SHIFT) and ads_blend < 0.25 and input_vec.y < 0.0
    var speed: float = sprint_speed if sprinting else walk_speed
    if ads_blend > 0.5:
        speed *= 0.72

    velocity.x = move_toward(velocity.x, wish.x * speed, acceleration * delta if input_vec != Vector2.ZERO else friction * delta)
    velocity.z = move_toward(velocity.z, wish.z * speed, acceleration * delta if input_vec != Vector2.ZERO else friction * delta)

    if jump_down and not jump_was_down and _try_start_mantle(wish):
        jump_was_down = jump_down
        return

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        if jump_down:
            velocity.y = jump_velocity
        else:
            velocity.y = 0.0

    move_and_slide()

    var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
    bob_phase += horizontal_speed * delta * 1.8

    recoil_velocity += -recoil_pitch * 34.0 * delta
    recoil_velocity *= pow(0.025, delta)
    recoil_pitch += recoil_velocity
    recoil_pitch = clampf(recoil_pitch, 0.0, 0.08)
    weapon_kick = move_toward(weapon_kick, 0.0, delta * 5.8)

    _animate_weapon(horizontal_speed)
    if is_instance_valid(uzi_viewmodel):
        uzi_viewmodel.call("set_ads_blend", ads_blend)
        uzi_viewmodel.call("set_move_speed", horizontal_speed)
    _update_hud()
    jump_was_down = jump_down

func _set_fly_mode(enabled: bool) -> void:
    fly_mode = enabled
    velocity = Vector3.ZERO
    mantle_active = false
    ads = false
    reloading = false
    jump_was_down = false
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
    var ledge_height: float = ledge_position.y - global_position.y
    if ledge_height < MANTLE_MIN_HEIGHT or ledge_height > MANTLE_MAX_HEIGHT:
        return false

    mantle_start = global_position
    mantle_target = ledge_position + forward * 0.32 + Vector3.UP * 0.06
    mantle_elapsed = 0.0
    mantle_duration = lerpf(0.22, 0.34, inverse_lerp(MANTLE_MIN_HEIGHT, MANTLE_MAX_HEIGHT, ledge_height))
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
    global_position = mantle_start.lerp(mantle_target, smooth_amount)
    global_position.y += sin(amount * PI) * 0.14
    if amount >= 1.0:
        global_position = mantle_target
        collision_layer = mantle_saved_layer
        collision_mask = mantle_saved_mask
        mantle_active = false
        velocity = -global_transform.basis.z * 1.2

func _smooth01(value: float) -> float:
    var x: float = clampf(value, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)

func _stage(value: float, start_t: float, end_t: float) -> float:
    if end_t <= start_t:
        return 1.0 if value >= end_t else 0.0
    return _smooth01((value - start_t) / (end_t - start_t))

func _animate_weapon(horizontal_speed: float) -> void:
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
        crosshair.visible = not ads and ads_blend < 0.05 and not reloading
    if is_instance_valid(ads_dot):
        # The authored UZI now uses its physical iron sights for ADS. Keeping
        # a screen-space dot would hide alignment errors and does not match the
        # requested iron-sight reference.
        ads_dot.visible = false

func shoot() -> void:
    if not alive or reloading or fire_cooldown > 0.0:
        return
    if ammo <= 0:
        hud_status.text = "EMPTY — press R"
        return

    ammo -= 1
    fire_cooldown = AUTO_FIRE_INTERVAL
    muzzle_timer = 0.055
    weapon_kick = 1.0
    recoil_velocity += 0.028 if ads_blend > 0.6 else 0.048

    # Put recoil into the real camera aim direction. Positive local X matches
    # the existing mouse-look convention for looking upward. We intentionally
    # do not auto-return this angle: during a burst the player counters the
    # climb by pulling the mouse slightly down, and the centered camera ray
    # follows the resulting sight direction exactly.
    var recoil_degrees: float = ADS_RECOIL_DEGREES_PER_SHOT if ads_blend > 0.6 else HIP_RECOIL_DEGREES_PER_SHOT
    head.rotate_x(deg_to_rad(recoil_degrees))
    var recoil_head_rot: Vector3 = head.rotation
    recoil_head_rot.x = clampf(recoil_head_rot.x, deg_to_rad(-84.0), deg_to_rad(84.0))
    head.rotation = recoil_head_rot

    if is_instance_valid(uzi_viewmodel):
        uzi_viewmodel.call("play_fire")

    # With the physical front/rear iron sights aligned to camera center, keep
    # ADS dispersion tiny so the shot follows the sight picture instead of
    # visibly missing a correctly aligned post.
    var spread: float = 0.00025 if ads_blend > 0.6 else 0.008
    spread += recoil_pitch * 0.045
    var origin: Vector3 = camera.global_position
    var direction: Vector3 = -camera.global_transform.basis.z
    direction = direction.rotated(camera.global_transform.basis.y, randf_range(-spread, spread))
    direction = direction.rotated(camera.global_transform.basis.x, randf_range(-spread, spread))
    var end: Vector3 = origin + direction * 120.0

    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end, 1 | 2)
    query.exclude = [get_rid()]
    var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if not result.is_empty():
        var collider: Object = result.get("collider") as Object
        if collider and collider.has_method("take_damage"):
            collider.take_damage(randf_range(32.0, 43.0), self)
            hit_marker = 0.14

    _update_hud()

func start_reload() -> void:
    if not alive or reloading or ammo >= mag_size or reserve <= 0:
        return
    reload_empty = ammo <= 0
    reload_duration = 3.75 if reload_empty else 3.10
    if is_instance_valid(uzi_viewmodel):
        var authored_duration: Variant = uzi_viewmodel.call("get_reload_duration", reload_empty)
        if authored_duration is float:
            reload_duration = maxf(float(authored_duration), 1.0)
        uzi_viewmodel.call("play_reload", reload_empty)
    reloading = true
    ads = false
    reload_time = 0.0
    hud_status.text = "Empty reload…" if reload_empty else "Reloading…"

func _finish_reload() -> void:
    var needed: int = mag_size - ammo
    var moved: int = mini(needed, reserve)
    ammo += moved
    reserve -= moved
    reloading = false
    reload_time = 0.0
    reload_empty = false
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

func take_damage(amount: float) -> void:
    if not alive:
        return
    health -= amount
    damage_flash = 0.75
    if health <= 0.0:
        health = 0.0
        alive = false
        ads = false
        if is_instance_valid(ads_dot):
            ads_dot.visible = false
        hud_status.text = "You were eliminated — press Enter to restart"
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        died.emit()
    _update_hud()

func notify_kill() -> void:
    kills += 1
    reserve = mini(reserve + 6, 240)
    hit_marker = 0.18
    _update_hud()

func set_wave(value: int) -> void:
    wave = value
    _update_hud()

func _process(_delta: float) -> void:
    if not alive and Input.is_key_pressed(KEY_ENTER):
        get_tree().reload_current_scene()

func _update_hud() -> void:
    if not hud_health:
        return
    hud_health.text = "HP %d" % int(ceil(health))
    hud_ammo.text = "AMMO %d / %d" % [ammo, reserve]
    hud_kills.text = "KILLS %d" % kills
    hud_wave.text = "WAVE %d" % wave
