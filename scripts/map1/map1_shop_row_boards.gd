extends Node3D
## A lunch chalkboard and a ramen shop's enamel hours board, each beside its real doorway.
const Kit := preload("res://scripts/interior_kit/house_kit.gd")
const Shell := preload("res://scripts/interior_kit/shell_mesh.gd")
const CoinParking := preload("res://scripts/map1/map1_shop_parking.gd")
const PlazaFurniture := preload("res://scripts/map1/map1_plaza_furniture.gd")
const SignalShader := preload("res://scripts/map1/map1_shop_signal.gdshader")
const INK := Color("#29423c")
const PAPER := Color("#f2e8cd")
const CEDAR := Color("#986742")
const RED := Color("#943e32")

static func install(map: Node3D) -> void:
	var found:=false
	for edge: Node3D in map.street_edges:
		if edge.get_meta("edge").name!="shop row" or not edge.has_node("Asphalt"): continue
		var asphalt: Mesh = edge.get_node("Asphalt").mesh
		var cross_at: float=map.SHOP_ROW_CROSSING
		for i: int in asphalt.get_surface_count():
			var material: ShaderMaterial=asphalt.surface_get_material(i)
			material.set_shader_parameter("shop_row_paint",true)
			material.set_shader_parameter("crossing_s",cross_at)
		found=true
	if not found: return
	CoinParking.install(map)
	PlazaFurniture.install(map)
	var row:=Node3D.new()
	row.name="ShopRowBoards"
	map.add_child(row)
	var signals:=Node3D.new()
	signals.name="ShopRowSignals"
	map.add_child(signals)
	var signal_material:=ShaderMaterial.new()
	signal_material.shader=SignalShader
	for b: Array in map.data.boxes:
		if absf(b[0]+265.99)>0.2 or (absf(b[2]+457.99)>0.2 and absf(b[2]+438.01)>0.2): continue
		if map.data.kinds[int(b[7])]!="signal": continue
		var north: bool=b[2]<-448.0
		var head:=MeshInstance3D.new()
		head.name="North" if north else "South"
		head.position=Vector3(b[0],b[1],b[2])
		head.mesh=signal_heads(north)
		head.material_override=signal_material
		head.visibility_range_end=140
		signals.add_child(head)
	for tenant: Dictionary in map.data.businesses:
		var lunch: bool = tenant.what=="set-meal diner" and absf(tenant.x+372.43)<0.15
		var ramen: bool = tenant.what=="ramen shop" and absf(tenant.x+338.85)<0.15
		if absf(tenant.z+464)>0.15 or not (lunch or ramen): continue
		var site: Dictionary=map.world.site(int(tenant.box))
		if not site.ok or site.street_out.z<0.9: continue
		var width: float=site.size.x
		var door_x: float=site.spec.doors[0].at
		var aside:=width-0.82 if door_x<width*0.5 else 0.82
		var at: Vector3=site.frame*Vector3(aside,0,-1.02)
		var board:=new()
		board.name="LunchMenu" if lunch else "RamenHours"
		board.set_meta("business_box",int(tenant.box))
		row.add_child(board)
		board.position=map.on_ground(at.x,at.z)
		board.rotation.y=atan2(site.street_out.x,site.street_out.z)
		board.build(lunch)
		board.set_physics_process(true)
		add_shop_drain(map,site,board.name)

