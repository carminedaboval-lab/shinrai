extends RefCounted
## Pistol reload with retention: the old magazine goes back into the rig and a
## fresh one comes out, in one continuous movement (2.7 s on the Akane).
##
## Beats, as a share of the reload (seconds at 2.7 s):
##   0.00-0.12  gun comes up and in toward the eye, rolls so the magazine well
##              faces the support hand and the muzzle tips up; the support hand
##              drops under the grip
##   0.16       release pressed, magazine starts out            (0.43 s, sound)
##   0.22       magazine clear of the grip
##   0.32-0.35  old magazine pushed into its pouch, low left    (0.86-0.95 s)
##   0.39-0.42  hand hops to the next pouch and takes a fresh one
##   0.675      fresh magazine lined up under the well
##   0.70       driven home                                     (1.89 s, sound)
##   0.725      seated: the gun is knocked up and settles
##   0.76-0.92  support hand back on the grip, gun rolls level, small overshoot
##   empty gun only: slide released at 0.80
## Nothing stops between beats: positions run through the keys on a spline, so
## the hand and gun keep their speed through each one instead of pausing on it.
## The pouches are only just below the picture, so the hand is out of sight for
## about half a second, not a second.

const OUT_AT := 0.16
const STOWED_AT := 0.345     # old magazine no longer drawn (it is in the pouch)
const DRAWN_AT := 0.415      # fresh magazine drawn from here
const IN_AT := 0.70
const BOLT_AT := 0.80

# Gun, in the viewmodel's axes (x right, y up, z toward the shooter), metres and
# degrees (x muzzle up, y muzzle left, z negative = grip base swings left).
# Rotation is about the grip, so the hand stays on it.
const GUN := [
	[0.00, Vector3(0, 0, 0), Vector3(0, 0, 0)],
	[0.05, Vector3(-.030, .040, .012), Vector3(4, 2, -6)],
	[0.12, Vector3(-.160, .225, .060), Vector3(16, 10, -38)],
	[0.16, Vector3(-.190, .262, .078), Vector3(20, 12, -46)],
	[0.20, Vector3(-.190, .276, .082), Vector3(23, 12, -44)],
	[0.28, Vector3(-.195, .262, .084), Vector3(19, 11, -46)],
	[0.42, Vector3(-.200, .248, .086), Vector3(16, 13, -51)],
	[0.56, Vector3(-.197, .253, .084), Vector3(19, 12, -49)],
	[0.675, Vector3(-.195, .250, .082), Vector3(19, 12, -47)],
	[0.715, Vector3(-.193, .282, .072), Vector3(25, 11, -42)],
	[0.765, Vector3(-.190, .256, .080), Vector3(17, 11, -40)],
	[0.84, Vector3(-.115, .156, .042), Vector3(9, 6, -20)],
	[0.92, Vector3(-.014, .015, .002), Vector3(-1.5, .5, -1)],
	[0.97, Vector3(.002, -.004, 0), Vector3(.6, 0, .4)],
	[1.00, Vector3(0, 0, 0), Vector3(0, 0, 0)],
]
# Magazine, in the gun's own axes (x toward the shooter, y up, z shooter's left),
# metres and degrees. Zero is seated. The grip is raked, so "out" runs down and
# back; the pouches sit low, left and close to the body.
const MAGAZINE := [
	[0.00, Vector3(0, 0, 0), Vector3(0, 0, 0)],
	[0.13, Vector3(0, 0, 0), Vector3(0, 0, 0)],
	[0.16, Vector3(.006, -.018, 0), Vector3(0, 0, 0)],
	[0.215, Vector3(.047, -.126, .004), Vector3(0, 0, 0)],
	[0.26, Vector3(.100, -.200, .050), Vector3(-20, 0, 25)],
	[0.32, Vector3(.235, -.295, .135), Vector3(-55, 10, 60)],
	[0.35, Vector3(.262, -.315, .145), Vector3(-60, 10, 65)],
	[0.385, Vector3(.258, -.310, .108), Vector3(-60, 10, 65)],
	[0.42, Vector3(.252, -.314, .098), Vector3(-60, 10, 65)],
	[0.47, Vector3(.200, -.262, .080), Vector3(-45, 8, 50)],
	[0.56, Vector3(.110, -.200, .030), Vector3(-18, 0, 20)],
	[0.64, Vector3(.060, -.150, .004), Vector3(-3, 0, 3)],
	[0.675, Vector3(.050, -.137, 0), Vector3(0, 0, 0)],
	[0.70, Vector3(.022, -.058, 0), Vector3(0, 0, 0)],
	[0.725, Vector3(0, 0, 0), Vector3(0, 0, 0)],
	[1.00, Vector3(0, 0, 0), Vector3(0, 0, 0)],
]

