extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")

# One metric composition, attached directly to the park root. Supplied assets
# remain unchanged; explicit world transform avoids the layout's doubled X/Z.
const BUILDING = preload("res://assets/shinrai/buildings/yakitori_shop/artwork_replica_v6/ProjectShinrai_YakitoriShop_ArtworkReplica_v6.tscn")
const VENDING = preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/neon_vending/vending_cyberpunk.tscn")
const FOUNTAIN = preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/drinking_fountain/fountain_satin.glb")
const TABLE = preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/picnic_2046/midori_picnic_table_2046.glb")
const BENCH = preload("res://assets/shinrai/parks/midori_park/models/furniture/vendor/futuristic_eco_bench/futuristic_eco_bench.glb")
const CUP = preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/takeaway_cup/midori_takeaway_cup.glb")
const RECYCLING = preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/recycling_station/recycling_cyberpunk.glb")
@export var world_anchor := Vector3(-126.0,0.112,-59.0)
var installed := false
var report: Dictionary = {}
var _lights: Array[Light3D] = []
var _night := false
var _parent_has_night := false
var _room_light: OmniLight3D
var _facade_lights: Array[SpotLight3D] = []
var _pitch_paving_footprint := PackedVector2Array()
var _grass_clear_done := false

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	call_deferred("install")

func install() -> void:
	if installed:
		return
	global_transform = Transform3D(Basis.IDENTITY,world_anchor)
	installed = true
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("#6e716b")
	stone.roughness = 0.92
	# Exterior uses the existing park terrain; no added apron or paving slab.
	var building := _asset(BUILDING,"SuppliedClubhouseShell",Vector3.ZERO)
	_readable_instance_finish(building)
	var threshold := building.find_child("SM_YakitoriShop_StoneThreshold",true,false) as MeshInstance3D
	if threshold != null and threshold.get_active_material(0) is StandardMaterial3D:
		var paving := threshold.get_active_material(0).duplicate() as StandardMaterial3D
		paving.albedo_texture = null
		paving.albedo_color = Color("#7b8078")
		paving.uv1_scale = Vector3(7,7,1)
		stone = paving
	# Extend only the supplied building plinth down to soil, within its footprint.
	_box("LoungePlinthToGround",Vector3(0,-global_position.y*.5,1.39),Vector3(4.55,global_position.y+.024,5.08),stone)
	_pitch_approach(stone)
	_trim_pitch_gate_intrusion()
	_extend_existing_canopy(building)
	_add_identity()
	# The V6 visible finish is above the older imported collision. Add matching
	# walking surfaces without deleting or rewriting the supplied shell collision.
	_collision(building,"VisibleInteriorFloor",Vector3(0,.225,1.50),Vector3(3.68,.045,4.08))
	_collision(building,"VisibleThresholdTop",Vector3(0,.194,-.91),Vector3(4.52,.018,.440))
	# Bridge the .15 m unfinished strip, overlapping both finishes by .01 m.
	# The sill meets the interior floor; its .0445 m outer step matches the rise.
	var sill_material: Material = threshold.get_active_material(0) if threshold != null else stone
	_box("EntrySill",Vector3(0,.22525,-.615),Vector3(1.2,.0445,.17),sill_material)
	_open_entry(building)
	_entry_ramp(stone)
	var indoor := _asset(TABLE,"IndoorCafeTable",Vector3(-.85,.2475,1.5))
	_collision(indoor,"TableTop",Vector3(0,.725,0),Vector3(1.5,.06,.84))
	for z: float in [-.65,.65]:
		_collision(indoor,"Seat",Vector3(0,.405,z),Vector3(1.5,.075,.35))
	var vending := _asset(VENDING,"CafeVending",_exterior_at(1.25,-1.60))
	_collision(vending,"VendingChassis",Vector3(0,.915,0),Vector3(.870,1.830,.669))
	# Visitor seating belongs on the west apron, clear of the entrance/canopy.
	# Keep this identity: the backpack adapter derives its two sites from it.
	var bench := _asset(BENCH,"ShelteredWaitingBench",_exterior_at(-3.70,-1.90),0.0,2.1)
	_collision(bench,"BenchBody",Vector3.ZERO,Vector3(1,.5117,.404))
	# Keep service fixtures against the east facade, outside the continuous
	# side route centred at X 4.6 from the rear exit to the front terrace.
	var fountain := _asset(FOUNTAIN,"DrinkingFountain",_exterior_at(3.15,-1.1),-PI*.5)
	_collision(fountain,"FountainPedestal",Vector3(0,.545,0),Vector3(.31,1.09,.31))
	var recycling := _asset(RECYCLING,"CafeRecycling",_exterior_at(3.0,2.25))
	_collision(recycling,"RecyclingShell",Vector3(0,.465,0),Vector3(.96,.93,.436))
	var tables: Array[Node3D] = []
	for spec: Array in [["TerraceTableWest",Vector3(-3.25,0,-4.6)],["TerraceTableEast",Vector3(2.8,0,-4.6)]]:
		var table := _asset(TABLE,spec[0],_exterior_at(spec[1].x,spec[1].z))
		tables.append(table)
		_collision(table,"TableTop",Vector3(0,.725,0),Vector3(1.5,.06,.84))
		for z: float in [-.65,.65]:
			_collision(table,"Seat",Vector3(0,.405,z),Vector3(1.5,.075,.35))
		for x: float in [-.49,.49]:
			for z: float in [-.42,.42]:
				_collision(table,"Leg",Vector3(x,.20,z),Vector3(.10,.4,.16))
	# Cup rests over a solid tabletop slat, away from the aisle and seat edges.
	_asset(CUP,"RecentlyUsedCup",_exterior_at(-3.55,-4.39)+Vector3(0,.755,0))
	# Warm local service lighting; no global environment/light settings changed.
	for x: float in [-1.2,1.2]:
		var light := OmniLight3D.new()
		light.position = Vector3(x,2.45,-2.15)
		light.light_color = Color("#ffe6bf")
		light.omni_range = 5.0
		light.shadow_enabled = true
		add_child(light)
		_lights.append(light)
	_room_light = OmniLight3D.new()
	_room_light.position = Vector3(0,2.18,1.55)
	_room_light.light_color = Color("#ffe3bd")
	_room_light.omni_range = 4.0
	_room_light.shadow_enabled = true
	add_child(_room_light)
	_single_storey_clubhouse(building,stone)
	for p: Dictionary in get_parent().get_property_list():
		_parent_has_night = _parent_has_night or p.name == "is_night_mode"
	set_night_mode(bool(get_parent().get("is_night_mode")) if _parent_has_night else false)
	var west := _bounds_in_module(tables[0])
	var east := _bounds_in_module(tables[1])
	report = {"world_anchor":str(global_position),"world_scale":str(global_basis.get_scale()),"building":str(_bounds_in_module(building)),"terrace_tables":2,"indoor_tables":1,"bench":6,"changing_room_benches":4,"hook_walls_per_changing_room":2,"vending":1,"fountain":1,"cup":1,"measured_table_gap_m":east.position.x-west.end.x,"pitch_gate_check":"pending installed review","storeys":1,"roof_height_m":3.04,"changing_rooms":2,"public_toilet":1,"corridor_width_m":1.8,"rear_exit_width_m":1.5,"toilet_fixtures":"Meshy ceramic toilet and wall-hung basin", "toilet_fixture_count":1, "basin_fixture_count":1}
	print("CLUBHOUSE_CAFETERIA: ",JSON.stringify(report))

