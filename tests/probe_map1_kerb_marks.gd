extends SceneTree
## Headless check of the kerb surface interface on `map1_street.gd`:
##   godot --headless --path . --script res://tests/probe_map1_kerb_marks.gd
##
## The interface is default off, so the trial probe runs the unmarked path and can say nothing
## about the marked one. This probe turns it on. It builds the same short street twice over flat
## ground — once unmarked, once marked — and asks three things of the pair:
##
##   1. the two meshes are the same geometry in the same order, triangle for triangle, so turning
##      the marking on cannot turn a face inwards (the fault Codex found in `_tri_marked` by
##      reading the source, which no default-off check could have caught);
##   2. every marked vertex's alpha decodes back to its own height above the road, so a lowered
##      kerb's top is tagged low and a full kerb's top is tagged full;
##   3. a kerb surface material given to the street reaches the built mesh.
##
## It builds no world and reads no ground picture: the street stands on a flat stub, so a
## vertex's own y is its height above the road and the decoded alpha can be compared with it.
## Prints KERB_PASS / KERB_FAIL lines and KERB_DONE passed=N failed=M.

const Street := preload("res://scripts/map1/map1_street.gd")

var passed := 0
var failed := 0


## The flat ground a street needs to be laid on: `at()` asks the map for a height, and nothing
## else of the map is touched while the edge is exact and carries no crossings.
class FlatGround extends Node3D:
	var ground_image: Image = null
	var frame := Rect2()
	func ground_height(_x: float, _z: float) -> float: return 0.0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("KERB_%s %s" % ["PASS" if ok else "FAIL", text])


## One street, 48 m of straight kerb with a corner at its east end and a nose at its west, and a
## lowered kerb in the middle so the marked heights have something other than full kerb to carry.
func _street(ground: Node3D, marked: bool, surface: Material = null, toned := false, curved := true) -> Node3D:
	var street: Node3D = Street.new()
	street.marked_kerb = marked
	street.cast_corner_tones = toned
	street.kerb_surface_material = surface
	ground.add_child(street)
	street.lay(ground, {
		"name": "kerb marks probe",
		"w": 7.0,
		"pavement": 2.4,
		"exact": true,
		"points": [[0.0, 0.0], [48.0, 0.0]],
	}, 1.0)
	# A corner at the east end and a rounded nose at the west: both are built by `_piece`, which
	# is the half of the interface the straight units do not cover. A street built without them
	# is the same mesh with the curved work left off the end, which is how the checks below tell
	# a curve's vertices from a straight unit's.
	if curved:
		street.corners.append({"mouth": 48.0, "dir": 1.0, "from": 44.0, "deep": 0.0})
		street.noses.append(-1.0)
	# A lowered kerb across the middle, with its ramps: the only way a marked top is not full height.
	street.drops.append(Vector2(22.8, 24.6))
	street.build([], [])
	return street


## Two colours the same to within one 8-bit step, which is all a vertex colour can hold.
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= 0.005 and absf(a.g - b.g) <= 0.005 and absf(a.b - b.b) <= 0.005


func _arrays(street: Node3D) -> Dictionary:
	var instance := street.get_node_or_null("Edge") as MeshInstance3D
	if instance == null or instance.mesh == null: return {}
	var mesh: Mesh = instance.mesh
	if mesh.get_surface_count() == 0: return {}
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# The kerb's mesh comes out of `SurfaceTool` unindexed — a triangle soup, so the vertex order
	# is already the draw order. Where there is no index buffer, stand in one that reads straight
	# through, so the comparison below is written one way for both cases.
	var index := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		index = arrays[Mesh.ARRAY_INDEX]
	else:
		index.resize(points.size())
		for i: int in points.size(): index[i] = i
	return {
		"points": points,
		"colours": arrays[Mesh.ARRAY_COLOR] as PackedColorArray,
		"index": index,
		"override": instance.material_override,
	}


