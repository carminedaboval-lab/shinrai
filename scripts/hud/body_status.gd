extends Control
## See-through body status (Gray Zone / Tarkov style). The player's own
## character model is rendered front-on as a hologram in a small viewport:
## glass-clear in the middle, glowing at its silhouette, slowly breathing in
## its idle. Every vertex is tinted by the medical part its strongest bone
## belongs to, so each part fades from pale glass through amber to red, and a
## destroyed part goes dark. Bleeding parts drip and pulse, fractured limbs show
## a broken bone, and a part that just took damage flashes. It sits faint at the
## edge of the screen and comes forward when you are hurt or checking vitals.
const UIStyle = preload("res://scripts/hud/shinrai_ui_style.gd")
const Medical = preload("res://scripts/extraction_medical.gd")
const ShaderPool = preload("res://scripts/shinrai_shader_pool.gd")
const MODEL_PATH := "res://assets/characters/urban_explorer_2050/urban_explorer_2050_body.glb"
const PARTS := ["head", "thorax", "stomach", "left_arm", "right_arm", "left_leg", "right_leg"]
const SHORT := {"head":"HEAD", "thorax":"THORAX", "stomach":"STOMACH", "left_arm":"L ARM", "right_arm":"R ARM", "left_leg":"L LEG", "right_leg":"R LEG"}
const HEALTHY := Color(0.62, 0.9, 0.95)
const WORN := Color(1.0, 0.78, 0.42)
const HURT := Color(1.0, 0.38, 0.2)
const DEAD := Color(0.35, 0.04, 0.03)
const SHADOW := Color(0.01, 0.025, 0.035)
const VIEW_SIZE := Vector2i(220, 440)
## Where the overlay icons sit, by bone.
const ANCHOR_BONES := {"head":"mixamorig_Head", "thorax":"mixamorig_Spine2", "stomach":"mixamorig_Spine", "left_arm":"mixamorig_LeftForeArm", "right_arm":"mixamorig_RightForeArm", "left_leg":"mixamorig_LeftLeg", "right_leg":"mixamorig_RightLeg"}

const HOLO_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
uniform vec4 part_color[7];
uniform int bind_part[96];
varying flat int part;
void vertex() {
	int best = 0;
	float weight = -1.0;
	for (int i = 0; i < 4; i++) {
		if (BONE_WEIGHTS[i] > weight) { weight = BONE_WEIGHTS[i]; best = int(BONE_INDICES[i]); }
	}
	part = bind_part[clamp(best, 0, 95)];
}
void fragment() {
	vec4 c = part_color[part];
	// X-ray skin: almost nothing facing the viewer, a soft glow at the outline,
	// so the body reads as a smooth shell and the skeleton shows through.
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 2.6);
	ALBEDO = c.rgb * (0.55 + 1.5 * rim);
	ALPHA = c.a * (0.05 + 0.95 * rim);
}
"""

const BONE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, blend_mix;
uniform vec4 bone_color : source_color = vec4(0.9, 0.96, 0.97, 0.9);
uniform float glow = 0.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 1.5);
	ALBEDO = bone_color.rgb * (0.7 + 0.9 * rim) + vec3(1.0, 0.55, 0.3) * glow;
	ALPHA = clamp(bone_color.a * (0.5 + 0.5 * rim) + glow, 0.0, 1.0);
}
"""

var hp: Dictionary = {}
var max_hp: Dictionary = Medical.MAX_HP
var bleeding: Dictionary = {}
var fractures: Dictionary = {}
var inspecting := false
var presence := 0.35
var _flash: Dictionary = {}
var _clock := 0.0
var _viewport: SubViewport
var _camera: Camera3D
var _skeleton: Skeleton3D
var _materials: Array[ShaderMaterial] = []
var _anchors: Dictionary = {}
var _bone_materials: Dictionary = {}
## Fracture rig per limb: the whole long bone, its two broken halves and the glowing break.
var _breaks: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_viewport()

