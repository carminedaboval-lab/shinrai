extends Node3D
# Additive placement of supplied plants: taller green masses behind the low grass.
# No source mesh/material changes, new collisions, or mature tree movement.
func _ready() -> void:
	call_deferred("install")

func install() -> void:
	var park:=get_parent() as Node3D
	if park.has_meta("woodland_diversity"):
		return
	var detail:Node=get_tree().root.get_node("MidoriGrassDetail")
	var beds:=park.find_children("WoodlandFillLOD0_*","MultiMeshInstance3D",true,false)
	var evergreen:Node3D=load("res://assets/shinrai/parks/midori_park/models/vegetation/midori_evergreen_shrub_v1.glb").instantiate()
	var sources:Array[Node3D]=[park.forest_floor_bush_prototypes[0],evergreen,park.emerald_fountain_grass_prototype,park.lilac_prototypes[1],park.midnight_fern_prototype,park.deadwood_trunk_prototype]
	var labels:=["woodland_bush","evergreen_shrub","fountain_grass","flowering_shrub","fern","fallen_wood"]
	var parts:Array=[]
	var boxes:Array[AABB]=[]
	for source in sources:
		var group:Array=[]
		var box:=AABB()
		var first:=true
		for part:MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
			if part.mesh==null:
				continue
			var relative:Transform3D=park._vegetation_relative_transform(part,source)
			var mesh:=part.mesh.duplicate() as Mesh
			for surface in range(mesh.get_surface_count()):
				mesh.surface_set_material(surface,part.get_active_material(surface))
			var b:AABB=relative*mesh.get_aabb()
			box=b if first else box.merge(b)
			first=false
			group.append({"mesh":mesh,"relative":relative})
		parts.append(group)
		boxes.append(box)
	var rng:=RandomNumberGenerator.new()
	rng.seed=205010063
	var counts:=[0,0,0,0,0,0]
	var positions:Array[Vector3]=[]
	var audit:Array=[]
	var pockets:=0
	for index in range(1,beds.size(),3):
		var bed:MultiMeshInstance3D=beds[index]
		var centre:=Vector2(bed.global_position.x,bed.global_position.z)
		var groups:Array=[[],[],[],[],[],[]]
		var angle:=rng.randf_range(0,TAU)
		var placed:=0
		for attempt in range(200):
			if placed>=26:
				break
			# Each group has a dominant leaf form; flowers are concentrated, not confetti.
			var pattern:=[0,0,1,0,1,4,4,2]
			if index%9==4:
				pattern=[4,4,4,0,0,1,2,2]
			elif index%9==7:
				pattern=[0,1,1,0,2,2,4,4]
			var kind:int=pattern[placed%pattern.size()]
			if index%5==1 and placed%4==0:
				kind=3
			if index%9==1 and placed==25:
				kind=5
			var box:=boxes[kind]
			var height_ranges:=[Vector2(.85,1.35),Vector2(1.05,1.65),Vector2(.65,.95),Vector2(1.0,1.5),Vector2(.55,.85)]
			var basis:=Basis(Vector3.UP,rng.randf_range(0,TAU))
			if kind==5:
				basis=basis*Basis(Vector3.FORWARD,PI*.5)
				var rotated:AABB=Transform3D(basis,Vector3.ZERO)*box
				var length:=rng.randf_range(.85,1.4)
				basis=basis.scaled(Vector3.ONE*length/maxf(rotated.size.x,rotated.size.z))
			else:
				var hr:Vector2=height_ranges[kind]
				basis=basis.scaled(Vector3.ONE*rng.randf_range(hr.x,hr.y)/box.size.y)
			var footprint:AABB=Transform3D(basis,Vector3.ZERO)*box
			var radius:=Vector2(footprint.size.x,footprint.size.z).length()*.5
			var offset:=Vector2(rng.randf_range(-7.5,7.5),rng.randf_range(-4.5,4.5)).rotated(angle)
			var p:=centre+offset
			if not detail._is_lawn_position(p.x,p.y) or not park._is_vegetation_clear(Vector3(p.x/2,0,p.y/2),radius*.5+.20):
				continue
			var clear:=true
			for side in range(12):
				var q:=p+Vector2(radius+.15,0).rotated(float(side)*TAU/12)
				if not detail._is_lawn_position(q.x,q.y):
					clear=false
			for tree:Vector2 in park.occupied_tree_positions:
				if p.distance_to(tree*2)<radius+.65:
					clear=false
			for prior:Vector3 in positions:
				if p.distance_to(Vector2(prior.x,prior.z))<maxf(.85,(radius+prior.y)*.70):
					clear=false
			if not clear:
				continue
			var anchor:=Vector3(footprint.get_center().x,footprint.position.y,footprint.get_center().z)
			var t:=Transform3D(basis,Vector3(p.x,.014,p.y)-anchor)
			groups[kind].append(t)
			positions.append(Vector3(p.x,radius,p.y))
			audit.append({"kind":labels[kind],"p":[p.x,p.y],"radius":radius,"base_y":(t*box).position.y,"height":footprint.size.y})
			counts[kind]+=1
			placed+=1
		if placed==0:
			continue
		for kind in range(groups.size()):
			if groups[kind].is_empty():
				continue
			for part:Dictionary in parts[kind]:
				var mm:=MultiMesh.new()
				mm.transform_format=MultiMesh.TRANSFORM_3D
				mm.mesh=part.mesh
				mm.instance_count=groups[kind].size()
				for j in range(mm.instance_count):
					var t:Transform3D=groups[kind][j]*part.relative
					t.origin-=Vector3(centre.x,0,centre.y)
					mm.set_instance_transform(j,t)
				var batch:=MultiMeshInstance3D.new()
				batch.name="%s_%03d_%02d"%[labels[kind],index,get_child_count()]
				batch.multimesh=mm
				batch.position=Vector3(centre.x,0,centre.y)
				batch.visibility_range_end=90 if kind<4 else 65
				batch.visibility_range_end_margin=12
				batch.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				add_child(batch)
		pockets+=1
	evergreen.free()
	set_meta("placement_audit",audit)
	if not positions.is_empty():
		set_meta("review_anchor",Vector2(positions[0].x,positions[0].z))
	var report:={"pockets":pockets,"new_collisions":0,"counts":{}}
	for i in range(labels.size()):
		report.counts[labels[i]]=counts[i]
	park.set_meta("woodland_diversity",report)
	print("WOODLAND_DIVERSITY ",JSON.stringify(report))
