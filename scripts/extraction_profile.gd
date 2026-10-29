extends RefCounted

# Kept separate from run state: carried loot is never persisted before extraction.
const VERSION := 1
const Clothing=preload("./extraction_clothing.gd")
const Supply=preload("./extraction_weapon_supplies.gd")
const Food = preload("./extraction_food_condition.gd")
const WeaponState = preload("./extraction_weapon_state.gd")
const PistolStarter = preload("./extraction_pistol_starter.gd")
var save_path := "user://shinrai_extraction_v1.json"
var data: Dictionary = defaults()
var last_error := ""
var recovered_interrupted_run := false

static func defaults() -> Dictionary:
	var initial: Dictionary = {"version": VERSION, "credits": 0, "stash": {}, "runs": 0,
		"extracts": 0, "pack_level": 0, "prepared_medkit": false, "active_run": false,
		"loadout": WeaponState.defaults(), "food_lots": {}, "food_lot_serial": 0, "food_illness": {}, "starter_pending":true,"clothing":Clothing.defaults(),"field_kit":[],"pistol_starter_version":0}
	var starter: Dictionary = PistolStarter.kit()
	if not starter.is_empty():
		initial.loadout = starter.loadout
		initial.field_kit = starter.field_kit
		initial.pistol_starter_version = PistolStarter.VERSION
	return initial

