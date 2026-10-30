extends Node3D
## Kids' playground in world metres; never parent this to the 2x park layout.
## Equipment only animates while the camera is near, so it costs nothing elsewhere.
const Kit = preload("res://scripts/midori_park_kit.gd")

const SURFACE_SIZE := Vector2(34.0, 26.0)
const ACTIVE_RANGE_M := 70.0

@export var yaw_degrees := -12.0

const RUBBER_SHADER := """
shader_type spatial;
uniform float night = 0.0;
varying vec2 p;
float hsh(vec2 q){ return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
float nz(vec2 q){ vec2 c = floor(q); vec2 f = fract(q); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hsh(c), hsh(c+vec2(1,0)), u.x), mix(hsh(c+vec2(0,1)), hsh(c+vec2(1,1)), u.x), u.y); }
float round_rect(vec2 q, vec2 h, float r){ vec2 d = abs(q) - h + vec2(r); return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r; }
void vertex(){ p = VERTEX.xz; }
void fragment(){
	float edge = round_rect(p, vec2(16.6, 12.6), 5.0);
	if (edge > 0.0) discard;
	// Poured EPDM laid out like a real installer's job: a slate field, a
	// meandering ochre track and hard-edged safety discs under the equipment.
	vec3 slate = vec3(0.075, 0.13, 0.15);
	vec3 coral = vec3(0.30, 0.095, 0.08);
	vec3 ochre = vec3(0.30, 0.205, 0.075);
	float aa = fwidth(p.x) + 0.015;
	vec3 base = slate;
	float track = abs(p.y + sin(p.x * 0.28) * 3.4 + cos(p.x * 0.11) * 2.0 - 1.0) - 1.05;
	base = mix(base, ochre, 1.0 - smoothstep(0.0, aa, track));
	for (int i = 0; i < 3; i++) {
		vec3 d = i == 0 ? vec3(10.0, 6.0, 3.2) : (i == 1 ? vec3(2.0, 4.5, 3.6) : vec3(8.5, -7.0, 2.6));
		float zone = i == 2 ? max(abs(p.x - d.x) - 5.2, abs(p.y - d.y) - d.z) : length(p - d.xy) - d.z;
		base = mix(base, coral, 1.0 - smoothstep(0.0, aa, zone));
	}
	// Scuffed walking lines and sun fade; the crumb calms down with distance.
	base *= mix(0.84, 1.08, nz(p * 0.6) * 0.7 + nz(p * 2.7) * 0.3);
	float crumb = hsh(floor(p * 70.0));
	base *= mix(mix(0.74, 1.16, crumb), 0.96, smoothstep(0.4, 1.4, fwidth(p.x) * 70.0));
	float kerb = smoothstep(-0.2, -0.17, edge);
	float led = smoothstep(-0.34, -0.31, edge) * (1.0 - smoothstep(-0.26, -0.23, edge));
	ALBEDO = mix(base, vec3(0.16, 0.17, 0.18), kerb);
	ROUGHNESS = 0.82;
	SPECULAR = 0.3;
	EMISSION = led * vec3(1.0, 0.22, 0.5) * 2.4 * night;
}
"""

var _surface: ShaderMaterial
var _glows: Array[StandardMaterial3D] = []
var _lights: Array[SpotLight3D] = []
var _swings: Array[Node3D] = []
var _carousel: Node3D
var _seesaw: Node3D
var _steel: StandardMaterial3D
var _red: StandardMaterial3D
var _yellow: StandardMaterial3D
var _blue: StandardMaterial3D
var _time := 0.0

func _ready() -> void:
	add_to_group("midori_horizon")
	rotation.y = deg_to_rad(yaw_degrees)
	call_deferred("_build")

