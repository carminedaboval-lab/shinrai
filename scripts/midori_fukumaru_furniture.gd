extends RefCounted
## Furniture assembled in the building's mesh batches, before its kit commits.
## An object's local +Z is its front. Positions are measured from its floor.

const CityKit := preload("res://scripts/midori_near_city_kit.gd")
const Soft := preload("res://scripts/midori_fukumaru_soft_furnishings.gd")
const Household := preload("res://scripts/midori_fukumaru_household.gd")
const Joinery := preload("res://scripts/midori_fukumaru_geometry.gd")
const OAK := Color("#ead1a3")
const WALNUT := Color("#ad8a6e")
const LINEN := Color("#ede5d3")
const PORCELAIN := Color("#ece9dc")
const CHROME := Color("#c4c9c7")
const CHARCOAL := Color("#454a48")

static func setup_materials(house: Node3D) -> void:
	Soft.materials(house)

static func furnish(house: Node3D) -> void:
	setup_materials(house)

	# 201: shikibuton over a pair of rush mats; a chabudai with one cushion.
	var low := 3.3
	_bath(house, "201", Vector2(-1.73, -3.99), Vector2(-.46, -2.15), Vector2(-3.36, -2.46), low)
	_kitchen(house, "201", _at(.92, low, -.408, 180), 1.53, Color("#d1cbbd"))
	_bed(house, "201", _at(-1.18, low, -1.14, 180), .94, 1.9, Color("#627b8e"), true)
	_table(house, "201", _at(-.38, low, -.83), .50, .44, .30, OAK)
	_pad(house, _at(-.35, low + .015, -1.32, -7), .40, .40, .064, Color("#c6bba4"))
	_cup(house, _at(-.46, low + .30, -.77), Color("#758e89"))
	_cupboard(house, "201_ShoeChest", _at(-.025, low, -3.78), .72, .38, .77, OAK)

	# 202: bed on a raised drawer base, a reading desk and enamel galley.
	_bath(house, "202", Vector2(-1.73, -6.09), Vector2(-.26, -4.07), Vector2(-5.45, -4.53), low)
	_kitchen(house, "202", _at(1.48, low, -6.88, -90), 1.56, Color("#d8d6ce"))
	_bed(house, "202", _at(-1.12, low, -7.91), 1.00, 2.00, Color("#d2cbbb"), false)
	_table(house, "202", _at(1.41, low, -8.32, -90), 1.14, .53, .72, WALNUT)
	_chair(house, "202", _at(.87, low, -8.22, 91), WALNUT, Color("#5e7272"))
	_books(house, _at(1.47, low + .72, -8.59, -84))
	_task_lamp(house, _at(1.52, low + .72, -7.96), Color("#737d76"))
	Household.pencil_pot(house, _at(1.57, low + .72, -8.17))
	_cupboard(house, "202_Wardrobe", _at(-1.43, low, -6.41, 90), .53, .56, 1.78, WALNUT)

	# 301: the wet core and kitchen share the rear wall run. The dining aisle
	# continues into the front bedroom. The existing balcony glazing is closed.
	var top := 6.15
	_bath(house, "301", Vector2(-1.73, -9.06), Vector2(-.09, -7.06), Vector2(-8.45, -7.51), top)
	_kitchen(house, "301", _at(-1.47, top, -6.18, 90), 1.60, Color("#d5cebe"))
	_settee(house, _at(-1.31, top, -4.64, 90))
	_table(house, "301", _at(1.33, top, -5.79, -90), 1.13, .65, .72, OAK)
	_chair(house, "301", _at(.77, top, -5.83, 88), OAK, Color("#c4bca9"))
	_cup(house, _at(1.22, top + .72, -5.59), Color("#999d8a"))
	_books(house, _at(1.39, top + .72, -6.09, -87))
	_bed(house, "301", _at(-.92, top, -2.53), 1.38, 2.02, Color("#849081"), false)
	_cupboard(house, "301_Wardrobe", _at(1.43, top, -1.87, -90), 1.22, .55, 1.99, OAK)
	_cupboard(house, "301_Bedside", _at(.09, top, -3.33), .43, .39, .42, WALNUT)
	_task_lamp(house, _at(.10, top + .42, -3.33), Color("#7c695d"))

