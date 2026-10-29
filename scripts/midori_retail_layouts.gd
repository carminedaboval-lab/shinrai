extends RefCounted
## Original logical retail plans; shop-local metres, floorY=.11, front-Z.
const Details = preload("res://scripts/midori_south_street_details.gd")
const Interiors = preload("res://scripts/midori_shop_interiors.gd")

static func build(street: Node3D,shop: Node3D,root: Node3D) -> Dictionary:
	var books: bool=str(shop.name)=="UedaBooks"
	var sparse_stock: bool=str(shop.name)=="HinataDaily"
	var width: float=11.0 if books else 10.0
	var fixtures: Array[Dictionary]=[]
	var routes: Array[Rect2]=[Rect2(-.8,0,1.6,1.5)]
	for side: float in [-1.0,1.0]:
		var depth: float=.34 if books else .43
		var centre:=Vector3(side*(width*.5-.30-depth*.5-.02),.11,4.1)
		var label: String=("Books" if books else "Grocery")+("Left" if side<0 else "Right")+"WallShelves"
		var bounds:=Rect2(centre.x-depth*.5,1.7 if books else 2.0,depth,4.8 if books else 4.4)
		var bay:=_fixture(root,label,centre,bounds,"perimeter_stock",fixtures)
		bay.rotation.y=-PI*.5 if side<0 else PI*.5
		var span: float=4.8 if books else 4.4
		if books and side>0:
			# Right-rear checkout staff aisle needs uninterrupted access.
			span=2.7;bay.position.z=3.05;bounds.position.y=1.7;bounds.size.y=2.7
			bay.set_meta("fixture_bounds",bounds);fixtures[-1].bounds=bounds
		_shelves(street,bay,span,2.15,depth,books,0 if side<0 else 3,sparse_stock)
	if books:
		for index: int in range(2):
			var x: float=-2.0 if index==0 else .4
			var island:=_fixture(root,"LowBrowseIsland%d"%index,Vector3(x,.11,3.8),Rect2(x-.375,2.8,.75,2.0),"low_browse",fixtures)
			_island(street,island,.75,2.0,.85,true,index)
		routes.append(Rect2(-1.55,1.5,1.10,4.9));routes.append(Rect2(.85,1.5,1.50,5.0))
		var display:=_fixture(root,"FrontLeftNewReleases",Vector3(-2.6,.11,.95),Rect2(-3.3,.60,1.4,.70),"front_display",fixtures)
		_island(street,display,1.4,.70,.68,true,4)
		_checkout(street,root,Vector3(3.55,.11,5.6),Vector2(.65,1.6),fixtures)
		routes.append(Rect2(4.0,4.4,1.1,2.3))
	else:
		var gondola:=_fixture(root,"CentralDoubleSidedGrocery",Vector3(0,.11,3.95),Rect2(-.45,2.7,.9,2.5),"double_sided_stock",fixtures)
		for side: float in [-1.0,1.0]:
			var face:=Node3D.new();face.name="InwardFacingGrocerySide";face.position=Vector3(side*.225,0,0);face.rotation.y=PI*.5 if side<0 else -PI*.5;gondola.add_child(face)
			_shelves(street,face,2.5,1.20,.45,false,2,sparse_stock)
		var produce:=_fixture(root,"LowFrontProduce",Vector3(-2.5,.11,2.0),Rect2(-3.4,1.5,1.8,1.0),"produce",fixtures)
		_island(street,produce,1.8,1.0,.55,false,1)
		for x: float in [-.57,0,.57]:
			Details._crate(street,produce,Vector3(x,.5525,0),.50,int((x+.6)*5),sparse_stock)
		_checkout(street,root,Vector3(2.85,.11,2.75),Vector2(.70,1.70),fixtures)
		routes.append(Rect2(-1.65,2.7,1.2,3.5));routes.append(Rect2(.45,3.65,1.2,2.7));routes.append(Rect2(3.25,1.5,.95,5.2))
		var bagging:=_fixture(root,"RearCheckoutBagging",Vector3(2.85,.11,4.0),Rect2(2.50,3.65,.70,.70),"bagging",fixtures)
		Interiors._cabinet(street,bagging,Vector3(0,.41,0),Vector3(.70,.82,.70),false)
		Details._b(street,bagging,"SupportedBaggingTop",Vector3(0,.84,0),Vector3(.74,.04,.74),"detail_wood")
	# Rear support band has a human-sized stock door and stocked cabinets.
	var stockdoor:=Vector3(width*.5-1.05,.11,7.70)
	var rear:=_fixture(root,"RearStockCabinet",Vector3(-1.1,.11,7.20),Rect2(-3.6,6.85,5.0,.70),"stock_storage",fixtures)
	Interiors._cabinet(street,rear,Vector3(0,.47,0),Vector3(5,.94,.70),false)
	Details._b(street,rear,"RearStockWorktop",Vector3(0,.96,0),Vector3(5.04,.04,.74),"detail_wood")
	if books:
		var back:=_fixture(root,"BackBookWall",Vector3(-1.1,1.09,7.59),Rect2(-3.6,7.42,5,.34),"back_stock_books",fixtures)
		_shelves(street,back,5,1.20,.34,true,5)
	else:
		for i: int in range(7):
			if sparse_stock and i not in [1,5]: continue
			Details._jar(street,rear,Vector3(-2.0+float(i)*.6,1.00,0),i)
	var door:=_fixture(root,"StaffStockDoor",stockdoor,Rect2(stockdoor.x-.45,7.65,.90,.08),"staff_door",fixtures)
	Details._b(street,door,"StockDoorLeaf",Vector3(0,1.0,0),Vector3(.86,2,.035),"detail_darkwood")
	for side: float in [-1.0,1.0]:Details._b(street,door,"StockDoorJamb",Vector3(side*.46,1.04,-.025),Vector3(.055,2.08,.07),"detail_wood")
	Details._b(street,door,"StockDoorHead",Vector3(0,2.10,-.025),Vector3(.975,.06,.07),"detail_wood")
	Details._b(street,door,"StockDoorLever",Vector3(-.28,1,-.045),Vector3(.12,.018,.035),"detail_metal")
	routes.append(Rect2(1.6,6.46,width*.5-2.05,1.04))
	var report: Dictionary={"shop":str(shop.name),"fixtures":fixtures,"clear_routes":routes,"stockdoor_position":stockdoor,"floor_surface_y":.11,"storage_band":Rect2(-width*.5,6.8,width,1.0),"lights_added":0,"notes":"Perimeter stock faces inward. Low browse furniture keeps sightlines. Customer and staff checkout sides separated; original exterior untouched."}
	root.set_meta("retail_logical_layout",report)
	return report

