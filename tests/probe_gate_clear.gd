extends SceneTree
## Is an open gate leaf hung on anything, and does it foul anything?
##   godot --headless --path . --script res://tests/probe_gate_clear.gd
##
## A leaf swings 90 degrees in and stands 68 cm inside the wall line. The code that places it
## asks `_free()`, and `_free()` asks the WORLD whether a building stands there — it knows
## nothing about what the plot's own dressing has already put down. That is why this exists.
##
## **What it works from.** The dressing records each leaf in `spec["gate_leaves"]`: the side, the
## gate's `at` and `line`, the leaf's `plane` and `foot`, and the `from`/`to` range of the blocks
## it became. So a leaf is a fact here, not a guess.
##
## It used to infer one from the pillars it hung between and from how thin its members were, and
## that inference was wrong three ways, each found by Codex: a thin prop in the same air was
## absorbed into the leaf's group and excused from clashing with it; parts of a leaf were missed;
## and averaging a single surviving pillar put the gate's centre 0.94 m out, so those plots tested
## the wrong air and reported clean. Recording six numbers a leaf removed all three and the
## heuristics with them. **Where a check has to guess what it is looking at, record it instead.**
##
## Counts are of **overlapping member/block pairs**, not of distinct leaves or plots.
##
## The plot's other kinds of thing are tested too, not only its boxes: a carport's lean-to roof,
## an upright prism and a sign each become a conservative box here. They matter because the
## dressing's own guard (`_slab_free`) asks about `blocks` and nothing else, so if a leaf and a
## carport roof ever wanted the same air, neither the guard nor this check would have said so.
## What is still outside it: the world's own geometry beyond what `_free()` refused at build
## time, and the house shell itself.
## Prints GATE_PASS / GATE_FAIL lines and GATE_DONE passed=N failed=M.

const Blockout := preload("res://scripts/map1/map1_blockout.gd")
const LEAF_LONG := 0.78
const LEAF_OUT := 0.77      # the leaf's middle plane, metres from the gate's middle
const HINGE := Vector3(0.075, 0.05, 0.07)
const PLAYER_WIDE := 0.72   # the player's capsule, 0.36 radius
## The envelope the dressing guards before hanging a leaf, read from its own constants.
const LEAF_TO_PILLAR := 0.052
const LEAF_TO_INSIDE := 0.065

var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("GATE_%s %s" % ["PASS" if ok else "FAIL", text])


## How far two boxes overlap on every axis at once. Zero if they miss on any of them.
func _overlap(a_at: Vector3, a_size: Vector3, b_at: Vector3, b_size: Vector3) -> float:
	var least := INF
	for axis: int in 3:
		var reach: float = (a_size[axis] + b_size[axis]) * 0.5 - absf(a_at[axis] - b_at[axis])
		if reach <= 0.0: return 0.0
		least = minf(least, reach)
	return least


func _is_wall(entry: Array) -> bool:
	return absf(float((entry[2] as Color).a) - 0.5) < 0.01


## The plot's things that are not plain boxes, each as a box that contains it, so one clash test
## covers them all. Deliberately generous: a box a little larger than the thing reports a near
## miss as a clash, which is the safe way round for a check whose job is to find them.
func _other_shapes(spec: Dictionary) -> Array:
	var found: Array = []
	# A lean-to: a sloped roof running `run` metres from the a-b line along `inward`, standing
	# at `y` at that edge and rising by `pitch` over the run.
	for roof: Dictionary in spec.get("lean_tos", []):
		var a: Vector2 = roof.a
		var b: Vector2 = roof.b
		var inward: Vector2 = roof.inward
		var run := float(roof.get("run", 0.0))
		var far_a: Vector2 = a + inward * run
		var far_b: Vector2 = b + inward * run
		var low := minf(minf(a.x, b.x), minf(far_a.x, far_b.x))
		var high := maxf(maxf(a.x, b.x), maxf(far_a.x, far_b.x))
		var near_z := minf(minf(a.y, b.y), minf(far_a.y, far_b.y))
		var far_z := maxf(maxf(a.y, b.y), maxf(far_a.y, far_b.y))
		var base := float(roof.get("y", 0.0)) - 0.14
		var top := float(roof.get("y", 0.0)) + run * float(roof.get("pitch", 0.0)) + 0.06
		found.append([Vector3((low + high) * 0.5, (base + top) * 0.5, (near_z + far_z) * 0.5),
			Vector3(maxf(high - low, 0.02), maxf(top - base, 0.02), maxf(far_z - near_z, 0.02)), Color.WHITE, false, 0.0])
	for drum: Array in spec.get("drums", []):
		var radius := float(drum[1])
		found.append([drum[0], Vector3(radius * 2.0, float(drum[2]), radius * 2.0), Color.WHITE, false, 0.0])
	for sign: Array in spec.get("signs", []):
		found.append([sign[1], Vector3(float(sign[3]), float(sign[4]), 0.02), Color.WHITE, false, 0.0])
	return found


