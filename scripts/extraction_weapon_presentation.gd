extends RefCounted

# Authored presentation accents over the supplied animation. Event times and
# source animation playback stay unchanged. Offsets affect the complete rig.
# Each row: normalized clip time, camera-local metres, Euler degrees.
const SHIGURE_PARTIAL := [
	[0.0,Vector3.ZERO,Vector3.ZERO],
	[.08,Vector3(-.015,.025,.005),Vector3(0,0,4)],
	[.16,Vector3(-.065,.070,.015),Vector3(-3,1,14)],
	[.28,Vector3(-.080,.080,.015),Vector3(-3,1,18)],
	[.50,Vector3(-.075,.080,.015),Vector3(-2,0,16)],
	[.62,Vector3(-.070,.080,.015),Vector3(-2,0,13)],
	[.65,Vector3(-.070,.080,.015),Vector3(-2,0,13)],
	[.675,Vector3(-.065,.074,.025),Vector3(-.5,0,12)],
	[.72,Vector3(-.055,.060,.010),Vector3(-1,0,10)],
	[.82,Vector3(-.020,.020,-.002),Vector3(0,0,-1)],
	[.90,Vector3(-.004,-.005,0),Vector3(0,0,-.7)],
	[1.0,Vector3.ZERO,Vector3.ZERO],
]
const KITE_PARTIAL := [
	[0.0,Vector3.ZERO,Vector3.ZERO],
	[.08,Vector3(-.025,.030,.010),Vector3(-1,0,6)],
	[.16,Vector3(-.130,.100,.030),Vector3(-5,2,22)],
	[.28,Vector3(-.145,.115,.035),Vector3(-4,2,28)],
	[.54,Vector3(-.140,.115,.025),Vector3(-4,1,25)],
	[.63,Vector3(-.140,.120,.030),Vector3(-3,0,22)],
	[.65,Vector3(-.140,.120,.030),Vector3(-3,0,22)],
	[.68,Vector3(-.130,.100,.045),Vector3(-1.5,0,20)],
	[.73,Vector3(-.120,.090,.025),Vector3(-2.5,0,18)],
	[.84,Vector3(-.040,.025,.005),Vector3(-.5,0,5)],
	[.93,Vector3(0,-.006,0),Vector3(.3,0,-1.2)],
	[1.0,Vector3.ZERO,Vector3.ZERO],
]
const SHIGURE_EMPTY := [
	[0.0,Vector3.ZERO,Vector3.ZERO],
	[.075,Vector3(-.045,.055,.015),Vector3(-2,0,12)],
	[.19,Vector3(-.080,.085,.018),Vector3(-3,1,20)],
	[.36,Vector3(-.080,.090,.012),Vector3(-2,0,16)],
	[.40,Vector3(-.080,.085,.012),Vector3(-2,0,16)],
	[.425,Vector3(-.070,.075,.025),Vector3(-.5,0,14)],
	[.49,Vector3(-.065,.075,.010),Vector3(-2,0,18)],
	[.58,Vector3(-.085,.075,.015),Vector3(-3,0,24)],
	[.68,Vector3(-.080,.085,.015),Vector3(-2,0,28)],
	[.72,Vector3(-.080,.085,.015),Vector3(-2,0,28)],
	[.76,Vector3(-.070,.075,.025),Vector3(-.5,0,25)],
	[.84,Vector3(-.025,.040,.005),Vector3(-1,0,10)],
	[.92,Vector3(-.005,-.004,0),Vector3(0,0,-1)],
	[1.0,Vector3.ZERO,Vector3.ZERO],
]
const KITE_EMPTY := [
	[0.0,Vector3.ZERO,Vector3.ZERO],
	[.075,Vector3(-.120,.100,.030),Vector3(-3,1,20)],
	[.17,Vector3(-.155,.120,.035),Vector3(-5,2,28)],
	[.32,Vector3(-.150,.130,.035),Vector3(-4,1,28)],
	[.40,Vector3(-.150,.130,.035),Vector3(-3,0,24)],
	[.425,Vector3(-.140,.110,.050),Vector3(-1,0,22)],
	[.49,Vector3(-.130,.100,.030),Vector3(-3,0,26)],
	[.59,Vector3(-.140,.110,.030),Vector3(-4,0,32)],
	[.70,Vector3(-.125,.110,.025),Vector3(-2,0,34)],
	[.72,Vector3(-.125,.110,.025),Vector3(-2,0,34)],
	[.77,Vector3(-.100,.085,.035),Vector3(-.5,0,28)],
	[.86,Vector3(-.035,.030,.005),Vector3(-1,0,8)],
	[.94,Vector3(0,-.006,0),Vector3(.3,0,-1)],
	[1.0,Vector3.ZERO,Vector3.ZERO],
]

static func pose(gun: String, empty: bool, ratio: float) -> Transform3D:
	var curve: Array = (KITE_EMPTY if empty else KITE_PARTIAL) if gun=="kite" else (SHIGURE_EMPTY if empty else SHIGURE_PARTIAL)
	var t := clampf(ratio,0,1)
	var index := 0
	while index < curve.size()-2 and t > float(curve[index+1][0]): index += 1
	var segment := clampf((t-float(curve[index][0]))/(float(curve[index+1][0])-float(curve[index][0])),0,1)
	# Smooth acceleration within each authored phase, including a brief seating
	# pulse and damped return. Exact zero endpoints avoid residual ADS offsets.
	var blend := smoothstep(0.0,1.0,segment)
	var offset: Vector3 = (curve[index][1] as Vector3).lerp(curve[index+1][1],blend)
	var degrees: Vector3 = (curve[index][2] as Vector3).lerp(curve[index+1][2],blend)
	return Transform3D(Basis.from_euler(degrees*PI/180.0),offset)

static func magazine_grasp(gun: String, empty: bool, ratio: float) -> float:
	if empty:
		# The supplied empty clip drops the spent magazine, then brings up a
		# replacement. Do not make the arm follow the falling magazine.
		var release := smoothstep(0.0,.055,ratio)*(1.0-smoothstep(.075,.11,ratio))
		var replacement := smoothstep(.245,.285,ratio)*(1.0-smoothstep(.425 if gun=="kite" else .415,.515 if gun=="kite" else .49,ratio))
		return maxf(release,replacement)
	return smoothstep(.0,.14 if gun=="kite" else .12,ratio)*(1.0-smoothstep(.66,.78 if gun=="kite" else .74,ratio))

static func bolt_press(gun: String, ratio: float) -> float:
	return smoothstep(.56 if gun=="kite" else .60,.70,ratio)*(1.0-smoothstep(.77,.91 if gun=="kite" else .88,ratio))

static func magazine_arc(gun: String, empty: bool, ratio: float) -> Vector3:
	# Lift the detached magazine into the working area. The added path is zero
	# at removal/seating events; the palm follows the actual moving mesh.
	var weight := magazine_display(gun,empty,ratio)
	return (Vector3(0,.090,.065) if gun=="kite" else Vector3(0,.045,.035))*weight

static func magazine_display(_gun: String, empty: bool, ratio: float) -> float:
	return smoothstep(.245 if empty else .16,.285 if empty else .22,ratio)*(1.0-smoothstep(.33 if empty else .50,.38 if empty else .63,ratio))

static func support_return(empty: bool, ratio: float) -> float:
	return smoothstep(.84 if empty else .74,.96 if empty else .90,ratio)
