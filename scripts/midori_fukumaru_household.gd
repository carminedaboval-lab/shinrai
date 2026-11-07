extends RefCounted
## Small household objects stay inside the existing cabinets and shelves. They
## share the apartment mesh batches and add neither collisions nor light nodes.
const CityKit := preload("res://scripts/midori_near_city_kit.gd")
const Joinery := preload("res://scripts/midori_fukumaru_geometry.gd")
const CREAM := Color("#e2dbc8")
const BLUE := Color("#526b7a")
const STEEL := Color("#c2c5bd")
const DARK := Color("#303936")

static func kitchen(h: Node3D, xf: Transform3D, unit: String, width: float) -> void:
	var sx := -width * .23
	_soap(h, xf.translated_local(Vector3(-width * .5 + .066, .833, -.164)), unit == "301")
	_towel(h, xf.translated_local(Vector3(-width * .375, .696, .282)))
	if unit == "201":
		cup(h, xf.translated_local(Vector3(.008, .833, .112)), BLUE)
		plant(h, xf.translated_local(Vector3(-.66, 1.51, -.103)))
	else:
		plant(h, xf.translated_local(Vector3(-.11, 1.615, -.103)))
		if unit == "301":
			_kettle(h, xf.translated_local(Vector3(width * .263, .854, -.015)))
			_cutting_board(h, xf.translated_local(Vector3(-.06,.833,-.205)))
			# This 15cm drying rack fits between the pressed sink and the hob.
			_rack(h, xf.translated_local(Vector3(.028, .833, .018)))
		else:
			_utensils(h, xf.translated_local(Vector3(width * .5 - .071, .833, -.165)))

static func cup(h: Node3D, xf: Transform3D, tint: Color) -> void:
	var kit: CityKit = h._kit
	# The open profile has a real lip and inside wall rather than a capped cone.
	Joinery.lathe(kit,"apartment_ceramic", xf, [Vector2(.028,0),Vector2(.032,.002), Vector2(.036,.006),
			Vector2(.042,.020),Vector2(.044,.047),Vector2(.045,.075), Vector2(.044,.083),Vector2(.042,.087),
			Vector2(.039,.086),Vector2(.038,.082), Vector2(.036,.023), Vector2(.025,.014)], CREAM, 24)
	kit.disc("apartment_ceramic", xf * Vector3(0,.014,0), xf.basis.x, -xf.basis.z, .026, CREAM.darkened(.14))
	var handle: Array[Vector3] = []
	for i: int in range(9):
		var a := -PI * .5 + PI * float(i) / 8.0
		handle.append(xf * Vector3(.039 + .031 * cos(a), .048 + .027 * sin(a), .0))
	kit.tube("apartment_ceramic", handle, .0065, CREAM, 10)
	# A few uneven cobalt leaf strokes follow the ceramic surface. No labels.
	for i: int in range(5):
		var angle := -.52 + float(i) * .245
		var y := .025 + float(i % 2) * .015
		var length := .026 - float(i % 3) * .003
		var a := Vector3(sin(angle-.055)*.0457,y,cos(angle-.055)*.0457)
		var b := Vector3(sin(angle+.014)*.0459,y+length,cos(angle+.014)*.0459)
		var c := Vector3(sin(angle+.075)*.0457,y+length*.62,cos(angle+.075)*.0457)
		var d := Vector3(sin(angle+.018)*.0457,y+.003,cos(angle+.018)*.0457)
		var n := xf.basis * Vector3(sin(angle),.01,cos(angle)).normalized()
		kit.smooth("apartment_ceramic",xf*a,xf*b,xf*c,xf*d,n,n,n,n,tint)

