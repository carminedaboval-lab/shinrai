extends RefCounted
## Small supported working arrangements on existing fixtures, before batching.
## Existing shared geometry/material helpers only; no floor furniture or lights.
const Details = preload("res://scripts/midori_south_street_details.gd")

static func build(street: Node3D, gallery: Dictionary = {}) -> Dictionary:
	var rows: Array[Dictionary] = []
	for id: String in ["MoriCoffee","UedaBooks","HinataDaily"]:
		var shop := street.get_node_or_null(NodePath(id)) as Node3D
		if shop == null: continue
		var room := shop.get_node_or_null("InteriorConstructedShop") as Node3D
		if room == null: continue
		match id:
			"MoriCoffee": rows.append(_cafe(street,room))
			"UedaBooks": rows.append(_books(street,room))
			"HinataDaily": rows.append(_grocery(street,room))
	if not gallery.is_empty(): rows.append(_gallery(street,gallery))
	return {"ok":rows.size()==4,"shops":rows,"floor_fixture_footprints_added":0,"collision_added":0,"lights_added":0,"original_asset_resources_modified":false,"source_provenance":"Original arrangements and identity cards; reused existing Details cups/jars/book geometry and original project shared materials","validation_boundary":"source support and clearance contract; parent owns actual renderer, gameplay and installed acceptance"}

