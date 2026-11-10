extends "res://scripts/uzi_viewmodel.gd"

# Candidate presentation only; gameplay and ammunition remain owner-controlled.
# Derived from supplied rig adapter; see SOURCE_CONTRACT.json for source hashes.
const OPTIC_SCENES := {"reflex_01": "res://assets/weapons/optics/ame_reflex.tscn"}
@export var display_title := "HIBARI / H-9C"
@export var reload_partial_seconds := 1.75
@export var reload_empty_seconds := 2.25
@export var slide_travel := 0.026
@export var slide_cycle_seconds := 0.105
@export var optic_mount_enabled := true
@export_range(0.08, 0.8, 0.01, "suffix:m") var iron_eye_relief_m := ADS_REAR_DEPTH
## World scale of the supplied arms and hands. 1.48 is the rig's old enlarged
## size; 1.0 is life size, which is what a true-size gun needs.
@export_range(0.5, 2.0, 0.01) var hand_world_scale := MODEL_SCALE
## Reload by putting the old magazine back in the rig and drawing a fresh one
## (scripts/pistol_reload_retention.gd) instead of the older lift-and-swap.
@export var retention_reload := false
## Moves both hands on the gun, in the gun's own axes (x toward the shooter, y up,
## z shooter's left), metres. The grip markers suit the old enlarged hands; true-
## size hands need to sit higher, under the slide.
@export var grip_hand_offset := Vector3.ZERO
@export var case_length := 0.019
@export var case_radius := 0.0048
var slide_mesh: Node3D
var slide_rest := Transform3D.IDENTITY
var optic_socket_rest := Transform3D.IDENTITY
var trigger_mesh: Node3D
var trigger_rest := Transform3D.IDENTITY
var _slide_elapsed := 1.0
var _bolt_locked := false
const PistolFillLighting = preload("res://scripts/pistol_fill_lighting.gd")
const PoseModifier = preload("res://scripts/extraction_weapon_pose.gd")
const Reticle = preload("res://assets/weapons/optics/reflex_reticle.gdshader")
const PrismReticle = preload("res://assets/weapons/optics/prism_reticle.gdshader")
const PrismView = preload("res://scripts/extraction_prism_scope_view.gd")
const MuzzleFlash = preload("res://assets/weapons/effects/muzzle_flash.gdshader")
const Presentation = preload("res://scripts/pistol_candidate_presentation.gd")
const Retention = preload("res://scripts/pistol_reload_retention.gd")
@export var weapon_key := "hibari_h9c"
@export var assembly_scene: PackedScene
@export var magazine_grip := Vector3(.045,-.105,0)
var assembly: Node3D
var optic_socket: Node3D
var magazine_mesh: Node3D
var magazine_exchange=preload("./extraction_magazine_exchange.gd").new()
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
var _pistol_left_idle: Array[Transform3D] = []
var _pistol_right_idle: Array[Transform3D] = []
var _pistol_finger_idle: Dictionary = {}
var _pistol_thumb_contact := LEFT_PALM_CONTACT
var _pistol_release_weight := 0.0
var _pistol_magazine_contact_weight := 0.0
var _pistol_contact_target_world := Vector3.ZERO
var _presentation_hold := false
var _flash_timer := 0.0
var _flash: MeshInstance3D
var _flash_material: ShaderMaterial
var _flash_light: OmniLight3D
var _magazine_inserted := true
var _reload_started_without_mag := false
var _cases: Array[Dictionary] = []
var _rig_base_transform := Transform3D.IDENTITY
var _rig_motion := Transform3D.IDENTITY
var _chamber_presentation := false
# Pistol fixed to the idle right hand, so a reload can move the gun with the
# wrist instead of folding the wrist to a gun that moved on its own.
var _hand_to_assembly := Transform3D.IDENTITY
# How much the reloading hands keep their natural (forearm-following) wrist
# versus the authored presentation cant. 1.0 = wrist never bends from idle.
const RELOAD_WRIST_CANT_WEIGHT := 0.6

