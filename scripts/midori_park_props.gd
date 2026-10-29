extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")

# Measured fixtures beside the existing authored socket. World scale is
# independent of the concept layout's X/Z enlargement; no generator edits.
const VENDING := preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/neon_vending/vending_cyberpunk.tscn")
const RECYCLING := preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/recycling_station/recycling_cyberpunk.glb")
const FOUNTAIN := preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/drinking_fountain/fountain_satin.glb")
const CUP := preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/takeaway_cup/midori_takeaway_cup.glb")
const RACK := preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/bicycle_rack/midori_bicycle_rack.glb")
const BOARD := preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/information_board/midori_information_board.glb")
const PETAL_LIFE := preload("res://scripts/midori_petal_life.gd")
@export var enabled := true
@export var petal_life_enabled := true
var installed := false
var report: Dictionary = {}

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	call_deferred("install")

func install() -> void:
	if installed or not enabled:
		return
	var park := get_parent() as Node3D
	if park == null:
		return
	var marker := park.find_child("FUR10_VendingMachine", true, false) as Marker3D
	if marker == null:
		push_warning("MIDORI_PROPS: vending socket missing; skipped")
		return
	var fixture := VENDING.instantiate() as Node3D
	fixture.name = "PlazaNeonVending"
	add_child(fixture)
	fixture.global_transform = Transform3D(marker.global_basis.orthonormalized(), marker.global_position)
	# Rest the feet on the top of the actual layered plaza mesh, not the planning
	# marker's older ground height. Only the circular paved layers are considered.
	for ground_name: String in ["PlazaGroundingCourt", "PlazaOuterStoneTerrace", "PlazaMainStoneCourt"]:
		var ground := park.find_child(ground_name, true, false) as MeshInstance3D
		if ground == null:
			continue
		var ground_bounds := ground.global_transform * ground.get_aabb()
		var center := ground_bounds.get_center()
		var radius_x := ground_bounds.size.x * 0.5
		var radius_z := ground_bounds.size.z * 0.5
		var delta := fixture.global_position - center
		if pow(delta.x / radius_x, 2.0) + pow(delta.z / radius_z, 2.0) <= 1.0:
			fixture.global_position.y = maxf(fixture.global_position.y, ground_bounds.end.y + 0.002)
	var body := StaticBody3D.new()
	body.name = "MeasuredChassisCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.870, 1.830, 0.669)
	collision.shape = shape
	collision.position.y = 0.915
	body.add_child(collision)
	fixture.add_child(body)
	var recycling := RECYCLING.instantiate() as Node3D
	recycling.name = "PlazaRecyclingStation"
	add_child(recycling)
	recycling.global_transform = fixture.global_transform
	# Leave over 1.2m between the physical shells, with the front opening onto
	# the plaza. The station shares the same paved layer and measured world scale.
	recycling.global_position.x -= 2.2
	var recycling_body := StaticBody3D.new()
	recycling_body.name = "MeasuredBinCollision"
	recycling_body.collision_layer = 1
	recycling_body.collision_mask = 1
	for x: float in [-0.245, 0.245]:
		var bin_collision := CollisionShape3D.new()
		var bin_shape := BoxShape3D.new()
		bin_shape.size = Vector3(0.470, 0.930, 0.4354)
		bin_collision.shape = bin_shape
		bin_collision.position = Vector3(x, 0.465, -0.0002)
		recycling_body.add_child(bin_collision)
	recycling.add_child(recycling_body)
	var fountain := FOUNTAIN.instantiate() as Node3D
	fountain.name = "PlazaDrinkingFountain"
	add_child(fountain)
	fountain.global_transform = Transform3D(Basis(Vector3.UP,-PI*.5), Vector3(140,0.1365,154))
	var fountain_body := StaticBody3D.new()
	fountain_body.name = "MeasuredFountainCollision"
	fountain_body.collision_layer = 1
	fountain_body.collision_mask = 1
	var fountain_collision := CollisionShape3D.new()
	var fountain_shape := CylinderShape3D.new()
	fountain_shape.radius = 0.155
	fountain_shape.height = 1.089
	fountain_collision.shape = fountain_shape
	fountain_collision.position.y = 1.089*.5
	fountain_body.add_child(fountain_collision)
	fountain.add_child(fountain_body)
	# A single human-approved litter prop rests on existing flat paving. Bench
	# slats were checked and rejected as an uneven support; no gameplay collider.
	var cup := CUP.instantiate() as Node3D
	cup.name = "LeftBehindTakeawayCup"
	add_child(cup)
	cup.global_transform = Transform3D(Basis.IDENTITY,Vector3(142.84024,0.1355,153.43339))
	var rack_marker := park.find_child("FUR09_BicycleRack",true,false) as Marker3D
	var rack: Node3D
	if rack_marker == null:
		push_warning("MIDORI_PROPS: bicycle rack socket missing; skipped")
	else:
		rack = RACK.instantiate() as Node3D
		rack.name = "PlazaBicycleRack"
		add_child(rack)
		rack.global_transform = Transform3D(rack_marker.global_basis.orthonormalized(),Vector3(148,.1365,156))
		var rack_body := StaticBody3D.new()
		rack_body.name = "MeasuredHoopCollision"
		rack_body.collision_layer = 1
		rack_body.collision_mask = 1
		# Measured tube centreline: thin capsules preserve the empty hoop.
		var points := PackedVector3Array([
			Vector3(-.35708,.025,0),Vector3(-.35703,.680,0),
			Vector3(-.340,.75126,0),Vector3(-.300,.81029,0),
			Vector3(-.270,.82883,0),Vector3(-.200,.83975,0),
			Vector3(.200,.83980,0),Vector3(.270,.82701,0),
			Vector3(.300,.80809,0),Vector3(.340,.74832,0),
			Vector3(.35719,.680,0),Vector3(.35722,.025,0),
		])
		for index: int in range(points.size()-1):
			var start := points[index]
			var end := points[index+1]
			var tube_collision := CollisionShape3D.new()
			var tube := CapsuleShape3D.new()
			tube.radius = .0245 if index in [0,5,10] else .028
			tube.height = start.distance_to(end) + 2.0*tube.radius
			tube_collision.shape = tube
			tube_collision.transform = Transform3D(Basis(Quaternion(Vector3.UP,(end-start).normalized())),(start+end)*.5)
			rack_body.add_child(tube_collision)
		rack.add_child(rack_body)
	var board := _add_information_board(park)
	var petal_life := Node3D.new()
	petal_life.name = "MidoriPetalLife"
	petal_life.set_script(PETAL_LIFE)
	petal_life.set("enabled",petal_life_enabled)
	add_child(petal_life)
	installed = true
	report = {"fixture_count":(5 if rack != null else 4)+(1 if board != null else 0), "position":str(fixture.global_position), "world_scale":str(fixture.global_basis.get_scale()), "physical_size_m":str(shape.size), "holograms":fixture.holograms.size(), "collision_layer":body.collision_layer, "recycling_position":str(recycling.global_position), "recycling_module_size_m":"(0.470,0.930,0.4354)", "recycling_shell_gap_m":1.285, "fountain_position":str(fountain.global_position), "cup_position":str(cup.global_position), "cup_collision":false, "rack_position":str(rack.global_position) if rack != null else "skipped", "rack_collision_segments":11 if rack != null else 0, "board_position":str(board.global_position) if board != null else "skipped", "board_collision_shapes":4 if board != null else 0}
	print("MIDORI_PROPS: ", JSON.stringify(report))

