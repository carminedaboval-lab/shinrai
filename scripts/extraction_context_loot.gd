extends RefCounted
## Physical supply cases on existing supported furniture/floors; no building edits.
const Containers=preload("./extraction_loot_containers.gd")
const REACH:=2.3

static func definitions() -> Array[Dictionary]:
	return [
		{"id":"clubhouse_pantry","parent":"cafe","at":Vector3(-.85,1.0025,1.5),"approach":Vector3(.55,.2475,1.5),"table":"pantry","label":"CAFÉ SUPPLIES","style":"food","guaranteed":["can_opener","canned_mackerel"]},
		{"id":"clubhouse_maintenance","parent":"cafe","at":Vector3(-2.45,.2475,4.35),"approach":Vector3(-1.8,.2475,5.25),"table":"maintenance","label":"MAINTENANCE CASE","style":"tool"},
		{"id":"clubhouse_first_aid","parent":"cafe","at":Vector3(-2.45,.2475,6.65),"approach":Vector3(-1.8,.2475,6.0),"table":"medical","label":"FIRST AID CASE","style":"medical","guaranteed":["bandage"]},
		{"id":"changing_room_supplies","parent":"cafe","at":Vector3(-2.4,.2475,9.0),"approach":Vector3(-1.75,.2475,8.4),"table":"sports","label":"TEAM SUPPLIES","style":"sports"},
		{"id":"haku_workbench_tools","parent":"street","at":Vector3(9.93,1.027,266.2),"approach":Vector3(9.7,.09,265.4),"table":"workshop","label":"HAKU TOOL CASE","style":"tool","small":true},
		{"id":"hinata_delivery_supplies","parent":"street","at":Vector3(-9.35,.09,192.5),"approach":Vector3(-8.9,.09,191.1),"table":"pantry","label":"HINATA DELIVERY","style":"food","guaranteed":["canned_mackerel"]},
		{"id":"canopy_evacuation_aid","parent":"entrance","at":Vector3(-5.25,.002,1.90),"approach":Vector3(-4.4,.01,2.5),"table":"medical","label":"EVACUATION AID CASE","style":"medical","guaranteed":["bandage"]}
	]

static func install(raid: Node) -> Dictionary:
	var result: Array[String]=[]
	var missing: Array[String]=[]
	var cafe: Node3D=raid.park.get_node_or_null("MidoriClubhouseCafeteria")
	var street: Node3D=raid.park.get_node_or_null("MidoriSouthStreet")
	for spec: Dictionary in definitions():
		if raid.sites.any(func(site: Dictionary)->bool:return str(site.id)==str(spec.id)):continue
		var producer: Node=cafe if spec.parent=="cafe" else street
		var parent: Node3D=producer as Node3D
		if spec.parent=="entrance":
			producer=raid.park.get_node_or_null("Midori2050Identity")
			parent=producer.get_node_or_null("PlazaEntranceRestGarden") as Node3D if producer!=null else null
		if parent==null or producer==null or producer.get("installed")!=true:missing.append(str(spec.id));continue
		var model:=_case(parent,spec)
		if model==null:missing.append(str(spec.id));continue
		var target:=model.global_position+Vector3(0,.12 if spec.get("small",false) else .23,0)
		raid.sites.append({"id":spec.id,"title":"Search "+str(spec.label).to_lower(),"container_title":str(spec.label),"empty_title":"Empty "+str(spec.label).to_lower(),"kind":"cache","position":target,"container_type":Containers.CONTEXT_TYPE,"loot_context":spec.table,"guaranteed":spec.get("guaranteed",[]).duplicate(),"prop_node":model,"approach":parent.to_global(spec.approach),"spawn_chance":1.0,"ammo_bonus":0,"done":true,"spawned":false,"discovered":false,"contents":[],"loot":{}})
		result.append(str(spec.id))
	return {"installed":result,"missing":missing,"registered_count":raid.sites.filter(func(site: Dictionary)->bool:return site.get("container_type","")==Containers.CONTEXT_TYPE).size()}

