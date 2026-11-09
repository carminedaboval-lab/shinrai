extends RefCounted
## Render-only lower-envelope construction. Caller removes replaced_labels()
## after _front(), then calls build() before the street's recursive mesh batch.
## All coordinates retain the approved building-local opening/footprint datum.
const JOINERY = preload("res://scripts/midori_shop_joinery.gd")
const PANEL_JOINT := .0025
const PANEL_RAIL := .041
const PANEL_STILE := .038
const CANOPY_JOINT := .003

static func replaced_labels() -> PackedStringArray:
	return PackedStringArray([
		"WindowLowerTimberPanel", "PanelInsetField", "PanelMortisedRail", "PanelMortisedStile",
		"StoneThresholdToe", "RecessedDoorThreshold", "FrontPierStoneFoot",
		"BoardedTimberCanopy", "TimberCanopyFascia", "CanopyFoldedDrip", "ExposedCanopyRafterEnd"
	])

static func build(street: Node3D, anchor: Node3D, spec: Dictionary) -> Dictionary:
	var batches: Dictionary = {}
	var w := float(spec.w)
	var narrow: bool = spec.roof == "cedar_gable"
	var frame_key := "arch_cedar" if narrow else "arch_pale_wood"
	var panel_count := _panels(batches,w,frame_key)
	_threshold_and_plinth(batches,w,frame_key)
	var timber_canopy: bool = spec.id != "MoriCoffee" and spec.id != "HinataDaily"
	var board_count := 0
	if timber_canopy:
		board_count = _timber_canopy(batches,w-.30,frame_key)
	else:
		_fabric_finish(batches,w-.34,String(spec.awning))
	var assembly := Node3D.new()
	assembly.name = "LowerFrontageConstruction"
	assembly.set_meta("render_only",true)
	assembly.set_meta("panel_count",panel_count)
	assembly.set_meta("panel_joint_m",PANEL_JOINT)
	assembly.set_meta("canopy_board_count",board_count)
	assembly.set_meta("opening_and_footprint_retained",true)
	anchor.add_child(assembly)
	var mats: Dictionary = street.get("materials")
	for key: String in batches:
		var tool: SurfaceTool = batches[key]
		tool.index()
		tool.generate_tangents()
		var visual := MeshInstance3D.new()
		visual.name = "ConstructedEnvelope_"+key
		visual.mesh = preload("res://scripts/midori_south_street_mesh_arrays.gd").commit(tool)
		visual.material_override = JOINERY.material(street,key) if JOINERY.applies(key,visual.name) else mats[key]
		assembly.add_child(visual)
	return {"ok":true,"panels":panel_count,"joint_m":PANEL_JOINT,"canopy_boards":board_count,"material_batches":batches.size(),"lights_created":0,"collisions_created":0}

static func _panels(batches: Dictionary, w: float, frame_key: String) -> int:
	var span := w*.5-.965
	var modules := maxi(2,int(ceil(span/.84)))
	var pitch := span/float(modules)
	for side: float in [-1.0,1.0]:
		var center := side*(.865+span*.5)
		# A 36mm continuous carcass closes the room, behind the loose panels.
		# Its front is 36.5mm behind the field backs: joints have real depth.
		_box(batches,"arch_cladding_backing",Vector3(center,.305,.2095),Vector3(span,.37,.036))
		for i: int in range(modules):
			var width := pitch-PANEL_JOINT
			var x := center-span*.5+(float(i)+.5)*pitch
			# Independent 65mm-deep frames, rather than one long perimeter rail.
			for y: float in [.12+PANEL_RAIL*.5,.49-PANEL_RAIL*.5]:
				_box(batches,frame_key,Vector3(x,y,.125),Vector3(width,PANEL_RAIL,.065))
			for edge: float in [-1.0,1.0]:
				_box(batches,frame_key,Vector3(x+edge*(width-PANEL_STILE)*.5,.305,.125),Vector3(PANEL_STILE,.37-2.0*PANEL_RAIL,.065))
			# Floating field: 2.5mm expansion gap on all four edges. Its street
			# face is 44.5mm behind the frame face, giving a readable shadow.
			var field_width := width-2.0*PANEL_STILE-2.0*PANEL_JOINT
			var field_height := .37-2.0*PANEL_RAIL-2.0*PANEL_JOINT
			_box(batches,"arch_cedar",Vector3(x,.305,.146),Vector3(field_width,field_height,.018))
	return modules*2

