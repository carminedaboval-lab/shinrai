extends SceneTree
## Measures how the scav crew behaves, in the test yard (no park boot, runs in seconds):
##   godot --headless --path . --fixed-fps 60 --script res://tests/probe_scav_ai.gd
##   ... -- --only=open_fight,break_contact   runs just those scenarios
##   ... -- --rows                             prints a row per second of what each scav is doing
## Each scenario spawns a fresh crew, plays a scripted "player" at it, and prints timings:
## how long until they notice, warn, turn hostile, shoot and hit; how exposed they stand;
## what they do when the player disappears; when they give up.
## Lines start with AI_ ; the summary is one AI_RESULT json line per scenario.

const YardWorld := preload("res://scripts/test_yard/yard_world.gd")
const YardRaid := preload("res://scripts/test_yard/yard_raid.gd")
const Squad := preload("res://scripts/scav_squad.gd")
const Target := preload("res://tests/ai_probe_target.gd")
const DT := 1.0 / 60.0

var yard: Node3D
var raid: Node
var target: CharacterBody3D
var crew: Node3D
var rows := false
var why := false
var only: PackedStringArray = []
var t := 0.0
var events: Array[Dictionary] = []
var _seen_messages := 0
var _seen_notices := 0
var _exposed_time: Dictionary = {}
var _alive_time: Dictionary = {}
var _row_at := 0.0
var _label := ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--rows": rows = true
		elif arg == "--why": rows = true; why = true
		elif arg.begins_with("--only="): only = arg.trim_prefix("--only=").split(",")
	_run.call_deferred()


func _run() -> void:
	var scenarios := {
		"walk_up": _walk_up, "aimed_at": _aimed_at, "open_fight": _open_fight,
		"break_contact": _break_contact, "unseen_shot": _unseen_shot,
		"far_shot": _far_shot, "sniped": _sniped, "sneak_behind": _sneak_behind,
		"gone": _gone,
	}
	for label: String in scenarios:
		if not only.is_empty() and not only.has(label): continue
		await _begin(label)
		var result: Dictionary = await scenarios[label].call()
		result.scenario = label
		print("AI_RESULT ", JSON.stringify(result))
		await _end()
	print("AI_DONE")
	quit(0)


# ---- world -----------------------------------------------------------------------------

func _begin(label: String) -> void:
	_label = label
	t = 0.0
	events.clear()
	_seen_messages = 0
	_seen_notices = 0
	_exposed_time.clear()
	_alive_time.clear()
	_row_at = 0.0
	yard = YardWorld.new()
	yard.visuals = DisplayServer.get_name() != "headless"
	root.add_child(yard)
	yard.build()
	target = Target.new()
	target.name = "ProbePlayer"
	yard.add_child(target)
	target.global_position = Vector3(0, 0.05, -40)
	await physics_frame
	await physics_frame
	raid = YardRaid.new()
	raid.name = "YardRaid"
	yard.add_child(raid)
	raid.setup(yard, target, YardWorld.HALF)
	crew = Squad.new()
	crew.name = "ScavPatrolCrew"
	crew.raid = raid
	crew.spawn_anchor = Vector3(0, 0.2, 20)
	yard.add_child(crew)
	var guard := 0
	while not crew.ready_for_use and guard < 600:
		await physics_frame
		guard += 1
	for actor: CharacterBody3D in crew.members: raid.navigation.exclude(actor)
	# Let concealment index and the bodies settle on the floor.
	for i: int in 30: await physics_frame
	print("AI_BEGIN %s  crew=%d  leader at %s" % [label, crew.members.size(), _p(crew.members[0].global_position) if not crew.members.is_empty() else "-"])


func _end() -> void:
	yard.queue_free()
	await process_frame
	await process_frame


# ---- stepping and recording --------------------------------------------------------------

