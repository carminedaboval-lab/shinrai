extends Node3D
## Midori's wildlife, in WORLD metres. Direct child of the scene root.
##
## Crows and pigeons feed on the lawns by day and scatter from the player,
## hostiles and gunfire. Koi and dragonflies work the lake margin; fireflies and
## lamp moths appear at night. Only the birds use CPU, and only near the camera:
## everything else is animated in the vertex shader.
const Budget = preload("res://scripts/shinrai_loading_budget.gd")

const SEED := 20261103
const ACTIVE_RANGE := 110.0
const THREAT_WALK := 7.0
const THREAT_SPRINT := 12.0
const THREAT_CROUCH := 3.5
const THREAT_HOSTILE := 9.0
const SHOT_RANGE := 48.0
const THREAT_INTERVAL := 0.2
const FLIGHT_SPEED := 8.5
const CRUISE_HEIGHT := 11.0
const FLOCK_ANCHORS: Array[Vector2] = [Vector2(-40, 140), Vector2(-120, 60), Vector2(-150, -70), Vector2(-40, -120), Vector2(120, -130), Vector2(175, -30), Vector2(165, 95), Vector2(70, 150), Vector2(-185, 150), Vector2(-96, -150)]
const GROVES: Array[Vector2] = [Vector2(-170, -110), Vector2(-120, 20), Vector2(-20, 118), Vector2(150, 110), Vector2(170, -100), Vector2(30, -140), Vector2(-190, 60), Vector2(190, 10)]
const CROW := Color("#17181b")
const PIGEON := Color("#6c7680")
const KOI_COLORS: Array[Color] = [Color("#d9581f"), Color("#e8e1d2"), Color("#c23a22"), Color("#e9a23a"), Color("#26262a")]

enum State { GROUND, FLEEING, CRUISING, LANDING }

var installed := false
var report: Dictionary = {}
var _park: Node3D
var _terrain: Node
var _player: Node3D
var _rng := RandomNumberGenerator.new()
var _night := false
var _sites: Array[Vector3] = []
var _flocks: Array[Dictionary] = []
var _birds: Array[Dictionary] = []
var _bird_mesh: MultiMesh
var _bird_instance: MultiMeshInstance3D
var _threat_clock := 0.0
var _day_nodes: Array[Node3D] = []
var _night_nodes: Array[Node3D] = []

func _ready() -> void:
	add_to_group("midori_horizon")
	_park = get_parent() as Node3D
	await Budget.wait_structure(_park)
	for producer_name: String in ["MidoriTerrain", "MidoriJapanesePathLamps"]:
		var producer: Node = _park.get_node_or_null(NodePath(producer_name))
		while producer != null and producer.get("installed") != true:
			await get_tree().process_frame
	_build()

func _build() -> void:
	set_as_top_level(true)
	global_transform = Transform3D.IDENTITY
	_terrain = _park.get_node_or_null("MidoriTerrain")
	_player = _park.get_node_or_null("ParkScaleReviewPlayer") as Node3D
	_rng.seed = SEED
	_night = bool(_park.get("is_night_mode"))
	_build_birds()
	var shore := _shore_points()
	_build_koi(shore)
	_build_dragonflies(shore)
	_build_fireflies()
	_build_moths()
	if _player != null and _player.has_signal("shot_fired"):
		_player.connect("shot_fired", _on_player_shot)
	installed = true
	set_night_mode(_night)
	report = {"birds":_birds.size(), "flocks":_flocks.size(), "shore_points":shore.size()}
	print("MIDORI_PARK_WILDLIFE_READY ", JSON.stringify(report))

func _ground(point: Vector2) -> float:
	if _terrain != null and _terrain.has_method("height_at"): return float(_terrain.height_at(point))
	return 0.0

func _is_water(point: Vector2) -> bool:
	return _terrain != null and _terrain.has_method("water_at") and bool(_terrain.water_at(point))