func set_magazine_inserted(value: bool) -> void:
	_magazine_inserted = value
	if is_instance_valid(magazine_mesh):
		var clip := str(animation_player.current_animation).to_lower() if animation_player != null else ""
		magazine_mesh.visible = value or clip.contains("reload")

func hold_presentation(value: bool) -> void:
	_presentation_hold = value
	visible = loaded and _fitted and not value

func _process(delta: float) -> void:
	super._process(delta)
	_update_aim_light()
	_slide_elapsed += delta
	_update_slide()
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

# Aimed, a pistol's rear sight and slide face the eye and the sun is usually
# behind them, so in daylight they read as a flat black block. A narrow, weak
# spot from the eye (viewmodel layer only, aimed at the sight picture) gives
# them form and lifts the sight paint, the way other shooters light the
# aimed weapon. It fades in with the aim and stays off at the hip.
const AIM_LIGHT_ENERGY := 0.7
const AIM_LIGHT_EYE := Vector3(0.0, 0.014, 0.02)
var _aim_light: SpotLight3D

func _update_aim_light() -> void:
	var weight := smoothstep(0.45, 1.0, ads_blend) if optic_id.is_empty() else 0.0
	if _aim_light == null:
		if weight <= 0.0:
			return
		_aim_light = SpotLight3D.new()
		_aim_light.name = "PistolAimLight"
		_aim_light.spot_angle = 6.5
		_aim_light.spot_angle_attenuation = 0.6
		_aim_light.spot_range = 0.9
		_aim_light.light_specular = 0.08
		_aim_light.light_color = Color(1.0, 0.98, 0.95)
		_aim_light.shadow_enabled = false
		_aim_light.light_cull_mask = VIEWMODEL_LAYER
		add_child(_aim_light)
	_aim_light.visible = weight > 0.0
	_aim_light.light_energy = AIM_LIGHT_ENERGY * weight
	# Keep it at the eye (the parent's origin) while the gun itself moves.
	var eye := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-2.5)), AIM_LIGHT_EYE)
	_aim_light.transform = transform.affine_inverse() * eye

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
	super._load_bundled_model()
	PistolFillLighting.apply(self)
	if failed or imported_root == null or assembly_scene == null or animation_player == null:
		_fail("Weapon assembly is unavailable")
		return
	var skeletons := imported_root.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		_fail("Supplied hand skeleton is unavailable")
		return
	skeleton = skeletons[0] as Skeleton3D
	# Imported glove meshes can retain a Skin but lose their Skeleton3D path.
	# Bind the original glove mesh to the supplied rig before fitting the pistol.
	var glove := imported_root.find_child("Object_13", true, false) as MeshInstance3D
	if glove == null or glove.skin == null:
		_fail("Supplied glove mesh or skin is unavailable")
		return
	glove.skeleton = glove.get_path_to(skeleton)
	if glove.get_node_or_null(glove.skeleton) != skeleton:
		_fail("Supplied glove skeleton binding is invalid")
		return
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
	_cache_pistol_reload_pose()
	# Hands at true size. The supplied rig is drawn 1.48x life size (a far-and-large
	# viewmodel trick that suited its own, equally enlarged gun). The rebuilt guns
	# are true size, so on them the hands read half as big again as they should and
	# the fingers overrun the frame. Scale the rig about the firing hand: the gun,
	# its sights and the aim stay exactly where they were.
	if not is_equal_approx(hand_world_scale, MODEL_SCALE):
		var palm_before := to_local(skeleton.global_transform * skeleton.get_bone_global_pose(right_hand_bone).origin)
		imported_root.scale = Vector3.ONE * hand_world_scale
		var palm_after := to_local(skeleton.global_transform * skeleton.get_bone_global_pose(right_hand_bone).origin)
		imported_root.position += palm_before - palm_after
	assembly = assembly_scene.instantiate() as Node3D
	if assembly == null:
		_fail("Pistol assembly root must be Node3D")
		return
	for marker: String in ["GripRight", "GripLeft", "OpticSocket", "Muzzle", "IronRearSight", "IronFrontSight", "BoltRelease", "EjectionPort"]:
		if not assembly.get_node_or_null(marker) is Node3D:
			assembly.free()
			assembly = null
			_fail("Pistol assembly marker missing: " + marker)
			return
	imported_root.add_child(assembly)
	assembly.basis = Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE / hand_world_scale)
	var palm_world := skeleton.global_transform * skeleton.get_bone_global_pose(right_hand_bone).origin
	var palm_model := imported_root.to_local(palm_world)
	assembly.position = palm_model - assembly.basis * assembly.get_node("GripRight").position
	optic_socket = assembly.get_node("OpticSocket")
	optic_socket_rest = optic_socket.transform
	trigger_mesh = assembly.find_child("Trigger", true, false) as Node3D
	if trigger_mesh != null:
		trigger_rest = assembly.global_transform.affine_inverse() * trigger_mesh.global_transform
	magazine_mesh = assembly.find_child("Magazine", true, false) as Node3D
	slide_mesh = assembly.find_child("Slide", true, false) as Node3D
	if slide_mesh == null:
		_fail("Separate moving slide is unavailable")
		return
	slide_rest = assembly.global_transform.affine_inverse() * slide_mesh.global_transform
	if magazine_mesh == null:
		_fail("Separate moving magazine is unavailable")
		return
	magazine_mesh = magazine_exchange.wrap(magazine_mesh)
	magazine_rest = assembly.global_transform.affine_inverse() * magazine_mesh.global_transform
	body_fit = (skeleton.global_transform * skeleton.get_bone_global_pose(body_bone)).affine_inverse() * assembly.global_transform
	assembly_reference = global_transform.affine_inverse() * assembly.global_transform
	_hand_to_assembly = (skeleton.global_transform * _pistol_right_idle[4]).affine_inverse() * assembly.global_transform
	if retention_reload:
		# At this point the grip marker sits on the wrist bone, which is only how the
		# fit is seeded: in the hand the grip belongs at the palm contact. Riding the
		# gun on the hand with the seeded offset pushed the grip through the heel of
		# the hand for the whole reload. Hold it where the hand really grips it.
		_hand_to_assembly = Transform3D(Basis.IDENTITY, RIGHT_PALM_CONTACT - _hand_to_assembly.basis * grip_hand_offset) * _hand_to_assembly
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
	status_changed.emit(display_title + " candidate ready")

