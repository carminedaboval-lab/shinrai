extends RefCounted
## Independent, shop-owned physical identities; no new lights/collisions/processes.
const BrandSigns = preload("res://scripts/midori_brand_signs.gd")
const Details = preload("res://scripts/midori_south_street_details.gd")

static func build(street: Node3D) -> Dictionary:
	var collisions_before: int = street.find_children("*","CollisionObject3D",true,false).size()
	var lights_before: int = street.find_children("*","Light3D",true,false).size()
	_materials(street)
	var shops: Array[Dictionary] = []
	for id: String in ["MoriCoffee","UedaBooks","HinataDaily","YakitoriShop"]:
		var shop := street.get_node_or_null(id) as Node3D
		if shop == null: continue
		var old := shop.get_node_or_null("CleanShopName")
		if old != null: old.free()
		var group := _group(shop,"ExteriorShopIdentity")
		var sockets: Array[Node3D] = _retire_menus(shop)
		var row: Dictionary = {}
		match id:
			"MoriCoffee": row = _mori(street,group,sockets)
			"UedaBooks": row = _ueda(street,group)
			"HinataDaily": row = _hinata(street,group,sockets)
			"YakitoriShop": row = _yakitori(street,group,shop)
		row["id"] = id
		row["entry_clear_width_m"] = 1.60
		row["collision_changed"] = false
		group.set_meta("shopfront_identity",row)
		shops.append(row)
	var gallery := street.get_node_or_null("CeramicsGallery/CeramicsGalleryExterior") as Node3D
	if gallery != null: shops.append(_haku(street,gallery))
	var collisions_after: int = street.find_children("*","CollisionObject3D",true,false).size()
	var lights_after: int = street.find_children("*","Light3D",true,false).size()
	var complete: bool = shops.size()==5
	for shop_row: Dictionary in shops:
		if shop_row.has("letter_asset_loaded"): complete = complete and bool(shop_row.letter_asset_loaded)
		if shop_row.has("plaque_asset_loaded"): complete = complete and bool(shop_row.plaque_asset_loaded)
	var report := {"ok":complete,"shops":shops,"new_lights":lights_after-lights_before,"new_collisions":collisions_after-collisions_before,"baseline_collisions_before":collisions_before,"baseline_collisions_after":collisions_after,"baseline_lights_before":lights_before,"baseline_lights_after":lights_after,"per_frame_scripts":0,"source_assets_modified":false,"asset_directory":BrandSigns.ASSET_ROOT,"shared_mandatory_sign_template":false}
	street.set_meta("exterior_shop_identity",report)
	return report

static func _materials(street: Node3D) -> void:
	for row: Array in [["mori_enamel","#173C32",.72],["mori_paper","#E9E0C9",.86],["mori_mount","#887A59",.48],["ueda_timber","#61513C",.91],["ueda_agedpaint","#DBD1B4",.94],["ueda_bracket","#3A3E3D",.76],["hinata_enamel","#EEE5C7",.57],["hinata_ochre","#B58A35",.7],["hinata_frame","#596449",.83],["yakitori_wood","#312922",.93],["yakitori_cloth","#372F2C",.99],["haku_ceramic","#E7DFCE",.38],["haku_reveal","#8A7C67",.87]]:
		# Dedicated keys avoid mutating shared architectural materials.
		street.call("_material",row[0],Color(row[1]),float(row[2]))

static func _group(parent: Node3D,label: String) -> Node3D:
	var group := Node3D.new()
	group.name = label
	group.set_meta("creator_protected",true)
	group.set_meta("creator_editable",false)
	parent.add_child(group)
	return group

static func _box(street: Node3D,parent: Node3D,label: String,p: Vector3,size: Vector3,key: String) -> MeshInstance3D:
	return street.call("_box",parent,label,p,size,key,false) as MeshInstance3D

static func _label(parent: Node3D,label: String,text: String,p: Vector3,height: float,ink: Color) -> void:
	var visual: Label3D = Details._print(parent,label,text,p,height,ink)
	visual.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _art(parent: Node3D,label: String,brand: String,variant: String,p: Vector3,bounds: Vector2) -> Vector2:
	var size: Vector2 = BrandSigns.fitted_dimensions(brand,variant,bounds)
	BrandSigns.print_surface(parent,label,brand,variant,p,size)
	return size

