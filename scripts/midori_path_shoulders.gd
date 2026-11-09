extends RefCounted

const BakeCache = preload("res://scripts/shinrai_mesh_bake_cache.gd")
const SHORE_CELL_M := 8.0
var _shore_cells: Dictionary = {}
var _shore_indexed := false

## terrain.edge_distance(p, shoreline) < limit, answered from the segments whose
## bounds share a cell with the square of half-side limit + 1 m round p: any
## segment closer than `limit` has a point in such a cell. Same distances, same
## comparison, so the same answer as testing every segment.
func _near_shore(p: Vector2, limit: float, shore: PackedVector2Array) -> bool:
	var n := shore.size()
	if not _shore_indexed:
		_shore_indexed = true
		for i in range(n):
			var a := shore[i]
			var b := shore[(i+1)%n]
			var low := a.min(b)
			var high := a.max(b)
			for z in range(floori(low.y/SHORE_CELL_M),floori(high.y/SHORE_CELL_M)+1):
				for x in range(floori(low.x/SHORE_CELL_M),floori(high.x/SHORE_CELL_M)+1):
					var key := Vector2i(x,z)
					if not _shore_cells.has(key): _shore_cells[key] = []
					_shore_cells[key].append(i)
	var reach := limit+1.0
	for z in range(floori((p.y-reach)/SHORE_CELL_M),floori((p.y+reach)/SHORE_CELL_M)+1):
		for x in range(floori((p.x-reach)/SHORE_CELL_M),floori((p.x+reach)/SHORE_CELL_M)+1):
			var bucket: Variant = _shore_cells.get(Vector2i(x,z))
			if bucket == null: continue
			for i: int in bucket:
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p,shore[i],shore[(i+1)%n]))<limit: return true
	return false

var _parts: Array = []
var _boxes: Array[AABB] = []
var _sources: Array[Node3D] = []
var _scan_task := -1
var _scan := {}

## The supplied plant parts and their bounds (pure resource work, done once).
func _build_sources(park: Node3D) -> void:
	if not _sources.is_empty(): return
	_sources=[park.midnight_fern_prototype,park.forest_floor_bush_prototypes[0],park.emerald_fountain_grass_prototype,park.dense_grass_prototypes[0]]
	for source in _sources:
		var group:Array=[]
		var box:=AABB()
		var first:=true
		for part:MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
			if part.mesh==null:continue
			var relative:Transform3D=park._vegetation_relative_transform(part,source)
			var materials:Array=[]
			for surface in range(part.mesh.get_surface_count()):
				var material:Material=part.get_active_material(surface)
				if source==_sources[3] and material is StandardMaterial3D:
					material=material.duplicate()
					material.albedo_color*=Color(.72,.78,.63,1)
					material.roughness=maxf(material.roughness,.90)
				materials.append(material)
			var mesh:=BakeCache.baked(part.mesh,materials)
			var b:AABB=relative*mesh.get_aabb()
			box=b if first else box.merge(b)
			first=false
			group.append({"mesh":mesh,"relative":relative,"bake_key":BakeCache.group_key()})
		_parts.append(group)
		_boxes.append(box)

## Starts the candidate sweep on a worker thread. The sweep only uses the seeded
## RNG, the park's path-edge distance index (built when the park was laid out,
## read-only since) and the source bounds, so it can run while the trails'
## surface is installed. install() takes its result. Desire paths call this
## before the trail surface; install() starts it itself when nobody did.
func start_scan(park: Node3D) -> void:
	if _scan_task != -1 or _scan.has("candidates"): return
	_build_sources(park)
	var rng:=RandomNumberGenerator.new()
	rng.seed=205010069
	# The worker holds the park's edge index itself (a Dictionary is refcounted,
	# so it outlives the park if the boot is quit or retried mid-sweep), never the
	# park node: nothing the worker touches can be freed under it.
	_scan = {"rng": rng, "edge_cells": park._path_edge_cells, "boxes": _boxes.duplicate()}
	_scan_task = WorkerThreadPool.add_task(_scan_job.bind(_scan), true, "MidoriPathShoulders sweep")

## Waited for when this object goes away (desire paths dropped mid-boot), so the
## sweep is always claimed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _scan_task != -1:
		WorkerThreadPool.wait_for_task_completion(_scan_task)
		_scan_task = -1