func set_optic(id: String) -> bool:
	if not id.is_empty() and (not optic_mount_enabled or not OPTIC_SCENES.has(id) or not ResourceLoader.exists(OPTIC_SCENES[id])):
		return false
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
		optic_model = (load(OPTIC_SCENES[id]) as PackedScene).instantiate() as Node3D
		optic_socket.add_child(optic_model)
		_prepare_imported_nodes(optic_model)
		for mesh: MeshInstance3D in optic_model.find_children("*", "MeshInstance3D", true, false):
			if str(mesh.name).contains("OpticGlass"):
				if str(mesh.name).contains("Rear"):
					reticle_material = ShaderMaterial.new()
					reticle_material.shader = PrismReticle if id == "prism_01" else Reticle
					if id == "prism_01":
						reticle_material.set_shader_parameter("eye_relief_m",ADS_REAR_DEPTH)
					mesh.material_override = reticle_material
				else:
					var glass := StandardMaterial3D.new()
					glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					if id == "reflex_01":
						# Clear neutral Ame window; keep other optics' authored glass.
						glass.albedo_color = Color(0.85, 0.85, 0.85, 0.012)
						glass.metallic_specular = 0.08
					else:
						glass.albedo_color = Color(0.65, 0.47, 0.18, 0.035)
					glass.roughness = 0.08
					glass.cull_mode = BaseMaterial3D.CULL_DISABLED
					mesh.material_override = glass
	_update_sight_alignment()
	var ancestor := get_parent()
	while ancestor != null and not ancestor is Camera3D:
		ancestor = ancestor.get_parent()
	gameplay_camera = ancestor as Camera3D
	if id == "prism_01" and gameplay_camera != null:
		prism_view = PrismView.new()
		add_child(prism_view)
		prism_view.configure(gameplay_camera,reticle_material)
	return true