func _step(seconds: float, until: Callable = Callable()) -> bool:
	var frames := int(seconds / DT)
	for i: int in frames:
		await physics_frame
		t += DT
		_record()
		if until.is_valid() and until.call(): return true
	return false


func _record() -> void:
	# New crew radio messages and HUD lines become events.
	var messages: Array = crew.tactics.messages
	while _seen_messages < messages.size():
		var message: Dictionary = messages[_seen_messages]
		_seen_messages += 1
		if message.kind in ["position_status"]: continue
		_event(str(message.kind), str(message.sender))
	while _seen_notices < raid.notices.size():
		_event("say", str(raid.notices[_seen_notices].text))
		_seen_notices += 1
	for actor: CharacterBody3D in crew.members:
		if not is_instance_valid(actor) or actor.dead: continue
		_alive_time[actor.name] = float(_alive_time.get(actor.name, 0.0)) + DT
		# Exposed = the player has a clear line to this scav's chest, whatever the scav is doing.
		if _line(target.global_position + Vector3.UP * 1.5, actor.global_position + Vector3.UP * (0.75 if actor.crouching else 1.2), actor):
			_exposed_time[actor.name] = float(_exposed_time.get(actor.name, 0.0)) + DT
	if rows and t >= _row_at:
		_row_at = t + 1.0
		var parts: Array[String] = []
		for actor: CharacterBody3D in crew.members:
			if not is_instance_valid(actor): continue
			if actor.dead: parts.append("%s dead" % actor.role); continue
			var order: Dictionary = crew.tactics.orders.get(actor, {})
			parts.append("%s %s/%s %.0fm see%d exp%d cr%d pin%d f%d %s" % [actor.role.left(4), actor.AIState.keys()[actor.state].left(4), str(order.get("kind", "-")), _flat(actor.global_position, target.global_position), 1 if actor.own_visual_time < 0.3 else 0, 1 if _line(target.global_position + Vector3.UP * 1.5, actor.global_position + Vector3.UP * 1.2, actor) else 0, 1 if actor.crouching else 0, 1 if actor.pinned_time > 0 else 0, actor.rounds_fired, _p(actor.global_position)])
		print("AI_ROW %s %5.1f  %s" % [_label, t, " | ".join(parts)])
		if why:
			for actor: CharacterBody3D in crew.members:
				if not is_instance_valid(actor) or actor.dead or actor.own_visual_time > 0.3: continue
				var muzzle: Vector3 = actor.scav_visual.muzzle_position()
				var chest: Vector3 = target.global_position + Vector3.UP * 1.2
				var lane := PhysicsRayQueryParameters3D.create(muzzle, chest, 1 | 2)
				lane.exclude = [actor.get_rid()]
				var hit: Dictionary = yard.get_world_3d().direct_space_state.intersect_ray(lane)
				var blocker := "clear" if hit.is_empty() or hit.collider == target else "%s at %.1fm h%.2f" % [hit.collider.name, muzzle.distance_to(hit.position), hit.position.y]
				var aim: Vector3 = target.global_position - actor.global_position
				aim.y = 0
				var facing: Vector3 = -actor.global_basis.z
				facing.y = 0
				print("AI_WHY %s %5.1f  %s muzzle_h=%.2f lane=%s facing=%.0fdeg permits=%s vis_for=%.2f cooldown=%.2f state=%s balance=%s" % [_label, t, actor.role, muzzle.y - actor.global_position.y, blocker, rad_to_deg(facing.normalized().angle_to(aim.normalized())), str(crew.tactics.permits_fire(actor)), actor.personal_visible_for, actor.attack_cooldown, actor.AIState.keys()[actor.state], str(actor.scav_visual.impact_can_fire())])


func _event(kind: String, detail: String = "") -> void:
	events.append({"t": snappedf(t, 0.01), "kind": kind, "detail": detail})
	if rows: print("AI_EVENT %s %5.2f  %s %s" % [_label, t, kind, detail])


