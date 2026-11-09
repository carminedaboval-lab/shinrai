extends RefCounted
## Hides low planting (spiky fountain grass, WoodlandFillLOD beds, shoulder and
## sparse-understory fountain grass, park-floor grass, lawn blades) everywhere it
## is actually drawn after boot, not only in the producer's own nodes.
##
## FINDINGS (why Kit.thin_multimeshes on WoodlandFillLOD0_* changed nothing):
##  1. scripts/midori_distance_detail.gd (run by midori_distance_boot before the
##     biomes) COPIES every visible MultiMeshInstance3D whose node PATH reads as
##     grass / flowers / other planting (category(): "grass", "woodlandfilllod",
##     "woodland", "fern", "lilac", "plantedbed", "sparseunderstory", "iris",
##     "azalea", "japaneseflowers") into park/MidoriDistanceDetail as 12 m cell
##     chunks named "grass_Cell_N", "flowers_Cell_N", "other_planting_Cell_N",
##     then HIDES the sources. The copies share the source Mesh resource (same
##     identity) but get fresh MultiMesh resources with world transforms
##     re-based to the cell centre. Chunks merge every source with the same
##     mesh + material + ranges, so one chunk can hold WoodlandFillLOD,
##     JapaneseForestGrassDrift, ParkFloor and SparseUnderstory instances
##     together. All three WoodlandFillLOD0/1/2 levels are copied (the far LODs
##     keep their range begin). Editing the hidden sources therefore does not
##     change the picture; the chunk names never contain "woodlandfill" or
##     "fountain", so a name filter misses them.
##     Sources it skips stay the drawn copy: nodes with a script or a
##     visibility_parent, and paths that do not read as planting, e.g.
##     MidoriPathShoulders/Shoulder_* (category "other").
##  2. scripts/midori_near_plant_shadows.gd (MidoriNearPlantShadows, installed
##     by midori_render_budget) draws shadow proxies ("PooledPlantShadow") that
##     SHARE the chunk's MultiMesh resource, so collapsing a chunk instance also
##     hides its shadow. It caches each chunk's world AABB and on any mismatch
##     permanently drops its soft fade (_invalidate_soft). Its documented
##     protocol before_source_change()/after_source_change() re-captures the
##     chunks, so it is called here after editing (synchronously, no frame in
##     between). If it is not installed yet it captures the edited chunks later.
##  3. scripts/midori_draw_distance.gd and midori_reflection_content.gd only set
##     visibility ranges / render layers on existing nodes; no copies.
##  4. MidoriGrassDetail (autoload at /root, builds park/MidoriGrassDetail:
##     UprightGrass_*, ThinUprightGrass_*, JapaneseForestGrassDrift_*,
##     ForestGrassLOD1/2_*, MeshyGroundClumps) is a source like any other and is
##     itself copied by (1). Its node_added hook returns early once installed
##     (_installed_scene_id), so it does not rebuild later.
##  5. No producer creates RenderingServer-level multimeshes or instances
##     (no multimesh_create / instance_create in scripts/), no planting is merged
##     into chunked ArrayMeshes, and no runtime script rewrites planting buffers
##     after boot (all instance_count / buffer writers run during boot). The
##     Creator registry clones MultiMeshes only when an object is edited and
##     copies the current (collapsed) transforms.
##  6. The park also places single plants as MeshInstance3D scenes (for example
##     MainlandEmeraldGrassClusters/EmeraldFountainGrass_###, fern and bush
##     pockets from midori_park_size_blockout). Those are drawn natively, never
##     copied, and are handled here by hiding the matching MeshInstance3D.
##  7. Producers that duplicate prototype meshes (path shoulders, sparse
##     understory, park floor, woodland diversity) keep the prototype's
##     resource_name and bounds, so those meshes are tagged with the prototype
##     they came from (for example "emerald_fountain_grass") and the filter can
##     match them even when the node name is only "Shoulder_2_..".
##
## HOW: every MultiMeshInstance3D under the park (except Biome* roots and the
## shadow proxies) is a candidate. Non-copy nodes are grouped by parent, name
## family, transform and count, and checked to stand on the same spots: sibling
## part batches of one plant share index order, so the whole plant hides or
## stays together. A group is hidden where filter_label matches any member and
## keep(world xz) is false; every hidden instance's world position is recorded
## per part. Distance-detail chunks (and any other node drawing a matched mesh)
## then collapse exactly the instances at recorded positions, so shared chunks
## lose only the matched plants. Only a chunk whose mesh has NO source node left
## in the park is thinned by its own label + keep() (re-deciding chunks of known
## sources per part origin would split multi-part plants). Hiding collapses the
## basis to 1e-5 in place via the MultiMesh buffer (origin kept), the same
## convention as Kit.thin_multimeshes.
## Single-plant MeshInstance3D nodes are hidden with visible = false, whole
## plants at a time, never when the plant carries a collision body.
##
## Labels passed to filter_label:
##   MultiMesh source:   "<node name> <mesh resource_name>[ | <prototype tag>]"
##   distance chunk:     "<mesh resource_name>[ | <prototype tag>]" (a
##                       "grass_Cell" name says nothing about the plant)
##   MeshInstance3D:     "<node name> <mesh resource_name>[ | <tag>] @ <plant>"
##                       where <plant> is the chain of numbered ancestors from
##                       the placed plant root down ("EmeraldFountainGrass_003"
##                       or "EmeraldFountainGrass_003/Object_2"). A plant hides
##                       whole when any part's label matches.
## Synchronous: no awaits, no per-frame work. Calling it several times is safe
## (already collapsed instances are skipped, but their positions still feed the
## copy matching).