func _build() -> void:
	_steel = Kit.mat(Color("#596069"), .42, .8)
	_red = Kit.mat(Color("#b23a2c"), .46, .3)
	_yellow = Kit.mat(Color("#c8952a"), .46, .3)
	_blue = Kit.mat(Color("#245f86"), .46, .3)
	_build_surface()
	_build_play_tower(Vector3(-6.5, .16, -3.5))
	_build_swings(Vector3(8.5, .16, -7.0))
	_build_climbing_dome(Vector3(2.0, .16, 4.5))
	_build_carousel(Vector3(10.0, .16, 6.0))
	_build_seesaw(Vector3(-9.5, .16, 7.0))
	_build_spring_rider(Vector3(-3.5, .16, 8.5), _red)
	_build_spring_rider(Vector3(-1.0, .16, 9.5), _blue)
	_build_lights()
	var park := get_parent()
	set_night_mode(park != null and park.get("is_night_mode") == true)

func set_night_mode(value: bool) -> void:
	if _surface != null: _surface.set_shader_parameter("night", 1.0 if value else 0.0)
	for material: StandardMaterial3D in _glows:
		material.emission_energy_multiplier = 2.8 if value else .1
	for light: SpotLight3D in _lights:
		light.visible = value

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.global_position.distance_to(global_position) > ACTIVE_RANGE_M:
		return
	# Nobody is playing here; the breeze just keeps it from looking frozen.
	_time += delta
	for i: int in range(_swings.size()):
		_swings[i].rotation.x = sin(_time * 1.5 + float(i) * 1.9) * deg_to_rad(5.0 + 3.0 * sin(_time * .17 + float(i)))
	if _carousel != null: _carousel.rotation.y += delta * .14
	if _seesaw != null: _seesaw.rotation.z = sin(_time * .35) * deg_to_rad(2.0) + deg_to_rad(9.0)

func _glow(color: Color) -> StandardMaterial3D:
	var material := Kit.glow(color)
	_glows.append(material)
	return material

func _build_surface() -> void:
	var plane := PlaneMesh.new()
	plane.size = SURFACE_SIZE
	var shader := Shader.new()
	shader.code = RUBBER_SHADER
	_surface = ShaderMaterial.new()
	_surface.shader = shader
	var ground := MeshInstance3D.new()
	ground.name = "RubberSurface"
	ground.mesh = plane
	ground.material_override = _surface
	ground.position.y = .16
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	Kit.solid(self, "PlaygroundFloor", Vector3(33.2, .3, 25.2), Vector3(0, .01, 0))

func _post(root: Node3D, x: float, z: float, height: float, material: Material) -> void:
	Kit.tube(root, "Post", Vector3(x, 0, z), Vector3(x, height, z), .06, material)

