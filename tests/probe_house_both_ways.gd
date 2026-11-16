extends SceneTree
## One house built both ways, compared as a multiset instead of by nearest neighbour:
##   godot --headless --path . --script res://tests/probe_house_both_ways.gd -- --plans=1650,1981,2189
##
## The world probe's `same_picture` check matches each triangle of the full house to a twin in
## the outside-only house by searching within 1.5 mm. That is a greedy search, and a gate's name
## plate puts hundreds of glyph slivers less than a millimetre apart, where greedy matching can
## take the wrong partner and orphan the rest even though both houses hold the same triangles.
## This settles which it is: it buckets every triangle by its place and size and compares the
## two counts, which no matching order can affect.
##
## **What it is not.** It compares a triangle's centre and area and nothing else — not its
## corners, not its winding, not its colour. Two different triangles of the same area about the
## same point fall in the same bucket. So this is evidence that two builds hold the same
## triangles in the same places, and it is not a proof that the two houses are identical from
## outside. For ordered geometry use Codex's native checker. (Codex, 2026-11-16.)
## Prints BOTH_PASS / BOTH_FAIL lines and BOTH_DONE passed=N failed=M.

const Blockout := preload("res://scripts/map1/map1_blockout.gd")
const HouseKit := preload("res://scripts/interior_kit/house_kit.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("BOTH_%s %s" % ["PASS" if ok else "FAIL", text])


## Every solid triangle a node draws, as a count of how many land in each bucket of place and
## size. `grain` is how finely the place is cut, in metres.
func _bucket(node: Node, frame: Transform3D, grain: float, into: Dictionary) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var instance := node as MeshInstance3D
		var pane: Material = preload("res://scripts/interior_kit/window.gd").pane_material()
		if instance.mesh.surface_get_material(0) != pane and instance.material_override != pane:
			var to_frame: Transform3D = frame.affine_inverse() * instance.global_transform
			var arrays: Array = instance.mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			var total: int = (indices as PackedInt32Array).size() if indices != null else points.size()
			for n: int in range(0, total, 3):
				var a: Vector3 = to_frame * points[indices[n] if indices != null else n]
				var b: Vector3 = to_frame * points[indices[n + 1] if indices != null else n + 1]
				var c: Vector3 = to_frame * points[indices[n + 2] if indices != null else n + 2]
				var middle := (a + b + c) / 3.0
				var area: float = (b - a).cross(c - a).length() * 0.5
				var key := "%d,%d,%d,%d" % [roundi(middle.x / grain), roundi(middle.y / grain), roundi(middle.z / grain), roundi(area / (grain * grain))]
				into[key] = int(into.get(key, 0)) + 1
	for child: Node in node.get_children(): _bucket(child, frame, grain, into)


func _run() -> void:
	var plans: Array[int] = [1650, 1981, 2189]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--plans="):
			plans = []
			for part: String in argument.substr(8).split(","): plans.append(int(part))
	var map: Node3D = Blockout.new()
	map.with_player = false
	root.add_child(map)
	for i: int in 4: await physics_frame
	var world: Node3D = map.world
	for index: int in plans:
		var plan: Dictionary = world.site(index)
		if not bool(plan.ok):
			_check(false, "plan %d has no house to build" % index)
			continue
		var full: Node3D = HouseKit.build(plan.spec, true)
		var look: Node3D = HouseKit.build_look(plan.spec)
		var twin: Node3D = HouseKit.build_look(plan.spec)
		for one: Node3D in [full, look, twin]:
			root.add_child(one)
			one.global_position = Vector3(3000.0, 0.0, 3000.0)
		var a := {}
		var b := {}
		var again := {}
		_bucket(full, full.global_transform, 0.0005, a)
		_bucket(look, look.global_transform, 0.0005, b)
		_bucket(twin, twin.global_transform, 0.0005, again)
		# First: is one build path even repeatable? Two outside-only houses from one spec.
		var wobble := 0
		for key: String in b: wobble += absi(int(b[key]) - int(again.get(key, 0)))
		_check(wobble == 0, "plan %d: the same spec built the same way twice gives the same triangles: %d buckets apart" % [index, wobble])
		twin.free()
		var only_full := 0
		var only_look := 0
		var worst := ""
		for key: String in a:
			var gap: int = int(a[key]) - int(b.get(key, 0))
			if gap > 0:
				only_full += gap
				if worst == "": worst = key
		for key: String in b:
			only_look += maxi(int(b[key]) - int(a.get(key, 0)), 0)
		var total: int = 0
		for key: String in a: total += int(a[key])
		_check(only_full == 0 and only_look == 0, "plan %d: %d solid triangles, %d in the full house only, %d in the outside-only house only%s" % [index, total, only_full, only_look, "" if worst == "" else " (first at bucket %s)" % worst])
		full.free()
		look.free()
	_done()


func _done() -> void:
	print("BOTH_DONE passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)
