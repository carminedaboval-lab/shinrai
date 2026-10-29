extends Node3D
## Each crew member uses their own preserved Meshy mesh, materials and rig.
const Impact=preload("./scav_impact.gd")
const POSTURE_WEIGHTS: Array[float]=[.55,.30,.15]
const WEAPON=preload("res://assets/weapons/shigure/shigure_weapon.tscn")
const GRASP={
	"Left":Basis(Vector3(.2225492,-.5583190,-.7992195),Vector3(-.9659967,-.0156133,-.2580825),Vector3(.1316139,.8294794,-.5428090)),
	"Right":Basis(Vector3(-.2420954,-.9548583,-.1721496),Vector3(-.9131085,.2842134,-.2923280),Vector3(.3280590,.0864200,-.9406959))}
class WeaponPose extends SkeletonModifier3D:
	var presentation: Node3D
	func _process_modification_with_delta(delta: float) -> void:
		if is_instance_valid(presentation): presentation.pose_weapon(delta)

var model_path: String
var model: Node3D
var actor: CharacterBody3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var weapon: Node3D
var muzzle: Marker3D
var clips: Dictionary={}
var current_state: String=""
var arms: Dictionary={}
var grip_errors: Dictionary={}
var torso_bone: int=-1
var torso_reference:=Transform3D.IDENTITY
var foot_bones: Array[int]=[]
var foot_reference: float=INF
var ready_for_use:=false
var dying:=false
var impact: SkeletonModifier3D
var search_blend:=0.0
var routine_blend:=0.0
var last_routine: String=""
var routine_errors: Dictionary={}
var head_bone: int=-1
var gaze_yaw:=0.0
var gaze_pitch:=0.0
var gaze_applied_angle:=0.0
var posture_before_lean:=0.0
var posture_after_lean:=0.0
var posture_applied_angle:=0.0
var posture_goal_lean:=0.0
var _posture_angle:=0.0
var _posture_bones: Array[int]=[]
var _posture_hips: int=-1
var _posture_neck: int=-1
var _pose_delta:=1.0/60.0
var _idle_leg_rig: Dictionary={}
var _idle_pelvis_lift:=0.0
var idle_leg_applied_lift:=0.0
var idle_leg_foot_error:=0.0
var idle_leg_length_error:=0.0
var idle_leg_flexion_before: Dictionary={}
var idle_leg_flexion_after: Dictionary={}
var _idle_sole_offsets: Dictionary={}
var _idle_sole_calibrated:=false
var _idle_support_blend:=0.0
var idle_leg_floor_hits:=0
var idle_sole_sample_counts: Dictionary={}
var _idle_sole_candidates: Dictionary={"Left":[],"Right":[]}
var _idle_sole_extremes: Dictionary={}
var _idle_sole_adjustments: Dictionary={}
var _idle_floor_targets: Dictionary={}
var idle_sole_skin_error: Dictionary={}

func _ready() -> void:
	actor=get_parent().get_parent() as CharacterBody3D
	# Preserve the original outfits; these derivatives sculpt their existing
	# bag panels and correct only the bag's attachment weights.
	var sculpt_path: String="res://assets/enemies/scavs/layered/"+str(actor.role)+"_body.glb"
	if FileAccess.file_exists(sculpt_path):model_path=sculpt_path
	if model_path.begins_with("res://"):
		var packed:=load(model_path) as PackedScene
		if packed!=null: model=packed.instantiate()
	else:
		var document:=GLTFDocument.new()
		var state:=GLTFState.new()
		if document.append_from_file(model_path,state,GLTFDocument.IMPORT_FLAG_GENERATE_TANGENT_ARRAYS)==OK: model=document.generate_scene(state)
	if model==null:
		push_error("SCAV_VISUAL: missing Meshy model "+model_path)
		return
	model.rotation.y=PI
	add_child(model)
	for node: Skeleton3D in model.find_children("*","Skeleton3D",true,false): skeleton=node; break
	for node: AnimationPlayer in model.find_children("*","AnimationPlayer",true,false): animator=node; break
	if skeleton==null or animator==null:
		push_error("SCAV_VISUAL: model must contain its humanoid rig and motions")
		return
	for i: int in range(skeleton.get_bone_count()):
		var label:=skeleton.get_bone_name(i)
		if label.ends_with("Foot") or label.ends_with("ToeBase"):
			foot_bones.append(i)
			foot_reference=minf(foot_reference,skeleton.get_bone_global_rest(i).origin.y)
	_prepare_clips()
	_prepare_weapon()
	impact=Impact.new();impact.name="BulletImpact";skeleton.add_child(impact);impact.setup(self)
	head_bone=_bone("Head")
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false): mesh.extra_cull_margin=1.5
	ready_for_use=clips.size()==5 and arms.size()==2
	if not ready_for_use: push_error("SCAV_VISUAL: incomplete animation or arm rig")

