extends SceneTree
## What a look house costs to build, house by house:
##   godot --headless --path . --script res://tests/probe_look_build_time.gd
##
## The world probe reports one number — "the worst frame in the flight cost N ms (building a
## look)" — and that number went from 9-12 ms to a standing 36-38 ms when the nameplate package
## was installed, with the average barely moving (4.3 to 4.6 ms a house). An average that holds
## while the worst case quadruples means something occasional and expensive, and one number
## cannot say which houses it happens on.
##
## So this builds a few hundred of them and reports the spread rather than the mean: median,
## p95, worst, and the slowest few by name. It also splits them by whether the house carries
## signs, because the installed package is the nameplate renderer and a sign is the only thing
## on a house that would go near it — if the slow builds are the sign-bearing ones, that is the
## answer; if they are not, the package is costing something everywhere and the signs are
## innocent. Each house is built twice: the first build of all pays any one-off warm-up, and
## the second pass is the standing cost.
## Prints LOOK_ lines and LOOK_DONE.

const Blockout := preload("res://scripts/map1/map1_blockout.gd")
const HouseKit := preload("res://scripts/interior_kit/house_kit.gd")
const HOW_MANY := 240


func _initialize() -> void:
	_run.call_deferred()


## Build one and give back what it cost in microseconds, as the kit itself measured it.
func _cost(spec: Dictionary) -> int:
	var house: Node3D = HouseKit.build_look(spec)
	var spent := int(house.get_meta("build_usec"))
	house.free()
	return spent


func _spread(name: String, costs: Array) -> void:
	if costs.is_empty():
		print("LOOK_INFO %s: none" % name)
		return
	# Sort a COPY. This used to sort the caller's array where it stood, which left `cold` in
	# rank order for everything that ran afterwards — so the cold-outlier diagnostic below,
	# which reads `cold[ordinal]` against `plans[ordinal]` and `warm[ordinal]`, was pairing a
	# sorted column with two unsorted ones and naming the wrong house. The reading it produced
	# looked entirely plausible. (Found 2026-11-16; the hazard was mine, in this function.)
	var ranked: Array = costs.duplicate()
	ranked.sort()
	var total := 0
	for one: int in ranked: total += one
	print("LOOK_INFO %-22s %4d houses: median %6.2f ms, p95 %6.2f ms, worst %6.2f ms, mean %5.2f ms" % [
		name, ranked.size(), float(ranked[ranked.size() / 2]) / 1000.0,
		float(ranked[mini(int(ranked.size() * 0.95), ranked.size() - 1)]) / 1000.0,
		float(ranked[ranked.size() - 1]) / 1000.0, float(total) / float(ranked.size()) / 1000.0])


func _run() -> void:
	var map: Node3D = Blockout.new()
	map.with_player = false
	root.add_child(map)
	for i: int in 4: await physics_frame
	var world: Node3D = map.world
	var plans: Array[int] = []
	for index: int in world.candidates:
		if plans.size() >= HOW_MANY: break
		if bool(world.site(index).ok): plans.append(index)
	# First pass: this one pays whatever is paid once — a resource load, a shader compile.
	var cold: Array = []
	for index: int in plans: cold.append(_cost(world.site(index).spec))
	# Second pass: the standing cost, which is the one that matters in play.
	var warm: Array = []
	var signed: Array = []
	var plain: Array = []
	var worst: Array = []
	for index: int in plans:
		var spec: Dictionary = world.site(index).spec
		var spent := _cost(spec)
		warm.append(spent)
		var has_signs: bool = not (spec.get("signs", []) as Array).is_empty()
		if has_signs: signed.append(spent)
		else: plain.append(spent)
		worst.append([spent, index, has_signs, (spec.get("blocks", []) as Array).size()])
	# Where in the cold pass the expensive build fell. If the extra cost is paid once for the
	# whole process — a resource load, a shader compile — it lands on the first house and on no
	# other, and the difference between this and the warm pass is that one-off, not a per-house
	# slowdown. Printed because those two readings call for completely different fixes.
	var cold_worst := 0
	var cold_worst_at := -1
	for n: int in cold.size():
		if int(cold[n]) > cold_worst:
			cold_worst = int(cold[n])
			cold_worst_at = n
	print("LOOK_INFO the cold pass's worst build was house %d of %d, at %.2f ms; the first was %.2f ms" % [cold_worst_at + 1, cold.size(), float(cold_worst) / 1000.0, float(cold[0]) / 1000.0])
	_spread("every house, cold", cold)
	_spread("every house, warm", warm)
	_spread("with signs, warm", signed)
	_spread("without signs, warm", plain)
	worst.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	for one: Array in worst.slice(0, 6):
		print("LOOK_SLOW plan %d: %.2f ms, %s, %d blocks" % [int(one[1]), float(one[0]) / 1000.0, "has signs" if bool(one[2]) else "no signs", int(one[3])])
	# Diagnose cold outliers after BOTH measured loops; do not perturb their work.
	var cold_order: Array[int] = []
	for ordinal: int in plans.size(): cold_order.append(ordinal)
	cold_order.sort_custom(func(a: int, b: int) -> bool: return int(cold[a]) > int(cold[b]))
	for ordinal: int in cold_order.slice(0, 6):
		var index: int = plans[ordinal]
		var spec: Dictionary = world.site(index).spec
		var words: Array[String] = []
		for entry: Array in spec.get("signs", []): words.append(str(entry[0]))
		print("LOOK_COLD_SLOW plan %d, ordinal %d: cold %.2f ms, warm %.2f ms, %d blocks, signs %s" % [index, ordinal + 1, float(cold[ordinal]) / 1000.0, float(warm[ordinal]) / 1000.0, (spec.get("blocks", []) as Array).size(), str(words)])
	print("LOOK_DONE %d houses, each built twice" % plans.size())
	quit(0)
