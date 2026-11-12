extends Node
## Boot flow: a short loading screen (shader feature latch), then the Operations
## menu at once while the park loads and builds behind it. DEPLOY pressed early is
## queued under the deploy cover. The last step warms the view under the menu and
## turns the live 3D park on; only then is the world ready.
const UI=preload("res://scripts/shinrai_loading_screen.gd")
const LoadState=preload("res://scripts/shinrai_load_state.gd")
const MenuSource=preload("res://scripts/shinrai_menu_source.gd")
const StartupTrace=preload("res://scripts/startup_trace.gd")
const WORLD:="res://scenes/shinrai_extraction.tscn"
## Loaded at runtime (not preloaded) so a half-edited menu file cannot stop the boot.
const MENU_KIT:="res://scripts/ui/shinrai_menu_kit.gd"
## Watchdog: fail with Retry when the build reports nothing for this long, or overall.
const STALL_LIMIT_MSEC:=300000
const TOTAL_LIMIT_MSEC:=1500000
## Frame cap while the menu shares the main thread with the build. Most build
## frames are light (a poll hop, one item per `await process_frame`); at 60 each
## was padded to 16.7 ms. 120 halves that padding; 3D is off, the menu is cheap.
const LOADING_MAX_FPS:=120
## Physics catch-up steps per frame during the boot. Build frames run ~50-100 ms,
## so the default (8) runs 3-6 full physics steps (doors, windows, fence, the
## physics server over the whole park) in every one of them for nothing: no actor
## moves before DEPLOY. One step a frame keeps every physics_frame await working.
const LOADING_PHYSICS_STEPS:=1
const Budget=preload("res://scripts/shinrai_loading_budget.gd")
## Loads the scene's script-free assets on threads of its own while the scene loads.
const ScenePrefetch=preload("res://scripts/shinrai_scene_prefetch.gd")
var _prefetch_thread: Thread
var _prefetched: Array=[]
var _prefetch_stop:=[false]
var _prefetch_go:=[false]
var previous_physics_steps:=8
## Mirrors LoadingBudget.interactive (set only on changes: set_interactive(true)
## also counts as fresh input).
var _menu_interactive:=false
@export var profile_path:="user://shinrai_extraction_v1.json"
@export var creator_layout_path:="user://creator_layouts/midori_default.json"
var loading: CanvasLayer
var park: Node3D
var requesting:=false
var previous_disable_3d:=false
var previous_max_fps:=0
var previous_vsync: int=DisplayServer.VSYNC_ENABLED
var menu_layer: CanvasLayer
var early_menu: Control
var menu_source: RefCounted
var quit_screen: Control
var _generation:=0
var _started_ms:=0
var _progress_ms:=0
var _fallback_handover:=false
## Display settings are saved once per boot attempt chain (a Retry must not
## save the loading-time values as the "previous" ones).
var _display_saved:=false

func _ready() -> void:
	DisplayServer.window_set_title("SHINRAI — Park Extraction")
	# Connected first, so it runs before every build coroutine resumed by this
	# frame's process_frame: the loading budget then counts from frame start.
	if not get_tree().process_frame.is_connected(_on_tree_frame): get_tree().process_frame.connect(_on_tree_frame)
	call_deferred("_open_loading")

func _on_tree_frame() -> void:
	Budget.frame_started()

## The early menu's DEPLOY waits ~150 s for the park; a focus loss meanwhile
## (before ExtractionRun exists to see it) must still start the raid paused.
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and menu_source!=null and bool(menu_source.get("deploy_requested")):
		menu_source.set("focus_lost",true)

func _open_loading() -> void:
	loading=get_tree().get_first_node_in_group("shinrai_loading_ui") as CanvasLayer
	if loading==null: loading=UI.new();get_tree().root.add_child(loading)
	if not loading.retry_requested.is_connected(_retry): loading.retry_requested.connect(_retry)
	_start()