func _first(kind: String, after: float = 0.0) -> float:
	for event: Dictionary in events:
		if event.kind == kind and float(event.t) >= after: return float(event.t)
	return -1.0


func _count(kind: String, after: float = 0.0) -> int:
	var total := 0
	for event: Dictionary in events:
		if event.kind == kind and float(event.t) >= after: total += 1
	return total


func _line(from: Vector3, to: Vector3, ignore: CollisionObject3D = null) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var skip: Array[RID] = [target.get_rid()]
	if ignore != null: skip.append(ignore.get_rid())
	query.exclude = skip
	return yard.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _p(point: Vector3) -> String:
	return "(%.0f,%.0f)" % [point.x, point.z]


func _rounds() -> int:
	var total := 0
	for actor: CharacterBody3D in crew.members:
		if is_instance_valid(actor): total += int(actor.rounds_fired)
	return total


func _first_round_time(from: float, limit: float) -> float:
	var start := _rounds()
	var found: bool = await _step(limit, func() -> bool: return _rounds() > start)
	return snappedf(t - from, 0.01) if found else -1.0


func _nearest_scav(point: Vector3) -> float:
	var best := INF
	for actor: CharacterBody3D in crew.members:
		if is_instance_valid(actor) and not actor.dead: best = minf(best, _flat(actor.global_position, point))
	return best


func _exposure() -> Dictionary:
	var output := {}
	for key: String in _alive_time:
		output[key.trim_prefix("Scav_")] = snappedf(float(_exposed_time.get(key, 0.0)) / maxf(float(_alive_time[key]), 0.01), 0.01)
	return output


func _order_kinds() -> Dictionary:
	var kinds := {}
	for event: Dictionary in events:
		if event.kind in ["move_cover", "hold_cover", "peek", "peek_move", "return_cover", "flank", "flank_arrived", "flank_aborted", "search_sector", "reposition", "observe", "retreat", "joining_fight", "returning_fire", "route_blocked", "cover_compromised", "need_cover", "flee"]:
			kinds[event.kind] = int(kinds.get(event.kind, 0)) + 1
	return kinds


func _states() -> String:
	var parts: Array[String] = []
	for actor: CharacterBody3D in crew.members:
		if not is_instance_valid(actor): continue
		if actor.dead: parts.append("%s dead" % actor.role); continue
		var order: Dictionary = crew.tactics.orders.get(actor, {})
		parts.append("%s %s/%s%s" % [actor.role, actor.AIState.keys()[actor.state], str(order.get("kind", "-")), " fleeing" if actor.fleeing else ""])
	return ", ".join(parts)


func _lead() -> CharacterBody3D:
	return crew.members[0]


## Puts the player in front of the leader at a distance, on open ground the leader can see.
func _place_in_view(distance: float) -> void:
	var lead := _lead()
	var forward := -lead.global_basis.z
	forward.y = 0
	for turn: float in [0.0, 0.3, -0.3, 0.6, -0.6, 0.9, -0.9]:
		var point := lead.global_position + forward.normalized().rotated(Vector3.UP, turn) * distance
		point.y = 0.05
		if raid.navigation.clear(point) and _line(lead.global_position + Vector3.UP * 1.5, point + Vector3.UP * 1.25, lead):
			target.global_position = point
			return
	push_error("AI probe: no clear spot %.0f m in front of the leader" % distance)
	target.global_position = raid.navigation.nearest(lead.global_position + forward.normalized() * distance)


func _fire_at(actor: CharacterBody3D, damage: float) -> void:
	target.weapon_lowered = false
	target.ads = true
	target.aim_at(actor.global_position + Vector3.UP * 1.2)
	raid.on_shot()
	if damage > 0.0: actor.take_damage(damage, target)


func _walk(to: Vector3, speed: float) -> void:
	var route: PackedVector3Array = raid.navigation.path(target.global_position, to)
	if route.is_empty(): target.walk_to(to, speed)
	else: target.follow(route, speed)


