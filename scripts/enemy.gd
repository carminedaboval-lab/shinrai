extends CharacterBody3D

# Hallway/facility enemy AI. Behaviour is deliberately separate from the visual
# model so a production PBR humanoid can replace the proxy without touching AI.

enum AIState {
    PATROL,
    ALERT,
    COMBAT,
    SEARCH,
    RETURN_TO_PATROL,
}

const GRAVITY: float = 18.0
const VISION_RANGE: float = 24.0
const VISION_HALF_ANGLE_DEG: float = 58.0
const ALERT_CONFIRM_TIME: float = 0.42
const LOST_SIGHT_GRACE: float = 1.15
const SEARCH_TOTAL_TIME: float = 10.0
const SEARCH_POINT_WAIT_MIN: float = 0.70
const SEARCH_POINT_WAIT_MAX: float = 1.35
const PATROL_WAIT_MIN: float = 0.55
const PATROL_WAIT_MAX: float = 1.45
const PATROL_SPEED_MULT: float = 0.62
const SEARCH_SPEED_MULT: float = 0.82
const COMBAT_STANDOFF_DISTANCE: float = 7.0
const WAYPOINT_REACHED_DISTANCE: float = 0.58
const DESTINATION_REACHED_DISTANCE: float = 0.72
const PATH_REFRESH_INTERVAL: float = 0.34
const PATH_RETARGET_DISTANCE: float = 0.90

# K17 uses the real authored static scene/model. A .tscn is preferred because it
# preserves the Stage 35 hierarchy, materials, sockets, collision proxies, and LODs.
# The runtime loader never treats renders or image files as a model substitute.
const K17_VISUAL_ROOTS: Array[String] = [
    "res://assets/enemies/k17",
    "res://assets/enemies/k17_drone",
]
const K17_VISUAL_SCENE_CANDIDATES: Array[String] = [
    "res://assets/enemies/k17/K17_Drone_Static.tscn",
    "res://assets/enemies/k17/ProjectShinrai_K17_Stage36_BODY_CORRECTED_STATIC.tscn",
    "res://assets/enemies/k17/ProjectShinrai_K17_Stage35_INGAME_STATIC_TEST.tscn",
    "res://assets/enemies/k17/K17_Drone_Static.glb",
    "res://assets/enemies/k17/ProjectShinrai_K17_Stage36_BODY_CORRECTED_STATIC.glb",
    "res://assets/enemies/k17/ProjectShinrai_K17_Stage35_INGAME_STATIC_TEST.glb",
    "res://assets/enemies/k17_drone/K17_Drone_Static.tscn",
    "res://assets/enemies/k17_drone/ProjectShinrai_K17_Stage36_BODY_CORRECTED_STATIC.tscn",
    "res://assets/enemies/k17_drone/ProjectShinrai_K17_Stage35_INGAME_STATIC_TEST.tscn",
    "res://assets/enemies/k17_drone/K17_Drone_Static.glb",
    "res://assets/enemies/k17_drone/ProjectShinrai_K17_Stage36_BODY_CORRECTED_STATIC.glb",
    "res://assets/enemies/k17_drone/ProjectShinrai_K17_Stage35_INGAME_STATIC_TEST.glb",
    "res://assets/enemies/K17_Drone_Static.tscn",
    "res://assets/enemies/K17_Drone_Static.glb",
]

var target: Node3D
var navigation_source: Node
var health: float = 100.0
var max_health: float = 100.0
var move_speed: float = 2.1
var attack_range: float = 18.0
var attack_cooldown: float = 0.0
var hit_flash: float = 0.0
var muzzle_timer: float = 0.0

var state: AIState = AIState.PATROL
var state_time: float = 0.0
var sight_confirm_time: float = 0.0
var time_since_seen: float = 999.0
var last_seen_position: Vector3 = Vector3.ZERO
var last_seen_valid: bool = false

var patrol_points: Array[Vector3] = []
var patrol_index: int = 0
var patrol_wait: float = 0.0
var search_points: Array[Vector3] = []
var search_index: int = 0
var search_wait: float = 0.0
var search_elapsed: float = 0.0

var navigation_path: PackedVector3Array = PackedVector3Array()
var navigation_path_index: int = 0
var navigation_destination: Vector3 = Vector3.ZERO
var navigation_destination_valid: bool = false
var path_refresh_timer: float = 0.0
var desired_velocity_xz: Vector3 = Vector3.ZERO