const Kit := preload("res://scripts/biomes/biome_kit.gd")
const HIDE_SCALE := 0.00001
const COLLAPSED := 0.0001
const MATCH_PER_M := 50.0 # 2 cm position cells for source -> copy matching
const MATCH_EDGE := 0.05
const SAME_PLANT_M := 2.5 # sibling part batches must stand within this of each other
const SINGLE_PLANT_MAX_M := 8.0 # MeshInstance3D wider than this is not a low plant
const PLANT_ROOT_REACH_M := 3.0 # a plant root stands within this of its mesh parts
const FLAT_M := 0.02 # a root-less mesh flatter than this is ground, not a plant
const PROTOTYPE_SINGLES := ["emerald_fountain_grass_prototype", "midnight_fern_prototype", "hollow_bark_prototype", "deadwood_trunk_prototype", "japanese_maple_prototype"]
const PROTOTYPE_LISTS := ["dense_grass_prototypes", "forest_floor_bush_prototypes", "lilac_prototypes"]

## Optional `area` (world xz) skips nodes and instances outside it, purely for
## speed; keep() is still the only judge inside it.
##
## `keep_pure` (optional): the caller vouches that keep() is pure maths (reads
## constants, packed arrays, the shared noise and terrain data only, writes
## nothing). Then keep() over the matched groups' instances runs on
## WorkerThreadPool (one task per group), as does the copy matching (always
## pure when the copy uses no keep()); every instance gets the same answer and
## the buffers are edited here, in the original order.
static func hide_low_planting(park: Node3D, filter_label: Callable, keep: Callable, area: Rect2 = Rect2(), keep_pure: bool = false) -> Dictionary:
	var started := Time.get_ticks_msec()
	if park == null or not is_instance_valid(park):
		return {"error": "park unavailable"}
	_scan(park)
	var tags := _prototype_tags(park)
	var container: Node = park.get_node_or_null("MidoriDistanceDetail")
	var nodes: Array[MultiMeshInstance3D] = []
	# Meshes that still have a producer (source) node anywhere in the park. A
	# chunk drawing such a mesh is decided by its sources' labels and positions
	# only; its own label is a fallback for meshes whose sources are gone.
	# (_scan: every candidate MultiMeshInstance3D in tree order, its bounds and
	# the source meshes, from one walk per builder.)
	var source_meshes: Dictionary = _source_meshes
	for i: int in range(_mmi_nodes.size()):
		if area.has_area() and not area.intersects(_mmi_rects[i]): continue
		nodes.append(_mmi_nodes[i])
	# Group sibling part batches of the same plants (non-copies only).
	var groups: Dictionary = {}
	var order: Array[String] = []
	var copies: Array[MultiMeshInstance3D] = []
	for node: MultiMeshInstance3D in nodes:
		if container != null and node.get_parent() == container:
			copies.append(node)
			continue
		var key := _group_key(node)
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		var placed := false
		for sub: Variant in groups[key]:
			var members: Array = sub
			if _same_spots(members[0], node):
				members.append(node)
				placed = true
				break
		if not placed:
			(groups[key] as Array).append([node])
	var by_owner: Dictionary = {}
	var target_meshes: Dictionary = {}
	var hidden_at: Dictionary = {}
	var hidden_box := Rect2()
	var done: Dictionary = {}
	var source_hidden := 0
	var groups_matched := 0
	var changed_nodes := 0
	# Pass 1: matched groups in their producers' nodes (visible or hidden).
	# The masks only read each leader's instance origins, which hiding never
	# moves (it scales the basis), so they are all worked out before any group
	# is edited (on WorkerThreadPool for a pure keep); the groups are then
	# edited one by one in the original order.
	var matched_groups: Array = []
	for key: String in order:
		for sub: Variant in groups[key]:
			var members: Array = sub
			for member: MultiMeshInstance3D in members:
				if filter_label.call(_label(member, false, tags)):
					matched_groups.append(members)
					break
	groups_matched = matched_groups.size()
	var masks := _group_masks(matched_groups, keep, area, keep_pure)
	for group_index: int in range(matched_groups.size()):
		var members: Array = matched_groups[group_index]
		var mask: PackedByteArray = masks[group_index]
		for member: MultiMeshInstance3D in members:
			target_meshes[member.multimesh.mesh.get_instance_id()] = true
			var mm_id := member.multimesh.get_instance_id()
			if done.has(mm_id): continue
			done[mm_id] = true
			var result := _apply_mask(member, mask, hidden_at, hidden_box)
			hidden_box = result[1]
			var n: int = result[0]
			if n > 0:
				source_hidden += n
				changed_nodes += 1
				member.set_meta("biome_thinned", true)
				var owner := _owner_name(park, member)
				by_owner[owner] = int(by_owner.get(owner, 0)) + n
	var search_box := hidden_box.grow(0.1) if hidden_at.size() > 0 else Rect2()
	# Pass 2: render copies. Distance-detail chunks first, then any other node
	# that draws a matched mesh (positions only, so unrelated plants stay).
	# Which nodes are edited depends only on pass 1 (labels, matched meshes, the
	# search box, bounds of nodes not yet edited), so the list is made first;
	# then every node's verdicts are worked out (WorkerThreadPool where keep()
	# is pure or unused) and the nodes are edited in list order.
	var copy_hidden := 0
	var copy_label_hidden := 0
	var other_hidden := 0
	var chunks_changed := 0
	var work: Array = [] # [node, hidden_at or {}, keep or Callable(), is chunk copy]
	for node: MultiMeshInstance3D in copies:
		var mm_id := node.multimesh.get_instance_id()
		if done.has(mm_id): continue
		var mesh_id := node.multimesh.mesh.get_instance_id()
		# Re-deciding a chunk by keep() at each part's own (offset) origin would
		# split multi-part plants whose sources pass 1 kept, and a label without
		# the node name can classify differently from the source's label.
		var by_label: bool = not source_meshes.has(mesh_id) and bool(filter_label.call(_label(node, true, tags)))
		var by_mesh := target_meshes.has(mesh_id)
		if by_mesh and not by_label and not (search_box.has_area() and search_box.intersects(_mmi_rect_of(node))): continue
		if not by_label and not by_mesh: continue
		done[mm_id] = true
		work.append([node, hidden_at if by_mesh else {}, keep if by_label else Callable(), true])
	for node: MultiMeshInstance3D in nodes:
		var mm_id := node.multimesh.get_instance_id()
		if done.has(mm_id): continue
		if not target_meshes.has(node.multimesh.mesh.get_instance_id()): continue
		if not (search_box.has_area() and search_box.intersects(_mmi_rect_of(node))): continue
		done[mm_id] = true
		work.append([node, hidden_at, Callable(), false])
	var results := _hide_copies(work, area, keep_pure)
	for work_index: int in range(work.size()):
		var node: MultiMeshInstance3D = work[work_index][0]
		var result: Vector2i = results[work_index]
		if work[work_index][3]:
			if result.x + result.y > 0:
				copy_hidden += result.x
				copy_label_hidden += result.y
				changed_nodes += 1
				chunks_changed += 1
				node.set_meta("biome_thinned", true)
		elif result.x > 0:
			other_hidden += result.x
			changed_nodes += 1
			node.set_meta("biome_thinned", true)
			var owner := _owner_name(park, node)
			by_owner[owner] = int(by_owner.get(owner, 0)) + result.x
	# Pass 3: single plants placed as MeshInstance3D scenes.
	var singles := _hide_single_plants(park, filter_label, keep, area, tags, by_owner)
	# Shadow proxies share the chunk MultiMesh; re-capture their cached bounds
	# so the soft shadow fade stays valid instead of failing permanently. Its
	# rows are only the distance-detail chunks, so recapture (a full fingerprint
	# pass) only when a chunk changed.
	var recaptured := false
	var shadows: Node = park.get_node_or_null("MidoriNearPlantShadows")
	if chunks_changed > 0 and shadows != null and shadows.has_method("before_source_change") and shadows.has_method("after_source_change"):
		shadows.before_source_change()
		shadows.after_source_change()
		recaptured = true
	return {
		"source_nodes": source_hidden,
		"distance_detail_copies": copy_hidden + copy_label_hidden,
		"distance_detail_by_position": copy_hidden,
		"distance_detail_by_label": copy_label_hidden,
		"other_copies": other_hidden,
		"mesh_instances": singles,
		"by_owner": by_owner,
		"groups_matched": groups_matched,
		"nodes_changed": changed_nodes,
		"target_meshes": target_meshes.size(),
		"recorded_positions": hidden_at.size(),
		"shadow_proxies": "share chunk MultiMesh",
		"shadow_recapture": recaptured,
		"rendering_server_instances": 0,
		"ms": Time.get_ticks_msec() - started,
	}

