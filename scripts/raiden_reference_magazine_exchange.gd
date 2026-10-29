extends RefCounted
## Two complete visual magazines, following the authored hand/rig motion.
var holder: Node3D
var current: Node3D
var replacement: Node3D
var swapping := false
var had_magazine := true
var generation := 0

func wrap(source: Node3D) -> Node3D:
	var rig: Node = source.get_node_or_null(source.skeleton) if source is MeshInstance3D else null
	holder=Node3D.new();holder.name="MagazineExchangePivot"
	source.get_parent().add_child(holder)
	holder.transform=source.transform
	source.reparent(holder,false);source.transform=Transform3D.IDENTITY
	if source is MeshInstance3D and rig!=null:source.skeleton=source.get_path_to(rig)
	current=source
	current.set_meta("magazine_role","inserted")
	return holder

func begin(inserted: bool) -> void:
	if not is_instance_valid(current):return
	if is_instance_valid(replacement):replacement.queue_free()
	replacement=current.duplicate() as Node3D
	generation+=1
	replacement.name="ReplacementMagazine_%d" % generation
	holder.add_child(replacement)
	replacement.set_meta("magazine_role","replacement")
	replacement.hide()
	current.set_meta("magazine_role","outgoing")
	had_magazine=inserted
	swapping=true

func update(ratio: float, reloading: bool, inserted: bool, empty: bool, raiden_partial: bool = false, dropped_outgoing: bool = false) -> void:
	if not is_instance_valid(current):return
	if swapping and not reloading:
		if inserted and is_instance_valid(replacement):
			current.queue_free();current=replacement;current.set_meta("magazine_role","inserted")
		elif is_instance_valid(replacement):replacement.queue_free()
		replacement=null;swapping=false
	if not swapping:
		current.visible=inserted
		return
	# A short hand-to-pouch interval separates the retained and replacement meshes.
	var exchange := .40 if raiden_partial else (.27 if empty else .42)
	current.visible=had_magazine and ratio<exchange and not (raiden_partial and dropped_outgoing and ratio>=.16)
	if is_instance_valid(replacement):replacement.visible=ratio>=exchange+.04
