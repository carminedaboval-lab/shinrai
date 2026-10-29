extends RefCounted
## Fictional loot tiers, not real-world armour or firearm classifications.
const Supply=preload("./extraction_weapon_supplies.gd")
const TIERS=Supply.TIERS
const Context=preload("./extraction_context_loot.gd")
const Containers=preload("./extraction_loot_containers.gd")
static func install(raid: Node) -> int:
	var relays: Array = raid.sites.filter(func(site: Dictionary)->bool:return site.get("kind","")=="relay")
	var ids: Array[String] = ["uzi","shigure","kite","raiden_r56","tobikage","hayate","yuzuru"]
	if relays.is_empty(): return 0
	var installed := 0
	for index: int in range(ids.size()):
		var id := ids[index]
		var site_id := "security_arms_"+id
		if raid.sites.any(func(site: Dictionary)->bool:return site.id==site_id):continue
		var origin: Vector3 = relays[index % relays.size()].position
		var location: Vector3 = raid.navigation.nearest(origin+Vector3(2.5+2.4*floori(float(index)/float(relays.size())),0,1.5))
		# A ray confirms terrain support before a case is installed.
		var query := PhysicsRayQueryParameters3D.create(location+Vector3(0,3,0),location-Vector3(0,4,0),1)
		var hit: Dictionary = raid.park.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():continue
		location = hit.position
		var anchor := Node3D.new()
		anchor.name = "SecuritySupplyAnchor_"+id
		raid.park.add_child(anchor)
		anchor.global_transform = Transform3D(Basis.IDENTITY,location)
		var case_spec := {"id":site_id,"at":Vector3.ZERO,"style":"tool","label":"SECURITY · TIER %d" % int(TIERS[id])}
		var model: Node3D = Context._case(anchor,case_spec)
		model.scale = Vector3(1.6,1,1)
		var context := "security_"+id
		# Guns and magazines are generated only by the residential spawner.
		raid.sites.append({"id":site_id,"title":"Search security supply case","container_title":str(case_spec.label),"empty_title":"Empty security supply case","kind":"cache","position":model.global_position+Vector3(0,.2,0),"container_type":Containers.CONTEXT_TYPE,"loot_context":context,"guaranteed":[Supply.ammunition_id(id)]+(["optic_scope_01"] if id in ["hayate","yuzuru"] else []),"prop_node":model,"approach":location+Vector3(0,0,-1.2),"spawn_chance":1.0,"ammo_bonus":0,"done":true,"spawned":false,"discovered":false,"contents":[],"loot":{}})
		installed += 1
	return installed
