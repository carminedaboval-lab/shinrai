extends RefCounted
## Momiji-dani 紅葉谷, the green-maple glen south of the spawn street
## (docs/biome_concepts/after_maple_glen.png). Clumps of green Japanese maples,
## about one in six turning rust, ferns at their feet, and a floor of fallen
## leaves: drifts everywhere in the glen, heaped under the crowns. The upright
## lawn blades give way to the leaf floor. A weathered timber azumaya stands at
## the relief yard's lake-facing side, seen across the pond from the shore.
const Biomes := preload("res://scripts/midori_biomes.gd")
const Kit := preload("res://scripts/biomes/biome_kit.gd")
const MAPLE_DIR := "res://assets/shinrai/parks/midori_park/models/vegetation/vendor/free3d_japanese_maple_n030123/"
const BARK_TILE := preload(MAPLE_DIR + "BarkDecd.jpg")
const LEAF_VEIN := preload(MAPLE_DIR + "leaf_01d.JPG")
const SPRAY_ATLAS := "res://assets/shinrai/parks/midori_park/materials/maple_glen/maple_sprays.png"
const PAVILION := "res://assets/shinrai/parks/midori_park/models/pavilion/azumaya.glb"
const ID := "momiji"
# The trampled relief yard round the pavilion keeps its open ground.
const YARD_C := Vector2(152, -146)
const YARD_R := Vector2(23, 16)
const CLUMPS := 8
const MAX_MAPLES := 23
## Back-projected from the concept through the pond-shore camera (eye
## (118,-126) looking at (140,-158), 70 deg): right of centre, about 25 m out,
## just behind the lantern walk, at the yard's lake-facing side.
const PAVILION_AIM := Vector2(140, -141.3)
const PAVILION_SIZE := 4.5 # plinth footprint, metres
const PAVILION_TALL := 4.3 # plinth foot to ridge, metres
const PAVILION_POST := 0.22 # post section, metres
## Maples keep their crowns off the pavilion roof.
const PAVILION_TREE_GAP := 9.5
## Full tree within MAPLE_NEAR m, thinned crown beyond (both drawn over the
## MAPLE_FADE m either side while they cross-fade); every tree casts its
## shadow from the thinned crown.
const MAPLE_NEAR := 40.0
const MAPLE_FADE := 5.0
const MAPLE_FAR_END := 260.0
const MAPLE_SHADOW_END := 160.0

## Thin leaf tissue catches indirect daylight even when another part of the
## crown shades it. Keep this tied to the directional light's actual energy.
const MAPLE_LIGHT := """
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrapped = max(0.0, (ndl + 0.53) / 1.53);
	float through = max(0.0, -ndl) * 0.37;
	float bounce = LIGHT_IS_DIRECTIONAL ? 0.16 : 0.0;
	DIFFUSE_LIGHT += LIGHT_COLOR * (ATTENUATION * (wrapped + through) + bounce) / PI;
}
"""

## Leaves are palmate geometry. The texture supplies a vein pattern, while
## the colour and transmission vary across each spray and between trees.
const MAPLE_LEAF_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D leaf_vein : source_color, filter_linear_mipmap, repeat_disable;
instance uniform vec4 tint : instance_index(0) = vec4(0.23, 0.31, 0.10, 1.0);
void fragment() {
	vec3 up = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	if (dot(NORMAL, up) < 0.0) NORMAL = -NORMAL;
	NORMAL = normalize(mix(NORMAL, up, 0.52));
	float pattern = dot(texture(leaf_vein, UV).rgb, vec3(0.50, 0.40, 0.10));
	float sunward = mix(0.76, 1.16, COLOR.r);
	float edge = mix(0.90, 1.05, COLOR.g);
	ALBEDO = tint.rgb * sunward * edge * (0.90 + 0.42 * pattern);
	ROUGHNESS = 0.92;
}
""" + MAPLE_LIGHT

const MAPLE_SPRAY_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D sprays : source_color, filter_linear_mipmap, repeat_disable;
instance uniform vec4 tint : instance_index(0) = vec4(0.23, 0.31, 0.10, 1.0);
void fragment() {
	vec4 leaf = texture(sprays, UV);
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.30;
	vec3 up = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	if (dot(NORMAL, up) < 0.0) NORMAL = -NORMAL;
	NORMAL = normalize(mix(NORMAL, up, 0.58));
	float grain = dot(leaf.rgb, vec3(0.36, 0.54, 0.10));
	ALBEDO = tint.rgb * mix(0.78, 1.16, COLOR.r) * (0.56 + 3.45 * grain);
	ROUGHNESS = 0.98;
}
""" + MAPLE_LIGHT

const MAPLE_BARK_SHADER := """
shader_type spatial;
render_mode specular_disabled;
uniform sampler2D bark_scan : source_color, filter_linear_mipmap, repeat_enable;
void fragment() {
	float grain = dot(texture(bark_scan, UV).rgb, vec3(0.32, 0.53, 0.15));
	ALBEDO = mix(vec3(0.025,0.028,0.026), vec3(0.125,0.123,0.110), smoothstep(0.018,0.35,grain));
	ROUGHNESS = 0.98;
}
"""

