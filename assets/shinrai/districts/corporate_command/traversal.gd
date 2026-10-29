extends Node3D
## Usable architecture in Godot metres. Shell art and circulation stay separate.
const Layout = preload("traversal_layout.gd")
const Stairs = preload("staircases.tscn")
const Elevator = preload("elevator.tscn")
const Ladder = preload("emergency_ladder.tscn")
var concrete: StandardMaterial3D
var floor_material: StandardMaterial3D
var rail_material: StandardMaterial3D
var amber: StandardMaterial3D
var collision_count := 0

func _ready() -> void:
	add_to_group("cantilever_traversal")
	concrete = _mat(Color(0.32,0.34,0.35),0.82)
	floor_material = _mat(Color("35414c"),0.52)
	rail_material = _mat(Color("9b835d"),0.34)
	rail_material.metallic = 0.65
	amber = _mat(Color("dba558"),0.6)
	_build_cores()
	_build_floors()
	_build_enclosure_collisions()
	_build_ladder_landings()
	add_child(Stairs.instantiate())
	add_child(Elevator.instantiate())
	add_child(Ladder.instantiate())
	_build_signage()
	print("CANTILEVER_TRAVERSAL_READY floors=8 stairs=2 roof=51.28 collision_shapes=",collision_count)

func _mat(c: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=c
	m.roughness=roughness
	return m

func _box(label: String, size: Vector3, at: Vector3, mat: Material, visible_mesh := true, collision := true) -> Node3D:
	var root := Node3D.new()
	root.name=label
	root.position=at
	add_child(root)
	if visible_mesh:
		var mesh := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size=size
		mesh.mesh=shape
		mesh.material_override=mat
		root.add_child(mesh)
	if collision:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size=size
		collider.shape=shape
		body.add_child(collider)
		root.add_child(body)
		collision_count+=1
	return root

func _slab(label: String,x0:float,x1:float,z0:float,z1:float,top:float,visible_mesh:=true) -> void:
	_box(label,Vector3(x1-x0,.24,z1-z0),Vector3((x0+x1)*.5,top-.12,(z0+z1)*.5),floor_material,visible_mesh)

func _rail(a:Vector3,b:Vector3,label:="Guard") -> void:
	var centre := (a+b)*.5+Vector3.UP*.65
	var root := _box(label,Vector3(.06,1.3,a.distance_to(b)),centre,rail_material,false)
	root.look_at_from_position(centre,centre+(b-a),Vector3.UP)
	var top := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size=Vector3(.055,.055,a.distance_to(b))
	top.mesh=bar;top.position.y=.62;top.material_override=rail_material;root.add_child(top)
	var length := a.distance_to(b)
	for i in range(int(ceil(length/1.8))+1):
		var p := a.lerp(b,float(i)/maxf(1.0,ceil(length/1.8)))
		_box("RailPost",Vector3(.045,1.27,.045),p+Vector3.UP*.635,rail_material,true,false)

func _build_cores() -> void:
	for cx in Layout.CORE_CENTRES:
		var side := signf(cx)
		_box("CoreOutsideWall",Vector3(.24,55,12),Vector3(cx+side*2.88,27.5,0),concrete)
		_box("CoreFrontWall",Vector3(6,.0+55,.24),Vector3(cx,27.5,5.88),concrete)
		_box("CoreBackWall",Vector3(6,55,.24),Vector3(cx,27.5,-5.88),concrete)
		_box("CoreCap",Vector3(6,.2,12),Vector3(cx,54.9,0),concrete)
		var inner_x := cx-side*2.88
		_box("CoreInnerRearWall",Vector3(.24,55,9.15),Vector3(inner_x,27.5,-1.425),concrete)
		# Door openings occupy Z3.15..5.6 at every stair landing.
		var bottom := 0.0
		for level in Layout.STAIR_LEVELS:
			if level>bottom:
				_box("InnerWallSpandrel",Vector3(.24,level-bottom,2.45),Vector3(inner_x,(bottom+level)*.5,4.375),concrete)
			bottom=level+2.8
		if bottom<55:
			_box("InnerWallTop",Vector3(.24,55-bottom,2.45),Vector3(inner_x,(bottom+55)*.5,4.375),concrete)
	for level in Layout.STAIR_LEVELS:
		_slab("StairFoyerBridge",-1.8,1.8,3.15,5.6,level)
		_slab("LiftFoyer",-1.2,1.2,1.35,3.2,level)
		for cx in Layout.CORE_CENTRES:
			var lamp := OmniLight3D.new()
			lamp.name="StairLandingLight"
			lamp.position=Vector3(cx,level+2.5,2.4)
			lamp.light_color=Color("ffe0b2")
			lamp.light_energy=4.5
			lamp.omni_range=7.0
			lamp.omni_attenuation=1.2
			lamp.light_specular=0.0
			add_child(lamp)
		# Open front slot: guard intermediate service landings without sealing stops.
		if not Layout.FLOORS.has(level):
			_rail(Vector3(-1.18,level,5.6),Vector3(1.18,level,5.6),"ServiceLandingGuard")

func _build_floors() -> void:
	# An unobstructed lobby route links the entry to the central circulation core.
	_slab("LobbyWalkableDeck",6.4,30.3,0,20.0,.8)
	_slab("LobbyCoreLink",-1.2,30.3,-4,8.4,.8)
	_slab("EntryThreshold",18.35,21.95,19.8,21.4,.8)
	_ramp("EntryAccessRamp",Vector3(20.15,0,24.5),3.6,3.1,.8)
	for y in [17.12,20.62,24.12,27.62]:
		_slab("MiddleWestFloor",-34,-7.25,-16,0,y)
		_slab("MiddleBehindCore",-7.25,7.25,-16,-6,y)
		_slab("MiddleRightFloor",7.25,23.25,-34,0,y)
		if y<27:
			_slab("MiddleCoreFrontGallery",-9.8,10.5,6.15,8.3,y)
			_slab("MiddleCentralExit",-1.2,1.2,5.5,8.3,y)
			_slab("MiddleWestLink",-9.8,-7.4,-.4,8.3,y)
			_slab("MiddleEastLink",7.5,10.5,-.4,8.3,y)
			_rail(Vector3(-9.8,y,8.3),Vector3(10.5,y,8.3))
			_rail(Vector3(-9.8,y,0),Vector3(-9.8,y,8.3))
			_rail(Vector3(10.5,y,0),Vector3(10.5,y,8.3))
			_rail(Vector3(-7.4,y,0),Vector3(-7.4,y,6.15))
			_rail(Vector3(7.5,y,0),Vector3(7.5,y,6.15))
	for y in [39.12,43.12,47.12,51.28]:
		_slab("UpperWestFloor",-36,-7.25,-9,9.12,y)
		_slab("UpperEastFloor",7.25,36,-9,9.12,y)
		_slab("UpperFrontPassage",-7.25,7.25,6.0,9.12,y)
		_slab("UpperRearPassage",-7.25,7.25,-9,-6,y)
		_slab("UpperCentralExit",-1.2,1.2,5.5,9.12,y)
	# Roof edge guards leave a deliberate rear opening for the emergency catwalk.
	_rail(Vector3(-36,51.28,9.12),Vector3(36,51.28,9.12))
	_rail(Vector3(-36,51.28,-9),Vector3(-11.5,51.28,-9))
	_rail(Vector3(-8.5,51.28,-9),Vector3(36,51.28,-9))
	_rail(Vector3(-36,51.28,-9),Vector3(-36,51.28,9.12))
	_rail(Vector3(36,51.28,-9),Vector3(36,51.28,9.12))

func _ramp(label:String,at:Vector3,width:float,length:float,rise:float) -> void:
	var body := StaticBody3D.new()
	body.name=label;body.position=at;add_child(body)
	var points := PackedVector3Array()
	for x in [-width*.5,width*.5]:
		points.append(Vector3(x,-.12,0));points.append(Vector3(x,-.12,-length))
		points.append(Vector3(x,0,0));points.append(Vector3(x,rise,-length))
	var shape := ConvexPolygonShape3D.new();shape.points=points
	var collider := CollisionShape3D.new();collider.shape=shape;body.add_child(collider)
	# Visible wedge shares the collision's exact top slope.
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector3(-width*.5,0,0),Vector3(width*.5,0,0),Vector3(width*.5,rise,-length),Vector3(-width*.5,rise,-length)]
	var indices: Array = [0,1,2,0,2,3] if length>0 else [0,2,1,0,3,2]
	for i in indices: st.add_vertex(corners[i])
	st.generate_normals()
	var mesh := MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=floor_material;body.add_child(mesh)

