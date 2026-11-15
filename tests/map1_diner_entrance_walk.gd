extends "res://tests/probe_map1_world.gd"

func _run() -> void:
	map = Blockout.new()
	map.with_player = false
	root.add_child(map)
	world = map.world
	player = RealPlayer.new()
	map.add_child(player)
	camera = player.camera
	world.set_viewer(camera,player)
	var facade: Node3D = map.get_node_or_null("TallShopfronts/Tenant_1728")
	_check(facade != null,"Asahi Shokudo frontage is installed")
	if facade == null:
		quit(1)
		return
	var window: Vector3 = facade.to_global(Vector3(0.155*facade.frontage,0,1.15))
	var entrance: Vector3 = facade.to_global(Vector3(-0.31*facade.frontage,0,1.15))
	for direction: float in [-1.0,1.0]:
		var start: Vector3 = facade.to_global(Vector3(direction*(facade.frontage*0.5+1.0),0,1.8))
		await _put(map.on_ground(start.x,start.z,0.25))
		_check(await _drive([window,entrance,start],false,8),"walked from side %.0f to the diner window, entrance and back"%direction)
	var tram_diner := map.get_node_or_null("TallShopfronts/Tenant_1656") as Node3D
	_check(tram_diner!=null,"Tram Street diner has its storefront")
	if tram_diner!=null:
		var pavement := tram_diner.to_global(Vector3(0,0,2.0))
		await _put(map.on_ground(pavement.x,pavement.z,0.25),tram_diner.global_position-pavement)
		_check(not world.candidates.has(1656) and not world.houses.has(1656) and not world.looks.has(1656),
			"Tram Street diner has one storefront when approached, with no overlapping house")
	print("DINER_DONE passed=",passed," failed=",failed)
	quit(1 if failed else 0)
