extends Node3D
## 2050 retrofit of the south street: signs fitted to each business,
## LED screens, utility cabling and rooftop plant, plus the coloured night air.
## Shop facades sit at local Z 0 and face local -Z. Signs stay in the band between
## the awning (Y 2.95) and the balcony soffit (Y 3.7), never across a balcony.
const Kit = preload("res://scripts/midori_park_kit.gd")
const Retrofit = preload("res://scripts/midori_street_retrofit.gd")
const Interiors = preload("res://scripts/midori_interiors.gd")
const Facades = preload("res://scripts/midori_building_facades.gd")
const WASH := {"UedaBooks":Color("#2fd4ff"), "MoriCoffee":Color("#ff3d82"), "HinataDaily":Color("#ffb03a"), "YakitoriShop":Color("#ff6a2a")}
const POLES: Array[Vector3] = [Vector3(-16.5,.09,190.9), Vector3(3.4,.09,190.9), Vector3(13.6,.09,190.9)]

const SCREEN_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform float power = 0.2;
uniform vec3 color_a = vec3(1.0, 0.1, 0.5);
uniform vec3 color_b = vec3(0.1, 0.8, 1.0);
uniform vec2 pixels = vec2(160.0, 90.0);
uniform float ticker = 0.0;
float hsh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment(){
	vec2 grid = UV * pixels;
	vec2 dots = abs(fract(grid) - 0.5);
	float far = smoothstep(0.3, 1.0, fwidth(grid.x));
	float led = mix(1.0 - smoothstep(0.34, 0.46, max(dots.x, dots.y)), 0.72, far);
	vec3 picture;
	if (ticker > 0.5) {
		// Scrolling amber characters: 7-row dot columns grouped into glyphs.
		vec2 cell = floor(grid);
		float column = cell.x + floor(TIME * 9.0);
		float glyph = floor(column / 6.0);
		float gap = step(5.0, mod(column, 6.0));
		float on = step(0.48, hsh(vec2(glyph, cell.y + mod(column, 6.0) * 7.0))) * (1.0 - gap);
		picture = color_a * on;
	} else {
		float wave = sin(UV.x * 4.0 + TIME * 0.5) + sin(UV.y * 6.0 - TIME * 0.35) + sin((UV.x + UV.y) * 5.0 + TIME * 0.2);
		float band = smoothstep(-0.2, 0.9, wave);
		float sweep = smoothstep(0.86, 1.0, fract(UV.x * 0.8 - UV.y * 0.5 + TIME * 0.09));
		picture = mix(color_a, color_b, band) * (0.42 + 0.3 * band) + vec3(1.0) * sweep * 0.5;
	}
	ALBEDO = picture * led * power;
}
"""

var installed := false
var park: Node3D
var street: Node
var _glows: Array[StandardMaterial3D] = []
var _lights: Array[OmniLight3D] = []
var _screens: Array[ShaderMaterial] = []
var _interior_lights: Array = []
var shop_roots := {}
var _font: SystemFont
var _steel: StandardMaterial3D
var _concrete: StandardMaterial3D
var _cable: StandardMaterial3D

func _ready() -> void:
	park = get_parent()
	add_to_group("midori_horizon")
	street = park.get_node_or_null("MidoriSouthStreet")
	if street == null: return
	while street.get("installed") != true:
		await get_tree().process_frame
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Yu Gothic", "Meiryo", "Noto Sans CJK JP", "sans-serif"])
	_font.font_weight = 700
	_steel = Kit.mat(Color("#3a3f45"), .5, .7)
	_concrete = Kit.mat(Color("#77756e"), .92)
	_cable = Kit.mat(Color("#101214"), .7)
	_dress_ueda(_shop_root("UedaBooks"))
	_dress_mori(_shop_root("MoriCoffee"))
	_dress_hinata(_shop_root("HinataDaily"))
	_dress_yakitori(_shop_root("YakitoriShop"))
	_build_utility_lines()
	print("MIDORI_STREET_RETROFIT: ", JSON.stringify(Retrofit.build(self)))
	print("MIDORI_INTERIORS: ", JSON.stringify(Interiors.build(self)))
	print("MIDORI_HOME_EXTERIORS: ", Facades.dress_homes(self, street))
	installed = true
	set_night_mode(park.get("is_night_mode") == true)

func set_night_mode(value: bool) -> void:
	for material: StandardMaterial3D in _glows:
		material.emission_energy_multiplier = 2.6 if value else .08
	for material: ShaderMaterial in _screens:
		material.set_shader_parameter("power", 1.3 if value else .55)
	for light: OmniLight3D in _lights:
		light.visible = value
	for row: Array in _interior_lights:
		var level: float = row[2] if value else row[1]
		if row[0] is ReflectionProbe: (row[0] as ReflectionProbe).ambient_color_energy = level
		else: (row[0] as OmniLight3D).light_energy = level
	if value: call_deferred("_apply_night_air")

func _apply_night_air() -> void:
	# Runs after the park's own quality pass so these values are not overwritten.
	var environment: Environment = park.get("park_environment")
	if environment == null or park.get("is_night_mode") != true: return
	# Enough sky fill that woodland reads as dark, not as a black screen.
	environment.ambient_light_energy = 1.1
	environment.fog_light_color = Color("#2a2342")
	environment.fog_density = .0024
	environment.glow_intensity = 1.0
	environment.glow_bloom = .12
	environment.glow_hdr_threshold = .85
	environment.volumetric_fog_albedo = Color("#857aa6")
	var sky := environment.sky.sky_material as ProceduralSkyMaterial
	sky.sky_horizon_color = Color("#3a2a5e")
	sky.ground_horizon_color = Color("#241d3a")

func _shop_root(shop_name: String) -> Node3D:
	# Children of the shop, so Creator Mode moves them with the building.
	var root := Node3D.new()
	root.name = shop_name + "Retrofit"
	street.get_node(NodePath(shop_name)).add_child(root)
	shop_roots[shop_name] = root
	var light := OmniLight3D.new()
	light.name = "ShopNeonWash"
	light.position = Vector3(0, 2.4, -2.0)
	# Mostly tint, not flood: the building keeps its own colours.
	light.light_color = (WASH[shop_name] as Color).lerp(Color("#ffe8d6"), .35)
	light.light_energy = 1.7
	light.light_specular = 1.4
	light.omni_range = 10.0
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 70.0
	light.distance_fade_length = 20.0
	root.add_child(light)
	_lights.append(light)
	return root

func _glow(color: Color) -> StandardMaterial3D:
	var material := Kit.glow(color)
	_glows.append(material)
	return material

func _text(parent: Node3D, words: String, at: Vector3, height: float, color: Color, face_back := false) -> void:
	var label := Label3D.new()
	label.name = "SignText"
	label.text = words
	label.font = _font
	label.font_size = 96
	label.pixel_size = height / 118.0
	label.modulate = color
	label.outline_size = 0
	label.shaded = false
	label.double_sided = false
	label.position = at
	# Label3D reads from +Z; street-facing faces look along local -Z.
	label.rotation.y = 0.0 if face_back else PI
	parent.add_child(label)

func _halo(parent: Node3D, centre: Vector3, size: Vector2, color: Color) -> void:
	# Thin light line just proud of an existing painted board.
	var line := _glow(color)
	var half := size * .5
	for edge: float in [-1.0, 1.0]:
		Kit.box(parent, "BoardHalo", Vector3(size.x + .06, .022, .022), centre + Vector3(0, edge * half.y, 0), line)
		Kit.box(parent, "BoardHalo", Vector3(.022, size.y, .022), centre + Vector3(edge * half.x, 0, 0), line)

func _screen(parent: Node3D, label: String, at: Vector3, yaw: float, size: Vector2, a: Color, b: Color, is_ticker := false) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var shader := Shader.new()
	shader.code = SCREEN_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("color_a", Vector3(a.r, a.g, a.b))
	material.set_shader_parameter("color_b", Vector3(b.r, b.g, b.b))
	material.set_shader_parameter("ticker", 1.0 if is_ticker else 0.0)
	material.set_shader_parameter("pixels", Vector2(size.x, size.y) * (24.0 if is_ticker else 18.0))
	_screens.append(material)
	var screen := MeshInstance3D.new()
	screen.name = label
	screen.mesh = quad
	screen.material_override = material
	screen.position = at
	screen.rotation.y = yaw
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(screen)
	return screen

func _wall_screen(parent: Node3D, at: Vector3, yaw: float, size: Vector2, a: Color, b: Color, words: String) -> void:
	# Bracket-framed LED wall on an otherwise blank gable.
	var frame := Node3D.new()
	frame.name = "WallScreen"
	frame.position = at
	frame.rotation.y = yaw
	parent.add_child(frame)
	Kit.box(frame, "ScreenFrame", Vector3(size.x + .24, size.y + .24, .14), Vector3(0, 0, -.07), _steel)
	_screen(frame, "ScreenPanel", Vector3(0, 0, .012), 0.0, size, a, b)
	_text(frame, words, Vector3(0, 0, .03), size.y * .46, Color(1, 1, 1, .94), true)

func _air_conditioner(parent: Node3D, at: Vector3, yaw: float) -> void:
	var unit := Node3D.new()
	unit.name = "AirConditioner"
	unit.position = at
	unit.rotation.y = yaw
	parent.add_child(unit)
	Interiors.model(unit, "exterior_aircon_unit", Vector3(0, -.28, 0), Vector3(.82, .58, .3), PI)
	for node: Node in unit.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).visibility_range_end = 70.0


func _antenna(parent: Node3D, base: Vector3, height: float) -> void:
	Kit.tube(parent, "Mast", base, base + Vector3.UP * height, .03, _steel)
	for i: int in range(3):
		var y := height * (.62 + float(i) * .16)
		Kit.tube(parent, "Element", base + Vector3(-.5 + float(i) * .1, y, 0), base + Vector3(.5 - float(i) * .1, y, 0), .012, _steel)

func _dish(parent: Node3D, at: Vector3, facing: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = .42
	mesh.height = .3
	mesh.is_hemisphere = false
	var dish := MeshInstance3D.new()
	dish.name = "SatelliteDish"
	dish.mesh = mesh
	dish.material_override = Kit.mat(Color("#c6c6bf"), .5, .2)
	dish.position = at
	dish.rotation = Vector3(deg_to_rad(68), facing, 0)
	parent.add_child(dish)
	Kit.tube(parent, "DishPost", at + Vector3.DOWN * .6, at, .025, _steel)

func _dress_ueda(root: Node3D) -> void:
	var cyan: Color = WASH.UedaBooks
	_halo(root, Vector3(1.9, 3.33, -.3), Vector2(2.66, .46), Color("#ffe9c9"))
	# Small double-sided lightbox on a bracket, clear of the balcony brackets.
	var box := Node3D.new()
	box.name = "BookLightbox"
	box.position = Vector3(-3.7, 3.32, -.5)
	root.add_child(box)
	Kit.box(box, "Case", Vector3(.1, .56, .72), Vector3.ZERO, Kit.mat(Color("#14181d"), .4, .5))
	var rim := _glow(cyan)
	Kit.box(box, "RimTop", Vector3(.13, .024, .75), Vector3(0, .28, 0), rim)
	Kit.box(box, "RimBase", Vector3(.13, .024, .75), Vector3(0, -.28, 0), rim)
	Kit.box(box, "RimFront", Vector3(.13, .56, .024), Vector3(0, 0, -.37), rim)
	Kit.box(root, "Bracket", Vector3(.04, .04, .4), Vector3(-3.7, 3.6, -.16), _steel)
	for face: float in [-1.0, 1.0]:
		var label := Node3D.new()
		label.position = Vector3(-3.7 + face * .056, 3.32, -.5)
		label.rotation.y = -face * PI * .5
		root.add_child(label)
		_text(label, "本", Vector3.ZERO, .4, Color("#d9f6ff"), true)
	# E-paper notice on the pier, flush like a real shop's listings board.
	Kit.box(root, "NoticeFrame", Vector3(.66, 1.26, .05), Vector3(-4.75, 1.62, -.06), _steel)
	_screen(root, "NoticePanel", Vector3(-4.75, 1.62, -.09), PI, Vector2(.58, 1.18), Color("#0d5f73"), cyan)
	_text(root, "古書\n買取", Vector3(-4.75, 1.62, -.1), .14, Color("#eafcff"))
	_air_conditioner(root, Vector3(4.6, 4.42, -.42), 0.0)
	_wall_screen(root, Vector3(5.56, 4.0, 4.0), PI * .5, Vector2(6.0, 3.4), Color("#ff2d78"), Color("#22d3ff"), "電脳")
	_antenna(root, Vector3(3.4, 7.8, 4.0), 2.6)
	_dish(root, Vector3(-3.6, 8.5, 3.6), PI)

func _dress_mori(root: Node3D) -> void:
	var pink: Color = WASH.MoriCoffee
	# Round sign echoing the shop's circular logo, sitting above the awning.
	var disc := Node3D.new()
	disc.name = "RoundCoffeeSign"
	disc.position = Vector3(-2.6, 3.34, -.1)
	root.add_child(disc)
	var plate := Kit.disc(disc, "Plate", .34, .06, Vector3.ZERO, Kit.mat(Color("#121418"), .4, .4))
	plate.rotation.x = PI * .5
	var ring := TorusMesh.new()
	ring.inner_radius = .33
	ring.outer_radius = .365
	ring.rings = 40
	ring.ring_segments = 8
	var tube := MeshInstance3D.new()
	tube.name = "NeonRing"
	tube.mesh = ring
	tube.material_override = _glow(pink)
	tube.rotation.x = PI * .5
	tube.position.z = -.04
	disc.add_child(tube)
	_text(disc, "珈", Vector3(0, 0, -.045), .4, Color("#ffd9e6"))
	# Warm logotype light and a thin tube tracing the awning's top seam.
	Kit.box(root, "LogoWash", Vector3(2.5, .02, .02), Vector3(1.4, 3.06, -.3), _glow(Color("#ffc9a0")))
	_air_conditioner(root, Vector3(-4.2, 4.42, -.42), 0.0)
	Kit.box(root, "RoofTank", Vector3(1.5, 1.1, 1.5), Vector3(-2.6, 7.75, 4.0), Kit.mat(Color("#5d6065"), .7, .4))
	for x: float in [-3.1, -2.1]:
		Kit.tube(root, "TankLeg", Vector3(x, 7.0, 4.0), Vector3(x, 7.25, 4.0), .05, _steel)
	for i: int in range(3):
		var panel := Kit.box(root, "SolarPanel", Vector3(1.2, .04, 1.9), Vector3(.6 + float(i) * 1.35, 7.42, 4.4), Kit.mat(Color("#101c30"), .22, .6))
		panel.rotation.x = deg_to_rad(-16)
	_dish(root, Vector3(3.8, 7.85, 2.0), PI)

func _dress_hinata(root: Node3D) -> void:
	var amber: Color = WASH.HinataDaily
	_halo(root, Vector3(1.75, 3.33, -.3), Vector2(2.92, .5), Color("#fff0cf"))
	# Grocer's scrolling price board in the free fascia beside the name board.
	Kit.box(root, "TickerFrame", Vector3(3.56, .42, .1), Vector3(-2.1, 3.33, -.27), _steel)
	_screen(root, "PriceTicker", Vector3(-2.1, 3.33, -.33), PI, Vector2(3.44, .3), amber, amber, true)
	# Fresh-produce green line along the base of the fascia.
	Kit.box(root, "ProduceStripe", Vector3(9.4, .03, .03), Vector3(0, 3.02, -.3), _glow(Color("#3dff8e")))
	_air_conditioner(root, Vector3(4.2, 4.42, -.42), 0.0)
	_wall_screen(root, Vector3(-5.04, 4.0, 3.8), -PI * .5, Vector2(6.0, 3.4), Color("#ffb03a"), Color("#ff3d82"), "新鮮市場")
	_antenna(root, Vector3(-3.0, 7.7, 4.0), 2.4)

func _dress_yakitori(root: Node3D) -> void:
	# Timber and paper: lanterns only. Neon would fight this building.
	_halo(root, Vector3(0, 3.35, -.12), Vector2(1.76, .54), Color("#ffb066"))
	var paper := _glow(Color("#ff4a22"))
	var cap := Kit.mat(Color("#17120e"), .6)
	var count := 7
	var span := 4.5
	for i: int in range(count):
		var t := float(i) / float(count - 1)
		var x := lerpf(-span * .5, span * .5, t)
		var y := 2.76 - sin(t * PI) * .07
		var mesh := CapsuleMesh.new()
		mesh.radius = .1
		mesh.height = .3
		var lantern := MeshInstance3D.new()
		lantern.name = "PaperLantern"
		lantern.mesh = mesh
		lantern.material_override = paper
		lantern.position = Vector3(x, y, -.86)
		root.add_child(lantern)
		Kit.box(root, "LanternCap", Vector3(.1, .03, .1), Vector3(x, y + .155, -.86), cap)
	for i: int in range(count - 1):
		var a := float(i) / float(count - 1)
		var b := float(i + 1) / float(count - 1)
		Kit.tube(root, "LanternCord", Vector3(lerpf(-span * .5, span * .5, a), 2.93 - sin(a * PI) * .07, -.86), Vector3(lerpf(-span * .5, span * .5, b), 2.93 - sin(b * PI) * .07, -.86), .006, _cable)

func _build_utility_lines() -> void:
	# Concrete poles and sagging lines: the most recognisable Tokyo street detail.
	var root := Node3D.new()
	root.name = "UtilityLines"
	add_child(root)
	var tops: Array[Vector3] = []
	for base: Vector3 in POLES:
		Kit.tube(root, "Pole", base, base + Vector3.UP * 8.8, .13, _concrete)
		Kit.solid(root, "PoleBlock", Vector3(.32, 3.0, .32), base + Vector3.UP * 1.5)
		var arm := base + Vector3.UP * 8.1
		Kit.box(root, "CrossArm", Vector3(1.9, .07, .09), arm, _steel)
		Kit.box(root, "CrossArmLow", Vector3(1.3, .06, .08), arm + Vector3.DOWN * .7, _steel)
		var can := Kit.disc(root, "Transformer", .24, .7, base + Vector3(.32, 6.3, 0), Kit.mat(Color("#8b8e8c"), .6, .3))
		Kit.box(root, "TransformerBand", Vector3(.1, .5, .24), base + Vector3(.1, 6.3, 0), _steel)
		if can != null: can.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tops.append(arm)
	for i: int in range(tops.size() - 1):
		for offset: Vector3 in [Vector3(-.85, .03, 0), Vector3(0, .03, 0), Vector3(.85, .03, 0), Vector3(-.55, -.66, 0), Vector3(.55, -.66, 0)]:
			_sagging_line(root, tops[i] + offset, tops[i + 1] + offset, .55)
	# Service drops from the low arm to each shop's upper wall.
	for spec: Array in [[1, Vector3(8.0, 6.3, 194.0)], [2, Vector3(19.5, 6.2, 194.0)], [0, Vector3(-8.0, 6.3, 194.0)], [2, Vector3(26.0, 6.0, 194.0)]]:
		_sagging_line(root, tops[spec[0]] + Vector3.DOWN * .7, spec[1], .3)

func _sagging_line(root: Node3D, a: Vector3, b: Vector3, sag: float) -> void:
	var previous := a
	var segments := 7
	for i: int in range(1, segments + 1):
		var t := float(i) / float(segments)
		var point := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		Kit.tube(root, "Cable", previous, point, .012, _cable).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		previous = point
