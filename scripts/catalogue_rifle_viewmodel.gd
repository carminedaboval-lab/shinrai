extends "res://scripts/uzi_viewmodel.gd"

# Generic authored rifle assemblies over the live first-person rig. Gameplay
# ammunition, readiness and cadence remain owned by the player/catalogue.
const Catalog = preload("res://scripts/extraction_weapon_catalog.gd")
const PoseModifier = preload("res://scripts/extraction_weapon_pose.gd")
const Reticle = preload("res://assets/weapons/optics/reflex_reticle.gdshader")
const PrismReticle = preload("res://assets/weapons/optics/prism_reticle.gdshader")
const PrismView = preload("res://scripts/extraction_prism_scope_view.gd")
const MuzzleFlash = preload("res://assets/weapons/effects/muzzle_flash.gdshader")
const Presentation = preload("res://scripts/extraction_weapon_presentation.gd")
const RaidenReferenceReload = preload("res://scripts/raiden_reference_reload.gd")
@export var weapon_key := "kite"
@export var assembly_scene: PackedScene
@export var magazine_grip := Vector3(-.066,-.085,0)
var assembly: Node3D
var optic_socket: Node3D
var magazine_mesh: Node3D
var magazine_exchange=preload("./raiden_reference_magazine_exchange.gd").new()
var optic_model: Node3D
var skeleton: Skeleton3D
var body_bone := -1
var magazine_bone := -1
var right_hand_bone := -1
var left_bones: Array[int] = []
var right_bones: Array[int] = []
# Interior grasp points derived from the supplied thumb/finger bone positions,
# rather than the wrist origin or the heel of the hand.
const RIGHT_PALM_CONTACT := Vector3(-.035,.105,.012)
const LEFT_PALM_CONTACT := Vector3(.035,.115,.018)
var body_fit := Transform3D.IDENTITY
var magazine_reference := Transform3D.IDENTITY
var magazine_rest := Transform3D.IDENTITY
var assembly_reference := Transform3D.IDENTITY
@export var optic_id := ""
var reticle_material: ShaderMaterial
var prism_view: Node
var gameplay_camera: Camera3D
var _fitted := false
var _reload_duration := 2.2
var _reload_empty := false
var _closed_fingers: Dictionary = {}
var _presentation_hold := false
var _flash_timer := 0.0
var _flash: MeshInstance3D
var _flash_material: ShaderMaterial
var _flash_light: OmniLight3D
var _magazine_inserted := true
var _reload_started_without_mag := false
var _reload_outgoing_destination := "cargo"
var _last_support_wrist_local := Vector3.ZERO
var _have_support_wrist := false
var _ground_release_wrist_local := Vector3.ZERO
var _have_ground_release_wrist := false
var _cases: Array[Dictionary] = []
var _rig_base_transform := Transform3D.IDENTITY
var _rig_motion := Transform3D.IDENTITY
var _chamber_presentation := false
var action_mesh: Node3D
var action_rest := Transform3D.IDENTITY
var action_grip_local := Vector3.ZERO
var _action_elapsed := 0.0
var _action_duration := 0.08
var _action_active := false
var _optic_magnification := 1.0
var _presentation_profile := "kite"

func _resolve_part(metadata_key: String, fallback_names: Array[String]) -> Node3D:
	var authored_path := str(assembly.get_meta(metadata_key, ""))
	if not authored_path.is_empty():
		return assembly.get_node_or_null(NodePath(authored_path)) as Node3D
	for part_name: String in fallback_names:
		var candidate := assembly.find_child(part_name, true, false) as Node3D
		if candidate != null:
			return candidate
	return null

func _validate_assembly() -> bool:
	for marker: String in ["GripRight", "GripLeft", "OpticSocket", "Muzzle", "IronRearSight", "IronFrontSight", "BoltRelease", "EjectionPort"]:
		if not assembly.get_node_or_null(NodePath(marker)) is Node3D:
			_fail("Required assembly marker is unavailable: " + marker)
			return false
	var sight_axis: Vector3 = assembly.get_node("IronFrontSight").position - assembly.get_node("IronRearSight").position
	if sight_axis.length() < 0.1 or sight_axis.x >= 0.0:
		_fail("Iron-sight markers must define a forward negative-X sight line")
		return false
	return true

func _reset_action() -> void:
	_action_active = false
	_action_elapsed = 0.0
	if is_instance_valid(action_mesh) and is_instance_valid(assembly):
		action_mesh.global_transform = assembly.global_transform * action_rest

func _update_action_pose() -> void:
	if not is_instance_valid(action_mesh):
		return
	action_mesh.global_transform = assembly.global_transform * action_rest
	if _action_active:
		var phase := clampf(_action_elapsed / maxf(_action_duration, 0.001), 0.0, 1.0)
		var travel := float(Catalog.WEAPONS[weapon_key].get("action_travel_m", 0.035))
		action_mesh.global_position += assembly.global_basis.x * travel * sin(phase * PI)