## Copies the medical state; a part that lost HP since last time flashes.
func feed(medical: Object, checking: bool) -> void:
	inspecting = checking
	if medical == null: return
	var source_hp: Dictionary = medical.get("hp")
	for part: String in PARTS:
		var value := float(source_hp.get(part, 0.0))
		if hp.has(part) and value < float(hp[part]) - 0.01: _flash[part] = 1.0
		hp[part] = value
	bleeding = medical.get("bleeding")
	fractures = medical.get("fractures")

func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null: return
	var model := packed.instantiate() as Node3D
	_viewport.add_child(model)
	for node: Node in model.find_children("*", "", true, false):
		if node is Skeleton3D: _skeleton = node
		if node is AnimationPlayer:
			var player := node as AnimationPlayer
			if player.has_animation("Idle_02"):
				# No clip: the figure stands in its rest pose, posed below.
				player.stop()
		if node is MeshInstance3D:
			var mesh := node as MeshInstance3D
			var material := ShaderMaterial.new()
			material.shader = _holo_shader()
			material.set_shader_parameter("bind_part", _bind_parts(mesh))
			mesh.material_override = material
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_materials.append(material)
	_pose_standing()
	_build_bones()
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 1.86
	_camera.position = Vector3(0, 0.9, 3.0)
	_viewport.add_child(_camera)
	_camera.look_at(Vector3(0, 0.9, 0))
	_camera.make_current()

## Rest pose is a T-pose facing the camera; drop both arms into a relaxed,
## slightly open stance so the silhouette reads like a person standing.
func _pose_standing() -> void:
	if _skeleton == null: return
	_skeleton.reset_bone_poses()
	# Each upper arm is turned (about the axis facing the camera) until it hangs
	# 14 degrees out from straight down; the forearm follows the upper arm.
	for pair: Array in [["mixamorig_LeftArm", "mixamorig_LeftForeArm", 1.0], ["mixamorig_RightArm", "mixamorig_RightForeArm", -1.0]]:
		var arm := _skeleton.find_bone(pair[0])
		var fore := _skeleton.find_bone(pair[1])
		if arm < 0 or fore < 0: continue
		var arm_pose := _skeleton.get_bone_global_pose(arm)
		var direction := _skeleton.get_bone_global_pose(fore).origin - arm_pose.origin
		var current := atan2(direction.y, direction.x)
		var target := atan2(-cos(deg_to_rad(14.0)), float(pair[2]) * sin(deg_to_rad(14.0)))
		arm_pose.basis = Basis(Vector3(0, 0, 1), wrapf(target - current, -PI, PI)) * arm_pose.basis
		_skeleton.set_bone_global_pose(arm, arm_pose)
# ------------------------------------------------------------------ skeleton

func _p(bone_name: String) -> Vector3:
	var bone := _skeleton.find_bone("mixamorig_" + bone_name)
	return _skeleton.get_bone_global_pose(bone).origin if bone >= 0 else Vector3.ZERO

func _bone_material(part: String) -> ShaderMaterial:
	if not _bone_materials.has(part):
		# One pooled bone shader for every part and glow (it was one per material).
		var material := ShaderPool.material(BONE_SHADER)
		material.render_priority = 1
		_bone_materials[part] = material
	return _bone_materials[part]

func _glow_material() -> ShaderMaterial:
	var material := ShaderPool.material(BONE_SHADER)
	material.render_priority = 2
	material.set_shader_parameter("bone_color", Color(1.0, 0.35, 0.15, 0.0))
	return material

