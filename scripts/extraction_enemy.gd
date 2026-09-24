extends "res://scripts/enemy.gd"

signal defeated(position: Vector3)
var approved_visual: PackedScene
var defeat_reported := false

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
