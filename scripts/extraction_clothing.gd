extends RefCounted
## Local gameplay tiers and pockets. Jewellery and armour do not create storage.
const ITEMS := [
	{"id":"basic_shirt","title":"Basic shirt","slot":"top","pockets":2,"mass_kg":0.25,"value":1,"description":"Basic starting shirt. Two pocket slots."},
	{"id":"basic_trousers","title":"Basic trousers","slot":"legs","pockets":4,"mass_kg":0.5,"value":2,"description":"Basic starting trousers. Four pocket slots."},
	{"id":"work_jacket","title":"Work jacket","slot":"top","pockets":4,"mass_kg":0.8,"value":12,"description":"Work jacket with four pocket slots. Replaces the shirt's storage."},
	{"id":"cargo_trousers","title":"Cargo trousers","slot":"legs","pockets":6,"mass_kg":0.8,"value":14,"description":"Cargo trousers with six pocket slots."},
	{"id":"utility_pouch","title":"Utility pouch","slot":"pouch","pockets":3,"mass_kg":0.25,"value":10,"description":"Three extra storage slots. Pouches and bags provide accessory storage."},
	{"id":"security_armour_t2","title":"Security vest · tier 2","slot":"armour","tier":2,"pockets":0,"mass_kg":3.0,"value":60,"protection":0.15,"description":"Tier 2 game armour: reduces thorax and stomach damage by 15%. No storage. These are fictional gameplay tiers."},
	{"id":"patrol_armour_t3","title":"Patrol vest · tier 3","slot":"armour","tier":3,"pockets":0,"mass_kg":5.0,"value":100,"protection":0.25,"description":"Tier 3 game armour: reduces thorax and stomach damage by 25%. No storage. These are fictional gameplay tiers."}
]
static func defaults() -> Dictionary:
	return {"top":"basic_shirt","legs":"basic_trousers","pouch":"","armour":""}
static func spec(id: String) -> Dictionary:
	for item: Dictionary in ITEMS:
		if item.id==id:return item.duplicate(true)
	return {}
static func normalize(raw: Variant) -> Dictionary:
	var result := defaults()
	if not raw is Dictionary:return result
	for slot: String in result:
		var item := spec(str(raw.get(slot,result[slot])))
		if item.get("slot","")==slot:result[slot]=item.id
	return result
static func pocket_slots(outfit: Dictionary) -> int:
	var total := 0
	for slot: String in ["top","legs","pouch"]:
		total+=int(spec(str(normalize(outfit)[slot])).get("pockets",0))
	return total
static func protected_damage(outfit: Dictionary, part: String, amount: float) -> float:
	if part not in ["thorax","stomach"]:return amount
	return amount*(1.0-float(spec(str(normalize(outfit).armour)).get("protection",0.0)))
