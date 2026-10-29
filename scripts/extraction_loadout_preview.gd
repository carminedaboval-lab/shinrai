extends SubViewportContainer

## Isolated menu presentation of the bundled first-person equipment rig.
## This does not replace the gameplay viewmodel or represent a full-body avatar.
signal availability_changed(available: bool)
signal status_changed(message: String)

const MODEL_PATH := "res://assets/uzi/scene.gltf"
const Catalog = preload("res://scripts/extraction_weapon_catalog.gd")
const DEFAULT_YAW := 0.90
const DEFAULT_PITCH := 0.10
const DEFAULT_DISTANCE := 0.65
const FOCUS := Vector3(0.0, -0.10, -0.47)

var workbench_presentation := false
var _assembly_bounds := AABB()
var available := false
var animation_player: AnimationPlayer
var idle_animation := ""
var inspect_animation := ""
var viewport: SubViewport
var camera: Camera3D
var model: Node3D
var _yaw := DEFAULT_YAW
var _pitch := DEFAULT_PITCH
var _distance := DEFAULT_DISTANCE
var _dragging := false
var _built := false
var _inspecting := false
var _inspect_distance_offset := 0.0
var weapon_id := "uzi"
var optic_id := ""
var _focus := FOCUS
var _base_distance := DEFAULT_DISTANCE

func set_loadout(id: String, attachment: String) -> void:
	if weapon_id == id and optic_id == attachment and available:
		return
	weapon_id = id
	optic_id = attachment
	if _built:
		_load_model()
		reset_view()

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(320, 240)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	stretch = true
	tooltip_text = "Drag to rotate · scroll to zoom · double-click to reset" if workbench_presentation else "Drag to rotate · scroll to zoom · double-click to inspect"
	_build_studio()
	_load_model()
	resized.connect(_resize_viewport)
	visibility_changed.connect(_update_visibility)
	_resize_viewport()
	_update_visibility()

