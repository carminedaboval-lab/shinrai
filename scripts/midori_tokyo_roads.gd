extends Node3D
## Real road surfaces over the near city's painted ground plane, out to two
## blocks around Midori Park, in WORLD metres. Direct child of the scene root.
##
## The near city (another module) draws every road as one flat ground shader.
## This module leaves that file alone and lays geometry 2 cm above it: worn
## asphalt with its repair history, gutters and grates, Japanese markings,
## manhole lids, 止まれ, cycling signals and street-light pools after dark.
## Roads outside this coverage keep the ground plane's look.
const Budget = preload("res://scripts/shinrai_loading_budget.gd")
const ROAD_SHADER := preload("res://scripts/midori_tokyo_road.gdshader")
const PARTS_SHADER := preload("res://scripts/midori_tokyo_road_parts.gdshader")
const SIGNAL_SHADER := preload("res://scripts/midori_tokyo_signal.gdshader")
const TEX := "res://assets/environment/roads/shinrai_road/"
const PAVER := "res://assets/shinrai/drain_hgu150/ProjectShinrai_HGU150_Drain_GameReady_SHINRAI_PrecastPaver_BaseColor_1K.png"
const CURB_ALBEDO := "res://assets/environment/roads/shinrai_road/curb_drain/SHINRAI_CurbConcrete_Albedo_1K.png"
const SURFACE_SHADER_PATH := "res://scripts/midori_surface_readability.gdshader"
const ASPHALT_SHADER_PATH := "res://scripts/midori_street_asphalt.gdshader"

const PARK := Rect2(-222, -182, 444, 364)
const RING := 14.0
const HW := 7.0
const ROAD_Y := -0.06
const REACH := 327.0 # Two blocks out from the park, plus a road's half width.
const LINES: Array[float] = [-320.0, -256.0, -192.0, -128.0, -64.0, 0.0, 64.0, 128.0, 192.0, 256.0, 320.0]
const CHUNK := 128.0
const J0 := 1.0
const ZEBRA := 4.0
const STOP_AT := J0 + ZEBRA + 1.6
const SIGNAL_RANGE := 160.0
const VERGE_TOP := 0.015
## Playable strip outside the park fence, where poles need collision.
const PLAYABLE := Rect2(-230.5, -190.5, 461.0, 381.0)

var installed := false
var report: Dictionary = {}
var bands: Array[Dictionary] = []
var boxes: Array[Dictionary] = []
var segments: Array[Dictionary] = []
var _park: Node3D
var _clear: Array[Rect2] = []
var _materials: Array[ShaderMaterial] = []
var _road_mat: ShaderMaterial
var _paint_mat: ShaderMaterial
var _lid_mat: ShaderMaterial
var _signal_mat: ShaderMaterial
var _metal_mat: StandardMaterial3D
var _chunks: Dictionary = {}
var _poles: StaticBody3D

func _ready() -> void:
	add_to_group("midori_horizon")
	_park = get_parent() as Node3D
	await Budget.wait_structure(_park)
	var city: Node = null
	var deadline := Time.get_ticks_msec() + 120000
	while city == null and Time.get_ticks_msec() < deadline:
		city = _park.get_node_or_null("MidoriHorizon/NearCity")
		if city == null: await get_tree().process_frame
	if city != null:
		for zone: Rect2 in city.get("CLEAR_ZONES"): _clear.append(zone)
	set_as_top_level(true)
	global_transform = Transform3D.IDENTITY
	_make_materials()
	_define_bands()
	_find_boxes()
	_split_segments()
	_build_surfaces()
	_build_manholes()
	_build_stop_text()
	_build_signals()
	_build_verge()
	installed = true
	set_night_mode(bool(_park.get("is_night_mode")))
	_resurface_existing()
	report.merge({"bands":bands.size(), "boxes":boxes.size(), "segments":segments.size(), "chunks":_chunks.size(), "signalised":boxes.filter(func(b: Dictionary) -> bool: return b.signalised).size()})
	print("MIDORI_TOKYO_ROADS_READY ", JSON.stringify(report))

func set_night_mode(value: bool) -> void:
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("night", 1.0 if value else 0.0)