func set_night_mode(enabled: bool) -> void:
	_night = enabled
	for light: Light3D in _lights:
		light.light_energy = 1.35 if enabled else .85
	if _room_light != null:
		_room_light.light_energy = 1.30 if enabled else 1.10
	for light: SpotLight3D in _facade_lights:
		light.light_energy = 1.6 if enabled else 1.2

func _single_storey_clubhouse(building: Node3D,stone: Material) -> void:
	# Work on this placed instance only. Preserve supplied scenes/GLBs and maps.
	var plaster := _room_material(building,"SM_YakitoriShop_ContinuousArtworkPlaster")
	var wood := _room_material(building,"SM_YakitoriShop_WoodFrames")
	var roof := _room_material(building,"SM_YakitoriShop_MatteRoofSurface")
	for mesh: Node in building.find_children("*","MeshInstance3D",true,false):
		var source := mesh as MeshInstance3D
		if not source.is_visible_in_tree() or source.mesh == null:
			continue
		var relative := global_transform.affine_inverse()*source.global_transform
		_subtract_instance_box(source,relative,[[1,2.90,1.0]])
		# Open the rear of the lounge to the new corridor, through every finish.
		_subtract_instance_box(source,relative,[[0,-.90,1.0],[0,.90,-1.0],[1,-.10,1.0],[1,2.48,-1.0],[2,3.30,1.0],[2,4.05,-1.0]])
	# Replace old fused/box collision with the edited visible shell. Hidden
	# placeholder geometry must never recreate an invisible second floor/wall.
	for shape: Node in building.find_children("*","CollisionShape3D",true,false):
		(shape as CollisionShape3D).disabled = true
	for mesh: Node in building.find_children("*","MeshInstance3D",true,false):
		var source := mesh as MeshInstance3D
		if source.is_visible_in_tree() and source.mesh != null and source.mesh.get_surface_count()>0:
			source.create_trimesh_collision()
	_box("LoungeFlatRoof",Vector3(0,2.96,1.55),Vector3(4.65,.16,4.75),roof)
	# A wider rear wing gives each changing room real bench/dressing clearance.
	_box("LoungeCorridorSill",Vector3(0,-.02625,3.7),Vector3(1.8,.5475,.8),stone)
	_box("TeamWingFloor",Vector3(0,-.02625,7.9),Vector3(8.0,.5475,8.1),stone)
	_box("TeamWingFlatRoof",Vector3(0,2.96,7.85),Vector3(8.35,.16,8.5),roof)
	_box("TeamWingCeiling",Vector3(0,2.855,7.9),Vector3(7.9,.04,8.1),plaster)
	for x: float in [-4.0,4.0]:
		_box("WingOuterWall",Vector3(x,1.56,7.9),Vector3(.18,2.625,8.3),plaster)
		_box("WingTimberBase",Vector3(x, .48,7.9),Vector3(.20,.40,8.3),wood)
	# Front shoulder walls close the wider wing against the retained lounge.
	for x: float in [-3.05,3.05]:
		_box("WingFrontReturn",Vector3(x,1.56,3.85),Vector3(1.9,2.625,.18),plaster)
	# Shared corridor: 1.8 m clear. Each side has two real door openings.
	for x: float in [-.98,.98]:
		for spec: Vector2 in [Vector2(4.075,.45),Vector2(6.375,1.65),Vector2(10.25,3.5)]:
			_box("CorridorPartition",Vector3(x,1.56,spec.x),Vector3(.16,2.625,spec.y),plaster)
		for z: float in [4.95,7.85]:
			_box("RoomDoorHeader",Vector3(x,2.64,z),Vector3(.16,.47,1.3),wood)
			for jamb: float in [z-.65,z+.65]:
				_box("RoomDoorJamb",Vector3(x,1.35,jamb),Vector3(.19,2.2,.055),wood)
	# West front bay is an open team waiting niche; east front is the separate WC.
	for x: float in [-2.53,2.53]:
		_box("ChangingRoomFrontWall",Vector3(x,1.56,7.15),Vector3(2.94,2.625,.15),plaster)
	# Rear exit: no door leaf across the route, 1.5 m clear and a flush sill.
	for x: float in [-2.42,2.42]:
		_box("RearExitWall",Vector3(x,1.56,12.0),Vector3(3.16,2.625,.18),plaster)
	_box("RearExitHeader",Vector3(0,2.64,12),Vector3(1.68,.47,.18),wood)
	_box("RearExitLanding",Vector3(0,.1975,12.55),Vector3(2,.10,1.1),stone)
	_sloped_walk("RearExitRamp",[Vector3(-1,.2475,13.1),Vector3(1,.2475,13.1),_exterior_at(1,15.0),_exterior_at(-1,15.0)],stone)
	# Sports changing furniture: 450 mm seat, empty mounted double hooks.
	# Each changing room has an L on outer/rear walls with flush seat edges.
	for x: float in [-3.55,3.55]:
		_sports_changing_bench("ChangingBenchWest" if x<0 else "ChangingBenchEast",Vector3(x,.2475,10.28),signf(x),wood)
		_sports_changing_bench("ChangingRearBenchWest" if x<0 else "ChangingRearBenchEast",Vector3(signf(x)*2.57,.2475,11.55),1.0,wood,2.4,-PI*.5)
		var marker := Marker3D.new()
		marker.name = "ClothesPlacementWest" if x<0 else "ClothesPlacementEast"
		marker.position = Vector3(x+signf(x)*.22,.2475+1.7,10.28)
		add_child(marker)
	_sports_changing_bench("TeamWaitingBench",Vector3(-3.55,.2475,5.4),-1.0,wood)
	# Real, measured derivatives of the preserved Meshy exports.
	_install_washroom_fixtures()
	_room_sign("Changing A",Vector3(-.875,2.14,7.85),PI*.5)
	_room_sign("Changing B",Vector3(.875,2.14,7.85),-PI*.5)
	_room_sign("PUBLIC WC",Vector3(.875,2.14,4.95),-PI*.5)
	_room_sign("REAR EXIT",Vector3(0,2.65,11.88),PI)
	_room_sign("LEISURE / CAFÉ",Vector3(0,2.55,3.98),0)
	for at: Vector3 in [Vector3(0,2.64,5),Vector3(0,2.64,9.5),Vector3(-2.5,2.64,9.5),Vector3(2.5,2.64,9.5),Vector3(2.5,2.64,5.4),Vector3(-2.5,2.64,5.4)]:
		var light := OmniLight3D.new()
		var source := building.find_child("SM_YakitoriShop_CanopyLightLenses",true,false) as MeshInstance3D
		_box("WingCeilingLight",at+Vector3(0,.19,0),Vector3(.5,.025,.18),source.get_active_material(0))
		light.position = at
		light.light_color = Color("#ffe9cf")
		light.omni_range = 3.5
		light.shadow_enabled = true
		add_child(light)
		_lights.append(light)
	# Clear vegetation only from the building and actual rear ramp/landing.
	for polygon: PackedVector2Array in [PackedVector2Array([Vector2(-4.2,3.6),Vector2(4.2,3.6),Vector2(4.2,12.1),Vector2(-4.2,12.1)]),PackedVector2Array([Vector2(-1.05,12.0),Vector2(1.05,12.0),Vector2(1.05,15.05),Vector2(-1.05,15.05)])]:
		var merged := Geometry2D.merge_polygons(_pitch_paving_footprint,polygon)
		if merged.size()==1:
			_pitch_paving_footprint = merged[0]
		else:
			_extra_grass_footprints.append(polygon)

