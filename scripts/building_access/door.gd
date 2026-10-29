extends Node3D
## Origin: bottom centre of a real clear aperture. Local +X runs across doorway.
## configure once after parenting; caller supplies existing architecture material.
const REACH := 2.3
var size := Vector3(1.1, 2.1, .05)
var locked := false
var allow_inside_unlock := false
var glazing_material: Material = null
var opened := false
var moving := false
var blocked := false
var title := "door"
var leaf: AnimatableBody3D
var _elapsed := 0.0
var _start := 0.0
var _goal := 0.0
var _actor: Node3D
var open_angle := -PI * .5

func configure(dimensions: Vector3, material: Material, is_locked := false, label := "door") -> void:
	assert(leaf == null, "Door configured twice")
	size = dimensions
	locked = is_locked
	title = label
	add_to_group("building_access_targets")
	set_meta("building_access_kind", "door")
	leaf = AnimatableBody3D.new()
	leaf.name = "HingedLeaf"
	leaf.collision_layer = 1
	leaf.collision_mask = 0
	leaf.sync_to_physics = false
	add_child(leaf)
	leaf.position.x = -size.x * .5
	if glazing_material == null:
		_detail("SolidLeaf",Vector3(size.x*.5,size.y*.5,0),size,material)
	else:
		set_meta("building_access_glazed",true)
		# Physical timber/metal perimeter, with NO opaque backing behind the glass.
		for x: float in [.065,size.x-.065]:
			_detail("GlazedStile",Vector3(x,size.y*.5,0),Vector3(.13,size.y,size.z),material)
		for y: float in [.085,size.y-.085]:
			_detail("GlazedRail",Vector3(size.x*.5,y,0),Vector3(size.x-.26,.17,size.z),material)
		_detail("CentralGlass",Vector3(size.x*.5,size.y*.5,0),Vector3(size.x-.26,size.y-.34,minf(size.z,.018)),glazing_material)
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = size
	shape.shape = slab
	shape.position = Vector3(size.x*.5,size.y*.5,0)
	leaf.add_child(shape)
	# Framed panels and hardware are visual children of the SAME colliding leaf.
	# Builders replacing old leaves must remove the old closed decorative slab.
	var hardware := StandardMaterial3D.new()
	hardware.albedo_color = Color("687371")
	hardware.metallic = .8
	hardware.roughness = .3
	for face: float in [-1,1]:
		if glazing_material == null:
			var z := face*(size.z*.5+.008)
			for x: float in [.075,size.x-.075]:
				_detail("Stile",Vector3(x,size.y*.5,z),Vector3(.09,size.y-.10,.018),material)
			for y: float in [.10,size.y*.45,size.y-.10]:
				_detail("Rail",Vector3(size.x*.5,y,z),Vector3(size.x-.10,.08,.018),material)
			for y: float in [size.y*.25,size.y*.72]:
				_detail("InsetPanel",Vector3(size.x*.5,y,face*(size.z*.5+.002)),Vector3(size.x-.27,size.y*.31,.008),material)
		_detail("HandlePlate",Vector3(size.x-.13,1.0,face*(size.z*.5+.015)),Vector3(.045,.18,.018),hardware)
		_detail("HandleStand",Vector3(size.x-.13,1.02,face*(size.z*.5+.038)),Vector3(.025,.025,.05),hardware)
		_detail("LeverHandle",Vector3(size.x-.18,1.02,face*(size.z*.5+.065)),Vector3(.12,.025,.025),hardware)
	for y: float in [.25,size.y*.5,size.y-.25]:
		_detail("Hinge",Vector3(.015,y,0),Vector3(.03,.12,size.z+.025),hardware)

func interaction_distance(actor: Node3D) -> float:
	if not is_instance_valid(actor) or leaf == null: return INF
	var point := to_local(actor.global_position)
	if point.y < -.4 or point.y > size.y+.2: return INF
	var distance := Vector2(point.x, point.z).length()
	if distance > REACH: return INF
	var query := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP, to_global(Vector3(0,1,0)),1)
	query.exclude = [leaf.get_rid()]
	if actor is CollisionObject3D: query.exclude.append(actor.get_rid())
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return INF
	return distance

func interaction_prompt(actor: Node3D) -> String:
	if locked:
		if not _can_unlock_inside(actor): return "Door locked · find an upstairs window"
		if _sweep_occupied(actor): return "Step clear of the door swing"
		return "E  ·  Unlock and open from inside"
	blocked = _sweep_occupied(actor)
	if moving: return "Door paused · step clear" if blocked else "Door moving"
	if blocked: return "Step clear of the door swing"
	return "E  ·  "+("Close " if opened else "Open ")+title

func interact(actor: Node3D) -> bool:
	if moving or interaction_distance(actor) == INF: return false
	if locked and not _can_unlock_inside(actor): return false
	blocked = _sweep_occupied(actor)
	if blocked: return false
	locked = false
	_actor = actor
	_start = leaf.rotation.y
	_goal = 0.0 if opened else open_angle
	_elapsed = 0.0
	moving = true
	return true

func _sweep_occupied(actor: Node3D) -> bool:
	var actors: Array[Node] = []
	if is_instance_valid(actor): actors.append(actor)
	for group: String in ["shinrai_input_players", "extraction_hostiles"]:
		for body: Node in get_tree().get_nodes_in_group(group):
			if not actors.has(body): actors.append(body)
	for body: Node in actors:
		if not body is Node3D: continue
		var point := to_local(body.global_position)
		if point.y > size.y+.1 or point.y+1.8 < 0: continue
		# Conservative complete swept leaf, including the standing capsule radius.
		for step: int in range(25):
			var angle := open_angle*float(step)/24.0
			var local := Basis(Vector3.UP,-angle)*(point-leaf.position)
			if local.x >= -.43 and local.x <= size.x+.43 and absf(local.z) <= .43+size.z*.5: return true
	return false

func _physics_process(delta: float) -> void:
	if not moving: return
	blocked = _sweep_occupied(_actor)
	if blocked: return
	_elapsed = minf(.75,_elapsed+delta)
	var t := smoothstep(0.0,1.0,_elapsed/.75)
	leaf.rotation.y = lerpf(_start,_goal,t)
	if _elapsed >= .75:
		moving = false
		opened = not opened

func _detail(label: String,at: Vector3,dimensions: Vector3,material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	leaf.add_child(mesh)

func _can_unlock_inside(actor: Node3D) -> bool:
	return allow_inside_unlock and is_instance_valid(actor) and interaction_distance(actor) < INF and to_local(actor.global_position).z > .15

