extends Node3D
## Roof mechanism, physical aiming cue and discharge trace. Combat owns hits.
## PoliceLights already follows the animated Body and its physical corpse body.
const LIFT_FINISHED_SECONDS := .42
const BLUE_AIM_SECONDS := 3.0
const RED_WARNING_SECONDS := LIFT_FINISHED_SECONDS + BLUE_AIM_SECONDS
const WINDUP_SECONDS := RED_WARNING_SECONDS + .20
const AIM_RETURN_START_SECONDS := WINDUP_SECONDS + .09
const RETRACT_START_SECONDS := WINDUP_SECONDS + .20
const GUN_RETRACTED_SECONDS := WINDUP_SECONDS + .43
const HATCH_CLOSE_SECONDS := WINDUP_SECONDS + .33
const CLOSED_SECONDS := WINDUP_SECONDS + .50
const FINISHED_SECONDS := WINDUP_SECONDS + .55
const MOUNT_OFFSET := Vector3(0, .041, .24)
const GUN_REST_Y := -.002
const GUN_RAISED_Y := .16
const GUN_OFFSET_Z := -.020
const FLASH_SECONDS := .30
const ARC_VISIBLE_METRES := 25.0
const ARC_SEGMENTS := 8
const HELIX_SEGMENTS := 64
const HELIX_STRANDS := 2
const DISCHARGE_ARTWORK_SECONDS := 1.6
const ARTWORK_SCALE_START_METRES := 8.0
const ARTWORK_FADE_START_METRES := 25.0
const ARTWORK_HIDE_METRES := 31.0
@export var discharge_artwork: Texture2D
const GUN_ASSET_PATH := "res://assets/enemies/police_spider/stun_gun/shinrai_stun_gun.glb"
const DISCHARGE_ARTWORK_PATH := "res://assets/enemies/police_spider/stun_gun/tazer_supplied.png"

var mount: Node3D
var hatch_left: Node3D
var hatch_right: Node3D
var gun: Node3D
var gun_visual: Node3D
var muzzle: Marker3D
var damage_area: Area3D
var deploy_amount := 0.0
var setup_complete := false
var shut_down := false
var _actor: CharacterBody3D
var _stem: MeshInstance3D
var _charge_material: StandardMaterial3D
var _aim_material: StandardMaterial3D
var _aim_root: Node3D
var _aim_beam: MeshInstance3D
var _aim_endpoint := Vector3.INF
var _aim_phase := ""
var _arc_root: Node3D
var _arc_pieces: Array[MeshInstance3D] = []
var _trace_endpoint := Vector3.INF
var _trace_origin := Vector3.INF
var _helix_mesh: ImmediateMesh
var _helix_visual: MeshInstance3D
var _artwork_sprite: Sprite3D
var _artwork_remaining := 0.0
var _spark: MeshInstance3D
var _aim_point := Vector3.INF
var _attack_seconds := -1.0
var _flash_remaining := 0.0
var _damage_enabled := false
static var _metal: StandardMaterial3D
static var _trim: StandardMaterial3D
static var _recess: StandardMaterial3D
static var _arc_material: StandardMaterial3D
static var _helix_material: StandardMaterial3D
static var _box_meshes: Dictionary = {}
static var _unit_stem: CylinderMesh
static var _unit_arc: CylinderMesh
static var _unit_trace: CylinderMesh
static var _spark_mesh: SphereMesh
static var _gun_scene: PackedScene
static var _supplied_artwork_texture: Texture2D