static func _threshold_and_plinth(batches: Dictionary, w: float, frame_key: String) -> void:
	# Existing 1.72m stone toe and 1.60m metal threshold retain their exact
	# dimensions. The joinery mesh supplies a tiny physical arris on the stone.
	_box(batches,"arch_stone",Vector3(0,.035,-.12),Vector3(1.72,.07,.26))
	_box(batches,"arch_metal",Vector3(0,.085,.15),Vector3(1.60,.025,.30))
	for side: float in [-1.0,1.0]:
		_box(batches,"arch_stone",Vector3(side*(w*.5-.13),.14,.015),Vector3(.26,.28,.27))
		# Folded shoe isolates the existing timber pier's end grain from stone.
		_box(batches,"arch_metal",Vector3(side*(w*.5-.13),.279,.04),Vector3(.152,.002,.182))
		# Existing profiled jambs start at .130m; make the 32.5mm junction to
		# the threshold explicit without moving a jamb or changing the leaf.
		_box(batches,frame_key,Vector3(side*.8325,.1145,.18),Vector3(.065,.031,.12))
		_box(batches,"arch_metal",Vector3(side*.8325,.09825,.18),Vector3(.065,.0015,.12))
		var span := w*.5-.965
		var center := side*(.865+span*.5)
		var courses := maxi(2,int(ceil(span/.84)))
		var pitch := span/float(courses)
		for i: int in range(courses):
			var x := center-span*.5+(float(i)+.5)*pitch
			_box(batches,"arch_stone",Vector3(x,.075,.19),Vector3(pitch-PANEL_JOINT,.09,.075))
		# A quiet continuous stone weathering caps the plinth, below the panels.
		_box(batches,"arch_stone",Vector3(center,.116,.14),Vector3(span,.008,.12))

static func _timber_canopy(batches: Dictionary, width: float, frame_key: String) -> int:
	var roof_basis := Basis(Vector3.RIGHT,-.15)
	var origin := Vector3(0,2.91,-.69)
	var boards := int(ceil(width/.143))
	var pitch := width/float(boards)
	for i: int in range(boards):
		var x := -width*.5+(float(i)+.5)*pitch
		# 18mm boards run out from the wall, with 3mm drainage joints; their
		# top face equals the top face of the old 55mm monolithic deck.
		_box(batches,frame_key,origin+roof_basis*Vector3(x,.0185,0),Vector3(pitch-CANOPY_JOINT,.018,1.20),roof_basis)
	# A continuous folded metal weather skin closes the deck's expansion joints.
	# The separate timber boards/rafters remain visible from the pavement below.
	_box(batches,"arch_metal",origin+roof_basis*Vector3(0,.0285,0),Vector3(width,.0015,1.20),roof_basis)
	var rafters := maxi(3,int(ceil((width-.12)/.64))+1)
	for i: int in range(rafters):
		var x := lerpf(-width*.5+.06,width*.5-.06,float(i)/float(rafters-1))
		# Full rafters bear directly against the underside of the deck boards.
		_box(batches,"arch_cedar",origin+roof_basis*Vector3(x,-.0355,0),Vector3(.060,.09,1.14),roof_basis)
		if i == 0 or i == rafters-1 or i%3 == 0:
			_canopy_shoe(batches,x)
	# Front fascia covers board end grain. Slim side covers close exposed
	# rafter/deck ends; all remain inside the former exposed-rafter envelope.
	_box(batches,frame_key,origin+roof_basis*Vector3(0,-.0175,-.61),Vector3(width+.04,.09,.035),roof_basis)
	for side: float in [-1.0,1.0]:
		_box(batches,frame_key,origin+roof_basis*Vector3(side*(width*.5-.014),-.0245,0),Vector3(.028,.104,1.20),roof_basis)
	_box(batches,"arch_cedar",Vector3(0,2.976,-.096),Vector3(width-.04,.10,.055))
	# Separate sheet-metal upstand, apron and returned drip are a physical
	# folded flashing, rather than another wooden highlight line.
	_box(batches,"arch_metal",Vector3(0,3.018,-.092),Vector3(width,.095,.0015))
	_box(batches,"arch_metal",origin+roof_basis*Vector3(0,.029,.535),Vector3(width,.0015,.13),roof_basis)
	_box(batches,"arch_metal",origin+roof_basis*Vector3(0,.029,-.617),Vector3(width+.04,.0015,.049),roof_basis)
	_box(batches,"arch_metal",origin+roof_basis*Vector3(0,.019,-.641),Vector3(width+.04,.020,.0015),roof_basis)
	return boards

