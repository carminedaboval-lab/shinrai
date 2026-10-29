extends Button
signal optic_clicked(optic_id: String, target: String)
signal optic_dropped(optic_id: String, target: String, revision: int)
const Catalog = preload("res://scripts/extraction_weapon_catalog.gd")
var optic_id := ""
var target := ""
var revision := 0

func _ready() -> void:
	pressed.connect(func() -> void: optic_clicked.emit(optic_id, target))

func _get_drag_data(_position: Vector2) -> Variant:
	if optic_id.is_empty():
		return null
	var preview := Label.new()
	preview.text = Catalog.OPTICS[optic_id].title
	preview.add_theme_font_size_override("font_size", 22)
	set_drag_preview(preview)
	return {"kind": "weapon_optic", "id": optic_id, "revision": revision}

func _can_drop_data(_position: Vector2, payload: Variant) -> bool:
	return payload is Dictionary and payload.get("kind") == "weapon_optic" and payload.get("revision") == revision and Catalog.OPTICS.has(str(payload.get("id", ""))) and (target == "tray" or Catalog.compatible(target, str(payload.id)))

func _drop_data(_position: Vector2, payload: Variant) -> void:
	if _can_drop_data(_position, payload):
		optic_dropped.emit(str(payload.id), target, int(payload.revision))
