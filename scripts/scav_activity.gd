extends RefCounted
## Search existing shopfront stock while a dedicated third member watches north.
var crew: Node3D
var sites: Array[Dictionary]=[]
var guard: CharacterBody3D
var guard_post:=Vector3.INF
var jobs: Dictionary={}
var completed: Array[Dictionary]=[]
var clock:=0.0
var mode: String="looting"
var routes: Array[Dictionary]=[]
var route_index: int=-1
var waypoint: int=0
var pause_left:=0.0
var phase_started:=0.0
var routine_actor: CharacterBody3D
var routine_kind: String=""
var routine_left:=0.0
var routine_due:=36.0
var route_history: Array[String]=[]
var routine_history: Array[Dictionary]=[]
var rng:=RandomNumberGenerator.new()
var patrol_last:=Vector3.INF
var patrol_progress:=0.0
var regroup_slots: Dictionary={}
var regroup_settled:=0.0
var regroup_retry:=0.0
var cohesion_hold:=false
var patrol_forward:=Vector3.FORWARD

func discover(street: Node3D) -> Array[AABB]:
	var bounds: Array[AABB]=[]
	for shop_name: String in ["UedaBooks","HinataDaily"]:
		var shop:=street.get_node_or_null(NodePath(shop_name)) as Node3D
		if shop==null:continue
		var frontage:=shop.get_node_or_null("C_ArtisanShopfrontDisplays")
		if frontage==null:continue
		for child: Node in frontage.get_children():
			if not child is Node3D:continue
			if not ("BrowseTable" in child.name or "FaceOutRack" in child.name or "ProduceStand" in child.name or (shop_name=="HinataDaily" and absf(absf(child.position.x)-2.8)<.1)):continue
			var half:=Vector3(.95,.8,.5)
			var box:=AABB(child.global_position-Vector3(half.x,0,half.z),half*2)
			bounds.append(box)
			sites.append({"owner":weakref(child),"focus":child.global_position+Vector3.UP*.62,"shop":shop_name,"bounds":box})
	return bounds

func setup(owner_crew: Node3D) -> bool:
	crew=owner_crew
	rng.randomize()
	guard_post=crew.get_nearest_walkable_world(Vector3(0,.1,182))
	if not guard_post.is_finite():return false
	for i: int in range(sites.size()-1,-1,-1):
		var site: Dictionary=sites[i];var found:=Vector3.INF
		for offset: Vector3 in [Vector3(0,0,-1.25),Vector3(-1.6,0,-.6),Vector3(1.6,0,-.6)]:
			var point: Vector3=crew.get_nearest_walkable_world(site.focus+offset)
			if not point.is_finite() or point.distance_to(site.focus)>2.5:continue
			if crew.get_path_world(guard_post,point).is_empty():continue
			found=point;break
		if not found.is_finite():sites.remove_at(i)
		else:site.point=found
	if sites.size()<2:return false
	_build_routes()
	guard=crew.members[2];guard.set_meta("scav_duty","guard")
	for actor: CharacterBody3D in crew.members:
		if actor!=guard:actor.set_meta("scav_duty","looter");_assign(actor)
	crew.tactics.send(guard,"guarding_looters",{"post":guard_post})
	return true

func _assign(actor: CharacterBody3D) -> void:
	var preferred: String="UedaBooks" if actor.role=="leader" else "HinataDaily"
	var previous: int=int(jobs.get(actor,{}).get("site",-1))
	var candidates: Array[int]=[]
	for i: int in range(sites.size()):
		if sites[i].shop==preferred:candidates.append(i)
	if candidates.is_empty():
		for i: int in range(sites.size()):candidates.append(i)
	var next: int=candidates[(maxi(0,candidates.find(previous))+1)%candidates.size()] if previous>=0 else candidates[0]
	jobs[actor]={"site":next,"elapsed":0.0,"phase":"approach","progress":clock,"last":actor.global_position}
	crew.tactics.send(actor,"loot_approach",{"stock":str(sites[next].owner.get_ref().get_path()),"destination":sites[next].point})

