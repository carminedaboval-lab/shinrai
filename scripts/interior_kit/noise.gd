extends RefCounted
## Noises that are NOT gunfire: breaking glass, a door being forced.
##
## Gunfire has its own path (the raid calls player_fired() on the scav crews and on_gunfire()
## on the "gunfire_listeners" group). This is the small, separate one: anything in the group
## "noise_listeners" gets on_noise(point, radius) and decides for itself whether it is close
## enough to care. The birds listen to it (scripts/wildlife/bird_manager.gd).
##
## Scav crews are never told "a shot was fired" from here, so they do not stop and go on
## guard. A scav inside the radius does hear it as an ordinary noise and walks over to look
## (the same hear_noise() the raid uses for other sounds). Set SCAVS_INVESTIGATE to false to
## make scavs deaf to it.

const LISTENER_GROUP := "noise_listeners"
## (default) A scav that is inside the noise radius goes to look at where it came from.
const SCAVS_INVESTIGATE := true

## How many times each sound has been asked for. No sound is approved yet, so nothing plays.
static var sounds_wanted: Dictionary = {}


## A noise at `point` that carries `radius` metres. `kind` names the sound it would make.
static func emit(from: Node, point: Vector3, radius: float, kind: StringName) -> void:
	sound(kind, point)
	if radius <= 0.0 or not is_instance_valid(from) or not from.is_inside_tree(): return
	var tree := from.get_tree()
	tree.call_group(LISTENER_GROUP, "on_noise", point, radius)
	if not SCAVS_INVESTIGATE: return
	for enemy: Node in tree.get_nodes_in_group("extraction_hostiles"):
		if enemy.has_method("hear_noise"): enemy.hear_noise(point, radius)


## HOUSE_SOUND_HOOK: the one place the glass, crowbar and lock sounds would start.
## `kind` is one of: &"glass_break", &"glass_knock_out", &"crowbar_pry", &"door_forced",
## &"lock_shot", &"lock_shot_open". No sound is approved yet, so nothing plays; put the
## player here.
static func sound(kind: StringName, _at: Vector3) -> void:
	sounds_wanted[kind] = int(sounds_wanted.get(kind, 0)) + 1


static func sounds_total() -> int:
	var total := 0
	for kind: StringName in sounds_wanted: total += int(sounds_wanted[kind])
	return total