## park.path_edge_distance_world(point) on the park's own index, line for line.
static func _edge_distance(cells: Dictionary, point: Vector2) -> float:
	var result := INF
	var cell := Vector2i(floori(point.x/8.0),floori(point.y/8.0))
	for segment:Dictionary in cells.get(cell,[]):
		var nearest := Geometry2D.get_closest_point_to_segment(point,segment.a,segment.b)
		var t := clampf((nearest-segment.a).length()/maxf(.001,segment.a.distance_to(segment.b)),0.0,1.0)
		result=minf(result,point.distance_to(nearest)-lerpf(segment.wa,segment.wb,t)*.5)
	return result

## WORKER: the first, pure part of the shoulder sweep (every RNG draw happens
## here, in the original order). Candidates that pass it are listed in sweep
## order with everything the remaining tests and the placement use.
static func _scan_job(job: Dictionary) -> void:
	var rng: RandomNumberGenerator = job.rng
	var cells: Dictionary = job.edge_cells
	var boxes: Array = job.boxes
	var candidates: Array = []
	# Irregular clusters along the main walks; leave intermittent views into woods.
	for z in range(-166,167):
		for x in range(-202,203):
			var p:=Vector2(x+rng.randf_range(-.48,.48),z+rng.randf_range(-.48,.48))
			if sin(p.x*.11+p.y*.06)+cos(p.y*.17-p.x*.03)<-.30:continue
			var edge_distance:float=_edge_distance(cells,p)
			if not is_finite(edge_distance) or edge_distance<.20 or edge_distance>5.0:continue
			# Short supplied grasses soften the immediate edge. Taller plants stay
			# farther back in broken pockets, retaining the previous outer density.
			var kind:=3
			if edge_distance>1.65:
				if posmod(x,2)!=0 or posmod(z,2)!=0:continue
				kind=rng.randi_range(0,2)
			var box:AABB=boxes[kind]
			var height:=rng.randf_range(.13,.25) if kind==3 else (rng.randf_range(.38,.72) if kind!=1 else rng.randf_range(.65,1.12))
			var basis:=Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*height/maxf(.01,box.size.y))
			# A low spreading clump covers soil without multiplying dense source meshes.
			# Full rotated bounds below still enforce the same paved-edge clearance.
			if kind==3:basis=basis.scaled(Vector3(2.5,1.0,2.5))
			var footprint:AABB=Transform3D(basis,Vector3.ZERO)*box
			var radius:=Vector2(footprint.size.x,footprint.size.z).length()*.5
			if edge_distance<radius+.20:continue
			candidates.append([p,kind,height,basis,footprint,radius,edge_distance])
	job["candidates"]=candidates

