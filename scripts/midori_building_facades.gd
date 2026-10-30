extends RefCounted
## Gives plain building shells real construction depth. Corporate blocks gain
## fins, floor bands, a glazed podium and rooftop plant; homes gain sills, window
## hoods, plinths and services. Visual only, and batched per building.
const Kit = preload("res://scripts/midori_park_kit.gd")
const FIN_SPACING := 3.6
const FLOOR_SPACING := 3.3
const PODIUM_HEIGHT := 3.6
const SHOPS := ["UedaBooks", "MoriCoffee", "HinataDaily", "YakitoriShop"]

static func dress_blocks(neon: Node3D, street: Node3D, blocks: Array[AABB]) -> int:
	var fin := Kit.mat(Color("#2b3137"), .42, .75)
	var band := Kit.mat(Color("#40464c"), .6, .4)
	var glass := Kit.mat(Color("#101820"), .08, .85)
	var roof := Kit.mat(Color("#34383c"), .8, .2)
	var plant := Kit.mat(Color("#6a6f72"), .5, .5)
	var parts := 0
	for i: int in range(blocks.size()):
		var box := blocks[i]
		var root := Node3D.new()
		root.name = "CorporateFacade_%02d" % i
		neon.add_child(root)
		var glow: StandardMaterial3D = neon._glow(Color("#ffd2a0"))
		var low := box.position
		var high := box.end
		var mid := box.get_center()
		# Each entry: a point on the face centre, its outward normal, its length.
		for face: Array in [[Vector3(mid.x, 0, low.z), Vector3(0, 0, -1), box.size.x], [Vector3(mid.x, 0, high.z), Vector3(0, 0, 1), box.size.x], [Vector3(low.x, 0, mid.z), Vector3(-1, 0, 0), box.size.z], [Vector3(high.x, 0, mid.z), Vector3(1, 0, 0), box.size.z]]:
			parts += _dress_face(root, face[0], face[1], float(face[2]), box.size.y, fin, band, glass, glow)
		_add_canopy(root, Vector3(mid.x, 0, low.z), roof, glow)
		parts += _add_roof(root, box, roof, plant, i)
		street.call("_batch_direct_geometry", root)
	return parts

static func _dress_face(root: Node3D, centre: Vector3, normal: Vector3, length: float, height: float, fin: Material, band: Material, glass: Material, glow: Material) -> int:
	var along := Vector3(-normal.z, 0, normal.x)
	var yaw := atan2(normal.x, normal.z)
	var parts := 0
	var fins := int(length / FIN_SPACING)
	for i: int in range(fins + 1):
		var offset := (float(i) - float(fins) * .5) * FIN_SPACING
		var at := centre + along * offset + normal * .19 + Vector3.UP * (PODIUM_HEIGHT + height) * .5
		Kit.box(root, "Fin", Vector3(.16, height - PODIUM_HEIGHT, .36), at, fin, Vector3(0, yaw, 0))
		parts += 1
	var y := PODIUM_HEIGHT + FLOOR_SPACING
	while y < height - 1.0:
		Kit.box(root, "FloorBand", Vector3(length + .3, .13, .24), centre + normal * .13 + Vector3.UP * y, band, Vector3(0, yaw, 0))
		y += FLOOR_SPACING
		parts += 1
	Kit.box(root, "PodiumGlass", Vector3(length + .2, PODIUM_HEIGHT - .4, .14), centre + normal * .08 + Vector3.UP * (PODIUM_HEIGHT - .4) * .5, glass, Vector3(0, yaw, 0))
	Kit.box(root, "PodiumHead", Vector3(length + .5, .4, .5), centre + normal * .24 + Vector3.UP * (PODIUM_HEIGHT - .2), band, Vector3(0, yaw, 0))
	Kit.box(root, "PodiumCove", Vector3(length + .3, .03, .05), centre + normal * .5 + Vector3.UP * (PODIUM_HEIGHT - .42), glow, Vector3(0, yaw, 0))
	for i: int in range(fins + 1):
		var offset := (float(i) - float(fins) * .5) * FIN_SPACING
		Kit.box(root, "PodiumMullion", Vector3(.1, PODIUM_HEIGHT - .4, .2), centre + along * offset + normal * .12 + Vector3.UP * (PODIUM_HEIGHT - .4) * .5, fin, Vector3(0, yaw, 0))
		parts += 1
	return parts + 3

static func _add_canopy(root: Node3D, front: Vector3, roof: Material, glow: Material) -> void:
	var at := front + Vector3(0, 3.7, -1.5)
	Kit.box(root, "EntranceCanopy", Vector3(9.0, .22, 3.0), at, roof)
	Kit.box(root, "CanopyLight", Vector3(8.4, .03, 2.5), at + Vector3.DOWN * .12, glow)
	for x: float in [-4.1, 4.1]:
		Kit.tube(root, "CanopyTie", at + Vector3(x, .1, -1.4), at + Vector3(x, 1.9, 1.5), .03, roof)

