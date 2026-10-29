extends Node3D

const REACH := 2.3
const DURATION := .75
const MODELS := "res://assets/shinrai/buildings/clubhouse_doors"
const HINGE_AXIS := Vector3(-.004,0,.026)
var doors: Array[Dictionary] = []
var controller: Node
var active := false
var key_held := true
var fresh_release_required := true
var _models: Dictionary = {}
var _materials: Dictionary = {}
var _frame_material: StandardMaterial3D
var _hinge_material: StandardMaterial3D

static func install(cafe: Node3D,raid: Node) -> Node3D:
	if cafe == null: return null
	var existing := cafe.get_node_or_null("ClubhouseDoors")
	if existing != null:
		existing.controller = raid
		return existing
	var service := load("res://scripts/midori_clubhouse_doors.gd").new() as Node3D
	service.name = "ClubhouseDoors"
	cafe.add_child(service)
	service.build(raid)
	return service

func build(raid: Node,models_dir := MODELS) -> void:
	assert(doors.is_empty(),"Door service must be built once")
	controller = raid
	_frame_material = StandardMaterial3D.new()
	_frame_material.albedo_color = Color("#493726")
	_frame_material.roughness = .58
	_hinge_material = StandardMaterial3D.new()
	_hinge_material.albedo_color = Color(.56,.59,.59)
	_hinge_material.metallic = .88
	_hinge_material.roughness = .34
	_add_door("FrontEntry","front entrance",Vector3(0,.2475,-.68),PI,1.20,2.0525,.025,models_dir.path_join("clubhouse_door_front_1140.glb"),1.14,1.995,-90,false)
	# 84 degrees leaves handle clearance against the adjacent front room wall.
	_add_door("ChangingA","Changing A",Vector3(-.98,.2475,7.85),-PI*.5,1.245,2.1575,.025,models_dir.path_join("clubhouse_door_interior_1185.glb"),1.185,2.1,-84,false)
	_add_door("ChangingB","Changing B",Vector3(.98,.2475,7.85),PI*.5,1.245,2.1575,.025,models_dir.path_join("clubhouse_door_interior_1185.glb"),1.185,2.1,84,false,-1)
	_add_door("PublicWC","public WC",Vector3(.98,.2475,4.95),PI*.5,1.245,2.1575,.025,models_dir.path_join("clubhouse_door_interior_1185.glb"),1.185,2.1,84,false,-1)
	_add_door("RearExit","rear exit",Vector3(0,.2475,12),0,1.68,2.1575,.0325,models_dir.path_join("clubhouse_door_rear_leaf_800.glb"),.8,2.1,-90,true)

func _model(path: String) -> Node3D:
	if not _models.has(path):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(path,state)==OK,"Door GLB failed: "+path)
		var source := document.generate_scene(state)
		for mesh: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
			for surface: int in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(surface)
				var key := material.resource_name
				if not _materials.has(key): _materials[key] = material
				mesh.set_surface_override_material(surface,_materials[key])
		var packed := PackedScene.new()
		assert(packed.pack(source)==OK)
		_models[path] = packed
		source.free()
	return (_models[path] as PackedScene).instantiate() as Node3D