# Support-hand fingers: 0 = closed as on the grip, 1 = open.
const FINGERS := [
	[0.00, 0.0], [0.03, 0.0], [0.08, 0.55], [0.13, 0.25], [0.16, 0.10], [0.31, 0.10],
	[0.35, 0.50], [0.385, 0.60], [0.42, 0.12], [0.705, 0.12], [0.74, 0.45], [0.82, 0.35],
	[0.92, 0.0], [1.00, 0.0],
]
static func _segment(keys: Array, ratio: float) -> int:
	var index := 0
	while index < keys.size() - 2 and ratio > float(keys[index + 1][0]):
		index += 1
	return index

## Catmull-Rom through the keys: the value keeps moving through each key.
static func _spline(keys: Array, column: int, ratio: float) -> Vector3:
	var t := clampf(ratio, 0.0, 1.0)
	var i := _segment(keys, t)
	var p0: Vector3 = keys[maxi(i - 1, 0)][column]
	var p1: Vector3 = keys[i][column]
	var p2: Vector3 = keys[i + 1][column]
	var p3: Vector3 = keys[mini(i + 2, keys.size() - 1)][column]
	var u := clampf((t - float(keys[i][0])) / maxf(float(keys[i + 1][0]) - float(keys[i][0]), 0.0001), 0.0, 1.0)
	# A segment that holds still (both ends equal) must stay still.
	if p1.is_equal_approx(p2):
		return p1
	return 0.5 * ((2.0 * p1) + (p2 - p0) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (3.0 * p1 - p0 - 3.0 * p2 + p3) * u * u * u)

static func _linear(keys: Array, ratio: float) -> float:
	var t := clampf(ratio, 0.0, 1.0)
	var i := _segment(keys, t)
	var u := clampf((t - float(keys[i][0])) / maxf(float(keys[i + 1][0]) - float(keys[i][0]), 0.0001), 0.0, 1.0)
	return lerpf(float(keys[i][1]), float(keys[i + 1][1]), smoothstep(0.0, 1.0, u))

static func _basis(degrees: Vector3) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z)))

## Gun movement in the viewmodel's axes, rotating about `grip` (viewmodel-local).
static func gun(ratio: float, empty: bool, grip: Vector3) -> Transform3D:
	var position := _spline(GUN, 1, ratio)
	var degrees := _spline(GUN, 2, ratio)
	if empty:
		# The slide runs forward: a short snap forward and down that dies away.
		var since := ratio - BOLT_AT
		if since > 0.0:
			var snap := exp(-since * 38.0) * sin(since * 70.0)
			position += Vector3(0, -.004, -.010) * snap
			degrees += Vector3(-3.0, 0, 0) * snap
	var basis := _basis(degrees)
	return Transform3D(basis, position + grip - basis * grip)

## Magazine offset in the gun's axes (apply as gun * offset * seated transform).
static func magazine(ratio: float) -> Transform3D:
	return Transform3D(_basis(_spline(MAGAZINE, 2, ratio)), _spline(MAGAZINE, 1, ratio))

## How much the support hand is on the magazine (1) rather than the grip (0).
static func grasp(ratio: float) -> float:
	return smoothstep(0.03, 0.12, ratio) * (1.0 - smoothstep(0.735, 0.86, ratio))

static func fingers_open(ratio: float) -> float:
	return _linear(FINGERS, ratio)

## Empty gun: the support thumb sweeps the slide stop on its way back to the grip.
static func slide_release(empty: bool, ratio: float) -> float:
	return smoothstep(0.74, BOLT_AT, ratio) * (1.0 - smoothstep(BOLT_AT + 0.02, 0.92, ratio)) if empty else 0.0
