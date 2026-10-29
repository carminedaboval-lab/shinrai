extends RefCounted
## Original procedural shop construction, 2026-10-23. No external assets/jobs.
## Call AFTER Details.build and BEFORE layer assignment/street batching.
## Existing products, chairs and artisan models remain owned by Details.
const Details = preload("res://scripts/midori_south_street_details.gd")
static var _removed: Array[Dictionary] = []

static func build(street: Node3D) -> Dictionary:
	_removed = []
	var report: Array[Dictionary] = []
	for spec: Dictionary in [{"id":"UedaBooks","w":11.0,"shelf":9.3,"kind":"books"},{"id":"MoriCoffee","w":10.0,"shelf":3.4,"kind":"coffee"},{"id":"HinataDaily","w":10.0,"shelf":8.4,"kind":"food"},{"id":"YakitoriShop","w":5.2,"shelf":3.65,"kind":"bar"}]:
		var shop := street.find_child(String(spec.id),true,false) as Node3D
		if shop == null: return {"ok":false,"missing_shop":spec.id}
		if shop.has_meta("constructed_interior_report"):
			report.append(shop.get_meta("constructed_interior_report"))
			continue
		var counter := shop.find_child("C_CounterContents",true,false) as Node3D
		var rear := shop.find_child("C_RearDisplay",true,false) as Node3D
		if counter == null or rear == null: return {"ok":false,"missing_contents":spec.id}
		var root := Node3D.new()
		root.name = "InteriorConstructedShop"
		root.set_meta("original_geometry",true)
		shop.add_child(root)
		# Rebuild carcasses only. Retain original counter tops, all working objects,
		# imported espresso/pastries, eight chairs and existing shelf boards.
		var counter_bodies: Array[MeshInstance3D] = []
		for child: Node in counter.get_children():
			if child is MeshInstance3D and _legacy_match(child as MeshInstance3D,"CounterBody"): counter_bodies.append(child as MeshInstance3D)
		for body: MeshInstance3D in counter_bodies:
			var size := (body.mesh.get_aabb()).size
			var p: Vector3 = body.position+counter.position+counter.get_parent().position
			_cabinet(street,root,p,size,false)
		_remove_named(counter,["CounterBody","CounterFrontInset","CounterTimberJoint"],String(spec.id))
		if spec.kind == "coffee":
			_remove_named(rear,["CoffeeRearCabinet"],String(spec.id))
			_cabinet(street,root,Vector3(-2.65,.59375,2.45),Vector3(3.4,.9675,.32),true)
			_coffee(street,root)
		else:
			_remove_named(rear,["ShelfLowBacking"],String(spec.id))
			_shelf_construction(street,root,float(spec.shelf),String(spec.kind))
			if spec.kind == "books": _books(street,root)
			elif spec.kind == "food": _food(street,root)
			else: _bar(street,root)
		# Replace the old plain light boxes at EXACT display-light coordinates.
		if spec.kind != "bar":
			_remove_named(shop,["InteriorDisplayLightHousing","InteriorDisplayLightDiffuser"],String(spec.id))
			for x: float in [-2.6,2.6]: _pendant(street,root,Vector3(x,2.35,.50),.22)
		_pendant(street,root,Vector3(0,2.65,1.10),.15)
		var stats := _statistics(root)
		stats["name"] = spec.id
		stats["entry_clear_width_m"] = 1.6
		stats["lights_created"] = 0
		stats["within_material_budget"] = int(stats["material_batches"]) <= 8
		stats["reuses_products_and_hero_assets"] = true
		root.set_meta("interior_material_batches_before_street_merge",stats["material_batches"])
		root.set_meta("interior_construction_members",stats["mesh_members"])
		root.set_meta("interior_required_batch_limit",8)
		shop.set_meta("constructed_interior_report",stats)
		report.append(stats)
	return {"ok":true,"shops":report,"suppressed":_removed,"lights_created":0,"chairs_added":0,"artisan_models_added":0,"original_assets_modified":false,"collision_created":false,"batch_report_stage":"predicted_from_shared_material_identity_before_existing_street_batching"}

static func _box(street: Node3D, parent: Node3D, label: String, pos: Vector3, size: Vector3, key: String) -> MeshInstance3D:
	return street.call("_box",parent,label,pos,size,key,false) as MeshInstance3D

