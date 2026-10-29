extends SceneTree

const Profile = preload("res://scripts/extraction_profile.gd")
const Run = preload("res://scripts/extraction_run.gd")
var checks := 0
var failures: Array[String] = []

class FakeHud extends CanvasLayer:
	var inventory_calls := 0
	var hq_calls := 0
	var pause_calls := 0
	func show_inventory(_run: Node) -> void:
		inventory_calls += 1
	func show_hq(_run: Node) -> void:
		hq_calls += 1
	func show_pause(_run: Node, _with_map: bool) -> void:
		pause_calls += 1
	func show_raid() -> void:
		pass

func _initialize() -> void:
	_test_profile_sales()
	_test_profile_invalid_sales()
	_test_profile_failure_rollback()
	_test_profile_load_normalization()
	_test_extraction_contract()
	_test_controller_inventory()
	print("INVENTORY_TEST_RESULT: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures:
		print("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _profile(name_suffix: String):
	var profile = Profile.new()
	profile.save_path = "user://inventory_qa_%s.json" % name_suffix
	profile.data = Profile.defaults()
	return profile

func _test_profile_sales() -> void:
	var profile = _profile("sales")
	profile.data.stash = {"circuit": 3, "cell": 2}
	_check(profile.sell_item("circuit", 1, Run.PRICES) == 85, "single sale returns actual proceeds")
	_check(profile.data.credits == 85 and profile.data.stash.circuit == 2, "single sale decrements one item")
	_check(profile.sell_item("circuit", 2, Run.PRICES) == 170, "all-selected sale returns quantity times price")
	_check(not profile.data.stash.has("circuit") and profile.data.stash.cell == 2, "all-selected removes only selected type")
	var reloaded = _profile("sales")
	reloaded.load_profile()
	_check(reloaded.last_error.is_empty() and reloaded.data == profile.data, "individual sales survive save and reload")
	_check(profile.sell_stash(Run.PRICES) == 120 and profile.data.credits == 375 and profile.data.stash.is_empty(), "sell-all values remaining stash once")
	profile.data.stash = {"archive": 1, "future_item": 4}
	_check(profile.sell_stash(Run.PRICES) == 220, "sell-all values recognized items only")
	_check(profile.data.stash.get("future_item", 0) == 4, "sell-all preserves unknown banked content")

func _test_profile_invalid_sales() -> void:
	var profile = _profile("invalid")
	profile.data.stash = {"circuit": 2, "future_item": 3}
	var baseline: Dictionary = profile.data.duplicate(true)
	for request: Array in [["circuit", 0], ["circuit", -2], ["circuit", 3], ["cell", 1], ["future_item", 1], ["", 1]]:
		_check(profile.sell_item(request[0], request[1], Run.PRICES) == 0, "reject invalid sale %s" % str(request))
		_check(profile.data == baseline, "invalid sale does not mutate profile %s" % str(request))
	profile.data.active_run = true
	baseline = profile.data.duplicate(true)
	_check(profile.sell_item("circuit", 1, Run.PRICES) == 0 and profile.data == baseline, "active run prevents individual sale")
	_check(profile.sell_stash(Run.PRICES) == 0 and profile.data == baseline, "active run prevents sell-all")
	profile.data.credits = 1000
	baseline = profile.data.duplicate(true)
	_check(not profile.buy_medkit() and profile.data == baseline, "active run prevents medical purchase")
	_check(not profile.buy_upgrade() and profile.data == baseline, "active run prevents cargo upgrade purchase")
	profile.data.active_run = false
	_check(profile.sell_item("circuit", 1, {"circuit": -85}) == 0 and profile.data.stash.circuit == 2, "negative price cannot mint credit or consume cargo")
	baseline = profile.data.duplicate(true)
	_check(profile.sell_stash({"circuit": -85}) == 0 and profile.data == baseline, "sell-all ignores nonpositive prices without changing economy")

func _test_profile_failure_rollback() -> void:
	var profile = _profile("write_failure")
	profile.save_path = "user://missing_inventory_qa_parent/save.json"
	profile.data.stash = {"archive": 2}
	profile.data.credits = 120
	var baseline: Dictionary = profile.data.duplicate(true)
	_check(profile.sell_item("archive", 1, Run.PRICES) == 0, "failed write reports no completed sale")
	_check(profile.data == baseline and not profile.last_error.is_empty(), "failed write rolls back credits and stash")
	_check(profile.sell_stash(Run.PRICES) == 0 and profile.data == baseline, "save error blocks subsequent sell-all")
	_check(not profile.buy_medkit() and profile.data == baseline, "save error blocks medical purchase")
	_check(not profile.buy_upgrade() and profile.data == baseline, "save error blocks cargo upgrade purchase")
	var bulk = _profile("bulk_failure")
	bulk.save_path = profile.save_path
	bulk.data.stash = {"archive": 2, "cell": 1}
	baseline = bulk.data.duplicate(true)
	_check(bulk.sell_stash(Run.PRICES) == 0 and bulk.data == baseline, "failed bulk sale write rolls back all stash and credits")
	var extracting = _profile("extract_failure")
	extracting.save_path = profile.save_path
	extracting.data.active_run = true
	baseline = extracting.data.duplicate(true)
	_check(not extracting.complete_run(true, [Run.ITEMS[0]], 150), "failed extraction write reports failure")
	_check(extracting.data == baseline, "failed extraction write rolls back active state and banked gains")

func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func _test_profile_load_normalization() -> void:
	var profile = _profile("normalize")
	var raw := Profile.defaults()
	raw.stash = {"circuit": 3.8, "cell": -5, "archive": "20", "optics": 0, "future_item": 2, "huge": 1000001}
	raw.credits = -35
	raw.pack_level = 50
	_write_json(profile.save_path, raw)
	profile.load_profile()
	_check(profile.data.stash == {"circuit": 3, "future_item": 2, "huge": 1000000}, "load normalizes numeric stash and preserves unknown ids")
	_check(profile.data.credits == 0 and profile.data.pack_level == 2, "load clamps negative economy and excessive upgrade")
	var corrupt = _profile("corrupt")
	var file := FileAccess.open(corrupt.save_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	corrupt.load_profile()
	var original := FileAccess.get_file_as_string(corrupt.save_path)
	_check(not corrupt.last_error.is_empty() and not corrupt.save_profile(), "unreadable original blocks saving")
	_check(FileAccess.get_file_as_string(corrupt.save_path) == original, "unreadable original remains untouched")

func _test_extraction_contract() -> void:
	var profile = _profile("extract")
	profile.data.stash = {"optics": 2}
	profile.data.prepared_medkit = true
	_check(profile.begin_run() and profile.data.active_run and profile.data.runs == 1, "begin run persists active marker")
	_check(profile.data.stash == {"optics": 2} and not profile.data.prepared_medkit, "deployment leaves banked stash and consumes prepared medkit")
	var carried: Array = [Run.ITEMS[0].duplicate(), Run.ITEMS[0].duplicate(), Run.ITEMS[3].duplicate()]
	_check(profile.data.stash == {"optics": 2}, "carried cargo is not banked before extraction")
	_check(profile.complete_run(true, carried, 150), "successful extraction persists cargo")
	_check(profile.data.stash == {"optics": 2, "circuit": 2, "archive": 1} and profile.data.credits == 150 and profile.data.extracts == 1, "extraction banks exact item quantities and bonus")
	var banked: Dictionary = profile.data.duplicate(true)
	_check(not profile.complete_run(true, carried, 150) and profile.data == banked, "extraction completion is idempotent")
	var reloaded = _profile("extract")
	reloaded.load_profile()
	_check(reloaded.data == banked, "extraction bank survives reload")
	_check(profile.begin_run() and profile.complete_run(false, carried, 999), "death completes active run")
	_check(profile.data.stash == banked.stash and profile.data.credits == banked.credits and profile.data.extracts == 1, "death loses carried cargo and bonus while preserving stash")
	var interrupted = _profile("interrupt")
	_check(interrupted.begin_run(), "interrupted run setup persists marker")
	var recovered = _profile("interrupt")
	recovered.load_profile()
	_check(recovered.recovered_interrupted_run and not recovered.data.active_run and recovered.data.stash.is_empty(), "interrupted run recovery grants no carried cargo")

func _test_controller_inventory() -> void:
	# This controller stays outside the tree: no park load, AI, navigation or bots.
	var run = Run.new()
	var hud := FakeHud.new()
	run.hud = hud
	run.profile = _profile("controller")
	run.profile.data.stash = {"circuit": 3}
	run.phase = Run.Phase.HQ
	run.map_open = true
	run.open_inventory()
	_check(run.inventory_open and not run.map_open and hud.inventory_calls == 1, "HQ opens dedicated inventory and closes map")
	run._on_action("sell_item:circuit:1")
	_check(run.profile.data.stash.circuit == 2 and run.profile.data.credits == 85, "HQ inventory action sells exact selected quantity")
	var baseline: Dictionary = run.profile.data.duplicate(true)
	for action: String in ["sell_item:circuit:-1", "sell_item:circuit:20", "sell_item:circuit:bad", "sell_item:circuit:1:extra", "sell_item:missing:1"]:
		run._on_action(action)
		_check(run.profile.data == baseline, "controller rejects malformed or invalid sale " + action)
	run.close_inventory()
	_check(not run.inventory_open and hud.hq_calls == 1, "HQ close returns to operations")
	run._on_action("sell_item:circuit:1")
	_check(run.profile.data == baseline, "selected sale requires inventory open")
	for invalid_phase: int in [Run.Phase.BOOT, Run.Phase.RESULT]:
		run.phase = invalid_phase
		run.open_inventory()
		_check(not run.inventory_open, "inventory rejects invalid phase %d" % invalid_phase)
	run.bag.assign([Run.ITEMS[3].duplicate(), Run.ITEMS[0].duplicate(), Run.ITEMS[1].duplicate(), Run.ITEMS[0].duplicate()])
	var original_bag: Array = run.bag.duplicate(true)
	run.phase = Run.Phase.HQ
	run.inventory_open = true
	_check(not run.discard_cargo(1) and run.bag == original_bag, "HQ cannot discard raid cargo")
	run._on_action("sort_cargo")
	_check(run.bag == original_bag, "HQ cannot sort raid cargo")
	run.phase = Run.Phase.PAUSED
	run.inventory_open = false
	_check(not run.discard_cargo(1) and run.bag == original_bag, "cargo discard requires open inventory")
	run.inventory_open = true
	run.pending_cache_id = "bench1"
	_check(not run.discard_cargo(1) and run.bag == original_bag, "pending loot decision prevents cargo discard")
	run._on_action("sort_cargo")
	_check(run.bag == original_bag, "pending loot decision prevents stale indexed cargo sort")
	run.inventory_open = false
	run.open_inventory()
	_check(not run.inventory_open, "pending loot decision prevents opening inventory")
	run.pending_cache_id = ""
	run.open_inventory()
	_check(run.inventory_open and not run.map_open, "paused raid opens inventory")
	_check(not run.discard_cargo(-1) and not run.discard_cargo(run.bag.size()) and run.bag == original_bag, "negative and out-of-range discard cannot remove cargo")
	run._on_action("sell_item:circuit:1")
	_check(run.profile.data == baseline, "raid inventory cannot sell banked stash")
	run._on_action("sort_cargo")
	_check(run.bag.size() == 4 and run.bag[0].id == "circuit" and run.bag[1].id == "circuit" and run.bag[2].id == "archive" and run.bag[3].id == "optics", "cargo sort uses item titles without losing duplicate quantities")
	var total_value := 0
	for item: Dictionary in run.bag:
		total_value += item.value
	_check(total_value == 530, "cargo sort preserves all item values")
	_check(run.discard_cargo(1) and run.bag.size() == 3 and run.bag[0].id == "circuit", "indexed discard removes exactly one duplicate")
	run._on_action("discard_item:bad")
	_check(run.bag.size() == 3, "malformed indexed discard does not mutate cargo")
	run.free()
	hud.free()
