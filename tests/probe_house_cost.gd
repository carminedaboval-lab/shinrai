extends SceneTree
## Where an outside-only house's triangles actually go:
##   godot --headless --path . --script res://tests/probe_house_cost.gd
##
## The 520-house projection is over the ring's tested budget, and the argument about what to cut
## was being had on guesses about which items are expensive. This measures it: each house is
## built whole, then built again with one part of its spec left out, and the difference is what
## that part costs. The parts are the dressing arrays — the plain boxes on the plot and indoors,
## the lettering on signs, the upright prisms, the bicycle wheels — and what is left when all of
## them are gone is the house itself: walls, roof, openings, stair.
## Prints COST lines and COST_DONE.

const Blockout := preload("res://scripts/map1/map1_blockout.gd")
const HouseKit := preload("res://scripts/interior_kit/house_kit.gd")
const PARTS: Array[String] = ["blocks", "signs", "drums", "wheels"]


func _initialize() -> void:
	_run.call_deferred()


func _triangles(spec: Dictionary) -> int:
	var house: Node3D = HouseKit.build_look(spec)
	var count := int(house.get_meta("triangles"))
	house.free()
	return count


## What the lettering on this house's signs costs.
func full_signs(spec: Dictionary) -> int:
	return _triangles(spec) - _triangles(_without(spec, "signs"))


## The same spec with one of its arrays emptied. A shallow copy is enough: only the one key is
## replaced, and nothing below it is touched.
func _without(spec: Dictionary, part: String) -> Dictionary:
	var cut := spec.duplicate()
	cut[part] = []
	return cut