# ------------------------------------------------------------ scene scan cache
## Every call used to walk the whole park twice (about 26,000
## MultiMeshInstance3D and 19,000 MeshInstance3D, with an ancestor walk and a
## RenderingServer bounds read per node), and a builder's thin pass calls this
## several times in a row (pine woods 8, moss garden and shrine 4, iris shore 2).
## Within one builder's pass nothing but these calls touches the planting, so
## one walk serves them all: midori_biomes calls forget() before every builder,
## and a changed SceneTree node count (a node added or freed) walks again.
## Kept per walk: the candidate MultiMeshInstance3D (in the park, not under a
## Biome* root or the shadow proxies, with a 3D-transform MultiMesh, a mesh and
## instances) in tree order with their bounds and copy/source role; every
## MeshInstance3D with a mesh in tree order with its bounds; owner/prototype
## tests, plant roots, collision, mesh keys and group keys on first use. Bounds
## of a MultiMesh this file rewrites are re-read at once (_touched); visibility
## and buffers are read fresh on every call. Same result as a fresh walk.
static var _scan_park := 0
static var _scan_count := -1
static var _mmi_nodes: Array[MultiMeshInstance3D] = []
static var _mmi_rects: Array[Rect2] = []
static var _mmi_index: Dictionary = {} # node id -> row
static var _rows_of_mm: Dictionary = {} # MultiMesh id -> [row, ...]
static var _source_meshes: Dictionary = {} # mesh id -> true (non-copy candidates)
static var _mesh_nodes: Array[MeshInstance3D] = []
static var _mesh_rects: Array[Rect2] = []
static var _mesh_boxes: Array[AABB] = []
static var _mesh_skip: PackedInt32Array = PackedInt32Array() # -1 unknown, 0 keep, 1 skip
static var _mesh_chain: Array = [] # _plant_root result or null
static var _collision_of: Dictionary = {} # plant (or lone mesh) id -> bool
static var _group_keys: Dictionary = {} # node id -> key
static var _mesh_keys: Dictionary = {} # Mesh id -> [surface count, key]

