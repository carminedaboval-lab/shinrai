extends SceneTree

# Prints the world AABB of candidate street prop models so they can be placed
# at true scale. godot --headless --path . --script res://tests/probe_prop_bounds.gd

const MODELS := [
	"res://assets/shinrai/parks/midori_park/models/furniture/ambient/entrance_bollards/sunpole_pa114sk_installed.glb",
	"res://assets/shinrai/parks/midori_park/models/furniture/ambient/bicycle_rack/midori_bicycle_rack.glb",
	"res://assets/shinrai/parks/midori_park/models/furniture/ambient/recycling_station/recycling_cyberpunk.glb",
	"res://assets/shinrai/parks/midori_park/models/furniture/ambient/takeaway_cup/midori_takeaway_cup.glb",
	"res://assets/park/kiyosumi_barrier/kiyosumi_meshy_post.glb",
	"res://assets/shinrai/parks/midori_park/models/furniture/vendor/neon_park_bench/neon_park_bench.glb",
	"res://assets/shinrai/parks/midori_park/models/furniture/ambient/information_board/midori_information_board.glb",
]

func _initialize() -> void:
	for path: String in MODELS:
		var scene := load(path) as PackedScene
		if scene == null:
			print("PROP_BOUNDS: missing ", path)
			continue
		var node := scene.instantiate()
		root.add_child(node)
		var bounds := AABB()
		var first := true
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			var box := mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		print("PROP_BOUNDS: %s min=%s size=%s" % [path.get_file(), bounds.position, bounds.size])
		node.queue_free()
	quit()
