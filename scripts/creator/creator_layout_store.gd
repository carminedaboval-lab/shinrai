extends RefCounted
## JSON-only layout persistence. Callers own catalog/world-revision validation.
## Saves never remove the primary before replacing it with a verified sibling temp.

const SCHEMA_VERSION := 1
const MAX_RECORDS := 50000
const MAX_FILE_BYTES := 33554432
const MAX_ID_LENGTH := 512
const MAX_TEXT_LENGTH := 256
const MAX_POSITION := 100000.0
const MAX_BASIS_COMPONENT := 1000.0
const MAX_CAMERA_YAW := 1000000.0
const MIN_BASIS_DETERMINANT := 0.000000001
var _last_replace_error := ""


func save_layout(path: String, layout: Dictionary) -> Dictionary:
	var path_error := _path_error(path)
	if not path_error.is_empty():
		return _failure(path_error)
	var checked := validate_layout(layout)
	if not checked.ok:
		return checked
	var absolute_path := ProjectSettings.globalize_path(path).simplify_path()
	var backup_path := absolute_path + ".bak"
	var primary_bytes := PackedByteArray()
	var has_primary := FileAccess.file_exists(absolute_path)
	if DirAccess.dir_exists_absolute(absolute_path) or DirAccess.dir_exists_absolute(backup_path):
		return _failure("A folder occupies the layout or backup filename; choose another layout filename.")
	if has_primary:
		var previous := _read_layout(absolute_path)
		if not previous.ok:
			return _failure("Existing layout was preserved because it could not be validated: %s Save to a new filename to keep both versions." % previous.error)
		primary_bytes = previous.bytes
	if FileAccess.file_exists(backup_path):
		var previous_backup := _read_layout(backup_path)
		if not previous_backup.ok:
			return _failure("Existing backup was preserved because it could not be validated: %s Save to a new filename." % previous_backup.error)
	var bytes := JSON.stringify(checked.layout, "\t", true, true).to_utf8_buffer()
	if bytes.size() > MAX_FILE_BYTES:
		return _failure("Layout exceeds the %d-byte save limit." % MAX_FILE_BYTES)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK:
		return _failure("Cannot create the creator layout folder (error %d)." % directory_error)
	var temporary_path := _temporary_path(absolute_path)
	var written := _write_verified(temporary_path, bytes)
	if not written.ok:
		_remove_owned_temporary(temporary_path)
		return written
	# The previous valid primary becomes the last-good backup. On the first save,
	# retain an existing valid recovery backup, or seed a backup with the new data.
	if has_primary or not FileAccess.file_exists(backup_path):
		var backup_bytes: PackedByteArray = primary_bytes if has_primary else bytes
		var backup_temporary := _temporary_path(backup_path)
		var backup_written := _write_verified(backup_temporary, backup_bytes)
		if not backup_written.ok:
			_remove_owned_temporary(temporary_path)
			_remove_owned_temporary(backup_temporary)
			return _failure("Layout was not replaced: backup preparation failed. " + str(backup_written.error))
		var backup_error := _replace_temporary(backup_temporary, backup_path)
		if backup_error != OK:
			_remove_owned_temporary(temporary_path)
			_remove_owned_temporary(backup_temporary)
			return _failure("Layout was not replaced: cannot replace the last-good backup (error %d). %s" % [backup_error, _last_replace_error])
	var replace_error := _replace_temporary(temporary_path, absolute_path)
	if replace_error != OK:
		_remove_owned_temporary(temporary_path)
		return _failure("Cannot replace the layout (error %d). The previous layout and last-good backup were preserved. %s" % [replace_error, _last_replace_error])
	var committed := _read_layout(absolute_path)
	if not committed.ok or committed.get("bytes", PackedByteArray()) != bytes:
		return _failure("The replacement could not be verified. Keep edits unsaved and recover from the last-good backup. " + str(committed.error))
	return {"ok": true, "error": "", "layout": committed.layout, "path": absolute_path,
		"backup_path": backup_path, "recovered": false, "primary_error": "", "warning": ""}


func load_layout(path: String) -> Dictionary:
	var path_error := _path_error(path)
	if not path_error.is_empty():
		return _failure(path_error)
	var absolute_path := ProjectSettings.globalize_path(path).simplify_path()
	var primary := _read_layout(absolute_path)
	if primary.ok:
		primary.erase("bytes")
		primary.merge({"source_path": absolute_path, "recovered": false, "primary_error": "", "warning": ""})
		return primary
	var backup_path := absolute_path + ".bak"
	var backup := _read_layout(backup_path)
	if not backup.ok:
		return _failure("Layout could not be loaded: %s Last-good backup could not be loaded: %s" % [primary.error, backup.error])
	return {"ok": true, "error": str(primary.error), "primary_error": str(primary.error), "layout": backup.layout,
		"source_path": backup_path, "recovered": true,
		"warning": "Recovered the last-good backup. The original layout file was left untouched. Save to a new filename if the original is corrupt."}


