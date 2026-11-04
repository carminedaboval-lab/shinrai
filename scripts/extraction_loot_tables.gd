extends RefCounted
## Local loot balance. Context selects eligible objects; inventory cannot reroll it.
const TOOLS := ["can_opener","pliers","scissors","utility_knife","hammer","screwdriver","wrench","bolt_cutters"]
const ITEMS := [
	{"id":"hammer","title":"Claw hammer","value":22,"mass_kg":0.65,"description":"Steel claw hammer with a worn grip. Recoverable maintenance tool; extract to bank or sell it.","world_spawn":false},
	{"id":"screwdriver","title":"Screwdriver","value":12,"mass_kg":0.16,"description":"Flat-head screwdriver. Recoverable workshop tool; extract to bank or sell it.","world_spawn":false},
	{"id":"wrench","title":"Adjustable wrench","value":24,"mass_kg":0.45,"description":"Adjustable steel wrench. Recoverable maintenance tool; extract to bank or sell it.","world_spawn":false},
	{"id":"bolt_cutters","title":"Bolt cutters","value":38,"mass_kg":1.40,"description":"Long-handled bolt cutters. Carry them to a chained park gate at night and hold interact to cut it open. Stays in your bag after use.","world_spawn":false}
]
const POOLS := {
	# Security supplies retain ammunition/optics/clothing; no generated guns or magazines outside homes.
	"security_raiden_r56":{"count":Vector2i(3,4),"weights":{"ammo_556x45": 8}},
	"security_tobikage":{"count":Vector2i(3,4),"weights":{"ammo_65x48": 8}},
	"security_hayate":{"count":Vector2i(3,4),"weights":{"ammo_762x51": 8, "optic_scope_01": 2}},
	"security_yuzuru":{"count":Vector2i(3,4),"weights":{"ammo_762x51": 8, "optic_scope_01": 2}},
	"security_uzi":{"count":Vector2i(3,4),"weights":{"ammo_9x19":8,"security_armour_t2":2,"utility_pouch":3}},
	"security_shigure":{"count":Vector2i(3,4),"weights":{"ammo_9x19":8,"security_armour_t2":2,"work_jacket":3}},
	"security_kite":{"count":Vector2i(3,4),"weights":{"ammo_762x51":8,"patrol_armour_t3":2,"cargo_trousers":3}},
	"maintenance":{"count":Vector2i(2,3),"weights":{"pliers":6,"utility_knife":3,"hammer":6,"screwdriver":8,"wrench":7,"bolt_cutters":5}},
	"workshop":{"count":Vector2i(2,3),"weights":{"scissors":8,"utility_knife":8,"pliers":4,"screwdriver":3,"hammer":1,"bolt_cutters":3}},
	"pantry":{"count":Vector2i(2,3),"weights":{"can_opener":2,"canned_mackerel":6,"canned_peaches":6,"ration_bar":3,"bottled_water_closed":4,"scissors":1}},
	"medical":{"count":Vector2i(2,3),"weights":{"bandage":8,"tourniquet":3,"splint":3,"scissors":2}},
	"sports":{"count":Vector2i(1,3),"weights":{"sports_bottle_closed":8,"bottled_water_closed":5,"ration_bar":4,"bandage":2}}
}

static func allows(id: String, context: String) -> bool:
	return POOLS.has(context) and POOLS[context].weights.has(id)

static func roll(context: String, rng: RandomNumberGenerator, guaranteed: Array = []) -> Array[String]:
	var result: Array[String]=[]
	if not POOLS.has(context):return result
	var table: Dictionary=POOLS[context]
	var weights: Dictionary=table.weights.duplicate()
	for entry: Variant in guaranteed:
		var id:=str(entry)
		if weights.has(id) and not result.has(id):result.append(id);weights.erase(id)
	var count:=rng.randi_range(int(table.count.x),int(table.count.y))
	count=maxi(count,result.size())
	while result.size()<count and not weights.is_empty():
		var total:=0.0
		for weight: Variant in weights.values():total+=float(weight)
		var roll:=rng.randf()*total
		var selected:=str(weights.keys()[-1])
		for id: String in weights:
			roll-=float(weights[id])
			if roll<0.0:selected=id;break
		result.append(selected);weights.erase(selected)
	return result