func setup(actor: CharacterBody3D) -> bool:
	if setup_complete: return _actor == actor and not shut_down
	if not is_instance_valid(actor): return false
	var lights := actor.get("police_lights") as Node3D
	if not is_instance_valid(lights): return false
	var weapon_scene := _load_gun_scene()
	if weapon_scene == null:
		push_error("Police drone stun gun asset is missing or invalid: " + GUN_ASSET_PATH)
		return false
	var supplied_weapon: Node = weapon_scene.instantiate()
	if not supplied_weapon is Node3D:
		if supplied_weapon != null: supplied_weapon.free()
		push_error("Police drone stun gun asset has no Node3D root")
		return false
	_actor = actor
	_ensure_resources()
	mount = Node3D.new(); mount.name = "StunRoofCassette"
	lights.add_child(mount); mount.position = MOUNT_OFFSET
	# Model Y-up: cassette footprint X +/-.09, Z +/-.10. Its dark floor
	# remains above the original roof; the side lids never sweep into the lightbar.
	_box(mount, Vector3(.16, .008, .18), Vector3(0, -.032, 0), _recess, "RecessFloor")
	for side: float in [-1.0, 1.0]:
		_box(mount, Vector3(.010, .060, .20), Vector3(side * .085, -.008, 0), _trim, "SideRail")
		_box(mount, Vector3(.014, .010, .19), Vector3(side * .083, .021, 0), _metal, "HingeRail")
	for end: float in [-1.0, 1.0]:
		_box(mount, Vector3(.16, .060, .010), Vector3(0, -.008, end * .095), _trim, "EndWall")
	hatch_left = _hatch(-1.0, "LeftHatch")
	hatch_right = _hatch(1.0, "RightHatch")
	_charge_material = StandardMaterial3D.new()
	_charge_material.albedo_color = Color(.015, .13, .17)
	_charge_material.emission_enabled = true
	_charge_material.emission = Color(.10, .85, 1.0)
	_charge_material.emission_energy_multiplier = 0.0
	_charge_material.roughness = .28
	_box(mount, Vector3(.078, .006, .003), Vector3(0, -.005, .101), _charge_material, "ChargeStrip")
	_stem = MeshInstance3D.new(); _stem.name = "LiftPiston"
	_stem.mesh = _unit_stem; _stem.material_override = _metal; mount.add_child(_stem)
	_box(mount, Vector3(.036, .010, .044), Vector3(0, -.023, GUN_OFFSET_Z - .014), _trim, "LiftSocket")
	gun = Node3D.new(); gun.name = "StunGun"; mount.add_child(gun)
	gun.position.z = GUN_OFFSET_Z
	_box(gun, Vector3(.070, .008, .078), Vector3(0, -.020, -.014), _trim, "GunGimbal")
	# The supplied Meshy mesh is already measured and uniformly fitted offline;
	# keep its actual geometry, UVs and shared PBR materials intact here.
	gun_visual = supplied_weapon as Node3D; gun_visual.name = "MeshyStunGun"
	gun.add_child(gun_visual)
	muzzle = Marker3D.new(); muzzle.name = "StunMuzzle"
	muzzle.position = Vector3(0, 0, .105); gun.add_child(muzzle)
	damage_area = Area3D.new(); damage_area.name = "HitStunEmitter"
	damage_area.set_script(preload("res://assets/enemies/police_spider/patrol_leg_hitbox.gd"))
	damage_area.set("actor", actor)
	damage_area.collision_layer = 0; damage_area.collision_mask = 0
	damage_area.monitoring = false; damage_area.monitorable = false
	var hit_shape := BoxShape3D.new(); hit_shape.size = Vector3(.078, .050, .174)
	var collision := CollisionShape3D.new(); collision.name = "EmitterCollision"
	collision.shape = hit_shape; collision.position.z = .0225
	damage_area.add_child(collision); gun.add_child(damage_area)
	_build_flash()
	_build_targeting()
	_build_discharge_artwork()
	setup_complete = true
	cancel_attack()
	return true

func aim_at(world_point: Vector3) -> void:
	if shut_down or not setup_complete or not world_point.is_finite(): return
	_aim_point = world_point
	_apply_aim()