func _visible_scav() -> CharacterBody3D:
	for actor: CharacterBody3D in crew.members:
		if is_instance_valid(actor) and not actor.dead and _line(target.global_position + Vector3.UP * 1.5, actor.global_position + Vector3.UP * 1.2, actor): return actor
	return null


func _per_scav_rounds() -> Dictionary:
	var output := {}
	for actor: CharacterBody3D in crew.members:
		if is_instance_valid(actor): output[actor.role] = int(actor.rounds_fired)
	return output


# ---- scenarios ---------------------------------------------------------------------------
# Lambdas copy the locals they capture, so anything a scenario updates while stepping lives
# in a dictionary `m` (dictionaries are shared, not copied).

## The player walks straight at the crew with the weapon down, following them if they move.
func _walk_up() -> Dictionary:
	_place_in_view(38.0)
	await _step(0.5)
	var lead := _lead()
	var m := {"repath": 0.0}
	var approach := func() -> bool:
		if t >= float(m.repath):
			m.repath = t + 1.0
			_walk(lead.global_position, 1.6)
		return crew.warning_active or crew.hostile or _flat(target.global_position, lead.global_position) < 1.5
	await _step(60.0, approach)
	var warned: bool = crew.warning_active or crew.hostile
	var warn_time := t
	var warn_distance := _nearest_scav(target.global_position)
	# Keep walking in after the warning, as a player who ignores it would.
	if not crew.hostile: await _step(30.0, func() -> bool:
		if t >= float(m.repath):
			m.repath = t + 1.0
			_walk(lead.global_position, 1.6)
		return crew.hostile or _flat(target.global_position, lead.global_position) < 1.5)
	var hostile: bool = crew.hostile
	var hostile_time := t
	var hostile_distance := _nearest_scav(target.global_position)
	target.halt()
	var first_shot: float = await _first_round_time(hostile_time, 12.0) if hostile else -1.0
	var hits_before: int = target.hits_taken.size()
	var rounds_before := _rounds()
	await _step(10.0)
	return {"warned": warned, "warn_after_s": snappedf(warn_time, 0.1), "warn_distance_m": snappedf(warn_distance, 0.1), "hostile": hostile, "warn_to_hostile_s": snappedf(hostile_time - warn_time, 0.1) if hostile else -1.0, "hostile_distance_m": snappedf(hostile_distance, 0.1), "hostile_to_first_shot_s": first_shot, "rounds_next_10s": _rounds() - rounds_before, "hits_next_10s": target.hits_taken.size() - hits_before, "said": _said()}


## The player stands in view at 16 m and raises the weapon at the leader.
func _aimed_at() -> Dictionary:
	_place_in_view(16.0)
	await _step(2.5)
	var lead := _lead()
	target.weapon_lowered = false
	target.ads = true
	var raised := t
	var hostile: bool = await _step(8.0, func() -> bool:
		target.aim_at(lead.global_position + Vector3.UP * 1.2)
		return crew.hostile)
	var hostile_time := t
	var first_shot: float = await _first_round_time(hostile_time, 12.0) if hostile else -1.0
	var first_hit := -1.0
	if await _step(15.0, func() -> bool: return not target.hits_taken.is_empty()): first_hit = snappedf(t - hostile_time, 0.01)
	return {"warned_before_raise": _first("warning") >= 0.0, "raise_to_hostile_s": snappedf(hostile_time - raised, 0.01) if hostile else -1.0, "hostile_to_first_shot_s": first_shot, "hostile_to_first_hit_s": first_hit, "said": _said()}