static func _at(x: float, y: float, z: float, degrees := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(degrees)), Vector3(x, y, z))

static func _box(h: Node3D, part: String, xf: Transform3D, p: Vector3, size: Vector3, tint: Color, label := "") -> void:
	var smallest := minf(size.x,minf(size.y,size.z))
	if part in ["apartment_wood","apartment_enamel","apartment_steel","apartment_ceramic"] and smallest > .017:
		var kit: CityKit = h._kit
		Joinery.bevel(kit,part,xf.translated_local(p),size,minf(.008,smallest*.19),tint)
	else:
		h._bar(part, xf, p.x, p.y, p.z, size, tint, .84, 1.0)
	if not label.is_empty():
		_blocking(h, label, xf, p, size)

static func _blocking(h: Node3D, label: String, xf: Transform3D, p: Vector3, size: Vector3) -> void:
	# Furniture footprints are axis-aligned in house space. The occasional
	# chair twist gets a slightly smaller solid inside its visible seat.
	var span := xf.basis.x.abs() * size.x + xf.basis.y.abs() * size.y + xf.basis.z.abs() * size.z
	h.apartment_furniture_box(label, xf * p, span)

## The geometry carries the folds, so bedding still reads correctly from
## a doorway and catches the real room lights. All cloth shares one batch.
static func _pad(h: Node3D, xf: Transform3D, wide: float, deep: float, tall: float, color: Color, part := "apartment_fabric") -> void:
	Soft.pad(h, xf, wide, deep, tall, color, .003,12,16,part)

static func _bed(h: Node3D, unit: String, xf: Transform3D, width: float, depth: float, quilt: Color, futon: bool) -> void:
	var height := .047 if futon else .34
	if futon:
		for side: float in [-1.0, 1.0]:
			var x := side * width * .255
			_box(h,"plain",xf,Vector3(x,.018,0),Vector3(width * .51,.036,depth + .035),Color("#baa982"))
			_box(h,"plain",xf,Vector3(x + side * width * .246,.037,0),Vector3(.019,.009,depth + .035),Color("#646a55"))
	else:
		_box(h,"apartment_wood",xf,Vector3(0,.18,0),Vector3(width-.025,.30,depth-.025),WALNUT)
		# Proper side posts and inset timber headboard, with rounded bedding
		# sitting in front of it rather than intersecting it.
		for side: float in [-1.0, 1.0]:
			_box(h,"apartment_wood",xf,Vector3(side*(width*.5-.035),.45,-depth*.47),Vector3(.055,.76,.055),WALNUT)
		_box(h,"apartment_wood",xf,Vector3(0,.72,-depth*.47),Vector3(width,.07,.052),OAK)
		_box(h,"apartment_wood",xf,Vector3(0,.54,-depth*.47),Vector3(width-.11,.30,.029),WALNUT)
		for side: float in [-1.0, 1.0]:
			_box(h,"apartment_wood",xf,Vector3(width*.5,.19,side*depth*.235),Vector3(.025,.20,depth*.44),OAK)
			_box(h,"metal",xf,Vector3(width*.5+.017,.235,side*depth*.235),Vector3(.015,.018,.12),CHARCOAL)
	_blocking(h,"Bed_"+unit,xf,Vector3(0,(height+.11)*.5,0),Vector3(width,height+.11,depth))
	Soft.pad(h,xf.translated_local(Vector3(0,height,0)),width,depth,.105,LINEN,.002,10,16)
	Soft.pad(h,xf.translated_local(Vector3(-.008,height+.088,depth*.10)),width*1.01,depth*.75,.075,quilt,.025,22,32)
	Soft.pad(h,xf.translated_local(Vector3(0,height+.135,-depth*.235)),width*.94,.18,.027,quilt.lightened(.05),.008,16,6)
	if unit == "202":
		# A folded blue-grey cover lies across the foot of the neutral duvet.
		Soft.pad(h,xf.translated_local(Vector3(-.01,height+.164,depth*.25)),width*.97,.49,.028,Color("#74878d"),.010,16,10)
	var pillows := 2 if width > 1.2 else 1
	for i: int in range(pillows):
		var x := (float(i) - (pillows - 1) * .5) * width * .47
		var pillow := xf.translated_local(Vector3(x,height+.099,-depth*.34))
		Soft.pad(h,pillow,.56 if pillows == 1 else .51,.34,.129,LINEN.lightened(.03),.009,14,10)