func _add_door(id: String,title: String,at: Vector3,yaw: float,width: float,height: float,jamb: float,model_path: String,leaf_width: float,leaf_height: float,angle: float,paired: bool,handedness := 1.0) -> void:
	var frame := Node3D.new()
	frame.name = id
	add_child(frame)
	frame.position = at
	frame.rotation.y = yaw
	var bottom_gap := .0205 if id=="FrontEntry" else .008
	var header := .025 if id=="FrontEntry" else .04
	for side: float in [-1,1]:
		_frame_box(frame,"FrameJamb",Vector3(side*(width-jamb)*.5,height*.5,0),Vector3(jamb,height,.16))
	_frame_box(frame,"FrameHeader",Vector3(0,height-header*.5,0),Vector3(width,header,.16))
	var leaves: Array[Dictionary] = []
	for index: int in range(2 if paired else 1):
		var direction := handedness if index==0 else -handedness
		var body := AnimatableBody3D.new()
		body.name = "LeftLeaf" if index==0 else "RightLeaf"
		body.collision_layer = 1
		body.collision_mask = 0
		body.sync_to_physics = false
		frame.add_child(body)
		var slab_origin := Vector3(direction*(-width*.5+jamb+.005),bottom_gap,.054)
		var axis := Vector3(HINGE_AXIS.x*direction,0,HINGE_AXIS.z)
		body.position = slab_origin+axis
		var handed_path := model_path.replace(".glb","_right.glb") if direction<0.0 else model_path
		var model := _model(handed_path)
		model.name = "MeasuredDoorModel"
		body.add_child(model)
		model.scale = Vector3.ONE # handedness baked into preserved derivative GLB
		model.position = -axis
		var collider := CollisionShape3D.new()
		collider.name = "LeafCollision45mm"
		var box := BoxShape3D.new()
		box.size = Vector3(leaf_width,leaf_height,.045)
		collider.shape = box
		collider.position = Vector3(direction*leaf_width*.5,leaf_height*.5,0)-axis
		body.add_child(collider)
		var hinge_heights := [.35,leaf_height*.5,leaf_height-.25]
		for hinge_index: int in range(3):
			var y: float = hinge_heights[hinge_index]
			var plate := MeshInstance3D.new()
			plate.name = str(body.name)+"StationaryFrameHingePlate"+str(hinge_index)
			var plate_box := BoxMesh.new()
			plate_box.size = Vector3(.032,.10,.003)
			plate_box.material = _hinge_material
			plate.mesh = plate_box
			frame.add_child(plate)
			plate.position = slab_origin+Vector3(-.020*direction,y,.0275)
		leaves.append({"body":body,"width":leaf_width,"height":leaf_height,"base_yaw":0.0,"open_angle":deg_to_rad(angle if not paired else angle*direction),"direction":direction,"axis":axis})
	doors.append({"id":id,"title":title,"frame":frame,"width":width,"height":height,"leaves":leaves,"opened":false,"moving":false,"blocked":false,"elapsed":0.0,"target_open":false,"start_angles":[],"actor":null})