func _wall(label:String,x0:float,x1:float,z0:float,z1:float,y0:float,y1:float) -> void:
	_box(label,Vector3(x1-x0,y1-y0,z1-z0),Vector3((x0+x1)*.5,(y0+y1)*.5,(z0+z1)*.5),concrete,false)

func _door_wall(label:String,x0:float,x1:float,z:float,door0:float,door1:float,levels:Array) -> void:
	for y in levels:
		_wall(label,x0,door0,z-.08,z+.08,y,y+3.5)
		_wall(label,door1,x1,z-.08,z+.08,y,y+3.5)
		_wall(label,door0,door1,z-.08,z+.08,y+2.8,y+3.5)

func _build_enclosure_collisions() -> void:
	_box("CoreBasePierCollision",Vector3(7.5,10.8,14),Vector3(-11,5.4,-3),concrete,false)
	_box("ReceptionDeskCollision",Vector3(6.1765,1.0,1.75),Vector3(19.2353,1.05,7.5),concrete,false)
	_box("ReceptionBackdropCollision",Vector3(15.8824,8.995,.2083),Vector3(20.1176,5.11,1.6667),concrete,false)
	for x in [7.55,22.95]:
		_box("RearLinkGlassCollision",Vector3(.12,16,6),Vector3(x,8.5,-1),concrete,false)
	_canopy_collision(Vector3(6,10.04,10),Vector3(28.059,13.5,10))
	_canopy_collision(Vector3(28.059,13.5,10),Vector3(36,.7,10))
	_wall("UpperGlassFront",-36,36,9.05,9.25,39.12,51.28)
	_wall("UpperGlassRear",-36,36,-9.25,-9.05,39.12,51.28)
	_wall("UpperWestEnd",-36.2,-36,-9.25,9.25,39.12,51.28)
	_wall("UpperEastEnd",36,36.2,-9.25,9.25,39.12,51.28)
	var middle: Array = [17.12,20.62,24.12]
	_door_wall("MiddleWestFrontGlass",-34,-7.25,0,-9.8,-7.4,middle)
	_door_wall("MiddleEastFrontGlass",7.25,23.25,0,7.5,10.5,middle)
	_door_wall("MiddleRearExitGlass",-34,7.25,-16.3,-11.5,-8.5,middle)
	_wall("MiddleOuterWest",-34.4,-34.2,-16.4,.1,17.12,27.62)
	_wall("MiddleOuterEast",23.4,23.6,-34.4,.1,17.12,27.62)
	_wall("MiddleInnerReturn",6.7,6.9,-34.4,-16.4,17.12,27.62)
	_wall("MiddleFarEnd",6.8,23.6,-34.4,-34.2,17.12,27.62)
	# Lobby front leaves a real door aperture; other glazing remains collision-backed.
	_door_wall("LobbyFrontGlass",6.4,30.3,20,18.4,21.9,[.8])
	_wall("LobbyWestGlass",6.3,6.45,8.4,20,.8,9.7)
	_wall("LobbyEastGlass",30.2,30.35,0,20,.8,10)

