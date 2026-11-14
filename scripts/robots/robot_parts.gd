extends RefCounted
## What a robot is worth fighting for (docs/LOOT_AND_CRAFTING_PLAN.md section 7): the things a
## real machine would have. No armour. This file names the parts, says which robot gives
## which, and keeps what a player has stripped.
##
## None of these is in the game's item list yet. Until they are, what a player has taken is
## kept on the player's body as a meta ("robot_parts": part -> how many), and the access chip
## also sets the meta "has_access_chip". The kit door reads has_chip() the same way it reads
## has_crowbar().

const POWER_CELL := &"power_cell"
const SERVO := &"servo"
const SENSOR := &"sensor"
const ACCESS_CHIP := &"access_chip"
const CARGO := &"cargo"

const NAMES := {
	POWER_CELL: "power cell",
	SERVO: "servo",
	SENSOR: "sensor",
	ACCESS_CHIP: "access chip",
	CARGO: "what it was carrying",
}

## (plan, section 7) What each kind of robot gives when it is stripped, in the order the
## parts come out.
const STATION_ROBOT: Array[StringName] = [POWER_CELL]
const PATROL_ROBOT: Array[StringName] = [POWER_CELL, SERVO, ACCESS_CHIP]
const WORK_ROBOT: Array[StringName] = [CARGO, SERVO, SERVO, ACCESS_CHIP]
const HIDDEN_ROBOT: Array[StringName] = [SENSOR, ACCESS_CHIP]
## (default) The first robot in the test yard gives a power cell, one servo and its chip, so
## the whole loop can be shown with one machine.
const FIRST_ROBOT: Array[StringName] = [POWER_CELL, SERVO, ACCESS_CHIP]

const CARRIED_META := "robot_parts"
const CHIP_META := "has_access_chip"

## ROBOT_SOUND_HOOK: the one place every robot and station sound would start. No sound is
## approved yet, so nothing plays: each request is only counted here. Kinds asked for:
##   &"station_hum"   the station's hum changed level (0 off, 1 steady, 2 raised)
##   &"robot_wake", &"robot_step_out", &"robot_strike", &"robot_down", &"robot_dock",
##   &"robot_strip", &"robot_part_out"
static var sounds_wanted: Dictionary = {}


static func sound(kind: StringName, _at: Vector3, _level: int = 0) -> void:
	sounds_wanted[kind] = int(sounds_wanted.get(kind, 0)) + 1


static func label(part: StringName) -> String:
	return str(NAMES.get(part, str(part)))


## Hands one part to `actor`.
static func give(actor: Node, part: StringName) -> void:
	if not is_instance_valid(actor): return
	var carried: Dictionary = actor.get_meta(CARRIED_META, {})
	carried[part] = int(carried.get(part, 0)) + 1
	actor.set_meta(CARRIED_META, carried)
	if part == ACCESS_CHIP: actor.set_meta(CHIP_META, true)


## What `actor` has stripped so far: part -> how many.
static func carried(actor: Node) -> Dictionary:
	if not is_instance_valid(actor): return {}
	return actor.get_meta(CARRIED_META, {})


static func carried_text(actor: Node) -> String:
	var parts: Array[String] = []
	var have := carried(actor)
	for part: StringName in have: parts.append("%d %s" % [int(have[part]), label(part)])
	return ", ".join(parts) if not parts.is_empty() else "nothing"


## True when `actor` carries an access chip: the item in the raid's bag once it exists, or
## the stand-in flag has_access_chip on the body (a property or a meta). The chip is good for
## the rest of that raid: whatever ends a raid clears the flag with clear().
static func has_chip(actor: Node) -> bool:
	if not is_instance_valid(actor): return false
	if actor.get(CHIP_META) == true or bool(actor.get_meta(CHIP_META, false)): return true
	if not actor.is_inside_tree(): return false
	var raid := actor.get_tree().get_first_node_in_group("shinrai_survival_run")
	if raid == null: return false
	var bag: Variant = raid.get("bag")
	if not bag is Array: return false
	for item: Variant in bag:
		if item is Dictionary and str(item.get("id", "")) == str(ACCESS_CHIP): return true
	return false


## The end of a raid: the chip stops working and the stripped parts are handed on.
static func clear(actor: Node) -> void:
	if not is_instance_valid(actor): return
	if actor.has_meta(CARRIED_META): actor.remove_meta(CARRIED_META)
	if actor.has_meta(CHIP_META): actor.remove_meta(CHIP_META)
