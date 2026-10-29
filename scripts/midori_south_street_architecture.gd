extends RefCounted
const Access = preload("res://scripts/building_access/geometry.gd")
const UpperConstruction = preload("res://scripts/midori_upper_construction.gd")
const Rainwater = preload("res://scripts/midori_roof_rainwater.gd")
const Envelope = preload("res://scripts/midori_frontage_envelope.gd")
const UpperRooms = preload("res://scripts/midori_upper_rooms.gd")
## Approved fancy-street architecture. One complete root per building; all units
## are world metres. No park, ground, lighting, gameplay or source-asset changes.

static func build(street: Node3D) -> Dictionary:
	_materials(street)
	var buildings: Array[Dictionary] = []
	for spec: Dictionary in [
		{"id":"UedaBooks","x":19.5,"w":11.0,"eave":6.35,"rise":2.10,"roof":"tile","wall":"arch_plaster","name":"UEDA BOOKS","awning":"arch_cedar","screen":true},
		{"id":"MoriCoffee","x":8.0,"w":10.0,"eave":6.8,"rise":0.0,"roof":"flat","wall":"arch_plaster","name":"MORI COFFEE","awning":"arch_sage","screen":true},
		{"id":"HinataDaily","x":-8.0,"w":10.0,"eave":6.4,"rise":2.05,"roof":"tile","wall":"arch_mineral","name":"HINATA DAILY","awning":"arch_linen","screen":false},
		{"id":"YakitoriShop","x":-19.5,"w":5.2,"eave":5.75,"rise":1.4,"roof":"cedar_gable","wall":"arch_cedar","name":"YAKITORI","awning":"arch_cedar","screen":false}
	]:
		var anchor := street.call("_root",spec.id,Vector3(spec.x,.08,194),spec.name,"building") as Node3D
		_shell(street,anchor,spec)
		_front(street,anchor,spec)
		var envelope := Envelope.build(street,anchor,spec)
		_upper(street,anchor,spec)
		UpperRooms.build(street,anchor,spec)
		if spec.roof == "flat": _flat_roof(street,anchor,spec)
		elif spec.roof == "cedar_gable": _cedar_gable(street,anchor,spec)
		else: _tiled_roof(street,anchor,spec)
		var rainwater := Rainwater.new().build(street,anchor,spec)
		anchor.set_meta("building_construction_v2",{"envelope":envelope,"rainwater":rainwater})
		var sockets := _sockets(anchor,float(spec.w),spec)
		Access.finish_shop(street,anchor,spec)
		var margin := .29 if spec.roof == "cedar_gable" else .15
		var bounds := AABB(Vector3(-float(spec.w)*.5-margin,0,-1.40),Vector3(float(spec.w)+margin*2.0,float(spec.eave)+float(spec.rise)+.45,10.20))
		anchor.set_meta("architecture_local_bounds",bounds)
		anchor.set_meta("architecture_shop_interior",Rect2(-float(spec.w)*.5+.30,.16,float(spec.w)-.60,7.62))
		buildings.append({"name":spec.id,"root":anchor,"local_bounds":bounds,"width":spec.w,"depth":8.0,"eave":spec.eave,"ridge":float(spec.eave)+float(spec.rise),"sockets":sockets})
	return {"ok":true,"buildings":buildings,"source":"approved_midori_street_art_target_v1","lights_created":0,"original_assets_modified":false}

static func _materials(street: Node3D) -> void:
	for row: Array in [
		["arch_plaster",Color("#c6bda8"),.91,"plaster_detail.png",.75],
		["arch_mineral",Color("#bcb49f"),.92,"plaster_detail.png",.72],
		["arch_cedar",Color("#796043"),.73,"wood_detail.png",1.3],
		["arch_pale_wood",Color("#a2865d"),.69,"wood_detail.png",1.2],
		["arch_floor",Color("#92836a"),.87,"wood_detail.png",.7],
		["arch_interior",Color("#bcae91"),.93,"plaster_detail.png",.6],
		["arch_stone",Color("#a6a18f"),.91,"concrete_detail.png",1.1],
		["arch_tile",Color("#626760"),.86,"concrete_detail.png",1.4],
		["arch_metal",Color("#424c47"),.51,"",1.0],
		["arch_sage",Color("#4e6858"),.96,"",1.0],
		["arch_linen",Color("#c0b89f"),.98,"",1.0],
		["arch_shadow",Color("#6d695a"),.96,"",1.0],
		["arch_cladding_backing",Color("#171913"),.97,"",1.0]
	]:
		var mat := street.call("_material",row[0],row[1],row[2],row[3],row[4]) as StandardMaterial3D
		if row[0] == "arch_tile": mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glass := street.call("_material","arch_glass",Color(.92,.95,.94,.07),.13,"",1.0) as StandardMaterial3D
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_BACK
	glass.metallic = 0.0
	glass.metallic_specular = .30
	glass.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	glass.render_priority = 1
	_apply_v5(street)

const V5 := "res://assets/shinrai/buildings/yakitori_shop/artwork_replica_v5/ProjectShinrai_YakitoriShop_ArtworkReplica_v5_"
const ROOF_ASSETS := "res://assets/shinrai/streets/midori_art_details/"

