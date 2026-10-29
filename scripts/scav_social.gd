extends RefCounted
## Quiet crew conversation and visual attention; never supplies enemy knowledge.
var crew: Node3D
var audio_root: String="res://assets/audio/scav_chatter"
var lines: Dictionary={}
var streams: Dictionary={}
var voices: Dictionary={}
var clock:=0.0
var next_chat:=12.0
var last_exchange: String=""
var pending: Array[Dictionary]=[]
var active_voice: AudioStreamPlayer3D
var caption: Label3D
var line_ends:=0.0
var line_started:=0.0
var reply_at:=0.0
var enabled:=true
var ready:=false
var looks: Dictionary={}
var next_look: Dictionary={}
var history: Array[Dictionary]=[]
var last_mode: String=""
var last_hold:=false
var last_routine: String=""
var rng:=RandomNumberGenerator.new()

func setup(owner_crew: Node3D) -> void:
	if crew!=null:return
	crew=owner_crew;rng.randomize()
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(audio_root.path_join("lines.json")))
	if not data is Dictionary:return
	for row: Dictionary in data.get("lines",[]):
		var path:=audio_root.path_join(str(row.id)+".wav")
		var clip: AudioStream=load(path) if ResourceLoader.exists(path) else AudioStreamWAV.load_from_file(path)
		if clip==null:continue
		lines[row.id]=row;streams[row.id]=clip
	for actor: CharacterBody3D in crew.members:
		var player:=AudioStreamPlayer3D.new();player.name="ScavConversationVoice"
		player.position=Vector3(0,1.45,0);player.max_distance=24;player.unit_size=6;player.volume_db=-5
		actor.add_child(player);voices[actor]=player;next_look[actor]=clock+rng.randf_range(2,6)
	ready=lines.size()==24

func quiet() -> bool:
	if not ready or crew.hostile or crew.morale_broken:return false
	for actor: CharacterBody3D in crew.members:
		if not is_instance_valid(actor) or actor.dead or actor.surrendered or actor.fleeing or actor.pinned_time>0:return false
		if actor.state==actor.AIState.SEARCH or actor.state==actor.AIState.COMBAT or actor.own_visual_time<3.0:return false
		if not crew.tactics.contact(actor).is_empty():return false
	return true

func _actor(role: String) -> CharacterBody3D:
	for actor: CharacterBody3D in crew.members:
		if is_instance_valid(actor) and not actor.dead and actor.role==role:return actor
	return null

func _pair(group: String) -> Array[CharacterBody3D]:
	var result: Array[CharacterBody3D]=[]
	for i: int in range(2):
		var row: Dictionary=lines.get(group+"_"+str(i),{})
		if row.is_empty():return []
		var actor:=_actor(row.role)
		if actor==null:return []
		result.append(actor)
	if result[0].global_position.distance_to(result[1].global_position)>22.0:return []
	if not crew.tactics.sightline(result[0].global_position+Vector3.UP*1.3,result[1].global_position+Vector3.UP*1.3):return []
	return result

func start_exchange(group: String) -> bool:
	if not enabled or not quiet() or clock<next_chat or active_voice!=null or not pending.is_empty():return false
	var pair:=_pair(group)
	if pair.size()!=2:return false
	last_exchange=group;next_chat=clock+rng.randf_range(30,52)
	for i: int in range(2):pending.append({"actor":weakref(pair[i]),"partner":weakref(pair[1-i]),"id":group+"_"+str(i)})
	return _deliver()

func _deliver() -> bool:
	if pending.is_empty() or not quiet():interrupt();return false
	var item: Dictionary=pending.pop_front()
	var actor: CharacterBody3D=item.actor.get_ref();var partner: CharacterBody3D=item.partner.get_ref()
	if not is_instance_valid(actor) or not is_instance_valid(partner) or actor.dead or partner.dead or actor.global_position.distance_to(partner.global_position)>24:
		interrupt();return false
	if not crew.tactics.sightline(actor.global_position+Vector3.UP*1.3,partner.global_position+Vector3.UP*1.3):interrupt();return false
	var row: Dictionary=lines[item.id]
	active_voice=voices[actor];active_voice.stream=streams[item.id];active_voice.play()
	line_started=clock;line_ends=clock+active_voice.stream.get_length();reply_at=line_ends+rng.randf_range(.35,.65)
	caption=Label3D.new();caption.name="ScavConversationCaption";caption.text=str(row.text)
	caption.font_size=28;caption.pixel_size=.005;caption.position=Vector3(0,2.05,0)
	caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED;caption.no_depth_test=false;caption.visibility_range_end=24
	actor.add_child(caption)
	_focus_on(actor,partner,line_ends-clock+.5);_focus_on(partner,actor,line_ends-clock+.5)
	history.append({"time":clock,"speaker":actor.role,"id":item.id,"text":row.text,"position":actor.global_position})
	if history.size()>64:history.pop_front()
	crew.tactics.send(actor,"crew_chatter",{"line":item.id,"listener":partner.role})
	return true

