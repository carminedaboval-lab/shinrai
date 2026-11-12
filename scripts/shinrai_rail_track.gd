extends RefCounted

## The tram line on the ring road around Midori Park. It is a C-shaped line, not a closed
## loop: up the west side, along the north side, down the east side. The south side is a
## narrower street with its own set pieces, so the line ends before it and the tram shuttles
## back and forth. Travelling from the west end to the east end the park is always on the
## right, which is the door side.
## Distances are metres along the line; s = 0 is the south end of the west side.

## The ring road is 14 m wide, from the park edge (222, 182) outward. The track runs
## down the park-side lane, 3.5 m out from the kerb.
const HALF_X := 225.5
const HALF_Z := 185.5
const RADIUS := 8.0
## How far south the west and east sides run.
const SOUTH_END := 150.0
## Top of the road surface (midori_tokyo_roads.gd ROAD_Y).
const RAIL_Y := -0.06

const SIDE := SOUTH_END + HALF_Z - RADIUS
const NORTH := 2.0 * (HALF_X - RADIUS)
const ARC := PI * RADIUS * 0.5
const NORTH_START := SIDE + ARC
const EAST_START := NORTH_START + NORTH + ARC


static func length() -> float:
	return EAST_START + SIDE


static func on_corner(s: float) -> bool:
	return (s > SIDE - 4.0 and s < NORTH_START + 4.0) or (s > NORTH_START + NORTH - 4.0 and s < EAST_START + 4.0)


## Position and heading at distance s. The basis has -Z along west-to-east travel and +X toward the park.
static func frame_at(s: float) -> Transform3D:
	s = clampf(s, 0.0, length())
	var cx := HALF_X - RADIUS
	var cz := HALF_Z - RADIUS
	var position := Vector3.ZERO
	var heading := PI * 1.5
	if s <= SIDE:
		position = Vector3(-HALF_X, 0.0, SOUTH_END - s)
	elif s <= NORTH_START:
		heading += (s - SIDE) / RADIUS
		position = Vector3(-cx, 0.0, -cz) + Vector3(sin(heading), 0.0, -cos(heading)) * RADIUS
	elif s <= NORTH_START + NORTH:
		heading = 0.0
		position = Vector3(-cx + (s - NORTH_START), 0.0, -HALF_Z)
	elif s <= EAST_START:
		heading = (s - NORTH_START - NORTH) / RADIUS
		position = Vector3(cx, 0.0, -cz) + Vector3(sin(heading), 0.0, -cos(heading)) * RADIUS
	else:
		heading = PI * 0.5
		position = Vector3(HALF_X, 0.0, -cz + (s - EAST_START))
	var right := Vector3(-sin(heading), 0.0, cos(heading))
	var back := Vector3(-cos(heading), 0.0, -sin(heading))
	return Transform3D(Basis(right, Vector3.UP, back), position + Vector3.UP * RAIL_Y)