func _canopy_collision(a:Vector3,b:Vector3) -> void:
	var root := _box("FoldedCanopyCollision",Vector3(.5,a.distance_to(b),20),(a+b)*.5,concrete,false)
	root.quaternion=Quaternion(Vector3.UP,(b-a).normalized())

func _build_ladder_landings() -> void:
	_slab("RearLadderGround",-12,-8,-22,-17.5,.8)
	_ramp("RearLadderGroundRamp",Vector3(-10,0,-25),3.4,-3,.8)
	for y in [17.12,20.62,24.12,51.28]:
		var front := -8.5 if y>50 else -15.8
		_slab("LadderLeftCheek",-11.5,-10.55,-19.35,front,y)
		_slab("LadderRightCheek",-9.45,-8.5,-19.35,front,y)
		_slab("LadderExitDeck",-10.55,-9.45,-18.45,front,y)
		_rail(Vector3(-11.5,y,-19.35),Vector3(-11.5,y,front))
		_rail(Vector3(-8.5,y,-19.35),Vector3(-8.5,y,front))
		_rail(Vector3(-11.5,y,-19.35),Vector3(-10.55,y,-19.35))
		_rail(Vector3(-9.45,y,-19.35),Vector3(-8.5,y,-19.35))

func _build_signage() -> void:
	for index in range(Layout.FLOORS.size()):
		var y:float=Layout.FLOORS[index]
		_sign(Layout.LABELS[index]+"\nLIFT / STAIRS",Vector3(0,y+2.45,5.75),0,.004,Color("ffe0a0"))
		for side in [-1.0,1.0]:
			_sign("STAIR A" if side<0 else "STAIR B",Vector3(side*1.3,y+2.35,4.4),-side*PI*.5,.005,Color("b7ffd1"))
	for y in [17.12,20.62,24.12,51.28]:
		_sign("EMERGENCY LADDER  ↓",Vector3(-10,y+1.6,-17.6),PI,.006,Color("8affbf"))

func _sign(text:String,at:Vector3,yaw:float,pixel:float,color:Color) -> void:
	# Separate single-sided faces keep the lettering readable from either approach.
	for angle in [yaw,yaw+PI]:
		var label := Label3D.new()
		label.text=text
		label.position=at+Vector3(sin(angle),0,cos(angle))*.005
		label.rotation.y=angle
		label.font_size=40;label.pixel_size=pixel;label.modulate=color
		label.double_sided=false
		add_child(label)

func get_traversal_spawn(label:String) -> Vector3:
	match label:
		"lobby": return Vector3(20.15,1.0,17.0)
		"lift": return Vector3(0,1.0,3.7)
		"stair-west": return Vector3(-4.25,1.0,4.8)
		"stair-east": return Vector3(4.25,1.0,4.8)
		"ladder": return Vector3(-10,1.0,-20)
		"roof": return Vector3(-10,51.5,-12)
	for i in range(1,7):
		if label == ("middle"+str(i) if i<=3 else "upper"+str(i-3)):
			return Vector3(0,Layout.FLOORS[i]+.2,7.1)
	return Vector3(20.15,1.0,17)