## The main street, its back lane and the corporate roads are boxes built by
## their own modules, with their own kerbs and paint. Once those modules finish,
## their asphalt takes this surface (asphalt only) and their paint wears in.
func _resurface_existing() -> void:
	# The raid reaching HQ is the one reliable "everything is built" signal; the
	# review scene has no raid, so there the producers' own flags decide.
	var deadline := Time.get_ticks_msec() + 600000
	while Time.get_ticks_msec() < deadline:
		var raid: Node = _park.get_node_or_null("ExtractionRun")
		if raid != null and int(raid.get("phase")) != 0: break
		if raid == null:
			var street: Node = _park.get_node_or_null("MidoriSouthStreet")
			var corporate: Node = _park.get_node_or_null("MidoriCorporateDistrict")
			if (street == null or street.get("installed") == true) and (corporate == null or corporate.get("installed") == true): break
		await get_tree().process_frame
	var roads := 0
	var paints := 0
	for node: Node in _park.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null: continue
		if mesh.material_override == null:
			var counts := _resurface_surfaces(mesh)
			roads += counts.x
			paints += counts.y
			continue
		var material := mesh.material_override as ShaderMaterial
		if material == null or material.shader == null: continue
		if not material.shader.resource_path in [SURFACE_SHADER_PATH, ASPHALT_SHADER_PATH]: continue
		var paint_flag: Variant = material.get_shader_parameter("paint_surface")
		if paint_flag != null and float(paint_flag) > 0.5:
			mesh.material_override = _paint_mat
			paints += 1
			continue
		var box := mesh.mesh.get_aabb()
		if box.size.y > 0.5: continue
		var long_x := box.size.x >= box.size.z
		mesh.material_override = _road_mat
		mesh.set_instance_shader_parameter("road_frame", Vector4(0.0 if long_x else 1.0, (box.size.z if long_x else box.size.x) * 0.5, maxf(box.size.x, box.size.z), 0.0))
		mesh.set_instance_shader_parameter("road_centre", Vector2(box.get_center().x, box.get_center().z))
		roads += 1
	report["resurfaced_roads"] = roads
	report["repainted_marks"] = paints
	print("MIDORI_TOKYO_ROADS_RESURFACED ", JSON.stringify({"roads":roads, "marks":paints}))

## Batched meshes carry one material per surface. Returns (roads, marks) swapped.
func _resurface_surfaces(mesh: MeshInstance3D) -> Vector2i:
	var counts := Vector2i.ZERO
	for surface: int in range(mesh.mesh.get_surface_count()):
		var material := mesh.get_active_material(surface) as ShaderMaterial
		if material == null or material.shader == null: continue
		if not material.shader.resource_path in [SURFACE_SHADER_PATH, ASPHALT_SHADER_PATH]: continue
		var paint_flag: Variant = material.get_shader_parameter("paint_surface")
		if paint_flag != null and float(paint_flag) > 0.5:
			mesh.set_surface_override_material(surface, _paint_mat)
			counts.y += 1
			continue
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		if vertices.is_empty(): continue
		var box := AABB(vertices[0], Vector3.ZERO)
		for vertex: Vector3 in vertices: box = box.expand(vertex)
		if box.size.y > 0.5: continue
		var long_x := box.size.x >= box.size.z
		var long := maxf(box.size.x, box.size.z)
		var short := minf(box.size.x, box.size.z)
		# One straight road gets lanes; a batch of roads in both directions keeps
		# the asphalt, joints and patches but no lane wear.
		var half := short * 0.5 if long > short * 3.0 else 0.0
		mesh.set_surface_override_material(surface, _road_mat)
		mesh.set_instance_shader_parameter("road_frame", Vector4(0.0 if long_x else 1.0, half, long, 0.0))
		mesh.set_instance_shader_parameter("road_centre", Vector2(box.get_center().x, box.get_center().z))
		counts.x += 1
	return counts

# ---------------------------------------------------------------- materials