func sample_attack(seconds: float) -> void:
	if shut_down or not setup_complete: return
	_attack_seconds = maxf(0.0, seconds)
	var opening := smoothstep(0.0, .30, _attack_seconds)
	var closing := smoothstep(HATCH_CLOSE_SECONDS, CLOSED_SECONDS, _attack_seconds)
	var hatch_amount := opening * (1.0 - closing)
	deploy_amount = smoothstep(.12, LIFT_FINISHED_SECONDS, _attack_seconds) * (1.0 - smoothstep(RETRACT_START_SECONDS, GUN_RETRACTED_SECONDS, _attack_seconds))
	hatch_left.rotation.z = hatch_amount * 1.72
	hatch_right.rotation.z = -hatch_amount * 1.72
	gun.position.y = lerpf(GUN_REST_Y, GUN_RAISED_Y, deploy_amount)
	gun.visible = deploy_amount > .03
	var stem_length := maxf(.002, gun.position.y - .004)
	_stem.position = Vector3(0, -.020 + stem_length * .5, GUN_OFFSET_Z - .014)
	_stem.scale = Vector3(1.0, stem_length, 1.0)
	_stem.visible = deploy_amount > .10
	_set_damage_enabled(deploy_amount > .25)
	_apply_aim()
	_update_targeting()
	_update_charge()

func muzzle_position() -> Vector3:
	if is_instance_valid(muzzle): return muzzle.global_position
	return global_position

func preview_muzzle_position(world_point: Vector3) -> Vector3:
	if shut_down or not setup_complete or not world_point.is_finite(): return Vector3.INF
	if not is_instance_valid(mount) or not is_instance_valid(gun) or not is_instance_valid(muzzle): return Vector3.INF
	var parent_transform: Transform3D=mount.global_transform
	var determinant: float=parent_transform.basis.determinant()
	if not parent_transform.is_finite() or not is_finite(determinant) or absf(determinant)<.000001: return Vector3.INF
	var raised_local := Vector3(0,GUN_RAISED_Y,GUN_OFFSET_Z)
	var raised_origin: Vector3=parent_transform*raised_local
	var offset: Vector3=world_point-raised_origin
	if not offset.is_finite() or offset.length_squared()<.000001: return Vector3.INF
	var forward: Vector3=offset.normalized()
	var up: Vector3=parent_transform.basis.y.normalized()
	if absf(forward.dot(up))>.98: up=parent_transform.basis.x.normalized()
	if not up.is_finite() or forward.cross(up).length_squared()<.000001: return Vector3.INF
	# Match the fully raised _apply_aim: Node3D.look_at keeps global scale,
	# then the gun's local basis is orthonormalized and sampled at full weight.
	# All calculations stay local; deployment, aim and hitbox state are untouched.
	var parent_scale: Vector3=parent_transform.basis.get_scale()
	if not parent_scale.is_finite(): return Vector3.INF
	var global_aim: Basis=Basis.looking_at(forward,up,true)*Basis.from_scale(parent_scale)
	var local_aim: Basis=parent_transform.basis.inverse()*global_aim
	if not local_aim.is_finite(): return Vector3.INF
	local_aim=local_aim.orthonormalized()
	local_aim=Basis.IDENTITY.slerp(local_aim,1.0)
	var raised_gun := parent_transform*Transform3D(local_aim,raised_local)
	var preview: Vector3=raised_gun*muzzle.position
	return preview if preview.is_finite() else Vector3.INF