static func _fixture(root: Node3D,label: String,p: Vector3,bounds: Rect2,role: String,fixtures: Array[Dictionary]) -> Node3D:
	var group:=Node3D.new();group.name=label;group.position=p;root.add_child(group)
	group.set_meta("fixture_bounds",bounds);group.set_meta("fixture_role",role)
	fixtures.append({"name":str(group.name),"node":str(group.get_path()),"bounds":bounds,"role":role});return group

static func _shelves(street: Node3D,parent: Node3D,width: float,height: float,depth: float,books: bool,seed_value: int,sparse_stock: bool = false) -> void:
	var levels: Array[float]=[.12,.62,1.12,1.62,2.08]
	if height<=1.5: levels.assign([.12,.48,.84,1.20])
	for side: float in [-1.0,1.0]:Details._b(street,parent,"ShelfSolidEnd",Vector3(side*(width*.5-.009),height*.5,0),Vector3(.018,height,depth),"detail_darkwood")
	Details._b(street,parent,"ShelfRecessedBacking",Vector3(0,height*.5,depth*.5-.006),Vector3(width-.036,height,.012),"detail_darkwood")
	var bays:=maxi(1,ceili(width/.95))
	for i: int in range(1,bays):Details._b(street,parent,"ShelfVerticalDivider",Vector3(-width*.5+width*i/bays,height*.5,0),Vector3(.018,height,depth),"detail_wood")
	for index: int in range(levels.size()):
		var y: float=levels[index]
		Details._b(street,parent,"SupportedShelfBoard",Vector3(0,y,0),Vector3(width,.025,depth),"detail_wood")
		Details._b(street,parent,"ShelfFrontLipping",Vector3(0,y-.009,-depth*.5),Vector3(width,.042,.018),"detail_darkwood")
		if index==levels.size()-1:continue
		for bay_index: int in range(bays):
			var x: float=-width*.5+(bay_index+.5)*width/bays
			if books:Details._book_row(street,parent,Vector3(x-width/bays*.38,y+.013,-.025),maxi(3,int(width/bays/.084)),seed_value+index+bay_index)
			else:
				for item: int in range(4):
					if sparse_stock and (seed_value+index*2+bay_index*3+item)%13 != 0: continue
					Details._jar(street,parent,Vector3(x+(item-1.5)*.17,y+.013,-.045),seed_value+index+bay_index)

static func _island(street: Node3D,parent: Node3D,width: float,depth: float,height: float,books: bool,seed_value: int) -> void:
	for x: float in [-width*.5+.06,width*.5-.06]:
		for z: float in [-depth*.5+.06,depth*.5-.06]:Details._b(street,parent,"DisplaySolidLeg",Vector3(x,height*.5,z),Vector3(.065,height,.065),"detail_darkwood")
	Details._b(street,parent,"DisplayLowerShelf",Vector3(0,.18,0),Vector3(width-.08,.035,depth-.08),"detail_wood")
	Details._b(street,parent,"DisplayRebatedTop",Vector3(0,height,0),Vector3(width,.035,depth),"detail_wood")
	if books:
		for z: float in [-depth*.28,depth*.28]:Details._book_stack(street,parent,Vector3(0,height+.018,z),seed_value+int(z*3))

static func _checkout(street: Node3D,root: Node3D,p: Vector3,size: Vector2,fixtures: Array[Dictionary]) -> void:
	var bounds:=Rect2(p.x-size.x*.5,p.z-size.y*.5,size.x,size.y)
	var counter:=_fixture(root,"CheckoutCustomerMinusXStaffPlusX",p,bounds,"checkout",fixtures)
	# Cabinet drawer/door fronts face staff+X; customer edge has a writing ledge.
	var cabinet:=Node3D.new();cabinet.rotation.y=-PI*.5;counter.add_child(cabinet)
	Interiors._cabinet(street,cabinet,Vector3(0,.45,0),Vector3(size.y,.90,size.x),true)
	Details._b(street,counter,"CheckoutSolidTop",Vector3(0,.925,0),Vector3(size.x+.06,.05,size.y+.06),"detail_wood")
	Details._b(street,counter,"TillMetalStand",Vector3(.08,1.0,-.30),Vector3(.14,.10,.12),"detail_metal")
	var terminal:=Details._b(street,counter,"CheckoutRegister",Vector3(.08,1.13,-.30),Vector3(.06,.20,.24),"detail_ink");terminal.rotation.z=.20
	Details._b(street,counter,"CustomerCounterWritingLedge",Vector3(-size.x*.5-.05,.92,.38),Vector3(.10,.04,.42),"detail_wood")
