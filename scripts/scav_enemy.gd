extends "./enemy.gd"
## Human scav AI uses the established perception/path state machine and real art.
var weapon_id := "shigure"
var weapon_rounds := 30
var spare_magazines := 2
var magazine_reload_remaining := 0.0
const RELOAD_SECONDS: float=2.9
const ScavVisual=preload("./scav_visual.gd")
# Quiet first spotting stays forgiving; known threats can be engaged farther out.
const HUMAN_VISION_RANGE: float=40.0
const HUMAN_COMBAT_RANGE: float=85.0
const WALK_SPEED: float=1.4
var catching_up:=false
var social_look_point:=Vector3.INF
signal contact_reported(actor: Node, point: Vector3)
signal defeated(actor: Node)
var squad: Node
var role := "scout"
var model_path := ""
var scav_visual: Node3D
var dead := false
var rounds_fired := 0
var _report_delay := 0.0
var _burst_left := 0
var shot_material: StandardMaterial3D
var crouching:=false
var pinned_time:=0.0
var _tactical_id: int=-1
var _tactical_path:=PackedVector3Array()
var _tactical_index:=0
var own_visual_time:=999.0
const NOTICE_CONFIRM_SECONDS: float=.65
const SHOT_ACQUIRE_SECONDS: float=.22
# A new sighting starts loose and settles as the shooter tracks the target.
const AIM_SETTLE_SECONDS: float=2.0
const AIM_LOOSE: float=1.45
const AIM_SETTLED: float=.9
const AIM_CROSSING_SPEED: float=5.0
const NEAR_MISS_PRESSURE: float=.3
const SUPPRESSED_AT: float=.6
const SUPPRESSION_DECAY: float=.35
var suppression:=0.0
var notice_exposure:=0.0
var personal_visible_for:=0.0
var _investigation_goal:=Vector3.INF
var _investigation_replan_elapsed:=999.0
var visibility_notice_rate:=1.0
var busy_search:=false
var search_focus:=Vector3.ZERO
var routine: String=""
var last_seen_height:=1.2
var fleeing:=false
var _escape_path:=PackedVector3Array()
var _escape_index:=0

func _ready() -> void:
	attack_range=HUMAN_COMBAT_RANGE
	max_health=105.0 if role=="leader" else 90.0
	health=max_health
	move_speed=2.6 if role=="scout" else 2.3
	add_to_group("extraction_hostiles")
	add_to_group("human_scavs")
	super._ready()
	get_node("BodyCollision").position.y=.86

func _build_collision() -> void:
	super._build_collision()
	get_node("BodyCollision").position.y=.86

func _build_visual_socket() -> void:
	visual_root=Node3D.new()
	visual_root.name="ScavVisualRoot"
	add_child(visual_root)
	scav_visual=ScavVisual.new()
	scav_visual.name="MeshyScav"
	scav_visual.model_path=model_path
	visual_root.add_child(scav_visual)
	_setup_muzzle_light()
	shot_material=StandardMaterial3D.new()
	shot_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	shot_material.albedo_color=Color(1.0,.66,.31)
	shot_material.emission_enabled=true
	shot_material.emission=shot_material.albedo_color
	shot_material.emission_energy_multiplier=2.5

func _physics_process(delta: float) -> void:
	if dead: return
	_report_delay=maxf(0.0,_report_delay-delta)
	pinned_time=maxf(0.0,pinned_time-delta)
	suppression=maxf(0.0,suppression-SUPPRESSION_DECAY*delta)
	super._physics_process(delta)