var visual_root: Node3D
var proxy_material: StandardMaterial3D
var visor_material: StandardMaterial3D
var proxy_meshes: Array[MeshInstance3D] = []
var muzzle_light: OmniLight3D

func configure(
    p_target: Node3D,
    wave: int,
    p_navigation_source: Node = null,
    p_patrol_points: Array[Vector3] = []
) -> void:
    target = p_target
    navigation_source = p_navigation_source
    max_health = 72.0 + float(wave) * 14.0
    health = max_health
    move_speed = 1.8 + minf(float(wave) * 0.08, 1.2)
    patrol_points = p_patrol_points.duplicate()

func _ready() -> void:
    add_to_group("enemies")
    collision_layer = 2
    collision_mask = 1 | 2
    _build_collision()
    _build_visual_socket()
    _enter_state(AIState.PATROL)

func _build_collision() -> void:
    var body_shape: CollisionShape3D = CollisionShape3D.new()
    body_shape.name = "BodyCollision"
    var capsule: CapsuleShape3D = CapsuleShape3D.new()
    capsule.radius = 0.34
    capsule.height = 1.72
    body_shape.shape = capsule
    body_shape.position = Vector3(0.0, 0.9, 0.0)
    add_child(body_shape)

func _build_visual_socket() -> void:
    visual_root = Node3D.new()
    visual_root.name = "VisualRoot"
    add_child(visual_root)

    for path: String in _get_production_visual_paths():
        if not ResourceLoader.exists(path):
            continue
        var resource: Resource = load(path)
        if resource is PackedScene:
            var production_visual: Node = (resource as PackedScene).instantiate()
            visual_root.add_child(production_visual)
            _setup_muzzle_light()
            print("K17 production visual loaded: %s" % path)
            return

    push_warning(
        "K17 asset missing. Copy the real Stage 35 runtime folder to " +
        "res://assets/enemies/k17; development proxy is active."
    )
    _build_development_proxy()
    _setup_muzzle_light()

func _get_production_visual_paths() -> Array[String]:
    var candidate_paths: Array[String] = []
    for path: String in K17_VISUAL_SCENE_CANDIDATES:
        _append_unique_visual_path(candidate_paths, path)

    # Accept the original package hierarchy when it is pasted intact. Scene
    # files are collected before raw models so sockets and authored structure win.
    var discovered_scenes: Array[String] = []
    var discovered_models: Array[String] = []
    for root_path: String in K17_VISUAL_ROOTS:
        _collect_k17_visual_paths(root_path, discovered_scenes, discovered_models)
    discovered_scenes.sort()
    discovered_models.sort()
    for path: String in discovered_scenes:
        _append_unique_visual_path(candidate_paths, path)
    for path: String in discovered_models:
        _append_unique_visual_path(candidate_paths, path)

    # Retain the original generic production-art socket as a final fallback.
    for path: String in [
        "res://assets/enemies/enemy.tscn",
        "res://assets/enemies/enemy.glb",
        "res://assets/enemies/enemy.gltf",
    ]:
        _append_unique_visual_path(candidate_paths, path)
    return candidate_paths

func _append_unique_visual_path(paths: Array[String], path: String) -> void:
    if not paths.has(path):
        paths.append(path)

func _collect_k17_visual_paths(
    directory_path: String,
    scene_paths: Array[String],
    model_paths: Array[String]
) -> void:
    var directory: DirAccess = DirAccess.open(directory_path)
    if directory == null:
        return

    directory.list_dir_begin()
    var entry_name: String = directory.get_next()
    while not entry_name.is_empty():
        if not entry_name.begins_with("."):
            var entry_path: String = directory_path.path_join(entry_name)
            if directory.current_is_dir():
                _collect_k17_visual_paths(entry_path, scene_paths, model_paths)
            else:
                var lower_name: String = entry_name.to_lower()
                if lower_name.ends_with(".tscn"):
                    scene_paths.append(entry_path)
                elif lower_name.ends_with(".glb") or lower_name.ends_with(".gltf"):
                    model_paths.append(entry_path)
        entry_name = directory.get_next()
    directory.list_dir_end()

