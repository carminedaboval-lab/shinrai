extends RefCounted

# World metres: same-tree groves inspired by the shaga woodland reference.
# Supplied pine family is reused; these are not claimed to be scanned cedars.
const GROVES := [
 {"name": "West iris woodland", "centre": Vector2(-155, -30), "radius": Vector2(28, 24)},
 {"name": "North iris woodland", "centre": Vector2(-110, -108), "radius": Vector2(27, 24)},
 {"name": "East iris woodland", "centre": Vector2(185, 40), "radius": Vector2(26, 29)},
]

static func grove_at(world: Vector2) -> int:
 for i in range(GROVES.size()):
  var delta: Vector2 = (world - GROVES[i].centre) / GROVES[i].radius
  if delta.length_squared() <= 1.0: return i
 return -1

static func apply(park: Node3D) -> void:
 # Keep established trunk positions and authored branch contacts. Reuse one
 # supplied pine visual inside the existing crown allowance, with uniform scale.
 var prototype: Node3D = park.pine_prototypes[0]
 var crown: float = park._tree_crown_radius(prototype)
 var counts := [0, 0, 0]
 var protected: Array[String] = []
 for contact: Dictionary in park.TreeBranchContactPlacement.MOVES:
  protected.append(contact.name)
 var trees: Array[Node3D] = []
 for candidate: Node3D in park.find_children("*", "Node3D", true, false):
  var name := String(candidate.name)
  if name.begins_with("ReferenceBroadleaf_") or name.begins_with("ReferencePine_") or name.begins_with("MicroGrove"):
   trees.append(candidate)
 for tree: Node3D in trees:
  var label := String(tree.name)
  if not (label.begins_with("ReferenceBroadleaf_") or label.begins_with("ReferencePine_") or label.begins_with("MicroGrove")): continue
  if protected.has(label): continue
  var world := Vector2(tree.global_position.x, tree.global_position.z)
  var grove := grove_at(world)
  if grove < 0: continue
  var content := tree.get_node_or_null("Content")
  if content == null: continue
  var local := Vector2(tree.position.x, tree.position.z)
  var old_radius: float = park._occupied_tree_crowns.get(local, crown * tree.scale.y)
  var size := minf(tree.scale.y, old_radius / crown)
  tree.remove_child(content)
  content.free()
  var replacement := prototype.get_node("Content").duplicate()
  tree.add_child(replacement)
  tree.scale = Vector3(size / park.LAYOUT_SCALE, size, size / park.LAYOUT_SCALE)
  park._occupied_tree_crowns[local] = crown * size
  var index: int = park.occupied_tree_positions.find(local)
  if index >= 0: park.occupied_tree_is_skinny[index] = true
  tree.set_meta("iris_grove", grove)
  tree.set_meta("grove_tree_source", "Pine_big_1_LOD1")
  counts[grove] += 1
 park.set_meta("iris_grove_tree_counts", counts)
 print("IRIS_WOODLAND_GROVES ", counts, " retained_trunk_positions=true")
