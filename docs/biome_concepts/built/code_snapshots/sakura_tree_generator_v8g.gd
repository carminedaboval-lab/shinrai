extends RefCounted
## Procedural somei-yoshino cherry (Prunus x yedoensis), after
## docs/biome_concepts/closeup/SOMEI_YOSHINO_REFERENCE.md: a short flaring
## trunk forking low into 3-5 leaders that rise at 40-60 deg and arch out to
## near level, then limbs, branches and zig-zag twigs (5 orders counting the
## trunk), each child rolled ~137 deg round its parent, shorter and thinner
## (pipe model), every branch tapering to a 4-5 mm tip. The crown is a broad
## flat-topped umbrella (about 1.5x as wide as tall) with the limb tips
## drooping. Flowers come in clusters of 4-6 on short stalks from one bud
## point, every few cm along the outer twigs and sparser on older wood, each
## cluster a pair of small crossed cards (cluster_texture()).
##
## build(seed) is deterministic and returns three level-of-detail meshes in
## tree space (metres at the reference height H, foot of the trunk at the
## origin), each with two surfaces: 0 bark, 1 bloom.
##  near: every twig and cluster;
##  mid: the finest twigs dropped, a third of the clusters grown to cover;
##  far: leaders and limbs only, a tenth of the clusters grown to cover.

const H := 8.5
# Crown radius and the height of its rim: the umbrella's top is flat at H and
# falls off toward the rim (see _top).
const R := 6.3
const EDGE_Y := 3.9
const TRUNK_R := 0.3
const TIP_R := 0.006
const PIPE := 2.0
const MAX_ORDER := 4
# Per order (0 trunk, 1 leaders, 2 limbs, 3 branches, 4 twigs).
const SEG: Array[float] = [0.3, 0.4, 0.28, 0.14, 0.085]
const SIDES_NEAR: Array[int] = [12, 9, 6, 4, 3]
const SIDES_MID: Array[int] = [7, 5, 3, 0, 0]
const SIDES_FAR: Array[int] = [6, 4, 3, 0, 0]
# Children along a parent of this order: spacing (m) and where they start
# (share of the parent's length; the lower leaders stay bare).
const GAP: Array[float] = [0.0, 0.42, 0.32, 0.14, 0.0]
const FIRST: Array[float] = [0.0, 0.12, 0.14, 0.1, 0.0]
# Longest child of each order (m).
const MAX_LEN: Array[float] = [0.0, 7.2, 3.8, 2.0, 0.8]
const UP_BIAS: Array[float] = [0.0, 0.0, 0.55, 0.22, 0.08]
const DROOP: Array[float] = [0.0, 0.0, 0.2, 0.42, 0.6]
# Zig-zag at the bud nodes of the last two orders (radians).
const ZIG := 0.24
const BARK_TILE := 0.35
# A flower cluster card (m); buds along twigs, spurs on branches and limbs.
const CLUSTER := 0.16
# Near: NEAR_CARDS single-cluster cards of CLUSTER_NEAR m at each bud.
const CLUSTER_NEAR := 0.1
const NEAR_CARDS := 2
const BUDS: Array = [[], [], [0.2, 0.14, 0.24], [0.08, 0.05, 0.09], [0.05, 0.032, 0.05]]
const MID_KEEP := 8
const MID_GROW := 2.8
const FAR_KEEP := 24
const FAR_GROW := 4.8

const BARK_TEX := "res://assets/shinrai/vegetation/sakura/jogoss_sakura_01/Bark001_2K_JPG.png"
const BARK_NORMAL := "res://assets/shinrai/vegetation/sakura/jogoss_sakura_01/Bark_Normal.png"

class Branch:
	var order := 0
	var points := PackedVector3Array()
	var radii := PackedFloat32Array()
	var along := PackedFloat32Array()
	var kids: Array = []

	func add(p: Vector3) -> void:
		along.append(0.0 if points.is_empty() else along[along.size() - 1] + p.distance_to(points[points.size() - 1]))
		points.append(p)

	func length() -> float:
		return along[along.size() - 1] if not along.is_empty() else 0.0

	func dir_at(i: int) -> Vector3:
		var a := points[maxi(i - 1, 0)]
		var b := points[mini(i + 1, points.size() - 1)]
		var d := b - a
		return d.normalized() if d.length() > 1e-6 else Vector3.UP

