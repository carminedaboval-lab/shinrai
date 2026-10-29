extends Node

# One world-only view per equipped prism. Source camera must view the gameplay world.
# Call sync AFTER the optic/weapon pose settles, in the same frame.
var viewport: SubViewport
var camera: Camera3D
var material: ShaderMaterial

func configure(source: Camera3D, lens_material: ShaderMaterial, excluded_layers: int = 1 << 19) -> void:
	material = lens_material
	viewport = SubViewport.new()
	viewport.size = Vector2i(768, 768)
	viewport.world_3d = source.get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.gui_disable_input = true
	add_child(viewport)
	camera = Camera3D.new()
	camera.cull_mask = source.cull_mask & ~excluded_layers
	camera.near = source.near
	camera.far = source.far
	camera.environment = source.environment
	camera.attributes = source.attributes
	viewport.add_child(camera)
	camera.current = true
	material.set_shader_parameter('scoped_view', viewport.get_texture())

func sync(source: Camera3D, rear: Vector3, forward: Vector3, up: Vector3, active: bool, magnification: float = 3.0) -> void:
	if not is_instance_valid(viewport):
		return
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	material.set_shader_parameter('scoped_view_ready', active)
	if not active:
		return
	var axis := forward.normalized()
	var right := axis.cross(up).normalized()
	var vertical := right.cross(axis).normalized()
	var dimensions := source.get_viewport().get_visible_rect().size
	var aspect := dimensions.x / maxf(dimensions.y, 1.0)
	var half_y := tan(deg_to_rad(source.fov) * 0.5)
	if source.keep_aspect == Camera3D.KEEP_WIDTH:
		half_y /= aspect
	# Square texture renders a square angular field; shader samples the corresponding
	# vertical field in both directions, avoiding texture aspect stretching.
	camera.fov = rad_to_deg(2.0 * atan(half_y / maxf(magnification, 1.0)))
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.global_position = source.global_position
	camera.look_at(camera.global_position + axis, vertical)
	material.set_shader_parameter('outside_half_tangent', Vector2(half_y, half_y))
	material.set_shader_parameter('sight_axis', axis)
	material.set_shader_parameter('sight_right', right)
	material.set_shader_parameter('sight_up', vertical)
	material.set_shader_parameter('sight_origin', rear)

func _exit_tree() -> void:
	if is_instance_valid(material):
		material.set_shader_parameter('scoped_view_ready', false)
