extends RefCounted
## Shared main-thread budget. Geometry, physics queries and RNG order stay native.
const FRAME_BUDGET_USEC := 50000
static func wait_structure(park: Node) -> void:
	while is_instance_valid(park) and park.get_meta("shinrai_structure_pending",false):
		await park.get_tree().process_frame
static func stage(park: Node, text: String) -> void:
	if not is_instance_valid(park) or not park.is_inside_tree(): return
	var ui:=park.get_tree().get_first_node_in_group("shinrai_loading_ui")
	if ui!=null: ui.set_stage(text)
static func checkpoint(park: Node) -> void:
	if not is_instance_valid(park) or not park.get_meta("shinrai_incremental_loading",false): return
	while is_instance_valid(park) and park.is_inside_tree():
		var frame:=Engine.get_process_frames()
		if int(park.get_meta("shinrai_budget_frame",-1))!=frame:
			park.set_meta("shinrai_budget_frame",frame)
			park.set_meta("shinrai_budget_start",Time.get_ticks_usec())
		if Time.get_ticks_usec()-int(park.get_meta("shinrai_budget_start"))<FRAME_BUDGET_USEC: return
		await park.get_tree().process_frame