static func _remove_named(parent: Node, prefixes: Array[String], shop: String) -> void:
	for child: Node in parent.get_children():
		var remove := false
		for prefix: String in prefixes:
			if child is MeshInstance3D and _legacy_match(child as MeshInstance3D,prefix): remove = true
		if remove and child is MeshInstance3D:
			_removed.append({"shop":shop,"node":str(child.name),"scope":"primitive_replaced_by_constructed_assembly"})
			parent.remove_child(child)
			child.free()
		elif not child.has_meta("artisan_asset") and not str(child.name).contains("BentwoodChair"):
			_remove_named(child,prefixes,shop)

static func _legacy_match(node: MeshInstance3D, kind: String) -> bool:
	if str(node.name).begins_with(kind): return true
	# Godot may replace repeated sibling names with @MeshInstance3D@ identifiers.
	# Match these precise legacy dimensions/positions within the owned socket,
	# never a broad timber-material test and never traverse imported hero roots.
	var size := node.mesh.get_aabb().size
	var p := node.position
	match kind:
		"CounterBody": return absf(size.z-.63)<.0001 and size.x>1.10 and absf(p.z)<.0001 and absf(p.y-size.y*.5-.11)<.0001
		"CounterFrontInset": return absf(size.z-.025)<.0001 and size.x>1.0 and absf(p.z+.325)<.0001
		"CounterTimberJoint": return absf(size.x-.012)<.0001 and absf(size.z-.012)<.0001 and absf(p.z+.343)<.0001
		"CoffeeRearCabinet": return p.distance_to(Vector3(-2.65,.60,0))<.0001 and size.distance_to(Vector3(3.4,.98,.32))<.0001
		"ShelfLowBacking": return absf(p.y-.30)<.0001 and absf(p.z-.145)<.0001 and absf(size.y-.31)<.0001 and absf(size.z-.035)<.0001
		"InteriorDisplayLightHousing": return absf(absf(p.x)-2.6)<.0001 and absf(p.y-2.43)<.0001 and absf(p.z-.50)<.0001 and size.distance_to(Vector3(.40,.07,.25))<.0001
		"InteriorDisplayLightDiffuser": return absf(absf(p.x)-2.6)<.0001 and absf(p.y-2.387)<.0001 and absf(p.z-.50)<.0001 and size.distance_to(Vector3(.35,.015,.20))<.0001
	return false

static func _cabinet(street: Node3D, root: Node3D, p: Vector3, size: Vector3, drawers: bool) -> void:
	# 18mm box carcass with open internal void; inset70mm toe-space and clear
	# 3mm door joints. Front/back depths match old bodies, no surface stacking.
	var low := p.y-size.y*.5
	var high := p.y+size.y*.5
	var front := p.z-size.z*.5
	_box(street,root,"InteriorCabinetRecessedToeKick",Vector3(p.x,low+.035,p.z+.035),Vector3(size.x-.10,.070,size.z-.070),"detail_darkwood")
	for side: float in [-1.0,1.0]:
		_box(street,root,"InteriorCabinet18mmEnd",Vector3(p.x+side*(size.x*.5-.009),(low+.07+high)*.5,p.z),Vector3(.018,size.y-.070,size.z),"detail_darkwood")
	_box(street,root,"InteriorCabinet18mmFloor",Vector3(p.x,low+.079,p.z),Vector3(size.x-.036,.018,size.z-.018),"detail_darkwood")
	_box(street,root,"InteriorCabinetThinRearPanel",Vector3(p.x,(low+.07+high)*.5,p.z+size.z*.5-.006),Vector3(size.x-.036,size.y-.070,.012),"detail_darkwood")
	_box(street,root,"InteriorCabinetUnderTopBearer",Vector3(p.x,high-.022,p.z),Vector3(size.x-.036,.044,size.z-.036),"detail_darkwood")
	var bays := maxi(2,int(ceil(size.x/.62)))
	var bay_width := (size.x-.04)/float(bays)
	for i: int in range(bays):
		var cx := p.x-size.x*.5+.02+(float(i)+.5)*bay_width
		var door_height := size.y-.105
		var cy := low+.070+door_height*.5
		if drawers and i == bays-1:
			for row: int in range(3):
				var yy := low+.075+(float(row)+.5)*door_height/3.0
				_box(street,root,"InteriorThreeDrawerFront",Vector3(cx,yy,front+.010),Vector3(bay_width-.003,door_height/3.0-.003,.020),"detail_wood")
				_box(street,root,"InteriorDrawerPull",Vector3(cx,yy,front-.010),Vector3(.12,.012,.020),"detail_metal")
		else:
			# Framed18mm door,60mm stiles/rails and8mm recessed floating panel.
			for side: float in [-1.0,1.0]:
				_box(street,root,"InteriorCabinetDoorStile",Vector3(cx+side*(bay_width*.5-.0315),cy,front+.009),Vector3(.060,door_height,.018),"detail_wood")
			for side: float in [-1.0,1.0]:
				_box(street,root,"InteriorCabinetDoorRail",Vector3(cx,cy+side*(door_height*.5-.030),front+.009),Vector3(bay_width-.123,.060,.018),"detail_wood")
			_box(street,root,"InteriorCabinetFloatingPanel",Vector3(cx,cy,front+.019),Vector3(bay_width-.123,door_height-.120,.008),"detail_cream")
			_box(street,root,"InteriorCabinetPullMount",Vector3(cx+bay_width*.28,cy+.06,front-.004),Vector3(.012,.10,.020),"detail_metal")

