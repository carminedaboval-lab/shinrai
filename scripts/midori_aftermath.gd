extends Node3D
## Recent emergency evidence and truthful supply directions on existing routes.
## No global lighting, weather, terrain, crop, enemy or save changes.
const Budget = preload("res://scripts/shinrai_loading_budget.gd")
const Context = preload("res://scripts/extraction_context_loot.gd")
const TownProps = preload("res://scripts/midori_town_prop_clusters.gd")
const OverturnedVan = preload("res://scripts/midori_overturned_van.gd")
const VAN_ENABLED := true
const VAN_ASSET := "res://assets/shinrai/vehicles/japanese_ev_delivery_2050/van_rollover.glb"
var installed := false
var park: Node3D
var terrain: Node
var street: Node3D
var identity: Node3D
var report: Dictionary = {"notices":[],"floor_papers":[],"physical_fixtures":[],"destinations":{},"rejections":[],"new_lights":0,"source_assets_modified":false}
var materials: Dictionary = {}

const PAPER_SHADER := """
shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform vec4 paper_color : source_color = vec4(.76,.73,.64,1);
void fragment() {
 float grain=fract(sin(dot(floor(UV*vec2(900.,1200.)),vec2(127.1,311.7)))*43758.5453);
 float edge=min(min(UV.x,1.-UV.x),min(UV.y,1.-UV.y));
 float mark=(1.-smoothstep(.0,.035,edge))*.035;
 ALBEDO=paper_color.rgb*(.97+.045*grain-mark);
 ROUGHNESS=.92;
}
"""

func _ready() -> void:
	park=get_parent() as Node3D
	await Budget.wait_structure(park)
	var deadline: int=Time.get_ticks_msec()+150000
	for name: String in ["MidoriTerrain","Midori2050Identity","MidoriSouthStreet","MidoriCivicLighting"]:
		var producer: Node=park.get_node_or_null(NodePath(name))
		if producer==null:
			report.rejections.append("Missing producer "+name); _finish(); return
		while producer.get("installed")!=true:
			if Time.get_ticks_msec()>deadline:
				report.rejections.append("Producer deadline "+name); _finish(); return
			await get_tree().process_frame
	terrain=park.get_node("MidoriTerrain")
	street=park.get_node("MidoriSouthStreet")
	identity=park.get_node("Midori2050Identity")
	set_as_top_level(true);global_transform=Transform3D.IDENTITY
	_make_materials()
	_destinations()
	_south_update()
	_canopy_update()
	_hinata_notices()
	var van_report: Dictionary={"ok":false,"pending":true,"rejections":[],"reason":"Free vehicle source is under review; no rejected art installed"}
	if VAN_ENABLED: van_report=await OverturnedVan.build(park,street,VAN_ASSET)
	report.overturned_van=van_report
	report.town_props=TownProps.build(park,street,van_report)
	for part: Dictionary in [van_report,report.town_props]:
		for reason: String in part.get("rejections",[]): report.rejections.append(reason)
	# Static props must reach physics before installed unlocks navigation scanning.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_finish()

func _finish() -> void:
	installed=true
	set_meta("aftermath_report",report)
	print("MIDORI_AFTERMATH_READY ",JSON.stringify(report))

func _make_materials() -> void:
	var shader:=Shader.new();shader.code=PAPER_SHADER
	var paper:=ShaderMaterial.new();paper.shader=shader
	materials.paper=paper
	for row: Array in [["wood",Color("#6d6252"),.83,0.0],["steel",Color("#394441"),.58,.50],["tape",Color("#b8b29b"),.66,0.0],["red",Color("#813d35"),.86,0.0]]:
		var mat:=StandardMaterial3D.new();mat.albedo_color=row[1];mat.roughness=float(row[2]);mat.metallic=float(row[3]);materials[row[0]]=mat
	materials.wood=(street.get("materials")["detail_wood"] as StandardMaterial3D).duplicate()