func _make_materials() -> void:
	_road_mat = ShaderMaterial.new()
	_road_mat.shader = ROAD_SHADER
	_road_mat.set_shader_parameter("aggregate_albedo", load(TEX + "textures/SHINRAI_Road_FineAggregate_BaseColor_2K.png"))
	_road_mat.set_shader_parameter("aggregate_normal", load(TEX + "textures/SHINRAI_Road_RealisticDry_NormalGL_2K.png"))
	_road_mat.set_shader_parameter("aggregate_orm", load(TEX + "textures/SHINRAI_Road_RealisticDry_ORM_2K.png"))
	_paint_mat = ShaderMaterial.new()
	_paint_mat.shader = PARTS_SHADER
	_paint_mat.set_shader_parameter("part", 0)
	_lid_mat = ShaderMaterial.new()
	_lid_mat.shader = PARTS_SHADER
	_lid_mat.set_shader_parameter("part", 1)
	_lid_mat.set_shader_parameter("lid_albedo", load(TEX + "repairs/SHINRAI_ManholeCover_Albedo_1K.png"))
	_lid_mat.set_shader_parameter("lid_normal", load(TEX + "repairs/SHINRAI_ManholeCover_NormalGL_1K.png"))
	_lid_mat.set_shader_parameter("lid_orm", load(TEX + "repairs/SHINRAI_ManholeCover_ORM_1K.png"))
	_signal_mat = ShaderMaterial.new()
	_signal_mat.shader = SIGNAL_SHADER
	_materials.append_array([_road_mat, _paint_mat, _lid_mat, _signal_mat])
	_metal_mat = StandardMaterial3D.new()
	_metal_mat.albedo_color = Color("#8c9193")
	_metal_mat.metallic = 0.55
	_metal_mat.roughness = 0.45
	_metal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

# ------------------------------------------------------------------ network

func _kind(line: float) -> int:
	return 1 if is_zero_approx(fposmod(line, 256.0)) else 2

## A band is one straight road strip. axis "x" runs along x at z = line.
func _band(axis: String, line: float, lo: float, hi: float, kind: int, label: String) -> void:
	# Cut away anything that enters the hand-built districts.
	var parts: Array[Vector2] = [Vector2(lo, hi)]
	for zone: Rect2 in _clear:
		var across := Vector2(zone.position.y, zone.end.y) if axis == "x" else Vector2(zone.position.x, zone.end.x)
		if line + HW <= across.x or line - HW >= across.y: continue
		var along := Vector2(zone.position.x, zone.end.x) if axis == "x" else Vector2(zone.position.y, zone.end.y)
		var next: Array[Vector2] = []
		for part: Vector2 in parts:
			if part.y <= along.x or part.x >= along.y:
				next.append(part)
				continue
			if part.x < along.x: next.append(Vector2(part.x, along.x - 1.0))
			if part.y > along.y: next.append(Vector2(along.y + 1.0, part.y))
		parts = next
	for part: Vector2 in parts:
		if part.y - part.x < 10.0: continue
		bands.append({"axis":axis, "line":line, "lo":part.x, "hi":part.y, "kind":kind, "label":label, "ring":kind == 0})

func _define_bands() -> void:
	var ring_x := PARK.size.x * 0.5 + RING * 0.5
	var ring_z := PARK.size.y * 0.5 + RING * 0.5
	var outer := PARK.grow(RING)
	_band("x", -ring_z, outer.position.x, outer.end.x, 0, "ring_north")
	_band("x", ring_z, outer.position.x, outer.end.x, 0, "ring_south")
	_band("z", -ring_x, outer.position.y, outer.end.y, 0, "ring_west")
	_band("z", ring_x, outer.position.y, outer.end.y, 0, "ring_east")
	for line: float in LINES:
		# North-south roads: arms off the ring inside its span, full lines beyond.
		if absf(line) + HW < outer.end.x:
			_band("z", line, -REACH, PARK.position.y, _kind(line), "arm_n_%d" % int(line))
			_band("z", line, PARK.end.y, REACH, _kind(line), "arm_s_%d" % int(line))
		else:
			_band("z", line, -REACH, REACH, _kind(line), "line_z_%d" % int(line))
		# East-west roads. Lines that would run along the ring stop short of it.
		if absf(line) + HW < outer.end.y:
			_band("x", line, -REACH, PARK.position.x, _kind(line), "arm_w_%d" % int(line))
			_band("x", line, PARK.end.x, REACH, _kind(line), "arm_e_%d" % int(line))
		elif absf(line) - HW < outer.end.y:
			_band("x", line, -REACH, outer.position.x, _kind(line), "spur_w_%d" % int(line))
			_band("x", line, outer.end.x, REACH, _kind(line), "spur_e_%d" % int(line))
		else:
			_band("x", line, -REACH, REACH, _kind(line), "line_x_%d" % int(line))

