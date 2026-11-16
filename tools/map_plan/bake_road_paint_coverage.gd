extends SceneTree

# Reproducible CPU data baker, self-contained: no inherited staging scripts.
# Run through tools/godot_locked.ps1 with the Godot EDITOR executable, but do
# not add --editor. --headless --script runs this tool without an import scan.
#
# Default output is a scratch/prototype subdirectory under user://. It never
# defaults to an installed asset directory. Production regeneration requires
# an explicit --out=<absolute-or-res://asset-directory> argument.
# Example from the production project, after this tool has been installed:
# tools/godot_locked.ps1 -TimeoutSec 300 -Out <log-path> -GodotArgs
# '--headless --path . --script res://tools/map_plan/bake_road_paint_scalar_coverage.gd
#  -- --out=res://assets/environment/roads/shinrai_road/paint_coverage'
#
# Two independent grayscale masks avoid vector-packed BC7 channel distortion.
# Threshold raw source pixels in linear space, generate FLOAT mipmaps after
# thresholding, quantize the complete chains toRGB8, then CPU-compress toBC7.
# RGB repeats one scalar; alpha is opaque. Shader samplers omit source_color.
# The two endpoint planes are mixed as authored coverage; that mixture is not
# the exact intermediate nonlinear threshold curve or measured real aging.
#
# At2048x2048, twelve levels per plane require5,592,432 compressed bytes each:
#11,184,864 bytes total, about10.67MiB of texture payload. Runtime errors and
# paired heavy<=light ordering are MEASURED and recorded, never assumed exact.
# Primary source for this Godot4.7.2 pipeline:
# https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/core/io/image.cpp
# https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/scene/resources/portable_compressed_texture.cpp
# https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/cvtt/image_compress_cvtt.cpp

const SOURCE := "res://assets/environment/roads/shinrai_road/textures/SHINRAI_Road_FineAggregate_BaseColor_2K.png"
const SELF_DEADLINE_MS := 240000

var output := ""
var started := 0
var report := {}
var failed := false

func _initialize() -> void:
	started = Time.get_ticks_msec()
	output = ProjectSettings.globalize_path("user://road_paint_scalar_prototype")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			var requested_output := argument.trim_prefix("--out=")
			if requested_output.is_empty():
				_fail("--out requires a directory")
				return
			output = ProjectSettings.globalize_path(requested_output)
		else:
			_fail("unknown argument; only --out=<directory> is supported: " + argument)
			return
	if output.is_empty():
		_fail("output directory must not be empty")
		return
	_bake.call_deferred()