func _run() -> void:
	var ground := FlatGround.new()
	root.add_child(ground)
	var plain := _street(ground, false)
	var marked := _street(ground, true)
	var a := _arrays(plain)
	var b := _arrays(marked)
	_check(not a.is_empty() and not b.is_empty(), "both streets built a kerb mesh")
	if a.is_empty() or b.is_empty():
		_done()
		return

	# 1. The same geometry in the same order. The vertex lists are compared through the index
	# buffers, so the comparison is of the triangles as drawn: a face turned the other way would
	# put its second and third corners the other way round and show up here.
	var pa: PackedVector3Array = a.points
	var pb: PackedVector3Array = b.points
	var ia: PackedInt32Array = a.index
	var ib: PackedInt32Array = b.index
	_check(ia.size() == ib.size(), "the marked street draws the same number of corners: %d against %d" % [ib.size(), ia.size()])
	var moved := 0
	var worst := 0.0
	var first_moved := -1
	for k: int in mini(ia.size(), ib.size()):
		var gap: float = pa[ia[k]].distance_to(pb[ib[k]])
		if gap > worst: worst = gap
		if gap > 0.0005:
			moved += 1
			if first_moved < 0: first_moved = k
	_check(moved == 0, "every one of the %d drawn corners is in the same place in the same order (worst %.4f mm%s)" % [ib.size(), worst * 1000.0, "" if first_moved < 0 else ", first apart at corner %d" % first_moved])

	# Turning a face would be invisible to a distance test alone if two corners happened to share
	# a place, so the winding is also checked against the plain street's own face normals.
	var turned := 0
	for t: int in mini(ia.size(), ib.size()) / 3:
		var na: Vector3 = (pa[ia[t * 3 + 1]] - pa[ia[t * 3]]).cross(pa[ia[t * 3 + 2]] - pa[ia[t * 3]])
		var nb: Vector3 = (pb[ib[t * 3 + 1]] - pb[ib[t * 3]]).cross(pb[ib[t * 3 + 2]] - pb[ib[t * 3]])
		if na.length() < 1e-9 or nb.length() < 1e-9: continue
		if na.normalized().dot(nb.normalized()) < 0.999: turned += 1
	_check(turned == 0, "no face faces the other way: %d of %d triangles turned" % [turned, ib.size() / 3])

	# 2. Every marked alpha decodes back to that vertex's own height above the road. The ground is
	# flat at y 0, so a vertex's y is its height. A kerb's own range of heights (-5 cm to +13 cm)
	# encodes to alpha 0.10 to 0.46, so what is left at alpha 1 is what the interface does not
	# tag — the end fans seen through the joints — and is passed over.
	var colours: PackedColorArray = b.colours
	_check(colours.size() == pb.size(), "the marked mesh carries a colour for every vertex: %d of %d" % [colours.size(), pb.size()])
	var tagged := 0
	var wrong := 0
	var off := 0.0
	var low_tags := 0
	for v: int in mini(colours.size(), pb.size()):
		var alpha := colours[v].a
		if is_equal_approx(alpha, 1.0): continue      # unmarked: an end fan, a pole, a wire
		tagged += 1
		var up: float = (alpha - Street.KERB_ALPHA_BASE) / Street.KERB_ALPHA_SCALE
		var gap: float = absf(up - pb[v].y)
		if gap > off: off = gap
		if gap > 0.002: wrong += 1
		# A band between the gutter's lip (2 cm) and well under the kerb's chamfer (11.7 cm): no
		# height of a full-height unit falls inside it, so anything here is a lowered top or a ramp.
		if pb[v].y > 0.025 and pb[v].y < 0.10: low_tags += 1
	_check(tagged > 0, "the marked street tagged %d vertices (the unmarked one tags none)" % tagged)
	var plain_tagged := 0
	for colour: Color in (a.colours as PackedColorArray):
		if not is_equal_approx(colour.a, 1.0): plain_tagged += 1
	_check(plain_tagged == 0, "with the interface off nothing is tagged: %d vertices off alpha 1" % plain_tagged)
	_check(wrong == 0, "every tagged alpha decodes to its own height: %d of %d wrong, worst %.2f mm out" % [wrong, tagged, off * 1000.0])
	_check(low_tags > 0, "the lowered kerb and its ramps are tagged at their own heights, not full kerb: %d vertices between the road and the kerb's top" % low_tags)

	# 3. The surface material reaches the mesh, and without one the street keeps the vertex-colour
	# material it has always had.
	var surface := StandardMaterial3D.new()
	var dressed := _street(ground, true, surface)
	var c := _arrays(dressed)
	_check(not c.is_empty() and c.override == surface, "a kerb surface material given to the street is the built mesh's override")
	_check(a.override != null and a.override is StandardMaterial3D and (a.override as StandardMaterial3D).vertex_color_use_as_albedo, "with no surface material the street keeps its own vertex-colour material")

	# 4. The corner tones: off by default, and when on, scoped to the curves. A street built
	# without its corner and nose is the same mesh with the curved work left off the end, so the
	# vertices past that street's count are exactly the ones `_piece` and its footway made. What
	# the marking checks above cannot say is whether a colour change stayed where it belongs, and
	# this is the question Codex asked: with the flag off nothing may move off the flat grey, and
	# with it on nothing before the curves may move at all.
	var straight := _street(ground, false, null, false, false)
	var toned := _street(ground, false, null, true, true)
	var s := _arrays(straight)
	var t := _arrays(toned)
	var ps: PackedVector3Array = s.points
	var cs: PackedColorArray = s.colours
	var ct: PackedColorArray = t.colours
	var ca: PackedColorArray = a.colours
	_check(pa.size() > ps.size() and ct.size() == pa.size(), "the straight-only street is the cornered one less its curves: %d vertices against %d" % [ps.size(), pa.size()])
	var before_moved := 0
	for v: int in mini(ps.size(), pa.size()):
		if not cs[v].is_equal_approx(ca[v]) or not cs[v].is_equal_approx(ct[v]): before_moved += 1
	_check(before_moved == 0, "nothing before the curves changes colour, flag on or off: %d of %d straight vertices moved" % [before_moved, ps.size()])
	# A colour comes back from the mesh as RGBA8 — the same quantising that costs the alpha its
	# last two millimetres — so it is compared to within one 8-bit step, never for equality.
	var grey := Color(Street.CONCRETE.r, Street.CONCRETE.g, Street.CONCRETE.b)
	var curved_count := 0
	var toned_count := 0
	var grey_off := 0
	var grey_on := 0
	for v: int in range(ps.size(), mini(ca.size(), ct.size())):
		curved_count += 1
		if _near(ca[v], grey): grey_off += 1
		if _near(ct[v], grey): grey_on += 1
		if not ca[v].is_equal_approx(ct[v]): toned_count += 1
	var grey_straight := 0
	for colour: Color in cs:
		if _near(colour, grey): grey_straight += 1
	# This is the mismatch stated as a measurement: the flat grey is a colour the curves carry
	# and the straight kerb never does, because every straight unit takes a batch tone instead.
	_check(grey_off > 0 and grey_straight == 0, "with the flag off the curves carry a flat grey the straight kerb never uses: %d of %d curved vertices on it, %d of %d straight" % [grey_off, curved_count, grey_straight, cs.size()])
	_check(grey_on == 0 and toned_count > 0, "with the flag on not one is left on it: %d curved vertices still grey, %d of %d changed colour" % [grey_on, toned_count, curved_count])
	# And the tone they take is their neighbours' delivery, not one of their own: the batch tone
	# at the corner's own distance along is carried by the curves and by the straight kerb there.
	var batch: Color = toned.call("_casting", 46.0)
	var batch_curved := 0
	var batch_straight := 0
	for v: int in range(ps.size(), ct.size()):
		if _near(ct[v], batch): batch_curved += 1
	for colour: Color in cs:
		if _near(colour, batch): batch_straight += 1
	_check(batch_curved > 0 and batch_straight > 0, "and the tone it takes is the one the straight kerb has at that distance, not a grey of its own: %d curved vertices and %d straight on the batch tone at 46 m" % [batch_curved, batch_straight])
	_done()


func _done() -> void:
	print("KERB_DONE passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)