static func _canopy_shoe(batches: Dictionary, x: float) -> void:
	# Wall plate + two 2mm cheeks + bearing seat; the rafter remains visible.
	_box(batches,"arch_metal",Vector3(x,2.975,-.128),Vector3(.086,.13,.002))
	for side: float in [-1.0,1.0]:
		_box(batches,"arch_metal",Vector3(x+side*.032,2.948,-.174),Vector3(.002,.072,.092))
	_box(batches,"arch_metal",Vector3(x,2.912,-.174),Vector3(.066,.002,.092))

static func _fabric_finish(batches: Dictionary, width: float, key: String) -> void:
	# Preserve the authored main cloth, scallop silhouette and support arms.
	# The folded side hems follow the same sampled fold curve as the fabric.
	for side: float in [-1.0,1.0]:
		var x := side*(width*.5-.009)
		for segment: int in range(12):
			var a := _awning_point(x,float(segment)/12.0)
			var b := _awning_point(x,float(segment+1)/12.0)
			_strip(batches,key,a+Vector3(0,.001,0),b+Vector3(0,.001,0),.018,.0025)
		# Turned valance side edge: thickness is visible in oblique views.
		var hem_bottom := 2.415+.027*cos(x*TAU/.53)
		_box(batches,key,Vector3(x,(2.595+hem_bottom)*.5,-1.3705),Vector3(.018,2.595-hem_bottom,.003))
	var segments := int(ceil(width/.09))
	for i: int in range(segments):
		var xa := -width*.5+width*float(i)/float(segments)
		var xb := -width*.5+width*float(i+1)/float(segments)
		var ya := 2.415+.027*cos(xa*TAU/.53)
		var yb := 2.415+.027*cos(xb*TAU/.53)
		# Ten-millimetre folded lower hem follows the existing scalloped edge.
		var tool := _tool(batches,key)
		_quad(tool,Vector3(xa,ya,-1.372),Vector3(xb,yb,-1.372),Vector3(xb,yb+.010,-1.372),Vector3(xa,ya+.010,-1.372),Vector3.FORWARD)
		_quad(tool,Vector3(xa,ya,-1.372),Vector3(xa,ya,-1.3685),Vector3(xb,yb,-1.3685),Vector3(xb,yb,-1.372),Vector3.DOWN)
	for x: float in [-width*.44,0,width*.44]:
		# Connect the existing thin arm/plate with a compact clevis shoe.
		_box(batches,"arch_metal",Vector3(x,2.866,-.202),Vector3(.052,.004,.074))
		for side: float in [-1.0,1.0]:
			_box(batches,"arch_metal",Vector3(x+side*.025,2.89,-.202),Vector3(.002,.05,.074))
	# Wall head flashing crosses the rear cloth/roller junction, behind fascia.
	_box(batches,"arch_metal",Vector3(0,3.055,-.092),Vector3(width,.062,.0015))
	_box(batches,"arch_metal",Vector3(0,3.025,-.139),Vector3(width,.0015,.095),Basis(Vector3.RIGHT,-.10))

static func _awning_point(x: float, t: float) -> Vector3:
	var fold := .017*cos(x*TAU/.53)*sin(t*PI*.5)
	return Vector3(x,lerpf(3.015,2.595,t)-.035*sin(t*PI)+fold,lerpf(-.12,-1.35,t))

static func _tool(batches: Dictionary, key: String) -> SurfaceTool:
	if not batches.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[key] = tool
	return batches[key] as SurfaceTool

static func _box(batches: Dictionary, key: String, pos: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var member := JOINERY.member_source(size,(key+str(pos)+str(size)).hash())
	_tool(batches,key).append_from(member,0,Transform3D(basis,pos))

static func _strip(batches: Dictionary, key: String, a: Vector3, b: Vector3, width: float, thickness: float) -> void:
	var along := (b-a).normalized()
	var across := Vector3.RIGHT
	var normal := along.cross(across).normalized()
	var basis := Basis(across,normal,along)
	_box(batches,key,(a+b)*.5,Vector3(width,thickness,a.distance_to(b)),basis)

static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	for triangle: Array in [[a,b,c],[a,c,d]]:
		if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).dot(normal) > 0.0:
			triangle.reverse()
		for point: Vector3 in triangle:
			tool.set_normal(normal)
			tool.set_uv(Vector2(point.x,point.y))
			tool.add_vertex(point)
