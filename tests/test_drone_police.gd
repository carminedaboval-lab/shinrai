extends SceneTree

# Robot-police layer on live drones in a real raid: scan beam, patrol scan,
# damage effects, attack flash and backup dispatch. Allows a slow park load.
# Headless: godot --headless --path . --script res://tests/test_drone_police.gd
# Capture: omit --headless and append -- --render

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	if ok: print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)
		print("FAIL ", label)

func _run() -> void:
	var render := "--render" in OS.get_cmdline_user_args()
	if render:
		root.size = Vector2i(1920, 1080)
		root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_drone_police_qa.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 300000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	raid.start_run()
	raid.player.process_mode = Node.PROCESS_MODE_DISABLED
	await _physics(20)
	var director: Node = scene.get_node("PoliceDroneGroups")
	var packs: Array = director.groups
	_check(packs.size() == 3, "three police packs exist")
	var pack: Node3D = packs[0]
	var drones: Array = pack.living_members()
	var drone: CharacterBody3D = drones[0]
	var brain: Node = drone.get_node("Awareness")
	await process_frame
	_check(drone.scan_beam != null and drone.scan_beam.brain == brain, "scan beam is wired to its awareness")
	_check(drone.damage_fx != null, "damage effects exist")

	# Stop-and-scan.
	# The pack's own tick overrides forced state, so read the beam synchronously.
	pack._update_area_scan(.016, drones, true)
	drone.scan_beam._process(.016)
	_check(drone.scan_beam._mode == "sweep" and drone.visual.area_scan, "area scan switches on beam and posture")
	pack._update_area_scan(.016, drones, false)
	drone.scan_beam._process(.016)
	_check(drone.scan_beam._mode == "", "area scan switches off")

	# Beam follows alert state.
	brain.last_known = drone.global_position + drone.global_basis.z * 6.0
	brain.change_state("IDENTIFY")
	drone.scan_beam._process(.016)
	_check(drone.scan_beam._mode == "lock", "identify locks an amber beam")
	brain.change_state("PATROL")
	drone.scan_beam._process(.016)

	# Attack flash.
	drone.combat.attack_started.emit("Slash")
	_check(drone.police_lights.attack_flash > 0.0, "attack start flashes the lightbar")

	# Damage states.
	var victim: CharacterBody3D = drones[1]
	victim.health.damage_body(45.0)
	await process_frame
	_check(victim.damage_fx._sparking, "sparks start below 60 percent")
	victim.health.damage_body(30.0)
	await process_frame
	_check(victim.damage_fx._smoke != null and victim.damage_fx._smoke.emitting and victim.police_lights.damage_flicker, "smoke and flicker below 30 percent")

	# Backup dispatch.
	var caller: Node3D = packs[1]
	var responder: Node3D = null
	var point: Vector3 = caller.living_members()[0].global_position
	director.backup_ready_at = 0.0
	for candidate: Node3D in packs:
		print("INFO pack=%s available=%s battle=%s alive=%d distance=%.0fm run_time=%.1f" % [candidate.name, candidate.is_available_for_dispatch(), candidate.battle_active, candidate.living_members().size(), candidate.living_members()[0].global_position.distance_to(point), float(raid.run_time)])
	director.request_backup(caller, point)
	for candidate: Node3D in packs:
		if candidate.backup_goal.is_finite(): responder = candidate
	_check(responder != null and responder != caller, "nearest free pack is dispatched")
	_check(str(raid.notice).begins_with("DISPATCH"), "player is warned of backup")
	var second_ready: float = director.backup_ready_at
	director.request_backup(packs[2], point)
	_check(director.backup_ready_at == second_ready, "backup cooldown blocks a second dispatch")
	if responder != null:
		var start: Vector3 = responder.living_members()[0].global_position
		var goal: Vector3 = responder.backup_goal
		var moved := 0.0
		var ticked := 0
		var outcome := "timed out"
		while ticked < 55:
			await _wait(5.0)
			ticked += 1
			var lead: CharacterBody3D = responder.leader
			moved = start.distance_to(lead.global_position)
			var spread: Array[int] = []
			for member: CharacterBody3D in responder.living_members():
				spread.append(roundi(member.global_position.distance_to(goal)))
			print("INFO responder t=%ds moved=%.1fm status=%s path=%d goal_left=%.0fm spread=%s remaining=%.0f" % [ticked * 5, moved, lead.nav_status, lead.nav_path.size(), lead.global_position.distance_to(goal), spread, float(responder.backup_remaining)])
			if not responder.backup_goal.is_finite():
				outcome = "gave up"
				for member: CharacterBody3D in responder.living_members():
					if member.global_position.distance_to(goal) < 15.0: outcome = "arrived"
				break
		print("INFO dispatch outcome=%s after %ds" % [outcome, ticked * 5])
		_check(moved > 3.0, "dispatched pack is travelling")
		_check(outcome == "arrived", "dispatched pack reaches the scene")
		var calm := 0
		for member: CharacterBody3D in responder.living_members():
			if member.nav_urgent: calm += 1
		_check(calm == 0, "urgent routing clears when the dispatch ends")

	# Being shot must not restart an identification, and a confirmed contact is
	# reacquired quickly.
	var lone: CharacterBody3D = packs[2].living_members()[0]
	var lone_brain: Node = lone.get_node("Awareness")
	var player_body: Node3D = raid.player
	lone_brain.target = player_body
	lone_brain.change_state("IDENTIFY")
	lone_brain.state_time = .5
	lone_brain.receive_damage_contact(player_body)
	_check(lone_brain.state == "IDENTIFY" and lone_brain.state_time >= .5, "a hit does not restart identification")
	_check(is_equal_approx(lone_brain._identify_hold(), lone_brain.IDENTIFY_DURATION), "first contact takes the full identify")
	packs[2].battle_active = true
	packs[2].battle_target_id = player_body.get_instance_id()
	_check(is_equal_approx(lone_brain._identify_hold(), lone_brain.REACQUIRE_DURATION), "confirmed contact is reacquired fast")
	packs[2].battle_active = false
	packs[2].battle_target_id = 0
	lone_brain.change_state("PATROL")

	# First identification warns the player, once per cooldown.
	director.warning_ready_at = 0.0
	raid.notice = ""
	lone_brain.target = player_body
	lone_brain.change_state("IDENTIFY")
	_check(str(raid.notice).begins_with("POLICE"), "identification warns the player")
	var warned_until: float = director.warning_ready_at
	lone_brain.change_state("PATROL")
	raid.notice = ""
	lone_brain.change_state("IDENTIFY")
	_check(director.warning_ready_at == warned_until and str(raid.notice) == "", "warning respects its cooldown")
	lone_brain.change_state("PATROL")

	# Stance clips: every one resolves to Body tracks and stays a small motion.
	var rig: Node3D = lone.visual
	for clip: String in ["NoticeLeft", "NoticeRight", "TargetConfirm", "CombatEnter", "CombatIdle", "Search", "CombatExit", "LookAround"]:
		rig.play_body_clip(clip)
		_check(rig._body_clip != null, "body clip %s has a Body track" % clip)
		var turn_peak := 0.0
		var shift_peak := 0.0
		if rig._body_clip != null:
			for sample: int in 40:
				var at: float = rig._body_clip.length * sample / 39.0
				if rig._body_clip_rot_track >= 0:
					var turn: Quaternion = rig._body_clip.rotation_track_interpolate(rig._body_clip_rot_track, at) * rig._body_clip_base_rot.inverse()
					# q and -q are the same rotation, so a full circle reads as none.
					turn_peak = maxf(turn_peak, minf(turn.get_angle(), TAU - turn.get_angle()))
				if rig._body_clip_pos_track >= 0:
					shift_peak = maxf(shift_peak, rig._body_clip.position_track_interpolate(rig._body_clip_pos_track, at).distance_to(rig._body_clip_base_pos))
		print("INFO clip=%s length=%.2fs turn=%.2frad shift=%.3fm" % [clip, rig._body_clip.length if rig._body_clip != null else 0.0, turn_peak, shift_peak])
	rig.stop_body_clip()

	# A state change plays its stance, and the rig really takes the pose.
	# Awareness off: with the player this close the drone would really attack.
	lone_brain.enabled = false
	lone_brain.change_state("PATROL")
	var wait_ground := 0
	while lone.mode != "GROUND" and wait_ground < 300:
		await physics_frame
		wait_ground += 1
	rig.set_expression("PATROL")
	rig.set_expression("IDENTIFY", 0.0)
	await _physics(14)
	print("INFO stance clip=%s weight=%.2f speed=%.2f" % [rig._body_clip_name, rig._body_clip_weight, Vector2(lone.velocity.x, lone.velocity.z).length()])
	# A moving drone plays stances at 30%, standing still at full strength.
	_check(rig._body_clip_name == "TargetConfirm" and rig._body_clip_weight > .25, "identify plays the confirm stance")
	# A calm drone may start its own area scan, or freeze when far from the camera.
	rig.lod_enabled = false
	rig.area_scan = false
	rig.set_expression("PATROL")
	await _physics(30)
	print("INFO calm clip=%s weight=%.2f scan=%s" % [rig._body_clip_name, rig._body_clip_weight, rig.area_scan])
	_check(rig._body_clip_weight < .5, "stance fades when calm")
	rig.lod_enabled = true

	# Hits jolt the chassis and slow the motors.
	var hit_from: Vector3 = lone.global_position + lone.global_basis.z * 5.0
	raid.player.global_position = hit_from
	lone.dodge_chance = 0.0
	lone.take_damage(1.0, raid.player)
	_check(lone.stagger_time > 0.0 and rig.hit_tilt_velocity.x < 0.0, "a frontal hit pitches the nose up and staggers")
	var hit_peak := 0.0
	for tick: int in 12:
		await physics_frame
		hit_peak = maxf(hit_peak, absf(rig.hit_tilt.x))
	print("INFO hit tilt peak=%.3frad" % hit_peak)
	_check(hit_peak > .03 and hit_peak < .25, "hit jolt is visible but not violent")
	await _physics(90)
	_check(rig.hit_tilt.length() < .01, "hit jolt settles")

	# Under fire in a fight, a drone can dodge and then carry on.
	lone.set_physics_process(true)
	lone.dodge_chance = 1.0
	lone.dodge_ready_at = 0
	lone.cooldown = 0.0
	var dodges_before: int = int(lone.accepted.get("DodgeLeft", 0)) + int(lone.accepted.get("DodgeRight", 0))
	var refused_before: int = lone.blocked_attempts
	lone_brain.state = "COMBAT"
	lone.take_damage(1.0, raid.player)
	var dodged: bool = int(lone.accepted.get("DodgeLeft", 0)) + int(lone.accepted.get("DodgeRight", 0)) > dodges_before
	_check(dodged or lone.blocked_attempts > refused_before, "a hit in combat tries a dodge")
	print("INFO dodge started=%s mode=%s" % [dodged, lone.mode])
	lone_brain.state = "PATROL"
	await _wait(2.5)
	_check(lone.mode == "GROUND", "drone lands from the dodge")
	lone.dodge_chance = .4
	raid.player.global_position += Vector3.UP * 100.0
	lone_brain.enabled = true

	# A wreck must not keep an attack flash lit.
	var flash_lights: Node = lone.police_lights
	flash_lights.flash_attack()
	flash_lights.set_alert_state("DISABLED")
	_check(flash_lights.strengths == Vector2.ZERO, "disabled lightbar ignores an attack flash")
	flash_lights.set_alert_state("PATROL")

	if render:
		# Hold the pack so the sweep stays on for the capture.
		pack.set_physics_process(false)
		for member: CharacterBody3D in pack.living_members():
			member.get_node("Awareness").enabled = false
			member.set_locomotion(0, 0)
		pack._update_area_scan(.016, pack.living_members(), true)
		# Side-on: from the front the camera sits inside the cone.
		var eye: Vector3 = victim.global_position + victim.global_basis.x * 7.0 + victim.global_basis.z * 3.0 + Vector3.UP * .3
		raid.player.global_position = eye
		raid.player.look_at(Vector3(victim.global_position.x, eye.y, victim.global_position.z) + victim.global_basis.z * 3.0)
		await _wait(2.5)
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://visual_fx_qa")
		var path := ProjectSettings.globalize_path("user://visual_fx_qa/drone_police.png")
		root.get_texture().get_image().save_png(path)
		print("DRONE_CAPTURE ", path)
		var locked: Node = victim.get_node("Awareness")
		locked.last_known = victim.global_position + victim.global_basis.z * 8.0
		locked.change_state("IDENTIFY")
		await _wait(.4)
		await RenderingServer.frame_post_draw
		var lock_path := ProjectSettings.globalize_path("user://visual_fx_qa/drone_police_lock.png")
		root.get_texture().get_image().save_png(lock_path)
		print("DRONE_CAPTURE ", lock_path)
		locked.change_state("PATROL")

	# Destruction leaves a smoking wreck, and nothing errors after death.
	print("INFO victim mode=%s scale=%s skeleton=%s" % [victim.mode, victim.global_basis.get_scale(), victim.visual.skeleton.global_basis.get_scale()])
	victim.health.damage_body(100.0)
	await _physics(30)
	_check(victim.dead, "drone destroys")
	if is_instance_valid(victim) and is_instance_valid(victim.damage_fx):
		_check(victim.damage_fx._smoke.emitting and victim.damage_fx._wreck_time > 0.0, "wreck keeps smoking")
	await _test_smarter_combat(raid, director, packs)
	print("DRONE_POLICE_RESULT: %d failures" % failures)
	quit(1 if failures > 0 else 0)

