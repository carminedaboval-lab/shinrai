extends "res://scripts/midori_near_city_handmade.gd"
## Local +Z faces the shopping street. The outdoor stair runs down the east alley.
const Stairs := preload("res://scripts/midori_fukumaru_stairs.gd")
const Furniture := preload("res://scripts/midori_fukumaru_furniture.gd")
const Door := preload("res://scripts/building_access/door.gd")
const FINISH := preload("res://scripts/midori_fukumaru_finish.gdshader")
const WIDTH := 3.72
const DEPTH := 9.20
const MIDDLE := 3.30
const UPPER := 6.15
const HEIGHT := 2.85
const ENTRY_2F := Rect2(3.34, MIDDLE, 1.10, 2.14)
const ENTRY_3F := Rect2(8.05, UPPER, 1.10, 2.14)
const REAR_LOWER := Rect2(.46, 4.30, 1.86, 1.12)
const REAR_UPPER := Rect2(.58, 7.14, 2.12, 1.22)
const PAPER := Color("#f1ece1")
const LINEN := Color("#ede8de")
const SKIRT := Color("#a18a70")
const INTERIOR_LAYER := 64

var _body := StaticBody3D.new()
var _room_probes: Array[ReflectionProbe] = []
var _room_night := false
var _shadow_rooms: Array[Dictionary] = []
var _light_tick := 0.0

func _ready() -> void:
	add_to_group("playable_buildings")
	_body.name = "ApartmentStructure"
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	_shared_looks()
	_looks.plaster = _look("white_stucco", 1.65, .90)
	_looks.plaster.set_shader_parameter("chroma", .14)
	_looks.boards = _look("japanese_cedar_planks", 1.65, .60)
	_looks.boards.set_shader_parameter("chroma", .52)
	Stairs.build(self)
	_bar("metal", Transform3D.IDENTITY, 3.06, .77, .77, Vector3(.032, 1.54, .032), SKIRT)
	_number("2F  /  3F", Vector3(3.04, 1.47, .80), 0)
	_kit.commit(self, _looks, [])
	_kit = Kit.new()
	# Keep the exterior stair materials; interior batches get room finishes.
	_looks.plaster = _interior_finish("white_stucco", .90, .94, .08, .20)
	_looks.boards = _interior_finish("japanese_cedar_planks", 1.40, .64, .40, .42)
	_looks.boards.set_shader_parameter("lightness", .83)
	_looks.boards.set_shader_parameter("gain", 1.12)
	_looks.boards.set_shader_parameter("floor_joints", true)
	Furniture.setup_materials(self)
	_shell(MIDDLE, ENTRY_2F, Rect2(.34, .60, 2.50, 1.42), REAR_LOWER)
	_shell(UPPER, ENTRY_3F, Rect2(.34, .10, 2.50, 2.0), REAR_UPPER)
	# The entrance is a notch between the two studios. Each gets its own door.
	_wall_at(Vector3(-1.86, MIDDLE, -4.03), 0.0, 2.28, [], LINEN)
	_wall_at(Vector3(.42, MIDDLE, -3.15), PI * .5, 1.70, [], PAPER)
	for z: float in [-3.15, -4.85]:
		_wall_at(Vector3(.42, MIDDLE, z), 0.0, 1.44, [Rect2(.16, 0, 1.08, 2.12)], PAPER)
	_wall_at(Vector3(-1.86, UPPER, -3.65), 0.0, WIDTH, [Rect2(2.42, 0, 1.06, 2.16)], LINEN)
	_door(201, Vector3(1.12, MIDDLE, -3.15), 0.0, -PI * .5, Color("#805d48"))
	_door(202, Vector3(1.12, MIDDLE, -4.85), PI, -PI * .5, Color("#6c7168"))
	_door(301, Vector3(WIDTH * .5 - .052, UPPER, -8.60), PI * .5, PI * .5, Color("#606e75"))
	_number("201", Vector3(1.12, MIDDLE + 2.26, -3.29), PI)
	_number("202", Vector3(1.12, MIDDLE + 2.26, -4.83), 0)
	_number("301", Vector3(WIDTH * .5 + .018, UPPER + 2.28, -8.60), PI * .5)
	_number("201  /  202", Vector3(WIDTH * .5 + .018, MIDDLE + 2.28, -3.89), PI * .5)
	# Stone entrance tiles at shoe level give each door a clear threshold.
	for at: Vector3 in [Vector3(1.12, MIDDLE, -2.85), Vector3(1.12, MIDDLE, -5.28), Vector3(1.31, UPPER, -8.60)]:
		_kit.block("plaster", Transform3D(Basis.IDENTITY, at + Vector3.UP * .01),
				Vector3(1.12, .018, .75), Color("#aaaa9d"))
	_ceiling_lamp("Landing", Vector3(1.21, MIDDLE + 2.68, -4.01), .68)
	_ceiling_lamp("FrontStudio", Vector3(.02, MIDDLE + 2.68, -1.8))
	_ceiling_lamp("RearStudio", Vector3(.04, MIDDLE + 2.68, -6.86))
	_ceiling_lamp("MainRoom", Vector3(.18, UPPER + 2.68, -5.91))
	_ceiling_lamp("Bedroom", Vector3(.05, UPPER + 2.68, -1.8))
	Furniture.furnish(self)
	_bath_light("Bath201", Vector3(-1.095, MIDDLE + 2.06, -3.07))
	_bath_light("Bath202", Vector3(-.995, MIDDLE + 2.06, -5.08))
	_bath_light("Bath301", Vector3(-.91, UPPER + 2.06, -8.06))
	_wall_prints()
	var rooms := Node3D.new()
	rooms.name = "RoomMeshes"
	add_child(rooms)
	_kit.commit(rooms, _looks, ["lamp"])
	for mesh: MeshInstance3D in rooms.get_children():
		mesh.layers |= INTERIOR_LAYER
		mesh.visibility_range_end = 56
	_kit = null
	_room_reflection("Studio201", MIDDLE, -.10, -3.14)
	_room_reflection("Studio202", MIDDLE, -4.87, -9.10)
	_room_reflection("Living301", UPPER, -3.78, -9.10)
	_room_reflection("Bedroom301", UPPER, -.10, -3.57)