static func build(park: Node3D, terrain: Node) -> Dictionary:
	var root := Node3D.new()
	root.name = "BiomeMapleGlen"
	park.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20501101
	# The pavilion goes first so trees, ferns and leaves keep off its footprint.
	var pavilion: Dictionary = await _pavilion(park, terrain, root)
	# The park can be freed (scene change) while the build waits on frames.
	if not is_instance_valid(park): return {}
	var maples := await _plant_maples(park, terrain, root, rng, pavilion)
	if not is_instance_valid(park): return {}
	var ferns := _ferns(park, terrain, root, rng, maples, pavilion)
	var leaves := await _leaf_floor(park, terrain, root, rng, maples, pavilion)
	if not is_instance_valid(park): return {}
	var thinned := _thin_lawn(park, terrain)
	# The pavilion blockout plane (a flat tan box) gives way to the yard floor.
	var zone := park.find_child("PavilionZone", true, false) as Node3D
	if zone != null: zone.hide()
	var label := park.find_child("PavilionZone*Label*", true, false) as Node3D
	if label != null: label.hide()
	var supplies := _yard_supplies(park, pavilion)
	var pavilion_at: Variant = false
	if not pavilion.is_empty():
		var at: Vector2 = pavilion.p
		pavilion_at = [snappedf(at.x, 0.1), snappedf(at.y, 0.1), snappedf(rad_to_deg(float(pavilion.yaw)), 1.0)]
	return {"supplies": supplies, "maples": maples.size(), "rust": maples.filter(func(m): return m.rust).size(), "ferns": ferns, "leaves": leaves, "thinned": thinned, "pavilion": pavilion_at}

static func _in_yard(p: Vector2) -> bool:
	return ((p - YARD_C) / YARD_R).length() < 1.0

static func _weight(p: Vector2, terrain: Node) -> float:
	return Biomes.weight(p, ID, terrain)

## True when nothing but the ground is under the point (no prop, deck or roof).
static func _bare(park: Node3D, terrain: Node, p: Vector2) -> bool:
	var space := park.get_world_3d().direct_space_state
	var ground: float = terrain.height_at(p)
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, ground + 30.0, p.y), Vector3(p.x, ground - 2.0, p.y))
	var hit := space.intersect_ray(query)
	return hit.is_empty() or hit.position.y < ground + 0.35

# ------------------------------------------------------------------ pavilion

## A pavilion-local offset (x across, y along its depth) in world xz.
static func _pav_world(p: Vector2, yaw: float, local: Vector2) -> Vector2:
	return p + local.rotated(-yaw)

## True when p lies on the pavilion's plinth, grown by pad metres.
static func _on_pavilion(pav: Dictionary, p: Vector2, pad: float) -> bool:
	if pav.is_empty(): return false
	var at: Vector2 = pav.p
	var local := (p - at).rotated(float(pav.yaw))
	var half: Vector2 = pav.half
	return absf(local.x) < half.x + pad and absf(local.y) < half.y + pad

## The model's real proportions, measured from its vertices (model metres):
## plinth box, plinth top, post rectangle, lowest eave, roof spread, ridge.
static func _measure(proto: Dictionary) -> Dictionary:
	var box: AABB = proto.box
	var y0 := box.position.y
	var h := maxf(box.size.y, 0.001)
	var all := PackedVector3Array()
	for part: Dictionary in proto.parts:
		var xf: Transform3D = part.relative
		var mesh: Mesh = part.mesh
		for s: int in range(mesh.get_surface_count()):
			var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts: all.append(xf * v)
	var plinth := AABB()
	var posts := AABB()
	var roof := AABB()
	var got := [false, false, false]
	for v: Vector3 in all:
		var f := (v.y - y0) / h
		if f < 0.06:
			plinth = plinth.expand(v) if got[0] else AABB(v, Vector3.ZERO)
			got[0] = true
		elif f > 0.25 and f < 0.4:
			posts = posts.expand(v) if got[1] else AABB(v, Vector3.ZERO)
			got[1] = true
		if f > 0.45:
			roof = roof.expand(v) if got[2] else AABB(v, Vector3.ZERO)
			got[2] = true
	if not got[0]: plinth = AABB(box.position, Vector3(box.size.x, 0.0, box.size.z))
	if not got[1]: posts = AABB(box.position + box.size * Vector3(0.15, 0.0, 0.15), box.size * Vector3(0.7, 1.0, 0.7))
	if not got[2]: roof = box
	var centre := plinth.get_center()
	var hx := plinth.size.x * 0.5
	var top := y0 + h * 0.08
	var eave := box.end.y
	for v: Vector3 in all:
		var f := (v.y - y0) / h
		# Plinth top: highest point of its outer walls.
		if f < 0.3 and absf(v.x - centre.x) > hx * 0.96: top = maxf(top, v.y)
		# Lowest eave: roof underside beyond the posts.
		if f > 0.3 and (absf(v.x - posts.get_center().x) > posts.size.x * 0.5 + 0.35 or absf(v.z - posts.get_center().z) > posts.size.z * 0.5 + 0.35):
			eave = minf(eave, v.y)
	return {"plinth": plinth, "top": top, "posts": posts, "eave": eave, "roof": roof, "ridge": box.end.y, "height": h}