func _add_information_board(park: Node3D) -> Node3D:
	var marker := park.find_child("FUR06_MainInformationBoard",true,false) as Marker3D
	var ground_body := park.find_child("ParkGround_220x180m",true,false) as StaticBody3D
	var ground: MeshInstance3D
	if ground_body != null and ground_body.get_child_count() > 0:
		ground = ground_body.get_child(0) as MeshInstance3D
	if marker == null or ground == null:
		push_warning("MIDORI_PROPS: information board socket/ground missing; skipped")
		return null
	# The accepted socket is on this flat ground mesh, outside the arrival paving.
	# Read the authored visible top directly; no deferred physics sync is required.
	var ground_bounds := ground.global_transform * ground.get_aabb()
	var position := marker.global_position
	if position.x-.631 < ground_bounds.position.x or position.x+.631 > ground_bounds.end.x or position.z < ground_bounds.position.z or position.z > ground_bounds.end.z:
		push_warning("MIDORI_PROPS: information board outside supporting ground; skipped")
		return null
	position.y = ground_bounds.end.y+.002
	var board := BOARD.instantiate() as Node3D
	board.name = "MainInformationBoard"
	add_child(board)
	board.global_transform = Transform3D(marker.global_basis.orthonormalized(),position)
	var body := StaticBody3D.new()
	body.name = "MeasuredBoardCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	for x: float in [-.600,.600]:
		var collision := CollisionShape3D.new()
		var post := CylinderShape3D.new()
		post.radius = .031
		post.height = 2.0
		collision.shape = post
		collision.position = Vector3(x,1.0,0)
		body.add_child(collision)
	var panel_collision := CollisionShape3D.new()
	var panel := BoxShape3D.new()
	panel.size = Vector3(1.16,1.20,.065)
	panel_collision.shape = panel
	panel_collision.position = Vector3(0,1.38,0)
	body.add_child(panel_collision)
	var rail_collision := CollisionShape3D.new()
	var rail := CapsuleShape3D.new()
	rail.radius = .031
	rail.height = 1.202
	rail_collision.shape = rail
	rail_collision.transform = Transform3D(Basis(Quaternion(Vector3.UP,Vector3.RIGHT)),Vector3(0,2.0,0))
	body.add_child(rail_collision)
	board.add_child(body)
	return board
