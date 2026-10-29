extends RefCounted

const Catalog = preload("res://scripts/extraction_weapon_catalog.gd")
const MagazineRecord = preload("./extraction_magazine_record.gd")

static func defaults() -> Dictionary:
	return {"equipped":"", "weapons":{}, "loose_optics":[], "revision":0}

static func recovered_weapon(id: String) -> Dictionary:
	if not Catalog.WEAPONS.has(id): return {}
	var spec: Dictionary = Catalog.weapon(id)
	return {"ammo":0,"reserve":0,"optic":"","physical_magazines":true,
		"chambered":false,"magazine_inserted":false,"inserted_magazine":{},"bolt_locked":false,"ammo_type":spec.ammo_type}

static func _quantity(value: Variant, maximum: int, fallback: int) -> int:
	if (value is int or value is float) and is_finite(float(value)):
		return int(clampf(float(value), 0.0, float(maximum)))
	return clampi(fallback,0,maximum)

static func normalize(raw: Variant) -> Dictionary:
	var clean := defaults()
	if not raw is Dictionary:
		return clean
	clean.revision = _quantity(raw.get("revision"), 2000000000, 0)
	var records: Variant = raw.get("weapons", {})
	var used: Dictionary = {}
	for id: String in Catalog.WEAPONS:
		if not records is Dictionary or not records.has(id): continue
		clean.weapons[id] = recovered_weapon(id)
		var record: Variant = records.get(id, {}) if records is Dictionary else {}
		if not record is Dictionary:
			record = {}
		var closed_bolt := bool(Catalog.weapon(id).closed_bolt)
		var chambered: bool = bool(record.get("chambered", _quantity(record.get("ammo"),999,clean.weapons[id].ammo)>0)) and closed_bolt
		var inserted := bool(record.get("magazine_inserted",true))
		clean.weapons[id].physical_magazines = bool(record.get("physical_magazines",false))
		var maximum: int = int(Catalog.WEAPONS[id].magazine) + int(chambered) if inserted else int(chambered)
		clean.weapons[id].ammo = _quantity(record.get("ammo"), maximum, clean.weapons[id].ammo)
		clean.weapons[id].chambered = chambered and clean.weapons[id].ammo > 0
		clean.weapons[id].magazine_inserted = inserted
		if inserted and clean.weapons[id].physical_magazines:
			var remaining := int(clean.weapons[id].ammo) - int(clean.weapons[id].chambered)
			clean.weapons[id].inserted_magazine = MagazineRecord.normalize(id, record.get("inserted_magazine"), remaining)
		clean.weapons[id].bolt_locked = closed_bolt and not clean.weapons[id].chambered and bool(record.get("bolt_locked",clean.weapons[id].ammo==0))
		clean.weapons[id].reserve = _quantity(record.get("reserve"), 999, clean.weapons[id].reserve)
		var attachment := str(record.get("optic", clean.weapons[id].optic))
		if not Catalog.compatible(id, attachment) or used.has(attachment):
			attachment = ""
		clean.weapons[id].optic = attachment
		if not attachment.is_empty():
			used[attachment] = true
	# Retain only attachments actually present in the save; never grant free gear.
	clean.loose_optics = []
	var tray: Variant = raw.get("loose_optics", [])
	if tray is Array:
		for value: Variant in tray:
			var optic := str(value)
			if Catalog.OPTICS.has(optic) and not used.has(optic):
				clean.loose_optics.append(optic)
				used[optic] = true
	var equipped := str(raw.get("equipped", ""))
	clean.equipped = equipped if clean.weapons.has(equipped) else (str(clean.weapons.keys()[0]) if not clean.weapons.is_empty() else "")
	return clean

static func location(state: Dictionary, optic_id: String) -> String:
	for id: String in state.weapons:
		if state.weapons[id].optic == optic_id:
			return id
	return "tray" if state.loose_optics.has(optic_id) else ""

static func move_optic(state: Dictionary, optic_id: String, target: String, revision: int) -> bool:
	if int(state.revision) != revision or not Catalog.OPTICS.has(optic_id):
		return false
	var source := location(state, optic_id)
	if source.is_empty() or source == target:
		return false
	if target != "tray" and (not state.weapons.has(target) or not Catalog.compatible(target, optic_id)):
		return false
	var displaced := "" if target == "tray" else str(state.weapons[target].optic)
	if source == "tray":
		state.loose_optics.erase(optic_id)
	else:
		state.weapons[source].optic = ""
	if target == "tray":
		state.loose_optics.append(optic_id)
	else:
		state.weapons[target].optic = optic_id
	if not displaced.is_empty():
		if source != "tray" and Catalog.compatible(source, displaced):
			state.weapons[source].optic = displaced
		else:
			state.loose_optics.append(displaced)
	state.revision += 1
	return true

static func equip(state: Dictionary, weapon_id: String, revision: int, model_ready: bool) -> bool:
	if int(state.revision) != revision or not state.weapons.has(weapon_id) or not model_ready or state.equipped == weapon_id:
		return false
	state.equipped = weapon_id
	state.revision += 1
	return true

static func set_ammunition(state: Dictionary, weapon_id: String, ammo: int, reserve: int, chambered: bool = true, magazine_inserted: bool = true, bolt_locked: bool = false, inserted_magazine: Variant = null) -> void:
	if state.weapons.has(weapon_id):
		var in_chamber := chambered and bool(Catalog.weapon(weapon_id).closed_bolt) and ammo > 0
		var maximum: int = int(Catalog.WEAPONS[weapon_id].magazine)+int(in_chamber) if magazine_inserted else int(in_chamber)
		state.weapons[weapon_id].ammo = clampi(ammo, 0, maximum)
		state.weapons[weapon_id].reserve = clampi(reserve, 0, 999)
		state.weapons[weapon_id].chambered = in_chamber
		state.weapons[weapon_id].magazine_inserted = magazine_inserted
		if magazine_inserted and bool(state.weapons[weapon_id].get("physical_magazines", false)):
			var record: Variant = state.weapons[weapon_id].get("inserted_magazine") if inserted_magazine == null else inserted_magazine
			state.weapons[weapon_id].inserted_magazine = MagazineRecord.normalize(weapon_id, record, int(state.weapons[weapon_id].ammo) - int(in_chamber))
		else:
			state.weapons[weapon_id].inserted_magazine = {}
		state.weapons[weapon_id].bolt_locked = bool(Catalog.weapon(weapon_id).closed_bolt) and not in_chamber and bolt_locked
