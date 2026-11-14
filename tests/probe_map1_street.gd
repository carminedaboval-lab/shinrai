extends SceneTree
## Headless check of the Map 1 trial street edge (kerb, gutter, footway on one side):
##   godot --headless --path . --script res://tests/probe_map1_street.gd
## Prints STREET_PASS / STREET_FAIL lines and STREET_DONE passed=N failed=M.

const Blockout := preload("res://scripts/map1/map1_blockout.gd")
const Street := preload("res://scripts/map1/map1_street.gd")
const Player := preload("res://scripts/player.gd")

## The game's own player body and step-up code, cut down as tests/probe_house.gd does it:
## no weapon, no HUD, moved by this probe.
class RealPlayer extends "res://scripts/player.gd":
	func _ready() -> void:
		collision_layer = 1
		collision_mask = 3
		_build_collision()
		_build_camera()
		floor_snap_length = STEP_HEIGHT + 0.03
		set_physics_process(false)
		set_process(false)
		set_process_unhandled_input(false)


var passed := 0
var failed := 0
var map: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("STREET_%s %s" % ["PASS" if ok else "FAIL", text])


func _run() -> void:
	map = Blockout.new()
	map.with_player = false
	root.add_child(map)
	for i: int in 4: await physics_frame
	_check(map.street_edges.filter(func(edge: Node3D) -> bool: return edge.get_meta("edge").name == "homes street trial").size() == 2, "both edges of the original homes trial are built")
	if map.street_edges.is_empty():
		_done()
		return
	var street: Node3D = map.street_edges[0]
	var total := 0.0
	var text := ""
	for run: Vector2 in street.runs:
		total += run.y - run.x
		text += "  %.1f to %.1f m (x %.1f to %.1f)" % [run.x, run.y, street.at(run.x, 0.0).x, street.at(run.y, 0.0).x]
	_check(street.runs.size() >= 1 and total > 40.0, "stretches built, %.1f m in all, %d units, %d triangles, 1 draw call:%s" % [total, street.units, street.triangles, text])

	# Sizes, measured off the built mesh with rays straight down.
	var run: Vector2 = street.runs[street.runs.size() - 1]
	var s := (run.x + run.y) * 0.5
	var road := _down(street.at(s, street.half - 1.0))
	var kerb := _down(street.at(s, street.half + Street.KERB_WIDE * 0.5))
	var foot := _down(street.at(s, street.half + street.footway_wide - 0.3))
	var behind := _down(street.at(s, street.half + street.footway_wide + 0.3))
	_check(absf(kerb - road - Street.KERB_HIGH) < 0.005, "the kerb's top stands %.1f cm above the road (wanted %.0f)" % [(kerb - road) * 100.0, Street.KERB_HIGH * 100.0])
	_check(absf(foot - kerb) < 0.005, "the footway is level with the kerb's top: %.1f cm apart" % [absf(foot - kerb) * 100.0])
	_check(absf(behind - road) < 0.02, "behind the footway the ground is the plot's own again: %.1f cm from road level" % [(behind - road) * 100.0])
	_check(is_equal_approx(Street.GUTTER_WIDE, 0.22) and is_equal_approx(Street.KERB_WIDE, 0.14), "gutter %.0f cm wide, kerb %.0f cm wide, footway %.2f m from the kerb's face to its back" % [Street.GUTTER_WIDE * 100.0, Street.KERB_WIDE * 100.0, street.footway_wide])

	# The faces show from outside: the mesh's top faces point up, the kerb's face at the road.
	var mesh: Mesh = (street.get_node("Edge") as MeshInstance3D).mesh
	var arrays := mesh.surface_get_arrays(0)
	var places: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var up := 0
	var down := 0
	var to_road := 0
	var from_road := 0
	var out: Vector3 = ((street.at(s, 1.0) as Vector3) - (street.at(s, 0.0) as Vector3)).normalized()
	var tints: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i: int in places.size():
		if not (_same(tints[i], Street.CONCRETE) or _same(tints[i], Street.FOOTWAY)): continue      # the kerb, gutter and footway
		if normals[i].y > 0.9: up += 1
		elif normals[i].y < -0.9: down += 1
		if normals[i].dot(out) < -0.9: to_road += 1
	for i: int in places.size():
		if normals[i].dot(out) > 0.9: from_road += 1
	_check(up > 0 and down == 0, "tops face up: %d corners up, %d down" % [up, down])
	_check(to_road > 0 and from_road > 0, "the kerb's face looks at the road (%d corners) and the footway's back looks at the plots (%d)" % [to_road, from_road])

	# No stretch runs across a road, a side street or the turning circle.
	var crossed := 0
	for each: Vector2 in street.runs:
		var here := each.x
		while here <= each.y:
			if street._road(here, street.half + 0.5) or street._road(here, street.half + street.footway_wide - 0.3): crossed += 1
			here += 0.3
	_check(crossed == 0, "no stretch lies over a side street or the turning circle: %d samples on road" % crossed)

	# No building stands on the footway.
	var hit := 0
	for each: Vector2 in street.runs:
		var here := each.x
		while here <= each.y:
			for across: float in [street.half + 0.3, street.half + street.footway_wide - 0.1]:
				var point: Vector3 = street.at(here, across, 0.6)
				if absf(here - street.pole_at) < 0.6: continue      # the pole stands there, and should
				var query := PhysicsPointQueryParameters3D.new()
				query.position = point
				if not root.world_3d.direct_space_state.intersect_point(query, 1).is_empty(): hit += 1
			here += 0.5
	_check(hit == 0, "nothing solid stands on the footway: %d of the samples 60 cm above it are inside something" % hit)

	# A real player walks from the road over the kerb, across the footway and off its back,
	# then back again.
	var player := RealPlayer.new()
	root.add_child(player)
	var start: Vector3 = street.at(s, street.half - 1.6, 0.05)
	var end: Vector3 = street.at(s, street.half + street.footway_wide + 1.4, 0.05)
	player.global_position = start
	for i: int in 30: await physics_frame
	# His feet's height while standing on something: lowest (the road, the plot) and highest.
	var peak := [-INF, INF]
	var reached := await _walk(player, end, func() -> void:
		if not player.is_on_floor(): return
		peak[0] = maxf(float(peak[0]), player.global_position.y)
		peak[1] = minf(float(peak[1]), player.global_position.y))
	var highest := float(peak[0])
	start.y = float(peak[1])
	_check(reached, "a player walks from the road up the kerb, over the footway and down its back: ended %.2f m from the far point" % Vector2(player.global_position.x - end.x, player.global_position.z - end.z).length())
	_check(highest - start.y > Street.KERB_HIGH - 0.06 and highest - start.y < Street.KERB_HIGH + 0.2, "on the footway his feet stood %.0f cm above the road" % [(highest - start.y) * 100.0])
	var back := await _walk(player, start, func() -> void: pass)
	_check(back, "and walks back down onto the road: ended %.2f m from where he began" % Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length())
	await _surface_checks(street, places, normals, arrays[Mesh.ARRAY_COLOR])
	# Along the footway, behind the pole: no snag on the unit joints, and room to pass it.
	var a: Vector3 = street.at(run.x + 1.0, street.half + 1.05, 0.2)
	var b: Vector3 = street.at(run.y - 1.0, street.half + 1.05, 0.2)
	player.global_position = a
	for i: int in 20: await physics_frame
	var along := await _walk(player, b, func() -> void: pass, 3000)
	_check(along, "and walks the footway's whole length, %.0f m: ended %.2f m from its far end" % [a.distance_to(b), Vector2(player.global_position.x - b.x, player.global_position.z - b.z).length()])
	await _entrance_checks(street, player)
	if map.street_edges.size() > 1: await _other_side_checks(map.street_edges[1], player)
	_done()