func _shore_points() -> PackedVector3Array:
	# Water points just off the lake edge, spaced round the whole shoreline.
	var result := PackedVector3Array()
	if _terrain == null: return result
	var shoreline: PackedVector2Array = _terrain.get("shoreline")
	if shoreline.size() < 3: return result
	var centre := Vector2.ZERO
	for point: Vector2 in shoreline: centre += point
	centre /= float(shoreline.size())
	var step := maxi(1, shoreline.size() / 40)
	for index: int in range(0, shoreline.size(), step):
		var edge := shoreline[index]
		var inward := (centre - edge).normalized()
		for inset: float in [7.0, 12.0, 4.0]:
			var point := edge + inward * inset
			if _is_water(point):
				result.append(Vector3(point.x, float(_terrain.get("WATER_Y")), point.y))
				break
	return result

# ------------------------------------------------------------------ birds

func _bird_shape() -> ArrayMesh:
	# A rounded bird, 1 unit long and facing -Z, lofted from cross sections.
	# UV.x marks wing vertices: 0 at the shoulder, 1 at the tip.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections: Array[Vector4] = [ # z, half width, half height, centre y.
		Vector4(-0.40, 0.045, 0.045, 0.36), Vector4(-0.30, 0.085, 0.085, 0.37),
		Vector4(-0.20, 0.10, 0.11, 0.31), Vector4(-0.02, 0.15, 0.16, 0.25),
		Vector4(0.18, 0.11, 0.12, 0.24), Vector4(0.34, 0.04, 0.04, 0.23),
	]
	var sides := 8
	var ring := func(section: Vector4, index: int) -> Array:
		var angle := TAU * float(index % sides) / float(sides)
		var c := cos(angle)
		var s := sin(angle)
		return [Vector3(c * section.y, s * section.z + section.w, section.x), Vector3(c / section.y, s / section.z, 0.0).normalized()]
	var emit := func(point: Vector3, normal: Vector3, wing := 0.0) -> void:
		st.set_uv(Vector2(wing, 0.0))
		st.set_normal(normal)
		st.add_vertex(point)
	for s: int in range(sections.size() - 1):
		var g: Vector4 = sections[s]
		var f: Vector4 = sections[s + 1]
		for i: int in range(sides):
			var f0: Array = ring.call(f, i)
			var f1: Array = ring.call(f, i + 1)
			var g0: Array = ring.call(g, i)
			var g1: Array = ring.call(g, i + 1)
			for corner: Array in [f0, f1, g1, f0, g1, g0]:
				emit.call(corner[0], corner[1])
	var beak := Vector3(0, 0.345, -0.53)
	var rump := Vector3(0, 0.23, 0.42)
	for i: int in range(sides):
		var a: Array = ring.call(sections[0], i)
		var b: Array = ring.call(sections[0], i + 1)
		emit.call(a[0], a[1]); emit.call(b[0], b[1]); emit.call(beak, Vector3.FORWARD)
		var c: Array = ring.call(sections[sections.size() - 1], i)
		var d: Array = ring.call(sections[sections.size() - 1], i + 1)
		emit.call(rump, Vector3.BACK); emit.call(d[0], d[1]); emit.call(c[0], c[1])
	# Tail fan.
	for point: Vector3 in [Vector3(-0.04, 0.24, 0.28), Vector3(0.04, 0.24, 0.28), Vector3(0.1, 0.22, 0.66), Vector3(-0.04, 0.24, 0.28), Vector3(0.1, 0.22, 0.66), Vector3(-0.1, 0.22, 0.66)]:
		emit.call(point, Vector3.UP)
	# Legs, so the body stands off the ground.
	for x: float in [-0.055, 0.055]:
		for point: Vector3 in [Vector3(x - 0.012, 0.0, 0.02), Vector3(x + 0.012, 0.0, 0.02), Vector3(x + 0.012, 0.12, 0.02), Vector3(x - 0.012, 0.0, 0.02), Vector3(x + 0.012, 0.12, 0.02), Vector3(x - 0.012, 0.12, 0.02)]:
			emit.call(point, Vector3.BACK)
	# Wings.
	for side: float in [-1.0, 1.0]:
		var root_a := Vector3(side * 0.1, 0.33, -0.12)
		var root_b := Vector3(side * 0.1, 0.33, 0.14)
		var mid := Vector3(side * 0.44, 0.33, -0.07)
		var tip := Vector3(side * 0.72, 0.33, 0.1)
		emit.call(root_a, Vector3.UP, 0.0); emit.call(mid, Vector3.UP, 0.6); emit.call(root_b, Vector3.UP, 0.0)
		emit.call(mid, Vector3.UP, 0.6); emit.call(tip, Vector3.UP, 1.0); emit.call(root_b, Vector3.UP, 0.0)
	return st.commit()