## A stand-up fight at 22 m: the player shoots first, then stands in the open for 30 s,
## firing once a second at whoever is exposed (misses, so the crew stays at full strength).
func _open_fight() -> Dictionary:
	_place_in_view(22.0)
	await _step(1.0)
	_fire_at(_lead(), 12.0)
	var start := t
	var m := {"first_hit": -1.0, "next_shot": t + 1.0, "first_round": -1.0, "in_view_idle": 0.0}
	await _step(30.0, func() -> bool:
		if float(m.first_round) < 0.0 and _rounds() > 0: m.first_round = t - start
		if float(m.first_hit) < 0.0 and not target.hits_taken.is_empty(): m.first_hit = t - start
		# Time a scav can see the player and has a working gun but is not allowed to fire.
		for actor: CharacterBody3D in crew.members:
			if not actor.dead and actor.own_visual_time < 0.1 and actor.can_fire_now() and not crew.tactics.permits_fire(actor): m.in_view_idle = float(m.in_view_idle) + DT
		if t >= float(m.next_shot):
			m.next_shot = t + 1.0
			var seen := _visible_scav()
			if seen != null: _fire_at(seen, 0.0)
		return false)
	var cover_time := _first("hold_cover")
	return {"first_shot_s": snappedf(float(m.first_round), 0.01), "first_hit_s": snappedf(float(m.first_hit), 0.01), "first_in_cover_s": snappedf(cover_time - start, 0.01) if cover_time >= 0 else -1.0, "rounds": _per_scav_rounds(), "hits": target.hits_taken.size(), "saw_player_but_held_fire_s": snappedf(float(m.in_view_idle), 0.1), "exposed_share": _exposure(), "orders": _order_kinds(), "end": _states()}


## Eight seconds of fight, then the player slips behind the west building and crouch-walks away.
func _break_contact() -> Dictionary:
	_place_in_view(22.0)
	await _step(1.0)
	_fire_at(_lead(), 12.0)
	await _step(8.0)
	var last_seen := target.global_position
	target.global_position = Vector3(-18.0, 0.05, -14.0)
	target.weapon_lowered = true
	target.ads = false
	target.crouching = true
	_walk(Vector3(-34.0, 0.05, -34.0), 1.2)
	var lost := t
	var m := {"near_last_seen": INF, "near_player": INF, "found": -1.0, "calm": -1.0, "reached_last_seen": -1.0}
	await _step(150.0, func() -> bool:
		m.near_last_seen = minf(float(m.near_last_seen), _nearest_scav(last_seen))
		m.near_player = minf(float(m.near_player), _nearest_scav(target.global_position))
		if float(m.reached_last_seen) < 0.0 and _nearest_scav(last_seen) < 6.0: m.reached_last_seen = t - lost
		if float(m.found) < 0.0 and t - lost > 0.5:
			for actor: CharacterBody3D in crew.members:
				if not actor.dead and actor.own_visual_time < 0.1: m.found = t - lost
		if float(m.calm) < 0.0 and t - lost > 3.0 and _all_calm(): m.calm = t - lost
		return float(m.found) >= 0.0 or (float(m.calm) >= 0.0 and t - lost > float(m.calm) + 15.0))
	return {"found_player_after_s": snappedf(float(m.found), 0.1), "reached_last_seen_after_s": snappedf(float(m.reached_last_seen), 0.1), "back_to_routine_after_s": snappedf(float(m.calm), 0.1), "closest_to_last_seen_m": snappedf(float(m.near_last_seen), 0.1), "closest_to_player_m": snappedf(float(m.near_player), 0.1), "search_orders": _count("search_sector"), "orders": _order_kinds(), "end": _states(), "still_hostile": crew.hostile}