static func _shelf_construction(street: Node3D, root: Node3D, width: float, kind: String) -> void:
	# Original shelves at z2.45 and heights .22/.77/1.32/1.87/2.37 retained.
	# Backing lies behind product rear faces and within rear-wall plane z2.82.
	var divisions := 5 if kind == "books" else (4 if kind == "food" else 3)
	var bay := width/float(divisions)
	for i: int in range(divisions):
		var cx := -width*.5+(float(i)+.5)*bay
		_box(street,root,"InteriorShelfPaintedBackPanel",Vector3(cx,1.37,2.635),Vector3(bay-.025,2.43,.018),"detail_cream")
		for yy: float in [.555,1.105,1.655,2.205]:
			_box(street,root,"InteriorShelfBackPanelCrossRail",Vector3(cx,yy,2.616),Vector3(bay-.025,.025,.020),"detail_darkwood")
		if i < divisions-1:
			_box(street,root,"InteriorShelfBayDivider",Vector3(_divider_x(kind,width,bay,i),1.34,2.48),Vector3(.025,2.45,.27),"detail_darkwood")
	for x: float in [-width*.5+.12,0,width*.5-.12]:
		for yy: float in [.77,1.32,1.87,2.37]:
			_box(street,root,"InteriorShelfWallFixingPlate",Vector3(x,yy-.075,2.652),Vector3(.035,.16,.012),"detail_metal")
			_box(street,root,"InteriorShelfUnderBracket",Vector3(x,yy-.035,2.515),Vector3(.024,.025,.26),"detail_metal")
	_box(street,root,"InteriorShelfTopCornice",Vector3(0,2.61,2.53),Vector3(width+.06,.065,.35),"detail_wood")
	_box(street,root,"InteriorShelfCorniceShadowStep",Vector3(0,2.565,2.55),Vector3(width+.025,.025,.29),"detail_darkwood")

static func _divider_x(kind: String, width: float, bay: float, index: int) -> float:
	# Fall in existing product gaps, never through retained cartons or bottles.
	if kind == "food": return [-2.25,.23,2.09][index]
	if kind == "bar": return [-.455,.405][index]
	return -width*.5+float(index+1)*bay

