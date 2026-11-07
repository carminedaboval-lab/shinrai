extends "res://scripts/uzi_viewmodel.gd"

const Catalog = preload("res://scripts/extraction_weapon_catalog.gd")
const PoseModifier = preload("res://scripts/extraction_weapon_pose.gd")
const Reticle = preload("res://assets/weapons/optics/reflex_reticle.gdshader")
const PrismReticle = preload("res://assets/weapons/optics/prism_reticle.gdshader")
const PrismView = preload("res://scripts/extraction_prism_scope_view.gd")
const MuzzleFlash = preload("res://assets/weapons/effects/muzzle_flash.gdshader")
const Presentation = preload("res://scripts/extraction_weapon_presentation.gd")
@export var weapon_key := "shigure"
@export var assembly_scene: PackedScene
@export var magazine_grip := Vector3(-.066,-.085,0)
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
@export var optic_id := "reflex_01"
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
var _cases: Array[Dictionary] = []
var _rig_base_transform := Transform3D.IDENTITY
var _rig_motion := Transform3D.IDENTITY
var _chamber_presentation := false
var _backup_iron_sights: Node3D

func set_magazine_inserted(value: bool) -> void:
	_magazine_inserted = value
	if is_instance_valid(magazine_mesh):
		var clip := str(animation_player.current_animation).to_lower()
		magazine_mesh.visible = value or clip.contains("reload")

func hold_presentation(value: bool) -> void:
	_presentation_hold = value
	visible = loaded and _fitted and not value

func _process(delta: float) -> void:
	super._process(delta)
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
	assembly.basis = Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE / MODEL_SCALE)
	var palm_world := skeleton.global_transform * skeleton.get_bone_global_pose(right_hand_bone).origin
	var palm_model := imported_root.to_local(palm_world)
	assembly.position = palm_model - assembly.basis * assembly.get_node("GripRight").position
	optic_socket = assembly.get_node("OpticSocket")
	magazine_mesh = assembly.find_child("Shigure_Magazine", true, false) as Node3D
	if magazine_mesh == null:
		magazine_mesh = assembly.find_child("Kite_Magazine", true, false) as Node3D
	if magazine_mesh == null:
		_fail("Separate moving magazine is unavailable")
		return
	magazine_mesh = magazine_exchange.wrap(magazine_mesh)
	magazine_rest = assembly.global_transform.affine_inverse() * magazine_mesh.global_transform
	body_fit = (skeleton.global_transform * skeleton.get_bone_global_pose(body_bone)).affine_inverse() * assembly.global_transform
	assembly_reference = global_transform.affine_inverse() * assembly.global_transform
	magazine_reference = skeleton.get_bone_global_pose(body_bone).affine_inverse() * skeleton.get_bone_global_pose(magazine_bone)
	_prepare_imported_nodes(assembly)
	_fitted = true
	_rig_base_transform = imported_root.transform
	_build_backup_iron_sights()
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
	optic_id = id
	if not _fitted:
		return true
	if is_instance_valid(_backup_iron_sights):
		_backup_iron_sights.visible = id.is_empty()
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
		optic_model = (load(Catalog.OPTICS[id].scene) as PackedScene).instantiate() as Node3D
		optic_socket.add_child(optic_model)
		_prepare_imported_nodes(optic_model)
		for mesh: MeshInstance3D in optic_model.find_children("*", "MeshInstance3D", true, false):
			if str(mesh.name).contains("OpticGlass"):
				if str(mesh.name).contains("Rear"):
					reticle_material = ShaderMaterial.new()
					reticle_material.shader = PrismReticle if id == "prism_01" else Reticle
					if id == "prism_01":
						reticle_material.set_shader_parameter("eye_relief_m",get_ads_eye_relief())
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
	# Magnified prism has a finite eye box; a reflex allows a longer relief.
	if optic_id == "prism_01": return 0.115
	if optic_id == "reflex_01": return 0.17
	# Irons: the catalogue's per-gun eye position (peep sights sit close to the eye).
	return float(Catalog.WEAPONS.get(weapon_key, {}).get("iron_eye_relief_m", 0.205))

func get_muzzle_world_position() -> Vector3:
	if is_instance_valid(assembly):
		return assembly.get_node("Muzzle").global_position
	return super.get_muzzle_world_position()

func get_sight_world_points() -> PackedVector3Array:
	if is_instance_valid(optic_model):
		return PackedVector3Array([optic_model.get_node("RearSight").global_position,optic_model.get_node("FrontSight").global_position])
	if is_instance_valid(assembly):
		return PackedVector3Array([assembly.get_node("IronRearSight").global_position,assembly.get_node("IronFrontSight").global_position])
	return super.get_sight_world_points()

