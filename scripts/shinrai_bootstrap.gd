extends Node
const UI=preload("res://scripts/shinrai_loading_screen.gd")
const WORLD:="res://scenes/shinrai_extraction.tscn"
@export var profile_path:="user://shinrai_extraction_v1.json"
@export var creator_layout_path:="user://creator_layouts/midori_default.json"
var loading: CanvasLayer
var park: Node3D
var requesting:=false
var previous_disable_3d:=false
var previous_max_fps:=0
var previous_vsync: int=DisplayServer.VSYNC_ENABLED
func _ready() -> void:
	DisplayServer.window_set_title("SHINRAI — Park Extraction")
	call_deferred("_open_loading")
func _open_loading() -> void:
	loading=get_tree().get_first_node_in_group("shinrai_loading_ui") as CanvasLayer
	if loading==null: loading=UI.new();get_tree().root.add_child(loading)
	if not loading.retry_requested.is_connected(_start): loading.retry_requested.connect(_start)
	_start()
func _start() -> void:
	if requesting: return
	requesting=true;loading.begin("Loading park resources");Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	previous_max_fps=Engine.max_fps;Engine.max_fps=120
	previous_vsync=DisplayServer.window_get_vsync_mode();DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	previous_disable_3d=get_viewport().disable_3d;get_viewport().disable_3d=true
	# Draw the actual loading UI before requesting or instantiating the world.
	await RenderingServer.frame_post_draw
	var error:=ResourceLoader.load_threaded_request(WORLD,"PackedScene",false)
	if error!=OK: _fail("Resource preparation failed. Please retry.");return
	while true:
		var progress: Array=[]
		var status:=ResourceLoader.load_threaded_get_status(WORLD,progress)
		if status==ResourceLoader.THREAD_LOAD_LOADED: break
		if status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]: _fail("Park resources could not be read. Please retry.");return
		loading.set_stage("Loading park resources",clampf(float(progress[0]),0,1) if not progress.is_empty() else -1.0)
		await get_tree().process_frame
	var scene:=ResourceLoader.load_threaded_get(WORLD) as PackedScene
	if scene==null: _fail("The park scene is unavailable. Please retry.");return
	loading.set_stage("Building the park")
	park=scene.instantiate() as Node3D;park.profile_path=profile_path
	preload("./creator/creator_game_integration.gd").prepare_world(park, creator_layout_path)
	park.set_meta("shinrai_incremental_loading",true);park.set_meta("shinrai_structure_pending",true)
	get_tree().root.add_child(park)
	while is_instance_valid(park) and park.get_meta("shinrai_structure_pending",false): await get_tree().process_frame
	if not is_instance_valid(park): _fail("Park preparation was interrupted.");return
	# The native scene is now the autoload target; its structural work is complete.
	get_tree().current_scene=park
	for service_name: String in ["MidoriGrassDetail","MidoriGroundTexture"]:
		var service:=get_tree().root.get_node_or_null(NodePath(service_name))
		if service!=null: service.call_deferred("_install_ground_clumps" if service_name=="MidoriGrassDetail" else "_try_install")
	var raid: Node
	while is_instance_valid(park):
		raid=park.get_node_or_null("ExtractionRun")
		if raid!=null and raid.phase==raid.Phase.HQ: break
		await get_tree().process_frame
	if not is_instance_valid(park): _fail("Park preparation was interrupted.");return
	loading.set_stage("Preparing the view")
	get_viewport().disable_3d=previous_disable_3d
	await RenderingServer.frame_post_draw;await get_tree().process_frame;await RenderingServer.frame_post_draw
	Engine.max_fps=previous_max_fps;DisplayServer.window_set_vsync_mode(previous_vsync);park.set_meta("shinrai_incremental_loading",false);loading.finish();requesting=false
	loading.retry_requested.disconnect(_start)
	queue_free()
func _fail(message: String) -> void:
	requesting=false;Engine.max_fps=previous_max_fps;DisplayServer.window_set_vsync_mode(previous_vsync);get_viewport().disable_3d=previous_disable_3d;loading.fail(message)
func _exit_tree() -> void:
	if requesting: Engine.max_fps=previous_max_fps;DisplayServer.window_set_vsync_mode(previous_vsync);get_viewport().disable_3d=previous_disable_3d
