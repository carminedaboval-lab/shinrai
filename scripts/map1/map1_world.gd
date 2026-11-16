extends Node3D
## Makes the Map 1 grey blockout a world you can go into (scripts/map1/map1_blockout.gd owns
## the boxes; this decides what stands in for each low open building, and builds the robot
## recharge stations).
##
## A low open town building (a house, timber house or shop-house of one or two floors, not
## shut: about 2,160 of them) is always one of three things:
##   BOX   the blockout's grey box.
##   LOOK  the house as it is seen, and nothing else: one mesh for walls, floors, stair, roof,
##         frames and closed doors, one for the glass (HouseKit.build_look). The box's
##         collision stays, so it is solid and costs no physics of its own.
##   FULL  the kit house: doors that open, glass that breaks, a stair to climb.
## LOOK and FULL are the same picture, face for face, as long as nobody has opened or broken
## anything, so one may be changed for the other at any moment, in plain view. Only the
## change between BOX and a house can be seen, and it is only made when it cannot be:
##
##   1. OUT OF VIEW   the building and the shadow it throws are outside the camera's view
##                    (with VIEW_MARGIN to spare), or
##   2. HIDDEN        the building is in front of the camera but behind other things: no ray
##                    from the eye to its corners, roof edges, wall middles or the tip of its
##                    shadow gets there, and it is at least HIDDEN_MIN away, or
##   3. FROM HEIGHT   the eye is HIGH_EYE or more above the ground (a rooftop, flying): from
##                    there little is hidden, so everything in view is to be a house already;
##                    a building at least HIGH_FAR away may change in view, or
##   4. A CUT         the viewer was just put somewhere else (the start, a jump to a place):
##                    the whole picture is new. It is cut to black and shown again when the
##                    houses near and in sight are made, a frame's share at a time (_cover), or
##   5. FAR           the building is FAR_SWAP or more away: further than the eye tells a box
##                    from a house. The ring of houses reaches past that all round, and down a
##                    long open view further still (VIEW_REACH), so a building is a house
##                    before it is near enough to be told from a box, whichever way it comes
##                    into view.
##
## Which are what:
##   LOOK  every low open building within LOOK_RADIUS of the viewer, nearest first, at most
##         LOOK_BUDGET; it goes back to a BOX past DROP_RADIUS.
##   FULL  the houses that front the street the player is standing on, FULL_ALONG metres up
##         and down it on both sides, nearest first, at most FULL_BUDGET; and the house the
##         player is in or at the door of. "Fronts the street" is worked out from the house:
##         its door faces an open strip (HouseRules gives a point in that strip and the way
##         it runs); the player is on that street when he stands within STREET_HALF of that
##         line, within FULL_ALONG along it, and the ground between him and that point is
##         open (no building in the way).
## Moving faster than FAST_SPEED (flying with Shift) builds no FULL houses.

const HouseRules := preload("res://scripts/map1/map1_house_rules.gd")
const HouseKit := preload("res://scripts/interior_kit/house_kit.gd")
const Station := preload("res://scripts/robots/station.gd")

enum Level { BOX, LOOK, FULL }
enum Why { CUT, OUT_OF_VIEW, HIDDEN, FROM_HEIGHT, SAME_PICTURE, FAR }

const LOOK_RADIUS := 250.0
const DROP_RADIUS := 290.0
const LOOK_BUDGET := 520
## Further than this the eye does not tell a grey box from a house (a two-floor house is
## under 1.8 degrees tall: about 20 of a screen's 1080 lines): a building that far off may
## change in open view. It is less than LOOK_RADIUS, so whatever comes into the ring in open
## view changes at once, at the ring's edge, and nothing nearer is ever left a box.
const FAR_SWAP := 230.0
## Down a long open view (a straight street, a square, the park's edge) the ring reaches
## this far along the way the camera looks, so that the change is made further off still.
const VIEW_REACH := 420.0
const VIEW_KEEP := 470.0
## After a cut the picture is black until everything within this distance is a house, and
## everything in the ring that is in open sight. The work is spread over frames.
const COVER_NEAR := 150.0
const COVER_USEC := 11000
const FADE_SECONDS := 0.3
## An ordinary frame makes houses ready until this much time is spent.
const WORK_USEC := 4500
const FULL_ALONG := 60.0
const STREET_HALF := 9.0
const FULL_BUDGET := 24
## A house stays FULL a little past where it would become one, so it does not flicker.
const KEEP_ALONG := 75.0
const KEEP_HALF := 14.0
const AT_DOOR := 4.0
## A house somebody opened or broke something in is kept FULL this far, then put back out of sight.
const TOUCHED_KEEP := 120.0
const HIDDEN_MIN := 20.0
const HIGH_EYE := 6.0
const HIGH_FAR := 60.0
const VIEW_MARGIN := deg_to_rad(6.0)
## Nearer than this you can see through a house's windows to what is behind it: a house that
## close does not hide anything.
const SEE_THROUGH := 25.0
const CUT_STEP := 6.0
const FAST_SPEED := 25.0
## Work in one frame. Only one costly thing is done in a frame: a full house, or else a
## plan, or else a look.
const LOOKS_PER_FRAME := 3
const TESTS_PER_FRAME := 8
const FULL_PER_FRAME := 1
const REFRESH_SECONDS := 0.25
const STATION_KINDS: Array[String] = ["charger", "charger_light", "robot"]
const ROAD_COLOURS: Array[Color] = [Color8(88, 88, 90), Color8(74, 74, 76), Color8(60, 60, 62), Color8(96, 94, 92), Color8(108, 102, 90), Color8(98, 92, 80), Color8(112, 104, 88), Color8(150, 150, 148)]

