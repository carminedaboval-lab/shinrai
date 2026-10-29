extends RefCounted
## Layered shop contents and artisan frontage for the approved Japanese street.
## All furniture belongs to the building/socket hierarchy; root owns batching.

const ARTISAN_PATH := "res://assets/shinrai/streets/midori_shop_craft/"
static var _soft_unit: ArrayMesh
static var _artisan_loaded: int = 0

static func build(street: Node3D, legacy_interiors: bool = true) -> Dictionary:
	_artisan_loaded = 0
	_materials(street)
	var shops: Array[Dictionary] = []
	for spec: Dictionary in [
		{"id":"UedaBooks","w":11.0,"kind":"books"},
		{"id":"MoriCoffee","w":10.0,"kind":"coffee"},
		{"id":"HinataDaily","w":10.0,"kind":"provisions"},
		{"id":"YakitoriShop","w":5.2,"kind":"yakitori"}
	]:
		var anchor := street.find_child(String(spec.id),true,false) as Node3D
		if anchor == null:
			return {"ok":false,"missing_building":spec.id,"lights_created":0}
		var counter := _group(anchor,"DetailCounter","C_CounterContents")
		var rear := _group(anchor,"DetailBackShelves","C_RearDisplay")
		var left := _group(anchor,"DetailWindowLeft","C_LeftWindowDisplay")
		var right := _group(anchor,"DetailWindowRight","C_RightWindowDisplay")
		var exterior_left := _group(anchor,"DetailExteriorLeft","C_LeftExterior")
		var exterior_right := _group(anchor,"DetailExteriorRight","C_RightExterior")
		if counter == null or rear == null or left == null or right == null or exterior_left == null or exterior_right == null:
			return {"ok":false,"missing_socket_in":spec.id,"lights_created":0}
		if legacy_interiors:
			match String(spec.kind):
				"books":
					_books(street,counter,rear,left,right,exterior_left,exterior_right)
				"coffee":
					_coffee(street,counter,rear,left,right,exterior_left,exterior_right)
				"provisions":
					_provisions(street,counter,rear,left,right,exterior_left,exterior_right)
				"yakitori":
					_yakitori(street,counter,rear,left,right,exterior_left,exterior_right)
		else:
			_exterior_contents(street,String(spec.kind),exterior_left,exterior_right)
		# The larger, readable outdoor silhouettes remain children of their shop.
		var frontage := Node3D.new()
		frontage.name = "C_ArtisanShopfrontDisplays"
		anchor.add_child(frontage)
		frontage.position.y = .01
		match String(spec.kind):
			"books": _bookshop_frontage(street,frontage)
			"coffee": _cafe_frontage(street,frontage)
			"provisions": _grocer_frontage(street,frontage)
			"yakitori": _yakitori_frontage(street,frontage)
		shops.append({"name":spec.id,"kind":spec.kind,"sockets_used":6,"entry_clear_width_m":1.6})
	return {"ok":(_artisan_loaded == 7 if legacy_interiors else shops.size() == 4),"shops":shops,"lights_created":0,"plants_created":0,
		"new_asset_jobs":0,"artisan_models_loaded":_artisan_loaded,"artisan_assets":[ARTISAN_PATH+"artisan_espresso.glb",ARTISAN_PATH+"artisan_pastry.glb"],"existing_facade_prop_types":2,"central_entry_clearance_m":1.6,
		"collision_created":false,"scope":"socket_owned_shop_contents_and_building_owned_frontage","frontage_local_z_min":-1.80,"entry_display_clear_width_m":1.8,"original_assets_modified":false}

static func _exterior_contents(street: Node3D, kind: String, ext_left: Node3D, ext_right: Node3D) -> void:
	match kind:
		"books":
			_book_stack(street,ext_left,Vector3(0,.11,0),2)
			# The retained outer tree pot occupies X24.55/Z193.35; set the board in
			# front of the browse table rather than putting its feet inside that pot.
			var board := Node3D.new()
			board.name = "BooksellerApronMenu"
			board.position = Vector3(-1.20,0,-.70)
			ext_right.add_child(board)
			_menu(street,board,"UEDA BOOKS\nNEW TITLES\nLOCAL STORIES\nOPEN 10 - 19")
			street.call("_prop",ext_right,"ac_condenser.glb","BookshopWallService",Vector3(0,3.72,.48))
		"coffee":
			_menu(street,ext_left,"MORI COFFEE\nFRESH COFFEE\nTEA + CAKE\nTAKE AWAY")
			_menu(street,ext_right,"SINGLE ORIGIN\nFRESHLY ROASTED\nTAKE A MOMENT")
		"provisions":
			_crate(street,ext_left,Vector3(0,.11,0),.63,0,true)
			_menu(street,ext_right,"HINATA DAILY\nNO RESTOCK\nSEALED TINS\nCHECK DELIVERY CASE")
		"yakitori":
			_menu(street,ext_right,"YAKITORI\nCHARCOAL GRILL\nEVENING MENU\nOPEN 17 - 23")
			street.call("_prop",ext_left,"shop_lantern.glb","SlimYakitoriLanternLeft",Vector3(0,2.74,.10))
			street.call("_prop",ext_right,"shop_lantern.glb","SlimYakitoriLanternRight",Vector3(0,2.74,.10))
			street.call("_prop",ext_left,"ac_condenser.glb","CompactWallService",Vector3(0,3.72,.48))
			_b(street,ext_left,"WallServiceMeter",Vector3(0,1.30,.47),Vector3(.22,.31,.12),"detail_metal")
			_b(street,ext_left,"MeterFace",Vector3(0,1.34,.405),Vector3(.14,.12,.012),"detail_paper")