## One bone shaft between two points, as a capsule.
func _shaft(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = a.distance_to(b) + radius * 2.0
	capsule.radial_segments = 12
	capsule.rings = 4
	var node := MeshInstance3D.new()
	node.mesh = capsule
	node.material_override = material
	var up := (b - a).normalized()
	node.transform = Transform3D(Basis(Quaternion(Vector3.UP, up)), (a + b) * 0.5)
	parent.add_child(node)
	return node

func _ball(parent: Node3D, at: Vector3, radius: float, stretch: Vector3, material: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var node := MeshInstance3D.new()
	node.mesh = sphere
	node.material_override = material
	node.transform = Transform3D(Basis.from_scale(stretch), at)
	parent.add_child(node)
	return node

## The X-ray skeleton, laid along the posed rig's own joints.
func _build_bones() -> void:
	if _skeleton == null: return
	var root := Node3D.new()
	root.name = "XraySkeleton"
	_skeleton.add_child(root)
	var head := _bone_material("head")
	var thorax := _bone_material("thorax")
	var stomach := _bone_material("stomach")
	# Skull and jaw, the neck, the spine.
	var skull_at := _p("Head") + Vector3(0, 0.085, 0.005)
	_ball(root, skull_at, 0.082, Vector3(0.86, 1.0, 0.95), head)
	_ball(root, _p("Head") + Vector3(0, 0.015, 0.035), 0.042, Vector3(1.1, 0.75, 1.0), head)
	_shaft(root, _p("Neck"), _p("Head"), 0.02, head)
	_shaft(root, _p("Spine2"), _p("Neck"), 0.022, thorax)
	_shaft(root, _p("Spine1"), _p("Spine2"), 0.026, thorax)
	_shaft(root, _p("Spine"), _p("Spine1"), 0.026, stomach)
	_shaft(root, _p("Hips"), _p("Spine"), 0.026, stomach)
	# Ribcage: a few rib hoops narrowing toward the waist, and the collarbones.
	var top := _p("Spine2")
	var low := _p("Spine1")
	for i: int in range(4):
		var t := float(i) / 3.0
		var ring := TorusMesh.new()
		var width := lerpf(0.13, 0.115, t) if i > 0 else 0.11
		ring.inner_radius = width - 0.012
		ring.outer_radius = width
		ring.rings = 24
		ring.ring_segments = 6
		var node := MeshInstance3D.new()
		node.mesh = ring
		node.material_override = thorax
		node.transform = Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.72)).rotated(Vector3.RIGHT, 0.25), top.lerp(low, 0.15 + t * 0.95) + Vector3(0, 0.02, 0.01))
		root.add_child(node)
	for side: String in ["Left", "Right"]:
		_shaft(root, _p("Spine2") + Vector3(0, 0.05, 0.03), _p(side + "Arm"), 0.012, thorax)
	# Pelvis: a broad, shallow bowl around the hips.
	_ball(root, _p("Hips") + Vector3(0, -0.02, 0), 0.08, Vector3(1.65, 0.75, 0.9), stomach)
	for side: String in ["Left", "Right"]:
		var arm_part := ("left" if side == "Left" else "right") + "_arm"
		var leg_part := ("left" if side == "Left" else "right") + "_leg"
		var arm := _bone_material(arm_part)
		var leg := _bone_material(leg_part)
		_ball(root, _p(side + "Arm"), 0.03, Vector3.ONE, arm)
		_long_bone(root, arm_part, _p(side + "Arm"), _p(side + "ForeArm"), 0.022, arm)
		_ball(root, _p(side + "ForeArm"), 0.024, Vector3.ONE, arm)
		_shaft(root, _p(side + "ForeArm"), _p(side + "Hand"), 0.017, arm)
		_shaft(root, _p(side + "Hand"), _p(side + "HandMiddle2"), 0.02, arm)
		_ball(root, _p(side + "UpLeg"), 0.034, Vector3.ONE, leg)
		_long_bone(root, leg_part, _p(side + "UpLeg"), _p(side + "Leg"), 0.03, leg)
		_ball(root, _p(side + "Leg"), 0.032, Vector3.ONE, leg)
		_shaft(root, _p(side + "Leg"), _p(side + "Foot"), 0.024, leg)
		_shaft(root, _p(side + "Foot"), _p(side + "ToeBase"), 0.022, leg)

