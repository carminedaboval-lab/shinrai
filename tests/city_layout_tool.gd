extends SceneTree
## Saves the near city's fixed layout, or checks that the city built from it matches
## the generator exactly.
## Save:   godot --headless --path . --script res://tests/city_layout_tool.gd -- export
## Check:  godot --headless --path . --script res://tests/city_layout_tool.gd -- verify
const City := preload("res://scripts/midori_near_city.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "export" in args: await _export()
	elif "verify" in args: await _verify()
	elif "profile" in args: _profile()
	elif "stream" in args: await _stream()
	else: print("CITY_LAYOUT: pass -- export, -- verify, -- profile or -- stream")
	quit()

func _build(record: bool) -> Node3D:
	# The city lays itself out in _ready, which runs once it is in the tree.
	var city: Node3D = City.new()
	city.record_layout = record
	city.keep_build_data = true
	root.add_child(city)
	if not city.is_node_ready(): await city.ready
	return city

func _export() -> void:
	var city := await _build(true)
	if city.layout.is_empty():
		print("CITY_LAYOUT_EXPORT: FAIL the generator recorded nothing")
		city.free()
		return
	var lines := PackedStringArray()
	lines.append("{\"version\":1,")
	lines.append("\"decks\":[")
	lines.append(",\n".join(_rows(city.layout_decks)))
	lines.append("],")
	lines.append("\"steps\":[")
	lines.append(",\n".join(_rows(city.layout)))
	lines.append("],")
	lines.append("\"alleys\":[")
	var alleys: Array = []
	for alley: Dictionary in city.alleys:
		var rect: Rect2 = alley.rect
		alleys.append({"rect":[rect.position.x, rect.position.y, rect.size.x, rect.size.y], "commercial":alley.commercial})
	lines.append(",\n".join(_rows(alleys)))
	lines.append("]}")
	var file := FileAccess.open(City.LAYOUT_PATH, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("CITY_LAYOUT_EXPORTED steps=%d decks=%d alleys=%d buildings=%d" % [city.layout.size(), city.layout_decks.size(), alleys.size(), city.get("_count")])
	city.free()

func _rows(items: Array) -> PackedStringArray:
	# One entry per line keeps the file readable and its diffs small.
	var out := PackedStringArray()
	for item: Variant in items: out.append(JSON.stringify(item, "", false, true))
	return out

func _verify() -> void:
	var live := await _build(true)
	var expected := _fingerprint(live)
	live.free()
	if not FileAccess.file_exists(City.LAYOUT_PATH):
		print("CITY_LAYOUT_VERIFY: FAIL no layout file")
		return
	var fixed := await _build(false)
	var actual := _fingerprint(fixed)
	fixed.free()
	var failures := 0
	for key: String in expected:
		if not actual.has(key): failures += 1; print("CITY_LAYOUT_MISSING ", key)
		elif actual[key] != expected[key]: failures += 1; print("CITY_LAYOUT_DIFFERS ", key)
	for key: String in actual:
		if not expected.has(key): failures += 1; print("CITY_LAYOUT_EXTRA ", key)
	print("CITY_LAYOUT_VERIFY: %s parts=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", expected.size(), failures])

func _stream() -> void:
	# Moves a camera to a far corner and back: tiles out of reach must be freed, and
	# the city must come back exactly as it was, built a few milliseconds a frame.
	var eye := Camera3D.new()
	root.add_child(eye)
	eye.current = true
	eye.position = Vector3(0, 2, 0)
	var city := await _build(false)
	var whole := _tiles_of(city)
	var memory := OS.get_static_memory_usage()
	city.load_radius = 200.0
	city.unload_radius = 300.0
	eye.position = Vector3(-560, 2, -560)
	city.set("_next_check", 0.0)
	await _settle(city)
	var corner := _tiles_of(city)
	var freed := (memory - OS.get_static_memory_usage()) / 1048576
	city.slow_steps.clear()
	city.load_radius = 900.0
	city.unload_radius = 1100.0
	eye.position = Vector3(0, 2, 0)
	city.set("_next_check", 0.0)
	var worst := await _settle(city)
	var back := _tiles_of(city)
	var ok := back.size() == whole.size() and corner.size() < whole.size()
	for key: int in whole:
		if back.get(key, -1) != whole[key]: ok = false
	for line: String in city.slow_steps: print("CITY_STREAM slow: ", line)
	print("CITY_STREAM: %s tiles whole=%d corner=%d back=%d, freed %d MB at the corner, worst frame while streaming %.1f ms" % ["PASS" if ok else "FAIL", whole.size(), corner.size(), back.size(), freed, worst])
	city.free()

func _settle(city: Node3D) -> float:
	# Runs frames until the city has checked the camera and finished building; returns the worst frame.
	var worst := 0.0
	var last := Time.get_ticks_usec()
	for frame: int in range(20000):
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		if frame > 2 and city.is_streaming_idle(): break
	await process_frame
	return worst

func _tiles_of(city: Node3D) -> Dictionary:
	# Each live tile with how many parts and buildings it holds.
	var out := {}
	for key: int in city.tiles:
		var tile: Node3D = city.tiles[key]
		if is_instance_valid(tile) and not tile.is_queued_for_deletion(): out[key] = tile.get_child_count()
	return out

func _profile() -> void:
	# Replays the layout outside the tree and times each step by its distance from
	# the park, to show where the city's build time goes. Hand-built buildings are
	# timed by instancing them in the tree.
	var city: Node3D = City.new()
	city.set("_tile", city)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(City.LAYOUT_PATH))
	var decks: Array = []
	for values: Array in data.decks:
		var deck: Array[int] = []
		for value: Variant in values: deck.append(int(value))
		decks.append(deck)
	var buckets := {}
	var rng: RandomNumberGenerator = city.get("_rng")
	for step: Dictionary in data.steps:
		rng.state = str(step.rng).to_int()
		var deck: Array[int] = city.get("_deck")
		deck.assign(decks[int(step.deck)])
		city.set("_dealt", int(step.dealt))
		var rect: Rect2 = city._rect_of(step.get("rect", step.block))
		var started := Time.get_ticks_usec()
		match str(step.t):
			"pave": city._add_pavement(city._rect_of(step.block))
			"tower": city._add_tower(city._rect_of(step.block))
			"lot": city._lay_lot(rect, city._rect_of(step.block), bool(step.commercial))
		var band := mini(int(city._park_distance(rect.get_center()) / 50.0) * 50, 400)
		if not buckets.has(band): buckets[band] = [0, 0]
		buckets[band][0] += Time.get_ticks_usec() - started
		buckets[band][1] += 1
	var keys := buckets.keys()
	keys.sort()
	for band: int in keys:
		print("CITY_PROFILE park distance %3d-%3s m: %5d steps, %6.0f ms" % [band, "+" if band == 400 else str(band + 50), buckets[band][1], buckets[band][0] / 1000.0])
	var total := 0
	for row: Array in City.HANDMADE:
		var script: GDScript = row[1]
		var started := Time.get_ticks_usec()
		var building: Node3D = script.new()
		root.add_child(building)
		total += Time.get_ticks_usec() - started
		building.free()
	print("CITY_PROFILE hand-built: %d buildings, %.0f ms" % [City.HANDMADE.size(), total / 1000.0])
	city.free()

func _fingerprint(city: Node3D) -> Dictionary:
	# Checksums of every laid-out part per layer, free of order and grouping, so a city
	# built tile by tile compares with one built in one pass. They come from the city's
	# own build data: a headless renderer hands no mesh data back.
	var parts := {"count":hash(city.get("_count")), "alleys":hash(str(city.alleys))}
	var audit: Dictionary = city.build_audit
	for layer: String in audit: parts["layer_" + layer] = hash(audit[layer])
	var placed: Array[String] = []
	for building: Node3D in city.get("_handmade"):
		placed.append("%s %s" % [building.get_script().resource_path.get_file(), building.global_transform])
	placed.sort()
	parts["handmade"] = hash(placed)
	return parts
