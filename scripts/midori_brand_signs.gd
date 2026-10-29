extends RefCounted
## Shared static ink materials: ten texture/material pairs at most, no processing.
const ASSET_ROOT := "res://assets/shinrai/signage/independent2050/"
static var _ink_materials: Dictionary = {}

static func ink_material(brand: String, variant: String) -> StandardMaterial3D:
	var asset: String = ASSET_ROOT + brand + "_" + variant + ".svg"
	if not _ink_materials.has(asset):
		var ink := StandardMaterial3D.new()
		ink.resource_name = brand + "_" + variant + "_shaded_ink"
		ink.albedo_texture = load(asset) as Texture2D
		# Ueda's fine painted strokes need filtered fractional coverage at a
		# walking distance. Its authored import settings generate mipmaps.
		ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if brand == "ueda" else BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		ink.alpha_scissor_threshold = .35
		ink.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		ink.roughness = .86
		_ink_materials[asset] = ink
	return _ink_materials[asset] as StandardMaterial3D

static func print_surface(parent: Node3D, label: String, brand: String, variant: String, position: Vector3, dimensions: Vector2) -> MeshInstance3D:
	var asset: String = ASSET_ROOT + brand + "_" + variant + ".svg"
	var plane := QuadMesh.new()
	plane.size = dimensions
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = plane
	visual.material_override = ink_material(brand,variant)
	visual.position = position
	# QuadMesh defaults to +Z. The physical fascia front faces -Z.
	# Rotating the geometry also keeps its printed UVs readable from that side.
	visual.rotation.y = PI
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.set_meta("brand_asset", asset)
	visual.set_meta("creator_protected", true)
	parent.add_child(visual)
	return visual

static func fitted_dimensions(brand: String, variant: String, bounds: Vector2) -> Vector2:
	var texture: Texture2D = load(ASSET_ROOT + brand + "_" + variant + ".svg") as Texture2D
	if texture == null:
		push_error("Missing original signage artwork: " + brand + "_" + variant)
		return Vector2.ZERO
	var source: Vector2 = texture.get_size()
	var scale_factor: float = minf(bounds.x / source.x, bounds.y / source.y)
	return source * scale_factor