static func plant(h: Node3D, xf: Transform3D) -> void:
	var kit: CityKit = h._kit
	Joinery.lathe(kit,"apartment_ceramic", xf, [Vector2(.040,0),Vector2(.043,.004),Vector2(.048,.015),
			Vector2(.060,.093),Vector2(.064,.106),Vector2(.065,.117),Vector2(.064,.123),
			Vector2(.058,.126),Vector2(.054,.118),Vector2(.053,.108)], CREAM, 24)
	kit.disc("plain", xf * Vector3(0,.111,0), xf.basis.x, -xf.basis.z, .054, Color("#473f2c"))
	# Small asymmetrical pothos spray and two natural trailing stems.
	for i: int in range(6):
		var angle := float(i) * 2.39996
		var reach := .044 + .016 * float(i % 3)
		var tip := Vector3(cos(angle)*reach,.195 + .025*sin(angle),sin(angle)*reach)
		var branch: Array[Vector3] = [xf*Vector3(0,.115,0),xf*Vector3(tip.x*.42,.17,tip.z*.42),xf*tip]
		kit.tube("leaf",branch,.0022,Color("#617047"),4)
		_leaf(kit,xf,tip,.062,.049,angle*.42,Color("#697a47"))
	for trail: int in range(2):
		var path: Array[Vector3] = []
		var direction := -1.0 if trail == 0 else 1.0
		for i: int in range(7):
			var t := float(i) / 6.0
			var p := Vector3(direction*(.026+.025*sin(t*4.2)),.14-t*(.43-.07*trail),.028+.075*sin(t*2.2))
			path.append(xf*p)
			if i > 0:
				var side := -1.0 if i % 2 == 0 else 1.0
				var attach := p + Vector3(.018*side,.006,.005)
				_leaf(kit,xf,attach,.062-.003*i,.045,side*.46,Color("#667a44").darkened(.025*i))
		kit.tube("leaf",path,.0024,Color("#5b6942"),4)

static func _leaf_point(u: float, v: float, length: float, width: float) -> Vector3:
	var across := u*2.0-1.0
	var span := pow(maxf(.0,sin(PI*pow(clampf(v,0,1),.78))),.72)
	var x := across*width*.53*span
	var y := -v*length+.045*length*sin(u*PI)*sin(v*TAU)
	# Pothos leaves cup slightly along the midrib; a deep dome made the
	# first shaded pass look like rounded pods instead of thin foliage.
	var z := length*(.035*sin(PI*v)+.035*(1.0-across*across)*sin(PI*v)-.06*pow(v,3.0))
	return Vector3(x,y,z)

static func _leaf(kit: CityKit, xf: Transform3D, at: Vector3, length: float, width: float, lean: float, tint: Color) -> void:
	var turn := Basis(Vector3.BACK,lean).rotated(Vector3.UP,sin(lean*3.0)*.4).rotated(Vector3.RIGHT,.18)
	var frame := xf * Transform3D(turn,at)
	const COLS := 4
	const ROWS := 7
	for row: int in range(ROWS):
		for col: int in range(COLS):
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			var uv: Array[Vector2] = []
			for index: Vector2i in [Vector2i(col,row),Vector2i(col,row+1),Vector2i(col+1,row+1),Vector2i(col+1,row)]:
				var u := float(index.x)/COLS
				var v := float(index.y)/ROWS
				var du := _leaf_point(u+.002,v,length,width)-_leaf_point(u-.002,v,length,width)
				var dv := _leaf_point(u,minf(v+.002,.999),length,width)-_leaf_point(u,maxf(v-.002,.001),length,width)
				var normal := dv.cross(du).normalized()
				if normal.length_squared() < .01: normal = Vector3(0,0,1)
				points.append(frame*_leaf_point(u,v,length,width))
				normals.append(frame.basis*normal)
				uv.append(Vector2(u,v))
			kit.mapped("apartment_foliage",points,normals,uv,[0.0,0.0,0.0,0.0],tint)