func load_profile() -> void:
	data = defaults()
	if not FileAccess.file_exists(save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary or int(parsed.get("version", -1)) != VERSION:
		last_error = "Save could not be read. Original file kept; saving is disabled."
		return
	# New-file defaults must never become a grant to an existing legacy file.
	# Only an explicit, backed-up PistolStarter.apply_existing(raw_data) may do so.
	data.loadout = WeaponState.defaults()
	data.field_kit = []
	data.pistol_starter_version = 0
	for key: String in data:
		if parsed.has(key) and typeof(parsed[key]) == typeof(data[key]):
			data[key] = parsed[key]
	# Retain future/unknown save fields alongside the known normalized schema.
	for key: String in parsed:
		if not data.has(key): data[key] = parsed[key]
	# JSON numbers are floats even when the saved value was an integer.
	for key: String in ["credits", "runs", "extracts", "pack_level", "food_lot_serial", "pistol_starter_version"]:
		if (parsed.get(key) is float or parsed.get(key) is int) and is_finite(float(parsed[key])):
			data[key] = maxi(0, int(parsed[key]))
	data.pack_level = mini(data.pack_level, 2)
	# Save files are untrusted data. Normalize quantities without deleting unknown
	# item ids, so future content stays banked and cannot create negative sales.
	var clean_stash: Dictionary = {}
	for key: Variant in data.stash:
		var amount: Variant = data.stash[key]
		if key is String and (amount is float or amount is int) and is_finite(float(amount)):
			var quantity := int(clampf(float(amount), 0.0, 1000000.0))
			if quantity > 0:
				clean_stash[key] = quantity
	data.stash = clean_stash
	data.clothing = Clothing.normalize(data.clothing)
	data.field_kit = data.field_kit.filter(func(item: Variant)->bool:return item is Dictionary and (str(item.get("id","")) in ["backpack_regular","backpack_mountain"] or Supply.is_supply(str(item.get("id",""))) or not Clothing.spec(str(item.get("id",""))).is_empty()))
	data.starter_pending = bool(parsed.get("starter_pending", false))
	data.loadout = WeaponState.normalize(data.loadout)
	# Migrate existing reserves once, conserving ammunition without free magazines.
	for id: String in data.loadout.weapons:
		var weapon: Dictionary = data.loadout.weapons[id]
		if bool(weapon.get("physical_magazines",false)): continue
		var ammunition_id := Supply.ammunition_id(id)
		if ammunition_id.is_empty(): continue # Preserve unknown reserve rather than discard it.
		var remaining := maxi(0,int(weapon.get("reserve",0)))
		while remaining>0:
			var packet := Supply.spec(ammunition_id)
			packet.rounds = mini(remaining,Supply.rounds(packet))
			remaining -= int(packet.rounds)
			data.field_kit.append(packet)
		weapon.reserve=0
		weapon.physical_magazines=true
		# Migrate an already-inserted legacy magazine without adding ammunition.
		if bool(weapon.get("magazine_inserted", false)):
			var inserted_rounds := int(weapon.ammo) - int(bool(weapon.chambered))
			weapon.inserted_magazine = preload("./extraction_magazine_record.gd").normalize(id, weapon.get("inserted_magazine"), inserted_rounds)
	data.food_illness = _normalize_food_illness(data.food_illness)
	_normalize_food_lots()
	recovered_interrupted_run = data.active_run
	if recovered_interrupted_run:
		data.active_run = false
		save_profile()

func save_profile() -> bool:
	if not last_error.is_empty():
		return false
	data.food_illness = _normalize_food_illness(data.get("food_illness", {}))
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Could not write the save. Your previous save is unchanged."
		return false
	var payload := JSON.stringify(data, "\t")
	var written: bool = file.store_string(payload)
	file.flush()
	file.close()
	# A successful buffered write does not guarantee the complete file reached close.
	if not written or FileAccess.get_file_as_bytes(temporary) != payload.to_utf8_buffer():
		last_error = "Could not write the save. Your previous save is unchanged."
		return false
	var result := DirAccess.rename_absolute(temporary, save_path)
	if result != OK:
		last_error = "Could not replace the save. Your previous save is unchanged."
		return false
	return true

func move_optic(optic_id: String, target: String, revision: int) -> bool:
	var previous: Dictionary = data.loadout.duplicate(true)
	if not WeaponState.move_optic(data.loadout, optic_id, target, revision):
		return false
	if save_profile():
		return true
	data.loadout = previous
	return false

func equip_weapon(weapon_id: String, revision: int, model_ready: bool) -> bool:
	var previous: Dictionary = data.loadout.duplicate(true)
	if not WeaponState.equip(data.loadout, weapon_id, revision, model_ready):
		return false
	if save_profile():
		return true
	data.loadout = previous
	return false

func begin_run() -> bool:
	var previous := data.duplicate(true)
	# Ammunition stays with owned weapons; deployment is not a free refill.
	data.starter_pending = false
	data.field_kit = []
	data.runs += 1
	data.active_run = true
	data.prepared_medkit = false
	if save_profile():
		recovered_interrupted_run = false
		return true
	data = previous
	return false

func complete_run(extracted: bool, bag: Array, bonus: int, field_loadout: Dictionary = {}, clothing: Dictionary = {}) -> bool:
	if not data.active_run:
		return false # Idempotent: a result screen cannot pay a second time.
	var previous := data.duplicate(true)
	_normalize_food_lots()
	data.active_run = false
	if extracted:
		if not field_loadout.is_empty(): data.loadout = WeaponState.normalize(field_loadout)
		if not clothing.is_empty(): data.clothing = Clothing.normalize(clothing)
		data.field_kit = []
		data.extracts += 1
		data.credits += bonus
		for item: Dictionary in bag:
			var key: String = item.id
			if key in ["backpack_regular","backpack_mountain"] or Supply.is_supply(key) or not Clothing.spec(key).is_empty():
				data.field_kit.append(item.duplicate(true))
				continue
			data.stash[key] = int(data.stash.get(key, 0)) + 1
			if Food.is_perishable(key): _append_food_lot(item)
	else:
		# Previously owned guns survive this game's failed-raid recovery, but spent
		# ammunition cannot reappear. Newly found weapons still require extraction.
		for id: String in data.loadout.weapons:
			if not field_loadout.get("weapons",{}).has(id):continue
			var current: Dictionary=field_loadout.weapons[id]
			for key: String in ["ammo","reserve","physical_magazines","magazine_inserted","inserted_magazine","chambered","bolt_locked"]:
				if current.has(key):
					var value: Variant = current[key]
					data.loadout.weapons[id][key] = value.duplicate(true) if value is Dictionary else value
	if save_profile():
		return true
	data = previous
	return false

func buy_upgrade() -> bool:
	if data.active_run or not last_error.is_empty():
		return false
	var level: int = data.pack_level
	if level >= 2:
		return false
	var price := 450 * (level + 1)
	if data.credits < price:
		return false
	data.credits -= price
	data.pack_level += 1
	if save_profile():
		return true
	data.credits += price
	data.pack_level -= 1
	return false

func buy_medkit() -> bool:
	if data.active_run or not last_error.is_empty():
		return false
	if data.prepared_medkit or data.credits < 120:
		return false
	data.credits -= 120
	data.prepared_medkit = true
	if save_profile():
		return true
	data.credits += 120
	data.prepared_medkit = false
	return false

func sell_item(item_id: String, quantity: int, prices: Dictionary) -> int:
	if Food.is_perishable(item_id):
		return _sell_food_selection(item_id, "", quantity, prices)
	if data.active_run or not last_error.is_empty() or quantity <= 0 or not prices.has(item_id):
		return 0
	var owned := int(data.stash.get(item_id, 0))
	var price := int(prices[item_id])
	if quantity > owned or price <= 0:
		return 0
	var previous := data.duplicate(true)
	var total := quantity * price
	data.credits += total
	if quantity == owned:
		data.stash.erase(item_id)
	else:
		data.stash[item_id] = owned - quantity
	if save_profile():
		return total
	data = previous
	return 0

func sell_stash(prices: Dictionary) -> int:
	if data.active_run or not last_error.is_empty():
		return 0
	var previous := data.duplicate(true)
	_normalize_food_lots()
	var total := 0
	for key: String in data.stash.keys():
		if Food.is_perishable(key):
			var quantity := 0
			for lot: Dictionary in data.food_lots.get(key, []):
				if Food.sale_value(_food_record(key, lot), int(prices.get(key, 0))) > 0:
					quantity += int(lot.quantity)
			if quantity > 0:
				var plan := _food_sale_plan(key, "", quantity, prices)
				if not plan.is_empty():
					total += int(plan.total)
					_apply_food_sale(key, plan)
		elif int(prices.get(key, 0)) > 0:
			total += int(data.stash[key]) * int(prices[key])
			data.stash.erase(key)
	if total <= 0:
		data = previous
		return 0
	data.credits += total
	if save_profile():
		return total
	data = previous
	return 0

static func _finite_food_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _normalize_food_illness(raw: Variant) -> Dictionary:
	if not raw is Dictionary: return {}
	var remaining := clampf(float(raw.remaining), 0.0, Food.MAX_SICKNESS_SECONDS) if _finite_food_number(raw.get("remaining")) else 0.0
	var severity := clampf(float(raw.severity), 0.0, 2.0) if _finite_food_number(raw.get("severity")) else 0.0
	var pulse := clampf(float(raw.pulse_elapsed), 0.0, 30.0) if _finite_food_number(raw.get("pulse_elapsed")) else 0.0
	var intolerance := clampf(float(raw.intolerance_remaining), 0.0, 60.0) if _finite_food_number(raw.get("intolerance_remaining")) else 0.0
	if remaining <= 0.0 or severity <= 0.0:
		remaining = 0.0
		severity = 0.0
		pulse = 0.0
	if remaining <= 0.0 and intolerance <= 0.0: return {}
	return {"remaining":remaining, "severity":severity, "pulse_elapsed":pulse, "intolerance_remaining":intolerance}

static func _valid_food_lot_id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 64: return false
	for code: int in value.to_utf8_buffer():
		if code == 45 or code == 95 or (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122): continue
		return false
	return true

func _new_food_lot_id(used: Dictionary) -> String:
	var serial := int(clampf(float(data.get("food_lot_serial", 0)), 0.0, 1000000000000.0))
	var id := ""
	while id.is_empty() or used.has(id):
		serial += 1
		id = "food_%d" % serial
	data.food_lot_serial = serial
	used[id] = true
	return id

func _used_food_lot_ids() -> Dictionary:
	var used: Dictionary = {}
	var stored: Variant = data.get("food_lots", {})
	if not stored is Dictionary: return used
	for value: Variant in stored.values():
		if not value is Array: continue
		for lot: Variant in value:
			if lot is Dictionary and _valid_food_lot_id(lot.get("lot_id")):
				used[str(lot.lot_id)] = true
	return used

static func _food_record(item_id: String, lot: Dictionary) -> Dictionary:
	var record := {"id":item_id}
	if lot.has("food_condition"):
		record.food_condition = lot.food_condition.duplicate(true) if lot.food_condition is Dictionary else lot.food_condition
	Food.ensure(record)
	return record

static func _food_age_fraction(lot: Dictionary) -> float:
	var condition: Dictionary = lot.food_condition
	return float(condition.age_seconds) / float(condition.lifetime_seconds)

func _normalize_food_lots() -> void:
	# Counts remain canonical. Legacy count-only fruit becomes ONE metadata lot,
	# even for a million units; never expand a count into individual item records.
	var raw: Dictionary = data.get("food_lots", {}) if data.get("food_lots", {}) is Dictionary else {}
	var result := raw.duplicate(true) # Unknown future food ids/metadata stay banked.
	var used: Dictionary = {}
	var reserved := _used_food_lot_ids()
	# Reserve unknown ids first so a known new lot cannot collide with future lots.
	for key: Variant in raw:
		if Food.is_perishable(str(key)) or not raw[key] is Array: continue
		for lot: Variant in raw[key]:
			if lot is Dictionary and _valid_food_lot_id(lot.get("lot_id")): used[str(lot.lot_id)] = true
	for item_id: String in Food.PERISHABLE_IDS:
		var owned := maxi(0, int(data.stash.get(item_id, 0)))
		if owned <= 0:
			result.erase(item_id)
			continue
		var pending: Array[Dictionary] = []
		var rows: Array = raw.get(item_id, []) if raw.get(item_id, []) is Array else []
		for value: Variant in rows:
			if not value is Dictionary: continue
			# Invalid quantity cannot launder a known old condition into new fresh stock.
			var quantity := int(clampf(float(value.quantity), 0.0, float(owned))) if _finite_food_number(value.get("quantity")) else owned
			if quantity <= 0: continue
			var record := _food_record(item_id, value)
			var lot: Dictionary = value.duplicate(true)
			lot.quantity = quantity
			lot.food_condition = record.food_condition
			pending.append(lot)
		# If damaged metadata overstates counts, preserve the oldest actual condition.
		pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _food_age_fraction(a) > _food_age_fraction(b))
		var normalized: Array[Dictionary] = []
		var remaining := owned
		for lot: Dictionary in pending:
			if remaining <= 0: break
			lot.quantity = mini(int(lot.quantity), remaining)
			var id := str(lot.get("lot_id", ""))
			if not _valid_food_lot_id(id) or used.has(id): id = _new_food_lot_id(reserved)
			used[id] = true
			lot.lot_id = id
			normalized.append(lot)
			remaining -= int(lot.quantity)
		if remaining > 0:
			var legacy := {"id":item_id}
			Food.ensure(legacy)
			var legacy_id := _new_food_lot_id(reserved)
			used[legacy_id] = true
			normalized.append({"lot_id":legacy_id, "quantity":remaining, "food_condition":legacy.food_condition})
		result[item_id] = normalized
	data.food_lots = result