func _start() -> void:
	if requesting: return
	requesting=true;_generation+=1
	var generation:=_generation
	_started_ms=Time.get_ticks_msec();_progress_ms=_started_ms;_fallback_handover=false
	_start_prefetch()
	LoadState.reset();LoadState.report("Starting Shinrai",0.0)
	LoadState.ui_begin(loading,"Starting Shinrai",&"boot");Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if not _display_saved:
		_display_saved=true
		previous_max_fps=Engine.max_fps;previous_vsync=DisplayServer.window_get_vsync_mode();previous_disable_3d=get_viewport().disable_3d
		previous_physics_steps=Engine.max_physics_steps_per_frame
	Engine.max_fps=LOADING_MAX_FPS;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_physics_steps_per_frame=LOADING_PHYSICS_STEPS
	get_viewport().disable_3d=true
	# Draw the loading UI before any heavy work.
	await _drawn_frame()
	if generation!=_generation: return
	# The player's smoothing choice goes on the main view before anything is prepared for it.
	preload("res://scripts/shinrai_settings.gd").apply(get_tree().root)
	# Fix the renderer's pipeline features before any park material exists.
	var warmup:=LoadState.warmup_script()
	if LoadState.script_has(warmup,"is_first_launch"): LoadState.first_launch_shaders=bool(warmup.call("is_first_launch"))
	if LoadState.script_has(warmup,"latch_features") and DisplayServer.get_name()!="headless":
		loading.set_stage("Preparing shaders (first launch)" if LoadState.first_launch_shaders else "Starting Shinrai")
		await warmup.call("latch_features",get_tree().root)
		if generation!=_generation: return
	# No sub-threads: tried (2026-11-08), the load never finished (stalled at 0 %
	# with the workers idle, 2+ minutes), so dependencies stay on one loader thread.
	# The script-free assets are read alongside it by our own threads (speed only).
	# (Requesting the scene before the latch was tried, 2026-11-08: the load is bound
	# by compiling ~190 scripts on its one thread and ended no sooner, the latch took
	# 0.6 s longer and mesh pipelines were precompiled before the latch.)
	_start_prefetch();_prefetch_go[0]=true
	var _lt:=StartupTrace.begin()
	var error:=ResourceLoader.load_threaded_request(WORLD,"PackedScene",false)
	if error!=OK: _fail("Resource preparation failed. Please retry.");return
	LoadState.band("Loading park resources",0.0,0.20,9.0)
	_open_early_menu()
	if is_instance_valid(early_menu):
		LoadState.ui_finish(loading,&"boot")
		await _drawn_frame()
		if generation!=_generation: return
		LoadState.menu_shown=true
	var last_resource:=-1.0
	while true:
		var progress: Array=[]
		var status:=ResourceLoader.load_threaded_get_status(WORLD,progress)
		if status==ResourceLoader.THREAD_LOAD_LOADED: break
		if status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]: _fail("Park resources could not be read. Please retry.");return
		var resource:=clampf(float(progress[0]),0,1) if not progress.is_empty() else -1.0
		if resource>last_resource:
			last_resource=resource;LoadState.report("Loading park resources",0.20*maxf(resource,0.0))
		if not await _wait_frame(generation): return
	StartupTrace.finish("boot.scene_load",_lt)
	var scene:=ResourceLoader.load_threaded_get(WORLD) as PackedScene
	# The scene now holds every asset the prefetch read; let the threads go.
	_stop_prefetch(false)
	if scene==null: _fail("The park scene is unavailable. Please retry.");return
	LoadState.band("Building the park",0.20,0.45,20.0)
	if not await _wait_frame(generation): return
	var _bt:=StartupTrace.begin()
	var instanced:=scene.instantiate() as Node3D
	_bt=StartupTrace.finish("boot.instantiate",_bt)
	park=instanced;park.profile_path=profile_path
	# Instancing and entering the tree (every _ready's first slice) used to share
	# one ~4.7 s frame under the menu; a frame between them halves the worst one.
	if not await _wait_frame(generation):
		if is_instance_valid(instanced) and not instanced.is_queued_for_deletion() and not instanced.is_inside_tree(): instanced.free()
		if park==instanced: park=null
		return
	preload("./creator/creator_game_integration.gd").prepare_world(park, creator_layout_path)
	park.set_meta("shinrai_incremental_loading",true);park.set_meta("shinrai_structure_pending",true)
	park.set_meta("shinrai_boot_host",true)
	# ExtractionRun takes this menu over in the frame it is created (no gap, no double menu).
	if menu_source!=null and is_instance_valid(early_menu): park.set_meta("shinrai_menu_source",menu_source)
	_bt=StartupTrace.begin()
	get_tree().root.add_child(park)
	_bt=StartupTrace.finish("boot.add_child",_bt)
	while is_instance_valid(park) and park.get_meta("shinrai_structure_pending",false):
		StartupTrace.watch(park)
		if not await _wait_frame(generation): return
	if not is_instance_valid(park): _fail("Park preparation was interrupted.");return
	# The native scene is now the autoload target; its structural work is complete.
	get_tree().current_scene=park
	for service_name: String in ["MidoriGrassDetail","MidoriGroundTexture"]:
		var service:=get_tree().root.get_node_or_null(NodePath(service_name))
		if service!=null: service.call_deferred("_install_ground_clumps" if service_name=="MidoriGrassDetail" else "_try_install")
	LoadState.report("",0.45)
	# Producers, navigation and world completion report through ExtractionRun.
	var raid: Node
	while is_instance_valid(park):
		raid=park.get_node_or_null("ExtractionRun")
		if raid!=null:
			if not bool(raid.get("hq_menu_open")): _hand_over_fallback(raid)
			if raid.phase!=raid.Phase.BOOT: break
		StartupTrace.watch(park)
		if not await _wait_frame(generation): return
	if not is_instance_valid(park) or not is_instance_valid(raid): _fail("Park preparation was interrupted.");return
	# Last step, under the menu: warm the chosen variant offscreen, then go live.
	_set_menu_interactive(false)
	LoadState.band("Preparing shaders (first launch)" if LoadState.first_launch_shaders else "Preparing the view",0.95,1.0,3.0)
	raid.apply_menu_preferences()
	_bt=StartupTrace.begin()
	var warm_report: Dictionary=await raid.warm_park_view(true)
	_bt=StartupTrace.finish("boot.view_warm",_bt)
	if generation!=_generation: return
	if not is_instance_valid(raid): _fail("Park preparation was interrupted.");return
	# warm_park_view stops waiting at its limit but the warm-up itself keeps
	# rendering; let it finish (bounded) before 3D goes live, so its end-of-warm
	# restore can never land on the live menu or raid.
	if str(warm_report.get("status",""))=="timeout" and LoadState.script_has(warmup,"is_busy"):
		var until:=Time.get_ticks_msec()+30000
		while bool(warmup.call("is_busy")) and Time.get_ticks_msec()<until:
			if not await _wait_frame(generation): return
	print("SHINRAI_BOOT_WARMUP ",JSON.stringify(warm_report))
	get_viewport().disable_3d=previous_disable_3d
	await _drawn_frame();await get_tree().process_frame;await _drawn_frame()
	_bt=StartupTrace.finish("boot.3d_on",_bt)
	if generation!=_generation: return
	if not is_instance_valid(raid): _fail("Park preparation was interrupted.");return
	if LoadState.script_has(warmup,"mark_done") and str(warm_report.get("status",""))=="ok": warmup.call("mark_done")
	raid.finish_view_warmup()
	if not LoadState.menu_shown:
		LoadState.ui_finish(loading,&"boot");LoadState.menu_shown=true
	_restore_display();park.set_meta("shinrai_incremental_loading",false)
	_display_saved=false;requesting=false
	if loading.retry_requested.is_connected(_retry): loading.retry_requested.disconnect(_retry)
	queue_free()

