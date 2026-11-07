extends SceneTree
## Offline: builds a light Japanese maple from the free3d source mesh.
## Leaves are real geometry (about 480k triangles); whole leaves are grouped by
## welded position, about one in KEEP_EVERY is kept and scaled up around its
## own centre so the crown keeps its mass. Bark is kept as it is.
## Then the maple glen's per-tree pair is written beside it: NEAR is the lite
## tree with only safe LODs (collapsed leaf LODs dropped), FAR is thinned from
## the lite one the same way (a subset of its leaves, grown again) and is shown
## past ~40 m and used as every tree's shadow caster. The lite mesh is only rebuilt when it is missing
## or MAPLE_REBUILD_LITE=1, so other users of it (moss garden) stay untouched.
## Run: godot --headless --path . --script res://tools/make_maple_lite.gd
const SOURCE := "res://assets/shinrai/parks/midori_park/models/vegetation/vendor/free3d_japanese_maple_n030123/midori_japanese_maple_complete.res"
const OUT := "res://assets/shinrai/parks/midori_park/models/vegetation/vendor/free3d_japanese_maple_n030123/midori_japanese_maple_lite.res"
const FAR := "res://assets/shinrai/parks/midori_park/models/vegetation/vendor/free3d_japanese_maple_n030123/midori_japanese_maple_far.res"
const NEAR := "res://assets/shinrai/parks/midori_park/models/vegetation/vendor/free3d_japanese_maple_n030123/midori_japanese_maple_near.res"
const KEEP := 0.45
const GROW := 1.5
## A generated LOD is kept only if it holds this share of the full triangles.
const LOD_FLOOR := 0.2
## Far: about 3 in 10 of the lite leaves, grown so the crown keeps its cover.
const KEEP_FAR := 0.3
const GROW_FAR := 1.55

var parent := PackedInt32Array()

func find(i: int) -> int:
	var r := i
	while parent[r] != r: r = parent[r]
	while parent[i] != r:
		var n := parent[i]
		parent[i] = r
		i = n
	return r

func _initialize() -> void:
	var started := Time.get_ticks_msec()
	if not ResourceLoader.exists(OUT) or OS.get_environment("MAPLE_REBUILD_LITE") == "1":
		var source: ArrayMesh = load(SOURCE)
		_save(_thinned(source, KEEP, GROW).get_mesh(), OUT)
		print("MAPLE_LITE_DONE ms=", Time.get_ticks_msec() - started)
	var lite: ArrayMesh = load(OUT)
	_report("LITE", lite)
	# Per-tree instances pick LODs by screen error (threshold 4 px in the park),
	# so collapsed leaf LODs (a few hundred triangles) must never be reachable.
	_save(_safe_lods(_thinned(lite, 1.0, 1.0)), NEAR)
	_report("NEAR", load(NEAR))
	_save(_safe_lods(_thinned(lite, KEEP_FAR, GROW_FAR)), FAR)
	_report("FAR", load(FAR))
	print("MAPLE_FAR_DONE ms=", Time.get_ticks_msec() - started)
	quit()

## Leaves thinned (keep < 1), bark kept; distance LODs generated (Godot picks
## one by screen size, so the bark simplifies with distance).
func _thinned(source: ArrayMesh, keep: float, grow: float) -> ImporterMesh:
	var importer := ImporterMesh.new()
	for s: int in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(s)
		var material := source.surface_get_material(s)
		var leaf := s == 1 or (material != null and String(material.resource_name).to_lower().contains("leaf"))
		var out_arrays := _thin_leaves(arrays, keep, grow) if leaf and keep < 1.0 else arrays
		print("SURFACE ", s, " tris ", _tris(arrays), " -> ", _tris(out_arrays))
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, out_arrays, [], {}, material)
	importer.generate_lods(25.0, 60.0, [])
	return importer