func fire_visual(endpoint: Vector3) -> void:
	if shut_down or not setup_complete or not endpoint.is_finite(): return
	_trigger_discharge_artwork()
	var origin := muzzle_position()
	_trace_origin = origin
	# A late cover/peer move also clips the visual trace. This query cannot apply
	# damage; combat passes the real discharge hit and keeps all hit authority.
	_trace_endpoint = _physical_endpoint(origin, endpoint)
	var offset := _trace_endpoint - origin
	if offset.length_squared() < .000001: return
	var last := origin
	for i in ARC_SEGMENTS:
		var t := float(i + 1) / float(ARC_SEGMENTS)
		# Straight segments retain the actual ray endpoint and cannot wiggle
		# through the edge of cover beside a physically blocked shot.
		var next := origin.lerp(_trace_endpoint, t)
		var direction := next - last
		var orientation := Basis(Quaternion(Vector3.UP, direction.normalized()))
		_arc_pieces[i].global_transform = Transform3D(orientation * Basis.from_scale(Vector3(1.0, direction.length(), 1.0)), (last + next) * .5)
		last = next
	# The bright trace reaches the physical hit. There is no contact spark to
	# enlarge at the victim's camera or obscure the independent screen fizz.
	_spark.visible = false
	_aim_root.visible = false; _aim_phase = ""; _aim_endpoint = Vector3.INF
	_arc_root.visible = true
	_flash_remaining = FLASH_SECONDS
	_update_helix()
	_update_charge()
	set_process(true)

func cancel_attack() -> void:
	_attack_seconds = -1.0; _aim_point = Vector3.INF; deploy_amount = 0.0
	_aim_endpoint = Vector3.INF; _trace_endpoint = Vector3.INF; _aim_phase = ""
	_flash_remaining = 0.0; _trace_origin = Vector3.INF
	if _helix_mesh != null: _helix_mesh.clear_surfaces()
	# A completed gun retraction must not cut short the comic shot label.
	set_process(_artwork_remaining > 0.0)
	if not setup_complete: return
	hatch_left.rotation = Vector3.ZERO; hatch_right.rotation = Vector3.ZERO
	gun.position.y = GUN_REST_Y; gun.basis = Basis.IDENTITY; gun.visible = false
	_stem.visible = false; _arc_root.visible = false; _aim_root.visible = false
	_set_damage_enabled(false)
	_update_charge()

func shutdown() -> void:
	if shut_down: return
	cancel_attack(); shut_down = true; _actor = null
	_artwork_remaining = 0.0
	if is_instance_valid(_artwork_sprite): _artwork_sprite.visible = false
	if is_instance_valid(damage_area):
		# Damage callbacks are rejected immediately, including during the frame
		# before the deferred collision-layer update and node retirement finish.
		damage_area.set("actor", null)
		damage_area.set_deferred("collision_layer", 0)
		damage_area.queue_free()
	set_process(false); set_physics_process(false)

func on_ragdoll_started(body: PhysicalBone3D) -> void:
	# The normal integration needs no hook: PoliceLights already reparents to
	# Body. This optional handoff remains safe for other actor integrations.
	if not is_instance_valid(body) or not is_instance_valid(mount): return
	if body.is_ancestor_of(mount): return
	mount.reparent(body, true)

func _apply_aim() -> void:
	if not is_instance_valid(gun): return
	# The closed gun fits fully between the floor and lids and behind the end
	# walls. Lift it straight before any yaw/pitch; return it straight while
	# still fully raised, before lowering it through the cassette opening.
	var aim_weight := smoothstep(.98, 1.0, deploy_amount)
	if _attack_seconds >= 0.0:
		aim_weight *= 1.0 - smoothstep(AIM_RETURN_START_SECONDS, RETRACT_START_SECONDS, _attack_seconds)
	if aim_weight <= 0.0:
		gun.basis = Basis.IDENTITY
		return
	if not _aim_point.is_finite(): return
	var offset := _aim_point - gun.global_position
	if offset.length_squared() < .000001: return
	var up := mount.global_basis.y.normalized()
	if absf(offset.normalized().dot(up)) > .98: up = mount.global_basis.x.normalized()
	gun.look_at(_aim_point, up, true)
	gun.basis = Basis.IDENTITY.slerp(gun.basis.orthonormalized(), aim_weight)

func _set_damage_enabled(enabled: bool) -> void:
	if _damage_enabled == enabled or not is_instance_valid(damage_area): return
	_damage_enabled = enabled
	damage_area.set_deferred("collision_layer", 4 if enabled else 0)

