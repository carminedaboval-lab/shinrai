extends RefCounted
## The interior kit: builds a house you can walk into from a small description.
##
##   var house := HouseKit.build(spec)        # a Node3D; put it where the house stands
##
## The description (`spec`, see scripts/interior_kit/yard_house.gd for a full one):
##   id          name of the node
##   size        Vector2: width along x, depth along z, in metres. The house's own origin is
##               the corner of its outline at ground level; the front wall is the z = 0 side.
##   floors      1 or 2 (see "Limits" below)
##   stair       {x, z, dir}: where the first riser is, and which way it climbs: "+z", "-z",
##               "+x" or "-x". The point given is the wall-side end of that riser: the wall
##               is on the climber's right and the banister on the left. (A stair with the
##               banister on the right is not built.)
##   partitions  inner walls: {id, floors: [0, 1], a: Vector2, b: Vector2}, straight along x
##               or z, given by the middle line of the wall
##   doors       {name, wall, floor, at, swing, hinge, locked, front}. `wall` is "front",
##               "right", "back", "left", "entry" (the wall at the back of a recessed porch)
##               or a partition id. `at` is where the middle of the door is along that wall,
##               as the house's own x or z. `swing` +1 opens to the wall's first side (the
##               inside, for an outer wall; the left of a -> b for a partition), -1 to the
##               other. `hinge` is "low" (towards a) or "high". `kind` "slide" makes it a
##               sliding door where the wall beside it has room to take the leaf (else it is
##               hinged after all). `style`: "panel", "flush", "slide", "fusuma" (door.gd).
##               `sunk`: how far its foot is below the floor (a door onto a genkan).
##   windows     {name, wall, floor, at, width, sill, head, panes, sunk}. sill 0 is a pane
##               down to the floor. `panes` 2 or more draws the meeting stiles of sliding
##               sashes.
##   steps       {wall, at, width, depth}: a slab outside a door or a low window. With `drop`
##               (how far the ground at its outer edge lies below the house) it is a landing
##               and steps down: give it depth `landing` (STEP_LANDING unless given) plus
##               about 0.3 m for each 0.18 m. `top`: its height (the floor's unless given).
##               `under`: how far it reaches below the house's origin. `deck`: boards on
##               posts (an engawa edge) instead of a concrete slab.
##   loot        {floor, at: Vector2, tier}: a marker where loot would be put.
##
## Japanese houses (all optional):
##   upper       {front, back, left, right}: how far the upper floor's walls are set back.
##   recess      {x0, x1, depth, head}: a porch cut into the ground-floor front; the door goes
##               in the wall "entry" at its back.
##   low         [Rect2]: parts of the ground floor that lie at the house's origin, one floor
##               step (FLOOR_ABOVE_GROUND) below the rest: the genkan, the porch, a shop floor.
##   ramps       [{at: Vector2, width, dir}]: where a body walks up that step (the middle of
##               the step's edge, and the way up).
##   kamachi     [[Vector2, Vector2]]: the timber edge board of that step, where it is seen.
##   roof        {form, ridge, pitch, eave, gable, wall_extra, ridge_ends, ridge_wide, thick,
##               ridge_high (a thin sheet-metal roof instead of a tiled one)}: form
##               "gable", "hip" or "irimoya"; ridge "x" or "z".
##   lean_tos    [{a, b, inward, run, y, pitch, eave, ends, cheeks, gutter, colour}]: lower
##               roofs (roof.gd lean()).
##   gutter      {pipe}: rain gutters on the low edges and one downpipe.
##   blocks      [[centre, size, colour, solid, yaw]]: plain boxes: fixtures indoors, things
##               on the plot.
##   wheels      [[centre, radius, yaw, colour]]: bicycle tyres.
##   drums       [[centre, radius, height, sides, colour]]: upright prisms (a paper lantern).
##   signs       [[text, centre, yaw, wide, tall, colour]]: the words on a sign, as flat shapes
##               fitted into `wide` by `tall` and seen from the way `yaw` turns +z (sign_shape()).
##
## Everything fixed (walls, floors, roof, stair, frames) is one mesh and one static body.
## Doors and windows are the existing ones from scripts/building_access/, extended in
## door.gd and window.gd. Openings are cut with building_access/geometry.gd's cut().
##
## Limits: one straight stair, so two floors. A third floor needs a stair that turns back on
## itself so the flights can stack; that is not built. A sliding window does not slide: its
## glass is one pane across both sashes.

const Geometry := preload("res://scripts/building_access/geometry.gd")
const ShellMesh := preload("res://scripts/interior_kit/shell_mesh.gd")
const House := preload("res://scripts/interior_kit/house.gd")
const KitDoor := preload("res://scripts/interior_kit/door.gd")
const KitWindow := preload("res://scripts/interior_kit/window.gd")
const Stair := preload("res://scripts/interior_kit/stair.gd")
const Roof := preload("res://scripts/interior_kit/roof.gd")

# ---- real sizes (the owner's brief; change here, every house follows) ---------------------
const WALL_OUTER := 0.15
const WALL_INNER := 0.12
const CEILING_HEIGHT := 2.4
## Floor structure between a ceiling and the floor above. Floor to floor is 2.6 m.
const FLOOR_BUILD_UP := 0.20
const DOOR_WIDTH := 0.9
const DOOR_HEIGHT := 2.0
const DOOR_LEAF := 0.04
const WINDOW_SILL := 0.85
## Window heads line up with the door heads.
const WINDOW_HEAD := 2.0
const STAIR_RISE := 0.20
const STAIR_GOING := 0.22
const STAIR_WIDTH := 0.8

