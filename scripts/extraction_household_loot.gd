extends RefCounted
## Household records reuse the existing inventory, can-opening and optic systems.
## Tier is local residential loot balance, not a new equipment-stat system.
const Containers = preload("./extraction_loot_containers.gd")
const Catalog = preload("./extraction_weapon_catalog.gd")
const Food = preload("./extraction_food_condition.gd")
const Models = preload("./extraction_residential_models.gd")
const POOLS := {
	"attachment":["optic_reflex_01", "optic_prism_01"],
	"tool":["can_opener", "pliers", "scissors", "utility_knife", "hammer", "screwdriver", "wrench"],
	"food":["canned_mackerel", "canned_peaches", "ration_bar"]
}
const TIERS := {
	"optic_reflex_01":2, "optic_prism_01":3,
	"can_opener":1, "pliers":1, "scissors":1, "utility_knife":1,
	"hammer":1, "screwdriver":1, "wrench":1,
	"canned_mackerel":1, "canned_peaches":1, "ration_bar":1
}

static func categories() -> Dictionary:
	return {"attachment":.06, "tool":.06, "food":.08}

static func tier(entry: Dictionary) -> int:
	return int(TIERS.get(str(entry.get("id", "")), 0))

static func item(category: String, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = POOLS.get(category, [])
	if pool.is_empty(): return {}
	return spec(str(pool[rng.randi_range(0, pool.size() - 1)]))

static func spec(id: String) -> Dictionary:
	if not TIERS.has(id): return {}
	var result := {}
	if id in POOLS.attachment:
		var optic_id := id.trim_prefix("optic_")
		var optic := Catalog.optic(optic_id)
		if optic.is_empty() or not ResourceLoader.exists(str(optic.scene)): return {}
		result = {"id":id, "optic_id":optic_id, "title":str(optic.title),
			"value":65 if optic_id == "reflex_01" else 95,
			"mass_kg":float(optic.handling_mass_kg), "world_spawn":false,
			"description":"Recovered optic. Fits compatible optic_mount_v1 weapons through the existing optic tray."}
	else:
		result = Containers.spec(id)
	if result.is_empty(): return {}
	result.tier = int(TIERS[id])
	for category: String in POOLS:
		if id in POOLS[category]: result.household_category = category
	Food.ensure(result)
	return result

static func model(entry: Dictionary) -> Node3D:
	var id := str(entry.get("id", ""))
	if not TIERS.has(id): return null
	var root: Node3D = _optic(id.trim_prefix("optic_")) if id in POOLS.attachment else Node3D.new()
	if root == null: return null
	root.name = "Household_" + id
	if id in POOLS.tool: _tool(root, id)
	elif id in POOLS.food: _food(root, id)
	if root.get_child_count() == 0:
		root.free(); return null
	var box := Models.bounds(root)
	var offset := Vector3(-box.get_center().x, .008 - box.position.y, -box.get_center().z)
	for child: Node3D in root.get_children(): child.position += offset
	root.set_meta("residential_model_size", box.size)
	root.set_meta("household_item_id", id)
	return root

static func _optic(optic_id: String) -> Node3D:
	var definition := Catalog.optic(optic_id)
	if definition.is_empty(): return null
	var packed := load(str(definition.scene)) as PackedScene
	if packed == null: return null
	var source := packed.instantiate() as Node3D
	if source == null: return null
	var output := Node3D.new()
	# Static copies retain the authored optic mesh/materials without mounted logic.
	for node: Node in source.find_children("*", "MeshInstance3D", true, false):
		var original := node as MeshInstance3D
		if original.mesh == null or original.skin != null: continue
		var copy := MeshInstance3D.new()
		copy.name = original.name
		copy.mesh = original.mesh
		copy.transform = Models._relative(original, source)
		copy.material_override = original.material_override
		for surface in range(copy.mesh.get_surface_count()):
			copy.set_surface_override_material(surface, original.get_active_material(surface))
		copy.layers = 1
		output.add_child(copy)
	source.free()
	return output

static func _material(color: Color, metallic: float = 0.0, roughness: float = .65) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

static func _mesh(root: Node3D, label: String, geometry: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = geometry
	part.position = position
	part.material_override = material
	root.add_child(part)
	return part

static func _box(root: Node3D, label: String, size: Vector3, position: Vector3, material: Material, turn: float = 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := _mesh(root, label, mesh, position, material)
	part.rotation.y = turn

static func _cylinder(root: Node3D, label: String, radius: float, height: float, position: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height
	mesh.radial_segments = 24; mesh.rings = 1
	_mesh(root, label, mesh, position, material)

static func _ring(root: Node3D, label: String, inner: float, outer: float, position: Vector3, material: Material, stretch: Vector3 = Vector3.ONE) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner; mesh.outer_radius = outer
	mesh.rings = 24; mesh.ring_segments = 8
	_mesh(root, label, mesh, position, material).scale = stretch

static func _tool(root: Node3D, id: String) -> void:
	var steel := _material(Color("9da5a7"), .82, .32)
	var dark := _material(Color("2c3335"), .15, .78)
	var grip := _material(Color("aa4b31"), .0, .84)
	var wood := _material(Color("9f7650"), .0, .77)
	match id:
		"hammer":
			_box(root, "AshHandle", Vector3(.026,.027,.25), Vector3(0,.017,.035), wood)
			_box(root, "GripEnd", Vector3(.030,.030,.065), Vector3(0,.017,.13), dark)
			_box(root, "SteelHead", Vector3(.10,.045,.038), Vector3(0,.023,-.095), steel)
			_box(root, "StrikingFace", Vector3(.018,.051,.042), Vector3(-.054,.023,-.095), steel)
			for z in [-.108,-.082]:
				_box(root, "Claw", Vector3(.048,.015,.012), Vector3(.062,.012,z), steel, -.22)
		"screwdriver":
			_box(root, "Handle", Vector3(.031,.028,.083), Vector3(0,.018,.06), grip)
			_box(root, "SteelShaft", Vector3(.007,.007,.104), Vector3(0,.018,-.033), steel)
			_box(root, "FlatBlade", Vector3(.011,.004,.023), Vector3(0,.017,-.093), steel)
			for z in [.035,.055,.075]:
				_box(root, "GripRib", Vector3(.033,.030,.004), Vector3(0,.018,z), dark)
		"wrench":
			_box(root, "SteelHandle", Vector3(.022,.012,.145), Vector3(0,.012,.035), steel)
			_box(root, "JawBody", Vector3(.057,.020,.041), Vector3(.005,.014,-.054), steel)
			_box(root, "FixedJaw", Vector3(.017,.020,.043), Vector3(-.020,.014,-.084), steel)
			_box(root, "SlidingJaw", Vector3(.018,.020,.032), Vector3(.026,.014,-.078), steel)
			_box(root, "AdjustmentWheel", Vector3(.022,.024,.014), Vector3(.007,.015,-.045), dark)
			_ring(root, "HangingEye", .006,.010, Vector3(0,.012,.108), steel)
		"utility_knife":
			_box(root, "KnifeShell", Vector3(.032,.018,.125), Vector3(0,.013,.01), grip)
			_box(root, "BladeChannel", Vector3(.012,.005,.093), Vector3(0,.024,-.001), dark)
			_box(root, "RetractedSteelTip", Vector3(.012,.003,.016), Vector3(0,.017,-.055), steel)
			_box(root, "ThumbSlider", Vector3(.015,.009,.019), Vector3(0,.027,.025), dark)
			for z in [.032,.043,.054]:
				_box(root, "GripNotch", Vector3(.034,.020,.002), Vector3(0,.013,z), dark)
		"pliers":
			for side in [-1.0,1.0]:
				_box(root, "Grip", Vector3(.018,.018,.105), Vector3(side*.023,.015,.044), grip, side*.25)
				_box(root, "Arm", Vector3(.013,.014,.067), Vector3(side*.012,.015,-.012), steel, side*.22)
				_box(root, "Jaw", Vector3(.014,.018,.047), Vector3(side*.009,.015,-.058), steel, side*-.12)
			_cylinder(root, "Pivot", .012,.019, Vector3(0,.015,-.025), steel)
		"scissors":
			for side in [-1.0,1.0]:
				_ring(root, "FingerLoop", .013,.019, Vector3(side*.020,.010,.061), grip, Vector3(1,.65,1.35))
				_box(root, "HandleLink", Vector3(.009,.009,.056), Vector3(side*.011,.010,.025), steel, side*.35)
				_box(root, "ClosedBlade", Vector3(.009,.006,.085), Vector3(side*.004,.010,-.044), steel, side*-.06)
			_cylinder(root, "PivotScrew", .007,.013, Vector3(0,.012,0), steel)
		"can_opener":
			for side in [-1.0,1.0]:
				_box(root, "CoatedHandle", Vector3(.014,.014,.082), Vector3(side*.018,.013,.033), dark, side*.18)
				_box(root, "SteelLink", Vector3(.012,.009,.047), Vector3(side*.008,.016,-.022), steel, side*.18)
			_cylinder(root, "CuttingWheel", .015,.006, Vector3(-.009,.018,-.050), steel)
			_cylinder(root, "DriveWheel", .011,.012, Vector3(.011,.018,-.048), steel)
			_box(root, "TurnKey", Vector3(.042,.008,.015), Vector3(.013,.029,-.035), dark)

static func _food(root: Node3D, id: String) -> void:
	var tin := _material(Color("b4bbba"), .8, .32)
	var cream := _material(Color("e4dfcb"), .0, .78)
	if id == "ration_bar":
		var wrapper := _material(Color("8c7951"), .10, .68)
		_box(root, "SealedWrapper", Vector3(.061,.020,.132), Vector3(0,.013,0), wrapper)
		_box(root, "PaperBand", Vector3(.062,.021,.052), Vector3(0,.013,0), cream)
		for z in [-.069,.069]:
			_box(root, "CrimpedSeal", Vector3(.063,.009,.008), Vector3(0,.012,z), wrapper)
			for x in [-.024,-.012,0,.012,.024]:
				_box(root, "SealRidge", Vector3(.002,.011,.008), Vector3(x,.012,z), tin)
		_box(root, "LabelStripe", Vector3(.043,.001,.009), Vector3(0,.024,.008), _material(Color("43553c")))
		return
	var fish := id == "canned_mackerel"
	var radius := .039 if fish else .037
	var height := .043 if fish else .105
	var label := _material(Color("3c6570") if fish else Color("d3994e"), .0, .73)
	_cylinder(root, "SealedTin", radius, height, Vector3(0,height*.5,0), tin)
	_cylinder(root, "PaperLabel", radius+.0006, height-.014, Vector3(0,height*.5,0), label)
	for y in [.003,height-.003]:
		_ring(root, "RolledRim", radius-.0015,radius+.0015,Vector3(0,y,0),tin)
	# Label band and rim detail make the small tins distinct at pickup distance.
	_cylinder(root, "LabelBand", radius+.0009,.007,Vector3(0,height*.55,0),cream)
	_cylinder(root, "RecessedLid", radius-.004,.001,Vector3(0,height+.0005,0),tin)
	if fish:
		_ring(root, "PullTab", .006,.009,Vector3(0,height+.003,.006),tin,Vector3(.75,.5,1.2))
		_cylinder(root, "TabRivet", .0025,.003,Vector3(0,height+.002,-.004),tin)