func _build_development_proxy() -> void:
    proxy_material = StandardMaterial3D.new()
    proxy_material.albedo_color = Color(0.055, 0.065, 0.078)
    proxy_material.metallic = 0.46
    proxy_material.roughness = 0.38

    visor_material = StandardMaterial3D.new()
    visor_material.albedo_color = Color(0.025, 0.095, 0.12)
    visor_material.metallic = 0.25
    visor_material.roughness = 0.22
    visor_material.emission_enabled = true
    visor_material.emission = Color(0.08, 0.72, 0.95)
    visor_material.emission_energy_multiplier = 3.8

    _proxy_capsule("Torso", Vector3(0.0, 1.17, 0.0), 0.34, 0.75, proxy_material, Vector3(1.0, 1.0, 0.72))
    _proxy_sphere("Helmet", Vector3(0.0, 1.82, 0.0), 0.25, proxy_material, Vector3(0.92, 1.05, 0.98))
    _proxy_box("Visor", Vector3(0.0, 1.84, -0.225), Vector3(0.34, 0.085, 0.035), visor_material)
    _proxy_box("ChestPlate", Vector3(0.0, 1.30, -0.27), Vector3(0.58, 0.48, 0.10), proxy_material)
    _proxy_box("BackUnit", Vector3(0.0, 1.28, 0.30), Vector3(0.44, 0.52, 0.14), proxy_material)

    for side in [-1.0, 1.0]:
        _proxy_capsule("UpperArm", Vector3(0.42 * side, 1.29, -0.02), 0.105, 0.44, proxy_material, Vector3.ONE, Vector3(0.0, 0.0, -0.16 * side))
        _proxy_capsule("Forearm", Vector3(0.34 * side, 0.98, -0.20), 0.095, 0.42, proxy_material, Vector3.ONE, Vector3(-0.65, 0.0, 0.10 * side))
        _proxy_box("ShoulderArmor", Vector3(0.42 * side, 1.48, 0.0), Vector3(0.22, 0.20, 0.32), proxy_material)
        _proxy_capsule("Thigh", Vector3(0.19 * side, 0.62, 0.0), 0.13, 0.52, proxy_material)
        _proxy_capsule("Shin", Vector3(0.19 * side, 0.23, 0.0), 0.11, 0.48, proxy_material)
        _proxy_box("Knee", Vector3(0.19 * side, 0.47, -0.115), Vector3(0.19, 0.18, 0.08), proxy_material)

    _proxy_box("Weapon", Vector3(0.19, 1.09, -0.48), Vector3(0.10, 0.13, 0.83), proxy_material, Vector3(-0.08, 0.0, 0.0))
    _proxy_box("WeaponCell", Vector3(0.19, 1.06, -0.53), Vector3(0.045, 0.05, 0.22), visor_material)

func _proxy_box(
    p_name: String,
    pos: Vector3,
    size: Vector3,
    mat: Material,
    rot: Vector3 = Vector3.ZERO
) -> void:
    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    mesh_instance.name = p_name
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.rotation = rot
    mesh_instance.material_override = mat
    visual_root.add_child(mesh_instance)
    proxy_meshes.append(mesh_instance)

func _proxy_sphere(
    p_name: String,
    pos: Vector3,
    radius: float,
    mat: Material,
    scale_value: Vector3 = Vector3.ONE
) -> void:
    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    mesh_instance.name = p_name
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 32
    mesh.rings = 16
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.scale = scale_value
    mesh_instance.material_override = mat
    visual_root.add_child(mesh_instance)
    proxy_meshes.append(mesh_instance)

func _proxy_capsule(
    p_name: String,
    pos: Vector3,
    radius: float,
    height: float,
    mat: Material,
    scale_value: Vector3 = Vector3.ONE,
    rot: Vector3 = Vector3.ZERO
) -> void:
    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    mesh_instance.name = p_name
    var mesh: CapsuleMesh = CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    mesh.radial_segments = 24
    mesh.rings = 8
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.scale = scale_value
    mesh_instance.rotation = rot
    mesh_instance.material_override = mat
    visual_root.add_child(mesh_instance)
    proxy_meshes.append(mesh_instance)

func _setup_muzzle_light() -> void:
    muzzle_light = OmniLight3D.new()
    muzzle_light.name = "MuzzleFlash"
    muzzle_light.light_color = Color(1.0, 0.58, 0.18)
    muzzle_light.light_energy = 0.0
    muzzle_light.omni_range = 4.5
    muzzle_light.position = Vector3(0.19, 1.12, -0.94)
    visual_root.add_child(muzzle_light)

