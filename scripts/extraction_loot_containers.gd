extends RefCounted
const Supply=preload("./extraction_weapon_supplies.gd")
const Clothing=preload("./extraction_clothing.gd")
const Tables = preload("./extraction_loot_tables.gd")
const CONTEXT_TYPE := "context_supply_case"
const Cans = preload("./extraction_canned_food.gd")
## Loot data and per-raid container state. No wearable pack or loose-world spawning.
const TYPE := "yellow_loot_backpack"
const BENCH_IDS := ["circuit", "optics", "cell", "archive"]
# Temporary game-balance masses and sale values, not measured asset properties.
const ITEMS := [
	{"id":"ration_bar", "title":"Field ration", "value":12, "mass_kg":0.15, "description":"Compact field ration. Restores 35 food reserve and 25 long-term energy. Eat from inventory during a raid.", "world_spawn":false},
	{"id":"bandage", "icon_path":"res://assets/ui/items/medical/bandage.png", "title":"Bandage", "value":15, "mass_kg":0.04, "description":"Sterile gauze bandage. Stops light bleeding on one selected body part in 3 seconds. Does not restore HP.", "world_spawn":false},
	{"id":"tourniquet", "icon_path":"res://assets/ui/items/medical/tourniquet.png", "title":"Tourniquet", "value":35, "mass_kg":0.09, "description":"Compact windlass tourniquet. In-game treatment for one heavy bleed, taking 5 seconds. Does not restore HP.", "world_spawn":false},
	{"id":"splint", "icon_path":"res://assets/ui/items/medical/splint.png", "title":"Splint", "value":25, "mass_kg":0.15, "description":"Folded foam-lined splint. Treats one fractured arm or leg in 5 seconds. Does not restore destroyed body parts or HP.", "world_spawn":false},
	{"id":"pliers", "icon_path":"res://assets/ui/items/loot/pliers.png", "title":"Pliers", "value":18, "mass_kg":0.30, "description":"A pair of utility pliers. Recoverable tool loot.", "world_spawn":false},
	{"id":"scissors", "icon_path":"res://assets/ui/items/loot/scissors.png", "title":"Scissors", "value":10, "mass_kg":0.08, "description":"A pair of scissors. Recoverable tool loot.", "world_spawn":false},
	{"id":"utility_knife", "icon_path":"res://assets/ui/items/loot/utility_knife.png", "title":"Utility knife", "value":16, "mass_kg":0.12, "description":"A utility knife recovered as tool loot.", "world_spawn":false},
	{"id":"bottled_water_closed", "icon_path":"res://assets/ui/items/loot/bottled_water_closed.png", "title":"Bottled water (closed)", "value":8, "mass_kg":0.52, "description":"A closed bottle of water. Stored as recovered supplies.", "world_spawn":false},
	{"id":"bottled_water_open", "icon_path":"res://assets/ui/items/loot/bottled_water_open.png", "title":"Bottled water (open)", "value":2, "mass_kg":0.27, "description":"An opened bottle of water. Stored separately from closed bottles.", "world_spawn":false},
	{"id":"sports_bottle_closed", "icon_path":"res://assets/ui/items/loot/sports_bottle_closed.png", "title":"Sports bottle (closed)", "value":14, "mass_kg":0.65, "description":"A closed reusable sports bottle. Recoverable supplies.", "world_spawn":false},
	{"id":"sports_bottle_open", "icon_path":"res://assets/ui/items/loot/sports_bottle_open.png", "title":"Sports bottle (open)", "value":7, "mass_kg":0.35, "description":"An opened reusable sports bottle. Stored separately from closed bottles.", "world_spawn":false}
] + Cans.ITEMS + Tables.ITEMS + Supply.ITEMS + Clothing.ITEMS

static func spec(id: String) -> Dictionary:
	for item: Dictionary in ITEMS:
		if item.id == id:
			return item.duplicate(true)
	return {}

