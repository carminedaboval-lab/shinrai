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
const REACTION_RANGE:=32.0
const REACTION_SECONDS:=1.5
const REACTION_COOLDOWN:=6.0
# A flanker who gets a clean look this close has found the angle: stop and use it.
const FLANK_ENGAGE_RANGE:=16.0
# Fire and movement: one who can see the enemy shoots while the others move. Each member
# takes that turn at most once per this many seconds.
const COVERING_SECONDS_MIN:=2.2
const COVERING_SECONDS_MAX:=3.0
const COVERING_COOLDOWN:=7.0
# A shooter whose rifle is blocked by something close for this long changes position.
const LANE_BLOCKED_SECONDS:=.45
# Nobody has seen the enemy for this long: stop staring at the empty spot and hunt.
const LOST_SECONDS:=5.0
const HUNT_SECONDS:=55.0
const HUNT_RINGS: Array[float]=[6.0,12.0,19.0,27.0]
const HUNT_CLEAR_RANGE:=13.0
const HUNT_PACE:=.85
const HUNT_LOOK_MIN:=1.0
const HUNT_LOOK_MAX:=1.7
const GUARD_SECONDS:=18.0
const RELOAD_TOPUP_ROUNDS:=10
const SEARCH_LEAD_SECONDS:=2.5
const SEARCH_LEAD_MAX:=10.0
# A firing spot needs a lane for the rifle: eyes clear low cover that the gun hits.
# Measured on the scav model: an aimed rifle's muzzle sits 0.9-1.1 m up, well below the
# eyes at 1.5 m. fire_lane() checks this height and a little under it.
const MUZZLE_HEIGHT:=1.0
const MUZZLE_MARGIN:=.14
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
var _cover_after: Dictionary={}
var _angle_after: Dictionary={}
## The search for an enemy the crew has lost: where they were, the spots still to check.
var hunt: Dictionary={}

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
	if kind=="sound":
		# One shot gives a rough idea; each further shot from the same place narrows it.
		var heard: Dictionary=knowledge.get(actor,{})
		if not heard.is_empty() and heard.kind=="sound" and clock-float(heard.time)<6.0 and _flat(heard.point,point)<30.0:
			point=(heard.point as Vector3).lerp(point,.4)
		# A new noise while hunting moves the hunt there.
		if hunting() and _flat(hunt.center,point)>8.0: _begin_hunt(point,Vector3.ZERO)
	else:
		_end_hunt()
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
	if hunting(): _hunt_mark_seen()
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
	# Nobody has laid eyes on the enemy for a while: the crew stops watching the empty
	# spot and goes looking, together.
	if not hunting() and not info.is_empty() and float(info.age)>LOST_SECONDS and clock-float(crew.last_visual_report)>LOST_SECONDS:
		_begin_hunt(info.point,info.get("heading",Vector3.ZERO))
	if hunting():
		_hunt_step(actor)
		return
	if info.is_empty():
		orders.erase(actor)
		return
	var threat: Vector3=info.point
	var order: Dictionary=orders.get(actor,{})
	var safe_hold: Dictionary={}
	# An empty rifle has no more business in the open than a wounded man.
	var low_health: bool=actor.health/actor.max_health<.32 or actor.out_of_ammo()
	# The one giving covering fire in the open gets down the moment rounds come back.
	if not order.is_empty() and order.kind=="observe" and order.get("covering",false) and actor.pinned_time>0:
		orders.erase(actor); order={}
	# Eyes over the cover but the rifle into it: shift to where the barrel clears.
	if not order.is_empty() and order.kind in ["peek","observe","hold_cover"] and actor.lane_blocked_time>LANE_BLOCKED_SECONDS:
		actor.lane_blocked_time=0.0
		send(actor,"lane_blocked")
		if order.kind=="peek" and order.has("cover"):
			var wider:=_wider_peek(actor,order.cover,threat)
			if not wider.is_empty():
				order.cover.peek=wider.peek
				_issue(actor,"peek_move",wider.peek,wider.path,{"cover":order.cover,"until":clock+3.0,"crouch":false})
				return
			_remember_failed_goal(actor,order.cover.point)
		else:
			_remember_failed_goal(actor,actor.global_position)
		_lateral_after[actor]=0.0
		orders.erase(actor); order={}
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
	# Fire and movement: if nobody is shooting yet and this one can, they shoot first.
	if not low_health and float(info.age)<2.5 and _covering_shot(actor,threat): return
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
			if not fire_lane(goal,threat): continue
			_issue(actor,"reposition",goal,route,{"until":clock+4.0})
			return
	# Crouched somewhere with no view while the others fight is no use to anyone: walk to
	# the nearest spot the rifle can reach the reported enemy from.
	if not low_health and actor.own_visual_time>2.0 and float(info.age)<6.0 and clock>=float(_angle_after.get(actor,0.0)):
		_angle_after[actor]=clock+5.0
		var angle:=_find_angle(actor,threat)
		if not angle.is_empty():
			send(actor,"finding_angle")
			_issue(actor,"reposition",angle.goal,angle.path,{"until":clock+5.0})
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
	if actor==flank_actor:
		send(actor,"flank_engaging")
		flank_actor=null; flank_support=null; unsupported_time=0; flank_cooldown=9.0
	send(actor,"returning_fire")
	_issue(actor,"observe",actor.global_position,PackedVector3Array(),{"until":clock+REACTION_SECONDS})