func _update_perception(target_visible: bool, delta: float) -> void:
	# A glimpse can build suspicion without immediately identifying a person.
	# Concealment affects initial social notice as well as combat confirmation.
	notice_exposure=clampf(notice_exposure+delta*visibility_notice_rate if target_visible else notice_exposure-delta*1.25,0.0,NOTICE_CONFIRM_SECONDS)
	personal_visible_for=personal_visible_for+delta if target_visible else 0.0
	var confirmed: bool=target_visible and (notice_exposure>=NOTICE_CONFIRM_SECONDS or (is_instance_valid(squad) and squad.hostile))
	super._update_perception(confirmed,delta)
	var new_sighting: bool=confirmed and own_visual_time>.3
	own_visual_time=0.0 if target_visible else own_visual_time+delta
	if new_sighting and is_instance_valid(squad) and squad.hostile: squad.tactics.sighted(self)
	if confirmed: last_seen_height=.68 if bool(target.get("crouching")) else 1.2
	if is_instance_valid(squad) and squad.has_method("observe_player"): squad.observe_player(self,confirmed,delta)
	if confirmed and state==AIState.COMBAT and _report_delay<=0.0:
		_report_delay=.8
		contact_reported.emit(self,last_seen_position)

func _state_patrol(delta: float, target_visible: bool) -> void:
	if target_visible or not is_instance_valid(squad) or squad.leader()==self:
		super._state_patrol(delta,target_visible)
		return
	var goal: Vector3=squad.formation_point(self)
	if _flat_distance_to(goal)>1.3:
		_move_toward_path(goal,move_speed*(1.0 if _flat_distance_to(goal)>7.0 else .67),delta)
	else:
		desired_velocity_xz=Vector3.ZERO
		_scan_idle(delta)

func _update_state(delta: float, target_visible: bool) -> void:
	busy_search=false;routine=""
	if is_instance_valid(squad) and not squad.hostile:
		target_visible=target_visible and notice_exposure>=NOTICE_CONFIRM_SECONDS
	if fleeing:
		_set_crouch(false)
		desired_velocity_xz=Vector3.ZERO
		while _escape_index<_escape_path.size():
			var direction: Vector3=_escape_path[_escape_index]-global_position; direction.y=0
			if direction.length()<.5: _escape_index+=1; continue
			desired_velocity_xz=direction.normalized()*move_speed*1.35
			_face_direction(direction.normalized(),delta,12.0)
			break
		return
	if is_instance_valid(squad) and squad.get("hostile")!=null and not squad.hostile:
		_set_crouch(false)
		if target_visible:
			desired_velocity_xz=Vector3.ZERO
			_face_point(target.global_position,delta,8.0)
		elif state==AIState.SEARCH: _state_search(delta,false)
		elif squad.get("activity")!=null: squad.activity.perform(self,delta)
		else: _state_patrol(delta,false)
		return
	if is_instance_valid(squad) and squad.tactics!=null:
		var order: Dictionary=squad.tactics.orders.get(self,{})
		if not order.is_empty():
			# Team intelligence can guide movement, never confirm a personal shot.
			if target_visible and state!=AIState.COMBAT:
				sight_confirm_time+=delta*visibility_notice_rate
				if sight_confirm_time>=ALERT_CONFIRM_TIME: _enter_state(AIState.COMBAT)
			elif not target_visible:
				sight_confirm_time=0.0
				if time_since_seen>LOST_SIGHT_GRACE and state!=AIState.SEARCH: _enter_state(AIState.SEARCH)
			_follow_order(order,delta)
			return
	_set_crouch(false)
	super._update_state(delta,target_visible)

func _state_alert(delta: float, target_visible: bool) -> void:
	super._state_alert(delta*visibility_notice_rate if target_visible else delta,target_visible)

func _state_combat(delta: float, target_visible: bool) -> void:
	# Wait for a tactical route instead of charging the player between plans.
	desired_velocity_xz=Vector3.ZERO
	if last_seen_valid: _face_point(last_seen_position,delta,10.0)
	if not target_visible and time_since_seen>LOST_SIGHT_GRACE: _enter_state(AIState.SEARCH)

