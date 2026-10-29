extends RefCounted

# Pistol-only visual choreography. Existing clip durations and gameplay commits
# remain authoritative; the UZI clips provide the clock, not magazine/hand travel.
const PARTIAL_MAGAZINE := [
	[0.0,Vector3.ZERO], [.06,Vector3.ZERO],
	[.16,Vector3(.012,-.075,0)], [.26,Vector3(.030,-.145,.012)],
	[.40,Vector3(.055,-.200,.030)], [.46,Vector3(.045,-.180,.025)],
	[.54,Vector3(.020,-.105,.010)], [.60,Vector3(.006,-.040,0)],
	[.65,Vector3.ZERO], [1.0,Vector3.ZERO],
]
const EMPTY_MAGAZINE := [
	[0.0,Vector3.ZERO], [.025,Vector3.ZERO],
	[.08,Vector3(.012,-.075,0)], [.18,Vector3(.030,-.200,0)],
	[.27,Vector3(.045,-.285,0)], [.31,Vector3(.030,-.160,.020)],
	[.36,Vector3(.008,-.065,.004)], [.40,Vector3.ZERO],
	[1.0,Vector3.ZERO],
]

static func pose(gun: String, empty: bool, ratio: float) -> Transform3D:
	var lift := smoothstep(0.0,.16,ratio)*(1.0-smoothstep(.76 if empty else .68,.98 if empty else .92,ratio))
	var scale := .95 if gun == "hibari_h9c" else (1.05 if gun == "onikiri" else 1.0)
	# Bring the grip base into view with a modest inward cant; no SMG body pose.
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(-4),deg_to_rad(8),deg_to_rad(-12))*lift),Vector3(-.150,.205,-.015)*lift*scale)

static func magazine_offset(empty: bool, ratio: float) -> Vector3:
	var curve: Array = EMPTY_MAGAZINE if empty else PARTIAL_MAGAZINE
	var t := clampf(ratio,0,1)
	var index := 0
	while index < curve.size()-2 and t > float(curve[index+1][0]): index += 1
	var alpha := smoothstep(0.0,1.0,clampf((t-float(curve[index][0]))/(float(curve[index+1][0])-float(curve[index][0])),0,1))
	return (curve[index][1] as Vector3).lerp(curve[index+1][1],alpha)

static func magazine_grasp(_gun: String, empty: bool, ratio: float) -> float:
	if empty:
		# The spent magazine drops independently; support hand meets replacement.
		return smoothstep(.25,.31,ratio)*(1.0-smoothstep(.43,.51,ratio))
	return smoothstep(.02,.12,ratio)*(1.0-smoothstep(.67,.86,ratio))

static func release_weight(empty: bool, ratio: float) -> float:
	return smoothstep(.54,.68,ratio)*(1.0-smoothstep(.76,.90,ratio)) if empty else 0.0

static func bolt_press(_gun: String, ratio: float) -> float:
	return release_weight(true,ratio)

static func support_fetch(empty: bool, ratio: float) -> float:
	return smoothstep(.02,.14,ratio)*(1.0-smoothstep(.25,.31,ratio)) if empty else 0.0

static func support_return(empty: bool, ratio: float) -> float:
	return smoothstep(.84 if empty else .74,.96 if empty else .90,ratio)