func tick(delta: float) -> void:
	clock+=delta
	if not is_instance_valid(guard) or guard.dead:
		for actor: CharacterBody3D in crew.members:
			if actor.dead:continue
			guard=actor;jobs.erase(actor);actor.set_meta("scav_duty","guard");crew.tactics.send(actor,"taking_guard_post");break
		if mode=="regroup":_gather_slots()
	var suspicious:=false
	for actor: CharacterBody3D in crew.members:
		if actor.dead:continue
		if crew.warning_active and actor.own_visual_time<3.0:suspicious=true
		if actor.state==actor.AIState.SEARCH or not crew.tactics.contact(actor).is_empty():suspicious=true
	if suspicious:
		interrupt("contact");routine_due=maxf(routine_due,clock+20);return
	if routine_left>0:
		routine_left-=delta
		if routine_left<=0:interrupt("finished");routine_due=clock+rng.randf_range(42,75)
		return
	if clock>=routine_due and mode!="regroup":
		begin_routine(crew.members[rng.randi_range(0,crew.members.size()-1)],["tie_boot","check_kit","stretch"][rng.randi_range(0,2)])
		return
	if mode=="looting" and clock-phase_started>38 and completed.size()>=2 and not routes.is_empty():
		mode="regroup";regroup_settled=0;cohesion_hold=false;_gather_slots()
		crew.tactics.send(guard,"regroup_at_guard",{"post":guard_post})
	elif mode=="regroup":
		var missing_slot:=false
		for actor: CharacterBody3D in crew.members:
			if not actor.dead and not regroup_slots.has(actor):missing_slot=true
		if clock>=regroup_retry and missing_slot:_gather_slots()
		var gathered:=true
		for actor: CharacterBody3D in crew.members:
			if actor.dead:continue
			if not regroup_slots.has(actor) or _flat_gap(actor.global_position,regroup_slots[actor])>.95 or Vector2(actor.velocity.x,actor.velocity.z).length()>.25:gathered=false
		regroup_settled=regroup_settled+delta if gathered else 0.0
		# A continuous settled second prevents departure while a buddy is still arriving.
		if regroup_settled>=1.0:
			mode="patrol";waypoint=0;pause_left=0;phase_started=clock
			patrol_last=crew.leader().global_position;patrol_progress=clock
			route_index=(route_index+1)%routes.size();route_history.append(routes[route_index].name)
			# Gathering already visited the first marker. Do not walk into the
			# sentinel's occupied capsule before setting off on the actual route.
			if _flat_gap(routes[route_index].points[0],guard_post)<1.0:waypoint=1
			var heading: Vector3=routes[route_index].points[1]-routes[route_index].points[0];heading.y=0
			if heading.length_squared()>.01:patrol_forward=heading.normalized()
			crew.tactics.send(crew.leader(),"patrol_route",{"route":routes[route_index].name,"crew_gathered":true})
	elif mode=="patrol":
		var lead: CharacterBody3D=crew.leader()
		if not is_instance_valid(lead):return
		var motion:=Vector3(lead.velocity.x,0,lead.velocity.z)
		if motion.length()>.35:
			var turn:=patrol_forward.signed_angle_to(motion.normalized(),Vector3.UP)
			patrol_forward=patrol_forward.rotated(Vector3.UP,clampf(turn,-delta*1.8,delta*1.8))
		var gap:=0.0
		for actor: CharacterBody3D in crew.members:
			if not actor.dead:gap=maxf(gap,_flat_gap(actor.global_position,lead.global_position))
		if gap>8.0 and not cohesion_hold:
			cohesion_hold=true;crew.tactics.send(lead,"waiting_for_buddy")
		elif gap<6.0 and cohesion_hold:
			cohesion_hold=false;crew.tactics.send(lead,"crew_together")
		if cohesion_hold:patrol_progress=clock;return
		var point: Vector3=routes[route_index].points[waypoint]
		if lead.global_position.distance_to(patrol_last)>.4:patrol_last=lead.global_position;patrol_progress=clock
		if clock-patrol_progress>10.0:
			crew.tactics.send(lead,"patrol_route_blocked",{"route":routes[route_index].name});mode="looting";phase_started=clock;return
		if Vector2(lead.position.x-point.x,lead.position.z-point.z).length()<.9:
			patrol_progress=clock
			if pause_left<=0:pause_left=rng.randf_range(2.0,4.0)
			pause_left-=delta
			if pause_left<=0:
				waypoint+=1
				if waypoint>=routes[route_index].points.size():mode="looting";phase_started=clock