class Geo:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var i := PackedInt32Array()

	func arrays() -> Array:
		var a: Array = []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = v
		a[Mesh.ARRAY_NORMAL] = n
		a[Mesh.ARRAY_TEX_UV] = uv
		if not uv2.is_empty(): a[Mesh.ARRAY_TEX_UV2] = uv2
		a[Mesh.ARRAY_INDEX] = i
		return a

## One tree variant. Returns {near, mid, far: ArrayMesh, box: AABB,
## trunk_r: float, stats: Dictionary}.
static func build(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var trunk := _grow_trunk(rng)
	_pipe(trunk)
	var fork_r: float = trunk.radii[maxi(trunk.radii.size() - 2, 0)]
	var k := TRUNK_R / maxf(fork_r, 0.001)
	_rescale(trunk, fork_r, k)
	var counts := {"branches": [0, 0, 0, 0, 0]}
	_count(trunk, counts)
	var clusters: Array = []
	_buds(trunk, clusters, rng)
	var meshes: Array = []
	for lod: int in range(3):
		var bark := Geo.new()
		_bark(bark, trunk, lod)
		var bloom := Geo.new()
		var keep: int = [1, MID_KEEP, FAR_KEEP][lod]
		var grow: float = [1.0, MID_GROW, FAR_GROW][lod]
		for c: int in range(0, clusters.size(), keep):
			if lod == 0: _near_cards(bloom, clusters[c])
			else: _cluster_cards(bloom, clusters[c], grow)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bark.arrays())
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bloom.arrays())
		meshes.append(mesh)
	var box: AABB = (meshes[0] as ArrayMesh).get_aabb()
	var stats := {"branches_by_order": counts.branches, "clusters": clusters.size()}
	for lod: int in range(3):
		var mesh: ArrayMesh = meshes[lod]
		stats[["near", "mid", "far"][lod] + "_tris"] = [mesh.surface_get_array_index_len(0) / 3, mesh.surface_get_array_index_len(1) / 3]
	stats["height"] = snappedf(box.end.y, 0.01)
	stats["spread"] = snappedf(maxf(box.size.x, box.size.z), 0.01)
	return {"near": meshes[0], "mid": meshes[1], "far": meshes[2], "box": box, "trunk_r": TRUNK_R * 1.1, "stats": stats}

# --- skeleton ----------------------------------------------------------------

static func _grow_trunk(rng: RandomNumberGenerator) -> Branch:
	var trunk := Branch.new()
	trunk.order = 0
	var fork := rng.randf_range(1.7, 2.3)
	var lean := Vector3(rng.randfn() * 0.05, 1.0, rng.randfn() * 0.05).normalized()
	var steps := ceili(fork / SEG[0])
	for s: int in range(steps + 1):
		var wobble := Vector3(rng.randfn(), 0.0, rng.randfn()) * 0.02 if s > 0 else Vector3.ZERO
		trunk.add(lean * fork * float(s) / float(steps) + wobble)
	# A low dome above the fork, hidden among the leaders.
	trunk.add(trunk.points[trunk.points.size() - 1] + lean * 0.22)
	var n := rng.randi_range(3, 5)
	var a0 := rng.randf() * TAU
	var at := trunk.points.size() - 2
	for i: int in range(n):
		var az := a0 + TAU * (float(i) + rng.randf_range(-0.22, 0.22)) / float(n)
		var el := deg_to_rad(rng.randf_range(40.0, 60.0))
		var length := rng.randf_range(5.6, 7.0)
		var node := at if i % 2 == 0 else maxi(at - 1, 1)
		trunk.kids.append([node, _grow_leader(trunk.points[node], az, el, length, rng)])
	return trunk

## A leader: rises at `el`, then arches out to just below level.
static func _grow_leader(start: Vector3, az: float, el: float, length: float, rng: RandomNumberGenerator) -> Branch:
	var b := Branch.new()
	b.order = 1
	var steps := ceili(length / SEG[1])
	var p := start
	b.add(p)
	var turn := az
	var arch := rng.randf_range(0.25, 0.4)
	for s: int in range(1, steps + 1):
		var t := float(s) / float(steps)
		var e := lerpf(el, deg_to_rad(-6.0), smoothstep(arch, 1.0, t)) + rng.randfn() * 0.05
		turn += rng.randfn() * 0.05
		var d := Vector3(cos(turn) * cos(e), sin(e), sin(turn) * cos(e))
		p += d * length / float(steps)
		b.add(p)
		if not _inside(p, 0.06): break
	_branch(b, rng)
	return b

