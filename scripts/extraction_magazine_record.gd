extends RefCounted

const Supply = preload("./extraction_weapon_supplies.gd")
const Catalog = preload("./extraction_weapon_catalog.gd")

## Return the same physical magazine with its authoritative remaining rounds.
## A legacy inserted magazine gets one new identity; later normalizations retain it.
## The caller decides whether an inserted magazine actually exists.
static func normalize(weapon_id: String, raw: Variant, remaining: int, create_missing: bool = true) -> Dictionary:
	if not Catalog.WEAPONS.has(weapon_id):
		return {}
	var id := Supply.magazine_id(weapon_id)
	if id.is_empty():
		return {}
	var valid := raw is Dictionary and str(raw.get("id", "")) == id
	if not valid and not create_missing:
		return {}
	var record: Dictionary = raw.duplicate(true) if valid else Supply.spec(id)
	if record.is_empty():
		return {}
	# pack_uid is exclusively the equipped-backpack identity, not a magazine id.
	record.erase("pack_uid")
	var uid: Variant = record.get("magazine_uid", "")
	if not uid is String or str(uid).strip_edges().is_empty():
		record.magazine_uid = "mag-" + Crypto.new().generate_random_bytes(16).hex_encode()
	var count := clampi(remaining, 0, int(Catalog.WEAPONS[weapon_id].magazine))
	record.rounds = count
	record.title = "%s · %d/%d" % [str(Supply.spec(id).title).trim_suffix(" · empty"), count, int(Catalog.WEAPONS[weapon_id].magazine)]
	return record