var _extra_grass_footprints: Array[PackedVector2Array] = []

func _sports_changing_bench(node_name: String,at: Vector3,wall_side: float,timber_source: Material,length := 2.1,yaw := 0.0) -> void:
	# Metric bench: 2.10/2.40 m long, .44 m deep, .45 m seat height. Five rounded
	# timber slats on 32 mm steel frames; wall-mounted rail at 1.70 m.
	var bench := Node3D.new()
	bench.name = node_name
	bench.position = at
	bench.rotation.y = yaw
	add_child(bench)
	var wood := timber_source.duplicate() as StandardMaterial3D
	wood.resource_local_to_scene = true
	wood.resource_name = "ChangingBenchSuppliedTimber"
	wood.albedo_color = Color(1.0,.96,.87)
	wood.roughness = .63
	wood.metallic = 0.0
	wood.uv1_scale = Vector3(2.0,2.0,.45)
	var steel := StandardMaterial3D.new()
	steel.resource_name = "ChangingBenchPowderCoatedSteel"
	steel.albedo_color = Color(.12,.15,.15)
	steel.metallic = .6
	steel.roughness = .48
	var stainless := StandardMaterial3D.new()
	stainless.resource_name = "BrushedStainlessHooksAndFasteners"
	stainless.albedo_color = Color(.56,.59,.59)
	stainless.metallic = .88
	stainless.roughness = .34
	var timber := SurfaceTool.new();timber.begin(Mesh.PRIMITIVE_TRIANGLES)
	var frame := SurfaceTool.new();frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hardware := SurfaceTool.new();hardware.begin(Mesh.PRIMITIVE_TRIANGLES)
	var support_z := length*.5-.20
	for i: int in range(5):
		var x := -.18+float(i)*.09
		_sports_rounded_prism(timber,Vector3(x,.4275,0),Vector3(.08,.045,length),.005)
		for z: float in [-support_z,0,support_z]:
			_sports_tube(hardware,Vector3(x,.447,z),Vector3(x,.4505,z),.0035,10)
	for z: float in [-support_z,0,support_z]:
		_sports_rounded_prism(frame,Vector3(0,.385,z),Vector3(.39,.04,.04),.003)
		for x: float in [-.155,.155]:
			_sports_rounded_prism(frame,Vector3(x,.205,z),Vector3(.032,.37,.032),.003)
			_sports_rounded_prism(frame,Vector3(x,.01,z),Vector3(.052,.02,.052),.003)
			_collision(bench,"FrameLeg",Vector3(x,.205,z),Vector3(.032,.41,.032))
	for x: float in [-.14,.14]:
		_sports_rounded_prism(frame,Vector3(x,.36,0),Vector3(.032,.032,length-.18),.003)
	# Front/rear edges and every timber slat have small rounded arrises.
	_collision(bench,"SlattedSeat",Vector3(0,.4275,0),Vector3(.44,.045,length))
	# Back of rail touches the finished wall at +/-3.91 m; no floating board.
	_sports_rounded_prism(timber,Vector3(wall_side*.3425,1.70,0),Vector3(.035,.14,length),.004)
	for i: int in range(6):
		var z := -length*.5+.225+float(i)*(length-.45)/5.0
		var mount := wall_side*.321
		_sports_rounded_prism(hardware,Vector3(mount,1.70,z),Vector3(.008,.105,.045),.002)
		for y: float in [1.665,1.735]:
			_sports_tube(hardware,Vector3(mount-wall_side*.006,y,z),Vector3(mount-wall_side*.011,y,z),.0035,10)
		# Two rounded prongs per plate, lower and upper: no shirts are authored.
		for y: float in [1.675,1.725]:
			var start := Vector3(mount-wall_side*.006,y,z)
			var previous := start
			for step: int in range(1,9):
				var t := float(step)/8.0
				var point := start+Vector3(-wall_side*(.08*sin(t*PI*.5)),.045*t*t,0)
				_sports_tube(hardware,previous,point,.0045,10)
				previous = point
			var tip := SphereMesh.new();tip.radius=.006;tip.height=.012
			tip.radial_segments=12;tip.rings=6
			hardware.append_from(tip,0,Transform3D(Basis.IDENTITY,previous))
	for spec: Array in [["RoundedTimberSlatsAndRail",timber,wood],["SteelFrame",frame,steel],["MountedDoubleHooksAndFasteners",hardware,stainless]]:
		var mesh := MeshInstance3D.new()
		mesh.name = spec[0]
		(spec[1] as SurfaceTool).generate_tangents()
		mesh.mesh = (spec[1] as SurfaceTool).commit()
		mesh.material_override = spec[2]
		bench.add_child(mesh)
	bench.set_meta("sports_furniture",{"length_m":length,"depth_m":.44,"seat_height_m":.45,"rail_height_m":1.7,"double_hook_plates":6,"hook_prongs":12,"shirts":0,"wall_side":wall_side})