func _rect(band: Dictionary) -> Rect2:
	if band.axis == "x":
		return Rect2(band.lo, band.line - HW, band.hi - band.lo, HW * 2.0)
	return Rect2(band.line - HW, band.lo, HW * 2.0, band.hi - band.lo)

func _find_boxes() -> void:
	for a: Dictionary in bands:
		if a.axis != "x": continue
		for b: Dictionary in bands:
			if b.axis != "z": continue
			var overlap := _rect(a).intersection(_rect(b))
			if overlap.get_area() < 4.0: continue
			var corner: bool = a.ring and b.ring
			var signalised: bool = not corner and (a.kind <= 1 or b.kind <= 1)
			# Edges with no road beyond them get a kerb and gutter.
			var edges := 0
			if a.lo > overlap.position.x - 0.5: edges |= 1
			if a.hi < overlap.end.x + 0.5: edges |= 2
			if b.lo > overlap.position.y - 0.5: edges |= 4
			if b.hi < overlap.end.y + 0.5: edges |= 8
			var centre := overlap.get_center()
			var flow_a := 0 if (a.ring or (a.kind < b.kind and not b.ring)) else 1
			if not a.ring and not b.ring and a.kind == b.kind: flow_a = 0
			boxes.append({"rect":overlap, "a":a, "b":b, "corner":corner, "signalised":signalised and _park_distance(centre) < SIGNAL_RANGE, "gutters":edges, "flow_a":flow_a, "phase":fposmod(centre.x * 0.0131 + centre.y * 0.0173, 1.0)})

func _park_distance(p: Vector2) -> float:
	var d := p.abs() - PARK.size * 0.5
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length()

## Junction type seen from a band arriving at a box: 0 none, 1 stop, 2 signal, 3 priority.
func _junction(band: Dictionary, box: Dictionary) -> int:
	if box.corner: return 0
	var other: Dictionary = box.b if is_same(box.a, band) else box.a
	if band.kind <= 1 or other.kind <= 1: return 2
	return 1 if band.axis == "z" else 3

func _split_segments() -> void:
	for band: Dictionary in bands:
		var on_band: Array[Dictionary] = []
		for box: Dictionary in boxes:
			if is_same(box.a, band) or is_same(box.b, band): on_band.append(box)
		var key := "x" if band.axis == "x" else "y"
		on_band.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return (p.rect as Rect2).position[key] < (q.rect as Rect2).position[key])
		var cursor: float = band.lo
		var previous: Dictionary = {}
		for box: Dictionary in on_band:
			var start: float = (box.rect as Rect2).position[key]
			if start - cursor > 1.0:
				_segment(band, cursor, start, previous, box)
			cursor = (box.rect as Rect2).end[key]
			previous = box
		if band.hi - cursor > 1.0:
			_segment(band, cursor, band.hi, previous, {})

func _segment(band: Dictionary, from: float, to: float, start_box: Dictionary, end_box: Dictionary) -> void:
	var dir := Vector2(1, 0) if band.axis == "x" else Vector2(0, 1)
	var start := Vector2(from, band.line) if band.axis == "x" else Vector2(band.line, from)
	segments.append({"band":band, "start":start, "dir":dir, "right":Vector2(-dir.y, dir.x), "length":to - from,
		"start_j":_junction(band, start_box) if not start_box.is_empty() else 0,
		"end_j":_junction(band, end_box) if not end_box.is_empty() else 0,
		"start_box":start_box, "end_box":end_box})

# ----------------------------------------------------------------- surfaces

func _chunk(point: Vector2) -> SurfaceTool:
	var key := Vector2i(floori(point.x / CHUNK), floori(point.y / CHUNK))
	if not _chunks.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
		_chunks[key] = st
	return _chunks[key]