## The asphalt and its white line, the drain grate and the utility pole (ROAD-003).
func _surface_checks(street: Node3D, places: PackedVector3Array, normals: PackedVector3Array, colours: PackedColorArray) -> void:
	var asphalt := street.get_node_or_null("Asphalt") as MeshInstance3D
	_check(asphalt != null and asphalt.mesh.get_surface_count() == 2, "the asphalt is laid: %d surfaces (with the white line, and without it at the side streets)" % (asphalt.mesh.get_surface_count() if asphalt != null else 0))
	if asphalt != null:
		var up := 0
		var all := 0
		var out_low := INF
		var out_high := -INF
		var lift_low := INF
		var lift_high := -INF
		var north_overlap := 0
		for surface: int in asphalt.mesh.get_surface_count():
			var arrays := asphalt.mesh.surface_get_arrays(surface)
			var at: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var facing: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			for i: int in at.size():
				all += 1
				if facing[i].y > 0.9: up += 1
				out_low = minf(out_low, uv[i].x)
				out_high = maxf(out_high, uv[i].x)
				for run: Vector2 in map.street_edges[1].runs:
					if uv[i].y > run.x + 0.001 and uv[i].y < run.y - 0.001 and uv[i].x < -street.half + Street.GUTTER_WIDE - 0.001:
						north_overlap += 1
				var lift: float = at[i].y - float(map.ground_height(at[i].x, at[i].z))
				lift_low = minf(lift_low, lift)
				lift_high = maxf(lift_high, lift)
		_check(up == all and all > 0, "the asphalt faces up: %d of %d corners" % [up, all])
		_check(absf(out_low + street.half) < 0.001 and absf(out_high - street.half) < 0.001, "it covers the road's width, %.2f m to %.2f m from the centre line (the road is %.2f m wide), measured in metres for the paint" % [out_low, out_high, street.half * 2.0])
		_check(lift_low > 0.005 and lift_high < Street.GUTTER_LIP, "it follows the ground: %.1f to %.1f cm above it everywhere, under the gutter's edge at %.1f cm" % [lift_low * 100.0, lift_high * 100.0, Street.GUTTER_LIP * 100.0])
		_check(north_overlap == 0, "asphalt clears the lowered bed of the north gutter: %d overlapping vertices" % north_overlap)
		var line: float = street.line_out
		var gutter: float = street.half - Street.GUTTER_WIDE
		_check(line + Street.LINE_WIDE * 0.5 < gutter and gutter - (line + Street.LINE_WIDE * 0.5) < 0.05, "the white line, %.0f cm wide, lies beside the gutter: its edge %.1f cm from the gutter's" % [Street.LINE_WIDE * 100.0, (gutter - line - Street.LINE_WIDE * 0.5) * 100.0])
		var with_line := asphalt.mesh.surface_get_material(0) as ShaderMaterial
		_check(with_line != null and is_equal_approx(float(with_line.get_shader_parameter("edge_line_offset")), line) and with_line.get_shader_parameter("aggregate") != null, "the asphalt material has its stone texture and the line's place: %.3f m" % line)

	# The grate: in a built stretch, in the gutter, flush.
	var in_run := false
	for each: Vector2 in street.runs:
		if street.grate_at >= each.x and street.grate_at + Street.UNIT <= each.y: in_run = true
	var iron := 0
	var iron_high := -INF
	var iron_out_low := INF
	var iron_out_high := -INF
	var base: Vector3 = street.at(street.grate_at, 0.0)
	var across: Vector3 = ((street.at(street.grate_at, 1.0) as Vector3) - base).normalized()
	for i: int in places.size():
		if not _same(colours[i], Street.IRON): continue
		iron += 1
		iron_high = maxf(iron_high, places[i].y - base.y)
		var out := (places[i] - base).dot(across)
		iron_out_low = minf(iron_out_low, out)
		iron_out_high = maxf(iron_out_high, out)
	_check(in_run and iron > 0, "one drain grate, %.1f m along the street (x %.1f), inside a built stretch" % [street.grate_at, base.x])
	_check(absf(iron_high - Street.GUTTER_LIP) < 0.001 and iron_out_low > street.half - Street.GUTTER_WIDE - 0.001 and iron_out_high < street.half + 0.001, "it sits in the gutter and flush with it: its top %.1f cm above the road (the gutter's edge is %.1f), from %.2f to %.2f m out (the gutter is %.2f to %.2f)" % [iron_high * 100.0, Street.GUTTER_LIP * 100.0, iron_out_low, iron_out_high, street.half - Street.GUTTER_WIDE, street.half])

	# The pole: on the footway, grounded, solid, with room to walk past.
	var foot: Vector3 = street.at(street.pole_at, street.pole_out)
	var shaft := 0
	var outward := 0
	var lowest := INF
	var highest := -INF
	for i: int in places.size():
		if not _same(colours[i], Street.POLE_CONCRETE): continue
		shaft += 1
		lowest = minf(lowest, places[i].y)
		highest = maxf(highest, places[i].y)
		var from_axis := Vector3(places[i].x - foot.x, 0.0, places[i].z - foot.z)
		if from_axis.length() < 0.01 or normals[i].dot(from_axis.normalized()) > 0.5 or normals[i].y > 0.9: outward += 1
	var footway_top: float = street.top(street.pole_at)
	_check(shaft > 0 and outward == shaft, "the pole's faces show from outside: %d of %d corners" % [outward, shaft])
	_check(absf(lowest - footway_top) < 0.001 and absf(highest - lowest - Street.POLE_HIGH) < 0.001, "it stands on the footway, not in the air or the ground: its foot %.1f cm from the footway's top, %.1f m tall" % [(lowest - footway_top) * 100.0, highest - lowest])
	var clear: float = street.half + street.footway_wide - street.pole_out - Street.POLE_FOOT_RADIUS
	_check(clear >= 0.9, "behind the pole %.2f m of footway is left to walk on (at least 0.90)" % clear)
	var ray := PhysicsRayQueryParameters3D.create(foot + Vector3(0.0, 1.0, 0.0) - across * 1.2, foot + Vector3(0.0, 1.0, 0.0) + across * 1.2)
	var hit := root.world_3d.direct_space_state.intersect_ray(ray)
	_check(not hit.is_empty() and absf(Vector2(hit.position.x - foot.x, hit.position.z - foot.z).length() - Street.POLE_FOOT_RADIUS) < 0.02, "the pole is solid: a line across it at 1 m stops at its face")
	await physics_frame


