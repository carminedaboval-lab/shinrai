extends Node
const LoadingUI = preload("res://scripts/shinrai_loading_screen.gd")
const LoadState = preload("res://scripts/shinrai_load_state.gd")
const CreatorPark = preload("./creator_park.gd")
## Loading-screen owner token for the creator boot.
const OWNER := &"creator"
const IdentityAdapter = preload("./creator_identity_adapter.gd")
const WORLD := "res://scenes/shinrai_extraction.tscn"
var loading: CanvasLayer
var park: Node3D
var requesting := false
var old_disable_3d := false
var old_max_fps := 0
var old_vsync: int

func _ready() -> void:
	DisplayServer.window_set_title("SHINRAI - Create in Park")
	call_deferred("_start")

func _start() -> void:
	if requesting: return
	requesting = true
	if loading == null:
		loading = LoadingUI.new()
		get_tree().root.add_child(loading)
		loading.retry_requested.connect(_retry)
	LoadState.ui_begin(loading, "Opening your park", OWNER)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	old_disable_3d = get_viewport().disable_3d
	old_max_fps = Engine.max_fps
	old_vsync = DisplayServer.window_get_vsync_mode()
	get_viewport().disable_3d = true
	Engine.max_fps = 120
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	# Same pipeline feature latch as the game boot, before any park material exists.
	var warmup := LoadState.warmup_script()
	if LoadState.script_has(warmup, "latch_features") and DisplayServer.get_name() != "headless":
		await warmup.call("latch_features", get_tree().root)
	var error :=ResourceLoader.load_threaded_request(WORLD, "PackedScene", false)
	if error != OK:
		_fail("The park resources could not be opened.")
		return
	while true:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(WORLD, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED: break
		if status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			_fail("The park resources could not be read.")
			return
		loading.set_stage("Opening your park", float(progress[0]) if not progress.is_empty() else -1.0)
		await get_tree().process_frame
	var packed := ResourceLoader.load_threaded_get(WORLD) as PackedScene
	if packed == null:
		_fail("The park scene is unavailable.")
		return
	park = packed.instantiate() as Node3D
	# Switch before tree entry: ExtractionRun is never created and no profile loaded.
	park.set_script(CreatorPark)
	var identity := park.get_node_or_null("Midori2050Identity")
	if identity != null:
		if FileAccess.get_sha256("res://scripts/midori_2050_identity.gd") != IdentityAdapter.COMPATIBILITY_SOURCE_SHA256:
			park.free()
			_fail("The park furniture has changed. Creator Mode needs its object adapters updated.")
			return
		identity.set_script(IdentityAdapter)
	park.set_meta("shinrai_incremental_loading", true)
	park.set_meta("shinrai_structure_pending", true)
	get_tree().root.add_child(park)
	while is_instance_valid(park) and park.get_meta("shinrai_structure_pending", false):
		await get_tree().process_frame
	if not is_instance_valid(park):
		_fail("Park loading was interrupted.")
		return
	get_tree().current_scene = park
	for service_name: String in ["MidoriGrassDetail", "MidoriGroundTexture"]:
		var service := get_tree().root.get_node_or_null(NodePath(service_name))
		if service != null: service.call_deferred("_install_ground_clumps" if service_name == "MidoriGrassDetail" else "_try_install")
	loading.set_stage("Preparing your creator tools")
	while is_instance_valid(park) and not park.creator_ready:
		if not str(park.creator_error).is_empty():
			_fail(str(park.creator_error))
			return
		await get_tree().process_frame
	if not is_instance_valid(park):
		_fail("Park loading was interrupted.")
		return
	# Warm the editor view offscreen, then draw the first 3D frames under the
	# loading screen, so the first-frame cost never shows as a frozen editor.
	loading.set_stage("Preparing the view")
	if LoadState.script_has(warmup, "warm") and DisplayServer.get_name() != "headless":
		var camera := get_viewport().get_camera_3d()
		var poses: Array[Transform3D] = []
		if camera != null: poses.append(camera.global_transform)
		await warmup.call("warm", park, poses, park.get("is_night_mode") == true, park.get("high_render_quality") == true)
		if not is_instance_valid(park):
			_fail("Park loading was interrupted.")
			return
	_restore_display()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	park.set_meta("shinrai_incremental_loading", false)
	LoadState.ui_finish(loading, OWNER)
	requesting = false
	queue_free()

func _restore_display() -> void:
	get_viewport().disable_3d = old_disable_3d
	Engine.max_fps = old_max_fps
	DisplayServer.window_set_vsync_mode(old_vsync)

func _fail(message: String) -> void:
	_restore_display()
	requesting = false
	loading.fail(message)

func _retry() -> void:
	if is_instance_valid(park):
		park.queue_free()
		await get_tree().process_frame
	_start()

func _exit_tree() -> void:
	if requesting: _restore_display()