func _process(delta: float) -> void:
	_light_tick += delta
	if _light_tick < .20:
		return
	_light_tick = 0.0
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := to_local(camera.global_position)
	# Distant rooms keep their ordinary ceiling light. Only rooms visible from
	# inside or their doorway need a live shadow map; do not render all floors
	# into four shadow maps while the player walks along the street.
	for room: Dictionary in _shadow_rooms:
		var active: bool = (room.bounds as AABB).has_point(eye)
		var lamp: OmniLight3D = room.light
		if lamp.shadow_enabled != active:
			lamp.shadow_enabled = active

func _room_reflection(label: String, level: float, front: float, back: float) -> void:
	# Capture the room once, excluding the city. Stainless steel should reflect
	# its cabinets and ceiling; the sky cubemap made it look like blue plastic.
	var probe := ReflectionProbe.new()
	probe.name = label + "Reflection"
	probe.position = Vector3(0, level + 1.35, (front + back) * .5)
	# Include the receiving wall faces and ceiling, not just the empty air.
	probe.size = Vector3(WIDTH + .04, 2.82, front - back + .22)
	probe.interior = true
	probe.box_projection = true
	probe.cull_mask = INTERIOR_LAYER
	probe.reflection_mask = INTERIOR_LAYER
	probe.max_distance = 8.0
	probe.intensity = .85
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color("#dfd6c4")
	probe.ambient_color_energy = .40
	probe.enable_shadows = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)
	_room_probes.append(probe)

func set_night_mode(value: bool) -> void:
	super.set_night_mode(value)
	if value == _room_night:
		return
	_room_night = value
	for probe: ReflectionProbe in _room_probes:
		probe.ambient_color_energy = .26 if value else .40
		# A transform change refreshes UPDATE_ONCE, only on an actual transition.
		probe.position.x = .001 if value else 0.0

func _interior_finish(texture: String, tile: float, rough: float, chroma: float, relief: float) -> ShaderMaterial:
	var finish := ShaderMaterial.new()
	finish.shader = FINISH
	finish.set_shader_parameter("albedo_map", load(TEXTURES + texture + "_diff.jpg"))
	finish.set_shader_parameter("normal_map", load(TEXTURES + texture + "_nor.jpg"))
	if ResourceLoader.exists(TEXTURES + texture + "_rough.jpg"):
		finish.set_shader_parameter("rough_map", load(TEXTURES + texture + "_rough.jpg"))
	finish.set_shader_parameter("tile", tile)
	finish.set_shader_parameter("rough_scale", rough)
	finish.set_shader_parameter("chroma", chroma)
	finish.set_shader_parameter("normal_depth", relief)
	return finish