static func _apply_v5(street: Node3D) -> void:
	var mats: Dictionary = street.get("materials")
	for row: Array in [
		["arch_plaster","Plaster","Plaster",Color(1.25,1.20,1.10),.54],
		["arch_mineral","Plaster","Plaster",Color(1.20,1.17,1.09),.54],
		["arch_interior","Plaster","Plaster",Color(1.03,1.00,.94),.50],
		["arch_cedar","UpperWoodCladding","Wood",Color(1,1,1),.48],
		["arch_pale_wood","WoodFrame","Wood",Color(1,1,1),.56],
		["arch_floor","WoodFrame","Wood",Color(.88,.84,.75),.45],
		["arch_stone","Stone","Stone",Color(.95,.94,.89),.72],
		["arch_tile","Roof","Roof",Color(.82,.88,.90),.55]
	]:
		var material: StandardMaterial3D = mats[row[0]]
		material.albedo_texture = load(V5+row[1]+"_BaseColor.png") as Texture2D
		material.albedo_color = row[3]
		# V5 explicitly provides OpenGL +Y normals, Godot's native convention.
		material.normal_enabled = true
		material.normal_texture = load(V5+row[2]+"_NormalGL.png") as Texture2D
		material.normal_scale = .52 if row[0] == "arch_tile" else (.28 if row[0] in ["arch_plaster","arch_mineral","arch_interior"] else .62)
		var orm := load(V5+row[2]+"_ORM.png") as Texture2D
		material.ao_enabled = true
		material.ao_texture = orm
		material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.ao_light_affect = .16 if row[0] in ["arch_plaster","arch_mineral"] else .28
		material.roughness_texture = orm
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		material.roughness = .94
		material.metallic = 0.0
		material.metallic_specular = .25
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * float(row[4])
		material.cull_mode = BaseMaterial3D.CULL_DISABLED

static func _box(street: Node3D, parent: Node3D, label: String, pos: Vector3, size: Vector3, key: String) -> MeshInstance3D:
	if label in Envelope.replaced_labels() or label in ["RainwaterPipe","TiledRoofGutter","ParapetCap","ParapetFoldedDrip","SideCoping"]: return null
	# Only these exterior fields become assemblies. Structural/reveal/sign members
	# retain the exact root-authored shape, placement and joinery treatment.
	if key == "arch_cedar" and label in ["RearElevation","SideElevationLower","SideElevationUpper","SideElevationPier","UpperLowerSpandrel","UpperHeader","SubstantialCenterPier","SubstantialCornerPier"]:
		return _clad_wall(street,parent,label,pos,size)
	return street.call("_box",parent,label,pos,size,key,false) as MeshInstance3D


# 20mm solid vertical boards; 155mm face + 4mm open drainage joint.
# Every clipped field uses the same world-local grid so joints align at openings.
# All members are merged into one indexed mesh per field, not one draw per board.
const CLADDING_PITCH := .159
const CLADDING_JOINT := .004
const CLADDING_DEPTH := .020

