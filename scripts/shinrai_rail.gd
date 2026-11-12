extends Node3D

## The Midori line: rails on the ring road (west, north and east sides), ten stops, and one
## tram that shuttles end to end for the whole raid. A raid begins aboard it: the tram brakes at a stop the player
## did not choose and lets them off. To leave the city the player boards it again at any
## stop, with a relay recovered, and stays aboard when the doors close.
## extraction_run.gd owns the raid; it calls begin_raid() on deploy and raid_tick() every
## physics step of a live raid.

const Track := preload("res://scripts/shinrai_rail_track.gd")
const Tram := preload("res://scripts/shinrai_rail_tram.gd")

const CRUISE := 11.0
const ACCEL := 1.0
const BRAKE := 1.25
const DWELL_SECONDS := 24.0
const DOOR_SECONDS := 1.6
const ARRIVAL_RUN_IN := 105.0
const EXTRACT_SECONDS := 6.0
## A drop-off stop must be at least this far from every relay (the park's best loot sits by them).
const DROP_CLEARANCE := 70.0
const GAUGE := 1.435
const STOP_NAMES: Array[String] = ["Nishi 3", "Nishi 2", "Nishi 1", "Kita 1", "Kita 2", "Kita 3", "Kita 4", "Higashi 1", "Higashi 2", "Higashi 3"]

enum Mode { IDLE, RUN, OPENING, DWELL, CLOSING, EXTRACT }

var tram: Node3D
var stops: Array[float] = []
var mode: Mode = Mode.IDLE
var s := 0.0
var speed := 0.0
var next_stop := 0
## +1 runs west end to east end, -1 runs back.
var direction := 1
var timer := 0.0
var arrival := false
var arrival_stop := -1
var rider: CharacterBody3D
var _rider_car: Node3D
var _rider_local := Vector3.ZERO
var _rider_yaw := 0.0
var _rider_world := Vector3.ZERO
var _ticked := false
var _rumble: AudioStreamPlayer3D
var _chime: AudioStreamPlayer3D
var _doors: AudioStreamPlayer3D


func _init() -> void:
	name = "ShinraiRail"
	# After the player's own physics step, so a rider is pinned to where the tram is now.
	process_physics_priority = 1000
	for offset: float in [40.0, 150.0, 260.0]: stops.append(offset)
	for offset: float in [60.0, 165.0, 270.0, 375.0]: stops.append(Track.NORTH_START + offset)
	for offset: float in [67.5, 177.5, 287.5]: stops.append(Track.EAST_START + offset)


func _ready() -> void:
	_build_rails()
	for index: int in stops.size():
		_build_stop_post(index)
	tram = Tram.new()
	add_child(tram)
	tram.place(stops[0])
	_rumble = _speaker(_rumble_stream(), 9.0, 140.0)
	_chime = _speaker(_chime_stream(), 22.0, 420.0)
	_doors = _speaker(_door_stream(), 6.0, 60.0)


## Where a stop's waiting point is: on the road by the kerb, beside the lead car's front door.
func stop_ground(index: int) -> Vector3:
	return Track.frame_at(stops[index]) * Vector3(2.9, 0.1, Tram.DOOR_Z[0])


func stop_title(index: int) -> String:
	return "Tram stop · " + STOP_NAMES[index]


## Starts a raid aboard the tram, running in toward a stop picked at random among those
## that are not close to a relay.
func begin_raid(run: Node, rng: RandomNumberGenerator) -> void:
	var allowed: Array[int] = []
	for index: int in stops.size():
		var clear := true
		for site: Dictionary in run.sites:
			if site.get("kind", "") == "relay" and stop_ground(index).distance_to(site.position) < DROP_CLEARANCE:
				clear = false
		if clear: allowed.append(index)
	if allowed.is_empty():
		for index: int in stops.size(): allowed.append(index)
	arrival_stop = allowed[rng.randi_range(0, allowed.size() - 1)]
	next_stop = arrival_stop
	# Run in from whichever end leaves room; either way when both do.
	var from_west := stops[arrival_stop] - ARRIVAL_RUN_IN >= 18.0
	var from_east := stops[arrival_stop] + ARRIVAL_RUN_IN <= Track.length() - 8.0
	direction = 1 if from_west and (not from_east or rng.randf() < 0.5) else -1
	s = stops[arrival_stop] - ARRIVAL_RUN_IN * float(direction)
	speed = CRUISE
	mode = Mode.RUN
	arrival = true
	timer = 0.0
	tram.set_doors(0.0)
	tram.place(s)
	var player := run.player as CharacterBody3D
	var car: Node3D = tram.cars[0]
	_hold(player, car, Vector3(0.15, Tram.FLOOR_Y + 0.03, Tram.DOOR_Z[0] - 0.2))
	var ahead: Vector3 = car.global_transform * Vector3(4.0, Tram.FLOOR_Y, Tram.DOOR_Z[0] - 3.0 * float(direction))
	player.look_at(Vector3(ahead.x, player.global_position.y, ahead.z))
	_rider_yaw = _yaw(car)


