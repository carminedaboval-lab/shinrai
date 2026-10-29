extends SceneTree

const Run = preload("res://scripts/extraction_run.gd")
const Hud = preload("res://scripts/extraction_hud.gd")
var checks := 0
var failures: Array[String] = []

class FakePlayer extends CharacterBody3D:
	var health := 62.0
	var stamina := 37.0
	var max_stamina := 100.0
	var crouching := true
	var sprinting := false
	var ammo := 19
	var reserve := 80
	var kills := 0
	var reloading := false
	var ads := false
	var ads_blend := 0.0
	var camera: Camera3D
	func _ready() -> void:
		camera = Camera3D.new()
		camera.position.y = 1.58
		camera.current = true
		add_child(camera)

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	root.size = Vector2i(1920, 1080)
	var run = Run.new()
	var player := FakePlayer.new()
	root.add_child(player)
	run.player = player
	run.medkits = 2
	run.bag.assign([Run.ITEMS[0].duplicate(), Run.ITEMS[1].duplicate()])
	run.relays = 1
	run.remaining = 600
	var hud = Hud.new()
	root.add_child(hud)
	hud.show_hq(run)
	var hidden_all := true
	for control: Control in hud.game_controls:
		hidden_all = hidden_all and not control.visible
	_check(hidden_all and hud.overlay.visible, "HQ hides every gameplay HUD element behind menu")
	hud.show_raid()
	hud.update_raid(run)
	await process_frame
	await process_frame
	_check(not hud.overlay.visible and hud.raid_status.visible and hud.ammo_status.visible and hud.mission_status.visible, "raid restores all three corner status panels")
	_check(hud.raid_status.health == 62 and hud.raid_status.stamina == 37 and hud.raid_status.max_stamina == 100, "HUD reads live health and stamina")
	_check(hud.raid_status.crouching and not hud.raid_status.sprinting, "HUD reads actual stance")
	_check(hud.ammo_status.medkits == 2 and hud.ammo_status.cargo == 2 and hud.ammo_status.capacity == 6, "HUD reads exact medical and cargo counts")
	_check(hud.vitals.text == "19 / 080" and hud.telemetry.text == "10:00", "HUD formats actual magazine reserve and raid clock")
	_check(hud.mission_status.relays == 1 and not hud.mission_status.urgent, "relay and urgency indicators reflect live objective state")
	for control: Control in [hud.raid_status, hud.ammo_status, hud.mission_status]:
		_check(Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(control.get_global_rect()), "corner panel fits1920x1080: " + str(control.name))
	_check(hud.objectives.text.is_empty() and not hud.prompt.visible and not hud.progress.visible and not hud.message.visible, "idle raid omits inactive prompts and progress")
	player.health = -5
	player.stamina = 9
	player.crouching = false
	player.sprinting = true
	player.reloading = true
	run.remaining = 89
	run.prompt_text = "H  ·  Healing"
	run.progress_ratio = 0.6
	hud.update_raid(run)
	_check(hud.raid_status.health == 0 and hud.raid_status.stamina == 9 and hud.raid_status.sprinting, "changing live values reach HUD with bounded health")
	_check(hud.ammo_status.reloading and hud.mission_status.urgent and hud.telemetry.text == "01:29", "reload and low-time urgency refresh immediately")
	_check(hud.prompt.visible and hud.prompt.text == run.prompt_text and hud.progress.visible and is_equal_approx(hud.progress.value, 60), "actual treatment prompt and progress reach HUD")
	run.exits.assign([{"id": "gate", "title": "South gate extraction", "position": Vector3(0, 0, -10)}])
	hud.update_raid(run)
	_check(hud.marker.visible, "in-view objective shows waypoint while aiming from hip")
	player.ads = true
	hud.update_raid(run)
	_check(not hud.marker.visible, "ADS suppresses waypoint to keep sights clear")
	player.ads = false
	player.ads_blend = 0.5
	hud.update_raid(run)
	_check(not hud.marker.visible, "transitioning ADS continues to suppress waypoint")
	player.ads_blend = 0
	run.notice = "Medkit applied"
	run.notice_time = 3.2
	hud.update_raid(run)
	_check(hud.message.visible and hud.message.text == run.notice and hud.message.modulate.a > 0.8, "new event notice displays at full intended opacity")
	hud._notice_started_at = Time.get_ticks_msec() / 1000.0 - 4.0
	run.notice_time = 0.2
	hud.update_raid(run)
	_check(not hud.message.visible, "expired notice fades out")
	run.notice_time = 3.2
	hud.update_raid(run)
	_check(hud.message.visible and hud.message.modulate.a > 0.8, "repeated identical new event restarts notice fade")
	hud.show_pause(run, false)
	hidden_all = true
	for control: Control in hud.game_controls:
		hidden_all = hidden_all and not control.visible
	_check(hidden_all and hud.overlay.visible, "pause hides live corner panels and transient widgets")
	hud.queue_free()
	player.queue_free()
	run.free()
	await process_frame
	print("RAID_HUD_TEST_RESULT: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures:
		print("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