## Sent just before a building changes what it is, while the old one still stands.
signal changing(index: int, from: int, to: int, why: int)

var map: Node3D
var boxes: Array = []
var visuals := true
var viewer: Node3D
var walker: Node3D
## Every low open building, by its place in the blockout's list of boxes.
var candidates := PackedInt32Array()
var stations: Array[Node3D] = []
## The trade in a box, for the boxes the map plan names a business in (data.businesses):
## box index -> {type: "restaurant" or "corner shop", what: the trade}.
var businesses: Dictionary = {}
var levels: Dictionary = {}
var looks: Dictionary = {}
var houses: Dictionary = {}
var sites: Dictionary = {}
var want_look: Array[int] = []
var _want_look_set: Dictionary = {}
var want_full: Array[int] = []
var keep_full: Dictionary = {}
var high := false
var fast := false
## True while the picture is black after a cut and the first houses are being made.
var covered := false
var fade := 0.0
## Counters a test reads.
var stats := {"cut_frames": 0, "cut_worst_usec": 0, "cut_looks": 0, "frames": 0, "worst_usec": 0, "worst_what": "", "looks_built": 0, "fulls_built": 0, "cuts": 0, "cut_usec": 0, "tests": 0, "worst_look_usec": 0, "worst_plan_usec": 0, "look_usec": 0, "plan_usec": 0, "full_usec": 0, "work_usec": 0, "worst_full_usec": 0, "worst_refresh_usec": 0}

var _kinds: PackedStringArray = []
var _locked: Dictionary = {}
var _grid: Dictionary = {}
var _near_grid: Dictionary = {}
var _cx := PackedFloat32Array()
var _cz := PackedFloat32Array()
var _hw := PackedFloat32Array()
var _hd := PackedFloat32Array()
var _cos := PackedFloat32Array()
var _sin := PackedFloat32Array()
var _roads: Dictionary = {}
var _image: Image
var _points: Dictionary = {}
var _shadow := Vector3.ZERO
var _last_eye := Vector3.INF
var _refresh_at := Vector3.INF
var _refresh_clock := 0.0
var _cut_asked := true
var _half_cone := 1.0
var _eye := Vector3.ZERO
var _forward := Vector3.FORWARD
var _feet := Vector3.ZERO
var _query: PhysicsRayQueryParameters3D
var _cover_phase := 0
var _cover_at := 0
var _cover_list: Array[int] = []
var _shade: ColorRect