## One shot fired from behind a building, about 45 m away, never seen.
func _unseen_shot() -> Dictionary:
	target.global_position = Vector3(-22.0, 0.05, -18.0)
	await _step(1.0)
	var lead := _lead()
	var gap := _flat(target.global_position, lead.global_position)
	var seen: bool = _line(lead.global_position + Vector3.UP * 1.5, target.global_position + Vector3.UP * 1.25, lead)
	raid.on_shot()
	var start := t
	var origin := lead.global_position
	var m := {"moved": -1.0, "closest": INF, "calm": -1.0, "found": -1.0}
	await _step(90.0, func() -> bool:
		m.closest = minf(float(m.closest), _nearest_scav(target.global_position))
		if float(m.moved) < 0.0 and _flat(lead.global_position, origin) > 1.5: m.moved = t - start
		if float(m.found) < 0.0:
			for actor: CharacterBody3D in crew.members:
				if not actor.dead and actor.own_visual_time < 0.1: m.found = t - start
		if float(m.calm) < 0.0 and t - start > 3.0 and _all_calm(): m.calm = t - start
		return float(m.found) >= 0.0)
	return {"distance_m": snappedf(gap, 0.1), "in_line_of_sight": seen, "hostile": crew.hostile, "leader_moved_after_s": snappedf(float(m.moved), 0.1), "found_shooter_after_s": snappedf(float(m.found), 0.1), "closest_approach_m": snappedf(float(m.closest), 0.1), "back_to_routine_after_s": snappedf(float(m.calm), 0.1), "orders": _order_kinds(), "said": _said(), "end": _states()}


## Eight seconds of fight, then the player is simply not there any more (taken out of the
## world). Shows the whole search: how long it lasts, how far it reaches, how it ends.
func _gone() -> Dictionary:
	_place_in_view(22.0)
	await _step(1.0)
	_fire_at(_lead(), 12.0)
	await _step(8.0)
	var last_seen := target.global_position
	target.global_position = Vector3(0.0, -80.0, 0.0)
	var lost := t
	var m := {"hunt": -1.0, "guard": -1.0, "calm": -1.0, "reached": -1.0, "far": 0.0, "spots": 0, "moving_max": 0}
	await _step(150.0, func() -> bool:
		if float(m.hunt) < 0.0 and _hunting():
			m.hunt = t - lost
			m.spots = crew.tactics.hunt.spots.size()
		if float(m.guard) < 0.0 and _hunting() and float(crew.tactics.hunt.guard_from) >= 0.0: m.guard = t - lost
		if float(m.reached) < 0.0 and _nearest_scav(last_seen) < 3.0: m.reached = t - lost
		var moving := 0
		for actor: CharacterBody3D in crew.members:
			if actor.dead: continue
			m.far = maxf(float(m.far), _flat(actor.global_position, last_seen) if _hunting() else 0.0)
			if str(crew.tactics.orders.get(actor, {}).get("kind", "")) == "search_sector": moving += 1
		m.moving_max = maxi(int(m.moving_max), moving)
		if float(m.calm) < 0.0 and t - lost > 3.0 and _all_calm(): m.calm = t - lost
		return float(m.calm) >= 0.0 and t - lost > float(m.calm) + 5.0)
	var cleared := 0
	return {"search_started_after_s": snappedf(float(m.hunt), 0.1), "places_to_check": int(m.spots), "reached_last_seen_after_s": snappedf(float(m.reached), 0.1), "searchers_moving_at_once": int(m.moving_max), "stood_guard_from_s": snappedf(float(m.guard), 0.1), "back_to_routine_after_s": snappedf(float(m.calm), 0.1), "search_orders": _count("search_sector"), "said": _said(), "end": _states()}


