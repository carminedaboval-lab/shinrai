extends RefCounted
const Catalog = preload("./extraction_weapon_catalog.gd")
const TIERS := {
  "akane": 2,
  "uzi": 2,
  "shigure": 2,
  "kite": 3,
  "raiden_r56": 3,
  "tobikage": 4,
  "hayate": 4,
  "yuzuru": 5
}
const MAGAZINES := {
  "akane_magazine": "akane",
  "uzi_magazine": "uzi",
  "shigure_magazine": "shigure",
  "kite_magazine": "kite",
  "raiden_r56_magazine": "raiden_r56",
  "tobikage_magazine": "tobikage",
  "hayate_magazine": "hayate",
  "yuzuru_magazine": "yuzuru"
}
const AMMUNITION := {
  "ammo_9x19": {
    "weapons": [
      "uzi",
      "shigure",
      "akane"
    ],
    "rounds": 15,
    "label": "9×19 mm"
  },
  "ammo_762x51": {
    "weapons": [
      "kite",
      "hayate",
      "yuzuru"
    ],
    "rounds": 10,
    "label": "7.62×51 mm"
  },
  "ammo_556x45": {
    "weapons": [
      "raiden_r56"
    ],
    "rounds": 20,
    "label": "5.56×45 mm"
  },
  "ammo_65x48": {
    "weapons": [
      "tobikage"
    ],
    "rounds": 10,
    "label": "6.5×48 mm"
  }
}
const ITEMS := [
  {
    "id": "weapon_akane",
    "weapon_id": "akane",
    "tier": 2,
    "title": "AKANE / A-9 · tier 2",
    "mass_kg": 0.79,
    "value": 90,
    "description": "Recovered AKANE service pistol. No magazine or ammunition included. Requires its A-9 magazine and 9×19 mm rounds. Extract to keep it.",
    "world_spawn": false
  },
  {
    "id": "akane_magazine",
    "title": "AKANE / A-9 magazine · empty",
    "mass_kg": 0.1,
    "value": 8,
    "description": "Empty A-9 magazine. Fits AKANE only. Pack loose 9×19 mm rounds into this magazine from inventory, then reload the pistol.",
    "world_spawn": false
  },
  {
    "id": "weapon_uzi",
    "weapon_id": "uzi",
    "tier": 2,
    "title": "UZI · tier 2",
    "mass_kg": 3.5,
    "value": 80,
    "description": "Recovered tier 2 UZI. No magazine or ammunition included. Find a compatible magazine and 9×19 mm rounds. Extract to keep it.",
    "world_spawn": false
  },
  {
    "id": "weapon_shigure",
    "weapon_id": "shigure",
    "tier": 2,
    "title": "Shigure S-9 · tier 2",
    "mass_kg": 2.7,
    "value": 100,
    "description": "Recovered tier 2 Shigure. No magazine or ammunition included. Requires its S-9 magazine and 9×19 mm rounds. Extract to keep it.",
    "world_spawn": false
  },
  {
    "id": "weapon_kite",
    "weapon_id": "kite",
    "tier": 3,
    "title": "Kite K-12 · tier 3",
    "mass_kg": 4.0,
    "value": 150,
    "description": "Recovered tier 3 Kite. No magazine or ammunition included. Requires its K-12 magazine and 7.62×51 mm rounds. Extract to keep it.",
    "world_spawn": false
  },
  {
    "id": "uzi_magazine",
    "title": "UZI magazine · empty",
    "mass_kg": 0.2,
    "value": 8,
    "description": "Empty UZI magazine. Select PACK MAGAZINE in inventory to add loose 9×19 mm rounds, then equip the UZI and press reload.",
    "world_spawn": false
  },
  {
    "id": "shigure_magazine",
    "title": "Shigure S-9 magazine · empty",
    "mass_kg": 0.2,
    "value": 8,
    "description": "Empty S-9 magazine. Fits Shigure only. Pack loose 9×19 mm rounds into this magazine from inventory, then reload the gun.",
    "world_spawn": false
  },
  {
    "id": "kite_magazine",
    "title": "Kite K-12 magazine · empty",
    "mass_kg": 0.25,
    "value": 10,
    "description": "Empty K-12 magazine. Fits Kite only. Pack loose 7.62×51 mm rounds into this magazine from inventory, then reload the gun.",
    "world_spawn": false
  },
  {
    "id": "ammo_9x19",
    "title": "9×19 mm · 15 rounds",
    "mass_kg": 0.18,
    "value": 6,
    "description": "Loose 9×19 mm rounds for UZI, Shigure or AKANE. Select a compatible magazine in inventory and choose PACK MAGAZINE. Reload to insert it into the gun.",
    "world_spawn": false
  },
  {
    "id": "ammo_762x51",
    "title": "7.62×51 mm · 10 rounds",
    "mass_kg": 0.25,
    "value": 8,
    "description": "Loose 7.62×51 mm rounds for Kite, Hayate or Yuzuru. Pack the matching weapon magazine in inventory, then reload.",
    "world_spawn": false
  },
  {
    "id": "weapon_raiden_r56",
    "weapon_id": "raiden_r56",
    "tier": 3,
    "title": "RAIDEN / R-56 · tier 3",
    "mass_kg": 3.6,
    "value": 180,
    "description": "Recovered RAIDEN / R-56. Find its own magazine and 5.56x45 mm rounds. No magazine or ammunition included. Extract to keep it.",
    "world_spawn": false
  },
  {
    "id": "raiden_r56_magazine",
    "title": "RAIDEN / R-56 magazine · empty",
    "mass_kg": 0.25,
    "value": 12,
    "description": "Fits RAIDEN / R-56 only. Pack 5.56x45 mm rounds from inventory, then reload the gun.",
    "world_spawn": false
  },
  {
    "id": "weapon_tobikage",
    "weapon_id": "tobikage",
    "tier": 4,
    "title": "TOBIKAGE / T-65 · tier 4",
    "mass_kg": 4.1,
    "value": 240,
    "description": "Recovered TOBIKAGE / T-65. Find its own magazine and 6.5×48 mm fictional rounds. No magazine or ammunition included. Extract to keep it.",
    "world_spawn": false
  },
  {
    "id": "tobikage_magazine",
    "title": "TOBIKAGE / T-65 magazine · empty",
    "mass_kg": 0.25,
    "value": 12,
    "description": "Fits TOBIKAGE / T-65 only. Pack 6.5×48 mm fictional rounds from inventory, then reload the gun.",
    "world_spawn": false
  },
  {
    "id": "weapon_hayate",
    "weapon_id": "hayate",
    "tier": 4,
    "title": "HAYATE / H-7 · tier 4",
    "mass_kg": 4.3,
    "value": 280,
    "description": "Recovered HAYATE / H-7. Find its own magazine and 7.62×51 mm NATO rounds. No magazine or ammunition included. Extract to keep it.",
    "world_spawn": false
  },
  {
    "id": "hayate_magazine",
    "title": "HAYATE / H-7 magazine · empty",
    "mass_kg": 0.25,
    "value": 12,
    "description": "Fits HAYATE / H-7 only. Pack 7.62×51 mm NATO rounds from inventory, then reload the gun.",
    "world_spawn": false
  },
  {
    "id": "weapon_yuzuru",
    "weapon_id": "yuzuru",
    "tier": 5,
    "title": "YUZURU / YZ-10 · tier 5",
    "mass_kg": 5.6,
    "value": 360,
    "description": "Recovered YUZURU / YZ-10. Find its own magazine and 7.62×51 mm NATO rounds. No magazine or ammunition included. Extract to keep it.",
    "world_spawn": false
  },
  {
    "id": "yuzuru_magazine",
    "title": "YUZURU / YZ-10 magazine · empty",
    "mass_kg": 0.25,
    "value": 12,
    "description": "Fits YUZURU / YZ-10 only. Pack 7.62×51 mm NATO rounds from inventory, then reload the gun.",
    "world_spawn": false
  },
  {
    "id": "ammo_556x45",
    "title": "5.56×45 mm · 20 rounds",
    "mass_kg": 0.24,
    "value": 10,
    "description": "Loose rounds. Select a compatible magazine in inventory and choose PACK MAGAZINE. Reload to insert it.",
    "world_spawn": false
  },
  {
    "id": "ammo_65x48",
    "title": "6.5×48 mm · 10 rounds",
    "mass_kg": 0.23,
    "value": 12,
    "description": "Loose rounds. Select a compatible magazine in inventory and choose PACK MAGAZINE. Reload to insert it.",
    "world_spawn": false
  },
  {
    "id": "optic_scope_01",
    "optic_id": "scope_01",
    "title": "KASUMI / 6× SCOPE",
    "mass_kg": 0.55,
    "value": 110,
    "description": "Six-power scope for Hayate and Yuzuru. Recover into the optic tray, then fit it at the weapon bench. Extract to keep it.",
    "world_spawn": false
  }
]