func get_action_grip_world() -> Vector3:
	return action_mesh.to_global(action_grip_local) if is_instance_valid(action_mesh) else assembly.get_node("ActionGrip").global_position

func get_muzzle_world_position() -> Vector3:
	# Uses the current rig-driven assembly, including reload/recoil motion.
	if is_instance_valid(assembly):
		var muzzle_marker := assembly.get_node_or_null("Muzzle") as Node3D
		if muzzle_marker != null:
			return muzzle_marker.global_position
	return global_position

func get_ads_eye_relief() -> float:
	if optic_id.is_empty():
		return float(Catalog.WEAPONS.get(weapon_key, {}).get("iron_eye_relief_m", 0.205))
	var optics: Dictionary = Catalog.OPTICS.get(optic_id, {})
	var magnification := float(optics.get("magnification", 3.0 if optic_id == "prism_01" else 1.0))
	return clampf(float(optics.get("eye_relief_m", 0.115 if magnification > 1.0 else 0.17)), 0.06, 0.35)

func get_sight_world_points() -> PackedVector3Array:
	if is_instance_valid(optic_model):
		return PackedVector3Array([optic_model.get_node("RearSight").global_position, optic_model.get_node("FrontSight").global_position])
	if is_instance_valid(assembly):
		return PackedVector3Array([assembly.get_node("IronRearSight").global_position, assembly.get_node("IronFrontSight").global_position])
	return PackedVector3Array()

func is_sight_aligned() -> bool:
	# Precision gating is based on the physical moving sights and camera ray.
	# The integration owner supplies the final UZI base with settled ADS hold.
	if ads_blend < 0.95 or not is_ready_for_input() or not is_instance_valid(gameplay_camera):
		return false
	var rear_marker: Node3D
	var front_marker: Node3D
	if is_instance_valid(optic_model):
		rear_marker = optic_model.get_node_or_null("RearSight") as Node3D
		front_marker = optic_model.get_node_or_null("FrontSight") as Node3D
	elif is_instance_valid(assembly):
		rear_marker = assembly.get_node_or_null("IronRearSight") as Node3D
		front_marker = assembly.get_node_or_null("IronFrontSight") as Node3D
	if rear_marker == null or front_marker == null:
		return false
	var rear_local := gameplay_camera.to_local(rear_marker.global_position)
	var front_local := gameplay_camera.to_local(front_marker.global_position)
	var axis := front_local - rear_local
	if not rear_local.is_finite() or not front_local.is_finite() or axis.length_squared() < 0.000001:
		return false
	# 0.15 degrees of angular tolerance and 1 mm at the rear plane. These are
	# presentation acceptance tolerances, not fictional ammunition spread.
	return rear_local.z < 0.0 and front_local.z < rear_local.z and Vector2(rear_local.x, rear_local.y).length() <= 0.001 and axis.normalized().dot(Vector3.FORWARD) >= cos(deg_to_rad(0.15))

func set_magazine_inserted(value: bool) -> void:
	_magazine_inserted = value
	if is_instance_valid(magazine_mesh):
		var clip := str(animation_player.current_animation).to_lower()
		magazine_mesh.visible = value or clip.contains("reload")

func set_reload_outgoing_destination(destination: String) -> void:
	# Player/raid owns the transaction and the world drop. This affects only
	# Raiden's nonempty presentation after the real eject callback.
	if destination == "ground" and _reload_outgoing_destination != "ground" and _have_support_wrist:
		_ground_release_wrist_local = _last_support_wrist_local
		_have_ground_release_wrist = true
	_reload_outgoing_destination = "ground" if destination == "ground" else "cargo"

func hold_presentation(value: bool) -> void:
	_presentation_hold = value
	if value:
		cancel_reload_presentation()
	visible = loaded and _fitted and not value

func cancel_reload_presentation() -> void:
	# Resolve only the visible magazine against the player-supplied inserted
	# state. Cancellation never changes ammunition or invents a loaded magazine.
	magazine_exchange.update(0.0, false, _magazine_inserted, false)
	_chamber_presentation = false
	_ads_idle_held = false
	_rig_motion = Transform3D.IDENTITY
	_reset_action()
	if animation_player != null and not idle_anim_name.is_empty():
		animation_player.speed_scale = 1.0
		animation_player.play(idle_anim_name, 0.08)

