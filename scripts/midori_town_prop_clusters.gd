extends RefCounted
## Bounded aftermath groups, added after the street has finished its own batching.
## Every coordinate and measured dimension below is in world metres.
const Details = preload("res://scripts/midori_south_street_details.gd")
const CHAIR := "res://assets/shinrai/streets/midori_frontage_construction/mori_bentwood_chair.glb"
const CUP := "res://assets/shinrai/parks/midori_park/models/furniture/ambient/takeaway_cup/midori_takeaway_cup.glb"
const PAPER := "res://assets/shinrai/parks/midori_park/models/forest_floor_20261026/paper_00.glb"
const GLASS_PATCH := "res://assets/shinrai/vehicles/japanese_ev_delivery_2050/glass_shards.glb"
const STREET_LIGHT_LAYER := 1 << 10
const CONTACT_GAP := .003
const KERB_WALKING_STRIP := Rect2(-27.5,190.0,55.0,2.0)
const MORI_ENTRY := Rect2(7.05,192.0,1.90,2.0)
const CENTRAL_PASSAGE := Rect2(-3.0,192.0,6.0,13.0)
const CROSSING := Rect2(-2.0,183.0,4.0,7.0)

static func build(park: Node3D, street: Node3D, van_report: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {"ok":false,"node":"","clusters":[],"props":[],"rejections":[],"van_cluster_skipped":false,"new_lights":0,"per_frame_processing":false,"source_assets_modified":false,"existing_furniture_modified":false,"coordinates":"world_metres","reserved_kerb_walking_strip":KERB_WALKING_STRIP,"reserved_mori_entry":MORI_ENTRY,"tiny_props_have_collision":false,"glass_patch_count":0,"tyre_scuff_count":0,"new_crash_decor_count":0}
	if park == null or street == null or not park.is_inside_tree():
		report.rejections.append("Town prop producers are unavailable")
		return report
	if park.get_node_or_null("MidoriTownPropClusters") != null:
		report.rejections.append("MidoriTownPropClusters already exists; duplicate build refused")
		return report
	var street_materials: Dictionary = street.get("materials")
	for key: String in ["detail_wood","detail_darkwood","detail_paper","detail_sage","detail_rust","detail_blue","detail_cream"]:
		if not street_materials.has(key):
			report.rejections.append("Required existing street material is missing: "+key)
	if not report.rejections.is_empty(): return report
	var root := _world_root(park,"MidoriTownPropClusters")
	report.node = str(root.get_path())
	# These groups supplement the retained setting rather than moving its chairs.
	_cafe_group(root,park,report)
	_books_group(root,park,street,report)
	if van_report.get("ok",false):
		_delivery_group(root,park,street,van_report,report)
		_broken_glass_group(root,park,van_report,report)
		_tyre_scuffs(root,park,report)
	else:
		report.van_cluster_skipped = true
		report.van_cluster_skip_reason = "No accepted installed van; no detached delivery debris is invented"
	var accepted_bounds: Array[AABB] = []
	for row: Dictionary in report.props: accepted_bounds.append(row.world_bounds)
	report.world_bounds = accepted_bounds
	report.local_route_reservations = {"west_walk":Rect2(-40.5,182,2,46),"main_road_clear_corridor":Rect2(-38.5,186.0,11.0,4.0)}
	var rearward_z := float(van_report.get("world_bounds",AABB()).end.z) if van_report.get("world_bounds") is AABB else 183.0
	for prop: Dictionary in report.props:
		if prop.get("zone","")=="delivery":rearward_z=maxf(rearward_z,(prop.world_bounds as AABB).end.z)
	report.combined_main_road_clear_m = 190.0-rearward_z
	report.ok = report.rejections.is_empty()
	root.set_meta("town_prop_report",report)
	return report

static func _world_root(parent: Node3D, label: String) -> Node3D:
	var root := Node3D.new()
	root.name = label
	parent.add_child(root)
	root.set_as_top_level(true)
	root.global_transform = Transform3D.IDENTITY
	_protect(root)
	return root

static func _protect(node: Node3D) -> void:
	node.set_meta("creator_protected",true)
	node.set_meta("creator_editable",false)
	node.set_meta("creator_object_kind","aftermath_prop")

static func _holder(parent: Node3D, label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	_protect(node)
	return node

static func _cafe_group(root: Node3D, park: Node3D, report: Dictionary) -> void:
	var cluster := _holder(root,"MoriInterruptedOutdoorSetting")
	var start: int = report.props.size()
	var chair := _asset(cluster,CHAIR,"FallenBentwoodChair",.80,1,report)
	if chair != null:
		# Behind the western setting: (6.4,192.5) intersects its retained right chair.
		chair.basis = Basis(Vector3.UP,.12)*Basis(Vector3.BACK,PI*.5)
		_finish_prop(chair,park,Vector2(6.45,193.48),"cafe",true,report,CHAIR)
	var cup := _asset(cluster,CUP,"SpilledTakeawayCup",.12,1,report)
	if cup != null:
		cup.basis = Basis(Vector3.UP,-.65)*Basis(Vector3.RIGHT,PI*.5)
		_finish_prop(cup,park,Vector2(6.72,192.37),"cafe",false,report,CUP)
	var paper := _asset(cluster,PAPER,"LooseCafeReceipt",.21,3,report)
	if paper != null:
		paper.basis = Basis(Vector3.UP,.61)
		_finish_prop(paper,park,Vector2(6.73,192.71),"cafe",false,report,PAPER)
	_record_cluster(cluster,"MoriCoffee",start,report)

static func _books_group(root: Node3D, park: Node3D, street: Node3D, report: Dictionary) -> void:
	var cluster := _holder(root,"UedaDislodgedBrowseBooks")
	var start: int = report.props.size()
	for index: int in range(2):
		var volume := _holder(cluster,"FallenBoundBook_%02d"%index)
		# Reuse the actual rounded covers, page block and printed Ueda design.
		Details._face_book(street,volume,Vector3.ZERO,.29,.34,index+1)
		# The helper's -0.15-radian display lean is baked into its children.
		# Cancel it and put the printed front (-Z) uppermost on the pavement.
		volume.basis = Basis(Vector3.UP,.26 if index == 0 else -.34)*Basis(Vector3.RIGHT,PI*.5+.15)
		_finish_prop(volume,park,Vector2(22.48+float(index)*.52,192.48),"books",false,report,"existing_ueda_rounded_book_helper")
	_record_cluster(cluster,"UedaBooks",start,report)

static func _delivery_group(root: Node3D, park: Node3D, street: Node3D, van_report: Dictionary, report: Dictionary) -> void:
	if not van_report.get("rear_point") is Vector3 or not van_report.get("rear_direction") is Vector3:
		report.rejections.append("Crash van report lacks native rear point and direction")
		return
	var rear: Vector3=van_report.rear_point
	var direction: Vector3=van_report.rear_direction
	var side: Vector3=van_report.roof_direction
	var cluster:=_holder(root,"InterruptedVanReturnCrates")
	var start: int=report.props.size()
	for index: int in range(2):
		var crate:=_holder(cluster,"EmptyReturnCrate_%02d"%index)
		Details._crate(street,crate,Vector3.ZERO,.63,2,true)
		crate.basis=Basis(Vector3.UP,atan2(direction.x,direction.z)+(.16 if index==0 else -.31))
		if index==1:crate.basis*=Basis(Vector3.BACK,-PI*.5)
		var at: Vector3=rear+direction*(.80 if index==0 else 1.65)+side*(.35 if index==0 else .55)
		var before: int=report.props.size()
		if _finish_prop(crate,park,Vector2(at.x,at.z),"delivery",true,report,"existing_empty_return_crate_helper"):
			# A world AABB includes empty space beside a diagonal vehicle. Use its
			# actual rear plane instead, and keep every crate vertex behind it.
			var clear:=true
			for point: Vector3 in _world_points(crate):
				if (point-rear).dot(direction)<.12:clear=false
			for row: Dictionary in report.props:
				if row.id==str(crate.name) or row.zone!="delivery":continue
				if (row.world_bounds as AABB).grow(.04).intersects(report.props[-1].world_bounds):clear=false
			if not clear:
				report.props.resize(before);_reject_prop(crate,"Return crate approaches the crash body or the other crate",report)
	_record_cluster(cluster,"VanRearDelivery",start,report)

static func _broken_glass_group(root: Node3D,park: Node3D,van_report: Dictionary,report: Dictionary) -> void:
	var cluster:=_holder(root,"BrokenWindscreenGroundGlass")
	var start: int=report.props.size()
	var patch:=_asset(cluster,GLASS_PATCH,"SparseGreenishGlassFragments",.44548,0,report)
	if patch!=null:
		var at: Vector3=van_report.front_point+van_report.nose_direction*.45+van_report.underside_direction*.32
		patch.basis=Basis(Vector3.UP,-.35)
		if _finish_prop(patch,park,Vector2(at.x,at.z),"crash_glass",false,report,GLASS_PATCH):
			report.glass_patch_count=1;report.new_crash_decor_count+=1
	_record_cluster(cluster,"CrashGlass",start,report)

static func _tyre_scuffs(root: Node3D,park: Node3D,report: Dictionary) -> void:
	var cluster:=_holder(root,"CrashApproachTyreScuffs")
	var start: int=report.props.size()
	var rubber:=StandardMaterial3D.new()
	rubber.resource_name="SubtleRecentTyreRubber"
	rubber.albedo_color=Color(.025,.029,.027,.38)
	rubber.roughness=.96;rubber.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	rubber.vertex_color_use_as_albedo=true;rubber.cull_mode=BaseMaterial3D.CULL_DISABLED
	for side: float in [-1.0,1.0]:
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vertices: Array[Vector3]=[]
		var colors: Array[Color]=[]
		var floor_samples: Array[Dictionary]=[]
		for row: int in range(33):
			var t: float=float(row)/32.0
			var inv: float=1.0-t
			var curve: Vector2=Vector2(-29.8,188.6)*inv*inv*inv+Vector2(-30.8,187.6)*3.0*inv*inv*t+Vector2(-32.3,185.4)*3.0*inv*t*t+Vector2(-33.55,184.45)*t*t*t
			var tangent: Vector2=(Vector2(-30.8,187.6)-Vector2(-29.8,188.6))*3.0*inv*inv+(Vector2(-32.3,185.4)-Vector2(-30.8,187.6))*6.0*inv*t+(Vector2(-33.55,184.45)-Vector2(-32.3,185.4))*3.0*t*t
			var cross_axis:=Vector2(-tangent.y,tangent.x).normalized()
			curve+=cross_axis*side*.79
			for col: int in range(5):
				var across: float=float(col)/4.0
				var wobble: float=.004*sin(t*73.0+side*2.0)
				var p: Vector2=curve+cross_axis*((across-.5)*(.15+.014*sin(t*39.0))+wobble)
				var ground: Dictionary=_road_hit(park,p)
				if ground.is_empty():
					cluster.free();report.rejections.append("Tyre scuff footprint left existing asphalt");return
				vertices.append(ground.position+Vector3.UP*.0025)
				var fade: float=smoothstep(0.0,.16,t)*(1.0-smoothstep(.86,1.0,t))
				var edge: float=sin(PI*across)
				var grain: float=.72+.18*sin(t*61.0+side*1.3)+.10*sin(t*127.0)
				colors.append(Color(1,1,1,fade*edge*grain))
				floor_samples.append({"position":ground.position,"collider":str(ground.collider.get_path())})
		for row: int in range(32):
			for col: int in range(4):
				var a: int=row*5+col
				for index: int in [a,a+5,a+1,a+1,a+5,a+6]:
					tool.set_normal(Vector3.UP);tool.set_color(colors[index]);tool.add_vertex(vertices[index])
		var visual:=MeshInstance3D.new();visual.name="FadedCurvedTyreScuffLeft" if side<0 else "FadedCurvedTyreScuffRight"
		visual.mesh=tool.commit();visual.material_override=rubber;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cluster.add_child(visual);_protect(visual);_assign_layers(visual)
		var bounds:=_bounds(_world_points(visual))
		report.props.append({"id":str(visual.name),"node":str(visual.get_path()),"zone":"tyre_scuff","source":"original_ground_conforming_static_mesh","world_bounds":bounds,"ground_height_m":.02,"support_samples":floor_samples,"support_gap_m":.0025,"collision":false,"collision_node":"","collision_point_count":0,"creator_protected":true})
		report.tyre_scuff_count+=1;report.new_crash_decor_count+=1
	_record_cluster(cluster,"CrashTyreScuffs",start,report)

static func _road_hit(park: Node3D,point: Vector2) -> Dictionary:
	# Only actual pre-existing asphalt; no markings across footpaths or soil.
	var on_main: bool=Rect2(-32.5,183,65,7).has_point(point)
	var on_side: bool=Rect2(-38.5,183,6,43.5).has_point(point)
	if not on_main and not on_side:return {}
	var query:=PhysicsRayQueryParameters3D.create(Vector3(point.x,.12,point.y),Vector3(point.x,-.10,point.y),1)
	var skipped: Array[RID]=[]
	for label: String in ["OverturnedDeliveryVan","MidoriTownPropClusters"]:
		var added: Node=park.get_node_or_null(NodePath(label))
		if added!=null:
			for body: CollisionObject3D in added.find_children("*","CollisionObject3D",true,false):skipped.append(body.get_rid())
	query.exclude=skipped
	var hit: Dictionary=park.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or absf(hit.position.y-.02)>.018 or hit.normal.y<.98:return {}
	return hit

static func _asset(parent: Node3D, path: String, label: String, target_size: float, measurement_axis: int, report: Dictionary) -> Node3D:
	if not ResourceLoader.exists(path):
		report.rejections.append("Required detailed prop asset is missing: "+path)
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		report.rejections.append("Prop asset is not a PackedScene: "+path)
		return null
	var holder := _holder(parent,label)
	var visual := scene.instantiate() as Node3D
	if visual == null:
		report.rejections.append("Prop asset has no Node3D root: "+path)
		holder.free()
		return null
	holder.add_child(visual)
	_strip_imported_collision(visual)
	var points := _world_points(holder)
	if points.size() < 4:
		report.rejections.append("Prop asset has no measurable geometry: "+path)
		holder.free()
		return null
	var bounds := _bounds(points)
	if not bounds.position.is_finite() or not bounds.size.is_finite():
		report.rejections.append("Prop asset has non-finite geometry: "+path)
		holder.free()
		return null
	var extent: float = bounds.size[measurement_axis] if measurement_axis < 3 else maxf(bounds.size.x,bounds.size.z)
	if extent <= .00001 or not extent < 1000.0:
		report.rejections.append("Prop asset has invalid measured extent: "+path)
		holder.free()
		return null
	# Uniform normalisation only; materials, proportions and source files survive.
	var scale_factor: float = target_size/extent
	visual.scale *= scale_factor
	holder.set_meta("source_asset",path)
	holder.set_meta("source_dimensions",bounds.size)
	holder.set_meta("uniform_scale_factor",scale_factor)
	return holder

static func _strip_imported_collision(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CollisionObject3D or child is CollisionShape3D:
			node.remove_child(child)
			child.free()
		else:
			_strip_imported_collision(child)

static func _finish_prop(node: Node3D, park: Node3D, centre: Vector2, zone: String, collide: bool, report: Dictionary, source: String) -> bool:
	var points := _world_points(node)
	if points.size() < 4:
		return _reject_prop(node,"New prop has insufficient measured geometry",report)
	var bounds := _bounds(points)
	if not bounds.position.is_finite() or not bounds.size.is_finite():
		return _reject_prop(node,"New prop has non-finite measured geometry",report)
	var middle := bounds.get_center()
	node.global_position += Vector3(centre.x-middle.x,0,centre.y-middle.z)
	points = _world_points(node)
	bounds = _bounds(points)
	var errors := _route_errors(bounds,zone)
	if not errors.is_empty(): return _reject_prop(node," / ".join(errors),report)
	var support: Dictionary = _support_height(park,bounds)
	if not support.get("ok",false): return _reject_prop(node,str(support.get("reason","No physical prop support")),report)
	node.global_position.y += float(support.height)+CONTACT_GAP-bounds.position.y
	points = _world_points(node)
	bounds = _bounds(points)
	_assign_layers(node)
	var collision_node := ""
	var collision_points := 0
	if collide:
		var fitted: Dictionary = _convex_collision(node,points)
		collision_node = str(fitted.node)
		collision_points = int(fitted.point_count)
	var local_route_gap: float = bounds.position.z-192.0
	if zone=="delivery":local_route_gap=190.0-bounds.end.z
	elif zone=="crash_glass":local_route_gap=bounds.position.x+38.5
	report.props.append({"id":str(node.name),"node":str(node.get_path()),"zone":zone,"source":source,"world_bounds":bounds,"ground_height_m":support.height,"support_samples":support.samples,"support_gap_m":bounds.position.y-float(support.height),"collision":collide,"collision_node":collision_node,"collision_point_count":collision_points,"creator_protected":true,"uniform_scale_factor":node.get_meta("uniform_scale_factor",1.0),"source_dimensions":node.get_meta("source_dimensions",Vector3.ZERO),"minimum_kerb_strip_gap_m":local_route_gap,"local_route_gap_m":local_route_gap,"clear_road_width_m":190.0-bounds.end.z if zone == "delivery" else 7.0})
	return true

static func _reject_prop(node: Node3D, reason: String, report: Dictionary) -> bool:
	report.rejections.append(str(node.name)+": "+reason)
	node.get_parent().remove_child(node)
	node.free()
	return false

static func _route_errors(bounds: AABB, zone: String) -> PackedStringArray:
	var errors := PackedStringArray()
	var footprint := Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z)
	for reserved: Rect2 in [KERB_WALKING_STRIP,MORI_ENTRY,CENTRAL_PASSAGE,CROSSING]:
		if footprint.intersects(reserved): errors.append("Intersects reserved public route "+str(reserved))
	if zone == "delivery":
		if bounds.position.z<183.40 or bounds.end.z>185.80 or bounds.position.x< -35.0 or bounds.end.x> -30.80:
			errors.append("Delivery debris leaves the bounded junction rear approach")
	elif zone == "crash_glass":
		if bounds.position.x< -38.15 or bounds.end.x> -35.80 or bounds.position.z<180.25 or bounds.end.z>182.50:
			errors.append("Ground glass leaves the bounded crash nose apron")
	else:
		if bounds.position.z < 192.10 or bounds.end.z > 193.92: errors.append("Frontage prop leaves the rear sidewalk apron")
		if zone == "cafe":
			if bounds.end.x > 6.98 or bounds.position.x < 4.25: errors.append("Cafe prop approaches the entry or leaves its setting")
			# Retained western table and its right chair are genuine occupied space.
			for occupied: Rect2 in [Rect2(5.145,192.425,.71,.71),Rect2(5.90,192.55,.50,.52)]:
				if footprint.intersects(occupied): errors.append("Intersects retained cafe furniture")
		if zone == "books":
			if bounds.position.x < 21.50 or bounds.end.x > 23.55 or bounds.end.z > 192.85:
				errors.append("Fallen book approaches browse table or shop route")
	return errors

static func _support_height(park: Node3D, bounds: AABB) -> Dictionary:
	var x0: float = bounds.position.x+.008
	var x1: float = bounds.end.x-.008
	var z0: float = bounds.position.z+.008
	var z1: float = bounds.end.z-.008
	var centre := bounds.get_center()
	var samples: Array[Dictionary] = []
	var low := INF
	var high := -INF
	for point: Vector2 in [Vector2(centre.x,centre.z),Vector2(x0,z0),Vector2(x0,z1),Vector2(x1,z0),Vector2(x1,z1)]:
		# Stay below tables/chairs and above the actual road/sidewalk surface.
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x,.45,point.y),Vector3(point.x,-.50,point.y),1)
		var hit: Dictionary = park.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): return {"ok":false,"reason":"Physical ground ray missed at "+str(point)}
		var position: Vector3 = hit.position
		var normal: Vector3 = hit.normal
		if normal.y < .98 or position.y < -.04 or position.y > .18:
			return {"ok":false,"reason":"Support is not the level road/sidewalk floor at "+str(point)}
		low = minf(low,position.y)
		high = maxf(high,position.y)
		samples.append({"point":point,"height":position.y,"normal":normal,"collider":str(hit.collider.get_path())})
	if high-low > .012: return {"ok":false,"reason":"Prop footprint crosses an uneven support or curb"}
	return {"ok":true,"height":high,"samples":samples}