func _build_backup_iron_sights() -> void:
	# Real-counterpart assemblies model their own sights at the marker heights;
	# hide them with an optic exactly like the generated backup pair.
	var authored := assembly.get_node_or_null("Geometry/IronSights") as Node3D
	if authored != null:
		_backup_iron_sights = authored
		return
	# The supplied receivers had a rail edge in place of a usable rear sight.
	# Compact folding sights use the same physical marks as the ADS solver.
	_backup_iron_sights = Node3D.new()
	_backup_iron_sights.name = "CalibratedBackupIronSights"
	assembly.add_child(_backup_iron_sights)
	# Lift the aiming line above the supplied receiver crest. Merely placing
	# a new post at its old rail-edge marker left the post buried in the mesh.
	assembly.get_node("IronRearSight").position.y += .012
	assembly.get_node("IronFrontSight").position.y += .012
	var rear: Vector3 = assembly.get_node("IronRearSight").position
	var front: Vector3 = assembly.get_node("IronFrontSight").position
	var sight_basis := Basis.looking_at((front-rear).normalized(), Vector3.UP)
	var finish := StandardMaterial3D.new()
	finish.albedo_color = Color(0.045, 0.052, 0.058)
	finish.metallic = 0.72
	finish.roughness = 0.38
	for is_rear: bool in [true, false]:
		var frame := Node3D.new()
		frame.name = "RearNotch" if is_rear else "FrontPost"
		frame.transform = Transform3D(sight_basis,rear if is_rear else front)
		_backup_iron_sights.add_child(frame)
		_sight_part(frame,Vector3(.018,.005,.012),Vector3(0,-.0185,0),finish)
		_sight_part(frame,Vector3(.008,.010,.007),Vector3(0,-.012,0),finish)
		_sight_part(frame,Vector3(.024,.003,.009),Vector3(0,-.0055 if is_rear else -.010,0),finish)
		if is_rear:
			# The front post tip is flush with the rear notch shoulders.
			for side: float in [-1.0, 1.0]:
				_sight_part(frame,Vector3(.005,.010,.006),Vector3(side*.0085,-.005,0),finish)
		else:
			_sight_part(frame,Vector3(.003,.009,.004),Vector3(0,-.0045,0),finish)
			for side: float in [-1.0, 1.0]:
				_sight_part(frame,Vector3(.003,.015,.005),Vector3(side*.010,-.0025,0),finish)
	_prepare_imported_nodes(_backup_iron_sights)

func _sight_part(parent: Node3D, size: Vector3, offset: Vector3, finish: Material) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = offset
	mesh.material_override = finish
	parent.add_child(mesh)