# Packmate loss, the hunt after losing a contact, and wounded units falling back.
func _test_smarter_combat(raid: Node, director: Node, packs: Array) -> void:
	raid.player.global_position += Vector3.UP * 100.0
	for each: Node3D in packs:
		each._reset_battle()
		each.backup_goal = Vector3.INF
		for member: CharacterBody3D in each.living_members():
			var calm_brain: Node = member.get_node("Awareness")
			calm_brain.enabled = true
			calm_brain.change_state("PATROL")
	director.backup_ready_at = 0.0
	var wary: Node3D = packs[2]
	var crew: Array = wary.living_members()
	var fallen: CharacterBody3D = crew[0]
	var wreck: Vector3 = fallen.global_position
	var run_clock: float = float(raid.run_time)
	print("INFO fallen mode=%s scale=%s skeleton=%s" % [fallen.mode, fallen.global_basis.get_scale(), fallen.visual.skeleton.global_basis.get_scale()])
	fallen.health.damage_body(100.0)
	var alerted := true
	var survivors: Array = wary.living_members()
	for member: CharacterBody3D in survivors:
		var brain: Node = member.get_node("Awareness")
		alerted = alerted and brain.state == "SEARCH" and brain.last_known.distance_to(wreck) < .01
	_check(survivors.size() == 4 and alerted, "packmates search a destroyed unit's wreck")
	_check(director.backup_ready_at > run_clock, "a destroyed unit is radioed in")
	var spread := true
	for a: int in survivors.size():
		for b: int in range(a + 1, survivors.size()):
			var first: Vector3 = survivors[a].get_node("Awareness").search_goal
			var second: Vector3 = survivors[b].get_node("Awareness").search_goal
			print("INFO search goals %.1f m apart" % Vector2(first.x - second.x, first.z - second.z).length())
			spread = spread and Vector2(first.x - second.x, first.z - second.z).length() > 1.0
	_check(spread, "the pack fans out instead of stacking on one spot")

	# Searches reach the contact, and lead its sighted heading.
	var hunter: CharacterBody3D = survivors[0]
	var hunter_brain: Node = hunter.get_node("Awareness")
	# Where the pack ends up varies; aim the test along a heading with open ground 18 m out.
	var far: Vector3 = hunter.global_position + hunter.global_basis.z * 18.0
	for turn: int in 8:
		var candidate: Vector3 = hunter.global_position + hunter.global_basis.z.rotated(Vector3.UP, turn * PI / 4.0) * 18.0
		var projected: Variant = hunter.navigation_source.get_nearest_walkable_world(candidate)
		if projected is Vector3 and Vector2(projected.x - candidate.x, projected.z - candidate.z).length() < 1.0:
			far = candidate
			break
	hunter_brain.last_known = far
	hunter_brain._begin_search()
	var reach: float = Vector2(hunter_brain.search_goal.x - hunter.global_position.x, hunter_brain.search_goal.z - hunter.global_position.z).length()
	print("INFO search reach=%.1f m" % reach)
	_check(reach > 8.0, "a search travels well past the old 6 m")
	wary.battle_active = true
	wary.battle_target_id = raid.player.get_instance_id()
	wary.observed_contact = far
	wary.lost_velocity = hunter.global_basis.x * 3.0
	var led: Vector3 = wary.search_point(survivors[1], far, 0)
	var lead_along: float = (led - far).dot(hunter.global_basis.x)
	print("INFO search lead=%.1f m along the sighted heading" % lead_along)
	_check(lead_along > 2.0, "a search leads the contact's sighted heading")
	hunter_brain.search_travel = false
	hunter_brain.search_scan_time = 99.0
	hunter_brain.search_step(.016, 0.0)
	_check(hunter_brain.state == "SEARCH" and hunter_brain.search_leg == 1 and hunter_brain.search_travel, "a search sweeps a second leg")
	for leg: int in range(1, hunter_brain.SEARCH_LEGS):
		hunter_brain.search_travel = false
		hunter_brain.search_scan_time = 99.0
		hunter_brain.search_step(.016, 0.0)
	_check(hunter_brain.state == "RELAX", "a search gives up after its sweep")

	# A wounded unit falls back from the contact, once.
	var hurt: CharacterBody3D = survivors[1]
	var hurt_brain: Node = hurt.get_node("Awareness")
	hurt.dodge_chance = 0.0
	wary.observed_contact = hurt.global_position + hurt.global_basis.z * 6.0
	hurt_brain.last_known = wary.observed_contact
	hurt_brain.state = "COMBAT"
	var waits := 0
	while hurt.mode != "GROUND" and waits < 300:
		await physics_frame
		waits += 1
	hurt.take_damage(1.0, null)
	_check(not wary.withdrawals.has(hurt), "a healthy unit keeps fighting")
	hurt.health.body_hp = 30.0
	var cover_started := Time.get_ticks_usec()
	hurt.take_damage(1.0, null)
	print("INFO cover search took %d usec" % (Time.get_ticks_usec() - cover_started))
	_check(wary.withdrawals.has(hurt), "a badly damaged unit withdraws")
	if wary.withdrawals.has(hurt):
		var cover: Vector3 = wary.withdrawal_goal(hurt)
		var gap_before: float = hurt.global_position.distance_to(cover)
		print("INFO cover %.1f m away, %.1f m from contact" % [gap_before, cover.distance_to(wary.observed_contact)])
		_check(cover.distance_to(wary.observed_contact) > hurt.global_position.distance_to(wary.observed_contact), "cover is farther from the contact")
		wary._select_gunner(wary.living_members())
		_check(wary.gunner != hurt, "a withdrawing unit is not picked as gunner")
		# A packmate at its shoulder can block the turn until it crabs clear.
		var gap_after: float = gap_before
		var waited := 0.0
		while gap_after >= gap_before - 1.0 and waited < 8.0 and wary.withdrawals.has(hurt):
			await _wait(.5)
			waited += .5
			gap_after = hurt.global_position.distance_to(cover)
		print("INFO withdrew %.1f m in %.1f s, nav=%s still=%s" % [gap_before - gap_after, waited, hurt.nav_status, wary.withdrawals.has(hurt)])
		_check(gap_after < gap_before - 1.0, "a withdrawing unit actually moves to cover")
	wary.withdrawals.clear()
	hurt.take_damage(1.0, null)
	_check(not wary.withdrawals.has(hurt), "a unit withdraws only once per battle")
	_check(wary.search_point(hurt, far, 0) == hurt.global_position, "a wounded unit stays out of the hunt")
	hurt.dodge_chance = .4

	# A newer sighting redirects a responding pack, at a limited rate.
	var runner: Node3D = packs[1]
	var first_report: Vector3 = raid.navigation.nearest(hunter.global_position)
	var newer: Vector3 = packs[0].living_members()[0].global_position
	runner.dispatch_to(first_report)
	director.backup_update_at = 0.0
	director.contact_update(newer)
	var redirected: Vector3 = runner.backup_goal
	print("INFO backup moved %.1f m" % redirected.distance_to(first_report))
	_check(redirected.distance_to(first_report) > director.BACKUP_UPDATE_MOVE, "a new sighting redirects responding backup")
	_check(runner.backup_points.size() == runner.living_members().size(), "redirected backup keeps a spot for every drone")
	director.contact_update(first_report)
	_check(runner.backup_goal == redirected, "backup redirects are rate limited")
	runner._end_dispatch(runner.living_members(), false)

func _physics(count: int) -> void:
	for i in count:
		await physics_frame

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
