extends RefCounted
## Independent once-per-house, once-per-raid rolls. Explicit interior anchors
## are owned by building access; commercial ground floors have no eligibility.
const Supply = preload("./extraction_weapon_supplies.gd")
const Catalog = preload("./extraction_weapon_catalog.gd")
const MagazineRecord = preload("./extraction_magazine_record.gd")
const Models = preload("./extraction_residential_models.gd")
const Household = preload("./extraction_household_loot.gd")
const GUN_CHANCE := .06
const MAGAZINE_CHANCE := .12
const REFILL_DELAY_SECONDS := 5100.0
const REFILL_MULTIPLIER := .75
const MAX_HOUSE_ITEMS := 4
const CATEGORIES := ["gun", "magazine", "attachment", "tool", "food"]
const REACH := 2.3
const HOMES := ["KobayashiHouse", "SugiCourtyardHouse", "AokiHouse", "WestCornerWorkshopResidence", "EastGardenResidence", "NishiTownhouse", "HigashiPorchHome"]
const SHOP_FLATS := ["MoriCoffee", "UedaBooks", "HinataDaily", "YakitoriShop"]
const SURFACES := ["table_top", "under_table", "kitchen_sink", "kitchen_counter", "toilet", "bed_top", "bedside", "bedside_floor", "upstairs_floor"]

static func rolled(gun_roll: float, magazine_roll: float) -> Dictionary:
	return {"gun": gun_roll >= 0.0 and gun_roll < GUN_CHANCE,
		"magazine": magazine_roll >= 0.0 and magazine_roll < MAGAZINE_CHANCE}

static func roll_house(rng: RandomNumberGenerator) -> Dictionary:
	return rolled(rng.randf(), rng.randf())

static func chance(item_category: String, refill: bool = false) -> float:
	var initial := GUN_CHANCE if item_category == "gun" else MAGAZINE_CHANCE if item_category == "magazine" else float(Household.categories().get(item_category, 0.0))
	return initial * REFILL_MULTIPLIER if refill else initial

static func refill_rolled(item_category: String, value: float) -> bool:
	return value >= 0.0 and value < chance(item_category, true)

static func category(site: Dictionary) -> String:
	if site.has("residential_category"): return str(site.residential_category)
	var item: Dictionary = site.get("loot", {})
	if not str(item.get("weapon_id", "")).is_empty(): return "gun"
	if Supply.MAGAZINES.has(str(item.get("id", ""))): return "magazine"
	return ""

static func tier(site: Dictionary) -> int:
	var item: Dictionary = site.get("loot", {})
	var weapon := str(item.get("weapon_id", Supply.MAGAZINES.get(str(item.get("id", "")), "")))
	return int(Supply.TIERS.get(weapon, 0)) if not weapon.is_empty() else Household.tier(item)

static func _weapon_pool(ordinary_only: bool = false) -> Array[String]:
	var pool: Array[String] = []
	for id: String in Catalog.READY_WEAPONS:
		if ordinary_only and int(Supply.TIERS.get(id, 0)) not in [1, 2, 3]: continue
		if Catalog.available(id) and not Supply.spec("weapon_" + id).is_empty() and not Supply.magazine_id(id).is_empty(): pool.append(id)
	return pool

static func _choose_item(item_category: String, rng: RandomNumberGenerator, ordinary_only: bool = false, matching_weapon: String = "") -> Dictionary:
	if item_category in ["gun", "magazine"]:
		var pool := _weapon_pool(ordinary_only)
		if pool.is_empty(): return {}
		var weapon := matching_weapon if matching_weapon in pool else pool[rng.randi_range(0, pool.size() - 1)]
		return MagazineRecord.normalize(weapon, {}, 0) if item_category == "magazine" else Supply.spec("weapon_" + weapon)
	var item: Dictionary = Household.item(item_category, rng)
	if ordinary_only and Household.tier(item) not in [1, 2, 3]: return {}
	return item

