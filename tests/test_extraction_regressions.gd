extends SceneTree

const Profile = preload("res://scripts/extraction_profile.gd")
const Navigation = preload("res://scripts/extraction_navigation.gd")
const Hud = preload("res://scripts/extraction_hud.gd")
var failures := 0
var save_path := "user://shinrai_route_regression_%d.json" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	print("PASS: " if condition else "FAIL: ", description)
	if not condition:
		failures += 1

func run() -> void:
	var profile := Profile.new()
	profile.save_path = save_path
	check(profile.begin_run(), "Deployment saves active run")
	check(not profile.begin_run(), "Active run cannot be overwritten by another deployment")
	var before := profile.data.duplicate(true)
	# A file cannot act as a directory: reliably fail without touching player data.
	profile.save_path = save_path + "/unwritable.json"
	var loot := [{"id": "circuit", "title": "Control circuit", "value": 85}]
	check(not profile.complete_run(true, loot, 150), "Settlement reports a write failure")
	check(profile.data == before, "Failed settlement rolls back credits, stash and active run")
	profile.save_path = save_path
	check(profile.complete_run(true, loot, 150), "Same profile can retry after a transient failure")
	check(profile.last_error.is_empty(), "Successful retry clears transient save error")
	check(profile.data.credits == 150 and profile.data.stash.circuit == 1, "Retry banks cargo and bonus once")
	check(not profile.complete_run(true, loot, 150), "Repeated settlement cannot pay twice")
	var reloaded := Profile.new()
	reloaded.save_path = save_path
	reloaded.load_profile()
	check(reloaded.data == profile.data, "Reload exactly preserves settled progression")
	check(reloaded.begin_run(), "Next deployment can begin after settlement")
	profile.load_profile()
	check(profile.recovered_interrupted_run and not profile.data.active_run, "Relaunch loses interrupted raid without losing banked stash")
	check(profile.data.credits == 150 and profile.data.stash.circuit == 1, "Interrupted raid preserves banked progression")
	profile.load_profile()
	check(not profile.recovered_interrupted_run, "Repeated load clears stale interruption notice")
	var malformed := Profile.defaults()
	malformed.stash = {"circuit": -5}
	var original := JSON.stringify(malformed)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	profile.load_profile()
	check(profile.saving_disabled and not profile.save_profile(), "Invalid stash blocks overwriting corrupt save")
	check(FileAccess.get_file_as_string(save_path) == original, "Corrupt original remains byte-for-byte intact")
	malformed = Profile.defaults()
	malformed.credits = 1.5
	check(not profile._valid_profile(malformed), "Fractional currency is rejected")
	malformed.version = {"unexpected": true}
	check(not profile._valid_profile(malformed), "Malformed version is rejected without conversion")
	var navigation := Navigation.new()
	navigation.grid.region = Rect2i(0, 0, 111, 91)
	navigation.grid.cell_size = Vector2.ONE * navigation.CELL
	navigation.grid.offset = navigation.ORIGIN
	navigation.grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.grid.update()
	navigation.grid.fill_solid_region(navigation.grid.region, true)
	for cell: Vector2i in [Vector2i(55, 45), Vector2i(56, 45), Vector2i(57, 45), Vector2i(58, 44)]:
		navigation.grid.set_point_solid(cell, false)
	navigation.ready = true
	var route := navigation.interaction_path(Vector3(0, 0.2, 0), Vector3(12, 0.2, 0), 4.0)
	check(not route.is_empty(), "Reachable interaction approach wins over disconnected nearby cell")
	if not route.is_empty():
		check(route[-1].distance_to(Vector3(12, 0.2, 0)) <= 4.0, "Guidance ends within usable interaction range")
	check(navigation.interaction_path(Vector3(0, 0.2, 0), Vector3(80, 0.2, 80), 4.0).is_empty(), "Unreachable interaction yields no route, not a distant snapped endpoint")
	var chart := Hud.FieldMap.new()
	chart.size = Vector2(780, 470)
	var origin := chart.project(Vector2.ZERO)
	check(is_equal_approx(origin.distance_to(chart.project(Vector2(100, 0))), origin.distance_to(chart.project(Vector2(0, 100)))), "Field map preserves equal scale on both axes")
	chart.free()
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(save_path + suffix)
	print("EXTRACTION_REGRESSION_RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
