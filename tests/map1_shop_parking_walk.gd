extends "res://tests/probe_map1_world.gd"
## Traverse the shop-row parking entrance, pay machine and all four vacant bays.
func _run() -> void:
	map = Blockout.new()
	map.with_player = false
	root.add_child(map)
	world = map.world
	player = RealPlayer.new()
	map.add_child(player)
	camera = player.camera
	world.set_viewer(camera,player)
	var parking := map.get_node_or_null("ShopRowCoinParking") as Node3D
	_check(parking != null,"live map installed the four-bay lot east of the café")
	if parking == null:
		quit(1)
		return
	var body := parking.get_node("Fixtures") as StaticBody3D
	var machine := body.get_node("PayMachine") as CollisionShape3D
	var entry_x := parking.position.x
	await _put(map.on_ground(entry_x,-452.0,0.35),Vector3.FORWARD)
	var kerb: Vector3 = map.on_ground(entry_x,-455.08)
	var ramp_hit := ray(kerb+Vector3.UP*0.4,kerb-Vector3.UP*0.1)
	_check(not ramp_hit.is_empty() and ramp_hit.position.y-kerb.y > 0.015 and ramp_hit.position.y-kerb.y < 0.055,"entrance kerb is lowered at the approach from the road")
	var aisle: Vector3 = map.on_ground(entry_x,parking.position.z-2.0)
	var back: Vector3 = map.on_ground(entry_x,-470.5,1.20)
	var wall := ray(back + Vector3.BACK,back - Vector3.BACK)
	_check(not wall.is_empty() and wall.collider == map.get_node("CoinCarPark0/Upstand"),"rear boundary stops a ray at chest height behind the bays")
	_check(await _drive([aisle],false,10),"walked from the road over the apron into the lot")
	var pay_at := machine.global_position
	_check(await _drive([map.on_ground(pay_at.x,pay_at.z+0.85)],false,10),"walked up to the pay machine from the entrance")
	var hit := ray(pay_at+Vector3(0,0.3,0.86),pay_at+Vector3(0,0.3,0))
	_check(not hit.is_empty() and hit.collider == body,"pay machine stops the player at its panel")
	var post := body.get_node("TariffPost") as CollisionShape3D
	_check(post.global_position.z < parking.position.z-0.5 and pay_at.z < parking.position.z-2.0,"sign and machine stand inside the lot clear of the through pavement")
	await _drive([aisle],false,10)
	for number in range(1,5):
		var plate := body.get_node("Plate%d"%number) as CollisionShape3D
		var p := plate.global_position
		var mouth: Vector3 = map.on_ground(p.x,p.z+3.5)
		var across: Vector3 = map.on_ground(p.x,p.z-1.15)
		_check(await _drive([mouth,across],false,22),"walked over the folded lock in bay %d"%number)
		var lock_hit := ray(p+Vector3.UP*0.3,p-Vector3.UP*0.08)
		_check(not lock_hit.is_empty() and lock_hit.collider == body,"bay %d has its own low physical lock"%number)
		_check(await _drive([mouth],false,7),"walked out of bay %d"%number)
	_check(await _drive([aisle,map.on_ground(entry_x,-456.0),map.on_ground(-316,-456.0)],false,22),"returned to the café along the through pavement")
	print("PARKING_DONE passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)

func ray(a: Vector3, b: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(a,b,1,[player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(query)
