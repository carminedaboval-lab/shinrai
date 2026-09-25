extends RefCounted

# One source for the visible water edge, traversal, and vegetation exclusion.
const ANCHORS: Array[Vector2] = [
	Vector2(48,-68),Vector2(40,-65),Vector2(35,-61),Vector2(30,-54),
	Vector2(27,-46),Vector2(22,-37),Vector2(25,-29),Vector2(16,-19),
	Vector2(19,-8),Vector2(14,3),Vector2(23,14),Vector2(25,25),
	Vector2(31,36),Vector2(42,43),Vector2(51,49),Vector2(60,46),
	Vector2(68,41),Vector2(70,32),Vector2(76,21),Vector2(74,11),
	Vector2(79,0),Vector2(74,-12),Vector2(79,-22),Vector2(71,-34),
	Vector2(72,-44),Vector2(74,-53),Vector2(66,-60),Vector2(59,-66),
	Vector2(53,-68),
]

static func contour() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i: int in range(ANCHORS.size()):
		var current := ANCHORS[i]
		var previous := ANCHORS[posmod(i - 1, ANCHORS.size())]
		var following := ANCHORS[(i + 1) % ANCHORS.size()]
		var trim := minf(5.0, minf(current.distance_to(previous), current.distance_to(following)) * 0.45)
		var a := current.move_toward(previous, trim)
		var b := current.move_toward(following, trim)
		for step: int in range(7):
			var t := float(step) / 6.0
			points.append(a.lerp(current, t).lerp(current.lerp(b, t), t))
	return points