static func _cupboard(h: Node3D, name: String, xf: Transform3D, width: float, depth: float, height: float, tint: Color) -> void:
	_box(h,"apartment_wood",xf,Vector3(0,height*.5,0),Vector3(width,height,depth),tint,name)
	for side: float in [-1.0,1.0]:
		_box(h,"apartment_wood",xf,Vector3(side*width*.245,height*.51,depth*.5+.009),Vector3(width*.475,height*.91,.022),tint.lightened(.045))
		_box(h,"metal",xf,Vector3(side*.041,height*.52,depth*.5+.032),Vector3(.014,.105,.017),CHARCOAL)

static func _table(h: Node3D, unit: String, xf: Transform3D, width: float, depth: float, height: float, tint: Color) -> void:
	_box(h,"apartment_wood",xf,Vector3(0,height-.024,0),Vector3(width,.048,depth),tint)
	# Recessed apron rails support the overhanging top and meet the legs.
	# They are inside the already-blocked table footprint, not aisle clutter.
	var apron := minf(.075,height*.23)
	for side: float in [-1.0,1.0]:
		_box(h,"apartment_wood",xf,Vector3(0,height-.055-apron*.5,side*(depth*.5-.068)),Vector3(width-.13,apron,.027),tint.darkened(.08))
		_box(h,"apartment_wood",xf,Vector3(side*(width*.5-.065),height-.055-apron*.5,0),Vector3(.027,apron,depth-.13),tint.darkened(.08))
	for side: float in [-1.0,1.0]:
		for end: float in [-1.0,1.0]:
			_box(h,"apartment_wood",xf,Vector3(side*(width*.5-.063),height*.48,end*(depth*.5-.06)),Vector3(.044,height*.96,.044),tint)
	_blocking(h,"Table_"+unit,xf,Vector3(0,height*.5,0),Vector3(width-.025,height,depth-.025))

static func _chair(h: Node3D, unit: String, xf: Transform3D, tint: Color, cushion: Color) -> void:
	for side: float in [-1.0,1.0]:
		for end: float in [-1.0,1.0]:
			var height := .72 if end < 0 else .42
			_box(h,"apartment_wood",xf,Vector3(side*.153,height*.5,end*.145),Vector3(.031,height,.033),tint)
	_box(h,"apartment_wood",xf,Vector3(0,.408,0),Vector3(.39,.04,.36),tint)
	_box(h,"apartment_wood",xf,Vector3(0,.665,-.15),Vector3(.36,.105,.032),tint)
	# Side stretchers and the rail below the back tie the four legs together.
	for side: float in [-1.0,1.0]:
		_box(h,"apartment_wood",xf,Vector3(side*.153,.18,0),Vector3(.023,.025,.29),tint.darkened(.06))
		_box(h,"apartment_wood",xf,Vector3(side*.153,.375,0),Vector3(.026,.057,.29),tint)
	_box(h,"apartment_wood",xf,Vector3(0,.21,-.145),Vector3(.31,.025,.023),tint)
	_pad(h,xf.translated_local(Vector3(0,.429,0)),.365,.325,.044,cushion,"apartment_upholstery")
	_blocking(h,"Chair_"+unit,xf,Vector3(0,.22,0),Vector3(.35,.44,.31))