## Street lights along the ring follow the near city's own lamp spacing, so each
## pool sits under a real lamp head. Side streets get dimmer pole-mounted lights.
func _lamps(seg: Dictionary) -> Array:
	var band: Dictionary = seg.band
	var along: float = seg.start.x if band.axis == "x" else seg.start.y
	match band.label:
		"ring_north":
			return [-6.6, 1.0, 34.0, fposmod(-238.0 - along, 34.0)]
		"ring_east":
			return [-6.6, 1.0, 362.0 / 11.0, fposmod(-198.0 - along, 362.0 / 11.0)]
		"ring_west":
			return [6.6, 1.0, 33.0, fposmod(-198.0 - along, 33.0)]
		"ring_south":
			return [99.0, 0.0, 0.0, 0.0]
	return [HW - 1.0, 0.5, 30.0, 9.0]

func _quad(st: SurfaceTool, corners: Array[Vector2], uvs: Array[Vector2], lamp: Vector2, color: Color, custom: Color) -> void:
	for index: int in [0, 1, 2, 0, 2, 3]:
		st.set_color(color)
		st.set_uv(uvs[index])
		st.set_uv2(lamp)
		st.set_custom(0, custom)
		st.add_vertex(Vector3(corners[index].x, ROAD_Y, corners[index].y))

func _build_surfaces() -> void:
	for seg: Dictionary in segments:
		var start: Vector2 = seg.start
		var dir: Vector2 = seg.dir
		var right: Vector2 = seg.right
		var length: float = seg.length
		var lamp: Array = _lamps(seg)
		var color := Color(float(seg.band.kind) / 8.0, float(seg.start_j) / 4.0, float(seg.end_j) / 4.0, 1.0)
		var custom := Color(length, HW, lamp[2], lamp[3])
		# Long runs are cut into pieces so each chunk culls on its own.
		var pieces := maxi(1, ceili(length / 64.0))
		for i: int in range(pieces):
			var v0 := length * float(i) / float(pieces)
			var v1 := length * float(i + 1) / float(pieces)
			var corners: Array[Vector2] = [start + dir * v0 - right * HW, start + dir * v1 - right * HW, start + dir * v1 + right * HW, start + dir * v0 + right * HW]
			var uvs: Array[Vector2] = [Vector2(-HW, v0), Vector2(-HW, v1), Vector2(HW, v1), Vector2(HW, v0)]
			_quad(_chunk(start + dir * (v0 + v1) * 0.5), corners, uvs, Vector2(lamp[0], lamp[1]), color, custom)
	for box: Dictionary in boxes:
		var rect: Rect2 = box.rect
		var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		var half := rect.size.x * 0.5
		var uvs: Array[Vector2] = [Vector2(-half, 0), Vector2(half, 0), Vector2(half, rect.size.y), Vector2(-half, rect.size.y)]
		var lit := 0.85 if (box.a.ring or box.b.ring) else 0.5
		_quad(_chunk(rect.get_center()), corners, uvs, Vector2(0.0, lit), Color(3.0 / 8.0, float(box.gutters) / 16.0, 0.0, 1.0), Color(rect.size.y, half, 1000.0, rect.size.y * 0.5))
	for key: Vector2i in _chunks:
		var st: SurfaceTool = _chunks[key]
		var mesh := st.commit()
		mesh.surface_set_material(0, _road_mat)
		var instance := MeshInstance3D.new()
		instance.name = "TokyoRoad_%d_%d" % [key.x, key.y]
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		instance.custom_aabb = AABB(Vector3(key.x * CHUNK - 8.0, -1.0, key.y * CHUNK - 8.0), Vector3(CHUNK + 16.0, 2.0, CHUNK + 16.0))
		add_child(instance)

# ------------------------------------------------------------- road details

func _world(seg: Dictionary, u: float, v: float, lift := 0.0) -> Vector3:
	var p: Vector2 = seg.start + seg.dir * v + seg.right * u
	return Vector3(p.x, ROAD_Y + lift, p.y)