func _bird_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
varying vec3 tint;
varying float belly;
void vertex() {
	// INSTANCE_CUSTOM: x flap amount, y phase, z flap rate.
	float reach = UV.x;
	float flap = INSTANCE_CUSTOM.x;
	if (reach > 0.0 || abs(VERTEX.x) > 0.09 && VERTEX.y > 0.32 && NORMAL.y > 0.9) {
		float side = sign(VERTEX.x);
		float beat = sin(TIME * INSTANCE_CUSTOM.z + INSTANCE_CUSTOM.y * 6.28);
		vec3 spread = VERTEX + vec3(0.0, reach * beat * 0.55 * flap, 0.0);
		// Folded wings lie along the flanks, with the tips past the rump.
		vec3 folded = vec3(side * (0.125 - 0.04 * reach), 0.34 - 0.05 * reach, VERTEX.z * 0.6 + reach * 0.34);
		VERTEX = mix(folded, spread, clamp(flap * 4.0, 0.0, 1.0));
	}
	tint = COLOR.rgb;
	belly = smoothstep(0.34, 0.14, VERTEX.y);
}
void fragment() {
	ALBEDO = tint * (1.0 + belly * 0.4);
	ROUGHNESS = 0.85;
	SPECULAR = 0.12;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _build_birds() -> void:
	for anchor: Vector2 in FLOCK_ANCHORS:
		var spot := anchor
		for attempt: int in range(10):
			if not _is_water(spot): break
			spot = anchor + Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-20.0, 20.0))
		if _is_water(spot): continue
		_sites.append(Vector3(spot.x, _ground(spot), spot.y))
	for site_index: int in range(_sites.size()):
		var crows := site_index % 2 == 0
		var flock := {"site":site_index, "birds":[], "alarmed":false}
		var count := _rng.randi_range(4, 6) if crows else _rng.randi_range(7, 10)
		for index: int in range(count):
			var bird := {"crow":crows, "state":State.GROUND, "flock":flock, "timer":_rng.randf_range(0.0, 3.0), "yaw":_rng.randf_range(0.0, TAU), "peck":0.0, "velocity":Vector3.ZERO, "target":Vector3.ZERO, "phase":_rng.randf(), "flap":0.0, "size":(_rng.randf_range(0.46, 0.52) if crows else _rng.randf_range(0.33, 0.37)), "tint":(CROW if crows else PIGEON.lerp(Color("#8d97a0"), _rng.randf()))}
			bird["position"] = _land_spot(_sites[site_index])
			_birds.append(bird)
			(flock.birds as Array).append(bird)
		_flocks.append(flock)
	_bird_mesh = MultiMesh.new()
	_bird_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_bird_mesh.use_colors = true
	_bird_mesh.use_custom_data = true
	_bird_mesh.mesh = _bird_shape()
	_bird_mesh.instance_count = _birds.size()
	_bird_instance = MultiMeshInstance3D.new()
	_bird_instance.name = "Birds"
	_bird_instance.multimesh = _bird_mesh
	_bird_instance.material_override = _bird_material()
	_bird_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bird_instance.custom_aabb = AABB(Vector3(-260, -4, -220), Vector3(520, 60, 440))
	add_child(_bird_instance)
	_day_nodes.append(_bird_instance)
	for index: int in range(_birds.size()):
		_write_bird(index)

func _land_spot(site: Vector3) -> Vector3:
	var flat := Vector2(site.x, site.z) + Vector2(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-5.0, 5.0))
	if _is_water(flat): flat = Vector2(site.x, site.z)
	return Vector3(flat.x, _ground(flat) + 0.03, flat.y)

