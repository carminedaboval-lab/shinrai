extends Node3D

const WIDTH := 2.7
const HEIGHT := 4.4
const LEAF := 1.30
const DURATION := 0.85
const REACH := 2.3
var opened := false
var moving := false
var elapsed := 0.0
var start_angle := 0.0
var target_angle := 0.0
var left: AnimatableBody3D
var right: AnimatableBody3D
var actor: Node3D
var blocked := false
var key_held := false
var active := false
var fresh_release_required := true
var controller: Node

static func install(park: Node3D, raid: Node) -> Node3D:
	var fence := park.find_child("ACT03_FiveASideSteelFence", true, false) as Node3D
	if fence == null: return null
	var existing := fence.get_node_or_null("InteractivePitchGate")
	if existing != null: return existing
	var gate := load("res://scripts/midori_pitch_gate.gd").new() as Node3D
	gate.name = "InteractivePitchGate"
	fence.add_child(gate)
	gate.position = Vector3(0, 0, 10.55)
	gate.build(fence)
	gate.controller = raid
	return gate

func set_active(enabled: bool) -> void:
	active = enabled
	key_held = true
	fresh_release_required = true

func raid_active() -> bool:
	return active and (not is_instance_valid(controller) or int(controller.phase) == 2)

func build(fence: Node3D) -> void:
	var frame: Material = fence.get("_frame_material")
	var net: Material = fence.get("_net_material")
	assert(frame != null and net != null, "Pitch fence must be built before gate")
	left = _leaf("LeftLeaf", -1.325, 1.0, frame, net)
	right = _leaf("RightLeaf", 1.325, -1.0, frame, net)

func _leaf(label: String, hinge_x: float, direction: float, frame: Material, net: Material) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = false # Updated only in _physics_process.
	add_child(body)
	body.position.x = hinge_x
	var center := direction * LEAF * 0.5
	_box(body, "LowerPanel", Vector3(LEAF, 1.18, .075), Vector3(center,.62,0), frame)
	_box(body, "TopRail", Vector3(LEAF,.075,.075), Vector3(center,HEIGHT,0), frame)
	_box(body, "MiddleRail", Vector3(LEAF,.075,.075), Vector3(center,1.24,0), frame)
	_box(body, "HingeStile", Vector3(.075,HEIGHT,.075), Vector3(0,HEIGHT*.5,0), frame)
	_box(body, "LatchStile", Vector3(.075,HEIGHT,.075), Vector3(direction*LEAF,HEIGHT*.5,0), frame)
	_box(body, "Handle", Vector3(.045,.22,.10), Vector3(direction*(LEAF-.13),1.05,.085), frame)
	var panel := MeshInstance3D.new()
	panel.name = "FenceMesh"
	var size := Vector2(LEAF-.075,HEIGHT-1.32)
	# Match midori_pitch_fence._add_net_panel: vertices/UV/indices only.
	# QuadMesh supplies normals/tangents that make the same net material brighter.
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-size.x*.5,-size.y*.5,0),Vector3(size.x*.5,-size.y*.5,0),
		Vector3(size.x*.5,size.y*.5,0),Vector3(-size.x*.5,size.y*.5,0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2.ZERO,Vector2(size.x/.105,0),
		Vector2(size.x/.105,size.y/.105),Vector2(0,size.y/.105)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,3])
	var actual := ArrayMesh.new()
	actual.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	actual.surface_set_material(0,net)
	panel.mesh = actual
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.position = Vector3(center,(1.28+HEIGHT-.04)*.5,0)
	body.add_child(panel)
	var collider := CollisionShape3D.new()
	collider.name = "GateCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(LEAF,HEIGHT,.11)
	collider.shape = shape
	collider.position = Vector3(center,HEIGHT*.5,0)
	body.add_child(collider)
	return body

