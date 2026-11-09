extends RefCounted
## CPU copies of the arrays the south street's generated meshes are committed from.
## The street merges ~15k small meshes at the end of its build; SurfaceTool reads
## each source back from the RenderingServer, a GPU download that stalls the
## render device (0.15-2 ms per mesh depending on what else is in flight). While
## the street builds, commit() keeps the committed arrays so the merge reads them
## from memory instead. Same SurfaceTool calls, same arrays as tool.commit() made.
## Positions, UVs, colours and indices are bit-identical to the read-back; normals
## and tangents skip the GPU's 16-bit octahedral round trip (<= 1.1e-4 apart).
## Never feed these to code that branches on normal values (axis tests, UV picks).
## Only active between begin() and end() (the street's own build and merge).

## SurfaceTool.append_from() source that serves kept arrays instead of reading
## the mesh back from the RenderingServer.
class Surfaces extends Mesh:
	var surfaces: Array = []
	var primitives: PackedInt32Array = PackedInt32Array()
	func _get_surface_count() -> int: return surfaces.size()
	func _surface_get_arrays(index: int) -> Array: return surfaces[index]
	func _surface_get_primitive_type(index: int) -> int: return primitives[index]
	func _surface_get_format(_index: int) -> int: return 0
	func _surface_get_array_len(index: int) -> int: return (surfaces[index][Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	func _surface_get_array_index_len(index: int) -> int:
		var indices: Variant = surfaces[index][Mesh.ARRAY_INDEX]
		return 0 if indices == null else (indices as PackedInt32Array).size()
	func _surface_get_blend_shape_arrays(_index: int) -> Array: return []
	func _surface_get_lods(_index: int) -> Dictionary: return {}
	func _surface_get_material(_index: int) -> Material: return null
	func _surface_set_material(_index: int, _material: Material) -> void: pass
	func _get_blend_shape_count() -> int: return 0
	func _get_blend_shape_name(_index: int) -> StringName: return &""
	func _set_blend_shape_name(_index: int, _name: StringName) -> void: pass
	func _get_aabb() -> AABB: return AABB()

static var _active := false
## Mesh instance id -> [surface arrays, primitive] (ids, not refs: never keeps a mesh alive).
static var _kept: Dictionary = {}
## [mesh instance id, surface] -> surface_get_arrays() result, for read().
static var _read: Dictionary = {}

## One street builds at a time; a build that was abandoned (park freed during
## loading) is discarded by the next begin().
static func begin() -> void:
	_kept.clear()
	_read.clear()
	_active = true

static func end() -> void:
	_kept.clear()
	_read.clear()
	_active = false

## mesh.surface_get_arrays(surface) for code that only reads the result. The
## street measures the same plant prototypes again for every placed copy (bounds
## of the referenced vertices); each call downloads the mesh from the GPU. While
## the street builds, each surface is read back once and the same Array is
## returned again (the very values a fresh read returns): callers must not modify
## it, and only meshes nothing rewrites in place may be read through it.
## Outside the build it is a plain surface_get_arrays().
static func read(mesh: Mesh, surface: int) -> Array:
	# A primitive regenerates when a property changes: always read it afresh.
	if not _active or not mesh is ArrayMesh: return mesh.surface_get_arrays(surface)
	var id := mesh.get_instance_id()
	var cached: Variant = _read.get([id, surface])
	if cached != null: return cached
	var arrays := mesh.surface_get_arrays(surface)
	_read[[id, surface]] = arrays
	return arrays

## tool.commit(), keeping the arrays while the street builds.
static func commit(tool: SurfaceTool) -> ArrayMesh:
	if not _active: return tool.commit()
	var arrays := tool.commit_to_arrays()
	var vertices: Variant = arrays[Mesh.ARRAY_VERTEX] if arrays.size() == Mesh.ARRAY_MAX else null
	if vertices == null or (vertices as PackedVector3Array).is_empty(): return tool.commit()
	# What SurfaceTool.commit() does: one surface, no blend shapes, no LODs, no flags.
	var primitive := tool.get_primitive_type()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(primitive, arrays)
	_kept[mesh.get_instance_id()] = [arrays, primitive]
	return mesh

## An append_from() source for `mesh` that needs no read-back, or null.
static func source(mesh: Mesh) -> Mesh:
	if _kept.is_empty() or mesh == null: return null
	var kept: Variant = _kept.get(mesh.get_instance_id())
	if kept == null or mesh.get_surface_count() != 1: return null
	return arrays_source(kept[0], int(kept[1]))

## An append_from()/create_from() source serving `arrays` as its one surface.
static func arrays_source(arrays: Array, primitive: int = Mesh.PRIMITIVE_TRIANGLES) -> Mesh:
	var proxy := Surfaces.new()
	proxy.surfaces.append(arrays)
	proxy.primitives.append(primitive)
	return proxy

## What tool.commit() would hold, as a source, without making a mesh of it.
static func tool_source(tool: SurfaceTool) -> Mesh:
	return arrays_source(tool.commit_to_arrays(), tool.get_primitive_type())
