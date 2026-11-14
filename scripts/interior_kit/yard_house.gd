extends RefCounted
## Puts one house into the test yard (scripts/test_yard/yard_world.gd): the first house built
## by the interior kit. The yard only: no other level gets a house from here.
##
## Two floors, 8.4 m by 6.6 m. Downstairs: a hall with the stair, a living room, a small
## front room and a kitchen. Upstairs: a bedroom, a spare room and one LOCKED room, which is
## where the better loot marker is. The big window at the front of the living room reaches
## the floor; the others are waist-high.
##
## It stands on the east side of the yard, front door facing the middle, clear of the scav
## probe's fights (south and centre), the bird sites and the crows' two buildings.

const HouseKit := preload("res://scripts/interior_kit/house_kit.gd")

## The corner of the house's outline, and its turn: the front (the house's own -z) faces west.
const POSITION := Vector3(33.5, 0.0, -5.0)
const TURN := PI * 0.5

## Everything below is in the house's own metres: x along the front, z from front to back.
const SPEC := {
	"id": "YardHouse",
	"size": Vector2(8.4, 6.6),
	"floors": 2,
	"stair": {"x": 3.26, "z": 2.8, "dir": "+z"},
	"partitions": [
		{"id": "west", "floors": [0, 1], "a": Vector2(3.2, 0.15), "b": Vector2(3.2, 6.45)},
		{"id": "east", "floors": [0, 1], "a": Vector2(5.2, 0.15), "b": Vector2(5.2, 6.45)},
		{"id": "cross", "floors": [0, 1], "a": Vector2(5.26, 3.3), "b": Vector2(8.25, 3.3)},
	],
	"doors": [
		{"name": "front", "wall": "front", "floor": 0, "at": 4.2, "swing": -1, "hinge": "high", "front": true},
		{"name": "living", "wall": "west", "floor": 0, "at": 1.65, "swing": 1, "hinge": "low"},
		{"name": "front_room", "wall": "east", "floor": 0, "at": 1.65, "swing": -1, "hinge": "high"},
		{"name": "kitchen", "wall": "east", "floor": 0, "at": 4.65, "swing": -1, "hinge": "high"},
		{"name": "bedroom", "wall": "west", "floor": 1, "at": 1.65, "swing": 1, "hinge": "low"},
		{"name": "spare", "wall": "east", "floor": 1, "at": 1.65, "swing": -1, "hinge": "high"},
		{"name": "locked", "wall": "east", "floor": 1, "at": 4.65, "swing": -1, "hinge": "high", "locked": true},
	],
	"windows": [
		{"name": "front_living", "wall": "front", "floor": 0, "at": 1.7, "width": 1.5, "sill": 0.0, "panes": 2},
		{"name": "west_living", "wall": "left", "floor": 0, "at": 4.1, "width": 1.4, "panes": 2},
		{"name": "back_living", "wall": "back", "floor": 0, "at": 1.6, "width": 1.2},
		{"name": "front_room", "wall": "front", "floor": 0, "at": 6.7, "width": 1.4, "panes": 2},
		{"name": "kitchen", "wall": "right", "floor": 0, "at": 4.8, "width": 1.2},
		{"name": "front_bedroom", "wall": "front", "floor": 1, "at": 1.7, "width": 1.5, "panes": 2},
		{"name": "back_bedroom", "wall": "back", "floor": 1, "at": 1.6, "width": 1.2},
		{"name": "spare", "wall": "front", "floor": 1, "at": 6.7, "width": 1.4, "panes": 2},
		{"name": "locked", "wall": "right", "floor": 1, "at": 4.8, "width": 1.2},
	],
	"steps": [
		{"wall": "front", "at": 4.2, "width": 1.6, "depth": 1.2},
		{"wall": "front", "at": 1.7, "width": 1.5, "depth": 0.5},
	],
	"loot": [
		{"floor": 0, "at": Vector2(1.6, 5.2), "tier": "ordinary"},
		{"floor": 0, "at": Vector2(6.9, 5.2), "tier": "ordinary"},
		{"floor": 1, "at": Vector2(1.6, 4.8), "tier": "ordinary"},
		{"floor": 1, "at": Vector2(6.9, 5.2), "tier": "locked_room"},
	],
}


static func populate(yard: Node3D) -> Node3D:
	var house: Node3D = HouseKit.build(SPEC, yard.get("visuals") != false)
	house.position = POSITION
	house.rotation.y = TURN
	yard.add_child(house)
	return house
