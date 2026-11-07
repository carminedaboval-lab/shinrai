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
static func hide_low_planting(park: Node3D, filter_label: Callable, keep: Callable, area: Rect2 = Rect2()) -> Dictionary:
	var started := Time.get_ticks_msec()
	if park == null or not is_instance_valid(park):
		return {"error": "park unavailable"}
	var tags := _prototype_tags(park)
	var container: Node = park.get_node_or_null("MidoriDistanceDetail")
	var nodes: Array[MultiMeshInstance3D] = []
	# Meshes that still have a producer (source) node anywhere in the park. A
	# chunk drawing such a mesh is decided by its sources' labels and positions
	# only; its own label is a fallback for meshes whose sources are gone.
	var source_meshes: Dictionary = {}
	for found: Node in park.find_children("*", "MultiMeshInstance3D", true, false):
		var node := found as MultiMeshInstance3D
		if node == null or node.multimesh == null or node.multimesh.mesh == null: continue
		if node.multimesh.transform_format != MultiMesh.TRANSFORM_3D or node.multimesh.instance_count == 0: continue
		if _excluded(park, node): continue
		if container == null or node.get_parent() != container:
			source_meshes[node.multimesh.mesh.get_instance_id()] = true
		if area.has_area() and not area.intersects(_flat_box(node)): continue
		nodes.append(node)
	# Group sibling part batches of the same plants (non-copies only).
	var groups: Dictionary = {}
	var order: Array[String] = []
	var copies: Array[MultiMeshInstance3D] = []
	for node: MultiMeshInstance3D in nodes:
		if container != null and node.get_parent() == container:
			copies.append(node)
			continue
		var key := "%d|%s|%s|%d" % [node.get_parent().get_instance_id(), _family(String(node.name)), str(node.transform), node.multimesh.instance_count]
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
	for key: String in order:
		for sub: Variant in groups[key]:
			var members: Array = sub
			var matched := false
			for member: MultiMeshInstance3D in members:
				if filter_label.call(_label(member, false, tags)):
					matched = true
					break
			if not matched: continue
			groups_matched += 1
			var leader: MultiMeshInstance3D = members[0]
			var mask := _keep_mask(leader, keep, area)
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
	var copy_hidden := 0
	var copy_label_hidden := 0
	var other_hidden := 0
	var chunks_changed := 0
	for node: MultiMeshInstance3D in copies:
		var mm_id := node.multimesh.get_instance_id()
		if done.has(mm_id): continue
		var mesh_id := node.multimesh.mesh.get_instance_id()
		# Re-deciding a chunk by keep() at each part's own (offset) origin would
		# split multi-part plants whose sources pass 1 kept, and a label without
		# the node name can classify differently from the source's label.
		var by_label: bool = not source_meshes.has(mesh_id) and bool(filter_label.call(_label(node, true, tags)))
		var by_mesh := target_meshes.has(mesh_id)
		if by_mesh and not by_label and not (search_box.has_area() and search_box.intersects(_flat_box(node))): continue
		if not by_label and not by_mesh: continue
		done[mm_id] = true
		var result := _hide_copy(node, hidden_at if by_mesh else {}, keep if by_label else Callable(), area)
		if result.x + result.y > 0:
			copy_hidden += result.x
			copy_label_hidden += result.y
			changed_nodes += 1
			chunks_changed += 1
			node.set_meta("biome_thinned", true)
	for node: MultiMeshInstance3D in nodes:
		var mm_id := node.multimesh.get_instance_id()
		if done.has(mm_id): continue
		if not target_meshes.has(node.multimesh.mesh.get_instance_id()): continue
		if not (search_box.has_area() and search_box.intersects(_flat_box(node))): continue
		done[mm_id] = true
		var result := _hide_copy(node, hidden_at, Callable(), area)
		if result.x > 0:
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
	return "%s|%d|%s" % [mesh.resource_name, mesh.get_surface_count(), str(mesh.get_aabb())]

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
	return [hidden, box]

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
	for found: Node in park.find_children("*", "MeshInstance3D", true, false):
		var node := found as MeshInstance3D
		if node == null or node.mesh == null or not node.is_visible_in_tree(): continue
		var flat := _flat_box(node)
		if reach.has_area() and not reach.intersects(flat): continue
		if _excluded(park, node) or _under_prototype(node, prototypes): continue
		var centre := flat.get_center()
		var chain := _plant_root(park, node, centre)
		var plant: Node3D = chain[0]
		var key: int = plant.get_instance_id() if plant != null else node.get_instance_id()
		if not plants.has(key):
			var at := centre
			if plant != null: at = Vector2(plant.global_position.x, plant.global_position.z)
			plants[key] = {"at": at, "parts": [], "matched": false, "blocked": _has_collision(plant if plant != null else node)}
			order.append(key)
		var row: Dictionary = plants[key]
		if row.blocked: continue
		var box: AABB = node.global_transform * node.mesh.get_aabb()
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