func _build_manholes() -> void:
	var transforms: Array[Transform3D] = []
	for seg: Dictionary in segments:
		var length: float = seg.length
		var kind: int = seg.band.kind
		var seed := fposmod(seg.start.x * 0.031 + seg.start.y * 0.047, 1.0)
		var v := 14.0 + seed * 20.0
		var flip := 1.0
		while v < length - 14.0:
			var lanes := [1.62, 4.9] if kind != 2 else [1.62]
			var u: float = lanes[int(v * 0.37) % lanes.size()] * flip
			transforms.append(Transform3D(Basis(Vector3.UP, seed * TAU + v), _world(seg, u, v, 0.004)))
			# A small square valve box sits by the kerb now and then.
			v += 34.0 + fposmod(v * 0.618, 1.0) * 14.0
			flip = -flip
	if transforms.is_empty(): return
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.68, 0.68)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = plane
	mm.instance_count = transforms.size()
	for i: int in range(transforms.size()): mm.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "ManholeLids"
	instance.multimesh = mm
	instance.material_override = _lid_mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = 140.0
	add_child(instance)
	report["manholes"] = transforms.size()

## 止まれ on each minor-road approach, read from the driver's seat: stretched along
## the lane, with the first character nearest the stop line.
func _build_stop_text() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Yu Gothic", "Meiryo", "MS Gothic", "Noto Sans CJK JP", "Noto Sans JP", "Hiragino Sans"])
	font.font_weight = 700
	if not font.has_char(0x6B62):
		report["stop_text"] = "no Japanese system font"
		return
	var glyphs: Dictionary = {}
	for ch: String in ["止", "ま", "れ"]:
		var text := TextMesh.new()
		text.text = ch
		text.font = font
		text.font_size = 64
		text.pixel_size = 1.35 / 64.0
		text.depth = 0.0
		text.curve_step = 0.25
		glyphs[ch] = text
	var placed := 0
	var root := Node3D.new()
	root.name = "StopText"
	add_child(root)
	for seg: Dictionary in segments:
		for toward_end: bool in [true, false]:
			var approach: int = seg.end_j if toward_end else seg.start_j
			if approach != 1 or float(seg.length) < 30.0: continue
			var forward: Vector2 = seg.dir if toward_end else -seg.dir
			var right := Vector2(-forward.y, forward.x)
			var lane_u := -1.62 if toward_end else 1.62
			var row := 0
			for ch: String in ["止", "ま", "れ"]:
				var dj := STOP_AT + 2.0 + float(row) * 2.55
				var v: float = (seg.length - dj) if toward_end else dj
				var at := _world(seg, lane_u, v, 0.006)
				var basis := Basis(Vector3(right.x, 0, right.y), Vector3(forward.x, 0, forward.y) * 1.75, Vector3.UP)
				var glyph := MeshInstance3D.new()
				glyph.mesh = glyphs[ch]
				glyph.material_override = _paint_mat
				glyph.transform = Transform3D(basis, at)
				glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				glyph.visibility_range_end = 120.0
				root.add_child(glyph)
				row += 1
			placed += 1
	report["stop_text"] = placed

# ----------------------------------------------------------------- signals

func _tube(st: SurfaceTool, a: Vector3, b: Vector3, radius: float, sides := 8) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := axis.cross(side).normalized()
	for i: int in range(sides):
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var o0 := (side * cos(a0) + up * sin(a0)) * radius
		var o1 := (side * cos(a1) + up * sin(a1)) * radius
		for corner: Vector3 in [a + o0, b + o0, b + o1, a + o0, b + o1, a + o1]:
			st.set_normal(((corner - a) - axis * (corner - a).dot(axis)).normalized())
			st.add_vertex(corner)

func _block(st: SurfaceTool, centre: Vector3, x: Vector3, y: Vector3, z: Vector3) -> void:
	# x, y, z are half extents along each edge direction.
	var faces: Array = [[x, y, z], [-x, y, -z], [z, y, -x], [-z, y, x], [y, -z, x], [-y, z, x]]
	for face: Array in faces:
		var n: Vector3 = face[0]
		var t: Vector3 = face[1]
		var b: Vector3 = face[2]
		var c := centre + n
		var quad: Array[Vector3] = [c - t - b, c - t + b, c + t + b, c + t - b]
		for index: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n.normalized())
			st.add_vertex(quad[index])