static func _settee(h: Node3D, xf: Transform3D) -> void:
	var fabric := Color("#8f8b80")
	_box(h,"apartment_wood",xf,Vector3(0,.16,0),Vector3(1.45,.19,.64),WALNUT,"Sofa_301")
	_box(h,"apartment_wood",xf,Vector3(0,.50,-.267),Vector3(1.40,.55,.09),WALNUT)
	for side: float in [-1.0,1.0]:
		_pad(h,xf.translated_local(Vector3(side*.335,.25,.025)),.655,.55,.14,fabric,"apartment_upholstery")
		var back := xf * Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3(side*.335,.55,-.225))
		Soft.pad(h,back,.655,.49,.102,fabric,.004,14,12,"apartment_upholstery")
		_box(h,"apartment_wood",xf,Vector3(side*.707,.42,0),Vector3(.052,.075,.65),OAK)
		_box(h,"apartment_wood",xf,Vector3(side*.707,.30,.25),Vector3(.043,.26,.045),WALNUT)
	var pillow := xf * Transform3D(Basis(Vector3.RIGHT,PI*.43).rotated(Vector3.FORWARD,.12),Vector3(.40,.53,-.06))
	Soft.pad(h,pillow,.32,.33,.105,Color("#c6bba4"),.006,12,12)
	Soft.throw_on_sofa(h,xf)

static func _books(h: Node3D, xf: Transform3D) -> void:
	var tints := [Color("#6b7a81"), Color("#a98769"), Color("#5d7062")]
	for i: int in range(3):
		var pose := xf * _at(.01*i,.027*i,0, -4.0+3.0*i)
		_box(h,"plain",pose,Vector3(0,.011,0),Vector3(.151,.021,.21),LINEN)
		_box(h,"plain",pose,Vector3(-.003,.024,0),Vector3(.16,.008,.219),tints[i])
		_box(h,"plain",pose,Vector3(-.079,.013,0),Vector3(.007,.026,.217),tints[i])

static func _cup(h: Node3D, xf: Transform3D, tint: Color) -> void:
	Household.cup(h,xf,tint)

static func _task_lamp(h: Node3D, xf: Transform3D, tint: Color) -> void:
	var kit: CityKit = h._kit
	kit.lathe("metal",xf.origin,[Vector2(.087,0),Vector2(.091,.012),Vector2(.043,.027),Vector2(.012,.032)],tint,12)
	kit.tube("metal",[xf*Vector3(0,.03,0),xf*Vector3(0,.26,0),xf*Vector3(.062,.31,.039)],.009,CHARCOAL,6)
	kit.lathe("plain",xf*Vector3(.068,.19,.041),[Vector2(.085,0),Vector2(.047,.085),Vector2(.012,.10)],tint,14)
	kit.disc("lamp",xf*Vector3(.068,.19,.041),Vector3.RIGHT,Vector3.BACK,.08,LINEN)

