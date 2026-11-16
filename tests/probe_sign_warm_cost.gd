extends SceneTree
## What it would cost to cut every sign in Map 1 up front:
##   godot --headless --path . --script res://tests/probe_sign_warm_cost.gd
##
## A sign's glyph outlines are cut the first time anything asks for that exact text and kept
## after. The bill therefore lands on whichever frame first builds a house carrying new text,
## and for the upstairs café — six signs at once — that is 26.72 ms on the frame a player first
## comes within sight of it. Nobody should pay that while walking.
##
## The obvious fix is to cut them during the load, where seconds are already being spent and
## nobody is looking. Before proposing it, this prices it: how many distinct strings the whole
## map carries, what they cost to cut in one go, and therefore whether the fix is free in
## practice or just moves a cost somewhere else that matters.
## Prints WARM_ lines and WARM_DONE.

const Blockout := preload("res://scripts/map1/map1_blockout.gd")
const HouseKit := preload("res://scripts/interior_kit/house_kit.gd")
const Dress := preload("res://scripts/map1/map1_house_dress.gd")


var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


## Every failed assertion must reach the exit code. A printed WARM_FAIL that leaves the process
## exiting 0 is worse than no check at all: the runner reports success and nobody reads the line.
## (Codex, 2026-11-16.)
func _check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("WARM_%s %s" % ["PASS" if ok else "FAIL", text])


func _run() -> void:
	# Time the cut FIRST, before anything builds a house. Once the map is dressed the dressing's
	# own warm pass has already filled the cache, so timing it afterwards measures nothing — it
	# read 0.1 ms and looked like a triumph. This is the real cold cost of the whole map's signs.
	# Nothing is cut here. The dressing's own warm pass does it, from World's setup,
	# and it records what that cost — so the number reported is the real one, measured where it
	# actually happens, rather than a second pass this probe makes for itself. Timing my own
	# copy of the work is how I got 28.7 ms and then 0.1 ms for the same thing earlier today.
	var keys: Dictionary = Dress.sign_keys()
	var map: Node3D = Blockout.new()
	map.with_player = false
	root.add_child(map)
	for i: int in 4: await physics_frame
	var world: Node3D = map.world
	# Every distinct sign text the map's houses carry, and which house carries the most.
	var texts := {}
	var houses := 0
	var signed := 0
	var most := 0
	var most_at := -1
	var began := Time.get_ticks_usec()
	for index: int in world.candidates:
		var plan: Dictionary = world.site(index)
		if not bool(plan.ok): continue
		houses += 1
		var mine: Array = plan.spec.get("signs", [])
		if not mine.is_empty(): signed += 1
		if mine.size() > most:
			most = mine.size()
			most_at = index
		# Keyed by text AND coarseness, as the cache is: a sign cut at 16 degrees is a different
		# shape from the same words at 2.5 and warming one does nothing for the other.
		for entry: Array in mine: texts[Dress.sign_key(str(entry[0]), float(entry[6]) if entry.size() > 6 else 2.5)] = true
	var dressing := Time.get_ticks_usec() - began
	var again := Time.get_ticks_usec()
	for key: String in keys:
		var split := key.rsplit("|", true, 1)
		HouseKit.sign_shape(split[0], float(split[1]))
	var second := Time.get_ticks_usec() - again
	# Whether the pass really was the first thing to cut letters is read from the kit's own
	# cache, key by key, as the pass runs — not inferred from how long it took. Elapsed time
	# cannot tell 27 cuts from 20 cuts and 7 hits, and a fast machine would have read as a
	# failure. (Codex, 2026-11-16: "elapsed time cannot prove all 27 cache misses or detect
	# partial warming".)
	_check(Dress.warmed_misses == Dress.warmed_keys and Dress.warmed_hits == 0,
		"the warm pass found an empty cache and cut every key itself: %d of %d were misses, %d were already there" % [
			Dress.warmed_misses, Dress.warmed_keys, Dress.warmed_hits])
	_check(Dress.warmed_usec > 0, "it ran from World's setup, before any house is dressed: %d keys in %.1f ms, worst single key %.1f ms; asking for all of them again afterwards costs %.3f ms" % [
		Dress.warmed_keys, float(Dress.warmed_usec) / 1000.0,
		float(Dress.warmed_slowest_usec) / 1000.0, float(second) / 1000.0])
	print("WARM_INFO %d houses dressed in %.0f ms; %d of them carry signs, %d distinct texts in all; the most on one house is %d (plan %d)" % [
		houses, float(dressing) / 1000.0, signed, texts.size(), most, most_at])
	# The warm pass reads its keys from the trade table and the café rather than from dressed
	# houses, which is the only way to do it in reasonable time — so what must be checked is
	# that nothing the map actually draws is left out of them. See the rule below for why a key
	# warmed and never drawn is reported rather than failed on.
	var warmed: Dictionary = keys
	var missed: Array[String] = []
	var spare: Array[String] = []
	for text: String in texts:
		if not warmed.has(text): missed.append(text)
	for text: String in warmed:
		if not texts.has(text): spare.append(text)
	# Only a MISS fails. A text the map draws and the warm pass does not cut is a hitch waiting
	# to happen, and that is what this exists to prevent. A text warmed but never drawn is a
	# trade that sits in the table without a plot in this map using it — about a millisecond of
	# load, and a perfectly ordinary state of affairs rather than a defect. It is reported, not
	# failed on. (Test rule set 2026-11-16: strict set equality would have cried wolf every time
	# a trade went unplaced.)
	_check(missed.is_empty(), "nothing the map draws goes uncut: %d drawn, %d warmed, %d drawn but never warmed %s" % [
		texts.size(), warmed.size(), missed.size(), str(missed)])
	if not spare.is_empty():
		print("WARM_INFO %d warmed but never drawn in this map (a trade in the table with no plot using it): %s" % [spare.size(), str(spare)])
	print("WARM_DONE passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)