## Ground height to seat the plinth at p (its lowest corner), or NAN when the
## spot is on a path, water, a prop or a slope.
static func _pavilion_seat(park: Node3D, terrain: Node, p: Vector2, yaw: float, half: Vector2) -> float:
	var radius := half.length()
	if not Kit.open_ground(park, terrain, p, radius + 0.4, radius + 2.5): return NAN
	var low := INF
	var high := -INF
	for c: Vector2 in [Vector2.ZERO, half, Vector2(-half.x, half.y), Vector2(half.x, -half.y), -half, Vector2(half.x, 0), Vector2(-half.x, 0), Vector2(0, half.y), Vector2(0, -half.y)]:
		var q := _pav_world(p, yaw, c)
		if terrain.water_at(q): return NAN
		var g: float = terrain.height_at(q)
		low = minf(low, g)
		high = maxf(high, g)
	if high - low > 0.35: return NAN
	# Five rays miss a crate stack or barrier standing between them: test the
	# whole plinth (and a little round it) up to the roof for anything solid.
	var box := BoxShape3D.new()
	box.size = Vector3(half.x * 2.0 + 0.6, 3.4, half.y * 2.0 + 0.6)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, high + 0.3 + box.size.y * 0.5, p.y))
	var player: Node = park.get_node_or_null("ParkScaleReviewPlayer")
	if player is CollisionObject3D: query.exclude = [(player as CollisionObject3D).get_rid()]
	if not park.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return NAN
	return low

static func _pavilion(park: Node3D, terrain: Node, root: Node3D) -> Dictionary:
	if not ResourceLoader.exists(PAVILION): return {}
	var proto: Dictionary = Kit.file_parts(PAVILION)
	if proto.parts.is_empty(): return {}
	var m := _measure(proto)
	var plinth: AABB = m.plinth
	var sxz := PAVILION_SIZE / maxf(plinth.size.x, 0.01)
	# Height to about PAVILION_TALL; never taller than the footprint scale.
	var sy := minf(sxz, PAVILION_TALL / maxf(float(m.height), 0.01))
	var half := Vector2(plinth.size.x, plinth.size.z) * 0.5 * sxz
	# Nearest open spot to the framed one, entrance turned to the yard.
	var spot := Vector2.INF
	var yaw := 0.0
	var base := 0.0
	for ring: int in range(7):
		var count := 1 if ring == 0 else 10
		for k: int in range(count):
			var a := TAU * (float(k) + 0.5 * float(ring % 2)) / float(count)
			var p := PAVILION_AIM + Vector2.RIGHT.rotated(a) * float(ring) * 1.5
			var face := YARD_C - p
			var y := atan2(face.x, face.y)
			var b := _pavilion_seat(park, terrain, p, y, half)
			if is_nan(b): continue
			spot = p
			yaw = y
			base = b - 0.04
			break
		if spot != Vector2.INF: break
	if spot == Vector2.INF: return {}
	var anchor := Vector3(plinth.get_center().x, plinth.position.y, plinth.get_center().z)
	var turn := Basis(Vector3.UP, yaw)
	var basis := turn * Basis.from_scale(Vector3(sxz, sy, sxz))
	var node := Node3D.new()
	node.name = "Azumaya"
	root.add_child(node)
	node.global_transform = Transform3D(basis, Vector3(spot.x, base, spot.y) - basis * anchor)
	for part: Dictionary in proto.parts:
		var mesh_node := MeshInstance3D.new()
		mesh_node.name = "AzumayaMesh"
		mesh_node.mesh = part.mesh
		mesh_node.transform = part.relative
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_node.visibility_range_end = 250.0
		mesh_node.visibility_range_end_margin = 25.0
		mesh_node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.add_child(mesh_node)
	# Simple collision in metres from the plinth foot: plinth, four posts, a
	# roof slab under the eaves and a smaller cap to the ridge.
	var body := StaticBody3D.new()
	body.name = "AzumayaCollision"
	root.add_child(body)
	body.global_transform = Transform3D(turn, Vector3(spot.x, base, spot.y))
	var local := func(v: Vector3) -> Vector3: return (v - anchor) * Vector3(sxz, sy, sxz)
	var top: float = local.call(Vector3(0, m.top, 0)).y
	var eave: float = local.call(Vector3(0, m.eave, 0)).y
	var ridge: float = local.call(Vector3(0, m.ridge, 0)).y
	_box(body, Vector3(plinth.size.x * sxz, top, plinth.size.z * sxz), Vector3(0, top * 0.5, 0))
	var posts: AABB = m.posts
	var inset := PAVILION_POST * 0.5
	for c: Vector2 in [Vector2(posts.position.x, posts.position.z), Vector2(posts.end.x, posts.position.z), Vector2(posts.position.x, posts.end.z), Vector2(posts.end.x, posts.end.z)]:
		var at: Vector3 = local.call(Vector3(c.x, 0, c.y))
		at.x -= signf(at.x) * inset
		at.z -= signf(at.z) * inset
		_box(body, Vector3(PAVILION_POST, eave - top, PAVILION_POST), Vector3(at.x, (top + eave) * 0.5, at.z))
	var roof: AABB = m.roof
	var roof_mid: Vector3 = local.call(roof.get_center())
	var slab := 0.6
	_box(body, Vector3(roof.size.x * sxz, slab, roof.size.z * sxz), Vector3(roof_mid.x, eave + slab * 0.5, roof_mid.z))
	if ridge - eave - slab > 0.2:
		_box(body, Vector3(roof.size.x * sxz * 0.5, ridge - eave - slab, roof.size.z * sxz * 0.5), Vector3(roof_mid.x, (eave + slab + ridge) * 0.5, roof_mid.z))
	# Let the physics space take the body before trees test the ground.
	var tree := park.get_tree()
	await tree.physics_frame
	await tree.physics_frame
	return {"p": spot, "yaw": yaw, "half": half, "base": base}

