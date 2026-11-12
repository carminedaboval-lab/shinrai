extends Node3D
## Green welded-mesh perimeter fence around Midori Park, in WORLD metres.
## Direct child of the scene root; never parent it to the 2x park layout.
##
## Day: every gate stands open. Night: the north, west and east gates are shut
## and chained (bolt cutters open them), the south main gate is smashed (one
## panel hangs off its top hinge, the other lies on the ground) and seven low
## holes along the sides let a prone player through.
const Budget = preload("res://scripts/shinrai_loading_budget.gd")
const Kit = preload("res://scripts/midori_park_kit.gd")
const GameInput = preload("res://scripts/shinrai_input.gd")
const StartupTrace = preload("res://scripts/startup_trace.gd")

const HEIGHT := 1.85
const BOTTOM := 0.10
const PANEL_SPAN := 2.5
const INSET := 0.6
const HALF := Vector2(220.0 - INSET, 180.0 - INSET)
const WIRE := 0.052
const HOLE_HALF_WIDTH := 0.48
const HOLE_TOP := 0.80 # Crouch capsule is 1.10 m tall; prone is 0.72 m.
const CUT_SECONDS := 2.6
const SWING_SECONDS := 1.3
const OUTSIDE_WALK_M := 11.0 # Pavement between the fence and the ring road.
const TOOL_ID := "bolt_cutters"
const HOLE_PROMPT_RANGE := 1.7
const OPEN_ANGLE := 1.815 # 104 degrees, into the park.
const HANG_LIFT := 0.22
const HANG_YAW := -0.593 # 34 degrees.
const HANG_DROOP := -0.113 # 6.5 degrees.
const HANG_KICK := 0.262 # 15 degrees.

## Gate openings. "at" is the point on the fence line, "width" the clear span.
const GATES: Array[Dictionary] = [
	{"id":"south","title":"South main gate","at":Vector2(0.0, HALF.y),"width":8.0,"smashed":true},
	{"id":"north","title":"North gate","at":Vector2(-76.0, -HALF.y),"width":6.0},
	{"id":"west","title":"West gate","at":Vector2(-HALF.x, 40.0),"width":6.0},
	{"id":"east","title":"East gate","at":Vector2(HALF.x, -40.0),"width":6.0},
]
## Seven prone-sized holes, all well away from the south main gate.
const HOLES: Array[Vector2] = [
	Vector2(-HALF.x, -118.0), Vector2(-HALF.x, 112.0),
	# East holes stay clear of the ring-road signal poles at z -136 and -120.
	Vector2(HALF.x, -146.0), Vector2(HALF.x, 98.0),
	Vector2(-168.0, -HALF.y), Vector2(118.0, -HALF.y),
	Vector2(-150.0, HALF.y),
]

var installed := false
var night := false
var report: Dictionary = {}
var park: Node3D
var _frame: StandardMaterial3D
var _steel: StandardMaterial3D
var _chain: StandardMaterial3D
var _dirt: StandardMaterial3D
var _tape: StandardMaterial3D
var _net: ShaderMaterial
var _space: PhysicsDirectSpaceState3D
var _terrain: Node
var _posts: Array[Transform3D] = []
var _rails: Array[Transform3D] = []
var _gates: Array[Dictionary] = []
var _hole_points: Array[Vector3] = []
var _holes: Array[Dictionary] = []
var _sway_time := 0.0
var _active_gate: Dictionary = {}
var _hold := 0.0
var hold_ratio := 0.0
var _key_latched := true

func _ready() -> void:
	add_to_group("midori_horizon")
	park = get_parent() as Node3D
	await Budget.wait_structure(park)
	_terrain = park.get_node_or_null("MidoriTerrain")
	while _terrain != null and _terrain.get("installed") != true:
		await get_tree().process_frame
	# The south arrival paving reaches Z180; its collision must exist first.
	var street: Node = park.get_node_or_null("MidoriSouthStreet")
	while street != null and street.get("installed") != true:
		await get_tree().process_frame
	await get_tree().physics_frame
	_build()

