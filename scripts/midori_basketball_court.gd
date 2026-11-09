extends Node3D
## Fenced FIBA street court in world metres; never parent this to the 2x park
## layout. Court markings are drawn in a shader so there are no decal seams.
const Kit = preload("res://scripts/midori_park_kit.gd")
const ShaderPool = preload("res://scripts/shinrai_shader_pool.gd")

const COURT_SIZE := Vector2(32.0, 19.0)
const FENCE_HEIGHT := 4.2
const GATE_WIDTH := 3.0

@export var yaw_degrees := 0.0

const SURFACE_SHADER := """
shader_type spatial;
uniform float night = 0.0;
varying vec2 p;
float hsh(vec2 q){ return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
float nz(vec2 q){ vec2 c = floor(q); vec2 f = fract(q); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hsh(c), hsh(c+vec2(1,0)), u.x), mix(hsh(c+vec2(0,1)), hsh(c+vec2(1,1)), u.x), u.y); }
float rect(vec2 q, vec2 c, vec2 h){ vec2 d = abs(q - c) - h; return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0); }
float ink(float d){ float w = max(fwidth(d), 0.002); return 1.0 - smoothstep(0.025, 0.025 + w, abs(d)); }
void vertex(){ p = VERTEX.xz; }
void fragment(){
	vec2 q = abs(p);
	vec2 basket = vec2(12.425, 0.0);
	float inside = step(rect(q, vec2(0.0), vec2(14.0, 7.5)), 0.0);
	float key = step(rect(q, vec2(11.1, 0.0), vec2(2.9, 2.45)), 0.0);
	float arc = q.y < 6.6 && q.x < basket.x ? abs(length(q - basket) - 6.75) : 9.0;
	float corner = q.x > 11.0 ? abs(q.y - 6.6) : 9.0;
	float lines = max(ink(rect(q, vec2(0.0), vec2(14.0, 7.5))), ink(q.x));
	lines = max(lines, ink(length(q) - 1.8));
	lines = max(lines, ink(rect(q, vec2(11.1, 0.0), vec2(2.9, 2.45))));
	lines = max(lines, ink(length(q - vec2(8.2, 0.0)) - 1.8));
	lines = max(lines, max(ink(arc), ink(corner)));
	float wear = nz(p * 0.7) * 0.55 + nz(p * 3.1) * 0.3 + nz(p * 17.0) * 0.15;
	float scuff = smoothstep(0.42, 0.7, nz(p * 0.45 + 7.0));
	vec3 runoff = vec3(0.075, 0.08, 0.09);
	vec3 court = mix(vec3(0.035, 0.145, 0.19), vec3(0.055, 0.19, 0.235), wear);
	vec3 paint = vec3(0.30, 0.055, 0.14) * mix(0.8, 1.1, wear);
	vec3 base = mix(runoff * mix(0.8, 1.15, wear), court, inside);
	base = mix(base, paint, key);
	base *= mix(1.0, 0.8, scuff);
	vec3 line_tone = vec3(0.82, 0.84, 0.82) * mix(0.72, 1.0, smoothstep(0.3, 0.6, nz(p * 2.3)));
	ALBEDO = mix(base, line_tone, lines);
	// Acrylic sheen, broken by puddled damp patches that catch the floodlights.
	float damp = smoothstep(0.5, 0.74, nz(p * 0.33 + 3.0));
	ROUGHNESS = mix(0.8, 0.62, damp);
	SPECULAR = 0.16;
	// The boundary and key lines double as LED inlays after dark.
	EMISSION = lines * vec3(0.12, 0.8, 1.0) * 1.1 * night;
}
"""

