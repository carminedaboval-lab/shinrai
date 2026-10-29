extends RefCounted
## Four visual shop plans in their existing shells. Collision ownership stays
## with the street generator; these visual sets do not enable indoor gameplay.
const Cafe = preload("res://scripts/midori_cafe_layout.gd")
const Retail = preload("res://scripts/midori_retail_layouts.gd")
const Yakitori = preload("res://scripts/midori_yakitori_layout.gd")
const Interiors = preload("res://scripts/midori_shop_interiors.gd")

static func practical_points(shop_name: String) -> Array[Vector3]:
	match shop_name:
		"MoriCoffee": return [Vector3(2.48,2.35,4.8),Vector3(-2.5,2.35,3.6)]
		"UedaBooks": return [Vector3(-2,2.35,3.8),Vector3(3.55,2.35,5.4)]
		"HinataDaily": return [Vector3(-2.5,2.35,2.0),Vector3(2.85,2.35,2.7)]
		_: return [Vector3(.4,2.35,2.5),Vector3(.4,2.35,5.5)]

static func build(street: Node3D) -> Dictionary:
	var reports: Array[Dictionary] = []
	var removed: Array[Dictionary] = []
	for shop_name: String in ["UedaBooks","MoriCoffee","HinataDaily","YakitoriShop"]:
		var shop := street.get_node_or_null(NodePath(shop_name)) as Node3D
		if shop == null: return {"ok":false,"missing_shop":shop_name}
		# Only the four interior sockets belong to this replacement. The outdoor
		# book/produce/menu displays, chairs and complete building remain intact.
		for socket_name: String in ["DetailCounter","DetailBackShelves","DetailWindowLeft","DetailWindowRight"]:
			var socket := shop.get_node(NodePath(socket_name))
			for child: Node in socket.get_children():
				removed.append({"shop":shop_name,"socket":socket_name,"group":str(child.name)})
				socket.remove_child(child)
				# Label3D creates font materials through deferred renderer updates.
				# Detach now, then retire the complete old group at the frame boundary.
				child.queue_free()
		Interiors._remove_named(shop,["InteriorDisplayLightHousing","InteriorDisplayLightDiffuser"],shop_name)
		var root := Node3D.new()
		root.name = "InteriorConstructedShop"
		root.set_meta("logical_shop_layout",true)
		shop.add_child(root)
		var plan: Dictionary
		if shop_name == "MoriCoffee": plan = Cafe.build(street,shop,root)
		elif shop_name == "YakitoriShop": plan = Yakitori.build(street,shop,root)
		else: plan = Retail.build(street,shop,root)
		Interiors._pendant(street,root,Vector3(0,2.65,3.9),.15)
		for point: Vector3 in practical_points(shop_name): Interiors._pendant(street,root,point,.22)
		plan["name"] = shop_name
		plan["usable_room"] = shop.get_meta("architecture_shop_interior")
		shop.set_meta("logical_shop_plan",plan)
		reports.append(plan)
	var artisan_count := 0
	for node: Node in street.find_children("*","Node3D",true,false):
		if node.has_meta("artisan_asset"): artisan_count += 1
	return {"ok":reports.size()==4,"shops":reports,"removed_legacy_groups":removed,"artisan_models_loaded":artisan_count,"lights_created":0,"collision_created":false,"original_assets_modified":false,"visual_layout_only":true}

static func audit_after_batching(street: Node3D) -> Dictionary:
	var shops: Array[Dictionary] = []
	for shop_name: String in ["UedaBooks","MoriCoffee","HinataDaily","YakitoriShop"]:
		var shop := street.get_node(NodePath(shop_name)) as Node3D
		var root := shop.get_node("InteriorConstructedShop") as Node3D
		var material_ids: Dictionary = {}
		var meshes := 0
		var surfaces := 0
		for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh == null: continue
			meshes += 1
			surfaces += mesh.mesh.get_surface_count()
			for index: int in range(mesh.mesh.get_surface_count()):
				var mat := mesh.get_active_material(index)
				if mat != null: material_ids[mat.get_instance_id()] = mat.resource_name
		var fixtures: Array[Dictionary] = []
		for node: Node3D in root.find_children("*","Node3D",true,false):
			if not node.has_meta("fixture_bounds"): continue
			var geometry := geometry_bounds(node,shop)
			fixtures.append({"name":str(node.name),"role":node.get_meta("fixture_role",""),"declared":node.get_meta("fixture_bounds"),"rendered":geometry,"rendered_footprint":Rect2(geometry.position.x,geometry.position.z,geometry.size.x,geometry.size.z)})
		shops.append({"name":shop_name,"surviving_meshes":meshes,"surviving_surfaces":surfaces,"material_count":material_ids.size(),"material_names":material_ids.values(),"within_material_budget":material_ids.size()<=24,"fixtures":fixtures})
	return {"shops":shops,"stage":"actual_recursive_surviving_mesh_geometry_after_street_batching"}

static func geometry_bounds(node: Node3D, coordinate_root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var inverse := coordinate_root.global_transform.affine_inverse()
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null: continue
		var local_box := inverse * mesh.global_transform * mesh.get_aabb()
		result = result.merge(local_box) if found else local_box
		found = true
	return result