static func _add_roof(root: Node3D, box: AABB, roof: Material, plant: Material, seed_value: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2050 + seed_value
	var top := box.end.y
	var mid := box.get_center()
	for side: float in [-1.0, 1.0]:
		Kit.box(root, "Parapet", Vector3(box.size.x + .3, .9, .2), Vector3(mid.x, top + .45, mid.z + side * box.size.z * .5), roof)
		Kit.box(root, "Parapet", Vector3(.2, .9, box.size.z + .3), Vector3(mid.x + side * box.size.x * .5, top + .45, mid.z), roof)
	var units := 4 + seed_value % 3
	for i: int in range(units):
		var at := Vector3(mid.x + rng.randf_range(-.34, .34) * box.size.x, top, mid.z + rng.randf_range(-.34, .34) * box.size.z)
		var size := Vector3(rng.randf_range(2.0, 4.5), rng.randf_range(1.2, 2.4), rng.randf_range(1.8, 3.2))
		Kit.box(root, "RoofPlant", size, at + Vector3.UP * size.y * .5, plant)
		Kit.box(root, "PlantLouvre", size + Vector3(.04, -size.y * .6, .04), at + Vector3.UP * size.y * .4, roof)
	var mast := Vector3(mid.x + box.size.x * .3, top, mid.z - box.size.z * .3)
	Kit.tube(root, "RoofMast", mast, mast + Vector3.UP * 7.0, .08, plant)
	return units * 2 + 5

static func dress_homes(neon: Node3D, street: Node3D) -> int:
	var hood := Kit.mat(Color("#33383c"), .45, .7)
	var sill := Kit.mat(Color("#6f6e68"), .85)
	var plinth := Kit.mat(Color("#4c4d4c"), .95)
	var band := Kit.mat(Color("#55534c"), .85)
	var pipe := Kit.mat(Color("#7c8084"), .5, .6)
	var meter := Kit.mat(Color("#aeb1ae"), .55, .3)
	var dressed := 0
	for row: Dictionary in street.get_meta("building_access_registry", []):
		if str(row.id) in SHOPS: continue
		var house := street.get_tree().root.get_node_or_null(NodePath(str(row.root_path))) as Node3D
		if house == null: continue
		var root := Node3D.new()
		root.name = String(house.name) + "Exterior"
		neon.add_child(root)
		root.global_transform = house.global_transform.orthonormalized()
		var dims: Dictionary = row.dimensions
		_dress_shell(root, dims, plinth, band)
		var first := true
		var centre := house.to_global(Vector3(0, 0, float(dims.front_z_m) + float(dims.depth_m) * .5))
		for path: String in row.windows:
			var pane := street.get_tree().root.get_node_or_null(NodePath(path)) as Node3D
			if pane == null or not pane.get("dimensions") is Vector3: continue
			_dress_window(neon, root, pane, centre, sill, hood, first)
			first = false
		_add_services(root, dims, pipe, meter)
		street.call("_batch_direct_geometry", root)
		dressed += 1
	return dressed

static func _dress_shell(root: Node3D, dims: Dictionary, plinth: Material, band: Material) -> void:
	var w := float(dims.width_m)
	var d := float(dims.depth_m)
	var f := float(dims.front_z_m)
	var h := float(dims.upper_floor_m) - .06
	var mid := f + d * .5
	# Doors sit in the front wall, so the plinth runs round the other three sides.
	for side: float in [-1.0, 1.0]:
		Kit.box(root, "Plinth", Vector3(.1, .5, d), Vector3(side * (w * .5 + .03), .25, mid), plinth)
		Kit.box(root, "FloorBand", Vector3(.09, .14, d + .1), Vector3(side * (w * .5 + .03), h, mid), band)
	Kit.box(root, "Plinth", Vector3(w + .1, .5, .1), Vector3(0, .25, f + d + .03), plinth)
	Kit.box(root, "FloorBand", Vector3(w + .1, .14, .09), Vector3(0, h, f + d + .03), band)
	Kit.box(root, "FloorBand", Vector3(w + .1, .14, .09), Vector3(0, h, f - .03), band)

static func _dress_window(neon: Node3D, root: Node3D, pane: Node3D, centre: Vector3, sill: Material, hood: Material, add_unit: bool) -> void:
	var size: Vector3 = pane.get("dimensions")
	var axis := pane.global_basis.z
	axis.y = 0.0
	axis = axis.normalized()
	if axis.dot(pane.global_position - centre) < 0.0: axis = -axis
	var outside := root.global_transform.affine_inverse() * (pane.global_position + axis * .34)
	var local_axis := (root.global_basis.inverse() * axis).normalized()
	var yaw := atan2(local_axis.x, local_axis.z)
	var half := size.y * .5
	Kit.box(root, "WindowSill", Vector3(size.x + .3, .07, .2), outside + Vector3.DOWN * (half + .12) + local_axis * .06, sill, Vector3(0, yaw, 0))
	var hood_box := Kit.box(root, "WindowHood", Vector3(size.x + .4, .05, .5), outside + Vector3.UP * (half + .13) + local_axis * .2, hood, Vector3(deg_to_rad(12), yaw, 0))
	hood_box.rotation_order = EULER_ORDER_YXZ
	if add_unit and float(pane.global_position.y) < 3.0:
		neon._air_conditioner(root, outside + Vector3.DOWN * (half + .55) + local_axis * .1 + Vector3(0, 0, 0), yaw + PI)

static func _add_services(root: Node3D, dims: Dictionary, pipe: Material, meter: Material) -> void:
	var w := float(dims.width_m)
	var f := float(dims.front_z_m)
	var d := float(dims.depth_m)
	var at := Vector3(w * .5 + .05, 0, f + d * .72)
	Kit.box(root, "GasMeter", Vector3(.16, .4, .32), at + Vector3(.04, 1.35, 0), meter)
	Kit.box(root, "PowerMeter", Vector3(.12, .3, .22), at + Vector3(.03, 1.45, .55), meter)
	Kit.tube(root, "GasRiser", at + Vector3(.05, .05, 0), at + Vector3(.05, 1.15, 0), .018, pipe)
	Kit.tube(root, "DropPipe", at + Vector3(.05, 1.6, .55), at + Vector3(.05, float(dims.upper_floor_m) + 2.3, .55), .018, pipe)