## A limb's long bone, rigged to snap: whole, or two halves apart at a glowing break.
func _long_bone(root: Node3D, part: String, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var whole := _shaft(root, a, b, radius, material)
	var mid := a.lerp(b, 0.52)
	var dir := (b - a).normalized()
	var upper := _shaft(root, a, mid - dir * 0.022, radius, material)
	var lower := _shaft(root, mid + dir * 0.022, b, radius, material)
	var glow := _glow_material()
	var crack := _ball(root, mid, radius * 1.6, Vector3.ONE, glow)
	upper.visible = false
	lower.visible = false
	crack.visible = false
	_breaks[part] = {"whole":whole, "upper":upper, "lower":lower, "crack":crack, "glow":glow, "rest":lower.transform, "mid":mid}

func _update_bones() -> void:
	for part: String in _bone_materials:
		var c := _part_color(part)
		var bleed := int(bleeding.get(part, 0))
		var bone_c := Color(0.9, 0.96, 0.97).lerp(c, clampf(1.15 - _ratio(part), 0.25, 1.0))
		if bleed > 0:
			var beat := 0.5 + 0.5 * sin(_clock * (7.0 if bleed > 1 else 4.0))
			bone_c = bone_c.lerp(Color(1.0, 0.12, 0.08), 0.6 * beat)
		bone_c.a = clampf(presence * 1.05, 0.0, 1.0)
		var material: ShaderMaterial = _bone_materials[part]
		material.set_shader_parameter("bone_color", bone_c)
		material.set_shader_parameter("glow", float(_flash.get(part, 0.0)) * 0.6)
	for part: String in _breaks:
		var rig: Dictionary = _breaks[part]
		var broken := bool(fractures.get(part, false))
		rig.whole.visible = not broken
		rig.upper.visible = broken
		rig.lower.visible = broken
		rig.crack.visible = broken
		if broken:
			# The lower half sits knocked out of line and twitches; the break throbs.
			var twitch := sin(_clock * 23.0) * 0.004 + sin(_clock * 9.0) * 0.003
			var rest: Transform3D = rig.rest
			var pivot: Vector3 = rig.mid
			var bent := Transform3D(Basis(Vector3(0, 0, 1), 0.3 + twitch * 5.0), Vector3.ZERO)
			rig.lower.transform = Transform3D(Basis.IDENTITY, pivot + Vector3(0.024 + twitch, -0.008, 0)) * bent * Transform3D(Basis.IDENTITY, -pivot) * rest
			var throb := 0.5 + 0.5 * sin(_clock * 6.0)
			rig.crack.scale = Vector3.ONE * (0.8 + 0.5 * throb)
			var glow: ShaderMaterial = rig.glow
			glow.set_shader_parameter("bone_color", Color(1.0, 0.3, 0.12, presence * (0.35 + 0.5 * throb)))
			glow.set_shader_parameter("glow", 0.4 + 0.6 * throb)

static var _shader: Shader
static func _holo_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = HOLO_SHADER
	return _shader

## Skin bind index -> medical part index, from the bone each bind drives.
func _bind_parts(mesh: MeshInstance3D) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(96)
	out.fill(1)
	var skin := mesh.skin
	var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
	if skin == null: return out
	for i: int in range(mini(skin.get_bind_count(), 96)):
		var bone_name := String(skin.get_bind_name(i))
		if bone_name.is_empty() and skeleton != null and skin.get_bind_bone(i) >= 0:
			bone_name = skeleton.get_bone_name(skin.get_bind_bone(i))
		out[i] = PARTS.find(_part_of(bone_name))
	return out

static func _part_of(bone: String) -> String:
	var b := bone.replace("mixamorig_", "").replace("mixamorig:", "")
	if b.begins_with("Neck") or b.begins_with("Head") or b == "headfront": return "head"
	if b.begins_with("LeftUpLeg") or b.begins_with("LeftLeg") or b.begins_with("LeftFoot") or b.begins_with("LeftToe"): return "left_leg"
	if b.begins_with("RightUpLeg") or b.begins_with("RightLeg") or b.begins_with("RightFoot") or b.begins_with("RightToe"): return "right_leg"
	if b.begins_with("LeftArm") or b.begins_with("LeftForeArm") or b.begins_with("LeftHand"): return "left_arm"
	if b.begins_with("RightArm") or b.begins_with("RightForeArm") or b.begins_with("RightHand"): return "right_arm"
	if b == "Hips" or b == "Spine": return "stomach"
	return "thorax"

func _process(delta: float) -> void:
	_clock += delta
	var worst := 1.0
	var trouble := false
	for part: String in PARTS:
		worst = minf(worst, _ratio(part))
		if int(bleeding.get(part, 0)) > 0 or bool(fractures.get(part, false)): trouble = true
	for part: String in _flash.keys():
		_flash[part] = maxf(0.0, float(_flash[part]) - delta * 1.4)
		if float(_flash[part]) > 0.0: trouble = true
	var want := 0.6
	if worst < 0.999: want = 0.72
	if trouble or worst < 0.5: want = 0.85
	if inspecting: want = 1.0
	presence = move_toward(presence, want, delta * (3.0 if want > presence else 0.6))
	var colors := PackedColorArray()
	for part: String in PARTS: colors.append(_part_color(part))
	for material: ShaderMaterial in _materials: material.set_shader_parameter("part_color", colors)
	_update_bones()
	# Breathing: the figure rises and settles a few millimetres.
	if _skeleton != null: _skeleton.position.y = sin(_clock * 1.6) * 0.006
	_update_anchors()
	queue_redraw()

func _part_color(part: String) -> Color:
	var ratio := _ratio(part)
	var c := _tint(ratio)
	var flash := float(_flash.get(part, 0.0))
	var bleed := int(bleeding.get(part, 0))
	if bleed > 0:
		var beat := 0.5 + 0.5 * sin(_clock * (7.0 if bleed > 1 else 4.0))
		c = c.lerp(Color(1.0, 0.1, 0.07), 0.35 * beat)
	c = c.lerp(Color(1.0, 0.25, 0.15), flash)
	c.a = presence * (0.75 + 0.25 * (1.0 - ratio) + (0.2 if ratio <= 0.0 else 0.0))
	return c

func _ratio(part: String) -> float:
	if not hp.has(part): return 1.0
	return clampf(float(hp[part]) / maxf(1.0, float(max_hp.get(part, 1.0))), 0.0, 1.0)

func _tint(ratio: float) -> Color:
	if ratio <= 0.0: return DEAD
	if ratio > 0.75: return HEALTHY.lerp(WORN, (1.0 - ratio) / 0.25 * 0.35)
	if ratio > 0.4: return WORN.lerp(HURT, (0.75 - ratio) / 0.35)
	return HURT.lerp(Color(0.85, 0.1, 0.06), (0.4 - ratio) / 0.4)

func _view_rect() -> Rect2:
	var scale_factor := minf(size.x / VIEW_SIZE.x, size.y / VIEW_SIZE.y)
	var draw_size := Vector2(VIEW_SIZE) * scale_factor
	return Rect2(Vector2((size.x - draw_size.x) * 0.5, 0), draw_size)

## The inventory shows the same scan at a larger size.
func scan_texture() -> Texture2D:
	return _viewport.get_texture()

func scan_anchor(part: String) -> Vector2:
	if not _anchors.has(part):
		_update_anchors()
	var rect := _view_rect()
	if not _anchors.has(part) or not rect.has_area():
		return Vector2(-1, -1)
	return (Vector2(_anchors[part]) - rect.position) / rect.size

func _update_anchors() -> void:
	if _skeleton == null or _camera == null: return
	var rect := _view_rect()
	for part: String in PARTS:
		var bone := _skeleton.find_bone(ANCHOR_BONES[part])
		if bone < 0: continue
		var world := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone).origin
		var pixel := _camera.unproject_position(world)
		_anchors[part] = rect.position + pixel / Vector2(VIEW_SIZE) * rect.size

