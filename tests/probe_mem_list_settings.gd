extends SceneTree
func _initialize() -> void:
	for p in ProjectSettings.get_property_list():
		var n := String(p.name)
		if n.begins_with("rendering/") and (n.contains("pipeline") or n.contains("shader") or n.contains("ubershader") or n.contains("special") or n.contains("staging") or n.contains("texture_upload") or n.contains("vram") or n.contains("d3d12") or n.contains("vulkan") or n.contains("rendering_device")):
			print("SETTING ", n, " = ", ProjectSettings.get_setting(n))
	quit(0)