func _sports_tube(surface: SurfaceTool,a: Vector3,b: Vector3,radius: float,sides: int) -> void:
	var tube := CylinderMesh.new()
	tube.top_radius=radius;tube.bottom_radius=radius;tube.height=a.distance_to(b)
	tube.radial_segments=sides;tube.rings=0
	surface.append_from(tube,0,Transform3D(Basis(Quaternion(Vector3.UP,(b-a).normalized())),(a+b)*.5))

func _sports_rounded_prism(surface: SurfaceTool,at: Vector3,size: Vector3,radius: float) -> void:
	# Eight-sided cross section bevels all long arrises; end caps share edges.
	var x := size.x*.5;var y := size.y*.5;var z := size.z*.5
	var r := minf(radius,minf(x,y)*.8)
	var ring := PackedVector2Array([Vector2(-x+r,-y),Vector2(x-r,-y),Vector2(x,-y+r),Vector2(x,y-r),Vector2(x-r,y),Vector2(-x+r,y),Vector2(-x,y-r),Vector2(-x,-y+r)])
	for i: int in range(8):
		var j := (i+1)%8
		var a := at+Vector3(ring[i].x,ring[i].y,-z)
		var b := at+Vector3(ring[j].x,ring[j].y,-z)
		var c := at+Vector3(ring[j].x,ring[j].y,z)
		var d := at+Vector3(ring[i].x,ring[i].y,z)
		_sports_triangle(surface,a,c,b);_sports_triangle(surface,a,d,c)
		_sports_triangle(surface,at+Vector3(0,0,-z),a,b)
		_sports_triangle(surface,at+Vector3(0,0,z),c,d)