# ---- defaults (mine) ---------------------------------------------------------------------
## The ground floor stands this far above the ground, on its slab, with a step at the door.
## It is also the genkan step: a genkan's floor is this far below the hall's.
const FLOOR_ABOVE_GROUND := 0.15
const ROOF_PLATE := 0.10
## A roof: rise over run, eaves and gable overhangs.
const ROOF_PITCH := 0.45
const ROOF_EAVE := 0.45
const ROOF_GABLE := 0.30
## From the roof's underside at the ridge to the top of the ridge tiles.
const RIDGE_TOP := Roof.RIDGE_TOP
## Door lining and window frame sections.
const LINING := 0.02
const FRAME_BAR := 0.045
const FRAME_DEPTH := 0.07
const GLASS_THICKNESS := 0.018
## The outer part of a step is a short ramp to walk up, hidden inside the visible slab.
const STEP_RAMP := 0.26
## Steps down to lower ground (a step with a "drop"): the landing at the door (the front
## door opens outwards over it, and somebody has to stand clear of it), and the most one
## step rises.
const STEP_LANDING := 1.5
const STEP_RISE_OUTSIDE := 0.18
const RECESS_HEAD := 2.25
const LOOT_GROUP := "interior_loot_anchors"

const COLOURS := {
	"outer_wall": Color(0.80, 0.78, 0.72),
	"inner_wall": Color(0.90, 0.88, 0.83),
	"floor": Color(0.55, 0.42, 0.28),
	"ceiling": Color(0.93, 0.92, 0.89),
	"timber": Color(0.47, 0.34, 0.21),
	"door": Color(0.60, 0.46, 0.30),
	"front_door": Color(0.27, 0.20, 0.15),
	"concrete": Color(0.56, 0.56, 0.54),
	"roof": Color(0.23, 0.24, 0.26),
	"frame": Color(0.25, 0.24, 0.23),
	"soffit": Color(0.84, 0.83, 0.80),
	"tataki": Color(0.50, 0.49, 0.46),
	"gutter": Color(0.30, 0.29, 0.28),
}

static var _door_materials: Dictionary = {}
## The fonts a sign's words are cut from: the first one this computer has (sign_shape()).
const SIGN_FONTS: Array[String] = ["Yu Gothic", "Meiryo", "MS Gothic", "Noto Sans CJK JP", "Noto Sans JP", "Hiragino Sans", "IPAGothic", "TakaoGothic"]
static var _sign_font: SystemFont
static var _sign_shapes: Dictionary = {}


static func build(spec: Dictionary, visuals: bool = true) -> Node3D:
	return _build(spec, visuals, false)


## The same house as it is SEEN, and nothing else: one mesh for everything fixed with the
## closed door leaves in it, and one for the window panes. No doors or windows to use, no
## collision, no script. Every face is the face build() draws, so a house can stand as this
## from far off and be changed for the full one without the picture changing (the Map 1
## world does that; tests/probe_map1_world.gd compares the two, face by face).
static func build_look(spec: Dictionary) -> Node3D:
	return _build(spec, true, true)