## One loading frame: progress creep, watchdog, early-menu upkeep. False = stop.
func _wait_frame(generation: int) -> bool:
	LoadState.tick()
	if _prefetch_thread!=null and _prefetch_stop[0] and not _prefetch_thread.is_alive(): _stop_prefetch(true)
	if LoadState.last_report_ms>_progress_ms: _progress_ms=LoadState.last_report_ms
	var now:=Time.get_ticks_msec()
	var raid: Node=park.get_node_or_null("ExtractionRun") if is_instance_valid(park) else null
	if raid!=null and not str(raid.get("boot_error")).is_empty(): _fail(str(raid.get("boot_error"))+" Please retry.");return false
	if now-_progress_ms>STALL_LIMIT_MSEC: _fail("The park stopped responding while it was being prepared. Please retry.");return false
	if now-_started_ms>TOTAL_LIMIT_MSEC: _fail("The park took too long to prepare. Please retry.");return false
	if menu_source!=null and bool(menu_source.get("deploy_requested")): loading.set_stage(LoadState.waiting_text(),LoadState.fraction)
	elif not LoadState.menu_shown: loading.set_stage(LoadState.stage,LoadState.fraction)
	# The build yields sooner while the player is using the menu over it (WORLD's
	# adaptive budget); an opaque loading screen or the deploy cover takes the larger one.
	_set_menu_interactive(LoadState.menu_shown and not loading.active)
	# (The Operations menu polls ShinraiLoadState itself for the DEPLOY progress.)
	await get_tree().process_frame
	return generation==_generation and requesting

