extends RefCounted
## Compact off-street parking for the three original lane houses. The hardscape
## is owned by midori_neighbourhood_ground.gd; this builder adds the supported
## carports, bay markings and parked resident cars before street batching.

const BAYS: Array[Dictionary] = [
	{"id":"KobayashiParking","number":"01","rect":Rect2(-26.35,227.45,4.30,7.55),"car":true,"color":Color("#6f827f")},
	{"id":"SugiParking","number":"02","rect":Rect2(-13.65,227.45,4.10,7.55),"car":false,"color":Color("#8c877a")},
	{"id":"AokiParking","number":"03","rect":Rect2(7.55,227.45,3.55,7.55),"car":true,"color":Color("#776b70")}
]

static func build(street: Node3D, ground: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "ResidentParking"
	root.set_meta("creator_protected",true)
	root.set_meta("creator_editable",false)
	street.add_child(root)
	var rows: Array[Dictionary] = []
	var parked := 0
	for spec: Dictionary in BAYS:
		var rect: Rect2 = spec.rect
		var bay := Node3D.new()
		bay.name = String(spec.id)
		bay.position = Vector3(rect.get_center().x,.09,rect.get_center().y)
		bay.set_meta("creator_protected",true)
		bay.set_meta("creator_editable",false)
		root.add_child(bay)
		_mark_bay(street,bay,rect.size)
		_carport(street,bay,rect.size)
		var car_bounds := AABB()
		if bool(spec.car):
			car_bounds = _compact_car(street,bay,spec.color)
			parked += 1
		var number := Label3D.new()
		number.name = "ResidentBayNumber"
		number.text = "P " + String(spec.number)
		number.font_size = 48
		number.pixel_size = .30/48.0
		number.modulate = Color("#e1ddd0")
		number.position = Vector3(0,.018,-rect.size.y*.5+.78)
		number.rotation_degrees = Vector3(-90,0,0)
		number.outline_size = 0
		bay.add_child(number)
		rows.append({"id":spec.id,"house_number":spec.number,"rect":rect,"occupied":spec.car,"vehicle_bounds":car_bounds,"dropped_kerb":true,"carport":true})
	var report := {"ok":true,"bays":rows,"bay_count":rows.size(),"parked_cars":parked,"empty_bays":rows.size()-parked,"parking_type":"private off-street compact bays","vehicle_type":"kei-scale compact resident cars","lane_blocked":false,"pedestrian_crossing_retained":true,"ground_rectangles":ground.get("parking_rectangles",[]),"new_lights":0,"per_frame_scripts":0,"source_assets_modified":false}
	root.set_meta("resident_parking",report)
	street.set_meta("resident_parking",report)
	return report

static func _mark_bay(street: Node3D, bay: Node3D, size: Vector2) -> void:
	var half_w := size.x*.5-.18
	var half_l := size.y*.5-.18
	for x: float in [-half_w,half_w]:
		street.call("_box",bay,"ParkingEdge",Vector3(x,.012,.15),Vector3(.055,.018,size.y-1.25),"paint")
	street.call("_box",bay,"ParkingStopLine",Vector3(0,.012,half_l),Vector3(size.x-.36,.018,.055),"paint")
	# Short entry ticks keep the dropped kerb readable as a driveway, not a footpath.
	for x: float in [-half_w,half_w]:
		street.call("_box",bay,"ParkingEntryTick",Vector3(x,.012,-half_l+.18),Vector3(.055,.018,.36),"paint")

static func _carport(street: Node3D, bay: Node3D, size: Vector2) -> void:
	var w := size.x-.34
	var rear := size.y*.5-.34
	var front := -size.y*.5+1.18
	for x: float in [-w*.5,w*.5]:
		for z: float in [front,rear]:
			street.call("_box",bay,"CarportPost",Vector3(x,1.18,z),Vector3(.10,2.20,.10),"metal",true)
	var roof := street.call("_box",bay,"CarportRoof",Vector3(0,2.34,.42),Vector3(w+.30,.10,rear-front+.42),"roof") as MeshInstance3D
	roof.rotation.z = deg_to_rad(-3.0)
	street.call("_box",bay,"CarportFrontBeam",Vector3(0,2.20,front),Vector3(w+.12,.13,.10),"metal")
	street.call("_box",bay,"CarportRearBeam",Vector3(0,2.20,rear),Vector3(w+.12,.13,.10),"metal")

static func _compact_car(street: Node3D, bay: Node3D, color: Color) -> AABB:
	var car := Node3D.new()
	car.name = "ParkedResidentKeiCar"
	car.position = Vector3(0,.10,.35)
	car.set_meta("creator_protected",true)
	car.set_meta("creator_editable",false)
	bay.add_child(car)
	var paint := StandardMaterial3D.new()
	paint.resource_name = "ResidentKeiPaint"
	paint.albedo_color = color
	paint.roughness = .58
	paint.metallic = .18
	var dark := StandardMaterial3D.new()
	dark.resource_name = "ResidentKeiTrim"
	dark.albedo_color = Color("#171c1d")
	dark.roughness = .72
	var glass := StandardMaterial3D.new()
	glass.resource_name = "ResidentKeiGlass"
	glass.albedo_color = Color("#26383c")
	glass.roughness = .26
	glass.metallic = .35
	_box(car,"LowerBody",Vector3(0,.48,0),Vector3(1.56,.64,3.32),paint)
	_box(car,"Cabin",Vector3(0,1.02,.18),Vector3(1.46,.72,1.92),paint)
	_box(car,"Windscreen",Vector3(0,1.08,-.80),Vector3(1.30,.48,.035),glass)
	_box(car,"RearGlass",Vector3(0,1.08,1.16),Vector3(1.30,.48,.035),glass)
	for side: float in [-1.0,1.0]:
		_box(car,"SideGlass",Vector3(side*.746,1.08,.18),Vector3(.025,.48,1.54),glass)
		_box(car,"DoorJoint",Vector3(side*.762,.62,.18),Vector3(.012,.46,.035),dark)
		for z: float in [-1.04,1.04]:
			_wheel(car,Vector3(side*.80,.32,z),dark)
	_box(car,"FrontBumper",Vector3(0,.38,-1.70),Vector3(1.42,.20,.12),dark)
	_box(car,"RearBumper",Vector3(0,.38,1.70),Vector3(1.42,.20,.12),dark)
	for x: float in [-.48,.48]:
		_box(car,"Headlamp",Vector3(x,.60,-1.77),Vector3(.25,.16,.035),street.get("materials")["warm"])
		_box(car,"TailLamp",Vector3(x,.60,1.77),Vector3(.25,.16,.035),street.get("materials")["red"])
	street.call("_solid",car,"ParkedCarCollision",Vector3(0,.66,0),Vector3(1.62,1.24,3.46))
	return AABB(car.position+Vector3(-.81,0,-1.73),Vector3(1.62,1.38,3.46))

static func _box(parent: Node3D, label: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = material
	visual.position = position
	parent.add_child(visual)
	return visual

static func _wheel(parent: Node3D, position: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = .24
	mesh.bottom_radius = .24
	mesh.height = .14
	mesh.radial_segments = 12
	var wheel := MeshInstance3D.new()
	wheel.name = "Wheel"
	wheel.mesh = mesh
	wheel.material_override = material
	wheel.position = position
	wheel.rotation_degrees.z = 90
	parent.add_child(wheel)