func _run() -> void:
	var map: Node3D = Blockout.new()
	map.with_player = false
	root.add_child(map)
	for i: int in 4: await physics_frame
	var world: Node3D = map.world
	var plots := 0
	var skipped := 0
	var groups := 0
	var clashes := 0
	var worst := 0.0
	var said := 0
	var hinges := 0
	var hung := 0
	var worst_y := INF
	var outside := 0.0
	var shapes := 0
	var tightest := INF
	var tightest_at := -1
	var through := 0
	var deepest := 0.0
	var railed_plots := 0
	for index: int in world.candidates:
		var plan: Dictionary = world.site(index)
		if not bool(plan.ok): continue
		var told := str((plan.get("features", {}) as Dictionary).get("plot", ""))
		var blocks: Array = plan.spec.get("blocks", [])
		var pillars: Array = []
		for entry: Array in blocks:
			var size: Vector3 = entry[1]
			if is_equal_approx(size.x, 0.28) and is_equal_approx(size.z, 0.28) and (entry[0] as Vector3).z < -0.2: pillars.append(entry)

		# The railing must stop at the pillar, not run through it.
		if "railing" in told and pillars.size() > 0:
			railed_plots += 1
			for entry: Array in blocks:
				var size: Vector3 = entry[1]
				if size.x < 0.4 or size.y > 0.05 or size.z > 0.05: continue
				for pillar: Array in pillars:
					var deep := _overlap(entry[0], entry[1], pillar[0], pillar[1])
					if deep <= 0.005: continue
					through += 1
					deepest = maxf(deepest, deep)

		var told_leaves: Array = plan.spec.get("gate_leaves", [])
		if told_leaves.is_empty(): continue
		plots += 1
		# Everything on the plot a leaf could run into: its boxes, and its roofs, prisms and
		# signs as boxes that contain them.
		var extra: Array = _other_shapes(plan.spec)
		shapes += extra.size()
		var others: Array = blocks + extra
		var middle: float = float(told_leaves[0].at)
		var line: float = -float(told_leaves[0].line)
		var opening := [INF, INF]
		for leaf: Dictionary in told_leaves:
			var side := float(leaf.side)
			var which: int = 0 if side < 0.0 else 1
			var plane := float(leaf.plane)
			# Exactly the blocks that leaf is, as the dressing recorded them. Nothing is judged
			# by its size or where it stands any more, so no prop can be absorbed into a leaf
			# and excused, and nothing of the leaf can be missed.
			var mine: Array = []
			for n: int in range(int(leaf.from), int(leaf.to)): mine.append(blocks[n])
			if mine.is_empty(): continue
			groups += 1
			# The guard the dressing tests before hanging a leaf must cover the whole leaf. Its
			# envelope is the hinges' 52 mm towards the pillar and the handle's 65 mm the other
			# way; a symmetric 55 mm guard left a band of handle outside it. (Codex, 2026-11-16.)
			for entry: Array in mine:
				var reach_in: float = (float((entry[0] as Vector3).x) - plane) * -side + float((entry[1] as Vector3).x) * 0.5
				var reach_out: float = (float((entry[0] as Vector3).x) - plane) * side + float((entry[1] as Vector3).x) * 0.5
				outside = maxf(outside, maxf(reach_in - LEAF_TO_INSIDE, reach_out - LEAF_TO_PILLAR))
			# The hinges must actually reach the pillar — on every axis, Y included. The clash
			# test below passes over masonry, so without this nothing would ever check that the
			# hardware this gate hangs on touches the post it hangs from. (Codex asked for this
			# as a positive assertion rather than an absence, 2026-11-16.)
			# The pillar this leaf hangs on, found at the place the dressing put it rather than
			# by picking between two: a plot where only one pillar stood can only carry a leaf
			# on that side, so it is tested like any other instead of being skipped.
			var pillar: Array = []
			var nearest := 0.2
			for one: Array in pillars:
				var off: float = absf((one[0] as Vector3).x - (middle + side * 0.94))
				if off < nearest:
					nearest = off
					pillar = one
			if pillar.is_empty():
				skipped += 1
				continue
			for entry: Array in mine:
				var size: Vector3 = entry[1]
				if not (absf(size.x - HINGE.x) < 0.002 and absf(size.y - HINGE.y) < 0.002 and absf(size.z - HINGE.z) < 0.002): continue
				hinges += 1
				var bite := _overlap(entry[0], entry[1], pillar[0], pillar[1])
				if bite > 0.0: hung += 1
				else:
					var gap_y: float = (size.y + (pillar[1] as Vector3).y) * 0.5 - absf((entry[0] as Vector3).y - (pillar[0] as Vector3).y)
					worst_y = minf(worst_y, gap_y)
			# The clear way in, measured off the built blocks rather than off the numbers that
			# placed them: how near the gate's middle anything comes, at the height a body walks.
			for entry: Array in mine:
				var at: Vector3 = entry[0]
				var size: Vector3 = entry[1]
				if at.y > 1.9: continue
				var inner: float = absf(at.x - middle) - size.x * 0.5
				opening[which] = minf(float(opening[which]), inner)
			# And everything of the leaf against everything that is not the leaf or masonry.
			for entry: Array in mine:
				for other: Array in others:
					if other == entry or mine.has(other) or _is_wall(other): continue
					var deep := _overlap(entry[0], entry[1], other[0], other[1])
					if deep <= 0.005: continue
					clashes += 1
					worst = maxf(worst, deep)
					if said < 5:
						said += 1
						print("GATE_NOTE plot %d: a leaf member %.3f x %.3f x %.3f at %.2f,%.2f,%.2f runs %.0f mm into a %.2f x %.2f x %.2f block at %.2f,%.2f,%.2f" % [index, (entry[1] as Vector3).x, (entry[1] as Vector3).y, (entry[1] as Vector3).z, (entry[0] as Vector3).x, (entry[0] as Vector3).y, (entry[0] as Vector3).z, deep * 1000.0, (other[1] as Vector3).x, (other[1] as Vector3).y, (other[1] as Vector3).z, (other[0] as Vector3).x, (other[0] as Vector3).y, (other[0] as Vector3).z])
		if opening[0] < INF and opening[1] < INF:
			var wide: float = float(opening[0]) + float(opening[1])
			if wide < tightest:
				tightest = wide
				tightest_at = index
	_check(through == 0, "the wall's railing stops at the gate pillars instead of running through them: %d rail/pillar pairs overlap on %d railed plots, deepest %.0f mm" % [through, railed_plots, deepest * 1000.0])
	_check(plots > 0 and groups > 0 and skipped == 0, "%d plots record a gate leaf; %d leaves read from the dressing's own block ranges, %d with no pillar found at the place the dressing put one" % [plots, groups, skipped])
	# Said out loud because a check that covers nothing passes just as quietly as one that
	# covers everything: these are the roofs, prisms and signs the clash test actually saw.
	_check(shapes > 0, "the plots with gates put down %d roofs, prisms and signs between them, and all of them are in the test below" % shapes)
	_check(clashes == 0, "no leaf member overlaps anything else its plot put down, boxes and roofs and prisms and signs alike: %d member/block pairs overlap, worst %.0f mm" % [clashes, worst * 1000.0])
	_check(outside <= 0.0005, "and the guard the dressing tests covers every part of the leaf, handle included: worst part stands %.1f mm outside the envelope" % [outside * 1000.0])
	_check(hinges > 0 and hung == hinges, "every hinge actually bites into its own pillar, on all three axes: %d of %d hinges, worst Y shortfall %s" % [hung, hinges, "none" if worst_y == INF else "%.0f mm" % (worst_y * -1000.0)])
	_check(tightest >= PLAYER_WIDE + 0.15, "the tightest gateway in the map is %.2f m clear at walking height against the player's %.2f m (plot %d)" % [tightest, PLAYER_WIDE, tightest_at])
	print("GATE_DONE passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)