static func _world_points(root: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	_collect_points(root,points)
	return points

static func _collect_points(node: Node, points: PackedVector3Array) -> void:
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		if visual.mesh != null:
			for surface: int in range(visual.mesh.get_surface_count()):
				var arrays: Array = visual.mesh.surface_get_arrays(surface)
				if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] == null: continue
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for vertex: Vector3 in vertices: points.append(visual.to_global(vertex))
	for child: Node in node.get_children(): _collect_points(child,points)

static func _bounds(points: PackedVector3Array) -> AABB:
	var bounds := AABB(points[0],Vector3.ZERO)
	for point: Vector3 in points: bounds = bounds.expand(point)
	return bounds

static func _assign_layers(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers |= STREET_LIGHT_LAYER
	for child: Node in node.get_children(): _assign_layers(child)

static func _convex_collision(root: Node3D, world_points: PackedVector3Array) -> Dictionary:
	# Unique measured vertices, not an oversized axis-aligned collision box.
	var local_points := PackedVector3Array()
	var seen: Dictionary = {}
	for point: Vector3 in world_points:
		var local: Vector3 = root.to_local(point)
		var key := Vector3i(roundi(local.x*10000.0),roundi(local.y*10000.0),roundi(local.z*10000.0))
		if seen.has(key): continue
		seen[key] = true
		local_points.append(local)
	var body := StaticBody3D.new()
	body.name = "FittedPropCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "MeasuredConvexHull"
	var shape := ConvexPolygonShape3D.new()
	shape.points = local_points
	collision.shape = shape
	body.add_child(collision)
	return {"node":body.get_path(),"point_count":local_points.size()}

static func _record_cluster(root: Node3D, kind: String, start: int, report: Dictionary) -> void:
	var rows: Array = []
	for index: int in range(start,report.props.size()): rows.append(report.props[index].id)
	if rows.is_empty():
		root.get_parent().remove_child(root)
		root.free()
		return
	report.clusters.append({"id":kind,"node":str(root.get_path()),"props":rows,"added_prop_count":rows.size(),"existing_nodes_moved":0})
