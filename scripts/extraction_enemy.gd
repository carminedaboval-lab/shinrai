extends "res://scripts/enemy.gd"

signal defeated(position: Vector3)
var approved_visual: PackedScene
var defeat_reported := false
var pistol_muzzle: Marker3D
var stun_muzzle: Marker3D
var pistol_tracer_material: StandardMaterial3D
var stun_tracer_material: StandardMaterial3D
var last_weapon: String = "pistol"
var shots_since_stun: int = 0
var stun_cooldown: float = 0.0
var shot_color: Color = Color(1.0, 0.58, 0.18)

func _ready() -> void:
	# The showcase guard begins about twenty metres from deployment.
	attack_range = 22.0
	super._ready()

func _build_collision() -> void:
	super._build_collision()
	# The supplied K17 has wide weapon arms and raised fins. Keep those visible
	# parts hittable without using the 400k-face render mesh for physics.
	for side: float in [-1.0, 1.0]:
		_add_k17_box_hit("WeaponArm", Vector3(side * 0.66, 0.67, 0.0), Vector3(0.76, 0.42, 0.70))
		_add_k17_box_hit("UpperFin", Vector3(side * 0.55, 1.25, 0.0), Vector3(0.48, 0.84, 0.54))

func _add_k17_box_hit(label: String, center: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = "%s_%s_Hit" % ["Left" if center.x < 0.0 else "Right", label]
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center
	add_child(collision)

func _refresh_navigation_path(destination: Vector3) -> void:
	super._refresh_navigation_path(destination)
	# A refreshed grid route begins with the cell behind the drone. Once the
	# drone has entered that 4 m cell, skip it so frequent replans do not make
	# patrols oscillate between their starting cell and the next waypoint.
	if navigation_path.size() > 1:
		var first: Vector3 = navigation_path[0]
		if Vector2(global_position.x, global_position.z).distance_to(Vector2(first.x, first.z)) < 2.9:
			navigation_path_index = 1

func _build_visual_socket() -> void:
	# No proxy fallback: the raid controller refuses to spawn without real art.
	assert(approved_visual != null)
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	# The supplied static mesh's feet start 0.259 m above its origin. Drop only
	# the artwork so the feet meet the lawn; keep CharacterBody collision upright.
	visual_root.position.y = -0.22
	add_child(visual_root)
	visual_root.add_child(approved_visual.instantiate())
	_setup_muzzle_light()
	pistol_muzzle = Marker3D.new()
	pistol_muzzle.name = "PistolMuzzle"
	pistol_muzzle.position = Vector3(0.66, 0.92, -0.55)
	visual_root.add_child(pistol_muzzle)
	stun_muzzle = Marker3D.new()
	stun_muzzle.name = "StunMuzzle"
	stun_muzzle.position = Vector3(-0.66, 0.92, -0.55)
	visual_root.add_child(stun_muzzle)
	pistol_tracer_material = _make_tracer_material(Color(1.0, 0.58, 0.18))
	stun_tracer_material = _make_tracer_material(Color(0.22, 0.86, 1.0))

func _make_tracer_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	return material

func _update_timers(delta: float) -> void:
	super._update_timers(delta)
	stun_cooldown = maxf(0.0, stun_cooldown - delta)
	if not is_instance_valid(muzzle_light):
		return
	if muzzle_timer > 0.0:
		muzzle_light.light_color = shot_color
		muzzle_light.omni_range = 5.0 if last_weapon == "stun" else 4.5
		return
	var park_node: Node = get_parent()
	var night: bool = park_node != null and bool(park_node.get("is_night_mode"))
	muzzle_light.light_color = Color("#79a9c4")
	muzzle_light.omni_range = 3.2
	muzzle_light.light_energy = 0.55 if night else 0.0

func _shoot_at_player(distance: float) -> void:
	if not is_instance_valid(target):
		return
	# A stun follows two pistol shots, then needs time to recharge. The player
	# handles stun immunity so several guards cannot chain-disable movement.
	var use_stun: bool = (
		shots_since_stun >= 2
		and stun_cooldown <= 0.0
		and distance <= 17.0
		and target.has_method("apply_stun")
	)
	var muzzle: Marker3D = stun_muzzle if use_stun else pistol_muzzle
	if not is_instance_valid(muzzle):
		return
	if use_stun:
		last_weapon = "stun"
		shots_since_stun = 0
		stun_cooldown = 7.0
		attack_cooldown = randf_range(1.5, 1.85)
		shot_color = Color(0.22, 0.86, 1.0)
	else:
		last_weapon = "pistol"
		shots_since_stun = mini(2, shots_since_stun + 1)
		attack_cooldown = randf_range(0.75, 1.2)
		shot_color = Color(1.0, 0.58, 0.18)
	muzzle_timer = 0.12 if use_stun else 0.07
	muzzle_light.position = muzzle.position
	var shot_origin: Vector3 = muzzle.global_position
	var target_point: Vector3 = target.global_position + Vector3.UP * 1.18
	# World-space scatter keeps pistol lethality close to the old distance-based
	# hit chance while making every miss visible in the shot path.
	var scatter: float = (0.20 + distance * 0.025) if use_stun else (0.35 + distance * 0.05)
	var aim_point: Vector3 = (
		target_point
		+ global_transform.basis.x * randf_range(-scatter, scatter)
		+ Vector3.UP * randf_range(-scatter * 0.7, scatter * 0.7)
	)
	var shot_direction: Vector3 = (aim_point - shot_origin).normalized()
	var shot_end: Vector3 = shot_origin + shot_direction * (shot_origin.distance_to(target_point) + 2.0)
	var query := PhysicsRayQueryParameters3D.create(shot_origin, shot_end, 1 | 2)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var visible_end: Vector3 = hit.get("position", shot_end) as Vector3
	# Stop the visible streak before the player's camera. A full cylinder ending
	# at the near plane expands into a distracting screen-wide wedge.
	var tracer_end := visible_end
	if hit.get("collider") == target:
		tracer_end -= shot_direction * minf(1.6, shot_origin.distance_to(visible_end) * 0.35)
	_show_tracer(shot_origin, tracer_end, use_stun)
	if hit.get("collider") != target:
		return
	if use_stun:
		target.call("apply_stun", 1.1)
	elif target.has_method("take_damage"):
		target.call("take_damage", randf_range(5.0, 9.0))

func _show_tracer(start_point: Vector3, end_point: Vector3, use_stun: bool) -> void:
	var shot: Vector3 = end_point - start_point
	var shot_length := shot.length()
	if shot_length < 0.01:
		return
	# Keep both effects near the drone. A full beam to the player fills the
	# screen when its cylinder approaches the first-person camera.
	var shot_direction := shot / shot_length
	var streak_start := start_point + shot_direction * minf(0.25, shot_length * 0.1)
	var beam := shot_direction * minf(shot_length - start_point.distance_to(streak_start), 4.5 if use_stun else 2.6)
	var shape := CylinderMesh.new()
	shape.height = beam.length()
	shape.top_radius = 0.032 if use_stun else 0.014
	shape.bottom_radius = shape.top_radius
	shape.radial_segments = 6
	var tracer := MeshInstance3D.new()
	tracer.name = "StunBolt" if use_stun else "PistolTracer"
	tracer.mesh = shape
	tracer.material_override = stun_tracer_material if use_stun else pistol_tracer_material
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(tracer)
	tracer.global_transform = Transform3D(
		Basis(Quaternion(Vector3.UP, beam.normalized())),
		streak_start + beam * 0.5
	)
	get_tree().create_timer(0.22 if use_stun else 0.12, false).timeout.connect(func() -> void:
		if is_instance_valid(tracer):
			tracer.queue_free()
	)

func take_damage(amount: float, source: Node = null) -> void:
	if defeat_reported:
		return
	super.take_damage(amount, source)
	if health <= 0.0:
		defeat_reported = true
		defeated.emit(global_position)

func hear_noise(point: Vector3, radius: float) -> void:
	if global_position.distance_to(point) > radius or state == AIState.COMBAT:
		return
	last_seen_position = point
	last_seen_valid = true
	_enter_state(AIState.SEARCH)
