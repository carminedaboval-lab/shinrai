extends RefCounted
## A bounded, shared tactical planner. Knowledge comes only from delivered
## sight/sound/hit reports; geometry queries never sample the hidden player.
const CONTACT_LIFETIME:=14.0
const RADIO_RANGE:=80.0
const FAILED_GOAL_SECONDS:=8.0
const LATERAL_COOLDOWN:=10.0
# A crewmate this far out with no lane walks in to about the standoff distance.
const JOIN_RANGE:=24.0
# Past this even a clear lane is too far for a rifle in these hands to matter.
const JOIN_LANE_LIMIT:=35.0
const JOIN_STANDOFF:=15.0
const JOIN_COOLDOWN:=3.0
const JOIN_ROUTE_LIMIT:=110.0
# Walking a route stops for a burst when the enemy appears this close.
const REACTION_RANGE:=20.0
const REACTION_SECONDS:=1.5
const REACTION_COOLDOWN:=7.0
const RELOAD_TOPUP_ROUNDS:=10
const SEARCH_LEAD_SECONDS:=2.5
const SEARCH_LEAD_MAX:=10.0
# A firing spot needs a lane for the rifle: eyes clear low cover that the gun hits.
const MUZZLE_HEIGHT:=1.2
const SEARCH_PACE:=.7
const SEARCH_BEARING_TRIES:=4
# Without cover a shooter kneels and shifts position rather than standing as a post.
const KNEEL_RANGE:=8.0
var crew: Node3D
var clock:=0.0
var knowledge: Dictionary={}
var orders: Dictionary={}
var messages: Array[Dictionary]=[]
var positions: Dictionary={}
var flank_actor: CharacterBody3D
var flank_support: CharacterBody3D
var flank_cooldown:=5.0
var unsupported_time:=0.0
var _plan_timer:=0.0
var _status_timer:=0.0
var _cursor:=0
var _sequence:=0
var _failed_goals: Dictionary={}
var _lateral_after: Dictionary={}
var _search_state: Dictionary={}
var _join_after: Dictionary={}
var _reaction_after: Dictionary={}
var _last_sighting: Dictionary={}

func setup(owner_crew: Node3D) -> void:
	crew=owner_crew

func alive(actor: Node) -> bool:
	return is_instance_valid(actor) and not actor.dead and not actor.fleeing

func send(actor: Node3D, kind: String, detail: Dictionary={}) -> void:
	var message: Dictionary={"time":clock,"sender":actor.name,"position":actor.global_position,"kind":kind}
	message.merge(detail)
	messages.append(message)
	if messages.size()>96: messages.pop_front()

func report(actor: CharacterBody3D, point: Vector3, kind: String="visual") -> void:
	if not alive(actor) or not point.is_finite(): return
	var confidence: float={"visual":1.0,"sound":.48,"hit":.65}.get(kind,.4)
	var report_data: Dictionary={"point":point,"time":clock,"confidence":confidence,"kind":kind,"heading":_sighted_heading(point,kind)}
	var receivers: Array[String]=[]
	for peer: CharacterBody3D in crew.members:
		if not alive(peer) or peer.global_position.distance_to(actor.global_position)>RADIO_RANGE: continue
		var old: Dictionary=knowledge.get(peer,{})
		if not old.is_empty() and old.kind=="visual" and clock-float(old.time)<3.0 and kind!="visual": continue
		knowledge[peer]=report_data.duplicate()
		receivers.append(peer.name)
		if peer!=actor: peer.investigate(point)
	send(actor,"enemy_"+kind,{"enemy_position":point,"confidence":confidence,"receivers":receivers})

# Two real sightings give a direction of travel. Reports a moment apart are the
# same glimpse from two people, so the older sighting stays as the baseline.
func _sighted_heading(point: Vector3, kind: String) -> Vector3:
	if kind!="visual": return Vector3.ZERO
	if _last_sighting.is_empty() or clock-float(_last_sighting.time)>3.0:
		_last_sighting={"point":point,"time":clock,"heading":Vector3.ZERO}
		return Vector3.ZERO
	var elapsed: float=clock-float(_last_sighting.time)
	if elapsed<.4: return _last_sighting.heading
	var heading: Vector3=(point-_last_sighting.point)/elapsed; heading.y=0
	_last_sighting={"point":point,"time":clock,"heading":heading}
	return heading