static func _build(spec: Dictionary, visuals: bool, look_only: bool) -> Node3D:
	var started := Time.get_ticks_usec()
	var home: House = null if look_only else House.new()
	var house: Node3D = Node3D.new() if look_only else home
	house.name = str(spec.get("id", "House"))
	var size: Vector2 = spec.size
	var floors := clampi(int(spec.get("floors", 2)), 1, 2)
	if int(spec.get("floors", 2)) > 2: push_warning("interior kit: %s asks for %d floors; the straight stair only stacks to 2" % [house.name, int(spec.floors)])
	var storey := CEILING_HEIGHT + FLOOR_BUILD_UP
	var levels: Array[float] = []
	for index: int in range(floors): levels.append(FLOOR_ABOVE_GROUND + storey * float(index))
	var top := levels[-1] + CEILING_HEIGHT
	var roof: Dictionary = spec.get("roof", {})
	var eave := top + ROOF_PLATE + float(roof.get("wall_extra", 0.0))
	var footing := float(spec.get("foundation", 0.10))
	var paint: Dictionary = COLOURS.duplicate()
	if spec.has("colours"): paint.merge(spec.colours, true)
	if not paint.has("gable_wall"): paint["gable_wall"] = paint.get("outer_wall_upper", paint.outer_wall)
	var body: StaticBody3D = null
	if not look_only:
		body = StaticBody3D.new()
		body.name = "Shell"
		body.collision_layer = 1
		body.collision_mask = 0
		house.add_child(body)
		home.spec = spec
		home.floor_heights = levels
	var kit := {"house": house, "body": body, "shell": ShellMesh.new(), "visuals": visuals, "glass": ShellMesh.new() if look_only else null}
	var t := WALL_OUTER
	var whole := Rect2(0.0, 0.0, size.x, size.y)
	var inset: Dictionary = spec.get("upper", {}) if floors == 2 else {}
	var upper := Rect2(float(inset.get("left", 0.0)), float(inset.get("front", 0.0)), size.x - float(inset.get("left", 0.0)) - float(inset.get("right", 0.0)), size.y - float(inset.get("front", 0.0)) - float(inset.get("back", 0.0)))
	var top_rect := upper if floors == 2 else whole

	# The slab the house stands on. Its top is the ground floor, but for the parts that lie
	# one step lower (a genkan, a porch, a shop floor).
	var low: Array = spec.get("low", [])
	if low.is_empty():
		_block(kit, Transform3D.IDENTITY, Vector3(size.x * 0.5, (levels[0] - footing) * 0.5, size.y * 0.5), Vector3(size.x, levels[0] + footing, size.y), paint.concrete, {"+y": paint.floor})
	else:
		_block(kit, Transform3D.IDENTITY, Vector3(size.x * 0.5, -footing * 0.5, size.y * 0.5), Vector3(size.x, footing, size.y), paint.concrete, {"+y": paint.tataki})
		var raised: Array[Rect2] = [whole]
		for rect: Rect2 in low: raised = Geometry.cut(raised, rect)
		for rect: Rect2 in raised:
			kit.shell.box(Transform3D.IDENTITY, Vector3(rect.get_center().x, levels[0] * 0.5, rect.get_center().y), Vector3(rect.size.x, levels[0], rect.size.y), paint.concrete, {"+y": paint.floor})
		# What is walked on: the step is a short ramp hidden inside the higher floor's edge.
		var firm: Array[Rect2] = raised
		for ramp: Dictionary in spec.get("ramps", []):
			var turn: float = {"+z": 0.0, "-z": PI, "+x": PI * 0.5, "-x": -PI * 0.5}.get(str(ramp.get("dir", "+z")), 0.0)
			var at: Vector2 = ramp.at
			var frame := Transform3D(Basis(Vector3.UP, turn), Vector3(at.x, 0.0, at.y))
			var half := float(ramp.width) * 0.5
			firm = Geometry.cut(firm, _floor_rect(frame, Rect2(-half, 0.0, half * 2.0, STEP_RAMP + Stair.SEAM_GAP)))
			_convex(kit, frame, Stair.ramp_prism(-half, half, 0.0, STEP_RAMP, levels[0], 0.12))
		for rect: Rect2 in firm:
			_solid(kit, Transform3D.IDENTITY, Vector3(rect.get_center().x, levels[0] * 0.5, rect.get_center().y), Vector3(rect.size.x, levels[0], rect.size.y))
		for edge: Array in spec.get("kamachi", []):
			var a: Vector2 = edge[0]
			var b: Vector2 = edge[1]
			Roof.bar(kit.shell, Vector3(a.x, levels[0] * 0.5 + 0.004, a.y), Vector3(b.x, levels[0] * 0.5 + 0.004, b.y), 0.03, levels[0] + 0.008, paint.timber)

	# Walls. An outer wall runs so that its own +z side is indoors.
	var walls: Array = []
	_outer_walls(walls, 0, whole, levels[0], levels[1] if floors == 2 else eave, paint.outer_wall)
	if floors == 2: _outer_walls(walls, 1, upper, levels[1], eave, paint.get("outer_wall_upper", paint.outer_wall))
	for entry: Dictionary in spec.get("partitions", []):
		for level: int in entry.get("floors", [0]):
			if level < floors: walls.append(_wall(entry.a, entry.b, levels[level], levels[level] + CEILING_HEIGHT, WALL_INNER, false, str(entry.id), level, paint.inner_wall))
	# A porch cut into the front: a hole in the front wall, and walls round the porch.
	if spec.has("recess"):
		var recess: Dictionary = spec.recess
		var x0 := float(recess.x0)
		var x1 := float(recess.x1)
		var depth := float(recess.depth)
		var head := levels[0] + float(recess.get("head", RECESS_HEAD))
		var at_left := x0 <= t + 0.01
		var at_right := x1 >= size.x - t - 0.01
		if at_left: x0 = -0.01
		if at_right: x1 = size.x + 0.01
		(_find_wall(walls, "front", 0).openings as Array).append(Rect2(x0, -1.0, x1 - x0, head + 1.0))
		if at_left:
			var left: Dictionary = _find_wall(walls, "left", 0)
			(left.openings as Array).append(Rect2(_along(left, depth), -1.0, float(left.length), head + 1.0))
		else:
			walls.append(_wall(Vector2(x0 - t * 0.5, t), Vector2(x0 - t * 0.5, depth), levels[0], levels[0] + CEILING_HEIGHT, t, true, "entry_left", 0, paint.outer_wall))
		if at_right:
			var right: Dictionary = _find_wall(walls, "right", 0)
			(right.openings as Array).append(Rect2(-1.0, -1.0, _along(right, depth) + 1.0, head + 1.0))
		else:
			walls.append(_wall(Vector2(x1 + t * 0.5, depth), Vector2(x1 + t * 0.5, t), levels[0], levels[0] + CEILING_HEIGHT, t, true, "entry_right", 0, paint.outer_wall))
		walls.append(_wall(Vector2(0.0 if at_left else x0 - t, depth + t * 0.5), Vector2(size.x if at_right else x1 + t, depth + t * 0.5), levels[0], levels[0] + CEILING_HEIGHT, t, true, "entry", 0, paint.outer_wall))

	# Doors, first only the holes: a sliding door needs to know what else is in its wall.
	var door_jobs: Array = []
	for entry: Dictionary in spec.get("doors", []):
		var level := int(entry.get("floor", 0))
		if level >= floors: continue
		var wall: Dictionary = _find_wall(walls, str(entry.wall), level)
		if wall.is_empty(): continue
		var along := _along(wall, float(entry.at))
		var base := levels[level] - float(entry.get("sunk", 0.0))
		var hole := Rect2(along - DOOR_WIDTH * 0.5 - LINING, base, DOOR_WIDTH + LINING * 2.0, DOOR_HEIGHT + LINING)
		(wall.openings as Array).append(hole)
		door_jobs.append([entry, wall, along, base, hole])

	# Windows: a hole, a frame in it, and the pane.
	for entry: Dictionary in spec.get("windows", []):
		var level := int(entry.get("floor", 0))
		if level >= floors: continue
		var wall: Dictionary = _find_wall(walls, str(entry.wall), level)
		if wall.is_empty(): continue
		var along := _along(wall, float(entry.at))
		var width := float(entry.get("width", 1.2))
		var sill := float(entry.get("sill", WINDOW_SILL))
		var floor_y := levels[level] - float(entry.get("sunk", 0.0))
		var bottom := floor_y + sill
		var head := floor_y + float(entry.get("head", WINDOW_HEAD))
		var middle := (bottom + head) * 0.5
		(wall.openings as Array).append(Rect2(along - width * 0.5, bottom, width, head - bottom))
		for side: float in [-1.0, 1.0]:
			_trim(kit, wall.frame, Vector3(along + side * (width - FRAME_BAR) * 0.5, middle, 0.0), Vector3(FRAME_BAR, head - bottom, FRAME_DEPTH), paint.frame)
			_trim(kit, wall.frame, Vector3(along, middle + side * (head - bottom - FRAME_BAR) * 0.5, 0.0), Vector3(width - FRAME_BAR * 2.0, FRAME_BAR, FRAME_DEPTH), paint.frame)
		# Sliding sashes: the stiles where they meet.
		var panes := int(entry.get("panes", 1))
		for stile: int in range(1, panes):
			_trim(kit, wall.frame, Vector3(along - width * 0.5 + width * float(stile) / float(panes), middle, 0.0), Vector3(0.04, head - bottom - FRAME_BAR * 2.0, 0.05), paint.frame)
		if sill > 0.3:
			# The board a window sits on indoors.
			_trim(kit, wall.frame, Vector3(along, bottom - 0.0125, float(wall.thickness) * 0.5 + 0.02), Vector3(width + 0.08, 0.025, 0.06), paint.timber)
		if look_only:
			kit.glass.box((wall.frame as Transform3D) * Transform3D(Basis.IDENTITY, Vector3(along, middle, 0.0)), Vector3.ZERO, Vector3(width - FRAME_BAR * 2.0, head - bottom - FRAME_BAR * 2.0, GLASS_THICKNESS), Color.WHITE)
			continue
		var window: KitWindow = KitWindow.new()
		window.name = "Window_%s" % str(entry.name)
		window.transform = (wall.frame as Transform3D) * Transform3D(Basis.IDENTITY, Vector3(along, middle, 0.0))
		window.visuals = visuals
		window.rng.seed = hash("%s/%s" % [house.name, str(entry.name)])
		house.add_child(window)
		window.configure(Vector3(width - FRAME_BAR * 2.0, head - bottom - FRAME_BAR * 2.0, GLASS_THICKNESS), KitWindow.pane_material(), false, str(entry.name))
		window.title = "window"
		window.inside_drop = sill + FRAME_BAR
		window.outside_drop = bottom + FRAME_BAR
		home.windows[str(entry.name)] = window

	# Doors: a lining round the hole, and the leaf.
	for job: Array in door_jobs:
		var entry: Dictionary = job[0]
		var wall: Dictionary = job[1]
		var along: float = job[2]
		var base: float = job[3]
		for side: float in [-1.0, 1.0]:
			_trim(kit, wall.frame, Vector3(along + side * (DOOR_WIDTH + LINING) * 0.5, base + DOOR_HEIGHT * 0.5, 0.0), Vector3(LINING, DOOR_HEIGHT, float(wall.thickness) + 0.02), paint.timber)
		_trim(kit, wall.frame, Vector3(along, base + DOOR_HEIGHT + LINING * 0.5, 0.0), Vector3(DOOR_WIDTH + LINING * 2.0, LINING, float(wall.thickness) + 0.02), paint.timber)
		var door: KitDoor = KitDoor.new()
		door.name = "Door_%s" % str(entry.name)
		var high: bool = str(entry.get("hinge", "low")) == "high"
		# A sliding door runs into the wall beside it, towards its hinge side if there is
		# room there, else the other way; with room on neither side it is hinged.
		var slide := 0.0
		if str(entry.get("kind", "hinged")) == "slide":
			for way: float in ([1.0, -1.0] if high else [-1.0, 1.0]):
				if slide == 0.0 and _pocket_free(wall, job[4], along, way): slide = way
		door.style = str(entry.get("style", "panel"))
		if slide != 0.0:
			door.slides = true
			door.slide_dir = slide
			door.transform = (wall.frame as Transform3D) * Transform3D(Basis.IDENTITY, Vector3(along, base, 0.0))
			door.room_side = 1.0 if int(entry.get("swing", 1)) > 0 else -1.0
		else:
			if door.style in ["slide", "fusuma"]: door.style = "flush"
			var opens_forward: bool = (int(entry.get("swing", 1)) > 0) != high
			door.transform = (wall.frame as Transform3D) * Transform3D(Basis(Vector3.UP, PI if high else 0.0), Vector3(along, base, 0.0))
			door.open_angle = -PI * 0.5 if opens_forward else PI * 0.5
			door.room_side = 1.0 if opens_forward else -1.0
		var locked := bool(entry.get("locked", false))
		var leaf_colour: Color = paint.front_door if bool(entry.get("front", false)) else (paint.get("fusuma", paint.door) if door.style == "fusuma" else paint.door)
		if look_only:
			# Only what the closed leaf looks like: its faces go into the house's one mesh.
			door.visuals = false
			door.keep_boxes = true
			door.configure(Vector3(DOOR_WIDTH, DOOR_HEIGHT - 0.012, DOOR_LEAF), _door_material(leaf_colour), locked, str(entry.name))
			var leaf_frame: Transform3D = door.transform * Transform3D(Basis.IDENTITY, door.leaf.position)
			for part: Array in door.leaf_boxes: kit.shell.box(leaf_frame, part[0], part[1], part[2])
			door.free()
			continue
		door.visuals = visuals
		house.add_child(door)
		door.configure(Vector3(DOOR_WIDTH, DOOR_HEIGHT - 0.012, DOOR_LEAF), _door_material(leaf_colour), locked, str(entry.name))
		door.title = "front door" if bool(entry.get("front", false)) else "door"
		door.allow_inside_unlock = locked
		home.doors[str(entry.name)] = door

	# The walls themselves, round their openings.
	for wall: Dictionary in walls:
		var fields: Array[Rect2] = [Rect2(0.0, float(wall.y0), float(wall.length), float(wall.y1) - float(wall.y0))]
		for opening: Rect2 in wall.openings: fields = Geometry.cut(fields, opening)
		var skin: Color = wall.face
		# The reveals of an outer wall's openings are its outside finish too.
		var faces: Dictionary = {"-z": skin, "+x": skin, "-x": skin, "+y": skin, "-y": skin} if bool(wall.exterior) else {}
		for rect: Rect2 in fields:
			_block(kit, wall.frame, Vector3(rect.get_center().x, rect.get_center().y, 0.0), Vector3(rect.size.x, rect.size.y, float(wall.thickness)), paint.inner_wall, faces)

	# The stair, and the hole it comes up through.
	var opening_above := Rect2()
	var solid_above := Rect2()
	if floors > 1 and spec.has("stair"):
		var turn: float = {"+z": 0.0, "-z": PI, "+x": PI * 0.5, "-x": -PI * 0.5}.get(str(spec.stair.get("dir", "+z")), 0.0)
		var frame := Transform3D(Basis(Vector3.UP, turn), Vector3(float(spec.stair.x), levels[0], float(spec.stair.z)))
		var stair: Dictionary = Stair.build(kit.shell, frame, storey, STAIR_RISE, STAIR_GOING, STAIR_WIDTH, {"timber": paint.timber, "riser": paint.inner_wall})
		for solid: Array in stair.solids: _solid(kit, frame, solid[0], solid[1])
		for prism: PackedVector3Array in stair.prisms: _convex(kit, frame, prism)
		opening_above = _floor_rect(frame, stair.opening)
		solid_above = _floor_rect(frame, stair.opening_solid)
		stair.erase("solids")
		stair.erase("prisms")
		if not look_only: home.stair = stair

	# Upper floors (each one is also the ceiling below it), and the top ceiling.
	# What is seen stops at the top riser; what is solid stops a little further on, under the
	# lip of the stair's ramp (see stair.gd).
	for index: int in range(1, floors):
		var inside: Array[Rect2] = [Rect2(t, t, size.x - t * 2.0, size.y - t * 2.0)]
		var middle := levels[index] - FLOOR_BUILD_UP * 0.5
		for rect: Rect2 in (Geometry.cut(inside, opening_above) if opening_above.has_area() else inside):
			kit.shell.box(Transform3D.IDENTITY, Vector3(rect.get_center().x, middle, rect.get_center().y), Vector3(rect.size.x, FLOOR_BUILD_UP, rect.size.y), paint.inner_wall, {"+y": paint.floor, "-y": paint.ceiling})
		for rect: Rect2 in (Geometry.cut(inside, solid_above) if solid_above.has_area() else inside):
			_solid(kit, Transform3D.IDENTITY, Vector3(rect.get_center().x, middle, rect.get_center().y), Vector3(rect.size.x, FLOOR_BUILD_UP, rect.size.y))
	_block(kit, Transform3D.IDENTITY, Vector3(top_rect.get_center().x, top + ROOF_PLATE * 0.5, top_rect.get_center().y), Vector3(top_rect.size.x - t * 2.0, ROOF_PLATE, top_rect.size.y - t * 2.0), paint.ceiling)

	# The roof over the top floor, and the lower roofs.
	var roof_opt := {"form": roof.get("form", "gable"), "ridge": roof.get("ridge", "x"), "pitch": float(roof.get("pitch", ROOF_PITCH)), "eave": float(roof.get("eave", ROOF_EAVE)), "gable": float(roof.get("gable", ROOF_GABLE)), "wall": t, "ridge_ends": roof.get("ridge_ends", false), "ridge_wide": roof.get("ridge_wide", 0.24), "thick": float(roof.get("thick", Roof.TILE)), "ridge_high": float(roof.get("ridge_high", Roof.RIDGE))}
	var made: Dictionary = Roof.main(kit.shell, top_rect, eave, roof_opt, paint)
	var rise: float = made.rise
	for plate: PackedVector3Array in made.plates: _plate(kit, plate, float(made.thick))
	var eaves: Array = made.eaves
	var gutters: bool = spec.has("gutter")
	if gutters:
		for line: Array in eaves: Roof.gutter(kit.shell, line, paint.gutter)
		# One downpipe: across under the eave to the wall, then down it.
		var pick := int(spec.gutter.get("pipe", 0))
		var line: Array = eaves[pick % eaves.size()]
		var at_b := (pick / eaves.size()) % 2 == 1
		var out: Vector3 = line[2]
		var on_wall: Vector3 = line[4] if at_b else line[3]
		var under_eave: Vector3 = ((line[1] if at_b else line[0]) as Vector3)
		var head_y := under_eave.y - 0.02
		var from := Vector3(on_wall.x, head_y, on_wall.z) + out * (Vector2(under_eave.x - on_wall.x, under_eave.z - on_wall.z).dot(Vector2(out.x, out.z)) + 0.055)
		var down := Vector3(on_wall.x, head_y, on_wall.z) + out * 0.045
		Roof.bar(kit.shell, from, down, 0.06, 0.06, paint.gutter)
		var outside := down + out * 0.05
		var to_ground := outside.x < 0.0 or outside.x > size.x or outside.z < 0.0 or outside.z > size.y
		Roof.bar(kit.shell, down + Vector3.UP * 0.03, Vector3(down.x, -minf(footing, 0.3) if to_ground else levels[-1] + 0.35, down.z), 0.06, 0.06, paint.gutter)
	for entry: Dictionary in spec.get("lean_tos", []):
		var inward: Vector2 = entry.inward
		var lean: Dictionary = Roof.lean(kit.shell, entry.a, entry.b, inward, float(entry.run), float(entry.y), float(entry.pitch), float(entry.eave), entry.ends, paint, entry.get("colour", paint.roof), float(entry.get("thick", made.thick)))
		_plate(kit, lean.plate, float(entry.get("thick", made.thick)))
		var cheeks: Array = entry.get("cheeks", [false, false])
		var dir: Vector2 = ((entry.b as Vector2) - (entry.a as Vector2)).normalized()
		if bool(cheeks[0]): Roof.lean_cheek(kit.shell, entry.a, inward, float(entry.run), float(entry.y), float(entry.pitch), dir * t, paint)
		if bool(cheeks[1]): Roof.lean_cheek(kit.shell, entry.b, inward, float(entry.run), float(entry.y), float(entry.pitch), -dir * t, paint)
		if gutters and bool(entry.get("gutter", false)): Roof.gutter(kit.shell, lean.eave, paint.gutter)

	# Steps outside: a slab to see, a short ramp inside its outer edge to walk up.
	for entry: Dictionary in spec.get("steps", []):
		var wall: Dictionary = _find_wall(walls, str(entry.wall), 0)
		if wall.is_empty(): continue
		var along := _along(wall, float(entry.at))
		var width := float(entry.get("width", 1.2))
		var depth := float(entry.get("depth", 0.6))
		var outer := -float(wall.thickness) * 0.5 - depth
		var drop := float(entry.get("drop", 0.0))
		var step_top := float(entry.get("top", levels[0]))
		var colour: Color = paint.timber if bool(entry.get("deck", false)) else paint.concrete
		if drop > 0.001:
			# The ground outside lies `drop` below the house (a house on a slope): a landing at
			# the door, then real steps down to the ground. What is walked on is one ramp laid
			# along their nosings, as on the stair indoors; it starts one going out from the
			# lowest step.
			var landing := float(entry.get("landing", STEP_LANDING))
			var climb := step_top + drop
			var count := maxi(1, ceili(climb / STEP_RISE_OUTSIDE))
			var going := (depth - landing) / float(count)
			var below := -drop - 0.10
			if landing > 0.01: kit.shell.box(wall.frame, Vector3(along, (step_top + below) * 0.5, -float(wall.thickness) * 0.5 - landing * 0.5), Vector3(width, step_top - below, landing), colour)
			for index: int in range(count):
				var tread_top := -drop + climb * float(index + 1) / float(count)
				kit.shell.box(wall.frame, Vector3(along, (tread_top + below) * 0.5, outer + going * (float(index) + 0.5)), Vector3(width, tread_top - below, going), colour)
			var ramp_top := outer + going * float(count - 1)
			var prism := PackedVector3Array()
			for point: Vector3 in Stair.ramp_prism(along - width * 0.5, along + width * 0.5, outer - going, ramp_top, climb, climb + 0.12): prism.append(point - Vector3(0.0, drop, 0.0))
			_convex(kit, wall.frame, prism)
			var solid_from := ramp_top + Stair.SEAM_GAP
			_solid(kit, wall.frame, Vector3(along, (step_top + below) * 0.5, (solid_from - float(wall.thickness) * 0.5) * 0.5), Vector3(width, step_top - below, -float(wall.thickness) * 0.5 - solid_from))
			continue
		var under := float(entry.get("under", 0.0))
		var tall := step_top + under
		var mid_y := (step_top - under) * 0.5
		if bool(entry.get("deck", false)):
			# An engawa edge: boards on short posts.
			kit.shell.box(wall.frame, Vector3(along, step_top - 0.02, outer + depth * 0.5), Vector3(width, 0.04, depth), colour)
			kit.shell.box(wall.frame, Vector3(along, step_top - 0.09, outer + 0.03), Vector3(width, 0.10, 0.04), colour)
			for post: float in [-1.0, 0.0, 1.0]:
				kit.shell.box(wall.frame, Vector3(along + post * (width * 0.5 - 0.08), mid_y - 0.02, outer + 0.09), Vector3(0.08, tall - 0.04, 0.08), colour)
		else:
			kit.shell.box(wall.frame, Vector3(along, mid_y, outer + depth * 0.5), Vector3(width, tall, depth), colour)
		var lip := STEP_RAMP + Stair.SEAM_GAP
		_solid(kit, wall.frame, Vector3(along, mid_y, outer + (depth + lip) * 0.5), Vector3(width, tall, depth - lip))
		var slope := PackedVector3Array()
		for point: Vector3 in Stair.ramp_prism(along - width * 0.5, along + width * 0.5, outer, outer + STEP_RAMP, tall, tall + 0.12): slope.append(point - Vector3(0.0, under, 0.0))
		_convex(kit, wall.frame, slope)

	# Plain boxes: the fixtures indoors, and what stands on the plot.
	for entry: Array in spec.get("blocks", []):
		var frame := Transform3D(Basis(Vector3.UP, float(entry[4])) if entry.size() > 4 and float(entry[4]) != 0.0 else Basis.IDENTITY, entry[0])
		kit.shell.box(frame, Vector3.ZERO, entry[1], entry[2])
		if bool(entry[3]): _solid(kit, frame, Vector3.ZERO, entry[1])
	for entry: Array in spec.get("wheels", []):
		kit.shell.ring(Transform3D(Basis(Vector3.UP, float(entry[2])), entry[0]), float(entry[1]), 0.035, 0.035, 10, entry[3])
	# Upright prisms, and the words on signs: both go into the house's one mesh.
	for entry: Array in spec.get("drums", []):
		kit.shell.drum(Transform3D(Basis.IDENTITY, entry[0]), float(entry[1]), float(entry[2]), int(entry[3]), entry[4])
	for entry: Array in spec.get("signs", []):
		var shape := sign_shape(str(entry[0]))
		var extent: Vector2 = shape.size
		if extent.x <= 0.0 or extent.y <= 0.0: continue
		kit.shell.flat(Transform3D(Basis(Vector3.UP, float(entry[2])), entry[1]), shape.corners, minf(float(entry[3]) / extent.x, float(entry[4]) / extent.y), entry[5])

	if look_only:
		var seen := MeshInstance3D.new()
		seen.name = "ShellMesh"
		seen.mesh = kit.shell.commit()
		house.add_child(seen)
		var glass: ShellMesh = kit.glass
		if not glass.is_empty():
			var panes := MeshInstance3D.new()
			panes.name = "Panes"
			var pane_mesh: ArrayMesh = glass.commit()
			pane_mesh.surface_set_material(0, KitWindow.pane_material())
			panes.mesh = pane_mesh
			panes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			house.add_child(panes)
		house.set_meta("triangles", kit.shell.triangle_count() + glass.triangle_count())
		house.set_meta("build_usec", Time.get_ticks_usec() - started)
		return house

	# Where loot would go. The locked room's marker says so.
	for entry: Dictionary in spec.get("loot", []):
		var marker := Marker3D.new()
		marker.name = "Loot_%s" % str(entry.get("tier", "ordinary"))
		var at: Vector2 = entry.at
		marker.position = Vector3(at.x, levels[mini(int(entry.get("floor", 0)), floors - 1)], at.y)
		marker.set_meta("loot_tier", str(entry.get("tier", "ordinary")))
		marker.set_meta("house_id", str(house.name))
		marker.add_to_group(LOOT_GROUP)
		house.add_child(marker, true)

	var shell: ShellMesh = kit.shell
	if visuals and not shell.is_empty():
		var mesh := MeshInstance3D.new()
		mesh.name = "ShellMesh"
		mesh.mesh = shell.commit()
		house.add_child(mesh)
	# The ridge is 0.18 m under the top of the bounds.
	home.bounds = AABB(Vector3(0.0, -0.1, 0.0), Vector3(size.x, eave + rise + float(made.top) + 0.28, size.y))
	home.roof = {"form": made.form, "ridge": made.ridge, "rise": rise, "eave": eave}
	home.stats = _measure(home, shell.triangle_count(), Time.get_ticks_usec() - started)
	return house