## A branch of `order` from `start` along `dir`, up to `length` m: drooping
## toward the tip, held under the crown's flat top, zig-zag at the buds of the
## last two orders; it stops where it leaves the crown (each its own slack, so
## the outline is ragged).
static func _grow(start: Vector3, dir: Vector3, length: float, order: int, rng: RandomNumberGenerator) -> Branch:
	var b := Branch.new()
	b.order = order
	var steps := maxi(2, ceili(length / SEG[order]))
	var step := length / float(steps)
	var p := start
	var d := dir
	var slack := rng.randf_range(-0.05, 0.1)
	var zig_axis := dir.cross(Vector3(rng.randfn(), rng.randfn(), rng.randfn())).normalized()
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	b.add(p)
	for s: int in range(1, steps + 1):
		var t := float(s) / float(steps)
		d.y -= DROOP[order] * step * t
		if p.y > _top(Vector2(p.x, p.z).length()) - 0.7: d.y -= 0.5 * step
		if order >= 3:
			var axis := (zig_axis - d * zig_axis.dot(d))
			if axis.length() > 0.01: d = d.rotated(axis.normalized(), ZIG * side * rng.randf_range(0.6, 1.2))
			side = -side
		d = (d + Vector3(rng.randfn(), rng.randfn(), rng.randfn()) * 0.05).normalized()
		p += d * step
		b.add(p)
		if not _inside(p, slack): break
	_branch(b, rng)
	return b

## Children along `b`: rolled round it by the golden angle, leaving at 30-55
## deg, shorter toward its tip, lifted a little (the upper shoots build the
## crown's height), never hanging steeply.
static func _branch(b: Branch, rng: RandomNumberGenerator) -> void:
	if b.order >= MAX_ORDER or b.points.size() < 3: return
	var o := b.order
	var length := b.length()
	var a := FIRST[o] * length + GAP[o] * rng.randf_range(0.3, 1.0)
	var roll := rng.randf() * TAU
	var i := 0
	while a < length * 0.96:
		while i < b.along.size() - 1 and b.along[i] < a: i += 1
		var d := b.dir_at(i)
		var t := a / length
		roll += deg_to_rad(137.5) + rng.randfn() * 0.3
		var ang := deg_to_rad(rng.randf_range(30.0, 55.0))
		var perp := d.cross(Vector3.UP)
		if perp.length() < 0.01: perp = d.cross(Vector3.RIGHT)
		perp = perp.normalized().rotated(d, roll)
		var cd := (d * cos(ang) + perp * sin(ang)).normalized()
		var p := b.points[i]
		var out := Vector3(p.x, 0.0, p.z).normalized() if Vector2(p.x, p.z).length() > 0.05 else Vector3.ZERO
		cd = (cd + Vector3.UP * UP_BIAS[o + 1] + out * 0.2).normalized()
		if cd.y < -0.45:
			cd.y = -0.45
			cd = cd.normalized()
		var child_len := minf(MAX_LEN[o + 1], length * rng.randf_range(0.6, 0.75)) * lerpf(1.0, 0.5, t)
		var child := _grow(p, cd, child_len, o + 1, rng)
		if child.points.size() >= 2: b.kids.append([i, child])
		a += GAP[o] * rng.randf_range(0.7, 1.3)

## The crown: a flat-topped umbrella, H at the middle falling to EDGE_Y at R.
static func _top(rho: float) -> float:
	return H - (H - EDGE_Y) * pow(clampf(rho / R, 0.0, 1.3), 2.6)

static func _inside(p: Vector3, slack: float) -> bool:
	var rho := Vector2(p.x, p.z).length()
	if rho > R * (1.0 + slack): return false
	if p.y > _top(rho) * (1.0 + slack * 0.4): return false
	return p.y > 1.5

