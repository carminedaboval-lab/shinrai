extends RefCounted
## Original constructed rainwater assemblies, metres; no collision or layout edits.
## API build(street, building_anchor, original_architecture_spec). Call after roof.
## Roof placement verified against imported GLB POSITION bounds; runtime review
## remains root-owned. Two batched meshes, no new materials in street dictionary.
## Root suppresses RainwaterPipe, TiledRoofGutter, ParapetCap,
## ParapetFoldedDrip and SideCoping in architecture._box. Keep all parapet walls.
var batches: Dictionary = {}
var sections: Array[Dictionary] = []

func build(_street: Node3D, anchor: Node3D, spec: Dictionary) -> Dictionary:
	batches.clear();sections.clear()
	var assembly:=Node3D.new();assembly.name="ConstructedRoofRainwater";anchor.add_child(assembly)
	var w: float=spec.w;var h: float=spec.eave
	if str(spec.roof)=="flat":
		_flat(w,h)
	else:
		var narrow: bool=str(spec.roof)=="cedar_gable"
		for side: float in [-1.0,1.0]:
			var a:=Vector3(-w*.5-.14,h-.17,4+side*4.70)
			var b:=Vector3(w*.5+.14,h-.17,4+side*4.70)
			var outward:=Vector3(0,0,side)
			if narrow:
				a=Vector3(side*(w*.5+.20),h-.17,-.63);b=Vector3(side*(w*.5+.20),h-.17,8.63);outward=Vector3(side,0,0)
			_gutter(a,b,outward)
			# Outlet is at real overhanging gutter, not a wall-corner floating pipe.
			var outlet: Vector3=a.lerp(b,.94)
			var wall: Vector3=outlet-outward*(.44 if narrow else .48)
			if narrow: wall.x=side*(w*.5+.075)
			else: wall.z=-.10 if side<0 else 8.08
			_downpipe(outlet-Vector3.UP*.061,wall,h,outward)
	for key: String in batches:
		var mesh: ArrayMesh=(batches[key] as SurfaceTool).commit()
		var visual:=MeshInstance3D.new();visual.name="Rainwater_"+key;visual.mesh=mesh
		var material:=StandardMaterial3D.new();material.albedo_color=Color("#454e48") if key=="metal" else Color("#6e5941")
		material.roughness=.54 if key=="metal" else .79;material.metallic=.65 if key=="metal" else 0.0
		material.cull_mode=BaseMaterial3D.CULL_DISABLED;visual.material_override=material;assembly.add_child(visual)
	var report: Dictionary={"building":spec.id,"sections":sections,"meshes":batches.size(),"collision_added":false,"units":"metres"}
	assembly.set_meta("rainwater_construction",report)
	return report

func _surface(key: String) -> SurfaceTool:
	if not batches.has(key):
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);batches[key]=tool
	return batches[key]

func _quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,key: String="metal") -> void:
	var tool:=_surface(key);var normal: Vector3=(b-a).cross(c-a).normalized()
	for point: Vector3 in [a,c,b,a,d,c]:tool.set_normal(normal);tool.add_vertex(point)

func _box(p: Vector3,size: Vector3,key: String="metal") -> void:
	var a:=p-size*.5;var b:=p+size*.5
	_quad(Vector3(a.x,a.y,a.z),Vector3(a.x,b.y,a.z),Vector3(b.x,b.y,a.z),Vector3(b.x,a.y,a.z),key)
	_quad(Vector3(b.x,a.y,b.z),Vector3(b.x,b.y,b.z),Vector3(a.x,b.y,b.z),Vector3(a.x,a.y,b.z),key)
	_quad(Vector3(a.x,a.y,b.z),Vector3(a.x,b.y,b.z),Vector3(a.x,b.y,a.z),Vector3(a.x,a.y,a.z),key)
	_quad(Vector3(b.x,a.y,a.z),Vector3(b.x,b.y,a.z),Vector3(b.x,b.y,b.z),Vector3(b.x,a.y,b.z),key)
	_quad(Vector3(a.x,b.y,a.z),Vector3(a.x,b.y,b.z),Vector3(b.x,b.y,b.z),Vector3(b.x,b.y,a.z),key)
	_quad(Vector3(a.x,a.y,b.z),Vector3(a.x,a.y,a.z),Vector3(b.x,a.y,a.z),Vector3(b.x,a.y,b.z),key)

