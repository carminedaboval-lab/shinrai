extends Node
## Shinrai graphics upgrades: the Unreal 5 features that stock Godot 4.7 can match from the
## project side (no engine fork). Autoload "ShinraiGraphics".
##
## The park's own presets live in midori_park_size_blockout.gd (_apply_render_quality, run on
## every N / F7 / deployment change). This module does not edit that file: it layers on top of it
## and re-asserts the few viewport fields that preset rewrites (scaling mode and scale), so the
## upgrades survive preset switches. Everything here is a setting on Godot's own renderer, so
## nothing pops in and there are no new assets.
##
##   SHINRAI_GRAPHICS_OFF=1        the pre-upgrade look (for A/B captures and bisecting)
##   SHINRAI_GRAPHICS_SKIP=a,b     turn off single features by key (see FEATURES)
##
## Measurements and the Unreal gap table: docs/GRAPHICS_UPGRADES.md.

## Feature keys, each one switchable on its own for captures.
const FEATURES := [
	"fsr2",          # FSR 2.2 temporal upscaler/AA in place of TAA + bilinear (Unreal: TSR)
	"anisotropy",    # 16x anisotropic filtering on every *_anisotropic sampler (ground, roads, paths)
	"debanding",     # dithers the 8-bit output: no banding in sky gradients, fog or night haze
	"shadow_filter", # high soft-shadow filter: smoother PCSS penumbrae, no extra memory
	"shadow_atlas",  # 8K sun shadow atlas, sharper near shadows (Unreal: virtual shadow maps); +96 MB VRAM
	"bounce_light",  # SSIL + SSR on Balanced too (High already had them; Unreal: Lumen screen traces)
]

## Labelled defaults. Balanced is the startup preset, High is F7.
const BALANCED := {"render_scale": 1.0, "fsr_sharpness": 0.35}
const HIGH := {"render_scale": 1.0, "fsr_sharpness": 0.35}
const ANISOTROPY := Viewport.ANISOTROPY_16X
const SUN_SHADOW_ATLAS := 8192
const SOFT_SHADOW_QUALITY := RenderingServer.SHADOW_QUALITY_SOFT_HIGH

var enabled := OS.get_environment("SHINRAI_GRAPHICS_OFF") != "1"
var active := {}
var park: Node
var _globals_applied := false
var _env_key := ""
var _original := {}


func _ready() -> void:
	process_priority = 1000 # after the park's own scripts in the same frame
	for key: String in FEATURES:
		active[key] = true
	for key: String in OS.get_environment("SHINRAI_GRAPHICS_SKIP").split(",", false):
		active[key.strip_edges()] = false
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		enabled = false
	_remember_globals()
	if enabled: _apply_globals()


func _process(_delta: float) -> void:
	if not enabled: return
	if park == null or not is_instance_valid(park):
		park = _find_park()
		_env_key = ""
		if park == null: return
	ensure()


## Turns one feature on or off at runtime (captures and the settings menu use this).
func set_feature(key: String, on: bool) -> void:
	active[key] = on
	_env_key = ""
	_apply_globals()
	# Let the park's preset code rewrite its own values first, then layer what is still on.
	if park != null and is_instance_valid(park) and park.has_method("_apply_render_quality"):
		park.call("_apply_render_quality")
	ensure()


## Turns the whole module on or off at runtime, restoring the park's own values when off.
func set_enabled(on: bool) -> void:
	enabled = on
	_env_key = ""
	if on:
		_apply_globals()
		ensure()
	else:
		_restore()


func is_on(key: String) -> bool:
	return enabled and bool(active.get(key, false))


## Re-applies the upgrades if the park's preset code has rewritten any of them. Cheap: a few
## property reads per frame, writes only on change.
func ensure() -> void:
	if not enabled or park == null or not is_instance_valid(park): return
	var high := bool(park.get("high_render_quality"))
	var preset: Dictionary = HIGH if high else BALANCED
	var view := get_viewport()
	if is_on("fsr2"):
		if view.scaling_3d_mode != Viewport.SCALING_3D_MODE_FSR2: view.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		if not is_equal_approx(view.scaling_3d_scale, preset.render_scale): view.scaling_3d_scale = preset.render_scale
		if not is_equal_approx(view.fsr_sharpness, preset.fsr_sharpness): view.fsr_sharpness = preset.fsr_sharpness
		# FSR 2 is its own temporal AA; Godot's TAA on top would only add blur.
		if view.use_taa: view.use_taa = false
	elif _original.has("use_taa"):
		if view.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2: view.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		if view.use_taa != _original.use_taa: view.use_taa = _original.use_taa
	var env: Environment = park.get("park_environment")
	if env == null: return
	var key := "%s|%s|%s" % [high, park.get("is_night_mode"), is_on("bounce_light")]
	if key == _env_key and (not is_on("bounce_light") or env.ssil_enabled): return
	_env_key = key
	if is_on("bounce_light"):
		# Screen-space bounce light under canopies and between buildings, and wet/glossy
		# reflections on paving, now on both presets. Balanced uses Godot's half-size passes.
		env.ssil_enabled = true
		env.ssil_radius = 4.0 if high else 3.0
		env.ssil_intensity = 0.7 if high else 0.6
		env.ssr_enabled = true
		env.ssr_max_steps = 48 if high else 32
		env.ssr_depth_tolerance = 0.2


func _find_park() -> Node:
	var scene := get_tree().current_scene
	if scene != null and "park_environment" in scene and scene.get("park_environment") != null:
		return scene
	return null


func _remember_globals() -> void:
	var view := get_viewport()
	_original = {
		"anisotropy": view.anisotropic_filtering_level,
		"debanding": view.use_debanding,
		"use_taa": view.use_taa,
		"shadow_atlas": int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", 4096)),
		"shadow_16": bool(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits", true)),
		"soft_quality": int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 2)),
	}


func _apply_globals() -> void:
	if not enabled: return
	var view := get_viewport()
	view.anisotropic_filtering_level = ANISOTROPY if is_on("anisotropy") else _original.anisotropy
	view.use_debanding = true if is_on("debanding") else _original.debanding
	var atlas: int = SUN_SHADOW_ATLAS if is_on("shadow_atlas") else _original.shadow_atlas
	RenderingServer.directional_shadow_atlas_set_size(atlas, true if is_on("shadow_atlas") else _original.shadow_16)
	RenderingServer.directional_soft_shadow_filter_set_quality(SOFT_SHADOW_QUALITY if is_on("shadow_filter") else _original.soft_quality)
	_globals_applied = true


func _restore() -> void:
	var view := get_viewport()
	view.anisotropic_filtering_level = _original.anisotropy
	view.use_debanding = _original.debanding
	view.use_taa = _original.use_taa
	if view.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2:
		view.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	RenderingServer.directional_shadow_atlas_set_size(_original.shadow_atlas, _original.shadow_16)
	RenderingServer.directional_soft_shadow_filter_set_quality(_original.soft_quality)
	# Hand the environment back to the park's own preset code.
	if park != null and is_instance_valid(park) and park.has_method("_apply_render_quality"):
		park.call("_apply_render_quality")
	_env_key = ""