func _prepare_clips() -> void:
	var library:=AnimationLibrary.new()
	for state: String in ["idle","walk","run","crouch","death"]:
		var wanted: Array={"idle":["idle","combat_stance","combat_idle"],"walk":["walking"],"run":["running"],"crouch":["cautious_crouch_walk_forward","cautious_crouch_walk_forward_inplace"],"death":["dying_backwards"]}[state]
		for name: String in animator.get_animation_list():
			var normalized:=name.replace(" ","_").get_file().to_lower()
			if normalized not in wanted: continue
			var animation:=animator.get_animation(name).duplicate(true) as Animation
			for track: int in range(animation.get_track_count()):
				if animation.track_get_type(track)!=Animation.TYPE_POSITION_3D: continue
				if not String(animation.track_get_path(track)).ends_with("Hips"): continue
				for key: int in range(animation.track_get_key_count(track)):
					var point: Vector3=animation.track_get_key_value(track,key)
					point.x=0.0
					point.z=0.0
					animation.track_set_key_value(track,key,point)
			animation.loop_mode=Animation.LOOP_NONE if state=="death" else Animation.LOOP_LINEAR
			library.add_animation(state,animation)
			clips[state]="scav/"+state
			break
	animator.add_animation_library("scav",library)

func _bone(suffix: String) -> int:
	for i: int in range(skeleton.get_bone_count()):
		if skeleton.get_bone_name(i).ends_with(suffix): return i
	return -1

func _prepare_weapon() -> void:
	torso_bone=_bone("Spine2")
	if torso_bone<0: return
	torso_reference=skeleton.get_bone_global_rest(torso_bone)
	_posture_hips=_bone("Hips");_posture_neck=_bone("Neck")
	for suffix: String in ["Spine","Spine1","Spine2"]:
		var id:=_bone(suffix)
		if id>=0:_posture_bones.append(id)
	for side: String in ["Left","Right"]:
		var upper:=_bone(side+"Arm")
		var lower:=_bone(side+"ForeArm")
		var hand:=_bone(side+"Hand")
		var index:=_bone(side+"HandIndex1")
		var middle:=_bone(side+"HandMiddle1")
		var ring:=_bone(side+"HandRing1")
		if mini(mini(upper,lower),mini(hand,mini(index,mini(middle,ring))))<0: continue
		var rest:=skeleton.get_bone_global_rest(hand)
		var knuckles: Vector3=(skeleton.get_bone_global_rest(index).origin+skeleton.get_bone_global_rest(middle).origin)*.5
		var forward: Vector3=(knuckles-rest.origin).normalized()
		var across: Vector3=(skeleton.get_bone_global_rest(ring).origin-skeleton.get_bone_global_rest(index).origin).normalized()
		across=(across-forward*across.dot(forward)).normalized()
		var frame:=Basis(across,forward,across.cross(forward)).orthonormalized()
		arms[side]={"upper":upper,"lower":lower,"hand":hand,"palm_frame":rest.basis.inverse()*frame,"palm_offset":rest.affine_inverse()*(rest.origin+(knuckles-rest.origin)*.65),"upper_length":skeleton.get_bone_global_rest(upper).origin.distance_to(skeleton.get_bone_global_rest(lower).origin),"lower_length":skeleton.get_bone_global_rest(lower).origin.distance_to(rest.origin)}
	weapon=WEAPON.instantiate()
	weapon.name="ScavCarbine"
	model.add_child(weapon)
	muzzle=weapon.get_node("Muzzle") as Marker3D
	var modifier:=WeaponPose.new()
	modifier.presentation=self
	skeleton.add_child(modifier)

func _process(_delta: float) -> void:
	if not ready_for_use or dying: return
	var yaw:=0.0;var pitch:=0.0
	var casual: bool=actor.social_look_point.is_finite() and actor.state!=actor.AIState.COMBAT and not actor.surrendered and not actor.fleeing and head_bone>=0
	if casual:
		var offset: Vector3=skeleton.to_local(actor.social_look_point)-skeleton.get_bone_global_pose(head_bone).origin
		yaw=clampf(atan2(offset.x,offset.z),-.7,.7)
		pitch=clampf(-atan2(offset.y,Vector2(offset.x,offset.z).length()),-.22,.22)
	var gaze_rate:=4.0 if casual else 12.0
	gaze_yaw=lerpf(gaze_yaw,yaw,clampf(_delta*gaze_rate,0,1));gaze_pitch=lerpf(gaze_pitch,pitch,clampf(_delta*gaze_rate,0,1))
	search_blend=move_toward(search_blend,1.0 if actor.busy_search else 0.0,_delta*6.0)
	var personal: String=actor.routine
	var active: bool=personal in ["tie_boot","check_kit","stretch"] and actor.state!=actor.AIState.COMBAT
	if active:last_routine=personal
	routine_blend=move_toward(routine_blend,1.0 if active else 0.0,_delta*7.0)
	var speed:=Vector2(actor.velocity.x,actor.velocity.z).length()
	# Separation/acceleration can straddle 2 m/s; avoid repeatedly crossfading
	# the two very different locomotion silhouettes around that one threshold.
	var running: bool=speed>(1.8 if current_state=="run" else 2.15)
	var state: String="crouch" if actor.crouching else "run" if running else "walk" if speed>.12 else "idle"
	if not clips.has(state): state="walk"
	if state!=current_state:
		current_state=state
		animator.play(clips[state],.15)
	animator.speed_scale=clampf(speed/(2.8 if state=="run" else 1.45),.35,1.5) if state in ["walk","run"] else 1.0
	if state=="crouch":
		animator.speed_scale=clampf(speed/1.1,.35,1.5) if speed>.12 else 0.0
		if speed<=.12: animator.seek(animator.get_animation(clips[state]).length*.35,true)
	if speed<=.12 and state=="walk": animator.speed_scale=0.0
	var floor_y: float=INF
	var support_y: float=INF
	for bone: int in foot_bones:
		var height: float=skeleton.get_bone_global_pose(bone).origin.y
		floor_y=minf(floor_y,height)
		var label:=skeleton.get_bone_name(bone)
		if label.ends_with("RightFoot") or label.ends_with("RightToeBase"):support_y=minf(support_y,height)
	# The left boot is raised after AnimationPlayer. Ground the remaining right
	# foot, rather than calibrating against the planted foot in the base clip.
	if last_routine=="tie_boot" and routine_blend>0 and is_finite(support_y):floor_y=lerpf(floor_y,support_y,routine_blend)
	model.position.y=.015+foot_reference-floor_y if is_finite(floor_y) else .015