func encode_transform(value: Transform3D) -> Array:
	return [value.basis.x.x, value.basis.x.y, value.basis.x.z,
		value.basis.y.x, value.basis.y.y, value.basis.y.z,
		value.basis.z.x, value.basis.z.y, value.basis.z.z,
		value.origin.x, value.origin.y, value.origin.z]


func decode_transform(data: Array) -> Transform3D:
	# Public API keeps the agreed Transform3D return type. Invalid input is a caller
	# programming error, not a usable identity transform: validate before calling.
	var error := _transform_error(data)
	if not error.is_empty():
		push_error("Creator layout transform was not validated: " + error)
		return Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
	return _decode_valid_transform(data)


func validate_layout(layout: Dictionary) -> Dictionary:
	var error := _keys_error(layout, ["version", "world_revision", "layout_name", "overrides", "additions", "camera"],
		["version", "world_revision", "layout_name", "overrides", "additions"])
	if not error.is_empty():
		return _failure("Layout " + error)
	if not _is_number(layout.version) or float(layout.version) != SCHEMA_VERSION:
		return _failure("Unsupported creator layout version; expected %d." % SCHEMA_VERSION)
	if not _valid_text(layout.world_revision, MAX_ID_LENGTH):
		return _failure("world_revision must be a nonempty string of at most %d characters." % MAX_ID_LENGTH)
	if not _valid_text(layout.layout_name, MAX_TEXT_LENGTH):
		return _failure("layout_name must be a nonempty string of at most %d characters." % MAX_TEXT_LENGTH)
	if not layout.overrides is Array or not layout.additions is Array:
		return _failure("overrides and additions must be arrays.")
	if layout.overrides.size() + layout.additions.size() > MAX_RECORDS:
		return _failure("Layout exceeds the %d-object limit." % MAX_RECORDS)
	var seen_ids: Dictionary = {}
	for collection_name: String in ["overrides", "additions"]:
		var records: Array = layout[collection_name]
		for index in records.size():
			var record: Variant = records[index]
			if not record is Dictionary:
				return _failure("%s[%d] must be an object." % [collection_name, index])
			var allowed: Array = ["id", "transform", "visible"]
			if collection_name == "additions":
				allowed.append("asset_id")
			error = _keys_error(record, allowed, allowed)
			if not error.is_empty():
				return _failure("%s[%d] %s" % [collection_name, index, error])
			if not _valid_text(record.id, MAX_ID_LENGTH):
				return _failure("%s[%d] has an invalid object id." % [collection_name, index])
			if seen_ids.has(record.id):
				return _failure("Duplicate object id '%s'; IDs must be unique across overrides and additions." % record.id)
			seen_ids[record.id] = true
			if collection_name == "additions" and not _valid_text(record.asset_id, MAX_ID_LENGTH):
				return _failure("additions[%d] has an invalid asset_id." % index)
			if not record.visible is bool:
				return _failure("%s[%d].visible must be a boolean." % [collection_name, index])
			error = _transform_error(record.transform)
			if not error.is_empty():
				return _failure("%s[%d].transform %s" % [collection_name, index, error])
	if layout.has("camera"):
		if not layout.camera is Dictionary:
			return _failure("camera must be an object when supplied.")
		var camera: Dictionary = layout.camera
		if not camera.is_empty():
			error = _keys_error(camera, ["position", "yaw", "pitch"], ["position", "yaw", "pitch"])
			if not error.is_empty():
				return _failure("camera " + error)
			if not camera.position is Array or camera.position.size() != 3:
				return _failure("camera.position must contain three numbers.")
			for component: Variant in camera.position:
				if not _finite_bounded(component, MAX_POSITION):
					return _failure("camera.position contains a non-finite or out-of-bounds coordinate.")
			if not _finite_bounded(camera.yaw, MAX_CAMERA_YAW) or not _finite_bounded(camera.pitch, PI / 2.0 + 0.001):
				return _failure("camera yaw/pitch is non-finite or outside the supported angle bounds.")
	var normalized: Dictionary = layout.duplicate(true)
	normalized.version = SCHEMA_VERSION
	return {"ok": true, "error": "", "layout": normalized}


func _keys_error(value: Dictionary, allowed: Array, required: Array) -> String:
	for key: Variant in value:
		if (not key is String and not key is StringName) or not allowed.has(str(key)):
			return "contains an unsupported field '%s'." % str(key)
	for key: String in required:
		if not value.has(key):
			return "is missing '%s'." % key
	return ""


func _valid_text(value: Variant, maximum: int) -> bool:
	if not value is String or value.length() > maximum or value.strip_edges().is_empty():
		return false
	for index in value.length():
		if value.unicode_at(index) < 32 or value.unicode_at(index) == 127:
			return false
	return true


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _finite_bounded(value: Variant, bound: float) -> bool:
	return _is_number(value) and is_finite(float(value)) and absf(float(value)) <= bound


