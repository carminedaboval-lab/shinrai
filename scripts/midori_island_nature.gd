extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")
const ASSETS="res://assets/shinrai/parks/midori_park/models/island_nature/"
var installed=false
var rock_positions:Array[Vector3]=[]
var plant_positions:Array[Vector3]=[]
var counts:Array[Dictionary]=[]
var footprints:Array[Dictionary]=[]
var moss_instances=0
var mainland_cover:Array[Dictionary]=[]
func _ready():
 # The rock and moss scenes are read on loader threads while the terrain is
 # built; install() then takes the same resources (load() if a request failed).
 for i in range(6):_request(ASSETS+"rock_%02d.glb"%i)
 for i in range(12):_request(ASSETS+"moss_%02d.glb"%i)
 await LoadingBudget.wait_structure(get_parent())
 call_deferred("install")
static func _request(path:String)->void:
 if ResourceLoader.has_cached(path):return
 if ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
  ResourceLoader.load_threaded_request(path)
## The requested resource once its loader thread is done (frames pass meanwhile).
func _fetch(path:String)->Variant:
 while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await get_tree().process_frame
 if ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_LOADED:
  var resource:=ResourceLoader.load_threaded_get(path)
  if resource!=null:return resource
 return load(path)
func _land(p:Vector2,r:float,island:Dictionary,terrain:Node,park:Node3D)->bool:
 if not Geometry2D.is_point_in_polygon(p,island.points) or terrain.edge_distance(p,island.points)<r+.45:return false
 if park.any_trunk_within(p,r+1.15):return false
 for route:PackedVector2Array in terrain.paths:
  for i in range(route.size()-1):
   if p.distance_to(Geometry2D.get_closest_point_to_segment(p,route[i],route[i+1]))<r+1.6:return false
 for prior in footprints:
  if p.distance_to(prior.p)<r+prior.r+.12:return false
 return true
func _parts(model:Node3D,park:Node3D)->Dictionary:
 var bounds:Dictionary=park._vegetation_visual_bounds(model)
 return {"model":model,"box":bounds.bounds}
func _plant(source:Node3D,p:Vector2,height:float,yaw:float,terrain:Node,park:Node3D,label:String)->Node3D:
 var root=Node3D.new();root.name=label;add_child(root)
 var content=source.duplicate() as Node3D;root.add_child(content)
 var box:AABB=park._vegetation_visual_bounds(content).bounds
 var scale_value=height/box.size.y
 content.scale*=scale_value
 content.position-=Vector3(box.get_center().x,box.position.y,box.get_center().z)*scale_value
 root.rotation.y=yaw
 root.position=Vector3(p.x,terrain.height_at(p),p.y)
 for part:MeshInstance3D in content.find_children("*","MeshInstance3D",true,false):
  part.visibility_range_end=55;part.visibility_range_end_margin=3
  part.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
 return root
