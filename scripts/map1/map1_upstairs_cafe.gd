extends RefCounted
## One coffee shop by S6. Use the surveyed parcel centre so a regenerated box index
## cannot turn a different house into the café.
const Kit := preload("res://scripts/interior_kit/house_kit.gd")
const ADDRESS := Vector2(175.07, 503.43)
const FLOOR := Kit.FLOOR_ABOVE_GROUND + Kit.CEILING_HEIGHT + Kit.FLOOR_BUILD_UP
const WALNUT := Color("#684331")
const GREEN := Color("#355b52")
const BRASS := Color("#b48451")
const CERAMIC := Color("#ede4cc")

static func fits(c: Dictionary) -> bool:
	if c.business.what != "coffee shop" or c.floors != 2 or c.layout.plan != "side_right":
		return false
	var box: Array = c.world.boxes[c.index]
	return ADDRESS.distance_to(Vector2(box[0],box[2])) < 0.15

static func fit_out(c: Dictionary) -> void:
	var counter_window: Dictionary = {}
	for w: Dictionary in c.windows:
		if w.floor == 1 and w.wall == "front" and str(w.name).begins_with("west"):
			counter_window = w
			break
	if counter_window.is_empty(): return
	var x := float(counter_window.at)
	var span := float(counter_window.width)
	c.features["business"] = "coffee shop"
	c.features["shop_front"] = ["2F stair directory", "window counter upstairs"]
	c.features["cafe_floor"] = 2
	var door_x := float(c.layout.door_x)
	# A board above the entry, a directory at hand height, and a blade visible along the street.
	panel(c,Vector3(door_x,2.31,-0.30),Vector3(1.72,0.25,0.09),GREEN)
	letter(c,"2F  喫茶",Vector3(door_x,2.31,-0.35),PI,1.46,0.20)
	panel(c,Vector3(door_x+0.78,1.52,-0.08),Vector3(0.43,0.72,0.09),GREEN)
	letter(c,"2F\n喫茶\n↑",Vector3(door_x+0.78,1.52,-0.13),PI,0.33,0.61)
	var blade := Vector3(0.22,FLOOR+0.57,-0.46)
	panel(c,blade,Vector3(0.10,0.81,0.87),GREEN)
	for side: int in [-1,1]:
		letter(c,"喫茶\n2F",blade+Vector3.RIGHT*0.056*side,side*PI*0.5,0.64,0.61)
	# Distinguish the ordinary ground floor shop. The shared stair hall has its own entry.
	panel(c,Vector3(1.87,2.31,-0.30),Vector3(2.55,0.25,0.09),WALNUT)
	letter(c,"日用品",Vector3(1.87,2.31,-0.35),PI,2.15,0.20)
	panel(c,Vector3(x,FLOOR+0.78,0.43),Vector3(span+0.22,0.075,0.51),WALNUT,true)
	for side: int in [-1,1]:
		panel(c,Vector3(x+side*(span*0.5-0.11),FLOOR+0.37,0.44),Vector3(0.07,0.74,0.43),WALNUT,true)
	for n: int in 4:
		var seat_x := x+(float(n)-1.5)*0.63
		drum(c,Vector3(seat_x,FLOOR+0.49,0.96),0.19,0.085,GREEN)
		panel(c,Vector3(seat_x,FLOOR+0.24,0.96),Vector3(0.115,0.48,0.115),BRASS,true)
		# A small hidden collision box inside each round cushion.
		panel(c,Vector3(seat_x,FLOOR+0.48,0.96),Vector3(0.25,0.055,0.25),GREEN,true)
		if n%2==0:
			drum(c,Vector3(seat_x,FLOOR+0.87,0.46),0.047,0.095,CERAMIC)
	for n: int in [-1,1]:
		var light_x := x+float(n)*0.74
		panel(c,Vector3(light_x,FLOOR+2.13,0.60),Vector3(0.018,0.48,0.018),WALNUT)
		drum(c,Vector3(light_x,FLOOR+1.89,0.60),0.13,0.10,BRASS)
		drum(c,Vector3(light_x,FLOOR+1.83,0.60),0.115,0.022,Color("#ffe5aa"))
	# The service counter runs along the far wall, leaving the aisle to the stair door clear.
	panel(c,Vector3(1.24,FLOOR+0.49,4.54),Vector3(1.9,0.98,0.57),GREEN,true)
	panel(c,Vector3(1.24,FLOOR+1.00,4.54),Vector3(2.04,0.065,0.69),WALNUT)
	panel(c,Vector3(0.86,FLOOR+1.19,4.52),Vector3(0.39,0.32,0.31),BRASS)
	for n: int in 3:
		drum(c,Vector3(1.4+n*0.17,FLOOR+1.09,4.53),0.048,0.11,CERAMIC)
	letter(c,"喫茶  /  COFFEE",Vector3(1.24,FLOOR+0.72,4.245),PI,1.30,0.18)

static func panel(c: Dictionary, at: Vector3, size: Vector3, tint: Color, solid := false) -> void:
	c.blocks.append([at,size,tint,solid,0.0])

static func drum(c: Dictionary, at: Vector3, radius: float, height: float, tint: Color) -> void:
	c.drums.append([at,radius,height,16,tint])

static func letter(c: Dictionary, words: String, at: Vector3, yaw: float, width: float, height: float) -> void:
	c.signs.append([words,at,yaw,width,height,CERAMIC])
