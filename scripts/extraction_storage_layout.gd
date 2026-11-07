extends RefCounted

const Clothing = preload("./extraction_clothing.gd")
const POSITION := "storage_cell"

# These dimensions describe loose cargo. Worn equipment and the weapon in hand
# are displayed by the equipment UI. Dimensions are in inventory cells.
const FOOTPRINTS := {
	"cell": Vector2i(1, 2),
	"bolt_cutters": Vector2i(1, 3),
	"hammer": Vector2i(1, 2),
	"wrench": Vector2i(1, 2),
	"splint": Vector2i(1, 2),
	"bottled_water_closed": Vector2i(1, 2),
	"bottled_water_open": Vector2i(1, 2),
	"sports_bottle_closed": Vector2i(1, 2),
	"sports_bottle_open": Vector2i(1, 2),
	"akane_magazine": Vector2i.ONE,
	"basic_shirt": Vector2i(1, 2),
	"work_jacket": Vector2i(1, 2),
	"basic_trousers": Vector2i(1, 2),
	"cargo_trousers": Vector2i(1, 2),
	"security_armour_t2": Vector2i(2, 2),
	"patrol_armour_t3": Vector2i(2, 2),
	"backpack_regular": Vector2i(1, 2),
	"backpack_mountain": Vector2i(2, 2),
}

static func footprint(item: Dictionary) -> Vector2i:
	var id := str(item.get("id", ""))
	if FOOTPRINTS.has(id):
		return FOOTPRINTS[id]
	if id.ends_with("_magazine"):
		return Vector2i(1, 2)
	return Vector2i.ONE

static func _container(id: String, item: Dictionary, kind: String, cells: int, columns: int) -> Dictionary:
	return {"id": id, "item_id": str(item.id), "title": str(item.title),
		"kind": kind, "cells": cells, "cols": columns, "rows": ceili(float(cells) / columns)}

static func _worn_pack_index(state: Dictionary, bag: Array) -> int:
	var uid := str(state.get("equipped_uid", ""))
	if uid.is_empty():
		return -1
	for index in bag.size():
		var item: Dictionary = bag[index]
		if str(item.get("pack_uid", "")) == uid and str(item.get("id", "")).begins_with("backpack_"):
			return index
	return -1

static func _containers(state: Dictionary, bag: Array, total_cells: int, worn_index: int) -> Array:
	var result := []
	var outfit := Clothing.normalize(state.get("clothing", {}))
	var pocket_cells := 0
	for slot: String in ["top", "legs", "pouch"]:
		var item := Clothing.spec(outfit[slot])
		var cells := int(item.get("pockets", 0))
		if cells == 0:
			continue
		pocket_cells += cells
		match slot:
			"top":
				result.append(_container(slot, item, "pockets", cells, cells))
			"legs":
				result.append(_container(slot, item, "channels", cells, ceili(cells / 2.0)))
			"pouch":
				result.append(_container(slot, item, "grid", cells, 1))
	var pack_cells := total_cells - pocket_cells
	if worn_index >= 0 and pack_cells > 0:
		var pack: Dictionary = bag[worn_index]
		var columns := mini(4, ceili(pack_cells / 2.0))
		result.append(_container("pack:" + str(pack.pack_uid), pack, "grid", pack_cells, columns))
	return result

# Build is also used by hypothetical pickups and swaps. Only commit() writes
# the result back to the physical items after the caller accepts a transaction.
static func build(state: Dictionary, bag: Array, total_cells: int) -> Dictionary:
	var worn_index := _worn_pack_index(state, bag)
	var layout := {"containers": _containers(state, bag, total_cells, worn_index),
		"placements": [], "sizes": [], "overflow": [], "worn_index": worn_index}
	for item: Dictionary in bag:
		layout.sizes.append(footprint(item))
		layout.placements.append({})
	var pending: Array[int] = []
	for index in bag.size():
		if index == worn_index:
			continue
		var stored: Variant = bag[index].get(POSITION)
		if stored is Dictionary:
			var x := _coordinate(stored.get("x"))
			var y := _coordinate(stored.get("y"))
			var id := str(stored.get("container", ""))
			var shape := shape_at(layout, index, id, x, y, stored.get("rotated") == true)
			if shape != Vector2i.ZERO:
				layout.placements[index] = _placement(id, x, y, shape)
				continue
		pending.append(index)
	# Reserve the few spaces that take bulky items before packing loose singles.
	pending.sort_custom(func(a: int, b: int) -> bool:
		var area_a: int = layout.sizes[a].x * layout.sizes[a].y
		var area_b: int = layout.sizes[b].x * layout.sizes[b].y
		return a < b if area_a == area_b else area_a > area_b)
	for index in pending:
		var placed := _first_fit(layout, index)
		layout.placements[index] = placed
		if placed.is_empty():
			layout.overflow.append(index)
	return layout

