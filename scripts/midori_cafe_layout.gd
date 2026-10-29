extends RefCounted
## Mori cafe layout, metres in shop-local space. Integration owns shell/lights.
## Call after Details.build and clearing only its four interior socket contents.
const Details = preload("res://scripts/midori_south_street_details.gd")
const Interiors = preload("res://scripts/midori_shop_interiors.gd")
const FLOOR := .11
const WORKTOP := 1.01
const ESPRESSO_SOURCE_BOUNDS := AABB(Vector3(-.41,0,-.21),Vector3(.82,.48,.42))
const ESPRESSO_SHA256 := "CB8EFE0D92E0F11A982DF3F6EB9928352C4F269700566F82600FA87BA1910567"

static func build(street: Node3D, shop: Node3D, root: Node3D) -> Dictionary:
	var fixtures: Array[Dictionary] = []
	var service_bounds := Rect2(2.10,2.50,.75,3.90)
	_counter_run(street,root,"MoriServiceCounter",service_bounds,true)
	_fixture(fixtures,root,"MoriServiceCounter",service_bounds,"service_counter")
	var backbar_bounds := Rect2(4.15,3.95,.53,2.45)
	_counter_run(street,root,"MoriBackbar",backbar_bounds,false)
	_backbar(street,root.get_node("MoriBackbar") as Node3D)
	_fixture(fixtures,root,"MoriBackbar",Rect2(4.15,3.95,.544,2.45),"backbar")

	var machine_position := Vector3(2.50,WORKTOP,4.80)
	# Authored source front is -Z. R_y(-PI/2) * -Z = +X, into staff aisle.
	var machine := Details._artisan_prop(root,"artisan_espresso.glb","MoriSingleWorkingEspressoMachine",machine_position,1.0,-PI*.5)
	var machine_transform := Transform3D(Basis(Vector3.UP,-PI*.5),machine_position)
	var machine_bounds: AABB = machine_transform * ESPRESSO_SOURCE_BOUNDS
	var machine_footprint := Rect2(machine_bounds.position.x,machine_bounds.position.z,machine_bounds.size.x,machine_bounds.size.z)
	var machine_report := {
		"loaded":machine != null,"count":1 if machine != null else 0,
		"source":Details.ARTISAN_PATH+"artisan_espresso.glb","source_sha256":ESPRESSO_SHA256,
		"source_bounds":ESPRESSO_SOURCE_BOUNDS,"source_front":Vector3(0,0,-1),
		"position":machine_position,"yaw_radians":-PI*.5,"facing":Vector3.RIGHT,
		"scale":Vector3.ONE,"transformed_bounds":machine_bounds,
		"support_counter":"MoriServiceCounter","support_counter_bounds":service_bounds,
		"support_surface_y":WORKTOP,"bottom_y":machine_bounds.position.y,
		"orientation_evidence":"build_hero_props.py:2,108-119; artisan_espresso_audit.json; inspected original preview and GLB POSITION bounds"
	}
	if machine != null: machine.set_meta("working_espresso_station",machine_report)
	_fixture(fixtures,root,"MoriSingleWorkingEspressoMachine",machine_footprint,"countertop_equipment")
	_grinder(street,root)
	_fixture(fixtures,root,"MoriGrinder",Rect2(2.425,5.505,.375,.29),"countertop_equipment")
	_till(street,root)
	_fixture(fixtures,root,"MoriTill",Rect2(2.115,3.57,.585,.28),"countertop_equipment")
	var pastries := _pastry_case(street,root)
	_fixture(fixtures,root,"MoriCompactPastryCase",Rect2(2.18,2.50,.57,.90),"countertop_display")

	# Two staggered settings leave the entrance axis and central route intact.
	var chairs := 0
	for place: Vector2 in [Vector2(-3.30,2.50),Vector2(-1.80,4.70)]:
		var setting := Node3D.new()
		setting.name = "MoriInteriorBistroSetting"
		setting.position = Vector3(place.x,FLOOR,place.y)
		root.add_child(setting)
		var table := Node3D.new()
		table.name = "BistroTable%d"%int(chairs/2+1)
		setting.add_child(table)
		Details._cafe_table(street,table)
		_fixture(fixtures,root,String(table.name),Rect2(place.x-.352,place.y-.352,.704,.704),"customer_table")
		for side: float in [-1.0,1.0]:
			var before := setting.get_child_count()
			Details._bentwood_chair(street,setting,Vector3(0,0,side*.62),0.0 if side > 0.0 else PI)
			if setting.get_child_count() > before:
				var chair := setting.get_child(setting.get_child_count()-1) as Node3D
				chair.set_meta("mori_interior_chair",true)
				chair.set_meta("source_scale",1.0)
				_prepare_chair_batch(chair)
				chairs += 1
				chair.name = "InteriorBentwoodChair%d"%chairs
				var chair_min_z := place.y+side*.62+(-.229428 if side > 0.0 else -.262501)
				_fixture(fixtures,root,String(chair.name),Rect2(place.x-.219491,chair_min_z,.438982,.491929),"customer_chair")

	var wash_bounds := Rect2(4.15,6.90,.53,.75)
	_counter_run(street,root,"MoriRearWashCabinet",wash_bounds,false)
	var wash_fixture := root.get_node("MoriRearWashCabinet") as Node3D
	# Add top objects in shop space, then preserve their transforms under fixture.
	var wash_contents := Node3D.new()
	wash_contents.name = "RearWashContents"
	root.add_child(wash_contents)
	Interiors._bowl(street,wash_contents,Vector3(4.415,WORKTOP,7.26))
	Details._rod(street,wash_contents,"MoriWashTapUpright",Vector3(4.65,WORKTOP,7.26),Vector3(4.65,1.28,7.26),.010,"detail_metal")
	Details._rod(street,wash_contents,"MoriWashTapSpout",Vector3(4.65,1.28,7.26),Vector3(4.45,1.28,7.26),.010,"detail_metal")
	wash_contents.reparent(wash_fixture,false)
	wash_contents.transform = wash_fixture.transform.affine_inverse()
	_fixture(fixtures,root,"MoriRearWashCabinet",wash_bounds,"staff_wash")
	_rear_storage(street,root)
	_fixture(fixtures,root,"MoriRearSupplyCupboard",Rect2(-4.68,6.90,1.45,.75),"rear_storage")
	_menu(street,root)
	_fixture(fixtures,root,"MoriRearMenu",Rect2(-1.21,7.62,2.42,.06),"wall_menu")

	var light_positions: Array[Vector3] = [Vector3(-2.50,2.35,3.60),Vector3(2.48,2.35,4.80),Vector3(0,2.65,3.90)]
	var clear_routes: Array[Rect2] = [
		Rect2(-.80,0,1.60,1.60), # Entry.
		Rect2(-.80,1.50,1.60,5.25), # Customer spine, reaching the rear pickup zone.
		Rect2(.70,2.35,1.30,4.00), # Customer ordering/pickup side of counter.
		Rect2(-2.85,2.05,2.25,1.00), # Branch to the first seating setting.
		Rect2(-1.35,3.90,1.00,1.50), # Branch to the second seating setting.
		Rect2(.70,1.50,3.35,.80), # Front crossover into staff aisle.
		Rect2(2.95,2.20,1.10,5.35) # Continuous staff aisle to rear handwash.
	]
	var report := {
		"ok":machine != null and chairs == 4 and int(pastries.loaded) == 5,
		"name":"MoriCoffee","fixtures":fixtures,"clear_routes":clear_routes,
		"route_roles":["entry","customer_spine","queue_and_pickup","seating_access_1","seating_access_2","staff_entry","staff_aisle"],
		"machine":machine_report,"pastry_case":pastries,
		"interior_chairs":chairs,"exterior_chairs_untouched":4,"total_cafe_chairs_expected":chairs+4,
		"bistro_tables":2,"floor_y":FLOOR,"worktop_y":WORKTOP,"rear_support_band":Vector2(6.8,7.8),
		"suggested_light_positions":light_positions,"lights_created":0,"pendants_created":0,
		"shared_material_limit":24,"preserves_original_asset_materials":true,"original_assets_modified":false,
		"batching":"existing recursive street pipeline; shared pastry vertex-colour material; original multi-surface espresso untouched",
		"validation_boundary":"source geometry/GLB bounds reviewed; no engine, installed visual or gameplay acceptance in this worker"
	}
	root.set_meta("mori_layout_report",report)
	shop.set_meta("mori_layout_report",report)
	return report

