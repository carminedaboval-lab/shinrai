extends SceneTree

# Renders the in-raid vitals and weapon panels in several states side by side.
# godot --path . --resolution 1600x900 --script res://tests/test_hud_preview.gd
# Saves user://visual_fx_qa/hud_preview.png and quits.

const Hud := preload("res://scripts/extraction_hud.gd")
const UIStyle := preload("res://scripts/hud/shinrai_ui_style.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	UIStyle.apply_fonts(theme)
	canvas.theme = theme
	root.add_child(canvas)
	var backdrop := TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var shot := Image.load_from_file(ProjectSettings.globalize_path("user://visual_fx_qa/visual_fx.png"))
	if shot != null:
		backdrop.texture = ImageTexture.create_from_image(shot)
	canvas.add_child(backdrop)

	var calm := _vitals(canvas, Vector2(10, 10), "CALM")
	var hurt := _vitals(canvas, Vector2(400, 10), "HIT IN COMBAT")
	var heal := _vitals(canvas, Vector2(790, 10), "HEALING, WINDED")
	var check := _vitals(canvas, Vector2(1180, 10), "SELF CHECK (V)")
	hurt.combat = true
	hurt.stun_remaining = 1.4
	hurt.sprinting = true
	heal.healing = true
	heal.health = 52.0
	heal.actual_hp = 52.0
	heal.treatment_ratio = 0.4
	heal.stamina = 12.0
	heal.medkits = 2
	check.inspecting = true
	check.health = 81.0
	check.actual_hp = 81.0
	check.reserve_energy = 64.0
	check.stamina = 70.0
	for status in [calm, hurt, heal, check]:
		status.accept_health()

	var full := _ammo(canvas, Vector2(10, 480), "FULL", 32, 96)
	var low := _ammo(canvas, Vector2(400, 480), "LOW", 4, 64)
	var empty := _ammo(canvas, Vector2(790, 480), "EMPTY", 0, 32)
	var reload := _ammo(canvas, Vector2(1180, 480), "RELOADING", 0, 32)
	reload.reloading = true
	reload.reload_ratio = 0.6
	low.cargo = 3
	low.cargo_mass_kg = 4.2
	full.last_ammo = 31
	var prompt_specs := [["E  ·  Search", 0.0], ["E  ·  Recover relay", 0.6], ["Extracting · 9s", 0.0]]
	for i in prompt_specs.size():
		_caption(canvas, Vector2(10 + i * 530, 720), "PROMPT")
		var signal_view = Hud.InteractionSignal.new()
		signal_view.position = Vector2(10 + i * 530, 750)
		signal_view.size = Vector2(520, 60)
		signal_view.text = prompt_specs[i][0]
		signal_view.ratio = prompt_specs[i][1]
		canvas.add_child(signal_view)
	for i in 20:
		await process_frame
	# Damage lands just before the capture so the lingering red chunk shows.
	hurt.health = 48.0
	hurt.actual_hp = 48.0
	hurt.accept_health()
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("user://visual_fx_qa/hud_preview.png")
	root.get_texture().get_image().save_png(path)
	print("HUD_PREVIEW ", path)
	quit()

func _vitals(parent: Control, at: Vector2, title: String) -> Control:
	_caption(parent, at, title)
	var status = Hud.RaidStatus.new()
	status.position = at + Vector2(0, 30)
	status.size = Vector2(360, 300)
	status.medkits = 1
	parent.add_child(status)
	return status

func _ammo(parent: Control, at: Vector2, title: String, rounds: int, spare: int) -> Control:
	_caption(parent, at, title)
	var supplies = Hud.AmmoStatus.new()
	supplies.position = at + Vector2(80, 30)
	supplies.size = Vector2(262, 190)
	supplies.weapon_name = "UZI"
	supplies.magazine_capacity = 32
	supplies.ammo = rounds
	supplies.reserve = spare
	parent.add_child(supplies)
	return supplies

func _caption(parent: Control, at: Vector2, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.position = at
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	parent.add_child(label)
