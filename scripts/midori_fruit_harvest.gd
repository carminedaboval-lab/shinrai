extends RefCounted
const GameInput=preload("./shinrai_input.gd")
## Finite logical fruit, retained until the next raid. Never deletes plant meshes.
const Food = preload("./extraction_food_condition.gd")
const BackpackRules = preload("./extraction_backpack_state.gd")
const GROUP := "midori_harvestable_fruit"
# Proposed game balance, shared with extraction_metabolism.PROVISIONS.
const ITEMS := [
	{"id":"garden_mikan", "title":"Mikan mandarin", "value":4, "mass_kg":0.10,
		"description":"Mikan mandarin from the park's managed fruit garden. Check its condition before eating.", "world_spawn":false},
	{"id":"garden_persimmon", "title":"Kaki persimmon", "value":5, "mass_kg":0.18,
		"description":"Kaki persimmon from the park's managed fruit garden. Check its condition before eating.", "world_spawn":false}
]
const FRUIT_NAMES := {"garden_mikan":"mikan", "garden_persimmon":"persimmon"}
const REACH := 2.4
const AIM_DEGREES := 5.0
const LOS_MASK := 1
var fruits: Dictionary = {}
var run_token := ""
var _pick_was := false
var _eat_was := false
var _pick_edge := false
var _eat_edge := false
var _release_pending := true

static func spec(item_id: String) -> Dictionary:
	for item: Dictionary in ITEMS:
		if str(item.id) == item_id: return item.duplicate(true)
	return {}

func register_tree(root: Node) -> int:
	if not is_instance_valid(root) or not root.is_inside_tree(): return 0
	var added := 0
	for candidate: Node in root.get_tree().get_nodes_in_group(GROUP):
		if candidate != root and not root.is_ancestor_of(candidate): continue
		if not candidate is Node3D: continue
		var id := str(candidate.get_meta("fruit_id", ""))
		var item_id := str(candidate.get_meta("item_id", ""))
		if id.is_empty() or not FRUIT_NAMES.has(item_id): continue
		if fruits.has(id): continue
		fruits[id] = {"id":id, "node":candidate, "item_id":item_id, "harvested":false,
			"monitorable":candidate.monitorable if candidate is Area3D else false,"item":spec(item_id),"materials":[]}
		_capture_materials(fruits[id],candidate)
		added += 1
	return added

func begin_raid(token: String) -> void:
	# Reusing a token (pause/UI/re-entry) cannot respawn harvested fruit.
	if token.is_empty() or token == run_token: return
	run_token = token
	for id: String in fruits:
		var row: Dictionary = fruits[id]
		row.harvested = false
		row.item=spec(str(row.item_id))
		# A young managed crop is usually fresh; a few older fruit reward checking.
		var roll := int((token+":"+id).hash() % 100)
		var fraction := 1.02 if roll>=97 else .82 if roll>=88 else .40 if roll>=70 else .04
		if id==str(fruits.keys()[0]): fraction=.04
		Food.seed(row.item,fraction)
		_refresh_materials(row)
		var node := row.node as Node3D
		if not is_instance_valid(node): continue
		node.show()
		node.set_meta("harvested", false)
		if node is Area3D: node.set_deferred("monitorable", bool(row.monitorable))
	require_release()

func require_release() -> void:
	_release_pending = true
	_pick_edge = false
	_eat_edge = false

func sample_input() -> void:
	# Call even outside RAID: keys held across UI cannot become a fresh action.
	var pick := GameInput.down("interact")
	var eat := GameInput.down("eat")
	_pick_edge = not _release_pending and pick and not _pick_was
	_eat_edge = not _release_pending and eat and not _eat_was
	if _release_pending and not pick and not eat: _release_pending = false
	_pick_was = pick
	_eat_was = eat

func remaining_count() -> int:
	var count := 0
	for row: Dictionary in fruits.values():
		if not row.harvested and is_instance_valid(row.node): count += 1
	return count

func _eligible(raid: Node) -> bool:
	if not is_instance_valid(raid) or raid.phase != raid.Phase.RAID or run_token.is_empty(): return false
	var player = raid.player
	if not is_instance_valid(player) or not player.alive: return false
	if raid.inventory_open or raid.quit_confirmation_open or raid.deployment_pending: return false
	if not raid.pending_cache_id.is_empty() or not raid.pending_result_save.is_empty(): return false
	if raid.healing > 0.0 or player.healing_active or player.reloading: return false
	if player.weapon_input_locked or player.mantle_active or player.is_swimming or player.stun_remaining > 0.0: return false
	return raid.run_time - raid.last_damage_at > 0.8