func _process(delta: float) -> void:
	super._process(delta)
	if _action_active:
		_action_elapsed = minf(_action_duration, _action_elapsed + maxf(delta, 0.0))
		if _action_elapsed >= _action_duration:
			_action_active = false
	for i: int in range(_cases.size()-1,-1,-1):
		var entry: Dictionary = _cases[i]
		entry.time -= delta
		if not is_instance_valid(entry.node) or entry.time <= 0:
			if is_instance_valid(entry.node): entry.node.queue_free()
			_cases.remove_at(i)
			continue
		entry.velocity.y -= 9.81*delta
		entry.node.global_position += entry.velocity*delta
		entry.node.rotate_object_local(Vector3.RIGHT,delta*entry.spin)
	_flash_timer = maxf(0.0,_flash_timer-delta)
	if is_instance_valid(_flash):
		_flash.visible = _flash_timer > 0
		var life := clampf(_flash_timer / .035,0.0,1.0)
		_flash_material.set_shader_parameter("life",life)
		_flash_light.light_energy = .85 * life

func _ready() -> void:
	name = weapon_key.capitalize() + "_Viewmodel"
	visible = false
	_build_sight_markers()
	call_deferred("_load_bundled_model")

func _prepare_imported_nodes(node: Node) -> void:
	super._prepare_imported_nodes(node)
	if node is MeshInstance3D and (str(node.name).to_lower() in ["object_1084", "object_1085"]):
		node.visible = false

func _load_bundled_model() -> void:
	if _fitted or failed:
		return
	if not Catalog.WEAPONS.has(weapon_key):
		_fail("Weapon catalog entry is unavailable: " + weapon_key)
		return
	_presentation_profile = str(Catalog.WEAPONS[weapon_key].get("presentation_profile", "kite"))
	super._load_bundled_model()
	if failed or imported_root == null or assembly_scene == null:
		_fail("Weapon assembly is unavailable")
		return
	var skeletons := imported_root.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		_fail("Supplied hand skeleton is unavailable")
		return
	skeleton = skeletons[0] as Skeleton3D
	body_bone = skeleton.find_bone("UZI Body_0725")
	magazine_bone = skeleton.find_bone("UZI Mag_0713")
	right_hand_bone = skeleton.find_bone("DEF-hand.R_0583")
	for bone_name: String in ["DEF-upper_arm.L_0454", "DEF-upper_arm.L.001_0455", "DEF-forearm.L_0456", "DEF-forearm.L.001_0457", "DEF-hand.L_0458"]:
		left_bones.append(skeleton.find_bone(bone_name))
	for bone_name: String in ["DEF-upper_arm.R_0579", "DEF-upper_arm.R.001_0580", "DEF-forearm.R_0581", "DEF-forearm.R.001_0582", "DEF-hand.R_0583"]:
		right_bones.append(skeleton.find_bone(bone_name))
	if body_bone < 0 or magazine_bone < 0 or right_hand_bone < 0 or left_bones.has(-1) or right_bones.has(-1):
		_fail("Supplied hand rig has changed; fitting is required")
		return
	animation_player.play(idle_anim_name, 0.0)
	animation_player.advance(0.2)
	skeleton.force_update_all_bone_transforms()
	for id: int in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(id)
		if bone_name.begins_with("DEF-") and bone_name.contains(".L") and (bone_name.contains("f_") or bone_name.contains("thumb")):
			_closed_fingers[id] = skeleton.get_bone_pose(id)
	assembly = assembly_scene.instantiate() as Node3D
	imported_root.add_child(assembly)
	if not _validate_assembly():
		return
	assembly.basis = Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE / MODEL_SCALE)
	var palm_world := skeleton.global_transform * skeleton.get_bone_global_pose(right_hand_bone).origin
	var palm_model := imported_root.to_local(palm_world)
	assembly.position = palm_model - assembly.basis * assembly.get_node("GripRight").position
	optic_socket = assembly.get_node("OpticSocket")
	magazine_mesh = _resolve_part("magazine_node_path", ["Magazine", "Kite_Magazine", "Shigure_Magazine"])
	if magazine_mesh == null:
		_fail("Separate moving magazine is unavailable")
		return
	magazine_mesh = magazine_exchange.wrap(magazine_mesh)
	magazine_rest = assembly.global_transform.affine_inverse() * magazine_mesh.global_transform
	action_mesh = _resolve_part("action_node_path", ["Action", "BoltAssembly", "Kite_Action"])
	if action_mesh == null:
		_fail("Separate moving action is unavailable")
		return
	action_rest = assembly.global_transform.affine_inverse() * action_mesh.global_transform
	var action_contact := assembly.get_node_or_null("ActionGrip") as Node3D
	if action_contact == null:
		action_contact = action_mesh.find_child("BoltGrip", true, false) as Node3D
	if action_contact == null:
		_fail("Action grip contact marker is unavailable")
		return
	action_grip_local = action_mesh.to_local(action_contact.global_position)
	var authored_magazine_grip: Variant = assembly.get_meta("magazine_grip", magazine_grip)
	if authored_magazine_grip is Vector3:
		magazine_grip = authored_magazine_grip
	body_fit = (skeleton.global_transform * skeleton.get_bone_global_pose(body_bone)).affine_inverse() * assembly.global_transform
	assembly_reference = global_transform.affine_inverse() * assembly.global_transform
	magazine_reference = skeleton.get_bone_global_pose(body_bone).affine_inverse() * skeleton.get_bone_global_pose(magazine_bone)
	_prepare_imported_nodes(assembly)
	_fitted = true
	_rig_base_transform = imported_root.transform
	if not set_optic(optic_id):
		_fail("Owned optic model is unavailable")
		return
	var modifier := PoseModifier.new()
	modifier.viewmodel = self
	skeleton.add_child(modifier)
	modifier.active = true
	_build_fire_effect()
	visible = not _presentation_hold
	play_equip()
	status_changed.emit(Catalog.WEAPONS[weapon_key].title + " ready")

