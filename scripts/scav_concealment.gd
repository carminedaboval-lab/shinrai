extends Node3D
## Human perception only. Read actual placed plant transforms and lights without
## adding collisions, changing artwork, or making foliage bulletproof.
const CELL:=4.0
const CACHE_SECONDS:=.15
const VIEWMODEL_LAYER:=1 << 19
var environment_root: Node3D
var volumes: Array[Dictionary]=[]
var grid: Dictionary={}
var lights: Array[Light3D]=[]
var ready_for_use:=false
var building:=false
var index_report: Dictionary={}
var _samples: Dictionary={}
var _rescan_requested:=false

func setup(root: Node3D) -> void:
	environment_root=root
	rebuild()

func rebuild() -> void:
	if building: _rescan_requested=true; return
	if not is_instance_valid(environment_root): return
	building=true
	# MultiMesh buffers are published at the frame boundary. Reading immediately
	# after a creator placement can otherwise return identity instance transforms.
	await get_tree().process_frame
	var next_volumes: Array[Dictionary]=[]
	var next_grid: Dictionary={}
	var next_lights: Array[Light3D]=[]
	var pending: Array[Node]=[environment_root]
	var work:=0
	var mesh_count:=0
	while not pending.is_empty():
		var node: Node=pending.pop_back()
		if not is_instance_valid(node): continue
		if node is Light3D and _world_light(node): next_lights.append(node)
		var kind:=_plant_kind(node)
		if kind!="" and node is MultiMeshInstance3D and node.multimesh!=null and node.multimesh.mesh!=null:
			var mm: MultiMesh=node.multimesh
			var count: int=mm.instance_count if mm.visible_instance_count<0 else mini(mm.instance_count,mm.visible_instance_count)
			for i: int in range(count):
				_register(next_volumes,next_grid,node,mm.mesh.get_aabb(),node.global_transform*mm.get_instance_transform(i),kind,i)
				work+=1
				if work>=256: work=0; await get_tree().process_frame
			mesh_count+=1
		elif kind!="" and node is MeshInstance3D and node.mesh!=null:
			_register(next_volumes,next_grid,node,node.get_aabb(),node.global_transform,kind)
			mesh_count+=1
		for child: Node in node.get_children():
			if child!=self: pending.append(child)
		work+=1
		if work>=256: work=0; await get_tree().process_frame
	volumes=next_volumes; grid=next_grid; lights=next_lights
	_samples.clear(); ready_for_use=true; building=false
	index_report={"foliage_volumes":volumes.size(),"plant_meshes":mesh_count,"grid_cells":grid.size(),"lights":lights.size()}
	if _rescan_requested:
		_rescan_requested=false
		call_deferred("rebuild")

func _plant_kind(node: Node) -> String:
	var path: String=String(node.name).to_lower()
	var ancestor: Node=node.get_parent()
	for i: int in range(5):
		if ancestor==null or ancestor==environment_root: break
		path+="/"+String(ancestor.name).to_lower(); ancestor=ancestor.get_parent()
	if "bush" in path or "shrub" in path or "lilac" in path or ("bed_" in path and "_plant_2_" in path): return "bush"
	if "fern" in path or "fountaingrass" in path or "fountain_grass" in path or "landscapeplants" in path: return "soft"
	if "broadleaf" in path or "referencespine" in path or "referencepine" in path or "sparsegaptree" in path or "islandtree" in path: return "canopy"
	return ""