## Pipe model: from a 4.5 mm tip a branch thickens a little along its own
## length, and at each node r^PIPE grows by its children's r^PIPE.
static func _pipe(b: Branch) -> float:
	var n := b.points.size()
	b.radii.resize(n)
	var extra := PackedFloat32Array()
	extra.resize(n)
	for kid: Array in b.kids:
		var r := _pipe(kid[1])
		extra[kid[0]] += pow(r, PIPE)
	var acc := pow(TIP_R, PIPE)
	var total := b.length()
	for i: int in range(n - 1, -1, -1):
		acc += extra[i]
		b.radii[i] = maxf(pow(acc, 1.0 / PIPE), TIP_R * (1.0 + 0.6 * (total - b.along[i])))
	return b.radii[0]

## Scales the thick wood to a TRUNK_R trunk at the fork, the twigs barely.
static func _rescale(b: Branch, ref: float, k: float) -> void:
	for i: int in range(b.radii.size()):
		var r := b.radii[i]
		b.radii[i] = r * (1.0 + (k - 1.0) * sqrt(clampf(r / ref, 0.0, 1.0)))
	if b.order == 0:
		# The trunk thickens a little toward the ground.
		var top := b.points[b.points.size() - 2].y
		for i: int in range(b.radii.size()):
			b.radii[i] *= 1.0 + 0.08 * maxf(0.0, top - b.points[i].y)
	for kid: Array in b.kids: _rescale(kid[1], ref, k)

static func _count(b: Branch, counts: Dictionary) -> void:
	counts.branches[b.order] += 1
	for kid: Array in b.kids: _count(kid[1], counts)

# --- bark mesh ---------------------------------------------------------------

static func _bark(g: Geo, b: Branch, lod: int) -> void:
	var sides: int = [SIDES_NEAR, SIDES_MID, SIDES_FAR][lod][b.order]
	if sides < 3: return
	_tube(g, b, sides)
	for kid: Array in b.kids: _bark(g, kid[1], lod)

## A generalized cylinder along the branch (parallel-transported frame), its
## tip closed to a point. UV: x round the girth, y along the length (laid
## round the branch the texture's furrows read as regular stripes); UV2:
## order and length (m) for the shader.
static func _tube(g: Geo, b: Branch, sides: int) -> void:
	var n := b.points.size()
	if n < 2: return
	var base := g.v.size()
	var d0 := b.dir_at(0)
	var normal := d0.cross(Vector3.UP)
	if normal.length() < 0.01: normal = d0.cross(Vector3.RIGHT)
	normal = normal.normalized()
	var around := maxf(1.0, roundf(TAU * b.radii[0] / BARK_TILE))
	var flare := b.order == 0
	var phase := float(hash(b.points[0]) % 100) * 0.1
	for i: int in range(n):
		var d := b.dir_at(i)
		normal = (normal - d * normal.dot(d)).normalized()
		var binormal := d.cross(normal)
		var r := b.radii[i] if i < n - 1 or flare else 0.0
		if flare and i == n - 1: r *= 0.45
		var p := b.points[i]
		for k: int in range(sides + 1):
			var a := TAU * float(k) / float(sides)
			var out := normal * cos(a) + binormal * sin(a)
			var rr := r
			if flare:
				# Root flare 1.8x at the ground, lobed into buttresses.
				var w := exp(-p.y / 0.35)
				rr *= 1.0 + 0.8 * w + 0.22 * w * sin(5.0 * a + phase)
			g.v.append(p + out * rr)
			g.n.append(out)
			g.uv.append(Vector2(float(k) / float(sides) * around, b.along[i] / (2.0 * BARK_TILE)))
			g.uv2.append(Vector2(float(b.order), b.along[i]))
	var s1 := sides + 1
	for i: int in range(n - 1):
		for k: int in range(sides):
			var a := base + i * s1 + k
			g.i.append_array([a, a + s1, a + 1, a + 1, a + s1, a + s1 + 1])

# --- flowers -----------------------------------------------------------------

