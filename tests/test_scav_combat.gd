extends SceneTree

# The human crew's combat reactions, in the real raid scene with the real planner.
# Headless: godot --headless --path . --script res://tests/test_scav_combat.gd

var checks := 0
var failures := 0
var crew: Node3D
var raid: Node
var lead: CharacterBody3D
var scout: CharacterBody3D
var rear: CharacterBody3D

class NoRoutes extends RefCounted:
	func nearest(point: Vector3) -> Vector3: return point
	func path(_from: Vector3, _to: Vector3) -> PackedVector3Array: return PackedVector3Array()

func _initialize() -> void:
	_run.call_deferred()

func _check(label: String, passed: bool, detail: Variant = "") -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s %s" % ["PASS" if passed else "FAIL", label, str(detail)])

func _run() -> void:
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_scav_combat_qa.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	raid = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 300000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	raid.start_run()
	raid.player.process_mode = Node.PROCESS_MODE_DISABLED
	while raid.has_method("insertion_grace") and raid.insertion_grace():
		await process_frame
	crew = scene.get_node("ScavPatrolCrew")
	while not crew.ready_for_use and Time.get_ticks_msec() < deadline:
		await process_frame
	lead = crew.members[0]; scout = crew.members[1]; rear = crew.members[2]
	_test_aim()
	_test_near_miss()
	await _test_join_and_fire()
	await _test_reload()
	_test_heading()
	await _test_casualties()
	print("SCAV_COMBAT %d checks, %d failures" % [checks, failures])
	print("SCAV_COMBAT_RESULT %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame
		raid.player.set("health", 100.0)

func _test_aim() -> void:
	lead.personal_visible_for = 0.0
	var fresh: float = lead.aim_spread(20.0)
	lead.personal_visible_for = 5.0
	var tracked: float = lead.aim_spread(20.0)
	_check("a tracked target is easier to hit than a fresh sighting", tracked < fresh, "%.2f<%.2f" % [tracked, fresh])
	raid.player.velocity = (raid.player.global_position - lead.global_position).cross(Vector3.UP).normalized() * 5.0
	var crossing: float = lead.aim_spread(20.0)
	raid.player.velocity = (raid.player.global_position - lead.global_position).normalized() * 5.0
	var closing: float = lead.aim_spread(20.0)
	raid.player.velocity = Vector3.ZERO
	_check("a crossing target is harder than a closing one", crossing > closing * 1.5, "%.2f>%.2f" % [crossing, closing])
	lead.health = lead.max_health * .3
	_check("wounds spoil aim", lead.aim_spread(20.0) > tracked, lead.aim_spread(20.0))
	lead.health = lead.max_health

func _test_near_miss() -> void:
	rear.pinned_time = 0.0
	rear.suppression = 0.0
	rear.near_miss()
	_check("one round past only flinches", rear.pinned_time == 0.0 and rear.suppression > 0.0, rear.suppression)
	var before: float = rear.aim_spread(20.0)
	rear.near_miss()
	rear.near_miss()
	_check("sustained fire puts a head down", rear.pinned_time > 0.0, rear.pinned_time)
	_check("suppression spoils aim", rear.aim_spread(20.0) > before, rear.aim_spread(20.0))
	rear.pinned_time = 0.0
	rear.suppression = 0.0

func _test_join_and_fire() -> void:
	# Contact on the leader only: the other two are at their own jobs elsewhere.
	raid.player.global_position = lead.global_position - lead.global_basis.z * 16.0 + Vector3.UP * .3
	await physics_frame
	var point: Vector3 = raid.player.global_position
	var clock_start := Time.get_ticks_usec()
	var planned: bool = crew.tactics._join_fight(scout, point)
	var planned_ms: float = (Time.get_ticks_usec() - clock_start) * .001
	clock_start = Time.get_ticks_usec()
	crew.tactics.find_cover(lead, point)
	print("INFO join plan %.1f ms (planned=%s), ordinary cover search %.1f ms" % [planned_ms, planned, (Time.get_ticks_usec() - clock_start) * .001])
	crew.tactics.orders.erase(scout)
	var start_scout: float = _walk_left(scout, point)
	var start_rear: float = _walk_left(rear, point)
	crew.make_hostile(lead, "gunfire")
	crew.tactics.report(lead, point, "visual")
	var first_sight := -1.0
	var first_shot := -1.0
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 20000:
		await _wait(.25)
		crew.tactics.report(lead, point, "visual")
		var now: float = (Time.get_ticks_msec() - started) * .001
		# A held view, not a one-frame sliver past a post the shooter cannot use.
		if first_sight < 0.0 and lead.personal_visible_for >= .2: first_sight = now
		if first_shot < 0.0 and lead.rounds_fired > 0: first_shot = now
	print("INFO leader held a view of the player at %.1f s, first shot at %.1f s" % [first_sight, first_shot])
	# The view can come mid-walk, so this allows for finishing the move and peeking.
	_check("the leader fires within 4 s of a held view", first_sight >= 0.0 and first_shot >= 0.0 and first_shot - first_sight < 4.0, first_shot - first_sight)
	var end_scout: float = _walk_left(scout, point)
	var end_rear: float = _walk_left(rear, point)
	# Measured along the real route: buildings can make 40 m of air a 70 m walk.
	_check("a distant crewmate closes in", end_scout < 24.0 or end_scout < start_scout - 15.0, "%.0f->%.0f m walk" % [start_scout, end_scout])
	_check("the other crewmate closes in", end_rear < 24.0 or end_rear < start_rear - 15.0, "%.0f->%.0f m walk" % [start_rear, end_rear])
	_check("the rifle stays up between peeks", lead.weapon_up() or crew.tactics.orders.is_empty(), crew.tactics.orders.get(lead, {}).get("kind", "-"))

func _walk_left(actor: CharacterBody3D, point: Vector3) -> float:
	var route: PackedVector3Array = crew.get_path_world(actor.global_position, crew.get_nearest_walkable_world(point))
	return crew.tactics.path_length(route, actor.global_position)

func _test_reload() -> void:
	var shooter: CharacterBody3D = lead
	shooter.weapon_rounds = 0
	shooter.magazine_reload_remaining = 0.0
	await physics_frame
	await physics_frame
	_check("an empty rifle reloads without needing to see anyone", shooter.magazine_reload_remaining > 0.0, shooter.magazine_reload_remaining)
	_check("reloading lowers the rifle", not shooter.weapon_up())
	var magazines: int = shooter.spare_magazines
	# Measured in game time: a slow machine stretches this in wall-clock time.
	var patience := Time.get_ticks_msec() + 12000
	while shooter.magazine_reload_remaining > 0.0 and Time.get_ticks_msec() < patience:
		await _wait(.1)
	# Shooting straight after the reload is fine: only a fresh magazine gets here.
	_check("the reload finishes with a fresh magazine", shooter.weapon_rounds > 20 and shooter.spare_magazines == magazines - 1, "%d rounds, %d spare" % [shooter.weapon_rounds, shooter.spare_magazines])
	shooter.weapon_rounds = 0
	shooter.spare_magazines = 0
	await physics_frame
	_check("the last magazine gone leaves the rifle empty", shooter.out_of_ammo() and not shooter.can_fire_now())
	shooter.weapon_rounds = 30
	shooter.spare_magazines = 1

func _test_heading() -> void:
	var tactics: RefCounted = crew.tactics
	tactics._last_sighting = {}
	var from := Vector3(100.0, 0.0, 0.0)
	tactics.report(lead, from, "visual")
	tactics.clock += 1.0
	tactics.report(lead, from + Vector3(4.0, 0.0, 0.0), "visual")
	var heading: Vector3 = tactics.knowledge[lead].heading
	_check("two sightings give a direction of travel", heading.distance_to(Vector3(4.0, 0.0, 0.0)) < .01, heading)
	tactics.clock += .1
	tactics.report(scout, from + Vector3(4.2, 0.0, 0.0), "visual")
	_check("a second report of one glimpse keeps that direction", (tactics.knowledge[lead].heading as Vector3).distance_to(heading) < .01)
	tactics.report(lead, from, "sound")
	_check("a sound carries no direction of travel", (tactics.knowledge[scout].get("heading", Vector3.ZERO) as Vector3).length() < 5.0)

func _test_casualties() -> void:
	# Keep the actors from reacting to the leftover contact while hit points change.
	crew.tactics.knowledge.clear()
	scout.pinned_time = 0.0
	rear.global_position = lead.global_position + Vector3(4.0, 0.0, 0.0)
	scout.global_position = lead.global_position + Vector3(-4.0, 0.0, 0.0)
	lead.pinned_time = 0.0
	scout.take_damage(500.0, raid.player)
	await physics_frame
	_check("a casualty makes the survivors duck", lead.pinned_time > 0.0 or rear.pinned_time > 0.0, "%.2f %.2f" % [lead.pinned_time, rear.pinned_time])
	_check("two survivors keep fighting", not crew.morale_broken)
	rear.take_damage(500.0, raid.player)
	await physics_frame
	_check("a healthy last man holds on", not crew.morale_broken, lead.health)
	# With every way out blocked there is nothing left to do but keep fighting.
	var real_navigation: RefCounted = crew.town_navigation
	crew.town_navigation = NoRoutes.new()
	lead.take_damage(lead.max_health * .5, raid.player)
	await physics_frame
	crew.town_navigation = real_navigation
	_check("a cornered last man keeps fighting", not crew.morale_broken and not lead.fleeing and lead.is_in_group("extraction_hostiles"), "broken=%s" % crew.morale_broken)
	_check("nobody can surrender any more", not "surrendered" in lead)
	lead.take_damage(1.0, raid.player)
	await physics_frame
	_check("a wounded last man breaks off and runs", crew.morale_broken and lead.fleeing, "fleeing=%s" % lead.fleeing)
	# The real corpse timer is 30 s: what it does, then a crew tick over the gap.
	crew.forget(scout)
	scout.queue_free()
	await _wait(.5)
	crew.player_fired()
	crew.social.interrupt()
	crew.activity.interrupt("casualty")
	_check("a removed corpse leaves the crew list", not crew.members.has(scout) and crew.members.size() == 2, crew.members.size())
