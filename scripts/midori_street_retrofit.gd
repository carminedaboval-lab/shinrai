extends RefCounted
## Turns the quiet street into a lived-in 2050 one: darker weathered materials
## across every building, then lit coves, conduit, plant and vending machines.
## Called by the neon street once the shops exist, so it can reuse its screens.
const Kit = preload("res://scripts/midori_park_kit.gd")
# Width and eave height of each shop, as built by the street architecture.
const SHOPS := {
	"UedaBooks":{"w":11.0, "eave":6.35}, "MoriCoffee":{"w":10.0, "eave":6.8},
	"HinataDaily":{"w":10.0, "eave":6.4}, "YakitoriShop":{"w":5.2, "eave":5.75},
}
# Only the roof tile is recoloured. Walls and timber darken in the grime pass,
# which stops at each building's inner walls so rooms keep their own colours.
const PALETTE := {"arch_tile":Color("#34373c")}
const KADO_FOOTPRINT := Rect2(-25, 246, 9, 9)
const WEATHERED := ["arch_plaster","arch_mineral","arch_stone","arch_cedar","arch_cladding_backing"]

const GRIME_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_back, fog_disabled;
uniform vec3 tone = vec3(0.6);
uniform vec4 indoors[16];
uniform int indoor_count = 0;
varying vec3 world;
float hsh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float nz(vec2 p){ vec2 c = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hsh(c), hsh(c+vec2(1,0)), u.x), mix(hsh(c+vec2(0,1)), hsh(c+vec2(1,1)), u.x), u.y); }
void vertex(){ world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	for (int i = 0; i < indoor_count; i++) {
		vec4 r = indoors[i];
		if (world.x > r.x && world.z > r.y && world.x < r.z && world.z < r.w) discard;
	}
	float along = world.x + world.z;
	// Rain tracks run down from ledges; damp creeps up from the ground.
	float tracks = nz(vec2(along * 2.3, world.y * 0.11)) * 0.65 + nz(vec2(along * 7.0, world.y * 0.3)) * 0.35;
	float rain = smoothstep(0.5, 0.8, tracks) * (0.35 + 0.65 * nz(vec2(along * 0.3, 4.0)));
	float rising = 1.0 - smoothstep(0.1, 1.5, world.y + (nz(vec2(along * 1.1, 9.0)) - 0.5) * 0.9);
	float patches = smoothstep(0.4, 0.75, nz(vec2(along, world.y) * 0.42));
	ALBEDO = tone * (1.0 - 0.4 * rain - 0.34 * rising - 0.14 * patches);
}
"""

static func build(neon: Node3D) -> Dictionary:
	var report := {"materials":_restyle_materials(neon)}
	var cable := Kit.mat(Color("#14171a"), .6, .4)
	for shop_name: String in SHOPS:
		var root: Node3D = neon.shop_roots.get(shop_name)
		if root == null: continue
		_dress_exterior(neon, root, shop_name, cable)
	_side_plant(neon)
	_mori_billboard(neon)
	_vending(neon, Vector3(-15.1, .09, 193.1), [Color("#ff3048"), Color("#2c8dff")])
	_vending(neon, Vector3(26.4, .09, 193.1), [Color("#22d38a"), Color("#ffb03a")])
	return report

static func _restyle_materials(neon: Node3D) -> int:
	var street: Node = neon.get("street")
	var wall_grime := _grime(Vector3(.46, .48, .52))
	var timber_grime := _grime(Vector3(.5, .46, .44))
	var rooms := _indoor_rects(street)
	for grime: ShaderMaterial in [wall_grime, timber_grime]:
		grime.set_shader_parameter("indoors", rooms)
		grime.set_shader_parameter("indoor_count", rooms.size())
	var mats: Dictionary = street.get("materials")
	for key: Variant in PALETTE:
		if mats.get(key) is StandardMaterial3D: (mats[key] as StandardMaterial3D).albedo_color = PALETTE[key]
	# Cladding backing doubles as the inside face of timber homes. Lighten it for
	# the rooms; the grime pass keeps it dark between boards outdoors.
	if mats.get("arch_cladding_backing") is StandardMaterial3D:
		(mats.arch_cladding_backing as StandardMaterial3D).albedo_color = Color("#b3a792")
	var restyled := {}
	# Walls and timber use per-property shaders, so they are darkened by a
	# multiply pass rather than by editing each one. Every house keeps its hue.
	for node: Node in street.find_children("*", "MeshInstance3D", true, false):
		var visual := node as MeshInstance3D
		if visual.mesh == null: continue
		for surface: int in range(visual.mesh.get_surface_count()):
			var material: Material = visual.material_override if visual.material_override != null else visual.mesh.surface_get_material(surface)
			if material == null or restyled.has(material): continue
			var label := material.resource_name.trim_prefix("SouthStreet_")
			if label.begins_with("land_") or "Road" in label: continue # Road paint and kerbs are not walls.
			if PALETTE.has(label) and material is StandardMaterial3D:
				(material as StandardMaterial3D).albedo_color = PALETTE[label]
			if label == "arch_cladding_backing" and material is StandardMaterial3D:
				(material as StandardMaterial3D).albedo_color = Color("#b3a792")
			if label in WEATHERED or "Mineral" in label or "Paint" in label or "Render" in label or "Plaster" in label:
				material.next_pass = wall_grime
			elif "Timber" in label or "joinery" in label:
				material.next_pass = timber_grime
			else:
				continue
			restyled[material] = true
	return restyled.size()

static func _indoor_rects(street: Node3D) -> PackedVector4Array:
	# Footprints inset to sit inside each wall's thickness: outer faces stay weathered.
	var rects := PackedVector4Array([Vector4(KADO_FOOTPRINT.position.x + .12, KADO_FOOTPRINT.position.y + .12, KADO_FOOTPRINT.end.x - .12, KADO_FOOTPRINT.end.y - .12)])
	for row: Dictionary in street.get_meta("building_access_registry", []):
		var house := street.get_tree().root.get_node_or_null(NodePath(str(row.root_path))) as Node3D
		if house == null: continue
		var half := float(row.dimensions.width_m) * .5 - .12
		var front := float(row.dimensions.front_z_m) + .12
		var a := house.to_global(Vector3(-half, 0, front))
		var b := house.to_global(Vector3(half, 0, front + float(row.dimensions.depth_m) - .24))
		rects.append(Vector4(minf(a.x, b.x), minf(a.z, b.z), maxf(a.x, b.x), maxf(a.z, b.z)))
	return rects

static func _grime(tone: Vector3) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = GRIME_SHADER
	var grime := ShaderMaterial.new()
	grime.shader = shader
	grime.resource_name = "SHINRAI_BuildingGrime"
	grime.set_shader_parameter("tone", tone)
	return grime

static func _dress_exterior(neon: Node3D, root: Node3D, shop_name: String, cable: Material) -> void:
	var width: float = SHOPS[shop_name].w
	var eave: float = SHOPS[shop_name].eave
	var color: Color = neon.WASH[shop_name]
	# Hidden coves: light falls down the wall from under the eave and balcony.
	Kit.box(root, "EaveCove", Vector3(width * .94, .03, .04), Vector3(0, eave - .1, -.26), neon._glow(color.lerp(Color.WHITE, .15)))
	if shop_name != "YakitoriShop":
		Kit.box(root, "BalconyCove", Vector3(width * .9, .03, .05), Vector3(0, 3.66, -.72), neon._glow(color))
	# Surface-run conduit, the honest retrofit of an old building.
	var x := width * .5 - .2
	for offset: float in [0.0, .09, .18]:
		Kit.tube(root, "Conduit", Vector3(x - offset, .25, -.3), Vector3(x - offset, eave - .2, -.3), .022, cable)
	Kit.box(root, "JunctionBox", Vector3(.36, .46, .12), Vector3(x - .09, 1.5, -.33), cable)
	Kit.box(root, "JunctionBox", Vector3(.3, .3, .1), Vector3(x - .09, eave - .55, -.33), cable)
	# Ground-floor plinth in dark steel, kicking up the damp line.
	Kit.box(root, "SteelPlinth", Vector3(width * .96, .34, .05), Vector3(0, .18, -.3), Kit.mat(Color("#1c1f22"), .5, .7))

static func _side_plant(neon: Node3D) -> void:
	# Stacked outdoor units on the blank gables, below the LED walls.
	var ueda: Node3D = neon.shop_roots.get("UedaBooks")
	var hinata: Node3D = neon.shop_roots.get("HinataDaily")
	for i: int in range(6):
		var row := i % 2
		var column := i / 2
		if ueda != null: neon._air_conditioner(ueda, Vector3(5.72, .6 + float(row) * .72, 1.4 + float(column) * 1.1), -PI * .5)
		if hinata != null: neon._air_conditioner(hinata, Vector3(-5.2, .6 + float(row) * .72, 1.4 + float(column) * 1.1), PI * .5)

static func _mori_billboard(neon: Node3D) -> void:
	var root: Node3D = neon.shop_roots.get("MoriCoffee")
	if root == null: return
	var steel := Kit.mat(Color("#25282c"), .5, .7)
	var roof := 7.0
	for x: float in [-2.7, 2.7]:
		Kit.tube(root, "BillboardLeg", Vector3(x, roof, 1.0), Vector3(x, roof + 1.0, 1.0), .07, steel)
		Kit.tube(root, "BillboardBrace", Vector3(x, roof, 2.2), Vector3(x, roof + 1.0, 1.0), .05, steel)
	neon._wall_screen(root, Vector3(0, roof + 2.25, 1.0), PI, Vector2(6.0, 2.5), Color("#22d3ff"), Color("#a14dff"), "新東京")

static func _vending(neon: Node3D, at: Vector3, colors: Array) -> void:
	var root := Node3D.new()
	root.name = "VendingMachines"
	root.position = at
	neon.add_child(root)
	for i: int in range(colors.size()):
		var color: Color = colors[i]
		var x := float(i) * 1.02 - .51
		Kit.box(root, "Body", Vector3(.96, 1.85, .72), Vector3(x, .93, 0), Kit.mat(color.darkened(.45), .4, .3))
		neon._screen(root, "Display", Vector3(x, 1.22, -.37), PI, Vector2(.78, 1.04), color.lerp(Color.WHITE, .55), color)
		Kit.box(root, "Tray", Vector3(.6, .2, .03), Vector3(x, .32, -.37), Kit.mat(Color("#101214"), .4, .6))
	Kit.solid(root, "VendingBlock", Vector3(2.0, 1.85, .72), Vector3(0, .93, 0))
	var light := OmniLight3D.new()
	light.name = "VendingGlow"
	light.position = Vector3(0, 1.2, -1.0)
	light.light_color = (colors[0] as Color).lerp(colors[1], .5).lerp(Color.WHITE, .3)
	light.light_energy = 1.1
	light.omni_range = 5.5
	light.shadow_enabled = false
	root.add_child(light)
	neon._lights.append(light)
