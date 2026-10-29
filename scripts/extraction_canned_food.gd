extends RefCounted
## Pure catalog/opening rules. No Food preload: Food and loot both depend on this.
const OPENED_LIFETIME := 7200.0
const CLOSED_IDS := ["canned_mackerel", "canned_peaches"]
const OPENED_IDS := ["canned_mackerel_open", "canned_peaches_open"]
const SPAWN_IDS := ["canned_mackerel", "canned_peaches", "can_opener"]
const OPENED_PAIRS := {"canned_mackerel":"canned_mackerel_open", "canned_peaches":"canned_peaches_open"}
# Masses, values and nutrition are local game balance, not product measurements.
const ITEMS := [
	{"id":"canned_mackerel", "title":"Canned mackerel (sealed)", "value":14, "mass_kg":0.22,
		"description":"Sealed pull-tab tin of mackerel. Open during a raid without a tool before eating. Once opened, restores 35 food and 12 energy but costs 5 water while fresh and can spoil.", "opening_method":"pull_tab", "requires_opener":false, "world_spawn":false},
	{"id":"canned_mackerel_open", "title":"Canned mackerel (opened)", "value":6, "mass_kg":0.22,
		"description":"Opened mackerel tin. While fresh, restores 35 food and 12 energy but costs 5 water. Perishable after opening; inspect its condition before eating.", "opening_method":"opened", "requires_opener":false, "world_spawn":false},
	{"id":"canned_peaches", "title":"Canned peaches (sealed)", "value":12, "mass_kg":0.42,
		"description":"Sealed tin of peaches. Requires a can opener in carried cargo and must be opened during a raid before eating. Once opened, restores 25 food, 20 water and 8 energy while fresh and can spoil.", "opening_method":"can_opener", "requires_opener":true, "world_spawn":false},
	{"id":"canned_peaches_open", "title":"Canned peaches (opened)", "value":5, "mass_kg":0.42,
		"description":"Opened peaches tin. While fresh, restores 25 food, 20 water and 8 energy. Perishable after opening; inspect its condition before eating.", "opening_method":"opened", "requires_opener":false, "world_spawn":false},
	{"id":"can_opener", "title":"Can opener", "value":9, "mass_kg":0.08,
		"description":"Reusable can opener. Carry it in cargo to open food tins that require a tool. Opening a tin does not consume the opener.", "world_spawn":false}
]

static func spec(id: String) -> Dictionary:
	for item: Dictionary in ITEMS:
		if str(item.id) == id: return item.duplicate(true)
	return {}

static func is_closed(id: String) -> bool:
	return id in CLOSED_IDS

static func is_opened(id: String) -> bool:
	return id in OPENED_IDS

static func has_opener(bag: Array) -> bool:
	for item: Variant in bag:
		if item is Dictionary and str(item.get("id", "")) == "can_opener": return true
	return false

static func can_open(item: Dictionary, bag: Array) -> bool:
	var id := str(item.get("id", ""))
	if not is_closed(id): return false
	# Stable item identity, never caller-editable metadata, controls tool eligibility.
	return id == "canned_mackerel" or has_opener(bag)

static func blocked_reason(item: Dictionary, bag: Array) -> String:
	var id := str(item.get("id", ""))
	if is_opened(id): return "This can is already open."
	if not is_closed(id): return "Select a sealed food can."
	if not can_open(item, bag): return "Requires a can opener in your cargo."
	return ""

static func opened_copy(item: Dictionary) -> Dictionary:
	var id := str(item.get("id", ""))
	if not is_closed(id): return {} # An opened record can never be reopened/refreshed.
	var opened := item.duplicate(true)
	var catalog := spec(str(OPENED_PAIRS[id]))
	for key: String in catalog: opened[key] = catalog[key]
	# Closed tins have no expiry clock. Opening creates the first perishable state;
	# irrelevant closed condition metadata must not become the new food's lifetime.
	opened.food_condition = {"age_seconds":0.0, "lifetime_seconds":OPENED_LIFETIME}
	return opened
