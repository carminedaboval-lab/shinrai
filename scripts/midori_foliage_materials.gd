extends RefCounted

# Shared runtime copies only. Keep imported textures, alpha silhouettes and PBR
# maps intact; opaque bark/wood never enters this adaptation.
const ALPHA_CUTOFF := 0.35
const ADAPTED_META: StringName = &"midori_natural_foliage_v1"
const SOURCE_META: StringName = &"midori_foliage_source_material"
const VEGETATION_TEXTURE_ROOTS := [
	"res://assets/shinrai/parks/midori_park/models/vegetation/",
	"res://assets/shinrai/vegetation/sakura/",
]
static var _material_cache: Dictionary = {}

static func is_eligible(source: Material) -> bool:
	if not source is StandardMaterial3D or source.has_meta(ADAPTED_META):
		return false
	var material := source as StandardMaterial3D
	if material.transparency not in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH]:
		return false
	if material.albedo_texture == null or material.albedo_color.a < 0.99 or material.next_pass != null:
		return false
	var texture_path := material.albedo_texture.resource_path.replace("\\", "/").to_lower()
	for vegetation_root: String in VEGETATION_TEXTURE_ROOTS:
		if texture_path.begins_with(vegetation_root):
			# Existing scissor/hash coverage is already intentional. Adapt only
			# identified foliage families while leaving unknown authored cutouts.
			return material.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS] or not _leaf_profile(material).is_empty()
	return false

static func _leaf_profile(material: StandardMaterial3D) -> String:
	var path := material.albedo_texture.resource_path.replace("\\", "/").to_lower()
	var label := material.resource_name.to_lower()
	if "/realistic_trees_collection/" in path and label.begins_with("leaves"):
		return "broadleaf"
	if "/pine_trees_pack/" in path and ("clusters" in label or "billboard" in label):
		return "pine"
	if "/lilac_bush_pack/" in path and ("brunches" in label or "billboard" in label):
		return "lilac"
	if "/jogoss_sakura_01/" in path and "bark" not in label and "bark" not in path:
		return "sakura"
	if "/cosmic_dust_grass/" in path or "/emerald_fountain_grass/" in path:
		return "grass"
	return ""

static func build(source: Material) -> Material:
	if not is_eligible(source):
		return source
	if _material_cache.has(source):
		return _material_cache[source] as StandardMaterial3D
	var original := source as StandardMaterial3D
	var material := original.duplicate() as StandardMaterial3D
	material.resource_local_to_scene = false
	# Resource.duplicate omits coverage properties hidden by the active mode.
	# Preserve both authored values explicitly, including an unused threshold.
	material.alpha_scissor_threshold = original.alpha_scissor_threshold
	material.alpha_hash_scale = original.alpha_hash_scale
	# Retain the established conversion for imported blend cards only. Every
	# authored scissor threshold/hash mode, texture and UV remains unchanged.
	if original.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = ALPHA_CUTOFF
	var profile := _leaf_profile(original)
	if not profile.is_empty():
		material.metallic = 0.0
		var specular_limit := 0.24
		var roughness_floor := 0.86
		var transmitted := Color(0.085, 0.105, 0.060, 1.0)
		if profile == "pine":
			specular_limit = 0.20
			transmitted = Color(0.040, 0.055, 0.032, 1.0)
		elif profile == "lilac":
			specular_limit = 0.22
			transmitted = Color(0.065, 0.080, 0.045, 1.0)
		elif profile == "sakura":
			specular_limit = 0.22
			transmitted = Color(0.090, 0.070, 0.075, 1.0)
		elif profile == "grass":
			specular_limit = 0.16
			roughness_floor = 0.90
			transmitted = Color(0.045, 0.060, 0.030, 1.0)
		material.metallic_specular = minf(original.metallic_specular, specular_limit)
		material.roughness = maxf(original.roughness, roughness_floor)
		# Thin leaves transmit a little light; this light-dependent builtin
		# response lifts flat dark card backs without emission or an SSS pass.
		# Keep a future artist-authored backlight configuration as supplied.
		if not original.backlight_enabled:
			material.backlight_enabled = true
			material.backlight = transmitted
	material.set_meta(ADAPTED_META, profile if not profile.is_empty() else "cutout_only")
	material.set_meta(SOURCE_META, source)
	_material_cache[source] = material
	return material

static func configure_mesh(mesh_instance: MeshInstance3D) -> int:
	if mesh_instance == null or mesh_instance.mesh == null:
		return 0
	if mesh_instance.material_override != null:
		var source := mesh_instance.material_override
		var material := build(source)
		if material != source:
			mesh_instance.material_override = material
			return 1
		return 0
	var changed := 0
	for surface: int in range(mesh_instance.mesh.get_surface_count()):
		var source := mesh_instance.get_active_material(surface)
		var material := build(source)
		if material != source:
			mesh_instance.set_surface_override_material(surface, material)
			changed += 1
	return changed

static func cache_size() -> int:
	return _material_cache.size()