## A spun or moulded bowl with a lip and visible hollow. The low exponent
## suits the rounded rectangular unit bath and the stainless pressed sink.
static func _well(h: Node3D, part: String, xf: Transform3D, width: float, depth: float, height: float, exponent: float, tint: Color, narrow_base := .90) -> void:
	var kit: CityKit = h._kit
	const SIDES := 20
	var radii := [narrow_base, .98, 1.0, .82, .64]
	var levels := [0.0, .69, .97, 1.0, .24]
	var rings: Array = []
	var normals: Array = []
	for j: int in range(radii.size()):
		var ring := PackedVector3Array()
		var ring_n := PackedVector3Array()
		for i: int in range(SIDES):
			var theta := TAU * i / SIDES
			var x := signf(cos(theta)) * pow(absf(cos(theta)), exponent)
			var z := signf(sin(theta)) * pow(absf(sin(theta)), exponent)
			ring.append(xf * Vector3(x*width*.5*radii[j],height*levels[j],z*depth*.5*radii[j]))
			# Ellipse gradient corrected for depth and the flattened sides.
			var nx := signf(x) * pow(absf(x), 2.0/exponent-1.0) / width
			var nz := signf(z) * pow(absf(z), 2.0/exponent-1.0) / depth
			var n := (xf.basis * Vector3(nx,0,nz)).normalized()
			if j < 2: ring_n.append(n)
			elif j == 2: ring_n.append((n + Vector3.UP * 1.7).normalized())
			elif j == 3: ring_n.append((-n + Vector3.UP * 2.2).normalized())
			else: ring_n.append((-n + Vector3.UP * .65).normalized())
		rings.append(ring)
		normals.append(ring_n)
	for i: int in range(SIDES):
		var next := (i+1) % SIDES
		for j: int in range(rings.size()-1):
			kit.smooth(part,rings[j][i],rings[j+1][i],rings[j+1][next],rings[j][next],normals[j][i],normals[j+1][i],normals[j+1][next],normals[j][next],tint)
		var mid := xf * Vector3(0,height*levels[-1],0)
		kit.smooth(part,rings[-1][i],rings[-1][next],mid,mid,Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP,tint.darkened(.16))

static func _spout(h: Node3D, xf: Transform3D, height: float, reach: float) -> void:
	var kit: CityKit = h._kit
	var body_h := minf(height*.36,.062)
	Joinery.lathe(kit,"apartment_steel",xf,[Vector2(.024,0),Vector2(.025,.004),Vector2(.021,.011),Vector2(.018,body_h*.82),Vector2(.016,body_h)],CHROME,18)
	var curve: Array[Vector3] = []
	var a := Vector3(0,body_h*.8,0)
	var b := Vector3(0,height*1.32,0)
	var c := Vector3(0,height*1.32,reach)
	var d := Vector3(0,height*.73,reach)
	for step: int in range(19):
		var t := float(step)/18.0
		var q := 1.0-t
		curve.append(xf*(a*q*q*q+b*3.0*q*q*t+c*3.0*q*t*t+d*t*t*t))
	kit.tube("apartment_steel",curve,minf(.011,height*.11),CHROME,10)
	var end := xf.translated_local(d)
	Joinery.lathe(kit,"apartment_steel",end,[Vector2(.013,-.010),Vector2(.015,-.008),Vector2(.015,.006),Vector2(.013,.009)],CHROME,16)
	kit.disc("plain",end*Vector3(0,-.010,0),xf.basis.x,xf.basis.z,.010,Color("#555e5e"))
	_box(h,"apartment_steel",xf,Vector3(.025,body_h+.006,.013),Vector3(.058,.012,.031),CHROME)