func setup(blockout: Node3D) -> void:
	map = blockout
	boxes = map.data.boxes
	_image = map.ground_image
	for colour: Color in ROAD_COLOURS: _roads[colour.to_rgba32()] = true
	var kinds: Array = map.data.kinds
	_kinds.resize(boxes.size())
	_cx.resize(boxes.size())
	_cz.resize(boxes.size())
	_hw.resize(boxes.size())
	_hd.resize(boxes.size())
	_cos.resize(boxes.size())
	_sin.resize(boxes.size())
	for index: int in boxes.size():
		var box: Array = boxes[index]
		var kind: String = kinds[int(box[7])]
		_kinds[index] = kind
		var turn := deg_to_rad(float(box[6]))
		_cx[index] = float(box[0])
		_cz[index] = float(box[2])
		_hw[index] = float(box[3]) * 0.5
		_hd[index] = float(box[5]) * 0.5
		_cos[index] = cos(turn)
		_sin[index] = sin(turn)
		# What stands in a door's way: every box but the road decks overhead and the station
		# boxes this file replaces.
		if kind != "deck" and not STATION_KINDS.has(kind):
			var reach := Vector2(_hw[index], _hd[index]).length()
			for gx: int in range(floori((_cx[index] - reach) / 16.0), floori((_cx[index] + reach) / 16.0) + 1):
				for gz: int in range(floori((_cz[index] - reach) / 16.0), floori((_cz[index] + reach) / 16.0) + 1):
					var cell := Vector2i(gx, gz)
					if not _grid.has(cell): _grid[cell] = []
					(_grid[cell] as Array).append(index)
		if HouseRules.is_low_open(kind, box):
			candidates.append(index)
			var cell := Vector2i(floori(_cx[index] / 40.0), floori(_cz[index] / 40.0))
			if not _near_grid.has(cell): _near_grid[cell] = []
			(_near_grid[cell] as Array).append(index)
	var by_place := {}
	for index: int in candidates: by_place[Vector2i(roundi(_cx[index] * 100.0), roundi(_cz[index] * 100.0))] = index
	for entry: Array in map.data.get("encounters", {}).get("locked_doors", []):
		var key := Vector2i(roundi(float(entry[0]) * 100.0), roundi(float(entry[1]) * 100.0))
		if by_place.has(key): _locked[by_place[key]] = str(entry[2])
	# The restaurants and corner shops the plan names, by the box each is in.
	for entry: Dictionary in map.data.get("businesses", []):
		var box_index := int(entry.get("box", -1))
		if box_index >= 0 and box_index < boxes.size(): businesses[box_index] = {"type": str(entry.get("type", "")), "what": str(entry.get("what", ""))}
	# (The letters of their signs are cut now, once, not when the first shop comes near.)
	if not businesses.is_empty(): HouseRules.Dress.cut_words()
	var sun := map.get_node_or_null("Sun") as Node3D
	if sun != null:
		var light: Vector3 = -sun.global_basis.z
		if light.y < -0.05: _shadow = Vector3(light.x, 0.0, light.z) / -light.y
	_build_stations()
	# The black the picture is cut to while the first houses are made.
	if visuals and DisplayServer.get_name() != "headless":
		var layer := CanvasLayer.new()
		layer.name = "CutShade"
		layer.layer = 90
		add_child(layer)
		_shade = ColorRect.new()
		_shade.color = Color(0, 0, 0, 1)
		_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shade.visible = false
		layer.add_child(_shade)


## The camera the world is seen through, and the body that walks in it (may be the same node,
## or null for a camera with no body).
func set_viewer(camera: Node3D, body: Node3D = null) -> void:
	viewer = camera
	walker = body
	_cut_asked = true
	covered = true
	fade = 1.0


## Say so when the viewer has been put somewhere else: the next frame is a new picture.
func cut() -> void:
	_cut_asked = true
	covered = true
	fade = 1.0


# ---- what the house rules ask ------------------------------------------------------------

func kind_of(index: int) -> String:
	return _kinds[index]


func ground(x: float, z: float) -> float:
	return map.ground_height(x, z)


## A house's place among the low open buildings of its own 40 m square of the map, and that
## square's place in a 2 by 2 pattern: neighbours get different numbers.
func cell_rank(index: int) -> int:
	var cell := Vector2i(floori(_cx[index] / 40.0), floori(_cz[index] / 40.0))
	return maxi((_near_grid.get(cell, []) as Array).find(index), 0) + posmod(cell.x, 2) * 3 + posmod(cell.y, 2) * 5


func has_locked_room(index: int) -> bool:
	return _locked.has(index)


## The business the map plan names in this box ({type, what}), or {} for none.
func business_of(index: int) -> Dictionary:
	return businesses.get(index, {})


## True when the point is inside some other building's outline.
func solid_at(x: float, z: float, skip: int = -1) -> bool:
	var cell := Vector2i(floori(x / 16.0), floori(z / 16.0))
	if not _grid.has(cell): return false
	for index: int in (_grid[cell] as Array):
		if index == skip: continue
		var dx := x - _cx[index]
		var dz := z - _cz[index]
		if absf(dx * _cos[index] - dz * _sin[index]) <= _hw[index] and absf(dx * _sin[index] + dz * _cos[index]) <= _hd[index]: return true
	return false


## True when the ground picture shows a road, a lane or a pavement there.
func road_at(x: float, z: float) -> bool:
	if _image == null: return false
	var px := int(x - map.frame.position.x)
	var pz := int(z - map.frame.position.y)
	if px < 0 or pz < 0 or px >= _image.get_width() or pz >= _image.get_height(): return false
	var colour := _image.get_pixel(px, pz)
	return _roads.has(Color8(colour.r8, colour.g8, colour.b8).to_rgba32())


