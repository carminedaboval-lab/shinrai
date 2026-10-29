extends RefCounted
## Three authored exterior details per property. Metres, existing material palette.
## Decorative assemblies are wall/soffit supported, outside all entrance aprons.
const HOMES := [
	"SouthNeighbourhoodBuildings/KobayashiHouse",
	"SouthNeighbourhoodBuildings/SugiCourtyardHouse",
	"SouthNeighbourhoodBuildings/AokiHouse",
	"ConnectedNeighbourhoodContext/WestCornerWorkshopResidence",
	"ConnectedNeighbourhoodContext/EastGardenResidence",
	"SouthCourtBuildings/NishiTownhouse",
	"SouthCourtBuildings/HigashiPorchHome",
	"SouthCourtBuildings/KadoMakerWorkroom"
]

static func build(street: Node3D) -> Dictionary:
	var report := {"properties":[],"missing":[],"detail_count":0,"new_lights":0,"new_colliders":0,"animated_nodes":0}
	for path: String in HOMES:
		var house := street.get_node_or_null(path) as Node3D
		if house == null:
			report.missing.append(path)
			continue
		if house.has_node("HouseholdDetails"):
			report.properties.append(house.get_meta("household_details"))
			report.detail_count += int(house.get_meta("household_details").count)
			continue
		var root := Node3D.new()
		root.name = "HouseholdDetails"
		root.set_meta("creator_protected",true)
		root.set_meta("creator_editable",false)
		house.add_child(root)
		match String(house.name):
			"KobayashiHouse":
				_identity(street,_detail(root,"CeramicFamilyPlate","Cream ceramic family plate",Vector3(-3.28,1.80,0)),"KOBAYASHI","arch_linen",.48)
				_umbrellas(street,_detail(root,"ShelteredUmbrellaRack","Two used umbrellas on a drained wall rack",Vector3(-.99,0,0)))
				_pots(street,_detail(root,"SideHerbShelf","Small kitchen herbs on a bracketed side shelf",Vector3(3.6,0,1.55),-PI*.5),false)
			"SugiCourtyardHouse":
				_identity(street,_detail(root,"CedarFamilyPlate","Slim cedar Sugi nameplate",Vector3(1.24,1.81,0)),"SUGI","arch_cedar",.38)
				_shade(street,_detail(root,"WovenWindowShade","Partly rolled reed shade with two ties",Vector3(-1.30,0,0)))
				_chime(street,_detail(root,"PorchWindBell","Small ceramic wind bell beneath the porch canopy",Vector3(2.85,2.437,-.25)))
			"AokiHouse":
				_identity(street,_detail(root,"TimberFamilyPlate","Pale timber Aoki nameplate",Vector3(-3.28,1.80,0)),"AOKI","arch_pale_wood",.40)
				_pots(street,_detail(root,"KitchenPots","Two unequal glazed herb pots beside the window",Vector3(2.95,0,0)),true)
				_drying(street,_detail(root,"SideDryingRail","Sage and linen cloths pegged on a side rail",Vector3(3.6,0,1.55),-PI*.5),false)
			"WestCornerWorkshopResidence":
				_cabinet(street,_detail(root,"RepairReturnBox","Kado repair return cabinet below the existing studio plaque",Vector3(2.92,.90,-.12)),"REPAIRS",false)
				_tools(street,_detail(root,"SideHandTools","Hand tools on a sheltered maker's rail",Vector3(3.6,0,1.55),-PI*.5),false)
				_timber(street,_detail(root,"OffcutRack","Short reusable timber offcuts in a rear wall rack",Vector3(0,0,9),PI))
			"EastGardenResidence":
				_cabinet(street,_detail(root,"SeedExchange","Small seed-sharing cabinet with paper packets",Vector3(2.92,1.15,0)),"SEEDS",true)
				_hose(street,_detail(root,"SideHoseReel","Coiled irrigation hose, tap and parked spray nozzle",Vector3(3.6,0,1.55),-PI*.5))
				_tools(street,_detail(root,"GardenToolRail","Trowel and hand fork tidied beside the rear garden",Vector3(0,0,9),PI),true)
			"NishiTownhouse":
				_identity(street,_detail(root,"NumberedNishiPlate","Number 06 and Nishi on a stone plaque",Vector3(-1.38,1.65,-4.5)),"06  NISHI","arch_stone",.45)
				_cabinet(street,_detail(root,"NeighbourBookBox","Weather-hooded take-a-book box beneath the porch",Vector3(-2.55,.48,-4.5)),"BOOKS",true)
				_pots(street,_detail(root,"SideCeramicPots","Mismatched pots on the quieter side wall",Vector3(4,0,-2.7),-PI*.5),true)
			"HigashiPorchHome":
				_identity(street,_detail(root,"NumberedHigashiPlate","Number 07 on a narrow modern metal plate",Vector3(-1.47,1.58,-4)),"07\nHIGASHI","arch_metal",.30)
				_cabinet(street,_detail(root,"ParcelBox","Private parcel box beside the recessed porch",Vector3(2.55,.52,-4)),"DELIVERY",false)
				_drying(street,_detail(root,"RearLaundry","Household towels on a folding rear drying rail",Vector3(-1.30,0,4),PI),true)
			"KadoMakerWorkroom":
				_identity(street,_detail(root,"WorkshopHours","Enamel repair-hours plaque beside the maker door",Vector3(-1.26,1.63,-4.5)),"KADO\n09 - 18","arch_linen",.45)
				_timber(street,_detail(root,"MaterialSamples","Labelled timber samples in a side storage rack",Vector3(4.5,0,-2.7),-PI*.5))
				_tools(street,_detail(root,"BenchToolRail","A measuring square, mallet and clamp on the other side",Vector3(-4.5,0,-2.7),PI*.5),false)
		var details: Array[Dictionary] = []
		for detail: Node3D in root.get_children():
			var bounds := _bounds(detail,house)
			details.append({"id":String(detail.name),"description":detail.get_meta("description"),"local_bounds":bounds,"world_bounds":house.global_transform*bounds})
		var data := {"house":String(house.name),"details":details,"count":details.size(),"new_colliders":0,"new_lights":0,"source":"Original small assemblies using installed street materials"}
		house.set_meta("household_details",data)
		report.properties.append(data)
		report.detail_count += details.size()
	street.set_meta("household_details",report)
	return report

