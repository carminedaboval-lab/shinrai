extends Node3D
const StartupTrace = preload("res://scripts/startup_trace.gd")
const Grid = preload("res://scripts/midori_woodland_diversity.gd")
const BakeCache = preload("res://scripts/shinrai_mesh_bake_cache.gd")

func _ready() -> void:
	call_deferred("install")

func install() -> void:
	var _boot_tick := StartupTrace.begin()
	var park:=get_parent() as Node3D
	if park.has_meta("woodland_companions"):
		return
	var detail:Node=get_tree().root.get_node("MidoriGrassDetail")
	var beds:=park.find_children("WoodlandFillLOD0_*","MultiMeshInstance3D",true,false)
	if beds.is_empty():
		return
	var sources:Array[Node3D]=[park.midnight_fern_prototype,park.lilac_prototypes[0],park.lilac_prototypes[1]]
	var parts:Array=[]
	var boxes:Array[AABB]=[]
	for source in sources:
		var source_parts:Array=[]
		var box:=AABB()
		var first:=true
		for part:MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
			if part.mesh==null:
				continue
			var relative:Transform3D=park._vegetation_relative_transform(part,source)
			var mesh:=BakeCache.baked_from(part)
			var b:AABB=relative*mesh.get_aabb()
			box=b if first else box.merge(b)
			first=false
			source_parts.append({"mesh":mesh,"relative":relative,"bake_key":BakeCache.group_key()})
		parts.append(source_parts)
		boxes.append(box)
	var rng:=RandomNumberGenerator.new()
	rng.seed=205010061
	var counts:=[0,0,0]
	var positions:Array[Vector2]=[]
	var prior_grid:={}
	var tree_grid:={}
	for tree:Vector2 in park.occupied_tree_positions:
		Grid._grid_add(tree_grid,tree*2,tree*2)
	var grounding_errors:=0
	var pockets:=0
	for index in range(0,beds.size(),3):
		var bed:MultiMeshInstance3D=beds[index]
		var centre:=Vector2(bed.global_position.x,bed.global_position.z)
		var groups:Array=[[],[],[]]
		var angle:=rng.randf_range(0,TAU)
		var placed:=0
		for attempt in range(160):
			if placed>=21:
				break
			var kind:=0 if placed%4!=0 else 1+(int(placed/4)%2)
			var box:=boxes[kind]
			var height:=rng.randf_range(.38,.62) if kind==0 else rng.randf_range(.75,1.05)
			var scale_value:=height/box.size.y
			var radius:=maxf(box.size.x,box.size.z)*scale_value*.5
			var offset:=Vector2(rng.randf_range(-6.2,6.2),rng.randf_range(1.7,4.8)).rotated(angle)
			var p:=centre+offset
			if not detail._is_lawn_position(p.x,p.y) or not park._is_vegetation_clear(Vector3(p.x/2,0,p.y/2),radius*.5+.18):
				continue
			# Same tests as before (pure, all required), cheapest first, stopping at
			# the first failure; grid neighbours get the original expressions, so the
			# placement is identical (see midori_woodland_diversity.gd).
			var clear:=not Grid._tree_near(tree_grid,p,radius+.65)
			if clear:
				for cell:Vector2i in Grid._cells_around(p,maxf(.70,radius+.3)):
					for prior:Vector2 in prior_grid.get(cell,[]):
						if p.distance_to(prior)<maxf(.70,radius+.3):
							clear=false
							break
					if not clear:
						break
			if clear:
				for side in range(8):
					var q:=p+Vector2(radius+.15,0).rotated(float(side)*TAU/8)
					if not detail._is_lawn_position(q.x,q.y):
						clear=false
						break
			if not clear:
				continue
			var basis:=Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*scale_value)
			var anchor:=Vector3(box.get_center().x,box.position.y,box.get_center().z)
			var t:=Transform3D(basis,Vector3(p.x,.014,p.y)-basis*anchor)
			if absf((t*box).position.y-.014)>.002:
				grounding_errors+=1
			groups[kind].append(t)
			positions.append(p)
			Grid._grid_add(prior_grid,p,p)
			counts[kind]+=1
			placed+=1
		if placed==0:
			continue
		for kind in range(3):
			if groups[kind].is_empty():
				continue
			for part:Dictionary in parts[kind]:
				var mm:=MultiMesh.new()
				mm.transform_format=MultiMesh.TRANSFORM_3D
				mm.mesh=part.mesh
				mm.instance_count=groups[kind].size()
				for i in range(mm.instance_count):
					var t:Transform3D=groups[kind][i]*part.relative
					t.origin-=Vector3(centre.x,0,centre.y)
					mm.set_instance_transform(i,t)
				var batch:=MultiMeshInstance3D.new()
				batch.multimesh=mm
				BakeCache.tag(batch,part.bake_key)
				batch.position=Vector3(centre.x,0,centre.y)
				batch.visibility_range_end=75
				batch.visibility_range_end_margin=12
				batch.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				add_child(batch)
		pockets+=1
	if not positions.is_empty():
		set_meta("review_anchor",positions[0])
	park.set_meta("woodland_companions",{"pockets":pockets,"ferns":counts[0],"shrubs":counts[1]+counts[2],"grounding_errors":grounding_errors,"new_collisions":0})
	_boot_tick = StartupTrace.finish("vegetation.companions",_boot_tick)
	print("WOODLAND_COMPANIONS ",JSON.stringify(park.get_meta("woodland_companions")))

	var diversity := preload("res://scripts/midori_woodland_diversity.gd").new()
	diversity.name = "WoodlandDiversity"
	park.add_child(diversity)
