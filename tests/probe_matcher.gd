extends SceneTree
## The triangle matcher on its own, with no world in the way:
##   godot --headless --path . --script res://tests/probe_matcher.gd
##
## `tests/triangle_match.gd` decides whether two houses hold the same triangles, and the world
## probe's `same_picture` rests on it. It has been wrong twice, both times in a way that a
## passing world probe could not show, so it is checked here against made-up lists where the
## right answer is known by hand.
##
## The first version took the first candidate inside its tolerance, which orphaned glyph slivers
## packed closer together than the tolerance. The second took the nearest instead, which is no
## stricter — only a different guess. The third seeded certain-looking pairs and froze them, and
## Codex reproduced two defects in that: a frozen seed can take the only partner another
## triangle had, and a seed was never checked at all, so two coincident triangles facing
## opposite ways — a flipped face, the very thing the check is for — were waved through as a
## match. Both are cases 3 and 4 below and they stay here.
## Prints MATCH_PASS / MATCH_FAIL lines and MATCH_DONE passed=N failed=M.

const Match := preload("res://tests/triangle_match.gd")
const GREY := Color(0.5, 0.5, 0.5)
const UP := Vector3.UP
const AREA := 0.001

var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("MATCH_%s %s" % ["PASS" if ok else "FAIL", text])


## A triangle entry: where its middle is (metres along one axis is enough), which way it faces.
func _tri(z: float, normal := UP, colour := GREY, area := AREA) -> Array:
	return [Vector3(0.0, 0.0, z), normal, colour, area]


func _count(first: Array, second: Array) -> int:
	return Match.new().unmatched(first, second, false)


func _run() -> void:
	_check(_count([], []) == 0, "two empty lists have nothing left over")
	_check(_count([_tri(0.0)], []) == 1, "one triangle against nothing is one left over")
	_check(_count([_tri(0.0)], [_tri(0.0)]) == 0, "a triangle against its own twin pairs off")
	_check(_count([_tri(0.0)], [_tri(0.004)]) == 2, "a triangle 4 mm away is out of reach: 2 left over")

	# 3. A seed must be movable. The key is cut to half a millimetre and eligibility reaches a
	# millimetre and a half, so a pair can be alone in the key and still not be the only pairing
	# available. Here the first triangle sits 0.1 mm from one of them — a key they share and
	# nobody else does — but the second triangle can reach only that same one. Freezing the seed
	# strands it; letting an augmenting path move the seed along pairs both.
	# (Codex reproduced this against the real functions, 2026-11-16.)
	var movable_first: Array = [_tri(0.0001), _tri(-0.0012)]
	var movable_second: Array = [_tri(0.0), _tri(0.0010)]
	_check(_count(movable_first, movable_second) == 0, "a seeded pair gives up its partner when the other triangle has no one else: 0 left over, not 2")

	# 4. A seed must be checked. The key carries place, colour and size and says nothing about
	# facing, so two coincident triangles pointing opposite ways share one and are alone in it.
	# That is a flipped face — the single thing this check exists to catch — and the first
	# version of the seeding pass called it a match. (Codex, 2026-11-16.)
	var flipped_first: Array = [_tri(0.0, Vector3.UP)]
	var flipped_second: Array = [_tri(0.0, Vector3.DOWN)]
	_check(_count(flipped_first, flipped_second) == 2, "a coincident triangle facing the other way is NOT a match, seeded or otherwise: 2 left over")
	# Why that one needs saying: the seed key really does ignore facing, so the pair really
	# would be seeded if seeds were not checked. Both halves asserted, so that nobody later
	# decides the `may_pair` call on a seed is redundant and takes it out.
	_check(Match.seed_key(flipped_first[0]) == Match.seed_key(flipped_second[0]), "the seed key says nothing about facing: a triangle and its mirror share one")
	_check(not Match.may_pair(flipped_first[0], flipped_second[0], 0.0015, false), "and `may_pair` is what rejects them, which is why every seed goes through it")
	# And the same for the movable case: the seeded pair is alone in its key on both sides, so a
	# seeding pass fires on it, while the other triangle's only candidate is that same partner.
	var keys_first := {}
	var keys_second := {}
	for one: Array in movable_first: keys_first[Match.seed_key(one)] = int(keys_first.get(Match.seed_key(one), 0)) + 1
	for one: Array in movable_second: keys_second[Match.seed_key(one)] = int(keys_second.get(Match.seed_key(one), 0)) + 1
	var shared := Match.seed_key(movable_first[0])
	var alone: bool = int(keys_first.get(shared, 0)) == 1 and int(keys_second.get(shared, 0)) == 1
	var only_one: bool = Match.may_pair(movable_first[1], movable_second[0], 0.0015, false) and not Match.may_pair(movable_first[1], movable_second[1], 0.0015, false)
	_check(alone and only_one, "and in the movable case the seed really is alone in its key while the other triangle really has one candidate, so the case bites")

	# And the case all of this began with: many triangles inside one another's tolerance, where
	# only one assignment pairs them all off. Greedy picking fails this; matching does not.
	var crowd_first: Array = []
	var crowd_second: Array = []
	for n: int in 12:
		crowd_first.append(_tri(float(n) * 0.0003))
		crowd_second.append(_tri(float(n) * 0.0003 + 0.00002))
	_check(_count(crowd_first, crowd_second) == 0, "twelve slivers 0.3 mm apart, every one inside the next one's tolerance, all pair off")

	# A real difference must still be reported: one triangle too many on one side.
	var extra: Array = crowd_first.duplicate()
	extra.append(_tri(0.5))
	_check(_count(extra, crowd_second) == 1, "and one genuinely extra triangle is still reported: 1 left over")

	# The leftovers are named, both ways round.
	var said: Array = []
	Match.new().unmatched([_tri(0.0), _tri(0.5)], [_tri(0.0), _tri(0.9)], false, said)
	var ways := {}
	for one: Array in said: ways[str(one[0])] = true
	_check(said.size() == 2 and ways.has("only in the first") and ways.has("only in the second"), "a failure names what is only in each list: %d notes, %s" % [said.size(), ",".join(PackedStringArray(ways.keys()))])
	_done()


func _done() -> void:
	print("MATCH_DONE passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)