func _apply_standing_posture(delta: float) -> void:
	posture_applied_angle=0.0
	if _posture_hips<0 or _posture_neck<0 or _posture_bones.size()!=3:return
	var hips: Vector3=skeleton.get_bone_global_pose(_posture_hips).origin
	var neck: Vector3=skeleton.get_bone_global_pose(_posture_neck).origin
	posture_before_lean=atan2(neck.z-hips.z,neck.y-hips.y)
	posture_after_lean=posture_before_lean
	# Preserve authored crouching, searching, gestures and morale poses. Walking
	# is already upright; only the shared combat-stance idle needs correction.
	var allowed: bool=not actor.crouching and not actor.busy_search and search_blend<.001 and routine_blend<.001 and not actor.surrendered and not actor.fleeing
	var eligible: bool=current_state=="idle" and allowed
	var alert: bool=actor.state in [actor.AIState.ALERT,actor.AIState.COMBAT,actor.AIState.SEARCH]
	if is_instance_valid(actor.squad):alert=alert or actor.squad.hostile or actor.squad.warning_active
	posture_goal_lean=deg_to_rad(9.0 if alert else 4.0)
	# Distributed joint rotations affect the trunk direction less than their sum.
	# Bound the total to 20 degrees (largest individual joint <=11 degrees).
	var needed: float=clampf((posture_goal_lean-posture_before_lean)*1.7,-deg_to_rad(20.0),0.0) if eligible else 0.0
	_posture_angle=move_toward(_posture_angle,needed,maxf(delta,0.0)*deg_to_rad(55.0))
	if not allowed:return
	# Fade the previous idle correction through the locomotion crossfade, but
	# never counter-rotate an already upright walking frame past the goal.
	var limit: float=minf(0.0,(posture_goal_lean-posture_before_lean)*1.7)
	var angle: float=maxf(_posture_angle,limit)
	if is_zero_approx(angle):return
	for index: int in range(_posture_bones.size()):
		var id: int=_posture_bones[index]
		var pose:=skeleton.get_bone_global_pose(id)
		# Rotation only: leave each bone's local translation/length untouched.
		pose.basis=Basis(Vector3.RIGHT,angle*POSTURE_WEIGHTS[index])*pose.basis
		skeleton.set_bone_global_pose(id,pose)
	posture_applied_angle=angle
	neck=skeleton.get_bone_global_pose(_posture_neck).origin
	posture_after_lean=atan2(neck.z-hips.z,neck.y-hips.y)

func _prepare_idle_leg_rig() -> bool:
	if _idle_leg_rig.size()==2:return true
	for side: String in ["Left","Right"]:
		var upper:=_bone(side+"UpLeg");var lower:=_bone(side+"Leg");var foot:=_bone(side+"Foot")
		if mini(upper,mini(lower,foot))<0:return false
		var hip: Vector3=skeleton.get_bone_global_rest(upper).origin
		var knee: Vector3=skeleton.get_bone_global_rest(lower).origin
		var ankle: Vector3=skeleton.get_bone_global_rest(foot).origin
		_idle_leg_rig[side]={"upper":upper,"lower":lower,"foot":foot,"thigh":hip.distance_to(knee),"shin":knee.distance_to(ankle)}
	return _idle_leg_rig.size()==2