static func _active_house_sites(raid: Node, house_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site: Dictionary in raid.sites:
		if bool(site.get("residential_loot", false)) and str(site.get("residential_house_id", "")) == house_id and not bool(site.get("done", true)) and bool(site.get("spawned", false)):
			result.append(site)
	return result

static func _occupied(raid: Node, house_id: String) -> Array[AABB]:
	var result: Array[AABB] = []
	for site: Dictionary in _active_house_sites(raid, house_id):
		if site.get("residential_world_bounds") is AABB: result.append(site.residential_world_bounds)
	return result

static func houses(park: Node3D) -> Dictionary:
	var result := {}
	var street := park.get_node_or_null("MidoriSouthStreet") as Node3D
	if street == null: return result
	for node: Node in street.find_children("*", "Marker3D", true, false):
		var marker := node as Marker3D
		if not _valid_anchor(marker): continue
		var house_id := str(marker.get_meta("residential_house_id", ""))
		var surface := str(marker.get_meta("residential_surface", ""))
		if surface not in SURFACES: continue
		var extent: Vector2 = marker.get_meta("support_extent")
		if extent.x <= .02 or extent.y <= .02: continue
		var root: Node = marker.get_parent()
		while root != null and root != street and str(root.name) != house_id: root = root.get_parent()
		if root == null or root == street: continue
		if not result.has(house_id): result[house_id] = []
		result[house_id].append(marker)
	return result

static func begin_run(raid: Node, run_token: String) -> Dictionary:
	if run_token.is_empty(): return {"ok": false, "reason": "Missing raid token"}
	if str(raid.get_meta("residential_loot_run", "")) == run_token:
		return raid.get_meta("residential_loot_result", {}).duplicate(true)
	# New deployment clears all sites and pending collection timers. Same-token
	# calls retain both item state and the single scheduled refill opportunity.
	for site: Dictionary in raid.sites.duplicate():
		if not bool(site.get("residential_loot", false)): continue
		if is_instance_valid(site.get("pickup_node")): site.pickup_node.queue_free()
		raid.sites.erase(site)
	raid.set_meta("residential_loot_run", run_token)
	raid.set_meta("residential_next_refill_at", INF)
	raid.set_meta("residential_refill_events", [])
	var eligible := houses(raid.park)
	var keys: Array = eligible.keys()
	keys.sort()
	var result := {"ok": true, "run_token": run_token, "houses": keys.size(), "guns": 0, "magazines": 0, "attachments": 0, "tools": 0, "food": 0, "rolls": [], "failed_placements": [], "rejected_by_cap": []}
	for house_id: String in keys:
		# All five independent chances are rolled first. A four-item cap then
		# takes category order (gun, magazine, attachment, tool, food); no rerolls.
		var roll := {"house": house_id}
		for item_category: String in CATEGORIES: roll[item_category] = raid.rng.randf() < chance(item_category)
		result.rolls.append(roll)
		var chosen_weapon := ""
		for item_category: String in CATEGORIES:
			if not bool(roll[item_category]): continue
			if _active_house_sites(raid, house_id).size() >= MAX_HOUSE_ITEMS:
				result.rejected_by_cap.append(house_id + ":" + item_category); continue
			var item := _choose_item(item_category, raid.rng, false, chosen_weapon if item_category == "magazine" else "")
			if item_category == "gun": chosen_weapon = str(item.get("weapon_id", ""))
			var site := spawn_category(raid, house_id, eligible[house_id], item_category, item, _occupied(raid, house_id))
			if site.is_empty(): result.failed_placements.append(house_id + ":" + item_category + ":" + str(item.get("id", "")))
			else:
				var counter := "food" if item_category == "food" else item_category + "s"
				result[counter] += 1
	raid.set_meta("residential_loot_result", result.duplicate(true))
	if not result.failed_placements.is_empty(): push_warning("RESIDENTIAL_LOOT unavailable placements: " + str(result.failed_placements))
	return result

static func collected(raid: Node, site: Dictionary) -> bool:
	# Only successful real pickups call this hook, after inventory/weapon state
	# commits and the site becomes done. Failed pickups cannot start a timer.
	if not bool(site.get("residential_loot", false)) or not bool(site.get("done", false)) or site not in raid.sites: return false
	var token := str(raid.get_meta("residential_loot_run", ""))
	if token.is_empty() or str(site.get("residential_run_token", "")) != token: return false
	if str(site.get("residential_refill_status", "uncollected")) != "uncollected" or bool(site.get("residential_refill_attempted", false)): return false
	site.residential_collected_at = float(raid.run_time)
	if tier(site) not in [1, 2, 3] or category(site) not in CATEGORIES:
		site.residential_refill_status = "ineligible"
		return false
	var due := float(raid.run_time) + REFILL_DELAY_SECONDS
	site.residential_refill_due_at = due
	site.residential_refill_status = "scheduled"
	raid.set_meta("residential_next_refill_at", minf(float(raid.get_meta("residential_next_refill_at", INF)), due))
	return true

static func process_refills(raid: Node) -> Dictionary:
	var summary := {"attempted": 0, "spawned": 0, "empty": 0, "failed": 0, "cap_rejected": 0}
	var now := float(raid.run_time)
	if now < float(raid.get_meta("residential_next_refill_at", INF)): return summary
	var token := str(raid.get_meta("residential_loot_run", ""))
	if token.is_empty(): return summary
	var next_due := INF
	var eligible := houses(raid.park)
	for site: Dictionary in raid.sites:
		if not bool(site.get("residential_loot", false)) or str(site.get("residential_refill_status", "")) != "scheduled": continue
		if str(site.get("residential_run_token", "")) != token or bool(site.get("residential_refill_attempted", false)): continue
		var due := float(site.get("residential_refill_due_at", INF))
		if now < due: next_due = minf(next_due, due); continue
		# Mark terminal before any RNG/model work; frame frequency, later visits
		# and repeated collect notifications can never create another attempt.
		site.residential_refill_attempted = true
		site.residential_refill_status = "rolled_empty"
		var item_category := category(site)
		if not bool(site.get("done", false)) or tier(site) not in [1, 2, 3]:
			site.residential_refill_status = "ineligible"; continue
		var roll: float = raid.rng.randf()
		site.residential_refill_roll = roll
		summary.attempted += 1
		var house_id := str(site.residential_house_id)
		var event := {"id": str(site.id), "category": item_category, "due": due, "at": now, "roll": roll, "chance": chance(item_category, true), "status": "rolled_empty"}
		if not refill_rolled(item_category, roll): summary.empty += 1
		elif _active_house_sites(raid, house_id).size() >= MAX_HOUSE_ITEMS:
			site.residential_refill_status = "cap_rejected"; summary.cap_rejected += 1
		else:
			var item := _choose_item(item_category, raid.rng, true)
			var replacement := _build_site(raid, house_id, eligible.get(house_id, []), item_category, item, _occupied(raid, house_id))
			if replacement.is_empty():
				site.residential_refill_status = "placement_failed"; summary.failed += 1
			else:
				if is_instance_valid(site.get("pickup_node")): site.pickup_node.queue_free()
				var collected_at := float(site.residential_collected_at)
				# Reuse the stable Dictionary and ID so no duplicated interaction
				# or stale reference remains when the new model becomes available.
				for key: Variant in replacement: site[key] = replacement[key]
				site.residential_collected_at = collected_at
				site.residential_refill_due_at = due
				site.residential_refill_roll = roll
				site.residential_refill_attempted = true
				site.residential_refill_status = "spawned"
				summary.spawned += 1
		event.status = str(site.residential_refill_status)
		var events: Array = raid.get_meta("residential_refill_events", [])
		events.append(event)
		raid.set_meta("residential_refill_events", events)
	raid.set_meta("residential_next_refill_at", next_due)
	return summary

static func spawn_item(raid: Node, house_id: String, anchors: Array, weapon_id: String, magazine_only: bool, occupied: Array[AABB] = []) -> Dictionary:
	# Shared production/fixture path: fixtures can exercise every physical item
	# without modifying the shipped spawn probabilities or a player's profile.
	var category := "magazine" if magazine_only else "gun"
	var item: Dictionary = MagazineRecord.normalize(weapon_id, {}, 0) if magazine_only else Supply.spec("weapon_" + weapon_id)
	return spawn_category(raid, house_id, anchors, category, item, occupied)

static func spawn_category(raid: Node, house_id: String, anchors: Array, item_category: String, item: Dictionary, occupied: Array[AABB] = []) -> Dictionary:
	var site_id := "residential_" + house_id + "_" + item_category
	if raid.sites.any(func(site: Dictionary) -> bool: return str(site.get("id", "")) == site_id) or _active_house_sites(raid, house_id).size() >= MAX_HOUSE_ITEMS: return {}
	var all_occupied := _occupied(raid, house_id)
	all_occupied.append_array(occupied)
	var site := _build_site(raid, house_id, anchors, item_category, item, all_occupied)
	if not site.is_empty(): raid.sites.append(site)
	return site

static func _build_site(raid: Node, house_id: String, anchors: Array, item_category: String, item: Dictionary, occupied: Array[AABB]) -> Dictionary:
	if item.is_empty() or item_category not in CATEGORIES: return {}
	var site_id := "residential_" + house_id + "_" + item_category
	var weapon_id := str(item.get("weapon_id", Supply.MAGAZINES.get(str(item.get("id", "")), "")))
	var visual: Node3D = Models.build(weapon_id, item_category == "magazine") if item_category in ["gun", "magazine"] else Household.model(item)
	if visual == null: return {}
	var local_bounds := Models.bounds(visual)
	var choices: Array[Dictionary] = []
	for value: Variant in anchors:
		var marker := value as Marker3D
		if marker == null or not marker.is_inside_tree() or not _valid_anchor(marker) or str(marker.get_meta("residential_house_id", "")) != house_id: continue
		var extent: Vector2 = marker.get_meta("support_extent", Vector2.ZERO)
		if local_bounds.size.y > float(marker.get_meta("clearance_height", .6)): continue
		for quarter_turn: bool in [false, true]:
			var footprint := Vector2(local_bounds.size.z, local_bounds.size.x) if quarter_turn else Vector2(local_bounds.size.x, local_bounds.size.z)
			if footprint.x + .02 > extent.x or footprint.y + .02 > extent.y: continue
			var basis := marker.global_basis.orthonormalized() * Basis(Vector3.UP, PI * .5 if quarter_turn else 0.0)
			var placed := Transform3D(basis, marker.global_position)
			var box: AABB = placed * local_bounds
			var interior := marker.get_parent().get_parent() as Node3D
			var house := interior.get_parent() as Node3D
			var inner: AABB = interior.get_meta("residential_inner_bounds")
			var house_box: AABB = (house.global_transform.affine_inverse() * placed) * local_bounds
			if not inner.encloses(house_box): continue
			if occupied.any(func(other: AABB) -> bool: return other.grow(.025).intersects(box)): continue
			if not _supported(raid.park, marker): continue
			choices.append({"marker": marker, "transform": placed, "bounds": box})
	if choices.is_empty(): visual.free(); return {}
	var selected: Dictionary = choices[raid.rng.randi_range(0, choices.size() - 1)]
	var marker: Marker3D = selected.marker
	var pickup := Node3D.new()
	pickup.name = site_id
	pickup.set_meta("creator_protected", true)
	pickup.set_meta("creator_editable", false)
	pickup.set_meta("creator_object_kind", "residential_loot")
	pickup.add_child(visual)
	raid.park.add_child(pickup)
	pickup.global_transform = selected.transform
	var target := pickup.to_global(local_bounds.get_center())
	var site := {"id": site_id, "title": "Recover " + str(item.title), "kind": "cache", "position": target,
		"done": false, "spawned": true, "discovered": false, "pickup_node": pickup, "ammo_bonus": 0,
		"loot": item, "fixed_loot": item.duplicate(true), "residential_loot": true,
		"residential_category": item_category, "residential_run_token": str(raid.get_meta("residential_loot_run", "")),
		"residential_refill_status": "uncollected", "residential_refill_attempted": false,
		"residential_refill_due_at": -1.0, "residential_collected_at": -1.0,
		"residential_house_id": house_id, "residential_surface": str(marker.get_meta("residential_surface", "")),
		"residential_upper_floor": bool(marker.get_meta("residential_upper_floor", false)),
		"residential_anchor": marker.get_path(), "residential_support_position": marker.global_position,
		"residential_world_bounds": selected.bounds, "residential_model_size": local_bounds.size,
		"model_bottom_y": (selected.bounds as AABB).position.y}
	return site

static func _valid_anchor(marker: Marker3D) -> bool:
	if not bool(marker.get_meta("residential_loot_anchor", false)): return false
	var house_id := str(marker.get_meta("residential_house_id", ""))
	if house_id not in HOMES and house_id not in SHOP_FLATS: return false
	if str(marker.get_meta("residential_surface", "")) not in SURFACES: return false
	if house_id in SHOP_FLATS and not bool(marker.get_meta("residential_upper_floor", false)): return false
	if not marker.get_meta("support_extent", null) is Vector2: return false
	var anchors := marker.get_parent()
	if anchors == null or str(anchors.name) != "ResidentialLootAnchors": return false
	var interior := anchors.get_parent()
	if interior == null or str(interior.name) != "BuildingAccessInterior" or not interior.get_meta("residential_inner_bounds", null) is AABB: return false
	var house := interior.get_parent()
	return house is Node3D and str(house.name) == house_id

static func _supported(park: Node3D, marker: Marker3D) -> bool:
	if not park.is_inside_tree(): return false
	var point := marker.global_position
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * .04, point - Vector3.UP * .08, 1)
	var hit := park.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and (hit.normal as Vector3).dot(Vector3.UP) > .9 and absf(float(hit.position.y) - point.y) < .035

static func reachable(player: Node3D, site: Dictionary) -> bool:
	if not bool(site.get("residential_loot", false)): return true
	if not player.is_inside_tree() or player.global_position.distance_to(site.position) > REACH: return false
	var camera: Camera3D = player.get("camera") as Camera3D
	if camera == null or not player is CollisionObject3D: return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, site.position, 1, [(player as CollisionObject3D).get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
