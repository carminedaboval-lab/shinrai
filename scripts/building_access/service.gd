extends RefCounted
## Shared raid arbitration; components do not poll input independently.
var active := false
var held := true
var release_required := true

func set_active(enabled: bool) -> void:
	active=enabled
	require_release()

func require_release() -> void:
	held=true
	release_required=true

func find_target(actor: Node3D) -> Dictionary:
	if not active or not is_instance_valid(actor) or not actor.is_inside_tree(): return {}
	var camera := actor.get("camera") as Node3D
	var eye: Vector3=actor.global_position+Vector3.UP*1.6 if camera==null else camera.global_position
	var forward: Vector3=-actor.global_basis.z if camera==null else -camera.global_basis.z
	var best := INF
	var result: Dictionary={}
	for node: Node in actor.get_tree().get_nodes_in_group("building_access_targets"):
		if not node is Node3D or not node.has_method("interaction_distance"): continue
		var target := node as Node3D
		var point := target.global_position
		if str(target.get_meta("building_access_kind","")) in ["door","sliding_door","gallery_sliding"]: point=target.to_global(Vector3(0,1.1,0))
		var offset: Vector3=point-eye
		if offset.length()>3.25: continue
		if offset.length_squared()>.01 and forward.dot(offset.normalized())<.70: continue
		var distance: float=target.interaction_distance(actor)
		if distance<best:
			best=distance
			result={"node":target,"distance":distance}
	return result

func consume_interaction(target: Dictionary,actor: Node3D,other_distance: float,eligible: bool,pressed: bool) -> String:
	var fresh: bool=pressed and not held and not release_required
	if not pressed: release_required=false
	held=pressed
	if not active or not eligible or target.is_empty(): return ""
	if float(target.get("distance",INF))>=other_distance: return ""
	var node := target.get("node") as Node3D
	if not is_instance_valid(node): return ""
	if fresh: node.interact(actor)
	return str(node.interaction_prompt(actor))
