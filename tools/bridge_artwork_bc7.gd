extends SceneTree
## Offline, one-off: turns the uncompressed textures embedded in the lake-bridge artwork
## bundle into BC7 in place (about 134 MB of RGBA8 on the GPU -> about 34 MB). Same
## ImageTexture objects, same sub-resource ids, same pixel sizes and mip chains; only the
## pixel format changes, as with the BC7 texture imports. No game script changes.
## Run (from the repo root, with the game closed):
##   godot --headless --path . --script res://tools/bridge_artwork_bc7.gd
## BRIDGE_BC7_DRY=1 reports what it would do (with the quality numbers) and writes nothing.
## The original is first copied to user://bridge_artwork_v4.before_bc7.res; if the saved
## bundle does not hold exactly the same resources under the same ids, that copy is put back.
const PATH := "res://assets/shinrai/parks/midori_park/models/structures/measured/bridge_artwork_v4.res"
const BACKUP := "user://bridge_artwork_v4.before_bc7.res"

func _initialize() -> void:
	var dry := OS.get_environment("BRIDGE_BC7_DRY") == "1"
	# A compressed .res starts with RSCC, a plain one with RSRC: save it back the same way.
	var head := FileAccess.open(PATH, FileAccess.READ)
	if head == null:
		_fail("cannot open " + PATH)
		return
	var magic := head.get_buffer(4).get_string_from_ascii()
	var size_before := head.get_length()
	head.close()
	var bundle: Resource = ResourceLoader.load(PATH)
	if bundle == null:
		_fail("bundle did not load")
		return
	var before := _inventory(bundle)
	print("BRIDGE_BC7 file=%s bytes=%d resources=%d textures=%d" % [magic, size_before, before.ids.size(), before.textures.size()])
	var converted := 0
	var raw_bytes := 0
	var new_bytes := 0
	for texture: ImageTexture in before.textures:
		var image := texture.get_image()
		var label := "%s %dx%d" % [texture.resource_path.get_slice("::", 1), texture.get_width(), texture.get_height()]
		if image == null or image.is_empty():
			_fail(label + ": no image (run without --headless)")
			return
		if image.is_compressed():
			print("BRIDGE_BC7 skip %s: already format %d" % [label, image.get_format()])
			continue
		if image.get_width() % 4 != 0 or image.get_height() % 4 != 0 or image.get_width() < 16 or image.get_height() < 16:
			print("BRIDGE_BC7 skip %s: size not a multiple of 4, or tiny" % label)
			continue
		if image.get_format() != Image.FORMAT_RGB8 and image.get_format() != Image.FORMAT_RGBA8:
			print("BRIDGE_BC7 skip %s: format %d is not RGB8/RGBA8" % [label, image.get_format()])
			continue
		var mips := image.has_mipmaps()
		var was_format := image.get_format()
		raw_bytes += image.get_data().size()
		# Same steps the near-city wall textures take at run time (midori_near_city.gd).
		var packed: Image = image.duplicate()
		packed.convert(Image.FORMAT_RGBA8)
		var reference: Image = packed.duplicate()
		var err := packed.compress(Image.COMPRESS_BPTC)
		if err != OK or not packed.is_compressed() or packed.has_mipmaps() != mips or packed.get_size() != image.get_size():
			_fail("%s: BC7 compression failed (err %d, format %d)" % [label, err, packed.get_format()])
			return
		# How far the BC7 copy is from the original, top mip, for the record.
		var decoded: Image = packed.duplicate()
		decoded.decompress()
		decoded.convert(Image.FORMAT_RGBA8)
		var metrics := reference.compute_image_metrics(decoded, false)
		new_bytes += packed.get_data().size()
		print("BRIDGE_BC7 %s %s: format %d -> %d, mips=%s, %.2f -> %.2f MB, psnr=%.1f dB, max_error=%d" % [
			"would convert" if dry else "convert", label, was_format, packed.get_format(), mips,
			float(image.get_data().size()) / 1048576.0, float(packed.get_data().size()) / 1048576.0,
			float(metrics.get("peak_snr", 0.0)), int(metrics.get("max", 0))])
		if not dry: texture.set_image(packed)
		converted += 1
	print("BRIDGE_BC7 textures=%d %.1f -> %.1f MB" % [converted, float(raw_bytes) / 1048576.0, float(new_bytes) / 1048576.0])
	if dry or converted == 0:
		print("BRIDGE_BC7_RESULT %s nothing written" % ("DRY" if dry else "NOTHING_TO_DO"))
		quit(0)
		return
	var copy_err := DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(BACKUP))
	if copy_err != OK:
		_fail("could not back the bundle up to %s (err %d); nothing written" % [BACKUP, copy_err])
		return
	var save_err := ResourceSaver.save(bundle, PATH, ResourceSaver.FLAG_COMPRESS if magic == "RSCC" else ResourceSaver.FLAG_NONE)
	if save_err != OK:
		_restore("save failed (err %d)" % save_err)
		return
	# Read the file back from disk, not from the cache, and compare it with what was there:
	# the same resources under the same ids (the world fingerprint hashes those paths), the
	# same meshes, and the textures at the same sizes.
	var saved: Resource = ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if saved == null:
		_restore("saved bundle did not load")
		return
	var after := _inventory(saved)
	var problems := _compare(before, after)
	for texture: ImageTexture in after.textures:
		var image := texture.get_image()
		if image == null or image.is_empty(): problems.append("texture %s has no image after save" % texture.resource_path)
	if not problems.is_empty():
		for line: String in problems: print("BRIDGE_BC7_DIFF ", line)
		_restore("%d differences after save" % problems.size())
		return
	var size_after := FileAccess.open(PATH, FileAccess.READ).get_length()
	print("BRIDGE_BC7_RESULT PASS converted=%d ids_unchanged=%d file %d -> %d bytes, backup %s" % [converted, after.ids.size(), size_before, size_after, ProjectSettings.globalize_path(BACKUP)])
	quit(0)