func _append_food_lot(item: Dictionary) -> void:
	var item_id := str(item.id)
	var record := item.duplicate(true)
	Food.ensure(record)
	var lots: Array = data.food_lots.get(item_id, [])
	for lot: Dictionary in lots:
		if lot.food_condition == record.food_condition:
			lot.quantity = int(lot.quantity) + 1
			return
	lots.append({"lot_id":_new_food_lot_id(_used_food_lot_ids()), "quantity":1, "food_condition":record.food_condition.duplicate(true)})
	data.food_lots[item_id] = lots

func food_entries(spec: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var item_id := str(spec.get("id", ""))
	var owned := maxi(0, int(data.stash.get(item_id, 0)))
	if owned <= 0 or not Food.is_food(item_id): return entries
	if not Food.is_perishable(item_id):
		var entry := spec.duplicate(true)
		entry.quantity = owned
		entry.food_lot_id = ""
		entries.append(entry)
		return entries
	_normalize_food_lots()
	for lot: Dictionary in data.food_lots.get(item_id, []):
		var entry := spec.duplicate(true)
		entry.quantity = int(lot.quantity)
		entry.food_lot_id = str(lot.lot_id)
		entry.food_condition = lot.food_condition.duplicate(true)
		entry.value = Food.sale_value(entry, int(spec.get("value", 0)))
		entries.append(entry)
	return entries

func advance_food(delta: float) -> bool:
	if not is_finite(delta) or delta <= 0.0: return false
	# Load/transaction/UI boundaries reconcile counts and assign lot identities.
	# The active clock only changes existing condition metadata, in place.
	var changed := false
	for item_id: String in Food.PERISHABLE_IDS:
		for lot: Dictionary in data.food_lots.get(item_id, []):
			var record := {"id":item_id, "food_condition":lot.food_condition}
			if Food.advance(record, delta, "stored"):
				lot.food_condition = record.food_condition
				changed = true
	# Caller advances only its active raid clock and owns the save heartbeat.
	return changed

func _food_sale_plan(item_id: String, lot_id: String, quantity: int, prices: Dictionary) -> Dictionary:
	if quantity <= 0 or quantity > int(data.stash.get(item_id, 0)) or not prices.has(item_id): return {}
	var rows: Array = data.food_lots.get(item_id, []).duplicate(true)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _food_age_fraction(a) > _food_age_fraction(b))
	var selections: Dictionary = {}
	var remaining := quantity
	var total := 0
	for lot: Dictionary in rows:
		if not lot_id.is_empty() and str(lot.lot_id) != lot_id: continue
		var price := Food.sale_value(_food_record(item_id, lot), int(prices[item_id]))
		if price <= 0: continue # Rotten stock stays banked, never sold as fresh.
		var count := mini(remaining, int(lot.quantity))
		selections[str(lot.lot_id)] = count
		total += count * price
		remaining -= count
		if remaining <= 0: break
	if remaining > 0 or total <= 0: return {}
	return {"selections":selections, "quantity":quantity, "total":total}

