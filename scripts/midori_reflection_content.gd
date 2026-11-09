extends Node
## Stable reflection budget: preserve sky, trees, bridges and props while
## omitting small ground planting at every tier. Main-view planting is intact.
const DETAIL_BIT := 1 << 18
const DistanceDetail = preload("res://scripts/midori_distance_detail.gd")
const LIGHT_MASKS := ["light_cull_mask", "shadow_caster_mask"]
var lake: Node
var enabled := true
var original_mask := 0
var geometries: Array = []
var lights: Array = []

func plant_kind(geometry: GeometryInstance3D) -> String:
	if geometry.get_parent().name == "MidoriDistanceDetail":
		for kind: String in ["grass","flowers","other_planting"]:
			if str(geometry.name).begins_with(kind+"_Cell_"): return kind
	return DistanceDetail.plant_kind(geometry)

func install(park: Node3D) -> Dictionary:
	lake = park.get_node_or_null("MidoriLakeLife")
	if lake == null or lake._camera == null: return {"error":"Missing installed reflection camera"}
	var main_camera := park.get_viewport().get_camera_3d()
	if main_camera == null or not main_camera.cull_mask & DETAIL_BIT:
		return {"error":"Main camera does not include reserved detail layer"}
	# One walk of the park serves the check and the pass (nothing is added between).
	var all_geometry := park.find_children("*","GeometryInstance3D",true,false)
	for geometry in all_geometry:
		if geometry.layers & DETAIL_BIT: return {"error":"Reserved detail layer already used","path":str(geometry.get_path()),"layers":geometry.layers}
	var shadow_budget:=park.get_node_or_null("MidoriNearPlantShadows")
	if shadow_budget!=null and shadow_budget.has_method("before_source_change"):shadow_budget.before_source_change()
	original_mask = lake._camera.cull_mask
	# Planting the world-complete step added (biomes) keeps layer 1 and stays in
	# the lake reflection, as when this pass ran before it (extraction_run.gd).
	# Visibility is judged as it was before that step (its thinning hides some).
	var before: Dictionary = park.get_meta(&"shinrai_render_budget_before", {})
	for geometry in all_geometry:
		if not is_instance_valid(geometry): continue
		var visible: bool = geometry.is_visible_in_tree()
		if not before.is_empty():
			if not before.has(geometry.get_instance_id()): continue
			visible = bool(before[geometry.get_instance_id()][0])
		if not visible or geometry.layers != 1: continue
		if plant_kind(geometry) not in ["grass","flowers","other_planting"]: continue
		geometries.append([geometry,geometry.layers])
		geometry.layers = DETAIL_BIT
	# Preserve illumination and shadow membership of geometry moved from layer 1.
	# The two mask properties are read directly (the full property list of every
	# light was walked for them), in the order that list gives them.
	for light in park.find_children("*","Light3D",true,false):
		for property_name: String in LIGHT_MASKS:
			if not property_name in light: continue
			var property := {"name": property_name}
			var old: int = light.get(property.name)
			if old & 1 and not old & DETAIL_BIT:
				lights.append([light,property.name,old])
				light.set(property.name,old | DETAIL_BIT)
	process_priority = 100
	park.add_child(self)
	_process(0)
	if is_instance_valid(shadow_budget) and shadow_budget.has_method("after_source_change"):shadow_budget.after_source_change()
	return {"geometry_nodes":geometries.size(),"light_masks_preserved":lights.size(),"near_reflection_content":"sky, trees, bridges and props retained; small ground planting omitted","distant_reflection_content":"same object membership at every tier; native distance/frustum/mesh-LOD culling","main_view_materials_meshes_resolution":"unchanged","qa_only":false}

func _process(_delta: float) -> void:
	if not is_instance_valid(lake): return
	var target_mask := (original_mask & ~DETAIL_BIT) if enabled else original_mask
	if lake._camera.cull_mask != target_mask: lake._camera.cull_mask = target_mask

func restore() -> void:
	set_process(false)
	var shadow_budget: Node=get_parent().get_node_or_null("MidoriNearPlantShadows") if get_parent()!=null else null
	var shadow_guard: bool=is_instance_valid(shadow_budget) and shadow_budget.is_inside_tree() and shadow_budget.has_method("before_source_change")
	if shadow_guard:shadow_budget.before_source_change()
	if is_instance_valid(lake): lake._camera.cull_mask = original_mask
	for row in geometries:
		if is_instance_valid(row[0]): row[0].layers = row[1]
	for row in lights:
		if is_instance_valid(row[0]): row[0].set(row[1],row[2])
	if shadow_guard and is_instance_valid(shadow_budget):shadow_budget.after_source_change()

func _exit_tree() -> void:
	restore()
