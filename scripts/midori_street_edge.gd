extends RefCounted
## Original metre-scale visual construction. Call after Landscape, before batching.
## Existing foundations, curb/planter colliders and every plant transform survive.
static func build(street: Node3D) -> Dictionary:
	var ground: Node3D=street.get_node("StreetStructure")
	_finish_materials(street,ground)
	var removed:=0
	for node: Node in ground.get_children():
		if node is MeshInstance3D and _old_ground_strip(node as MeshInstance3D):
			node.free();removed+=1
	var curb_count:=0
	var gutter_count:=0
	var unit_bounds: Array[AABB]=[]
	# Match exact original29.5m runs; leave dropped crossing X[-3,3] untouched.
	for side: float in [-1.0,1.0]:
		var start: float=-32.5 if side<0 else 3.0
		for z: float in [182.93,190.07]:
			var toward_road: float=1.0 if z<187 else -1.0
			var count:=32;var pitch:=29.5/float(count)
			for i: int in range(count):
				var x: float=start+(float(i)+.5)*pitch
				var length: float=pitch-.004
				var profile:=PackedVector2Array([Vector2(-.07,0),Vector2(.07,0),Vector2(.07,.119),Vector2(.057,.132),Vector2(-.057,.132),Vector2(-.07,.119)])
				var mesh:=_extrude_x(profile,length)
				_add(street,ground,"ConstructedCurb_%d"%curb_count,mesh,Vector3(x,0,z),"land_curb")
				unit_bounds.append(AABB(Vector3(x-length*.5,0,z-.07),Vector3(length,.132,.14)))
				curb_count+=1
				# Dish-shaped modular roadside channel: shallow invert, raised lips.
				# Its curb-side lip meets the curb face (centre .07+.11 out), so no
				# asphalt sliver shows between curb and channel.
				var dish:=PackedVector2Array([Vector2(-.11,0),Vector2(.11,0),Vector2(.11,.012),Vector2(.08,.012),Vector2(0,.006),Vector2(-.08,.012),Vector2(-.11,.012)])
				_add(street,ground,"ConstructedGutter_%d"%gutter_count,_extrude_x(dish,length),Vector3(x,.016,z+toward_road*.18),"land_gutter")
				gutter_count+=1
				# Dark sealed joint between precast gutter units, flush with the lips.
				if i<count-1:
					_box(street,ground,"GutterJointSeal",Vector3(x+pitch*.5,.0215,z+toward_road*.18),Vector3(.005,.013,.22),"land_void")
	var planter_reports: Array[Dictionary]=[]
	for root: Node in street.get_children():
		if not root is Node3D or not str(root.name).begins_with("StorefrontTree"):continue
		var before: Dictionary={}
		for child: Node3D in root.find_children("*","Node3D",true,false):
			if not child is MeshInstance3D:before[str(child.get_path())]=child.global_transform
		# Remove visual shell only, not plant meshes or original physics bodies.
		for child: Node in root.get_children():
			if child is MeshInstance3D and _old_planter_piece(child as MeshInstance3D):child.free()
		var h:=.48
		for side: float in [-1.0,1.0]:
			# 45mm shell wall, inward-bevelled40mm projecting cap; actual empty top.
			_box(street,root,"PlanterThinSide",Vector3(side*.4275,h*.5,0),Vector3(.045,h,.90),"land_pot")
			_box(street,root,"PlanterThinEnd",Vector3(0,h*.5,side*.4275),Vector3(.81,h,.045),"land_pot")
			_add(street,root,"PlanterRimSide",_extrude_x(PackedVector2Array([Vector2(-.033,-.018),Vector2(.033,-.018),Vector2(.033,.013),Vector2(.025,.021),Vector2(-.025,.021),Vector2(-.033,.013)]),.90),Vector3(0,h,side*.421),"land_curb")
			var rim:=_add(street,root,"PlanterRimEnd",_extrude_x(PackedVector2Array([Vector2(-.033,-.018),Vector2(.033,-.018),Vector2(.033,.013),Vector2(.025,.021),Vector2(-.025,.021),Vector2(-.033,.013)]),.768),Vector3(side*.421,h,0),"land_curb")
			rim.rotation.y=PI*.5
		_box(street,root,"PlanterRecessedRootSoil",Vector3(0,.443,0),Vector3(.806,.024,.806),"land_soil")
		var unchanged:=true
		for path: String in before:
			var child: Node3D=street.get_tree().root.get_node_or_null(NodePath(path)) as Node3D
			if child==null or not child.global_transform.is_equal_approx(before[path]):unchanged=false
		root.set_meta("constructed_planter_shell",{"wall_m":.045,"soil_top_local_y":.455,"top_local_y":.501,"footprint_m":Vector2(.90,.90),"plant_transforms_unchanged":unchanged})
		planter_reports.append({"node":str(root.get_path()),"plant_transforms_unchanged":unchanged,"bounds":AABB(root.position-Vector3(.45,0,.45),Vector3(.9,.501,.9))})
	# One flush service cover in the broad park-side pavement, away from drains.
	var utility:=Vector3(4.5,.091,181.9)
	# Open surrounding frame: no hidden solid bed fills the lifting pockets.
	for edge: float in [-1.0,1.0]:
		_box(street,ground,"InspectionCoverFrameSide",utility+Vector3(edge*.308,-.009,0),Vector3(.024,.018,.64),"street_cover_frame")
		_box(street,ground,"InspectionCoverFrameEnd",utility+Vector3(0,-.009,edge*.308),Vector3(.592,.018,.024),"street_cover_frame")
	# Split solid lid around two real45x12mm lifting slots. No top decals.
	# Lid spansX/Z±.296; pockets X±.225, Z±.006,4mm plate thickness.
	for side: float in [-1.0,1.0]:
		_box(street,ground,"InspectionCoverLidBroad",utility+Vector3(0,0,side*.151),Vector3(.592,.004,.290),"street_cover_iron")
	for interval: Vector2 in [Vector2(-.296,-.2475),Vector2(-.2025,.2025),Vector2(.2475,.296)]:
		_box(street,ground,"InspectionCoverLidWeb",utility+Vector3((interval.x+interval.y)*.5,0,0),Vector3(interval.y-interval.x,.004,.012),"street_cover_iron")
	for side: float in [-1.0,1.0]:
		var pocket:=utility+Vector3(side*.225,-.0115,0)
		_box(street,ground,"InspectionPocketRecessFloor",pocket,Vector3(.045,.003,.012),"land_channel")
		for edge: float in [-1.0,1.0]:
			_box(street,ground,"InspectionPocketInnerSide",pocket+Vector3(0,.006,edge*.006),Vector3(.045,.012,.0015),"street_cover_iron")
			_box(street,ground,"InspectionPocketInnerEnd",pocket+Vector3(edge*.0225,.006,0),Vector3(.0015,.012,.012),"street_cover_iron")
	# Millimetre-relief cast traction ribs make the lid legible as a fitted
	# iron component. The lifting pockets remain genuinely open.
	var traction_ribs := 0
	for row: int in range(9):
		for col: int in range(9):
			var local := Vector3(-.224+float(col)*.056,.00275,-.224+float(row)*.056)
			if absf(local.z)<.018 and absf(absf(local.x)-.225)<.045: continue
			var rib := _add(street,ground,"CoverCastTractionRib",_traction_rib(),utility+local,"street_cover_iron")
			rib.rotation.y=PI*.25 if (row+col)%2==0 else -PI*.25
			traction_ribs+=1
	var fasteners := 0
	for x: float in [-.263,.263]:
		for z: float in [-.263,.263]:
			# Recessed collar with a flush hexagonal captive head.
			var collar := CylinderMesh.new()
			collar.top_radius=.009;collar.bottom_radius=.009;collar.height=.0015;collar.radial_segments=16
			_add(street,ground,"CoverFastenerRecess",collar,utility+Vector3(x,.00215,z),"land_channel")
			var head := CylinderMesh.new()
			head.top_radius=.0065;head.bottom_radius=.0065;head.height=.0018;head.radial_segments=6
			_add(street,ground,"CoverCaptiveHexHead",head,utility+Vector3(x,.00225,z),"street_cover_frame")
			fasteners+=1
	var report: Dictionary={"curb_units":curb_count,"gutter_units":gutter_count,"curb_pitch_m":29.5/32.0,"joint_m":.004,"curb_bounds":unit_bounds,"planters":planter_reports,"utility_covers":1,"visuals_removed":removed,"collision_changed":false,"crossing_clear_x":Vector2(-3,3),"shop_clear_strip_z":Vector2(192.05,193.50),"cover_footprint":Rect2(4.18,181.58,.64,.64),"cover_traction_ribs":traction_ribs,"cover_fasteners":fasteners,"cover_max_y":.0945,"cover_lifting_slots":[Rect2(4.2525,181.894,.045,.012),Rect2(4.7025,181.894,.045,.012)],"finish_policy":"Original sourced road maps; fitted cast iron lid; existing precast gutter source maps; crossing collision levels unchanged"}
	ground.set_meta("constructed_street_edge",report)
	return report