## Two runs at the low end of the paving, interrupted by the entrance and its
## doorstep. The existing forecourt is the walking surface. The dark slots and
## cast-iron webs sit millimetres above it and add no obstacles.
static func add_shop_drain(map: Node3D, site: Dictionary, business: String) -> void:
	var frame: Transform3D=site.frame
	var width: float=site.size.x
	var door_x: float=site.spec.doors[0].at
	var slots:=Shell.new()
	var gap_lo:=door_x-0.85
	var gap_hi:=door_x+0.85
	for step: Dictionary in site.spec.get("steps",[]):
		if step.wall!="front": continue
		gap_lo=minf(gap_lo,step.at-step.width*0.5-0.10)
		gap_hi=maxf(gap_hi,step.at+step.width*0.5+0.10)
	var origin: Vector3=map.on_ground(frame.origin.x,frame.origin.z)
	for span: Vector2 in [Vector2(0.18,gap_lo),Vector2(gap_hi,width-0.18)]:
		var panels:=floori((span.y-span.x)/0.46)
		for i: int in panels:
			var x:=span.x+i*0.46
			var mid:=frame*Vector3(x+0.23,0,-0.22)
			if map.paving_lift(mid.x,mid.z)<=0: continue
			var plane:=Transform3D.IDENTITY
			for p: Vector2 in [Vector2(0,0),Vector2(0.454,0),Vector2(0,0.160)]:
				var w:=frame*Vector3(x+p.x,0,-0.298+p.y)
				var v: Vector3=map.on_ground(w.x,w.z,map.paving_lift(w.x,w.z))-origin
				if p==Vector2.ZERO: plane.origin=v
				elif p.x>0: plane.basis.x=(v-plane.origin)/p.x
				else: plane.basis.z=(v-plane.origin)/p.y
			var iron:=Color("#64635b") if i%3!=0 else Color("#72685a")
			drain_face(slots,plane,0,0.454,0,0.16,0.002,Color("#343633"))
			for z: float in [0.0,0.144]:
				drain_face(slots,plane,0,0.454,z,z+0.016,0.004,iron)
			for j: int in 10:
				var bar:=j*0.046
				drain_face(slots,plane,bar,bar+0.032,0.016,0.144,0.004,iron)
	if slots.is_empty(): return
	var drain:=MeshInstance3D.new()
	drain.name=business+"Drain"
	drain.position=origin
	drain.mesh=slots.commit()
	drain.visibility_range_end=70
	map.add_child(drain)

static func drain_face(shell: RefCounted, f: Transform3D, a: float, b: float, c: float, d: float, lift: float, tint: Color) -> void:
	shell.quad(f*Vector3(a,lift,c),f*Vector3(b,lift,c),f*Vector3(b,lift,d),f*Vector3(a,lift,d),Vector3.UP,tint)

var settled:=false
func _physics_process(_delta: float) -> void:
	# Seat the feet on the finished walk, including the version without built kerbs.
	if settled: return
	var top:=global_position+Vector3.UP*0.32
	var query:=PhysicsRayQueryParameters3D.create(top,global_position-Vector3.UP*0.5,1)
	query.exclude=[($Body as StaticBody3D).get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): global_position.y=hit.position.y
	settled=true
	set_physics_process(false)

func build(lunch: bool) -> void:
	var mesh:=Shell.new()
	var f:=Transform3D.IDENTITY
	if lunch:
		for x: float in [-0.27,0.27]:
			for sign_: int in [-1,1]:
				var leg:=Transform3D(Basis(Vector3.RIGHT,sign_*0.17),Vector3(x,0.50,-sign_*0.095))
				mesh.box(leg,Vector3.ZERO,Vector3(0.042,1.02,0.044),CEDAR)
		mesh.box(f,Vector3(0,0.61,0.045),Vector3(0.60,0.74,0.055),CEDAR)
		mesh.box(f,Vector3(0,0.61,0.078),Vector3(0.53,0.67,0.018),INK)
		write(mesh,"本日の定食","LUNCH",0.80,0.092,0.46,0.105,PAPER)
		write(mesh,"焼き魚","GRILLED FISH",0.59,0.092,0.44,0.10,PAPER)
		write(mesh,"ご飯・みそ汁","RICE / MISO",0.41,0.092,0.46,0.072,PAPER)
	else:
		mesh.box(f,Vector3(0,0.026,0),Vector3(0.49,0.052,0.34),RED)
		mesh.box(f,Vector3(0,0.44,0),Vector3(0.054,0.84,0.046),CEDAR)
		mesh.box(f,Vector3(0,0.86,0),Vector3(0.52,0.53,0.046),RED)
		mesh.box(f,Vector3(0,0.84,0.029),Vector3(0.47,0.42,0.018),PAPER)
		write(mesh,"らーめん","RAMEN",0.97,0.045,0.43,0.103,RED)
		write(mesh,"営業時間","HOURS",0.84,0.045,0.36,0.067,INK)
		write(mesh,"11:00–20:00","11-20",0.73,0.045,0.43,0.066,INK)
	var vis:=MeshInstance3D.new()
	vis.name="Board"
	vis.mesh=mesh.commit()
	vis.visibility_range_end=65.0
	add_child(vis)
	var body:=StaticBody3D.new()
	body.name="Body"
	add_child(body)
	var shape:=BoxShape3D.new()
	shape.size=Vector3(0.60,1.02,0.34) if lunch else Vector3(0.52,1.13,0.34)
	var collision:=CollisionShape3D.new()
	collision.shape=shape
	collision.position.y=shape.size.y*0.5
	body.add_child(collision)

