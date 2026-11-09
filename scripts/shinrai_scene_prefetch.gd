extends RefCounted
## Boot speed hint: the park scene's threaded load runs on ONE loader thread
## (sub-threads hung, see shinrai_bootstrap.gd). About a fifth of it is asset
## files (meshes, imported scenes, textures) whose dependencies hold no script.
## Threads of our own load those at the same time, so the scene's loader finds
## them cached. Scripts are never loaded here (the GDScript cache is not safe to
## fill from several threads). Same resources, same files: only who reads them first
## changes. Measured in the boot (2026-11-08, two runs each): the scene load took
## 6.8-7.3 s without this and 5.7-5.8 s with it. The rest is compiling ~190 scripts.
##
## run(world, out, stop) is a Thread body: it walks the scene's dependencies
## (ResourceLoader.get_dependencies, and preload/extends paths in script text),
## then loads every script-free asset on itself and HELPERS more threads, keeping
## them in `out` (so they stay cached until the boot drops `out`). stop[0] = true
## makes every thread finish after its current file.

const HELPERS := 3

## go[0]: the walk (file reads only) starts at once; loading waits for go[0], set
## when the scene request starts (after the renderer's pipeline features are fixed:
## no asset may create a material before that).
static func run(world: String, out: Array, stop: Array, go: Array) -> void:
	var deps := {}
	var order: Array[String] = []
	var pattern := RegEx.create_from_string("(?m)(?:preload\\(\\s*|^extends\\s+)\"(res://[^\"]+)\"")
	_collect(world, deps, order, pattern, stop)
	var scripted := {}
	var leaves: Array = []
	for path: String in order:
		if stop[0]: return
		if path != world and not _scripted(path, deps, scripted):
			leaves.append([_size(path), path])
	while not go[0]:
		if stop[0]: return
		OS.delay_msec(5)
	# Largest first, dealt out so each thread gets a similar share.
	leaves.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	var lists: Array = []
	var loads: Array = []
	for i: int in HELPERS + 1:
		lists.append([])
		loads.append(0)
	for leaf: Array in leaves:
		var best := 0
		for i: int in lists.size():
			if int(loads[i]) < int(loads[best]): best = i
		lists[best].append(leaf[1])
		loads[best] = int(loads[best]) + maxi(1, int(leaf[0]))
	var threads: Array[Thread] = []
	var kept: Array = []
	for i: int in range(1, lists.size()):
		var bucket: Array = []
		kept.append(bucket)
		var thread := Thread.new()
		thread.start(_load_all.bind(lists[i], bucket, stop))
		threads.append(thread)
	var own: Array = []
	_load_all(lists[0], own, stop)
	for thread: Thread in threads: thread.wait_to_finish()
	out.append_array(own)
	for bucket: Array in kept: out.append_array(bucket)

static func _load_all(paths: Array, out: Array, stop: Array) -> void:
	for path: String in paths:
		if stop[0]: return
		if ResourceLoader.has_cached(path): continue
		var resource := ResourceLoader.load(path)
		if resource != null: out.append(resource)

static func _collect(path: String, deps: Dictionary, order: Array[String], pattern: RegEx, stop: Array) -> void:
	if deps.has(path) or stop[0]: return
	var found: Array[String] = []
	deps[path] = found
	if path.get_extension() == "gd":
		# Exported builds may hold no script text: then nothing is found and the
		# scene's own loader reads everything, as before.
		var text := FileAccess.get_file_as_string(path)
		for m: RegExMatch in pattern.search_all(text): found.append(m.get_string(1))
	elif ResourceLoader.exists(path):
		for dep: String in ResourceLoader.get_dependencies(path):
			var clean := dep.get_slice("::", 2) if dep.contains("::") else dep
			if clean.begins_with("uid://"): clean = ResourceUID.get_id_path(ResourceUID.text_to_id(clean))
			if not clean.is_empty(): found.append(clean)
	for dep: String in found: _collect(dep, deps, order, pattern, stop)
	order.append(path)

static func _scripted(path: String, deps: Dictionary, memo: Dictionary) -> bool:
	if memo.has(path): return memo[path]
	memo[path] = true # a cycle counts as scripted (never prefetched)
	var result := path.get_extension() in ["gd", "cs", "gdc"] or not ResourceLoader.exists(path)
	if not result:
		for dep: String in deps.get(path, []):
			if _scripted(dep, deps, memo):
				result = true
				break
	memo[path] = result
	return result

static func _size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file != null else 0