func _register(list: Array[Dictionary], cells: Dictionary, node: Node3D, local: AABB, transform_value: Transform3D, kind: String, instance: int=-1) -> void:
	if not node.is_visible_in_tree(): return
	var bounds: AABB=transform_value*local
	# Ordinary lawn blades, flower heads and source debris are not human cover.
	if bounds.size.y<.55 or maxf(bounds.size.x,bounds.size.z)<.25: return
	if kind=="canopy":
		if bounds.size.y<2.5: return
		bounds.position.y+=bounds.size.y*.45
		bounds.size.y*=.55
	elif bounds.size.y>4.0: return
	var id:=list.size()
	var local_transform: Transform3D=node.multimesh.get_instance_transform(instance) if instance>=0 else Transform3D.IDENTITY
	list.append({"bounds":bounds,"density":.8 if kind=="bush" else .45 if kind=="soft" else .65,"owner":weakref(node),"transform":node.global_transform,"kind":kind,"instance":instance,"instance_transform":local_transform})
	var first:=Vector2i(floori(bounds.position.x/CELL),floori(bounds.position.z/CELL))
	var last:=Vector2i(floori(bounds.end.x/CELL),floori(bounds.end.z/CELL))
	for z: int in range(first.y,last.y+1):
		for x: int in range(first.x,last.x+1):
			var key:=Vector2i(x,z)
			if not cells.has(key): cells[key]=[]
			cells[key].append(id)

func invalidate_samples() -> void:
	_samples.clear()

func _world_light(light: Light3D) -> bool:
	# First-person weapon fill/flash lights illuminate only reserved layer20.
	# They never light the player's world body and must not reveal it to AI.
	return (light.light_cull_mask & ~VIEWMODEL_LAYER)!=0

func sample(actor: CharacterBody3D, target: Node3D, alerted: bool) -> Dictionary:
	var now:=Time.get_ticks_msec()*.001
	var key:=actor.get_instance_id()
	var cached: Dictionary=_samples.get(key,{})
	var crouched: bool=bool(target.get("crouching"))
	if not cached.is_empty() and now-float(cached.time)<CACHE_SECONDS and cached.alerted==alerted and cached.crouched==crouched and cached.actor.distance_squared_to(actor.global_position)<.16 and cached.target.distance_squared_to(target.global_position)<.16:
		return cached.result
	var eye:=actor.global_position+Vector3.UP*(.98 if bool(actor.get("crouching")) else 1.52)
	var chest:=target.global_position+Vector3.UP*(.78 if crouched else 1.25)
	var head:=target.global_position+Vector3.UP*(1.02 if crouched else 1.6)
	var distance:=eye.distance_to(chest)
	var illumination:=_illumination(head,actor,target)
	var side: Vector3=(chest-eye).cross(Vector3.UP).normalized()*.22
	var depth:=(_foliage_depth(eye,chest)+_foliage_depth(eye,head)+_foliage_depth(eye,chest+side))/3.0
	var foliage:=clampf(exp(-.65*depth),.18,1.0)
	var velocity_value: Variant=target.get("velocity")
	if velocity_value is Vector3:
		foliage=lerpf(foliage,1.0,clampf(Vector2(velocity_value.x,velocity_value.z).length()/24.0,0,.3))
	var factor: float=(lerpf(.25,1.0,illumination)*maxf(.4,foliage)) if alerted else illumination*foliage
	# A face-to-face encounter still reveals a person. Walls/cone are checked by
	# the actor separately, so this never sees through solid cover or behind it.
	if distance<=3.5: factor=1.0
	var result: Dictionary={"factor":clampf(factor,.05,1.0),"notice_rate":clampf(illumination*foliage,.3,1.0),"illumination":illumination,"foliage":foliage,"foliage_depth_m":depth,"distance_m":distance}
	if distance<=3.5: result.notice_rate=1.0
	_samples[key]={"time":now,"actor":actor.global_position,"target":target.global_position,"alerted":alerted,"crouched":crouched,"result":result}
	return result

