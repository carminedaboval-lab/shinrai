extends SceneTree
## Enumerate the full business plan against the live shells. Catches one-storey/two-storey
## plots that are too small or walled in and therefore remain grey at every distance.
const Map := preload("res://scripts/map1/map1_blockout.gd")
const Rules := preload("res://scripts/map1/map1_house_rules.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var map := Map.new()
	map.with_player=false
	root.add_child(map)
	var full := 0
	var signed := 0
	var exterior := 0
	var misses := 0
	for tenant: Dictionary in map.data.businesses:
		var idx := int(tenant.box)
		if Rules.floors_of(map.data.boxes[idx]) > 2:
			exterior+=1
			continue
		var site: Dictionary=map.world.site(idx)
		if site.ok:
			full+=1
			if not site.spec.get("signs",[]).is_empty() and str(site.get("business",{}).get("what","")) == str(tenant.what):
				signed+=1
			else:
				print("MISSING_KIT_SIGN ",idx," ",tenant.what)
		else:
			if map.get_node("TallShopfronts").has_node("Tenant_%d"%idx):
				exterior+=1
			else:
				misses+=1
				print("UNSERVED ",idx," ",tenant.what," ",site.reason)
	print("TENANT_SHELLS kit=",full," exterior=",exterior," signed_kit=",signed," missing=",misses)
	quit(1 if misses or signed!=full else 0)

