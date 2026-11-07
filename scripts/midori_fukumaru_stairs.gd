extends RefCounted
## The residential stair occupies the east alley. Coordinates are in metres in
## the house's own space, where +Z faces the public pavement and +X is east.
const Kit := preload("res://scripts/midori_near_city_kit.gd")
const INNER := 1.86
const OUTER := 3.12
const MID := (INNER + OUTER) * 0.5
const WIDTH := OUTER - INNER
const RAIL_X := OUTER - 0.045
const FRAME := Color("#525b58")
const GALVANISED := Color("#8b9593")
const FLOOR := Color("#666d6b")
const NOSING := Color("#b6ab80")

static func build(house: Node3D) -> void:
	var kit: Kit = house.get("_kit")
	# The city's drawn pavement is at house Y=0; its playable floor is 8 cm
	# lower. This slim sill bridges them before the first tread.
	_deck(house, kit, "EntryApron", Vector2(1.40,-0.08), Vector2(0.75,0.0), 0.075)
	_flight(house, kit, "Lower", Vector2(0.75,0.0), Vector2(-3.23,3.30), 19)
	_landing(house, kit, "SecondFloor", -3.23, -4.55, 3.30)
	_flight(house, kit, "Upper", Vector2(-4.55,3.30), Vector2(-8.0,6.15), 17)
	_landing(house, kit, "ThirdFloor", -8.0, -9.18, 6.15)
	# Only the far end is closed. Both west edges at the landings open directly
	# into the apartments, and the first tread faces the street.
	var stop_z := -9.15
	for height: float in [0.44,1.02]:
		kit.tube("metal",[Vector3(INNER,6.15+height,stop_z),Vector3(RAIL_X,6.15+height,stop_z)],0.023,GALVANISED,8)
	for x: float in [INNER+0.035,MID,RAIL_X]:
		kit.block("metal",Transform3D(Basis.IDENTITY, Vector3(x,6.65,stop_z)),Vector3(0.035,1.02,0.035),FRAME)
	house.apartment_solid("ResidentialStairBackGuard",Vector3(MID,6.65,stop_z),Vector3(WIDTH,1.02,0.055))

static func _flight(house: Node3D, kit: Kit, label: String, low: Vector2, high: Vector2, steps: int) -> void:
	var run := low.x - high.x
	var rise := high.y - low.y
	var pitch := Basis(Vector3.RIGHT,atan2(rise,run))
	var length := low.distance_to(high)
	var mid := Vector3(MID,(low.y+high.y)*0.5,(low.x+high.x)*0.5)
	# A smooth top plane beneath the visual folded-steel treads lets the real
	# character move continuously in both directions. Only its top meets the landings.
	house.apartment_solid(label+"StairRamp",mid - pitch.y*0.07,Vector3(WIDTH,0.14,length),pitch)
	var going := run / steps
	var step_rise := rise / steps
	for index: int in range(steps):
		var z := low.x - going*(index+0.5)
		var y := low.y + step_rise*(index+0.5)
		kit.block("metal",Transform3D(Basis.IDENTITY,Vector3(MID,y-0.014,z)),Vector3(WIDTH-0.046,0.028,going+0.012),FLOOR,0.83,1.0)
		# Rolled front edge and a narrow aggregate grip strip.
		kit.block("metal",Transform3D(Basis.IDENTITY,Vector3(MID,y-0.045,z+going*0.5)),Vector3(WIDTH-0.046,0.074,0.018),FRAME)
		kit.block("plain",Transform3D(Basis.IDENTITY,Vector3(MID,y+0.001,z+going*0.5-0.033)),Vector3(WIDTH-0.082,0.004,0.038),NOSING,0.86,0.94)
	for x: float in [INNER+0.024,OUTER-0.024]:
		kit.block("metal",Transform3D(pitch,Vector3(x,mid.y,mid.z)-pitch.y*0.069),Vector3(0.052,0.19,length),FRAME,0.75,0.95)
	_guard(house,kit,label,low,high)
	# Short wall returns end on the flights; the landing doorways have no rail across them.
	var walkside := INNER + 0.089
	var first := low.lerp(high,0.055)
	var last := low.lerp(high,0.945)
	kit.tube("metal",[Vector3(INNER,first.y+0.87,first.x),Vector3(walkside,first.y+0.87,first.x),
		Vector3(walkside,last.y+0.87,last.x),Vector3(INNER,last.y+0.87,last.x)],0.020,GALVANISED,8)
	for u: float in [0.25,0.65]:
		var point := low.lerp(high,u)
		kit.block("metal",Transform3D(Basis.IDENTITY,Vector3(INNER+0.045,point.y+0.85,point.x)),Vector3(0.09,0.025,0.027),FRAME)