func _should_return_fire(actor: CharacterBody3D, order: Dictionary, threat: Vector3) -> bool:
	if not order.kind in ["move_cover","reposition","search_sector","return_cover","peek_move","flank"]: return false
	if clock<float(_reaction_after.get(actor,0.0)) or not actor.can_fire_now(): return false
	if actor.own_visual_time>.3: return false
	var gap: float=_flat(actor.global_position,threat)
	if gap>=(FLANK_ENGAGE_RANGE if actor==flank_actor else REACTION_RANGE): return false
	# Stopping in the open is only worth it where the rifle can actually reach.
	return fire_lane(actor.global_position,threat)

## One member who can see the enemy shoots while the rest get to cover. Never two at once,
## and each takes the turn only now and then, so nobody stands in the open for long.
func _covering_shot(actor: CharacterBody3D, threat: Vector3) -> bool:
	if clock<float(_cover_after.get(actor,0.0)) or actor.own_visual_time>.3 or not actor.can_fire_now(): return false
	if not fire_lane(actor.global_position,threat): return false
	for peer: CharacterBody3D in crew.members:
		if peer==actor or not alive(peer): continue
		if _ready_to_cover(peer) and peer.own_visual_time<.6: return false
	_cover_after[actor]=clock+COVERING_COOLDOWN
	send(actor,"covering_fire")
	crew.callout(actor,"Covering!")
	_issue(actor,"observe",actor.global_position,PackedVector3Array(),{"until":clock+randf_range(COVERING_SECONDS_MIN,COVERING_SECONDS_MAX),"crouch":_flat(actor.global_position,threat)>KNEEL_RANGE,"covering":true})
	return true

## Can a rifle held at this spot reach the reported enemy? Two rays: the muzzle line and a
## little below it, because cover that the eyes clear often stops the barrel.
func fire_lane(point: Vector3, threat: Vector3) -> bool:
	return sightline(point+Vector3.UP*MUZZLE_HEIGHT,threat+Vector3.UP*1.2) and sightline(point+Vector3.UP*(MUZZLE_HEIGHT-MUZZLE_MARGIN),threat+Vector3.UP*1.1)

## The shortest walk to somewhere a rifle can reach the reported enemy, not too close to them.
func _find_angle(actor: CharacterBody3D, threat: Vector3) -> Dictionary:
	var best: Dictionary={}; var best_length:=INF
	for radius: float in [3.0,6.0,9.0]:
		for i: int in 8:
			var bearing:=float(i)*TAU/8.0+radius*.2
			var goal: Vector3=crew.get_nearest_walkable_world(actor.global_position+Vector3(cos(bearing),0,sin(bearing))*radius)
			if not goal.is_finite() or _flat(goal,actor.global_position)<1.5 or _flat(goal,threat)<7.0: continue
			if _goal_failed(actor,goal) or claimed(goal,actor) or not fire_lane(goal,threat): continue
			var route:=path_to(actor.global_position,goal,actor)
			if route.is_empty(): continue
			var length:=path_length(route,actor.global_position)
			if length<best_length: best_length=length; best={"goal":goal,"path":route}
		if not best.is_empty(): break
	return best

## A step further out along the cover when the first peek spot left the rifle blocked.
func _wider_peek(actor: CharacterBody3D, cover: Dictionary, threat: Vector3) -> Dictionary:
	var away: Vector3=cover.point-threat; away.y=0
	if away.length()<.1: return {}
	away=away.normalized()
	var side:=Vector3(-away.z,0,away.x)
	for distance: float in [2.1,2.8,3.6,4.4]:
		for sign_value: float in [-1.0,1.0]:
			var peek:=floor_point(cover.point+side*sign_value*distance,actor)
			if not peek.is_finite() or _goal_failed(actor,peek) or claimed(peek,actor): continue
			if _peek_path(actor,cover.point,peek,threat).is_empty(): continue
			var route:=path_to(actor.global_position,peek,actor)
			if route.is_empty() or path_length(route,actor.global_position)>7.0: continue
			return {"peek":peek,"path":route}
	return {}

# ---- the hunt: looking for an enemy the crew has lost --------------------------------