## midori_biomes: true around each builder (a fresh walk at its first call, then
## shared by its later calls). Off (the default, any other caller), every call
## walks the park itself, as before.
static var _batching := false
static func batch(on: bool) -> void:
	forget()
	_batching = on

## The walk itself (which MultiMeshInstance3D and MeshInstance3D nodes, in
## tree order) is kept across builders while midori_biomes tracks the park:
## every node that enters or leaves the tree outside the Biome* roots and the
## shadow proxies drops it (SceneTree.node_added / node_removed). The per-node
## data (bounds, multimesh, mesh, counts) is read again by every scan.
static var _tracking := 0
static var _track_park: WeakRef = null
static var _walk_valid := false
static var _walk_park := 0
static var _walk_mmi: Array[Node] = []
static var _walk_mesh: Array[Node] = []

static func track(park: Node3D, on: bool) -> void:
	_walk_valid = false
	_walk_mmi = []
	_walk_mesh = []
	var tree := Engine.get_main_loop() as SceneTree
	if on and tree != null and is_instance_valid(park) and park.is_inside_tree():
		_tracking = park.get_instance_id()
		_track_park = weakref(park)
		if not tree.node_added.is_connected(_on_tree_changed): tree.node_added.connect(_on_tree_changed)
		if not tree.node_removed.is_connected(_on_tree_changed): tree.node_removed.connect(_on_tree_changed)
	else:
		_tracking = 0
		_track_park = null
		if tree != null:
			if tree.node_added.is_connected(_on_tree_changed): tree.node_added.disconnect(_on_tree_changed)
			if tree.node_removed.is_connected(_on_tree_changed): tree.node_removed.disconnect(_on_tree_changed)

static func _on_tree_changed(node: Node) -> void:
	if not _walk_valid: return
	var park: Node = _track_park.get_ref() if _track_park != null else null
	if park == null:
		_walk_valid = false
		return
	if node == park:
		_walk_valid = false
		return
	if not park.is_ancestor_of(node): return
	var at: Node = node
	while at.get_parent() != park: at = at.get_parent()
	var top := String(at.name)
	if top.begins_with("Biome") or top == "MidoriNearPlantShadows": return
	_walk_valid = false

## Drops every cached walk (the next call walks the park again).
static func forget() -> void:
	_scan_park = 0
	_scan_count = -1
	_mmi_nodes = []
	_mmi_rects = []
	_mmi_index = {}
	_rows_of_mm = {}
	_source_meshes = {}
	_mesh_nodes = []
	_mesh_rects = []
	_mesh_boxes = []
	_mesh_skip = PackedInt32Array()
	_mesh_chain = []
	_collision_of = {}
	_group_keys = {}
	_mesh_keys = {}

static func _scan(park: Node3D) -> void:
	var count := park.get_tree().get_node_count()
	if _batching and _scan_park == park.get_instance_id() and _scan_count == count: return
	forget()
	_scan_park = park.get_instance_id()
	_scan_count = count
	var container: Node = park.get_node_or_null("MidoriDistanceDetail")
	# The park's top-level branches minus the Biome* roots and the shadow
	# proxies (what _excluded() rejects), each walked the way
	# park.find_children() walks (the node, then its subtree, pre-order, internal
	# children included): the same nodes in the same order, with no ancestor walk
	# per node. Meshes under excluded roots were always skipped before any use.
	var _found: Array[Node] = []
	var _found2: Array[Node] = []
	if _walk_valid and _walk_park == park.get_instance_id():
		# No node outside the Biome* roots and the shadow proxies entered or left
		# the tree since this walk (see track()): the same nodes, the same order.
		_found = _walk_mmi
		_found2 = _walk_mesh
	else:
		for top: Node in park.get_children(true):
			var top_name := String(top.name)
			if top_name.begins_with("Biome") or top_name == "MidoriNearPlantShadows": continue
			if top is MultiMeshInstance3D: _found.append(top)
			_found.append_array(top.find_children("*", "MultiMeshInstance3D", true, false))
			if top is MeshInstance3D: _found2.append(top)
			_found2.append_array(top.find_children("*", "MeshInstance3D", true, false))
		if _tracking == park.get_instance_id():
			_walk_mmi = _found
			_walk_mesh = _found2
			_walk_park = park.get_instance_id()
			_walk_valid = true
	for found: Node in _found:
		var node := found as MultiMeshInstance3D
		if node == null or node.multimesh == null or node.multimesh.mesh == null: continue
		if node.multimesh.transform_format != MultiMesh.TRANSFORM_3D or node.multimesh.instance_count == 0: continue
		if container == null or node.get_parent() != container:
			_source_meshes[node.multimesh.mesh.get_instance_id()] = true
		var row := _mmi_nodes.size()
		_mmi_nodes.append(node)
		_mmi_rects.append(_flat_box(node))
		_mmi_index[node.get_instance_id()] = row
		var mm_id := node.multimesh.get_instance_id()
		if not _rows_of_mm.has(mm_id): _rows_of_mm[mm_id] = []
		(_rows_of_mm[mm_id] as Array).append(row)
	for found: Node in _found2:
		var node := found as MeshInstance3D
		if node == null or node.mesh == null: continue
		var box: AABB = node.global_transform * node.mesh.get_aabb()
		_mesh_nodes.append(node)
		_mesh_boxes.append(box)
		_mesh_rects.append(Rect2(box.position.x, box.position.z, maxf(box.size.x, 0.01), maxf(box.size.z, 0.01)))
		_mesh_chain.append(null)
	_mesh_skip.resize(_mesh_nodes.size())
	_mesh_skip.fill(-1)