static func _soap(h: Node3D, xf: Transform3D, amber: bool) -> void:
	var kit: CityKit = h._kit
	var tint := Color("#7b6547") if amber else Color("#899b7b")
	kit.lathe("apartment_ceramic",xf.origin,[Vector2(.022,0),Vector2(.028,.008),
		Vector2(.028,.104),Vector2(.023,.118),Vector2(.013,.126),Vector2(.013,.137)],tint,10)
	kit.lathe("apartment_steel",xf*Vector3(0,.135,0),[Vector2(.014,0),Vector2(.014,.009),Vector2(.005,.010),Vector2(.005,.029)],DARK,8)
	kit.tube("apartment_steel",[xf*Vector3(0,.164,-.005),xf*Vector3(0,.164,.026),xf*Vector3(0,.153,.030)],.006,DARK,5)
	kit.block("plain",xf.translated_local(Vector3(0,.067,.0284)),Vector3(.032,.047,.0015),CREAM.darkened(.08))

static func _towel_point(u: float, v: float) -> Vector3:
	var x := (u-.5)*.23 + .007*sin(v*5.0)
	var y := -.355*v + .003*cos(u*8.0)*v
	var z := .007 + .010*sin(u*TAU*2.35+.3*v)*(0.25+.75*v) + .014*exp(-v*21.0)
	return Vector3(x,y,z)

static func _towel(h: Node3D, xf: Transform3D) -> void:
	var kit: CityKit = h._kit
	const COLS := 8
	const ROWS := 9
	for row: int in range(ROWS):
		for col: int in range(COLS):
			var uv: Array[Vector2] = [Vector2(float(col)/COLS,float(row)/ROWS),
				Vector2(float(col)/COLS,float(row+1)/ROWS),
				Vector2(float(col+1)/COLS,float(row+1)/ROWS),Vector2(float(col+1)/COLS,float(row)/ROWS)]
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			var prints: Array[Vector2] = []
			for coord: Vector2 in uv:
				var p := _towel_point(coord.x,coord.y)
				var dx := _towel_point(coord.x+.002,coord.y)-p
				var dy := _towel_point(coord.x,coord.y+.002)-p
				points.append(xf*p)
				normals.append((xf.basis*(dy.cross(dx))).normalized())
				prints.append(Vector2(coord.x*.23,coord.y*.355))
			kit.mapped("apartment_fabric",points,normals,prints,[0.0,0.0,0.0,0.0],CREAM)

static func _kettle(h: Node3D, xf: Transform3D) -> void:
	var kit: CityKit = h._kit
	Joinery.lathe(kit,"apartment_steel",xf,[Vector2(.072,0),Vector2(.083,.005),Vector2(.090,.014),
		Vector2(.094,.037),Vector2(.092,.065),Vector2(.085,.095),Vector2(.076,.121),
		Vector2(.063,.140),Vector2(.047,.149),Vector2(.042,.151)],Color("#b4ad91"),24)
	Joinery.lathe(kit,"apartment_steel",xf.translated_local(Vector3(0,.148,0)),[Vector2(.042,0),
		Vector2(.046,.004),Vector2(.046,.008),Vector2(.035,.012),Vector2(.020,.015),Vector2(.007,.016)],STEEL,24)
	kit.lathe("plain",xf*Vector3(0,.162,0),[Vector2(.008,0),Vector2(.013,.012),Vector2(.010,.020),Vector2(.001,.021)],DARK,8)
	var handle: Array[Vector3] = []
	for i: int in range(9):
		var angle := PI * float(i) / 8.0
		handle.append(xf*Vector3(.076*cos(angle),.126+.104*sin(angle),0))
	kit.tube("plain",handle,.011,DARK,6)
	var spout: Array[Vector3] = [xf*Vector3(0,.064,.071),xf*Vector3(0,.098,.102),xf*Vector3(0,.147,.138)]
	kit.tube("apartment_steel",spout,.016,STEEL,8)
	kit.disc("plain",xf*Vector3(0,.149,.139),xf.basis.x,(xf.basis*Vector3(0,.6,-.8)).normalized(),.011,DARK)