func _calibrate_idle_soles() -> void:
	if _idle_sole_calibrated:return
	_idle_sole_calibrated=true
	var candidates: Dictionary={"Left":[],"Right":[]}
	for source: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if source.skin==null or source.mesh==null:continue
		var bind_side: Dictionary={}
		var bind_bones: Dictionary={}
		for bind: int in range(source.skin.get_bind_count()):
			var name: String=String(source.skin.get_bind_name(bind))
			if name.is_empty():
				var bone: int=source.skin.get_bind_bone(bind)
				if bone>=0 and bone<skeleton.get_bone_count():name=skeleton.get_bone_name(bone)
			var resolved: int=skeleton.find_bone(name)
			if resolved>=0:bind_bones[bind]=resolved
			for side: String in ["Left","Right"]:
				if side+"Foot" in name or side+"Toe" in name:bind_side[bind]=side
		if bind_side.is_empty():continue
		var to_rig: Transform3D=skeleton.global_transform.affine_inverse()*source.global_transform
		for surface: int in range(source.mesh.get_surface_count()):
			var arrays: Array=source.mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_VERTEX]==null or arrays[Mesh.ARRAY_BONES]==null or arrays[Mesh.ARRAY_WEIGHTS]==null:continue
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or bones.is_empty() or weights.size()!=bones.size():continue
			var influences: int=int(bones.size()/vertices.size())
			for vertex: int in range(vertices.size()):
				var at: Vector3=to_rig*vertices[vertex]
				if at.y>.20:continue
				var totals: Dictionary={"Left":0.0,"Right":0.0}
				for influence: int in range(influences):
					var index: int=vertex*influences+influence
					if bind_side.has(bones[index]):totals[bind_side[bones[index]]]+=weights[index]
				for side: String in ["Left","Right"]:
					if float(totals[side])<=.60:continue
					candidates[side].append(at)
					var sample: Dictionary={"rest":at,"influences":[]}
					for influence: int in range(influences):
						var index: int=vertex*influences+influence
						var slot: int=bones[index]
						if not bind_bones.has(slot) or weights[index]<=0.0:continue
						sample.influences.append({"bone":bind_bones[slot],"point":source.skin.get_bind_pose(slot)*vertices[vertex],"weight":weights[index]})
					_idle_sole_candidates[side].append(sample)
	for side: String in ["Left","Right"]:
		var points: Array=candidates[side]
		idle_sole_sample_counts[side]=points.size()
		if points.is_empty():continue
		var minimum:=INF
		for at: Vector3 in points:minimum=minf(minimum,at.y)
		var sole:=Vector3.ZERO;var count:=0
		for at: Vector3 in points:
			if at.y<=minimum+.003:sole+=at;count+=1
		sole/=maxi(count,1)
		sole.y=minimum
		var leg: Dictionary=_idle_leg_rig[side]
		var rest:=skeleton.get_bone_global_rest(leg.foot)
		_idle_sole_offsets[side]=rest.affine_inverse()*sole

func _idle_skinned_sole_point(sample: Dictionary) -> Vector3:
	var at:=Vector3.ZERO
	for influence: Dictionary in sample.influences:
		at+=skeleton.get_bone_global_pose(int(influence.bone))*(influence.point as Vector3)*float(influence.weight)
	return skeleton.to_global(at)

func _pick_idle_sole_extremes(side: String) -> void:
	if _idle_sole_extremes.has(side):return
	var candidates: Array=_idle_sole_candidates.get(side,[])
	if candidates.is_empty():return
	var ranked: Array[Dictionary]=[]
	var min_x:=INF;var max_x:=-INF;var min_z:=INF;var max_z:=-INF
	for index: int in range(candidates.size()):
		var sample: Dictionary=candidates[index]
		ranked.append({"index":index,"height":_idle_skinned_sole_point(sample).y})
		var at: Vector3=sample.rest
		min_x=minf(min_x,at.x);max_x=maxf(max_x,at.x);min_z=minf(min_z,at.z);max_z=maxf(max_z,at.z)
	ranked.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return float(a.height)<float(b.height))
	var selected: Dictionary={}
	for index: int in range(mini(12,ranked.size())):selected[int(ranked[index].index)]=true
	# Twelve spatial bottom cells retain heel/toe/outer-sole extremes as idle
	# weight shifts. Pick from exact current skinned points, not a Foot-only proxy.
	var cells: Dictionary={}
	for row: Dictionary in ranked:
		var index: int=row.index;var at: Vector3=candidates[index].rest
		var x: int=clampi(int((at.x-min_x)/maxf(max_x-min_x,.0001)*3.0),0,2)
		var z: int=clampi(int((at.z-min_z)/maxf(max_z-min_z,.0001)*4.0),0,3)
		var key: int=x+z*3
		if not cells.has(key):cells[key]=index
	for index: int in cells.values():selected[index]=true
	var samples: Array[Dictionary]=[]
	for index: int in selected:samples.append(candidates[index])
	_idle_sole_extremes[side]=samples
	_idle_sole_candidates.erase(side)