func install():
 var park=get_parent() as Node3D
 var terrain=park.get_node("MidoriTerrain")
 while not terrain.installed:await get_tree().process_frame
 # Everything waiting on the terrain wakes in one frame: take a budget turn first.
 await LoadingBudget.checkpoint(park)
 var _ft := preload("res://scripts/startup_trace.gd").begin()
 set_as_top_level(true);global_transform=Transform3D.IDENTITY
 var rocks:Array[Node3D]=[]
 var rock_material:Material
 var moss_material:StandardMaterial3D
 var moss:Array[Mesh]=[]
 # Budget turns between model loads, islands and moss anchors (all local work in
 # the same order and RNG sequence); the pass used to be one ~4 s frame.
 for i in range(6):
  await LoadingBudget.checkpoint(park)
  var model=(await _fetch(ASSETS+"rock_%02d.glb"%i)).instantiate()
  for part:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
   if rock_material==null:rock_material=part.get_active_material(0)
   part.material_override=rock_material
  rocks.append(model)
 for i in range(12):
  await LoadingBudget.checkpoint(park)
  var model=(await _fetch(ASSETS+"moss_%02d.glb"%i)).instantiate()
  var mesh:Mesh=model.find_children("*","MeshInstance3D",true,false)[0].mesh
  mesh=mesh.duplicate()
  for surface in range(mesh.get_surface_count()):
   var mat=moss_material
   if mat==null:mat=mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
   mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;mat.alpha_scissor_threshold=.35
   mat.cull_mode=BaseMaterial3D.CULL_DISABLED
   moss_material=mat
   mesh.surface_set_material(surface,mat)
  moss.append(mesh);model.free()
 var rng=RandomNumberGenerator.new();rng.seed=2050100631
 for index in range(terrain.islands.size()):
  await LoadingBudget.checkpoint(park)
  var island:Dictionary=terrain.islands[index]
  var centre=Vector2.ZERO
  for p:Vector2 in island.points:centre+=p
  centre/=island.points.size()
  var planted=0;var placed_rocks=0;var moss_before=moss_instances
  var anchors:Array[Vector2]=[]
  var stone_origin=centre
  var group_yaw=index*1.7
  # Unequal stone groups, with openings between them and existing trunks.
  for attempt in range(80):
   var angle=attempt*2.399963+index*.63
   var p=centre+Vector2(cos(angle),sin(angle))*sqrt(float(attempt)/80.0)*5.5
   if placed_rocks>0:
    var offsets=[Vector2.ZERO,Vector2(2.6,1.0),Vector2(-2.3,1.4),Vector2(.6,-2.35)]
    var target=stone_origin+offsets[placed_rocks].rotated(group_yaw)
    p=target+Vector2(cos(angle),sin(angle))*float(attempt%6)*.18
   var size=2.2 if placed_rocks==0 else (1.3 if placed_rocks==1 else (.85 if placed_rocks==2 else .65))
   var source:Node3D=rocks[(index+placed_rocks*2)%rocks.size()]
   var box:AABB=park._vegetation_visual_bounds(source).bounds
   var height=size*box.size.y/maxf(box.size.x,box.size.z)
   var radius=size*.75
   if not _land(p,radius,island,terrain,park):continue
   var root=_plant(source,p,height,rng.randf_range(0,TAU),terrain,park,"IslandStone_%d_%d"%[index,placed_rocks])
   root.position.y-=height*.18
   root.set_meta("island_index",index)
   var body=StaticBody3D.new();body.name="StoneCollision";root.add_child(body)
   body.collision_layer=1;body.collision_mask=1
   for part:MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
    var shape=CollisionShape3D.new();shape.shape=part.mesh.create_convex_shape()
    body.add_child(shape);shape.transform=root.global_transform.affine_inverse()*part.global_transform
   if placed_rocks==0:stone_origin=p
   rock_positions.append(root.position);footprints.append({"p":p,"r":radius});anchors.append(p)
   placed_rocks+=1
   if placed_rocks>=4:break
  # Low fern/shrub pockets occupy the empty floor; no uniform rim or random rainbow.
  for attempt in range(100):
   var angle=attempt*2.399963+index
   var pocket=(index+attempt)%3
   var pocket_centre=stone_origin+Vector2(3.9,0).rotated(group_yaw+pocket*TAU/3)
   var p=pocket_centre+Vector2(cos(angle),sin(angle))*sqrt(float(attempt)/100.0)*2.2
   var shrub=planted%4==3
   var source:Node3D=park.forest_floor_bush_prototypes[0] if shrub else park.midnight_fern_prototype
   var height=rng.randf_range(.38,.62) if not shrub else rng.randf_range(.58,.82)
   var box:AABB=park._vegetation_visual_bounds(source).bounds
   var scale_value=height/box.size.y
   var radius=maxf(box.size.x,box.size.z)*scale_value*.5
   if not _land(p,radius,island,terrain,park):continue
   var root=_plant(source,p,height,rng.randf_range(0,TAU),terrain,park,"IslandFloor_%d_%d"%[index,planted])
   plant_positions.append(root.position);footprints.append({"p":p,"r":radius});planted+=1
   if planted>=16:break
  var batches:Array=[]
  for i in range(moss.size()):batches.append([])
  for anchor in anchors:
   await LoadingBudget.checkpoint(park)
   for z in range(-25,26):
    for x in range(-25,26):
     var offset=Vector2(x*.035+rng.randf_range(-.012,.012),z*.035+rng.randf_range(-.012,.012))
     var p=anchor+offset
     if offset.length()>.85 or offset.length()<.45:continue
     if not Geometry2D.is_point_in_polygon(p,island.points) or terrain.edge_distance(p,island.points)<.5:continue
     var basis=Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*rng.randf_range(.85,1.3))
     batches[rng.randi_range(0,11)].append(Transform3D(basis,Vector3(p.x,terrain.height_at(p)+.002,p.y)))
     moss_instances+=1
  for i in range(moss.size()):
   if batches[i].is_empty():continue
   var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=moss[i];mm.instance_count=batches[i].size()
   for j in range(batches[i].size()):mm.set_instance_transform(j,batches[i][j])
   var node=MultiMeshInstance3D.new();node.name="IslandMoss_%d_%d"%[index,i];node.multimesh=mm
   node.visibility_range_end=14;node.visibility_range_end_margin=2;node.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
   add_child(node)
  counts.append({"island":index,"stones":placed_rocks,"floor_plants":planted,"moss_fronds":moss_instances-moss_before})
 await _install_mainland_cover(park,terrain,rocks[3])
 for model in rocks:model.free()
 preload("res://scripts/startup_trace.gd").finish("feature.island_nature", _ft)
 installed=true
 print("ISLAND_NATURE_READY ",JSON.stringify({"islands":counts,"rocks":rock_positions.size(),"plants":plant_positions.size(),"moss":moss_instances,"stone_collisions":rock_positions.size()}))



