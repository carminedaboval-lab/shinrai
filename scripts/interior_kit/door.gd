extends "res://scripts/building_access/door.gd"
## A house door from the interior kit.
##
## It IS the existing swinging door (scripts/building_access/door.gd: the hinged leaf, the
## "step clear of the swing" rule, the interact and prompt calls the raid already uses), with
## two changes: the leaf is drawn as one mesh instead of about thirty, and a locked door can
## be opened in the three ways the design gives:
##   - a crowbar, held on the door for CROWBAR_SECONDS, heard CROWBAR_NOISE_RADIUS away;
##   - LOCK_SHOTS bullets on the lock (the shots are heard like any gunfire);
##   - an access chip: open_with_chip(), at once and with no noise.
## From inside the locked room the door simply unlocks (a thumb turn), as the existing door did.

const KitNoise := preload("res://scripts/interior_kit/noise.gd")
const ShellMesh := preload("res://scripts/interior_kit/shell_mesh.gd")
const DoorLeaf := preload("res://scripts/interior_kit/door_leaf.gd")
const RobotParts := preload("res://scripts/robots/robot_parts.gd")

# ---- defaults (mine, easy to change) -----------------------------------------------------
## Seconds the crowbar must be held on a locked door before the lock gives.
const CROWBAR_SECONDS := 5.0
## Forcing a door is heard this far away ...
const CROWBAR_NOISE_RADIUS := 35.0
## ... once when the bar goes in, then again this often while it is worked, and when it gives.
const CROWBAR_NOISE_INTERVAL := 1.0
## Bullets on the lock that open it.
const LOCK_SHOTS := 3
## The part of the leaf that counts as "the lock": width and height in metres, centred on
## the handle and the lock above it.
const LOCK_ZONE := Vector2(0.16, 0.34)
const LOCK_HEIGHT := 1.10
## The item a player must carry. It is not in the item list yet: until it is, a body with
## has_crowbar = true (a property or a meta) counts as carrying one.
const CROWBAR_ITEM_ID := "crowbar"
## The interact key counts as let go when hold_interact() misses this many physics ticks.
const HOLD_GAP_TICKS := 2
const HANDLE_INSET := 0.13 # the base door puts the handle this far in from the leaf's edge
## A body whose middle is this far on the side the leaf swings away from is clear of it.
const CLEAR_BEHIND := 0.30

## True once the lock has been broken (crowbar or bullets). A chip leaves it whole.
var forced := false
var lock_hits := 0
var pry_seconds := 0.0
## How it came to be unlocked: "", "crowbar", "shots", "chip" or "inside".
var opened_with := ""
## Which side of the door is the room it opens into: +1 or -1 along the door's own z.
var room_side := 1.0
## False in headless tests: the door works the same but draws nothing.
var visuals := true
var triangles := 0
## Set before configure() to keep the leaf's boxes ([centre, size, colour], in the leaf's own
## space) in leaf_boxes: house_kit.gd's build_look() draws a closed door from them.
var keep_boxes := false
var leaf_boxes: Array = []

## How the leaf is made. "panel": framed and panelled, lever handle (the base door).
## "flush": a plain flat leaf with a lever handle, as indoor doors in a Japanese house are.
## "slide": a framed sliding door (hikido) with a finger pull. "fusuma": a plain sliding
## panel with a finger pull.
var style := "panel"
## A sliding door: the leaf runs sideways into the wall (a pocket in its thickness) instead
## of swinging. slide_dir is +1 or -1 along the door's own x.
var slides := false
var slide_dir := 1.0

var _boxes: Array = []
var _hold_frame := -1000
var _noise_at := 0.0