func _update_charge() -> void:
	if _charge_material == null: return
	var strength := 0.0
	if _attack_seconds >= 0.0 and deploy_amount > .03:
		strength = deploy_amount * lerpf(.20, 2.2, smoothstep(.30, WINDUP_SECONDS, _attack_seconds))
	if _flash_remaining > 0.0: strength = 4.0
	_charge_material.emission_energy_multiplier = strength
	var warning := _aim_phase == "red" and _flash_remaining <= 0.0
	var base := Color(.19, .012, .008) if warning else Color(.015, .13, .17)
	var lit := Color(1.0, .06, .02) if warning else Color(.10, .75, .90)
	_charge_material.emission = Color(1.0, .025, .01) if warning else Color(.10, .85, 1.0)
	_charge_material.albedo_color = base.lerp(lit, clampf(strength / 4.0, 0.0, 1.0))

func _physical_endpoint(origin: Vector3, endpoint: Vector3) -> Vector3:
	var offset := endpoint - origin
	if not origin.is_finite() or not offset.is_finite() or offset.length_squared() < .000001: return origin
	var bounded := origin + offset.normalized() * minf(offset.length(), ARC_VISIBLE_METRES)
	if not is_instance_valid(_actor) or not _actor.is_inside_tree(): return origin
	var query := PhysicsRayQueryParameters3D.create(origin, bounded, 1|2|8)
	query.exclude = [_actor.get_rid()]; query.hit_from_inside = true
	var hit := _actor.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("position", bounded)

func _update_targeting() -> void:
	_aim_root.visible = false; _aim_endpoint = Vector3.INF; _aim_phase = ""
	# The gun has cleared the hatch and reached its true aimed pose before the
	# cue appears. No preview ray starts inside the stowed cassette.
	if _attack_seconds < LIFT_FINISHED_SECONDS or _attack_seconds >= WINDUP_SECONDS: return
	if deploy_amount < .999 or not _aim_point.is_finite(): return
	var origin := muzzle_position()
	var forward := muzzle.global_basis.z.normalized()
	_aim_endpoint = _physical_endpoint(origin, origin + forward * ARC_VISIBLE_METRES)
	var direction := _aim_endpoint - origin
	if direction.length_squared() < .000001: return
	_aim_phase = "red" if _attack_seconds >= RED_WARNING_SECONDS else "blue"
	# Each emitter owns its mutable material: one drone's red warning cannot
	# recolor another drone's blue cue. Meshes and immutable trace material share.
	var color := Color(1.0, .035, .015) if _aim_phase == "red" else Color(.025, .32, 1.0)
	_aim_material.albedo_color = color; _aim_material.emission = color
	var focus := smoothstep(LIFT_FINISHED_SECONDS, RED_WARNING_SECONDS, _attack_seconds)
	var radius_scale := 1.2 if _aim_phase == "red" else lerpf(1.15, .70, focus)
	var orientation := Basis(Quaternion(Vector3.UP, direction.normalized()))
	_aim_beam.global_transform = Transform3D(orientation * Basis.from_scale(Vector3(radius_scale, direction.length(), radius_scale)), (origin + _aim_endpoint) * .5)
	_aim_root.visible = true

func _process(delta: float) -> void:
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	_artwork_remaining = maxf(0.0, _artwork_remaining - delta)
	if _flash_remaining > 0.0:
		_update_helix()
	else:
		_arc_root.visible = false; _trace_endpoint = Vector3.INF; _trace_origin = Vector3.INF
		if _helix_mesh != null: _helix_mesh.clear_surfaces()
		_update_charge()
	_update_discharge_artwork_view()
	set_process(_flash_remaining > 0.0 or _artwork_remaining > 0.0)

