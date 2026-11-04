extends SceneTree

var failures := 0
var detours := 0
const DT := 1.0 / 60.0
const FORWARD := Vector2(0, -1)
const STALL_TICKS := 24
const SIDESTEP_TICKS := 40
const MAX_DETOURS_PER_LEG := 12

func _initialize() -> void:
	call_deferred("run_walks")

func run_walks() -> void:
	# Accelerate wall time while retaining the normal 1/60s simulation step.
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	var scene: Node3D = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_route_qa_only.json"
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var extracts_before: int = raid.profile.data.extracts
	var deadline := Time.get_ticks_msec() + 300000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await physics_frame
	raid.start_run()
	if raid.phase != raid.Phase.RAID:
		push_error("Route test could not deploy")
		quit(1)
		return
	# This test isolates player traversal and relay interaction. Combat is
	# exercised elsewhere; walking past twelve police drones would measure
	# survival instead of path connectivity.
	raid._clear_enemies()
	await physics_frame
	# Movement input needs a captured mouse, which a headless run never has. The
	# test calls the player's real ground movement itself, so walking, gravity,
	# stepping and collision are all the code the game uses.
	raid.player.set_physics_process(false)
	var destinations: Array[Vector3] = []
	for site: Dictionary in raid.sites:
		if site.kind == "relay":
			destinations.append(site.position)
	destinations.append(raid.exits[0].position)
	var origin: Vector3 = raid.player.position
	for goal: Vector3 in destinations:
		raid.player.position = origin
		raid.player.velocity = Vector3.ZERO
		var route: PackedVector3Array = raid.navigation.path(origin, goal)
		var result: Dictionary = await follow(raid, route)
		var ok: bool = not route.is_empty() and result.ok
		if not ok:
			failures += 1
		print("WALK_", "PASS" if ok else "FAIL", ": ", origin, " -> ", goal, " ticks=", result.ticks, " detours=", result.detours)
		for site: Dictionary in raid.sites:
			if site.kind == "relay" and site.position == goal and ok:
				# Routes end on the nearest grid point, so finish by walking up to the lamp.
				var side: Vector3 = raid.player.position - (site.position as Vector3)
				side.y = 0.0
				var beside: Vector3 = site.position + side.normalized() * 1.1
				await follow(raid, PackedVector3Array([raid.player.position, beside]))
				Input.action_press("sr_interact")
				for tick: int in range(270):
					await physics_frame
				Input.action_release("sr_interact")
				print("RELAY_", "PASS" if site.done else "FAIL", ": ", site.id)
				if not site.done:
					failures += 1
		origin = raid.player.position
	for tick: int in range(1000):
		if raid.phase == raid.Phase.RESULT:
			break
		await physics_frame
	var extracted: bool = raid.phase == raid.Phase.RESULT and raid.relays == 3 and int(raid.profile.data.extracts) == extracts_before + 1
	print("FULL_RUN_EXTRACTION: ", "PASS" if extracted else "FAIL")
	if not extracted:
		failures += 1
		raid.finish_run(false, "Automated route test completed")
	print("ROUTE_DETOURS: ", detours)
	print("ROUTE_WALK_RESULT: ", failures, " failures")
	quit(0 if failures == 0 else 1)

## Walks the points like a player would: straight at each one, and sidestepping
## anything the grid missed. A point that stays blocked after three sidesteps is
## skipped. Too many detours fail the leg, so a closed route still fails, and
## ROUTE_DETOUR lines show where the grid and the world disagree.
func follow(raid: Node, route: PackedVector3Array) -> Dictionary:
	var player: CharacterBody3D = raid.player
	var waypoint := 1
	var ticks := 0
	var stalled := 0
	var sidestep := 0
	var side := 1.0
	var blocked := 0
	var leg_detours := 0
	var previous: Vector3 = player.position
	while waypoint < route.size() and ticks < 18000:
		var point: Vector3 = route[waypoint]
		if Vector2(player.position.x, player.position.z).distance_to(Vector2(point.x, point.z)) < 0.65:
			waypoint += 1
			blocked = 0
			continue
		player.look_at(Vector3(point.x, player.position.y, point.z))
		await physics_frame
		player._advance_ground_movement(DT, Vector2(side, 0) if sidestep > 0 else FORWARD, false, false, false)
		sidestep = maxi(0, sidestep - 1)
		ticks += 1
		stalled = stalled + 1 if player.position.distance_to(previous) < 0.008 else 0
		previous = player.position
		if stalled < STALL_TICKS:
			continue
		stalled = 0
		blocked += 1
		leg_detours += 1
		detours += 1
		side = -side
		sidestep = SIDESTEP_TICKS
		print("ROUTE_DETOUR: at ", player.position, " toward ", point)
		if leg_detours > MAX_DETOURS_PER_LEG:
			print("ROUTE_STUCK: ", player.position, " next ", point)
			return {"ok": false, "ticks": ticks, "detours": leg_detours}
		if blocked >= 3:
			waypoint += 1
			blocked = 0
	return {"ok": waypoint >= route.size(), "ticks": ticks, "detours": leg_detours}