func _destinations() -> void:
	var cafe: Node3D=park.get_node_or_null("MidoriClubhouseCafeteria")
	var entrance: Node3D=identity.get_node_or_null("PlazaEntranceRestGarden")
	for spec: Dictionary in Context.definitions():
		if spec.id not in ["hinata_delivery_supplies","clubhouse_pantry","clubhouse_first_aid","canopy_evacuation_aid"]: continue
		var parent: Node3D=street if spec.parent=="street" else (entrance if spec.parent=="entrance" else cafe)
		if parent==null: report.rejections.append("Supply parent "+str(spec.id));continue
		report.destinations[spec.id]={"position":parent.to_global(spec.at),"approach":parent.to_global(spec.approach),"guaranteed":spec.get("guaranteed",[]).duplicate(),"existing_context_rules":true}

func _box(parent: Node3D,id: String,pos: Vector3,size: Vector3,key: String) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.name=id
	var mesh:=BoxMesh.new();mesh.size=size
	node.mesh=mesh;node.material_override=materials[key];node.position=pos
	parent.add_child(node);return node

func _paper(parent: Node3D,id: String,pos: Vector3,size: Vector2,yaw: float=0.0) -> Node3D:
	var root:=Node3D.new();root.name=id;parent.add_child(root);root.position=pos;root.rotation.y=yaw
	root.set_meta("creator_protected",true);root.set_meta("creator_editable",false)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in range(8):
		for col: int in range(6):
			for uv: Vector2 in [Vector2(col,row),Vector2(col+1,row),Vector2(col,row+1),Vector2(col+1,row),Vector2(col+1,row+1),Vector2(col,row+1)]:
				uv/=Vector2(6,8)
				var x: float=(uv.x-.5)*size.x
				var y: float=(uv.y-.5)*size.y
				var curl: float=.0012*sin(uv.x*7.0+uv.y*5.0)+.002*pow(absf(uv.x-.5)*2.0,6.0)
				surface.set_uv(uv);surface.add_vertex(Vector3(x,y,curl))
	surface.generate_normals()
	var visual:=MeshInstance3D.new();visual.name="CreasedPaper";visual.mesh=surface.commit();visual.material_override=materials.paper;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(visual)
	for side: float in [-1.0,1.0]:
		var tape:=_box(root,"TemporaryTape",Vector3(side*size.x*.37,size.y*.47,.005),Vector3(.038,size.y*.15,.002),"tape")
		tape.rotation.z=side*.14
	return root

func _text(parent: Node3D,id: String,words: String,pos: Vector3,letter_height: float,color: Color) -> void:
	var label:=Label3D.new();label.name=id;label.text=words;label.font_size=64;label.pixel_size=letter_height/64.0
	label.modulate=color;label.outline_size=0;label.shaded=true;label.no_depth_test=false;label.position=pos
	parent.add_child(label)

func _notice(parent: Node3D,id: String,pos: Vector3,size: Vector2,heading: String,body: String,footer: String,yaw: float=0.0) -> Node3D:
	var root:=_paper(parent,id,pos,size,yaw)
	var scale: float=size.x/.64
	_text(root,"Heading",heading,Vector3(0,size.y*.32,.009),.051*scale,Color("#813d35"))
	_text(root,"Instructions",body,Vector3(0,-size.y*.015,.009),.035*scale,Color("#253a33"))
	_text(root,"Update",footer,Vector3(0,-size.y*.38,.009),.020*scale,Color("#46524a"))
	report.notices.append({"id":id,"node":str(root.get_path()),"position":root.global_position,"heading":heading,"body":body,"footer":footer,"width_m":size.x,"height_m":size.y})
	return root

