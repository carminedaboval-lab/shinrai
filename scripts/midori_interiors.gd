extends RefCounted
## Lights every enterable room and furnishes the homes on top of their existing
## colliding fixtures, which keep their loot anchors. Each home gets its own
## palette; additions are batched per building and draw only when nearby.
const Kit = preload("res://scripts/midori_park_kit.gd")
const HOME_STYLES := [
	{"fabric":Color("#5a6b73"), "rug":Color("#7a3b34"), "accent":Color("#c98f3c"), "lamp":Color("#ffd2a0")},
	{"fabric":Color("#7a6a55"), "rug":Color("#2f4a55"), "accent":Color("#b5483f"), "lamp":Color("#ffe0bc")},
	{"fabric":Color("#3f5a4c"), "rug":Color("#8a7a5c"), "accent":Color("#d9b65a"), "lamp":Color("#ffc994")},
	{"fabric":Color("#6d4a55"), "rug":Color("#3a3f52"), "accent":Color("#7fb5c4"), "lamp":Color("#f2e6ff")},
	{"fabric":Color("#55606e"), "rug":Color("#6b4a32"), "accent":Color("#e07a4a"), "lamp":Color("#ffd8ad")},
	{"fabric":Color("#8a7f6b"), "rug":Color("#44524a"), "accent":Color("#4f86a8"), "lamp":Color("#dfeaff")},
]
const SHOP_LIGHT := {"UedaBooks":Color("#ffd9b0"), "MoriCoffee":Color("#ffc9a0"), "HinataDaily":Color("#e8f3ff"), "YakitoriShop":Color("#ffb47a")}
const SHOP_COVE := {"UedaBooks":Color("#ffe2bd"), "MoriCoffee":Color("#ff9d6e"), "HinataDaily":Color("#bfe6ff"), "YakitoriShop":Color("#ff7a3a")}
const KADO := "KadoMakerWorkroom"
const DRAW_RANGE_M := 60.0

static func build(neon: Node3D) -> Dictionary:
	var street: Node3D = neon.get("street")
	var homes := 0
	var shops := 0
	for row: Dictionary in street.get_meta("building_access_registry", []):
		var house := street.get_node_or_null(NodePath(str(row.root_path))) as Node3D
		if house == null: house = neon.get_node(NodePath(str(row.root_path))) as Node3D
		var dims: Dictionary = row.dimensions
		var root := _root(neon, house)
		if SHOP_LIGHT.has(str(row.id)):
			_light_shop(neon, root, str(row.id), dims)
			shops += 1
		else:
			_furnish_home(neon, root, dims, HOME_STYLES[homes % HOME_STYLES.size()])
			homes += 1
		_finish(street, root)
	var kado := street.find_child(KADO, true, false) as Node3D
	if kado != null:
		var root := _root(neon, kado)
		_lamp(neon, root, Vector3(0, 3.1, 0), Color("#ffe0bc"), 1.1, 2.6, 8.0)
		Kit.box(root, "BenchLightBar", Vector3(2.0, .03, .08), Vector3(1.8, 2.05, 3.5), neon._glow(Color("#fff0d8")))
		_finish(street, root)
	return {"homes":homes, "shops":shops, "lights":(neon.get("_interior_lights") as Array).size()}

