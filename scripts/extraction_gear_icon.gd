extends Control
## Inventory cutouts, with shared equipment artwork for items outside the loot catalogue.
const Art = preload("./extraction_item_art.gd")
const Clothing = preload("./extraction_clothing.gd")
const Supplies = preload("./extraction_weapon_supplies.gd")
const Catalog = preload("./extraction_weapon_catalog.gd")
const GEAR_ATLAS = preload("res://assets/ui/inventory/inventory_gear.png")
# Art-directed crops keep long tools and magazines legible in their actual cells.
const GEAR_CROPS := {
	"basic_shirt": Rect2(33, 27, 258, 268),
	"basic_trousers": Rect2(400, 9, 141, 298),
	"work_jacket": Rect2(642, 9, 284, 288),
	"cargo_trousers": Rect2(1021, 9, 153, 296),
	"security_armour_t2": Rect2(42, 333, 234, 277),
	"patrol_armour_t3": Rect2(344, 327, 252, 278),
	"utility_pouch": Rect2(643, 391, 282, 172),
	"backpack_regular": Rect2(989, 326, 215, 287),
	"backpack_mountain": Rect2(45, 633, 235, 303),
	"wrench": Rect2(423, 634, 91, 296),
	"bolt_cutters": Rect2(724, 634, 116, 297),
	"hammer": Rect2(1020, 643, 154, 289),
	"akane_magazine": Rect2(107, 986, 109, 246),
	"rifle_magazine": Rect2(406, 957, 135, 286),
	"smg_magazine": Rect2(748, 956, 73, 287),
	"ammo": Rect2(944, 997, 302, 210),
}
const EMPTY_GEAR := {"armour": "security_armour_t2", "pouch": "utility_pouch", "backpack": "backpack_regular"}
var item_id := ""
var vacant := false
var photo: Texture2D
var crop := Rect2()
# Tight alpha bounds in the shipped 256- and 512-pixel item photographs.
const PHOTO_CROPS := {
	"bottled_water_closed":Rect2(91,31,75,199),"bottled_water_open":Rect2(91,27,75,207),
	"sports_bottle_closed":Rect2(91,31,75,203),"sports_bottle_open":Rect2(91,31,75,203),
	"pliers":Rect2(43,83,187,99),"scissors":Rect2(35,91,191,91),"utility_knife":Rect2(43,91,171,87),
	"bandage":Rect2(46,114,425,281),"splint":Rect2(30,114,453,285),"tourniquet":Rect2(58,158,393,217),
}

func setup(id: String, empty_slot: bool = false) -> void:
	item_id = id
	vacant = empty_slot
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo = Art.loot_texture(id)
	var artwork := str(EMPTY_GEAR.get(id, id)) if vacant else id
	if id in ["uzi_magazine", "shigure_magazine"]:
		artwork = "smg_magazine"
	elif Supplies.MAGAZINES.has(id) and id != "akane_magazine":
		artwork = "rifle_magazine"
	elif Supplies.AMMUNITION.has(id):
		artwork = "ammo"
	if photo != null:
		crop = PHOTO_CROPS.get(id,Rect2(Vector2.ZERO,photo.get_size()))
	elif GEAR_CROPS.has(artwork):
		photo = GEAR_ATLAS
		crop = GEAR_CROPS[artwork]
	elif id in ["park_map","coffee_cup","screwdriver","canned_mackerel","canned_mackerel_open","canned_peaches","canned_peaches_open","can_opener"]:
		var art := Art.new()
		art.item_id = id
		add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func _draw() -> void:
	if get_child_count() > 0: return
	var area := size - Vector2(6,5)
	if area.x <= 0 or area.y <= 0: return
	if photo != null:
		var wearable := not Clothing.spec(item_id).is_empty() or item_id.begins_with("backpack_") or vacant
		var sideways := not wearable and ((area.y > area.x * 1.55 and crop.size.x > crop.size.y * 1.3) or (area.x > area.y * 1.55 and crop.size.y > crop.size.x * 1.3))
		var axes := Vector2(area.y,area.x) if sideways else area
		var extent := crop.size * minf(axes.x / crop.size.x,axes.y / crop.size.y)
		draw_set_transform(size * 0.5,PI * 0.5 if sideways else 0.0,Vector2.ONE)
		var tint := Color(0.68, 0.76, 0.76, 0.34) if vacant else Color.WHITE
		draw_texture_rect_region(photo,Rect2(-extent*0.5,extent),crop,tint)
		return
	var bounds := Rect2(0, 0, 68, 46)
	var scale_factor := minf(area.x / bounds.size.x, area.y / bounds.size.y)
	draw_set_transform(size * 0.5 - bounds.get_center() * scale_factor, 0.0, Vector2.ONE * scale_factor)
	var lit := Color("bdcac4") if not vacant else Color("506460")
	var shade := Color("536c68") if not vacant else Color("354844")
	if item_id.begins_with("weapon_") or Catalog.WEAPONS.has(item_id):
		var weapon := item_id.trim_prefix("weapon_")
		if str(Catalog.WEAPONS.get(weapon,{}).get("category","")) == "pistol":
			_shape([14,13,53,13,53,20,33,21,27,38,17,37,21,22,14,21],shade,lit)
		else:
			_shape([3,16,21,19,24,14,46,14,48,17,65,17,65,20,48,21,44,24,37,24,35,33,28,32,30,24,25,24,22,32,17,30,19,23,4,28],shade,lit)
	elif item_id in ["garden_mikan","garden_persimmon"]:
		draw_circle(Vector2(34,24),13,Color("c49061"))
		draw_line(Vector2(34,12),Vector2(39,7),lit,2,true)
	elif item_id == "optics" or item_id.begins_with("optic_"):
		draw_rect(Rect2(15,16,29,15),shade)
		draw_circle(Vector2(44,23),11,lit)
		draw_circle(Vector2(45,23),8,shade)
	elif item_id == "medkit":
		draw_rect(Rect2(16,11,35,27),shade)
		draw_rect(Rect2(16,11,35,27),lit,false,1.5)
		draw_line(Vector2(34,15),Vector2(34,33),lit,4)
		draw_line(Vector2(25,24),Vector2(43,24),lit,4)
	else:
		_shape([12,14,29,7,54,15,54,33,38,40,12,32],shade,lit)
		draw_polyline(PackedVector2Array([Vector2(12,14),Vector2(38,22),Vector2(54,15)]),lit,1.5,true)
		draw_line(Vector2(38,22),Vector2(38,39),lit,1)

func _shape(coords: Array, fill: Color, outline: Color) -> void:
	var path := PackedVector2Array()
	for i: int in range(0,coords.size(),2): path.append(Vector2(coords[i],coords[i+1]))
	draw_colored_polygon(path,fill)
	path.append(path[0])
	draw_polyline(path,outline,1.4,true)