## One shot fired in the open but beyond the game's 65 m gunfire radius.
func _far_shot() -> Dictionary:
	var lead := _lead()
	target.global_position = Vector3(-42.0, 0.05, -42.0)
	await _step(1.0)
	var gap := _flat(target.global_position, lead.global_position)
	var facing_before := -lead.global_basis.z
	raid.on_shot()
	await _step(3.0)
	# How far off the true direction the crew ends up looking, and how many got low.
	var kneeling := 0
	var worst_angle := 0.0
	for actor: CharacterBody3D in crew.members:
		if actor.crouching: kneeling += 1
		var toward: Vector3 = target.global_position - actor.global_position
		toward.y = 0
		var facing: Vector3 = -actor.global_basis.z
		facing.y = 0
		worst_angle = maxf(worst_angle, rad_to_deg(facing.normalized().angle_to(toward.normalized())))
	var guarded: bool = crew.on_guard()
	var m := {"resumed": -1.0}
	await _step(40.0, func() -> bool:
		if float(m.resumed) < 0.0 and not crew.on_guard(): m.resumed = t
		return float(m.resumed) >= 0.0)
	return {"distance_m": snappedf(gap, 0.1), "hostile": crew.hostile, "stopped_to_watch": guarded, "kneeling": kneeling, "looking_off_by_deg": snappedf(worst_angle, 1.0), "back_to_routine_after_s": snappedf(float(m.resumed), 0.1), "said": _said(), "end": _states()}


## The rear guard is killed by a shot from about 60 m that nobody saw. The shooter stays put.
func _sniped() -> Dictionary:
	var lead := _lead()
	target.global_position = Vector3(20.0, 0.05, -38.0)
	await _step(1.0)
	var victim: CharacterBody3D = crew.members[2]
	var gap := _flat(target.global_position, victim.global_position)
	_fire_at(victim, 500.0)
	var start := t
	var m := {"first_round": -1.0}
	await _step(40.0, func() -> bool:
		if float(m.first_round) < 0.0 and _rounds() > 0: m.first_round = t - start
		return false)
	return {"distance_m": snappedf(gap, 0.1), "first_return_shot_s": snappedf(float(m.first_round), 0.01), "rounds": _per_scav_rounds(), "hits": target.hits_taken.size(), "exposed_share": _exposure(), "orders": _order_kinds(), "said": _said(), "end": _states()}


## The player crouch-walks up behind the crew from 28 m. How close do they get unnoticed?
func _sneak_behind() -> Dictionary:
	var lead := _lead()
	var back := lead.global_basis.z
	back.y = 0
	var start_point := lead.global_position + back.normalized() * 28.0
	start_point.x = clampf(start_point.x, -40, 40)
	start_point.z = clampf(start_point.z, -40, 40)
	start_point.y = 0.05
	target.global_position = raid.navigation.nearest(start_point)
	target.crouching = true
	await _step(0.5)
	var m := {"repath": 0.0}
	var noticed: bool = await _step(90.0, func() -> bool:
		if t >= float(m.repath):
			m.repath = t + 1.0
			# Creep up on whoever is nearest, from behind them.
			var nearest: CharacterBody3D = null
			for actor: CharacterBody3D in crew.members:
				if nearest == null or _flat(actor.global_position, target.global_position) < _flat(nearest.global_position, target.global_position): nearest = actor
			_walk(nearest.global_position, 1.2)
		if crew.warning_active or crew.hostile: return true
		for actor: CharacterBody3D in crew.members:
			if actor.state != actor.AIState.PATROL: return true
		return _nearest_scav(target.global_position) < 1.2)
	var reached: bool = _nearest_scav(target.global_position) < 1.2
	return {"noticed": noticed and not reached, "reached_touching_distance": reached, "distance_at_end_m": snappedf(_nearest_scav(target.global_position), 0.1), "after_s": snappedf(t, 0.1), "said": _said(), "end": _states()}


func _hunting() -> bool:
	return crew.tactics.has_method("hunting") and crew.tactics.hunting()


func _all_calm() -> bool:
	for actor: CharacterBody3D in crew.members:
		if not is_instance_valid(actor) or actor.dead or actor.fleeing: continue
		if crew.tactics.orders.has(actor): return false
		if actor.state in [actor.AIState.COMBAT, actor.AIState.ALERT, actor.AIState.SEARCH]: return false
	return true


func _said() -> Array:
	var output: Array = []
	for entry: Dictionary in raid.notices: output.append("%.1fs %s" % [float(entry.time), str(entry.text)])
	return output