func configure(dimensions: Vector3, material: Material, is_locked := false, label := "door") -> void:
	_boxes.clear()
	super.configure(dimensions, material, is_locked, label)
	if is_locked:
		# A lock case above the handle, on both faces: what the crowbar and the bullets go for.
		var steel := StandardMaterial3D.new()
		steel.albedo_color = Color("5b6463")
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color("1d1f20")
		for face: float in [-1.0, 1.0]:
			_detail("LockCase", Vector3(size.x - HANDLE_INSET, 1.22, face * (size.z * 0.5 + 0.008)), Vector3(0.055, 0.11, 0.016), steel)
			_detail("LockCylinder", Vector3(size.x - HANDLE_INSET, 1.225, face * (size.z * 0.5 + 0.019)), Vector3(0.026, 0.026, 0.008), dark)
	var builder := ShellMesh.new()
	for entry: Array in _boxes: builder.box(Transform3D.IDENTITY, entry[0], entry[1], entry[2])
	triangles = builder.triangle_count()
	if keep_boxes: leaf_boxes = _boxes.duplicate()
	_boxes.clear()
	if visuals:
		var mesh := MeshInstance3D.new()
		mesh.name = "Leaf"
		mesh.mesh = builder.commit()
		leaf.add_child(mesh)
	# The leaf is what a bullet hits; give it the call the gun looks for.
	leaf.set_script(DoorLeaf)
	set_physics_process(false)


## The base door makes a mesh node for every stile, rail, panel, handle part and hinge.
## Here they are only collected, and drawn together as one mesh.
func _detail(_label: String, at: Vector3, dimensions: Vector3, material: Material) -> void:
	var colour := Color(0.5, 0.5, 0.5)
	if material is BaseMaterial3D: colour = (material as BaseMaterial3D).albedo_color
	if style != "panel":
		if _label in ["Stile", "Rail", "InsetPanel"] and style != "slide": return
		if _label in ["HandleStand", "LeverHandle", "Hinge"] and style != "flush": return
		if _label == "HandlePlate" and style != "flush":
			# A finger pull let into the leaf.
			dimensions = Vector3(0.045, 0.11, 0.012)
			at.z = signf(at.z) * (size.z * 0.5 + 0.004)
			colour = Color(0.16, 0.15, 0.14)
	_boxes.append([at, dimensions, colour])


## True when `actor` carries a crowbar: the item in the raid's bag once it exists, or the
## stand-in flag has_crowbar on the body.
static func has_crowbar(actor: Node) -> bool:
	if not is_instance_valid(actor): return false
	if actor.get("has_crowbar") == true or bool(actor.get_meta("has_crowbar", false)): return true
	if not actor.is_inside_tree(): return false
	var raid := actor.get_tree().get_first_node_in_group("shinrai_survival_run")
	if raid == null: return false
	var bag: Variant = raid.get("bag")
	if not bag is Array: return false
	for item: Variant in bag:
		if item is Dictionary and str(item.get("id", "")) == CROWBAR_ITEM_ID: return true
	return false


## Where the lock is, in the world.
func lock_point() -> Vector3:
	return leaf.to_global(Vector3(size.x - HANDLE_INSET, LOCK_HEIGHT, 0.0))


func interaction_prompt(actor: Node3D) -> String:
	if locked and not _can_unlock_inside(actor):
		if RobotParts.has_chip(actor): return "E  ·  Open with the access chip"
		if has_crowbar(actor): return "Hold E  ·  Force the lock with the crowbar"
		return "Locked  ·  needs a crowbar, or shoot the lock"
	return super.interaction_prompt(actor)


## One press of the interact key: opens or closes an unlocked door, unlocks a locked one
## from inside its room. A locked door from outside does nothing on a press.
func interact(actor: Node3D) -> bool:
	# A player who carries a robot's access chip opens a locked door by using it: no noise.
	if locked and not _can_unlock_inside(actor) and RobotParts.has_chip(actor): return open_with_chip(actor)
	var was_locked := locked
	var done: bool = super.interact(actor)
	if done:
		if was_locked: opened_with = "inside"
		set_physics_process(true)
	return done


