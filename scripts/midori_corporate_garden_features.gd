extends RefCounted
## The built parts of the corporate gardens, after Tokyo Midtown: poured permeable
## paths, a granite stream with terraced pools and weirs in black and buff stone,
## Ipe deck bridges, granite seat walls and bamboo in raised planters. The two
## monuments are original work for Trust City, not copies of Midtown's sculptures.
## Coordinates are district space.
const Lawn = preload("res://scripts/midori_corporate_lawn.gd")
const Surfaces = preload("res://scripts/midori_corporate_garden_surfaces.gdshader")
const BUFF := Color(.70, .64, .54)
const BLACK := Color(.21, .21, .22)
const WATER := Color(.20, .31, .36)
const PATH := Color(.84, .79, .69)
const IPE := Color("5b3a26")
const SEAT_WALLS: Array[float] = [-23.0, -3.0]

static func build(district: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "CorporateGardenFeatures"
	root.set_meta("creator_protected", true)
	district.add_child(root)
	var mats := {
		"buff":_surface(1, BUFF), "black":_surface(1, BLACK), "water":_surface(2, WATER), "path":_surface(0, PATH), "foam":_surface(3, WATER),
		"ipe":district.call("mat", IPE, .62),
		"steel":_steel(),
	}
	for child: Node in district.get_children():
		if str(child.name).contains("GardenWalk"): (child as MeshInstance3D).material_override = mats.path
	var bamboo := _bamboo_mesh()
	for i: int in range(Lawn.GARDENS.size()):
		var garden: Rect2 = Lawn.GARDENS[i]
		var walk_z: float = Lawn.WALK_Z[i]
		_stream(district, root, Lawn.channel(garden, walk_z), mats)
		_pools(district, root, Lawn.pools(walk_z), mats)
		_bridge(root, walk_z, mats)
		for x: float in SEAT_WALLS:
			_seat_wall(district, Vector3(x, 0, walk_z - 2.7), mats)
		for x: float in [-31.0, 31.0]:
			_bamboo_planter(district, root, Vector3(x, 0, walk_z + 9.0), bamboo, mats)
	_trust_monument(district, Vector3(-12, 0, Lawn.WALK_Z[0] + 11.0), mats)
	_ring_monument(district, Vector3(-12, 0, Lawn.WALK_Z[1] + 10.0), mats)
	return {"streams":Lawn.GARDENS.size(), "monuments":2}

static func _surface(kind: int, tone: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Surfaces
	material.set_shader_parameter("kind", kind)
	material.set_shader_parameter("tone", tone)
	return material

static func _steel() -> StandardMaterial3D:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(.78, .8, .82)
	steel.metallic = .95
	steel.roughness = .2
	return steel

static func _box(parent: Node3D, label: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

static func _stream(district: Node3D, root: Node3D, rect: Rect2, mats: Dictionary) -> void:
	var centre := rect.get_center()
	# Low enough to step across, so the player does not wade through the rims.
	var solid: Node3D = district.call("box", "StreamBlock", Vector3(rect.size.x, .16, rect.size.y), Vector3(centre.x, .08, centre.y), null, true)
	solid.visible = false
	_box(root, "StreamBed", Vector3(rect.size.x, .06, rect.size.y), Vector3(centre.x, .01, centre.y), mats.black)
	_box(root, "StreamWater", Vector3(rect.size.x - .3, .02, rect.size.y), Vector3(centre.x, .07, centre.y), mats.water)
	for side: float in [-1.0, 1.0]:
		_box(root, "StreamRim", Vector3(.15, .16, rect.size.y), Vector3(centre.x + side * (rect.size.x * .5 - .075), .08, centre.y), mats.buff)

## Three terraced pools stepping down a metre toward the walk, each spilling white
## over a buff weir. Jets feed the top pool. Midtown's stream falls 30 m; this site
## is flat, so the fall is built up in stone. The solid block stops the player.
static func _pools(district: Node3D, root: Node3D, pools: Array[Rect2], mats: Dictionary) -> void:
	for i: int in range(pools.size()):
		var rect := pools[i]
		var centre := rect.get_center()
		var top := .36 + float(i) * .3
		var below := .08 if i == 0 else .36 + float(i - 1) * .3 - .05
		var solid: Node3D = district.call("box", "PoolBlock", Vector3(rect.size.x, top, rect.size.y), Vector3(centre.x, top * .5, centre.y), null, true)
		solid.visible = false
		_box(root, "PoolFloor", Vector3(rect.size.x, .04, rect.size.y), Vector3(centre.x, top - .2, centre.y), mats.black)
		_box(root, "PoolWater", Vector3(rect.size.x - .4, .02, rect.size.y - .4), Vector3(centre.x, top - .05, centre.y), mats.water)
		for side: float in [-1.0, 1.0]:
			_box(root, "PoolWall", Vector3(.2, top, rect.size.y), Vector3(centre.x + side * (rect.size.x * .5 - .1), top * .5, centre.y), mats.black)
		_box(root, "PoolWall", Vector3(rect.size.x - .4, top, .2), Vector3(centre.x, top * .5, rect.end.y - .1), mats.black)
		_box(root, "PoolWeir", Vector3(rect.size.x - .4, top - .07, .2), Vector3(centre.x, (top - .07) * .5, rect.position.y + .1), mats.buff)
		var drop := top - .05 - below
		_box(root, "WeirFall", Vector3(rect.size.x - .5, drop, .03), Vector3(centre.x, below + drop * .5, rect.position.y - .02), mats.foam)
		_box(root, "WeirFoam", Vector3(rect.size.x - .5, .025, .3), Vector3(centre.x, below + .015, rect.position.y - .17), mats.foam)
	var head := pools[pools.size() - 1]
	for i: int in range(5):
		var jet := MeshInstance3D.new()
		jet.name = "PoolJet"
		var mesh := CylinderMesh.new()
		mesh.top_radius = .008
		mesh.bottom_radius = .03
		mesh.height = .55
		mesh.radial_segments = 8
		jet.mesh = mesh
		jet.material_override = mats.foam
		jet.position = Vector3(head.position.x + 1.0 + float(i), .96 + .275, head.end.y - .7)
		root.add_child(jet)

static func _bridge(root: Node3D, walk_z: float, mats: Dictionary) -> void:
	var width := 3.0
	var z := walk_z - 2.15
	while z < walk_z + 2.15:
		_box(root, "BridgeSlat", Vector3(width, .05, .135), Vector3(Lawn.STREAM_X, .06, z + .07), mats.ipe)
		z += .15
	for side: float in [-1.0, 1.0]:
		_box(root, "BridgeKerb", Vector3(.14, .12, 4.5), Vector3(Lawn.STREAM_X + side * (width * .5 + .07), .06, walk_z), mats.black)

static func _seat_wall(district: Node3D, at: Vector3, mats: Dictionary) -> void:
	district.call("box", "GraniteSeatWall", Vector3(6, .4, .5), at + Vector3(0, .2, 0), mats.buff, true)
	district.call("box", "GraniteSeatCap", Vector3(6.06, .06, .56), at + Vector3(0, .43, 0), mats.black, false)

## Two black slabs leaning on each other, one unable to stand without the other.
static func _trust_monument(district: Node3D, at: Vector3, mats: Dictionary) -> void:
	district.call("box", "TrustPlinth", Vector3(7.5, .3, 4.6), at + Vector3(0, .15, 0), mats.buff, true)
	district.call("box", "TrustPlinthBand", Vector3(7.56, .06, 4.66), at + Vector3(0, .31, 0), mats.black, false)
	for side: float in [-1.0, 1.0]:
		var slab: Node3D = district.call("box", "TrustSlab", Vector3(1.5, 8.0, .42), at + Vector3(side * 1.12, 4.1, 0), mats.black, true)
		slab.rotation.z = side * .1
	district.call("box", "TrustTablet", Vector3(2.6, .9, .14), at + Vector3(0, .79, 1.92), mats.buff, true)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Yu Gothic", "Meiryo", "Noto Sans CJK JP", "sans-serif"])
	font.font_weight = 500
	var plaque := Label3D.new()
	plaque.name = "TrustPlaque"
	plaque.text = "信頼\nTRUST CITY"
	plaque.font = font
	plaque.font_size = 72
	plaque.pixel_size = .008
	plaque.outline_size = 0
	plaque.modulate = Color(.1, .1, .11)
	plaque.position = at + Vector3(0, .85, 2.0)
	plaque.double_sided = false
	district.add_child(plaque)

## A polished steel ring standing on a black plinth, framing the garden behind it.
static func _ring_monument(district: Node3D, at: Vector3, mats: Dictionary) -> void:
	district.call("box", "RingPlinth", Vector3(4.2, .5, 2.2), at + Vector3(0, .25, 0), mats.black, true)
	var ring := MeshInstance3D.new()
	ring.name = "ServiceRing"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 2.05
	mesh.outer_radius = 2.4
	mesh.rings = 96
	mesh.ring_segments = 32
	ring.mesh = mesh
	ring.material_override = mats.steel
	ring.position = at + Vector3(0, 2.72, 0)
	ring.rotation.x = PI * .5
	district.add_child(ring)
	district.call("box", "RingFoot", Vector3(.5, .4, .5), at + Vector3(0, .6, 0), mats.steel, false)

static func _bamboo_planter(district: Node3D, root: Node3D, at: Vector3, bamboo: Mesh, mats: Dictionary) -> void:
	district.call("box", "BambooPlanter", Vector3(2.2, .55, 6.0), at + Vector3(0, .275, 0), mats.black, true)
	_box(root, "BambooSoil", Vector3(1.96, .03, 5.76), at + Vector3(0, .55, 0), mats.black)
	var clump := MeshInstance3D.new()
	clump.name = "Bamboo"
	clump.mesh = bamboo
	clump.position = at + Vector3(0, .55, 0)
	clump.visibility_range_end = 220.0
	root.add_child(clump)

## Thin jointed culms in a 2 x 6 m bed, with sprays of narrow leaves on their upper parts.
static func _bamboo_mesh() -> ArrayMesh:
	var culms := StandardMaterial3D.new()
	culms.vertex_color_use_as_albedo = true
	culms.roughness = .42
	var leaves := StandardMaterial3D.new()
	leaves.vertex_color_use_as_albedo = true
	leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaves.roughness = .55
	var stems := SurfaceTool.new()
	stems.begin(Mesh.PRIMITIVE_TRIANGLES)
	var foliage := SurfaceTool.new()
	foliage.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261031
	for i: int in range(46):
		var base := Vector3(rng.randf_range(-.85, .85), 0, rng.randf_range(-2.75, 2.75))
		var height := rng.randf_range(4.6, 6.6)
		var lean := Vector3(rng.randf_range(-.5, .5), 0, rng.randf_range(-.5, .5))
		_culm(stems, base, height, lean, rng)
		for s: int in range(46):
			var t := rng.randf_range(.38, 1.0)
			_leaf(foliage, base + Vector3(0, height * t, 0) + lean * t * t, rng)
	stems.generate_normals()
	var mesh := stems.commit()
	mesh.surface_set_material(0, culms)
	foliage.commit(mesh)
	mesh.surface_set_material(1, leaves)
	return mesh

static func _culm(tool: SurfaceTool, base: Vector3, height: float, lean: Vector3, rng: RandomNumberGenerator) -> void:
	var radius := rng.randf_range(.016, .03)
	var green := Color(.34, .47, .2).lerp(Color(.5, .54, .26), rng.randf())
	var joints := 11
	for j: int in range(joints):
		var t0 := float(j) / float(joints)
		var t1 := float(j + 1) / float(joints)
		var a := base + Vector3(0, height * t0, 0) + lean * t0 * t0
		var b := base + Vector3(0, height * t1, 0) + lean * t1 * t1
		var r0 := radius * (1.0 - t0 * .7)
		var r1 := radius * (1.0 - t1 * .7)
		tool.set_color(green.darkened(.3))
		for side: int in range(6):
			var u0 := Vector3(cos(TAU * float(side) / 6.0), 0, sin(TAU * float(side) / 6.0))
			var u1 := Vector3(cos(TAU * float(side + 1) / 6.0), 0, sin(TAU * float(side + 1) / 6.0))
			for point: Vector3 in [a + u0 * r0 * 1.25, b + u0 * r1, b + u1 * r1, a + u0 * r0 * 1.25, b + u1 * r1, a + u1 * r0 * 1.25]:
				tool.set_color(green.darkened(.28) if point.distance_to(a) < r0 * 1.5 else green)
				tool.add_vertex(point)

static func _leaf(tool: SurfaceTool, at: Vector3, rng: RandomNumberGenerator) -> void:
	var colour := Color(.2, .34, .12).lerp(Color(.38, .48, .17), rng.randf())
	for i: int in range(5):
		var yaw := rng.randf_range(0.0, TAU)
		var out := Vector3(cos(yaw), rng.randf_range(-.55, -.1), sin(yaw)).normalized()
		var length := rng.randf_range(.16, .28)
		var side := out.cross(Vector3.UP).normalized() * length * .1
		var root := at + Vector3(cos(yaw), 0, sin(yaw)) * rng.randf_range(.05, .32)
		var normal := out.cross(side).normalized()
		for point: Vector3 in [root, root + out * length * .4 + side, root + out * length, root, root + out * length, root + out * length * .4 - side]:
			tool.set_color(colour)
			tool.set_normal(normal)
			tool.add_vertex(point)
