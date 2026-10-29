extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")

# Two existing measured posts flank the current south-arrival route.
# Installation checks the existing visible paving, without changing its mesh.
@export var enabled := true
@export var automatic_install := true
@export var bollard_scene: PackedScene
@export var route_start_world := Vector2(0.0, 180.0)
@export var route_end_world := Vector2(-8.0, 160.0)
@export_range(0.0, 1.0) var route_station := 0.2
@export var half_spacing_m := 2.1
@export var mounting_allowance_m := 0.002

var installed := false
var report: Dictionary = {}

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	if automatic_install:
		call_deferred("install")

func install(park: Node3D = null) -> bool:
	if installed:
		return true
	if not enabled:
		return false
	if park == null:
		park = get_parent() as Node3D
	if park == null or bollard_scene == null:
		push_warning("ENTRANCE_BOLLARDS: missing park or measured source")
		return false
	var pad := park.find_child("MainSouthEntrance", true, false) as MeshInstance3D
	if pad == null or pad.mesh == null:
		push_warning("ENTRANCE_BOLLARDS: existing entrance paving missing")
		return false
	var delta := route_end_world - route_start_world
	if delta.length() < 1.0 or half_spacing_m < 1.0:
		push_warning("ENTRANCE_BOLLARDS: unsuitable route or spacing")
		return false
	var travel := delta.normalized()
	var normal := Vector2(-travel.y, travel.x)
	var centre := route_start_world.lerp(route_end_world, route_station)
	# Local X is the measured lock-pin axis; run it along the route.
	var yaw := atan2(-travel.y, travel.x)
	var basis := Basis(Vector3.UP, yaw)
	var placements: Array[Vector3] = []
	var heights: Array[float] = []
	for side: float in [-1.0, 1.0]:
		var point := centre + normal * half_spacing_m * side
		var position := Vector3(point.x, 0.0, point.y)
		var highest := -INF
		var lowest := INF
		# Check the complete ground-ring footprint against actual pad triangles.
		for offset: Vector3 in [Vector3.ZERO, Vector3(.067,0,0), Vector3(-.067,0,0), Vector3(0,0,.067), Vector3(0,0,-.067)]:
			var height := surface_height(pad, position + basis * offset)
			if not is_finite(height):
				push_warning("ENTRANCE_BOLLARDS: base lies outside existing paving")
				return false
			highest = maxf(highest, height)
			lowest = minf(lowest, height)
		if highest - lowest > .002:
			push_warning("ENTRANCE_BOLLARDS: paving is uneven beneath base")
			return false
		position.y = highest + mounting_allowance_m
		placements.append(position)
		heights.append(highest)
	var fixtures: Array[Node3D] = []
	for index: int in range(placements.size()):
		var fixture := bollard_scene.instantiate() as Node3D
		if fixture == null:
			for previous: Node3D in fixtures:
				previous.queue_free()
			push_warning("ENTRANCE_BOLLARDS: source root is not spatial")
			return false
		fixture.name = "WestMeasuredBollard" if index == 0 else "EastMeasuredBollard"
		add_child(fixture)
		# A world transform avoids inheriting the concept layout's X/Z scale2.
		fixture.global_transform = Transform3D(basis, placements[index])
		_add_collision(fixture)
		fixtures.append(fixture)
	installed = true
	report = {
		"fixture_count": fixtures.size(),
		"source": bollard_scene.resource_path,
		"route_start_world": route_start_world, "route_end_world": route_end_world,
		"west_position": placements[0], "east_position": placements[1],
		"pad_top_heights": heights, "yaw_degrees": rad_to_deg(yaw),
		"post_diameter_m": .1143, "post_height_m": .850,
		"hardware_clear_gap_m": half_spacing_m * 2.0 - .134,
		"world_scale": fixtures[0].global_basis.get_scale(),
		"mounting_allowance_m": mounting_allowance_m
	}
	print("ENTRANCE_BOLLARDS_INSTALLED: ", report)
	return true

func _add_collision(fixture: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "MeasuredPostCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	var post := CollisionShape3D.new()
	post.name = "Post"
	var cylinder := CylinderShape3D.new()
	cylinder.radius = .05715
	cylinder.height = .850
	post.shape = cylinder
	post.position.y = .425
	body.add_child(post)
	# Conservative low envelope for the pin, padlock and upright socket lid.
	# It does not turn the thin post into a full-height wide box.
	var hardware := CollisionShape3D.new()
	hardware.name = "BaseHardware"
	var box := BoxShape3D.new()
	box.size = Vector3(.183, .150, .134)
	hardware.shape = box
	hardware.position = Vector3(.000875, .075, 0.0)
	body.add_child(hardware)
	fixture.add_child(body)

static func surface_height(mesh: MeshInstance3D, point: Vector3) -> float:
	var height := -INF
	for surface: int in range(mesh.mesh.get_surface_count()):
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for index: int in range(0, count - 2, 3):
			var a := mesh.global_transform * vertices[indices[index] if not indices.is_empty() else index]
			var b := mesh.global_transform * vertices[indices[index + 1] if not indices.is_empty() else index + 1]
			var c := mesh.global_transform * vertices[indices[index + 2] if not indices.is_empty() else index + 2]
			var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(point.x, 5.0, point.z), Vector3.DOWN, a, b, c)
			if hit != null:
				height = maxf(height, hit.y)
	return height