func set_optic(id: String) -> bool:
	if not id.is_empty() and (not Catalog.compatible(weapon_key, id) or not ResourceLoader.exists(Catalog.OPTICS[id].scene)):
		return false
	# Validate replacement completely before removing the currently working
	# sight. A malformed resource must not leave catalog and presentation split.
	var replacement: Node3D
	if _fitted and not id.is_empty():
		var packed := load(Catalog.OPTICS[id].scene) as PackedScene
		if packed == null:
			return false
		replacement = packed.instantiate() as Node3D
		if replacement == null:
			return false
		var rear := replacement.get_node_or_null("RearSight") as Node3D
		var front := replacement.get_node_or_null("FrontSight") as Node3D
		if rear == null or front == null or rear.position.distance_squared_to(front.position) < 0.000001:
			replacement.free()
			return false
		var has_lens := false
		for lens: MeshInstance3D in replacement.find_children("*", "MeshInstance3D", true, false):
			if str(lens.name).contains("OpticGlass") and str(lens.name).contains("Rear"):
				has_lens = true
		if not has_lens:
			replacement.free()
			return false
	_optic_magnification = float(Catalog.OPTICS[id].get("magnification", 3.0 if id == "prism_01" else 1.0)) if not id.is_empty() else 1.0
	optic_id = id
	if not _fitted:
		return true
	if is_instance_valid(prism_view):
		prism_view.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		remove_child(prism_view)
		prism_view.queue_free()
	prism_view = null
	if is_instance_valid(optic_model):
		optic_socket.remove_child(optic_model)
		optic_model.queue_free()
	optic_model = null
	reticle_material = null
	if not id.is_empty():
		optic_model = replacement
		optic_socket.add_child(optic_model)
		_prepare_imported_nodes(optic_model)
		for mesh: MeshInstance3D in optic_model.find_children("*", "MeshInstance3D", true, false):
			if str(mesh.name).contains("OpticGlass"):
				if str(mesh.name).contains("Rear"):
					reticle_material = ShaderMaterial.new()
					reticle_material.shader = PrismReticle if _optic_magnification > 1.0 else Reticle
					if _optic_magnification > 1.0:
						reticle_material.set_shader_parameter("eye_relief_m",get_ads_eye_relief())
						reticle_material.set_shader_parameter("aperture_radius_m",float(Catalog.OPTICS[id].get("aperture_radius_m",0.0177 if id == "scope_01" else 0.0118)))
					mesh.material_override = reticle_material
				else:
					var glass := StandardMaterial3D.new()
					glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					glass.albedo_color = Color(0.65, 0.47, 0.18, 0.035)
					glass.roughness = 0.08
					glass.cull_mode = BaseMaterial3D.CULL_DISABLED
					mesh.material_override = glass
	_update_sight_alignment()
	var ancestor := get_parent()
	while ancestor != null and not ancestor is Camera3D:
		ancestor = ancestor.get_parent()
	gameplay_camera = ancestor as Camera3D
	if _optic_magnification > 1.0 and gameplay_camera != null and reticle_material != null:
		prism_view = PrismView.new()
		add_child(prism_view)
		prism_view.configure(gameplay_camera,reticle_material)
	return true

func _update_sight_alignment() -> void:
	# The authored iron parts are a separate subtree in the accepted rifle assets.
	# Stow only those parts when an optic is mounted; never hide merged receiver
	# geometry or alter the two iron markers used when the optic is removed.
	var iron_path := NodePath(str(assembly.get_meta("iron_sights_node_path", "Geometry/IronSights")))
	var iron_sights := assembly.get_node_or_null(iron_path) as Node3D
	if iron_sights != null:
		iron_sights.visible = not is_instance_valid(optic_model)
	if is_instance_valid(optic_model):
		var reference := assembly_reference * optic_socket.transform * optic_model.transform
		rear_sight_point.position = reference * optic_model.get_node("RearSight").position
		front_sight_point.position = reference * optic_model.get_node("FrontSight").position
	else:
		# Assembly-specific measured rear rail edge and actual front sight.
		rear_sight_point.position = assembly_reference * assembly.get_node("IronRearSight").position
		front_sight_point.position = assembly_reference * assembly.get_node("IronFrontSight").position
	_derive_ads_transform_from_sights()