func _pipe(points: PackedVector3Array,radius: float) -> void:
	# Swept circular profile with shared bend rings; genuinely hollow open ends.
	var count:=16
	for i: int in range(points.size()-1):
		var ta: Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
		var tb: Vector3=(points[mini(i+2,points.size()-1)]-points[i]).normalized()
		var ua: Vector3=ta.cross(Vector3.RIGHT).normalized();var ub: Vector3=tb.cross(Vector3.RIGHT).normalized()
		if ua.length()<.5:ua=ta.cross(Vector3.FORWARD).normalized()
		if ub.length()<.5:ub=tb.cross(Vector3.FORWARD).normalized()
		var va:=ta.cross(ua);var vb:=tb.cross(ub)
		for j: int in range(count):
			var angle: float=TAU*float(j)/count;var next: float=TAU*float(j+1)/count
			# Angle then axis yields the outward radial cross-product normal.
			_quad(points[i]+(ua*cos(angle)+va*sin(angle))*radius,points[i]+(ua*cos(next)+va*sin(next))*radius,points[i+1]+(ub*cos(next)+vb*sin(next))*radius,points[i+1]+(ub*cos(angle)+vb*sin(angle))*radius)

func _gutter(a: Vector3,b: Vector3,outward: Vector3) -> void:
	var length: float=a.distance_to(b);var along: Vector3=(b-a).normalized()
	# 125mm half round channel, 2mm wall, inner/outer skin and rolled lips.
	for i: int in range(16):
		var t0: float=PI*float(i)/16;var t1: float=PI*float(i+1)/16
		var p0: Vector3=outward*cos(t0)-Vector3.UP*sin(t0);var p1: Vector3=outward*cos(t1)-Vector3.UP*sin(t1)
		var outlet_distance: float=length*.94
		var cuts: Array[float]=[0.0,outlet_distance-.038,outlet_distance+.038,length]
		for span: int in range(3):
			# Open throat through gutter invert directly over circular outlet.
			if span==1 and i in [5,6,7,8,9,10]: continue
			var start: Vector3=a+along*cuts[span];var finish: Vector3=a+along*cuts[span+1]
			_quad(start+p0*.064,start+p1*.064,finish+p1*.064,finish+p0*.064)
			_quad(start+p1*.062,start+p0*.062,finish+p0*.062,finish+p1*.062)
		for end: Vector3 in [a,b]:_quad(end+p0*.062,end+p1*.062,end+p1*.064,end+p0*.064)
	for sign_value: float in [-1.0,1.0]:_pipe(PackedVector3Array([a+outward*.063*sign_value,b+outward*.063*sign_value]),.003)
	# Shaped end closures at both gutter ends.
	for end: Vector3 in [a,b]:
		for i: int in range(16):
			var t0: float=PI*float(i)/16;var t1: float=PI*float(i+1)/16
			var tool:=_surface("metal");tool.set_normal(along)
			var first: Vector3=end+(outward*cos(t0)-Vector3.UP*sin(t0))*.064
			var second: Vector3=end+(outward*cos(t1)-Vector3.UP*sin(t1))*.064
			var normal: Vector3=(first-end).cross(second-end).normalized()
			var desired: Vector3=-along if end.is_equal_approx(a) else along
			if normal.dot(desired)<0:
				var swap: Vector3=first;first=second;second=swap;normal=-normal
			tool.set_normal(normal)
			for p: Vector3 in [end,second,first]:tool.add_vertex(p)
	var intervals:=maxi(1,ceili(length/.70))
	for i: int in range(intervals+1):
		var at: Vector3=a.lerp(b,float(i)/intervals)
		var band:=PackedVector3Array()
		for j: int in range(13):band.append(at+(outward*cos(PI*j/12.0)-Vector3.UP*sin(PI*j/12.0))*.067)
		_pipe(band,.0035)
		_pipe(PackedVector3Array([at-outward*.065,at-outward*.12+Vector3.UP*.025]),.004)
	# Slim fascia and closed soffit at eave underside, not a thick roof slab.
	var centre: Vector3=(a+b)*.5-outward*.095-Vector3.UP*.055
	_box(centre,Vector3(length,.12,.022) if absf(along.x)>.5 else Vector3(.022,.12,length),"timber")
	_box(centre-outward*.10-Vector3.UP*.052,Vector3(length,.018,.20) if absf(along.x)>.5 else Vector3(.20,.018,length),"timber")
	sections.append({"kind":"open_half_round_gutter","a":a,"b":b,"diameter_m":.128,"hangers":intervals+1})