func get_ads_eye_relief() -> float:
	# Pistols can extend their iron sights to a two-hand aiming distance while
	# retaining the optic's existing camera position.
	return iron_eye_relief_m if optic_id.is_empty() else ADS_REAR_DEPTH

func _update_sight_alignment() -> void:
	if is_instance_valid(optic_model):
		var reference := assembly_reference * optic_socket_rest
		rear_sight_point.position = reference * optic_model.get_node("RearSight").position
		front_sight_point.position = reference * optic_model.get_node("FrontSight").position
	else:
		# Assembly-specific measured rear rail edge and actual front sight.
		rear_sight_point.position = assembly_reference * assembly.get_node("IronRearSight").position
		front_sight_point.position = assembly_reference * assembly.get_node("IronFrontSight").position
	_derive_ads_transform_from_sights()

func _cache_pistol_reload_pose() -> void:
	for id: int in left_bones: _pistol_left_idle.append(skeleton.get_bone_global_pose(id))
	for id: int in right_bones: _pistol_right_idle.append(skeleton.get_bone_global_pose(id))
	for id: int in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(id)
		if bone_name.begins_with("DEF-") and (bone_name.contains("f_") or bone_name.contains("thumb")):
			_pistol_finger_idle[id] = skeleton.get_bone_pose(id)
	var thumb_tip := skeleton.find_bone("DEF-thumb.03.L_end_0976")
	if thumb_tip >= 0:
		_pistol_thumb_contact = _pistol_left_idle[4].affine_inverse()*skeleton.get_bone_global_pose(thumb_tip).origin