static func _screws(street: Node3D,parent: Node3D,center: Vector3,size: Vector2,key: String) -> void:
	for x: float in [-1.0,1.0]:
		for y: float in [-1.0,1.0]:
			_pin(street,parent,"FaceFixing",center+Vector3(x*(size.x*.5-.035),y*(size.y*.5-.035),0),.006,.004,key)

static func _pin(street: Node3D,parent: Node3D,label: String,p: Vector3,radius: float,depth: float,key: String) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = depth
	cylinder.radial_segments = 10
	var pin := MeshInstance3D.new()
	pin.name = label
	pin.mesh = cylinder
	pin.position = p
	pin.rotation.x = PI*.5
	pin.material_override = street.get("materials")[key]
	parent.add_child(pin)

static func _retire_menus(shop: Node3D) -> Array[Node3D]:
	var sockets: Array[Node3D] = []
	for label: Node in shop.find_children("MenuLettering","Label3D",true,false):
		var socket := label.get_parent() as Node3D
		sockets.append(socket)
		label.free()
		# Remove only the old menu assembly, preserving socket-owned stock/lanterns.
		for child: Node in socket.get_children():
			if child is MeshInstance3D and child.position.y < 1.21 and absf(child.position.x) < .31 and absf(child.position.z) < .20:
				child.free()
	return sockets

static func _entrance_english(street: Node3D,parent: Node3D,brand: String,key: String,width: float=.74) -> void:
	# Attached to the existing solid lintel, above the 2.79m shop glazing.
	_box(street,parent,"EntranceEnglishPlaque",Vector3(-1.30,2.94,-.051),Vector3(width,.115,.012),key)
	_art(parent,"EntranceEnglish",brand,"english",Vector3(-1.30,2.94,-.059),Vector2(width-.055,.085))

static func _mori(street: Node3D,parent: Node3D,sockets: Array[Node3D]) -> Dictionary:
	var center := Vector3(1.665,3.33,-.181)
	# The existing architectural backing stays pale; these are individual letters.
	var packed := load(BrandSigns.ASSET_ROOT+"mori_letters.glb") as PackedScene
	var mounted := _group(parent,"MoriMountedLetters")
	mounted.position = center
	var letter_count: int = 0
	if packed != null:
		var letters := packed.instantiate() as Node3D
		mounted.add_child(letters)
		var glyphs: Array[Node] = letters.find_children("*","MeshInstance3D",true,false)
		letter_count = glyphs.size()
		for node: Node in glyphs:
			var glyph := node as MeshInstance3D
			for surface: int in range(glyph.mesh.get_surface_count()):
				var intrinsic := glyph.get_active_material(surface) as StandardMaterial3D
				if intrinsic == null: continue
				var bronze := intrinsic.duplicate() as StandardMaterial3D
				bronze.resource_name = "MoriInstanceAgedBronze"
				bronze.albedo_color = Color("#64513A")
				bronze.roughness = .42
				bronze.metallic = .65
				glyph.set_surface_override_material(surface,bronze)
	# Small spacers sit behind the actual letter array, anchored to backing front -.14.
	for x: float in [-.43,0,.43]:
		_pin(street,mounted,"LetterMountingPin",Vector3(x,0,.0205),.005,.041,"mori_mount")
	var emblem := _group(parent,"MoriRoundEmblem")
	emblem.position = Vector3(.55,3.33,-.181)
	_pin(street,emblem,"PierRoundelSpacer",Vector3(0,0,.0275),.035,.027,"mori_mount")
	_pin(street,emblem,"EnamelRoundel",Vector3.ZERO,.18,.028,"mori_enamel")
	_art(emblem,"CafeEmblem","mori","mark",Vector3(0,0,-.016),Vector2(.285,.285))
	_entrance_english(street,parent,"mori","mori_enamel")
	if not sockets.is_empty():
		var menu := _group(sockets[0],"MoriCompactMenu")
		menu.position.z = -.72
		_compact_cafe_menu(street,menu)
	return {"treatment":"individual_metal_letters_round_emblem_fabric_awning","main_center_m":center,"main_asset":"mori_letters.glb","main_size_m":Vector3(1.3457338,.40,.020),"letter_meshes":letter_count,"letter_asset_loaded":packed != null,"emblem_center_m":emblem.position,"emblem_diameter_m":.36,"materials":["per_instance_aged_bronze_64513A","mori_enamel","mori_mount"],"blade_count":0,"menu_boards":1 if not sockets.is_empty() else 0,"awning":"existing_green_scalloped_fabric","sign_backing":"existing_pale_architectural_backing"}