func _build_studio() -> void:
	viewport = SubViewport.new()
	viewport.name = "EquipmentStudio"
	viewport.own_world_3d = true
	viewport.transparent_bg = workbench_presentation
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	var scene := Node3D.new()
	scene.name = "Studio"
	viewport.add_child(scene)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR if workbench_presentation else Environment.BG_COLOR
	environment.background_color = Color("10151b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("aab9ce")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	scene.add_child(world)
	_add_light(scene, "Key", Vector3(1.2, 2.0, 1.0), Color("ffe5c7"), 2.8)
	_add_light(scene, "Fill", Vector3(-1.8, 0.4, 0.7), Color("b7d7ed"), 1.0)
	_add_light(scene, "Rim", Vector3(0.8, 0.9, -1.8), Color("d2e1ed"), 1.8)
	camera = Camera3D.new()
	camera.name = "EquipmentCamera"
	camera.fov = 44.0
	camera.near = 0.025
	camera.far = 12.0
	scene.add_child(camera)
	camera.make_current()
	_built = true
	_update_camera()

func _add_light(parent: Node3D, light_name: String, at: Vector3, color: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.name = light_name
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 6.0
	light.shadow_enabled = false
	parent.add_child(light)

func _load_model() -> void:
	_inspecting = false
	_inspect_distance_offset = 0.0
	if is_instance_valid(model):
		model.get_parent().remove_child(model)
		model.queue_free()
	model = null
	animation_player = null
	available = false
	_focus = FOCUS
	_base_distance = DEFAULT_DISTANCE
	if weapon_id != "uzi":
		_load_weapon_assembly()
		return
	# No remote fetches or generated substitute: unavailable art remains explicit.
	if not ResourceLoader.exists(MODEL_PATH):
		status_changed.emit("Equipment preview unavailable")
		availability_changed.emit(false)
		return
	var source := ResourceLoader.load(MODEL_PATH) as PackedScene
	if source == null:
		status_changed.emit("Equipment preview unavailable")
		availability_changed.emit(false)
		return
	model = source.instantiate() as Node3D
	if model == null:
		status_changed.emit("Equipment preview unavailable")
		availability_changed.emit(false)
		return
	# Preserve the asset's authored unit scale. Only its presentation origin and
	# orientation change; animation bone transforms and materials stay intact.
	model.name = "SuppliedUziArms"
	model.position = Vector3(0.0, -1.46, -0.17)
	model.rotation.y = PI
	viewport.get_node("Studio").add_child(model)
	_prepare_nodes(model)
	animation_player = _find_animation_player(model)
	if animation_player != null:
		idle_animation = _find_clip("idle", "")
		inspect_animation = _find_clip("inspect", "")
		animation_player.animation_finished.connect(_on_animation_finished)
		_play_idle()
	available = true
	status_changed.emit("UZI · supplied arms rig")
	availability_changed.emit(true)

func _load_weapon_assembly() -> void:
	if not Catalog.WEAPONS.has(weapon_id):
		availability_changed.emit(false)
		return
	var path: String = str(Catalog.WEAPONS[weapon_id].scene).replace("_viewmodel.tscn", "_weapon.tscn")
	if not ResourceLoader.exists(path):
		status_changed.emit("Model pending")
		availability_changed.emit(false)
		return
	model = (load(path) as PackedScene).instantiate() as Node3D
	viewport.get_node("Studio").add_child(model)
	if Catalog.compatible(weapon_id, optic_id) and ResourceLoader.exists(Catalog.OPTICS[optic_id].scene):
		var optic := (load(Catalog.OPTICS[optic_id].scene) as PackedScene).instantiate() as Node3D
		model.get_node("OpticSocket").add_child(optic)
		for mesh: MeshInstance3D in optic.find_children("*", "MeshInstance3D", true, false):
			if str(mesh.name).contains("OpticGlass"):
				var glass := StandardMaterial3D.new()
				glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				glass.albedo_color = Color(.6,.5,.3,.06)
				glass.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh.material_override = glass
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	_assembly_bounds = bounds
	_focus = bounds.get_center()
	_base_distance = maxf(.65, bounds.size.length() * 1.55)
	_yaw = .15
	_distance = _base_distance
	_pitch = .15
	if workbench_presentation:
		_pitch = DEFAULT_PITCH
		_fit_workbench_view()
	_update_camera()
	available = true
	status_changed.emit(Catalog.WEAPONS[weapon_id].title)
	availability_changed.emit(true)

func _prepare_nodes(node: Node) -> void:
	if node is Camera3D:
		(node as Camera3D).current = false
		(node as Camera3D).visible = false
	elif node is Light3D:
		(node as Light3D).visible = false
	elif node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var lower_name := String(mesh.name).to_lower()
		var source_name := String(mesh.mesh.resource_name).to_lower() if mesh.mesh != null else ""
		# Inspect the supplied weapon itself; arm/cloth geometry is retained in
		# the source and in gameplay, but hidden in this isolated equipment studio.
		if lower_name in ["object_9", "object_10", "object_11", "object_12", "object_13"] or source_name.begins_with("mesh_"):
			mesh.visible = false
		# Source presentation cards and sky are not equipment.
		if lower_name.contains("sky") or lower_name.contains("dome") or lower_name.begins_with("aim"):
			mesh.visible = false
		mesh.extra_cull_margin = 3.0
	for child: Node in node.get_children():
		_prepare_nodes(child)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _find_clip(required: String, excluded: String) -> String:
	for clip: StringName in animation_player.get_animation_list():
		var lower := String(clip).to_lower()
		if lower.contains(required) and (excluded.is_empty() or not lower.contains(excluded)):
			return String(clip)
	return ""

func _play_idle() -> void:
	_inspecting = false
	if animation_player != null and not idle_animation.is_empty():
		# Loop by replaying if needed; never change the shared imported Animation.
		animation_player.play(idle_animation, 0.18)

func _on_animation_finished(_clip: StringName) -> void:
	_play_idle()

func inspect_equipment() -> bool:
	if available and weapon_id != "uzi":
		reset_view()
		return true
	if not available or animation_player == null or inspect_animation.is_empty():
		return false
	_inspecting = true
	animation_player.play(inspect_animation, 0.16)
	return true

func _process(delta: float) -> void:
	# The authored Inspect gesture moves the support hand outside its idle
	# envelope. Ease back while inspecting, then return to the closer idle view.
	var target := 0.35 if _inspecting else 0.0
	var next_offset := move_toward(_inspect_distance_offset, target, delta * 0.70)
	if not is_equal_approx(next_offset, _inspect_distance_offset):
		_inspect_distance_offset = next_offset
		_update_camera()

func reset_view() -> void:
	_yaw = DEFAULT_YAW
	_pitch = DEFAULT_PITCH
	_distance = DEFAULT_DISTANCE
	_distance = _base_distance
	if weapon_id != "uzi":
		_yaw = .15
		if workbench_presentation: _fit_workbench_view()
	_update_camera()

func _update_camera() -> void:
	if camera == null:
		return
	var offset := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * (_distance + _inspect_distance_offset)
	camera.position = _focus + offset
	camera.look_at(_focus, Vector3.UP)

func _resize_viewport() -> void:
	if viewport != null:
		# Bound GPU cost independently of the menu/window size.
		var target := Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
		stretch_shrink = maxi(1, ceili(float(maxi(target.x, target.y)) / 960.0))
		if workbench_presentation and weapon_id != "uzi":
			_fit_workbench_view()
			_update_camera()

func _fit_workbench_view() -> void:
	if camera == null or _assembly_bounds.size == Vector3.ZERO or size.y <= 0.0: return
	# Fit the actual supplied assembly and optic to this panel's aspect ratio.
	# Existing hands-strip framing and the authored UZI rig stay independent.
	var direction := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	var view_basis := Basis.looking_at(-direction, Vector3.UP).transposed()
	var tangent := tan(deg_to_rad(camera.fov) * 0.5)
	var aspect := maxf(size.x / size.y, 0.1)
	var distance := 0.20
	for index: int in range(8):
		var corner := view_basis * (_assembly_bounds.get_endpoint(index) - _focus)
		distance = maxf(distance, corner.z + maxf(absf(corner.x) / (tangent * aspect * .82), absf(corner.y) / (tangent * .74)))
	_base_distance = distance
	_distance = distance

func _update_visibility() -> void:
	if not _built:
		return
	var shown := is_visible_in_tree()
	set_process(shown)
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if shown else SubViewport.UPDATE_DISABLED
	if animation_player != null:
		animation_player.active = shown
	_dragging = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mouse.pressed
			if mouse.pressed and mouse.double_click:
				if workbench_presentation: reset_view()
				else: inspect_equipment()
			accept_event()
		elif mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_distance = clampf(_distance + (-0.12 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else 0.12), _base_distance * .55 if workbench_presentation else .50, maxf(2.40, _base_distance * 2.4) if workbench_presentation else 2.40)
			_update_camera()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_yaw = clampf(_yaw - motion.relative.x * 0.008, -1.20, 1.20)
		_pitch = clampf(_pitch + motion.relative.y * 0.006, -0.12, 0.62)
		_update_camera()
		accept_event()