func _lens(st: SurfaceTool, centre: Vector3, facing: Vector3, radius: float, role: int, flow: int, phase: float) -> void:
	var side := facing.cross(Vector3.UP).normalized()
	var up := side.cross(facing).normalized()
	for i: int in range(12):
		var a0 := TAU * float(i) / 12.0
		var a1 := TAU * float(i + 1) / 12.0
		for corner: Vector3 in [centre, centre + (side * cos(a1) + up * sin(a1)) * radius, centre + (side * cos(a0) + up * sin(a0)) * radius]:
			st.set_color(Color(float(role) / 8.0, float(flow), phase, 1.0))
			st.set_normal(facing)
			st.add_vertex(corner)

func _build_signals() -> void:
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lenses := SurfaceTool.new()
	lenses.begin(Mesh.PRIMITIVE_TRIANGLES)
	_poles = StaticBody3D.new()
	_poles.name = "SignalPoleCollision"
	add_child(_poles)
	var heads := 0
	for box: Dictionary in boxes:
		if not box.signalised: continue
		var rect: Rect2 = box.rect
		var centre := Vector3(rect.get_center().x, 0.0, rect.get_center().y)
		for seg: Dictionary in segments:
			for toward_end: bool in [true, false]:
				var arrives: Dictionary = seg.end_box if toward_end else seg.start_box
				if not is_same(arrives, box): continue
				var forward2: Vector2 = seg.dir if toward_end else -seg.dir
				var forward := Vector3(forward2.x, 0, forward2.y)
				var right := Vector3(-forward.z, 0, forward.x)
				var flow: int = int(box.flow_a) if is_same(seg.band, box.a) else 1 - int(box.flow_a)
				var reach := (rect.size.x if absf(forward.x) > 0.5 else rect.size.y) * 0.5
				# Vehicle signal on the far left corner, its arm out over the lanes.
				var pole := centre + forward * (reach + 1.3) - right * (HW + 1.3)
				_tube(body, pole, pole + Vector3.UP * 5.6, 0.1)
				var arm_end := pole + right * 4.6 + Vector3.UP * 5.35
				_tube(body, pole + Vector3.UP * 5.35, arm_end, 0.06)
				_tube(body, pole + Vector3.UP * 4.6, pole + right * 1.8 + Vector3.UP * 5.3, 0.035)
				var head := arm_end - right * 0.75 - Vector3.UP * 0.05
				_block(body, head, right * 0.66, Vector3.UP * 0.22, forward * 0.14)
				for slot: int in range(3):
					var lens_at := head + right * (float(slot) - 1.0) * 0.42 - forward * 0.145
					_lens(lenses, lens_at, -forward, 0.15, slot, flow, box.phase)
					# Visor over each lens.
					_block(body, lens_at + Vector3.UP * 0.17 - forward * 0.11, right * 0.17, Vector3.UP * 0.012, forward * 0.12)
				_collide(pole, 0.12)
				heads += 1
				# Pedestrian signals at both ends of this arm's crossing.
				var crossing := centre - forward * (reach + J0 + ZEBRA * 0.5)
				for side: float in [-1.0, 1.0]:
					var foot := crossing + right * side * (HW + 0.9)
					_tube(body, foot, foot + Vector3.UP * 3.0, 0.07)
					var walk_head := foot + Vector3.UP * 2.45 - right * side * 0.2
					var facing := -right * side
					_block(body, walk_head, forward * 0.17, Vector3.UP * 0.38, facing * 0.11)
					_lens_square(lenses, walk_head + facing * 0.115 + Vector3.UP * 0.17, facing, forward, 3, 1 - flow, box.phase)
					_lens_square(lenses, walk_head + facing * 0.115 - Vector3.UP * 0.17, facing, forward, 4, 1 - flow, box.phase)
					_collide(foot, 0.08)
	if heads == 0: return
	var body_mesh := body.commit()
	body_mesh.surface_set_material(0, _metal_mat)
	var body_instance := MeshInstance3D.new()
	body_instance.name = "TrafficSignals"
	body_instance.mesh = body_mesh
	body_instance.visibility_range_end = 260.0
	add_child(body_instance)
	var lens_mesh := lenses.commit()
	lens_mesh.surface_set_material(0, _signal_mat)
	var lens_instance := MeshInstance3D.new()
	lens_instance.name = "TrafficSignalLenses"
	lens_instance.mesh = lens_mesh
	lens_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lens_instance.visibility_range_end = 320.0
	add_child(lens_instance)
	report["signal_heads"] = heads

