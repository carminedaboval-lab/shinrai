import bmesh
import bpy
import sys

source = sys.argv[-2]
destination = sys.argv[-1]
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=source)
obj = next(item for item in bpy.data.objects if item.type == "MESH")
mesh = obj.data
before = len(mesh.polygons)

# The supplied GLB welds its ragged perimeter net to the pitch and goals in
# one mesh. Preserve the turf/goal center while cutting the vertical outer
# shell. The new regular fence is built in Godot at the same footprint.
bm = bmesh.new()
bm.from_mesh(mesh)
to_remove = []
for face in bm.faces:
    point = face.calc_center_median()
    # Remove the old stone lip at the new north-side entrance, while keeping
    # the flat turf at z=0 so the player can walk through the opening.
    gate_lip = point.x < -0.242 and abs(point.y) < 0.045 and point.z > 0.005
    if gate_lip:
        to_remove.append(face)
        continue
    # The pitch surface (including its painted lines) sits around z=0.016.
    # The torn fence skirt starts above 0.022, so preserve the playing face.
    if point.z <= 0.022:
        continue
    side_fence = abs(point.x) > 0.210
    end_fence = abs(point.y) > 0.460 and abs(point.x) > 0.105
    if side_fence or end_fence:
        to_remove.append(face)
print("PITCH_REPAIR faces_before", before, "outer_faces_removed", len(to_remove))
bmesh.ops.delete(bm, geom=to_remove, context="FACES")
bm.to_mesh(mesh)
bm.free()
mesh.update()

# The imported generator also left thousands of detached triangular skirt
# islands just inside the perimeter. Remove entire islands when they rise above
# the field surface; removing individual triangles leaves sawtooth silhouettes.
parents = list(range(len(mesh.vertices)))
sizes = [1] * len(parents)

def find(index):
    while parents[index] != index:
        parents[index] = parents[parents[index]]
        index = parents[index]
    return index

def union(first, second):
    first, second = find(first), find(second)
    if first == second:
        return
    if sizes[first] < sizes[second]:
        first, second = second, first
    parents[second] = first
    sizes[first] += sizes[second]

for face in mesh.polygons:
    anchor = face.vertices[0]
    for vertex in face.vertices[1:]:
        union(anchor, vertex)

islands = {}
for face in mesh.polygons:
    key = find(face.vertices[0])
    item = islands.setdefault(key, [0, 0.0, 0.0, 0.0, 0.0])
    item[0] += 1
    for vertex_id in face.vertices:
        point = mesh.vertices[vertex_id].co
        item[1] = max(item[1], point.z)
        item[2] = max(item[2], abs(point.x))
        item[3] = max(item[3], abs(point.y))
        item[4] = max(item[4], abs(point.x) if abs(point.y) > 0.46 else 0.0)

remove_roots = {
    key for key, item in islands.items()
    if item[1] > 0.022 and (item[2] > 0.21 or (item[3] > 0.46 and item[4] > 0.105))
}
print("PITCH_REPAIR skirt_islands_removed", len(remove_roots),
      "skirt_faces_removed", sum(islands[key][0] for key in remove_roots))
bm = bmesh.new()
bm.from_mesh(mesh)
bm.verts.index_update()
bm.faces.ensure_lookup_table()
extra = [face for face in bm.faces if find(face.verts[0].index) in remove_roots]
bmesh.ops.delete(bm, geom=extra, context="FACES")
bm.to_mesh(mesh)
bm.free()
mesh.update()
print("PITCH_REPAIR faces_after", len(mesh.polygons), "vertices_after", len(mesh.vertices))
bpy.ops.export_scene.gltf(filepath=destination, export_format="GLB", export_apply=True)
print("PITCH_REPAIR exported", destination)