func _flat_gap(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func _gather_slots() -> void:
	regroup_slots.clear();regroup_settled=0;regroup_retry=clock+2.0
	if not is_instance_valid(guard) or guard.dead:return
	regroup_slots[guard]=guard_post
	for actor: CharacterBody3D in crew.members:
		if actor.dead or actor==guard:continue
		for offset: Vector3 in [Vector3(-2,0,1),Vector3(2,0,1),Vector3(-2,0,-1),Vector3(2,0,-1),Vector3(-1,0,2),Vector3(1,0,2)]:
			var point: Vector3=crew.get_nearest_walkable_world(guard_post+offset)
			if not point.is_finite() or _flat_gap(point,guard_post)>3.5:continue
			var free:=true
			for occupied: Vector3 in regroup_slots.values():
				if _flat_gap(point,occupied)<1.3:free=false
			if not free or crew.get_path_world(actor.global_position,point).is_empty():continue
			regroup_slots[actor]=point;break

func _build_routes() -> void:
	for plan: Dictionary in [
		{"name":"shopfront_sweep","points":[Vector3(0,.1,182),Vector3(21,.1,190),Vector3(8,.1,190),Vector3(-14,.1,190),Vector3(0,.1,182)]},
		{"name":"market_loop","points":[Vector3(0,.1,182),Vector3(24,.1,183),Vector3(25,.1,190),Vector3(0,.1,191),Vector3(-22,.1,184),Vector3(0,.1,182)]},
		{"name":"central_passage","points":[Vector3(0,.1,182),Vector3(0,.1,193),Vector3(0,.1,207),Vector3(0,.1,193),Vector3(0,.1,182)]}
	]:
		var points: Array[Vector3]=[]
		for requested: Vector3 in plan.points:
			var point: Vector3=crew.get_nearest_walkable_world(requested)
			if not point.is_finite() or point.distance_to(requested)>3.0:points.clear();break
			if not points.is_empty() and crew.get_path_world(points[-1],point).is_empty():points.clear();break
			points.append(point)
		if points.size()>=3:routes.append({"name":plan.name,"points":points})

func begin_routine(actor: CharacterBody3D,kind: String) -> bool:
	if mode=="regroup":return false
	if not is_instance_valid(actor) or actor.dead or crew.hostile or crew.morale_broken:return false
	for member: CharacterBody3D in crew.members:
		if member.dead:continue
		if crew.warning_active and member.own_visual_time<3.0:return false
		if member.state==member.AIState.SEARCH or not crew.tactics.contact(member).is_empty():return false
	routine_actor=actor;routine_kind=kind;routine_left=5.5 if kind=="tie_boot" else 3.5
	routine_history.append({"actor":actor.name,"kind":kind,"time":clock})
	if routine_history.size()>24:routine_history.pop_front()
	crew.tactics.send(actor,"routine_"+kind,{"crew_holds":true})
	return true

func interrupt(reason: String) -> void:
	regroup_settled=0
	if routine_left>0 and is_instance_valid(routine_actor):crew.tactics.send(routine_actor,"routine_end",{"reason":reason})
	routine_left=0;routine_actor=null;routine_kind=""
	for actor: CharacterBody3D in crew.members:
		if is_instance_valid(actor):actor.routine=""

func perform(actor: CharacterBody3D,delta: float) -> bool:
	if routine_left>0:
		actor.busy_search=false;actor.desired_velocity_xz=Vector3.ZERO
		actor.routine=routine_kind if actor==routine_actor else "cover_pause"
		actor._set_crouch(actor==routine_actor and routine_kind=="tie_boot")
		if actor!=routine_actor:actor._scan_idle(delta,.8)
		return true
	actor.routine=""
	if mode=="regroup":
		actor.busy_search=false;actor._set_crouch(false);actor.set_meta("scav_duty","guard" if actor==guard else "regroup")
		var slot: Vector3=regroup_slots.get(actor,Vector3.INF)
		if slot.is_finite() and _flat_gap(actor.global_position,slot)>.75:actor._move_toward_path(slot,actor.move_speed*.85,delta)
		else:actor.desired_velocity_xz=Vector3.ZERO;actor._scan_idle(delta,.8)
		return true
	if mode=="patrol":
		actor.busy_search=false;actor._set_crouch(false);actor.set_meta("scav_duty","patrol")
		var lead: CharacterBody3D=crew.leader()
		if actor==lead and cohesion_hold:
			actor.desired_velocity_xz=Vector3.ZERO;actor._scan_idle(delta,.8);return true
		var goal: Vector3=routes[route_index].points[waypoint]
		if actor!=lead:
			# Watching sideways must not rotate the whole formation around the guard.
			var side: float=-1.8 if actor.role=="scout" else 1.8
			var behind: float=2.8 if actor.role=="scout" else 4.3
			goal=crew.get_nearest_walkable_world(lead.global_position+patrol_forward.cross(Vector3.UP)*side-patrol_forward*behind)
		if goal.is_finite() and Vector2(actor.position.x-goal.x,actor.position.z-goal.z).length()>.9:
			actor._move_toward_path(goal,actor.move_speed*(.78 if actor==lead else 1.0),delta)
		else:actor.desired_velocity_xz=Vector3.ZERO;actor._scan_idle(delta,.7)
		return true
	if actor==guard:
		actor.set_meta("scav_duty","guard")
		actor.busy_search=false;actor._set_crouch(false)
		if actor.global_position.distance_to(guard_post)>.85:actor._move_toward_path(guard_post,actor.move_speed*.7,delta)
		else:
			actor.desired_velocity_xz=Vector3.ZERO
			var direction:=Vector3.FORWARD.rotated(Vector3.UP,sin(clock*.24)*1.0)
			actor._face_direction(direction,delta,3.0)
		return true
	if not jobs.has(actor):_assign(actor)
	actor.set_meta("scav_duty","looter")
	var job: Dictionary=jobs[actor];var site: Dictionary=sites[job.site]
	var source: Node=site.owner.get_ref()
	if not is_instance_valid(source):actor.busy_search=false;actor.desired_velocity_xz=Vector3.ZERO;return true
	if actor.global_position.distance_to(site.point)>.85:
		actor.busy_search=false;actor._set_crouch(false)
		actor._move_toward_path(site.point,actor.move_speed*.65,delta)
		if actor.global_position.distance_to(job.last)>.3:job.last=actor.global_position;job.progress=clock
		if clock-float(job.progress)>6.0:crew.tactics.send(actor,"loot_route_blocked");_assign(actor)
		return true
	actor.desired_velocity_xz=Vector3.ZERO;actor._set_crouch(true);actor.busy_search=true;actor.search_focus=site.focus
	actor._face_point(site.focus,delta,6.0)
	if job.phase!="search":job.phase="search";crew.tactics.send(actor,"searching_stock",{"stock":str(source.get_path())})
	job.elapsed+=delta
	if job.elapsed>8.0+crew.members.find(actor)*2.0:
		completed.append({"actor":actor.name,"stock":str(source.get_path()),"time":clock})
		if completed.size()>32:completed.pop_front()
		crew.tactics.send(actor,"stock_checked",{"stock":str(source.get_path())});actor.busy_search=false;_assign(actor)
	return true