## This file rewrote `mm`'s buffer: its bounds (and so the area tests) change.
static func _touched(mm: MultiMesh) -> void:
	for row: int in _rows_of_mm.get(mm.get_instance_id(), []):
		_mmi_rects[row] = _flat_box(_mmi_nodes[row])

static func _mmi_rect_of(node: MultiMeshInstance3D) -> Rect2:
	return _mmi_rects[int(_mmi_index[node.get_instance_id()])]

static func _group_key(node: MultiMeshInstance3D) -> String:
	var id := node.get_instance_id()
	if _group_keys.has(id): return _group_keys[id]
	var key := "%d|%s|%s|%d" % [node.get_parent().get_instance_id(), _family(String(node.name)), str(node.transform), node.multimesh.instance_count]
	_group_keys[id] = key
	return key

## Biome roots hold the new planting; shadow proxies share chunk data.
static func _excluded(park: Node3D, node: Node) -> bool:
	var at: Node = node
	while at != null and at.get_parent() != park:
		at = at.get_parent()
	if at == null: return true
	var top := String(at.name)
	return top.begins_with("Biome") or top == "MidoriNearPlantShadows"

static func _owner_name(park: Node3D, node: Node) -> String:
	var at: Node = node
	while at != null and at.get_parent() != park:
		at = at.get_parent()
	return String(at.name) if at != null else "?"

static func _flat_box(node: GeometryInstance3D) -> Rect2:
	var local := AABB()
	if node is MultiMeshInstance3D: local = (node as MultiMeshInstance3D).multimesh.get_aabb()
	elif node is MeshInstance3D: local = (node as MeshInstance3D).mesh.get_aabb()
	var box: AABB = node.global_transform * local
	return Rect2(box.position.x, box.position.z, maxf(box.size.x, 0.01), maxf(box.size.z, 0.01))

## Node name without its trailing serial ("Shoulder_2_3_-4_17" -> "Shoulder_2_3_-4").
static func _family(node_name: String) -> String:
	var base := node_name
	var at_sign := base.find("@")
	if at_sign >= 0: base = base.left(at_sign)
	var cut := base.rfind("_")
	if cut > 0 and base.substr(cut + 1).is_valid_int(): base = base.left(cut)
	return base

## Two batches of one key are parts of the same plants only if their instances
## stand on the same spots (first, middle, last instance).
static func _same_spots(a: MultiMeshInstance3D, b: MultiMeshInstance3D) -> bool:
	var count := a.multimesh.instance_count
	if count != b.multimesh.instance_count: return false
	for i: int in [0, count / 2, count - 1]:
		var pa: Vector3 = a.global_transform * a.multimesh.get_instance_transform(i).origin
		var pb: Vector3 = b.global_transform * b.multimesh.get_instance_transform(i).origin
		if Vector2(pa.x - pb.x, pa.z - pb.z).length() > SAME_PLANT_M: return false
	return true

static func _mesh_key(mesh: Mesh) -> String:
	var id := mesh.get_instance_id()
	var surfaces := mesh.get_surface_count()
	var hit: Variant = _mesh_keys.get(id)
	if hit != null and int(hit[0]) == surfaces: return hit[1]
	var key := "%s|%d|%s" % [mesh.resource_name, surfaces, str(mesh.get_aabb())]
	_mesh_keys[id] = [surfaces, key]
	return key

## Mesh signatures of the park's planting prototypes -> readable tag.
static func _prototype_tags(park: Node3D) -> Dictionary:
	var tags: Dictionary = {}
	var sources: Array = []
	for property: String in PROTOTYPE_SINGLES:
		var proto: Variant = park.get(property)
		if _live_node(proto): sources.append([property.trim_suffix("_prototype"), proto])
	for property: String in PROTOTYPE_LISTS:
		var list: Variant = park.get(property)
		if list is Array:
			for proto: Variant in list:
				if _live_node(proto): sources.append([property.trim_suffix("_prototypes"), proto])
	for row: Array in sources:
		var proto: Node = row[1]
		for part: Node in proto.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (part as MeshInstance3D).mesh
			if mesh == null: continue
			var key := _mesh_key(mesh)
			if not tags.has(key): tags[key] = String(row[0])
	return tags

## The park's prototype nodes themselves (never hidden).
static func _prototype_nodes(park: Node3D) -> Dictionary:
	var ids: Dictionary = {}
	for property: String in PROTOTYPE_SINGLES:
		var proto: Variant = park.get(property)
		if _live_node(proto): ids[(proto as Node).get_instance_id()] = true
	for property: String in PROTOTYPE_LISTS:
		var list: Variant = park.get(property)
		if list is Array:
			for proto: Variant in list:
				if _live_node(proto): ids[(proto as Node).get_instance_id()] = true
	return ids