## The plan for one building (worked out once, then kept).
func site(index: int) -> Dictionary:
	if not sites.has(index): sites[index] = HouseRules.plan(self, index)
	return sites[index]


func level_of(index: int) -> int:
	return int(levels.get(index, Level.BOX))


func count(level: int) -> int:
	if level == Level.FULL: return houses.size()
	var total := 0
	for index: int in levels:
		if int(levels[index]) == level: total += 1
	return total


func centre_of(index: int) -> Vector3:
	var box: Array = boxes[index]
	return Vector3(float(box[0]), float(box[1]) + float(box[4]) * 0.5, float(box[2]))


## How far a point on the ground is outside a building's outline (0 inside it).
func outline_gap(index: int, point: Vector3) -> float:
	var dx := point.x - _cx[index]
	var dz := point.z - _cz[index]
	return Vector2(maxf(absf(dx * _cos[index] - dz * _sin[index]) - _hw[index], 0.0), maxf(absf(dx * _sin[index] + dz * _cos[index]) - _hd[index], 0.0)).length()


## Is somebody standing at `point` on the street this house fronts?
func fronts_street_of(index: int, point: Vector3, along: float = FULL_ALONG, half: float = STREET_HALF) -> bool:
	var plan := site(index)
	if not bool(plan.ok): return false
	var street: Vector3 = plan.street_point
	var offset := Vector3(point.x - street.x, 0.0, point.z - street.z)
	if absf(offset.dot(plan.street_out)) > half or absf(offset.dot(plan.street_along)) > along: return false
	# The strip between them must be open ground.
	var length := offset.length()
	var steps := ceili(length / 1.5)
	for step: int in range(1, steps):
		var at := street + offset * (float(step) / float(steps))
		if solid_at(at.x, at.z, index): return false
	return true


# ---- every frame -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if map == null or not is_instance_valid(viewer) or not viewer.is_inside_tree(): return
	var started := Time.get_ticks_usec()
	_eye = viewer.global_position
	_forward = -viewer.global_basis.z
	_feet = walker.global_position if is_instance_valid(walker) else Vector3(_eye.x, ground(_eye.x, _eye.z), _eye.z)
	var above := _eye.y - ground(_eye.x, _eye.z)
	high = above >= HIGH_EYE
	var moved := _eye.distance_to(_last_eye) if _last_eye.is_finite() else INF
	var is_cut := _cut_asked or moved > CUT_STEP
	fast = not is_cut and moved / maxf(delta, 0.0001) > FAST_SPEED
	_last_eye = _eye
	_cut_asked = false
	_half_cone = _cone()
	_refresh_clock -= delta
	if is_cut:
		# A new picture: black at once, and the houses made behind it, nearest first.
		covered = true
		fade = 1.0
		_cover_phase = 0
		stats.cuts += 1
		stats.cut_usec = 0
		stats.cut_frames = 0
		stats.cut_worst_usec = 0
		stats.cut_looks = 0
	if is_cut or (not covered and (_refresh_clock <= 0.0 or _feet.distance_to(_refresh_at) > 2.0)):
		_refresh()
		if not is_cut: stats.worst_refresh_usec = maxi(int(stats.worst_refresh_usec), Time.get_ticks_usec() - started)
	if not covered and fade > 0.0: fade = maxf(fade - delta / FADE_SECONDS, 0.0)
	if _shade != null:
		_shade.visible = fade > 0.0
		_shade.color.a = fade
	var what := ""
	if covered:
		_cover(started)
		var spent := Time.get_ticks_usec() - started
		stats.cut_usec += spent
		stats.cut_frames += 1
		stats.cut_worst_usec = maxi(int(stats.cut_worst_usec), spent)
	else:
		what = _work(started)
		stats.frames += 1
		var took := Time.get_ticks_usec() - started
		stats.work_usec += took
		if took > int(stats.worst_usec):
			stats.worst_usec = took
			stats.worst_what = what


## Half the angle of the cone the camera sees, corner to corner, with the margin.
func _cone() -> float:
	var camera := viewer as Camera3D
	var fov := 75.0
	var aspect := 16.0 / 9.0
	if camera != null:
		fov = maxf(camera.fov, 75.0)
		var size: Vector2 = camera.get_viewport().get_visible_rect().size
		if size.y > 1.0: aspect = maxf(aspect, size.x / size.y)
	var up := tan(deg_to_rad(fov) * 0.5)
	return atan(up * sqrt(1.0 + aspect * aspect)) + VIEW_MARGIN