func _build() -> void:
	var tick := StartupTrace.begin()
	set_as_top_level(true)
	global_transform = Transform3D.IDENTITY
	night = bool(park.get("is_night_mode"))
	_space = get_world_3d().direct_space_state
	_make_materials()
	var body := StaticBody3D.new()
	body.name = "PerimeterCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var corners: Array[Vector2] = [Vector2(-HALF.x, -HALF.y), Vector2(HALF.x, -HALF.y), Vector2(HALF.x, HALF.y), Vector2(-HALF.x, HALF.y)]
	var panel_count := 0
	var hole_count := 0
	for side: int in range(4):
		var a := corners[side]
		var b := corners[(side + 1) % 4]
		var direction := (b - a).normalized()
		var length := a.distance_to(b)
		# Cut the side at every gate on it; piers belong to the gate node.
		var cuts: Array[Vector2] = []
		for gate: Dictionary in GATES:
			var at: Vector2 = gate.at
			var t := (at - a).dot(direction)
			if t < -0.5 or t > length + 0.5 or absf((at - a).cross(direction)) > 0.5: continue
			cuts.append(Vector2(t - float(gate.width) * 0.5 - 0.14, t + float(gate.width) * 0.5 + 0.14))
		cuts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
		var runs: Array[Vector2] = []
		var cursor := 0.0
		for cut: Vector2 in cuts:
			if cut.x > cursor + 0.2: runs.append(Vector2(cursor, cut.x))
			cursor = cut.y
		if cursor < length - 0.2: runs.append(Vector2(cursor, length))
		var side_mesh := SurfaceTool.new()
		side_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
		for run: Vector2 in runs:
			var counts := _build_run(body, a, direction, run, side_mesh)
			panel_count += int(counts.x)
			hole_count += int(counts.y)
		var mesh := side_mesh.commit()
		if mesh.get_surface_count() > 0:
			mesh.surface_set_material(0, _net)
			var instance := MeshInstance3D.new()
			instance.name = "Mesh_Side_%d" % side
			instance.mesh = mesh
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)
	_commit_multimesh("Posts", BoxMesh.new(), Vector3(0.06, HEIGHT, 0.06), _posts, _frame)
	_commit_multimesh("Rails", BoxMesh.new(), Vector3(1.0, 0.045, 0.045), _rails, _frame)
	for gate: Dictionary in GATES:
		_gates.append(_build_gate(gate))
	_build_outside_walk()
	_apply_gate_states()
	installed = true
	report = {"panels":panel_count, "holes":hole_count, "gates":_gates.size(), "night":night, "posts":_posts.size()}
	print("MIDORI_PARK_FENCE_READY ", JSON.stringify(report))
	StartupTrace.finish("park_fence.build", tick)