## Bud points: along the twigs every 4.5-7.5 cm from near their base, on the
## outer branches every 13-22 cm, on the limbs a few spurs; each a cluster
## [bud, hang direction, roll, size, atlas cell, side of the twig it sits on,
## twig direction]. A twig's tip has one too.
static func _buds(b: Branch, out: Array, rng: RandomNumberGenerator) -> void:
	for kid: Array in b.kids: _buds(kid[1], out, rng)
	if b.order < 2 or b.points.size() < 2: return
	var spec: Array = BUDS[b.order]
	var length := b.length()
	var a := float(spec[0]) * length
	var i := 0
	while a <= length:
		while i < b.along.size() - 2 and b.along[i + 1] < a: i += 1
		var seg := maxf(b.along[i + 1] - b.along[i], 1e-5)
		var f := clampf((a - b.along[i]) / seg, 0.0, 1.0)
		var p := b.points[i].lerp(b.points[i + 1], f)
		var r := lerpf(b.radii[i], b.radii[i + 1], f)
		var d := (b.points[i + 1] - b.points[i]).normalized()
		var perp := d.cross(Vector3.UP)
		if perp.length() < 0.01: perp = d.cross(Vector3.RIGHT)
		perp = perp.normalized().rotated(d, rng.randf() * TAU)
		var bud := p + perp * r
		var outward := Vector3(bud.x, 0.0, bud.z).normalized()
		var hang := (perp * 0.55 + Vector3.DOWN * 0.7 + outward * 0.3 + Vector3(rng.randfn(), rng.randfn(), rng.randfn()) * 0.25).normalized()
		out.append([bud, hang, rng.randf() * TAU, CLUSTER * rng.randf_range(0.85, 1.15), rng.randi() % 4, perp, d])
		a += rng.randf_range(float(spec[1]), float(spec[2]))
	if b.order == MAX_ORDER:
		var tip := b.points[b.points.size() - 1]
		var d := b.dir_at(b.points.size() - 1)
		var tperp := d.cross(Vector3.UP)
		if tperp.length() < 0.01: tperp = d.cross(Vector3.RIGHT)
		out.append([tip, (d * 0.5 + Vector3.DOWN * 0.6).normalized(), rng.randf() * TAU, CLUSTER, rng.randi() % 4, tperp.normalized(), d])

## A cluster as three crossed cards round a point just below its bud along
## the hang (the cluster is a loose ball of flowers there): two upright, one
## across the hang so it also reads from below; `grow` x its size.
static func _cluster_cards(g: Geo, c: Array, grow: float) -> void:
	var bud: Vector3 = c[0]
	var hang: Vector3 = c[1]
	var s: float = float(c[3]) * grow
	var cell: int = c[4]
	var off := Vector2(float(cell % 4) * 0.25, 0.0)
	var side := hang.cross(Vector3.UP)
	if side.length() < 0.01: side = hang.cross(Vector3.RIGHT)
	side = side.normalized().rotated(hang, float(c[2]))
	var side2 := hang.cross(side).normalized()
	var centre := bud + hang * 0.2 * s
	for q: int in range(3):
		var sd := side if q != 1 else side2
		var up := hang if q < 2 else side2
		if q == 2: sd = side
		var face := sd.cross(up).normalized()
		var base := g.v.size()
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			g.v.append(centre + sd * (corner.x - 0.5) * s + up * (corner.y - 0.5) * s)
			g.n.append(face)
			g.uv.append(off + corner * Vector2(0.25, 0.5))
		g.i.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

## The near clusters: at each bud NEAR_CARDS single-cluster cards (8-12 cm,
## flowers 3-3.5 cm), each its own small hang off the bud and facing out from
## the twig and down with jitter, the cluster's bud texel on the bud, so the
## stalks meet the twig and no pair of large cards crosses square in view.
static func _near_cards(g: Geo, c: Array) -> void:
	var bud: Vector3 = c[0]
	var hang: Vector3 = c[1]
	var away: Vector3 = c[5]
	var twig: Vector3 = c[6]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i((bud * 1000.0).round()))
	for k: int in range(NEAR_CARDS):
		var h := (hang + Vector3(rng.randfn(), rng.randfn(), rng.randfn()) * 0.4).normalized()
		var face := away.rotated(twig, rng.randf_range(-1.2, 1.2)) * 0.55 + Vector3.DOWN * 0.6 + Vector3(rng.randfn(), rng.randfn(), rng.randfn()) * 0.35
		face -= h * face.dot(h)
		if face.length() < 0.05: face = h.cross(twig)
		if face.length() < 0.05: face = h.cross(Vector3.RIGHT)
		face = face.normalized()
		var sd := h.cross(face).normalized()
		if rng.randf() < 0.5: sd = -sd
		# The first card at each bud shows the cluster and its neighbour on the
		# spur (the top atlas row), the others single clusters.
		var pair := k == 0
		var s := (CLUSTER * 0.82 if pair else CLUSTER_NEAR) * rng.randf_range(0.8, 1.15)
		var cell := rng.randi() % 4
		var off := Vector2(float(cell) * 0.25, 0.0 if pair else 0.5)
		var anchor := Vector2(0.5 - 0.06 * (1.0 if cell % 2 == 0 else -1.0), 0.33) if pair else Vector2(0.5, 0.38)
		var base := g.v.size()
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			g.v.append(bud + sd * (corner.x - anchor.x) * s + h * (corner.y - anchor.y) * s)
			g.n.append(face)
			g.uv.append(off + corner * Vector2(0.25, 0.5))
		g.i.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

