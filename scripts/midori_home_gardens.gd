extends RefCounted
## Authored planting masses beside the homes, using the neighbourhood's existing
## textured foliage. Build after both ground parcels, before static batching.
const Gardens = preload("res://scripts/midori_neighbourhood_gardens.gd")
const Ground = preload("res://scripts/midori_neighbourhood_ground.gd")
const Landscape = preload("res://scripts/midori_south_street_landscape.gd")
const TRIANGLE_BUDGET := 1800000

static func build(street: Node3D, context: Dictionary, lane: Dictionary, court: Dictionary, outer_gardens: Dictionary) -> Dictionary:
	if street.has_node("HomeGardenPlanting"):
		return street.get_node("HomeGardenPlanting").get_meta("home_gardens")
	var soils: Array[Rect2] = []
	var obstacles: Array[Dictionary] = Gardens._obstacles(context,lane)
	# Low shrubs can sit beneath the high eaves. Retain a real wall service gap,
	# rather than excluding the whole roof projection from every ground plant.
	for obstacle: Dictionary in obstacles:
		if obstacle.reason=="building_and_roof_clearance":
			obstacle.rect=(obstacle.rect as Rect2).grow(-.30)
			obstacle.reason="house_wall_service_gap"
	for parcel: Dictionary in [context,lane,court]:
		soils.append_array(parcel.get("soil_rectangles",[]))
	for key: String in ["paving_rectangles","pocket_rims"]:
		for rect: Rect2 in court.get(key,[]):
			obstacles.append({"rect":rect.grow(.18),"reason":"court_"+key})
	for rect: Rect2 in court.get("building_footprints",[]):
		obstacles.append({"rect":rect.grow(.30),"reason":"court_wall_service_gap"})
	# Retain the bench, outer enclosure and the two narrow court connections.
	obstacles.append({"rect":Rect2(-1.80,252.20,2.60,1.20),"reason":"bench_clearance"})
	obstacles.append({"rect":Rect2(-27.5,269.45,55,.55),"reason":"rear_screen"})
	for x: float in [-27.5,27.0]:
		obstacles.append({"rect":Rect2(x,242,.50,28),"reason":"side_screen"})
	var existing: Dictionary = Gardens._existing_plants(context.root,lane)
	for parcel: Dictionary in [court,outer_gardens]:
		for row: Dictionary in parcel.get("plants",[]):
			var p: Vector3 = row.position
			existing.roots.append(Vector2(p.x,p.z))
			if str(row.get("kind","")) == "tree": existing.trees.append(Vector2(p.x,p.z))
	# Keep the established flowering colonies visible above their low margins.
	# Taller new crowns stop outside each actual flower clump, not an invented bed.
	for parcel: Dictionary in [lane,court]:
		for row: Dictionary in parcel.get("plants",[]):
			if str(row.get("kind","")) in ["flowering_iris","flowering_azalea"]:
				var b: AABB=row.bounds
				obstacles.append({"rect":Rect2(b.position.x,b.position.z,b.size.x,b.size.z).grow(.05),"reason":"retained_flower_colony"})
	var sources: Array[Node3D] = [
		Landscape._prototype(Landscape.TREE_PACK,Gardens.LOW_SOURCE),
		Landscape._prototype(Landscape.TREE_PACK,Gardens.LOW_SOURCE),
		Landscape._prototype(Landscape.TREE_PACK,Landscape.SHRUB_NAME),
		Landscape._prototype(Landscape.FERN,"")]
	Ground._leaf_finish(sources[0],false)
	Ground._leaf_finish(sources[1],true)
	Ground._leaf_finish(sources[2],false)
	var source_rows: Array[Dictionary] = []
	for i: int in range(sources.size()): source_rows.append(Gardens._measure_source(sources[i],i))
	var surfaces: Array[Dictionary] = Gardens._soil_surfaces(street)
	var beds: Array[Dictionary] = _beds()
	var candidates: Array[Array] = []
	var rounds := 0
	for bed: Dictionary in beds:
		var points: Array = Gardens._bed_candidates(bed)
		candidates.append(points)
		rounds=maxi(rounds,points.size())
	var root := Node3D.new()
	root.name="HomeGardenPlanting"
	root.set_meta("creator_protected",true)
	root.set_meta("creator_editable",false)
	street.add_child(root)
	var accepted: Array[Dictionary] = []
	var rejected: Dictionary = {}
	var buckets: Dictionary = {}
	var triangles := 0
	for round_index: int in range(rounds):
		for bed_index: int in range(beds.size()):
			if round_index>=candidates[bed_index].size():continue
			var spec: Dictionary=candidates[bed_index][round_index]
			var index: int=spec.source
			var cost: int=source_rows[index].triangles
			if not source_rows[index].ok or triangles+cost>TRIANGLE_BUDGET:continue
			var p: Vector3=spec.position
			var placement: Dictionary=Gardens._placement(sources[index],p,spec.height,spec.spread,spec.yaw)
			var box: AABB=placement.bounds
			var crown:=Rect2(box.position.x,box.position.z,box.size.x,box.size.z)
			var reason:=Gardens._clearance_reason(crown,soils,obstacles,existing)
			if reason.is_empty():
				for previous: Dictionary in accepted:
					if (previous.position as Vector3).distance_to(p)<.48:
						reason="new_root_spacing";break
			if not reason.is_empty():
				rejected[reason]=int(rejected.get(reason,0))+1;continue
			var support: Dictionary=Gardens._support_for(crown,surfaces)
			if not support.ok:
				rejected["missing_soil_support"]=int(rejected.get("missing_soil_support",0))+1;continue
			p.y=float(support.top_y)-.002
			placement=Gardens._placement(sources[index],p,spec.height,spec.spread,spec.yaw)
			box=placement.bounds
			# Complete shrubs include branch geometry below the leaf crown pivot.
			# Correct using the transformed rendered bounds, not that crown pivot.
			p.y+=float(support.top_y)-.002-box.position.y
			placement=Gardens._placement(sources[index],p,spec.height,spec.spread,spec.yaw)
			box=placement.bounds
			var row: Dictionary={"plant_id":accepted.size(),"bed":spec.bed,"source_index":index,
				"kind":spec.kind,"position":p,"height_m":spec.height,"spread_m":spec.spread,
				"bounds":box,"crown_rect":crown,"triangles":cost,"soil_top_y":support.top_y,
				"soil_contact_error_m":box.position.y-float(support.top_y),"ground_transform":placement.transform}
			accepted.append(row);triangles+=cost
			beds[bed_index]["accepted"]=int(beds[bed_index].get("accepted",0))+1
			var cell:=Vector2i(floori(p.x/Gardens.CELL_SIZE),floori(p.z/Gardens.CELL_SIZE))
			var key: String="%d_%d_%d"%[index,cell.x,cell.y]
			if not buckets.has(key):buckets[key]={"source_index":index,"cell":cell,"rows":[]}
			buckets[key].rows.append(row)
	var batches: Array[Dictionary]=Gardens._make_batches(root,sources,buckets)
	for source: Node3D in sources:
		if source!=null:source.free()
	var report: Dictionary={"ok":not accepted.is_empty(),"beds":beds,"plants":accepted,"plant_count":accepted.size(),
		"sources":source_rows,"batches":batches,"batch_count":batches.size(),"instanced_triangle_count":triangles,
		"triangle_budget":TRIANGLE_BUDGET,"rejected":rejected,"obstacles":obstacles,
		"new_collisions":0,"new_lights":0,"new_trees":0,"per_frame_scripts":0,
		"source_assets_modified":false,"soil_union_checked":true,"root_contact_embed_m":.002,
		"composition":"Connected low planting ribbons beside homes and court walks, with taller stemmed shrubs and small fern colonies. Existing iris and azalea groups remain visible.",
		"performance_note":"Static spatial MultiMeshes and 160m visibility distance; triangle cap is a construction limit, not an FPS claim."}
	root.set_meta("home_gardens",report)
	return report