func set_discharge_artwork(texture: Texture2D) -> void:
	# Only supplied artwork is accepted. An empty slot never invents a label.
	discharge_artwork = texture
	if not is_instance_valid(_artwork_sprite): return
	_artwork_sprite.texture = texture
	_artwork_sprite.pixel_size = 1.05 / maxf(1.0, float(texture.get_width())) if texture != null else .002
	if texture == null:
		_artwork_remaining = 0.0; _artwork_sprite.visible = false

func _build_discharge_artwork() -> void:
	if discharge_artwork == null: discharge_artwork = _load_supplied_artwork()
	_artwork_sprite = Sprite3D.new(); _artwork_sprite.name = "SuppliedTazerComicArtwork"
	add_child(_artwork_sprite); _artwork_sprite.top_level = true
	_artwork_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_artwork_sprite.shaded = false; _artwork_sprite.no_depth_test = false
	_artwork_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_artwork_sprite.visible = false
	set_discharge_artwork(discharge_artwork)

func _trigger_discharge_artwork() -> void:
	if discharge_artwork == null or not is_instance_valid(_artwork_sprite): return
	_artwork_remaining = DISCHARGE_ARTWORK_SECONDS
	_update_discharge_artwork_view()
	set_process(true)

func _update_discharge_artwork_view() -> void:
	if not is_instance_valid(_artwork_sprite): return
	_artwork_sprite.visible = false
	if _artwork_remaining <= 0.0 or discharge_artwork == null or not is_instance_valid(_actor): return
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera): return
	var distance := camera.global_position.distance_to(_actor.global_position)
	if distance >= ARTWORK_HIDE_METRES: return
	# Keep the original nearby size, then hold roughly constant angular size.
	# Cap growth before the distance fade so far-away fights cannot fill the HUD.
	var size_scale := clampf(distance / ARTWORK_SCALE_START_METRES, 1.0, ARTWORK_FADE_START_METRES / ARTWORK_SCALE_START_METRES)
	_artwork_sprite.scale = Vector3.ONE * size_scale
	var height := 1.05 * float(discharge_artwork.get_height()) / maxf(1.0, float(discharge_artwork.get_width()))
	_artwork_sprite.global_position = _actor.global_position + Vector3.UP * (1.45 + height * (size_scale - 1.0) * 0.5)
	_artwork_sprite.modulate.a = 1.0 - smoothstep(ARTWORK_FADE_START_METRES, ARTWORK_HIDE_METRES, distance)
	_artwork_sprite.visible = true

func _update_helix() -> void:
	_helix_mesh.clear_surfaces()
	if not _trace_origin.is_finite() or not _trace_endpoint.is_finite(): return
	var axis := _trace_endpoint - _trace_origin
	var length := axis.length()
	if length < .001: return
	var forward := axis / length
	var reference := Vector3.UP if absf(forward.y) < .95 else Vector3.RIGHT
	var right := forward.cross(reference).normalized()
	var up := right.cross(forward).normalized()
	var age := FLASH_SECONDS - _flash_remaining
	var turns := clampf(length * 1.25, 1.5, 12.0)
	var phase := age * 38.0
	var fade := clampf(_flash_remaining / .10, 0.0, 1.0)
	var camera := get_viewport().get_camera_3d()
	var view_position := camera.global_position if camera != null else _trace_origin + up * 3.0
	_helix_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _helix_material)
	for strand: int in HELIX_STRANDS:
		var last := _trace_origin
		for index: int in range(1, HELIX_SEGMENTS + 1):
			var t := float(index) / float(HELIX_SEGMENTS)
			var angle := t * turns * TAU - phase + float(strand) * PI
			# Taper to the exact muzzle/hit: no winding extends past the cover hit.
			var envelope := sin(t * PI)
			var radius := minf(.14, length * .08) * envelope * (1.0 + .15 * sin(t * 91.0 + phase * 2.0))
			var next := _trace_origin + axis * t + (right * cos(angle) + up * sin(angle)) * radius
			var tangent := (next - last).normalized()
			var facing := (view_position - (last + next) * .5).normalized()
			var ribbon := tangent.cross(facing)
			if ribbon.length_squared() < .000001: ribbon = right
			ribbon = ribbon.normalized() * .006
			_helix_mesh.surface_set_color(Color(.35, .80, 1.0, fade * .90))
			for vertex: Vector3 in [last-ribbon, next-ribbon, next+ribbon, last-ribbon, next+ribbon, last+ribbon]:
				var along := (vertex - _trace_origin).dot(forward)
				var bounded_vertex := vertex + forward * (clampf(along, 0.0, length) - along)
				_helix_mesh.surface_add_vertex(bounded_vertex)
			last = next
	_helix_mesh.surface_end()

