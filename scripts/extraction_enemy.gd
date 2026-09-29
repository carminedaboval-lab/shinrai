extends "res://scripts/enemy.gd"

signal defeated(position: Vector3)
var approved_visual: PackedScene
var defeat_reported := false

func _build_collision() -> void:
	super._build_collision()
	# The supplied K17 has wide weapon arms and raised fins. Keep those visible
	# parts hittable without using the 400k-face render mesh for physics.
	for side: float in [-1.0, 1.0]:
		_add_k17_box_hit("WeaponArm", Vector3(side * 0.66, 0.89, 0.0), Vector3(0.76, 0.42, 0.70))
		_add_k17_box_hit("UpperFin", Vector3(side * 0.55, 1.47, 0.0), Vector3(0.48, 0.84, 0.54))

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
	add_child(visual_root)
	visual_root.add_child(approved_visual.instantiate())
	_setup_muzzle_light()

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