## The lowered kerb at a house's gate (ROAD-003, the first entrance).
func _entrance_checks(street: Node3D, player: CharacterBody3D) -> void:
	var gates: Array = map._gates_near(map.data.street_edges[0])
	var mine: Array = gates.filter(func(gate: Vector3) -> bool: return street.out_of(gate) > street.half)
	_check(street.drops.size() == 1 and not mine.is_empty(), "one lowered kerb, and a house with a gate on this side to put it at: %d lowered, %d gates on this side of %d along the street" % [street.drops.size(), mine.size(), gates.size()])
	if street.drops.is_empty() or mine.is_empty(): return
	var gate: Vector3 = mine[0]
	var drop: Vector2 = street.drops[0]
	var middle := (drop.x + drop.y) * 0.5
	var gate_along: float = street.along_of(gate)
	# The house, and the opening between its gate pillars as its own plan built it.
	var world: Node3D = map.world
	var house := -1
	var gap := INF
	for index: int in world.candidates:
		var here := Vector2(float(map.data.boxes[index][0]) - gate.x, float(map.data.boxes[index][2]) - gate.z).length()
		if here < gap:
			gap = here
			house = index
	var site: Dictionary = world.site(house)
	var frame: Transform3D = site.frame
	var pillars: Array[float] = []
	var wall_out := 0.0
	for block: Array in site.spec.blocks:
		var size: Vector3 = block[1]
		if is_equal_approx(size.x, 0.28) and is_equal_approx(size.z, 0.28) and (block[0] as Vector3).z < -0.2:
			pillars.append(float(street.along_of(frame * (block[0] as Vector3))))
			wall_out = float(street.out_of(frame * (block[0] as Vector3)))
	pillars.sort()
	_check(pillars.size() == 2, "the house at x %.1f (box %d) has its two gate pillars: found %d, standing %.2f m from the centre line" % [float(map.data.boxes[house][0]), house, pillars.size(), wall_out])
	if pillars.size() != 2: return
	var open_from := pillars[0] + 0.14
	var open_to := pillars[1] - 0.14
	_check(drop.x <= open_from + 0.001 and drop.y >= open_to - 0.001, "the lowered kerb, %.2f to %.2f m along (x %.2f to %.2f), covers the gate's opening, %.2f to %.2f m (%.2f m wide); their middles are %.2f m apart" % [drop.x, drop.y, street.at(drop.x, 0.0).x, street.at(drop.y, 0.0).x, open_from, open_to, open_to - open_from, absf(middle - (open_from + open_to) * 0.5)])
	var road := _down(street.at(middle, street.half - 1.0))
	var kerb := _down(street.at(middle, street.half + Street.KERB_WIDE * 0.5))
	var foot := _down(street.at(middle, street.half + 0.8))
	var ramp := float(Street.RAMP_UNITS) * Street.UNIT
	var full := _down(street.at(drop.x - ramp - 0.3, street.half + 0.8))
	var half_way := _down(street.at(drop.x - ramp * 0.5, street.half + 0.8))
	_check(absf(kerb - road - Street.DROP_HIGH) < 0.005 and absf(foot - road - Street.DROP_HIGH) < 0.005, "there the kerb stands %.1f cm above the road and the footway %.1f cm (wanted %.0f)" % [(kerb - road) * 100.0, (foot - road) * 100.0, Street.DROP_HIGH * 100.0])
	_check(absf(full - road - Street.KERB_HIGH) < 0.005 and absf(half_way - road - (Street.KERB_HIGH + Street.DROP_HIGH) * 0.5) < 0.01, "to either side the footway slopes back up over %.1f m: %.1f cm half way, %.1f cm beyond (a slope of 1 in %.0f)" % [ramp, (half_way - road) * 100.0, (full - road) * 100.0, ramp / (Street.KERB_HIGH - Street.DROP_HIGH)])
	_check(wall_out < street.half + street.footway_wide + 0.6 and wall_out > street.half + Street.KERB_WIDE + 0.8, "the gate stands at the footway's back: %.2f m from the centre line, the footway runs from %.2f to %.2f" % [wall_out, street.half + Street.KERB_WIDE, street.half + street.footway_wide])

	# The house is made for real (its wall and pillars are solid), then the player walks in
	# at the gate and out again.
	var camera := Camera3D.new()
	root.add_child(camera)
	var way_in := (open_from + open_to) * 0.5
	var start: Vector3 = street.at(way_in, street.half - 1.6, 0.05)
	camera.global_position = start + Vector3.UP * 1.6
	player.global_position = start
	world.set_viewer(camera, player)
	var waited := 0
	while int(world.level_of(house)) != 2 and waited < 1200:      # 2: the full house
		await physics_frame
		waited += 1
	_check(int(world.level_of(house)) == 2, "the house is built in full for the walk (after %d frames)" % waited)
	for i: int in 20: await physics_frame
	var inside: Vector3 = street.at(way_in, wall_out + 1.0, 0.05)
	var peak := [-INF, INF]
	var went_in := await _walk(player, inside, func() -> void:
		camera.global_position = player.global_position + Vector3.UP * 1.6
		if not player.is_on_floor(): return
		peak[0] = maxf(float(peak[0]), player.global_position.y)
		peak[1] = minf(float(peak[1]), player.global_position.y))
	_check(went_in, "a player walks from the road in at the gate, to 1 m inside the wall: ended %.2f m from that point" % Vector2(player.global_position.x - inside.x, player.global_position.z - inside.z).length())
	_check(float(peak[0]) - float(peak[1]) < Street.DROP_HIGH + 0.03, "on the way his feet rose %.1f cm at most (the kerb elsewhere is %.0f cm)" % [(float(peak[0]) - float(peak[1])) * 100.0, Street.KERB_HIGH * 100.0])
	var went_out := await _walk(player, start, func() -> void: camera.global_position = player.global_position + Vector3.UP * 1.6)
	_check(went_out, "and walks out again onto the road: ended %.2f m from where he began" % Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length())
	# A pillar is solid: the same walk aimed at a pillar is stopped.
	var blocked: Vector3 = street.at(pillars[1], wall_out + 1.0, 0.05)
	player.global_position = street.at(pillars[1], street.half - 1.6, 0.05)
	for i: int in 10: await physics_frame
	var through := await _walk(player, blocked, func() -> void: pass, 300)
	_check(not through, "and a walk aimed at a gate pillar is stopped by it, so the way in really is the opening")
	world.set_viewer(null, null)
	camera.queue_free()


