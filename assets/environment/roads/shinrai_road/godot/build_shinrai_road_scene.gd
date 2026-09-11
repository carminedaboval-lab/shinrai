@tool
extends EditorScript

# Run this script from Godot's Script Editor after the asset folder has imported.
# It creates:
# res://assets/environment/roads/shinrai_road/godot/SHINRAI_Road_GameReady.tscn

const ROOT := "res://assets/environment/roads/shinrai_road"
const SOURCE_GLB := ROOT + "/mesh/SHINRAI_Road_LP_Godot_YUp.glb"
const MATERIAL_PATH := ROOT + "/godot/M_SHINRAI_Road_Dry.tres"
const OUTPUT_SCENE := ROOT + "/godot/SHINRAI_Road_GameReady.tscn"

func _run() -> void:
    var packed := load(SOURCE_GLB) as PackedScene
    if packed == null:
        push_error("SHINRAI: Could not load " + SOURCE_GLB)
        return

    var material := load(MATERIAL_PATH) as Material
    if material == null:
        push_error("SHINRAI: Could not load " + MATERIAL_PATH)
        return

    var root := packed.instantiate()
    root.name = "SHINRAI_Road_GameReady"

    var mesh_count := _apply_material_recursive(root, material)
    if mesh_count == 0:
        push_error("SHINRAI: No MeshInstance3D found in imported GLB.")
        root.free()
        return

    var out := PackedScene.new()
    var pack_err := out.pack(root)
    if pack_err != OK:
        push_error("SHINRAI: PackedScene.pack failed: " + str(pack_err))
        root.free()
        return

    var save_err := ResourceSaver.save(out, OUTPUT_SCENE)
    root.free()

    if save_err != OK:
        push_error("SHINRAI: Scene save failed: " + str(save_err))
        return

    print("SHINRAI road scene created: ", OUTPUT_SCENE)
    print("Material applied to ", mesh_count, " MeshInstance3D node(s).")
    print("Road footprint: 3.10 m x 5.00 m. Lowest surface point is Y=0.")

func _apply_material_recursive(node: Node, material: Material) -> int:
    var count := 0
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        mesh_instance.material_override = material
        count += 1

    for child in node.get_children():
        count += _apply_material_recursive(child, material)

    return count