## Null, freed or non-Node values are skipped ("is" on a freed instance errors).
static func _live_node(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value) and value is Node

static func _label(node: MultiMeshInstance3D, copy: bool, tags: Dictionary) -> String:
	var mesh := node.multimesh.mesh
	var label := mesh.resource_name if copy else String(node.name) + " " + mesh.resource_name
	var tag: String = tags.get(_mesh_key(mesh), "")
	if tag != "": label += " | " + tag
	return label

static func _stride(mm: MultiMesh) -> int:
	return 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)

## 1 = hide, from the leader's own instance positions.
static func _keep_mask(leader: MultiMeshInstance3D, keep: Callable, area: Rect2) -> PackedByteArray:
	var mm := leader.multimesh
	var count := mm.instance_count
	var mask := PackedByteArray()
	mask.resize(count)
	var to_world := leader.global_transform
	var buffer := mm.buffer
	var stride := _stride(mm)
	var packed := buffer.size() == count * stride
	for i: int in range(count):
		var local: Vector3
		if packed:
			var o := i * stride
			local = Vector3(buffer[o + 3], buffer[o + 7], buffer[o + 11])
		else:
			local = mm.get_instance_transform(i).origin
		var at := to_world * local
		var p := Vector2(at.x, at.z)
		if area.has_area() and not area.has_point(p): continue
		if not keep.call(p): mask[i] = 1
	return mask

static func _grow_box(box: Rect2, p: Vector2) -> Rect2:
	if box.size == Vector2.ZERO and box.position == Vector2.ZERO: return Rect2(p, Vector2(0.001, 0.001))
	return box.expand(p)

## Collapse masked instances; record every masked part position for copies.
## Returns [hidden count, grown bounds of recorded positions].
static func _apply_mask(node: MultiMeshInstance3D, mask: PackedByteArray, hidden_at: Dictionary, box: Rect2) -> Array:
	var mm := node.multimesh
	var count := mini(mm.instance_count, mask.size())
	var to_world := node.global_transform
	var stride := _stride(mm)
	var buffer := mm.buffer
	var packed := buffer.size() == mm.instance_count * stride
	var hidden := 0
	for i: int in range(count):
		if mask[i] == 0: continue
		if packed:
			var o := i * stride
			var at := to_world * Vector3(buffer[o + 3], buffer[o + 7], buffer[o + 11])
			var p := Vector2(at.x, at.z)
			hidden_at[_cell(p)] = true
			box = _grow_box(box, p)
			if Vector3(buffer[o], buffer[o + 4], buffer[o + 8]).length() < COLLAPSED: continue
			for k: int in [0, 1, 2, 4, 5, 6, 8, 9, 10]: buffer[o + k] *= HIDE_SCALE
			hidden += 1
		else:
			var t := mm.get_instance_transform(i)
			var at := to_world * t.origin
			var p := Vector2(at.x, at.z)
			hidden_at[_cell(p)] = true
			box = _grow_box(box, p)
			if t.basis.get_scale().x < COLLAPSED: continue
			t.basis = t.basis.scaled(Vector3.ONE * HIDE_SCALE)
			mm.set_instance_transform(i, t)
			hidden += 1
	if packed and hidden > 0: mm.buffer = buffer
	if hidden > 0: _touched(mm)
	return [hidden, box]

## Masks (1 = hide) of each group's leader, as _keep_mask() makes them. With a
## pure keep() the packed leaders are judged on WorkerThreadPool, one task per
## group (their buffers are read here first, as _keep_mask() reads them); a
## leader without a packed buffer, or an impure keep(), takes _keep_mask().
static func _group_masks(groups: Array, keep: Callable, area: Rect2, pure: bool) -> Array:
	var masks: Array = []
	masks.resize(groups.size())
	var jobs: Array = [] # [group index, buffer, stride, count, to_world]
	for i: int in range(groups.size()):
		var leader: MultiMeshInstance3D = groups[i][0]
		if not pure:
			masks[i] = _keep_mask(leader, keep, area)
			continue
		var mm := leader.multimesh
		var count := mm.instance_count
		var stride := _stride(mm)
		var buffer := mm.buffer
		if buffer.size() != count * stride:
			masks[i] = _keep_mask(leader, keep, area)
			continue
		jobs.append([i, buffer, stride, count, leader.global_transform])
	if jobs.is_empty(): return masks
	var job := func(j: int) -> PackedByteArray:
		var row: Array = jobs[j]
		var buffer: PackedFloat32Array = row[1]
		var stride: int = row[2]
		var count: int = row[3]
		var to_world: Transform3D = row[4]
		var mask := PackedByteArray()
		mask.resize(count)
		for i: int in range(count):
			var o := i * stride
			var at := to_world * Vector3(buffer[o + 3], buffer[o + 7], buffer[o + 11])
			var p := Vector2(at.x, at.z)
			if area.has_area() and not area.has_point(p): continue
			if not keep.call(p): mask[i] = 1
		return mask
	var done := Kit.parallel(jobs.size(), job, "thin_all keep")
	for j: int in range(jobs.size()): masks[int(jobs[j][0])] = done[j]
	return masks