static func allows_spawn(id: String, context: String) -> bool:
	if Cans.is_opened(id): return false
	if Tables.POOLS.has(context): return Tables.allows(id,context)
	if context == "bench":
		return id in BENCH_IDS
	if context == TYPE:
		if Supply.spec(id).has("weapon_id") or Supply.is_supply(id) or not Clothing.spec(id).is_empty(): return false
		if not Cans.spec(id).is_empty(): return id in Cans.SPAWN_IDS
		return not spec(id).is_empty()
	# Future loose-world spawners must explicitly query this eligibility.
	if context == "world":
		return bool(spec(id).get("world_spawn", false))
	return false

static func is_container(site: Dictionary) -> bool:
	return site.get("container_type", "") in [TYPE, CONTEXT_TYPE]

static func begin_run(site: Dictionary, rng: RandomNumberGenerator, run_token: String) -> void:
	if not is_container(site) or site.get("container_run", "") == run_token:
		return
	if site.get("container_type", "") == CONTEXT_TYPE:
		var contents: Array[Dictionary]=[]
		for id: String in Tables.roll(str(site.get("loot_context","")),rng,site.get("guaranteed",[])):
			var item:=spec(id)
			if not item.is_empty():contents.append(item)
		site["container_run"]=run_token;site["contents"]=contents;site["selected_loot"]=0;site["discovered"]=false
		sync_selection(site)
		return
	var pool: Array = ITEMS.filter(func(item: Dictionary) -> bool: return allows_spawn(str(item.id), TYPE)).duplicate(true)
	var contents: Array[Dictionary] = []
	for _index: int in range(rng.randi_range(2, 4)):
		var index := rng.randi_range(0, pool.size() - 1)
		contents.append(pool[index].duplicate(true))
		pool.remove_at(index)
	_pair_can_opener(contents)
	site["container_run"] = run_token
	site["contents"] = contents
	site["selected_loot"] = 0
	site["discovered"] = false
	sync_selection(site)

static func _pair_can_opener(contents: Array[Dictionary]) -> void:
	var needs_opener := false
	for item: Dictionary in contents:
		if str(item.id) == "canned_peaches": needs_opener = true
	if not needs_opener or Cans.has_opener(contents): return
	var opener := Cans.spec("can_opener")
	if contents.size() < 4:
		contents.append(opener)
		return
	# Prefer a tool/salvage/medical roll. Required food cans are never replaced.
	for index: int in range(contents.size()-1, -1, -1):
		if str(contents[index].id) in ["pliers", "scissors", "utility_knife", "bandage", "tourniquet", "splint", "circuit", "optics", "cell", "archive"]:
			contents[index] = opener
			return
	# Four food-only rolls are possible; ordinary old rations/drinks are the
	# fallback so a plain peach tin always remains practically openable.
	for index: int in range(contents.size()-1, -1, -1):
		if not Cans.is_closed(str(contents[index].id)) and not Cans.is_opened(str(contents[index].id)):
			contents[index] = opener
			return

static func sync_selection(site: Dictionary) -> void:
	var contents: Array = site.get("contents", [])
	var index := clampi(int(site.get("selected_loot", 0)), 0, maxi(0, contents.size() - 1))
	site["selected_loot"] = index
	site["loot"] = {} if contents.is_empty() else contents[index].duplicate(true)
	site["done"] = not bool(site.get("spawned", false)) or contents.is_empty()
	site["title"] = (str(site.get("empty_title","Empty supply case"))) if contents.is_empty() else ("Search "+str(site.container_title).to_lower()) if site.get("container_type","")==CONTEXT_TYPE else "Search yellow backpack"
	if site.get("container_type","")==TYPE:site["title"]="Empty yellow backpack" if contents.is_empty() else "Search yellow backpack"

static func select(site: Dictionary, index: int) -> bool:
	if not is_container(site) or index < 0 or index >= site.get("contents", []).size():
		return false
	site["selected_loot"] = index
	sync_selection(site)
	return true

static func remove_selected(site: Dictionary) -> bool:
	if not is_container(site) or site.get("loot", {}).is_empty() or bool(site.get("done", true)):
		return false
	site.contents.remove_at(int(site.selected_loot))
	sync_selection(site)
	return true