func raid_tick(run: Node, delta: float) -> void:
	_ticked = true
	var player := run.player as CharacterBody3D
	var total := Track.length()
	match mode:
		Mode.RUN:
			var left := maxf(0.0, (stops[next_stop] - s) * float(direction))
			var target := minf(CRUISE, sqrt(2.0 * BRAKE * left) + 0.3)
			# Someone on the rails ahead: brake and wait for them to move.
			if _track_blocked(player): target = 0.0
			speed = move_toward(speed, target, (ACCEL if target > speed else BRAKE * 2.0) * delta)
			var step := minf(speed * delta, left)
			s += step * float(direction)
			if left - step <= 0.02 and target > 0.0:
				speed = 0.0
				mode = Mode.OPENING
				timer = 0.0
				_chime.play()
				_doors.play()
		Mode.OPENING:
			timer += delta
			tram.set_doors(timer / DOOR_SECONDS)
			if timer >= DOOR_SECONDS:
				mode = Mode.DWELL
				timer = 0.0
				if arrival:
					_release()
					run.run_time = 0.0
					run.remaining = run.RAID_SECONDS
					run.announce("%s · this is your stop" % STOP_NAMES[next_stop], 4.0)
		Mode.DWELL:
			timer += delta
			var aboard: bool = tram.car_holding(player.global_position) != null
			var closing_in := ceili(maxf(0.0, DWELL_SECONDS - timer))
			if arrival:
				if (not aboard and player.global_position.distance_to(tram.cars[0].global_position) > 6.0) or timer > 45.0:
					arrival = false
					timer = maxf(timer, DWELL_SECONDS - 5.0) if timer <= DWELL_SECONDS else DWELL_SECONDS
			elif aboard:
				run.prompt_text = ("Stay aboard to leave the city · doors close in %d s" % closing_in) if run.relays > 0 else "Extraction locked · recover a relay"
			elif player.global_position.distance_to(stop_ground(next_stop)) < 14.0:
				run.prompt_text = ("Tram boarding · doors close in %d s" % closing_in) if run.relays > 0 else "Tram · recover a relay to ride out"
			if timer >= DWELL_SECONDS and not arrival:
				if aboard and run.relays == 0:
					timer = DWELL_SECONDS - 3.0
				elif not aboard and timer < DWELL_SECONDS + 8.0 and tram.door_blocked(player.global_position):
					pass # Someone is in the doorway: hold the doors a little longer.
				else:
					mode = Mode.CLOSING
					timer = 0.0
					_chime.play()
					_doors.play()
		Mode.CLOSING:
			timer += delta
			tram.set_doors(1.0 - timer / DOOR_SECONDS)
			if timer >= DOOR_SECONDS:
				var car: Node3D = tram.car_holding(player.global_position)
				timer = 0.0
				if car != null and run.relays == 0:
					# Slipped aboard without a relay as the doors shut: open again, do not carry them off.
					mode = Mode.OPENING
					_doors.play()
				else:
					# Turn back at either end of the line.
					if next_stop + direction < 0 or next_stop + direction >= stops.size(): direction = -direction
					next_stop += direction
					if car != null:
						_hold(player, car, car.global_transform.affine_inverse() * player.global_position)
						mode = Mode.EXTRACT
					else:
						mode = Mode.RUN
		Mode.EXTRACT:
			timer += delta
			speed = move_toward(speed, CRUISE, ACCEL * delta)
			s = clampf(s + speed * delta * float(direction), 18.0, total - 6.0)
			run.prompt_text = "Leaving the city"
			run.progress_ratio = clampf(timer / EXTRACT_SECONDS, 0.0, 1.0)
			if timer >= EXTRACT_SECONDS:
				var held_car := _rider_car
				var held_local := _rider_local
				run.finish_run(true, "You rode the tram out of the city.")
				if run.phase == run.Phase.PAUSED and run.pending_result_save.is_empty():
					# Refused (a reserved magazine needs space): stay sealed and try again on resume.
					if held_car != null and rider == null: _hold(player, held_car, held_local)
				else:
					mode = Mode.IDLE
					speed = 0.0
	tram.place(s)
	_pin()


func _physics_process(_delta: float) -> void:
	_pin()
	if _rumble != null:
		var moving := _ticked and speed > 0.2
		if moving and not _rumble.playing: _rumble.play()
		elif not moving and _rumble.playing: _rumble.stop()
		if moving:
			_rumble.volume_db = lerpf(-16.0, 0.0, clampf(speed / CRUISE, 0.0, 1.0))
			_rumble.pitch_scale = lerpf(0.7, 1.0, clampf(speed / CRUISE, 0.0, 1.0))
	_ticked = false