func _write_bird(index: int) -> void:
	var bird: Dictionary = _birds[index]
	var basis := Basis(Vector3.UP, float(bird.yaw)) * Basis(Vector3.RIGHT, -float(bird.peck))
	var size: float = bird.size
	if int(bird.state) != State.GROUND and Vector3(bird.velocity).length_squared() > 0.01:
		var forward := Vector3(bird.velocity).normalized()
		basis = Basis.looking_at(forward, Vector3.UP)
	_bird_mesh.set_instance_transform(index, Transform3D(basis.scaled(Vector3.ONE * size), Vector3(bird.position)))
	_bird_mesh.set_instance_color(index, Color(bird.tint).srgb_to_linear())
	var rate := 15.0 if bool(bird.crow) else 21.0
	_bird_mesh.set_instance_custom_data(index, Color(bird.flap, bird.phase, rate, 0.0))

func _threat_radius(node: Node3D) -> float:
	if node == _player:
		if bool(node.get("sprinting")): return THREAT_SPRINT
		if bool(node.get("crouching")): return THREAT_CROUCH
		return THREAT_WALK
	return THREAT_HOSTILE

func _scatter(flock: Dictionary, from: Vector3) -> void:
	if flock.alarmed: return
	flock.alarmed = true
	var options: Array[int] = []
	for index: int in range(_sites.size()):
		if index != int(flock.site) and _sites[index].distance_to(from) > 45.0: options.append(index)
	if options.is_empty(): options.append(int(flock.site))
	var next_site: int = options[_rng.randi_range(0, options.size() - 1)]
	flock.site = next_site
	for entry: Variant in flock.birds:
		var bird: Dictionary = entry
		var away := Vector3(bird.position) - from
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 0.01 else Vector3.FORWARD
		bird.state = State.FLEEING
		bird.flap = 1.0
		bird.timer = _rng.randf_range(0.0, 0.32) # Staggered take-off.
		bird.velocity = (away + Vector3.UP * _rng.randf_range(0.9, 1.3)).normalized() * FLIGHT_SPEED
		bird.target = _land_spot(_sites[next_site])

func _on_player_shot() -> void:
	if _night or _player == null: return
	for flock: Dictionary in _flocks:
		if flock.alarmed: continue
		if _sites[int(flock.site)].distance_to(_player.global_position) < SHOT_RANGE:
			_scatter(flock, _player.global_position)

func _check_threats() -> void:
	var threats: Array[Node3D] = []
	if _player != null: threats.append(_player)
	for hostile: Node in get_tree().get_nodes_in_group("extraction_hostiles"):
		if hostile is Node3D: threats.append(hostile as Node3D)
	for flock: Dictionary in _flocks:
		if flock.alarmed: continue
		var site := _sites[int(flock.site)]
		for threat: Node3D in threats:
			var radius := _threat_radius(threat) + 5.0 # Site radius.
			if site.distance_squared_to(threat.global_position) > radius * radius: continue
			for entry: Variant in flock.birds:
				var bird_radius := _threat_radius(threat)
				if Vector3(entry.position).distance_squared_to(threat.global_position) < bird_radius * bird_radius:
					_scatter(flock, threat.global_position)
					break
			if flock.alarmed: break

func _process(delta: float) -> void:
	if not installed or _night: return
	delta = minf(delta, 0.05)
	_threat_clock -= delta
	if _threat_clock <= 0.0:
		_threat_clock = THREAT_INTERVAL
		_check_threats()
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera != null else Vector3.ZERO
	var range_squared := ACTIVE_RANGE * ACTIVE_RANGE
	for index: int in range(_birds.size()):
		var bird: Dictionary = _birds[index]
		if int(bird.state) == State.GROUND:
			if Vector3(bird.position).distance_squared_to(eye) > range_squared: continue
			_step_ground(bird, delta)
		else:
			_step_flight(bird, delta)
		_write_bird(index)

func _step_ground(bird: Dictionary, delta: float) -> void:
	bird.timer = float(bird.timer) - delta
	var pecking := float(bird.timer) < 0.32
	bird.peck = move_toward(float(bird.peck), 0.6 if pecking else 0.0, delta * 7.0)
	if float(bird.timer) > 0.0: return
	bird.timer = _rng.randf_range(1.2, 4.0)
	# A short shuffle to fresh ground between pecks.
	bird.yaw = float(bird.yaw) + _rng.randf_range(-1.2, 1.2)
	var forward := Vector3(sin(float(bird.yaw)), 0.0, cos(float(bird.yaw))) * -_rng.randf_range(0.05, 0.28)
	var moved: Vector3 = Vector3(bird.position) + forward
	var flat := Vector2(moved.x, moved.z)
	if not _is_water(flat):
		moved.y = _ground(flat) + 0.03
		bird.position = moved

