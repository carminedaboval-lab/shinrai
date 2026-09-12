extends Node3D

signal status_changed(text: String)

# The complete authored asset is bundled with the project. Loading is local and
# synchronous from Godot's imported resource cache; gameplay never depends on a
# network request or a user:// download.
const MODEL_PATH: String = "res://assets/uzi/scene.gltf"
# v6: compensate for the authored arms sitting above the model origin.
# Increasing MODEL_SCALE also raises them; recheck this Y offset after scaling.
const MODEL_POSITION: Vector3 = Vector3(0.0, -2.16, -0.25)
const MODEL_ROTATION: Vector3 = Vector3(0.0, PI, 0.0)
const MODEL_SCALE: float = 1.48
const VIEWMODEL_LAYER: int = 1 << 19
# v10.6 visual recoil overlay. Hip fire keeps the authored UZI Fire clip and
# full visual kick. In ADS, the physical rear peep must remain readable while
# the camera itself climbs, so only a small fraction of this outer-root kick is
# retained. This prevents sustained automatic fire from sweeping the iron sight
# across the target while still giving visible weapon response.
const SHOT_RECOIL_BACK_OFFSET: float = 0.028
const SHOT_RECOIL_UP_OFFSET: float = 0.004
const SHOT_RECOIL_PITCH_RADIANS: float = 0.018
const ADS_VISUAL_RECOIL_SCALE: float = 0.12
const ADS_FIRE_ANIMATION_CUTOFF: float = 0.70

var imported_root: Node3D
var animation_player: AnimationPlayer
var loaded: bool = false
var failed: bool = false
var ads_blend: float = 0.0
var shot_kick: float = 0.0
var move_speed: float = 0.0
var bob_phase: float = 0.0

var equip_anim_name: String = ""
var idle_anim_name: String = ""
var walk_anim_name: String = ""
var run_anim_name: String = ""
var fire_anim_name: String = ""
var reload_anim_name: String = ""
var empty_reload_anim_name: String = ""
var aim_anim_name: String = ""

# ADS v10.3: reference-matched real peep-sight eye relief.
#
# The v10.1 capture showed that the transform was centering a point just below
# the visible rear peep hole. That left the solid rear leaf sitting across the
# firing ray even though the sight assembly looked nearly centered. The rear
# marker below is the aperture center reconstructed from the supplied gameplay
# frame at full ADS. Keeping the front marker from v10.1 while correcting the
# rear point reduces the excessive pitch and makes the real rear->front sight
# line pass through the visible peep instead of the leaf beneath it.
#
# The supplied comparison reference shows a noticeably larger rear-sight frame
# than v10.1. v10.3 keeps the corrected real peep center and moves the eye only
# 5.5 cm closer than v10.2. This is a conservative reference-matched step: large
# enough for the physical aperture to frame the view, but deliberately short of
# another blind v8-style close-up.
const REAR_SIGHT_LOCAL: Vector3 = Vector3(0.06969, 0.01023, -0.74390)
const FRONT_SIGHT_LOCAL: Vector3 = Vector3(0.05452, 0.02204, -1.18766)
const ADS_REAR_DEPTH: float = 0.205

var rear_sight_point: Node3D
var front_sight_point: Node3D

var hip_pos: Vector3 = Vector3(0.190, -0.100, 0.100)
# Fallback values are the marker-derived endpoint. _derive_ads_transform_from_sights()
# recomputes them at startup so the relationship stays explicit in the project.
var ads_pos: Vector3 = Vector3(-0.09506, 0.00956, 0.48109)
var hip_rot: Vector3 = Vector3(deg_to_rad(-1.0), deg_to_rad(-7.0), deg_to_rad(-3.8))
var ads_rot: Vector3 = Vector3(deg_to_rad(-1.5245), deg_to_rad(-1.9572), 0.0)

func _ready() -> void:
    name = "UZI_Viewmodel_CC_BY_4"
    visible = false
    _build_sight_markers()
    _derive_ads_transform_from_sights()
    call_deferred("_load_bundled_model")

func _build_sight_markers() -> void:
    rear_sight_point = Node3D.new()
    rear_sight_point.name = "RearSightPoint"
    rear_sight_point.position = REAR_SIGHT_LOCAL
    add_child(rear_sight_point)

    front_sight_point = Node3D.new()
    front_sight_point.name = "FrontSightPoint"
    front_sight_point.position = FRONT_SIGHT_LOCAL
    add_child(front_sight_point)