func update_supplied_pose(rig: Skeleton3D, delta: float = 0.0) -> void:
	if not _fitted or not loaded or rig == null:
		return
	var current_clip := str(animation_player.assigned_animation).to_lower()
	var reloading := current_clip.contains("reload")
	var empty := current_clip.contains("empty")
	var ratio := 0.0
	if reloading:
		ratio = animation_player.current_animation_position / animation_player.get_animation(animation_player.assigned_animation).length
		if _retention_active():
			_rig_motion = Retention.gun(ratio,empty,assembly_reference*(assembly.get_node("GripRight") as Node3D).position)
		else:
			_rig_motion = Presentation.pose(weapon_key,empty,ratio)
		if _chamber_presentation:
			_rig_motion = Transform3D.IDENTITY.interpolate_with(_rig_motion,smoothstep(.60,.65,ratio))
	else:
		_rig_motion = _rig_motion.interpolate_with(Transform3D.IDENTITY,1.0-exp(-28.0*delta)) if delta>0 else Transform3D.IDENTITY
	# Move the pistol into the working area while shoulders stay below the eye.
	imported_root.transform = _rig_base_transform if reloading else _rig_motion * _rig_base_transform
	if reloading:
		# Retain the calibrated pistol, not the UZI's moving receiver/magazine bones.
		assembly.global_transform = global_transform * _rig_motion * assembly_reference
		magazine_mesh.global_transform = assembly.global_transform * magazine_rest
		if _retention_active():
			magazine_mesh.global_transform = assembly.global_transform * Retention.magazine(ratio) * magazine_rest
		elif not _chamber_presentation:
			magazine_mesh.global_position += assembly.global_basis * Presentation.magazine_offset(empty,ratio)
		for id: int in _pistol_finger_idle: rig.set_bone_pose(id,_pistol_finger_idle[id])
		if _retention_active():
			# The support hand opens to reach, closes on the magazine, lets go in the
			# pouch, takes the fresh one and opens again as the palm drives it home.
			var open := Retention.fingers_open(ratio)
			for id: int in _closed_fingers:
				rig.set_bone_pose(id,(_pistol_finger_idle[id] as Transform3D).interpolate_with(rig.get_bone_rest(id),open))
	else:
		var body_pose := rig.get_bone_global_pose(body_bone)
		assembly.global_transform = rig.global_transform * body_pose * body_fit
		magazine_mesh.global_transform = assembly.global_transform * magazine_rest
	if reticle_material != null and is_instance_valid(optic_model):
		reticle_material.set_shader_parameter("sight_axis", optic_model.global_basis.z.normalized())
		if is_instance_valid(prism_view) and is_instance_valid(gameplay_camera):
			prism_view.sync(gameplay_camera,optic_model.get_node("RearSight").global_position,optic_model.global_basis.z.normalized(),optic_model.global_basis.y.normalized(),ads_blend>.05 and is_visible_in_tree(),3.0)
	var poses: Array[Transform3D] = []
	var right_poses: Array[Transform3D] = []
	for index: int in range(left_bones.size()):
		poses.append(_pistol_left_idle[index] if reloading else rig.get_bone_global_pose(left_bones[index]))
		right_poses.append(_pistol_right_idle[index] if reloading else rig.get_bone_global_pose(right_bones[index]))
	if reloading:
		# The presentation lifts the pistol ~20 cm. Reaching it from the idle arm
		# used to keep the idle hand orientation, so the forearm swung up while the
		# hand stayed put and the wrist folded. Let the hand follow the forearm,
		# keep a little of the authored cant, and attach the pistol to that hand.
		var cant := rig.global_basis.inverse() * (global_basis * _rig_motion.basis * global_basis.inverse()) * rig.global_basis
		var cant_basis := cant * right_poses[4].basis
		var grip_target: Vector3 = assembly.get_node("GripRight").global_position + assembly.global_basis * grip_hand_offset
		var provisional_offset := rig.global_basis * cant_basis * RIGHT_PALM_CONTACT
		_solve_arm(rig,right_bones,right_poses,rig.global_transform.affine_inverse()*(grip_target-provisional_offset),false)
		var natural := rig.get_bone_global_pose(right_bones[4]).basis
		var hand_basis := Basis(natural.get_rotation_quaternion().slerp(cant_basis.get_rotation_quaternion(),RELOAD_WRIST_CANT_WEIGHT)).scaled(natural.get_scale())
		right_poses[4].basis = hand_basis
		var palm_offset := rig.global_basis * hand_basis * RIGHT_PALM_CONTACT
		_solve_arm(rig,right_bones,right_poses,rig.global_transform.affine_inverse()*(grip_target-palm_offset),true)
		# The pistol now rides on the solved hand, so palm and grip stay together.
		assembly.global_transform = rig.global_transform * rig.get_bone_global_pose(right_bones[4]) * _hand_to_assembly
		magazine_mesh.global_transform = assembly.global_transform * magazine_rest
		if _retention_active():
			magazine_mesh.global_transform = assembly.global_transform * Retention.magazine(ratio) * magazine_rest
		elif not _chamber_presentation:
			magazine_mesh.global_position += assembly.global_basis * Presentation.magazine_offset(empty,ratio)
	else:
		var right_palm_offset := rig.global_basis*right_poses[4].basis*RIGHT_PALM_CONTACT
		var right_target: Vector3 = assembly.get_node("GripRight").global_position+assembly.global_basis*grip_hand_offset-right_palm_offset
		_solve_arm(rig,right_bones,right_poses,rig.global_transform.affine_inverse()*right_target,true)
	magazine_mesh.visible = _magazine_inserted or reloading
	magazine_exchange.update(ratio,reloading and not _chamber_presentation,_magazine_inserted,empty)
	if _retention_active() and magazine_exchange.swapping:
		# One magazine is in the hand at a time: the old one until it is in its
		# pouch, the fresh one from the moment it is drawn.
		if is_instance_valid(magazine_exchange.current): magazine_exchange.current.visible = magazine_exchange.had_magazine and ratio < Retention.STOWED_AT
		if is_instance_valid(magazine_exchange.replacement): magazine_exchange.replacement.visible = ratio >= Retention.DRAWN_AT
	var contact_world: Vector3 = assembly.get_node("GripLeft").global_position + assembly.global_basis * grip_hand_offset
	var contact_local := LEFT_PALM_CONTACT
	_pistol_release_weight = 0.0
	_pistol_magazine_contact_weight = 0.0
	if _retention_active():
		_pistol_magazine_contact_weight = Retention.grasp(ratio)
		contact_world = contact_world.lerp(magazine_mesh.to_global(magazine_grip),_pistol_magazine_contact_weight)
		_pistol_release_weight = Retention.slide_release(empty,ratio)
		contact_world = contact_world.lerp(assembly.get_node("BoltRelease").global_position,_pistol_release_weight)
		contact_local = contact_local.lerp(_pistol_thumb_contact,_pistol_release_weight)
	elif reloading:
		if not _chamber_presentation:
			var fetch: Vector3 = assembly.to_global(magazine_grip+Vector3(.030,-.160,.035))
			contact_world = contact_world.lerp(fetch,Presentation.support_fetch(empty,ratio))
			_pistol_magazine_contact_weight = Presentation.magazine_grasp(weapon_key,empty,ratio)
			contact_world = contact_world.lerp(magazine_mesh.to_global(magazine_grip),_pistol_magazine_contact_weight)
		_pistol_release_weight = Presentation.release_weight(empty,ratio)
		if _chamber_presentation: _pistol_release_weight *= smoothstep(.60,.68,ratio)
		# Use the original glove thumb tip at the slide stop, not a palm/SMG handle.
		contact_world = contact_world.lerp(assembly.get_node("BoltRelease").global_position,_pistol_release_weight)
		contact_local = contact_local.lerp(_pistol_thumb_contact,_pistol_release_weight)
	_pistol_contact_target_world = contact_world
	var wrist_world := contact_world-rig.global_basis*poses[4].basis*contact_local
	if reloading:
		# Same treatment for the support hand: follow the forearm to the contact,
		# then re-aim the contact point with the hand it actually ended up with.
		_solve_arm(rig,left_bones,poses,rig.global_transform.affine_inverse()*wrist_world,false)
		for iteration: int in range(2):
			var natural := rig.get_bone_global_pose(left_bones[4]).basis
			var held := _pistol_left_idle[4].basis
			if _retention_active():
				# The hand turns with the magazine it is carrying.
				var gun_basis := assembly.global_basis.orthonormalized()
				var rig_basis := rig.global_basis.orthonormalized()
				var turn := rig_basis.inverse() * (gun_basis * Retention.magazine(ratio).basis * gun_basis.inverse()) * rig_basis
				held = Basis(Quaternion.IDENTITY.slerp(turn.get_rotation_quaternion(),_pistol_magazine_contact_weight)) * held
			poses[4].basis = Basis(natural.get_rotation_quaternion().slerp(held.get_rotation_quaternion(),RELOAD_WRIST_CANT_WEIGHT)).scaled(natural.get_scale())
			wrist_world = contact_world-rig.global_basis*poses[4].basis*contact_local
			_solve_arm(rig,left_bones,poses,rig.global_transform.affine_inverse()*wrist_world,true)
	else:
		_solve_arm(rig,left_bones,poses,rig.global_transform.affine_inverse()*wrist_world,true)
	_update_slide()