func _sports_triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	# Godot front faces are clockwise, opposite the mathematical cross product.
	var normal := -(b-a).cross(c-a).normalized()
	for vertex: Vector3 in [a,b,c]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(vertex.z,vertex.x+vertex.y))
		surface.add_vertex(vertex)

func _room_material(building: Node3D,mesh_name: String) -> Material:
	var mesh := building.find_child(mesh_name,true,false) as MeshInstance3D
	var material := mesh.get_active_material(0).duplicate() as StandardMaterial3D
	material.resource_local_to_scene = true
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE*.5
	material.emission_enabled = false
	return material

func _room_sign(caption: String,at: Vector3,yaw: float) -> void:
	var label := Label3D.new()
	label.text = caption
	label.font_size = 42
	label.pixel_size = .0025
	label.outline_size = 0
	label.modulate = Color("#eee6d7")
	label.position = at
	label.rotation.y = yaw
	add_child(label)

func _readable_instance_finish(building: Node3D) -> void:
	# V6's presentation tint multiplies the authored maps a second time. Restore
	# neutral reflectance on this cafe instance; keep all texture/normal/ORM maps.
	for mesh: Node in building.find_children("*","MeshInstance3D",true,false):
		var source: Material = mesh.get_active_material(0)
		if not source is StandardMaterial3D or "LightLenses" in str(mesh.name):
			continue
		var material := source.duplicate() as StandardMaterial3D
		material.resource_local_to_scene = true
		if material.albedo_texture != null:
			var texture_path := material.albedo_texture.resource_path
			if "Wood" in texture_path:
				material.albedo_color = Color(.95,.90,.83)
			elif "Plaster" in texture_path:
				material.albedo_color = Color(.90,.88,.83)
			elif "Stone" in texture_path:
				material.albedo_color = Color(.85,.83,.78)
		elif "Wall" in str(mesh.name) or "Ceiling" in str(mesh.name) or "InteriorPlaceholder" in str(mesh.name):
			material.albedo_color = Color(.62,.56,.47)
			material.emission_enabled = false
		elif material.metallic > .5:
			material.albedo_color = Color(.16,.17,.17)
		mesh.material_override = material

func _pitch_approach(material: Material) -> void:
	# Keep the compact gate access; the approach now uses normal park terrain.
	# The gate shoulders fill the aperture, while the central proven 1.8 m
	# collision ramp and its sampled profile stay exactly as before.
	_sloped_walk("PitchGateRamp",[Vector3(-14.9,.038,-16.70),Vector3(-13.1,.038,-16.70),Vector3(-13.1,-.109,-15.15),Vector3(-14.9,-.109,-15.15)],material)
	_sloped_walk("GateShoulderWest",[Vector3(-15.32,.038,-16.70),Vector3(-14.9,.038,-16.70),Vector3(-14.9,-.109,-15.15),Vector3(-15.32,-.109,-15.15)],material)
	_sloped_walk("GateShoulderEast",[Vector3(-13.1,.038,-16.70),Vector3(-12.68,.038,-16.70),Vector3(-12.68,-.109,-15.15),Vector3(-13.1,-.109,-15.15)],material)
	var top_pad := PackedVector2Array([Vector2(-15.32,-17.4),Vector2(-12.68,-17.4),Vector2(-12.68,-16.7),Vector2(-15.32,-16.7)])
	_paved_polygon("PitchGateLanding",top_pad,.0385,material)
	# One local footprint for grass exclusion, limited to this approach only.
	_pitch_paving_footprint = PackedVector2Array([Vector2(-15.32,-17.4),Vector2(-12.68,-17.4),Vector2(-12.68,-15.14),Vector2(-15.32,-15.14)])

func _paved_polygon(node_name: String,polygon: PackedVector2Array,height: float,material: Material) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	var points: Array = []
	for p: Vector2 in polygon:
		points.append(Vector3(p.x,height,p.y))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(0,indices.size(),3):
		var a: Vector3 = points[indices[i]]
		var b: Vector3 = points[indices[i+1]]
		var c: Vector3 = points[indices[i+2]]
		if (b-a).cross(c-a).y > 0:
			var swap := b
			b = c
			c = swap
		for p: Vector3 in [a,b,c]:
			surface.set_uv(Vector2(p.x,p.z))
			surface.add_vertex(p)
	_finish_walk(node_name,surface,points,material)