func _run() -> void:
	var map: Node3D = Blockout.new()
	map.with_player = false
	root.add_child(map)
	for i: int in 4: await physics_frame
	var world: Node3D = map.world
	var whole := 0
	var houses := 0
	var inside_cost := 0
	var outside_cost := 0
	var cost := {}
	var most := {}
	for part: String in PARTS:
		cost[part] = 0
		most[part] = 0
	# The same window the world probe reports its budget from: the houses nearest the spot it
	# stands its player on, 40 of them. (Its own `_makeable_near` is the world probe's; this
	# sorts the candidates by distance to the same point, which picks the same neighbourhood.)
	# Sorted on the map's own box positions, not on `world.site()`: asking for a site dresses the
	# whole house, and a comparison function that does that would build every house in the map
	# a hundred times over.
	var here := Vector2(119.0, 447.0)
	var near: Array[int] = []
	for index: int in world.candidates: near.append(index)
	var boxes: Array = map.data.boxes
	near.sort_custom(func(a: int, b: int) -> bool:
		return here.distance_squared_to(Vector2(float(boxes[a][0]), float(boxes[a][2]))) < here.distance_squared_to(Vector2(float(boxes[b][0]), float(boxes[b][2]))))
	var leaves := 0
	var plates := 0
	var plate_glyphs := 0
	var counted: Array[int] = []
	for index: int in near:
		if houses >= 40: break
		var plan: Dictionary = world.site(index)
		if not bool(plan.ok): continue
		houses += 1
		counted.append(index)
		# What the gate work costs in this window, exactly: a leaf is 12 boxes however it is
		# made, barred or panelled, so 144 triangles; the plate, intercom and speaker are 3 more
		# boxes; and the lettering is whatever `signs` costs on a house with no shop sign.
		var told := str((plan.get("features", {}) as Dictionary).get("plot", ""))
		if "leaf open against its pillar" in told:
			leaves += 1 if "1 leaf open" in told else 2
		if "name plate and intercom" in told:
			plates += 1
			if not ("sign board" in told): plate_glyphs += full_signs(plan.spec)
		var spec: Dictionary = plan.spec
		var full := _triangles(spec)
		whole += full
		for part: String in PARTS:
			var gone: int = full - _triangles(_without(spec, part))
			cost[part] = int(cost[part]) + gone
			most[part] = maxi(int(most[part]), gone)
		# The boxes split by where they stand. An outside-only house is seen from the street, so
		# what it pays for a fixture standing indoors is worth knowing on its own: some of it is
		# seen through a window and some of it is behind an opaque wall.
		var size: Vector2 = spec.size
		var indoors: Array = []
		var outdoors: Array = []
		for entry: Array in (spec.get("blocks", []) as Array):
			var at: Vector3 = entry[0]
			if at.x > 0.1 and at.x < size.x - 0.1 and at.z > 0.1 and at.z < size.y - 0.1: indoors.append(entry)
			else: outdoors.append(entry)
		var only_out := spec.duplicate()
		only_out["blocks"] = outdoors
		var only_in := spec.duplicate()
		only_in["blocks"] = indoors
		inside_cost += full - _triangles(only_out)
		outside_cost += full - _triangles(only_in)
	var n := float(maxi(houses, 1))
	var dressed := 0
	for part: String in PARTS: dressed += int(cost[part])
	print("COST %d houses, %d triangles in all = %.1f each" % [houses, whole, whole / n])
	for part: String in PARTS:
		print("COST   %-7s %7d = %6.1f a house (%4.1f%%), worst house %d" % [part, int(cost[part]), int(cost[part]) / n, 100.0 * float(cost[part]) / maxf(float(whole), 1.0), int(most[part])])
	print("COST   %-7s %7d = %6.1f a house (%4.1f%%)" % ["shell", whole - dressed, (whole - dressed) / n, 100.0 * float(whole - dressed) / maxf(float(whole), 1.0)])
	print("COST   of those boxes: %.1f a house stand indoors, %.1f on the plot" % [inside_cost / n, outside_cost / n])
	# And what the shell spends on things an outside-only house cannot show: the inner walls and
	# the stair. If those are being built behind opaque outer walls, they are the cheapest saving
	# on the table — far cheaper than any frontage detail. Measured the same way.
	var inner := 0
	var treads := 0
	var done := 0
	for index: int in world.candidates:
		if done >= 40: break
		var plan: Dictionary = world.site(index)
		if not bool(plan.ok): continue
		done += 1
		var spec: Dictionary = plan.spec
		var full := _triangles(spec)
		inner += full - _triangles(_without(spec, "partitions"))
		var flat := spec.duplicate()
		flat.erase("stair")
		treads += full - _triangles(flat)
	print("COST   inside the shell: %.1f a house is inner walls, %.1f is the stair" % [inner / n, treads / n])
	print("COST   the gate work in this window: %d leaves = %d triangles, %d plates = %d for the boxes and %d for the lettering; %.1f a house in all (%.1f%%)" % [leaves, leaves * 144, plates, plates * 36, plate_glyphs, (leaves * 144 + plates * 36 + plate_glyphs) / n, 100.0 * float(leaves * 144 + plates * 36 + plate_glyphs) / maxf(float(whole), 1.0)])
	# And what the boxes on the plot actually are. Counted, not rebuilt: every one of them is a
	# box, and a box is twelve triangles, so this is exact. The frontage is the biggest item in
	# the dressing and until now nobody had looked inside the number.
	var kinds := {"wall and pillars": 0, "coping": 0, "hedge": 0, "thin metal": 0, "slabs": 0, "the rest": 0}
	for index: int in counted:
		for entry: Array in (world.site(index).spec.get("blocks", []) as Array):
			var size: Vector3 = entry[1]
			var colour: Color = entry[2]
			var what := "the rest"
			if absf(colour.a - 0.5) < 0.01: what = "wall and pillars"
			elif colour.g > colour.r + 0.02 and colour.g > colour.b + 0.02: what = "hedge"
			elif size.y < 0.08 and size.z > 0.15 and size.z < 0.2: what = "coping"
			elif minf(size.x, size.z) < 0.06 and size.y > 0.1: what = "thin metal"
			elif size.y < 0.14 and minf(size.x, size.z) > 0.5: what = "slabs"
			kinds[what] = int(kinds[what]) + 12
	for what: String in kinds:
		print("COST   of the boxes, %-16s %6d = %6.1f a house (%4.1f%%)" % [what, int(kinds[what]), int(kinds[what]) / n, 100.0 * float(kinds[what]) / maxf(float(whole), 1.0)])
	print("COST   (of that thin metal, %d is the gate leaves, so about %.1f a house is railing)" % [leaves * 144, (int(kinds["thin metal"]) - leaves * 144) / n])
	print("COST_DONE %d at the 520-house ring" % roundi(whole / n * 520.0))
	quit(0)