static func _landing(house: Node3D, kit: Kit, label: String, start_z: float, end_z: float, y: float) -> void:
	var start := Vector2(start_z,y)
	var end := Vector2(end_z,y)
	_deck(house,kit,label+"Landing",start,end,0.105)
	_guard(house,kit,label,start,end)
	# Fixed to the masonry, a pair of gusseted supports carry each landing. The
	# bays underneath remain open; the residential doors are above the brackets.
	for z: float in [start_z-0.14,end_z+0.14]:
		kit.block("metal",Transform3D(Basis.IDENTITY,Vector3(MID,y-0.15,z)),Vector3(WIDTH,0.12,0.065),FRAME)
		kit.beam("metal",Vector3(INNER+0.025,y-0.74,z),Vector3(OUTER-0.10,y-0.17,z),0.055,0.072,Vector3.UP,FRAME)
		kit.block("metal",Transform3D(Basis.IDENTITY,Vector3(INNER+0.018,y-0.64,z)),Vector3(0.036,0.28,0.11),GALVANISED)

static func _deck(house: Node3D, kit: Kit, label: String, low: Vector2, high: Vector2, thickness: float) -> void:
	var pitch := Basis(Vector3.RIGHT,atan2(high.y-low.y,low.x-high.x))
	var centre := Vector3(MID,(low.y+high.y)*0.5,(low.x+high.x)*0.5) - pitch.y*thickness*0.5
	var size := Vector3(WIDTH,thickness,low.distance_to(high))
	kit.block("metal",Transform3D(pitch,centre),size,FLOOR,0.82,1.0)
	house.apartment_solid(label,centre,size,pitch)

static func _guard(house: Node3D, kit: Kit, label: String, start: Vector2, end: Vector2) -> void:
	var start_p := Vector3(RAIL_X,start.y,start.x)
	var end_p := Vector3(RAIL_X,end.y,end.x)
	for height: float in [0.45,1.02]:
		kit.tube("metal",[start_p + Vector3.UP*height,end_p + Vector3.UP*height],0.023,GALVANISED,8)
	var bays := maxi(1,ceili(absf(start.x-end.x)/0.88))
	for index: int in range(bays):
		var foot := start_p.lerp(end_p,float(index)/bays)
		kit.block("metal",Transform3D(Basis.IDENTITY,foot+Vector3.UP*0.50),Vector3(0.035,1.02,0.035),FRAME)
		kit.block("metal",Transform3D(Basis.IDENTITY,foot+Vector3.UP*0.052),Vector3(0.07,0.10,0.078),GALVANISED)
	# A thin continuous barrier at the outside rail prevents the capsule slipping
	# between posts. Rotating this box around X leaves the full clear width intact.
	var pitch := Basis(Vector3.RIGHT,atan2(end.y-start.y,start.x-end.x))
	var centre := (start_p+end_p)*0.5 + Vector3.UP*0.50
	house.apartment_solid(label+"OutsideGuard",centre,Vector3(0.050,pitch.y.y,start.distance_to(end)),pitch)
