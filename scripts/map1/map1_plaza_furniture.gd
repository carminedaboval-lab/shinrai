extends StaticBody3D
## Shop-facing seats and shielded pedestrian lamps on the south plaza.
const Shell := preload("res://scripts/interior_kit/shell_mesh.gd")
const Plaza := preload("res://scripts/map1/map1_plaza.gd")
const STEEL := Color("#455355")
const CEDAR := Color("#a47450")
const STONE := Color("#97988d")
var shell := Shell.new()

static func install(map: Node3D) -> void:
	for plaza in map.get_children():
		if not plaza is Plaza or not plaza.has_node("Paving"): continue
		if plaza.space.name != "south side of the shop row road": continue
		var trees: Array = plaza.space.trees
		if trees.size() < 19: continue
		var furniture := new()
		furniture.name = "Furniture"
		plaza.add_child(furniture)
		furniture.position = map.on_ground(plaza.space.x,plaza.space.back)
		furniture.collision_mask = 0
		for index: int in [1,5,8,10,14,16]:
			var tree: Array = trees[index]
			var foot: Vector3 = map.on_ground(tree[0]+2.1,tree[1]+2.3,Plaza.LIFT)
			furniture.bench(furniture.to_local(foot),index)
		for index: int in [0,4,9,13,17]:
			var tree: Array = trees[index]
			var foot: Vector3 = map.on_ground(tree[0]+4.5,tree[1]+1.8,Plaza.LIFT)
			furniture.lamp(furniture.to_local(foot),index)
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = furniture.shell.commit()
		furniture.add_child(mesh_instance)

func collision(at: Vector3, size: Vector3, label: String) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var node := CollisionShape3D.new()
	node.name = label
	node.position = at
	node.shape = shape
	add_child(node)

func bench(foot: Vector3, index: int) -> void:
	var frame := Transform3D(Basis.IDENTITY,foot)
	# Two timber seat boards drain through the centre gap. Cast pedestals carry
	# the seat rails and the backrest, with an arm at each end.
	for x: float in [-0.68,0.68]:
		shell.box(frame,Vector3(x,0.045,0),Vector3(0.20,0.09,0.49),STONE)
		shell.box(frame,Vector3(x,0.22,0.01),Vector3(0.105,0.29,0.31),STEEL)
		shell.box(frame,Vector3(x,0.38,0),Vector3(0.14,0.075,0.49),STEEL)
		shell.box(frame,Vector3(x,0.59,0.219),Vector3(0.075,0.46,0.065),STEEL)
		shell.box(frame,Vector3(x,0.53,-0.16),Vector3(0.055,0.22,0.055),STEEL)
		shell.box(frame,Vector3(x,0.65,0.018),Vector3(0.065,0.05,0.42),STEEL)
	for z: float in [-0.126,0.116]:
		shell.box(frame,Vector3(0,0.437,z),Vector3(1.88,0.055,0.227),CEDAR)
	var back := frame.translated_local(Vector3(0,0.735,0.196))
	back.basis = Basis(Vector3.RIGHT,deg_to_rad(8))
	shell.box(back,Vector3.ZERO,Vector3(1.88,0.22,0.048),CEDAR)
	collision(foot+Vector3(0,0.23,0),Vector3(1.88,0.46,0.48),"Seat%d"%index)
	collision(foot+Vector3(0,0.65,0.20),Vector3(1.88,0.39,0.08),"SeatBack%d"%index)

func lamp(foot: Vector3, index: int) -> void:
	var frame := Transform3D(Basis.IDENTITY,foot)
	shell.drum(frame.translated_local(Vector3.UP*0.07),0.17,0.14,12,STONE)
	shell.drum(frame.translated_local(Vector3.UP*0.25),0.11,0.28,12,STEEL)
	shell.drum(frame.translated_local(Vector3.UP*1.95),0.068,3.40,12,STEEL)
	shell.box(frame,Vector3(0,3.62,0.245),Vector3(0.10,0.10,0.53),STEEL)
	shell.box(frame,Vector3(0,3.58,0.57),Vector3(0.34,0.12,0.47),STEEL)
	shell.box(frame,Vector3(0,3.51,0.57),Vector3(0.28,0.021,0.39),Color("#ece5c9"))
	collision(foot+Vector3.UP*1.82,Vector3(0.16,3.64,0.16),"LampPost%d"%index)
	var light := SpotLight3D.new()
	light.position = foot+Vector3(0,3.49,0.57)
	light.rotation.x = -PI/2
	light.light_color = Color("#ffe3ab")
	light.light_energy = 0.65
	light.spot_range = 6.0
	light.spot_angle = 52.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 22.0
	light.distance_fade_length = 10.0
	add_child(light)