func _solve_idle_support_leg(side: String, original: Dictionary, target: Transform3D) -> void:
	var leg: Dictionary=_idle_leg_rig[side]
	var upper: Transform3D=original.upper;var lower: Transform3D=original.lower;var foot: Transform3D=original.foot
	upper.origin=skeleton.get_bone_global_pose(leg.upper).origin
	var offset: Vector3=target.origin-upper.origin
	var direction:=offset.normalized()
	var a: float=leg.thigh;var b: float=leg.shin
	var reach: float=clampf(offset.length(),absf(a-b)+.001,a+b-.012)
	var authored: Vector3=(original.lower as Transform3D).origin-(original.upper as Transform3D).origin
	var bend: Vector3=authored-direction*authored.dot(direction)
	if bend.length_squared()<.00001:bend=upper.basis.z-direction*upper.basis.z.dot(direction)
	bend=bend.normalized()
	var along: float=(a*a-b*b+reach*reach)/(2.0*reach)
	var knee: Vector3=upper.origin+direction*along+bend*sqrt(maxf(0.0,a*a-along*along))
	var ankle: Vector3=upper.origin+direction*reach
	var upper_turn:=Basis(Quaternion(authored.normalized(),(knee-upper.origin).normalized()))
	var lower_turn:=Basis(Quaternion((foot.origin-lower.origin).normalized(),(ankle-knee).normalized()))
	skeleton.set_bone_global_pose(leg.upper,Transform3D(upper_turn*upper.basis,upper.origin))
	skeleton.set_bone_global_pose(leg.lower,Transform3D(lower_turn*lower.basis,knee))
	skeleton.set_bone_global_pose(leg.foot,Transform3D(target.basis,ankle))
	idle_leg_foot_error=maxf(idle_leg_foot_error,ankle.distance_to(target.origin))
	idle_leg_length_error=maxf(idle_leg_length_error,maxf(absf(upper.origin.distance_to(knee)-a),absf(knee.distance_to(ankle)-b)))
	idle_leg_flexion_after[side]=(knee-upper.origin).angle_to(ankle-knee)

func _idle_foot_target(side: String, authored: Transform3D, weight: float) -> Transform3D:
	if weight<=0.0 or not _idle_sole_offsets.has(side) or not actor.is_on_floor():return authored
	var leg: Dictionary=_idle_leg_rig[side]
	var rest:=skeleton.get_bone_global_rest(leg.foot)
	var toe: int=_bone(side+"ToeBase")
	if toe<0:return authored
	var rest_forward: Vector3=skeleton.get_bone_global_rest(toe).origin-rest.origin
	var local_forward: Vector3=rest.basis.inverse()*rest_forward
	var forward: Vector3=authored.basis*local_forward
	var yaw: float=atan2(forward.x,forward.z)-atan2(rest_forward.x,rest_forward.z)
	var level: Basis=Basis(Vector3.UP,yaw)*rest.basis
	var sole: Vector3=authored.origin+level*(_idle_sole_offsets[side] as Vector3)
	var world: Vector3=skeleton.to_global(sole)
	var query:=PhysicsRayQueryParameters3D.create(world+Vector3.UP*.45,world-Vector3.UP*.55,1)
	query.exclude=[actor.get_rid()]
	var floor_hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
	if floor_hit.is_empty() or floor_hit.normal.y<.72:return authored
	idle_leg_floor_hits+=1
	_idle_floor_targets[side]=float(floor_hit.position.y)+.002
	var goal:=authored
	goal.basis=authored.basis.slerp(level,weight)
	var floor_local: Vector3=skeleton.to_local(floor_hit.position+Vector3.UP*.002)
	# Keep each authored horizontal placement/yaw; correct the actual sole height.
	var target_y: float=floor_local.y-(goal.basis*(_idle_sole_offsets[side] as Vector3)).y
	goal.origin.y=lerpf(authored.origin.y,clampf(target_y,authored.origin.y-.065,authored.origin.y+.065),weight)
	goal.origin.y+=float(_idle_sole_adjustments.get(side,0.0))*weight
	return goal