static func _box(body: StaticBody3D, size: Vector3, centre: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = centre
	body.add_child(shape)

# -------------------------------------------------------------------- maples

## Sweep a tapered, round branch along its centreline. Middle rings look both
## ways along the branch, so the bend is continuous at each elbow.
static func _branch(st: SurfaceTool, points: Array[Vector3], widths: Array[float], sides: int) -> void:
	var rings: Array = []
	var normals: Array = []
	for j: int in range(points.size()):
		var along := (points[mini(j + 1, points.size() - 1)] - points[maxi(0, j - 1)]).normalized()
		var reference := Vector3.RIGHT if absf(along.dot(Vector3.FORWARD)) > 0.94 else Vector3.FORWARD
		var radial := along.cross(reference).normalized()
		var side := along.cross(radial)
		var verts := PackedVector3Array()
		var ns := PackedVector3Array()
		for k: int in range(sides):
			var angle := TAU * float(k) / float(sides)
			var n := radial * cos(angle) + side * sin(angle)
			verts.append(points[j] + n * widths[j])
			ns.append(n)
		rings.append(verts)
		normals.append(ns)
	var length := 0.0
	for j: int in range(points.size() - 1):
		var next := length + points[j].distance_to(points[j + 1])
		for k: int in range(sides):
			var k1 := (k + 1) % sides
			var ids := [Vector2i(j,k),Vector2i(j+1,k),Vector2i(j+1,k1),Vector2i(j,k1)]
			var us := [float(k) / sides, float(k) / sides, float(k+1) / sides, float(k+1) / sides]
			for s: int in [0, 1, 2, 0, 2, 3]:
				var id: Vector2i = ids[s]
				st.set_normal(normals[id.x][id.y])
				st.set_uv(Vector2(us[s], length if id.x == j else next))
				st.add_vertex(rings[id.x][id.y])
		length = next

## A leaf fans from a single petiole; the seven tapering fingers are separated
## by deep, unequal sinuses. A fold through the palm catches the dappled light.
static func _palm(st: SurfaceTool, foot: Vector3, forward: Vector3, radius: float, shade: float, far: bool) -> void:
	var side := forward.cross(Vector3.UP).normalized()
	var normal := side.cross(forward).normalized()
	var lobes := 5 if far else 7
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	var base_uv := Vector2(0.50, 0.91)
	var heart := foot + forward * radius * 0.23 + normal * radius * 0.038
	for j: int in range(lobes * 2 + 1):
		var fraction := float(j) / float(lobes * 2)
		var angle := lerpf(-1.92, 1.92, fraction)
		var lobe := j % 2 == 1
		var extent := (0.58 + 0.52 * (1.0 - absf(fraction - 0.5) * 2.0)) if lobe else (0.23 + 0.21 * sin(PI * fraction))
		var x := sin(angle) * extent
		var y := cos(angle) * extent
		var p := heart + (side * x + forward * y) * radius
		p += normal * radius * (0.105 * absf(x) - 0.14 * maxf(0.0, y))
		points.append(p)
		uvs.append(Vector2(0.50 + x * 0.49, 0.73 - y * 0.53))
	points.append(foot)
	uvs.append(base_uv)
	for j: int in range(points.size()):
		var k := (j + 1) % points.size()
		for v: int in [-1, j, k]:
			st.set_color(Color(shade, 0.3 if v < 0 else 0.94, 0.0, 1.0))
			st.set_normal((normal + Vector3.UP * 0.65).normalized())
			st.set_uv(Vector2(0.50, 0.73) if v < 0 else uvs[v])
			st.add_vertex(heart if v < 0 else points[v])

## Opposite leaf pairs on a supple twig. Neighbouring twigs form separate
## overlapping shelves, with visible gaps between their outer tips.
static func _spray(wood: SurfaceTool, near: SurfaceTool, far: SurfaceTool, rng: RandomNumberGenerator, start: Vector3, end: Vector3, serial: int) -> void:
	var along := (end - start).normalized()
	var crosswise := Vector3(-along.z, 0, along.x).normalized()
	var mid := start.lerp(end, 0.53) + Vector3.UP * rng.randf_range(0.025, 0.12)
	_branch(wood, [start, mid, end], [0.010, 0.0065, 0.003], 3)
	var pairs := rng.randi_range(6, 8)
	for j: int in range(pairs):
		var t := (float(j) + rng.randf_range(0.24, 0.78)) / float(pairs)
		var stem := start.lerp(mid, t / 0.53) if t < 0.53 else mid.lerp(end, (t - 0.53) / 0.47)
		for hand: float in [-1.0, 1.0]:
			var heading := (crosswise * hand * rng.randf_range(0.65, 0.96) + along * rng.randf_range(0.26, 0.86) + Vector3.UP * rng.randf_range(-0.46, 0.20)).normalized()
			var leaf_root := stem + heading * rng.randf_range(0.008, 0.024)
			var radius := rng.randf_range(0.085, 0.136) * lerpf(1.16, 0.80, t)
			var light := clampf(0.12 + end.y * 0.105 + t * 0.15 + rng.randf_range(-0.22, 0.23), 0.08, 1.0)
			_palm(near, leaf_root, heading, radius, light, false)
			if (j + serial + int(hand > 0.0)) % 3 == 0:
				_palm(far, leaf_root, heading, radius * 1.53, light, true)

## A compound twiglet curves away from its parent, with one side of the leaf
## fan tilted toward the viewer. Its tip passes below the middle of the spray.
static func _spray_card(st: SurfaceTool, root: Vector3, direction: Vector3, length: float, breadth: float, roll: float, tile: int, sun: float) -> void:
	length *= 0.82
	breadth *= 0.73
	var across := direction.cross(Vector3.UP).normalized().rotated(direction, roll)
	var normal := across.cross(direction).normalized()
	var lefts := PackedVector3Array()
	var rights := PackedVector3Array()
	var normals := PackedVector3Array()
	for row: int in range(3):
		var t := float(row) * 0.5
		var mid := root + direction * length * t + Vector3.UP * length * (0.19 * sin(PI * t) - 0.15 * t * t)
		var side := across.rotated(direction, (t - 0.5) * 0.36)
		lefts.append(mid - side * breadth * 0.5)
		rights.append(mid + side * breadth * 0.5)
		normals.append((normal + direction * (t - 0.5) * 0.65).normalized())
	var start_uv := Vector2(float(tile % 2), floorf(float(tile) / 2.0)) * 0.5
	for row: int in range(2):
		for corner: Vector2i in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(1,0)]:
			var k := row + corner.y
			st.set_normal(normals[k])
			st.set_color(Color(sun, 1.0, 1.0))
			st.set_uv(start_uv + Vector2(float(corner.x) * 0.5, (2.0 - float(k)) * 0.25))
			st.add_vertex(lefts[k] if corner.x == 0 else rights[k])