static func _group(parent: Node3D,label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.set_meta("creator_protected",true)
	node.set_meta("creator_editable",false)
	parent.add_child(node)
	return node

static func _part(street: Node3D,parent: Node3D,label: String,pos: Vector3,size: Vector3,key: String) -> MeshInstance3D:
	return street.call("_box",parent,label,pos,size,key,false) as MeshInstance3D

static func _card(street: Node3D,parent: Node3D,label: String,pos: Vector3,width: float,height: float,words: String,yaw: float = 0.0) -> Node3D:
	var card := _group(parent,label)
	card.position = pos
	card.rotation.y = yaw
	# Foot is on the actual supporting surface; upright is held in its slot.
	_part(street,card,"IdentityCardTimberFoot",Vector3(0,.012,0),Vector3(width+.025,.024,.075),"detail_wood")
	_part(street,card,"IdentityCardPaper",Vector3(0,.024+height*.5,0),Vector3(width,height,.008),"detail_paper")
	Details._print(card,"IdentityPrintedCard",words,Vector3(0,.024+height*.5,-.005),height*.12,Color("#35443b"))
	return card

static func _adopt(group: Node3D, fixture: Node3D) -> void:
	# New group was authored in the fixture parent's coordinates. Adopt into the
	# existing fixture so native rendered-bound checks include every new object.
	if fixture == null: return
	var authored := group.transform
	group.reparent(fixture,false)
	group.transform = fixture.transform.affine_inverse()*authored

static func _cafe(street: Node3D,room: Node3D) -> Dictionary:
	var pickup := _group(room,"InteriorMoriPickupArrangement")
	_part(street,pickup,"PickupServingTray",Vector3(2.47,1.019,6.10),Vector3(.55,.018,.40),"detail_darkwood")
	Details._cup(street,pickup,Vector3(2.30,1.028,6.09))
	Details._cup(street,pickup,Vector3(2.55,1.028,6.14))
	# A restrained pickup tag is wholly inside the counter and behind the cups.
	_card(street,pickup,"MoriPickupCard",Vector3(2.66,1.028,6.00),.16,.105,"MORI\nPICKUP",PI*.5)
	_adopt(pickup,room.get_node_or_null("MoriServiceCounter") as Node3D)
	var order := _group(room,"InteriorMoriOrderCard")
	_card(street,order,"MoriSeasonalCoffee",Vector3(2.43,1.01,4.10),.235,.17,"MORI COFFEE\nHOUSE BLEND\nPOUR OVER  480",PI*.5)
	_adopt(order,room.get_node_or_null("MoriServiceCounter") as Node3D)
	var condiments := _group(room,"InteriorMoriCondimentTray")
	_part(street,condiments,"CondimentTray",Vector3(4.42,1.02,6.11),Vector3(.32,.02,.36),"detail_darkwood")
	Details._jar(street,condiments,Vector3(4.42,1.03,6.025),1)
	Details._jar(street,condiments,Vector3(4.42,1.03,6.195),2)
	_adopt(condiments,room.get_node_or_null("MoriBackbar") as Node3D)
	var report := {"shop":"MoriCoffee","support_surfaces":[{"fixture":"MoriServiceCounter","top_y":1.01,"used_rectangles":[Rect2(2.195,5.90,.55,.40),Rect2(2.30,3.98,.26,.24)]},{"fixture":"MoriBackbar","top_y":1.01,"used_rectangles":[Rect2(4.26,5.93,.32,.36)]}],"cups_added":2,"condiment_jars_added":2,"espresso_position_retained":Vector3(2.5,1.01,4.8),"staff_aisle_width_m":1.10,"floor_route_changes":0,"lights_created":0}
	room.set_meta("shop_identity_arrangement",report)
	return report

static func _books(street: Node3D,room: Node3D) -> Dictionary:
	var table := room.get_node_or_null("FrontLeftNewReleases") as Node3D
	if table == null: return {"shop":"UedaBooks","ok":false,"missing":"FrontLeftNewReleases"}
	var display := _group(table,"InteriorUedaSelectedRelease")
	# Existing tabletop is localY .6975; both cradle and standing volume bear on it.
	_part(street,display,"FeaturedBookCradleFoot",Vector3(.45,.710,0),Vector3(.30,.025,.27),"detail_darkwood")
	_part(street,display,"FeaturedBookHeel",Vector3(.45,.735,-.085),Vector3(.29,.025,.025),"detail_wood")
	var back := _part(street,display,"FeaturedBookBackSupport",Vector3(.45,.835,.07),Vector3(.27,.24,.025),"detail_wood")
	back.rotation.x = -.15
	Details._face_book(street,display,Vector3(.45,.868,0),.255,.29,5)
	_card(street,display,"UedaStaffSelection",Vector3(-.48,.6975,0),.30,.16,"UEDA BOOKS\nLOCAL STORIES\nSTAFF SELECTION")
	# Label front edge of an existing low island, anchored into its timber lip.
	var island := room.get_node_or_null("LowBrowseIsland0") as Node3D
	if island != null:
		var label := _group(island,"InteriorUedaBrowseLabel")
		_part(street,label,"BrowseLabelBacking",Vector3(0,.79,-.993),Vector3(.42,.11,.012),"detail_paper")
		Details._print(label,"BrowsePrintedCategory","CITY / LANDSCAPE",Vector3(0,.79,-1.0),.018,Color("#35443b"))
	var report := {"shop":"UedaBooks","fixture":"FrontLeftNewReleases","fixture_local_support_y":.6975,"table_world_local_surface_y":.8075,"featured_book_count":1,"original_table_stacks_retained":true,"selected_footprints":[Rect2(.30,-.135,.30,.27),Rect2(-.6425,-.04,.325,.08)],"main_customer_routes_retained":true,"fixture_footprints_added":0,"lights_created":0}
	room.set_meta("shop_identity_arrangement",report)
	return report

static func _grocery(street: Node3D,room: Node3D) -> Dictionary:
	var produce := room.get_node_or_null("LowFrontProduce") as Node3D
	if produce == null: return {"shop":"HinataDaily","ok":false,"missing":"LowFrontProduce"}
	var notice := _group(produce,"InteriorHinataAbandonedStockNotice")
	# One temporary notice replaces the three old price labels, on the same lip.
	_part(street,notice,"NoticeClip",Vector3(0,.52,-.493),Vector3(.045,.075,.024),"detail_metal")
	_part(street,notice,"AbandonedStockNotice",Vector3(0,.54,-.493),Vector3(1.02,.14,.012),"detail_paper")
	Details._print(notice,"PrintedStockWarning","SPOILED PRODUCE / DO NOT EAT",Vector3(0,.54,-.500),.017,Color("#53472f"))
	var bagging := room.get_node_or_null("RearCheckoutBagging") as Node3D
	if bagging != null:
		var bags := _group(bagging,"InteriorHinataBaggingSupplies")
		for i: int in range(3):
			Details._soft_block(street,bags,"FoldedPaperGroceryBag",Vector3(-.13+float(i)*.012,.867+float(i)*.014,.08),Vector3(.27,.014,.31),"detail_paper")
		_card(street,bags,"HinataSealedSupplyNotice",Vector3(.17,.86,-.19),.21,.14,"NO RESTOCK\nSEALED TINS\nDELIVERY CASE")
	var report := {"shop":"HinataDaily","existing_produce_crates_retained":3,"price_labels":0,"emergency_notices":2,"decorative_remnants_not_food":true,"bagging_support_fixture":"RearCheckoutBagging","bagging_local_support_y":.86,"bagging_used_rectangles":[Rect2(-.265,-.075,.295,.31),Rect2(.0525,-.2275,.235,.075)],"folded_bags_added":3,"stock_aisles_retained":true,"fixture_footprints_added":0,"lights_created":0}
	room.set_meta("shop_identity_arrangement",report)
	return report

static func _gallery(street: Node3D,gallery: Dictionary) -> Dictionary:
	var fixtures := gallery.get("fixtures_group") as Node3D
	if fixtures == null: return {"shop":"HakuCeramics","ok":false,"missing":"fixtures_group"}
	var root := _group(fixtures,"InteriorHakuCurationArrangement")
	# Real rear-bench topY .915. Existing vase is atX2.8, padX1.73..2.13,
	# drying boardsX3.52..3.88: new groups occupy the deliberate gaps between.
	_part(street,root,"GlazeTestTray",Vector3(3.24,.924,8.65),Vector3(.38,.018,.36),"arch_cedar")
	for i: int in range(3):
		_part(street,root,"StonewareGlazeTestTile",Vector3(3.12+float(i)*.12,.941,8.65),Vector3(.105,.016,.23),["detail_sage","detail_cream","detail_amber"][i])
	_part(street,root,"CuratorialNotebookPages",Vector3(2.30,.932,8.72),Vector3(.28,.025,.31),"detail_paper")
	_part(street,root,"CuratorialNotebookCover",Vector3(2.30,.9175,8.72),Vector3(.29,.005,.32),"detail_darkwood")
	Details._rod(street,root,"BenchGraphitePencil",Vector3(2.225,.9475,8.62),Vector3(2.35,.9475,8.79),.003,"detail_ink")
	# Label on the hero plinth's own top front margin; clear of the vase atZ3.65.
	_card(street,root,"HakuHeroInterpretation",Vector3(-2.70,.80,3.32),.23,.085,"HAKU / STONEWARE\nVESSEL STUDY  03")
	# Wall captions are fixed into backing, below the existing framed image.
	_part(street,root,"StreetStudyCaptionBacking",Vector3(-2.9,.975,9.47),Vector3(.72,.14,.018),"arch_linen")
	Details._print(root,"StreetStudyCaption","STREET STUDY\nMIDORI / ORIGINAL PRINT",Vector3(-2.9,.975,9.458),.019,Color("#35443b"))
	_part(street,root,"GlazeStudyWallNotice",Vector3(2.65,1.48,9.47),Vector3(1.05,.32,.018),"arch_linen")
	Details._print(root,"GlazeStudyWallText","HAKU / MATERIAL STUDIES\nTHREE GLAZES, ONE CLAY\nWORKING NOTES / AUTUMN",Vector3(2.65,1.48,9.458),.026,Color("#35443b"))
	var report := {"shop":"HakuCeramics","rear_workbench_support_y":.915,"rear_workbench_used_rectangles":[Rect2(3.05,8.47,.38,.36),Rect2(2.155,8.56,.29,.32)],"glaze_samples":3,"notebook":1,"existing_vase_count_unchanged":5,"existing_artwork_count_unchanged":1,"gallery_clear_aisle_m":2.2,"floor_fixtures_added":0,"collisions_added":0,"lights_created":0,"light_targets_local":[Vector3(-2.7,1.00,3.65),Vector3(-2.9,1.70,9.44),Vector3(3.24,.96,8.65)]}
	fixtures.set_meta("shop_identity_arrangement",report)
	return report