func take_damage(amount: float, source: Node = null) -> void:
    health -= amount
    hit_flash = 0.10

    if is_instance_valid(source) and source is Node3D:
        last_seen_position = (source as Node3D).global_position
        last_seen_valid = true
        time_since_seen = 0.0
        if state != AIState.COMBAT:
            _enter_state(AIState.ALERT)

    if health <= 0.0:
        if source and source.has_method("notify_kill"):
            source.notify_kill()
        queue_free()

func _physics_process(delta: float) -> void:
    _update_timers(delta)

    if not is_instance_valid(target):
        desired_velocity_xz = Vector3.ZERO
        _apply_movement(delta)
        return

    var target_visible: bool = _can_see_target()
    _update_perception(target_visible, delta)
    _update_state(delta, target_visible)
    _apply_movement(delta)

    if (
        state == AIState.COMBAT
        and target_visible
        and _flat_distance_to(target.global_position) < attack_range
        and attack_cooldown <= 0.0
    ):
        _shoot_at_player(_flat_distance_to(target.global_position))

func _update_timers(delta: float) -> void:
    state_time += delta
    attack_cooldown -= delta
    hit_flash = maxf(0.0, hit_flash - delta)
    muzzle_timer = maxf(0.0, muzzle_timer - delta)
    path_refresh_timer = maxf(0.0, path_refresh_timer - delta)

    if is_instance_valid(muzzle_light):
        muzzle_light.light_energy = 7.0 if muzzle_timer > 0.0 else 0.0

    if is_instance_valid(proxy_material):
        proxy_material.albedo_color = Color(0.62, 0.055, 0.035) if hit_flash > 0.0 else Color(0.055, 0.065, 0.078)

func _update_perception(target_visible: bool, delta: float) -> void:
    if target_visible:
        last_seen_position = target.global_position
        last_seen_valid = true
        time_since_seen = 0.0
    else:
        time_since_seen += delta

func _update_state(delta: float, target_visible: bool) -> void:
    match state:
        AIState.PATROL:
            _state_patrol(delta, target_visible)
        AIState.ALERT:
            _state_alert(delta, target_visible)
        AIState.COMBAT:
            _state_combat(delta, target_visible)
        AIState.SEARCH:
            _state_search(delta, target_visible)
        AIState.RETURN_TO_PATROL:
            _state_return(delta, target_visible)

func _state_patrol(delta: float, target_visible: bool) -> void:
    if target_visible:
        _enter_state(AIState.ALERT)
        return

    if patrol_points.is_empty():
        desired_velocity_xz = Vector3.ZERO
        _scan_idle(delta)
        return

    var point: Vector3 = patrol_points[patrol_index]
    if _flat_distance_to(point) <= DESTINATION_REACHED_DISTANCE:
        desired_velocity_xz = Vector3.ZERO
        patrol_wait -= delta
        _scan_idle(delta)
        if patrol_wait <= 0.0:
            patrol_index = (patrol_index + 1) % patrol_points.size()
            patrol_wait = randf_range(PATROL_WAIT_MIN, PATROL_WAIT_MAX)
            _invalidate_path()
    else:
        _move_toward_path(point, move_speed * PATROL_SPEED_MULT, delta)

func _state_alert(delta: float, target_visible: bool) -> void:
    desired_velocity_xz = Vector3.ZERO

    if target_visible:
        sight_confirm_time += delta
        _face_point(target.global_position, delta, 12.0)
        if sight_confirm_time >= ALERT_CONFIRM_TIME:
            _enter_state(AIState.COMBAT)
        return

    sight_confirm_time = maxf(0.0, sight_confirm_time - delta * 0.8)
    if last_seen_valid:
        _face_point(last_seen_position, delta, 8.0)
        if state_time >= 0.60:
            _enter_state(AIState.SEARCH)
    elif state_time >= 1.0:
        _enter_state(AIState.RETURN_TO_PATROL)

func _state_combat(delta: float, target_visible: bool) -> void:
    if target_visible:
        var distance: float = _flat_distance_to(target.global_position)
        _face_point(target.global_position, delta, 12.0)

        if distance > COMBAT_STANDOFF_DISTANCE:
            _move_toward_path(target.global_position, move_speed, delta)
        else:
            desired_velocity_xz = Vector3.ZERO
        return

    if last_seen_valid and time_since_seen <= LOST_SIGHT_GRACE:
        _move_toward_path(last_seen_position, move_speed * 0.88, delta)
        return

    _enter_state(AIState.SEARCH)