static func write(mesh: RefCounted, jp: String, fallback: String, y: float, z: float, w: float, h: float, tint: Color) -> void:
	var glyph:=Kit.sign_shape(jp)
	if glyph.corners.is_empty(): glyph=Kit.sign_shape(fallback)
	if glyph.corners.is_empty(): return
	mesh.flat(Transform3D(Basis.IDENTITY,Vector3(0,y,z)),glyph.corners,minf(w/glyph.size.x,h/glyph.size.y),tint)

## Static pedestrian phase: a red vehicle light on the approach side (red on the
## driver's right of the three lenses) and a green walking figure facing each kerb.
static func signal_heads(north: bool) -> ArrayMesh:
	var shell:=Shell.new()
	var dark:=Color("#293035")
	var grey:=Color("#566168")
	var curb_dir:=1.0 if north else -1.0
	var f:=Transform3D(Basis(Vector3.UP,0.0 if north else PI),Vector3(0,2.75,curb_dir*0.23))
	shell.box(f,Vector3.ZERO,Vector3(0.31,0.57,0.16),grey)
	shell.box(f,Vector3(0,0,0.085),Vector3(0.26,0.50,0.026),dark)
	shell.box(f,Vector3(0,0.26,0.12),Vector3(0.31,0.032,0.19),grey)
	var green:=Color("#70e2a5")
	lens(shell,f,Vector3(0.015,-0.036,0.106),0.028,green)
	for segment: Array in [[0,-0.107,0.1,0.094],[0.038,-0.10,0.91,0.075],[-0.04,-0.11,0.80,0.066],[0.03,-0.177,0.55,0.102],[-0.036,-0.175,-0.69,0.102]]:
		var limb:=f*Transform3D(Basis(Vector3.BACK,float(segment[2])),Vector3(segment[0],segment[1],0.109))
		shell.box(limb,Vector3.ZERO,Vector3(0.021,segment[3],0.014),green)
	if north:
		var arm:=Transform3D.IDENTITY
		shell.box(arm,Vector3(0,5.77,0.76),Vector3(0.13,0.14,1.52),grey)
		var main:=Transform3D(Basis(Vector3.UP,-PI/2),Vector3(-0.15,5.55,1.23))
		shell.box(main,Vector3.ZERO,Vector3(1.18,0.43,0.23),grey)
		shell.box(main,Vector3(0,0,0.124),Vector3(1.13,0.38,0.034),dark)
		for i: int in 3:
			var x: float=(i-1)*0.36
			lens(shell,main,Vector3(x,0,0.151),0.138,[Color("#275343"),Color("#5d5030"),Color("#ff5545")][i])
			shell.box(main,Vector3(x,0.164,0.197),Vector3(0.303,0.036,0.235),dark)
	return shell.commit()

static func lens(mesh: RefCounted, f: Transform3D, centre: Vector3, radius: float, tint: Color) -> void:
	for i: int in 16:
		var a:=TAU*i/16.0
		var b:=TAU*(i+1)/16.0
		mesh.triangle(f*centre,f*(centre+Vector3(cos(a),sin(a),0)*radius),f*(centre+Vector3(cos(b),sin(b),0)*radius),f.basis.z,tint)
