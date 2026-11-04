extends RefCounted
## Destination scheduling only. Native actor navigation, floor/chassis checks,
## collision, perception and combat remain authoritative over actual movement.
const MIN_DISTANCE := 14.0
const MAX_DISTANCE := 44.0
const ATTEMPTS_PER_DECISION := 6
const STALL_SECONDS := 8.0
const MAX_LEG_SECONDS := 100.0
const FAILED_GOAL_SECONDS := 45.0
const SCAN_MIN_SECONDS := 2.6
const SCAN_MAX_SECONDS := 4.2

var goal := Vector3.INF
var owner_id := 0
var pause_remaining := 0.0
var still_seconds := 0.0
var blocked_seconds := 0.0
var leg_seconds := 0.0
var progress_anchor := Vector3.INF
var best_distance := INF
var recent: Array[Vector3] = []
var rejected: Array[Dictionary] = []
var decisions := 0
var route_queries := 0
var arrivals := 0
var reroutes := 0
var attempts_last_decision := 0
var checkpoint_scan := false
var resume_attempt := 0
var resume_heading := 0.0

func suspend(actor: CharacterBody3D) -> void:
	# Combat/abilities do not count as a stalled patrol or an elapsed roaming leg.
	progress_anchor = actor.global_position
	still_seconds = 0.0
	blocked_seconds = 0.0
	leg_seconds = 0.0
	best_distance = _flat_distance(actor.global_position, goal) if goal.is_finite() else INF

func next_goal(actor: CharacterBody3D, delta: float) -> Vector3:
	if actor.dead or actor.mode != "GROUND" or not is_instance_valid(actor.navigation_source):
		suspend(actor)
		return Vector3.INF
	if owner_id != actor.get_instance_id():
		owner_id = actor.get_instance_id()
		goal = Vector3.INF
		pause_remaining = 0.0
		checkpoint_scan = false
		resume_attempt = 0
		suspend(actor)
	pause_remaining = maxf(0.0, pause_remaining - delta)
	if pause_remaining <= 0.0: checkpoint_scan = false
	for row: Dictionary in rejected.duplicate():
		row.seconds = float(row.seconds) - delta
		if row.seconds <= 0.0: rejected.erase(row)
	if goal.is_finite():
		var distance := _flat_distance(actor.global_position, goal)
		if distance <= 0.9:
			arrivals += 1
			recent.append(goal)
			if recent.size() > 4: recent.pop_front()
			goal = Vector3.INF
			# Each arrival is a police checkpoint: hold position and sweep the area.
			pause_remaining = randf_range(SCAN_MIN_SECONDS, SCAN_MAX_SECONDS)
			checkpoint_scan = true
			return Vector3.INF
		leg_seconds += delta
		still_seconds += delta
		# Count real progress toward this destination, not turning or oscillation.
		if distance < best_distance - 0.5:
			best_distance = distance
			progress_anchor = actor.global_position
			still_seconds = 0.0
		if actor.nav_status in ["blocked", "rejected"]:
			blocked_seconds += delta
		else:
			blocked_seconds = 0.0
		if still_seconds >= STALL_SECONDS or blocked_seconds >= 2.0 or leg_seconds >= MAX_LEG_SECONDS:
			_avoid(goal)
			reroutes += 1
			goal = Vector3.INF
			pause_remaining = 0.3
			actor.nav_refresh = 0.0
			return Vector3.INF
		return goal
	if pause_remaining > 0.0:
		return Vector3.INF
	return _choose(actor)

func _choose(actor: CharacterBody3D) -> Vector3:
	var source: Node = actor.navigation_source
	if not source.has_method("get_nearest_walkable_world") or not source.has_method("get_path_world"):
		pause_remaining = 2.0
		return Vector3.INF
	if resume_attempt == 0:
		decisions += 1
		attempts_last_decision = 0
		resume_heading = randf_range(0.0, TAU)
	var heading := resume_heading
	for attempt: int in range(resume_attempt, ATTEMPTS_PER_DECISION):
		# Each attempt plans a full route; spread a decision across physics ticks,
		# picking up where it stopped so the back-off below still applies.
		if not actor.planning_budget_left():
			resume_attempt = attempt
			pause_remaining = 0.05
			return Vector3.INF
		attempts_last_decision += 1
		# Sampling from the current leader position lets successive legs traverse
		# the park instead of repeatedly returning to the original spawn anchor.
		var angle := heading + float(attempt) * TAU / float(ATTEMPTS_PER_DECISION)
		var requested := actor.global_position + Vector3(sin(angle), 0, cos(angle)) * randf_range(20.0, 38.0)
		var projected: Variant = source.get_nearest_walkable_world(requested)
		if not projected is Vector3 or not projected.is_finite(): continue
		var candidate: Vector3 = projected
		var distance := _flat_distance(candidate, actor.global_position)
		if distance < MIN_DISTANCE or distance > MAX_DISTANCE or _flat_distance(candidate, requested) > 7.0: continue
		if _avoided(candidate): continue
		# steering_point includes gate/door vetoes, connected navigation and the
		# actor's own full-body floor/turn clearance. Never steer directly on failure.
		actor.nav_refresh = 0.0
		route_queries += 1
		actor.steering_point(candidate)
		if actor.nav_status not in ["following", "arrived"] or not actor.nav_endpoint.is_finite():
			_avoid(candidate)
			continue
		if _flat_distance(actor.nav_endpoint, candidate) > 3.0 or _flat_distance(actor.nav_endpoint, actor.global_position) < MIN_DISTANCE:
			_avoid(candidate)
			continue
		goal = actor.nav_endpoint
		resume_attempt = 0
		progress_anchor = actor.global_position
		best_distance = _flat_distance(actor.global_position, goal)
		still_seconds = 0.0
		blocked_seconds = 0.0
		leg_seconds = 0.0
		return goal
	# Bounded retries during a genuinely blocked world, rather than pathfinding
	# every frame. The native motor remains stopped until a checked route exists.
	resume_attempt = 0
	pause_remaining = randf_range(1.5, 2.5)
	return Vector3.INF

func _avoid(point: Vector3) -> void:
	rejected.append({"point": point, "seconds": FAILED_GOAL_SECONDS})
	if rejected.size() > 8: rejected.pop_front()

func _avoided(point: Vector3) -> bool:
	for row: Dictionary in rejected:
		if _flat_distance(row.point, point) < 7.0: return true
	for previous: Vector3 in recent:
		if _flat_distance(previous, point) < 9.0: return true
	return false

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