func _follow_order(order: Dictionary, delta: float) -> void:
	# Nobody stands tall under fire or while their hands are on a magazine.
	var ducking: bool=order.kind in ["hold_cover","observe"] and (pinned_time>0.0 or magazine_reload_remaining>0.0)
	_set_crouch(bool(order.get("crouch",false)) or ducking)
	if int(order.id)!=_tactical_id:
		_tactical_id=int(order.id)
		_tactical_path=order.path.duplicate()
		_tactical_index=0
	var direction:=Vector3.ZERO
	while _tactical_index<_tactical_path.size():
		var point: Vector3=_tactical_path[_tactical_index]
		point.y=global_position.y
		var offset: Vector3=point-global_position
		var tolerance: float=.22 if _tactical_index==_tactical_path.size()-1 else .5
		if offset.length()<tolerance: _tactical_index+=1; continue
		direction=offset.normalized(); break
	# Publish progress along the unconsumed route, not just body displacement.
	var remaining:=0.0
	var previous: Vector3=global_position
	for index: int in range(_tactical_index,_tactical_path.size()):
		remaining+=previous.distance_to(_tactical_path[index])
		previous=_tactical_path[index]
	order.route_remaining=remaining
	desired_velocity_xz=direction*move_speed*(.5 if crouching else 1.0)*float(order.get("pace",1.0))
	if direction.length_squared()>.01:
		_face_direction(direction,delta,9.0)
	elif last_seen_valid:
		_face_point(last_seen_position,delta,10.0)

func _set_crouch(value: bool) -> void:
	if value==crouching: return
	if not value and is_instance_valid(squad) and not squad.tactics.clear_at(global_position,self,false): return
	crouching=value
	var collision: CollisionShape3D=get_node("BodyCollision")
	var capsule: CapsuleShape3D=collision.shape
	capsule.height=1.1 if crouching else 1.72
	collision.position.y=capsule.height*.5