static func _fixture(fixtures: Array[Dictionary], root: Node3D, label: String, bounds: Rect2, role: String) -> void:
	var node := root.find_child(label,true,false) as Node3D
	if node == null: return
	node.set_meta("fixture_bounds",bounds)
	node.set_meta("fixture_role",role)
	fixtures.append({"name":String(node.name),"node_path":String(root.get_path_to(node)),"bounds":bounds,"role":role})

static func _counter_run(street: Node3D, root: Node3D, label: String, bounds: Rect2, face_positive_x: bool) -> void:
	var cabinet := Node3D.new()
	cabinet.name = label
	cabinet.position = Vector3(bounds.get_center().x,0,bounds.get_center().y)
	cabinet.rotation.y = -PI*.5 if face_positive_x else PI*.5
	cabinet.set_meta("fixture_bounds",bounds)
	cabinet.set_meta("working_face",Vector3.RIGHT if face_positive_x else Vector3.LEFT)
	root.add_child(cabinet)
	# 18mm carcass, framed doors, real recessed toe-space and supported pulls.
	# The reused joinery front is local -Z; rotate that front into the staff aisle.
	Interiors._cabinet(street,cabinet,Vector3(0,.54,0),Vector3(bounds.size.y-.02,.86,bounds.size.x-.04),true)
	Details._b(street,cabinet,"ContinuousSolidTimberWorktop",Vector3(0,.99,0),Vector3(bounds.size.y,.04,bounds.size.x),"detail_wood")