func _roof(root: Node3D, position: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = .02
	mesh.bottom_radius = 1.75
	mesh.height = .85
	mesh.radial_segments = 4
	mesh.rings = 1
	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	roof.mesh = mesh
	roof.material_override = material
	roof.position = position
	roof.rotation.y = PI * .25
	root.add_child(roof)

func _build_play_tower(origin: Vector3) -> void:
	var root := Node3D.new()
	root.name = "PlayTower"
	root.position = origin
	add_child(root)
	var deck := Kit.mat(Color("#3a3f45"), .85, .2)
	# Tall tower at the origin, lower tower 4.5 m east, linked by a rope bridge.
	for x: float in [-1.1, 1.1]:
		for z: float in [-1.1, 1.1]:
			_post(root, x, z, 3.35, _red)
			_post(root, x + 4.5, z, 2.55, _blue)
	Kit.box(root, "HighDeck", Vector3(2.3, .07, 2.3), Vector3(0, 1.8, 0), deck)
	Kit.box(root, "LowDeck", Vector3(2.3, .07, 2.3), Vector3(4.5, 1.1, 0), deck)
	_roof(root, Vector3(0, 3.75, 0), _yellow)
	_roof(root, Vector3(4.5, 2.95, 0), _red)
	for y: float in [2.25, 2.7]:
		Kit.tube(root, "GuardBack", Vector3(-1.1, y, -1.1), Vector3(1.1, y, -1.1), .022, _steel)
		Kit.tube(root, "GuardWest", Vector3(-1.1, y, -1.1), Vector3(-1.1, y, 1.1), .022, _steel)
	var planks := 8
	var bridge_a := Vector3(1.15, 1.8, 0)
	var bridge_b := Vector3(3.35, 1.1, 0)
	var plank := Kit.mat(Color("#5c4632"), .85)
	for i: int in range(planks):
		var t := (float(i) + .5) / float(planks)
		var p := bridge_a.lerp(bridge_b, t) + Vector3.DOWN * sin(t * PI) * .12
		Kit.box(root, "Plank", Vector3(.22, .035, .8), p, plank)
	for z: float in [-.45, .45]:
		Kit.tube(root, "BridgeRope", bridge_a + Vector3(0, .75, z), bridge_b + Vector3(0, .75, z), .016, Kit.mat(Color("#8a7a5c"), .95))
	for i: int in range(7):
		var y := .3 + float(i) * .25
		Kit.tube(root, "LadderRung", Vector3(-1.45, y, -.3), Vector3(-1.45, y, .3), .018, _steel)
	for z: float in [-.3, .3]:
		Kit.tube(root, "LadderRail", Vector3(-1.85, 0, z), Vector3(-1.12, 1.85, z), .03, _yellow)
	_build_slide(root, Vector3(.0, 1.84, 1.15), Vector3(.0, .1, 6.1))
	var neon := _glow(Color("#3be8ff"))
	Kit.box(root, "NeonEaveHigh", Vector3(2.5, .025, .025), Vector3(0, 3.33, 1.15), neon)
	Kit.box(root, "NeonEaveLow", Vector3(2.5, .025, .025), Vector3(4.5, 2.53, 1.15), neon)
	Kit.solid(root, "HighDeckBlock", Vector3(2.3, .1, 2.3), Vector3(0, 1.8, 0))
	Kit.solid(root, "LowDeckBlock", Vector3(2.3, .1, 2.3), Vector3(4.5, 1.1, 0))
	Kit.solid(root, "BridgeBlock", Vector3(2.5, .1, .9), Vector3(2.25, 1.45, 0), 0.0).rotation.z = -atan2(.7, 2.2)
	Kit.solid(root, "SlideBlock", Vector3(.8, .1, 5.1), Vector3(0, .98, 3.6)).rotation.x = atan2(1.72, 4.95)

func _build_slide(root: Node3D, top: Vector3, bottom: Vector3) -> void:
	# Swept U-section with a flat run-out so it reads as moulded, not a ramp.
	var section: Array[Vector2] = [Vector2(-.34, .2), Vector2(-.31, .03), Vector2(-.24, 0), Vector2(.24, 0), Vector2(.31, .03), Vector2(.34, .2)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 36
	for i: int in range(steps + 1):
		var t := float(i) / float(steps)
		var height := lerpf(top.y, bottom.y, smoothstep(.0, .86, t))
		var centre := Vector3(lerpf(top.x, bottom.x, t) + sin(t * PI) * .55, height, lerpf(top.z, bottom.z, t))
		for j: int in range(section.size()):
			var point := centre + Vector3(section[j].x, section[j].y, 0)
			st.set_uv(Vector2(float(j) / 5.0, t * 5.0))
			st.add_vertex(point)
	for i: int in range(steps):
		for j: int in range(section.size() - 1):
			var a := i * section.size() + j
			var b := a + 1
			var c := a + section.size()
			var d := c + 1
			for index: int in [a, b, d, a, d, c]:
				st.add_index(index)
	st.generate_normals()
	var material := Kit.mat(Color("#b9ad93"), .24, .78)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var slide := MeshInstance3D.new()
	slide.name = "Slide"
	slide.mesh = st.commit()
	slide.material_override = material
	root.add_child(slide)
	for t: float in [.35, .68]:
		var height := lerpf(top.y, bottom.y, smoothstep(.0, .86, t))
		var x := lerpf(top.x, bottom.x, t) + sin(t * PI) * .55
		var z := lerpf(top.z, bottom.z, t)
		Kit.tube(root, "SlideSupport", Vector3(x, 0, z), Vector3(x, height, z), .04, _steel)

func _build_swings(origin: Vector3) -> void:
	var root := Node3D.new()
	root.name = "SwingSet"
	root.position = origin
	add_child(root)
	var length := 7.4
	var top := 2.75
	Kit.tube(root, "TopBeam", Vector3(-length * .5, top, 0), Vector3(length * .5, top, 0), .055, _blue)
	for x: float in [-length * .5, length * .5]:
		for z: float in [-1.15, 1.15]:
			Kit.tube(root, "ALeg", Vector3(x, 0, z), Vector3(x, top, 0), .05, _blue)
		Kit.solid(root, "FrameBlock", Vector3(.2, top, 2.0), Vector3(x, top * .5, 0))
	var chain := Kit.mat(Color("#8c9299"), .38, .9)
	var seat := Kit.mat(Color("#1c1f23"), .8)
	for x: float in [-2.3, 0.0, 2.3]:
		var pivot := Node3D.new()
		pivot.name = "Swing"
		pivot.position = Vector3(x, top, 0)
		root.add_child(pivot)
		for side: float in [-.22, .22]:
			Kit.tube(pivot, "Chain", Vector3(side, 0, 0), Vector3(side, -2.2, 0), .009, chain)
		Kit.box(pivot, "Seat", Vector3(.5, .035, .17), Vector3(0, -2.21, 0), seat)
		_swings.append(pivot)

func _build_climbing_dome(origin: Vector3) -> void:
	var root := Node3D.new()
	root.name = "ClimbingDome"
	root.position = origin
	add_child(root)
	var radius := 2.3
	var bars := 12
	var bands := 5
	var bar := _yellow
	for i: int in range(bars):
		var a := TAU * float(i) / float(bars)
		var b := TAU * float(i + 1) / float(bars)
		for j: int in range(bands):
			var p0 := float(j) / float(bands) * PI * .5
			var p1 := float(j + 1) / float(bands) * PI * .5
			var lower := Vector3(cos(a) * cos(p0), sin(p0), sin(a) * cos(p0)) * radius
			var upper := Vector3(cos(a) * cos(p1), sin(p1), sin(a) * cos(p1)) * radius
			Kit.tube(root, "Meridian", lower, upper, .024, bar)
			if j > 0:
				var next := Vector3(cos(b) * cos(p0), sin(p0), sin(b) * cos(p0)) * radius
				Kit.tube(root, "Parallel", lower, next, .02, _steel)
	Kit.box(root, "DomeCap", Vector3(.2, .04, .2), Vector3(0, radius, 0), _steel)
	Kit.solid(root, "DomeBlock", Vector3(3.2, 2.1, 3.2), Vector3(0, 1.05, 0))

func _build_carousel(origin: Vector3) -> void:
	Kit.disc(self, "CarouselBase", .35, .12, origin + Vector3.UP * .06, _steel)
	_carousel = Node3D.new()
	_carousel.name = "Carousel"
	_carousel.position = origin + Vector3.UP * .16
	add_child(_carousel)
	Kit.disc(_carousel, "Deck", 1.5, .05, Vector3.UP * .1, Kit.mat(Color("#2f353b"), .7, .4))
	Kit.disc(_carousel, "GlowRing", 1.53, .02, Vector3.UP * .07, _glow(Color("#ff4fa0")))
	Kit.tube(_carousel, "Hub", Vector3.UP * .1, Vector3.UP * 1.05, .05, _steel)
	for i: int in range(4):
		var a := PI * .5 * float(i)
		var out := Vector3(cos(a), 0, sin(a)) * 1.28
		Kit.tube(_carousel, "Spoke", Vector3.UP * 1.0, out + Vector3.UP * .85, .024, _red)
		Kit.tube(_carousel, "Upright", out + Vector3.UP * .1, out + Vector3.UP * .85, .024, _red)
	Kit.solid(self, "CarouselBlock", Vector3(2.2, .5, 2.2), origin + Vector3.UP * .25)

func _build_seesaw(origin: Vector3) -> void:
	Kit.box(self, "SeesawFulcrum", Vector3(.3, .5, .5), origin + Vector3.UP * .25, _steel)
	_seesaw = Node3D.new()
	_seesaw.name = "Seesaw"
	_seesaw.position = origin + Vector3.UP * .55
	_seesaw.rotation.z = deg_to_rad(9.0)
	add_child(_seesaw)
	Kit.box(_seesaw, "Beam", Vector3(3.6, .06, .26), Vector3.ZERO, _yellow)
	for x: float in [-1.55, 1.55]:
		Kit.box(_seesaw, "Seat", Vector3(.36, .05, .3), Vector3(x, .05, 0), Kit.mat(Color("#1c1f23"), .8))
		Kit.tube(_seesaw, "Handle", Vector3(x * .84, .03, -.16), Vector3(x * .84, .34, -.16), .016, _steel)
		Kit.tube(_seesaw, "Handle", Vector3(x * .84, .03, .16), Vector3(x * .84, .34, .16), .016, _steel)
		Kit.tube(_seesaw, "Grip", Vector3(x * .84, .34, -.16), Vector3(x * .84, .34, .16), .016, _steel)

func _build_spring_rider(origin: Vector3, tint: Material) -> void:
	var root := Node3D.new()
	root.name = "SpringRider"
	root.position = origin
	add_child(root)
	var coil := Kit.mat(Color("#2e3338"), .5, .7)
	var turns := 40
	for i: int in range(turns):
		var a := float(i) * .55
		var b := float(i + 1) * .55
		var p0 := Vector3(cos(a) * .09, .03 + float(i) * .0085, sin(a) * .09)
		var p1 := Vector3(cos(b) * .09, .03 + float(i + 1) * .0085, sin(b) * .09)
		Kit.tube(root, "Coil", p0, p1, .011, coil)
	var body := CapsuleMesh.new()
	body.radius = .17
	body.height = .78
	var shell := MeshInstance3D.new()
	shell.name = "Body"
	shell.mesh = body
	shell.material_override = tint
	shell.position = Vector3(0, .58, 0)
	shell.rotation.z = PI * .5
	root.add_child(shell)
	Kit.tube(root, "Handle", Vector3(.26, .6, 0), Vector3(.26, .9, 0), .02, _steel)
	Kit.tube(root, "HandleBar", Vector3(.26, .9, -.15), Vector3(.26, .9, .15), .017, _steel)
	Kit.solid(root, "RiderBlock", Vector3(.8, .8, .35), Vector3(0, .4, 0))

func _build_lights() -> void:
	var head := Kit.mat(Color("#1b1e22"), .5, .6)
	for position: Vector3 in [Vector3(-14.5, 0, -10.0), Vector3(14.5, 0, -10.0), Vector3(14.5, 0, 10.0), Vector3(-14.5, 0, 10.0)]:
		var top := position + Vector3.UP * 5.2
		Kit.tube(self, "LampPole", position + Vector3.UP * .16, top, .06, _steel)
		Kit.box(self, "LampHead", Vector3(.7, .08, .22), top, head)
		Kit.box(self, "LampPanel", Vector3(.62, .02, .16), top - Vector3.UP * .05, _glow(Color("#ffe3bd")))
		_lights.append(Kit.flood(self, "PlayLamp", top, Vector3(position.x * .35, 0, position.z * .35), Color("#ffd9ae"), 4.5, 22.0))
		Kit.solid(self, "LampPoleBlock", Vector3(.2, 5.2, .2), position + Vector3.UP * 2.6)