static func _kitchen(h: Node3D, unit: String, xf: Transform3D, width: float, paint: Color) -> void:
	var kit: CityKit = h._kit
	var sx := -width*.23
	# Keep the original full collision block, but build a hollow carcass.
	# A solid visual cuboid previously filled the lower half of the sink.
	_blocking(h,"Kitchen_"+unit,xf,Vector3(0,.395,0),Vector3(width-.025,.72,.48))
	for side: float in [-1.0,1.0]:
		_box(h,"apartment_enamel",xf,Vector3(side*(width*.5-.0215),.414,0),Vector3(.018,.758,.48),paint)
	_box(h,"apartment_enamel",xf,Vector3(0,.414,-.231),Vector3(width-.025,.758,.018),paint.darkened(.12))
	# A real top rail supports the worktop and closes the former 22 mm black
	# slot above the doors. It sits in front of, and clear of, the sink bowl.
	_box(h,"apartment_enamel",xf,Vector3(0,.771,.226),Vector3(width-.025,.046,.024),paint)
	_box(h,"apartment_enamel",xf,Vector3(0,.055,0),Vector3(width-.025,.025,.48),paint.darkened(.12))
	_box(h,"plain",xf,Vector3(0,.047,.01),Vector3(width-.08,.09,.41),CHARCOAL)
	_box(h,"apartment_steel",xf,Vector3(0,.86,-.234),Vector3(width,.10,.035),CHROME)
	# Four edges of a worktop surround the actual recessed stainless sink.
	var cut := .435
	for side: float in [-1.0,1.0]:
		h._bar("apartment_steel",xf,sx,.81,side*.205,Vector3(cut,.036,.097),CHROME)
	var left := -width*.5
	var right := width*.5
	var lo := sx-cut*.5
	var hi := sx+cut*.5
	# Coplanar top patches join with no bevel seam. Only the outer pressed
	# return is rolled; treating each patch as a separate box made false joins.
	h._bar("apartment_steel",xf,(left+lo)*.5,.81,0,Vector3(lo-left,.036,.505),CHROME)
	h._bar("apartment_steel",xf,(right+hi)*.5,.81,0,Vector3(right-hi,.036,.505),CHROME)
	kit.tube("apartment_steel",[xf*Vector3(left,.822,.249),xf*Vector3(right,.822,.249)],.006,CHROME,10)
	Joinery.sink(kit,xf.translated_local(Vector3(sx,.833,0)),CHROME)
	_spout(h,xf.translated_local(Vector3(sx+.10,.833,-.173)),.191,.154)
	# A compact under-counter refrigerator shares the run with the sink doors.
	var split := .095
	var fridge_w := width*.5-split-.04
	var fridge_x := split + fridge_w*.5
	_box(h,"apartment_enamel",xf,Vector3(fridge_x,.459,.250),Vector3(fridge_w,.65,.040),PORCELAIN)
	_box(h,"metal",xf,Vector3(fridge_x,.626,.276),Vector3(fridge_w-.022,.014,.014),CHARCOAL)
	_box(h,"metal",xf,Vector3(fridge_x+.13,.576,.279),Vector3(.15,.022,.020),CHROME)
	var door_width := (width*.5+split)*.5
	for i: int in range(2):
		var cx := left + (.5+i)*door_width
		_box(h,"apartment_enamel",xf,Vector3(cx,.44,.245),Vector3(door_width-.012,.66,.028),paint)
		# Bracketed handles stand clear of the door face like real bent steel.
		kit.tube("apartment_steel",[xf*Vector3(cx-.055,.692,.261),xf*Vector3(cx-.055,.692,.290),xf*Vector3(cx+.055,.692,.290),xf*Vector3(cx+.055,.692,.261)],.006,CHROME,6)
	var hob_x := width*.263
	_box(h,"apartment_ceramic",xf,Vector3(hob_x,.841,0),Vector3(.456,.021,.377),Color("#282d2d"))
	kit.disc("apartment_ceramic",xf*Vector3(hob_x-.033,.853,-.021),xf.basis.x,-xf.basis.z,.127,Color("#666d6d"))
	kit.disc("apartment_ceramic",xf*Vector3(hob_x-.033,.854,-.021),xf.basis.x,-xf.basis.z,.124,Color("#282d2d"))
	for i: int in range(2):
		kit.disc("metal",xf*Vector3(hob_x+.110+i*.045,.854,.124),xf.basis.x,-xf.basis.z,.013,CHROME)
	# The 201 run sits under the street sash. Put its shelf against the short
	# solid return east of the sash, leaving the window and daylight clear.
	if unit == "201":
		_box(h,"apartment_wood",xf,Vector3(-.52,1.49,-.112),Vector3(.45,.035,.23),OAK)
		_shelf_brackets(h,xf,-.52,1.472,.45)
		_cup(h,xf.translated_local(Vector3(-.43,1.509,-.112)),Color("#788a88"))
		Household.kitchen(h,xf,unit,width)
		return
	_box(h,"apartment_enamel",xf,Vector3(0,1.22,-.237),Vector3(width,.67,.027),Color("#e0ded2"))
	_box(h,"apartment_wood",xf,Vector3(-width*.235,1.59,-.118),Vector3(width*.495,.048,.25),OAK)
	_shelf_brackets(h,xf,-width*.235,1.565,width*.495)
	for i: int in range(3):
		var at: Vector3 = xf*Vector3(-width*.33,1.615+.023*i,-.112)
		kit.lathe("apartment_ceramic",at,[Vector2(.057,0),Vector2(.087,.029),Vector2(.080,.035),Vector2(.062,.023)],PORCELAIN,16)
	_box(h,"apartment_steel",xf,Vector3(hob_x,1.83,-.093),Vector3(.525,.10,.33),CHROME)
	_box(h,"plain",xf,Vector3(hob_x,1.783,-.10),Vector3(.355,.009,.214),CHARCOAL)
	_box(h,"apartment_steel",xf,Vector3(hob_x,2.00,-.187),Vector3(.31,.26,.108),CHROME)
	Household.kitchen(h,xf,unit,width)