func _update_sight_alignment() -> void:
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
	if current_clip.contains("reload"):
		var duration := animation_player.get_animation(animation_player.assigned_animation).length
		ratio = animation_player.current_animation_position / duration
		_rig_motion = Presentation.pose(weapon_key,current_clip.contains("empty"),ratio)
		if _chamber_presentation:
			_rig_motion = Transform3D.IDENTITY.interpolate_with(_rig_motion,smoothstep(.60,.65,ratio))
	else:
		_rig_motion = _rig_motion.interpolate_with(Transform3D.IDENTITY,1.0-exp(-28.0*delta)) if delta>0 else Transform3D.IDENTITY
	imported_root.transform = _rig_motion * _rig_base_transform
	var body_pose := rig.get_bone_global_pose(body_bone)
	var magazine_pose := rig.get_bone_global_pose(magazine_bone)
	assembly.global_transform = rig.global_transform * body_pose * body_fit
	var delta_mag := (body_pose.affine_inverse() * magazine_pose) * magazine_reference.affine_inverse()
	var body_world := rig.global_transform * body_pose
	magazine_mesh.global_transform = body_world * delta_mag * body_world.affine_inverse() * assembly.global_transform * magazine_rest
	var magazine_turn := Basis.IDENTITY
	if current_clip.contains("reload") and not _chamber_presentation:
		magazine_mesh.global_position += global_basis * Presentation.magazine_arc(weapon_key,current_clip.contains("empty"),ratio)
		# Present the broad side while detached, then return to the source
		# alignment before seating. Rotate about the grasp, keeping it attached.
		var show_mag := Presentation.magazine_display(weapon_key,current_clip.contains("empty"),ratio)
		var source_basis := magazine_mesh.global_basis
		var display_basis := global_basis * Basis.from_euler(Vector3(deg_to_rad(-10),deg_to_rad(8),deg_to_rad(12 if weapon_key=="kite" else -18)))
		var grip_before := magazine_mesh.to_global(magazine_grip)
		magazine_mesh.global_basis = Basis(source_basis.get_rotation_quaternion().slerp(display_basis.get_rotation_quaternion(),show_mag)).scaled(source_basis.get_scale())
		magazine_mesh.global_position = grip_before-magazine_mesh.global_basis*magazine_grip
		magazine_turn = rig.global_basis.inverse()*magazine_mesh.global_basis*source_basis.inverse()*rig.global_basis
	if reticle_material != null and is_instance_valid(optic_model):
		reticle_material.set_shader_parameter("sight_axis", optic_model.global_basis.z.normalized())
		if is_instance_valid(prism_view) and is_instance_valid(gameplay_camera):
			prism_view.sync(gameplay_camera,optic_model.get_node("RearSight").global_position,optic_model.global_basis.z.normalized(),optic_model.global_basis.y.normalized(),ads_blend>.05 and is_visible_in_tree(),3.0)
	var poses: Array[Transform3D] = []
	for id: int in left_bones:
		poses.append(rig.get_bone_global_pose(id))
	var right_poses: Array[Transform3D] = []
	for id: int in right_bones: right_poses.append(rig.get_bone_global_pose(id))
	var right_palm_offset := rig.global_basis*right_poses[4].basis*RIGHT_PALM_CONTACT
	var right_target: Vector3 = assembly.get_node("GripRight").global_position-right_palm_offset
	_solve_arm(rig,right_bones,right_poses,rig.global_transform.affine_inverse()*right_target,true)
	var desired_world: Vector3 = assembly.get_node("GripLeft").global_position
	magazine_mesh.visible = _magazine_inserted or current_clip.contains("reload")
	magazine_exchange.update(ratio,current_clip.contains("reload") and not _chamber_presentation,_magazine_inserted,current_clip.contains("empty"))
	var grasp := 0.0
	var magazine_grasp := 0.0
	var bolt_grasp := 0.0
	var grip_return := 0.0
	var contact_world := desired_world
	var free_wrist_world := desired_world
	if current_clip.contains("reload"):
		var source_wrist := rig.global_transform*poses[4].origin
		var anticipation := smoothstep(0.0,.045 if current_clip.contains("empty") else .065,ratio)
		grip_return = Presentation.support_return(current_clip.contains("empty"),ratio)
		free_wrist_world = desired_world.lerp(source_wrist,anticipation).lerp(desired_world,grip_return)
		desired_world = free_wrist_world
		var new_grip := magazine_mesh.to_global(magazine_grip)
		var weight := Presentation.magazine_grasp(weapon_key,current_clip.contains("empty"),ratio)*(1.0-grip_return)
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
			var bolt_press := Presentation.bolt_press(weapon_key,ratio)
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
			solved.basis = Basis(solved.basis.get_rotation_quaternion().slerp((magazine_turn*poses[4].basis).get_rotation_quaternion(),magazine_grasp*(1.0 if weapon_key=="kite" else .85))).scaled(solved.basis.get_scale())
			rig.set_bone_global_pose(left_bones[4],solved)
			var palm_offset := rig.global_basis * solved.basis * LEFT_PALM_CONTACT
			var wrist_target: Vector3 = free_wrist_world.lerp(contact_world-palm_offset,grasp)
			_solve_arm(rig,left_bones,poses,rig.global_transform.affine_inverse()*wrist_target)
		var final_hand := rig.get_bone_global_pose(left_bones[4])
		final_hand.basis = Basis(final_hand.basis.get_rotation_quaternion().slerp((magazine_turn*poses[4].basis).get_rotation_quaternion(),magazine_grasp*(1.0 if weapon_key=="kite" else .85))).scaled(final_hand.basis.get_scale())
		rig.set_bone_global_pose(left_bones[4],final_hand)
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
	if animation_player != null:
		animation_player.speed_scale = 1.0
		animation_player.play(equip_anim_name, 0.0)

func play_holster() -> void:
	if animation_player != null:
		animation_player.speed_scale = 1.0
		var chosen := _find_animation_name(animation_player.get_animation_list(), ["unequip"], [])
		if not chosen.is_empty():
			animation_player.play(chosen, 0.06)

func play_reload(empty: bool) -> void:
	magazine_exchange.begin(_magazine_inserted)
	_chamber_presentation = false
	_reload_started_without_mag = not _magazine_inserted
	_reload_empty = empty
	_reload_duration = get_reload_duration(empty)
	var chosen := empty_reload_anim_name if empty else reload_anim_name
	animation_player.speed_scale = animation_player.get_animation(chosen).length / _reload_duration
	animation_player.play(chosen, 0.08)

func play_chamber(duration: float) -> void:
	_chamber_presentation = true
	_reload_started_without_mag = false
	var clip_length := animation_player.get_animation(empty_reload_anim_name).length
	animation_player.speed_scale = clip_length * 0.40 / duration
	animation_player.play(empty_reload_anim_name, 0.04)
	animation_player.seek(clip_length * 0.60, true)

func get_reload_duration(empty: bool) -> float:
	return float(Catalog.WEAPONS[weapon_key].reload_empty if empty else Catalog.WEAPONS[weapon_key].reload_partial)

func _on_animation_finished(animation_name: StringName) -> void:
	animation_player.speed_scale = 1.0
	super._on_animation_finished(animation_name)

func is_ready_for_input() -> bool:
	var current := str(animation_player.current_animation).to_lower() if animation_player != null else ""
	return loaded and _fitted and not failed and not _presentation_hold and not current.contains("equip") and not current.contains("reload")

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
	_flash_timer = .035
	_flash_material.set_shader_parameter("shot_seed",randf_range(0.0,TAU))
	_flash_material.set_shader_parameter("life",1.0)
	_flash.visible = true
	_flash_light.light_energy = .85
	_eject_case()

func _eject_case() -> void:
	var case_mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = .0048 if weapon_key == "shigure" else .006
	shape.bottom_radius = shape.top_radius
	shape.height = .019 if weapon_key == "shigure" else .051
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