func update_supplied_pose(rig: Skeleton3D, delta: float = 0.0) -> void:
	if not _fitted or not loaded or rig == null:
		return
	var current_clip := str(animation_player.assigned_animation).to_lower()
	var ratio := 0.0
	var raiden_partial := weapon_key == "raiden_r56" and current_clip.contains("reload") and not current_clip.contains("empty") and not _chamber_presentation
	var working_pose := Transform3D.IDENTITY
	if current_clip.contains("reload"):
		var duration := animation_player.get_animation(animation_player.assigned_animation).length
		ratio = animation_player.current_animation_position / duration
		if raiden_partial:
			working_pose = RaidenReferenceReload.pose(ratio)
			_rig_motion = Transform3D.IDENTITY
		else:
			_rig_motion = Presentation.pose(_presentation_profile,current_clip.contains("empty"),ratio)
		if _chamber_presentation:
			_rig_motion = Transform3D.IDENTITY.interpolate_with(_rig_motion,smoothstep(.60,.65,ratio))
	else:
		_rig_motion = _rig_motion.interpolate_with(Transform3D.IDENTITY,1.0-exp(-28.0*delta)) if delta>0 else Transform3D.IDENTITY
	imported_root.transform = _rig_motion * _rig_base_transform
	var body_pose := rig.get_bone_global_pose(body_bone)
	var magazine_pose := rig.get_bone_global_pose(magazine_bone)
	assembly.global_transform = rig.global_transform * body_pose * body_fit
	var bone_rotation := Basis.IDENTITY
	if raiden_partial:
		# Keep the supplied shoulders fixed; move the rifle about its real grip.
		# Align the real muzzle axis to the camera-space working direction; the
		# working phase blends in and out without changing gameplay timing.
		var camera_basis := gameplay_camera.global_basis.orthonormalized() if is_instance_valid(gameplay_camera) else global_basis.orthonormalized()
		var pivot: Vector3 = assembly.get_node("GripRight").global_position
		var current_axis: Vector3 = (assembly.get_node("Muzzle").global_position-pivot).normalized()
		var target_axis: Vector3 = (camera_basis * Vector3(-.12,.95,-.25).normalized()).normalized()
		var working_blend := smoothstep(0.0,.25,ratio) * (1.0-smoothstep(.75,1.0,ratio))
		var world_rotation := Basis(Quaternion.IDENTITY.slerp(Quaternion(current_axis,target_axis),working_blend))
		assembly.global_transform = Transform3D(world_rotation * assembly.global_basis, pivot + camera_basis * working_pose.origin + world_rotation * (assembly.global_position - pivot))
		var rig_basis := rig.global_basis.orthonormalized()
		bone_rotation = rig_basis.inverse() * world_rotation * rig_basis
	_update_action_pose()
	var delta_mag := (body_pose.affine_inverse() * magazine_pose) * magazine_reference.affine_inverse()
	var body_world := rig.global_transform * body_pose
	magazine_mesh.global_transform = body_world * delta_mag * body_world.affine_inverse() * assembly.global_transform * magazine_rest
	if raiden_partial:
		# Drive both magazines from the real socket, then use the support-hand IK.
		magazine_mesh.global_transform = assembly.global_transform * magazine_rest
		magazine_mesh.global_position += global_basis * RaidenReferenceReload.magazine_offset(ratio)
	var magazine_turn := bone_rotation if raiden_partial else Basis.IDENTITY
	if current_clip.contains("reload") and not _chamber_presentation and not raiden_partial:
		magazine_mesh.global_position += global_basis * Presentation.magazine_arc(_presentation_profile,current_clip.contains("empty"),ratio)
		# Present the broad side while detached, then return to the source
		# alignment before seating. Rotate about the grasp, keeping it attached.
		var show_mag := Presentation.magazine_display(_presentation_profile,current_clip.contains("empty"),ratio)
		var source_basis := magazine_mesh.global_basis
		var display_basis := global_basis * Basis.from_euler(Vector3(deg_to_rad(-10),deg_to_rad(8),deg_to_rad(12 if _presentation_profile=="kite" else -18)))
		var grip_before := magazine_mesh.to_global(magazine_grip)
		magazine_mesh.global_basis = Basis(source_basis.get_rotation_quaternion().slerp(display_basis.get_rotation_quaternion(),show_mag)).scaled(source_basis.get_scale())
		magazine_mesh.global_position = grip_before-magazine_mesh.global_basis*magazine_grip
		magazine_turn = rig.global_basis.inverse()*magazine_mesh.global_basis*source_basis.inverse()*rig.global_basis
	if reticle_material != null and is_instance_valid(optic_model):
		reticle_material.set_shader_parameter("sight_axis", optic_model.global_basis.z.normalized())
		if is_instance_valid(prism_view) and is_instance_valid(gameplay_camera):
			prism_view.sync(gameplay_camera,optic_model.get_node("RearSight").global_position,optic_model.global_basis.z.normalized(),optic_model.global_basis.y.normalized(),ads_blend>.05 and is_visible_in_tree(),_optic_magnification)
	var poses: Array[Transform3D] = []
	for id: int in left_bones:
		poses.append(rig.get_bone_global_pose(id))
	var right_poses: Array[Transform3D] = []
	for id: int in right_bones: right_poses.append(rig.get_bone_global_pose(id))
	var right_hand_basis := bone_rotation * right_poses[4].basis if raiden_partial else right_poses[4].basis
	var right_palm_offset := rig.global_basis*right_hand_basis*RIGHT_PALM_CONTACT
	var right_target: Vector3 = assembly.get_node("GripRight").global_position-right_palm_offset
	_solve_arm(rig,right_bones,right_poses,rig.global_transform.affine_inverse()*right_target,true)
	if raiden_partial:
		var right_hand := rig.get_bone_global_pose(right_bones[4])
		right_hand.basis = right_hand_basis
		rig.set_bone_global_pose(right_bones[4],right_hand)
	var desired_world: Vector3 = assembly.get_node("GripLeft").global_position
	magazine_mesh.visible = _magazine_inserted or current_clip.contains("reload")
	var dropped_outgoing := raiden_partial and _reload_outgoing_destination == "ground" and ratio >= .16
	magazine_exchange.update(ratio,current_clip.contains("reload") and not _chamber_presentation,_magazine_inserted,current_clip.contains("empty"),raiden_partial,dropped_outgoing)
	var grasp := 0.0
	var magazine_grasp := 0.0
	var bolt_grasp := 0.0
	var grip_return := 0.0
	var contact_world := desired_world
	var free_wrist_world := desired_world
	if current_clip.contains("reload"):
		var source_wrist := rig.global_transform*poses[4].origin
		var anticipation := smoothstep(0.0,.045 if current_clip.contains("empty") else .065,ratio)
		grip_return = RaidenReferenceReload.support_return(ratio) if raiden_partial else Presentation.support_return(current_clip.contains("empty"),ratio)
		var no_outgoing := _reload_started_without_mag or dropped_outgoing
		free_wrist_world = desired_world if raiden_partial and no_outgoing else desired_world.lerp(source_wrist,anticipation).lerp(desired_world,grip_return)
		if dropped_outgoing and _have_ground_release_wrist:
			# Continue from the last rendered support wrist as the hand leaves the
			# dropped magazine, rather than snapping immediately to the foregrip.
			free_wrist_world = to_global(_ground_release_wrist_local).lerp(source_wrist,smoothstep(.16,.27,ratio))
		desired_world = free_wrist_world
		var new_grip := magazine_mesh.to_global(magazine_grip)
		var weight := (RaidenReferenceReload.grasp(ratio,no_outgoing) if raiden_partial else Presentation.magazine_grasp(_presentation_profile,current_clip.contains("empty"),ratio))*(1.0-grip_return)
		if raiden_partial:
			# Fade tracking before asking the arm to reach beyond its real chain.
			var shoulder: Vector3 = rig.global_transform * poses[0].origin
			var elbow: Vector3 = rig.global_transform * poses[2].origin
			var wrist: Vector3 = rig.global_transform * poses[4].origin
			var reach := shoulder.distance_to(elbow) + elbow.distance_to(wrist)
			weight *= 1.0-smoothstep(reach*.92,reach*1.12,shoulder.distance_to(new_grip))
		magazine_grasp = weight
		if _reload_started_without_mag and ratio < 0.25:
			magazine_mesh.visible = false
		# A wrist marker is not the palm contact point. Retain the authored
		# magazine-hand orientation and account for the supplied glove's palm.
		var palm_offset := rig.global_basis * poses[4].basis * LEFT_PALM_CONTACT
		desired_world = desired_world.lerp(new_grip - palm_offset, weight)
		contact_world = new_grip
		grasp = weight
		if current_clip.contains("empty"):
			var bolt_press := Presentation.bolt_press(_presentation_profile,ratio)
			bolt_grasp = bolt_press
			var release_point: Vector3 = assembly.get_node("BoltRelease").global_position
			desired_world = desired_world.lerp(release_point-palm_offset, bolt_press)
			contact_world = contact_world.lerp(release_point,bolt_press)
			grasp = maxf(grasp,bolt_press)
	_solve_arm(rig,left_bones,poses,rig.global_transform.affine_inverse()*desired_world)
	if grasp > 0:
		for iteration: int in range(3):
			var solved := rig.get_bone_global_pose(left_bones[4])
			# Preserve the supplied magazine-hand rotation while solving the arm
			# position; rotating the forearm alone used to turn the palm off it.
			solved.basis = Basis(solved.basis.get_rotation_quaternion().slerp((magazine_turn*poses[4].basis).get_rotation_quaternion(),magazine_grasp*(1.0 if _presentation_profile=="kite" else .85))).scaled(solved.basis.get_scale())
			rig.set_bone_global_pose(left_bones[4],solved)
			var palm_offset := rig.global_basis * solved.basis * LEFT_PALM_CONTACT
			var wrist_target: Vector3 = free_wrist_world.lerp(contact_world-palm_offset,grasp)
			_solve_arm(rig,left_bones,poses,rig.global_transform.affine_inverse()*wrist_target)
		var final_hand := rig.get_bone_global_pose(left_bones[4])
		final_hand.basis = Basis(final_hand.basis.get_rotation_quaternion().slerp((magazine_turn*poses[4].basis).get_rotation_quaternion(),magazine_grasp*(1.0 if _presentation_profile=="kite" else .85))).scaled(final_hand.basis.get_scale())
		rig.set_bone_global_pose(left_bones[4],final_hand)
	if raiden_partial and grip_return > 0.0:
		# Rotate the returning support palm with the rifle as well as its target.
		var returning_hand := rig.get_bone_global_pose(left_bones[4])
		var target_basis := bone_rotation * poses[4].basis
		var blended := Basis(returning_hand.basis.get_rotation_quaternion().slerp(target_basis.get_rotation_quaternion(),grip_return)).scaled(returning_hand.basis.get_scale())
		var contact_offset := rig.global_basis * blended * LEFT_PALM_CONTACT
		var wrist_world := rig.global_transform * returning_hand.origin
		var return_target := wrist_world.lerp(assembly.get_node("GripLeft").global_position-contact_offset,grip_return)
		_solve_arm(rig,left_bones,poses,rig.global_transform.affine_inverse()*return_target)
		returning_hand = rig.get_bone_global_pose(left_bones[4])
		returning_hand.basis = blended
		rig.set_bone_global_pose(left_bones[4],returning_hand)
	if raiden_partial:
		_last_support_wrist_local = to_local(rig.global_transform * rig.get_bone_global_pose(left_bones[4]).origin)
		_have_support_wrist = true
	for id: int in _closed_fingers:
		# Retain authored exchange articulation and close onto the support grip
		# during recovery, instead of carrying an open manipulation hand into it.
		var finger_weight := maxf(maxf(magazine_grasp,bolt_grasp*.35),grip_return)
		if finger_weight>0: rig.set_bone_pose(id,rig.get_bone_pose(id).interpolate_with(_closed_fingers[id],finger_weight))