## True while the retention reload is driving the hands (not the chamber-only action).
func _retention_active() -> bool:
	if not retention_reload or _chamber_presentation or animation_player == null:
		return false
	return str(animation_player.assigned_animation).to_lower().contains("reload") and animation_player.is_playing()

## When the magazine leaves and enters, as a share of the reload, so the player's
## sounds and ammunition changes land on the visible moments.
func get_reload_events(_empty: bool) -> Dictionary:
	if not retention_reload:
		return {}
	return {"out": Retention.OUT_AT, "in": Retention.IN_AT, "bolt": Retention.BOLT_AT}

func _solve_arm(rig: Skeleton3D, bones: Array[int], poses: Array[Transform3D], target: Vector3, preserve_hand_orientation: bool = false) -> void:
	var shoulder := poses[0].origin
	var elbow := poses[2].origin
	var wrist := poses[4].origin
	var upper_length := shoulder.distance_to(elbow)
	var lower_length := elbow.distance_to(wrist)
	var distance := clampf(shoulder.distance_to(target), absf(upper_length-lower_length)+0.001, upper_length + lower_length - 0.001)
	var direction := (target - shoulder).normalized()
	var normal := (elbow - shoulder).cross(wrist - shoulder).normalized()
	if normal.length_squared() < 0.01:
		normal = Vector3.FORWARD
	var bend := normal.cross(direction).normalized()
	if bend.dot(elbow - shoulder) < 0.0:
		bend = -bend
	# AKANE's close magazine work folds the support arm much further than the
	# inherited SMG pose. Keep its elbow below/outside the camera rather than
	# selecting the upward solution of the otherwise valid two-bone triangle.
	# This changes the bend plane only: skin, bone lengths and wrist contacts stay.
	if weapon_key == "akane" and is_instance_valid(gameplay_camera):
		var clip := str(animation_player.assigned_animation).to_lower()
		if clip.contains("reload"):
			var phase := animation_player.current_animation_position / maxf(.001,animation_player.current_animation_length)
			var weight := smoothstep(0.0,.12,phase) * (1.0-smoothstep(.82,.98,phase))
			if _chamber_presentation: weight *= smoothstep(.60,.68,phase)
			var side := 0.5 if bones[4] == right_hand_bone else -0.5
			var preferred := rig.global_basis.inverse() * (gameplay_camera.global_basis * Vector3(side,-1.0,0.0))
			var pole := preferred - direction * preferred.dot(direction)
			if pole.length_squared() > 0.000001:
				pole = pole.normalized()
				# Rotate within the bend plane; a vector lerp can collapse when the
				# inherited and desired poles oppose each other.
				var angle := atan2(bend.cross(pole).dot(direction),clampf(bend.dot(pole),-1.0,1.0))
				bend = bend.rotated(direction,angle*weight).normalized()
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
	_release_candidate_ads_hold()
	if animation_player != null:
		animation_player.speed_scale = 1.0
		animation_player.play(equip_anim_name, 0.0)