func _draw() -> void:
	if _viewport == null: return
	var a := presence
	draw_texture_rect(_viewport.get_texture(), _view_rect(), false)
	for part: String in PARTS:
		if not _anchors.has(part): continue
		var anchor: Vector2 = _anchors[part]
		if _ratio(part) <= 0.0: _blacked_out(anchor, a)
		var bleed := int(bleeding.get(part, 0))
		if bleed > 0:
			var pulse := 0.55 + 0.45 * sin(_clock * (7.0 if bleed > 1 else 4.0))
			_drop(anchor + Vector2(0, -2), Color(0.95, 0.1, 0.08, a * pulse), bleed > 1)
	if inspecting: _labels(a)

func _blacked_out(c: Vector2, a: float) -> void:
	var s := 8.0
	draw_line(c + Vector2(-s, -s), c + Vector2(s, s), Color(0.95, 0.15, 0.1, a), 2.2, true)
	draw_line(c + Vector2(s, -s), c + Vector2(-s, s), Color(0.95, 0.15, 0.1, a), 2.2, true)

func _labels(a: float) -> void:
	# A legend column beside the figure: part, HP of max, and its wound.
	var font := UIStyle.body_font()
	var heading := UIStyle.heading_font()
	var x := _view_rect().end.x + 6.0
	var y := 40.0
	draw_string_outline(heading, Vector2(x, y), "CONDITION", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(SHADOW, 0.8 * a))
	draw_string(heading, Vector2(x, y), "CONDITION", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(HEALTHY, 0.8 * a))
	y += 22.0
	for part: String in PARTS:
		var ratio := _ratio(part)
		var tint := _tint(ratio) if ratio > 0.0 else Color(0.95, 0.2, 0.15)
		tint.a = a
		var value := "%d/%d" % [ceili(float(hp.get(part, max_hp.get(part, 0.0)))), roundi(float(max_hp.get(part, 0.0)))]
		draw_string_outline(font, Vector2(x, y), SHORT[part], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(SHADOW, 0.8 * a))
		draw_string(font, Vector2(x, y), SHORT[part], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.86, 0.94, 0.95, 0.85 * a))
		draw_string_outline(font, Vector2(x + 68, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(SHADOW, 0.8 * a))
		draw_string(font, Vector2(x + 68, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tint)
		var wound := ""
		var bleed := int(bleeding.get(part, 0))
		if bleed > 1: wound = "HEAVY BLEED"
		elif bleed > 0: wound = "BLEEDING"
		if bool(fractures.get(part, false)): wound = (wound + " · " if not wound.is_empty() else "") + "FRACTURE"
		if ratio <= 0.0: wound = "DESTROYED"
		if not wound.is_empty():
			draw_string_outline(font, Vector2(x + 2, y + 13), wound, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(SHADOW, 0.8 * a))
			draw_string(font, Vector2(x + 2, y + 13), wound, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.32, 0.24, a))
			y += 13.0
		y += 20.0

func _drop(at: Vector2, color: Color, heavy: bool) -> void:
	for k: int in range(2 if heavy else 1):
		var c := at + Vector2(k * 10.0 - (5.0 if heavy else 0.0), 0)
		var poly := PackedVector2Array([c + Vector2(0, -8.5)])
		for i: int in range(9):
			var t := PI * float(i) / 8.0
			poly.append(c + Vector2(cos(t) * 4.6, sin(t) * 4.6 + 1.4))
		draw_colored_polygon(poly, Color(SHADOW, color.a * 0.6))
		draw_colored_polygon(poly, color)

func _bone(at: Vector2, color: Color) -> void:
	# Broken bone: two short rounded halves, offset at the break.
	draw_line(at + Vector2(-7, -3), at + Vector2(-1.5, -0.5), Color(SHADOW, color.a * 0.7), 5.0, true)
	draw_line(at + Vector2(1.5, 0.5), at + Vector2(7, 3), Color(SHADOW, color.a * 0.7), 5.0, true)
	draw_line(at + Vector2(-7, -3), at + Vector2(-1.5, -0.5), color, 2.6, true)
	draw_line(at + Vector2(1.5, 0.5), at + Vector2(7, 3), color, 2.6, true)
	draw_circle(at + Vector2(-7, -3), 2.1, color)
	draw_circle(at + Vector2(7, 3), 2.1, color)