static func _maple_form(seed_value: int, bark: Material, leaves: Material, spray_mat: Material = null) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var fan_rng := RandomNumberGenerator.new()
	fan_rng.seed = seed_value + 813
	var wood := SurfaceTool.new()
	var near := SurfaceTool.new()
	var far := SurfaceTool.new()
	var fans := SurfaceTool.new()
	for tool: SurfaceTool in [wood, near, far, fans]: tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	wood.set_material(bark)
	near.set_material(leaves)
	far.set_material(leaves)
	fans.set_material(spray_mat)
	var slant := Vector3(rng.randf_range(-0.42, 0.48), 0, rng.randf_range(-0.4, 0.45))
	var spine: Array[Vector3] = [Vector3.ZERO, Vector3(-0.055,0.63,0.065), Vector3(0.14,1.38,-0.11), Vector3(0.20,2.32,0.12) + slant * 0.3, Vector3(-0.06,3.18,0.24) + slant * 0.67, Vector3(0.18,3.95,0.19) + slant]
	_branch(wood, spine, [0.145, 0.105, 0.083, 0.057, 0.031, 0.012], 8)
	var azimuth := rng.randf() * TAU
	var serial := 0
	for i: int in range(15):
		var layer := float(i) / 14.0
		var level := lerpf(1.02, 4.84, layer)
		var joint := mini(floori(level), spine.size() - 2)
		var start := spine[joint].lerp(spine[joint + 1], level - float(joint))
		azimuth += rng.randf_range(2.04, 2.71)
		var direction := Vector3(cos(azimuth), 0, sin(azimuth))
		var side := Vector3(-direction.z, 0, direction.x)
		var run := rng.randf_range(1.42, 2.28) * lerpf(1.15, 0.57, layer)
		var climb := rng.randf_range(0.8, 1.56) * lerpf(1.22, 0.78, layer)
		var elbow := start + direction * run * 0.28 + Vector3.UP * climb * 0.75
		var shoulder := start + direction * run * 0.71 + Vector3.UP * climb + side * rng.randf_range(-0.26, 0.26)
		var tip := shoulder + direction * run * 0.29 + Vector3.UP * rng.randf_range(-0.24, 0.18)
		_branch(wood, [start, elbow, shoulder, tip], [lerpf(0.084, 0.033, layer), 0.040, 0.021, 0.009], 6)
		for j: int in range(5):
			var t := (j + rng.randf_range(0.30, 0.80)) / 5.0
			var at := elbow.lerp(shoulder, t / 0.62) if t < 0.62 else shoulder.lerp(tip, (t - 0.62) / 0.38)
			var hand := -1.0 if j % 2 == 0 else 1.0
			var branch := (direction * rng.randf_range(0.28, 0.81) + side * hand * rng.randf_range(0.52, 1.05)).normalized()
			var reach := rng.randf_range(0.47, 0.92)
			var knuckle := at + branch * reach * 0.46 + Vector3.UP * rng.randf_range(0.14, 0.39)
			var end := knuckle + branch * reach * 0.54 + Vector3.UP * rng.randf_range(-0.15, 0.12)
			_branch(wood, [at, knuckle, end], [0.025, 0.013, 0.005], 4)
			var inner_dir := (branch.rotated(Vector3.UP, hand * 0.51) + Vector3.DOWN * fan_rng.randf_range(0.10,0.46)).normalized()
			_spray_card(fans, at, inner_dir, fan_rng.randf_range(0.96,1.42), fan_rng.randf_range(0.88,1.35), hand * fan_rng.randf_range(0.42,0.94), fan_rng.randi_range(0,3), fan_rng.randf_range(0.42,0.78))
			for k: int in range(3):
				var twig := branch.rotated(Vector3.UP, rng.randf_range(-0.21, 0.21) + (float(k) - 1.0) * 0.75)
				var twig_base := knuckle.lerp(end, rng.randf_range(0.02, 0.85))
				var twig_tip := twig_base + twig * rng.randf_range(0.44, 0.78) + Vector3.UP * rng.randf_range(-0.21, 0.19)
				_spray(wood, near, far, rng, twig_base, twig_tip, serial)
				# Alternating drooping, level and upright layers break up horizontal
				# shelves. Two or three of these leafy twiglets overlap at each fork.
				var spread := 1.0 if k == 1 else -1.0
				var lean := fan_rng.randf_range(-0.56, 0.28) + 0.18 * sin(float(serial) * 1.7)
				var fan_dir := (twig.rotated(Vector3.UP, fan_rng.randf_range(-0.35, 0.35)) + Vector3.UP * lean).normalized()
				var size := fan_rng.randf_range(0.93, 1.50)
				_spray_card(fans, twig_base, fan_dir, size, size * fan_rng.randf_range(0.89, 1.23), spread * hand * fan_rng.randf_range(0.38, 1.11), fan_rng.randi_range(0,3), fan_rng.randf_range(0.52,1.00))
				serial += 1
	wood.index()
	var near_mesh := wood.commit()
	var far_mesh := near_mesh.duplicate() as ArrayMesh
	near.index()
	far.index()
	near.commit(near_mesh)
	far.commit(far_mesh)
	fans.index()
	fans.commit(near_mesh)
	fans.commit(far_mesh)
	return {"near": near_mesh, "far": far_mesh, "height": near_mesh.get_aabb().size.y}