static func _detail(root: Node3D, id: String, description: String, at: Vector3, yaw: float=0) -> Node3D:
	var node := Node3D.new()
	node.name=id
	node.position=at
	node.rotation.y=yaw
	node.set_meta("description",description)
	root.add_child(node)
	return node

static func _box(s: Node3D,r: Node3D,id: String,p: Vector3,size: Vector3,key: String) -> MeshInstance3D:
	return s.call("_box",r,id,p,size,key,false) as MeshInstance3D

static func _mesh(s: Node3D,r: Node3D,id: String,p: Vector3,mesh: Mesh,key: String) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name=id
	n.mesh=mesh
	n.position=p
	var materials: Dictionary=s.get("materials")
	n.material_override=materials[key]
	r.add_child(n)
	return n

static func _rod(s: Node3D,r: Node3D,id: String,a: Vector3,b: Vector3,radius: float,key: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=a.distance_to(b)
	mesh.radial_segments=12
	mesh.rings=1
	var n := _mesh(s,r,id,(a+b)*.5,mesh,key)
	n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	return n

static func _ring(s: Node3D,r: Node3D,id: String,p: Vector3,radius: float,thickness: float,key: String) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius=radius-thickness
	mesh.outer_radius=radius+thickness
	mesh.rings=24
	mesh.ring_segments=8
	var n := _mesh(s,r,id,p,mesh,key)
	n.rotation.x=PI*.5
	return n

static func _label(s: Node3D,r: Node3D,words: String,p: Vector3,size: float,color: Color=Color("#e5dfd1")) -> void:
	s.call("_text",r,"Lettering",words,p,size,color)

static func _identity(s: Node3D,r: Node3D,words: String,key: String,width: float) -> void:
	var height := .24 if words.contains("\n") else .16
	_box(s,r,"Backing",Vector3(0,0,-.014),Vector3(width+.02,height+.02,.030),"arch_metal")
	_box(s,r,"NameSurface",Vector3(0,0,-.032),Vector3(width,height,.020),key)
	for x: float in [-width*.43,width*.43]:
		_box(s,r,"CaptiveScrew",Vector3(x,0,-.044),Vector3(.012,.012,.008),"arch_metal")
	_label(s,r,words,Vector3(0,0,-.047),.047 if width>.4 else .042,Color("#292f2c") if key in ["arch_linen","arch_stone","arch_pale_wood"] else Color("#e4dac5"))

static func _brackets(s: Node3D,r: Node3D,width: float,y: float,depth: float) -> void:
	for x: float in [-width*.36,width*.36]:
		_box(s,r,"WallFixing",Vector3(x,y-.10,-.014),Vector3(.055,.24,.032),"arch_metal")
		_box(s,r,"ShelfArm",Vector3(x,y-.025,-depth*.5),Vector3(.035,.04,depth),"arch_metal")
		_rod(s,r,"TriangularBrace",Vector3(x,y-.20,-.03),Vector3(x,y-.025,-depth+.04),.009,"arch_metal")

static func _umbrellas(s: Node3D,r: Node3D) -> void:
	_brackets(s,r,.36,.48,.24)
	_box(s,r,"DrainTray",Vector3(0,.48,-.145),Vector3(.38,.045,.27),"arch_metal")
	for x: float in [-.16,.16]:
		_box(s,r,"RackUpright",Vector3(x,.65,-.24),Vector3(.02,.34,.02),"arch_metal")
	_box(s,r,"Retainer",Vector3(0,.80,-.24),Vector3(.34,.025,.02),"arch_metal")
	for i: int in range(2):
		var x := -.085+float(i)*.16
		var top := 1.12+float(i)*.06
		_rod(s,r,"UmbrellaShaft",Vector3(x,.495,-.14),Vector3(x,top,-.14),.009,"arch_metal")
		var cloth := CylinderMesh.new()
		cloth.bottom_radius=.018
		cloth.top_radius=.045
		cloth.height=.44
		cloth.radial_segments=10
		cloth.rings=1
		_mesh(s,r,"FoldedUmbrella",Vector3(x,.75,-.14),cloth,"arch_sage" if i==0 else "arch_linen")
		_box(s,r,"UmbrellaTie",Vector3(x,.85,-.185),Vector3(.07,.022,.012),"arch_metal")
		for j: int in range(7):
			var a := float(j)*PI/7
			var b := float(j+1)*PI/7
			_rod(s,r,"CurvedHandle",Vector3(x+.035+.035*cos(a),top+.035*sin(a),-.14),Vector3(x+.035+.035*cos(b),top+.035*sin(b),-.14),.010,"arch_pale_wood")

static func _pots(s: Node3D,r: Node3D,glazed: bool) -> void:
	_brackets(s,r,.88,.54,.27)
	_box(s,r,"PlantShelf",Vector3(0,.54,-.15),Vector3(.88,.035,.30),"arch_cedar")
	for i: int in range(2):
		var x := -.23+float(i)*.45
		var h := .19+float(i)*.035
		var pot := CylinderMesh.new()
		pot.top_radius=.112
		pot.bottom_radius=.078
		pot.height=h
		pot.radial_segments=20
		pot.rings=1
		_mesh(s,r,"CeramicPot",Vector3(x,.56+h*.5,-.15),pot,"arch_sage" if glazed and i==0 else "arch_stone")
		var rim := _ring(s,r,"PotRim",Vector3(x,.56+h,-.15),.108,.012,"arch_sage" if glazed and i==0 else "arch_stone")
		rim.rotation=Vector3.ZERO
		_rod(s,r,"PotSoil",Vector3(x,.56+h-.012,-.15),Vector3(x,.56+h-.006,-.15),.095,"arch_shadow")
		for stem: int in range(3):
			var dx := float(stem-1)*.045
			var bottom := Vector3(x+dx,.56+h,-.15)
			var top := bottom+Vector3(dx,.16+float(stem%2)*.08,0)
			_rod(s,r,"HerbStem",bottom,top,.003,"arch_sage")
			for leaf: int in range(4):
				var side := -1.0 if leaf%2==0 else 1.0
				var leaf_mesh := SphereMesh.new()
				leaf_mesh.radius=.045
				leaf_mesh.height=.09
				leaf_mesh.radial_segments=8
				leaf_mesh.rings=4
				var n := _mesh(s,r,"HerbLeaf",bottom.lerp(top,.30+float(leaf)*.16)+Vector3(side*.028,.008,0),leaf_mesh,"arch_sage")
				n.scale=Vector3(1,.20,.5)
				n.rotation.z=side*.35

static func _shade(s: Node3D,r: Node3D) -> void:
	for x: float in [-.86,.86]:
		_box(s,r,"ShadeWallBracket",Vector3(x,2.53,-.08),Vector3(.055,.12,.18),"arch_metal")
	_rod(s,r,"RolledReedShade",Vector3(-.97,2.54,-.17),Vector3(.97,2.54,-.17),.065,"arch_pale_wood")
	for i: int in range(20):
		var yy := 2.47-float(i)*.016
		_rod(s,r,"IndividualReed",Vector3(-.96,yy,-.17),Vector3(.96,yy,-.17),.006,"arch_pale_wood" if i%3 else "arch_cedar")
	for x: float in [-.76,.76]:
		_box(s,r,"ShadeBinding",Vector3(x,2.31,-.182),Vector3(.012,.34,.008),"arch_linen")
		_rod(s,r,"TiedCord",Vector3(x,2.58,-.19),Vector3(x,2.05,-.19),.003,"arch_linen")

static func _chime(s: Node3D,r: Node3D) -> void:
	r.scale=Vector3.ONE*.70 # Keep the hanging paper above 2.10m head clearance.
	_box(s,r,"SoffitFixing",Vector3(0,-.008,0),Vector3(.045,.018,.045),"arch_metal")
	_rod(s,r,"HangingCord",Vector3(0,-.01,0),Vector3(0,-.18,0),.003,"arch_linen")
	var bell := SphereMesh.new()
	bell.radius=.055
	bell.height=.11
	bell.radial_segments=16
	bell.rings=8
	_mesh(s,r,"CeramicBell",Vector3(0,-.22,0),bell,"arch_sage")
	var lip := _ring(s,r,"BellLip",Vector3(0,-.255,0),.042,.005,"arch_linen")
	lip.rotation=Vector3.ZERO
	_rod(s,r,"ClapperString",Vector3(0,-.25,0),Vector3(0,-.35,0),.002,"arch_linen")
	var card := _box(s,r,"PaperWindStrip",Vector3(0,-.405,0),Vector3(.045,.12,.003),"arch_linen")
	card.rotation.z=.12
	_box(s,r,"InkMark",Vector3(0,-.4,-.003),Vector3(.009,.04,.002),"arch_sage")

static func _drying(s: Node3D,r: Node3D,wide: bool) -> void:
	var width := 1.28 if wide else .9
	_brackets(s,r,width,1.62,.28)
	_rod(s,r,"DryingRail",Vector3(-width*.5,1.62,-.26),Vector3(width*.5,1.62,-.26),.012,"arch_metal")
	for i: int in range(2):
		var x := -width*.24+float(i)*width*.48
		var drop := .45+float(i)*.11
		# Separate narrow facets give the hanging cloth a soft hem without simulation.
		for fold: int in range(9):
			_box(s,r,"ClothFold",Vector3(x+float(fold-4)*.032,1.62-drop*.5,-.275-float(fold%2)*.009),Vector3(.034,drop,.009),"arch_linen" if i else "arch_sage")
		for edge: float in [-.09,.09]:
			_box(s,r,"WoodenPeg",Vector3(x+edge,1.63,-.28),Vector3(.014,.052,.018),"arch_pale_wood")
		_box(s,r,"WovenHem",Vector3(x,1.64-drop,-.285),Vector3(.29,.017,.012),"arch_cedar" if i else "arch_linen")

static func _cabinet(s: Node3D,r: Node3D,title: String,open: bool) -> void:
	var wood := "arch_cedar" if open else "arch_metal"
	_box(s,r,"CabinetBack",Vector3(0,0,-.025),Vector3(.60,.46,.055),wood)
	for side: float in [-1.0,1.0]:
		_box(s,r,"CabinetSide",Vector3(side*.29,0,-.14),Vector3(.035,.46,.25),wood)
	for y: float in [-.22,.22]:
		_box(s,r,"CabinetShelf",Vector3(0,y,-.14),Vector3(.60,.035,.25),wood)
	var hood := _box(s,r,"SlopedWeatherHood",Vector3(0,.26,-.15),Vector3(.68,.035,.34),"arch_metal")
	hood.rotation.x=-.10
	_box(s,r,"CabinetNameStrip",Vector3(0,.16,-.275),Vector3(.50,.075,.018),"arch_linen")
	_label(s,r,title,Vector3(0,.16,-.286),.042,Color("#303d34"))
	if open:
		for i: int in range(5):
			var p := _box(s,r,"SharedBook" if title=="BOOKS" else "SeedPacket",Vector3(-.20+float(i)*.095,-.075,-.13),Vector3(.07,.24 if title=="BOOKS" else .17,.13 if title=="BOOKS" else .025),"arch_linen" if i%2 else "arch_sage")
			p.rotation.z=.055*float(i%3-1)
		_box(s,r,"RetainingLip",Vector3(0,-.17,-.265),Vector3(.55,.07,.025),wood)
	else:
		_box(s,r,"ClosedDoor",Vector3(0,-.035,-.268),Vector3(.53,.32,.025),"arch_sage")
		_box(s,r,"PullHandle",Vector3(.19,-.02,-.297),Vector3(.025,.11,.032),"arch_metal")
		_box(s,r,"LockEscutcheon",Vector3(.19,-.115,-.286),Vector3(.025,.025,.012),"arch_linen")
	for x: float in [-.23,.23]:
		_box(s,r,"CabinetMount",Vector3(x,0,.006),Vector3(.055,.36,.02),"arch_metal")

static func _tools(s: Node3D,r: Node3D,garden: bool) -> void:
	_box(s,r,"ToolBoard",Vector3(0,1.46,-.025),Vector3(.74,.13,.055),"arch_cedar")
	for i: int in range(3):
		var x := -.24+float(i)*.24
		_rod(s,r,"ToolHook",Vector3(x,1.46,-.04),Vector3(x,1.46,-.105),.007,"arch_metal")
		_ring(s,r,"ToolHangingLoop",Vector3(x,1.435,-.11),.024,.004,"arch_linen")
		_rod(s,r,"TimberHandle",Vector3(x,1.10,-.11),Vector3(x,1.43,-.11),.017,"arch_pale_wood")
		if garden and i==0:
			var blade := SphereMesh.new()
			blade.radius=.058
			blade.height=.19
			blade.radial_segments=12
			blade.rings=6
			var n := _mesh(s,r,"TrowelBlade",Vector3(x,1.04,-.11),blade,"arch_metal")
			n.scale.z=.17
		elif garden:
			_box(s,r,"ForkShoulder",Vector3(x,1.09,-.11),Vector3(.09,.025,.02),"arch_metal")
			for tooth: int in range(3):
				_rod(s,r,"ForkTine",Vector3(x+float(tooth-1)*.035,1.09,-.11),Vector3(x+float(tooth-1)*.035,1.0,-.14),.005,"arch_metal")
		elif i==0:
			_box(s,r,"MalletHead",Vector3(x,1.10,-.11),Vector3(.17,.07,.075),"arch_pale_wood")
		elif i==1:
			_box(s,r,"SquareBlade",Vector3(x+.07,1.10,-.11),Vector3(.18,.025,.013),"arch_metal")
		else:
			_box(s,r,"ClampFrame",Vector3(x+.05,1.2,-.11),Vector3(.025,.22,.025),"arch_metal")
			for y: float in [1.1,1.3]: _box(s,r,"ClampJaw",Vector3(x+.02,y,-.11),Vector3(.085,.025,.025),"arch_metal")
	_box(s,r,"ToolRainHood",Vector3(0,1.61,-.105),Vector3(.82,.035,.24),"arch_metal")

static func _timber(s: Node3D,r: Node3D) -> void:
	_brackets(s,r,1.05,.44,.25)
	_box(s,r,"OffcutShelf",Vector3(0,.44,-.14),Vector3(1.05,.04,.28),"arch_metal")
	for i: int in range(6):
		var h := .42+float((i*3)%5)*.11
		var n := _box(s,r,"ReclaimedOffcut",Vector3(-.38+float(i)*.15,.47+h*.5,-.12),Vector3(.11,h,.09),"arch_pale_wood" if i%2 else "arch_cedar")
		n.rotation.z=float(i%3-1)*.035
		_box(s,r,"InventoryChalkMark",Vector3(-.38+float(i)*.15,.63,-.169),Vector3(.035,.007,.002),"arch_linen")
	for x: float in [-.51,.51]: _box(s,r,"RackEnd",Vector3(x,.61,-.24),Vector3(.03,.34,.03),"arch_metal")
	_box(s,r,"RackRetainer",Vector3(0,.75,-.24),Vector3(1.05,.025,.025),"arch_metal")

static func _hose(s: Node3D,r: Node3D) -> void:
	_box(s,r,"ReelMount",Vector3(0,1.28,-.025),Vector3(.17,.24,.055),"arch_metal")
	_rod(s,r,"ReelAxle",Vector3(0,1.28,-.03),Vector3(0,1.28,-.24),.024,"arch_metal")
	for i: int in range(4): _ring(s,r,"HoseCoil",Vector3(0,1.28,-.11-float(i)*.027),.175,.012,"arch_sage")
	for end: float in [-1.0,1.0]: _rod(s,r,"ReelSpoke",Vector3(0,1.28,-.24),Vector3(end*.19,1.28,-.24),.010,"arch_metal")
	_rod(s,r,"HoseTail",Vector3(.17,1.28,-.19),Vector3(.23,.88,-.19),.011,"arch_sage")
	_rod(s,r,"ParkedNozzle",Vector3(.23,.88,-.19),Vector3(.23,1.02,-.19),.023,"arch_metal")
	_box(s,r,"NozzleWallClip",Vector3(.23,.93,-.10),Vector3(.07,.07,.22),"arch_metal")
	_rod(s,r,"FeedHose",Vector3(-.17,1.28,-.14),Vector3(-.31,.88,-.10),.011,"arch_sage")
	_rod(s,r,"GardenTap",Vector3(-.31,.88,0),Vector3(-.31,.88,-.11),.019,"arch_metal")
	_box(s,r,"TapHandle",Vector3(-.31,.92,-.07),Vector3(.10,.018,.027),"arch_metal")

static func _bounds(root: Node3D,relative_to: Node3D) -> AABB:
	var bounds := AABB()
	var started := false
	for n: Node in root.find_children("*","MeshInstance3D",true,false):
		var mesh := n as MeshInstance3D
		var b: AABB = relative_to.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		bounds=b if not started else bounds.merge(b)
		started=true
	return bounds