func _refresh() -> void:
	_refresh_clock = REFRESH_SECONDS
	_refresh_at = _feet
	var near: Array[Vector2] = []
	var reach := ceili(LOOK_RADIUS / 40.0)
	var middle := Vector2i(floori(_eye.x / 40.0), floori(_eye.z / 40.0))
	for gx: int in range(middle.x - reach, middle.x + reach + 1):
		for gz: int in range(middle.y - reach, middle.y + reach + 1):
			var cell := Vector2i(gx, gz)
			if not _near_grid.has(cell): continue
			for index: int in (_near_grid[cell] as Array):
				var gap := Vector2(_cx[index] - _eye.x, _cz[index] - _eye.z).length()
				if gap <= LOOK_RADIUS and not (sites.has(index) and not bool(sites[index].ok)): near.append(Vector2(gap, index))
	near.sort()
	want_look.clear()
	_want_look_set.clear()
	for entry: Vector2 in near:
		if want_look.size() >= LOOK_BUDGET: break
		want_look.append(int(entry.y))
		_want_look_set[int(entry.y)] = true
	# Down an open view the ring reaches further: walk out along the way the camera looks,
	# and a little to either side, until a building stands in the way.
	var ahead := Vector3(_forward.x, 0.0, _forward.z)
	if ahead.length() > 0.2:
		ahead = ahead.normalized()
		var far: Array[Vector2] = []
		var seen := {}
		for swing: float in [0.0, -0.2, 0.2, -0.45, 0.45]:
			var way := ahead.rotated(Vector3.UP, swing)
			var out := 24.0
			while out <= VIEW_REACH:
				var at := _eye + way * out
				if solid_at(at.x, at.z) and _eye.y < ground(at.x, at.z) + 12.0: break
				if out >= LOOK_RADIUS - 40.0:
					var home := Vector2i(floori(at.x / 40.0), floori(at.z / 40.0))
					for gx: int in range(home.x - 1, home.x + 2):
						for gz: int in range(home.y - 1, home.y + 2):
							for index: int in (_near_grid.get(Vector2i(gx, gz), []) as Array):
								if seen.has(index) or _want_look_set.has(index) or (sites.has(index) and not bool(sites[index].ok)): continue
								seen[index] = true
								var gap := Vector2(_cx[index] - _eye.x, _cz[index] - _eye.z).length()
								if gap > LOOK_RADIUS and gap <= VIEW_REACH and Vector2(_cx[index] - at.x, _cz[index] - at.z).length() <= 46.0: far.append(Vector2(gap, index))
				out += 8.0
		far.sort()
		for entry: Vector2 in far:
			if want_look.size() >= LOOK_BUDGET: break
			want_look.append(int(entry.y))
			_want_look_set[int(entry.y)] = true
	# The player's street. From up high he is on no street: only a house he is in counts.
	want_full.clear()
	keep_full.clear()
	for entry: Vector2 in near:
		if entry.x > KEEP_ALONG + 20.0: break
		var index := int(entry.y)
		if not sites.has(index): continue
		var at_door := outline_gap(index, _feet) <= AT_DOOR and _feet.y < float(boxes[index][1]) + float(boxes[index][4])
		if at_door or (not high and fronts_street_of(index, _feet)):
			if want_full.size() < FULL_BUDGET: want_full.append(index)
			keep_full[index] = true
		elif houses.has(index) and (outline_gap(index, _feet) <= AT_DOOR * 2.0 or (not high and fronts_street_of(index, _feet, KEEP_ALONG, KEEP_HALF))):
			keep_full[index] = true