static func _compact_cafe_menu(street: Node3D,parent: Node3D) -> void:
	# One compact supported cafe menu; the second old menu is retired.
	for x: float in [-.19,.19]:
		for z: float in [-.12,.16]:
			_box(street,parent,"CafeMenuLeg",Vector3(x,.50,z),Vector3(.027,.98,.027),"detail_wood")
			_box(street,parent,"CafeMenuFoot",Vector3(x,.018,z),Vector3(.04,.016,.05),"arch_metal")
	_box(street,parent,"CafeMenuFrame",Vector3(0,.77,0),Vector3(.46,.65,.045),"detail_wood")
	_box(street,parent,"CafeMenuPaper",Vector3(0,.77,-.026),Vector3(.408,.59,.01),"mori_paper")
	for i: int in range(4):
		var lines := ["HOUSE BLEND","POUR OVER  480","TEA + TODAY'S CAKE","BEANS TO TAKE HOME"]
		_label(parent,"CafeDailyLine%d"%i,lines[i],Vector3(0,.97-float(i)*.12,-.033),.031,Color("#24392F"))
	_box(street,parent,"CafeRearTie",Vector3(0,.25,.15),Vector3(.40,.025,.025),"detail_wood")

static func _ueda(street: Node3D,parent: Node3D) -> Dictionary:
	var center := Vector3(1.845,3.33,-.166)
	_box(street,parent,"UedaRearMountingCleat",center+Vector3(0,0,.024),Vector3(2.32,.15,.010),"ueda_timber")
	_box(street,parent,"UedaPaintedTimberSign",center,Vector3(2.48,.43,.044),"ueda_agedpaint")
	# Sparse endgrain strips and maintained timber edges, not distressed illegibility.
	for y: float in [-.198,.198]:
		_box(street,parent,"UedaTimberBoardEdge",center+Vector3(0,y,-.003),Vector3(2.48,.021,.048),"ueda_timber")
	var size := _art(parent,"UedaPaintedJapanese","ueda","fascia",center+Vector3(0,0,-.024),Vector2(2.20,.35))
	_screws(street,parent,center+Vector3(0,0,-.025),Vector2(2.48,.43),"ueda_bracket")
	var blade := _group(parent,"UedaSupportedVerticalSign")
	# Outer pier width .26m, center x5.37; blade lies beyond the deck edge x4.875.
	blade.position = Vector3(5.37,2.55,-.47)
	blade.rotation.y = PI*.5
	_box(street,blade,"VerticalTimberCore",Vector3.ZERO,Vector3(.27,.98,.038),"ueda_timber")
	for back: bool in [false,true]:
		var face := _group(blade,"Back" if back else "Front")
		if back: face.rotation.y=PI
		_box(street,face,"PaintedVerticalFace",Vector3(0,0,-.022),Vector3(.242,.94,.009),"ueda_agedpaint")
		_art(face,"VerticalBookshopLettering","ueda","vertical",Vector3(0,0,-.0285),Vector2(.22,.87))
	for y: float in [2.18,2.92]:
		_box(street,parent,"UedaOuterPierPlate",Vector3(5.37,y,-.065),Vector3(.10,.13,.10),"ueda_bracket")
		_box(street,parent,"UedaSignArm",Vector3(5.37,y,-.28),Vector3(.024,.024,.39),"ueda_bracket")
	_entrance_english(street,parent,"ueda","ueda_agedpaint")
	var privacy: Dictionary = _ueda_privacy_panel(street,parent)
	return {"treatment":"maintained_painted_timber_and_vertical_bookseller_sign","main_center_m":center,"main_size_m":size,"materials":["ueda_timber","ueda_agedpaint","ueda_bracket"],"blade_count":1,"blade_board_size_m":Vector3(.27,.98,.038),"blade_center_m":blade.position,"blade_lowest_local_y":2.06,"blade_mount":"outer solid pier x5.37, outside balcony width","menu_boards":0,"balcony_privacy_screen":privacy}