static func _traction_rib() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size=Vector3(.028,.0015,.005)
	return mesh

static func _finish_materials(street: Node3D,ground: Node3D) -> void:
	var mats: Dictionary=street.get("materials")
	for spec: Array in [["street_cover_iron",Color("#626660"),.85,.35],["street_cover_frame",Color("#74786f"),.75,.45]]:
		var iron := ShaderMaterial.new()
		iron.resource_name=String(spec[0])
		iron.shader=preload("res://scripts/midori_street_iron.gdshader")
		iron.set_shader_parameter("iron_color",spec[1])
		iron.set_shader_parameter("base_roughness",spec[2])
		iron.set_shader_parameter("metalness",spec[3])
		mats[spec[0]]=iron
	# Retain the original drain asset's sourced precast maps and physical
	# channel profile; reduce the uniform road-dirt tint on modular concrete.
	var old: Material=mats.land_gutter
	var gutter := old.duplicate() as ShaderMaterial
	if gutter!=null:
		gutter.resource_name="StreetModularPrecastGutter"
		gutter.set_shader_parameter("mineral_color",Color("#a09f93"))
		gutter.set_shader_parameter("road_weather",.35)
		mats.land_gutter=gutter
		for child: Node in ground.get_children():
			if child is MeshInstance3D and child.material_override==old: child.material_override=gutter