func _focus_on(actor: CharacterBody3D,partner: CharacterBody3D,duration: float) -> void:
	looks[actor]={"until":clock+duration,"partner":weakref(partner)}
	next_look[actor]=clock+duration+rng.randf_range(4,9)

func _glances() -> void:
	for actor: CharacterBody3D in crew.members:
		actor.social_look_point=Vector3.INF
		var look: Dictionary=looks.get(actor,{})
		if not look.is_empty() and float(look.until)>clock:
			if look.has("partner"):
				var partner: CharacterBody3D=look.partner.get_ref()
				if is_instance_valid(partner):actor.social_look_point=partner.global_position+Vector3.UP*(.95 if partner.crouching else 1.5)
			else:actor.social_look_point=look.point
		elif clock>=float(next_look.get(actor,0)):
			var angle:=rng.randf_range(.35,.75)*(1 if rng.randf()>.5 else -1)
			if actor.busy_search:angle*=.6
			var point: Vector3=actor.global_position-actor.global_basis.z.rotated(Vector3.UP,angle)*6+Vector3.UP*1.5
			looks[actor]={"until":clock+rng.randf_range(1.0,2.5),"point":point}
			next_look[actor]=clock+rng.randf_range(6,13)
			actor.social_look_point=point

func tick(delta: float) -> void:
	if not enabled or not is_finite(delta) or delta<=0:return
	clock+=delta
	if not quiet():interrupt();next_chat=maxf(next_chat,clock+15);return
	_glances()
	if active_voice!=null:
		if is_instance_valid(caption):caption.modulate.a=clampf(minf((clock-line_started)*5,(line_ends-clock)*4),0,1)
		if clock<line_ends:return
		active_voice.stop();active_voice=null;_clear_caption()
	if not pending.is_empty():
		if clock>=reply_at:_deliver()
		return
	var activity: RefCounted=crew.get("activity")
	if activity==null:return
	var event: String=""
	if activity.mode=="regroup" and last_mode!="regroup":event="regroup"
	elif activity.cohesion_hold and not last_hold:event="hold"
	elif activity.routine_kind!=last_routine:
		if activity.routine_kind=="tie_boot" and is_instance_valid(activity.routine_actor) and activity.routine_actor.role=="scout":event="tie_boot"
		elif not activity.routine_kind.is_empty() and is_instance_valid(activity.routine_actor) and activity.routine_actor.role=="leader":event="routine"
	last_mode=activity.mode;last_hold=activity.cohesion_hold;last_routine=activity.routine_kind
	if clock<next_chat:return
	if not event.is_empty() and start_exchange(event):return
	var options: Array[String]=[]
	if activity.mode=="patrol":options.assign(["patrol_doors","patrol_rear","patrol_quiet","patrol_pack"])
	else:options.assign(["loot_quiet","loot_books","loot_tins","loot_watch"])
	var available: Array[String]=[]
	for group: String in options:
		if group!=last_exchange and _pair(group).size()==2:available.append(group)
	if not available.is_empty():start_exchange(available[rng.randi_range(0,available.size()-1)])
	else:next_chat=clock+5

func _clear_caption() -> void:
	if is_instance_valid(caption):caption.queue_free()
	caption=null

func interrupt() -> void:
	for player: AudioStreamPlayer3D in voices.values():
		if is_instance_valid(player):player.stop()
	active_voice=null;pending.clear();_clear_caption();looks.clear()
	if not is_instance_valid(crew):return
	for actor: CharacterBody3D in crew.members:
		if is_instance_valid(actor):actor.social_look_point=Vector3.INF

func set_active(active: bool) -> void:
	enabled=active
	for player: AudioStreamPlayer3D in voices.values():
		if is_instance_valid(player):
			player.process_mode=Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
			player.stream_paused=not active