static func _coffee(street: Node3D, root: Node3D) -> void:
	# Retained machine/grinder worktop y1.105 at rear socket2.45.
	_box(street,root,"InteriorCoffeeBackbarSplash",Vector3(-2.65,1.48,2.66),Vector3(3.42,.68,.018),"detail_cream")
	for x: float in [-4.33,-.97]:
		_box(street,root,"InteriorCoffeeBackbarEndTrim",Vector3(x,1.98,2.64),Vector3(.045,1.73,.06),"detail_darkwood")
	_box(street,root,"InteriorCoffeeUpperPaintedPanel",Vector3(-2.65,2.23,2.66),Vector3(3.40,.78,.018),"detail_cream")
	for x: float in [-4.14,-2.65,-1.16]:
		for yy: float in [1.87,2.37]:
			_box(street,root,"InteriorCoffeeShelfBracketPlate",Vector3(x,yy-.08,2.642),Vector3(.040,.18,.018),"detail_metal")
			_box(street,root,"InteriorCoffeeShelfSupportArm",Vector3(x,yy-.037,2.51),Vector3(.030,.028,.265),"detail_metal")
	_box(street,root,"InteriorCoffeeBackbarCrown",Vector3(-2.65,2.65,2.55),Vector3(3.52,.060,.35),"detail_wood")
	for i: int in range(5): Details._cup(street,root,Vector3(-3.84+float(i)*.29,2.394,2.45))
	# A framed menu stays at its original plane; no opaque overlay over text.
	for x: float in [.47,2.73]:
		_box(street,root,"InteriorCoffeeMenuFrameStile",Vector3(x,1.66,2.385),Vector3(.045,1.27,.055),"detail_wood")
	for yy: float in [1.025,2.295]:
		_box(street,root,"InteriorCoffeeMenuFrameRail",Vector3(1.60,yy,2.385),Vector3(2.305,.045,.055),"detail_wood")
	# Right side: compact porcelain handwash bowl atop a real wall-hung cupboard.
	_cabinet(street,root,Vector3(4.35,.59,2.39),Vector3(.72,.92,.43),true)
	_box(street,root,"InteriorCoffeeSideWorktop",Vector3(4.35,1.075,2.39),Vector3(.76,.050,.47),"detail_wood")
	_bowl(street,root,Vector3(4.35,1.102,2.39))
	Details._rod(street,root,"InteriorWashTapUpright",Vector3(4.35,1.10,2.58),Vector3(4.35,1.32,2.58),.010,"detail_metal")
	Details._rod(street,root,"InteriorWashTapSpout",Vector3(4.35,1.32,2.58),Vector3(4.35,1.32,2.43),.010,"detail_metal")

static func _books(street: Node3D, root: Node3D) -> void:
	# Small librarian's wall catalogue, not another arbitrary product pile.
	_box(street,root,"InteriorBooksellerCatalogueBack",Vector3(-5.185,1.45,1.56),Vector3(.025,1.05,.72),"detail_cream")
	for i: int in range(3):
		for j: int in range(4):
			_box(street,root,"InteriorCatalogueDrawer",Vector3(-5.161,1.06+float(j)*.245,1.31+float(i)*.25),Vector3(.030,.22,.23),"detail_wood")
			_box(street,root,"InteriorCataloguePull",Vector3(-5.140,1.06+float(j)*.245,1.31+float(i)*.25),Vector3(.018,.025,.075),"detail_metal")
	# Two quiet closed clothbound volumes sit on the empty top shelf. Shared
	# existing rounded book block avoids text-label draws or invented dense noise.
	for x: float in [-3.35,3.35]:
		Details._soft_block(street,root,"InteriorFeaturedVolumePages",Vector3(x,2.422,2.43),Vector3(.31,.042,.22),"detail_paper")
		for yy: float in [2.397,2.447]:
			Details._soft_block(street,root,"InteriorFeaturedVolumeClothCover",Vector3(x,yy,2.43),Vector3(.33,.008,.235),"detail_cream")

static func _food(street: Node3D, root: Node3D) -> void:
	# Reusable paper wrapping dispenser, housed on side wall beyond counter end.
	_box(street,root,"InteriorGrocerWrappingWallPlate",Vector3(4.685,1.54,1.54),Vector3(.025,.62,.62),"detail_cream")
	for z: float in [1.28,1.80]:
		_box(street,root,"InteriorGrocerPaperRollBracket",Vector3(4.615,1.54,z),Vector3(.14,.18,.035),"detail_metal")
	var roll := Details._cylinder(street,root,"InteriorGrocerWrappingPaperRoll",Vector3(4.560,1.57,1.54),.12,.48,"detail_paper")
	roll.rotation.x = PI*.5
	_box(street,root,"InteriorGrocerHangingPaper",Vector3(4.430,1.36,1.54),Vector3(.004,.36,.45),"detail_paper")
	_box(street,root,"InteriorGrocerTearBar",Vector3(4.420,1.16,1.54),Vector3(.020,.020,.50),"detail_metal")