## The other side of the street (the north side): kerb, gutter and footway only, with lowered
## kerbs where a car crosses; and on both sides, no garden wall left standing on a footway.
func _other_side_checks(street: Node3D, player: CharacterBody3D) -> void:
	var total := 0.0
	var text := ""
	var longest := Vector2.ZERO
	for run: Vector2 in street.runs:
		total += run.y - run.x
		text += "  x %.1f to %.1f" % [street.at(run.x, 0.0).x, street.at(run.y, 0.0).x]
		if run.y - run.x > longest.y - longest.x: longest = run
	_check(street.runs.size() >= 1 and total > 40.0, "the other side: %.1f m in %d stretches, %d units, %d triangles, 1 draw call:%s" % [total, street.runs.size(), street.units, street.triangles, text])
	_check(street.get_node_or_null("Asphalt") == null and float(street.grate_at) < 0.0 and float(street.pole_at) < 0.0, "it lays no second road surface, white line, grate or pole: the road keeps its one ribbon and its one line")
	var crossed := 0
	for each: Vector2 in street.runs:
		var here := each.x
		while here <= each.y:
			if street._road(here, street.half + 0.5) or street._road(here, street.half + street.footway_wide - 0.3): crossed += 1
			here += 0.3
	_check(crossed == 0, "no stretch lies over a side street or the turning circle: %d samples on road" % crossed)
	# Sizes, clear of any lowered kerb.
	var s := longest.x + 3.0
	var road := _down(street.at(s, street.half - 1.0))
	var kerb := _down(street.at(s, street.half + Street.KERB_WIDE * 0.5))
	var foot := _down(street.at(s, street.half + street.footway_wide - 0.3))
	_check(absf(kerb - road - Street.KERB_HIGH) < 0.005 and absf(foot - kerb) < 0.005, "its kerb stands %.1f cm above the road and its footway is level with the kerb's top (%.1f cm apart)" % [(kerb - road) * 100.0, absf(foot - kerb) * 100.0])
	var mesh: Mesh = (street.get_node("Edge") as MeshInstance3D).mesh
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var out: Vector3 = ((street.at(s, 1.0) as Vector3) - (street.at(s, 0.0) as Vector3)).normalized()
	var up := 0
	var down := 0
	var to_road := 0
	for i: int in normals.size():
		if normals[i].y > 0.9: up += 1
		elif normals[i].y < -0.9: down += 1
		if normals[i].dot(out) < -0.9: to_road += 1
	_check(up > 0 and down == 0 and to_road > 0, "its faces show from outside though it is the mirror: %d corners up, %d down, %d facing the road" % [up, down, to_road])

	# Lowered kerbs: where a car crosses.
	var where := ""
	var low := true
	for drop: Vector2 in street.drops:
		var middle := (drop.x + drop.y) * 0.5
		var here := _down(street.at(middle, street.half + 0.8)) - _down(street.at(middle, street.half - 1.0))
		if absf(here - Street.DROP_HIGH) > 0.005: low = false
		where += "  x %.1f to %.1f (%.1f m, footway %.1f cm above the road)" % [street.at(drop.x, 0.0).x, street.at(drop.y, 0.0).x, drop.y - drop.x, here * 100.0]
	var wanted: Array = map._carports_near(map.data.street_edges[0]).filter(func(entry: Dictionary) -> bool: return float(street.plot_gap(entry.at)) < INF)
	var parks: Array = street.car_parks(4.2)
	_check(street.drops.size() == wanted.size() + parks.size() and low, "a lowered kerb at each place a car crosses, %d carports and %d parking plots, and none at a footpath gate: %d lowered:%s" % [wanted.size(), parks.size(), street.drops.size(), where])

	# On both sides: every house that fronts a built footway keeps its wall and pillars off it.
	var world: Node3D = map.world
	var fronting := 0
	var on_footway := 0
	var nearest := INF
	var note := ""
	for index: int in map._houses_near(map.data.street_edges[0]):
		var site: Dictionary = world.site(index)
		if not bool(site.ok): continue
		var frame: Transform3D = site.frame
		var front: Vector3 = frame * Vector3(float(site.size.x) * 0.5, 0.0, 0.0)
		for edge: Node3D in map.street_edges:
			if float(edge.plot_gap(front)) == INF: continue
			fronting += 1
			var back: float = edge.half + edge.footway_wide
			for block: Array in site.spec.blocks:
				var at: Vector3 = block[0]
				var size: Vector3 = block[1]
				if at.z > -0.2 or size.y < 0.6: continue
				var face: float = float(edge.out_of(frame * at)) - size.z * 0.5
				nearest = minf(nearest, face - back)
				if face < back - 0.005:
					on_footway += 1
					if note.length() < 200: note += "  box %d: %.2f m inside" % [index, back - face]
	_check(fronting > 0 and on_footway == 0, "of the %d houses fronting a footway (both sides), no wall, pillar or post stands on it: %d pieces do; the nearest stands %.2f m behind the footway's back%s" % [fronting, on_footway, nearest, note])

	# Walking: road, kerb, footway, plot and back; then the footway's length.
	var start: Vector3 = street.at(s, street.half - 1.6, 0.05)
	var end: Vector3 = street.at(s, street.half + street.footway_wide + 1.2, 0.05)
	player.global_position = start
	for i: int in 20: await physics_frame
	var peak := [-INF, INF]
	var reached := await _walk(player, end, func() -> void:
		if not player.is_on_floor(): return
		peak[0] = maxf(float(peak[0]), player.global_position.y)
		peak[1] = minf(float(peak[1]), player.global_position.y))
	var back_again := await _walk(player, start, func() -> void: pass)
	_check(reached and back_again and absf(float(peak[0]) - float(peak[1]) - Street.KERB_HIGH) < 0.03, "a player walks from the road up the other kerb, over the footway onto the plot and back, his feet %.0f cm above the road on the footway" % [(float(peak[0]) - float(peak[1])) * 100.0])
	var a: Vector3 = street.at(longest.x + 1.0, street.half + 0.85, 0.2)
	var b: Vector3 = street.at(longest.y - 1.0, street.half + 0.85, 0.2)
	player.global_position = a
	for i: int in 20: await physics_frame
	var along := await _walk(player, b, func() -> void: pass, 3000)
	_check(along, "and walks that footway's longest stretch, %.0f m, through its lowered kerbs: ended %.2f m from its far end" % [a.distance_to(b), Vector2(player.global_position.x - b.x, player.global_position.z - b.z).length()])


## Two colours alike, as a mesh keeps them (8 bits a channel).
func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func _done() -> void:
	print("STREET_DONE passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)


## The height of the first thing under a point (from 3 m above the ground there).
func _down(point: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3.0, point + Vector3.DOWN * 3.0)
	var hit := root.world_3d.direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else -INF


## Pushes the player's own movement towards a point. True when he gets within 35 cm.
func _walk(player: CharacterBody3D, target: Vector3, each: Callable, limit := 600) -> bool:
	for i: int in limit:
		var gap := Vector3(target.x - player.global_position.x, 0.0, target.z - player.global_position.z)
		if gap.length() < 0.35: return true
		var push := gap.normalized() * 3.0
		player.velocity.x = push.x
		player.velocity.z = push.z
		player.velocity.y = 0.0 if player.is_on_floor() else player.velocity.y - 9.8 / 60.0
		player.move_and_slide()
		if player.is_on_wall(): player._try_step_up(Vector3(push.x, 0.0, push.z) / 60.0)
		each.call()
		await physics_frame
	return false