func _sloped_walk(node_name: String,points: Array,material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in [0,1,2,0,2,3]:
		surface.set_uv(Vector2(points[index].x,points[index].z))
		surface.add_vertex(points[index])
	_finish_walk(node_name,surface,points,material)

func _finish_walk(node_name: String,surface: SurfaceTool,points: Array,material: Material) -> void:
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = surface.commit()
	mesh.material_override = material
	add_child(mesh)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = mesh.mesh.create_trimesh_shape()
	body.add_child(collision)
	mesh.add_child(body)
	# Close visible vertical edges to below the soil; no additional collision.
	var skirt := SurfaceTool.new()
	skirt.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(points.size()):
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i+1)%points.size()]
		for p: Vector3 in [a,Vector3(a.x,-.20,a.z),b,b,Vector3(a.x,-.20,a.z),Vector3(b.x,-.20,b.z)]:
			skirt.set_uv(Vector2(p.x,p.z))
			skirt.add_vertex(p)
	skirt.generate_normals()
	var edge := MeshInstance3D.new()
	edge.mesh = skirt.commit()
	edge.material_override = material
	mesh.add_child(edge)

func _clear_pitch_link_grass(detail: Node) -> void:
	var cleared := 0
	var batches := 0
	for node: Node in detail.find_children("*","MultiMeshInstance3D",true,false):
		var batch := node as MultiMeshInstance3D
		var mm := batch.multimesh
		if mm == null or mm.mesh == null:
			continue
		var kept: Array[int] = []
		var removed := 0
		for index: int in range(mm.instance_count):
			var relative := global_transform.affine_inverse()*batch.global_transform*mm.get_instance_transform(index)
			var bounds: AABB = relative*mm.mesh.get_aabb()
			var rect := Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(.04)
			var footprint := PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)])
			var overlaps := not Geometry2D.intersect_polygons(footprint,_pitch_paving_footprint).is_empty()
			for extra: PackedVector2Array in _extra_grass_footprints:
				overlaps = overlaps or not Geometry2D.intersect_polygons(footprint,extra).is_empty()
			if overlaps:
				removed += 1
			else:
				kept.append(index)
		if removed == 0:
			continue
		var filtered := mm.duplicate() as MultiMesh
		filtered.instance_count = kept.size()
		for index: int in range(kept.size()):
			filtered.set_instance_transform(index,mm.get_instance_transform(kept[index]))
			if mm.use_colors:
				filtered.set_instance_color(index,mm.get_instance_color(kept[index]))
			if mm.use_custom_data:
				filtered.set_instance_custom_data(index,mm.get_instance_custom_data(kept[index]))
		batch.multimesh = filtered
		cleared += removed
		batches += 1
	_grass_clear_done = true
	report["pitch_link_grass_tufts_removed"] = cleared
	report["pitch_link_grass_batches_changed"] = batches
	print("CAFE_PITCH_PAVING_GRASS: removed=",cleared," batches=",batches," individual footprint intersections only; other planting unchanged")

func _process(_delta: float) -> void:
	if installed and not _grass_clear_done:
		var detail := get_parent().get_node_or_null("MidoriGrassDetail")
		if detail != null and detail.has_meta("thin_grass_count"):
			_clear_pitch_link_grass(detail)
	if installed and _parent_has_night:
		var enabled := bool(get_parent().get("is_night_mode"))
		if enabled != _night:
			set_night_mode(enabled)

func _asset(scene: PackedScene,node_name: String,at: Vector3,yaw := 0.0,size := 1.0) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.name = node_name
	add_child(node)
	node.position = at
	node.rotation.y = yaw
	node.scale = Vector3.ONE*size
	var bounds := _bounds_in_module(node)
	node.position.y += at.y-bounds.position.y
	return node

func _add_identity() -> void:
	var sign := StandardMaterial3D.new()
	sign.albedo_color = Color("#293b38")
	sign.roughness = .8
	_box("ClubhouseCafeSign",Vector3(0,2.78,-2.84),Vector3(3.9,.30,.065),sign)
	var text := Label3D.new()
	text.name = "JapaneseCafeIdentity"
	text.text = "クラブハウス  /  カフェ"
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Yu Gothic","Meiryo","Noto Sans CJK JP"])
	text.font = font
	text.font_size = 64
	text.pixel_size = .0023
	text.modulate = Color("#e0e2d7")
	text.outline_size = 0
	text.no_depth_test = false
	text.position = Vector3(0,2.83,-2.88)
	text.rotation.y = PI
	add_child(text)
	var subtitle := Label3D.new()
	subtitle.name = "CafeSubtitle"
	subtitle.text = "MIDORI SPORTS  ·  CLUBHOUSE CAFÉ"
	subtitle.font_size = 48
	subtitle.pixel_size = .0018
	subtitle.outline_size = 0
	subtitle.modulate = Color("#c5d1c6")
	subtitle.position = Vector3(0,2.70,-2.88)
	subtitle.rotation.y = PI
	add_child(subtitle)

