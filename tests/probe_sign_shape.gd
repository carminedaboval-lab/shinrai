extends SceneTree
## Is a sign's lettering the same every time it is asked for?
##   godot --headless --path . --script res://tests/probe_sign_shape.gd
##
## The world probe's `same_picture` check found the two builds of one house disagreeing on the
## triangles of a gate's name plate — tiny glyph slivers, a couple of centimetres apart. Either
## the glyph outline itself comes out differently from one call to the next (the font is a
## `SystemFont`, which resolves lazily), or the two build paths do something different with the
## same outline. This asks the first question on its own, with no house in the way.
## Prints SIGN_PASS / SIGN_FAIL lines and SIGN_DONE passed=N failed=M.

const HouseKit := preload("res://scripts/interior_kit/house_kit.gd")
## Every surname `map1_house_dress.gd` can put on a gate, and two shop words. 鈴木 is deliberately
## not among them: `TextMesh` cannot decompose 鈴, so the plate came out reading 木.
const WORDS: Array[String] = ["田中", "佐藤", "山田", "高橋", "渡辺", "山本", "中村", "小林", "加藤", "吉田", "松本", "井上", "清水", "石川", "寿司", "珈琲"]

var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("SIGN_%s %s" % ["PASS" if ok else "FAIL", text])


func _run() -> void:
	for word: String in WORDS:
		# The very first ask, before anything has warmed the font up.
		var first: Dictionary = HouseKit.sign_shape(word)
		var first_corners := PackedVector3Array((first.corners as PackedVector3Array))
		var first_size: Vector2 = first.size
		# Every letter has to be there. `TextMesh` drops a glyph its convex decomposition chokes
		# on — the error at the end of this run — and what comes back is a shape of the letters
		# that survived, which on a gate's name plate reads as half a surname. A whole two-letter
		# word is about twice as wide as it is tall; a word with a letter missing is about square.
		var letters := float(word.length())
		var ratio: float = first_size.x / maxf(first_size.y, 0.0001)
		_check(first_corners.size() > 0 and ratio > letters - 0.6, "\"%s\" came out whole: %d corners, %.3f by %.3f m, %.2f wide for %d letters" % [word, first_corners.size(), first_size.x, first_size.y, ratio, word.length()])
		# And again, after a few frames, which is when a lazily resolved font would have landed.
		await physics_frame
		await physics_frame
		var again: Dictionary = HouseKit.sign_shape(word)
		var same := (again.corners as PackedVector3Array).size() == first_corners.size() and (again.size as Vector2).is_equal_approx(first_size)
		var moved := 0.0
		if same:
			for n: int in first_corners.size():
				moved = maxf(moved, first_corners[n].distance_to((again.corners as PackedVector3Array)[n]))
		_check(same and moved < 0.0001, "and the same the second time: %d corners against %d, worst corner %.4f mm away" % [(again.corners as PackedVector3Array).size(), first_corners.size(), moved * 1000.0])
	# What a coarser cut costs and saves. A gate's name plate is 12.5 cm wide: a stroke's curve
	# there is a pixel or two, so the fine cut is paid for and never seen.
	for word: String in WORDS:
		var said := "\"%s\" by how finely its curves are cut:" % word
		var fine := 0
		for step: float in [2.5, 8.0, 16.0, 30.0]:
			var shape: Dictionary = HouseKit.sign_shape(word, step)
			var count: int = (shape.corners as PackedVector3Array).size() / 3
			if is_equal_approx(step, 2.5): fine = count
			said += " %.0f deg = %d triangles (%.0f%%)" % [step, count, 100.0 * float(count) / maxf(float(fine), 1.0)]
		_check(true, said)
	# What the first cut of a sign actually costs. The look-build probe's 34 ms cold outlier is
	# plan 1660, the upstairs café, which carries six sign texts — and its warm build is 5.7 ms.
	# If cutting those six strings for the first time accounts for the gap, the spike is the
	# vector text path warming up and has nothing to do with the atlas package. Timed here
	# because this needs no house, no world and no install to settle.
	var cafe: Array[String] = ["2F  喫茶", "2F\n喫茶\n↑", "喫茶\n2F", "日用品", "喫茶  /  COFFEE"]
	var first_cut := 0
	for word: String in cafe:
		var began := Time.get_ticks_usec()
		HouseKit.sign_shape(word)
		first_cut += Time.get_ticks_usec() - began
	var again_cut := 0
	for word: String in cafe:
		var began := Time.get_ticks_usec()
		HouseKit.sign_shape(word)
		again_cut += Time.get_ticks_usec() - began
	_check(first_cut > 0, "cutting the café's %d signs for the first time cost %.2f ms; asking for the same shapes again cost %.3f ms" % [cafe.size(), float(first_cut) / 1000.0, float(again_cut) / 1000.0])
	_done()


func _done() -> void:
	print("SIGN_DONE passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)