func _state_search(delta: float, target_visible: bool) -> void:
    if target_visible:
        _enter_state(AIState.ALERT)
        return

    search_elapsed += delta
    if search_elapsed >= SEARCH_TOTAL_TIME:
        _enter_state(AIState.RETURN_TO_PATROL)
        return

    if search_points.is_empty():
        _prepare_search_points()
        if search_points.is_empty():
            _enter_state(AIState.RETURN_TO_PATROL)
            return

    var search_target: Vector3 = search_points[search_index]
    if _flat_distance_to(search_target) <= DESTINATION_REACHED_DISTANCE:
        desired_velocity_xz = Vector3.ZERO
        search_wait -= delta
        _scan_idle(delta, 1.55)
        if search_wait <= 0.0:
            search_index += 1
            if search_index >= search_points.size():
                _enter_state(AIState.RETURN_TO_PATROL)
            else:
                search_wait = randf_range(SEARCH_POINT_WAIT_MIN, SEARCH_POINT_WAIT_MAX)
                _invalidate_path()
    else:
        _move_toward_path(search_target, move_speed * SEARCH_SPEED_MULT, delta)

func _state_return(delta: float, target_visible: bool) -> void:
    if target_visible:
        _enter_state(AIState.ALERT)
        return

    if patrol_points.is_empty():
        _enter_state(AIState.PATROL)
        return

    var return_index: int = _nearest_patrol_index()
    var point: Vector3 = patrol_points[return_index]
    if _flat_distance_to(point) <= 0.82:
        patrol_index = return_index
        _enter_state(AIState.PATROL)
    else:
        _move_toward_path(point, move_speed * PATROL_SPEED_MULT, delta)

func _enter_state(new_state: AIState) -> void:
    state = new_state
    state_time = 0.0
    _invalidate_path()

    match new_state:
        AIState.PATROL:
            sight_confirm_time = 0.0
            patrol_wait = randf_range(PATROL_WAIT_MIN, PATROL_WAIT_MAX)
            if not patrol_points.is_empty():
                patrol_index = clampi(patrol_index, 0, patrol_points.size() - 1)
        AIState.ALERT:
            desired_velocity_xz = Vector3.ZERO
            sight_confirm_time = 0.0
        AIState.COMBAT:
            pass
        AIState.SEARCH:
            desired_velocity_xz = Vector3.ZERO
            search_elapsed = 0.0
            search_index = 0
            search_wait = randf_range(SEARCH_POINT_WAIT_MIN, SEARCH_POINT_WAIT_MAX)
            _prepare_search_points()
        AIState.RETURN_TO_PATROL:
            sight_confirm_time = 0.0
            search_points.clear()

func _prepare_search_points() -> void:
    search_points.clear()
    search_index = 0
    if not last_seen_valid:
        return

    if is_instance_valid(navigation_source) and navigation_source.has_method("get_search_positions_world"):
        var result: Variant = navigation_source.call("get_search_positions_world", last_seen_position, 4)
        if result is Array:
            for value: Variant in result:
                if value is Vector3:
                    search_points.append(value)

    if search_points.is_empty():
        search_points.append(_project_to_walkable(last_seen_position))

    search_wait = randf_range(SEARCH_POINT_WAIT_MIN, SEARCH_POINT_WAIT_MAX)
    _invalidate_path()

func _move_toward_path(destination: Vector3, speed: float, delta: float) -> void:
    if not is_instance_valid(navigation_source) or not navigation_source.has_method("get_path_world"):
        var direct_direction: Vector3 = _flat_direction_to(destination)
        desired_velocity_xz = direct_direction * speed
        _face_direction(direct_direction, delta, 8.0)
        return

    var destination_changed: bool = (
        not navigation_destination_valid
        or navigation_destination.distance_to(destination) >= PATH_RETARGET_DISTANCE
    )
    if destination_changed or path_refresh_timer <= 0.0 or navigation_path.is_empty():
        _refresh_navigation_path(destination)

    var direction: Vector3 = _get_navigation_direction()
    if direction.length_squared() > 0.001:
        desired_velocity_xz = direction * speed
        _face_direction(direction, delta, 8.0)
    else:
        desired_velocity_xz = Vector3.ZERO

func _refresh_navigation_path(destination: Vector3) -> void:
    navigation_destination = destination
    navigation_destination_valid = true
    path_refresh_timer = PATH_REFRESH_INTERVAL
    navigation_path = PackedVector3Array()
    navigation_path_index = 0

    var result: Variant = navigation_source.call("get_path_world", global_position, destination)
    if result is PackedVector3Array:
        navigation_path = result
        navigation_path_index = 0