static func maple_tint(rng: RandomNumberGenerator, rust: bool) -> Color:
	if rust: return Color(0.37, 0.236, 0.119).lerp(Color(0.47, 0.286, 0.148), rng.randf())
	return Color(0.285, 0.34, 0.152).lerp(Color(0.405, 0.418, 0.196), rng.randf())

static func _maple_clear(park: Node3D, terrain: Node, p: Vector2, placed: Array, edge: float, tree_gap: float, grove_gap: float) -> bool:
	for m: Dictionary in placed:
		if m.p.distance_to(p) < grove_gap: return false
	return Kit.open_ground(park, terrain, p, edge, tree_gap) and _bare(park, terrain, p)

## Preserve a window onto the roof and posts from the shore. A single young
## tree may stand between the shore and pavilion, just off the line of sight.
static func _frame_pavilion(park: Node3D, terrain: Node, placed: Array, pavilion: Dictionary) -> void:
	if pavilion.is_empty(): return
	var shore := Vector2(118, -126)
	var pav: Vector2 = pavilion.p
	var axis := shore.direction_to(pav)
	var across := Vector2(-axis.y, axis.x)
	var nearest := -1
	var best_overlap := 0.0
	for i: int in range(placed.size()):
		var m: Dictionary = placed[i]
		var offset: Vector2 = m.p - shore
		var depth := offset.dot(axis)
		if depth < 3.5 or depth >= shore.distance_to(pav) - 1.0: continue
		var half_view := 2.6 * depth / shore.distance_to(pav)
		var overlap := (half_view + 0.66 * float(m.h) - absf(offset.dot(across))) / depth
		if overlap > best_overlap:
			best_overlap = overlap
			nearest = i
	if nearest < 0: return
	var front: Dictionary = placed[nearest]
	var side := signf((front.p - shore).dot(across))
	var others := placed.duplicate()
	others.remove_at(nearest)
	for step: float in [4.8, 3.7, 2.8, 2.0]:
		var site: Vector2 = front.p + across * (side if side != 0.0 else -1.0) * step
		if ((site - YARD_C) / YARD_R).length() < 0.82 or site.distance_to(pav) < 7.2: continue
		if not _maple_clear(park, terrain, site, others, 1.6, 2.9, 3.9): continue
		front.p = site
		front.h = float(front.h) * 0.78
		return
	# A tree squeezed between an occupied path and root system stays a young,
	# low plant. Its upper branches sit below the pavilion eave from the shore.
	front.h = minf(float(front.h) * 0.51, 2.55)