func _wall_prints() -> void:
	# A resident's print of the park reuses the project's original artwork.
	# Both small frames remain against the wall, outside the walking route.
	var art := ShaderMaterial.new()
	art.shader = FINISH
	art.set_shader_parameter("albedo_map",load("res://assets/shinrai/streets/interior_paintings/mori_morning.png"))
	art.set_shader_parameter("chroma",1.0)
	art.set_shader_parameter("rough_scale",.94)
	art.set_shader_parameter("normal_depth",0.0)
	_looks["apartment_print"] = art
	for centre: Vector3 in [Vector3(-1.736,MIDDLE+1.62,-7.37),Vector3(-1.736,UPPER+1.65,-4.64)]:
		var frame := Transform3D(Basis(Vector3.UP,PI*.5),centre)
		var half := Vector2(.235,.157)
		_bar("plain",frame,0,0,0,Vector3(.51,.354,.008),Color("#e9e3d5"))
		for side: float in [-1.0,1.0]:
			_bar("apartment_wood",frame,side*.259,0,.007,Vector3(.018,.376,.018),Color("#b0946c"))
			_bar("apartment_wood",frame,0,side*.179,.007,Vector3(.50,.018,.018),Color("#b0946c"))
		_kit.atlas("apartment_print",frame*Vector3(-half.x,-half.y,.005),frame*Vector3(-half.x,half.y,.005),
			frame*Vector3(half.x,half.y,.005),frame*Vector3(half.x,-half.y,.005),Rect2(0,0,1,1))

func _shell(level: float, entry: Rect2, front_window: Rect2, rear_window: Rect2) -> void:
	var paint := PAPER if level == MIDDLE else LINEN
	var slab := Vector3(0, level - .08, -DEPTH * .5)
	var size := Vector3(WIDTH, .16, DEPTH)
	_kit.block("boards", Transform3D(Basis.IDENTITY, slab), size, Color("#e5cdb0"))
	apartment_solid("Floor", slab, size)
	# The underside is painted separately from the timber finish of the floor above.
	_bar("plaster", Transform3D.IDENTITY, 0, level + HEIGHT - .175, -DEPTH * .5,
			Vector3(WIDTH - .12, .025, DEPTH - .12), Color("#ece6d7"))
	if level == UPPER:
		apartment_solid("Ceiling", Vector3(0, level + HEIGHT - .09, -DEPTH * .5), size)
	var front := Transform3D(Basis.IDENTITY, Vector3(-WIDTH * .5, level, 0))
	var rear := Transform3D(Basis(Vector3.UP, PI), Vector3(WIDTH * .5, level, -DEPTH))
	var back_hole := Rect2(rear_window.position - Vector2(0, level), rear_window.size)
	_wall_at(front.origin, 0, WIDTH, [front_window], paint)
	_wall_at(rear.origin, PI, WIDTH, [back_hole], paint)
	_glass_barrier(front, front_window)
	_glass_barrier(rear, back_hole)
	_drapes(front, front_window, Color("#ddd5c5"))
	# The top flat's wet-room wall seals off the left end of this sash.
	# Its hidden panel must not protrude through that wall above the bath.
	_drapes(rear, back_hole, Color("#d9d4c8") if level == MIDDLE else Color("#dfd5c4"), level == UPPER)
	_wall_at(Vector3(WIDTH * .5, level, 0), PI * .5, DEPTH,
			[Rect2(entry.position - Vector2(0, level), entry.size)], paint)
	_wall_at(Vector3(-WIDTH * .5, level, -DEPTH), -PI * .5, DEPTH, [], paint)

func _glass_barrier(face: Transform3D, opening: Rect2) -> void:
	var mid := opening.get_center()
	apartment_solid("Window", face * Vector3(mid.x, mid.y, -.082),
			Vector3(opening.size.x, opening.size.y, .035), face.basis)

