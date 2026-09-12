extends Node

const CAT_CAFE_SIGN: PackedScene = preload(
	"res://assets/shinrai/signage/cat_cafe/SHINRAI_CatCafeSign_HQ.tscn"
)

# The current visual-comparison / Yakitori work is centred on the locked
# east-west corridor at world z ~= 36. Keep the Cat Café completely away from it.
const RECENT_WORK_MIN_X: float = 0.0
const RECENT_WORK_MAX_X: float = 43.0
const RECENT_WORK_MIN_Z: float = 26.0
const RECENT_WORK_MAX_Z: float = 46.0

# Stable offset used only by this placer. It does NOT consume town_main.gd's RNG.
const CAT_CAFE_RANDOM_SALT: int = 1346459221

@export var mount_height_m: float = 3.25
@export var visibility_range_m: float = 38.0
@export var print_selected_building: bool = true

func _ready() -> void:
	call_deferred("_place_after_town_generation")

func _place_after_town_generation() -> void:
	# Child _ready() runs before Blacksite's _ready(), so retry for a few frames
	# until ProceduralTownGeometry has been generated.
	for _attempt: int in range(12):
		if _try_place_sign():
			return
		await get_tree().process_frame
	push_warning("Cat Café sign: no eligible building was found after town generation.")

func _try_place_sign() -> bool:
	var town: Node = get_parent()
	if town == null:
		return false

	var geometry_root: Node3D = town.get_node_or_null("ProceduralTownGeometry") as Node3D
	if geometry_root == null:
		return false

	# Do not place twice if the scene is reloaded/re-entered in an unusual setup.
	if geometry_root.find_child("CatCafeSign_Runtime", true, false) != null:
		return true

	var preferred: Array[Node3D] = []
	var fallback: Array[Node3D] = []

	for child: Node in geometry_root.get_children():
		var building: Node3D = child as Node3D
		if building == null:
			continue
		if not String(building.name).begins_with("Block"):
			continue
		if _is_recent_work(building):
			continue
		if building.get_node_or_null("ClosedShutter") != null:
			continue

		var body: MeshInstance3D = _shop_body(building)
		if body == null:
			continue

		# Mixed-use shops are visually neutral and make the most believable
		# conversion into a Cat Café without fighting explicit ramen/izakaya art.
		if building.get_node_or_null("MixedHeader") != null:
			preferred.append(building)
		elif _is_non_shuttered_shop(building):
			fallback.append(building)

	var candidates: Array[Node3D] = preferred if not preferred.is_empty() else fallback
	if candidates.is_empty():
		return false

	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return String(a.name) < String(b.name)
	)

	var rng := RandomNumberGenerator.new()
	var generation_seed: int = int(town.get("generation_seed"))
	rng.seed = generation_seed + CAT_CAFE_RANDOM_SALT
	var selected: Node3D = candidates[rng.randi_range(0, candidates.size() - 1)]

	return _mount_on_building(selected)

func _is_recent_work(building: Node3D) -> bool:
	if building.is_in_group("shinrai_authored_yakitori_shop"):
		return true
	if bool(building.get_meta("shinrai_authored_yakitori_shop", false)):
		return true
	if "Yakitori" in String(building.name):
		return true

	var p: Vector3 = building.global_position
	return (
		p.x >= RECENT_WORK_MIN_X
		and p.x <= RECENT_WORK_MAX_X
		and p.z >= RECENT_WORK_MIN_Z
		and p.z <= RECENT_WORK_MAX_Z
	)

func _is_non_shuttered_shop(building: Node3D) -> bool:
	return (
		building.get_node_or_null("ShopBody") != null
		or building.get_node_or_null("UpperShopBody") != null
	)

func _shop_body(building: Node3D) -> MeshInstance3D:
	var body: MeshInstance3D = building.get_node_or_null("ShopBody") as MeshInstance3D
	if body == null:
		body = building.get_node_or_null("UpperShopBody") as MeshInstance3D
	return body

func _mount_on_building(building: Node3D) -> bool:
	var body: MeshInstance3D = _shop_body(building)
	if body == null or body.mesh == null:
		return false

	var body_aabb: AABB = body.mesh.get_aabb()
	var width_m: float = body_aabb.size.x
	var depth_m: float = body_aabb.size.z
	if width_m <= 0.1 or depth_m <= 0.1:
		return false

	# Procedural shop fronts face local -Z. The sign was authored to the same
	# convention, with its wall plane at local Z=0 and all projection toward -Z.
	var facade_z: float = body.position.z - depth_m * 0.5

	var sign: Node3D = CAT_CAFE_SIGN.instantiate() as Node3D
	if sign == null:
		push_error("Cat Café sign scene failed to instantiate.")
		return false

	sign.name = "CatCafeSign_Runtime"
	building.add_child(sign)

	# Put the round sign on the right half of the shop, above the awning/header.
	# The asset's wall plate is offset left of the circular body, matching the
	# approved reference sheet.
	var max_center_x: float = maxf(0.60, width_m * 0.5 - 0.42)
	var sign_center_x: float = clampf(width_m * 0.28, 0.68, max_center_x)
	sign.position = Vector3(sign_center_x, mount_height_m, facade_z - 0.012)
	sign.rotation = Vector3.ZERO
	sign.scale = Vector3.ONE
	sign.set_meta("shinrai_cat_cafe_sign", true)

	for node: Node in sign.find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		if geometry != null:
			geometry.visibility_range_end = visibility_range_m
			geometry.visibility_range_end_margin = 6.0

	if print_selected_building:
		print(
			"SHINRAI Cat Café: mounted on ",
			building.name,
			" at ",
			building.global_position,
			" (recent Yakitori/comparison work excluded)"
		)

	return true
