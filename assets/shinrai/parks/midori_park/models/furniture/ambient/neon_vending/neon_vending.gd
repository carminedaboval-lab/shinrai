extends Node3D
## Optional gentle hologram motion; the underlying machine keeps its real dimensions.
var elapsed := 0.0
var holograms: Array[MeshInstance3D] = []
var rest_positions: Array[Vector3] = []

func _ready() -> void:
	collect_holograms(self)

func collect_holograms(node: Node) -> void:
	if node is MeshInstance3D and str(node.name).begins_with("Hologram"):
		# Projected light must not stamp opaque text shadows onto the roof/header.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holograms.append(node)
		rest_positions.append(node.position)
	for child in node.get_children():
		collect_holograms(child)

func _process(delta: float) -> void:
	elapsed += delta
	for i in holograms.size():
		holograms[i].position = rest_positions[i] + Vector3(0, sin(elapsed * 1.4) * 0.006, 0)