func _make_materials() -> void:
	_frame = Kit.mat(Color("#2f5438"), .58, .42)
	_steel = Kit.mat(Color("#4a5553"), .52, .62)
	_chain = Kit.mat(Color("#6a6f6c"), .45, .85)
	_dirt = Kit.mat(Color("#3b2f24"), .97, 0.0)
	_tape = Kit.mat(Color("#d9651e"), .7, 0.0)
	_tape.emission_enabled = true
	_tape.emission = Color("#d9651e")
	_tape.emission_energy_multiplier = 0.35
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform float night = 0.0;
uniform vec3 hole_centres[7];
varying vec3 world_p;
// Half-width of one wire in pattern units: where the old cut-out sat
// (smoothstep(0.045, 0.12, d) crossing the 0.45 threshold).
const float HALF_WIRE = 0.085;
// Share of a pixel footprint of width w, centred on x, that one family of
// wires covers: the exact box filter of a wire on every half-integer.
float wire_cover(float x, float w) {
	float f = fract(x - 0.5 * w);
	float e = f + w;
	float lo = 0.5 - HALF_WIRE;
	float c0 = clamp(f - lo, 0.0, 2.0 * HALF_WIRE);
	float c1 = floor(e) * 2.0 * HALF_WIRE + clamp(fract(e) - lo, 0.0, 2.0 * HALF_WIRE);
	return clamp((c1 - c0) / w, 0.0, 1.0);
}
void vertex() { world_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float sa = UV.x + UV.y;
	float sb = UV.x - UV.y;
	// Pattern periods per pixel for each diagonal (taken before any discard).
	float wa = max(length(vec2(dFdx(sa), dFdy(sa))), 0.0001);
	float wb = max(length(vec2(dFdx(sb), dFdy(sb))), 0.0001);
	for (int i = 0; i < 7; i++) {
		vec3 q = world_p - hole_centres[i];
		if (length(q.xz) < 0.50 && q.y < 0.80 - 0.09 * sin(q.x * 9.0 + q.z * 9.0)) discard;
	}
	// Near: a one-pixel soft wire edge. As a diagonal nears two pixels per
	// period it settles on its true average cover, so the two together read as
	// the mesh's real 31 % veil instead of moire.
	float ca = mix(wire_cover(sa, wa), 2.0 * HALF_WIRE, smoothstep(0.25, 0.6, wa));
	float cb = mix(wire_cover(sb, wb), 2.0 * HALF_WIRE, smoothstep(0.25, 0.6, wb));
	ALBEDO = mix(vec3(0.19, 0.35, 0.21), vec3(0.12, 0.2, 0.13), night * 0.6);
	METALLIC = 0.25;
	ROUGHNESS = 0.7;
	// Blended, no scissor: depth_prepass_alpha still writes depth for solid wire.
	ALPHA = 1.0 - (1.0 - ca) * (1.0 - cb);
}
"""
	_net = ShaderMaterial.new()
	_net.shader = shader
	_net.resource_name = "SHINRAI_ParkFenceMesh"
	_net.set_shader_parameter("night", 1.0 if night else 0.0)

func _ground(point: Vector2) -> float:
	if _space != null:
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 8.0, point.y), Vector3(point.x, -4.0, point.y), 1)
		var hit: Dictionary = _space.intersect_ray(query)
		if not hit.is_empty(): return float(hit.position.y)
	if _terrain != null and _terrain.has_method("height_at"): return float(_terrain.height_at(point))
	return 0.0

## Builds one straight run of fence (posts, rails, mesh, collision). Returns
## Vector2(panels, holes).
func _build_run(body: StaticBody3D, a_end: Vector2, direction: Vector2, run: Vector2, st: SurfaceTool) -> Vector2:
	var length := run.y - run.x
	var sections := maxi(1, ceili(length / PANEL_SPAN))
	var normal := Vector3(-direction.y, 0.0, direction.x) # Toward the park centre.
	var hole_total := 0
	var points: Array[Vector3] = []
	for index: int in range(sections + 1):
		var p := a_end + direction * (run.x + length * float(index) / float(sections))
		points.append(Vector3(p.x, _ground(p), p.y))
		_posts.append(Transform3D(Basis.IDENTITY, points[index] + Vector3.UP * (HEIGHT * 0.5)))
	var stretch_start := 0
	for index: int in range(sections):
		var a := points[index]
		var b := points[index + 1]
		_add_rail(a + Vector3.UP * (HEIGHT - 0.03), b + Vector3.UP * (HEIGHT - 0.03))
		_add_rail(a + Vector3.UP * BOTTOM, b + Vector3.UP * BOTTOM)
		_add_panel(st, a, b, BOTTOM, HEIGHT - 0.05)
		var hole_t := -1.0
		var span := a.distance_to(b)
		for hole: Vector2 in HOLES:
			var offset := hole - Vector2(a.x, a.z)
			var t := offset.dot(direction) / span
			# A listed spot can land on a post, so centre the gap in its panel.
			if t >= 0.0 and t < 1.0 and absf(offset.cross(direction)) < 1.0:
				hole_t = clampf(t, 0.32, 0.68)
				break
		if hole_t < 0.0: continue
		hole_total += 1
		# The side collider stops either side of the panel, which keeps its own
		# pieces so the fence stays solid above and around the gap.
		_add_collision(body, points[stretch_start], a, 0.0, HEIGHT)
		stretch_start = index + 1
		var left := a.lerp(b, maxf(0.0, hole_t - HOLE_HALF_WIDTH / span))
		var right := a.lerp(b, minf(1.0, hole_t + HOLE_HALF_WIDTH / span))
		_add_collision(body, a, left, 0.0, HOLE_TOP)
		_add_collision(body, right, b, 0.0, HOLE_TOP)
		_add_collision(body, left, right, HOLE_TOP, HEIGHT)
		_build_hole(a, b, left, right, normal, Vector3(direction.x, 0.0, direction.y))
	if stretch_start < sections: _add_collision(body, points[stretch_start], points[sections], 0.0, HEIGHT)
	return Vector2(sections, hole_total)

## The side mesh is always whole. By night a hole cuts the wire with a clip that
## discards fragments, and its collider patch is disabled; by day the patch and
## the intact wire read as an undamaged fence.
func _build_hole(a: Vector3, b: Vector3, left: Vector3, right: Vector3, normal: Vector3, along: Vector3) -> void:
	var centre := (left + right) * 0.5
	var root := Node3D.new()
	root.name = "FenceHole_%d" % (_holes.size() + 1)
	add_child(root)
	root.position = centre
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_flap(st, left - centre, left - centre + Vector3.UP * (HOLE_TOP - 0.12), -normal * 0.34 - along * 0.10)
	_add_flap(st, right - centre, right - centre + Vector3.UP * (HOLE_TOP - 0.12), -normal * 0.30 + along * 0.12)
	var mesh := st.commit()
	mesh.surface_set_material(0, _net)
	var flaps := MeshInstance3D.new()
	flaps.name = "TornWire"
	flaps.mesh = mesh
	flaps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flaps)
	var blackout := Kit.box(root, "BrokenBottomRail", Vector3(0.5, 0.03, 0.03), Vector3(0, BOTTOM, 0) - normal * 0.16, _frame)
	blackout.rotation.y = -atan2(along.z, along.x) + 0.5
	# Tells for anyone searching the fence line at night: scuffed earth both sides
	# and scraps of flagging tape tied to the cut wire.
	var cues := Node3D.new()
	cues.name = "Cues"
	root.add_child(cues)
	var yaw := -atan2(along.z, along.x)
	for side: float in [-1.0, 1.0]:
		var scuff := Kit.box(cues, "ScuffedEarth", Vector3(1.5, 0.012, 1.3), normal * side * 0.75 + Vector3.UP * 0.02, _dirt)
		scuff.rotation.y = yaw
		scuff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for offset: float in [-0.52, 0.52]:
		var tag := Kit.box(cues, "FlaggingTape", Vector3(0.05, 0.3, 0.012), along * offset + Vector3.UP * (HOLE_TOP - 0.02) - normal * 0.05, _tape)
		tag.rotation = Vector3(0.18 * signf(offset), yaw, 0.1)
	var body := StaticBody3D.new()
	body.name = "DayPatch"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(left.distance_to(right), HOLE_TOP, 0.10)
	shape.shape = box
	shape.position = Vector3(0, HOLE_TOP * 0.5, 0)
	shape.rotation.y = -atan2(along.z, along.x)
	body.add_child(shape)
	root.add_child(body)
	# Night clip region for the shared wire shader, one vec4 per hole.
	_holes.append({"root":root, "flaps":flaps, "rail":blackout, "cues":cues, "shape":shape, "centre":centre, "along":along})
	_hole_points.append(centre)

func _add_collision(body: StaticBody3D, a: Vector3, b: Vector3, bottom: float, top: float) -> void:
	var length := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
	if length < 0.05: return
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, top - bottom, 0.10)
	shape.shape = box
	shape.position = Vector3((a.x + b.x) * 0.5, minf(a.y, b.y) + (bottom + top) * 0.5, (a.z + b.z) * 0.5)
	shape.rotation.y = -atan2(b.z - a.z, b.x - a.x)
	body.add_child(shape)

func _add_rail(a: Vector3, b: Vector3) -> void:
	var span := b - a
	if span.length() < 0.05: return
	var side := span.normalized().cross(Vector3.UP).normalized()
	_rails.append(Transform3D(Basis(span, Vector3.UP, side), (a + b) * 0.5))

func _add_panel(st: SurfaceTool, a: Vector3, b: Vector3, bottom: float, top: float) -> void:
	var width := a.distance_to(b)
	if width < 0.03 or top - bottom < 0.03: return
	var corners: Array[Vector3] = [a + Vector3.UP * bottom, b + Vector3.UP * bottom, b + Vector3.UP * top, a + Vector3.UP * top]
	var uvs: Array[Vector2] = [Vector2(0, bottom / WIRE), Vector2(width / WIRE, bottom / WIRE), Vector2(width / WIRE, top / WIRE), Vector2(0, top / WIRE)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uvs[i])
		st.add_vertex(corners[i])

func _add_flap(st: SurfaceTool, foot: Vector3, head: Vector3, curl: Vector3) -> void:
	var corners: Array[Vector3] = [foot, foot + curl, head + curl * 0.55, head]
	var uvs: Array[Vector2] = [Vector2.ZERO, Vector2(curl.length() / WIRE, 0), Vector2(curl.length() / WIRE, HOLE_TOP / WIRE), Vector2(0, HOLE_TOP / WIRE)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uvs[i])
		st.add_vertex(corners[i])

func _commit_multimesh(label: String, mesh: BoxMesh, size: Vector3, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty(): return
	mesh.size = size
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = multimesh
	add_child(instance)

# ------------------------------------------------------------------ gates

func _build_gate(spec: Dictionary) -> Dictionary:
	var at: Vector2 = spec.at
	var width := float(spec.width)
	# Local +x runs along the fence line, local +z points into the park.
	var direction := Vector2.ZERO
	var normal := Vector2.ZERO
	if absf(at.y) > HALF.y - 0.01:
		direction = Vector2(1, 0) if at.y < 0.0 else Vector2(-1, 0)
	else:
		direction = Vector2(0, 1) if at.x > 0.0 else Vector2(0, -1)
	normal = Vector2(-direction.y, direction.x)
	var base := _ground(at)
	var root := Node3D.new()
	root.name = "Gate_" + str(spec.id)
	add_child(root)
	root.global_transform = Transform3D(Basis(Vector3(direction.x, 0, direction.y), Vector3.UP, Vector3(normal.x, 0, normal.y)), Vector3(at.x, base, at.y))
	var gate := {"id":spec.id, "title":spec.title, "root":root, "width":width, "smashed":bool(spec.get("smashed", false)), "locked":false, "opening":false, "open":true, "progress":1.0, "panels":[], "chain":null}
	for side: float in [-1.0, 1.0]:
		Kit.box(root, "Pier", Vector3(0.14, HEIGHT + 0.30, 0.14), Vector3(side * (width * 0.5 + 0.07), (HEIGHT + 0.30) * 0.5, 0.0), _frame)
		Kit.box(root, "PierCap", Vector3(0.20, 0.05, 0.20), Vector3(side * (width * 0.5 + 0.07), HEIGHT + 0.325, 0.0), _frame)
		for y: float in [0.35, HEIGHT - 0.25]:
			Kit.box(root, "Hinge", Vector3(0.05, 0.12, 0.09), Vector3(side * (width * 0.5 - 0.02), y, 0.04), _steel)
		var leaf := width * 0.5 - 0.09
		var pivot := Node3D.new()
		pivot.name = "Pivot_%s" % ("A" if side < 0.0 else "B")
		root.add_child(pivot)
		pivot.position = Vector3(side * (width * 0.5 - 0.02), HEIGHT, 0.0)
		var panel := AnimatableBody3D.new()
		panel.name = "Panel"
		panel.collision_layer = 1
		panel.collision_mask = 0
		panel.sync_to_physics = false
		pivot.add_child(panel)
		panel.position = Vector3(0, -HEIGHT, 0)
		var centre := -side * leaf * 0.5
		var frame_y := BOTTOM + (HEIGHT - BOTTOM) * 0.5
		Kit.box(panel, "HingeStile", Vector3(0.06, HEIGHT - BOTTOM, 0.06), Vector3(0, frame_y, 0), _frame)
		Kit.box(panel, "LatchStile", Vector3(0.06, HEIGHT - BOTTOM, 0.06), Vector3(-side * leaf, frame_y, 0), _frame)
		Kit.box(panel, "TopRail", Vector3(leaf, 0.05, 0.05), Vector3(centre, HEIGHT - 0.03, 0), _frame)
		Kit.box(panel, "BottomRail", Vector3(leaf, 0.05, 0.05), Vector3(centre, BOTTOM + 0.03, 0), _frame)
		Kit.box(panel, "MidRail", Vector3(leaf, 0.04, 0.04), Vector3(centre, 1.0, 0), _frame)
		Kit.box(panel, "Handle", Vector3(0.04, 0.18, 0.08), Vector3(-side * (leaf - 0.12), 1.02, 0.06), _steel)
		var net := MeshInstance3D.new()
		net.name = "Mesh"
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var x0 := minf(0.0, -side * leaf) + 0.03
		var x1 := maxf(0.0, -side * leaf) - 0.03
		_add_panel(st, Vector3(x0, 0, 0), Vector3(x1, 0, 0), BOTTOM + 0.05, HEIGHT - 0.05)
		var net_mesh := st.commit()
		net_mesh.surface_set_material(0, _net)
		net.mesh = net_mesh
		net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		panel.add_child(net)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(leaf, HEIGHT - BOTTOM, 0.08)
		shape.shape = box
		shape.position = Vector3(centre, frame_y, 0)
		panel.add_child(shape)
		gate.panels.append({"pivot":pivot, "body":panel, "shape":shape, "side":side, "leaf":leaf})
	# Chain and padlock across the meeting stiles, shown only while locked.
	var chain := Node3D.new()
	chain.name = "ChainLock"
	root.add_child(chain)
	chain.position = Vector3(0, 1.0, 0.05)
	for i: int in range(5):
		var link := Kit.box(chain, "Link", Vector3(0.09, 0.035, 0.012), Vector3(-0.18 + 0.09 * float(i), 0.0, 0.0), _chain)
		link.rotation.x = PI * 0.5 * float(i % 2)
	Kit.box(chain, "Padlock", Vector3(0.075, 0.095, 0.035), Vector3(0.0, -0.09, 0.0), _chain)
	Kit.box(chain, "Shackle", Vector3(0.05, 0.05, 0.012), Vector3(0.0, -0.025, 0.0), _steel)
	gate.chain = chain
	if gate.smashed:
		# Broken lower hinge on pier A: a bent stub rather than a clean plate.
		var stub := Kit.box(root, "BrokenHinge", Vector3(0.05, 0.10, 0.11), Vector3(-(width * 0.5 - 0.02), 0.30, 0.09), _steel)
		stub.rotation.z = deg_to_rad(-28.0)
		stub.rotation.x = deg_to_rad(22.0)
	return gate

func _apply_gate_states() -> void:
	for gate: Dictionary in _gates:
		gate.locked = night and not gate.smashed
		gate.open = not night or gate.smashed
		gate.opening = false
		gate.progress = 0.0 if night else 1.0
		(gate.chain as Node3D).visible = gate.locked
		for panel: Dictionary in gate.panels:
			(panel.shape as CollisionShape3D).disabled = false
			if night and gate.smashed:
				_pose_smashed(gate, panel)
			else:
				_pose_swing(gate, panel, 0.0 if night else OPEN_ANGLE)
	for hole: Dictionary in _holes:
		(hole.flaps as Node3D).visible = night
		(hole.rail as Node3D).visible = night
		(hole.cues as Node3D).visible = night
		(hole.shape as CollisionShape3D).disabled = night
	_sync_hole_clips()

func _sync_hole_clips() -> void:
	# The wire shader discards fragments inside active holes.
	var centres := PackedVector3Array()
	for hole: Dictionary in _holes:
		centres.append(hole.centre if night else Vector3(0, -100, 0))
	while centres.size() < HOLES.size(): centres.append(Vector3(0, -100, 0))
	_net.set_shader_parameter("hole_centres", centres)

func _pose_swing(gate: Dictionary, panel: Dictionary, angle: float) -> void:
	var pivot: Node3D = panel.pivot
	var side: float = panel.side
	pivot.position = Vector3(side * (float(gate.width) * 0.5 - 0.02), HEIGHT, 0.0)
	pivot.basis = Basis(Vector3.UP, side * angle)

func _pose_smashed(gate: Dictionary, panel: Dictionary) -> void:
	var pivot: Node3D = panel.pivot
	if float(panel.side) < 0.0:
		# Torn off its lower hinge: it hangs from the top one, heel lifted, toe
		# dropped to the ground and swung part way into the park.
		pivot.position = Vector3(-(float(gate.width) * 0.5 - 0.02), HEIGHT + HANG_LIFT, 0.0)
		pivot.basis = Basis(Vector3.UP, HANG_YAW) * Basis(Vector3.BACK, HANG_DROOP) * Basis(Vector3.RIGHT, HANG_KICK)
	else:
		# Ripped clean off and lying flat just inside the park. A flat gate is
		# something you walk over, so it has no collision.
		(panel.shape as CollisionShape3D).disabled = true
		pivot.position = Vector3(float(gate.width) * 0.5 - 0.42, 0.06, 0.72)
		pivot.basis = Basis(Vector3.UP, deg_to_rad(13.0)) * Basis(Vector3.RIGHT, deg_to_rad(-88.5))

func set_night_mode(value: bool) -> void:
	night = value
	if _net != null: _net.set_shader_parameter("night", 1.0 if value else 0.0)
	if installed: _apply_gate_states()

## Called when a raid starts: night gates are chained again.
func reset_for_raid() -> void:
	_hold = 0.0
	hold_ratio = 0.0
	_active_gate = {}
	_key_latched = true
	if installed: _apply_gate_states()

# ---------------------------------------------------------- outside walk

func _build_outside_walk() -> void:
	# Invisible pavement collision between the park edge and the ring road, so
	# the holes and the smashed gate lead somewhere a player can stand.
	var body := StaticBody3D.new()
	body.name = "OutsidePavementCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("midori_walk_surface")
	add_child(body)
	var outer := Vector2(220.0 + OUTSIDE_WALK_M, 180.0 + OUTSIDE_WALK_M)
	for spec: Array in [[Vector2(0, -(180.0 + OUTSIDE_WALK_M * 0.5)), Vector2(outer.x * 2.0, OUTSIDE_WALK_M)], [Vector2(0, 180.0 + OUTSIDE_WALK_M * 0.5), Vector2(outer.x * 2.0, OUTSIDE_WALK_M)], [Vector2(-(220.0 + OUTSIDE_WALK_M * 0.5), 0), Vector2(OUTSIDE_WALK_M, 360.0)], [Vector2(220.0 + OUTSIDE_WALK_M * 0.5, 0), Vector2(OUTSIDE_WALK_M, 360.0)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(spec[1].x, 1.0, spec[1].y)
		shape.shape = box
		shape.position = Vector3(spec[0].x, -0.58, spec[0].y)
		body.add_child(shape)

# ----------------------------------------------------------- interaction

func _nearest_gate(point: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for gate: Dictionary in _gates:
		var local: Vector3 = (gate.root as Node3D).to_local(point)
		if absf(local.x) > float(gate.width) * 0.5 + 0.6 or absf(local.z) > 2.4 or absf(local.y) > 2.5: continue
		var distance := absf(local.z)
		if distance < best_distance:
			best_distance = distance
			best = gate
	return best

func interaction_distance(player: Node3D) -> float:
	if not installed or player == null: return INF
	var gate := _nearest_gate(player.global_position)
	if gate.is_empty() or not gate.locked: return INF
	return absf((gate.root as Node3D).to_local(player.global_position).z)

func _has_tool(raid: Node) -> bool:
	if raid == null: return false
	var bag: Variant = raid.get("bag")
	if not bag is Array: return false
	for item: Variant in bag:
		if item is Dictionary and str(item.get("id", "")) == TOOL_ID: return true
	return false

## Mirrors midori_pitch_gate.consume_interaction: returns the prompt when the
## locked gate is the player's nearest target, and advances the cut while E
## is held.
func consume_interaction(raid: Node, player: Node3D, competing_distance: float, eligible: bool, pressed: bool, delta: float) -> String:
	if not installed or player == null:
		_key_latched = true
		return ""
	var gate := _nearest_gate(player.global_position)
	if gate.is_empty() or not gate.locked:
		_hold = 0.0
		hold_ratio = 0.0
		_key_latched = pressed
		return _hole_prompt(player)
	var distance := absf((gate.root as Node3D).to_local(player.global_position).z)
	if competing_distance < distance or not eligible:
		_hold = 0.0
		hold_ratio = 0.0
		_key_latched = pressed
		return ""
	if not _has_tool(raid):
		_hold = 0.0
		hold_ratio = 0.0
		_key_latched = pressed
		return "Chained shut  ·  needs bolt cutters"
	if pressed and not _key_latched:
		_hold += delta
		hold_ratio = clampf(_hold / CUT_SECONDS, 0.0, 1.0)
		if _hold >= CUT_SECONDS:
			_cut(gate)
			_hold = 0.0
			hold_ratio = 0.0
			_key_latched = true
			if raid != null and raid.has_method("announce"): raid.call("announce", str(gate.title) + " chain cut", 2.5)
			return "Chain cut  ·  gate swinging open"
		return "Cutting chain"
	if not pressed: _key_latched = false
	_hold = 0.0
	hold_ratio = 0.0
	return "Hold E  ·  Cut gate chain"

func _hole_prompt(player: Node3D) -> String:
	if not night or bool(player.get("prone")): return ""
	for centre: Vector3 in _hole_points:
		if Vector2(centre.x, centre.z).distance_squared_to(Vector2(player.global_position.x, player.global_position.z)) < HOLE_PROMPT_RANGE * HOLE_PROMPT_RANGE:
			return GameInput.hint("Z") + "  ·  Go prone to crawl through"
	return ""

func _cut(gate: Dictionary) -> void:
	gate.locked = false
	gate.opening = true
	gate.progress = 0.0
	(gate.chain as Node3D).visible = false

func _physics_process(delta: float) -> void:
	if not installed: return
	if night: _sway_hanging_panel(delta)
	for gate: Dictionary in _gates:
		if not gate.opening: continue
		gate.progress = minf(1.0, float(gate.progress) + delta / SWING_SECONDS)
		var t: float = gate.progress
		var eased := t * t * (3.0 - 2.0 * t)
		for panel: Dictionary in gate.panels:
			_pose_swing(gate, panel, OPEN_ANGLE * eased)
		if t >= 1.0:
			gate.opening = false
			gate.open = true

func _sway_hanging_panel(delta: float) -> void:
	# The loose panel creaks a little on its one hinge in the night wind.
	_sway_time += delta
	var camera := get_viewport().get_camera_3d()
	for gate: Dictionary in _gates:
		if not gate.smashed: continue
		var root: Node3D = gate.root
		if camera == null or camera.global_position.distance_squared_to(root.global_position) > 3600.0: continue
		var yaw := HANG_YAW + 0.022 * sin(_sway_time * 0.9) + 0.012 * sin(_sway_time * 2.3 + 1.0)
		(gate.panels[0].pivot as Node3D).basis = Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, HANG_DROOP) * Basis(Vector3.RIGHT, HANG_KICK)

## True when the route crosses a gate that is still shut, so guidance does not
## draw a path through chained steel.
func blocks_route(from: Vector3, points: PackedVector3Array) -> bool:
	if not installed: return false
	for gate: Dictionary in _gates:
		if gate.open and not gate.opening: continue
		var root: Node3D = gate.root
		var a := root.to_local(from)
		for point: Vector3 in points:
			var b := root.to_local(point)
			if (a.z <= 0.0 and b.z >= 0.0) or (a.z >= 0.0 and b.z <= 0.0):
				if absf(b.z - a.z) > 0.0001:
					var crossing := a.lerp(b, -a.z / (b.z - a.z))
					if absf(crossing.x) <= float(gate.width) * 0.5 + 0.3 and absf(crossing.y) < HEIGHT: return true
			a = b
	return false

func hole_positions() -> Array[Vector3]:
	return _hole_points.duplicate()