func _exit_tree() -> void:
	if is_instance_valid(mount) and not mount.is_queued_for_deletion(): mount.queue_free()

func _hatch(side: float, node_name: String) -> Node3D:
	var hinge := Node3D.new(); hinge.name = node_name
	hinge.position = Vector3(side * .085, .028, 0); mount.add_child(hinge)
	_box(hinge, Vector3(.080, .010, .19), Vector3(-side * .041, 0, 0), _metal, "Lid")
	_box(hinge, Vector3(.063, .002, .14), Vector3(-side * .041, .006, 0), _trim, "InsetPanel")
	for end: float in [-1.0, 1.0]:
		_box(hinge, Vector3(.010, .003, .014), Vector3(-side * .015, .007, end * .065), _recess, "HingeFastener")
	return hinge

func _box(parent: Node3D, size: Vector3, center: Vector3, material: Material, node_name: String) -> MeshInstance3D:
	var key := str(size)
	if not _box_meshes.has(key):
		var mesh := BoxMesh.new(); mesh.size = size; _box_meshes[key] = mesh
	var instance := MeshInstance3D.new(); instance.name = node_name
	instance.mesh = _box_meshes[key]; instance.material_override = material
	instance.position = center; parent.add_child(instance)
	return instance

func _build_flash() -> void:
	_arc_root = Node3D.new(); _arc_root.name = "StunDischargeFlash"; add_child(_arc_root)
	_arc_root.top_level = true; _arc_root.global_transform = Transform3D.IDENTITY
	for i in ARC_SEGMENTS:
		var piece := MeshInstance3D.new(); piece.name = "Arc" + str(i)
		piece.mesh = _unit_trace; piece.material_override = _arc_material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arc_root.add_child(piece); _arc_pieces.append(piece)
	_spark = MeshInstance3D.new(); _spark.name = "StunContactSpark"
	_spark.mesh = _spark_mesh; _spark.material_override = _arc_material
	_spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arc_root.add_child(_spark); _arc_root.visible = false
	_helix_mesh = ImmediateMesh.new()
	_helix_visual = MeshInstance3D.new(); _helix_visual.name = "ElectricalDischargeHelix"
	_helix_visual.mesh = _helix_mesh
	_helix_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arc_root.add_child(_helix_visual)

func _build_targeting() -> void:
	_aim_material = StandardMaterial3D.new()
	_aim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aim_material.emission_enabled = true
	_aim_material.emission_energy_multiplier = 3.0
	_aim_root = Node3D.new(); _aim_root.name = "StunTargetingCue"; add_child(_aim_root)
	_aim_root.top_level = true; _aim_root.global_transform = Transform3D.IDENTITY
	_aim_beam = MeshInstance3D.new(); _aim_beam.name = "TargetingBeam"
	_aim_beam.mesh = _unit_arc; _aim_beam.material_override = _aim_material
	_aim_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aim_root.add_child(_aim_beam); _aim_root.visible = false