# ---- pieces ------------------------------------------------------------------------------

## A wall by its middle line a -> b. Its frame: x along the wall from a, y up, z across it.
static func _wall(a: Vector2, b: Vector2, y0: float, y1: float, thickness: float, exterior: bool, label: String = "", level: int = 0, face: Color = Color.WHITE) -> Dictionary:
	var along := Vector3(b.x - a.x, 0.0, b.y - a.y).normalized()
	return {
		"a": a, "b": b, "y0": y0, "y1": y1, "thickness": thickness, "exterior": exterior,
		"length": a.distance_to(b), "openings": [], "name": label, "level": level, "face": face,
		"frame": Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)), Vector3(a.x, 0.0, a.y)),
	}


## The four outer walls of one floor, round the rectangle `r`.
static func _outer_walls(walls: Array, level: int, r: Rect2, y0: float, y1: float, face: Color) -> void:
	var t := WALL_OUTER
	walls.append(_wall(Vector2(r.position.x, r.position.y + t * 0.5), Vector2(r.end.x, r.position.y + t * 0.5), y0, y1, t, true, "front", level, face))
	walls.append(_wall(Vector2(r.end.x - t * 0.5, r.position.y + t), Vector2(r.end.x - t * 0.5, r.end.y - t), y0, y1, t, true, "right", level, face))
	walls.append(_wall(Vector2(r.end.x, r.end.y - t * 0.5), Vector2(r.position.x, r.end.y - t * 0.5), y0, y1, t, true, "back", level, face))
	walls.append(_wall(Vector2(r.position.x + t * 0.5, r.end.y - t), Vector2(r.position.x + t * 0.5, r.position.y + t), y0, y1, t, true, "left", level, face))