static func reachable(player: Node3D, site: Dictionary) -> bool:
	if site.get("container_type","")!=Containers.CONTEXT_TYPE:return true
	if not player.is_inside_tree() or player.global_position.distance_to(site.position)>REACH:return false
	var query:=PhysicsRayQueryParameters3D.create(player.camera.global_position,site.position,1,[player.get_rid()])
	var hit:=player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():return true
	var model: Node=site.get("prop_node")
	return is_instance_valid(model) and (hit.collider==model or model.is_ancestor_of(hit.collider))

static func _material(color: Color, metallic: float=0.0) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=.8;material.metallic=metallic;return material

static func _part(parent: Node3D, label: String, position: Vector3, size: Vector3, material: Material) -> void:
	var node:=MeshInstance3D.new();node.name=label
	var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.material_override=material;node.position=position;parent.add_child(node)

static func _case(parent: Node3D, spec: Dictionary) -> Node3D:
	var root:=Node3D.new();root.name=str(spec.id);root.position=spec.at
	root.set_meta("creator_protected",true);root.set_meta("creator_editable",false);root.set_meta("creator_object_kind","loot_container")
	parent.add_child(root)
	var small: bool=spec.get("small",false)
	var size:=Vector3(.38,.18,.30) if small else Vector3(.62,.34,.40)
	var colors: Dictionary={"food":Color("796347"),"medical":Color("c2c5b8"),"sports":Color("3c515d"),"tool":Color("48594e")}
	var body:=_material(colors[str(spec.style)])
	var dark:=_material(Color("252e2b"),.15)
	var steel:=_material(Color("858b83"),.6)
	_part(root,"CaseBody",Vector3(0,size.y*.5,0),size,body)
	_part(root,"LidSeam",Vector3(0,size.y*.78,0),Vector3(size.x+.008,.012,size.z+.008),dark)
	_part(root,"Lid",Vector3(0,size.y+.014,0),Vector3(size.x+.018,.028,size.z+.018),body)
	# Handle has actual posts and a gap, rather than a solid cuboid decoration.
	for x: float in [-.065,.065]:_part(root,"HandleMount",Vector3(x,size.y+.047,0),Vector3(.017,.04,.02),dark)
	_part(root,"CarryHandle",Vector3(0,size.y+.070,0),Vector3(.15,.018,.022),dark)
	for x: float in [-size.x*.31,size.x*.31]:_part(root,"Latch",Vector3(x,size.y*.78,-size.z*.5-.007),Vector3(.038,.072,.018),steel)
	var plate:=_material(Color("d6d2bc"))
	_part(root,"PrintedLabel",Vector3(0,size.y*.42,-size.z*.5-.005),Vector3(size.x*.72,size.y*.27,.006),plate)
	var text:=Label3D.new();text.name="CaseLabel";text.text=str(spec.label);text.font_size=32;text.pixel_size=.00065 if small else .00095;text.modulate=Color("26362e");text.outline_size=0;text.no_depth_test=false;text.position=Vector3(0,size.y*.42,-size.z*.5-.010);text.rotation.y=PI;root.add_child(text)
	if spec.style=="medical":
		var red:=_material(Color("923d39"))
		_part(root,"MedicalMarkVertical",Vector3(0,size.y+.032,0),Vector3(.035,.008,.13),red)
		_part(root,"MedicalMarkHorizontal",Vector3(0,size.y+.032,0),Vector3(.13,.008,.035),red)
	var body_node:=StaticBody3D.new();body_node.name="CaseCollision";body_node.collision_layer=1;body_node.collision_mask=0;root.add_child(body_node)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size+Vector3(.02,.03,.02);collision.shape=shape;collision.position=Vector3(0,(size.y+.03)*.5,0);body_node.add_child(collision)
	root.set_meta("loot_case_size",size)
	return root