static func _materials(street: Node3D) -> void:
	for row: Array in [
		["detail_wood",Color("#96714c"),.75,"wood_detail.png",1.2],
		["detail_darkwood",Color("#604c36"),.78,"wood_detail.png",1.0],
		["detail_metal",Color("#404b44"),.55,"",1.0],
		["detail_paper",Color("#d2c4a4"),.92,"",1.0],
		["detail_cream",Color("#c5b591"),.80,"",1.0],
		["detail_sage",Color("#72836a"),.82,"",1.0],
		["detail_rust",Color("#9e6448"),.84,"",1.0],
		["detail_blue",Color("#596c78"),.86,"",1.0],
		["detail_ink",Color("#303c36"),.88,"",1.0],
		["detail_ceramic",Color("#dfd5b9"),.38,"",1.0],
		["detail_amber",Color("#ad7f3b"),.50,"",1.0],
		["detail_red",Color("#ad5e41"),.68,"",1.0],
		["detail_green",Color("#7b8a4c"),.76,"",1.0],
		["detail_apple",Color("#a35e45"),.43,"",1.0],
		["detail_pear",Color("#a2a35a"),.60,"",1.0],
		["detail_citrus",Color("#c59145"),.67,"",1.0],
		["detail_radish",Color("#ded5b9"),.72,"",1.0],
		["detail_leaf",Color("#506a3d"),.80,"",1.0],
		["detail_cake",Color("#c4a66e"),.88,"",1.0],
		["detail_chocolate",Color("#694c38"),.70,"",1.0]
	]:
		street.call("_material",row[0],row[1],row[2],row[3],row[4])
	for key: String in ["detail_wood","detail_darkwood"]:
		var mat: StandardMaterial3D = street.get("materials")[key]
		mat.albedo_texture = load("res://assets/shinrai/streets/midori_frontage_construction/smoked_walnut_veneer_diff_2k.jpg")
		mat.albedo_color = Color(.70,.70,.70) if key == "detail_wood" else Color(.32,.32,.32)
		mat.roughness = .78
		mat.metallic_specular = .25
		mat.uv1_world_triplanar = false
		mat.uv1_scale = Vector3.ONE

static func _group(anchor: Node3D, socket_name: String, label: String) -> Node3D:
	var socket := anchor.get_node_or_null(socket_name) as Node3D
	if socket == null: socket = anchor.find_child(socket_name,true,false) as Node3D
	if socket == null: return null
	var node := Node3D.new()
	node.name = label
	socket.add_child(node)
	return node

static func _b(street: Node3D, parent: Node3D, label: String, pos: Vector3, size: Vector3, key: String) -> MeshInstance3D:
	return street.call("_box",parent,label,pos,size,key,false) as MeshInstance3D

