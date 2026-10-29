extends Node3D
## Adopts Haku's finished sliding geometry BEFORE south-street batching.
const REACH := 2.3
var opened := false
var moving := false
var blocked := false
var leaves: Array[AnimatableBody3D] = []
var adopted_meshes := 0
var _elapsed := 0.0
var _start := 0.0
var _goal := 0.0
var _actor: Node3D

static func install(street: Node3D) -> Dictionary:
	var gallery := street.get_node_or_null("CeramicsGallery")
	if gallery == null: return {"ok":false,"reason":"gallery_missing"}
	var existing := gallery.get_node_or_null("FunctionalGallerySlidingDoors")
	if existing != null: return {"ok":true,"service":existing,"adopted_meshes":existing.adopted_meshes}
	var exterior := gallery.get_node_or_null("CeramicsGalleryExterior") as Node3D
	var room := gallery.get_node_or_null("InteriorGalleryRoom") as Node3D
	if exterior == null or room == null: return {"ok":false,"reason":"gallery_groups_missing"}
	var service := load("res://scripts/building_access/gallery_sliding.gd").new() as Node3D
	service.name = "FunctionalGallerySlidingDoors"
	gallery.add_child(service)
	var ok: bool = service.configure(exterior,room)
	if not ok:
		service.queue_free()
		return {"ok":false,"reason":"original_sliding_geometry_missing_or_already_batched"}
	return {"ok":true,"service":service,"adopted_meshes":service.adopted_meshes,"clear_width":1.8,"closed_centres":[-.45,.45],"parked_centres":[-1.61,1.61]}

func configure(exterior: Node3D, room: Node3D) -> bool:
	assert(leaves.is_empty(),"Gallery sliding doors configured twice")
	var selections: Array[Array] = [[],[]]
	# Match source parent + exact authored position/box dimensions, not unstable names.
	for parent: Node3D in [exterior,room]:
		for child: Node in parent.get_children():
			if not child is MeshInstance3D or child.mesh == null: continue
			var p: Vector3 = child.position
			var size: Vector3 = child.mesh.get_aabb().size
			var match_part := false
			if parent == exterior:
				match_part = (_near(absf(p.x),1.18) or _near(absf(p.x),2.04)) and _near(p.y,1.2) and _near(p.z,.29) and size.is_equal_approx(Vector3(.05,2.36,.055))
				match_part = match_part or (_near(absf(p.x),1.61) and (_near(p.y,.045) or _near(p.y,2.355)) and _near(p.z,.29) and size.is_equal_approx(Vector3(.91,.05,.055)))
				match_part = match_part or (_near(absf(p.x),1.22) and _near(p.y,1.14) and _near(p.z,.25) and size.is_equal_approx(Vector3(.016,.27,.035)))
			else:
				match_part = _near(absf(p.x),1.61) and _near(p.y,1.2) and _near(p.z,.29) and size.is_equal_approx(Vector3(.81,2.26,.008))
			if match_part: selections[0 if p.x < 0.0 else 1].append(child)
	if selections[0].size() != 6 or selections[1].size() != 6: return false
	for index: int in range(2):
		var side := -1.0 if index == 0 else 1.0
		var body := AnimatableBody3D.new()
		body.name = "LeftOriginalSlidingLeaf" if index == 0 else "RightOriginalSlidingLeaf"
		body.collision_layer = 1
		body.collision_mask = 0
		body.sync_to_physics = false
		add_child(body)
		body.position = Vector3(side*1.61,1.2,.29)
		for mesh: MeshInstance3D in selections[index]:
			mesh.reparent(body,true)
			adopted_meshes += 1
		var collision := CollisionShape3D.new()
		collision.name = "SlidingLeafCollision"
		var shape := BoxShape3D.new()
		shape.size = Vector3(.91,2.36,.055)
		collision.shape = shape
		body.add_child(collision)
		body.position.x = side*.45
		leaves.append(body)
	add_to_group("building_access_targets")
	set_meta("building_access_kind","gallery_sliding")
	set_meta("building_access_adopted_meshes",adopted_meshes)
	set_meta("creator_protected",true)
	return true

func _near(a: float,b: float) -> bool:
	return absf(a-b) < .001

func interaction_distance(actor: Node3D) -> float:
	if not is_instance_valid(actor) or leaves.size() != 2: return INF
	var p := to_local(actor.global_position)
	if p.y < -.4 or p.y > 2.6 or absf(p.x)>1.15: return INF
	var distance := Vector2(p.x,p.z-.29).length()
	if distance>REACH: return INF
	var query := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP,to_global(Vector3(0,1.1,.29)),1)
	query.exclude = [leaves[0].get_rid(),leaves[1].get_rid()]
	if actor is CollisionObject3D: query.exclude.append(actor.get_rid())
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return INF
	return distance

func interaction_prompt(actor: Node3D) -> String:
	blocked = _occupied(actor)
	if moving: return "Sliding doors paused · step clear" if blocked else "Sliding doors moving"
	if blocked: return "Step clear of the sliding doors"
	return "E  ·  "+("Close" if opened else "Open")+" gallery doors"

func interact(actor: Node3D) -> bool:
	if moving or interaction_distance(actor)==INF: return false
	blocked = _occupied(actor)
	if blocked: return false
	_actor = actor
	_elapsed = 0.0
	_start = absf(leaves[0].position.x)
	_goal = .45 if opened else 1.61
	moving = true
	return true

func _occupied(actor: Node3D) -> bool:
	var actors: Array[Node] = []
	if is_instance_valid(actor): actors.append(actor)
	for group: String in ["shinrai_input_players","extraction_hostiles"]:
		for body: Node in get_tree().get_nodes_in_group(group):
			if not actors.has(body): actors.append(body)
	for body: Node in actors:
		if not body is Node3D: continue
		var p := to_local(body.global_position)
		if p.y>2.43 or p.y+1.8<.02: continue
		# Whole swept band plus capsule radius: guards both leaves at every step.
		if absf(p.x)<2.51 and absf(p.z-.29)<.48: return true
	return false

func _physics_process(delta: float) -> void:
	if not moving: return
	blocked = _occupied(_actor)
	if blocked: return
	_elapsed = minf(.75,_elapsed+delta)
	var centre := lerpf(_start,_goal,smoothstep(0.0,1.0,_elapsed/.75))
	leaves[0].position.x = -centre
	leaves[1].position.x = centre
	if _elapsed>=.75:
		moving = false
		opened = not opened

