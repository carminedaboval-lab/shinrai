extends RefCounted

# Kept separate from run state: carried loot is never persisted before extraction.
const VERSION := 1
var save_path := "user://shinrai_extraction_v1.json"
var data: Dictionary = defaults()
var last_error := ""
var recovered_interrupted_run := false
var saving_disabled := false

static func defaults() -> Dictionary:
	return {"version": VERSION, "credits": 0, "stash": {}, "runs": 0,
		"extracts": 0, "pack_level": 0, "prepared_medkit": false, "active_run": false}

func load_profile() -> void:
	data = defaults()
	last_error = ""
	saving_disabled = false
	recovered_interrupted_run = false
	if not FileAccess.file_exists(save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not _valid_profile(parsed):
		last_error = "Save could not be read. Original file kept; saving is disabled."
		saving_disabled = true
		return
	for key: String in data:
		if parsed.has(key) and typeof(parsed[key]) == typeof(data[key]):
			data[key] = parsed[key]
	# JSON numbers are floats even when the saved value was an integer.
	for key: String in ["credits", "runs", "extracts", "pack_level"]:
		if parsed.get(key) is float or parsed.get(key) is int:
			data[key] = maxi(0, int(parsed[key]))
	data.pack_level = mini(data.pack_level, 2)
	recovered_interrupted_run = data.active_run
	if recovered_interrupted_run:
		data.active_run = false
		save_profile()

func _valid_profile(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if not _valid_count(value.get("version")) or int(value.version) != VERSION:
		return false
	for key: String in ["credits", "runs", "extracts", "pack_level"]:
		if not _valid_count(value.get(key)):
			return false
	for key: String in ["prepared_medkit", "active_run"]:
		if not value.get(key) is bool:
			return false
	if not value.get("stash") is Dictionary:
		return false
	for key: Variant in value.stash:
		if not key is String or key.is_empty() or not _valid_count(value.stash[key]):
			return false
	return true

func _valid_count(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	# Keep JSON integers exact and reject fractional/negative/corrupt balances.
	return is_finite(float(value)) and value >= 0 and value <= 9007199254740991 and float(value) == floorf(float(value))

func save_profile() -> bool:
	if saving_disabled:
		return false
	last_error = ""
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Could not write the save. Your previous save is unchanged."
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "Could not finish writing the save. Your previous save is unchanged."
		return false
	var result := DirAccess.rename_absolute(temporary, save_path)
	if result != OK:
		last_error = "Could not replace the save. Your previous save is unchanged."
		return false
	return true

func begin_run() -> bool:
	if data.active_run:
		return false # An unsettled result must be saved before another deployment.
	var previous := data.duplicate(true)
	data.runs += 1
	data.active_run = true
	data.prepared_medkit = false
	if save_profile():
		recovered_interrupted_run = false
		return true
	data = previous
	return false

func complete_run(extracted: bool, bag: Array, bonus: int) -> bool:
	if not data.active_run:
		return false # Idempotent: a result screen cannot pay a second time.
	var previous := data.duplicate(true)
	data.active_run = false
	if extracted:
		data.extracts += 1
		data.credits += bonus
		for item: Dictionary in bag:
			var key: String = item.id
			data.stash[key] = int(data.stash.get(key, 0)) + 1
	if save_profile():
		return true
	data = previous
	return false

func buy_upgrade() -> bool:
	var level: int = data.pack_level
	if level >= 2:
		return false
	var price := 450 * (level + 1)
	if data.credits < price:
		return false
	data.credits -= price
	data.pack_level += 1
	if save_profile():
		return true
	data.credits += price
	data.pack_level -= 1
	return false

func buy_medkit() -> bool:
	if data.prepared_medkit or data.credits < 120:
		return false
	data.credits -= 120
	data.prepared_medkit = true
	if save_profile():
		return true
	data.credits += 120
	data.prepared_medkit = false
	return false

func sell_stash(prices: Dictionary) -> int:
	var total := 0
	for key: String in data.stash:
		total += int(data.stash[key]) * int(prices.get(key, 0))
	var previous := data.duplicate(true)
	data.credits += total
	data.stash.clear()
	if save_profile():
		return total
	data = previous
	return 0
