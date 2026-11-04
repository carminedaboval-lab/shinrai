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
	else: print("CITY_LAYOUT: pass -- export or -- verify")
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

func _fingerprint(city: Node3D) -> Dictionary:
	# A hash of every laid-out part, so two cities compare part by part. It reads the
	# city's own build data: a headless renderer hands no mesh data back.
	var parts := {"count":hash(city.get("_count")), "alleys":hash(str(city.alleys))}
	var rows: Dictionary = city.build_rows
	for layer: String in rows:
		for key: int in rows[layer]:
			parts["%s_%d" % [layer, key]] = hash(rows[layer][key])
	var walls: Dictionary = city.build_hero.walls()
	var panes: Dictionary = city.build_hero.glass()
	for key: int in walls: parts["shell_%d" % key] = hash(walls[key])
	for key: int in panes: parts["panes_%d" % key] = hash(panes[key])
	for child: Node in city.get_children():
		if child is MeshInstance3D or child is MultiMeshInstance3D: continue
		if child is Node3D:
			# Hand-built buildings get generated node names, so they are matched by order.
			var script: Script = child.get_script()
			var label := script.resource_path.get_file() if script != null else child.get_class()
			parts["node_%d_%s" % [child.get_index(), label]] = hash(str((child as Node3D).transform))
	return parts