static func _bar(street: Node3D, root: Node3D) -> void:
	# Restrained wash/prep tray on the rear shelf's empty top level; no grill smoke
	# appliance is invented in the impossible .35m deep product shelving.
	_box(street,root,"InteriorYakitoriTrayBottom",Vector3(.90,2.405,2.45),Vector3(.56,.018,.25),"detail_metal")
	for x: float in [.62,1.18]:
		_box(street,root,"InteriorYakitoriTrayEnd",Vector3(x,2.44,2.45),Vector3(.018,.07,.25),"detail_metal")
	for z: float in [2.325,2.575]:
		_box(street,root,"InteriorYakitoriTrayRim",Vector3(.90,2.44,z),Vector3(.56,.07,.018),"detail_metal")
	for x: float in [-.98,-.64,-.30]: Details._cup(street,root,Vector3(x,2.394,2.45))

static func _bowl(street: Node3D, root: Node3D, p: Vector3) -> void:
	var profile: Array[Vector2] = [Vector2(0,0),Vector2(.12,0),Vector2(.17,.025),Vector2(.205,.105),Vector2(.198,.115),Vector2(.185,.108),Vector2(.15,.036),Vector2(0,.022)]
	Details._lathe(street,root,"InteriorHollowPorcelainWashBowl",profile,p,1.0,"detail_ceramic")

static func _pendant(street: Node3D, root: Node3D, p: Vector3, radius: float) -> void:
	# Existing light is below the open shade, not buried in a solid cube.
	var rise := .14 if radius < .20 else .20
	var mount_y := 2.821 if radius < .20 else 2.995
	Details._cylinder(street,root,"InteriorPendantCeilingRose",Vector3(p.x,mount_y,p.z),.045,.018,"detail_metal")
	Details._rod(street,root,"InteriorPendantClothCord",Vector3(p.x,p.y+rise+.005,p.z),Vector3(p.x,mount_y-.009,p.z),.0035,"detail_metal")
	var profile: Array[Vector2] = [Vector2(radius,0),Vector2(radius*.32,rise),Vector2(radius*.29,rise),Vector2(radius-.008,.004),Vector2(radius,0)]
	Details._lathe(street,root,"InteriorOpenSpunPendantShade",profile,p,1.0,"detail_metal")
	Details._cylinder(street,root,"InteriorPendantPorcelainSocket",p+Vector3(0,rise-.05,0),.025,.055,"detail_ceramic")

static func _statistics(root: Node3D) -> Dictionary:
	var materials: Dictionary = {}
	var meshes := 0
	var triangles := 0
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			var visual := child as MeshInstance3D
			meshes += 1
			materials[visual.material_override.get_instance_id()] = visual.material_override.resource_name
			triangles += int(visual.mesh.get_faces().size()/3)
	return {"mesh_members":meshes,"triangles":triangles,"material_batches":materials.size(),"material_identity_keys":materials.keys()}


static func audit_after_batching(street: Node3D) -> Dictionary:
	# Root calls once AFTER its _batch_tree pass; this reports surviving meshes,
	# actual surfaces/material identities rather than claiming pre-build estimates.
	var rows: Array[Dictionary] = []
	for id: String in ["UedaBooks","MoriCoffee","HinataDaily","YakitoriShop"]:
		var shop := street.find_child(id,true,false) as Node3D
		if shop == null: continue
		var root := shop.find_child("InteriorConstructedShop",true,false) as Node3D
		if root == null: continue
		var materials: Dictionary = {}
		var mesh_count := 0
		var surfaces := 0
		for child: Node in root.get_children():
			if not child is MeshInstance3D: continue
			var visual := child as MeshInstance3D
			mesh_count += 1
			for index: int in range(visual.mesh.get_surface_count()):
				var mat := visual.get_active_material(index)
				if mat != null: materials[mat.get_instance_id()] = true
				surfaces += 1
		var row := {"name":id,"surviving_meshes":mesh_count,"surviving_surfaces":surfaces,"material_batches":materials.size(),"within_material_budget":materials.size()<=8}
		root.set_meta("interior_surviving_batch_report",row)
		rows.append(row)
	return {"shops":rows,"stage":"after_existing_street_batching","lights_created":0}