static func _same_piece(visual: MeshInstance3D,p: Vector3,size: Vector3) -> bool:
	if visual.mesh==null or not visual.position.is_equal_approx(p):return false
	return visual.mesh.get_aabb().size.is_equal_approx(size)

static func _old_ground_strip(visual: MeshInstance3D) -> bool:
	# Godot can auto-rename duplicate siblings; match exact producer geometry.
	for side: float in [-1.0,1.0]:
		for z: float in [182.93,190.07]:
			if _same_piece(visual,Vector3(side*17.75,.066,z),Vector3(29.5,.132,.14)):return true
		for z: float in [183.17,189.83]:
			if _same_piece(visual,Vector3(side*17.75,.022,z),Vector3(29.5,.012,.22)):return true
	return false

static func _old_planter_piece(visual: MeshInstance3D) -> bool:
	for side: float in [-1.0,1.0]:
		if _same_piece(visual,Vector3(side*.395,.24,0),Vector3(.11,.48,.90)):return true
		if _same_piece(visual,Vector3(0,.24,side*.395),Vector3(.68,.48,.11)):return true
	return _same_piece(visual,Vector3(0,.425,0),Vector3(.68,.05,.68))

static func _add(street: Node3D,parent: Node3D,label: String,mesh: Mesh,p: Vector3,key: String) -> MeshInstance3D:
	var visual:=MeshInstance3D.new();visual.name=label;visual.mesh=mesh;visual.position=p
	visual.material_override=street.get("materials")[key];parent.add_child(visual,true);return visual

static func _box(street: Node3D,parent: Node3D,label: String,p: Vector3,size: Vector3,key: String) -> void:
	var visual := street.call("_box",parent,label,p,size,key,false) as MeshInstance3D
	if not String(visual.name).begins_with(label):
		visual.name=label+"_"+str(visual.get_instance_id())

static func _extrude_x(profile: PackedVector2Array,length: float) -> ArrayMesh:
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(profile.size()):
		var a: Vector2=profile[i];var b: Vector2=profile[(i+1)%profile.size()]
		var p:=Vector3(-length*.5,a.y,a.x);var q:=Vector3(length*.5,a.y,a.x)
		var r:=Vector3(length*.5,b.y,b.x);var s:=Vector3(-length*.5,b.y,b.x)
		var normal: Vector3=(q-p).cross(r-p).normalized()
		for vertex: Vector3 in [p,r,q,p,s,r]:tool.set_normal(normal);tool.add_vertex(vertex)
	var polygon:=Geometry2D.triangulate_polygon(profile)
	for side: float in [-1.0,1.0]:
		for i: int in range(0,polygon.size(),3):
			var vertices: Array[Vector3]=[]
			for j: int in range(3):
				var point: Vector2=profile[polygon[i+j]]
				vertices.append(Vector3(side*length*.5,point.y,point.x))
			var desired:=Vector3(side,0,0)
			var cross_normal: Vector3=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
			# Godot front faces clockwise; cross-product points opposite supplied normal.
			if cross_normal.dot(desired)>0:vertices.reverse()
			for vertex: Vector3 in vertices:tool.set_normal(desired);tool.add_vertex(vertex)
	return tool.commit()