func _save_report() -> void:
	if not output.is_empty() and DirAccess.dir_exists_absolute(output):
		var file := FileAccess.open(output.path_join("bake.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))

func _fail(reason: String) -> void:
	failed = true
	report["status"] = "failed"
	report["failure"] = reason
	_save_report()
	push_error("ROAD_COVERAGE_BAKE FAIL " + reason)
	quit(1)

func _deadline() -> bool:
	if Time.get_ticks_msec() - started > SELF_DEADLINE_MS:
		_fail("CPU bake deadline expired")
	return failed

func _values(colour: Color) -> Array[float]:
	return [colour.r, colour.g, colour.b]

func _mip_image(image: Image, bytes: PackedByteArray, level: int) -> Image:
	var begin := image.get_mipmap_offset(level)
	var end := image.get_mipmap_offset(level + 1) if level < image.get_mipmap_count() else bytes.size()
	return Image.create_from_data(maxi(1, image.get_width() >> level),
		maxi(1, image.get_height() >> level), false, image.get_format(), bytes.slice(begin, end))

func _bc7_bytes(width: int, height: int) -> int:
	var size := 0
	var w := width
	var h := height
	while true:
		size += maxi(1, ceili(w / 4.0)) * maxi(1, ceili(h / 4.0)) * 16
		if w == 1 and h == 1:
			return size
		w = maxi(1, w >> 1)
		h = maxi(1, h >> 1)
	return size

func _audit_levels(reference: Image, quantized: Image, decoded: Image) -> Array[Dictionary]:
	var float_bytes := reference.get_data()
	var quantized_bytes := quantized.get_data()
	var decoded_bytes := decoded.get_data()
	var audits: Array[Dictionary] = []
	for level in reference.get_mipmap_count() + 1:
		var exact := _mip_image(reference, float_bytes, level)
		var raw8 := _mip_image(quantized, quantized_bytes, level)
		var bc7 := _mip_image(decoded, decoded_bytes, level)
		var sums := [0.0, 0.0, 0.0]
		var quant_sums := [0.0, 0.0, 0.0]
		var decoded_sums := [0.0, 0.0, 0.0]
		var abs_errors := [0.0, 0.0, 0.0]
		var max_errors := [0.0, 0.0, 0.0]
		var samples := 0
		var stride := maxi(1, ceili(exact.get_width() / 256.0))
		for y in range(stride >> 1, exact.get_height(), stride):
			for x in range(stride >> 1, exact.get_width(), stride):
				var a := _values(exact.get_pixel(x, y))
				var b := _values(raw8.get_pixel(x, y))
				var c := _values(bc7.get_pixel(x, y))
				for channel in 3:
					sums[channel] += a[channel]
					quant_sums[channel] += b[channel]
					decoded_sums[channel] += c[channel]
					var error := absf(c[channel] - a[channel])
					abs_errors[channel] += error
					max_errors[channel] = maxf(max_errors[channel], error)
				samples += 1
		for channel in 3:
			sums[channel] /= samples
			quant_sums[channel] /= samples
			decoded_sums[channel] /= samples
			abs_errors[channel] /= samples
		audits.append({"level": level, "size": [exact.get_width(), exact.get_height()],
			"sample_stride": stride, "samples": samples, "float_mean": sums.slice(0, 3),
			"rgb8_mean": quant_sums.slice(0, 3), "bc7_mean": decoded_sums.slice(0, 3),
			"bc7_mean_absolute_error": abs_errors.slice(0, 3),
			"bc7_max_absolute_error": max_errors.slice(0, 3)})
	return audits

func _pack_scalar(name: String, mask: Image, exact_mean: float) -> Dictionary:
	var error := mask.generate_mipmaps(false)
	if error != OK or not mask.has_mipmaps():
		_fail(name + " float mip generation failed")
		return {}
	var quantized := mask.duplicate() as Image
	quantized.convert(Image.FORMAT_RGB8)
	var compressed := quantized.duplicate() as Image
	error = compressed.compress(Image.COMPRESS_BPTC, Image.COMPRESS_SOURCE_GENERIC)
	var expected_bytes := _bc7_bytes(mask.get_width(), mask.get_height())
	if error != OK or compressed.get_format() != Image.FORMAT_BPTC_RGBA or compressed.get_data_size() != expected_bytes or compressed.get_mipmap_count() != mask.get_mipmap_count():
		_fail(name + " CPU BC7 compression unavailable or mip payload mismatch")
		return {}
	var decoded := compressed.duplicate() as Image
	error = decoded.decompress()
	if error != OK or decoded.get_mipmap_count() != mask.get_mipmap_count():
		_fail(name + " CPU BC7 decoding/mip validation unavailable")
		return {}
	var audits := _audit_levels(mask, quantized, decoded)
	var previous_keep := PortableCompressedTexture2D.is_keeping_all_compressed_buffers()
	PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)
	var texture := PortableCompressedTexture2D.new()
	texture.create_from_image(compressed, PortableCompressedTexture2D.COMPRESSION_MODE_BPTC)
	var payload: PackedByteArray = texture.get("_data")
	if payload.size() != expected_bytes + 20 or payload.decode_u32(4) != Image.FORMAT_BPTC_RGBA or payload.decode_u32(8) != mask.get_mipmap_count() + 1:
		PortableCompressedTexture2D.set_keep_all_compressed_buffers(previous_keep)
		_fail(name + " portable texture header/payload mismatch")
		return {}
	var path := output.path_join("road_paint_coverage_" + name + "_bc7.res")
	error = ResourceSaver.save(texture, path)
	PortableCompressedTexture2D.set_keep_all_compressed_buffers(previous_keep)
	if error != OK:
		_fail(name + " resource save failed: " + error_string(error))
		return {}
	var loaded := ResourceLoader.load(path, "PortableCompressedTexture2D", ResourceLoader.CACHE_MODE_IGNORE) as PortableCompressedTexture2D
	if loaded == null or loaded.get_width() != mask.get_width() or loaded.get_height() != mask.get_height() or loaded.get_compression_mode() != PortableCompressedTexture2D.COMPRESSION_MODE_BPTC:
		_fail(name + " saved resource failed reload/type/dimension/mode check")
		return {}
	return {"decoded": decoded, "manifest": {"resource": path,
		"resource_sha256": FileAccess.get_sha256(path), "exact_full_resolution_mean": exact_mean,
		"scalar_shader_channel": "r", "rgb_channels_repeat_the_same_linear_scalar": true,
		"alpha": 1.0, "compressed_payload_bytes": expected_bytes,
		"mip_levels_including_base": mask.get_mipmap_count() + 1,
		"runtime_instance_keep_compressed_buffer": loaded.keep_compressed_buffer,
		"mip_audit": audits}}

func _paired_monotonicity(light: Image, heavy: Image) -> Array[Dictionary]:
	var light_bytes := light.get_data()
	var heavy_bytes := heavy.get_data()
	var result: Array[Dictionary] = []
	for level in light.get_mipmap_count() + 1:
		var a := _mip_image(light, light_bytes, level)
		var b := _mip_image(heavy, heavy_bytes, level)
		var stride := maxi(1, ceili(a.get_width() / 256.0))
		var samples := 0
		var inversions := [0, 0, 0]
		var worst_excess := [0.0, 0.0, 0.0]
		var light_sum := 0.0
		var heavy_sum := 0.0
		for y in range(stride >> 1, a.get_height(), stride):
			for x in range(stride >> 1, a.get_width(), stride):
				var av := _values(a.get_pixel(x, y))
				var bv := _values(b.get_pixel(x, y))
				for channel in 3:
					var excess: float = bv[channel] - av[channel]
					worst_excess[channel] = maxf(worst_excess[channel], excess)
					if excess > 1.0 / 255.0:
						inversions[channel] += 1
				light_sum += av[0]
				heavy_sum += bv[0]
				samples += 1
		result.append({"level": level, "size": [a.get_width(), a.get_height()],
			"sample_stride": stride, "samples_per_channel": samples,
			"heavy_above_light_by_more_than_one_byte": inversions,
			"maximum_heavy_minus_light": worst_excess,
			"red_light_mean": light_sum / samples, "red_heavy_mean": heavy_sum / samples})
	return result

func _bake() -> void:
	if DisplayServer.get_name() != "headless" or not OS.has_feature("editor"):
		_fail("run the editor executable --headless for this CPU-only data bake")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("could not create scalar-mask staging directory")
		return
	var source_hash := FileAccess.get_sha256(SOURCE)
	var source := Image.load_from_file(SOURCE)
	if source == null or source.is_empty() or source.is_compressed() or source.get_width() != 2048 or source.get_height() != 2048:
		_fail("expected the existing raw2048x2048 aggregate PNG")
		return
	var light := Image.create_empty(2048, 2048, false, Image.FORMAT_RGBF)
	var heavy := Image.create_empty(2048, 2048, false, Image.FORMAT_RGBF)
	var light_sum := 0.0
	var heavy_sum := 0.0
	report = {"status": "running", "engine": Engine.get_version_info(),
		"baker_source_sha256": FileAccess.get_sha256(get_script().resource_path),
		"source": SOURCE, "source_sha256_before": source_hash, "size": [2048, 2048],
		"encoding": "two independent linear grayscale coverage planes,RGB repeated,alpha1",
		"damage_endpoints": {"light": 0.0, "heavy": 1.0},
		"operation_order": ["rawPNG sRGB-to-linear pixels", "threshold each scalar at full resolution",
			"generate float mipmaps after threshold", "quantize complete chain toRGB8",
			"CPU BC7 compression per plane", "save two self-contained PortableCompressedTexture2D resources"],
		"shader_interpretation": "Mix filtered endpoint coverage by authored damage. This mixture is not the exact intermediate nonlinear threshold curve.",
		"acceptance": "Packaging and error measurements only. Resources require compression/visual review before acceptance.",
		"planes": {}, "limitations": ["Coverage is authored from existing imagery, not measured literal road aging.",
			"BC7 is lossy; audit each plane and paired monotonicity before accepting the masks.",
			"Correct mip filtering still averages genuinely unresolved small chips."]}
	for y in 2048:
		for x in 2048:
			var linear := source.get_pixel(x, y).srgb_to_linear()
			var luma := linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722
			var a := smoothstep(0.014, 0.022, luma)
			var b := smoothstep(0.020, 0.028, luma)
			light.set_pixel(x, y, Color(a, a, a, 1.0))
			heavy.set_pixel(x, y, Color(b, b, b, 1.0))
			light_sum += a
			heavy_sum += b
		if y % 32 == 31:
			await process_frame
			if _deadline():
				return
	ProjectSettings.set_setting("rendering/textures/vram_compression/compress_with_gpu", false)
	var light_result := _pack_scalar("light", light, light_sum / (2048.0 * 2048.0))
	if failed:
		return
	report.planes["light"] = light_result.manifest
	if _deadline():
		return
	var heavy_result := _pack_scalar("heavy", heavy, heavy_sum / (2048.0 * 2048.0))
	if failed:
		return
	report.planes["heavy"] = heavy_result.manifest
	report["paired_monotonicity"] = _paired_monotonicity(light_result.decoded, heavy_result.decoded)
	report["source_sha256_after"] = FileAccess.get_sha256(SOURCE)
	if source_hash != report.source_sha256_after:
		_fail("source PNG changed during the scalar bake")
		return
	report["total_compressed_payload_bytes"] = int(report.planes.light.compressed_payload_bytes) + int(report.planes.heavy.compressed_payload_bytes)
	report["estimated_total_texture_vram_mib"] = report.total_compressed_payload_bytes / 1048576.0
	report["elapsed_ms"] = Time.get_ticks_msec() - started
	report["status"] = "complete_for_review"
	_save_report()
	print("ROAD_SCALAR_COVERAGE_BAKE_DONE bytes=", report.total_compressed_payload_bytes,
		" light_mean=", report.planes.light.exact_full_resolution_mean,
		" heavy_mean=", report.planes.heavy.exact_full_resolution_mean,
		" elapsed_ms=", report.elapsed_ms)
	quit(0)