## _hide_copy() for every [node, hidden_at, keep, chunk] in `work`, in order,
## with the same edits and counts. The verdict per instance (0 stays, 1 hidden
## by a recorded source position, 2 by keep()) of every packed node whose keep()
## is unused or pure is worked out first on WorkerThreadPool, one task per node
## (hidden_at and the buffers are only read); the buffers are then edited here.
static func _hide_copies(work: Array, area: Rect2, pure: bool) -> Array:
	var results: Array = []
	results.resize(work.size())
	var jobs: Array = [] # [work index, buffer, stride, count, to_world, hidden_at, keep]
	var serial := PackedByteArray()
	serial.resize(work.size())
	for w: int in range(work.size()):
		var node: MultiMeshInstance3D = work[w][0]
		var keep: Callable = work[w][2]
		var mm := node.multimesh
		var count := mm.instance_count
		var stride := _stride(mm)
		var buffer := mm.buffer
		if buffer.size() != count * stride or (keep.is_valid() and not pure):
			serial[w] = 1
			continue
		jobs.append([w, buffer, stride, count, node.global_transform, work[w][1], keep])
	var job := func(j: int) -> PackedByteArray:
		var row: Array = jobs[j]
		var buffer: PackedFloat32Array = row[1]
		var stride: int = row[2]
		var count: int = row[3]
		var to_world: Transform3D = row[4]
		var hidden_at: Dictionary = row[5]
		var keep: Callable = row[6]
		var flags := PackedByteArray()
		flags.resize(count)
		for i: int in range(count):
			var o := i * stride
			if Vector3(buffer[o], buffer[o + 4], buffer[o + 8]).length() < COLLAPSED: continue
			var at := to_world * Vector3(buffer[o + 3], buffer[o + 7], buffer[o + 11])
			var p := Vector2(at.x, at.z)
			if not hidden_at.is_empty() and _recorded(hidden_at, p): flags[i] = 1
			elif keep.is_valid() and (not area.has_area() or area.has_point(p)) and not keep.call(p): flags[i] = 2
		return flags
	var verdicts := Kit.parallel(jobs.size(), job, "thin_all copies") if not jobs.is_empty() else []
	var next := 0
	for w: int in range(work.size()):
		var node: MultiMeshInstance3D = work[w][0]
		if serial[w] == 1:
			results[w] = _hide_copy(node, work[w][1], work[w][2], area)
			continue
		var row: Array = jobs[next]
		var flags: PackedByteArray = verdicts[next]
		next += 1
		var buffer: PackedFloat32Array = row[1]
		var stride: int = row[2]
		var by_position := 0
		var by_keep := 0
		for i: int in range(flags.size()):
			if flags[i] == 0: continue
			if flags[i] == 1: by_position += 1
			else: by_keep += 1
			var o := i * stride
			for k: int in [0, 1, 2, 4, 5, 6, 8, 9, 10]: buffer[o + k] *= HIDE_SCALE
		if by_position + by_keep > 0:
			node.multimesh.buffer = buffer
			_touched(node.multimesh)
		results[w] = Vector2i(by_position, by_keep)
	return results

## x: hidden by recorded source position, y: hidden by the copy's own label + keep.
static func _hide_copy(node: MultiMeshInstance3D, hidden_at: Dictionary, keep: Callable, area: Rect2) -> Vector2i:
	var mm := node.multimesh
	var count := mm.instance_count
	var to_world := node.global_transform
	var stride := _stride(mm)
	var buffer := mm.buffer
	var packed := buffer.size() == count * stride
	var by_position := 0
	var by_keep := 0
	for i: int in range(count):
		var o := i * stride
		var t := Transform3D()
		var local: Vector3
		var scale: float
		if packed:
			local = Vector3(buffer[o + 3], buffer[o + 7], buffer[o + 11])
			scale = Vector3(buffer[o], buffer[o + 4], buffer[o + 8]).length()
		else:
			t = mm.get_instance_transform(i)
			local = t.origin
			scale = t.basis.get_scale().x
		if scale < COLLAPSED: continue
		var at := to_world * local
		var p := Vector2(at.x, at.z)
		var hide := false
		if not hidden_at.is_empty() and _recorded(hidden_at, p):
			hide = true
			by_position += 1
		elif keep.is_valid() and (not area.has_area() or area.has_point(p)) and not keep.call(p):
			hide = true
			by_keep += 1
		if not hide: continue
		if packed:
			for k: int in [0, 1, 2, 4, 5, 6, 8, 9, 10]: buffer[o + k] *= HIDE_SCALE
		else:
			t.basis = t.basis.scaled(Vector3.ONE * HIDE_SCALE)
			mm.set_instance_transform(i, t)
	if packed and by_position + by_keep > 0: mm.buffer = buffer
	if by_position + by_keep > 0: _touched(mm)
	return Vector2i(by_position, by_keep)