func _solve_arm(rig: Skeleton3D, bones: Array[int], poses: Array[Transform3D], target: Vector3, preserve_hand_orientation: bool = false) -> void:
	var shoulder := poses[0].origin
	var elbow := poses[2].origin
	var wrist := poses[4].origin
	var upper_length := shoulder.distance_to(elbow)
	var lower_length := elbow.distance_to(wrist)
	var distance := clampf(shoulder.distance_to(target), 0.001, upper_length + lower_length - 0.001)
	var direction := (target - shoulder).normalized()
	var normal := (elbow - shoulder).cross(wrist - shoulder).normalized()
	if normal.length_squared() < 0.01:
		normal = Vector3.FORWARD
	var bend := normal.cross(direction).normalized()
	if bend.dot(elbow - shoulder) < 0.0:
		bend = -bend
	var along := (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var new_elbow := shoulder + direction * along + bend * height
	var new_wrist := shoulder + direction * distance
	var upper_rotation := Basis(Quaternion((elbow - shoulder).normalized(), (new_elbow - shoulder).normalized()))
	var lower_rotation := Basis(Quaternion((wrist - elbow).normalized(), (new_wrist - new_elbow).normalized()))
	for i: int in range(5):
		var pose := poses[i]
		if i < 2:
			pose.origin = shoulder + upper_rotation * (pose.origin - shoulder)
			pose.basis = upper_rotation * pose.basis
		elif i < 4:
			pose.origin = new_elbow + lower_rotation * (pose.origin - elbow)
			pose.basis = lower_rotation * pose.basis
		else:
			pose.origin = new_wrist
			if not preserve_hand_orientation: pose.basis = lower_rotation * pose.basis
		rig.set_bone_global_pose(bones[i], pose)

func play_equip() -> void:
	_ads_idle_held = false
	if animation_player != null:
		animation_player.speed_scale = 1.0
		animation_player.play(equip_anim_name, 0.0)

func play_holster() -> void:
	cancel_reload_presentation()
	if animation_player != null:
		animation_player.speed_scale = 1.0
		var chosen := _find_animation_name(animation_player.get_animation_list(), ["unequip"], [])
		if not chosen.is_empty():
			animation_player.play(chosen, 0.06)

func play_reload(empty: bool) -> void:
	_ads_idle_held = false
	_reset_action()
	_reload_outgoing_destination = "cargo"
	_have_support_wrist = false
	_have_ground_release_wrist = false
	magazine_exchange.begin(_magazine_inserted)
	_chamber_presentation = false
	_reload_started_without_mag = not _magazine_inserted
	_reload_empty = empty
	_reload_duration = get_reload_duration(empty)
	var chosen := empty_reload_anim_name if empty else reload_anim_name
	animation_player.speed_scale = animation_player.get_animation(chosen).length / _reload_duration
	animation_player.play(chosen, 0.08)

func play_chamber(duration: float) -> void:
	_ads_idle_held = false
	_reset_action()
	_chamber_presentation = true
	_reload_started_without_mag = false
	var clip_length := animation_player.get_animation(empty_reload_anim_name).length
	animation_player.speed_scale = clip_length * 0.40 / maxf(duration, 0.1)
	animation_player.play(empty_reload_anim_name, 0.04)
	animation_player.seek(clip_length * 0.60, true)

func get_reload_duration(empty: bool) -> float:
	return float(Catalog.WEAPONS[weapon_key].reload_empty if empty else Catalog.WEAPONS[weapon_key].reload_partial)

func _on_animation_finished(animation_name: StringName) -> void:
	animation_player.speed_scale = 1.0
	super._on_animation_finished(animation_name)

func is_ready_for_input() -> bool:
	var current := str(animation_player.current_animation).to_lower() if animation_player != null else ""
	return loaded and _fitted and not failed and not _presentation_hold and not current.contains("equip") and not current.contains("reload") and not current.contains("inspect")

func _build_fire_effect() -> void:
	var muzzle: Node3D = assembly.get_node("Muzzle")
	_flash = MeshInstance3D.new()
	var sprite := QuadMesh.new()
	var span := .075 if weapon_key == "shigure" else .10
	sprite.size = Vector2(span,span)
	_flash.mesh = sprite
	_flash.position.z = .035 if weapon_key == "shigure" else .045
	_flash.layers = VIEWMODEL_LAYER
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = MuzzleFlash
	_flash_material.set_shader_parameter("life",0.0)
	_flash.material_override = _flash_material
	_flash.visible = false
	muzzle.add_child(_flash)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1,.65,.32)
	_flash_light.omni_range = 1.4
	_flash_light.light_cull_mask = VIEWMODEL_LAYER
	_flash_light.light_energy = 0
	muzzle.add_child(_flash_light)