static func _plant_maples(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, pavilion: Dictionary) -> Array:
	var placed: Array = []
	# Draw the pond-side trees from the same total allocation as the rear
	# clumps. Their roots keep off the promenade, water, pavilion and relief yard.
	var banks := [Vector2(119, -143), Vector2(127, -147), Vector2(130, -154), Vector2(137, -158), Vector2(145, -162), Vector2(153, -162), Vector2(158, -137), Vector2(159, -130)]
	var pav_at: Vector2 = pavilion.get("p", Vector2.INF)
	for i: int in range(banks.size()):
		var aim: Vector2 = banks[i]
		for attempt: int in range(75):
			var p := aim + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.1, 4.4)
			var yard_radius := ((p - YARD_C) / YARD_R).length()
			if yard_radius < 0.82 or p.distance_to(pav_at) < 7.2: continue
			if not _maple_clear(park, terrain, p, placed, 1.6, 2.9, 3.9): continue
			var h := rng.randf_range(4.1, 5.6) if i < 2 or i >= 6 else rng.randf_range(5.3, 7.0)
			placed.append({"p": p, "h": h, "yaw": rng.randf() * TAU, "rust": i == 3 or i == 6})
			break
	# Clump centres spread through the glen, away from the yard.
	var centres: Array[Vector2] = [Vector2(66, -171), Vector2(98, -169), Vector2(128, -172), Vector2(170, -168), Vector2(112, -150), Vector2(124, -140), Vector2(181, -148), Vector2(88, -152)]
	for attempt: int in range(400):
		if centres.size() >= CLUMPS + 4: break
		var p := Vector2(rng.randf_range(45, 178), rng.randf_range(-176, -120))
		if _weight(p, terrain) < 0.7 or _in_yard(p): continue
		var spaced := true
		for c: Vector2 in centres: if c.distance_to(p) < 15.0: spaced = false
		if spaced: centres.append(p)
	for c: Vector2 in centres:
		var want := rng.randi_range(3, 4)
		for attempt: int in range(40):
			if want <= 0 or placed.size() >= MAX_MAPLES: break
			var p := c + Vector2(rng.randf_range(-9, 9), rng.randf_range(-7, 7))
			if _weight(p, terrain) < 0.55 or _in_yard(p): continue
			if p.distance_to(pav_at) < PAVILION_TREE_GAP: continue
			if not _maple_clear(park, terrain, p, placed, 1.9, 3.8, 4.5): continue
			var height := rng.randf_range(4.8, 7.2)
			placed.append({"p": p, "h": height, "yaw": rng.randf() * TAU, "rust": false})
			want -= 1
		await park.get_tree().process_frame
		if not is_instance_valid(park): return placed
	# About one in six turns rust, never two side by side.
	for i: int in range(placed.size()):
		if i >= banks.size() and i % 7 == 4: placed[i].rust = true
	_frame_pavilion(park, terrain, placed, pavilion)
	var bark := ShaderMaterial.new()
	bark.shader = Shader.new()
	bark.shader.code = MAPLE_BARK_SHADER
	bark.set_shader_parameter("bark_scan", BARK_TILE)
	var foliage := ShaderMaterial.new()
	foliage.shader = Shader.new()
	foliage.shader.code = MAPLE_LEAF_SHADER
	foliage.set_shader_parameter("leaf_vein", LEAF_VEIN)
	var sprays := ShaderMaterial.new()
	sprays.shader = Shader.new()
	sprays.shader.code = MAPLE_SPRAY_SHADER
	sprays.set_shader_parameter("sprays", load(SPRAY_ATLAS))
	var forms: Array[Dictionary] = []
	for seed_value: int in [77951, 77963]:
		forms.append(_maple_form(seed_value, bark, foliage, sprays))
		await park.get_tree().process_frame
		if not is_instance_valid(park): return placed
	var trees := Node3D.new()
	trees.name = "GreenMaples"
	root.add_child(trees)
	for i: int in range(placed.size()):
		var m: Dictionary = placed[i]
		var form: Dictionary = forms[i % forms.size()]
		var s: float = m.h / form.height
		var ground: float = terrain.height_at(m.p)
		var scale3 := Vector3(s * rng.randf_range(1.05, 1.22), s * 0.93, s * rng.randf_range(1.06, 1.22))
		var basis := Basis(Vector3.UP, m.yaw) * Basis.from_scale(scale3)
		var origin := Vector3(m.p.x, ground - 0.035, m.p.y)
		var tint := maple_tint(rng, m.rust)
		var near := MeshInstance3D.new()
		near.name = "Maple_%02d" % i
		near.mesh = form.near
		near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		near.visibility_range_end = MAPLE_NEAR
		near.visibility_range_end_margin = MAPLE_FADE
		near.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		var far := MeshInstance3D.new()
		far.name = "MapleFar_%02d" % i
		far.mesh = form.far
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Near fades out and far fades in across the same band round
		# MAPLE_NEAR (Godot fades over threshold +/- margin), so the crown never
		# drops out between them.
		far.visibility_range_begin = MAPLE_NEAR
		far.visibility_range_begin_margin = MAPLE_FADE
		far.visibility_range_end = MAPLE_FAR_END
		far.visibility_range_end_margin = MAPLE_FAR_END * 0.1
		far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		var shade := MeshInstance3D.new()
		shade.name = "MapleShadow_%02d" % i
		shade.mesh = form.far
		shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		shade.visibility_range_end = MAPLE_SHADOW_END
		for node: MeshInstance3D in [near, far, shade]:
			trees.add_child(node)
			node.global_transform = Transform3D(basis, origin)
		near.set_instance_shader_parameter("tint", tint)
		far.set_instance_shader_parameter("tint", tint)
		# Trunk collision, as the park's other trees have.
		var body := StaticBody3D.new()
		body.name = "MapleTrunk_%02d" % i
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = clampf(0.145 * s, 0.13, 0.24)
		cylinder.height = 2.6
		shape.shape = cylinder
		body.add_child(shape)
		root.add_child(body)
		body.global_position = Vector3(m.p.x, ground + 1.3, m.p.y)
		park.occupied_tree_positions.append(m.p / 2.0)
		park.occupied_tree_is_skinny.append(false)
	return placed

# ------------------------------------------------------------- ground cover

static func _ferns(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, maples: Array, pavilion: Dictionary) -> int:
	var source: Node3D = park.get("midnight_fern_prototype")
	if source == null: return 0
	var parts: Array = []
	var box := AABB()
	var first := true
	for part: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null: continue
		var relative: Transform3D = park._vegetation_relative_transform(part, source)
		var mesh := part.mesh.duplicate() as Mesh
		for surface: int in range(mesh.get_surface_count()): mesh.surface_set_material(surface, part.get_active_material(surface))
		var b: AABB = relative * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
		parts.append({"mesh": mesh, "relative": relative})
	if parts.is_empty(): return 0
	var rows: Array[Transform3D] = []
	for m: Dictionary in maples:
		for k: int in range(rng.randi_range(3, 6)):
			var a := rng.randf() * TAU
			var p: Vector2 = m.p + Vector2(cos(a), sin(a)) * rng.randf_range(0.9, 3.2)
			if not Kit.open_ground(park, terrain, p, 0.8): continue
			if _on_pavilion(pavilion, p, 0.6): continue
			var h := rng.randf_range(0.45, 0.85)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * h / box.size.y)
			var footprint := Transform3D(basis, Vector3.ZERO) * box
			rows.append(Transform3D(basis, Vector3(p.x, terrain.height_at(p) + 0.01 - footprint.position.y, p.y)))
	for part: Dictionary in parts:
		var many := MultiMesh.new()
		many.transform_format = MultiMesh.TRANSFORM_3D
		many.mesh = part.mesh
		many.instance_count = rows.size()
		for i: int in range(rows.size()): many.set_instance_transform(i, rows[i] * part.relative)
		var node := MultiMeshInstance3D.new()
		node.name = "MapleFerns"
		node.multimesh = many
		node.visibility_range_end = 70.0
		root.add_child(node)
	return rows.size()