func _box(parent: Node3D, label: String, size: Vector3, at: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = at
	parent.add_child(instance)

func reachable(point: Vector3) -> bool:
	var p := to_local(point)
	# Gate can be operated from either side, only inside its actual aperture.
	return absf(p.x) <= 1.30 and absf(p.z) <= REACH and absf(p.y) < 2.5

func sweep_occupied(point: Vector3, radius: float = .36) -> bool:
	var p := to_local(point)
	# 100-degree tip overtravel + rotating stile/collider extent + body radius.
	var margin := radius + .06 + .05
	var extent_x := 1.325 + LEAF*sin(deg_to_rad(10.0)) + margin
	return absf(p.x) <= extent_x and p.z >= -LEAF-margin and p.z <= margin and p.y > -.6 and p.y < HEIGHT+.5

func body_radius(body: Node3D) -> float:
	var radius := .36
	for node: Node in body.find_children("*","CollisionShape3D",true,false):
		var collision := node as CollisionShape3D
		if collision.disabled or collision.shape == null: continue
		if collision.shape is CapsuleShape3D:
			var offset := collision.global_position-body.global_position
			var scale_value := collision.global_basis.get_scale()
			radius = maxf(radius,Vector2(offset.x,offset.z).length()+collision.shape.radius*maxf(scale_value.x,scale_value.z))
			continue
		var bounds := collision.shape.get_debug_mesh().get_aabb()
		for x: float in [bounds.position.x,bounds.end.x]:
			for y: float in [bounds.position.y,bounds.end.y]:
				for z: float in [bounds.position.z,bounds.end.z]:
					var offset := collision.global_transform*Vector3(x,y,z)-body.global_position
					radius = maxf(radius,Vector2(offset.x,offset.z).length())
	return radius

func occupied(player: Node3D) -> bool:
	if is_instance_valid(player) and sweep_occupied(player.global_position,body_radius(player)): return true
	for enemy: Node in get_tree().get_nodes_in_group("extraction_hostiles"):
		if enemy is Node3D and enemy != player:
			# Broad phase avoids measuring every distant hostile collision rig.
			if global_position.distance_to(enemy.global_position) < 8.0 and sweep_occupied(enemy.global_position,body_radius(enemy)): return true
	return false

func blocks_route(from: Vector3, points: PackedVector3Array) -> bool:
	if opened and not moving: return false
	var a := to_local(from)
	for point: Vector3 in points:
		var b := to_local(point)
		if (a.z <= 0.0 and b.z >= 0.0) or (a.z >= 0.0 and b.z <= 0.0):
			if absf(b.z-a.z) > .0001:
				var crossing := a.lerp(b,-a.z/(b.z-a.z))
				if absf(crossing.x) <= WIDTH*.5+.42 and absf(crossing.y) < HEIGHT: return true
		a = b
	return false

func request_toggle(player: Node3D) -> bool:
	if not raid_active() or moving or player == null or not reachable(player.global_position): return false
	blocked = occupied(player)
	if blocked: return false
	actor = player
	start_angle = left.rotation.y
	target_angle = 0.0 if opened else deg_to_rad(100.0)
	elapsed = 0.0
	moving = true
	return true

func _physics_process(delta: float) -> void:
	if not raid_active():
		fresh_release_required = true
		key_held = true
		return
	if not moving: return
	# Hold motion if the player enters the sweep; resume after they step clear.
	blocked = occupied(actor)
	if blocked: return
	elapsed = minf(DURATION,elapsed+delta)
	var t := elapsed / DURATION
	var eased := t*t*(3.0-2.0*t)
	left.rotation.y = lerpf(start_angle,target_angle,eased)
	right.rotation.y = -left.rotation.y
	if elapsed >= DURATION:
		moving = false
		opened = target_angle > .1

func consume_interaction(player: Node3D, site_distance: float, eligible: bool, pressed: bool) -> String:
	var just_pressed := pressed and not key_held
	key_held = pressed
	if not raid_active():
		fresh_release_required = true
		return ""
	if fresh_release_required:
		just_pressed = false
		if not pressed: fresh_release_required = false
	if player == null or not eligible or not reachable(player.global_position): return ""
	var p := to_local(player.global_position)
	if site_distance < absf(p.z): return ""
	blocked = occupied(player)
	if just_pressed: request_toggle(player)
	if moving: return "Gate paused · step clear" if blocked else "Gate opening" if target_angle > .1 else "Gate closing"
	if blocked: return "Step clear of the gate"
	return "E  ·  Close pitch gate" if opened else "E  ·  Open pitch gate"
