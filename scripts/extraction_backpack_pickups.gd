extends RefCounted
## Supplies two real GLB pickup instances only; no substitute geometry.
const MODELS := {
	"backpack_regular":"res://assets/shinrai/gear/backpacks/regular.glb",
	"backpack_mountain":"res://assets/shinrai/gear/backpacks/mountain.glb"
}
static func register_for(raid: Node, cafe: Node3D) -> int:
	if cafe==null or not cafe.is_inside_tree(): return 0
	var bench := cafe.get_node_or_null("ShelteredWaitingBench") as Node3D
	if bench==null: return 0
	var holder := cafe.get_node_or_null("BackpackPickups") as Node3D
	if holder==null:
		holder=Node3D.new()
		holder.name="BackpackPickups"
		cafe.add_child(holder)
	var anchor := cafe.to_local(bench.global_position)
	anchor.y=0.0 # Bench root includes imported pivot compensation.
	var count := 0
	for id: String in MODELS:
		var path: String=MODELS[id]
		if not ResourceLoader.exists(path):
			push_warning("Backpack real GLB unavailable; pickup disabled: "+path)
			continue
		var model := holder.get_node_or_null(id) as Node3D
		if model==null:
			var packed := load(path) as PackedScene
			if packed==null: continue
			model=packed.instantiate() as Node3D
			if model==null: continue
			model.name=id
			holder.add_child(model)
			# Separate, non-blocking positions by the bench's western end. The
			# clubhouse bench name is outside the generic cache registration names.
			model.position=anchor+(Vector3(-1.30,0,-.10) if id=="backpack_regular" else Vector3(-1.95,0,.25))
			model.rotation.y=0.16 if id=="backpack_regular" else -0.22
			var bottom := INF
			for mesh: Node in model.find_children("*","MeshInstance3D",true,false):
				var box: AABB=holder.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
				bottom=minf(bottom,box.position.y)
			if not is_finite(bottom):
				model.queue_free()
				continue
			var floor_y := 0.0
			if cafe.has_method("exterior_floor_height_at"):
				floor_y=float(cafe.call("exterior_floor_height_at",model.global_position))-holder.global_position.y
			model.position.y+=floor_y+0.002-bottom
		model.hide()
		if raid.register_backpack_pickup(id,model,path): count+=1
	return count