# --- materials ---------------------------------------------------------------

## Flower clusters, a 4 x 2 atlas: top row four cells of two neighbouring
## clusters (CLUSTER cards: mid and far), bottom row four single clusters
## (CLUSTER_NEAR cards: near). In each, from a
## bud point near the middle, 4-6 stalks of 2-2.5 cm fan out (mostly down
## and sideways), a couple of short ones toward the viewer, each with an open
## flower 3-3.5 cm across: five rounded petals notched at the
## tip, near-white with a pink blush toward the base, a deeper pink eye and a
## ring of pale stamens; a dark red-brown bud scale where the stalks meet.
static func cluster_texture() -> ImageTexture:
	var cell := 256
	var cm := float(cell) / (CLUSTER * 100.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33017
	var image := Image.create(cell * 4, cell * 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.95, 0.8, 0.84, 0.0))
	# Bottom row: a single cluster per cell (the near cards), its bud at 38%
	# down the cell.
	var cm_near := float(cell) / (CLUSTER_NEAR * 100.0)
	for c: int in range(4):
		var origin := Vector2(float(c) * cell, float(cell))
		_cluster(image, origin + Vector2(cell * 0.5, cell * 0.38), cm_near, rng, origin, cell)
	for c: int in range(4):
		var origin := Vector2(float(c) * cell, 0.0)
		# A neighbouring cluster on the same spur, behind, then the bud's own.
		var flowers: Array = []
		var side := 1.0 if c % 2 == 0 else -1.0
		var buds: Array = [origin + Vector2(cell * (0.5 + 0.2 * side), cell * 0.55), origin + Vector2(cell * (0.5 - 0.06 * side), cell * 0.33)]
		for bud: Vector2 in buds:
			_cluster(image, bud, cm, rng, origin, cell)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func _cluster(image: Image, bud: Vector2, cm: float, rng: RandomNumberGenerator, origin: Vector2, cell: int) -> void:
		var count := rng.randi_range(4, 6) + 2
		var flowers: Array = []
		for k: int in range(count):
			var ang := PI * 0.5 + lerpf(-2.6, 2.6, (float(k) + rng.randf_range(0.2, 0.8)) / float(count))
			var stalk := rng.randf_range(2.0, 2.5) * cm
			# The last two point toward the viewer: seen foreshortened, near the bud.
			if k >= count - 2: stalk *= rng.randf_range(0.25, 0.5)
			var at := bud + Vector2(cos(ang), sin(ang)) * stalk
			_line(image, bud, at, 0.09 * cm, Color(0.42, 0.24, 0.2, 1.0), origin, cell)
			flowers.append(at)
		flowers.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
		for at: Vector2 in flowers:
			_flower(image, at, rng.randf_range(1.5, 1.75) * cm, rng.randf() * TAU, rng.randf(), origin, cell)
		_line(image, bud, bud, 0.22 * cm, Color(0.4, 0.17, 0.17, 1.0), origin, cell)

static func _line(image: Image, a: Vector2, b: Vector2, w: float, col: Color, origin: Vector2, cell: int) -> void:
	var steps := int(a.distance_to(b)) + 1
	for s: int in range(steps + 1):
		var p := a.lerp(b, float(s) / float(steps))
		for dy: int in range(-ceili(w), ceili(w) + 1):
			for dx: int in range(-ceili(w), ceili(w) + 1):
				if float(dx * dx + dy * dy) > w * w + 0.25: continue
				var x := int(p.x) + dx
				var y := int(p.y) + dy
				if x < origin.x or y < origin.y or x >= origin.x + cell or y >= origin.y + cell: continue
				image.set_pixel(x, y, col)

