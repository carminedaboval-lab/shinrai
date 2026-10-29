extends RefCounted
## Raiden nonempty reload presentation trial. Normalized to its existing 2.5 s
## gameplay reload, including eject at .16 and insert at .65. No gameplay state.
## The sampled reference shows a long pouch interval; this candidate compresses
## it to the existing game events. The source clip's chamber state is unknown.

const WORKING_POSE := [
	[0.00, Vector3.ZERO, Vector3.ZERO],
	[0.08, Vector3(-.005,.012,0), Vector3.ZERO],
	[0.16, Vector3(-.020,.035,0), Vector3.ZERO],
	[0.25, Vector3(-.025,.045,0), Vector3.ZERO],
	[0.60, Vector3(-.025,.045,0), Vector3.ZERO],
	[0.65, Vector3(-.023,.042,0), Vector3.ZERO],
	[0.69, Vector3(-.020,.035,0), Vector3.ZERO],
	[0.76, Vector3(-.015,.025,0), Vector3.ZERO],
	[0.88, Vector3(-.005,.010,0), Vector3.ZERO],
	[1.00, Vector3.ZERO, Vector3.ZERO],
]

static func pose(ratio: float) -> Transform3D:
	var t := clampf(ratio, 0.0, 1.0)
	var i := 0
	while i < WORKING_POSE.size() - 2 and t > float(WORKING_POSE[i + 1][0]):
		i += 1
	var fraction := (t - float(WORKING_POSE[i][0])) / (float(WORKING_POSE[i + 1][0]) - float(WORKING_POSE[i][0]))
	var blend := smoothstep(0.0, 1.0, clampf(fraction, 0.0, 1.0))
	var a: Vector3 = WORKING_POSE[i][1]
	var b: Vector3 = WORKING_POSE[i + 1][1]
	var r1: Vector3 = WORKING_POSE[i][2]
	var r2: Vector3 = WORKING_POSE[i + 1][2]
	return Transform3D(Basis.from_euler(r1.lerp(r2, blend) * PI / 180.0), a.lerp(b, blend))

static func magazine_offset(ratio: float) -> Vector3:
	# Camera-local metres. Anchor at the real seated magazine; take the old
	# magazine toward the pouch and bring the new one back to the same socket.
	# These distances are deliberately tunable, not measured world geometry.
	var travel := smoothstep(.16, .33, ratio) * (1.0 - smoothstep(.51, .65, ratio))
	return Vector3(-.23, -.55, .04) * travel

static func grasp(ratio: float, started_without_mag: bool = false) -> float:
	# Use the existing arm IK to follow the actual magazine pivot throughout the
	# outgoing and incoming paths; then move the hand back to the foregrip.
	# A restarted reload with a chambered round but no inserted magazine has
	# nothing to remove: leave the foregrip only when fetching its replacement.
	var approach := smoothstep(.23, .43, ratio) if started_without_mag else smoothstep(.035, .14, ratio)
	return approach * (1.0 - smoothstep(.67, .84, ratio))

static func support_return(ratio: float) -> float:
	return smoothstep(.70, .90, ratio)