## Call once every physics tick while `actor` holds the interact key on this door.
## Returns how far the forcing has got, 0 to 1. It stays 0 without a crowbar, and starts
## again from 0 if the key is let go.
func hold_interact(actor: Node3D, delta: float) -> float:
	if not locked or moving or not has_crowbar(actor) or interaction_distance(actor) == INF:
		pry_seconds = 0.0
		return 0.0
	var frame := Engine.get_physics_frames()
	if frame - _hold_frame > HOLD_GAP_TICKS:
		pry_seconds = 0.0
		_noise_at = 0.0
	_hold_frame = frame
	if pry_seconds >= _noise_at:
		_noise_at += CROWBAR_NOISE_INTERVAL
		KitNoise.emit(self, lock_point(), CROWBAR_NOISE_RADIUS, &"crowbar_pry")
	pry_seconds += delta
	if pry_seconds < CROWBAR_SECONDS - 0.0001: return pry_seconds / CROWBAR_SECONDS
	KitNoise.emit(self, lock_point(), CROWBAR_NOISE_RADIUS, &"door_forced")
	forced = true
	_release(actor, "crowbar")
	return 1.0


## A bullet struck the leaf at `at`. Only a hit on the lock counts; the shot's own noise is
## the gun's (the raid tells the scav crews and the birds about gunfire).
func bullet_hit(damage: float, source: Node, at: Vector3, _direction: Vector3) -> bool:
	if not locked or damage <= 0.0: return false
	var point := leaf.to_local(at)
	if absf(point.x - (size.x - HANDLE_INSET)) > LOCK_ZONE.x * 0.5 or absf(point.y - LOCK_HEIGHT) > LOCK_ZONE.y * 0.5: return false
	lock_hits += 1
	if lock_hits < LOCK_SHOTS:
		KitNoise.sound(&"lock_shot", at)
		return true
	KitNoise.sound(&"lock_shot_open", at)
	forced = true
	_release(source as Node3D, "shots")
	return true


## ACCESS CHIP HOOK. A robot's access chip opens a locked door at once and without a sound
## (docs/LOOT_AND_CRAFTING_PLAN.md section 7). There is no chip item yet: whatever comes to
## own one calls this for the door the player is at.
func open_with_chip(actor: Node3D) -> bool:
	if not locked or moving: return false
	if is_instance_valid(actor) and interaction_distance(actor) == INF: return false
	_release(actor, "chip")
	return true


func _release(actor: Node3D, how: String) -> void:
	locked = false
	opened_with = how
	pry_seconds = 0.0
	_actor = actor
	_start = leaf.rotation.y
	_goal = open_angle
	_elapsed = 0.0
	moving = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if slides:
		if moving:
			_elapsed = minf(0.75, _elapsed + delta)
			var t := smoothstep(0.0, 1.0, _elapsed / 0.75)
			leaf.position.x = -size.x * 0.5 + slide_dir * (size.x + 0.03) * ((1.0 - t) if opened else t)
			if _elapsed >= 0.75:
				moving = false
				opened = not opened
	else:
		super._physics_process(delta)
	if not moving: set_physics_process(false)


## The base door's rule, "nobody may stand where the leaf swings", with one correction: a
## body on the side the leaf swings AWAY from cannot be struck by it, so it does not hold
## the door up. (Without this, a player leaning on a door they have just forced has to step
## back before it will open.)
func _sweep_occupied(actor: Node3D) -> bool:
	if slides: return false      # a sliding leaf sweeps nothing
	var actors: Array[Node] = []
	if is_instance_valid(actor): actors.append(actor)
	for group: String in ["shinrai_input_players", "extraction_hostiles"]:
		for other: Node in get_tree().get_nodes_in_group(group):
			if not actors.has(other): actors.append(other)
	for other: Node in actors:
		if not other is Node3D: continue
		var point := to_local((other as Node3D).global_position)
		if point.y > size.y + 0.1 or point.y + 1.8 < 0.0: continue
		if point.z * room_side < -CLEAR_BEHIND: continue
		for step: int in range(25):
			var angle := open_angle * float(step) / 24.0
			var local := Basis(Vector3.UP, -angle) * (point - leaf.position)
			if local.x >= -0.43 and local.x <= size.x + 0.43 and absf(local.z) <= 0.43 + size.z * 0.5: return true
	return false


func _can_unlock_inside(actor: Node3D) -> bool:
	return allow_inside_unlock and is_instance_valid(actor) and interaction_distance(actor) < INF and to_local(actor.global_position).z * room_side > 0.15
