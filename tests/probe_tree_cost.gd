extends SceneTree
## What a street tree costs, measured off the meshes themselves:
##   godot --headless --path . --script res://tests/probe_tree_cost.gd
##
## There are 9,776 of them in Map 1 and they are drawn as two MultiMeshes, so the per-tree
## triangle count is multiplied by ten thousand and the whole map's tree budget turns on it.
## The old crown was an 8x5 sphere and the old trunk a 6-sided cylinder. Counted here rather
## than worked out on paper, because a number worked out on paper is a number nobody measured.
## Prints TREE_ lines and TREE_DONE.

const Blockout := preload("res://scripts/map1/map1_blockout.gd")


func _initialize() -> void:
	_run.call_deferred()


func _faces(mesh: Mesh) -> int:
	return mesh.get_faces().size() / 3


func _run() -> void:
	var crown: ArrayMesh = Blockout._tree_crown_mesh()
	var trunk: ArrayMesh = Blockout._tree_trunk_mesh()
	var each := _faces(crown) + _faces(trunk)
	# The old shapes, rebuilt here exactly as they were, so the comparison is measured too.
	var was_crown := SphereMesh.new()
	was_crown.radius = 2.5
	was_crown.height = 6.4
	was_crown.radial_segments = 8
	was_crown.rings = 5
	var was_trunk := CylinderMesh.new()
	was_trunk.top_radius = 0.16
	was_trunk.bottom_radius = 0.26
	was_trunk.height = 3.2
	was_trunk.radial_segments = 6
	was_trunk.rings = 1
	var before := _faces(was_crown) + _faces(was_trunk)
	var trees := 9776
	print("TREE_INFO before: crown %d + trunk %d = %d triangles a tree, %d across %d trees" % [
		_faces(was_crown), _faces(was_trunk), before, before * trees, trees])
	print("TREE_INFO after:  crown %d + trunk %d = %d triangles a tree, %d across %d trees" % [
		_faces(crown), _faces(trunk), each, each * trees, trees])
	print("TREE_INFO difference: %+d a tree, %+d in the map; still two MultiMeshes, so still two draw calls" % [
		each - before, (each - before) * trees])
	# Which way the faces point. A tree built inside out looks almost right in a street shot —
	# you see the far side of the trunk through the near side and at 1600x900 it reads as shading
	# — so nothing but a mesh check finds it. Codex found mine that way: all 30 trunk faces and
	# all 90 normals pointed inward. Both parts are checked here so the next one is caught at
	# home. A trunk and a crown are both roughly solids of revolution about their own axis, so
	# "outward" is the face normal agreeing with the direction from the axis to the face.
	var wrong := 0
	var checked := 0
	var worst := 1.0
	for named: Array in [["crown", crown], ["trunk", trunk]]:
		var faces: PackedVector3Array = (named[1] as ArrayMesh).get_faces()
		var out := 0
		var count := 0
		for n: int in range(0, faces.size(), 3):
			# Godot winds a front face CLOCKWISE, so the outward direction is (c-a) x (b-a),
			# not the right-hand (b-a) x (c-a). Written the other way round first, this called
			# the crown inward — a crown Codex had already measured as outward before anything
			# was touched, which is how the sign error was caught rather than the mesh.
			var edge_one := faces[n + 2] - faces[n]
			var edge_two := faces[n + 1] - faces[n]
			var normal := edge_one.cross(edge_two)
			if normal.length() < 1e-9: continue              # a pole triangle with no area
			count += 1
			var middle := (faces[n] + faces[n + 1] + faces[n + 2]) / 3.0
			var away := Vector3(middle.x, 0.0, middle.z)
			if away.length() < 1e-6: continue                 # straight above the axis
			var agrees := normal.normalized().dot(away.normalized())
			worst = minf(worst, agrees)
			if agrees < 0.0: out += 1
		checked += count
		wrong += out
		print("TREE_%s %s: %d faces with area, %d of them facing inward" % ["FAIL" if out > 0 else "PASS", named[0], count, out])
	print("TREE_INFO %d faces checked, worst agreement with outward %.4f" % [checked, worst])
	print("TREE_DONE %s" % ["all faces point outward" if wrong == 0 else "%d faces point the wrong way" % wrong])
	quit(1 if wrong > 0 else 0)