func _install_mainland_cover(park:Node3D,terrain:Node,source:Node3D):
 var flowers=park.get_node("MidoriJapaneseFlowers")
 while not flowers.installed:await get_tree().process_frame
 var sockets=park.find_child("PlannedPropSockets",true,false)
 var old_cover=park.find_child("OpenLawnBoulderCover",true,false)
 var targets=[Vector2(-85,105),Vector2(-55,-115),Vector2(-45,-30),Vector2(100,110),Vector2(190,-100),Vector2(-175,-125)]
 var box:AABB=park._vegetation_visual_bounds(source).bounds
 for region in range(targets.size()):
  var height=1.9+float(region%3)*.1
  var scale_value=height/box.size.y
  var radius=Vector2(box.size.x,box.size.z).length()*.5*scale_value
  var selected=Vector2.ZERO;var found=false
  for attempt in range(150):
   var angle=attempt*2.399963+region*.73
   var p:Vector2=targets[region]+Vector2(cos(angle),sin(angle))*sqrt(float(attempt)/150.0)*22
   if not park._is_vegetation_clear(Vector3(p.x*.5,0,p.y*.5),radius*.5+1):continue
   var blocked=terrain.water_at(p)
   for route:PackedVector2Array in terrain.paths:
    for i in range(route.size()-1):
     if p.distance_to(Geometry2D.get_closest_point_to_segment(p,route[i],route[i+1]))<radius+2:blocked=true
   if park.any_trunk_within(p,radius+1.25):blocked=true
   for marker:Node3D in sockets.get_children():
    if p.distance_to(Vector2(marker.global_position.x,marker.global_position.z))<radius+11:blocked=true
   for old:Node3D in old_cover.get_children():
    if String(old.name).begins_with("OpenBoulder_") and p.distance_to(Vector2(old.global_position.x,old.global_position.z))<16:blocked=true
   for prior in mainland_cover:
    if p.distance_to(prior.p)<24:blocked=true
   for plant:Vector3 in flowers.colony_roots:
    if p.distance_to(Vector2(plant.x,plant.z))<radius+1:blocked=true
   for plant:Vector3 in flowers.azalea_positions:
    if p.distance_to(Vector2(plant.x,plant.z))<radius+2:blocked=true
   if blocked:continue
   # Keep all corners grounded on traversable mainland, clear of shore shelves.
   var low=INF;var high=-INF
   for side in range(8):
    var q=p+Vector2(radius,0).rotated(side*TAU/8)
    if terrain.water_at(q):blocked=true
    var y=terrain.height_at(q);low=minf(low,y);high=maxf(high,y)
   if blocked or high-low>.20:continue
   selected=p;found=true;break
  if not found:continue
  var root=_plant(source,selected,height,float(region)*2.1,terrain,park,"MainlandStoneCover_%d"%region)
  for mesh:MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
   mesh.visibility_range_end=140;mesh.visibility_range_end_margin=8
  root.position.y-=height*.18
  var body=StaticBody3D.new();body.name="CoverCollision";body.collision_layer=1;body.collision_mask=1;root.add_child(body)
  for mesh:MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
   var shape=CollisionShape3D.new();shape.shape=mesh.mesh.create_convex_shape()
   body.add_child(shape);shape.transform=root.global_transform.affine_inverse()*mesh.global_transform
  mainland_cover.append({"p":selected,"radius":radius,"exposed_height_m":height*.82,"node":String(root.name)})
 print("MAINLAND_STONE_COVER_READY ",JSON.stringify(mainland_cover))