func _fail(reason: String) -> void:
	print("BRIDGE_BC7_RESULT FAIL ", reason)
	quit(1)

func _restore(reason: String) -> void:
	var err := DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP), ProjectSettings.globalize_path(PATH))
	print("BRIDGE_BC7_RESULT FAIL %s; original put back (err %d)" % [reason, err])
	quit(1)

## Every resource stored in the bundle: {"ids": {path or key: signature}, "textures": [ImageTexture]}.
## The signature is the class, plus the size for textures and the surface geometry for meshes;
## the pixel format is left out on purpose, it is the one thing meant to change.
func _inventory(bundle: Resource) -> Dictionary:
	var out := {"ids": {}, "textures": []}
	_walk(bundle, {}, out)
	return out

func _walk(value: Variant, seen: Dictionary, out: Dictionary) -> void:
	match typeof(value):
		TYPE_ARRAY:
			for item: Variant in value: _walk(item, seen, out)
		TYPE_DICTIONARY:
			for key: Variant in value:
				_walk(key, seen, out)
				_walk(value[key], seen, out)
		TYPE_OBJECT:
			if not (value is Resource): return
			var resource := value as Resource
			var id := resource.get_instance_id()
			if seen.has(id): return
			seen[id] = true
			var path := resource.resource_path
			var inside := path == PATH or path.begins_with(PATH + "::")
			if path != "" and not inside:
				# A file of its own (shader, external texture): referenced, not stored here.
				out.ids["ext " + path] = resource.get_class()
				return
			var key := path if path != "" else "unsaved %s #%d" % [resource.get_class(), out.ids.size()]
			var signature: Array = [resource.get_class()]
			if resource is Texture2D:
				signature.append((resource as Texture2D).get_size())
				if resource is ImageTexture:
					var image := (resource as ImageTexture).get_image()
					signature.append(image.has_mipmaps() if image != null else false)
					out.textures.append(resource)
			elif resource is ArrayMesh:
				var mesh := resource as ArrayMesh
				for s: int in range(mesh.get_surface_count()):
					var arrays := mesh.surface_get_arrays(s)
					signature.append([mesh.surface_get_format(s), mesh.surface_get_array_len(s), mesh.surface_get_array_index_len(s), hash(arrays[Mesh.ARRAY_VERTEX]), hash(arrays[Mesh.ARRAY_TEX_UV])])
			out.ids[key] = signature
			for property: Dictionary in resource.get_property_list():
				if int(property.usage) & PROPERTY_USAGE_STORAGE == 0: continue
				_walk(resource.get(String(property.name)), seen, out)

func _compare(before: Dictionary, after: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for key: String in before.ids:
		if not after.ids.has(key): problems.append("missing after save: " + key)
		elif str(after.ids[key]) != str(before.ids[key]): problems.append("changed: %s %s -> %s" % [key, before.ids[key], after.ids[key]])
	for key: String in after.ids:
		if not before.ids.has(key): problems.append("new after save: " + key)
	return problems