static func _backbar(street: Node3D, cabinet: Node3D) -> void:
	var root := Node3D.new()
	root.name = "BackbarContents"
	cabinet.get_parent().add_child(root)
	Details._b(street,root,"MoriWashableBackbarSplash",Vector3(4.685,1.30,5.175),Vector3(.018,.54,2.45),"detail_cream")
	for y: float in [1.77,2.24]:
		Details._b(street,root,"BackbarSolidShelf",Vector3(4.51,y,5.175),Vector3(.34,.028,2.45),"detail_wood")
		for z: float in [4.15,5.175,6.20]:
			Details._b(street,root,"BackbarBracketWallPlate",Vector3(4.681,y-.080,z),Vector3(.018,.18,.036),"detail_metal")
			Details._b(street,root,"BackbarBracketSupport",Vector3(4.51,y-.031,z),Vector3(.34,.028,.028),"detail_metal")
	# Modest working stock: clean cups, three coffee bags, one towel.
	for i: int in range(5): Details._cup(street,root,Vector3(4.45,1.784,4.35+float(i)*.33))
	for i: int in range(3):
		var z := 4.55+float(i)*.43
		Details._soft_block(street,root,"RoastedBeanBag",Vector3(4.51,2.405,z),Vector3(.20,.30,.25),"detail_paper")
		Details._b(street,root,"CoffeeBagPrintedLabel",Vector3(4.406,2.405,z),Vector3(.006,.11,.14),"detail_ink")
	Details._b(street,root,"FoldedBarTowel",Vector3(4.43,1.034,5.78),Vector3(.30,.048,.26),"detail_cream")
	root.reparent(cabinet,false)
	root.transform = cabinet.transform.affine_inverse()

static func _grinder(street: Node3D, root: Node3D) -> void:
	var group := Node3D.new()
	group.name = "MoriGrinder"
	group.position = Vector3(2.55,WORKTOP,5.65)
	root.add_child(group)
	Details._soft_block(street,group,"GrinderFoot",Vector3(0,.018,0),Vector3(.25,.036,.29),"detail_metal")
	Details._soft_block(street,group,"GrinderMotorHousing",Vector3(0,.16,0),Vector3(.19,.25,.22),"detail_metal")
	Details._cylinder(street,group,"HopperThroat",Vector3(0,.30,0),.044,.055,"detail_metal")
	Details._cylinder(street,group,"ClearBeanHopper",Vector3(0,.405,0),.075,.19,"arch_glass",.098)
	Details._cylinder(street,group,"BeansInsideHopper",Vector3(0,.385,0),.071,.12,"detail_darkwood",.085)
	Details._cylinder(street,group,"RemovableHopperLid",Vector3(0,.508,0),.100,.018,"detail_metal")
	Details._b(street,group,"GrinderDosingChute",Vector3(.122,.22,0),Vector3(.10,.075,.06),"detail_metal")
	for z: float in [-.027,.027]:
		Details._rod(street,group,"GrinderPortafilterFork",Vector3(.09,.13,z),Vector3(.235,.13,z),.006,"detail_metal")

