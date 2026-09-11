@tool
extends EditorScript

# OPTIONAL:
# Open SHINRAI_Road_GameReady.tscn in the editor, then run this script.
# It adds trimesh collision to every MeshInstance3D.
# This is suitable for a static road. Do not use this collision method for moving bodies.

func _run() -> void:
    var root := get_editor_interface().get_edited_scene_root()
    if root == null:
        push_error("Open SHINRAI_Road_GameReady.tscn before running this script.")
        return

    var count := _add_collision_recursive(root)
    print("SHINRAI: Added trimesh collision to ", count, " mesh node(s). Save the scene.")

func _add_collision_recursive(node: Node) -> int:
    var count := 0
    if node is MeshInstance3D:
        var mi := node as MeshInstance3D
        mi.create_trimesh_collision()
        count += 1

    for child in node.get_children():
        count += _add_collision_recursive(child)

    return count