static func _ueda_privacy_panel(street: Node3D,parent: Node3D) -> Dictionary:
	# One removable infill behind the outer-left existing railing bay.
	# Ueda deck width10.25, first post centres -5.11 and -3.65, topY3.98.
	# Its feet occupy only the front-edge strip; no deck/rail/support is altered.
	var screen := _group(parent,"UedaRemovableBalconyPrivacyPanel")
	screen.position = Vector3(-4.38,0,-1.39)
	for x: float in [-.535,.535]:
		_box(street,screen,"PrivacyPanelEndPost",Vector3(x,4.43,0),Vector3(.035,.86,.035),"ueda_timber")
		_box(street,screen,"PrivacyPanelDeckFoot",Vector3(x,3.99,.02),Vector3(.075,.020,.09),"ueda_bracket")
		for y: float in [4.15,4.71]:
			# Small removable clamps meet existing rails at local z-1.45.
			_box(street,screen,"PrivacyRailClamp",Vector3(x,y,-.030),Vector3(.055,.055,.050),"ueda_bracket")
	for y: float in [4.13,4.80]:
		_box(street,screen,"PrivacyPanelTimberRail",Vector3(0,y,0),Vector3(1.15,.040,.040),"ueda_timber")
	for i: int in range(11):
		_box(street,screen,"PrivacyPanelSpacedSlat",Vector3(-.475+float(i)*.095,4.465,0),Vector3(.055,.63,.025),"ueda_timber")
	return {"panels":1,"slats":11,"center_xz_m":Vector2(-4.38,-1.39),"width_m":1.15,"top_y_m":4.86,"deck_contact_y_m":3.98,"foot_rear_z_m":-1.325,"existing_rail_inner_z_m":-1.4325,"remaining_clear_depth_m":1.135,"structure_modified":false,"removable_clamps":4,"collision_added":false}

static func _hinata(street: Node3D,parent: Node3D,sockets: Array[Node3D]) -> Dictionary:
	var center := Vector3(1.665,3.33,-.162)
	_box(street,parent,"HinataRearMountingRail",center+Vector3(0,0,.020),Vector3(2.60,.10,.008),"hinata_frame")
	_box(street,parent,"HinataEnamelProduceSign",center,Vector3(2.80,.48,.035),"hinata_ochre")
	_box(street,parent,"HinataCreamEnamelFace",center+Vector3(0,0,-.020),Vector3(2.73,.415,.009),"hinata_enamel")
	var size := _art(parent,"HinataProduceJapanese","hinata","fascia",center+Vector3(0,0,-.0265),Vector2(2.55,.37))
	_screws(street,parent,center+Vector3(0,0,-.027),Vector2(2.80,.48),"hinata_frame")
	_entrance_english(street,parent,"hinata","hinata_enamel")
	var count: int = 0
	for socket: Node3D in sockets:
		var board := _group(socket,"HinataPracticalPriceBoard")
		board.position.z = -.75
		# Existing menu socket and .55m apron footprint; distinctive market frame.
		for x: float in [-.23,.23]:
			_box(street,board,"MarketStandUpright",Vector3(x,.59,.04),Vector3(.035,1.15,.035),"hinata_frame")
			_box(street,board,"MarketStandFoot",Vector3(x,.025,.03),Vector3(.045,.03,.34),"hinata_frame")
		_box(street,board,"MarketBoardEnamel",Vector3(0,.84,0),Vector3(.55,.62,.035),"hinata_enamel")
		_box(street,board,"MarketOchreTopRail",Vector3(0,1.17,-.005),Vector3(.55,.045,.05),"hinata_ochre")
		_art(board,"HandwrittenProduceOffers","hinata","offers",Vector3(0,.85,-.020),Vector2(.43,.52))
		count += 1
	return {"treatment":"bright_enamel_produce_board_handwritten_offers_market_shade","main_center_m":center,"main_size_m":size,"materials":["hinata_enamel","hinata_ochre","hinata_frame"],"blade_count":0,"menu_boards":count,"awning":"straight utilitarian valance, flat cloth panels, existing supports","menu_footprint_m":Vector2(.55,.34)}

static func _yakitori(street: Node3D,parent: Node3D,shop: Node3D) -> Dictionary:
	var center := Vector3(0,3.33,-.164)
	_box(street,parent,"YakitoriBrushTimberSign",center,Vector3(1.65,.49,.048),"yakitori_wood")
	var size := _art(parent,"YakitoriBrushJapanese","yakitori","fascia",center+Vector3(0,0,-.026),Vector2(1.48,.42))
	_screws(street,parent,center+Vector3(0,0,-.027),Vector2(1.65,.49),"arch_metal")
	_entrance_english(street,parent,"yakitori","yakitori_wood",.80)
	var leaves: Array[Node] = shop.find_children("PleatedNorenLeaf*","MeshInstance3D",true,false)
	for leaf: Node in leaves: (leaf as MeshInstance3D).material_override=street.get("materials")["yakitori_cloth"]
	# Print one seal on the centre leaf, following its actual four pleats.
	_noren_seal(parent)
	var lanterns: int = shop.find_children("SlimYakitoriLantern*","Node3D",true,false).size()
	return {"treatment":"short_brush_timber_sign_pleated_noren_existing_lanterns","main_center_m":center,"main_size_m":size,"materials":["yakitori_wood","yakitori_cloth"],"blade_count":0,"menu_boards":0,"noren_leaves_existing":leaves.size(),"lanterns_existing":lanterns,"noren_print":"one curved seal on centre leaf","lights_added":0}

