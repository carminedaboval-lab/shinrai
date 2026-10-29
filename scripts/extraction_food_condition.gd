extends RefCounted
const Cans = preload("./extraction_canned_food.gd")
## Local game balance: four hours of active raid time, never wall-clock expiry.
const DEFAULT_LIFETIME := 14400.0
const MAX_SICKNESS_SECONDS := 1800.0
const PERISHABLE_IDS := ["garden_mikan", "garden_persimmon"] + Cans.OPENED_IDS
const PRESERVED_IDS := ["ration_bar"]
const SEALED_IDS := ["bottled_water_closed", "sports_bottle_closed", "coffee_cup"] + Cans.CLOSED_IDS
const OPENED_IDS := ["bottled_water_open", "sports_bottle_open"]
const STORAGE_RATES := {"carried":1.0, "world":1.0, "stored":1.0}
const CONDITION_EFFECTS := {
	"fresh":{"food_multiplier":1.0,"water_multiplier":1.0,"energy_multiplier":1.0,"sickness_seconds":0.0,"sickness_severity":0.0,"sale_multiplier":1.0},
	"stale":{"food_multiplier":0.85,"water_multiplier":0.85,"energy_multiplier":0.85,"sickness_seconds":0.0,"sickness_severity":0.0,"sale_multiplier":0.75},
	"spoiled":{"food_multiplier":0.45,"water_multiplier":0.45,"energy_multiplier":0.45,"sickness_seconds":300.0,"sickness_severity":1.0,"sale_multiplier":0.25},
	"rotten":{"food_multiplier":0.10,"water_multiplier":0.10,"energy_multiplier":0.10,"sickness_seconds":720.0,"sickness_severity":2.0,"sale_multiplier":0.0}
}

static func is_food(id: String) -> bool:
	return is_perishable(id) or id in PRESERVED_IDS or id in SEALED_IDS or id in OPENED_IDS

static func is_perishable(id: String) -> bool:
	return id in PERISHABLE_IDS

static func default_lifetime(item_id: String) -> float:
	return Cans.OPENED_LIFETIME if Cans.is_opened(item_id) else DEFAULT_LIFETIME

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func ensure(item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	if not is_perishable(item_id): return
	var fallback := default_lifetime(item_id)
	if not item.has("food_condition"):
		item.food_condition = {"age_seconds":0.0, "lifetime_seconds":fallback}
		return
	# Existing malformed metadata must not turn questionable food fresh.
	if not item.food_condition is Dictionary:
		item.food_condition = {"age_seconds":fallback, "lifetime_seconds":fallback}
		return
	var condition: Dictionary = item.food_condition
	var lifetime := fallback
	var invalid := false
	if _number(condition.get("lifetime_seconds")) and float(condition.lifetime_seconds) > 0.0:
		lifetime = float(condition.lifetime_seconds)
	else:
		invalid = true
	var age := 0.0
	if _number(condition.get("age_seconds")) and float(condition.age_seconds) >= 0.0:
		age = float(condition.age_seconds)
	else:
		invalid = true
	if invalid: age = maxf(age, lifetime)
	# Preserve unknown metadata keys and all valid age, including age > lifetime.
	condition.age_seconds = age
	condition.lifetime_seconds = lifetime

static func seed(item: Dictionary, age_fraction: float = 0.0, lifetime: float = 0.0) -> void:
	var item_id := str(item.get("id", ""))
	if not is_perishable(item_id): return
	# A spawner may initialize a new record once; repeated setup cannot rejuvenate it.
	if item.has("food_condition"):
		ensure(item)
		return
	var life := lifetime if is_finite(lifetime) and lifetime > 0.0 else default_lifetime(item_id)
	var fraction := maxf(0.0, age_fraction) if is_finite(age_fraction) else 1.0
	var age := fraction * life
	if not is_finite(age): age = life
	item.food_condition = {"age_seconds":age, "lifetime_seconds":life}

static func state(item: Dictionary) -> String:
	var id := str(item.get("id", ""))
	if id in PRESERVED_IDS: return "preserved"
	if id in SEALED_IDS: return "sealed"
	if id in OPENED_IDS: return "opened"
	if not is_perishable(id): return ""
	ensure(item)
	var condition: Dictionary = item.food_condition
	var fraction := float(condition.age_seconds) / float(condition.lifetime_seconds)
	if fraction < 0.25: return "fresh"
	if fraction < 0.75: return "stale"
	if fraction < 1.0: return "spoiled"
	return "rotten"

static func label(item: Dictionary) -> String:
	return state(item).capitalize()

static func warning(item: Dictionary) -> String:
	match state(item):
		"stale": return "Stale: reduced nourishment."
		"spoiled": return "Spoiled: eating causes food poisoning."
		"rotten": return "Rotten: eating causes severe food poisoning."
	return ""

static func tint(item: Dictionary) -> Color:
	match state(item):
		"fresh": return Color("a8c798")
		"stale": return Color("d5c18b")
		"spoiled": return Color("dca16f")
		"rotten": return Color("ce8580")
	return Color("c6cecf")

static func advance(item: Dictionary, delta: float, storage: String = "carried") -> bool:
	if not is_perishable(str(item.get("id", ""))) or not is_finite(delta) or delta <= 0.0: return false
	ensure(item)
	var condition: Dictionary = item.food_condition
	var previous := float(condition.age_seconds)
	var next := previous + delta * float(STORAGE_RATES.get(storage, 1.0))
	# Saturating at the previous valid age avoids overflow rejuvenation.
	if not is_finite(next): next = previous
	condition.age_seconds = maxf(previous, next)
	return float(condition.age_seconds) != previous

static func effects(item: Dictionary) -> Dictionary:
	return CONDITION_EFFECTS.get(state(item), CONDITION_EFFECTS.fresh).duplicate(true)

static func sale_value(item: Dictionary, base_price: int) -> int:
	var multiplier := float(effects(item).sale_multiplier)
	return maxi(0, int(floor(float(maxi(0, base_price)) * multiplier)))
