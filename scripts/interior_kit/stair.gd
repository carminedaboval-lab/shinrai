extends RefCounted
## The indoor stair of a kit house: one straight flight, steep and narrow the way a Japanese
## house stair is.
##
## What you see is real steps (a block and a tread board with a nosing for every step), a
## banister on the open side (newel posts, a raked handrail, square balusters), a handrail on
## the wall side, and a guard round the opening in the floor above. What you walk on is one
## ramp laid along the nosings, because that is what the player and the scavs can climb:
## 42 degrees, under their 45 degree limit.
##
## The ramp ends in a short level lip, and the floor it arrives at starts under that lip
## (ramp_prism(), RAMP_LAP, SEAM_GAP). The first version used ramp() from scripts/
## building_access/geometry.gd, whose top simply meets the floor's edge. A body pressed a
## millimetre into so steep a ramp then touches the floor's corner at about 47 degrees, which
## counts as a wall, and it jams on the last step. The probe caught that with houses standing
## away from the world's origin; with the lip the corner is never there to be touched.
##
## The stair's own axes: it climbs towards +z, the walking lane is x from 0 to `width`, the
## banister stands just outside it on the +x side, y = 0 is the lower floor. The first riser
## is at z = 0; the ramp starts one going before it.

const ShellMesh := preload("res://scripts/interior_kit/shell_mesh.gd")

const TREAD_BOARD := 0.03
const NOSING := 0.02
## Handrail height above the line of the nosings, and the guard height upstairs.
const RAIL_HEIGHT := 0.85
const GUARD_HEIGHT := 0.95
## The banister takes this much room beside the lane.
const BANISTER := 0.09
const BALUSTER := 0.028
## Gap between balusters, centre to centre (a child cannot get through).
const BALUSTER_SPACING := 0.11
## A ramp's level lip is this long, and the solid floor it arrives at starts this far along
## it (so the lip covers the floor's edge).
const RAMP_LAP := 0.12
const SEAM_GAP := 0.06


## Adds the stair's faces to `shell` (in the house's space, through `frame`) and returns what
## the kit must add as collision and cut out of the floor above:
##   solids   boxes [centre, size] in the stair's axes
##   prisms   convex shapes (PackedVector3Array) in the stair's axes
##   opening  Rect2 in the stair's x and z: the hole in the upper floor, as it is seen
##   opening_solid  the same hole in the floor's collision: SEAM_GAP longer at the top
##   plus the measured numbers (risers, rise, going, slope_degrees, run).
static func build(shell: ShellMesh, frame: Transform3D, storey: float, rise_wanted: float, going: float, width: float, colours: Dictionary) -> Dictionary:
	var risers := maxi(2, roundi(storey / rise_wanted))
	var rise := storey / float(risers)
	var treads := risers - 1
	var run := float(treads) * going
	var slope := atan(rise / going)
	var timber: Color = colours.timber
	var plain: Color = colours.riser
	var solids: Array = []
	var prisms: Array = []
	# Steps: a block under every tread, and the tread board on top with its nosing.
	for i: int in range(1, risers):
		var top := rise * float(i)
		var z0 := going * float(i - 1)
		shell.box(frame, Vector3(width * 0.5, (top - TREAD_BOARD) * 0.5, z0 + going * 0.5), Vector3(width, top - TREAD_BOARD, going), plain)
		shell.box(frame, Vector3(width * 0.5, top - TREAD_BOARD * 0.5, z0 + (going - NOSING) * 0.5), Vector3(width, TREAD_BOARD, going + NOSING), timber)
	# What is walked on: one ramp along the nosings, from one going before the first riser.
	prisms.append(ramp_prism(0.0, width, -going, run, storey, 0.19))
	# The ramp is a thin slab. The stair's high end is closed, as solid as it looks.
	solids.append([Vector3(width * 0.5, (storey - rise) * 0.5, run - 0.03), Vector3(width, storey - rise, 0.06)])
	var centre_x := width + BANISTER * 0.5
	# Banister, lower part: raked from the foot of the stair to the floor above. Its first
	# post stands one going before the first riser, where the ramp begins, so a body that
	# comes at the stair from the side meets the post on the level floor, not part-way up.
	var foot_z := -going - BANISTER * 0.5
	shell.box(frame, Vector3(centre_x, 0.55, foot_z), Vector3(BANISTER, 1.10, BANISTER), timber)
	shell.box(frame, Vector3(centre_x, (rise * float(treads) + storey + GUARD_HEIGHT + 0.05) * 0.5, run - BANISTER * 0.5), Vector3(BANISTER, storey + GUARD_HEIGHT + 0.05 - rise * float(treads), BANISTER), timber)
	_raked_rail(shell, frame, centre_x, foot_z, run - BANISTER, rise, going, RAIL_HEIGHT, Vector2(0.05, 0.06), timber)
	var z := -going + BALUSTER_SPACING * 0.5
	while z < run - BANISTER - 0.03:
		var foot := maxf(0.0, rise * float(int(floor(z / going)) + 1))
		var head := _nosing_line(z, rise, going) + RAIL_HEIGHT - 0.03
		shell.box(frame, Vector3(centre_x, (foot + head) * 0.5, z), Vector3(BALUSTER, head - foot, BALUSTER), timber)
		z += BALUSTER_SPACING
	prisms.append(_side_prism(width, width + BANISTER, -going - BANISTER, run, _nosing_line(-going - BANISTER, rise, going) + RAIL_HEIGHT + 0.03, storey + GUARD_HEIGHT))
	# A handrail on the wall side, on three brackets. No collision: it is hand-thin.
	_raked_rail(shell, frame, 0.055, 0.10, run - 0.10, rise, going, RAIL_HEIGHT - 0.05, Vector2(0.035, 0.045), timber)
	for bracket_z: float in [0.25, run * 0.5, run - 0.25]:
		var under := _nosing_line(bracket_z, rise, going) + RAIL_HEIGHT - 0.05 - 0.035
		shell.box(frame, Vector3(0.0275, under, bracket_z), Vector3(0.055, 0.02, 0.025), timber)
	# The guard round the opening upstairs: along the open side, and across the low end.
	var south := -going - 0.06
	var apron_top := storey + 0.05
	var rail_y := storey + GUARD_HEIGHT - 0.03
	var side_length := run - BANISTER - south
	var side_middle := (run - BANISTER + south) * 0.5
	shell.box(frame, Vector3(centre_x, storey - 0.075, (run + south) * 0.5), Vector3(BANISTER, 0.25, run - south), timber)
	shell.box(frame, Vector3(centre_x, rail_y, side_middle), Vector3(0.05, 0.06, side_length), timber)
	shell.box(frame, Vector3(centre_x, (apron_top + storey + GUARD_HEIGHT + 0.05) * 0.5, south + BANISTER * 0.5), Vector3(BANISTER, GUARD_HEIGHT + 0.05 - 0.05, BANISTER), timber)
	z = south + BANISTER + BALUSTER_SPACING * 0.5
	while z < run - BANISTER - 0.03:
		shell.box(frame, Vector3(centre_x, (apron_top + rail_y - 0.03) * 0.5, z), Vector3(BALUSTER, rail_y - 0.03 - apron_top, BALUSTER), timber)
		z += BALUSTER_SPACING
	solids.append([Vector3(centre_x, storey + (GUARD_HEIGHT - 0.2) * 0.5, (run + south) * 0.5), Vector3(BANISTER, GUARD_HEIGHT + 0.2, run - south)])
	var end_z := south + 0.03
	shell.box(frame, Vector3(width * 0.5, rail_y, end_z), Vector3(width, 0.06, 0.05), timber)
	shell.box(frame, Vector3(width * 0.5, storey + 0.02, end_z), Vector3(width, 0.04, 0.05), timber)
	var x := BALUSTER_SPACING * 0.5
	while x < width - 0.02:
		shell.box(frame, Vector3(x, (storey + 0.04 + rail_y - 0.03) * 0.5, end_z), Vector3(BALUSTER, rail_y - 0.03 - storey - 0.04, BALUSTER), timber)
		x += BALUSTER_SPACING
	solids.append([Vector3(width * 0.5, storey + GUARD_HEIGHT * 0.5, end_z), Vector3(width, GUARD_HEIGHT, 0.06)])
	return {
		"solids": solids, "prisms": prisms,
		"opening": Rect2(0.0, -going, width + BANISTER, run + going),
		"opening_solid": Rect2(0.0, -going, width + BANISTER, run + going + SEAM_GAP),
		"risers": risers, "rise": rise, "going": going, "width": width, "run": run,
		"slope_degrees": rad_to_deg(atan(storey / (run + going))),
		"step_degrees": rad_to_deg(slope),
	}


