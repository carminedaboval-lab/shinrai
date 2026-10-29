extends Node3D
## Shared metre-scale modelling helpers for the corporate district.
var geometry_count := 0
var collider_count := 0

func mat(color:Color,roughness:float=.8,emission:float=0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=color; m.roughness=roughness
	if emission>0:
		m.emission_enabled=true; m.emission=color; m.emission_energy_multiplier=emission
	return m

func box(label:String,size:Vector3,at:Vector3,material:Material,collision:bool=true) -> Node3D:
	var node := MeshInstance3D.new()
	node.name=label; node.position=at
	var mesh := BoxMesh.new(); mesh.size=size
	node.mesh=mesh; node.material_override=material; add_child(node)
	geometry_count+=1
	if collision:
		var body := StaticBody3D.new()
		var shape := BoxShape3D.new(); shape.size=size
		var col := CollisionShape3D.new(); col.shape=shape
		body.add_child(col); node.add_child(body); collider_count+=1
	return node

func slab(label:String,x0:float,x1:float,z0:float,z1:float,top:float,material:Material,thickness:float=.22) -> void:
	box(label,Vector3(x1-x0,thickness,z1-z0),Vector3((x0+x1)*.5,top-thickness*.5,(z0+z1)*.5),material)

func ramp(label:String,start:Vector3,end:Vector3,width:float,material:Material) -> void:
	var direction := end-start
	var side := Vector3(-direction.z,0,direction.x).normalized()*width*.5
	var corners := [start-side,start+side,end+side,end-side]
	var node := StaticBody3D.new(); node.name=label; add_child(node)
	var points := PackedVector3Array()
	for p in corners:
		points.append(p); points.append(p-Vector3.UP*.18)
	var shape := ConvexPolygonShape3D.new(); shape.points=points
	var col := CollisionShape3D.new(); col.shape=shape; node.add_child(col)
	collider_count+=1
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices: Array = [0,1,2,0,2,3]
	# The lateral basis keeps this winding consistent for either travel direction.
	for i in indices: surface.add_vertex(corners[i])
	surface.generate_normals()
	var mesh := MeshInstance3D.new(); mesh.mesh=surface.commit(); mesh.material_override=material
	node.add_child(mesh); geometry_count+=1

func beam(label:String,a:Vector3,b:Vector3,width:float,material:Material,collision:bool=false) -> Node3D:
	var middle := (a+b)*.5
	var node := box(label,Vector3(width,width,a.distance_to(b)),middle,material,collision)
	var direction := (b-a).normalized()
	var up := Vector3.RIGHT if absf(direction.dot(Vector3.UP))>.98 else Vector3.UP
	node.basis=Basis.looking_at(direction,up)
	return node

func rail(a:Vector3,b:Vector3,material:Material,height:float=1.1) -> void:
	var length := a.distance_to(b)
	beam("Handrail",a+Vector3.UP*height,b+Vector3.UP*height,.065,material)
	beam("Midrail",a+Vector3.UP*.55,b+Vector3.UP*.55,.045,material)
	var barrier := StaticBody3D.new()
	barrier.name="GuardCollision"; add_child(barrier)
	barrier.position=(a+b)*.5+Vector3.UP*height*.5
	barrier.basis=Basis.looking_at((b-a).normalized(),Vector3.UP)
	var shape := BoxShape3D.new(); shape.size=Vector3(.08,height,length)
	var col := CollisionShape3D.new(); col.shape=shape; barrier.add_child(col); collider_count+=1
	var segments := maxi(1,int(ceil(length/1.8)))
	for i in range(segments+1):
		box("GuardPost",Vector3(.06,height,.06),a.lerp(b,float(i)/segments)+Vector3.UP*height*.5,material,false)

func sign_text(caption:String,at:Vector3,yaw:float,width:float,color:Color) -> Label3D:
	var sign := Label3D.new()
	sign.text=caption; sign.position=at; sign.rotation.y=yaw
	sign.font_size=64; sign.pixel_size=width/maxf(1.0,float(caption.length())*37.0)
	sign.modulate=color; sign.outline_size=5; sign.double_sided=false
	add_child(sign)
	return sign

func light(at:Vector3,color:Color,energy:float=3.0,range_m:float=8.0,shadows:bool=false) -> OmniLight3D:
	var lamp := OmniLight3D.new(); lamp.position=at; lamp.light_color=color
	lamp.light_energy=energy; lamp.omni_range=range_m; lamp.omni_attenuation=1.25
	lamp.light_specular=.25; lamp.shadow_enabled=shadows
	add_child(lamp); return lamp

func parked_car(at:Vector3,color:Color,yaw:float=0.0) -> Node3D:
	var car := Node3D.new(); car.name="ParkedEV"; add_child(car)
	var paint := mat(color,.3); paint.metallic=.45
	var glass := mat(Color("142837"),.22); glass.metallic=.3
	var tyre := mat(Color("101419"),.95)
	var white := mat(Color("c8f5ff"),.35,.65)
	var red := mat(Color("ff3f5e"),.35,.7)
	var parts: Array[Node3D] = []
	parts.append(box("CarBody",Vector3(1.85,.48,4.25),Vector3(0,.59,0),paint,false))
	parts.append(box("CarCabin",Vector3(1.56,.65,2.1),Vector3(0,1.12,-.1),glass,false))
	parts.append(box("CarRoof",Vector3(1.6,.08,2.16),Vector3(0,1.48,-.1),paint,false))
	parts.append(box("FrontLED",Vector3(1.6,.07,.04),Vector3(0,.7,2.14),white,false))
	parts.append(box("RearLED",Vector3(1.5,.06,.04),Vector3(0,.7,-2.14),red,false))
	for x in [-.91,.91]:
		for z in [-1.35,1.35]:
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new(); cylinder.top_radius=.33; cylinder.bottom_radius=.33; cylinder.height=.22; cylinder.radial_segments=12
			wheel.mesh=cylinder; wheel.material_override=tyre; wheel.position=Vector3(x,.34,z); wheel.rotation.z=PI*.5
			add_child(wheel); parts.append(wheel); geometry_count+=1
	for part in parts: part.reparent(car,false)
	var body := StaticBody3D.new(); car.add_child(body)
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size=Vector3(1.85,1.45,4.25)
	collision.shape=shape; collision.position.y=.74; body.add_child(collision); collider_count+=1
	car.position=at; car.rotation.y=yaw
	return car

func tree(at:Vector3,scale_m:float=1.0) -> void:
	var bark := mat(Color("4d4942"),.95)
	var leaf := mat(Color("436653"),.92)
	box("TreeTrunk",Vector3(.25,3.1,.25)*scale_m,at+Vector3.UP*1.55*scale_m,bark,true)
	for i in range(3):
		var crown := MeshInstance3D.new()
		var mesh := SphereMesh.new(); mesh.radius=1.25*scale_m; mesh.height=2.3*scale_m; mesh.radial_segments=12; mesh.rings=6
		crown.mesh=mesh; crown.material_override=leaf
		crown.position=at+Vector3(sin(i*2.1)*.55,3.1+i*.42,cos(i*2.1)*.55)*scale_m
		add_child(crown); geometry_count+=1