# Called only for a genuine observed hostile contact, not a radio estimate.
# Planning does not bypass this member's normal personal combat confirmation.
func on_hostile_contact(actor: CharacterBody3D, point: Vector3) -> void:
	if not alive(actor) or not point.is_finite(): return
	report(actor,point,"visual")
	_decide(actor)

func contact(actor: CharacterBody3D) -> Dictionary:
	var data: Dictionary=knowledge.get(actor,{})
	if data.is_empty() or clock-float(data.time)>CONTACT_LIFETIME: return {}
	var result:=data.duplicate()
	result.confidence=float(data.confidence)*exp(-(clock-float(data.time))/8.0)
	result.age=clock-float(data.time)
	return result

func tick(delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	clock+=delta
	flank_cooldown=maxf(0.0,flank_cooldown-delta)
	_status_timer-=delta
	if _status_timer<=0:
		_status_timer=2.0
		for actor: CharacterBody3D in crew.members:
			if alive(actor):
				positions[actor]={"point":actor.global_position,"time":clock,"health":actor.health/actor.max_health}
				send(actor,"position_status",{"health":actor.health/actor.max_health,"order":orders.get(actor,{}).get("kind","patrol")})
	if alive(flank_actor):
		var support_info:=contact(flank_support) if alive(flank_support) else {}
		# Cover a reported lane even after the enemy ducks out of sight. Support
		# means a healthy gun watching that lane, not continuous enemy visibility.
		var supported: bool=alive(flank_support) and flank_support.health/flank_support.max_health>.3 and not support_info.is_empty() and float(support_info.age)<12.0 and flank_support.global_position.distance_to(flank_actor.global_position)<RADIO_RANGE and _ready_to_cover(flank_support) and sightline(flank_support.global_position+Vector3.UP*1.5,support_info.point+Vector3.UP*1.2)
		unsupported_time=0.0 if supported else unsupported_time+delta
		if unsupported_time>2.2 or flank_actor.pinned_time>0 or flank_actor.health/flank_actor.max_health<.45 or contact(flank_actor).is_empty():
			_abort_flank("support_lost_or_unsafe")
	_plan_timer-=delta
	if _plan_timer>0 or crew.members.is_empty(): return
	_plan_timer=.25
	_cursor=(_cursor+1)%crew.members.size()
	var actor: CharacterBody3D=crew.members[_cursor]
	if alive(actor): _decide(actor)
	if not alive(flank_actor) and flank_cooldown<=0:
		flank_cooldown=2.0
		_try_flank()

func _issue(actor: CharacterBody3D, kind: String, goal: Vector3, route: PackedVector3Array=PackedVector3Array(), extra: Dictionary={}) -> void:
	_sequence+=1
	var order: Dictionary={"id":_sequence,"kind":kind,"goal":goal,"path":route,"issued":clock,"until":clock+4.0,"last_progress":clock,"best_remaining":path_length(route,actor.global_position),"route_remaining":path_length(route,actor.global_position)}
	order.merge(extra,true)
	orders[actor]=order
	send(actor,kind,{"destination":goal})

func _decide(actor: CharacterBody3D) -> void:
	var info:=contact(actor)
	if info.is_empty():
		orders.erase(actor)
		return
	var threat: Vector3=info.point
	var order: Dictionary=orders.get(actor,{})
	var safe_hold: Dictionary={}
	# An empty rifle has no more business in the open than a wounded man.
	var low_health: bool=actor.health/actor.max_health<.32 or actor.out_of_ammo()
	if not order.is_empty() and order.kind=="flank" and order.has("threat") and _flat(order.threat,threat)>6.0:
		_abort_flank("contact_relocated")
		order={}
	if not order.is_empty() and _should_return_fire(actor,order,threat):
		_return_fire(actor)
		return
	if not order.is_empty():
		var moving: bool=order.kind in ["move_cover","retreat","flank","peek_move","return_cover","search_sector","reposition"]
		# The follower publishes remaining route length, so sideways shuffling or
		# oscillation cannot continually reset the blocked-route timer.
		if moving and float(order.route_remaining)<float(order.best_remaining)-.35:
			order.best_remaining=order.route_remaining
			order.last_progress=clock
		if moving and clock-float(order.last_progress)>3.2 and _flat(actor.global_position,order.goal)>.32:
			_remember_failed_goal(actor,order.goal)
			send(actor,"route_blocked")
			if actor==flank_actor: _abort_flank("blocked")
			orders.erase(actor); order={}
		if not order.is_empty() and moving and _flat(actor.global_position,order.goal)<.32:
			if order.kind=="search_sector" and _search_state.has(actor):
				_search_state[actor].step=int(_search_state[actor].step)+1
			if order.kind=="flank":
				send(actor,"flank_arrived")
				flank_actor=null; flank_support=null; flank_cooldown=9.0
			if order.has("cover"):
				var cover: Dictionary=order.cover
				if order.kind=="peek_move":
					_issue(actor,"peek",order.goal,PackedVector3Array(),{"cover":cover,"until":clock+randf_range(1.7,2.8),"crouch":false})
				else:
					_issue(actor,"hold_cover",cover.point,PackedVector3Array(),{"cover":cover,"until":clock+1.2+crew.members.find(actor)*.55,"crouch":cover.crouch})
				return
			else:
				_issue(actor,"observe",actor.global_position,PackedVector3Array(),{"until":clock+1.8})
				return
		if not order.is_empty() and order.has("cover"):
			var slot: Dictionary=order.cover
			var compromised: bool=not protected_at(slot.point,threat,slot.crouch)
			# Wounded members already protected at their destination must settle.
			if compromised or (low_health and order.kind in ["peek","peek_move","flank"]) or (actor.pinned_time>0 and order.kind in ["peek","peek_move"]):
				if compromised: _remember_failed_goal(actor,slot.point)
				send(actor,"cover_compromised" if compromised else "need_cover")
				if actor==flank_actor: _abort_flank("cover_compromised")
				orders.erase(actor); order={}
		# Reloads happen behind cover: a dry peek ends now, and a quiet moment in
		# cover tops up a low magazine before the next one.
		if not order.is_empty() and order.kind=="peek" and actor.magazine_reload_remaining>0: order.until=clock
		if not order.is_empty() and order.kind=="hold_cover" and actor.weapon_rounds<=RELOAD_TOPUP_ROUNDS: actor.begin_reload()
		if not order.is_empty() and clock<float(order.until): return
		if not order.is_empty() and order.kind=="hold_cover":
			# A long checked approach can consume several seconds of the report's
			# lifetime. Healthy members may probe that last-known lane until contact
			# expires normally; this never refreshes knowledge or authorizes a shot.
			if low_health or actor.pinned_time>0 or actor.magazine_reload_remaining>0:
				order.until=clock+1.5
				return
			if order.cover.has("peek"):
				var path:=_peek_path(actor,order.cover.point,order.cover.peek,threat)
				if not path.is_empty():
					_issue(actor,"peek_move",order.cover.peek,path,{"cover":order.cover,"until":clock+3.0,"crouch":false})
					return
			# A protected but unusable firing position is reconsidered periodically.
			# Keep its protection if no better reachable cover exists this cycle.
			safe_hold=order.cover
			_remember_failed_goal(actor,safe_hold.point)
		if not order.is_empty() and order.kind=="peek":
			var route:=path_to(actor.global_position,order.cover.point,actor)
			if not route.is_empty():
				_issue(actor,"return_cover",order.cover.point,route,{"cover":order.cover,"until":clock+3.0,"crouch":order.cover.crouch})
				return
			_remember_failed_goal(actor,order.cover.point)
		if not order.is_empty() and moving and order.kind!="flank":
			# A useful checked route continues between planner turns; its real
			# progress watchdog above, rather than a short order deadline, owns it.
			order.until=clock+2.0
			return
		if not order.is_empty() and order.kind=="flank":
			_abort_flank("timeout")
	var gap: float=_flat(actor.global_position,threat)
	if float(info.age)<=6.0 and not low_health and clock>=float(_join_after.get(actor,0.0)) and gap>JOIN_RANGE and (gap>JOIN_LANE_LIMIT or not sightline(actor.global_position+Vector3.UP*1.5,threat+Vector3.UP*1.2)):
		_join_after[actor]=clock+JOIN_COOLDOWN
		if _join_fight(actor,threat): return
	if float(info.age)>6.0:
		# Search assignment follows the reported location and completed visits,
		# never a wall-clock phase. Replanning a blocked route keeps its sector.
		var search: Dictionary=_search_state.get(actor,{})
		if search.is_empty() or _flat(search.origin,threat)>4.0:
			search={"origin":threat,"step":0}
			_search_state[actor]=search
		var sector: int=maxi(0,crew.members.find(actor))
		var member_count: int=maxi(1,crew.members.size())
		# Search where a moving enemy was heading, not only where they were last seen.
		var lead: Vector3=(info.get("heading",Vector3.ZERO) as Vector3)*SEARCH_LEAD_SECONDS
		var center: Vector3=threat+lead.limit_length(SEARCH_LEAD_MAX)
		# A blocked sector rolls on to the next bearing rather than leaving them idle.
		for attempt: int in SEARCH_BEARING_TRIES:
			var angle:=float(sector)*TAU/float(member_count)+float(search.step)*.45+float(attempt)*.9
			var goal: Vector3=crew.get_nearest_walkable_world(center+Vector3(cos(angle),0,sin(angle))*7.0)
			var route:=path_to(actor.global_position,goal,actor) if not _goal_failed(actor,goal) and not claimed(goal,actor) else PackedVector3Array()
			if not route.is_empty() and _flat(actor.global_position,goal)>.65:
				_issue(actor,"search_sector",goal,route,{"until":clock+5.0,"pace":SEARCH_PACE})
				return
	# Being pinned calls for protection, not an automatic outward displacement.
	var cover:=find_cover(actor,threat,low_health)
	if not cover.is_empty():
		_issue(actor,"retreat" if low_health else "move_cover",cover.point,cover.path,{"cover":cover,"crouch":false,"until":clock+12.0})
		return
	if not safe_hold.is_empty():
		_issue(actor,"hold_cover",safe_hold.point,PackedVector3Array(),{"cover":safe_hold,"until":clock+3.0,"crouch":safe_hold.crouch})
		return
	if low_health:
		var away: Vector3=actor.global_position-threat; away.y=0
		var goal: Vector3=crew.get_nearest_walkable_world(actor.global_position+away.normalized()*7.0)
		var route:=path_to(actor.global_position,goal,actor) if not _goal_failed(actor,goal) and not claimed(goal,actor) else PackedVector3Array()
		if not route.is_empty() and _flat(goal,threat)>_flat(actor.global_position,threat)+2.0:
			_issue(actor,"reposition",goal,route,{"until":clock+4.0})
			return
	elif clock>=float(_lateral_after.get(actor,0.0)):
		_lateral_after[actor]=clock+LATERAL_COOLDOWN
		var toward: Vector3=threat-actor.global_position; toward.y=0
		var side:=Vector3(-toward.z,0,toward.x).normalized()
		for sign_value: float in [-1.0,1.0]:
			var goal: Vector3=crew.get_nearest_walkable_world(actor.global_position+side*sign_value*2.5)
			if _goal_failed(actor,goal) or claimed(goal,actor) or _flat(goal,threat)<=2.0 or absf(_flat(goal,threat)-_flat(actor.global_position,threat))>1.25: continue
			var route:=path_to(actor.global_position,goal,actor)
			if route.is_empty() or path_length(route,actor.global_position)>5.0 or _flat(goal,actor.global_position)<1.0: continue
			if not sightline(goal+Vector3.UP*MUZZLE_HEIGHT,threat+Vector3.UP*1.2): continue
			_issue(actor,"reposition",goal,route,{"until":clock+4.0})
			return
	# Healthy members with a clear useful lane engage instead of repeatedly
	# withdrawing three metres. Own sight, aim and friendly-fire gates still apply.
	_issue(actor,"observe",actor.global_position,PackedVector3Array(),{"until":clock+1.5,"crouch":_flat(actor.global_position,threat)>KNEEL_RANGE})

## The moment a person walking a route spots the enemy, without waiting a planner
## turn: by then a glimpse through a gap has already gone behind them.
func sighted(actor: CharacterBody3D) -> void:
	var order: Dictionary=orders.get(actor,{})
	var info:=contact(actor)
	if not order.is_empty() and not info.is_empty() and _should_return_fire(actor,order,info.point): _return_fire(actor)

func _return_fire(actor: CharacterBody3D) -> void:
	_reaction_after[actor]=clock+REACTION_COOLDOWN
	send(actor,"returning_fire")
	_issue(actor,"observe",actor.global_position,PackedVector3Array(),{"until":clock+REACTION_SECONDS})

func _should_return_fire(actor: CharacterBody3D, order: Dictionary, threat: Vector3) -> bool:
	if not order.kind in ["move_cover","reposition","search_sector","return_cover"] or actor==flank_actor: return false
	if clock<float(_reaction_after.get(actor,0.0)) or not actor.can_fire_now(): return false
	return actor.own_visual_time<=.3 and _flat(actor.global_position,threat)<REACTION_RANGE

# Walk a crewmate in along the real route, then let cover near that point decide
# where they end up. Open ground with no cover still closes the distance.
func _join_fight(actor: CharacterBody3D, threat: Vector3) -> bool:
	var route: PackedVector3Array=crew.get_path_world(actor.global_position,crew.get_nearest_walkable_world(threat))
	if route.is_empty() or path_length(route,actor.global_position)>JOIN_ROUTE_LIMIT: return false
	var anchor: Vector3=route[-1]
	for point: Vector3 in route:
		if _flat(point,threat)<=JOIN_STANDOFF: anchor=point; break
	var cover:=find_cover(actor,threat,false,anchor,7.0,JOIN_ROUTE_LIMIT)
	if not cover.is_empty():
		send(actor,"joining_fight")
		_issue(actor,"move_cover",cover.point,cover.path,{"cover":cover,"crouch":false,"until":clock+12.0})
		return true
	var walk:=path_to(actor.global_position,anchor,actor)
	if walk.is_empty(): return false
	send(actor,"joining_fight")
	_issue(actor,"reposition",anchor,walk,{"until":clock+4.0})
	return true

func _remember_failed_goal(actor: CharacterBody3D, point: Vector3) -> void:
	var recent: Array=_failed_goals.get(actor,[])
	for index: int in range(recent.size()-1,-1,-1):
		if clock>=float(recent[index].until) or _flat(recent[index].point,point)<1.25: recent.remove_at(index)
	recent.append({"point":point,"until":clock+FAILED_GOAL_SECONDS})
	# The fixed cover fan has at most 25 candidates; retain its failures without
	# evicting the last blocked movement goal during the same planner pass.
	while recent.size()>32: recent.pop_front()
	_failed_goals[actor]=recent

func _goal_failed(actor: CharacterBody3D, point: Vector3) -> bool:
	var recent: Array=_failed_goals.get(actor,[])
	for entry: Dictionary in recent:
		if clock<float(entry.until) and _flat(entry.point,point)<1.25: return true
	return false

func permits_fire(actor: CharacterBody3D) -> bool:
	# Cover that gives a personal view of the enemy gives them a view back.
	var kind: String=orders.get(actor,{}).get("kind","")
	return kind in ["peek","observe","hold_cover"] and actor.pinned_time<=0

# The order permits covering, but an empty or reloading weapon cannot provide
# it. Maintenance keeps the existing 2.2-second interruption grace in tick().
func _ready_to_cover(actor: CharacterBody3D) -> bool:
	return permits_fire(actor) and actor.weapon_rounds>0 and actor.magazine_reload_remaining<=0.0

func _abort_flank(reason: String) -> void:
	if alive(flank_actor):
		send(flank_actor,"flank_aborted",{"reason":reason})
		orders.erase(flank_actor)
	flank_actor=null; flank_support=null; unsupported_time=0; flank_cooldown=8.0

func _try_flank() -> void:
	# One mover, one confirmed covering gun. A position report alone is not support.
	var support: CharacterBody3D
	for actor: CharacterBody3D in crew.members:
		if not alive(actor) or actor.health/actor.max_health<=.4 or not _ready_to_cover(actor): continue
		var known:=contact(actor)
		if known.is_empty() or known.kind!="visual" or float(known.age)>3.5: continue
		if sightline(actor.global_position+Vector3.UP*1.5,known.point+Vector3.UP*1.2): support=actor; break
	if support==null: return
	for actor: CharacterBody3D in crew.members:
		if not alive(actor) or actor==support or actor.health/actor.max_health<.6 or actor.pinned_time>0: continue
		var info:=contact(actor)
		if info.is_empty() or float(info.age)>2.5 or float(info.confidence)<.65 or _flat(actor.global_position,support.global_position)>RADIO_RANGE: continue
		var plan:=plan_flank(actor,support,info.point)
		if plan.is_empty(): continue
		flank_actor=actor; flank_support=support; unsupported_time=0.0
		_issue(actor,"flank",plan.goal,plan.path,{"until":clock+minf(24.0,plan.length/actor.move_speed+5.0),"cover":plan.cover,"threat":info.point,"crouch":false})
		# Keep the covering gun exposed for a bounded window; it may still leave
		# if hit, its cover is compromised, or health drops.
		var support_order: Dictionary=orders[support]
		support_order.until=clock+minf(16.0,plan.length/actor.move_speed+2.0)
		send(support,"covering_flank",{"teammate":actor.name,"teammate_position":actor.global_position})
		return

func plan_flank(actor: CharacterBody3D, support: CharacterBody3D, threat: Vector3) -> Dictionary:
	var away: Vector3=actor.global_position-threat; away.y=0
	if away.length()<7.0 or away.length()>28.0: return {}
	away=away.normalized()
	var side:=Vector3(-away.z,0,away.x)
	var best: Dictionary={}; var best_score:=INF
	for sign_value: float in [-1.0,1.0]:
		var entry: Vector3=crew.get_nearest_walkable_world(actor.global_position+side*sign_value*10.0)
		var anchor: Vector3=crew.get_nearest_walkable_world(threat+side*sign_value*13.0+away*3.0)
		var cover:=find_cover(actor,threat,false,anchor,7.0)
		if cover.is_empty() or not cover.has("peek"): continue
		var goal: Vector3=cover.point
		var from_enemy: Vector3=(goal-threat).normalized()
		var support_angle: Vector3=(support.global_position-threat).normalized()
		if acos(clampf(from_enemy.dot(support_angle),-1,1))<deg_to_rad(38): continue
		var first:=path_to(actor.global_position,entry,actor)
		var second:=path_to(entry,goal,actor)
		if first.is_empty() or second.is_empty(): continue
		var route:=first.duplicate(); route.append_array(second)
		var length:=0.0; var previous:=actor.global_position; var safe:=true
		for point: Vector3 in route:
			var step:=previous.distance_to(point)
			if _segment_distance(threat,previous,point)<6.5: safe=false; break
			length+=step
			previous=point
		if not safe or length>44.0 or length<8.0: continue
		var exposure:=_route_exposure(route,actor.global_position,threat)
		if exposure/maxf(length,.01)>.68: continue
		var score:=length+exposure*1.5
		if score<best_score: best_score=score; best={"goal":goal,"path":route,"cover":cover,"length":length,"exposure":exposure}
	return best

func find_cover(actor: CharacterBody3D, threat: Vector3, retreat: bool=false, center: Vector3=Vector3.INF, radius: float=17.0, reach: float=33.0) -> Dictionary:
	if not center.is_finite(): center=actor.global_position
	var candidates: Array[Vector3]=[]
	# Cast a small fixed fan from local samples toward the reported threat. The
	# first hit's outward normal identifies the protected side of real geometry.
	for ring: float in [0.0,5.0,10.0,15.0]:
		if ring>radius: continue
		for i: int in range(1 if ring==0 else 8):
			var angle:=float(i)*TAU/8.0
			var sample: Vector3=center+Vector3(cos(angle),0,sin(angle))*ring
			var from: Vector3=sample+Vector3.UP*1.05
			var hit:=ray(from,threat+Vector3.UP*1.05)
			if hit.is_empty() or from.distance_to(hit.position)>radius+2.0: continue
			var normal: Vector3=hit.normal; normal.y=0
			if normal.length()<.2: continue
			var floor:=floor_point(hit.position+normal.normalized()*.68,actor)
			if floor.is_finite() and _flat(floor,center)<radius+1.0: candidates.append(floor)
	var best: Dictionary={}; var score_best:=INF
	for point: Vector3 in candidates:
		if _flat(point,threat)<=2.0 or _goal_failed(actor,point) or claimed(point,actor) or not clear_at(point,actor,false): continue
		var crouch:=not protected_at(point,threat,false)
		if crouch and not protected_at(point,threat,true): continue
		var route:=path_to(actor.global_position,point,actor)
		if route.is_empty():
			_remember_failed_goal(actor,point)
			continue
		var length:=path_length(route,actor.global_position)
		if length>reach or (retreat and _flat(point,threat)<_flat(actor.global_position,threat)+2): continue
		var slot: Dictionary={"point":point,"crouch":crouch,"path":route}
		var away: Vector3=(point-threat).normalized()
		var side:=Vector3(-away.z,0,away.x)
		for distance: float in [.95,1.5,2.1]:
			for sign_value: float in [-1.0,1.0]:
				var peek:=floor_point(point+side*sign_value*distance,actor)
				if not peek.is_finite() or claimed(peek,actor): continue
				if not _peek_path(actor,point,peek,threat).is_empty(): slot.peek=peek; break
			if slot.has("peek"): break
		var close_risk: float=maxf(0.0,5.5-_flat(point,threat))*1.5
		var exposed:=_route_exposure(route,actor.global_position,threat)
		var score:=length+exposed*1.5+close_risk+(_flat(point,threat)*-.12 if retreat else absf(_flat(point,threat)-13.0)*.15)+(0.0 if slot.has("peek") else 5.0)
		if score<score_best: score_best=score; best=slot
	return best

# A peek must be a short, traversable excursion beside its cover. AStar
# reachability alone can lead around an entire wall to a point one metre away.
func _peek_path(actor: CharacterBody3D, point: Vector3, peek: Vector3, threat: Vector3) -> PackedVector3Array:
	if claimed(peek,actor) or _flat(peek,threat)<=2.0 or not clear_at(peek,actor,false): return PackedVector3Array()
	if not sightline(peek+Vector3.UP*MUZZLE_HEIGHT,threat+Vector3.UP*1.2): return PackedVector3Array()
	var route:=path_to(point,peek,actor)
	if path_length(route,point)>minf(3.5,_flat(point,peek)*1.6+.3): return PackedVector3Array()
	return route

# Sample the full route, rather than a long segment's single midpoint, using
# only reported threat geometry. This ranks a sheltered approach above an open
# shortcut without inventing knowledge of the enemy's current position.
func _route_exposure(route: PackedVector3Array, start: Vector3, threat: Vector3) -> float:
	var exposed:=0.0
	for point: Vector3 in route:
		var distance:=start.distance_to(point)
		var samples: int=maxi(1,int(ceil(distance/2.0)))
		for index: int in range(samples):
			var sample:=start.lerp(point,(float(index)+.5)/float(samples))
			if sightline(sample+Vector3.UP*1.2,threat+Vector3.UP*1.3): exposed+=distance/float(samples)
		start=point
	return exposed

func claimed(point: Vector3, actor: CharacterBody3D) -> bool:
	for peer: CharacterBody3D in orders:
		if peer==actor or not alive(peer): continue
		var data: Dictionary=orders[peer]
		if data.has("cover"):
			if _flat(data.cover.point,point)<1.7: return true
			if data.cover.has("peek") and _flat(data.cover.peek,point)<1.2: return true
		if data.kind in ["search_sector","reposition","retreat","flank","move_cover","peek_move","return_cover"] and _flat(data.goal,point)<1.4: return true
	return false

func protected_at(point: Vector3, threat: Vector3, crouch: bool) -> bool:
	var head: float=1.03 if crouch else 1.58
	return not sightline(threat+Vector3.UP*1.35,point+Vector3.UP*head) and not sightline(threat+Vector3.UP*1.35,point+Vector3.UP*(head*.65))

func sightline(from: Vector3, to: Vector3) -> bool:
	return ray(from,to).is_empty()

func ray(from: Vector3, to: Vector3) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(from,to,1)
	# The installed player shares the world's collision layer. Geometry tests
	# must ignore that body, otherwise every clear peek ends inside a 'wall'.
	var player: Node=crew.raid.get("player")
	if player is CollisionObject3D: query.exclude=[player.get_rid()]
	return crew.get_world_3d().direct_space_state.intersect_ray(query)

func floor_point(point: Vector3, actor: CharacterBody3D) -> Vector3:
	var hit:=ray(point+Vector3.UP*2.0,point-Vector3.UP*3.0)
	if hit.is_empty() or hit.normal.y<.72: return Vector3.INF
	var result: Vector3=hit.position+Vector3.UP*.025
	if not clear_at(result,actor,false): return Vector3.INF
	return result

func clear_at(point: Vector3, actor: CharacterBody3D, crouch: bool) -> bool:
	var shape:=CapsuleShape3D.new(); shape.radius=.35; shape.height=1.1 if crouch else 1.72
	var query:=PhysicsShapeQueryParameters3D.new(); query.shape=shape; query.collision_mask=1|2
	query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*(shape.height*.5+.015))
	if is_instance_valid(actor): query.exclude=[actor.get_rid()]
	return crew.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func path_to(from: Vector3, to: Vector3, actor: CharacterBody3D) -> PackedVector3Array:
	var result: PackedVector3Array=crew.get_path_world(from,to)
	if result.is_empty(): return result
	# AStar endpoints are grid centres. Exact cover is appended only after the
	# same floor/obstacle edge check used by the installed park navigation.
	var nav: RefCounted=crew.navigation
	var previous: Vector3=from
	var output:=PackedVector3Array()
	for point: Vector3 in result:
		if _flat(previous,point)<.2: continue
		if output.is_empty() and not nav._can_walk_edge(Vector2(from.x,from.z),Vector2(point.x,point.z)): return PackedVector3Array()
		output.append(point); previous=point
	if not nav._can_walk_edge(Vector2(previous.x,previous.z),Vector2(to.x,to.z)) or not clear_at(to,actor,false): return PackedVector3Array()
	if output.is_empty() or _flat(output[-1],to)>.1: output.append(to)
	return output

func path_length(path: PackedVector3Array, start: Vector3) -> float:
	var length:=0.0
	for point: Vector3 in path: length+=start.distance_to(point); start=point
	return length

func _flat(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func _segment_distance(point: Vector3,a: Vector3,b: Vector3) -> float:
	return Vector2(point.x,point.z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(point.x,point.z),Vector2(a.x,a.z),Vector2(b.x,b.z)))

func member_down(actor: CharacterBody3D) -> void:
	send(actor,"member_down")
	if actor==flank_actor or actor==flank_support: _abort_flank("teammate_down")
	orders.erase(actor); knowledge.erase(actor); positions.erase(actor)
	_failed_goals.erase(actor); _lateral_after.erase(actor); _search_state.erase(actor)
	_join_after.erase(actor); _reaction_after.erase(actor)