func _open_entry(building: Node3D) -> void:
	for node_name: String in ["SM_YakitoriShop_GlazingPlaceholder","SM_YakitoriShop_WoodFrames","SM_YakitoriShop_ExteriorWoodMain"]:
		var source := building.find_child(node_name,true,false) as MeshInstance3D
		if source == null:
			continue
		var relative := building.global_transform.affine_inverse()*source.global_transform
		_subtract_instance_box(source,relative,[[0,-.60,1.0],[0,.60,-1.0],[1,.205,1.0],[1,2.30,-1.0],[2,-.50,-1.0]])
	for pull: Node in building.find_children("DoorPull*","MeshInstance3D",true,false):
		(pull as MeshInstance3D).hide()

func _trim_pitch_gate_intrusion() -> void:
	# The supplied pitch skirt has a pointed stone face inside the real gate.
	# Clip only its intrusion above the landing, on the placed render instance.
	# The original GLB, turf outside this tiny aperture and collision stay intact.
	var pitch := get_parent().find_child("ACT03_FiveASideFootballPitch",true,false)
	if pitch == null:
		return
	for node: Node in pitch.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		var relative := global_transform.affine_inverse()*mesh.global_transform
		# A 5 mm cut allowance keeps reconstructed/quantized boundary fragments
		# outside the visible aperture. It stays within the 2.7 m fence opening.
		_subtract_instance_box(mesh,relative,[[0,-15.325,1.0],[0,-12.675,-1.0],[1,.0336,1.0],[1,1.005,-1.0],[2,-17.405,1.0],[2,-15.145,-1.0]])

func _subtract_instance_box(source: MeshInstance3D,relative: Transform3D,planes: Array) -> void:
	var opened := ArrayMesh.new()
	for s: int in range(source.mesh.get_surface_count()):
		var arrays := source.mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index: int in range(vertices.size()):
				indices.append(index)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var emitted := 0
		for i: int in range(0,indices.size(),3):
			var inside: Array = []
			for j: int in range(3):
				var index := indices[i+j]
				inside.append({"v":vertices[index],"p":relative*vertices[index],"n":normals[index],"uv":uvs[index] if not uvs.is_empty() else Vector2.ZERO})
			for plane: Array in planes:
				if inside.is_empty():
					break
				var split := _split_entry_polygon(inside,plane[0],plane[1],plane[2])
				var outside: Array = split[1]
				for j: int in range(1,outside.size()-1):
					for vertex: Dictionary in [outside[0],outside[j],outside[j+1]]:
						surface.set_normal(vertex.n)
						surface.set_uv(vertex.uv)
						surface.add_vertex(vertex.v)
						emitted += 1
				inside = split[0]
		if emitted == 0:
			continue
		if not uvs.is_empty():
			surface.generate_tangents()
		surface.commit(opened)
		opened.surface_set_material(opened.get_surface_count()-1,source.get_active_material(s))
	source.mesh = opened

func _split_entry_polygon(polygon: Array,axis: int,limit: float,sign_value: float) -> Array:
	var inside: Array = []
	var outside: Array = []
	for i: int in range(polygon.size()):
		var a: Dictionary = polygon[i]
		var b: Dictionary = polygon[(i+1)%polygon.size()]
		var da: float = sign_value*(a.p[axis]-limit)
		var db: float = sign_value*(b.p[axis]-limit)
		if da >= 0:
			inside.append(a)
		else:
			outside.append(a)
		if (da >= 0) != (db >= 0):
			var t := da/(da-db)
			var cut := {"v":a.v.lerp(b.v,t),"p":a.p.lerp(b.p,t),"n":a.n.lerp(b.n,t).normalized(),"uv":a.uv.lerp(b.uv,t)}
			inside.append(cut)
			outside.append(cut)
	return [inside,outside]