func _derive_ads_transform_from_sights() -> void:
    if not is_instance_valid(rear_sight_point) or not is_instance_valid(front_sight_point):
        return

    var sight_axis: Vector3 = front_sight_point.position - rear_sight_point.position
    if sight_axis.length_squared() <= 0.000001:
        return
    sight_axis = sight_axis.normalized()

    # Default Godot Euler order is Y-X-Z. First remove the vertical component
    # with pitch, then the horizontal component with yaw. The resulting basis
    # maps the real rear->front sight line exactly onto camera forward (-Z).
    var pitch: float = -atan2(sight_axis.y, -sight_axis.z)
    var pitch_basis: Basis = Basis(Vector3.RIGHT, pitch)
    var pitched_axis: Vector3 = pitch_basis * sight_axis
    var yaw: float = atan2(pitched_axis.x, -pitched_axis.z)
    ads_rot = Vector3(pitch, yaw, 0.0)

    var ads_basis: Basis = Basis.from_euler(ads_rot)
    var rear_target: Vector3 = Vector3(0.0, 0.0, -ADS_REAR_DEPTH)
    ads_pos = rear_target - ads_basis * rear_sight_point.position

func _process(delta: float) -> void:
    shot_kick = move_toward(shot_kick, 0.0, delta * 8.0)
    bob_phase += move_speed * delta * 1.65
    var bob_weight: float = clampf(move_speed / 8.0, 0.0, 1.0) * (1.0 - ads_blend * 0.92)
    var bob: Vector3 = Vector3(
        sin(bob_phase * 5.2) * 0.008,
        abs(cos(bob_phase * 5.2)) * 0.006,
        0.0
    ) * bob_weight
    var target_pos: Vector3 = hip_pos.lerp(ads_pos, ads_blend) + bob
    var visual_recoil_scale: float = lerpf(1.0, ADS_VISUAL_RECOIL_SCALE, ads_blend)
    target_pos.z += shot_kick * SHOT_RECOIL_BACK_OFFSET * visual_recoil_scale
    target_pos.y += shot_kick * SHOT_RECOIL_UP_OFFSET * visual_recoil_scale
    var target_rot: Vector3 = hip_rot.lerp(ads_rot, ads_blend)
    target_rot.x += shot_kick * SHOT_RECOIL_PITCH_RADIANS * visual_recoil_scale
    position = position.lerp(target_pos, 0.28)
    rotation = rotation.lerp(target_rot, 0.25)

func _load_bundled_model() -> void:
    if loaded or failed:
        return
    status_changed.emit("Loading bundled UZI hands + weapon…")

    var model_resource: Resource = ResourceLoader.load(MODEL_PATH)
    if model_resource == null or not (model_resource is PackedScene):
        _fail("Bundled UZI scene could not be loaded")
        return

    var packed_scene: PackedScene = model_resource as PackedScene
    var generated: Node = packed_scene.instantiate()
    if generated == null or not (generated is Node3D):
        if generated != null:
            generated.queue_free()
        _fail("Bundled UZI scene generated no 3D root")
        return

    imported_root = generated as Node3D
    imported_root.name = "UZI_Ultimate_FPS_Animations"
    imported_root.position = MODEL_POSITION
    imported_root.rotation = MODEL_ROTATION
    imported_root.scale = Vector3.ONE * MODEL_SCALE
    add_child(imported_root)

    _prepare_imported_nodes(imported_root)
    _build_viewmodel_light()
    animation_player = _find_first_animation_player(imported_root)
    if animation_player != null:
        _discover_animations()
        animation_player.animation_finished.connect(_on_animation_finished)
        _configure_looping_clips()

    loaded = true
    visible = true
    if animation_player != null and equip_anim_name != "":
        animation_player.play(equip_anim_name, 0.0)
    else:
        _play_locomotion_or_idle()
    status_changed.emit("UZI ready · bundled locally · RMB ADS · R reload")

func _prepare_imported_nodes(node: Node) -> void:
    var lower_name: String = String(node.name).to_lower()
    if node is Camera3D:
        (node as Camera3D).current = false
        (node as Camera3D).visible = false
    elif node is Light3D:
        (node as Light3D).visible = false
    elif node is MeshInstance3D:
        var mesh_node: MeshInstance3D = node as MeshInstance3D
        mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mesh_node.layers = VIEWMODEL_LAYER
        # The source's bind-pose bounds do not contain every animated vertex.
        # A generous cull margin prevents the complete skinned rig from being
        # discarded while its authored animation is visibly in front of camera.
        mesh_node.extra_cull_margin = 2.0
        # The Sketchfab source includes presentation-only sky and aim-card
        # geometry. Neither belongs in Blacksite's first-person view.
        if lower_name.contains("sky") or lower_name.contains("dome") or lower_name.begins_with("aim"):
            mesh_node.visible = false
    for child: Node in node.get_children():
        _prepare_imported_nodes(child)

func _build_viewmodel_light() -> void:
    var fill_light: OmniLight3D = OmniLight3D.new()
    fill_light.name = "ViewmodelFillLight"
    fill_light.position = Vector3(0.35, 0.28, 0.18)
    fill_light.light_color = Color(0.72, 0.84, 1.0)
    fill_light.light_energy = 3.2
    fill_light.omni_range = 4.0
    fill_light.shadow_enabled = false
    fill_light.light_cull_mask = VIEWMODEL_LAYER
    add_child(fill_light)

func _find_first_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child: Node in node.get_children():
        var found: AnimationPlayer = _find_first_animation_player(child)
        if found != null:
            return found
    return null