const CHAIN_LINK_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec2 panel_metres = vec2(1.0, 1.0);
void fragment(){
	// UV scaled to metres by the panel's size (a uniform, so every fence run
	// shares this one shader). Wires resolve up close, then settle into a
	// see-through grey veil at the mesh's real coverage instead of shimmering.
	vec2 m = UV * panel_metres; vec2 g = vec2(m.x + m.y, m.x - m.y) * 14.0;
	vec2 f = abs(fract(g) - 0.5);
	float px = fwidth(g.x) + fwidth(g.y);
	float wire = max(smoothstep(0.42, 0.43 + px, f.x), smoothstep(0.42, 0.43 + px, f.y));
	ALPHA = mix(wire, 0.3, smoothstep(0.35, 1.1, px));
	ALBEDO = vec3(0.34, 0.37, 0.39);
	METALLIC = 0.8;
	ROUGHNESS = 0.42;
}
"""

const NET_SHADER := """
shader_type spatial;
render_mode cull_disabled;
void fragment(){
	vec2 g = vec2(UV.x * 12.0 + UV.y * 3.0, UV.x * 12.0 - UV.y * 3.0);
	vec2 f = abs(fract(g) - 0.5);
	ALPHA = max(step(0.43, f.x), step(0.43, f.y));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = vec3(0.86, 0.86, 0.82);
	ROUGHNESS = 0.9;
}
"""

var _surface: ShaderMaterial
var _glows: Array[StandardMaterial3D] = []
var _lights: Array[SpotLight3D] = []
var _steel: StandardMaterial3D

func _ready() -> void:
	add_to_group("midori_horizon")
	rotation.y = deg_to_rad(yaw_degrees)
	call_deferred("_build")

func _build() -> void:
	_steel = Kit.mat(Color("#2b3036"), .46, .75)
	_build_surface()
	_build_fence()
	for side: float in [-1.0, 1.0]:
		_build_hoop(side)
	_build_floodlights()
	_build_sideline_furniture()
	var park := get_parent()
	set_night_mode(park != null and park.get("is_night_mode") == true)

func set_night_mode(value: bool) -> void:
	if _surface != null: _surface.set_shader_parameter("night", 1.0 if value else 0.0)
	for material: StandardMaterial3D in _glows:
		material.emission_energy_multiplier = 3.2 if value else .15
	for light: SpotLight3D in _lights:
		light.visible = value

func _glow(color: Color) -> StandardMaterial3D:
	var material := Kit.glow(color)
	_glows.append(material)
	return material

func _build_surface() -> void:
	var plane := PlaneMesh.new()
	plane.size = COURT_SIZE
	_surface = ShaderPool.material(SURFACE_SHADER)
	var ground := MeshInstance3D.new()
	ground.name = "CourtSurface"
	ground.mesh = plane
	ground.material_override = _surface
	ground.position.y = .17
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	Kit.box(self, "CourtSlab", Vector3(COURT_SIZE.x + .5, .17, COURT_SIZE.y + .5), Vector3(0, .08, 0), Kit.mat(Color("#55585a"), .9))
	Kit.solid(self, "CourtFloor", Vector3(COURT_SIZE.x + .5, .4, COURT_SIZE.y + .5), Vector3(0, -.03, 0))

func _build_fence() -> void:
	var link := ShaderPool.material(CHAIN_LINK_SHADER)
	var half := COURT_SIZE * .5
	var corners: Array[Vector3] = [Vector3(-half.x, .17, -half.y), Vector3(half.x, .17, -half.y), Vector3(half.x, .17, half.y), Vector3(-half.x, .17, half.y)]
	var strip := _glow(Color("#22d3ff"))
	var accent := _glow(Color("#ff2d78"))
	for side: int in range(4):
		var a := corners[side]
		var b := corners[(side + 1) % 4]
		var runs: Array = [[a, b]]
		if side == 2:
			# Gate on the south side, in line with the half-way line.
			var mid := (a + b) * .5
			var gap := (b - a).normalized() * GATE_WIDTH * .5
			runs = [[a, mid - gap], [mid + gap, b]]
		for run: Array in runs:
			_fence_run(run[0], run[1], link, strip if side % 2 == 0 else accent)

func _fence_run(a: Vector3, b: Vector3, link: Material, strip: Material) -> void:
	var length := a.distance_to(b)
	var along := (b - a).normalized()
	var yaw := atan2(-along.z, along.x)
	var quad := QuadMesh.new()
	quad.size = Vector2(length, FENCE_HEIGHT)
	var panel := MeshInstance3D.new()
	panel.name = "ChainLink"
	panel.mesh = quad
	panel.material_override = _metres_uv(link, quad)
	panel.position = (a + b) * .5 + Vector3.UP * FENCE_HEIGHT * .5
	panel.rotation.y = yaw
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(panel)
	var posts := maxi(ceili(length / 3.0), 1)
	for i: int in range(posts + 1):
		var base := a + along * length * float(i) / float(posts)
		Kit.tube(self, "FencePost", base, base + Vector3.UP * FENCE_HEIGHT, .038, _steel)
	var top := Vector3.UP * FENCE_HEIGHT
	Kit.tube(self, "TopRail", a + top, b + top, .024, _steel)
	Kit.tube(self, "MidRail", a + top * .5, b + top * .5, .018, _steel)
	Kit.tube(self, "BottomRail", a + Vector3.UP * .08, b + Vector3.UP * .08, .018, _steel)
	Kit.box(self, "LedStrip", Vector3(length, .03, .03), (a + b) * .5 + top + Vector3.UP * .04, strip, Vector3(0, yaw, 0))
	Kit.solid(self, "FenceBlock", Vector3(length, FENCE_HEIGHT, .12), (a + b) * .5 + Vector3.UP * FENCE_HEIGHT * .5, yaw)

func _metres_uv(link: ShaderMaterial, quad: QuadMesh) -> ShaderMaterial:
	# Each run keeps a 5 cm mesh pitch however long it is: the run's size in
	# metres is a uniform on its own material, so the five runs share one shader
	# (one compile, one set of pipelines) instead of one shader each.
	var scaled := link.duplicate() as ShaderMaterial
	scaled.set_shader_parameter("panel_metres", quad.size)
	return scaled

func _build_hoop(side: float) -> void:
	var hoop := Node3D.new()
	hoop.name = "HoopWest" if side < 0.0 else "HoopEast"
	hoop.position = Vector3(side * 12.425, .17, 0)
	hoop.rotation.y = 0.0 if side > 0.0 else PI
	add_child(hoop)
	var white := Kit.mat(Color("#d8dbd8"), .5, .2)
	var orange := Kit.mat(Color("#e0531c"), .4, .6)
	# The hoop origin is the rim centre, 1.575 m in from the baseline. +X faces
	# the baseline; the offset gooseneck lets players run under the basket.
	Kit.box(hoop, "BasePlate", Vector3(.9, .03, .9), Vector3(2.5, .015, 0), _steel)
	Kit.tube(hoop, "Pole", Vector3(2.5, 0, 0), Vector3(2.5, 2.6, 0), .095, _steel)
	Kit.tube(hoop, "Gooseneck", Vector3(2.5, 2.6, 0), Vector3(.44, 3.45, 0), .075, _steel)
	var pad := Kit.mat(Color("#14171b"), .85)
	Kit.tube(hoop, "PolePad", Vector3(2.5, .05, 0), Vector3(2.5, 1.9, 0), .15, pad)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(.72, .86, .9, .2)
	glass.roughness = .08
	glass.metallic = .4
	Kit.box(hoop, "Backboard", Vector3(.025, 1.05, 1.8), Vector3(.375, 3.45, 0), glass).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var frame := _glow(Color("#22d3ff"))
	Kit.box(hoop, "BoardTop", Vector3(.05, .035, 1.84), Vector3(.375, 3.98, 0), frame)
	Kit.box(hoop, "BoardBottom", Vector3(.05, .035, 1.84), Vector3(.375, 2.92, 0), frame)
	for edge: float in [-.91, .91]:
		Kit.box(hoop, "BoardSide", Vector3(.05, 1.09, .035), Vector3(.375, 3.45, edge), frame)
	var square := _glow(Color("#ff2d78"))
	Kit.box(hoop, "TargetTop", Vector3(.03, .03, .59), Vector3(.355, 3.495, 0), square)
	Kit.box(hoop, "TargetBase", Vector3(.03, .03, .59), Vector3(.355, 3.05, 0), square)
	for edge: float in [-.295, .295]:
		Kit.box(hoop, "TargetSide", Vector3(.03, .45, .03), Vector3(.355, 3.27, edge), square)
	var ring := TorusMesh.new()
	ring.inner_radius = .216
	ring.outer_radius = .24
	ring.rings = 32
	ring.ring_segments = 10
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	rim.mesh = ring
	rim.material_override = orange
	rim.position = Vector3(0, 3.05, 0)
	hoop.add_child(rim)
	Kit.box(hoop, "RimBracket", Vector3(.16, .05, .16), Vector3(.29, 3.05, 0), orange)
	var net_mesh := CylinderMesh.new()
	net_mesh.top_radius = .225
	net_mesh.bottom_radius = .15
	net_mesh.height = .42
	net_mesh.radial_segments = 16
	net_mesh.rings = 1
	net_mesh.cap_top = false
	net_mesh.cap_bottom = false
	var net_material := ShaderPool.material(NET_SHADER)
	var net := MeshInstance3D.new()
	net.name = "Net"
	net.mesh = net_mesh
	net.material_override = net_material
	net.position = Vector3(0, 2.83, 0)
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hoop.add_child(net)
	Kit.solid(self, "HoopPole", Vector3(.4, 3.2, .4), Vector3(side * 14.925, 1.8, 0))

func _build_floodlights() -> void:
	var half := COURT_SIZE * .5 + Vector2(.6, .6)
	var housing := Kit.mat(Color("#1b1e22"), .5, .6)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var base := Vector3(corner.x * half.x, .0, corner.y * half.y)
		var head := base + Vector3.UP * 8.2
		Kit.tube(self, "FloodMast", base, head, .085, _steel)
		var target := Vector3(corner.x * 7.0, .2, corner.y * 2.0)
		var yaw := atan2(-corner.x, -corner.y)
		Kit.box(self, "FloodHousing", Vector3(1.0, .12, .55), head + Vector3.UP * .05, housing, Vector3(deg_to_rad(-24), yaw, 0))
		Kit.box(self, "FloodPanel", Vector3(.92, .03, .47), head - Vector3.UP * .03, _glow(Color("#dff4ff")), Vector3(deg_to_rad(-24), yaw, 0))
		_lights.append(Kit.flood(self, "Flood", head, target, Color("#cfe6ff"), 5.0, 26.0))
		Kit.solid(self, "FloodMastBlock", Vector3(.3, 8.2, .3), base + Vector3.UP * 4.1)

func _build_sideline_furniture() -> void:
	var bench_wood := Kit.mat(Color("#54402f"), .8)
	for x: float in [-7.0, 7.0]:
		var z := COURT_SIZE.y * .5 - .75
		Kit.box(self, "BenchSeat", Vector3(3.0, .05, .4), Vector3(x, .62, z), bench_wood)
		Kit.box(self, "BenchBack", Vector3(3.0, .4, .05), Vector3(x, .9, z + .2), bench_wood)
		for leg: float in [-1.3, 1.3]:
			Kit.box(self, "BenchLeg", Vector3(.06, .45, .4), Vector3(x + leg, .4, z), _steel)
		Kit.solid(self, "BenchBlock", Vector3(3.0, .8, .45), Vector3(x, .57, z))
	var board := Node3D.new()
	board.name = "CourtSign"
	board.position = Vector3(0, .17, -COURT_SIZE.y * .5 - .08)
	add_child(board)
	Kit.box(board, "SignBack", Vector3(7.0, 1.5, .08), Vector3(0, 5.0, 0), Kit.mat(Color("#101317"), .4, .5))
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Yu Gothic", "Meiryo", "Noto Sans CJK JP", "sans-serif"])
	font.font_weight = 700
	var label := Label3D.new()
	label.name = "SignText"
	label.text = "ミドリ 第七コート"
	label.font = font
	label.font_size = 96
	label.pixel_size = .0075
	label.modulate = Color("#ff4f93")
	label.outline_size = 0
	label.position = Vector3(0, 5.0, .05)
	label.shaded = false
	label.double_sided = false
	board.add_child(label)
