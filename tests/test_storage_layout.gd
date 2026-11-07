extends SceneTree

const Packs = preload("res://scripts/extraction_backpack_state.gd")
const Storage = preload("res://scripts/extraction_storage_layout.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_test_pocket_boundaries()
	_test_backpack_placement()
	_test_older_cargo()
	for failure in failures:
		push_error(failure)
	print("STORAGE_LAYOUT_TEST: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _test_pocket_boundaries() -> void:
	var state := Packs.new_state("pockets")
	var bag := [{"id": "bandage"}, {"id": "bandage"}]
	Packs.settle(state, bag, 0)
	for index in bag.size():
		var layout := Packs.layout(state, bag, 0)
		_check(Storage.move(bag, layout, index, "legs", index, 0), "could not select trouser pocket")
	var magazine := {"id": "kite_magazine", "magazine_uid": "mag-a", "rounds": 11}
	var candidate := bag.duplicate(true)
	candidate.append(magazine)
	var before := candidate.duplicate(true)
	_check(not Packs.fits(state, candidate, 0), "magazine bridged two separate half-empty pockets")
	_check(candidate == before, "pickup preview changed the candidate records")
	_check(Storage.move(bag, Packs.layout(state, bag, 0), 0, "top", 0, 0), "could not empty a trouser pocket")
	bag.append(magazine)
	_check(Packs.fits(state, bag, 0), "magazine did not fit a free two-cell pocket")
	Packs.settle(state, bag, 0)
	bag.reverse()
	var restored := Packs.layout(state, bag, 0)
	_check(restored.placements[0] == {"container":"legs","x":0,"y":0,"w":1,"h":2}, "sorting displaced magazine")
	_check(restored.placements[1].x == 1 and restored.placements[1].container == "legs",
		"sorting swapped the positions of identical bandages")

func _test_backpack_placement() -> void:
	var state := Packs.new_state("backpack")
	Packs.roll_spawns(state, 0.0, true, true)
	var bag := [{"id": "kite_magazine", "magazine_uid": "mag-b", "rounds": 9}]
	_check(Packs.pickup(state, bag, Packs.REGULAR, 0, true), "could not equip a field backpack")
	var grid := "pack:" + str(state.equipped_uid)
	var layout := Packs.layout(state, bag, 0)
	_check(not Storage.can_move(layout, layout.worn_index, grid, 0, 0), "worn pack fits inside itself")
	_check(Storage.move(bag, layout, 0, grid, 0, 1), "magazine did not turn to fit bottom row")
	var decoded: Array = JSON.parse_string(JSON.stringify(bag))
	var restored := Packs.layout(state, decoded, 0)
	_check(restored.placements[0] == {"container":grid,"x":0,"y":1,"w":2,"h":1},
		"orientation or physical position lost on JSON round trip")
	_check(decoded[0].rounds == 9 and decoded[0].magazine_uid == "mag-b", "moving changed the magazine state")
	var vest := {"id":"security_armour_t2"}
	bag.append(vest)
	_check(not Packs.fits(state, bag, 0), "vest overlaps a placed magazine")
	_check(Storage.move(bag, Packs.layout(state, bag, 0), 0, "legs", 0, 0), "could not free the backpack")
	_check(Packs.fits(state, bag, 0), "four-cell vest did not fit the empty field pack")
	Packs.settle(state, bag, 0)
	var before := bag.duplicate(true)
	_check(not Packs.discard(state, bag, layout.worn_index, 0), "discarded a pack with no space for its contents")
	_check(bag == before and str(state.equipped_uid) != "", "rejected pack discard changed cargo")

func _test_older_cargo() -> void:
	var state := Packs.new_state("legacy")
	var bag := [{"id":"security_armour_t2"}, {"id":"patrol_armour_t3"}, {"id":"bandage"}]
	Packs.settle(state, bag, 0)
	_check(bag.size() == 3 and Packs.layout(state, bag, 0).overflow.size() == 2,
		"oversized items from an older field kit were lost")
	_check(Packs.discard(state, bag, 0, 0), "could not discard from an overfull legacy kit")
	_check(Packs.layout(state, bag, 0).overflow.size() == 1, "first discard did not preserve remaining overflow")
	_check(Packs.discard(state, bag, 0, 0), "could not finish resolving overflow")
	_check(bag.size() == 1 and bag[0].id == "bandage" and Packs.fits(state, bag, 0),
		"resolving overflow changed the retained item")