static func _cutting_board(h: Node3D, xf: Transform3D) -> void:
	var kit: CityKit = h._kit
	var frame := xf * Transform3D(Basis(Vector3.RIGHT,-.06),Vector3.ZERO)
	Joinery.bevel(kit,"apartment_wood",frame.translated_local(Vector3(0,.12,0)),Vector3(.125,.24,.014),.006,Color("#c5a77b"))
	Joinery.bevel(kit,"apartment_wood",frame.translated_local(Vector3(0,.259,0)),Vector3(.043,.051,.014),.006,Color("#c5a77b"))

static func _rack(h: Node3D, xf: Transform3D) -> void:
	var kit: CityKit = h._kit
	kit.block("apartment_steel",xf.translated_local(Vector3(0,.005,0)),Vector3(.148,.010,.218),STEEL.darkened(.14))
	for x: float in [-.067,.067]:
		kit.tube("apartment_steel",[xf*Vector3(x,.016,-.10),xf*Vector3(x,.071,-.10),xf*Vector3(x,.071,.10),xf*Vector3(x,.016,.10)],.003,STEEL,5)
	for i: int in range(3):
		var x := -.041 + .041*i
		kit.tube("apartment_steel",[xf*Vector3(x,.018,-.1),xf*Vector3(x,.047,-.087),xf*Vector3(x,.047,.087),xf*Vector3(x,.018,.1)],.0027,STEEL,5)
		# Plates stand nearly vertical; a real bevel gives the white rim a highlight.
		var centre := xf*Vector3(x,.096,0)
		var normal := xf.basis.x
		var up := xf.basis.y
		var right := xf.basis.z
		kit.disc("apartment_ceramic",centre+normal*.002,right,up,.078,CREAM)
		kit.disc("apartment_ceramic",centre-normal*.002,-right,up,.078,CREAM.darkened(.07))
		var rim: Array[Vector3] = []
		for j: int in range(17):
			var angle := TAU * float(j) / 16.0
			rim.append(centre+(right*cos(angle)+up*sin(angle))*.077)
		kit.tube("apartment_ceramic",rim,.0035,CREAM,4)

static func _utensils(h: Node3D, xf: Transform3D) -> void:
	var kit: CityKit = h._kit
	kit.lathe("apartment_ceramic",xf.origin,[Vector2(.035,0),Vector2(.041,.008),
		Vector2(.043,.113),Vector2(.039,.119),Vector2(.036,.109)],CREAM,10)
	for i: int in range(3):
		var x := -.023+.023*i
		var top := Vector3(x*1.5,.246+.017*i,.006*(i-1))
		kit.tube("apartment_wood",[xf*Vector3(x*.55,.055,0),xf*top],.006,Color("#b59a6b"),5)
		if i == 0:
			var a := xf*(top+Vector3(-.020,.004,0))
			var b := xf*(top+Vector3(-.017,.058,.004))
			var c := xf*(top+Vector3(.017,.058,.004))
			var d := xf*(top+Vector3(.020,.004,0))
			var n := xf.basis.z
			kit.smooth("apartment_wood",a,b,c,d,n,n,n,n,Color("#b59a6b"))
			kit.smooth("apartment_wood",d,c,b,a,-n,-n,-n,-n,Color("#9f835b"))

static func pencil_pot(h: Node3D, xf: Transform3D) -> void:
	var kit: CityKit = h._kit
	kit.lathe("apartment_ceramic",xf.origin,[Vector2(.028,0),Vector2(.033,.007),
		Vector2(.035,.086),Vector2(.031,.090),Vector2(.028,.079)],CREAM,10)
	for i: int in range(4):
		var a := float(i)*2.3
		var base := Vector3(cos(a)*.014,.009,sin(a)*.014)
		var tip := Vector3(cos(a)*.024,.150+.012*(i%2),sin(a)*.024)
		kit.tube("apartment_wood",[xf*base,xf*tip],.0028,Color("#bc9b6b"),4)