## The importer's mesh with only the LODs that keep at least LOD_FLOOR of the
## surface's triangles.
func _safe_lods(importer: ImporterMesh) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for s: int in range(importer.get_surface_count()):
		var arrays := importer.get_surface_arrays(s)
		var full := _tris(arrays)
		var lods := {}
		var line := "  surface %d lod0 %d" % [s, full]
		for l: int in range(importer.get_surface_lod_count(s)):
			var indices := importer.get_surface_lod_indices(s, l)
			var tris := indices.size() / 3
			var kept := float(tris) >= float(full) * LOD_FLOOR
			if kept: lods[importer.get_surface_lod_size(s, l)] = indices
			line += " | lod%d %d tris @%.2f%s" % [l + 1, tris, importer.get_surface_lod_size(s, l), "" if kept else " (dropped)"]
		print(line)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods)
		mesh.surface_set_material(s, importer.get_surface_material(s))
	return mesh

func _save(mesh: ArrayMesh, path: String) -> void:
	var err := ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	print("SAVED ", path, " err=", err)

## Triangle counts per surface and per stored LOD.
func _report(label: String, mesh: ArrayMesh) -> void:
	var surfaces = mesh.get("_surfaces")
	if not (surfaces is Array): return
	for s: int in range(surfaces.size()):
		var d: Dictionary = surfaces[s]
		var wide: bool = int(d.get("vertex_count", 0)) > 65535
		var line := "%s surface %d lod0 %d tris" % [label, s, int(d.get("index_count", 0)) / 3]
		var lods: Array = d.get("lods", [])
		for l: int in range(0, lods.size(), 2):
			var data: PackedByteArray = lods[l + 1]
			line += " | lod%d %d tris @%.2f" % [l / 2 + 1, data.size() / (4 if wide else 2) / 3, float(lods[l])]
		print(line)

func _tris(arrays: Array) -> int:
	var idx = arrays[Mesh.ARRAY_INDEX]
	return (idx.size() if idx != null and idx.size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3

func _thin_leaves(arrays: Array, keep_share: float, grow: float) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		idx.resize(verts.size())
		for i: int in range(verts.size()): idx[i] = i
	# Weld by position so triangles of one leaf join up.
	parent.resize(verts.size())
	for i: int in range(verts.size()): parent[i] = i
	var welded := {}
	for i: int in range(verts.size()):
		var key := Vector3i(roundi(verts[i].x * 2000.0), roundi(verts[i].y * 2000.0), roundi(verts[i].z * 2000.0))
		if welded.has(key): parent[find(i)] = find(welded[key])
		else: welded[key] = i
	welded.clear()
	for t: int in range(0, idx.size(), 3):
		var a := find(idx[t])
		parent[find(idx[t + 1])] = a
		parent[find(idx[t + 2])] = a
	# Centre of each leaf.
	var sums := {}
	var counts := {}
	for i: int in range(verts.size()):
		var r := find(i)
		sums[r] = sums.get(r, Vector3.ZERO) + verts[i]
		counts[r] = int(counts.get(r, 0)) + 1
	print("LEAF_GROUPS ", sums.size())
	var keep := {}
	for r: int in sums:
		var h := absi(hash(r * 7919 + 13)) % 10000
		if float(h) / 10000.0 < keep_share: keep[r] = sums[r] / float(counts[r])
	var remap := {}
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var out_i := PackedInt32Array()
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	for t: int in range(0, idx.size(), 3):
		var r := find(idx[t])
		if not keep.has(r): continue
		var centre: Vector3 = keep[r]
		for k: int in range(3):
			var v := idx[t + k]
			if not remap.has(v):
				remap[v] = out_v.size()
				out_v.append(centre + (verts[v] - centre) * grow)
				out_n.append(normals[v] if not normals.is_empty() else Vector3.UP)
				if not uvs.is_empty(): out_uv.append(uvs[v])
			out_i.append(remap[v])
	var result := []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = out_v
	result[Mesh.ARRAY_NORMAL] = out_n
	if not out_uv.is_empty(): result[Mesh.ARRAY_TEX_UV] = out_uv
	result[Mesh.ARRAY_INDEX] = out_i
	return result