func _apply_relaxed_idle_legs(delta: float) -> void:
	idle_leg_applied_lift=0.0;idle_leg_foot_error=0.0;idle_leg_length_error=0.0
	idle_leg_floor_hits=0
	_idle_floor_targets.clear();idle_sole_skin_error.clear()
	idle_leg_flexion_before.clear();idle_leg_flexion_after.clear()
	if _posture_hips<0 or not _prepare_idle_leg_rig():return
	_calibrate_idle_soles()
	# Keep combat's lowered pelvis while grounding standing boots. Deliberate
	# crouches, searches, gestures and balance reactions retain authored poses.
	var alert: bool=actor.state in [actor.AIState.ALERT,actor.AIState.COMBAT,actor.AIState.SEARCH]
	if is_instance_valid(actor.squad):alert=alert or actor.squad.hostile or actor.squad.warning_active
	var excluded: bool=actor.crouching or actor.busy_search or search_blend>.001 or routine_blend>.001 or actor.surrendered or actor.fleeing
	if impact!=null and impact.ready_for_use:excluded=excluded or impact.balance.active() or not impact.springs.is_empty()
	if excluded:
		_idle_pelvis_lift=0.0
		_idle_support_blend=0.0
		_idle_sole_adjustments.clear()
		return
	_idle_support_blend=move_toward(_idle_support_blend,1.0 if current_state=="idle" and actor.is_on_floor() else 0.0,maxf(delta,0.0)*3.0)
	var support_weight: float=clampf((_idle_support_blend-.5)*2.0,0.0,1.0)
	var feet: Dictionary={};var animated_legs: Dictionary={}
	var feasible_lift:=.060
	for side: String in _idle_leg_rig:
		var leg: Dictionary=_idle_leg_rig[side]
		var upper:=skeleton.get_bone_global_pose(leg.upper)
		var lower:=skeleton.get_bone_global_pose(leg.lower)
		var foot:=skeleton.get_bone_global_pose(leg.foot)
		var target: Transform3D=_idle_foot_target(side,foot,support_weight)
		var target_horizontal: Vector3=upper.origin-target.origin;target_horizontal.y=0.0
		var safe_reach: float=leg.thigh+leg.shin-.012
		# A nearly straight transition leg may not reach a lower floor target.
		# Keep its X/Z and stop short of the floor rather than stretch the limb.
		var minimum_y: float=upper.origin.y-sqrt(maxf(0.0,safe_reach*safe_reach-target_horizontal.length_squared()))
		target.origin.y=maxf(target.origin.y,minimum_y)
		feet[side]=target
		animated_legs[side]={"upper":upper,"lower":lower,"foot":foot}
		idle_leg_flexion_before[side]=(lower.origin-upper.origin).angle_to(foot.origin-lower.origin)
		var horizontal: Vector3=upper.origin-target.origin;horizontal.y=0.0
		# Preserve a 12 mm reach reserve: never straighten a knee to its singularity.
		var reach: float=leg.thigh+leg.shin-.012
		var available: float=sqrt(maxf(0.0,reach*reach-horizontal.length_squared()))-(upper.origin.y-target.origin.y)
		feasible_lift=minf(feasible_lift,maxf(0.0,available))
	var wanted: float=feasible_lift if current_state=="idle" and actor.is_on_floor() and not alert else 0.0
	_idle_pelvis_lift=move_toward(_idle_pelvis_lift,wanted,maxf(delta,0.0)*.20)
	var lift: float=minf(_idle_pelvis_lift,feasible_lift)
	if lift<=.00001 and support_weight<=.00001:return
	var pelvis:=skeleton.get_bone_global_pose(_posture_hips)
	pelvis.origin.y+=lift
	skeleton.set_bone_global_pose(_posture_hips,pelvis)
	for side: String in _idle_leg_rig:
		_solve_idle_support_leg(side,animated_legs[side],feet[side])
	if support_weight>.95 and current_state=="idle":
		for side: String in _idle_leg_rig:
			if not _idle_floor_targets.has(side):continue
			_pick_idle_sole_extremes(side)
			var samples: Array=_idle_sole_extremes.get(side,[])
			if samples.is_empty():continue
			for iteration: int in range(2):
				var minimum:=INF
				for sample: Dictionary in samples:minimum=minf(minimum,_idle_skinned_sole_point(sample).y)
				var error: float=float(_idle_floor_targets[side])-minimum
				idle_sole_skin_error[side]=error
				if absf(error)<.001:break
				var adjustment: float=clampf(error,-.025,.025)
				var target: Transform3D=feet[side]
				var previous_y: float=target.origin.y
				var leg: Dictionary=_idle_leg_rig[side]
				var hip: Vector3=skeleton.get_bone_global_pose(leg.upper).origin
				var horizontal: Vector3=hip-target.origin;horizontal.y=0.0
				var safe_reach: float=leg.thigh+leg.shin-.012
				var minimum_y: float=hip.y-sqrt(maxf(0.0,safe_reach*safe_reach-horizontal.length_squared()))
				var old_adjustment: float=_idle_sole_adjustments.get(side,0.0)
				var new_adjustment: float=clampf(old_adjustment+adjustment,-.060,.060)
				target.origin.y=maxf(minimum_y,target.origin.y+new_adjustment-old_adjustment)
				_idle_sole_adjustments[side]=clampf(old_adjustment+target.origin.y-previous_y,-.060,.060)
				feet[side]=target
				_solve_idle_support_leg(side,animated_legs[side],target)
			var final_minimum:=INF
			for sample: Dictionary in samples:final_minimum=minf(final_minimum,_idle_skinned_sole_point(sample).y)
			idle_sole_skin_error[side]=float(_idle_floor_targets[side])-final_minimum
	idle_leg_applied_lift=lift