func play_holster() -> void:
	_release_candidate_ads_hold()
	if animation_player != null:
		animation_player.speed_scale = 1.0
		var chosen := _find_animation_name(animation_player.get_animation_list(), ["unequip"], [])
		if not chosen.is_empty():
			animation_player.play(chosen, 0.06)

func play_reload(empty: bool) -> void:
	_release_candidate_ads_hold()
	magazine_exchange.begin(_magazine_inserted)
	_chamber_presentation = false
	_reload_started_without_mag = not _magazine_inserted
	_reload_empty = empty
	_reload_duration = get_reload_duration(empty)
	var chosen := empty_reload_anim_name if empty else reload_anim_name
	animation_player.speed_scale = animation_player.get_animation(chosen).length / _reload_duration
	animation_player.play(chosen, 0.08)

func play_chamber(duration: float) -> void:
	_release_candidate_ads_hold()
	_chamber_presentation = true
	_reload_started_without_mag = false
	var clip_length := animation_player.get_animation(empty_reload_anim_name).length
	animation_player.speed_scale = clip_length * 0.40 / duration
	animation_player.play(empty_reload_anim_name, 0.04)
	animation_player.seek(clip_length * 0.60, true)

func get_reload_duration(empty: bool) -> float:
	return reload_empty_seconds if empty else reload_partial_seconds

func _on_animation_finished(animation_name: StringName) -> void:
	if str(animation_name).to_lower().contains("reload"):
		_chamber_presentation = false
		_reload_started_without_mag = false
	animation_player.speed_scale = 1.0
	super._on_animation_finished(animation_name)

func is_ready_for_input() -> bool:
	var current := str(animation_player.current_animation).to_lower() if animation_player != null else ""
	return loaded and _fitted and not failed and not _presentation_hold and not current.contains("equip") and not current.contains("reload")

