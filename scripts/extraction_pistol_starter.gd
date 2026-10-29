extends RefCounted
## Pure factory and explicit in-memory handoff. No profile IO, auto-migration,
## active-run recovery or repeated ammunition grant occurs in this helper.
const VERSION := 1
const WEAPON_ID := "akane"
const MARKER := "pistol_starter_version"
const ARCHIVE := "pistol_starter_archive_v1"
const Catalog = preload("./extraction_weapon_catalog.gd")
const Supply = preload("./extraction_weapon_supplies.gd")
const WeaponState = preload("./extraction_weapon_state.gd")
const MagazineRecord = preload("./extraction_magazine_record.gd")

static func kit() -> Dictionary:
	if not Catalog.WEAPONS.has(WEAPON_ID) or not Catalog.available(WEAPON_ID):return {}
	var spec: Dictionary = Catalog.weapon(WEAPON_ID)
	if str(spec.get("category","")) != "pistol" or not bool(spec.get("closed_bolt",false)):return {}
	var capacity: int = int(spec.get("magazine",0))
	var magazine_id: String = Supply.magazine_id(WEAPON_ID)
	var ammunition_id: String = Supply.ammunition_id(WEAPON_ID)
	if capacity <= 0 or magazine_id.is_empty() or ammunition_id.is_empty():return {}
	if Supply.MAGAZINES.get(magazine_id,"") != WEAPON_ID or not Supply.AMMUNITION.has(ammunition_id):return {}
	if WEAPON_ID not in Supply.AMMUNITION[ammunition_id].weapons:return {}
	if Supply.spec(magazine_id).is_empty() or Supply.spec(ammunition_id).is_empty():return {}
	var record: Dictionary = WeaponState.recovered_weapon(WEAPON_ID)
	if record.is_empty():return {}
	var magazines: Array[Dictionary] = []
	var identities: Dictionary = {}
	for index: int in range(3):
		var magazine: Dictionary = MagazineRecord.normalize(WEAPON_ID,{},capacity)
		var uid: String = str(magazine.get("magazine_uid",""))
		if magazine.is_empty() or uid.is_empty() or identities.has(uid) or Supply.rounds(magazine) != capacity:return {}
		identities[uid] = true
		magazines.append(magazine)
	record.ammo = capacity + 1
	record.reserve = 0 # Runtime reserve is derived from the two physical bag magazines.
	record.optic = ""
	record.physical_magazines = true
	record.chambered = true
	record.magazine_inserted = true
	record.inserted_magazine = magazines[0]
	record.bolt_locked = false
	var loadout: Dictionary = WeaponState.defaults()
	loadout.equipped = WEAPON_ID
	loadout.weapons[WEAPON_ID] = record
	return {"loadout":loadout,"field_kit":[magazines[1],magazines[2]],"capacity":capacity,"ammunition_id":ammunition_id,"version":VERSION}

static func _copied(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value

static func apply_existing(data: Dictionary) -> bool:
	# The caller must read raw JSON, back it up, hold a global no-game guard,
	# and explicitly decide interrupted-run recovery before invoking this function.
	var marker: Variant = data.get(MARKER,0)
	if not (marker is int or marker is float) or not is_finite(float(marker)):return false
	if float(marker) != 0.0 or data.has(ARCHIVE) or bool(data.get("active_run",false)):return false
	var starter: Dictionary = kit()
	if starter.is_empty():return false
	var archive: Dictionary = {"loadout_present":data.has("loadout"),"field_kit_present":data.has("field_kit"),"loadout":_copied(data.get("loadout",WeaponState.defaults())),"field_kit":_copied(data.get("field_kit",[])),"previous_starter_version":marker}
	data[ARCHIVE] = archive
	data["loadout"] = starter.loadout
	data["field_kit"] = starter.field_kit
	data[MARKER] = VERSION
	return true