## After a cut, behind the black: one frame's share of putting the picture right. Nearest
## first: every house within COVER_NEAR; then the insides of the player's street; then
## whatever else in the ring is in open sight from here, whichever way he turns. The rest of
## the ring is hidden or far and follows by the ordinary rules. Nothing is built in one go:
## each frame stops when COVER_USEC is spent, so the game keeps answering.
func _cover(started: int) -> void:
	if _cover_phase == 0:
		_cover_list = want_look.duplicate()
		_cover_at = 0
		_cover_phase = 1
	while Time.get_ticks_usec() - started < COVER_USEC:
		match _cover_phase:
			1, 3:
				if _cover_at >= _cover_list.size() or (_cover_phase == 1 and _flat_gap(_cover_list[_cover_at]) > COVER_NEAR):
					if _cover_phase == 1:
						# The street may only be known now that the plans exist.
						_refresh()
						_cover_phase = 2
					else: _cover_phase = 4
					continue
				var index: int = _cover_list[_cover_at]
				_cover_at += 1
				if level_of(index) != Level.BOX or (looks.size() >= LOOK_BUDGET and not looks.has(index)): continue
				if _cover_phase == 3 and _flat_gap(index) < VIEW_KEEP and not looks.has(index) and _hidden(index): continue
				if _prepare(index):
					_to_look(index, Why.CUT)
					stats.cut_looks += 1
			2:
				var made := false
				for index: int in want_full:
					if level_of(index) == Level.BOX and _prepare(index): _to_look(index, Why.CUT)
					if level_of(index) == Level.LOOK and houses.size() < FULL_BUDGET:
						_to_full(index)
						made = true
						break
				if not made: _cover_phase = 3
			_:
				for index: int in levels.keys():
					var level := int(levels[index])
					if level == Level.FULL and not keep_full.has(index) and not _standing_at(index): _to_look(index, Why.CUT)
					if int(levels.get(index, Level.BOX)) == Level.LOOK and not _want_look_set.has(index) and _flat_gap(index) > DROP_RADIUS: _to_box(index, Why.CUT)
				covered = false
				return


## One frame's share of the work. Returns what the costly part was.
func _work(started: int) -> String:
	var what := ""
	# One costly thing a frame: a full house for the player's street if one is due, or else
	# the next plan, or else the next look.
	var full_due := false
	if not fast:
		for index: int in want_full:
			if level_of(index) == Level.LOOK:
				full_due = true
				break
	# 1. Get houses ready (their plan, then their look), nearest first. Nothing changes yet.
	var built := 0
	if not full_due:
		for index: int in want_look:
			if looks.has(index) or (sites.has(index) and not bool(sites[index].ok)): continue
			if looks.size() >= LOOK_BUDGET: break
			var look_started := Time.get_ticks_usec()
			if not sites.has(index):
				# A cached look already used this update's construction slot.
				if built > 0: break
				site(index)
				var plan_usec := Time.get_ticks_usec() - look_started
				stats.plan_usec += plan_usec
				stats.worst_plan_usec = maxi(int(stats.worst_plan_usec), plan_usec)
				what = "plan"
				# Valid and invalid plans are cached. Prepare or skip next update.
				break
			_prepare(index)
			stats.worst_look_usec = maxi(int(stats.worst_look_usec), Time.get_ticks_usec() - look_started)
			built += 1
			what = "look"
			if built >= LOOKS_PER_FRAME or Time.get_ticks_usec() - started > WORK_USEC: break
	# 2. Boxes whose house is ready: change them when it cannot be seen.
	var tests := 0
	for index: int in want_look:
		if not looks.has(index) or level_of(index) != Level.BOX: continue
		var why := _may_change(index, tests < TESTS_PER_FRAME)
		if why == Why.HIDDEN or why == -2: tests += 1
		if why >= 0: _to_look(index, why)
	stats.tests += tests
	# 3. The player's street: insides, one house a frame.
	# Phase 2 may have activated a ready LOOK; don't build its FULL beside a fresh plan.
	if not fast and what != "plan":
		var made := 0
		for index: int in want_full:
			if made >= FULL_PER_FRAME: break
			if level_of(index) != Level.LOOK: continue
			if houses.size() >= FULL_BUDGET and not _make_room(): break
			var full_started := Time.get_ticks_usec()
			_to_full(index)
			stats.worst_full_usec = maxi(int(stats.worst_full_usec), Time.get_ticks_usec() - full_started)
			made += 1
			what = "full"
	# 4. Houses no longer on the player's street go back to their look.
	var back := 0
	for index: int in houses.keys():
		if back >= 2: break
		if keep_full.has(index) or _standing_at(index): continue
		if _untouched(index):
			_to_look(index, Why.SAME_PICTURE)
			back += 1
		elif _flat_gap(index) > TOUCHED_KEEP:
			var why := _may_change(index, true)
			if why >= 0:
				_to_look(index, why)
				back += 1
	# 5. Far behind: back to a grey box.
	var dropped := 0
	var crowded := looks.size() > LOOK_BUDGET - 24
	for index: int in looks.keys():
		if dropped >= 4: break
		if _want_look_set.has(index) or level_of(index) == Level.FULL: continue
		# (One made for a long view is kept while it is within that view's reach.)
		if _flat_gap(index) <= (VIEW_KEEP if _in_cone(centre_of(index), 12.0) else DROP_RADIUS) and not crowded: continue
		if level_of(index) == Level.BOX:
			# Made ready but never shown: nothing to see go.
			(looks[index] as Node3D).queue_free()
			looks.erase(index)
			continue
		var why := _may_change(index, tests < TESTS_PER_FRAME)
		if why == Why.HIDDEN or why == -2: tests += 1
		if why >= 0:
			_to_box(index, why)
			dropped += 1
	return what


