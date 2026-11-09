extends SceneTree
## Memory-fix round, TEXTURES role: proves the indexed near-city emitters draw exactly the
## triangles the six-corner emitters drew. Builds the same shells (hero) and kit parts with
## the saved original scripts and the edited ones, expands the new indices back to corner
## lists and compares every attribute bit for bit. Headless, seconds, no park.
##   godot --headless --script res://tests/probe_mem_near_city_index.gd -- --orig=<dir with midori_near_city_hero.gd / _kit.gd>

func _initialize() -> void:
	var orig_dir := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--orig="): orig_dir = arg.get_slice("=", 1)
	if orig_dir == "":
		print("NCIDX_FAIL no --orig=<dir>")
		quit(1)
		return
	var old_hero_script: GDScript = load(orig_dir.path_join("midori_near_city_hero.gd"))
	var old_kit_script: GDScript = load(orig_dir.path_join("midori_near_city_kit.gd"))
	var new_hero_script: GDScript = load("res://scripts/midori_near_city_hero.gd")
	var new_kit_script: GDScript = load("res://scripts/midori_near_city_kit.gd")
	if old_hero_script == null or old_kit_script == null or new_hero_script == null or new_kit_script == null:
		print("NCIDX_FAIL scripts did not load")
		quit(1)
		return
	var failures := 0
	var checked := 0
	# --- hero: a spread of specs over the generator's ranges (same calls into both) ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 20500702
	var old_hero: RefCounted = old_hero_script.new()
	var new_hero: RefCounted = new_hero_script.new()
	for i: int in range(60):
		var seed_value := rng.randf()
		var spec := {"seed": seed_value, "storey": 3.2, "ground": [0.0, 4.2][i % 2], "mansion": i % 5 == 0, "metal": Color(.5, .52, .54, 1.0),
			"radius": [.06, 1.2, .4][i % 3], "bay": 1.7 + rng.randf() * 3.3, "pane_x": .12 + rng.randf() * .34, "pane_y": .58 + rng.randf() * .6, "sill": .42 + rng.randf() * .2,
			"recess": [.08, .2, .7, .9][i % 4], "detail": i % 3, "tint": Color(rng.randf(), rng.randf(), rng.randf(), float(i % 8) / 8.0),
			"lobby": i % 4 == 1, "quoin": i % 3 == 2, "undercroft": i % 7 == 3, "deck": i % 11 == 5, "parapet": [.9, .3, 0.0][i % 3]}
		if i % 6 == 4: spec["band"] = Color(.2, .2, .2, 1.0 / 8.0)
		var size := Vector3(6.0 + rng.randf() * 20.0, 6.0 + rng.randf() * 30.0, 6.0 + rng.randf() * 16.0)
		var centre := Vector2(rng.randf_range(-600, 600), rng.randf_range(-600, 600))
		var key := i % 7
		old_hero.add(centre, 0.0, size, i % 4, key, spec.duplicate())
		new_hero.add(centre, 0.0, size, i % 4, key, spec.duplicate())
	var old_walls: Dictionary = old_hero.walls()
	var new_walls: Dictionary = new_hero.walls()
	var old_glass: Dictionary = old_hero.glass()
	var new_glass: Dictionary = new_hero.glass()
	for key: int in old_walls:
		checked += 1
		if not _same(old_walls[key], new_walls.get(key, {}), "hero walls %d" % key): failures += 1
		checked += 1
		if not _same(old_glass[key], new_glass.get(key, {}), "hero glass %d" % key): failures += 1
	if old_walls.keys() != new_walls.keys(): failures += 1; print("NCIDX_DIFF hero key order")
	# --- kit: every emitter ---
	var old_kit: RefCounted = old_kit_script.new()
	var new_kit: RefCounted = new_kit_script.new()
	for kit: RefCounted in [old_kit, new_kit]:
		var r := RandomNumberGenerator.new()
		r.seed = 7
		for i: int in range(40):
			var a := Vector3(r.randf() * 5, r.randf() * 5, r.randf() * 5)
			var b := a + Vector3(0, 1 + r.randf(), 0)
			var d := a + Vector3(1 + r.randf(), 0, r.randf())
			var c := b + (d - a)
			kit.quad("wall", a, b, c, d, Color(r.randf(), r.randf(), r.randf()), r.randf(), r.randf(), r.randf(), Vector2(r.randf(), r.randf()))
			kit.smooth("tube", a, b, c, d, Vector3.UP, Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD, Color(.3, .4, .5), r.randf())
			kit.smooth("tube", d, c, b, a, Vector3.UP, Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD, Color(.3, .4, .5), r.randf())
			var pts: Array[Vector3] = [a, b, c, d]
			var nrm: Array[Vector3] = [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]
			var prints: Array[Vector2] = [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]
			var marks: Array[float] = [r.randf(), r.randf(), r.randf(), r.randf()]
			kit.mapped("cut", pts, nrm, prints, marks, Color(.9, .8, .7), r.randf())
			nrm = [Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN]
			kit.mapped("cut", pts, nrm, prints, marks, Color(.9, .8, .7), r.randf())
			kit.atlas("sign", a, b, c, d, Rect2(r.randf() * .5, r.randf() * .5, .25, .25), Color(.9, .9, .9), r.randf(), r.randf())
			kit.block("steel", Transform3D(Basis(Vector3.UP, r.randf() * TAU), a), Vector3(1 + r.randf(), 1 + r.randf(), 1 + r.randf()), Color(.5, .5, .5), r.randf(), r.randf(), r.randf())
			kit.beam("steel", a, b + Vector3(2, 0, 1), .1, .2, Vector3.UP, Color(.4, .4, .4), r.randf())
			var path: Array[Vector3] = [a, b, c, d]
			kit.tube("cable", path, .02 + r.randf() * .1, Color(.1, .1, .1), 3 + i % 5, r.randf())
			var profile: Array[Vector2] = [Vector2(.2, 0), Vector2(.3, .1), Vector2(.1, .5), Vector2(.05, .7)]
			kit.lathe("plain", a, profile, Color(.2, .6, .4), 6 + i % 7)
			kit.lathe("plain", d, profile, Color(.2, .6, .4), 8, Rect2(.1, .1, .3, .3))
			kit.disc("plain", a, Vector3.RIGHT, Vector3.UP, .4, Color(.7, .7, .7), Rect2(0, 0, .5, .5))
			kit.pane("glass", Transform3D(Basis.IDENTITY, a), -1.0, 1.0, 0.0, 1.5, .1, r.randf())
			var target: Dictionary = kit._part("cloth")
			kit._emit(target, a, Vector3.UP, Vector3.RIGHT, Color.WHITE, Vector2.ZERO, Vector2.ZERO)
			kit._emit(target, b, Vector3.UP, Vector3.RIGHT, Color.WHITE, Vector2.ZERO, Vector2.ZERO)
			kit._emit(target, c, Vector3.UP, Vector3.RIGHT, Color.WHITE, Vector2.ZERO, Vector2.ZERO)
			kit.quad("cloth", a, b, c, d, Color.WHITE)
		kit._park()
	var old_parts: Dictionary = old_kit._parts
	var new_parts: Dictionary = new_kit._parts
	if old_parts.keys() != new_parts.keys(): failures += 1; print("NCIDX_DIFF kit part order ", old_parts.keys(), " vs ", new_parts.keys())
	for part: String in old_parts:
		checked += 1
		if not _same(old_parts[part], new_parts.get(part, {}), "kit part " + part): failures += 1
	# Vertex counts per quad: the saving the change is for.
	var old_v := 0
	var new_v := 0
	for key: int in old_walls: old_v += (old_walls[key].v as PackedVector3Array).size(); new_v += (new_walls[key].v as PackedVector3Array).size()
	print("NCIDX hero wall vertices old=%d new=%d (%.0f%%)" % [old_v, new_v, 100.0 * float(new_v) / maxf(1.0, float(old_v))])
	print("NCIDX_RESULT checked=%d failures=%d %s" % [checked, failures, "PASS" if failures == 0 else "FAIL"])
	quit(0 if failures == 0 else 1)