func _transform_error(data: Variant) -> String:
	if not data is Array or data.size() != 12:
		return "must contain twelve basis-column/origin numbers."
	for index in 12:
		if not _finite_bounded(data[index], MAX_BASIS_COMPONENT if index < 9 else MAX_POSITION):
			return "contains a non-finite, nonnumeric or out-of-bounds component at index %d." % index
	var value := _decode_valid_transform(data)
	if absf(value.basis.determinant()) < MIN_BASIS_DETERMINANT:
		return "has a singular or unsupported near-zero basis."
	return ""


func _decode_valid_transform(data: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(float(data[0]), float(data[1]), float(data[2])),
		Vector3(float(data[3]), float(data[4]), float(data[5])),
		Vector3(float(data[6]), float(data[7]), float(data[8]))),
		Vector3(float(data[9]), float(data[10]), float(data[11])))


func _path_error(path: String) -> String:
	if path.is_empty():
		return "Choose a creator layout filename."
	if path.begins_with("res://") or (not path.begins_with("user://") and not path.is_absolute_path()):
		return "Creator layouts require a user:// or absolute path; project resources are not writable layouts."
	if path.get_extension().to_lower() != "json":
		return "Creator layout filenames must end in .json."
	if path.get_file().to_lower() == "shinrai_extraction_v1.json":
		return "The gameplay profile is protected; choose a separate creator layout filename."
	return ""


func _read_layout(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("Cannot read '%s' (error %d)." % [path.get_file(), FileAccess.get_open_error()])
	var size := file.get_length()
	if size < 1 or size > MAX_FILE_BYTES:
		file.close()
		return _failure("'%s' is empty or exceeds the %d-byte limit." % [path.get_file(), MAX_FILE_BYTES])
	var bytes := file.get_buffer(size)
	var read_error := file.get_error()
	file.close()
	if bytes.size() != size or (read_error != OK and read_error != ERR_FILE_EOF):
		return _failure("Could not read all bytes of '%s'." % path.get_file())
	var parser := JSON.new()
	var parse_error := parser.parse(bytes.get_string_from_utf8())
	if parse_error != OK:
		return _failure("'%s' contains invalid JSON at line %d: %s" % [path.get_file(), parser.get_error_line(), parser.get_error_message()])
	if not parser.data is Dictionary:
		return _failure("'%s' does not contain a layout object." % path.get_file())
	var checked := validate_layout(parser.data)
	if not checked.ok:
		return _failure("'%s' failed validation: %s" % [path.get_file(), checked.error])
	checked.bytes = bytes
	return checked


func _write_verified(path: String, bytes: PackedByteArray) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure("Cannot create temporary layout file (error %d)." % FileAccess.get_open_error())
	var stored := file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if not stored or write_error != OK:
		return _failure("Cannot write and flush the temporary layout (error %d)." % write_error)
	var checked := _read_layout(path)
	if not checked.ok:
		return _failure("Temporary layout failed verification: " + str(checked.error))
	if checked.bytes != bytes:
		return _failure("Temporary layout byte verification failed; original layout was not replaced.")
	return {"ok": true, "error": ""}


func _temporary_path(path: String) -> String:
	var candidate := "%s.tmp-%d-%d-%d" % [path, OS.get_process_id(), Time.get_ticks_usec(), randi()]
	while FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(candidate):
		candidate += "x"
	return candidate


func _replace_temporary(from: String, to: String) -> Error:
	_last_replace_error = ""
	# Godot's Windows DirAccess rename implementation unlinks an existing target.
	# A fixed .NET File.Replace operation instead uses Windows' replacement API.
	# Only core-selected filesystem paths become escaped literals; JSON content is
	# never executable. EncodedCommand avoids command-line quoting ambiguities.
	if OS.get_name() == "Windows":
		var program := "$ErrorActionPreference='Stop'; try { $source='%s'; $destination='%s'; if ([System.IO.File]::Exists($destination)) { [System.IO.File]::Replace($source,$destination,[System.Management.Automation.Language.NullString]::Value,$true) } else { [System.IO.File]::Move($source,$destination) }; exit 0 } catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }" % [from.replace("'", "''"), to.replace("'", "''")]
		var arguments := PackedStringArray(["-NoLogo", "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-EncodedCommand", Marshalls.raw_to_base64(program.to_utf16_buffer())])
		var output: Array = []
		var executable := OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
		var result := OS.execute(executable, arguments, output, true, false)
		if result != 0:
			_last_replace_error = "Windows atomic replacement helper failed (exit %d): %s" % [result, " ".join(output).strip_edges()]
			return ERR_CANT_CREATE
		return OK
	# Sibling paths keep the POSIX rename on one filesystem. Never unlink `to`.
	return DirAccess.rename_absolute(from, to)


func _remove_owned_temporary(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "layout": {}}
