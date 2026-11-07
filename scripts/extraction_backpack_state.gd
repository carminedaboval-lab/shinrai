extends RefCounted
const Clothing=preload("./extraction_clothing.gd")
const LootContainers = preload("./extraction_loot_containers.gd")
const Storage = preload("./extraction_storage_layout.gd")
const TEST_ARGUMENT := "--shinrai-test-backpacks"
const MOUNTAIN_CHANCE := 0.05
const REGULAR := "backpack_regular"
const MOUNTAIN := "backpack_mountain"
const PACKS := {
	REGULAR: {"title":"Field backpack", "value":0, "mass_kg":0.7, "extra_slots":4, "extra_kg":10.0},
	MOUNTAIN: {"title":"Mountain backpack", "value":0, "mass_kg":1.5, "extra_slots":8, "extra_kg":20.0}
}
# Proposed GAME BALANCE masses, not measurements of supplied real-world assets.
# Cargo only: currently equipped weapon/ammo/medical kit are outside bag semantics.
const CARGO_MASS_KG := {"circuit":0.25,"optics":0.35,"cell":3.50,"archive":0.20,"coffee_cup":0.30,"park_map":0.05,"garden_mikan":0.10,"garden_persimmon":0.18}

static func test_override(arguments: PackedStringArray, debug_build: bool) -> bool:
	return debug_build and arguments.has(TEST_ARGUMENT)

static func new_state(run_token: String) -> Dictionary:
	return {"run_token":run_token,"equipped_uid":"","serial":0,"spawn_rolled":false,"spawned":{},"collected":{},"clothing":Clothing.defaults()}

static func roll_spawns(state: Dictionary, mountain_roll: float, test_enabled: bool, debug_build: bool, regular_chance: float = 1.0, regular_roll: float = 0.0) -> Dictionary:
	# Once per state/run. UI inspection and pause/resume must reuse this result.
	if bool(state.get("spawn_rolled",false)):
		return state.spawned.duplicate()
	var forced := test_enabled and debug_build
	var mountain := is_finite(mountain_roll) and mountain_roll >= 0.0 and mountain_roll < MOUNTAIN_CHANCE
	var regular := is_finite(regular_roll) and regular_roll >= 0.0 and regular_roll < clampf(regular_chance,0.0,1.0)
	state.spawned = {REGULAR: forced or regular, MOUNTAIN: forced or mountain}
	state.collected = {REGULAR:false,MOUNTAIN:false}
	state.spawn_rolled = true
	return state.spawned.duplicate()

static func item_mass(item: Dictionary) -> float:
	var id := str(item.get("id",""))
	if PACKS.has(id): return float(PACKS[id].mass_kg)
	var contained := LootContainers.spec(id)
	if not contained.is_empty(): return float(contained.mass_kg)
	# Unknown cargo has conservative mass, not zero; untrusted item overrides ignored.
	return float(CARGO_MASS_KG.get(id,1.0))

static func cargo_mass(bag: Array) -> float:
	var mass := 0.0
	for item: Dictionary in bag: mass += item_mass(item)
	return mass

static func equipped_id(state: Dictionary, bag: Array) -> String:
	var uid := str(state.get("equipped_uid",""))
	if uid.is_empty(): return ""
	for item: Dictionary in bag:
		if str(item.get("pack_uid",""))==uid and PACKS.has(str(item.get("id",""))):
			return str(item.id)
	return ""

static func limits(state: Dictionary, bag: Array, purchased_level: int) -> Dictionary:
	var level := clampi(purchased_level,0,2)
	var id := equipped_id(state,bag)
	return {"slots":Clothing.pocket_slots(state.get("clothing",Clothing.defaults()))+(int(PACKS[id].extra_slots)+level*2 if not id.is_empty() else 0),
		"kg":20.0+(float(PACKS[id].extra_kg) if not id.is_empty() else 0.0)}

static func fits(state: Dictionary, bag: Array, purchased_level: int) -> bool:
	var cap := limits(state,bag,purchased_level)
	return cargo_mass(bag) <= float(cap.kg) + 0.00001 and Storage.build(state, bag, int(cap.slots)).overflow.is_empty()

static func layout(state: Dictionary, bag: Array, purchased_level: int) -> Dictionary:
	var cells := int(limits(state, bag, purchased_level).slots)
	return Storage.build(state, bag, cells)

static func settle(state: Dictionary, bag: Array, purchased_level: int) -> void:
	Storage.commit(bag, layout(state, bag, purchased_level))

static func load_ratio(state: Dictionary, bag: Array, purchased_level: int) -> float:
	return clampf(cargo_mass(bag)/float(limits(state,bag,purchased_level).kg),0.0,1.0)

static func _entry(state: Dictionary, id: String) -> Dictionary:
	return {"id":id,"title":str(PACKS[id].title),"value":int(PACKS[id].value),
		"pack_uid":"%s:%s:%d"%[state.run_token,id,int(state.serial)+1]}

static func pickup(state: Dictionary, bag: Array, id: String, purchased_level: int, model_ready: bool, equip_now: bool = true, replace_index: int = -1) -> bool:
	# Caller MUST also enforce existing raid phase/distance/pending-choice guards.
	if not model_ready or not PACKS.has(id) or not bool(state.get("spawn_rolled",false)):
		return false
	if not bool(state.spawned.get(id,false)) or bool(state.collected.get(id,false)):
		return false
	if replace_index < -1 or replace_index >= bag.size(): return false
	var candidate := bag.duplicate(true)
	var next := state.duplicate(true)
	var entry := _entry(state,id)
	if replace_index>=0:
		if str(candidate[replace_index].get("pack_uid",""))==str(next.equipped_uid): next.equipped_uid=""
		candidate[replace_index]=entry
	else: candidate.append(entry)
	var current_id := equipped_id(next,candidate)
	var better := current_id.is_empty() or (int(PACKS[id].extra_slots)>int(PACKS[current_id].extra_slots) and float(PACKS[id].extra_kg)>=float(PACKS[current_id].extra_kg))
	if equip_now and better: next.equipped_uid=entry.pack_uid
	if not fits(next,candidate,purchased_level): return false
	next.serial=int(next.serial)+1
	next.collected[id]=true
	bag.assign(candidate)
	state.merge(next,true)
	settle(state, bag, purchased_level)
	return true

static func equip(state: Dictionary, bag: Array, uid: String, purchased_level: int) -> bool:
	var found := uid.is_empty()
	for item: Dictionary in bag:
		if str(item.get("pack_uid",""))==uid and PACKS.has(str(item.get("id",""))): found=true
	if not found: return false
	var next := state.duplicate(true)
	next.equipped_uid=uid
	if not fits(next,bag,purchased_level): return false
	state.equipped_uid=uid
	return true

static func discard(state: Dictionary, bag: Array, index: int, purchased_level: int) -> bool:
	if index<0 or index>=bag.size(): return false
	var candidate := bag.duplicate(true)
	var next := state.duplicate(true)
	var worn := not str(next.equipped_uid).is_empty() and str(candidate[index].get("pack_uid","")) == str(next.equipped_uid)
	if worn: next.equipped_uid=""
	candidate.remove_at(index)
	# A legacy kit may already exceed the available cells. Allow ordinary
	# discards so the player can resolve it even if several items must go.
	if worn and not fits(next,candidate,purchased_level): return false
	bag.assign(candidate)
	state.equipped_uid=next.equipped_uid
	settle(state, bag, purchased_level)
	return true