func play_fire() -> void:
	if not is_ready_for_input(): return
	super.play_fire()
	if str(Catalog.WEAPONS[weapon_key].get("mode", "semi")) != "bolt":
		_action_duration = maxf(float(Catalog.WEAPONS[weapon_key].get("action_duration_s", 0.08)), 0.02)
		_action_elapsed = 0.0
		_action_active = true
	_flash_timer = .035
	_flash_material.set_shader_parameter("shot_seed",randf_range(0.0,TAU))
	_flash_material.set_shader_parameter("life",1.0)
	_flash.visible = true
	_flash_light.light_energy = .85
	_eject_case()

func _eject_case() -> void:
	var case_mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = float(Catalog.WEAPONS[weapon_key].get("case_radius_m", .006))
	shape.bottom_radius = shape.top_radius
	shape.height = float(Catalog.WEAPONS[weapon_key].get("case_length_m", .051))
	shape.radial_segments = 10
	case_mesh.mesh = shape
	case_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	case_mesh.layers = VIEWMODEL_LAYER
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(.52,.34,.11)
	brass.metallic = .75
	brass.roughness = .33
	case_mesh.material_override = brass
	get_tree().root.add_child(case_mesh)
	case_mesh.global_transform = assembly.get_node("EjectionPort").global_transform
	case_mesh.rotate_object_local(Vector3.FORWARD,PI*.5)
	var outward := -assembly.global_basis.z.normalized()
	_cases.append({"node":case_mesh,"velocity":outward*randf_range(1.5,2.2)+Vector3.UP*randf_range(.7,1.2),"spin":randf_range(8,16),"time":1.6})
	if _cases.size()>24:
		_cases[0].node.queue_free()
		_cases.remove_at(0)

func _exit_tree() -> void:
	for entry: Dictionary in _cases:
		if is_instance_valid(entry.node): entry.node.queue_free()
	_cases.clear()
