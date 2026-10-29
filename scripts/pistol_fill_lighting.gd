extends RefCounted
## Candidate pistol presentation only. Preserve diffuse visibility while reducing
## the artificial camera fill's metallic glare; world lights/materials are intact.
const FILL_SPECULAR: float = 0.12

static func apply(viewmodel: Node3D) -> bool:
	var fill := viewmodel.get_node_or_null("ViewmodelFillLight") as OmniLight3D
	if fill == null:
		return false
	fill.light_specular = FILL_SPECULAR
	return true
