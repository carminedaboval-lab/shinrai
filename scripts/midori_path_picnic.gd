extends Node3D
const CUP := preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/takeaway_cup/midori_takeaway_cup.glb")
const STOP := Vector2(-20,154)
var park: Node3D
var terrain: Node
var loot_cup: Node3D
var loot_map: Node3D

func install(owner_park: Node3D, paths: Array[Dictionary]) -> void:
	park=owner_park
	terrain=park.get_node_or_null("MidoriTerrain")
	var rng := RandomNumberGenerator.new()
	rng.seed=2050100523
	# Reuse the supplied bare branch meshes: no cut trunk ends along footpaths.
	var branch_source := preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/realistic_trees_collection/scene.glb").instantiate()
	add_child(branch_source)
	var branches: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in branch_source.find_children("*", "MeshInstance3D", true, false):
		if String(mesh.name).contains("branches") and (String(mesh.name).contains("Medium011") or String(mesh.name).contains("Medium002") or String(mesh.name).contains("Bush006")):
			branches.append(mesh)
	var count := 0
	for route: Dictionary in paths:
		var points: PackedVector2Array=route.points
		for i in range(8,points.size()-6,16):
			var tangent := (points[i+1]-points[i-1]).normalized()
			var p := points[i]+Vector2(-tangent.y,tangent.x)*(rng.randf_range(.65,.95) if count%2==0 else -rng.randf_range(.65,.95))
			if branches.is_empty(): continue
			var original := branches[count % branches.size()]
			var wood := Node3D.new()
			wood.name = "PathsideFallenBranch_%02d" % count
			add_child(wood)
			wood.global_transform = Transform3D.IDENTITY
			var fragment_mesh := MeshInstance3D.new()
			fragment_mesh.mesh = original.mesh
			fragment_mesh.transform = original.global_transform
			wood.add_child(fragment_mesh)
			var box := _bounds(wood)
			var length := rng.randf_range(.80,1.20)
			var width := rng.randf_range(.32,.48)
			var thickness := rng.randf_range(.07,.12)
			var dimensions := Vector3(width / maxf(box.size.x,.001),length / maxf(box.size.y,.001),thickness / maxf(box.size.z,.001))
			wood.global_basis = Basis(Vector3.UP,rng.randf_range(0,TAU))*Basis(Vector3.RIGHT,PI*.5)*Basis.from_scale(dimensions)
			_settle(wood,p)
			for mesh: MeshInstance3D in wood.find_children("*","MeshInstance3D",true,false):
				mesh.visibility_range_end=38.0
				mesh.visibility_range_end_margin=5.0
				mesh.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			count+=1
	branch_source.free()
	# Small supplied weathered-stone clusters collect beside the walking line.
	var stone_count := 0
	for route: Dictionary in paths:
		var points: PackedVector2Array = route.points
		for i in range(9,points.size()-6,32):
			var tangent := (points[i+1]-points[i-1]).normalized()
			var side := -1.0 if stone_count%2==0 else 1.0
			var p := points[i]+Vector2(-tangent.y,tangent.x)*side*rng.randf_range(.55,.85)
			var stones := preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_mossy_boulder_cluster_v1.glb").instantiate() as Node3D
			stones.name = "PathsideStoneCluster_%02d" % stone_count
			add_child(stones)
			stones.global_transform = Transform3D.IDENTITY
			var box := _bounds(stones)
			var length := rng.randf_range(.46,.64)
			var factor := length/maxf(box.size.x,box.size.z)
			stones.global_basis = Basis(Vector3.UP,rng.randf_range(0,TAU))*Basis.from_scale(Vector3(factor,factor*.65,factor))
			_settle(stones,p)
			for mesh: MeshInstance3D in stones.find_children("*","MeshInstance3D",true,false):
				mesh.visibility_range_end = 38.0
				mesh.visibility_range_end_margin = 5.0
				mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			stone_count += 1
	preload("res://scripts/midori_path_edge_clutter.gd").apply(self,park,paths,terrain)
	print("PATH_CLUTTER_READY branches=",count," stone_clusters=",stone_count)
	var table := preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/picnic_2046/midori_picnic_table_2046.glb").instantiate() as Node3D
	table.name="JapaneseWoodenPicnicTable2046"
	add_child(table)
	_settle(table,STOP)
	# Separate solids keep the two benches and the leg space physically distinct.
	for spec in [Vector4(0,.725,0,.84),Vector4(0,.405,-.65,.35),Vector4(0,.405,.65,.35)]:
		_add_box(table,Vector3(spec.x,spec.y,spec.z),Vector3(1.50,.05,spec.w))
	for x in [-.49,.49]:
		for z in [-.55,.55]: _add_box(table,Vector3(x,.2,z),Vector3(.13,.40,.16))
	var seat := Vector3(STOP.x-.40,_height(STOP)+.433,STOP.y+.65)
	var bin_source := park.find_child("PlazaRecyclingStation",true,false) as Node3D
	if bin_source != null:
		var bin := bin_source.duplicate() as Node3D
		bin.name="PicnicSmartRecyclingStation"
		add_child(bin)
		bin.global_basis=bin_source.global_basis
		_settle(bin,STOP+Vector2(2.3,-1.3))
	loot_cup=CUP.instantiate()
	loot_cup.name="PicnicCoffeeCup"
	add_child(loot_cup)
	var cup_box := _bounds(loot_cup)
	loot_cup.global_position=seat-Vector3(cup_box.get_center().x,cup_box.position.y,cup_box.get_center().z)+Vector3(0,.002,0)
	var litter := CUP.instantiate() as Node3D
	litter.name="PathsideDiscardedCup"
	add_child(litter)
	litter.rotation=Vector3(0,.7,PI*.46)
	_settle(litter,STOP+Vector2(-2.1,1.0))
	print("PICNIC_STOP_READY wood=",count," seat=",seat," cup_bottom=",_bounds(loot_cup).position.y," map=",park.find_child("MainInformationBoard",true,false).global_position)
	loot_map=Node3D.new()
	loot_map.name="CollectibleParkMap"
	add_child(loot_map)
	loot_map.position=Vector3(STOP.x+.24,_height(STOP)+.754,STOP.y+.12)
	loot_map.rotation.y=.13
	var paper:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(.25,.25)
	paper.mesh=plane
	var material:=StandardMaterial3D.new()
	material.albedo_texture=preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/information_board/midori_information_board_midori_information_map_draft_v2_1k.png")
	material.roughness=.92
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	paper.material_override=material
	loot_map.add_child(paper)
	call_deferred("_register_loot")