## Expands an indexed part to corner lists and compares them with a plain part, attribute by attribute.
func _same(old: Dictionary, new: Dictionary, label: String) -> bool:
	if new.is_empty():
		print("NCIDX_DIFF %s: missing in new" % label)
		return false
	var idx: PackedInt32Array = new.get("i", PackedInt32Array())
	var ov: PackedVector3Array = old.v
	if idx.is_empty():
		if ov.size() != (new.v as PackedVector3Array).size():
			print("NCIDX_DIFF %s: unindexed and %d vs %d vertices" % [label, ov.size(), (new.v as PackedVector3Array).size()])
			return false
	if not idx.is_empty() and idx.size() != ov.size():
		print("NCIDX_DIFF %s: %d old corners vs %d new indices" % [label, ov.size(), idx.size()])
		return false
	var nv: PackedVector3Array = new.v
	var on: PackedVector3Array = old.n
	var nn: PackedVector3Array = new.n
	var ot: PackedFloat32Array = old.t
	var nt: PackedFloat32Array = new.t
	var oc: PackedColorArray = old.c
	var nc: PackedColorArray = new.c
	var ou: PackedVector2Array = old.u
	var nu: PackedVector2Array = new.u
	var ou2: PackedVector2Array = old.u2
	var nu2: PackedVector2Array = new.u2
	if nn.size() != nv.size() or nt.size() != nv.size() * 4 or nc.size() != nv.size() or nu.size() != nv.size() or nu2.size() != nv.size():
		print("NCIDX_DIFF %s: new arrays ragged v=%d n=%d t=%d c=%d u=%d u2=%d" % [label, nv.size(), nn.size(), nt.size(), nc.size(), nu.size(), nu2.size()])
		return false
	# Every index must be in range, and every new vertex referenced at least once.
	var used := PackedByteArray()
	used.resize(nv.size())
	for k: int in range(idx.size()):
		var j := idx[k]
		if j < 0 or j >= nv.size():
			print("NCIDX_DIFF %s: index %d out of range at %d" % [label, j, k])
			return false
		used[j] = 1
		if ov[k] != nv[j] or on[k] != nn[j] or oc[k] != nc[j] or ou[k] != nu[j] or ou2[k] != nu2[j] \
			or ot[k * 4] != nt[j * 4] or ot[k * 4 + 1] != nt[j * 4 + 1] or ot[k * 4 + 2] != nt[j * 4 + 2] or ot[k * 4 + 3] != nt[j * 4 + 3]:
			print("NCIDX_DIFF %s: corner %d differs (old v=%s new v=%s)" % [label, k, ov[k], nv[j]])
			return false
	for j: int in range(nv.size()):
		if used[j] == 0 and not idx.is_empty():
			print("NCIDX_DIFF %s: vertex %d never indexed" % [label, j])
			return false
	return true