func _drapes(face: Transform3D, window: Rect2, tint: Color, enclosed_end := false) -> void:
	var top := window.end.y + .10
	var bottom := maxf(.12, window.position.y - .13)
	_bar("metal", face, window.get_center().x, top + .012, -.18,
			Vector3(window.size.x + .25, .025, .028), ALUMINIUM)
	for side: int in range(2):
		if enclosed_end and side == 1:
			continue
		var edge := window.position.x - .09 if side == 0 else window.end.x + .09
		var direction := 1.0 if side == 0 else -1.0
		# Smooth gathers, slight gravity flare, and a sewn bottom hem. These
		# remain one opaque fabric batch and need no cloth simulation.
		# Each corner is shared by up to four cells: work it out once (same expressions on
		# the same values, so every cell gets the corners it always had).
		var grid_points := PackedVector3Array()
		var grid_normals := PackedVector3Array()
		var grid_prints := PackedVector2Array()
		for row: int in range(9):
			for column: int in range(41):
				var uv := Vector2(float(column) / 40.0, float(row) / 8.0)
				grid_points.append(face * _curtain_point(uv, edge, direction, bottom, top))
				var tangent := _curtain_point(uv + Vector2(.001,0),edge,direction,bottom,top) - _curtain_point(uv - Vector2(.001,0),edge,direction,bottom,top)
				var vertical := _curtain_point(uv + Vector2(0,.001),edge,direction,bottom,top) - _curtain_point(uv - Vector2(0,.001),edge,direction,bottom,top)
				grid_normals.append(face.basis * (tangent.cross(vertical).normalized() * -direction))
				grid_prints.append(Vector2(uv.x*.40,uv.y*(top-bottom)))
		for row: int in range(8):
			for column: int in range(40):
				# Corners (column,row), (column,row+1), (column+1,row+1), (column+1,row).
				var c0 := row * 41 + column
				var c1 := c0 + 41
				var c2 := c1 + 1
				var c3 := c0 + 1
				var positions: Array[Vector3] = [grid_points[c0], grid_points[c1], grid_points[c2], grid_points[c3]]
				var normals: Array[Vector3] = [grid_normals[c0], grid_normals[c1], grid_normals[c2], grid_normals[c3]]
				var prints: Array[Vector2] = [grid_prints[c0], grid_prints[c1], grid_prints[c2], grid_prints[c3]]
				_kit.mapped("apartment_fabric",positions,normals,prints,[0.0,0.0,0.0,0.0],tint,.96)
		var hem: Array[Vector3] = []
		for step: int in range(41):
			hem.append(face * _curtain_point(Vector2(float(step)/40.0,.018),edge,direction,bottom,top))
		_kit.tube("apartment_fabric",hem,.003,tint.darkened(.08),4)
		for clip: int in range(6):
			var at := face * _curtain_point(Vector2(float(clip)/5.0,1.0),edge,direction,bottom,top)
			_kit.block("metal",Transform3D(face.basis,at+face.basis*Vector3(0,.012,.015)),Vector3(.009,.029,.013),ALUMINIUM)

func _curtain_point(uv: Vector2, edge: float, direction: float, bottom: float, top: float) -> Vector3:
	var flare := .32 + .062 * (1.0-uv.y)
	# The gathers relax into unequal curves below their clips; shallow
	# valleys avoid the sharp accordion profile of the initial curtains.
	var phase := TAU * (3.05*uv.x + .10*sin(uv.x*PI) + .11*(1.0-uv.y)*sin(uv.x*PI*1.5))
	var x := edge + direction * (uv.x*flare + .007*sin(uv.y*PI)*sin(uv.x*TAU))
	var y := lerpf(bottom,top,uv.y) + .024*(1.0-uv.y)*sin(uv.x*TAU*1.7+.4)
	var z := -.193 - .022*(1.0-cos(phase)) - .016*sin(uv.y*PI)*sin(uv.x*PI)
	return Vector3(x,y,z)

func _wall_at(origin: Vector3, yaw: float, length: float, holes: Array[Rect2], tint: Color) -> void:
	var face := Transform3D(Basis(Vector3.UP, yaw), origin)
	for rect: Rect2 in _minus(Rect2(0, 0, length, HEIGHT - .16), holes):
		var mid := rect.get_center()
		var at := face * Vector3(mid.x, mid.y, -.061)
		var size := Vector3(rect.size.x, rect.size.y, .098)
		_kit.block("plaster", Transform3D(face.basis, at), size, tint)
		apartment_solid("Wall", at, size, face.basis)
	for run: Rect2 in _minus(Rect2(0, 0, length, .075), holes):
		_bar("plain", face, run.get_center().x, .04, -.118,
				Vector3(run.size.x, .08, .018), SKIRT)