func _step_flight(bird: Dictionary, delta: float) -> void:
	if float(bird.timer) > 0.0:
		bird.timer = float(bird.timer) - delta
		return
	var at: Vector3 = bird.position
	var target: Vector3 = bird.target
	match int(bird.state):
		State.FLEEING:
			if at.y > target.y + CRUISE_HEIGHT * 0.6: bird.state = State.CRUISING
		State.CRUISING:
			var to_target := target - at
			to_target.y = 0.0
			var heading := (to_target.normalized() + Vector3.UP * clampf((target.y + CRUISE_HEIGHT - at.y) * 0.1, -0.3, 0.3)).normalized() * FLIGHT_SPEED
			bird.velocity = Vector3(bird.velocity).lerp(heading, 1.0 - exp(-2.0 * delta))
			if to_target.length() < 18.0:
				bird.state = State.LANDING
				bird.flap = 0.42 # Glide in.
		State.LANDING:
			var approach := target - at
			bird.velocity = Vector3(bird.velocity).lerp(approach.normalized() * minf(FLIGHT_SPEED, 1.2 + approach.length()), 1.0 - exp(-3.0 * delta))
			if approach.length() < 0.25:
				bird.position = target
				bird.state = State.GROUND
				bird.flap = 0.0
				bird.velocity = Vector3.ZERO
				bird.timer = _rng.randf_range(0.5, 3.0)
				var flock: Dictionary = bird.flock
				var settled := true
				for entry: Variant in flock.birds:
					if int(entry.state) != State.GROUND: settled = false
				if settled: flock.alarmed = false
				return
	bird.position = at + Vector3(bird.velocity) * delta

# ---------------------------------------------------------- shader critters