static func _leaf_floor(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, maples: Array, pavilion: Dictionary) -> int:
	var rows: Array = []
	var pav_at: Vector2 = pavilion.get("p", Vector2.INF)
	for z: int in range(-182, -110):
		for x: int in range(38, 186):
			var cell := Vector2(x + 0.5, z + 0.5)
			var w := _weight(cell, terrain)
			if w < 0.08: continue
			if terrain.water_at(cell): continue
			# Heaped under crowns, drifts between, thin in the yard and on walks.
			var under := 0.0
			for m: Dictionary in maples:
				var d: float = m.p.distance_to(cell)
				if d < 6.0: under = maxf(under, 1.0 - d / 6.0)
			var drift := 0.5 + 0.5 * Biomes.noise().get_noise_2dv(cell * 3.1)
			var per_m2 := (9.0 + 16.0 * drift) * w + 38.0 * under
			if _in_yard(cell): per_m2 *= 0.25
			var walk_edge: float = park.path_edge_distance_world(cell) if park.has_method("path_edge_distance_world") else 9.0
			if walk_edge < 0.4: per_m2 *= 0.12
			var count := int(per_m2) + (1 if rng.randf() < per_m2 - floorf(per_m2) else 0)
			# The plinth covers its own ground: no leaves under it.
			var by_pavilion := cell.distance_to(pav_at) < 4.5
			for k: int in range(count):
				var p := Vector2(x + rng.randf(), z + rng.randf())
				var ground: float = terrain.height_at(p)
				var s := rng.randf_range(0.85, 1.4)
				var basis := Basis(Vector3.UP, rng.randf() * TAU)
				basis = basis * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25)) * Basis(Vector3.FORWARD, rng.randf_range(-0.25, 0.25))
				var lift := rng.randf() * 0.01
				var colour := Kit.leaf_colour(rng, 1.0)
				if by_pavilion and _on_pavilion(pavilion, p, 0.0): continue
				rows.append([Transform3D(basis.scaled(Vector3.ONE * s), Vector3(p.x, ground + 0.012 + lift, p.y)), colour])
		if z % 4 == 0:
			await park.get_tree().process_frame
			if not is_instance_valid(park): return 0
	Kit.cell_batches(root, "FallenMapleLeaves", Kit.leaf_mesh(), Kit.leaf_material(), rows, 8.0, 26.0, false)
	return rows.size()

## The glen floor is leaf litter, not mown lawn: upright blades and lawn tufts
## thin out with the glen's weight, ferns and shrubs stay.
static func _thin_lawn(park: Node3D, terrain: Node) -> Dictionary:
	var area := Rect2(30, -190, 160, 85)
	var filter := func(label: String) -> bool:
		var l := label.to_lower()
		return l.contains("grass") or l.contains("blade") or l.contains("tuft") or l.contains("lawn") or l.contains("woodlandfill") or l.contains("fountain")
	var keep := func(p: Vector2) -> bool:
		if not area.has_point(p): return true
		return not Biomes.pick(p, smoothstep(0.35, 0.85, _weight(p, terrain)) * 0.92, 11)
	if ResourceLoader.exists("res://scripts/biomes/thin_all.gd"):
		return load("res://scripts/biomes/thin_all.gd").hide_low_planting(park, filter, keep, area)
	return {}

## Relief supplies round the pavilion: crates and water tanks. The crate stack
## that stood where the pavilion now is moves to its far side, off the view.
static func _yard_supplies(park: Node3D, pavilion: Dictionary) -> int:
	var cover: Node = null
	for child: Node in park.get_children():
		if child.has_method("_kind_relief_crates") and child.has_method("_kind_water_tanks"):
			cover = child
			break
	if cover == null or cover.get("installed") != true: return 0
	cover.set("_batches", {})
	var made := 0
	var spots := [[Vector2(137, -139), "_kind_relief_crates", 0.4], [Vector2(140, -155), "_kind_water_tanks", 1.9], [Vector2(167, -153), "_kind_relief_crates", 2.6], [Vector2(168, -138), "_kind_water_tanks", 4.1]]
	if not pavilion.is_empty():
		var at: Vector2 = pavilion.p
		var entrance := (YARD_C - at).normalized()
		spots[0][0] = at + Vector2(entrance.y, -entrance.x) * 6.5
		for spot: Array in spots:
			var off: Vector2 = spot[0] - at
			if off.length() < 6.5: spot[0] = at + off.normalized() * 6.5
		cover.get("_reserved").append(at)
	for spot: Array in spots:
		var found: Variant = cover.call("_find_spot", spot[0], 1.6, 4.0, 3, false)
		if found == null: continue
		var spot_at: Vector2 = found
		if _on_pavilion(pavilion, spot_at, 1.8): continue
		var origin := Transform3D(Basis(Vector3.UP, float(spot[2])), Vector3(spot_at.x, cover.call("_ground", spot_at) - 0.02, spot_at.y))
		cover.call(String(spot[1]), origin)
		cover.get("_reserved").append(spot_at)
		made += 1
	cover.call("_commit")
	return made
