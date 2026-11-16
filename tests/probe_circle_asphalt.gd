extends SceneTree
## Why the turning circle's road is flat grey picture ground beside textured approaches:
##   godot --headless --path . --script res://tests/probe_circle_asphalt.gd
##
## `Blockout._circle_asphalt()` already exists and already lays a proper surface with metre UVs
## on the existing unpainted asphalt material. It selects its two approach sides by gathering
## EVERY street edge in the map whose `fillet_at >= 0` and giving up unless there are exactly
## two. But `end_corner_r` and `end_fillet` set that same flag on shop and tram corners that
## have nothing to do with the circle, so the count can run past two and the surface is never
## laid at all. This counts them and says which, so the repair is aimed rather than guessed.
## Prints CIRCLE_ lines and CIRCLE_DONE passed=N failed=M.

const Blockout := preload("res://scripts/map1/map1_blockout.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("CIRCLE_%s %s" % ["PASS" if ok else "FAIL", text])


func _run() -> void:
	var map: Node3D = Blockout.new()
	map.with_player = false
	root.add_child(map)
	for i: int in 4: await physics_frame
	var flagged: Array[String] = []
	for street: Node3D in map.street_edges:
		if float(street.fillet_at) >= 0.0:
			var edge: Dictionary = street.get_meta("edge")
			flagged.append("%s/%s" % [str(edge.get("name", "?")), "A" if float(street.side) > 0.0 else "B"])
	_check(map.circle_edge != null, "the turning circle's ring exists")
	# Kept as information, not as a requirement: this is the count the old selector gathered and
	# the reason it gave up. The surface no longer depends on it, and it will keep growing as
	# more corners get fillets — which is exactly why selecting on it was wrong.
	print("CIRCLE_INFO %d street edges carry fillet_at >= 0, which is what the old selector gathered: %s" % [flagged.size(), ", ".join(flagged)])
	# What it depends on now: the two sides recorded where the circle was built.
	var sides: Array = map.circle_sides
	var named: Array[String] = []
	for street: Node3D in sides: named.append(str((street.get_meta("edge") as Dictionary).get("name", "?")))
	_check(sides.size() == 2 and named[0] == named[1], "the circle keeps its own two approach sides, both of one street: %s" % str(named))
	# And the question that actually matters: is there a surface under the circle or not?
	var laid := 0
	for street: Node3D in map.street_edges:
		for child: Node in street.get_children():
			if child is MeshInstance3D and str(child.name).findn("circle") >= 0: laid += 1
	_check(laid > 0, "a circle road surface was built: %d found" % laid)
	print("CIRCLE_DONE passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)