func pose_weapon(frame_delta: float=1.0/60.0) -> void:
	if dying or weapon==null or arms.size()!=2: return
	_pose_delta=clampf(frame_delta,0.0,.1)
	_apply_relaxed_idle_legs(_pose_delta)
	_apply_standing_posture(_pose_delta)
	if head_bone>=0:
		var head:=skeleton.get_bone_global_pose(head_bone)
		var before:=head.basis.get_rotation_quaternion()
		head.basis=Basis.from_euler(Vector3(gaze_pitch,gaze_yaw,0))*head.basis
		skeleton.set_bone_global_pose(head_bone,head)
		# SkeletonModifier poses are restored after skinning. Measure the actual
		# applied transform here, while the temporary head pose is in effect.
		gaze_applied_angle=before.angle_to(skeleton.get_bone_global_pose(head_bone).basis.get_rotation_quaternion())
	if actor.surrendered:
		weapon.visible=false
		for side: String in arms:
			var arm: Dictionary=arms[side]
			var hand:=skeleton.get_bone_global_pose(arm.hand)
			_solve_arm(arm,Vector3(.32 if side=="Left" else -.32,1.65,.05),hand.basis,side)
		return
	weapon.visible=true
	var time:=Time.get_ticks_msec()*.001
	if routine_blend>0 and last_routine=="tie_boot":
		_raise_boot(routine_blend)
		var spine:=_bone("Spine")
		if spine>=0:
			var pose:=skeleton.get_bone_global_pose(spine)
			pose.basis=Basis(Vector3.RIGHT,routine_blend*.6)*pose.basis
			skeleton.set_bone_global_pose(spine,pose)
	var aiming: bool=actor.state==actor.AIState.COMBAT and is_instance_valid(actor.target)
	var pitch:=lerpf(.26,.85,search_blend)
	var yaw:=0.0
	if aiming:
		var contact: Vector3=model.to_local(actor.last_seen_position+Vector3.UP*actor.last_seen_height)-Vector3(-.08,1.28,.16)
		pitch=clampf(-atan2(contact.y,Vector2(contact.x,contact.z).length()),-.45,.45)
		yaw=clampf(atan2(contact.x,contact.z),-.45,.45)
	var turn:=Basis.from_euler(Vector3(pitch,PI*.5+yaw,0))
	var right: Vector3=weapon.get_node("GripRight").position
	# Carry the relaxed rifle clear of the jacket instead of pinning both
	# forearms against the chest. Aimed/search/gesture placement stays authored.
	var relaxed: bool=not aiming and not actor.crouching and search_blend<.001 and routine_blend<.001
	var anchor:=Vector3(-.08,1.28 if aiming else 1.10 if relaxed else 1.14,(.24 if relaxed else .16)-float(actor.muzzle_timer)*.3)
	if routine_blend>0 and last_routine in ["tie_boot","stretch"]:
		turn=turn.slerp(Basis.from_euler(Vector3(-.6,PI*.5,.15)),routine_blend)
		anchor=anchor.lerp(Vector3(.18,1.15,-.28),routine_blend)
	var rest:=Transform3D(turn,anchor-turn*right)
	var delta:=skeleton.get_bone_global_pose(torso_bone)*torso_reference.affine_inverse()
	weapon.global_transform=skeleton.global_transform*delta*skeleton.global_transform.affine_inverse()*model.global_transform*rest
	if relaxed:_fit_relaxed_weapon_reach()
	for side: String in arms:
		var arm: Dictionary=arms[side]
		var hand_basis: Basis=skeleton.global_basis.inverse()*weapon.global_basis*GRASP[side]*(arm.palm_frame as Basis).inverse()
		var contact: Vector3=skeleton.to_local(weapon.get_node("Grip"+side).global_position)
		var wrist: Vector3=contact-hand_basis*(arm.palm_offset as Vector3)
		if search_blend>0 and side=="Left":
			var searching: Vector3=skeleton.to_local(actor.search_focus)+Vector3(sin(time*3.5)*.025,.02+sin(time*5)*.025,0)
			wrist=wrist.lerp(searching,search_blend)
		if routine_blend>0:
			var gesture:=wrist
			if last_routine=="tie_boot" and not foot_bones.is_empty():
				gesture=skeleton.get_bone_global_pose(foot_bones[0]).origin+Vector3(.05 if side=="Left" else -.05,.07+sin(time*6)*.015,.04)
			elif last_routine=="stretch":
				gesture=skeleton.get_bone_global_pose(torso_bone).origin+Vector3(.36 if side=="Left" else -.36,.55,.02+sin(time*1.7)*.06)
			elif last_routine=="check_kit" and side=="Left":
				gesture=skeleton.get_bone_global_pose(torso_bone).origin+Vector3(.13,-.22,sin(time*4)*.025+.15)
			wrist=wrist.lerp(gesture,routine_blend)
		_solve_arm(arm,wrist,hand_basis,side)
		if routine_blend>.95 and last_routine=="tie_boot" and not foot_bones.is_empty():
			routine_errors[side]=skeleton.get_bone_global_pose(arm.hand).origin.distance_to(skeleton.get_bone_global_pose(foot_bones[0]).origin)
		var actual: Vector3=skeleton.get_bone_global_pose(arm.hand).origin+hand_basis*(arm.palm_offset as Vector3)
		grip_errors[side]=actual.distance_to(contact)

func _fit_relaxed_weapon_reach() -> void:
	# Keep the entire carbine rigid. Fit its two grip targets to actual arm reach
	# before IK rather than stretching a wrist to an unreachable relaxed anchor.
	var original_position: Vector3=weapon.global_position
	var correction:=Vector3.ZERO
	for pass_index: int in range(2):
		var worst_excess:=0.0
		var toward:=Vector3.ZERO
		for side: String in arms:
			var arm: Dictionary=arms[side]
			var hand_basis: Basis=skeleton.global_basis.inverse()*weapon.global_basis*GRASP[side]*(arm.palm_frame as Basis).inverse()
			var contact: Vector3=skeleton.to_local(weapon.get_node("Grip"+side).global_position)
			var wrist: Vector3=contact-hand_basis*(arm.palm_offset as Vector3)
			var shoulder: Vector3=skeleton.get_bone_global_pose(arm.upper).origin
			# Match the solver's 1 mm maximum-reach margin plus 3 mm reserve.
			var available: float=arm.upper_length+arm.lower_length-.004
			var excess: float=shoulder.distance_to(wrist)-available
			if excess>worst_excess:
				worst_excess=excess
				toward=(shoulder-wrist).normalized()
		if worst_excess<=0.0:break
		correction=(correction+skeleton.global_basis*toward*worst_excess).limit_length(.020)
		weapon.global_position=original_position+correction