## Frees one full house that the player's street no longer needs. False if there is none.
func _make_room() -> bool:
	var farthest := -1
	var gap := -1.0
	for index: int in houses:
		if want_full.has(index) or _standing_at(index) or not _untouched(index): continue
		if _flat_gap(index) > gap:
			gap = _flat_gap(index)
			farthest = index
	if farthest < 0: return false
	_to_look(farthest, Why.SAME_PICTURE)
	return true


func _flat_gap(index: int) -> float:
	return Vector2(_cx[index] - _eye.x, _cz[index] - _eye.z).length()


func _standing_at(index: int) -> bool:
	return outline_gap(index, _feet) <= 2.0


## Nothing opened, nothing unlocked, no glass broken: the house looks as its look does.
func _untouched(index: int) -> bool:
	var house: Node3D = houses.get(index)
	if house == null: return true
	for label: String in house.doors:
		var door: Node3D = house.doors[label]
		if door.opened or door.moving or door.forced or door.opened_with != "": return false
	for label: String in house.windows:
		if int(house.windows[label].glass) != 0: return false
	return true


# ---- can the change be seen? -------------------------------------------------------------

## Why a building may change between a box and a house right now, or -1 (it would be seen),
## or -2 (it would be seen, and rays were cast to find that out). `with_rays` false skips the
## hidden test.
func _may_change(index: int, with_rays: bool) -> int:
	if outline_gap(index, _feet) <= 1.5: return -1
	var box: Array = boxes[index]
	var centre := centre_of(index)
	var radius := Vector3(_hw[index], float(box[4]) * 0.5, _hd[index]).length() + 1.3
	# The shadow it throws is part of what would change.
	var throw: Vector3 = _shadow * float(box[4])
	if not _in_cone(centre + throw * 0.5, radius + throw.length() * 0.5): return Why.OUT_OF_VIEW
	var gap := centre.distance_to(_eye)
	if high and gap >= HIGH_FAR: return Why.FROM_HEIGHT
	if _flat_gap(index) >= FAR_SWAP: return Why.FAR
	if gap < HIDDEN_MIN or not with_rays: return -1
	return Why.HIDDEN if _hidden(index) else -2


func _in_cone(centre: Vector3, radius: float) -> bool:
	var offset := centre - _eye
	var gap := offset.length()
	if gap <= radius: return true
	return _forward.angle_to(offset) - asin(radius / gap) <= _half_cone


## The points a building is looked for at: its corners at the ground and at the roof, the
## middle of each roof edge and each wall, the top, and where the shadow of its roof falls.
func look_points(index: int) -> PackedVector3Array:
	if _points.has(index): return _points[index]
	var box: Array = boxes[index]
	var turn := Basis(Vector3.UP, deg_to_rad(float(box[6])))
	var base := float(box[1])
	var top := base + float(box[4])
	var middle := Vector3(_cx[index], 0.0, _cz[index])
	var points := PackedVector3Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var wide: Vector3 = middle + turn * Vector3(corner.x * (_hw[index] + 1.3), 0.0, corner.y * (_hd[index] + 1.3))
		points.append(Vector3(wide.x, ground(wide.x, wide.z) + 0.15, wide.z))
		var roof: Vector3 = middle + turn * Vector3(corner.x * (_hw[index] + 0.5), 0.0, corner.y * (_hd[index] + 0.5))
		points.append(Vector3(roof.x, top, roof.z))
		var fallen: Vector3 = roof + _shadow * (top - ground(roof.x, roof.z))
		points.append(Vector3(fallen.x, ground(fallen.x, fallen.z) + 0.15, fallen.z))
	for edge: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		var out: Vector3 = middle + turn * Vector3(edge.x * (_hw[index] + 0.5), 0.0, edge.y * (_hd[index] + 0.5))
		points.append(Vector3(out.x, top, out.z))
		points.append(Vector3(out.x, (base + top) * 0.5 + 0.5, out.z))
	points.append(Vector3(middle.x, top + 0.1, middle.z))
	_points[index] = points
	return points