static func _shelf_brackets(h: Node3D, xf: Transform3D, middle: float, height: float, width: float) -> void:
	var kit: CityKit = h._kit
	for side: float in [-1.0,1.0]:
		var x := middle+side*width*.34
		_box(h,"apartment_steel",xf,Vector3(x,height-.070,-.218),Vector3(.022,.14,.012),Color("#797e7a"))
		_box(h,"apartment_steel",xf,Vector3(x,height-.010,-.128),Vector3(.022,.012,.19),Color("#797e7a"))
		kit.beam("apartment_steel",xf*Vector3(x,height-.125,-.207),xf*Vector3(x,height-.016,-.061),.012,.009,xf.basis.x,Color("#737b77"))

static func _bath(h: Node3D, unit: String, lo: Vector2, hi: Vector2, door: Vector2, y: float) -> void:
	var kit: CityKit = h._kit
	var w := hi.x-lo.x
	var d := hi.y-lo.y
	var cx := (lo.x+hi.x)*.5
	var cz := (lo.y+hi.y)*.5
	var frame := _at(cx,y,cz)
	var shell := Color("#d2d6ca")
	const HEIGHT := 2.22
	const THICK := .060
	_box(h,"apartment_enamel",frame,Vector3(0,.024,0),Vector3(w,.038,d),Color("#c3c5b8"))
	_box(h,"apartment_enamel",frame,Vector3(0,HEIGHT,0),Vector3(w,.047,d),shell)
	for k: int in range(2):
		var z := -d*.5 if k == 0 else d*.5
		_box(h,"apartment_enamel",frame,Vector3(0,HEIGHT*.5,z),Vector3(w,HEIGHT,THICK),shell,"BathEnd%d_%s" % [k,unit])
	_box(h,"apartment_enamel",frame,Vector3(-w*.5,HEIGHT*.5,0),Vector3(THICK,HEIGHT,d),shell,"BathBack_"+unit)
	for edge: Vector2 in [Vector2(lo.y,door.x),Vector2(door.y,hi.y)]:
		var length := edge.y-edge.x
		_box(h,"apartment_enamel",frame,Vector3(w*.5,HEIGHT*.5,(edge.x+edge.y)*.5-cz),Vector3(THICK,HEIGHT,length),shell,"BathReturn_%s_%s" % [unit,edge.x])
	var door_z := (door.x+door.y)*.5-cz
	_box(h,"apartment_enamel",frame,Vector3(w*.5,2.145,door_z),Vector3(THICK,.15,door.y-door.x),shell,"BathLintel_"+unit)
	for z: float in [door.x,door.y]:
		_box(h,"metal",frame,Vector3(w*.5,1.02,z-cz),Vector3(.078,2.05,.025),CHROME)
	_box(h,"metal",frame,Vector3(w*.5,.026,door_z),Vector3(.080,.013,door.y-door.x),CHROME)
	_box(h,"lamp",frame,Vector3(0,2.17,0),Vector3(.44,.04,.15),LINEN)
	var tub_w := w-.15
	var tub_d := .67
	var tub := _at(cx,y+.047,lo.y+.42)
	_well(h,"apartment_ceramic",tub,tub_w,tub_d,.49,.32,PORCELAIN)
	_blocking(h,"BathTub_"+unit,tub,Vector3(0,.239,0),Vector3(tub_w-.05,.48,tub_d-.03))
	kit.disc("metal",tub*Vector3(-tub_w*.19,.119,0),Vector3.RIGHT,Vector3.FORWARD,.023,CHROME)
	var mx := -w*.5+.15
	_box(h,"metal",frame,Vector3(mx,.74,-d*.5+.067),Vector3(.19,.045,.074),CHROME)
	_spout(h,frame.translated_local(Vector3(mx,.681,-d*.5+.095)),.061,.118)
	kit.tube("metal",[frame*Vector3(mx+.07,.73,-d*.5+.089),frame*Vector3(mx+.12,.38,-d*.5+.17),frame*Vector3(mx+.28,.53,-d*.5+.19),frame*Vector3(mx+.27,1.58,-d*.5+.11)],.009,CHROME,6)
	kit.tube("metal",[frame*Vector3(mx+.27,1.53,-d*.5+.11),frame*Vector3(mx+.27,1.66,-d*.5+.10),frame*Vector3(mx+.27,1.69,-d*.5+.16)],.020,CHROME,8)
	kit.disc("plain",frame*Vector3(mx+.27,1.687,-d*.5+.163),Vector3.RIGHT,Vector3.UP,.037,Color("#8c9590"))
	# The cistern sits at the opposite end of the moulded unit, with a short
	# wall basin between WC and bath. The floor beyond its rim stays walkable.
	var toilet := _at(lo.x+.38,y+.045,hi.y-.40,180)
	_box(h,"apartment_ceramic",toilet,Vector3(0,.53,-.233),Vector3(.33,.42,.15),PORCELAIN)
	_box(h,"apartment_ceramic",toilet,Vector3(0,.753,-.233),Vector3(.35,.038,.167),PORCELAIN)
	_box(h,"metal",toilet,Vector3(.174,.658,-.219),Vector3(.035,.026,.047),CHROME)
	_well(h,"apartment_ceramic",toilet.translated_local(Vector3(0,0,.04)),.35,.46,.392,.89,PORCELAIN,.61)
	Soft.pad(h,toilet.translated_local(Vector3(0,.373,.033)),.35,.47,.044,PORCELAIN,0.0,12,12,"apartment_ceramic")
	_blocking(h,"WC_"+unit,toilet,Vector3(0,.24,-.018),Vector3(.34,.48,.53))
	var sink := _at(lo.x+.176,y+.677,lo.y+d*.52,90)
	_well(h,"apartment_ceramic",sink,.40,.262,.135,.52,PORCELAIN,.67)
	_spout(h,sink.translated_local(Vector3(.085,.133,-.096)),.098,.10)
	kit.tube("metal",[sink*Vector3(0,.025,.005),sink*Vector3(0,-.19,.005),sink*Vector3(0,-.21,-.14)],.016,CHROME,7)
	_box(h,"metal",sink,Vector3(0,.64,-.122),Vector3(.37,.43,.02),Color("#a7b8b6"))
	_box(h,"metal",sink,Vector3(0,.40,-.103),Vector3(.38,.018,.066),CHROME)
