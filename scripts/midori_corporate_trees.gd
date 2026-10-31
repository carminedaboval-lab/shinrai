extends RefCounted
## Real tree models for the corporate district, from the same pack as the main
## street. The district only records each spot and its invisible trunk collision,
## so routes and collision are unchanged. Spots are in district space.
const Landscape = preload("res://scripts/midori_south_street_landscape.gd")
const MODELS: Array[String] = ["Tree EZTree0.Medium011", "Tree EZTree0.Medium010"]
const HEIGHT_PER_SCALE := 6.4  # metres of tree per unit of district tree scale

static func plant(district: Node3D) -> Dictionary:
	var prototypes: Array[Node3D] = []
	for model: String in MODELS:
		var prototype := Landscape._prototype(Landscape.TREE_PACK, model)
		if prototype != null: prototypes.append(prototype)
	if prototypes.is_empty(): return {"trees":0}
	var root := Node3D.new()
	root.name = "CorporateTrees"
	root.set_meta("creator_protected", true)
	district.add_child(root)
	var spots: Array[Vector4] = district.get("tree_spots")
	for i: int in range(spots.size()):
		var spot := spots[i]
		var variation := .92 + .16 * absf(sin(float(i) * 1.9))
		_place(prototypes[i % prototypes.size()], root, Vector3(spot.x, spot.y, spot.z), spot.w * HEIGHT_PER_SCALE * variation, float(i) * 2.4)
	for prototype: Node3D in prototypes:
		prototype.free()
	return {"trees":spots.size(), "models":MODELS}

static func _place(prototype: Node3D, parent: Node3D, at: Vector3, height: float, yaw: float) -> void:
	var bounds: AABB = prototype.get_meta("source_bounds")
	var factor := height / maxf(bounds.size.y, .001)
	var content := Node3D.new()
	content.name = "CorporateTree"
	content.position = at
	content.rotation.y = yaw
	parent.add_child(content)
	var instance := prototype.duplicate() as Node3D
	instance.scale = Vector3.ONE * factor
	instance.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	content.add_child(instance)