## True once the doors have shut on a rider who is leaving the city.
func rider_committed() -> bool:
	return mode == Mode.EXTRACT


## True when the player stands on the rails close ahead of the moving tram.
func _track_blocked(player: CharacterBody3D) -> bool:
	if player == rider: return false
	var lead: Node3D = tram.cars[0] if direction > 0 else tram.cars[1]
	var local := lead.global_transform.affine_inverse() * player.global_position
	var ahead := -local.z * float(direction) - Tram.HALF_L
	var reach := speed * speed / (2.0 * BRAKE * 2.0) + 2.5
	return ahead > -0.5 and ahead < reach and absf(local.x) < Tram.HALF_W + 0.45 and local.y > -0.6 and local.y < 3.2


## Lets go of a rider when the raid ends some other way (death, abandon).
func release_rider() -> void:
	_release()


func _hold(player: CharacterBody3D, car: Node3D, local: Vector3) -> void:
	rider = player
	_rider_car = car
	_rider_local = local
	_rider_yaw = _yaw(car)
	_rider_world = car.global_transform * local
	player.global_position = _rider_world
	_pin()


func _release() -> void:
	rider = null
	_rider_car = null


func _pin() -> void:
	if rider == null or not is_instance_valid(rider) or _rider_car == null: return
	# Something else moved the rider (a test, a respawn): let go instead of dragging them back.
	if rider.global_position.distance_to(_rider_world) > 2.0:
		_release()
		arrival = false
		return
	# Hold the rider across the floor only; their own physics keeps them standing on it.
	var target := _rider_car.global_transform * _rider_local
	var height := rider.global_position.y
	if absf(height - target.y) > 0.5: height = target.y
	_rider_world = Vector3(target.x, height, target.z)
	rider.global_position = _rider_world
	rider.velocity = Vector3(0.0, rider.velocity.y, 0.0)
	var yaw := _yaw(_rider_car)
	rider.rotation.y += angle_difference(_rider_yaw, yaw)
	_rider_yaw = yaw


func _yaw(node: Node3D) -> float:
	return node.global_transform.basis.get_euler().y


func _build_rails() -> void:
	var steel := StandardMaterial3D.new()
	# Worn rail head set in asphalt: dark, only a dull sheen (a mirror finish reads as a painted blue line).
	steel.albedo_color = Color(0.17, 0.17, 0.175)
	steel.metallic = 0.35
	steel.roughness = 0.62
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	var total := Track.length() - 2.0
	for side: float in [-0.5, 0.5]:
		var distance := 2.0
		var previous := Track.frame_at(distance)
		while distance < total:
			var step := 0.6 if (Track.on_corner(distance) or Track.on_corner(distance + 6.0)) else 6.0
			var next_distance := minf(distance + step, total)
			var following := Track.frame_at(next_distance)
			var a := previous * Vector3(side * GAUGE - 0.035, 0.012, 0.0)
			var b := previous * Vector3(side * GAUGE + 0.035, 0.012, 0.0)
			var c := following * Vector3(side * GAUGE - 0.035, 0.012, 0.0)
			var d := following * Vector3(side * GAUGE + 0.035, 0.012, 0.0)
			for corner: Vector3 in [a, c, b, b, c, d]:
				tool.add_vertex(corner)
			previous = following
			distance = next_distance
	var rails := MeshInstance3D.new()
	rails.name = "Rails"
	rails.mesh = tool.commit()
	rails.material_override = steel
	rails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rails)