func find_target(raid: Node) -> Dictionary:
	if not _eligible(raid): return {}
	var player = raid.player
	var camera: Camera3D = player.camera
	if not is_instance_valid(camera) or not camera.is_inside_tree(): return {}
	var eye := camera.global_position
	var forward := -camera.global_basis.z.normalized()
	var best: Dictionary = {}
	var best_alignment := cos(deg_to_rad(AIM_DEGREES))
	for id: String in fruits:
		var row: Dictionary = fruits[id]
		var node := row.node as Node3D
		if row.harvested or not is_instance_valid(node) or not node.is_visible_in_tree(): continue
		var offset := node.global_position - eye
		var distance := offset.length()
		if distance <= 0.01 or distance > REACH: continue
		var alignment := forward.dot(offset / distance)
		if alignment < best_alignment: continue
		# Solid geometry blocks reach. Query fruit areas never block each other.
		var ray := PhysicsRayQueryParameters3D.create(eye, node.global_position, LOS_MASK, [player.get_rid()])
		ray.collide_with_areas = false
		if not camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		best_alignment = alignment
		best = {"id":id, "node":node, "distance":distance, "item_id":str(row.item_id)}
	return best

func interact(raid: Node, target: Dictionary, eligible: bool = true) -> Dictionary:
	var result := {"prompt":"", "handled":false, "distance":float(target.get("distance", INF))}
	if target.is_empty() or not eligible or not _eligible(raid): return result
	var id := str(target.get("id", ""))
	if not fruits.has(id) or bool(fruits[id].harvested): return result
	var item_id := str(fruits[id].item_id)
	if not FRUIT_NAMES.has(item_id): return result
	var label := str(FRUIT_NAMES[item_id])
	var can_pick := _fits(raid, item_id)
	var record: Dictionary=fruits[id].item
	var can_eat: bool = raid.metabolism.can_consume_item(record)
	label=Food.label(record)+" "+label
	result.prompt=label+(" · POISONOUS" if float(Food.effects(record).sickness_seconds)>0.0 else "")
	result.prompt+=" · "+GameInput.hint("E")+" Pick"+(" [full]" if not can_pick else "")+" · "+GameInput.hint("F")+" Eat"+(" [vomit]" if raid.metabolism.nausea_remaining()>0.0 else " [full]" if not can_eat else "")
	# Simultaneous keys perform at most one transaction; E has priority.
	if _pick_edge:
		_pick_edge = false
		_eat_edge = false
		result.handled = try_pick(raid, id)
	elif _eat_edge:
		_eat_edge = false
		result.handled = try_eat(raid, id)
	return result

func _fits(raid: Node, item_id: String) -> bool:
	var item := spec(item_id)
	if item.is_empty(): return false
	var candidate: Array = raid.bag.duplicate(true)
	candidate.append(item)
	return BackpackRules.fits(raid.backpack_state, candidate, int(raid.profile.data.pack_level))

func _valid_target(raid: Node, id: String) -> bool:
	if not _eligible(raid) or not fruits.has(id) or bool(fruits[id].harvested): return false
	if not FRUIT_NAMES.has(str(fruits[id].item_id)): return false
	var target := find_target(raid)
	return not target.is_empty() and str(target.id) == id

func try_pick(raid: Node, fruit_id: String) -> bool:
	if not _valid_target(raid, fruit_id): return false
	var item_id := str(fruits[fruit_id].item_id)
	if not _fits(raid, item_id): return false
	# No node state changes until the actual slot AND mass transaction succeeds.
	raid.bag.append(fruits[fruit_id].item.duplicate(true))
	_claim(fruit_id)
	raid.player.set_cargo_mass(raid.cargo_mass_kg(), raid.cargo_limit_kg())
	raid.announce("Picked " + str(FRUIT_NAMES[item_id]), 2.0)
	return true

func try_eat(raid: Node, fruit_id: String) -> bool:
	if not _valid_target(raid, fruit_id): return false
	var item_id := str(fruits[fruit_id].item_id)
	var record: Dictionary=fruits[fruit_id].item
	if not raid.metabolism.can_consume_item(record): return false
	# The actual age travels through both direct and inventory eating.
	if not raid.consume_food_item(record): return false
	_claim(fruit_id)
	raid.announce_food_consumption(record)
	return true

func _claim(id: String) -> void:
	var row: Dictionary = fruits[id]
	row.harvested = true
	var node := row.node as Node3D
	if not is_instance_valid(node): return
	node.hide()
	node.set_meta("harvested", true)
	if node is Area3D: node.set_deferred("monitorable", false)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta<=0.0: return
	for row: Dictionary in fruits.values():
		if bool(row.harvested): continue
		var before := Food.state(row.item)
		Food.advance(row.item,delta,"world")
		if Food.state(row.item)!=before: _refresh_materials(row)

func _capture_materials(row: Dictionary, root: Node) -> void:
	if root is MeshInstance3D and root.mesh!=null:
		for surface: int in range(root.mesh.get_surface_count()):
			var source: Material=root.get_active_material(surface)
			if source is StandardMaterial3D:
				var unique := source.duplicate() as StandardMaterial3D
				root.set_surface_override_material(surface,unique)
				row.materials.append({"material":unique,"albedo":source.albedo_color})
	for child: Node in root.get_children(): _capture_materials(row,child)

func _refresh_materials(row: Dictionary) -> void:
	var condition := Food.state(row.item)
	var shade := Color.WHITE
	if condition=="stale": shade=Color(.92,.87,.72)
	elif condition=="spoiled": shade=Color(.59,.48,.32)
	elif condition=="rotten": shade=Color(.30,.31,.23)
	for surface: Dictionary in row.materials:
		surface.material.albedo_color=surface.albedo*shade