func _get_navigation_direction() -> Vector3:
    while navigation_path_index < navigation_path.size():
        var waypoint: Vector3 = navigation_path[navigation_path_index]
        waypoint.y = global_position.y
        var to_waypoint: Vector3 = waypoint - global_position
        to_waypoint.y = 0.0
        if to_waypoint.length() <= WAYPOINT_REACHED_DISTANCE:
            navigation_path_index += 1
            continue
        return to_waypoint.normalized()
    return Vector3.ZERO

func _invalidate_path() -> void:
    navigation_path = PackedVector3Array()
    navigation_path_index = 0
    navigation_destination_valid = false
    path_refresh_timer = 0.0

func _project_to_walkable(point: Vector3) -> Vector3:
    if is_instance_valid(navigation_source) and navigation_source.has_method("get_nearest_walkable_world"):
        var result: Variant = navigation_source.call("get_nearest_walkable_world", point)
        if result is Vector3:
            return result
    return point

func _apply_movement(delta: float) -> void:
    var desired: Vector3 = desired_velocity_xz
    desired.y = 0.0
    velocity.x = move_toward(velocity.x, desired.x, 7.5 * delta)
    velocity.z = move_toward(velocity.z, desired.z, 7.5 * delta)

    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    else:
        velocity.y = 0.0

    move_and_slide()

func _can_see_target() -> bool:
    if not is_instance_valid(target):
        return false

    var eye: Vector3 = global_position + Vector3.UP * 1.52
    var target_point: Vector3 = target.global_position + Vector3.UP * 1.25
    var to_target: Vector3 = target_point - eye
    var distance: float = to_target.length()
    if distance > VISION_RANGE or distance < 0.01:
        return false

    var flat_to_target: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
    if flat_to_target.length_squared() > 0.001:
        flat_to_target = flat_to_target.normalized()
        var forward: Vector3 = -global_transform.basis.z
        forward.y = 0.0
        if forward.length_squared() > 0.001:
            forward = forward.normalized()
            var threshold: float = cos(deg_to_rad(VISION_HALF_ANGLE_DEG))
            if forward.dot(flat_to_target) < threshold:
                return false

    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, target_point, 1)
    query.exclude = [get_rid()]
    var hit: Dictionary = space.intersect_ray(query)
    return hit.is_empty() or hit.get("collider") == target

func _nearest_patrol_index() -> int:
    if patrol_points.is_empty():
        return 0
    var best_index: int = 0
    var best_distance: float = INF
    for i: int in range(patrol_points.size()):
        var distance: float = global_position.distance_squared_to(patrol_points[i])
        if distance < best_distance:
            best_distance = distance
            best_index = i
    return best_index

func _scan_idle(delta: float, speed_multiplier: float = 1.0) -> void:
    var phase: float = Time.get_ticks_msec() * 0.0015 + float(get_instance_id() % 23)
    var scan_offset: float = sin(phase) * 0.65
    var base_yaw: float = rotation.y
    rotation.y = lerp_angle(base_yaw, base_yaw + scan_offset, clampf(delta * 0.75 * speed_multiplier, 0.0, 1.0))

func _face_point(point: Vector3, delta: float, turn_speed: float) -> void:
    var direction: Vector3 = point - global_position
    direction.y = 0.0
    if direction.length_squared() > 0.001:
        _face_direction(direction.normalized(), delta, turn_speed)

func _face_direction(direction: Vector3, delta: float, turn_speed: float) -> void:
    if direction.length_squared() < 0.001:
        return
    var target_yaw: float = atan2(-direction.x, -direction.z)
    rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))

func _flat_direction_to(point: Vector3) -> Vector3:
    var direction: Vector3 = point - global_position
    direction.y = 0.0
    return direction.normalized() if direction.length_squared() > 0.001 else Vector3.ZERO

func _flat_distance_to(point: Vector3) -> float:
    var delta_pos: Vector3 = point - global_position
    delta_pos.y = 0.0
    return delta_pos.length()

func _shoot_at_player(distance: float) -> void:
    # Kept intentionally close to the existing prototype gunplay. The separate
    # gunplay pass can replace this later without changing AI states.
    attack_cooldown = randf_range(0.7, 1.25)
    muzzle_timer = 0.07
    var accuracy: float = clampf(0.78 - distance * 0.035, 0.28, 0.70)
    if randf() < accuracy and target.has_method("take_damage"):
        target.take_damage(randf_range(5.0, 9.0))
