extends "res://scripts/building_access/window.gd"
## A house window from the interior kit: the existing window (scripts/building_access/
## window.gd: a pane that takes bullets and blocks the way) with the owner's glass rules.
##
## The pane is in one of four states:
##   INTACT   it stops a walking body.
##   SHOT     a bullet shattered it. A ring of shards stays in the frame, SHARD_RING deep all
##            round. A body that goes through the clear middle is not hurt; one that touches
##            the ring gets a light bleed on an arm or a leg.
##   SMASHED  broken by a body going through it, by hand or with a tool. Ragged glass is left
##            right across the frame, so every passage has SMASH_BLEED_CHANCE of a light
##            bleed on an arm or a leg (and going through intact glass is the first passage).
##   CLEAN    the rest was knocked out (KNOCK_OUT_SECONDS of holding). Safe for good.
##
## The window does not move anybody. It is told where bodies were and are (body_moved(),
## called by the house every tick for bodies close by) and applies the rule when one crosses
## the pane. So the rule holds whatever carried the body through: walking, a mantle, a vault.
##
## Local axes: x across the opening, y up, +z into the house. The origin is the pane's centre.

const KitNoise := preload("res://scripts/interior_kit/noise.gd")

enum Glass { INTACT, SHOT, SMASHED, CLEAN }

# ---- the owner's rules -------------------------------------------------------------------
## Going through glass you smashed: this chance of a light bleed, on an arm or a leg.
const SMASH_BLEED_CHANCE := 0.6
## After a shot the shards left in the frame reach this far in from its edge, all round.
const SHARD_RING := 0.12
## Knocking the rest out takes this long and makes the window safe.
const KNOCK_OUT_SECONDS := 2.0
## Breaking glass is heard this far away (and sends birds up).
const GLASS_NOISE_RADIUS := 30.0

# ---- defaults (mine, easy to change) -----------------------------------------------------
## Bullets it takes to shatter the pane.
const SHOTS_TO_SHATTER := 1
## Knocking out what is left is a small noise.
const KNOCK_OUT_NOISE_RADIUS := 12.0
## Where a cut can land, and how bad it is (1 = light bleed in extraction_medical.gd).
const CUT_PARTS: Array[String] = ["left_arm", "right_arm", "left_leg", "right_leg"]
const LIGHT_BLEED := 1
## After a smash the ragged glass reaches this far in: there is no clean way through.
const SMASHED_REACH := 0.30
## A body's size when it has no capsule to read: half its width, and its height.
const BODY_RADIUS := 0.36
const BODY_HEIGHT := 1.75
## A person lifts their feet this high over shards on a low sill.
const STEP_OVER := 0.25
const HOLD_GAP_TICKS := 2

signal glass_broken(window: Node3D, how: int)
signal glass_cut(body: Node, part: String)

var glass: int = Glass.INTACT
var rng := RandomNumberGenerator.new()
## False in headless tests: the rules are the same but nothing is drawn.
var visuals := true
var shots_taken := 0
var passes := 0
var cuts := 0
var last_cut_part := ""
var knock_seconds := 0.0
## What is left in the frame, measured: how many shards, and how far in the shortest and the
## longest reach from the frame's edge.
var shard_count := 0
var shard_reach := Vector2.ZERO
var floor_pieces := 0
## Fallbacks for where broken glass comes to rest when no floor is found under it: how far
## below the pane's bottom edge the floor is, inside and outside.
var inside_drop := 0.9
var outside_drop := 1.0

## The dice for how broken glass LOOKS, kept apart from `rng` (the dice for who gets cut), so
## the look can change without changing any outcome.
var _look := RandomNumberGenerator.new()
var _scratch: MeshInstance3D
var _ring: MeshInstance3D
var _litter: Array[MeshInstance3D] = []
var _hold_frame := -1000

static var _pane_material: StandardMaterial3D
static var _shard_material: StandardMaterial3D