## A stop post on the kerb: steel pole, round sign, and a lit name panel.
func _build_stop_post(index: int) -> void:
	var post := Node3D.new()
	post.name = "Stop_%s" % STOP_NAMES[index].replace(" ", "_")
	add_child(post)
	post.global_transform = Track.frame_at(stops[index]) * Transform3D(Basis.IDENTITY, Vector3(3.85, 0.08, Tram.DOOR_Z[0] - 2.2))
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.30, 0.31, 0.32)
	steel.metallic = 0.7
	steel.roughness = 0.4
	var pole := CylinderMesh.new()
	pole.top_radius = 0.038
	pole.bottom_radius = 0.038
	pole.height = 2.7
	pole.radial_segments = 12
	var pole_instance := MeshInstance3D.new()
	pole_instance.mesh = pole
	pole_instance.material_override = steel
	pole_instance.position = Vector3(0.0, 1.35, 0.0)
	post.add_child(pole_instance)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.24
	disc.bottom_radius = 0.24
	disc.height = 0.03
	disc.radial_segments = 28
	var face := StandardMaterial3D.new()
	face.albedo_color = Color(0.16, 0.30, 0.27)
	face.roughness = 0.5
	var disc_instance := MeshInstance3D.new()
	disc_instance.mesh = disc
	disc_instance.material_override = face
	disc_instance.position = Vector3(0.0, 2.52, 0.0)
	disc_instance.rotation.x = PI * 0.5
	post.add_child(disc_instance)
	var panel := BoxMesh.new()
	panel.size = Vector3(0.05, 0.42, 0.62)
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(0.86, 0.86, 0.82)
	lit.emission_enabled = true
	lit.emission = Color(0.95, 0.93, 0.85)
	lit.emission_energy_multiplier = 0.55
	var panel_instance := MeshInstance3D.new()
	panel_instance.mesh = panel
	panel_instance.material_override = lit
	panel_instance.position = Vector3(0.0, 1.85, 0.0)
	post.add_child(panel_instance)
	for facing: float in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = "MIDORI LINE\n%s" % STOP_NAMES[index].to_upper()
		label.font_size = 40
		label.pixel_size = 0.0021
		label.modulate = Color(0.08, 0.1, 0.1)
		label.outline_size = 0
		label.shaded = false
		label.position = Vector3(facing * 0.027, 1.85, 0.0)
		label.rotation.y = facing * PI * 0.5
		post.add_child(label)
		var mark := Label3D.new()
		mark.text = "TRAM"
		mark.font_size = 44
		mark.pixel_size = 0.0021
		mark.modulate = Color(0.9, 0.9, 0.86)
		mark.outline_size = 0
		mark.shaded = false
		mark.position = Vector3(0.0, 2.52, facing * 0.017)
		mark.rotation.y = 0.0 if facing > 0.0 else PI
		post.add_child(mark)


func _speaker(stream: AudioStream, unit: float, reach: float) -> AudioStreamPlayer3D:
	var speaker := AudioStreamPlayer3D.new()
	speaker.stream = stream
	speaker.unit_size = unit
	speaker.max_distance = reach
	speaker.position = Vector3(0.0, 1.6, 0.0)
	tram.cars[0].add_child(speaker)
	return speaker


func _wave(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index: int in samples.size():
		bytes.encode_s16(index * 2, int(clampf(samples[index], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	return stream


## Rolling rumble: low hum plus smoothed noise, cross-faded so the loop has no click.
func _rumble_stream() -> AudioStreamWAV:
	var rate := 22050
	var count := rate * 3
	var noise := RandomNumberGenerator.new()
	noise.seed = 5150
	var raw := PackedFloat32Array()
	raw.resize(count + rate)
	var low := 0.0
	var lower := 0.0
	for index: int in raw.size():
		low = lerpf(low, noise.randf_range(-1.0, 1.0), 0.045)
		lower = lerpf(lower, low, 0.02)
		var t := float(index) / float(rate)
		raw[index] = low * 0.9 + lower * 2.2 + sin(TAU * 46.0 * t) * 0.09 + sin(TAU * 92.0 * t) * 0.04
	var samples := PackedFloat32Array()
	samples.resize(count)
	for index: int in count:
		var value := raw[index]
		if index < rate:
			var blend := float(index) / float(rate)
			value = raw[index] * blend + raw[index + count] * (1.0 - blend)
		samples[index] = value * 0.75
	return _wave(samples, true)


## Two soft bell notes, the door chime heard across the district.
func _chime_stream() -> AudioStreamWAV:
	var rate := 22050
	var samples := PackedFloat32Array()
	samples.resize(int(rate * 1.9))
	for note: Array in [[0.0, 783.99], [0.55, 622.25]]:
		var start := int(float(note[0]) * rate)
		for index: int in range(start, samples.size()):
			var t := float(index - start) / float(rate)
			var envelope := exp(-t * 3.2) * minf(1.0, t * 180.0)
			samples[index] += (sin(TAU * note[1] * t) * 0.5 + sin(TAU * note[1] * 2.0 * t) * 0.14 + sin(TAU * note[1] * 3.01 * t) * 0.05) * envelope
	return _wave(samples, false)


## Air-driven door: a short breath of filtered noise.
func _door_stream() -> AudioStreamWAV:
	var rate := 22050
	var noise := RandomNumberGenerator.new()
	noise.seed = 77
	var samples := PackedFloat32Array()
	samples.resize(int(rate * 1.5))
	var smooth := 0.0
	for index: int in samples.size():
		var t := float(index) / float(rate)
		smooth = lerpf(smooth, noise.randf_range(-1.0, 1.0), 0.35)
		samples[index] = smooth * 0.34 * minf(1.0, t * 12.0) * exp(-t * 2.6)
	return _wave(samples, false)