func _entry_ramp(material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [_exterior_at(-.60,-2.65),_exterior_at(.60,-2.65),Vector3(.60,.203,-1.13),Vector3(-.60,.203,-1.13)]
	for index: int in [0,1,2,0,2,3]:
		surface.set_uv(Vector2(points[index].x,points[index].z))
		surface.add_vertex(points[index])
	surface.generate_normals()
	var ramp := MeshInstance3D.new()
	ramp.name = "EntryRamp"
	ramp.mesh = surface.commit()
	ramp.material_override = material
	add_child(ramp)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = ramp.mesh.create_trimesh_shape()
	body.add_child(collision)
	ramp.add_child(body)

func _extend_existing_canopy(building: Node3D) -> void:
	var source := building.find_child("SM_YakitoriShop_CanopyEaveWood",true,false) as MeshInstance3D
	if source == null:
		push_warning("Cafeteria supplied canopy missing")
		return
	# Reassemble two supplied canopy bays at their authored metre scale. Small
	# overlaps prevent cracks; front posts carry the extended terrace roof.
	for forward: float in [.68,1.36]:
		var bay := source.duplicate() as MeshInstance3D
		# This imported group also contains upper-storey timber. Reuse only its
		# actual lower canopy faces, preserving all original vertex/material data.
		var canopy := ArrayMesh.new()
		var to_module := global_transform.affine_inverse()*source.global_transform
		for surface: int in range(source.mesh.get_surface_count()):
			var arrays := source.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var selected := PackedInt32Array()
			for i: int in range(0,indices.size(),3):
				var a := (to_module*vertices[indices[i]]).y
				var b := (to_module*vertices[indices[i+1]]).y
				var c := (to_module*vertices[indices[i+2]]).y
				if maxf(a,maxf(b,c)) < 3.15 and minf(a,minf(b,c)) > 2.15:
					selected.append_array(PackedInt32Array([indices[i],indices[i+1],indices[i+2]]))
			if selected.is_empty():
				continue
			arrays[Mesh.ARRAY_INDEX] = selected
			canopy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			canopy.surface_set_material(canopy.get_surface_count()-1,source.get_active_material(surface))
		bay.mesh = canopy
		bay.name = "ReusedCanopyBay"
		add_child(bay)
		bay.global_transform = source.global_transform
		bay.position.z -= forward
	var post_material := StandardMaterial3D.new()
	post_material.albedo_color = Color("#3b403e")
	post_material.metallic = .55
	post_material.roughness = .65
	for x: float in [-2.15,2.15]:
		var floor_y := _exterior_at(x,-2.58).y
		_box("CanopySupport",Vector3(x,(2.62+floor_y)*.5,-2.58),Vector3(.10,2.62-floor_y,.10),post_material)

func exterior_floor_height_at(world_point: Vector3) -> float:
	var terrain := get_parent().get_node_or_null("MidoriTerrain")
	if terrain != null and bool(terrain.get("installed")):
		return float(terrain.call("height_at",Vector2(world_point.x,world_point.z)))
	# The clubhouse's reserved activity terrain is at the park's zero datum.
	return 0.0

func _exterior_at(x: float,z: float) -> Vector3:
	var world := to_global(Vector3(x,0,z))
	return Vector3(x,exterior_floor_height_at(world)-global_position.y,z)

func _bounds_in_module(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: Node in node.find_children("*","MeshInstance3D",true,false):
		if not (mesh as MeshInstance3D).is_visible_in_tree() or mesh.mesh.get_surface_count()==0:
			continue
		var relative := global_transform.affine_inverse()*(mesh as MeshInstance3D).global_transform
		var part := relative*(mesh as MeshInstance3D).get_aabb()
		bounds = part if first else bounds.merge(part)
		first = false
	return bounds

func _collision(parent: Node3D,node_name: String,at: Vector3,size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = at
	body.add_child(collider)
	parent.add_child(body)

func _box(node_name: String,at: Vector3,size: Vector3,material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
	_collision(self,node_name+"Collision",at,size)


func _install_washroom_fixtures() -> void:
	var assets := str(get_meta("washroom_asset_root", "res://assets/shinrai/buildings/clubhouse_washroom"))
	var toilet := _washroom_asset(assets.path_join("toilet/midori_toilet_lod0.glb"), "PublicToiletFixture", Vector3(3.49,.2475,6.30))
	if toilet != null:
		# One convex solid follows this closed fixture's actual silhouette.
		for mesh: MeshInstance3D in toilet.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh == null: continue
			var body := StaticBody3D.new()
			body.name = "ToiletCollision"
			body.collision_layer = 1
			body.collision_mask = 0
			var shape := CollisionShape3D.new()
			shape.shape = mesh.mesh.create_convex_shape()
			body.add_child(shape)
			mesh.add_child(body)
	# Bowl rear is 20 mm from the wall; the pipe flange reaches into the wall.
	# The measured front rim is .425 m above the GLB's lowest pipe vertex.
	var basin := _washroom_asset(assets.path_join("basin/midori_basin_lod0.glb"), "PublicWashbasinFixture", Vector3(3.71,.6725,4.40))
	if basin != null:
		# Separate bowl and trap collision leaves the space beneath the bowl open.
		_collision(basin,"BasinBowlCollision",Vector3(0,.375,.033),Vector3(.53,.15,.42))
		_collision(basin,"BasinTrapCollision",Vector3(0,.14,-.035),Vector3(.075,.28,.075))
		_collision(basin,"BasinWasteToWallCollision",Vector3(0,.08,-.14),Vector3(.075,.075,.23))
		_collision(basin,"BasinTapCollision",Vector3(-.03,.505,-.09),Vector3(.065,.13,.14))

func _washroom_asset(path: String, label: String, at: Vector3) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path,state)
	if error != OK:
		push_error("Washroom fixture failed to load: "+path)
		return null
	var model := document.generate_scene(state) as Node3D
	if model == null:
		push_error("Washroom fixture has no scene: "+path)
		return null
	model.name = label
	add_child(model)
	model.position = at
	# Meshy originals face +Z; west-facing installation puts the backs at the east wall.
	model.rotation.y = -PI*.5
	model.scale = Vector3.ONE
	var bounds := _bounds_in_module(model)
	model.position.y += at.y-bounds.position.y
	model.set_meta("source_provider","Meshy 7.1; preserved originals and cleanup report in meshy_washroom_20261014")
	return model
