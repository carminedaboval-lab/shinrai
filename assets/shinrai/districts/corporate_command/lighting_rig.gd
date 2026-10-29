extends Node3D
## Portable model-space lighting for Cantilever Command, measured in metres.
## Instance lighting_rig.tscn below the building root; original mesh resources stay intact.

const WET_PLATFORM_SHADER := preload("wet_paving.gdshader")

@export var night_enabled := true
@export_range(0.0, 4.0, 0.05) var intensity_scale := 1.0
@export var enable_reflection_probe := true
@export var wet_platform_enabled := true
@export_flags_3d_render var reflection_receiver_mask: int = 2

var architecture_lights: Array[Light3D] = []
var reflection_probe: ReflectionProbe
var _probe_refresh_sign := 1.0


func _ready() -> void:
	_build_lights()
	if enable_reflection_probe:
		_build_reflection_probe()
	if wet_platform_enabled:
		apply_wet_platform(get_parent())
	set_night_enabled(night_enabled)


func apply_wet_platform(building: Node) -> int:
	# Only the existing basalt paving changes appearance; steps and ramps stay intact.
	var wet_surface := ShaderMaterial.new()
	wet_surface.shader = WET_PLATFORM_SHADER
	var surface_count := 0
	for mesh_node in building.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		var has_wet_stone := false
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var original := mesh_instance.mesh.surface_get_material(surface)
			if original != null and original.resource_name.begins_with("Basalt_plinth"):
				mesh_instance.set_surface_override_material(surface, wet_surface)
				has_wet_stone = true
				surface_count += 1
		if has_wet_stone:
			mesh_instance.layers = reflection_receiver_mask
	print("CANTILEVER_WET_PLATFORM_SURFACES ", surface_count)
	return surface_count


func _build_lights() -> void:
	# Upper wing soffit. Shadows keep light below the plate instead of whitening glass.
	_omni("UpperVioletWest", Vector3(-25.0, 37.5, 8.7), Color("9028ff"), 24.0, 14.0, true)
	_omni("UpperVioletCentre", Vector3(0.0, 37.5, 3.0), Color("a72aff"), 15.0, 12.0, true)
	_omni("UpperVioletEast", Vector3(25.0, 37.5, 8.7), Color("9028ff"), 24.0, 14.0, true)
	# Purple core slot is supported by localized fill across its concrete edges.
	_omni("CoreVioletLower", Vector3(0.0, 15.0, 8.0), Color("b526ff"), 8.0, 12.0)
	_omni("CoreVioletUpper", Vector3(0.0, 34.0, 8.0), Color("8b27ff"), 9.0, 12.0)
	# The lower L-shaped wing has an independent wash on each underside.
	_omni("LowerMagentaWest", Vector3(-20.0, 15.8, -8.0), Color("ff1678"), 18.0, 14.0, true)
	_omni("LowerMagentaCorner", Vector3(16.0, 15.8, -4.0), Color("ff197d"), 16.0, 14.0, true)
	_omni("LowerMagentaRear", Vector3(16.0, 15.8, -25.0), Color("ef24b2"), 17.0, 15.0, true)
	# Light the genuine recessed rooms at the front end of the right arm.
	for floor_index in range(3):
		_omni("RightArmAmberFloor" + str(floor_index + 1), Vector3(15.25, 18.75 + 3.5 * floor_index, -1.0), Color("ffc180"), 2.5, 9.0, true)
	# Warm lobby lamps illuminate the connected entrance and the wet approach.
	# The refined pavilion is X 6..36 m, Z 0..20 m; its core connector stays fixed.
	_omni("LobbyAmberWest", Vector3(13.06, 6.2, 12.5), Color("ffad54"), 14.0, 17.0, true, 0.2)
	_omni("LobbyAmberEast", Vector3(26.29, 6.2, 12.5), Color("ffb261"), 14.0, 17.0, true, 0.2)
	_omni("LobbyAmberConnector", Vector3(15.0, 12.0, 1.0), Color("ffae55"), 9.0, 12.0, true, 0.1)
	_omni("EntranceAmberApproach", Vector3(19.68, 2.8, 23.0), Color("ffb66a"), 5.0, 13.0, false, 0.3)


func _omni(label: String, at: Vector3, color: Color, energy: float, radius: float, casts_shadows: bool = false, specular_amount: float = 0.0) -> void:
	var lamp := OmniLight3D.new()
	lamp.name = label
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy * intensity_scale
	lamp.omni_range = radius
	lamp.omni_attenuation = 0.8
	lamp.light_specular = specular_amount
	lamp.shadow_enabled = casts_shadows
	lamp.shadow_bias = 0.035
	lamp.shadow_normal_bias = 0.35
	architecture_lights.append(lamp)
	add_child(lamp)


func _build_reflection_probe() -> void:
	reflection_probe = ReflectionProbe.new()
	reflection_probe.name = "ArchitectureReflection"
	reflection_probe.position = Vector3(0.0, 15.0, 15.0)
	reflection_probe.size = Vector3(150.0, 64.0, 150.0)
	# Capture from the open approach, outside the connected lobby and core.
	reflection_probe.origin_offset = Vector3(0.0, -11.0, 25.0)
	reflection_probe.max_distance = 180.0
	reflection_probe.box_projection = false
	reflection_probe.intensity = 0.65
	reflection_probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	reflection_probe.enable_shadows = true
	reflection_probe.cull_mask = 1
	reflection_probe.reflection_mask = reflection_receiver_mask
	reflection_probe.blend_distance = 12.0
	reflection_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(reflection_probe)


func set_night_enabled(enabled: bool) -> void:
	night_enabled = enabled
	for lamp in architecture_lights:
		lamp.visible = enabled
	refresh_reflections()


func refresh_reflections() -> void:
	# UPDATE_ONCE refreshes on transform change, avoiding continuous cubemap renders.
	if is_instance_valid(reflection_probe):
		_probe_refresh_sign *= -1.0
		reflection_probe.position.x = 0.002 * _probe_refresh_sign