static func _noren_seal(parent: Node3D) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(4):
		var breaks: Array[float] = [-.14,-.0775,0,.0775,.14]
		var xa: float = breaks[i]
		var xb: float = breaks[i+1]
		var ua: float = (xa+.14)/.28
		var ub: float = (xb+.14)/.28
		# Same piecewise pleat as existing centre cloth, sampled within its width.
		var za: float = _cloth_z(xa)
		var zb: float = _cloth_z(xb)
		var vertices: Array[Vector3] = [Vector3(xa,2.51,za-.014),Vector3(xb,2.51,zb-.014),Vector3(xb,2.23,zb-.0315),Vector3(xa,2.23,za-.0315)]
		var uvs: Array[Vector2] = [Vector2(1.0-ua,0),Vector2(1.0-ub,0),Vector2(1.0-ub,1),Vector2(1.0-ua,1)]
		# Winding viewed from -Z; UVs keep the actual original seal readable.
		for index: int in [0,2,1,0,3,2]:
			tool.set_normal(Vector3.FORWARD)
			tool.set_uv(uvs[index])
			tool.add_vertex(vertices[index])
	tool.generate_tangents()
	var visual := MeshInstance3D.new()
	visual.name = "YakitoriSealFollowingNorenPleats"
	visual.mesh = tool.commit()
	visual.material_override = BrandSigns.ink_material("yakitori","mark")
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)

static func _cloth_z(x: float) -> float:
	var section: float = clampf((x+.155)/.0775,0,4)
	var index: int = mini(int(section),3)
	return lerpf(-.18+.025*cos(float(index)*PI*.5),-.18+.025*cos(float(index+1)*PI*.5),section-float(index))

static func _haku(street: Node3D,gallery: Node3D) -> Dictionary:
	var group := _group(gallery,"ExteriorGalleryIdentity")
	var center := Vector3(-1.19,2.13,-.030)
	# Pier x[-1.40,-.98]: .36m plaque leaves .03m solid margin each side.
	# Native asset has actual boolean glyph pockets and dark ceramic recess floors.
	_box(street,group,"HakuPlaqueSpacers",center+Vector3(0,0,.022),Vector3(.26,.26,.016),"haku_reveal")
	var plaque := _group(group,"HakuCeramicPlaque")
	plaque.position = center
	var packed := load(BrandSigns.ASSET_ROOT+"haku_plaque.glb") as PackedScene
	var asset_loaded: bool = packed != null
	if asset_loaded:
		plaque.add_child(packed.instantiate())
	_box(street,group,"ExhibitionCardFrame",Vector3(-1.19,1.52,-.032),Vector3(.34,.46,.06),"arch_cedar")
	_box(street,group,"ExhibitionCardPaper",Vector3(-1.19,1.52,-.064),Vector3(.292,.405,.008),"haku_ceramic")
	_label(group,"ExhibitionTitle","MATERIAL\nSTUDIES",Vector3(-1.19,1.60,-.070),.033,Color("#34433B"))
	_label(group,"ExhibitionDetails","CLAY / GLAZE\nWORKING NOTES\nOPEN STUDIO",Vector3(-1.19,1.47,-.070),.017,Color("#34433B"))
	return {"id":"HakuCeramics","treatment":"small_thick_ceramic_entrance_plaque","main_center_m":center,"main_size_m":Vector3(.36,.44,.028),"plaque_size_m":Vector3(.36,.44,.028),"plaque_asset_loaded":asset_loaded,"materials":["haku_ceramic","haku_reveal"],"entry_clear_width_m":1.80,"blade_count":0,"menu_boards":0,"exhibition_card_retained":true,"original_large_sign_removed":true,"lettering_geometry":"boolean recessed Japanese glyphs and maker seal in ceramic asset"}
