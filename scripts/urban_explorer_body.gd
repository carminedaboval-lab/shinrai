extends Node3D
## Presentation only. The production CharacterBody3D owns collision and movement.

const MODEL_PATH := "res://assets/characters/urban_explorer_2050/urban_explorer_2050_body.glb"
const CLIPS := {
    "idle": "Idle_02", "walk": "Walking", "run": "Running",
    "crouch": "Cautious_Crouch_Walk_Forward", "jump": "Regular_Jump",
    "mantle": "Parkour_Vault", "swim": "Swim_Forward", "swim_idle": "Swim_Idle"
}
@export var first_person := true
var model: Node3D
var animator: AnimationPlayer
var player: CharacterBody3D
var current_state := ""
var ready_for_use := false
var _stationary_crouch := false
var _parts: Array[MeshInstance3D] = []
var _clips: Dictionary = {}
var skeleton: Skeleton3D
var _foot_reference: Dictionary = {}

func _ready() -> void:
    name = "UrbanExplorerBody"
    player = get_parent() as CharacterBody3D
    var packed := load(MODEL_PATH) as PackedScene
    if packed == null:
        push_error("Urban Explorer body model unavailable")
        return
    model = packed.instantiate() as Node3D
    model.rotation.y = PI
    model.position.z = 0.12
    add_child(model)
    _collect(model)
    if animator == null:
        push_error("Urban Explorer body animation player unavailable")
        return
    _prepare_clips()
    set_first_person(first_person)
    ready_for_use = _clips.size() == CLIPS.size()

func _collect(node: Node) -> void:
    if node is Skeleton3D:
        skeleton = node as Skeleton3D
        for bone in range(skeleton.get_bone_count()):
            var bone_name := skeleton.get_bone_name(bone)
            if bone_name.ends_with("Foot") or bone_name.ends_with("ToeBase"):
                _foot_reference[bone] = skeleton.get_bone_global_rest(bone).origin.y
    if node is AnimationPlayer:
        animator = node as AnimationPlayer
    if node is MeshInstance3D:
        var mesh := node as MeshInstance3D
        mesh.layers = 1
        mesh.extra_cull_margin = 2.0
        _parts.append(mesh)
    for child in node.get_children():
        _collect(child)

func _prepare_clips() -> void:
    var library := AnimationLibrary.new()
    for state: String in CLIPS:
        var source_name := ""
        for available: String in animator.get_animation_list():
            if available == CLIPS[state] or available.ends_with("/" + CLIPS[state]):
                source_name = available
                break
        if source_name.is_empty():
            push_error("Urban Explorer missing motion: " + CLIPS[state])
            continue
        var clip := animator.get_animation(source_name).duplicate(true) as Animation
        var hip_matched := false
        # Keep vertical crouch/stride motion. Controller translation remains the
        # only source of travel; library vault/swim paths must not move the mesh away.
        for track in range(clip.get_track_count()):
            if clip.track_get_type(track) != Animation.TYPE_POSITION_3D:
                continue
            var path := String(clip.track_get_path(track))
            if path.ends_with(":Hips") or path.ends_with(":mixamorig_Hips") or path.ends_with(":mixamorig:Hips"):
                hip_matched = true
                var first_position: Vector3 = clip.track_get_key_value(track, 0)
                for key in range(clip.track_get_key_count(track)):
                    var value: Vector3 = clip.track_get_key_value(track, key)
                    # The corrected crouch includes a measured hip-back offset.
                    # Remove clip travel while retaining that anatomical fit.
                    value.x = first_position.x if state == "crouch" else 0.0
                    value.z = first_position.z if state == "crouch" else 0.0
                    if state in ["jump", "mantle"]:
                        value.y = 0.800334
                    elif state == "swim":
                        # The source swim pose is authored near the floor. Lift
                        # its horizontal torso to the controller's floating body.
                        value.y += 0.95
                    clip.track_set_key_value(track, key, value)
        if not hip_matched:
            push_error("Urban Explorer missing hip position track: " + source_name)
            continue
        clip.loop_mode = Animation.LOOP_NONE if state in ["jump", "mantle"] else Animation.LOOP_LINEAR
        library.add_animation(state, clip)
        _clips[state] = "presentation/" + state
    animator.add_animation_library("presentation", library)

func set_first_person(enabled: bool) -> void:
    first_person = enabled
    if model != null:
        # Place the local waist cut behind the downward camera frustum.
        # Collision and the complete external-body framing remain unchanged.
        model.position.z = 0.32 if enabled else 0.12
    for mesh in _parts:
        var locally_hidden := String(mesh.name).begins_with("Body_Head") or String(mesh.name).begins_with("Body_Arms") or String(mesh.name).begins_with("Body_TorsoUpper")
        mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if enabled and locally_hidden else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _process(_delta: float) -> void:
    if not ready_for_use or player == null:
        return
    visible = player.alive and not player.fly_mode
    if not visible:
        return
    var speed := Vector2(player.velocity.x, player.velocity.z).length()
    var next := "idle"
    if player.mantle_active:
        next = "mantle"
    elif player.is_swimming:
        next = "swim" if player.velocity.length() > 0.15 else "swim_idle"
    elif not player.is_on_floor():
        next = "jump"
    elif player.crouching:
        next = "crouch"
    elif speed > 0.15:
        next = "run" if player.sprinting else "walk"
    play_state(next, speed)
    if next in ["idle", "walk", "run"] and skeleton != null:
        var foot_offset := INF
        for bone: int in _foot_reference:
            foot_offset = minf(foot_offset, skeleton.get_bone_global_pose(bone).origin.y - float(_foot_reference[bone]))
        model.position.y = 0.025 - foot_offset if is_finite(foot_offset) else 0.025
    else:
        model.position.y = 0.025
    if next == "mantle":
        var length := animator.get_animation(_clips[next]).length
        animator.seek(clampf(player.mantle_elapsed / maxf(player.mantle_duration, 0.001), 0.0, 1.0) * length, true)

func play_state(state: String, speed: float = 0.0) -> void:
    if not _clips.has(state):
        return
    var stationary_crouch := state == "crouch" and speed < 0.15
    if current_state != state:
        current_state = state
        animator.play(_clips[state], 0.0 if stationary_crouch else 0.12)
        _stationary_crouch = false
    if stationary_crouch and not _stationary_crouch:
        # Stop on the measured balanced pose, including after crouch-walking.
        animator.play(_clips[state], 0.0)
        animator.seek(animator.get_animation(_clips[state]).length * 0.35, true)
    _stationary_crouch = stationary_crouch
    animator.speed_scale = 1.0
    if state == "crouch" and speed < 0.15:
        animator.speed_scale = 0.0
    elif state in ["walk", "run", "crouch"]:
        var authored_speed: float = 5.0 if state == "walk" else (8.0 if state == "run" else 2.8)
        animator.speed_scale = clampf(speed / authored_speed, 0.4, 1.6)