static func _ribbon(id: String,a: Vector2,b: Vector2,width: float,layers: int,spacing: float,height: float,spread: float,source: int=0) -> Dictionary:
	return Gardens._bed(id,a,b,width,layers,spacing,height,spread,source)

static func _low_pocket(id: String,area: Rect2) -> Dictionary:
	var points: Array[Vector2]=[]
	var columns:=maxi(2,floori(area.size.x/.48))
	var rows:=maxi(2,floori(area.size.y/.48))
	for row: int in range(rows):
		for column: int in range(columns):
			var phase:=float(column)*1.7+float(row)*2.4
			points.append(area.position+Vector2(area.size.x*float(column)/float(columns-1)+.06*sin(phase),area.size.y*float(row)/float(rows-1)+.06*cos(phase)))
	return {"id":id,"source":1,"kind":"low_front_garden","points":points,"height":.32,"spread":.66}

static func _beds() -> Array[Dictionary]:
	return [
		_low_pocket("Sugi_front_low_layer",Rect2(-4.0,228.85,3.45,1.82)),
		_low_pocket("Nishi_left_front_low_layer",Rect2(-11.4,256.75,1.65,.43)),
		_low_pocket("Nishi_right_front_low_layer",Rect2(-6.2,256.75,1.7,.43)),
		_low_pocket("Higashi_porches_low_layer",Rect2(15.0,246.65,.70,1.95)),
		_low_pocket("Kado_entry_low_layer",Rect2(-15.45,246.65,.70,1.70)),
		_ribbon("Kobayashi_west_garden",Vector2(-24.0,229.6),Vector2(-24.0,240.5),2.5,3,1.10,.64,1.70,1),
		_ribbon("Kobayashi_east_walk",Vector2(-11.1,229.25),Vector2(-11.1,240.7),3.3,4,.79,.58,1.43),
		_ribbon("Sugi_sunken_front_garden",Vector2(-3.35,229.75),Vector2(-.85,229.75),.30,1,.82,.52,1.25,1),
		_ribbon("Sugi_east_walk",Vector2(3.80,229.3),Vector2(3.80,240.8),.0,1,.53,.52,.94,1),
		_ribbon("Sugi_rear_garden",Vector2(-3.3,241.0),Vector2(1.5,241.0),.1,1,.80,.55,1.28),
		_ribbon("Aoki_west_walk",Vector2(9.35,229.4),Vector2(9.35,240.6),.80,2,.78,.57,1.30,1),
		_ribbon("Aoki_east_garden",Vector2(23.0,229.8),Vector2(23.0,240.4),3.9,4,1.03,.66,1.78),
		_ribbon("Kado_residence_south",Vector2(-49.6,219.7),Vector2(-43.5,219.7),5.2,5,1.03,.67,1.72,1),
		_ribbon("Kado_residence_north",Vector2(-49.5,205.3),Vector2(-43.5,205.3),.65,2,.96,.65,1.62),
		_ribbon("East_home_lane_garden",Vector2(36.0,229.5),Vector2(36.0,240.4),4.0,4,1.00,.64,1.75,1),
		_ribbon("East_home_side_garden",Vector2(49.55,229.5),Vector2(49.55,240.3),1.05,2,.94,.63,1.66),
		_ribbon("East_home_rear_garden",Vector2(41.4,239.6),Vector2(47.6,239.6),1.00,2,.95,.62,1.65,1),
		_ribbon("Kado_workroom_arrival",Vector2(-24.4,243.6),Vector2(-14.75,243.6),.50,2,1.00,.58,1.48),
		_ribbon("Kado_workroom_path_north",Vector2(-14.75,246.1),Vector2(-14.75,248.3),.15,1,.80,.60,1.40,1),
		_ribbon("Kado_workroom_path_south",Vector2(-14.7,252.0),Vector2(-14.7,256.4),.15,1,.85,.66,1.48,1),
		_ribbon("Nishi_west_garden",Vector2(-18.3,257.0),Vector2(-18.3,267.7),6.3,6,1.05,.66,1.78),
		_ribbon("Nishi_front_west",Vector2(-11.4,257.0),Vector2(-10.3,257.0),.05,1,.85,.52,1.20,1),
		_ribbon("Nishi_front_east",Vector2(-6.1,257.0),Vector2(-5.0,257.0),.05,1,.85,.52,1.20,1),
		_ribbon("Nishi_gallery_garden",Vector2(-.55,258.0),Vector2(-.55,267.8),3.3,4,.96,.60,1.64,1),
		_ribbon("Higashi_arrival_garden",Vector2(15.6,246.4),Vector2(15.6,248.4),.1,1,.8,.59,1.30),
		_ribbon("Higashi_porch_garden",Vector2(15.5,252.0),Vector2(15.5,255.5),.10,1,.85,.63,1.45,1),
		_ribbon("Higashi_rear_garden",Vector2(20.5,257.0),Vector2(20.5,267.6),7.9,7,1.02,.65,1.76),
		_ribbon("Court_north_east_garden",Vector2(15.4,243.6),Vector2(24.5,243.6),.50,2,1.00,.57,1.48,1),
		{"id":"Home_stemmed_shrub_groups","source":2,"kind":"stemmed_shrub","points":[Vector2(-25.5,239.7),Vector2(-23.9,240.1),Vector2(-12.5,239.8),Vector2(24.8,239.7),Vector2(25.6,238.4),Vector2(37.3,239.8),Vector2(35.8,240.0),Vector2(49.7,239.6),Vector2(-24.8,266.8),Vector2(-23.4,267.3),Vector2(-15.4,266.6),Vector2(23.6,266.7),Vector2(25,267.1),Vector2(.7,267.9)],"height":1.08,"spread":1.58},
		{"id":"Shaded_fern_colonies","source":3,"kind":"fern","points":[Vector2(-13.1,234.6),Vector2(-12.5,235.2),Vector2(-12.9,235.9),Vector2(19.6,232.3),Vector2(20.2,232.8),Vector2(19.8,233.5),Vector2(-14.1,261.0),Vector2(-14.6,261.7),Vector2(-14.1,262.3),Vector2(14.7,262.0),Vector2(15.3,262.6),Vector2(14.9,263.2)],"height":.57,"spread":.95}
	]
