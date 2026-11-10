@tool
extends Node3D

@export var wear_t_shirt: bool = true:
	set(value):
		wear_t_shirt = value
		if is_node_ready():
			_update_wardrobe()

@export var wear_field_trousers: bool = true:
	set(value):
		wear_field_trousers = value
		if is_node_ready():
			_update_wardrobe()

func _ready() -> void:
	_update_wardrobe()

func _update_wardrobe() -> void:
	for child in find_children("*", "MeshInstance3D", true, false):
		var part := child as MeshInstance3D
		match String(part.name):
			"Wear_TShirt", "Body_TorsoUpper_Shirt", "Body_Arms_ShirtSleeves":
				part.visible = wear_t_shirt
			"Wear_FieldTrousers":
				part.visible = wear_field_trousers
			"Body_Arms_UnderSleeves", "Body_TorsoUpper_Chest", "Skin_Abdomen":
				part.visible = not wear_t_shirt
			"Skin_Legs", "Under_Hem", "Under_Briefs", "Under_Waistband":
				part.visible = not wear_field_trousers