static func _cylinder(street: Node3D, parent: Node3D, label: String, pos: Vector3, radius: float, height: float, key: String, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = street.get("materials")[key]
	node.position = pos
	parent.add_child(node)
	return node

# Imported artisan pieces preserve their GLB materials and socket ownership.
static func _artisan_prop(parent: Node3D, filename: String, label: String, pos: Vector3, scale_factor: float = 1.0, yaw: float = 0.0) -> Node3D:
	var resource_path := ARTISAN_PATH+filename
	if not ResourceLoader.exists(resource_path):
		parent.set_meta("missing_artisan_asset",resource_path)
		push_error("Missing required shop craft asset: "+resource_path)
		return null
	var scene := load(resource_path) as PackedScene
	if scene == null: return null
	var node := scene.instantiate() as Node3D
	node.name = label
	node.position = pos
	node.scale = Vector3.ONE*scale_factor
	node.rotation.y = yaw
	node.set_meta("artisan_asset",resource_path)
	if filename == "artisan_pastry.glb": _enable_pastry_vertex_colors(node)
	parent.add_child(node)
	_artisan_loaded += 1
	return node

static func _enable_pastry_vertex_colors(node: Node) -> void:
	# Godot imports the linear GLB COLOR_0 stream without enabling its albedo
	# use. Duplicate only the instance material; preserve the shared mesh and
	# every authored colour/roughness/sRGB setting, including linear colours.
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		if visual.mesh != null:
			for surface_index: int in range(visual.mesh.get_surface_count()):
				var arrays := visual.mesh.surface_get_arrays(surface_index)
				if arrays.size() <= Mesh.ARRAY_COLOR or typeof(arrays[Mesh.ARRAY_COLOR]) != TYPE_PACKED_COLOR_ARRAY: continue
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				if colors.is_empty(): continue
				var source := visual.get_active_material(surface_index) as StandardMaterial3D
				if source == null: continue
				var material := source.duplicate() as StandardMaterial3D
				material.vertex_color_use_as_albedo = true
				visual.set_surface_override_material(surface_index,material)
	for child: Node in node.get_children(): _enable_pastry_vertex_colors(child)

static func _print(parent: Node3D, label: String, words: String, pos: Vector3, letter_height: float, color: Color) -> Label3D:
	var text := Label3D.new()
	text.name = label
	text.text = words
	text.font_size = 48
	text.pixel_size = letter_height/48.0
	text.modulate = color
	text.outline_size = 0
	text.shaded = true
	text.no_depth_test = false
	text.position = pos
	text.rotation.y = PI
	parent.add_child(text)
	return text

static func _soft_block(street: Node3D, parent: Node3D, label: String, pos: Vector3, size: Vector3, key: String) -> MeshInstance3D:
	# Shared rounded rectangular extrusion: a restrained 1.4% corner radius,
	# page edges and dust jackets retain their thin, tangible silhouettes.
	if _soft_unit == null:
		var outline := PackedVector2Array()
		var radius := .014
		for corner: int in range(4):
			var center := Vector2(.5-radius,.5-radius)
			if corner == 1: center.x *= -1
			elif corner == 2: center *= -1
			elif corner == 3: center.y *= -1
			for section: int in range(4):
				var angle := float(corner)*PI*.5+float(section)*PI/6.0
				outline.append(center+Vector2(cos(angle),sin(angle))*radius)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i: int in range(outline.size()):
			var j := (i+1)%outline.size()
			var a := Vector3(outline[i].x,outline[i].y,-.5)
			var b := Vector3(outline[j].x,outline[j].y,-.5)
			var c := Vector3(outline[j].x,outline[j].y,.5)
			var d := Vector3(outline[i].x,outline[i].y,.5)
			_detail_triangle(tool,Vector3(0,0,-.5),a,b,Vector3.FORWARD)
			_detail_triangle(tool,Vector3(0,0,.5),c,d,Vector3.BACK)
			var edge := outline[j]-outline[i]
			var normal := Vector3(edge.y,-edge.x,0).normalized()
			_detail_triangle(tool,a,d,c,normal)
			_detail_triangle(tool,a,c,b,normal)
		tool.index()
		_soft_unit = tool.commit()
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = _soft_unit
	node.material_override = street.get("materials")[key]
	node.position = pos
	node.scale = size
	parent.add_child(node)
	return node

static func _flatten_new_prop(group: Node3D, parent: Node3D) -> void:
	# These are newly authored decorative parts, all owned by the same socket.
	# Bake their local transforms so root can batch by material across a display,
	# rather than leaving one draw-call hierarchy per apple or book.
	for child: Node in group.get_children():
		if not child is Node3D: continue
		var part := child as Node3D
		var placement: Transform3D = group.transform*part.transform
		group.remove_child(part)
		parent.add_child(part)
		part.transform = placement
	group.get_parent().remove_child(group)
	group.free()

static func _detail_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	for vertex: Vector3 in [a,b,c]:
		tool.set_normal(normal)
		tool.set_uv(Vector2(vertex.x+.5,vertex.y+.5))
		tool.add_vertex(vertex)

static func _lathe(street: Node3D, parent: Node3D, label: String, profile: Array[Vector2], pos: Vector3, scale_factor: float, key: String, lobes: float = 0.0) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 16
	# One shared tangent per profile vertex removes the hard horizontal rings.
	# Signed tangents continue around the rim onto hollow inner walls.
	var tangents: Array[Vector2] = []
	for point_index: int in range(profile.size()):
		var incoming := Vector2.ZERO
		var outgoing := Vector2.ZERO
		if point_index > 0: incoming = (profile[point_index]-profile[point_index-1]).normalized()
		if point_index+1 < profile.size(): outgoing = (profile[point_index+1]-profile[point_index]).normalized()
		var tangent := incoming+outgoing
		if tangent.length_squared() < .000001:
			tangent = outgoing if outgoing.length_squared() > .000001 else incoming
		tangents.append(tangent.normalized())
	for row: int in range(profile.size()-1):
		var p0 := profile[row]
		var p1 := profile[row+1]
		for section: int in range(segments):
			var aa := float(section)*TAU/float(segments)
			var ab := float(section+1)*TAU/float(segments)
			var ra := 1.0+lobes*cos(aa*5.0)
			var rb := 1.0+lobes*cos(ab*5.0)
			var a := Vector3(cos(aa)*p0.x*ra,p0.y,sin(aa)*p0.x*ra)
			var b := Vector3(cos(ab)*p0.x*rb,p0.y,sin(ab)*p0.x*rb)
			var c := Vector3(cos(ab)*p1.x*rb,p1.y,sin(ab)*p1.x*rb)
			var d := Vector3(cos(aa)*p1.x*ra,p1.y,sin(aa)*p1.x*ra)
			var na := _lathe_smooth_normal(p0,tangents[row],aa,lobes)
			var nb := _lathe_smooth_normal(p0,tangents[row],ab,lobes)
			var nc := _lathe_smooth_normal(p1,tangents[row+1],ab,lobes)
			var nd := _lathe_smooth_normal(p1,tangents[row+1],aa,lobes)
			for entry: Array in [[a,na],[b,nb],[c,nc],[a,na],[c,nc],[d,nd]]:
				tool.set_normal(entry[1])
				tool.set_uv(Vector2(aa/TAU,p0.y))
				tool.add_vertex(entry[0])
	tool.index()
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = tool.commit()
	node.material_override = street.get("materials")[key]
	node.position = pos
	node.scale = Vector3.ONE*scale_factor
	parent.add_child(node)
	return node

static func _lathe_smooth_normal(point: Vector2, tangent: Vector2, angle: float, lobes: float) -> Vector3:
	# At the rotation axis, every sector shares one pole normal. Away from the
	# axis, include the radial lobe derivative without altering any vertices.
	if absf(point.x) < .000001:
		return Vector3.DOWN if tangent.x > 0.0 else Vector3.UP
	var wave := maxf(.001,1.0+lobes*cos(angle*5.0))
	var angular_slope := -5.0*lobes*sin(angle*5.0)/wave
	return Vector3(tangent.y*(cos(angle)+angular_slope*sin(angle)),-tangent.x*wave,tangent.y*(sin(angle)-angular_slope*cos(angle))).normalized()

static func _leaf(street: Node3D, parent: Node3D, pos: Vector3, length: float, yaw: float, wilted: bool = false) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3.ZERO
	var b := Vector3(-length*.23,length*.24,length*.47)
	var c := Vector3(0,length*.46,length)
	var d := Vector3(length*.23,length*.24,length*.47)
	var ridge := Vector3(0,length*.38,length*.47)
	for tri: Array in [[a,b,ridge],[b,c,ridge],[c,d,ridge],[d,a,ridge]]:
		_detail_triangle(tool,tri[0],tri[1],tri[2],Vector3.UP)
		_detail_triangle(tool,tri[2],tri[1],tri[0],Vector3.DOWN)
	var node := MeshInstance3D.new()
	node.name = "FreshProduceLeaf"
	node.mesh = tool.commit()
	node.material_override = street.get("materials")["detail_leaf"]
	node.position = pos
	node.rotation.y = yaw
	if wilted:
		# The few abandoned display remnants droop and lose their fresh green.
		node.scale.y = -.65
		var leaf_material := (node.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		leaf_material.albedo_color = Color("#655b3c")
		leaf_material.roughness = .96
		node.material_override = leaf_material
	parent.add_child(node)

static func _produce(street: Node3D, parent: Node3D, pos: Vector3, kind: int, seed_index: int, radius: float = .056, stale: bool = false) -> void:
	var item := Node3D.new()
	item.name = ["Mandarin","OrchardApple","AsianPear","DaikonRadish"][kind%4]
	item.position = pos
	item.rotation = Vector3(.045*sin(float(seed_index)*2.1),float(seed_index)*2.399,.07*cos(float(seed_index)*1.7))
	if kind%4 == 3: item.rotation.z += .26*float(seed_index%3-1)
	parent.add_child(item)
	var profile: Array[Vector2] = []
	var material_key := "detail_citrus"
	match kind%4:
		0:
			profile = [Vector2(0,-.73),Vector2(.58,-.68),Vector2(.94,-.33),Vector2(1,.10),Vector2(.88,.51),Vector2(.46,.68),Vector2(0,.63)]
		1:
			profile = [Vector2(0,-.82),Vector2(.56,-.74),Vector2(.88,-.35),Vector2(1,.14),Vector2(.93,.58),Vector2(.48,.75),Vector2(.15,.62),Vector2(0,.63)]
			material_key = "detail_apple"
		2:
			profile = [Vector2(0,-.91),Vector2(.52,-.83),Vector2(.85,-.48),Vector2(.93,-.09),Vector2(.76,.33),Vector2(.43,.73),Vector2(.30,1.05),Vector2(0,1.14)]
			material_key = "detail_pear"
		3:
			profile = [Vector2(0,-1.9),Vector2(.16,-1.48),Vector2(.38,-.81),Vector2(.48,.1),Vector2(.41,.80),Vector2(.25,1.01),Vector2(0,1.05)]
			material_key = "detail_radish"
	var variation := .93+.035*float(seed_index%5)
	var skin := _lathe(street,item,"AbandonedProduceSkin" if stale else "NaturalProduceSkin",profile,Vector3.ZERO,radius*variation,material_key,.025 if kind%4 == 1 else .010)
	if stale:
		# Decorative leftovers are not registered harvest or inventory items.
		# Duplicate this surface only; shared fresh produce/materials stay intact.
		skin.set_meta("aftermath_decorative_remnant",true)
		parent.set_meta("aftermath_remnant_count",int(parent.get_meta("aftermath_remnant_count",0))+1)
		var aged_material := (skin.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		aged_material.albedo_color = aged_material.albedo_color * Color(.64,.61,.43)
		aged_material.roughness = .96
		skin.material_override = aged_material
		item.scale.y = .90
	var top := radius*(1.14 if kind%4 == 2 else 1.05 if kind%4 == 3 else .65)*variation
	_rod(street,item,"FruitStem",Vector3(0,top-.008,0),Vector3(.006,top+.024,0),.003,"detail_darkwood")
	if kind%4 == 3:
		for leaf_index: int in range(4): _leaf(street,item,Vector3(0,top,0),radius*(1.8+float(leaf_index%2)*.35),float(leaf_index)*1.65,stale)
	elif seed_index%3 == 0:
		_leaf(street,item,Vector3(.003,top+.008,0),radius*.75,float(seed_index),stale)
	_flatten_new_prop(item,parent)

static func _shelf(street: Node3D, parent: Node3D, width: float, height: float, x: float = 0.0) -> void:
	for side: float in [-1.0,1.0]:
		_b(street,parent,"ShelfUpright",Vector3(x+side*(width*.5-.025),.11+height*.5,0),Vector3(.045,height,.32),"detail_darkwood")
	for y: float in [.22,.77,1.32,1.87,2.37]:
		if y > height: continue
		_b(street,parent,"DisplayShelf",Vector3(x,y,0),Vector3(width,.045,.34),"detail_wood")
	_b(street,parent,"ShelfLowBacking",Vector3(x,.30,.145),Vector3(width,.31,.035),"detail_darkwood")

static func _book_row(street: Node3D, parent: Node3D, pos: Vector3, count: int, seed_index: int) -> void:
	var colors: Array[String] = ["detail_sage","detail_cream","detail_blue","detail_rust","detail_paper","detail_ink"]
	var titles: Array[String] = ["MORI","FIELD","TOKYO","STILL","FORM","GARDEN"]
	for i: int in range(count):
		var h: float = .23+float((i+seed_index)%4)*.028
		var width := .055+float((i+seed_index)%3)*.005
		var p := pos+Vector3(float(i)*.073,h*.5,0)
		var book := Node3D.new()
		book.name = "BoundShelfVolume"
		book.position = p
		book.rotation.z = .025 if i%9 == 8 else 0.0
		parent.add_child(book)
		_soft_block(street,book,"RoundedBookSpine",Vector3.ZERO,Vector3(width,h,.185),colors[(i+seed_index)%colors.size()])
		for y: float in [-h*.34,h*.34]:
			_b(street,book,"FineSpineRule",Vector3(0,y,-.094),Vector3(width*.72,.004,.004),"detail_paper")
		if i%8 == 2:
			var lettering := _print(book,"PrintedSpineTitle",titles[(i+seed_index)%titles.size()],Vector3(0,0,-.096),.018,Color("#e5dcc8"))
			lettering.rotation.z = PI*.5
		_flatten_new_prop(book,parent)

static func _book_stack(street: Node3D, parent: Node3D, pos: Vector3, variant: int) -> void:
	for i: int in range(3):
		var book := Node3D.new()
		book.name = "StackedBoundVolume"
		book.position = pos+Vector3(float(i%2)*.012,float(i)*.047,0)
		book.rotation.y = .035*float((variant+i)%3-1)
		parent.add_child(book)
		_soft_block(street,book,"StackedBookPages",Vector3(0,.023,0),Vector3(.30,.033,.22),"detail_paper")
		for y: float in [.005,.043]:
			_soft_block(street,book,"RoundedHardbackCover",Vector3(0,y,0),Vector3(.32,.007,.235),"detail_sage" if (variant+i)%2 == 0 else "detail_rust")
		for y: float in [.017,.029]:
			_b(street,book,"SubtlePageEdgeRule",Vector3(0,y,-.111),Vector3(.285,.0015,.002),"detail_cream")
		_flatten_new_prop(book,parent)

static func _display_rack(street: Node3D, parent: Node3D, width: float, count: int) -> void:
	for side: float in [-1.0,1.0]:
		var leg := _b(street,parent,"RackLeg",Vector3(side*(width*.5-.035),.57,.035),Vector3(.045,1.02,.045),"detail_darkwood")
		leg.rotation.x = -.12
		_b(street,parent,"RackFoot",Vector3(side*(width*.5-.035),.075,0),Vector3(.07,.07,.46),"detail_darkwood")
	for y: float in [.45,.89]:
		_b(street,parent,"BookDisplayLedge",Vector3(0,y,-.035),Vector3(width,.06,.24),"detail_wood")
		for i: int in range(count):
			var x: float = (float(i)-float(count-1)*.5)*(width/float(count))
			_face_book(street,parent,Vector3(x,y+.18,-.065),minf(width/float(count)-.055,.27),.34,i+int(y*10))

static func _menu(street: Node3D, parent: Node3D, words: String) -> void:
	_b(street,parent,"MenuBoard",Vector3(0,.80,0),Vector3(.49,.68,.055),"detail_ink")
	for side: float in [-1.0,1.0]:
		_b(street,parent,"MenuFrame",Vector3(side*.259,.80,-.005),Vector3(.035,.75,.07),"detail_wood")
		var leg := _b(street,parent,"MenuStand",Vector3(side*.21,.48,.08),Vector3(.035,.88,.045),"detail_wood")
		leg.rotation.x = -.12
	_b(street,parent,"MenuFrameTop",Vector3(0,1.155,-.005),Vector3(.55,.035,.07),"detail_wood")
	_b(street,parent,"MenuFrameBottom",Vector3(0,.445,-.005),Vector3(.55,.035,.07),"detail_wood")
	street.call("_text",parent,"MenuLettering",words,Vector3(0,.83,-.033),.065,Color("#d5c8a9"))

static func _counter(street: Node3D, parent: Node3D, x: float, width: float, height: float = 1.0925) -> void:
	var body_height: float = height-.185
	var center_y: float = .11+body_height*.5
	_b(street,parent,"CounterBody",Vector3(x,center_y,0),Vector3(width,body_height,.63),"detail_darkwood")
	_b(street,parent,"CounterFrontInset",Vector3(x,center_y,-.325),Vector3(width-.10,body_height-.16,.025),"detail_wood")
	_b(street,parent,"CounterTop",Vector3(x,height-.0375,0),Vector3(width+.08,.075,.74),"detail_wood")
	for i: int in range(5):
		_b(street,parent,"CounterTimberJoint",Vector3(x-width*.4+float(i)*width*.2,center_y,-.343),Vector3(.012,body_height-.20,.012),"detail_darkwood")

static func _jar(street: Node3D, parent: Node3D, pos: Vector3, variant: int) -> void:
	parent.set_meta("aftermath_jar_count",int(parent.get_meta("aftermath_jar_count",0))+1)
	_cylinder(street,parent,"PantryJar",pos+Vector3(0,.10,0),.065,.20,"detail_amber" if variant%2 == 0 else "detail_ceramic")
	_cylinder(street,parent,"JarLid",pos+Vector3(0,.21,0),.069,.025,"detail_metal")
	_b(street,parent,"JarPaperLabel",pos+Vector3(0,.105,-.064),Vector3(.07,.055,.008),"detail_paper")

static func _cup(street: Node3D, parent: Node3D, pos: Vector3) -> void:
	var profile: Array[Vector2] = [Vector2(0,0),Vector2(.030,0),Vector2(.035,.015),Vector2(.046,.108),Vector2(.044,.114),Vector2(.038,.114),Vector2(.037,.102),Vector2(.028,.014),Vector2(0,.014)]
	_lathe(street,parent,"PorcelainCupWithOpenRim",profile,pos,1.0,"detail_ceramic")
	_cylinder(street,parent,"CoffeeSurface",pos+Vector3(0,.100,0),.037,.003,"detail_chocolate")
	var handle_mesh := TorusMesh.new()
	handle_mesh.inner_radius = .019
	handle_mesh.outer_radius = .029
	handle_mesh.rings = 14
	handle_mesh.ring_segments = 5
	var handle := MeshInstance3D.new()
	handle.name = "PorcelainCupHandle"
	handle.mesh = handle_mesh
	handle.material_override = street.get("materials")["detail_ceramic"]
	handle.position = pos+Vector3(.052,.060,0)
	handle.rotation.x = PI*.5
	parent.add_child(handle)

static func _books(street: Node3D, counter: Node3D, rear: Node3D, left: Node3D, right: Node3D, ext_left: Node3D, ext_right: Node3D) -> void:
	_shelf(street,rear,9.3,2.45)
	for level: int in range(4):
		for bay: int in range(5):
			_book_row(street,rear,Vector3(-4.28+float(bay)*1.82,.245+float(level)*.55,-.02),16,level+bay)
	_display_rack(street,left,2.35,5)
	_display_rack(street,right,2.35,5)
	_counter(street,counter,-3.45,1.55)
	_book_stack(street,counter,Vector3(-3.8,1.10,-.10),0)
	_book_stack(street,counter,Vector3(-3.25,1.10,.09),1)
	_counter(street,counter,2.70,2.6)
	for i: int in range(4): _book_stack(street,counter,Vector3(1.75+float(i)*.62,1.10,0),i)
	_exterior_contents(street,"books",ext_left,ext_right)

static func _rod(street: Node3D, parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, key: String) -> void:
	var member := _cylinder(street,parent,label,(a+b)*.5,radius,a.distance_to(b),key)
	member.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

static func _bentwood_chair(street: Node3D, parent: Node3D, pos: Vector3, angle: float) -> void:
	var scene := load("res://assets/shinrai/streets/midori_frontage_construction/mori_bentwood_chair.glb") as PackedScene
	if scene == null:
		push_error("Required constructed cafe chair is missing")
		return
	var chair := scene.instantiate() as Node3D
	chair.name = "BentwoodCafeChair"
	chair.position = pos
	chair.rotation.y = angle
	chair.set_meta("constructed_cafe_chair",true)
	parent.add_child(chair)

static func _table(street: Node3D, parent: Node3D, x: float) -> void:
	var setting := Node3D.new()
	setting.name = "CafeBistroSetting"
	setting.position = Vector3(x,.11,0)
	parent.add_child(setting)
	_cafe_table(street,setting)
	for side: float in [-1.0,1.0]:
		_bentwood_chair(street,setting,Vector3(0,0,side*.62),0.0 if side > 0 else PI)

static func _cafe_table(street: Node3D, parent: Node3D) -> void:
	_cylinder(street,parent,"RoundTimberBistroTop",Vector3(0,.75,0),.35,.028,"detail_wood")
	_cylinder(street,parent,"TableEdgeBand",Vector3(0,.744,0),.352,.015,"detail_darkwood")
	_cylinder(street,parent,"CastMetalTableStem",Vector3(0,.38,0),.035,.68,"detail_metal")
	for i: int in range(3):
		var angle := float(i)*TAU/3.0
		_rod(street,parent,"SplayedBistroFoot",Vector3(0,.13,0),Vector3(cos(angle)*.28,.025,sin(angle)*.28),.023,"detail_metal")
	_cylinder(street,parent,"CupSaucer",Vector3(-.14,.770,-.07),.075,.012,"detail_ceramic")
	_cup(street,parent,Vector3(-.14,.777,-.07))
	_b(street,parent,"FoldedTableMenu",Vector3(.14,.88,.035),Vector3(.12,.18,.025),"detail_paper")

static func _coffee(street: Node3D, counter: Node3D, rear: Node3D, left: Node3D, right: Node3D, ext_left: Node3D, ext_right: Node3D) -> void:
	_counter(street,counter,-2.7,2.9)
	_artisan_prop(rear,"artisan_espresso.glb","RearArtisanEspressoMachine",Vector3(-3.18,1.133,-.02),.84)
	for x: float in [-3.36,-3.07]: _cup(street,counter,Vector3(x,1.10,-.21))
	_cylinder(street,rear,"GrinderHopper",Vector3(-2.48,1.52,.02),.105,.26,"detail_amber",.08)
	_b(street,rear,"GrinderBase",Vector3(-2.48,1.24,.02),Vector3(.22,.29,.23),"detail_metal")
	_b(street,counter,"PaymentTerminal",Vector3(-1.65,1.17,-.12),Vector3(.19,.14,.14),"detail_ink")
	_table(street,counter,1.85)
	_table(street,counter,3.45)
	_b(street,rear,"CoffeeRearCabinet",Vector3(-2.65,.60,0),Vector3(3.4,.98,.32),"detail_darkwood")
	_b(street,rear,"RearWorktop",Vector3(-2.65,1.105,0),Vector3(3.42,.055,.34),"detail_wood")
	for y: float in [1.87,2.37]:
		_b(street,rear,"CoffeeUpperShelf",Vector3(-2.65,y,0),Vector3(3.4,.045,.32),"detail_wood")
	for i: int in range(8): _jar(street,rear,Vector3(-4.05+float(i)*.39,1.90,-.015),i)
	_b(street,rear,"CoffeeWallMenu",Vector3(1.60,1.66,-.06),Vector3(2.20,1.18,.06),"detail_ink")
	street.call("_text",rear,"CoffeeMenu","MORI COFFEE\nFILTER  450\nLATTE  550\nTEA  400\nTODAY'S CAKE",Vector3(1.60,1.67,-.095),.12,Color("#d9ccad"))
	_b(street,left,"WindowBeanDisplay",Vector3(0,.71,0),Vector3(2.35,.10,.45),"detail_wood")
	for x: float in [-.96,.96]: _b(street,left,"BeanDisplayLeg",Vector3(x,.39,0),Vector3(.05,.58,.32),"detail_darkwood")
	for i: int in range(3):
		_b(street,left,"CoffeeBeanBag",Vector3(-.94+float(i)*.27,.94,0),Vector3(.22,.37,.17),"detail_paper")
		_b(street,left,"BeanBagLabel",Vector3(-.94+float(i)*.27,.97,-.089),Vector3(.13,.10,.006),"detail_sage")
	_b(street,right,"PastryDisplayTable",Vector3(0,.69,0),Vector3(2.15,.09,.45),"detail_wood")
	for x: float in [-.83,.83]: _b(street,right,"WindowTableLeg",Vector3(x,.39,0),Vector3(.05,.60,.32),"detail_darkwood")
	_pastry_case(street,right)
	# The visible machine occupies the front display layer, ahead of the back bar.
	_b(street,left,"FrontMachineSupportPlinth",Vector3(.40,.86,.04),Vector3(.88,.20,.43),"detail_wood")
	_artisan_prop(left,"artisan_espresso.glb","FrontArtisanEspressoMachine",Vector3(.40,.96,.04))
	_exterior_contents(street,"coffee",ext_left,ext_right)

static func _crate(street: Node3D, parent: Node3D, pos: Vector3, width: float, variant: int, sparse: bool = false) -> void:
	_b(street,parent,"CrateBottom",pos+Vector3(0,.035,0),Vector3(width,.045,.44),"detail_darkwood")
	for side: float in [-1.0,1.0]:
		for z: float in [-.20,.20]:
			_b(street,parent,"CrateCorner",pos+Vector3(side*(width*.5-.027),.17,z),Vector3(.045,.31,.045),"detail_wood")
		# Separated narrow slats expose the contents and the empty gaps.
		for y: float in [.105,.215]:
			_b(street,parent,"OpenCrateLongSlat",pos+Vector3(0,y,side*.215),Vector3(width,.055,.027),"detail_wood")
			_b(street,parent,"OpenCrateEndSlat",pos+Vector3(side*(width*.5-.018),y,0),Vector3(.027,.055,.44),"detail_wood")
		# Split the end's top rail around a visible hand opening.
		for z: float in [-.145,.145]:
			_b(street,parent,"CrateHandleRail",pos+Vector3(side*(width*.5-.018),.29,z),Vector3(.032,.055,.15),"detail_wood")
	var columns := 4 if width < .80 else 5
	if sparse: parent.set_meta("aftermath_sparse_crate_count",int(parent.get_meta("aftermath_sparse_crate_count",0))+1)
	for layer: int in range(2):
		for row: int in range(2):
			for i: int in range(columns):
				# Sparse mode belongs only to Hinata's abandoned shop displays.
				# Keep every crate/slat; two of three variants retain one old remnant.
				if sparse and (layer != 0 or row != 0 or i != columns-2 or variant%3 == 2): continue
				if layer == 1 and (i+row+variant)%3 == 0: continue
				var seed_index := i+row*7+layer*13+variant*5
				var x := lerpf(-width*.36,width*.36,float(i)/float(columns-1))+.010*sin(float(seed_index)*2.7)
				var z := -.085+float(row)*.16+.011*cos(float(seed_index)*1.9)
				var y := .115+float(layer)*.106+.005*sin(float(seed_index))
				_produce(street,parent,pos+Vector3(x,y,z),variant%4,seed_index,.051 if variant%4 != 3 else .044,sparse)
	if sparse: return # Old price cards have been removed from these empty crates.
	var kind_names: Array[String] = ["MIKAN","APPLES","PEARS","DAIKON"]
	_b(street,parent,"ProducePriceCard",pos+Vector3(0,.33,-.24),Vector3(.24,.105,.012),"detail_paper")
	_print(parent,"ProduceVarietyLabel",kind_names[variant%4]+"  280",pos+Vector3(0,.33,-.248),.020,Color("#3f4937"))

static func _provisions(street: Node3D, counter: Node3D, rear: Node3D, left: Node3D, right: Node3D, ext_left: Node3D, ext_right: Node3D) -> void:
	_shelf(street,rear,8.4,2.45)
	for level: int in range(4):
		for i: int in range(13):
			if (i+level*3)%7 != 1: continue
			var p := Vector3(-3.8+float(i)*.62,.245+float(level)*.55,0)
			if (i+level)%3 == 0: _jar(street,rear,p,i)
			else:
				_b(street,rear,"PantryCarton",p+Vector3(0,.16,0),Vector3(.20,.30,.20),"detail_paper" if i%2 == 0 else "detail_sage")
				_b(street,rear,"CartonLabel",p+Vector3(0,.17,-.105),Vector3(.12,.07,.006),"detail_rust")
	_counter(street,counter,-2.75,2.9,.89)
	_counter(street,counter,2.75,2.9,.89)
	for side: float in [-1.0,1.0]:
		for i: int in range(3): _crate(street,counter,Vector3(side*2.75+(float(i)-1.0)*.85,.895,0),.75,i,true)
	for parent: Node3D in [left,right]:
		_b(street,parent,"WindowProduceBench",Vector3(0,.56,0),Vector3(2.35,.10,.49),"detail_darkwood")
		for x: float in [-.96,.96]: _b(street,parent,"ProduceBenchLeg",Vector3(x,.32,0),Vector3(.06,.48,.36),"detail_wood")
		for i: int in range(3): _crate(street,parent,Vector3((float(i)-1.0)*.78,.62,0),.70,i,true)
	_exterior_contents(street,"provisions",ext_left,ext_right)

static func _yakitori(street: Node3D, counter: Node3D, rear: Node3D, left: Node3D, right: Node3D, ext_left: Node3D, ext_right: Node3D) -> void:
	_shelf(street,rear,3.65,2.45)
	for level: int in range(3):
		for i: int in range(8):
			var p := Vector3(-1.53+float(i)*.43,.245+float(level)*.55,0)
			_cylinder(street,rear,"SakeBottle",p+Vector3(0,.145,0),.05,.29,"detail_sage")
			_cylinder(street,rear,"BottleNeck",p+Vector3(0,.325,0),.025,.09,"detail_ink")
			_b(street,rear,"BottleLabel",p+Vector3(0,.15,-.052),Vector3(.065,.095,.005),"detail_paper")
	_counter(street,counter,-1.52,1.12)
	_counter(street,counter,1.52,1.12)
	for side: float in [-1.0,1.0]:
		for i: int in range(3):
			var x: float = side*1.52+(float(i)-1.0)*.28
			_cylinder(street,counter,"ServingPlate",Vector3(x,1.103,-.04),.11,.018,"detail_ceramic")
			_b(street,counter,"ChopstickPair",Vector3(x+.04,1.12,-.07),Vector3(.009,.008,.16),"detail_wood")
	for parent: Node3D in [left,right]:
		_b(street,parent,"WindowBar",Vector3(0,.94,0),Vector3(1.15,.065,.42),"detail_wood")
		for x: float in [-.41,.41]: _b(street,parent,"BarLeg",Vector3(x,.52,0),Vector3(.055,.80,.30),"detail_darkwood")
		_cup(street,parent,Vector3(-.22,.975,0))
		_jar(street,parent,Vector3(.25,.975,0),0)
	_exterior_contents(street,"yakitori",ext_left,ext_right)

# Shop-specific outdoor silhouettes. Local X within +/- .90 stays empty, and
# every object fits the existing pavement between the facade and world Z 191.9.
static func _bookshop_frontage(street: Node3D, parent: Node3D) -> void:
	var rack := Node3D.new()
	rack.name = "BooksellerFaceOutRack"
	rack.position = Vector3(-3.10,0,-.95)
	rack.rotation.y = -.08
	parent.add_child(rack)
	for side: float in [-1.0,1.0]:
		_rod(street,rack,"RackAngledSide",Vector3(side*.73,.04,-.31),Vector3(side*.73,1.51,.12),.034,"detail_darkwood")
		_rod(street,rack,"RackRearBrace",Vector3(side*.73,.04,.37),Vector3(side*.73,1.37,.08),.028,"detail_darkwood")
	for level: int in range(3):
		var y := .23+float(level)*.43
		var z := -.24+float(level)*.12
		_b(street,rack,"BooksellerSlopedBacking",Vector3(0,y+.18,z+.055),Vector3(1.48,.38,.045),"detail_wood").rotation.x = -.20
		_b(street,rack,"DeepBookRackLedge",Vector3(0,y,z-.04),Vector3(1.55,.06,.24),"detail_wood")
		for i: int in range(4):
			_face_book(street,rack,Vector3(-.56+float(i)*.37,y+.20,z-.075),.29,.34,level+i)
	street.call("_text",rack,"BooksellerRackHeader","NEW + SELECTED",Vector3(0,1.64,.03),.115,Color("#e5d7b8"))
	_b(street,rack,"RackHeaderBoard",Vector3(0,1.64,.055),Vector3(1.56,.21,.045),"detail_darkwood")
	var table := Node3D.new()
	table.name = "BooksellerBrowseTable"
	table.position = Vector3(2.75,0,-.77)
	parent.add_child(table)
	_b(street,table,"BrowseTableTop",Vector3(0,.72,0),Vector3(1.85,.075,.66),"detail_wood")
	for x: float in [-.75,.75]:
		for z: float in [-.23,.23]: _rod(street,table,"BrowseTableLeg",Vector3(x,.025,z),Vector3(x,.69,z),.030,"detail_darkwood")
	for i: int in range(4): _book_stack(street,table,Vector3(-.63+float(i)*.43,.76,.02),i)
	for i: int in range(3): _face_book(street,table,Vector3(-.58+float(i)*.55,1.02,.21),.36,.43,i+2)

static func _face_book(street: Node3D, parent: Node3D, pos: Vector3, width: float, height: float, variant: int) -> void:
	var cover_keys: Array[String] = ["detail_sage","detail_rust","detail_blue","detail_cream"]
	var titles: Array[String] = ["GARDEN\nNOTES","TOKYO\nWALKS","QUIET\nFORMS","THE\nSEASONS","FIELD\nJOURNAL","LOCAL\nSTORIES"]
	var volume := Node3D.new()
	volume.name = "FaceOutFeaturedVolume"
	volume.position = pos
	volume.rotation.x = -.15
	parent.add_child(volume)
	_soft_block(street,volume,"RoundedBookPageBlock",Vector3.ZERO,Vector3(width-.012,height-.014,.045),"detail_paper")
	for z: float in [-.027,.027]:
		_soft_block(street,volume,"RoundedPrintedCover",Vector3(0,0,z),Vector3(width,height,.009),cover_keys[variant%4])
	# Designed covers use a typographic hierarchy and restrained line motif,
	# rather than a bright generic rectangle pretending to be a photograph.
	var ink := Color("#424e3e") if variant%4 == 3 else Color("#e6ddc5")
	_print(volume,"PrintedBookTitle",titles[variant%titles.size()],Vector3(0,height*.17,-.033),width*.092,ink)
	_print(volume,"PrintedBookImprint","UEDA EDITIONS",Vector3(0,-height*.37,-.033),width*.041,ink)
	_b(street,volume,"CoverFineRule",Vector3(0,-height*.25,-.033),Vector3(width*.72,.0025,.002),"detail_paper")
	for i: int in range(3):
		var line := _b(street,volume,"CoverBotanicalLine",Vector3((float(i)-1.0)*width*.13,-height*.10,-.034),Vector3(.002,height*.14,.002),"detail_paper")
		line.rotation.z = -.28+float(i)*.28
	_flatten_new_prop(volume,parent)

static func _pastry_case(street: Node3D, parent: Node3D) -> void:
	# Transparent case with a sloped front, framed corners and two tray heights.
	_b(street,parent,"PastryCaseBase",Vector3(0,.79,0),Vector3(1.98,.12,.51),"detail_darkwood")
	for x: float in [-.98,.98]:
		_rod(street,parent,"PastryCaseFrontUpright",Vector3(x,.85,-.26),Vector3(x,1.35,-.12),.018,"detail_metal")
		_rod(street,parent,"PastryCaseRearUpright",Vector3(x,.85,.23),Vector3(x,1.35,.23),.018,"detail_metal")
	_b(street,parent,"PastryCaseGlassTop",Vector3(0,1.35,.055),Vector3(2.0,.014,.37),"arch_glass")
	var glazing := _b(street,parent,"PastryCaseSlopedGlass",Vector3(0,1.10,-.19),Vector3(1.96,.52,.012),"arch_glass")
	glazing.rotation.x = .273
	for level: int in range(2):
		var y := .87+float(level)*.235
		_b(street,parent,"PatisserieTray",Vector3(0,y,.025),Vector3(1.78,.022,.30),"detail_ceramic")
		for i: int in range(5):
			var x := -.70+float(i)*.35
			_cylinder(street,parent,"PatisserieIndividualPlate",Vector3(x,y+.019,.025),.137,.016,"detail_ceramic")
			if (i+level)%2 == 0:
				_cake(street,parent,Vector3(x,y+.027,.025),i+level)
			else:
				_artisan_prop(parent,"artisan_pastry.glb","ArtisanButterCroissant",Vector3(x,y+.027,.025),.94+.04*float(i%3),-.12+.065*float(i))

		_b(street,parent,"PastryPriceCard",Vector3(.66,y+.09,-.15),Vector3(.20,.11,.012),"detail_paper")
		_print(parent,"PatisseriePriceLettering","BAKED TODAY",Vector3(.66,y+.09,-.158),.016,Color("#4a4939"))

static func _cafe_frontage(street: Node3D, parent: Node3D) -> void:
	for side: float in [-1.0,1.0]:
		var setting := Node3D.new()
		setting.name = "OutdoorCafeSetting"
		setting.position = Vector3(side*2.50,0,-1.22)
		parent.add_child(setting)
		_cafe_table(street,setting)
		# Side seating keeps the full shop entry axis and the sidewalk apron open.
		_bentwood_chair(street,setting,Vector3(-.65,0,.04),-PI*.5+.09)
		_bentwood_chair(street,setting,Vector3(.65,0,.04),PI*.5-.07)

static func _grocer_frontage(street: Node3D, parent: Node3D) -> void:
	for side: float in [-1.0,1.0]:
		var stand := Node3D.new()
		stand.name = "SteppedSeasonalProduceStand"
		stand.position = Vector3(side*2.80,0,-.90)
		stand.rotation.y = side*.055
		parent.add_child(stand)
		for x: float in [-.88,.88]:
			_b(street,stand,"ProduceStandSideFrame",Vector3(x,.48,.06),Vector3(.065,.90,.58),"detail_darkwood")
		for level: int in range(2):
			var y := .30+float(level)*.46
			var z := -.19+float(level)*.33
			_b(street,stand,"ProduceTierShelf",Vector3(0,y,z),Vector3(1.90,.065,.49),"detail_wood")
			for bay: int in range(2):
				var px := -.47+float(bay)*.94
				_crate(street,stand,Vector3(px,y+.04,z),.86,level+bay+(0 if side < 0 else 1),true)
		_b(street,stand,"SeasonalProduceHeader",Vector3(0,1.42,.24),Vector3(1.92,.22,.05),"detail_darkwood")
		street.call("_text",stand,"SeasonalProduceLettering","NO RESTOCK",Vector3(0,1.43,.207),.10,Color("#e5d7b8"))
		# Open wicker wall and rim: the top is hollow, with visible curved stakes.
		_open_basket(street,stand,Vector3(.61,.01,-.59))
		# One wilted radish left in the west basket; the other basket is empty.
		if side < 0:
			_produce(street,stand,Vector3(.60,.26,-.65),3,6,.061,true)

static func _yakitori_frontage(street: Node3D, parent: Node3D) -> void:
	for side: float in [-1.0,1.0]:
		var bar := Node3D.new()
		bar.name = "YakitoriStreetCounter"
		bar.position = Vector3(side*1.55,0,-.69)
		parent.add_child(bar)
		_b(street,bar,"ThickCedarServiceLedge",Vector3(0,.98,0),Vector3(1.16,.09,.46),"detail_wood")
		for x: float in [-.43,.43]:
			_rod(street,bar,"CounterWallBracket",Vector3(x,.55,.19),Vector3(x,.93,-.15),.027,"detail_metal")
		_cylinder(street,bar,"HandThrownServingBowl",Vector3(.27,1.06,0),.115,.09,"detail_ceramic",.14)
		_cup(street,bar,Vector3(-.28,1.03,0))
		# A stool in each side bay keeps the central doorway completely open.
		_cylinder(street,bar,"RoundBarStoolSeat",Vector3(0,.65,-.64),.20,.065,"detail_darkwood")
		for x: float in [-.12,.12]:
			for z: float in [-.12,.12]:
				_rod(street,bar,"SplayedBarStoolLeg",Vector3(x*1.28,.025,-.64+z*1.28),Vector3(x,.62,-.64+z),.022,"detail_wood")
		_rod(street,bar,"StoolFootrest",Vector3(-.15,.25,-.78),Vector3(.15,.25,-.78),.017,"detail_wood")

static func _cake(street: Node3D, parent: Node3D, bottom: Vector3, variant: int) -> void:
	var chocolate: bool = variant%3 == 1
	_cylinder(street,parent,"LayeredPatisserieCake",bottom+Vector3(0,.042,0),.105,.084,"detail_chocolate" if chocolate else "detail_cake")
	_cylinder(street,parent,"CakeCreamLayer",bottom+Vector3(0,.041,0),.107,.013,"detail_ceramic")
	_cylinder(street,parent,"SoftIcingTop",bottom+Vector3(0,.090,0),.109,.014,"detail_ceramic" if not chocolate else "detail_chocolate",.105)
	# A small offset topping keeps the cakes individual and proportionate.
	var berry := SphereMesh.new()
	berry.radius = .019
	berry.height = .029
	berry.radial_segments = 12
	berry.rings = 6
	var topping := MeshInstance3D.new()
	topping.name = "CakeBerryTopping"
	topping.mesh = berry
	topping.position = bottom+Vector3(.025,.113,-.015)
	topping.material_override = street.get("materials")["detail_apple"]
	parent.add_child(topping)
	_leaf(street,parent,bottom+Vector3(.02,.107,-.01),.033,float(variant))

static func _open_basket(street: Node3D, parent: Node3D, bottom: Vector3) -> void:
	var profile: Array[Vector2] = [Vector2(0,0),Vector2(.21,0),Vector2(.225,.025),Vector2(.27,.27),Vector2(.267,.285),Vector2(.250,.285),Vector2(.248,.26),Vector2(.209,.025),Vector2(0,.025)]
	_lathe(street,parent,"OpenWickerBasketWall",profile,bottom,1.0,"detail_wood")
	for ring: int in range(5):
		var y := .035+float(ring)*.06
		var radius := .227+y*.15
		var mesh := TorusMesh.new()
		mesh.inner_radius = radius-.006
		mesh.outer_radius = radius+.006
		mesh.rings = 20
		mesh.ring_segments = 5
		var weave := MeshInstance3D.new()
		weave.name = "BasketHorizontalWeave"
		weave.mesh = mesh
		weave.position = bottom+Vector3(0,y,0)
		weave.material_override = street.get("materials")["detail_darkwood"]
		parent.add_child(weave)
	for i: int in range(16):
		var angle := float(i)*TAU/16.0
		_rod(street,parent,"BasketVerticalStake",bottom+Vector3(cos(angle)*.225,.025,sin(angle)*.225),bottom+Vector3(cos(angle)*.270,.277,sin(angle)*.270),.005,"detail_darkwood")