## The dependency walk starts with the boot; the loads wait for _prefetch_go.
func _start_prefetch() -> void:
	if _prefetch_thread!=null: return
	_prefetch_stop=[false];_prefetch_go=[false];_prefetched=[]
	_prefetch_thread=Thread.new()
	if _prefetch_thread.start(ScenePrefetch.run.bind(WORLD,_prefetched,_prefetch_stop,_prefetch_go))!=OK: _prefetch_thread=null

## Asks the prefetch threads to stop after their current file. join: wait for them
## (otherwise _wait_frame joins once they have ended, without blocking a frame).
func _stop_prefetch(join: bool) -> void:
	if _prefetch_thread==null: return
	_prefetch_stop[0]=true
	if not join and _prefetch_thread.is_alive(): return
	_prefetch_thread.wait_to_finish()
	_prefetch_thread=null;_prefetched.clear()

func _drawn_frame() -> void:
	if DisplayServer.get_name()=="headless": await get_tree().process_frame
	else: await RenderingServer.frame_post_draw

# --- Early Operations menu (before ExtractionRun exists) ---

func _open_early_menu() -> void:
	_close_early_menu()
	var menu_script:=LoadState.optional_script(LoadState.OPERATIONS_MENU_PATH)
	if menu_script==null: return
	menu_layer=CanvasLayer.new();menu_layer.name="ShinraiEarlyMenu";menu_layer.layer=60
	get_tree().root.add_child(menu_layer)
	menu_source=MenuSource.new();menu_source.call("load_from",profile_path)
	menu_source.connect("handed_over",_on_menu_handed_over)
	early_menu=menu_script.new() as Control
	if early_menu==null: _close_early_menu();return
	# The menu draws its own backdrop: plaza art while 3D is off (the whole boot).
	early_menu.name="EarlyOperationsMenu";early_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(early_menu)
	early_menu.call("configure",menu_source)
	early_menu.connect("action_requested",_on_early_action)

func _on_early_action(action: String) -> void:
	if menu_source==null or loading.active: return
	match action:
		"deploy":
			if bool(menu_source.get("deploy_requested")) or not bool(menu_source.call("menu_can","deploy")): return
			menu_source.set("deploy_requested",true);menu_source.set("focus_lost",false)
			LoadState.ui_begin(loading,"Entering the park",&"deploy");LoadState.ui_show_cancel(loading,true)
			loading.set_stage(LoadState.waiting_text(),LoadState.fraction)
			if loading.has_signal("cancel_requested") and not loading.is_connected("cancel_requested",_cancel_early_deploy): loading.connect("cancel_requested",_cancel_early_deploy)
		"time":
			menu_source.set("night",not bool(menu_source.get("night")));early_menu.call("refresh")
		"graphics":
			menu_source.set("high_quality",not bool(menu_source.get("high_quality")));early_menu.call("refresh")
		"quit_confirm": _confirm_quit()
		"quit_desktop": get_tree().quit()

func _cancel_early_deploy() -> void:
	if menu_source==null or not bool(menu_source.get("deploy_requested")): return
	menu_source.set("deploy_requested",false);menu_source.set("focus_lost",false)
	_release_early_cancel()
	LoadState.ui_show_cancel(loading,false);LoadState.ui_finish(loading,&"deploy")
	if is_instance_valid(early_menu):
		early_menu.call("refresh")
		var deploy_button: Variant=early_menu.get("deploy_button")
		if deploy_button is Control: (deploy_button as Control).grab_focus()

func _release_early_cancel() -> void:
	if loading.has_signal("cancel_requested") and loading.is_connected("cancel_requested",_cancel_early_deploy): loading.disconnect("cancel_requested",_cancel_early_deploy)

## Same quit confirmation as the HQ one, built from the menu kit, before the HUD exists.
func _confirm_quit() -> void:
	if is_instance_valid(quit_screen) or not is_instance_valid(menu_layer): return
	var kit=load(MENU_KIT)
	quit_screen=Control.new();quit_screen.name="EarlyQuitConfirmation";quit_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(quit_screen)
	kit.backdrop(quit_screen,3.0,0.55,0.50)
	var margin:=MarginContainer.new();margin.mouse_filter=Control.MOUSE_FILTER_IGNORE;margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right"]: margin.add_theme_constant_override("margin_"+side,12)
	for side: String in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,14)
	quit_screen.add_child(margin)
	var screen=kit.screen(margin,"QUIT","HQ")
	kit.status_text(screen,"HQ  ·  SECURED")
	kit.caption(screen,"QUIT  /  Close Shinrai and return to the desktop.")
	kit.key_hints(screen,[["Enter / A","Select"],["Esc / B","Back"]])
	var box=kit.dialog(screen,"CONFIRM","QUIT TO DESKTOP?")
	kit.wrapped(kit.text(box,"Close Shinrai and return to the desktop. The park keeps nothing you have not banked.",20,Color("f3eee2")))
	kit.spacer(box,6)
	var row=kit.button_row(box)
	var back: Button=kit.primary_button(row,"BACK",22);back.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	back.pressed.connect(_close_quit)
	var quit: Button=kit.danger_button(row,"QUIT TO DESKTOP");quit.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	quit.pressed.connect(func() -> void: get_tree().quit())
	back.focus_neighbor_right=back.get_path_to(quit);quit.focus_neighbor_left=quit.get_path_to(back)
	early_menu.hide()
	# The run reopens this dialog if it takes the menu over while it is up.
	if menu_source!=null: menu_source.set("quit_open",true)
	back.grab_focus()

