extends RefCounted
## Bevelled joinery and pressed bowls share the existing room material batches.
## No new mesh instances, lights, collision bodies, or texture dependencies.
const CityKit := preload("res://scripts/midori_near_city_kit.gd")

static func bevel(kit: CityKit, part: String, xf: Transform3D, size: Vector3, radius: float, tint: Color) -> void:
	var half := size*.5
	var r := minf(radius,minf(half.x,minf(half.y,half.z))*.80)
	var inner := half-Vector3.ONE*r
	var axes: Array[Vector3] = [Vector3.RIGHT,Vector3.UP,Vector3.BACK]
	# Six broad flat faces. The narrow adjoining chamfers are independent
	# so furniture still has crisp construction planes under grazing light.
	for axis: int in range(3):
		var other := (axis+1)%3
		var last := (axis+2)%3
		for sign: float in [-1.0,1.0]:
			var n := axes[axis]*sign
			var centre := n*half[axis]
			var points: Array[Vector3] = []
			var uv: Array[Vector2] = []
			for p: Vector2 in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,1),Vector2(1,-1)]:
				points.append(xf*(centre+axes[other]*p.x*inner[other]+axes[last]*p.y*inner[last]))
				var grain := Vector2(p.x*inner[other],p.y*inner[last])
				if part == "apartment_wood" and inner[other] > inner[last]: grain = Vector2(grain.y,grain.x)
				uv.append(grain)
			var normal := xf.basis*n
			kit.mapped(part,points,[normal,normal,normal,normal],uv,[0.0,0.0,0.0,0.0],tint,.98)
	# Twelve chamfers; the interpolated normals meet the planar faces without
	# a hard black seam. Radius remains inside the original solid's bounds.
	for along: int in range(3):
		var a := (along+1)%3
		var b := (along+2)%3
		for sa: float in [-1.0,1.0]:
			for sb: float in [-1.0,1.0]:
				var edge_a := axes[a]*sa*half[a]+axes[b]*sb*inner[b]
				var edge_b := axes[a]*sa*inner[a]+axes[b]*sb*half[b]
				var run := axes[along]*inner[along]
				var na := xf.basis*axes[a]*sa
				var nb := xf.basis*axes[b]*sb
				kit.mapped(part,[xf*(edge_a-run),xf*(edge_a+run),xf*(edge_b+run),xf*(edge_b-run)],
					[na,na,nb,nb],[Vector2(0,0),Vector2(0,inner[along]*2),Vector2(r*1.414,inner[along]*2),Vector2(r*1.414,0)],
					[0.0,0.0,0.0,0.0],tint,.98)
	for sx: float in [-1.0,1.0]:
		for sy: float in [-1.0,1.0]:
			for sz: float in [-1.0,1.0]:
				var corner := inner*Vector3(sx,sy,sz)
				var a := xf*(corner+Vector3(sx*r,0,0))
				var b := xf*(corner+Vector3(0,sy*r,0))
				var c := xf*(corner+Vector3(0,0,sz*r))
				var na := xf.basis*Vector3(sx,0,0)
				var nb := xf.basis*Vector3(0,sy,0)
				var nc := xf.basis*Vector3(0,0,sz)
				kit.smooth(part,a,b,c,c,na,nb,nc,nc,tint,.98)

static func lathe(kit: CityKit, part: String, xf: Transform3D, profile: Array[Vector2], tint: Color, sides := 24) -> void:
	# Smooth both around the pot and along its turned profile. The old kit
	# retains a hard normal at each profile ring, which reads as stacked cones.
	for row: int in range(profile.size()-1):
		for side: int in range(sides):
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			var uv: Array[Vector2] = []
			for index: Vector2i in [Vector2i(side,row),Vector2i(side,row+1),Vector2i(side+1,row+1),Vector2i(side+1,row)]:
				var angle := TAU*float(index.x)/sides
				var radial := Vector3(cos(angle),0,sin(angle))
				var p := profile[index.y]
				var slope := profile[mini(index.y+1,profile.size()-1)]-profile[maxi(0,index.y-1)]
				var normal := (radial*slope.y-Vector3.UP*slope.x).normalized()
				points.append(xf*(radial*p.x+Vector3.UP*p.y))
				normals.append(xf.basis*normal)
				uv.append(Vector2(angle*maxf(p.x,.001),p.y))
			kit.mapped(part,points,normals,uv,[0.0,0.0,0.0,0.0],tint)

static func _ring(width: float, depth: float, y: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	var radius := minf(width,depth)*.20
	for corner: int in range(4):
		var angle0 := float(corner)*PI*.5
		var centre := Vector2(1 if corner < 1 or corner > 2 else -1,1 if corner < 2 else -1)
		centre *= Vector2(width*.5-radius,depth*.5-radius)
		for step: int in range(6):
			var angle := angle0+float(step)/5.0*PI*.5
			result.append(Vector3(centre.x+cos(angle)*radius,y,centre.y+sin(angle)*radius))
	return result

static func sink(kit: CityKit, xf: Transform3D, tint: Color) -> void:
	var profile: Array[Vector3] = [Vector3(.451,.340,-.008),Vector3(.464,.353,.004),
		Vector3(.424,.313,.006),Vector3(.408,.297,0),Vector3(.390,.278,-.055),
		Vector3(.332,.220,-.115),Vector3(.285,.175,-.126)]
	var rings: Array[PackedVector3Array] = []
	for p: Vector3 in profile: rings.append(_ring(p.x,p.y,p.z))
	const SIDES := 24
	for row: int in range(rings.size()-1):
		for side: int in range(SIDES):
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			var uv: Array[Vector2] = []
			for index: Vector2i in [Vector2i(side,row),Vector2i(side,row+1),Vector2i((side+1)%SIDES,row+1),Vector2i((side+1)%SIDES,row)]:
				var p := rings[index.y][index.x]
				var around := rings[index.y][(index.x+1)%SIDES]-rings[index.y][(index.x+SIDES-1)%SIDES]
				var down := rings[mini(index.y+1,rings.size()-1)][index.x]-rings[maxi(0,index.y-1)][index.x]
				var normal := down.cross(around).normalized()
				points.append(xf*p)
				normals.append(xf.basis*normal)
				uv.append(Vector2(p.x,p.z))
			kit.mapped("apartment_steel",points,normals,uv,[0.0,0.0,0.0,0.0],tint)
	var centre := xf*Vector3(0,-.126,0)
	var up := xf.basis.y
	for side: int in range(SIDES):
		kit.smooth("apartment_steel",xf*rings[-1][side],xf*rings[-1][(side+1)%SIDES],centre,centre,up,up,up,up,tint.darkened(.06))
	var drain := xf.translated_local(Vector3(0,-.124,.018))
	lathe(kit,"apartment_steel",drain,[Vector2(.029,0),Vector2(.030,.002),Vector2(.024,.004),Vector2(.020,.003)],tint,20)
	kit.disc("apartment_steel",drain*Vector3(0,.003,0),xf.basis.x,-xf.basis.z,.020,tint.darkened(.18))
	for hole: int in range(6):
		var angle := TAU*float(hole)/6.0
		kit.disc("plain",drain*Vector3(cos(angle)*.012,.004,sin(angle)*.012),xf.basis.x,-xf.basis.z,.0034,Color("#353d3d"))

