extends RefCounted
## One baked copy of a supplied mesh per (mesh, materials), shared by every
## batch that bakes the same part with the same materials.
##
## Builders copy a GLB part's mesh (`mesh.duplicate()`) only to set a material
## on each surface before handing it to a MultiMesh. Every copy reads the
## surfaces back and uploads them again, so a part baked by five modules, or by
## one module per bucket, sat on the GPU five or fifty times. `baked()` returns
## the first copy for the same source mesh and the same material objects; the
## copy is otherwise exactly what `duplicate()` + `surface_set_material()` made.
##
## The cache never keeps a copy alive: entries hold weak references, so a copy
## lives as long as the batches that use it (a Retry rebuilds everything and
## the old copies go with the old park). A source mesh that died cannot match
## (its weak reference reads back null), so a reused instance id is never taken
## for the old mesh. Materials in the key are held by the copy's surfaces while
## it lives, so a live hit always carries the same material objects.
## Callers may run on any thread (one lock around the table).

const SWEEP_AT := 2048
## Node meta read by midori_distance_detail.gd in place of the mesh's instance
## id when it groups batches into far chunks.
const GROUP_META := &"bake_group"

static var _entries: Dictionary = {}
static var _lock := Mutex.new()
static var _next_group := 0

## A grouping key for one bake: what the private duplicate's instance id used to
## be. Distance detail merges batches that share a mesh object (and settings) in
## the same cell. Before the cache every bake call made its own copy, so batches
## from different calls never merged; sharing the copy would merge them, renaming
## the far chunks and re-rolling which ones skip shadows (midori_near_plant_shadows).
## Take one key per former duplicate() call and tag() every batch node built from
## that call's mesh, and the old grouping comes back exactly.
static func group_key() -> String:
	_lock.lock()
	_next_group += 1
	var key := "bake%d" % _next_group
	_lock.unlock()
	return key

static func tag(node: Node, key: String) -> void:
	node.set_meta(GROUP_META, key)

## The shared baked copy of `mesh` with `materials[s]` set on surface s, exactly
## as the old duplicate() + surface_set_material() loop did (a null entry sets
## null, as before).
static func baked(mesh: Mesh, materials: Array) -> Mesh:
	if mesh == null: return null
	var key := _key(mesh, materials)
	_lock.lock()
	var entry: Variant = _entries.get(key)
	if entry != null:
		var source: Variant = (entry[0] as WeakRef).get_ref()
		var copy: Variant = (entry[1] as WeakRef).get_ref()
		if source == mesh and copy != null:
			_lock.unlock()
			return copy as Mesh
	var fresh := mesh.duplicate() as Mesh
	var surfaces := mini(fresh.get_surface_count(), materials.size())
	for s: int in range(surfaces):
		fresh.surface_set_material(s, materials[s])
	if _entries.size() >= SWEEP_AT: _sweep()
	_entries[key] = [weakref(mesh), weakref(fresh)]
	_lock.unlock()
	return fresh

## The shared baked copy of a part's mesh carrying the part's active material
## on every surface (override where set, the mesh's own otherwise): the usual
## `visual.mesh.duplicate()` + `surface_set_material(s, visual.get_active_material(s))`.
static func baked_from(visual: MeshInstance3D) -> Mesh:
	if visual == null or visual.mesh == null: return null
	var materials: Array = []
	for s: int in range(visual.mesh.get_surface_count()):
		materials.append(visual.get_active_material(s))
	return baked(visual.mesh, materials)

## How many copies the table remembers (live or not); for probes.
static func size() -> int:
	_lock.lock()
	var n := _entries.size()
	_lock.unlock()
	return n

static func _key(mesh: Mesh, materials: Array) -> String:
	var ids: PackedInt64Array = [mesh.get_instance_id()]
	for m: Variant in materials:
		ids.append((m as Object).get_instance_id() if m is Object and m != null else 0)
	return str(ids)

## Drops entries whose source or copy is gone (called with the lock held).
static func _sweep() -> void:
	for key: String in _entries.keys():
		var entry: Array = _entries[key]
		if (entry[0] as WeakRef).get_ref() == null or (entry[1] as WeakRef).get_ref() == null:
			_entries.erase(key)
