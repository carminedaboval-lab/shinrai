extends RefCounted
## The original glove skin and weapon animation remain on their existing rig.
const MODEL_PATH := "res://assets/characters/urban_explorer_2050/urban_explorer_detailed_sleeves_overlay.glb"
const REPLACED_NODES := ["Object_9", "Object_10", "Object_11", "Object_12"]

static func apply_to(model_root: Node3D) -> bool:
    if model_root.has_meta("explorer_sleeves_attached"):
        return true
    var target := _find_skeleton(model_root)
    var packed := load(MODEL_PATH) as PackedScene
    if target == null or packed == null:
        push_warning("Explorer sleeve overlay unavailable; original arms retained")
        return false
    var imported := packed.instantiate() as Node3D
    var source := _find_mesh(imported)
    if source == null or source.skin == null:
        imported.free()
        return false
    var source_skeleton := source.get_node_or_null(source.skeleton) as Skeleton3D
    if source_skeleton == null:
        imported.free()
        return false
    var named_skin := source.skin.duplicate() as Skin
    for bind in range(named_skin.get_bind_count()):
        var bone_name := named_skin.get_bind_name(bind)
        if bone_name.is_empty():
            var source_bone := named_skin.get_bind_bone(bind)
            if source_bone < 0 or source_bone >= source_skeleton.get_bone_count():
                imported.free()
                return false
            bone_name = source_skeleton.get_bone_name(source_bone)
        if target.find_bone(bone_name) < 0:
            push_warning("Explorer sleeve bind absent: " + bone_name)
            imported.free()
            return false
        named_skin.set_bind_name(bind, bone_name)
    var sleeve := MeshInstance3D.new()
    sleeve.name = "ExplorerDetailedSleeves"
    sleeve.mesh = source.mesh
    sleeve.skin = named_skin
    sleeve.transform = _root_transform(source_skeleton).affine_inverse() * _root_transform(source)
    sleeve.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    sleeve.layers = 1 << 19
    sleeve.extra_cull_margin = 2.0
    target.add_child(sleeve)
    sleeve.skeleton = NodePath("..")
    # Hide supplied clothing only once every new sleeve bind is valid.
    for name_to_replace: String in REPLACED_NODES:
        var previous := model_root.find_child(name_to_replace, true, false) as GeometryInstance3D
        if previous != null:
            previous.hide()
    model_root.set_meta("explorer_sleeves_attached", true)
    imported.free()
    return true

static func _root_transform(node: Node3D) -> Transform3D:
    var result := node.transform
    var parent := node.get_parent()
    while parent is Node3D:
        result = (parent as Node3D).transform * result
        parent = parent.get_parent()
    return result

static func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

static func _find_mesh(node: Node) -> MeshInstance3D:
    if node is MeshInstance3D:
        return node as MeshInstance3D
    for child in node.get_children():
        var found := _find_mesh(child)
        if found != null:
            return found
    return null