func hunting() -> bool:
	return not hunt.is_empty()

func _end_hunt() -> void:
	if hunt.is_empty(): return
	hunt={}
	for actor: CharacterBody3D in crew.members:
		if alive(actor) and orders.has(actor) and orders[actor].get("hunt",false): orders.erase(actor)

## Lists the places worth checking: where they were last seen, then rings outward from
## there, leaning the way they were heading.
func _begin_hunt(origin: Vector3, heading: Vector3) -> void:
	if not origin.is_finite(): return
	if alive(flank_actor): _abort_flank("contact_lost")
	heading.y=0
	var center: Vector3=origin+(heading*SEARCH_LEAD_SECONDS).limit_length(SEARCH_LEAD_MAX)
	var spots: Array[Dictionary]=[]
	var first: Vector3=crew.get_nearest_walkable_world(origin)
	if first.is_finite(): spots.append({"point":first,"ring":0,"bias":0.0,"cleared":false})
	for ring_index: int in HUNT_RINGS.size():
		for i: int in 8:
			var angle:=float(i)*TAU/8.0+float(ring_index)*.39
			var direction:=Vector3(cos(angle),0,sin(angle))
			var goal: Vector3=crew.get_nearest_walkable_world(center+direction*HUNT_RINGS[ring_index])
			if not goal.is_finite(): continue
			var repeated:=false
			for spot: Dictionary in spots:
				if _flat(spot.point,goal)<3.5: repeated=true; break
			if repeated: continue
			# Places along the way they were going are checked before the ones behind.
			var bias: float=-direction.dot(heading.normalized())*5.0 if heading.length()>.5 else 0.0
			spots.append({"point":goal,"ring":ring_index+1,"bias":bias,"cleared":false})
	var first_hunt: bool=hunt.is_empty()
	hunt={"origin":origin,"center":center,"started":clock,"spots":spots,"guard_from":-1.0}
	for actor: CharacterBody3D in crew.members:
		if alive(actor): orders.erase(actor)
	var speaker: CharacterBody3D=crew.leader()
	if alive(speaker):
		send(speaker,"hunt_started",{"spots":spots.size()})
		if first_hunt: crew.callout(speaker,"Lost him. Sweep it.")

## A spot is cleared when someone has stood on it or has plainly looked at it from close by.
func _hunt_mark_seen() -> void:
	for spot: Dictionary in hunt.spots:
		if spot.cleared: continue
		for actor: CharacterBody3D in crew.members:
			if not alive(actor): continue
			var gap: float=_flat(actor.global_position,spot.point)
			if gap<1.6: spot.cleared=true; break
			if gap>HUNT_CLEAR_RANGE: continue
			var toward: Vector3=spot.point-actor.global_position; toward.y=0
			var facing: Vector3=-actor.global_basis.z; facing.y=0
			if facing.normalized().dot(toward.normalized())<.45: continue
			if sightline(actor.global_position+Vector3.UP*1.5,spot.point+Vector3.UP*1.0): spot.cleared=true; break

func _hunt_remaining() -> int:
	var count:=0
	for spot: Dictionary in hunt.spots:
		if not spot.cleared: count+=1
	return count

## The member who stays back with a rifle up while the others walk the spots.
func _hunt_overwatch() -> CharacterBody3D:
	var living: Array[CharacterBody3D]=[]
	for actor: CharacterBody3D in crew.members:
		if alive(actor): living.append(actor)
	if living.size()<3: return null
	# The one hurt worst watches; otherwise the rear guard.
	var chosen: CharacterBody3D=living[-1]
	for actor: CharacterBody3D in living:
		if actor.health/actor.max_health<chosen.health/chosen.max_health-.15: chosen=actor
	return chosen