func _can_see_target() -> bool:
	if not is_instance_valid(target): return false
	if is_instance_valid(squad) and is_instance_valid(squad.raid) and squad.raid.has_method("insertion_grace") and squad.raid.insertion_grace(): return false
	var eye:=global_position+Vector3.UP*(.98 if crouching else 1.52)
	var target_point:=target.global_position+Vector3.UP*(.95 if bool(target.get("crouching")) else 1.25)
	var offset:=target_point-eye
	var sight_range: float=HUMAN_VISION_RANGE
	if is_instance_valid(squad) and squad.hostile:
		var known_contact: bool=last_seen_valid and time_since_seen<=14.0
		if not known_contact and squad.tactics!=null:
			known_contact=not squad.tactics.contact(self).is_empty()
		if known_contact: sight_range=HUMAN_COMBAT_RANGE
	if offset.length()>sight_range or offset.length()<.01: return false
	visibility_notice_rate=1.0
	if is_instance_valid(squad) and squad.get("concealment")!=null:
		var concealment: Node3D=squad.concealment
		if not concealment.ready_for_use: return false
		if concealment.ready_for_use:
			var exposure: Dictionary=concealment.sample(self,target,sight_range>HUMAN_VISION_RANGE)
			sight_range=maxf(3.5,sight_range*float(exposure.factor))
			visibility_notice_rate=float(exposure.notice_rate)
	if offset.length()>sight_range or offset.length()<.01: return false
	var forward: Vector3=-global_basis.z; forward.y=0
	var flat:=Vector3(offset.x,0,offset.z).normalized()
	if forward.normalized().dot(flat)<cos(deg_to_rad(VISION_HALF_ANGLE_DEG)): return false
	var query:=PhysicsRayQueryParameters3D.create(eye,target_point,1|2)
	query.exclude=[get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider")==target

func _refresh_navigation_path(destination: Vector3) -> void:
	super._refresh_navigation_path(destination)
	# A replan must not pull a moving human back to the grid vertex behind them.
	if navigation_path.size()<2 or not is_instance_valid(navigation_source): return
	var nav: RefCounted=navigation_source.get("navigation")
	if nav==null or not nav.has_method("_can_walk_edge"): return
	var here:=Vector2(global_position.x,global_position.z)
	# Follow a short, capsule-checked stretch of the corridor. Targeting every
	# grid corner at walking pace causes repeated brakes and backward replans.
	var furthest:=1
	for i: int in range(1,navigation_path.size()):
		if here.distance_to(Vector2(navigation_path[i].x,navigation_path[i].z))>3.0:break
		furthest=i
	for i: int in range(furthest,0,-1):
		var next:=Vector2(navigation_path[i].x,navigation_path[i].z)
		if here.distance_to(next)<=3.0 and nav._can_walk_edge(here,next):navigation_path_index=i;break
	if not _urgent_movement():path_refresh_timer=.75

func _urgent_movement() -> bool:
	if fleeing:return true
	if not is_instance_valid(squad):return state==AIState.COMBAT
	if not squad.hostile:return false
	return state==AIState.COMBAT or pinned_time>0.0 or (squad.tactics!=null and not squad.tactics.contact(self).is_empty())

func _move_toward_path(destination: Vector3,speed: float,delta: float) -> void:
	if not _urgent_movement():
		# Slow into a destination rather than hitting its arrival radius at full pace.
		var gap:=Vector2(destination.x-global_position.x,destination.z-global_position.z).length()
		speed=minf(speed,move_speed if catching_up else WALK_SPEED)*clampf(gap/1.8,.4,1.0)
	super._move_toward_path(destination,speed,delta)

func _apply_movement(delta: float) -> void:
	# Local separation complements the real body capsules; walls still block motion.
	if is_instance_valid(squad) and desired_velocity_xz.length_squared()>.01:
		desired_velocity_xz+=squad.separation(self)
	var urgent:=_urgent_movement()
	var can_catch_up:=false
	if is_instance_valid(squad) and not squad.hostile and not crouching and routine.is_empty() and not busy_search and state!=AIState.SEARCH:
		var activity: RefCounted=squad.get("activity")
		var lead: CharacterBody3D=squad.leader()
		if activity!=null and activity.mode=="patrol" and is_instance_valid(lead) and lead!=self:
			can_catch_up=true
			var gap:=Vector2(global_position.x-lead.global_position.x,global_position.z-lead.global_position.z).length()
			if gap>7.0:catching_up=true
			elif gap<5.5:catching_up=false
	if not can_catch_up:catching_up=false
	if not urgent:
		desired_velocity_xz=desired_velocity_xz.limit_length(move_speed if catching_up else WALK_SPEED)
		var current:=Vector3(velocity.x,0,velocity.z)
		var acceleration:=4.5 if catching_up else 2.2
		if desired_velocity_xz.length()<current.length():acceleration=3.8
		desired_velocity_xz=current.move_toward(desired_velocity_xz,acceleration*delta)
	if scav_visual.has_method("impact_motion"):desired_velocity_xz=scav_visual.impact_motion(desired_velocity_xz)
	super._apply_movement(delta)

func hear_noise(point: Vector3, radius: float) -> void:
	if dead or fleeing or global_position.distance_to(point)>radius: return
	# Bounded uncertainty: repeated estimates of one sound stay within one
	# five-metre search area rather than restarting at opposite square corners.
	var estimate:=point+Vector3.RIGHT.rotated(Vector3.UP,randf_range(0.0,TAU))*randf_range(0.0,2.5)
	if is_instance_valid(squad): squad.tactics.report(self,estimate,"sound")
	if state!=AIState.COMBAT: investigate(estimate)

func investigate(point: Vector3) -> void:
	if dead or fleeing or not point.is_finite(): return
	last_seen_position=point
	last_seen_valid=true
	# A delivered report may redirect attention, never refresh personal sight or
	# allow a shot. Preserve the current combat/cover commitment until replanned.
	if state==AIState.COMBAT: return
	if state==AIState.SEARCH:
		if _investigation_goal.is_finite() and _flat_distance_between(point,_investigation_goal)<=5.0: return
		if _investigation_replan_elapsed<1.0: return
		_investigation_goal=point; _investigation_replan_elapsed=0.0
		_prepare_search_points()
		_invalidate_path()
		# Relocate search intent without resetting its total time budget.
		return
	_investigation_goal=point; _investigation_replan_elapsed=0.0
	_enter_state(AIState.SEARCH)

func _flat_distance_between(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func _shoot_at_player(distance: float) -> void:
	if magazine_reload_remaining>0.0:return
	if personal_visible_for<SHOT_ACQUIRE_SECONDS:return
	if weapon_rounds<=0:return
	if scav_visual.has_method("impact_can_fire") and not scav_visual.impact_can_fire():return
	if distance>=attack_range: return
	if dead or fleeing or not is_instance_valid(target) or not _can_see_target(): return
	if is_instance_valid(squad) and squad.get("hostile")!=null and not squad.hostile: return
	if is_instance_valid(squad) and not squad.tactics.permits_fire(self): return
	# Personal vision is wider than a firing stance. Turn onto the target before
	# firing; a radio contact or a moving actor facing away cannot shoot backwards.
	var aim_flat: Vector3=target.global_position-global_position; aim_flat.y=0
	var facing: Vector3=-global_basis.z; facing.y=0
	if aim_flat.length_squared()<.001 or facing.normalized().dot(aim_flat.normalized())<cos(deg_to_rad(12.0)): return
	var origin: Vector3=scav_visual.muzzle_position()
	var chest: Vector3=target.global_position+Vector3.UP*(.68 if bool(target.get("crouching")) else 1.20)
	# Check the centre firing lane before a burst: a friend or wall means hold fire.
	var lane:=PhysicsRayQueryParameters3D.create(origin,chest,1|2)
	lane.exclude=[get_rid()]
	var obstruction:=get_world_3d().direct_space_state.intersect_ray(lane)
	if not obstruction.is_empty() and obstruction.get("collider")!=target: return
	# Short, imperfect bursts. The actual muzzle ray must hit the player to hurt them.
	if _burst_left<=0: _burst_left=3
	var spread:=aim_spread(distance)
	var aim:=chest+global_basis.x*randf_range(-spread,spread)+Vector3.UP*randf_range(-spread*.65,spread*.65)
	var direction: Vector3=(aim-origin).normalized()
	var end: Vector3=origin+direction*(origin.distance_to(chest)+2.0)
	var query:=PhysicsRayQueryParameters3D.create(origin,end,1|2)
	query.exclude=[get_rid()]
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	var visible_end: Vector3=hit.get("position",end)
	_show_tracer(origin,visible_end)
	_burst_left-=1
	attack_cooldown=.16 if _burst_left>0 else randf_range(1.5,2.2)
	muzzle_timer=.055
	rounds_fired+=1
	weapon_rounds-=1
	if hit.get("collider")==target and target.has_method("take_damage"):
		if target.has_method("register_damage_source"): target.register_damage_source(global_position)
		target.take_damage(randf_range(4.0,7.0))

## Half-width of a shot's scatter at the target, in metres. Everything here is
## something a person would feel: tracking time, a crossing target, recoil,
## wounds and rounds cracking past.
func aim_spread(distance: float) -> float:
	var settle: float=lerpf(AIM_LOOSE,AIM_SETTLED,clampf(personal_visible_for/AIM_SETTLE_SECONDS,0.0,1.0))
	var crossing:=0.0
	if is_instance_valid(target) and target is CharacterBody3D:
		var line: Vector3=target.global_position-global_position; line.y=0
		if line.length_squared()>.01:
			var moved: Vector3=target.velocity; moved.y=0
			crossing=clampf((moved-line.normalized()*moved.dot(line.normalized())).length()/AIM_CROSSING_SPEED,0.0,1.0)
	var recoil: float=1.0+float(3-_burst_left)*.2 if _burst_left>0 else 1.0
	var wounded: float=1.0+(1.0-health/max_health)*.5
	return (.14+distance*.022)*settle*(1.0+crossing*.8)*recoil*wounded*(1.0+suppression*1.2)

## A round cracking past. One is a flinch; several in a row put a head down.
func near_miss() -> void:
	if dead or fleeing: return
	suppression=minf(1.0,suppression+NEAR_MISS_PRESSURE)
	if suppression>=SUPPRESSED_AT: pinned_time=maxf(pinned_time,randf_range(.8,1.3))

func begin_reload() -> void:
	if dead or fleeing or spare_magazines<=0 or magazine_reload_remaining>0.0 or weapon_rounds>=30: return
	magazine_reload_remaining=RELOAD_SECONDS
	if is_instance_valid(squad): squad.callout(self,"Reloading!")

func out_of_ammo() -> bool:
	return weapon_rounds<=0 and spare_magazines<=0 and magazine_reload_remaining<=0.0

func can_fire_now() -> bool:
	return weapon_rounds>0 and magazine_reload_remaining<=0.0 and pinned_time<=0.0

func weapon_up() -> bool:
	if magazine_reload_remaining>0.0 or not is_instance_valid(target): return false
	return state==AIState.COMBAT or (is_instance_valid(squad) and squad.hostile and squad.tactics.orders.has(self))

func _show_tracer(start: Vector3, end: Vector3) -> void:
	var line:=end-start
	if line.length()<.08: return
	var length:=minf(line.length(),2.2)
	var beam:=MeshInstance3D.new()
	beam.name="ScavShot"
	var mesh:=CylinderMesh.new()
	mesh.height=length
	mesh.top_radius=.006
	mesh.bottom_radius=.006
	mesh.radial_segments=5
	beam.mesh=mesh
	beam.material_override=shot_material
	beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(beam)
	beam.global_transform=Transform3D(Basis(Quaternion(Vector3.UP,line.normalized())),start+line.normalized()*length*.5)
	var beam_ref: WeakRef=weakref(beam)
	get_tree().create_timer(.065,false).timeout.connect(func() -> void:
		var live: Node=beam_ref.get_ref()
		if is_instance_valid(live): live.queue_free())

func _update_timers(delta: float) -> void:
	_investigation_replan_elapsed+=maxf(0.0,delta)
	if magazine_reload_remaining>0.0:
		magazine_reload_remaining=maxf(0.0,magazine_reload_remaining-delta)
		if magazine_reload_remaining==0.0 and spare_magazines>0:
			spare_magazines-=1
			weapon_rounds=30
	elif weapon_rounds<=0: begin_reload()
	super._update_timers(delta)
	if is_instance_valid(muzzle_light) and is_instance_valid(scav_visual):
		muzzle_light.global_position=scav_visual.muzzle_position()

func take_damage(amount: float, source: Node=null) -> void:
	if dead or not is_finite(amount) or amount<=0.0: return
	if is_instance_valid(squad) and squad.has_method("make_hostile"): squad.make_hostile(self,"attacked")
	health=maxf(0.0,health-amount)
	pinned_time=randf_range(1.7,2.5)
	hit_flash=.1
	if is_instance_valid(source) and source is Node3D:
		last_seen_position=source.global_position+Vector3(randf_range(-3,3),0,randf_range(-3,3))
		last_seen_valid=true
		time_since_seen=0.0
		if state!=AIState.COMBAT: _enter_state(AIState.ALERT)
		if is_instance_valid(squad): squad.tactics.report(self,last_seen_position,"hit")
	if health>0.0:
		if is_instance_valid(squad): squad.reassess_morale(self)
		return
	dead=true
	if is_instance_valid(muzzle_light): muzzle_light.light_energy=0
	desired_velocity_xz=Vector3.ZERO
	velocity=Vector3.ZERO
	set_physics_process(false)
	remove_from_group("extraction_hostiles")
	remove_from_group("enemies")
	collision_layer=0
	collision_mask=0
	if source!=null and source.has_method("notify_kill"): source.notify_kill()
	var run := get_tree().get_first_node_in_group("shinrai_survival_run")
	if is_instance_valid(run):run.register_scav_drop(self)
	scav_visual.play_death()
	defeated.emit(self)
	var corpse_ref: WeakRef=weakref(self)
	get_tree().create_timer(30.0,false).timeout.connect(func() -> void:
		var live: Node=corpse_ref.get_ref()
		if not is_instance_valid(live): return
		if is_instance_valid(live.squad): live.squad.forget(live)
		live.queue_free())

func break_morale(escape: PackedVector3Array) -> void:
	if dead or escape.is_empty(): return
	fleeing=true
	_escape_path=escape; _escape_index=0
	_burst_left=0; attack_cooldown=9999.0; muzzle_timer=0
	state=AIState.RETURN_TO_PATROL
	remove_from_group("enemies"); remove_from_group("extraction_hostiles")
	if scav_visual.get("weapon")!=null and is_instance_valid(scav_visual.weapon): scav_visual.weapon.visible=false