func _register_loot() -> void:
	var raid := park.get_node_or_null("ExtractionRun")
	if raid == null: return
	while raid.phase == raid.Phase.BOOT: await get_tree().process_frame
	for site: Dictionary in raid.sites:
		if site.id == "PicnicCoffeeCup": return
	raid.sites.append({"id":"PicnicCoffeeCup","title":"Take picnic coffee cup","kind":"cache","position":loot_cup.global_position,"done":false,"discovered":false,"fixed_loot":{"id":"coffee_cup","title":"Sealed coffee cup","value":12},"loot":{"id":"coffee_cup","title":"Sealed coffee cup","value":12},"pickup_node":loot_cup,"ammo_bonus":0,"spawn_chance":.23})

	raid.sites.append({"id":"PicnicParkMap","title":"Collect visitor map","kind":"cache","position":loot_map.global_position,"done":false,"discovered":false,"fixed_loot":{"id":"park_map","title":"Midori park map","value":0},"loot":{"id":"park_map","title":"Midori park map","value":0},"pickup_node":loot_map,"ammo_bonus":0,"spawn_chance":.11})

func _height(p: Vector2) -> float:
	return terrain.height_at(p) if terrain != null else .01

func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		var b: AABB=mesh.global_transform*mesh.get_aabb()
		box=b if first else box.merge(b)
		first=false
	return box

func _settle(node: Node3D,p: Vector2) -> void:
	var box:=_bounds(node)
	node.global_position+=Vector3(p.x-box.get_center().x,_height(p)-box.position.y+.003,p.y-box.get_center().z)

func _add_box(parent: Node3D,position: Vector3,size: Vector3) -> void:
	var body:=StaticBody3D.new()
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collider.shape=shape
	body.add_child(collider)
	parent.add_child(body)
	body.position=position

