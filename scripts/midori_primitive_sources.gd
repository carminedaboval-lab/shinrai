extends RefCounted
## SurfaceTool.append_from() sources for generated primitive meshes, without a GPU
## read-back per use. append_from() reads its source with surface_get_arrays(); for
## a BoxMesh that is a RenderingServer download of the freshly uploaded primitive,
## which stalls the render device (~0.1-0.5 ms each, thousands per build). Primitives
## with the same parameters generate the same arrays, so each distinct one is read
## back once here and the very arrays that read returned are served again through a
## scripted Mesh (the south street's MeshArrays proxy): append_from() sees exactly
## what a fresh primitive of that size returns (positions, normals, tangents, UVs).
## Callers must not modify the served arrays (append_from only reads them).
const MeshArrays = preload("res://scripts/midori_south_street_mesh_arrays.gd")

static var _boxes: Dictionary = {}

## The append_from() source of BoxMesh.new() with this size (other properties default).
static func box(size: Vector3) -> Mesh:
	var hit: Variant = _boxes.get(size)
	if hit != null: return hit
	var mesh := BoxMesh.new()
	mesh.size = size
	# A BoxMesh is one triangle-list surface.
	var source := MeshArrays.arrays_source(mesh.surface_get_arrays(0), Mesh.PRIMITIVE_TRIANGLES)
	_boxes[size] = source
	return source
