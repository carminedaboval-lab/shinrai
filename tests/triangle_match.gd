extends RefCounted
## Pairing two lists of triangles off against each other, and saying how many are left over.
##
## Used by the world probe to ask whether a full house and the outside-only house that replaces
## it hold the same triangles. It is a MATCHING problem, not a search: a triangle may be eligible
## to stand for several of the other list's, and picking wrongly orphans one that had no other
## partner. Greedy picking — first-fit or nearest-fit alike — gets that wrong wherever triangles
## lie closer together than the tolerance, which a gate's name plate does: hundreds of glyph
## slivers under a millimetre apart once read as 17 houses differing when nothing differed.
##
## So it is answered properly, with Kuhn's augmenting paths over the whole eligibility graph.
## What it returns is "no pairing of these two lists could do better", not "my guesses ran out".
##
## A fast seeding pass goes first — pairs sharing a key fine enough to be certain — but a seed is
## only ever a STARTING match: it is checked by `may_pair` like any other, and an augmenting path
## may take its partner away again. Codex found both halves of that the hard way in the first
## version, 2026-11-16, and both are in `tests/probe_matcher.gd`:
##   - a seed cannot be frozen. Uniqueness in the key is not uniqueness in the graph: the key is
##     cut to half a millimetre and eligibility reaches a millimetre and a half, so a key-unique
##     seed can take the only partner another triangle had.
##   - a seed must be checked. The key carries place, colour and size but NOT the normal, so two
##     coincident triangles facing opposite ways share a key — exactly the flipped face the check
##     exists to catch, waved through as a match.
##
## What it does NOT compare: the triangles' own corners and winding. Two triangles with the same
## centre, normal, colour and area can differ in shape. Codex's native checker covers those.
##
## An entry is [centre: Vector3, normal: Vector3, colour: Color, area: float].

const CELL := 0.02

var _first: Array = []
var _second: Array = []
var _cells := {}
var _reach := 0.0015
var _by_quad := false
var _adj := {}
var _holder := {}      # index in `second` -> index in `first`


## Whether one triangle may stand for another: the same place to within the tolerance, facing the
## same way, the same colour and the same size.
static func may_pair(a: Array, b: Array, reach: float, by_quad: bool) -> bool:
	if (b[0] as Vector3).distance_to(a[0] as Vector3) > reach: return false
	if (b[1] as Vector3).dot(a[1]) < 0.999: return false
	var ca: Color = b[2]
	var cb: Color = a[2]
	if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.01: return false
	if not by_quad and absf(float(b[3]) - float(a[3])) > 0.0005: return false
	return true


## A triangle's place, colour and size cut to half a millimetre and one colour step. Two
## triangles sharing one are in the same spot, well inside the tolerance — but sharing one is
## not on its own a reason to pair them, and this deliberately says nothing about facing.
static func seed_key(entry: Array) -> String:
	var at: Vector3 = entry[0]
	var colour: Color = entry[2]
	return "%d,%d,%d|%d,%d,%d|%d" % [roundi(at.x * 2000.0), roundi(at.y * 2000.0), roundi(at.z * 2000.0), colour.r8, colour.g8, colour.b8, roundi(float(entry[3]) * 2.0e6)]


## Every triangle of the second list that `i` of the first may stand for. Worked out when first
## asked and kept, because an augmenting path may come back to a triangle that was seeded.
func _candidates(i: int) -> Array:
	if _adj.has(i): return _adj[i]
	var entry: Array = _first[i]
	var home := Vector3i((entry[0] as Vector3 / CELL).floor())
	var list: Array[int] = []
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			for dz: int in [-1, 0, 1]:
				for n: int in _cells.get(home + Vector3i(dx, dy, dz), []):
					if may_pair(entry, _second[n], _reach, _by_quad): list.append(n)
	_adj[i] = list
	return list


## Find a partner for `i`, pushing whoever already holds one along to another of their own if
## need be. A seeded holder is pushed along like any other.
func _augment(i: int, seen: Dictionary) -> bool:
	for j: int in _candidates(i):
		if seen.has(j): continue
		seen[j] = true
		if not _holder.has(j) or _augment(int(_holder[j]), seen):
			_holder[j] = i
			return true
	return false


func unmatched(first: Array, second: Array, by_quad: bool, lonely_into: Array = []) -> int:
	_first = first
	_second = second
	_by_quad = by_quad
	_reach = 0.02 if by_quad else 0.0015
	_cells = {}
	_adj = {}
	_holder = {}
	for n: int in second.size():
		var key := Vector3i((second[n][0] as Vector3 / CELL).floor())
		if not _cells.has(key): _cells[key] = []
		(_cells[key] as Array).append(n)
	# Seeding: the pairs that are certain enough to start from. Checked with `may_pair`, and
	# left movable — they go into the holder, which augmenting paths are free to rearrange.
	var mine := {}
	var theirs := {}
	for i: int in first.size():
		var key := seed_key(first[i])
		if not mine.has(key): mine[key] = []
		(mine[key] as Array).append(i)
	for n: int in second.size():
		var key := seed_key(second[n])
		if not theirs.has(key): theirs[key] = []
		(theirs[key] as Array).append(n)
	var paired := {}
	for i: int in first.size():
		var key := seed_key(first[i])
		var ours: Array = mine[key]
		var others: Array = theirs.get(key, [])
		if ours.size() != 1 or others.size() != 1: continue
		var j: int = int(others[0])
		if _holder.has(j): continue
		if not may_pair(first[i], second[j], _reach, _by_quad): continue
		_holder[j] = i
		paired[i] = true
	# And the rest, properly.
	for i: int in first.size():
		if paired.has(i): continue
		if _augment(i, {}): paired[i] = true
	var matched: int = _holder.size()
	# What is left over, named, so a failure says where to look and not only how many.
	for i: int in first.size():
		if paired.has(i) or lonely_into.size() >= 6: continue
		lonely_into.append(["only in the first", first[i][0], first[i][2], float(first[i][3])])
	for n: int in second.size():
		if _holder.has(n) or lonely_into.size() >= 6: continue
		lonely_into.append(["only in the second", second[n][0], second[n][2], float(second[n][3])])
	return (first.size() - matched) + (second.size() - matched)