func _frame_box(parent: Node3D,label: String,at: Vector3,size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	parent.add_child(body)
	body.position = at
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = _frame_material
	mesh.mesh = box
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func set_active(enabled: bool) -> void:
	active = enabled
	key_held = true
	fresh_release_required = true

func raid_active() -> bool:
	return active and (not is_instance_valid(controller) or int(controller.phase)==2)

func nearest(player: Node3D) -> Dictionary:
	if player == null: return {}
	var found: Dictionary = {}
	var best := REACH
	for door: Dictionary in doors:
		var p: Vector3 = door.frame.to_local(player.global_position)
		if absf(p.x)>float(door.width)*.5+.25 or p.y<-.5 or p.y>float(door.height)+.4: continue
		var distance := Vector2(p.x,p.z).length()
		if distance<best and _visible_aperture(door,player):
			best = distance
			found = door
	return found

func _visible_aperture(door: Dictionary,player: Node3D) -> bool:
	var from := player.global_position+Vector3.UP*1.0
	var target: Vector3 = door.frame.to_global(Vector3(0,1.0,0))
	var query := PhysicsRayQueryParameters3D.create(from,target,1)
	var excluded: Array[RID] = []
	if player is CollisionObject3D: excluded.append(player.get_rid())
	for leaf: Dictionary in door.leaves: excluded.append(leaf.body.get_rid())
	query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func interaction_distance(player: Node3D) -> float:
	if not raid_active(): return INF
	var door := nearest(player)
	if door.is_empty(): return INF
	var p: Vector3 = door.frame.to_local(player.global_position)
	return Vector2(p.x,p.z).length()

func body_radius(body: Node3D) -> float:
	var radius := .36
	for node: CollisionShape3D in body.find_children("*","CollisionShape3D",true,false):
		if node.disabled or node.shape==null: continue
		if node.shape is CapsuleShape3D:
			var offset := node.global_position-body.global_position
			var scale_value := node.global_basis.get_scale()
			radius = maxf(radius,Vector2(offset.x,offset.z).length()+node.shape.radius*maxf(scale_value.x,scale_value.z))
		else:
			var bounds := node.global_transform*node.shape.get_debug_mesh().get_aabb()
			for corner: Vector3 in [bounds.position,bounds.end,Vector3(bounds.position.x,0,bounds.end.z),Vector3(bounds.end.x,0,bounds.position.z)]:
				radius = maxf(radius,Vector2(corner.x-body.global_position.x,corner.z-body.global_position.z).length())
	return radius

func sweep_occupied(door: Dictionary,point: Vector3,radius := .36) -> bool:
	var p: Vector3 = door.frame.to_local(point)
	if p.y<-.5 or p.y>float(door.height)+.4: return false
	for leaf: Dictionary in door.leaves:
		var hinge: Vector3 = leaf.body.position
		for step: int in range(13):
			var yaw: float = leaf.base_yaw+leaf.open_angle*float(step)/12.0
			var q: Vector3 = Basis(Vector3.UP,-yaw)*(p-hinge)+leaf.axis
			q.x *= float(leaf.direction)
			if q.x>=-radius-.035 and q.x<=float(leaf.width)+radius+.035 and absf(q.z)<=radius+.06: return true
	return false

func occupied(door: Dictionary,player: Node3D) -> bool:
	if is_instance_valid(player) and sweep_occupied(door,player.global_position,body_radius(player)): return true
	for enemy: Node in get_tree().get_nodes_in_group("extraction_hostiles"):
		if enemy is Node3D and enemy!=player and door.frame.global_position.distance_to(enemy.global_position)<6.0:
			if sweep_occupied(door,enemy.global_position,body_radius(enemy)): return true
	return false

func request_toggle(door: Dictionary,player: Node3D) -> bool:
	if not raid_active() or door.is_empty() or door.moving or player==null or nearest(player).get("id","")!=door.id: return false
	door.blocked = occupied(door,player)
	if door.blocked: return false
	door.actor = player
	door.start_angles = []
	for leaf: Dictionary in door.leaves:
		door.start_angles.append(leaf.body.rotation.y-leaf.base_yaw)
	door.elapsed = 0.0
	door.target_open = not door.opened
	door.moving = true
	return true

func _physics_process(delta: float) -> void:
	if not raid_active():
		fresh_release_required = true
		key_held = true
		return
	for door: Dictionary in doors:
		if not door.moving: continue
		door.blocked = occupied(door,door.actor)
		if door.blocked: continue
		door.elapsed = minf(DURATION,float(door.elapsed)+delta)
		var t: float = door.elapsed/DURATION
		var eased := t*t*(3.0-2.0*t)
		for index: int in range(door.leaves.size()):
			var leaf: Dictionary = door.leaves[index]
			leaf.body.rotation.y = leaf.base_yaw+lerpf(door.start_angles[index],leaf.open_angle if door.target_open else 0.0,eased)
		if door.elapsed>=DURATION:
			door.moving = false
			door.opened = door.target_open

func consume_interaction(player: Node3D,competing_distance: float,eligible: bool,pressed: bool) -> String:
	var just_pressed := pressed and not key_held
	key_held = pressed
	if not raid_active():
		fresh_release_required = true
		return ""
	if fresh_release_required:
		just_pressed = false
		if not pressed: fresh_release_required = false
	if not eligible: return ""
	var door := nearest(player)
	if door.is_empty() or competing_distance<interaction_distance(player): return ""
	door.blocked = occupied(door,player)
	if just_pressed: request_toggle(door,player)
	if door.moving: return "Door paused · step clear" if door.blocked else "Door opening" if door.target_open else "Door closing"
	if door.blocked: return "Step clear of the "+str(door.title)+" door"
	return "E  ·  "+("Close " if door.opened else "Open ")+str(door.title)

func blocks_route(from: Vector3,points: PackedVector3Array) -> bool:
	for door: Dictionary in doors:
		if door.opened and not door.moving: continue
		var a: Vector3 = door.frame.to_local(from)
		for point: Vector3 in points:
			var b: Vector3 = door.frame.to_local(point)
			if a.z*b.z<=0 and absf(b.z-a.z)>.0001:
				var crossing := a.lerp(b,-a.z/(b.z-a.z))
				if absf(crossing.x)<=float(door.width)*.5+.42 and crossing.y>-.5 and crossing.y<float(door.height): return true
			a = b
	return false