## Clear glass for a pane: one material shared by every kit window.
static func pane_material() -> StandardMaterial3D:
	if _pane_material == null: _pane_material = _glass(Color(0.66, 0.78, 0.80, 0.24), 0.04)
	return _pane_material


## Broken edges scatter light, so shards read whiter and less clear than a whole pane.
static func shard_material() -> StandardMaterial3D:
	if _shard_material == null: _shard_material = _glass(Color(0.78, 0.88, 0.87, 0.5), 0.08)
	return _shard_material


static func _glass(colour: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = roughness
	material.metallic_specular = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func configure(pane_dimensions: Vector3, material: Material, openable := true, label := "window") -> void:
	super.configure(pane_dimensions, material, openable, label)
	if _scratch != null:
		_scratch.free()
		_scratch = null
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_look.seed = rng.seed + 7919


## The base window makes a node for the pane, four sash bars, a latch and three "remnant"
## chips. A kit window keeps only the pane: its frame is part of the house's own mesh, and
## broken glass is built below when the pane breaks.
func _part(parent: Node3D, label: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	if label == "GlassPane":
		if visuals: return super._part(parent, label, at, size, material)
		var bare := MeshInstance3D.new()
		bare.name = label
		parent.add_child(bare)
		return bare
	if _scratch == null: _scratch = MeshInstance3D.new()
	return _scratch


# ---- what breaks it ----------------------------------------------------------------------

func receive_bullet_hit(damage: float, source: Node, at: Vector3, direction: Vector3) -> bool:
	if opened or glass != Glass.INTACT or damage <= 0.0: return false
	shots_taken += 1
	if shots_taken >= SHOTS_TO_SHATTER:
		var local := to_local(at)
		_shatter(Glass.SHOT, Vector2(local.x, local.y), signf((global_basis.inverse() * direction).z), source)
	return true


## Damage that is not a bullet (the base window's own call): enough of it shatters the pane
## the way a shot does.
func take_damage(amount: float, source: Node = null) -> void:
	if opened or glass != Glass.INTACT or amount <= 0.0: return
	health -= amount
	if health <= 0.0: _shatter(Glass.SHOT, Vector2.ZERO, 0.0, source)


## Broken by hand or with a tool, from where `actor` stands. Nobody is cut by the blow; the
## risk comes with going through what is left.
func smash(actor: Node3D = null) -> bool:
	if opened or glass != Glass.INTACT: return false
	var push := 0.0
	var at := Vector2.ZERO
	if is_instance_valid(actor):
		var from := to_local(actor.global_position)
		push = -signf(from.z)
		at = Vector2(from.x, from.y + 1.2)
	_shatter(Glass.SMASHED, at, push, actor)
	return true


## One press of the interact key: smashes an intact pane. (What is left afterwards is
## knocked out by holding the key: hold_interact().)
func interact(actor: Node3D) -> bool:
	if glass != Glass.INTACT: return false
	if can_open: return super.interact(actor)
	if _reach(actor) == INF: return false
	return smash(actor)


## Call once every physics tick while `actor` holds the interact key on a broken window.
## Returns how far the knocking-out has got, 0 to 1.
func hold_interact(actor: Node3D, delta: float) -> float:
	if (glass != Glass.SHOT and glass != Glass.SMASHED) or _reach(actor) == INF:
		knock_seconds = 0.0
		return 0.0
	var frame := Engine.get_physics_frames()
	if frame - _hold_frame > HOLD_GAP_TICKS: knock_seconds = 0.0
	_hold_frame = frame
	knock_seconds += delta
	if knock_seconds < KNOCK_OUT_SECONDS - 0.0001: return knock_seconds / KNOCK_OUT_SECONDS
	knock_out(actor)
	return 1.0


## Removes every shard left in the frame. The window is safe from now on.
func knock_out(actor: Node3D = null) -> void:
	if glass != Glass.SHOT and glass != Glass.SMASHED: return
	glass = Glass.CLEAN
	knock_seconds = 0.0
	if is_instance_valid(_ring): _ring.queue_free()
	_ring = null
	var fell := shard_count
	shard_count = 0
	shard_reach = Vector2.ZERO
	var push := 0.0
	if is_instance_valid(actor): push = -signf(to_local(actor.global_position).z)
	_scatter(clampi(fell / 4, 4, 10), push, actor)
	KitNoise.emit(self, global_position, KNOCK_OUT_NOISE_RADIUS, &"glass_knock_out")


## A new pane (a repair robot's job, and what a test uses between tries).
func repair() -> void:
	glass = Glass.INTACT
	broken = false
	health = 12.0
	shots_taken = 0
	knock_seconds = 0.0
	shard_count = 0
	shard_reach = Vector2.ZERO
	floor_pieces = 0
	if is_instance_valid(_ring): _ring.queue_free()
	_ring = null
	for piece: MeshInstance3D in _litter:
		if is_instance_valid(piece): piece.queue_free()
	_litter.clear()
	pane.visible = true
	collision_layer = 1
	pane_collision.set_deferred("disabled", false)


func interaction_distance(actor: Node3D) -> float:
	if glass == Glass.CLEAN: return INF
	return _reach(actor)


func interaction_prompt(actor: Node3D) -> String:
	if glass == Glass.SHOT or glass == Glass.SMASHED: return "Hold E  ·  Knock the rest of the glass out"
	if glass == Glass.INTACT and not can_open: return "E  ·  Smash the window"
	return super.interaction_prompt(actor)


func _reach(actor: Node3D) -> float:
	if not is_instance_valid(actor): return INF
	var from := actor.global_position + Vector3.UP
	var distance := from.distance_to(global_position)
	if distance > REACH: return INF
	var query := PhysicsRayQueryParameters3D.create(from, global_position, 1)
	query.exclude = [get_rid()]
	if actor is CollisionObject3D: query.exclude.append((actor as CollisionObject3D).get_rid())
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return INF
	return distance


# ---- going through it --------------------------------------------------------------------

## `body` moved from `from` to `to` this tick (world positions of its feet). If that took it
## through the pane, the rule for the pane's state is applied.
func body_moved(body: Node3D, from: Vector3, to: Vector3) -> void:
	if glass == Glass.CLEAN or opened: return
	var a := to_local(from)
	var b := to_local(to)
	if (a.z > 0.0) == (b.z > 0.0): return
	var at := a.lerp(b, a.z / (a.z - b.z))
	var half := dimensions * 0.5
	if absf(at.x) > half.x: return
	var feet := at.y + half.y # how high the feet are above the bottom edge of the glass
	var height := body_height(body)
	if feet >= dimensions.y or feet + height <= 0.0: return
	passes += 1
	match glass:
		Glass.INTACT:
			_shatter(Glass.SMASHED, Vector2(at.x, at.y + minf(height * 0.6, 1.1)), signf(b.z - a.z), body)
			if rng.randf() < SMASH_BLEED_CHANCE: _cut(body)
		Glass.SMASHED:
			if rng.randf() < SMASH_BLEED_CHANCE: _cut(body)
		Glass.SHOT:
			if touches_ring(at.x, feet, body_radius(body), height): _cut(body)


## True when a body `radius` wide and `height` tall, crossing the pane `x` metres off its
## centre with its feet `feet` metres above the bottom edge of the glass, reaches the ring of
## shards: at either side, overhead, or on the sill if it is too high to step over.
func touches_ring(x: float, feet: float, radius: float, height: float) -> bool:
	if absf(x) + radius > dimensions.x * 0.5 - SHARD_RING: return true
	if feet + height > dimensions.y - SHARD_RING: return true
	return feet + STEP_OVER < SHARD_RING


## The widest a body's centre can be off the middle of the opening and still not touch.
func clear_half_width(radius: float = BODY_RADIUS) -> float:
	return dimensions.x * 0.5 - SHARD_RING - radius


static func body_radius(body: Node) -> float:
	var capsule := _capsule(body)
	return capsule.radius if capsule != null else BODY_RADIUS


static func body_height(body: Node) -> float:
	var capsule := _capsule(body)
	return capsule.height if capsule != null else BODY_HEIGHT


static func _capsule(body: Node) -> CapsuleShape3D:
	if not is_instance_valid(body): return null
	var own: Variant = body.get("body_capsule") # the player keeps its capsule here
	if own is CapsuleShape3D: return own
	for child: Node in body.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is CapsuleShape3D: return (child as CollisionShape3D).shape
	return null


func _cut(body: Node) -> void:
	var part: String = CUT_PARTS[rng.randi() % CUT_PARTS.size()]
	cuts += 1
	last_cut_part = part
	var medical: Variant = body.get("medical") if is_instance_valid(body) else null
	if medical != null and medical.get("bleeding") is Dictionary and medical.bleeding.has(part):
		# Never makes a heavy bleed lighter.
		medical.bleeding[part] = maxi(int(medical.bleeding[part]), LIGHT_BLEED)
	glass_cut.emit(body, part)


# ---- the break itself --------------------------------------------------------------------

func _shatter(how: int, hit: Vector2, push: float, source: Node) -> void:
	glass = how
	broken = true
	collision_layer = 0
	pane_collision.set_deferred("disabled", true)
	pane.visible = false
	var half := Vector2(dimensions.x, dimensions.y) * 0.5
	hit = Vector2(clampf(hit.x, -half.x * 0.8, half.x * 0.8), clampf(hit.y, -half.y * 0.8, half.y * 0.8))
	_build_ring(hit, SHARD_RING if how == Glass.SHOT else SMASHED_REACH, 0.82 if how == Glass.SHOT else 0.95)
	_scatter(clampi(int(dimensions.x * dimensions.y * 7.0), 6, 18), push, source)
	KitNoise.emit(self, global_position, GLASS_NOISE_RADIUS, &"glass_break")
	glass_broken.emit(self, how)


## The glass left in the frame. A pane breaks along cracks that run out from where it was
## struck, so every shard here is the piece between two such cracks, snapped off some way in
## from the frame: its two long edges point back at the strike. `reach` is how far in the
## longest ones come; `kept` is the share of pieces that stayed in the frame at all.
func _build_ring(hit: Vector2, reach: float, kept: float) -> void:
	var half := Vector2(dimensions.x, dimensions.y) * 0.5
	var count := clampi(int((half.x + half.y) * 4.0 / 0.11), 14, 72)
	var ends: Array[Vector2] = []
	var sides: Array[int] = []
	# Cracks are not evenly spaced: mostly narrow pieces, a broad one now and then.
	var steps := PackedFloat32Array()
	var turn := 0.0
	for index: int in range(count):
		var step := _look.randf_range(0.3, 1.0)
		if _look.randf() < 0.22: step *= _look.randf_range(1.8, 3.0)
		steps.append(step)
		turn += step
	var angle := _look.randf() * TAU
	for index: int in range(count):
		angle += steps[index] / turn * TAU
		var direction := Vector2(cos(angle), sin(angle))
		var tx := INF if absf(direction.x) < 1e-6 else ((half.x if direction.x > 0.0 else -half.x) - hit.x) / direction.x
		var ty := INF if absf(direction.y) < 1e-6 else ((half.y if direction.y > 0.0 else -half.y) - hit.y) / direction.y
		ends.append(hit + direction * minf(tx, ty))
		# Sides in the order the cracks go round: right, top, left, bottom.
		if tx <= ty: sides.append(0 if direction.x > 0.0 else 2)
		else: sides.append(1 if direction.y > 0.0 else 3)
	var corners: Array[Vector2] = [Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y), Vector2(half.x, -half.y)]
	# Pointing into the pane from each side (y is up here, unlike Vector2.UP).
	var inward: Array[Vector2] = [Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0), Vector2(0, 1)]
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	shard_count = 0
	var nearest := INF
	var furthest := 0.0
	for index: int in range(count):
		if _look.randf() > kept: continue
		var next := (index + 1) % count
		# One side of the shard snaps off deep, the other shallow: a point, not a strip.
		var deep := reach * _look.randf_range(0.45, 1.0)
		var shallow := deep * _look.randf_range(0.1, 0.55)
		var first_deep := _look.randf() < 0.5
		var outline: Array[Vector2] = [ends[index]]
		var side := sides[index]
		while side != sides[next]:
			outline.append(corners[side])
			side = (side + 1) % 4
		outline.append(ends[next])
		outline.append(_snap(ends[next], hit, inward[sides[next]], shallow if first_deep else deep))
		outline.append(_snap(ends[index], hit, inward[sides[index]], deep if first_deep else shallow))
		var first := points.size()
		for point: Vector2 in outline:
			points.append(Vector3(point.x, point.y, 0.0))
			normals.append(Vector3.BACK)
		for corner: int in range(1, outline.size() - 1):
			indices.append_array(PackedInt32Array([first, first + corner, first + corner + 1]))
		shard_count += 1
		nearest = minf(nearest, shallow)
		furthest = maxf(furthest, deep)
	shard_reach = Vector2(nearest if shard_count > 0 else 0.0, furthest)
	if is_instance_valid(_ring): _ring.queue_free()
	_ring = null
	if not visuals or indices.is_empty(): return
	_ring = _glass_mesh("ShardsInFrame", points, normals, indices)