static func _ensure_resources() -> void:
	if _metal != null: return
	_metal = StandardMaterial3D.new(); _metal.albedo_color = Color(.28, .32, .34)
	_metal.metallic = .72; _metal.roughness = .34
	_trim = StandardMaterial3D.new(); _trim.albedo_color = Color(.055, .070, .080)
	_trim.metallic = .65; _trim.roughness = .42
	_recess = StandardMaterial3D.new(); _recess.albedo_color = Color(.012, .018, .022)
	_recess.metallic = .25; _recess.roughness = .72
	_arc_material = StandardMaterial3D.new(); _arc_material.albedo_color = Color(.30, .95, 1.0)
	_arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_material.emission_enabled = true; _arc_material.emission = Color(.20, .85, 1.0)
	_arc_material.emission_energy_multiplier = 4.0
	_helix_material = StandardMaterial3D.new()
	_helix_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_helix_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_helix_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_helix_material.vertex_color_use_as_albedo = true
	_helix_material.emission_enabled = true; _helix_material.emission = Color(.12, .55, 1.0)
	_helix_material.emission_energy_multiplier = 3.0
	_unit_stem = CylinderMesh.new(); _unit_stem.top_radius = .009; _unit_stem.bottom_radius = .009
	_unit_stem.height = 1.0; _unit_stem.radial_segments = 10
	_unit_arc = CylinderMesh.new(); _unit_arc.top_radius = .0025; _unit_arc.bottom_radius = .0025
	_unit_arc.height = 1.0; _unit_arc.radial_segments = 6
	# A bright 3 cm discharge stays distinct from the 5 mm aiming laser.
	_unit_trace = CylinderMesh.new(); _unit_trace.top_radius = .015; _unit_trace.bottom_radius = .015
	_unit_trace.height = 1.0; _unit_trace.radial_segments = 8
	_spark_mesh = SphereMesh.new(); _spark_mesh.radius = .014; _spark_mesh.height = .028
	_spark_mesh.radial_segments = 8; _spark_mesh.rings = 4

static func _load_supplied_artwork() -> Texture2D:
	if _supplied_artwork_texture != null: return _supplied_artwork_texture
	var raw_exists := FileAccess.file_exists(DISCHARGE_ARTWORK_PATH)
	# Preserve the supplied alpha and use the imported texture when available.
	# A fresh install before editor import may load those same PNG bytes once.
	if ResourceLoader.exists(DISCHARGE_ARTWORK_PATH) and (FileAccess.file_exists(DISCHARGE_ARTWORK_PATH + ".import") or not raw_exists):
		_supplied_artwork_texture = load(DISCHARGE_ARTWORK_PATH) as Texture2D
		if _supplied_artwork_texture != null: return _supplied_artwork_texture
	if not raw_exists: return null
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(DISCHARGE_ARTWORK_PATH)) != OK: return null
	_supplied_artwork_texture = ImageTexture.create_from_image(image)
	return _supplied_artwork_texture

static func _load_gun_scene() -> PackedScene:
	if _gun_scene != null: return _gun_scene
	var raw_file_exists := FileAccess.file_exists(GUN_ASSET_PATH)
	# The editor normally supplies an imported PackedScene. A fresh installed
	# GLB may precede the editor's import: parse it once in memory instead of
	# substituting geometry or repeatedly doing file work for every pack member.
	# Exported packs may retain only the imported/remapped resource. A local raw
	# GLB without import metadata still takes the quiet in-memory fallback below.
	if ResourceLoader.exists(GUN_ASSET_PATH) and (FileAccess.file_exists(GUN_ASSET_PATH + ".import") or not raw_file_exists):
		_gun_scene = load(GUN_ASSET_PATH) as PackedScene
		if _gun_scene != null: return _gun_scene
	if not raw_file_exists: return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(ProjectSettings.globalize_path(GUN_ASSET_PATH), state) != OK: return null
	var imported: Node3D = document.generate_scene(state)
	if imported == null: return null
	var cached := PackedScene.new()
	var packed: Error = cached.pack(imported)
	imported.free()
	if packed != OK: return null
	_gun_scene = cached
	return _gun_scene