func _drift_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, skip_vertex_transform, cull_disabled, depth_draw_never;
uniform float size = 0.05;
uniform float kind = 0.0; // 0 firefly, 1 dragonfly, 2 moth.
uniform vec3 tint : source_color = vec3(0.7, 1.0, 0.3);
varying float blink;
void vertex() {
	// INSTANCE_CUSTOM: x phase, y speed, z radius, w lift.
	float t = TIME * INSTANCE_CUSTOM.y + INSTANCE_CUSTOM.x * 6.28;
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 offset;
	if (kind < 0.5) {
		offset = vec3(sin(t * 0.7) + sin(t * 0.31 + 1.0), sin(t * 0.43) * 0.5, cos(t * 0.59) + sin(t * 0.23)) * INSTANCE_CUSTOM.z;
		blink = pow(max(sin(t * 1.3 + INSTANCE_CUSTOM.x * 20.0), 0.0), 3.0);
	} else if (kind < 1.5) {
		// Dart, hover, dart: time is quantised through a smooth step.
		float s = floor(t) + smoothstep(0.7, 1.0, fract(t));
		offset = vec3(sin(s * 2.4), sin(s * 1.7) * 0.25 + 0.15, cos(s * 1.9)) * INSTANCE_CUSTOM.z;
		offset.y += sin(TIME * 7.0 + INSTANCE_CUSTOM.x * 9.0) * 0.012;
		blink = 1.0;
	} else {
		offset = vec3(cos(t), sin(t * 2.3) * 0.45, sin(t * 1.4)) * INSTANCE_CUSTOM.z;
		blink = 0.5 + 0.5 * sin(TIME * 34.0 + INSTANCE_CUSTOM.x * 40.0);
	}
	vec3 view = (VIEW_MATRIX * vec4(centre + offset, 1.0)).xyz;
	VERTEX = view + vec3(VERTEX.xy * size, 0.0);
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float mask;
	if (kind < 0.5) {
		mask = pow(max(1.0 - length(q), 0.0), 2.4) * blink;
		ALBEDO = tint * 3.2;
	} else if (kind < 1.5) {
		vec2 r = vec2(q.x * 0.36 - q.y * 0.93, q.x * 0.93 + q.y * 0.36);
		float body = (1.0 - smoothstep(0.022, 0.05, abs(r.x))) * step(abs(r.y), 0.9);
		float fore = 1.0 - smoothstep(0.8, 1.0, length(vec2(r.x / 0.9, (r.y - 0.42) / 0.11)));
		float hind = 1.0 - smoothstep(0.8, 1.0, length(vec2(r.x / 0.82, (r.y - 0.2) / 0.1)));
		mask = max(body, max(fore, hind) * 0.42);
		ALBEDO = mix(vec3(0.74, 0.85, 0.88), tint, body);
	} else {
		float wing = 1.0 - smoothstep(0.5, 0.9, length(vec2(abs(q.x) - 0.42 * (0.4 + 0.6 * blink), q.y)));
		mask = wing;
		ALBEDO = tint;
	}
	ALPHA = clamp(mask, 0.0, 1.0);
	if (ALPHA < 0.01) discard;
}
"""
	return shader

func _swarm(label: String, centres: PackedVector3Array, per_centre: int, spread: float, kind: float, size: float, tint: Color, speed: Vector2, radius: Vector2, range_end: float, shader: Shader, group: Array[Node3D]) -> void:
	if centres.is_empty(): return
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("size", size)
	material.set_shader_parameter("kind", kind)
	material.set_shader_parameter("tint", tint)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = centres.size() * per_centre
	var index := 0
	var low := Vector3.INF
	var high := -Vector3.INF
	for centre: Vector3 in centres:
		low = low.min(centre)
		high = high.max(centre)
		for i: int in range(per_centre):
			var p := centre + Vector3(_rng.randf_range(-spread, spread), _rng.randf_range(0.0, 1.0) * spread * 0.2, _rng.randf_range(-spread, spread))
			multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, p))
			multimesh.set_instance_custom_data(index, Color(_rng.randf(), _rng.randf_range(speed.x, speed.y), _rng.randf_range(radius.x, radius.y), 0.0))
			index += 1
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var margin := Vector3.ONE * (spread + radius.y * 3.0 + 2.0)
	instance.custom_aabb = AABB(low - margin, high - low + margin * 2.0)
	if range_end > 0.0: instance.visibility_range_end = range_end
	add_child(instance)
	group.append(instance)

func _build_koi(shore: PackedVector3Array) -> void:
	if shore.is_empty(): return
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform float night = 0.0;
varying vec3 fish_color;
varying vec2 local;
void vertex() {
	// Orbit on the water plane. INSTANCE_CUSTOM: x phase, y speed, z radius.
	float t = TIME * INSTANCE_CUSTOM.y + INSTANCE_CUSTOM.x * 6.28;
	float r = INSTANCE_CUSTOM.z * (1.0 + 0.3 * sin(t * 0.37));
	local = VERTEX.xz;
	float wag = sin(TIME * 5.0 + INSTANCE_CUSTOM.x * 30.0) * 0.16 * smoothstep(-0.05, 0.5, VERTEX.z);
	vec3 p = vec3(VERTEX.x + wag, VERTEX.y, VERTEX.z);
	float heading = -t;
	float c = cos(heading);
	float s = sin(heading);
	VERTEX = vec3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c) + vec3(cos(t) * r, 0.0, sin(t) * r);
	fish_color = COLOR.rgb;
}
void fragment() {
	float y = local.y;
	float t = clamp((y + 0.52) / 0.86, 0.0, 1.0);
	float body_width = 0.17 * sin(3.1416 * pow(t, 0.72));
	float body = 1.0 - smoothstep(body_width - 0.02, body_width + 0.005, abs(local.x));
	float fan = 0.13 * smoothstep(0.3, 0.56, y);
	float fork = smoothstep(0.42, 0.56, y) * 0.07;
	float tail = (1.0 - smoothstep(fan - 0.015, fan, abs(local.x))) * smoothstep(fork - 0.01, fork, abs(local.x)) * step(y, 0.57) * step(0.3, y);
	float fin = (1.0 - smoothstep(0.015, 0.05, abs(abs(local.x) - 0.2 + (y + 0.2) * 0.5))) * step(abs(y + 0.18), 0.09);
	// Soft patches, seeded per fish so no two share markings.
	float seed = fish_color.r * 7.0 + fish_color.g * 13.0;
	float marks = smoothstep(0.1, 0.32, sin(y * 9.0 + seed) * sin(local.x * 16.0 + seed * 2.0) + 0.24 * sin(y * 21.0 - seed));
	vec3 color = mix(fish_color, vec3(0.74, 0.7, 0.62), marks * 0.7);
	ALBEDO = mix(color, vec3(0.03, 0.06, 0.05), 0.3) * mix(1.0, 0.16, night);
	ALPHA = max(max(body, tail * 0.75), fin * 0.5) * 0.66;
	if (ALPHA < 0.01) discard;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("night", 1.0 if _night else 0.0)
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.5, 1.15)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = mini(72, shore.size() * 4)
	for index: int in range(multimesh.instance_count):
		# Four fish share a pool and a heading, so they read as a loose school.
		var pool := index / 4
		var at := shore[pool % shore.size()] + Vector3(_rng.randf_range(-1.0, 1.0), 0.012, _rng.randf_range(-1.0, 1.0))
		var scale_value := _rng.randf_range(0.45, 0.68)
		var direction := 1.0 if pool % 2 == 0 else -1.0
		multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * scale_value), at))
		multimesh.set_instance_color(index, KOI_COLORS[(index + pool) % KOI_COLORS.size()].srgb_to_linear())
		multimesh.set_instance_custom_data(index, Color(float(pool) * 0.37 + _rng.randf_range(0.0, 0.07), _rng.randf_range(0.2, 0.28) * direction, _rng.randf_range(3.0, 5.2), 0.0))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Koi"
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-240, -2, -200), Vector3(480, 4, 400))
	add_child(instance)
	set_meta("koi_material", material)

func _build_dragonflies(shore: PackedVector3Array) -> void:
	var shader := _drift_shader()
	var centres := PackedVector3Array()
	for index: int in range(0, shore.size(), 2):
		centres.append(shore[index] + Vector3.UP * 0.85)
	# Split into chunks so each hovering group culls with distance on its own.
	var chunk := 6
	for start: int in range(0, centres.size(), chunk):
		var part := centres.slice(start, start + chunk)
		_swarm("Dragonflies_%d" % start, part, 2, 3.0, 1.0, 0.062, Color("#1c7f9c"), Vector2(0.3, 0.55), Vector2(1.4, 3.0), 60.0, shader, _day_nodes)

func _build_fireflies() -> void:
	var shader := _drift_shader()
	for index: int in range(GROVES.size()):
		var spot := GROVES[index]
		if _is_water(spot): continue
		var centres := PackedVector3Array()
		for i: int in range(5):
			var p := spot + Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-14.0, 14.0))
			if not _is_water(p): centres.append(Vector3(p.x, _ground(p) + 0.75, p.y))
		_swarm("Fireflies_%d" % index, centres, 9, 3.6, 0.0, 0.1, Color("#c8f06a"), Vector2(0.35, 0.8), Vector2(0.5, 1.5), 90.0, shader, _night_nodes)

func _build_moths() -> void:
	var lamps := PackedVector3Array()
	for node: Node in _park.find_children("JapanesePathLamp_*", "Node3D", true, false):
		lamps.append((node as Node3D).global_position + Vector3.UP * 2.55)
	var shader := _drift_shader()
	var chunk := 10
	for start: int in range(0, lamps.size(), chunk):
		_swarm("LampMoths_%d" % start, lamps.slice(start, start + chunk), 4, 0.25, 2.0, 0.03, Color("#d7cdb2"), Vector2(1.2, 2.4), Vector2(0.28, 0.55), 55.0, shader, _night_nodes)

func set_night_mode(value: bool) -> void:
	_night = value
	if not installed: return
	for node: Node3D in _day_nodes: node.visible = not value
	for node: Node3D in _night_nodes: node.visible = value
	if has_meta("koi_material"):
		(get_meta("koi_material") as ShaderMaterial).set_shader_parameter("night", 1.0 if value else 0.0)