## Single plants placed as scenes. Parts are gathered per plant root first, so a
## plant hides whole when ANY part's label matches (like the MultiMesh groups)
## and keep() is asked once per plant, at the root. A plant that carries a
## collision body (boulders, path pieces, props) is never hidden: hiding only
## its visual would leave an invisible wall. A root-less mesh that is wider
## than SINGLE_PLANT_MAX_M or flat (ground patch) is left alone too.
static func _hide_single_plants(park: Node3D, filter_label: Callable, keep: Callable, area: Rect2, tags: Dictionary, by_owner: Dictionary) -> int:
	var prototypes := _prototype_nodes(park)
	var reach := area.grow(SINGLE_PLANT_MAX_M) if area.has_area() else Rect2()
	var plants: Dictionary = {}
	var order: Array[int] = []
	# (_scan: every MeshInstance3D with a mesh in tree order, with its bounds; the
	# owner/prototype test and the plant root are filled in on first use.)
	for i: int in range(_mesh_nodes.size()):
		var flat: Rect2 = _mesh_rects[i]
		if reach.has_area() and not reach.intersects(flat): continue
		var node: MeshInstance3D = _mesh_nodes[i]
		if not node.is_visible_in_tree(): continue
		if _mesh_skip[i] < 0: _mesh_skip[i] = 1 if (_excluded(park, node) or _under_prototype(node, prototypes)) else 0
		if _mesh_skip[i] == 1: continue
		var centre := flat.get_center()
		if _mesh_chain[i] == null: _mesh_chain[i] = _plant_root(park, node, centre)
		var chain: Array = _mesh_chain[i]
		var plant: Node3D = chain[0]
		var key: int = plant.get_instance_id() if plant != null else node.get_instance_id()
		if not plants.has(key):
			var at := centre
			if plant != null: at = Vector2(plant.global_position.x, plant.global_position.z)
			if not _collision_of.has(key): _collision_of[key] = _has_collision(plant if plant != null else node)
			plants[key] = {"at": at, "parts": [], "matched": false, "blocked": _collision_of[key]}
			order.append(key)
		var row: Dictionary = plants[key]
		if row.blocked: continue
		var box: AABB = _mesh_boxes[i]
		if maxf(flat.size.x, flat.size.y) > SINGLE_PLANT_MAX_M or (plant == null and box.size.y < FLAT_M):
			row.blocked = true
			continue
		(row.parts as Array).append(node)
		if not row.matched:
			var label := String(node.name) + " " + node.mesh.resource_name
			var tag: String = tags.get(_mesh_key(node.mesh), "")
			if tag != "": label += " | " + tag
			if plant != null: label += " @ " + String(chain[1])
			if filter_label.call(label): row.matched = true
	var hidden := 0
	for key: int in order:
		var row: Dictionary = plants[key]
		if row.blocked or not row.matched or (row.parts as Array).is_empty(): continue
		var p: Vector2 = row.at
		if area.has_area() and not area.has_point(p): continue
		if keep.call(p): continue
		for part: MeshInstance3D in row.parts:
			part.visible = false
			part.set_meta("biome_thinned", true)
			hidden += 1
			var owner := _owner_name(park, part)
			by_owner[owner] = int(by_owner.get(owner, 0)) + 1
	return hidden

static func _under_prototype(node: Node, prototypes: Dictionary) -> bool:
	var at: Node = node
	while at != null:
		if prototypes.has(at.get_instance_id()): return true
		at = at.get_parent()
	return false

## True when hiding `top`'s visuals would leave a collider behind: a collision
## body inside it, as its parent, or beside it under the same parent.
static func _has_collision(top: Node) -> bool:
	if top is CollisionObject3D: return true
	var parent := top.get_parent()
	if parent is CollisionObject3D: return true
	if not top.find_children("*", "CollisionObject3D", true, false).is_empty(): return true
	# A root-less mesh: a body placed beside it belongs to the same object.
	if top is MeshInstance3D and parent != null:
		for sibling: Node in parent.get_children():
			if sibling is CollisionObject3D: return true
	return false

## The placed plant a mesh belongs to: the OUTERMOST Node3D ancestor named like
## a placed plant ("EmeraldFountainGrass_003", "OpenBoulder_02") that stands
## within PLANT_ROOT_REACH_M of the mesh. Outermost, because imported scenes
## carry their own numbered inner nodes ("Object_2", "Plane_001"); the reach
## keeps grid containers ("Cell_3") with far-off origins out. Returns
## [root or null, "Root_003/Inner_2" chain of numbered names for the label].
static func _plant_root(park: Node3D, node: Node, centre: Vector2) -> Array:
	var root: Node3D = null
	var names := PackedStringArray()
	var at: Node = node.get_parent()
	while at != null and at != park:
		var at_name := String(at.name)
		var cut := at_name.rfind("_")
		if at is Node3D and cut > 0 and at_name.substr(cut + 1).is_valid_int():
			var g := (at as Node3D).global_position
			if Vector2(g.x - centre.x, g.z - centre.y).length() <= PLANT_ROOT_REACH_M:
				root = at as Node3D
				names.insert(0, at_name)
		at = at.get_parent()
	return [root, "/".join(names)]

static func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x * MATCH_PER_M), floori(p.y * MATCH_PER_M))

## Tolerant lookup: copies round-trip within 0.1 mm of their source.
static func _recorded(hidden_at: Dictionary, p: Vector2) -> bool:
	var fx := p.x * MATCH_PER_M
	var fz := p.y * MATCH_PER_M
	var x0 := floori(fx)
	var z0 := floori(fz)
	var xs: Array[int] = [x0]
	var zs: Array[int] = [z0]
	var rx := fx - float(x0)
	var rz := fz - float(z0)
	if rx < MATCH_EDGE: xs.append(x0 - 1)
	elif rx > 1.0 - MATCH_EDGE: xs.append(x0 + 1)
	if rz < MATCH_EDGE: zs.append(z0 - 1)
	elif rz > 1.0 - MATCH_EDGE: zs.append(z0 + 1)
	for x: int in xs:
		for z: int in zs:
			if hidden_at.has(Vector2i(x, z)): return true
	return false
