extends Node3D
## One house built by the interior kit (scripts/interior_kit/house_kit.gd).
##
## It holds the doors and windows by name, and does the one thing that needs a tick: it
## watches bodies that are close to the house and tells the windows when one of them moves,
## so a window can tell that a body went through it (scripts/interior_kit/window.gd).
## Bodies watched: every player (group "shinrai_input_players") and anything given to
## track(). With nobody near, a tick is one distance check per body.

## Bodies further than this from the house's outline are not watched.
const NEAR_MARGIN := 2.0
## A body that moved further than this in one tick was placed there, not moved: no window
## counts it as a passage.
const MAX_STEP := 0.75

var spec: Dictionary = {}
var doors: Dictionary = {}
var windows: Dictionary = {}
## Height of each floor above the house's origin (the ground), lowest first.
var floor_heights: Array[float] = []
## The measured stair, as scripts/interior_kit/stair.gd returns it.
var stair: Dictionary = {}
## The roof as built: {form, ridge ("x" or "z"), rise, eave}.
var roof: Dictionary = {}
var bounds := AABB()
## What the house cost to build: nodes, collision shapes, meshes, triangles, microseconds.
var stats: Dictionary = {}

var _tracked: Array[Node3D] = []
var _last: Dictionary = {}


func track(body: Node3D) -> void:
	if body != null and not _tracked.has(body): _tracked.append(body)


func untrack(body: Node3D) -> void:
	_tracked.erase(body)
	if body != null: _last.erase(body.get_instance_id())


func door(label: String) -> Node3D:
	return doors.get(label)


func window(label: String) -> Node3D:
	return windows.get(label)


func _physics_process(_delta: float) -> void:
	var near := bounds.grow(NEAR_MARGIN)
	for index: int in range(_tracked.size() - 1, -1, -1):
		if is_instance_valid(_tracked[index]): _watch(_tracked[index], near)
		else: _tracked.remove_at(index)
	for body: Node in get_tree().get_nodes_in_group("shinrai_input_players"):
		if body is Node3D and not _tracked.has(body): _watch(body as Node3D, near)


func _watch(body: Node3D, near: AABB) -> void:
	if not is_instance_valid(body) or not body.is_inside_tree(): return
	var id := body.get_instance_id()
	var now := body.global_position
	if not near.has_point(to_local(now)):
		_last.erase(id)
		return
	if _last.has(id):
		var before: Vector3 = _last[id]
		if before != now and before.distance_to(now) <= MAX_STEP:
			for label: String in windows: windows[label].body_moved(body, before, now)
	_last[id] = now
