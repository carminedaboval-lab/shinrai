extends StaticBody3D
## Origin: pane centre; wall/frame aperture is owned by architecture builder.
## A casement folds 180 degrees beside the opening. State lasts until session rebuild.
const REACH := 2.3
var dimensions := Vector3(1.2,1.5,.03)
var opened := false
var broken := false
var moving := false
var blocked := false
var health := 12.0
var title := "window"
var pane: MeshInstance3D
var pane_collision: CollisionShape3D
var can_open := true
var sash: Node3D
var _actor: Node3D
var _elapsed := 0.0
var _start := 0.0
var _goal := 0.0
var _closing := false
var _remnants: Node3D

func configure(pane_dimensions: Vector3, material: Material, openable := true, label := "window") -> void:
	assert(pane == null,"Window configured twice")
	dimensions = pane_dimensions
	can_open = openable
	title = label
	collision_layer = 1
	collision_mask = 0
	add_to_group("building_access_targets")
	set_meta("building_access_kind","window")
	sash = Node3D.new()
	sash.name = "HingedCasement"
	add_child(sash)
	sash.position.x = -dimensions.x*.5
	pane = _part(sash,"GlassPane",Vector3(dimensions.x*.5,0,0),dimensions,material)
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color("414b4b")
	trim.metallic = .55
	trim.roughness = .42
	var rail := .035
	for side: float in [-1,1]:
		_part(sash,"SashStile",Vector3(dimensions.x*(side+1)*.5,0,0),Vector3(rail,dimensions.y,.055),trim)
		_part(sash,"SashRail",Vector3(dimensions.x*.5,side*dimensions.y*.5,0),Vector3(dimensions.x,rail,.055),trim)
	_part(sash,"Latch",Vector3(dimensions.x-.07,0,-.045),Vector3(.025,.16,.025),trim)
	_remnants = Node3D.new()
	_remnants.name = "BrokenEdgeGlass"
	sash.add_child(_remnants)
	_remnants.visible = false
	# A few tiny edge remnants communicate broken glass without blocking traversal.
	for index: int in range(3):
		var shard := _part(_remnants,"EdgeRemnant",Vector3(.06+index*.08,-dimensions.y*.5+.025,0),Vector3(.055,.045,dimensions.z),material)
		shard.rotation.z = .23*float(index-1)
	pane_collision = CollisionShape3D.new()
	pane_collision.name = "PaneCollision"
	var shape := BoxShape3D.new()
	shape.size = dimensions
	pane_collision.shape = shape
	add_child(pane_collision)

func _part(parent: Node3D,label: String,at: Vector3,size: Vector3,material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh

func interaction_distance(actor: Node3D) -> float:
	if broken or not is_instance_valid(actor): return INF
	var from := actor.global_position+Vector3.UP
	var distance := from.distance_to(global_position)
	if distance > REACH: return INF
	var query := PhysicsRayQueryParameters3D.create(from,global_position,1)
	query.exclude = [get_rid()]
	if actor is CollisionObject3D: query.exclude.append(actor.get_rid())
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return INF
	return distance

func interaction_prompt(actor: Node3D) -> String:
	blocked = _sweep_occupied(actor)
	if moving: return "Window paused · step clear" if blocked else "Window moving"
	if can_open and blocked: return "Step clear of the window swing"
	return "E  ·  "+(("Close " if opened else "Open ") if can_open else "Smash ")+title

func interact(actor: Node3D) -> bool:
	if moving or interaction_distance(actor) == INF: return false
	if not can_open:
		take_damage(health,actor)
		return true
	blocked = _sweep_occupied(actor)
	if blocked: return false
	_actor = actor
	_closing = opened
	_start = sash.rotation.y
	_goal = 0.0 if _closing else -PI
	_elapsed = 0.0
	moving = true
	opened = true
	collision_layer = 0
	pane_collision.set_deferred("disabled",true)
	return true

func _sweep_occupied(actor: Node3D) -> bool:
	var actors: Array[Node] = []
	if is_instance_valid(actor): actors.append(actor)
	for group: String in ["shinrai_input_players","extraction_hostiles"]:
		for body: Node in get_tree().get_nodes_in_group(group):
			if not actors.has(body): actors.append(body)
	for body: Node in actors:
		if not body is Node3D: continue
		var point := to_local(body.global_position)
		if point.y > dimensions.y*.5+.05 or point.y+1.8 < -dimensions.y*.5: continue
		for step: int in range(37):
			var local := Basis(Vector3.UP,PI*float(step)/36.0)*(point-Vector3(-dimensions.x*.5,0,0))
			if local.x >= -.43 and local.x <= dimensions.x+.43 and absf(local.z) <= .47: return true
	return false

func _physics_process(delta: float) -> void:
	if not moving: return
	blocked = _sweep_occupied(_actor)
	if blocked: return
	_elapsed = minf(.6,_elapsed+delta)
	sash.rotation.y = lerpf(_start,_goal,smoothstep(0.0,1.0,_elapsed/.6))
	if _elapsed >= .6:
		moving = false
		if _closing:
			opened = false
			collision_layer = 1
			pane_collision.set_deferred("disabled",false)

func receive_bullet_hit(damage: float, source: Node, _position: Vector3, _direction: Vector3) -> bool:
	if opened or broken or damage <= 0.0: return false
	take_damage(damage,source)
	return true

func take_damage(amount: float, _source: Node = null) -> void:
	if opened or broken or amount <= 0.0: return
	health -= amount
	if health <= 0.0:
		broken = true
		collision_layer = 0
		pane_collision.set_deferred("disabled",true)
		pane.visible = false
		_remnants.visible = true