func _downpipe(outlet: Vector3,wall: Vector3,h: float,outward: Vector3) -> void:
	var top: Vector3=Vector3(wall.x,outlet.y-.37,wall.z)
	var route:=PackedVector3Array([outlet, outlet-Vector3.UP*.10,outlet.lerp(top,.25)-Vector3.UP*.06,outlet.lerp(top,.75)+Vector3.UP*.06,top,Vector3(wall.x,.26,wall.z),Vector3(wall.x,.14,wall.z)+outward*.045,Vector3(wall.x,.105,wall.z)+outward*.16])
	_pipe(route,.038)
	# Visible shoe has a real 2mm annular metal lip and 18mm inner return.
	var mouth: Vector3=route[-1];var direction: Vector3=(mouth-route[-2]).normalized()
	var ring_u: Vector3=direction.cross(Vector3.RIGHT).normalized()
	if ring_u.length()<.5:ring_u=direction.cross(Vector3.UP).normalized()
	var ring_v: Vector3=direction.cross(ring_u)
	for j: int in range(16):
		var t0: float=TAU*j/16.0;var t1: float=TAU*(j+1)/16.0
		var r0: Vector3=ring_u*cos(t0)+ring_v*sin(t0);var r1: Vector3=ring_u*cos(t1)+ring_v*sin(t1)
		_quad(mouth+r0*.036,mouth+r0*.038,mouth+r1*.038,mouth+r1*.036)
		_quad(mouth+r0*.036,mouth+r1*.036,mouth-direction*.018+r1*.036,mouth-direction*.018+r0*.036)
	# Socket sleeves, fixing saddles and wall stand-offs stay in the same batch.
	for y: float in [.55,h*.46,h-.70]:
		var p:=Vector3(wall.x,y,wall.z)
		_pipe(PackedVector3Array([p-Vector3.UP*.018,p+Vector3.UP*.018]),.041)
		_box(p-outward*.055,Vector3(.06,.025,.08))
	sections.append({"kind":"connected_downpipe","outlet":outlet,"wall_top":top,"shoe":route[-1],"diameter_m":.076,"fixings":3})

func _flat(w: float,h: float) -> void:
	# Folded coping crown with downturned weather edges and hemmed drip returns.
	for z: float in [-.02,7.94]:
		var side: float=-1.0 if z<1 else 1.0
		_box(Vector3(0,h+.35,z),Vector3(w+.20,.018,.36))
		_box(Vector3(0,h+.319,z+side*.18),Vector3(w+.20,.064,.012))
		_box(Vector3(0,h+.289,z+side*.19),Vector3(w+.20,.008,.026))
	for side: float in [-1.0,1.0]:
		_box(Vector3(side*w*.5,h+.35,4),Vector3(.30,.018,8.12))
		_box(Vector3(side*(w*.5+.15),h+.319,4),Vector3(.012,.064,8.12))
		_box(Vector3(side*(w*.5+.16),h+.289,4),Vector3(.026,.008,8.12))
		var x: float=side*(w*.5-.20)
		var z: float=-.19
		# Open hopper: tapered four walls, visible throat, connected wall pipe.
		var top:=Vector3(x,h+.03,z);var low:=Vector3(x,h-.17,z)
		for i: int in range(4):
			var corners: Array[Vector2]=[Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]
			var a: Vector2=corners[i];var b: Vector2=corners[(i+1)%4]
			_quad(top+Vector3(a.x*.10,0,a.y*.075),low+Vector3(a.x*.039,0,a.y*.039),low+Vector3(b.x*.039,0,b.y*.039),top+Vector3(b.x*.10,0,b.y*.075))
		# Rectangular scupper flange at parapet face, open dark mouth is recess.
		for edge: float in [-1.0,1.0]:
			_box(Vector3(x+edge*.105,h+.045,-.148),Vector3(.018,.12,.018))
			_box(Vector3(x,h+.045+edge*.06,-.148),Vector3(.21,.018,.018))
		_quad(Vector3(x-.09,h-.006,-.14),Vector3(x+.09,h-.006,-.14),Vector3(x+.09,h-.006,-.265),Vector3(x-.09,h-.006,-.265))
		_downpipe(low,Vector3(x,0,-.19),h,Vector3.FORWARD)
	sections.append({"kind":"folded_coping_scupper_hoppers","roof_eave_m":h,"width_m":w})