static func _find_wall(walls: Array, id: String, level: int) -> Dictionary:
	for wall: Dictionary in walls:
		if str(wall.name) == id and int(wall.level) == level: return wall
	push_warning("interior kit: no wall '%s' on floor %d" % [id, level])
	return {}


## Is the wall beside a door whole, far enough for the leaf to slide into it?
static func _pocket_free(wall: Dictionary, own: Rect2, along: float, way: float) -> bool:
	var near := along + way * (DOOR_WIDTH * 0.5 + LINING)
	var far := near + way * (DOOR_WIDTH + 0.08)
	var from := minf(near, far)
	var to := maxf(near, far)
	if from < 0.03 or to > float(wall.length) - 0.03: return false
	for opening: Rect2 in wall.openings:
		if opening == own: continue
		if opening.position.x < to and opening.end.x > from: return false
	return true


## A rectangle given in a stair's own x and z, as a rectangle on the house's floor plan.
static func _floor_rect(frame: Transform3D, rect: Rect2) -> Rect2:
	var a := frame * Vector3(rect.position.x, 0.0, rect.position.y)
	var b := frame * Vector3(rect.end.x, 0.0, rect.end.y)
	return Rect2(minf(a.x, b.x), minf(a.z, b.z), absf(a.x - b.x), absf(a.z - b.z))


