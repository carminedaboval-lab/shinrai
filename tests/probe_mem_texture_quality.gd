extends SceneTree
## How far each VRAM-compressed texture is from its source picture. No park:
## loads every listed texture, decompresses the imported copy and compares it
## with the source file on a sample grid (about 65,000 pixels per texture).
##   godot --path . --script res://tests/probe_mem_texture_quality.gd -- --list=<csv with a "rel" column> --out=<csv>
## Columns: mean and worst colour error (0-255, over pixels the source does not
## make fully transparent), PSNR, mean alpha error, and the share of sampled
## pixels whose alpha lands on the other side of the 0.5 cut-out threshold.

const SAMPLES_PER_SIDE := 256

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var list := ""
	var out := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--list="): list = arg.get_slice("=", 1)
		if arg.begins_with("--out="): out = arg.get_slice("=", 1)
	var file := FileAccess.open(list, FileAccess.READ)
	if file == null or out.is_empty():
		printerr("TEXQ_FAILED missing --list or --out")
		quit(1)
		return
	var header := file.get_csv_line()
	var column := header.find("rel")
	var rows: PackedStringArray = ["rel,width,height,format,has_alpha,mean_rgb,max_rgb,psnr_db,mean_alpha,alpha_flip_pct,note"]
	var done := 0
	while not file.eof_reached():
		var line := file.get_csv_line()
		if column < 0 or line.size() <= column or line[column].is_empty(): continue
		rows.append(_compare(line[column]))
		done += 1
		if done % 40 == 0:
			print("TEXQ progress ", done)
			await process_frame
	var result := FileAccess.open(out, FileAccess.WRITE)
	result.store_string("\n".join(rows) + "\n")
	result.close()
	print("TEXQ_DONE ", done)
	quit()

func _compare(rel: String) -> String:
	var path := "res://" + rel
	var texture := load(path) as Texture2D
	if texture == null: return "%s,0,0,,,,,,,,load failed" % rel
	var imported := texture.get_image()
	if imported == null: return "%s,0,0,,,,,,,,no image" % rel
	var format := imported.get_format()
	if imported.is_compressed() and imported.decompress() != OK:
		return "%s,0,0,%d,,,,,,,decompress failed" % [rel, format]
	var source := Image.load_from_file(ProjectSettings.globalize_path(path))
	if source == null: return "%s,0,0,%d,,,,,,,source unreadable" % [rel, format]
	var note := ""
	if source.get_size() != imported.get_size():
		note = "source %dx%d resized" % [source.get_width(), source.get_height()]
		source.resize(imported.get_width(), imported.get_height(), Image.INTERPOLATE_LANCZOS)
	var has_alpha := source.detect_alpha() != Image.ALPHA_NONE
	imported.clear_mipmaps()
	source.clear_mipmaps()
	imported.convert(Image.FORMAT_RGBA8)
	source.convert(Image.FORMAT_RGBA8)
	var a := source.get_data()
	var b := imported.get_data()
	var w := source.get_width()
	var h := source.get_height()
	var step_x := maxi(1, w / SAMPLES_PER_SIDE)
	var step_y := maxi(1, h / SAMPLES_PER_SIDE)
	var colour_sum := 0
	var colour_sq := 0
	var colour_max := 0
	var colour_n := 0
	var alpha_sum := 0
	var flips := 0
	var n := 0
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var i := (y * w + x) * 4
			var sa := a[i + 3]
			var da := b[i + 3]
			alpha_sum += absi(sa - da)
			if (sa >= 128) != (da >= 128): flips += 1
			n += 1
			if sa > 0:
				for c: int in range(3):
					var d := absi(a[i + c] - b[i + c])
					colour_sum += d
					colour_sq += d * d
					if d > colour_max: colour_max = d
				colour_n += 3
			x += step_x
		y += step_y
	var mean := float(colour_sum) / maxf(1.0, colour_n)
	var mse := float(colour_sq) / maxf(1.0, colour_n)
	var psnr := 99.0 if mse <= 0.0 else 10.0 * log(65025.0 / mse) / log(10.0)
	return "%s,%d,%d,%d,%s,%.3f,%d,%.2f,%.3f,%.4f,%s" % [rel, w, h, format, str(has_alpha), mean, colour_max, psnr, float(alpha_sum) / maxf(1.0, n), 100.0 * flips / maxf(1.0, n), note]