func _discover_animations() -> void:
    if animation_player == null:
        return
    var names: PackedStringArray = animation_player.get_animation_list()
    equip_anim_name = _find_animation_name(names, ["equip"], ["unequip"])
    idle_anim_name = _find_animation_name(names, ["idle"], [])
    walk_anim_name = _find_animation_name(names, ["walk"], [])
    run_anim_name = _find_animation_name(names, ["run"], [])
    fire_anim_name = _find_animation_name(names, ["fire"], ["firemode"])
    if fire_anim_name == "":
        fire_anim_name = _find_animation_name(names, ["shoot"], [])
    reload_anim_name = _find_animation_name(names, ["reload"], ["empty"])
    empty_reload_anim_name = _find_animation_name(names, ["reload", "empty"], [])
    aim_anim_name = _find_animation_name(names, ["aim"], [])
    if aim_anim_name == "":
        aim_anim_name = _find_animation_name(names, ["ads"], [])

func _find_animation_name(names: PackedStringArray, required: Array[String], excluded: Array[String]) -> String:
    for animation_name: String in names:
        var lower: String = animation_name.to_lower()
        var matches: bool = true
        for word: String in required:
            if not lower.contains(word):
                matches = false
                break
        if not matches:
            continue
        for word: String in excluded:
            if lower.contains(word):
                matches = false
                break
        if matches:
            return animation_name
    return ""

func _configure_looping_clips() -> void:
    _set_animation_loop(idle_anim_name)
    _set_animation_loop(walk_anim_name)
    _set_animation_loop(run_anim_name)

func _set_animation_loop(animation_name: String) -> void:
    if animation_player == null or animation_name == "" or not animation_player.has_animation(animation_name):
        return
    var animation: Animation = animation_player.get_animation(animation_name)
    if animation != null:
        animation.loop_mode = Animation.LOOP_LINEAR

func _play_locomotion_or_idle() -> void:
    if animation_player == null or not loaded:
        return
    if _is_action_animation_playing():
        return

    var desired: String = idle_anim_name
    if ads_blend < 0.55:
        if move_speed > 6.1 and run_anim_name != "":
            desired = run_anim_name
        elif move_speed > 0.2 and walk_anim_name != "":
            desired = walk_anim_name
    if desired != "" and animation_player.current_animation != desired:
        animation_player.play(desired, 0.12)

func _is_action_animation_playing() -> bool:
    if animation_player == null or not animation_player.is_playing():
        return false
    var current: String = String(animation_player.current_animation).to_lower()
    return (
        current.contains("equip")
        or current.contains("fire")
        or current.contains("reload")
        or current.contains("inspect")
    )

func _on_animation_finished(_animation_name: StringName) -> void:
    _play_locomotion_or_idle()

func set_ads_blend(value: float) -> void:
    var previous: float = ads_blend
    ads_blend = clampf(value, 0.0, 1.0)
    if animation_player == null:
        return

    # This asset has no dedicated ADS clip in its authored animation set. The
    # complete rig is centered with the transforms above. If a compatible
    # future revision adds an Aim/ADS clip, it is picked up automatically.
    if aim_anim_name != "" and previous < 0.55 and ads_blend >= 0.55 and not _is_action_animation_playing():
        animation_player.play(aim_anim_name, 0.12)
    elif previous >= 0.55 and ads_blend < 0.55:
        _play_locomotion_or_idle()

func set_move_speed(value: float) -> void:
    move_speed = maxf(value, 0.0)
    _play_locomotion_or_idle()

func play_fire() -> void:
    if not loaded:
        return
    shot_kick = 1.0
    # The authored Fire clip moves the UZI body substantially. That looks good
    # from hip fire, but at full ADS it physically sweeps the tiny rear sight
    # across the target on every automatic shot. Keep the authored clip for hip
    # fire / ADS transition, while full ADS uses camera climb plus the restrained
    # procedural viewmodel impulse above so the real iron sight remains usable.
    if animation_player != null and fire_anim_name != "" and ads_blend < ADS_FIRE_ANIMATION_CUTOFF:
        animation_player.play(fire_anim_name, 0.035)

func play_reload(empty: bool) -> void:
    if animation_player == null:
        return
    var chosen: String = empty_reload_anim_name if empty and empty_reload_anim_name != "" else reload_anim_name
    if chosen != "":
        animation_player.play(chosen, 0.08)

func get_reload_duration(empty: bool) -> float:
    if animation_player == null:
        return 3.75 if empty else 3.10
    var chosen: String = empty_reload_anim_name if empty and empty_reload_anim_name != "" else reload_anim_name
    if chosen == "" or not animation_player.has_animation(chosen):
        return 3.75 if empty else 3.10
    var animation: Animation = animation_player.get_animation(chosen)
    if animation == null:
        return 3.75 if empty else 3.10
    return maxf(animation.length, 1.0)

func _fail(message: String) -> void:
    failed = true
    visible = false
    status_changed.emit(message)
