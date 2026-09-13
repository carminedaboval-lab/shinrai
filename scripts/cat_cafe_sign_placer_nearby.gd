extends Node

const CAT_CAFE_SIGN: PackedScene = preload(
	"res://assets/shinrai/signage/cat_cafe/SHINRAI_CatCafeSign_HQ.tscn"
)

# Keep the Cat Café away from the current Yakitori/comparison work.
const RECENT_WORK_MIN_X: float = 0.0
const RECENT_WORK_MAX_X: float = 43.0
const RECENT_WORK_MIN_Z: float = 26.0
const RECENT_WORK_MAX_Z: float = 46.0

# Keep the sign easy to reach from the current test spawn.
const MIN_SPAWN_DISTANCE_M: float = 10.0
const MAX_SPAWN_DISTANCE_M: float = 38.0

# Stable RNG. Does not consume town_main.gd's procedural RNG.
const CAT_CAFE_RANDOM_SALT: int = 1346459221

@export var mount_height_m: float = 3.25
@export var visibility_range_m: float = 46.0
@export var print_selected_building: bool = true

func _ready() -> void:
	call_deferred("_place_after_town_generation")

func _place_after_town_generation() -> void:
	for _attempt: int in range(20):
		if _try_place_sign():
			return
		await get_tree().process_frame
	push_warning("Cat Café sign: no eligible nearby building was found after town generation.")

func _try_place_sign() -> bool:
	var town: Node = get_parent()
	if town == null:
		return false

	var geometry_root: Node3D = town.get_node_or_null("ProceduralTownGeometry") as Node3D
	if geometry_root == null:
		return false

	if geometry_root.find_child("CatCafeSign_Runtime", true, false) != null:
		return true

	var spawn_world: Vector3 = _get_spawn_world(town)

	var preferred_nearby: Array[Node3D] = []
	var fallback_nearby: Array[Node3D] = []
	var preferred_any: Array[Node3D] = []
	var fallback_any: Array[Node3D] = []

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

		var is_preferred: bool = building.get_node_or_null("MixedHeader") != null
		var is_shop: bool = is_preferred or _is_non_shuttered_shop(building)
		if not is_shop:
			continue

		var distance_m: float = _horizontal_distance(building.global_position, spawn_world)
		var nearby: bool = (
			distance_m >= MIN_SPAWN_DISTANCE_M
			and distance_m <= MAX_SPAWN_DISTANCE_M
		)

		if is_preferred:
			preferred_any.append(building)
			if nearby:
				preferred_nearby.append(building)
		else:
			fallback_any.append(building)
			if nearby:
				fallback_nearby.append(building)

	var candidates: Array[Node3D] = []
	if not preferred_nearby.is_empty():
		candidates = preferred_nearby
	elif not fallback_nearby.is_empty():
		candidates = fallback_nearby
	elif not preferred_any.is_empty():
		candidates = preferred_any
	else:
		candidates = fallback_any

	if candidates.is_empty():
		return false

	# First sort nearest-to-farthest, then randomize only within the nearest few.
	# This keeps the result feeling random without hiding the sign across town.
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var da: float = _horizontal_distance(a.global_position, spawn_world)
		var db: float = _horizontal_distance(b.global_position, spawn_world)
		if absf(da - db) < 0.01:
			return String(a.name) < String(b.name)
		return da < db
	)

	var shortlist_count: int = mini(4, candidates.size())
	var rng := RandomNumberGenerator.new()
	var generation_seed: int = int(town.get("generation_seed"))
	rng.seed = generation_seed + CAT_CAFE_RANDOM_SALT
	var selected: Node3D = candidates[rng.randi_range(0, shortlist_count - 1)]

	return _mount_on_building(selected, spawn_world)

func _get_spawn_world(town: Node) -> Vector3:
	var spawn_cell_variant: Variant = town.get("player_spawn_cell")
	if spawn_cell_variant is Vector2i and town.has_method("_cell_to_world"):
		return town.call("_cell_to_world", spawn_cell_variant, 0.0)
	return Vector3(21.6, 0.0, 36.0)

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

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

func _mount_on_building(building: Node3D, spawn_world: Vector3) -> bool:
	var body: MeshInstance3D = _shop_body(building)
	if body == null or body.mesh == null:
		return false

	var body_aabb: AABB = body.mesh.get_aabb()
	var width_m: float = body_aabb.size.x
	var depth_m: float = body_aabb.size.z
	if width_m <= 0.1 or depth_m <= 0.1:
		return false

	var facade_z: float = body.position.z - depth_m * 0.5

	var sign: Node3D = CAT_CAFE_SIGN.instantiate() as Node3D
	if sign == null:
		push_error("Cat Café sign scene failed to instantiate.")
		return false

	sign.name = "CatCafeSign_Runtime"
	building.add_child(sign)

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
			geometry.visibility_range_end_margin = 8.0

	if print_selected_building:
		print(
			"SHINRAI Cat Café: mounted on ",
			building.name,
			" at ",
			building.global_position,
			" | distance from spawn=",
			snappedf(_horizontal_distance(building.global_position, spawn_world), 0.1),
			" m | recent Yakitori/comparison work excluded"
		)

	return true