func _door(number: int, at: Vector3, yaw: float, swing: float, tint: Color) -> void:
	var door := Door.new()
	door.name = "Apartment%d" % number
	door.transform = Transform3D(Basis(Vector3.UP, yaw), at)
	door.open_angle = swing
	var enamel := StandardMaterial3D.new()
	enamel.albedo_color = tint
	enamel.roughness = .70
	add_child(door)
	door.configure(Vector3(1.02, 2.07, .046), enamel, false, "apartment %d" % number)
	for detail in door.leaf.get_children():
		if detail is MeshInstance3D:
			detail.layers |= INTERIOR_LAYER
			detail.visibility_range_end = 46
	var frame := door.transform
	for x: float in [-.536, .536]:
		_bar("plain", frame, x, 1.055, 0, Vector3(.036, 2.11, .14), SKIRT)
	_bar("plain", frame, 0, 2.10, 0, Vector3(1.11, .06, .14), SKIRT)

func _number(value: String, at: Vector3, yaw: float) -> void:
	var face := Transform3D(Basis(Vector3.UP, yaw), at)
	var wide := maxf(.21, value.length() * .044)
	_bar("plain", face, 0, 0, 0, Vector3(wide, .13, .018), Color("#354842"))
	var label := Label3D.new()
	label.text = value
	label.font_size = 48
	label.pixel_size = .00145
	label.outline_size = 0
	label.double_sided = false
	label.modulate = Color("#f4ebd8")
	label.transform = face.translated_local(Vector3(0, 0, .011))
	label.visibility_range_end = 20
	add_child(label)

func _ceiling_lamp(label: String, at: Vector3, energy := 1.65) -> void:
	_kit.lathe("lamp", at - Vector3.UP * .055, [Vector2(.01, 0), Vector2(.19, .012),
			Vector2(.22, .04), Vector2(.22, .068)], Color("#e1dbc3"), 16)
	var lamp := OmniLight3D.new()
	lamp.omni_range = 2.2 if label == "Landing" else 3.7
	lamp.omni_attenuation = 1.0
	lamp.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	lamp.shadow_bias = .12
	lamp.shadow_normal_bias = 1.0
	lamp.name = label
	lamp.position = at - Vector3.UP * .24
	lamp.light_color = Color("#fff0d9")
	lamp.light_energy = energy
	lamp.light_cull_mask = INTERIOR_LAYER
	lamp.shadow_caster_mask = INTERIOR_LAYER
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 22.0
	lamp.distance_fade_shadow = 18.0
	lamp.distance_fade_length = 7.0
	add_child(lamp)
	if label != "Landing":
		var level := MIDDLE if label in ["FrontStudio", "RearStudio"] else UPPER
		var back := -4.15 if label == "FrontStudio" else -9.35
		var front := .40 if label in ["FrontStudio", "Bedroom"] else -4.65
		if label == "MainRoom": front = -3.45
		if label == "Bedroom": back = -3.85
		_shadow_rooms.append({"light":lamp,"bounds":AABB(Vector3(-2.10,level+.05,back),Vector3(4.45,2.73,front-back))})

func _bath_light(label: String, at: Vector3) -> void:
	# The enclosed unit baths already have ceiling fixtures. Give each its own
	# short-range light rather than relying on light leaking through its walls.
	var lamp := OmniLight3D.new()
	lamp.name = label
	lamp.position = at
	lamp.light_color = Color("#fff3df")
	lamp.light_energy = 1.0
	lamp.omni_range = 2.7
	lamp.omni_attenuation = 1.0
	lamp.light_cull_mask = INTERIOR_LAYER
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 12.0
	lamp.distance_fade_length = 5.0
	add_child(lamp)

func apartment_furniture_box(label: String, center: Vector3, size: Vector3) -> void:
	apartment_solid(label, center, size)

func apartment_solid(label: String, center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	var collider := CollisionShape3D.new()
	collider.name = label
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	collider.transform = Transform3D(basis, center)
	_body.add_child(collider, true)

func contains_world_point(point: Vector3) -> bool:
	var p := to_local(point)
	if p.x >= 1.80 and p.x <= 3.14 and p.z >= -9.24 and p.z <= 1.70:
		return p.y >= -.40 and p.y < UPPER + 2.6
	return absf(p.x) <= WIDTH * .5 + .04 and p.z >= -DEPTH - .04 and p.z <= .12 \
			and p.y >= MIDDLE - .20 and p.y <= UPPER + HEIGHT
