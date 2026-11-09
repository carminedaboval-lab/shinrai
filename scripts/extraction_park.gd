extends "res://scripts/midori_park_size_blockout.gd"

const RaidScript = preload("res://scripts/extraction_run.gd")
@export var profile_path := "user://shinrai_extraction_v1.json"

func _ready() -> void:
	DisplayServer.window_set_title("SHINRAI — Park Extraction")
	start_at_night = false
	await super._ready()
	# Keep the original review scene intact; hide only its diagnostic overlay.
	for child: Node in get_children():
		if child is CanvasLayer:
			child.hide()
	var raid := RaidScript.new()
	raid.name = "ExtractionRun"
	add_child(raid)

func _spawn_scale_review_player() -> void:
	var player := PlayerScript.new()
	player.name = "ParkScaleReviewPlayer"
	player.extraction_mode = true
	player.position = Vector3(0, 0.2, 160)
	add_child(player)

func _unhandled_input(event: InputEvent) -> void:
	# Time of day is selected before insertion, not changed during a raid.
	if event is InputEventKey and event.physical_keycode == KEY_F7:
		# Not while a warm-up renders the current variant (its restore would undo it).
		var raid := get_node_or_null("ExtractionRun")
		if raid != null and raid.has_method("view_settings_locked") and bool(raid.call("view_settings_locked")): return
		super._unhandled_input(event)