func install(park: Node3D, terrain: Node, trails: Node) -> void:
	start_scan(park)
	# Wait for the terrain and draped walk bodies to enter the physics space.
	for frame in range(2):await park.get_tree().physics_frame
	var space:=park.get_world_3d().direct_space_state
	var parent:=Node3D.new()
	parent.name="FullerWalkShoulders"
	park.add_child(parent)
	parent.global_transform=Transform3D.IDENTITY
	var sources:=_sources
	var parts:=_parts
	var groups:Array=[[],[],[],[]]
	var audit:Array=[]
	var grid_obstacles:=trails.has_method("obstacle_hit")
	# The sweep normally finished during the trail surface; this only blocks
	# if it did not (no frame passes here, as in the old single-pass loop).
	WorkerThreadPool.wait_for_task_completion(_scan_task)
	_scan_task = -1
	for candidate: Array in _scan.candidates:
		var p:Vector2=candidate[0]
		var kind:int=candidate[1]
		var height:float=candidate[2]
		var basis:Basis=candidate[3]
		var footprint:AABB=candidate[4]
		var radius:float=candidate[5]
		var edge_distance:float=candidate[6]
		# The tests below are pure and draw no random numbers, so all of them
		# passing is the same decision in any order: the cheap ones go first.
		var clear:=true
		for centre:Vector2 in [Vector2(9,6),Vector2(3,28),Vector2(30,-104)]:
			if p.distance_to(centre)<9.0+radius:clear=false
		if not clear:continue
		if trails.distance_to_path(p)<1.7+radius:continue
		if park.any_trunk_within(p,radius+.75):continue
		# Same any-hit answer from the trails' obstacle grid, not every rect.
		if grid_obstacles:
			if trails.obstacle_hit(p,radius):continue
		else:
			for rect:Rect2 in trails.obstacles:
				if rect.grow(radius).has_point(p):clear=false;break
			if not clear:continue
		# Authored vegetation masks predate narrower walks. Relax only their
		# old wide buffer, retaining footprint separation from actual paving.
		if not park._is_vegetation_clear(Vector3(p.x/2,0,p.y/2),radius/2-.85):continue
		if terrain.water_at(p) or _near_shore(p,2.0+radius,terrain.shoreline):continue
		var low:=INF
		var high:=-INF
		for k in range(8):
			var q:=p+Vector2(radius,0).rotated(k*TAU/8)
			low=minf(low,terrain.height_at(q))
			high=maxf(high,terrain.height_at(q))
		if high-low>.18:continue
		# Test the centre and an enclosing ring against the installed walk faces.
		# This also covers rounded corners and bridge joins absent from polylines.
		for k in range(17):
			var q:Vector2=p if k==16 else p+Vector2(radius+.20,0).rotated(k*TAU/16)
			var h:float=terrain.height_at(q)
			var hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x,h+.6,q.y),Vector3(q.x,h-.10,q.y),1))
			if hit.is_empty() or hit.collider.is_in_group("midori_terrain_paving") or hit.collider.is_in_group("midori_walk_surface"):
				clear=false
				break
		if not clear:continue
		var anchor:=Vector3(footprint.get_center().x,footprint.position.y,footprint.get_center().z)
		var transform:=Transform3D(basis,Vector3(p.x,terrain.height_at(p)+.014,p.y)-anchor)
		groups[kind].append(transform)
		audit.append({"p":p,"radius":radius,"height":height,"kind":kind,"path_edge_distance_m":edge_distance,"edge_clearance_m":edge_distance-radius,"base_y":terrain.height_at(p)+.014})
	# Visibility ranges apply to an entire MultiMesh AABB, never each clump.
	# Partition the accepted transforms so nearby shoulders survive far from
	# the park origin while distant tiles still fade out at the existing range.
	const TILE_M := 24.0
	for kind in range(sources.size()):
		var tiles:Dictionary={}
		for transform:Transform3D in groups[kind]:
			var key:=Vector2i(floori(transform.origin.x/TILE_M),floori(transform.origin.z/TILE_M))
			if not tiles.has(key):tiles[key]=[]
			tiles[key].append(transform)
		for key:Vector2i in tiles:
			var tile_origin:=Vector3(key.x*TILE_M,0,key.y*TILE_M)
			var to_tile:=Transform3D(Basis.IDENTITY,-tile_origin)
			var transforms:Array=tiles[key]
			for part:Dictionary in parts[kind]:
				var mm:=MultiMesh.new()
				mm.transform_format=MultiMesh.TRANSFORM_3D
				mm.mesh=part.mesh
				mm.instance_count=transforms.size()
				var bounds:=AABB()
				for j in range(mm.instance_count):
					var local:Transform3D=to_tile*transforms[j]*part.relative
					mm.set_instance_transform(j,local)
					var instance_bounds:AABB=local*part.mesh.get_aabb()
					bounds=instance_bounds if j==0 else bounds.merge(instance_bounds)
				mm.custom_aabb=bounds
				var batch:=MultiMeshInstance3D.new()
				batch.name="Shoulder_%d_%d_%d_%d"%[kind,key.x,key.y,parent.get_child_count()]
				batch.position=tile_origin
				batch.multimesh=mm
				BakeCache.tag(batch,part.bake_key)
				batch.visibility_range_end=80
				batch.visibility_range_end_margin=12
				batch.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				parent.add_child(batch)
	parent.set_meta("placement_audit",audit)
	parent.set_meta("tile_size_m",TILE_M)
	park.set_meta("walk_shoulders",{"tile_size_m":TILE_M,"batches":parent.get_child_count(),"ferns":groups[0].size(),"shrubs":groups[1].size(),"fountain_grass":groups[2].size(),"short_grass":groups[3].size()})
	print("WALK_SHOULDERS_READY ",JSON.stringify(park.get_meta("walk_shoulders")))