## Distance along a wall of the point whose own x (or z, for a wall that runs along z) is `at`.
static func _along(wall: Dictionary, at: float) -> float:
	var a: Vector2 = wall.a
	var b: Vector2 = wall.b
	if absf(b.x - a.x) > absf(b.y - a.y): return (at - a.x) * signf(b.x - a.x)
	return (at - a.y) * signf(b.y - a.y)


## A box that is both seen and solid.
static func _block(kit: Dictionary, frame: Transform3D, centre: Vector3, size: Vector3, colour: Color, faces: Dictionary = {}) -> void:
	kit.shell.box(frame, centre, size, colour, faces)
	_solid(kit, frame, centre, size)


## A box that is only seen (linings, frames).
static func _trim(kit: Dictionary, frame: Transform3D, centre: Vector3, size: Vector3, colour: Color) -> void:
	kit.shell.box(frame, centre, size, colour)


static func _solid(kit: Dictionary, frame: Transform3D, centre: Vector3, size: Vector3) -> void:
	if kit.body == null: return
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.transform = frame * Transform3D(Basis.IDENTITY, centre)
	(kit.body as StaticBody3D).add_child(collision)


static func _convex(kit: Dictionary, frame: Transform3D, points: PackedVector3Array) -> void:
	if kit.body == null: return
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collision.shape = shape
	collision.transform = frame
	(kit.body as StaticBody3D).add_child(collision)