func _south_update() -> void:
	var totem: Node3D=identity.get_node_or_null("SouthGateWayfinding")
	if totem==null: report.rejections.append("South gate map unavailable");return
	# Small paper status replaces a footer, leaving the actual map and civic wing clear.
	_notice(totem,"SouthGateEvacuationUpdate",Vector3(0,.33,.125),Vector2(.64,.52),"BUS EVACUATION", "SUSPENDED\nCOMMUNITY AID\nAT LEAF CANOPY", "DAY 7 / USE PUBLIC PATHS")
	_notice(totem,"NetworkStatusSlip",Vector3(0,1.97,.13),Vector2(.67,.16),"NETWORK OFFLINE", "", "MANUAL UPDATES ONLY")
	# A few loose copies collect at this existing base rather than across the route.
	for index: int in range(3):
		var p: Vector3=totem.to_global(Vector3(.16-float(index)*.14,.0,.26+float(index%2)*.07))
		p.y=float(terrain.height_at(Vector2(p.x,p.z)))+.012+float(index)*.003
		var sheet:=_paper(self,"GateDiscardedNotice_%02d"%index,p,Vector2(.17,.24),.18+float(index)*.57)
		sheet.rotation.x=-PI*.5
		_text(sheet,"PaperHeadline","EVACUATION\nSUSPENDED",Vector3(0,0,.009),.013,Color("#813d35"))
		report.floor_papers.append({"position":p,"size_m":Vector2(.17,.24),"collision":false})

func _canopy_update() -> void:
	var entrance: Node3D=identity.get_node_or_null("PlazaEntranceRestGarden")
	if entrance==null: report.rejections.append("Entrance canopy unavailable");return
	var board:=Node3D.new();board.name="CanopyReliefNotice";entrance.add_child(board)
	board.position=Vector3(5.12,0,1.95)
	board.set_meta("creator_protected",true);board.set_meta("creator_editable",false)
	# A small reused timber notice stand occupies the outer apron only.
	for x: float in [-.28,.28]:
		_box(board,"NoticeStandLeg",Vector3(x,.70,0),Vector3(.034,1.4,.045),"wood")
		_box(board,"NoticeStandFoot",Vector3(x,.025,0),Vector3(.065,.05,.32),"steel")
	_box(board,"NoticeBacking",Vector3(0,1.04,0),Vector3(.69,.91,.022),"wood")
	_box(board,"NoticeLowerBrace",Vector3(0,.40,0),Vector3(.58,.035,.035),"wood")
	_notice(board,"CommunityReliefInstructions",Vector3(0,1.04,.018),Vector2(.64,.85),"DAY 7 / RELIEF","AID CASE: LEFT END\n\nSEALED FOOD:\nHINATA DELIVERY CASE\n\nMORE FIRST AID:\nCLUBHOUSE / WEST PATH","CHECK SUPPLIES / LEAVE ROUTE CLEAR")
	var body:=StaticBody3D.new();body.name="FittedNoticeStandCollision";body.collision_layer=1;body.collision_mask=0;board.add_child(body)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.72,1.43,.34);shape.shape=box;shape.position.y=.715;body.add_child(shape)
	report.physical_fixtures.append({"id":"canopy_notice_stand","node":str(board.get_path()),"position":board.global_position,"size_m":box.size,"approach":entrance.to_global(Vector3(4.25,0,2.75)),"main_ramp_clear":true})

func _hinata_notices() -> void:
	var hinata: Node3D=street.get_node_or_null("HinataDaily")
	if hinata==null: report.rejections.append("Hinata unavailable");return
	var index:=0
	for board: Node3D in hinata.find_children("HinataPracticalPriceBoard*","Node3D",true,false):
		_notice(board,"HandTapedRestockUpdate",Vector3(0,.85,-.045),Vector2(.50,.56),"NO RESTOCK", "SEALED TINS\nCHECK DELIVERY CASE\nBESIDE PRODUCE", "DAY 7 / SUPPLY INTERRUPTED",PI)
		index+=1
	if index==0: report.rejections.append("Hinata offer boards not found")
	report.hinata_offer_boards_updated=index