static func spec(id: String) -> Dictionary:
	for item: Dictionary in ITEMS:
		if item.id==id:return item.duplicate(true)
	return {}

static func supply_action(id: String) -> String:
	return "PACK MAGAZINE WITH LOOSE ROUNDS" if MAGAZINES.has(id) else ""


static func magazine_id(weapon: String) -> String:
	for id: String in MAGAZINES:
		if MAGAZINES[id]==weapon:return id
	return ""

static func is_supply(id: String) -> bool:
	return MAGAZINES.has(id) or AMMUNITION.has(id)

static func rounds(item: Dictionary) -> int:
	var id := str(item.get("id",""))
	var maximum := int(Catalog.WEAPONS[MAGAZINES[id]].magazine) if MAGAZINES.has(id) else int(AMMUNITION[id].rounds) if AMMUNITION.has(id) else 0
	var raw: Variant = item.get("rounds",0 if MAGAZINES.has(id) else maximum)
	return clampi(int(raw),0,maximum) if (raw is int or raw is float) and is_finite(float(raw)) else 0

static func pack(magazine: Dictionary, bag: Array) -> int:
	var id := str(magazine.get("id",""))
	if not MAGAZINES.has(id):return 0
	var weapon := str(MAGAZINES[id])
	var held := rounds(magazine)
	var needed := int(Catalog.WEAPONS[weapon].magazine)-held
	var moved := 0
	for index: int in range(bag.size()-1,-1,-1):
		var packet: Dictionary = bag[index]
		var ammo_id := str(packet.get("id",""))
		if not AMMUNITION.has(ammo_id) or weapon not in AMMUNITION[ammo_id].weapons:continue
		var available := rounds(packet)
		var take := mini(needed-moved,available)
		packet.rounds = available-take
		packet.title = str(AMMUNITION[ammo_id].label)+" · %d rounds" % int(packet.rounds)
		moved += take
		if packet.rounds==0:bag.remove_at(index)
		if moved==needed:break
	magazine.rounds = held+moved
	magazine.title = "%s · %d/%d" % [str(spec(id).title).trim_suffix(" · empty"),held+moved,int(Catalog.WEAPONS[weapon].magazine)]
	return moved

static func ammunition_id(weapon: String) -> String:
	for id: String in AMMUNITION:
		if weapon in AMMUNITION[id].weapons: return id
	return ""