func _raise_boot(weight: float) -> void:
	var upper_id:=_bone("LeftUpLeg");var lower_id:=_bone("LeftLeg");var foot_id:=_bone("LeftFoot")
	if mini(upper_id,mini(lower_id,foot_id))<0:return
	var upper:=skeleton.get_bone_global_pose(upper_id)
	var lower:=skeleton.get_bone_global_pose(lower_id)
	var foot:=skeleton.get_bone_global_pose(foot_id)
	var target:=foot.origin.lerp(Vector3(0,upper.origin.y-.04,upper.origin.z+.45),weight)
	var first:=upper.origin.distance_to(lower.origin);var second:=lower.origin.distance_to(foot.origin)
	var direction: Vector3=(target-upper.origin).normalized()
	var reach:=clampf(upper.origin.distance_to(target),absf(first-second)+.001,first+second-.001)
	var pole:=Vector3(0,.35,.65)
	var bend: Vector3=(pole-direction*pole.dot(direction)).normalized()
	var along: float=(first*first-second*second+reach*reach)/(2*reach)
	var knee: Vector3=upper.origin+direction*along+bend*sqrt(maxf(0,first*first-along*along))
	var turn:=Basis(Quaternion((lower.origin-upper.origin).normalized(),(knee-upper.origin).normalized()))
	var shin:=Basis(Quaternion((foot.origin-lower.origin).normalized(),(target-knee).normalized()))
	skeleton.set_bone_global_pose(upper_id,Transform3D(turn*upper.basis,upper.origin))
	skeleton.set_bone_global_pose(lower_id,Transform3D(shin*lower.basis,knee))
	skeleton.set_bone_global_pose(foot_id,Transform3D(foot.basis,target))

func _solve_arm(arm: Dictionary, target: Vector3, hand_basis: Basis, side: String) -> void:
	var upper:=skeleton.get_bone_global_pose(arm.upper)
	var lower:=skeleton.get_bone_global_pose(arm.lower)
	var hand:=skeleton.get_bone_global_pose(arm.hand)
	var a: float=arm.upper_length
	var b: float=arm.lower_length
	var direction: Vector3=(target-upper.origin).normalized()
	var reach: float=clampf(upper.origin.distance_to(target),absf(a-b)+.001,a+b-.001)
	# An armed carry needs elbows below/outside the chest even when a walk
	# clip swings its free arm upward. Follow the torso's rotation and leave
	# room for the sleeves, rather than inheriting that unrelated swing plane.
	var torso:=skeleton.get_bone_global_pose(torso_bone)
	var pole: Vector3=torso.origin+torso.basis*Vector3(.42 if side=="Left" else -.42,-.25,-.06)-upper.origin
	var plane: Vector3=pole-direction*pole.dot(direction)
	if plane.length_squared()<.0001:plane=upper.basis.x-direction*upper.basis.x.dot(direction)
	var bend:=plane.normalized()
	var along: float=(a*a-b*b+reach*reach)/(2.0*reach)
	var elbow: Vector3=upper.origin+direction*along+bend*sqrt(maxf(0.0,a*a-along*along))
	var wrist: Vector3=upper.origin+direction*reach
	var upper_turn:=Basis(Quaternion((lower.origin-upper.origin).normalized(),(elbow-upper.origin).normalized()))
	var lower_turn:=Basis(Quaternion((hand.origin-lower.origin).normalized(),(wrist-elbow).normalized()))
	skeleton.set_bone_global_pose(arm.upper,Transform3D(upper_turn*upper.basis,upper.origin))
	skeleton.set_bone_global_pose(arm.lower,Transform3D(lower_turn*lower.basis,elbow))
	skeleton.set_bone_global_pose(arm.hand,Transform3D(hand_basis,wrist))

func muzzle_position() -> Vector3:
	return muzzle.global_position if is_instance_valid(muzzle) else global_position+Vector3.UP*1.25

func play_death() -> void:
	dying=true
	var physical: bool=impact!=null and impact.start_death()
	if weapon!=null and skeleton!=null and arms.has("Right"):
		var socket:=BoneAttachment3D.new()
		socket.bone_name=skeleton.get_bone_name(arms.Right.hand)
		skeleton.add_child(socket)
		socket.transform=skeleton.get_bone_global_pose(arms.Right.hand)
		weapon.reparent(socket)
	if physical:return
	if clips.has("death"):
		animator.speed_scale=1.0
		animator.play(clips.death,.08)
	else:
		animator.pause()
		create_tween().tween_property(model,"rotation:x",deg_to_rad(83.0),.65)

func impact_motion(desired: Vector3) -> Vector3:
	return impact.balance.motion(desired) if impact!=null and impact.ready_for_use else desired

func impact_can_fire() -> bool:
	return impact==null or not impact.ready_for_use or impact.balance.can_fire()