static func _root(neon: Node3D, building: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = String(building.name) + "Interior"
	neon.add_child(root)
	root.global_transform = building.global_transform.orthonormalized()
	return root

static func _finish(street: Node3D, root: Node3D) -> void:
	street.call("_batch_direct_geometry", root)
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var visual := node as GeometryInstance3D
		visual.visibility_range_end = DRAW_RANGE_M
		visual.visibility_range_end_margin = 8.0
		visual.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

static func _lamp(neon: Node3D, root: Node3D, at: Vector3, color: Color, day: float, night: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.name = "RoomLight"
	light.position = at
	light.light_color = color
	light.omni_range = reach
	light.omni_attenuation = 1.1
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 42.0
	light.distance_fade_length = 14.0
	root.add_child(light)
	(neon.get("_interior_lights") as Array).append([light, day, night])

static func _light_shop(neon: Node3D, root: Node3D, id: String, dims: Dictionary) -> void:
	var w := float(dims.width_m)
	_lamp(neon, root, Vector3(0, 2.5, 5.6), SHOP_LIGHT[id], 1.0, 2.8, 9.0)
	_lamp(neon, root, Vector3(0, 2.5, 2.2), SHOP_LIGHT[id], .7, 1.6, 7.0)
	_lamp(neon, root, Vector3(0, .5, 4.0), SHOP_LIGHT[id], .4, .8, 6.5)
	Kit.box(root, "BackCove", Vector3(w * .8, .03, .04), Vector3(0, 2.72, 7.55), neon._glow(SHOP_COVE[id]))

static func _pendant(neon: Node3D, root: Node3D, at: Vector3, drop: float, shade: Material, lamp: Color) -> void:
	Kit.tube(root, "PendantCord", at, at + Vector3.DOWN * drop, .006, shade)
	var mesh := CylinderMesh.new()
	mesh.top_radius = .05
	mesh.bottom_radius = .2
	mesh.height = .17
	mesh.radial_segments = 16
	var dome := MeshInstance3D.new()
	dome.name = "PendantShade"
	dome.mesh = mesh
	dome.material_override = shade
	dome.position = at + Vector3.DOWN * (drop + .08)
	root.add_child(dome)
	Kit.disc(root, "PendantBulb", .15, .02, at + Vector3.DOWN * (drop + .17), neon._glow(lamp))

static func _furnish_home(neon: Node3D, root: Node3D, dims: Dictionary, style: Dictionary) -> void:
	var w := float(dims.width_m)
	var d := float(dims.depth_m)
	var f := float(dims.front_z_m)
	var g := float(dims.ground_floor_m)
	var u := float(dims.upper_floor_m)
	var h := float(dims.height_m)
	var lamp: Color = style.lamp
	var fabric := Kit.mat(style.fabric, .95)
	var rug := Kit.mat(style.rug, 1.0)
	var accent := Kit.mat(style.accent, .85)
	var cream := Kit.mat(Color("#d8d1c0"), .9)
	var walnut := Kit.mat(Color("#5b4331"), .6)
	var dark := Kit.mat(Color("#23262a"), .5, .4)
	var tile := Kit.mat(Color("#b9b6ac"), .5)
	var table := Vector3(.25, g, f + 3.2)
	# Room light hangs over the table; the bulb is visible from the door.
	_pendant(neon, root, Vector3(table.x, u - .1, table.z), u - g - 2.1, dark, lamp)
	_lamp(neon, root, Vector3(table.x, g + 2.0, table.z), lamp, .8, 2.4, 7.5)
	_lamp(neon, root, Vector3(w * .25, g + 2.2, f + d - 1.7), lamp.lerp(Color.WHITE, .3), .5, 1.5, 5.5)
	_lamp(neon, root, Vector3(0, u + 1.9, f + d * .6), lamp, .7, 2.0, 7.0)
	# Stands in for light bouncing off the floor, so furniture sides are not black.
	_lamp(neon, root, Vector3(.6, g + .5, f + d * .5), lamp, .5, .9, 6.5)
	Kit.disc(root, "UpperCeilingLight", .3, .03, Vector3(0, h - .24, f + d * .6), neon._glow(lamp))
	# Living area: rug, chairs and a sofa shell fitted over the colliding base.
	Kit.box(root, "RugBorder", Vector3(3.3, .012, 2.3), table + Vector3(.1, .008, .1), accent)
	Kit.box(root, "Rug", Vector3(3.14, .014, 2.14), table + Vector3(.1, .01, .1), rug)
	for side: float in [-.42, .42]:
		var seat := table + Vector3(side, 0, .66)
		Kit.box(root, "ChairSeat", Vector3(.42, .04, .42), seat + Vector3.UP * .45, walnut)
		Kit.box(root, "ChairBack", Vector3(.42, .42, .03), seat + Vector3(0, .68, .2), walnut)
		for lx: float in [-.18, .18]:
			for lz: float in [-.18, .18]:
				Kit.tube(root, "ChairLeg", seat + Vector3(lx, 0, lz), seat + Vector3(lx, .44, lz), .014, walnut)
		Kit.solid(root, "ChairBlock", Vector3(.42, .9, .42), seat + Vector3.UP * .45)
	var sofa := Vector3(w * .5 - 1.35, g, f + 3.3)
	Kit.box(root, "SofaShell", Vector3(1.7, .79, .74), sofa + Vector3.UP * .395, fabric)
	Kit.box(root, "SofaBack", Vector3(1.7, .46, .18), sofa + Vector3(0, 1.0, .29), fabric)
	for side: float in [-1.0, 1.0]:
		Kit.box(root, "SofaArm", Vector3(.14, .98, .76), sofa + Vector3(side * .87, .49, 0), fabric)
		Kit.box(root, "SofaCushion", Vector3(.78, .11, .54), sofa + Vector3(side * .4, .845, -.09), fabric.duplicate())
		Kit.box(root, "ThrowPillow", Vector3(.34, .3, .1), sofa + Vector3(side * .52, 1.05, .15), accent)
	# Digital picture wall over the sofa.
	var frame := Vector3(w * .5 - .27, g + 1.75, f + 3.3)
	Kit.box(root, "FrameEdge", Vector3(.03, .76, 1.26), frame, dark)
	neon._screen(root, "HomeFrame", frame + Vector3(-.02, 0, 0), -PI * .5, Vector2(1.16, .66), style.accent, style.rug)
	# Kitchen: wall units over the counter and a fridge at its near end.
	var kitchen := Vector3(w * .5 - .67, g, f + d - 1.2)
	Kit.box(root, "WallCabinet", Vector3(.36, .72, 1.8), Vector3(w * .5 - .44, g + 1.85, kitchen.z), cream)
	Kit.box(root, "CabinetUnderLight", Vector3(.05, .02, 1.7), Vector3(w * .5 - .6, g + 1.47, kitchen.z), neon._glow(lamp))
	var fridge_z := kitchen.z - 1.36
	if fridge_z - .36 > f + 3.9:
		Kit.box(root, "Fridge", Vector3(.72, 1.86, .7), Vector3(w * .5 - .62, g + .93, fridge_z), Kit.mat(Color("#a9adb0"), .35, .6))
		Kit.solid(root, "FridgeBlock", Vector3(.72, 1.86, .7), Vector3(w * .5 - .62, g + .93, fridge_z))
		neon._screen(root, "FridgePanel", Vector3(w * .5 - .985, g + 1.4, fridge_z), -PI * .5, Vector2(.3, .2), style.accent, Color("#22d3ff"))
	# The WC gets a tiled cubicle, open on the side its loot is reached from.
	var wc := Vector3(.15, g, f + d - 1.0)
	var back := f + d - .24
	var front := f + d - 1.75
	for panel: Array in [[Vector3(.06, 2.3, back - front), Vector3(wc.x - .62, g + 1.15, (back + front) * .5)], [Vector3(.74, 2.3, .06), Vector3(wc.x - .28, g + 1.15, front)], [Vector3(.06, 2.3, .55), Vector3(wc.x + .64, g + 1.15, back - .27)]]:
		Kit.box(root, "CubiclePanel", panel[0], panel[1], tile)
		Kit.solid(root, "CubicleBlock", panel[0], panel[1])
	# Low sideboard on the back wall with books and a plant.
	var board := Vector3(-w * .5 + 1.2, g, f + d - .46)
	Kit.box(root, "Sideboard", Vector3(1.3, .74, .36), board + Vector3.UP * .37, walnut)
	Kit.solid(root, "SideboardBlock", Vector3(1.3, .74, .36), board + Vector3.UP * .37)
	for i: int in range(5):
		Kit.box(root, "Book", Vector3(.05, .24, .18), board + Vector3(-.5 + float(i) * .06, .86, 0), accent if i % 2 == 0 else cream)
	Kit.disc(root, "PlantPot", .1, .18, board + Vector3(.42, .83, 0), cream)
	Kit.disc(root, "PlantCrown", .17, .3, board + Vector3(.42, 1.07, 0), Kit.mat(Color("#34573c"), .9))
	# Bedroom dressing around the colliding bed.
	var bed := Vector3(w * .5 - 1.25, u, f + minf(5.15, d - 2.0))
	Kit.box(root, "Duvet", Vector3(1.41, .14, 1.46), bed + Vector3(0, .5, -.26), fabric)
	Kit.box(root, "DuvetFold", Vector3(1.42, .15, .3), bed + Vector3(0, .51, .3), cream)
	Kit.box(root, "Pillows", Vector3(1.1, .14, .4), bed + Vector3(0, .6, .74), cream)
	Kit.box(root, "Headboard", Vector3(1.5, 1.05, .07), bed + Vector3(0, .52, 1.04), walnut)
	Kit.box(root, "BedRug", Vector3(1.5, .012, 1.0), bed + Vector3(-1.32, .008, -.1), rug)
	Kit.box(root, "SideTable", Vector3(.42, .5, .42), bed + Vector3(-.96, .25, .78), walnut)
	Kit.solid(root, "SideTableBlock", Vector3(.42, .5, .42), bed + Vector3(-.96, .25, .78))
	Kit.disc(root, "BedsideLamp", .09, .22, bed + Vector3(-.96, .62, .78), neon._glow(lamp))