static func _flower(image: Image, c: Vector2, r: float, turn: float, blush: float, origin: Vector2, cell: int) -> void:
	for dy: int in range(-ceili(r) - 1, ceili(r) + 2):
		for dx: int in range(-ceili(r) - 1, ceili(r) + 2):
			var x := int(c.x) + dx
			var y := int(c.y) + dy
			if x < origin.x or y < origin.y or x >= origin.x + cell or y >= origin.y + cell: continue
			var d := Vector2(dx, dy)
			var dist := d.length() / r
			if dist > 1.0: continue
			# Five lobes, narrowing between petals; a notch at each petal tip.
			var ang := fposmod(atan2(d.y, d.x) - turn, TAU / 5.0) - TAU / 10.0
			# Rounded petals with a soft rim (so the magnified alpha scissor
			# traces a smooth round outline, not torn paper) and a small notch.
			var edge := 0.62 + 0.38 * sqrt(maxf(cos(ang * 2.5), 0.0))
			if absf(ang) < 0.08: edge -= 0.1 * (1.0 - absf(ang) / 0.08)
			var cover := smoothstep(edge, edge - 0.12, dist)
			if cover <= 0.0: continue
			var t := dist / edge
			var white := Color(0.98, 0.88, 0.9)
			var pink := Color(0.92, 0.62, 0.71).lerp(Color(0.96, 0.74, 0.8), blush)
			var col := pink.lerp(white, smoothstep(0.2, 0.9, t))
			col = col * lerpf(0.9, 1.0, smoothstep(0.0, 0.3, absf(ang) * 3.0 + (1.0 - t) * 0.4))
			if dist < 0.18: col = Color(0.8, 0.32, 0.45)
			elif dist < 0.33 and fmod(atan2(d.y, d.x) * 7.0 + 10.0, 1.0) < 0.4: col = Color(0.96, 0.88, 0.74)
			var old := image.get_pixel(x, y)
			col.a = maxf(cover, old.a)
			if old.a > cover: col = old
			image.set_pixel(x, y, col)

## Somei-yoshino bark: the source bark texture laid round the branch (its
## furrows become horizontal strips), warm red/grey-brown, fairly glossy;
## young twigs (orders 3-4) slender, smooth and reddish-brown; on the trunk and
## leaders short horizontal lenticel dashes, faint and gone by ~12 m so they
## never read as stripes; a faint warm lift so the shaded side stays brown.
const BARK_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap;
uniform sampler2D bark : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint = vec3(1.5, 1.42, 1.42);
uniform vec3 young_tint = vec3(0.11, 0.045, 0.035);
varying float order;
varying float along;

void vertex() {
	order = UV2.x;
	along = UV2.y;
}

float h1(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	vec3 tex = texture(bark, UV).rgb;
	float g0 = dot(tex, vec3(0.3, 0.59, 0.11));
	vec3 c = mix(vec3(g0), tex, 0.55) * tint;
	float young = smoothstep(2.5, 3.5, order);
	float grey = dot(tex, vec3(0.3, 0.59, 0.11));
	c = mix(c, young_tint * (0.75 + 2.5 * grey), young);
	float row = floor(along / 0.045);
	float in_row = fract(along / 0.045);
	float width = 0.07 + 0.06 * h1(row * 3.1);
	float line = smoothstep(width, width * 0.4, abs(in_row - 0.5 - 0.3 * (h1(row) - 0.5)));
	float around = UV.x * (5.0 + 5.0 * h1(row * 7.7));
	float dash = step(0.5, h1(row * 13.0 + floor(around + h1(row) * 5.0)));
	float thick = 1.0 - smoothstep(1.5, 2.5, order);
	float near = 1.0 - smoothstep(4.0, 12.0, length(VERTEX));
	float lenticel = line * dash * thick * near;
	c = mix(c, c * 0.5, lenticel * 0.6);
	ALBEDO = c;
	NORMAL_MAP = texture(bark_normal, UV).rgb;
	NORMAL_MAP_DEPTH = mix(0.5, 0.15, young);
	ROUGHNESS = mix(0.5, 0.4, young) + lenticel * 0.3;
	SPECULAR = 0.45;
	EMISSION = c * 0.3;
}
"""

static func bark_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = BARK_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	if ResourceLoader.exists(BARK_TEX): material.set_shader_parameter("bark", load(BARK_TEX))
	if ResourceLoader.exists(BARK_NORMAL): material.set_shader_parameter("bark_normal", load(BARK_NORMAL))
	return material
