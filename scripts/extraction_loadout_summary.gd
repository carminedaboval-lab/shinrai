extends RefCounted

const WeaponState = preload("res://scripts/extraction_weapon_state.gd")
const Clothing=preload("./extraction_clothing.gd")

# HQ uses one saved loadout record; the live player may still show an old gun.
# Normalization returns a new record and never changes the player's saved kit.
static func describe(profile: Dictionary) -> String:
	var state := WeaponState.normalize(profile.get("loadout", {}))
	var id := str(state.equipped)
	if not state.weapons.has(id):
		return "LOADOUT  UNARMED\nOne fruit and one bandage for your first deployment. Find equipment and extract to keep it." if bool(profile.get("starter_pending",false)) else "LOADOUT  UNARMED\nFind equipment during the raid and extract to keep it."
	var spec := WeaponState.Catalog.weapon(id)
	var kit: Dictionary = state.weapons[id]
	var medkits := 1 if bool(profile.get("prepared_medkit", false)) else 0
	var slots := Clothing.pocket_slots(profile.get("clothing",Clothing.defaults()))
	return "LOADOUT  %s · %s\n%d loaded · %d spare rounds · %d medkit%s · %d pocket slots" % [
		str(spec.title), str(spec.ammo_type), int(kit.ammo), int(kit.reserve),
		medkits, "s" if medkits != 1 else "", slots]
