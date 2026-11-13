extends Node
## Stands in for extraction_run.gd in the test yard: the handful of calls the scav crew makes
## on its raid (player, phase, navigation, routes, notices, gunfire), and nothing else.

const YardNavigation := preload("res://scripts/test_yard/yard_navigation.gd")
enum Phase { BOOT, HQ, RAID, PAUSED, RESULT }
const GUNFIRE_RADIUS := 65.0 # same as extraction_run.gd _on_shot

var phase: Phase = Phase.RAID
var player: CharacterBody3D
var park: Node3D
var navigation: RefCounted
var run_time := 0.0
var notice := ""
var notices: Array[Dictionary] = []
var shots := 0


func setup(yard: Node3D, target: CharacterBody3D, half_size: int) -> void:
	park = yard
	player = target
	navigation = YardNavigation.new()
	navigation.build(yard, half_size)
	navigation.exclude(target)


func _physics_process(delta: float) -> void:
	run_time += delta


func insertion_grace() -> bool:
	return false


func announce(text: String, _duration: float = 4.0) -> void:
	notice = text
	notices.append({"time": run_time, "text": text})


func get_path_world(from: Vector3, to: Vector3) -> PackedVector3Array:
	return navigation.path(from, to)


func get_nearest_walkable_world(point: Vector3) -> Vector3:
	return navigation.nearest(point)


func get_search_positions_world(point: Vector3, count: int) -> Array[Vector3]:
	var output: Array[Vector3] = []
	for i: int in range(count):
		var angle := float(i) * TAU / maxi(1, count)
		var goal: Vector3 = navigation.nearest(point + Vector3(cos(angle), 0, sin(angle)) * 5.0)
		if goal.is_finite(): output.append(goal)
	return output


## What extraction_run.gd does when the player fires: tell the crews, then the noise.
func on_shot() -> void:
	shots += 1
	for crew: Node in get_tree().get_nodes_in_group("scav_squad_directors"):
		crew.player_fired()
	for enemy: Node in get_tree().get_nodes_in_group("extraction_hostiles"):
		enemy.hear_noise(player.global_position, GUNFIRE_RADIUS)