func _close_quit() -> void:
	if is_instance_valid(quit_screen): quit_screen.queue_free()
	quit_screen=null
	if menu_source!=null: menu_source.set("quit_open",false)
	if is_instance_valid(early_menu):
		early_menu.show()
		var quit_button: Variant=early_menu.get("quit_button")
		if quit_button is Control: (quit_button as Control).grab_focus()

## Esc / pad B on the early menu: close the quit screen, then the settings drawer.
func _input(event: InputEvent) -> void:
	if not is_instance_valid(early_menu) or loading.active: return
	var back: bool=(event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B)
	if not back: return
	if is_instance_valid(quit_screen): _close_quit();get_viewport().set_input_as_handled()
	elif early_menu.has_method("controller_cancel") and bool(early_menu.call("controller_cancel")): get_viewport().set_input_as_handled()

## ExtractionRun showed its HQ menu (same component) in this frame: drop ours.
## A requested deploy continues under the same cover, now owned by the run.
func _on_menu_handed_over(_raid: Node) -> void:
	_release_early_cancel()
	if menu_source!=null: menu_source.set("deploy_requested",false)
	if is_instance_valid(menu_layer): menu_layer.hide();menu_layer.queue_free()
	menu_layer=null;early_menu=null;menu_source=null;quit_screen=null

## Without the Operations menu component: keep the loading screen until the run
## exists, then show its HQ panel (world still building, DEPLOY queues).
func _hand_over_fallback(raid: Node) -> void:
	if _fallback_handover or not is_instance_valid(raid.get("hud")): return
	_fallback_handover=true
	raid.set("hq_menu_open",true)
	raid.hud.show_hq(raid)
	LoadState.ui_finish(loading,&"boot")
	LoadState.menu_shown=true

func _close_early_menu() -> void:
	if menu_source!=null and bool(menu_source.get("deploy_requested")):
		menu_source.set("deploy_requested",false);_release_early_cancel();LoadState.ui_show_cancel(loading,false);LoadState.ui_finish(loading,&"deploy")
	if is_instance_valid(menu_layer): menu_layer.queue_free()
	menu_layer=null;early_menu=null;menu_source=null;quit_screen=null

## Probe/QA hook: press an Operations-menu action on whichever menu is current.
func press_menu_action(action: String) -> void:
	var raid: Node=park.get_node_or_null("ExtractionRun") if is_instance_valid(park) else null
	if raid!=null and bool(raid.get("hq_menu_open")): raid.call("_on_action",action)
	elif is_instance_valid(early_menu) and early_menu.visible: early_menu.emit_signal("action_requested",action)

func _set_menu_interactive(value: bool) -> void:
	if value==_menu_interactive: return
	_menu_interactive=value;Budget.set_interactive(value)

func _restore_display() -> void:
	_set_menu_interactive(false)
	Engine.max_fps=previous_max_fps;DisplayServer.window_set_vsync_mode(previous_vsync)
	Engine.max_physics_steps_per_frame=previous_physics_steps

func _fail(message: String) -> void:
	requesting=false;_generation+=1
	_stop_prefetch(true)
	_restore_display()
	LoadState.ui_begin(loading,"Unable to load the park",&"boot");loading.fail(message)

## Retry frees a half-built park (and its run) before starting again cleanly.
func _retry() -> void:
	if requesting: return
	_generation+=1
	_close_early_menu()
	if is_instance_valid(park):
		park.queue_free();park=null
		await get_tree().process_frame
	_start()

func _exit_tree() -> void:
	_stop_prefetch(true)
	if _display_saved: _restore_display();get_viewport().disable_3d=previous_disable_3d