## A ramp to walk on, between x0 and x1: it starts at height 0 at z0 and reaches `rise` at
## z1, then runs level for RAMP_LAP. The floor it arrives at must start SEAM_GAP along that
## lip, at the same height. `under` is how thick the lip is (keep it inside the floor it
## covers). The ramp is the slab between those points and a little below its own foot.
static func ramp_prism(x0: float, x1: float, z0: float, z1: float, rise: float, under: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var lap := RAMP_LAP * signf(z1 - z0)
	for x: float in [x0, x1]:
		points.append(Vector3(x, -0.12, z0))
		points.append(Vector3(x, 0.0, z0))
		points.append(Vector3(x, rise, z1))
		points.append(Vector3(x, rise, z1 + lap))
		points.append(Vector3(x, maxf(rise - under, -0.12), z1 + lap))
	return points


## Height of the line through the step nosings at `z`, above the lower floor.
static func _nosing_line(z: float, rise: float, going: float) -> float:
	return (z + going) * rise / going


static func _raked_rail(shell: ShellMesh, frame: Transform3D, x: float, z0: float, z1: float, rise: float, going: float, height: float, section: Vector2, colour: Color) -> void:
	var a := Vector3(x, _nosing_line(z0, rise, going) + height, z0)
	var b := Vector3(x, _nosing_line(z1, rise, going) + height, z1)
	var rail := frame * Transform3D(Basis(Vector3.RIGHT, -atan(rise / going)), (a + b) * 0.5)
	shell.box(rail, Vector3.ZERO, Vector3(section.x, section.y, a.distance_to(b)), colour)


## A thin upright slab between x0 and x1 whose top slopes: from `low` high at z0 up to `high`
## at z1. This is what stops a body at the banister.
static func _side_prism(x0: float, x1: float, z0: float, z1: float, low: float, high: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for x: float in [x0, x1]:
		points.append(Vector3(x, 0.0, z0))
		points.append(Vector3(x, low, z0))
		points.append(Vector3(x, high, z1))
		points.append(Vector3(x, 0.0, z1))
	return points