## A roof plane as something solid: the plate between its underside and its top.
static func _plate(kit: Dictionary, under: PackedVector3Array, thick: float) -> void:
	if kit.body == null: return
	var points := PackedVector3Array()
	for point: Vector3 in under:
		points.append(point)
		points.append(point + Vector3.UP * thick)
	_convex(kit, Transform3D.IDENTITY, points)


## The letters of a sign as flat shapes: {corners: loose triangles round the middle of the
## words, size: how wide and tall they are}, the height of one letter being about 1. Cut once
## for each text from the outlines of a Japanese font of this computer (no texture and no draw
## call of its own: the shapes go into the house's mesh). A new line in the text starts a new
## row, so a sign that reads downwards has one letter to a row. Where the computer has no
## font with every letter of the text, the shape is empty and the sign stays blank.
static func sign_shape(text: String) -> Dictionary:
	if _sign_shapes.has(text): return _sign_shapes[text]
	var shape := {"corners": PackedVector3Array(), "size": Vector2.ZERO}
	_sign_shapes[text] = shape
	if _sign_font == null:
		_sign_font = SystemFont.new()
		_sign_font.font_names = PackedStringArray(SIGN_FONTS)
		_sign_font.font_weight = 700
	for n: int in text.length():
		if text[n] != "\n" and not _sign_font.has_char(text.unicode_at(n)): return shape
	var words := TextMesh.new()
	words.font = _sign_font
	words.font_size = 64
	words.pixel_size = 1.0 / 64.0
	words.depth = 0.0
	words.curve_step = 2.5
	words.line_spacing = -12.0
	words.text = text
	var arrays: Array = words.get_mesh_arrays()
	if arrays.size() <= Mesh.ARRAY_INDEX or arrays[Mesh.ARRAY_VERTEX] == null: return shape
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: Variant = arrays[Mesh.ARRAY_INDEX]
	var total: int = (indices as PackedInt32Array).size() if indices != null else points.size()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var corners := PackedVector3Array()
	for n: int in range(0, total - 2, 3):
		var a: Vector3 = points[indices[n] if indices != null else n]
		var b: Vector3 = points[indices[n + 1] if indices != null else n + 1]
		var c: Vector3 = points[indices[n + 2] if indices != null else n + 2]
		# (A sliver with no area is nothing to see.)
		if (b - a).cross(c - a).length() < 1e-6: continue
		for point: Vector3 in [a, b, c]:
			corners.append(Vector3(point.x, point.y, 0.0))
			low = low.min(Vector2(point.x, point.y))
			high = high.max(Vector2(point.x, point.y))
	if corners.is_empty(): return shape
	var middle := (low + high) * 0.5
	for n: int in corners.size(): corners[n] -= Vector3(middle.x, middle.y, 0.0)
	shape.corners = corners
	shape.size = high - low
	return shape


static func _door_material(colour: Color) -> StandardMaterial3D:
	var key := colour.to_html()
	if not _door_materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		_door_materials[key] = material
	return _door_materials[key]


## What one house is made of, counted from the built tree.
static func _measure(house: House, shell_triangles: int, usec: int) -> Dictionary:
	var count := {"nodes": 0, "bodies": 0, "collision_shapes": 0, "meshes": 0, "scripts": 0}
	var queue: Array[Node] = [house]
	while not queue.is_empty():
		var node: Node = queue.pop_back()
		count.nodes += 1
		if node is CollisionObject3D: count.bodies += 1
		if node is CollisionShape3D: count.collision_shapes += 1
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null: count.meshes += 1
		if node.get_script() != null: count.scripts += 1
		queue.append_array(node.get_children())
	var door_triangles := 0
	for label: String in house.doors: door_triangles += int(house.doors[label].triangles)
	count["shell_triangles"] = shell_triangles
	count["door_triangles"] = door_triangles
	count["pane_triangles"] = house.windows.size() * 12
	count["triangles"] = shell_triangles + door_triangles + house.windows.size() * 12
	count["doors"] = house.doors.size()
	count["windows"] = house.windows.size()
	count["build_usec"] = usec
	return count