func _illumination(point: Vector3, actor: CollisionObject3D, target: Node3D) -> float:
	var night_value: Variant=environment_root.get("is_night_mode") if is_instance_valid(environment_root) else null
	var night: bool=bool(night_value) if night_value!=null else false
	var sun: DirectionalLight3D
	for light: Light3D in lights:
		if is_instance_valid(light) and _world_light(light) and light is DirectionalLight3D and light.is_visible_in_tree() and light.light_energy>.01:
			if sun==null or light.light_energy>sun.light_energy: sun=light
	var exposed:=false
	if sun!=null:
		var toward_sun: Vector3=sun.global_basis.z.normalized()
		exposed=_clear_light(point,point+toward_sun*65.0,actor,target) and _foliage_depth(point,point+toward_sun*25.0)<.6
	var base: float=(.45 if exposed else .30) if night else (1.0 if exposed else .55)
	var candidates: Array[Dictionary]=[]
	for light: Light3D in lights:
		if not is_instance_valid(light) or not _world_light(light) or light is DirectionalLight3D or not light.is_visible_in_tree() or light.light_energy<=.01: continue
		var radius: float=light.omni_range if light is OmniLight3D else light.spot_range if light is SpotLight3D else 0.0
		var distance:=point.distance_to(light.global_position)
		if radius<=0 or distance>=radius: continue
		var strength:=minf(1.0,light.light_energy*.6*pow(1.0-distance/radius,2))
		if light is SpotLight3D:
			var facing: float=(-light.global_basis.z).dot((point-light.global_position).normalized())
			if facing<cos(deg_to_rad(light.spot_angle)): continue
			strength*=smoothstep(cos(deg_to_rad(light.spot_angle)),1.0,facing)
		candidates.append({"light":light,"strength":strength})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.strength>b.strength)
	var local_strength:=0.0
	for i: int in range(mini(4,candidates.size())):
		var candidate: Dictionary=candidates[i]
		var origin: Vector3=candidate.light.global_position
		origin+=(point-origin).normalized()*.15
		if _clear_light(origin,point,actor,target): local_strength=maxf(local_strength,candidate.strength)
	return clampf(base+(1.0-base)*local_strength,.25,1.0)

func _clear_light(from: Vector3, to: Vector3, actor: CollisionObject3D, target: Node3D) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(from,to,1)
	var excluded: Array[RID]=[actor.get_rid()]
	if target is CollisionObject3D: excluded.append(target.get_rid())
	query.exclude=excluded
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _foliage_depth(from: Vector3,to: Vector3) -> float:
	var direction:=to-from
	var length:=direction.length()
	if length<.01: return 0
	var candidates: Dictionary={}
	var steps:=maxi(1,ceili(Vector2(direction.x,direction.z).length()/(CELL*.5)))
	for i: int in range(steps+1):
		var point: Vector3=from+direction*(float(i)/steps)
		var key:=Vector2i(floori(point.x/CELL),floori(point.z/CELL))
		for z: int in range(-1,2):
			for x: int in range(-1,2):
				for id: int in grid.get(key+Vector2i(x,z),[]): candidates[id]=true
	# Occupied half-metre bins use maximum density. Separate mesh surfaces or
	# duplicate LODs of one shrub cannot multiply its concealment.
	var bins: Dictionary={}
	for id: int in candidates:
		var volume: Dictionary=volumes[id]
		var owner_node: Node3D=volume.owner.get_ref()
		if not is_instance_valid(owner_node) or not owner_node.is_visible_in_tree() or owner_node.global_transform!=volume.transform: continue
		if int(volume.instance)>=0:
			var mm: MultiMesh=owner_node.multimesh
			if mm==null or mm.instance_count<=int(volume.instance) or (mm.visible_instance_count>=0 and int(volume.instance)>=mm.visible_instance_count): continue
			if mm.get_instance_transform(volume.instance)!=volume.instance_transform: continue
		var bounds: AABB=volume.bounds
		var radius: Vector3=bounds.size*.5
		if minf(radius.x,minf(radius.y,radius.z))<.01: continue
		var origin: Vector3=(from-bounds.get_center())/radius
		var ray_direction: Vector3=direction/radius
		var a:=ray_direction.dot(ray_direction)
		var b:=2.0*origin.dot(ray_direction)
		var c:=origin.dot(origin)-1.0
		var discriminant:=b*b-4*a*c
		if discriminant<=0 or a<.00001: continue
		var first:=maxf(0.0,(-b-sqrt(discriminant))/(2*a))
		var last:=minf(1.0,(-b+sqrt(discriminant))/(2*a))
		if last<=first: continue
		for bin: int in range(floori(first*length/.5),ceili(last*length/.5)):
			bins[bin]=maxf(float(bins.get(bin,0.0)),float(volume.density))
	var depth:=0.0
	for density: float in bins.values(): depth+=density*.5
	return minf(depth,6.0)