# JSON-decoded coordinates may be whole-valued floats. Invalid input is
# repacked just like an older item that predates saved placements.
static func _coordinate(value: Variant) -> int:
	if value is int or value is float:
		if is_finite(float(value)) and value >= 0 and value <= 1024 and floorf(float(value)) == value:
			return int(value)
	return -1

static func _placement(id: String, x: int, y: int, shape: Vector2i) -> Dictionary:
	return {"container": id, "x": x, "y": y, "w": shape.x, "h": shape.y}

static func _fits_at(layout: Dictionary, index: int, box: Dictionary, x: int, y: int, shape: Vector2i) -> bool:
	if x < 0 or y < 0 or x > int(box.cols) - shape.x or y > int(box.rows) - shape.y:
		return false
	if (y + shape.y - 1) * int(box.cols) + x + shape.x > int(box.cells):
		return false
	if box.kind == "pockets" and shape != Vector2i.ONE:
		return false
	if box.kind == "channels" and shape.x != 1:
		return false
	var target := Rect2i(Vector2i(x, y), shape)
	for other in layout.placements.size():
		var placed: Dictionary = layout.placements[other]
		if other == index or placed.get("container", "") != box.id:
			continue
		if target.intersects(Rect2i(placed.x, placed.y, placed.w, placed.h)):
			return false
	return true

static func _fitting_shape(layout: Dictionary, index: int, box: Dictionary, x: int, y: int, preferred: Vector2i) -> Vector2i:
	if _fits_at(layout, index, box, x, y, preferred):
		return preferred
	var turned := Vector2i(preferred.y, preferred.x)
	if turned != preferred and _fits_at(layout, index, box, x, y, turned):
		return turned
	return Vector2i.ZERO

static func _first_fit(layout: Dictionary, index: int) -> Dictionary:
	for box: Dictionary in layout.containers:
		for x in int(box.cols):
			for y in int(box.rows):
				var shape := _fitting_shape(layout, index, box, x, y, layout.sizes[index])
				if shape != Vector2i.ZERO:
					return _placement(box.id, x, y, shape)
	return {}

static func shape_at(layout: Dictionary, index: int, id: String, x: int, y: int, prefer_turned: bool = false) -> Vector2i:
	if index < 0 or index >= layout.placements.size() or index == int(layout.worn_index):
		return Vector2i.ZERO
	var preferred: Vector2i = layout.sizes[index]
	var current: Dictionary = layout.placements[index]
	if not current.is_empty():
		preferred = Vector2i(current.w, current.h)
	elif prefer_turned:
		preferred = Vector2i(preferred.y, preferred.x)
	for box: Dictionary in layout.containers:
		if box.id == id:
			return _fitting_shape(layout, index, box, x, y, preferred)
	return Vector2i.ZERO

static func can_move(layout: Dictionary, index: int, id: String, x: int, y: int) -> bool:
	return shape_at(layout, index, id, x, y) != Vector2i.ZERO

static func commit(bag: Array, layout: Dictionary) -> void:
	for index in bag.size():
		var placed: Dictionary = layout.placements[index]
		if placed.is_empty():
			bag[index].erase(POSITION)
		else:
			var saved := {"container": placed.container, "x": placed.x, "y": placed.y}
			if placed.w != layout.sizes[index].x:
				saved["rotated"] = true
			bag[index][POSITION] = saved

static func move(bag: Array, layout: Dictionary, index: int, id: String, x: int, y: int) -> bool:
	if bag.size() != layout.placements.size():
		return false
	var shape := shape_at(layout, index, id, x, y)
	if shape == Vector2i.ZERO:
		return false
	layout.placements[index] = _placement(id, x, y, shape)
	layout.overflow.erase(index)
	commit(bag, layout)
	return true