static func _till(street: Node3D, root: Node3D) -> void:
	var station := Node3D.new()
	station.name = "MoriTill"
	root.add_child(station)
	var till := Node3D.new()
	till.name = "MoriTillFacingStaff"
	till.position = Vector3(2.57,WORKTOP,3.70)
	till.rotation.y = -PI*.5
	station.add_child(till)
	Details._soft_block(street,till,"TillStandFoot",Vector3(0,.015,0),Vector3(.20,.03,.22),"detail_metal")
	Details._b(street,till,"TillStandUpright",Vector3(0,.095,.025),Vector3(.035,.16,.035),"detail_metal")
	var screen := Details._soft_block(street,till,"StaffTillScreen",Vector3(0,.19,0),Vector3(.24,.16,.025),"detail_ink")
	screen.rotation.x = -.18
	Details._soft_block(street,station,"CustomerCardReader",Vector3(2.18,WORKTOP+.045,3.76),Vector3(.13,.09,.18),"detail_ink")

static func _pastry_case(street: Node3D, root: Node3D) -> Dictionary:
	var case_root := Node3D.new()
	case_root.name = "MoriCompactPastryCase"
	case_root.position = Vector3(2.475,WORKTOP,2.95)
	case_root.rotation.y = PI*.5 # The original sloped -Z face turns toward customers -X.
	root.add_child(case_root)
	Details._b(street,case_root,"PastryCaseCountertopBase",Vector3(0,.04,0),Vector3(.90,.08,.56),"detail_darkwood")
	for x: float in [-.43,.43]:
		Details._rod(street,case_root,"SlopedFrontCasePost",Vector3(x,.08,-.28),Vector3(x,.58,-.14),.012,"detail_metal")
		Details._rod(street,case_root,"RearCasePost",Vector3(x,.08,.26),Vector3(x,.58,.26),.012,"detail_metal")
		# Closed triangular side glazing; the staff rear remains open for service.
		_side_glass(street,case_root,x)
	Details._b(street,case_root,"PastryCaseGlassTop",Vector3(0,.58,.06),Vector3(.90,.012,.40),"arch_glass")
	var front := Details._b(street,case_root,"PastryCaseSlopedGlass",Vector3(0,.33,-.21),Vector3(.88,.51923,.010),"arch_glass")
	front.rotation.x = .273
	var loaded := 0
	var shared_pastry_material: Dictionary = {}
	for level: int in range(2):
		var y := .105+float(level)*.235
		Details._b(street,case_root,"PorcelainPastryTray",Vector3(0,y,.025),Vector3(.82,.018,.34),"detail_ceramic")
		var columns := 3 if level == 0 else 2
		for i: int in range(columns):
			var x := (float(i)-float(columns-1)*.5)*.27
			Details._cylinder(street,case_root,"IndividualPastryPlate",Vector3(x,y+.017,.025),.106,.016,"detail_ceramic")
			var pastry := Details._artisan_prop(case_root,"artisan_pastry.glb","OriginalArtisanButterCroissant",Vector3(x,y+.025,.025),1.0,-.10+float(i)*.07)
			if pastry != null:
				_share_pastry_material(pastry,shared_pastry_material)
				loaded += 1
	Details._b(street,case_root,"PastryCasePaperLabel",Vector3(0,.042,-.284),Vector3(.46,.048,.008),"detail_paper")
	var tag := Details._print(case_root,"PastryPriceLettering","BAKED TODAY",Vector3(0,.042,-.289),.014,Color("#303c36"))
	tag.set_meta("case_label",true)
	return {"loaded":loaded,"source":Details.ARTISAN_PATH+"artisan_pastry.glb","scale":1.0,"tiers":2,"arrangement":"3 lower / 2 upper","support_surface_y":WORKTOP,"customer_facing":Vector3.LEFT,"modified_source_assets":false,"original_case_reference":"Details._pastry_case: same sloped glazing/trays, resized authored construction rather than compressed asset instances"}