func _apply_food_sale(item_id: String, plan: Dictionary) -> void:
	var kept: Array[Dictionary] = []
	for lot: Dictionary in data.food_lots.get(item_id, []):
		lot.quantity = int(lot.quantity) - int(plan.selections.get(str(lot.lot_id), 0))
		if int(lot.quantity) > 0: kept.append(lot)
	var remaining := int(data.stash[item_id]) - int(plan.quantity)
	if remaining > 0:
		data.stash[item_id] = remaining
		data.food_lots[item_id] = kept
	else:
		data.stash.erase(item_id)
		data.food_lots.erase(item_id)

func _sell_food_selection(item_id: String, lot_id: String, quantity: int, prices: Dictionary) -> int:
	if data.active_run or not last_error.is_empty() or quantity <= 0: return 0
	var previous := data.duplicate(true)
	_normalize_food_lots()
	var plan := _food_sale_plan(item_id, lot_id, quantity, prices)
	if plan.is_empty():
		data = previous
		return 0
	_apply_food_sale(item_id, plan)
	data.credits += int(plan.total)
	if save_profile(): return int(plan.total)
	data = previous
	return 0

func sell_food_lot(item_id: String, lot_id: String, quantity: int, prices: Dictionary) -> int:
	if not Food.is_perishable(item_id) or not _valid_food_lot_id(lot_id): return 0
	return _sell_food_selection(item_id, lot_id, quantity, prices)

func discard_food_lot(item_id: String, lot_id: String, quantity: int) -> bool:
	if data.active_run or not last_error.is_empty() or quantity <= 0: return false
	if not Food.is_perishable(item_id) or not _valid_food_lot_id(lot_id): return false
	var previous := data.duplicate(true)
	_normalize_food_lots()
	var available := 0
	for lot: Dictionary in data.food_lots.get(item_id, []):
		if str(lot.lot_id) == lot_id:
			available = int(lot.quantity)
			break
	if quantity > available or quantity > int(data.stash.get(item_id, 0)):
		data = previous
		return false
	# Discard has no price gate and never changes credits, including rotten stock.
	var selections := {lot_id:quantity}
	_apply_food_sale(item_id, {"selections":selections, "quantity":quantity})
	if save_profile(): return true
	data = previous
	return false
