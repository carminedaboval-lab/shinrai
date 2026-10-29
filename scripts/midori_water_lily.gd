extends RefCounted
## Staged reference-led water-lily artwork. Origin is lake surface in metres.
## build(0): blush, (1): ivory, (2): green bud, (3): green foliage, (4): mixed-age foliage.
## Mizumoto/GANREF observations supplied by scene owner inform appearance,
## not measured photographic colour or a universal botanical-fidelity claim.
## All variants share the same four materials; no collisions or animations.
## Dimensions retained near baseline: pads nominal .470/.316/.384 m across,
## flower about .180 m across; origin at water, centres .006-.008 m above it,
## 2.8 mm rims and submerged stems retained. Small young-pad sector rises
## up to an additional 12 mm while its centre keeps the same contact height.
## Three pads per build. Foliage uses 48 outer segments, flowering/bud 96;
## all retain the solved six adaptive radial intervals and tangent joins.
## Topology budget: 13,977 flower / 8,985 bud / 3,876 foliage triangles.
## Engine audit and actual park renders belong to the scene owner.
## Candidate V2 colour response revision follows V1's actual day/night QA:
## V1 script SHA256 AE24BB0C2CB31EDB2F68D9E76896DB38A6D0E1CE46E7A9238D037EF2838A3172.
## preserve texture restraint, but linearise the leaf palette, restore green
## dominance, deepen supported rim cups and vary physical roughness. No light,
## emission, unlit or water changes. The leaf centres retain their heights.

static var _materials: Array[Material] = []
static var _meshes: Dictionary = {}

static func build(variant: int = 0) -> Node3D:
	variant = clampi(variant, 0, 4)
	if _materials.is_empty():
		_make_materials()
	if not _meshes.has(variant):
		_meshes[variant] = _make_meshes(variant)
	var plant := Node3D.new()
	plant.name = ["WaterLilyBlush", "WaterLilyIvory", "WaterLilyBud", "WaterLilyGreenFoliage", "WaterLilyMixedAgeFoliage"][variant]
	var meshes: Array = _meshes[variant]
	for i in range(meshes.size()):
		if meshes[i] == null:
			continue
		var part := MeshInstance3D.new()
		part.name = ["WaxyPads", "CurvedPetals", "FineStamens", "SubmergedStems"][i]
		part.mesh = meshes[i]
		# Thin petals transmit light and should not create hard shadow-map wedges
		# across neighbouring petals; foliage and stems still cast shadows.
		if i == 1:
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plant.add_child(part)
	plant.set_meta("water_surface_local_y", 0.0)
	plant.set_meta("botanical_style", "Cultivated water-lily artwork: notched floating pads and layered water-level flowers")
	return plant

static func _make_materials() -> void:
	var leaf := _material("WaterLilyWaxyLeaf", 0.32)
	leaf.albedo_texture = _leaf_texture()
	leaf.roughness = 1.0
	leaf.roughness_texture = _leaf_roughness_texture()
	leaf.metallic_specular = 0.45
	leaf.clearcoat_enabled = true
	leaf.clearcoat = 0.22
	leaf.clearcoat_roughness = 0.30
	var petal := _material("WaterLilyPetal", 0.62)
	petal.albedo_texture = _petal_texture()
	petal.backlight_enabled = true
	petal.backlight = Color(0.18, 0.18, 0.16)
	var pollen := _material("WaterLilyPollen", 0.72)
	var stem := _material("WaterLilyStem", 0.56)
	_materials = [leaf, petal, pollen, stem]