func _hunt_step(actor: CharacterBody3D) -> void:
	var order: Dictionary=orders.get(actor,{})
	if not order.is_empty() and not order.get("hunt",false):
		orders.erase(actor); order={}
	# Time is up or everything has been looked at: hold and watch for a while, then stand down.
	if clock-float(hunt.started)>HUNT_SECONDS or _hunt_remaining()==0:
		if float(hunt.guard_from)<0.0:
			hunt.guard_from=clock
			var speaker: CharacterBody3D=crew.leader()
			if alive(speaker):
				send(speaker,"hunt_guard")
				crew.callout(speaker,"Nothing. Stay sharp.")
		if clock-float(hunt.guard_from)>GUARD_SECONDS:
			send(actor,"hunt_over")
			_end_hunt()
			for member: CharacterBody3D in crew.members:
				if alive(member): member._enter_state(member.AIState.RETURN_TO_PATROL)
			return
		if order.is_empty() or order.kind!="observe":
			_issue(actor,"observe",actor.global_position,PackedVector3Array(),{"until":float(hunt.guard_from)+GUARD_SECONDS+1.0,"crouch":true,"hunt":true})
			actor.last_seen_position=_hunt_look_point(actor)
		return
	if not order.is_empty() and order.kind=="search_sector":
		var spot: Dictionary=order.spot
		if float(order.route_remaining)<float(order.best_remaining)-.35:
			order.best_remaining=order.route_remaining
			order.last_progress=clock
		if _flat(actor.global_position,order.goal)<.6 or spot.cleared:
			spot.cleared=true
			# Stop and look before moving on, towards the nearest place nobody has checked.
			_issue(actor,"observe",actor.global_position,PackedVector3Array(),{"until":clock+randf_range(HUNT_LOOK_MIN,HUNT_LOOK_MAX),"hunt":true})
			actor.last_seen_position=_hunt_look_point(actor)
			return
		if clock-float(order.last_progress)>3.2:
			_remember_failed_goal(actor,order.goal)
			spot.cleared=true
			send(actor,"route_blocked")
			orders.erase(actor); order={}
		else:
			order.until=clock+2.0
			return
	if not order.is_empty() and clock<float(order.until): return
	if actor==_hunt_overwatch():
		_issue(actor,"observe",actor.global_position,PackedVector3Array(),{"until":clock+2.5,"crouch":true,"hunt":true})
		actor.last_seen_position=_hunt_look_point(actor)
		return
	# Near first, inner rings first, the way they were heading first; and a place the crew
	# cannot see from where it stands is where someone would be hiding. Rank by straight-line
	# distance, then work out real routes for the few best only: a route per spot in one
	# tick is a visible hitch.
	var ranked: Array[Dictionary]=[]
	for spot: Dictionary in hunt.spots:
		if spot.cleared or _goal_failed(actor,spot.point) or claimed(spot.point,actor): continue
		var hidden: bool=true
		for peer: CharacterBody3D in crew.members:
			if alive(peer) and sightline(peer.global_position+Vector3.UP*1.5,spot.point+Vector3.UP*1.0): hidden=false; break
		ranked.append({"spot":spot,"score":_flat(actor.global_position,spot.point)+float(spot.ring)*4.0+float(spot.bias)-(6.0 if hidden else 0.0)})
	ranked.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return float(a.score)<float(b.score))
	var best: Dictionary={}; var best_route:=PackedVector3Array()
	for index: int in mini(ranked.size(),4):
		var candidate: Dictionary=ranked[index].spot
		var route:=path_to(actor.global_position,candidate.point,actor)
		if route.is_empty():
			_remember_failed_goal(actor,candidate.point)
			continue
		best=candidate; best_route=route
		break
	if best.is_empty():
		_issue(actor,"observe",actor.global_position,PackedVector3Array(),{"until":clock+1.5,"crouch":true,"hunt":true})
		actor.last_seen_position=_hunt_look_point(actor)
		return
	_issue(actor,"search_sector",best.point,best_route,{"until":clock+6.0,"pace":HUNT_PACE,"spot":best,"hunt":true})

## Where a hunter who has stopped should be looking: the nearest unchecked place, or the
## last seen point when nothing is left.
func _hunt_look_point(actor: CharacterBody3D) -> Vector3:
	var best: Vector3=hunt.center; var nearest:=INF
	for spot: Dictionary in hunt.spots:
		if spot.cleared: continue
		var gap: float=_flat(actor.global_position,spot.point)
		if gap>2.5 and gap<nearest: nearest=gap; best=spot.point
	return best

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
		if not sightline(actor.global_position+Vector3.UP*1.5,known.point+Vector3.UP*1.2): continue
		# A gun already behind cover makes the better support: it can stay up longer.
		if support==null or (orders[actor].has("cover") and not orders[support].has("cover")): support=actor
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
		support_order.until=clock+minf(9.0 if support_order.has("cover") else 5.0,plan.length/actor.move_speed+2.0)
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
	if not fire_lane(peek,threat): return PackedVector3Array()
	var route:=path_to(point,peek,actor)
	if path_length(route,point)>minf(6.0,_flat(point,peek)*1.6+.3): return PackedVector3Array()
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
		# Someone pressed up against their cover fails the full-width check for the first
		# step. A clear line at knee and chest height to a point this close is enough: the
		# body slides off the cover as it sets out.
		if output.is_empty() and not nav._can_walk_edge(Vector2(from.x,from.z),Vector2(point.x,point.z)):
			if _flat(from,point)>2.5 or not sightline(from+Vector3.UP*.45,point+Vector3.UP*.45) or not sightline(from+Vector3.UP*1.2,point+Vector3.UP*1.2): return PackedVector3Array()
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
	_join_after.erase(actor); _reaction_after.erase(actor); _cover_after.erase(actor); _angle_after.erase(actor)
