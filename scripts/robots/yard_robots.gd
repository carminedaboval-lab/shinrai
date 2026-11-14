extends RefCounted
## Puts one recharge station into the test yard (scripts/test_yard/yard_world.gd): the first
## station, with the first robot in it. The yard only: no other level gets one from here.
##
## Three bays, two robots, one bay empty. The first robot gives a power cell, one servo and
## its access chip (so the whole loop can be shown); the second is an ordinary station robot
## and gives a power cell.
##
## It stands against the east edge of the yard, south of the kit house, facing west down an
## open lane. That is 42 m from where the walk scene starts, behind the east building, so the
## owner sees the marker post over the roof and goes to it on purpose. It is clear of the
## scav probe's fights (north-west, south and centre), the bird sites and the house.

const Station := preload("res://scripts/robots/station.gd")
const RobotParts := preload("res://scripts/robots/robot_parts.gd")

const POSITION := Vector3(40.5, 0.0, 16.5)
## The bays face west, towards the middle of the yard.
const TURN := -PI * 0.5
const SPEC := {
	"id": "RechargeStation",
	"bays": 3,
	"robots": 2,
	"occupied": [0, 2],
	"loadouts": [RobotParts.FIRST_ROBOT, RobotParts.STATION_ROBOT],
}


static func populate(yard: Node3D, spec: Dictionary = SPEC) -> Node3D:
	var station: Node3D = Station.build(spec, yard.get("visuals") != false)
	station.position = POSITION
	station.rotation.y = TURN
	yard.add_child(station)
	return station