static func _clad_wall(street: Node3D, parent: Node3D, label: String, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var side_face := label.begins_with("SideElevation")
	var face_axis := 0 if side_face else 2
	var across_axis := 2 if side_face else 0
	var outward := signf(pos.x) if side_face else (1.0 if label == "RearElevation" else -1.0)
	var backing_size := size
	backing_size[face_axis] -= CLADDING_DEPTH+.018
	var backing_pos := pos
	backing_pos[face_axis] -= outward*(CLADDING_DEPTH+.018)*.5
	var backing := street.call("_box",parent,label+"DarkVentilatedBacking",backing_pos,backing_size,"arch_cladding_backing",false) as MeshInstance3D
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var low := pos[across_axis]-size[across_axis]*.5
	var high := pos[across_axis]+size[across_axis]*.5
	var first := int(floor(low/CLADDING_PITCH))
	var last := int(ceil(high/CLADDING_PITCH))
	var count := 0
	for board: int in range(first,last):
		var a := maxf(low,float(board)*CLADDING_PITCH+CLADDING_JOINT*.5)
		var b := minf(high,float(board+1)*CLADDING_PITCH-CLADDING_JOINT*.5)
		if b-a < .006: continue
		var member_size := size
		member_size[across_axis] = b-a
		member_size[face_axis] = CLADDING_DEPTH
		var member_pos := pos
		member_pos[across_axis] = (a+b)*.5
		member_pos[face_axis] += outward*(size[face_axis]*.5-CLADDING_DEPTH*.5-.001)
		var member := preload("res://scripts/midori_shop_joinery.gd").mesh(member_size,board*73+int(pos.y*100))
		tool.append_from(member,0,Transform3D(Basis.IDENTITY,member_pos))
		count += 1
	if count > 0:
		var node := MeshInstance3D.new()
		node.name = label+"VerticalBoardAssembly"
		tool.index()
		tool.generate_tangents()
		node.mesh = tool.commit()
		node.material_override = preload("res://scripts/midori_shop_joinery.gd").material(street,"arch_cladding")
		node.set_meta("constructed_cladding",true)
		node.set_meta("board_count",count)
		node.set_meta("joint_width_m",CLADDING_JOINT)
		node.set_meta("board_thickness_m",CLADDING_DEPTH)
		node.set_meta("construction",{"nominal_face_m":.155,"grain":"vertical","original_envelope_retained":false,"trim_proud_m":.001,"backing_clearance_m":.017})
		parent.add_child(node)
	return backing

static func _cladding_terminations(street: Node3D, anchor: Node3D, w: float, h: float) -> void:
	# Covers stop short of the old exterior planes; they never grow the footprint.
	# 60mm corner covers conceal cut board ends; 90mm base and 70mm head rails
	# cap the ventilation cavity while the existing sill/reveal assemblies remain.
	for side: float in [-1.0,1.0]:
		for z: float in [.030,7.970]:
			_box(street,anchor,"CladdingSideCornerCover",Vector3(side*(w*.5-.010),h*.5,z),Vector3(.020,h,.060),"arch_cedar")
		for y: float in [.045,h-.035]:
			_box(street,anchor,"CladdingSideTermination",Vector3(side*(w*.5-.010),y,4),Vector3(.020,.090 if y < 1 else .070,8),"arch_cedar")
	for x: float in [-w*.5+.030,w*.5-.030]:
		_box(street,anchor,"CladdingRearCornerCover",Vector3(x,h*.5,7.990),Vector3(.060,h,.020),"arch_cedar")
		_box(street,anchor,"CladdingFrontUpperCornerCover",Vector3(x,(3.58+h)*.5,-.030),Vector3(.060,h-3.58,.020),"arch_cedar")
	for y: float in [.045,h-.035]:
		_box(street,anchor,"CladdingRearTermination",Vector3(0,y,7.990),Vector3(w,.090 if y < 1 else .070,.020),"arch_cedar")
	for y: float in [3.615,h-.035]:
		_box(street,anchor,"CladdingFrontUpperTermination",Vector3(0,y,-.030),Vector3(w,.070,.020),"arch_cedar")

static func _profiled_jamb(street: Node3D, anchor: Node3D, label: String, pos: Vector3, width: float, height: float, depth: float, key: String) -> void:
	# Rebated solid timber section: a narrow face and recessed glazing shoulder.
	var section: Array[Vector2] = [Vector2(-width*.5,-depth*.5),Vector2(width*.5,-depth*.5),Vector2(width*.5,depth*.12),Vector2(width*.32,depth*.12),Vector2(width*.32,depth*.5),Vector2(-width*.32,depth*.5),Vector2(-width*.32,depth*.12),Vector2(-width*.5,depth*.12)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(section.size()):
		var a: Vector2 = section[i]
		var b: Vector2 = section[(i+1)%section.size()]
		var normal := Vector3(b.y-a.y,0,a.x-b.x).normalized()
		_quad(tool,pos+Vector3(a.x,-height*.5,a.y),pos+Vector3(b.x,-height*.5,b.y),pos+Vector3(b.x,height*.5,b.y),pos+Vector3(a.x,height*.5,a.y),normal)
	# Polygon triangulation retains the rebates at the end grain.
	var polygon := PackedVector2Array(section)
	var indices := Geometry2D.triangulate_polygon(polygon)
	for i: int in range(0,indices.size(),3):
		for side: float in [-1.0,1.0]:
			var a: Vector2 = section[indices[i]]
			var b: Vector2 = section[indices[i+1]]
			var c: Vector2 = section[indices[i+2]]
			_triangle(tool,pos+Vector3(a.x,side*height*.5,a.y),pos+Vector3(b.x,side*height*.5,b.y),pos+Vector3(c.x,side*height*.5,c.y),Vector3.UP*side)
	_mesh(street,anchor,label,tool,key)

static func _shell(street: Node3D, anchor: Node3D, spec: Dictionary) -> void:
	var w := float(spec.w)
	var h := float(spec.eave)
	# Existing metre-scale shell now receives real access perimeter collision.
	var floor_visual := _box(street,anchor,"GroundInteriorFloor",Vector3(0,.055,3.9),Vector3(w-.32,.11,7.8),"arch_floor")
	floor_visual.mesh = preload("res://scripts/midori_shop_joinery.gd").floor_mesh(Vector3(w-.32,.11,7.8))
	floor_visual.set_meta("physical_timber_floor",{"board_pitch_m":.160,"board_depth_m":.018,"joint_m":.002,"original_envelope_retained":false,"grain_axis":"X"})
	for side: float in [-1.0,1.0]:
		var openings: Array[Dictionary] = []
		for window_z: float in [3.90,6.15]:
			openings.append({"x":side*(window_z-4.0),"w":1.20,"bottom":4.18,"top":minf(5.64,h-.24)})
		if Access.window_only(str(spec.id)) and side<0:
			var entry_z: float = 5.80 if str(spec.id)=="YakitoriShop" else 3.15
			openings.append({"x":side*(entry_z-4.0),"w":1.20,"bottom":.77,"top":2.91})
		var face := Access.elevation(street,anchor,"AccessibleShopSide",Vector3(side*w*.5,0,4),-side*PI*.5,8.0,h,openings,str(spec.wall))
		for opening: Dictionary in openings:
			Access.window(street,face,float(opening.x),float(opening.bottom),float(opening.top),float(opening.w),"GroundEntryWindow" if float(opening.bottom)<1.0 else "OperableSideWindow")
		_box(street,anchor,"RainwaterPipe",Vector3(side*(w*.5-.12),h*.47,-.14),Vector3(.065,h*.92,.065),"arch_metal")
	if spec.wall == "arch_cedar": _cladding_terminations(street,anchor,w,h)
	_box(street,anchor,"InteriorRearSkirting",Vector3(0,.18,7.75),Vector3(w-.45,.25,.06),"arch_pale_wood")

static func _front(street: Node3D, anchor: Node3D, spec: Dictionary) -> void:
	var w := float(spec.w)
	var narrow: bool = spec.roof == "cedar_gable"
	var frame_key := "arch_cedar" if narrow else "arch_pale_wood"
	# 1.60m entry assembly: a 970mm door and 510mm fixed sidelight.
	# Joinery stands 240mm behind the masonry face; no oversized single leaf.
	_box(street,anchor,"StoneThresholdToe",Vector3(0,.035,-.12),Vector3(1.72,.07,.26),"arch_stone")
	_box(street,anchor,"RecessedDoorThreshold",Vector3(0,.085,.15),Vector3(1.60,.025,.30),"arch_metal")
	for side: float in [-1.0,1.0]:
		_box(street,anchor,"FrontPierStoneFoot",Vector3(side*(w*.5-.13),.14,.015),Vector3(.26,.28,.27),"arch_stone")
		_box(street,anchor,"FrontTimberPier",Vector3(side*(w*.5-.13),1.67,.04),Vector3(.15,2.78,.18),frame_key)
	_box(street,anchor,"DeepShopfrontLintel",Vector3(0,2.94,.055),Vector3(w,.14,.20),frame_key)
	var door_half := .8325
	for side: float in [-1.0,1.0]:
		var span := w*.5-.965
		var center := side*(door_half+.0325+span*.5)
		Access.window(street,anchor,center,.51,2.81,span-.07,"GroundShopWindow")
		_profiled_jamb(street,anchor,"DeepDoorJamb",Vector3(side*door_half,1.54,.18),.065,2.82,.12,frame_key)
		_box(street,anchor,"WindowLowerTimberPanel",Vector3(center,.305,.19),Vector3(span,.37,.075),frame_key)
		_box(street,anchor,"PanelInsetField",Vector3(center,.31,.143),Vector3(span-.11,.25,.018),"arch_cedar")
		for py: float in [.145,.465]:
			_box(street,anchor,"PanelMortisedRail",Vector3(center,py,.125),Vector3(span,.045,.065),frame_key)
		for edge: float in [-1.0,1.0]:
			_box(street,anchor,"PanelMortisedStile",Vector3(center+edge*(span*.5-.025),.305,.125),Vector3(.05,.28,.065),frame_key)
		# Sloping weather sill: only 180mm deep, with a separate undercut drip.
		var sill := _box(street,anchor,"ProjectingTimberDisplaySill",Vector3(center,.51,.14),Vector3(span+.035,.043,.18),frame_key)
		sill.rotation.x = .07
		_box(street,anchor,"SillDripEdge",Vector3(center,.482,.056),Vector3(span+.035,.012,.018),"arch_cedar")
		_box(street,anchor,"WindowToplightRail",Vector3(center,2.45,.19),Vector3(span,.05,.10),frame_key)
		for edge: float in [-1.0,1.0]:
			_box(street,anchor,"RecessedWindowBead",Vector3(center+edge*(span*.5-.018),1.67,.216),Vector3(.028,2.30,.045),"arch_cedar")
		for y: float in [.55,2.79]:
			_box(street,anchor,"WindowHorizontalBead",Vector3(center,y,.216),Vector3(span,.028,.045),"arch_cedar")
	# Door outer stiles leave a human sized 970mm leaf. Fixed sidelight is on right.
	var leaf_left := -.795
	var leaf_right := .175
	var leaf_center := (leaf_left+leaf_right)*.5
	_profiled_jamb(street,anchor,"EntrySidelightMullion",Vector3(.205,1.43,.245),.060,2.61,.105,frame_key)
	_box(street,anchor,"EntryFixedSidelightGlass",Vector3(.5075,1.43,.284),Vector3(.535,2.48,.012),"arch_glass")
	for y: float in [.155,2.705]:
		_box(street,anchor,"SidelightHorizontalRail",Vector3(.5075,y,.245),Vector3(.535,.05,.105),frame_key)
	_box(street,anchor,"EntryDoorHead",Vector3(leaf_center,2.32,.245),Vector3(.97,.065,.105),frame_key)
	_box(street,anchor,"EntryDoorTransomGlass",Vector3(leaf_center,2.52,.284),Vector3(.91,.33,.012),"arch_glass")
	_box(street,anchor,"EntryTransomHead",Vector3(leaf_center,2.725,.245),Vector3(.97,.05,.105),frame_key)
	Access.door(street,anchor,Vector3(leaf_center,.11,.265),Vector2(.97,2.15),false,"PublicShopEntrance",true)
	var dark_sign: bool = narrow or spec.id == "UedaBooks"
	_box(street,anchor,"SignFasciaBacking",Vector3(0,3.33,-.08),Vector3(w-.20,.54,.12),"arch_cedar" if dark_sign else spec.wall)
	_box(street,anchor,"SignFasciaTopLip",Vector3(0,3.63,-.17),Vector3(w-.08,.035,.24),"arch_cedar" if dark_sign else "arch_stone")
	_box(street,anchor,"SignFasciaBottomBead",Vector3(0,3.045,-.27),Vector3(w-.20,.028,.05),frame_key)
	street.call("_text",anchor,"CleanShopName",spec.name,Vector3(0,3.34,-.143),.34 if narrow else .41,Color("#eadbbd") if dark_sign else Color("#282e26"))
	if not narrow:
		# Visible housings align with root-owned warm display lights at (+/-2.6,
		# 2.35,.50). Interior naming keeps them out of the facade bounce layer.
		for x: float in [-2.6,2.6]:
			_box(street,anchor,"InteriorDisplayLightHousing",Vector3(x,2.43,.50),Vector3(.40,.07,.25),"arch_cedar")
			_box(street,anchor,"InteriorDisplayLightDiffuser",Vector3(x,2.387,.50),Vector3(.35,.015,.20),"arch_linen")
	if spec.id == "MoriCoffee" or spec.id == "HinataDaily":
		_fabric_awning(street,anchor,w-.34,String(spec.awning),spec.id == "MoriCoffee")
	if narrow:
		# Pleated cloth noren has separate lower tails rather than solid flat boards.
		for i: int in range(5):
			var x := (float(i)-2.0)*.34
			var cloth := SurfaceTool.new()
			cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
			for section: int in range(4):
				var xa := x-.155+float(section)*.0775
				var xb := xa+.0775
				var za := -.18+.025*cos(float(section)*PI*.5)
				var zb := -.18+.025*cos(float(section+1)*PI*.5)
				_quad(cloth,Vector3(xa,2.70,za),Vector3(xb,2.70,zb),Vector3(xb,2.14,zb-.035),Vector3(xa,2.14,za-.035),Vector3.FORWARD)
			_mesh(street,anchor,"PleatedNorenLeaf%d"%i,cloth,"arch_linen")

static func _fabric_awning(street: Node3D, anchor: Node3D, width: float, key: String, cafe: bool) -> void:
	# 19 degree slope, 1.23 m projection, subtle hanging fabric folds, stitched
	# panel seams and a scalloped .18 m valance. Lowest hem is world Y 2.48 m.
	var cloth := SurfaceTool.new()
	cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := int(ceil(width/.11))
	for i: int in range(sections):
		var xa := -width*.5+width*float(i)/float(sections)
		var xb := -width*.5+width*float(i+1)/float(sections)
		for band: int in range(6):
			var ta := float(band)/6.0
			var tb := float(band+1)/6.0
			var a := _awning_point(xa,ta,cafe)
			var b := _awning_point(xb,ta,cafe)
			var c := _awning_point(xb,tb,cafe)
			var d := _awning_point(xa,tb,cafe)
			_quad(cloth,a,b,c,d,Vector3(0,.945,-.326))
		var ya := 2.415+.027*cos(xa*TAU/.53) if cafe else 2.48
		var yb := 2.415+.027*cos(xb*TAU/.53) if cafe else 2.48
		_quad(cloth,Vector3(xa,2.595,-1.35),Vector3(xb,2.595,-1.35),Vector3(xb,yb,-1.37),Vector3(xa,ya,-1.37),Vector3.FORWARD)
	_mesh(street,anchor,"TailoredSlopingFabricAwning",cloth,key)
	_box(street,anchor,"AwningWallRoll",Vector3(0,3.015,-.12),Vector3(width,.065,.08),"arch_metal")
	_box(street,anchor,"AwningFrontHem",Vector3(0,2.595,-1.35),Vector3(width,.025,.028),key)
	for i: int in range(int(ceil(width/.53))):
		var x := -width*.5+float(i)*.53
		var seam := _box(street,anchor,"StitchedFabricPanelSeam",Vector3(x,2.813,-.735),Vector3(.012,.012,1.30),key)
		seam.rotation.x = -.329
	for x: float in [-width*.44,0,width*.44]:
		var arm := _box(street,anchor,"SlenderAwningSupportArm",Vector3(x,2.77,-.73),Vector3(.035,.035,1.30),"arch_metal")
		arm.rotation.x = -.329
		_box(street,anchor,"AwningWallBracket",Vector3(x,2.90,-.14),Vector3(.08,.30,.10),"arch_metal")
	# Brand graphics are built by the shop-specific identity pass.

static func _awning_point(x: float, t: float, cafe: bool = true) -> Vector3:
	var fold := .017*cos(x*TAU/.53)*sin(t*PI*.5) if cafe else 0.0
	return Vector3(x,lerpf(3.015,2.595,t)-.035*sin(t*PI)+fold,lerpf(-.12,-1.35,t))

static func _upper(street: Node3D, anchor: Node3D, spec: Dictionary) -> void:
	var w := float(spec.w)
	var h := float(spec.eave)
	var narrow: bool = spec.roof == "cedar_gable"
	var bottom := 4.10
	var top := minf(6.03,h-.38)
	var window_width := 1.28 if narrow else w*.285
	var center_offset := w*.25
	var center_y := (bottom+top)*.5
	var opening_height := top-bottom
	# Two individual cut-out openings separated by substantial wall piers.
	# Opaque plaster never backs the glazing: each recess opens to the room.
	_box(street,anchor,"UpperLowerSpandrel",Vector3(0,(3.58+bottom)*.5,.12),Vector3(w,bottom-3.58,.32),spec.wall)
	_box(street,anchor,"UpperHeader",Vector3(0,(h+top)*.5,.12),Vector3(w,h-top,.32),spec.wall)
	var inner_edge := center_offset-window_width*.5
	var outer_edge := center_offset+window_width*.5
	_box(street,anchor,"SubstantialCenterPier",Vector3(0,center_y,.12),Vector3(inner_edge*2,opening_height,.32),spec.wall)
	for side: float in [-1.0,1.0]:
		var corner_width := w*.5-outer_edge
		_box(street,anchor,"SubstantialCornerPier",Vector3(side*(outer_edge+corner_width*.5),center_y,.12),Vector3(corner_width,opening_height,.32),spec.wall)
		_recessed_window(street,anchor,side*center_offset,bottom,top,window_width,narrow)
	if not narrow:
		_balcony(street,anchor,w)
		var screen_width := window_width*(.88 if spec.id == "UedaBooks" else .70 if spec.id == "MoriCoffee" else .32)
		var screen_center := -center_offset if spec.id == "UedaBooks" else center_offset+(window_width-screen_width)*.5
		var slat_count := int(ceil(screen_width/.13))
		for i: int in range(slat_count):
			var x := screen_center-screen_width*.5+float(i)*screen_width/maxf(1.0,float(slat_count-1))
			_box(street,anchor,"SelectiveUpperCedarScreen",Vector3(x,center_y,-.14),Vector3(.055,opening_height+.12,.13),"arch_pale_wood")
		for y: float in [bottom-.035,top+.035]:
			_box(street,anchor,"CedarScreenRail",Vector3(screen_center,y,-.15),Vector3(screen_width+.12,.075,.18),"arch_cedar")
		UpperConstruction.screen_mounts(street,anchor,screen_center,bottom,top,screen_width)

static func _recessed_window(street: Node3D, anchor: Node3D, x: float, bottom: float, top: float, width: float, narrow: bool) -> void:
	Access.window(street,anchor,x,bottom,top,width)

static func _balcony(street: Node3D, anchor: Node3D, w: float) -> void:
	UpperConstruction.replace_balcony(street,anchor,w)

static func _flat_roof(street: Node3D, anchor: Node3D, spec: Dictionary) -> void:
	var w := float(spec.w)
	var h := float(spec.eave)
	_box(street,anchor,"FlatRoofDeck",Vector3(0,h-.05,4),Vector3(w,.15,8),"arch_metal")
	# Actual scupper openings through the parapet, aligned with the hopper trays.
	_box(street,anchor,"ParapetBelowScuppers",Vector3(0,h-.0425,-.005),Vector3(w+.12,.055,.27),spec.wall)
	_box(street,anchor,"ParapetAboveScuppers",Vector3(0,h+.2175,-.005),Vector3(w+.12,.225,.27),spec.wall)
	_box(street,anchor,"ParapetBetweenScuppers",Vector3(0,h+.045,-.005),Vector3(w-.610,.120,.27),spec.wall)
	for side: float in [-1.0,1.0]:
		_box(street,anchor,"ParapetScupperEndPier",Vector3(side*(w*.5-.0175),h+.045,-.005),Vector3(.155,.120,.27),spec.wall)
	_box(street,anchor,"ParapetCap",Vector3(0,h+.35,-.02),Vector3(w+.20,.025,.36),"arch_metal")
	_box(street,anchor,"ParapetFoldedDrip",Vector3(0,h+.325,-.195),Vector3(w+.20,.045,.018),"arch_metal")
	for side: float in [-1.0,1.0]:
		_box(street,anchor,"SideParapet",Vector3(side*w*.5,h+.13,4),Vector3(.22,.40,8),spec.wall)
		_box(street,anchor,"SideCoping",Vector3(side*w*.5,h+.35,4),Vector3(.30,.025,8.12),"arch_metal")
	_box(street,anchor,"RoofRearParapet",Vector3(0,h+.13,7.94),Vector3(w,.4,.22),spec.wall)

static func _roof_asset(street: Node3D, anchor: Node3D, filename: String) -> bool:
	var scene := load(ROOF_ASSETS+filename) as PackedScene
	if scene == null:
		push_warning("Blender roof import missing: "+filename)
		return false
	var model := scene.instantiate() as Node3D
	model.name = "BlenderAuthoredClayRoof"
	anchor.set_meta("blender_roof_loaded",filename)
	anchor.add_child(model)
	_apply_roof_materials(model,street.get("materials"))
	return true

static func _apply_roof_materials(node: Node, materials: Dictionary) -> void:
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		visual.material_override = materials["arch_cedar" if "EaveBeams" in str(node.name) else "arch_tile"]
	for child: Node in node.get_children(): _apply_roof_materials(child,materials)

static func _tiled_roof(street: Node3D, anchor: Node3D, spec: Dictionary) -> void:
	if not _roof_asset(street,anchor,"ueda_clay_roof.glb" if spec.id == "UedaBooks" else "hinata_clay_roof.glb"):
		_tiled_roof_fallback(street,anchor,spec)
		return
	var w := float(spec.w)
	var eave := float(spec.eave)
	var rise := float(spec.rise)
	for side: float in [-1.0,1.0]:
		var gable := SurfaceTool.new()
		gable.begin(Mesh.PRIMITIVE_TRIANGLES)
		_triangle(gable,Vector3(side*w*.5,eave,0),Vector3(side*w*.5,eave+rise,4),Vector3(side*w*.5,eave,8),Vector3(side,0,0))
		_mesh(street,anchor,"PlasteredSideGable",gable,spec.wall)
		_box(street,anchor,"TiledRoofGutter",Vector3(0,eave-.10,4+side*4.62),Vector3(w,.10,.10),"arch_metal")

static func _tiled_roof_fallback(street: Node3D, anchor: Node3D, spec: Dictionary) -> void:
	var w := float(spec.w)
	var eave := float(spec.eave)
	var rise := float(spec.rise)
	var half_depth := 4.55
	var angle := atan2(rise,half_depth)
	var slope_length := sqrt(half_depth*half_depth+rise*rise)
	for side: float in [-1.0,1.0]:
		var center_z := 4.0+side*half_depth*.5
		var roof := _box(street,anchor,"PitchedRoofUnderlay",Vector3(0,eave+rise*.5,center_z),Vector3(w-.04,.15,slope_length),"arch_tile")
		roof.rotation.x = side*angle
		_box(street,anchor,"DeepTimberEave",Vector3(0,eave-.08,4+side*4.43),Vector3(w,.14,.16),"arch_cedar")
		_box(street,anchor,"FrontRearGutter",Vector3(0,eave-.04,4+side*4.59),Vector3(w,.12,.11),"arch_metal")
	# One indexed mesh carries the inexpensive repeated curved clay-tile profiles.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := int(ceil(w/.32))
	var rows := 8
	for side: float in [-1.0,1.0]:
		for row: int in range(rows):
			var d0 := float(row)*half_depth/rows
			var d1 := minf(half_depth,d0+half_depth/rows+.055)
			for col: int in range(cols):
				var x0 := -w*.5+float(col)*w/cols
				var x1 := -w*.5+float(col+1)*w/cols
				for part: int in range(3):
					var u0 := float(part)/3.0
					var u1 := float(part+1)/3.0
					var xa := lerpf(x0,x1,u0)
					var xb := lerpf(x0,x1,u1)
					var ya := .043*sin(u0*PI)
					var yb := .043*sin(u1*PI)
					_quad(tool,Vector3(xa,eave+rise*(1-d0/half_depth)+ya+.085,4+side*d0),Vector3(xb,eave+rise*(1-d0/half_depth)+yb+.085,4+side*d0),Vector3(xb,eave+rise*(1-d1/half_depth)+yb+.085,4+side*d1),Vector3(xa,eave+rise*(1-d1/half_depth)+ya+.085,4+side*d1),Vector3.UP)
	_mesh(street,anchor,"ProfiledRoofTiles",tool,"arch_tile")
	_box(street,anchor,"RidgeCap",Vector3(0,eave+rise+.12,4),Vector3(w,.17,.25),"arch_tile")
	# Triangular side gables close the roof volume in oblique views.
	for side: float in [-1.0,1.0]:
		var gable := SurfaceTool.new()
		gable.begin(Mesh.PRIMITIVE_TRIANGLES)
		_triangle(gable,Vector3(side*w*.5,eave,0),Vector3(side*w*.5,eave+rise,4),Vector3(side*w*.5,eave,8),Vector3(side,0,0))
		_mesh(street,anchor,"SideGable",gable,spec.wall)

static func _cedar_gable(street: Node3D, anchor: Node3D, spec: Dictionary) -> void:
	var w := float(spec.w)
	var eave := float(spec.eave)
	var rise := float(spec.rise)
	var half_width := w*.5-.04
	var angle := atan2(rise,half_width)
	var imported_roof := _roof_asset(street,anchor,"yakitori_clay_roof.glb")
	if not imported_roof:
		for side: float in [-1.0,1.0]:
			var roof := _box(street,anchor,"CedarShopPitchedRoof",Vector3(side*half_width*.5,eave+rise*.5,4),Vector3(sqrt(half_width*half_width+rise*rise),.14,8.95),"arch_tile")
			roof.rotation.z = -side*angle
	for z: float in [-.35,8.35]:
		var gable := SurfaceTool.new()
		gable.begin(Mesh.PRIMITIVE_TRIANGLES)
		_triangle(gable,Vector3(-w*.5,eave,z),Vector3(w*.5,eave,z),Vector3(0,eave+rise,z),Vector3(0,0,-1 if z < 0 else 1))
		_mesh(street,anchor,"CedarFrontRearGable",gable,"arch_cedar")
		for side: float in [-1.0,1.0]:
			var fascia := _box(street,anchor,"GableSlopingFascia",Vector3(side*half_width*.5,eave+rise*.5,z-.09),Vector3(sqrt(half_width*half_width+rise*rise),.11,.055),"arch_cedar")
			fascia.rotation.z = -side*angle
	if not imported_roof: _box(street,anchor,"LongCedarRidgeCap",Vector3(0,eave+rise+.08,4),Vector3(.22,.14,9.05),"arch_tile")
	# Visible vertical boards on gable front establish a narrow cedar silhouette.
	for i: int in range(29):
		var x := -w*.5+float(i)*w/28.0
		var height := rise*(1.0-absf(x)/(w*.5))
		if height > .03: _box(street,anchor,"CedarGableBoard",Vector3(x,eave+height*.5,-.395),Vector3(.09,height,.055),"arch_pale_wood")

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b-a).cross(c-a).dot(normal) > 0.0:
		var previous := b
		b = c
		c = previous
	for vertex: Vector3 in [a,b,c]:
		tool.set_normal(normal)
		tool.set_uv(Vector2(vertex.x,vertex.z))
		tool.add_vertex(vertex)

static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_triangle(tool,a,b,c,normal)
	_triangle(tool,a,c,d,normal)

static func _mesh(street: Node3D, anchor: Node3D, label: String, tool: SurfaceTool, material_key: String) -> void:
	tool.index()
	var mesh := tool.commit()
	var node := MeshInstance3D.new()
	node.name = label
	if preload("res://scripts/midori_shop_joinery.gd").applies(material_key,label):
		node.mesh = preload("res://scripts/midori_shop_joinery.gd").upright_profile(mesh)
		node.material_override = preload("res://scripts/midori_shop_joinery.gd").material(street,material_key)
		anchor.add_child(node)
		return
	node.mesh = mesh
	var mats: Dictionary = street.get("materials")
	var material: StandardMaterial3D = mats[material_key]
	if material_key != "arch_tile":
		material = material.duplicate() as StandardMaterial3D
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	anchor.add_child(node)

static func _sockets(anchor: Node3D, width: float, spec: Dictionary) -> Dictionary:
	var sockets: Dictionary = {}
	for row: Array in [
		["DetailCounter",Vector3(0,0,1.55),Vector3(width-1.2,1.25,1.2)],
		["DetailBackShelves",Vector3(0,0,2.45),Vector3(width-1.1,2.45,.35)],
		["DetailWindowLeft",Vector3(-width*.28,0,.66),Vector3(width*.26,1.3,.55)],
		["DetailWindowRight",Vector3(width*.28,0,.66),Vector3(width*.26,1.3,.55)],
		["DetailExteriorLeft",Vector3(-width*.5+.65,0,-.65),Vector3(.7,1.4,.55)],
		["DetailExteriorRight",Vector3(width*.5-.65,0,-.65),Vector3(.7,1.4,.55)],
		["LightInterior",Vector3(0,2.65,1.1),Vector3.ZERO],
		["LightEntrance",Vector3(0,2.6,-.35),Vector3.ZERO],
		["LightUpper",Vector3(0,5.4,1.5),Vector3.ZERO]
	]:
		var marker := Marker3D.new()
		marker.name = row[0]
		marker.position = row[1]
		marker.set_meta("socket_usable_size",row[2])
		anchor.add_child(marker)
		sockets[row[0]] = {"node":marker,"local_position":row[1],"usable_size":row[2]}
	if spec.roof != "flat":
		var narrow: bool = spec.roof == "cedar_gable"
		for side: float in [-1.0,1.0]:
			var marker := Marker3D.new()
			marker.name = "RoofRidgeEndLeft" if side < 0 else "RoofRidgeEndRight"
			marker.position = Vector3(0,float(spec.eave)+float(spec.rise)+.13,4+side*4.55) if narrow else Vector3(side*(width*.5+.06),float(spec.eave)+float(spec.rise)+.13,4)
			# Ornament faces outward along the ridge. These sockets are additive;
			# all six Detail* and all three Light* markers above remain unchanged.
			marker.rotation.y = (0.0 if side < 0 else PI) if narrow else (PI*.5 if side < 0 else -PI*.5)
			marker.set_meta("socket_usable_size",Vector3(.46,.55,.26))
			anchor.add_child(marker)
			sockets[marker.name] = {"node":marker,"local_position":marker.position,"usable_size":Vector3(.46,.55,.26)}
	return sockets