## The inner end of a crack: `depth` metres in from the frame edge, along the line from the
## edge point back to the strike.
func _snap(edge: Vector2, hit: Vector2, inward: Vector2, depth: float) -> Vector2:
	var toward := hit - edge
	var length := toward.length()
	if length < 0.001: return edge
	toward /= length
	var along := depth / maxf(toward.dot(inward), 0.35)
	return edge + toward * minf(along, length * 0.9)


## Pieces of glass on the floor: `push` > 0 throws them into the house, < 0 out of it, 0 both.
func _scatter(count: int, push: float, source: Node) -> void:
	var half := Vector2(dimensions.x, dimensions.y) * 0.5
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	for index: int in range(count):
		var side := push if push != 0.0 else (1.0 if _look.randf() < 0.5 else -1.0)
		# Most of it drops close under the frame; a few pieces skid further.
		var out := 0.1 + 0.9 * pow(_look.randf(), 2.0)
		var at := Vector3(_look.randf_range(-half.x, half.x) * 1.05, 0.0, side * out)
		at.y = -half.y - (inside_drop if side > 0.0 else outside_drop)
		if space != null:
			var top := to_global(Vector3(at.x, -half.y + 0.25, at.z))
			var query := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 6.0, 1)
			var skip: Array[RID] = [get_rid()]
			if source is CollisionObject3D: skip.append((source as CollisionObject3D).get_rid())
			query.exclude = skip
			var found := space.intersect_ray(query)
			if not found.is_empty() and not found.collider is CharacterBody3D: at.y = to_local(found.position).y
		at.y += 0.004
		var size := _look.randf_range(0.02, 0.10)
		var turn := _look.randf() * TAU
		var first := points.size()
		var corners := 3 if _look.randf() < 0.6 else 4
		for corner: int in range(corners):
			var angle := turn + TAU * (float(corner) + _look.randf_range(-0.2, 0.2)) / float(corners)
			points.append(at + Vector3(cos(angle), 0.0, sin(angle)) * size * _look.randf_range(0.5, 1.0))
			normals.append(Vector3.UP)
		for corner: int in range(1, corners - 1):
			indices.append_array(PackedInt32Array([first, first + corner, first + corner + 1]))
	floor_pieces += count
	if not visuals or indices.is_empty(): return
	_litter.append(_glass_mesh("GlassOnFloor", points, normals, indices))


func _glass_mesh(label: String, points: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> MeshInstance3D:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, shard_material())
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node, true)
	return node