static func _material(label: String, roughness_value: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = label
	material.vertex_color_use_as_albedo = true
	material.roughness = roughness_value
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

static func _leaf_texture() -> ImageTexture:
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 71329
	noise.frequency = 0.046
	for y in range(256):
		for x in range(256):
			var p := Vector2(float(x - 128), float(y - 128)) / 128.0
			var radius := p.length()
			var angle := atan2(p.y, p.x)
			# Neutral multiplicative texture lets per-pad olive/copper colour
			# survive; faint irregular veins replace bright thirteen-ray stripes.
			var warped_angle := angle + 0.07 * sin(radius * 11.0 + angle * 3.0)
			var main_vein := pow(maxf(0.0, cos(warped_angle * 11.0 + radius * 0.25)), 60.0)
			var branch_phase := radius * 91.0 + sin(warped_angle * 11.0) * 8.0
			var branch_vein := pow(maxf(0.0, cos(branch_phase)), 42.0)
			var mottling := noise.get_noise_2d(x, y) * 0.034
			var fine_noise := noise.get_noise_2d(float(x) * 3.7 + 130.0, float(y) * 3.7 - 80.0)
			var speckle := smoothstep(0.22, 0.45, fine_noise) * 0.045
			var shade := 0.012 * main_vein + 0.003 * branch_vein + mottling - speckle
			var edge := smoothstep(0.86, 1.02, radius) * (0.015 + 0.012 * sin(angle * 9.0 + radius))
			image.set_pixel(x, y, Color(0.90 + shade - edge, 0.90 + shade - edge, 0.88 + shade - edge))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func _petal_texture() -> ImageTexture:
	var image := Image.create(128, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(128):
			var t := float(y) / 255.0
			var u := float(x) / 127.0
			var vein := pow(maxf(0.0, cos(u * 67.0 + sin(t * 4.0) * 1.2)), 18.0) * 0.012
			var edge := pow(absf(u * 2.0 - 1.0), 2.0) * 0.014
			image.set_pixel(x, y, Color(1.0 - vein * 0.45 - edge * 0.5, 1.0 - vein - edge, 1.0 - vein * 0.65 - edge * 0.7))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func _leaf_roughness_texture() -> ImageTexture:
	# Linear data map: moderately wet leaf wax with faint uneven veins and
	# speckle response. All channels match, so the selected channel is neutral.
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 71329
	noise.frequency = 0.046
	for y in range(256):
		for x in range(256):
			var p := Vector2(float(x - 128), float(y - 128)) / 128.0
			var radius := p.length()
			var angle := atan2(p.y, p.x)
			var warped := angle + 0.07 * sin(radius * 11.0 + angle * 3.0)
			var vein := pow(maxf(0.0, cos(warped * 11.0 + radius * 0.25)), 60.0)
			var mottling := noise.get_noise_2d(x, y)
			var edge_wear := smoothstep(0.82, 1.0, radius) * (0.025 + 0.012 * sin(angle * 9.0))
			var rough := clampf(0.35 + mottling * 0.075 + vein * 0.045 + edge_wear, 0.27, 0.46)
			image.set_pixel(x, y, Color(rough, rough, rough, 1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func _buffer() -> Dictionary:
	return {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}

static func _vertex(buffer: Dictionary, p: Vector3, n: Vector3, uv: Vector2, color: Color) -> int:
	var index: int = buffer.v.size()
	buffer.v.append(p)
	buffer.n.append(n.normalized())
	buffer.uv.append(uv)
	buffer.c.append(color)
	return index

static func _triangle(buffer: Dictionary, a: int, b: int, c: int) -> void:
	buffer.i.append_array(PackedInt32Array([a, b, c]))

static func _finish(buffer: Dictionary, material_index: int) -> ArrayMesh:
	if buffer.i.is_empty():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = buffer.v
	arrays[Mesh.ARRAY_NORMAL] = buffer.n
	arrays[Mesh.ARRAY_TEX_UV] = buffer.uv
	arrays[Mesh.ARRAY_COLOR] = buffer.c
	arrays[Mesh.ARRAY_INDEX] = buffer.i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _materials[material_index])
	return mesh

static func _make_meshes(variant: int) -> Array:
	var leaves := _buffer()
	var petals := _buffer()
	var stamens := _buffer()
	var stems := _buffer()
	var pads := [
		{"p": Vector3(0, 0.006, 0), "r": 0.235, "a": 0.31, "s": 0.0},
		{"p": Vector3(0.325, 0.008, 0.105), "r": 0.158, "a": 2.52, "s": 1.7},
		{"p": Vector3(-0.278, 0.007, -0.155), "r": 0.192, "a": -1.83, "s": 3.2}
	]
	var ages := [[0.12, 0.42, 0.20], [0.30, 0.12, 0.55], [0.18, 0.35, 0.38], [0.08, 0.48, 0.26], [0.76, 1.28, 0.58]]
	var pad_segments := 48 if variant >= 3 else 96
	for index in range(pads.size()):
		var pad: Dictionary = pads[index]
		var phase := float(variant) * 1.91 + float(index) * 2.14
		pad.p += Vector3(sin(phase) * 0.023, 0, cos(phase) * 0.021)
		pad.r *= 1.0 + 0.045 * sin(phase + 0.4)
		pad.a += float(variant) * 0.43 + sin(phase) * 0.14
		pad.s += float(variant) * 1.37
		var age: float = ages[variant][index]
		var curl := 0.0
		if age > 1.0:
			pad.r *= 0.89
			curl = 0.012
		_add_pad(leaves, pad.p, pad.r, pad.a, pad.s, _leaf_color(age, phase), curl, pad_segments)
		_add_tube(stems, pad.p + Vector3(0, -0.008, 0), pad.p + Vector3(-0.025, -0.19, 0.015), 0.0035, 0.0025, Color(0.20, 0.28, 0.11), 6)
	var flower_base := Vector3(0.072, 0.02, -0.045)
	if variant <= 2:
		_add_tube(stems, flower_base, flower_base + Vector3(0.01, -0.21, 0.015), 0.0042, 0.0035, Color(0.28, 0.34, 0.13), 7)
	if variant < 2:
		var counts := [13, 11, 9, 7]
		var lengths := [0.073, 0.062, 0.044, 0.026]
		var widths := [0.0140, 0.0125, 0.0095, 0.0070]
		var rises := [0.016, 0.040, 0.060, 0.078]
		for layer in range(4):
			for petal in range(counts[layer]):
				var angle := TAU * float(petal) / float(counts[layer]) + float(layer) * 0.38
				var length_jitter := 1.0 + 0.045 * sin(float(petal) * 3.7 + float(layer))
				_add_petal(petals, flower_base, angle, lengths[layer] * length_jitter, widths[layer], rises[layer], layer, variant)
		for i in range(64):
			var angle := float(i) * 2.399963
			var fraction := sqrt((float(i) + 0.5) / 64.0)
			var radius := 0.003 + 0.018 * fraction
			var base := flower_base + Vector3(cos(angle) * radius, 0.010, sin(angle) * radius)
			var tip := base + Vector3(cos(angle) * 0.0015, 0.022 + (1.0 - fraction) * 0.007, sin(angle) * 0.0015)
			_add_tube(stamens, base, tip, 0.00072, 0.00080, Color(0.96, 0.48, 0.025), 4)
			_add_tube(stamens, tip - Vector3(0, 0.0035, 0), tip + Vector3(0, 0.0018, 0), 0.0016, 0.00085, Color(1.0, 0.72, 0.075), 4)
	elif variant == 2:
		_add_closed_bud(petals, flower_base)
	return [_finish(leaves, 0), _finish(petals, 1), _finish(stamens, 2), _finish(stems, 3)]

static func _leaf_color(age: float, phase: float) -> Color:
	# Shared neutral texture, different leaf-age albedos: olive/yellow-green,
	# deeper waxy foliage and occasional smaller copper unfolding pads.
	# Palette values are display-space RGB; array vertex colours are linear.
	# V1 omitted this conversion, creating much brighter mustard leaf albedos.
	var color := Color(0.145, 0.315, 0.105).lerp(Color(0.245, 0.375, 0.145), clampf(age, 0.0, 0.65) / 0.65)
	if age > 0.65 and age <= 1.0:
		color = color.lerp(Color(0.115, 0.255, 0.095), (age - 0.65) / 0.35)
	elif age > 1.0:
		color = Color(0.315, 0.195, 0.115).lerp(Color(0.245, 0.260, 0.11), (age - 1.0) * 0.6)
	return (color * (0.96 + 0.035 * sin(phase * 2.3))).srgb_to_linear()

static func _pad_point(t: float, angle: float, radius: float, seed_value: float, curl: float) -> Vector3:
	var edge_variation := 1.0 + 0.025 * sin(angle * 3.0 + seed_value) + 0.008 * sin(angle * 7.0 + seed_value * 2.0)
	var r := t * radius * edge_variation
	var cupping := (0.0055 + 0.0010 * sin(seed_value * 1.7)) * pow(t, 3.0) + 0.0020 * sin(angle * 3.0 + seed_value) * t * t
	var vein_ridge := 0.00024 * pow(maxf(0.0, cos(angle * 11.0 + t * 0.25)), 30.0) * sin(t * PI)
	# Curl raises only one young-leaf sector; the centre remains at its
	# original supported water-contact height instead of lifting the pad.
	cupping += curl * pow(t, 3.0) * pow(maxf(0.0, cos(angle - seed_value * 0.4)), 2.0)
	var aspect := 0.91 + 0.035 * sin(seed_value * 1.3)
	return Vector3(cos(angle) * r, cupping + vein_ridge, sin(angle) * r * aspect)

static func _pad_coordinates(t: float, arc: float, seed_value: float) -> Vector2:
	# A cubic sinus boundary turns into the outer circumference tangentially.
	# The narrow center broadens into rounded shoulders instead of a V cut.
	var alpha := 0.195 + 0.022 * sin(seed_value + 1.4)
	var p0 := Vector2(0.0005, 0.00004)
	var p1 := Vector2(0.48, 0.025 + 0.008 * sin(seed_value * 2.1))
	var p3 := Vector2(cos(alpha), sin(alpha))
	var outer_tangent := Vector2(-sin(alpha), cos(alpha))
	var p2 := p3 - outer_tangent * 0.155
	var s := 1.0 - t
	var boundary := p0 * s * s * s + p1 * 3.0 * s * s * t + p2 * 3.0 * s * t * t + p3 * t * t * t
	var radius_fraction := boundary.length()
	var shoulder := atan2(boundary.y, boundary.x)
	var asymmetry := 0.012 * sin(seed_value * 2.7) * sin(PI * t)
	return Vector2(radius_fraction, lerpf(shoulder + asymmetry, TAU - shoulder + asymmetry, arc))

static func _pad_surface(t: float, arc: float, radius: float, seed_value: float, curl: float) -> Vector3:
	var coordinate := _pad_coordinates(t, arc, seed_value)
	return _pad_point(coordinate.x, coordinate.y, radius, seed_value, curl)

static func _pad_normal(t: float, arc: float, radius: float, seed_value: float, curl: float) -> Vector3:
	# Compute the height-field normal in polar coordinates, independent of the
	# boundary grid's vanishing radial derivative at its tangent shoulder.
	var coordinate := _pad_coordinates(t, arc, seed_value)
	var dr := _pad_point(coordinate.x + 0.0001, coordinate.y, radius, seed_value, curl) - _pad_point(maxf(0.00001, coordinate.x - 0.0001), coordinate.y, radius, seed_value, curl)
	var da := _pad_point(coordinate.x, coordinate.y + 0.0001, radius, seed_value, curl) - _pad_point(coordinate.x, coordinate.y - 0.0001, radius, seed_value, curl)
	return da.cross(dr).normalized()

static func _add_pad(buffer: Dictionary, center: Vector3, radius: float, rotation: float, seed_value: float, tint: Color, curl: float, segments: int) -> void:
	var SEGMENTS := segments
	const RINGS := 6
	var radial_samples := [0.001, 0.22, 0.44, 0.64, 0.80, 0.92, 1.0]
	var basis := Basis(Vector3.UP, rotation)
	var start_index: int = buffer.v.size()
	for side in range(2):
		for ring in range(RINGS + 1):
			var t: float = radial_samples[ring]
			for segment in range(SEGMENTS + 1):
				var arc := float(segment) / float(SEGMENTS)
				var p := _pad_surface(t, arc, radius, seed_value, curl)
				var normal := _pad_normal(t, arc, radius, seed_value, curl)
				var coordinate := _pad_coordinates(t, arc, seed_value)
				var rim_warmth := smoothstep(0.82, 1.0, coordinate.x) * 0.05 * (0.5 + 0.5 * sin(coordinate.y * 5.0 + seed_value))
				var color := tint.lerp(Color(0.30, 0.225, 0.115).srgb_to_linear(), rim_warmth)
				if side == 1:
					color *= Color(0.68, 0.72, 0.68)
				if side == 1:
					p.y -= 0.0028
					normal = -normal
				_vertex(buffer, center + basis * p, basis * normal, Vector2(p.x / radius * 0.5 + 0.5, p.z / (radius * 0.92) * 0.5 + 0.5), color)
		var side_start := start_index + side * (RINGS + 1) * (SEGMENTS + 1)
		for ring in range(RINGS):
			for segment in range(SEGMENTS):
				var a := side_start + ring * (SEGMENTS + 1) + segment
				var b := a + SEGMENTS + 1
				if side == 0:
					_triangle(buffer, a, b, a + 1)
					_triangle(buffer, a + 1, b, b + 1)
				else:
					_triangle(buffer, a, a + 1, b)
					_triangle(buffer, a + 1, b + 1, b)
	# Dedicated rounded rim with side normals, including both sides of the notch.
	var rim_points: Array[Vector3] = []
	for segment in range(SEGMENTS + 1):
		rim_points.append(_pad_surface(1.0, float(segment) / float(SEGMENTS), radius, seed_value, curl))
	for ring in range(RINGS - 1, -1, -1):
		rim_points.append(_pad_surface(radial_samples[ring], 1.0, radius, seed_value, curl))
	for ring in range(RINGS):
		rim_points.append(_pad_surface(radial_samples[ring], 0.0, radius, seed_value, curl))
	for edge in range(rim_points.size()):
		var a := rim_points[edge]
		var b := rim_points[(edge + 1) % rim_points.size()]
		var n := Vector3(b.z - a.z, 0, a.x - b.x).normalized()
		var start: int = buffer.v.size()
		for p in [a, b, a - Vector3(0, 0.0028, 0), b - Vector3(0, 0.0028, 0)]:
			_vertex(buffer, center + basis * p, basis * n, Vector2(0.9, 0.5), tint * Color(0.80, 0.85, 0.74))
		_triangle(buffer, start, start + 1, start + 2)
		_triangle(buffer, start + 1, start + 3, start + 2)

static func _petal_point(t: float, u: float, length_value: float, width: float, rise: float, layer: int) -> Vector3:
	# Rounded lamina: broad shoulders, smooth rising centerline and a slight
	# recurved tip. Small continuous edge cupping avoids a folded-paper ridge.
	var breadth := width * pow(maxf(0.0, sin(PI * t)), 0.70) * (1.0 - t * 0.18)
	var rise_curve := t * t * (3.0 - 2.0 * t)
	var y := rise * rise_curve + 0.0035 * sin(PI * t) - 0.003 * pow(t, 5.0) * (1.0 - float(layer) / 4.0)
	y += 0.0011 * u * u * sin(PI * t) + 0.000025 * cos(u * 17.0) * sin(PI * t)
	return Vector3(0.017 + length_value * t, y, u * breadth)

static func _add_petal(buffer: Dictionary, center: Vector3, angle: float, length_value: float, width: float, rise: float, layer: int, variant: int) -> void:
	const LONG := 10
	const WIDE := 6
	var basis := Basis(Vector3.UP, angle)
	var start: int = buffer.v.size()
	for row in range(LONG + 1):
		var t := clampf(float(row) / float(LONG), 0.001, 0.999)
		for column in range(WIDE + 1):
			var u := float(column) / float(WIDE) * 2.0 - 1.0
			var p := _petal_point(t, u, length_value, width, rise, layer)
			var dt := _petal_point(minf(0.99999, t + 0.0001), u, length_value, width, rise, layer) - _petal_point(maxf(0.00001, t - 0.0001), u, length_value, width, rise, layer)
			var du := _petal_point(t, u + 0.0001, length_value, width, rise, layer) - _petal_point(t, u - 0.0001, length_value, width, rise, layer)
			var normal := du.cross(dt).normalized()
			var blush := smoothstep(0.20, 0.94, t) * (0.65 + 0.35 * absf(u))
			var color := Color(0.97, 0.85, 0.56).lerp(Color(0.98, 0.95, 0.94), smoothstep(0.03, 0.35, t))
			color = color.lerp(Color(0.95, 0.78, 0.82), blush * 0.25)
			if variant == 1:
				color = Color(0.96, 0.91, 0.72).lerp(Color(0.97, 0.98, 0.975), smoothstep(0.025, 0.38, t))
			_vertex(buffer, center + basis * p, basis * normal, Vector2(float(column) / WIDE, t), color)
	for row in range(LONG):
		for column in range(WIDE):
			var a := start + row * (WIDE + 1) + column
			var b := a + WIDE + 1
			_triangle(buffer, a, b, a + 1)
			_triangle(buffer, a + 1, b, b + 1)

static func _bud_point(t: float, angle: float) -> Vector3:
	var radius := 0.017 * pow(maxf(0.0, sin(PI * t)), 0.72) * (1.10 - t * 0.25)
	radius *= 1.0 + 0.02 * cos(angle * 8.0)
	return Vector3(cos(angle) * radius, t * 0.064, sin(angle) * radius)

static func _add_closed_bud(buffer: Dictionary, center: Vector3) -> void:
	const ROWS := 14
	const SEGMENTS := 48
	var start: int = buffer.v.size()
	for row in range(ROWS + 1):
		var t := clampf(float(row) / ROWS, 0.001, 0.999)
		for segment in range(SEGMENTS + 1):
			var angle := TAU * float(segment) / SEGMENTS
			var p := _bud_point(t, angle)
			var da := _bud_point(t, angle + 0.0001) - _bud_point(t, angle - 0.0001)
			var dt := _bud_point(t + 0.0001, angle) - _bud_point(t - 0.0001, angle)
			var n := dt.cross(da).normalized()
			var stripe := pow(maxf(0.0, cos(angle * 5.0 + t * 0.3)), 20.0) * 0.045
			var color := Color(0.24, 0.34, 0.13).lerp(Color(0.39, 0.46, 0.20), smoothstep(0.14, 0.82, t))
			color += Color(stripe * 0.65, stripe, stripe * 0.35, 0.0)
			_vertex(buffer, center + p, n, Vector2(float(segment) / SEGMENTS, t), color)
	for row in range(ROWS):
		for segment in range(SEGMENTS):
			var a := start + row * (SEGMENTS + 1) + segment
			var b := a + SEGMENTS + 1
			_triangle(buffer, a, a + 1, b)
			_triangle(buffer, a + 1, b + 1, b)

static func _add_tube(buffer: Dictionary, base: Vector3, tip: Vector3, radius_base: float, radius_tip: float, color: Color, sides: int) -> void:
	var axis := (tip - base).normalized()
	var tangent := axis.cross(Vector3.RIGHT).normalized()
	var bitangent := axis.cross(tangent).normalized()
	var start: int = buffer.v.size()
	for ring in range(2):
		for i in range(sides):
			var n := tangent * cos(TAU * float(i) / sides) + bitangent * sin(TAU * float(i) / sides)
			var p := base + n * radius_base if ring == 0 else tip + n * radius_tip
			_vertex(buffer, p, n, Vector2(float(i) / sides, ring), color)
	for i in range(sides):
		var following := (i + 1) % sides
		_triangle(buffer, start + i, start + following, start + sides + i)
		_triangle(buffer, start + following, start + sides + following, start + sides + i)
	var cap := _vertex(buffer, tip, axis, Vector2(0.5, 0.5), color)
	for i in range(sides):
		_triangle(buffer, cap, start + sides + i, start + sides + (i + 1) % sides)
