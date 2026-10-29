extends "res://scripts/midori_park_size_blockout.gd"
## The real park generators, with a separate editing session instead of a raid.
const CreatorPlayer = preload("./creator_player.gd")
var creator_ready := false
var creator_error := ""

func _ready() -> void:
	start_at_night = false
	await super._ready()
	call_deferred("_prepare_creator")

func _spawn_scale_review_player() -> void:
	var rig := CreatorPlayer.new()
	rig.name = "CreatorPlayer"
	rig.position = Vector3(0, 0.2, 160)
	add_child(rig)

func _build_size_hud() -> void:
	pass

func _unhandled_input(_event: InputEvent) -> void:
	# Creator controller owns keys, including day/night, so typing cannot leak here.
	pass

func _prepare_creator() -> void:
	var deadline := Time.get_ticks_msec() + 150000
	var producer_check = preload("res://scripts/midori_distance_boot.gd")
	while true:
		var pending: Array[String] = producer_check.pending_producers(self)
		var identity := get_node_or_null("Midori2050Identity")
		if identity != null and identity.get("installed") != true: pending.append("Midori2050Identity")
		if pending.is_empty(): break
		if Time.get_ticks_msec() >= deadline:
			creator_error = "Park preparation did not finish: " + ", ".join(pending)
			push_error(creator_error)
			return
		await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Keep original instance identities while editing. The extraction renderer may
	# repartition these later; creator never creates stale copied shadow instances.
	var controller_script: Script = load(get_script().resource_path.get_base_dir().path_join("creator_mode_controller.gd"))
	if controller_script == null:
		creator_error = "Creator tools could not be loaded."
		return
	var controller: Node = controller_script.new()
	controller.name = "CreatorMode"
	add_child(controller)
	controller.initialize(self, get_node("CreatorPlayer"))
	creator_ready = bool(controller.initialized) and creator_error.is_empty()