func _build_fire_effect() -> void:
	var muzzle: Node3D = assembly.get_node("Muzzle")
	_flash = MeshInstance3D.new()
	var sprite := QuadMesh.new()
	var span := .05 if weapon_key == "hibari_h9c" else .065
	sprite.size = Vector2(span,span)
	_flash.mesh = sprite
	_flash.position.z = -.025
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
	_slide_elapsed = 0.0
	_update_slide()
	_flash_timer = .035
	_flash_material.set_shader_parameter("shot_seed",randf_range(0.0,TAU))
	_flash_material.set_shader_parameter("life",1.0)
	_flash.visible = true
	_flash_light.light_energy = .85
	_eject_case()

func _eject_case() -> void:
	var case_mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = case_radius
	shape.bottom_radius = shape.top_radius
	shape.height = case_length
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

# Uses the actual assembly marker; required by the owner's bore-obstruction ray.
func get_muzzle_world_position() -> Vector3:
	if is_instance_valid(assembly):
		return assembly.get_node("Muzzle").global_position
	return global_position

# Physical iron/optic marks are tested in the gameplay camera frame. This is a
# settled-presentation check, not authority to fire or consume a cartridge.
func is_sight_aligned() -> bool:
	if not is_ready_for_input() or ads_blend < 0.95 or _bolt_locked:
		return false
	var ancestor := get_parent()
	while ancestor != null and not ancestor is Camera3D:
		ancestor = ancestor.get_parent()
	var camera := ancestor as Camera3D
	if camera == null:
		return false
	var rear_world: Vector3 = assembly.get_node("IronRearSight").global_position
	var front_world: Vector3 = assembly.get_node("IronFrontSight").global_position
	if is_instance_valid(optic_model):
		rear_world = optic_model.get_node("RearSight").global_position
		front_world = optic_model.get_node("FrontSight").global_position
	var rear := camera.to_local(rear_world)
	var front := camera.to_local(front_world)
	var axis := (front - rear).normalized()
	return front.z < rear.z and rear.z < 0.0 and Vector2(rear.x, rear.y).length() < 0.001 and axis.angle_to(Vector3.FORWARD) < deg_to_rad(0.15)

# Supports the owner's newer UZI base without requiring that field on older
# production bases. A reload or equip must release a paused ADS idle clip.
func _release_candidate_ads_hold() -> void:
	for property: Dictionary in get_property_list():
		if str(property.name) == "_ads_idle_held":
			set("_ads_idle_held", false)
			break

# Owner must call this after shots, loadout restoration, magazine changes, and
# chamber events. It is presentation state only and never creates ammunition.
func set_bolt_locked(value: bool) -> void:
	_bolt_locked = value
	_update_slide()

func _update_slide() -> void:
	if not _fitted or not is_instance_valid(slide_mesh):
		return
	var cycle := clampf(_slide_elapsed / maxf(slide_cycle_seconds, 0.001), 0.0, 1.0)
	var travel := sin(cycle * PI)
	if _bolt_locked:
		travel = maxf(travel, smoothstep(0.0, 0.35, cycle))
	slide_mesh.global_transform = assembly.global_transform * slide_rest
	slide_mesh.global_position += assembly.global_basis * Vector3(slide_travel * travel, 0, 0)
	# The optional compact reflex uses the slide's mounting plate.
	optic_socket.transform = optic_socket_rest
	optic_socket.position.x += slide_travel * travel
	if is_instance_valid(trigger_mesh):
		trigger_mesh.global_transform = assembly.global_transform * trigger_rest
		trigger_mesh.global_position += assembly.global_basis * Vector3(0.0025 * sin(cycle * PI), 0, 0)

# Alias is useful for non-player preview drivers; live player calls play_fire.
func play_shoot() -> void:
	play_fire()

func cancel_action() -> void:
	_release_candidate_ads_hold()
	magazine_exchange.update(0.0, false, _magazine_inserted, false)
	if animation_player != null and loaded:
		animation_player.speed_scale = 1.0
		animation_player.play(idle_anim_name, 0.0)
	_chamber_presentation = false
	_rig_motion = Transform3D.IDENTITY
	if is_instance_valid(imported_root):
		imported_root.transform = _rig_base_transform
	_update_slide()