func _hidden(index: int) -> bool:
	var space := get_world_3d().direct_space_state
	if _query == null:
		_query = PhysicsRayQueryParameters3D.new()
		_query.collision_mask = 1
	_query.exclude = [(walker as CollisionObject3D).get_rid()] if walker is CollisionObject3D else []
	_query.from = _eye
	for point: Vector3 in look_points(index):
		_query.to = point
		var hit := space.intersect_ray(_query)
		if hit.is_empty(): return false
		var at: Vector3 = hit.position
		if at.distance_to(point) < 0.9 or outline_gap(index, at) < 1.6: return false
		if not hides(hit, _eye): return false
	return true


## Does the thing a ray struck hide what is behind it? The ground and a grey box do. A house
## does unless the eye is close enough to see through its windows. Anything else is taken
## not to.
func hides(hit: Dictionary, eye: Vector3) -> bool:
	var body: Object = hit.collider
	if body == map.ground_body: return true
	if body == map.solids:
		var struck: int = map.shape_box[int(hit.shape)]
		return level_of(struck) == Level.BOX or eye.distance_to(hit.position) > SEE_THROUGH
	var node := body as Node
	for step: int in range(4):
		if node == null: return false
		if node.has_meta("map1_house"): return eye.distance_to(hit.position) > SEE_THROUGH
		node = node.get_parent()
	return false


# ---- changing a building -----------------------------------------------------------------

## Works out the plan and builds the look, hidden. False when no house can be made of it.
func _prepare(index: int) -> bool:
	if looks.has(index): return true
	var plan := site(index)
	if not bool(plan.ok): return false
	var look: Node3D = HouseKit.build_look(plan.spec)
	look.name = "Look_%d" % index
	look.transform = plan.frame
	look.visible = false
	add_child(look)
	looks[index] = look
	stats.looks_built += 1
	stats.look_usec += int(look.get_meta("build_usec", 0))
	return true


func _to_look(index: int, why: int) -> void:
	var from := level_of(index)
	changing.emit(index, from, Level.LOOK, why)
	if from == Level.BOX:
		map.set_box_drawn(index, false)
	elif from == Level.FULL:
		var house: Node3D = houses[index]
		houses.erase(index)
		house.visible = false
		house.queue_free()
		map.set_box_solid(index, true)
	(looks[index] as Node3D).visible = true
	levels[index] = Level.LOOK


func _to_full(index: int) -> void:
	changing.emit(index, Level.LOOK, Level.FULL, Why.SAME_PICTURE)
	var plan := site(index)
	var house: Node3D = HouseKit.build(plan.spec, visuals)
	house.transform = plan.frame
	house.set_meta("map1_house", index)
	add_child(house)
	houses[index] = house
	(looks[index] as Node3D).visible = false
	map.set_box_solid(index, false)
	levels[index] = Level.FULL
	stats.fulls_built += 1
	stats.full_usec += int(house.stats.build_usec)


func _to_box(index: int, why: int) -> void:
	changing.emit(index, Level.LOOK, Level.BOX, why)
	(looks[index] as Node3D).queue_free()
	looks.erase(index)
	levels.erase(index)
	map.set_box_drawn(index, true)


# ---- the recharge stations ---------------------------------------------------------------

## The 21 stations of encounters.charging_stations, each where the plan put its plinth and
## turned the way the plan turned it (bays towards the public).
func _build_stations() -> void:
	var plinths: Array[int] = []
	for index: int in boxes.size():
		if _kinds[index] == "charger" and is_equal_approx(float(boxes[index][5]), 2.4): plinths.append(index)
	for entry: Array in map.data.get("encounters", {}).get("charging_stations", []):
		var station: Node3D = Station.from_map_entry(entry, visuals)
		var best := -1
		var gap := 30.0
		for index: int in plinths:
			var here := Vector2(_cx[index] - float(entry[0]), _cz[index] - float(entry[1])).length()
			if here < gap:
				gap = here
				best = index
		var at := Vector3(float(entry[0]), 0.0, float(entry[1]))
		if best >= 0:
			at = Vector3(_cx[best], 0.0, _cz[best])
			# The plan's boxes have the bays looking down their own -z; the station's look down +z.
			station.rotation.y = deg_to_rad(float(boxes[best][6])) + PI
		var level := ground(at.x, at.z)
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var out: Vector3 = at + Basis(Vector3.UP, station.rotation.y) * Vector3(corner.x * float(station.width) * 0.5, 0.0, corner.y * Station.PLINTH_DEPTH * 0.5)
			level = maxf(level, ground(out.x, out.z))
		station.position = Vector3(at.x, level, at.z)
		station.name = "RechargeStation%d" % (stations.size() + 1)
		station.set_meta("map_entry", entry)
		add_child(station)
		stations.append(station)