func _lens_square(st: SurfaceTool, centre: Vector3, facing: Vector3, across: Vector3, role: int, flow: int, phase: float) -> void:
	var x := across.normalized() * 0.13
	var y := Vector3.UP * 0.14
	for corner: Vector3 in [centre - x - y, centre + x + y, centre + x - y, centre - x - y, centre - x + y, centre + x + y]:
		st.set_color(Color(float(role) / 8.0, float(flow), phase, 1.0))
		st.set_normal(facing)
		st.add_vertex(corner)

func _collide(foot: Vector3, radius: float) -> void:
	if not PLAYABLE.has_point(Vector2(foot.x, foot.z)): return
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = 5.6
	shape.shape = cylinder
	shape.position = foot + Vector3.UP * 2.8
	_poles.add_child(shape)

# -------------------------------------------------------------------- verge

## The ring road starts 2 m beyond the park's ground, which left a strip with
## nothing in it: the sea plane showed through as a blue band. A paved verge
## with a granite kerb now fills it.
func _build_verge() -> void:
	var paving := StandardMaterial3D.new()
	paving.albedo_texture = load(PAVER)
	paving.albedo_color = Color(0.84, 0.83, 0.8)
	paving.uv1_triplanar = true
	paving.uv1_world_triplanar = true
	paving.uv1_scale = Vector3.ONE * 0.4
	paving.roughness = 0.88
	var kerb := StandardMaterial3D.new()
	kerb.albedo_texture = load(CURB_ALBEDO)
	kerb.albedo_color = Color(0.9, 0.9, 0.88)
	kerb.uv1_triplanar = true
	kerb.uv1_world_triplanar = true
	kerb.uv1_scale = Vector3.ONE * 0.8
	kerb.roughness = 0.8
	var body := StaticBody3D.new()
	body.name = "VergeCollision"
	add_child(body)
	# North and south strips own the corners, so no two boxes overlap.
	var strips: Array[Rect2] = [Rect2(-222, -182, 444, 2), Rect2(-222, 180, 162, 2), Rect2(-222, -180, 2, 360), Rect2(220, -180, 2, 360)]
	var mesh := BoxMesh.new()
	var mm_paving: Array[Transform3D] = []
	var mm_kerb: Array[Transform3D] = []
	for strip: Rect2 in strips:
		var c := strip.get_center()
		# Flush with the park ground (top at +1.5 cm), so a player crawling out of
		# a fence hole lands on it rather than against its edge.
		mm_paving.append(Transform3D(Basis.from_scale(Vector3(strip.size.x, 0.18, strip.size.y)), Vector3(c.x, VERGE_TOP - 0.09, c.y)))
		# The kerb runs along the road side of the strip.
		var long_x := strip.size.x > strip.size.y
		var edge := (c.y + (-1.0 if c.y < 0.0 else 1.0) * (strip.size.y * 0.5 - 0.08)) if long_x else (c.x + (-1.0 if c.x < 0.0 else 1.0) * (strip.size.x * 0.5 - 0.08))
		var kerb_at := Vector3(c.x, 0.03, edge) if long_x else Vector3(edge, 0.03, c.y)
		var kerb_size := Vector3(strip.size.x, 0.2, 0.16) if long_x else Vector3(0.16, 0.2, strip.size.y)
		mm_kerb.append(Transform3D(Basis.from_scale(kerb_size), kerb_at))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(strip.size.x, 0.2, strip.size.y)
		shape.shape = box
		shape.position = Vector3(c.x, VERGE_TOP - 0.1, c.y)
		body.add_child(shape)
	for pair: Array in [["VergePaving", mm_paving, paving], ["VergeKerb", mm_kerb, kerb]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var rows: Array[Transform3D] = pair[1]
		mm.instance_count = rows.size()
		for i: int in range(rows.size()): mm.set_instance_transform(i, rows[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = pair[0]
		instance.multimesh = mm
		instance.material_override = pair[2]
		add_child(instance)