static func _side_glass(street: Node3D, parent: Node3D, x: float) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = [Vector3(x,.08,-.28),Vector3(x,.58,-.14),Vector3(x,.58,.26),Vector3(x,.08,.26)]
	var indices: Array[int] = [0,2,1,0,3,2]
	if x <= 0.0: indices.assign([0,1,2,0,2,3])
	for index: int in indices:
		tool.set_normal(Vector3.RIGHT if x > 0.0 else Vector3.LEFT)
		tool.add_vertex(points[index])
	var mesh := MeshInstance3D.new()
	mesh.name = "PastryCaseSideGlazing"
	mesh.mesh = tool.commit()
	mesh.material_override = street.get("materials")["arch_glass"]
	parent.add_child(mesh)

static func _share_pastry_material(node: Node, registry: Dictionary) -> void:
	# Details enables original GLB COLOR_0 on an instance duplicate. Share that
	# correctly configured material across all five identical original pastries.
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		if visual.mesh != null and visual.mesh.get_surface_count() == 1:
			if not registry.has("material"): registry["material"] = visual.get_active_material(0)
			# Preserve the imported mesh and share its real surface override. A
			# whole-mesh override would opt it into procedural geometry batching,
			# leaving the discarded instance's duplicate surface material behind.
			visual.set_surface_override_material(0,registry["material"])
	for child: Node in node.get_children(): _share_pastry_material(child,registry)

static func _prepare_chair_batch(node: Node) -> void:
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		if visual.mesh != null and visual.mesh.get_surface_count() == 1: visual.material_override = visual.get_active_material(0)
	for child: Node in node.get_children(): _prepare_chair_batch(child)

static func _rear_storage(street: Node3D, root: Node3D) -> void:
	var group := Node3D.new()
	group.name = "MoriRearSupplyCupboard"
	group.position = Vector3(-3.955,0,7.275)
	root.add_child(group)
	Interiors._cabinet(street,group,Vector3(0,.54,0),Vector3(1.41,.86,.71),true)
	Details._b(street,group,"StorageCountertop",Vector3(0,.99,0),Vector3(1.45,.04,.75),"detail_wood")
	for side: float in [-1.0,1.0]:
		Details._b(street,group,"SupplyCupboardEnd",Vector3(side*.716,1.7925,.06),Vector3(.018,1.565,.61),"detail_darkwood")
	Details._b(street,group,"SupplyCupboardBack",Vector3(0,1.84,.357),Vector3(1.414,1.47,.018),"detail_cream")
	for y: float in [1.115,1.59,2.065,2.575]:
		Details._b(street,group,"SupplyCupboardShelf",Vector3(0,y,.06),Vector3(1.414,.018,.61),"detail_wood")
	for i: int in range(3):
		Details._soft_block(street,group,"SealedCoffeeSupply",Vector3(-.43+float(i)*.43,1.77,.04),Vector3(.29,.34,.36),"detail_paper")
		Details._b(street,group,"SupplyBagLabel",Vector3(-.43+float(i)*.43,1.77,-.144),Vector3(.15,.11,.008),"detail_ink")

static func _menu(street: Node3D, root: Node3D) -> void:
	var menu := Node3D.new()
	menu.name = "MoriRearMenu"
	root.add_child(menu)
	Details._b(street,menu,"MoriRearMenuBoard",Vector3(0,1.88,7.665),Vector3(2.36,1.20,.030),"detail_ink")
	for side: float in [-1.0,1.0]:
		Details._b(street,menu,"MoriMenuFrameStile",Vector3(side*1.195,1.88,7.645),Vector3(.03,1.26,.05),"detail_wood")
		Details._b(street,menu,"MoriMenuFrameRail",Vector3(0,1.88+side*.615,7.645),Vector3(2.36,.03,.05),"detail_wood")
	Details._print(menu,"MoriMenuLettering","MORI COFFEE\nFILTER 450   LATTE 550\nTEA 400\nFRESHLY BAKED TODAY",Vector3(0,1.88,7.645),.105,Color("#d2c4a4"))
