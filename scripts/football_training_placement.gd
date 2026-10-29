extends RefCounted

# Staging only. No engine validation or live installation yet.
# Manager/loot owner supplies real, measured metric models; no placeholders.
const SITE_ID := "pitch_east_yellow_backpack"
const ROOT_NAME := "FootballEastGoalTrainingDressing"
const SURFACE_Y := 0.152
const APPROACH_X := -121.41
const PLAYER_RADIUS := .36
const RESOURCE_MAP := {
	"yellow_container":"res://assets/shinrai/gear/backpacks/regular.glb",
	"football_bag":"res://assets/shinrai/props/football_training/bag_lod1.glb",
	"cone_stack":"res://assets/shinrai/props/football_training/cones_lod1.glb",
	"boots_pair":"res://assets/shinrai/props/football_training/boots_v2_lod1.glb",
	"agility_ladders":"res://assets/shinrai/props/football_training/ladder_v2_lod1.glb",
}
const YELLOW_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D source_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D source_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D source_mr : filter_linear_mipmap_anisotropic;
uniform bool has_normal = false;
uniform bool has_mr = false;
uniform float source_normal_depth = 1.0;
void fragment(){
 vec3 original=texture(source_albedo,UV).rgb;
 // Classify the fabric from a small low-frequency neighbourhood, avoiding
 // JPEG/cloth-grain colour noise becoming fake chipped yellow paint.
 vec3 mask_color=vec3(0.0);
 for(int x=-1;x<=1;x++){for(int y=-1;y<=1;y++){
  mask_color+=texture(source_albedo,UV+vec2(float(x),float(y))*(4.0/2048.0)).rgb/9.0;
 }}
 float blue_fabric=(mask_color.b-mask_color.r)/max(mask_color.b,.001);
 float luminance=dot(original,vec3(.2126,.7152,.0722));
 // Recolour blue fabric, preserving neutral hardware and darkest seams.
 float mask=smoothstep(.28,.38,blue_fabric)*smoothstep(.006,.020,luminance);
 float shade=clamp(luminance/.065,.30,1.35);
 vec3 yellow=vec3(.80,.48,.015)*shade;
 ALBEDO=mix(original,yellow,mask);
 ROUGHNESS=has_mr ? texture(source_mr,UV).g : .9;
 METALLIC=has_mr ? texture(source_mr,UV).b : 0.0;
 if(has_normal){NORMAL_MAP=texture(source_normal,UV).rgb;NORMAL_MAP_DEPTH=source_normal_depth;}
}
"""

static func slots() -> Array[Dictionary]:
	# max_size_m applies AFTER rotation; these are acceptance envelopes,
	# never instructions to shrink an oversized asset.
	return [
		{"id":"yellow_container", "ground":Vector3(-120.70,SURFACE_Y,-86.00), "yaw":-PI/2.0, "max_size_m":Vector3(.45,.60,.45)},
		{"id":"football_bag", "ground":Vector3(-120.70,SURFACE_Y,-86.75), "yaw":0.0, "max_size_m":Vector3(.50,.65,.76)},
		{"id":"boots_pair", "ground":Vector3(-120.70,SURFACE_Y,-85.20), "yaw":-.12, "max_size_m":Vector3(.45,.28,.50)},
		{"id":"cone_stack", "ground":Vector3(-120.70,SURFACE_Y,-87.55), "yaw":.15, "max_size_m":Vector3(.40,.65,.40)},
		{"id":"agility_ladders", "ground":Vector3(-120.70,SURFACE_Y,-89.15), "yaw":0.0, "max_size_m":Vector3(.50,.15,2.40)},
	]

static func approach_points() -> Array[Vector3]:
	return [Vector3(-140,.15,-77.20),Vector3(APPROACH_X,.15,-78.60),Vector3(APPROACH_X,.15,-83.00),Vector3(APPROACH_X,.15,-86.00),Vector3(APPROACH_X,.15,-90.60)]

static func build_actual_cluster(parent: Node3D, model_loader: Callable = Callable()) -> Dictionary:
	# Production caller uses the default resource loader after guarded import.
	# Isolated test may inject an actual-GLB loader; never use placeholder art.
	if parent.get_node_or_null(ROOT_NAME) != null:
		return {"ok":false,"reason":"Already installed; factory did not allocate duplicates"}
	var models := {}
	for slot: Dictionary in slots():
		var path: String = RESOURCE_MAP[slot.id]
		var model = model_loader.call(path) if model_loader.is_valid() else _instantiate_resource(path)
		if not model is Node3D or not is_instance_valid(model):
			return _preflight_reject(models,"Missing accepted model resource: "+path)
		models[slot.id] = model
	return build_candidate(parent,models)

static func _instantiate_resource(path: String) -> Node3D:
	if not ResourceLoader.exists(path): return null
	var source := load(path) as PackedScene
	return source.instantiate() as Node3D if source != null else null

static func build_candidate(parent: Node3D, models: Dictionary) -> Dictionary:
	# This consuming API owns every supplied REQUIRED unparented Node3D,
	# even on failure. Parented/foreign nodes and extra dictionary keys remain
	# caller-owned. Rejected fresh instances must never be reused by caller.
	if parent.get_node_or_null(ROOT_NAME) != null:
		return _preflight_reject(models,"Already installed; do not register a duplicate site")
	var identities := {}
	for slot: Dictionary in slots():
		var supplied = models.get(slot.id)
		if not supplied is Node3D or not is_instance_valid(supplied) or supplied.get_parent() != null:
			return _preflight_reject(models,"Need unattached real model: "+str(slot.id))
		if identities.has(supplied.get_instance_id()):
			return _preflight_reject(models,"Aliased model instance: "+str(slot.id))
		identities[supplied.get_instance_id()] = true
	var root := Node3D.new()
	root.name = ROOT_NAME
	parent.add_child(root)
	# Cancel the park layout's doubled X/Z without scaling supplied props.
	root.transform = parent.global_transform.affine_inverse()
	# Attach the entire accepted set before any mesh/material validation,
	# so a later rejection frees every supplied model, not a partial prefix.
	for slot: Dictionary in slots(): root.add_child(models[slot.id])
	var measured := {}
	for slot: Dictionary in slots():
		var model: Node3D = models[slot.id]
		model.name = slot.id
		model.rotation.y = slot.yaw
		var boxes: Array[AABB] = []
		_collect_mesh_boxes(model,boxes)
		if boxes.is_empty():
			return _reject(root,"Model has no measurable mesh: "+str(slot.id))
		var bounds := boxes[0]
		for index: int in range(1,boxes.size()): bounds = bounds.merge(boxes[index])
		var cap: Vector3 = slot.max_size_m
		if bounds.size.x>cap.x+.0001 or bounds.size.y>cap.y+.0001 or bounds.size.z>cap.z+.0001:
			return _reject(root,"Oversized real model; re-layout required: "+str(slot.id))
		# Actual rotated bounds determine seating, even if the supplier pivot
		# differs. No invented floor collision and no per-frame positioning.
		var bottom_center := Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
		var offset: Vector3 = slot.ground-bottom_center
		model.global_position += offset
		measured[slot.id] = AABB(bounds.position+offset,bounds.size)
	root.set_meta("football_loot_site_id",SITE_ID)
	root.set_meta("placement_measurements",measured)
	var clearance := _layout_clearance(measured)
	if not clearance.ok: return _reject(root,str(clearance.reason))
	if not _yellow_instance_finish(models["yellow_container"]):
		return _reject(root,"Yellow finish needs original regular model's textured StandardMaterial3D")
	# Two conservative, inset boxes for bulky bags; low flexible equipment
	# remains nonblocking dressing. No imported/trimesh or floor collision.
	for key: String in ["yellow_container","football_bag"]:
		_bag_collision(root,key,measured[key])
	# Loot owner alone calls raid.register_loot_container_pickup(SITE_ID,
	# yellow_model) -> bool, during BOOT/HQ. This helper never registers loot.
	return {"ok":true,"root":root,"site_id":SITE_ID,"yellow_model":models["yellow_container"],"ground_anchor":Vector3(-120.70,SURFACE_Y,-86.00),"bounds":measured,"approach":approach_points(),"clearance_report":clearance}

static func create_yellow_container_model() -> Node3D:
	# Reuse the delivered 45cm pack. It becomes a container only through the
	# loot owner's registration: never assign backpack_id or fixed_loot.
	return _instantiate_resource(RESOURCE_MAP.yellow_container)

static func _bag_collision(root: Node3D, key: String, bounds: AABB) -> void:
	var body := StaticBody3D.new()
	body.name = key+"_SimpleBody"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var size := bounds.size*.85
	body.position = Vector3(bounds.get_center().x,bounds.position.y+size.y*.5,bounds.get_center().z)
	var shape := CollisionShape3D.new()
	shape.name = "InsetBagBox"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

static func _layout_clearance(measured: Dictionary) -> Dictionary:
	# Analytic AABB guard only; real movement/floor/interaction still required.
	var minimum_approach := INF
	var minimum_fence := INF
	var keys := measured.keys()
	for key: String in keys:
		var bounds: AABB = measured[key]
		var maximum := bounds.end
		if bounds.position.x<=-123.0 or maximum.x>=-120.165 or bounds.position.z<=-96.55 or maximum.z>=-75.45:
			return {"ok":false,"reason":"Prop exceeds behind-goal deck/fence envelope: "+key}
		minimum_approach = minf(minimum_approach,bounds.position.x-(APPROACH_X+PLAYER_RADIUS))
		minimum_fence = minf(minimum_fence,-120.165-maximum.x)
	for first: int in range(keys.size()):
		var a: AABB = measured[keys[first]]
		for second: int in range(first+1,keys.size()):
			var b: AABB = measured[keys[second]]
			if Rect2(Vector2(a.position.x,a.position.z),Vector2(a.size.x,a.size.z)).intersects(Rect2(Vector2(b.position.x,b.position.z),Vector2(b.size.x,b.size.z))):
				return {"ok":false,"reason":"Prop footprints overlap"}
	var anchor_margin := APPROACH_X-PLAYER_RADIUS-(-121.885)
	if minimum_approach<.08 or minimum_fence<.12 or anchor_margin<.08:
		return {"ok":false,"reason":"Narrow-strip analytic safety margin failed"}
	return {"ok":true,"capsule_to_prop_m":minimum_approach,"prop_to_fence_m":minimum_fence,"capsule_to_rear_anchor_m":anchor_margin,"runtime_verified":false}

static func _yellow_instance_finish(model: Node3D) -> bool:
	var meshes: Array[Node] = model.find_children("*","MeshInstance3D",true,false)
	if model is MeshInstance3D: meshes.push_front(model)
	if meshes.is_empty(): return false
	var shader := Shader.new()
	shader.code = YELLOW_SHADER
	for node: Node in meshes:
		var mesh := node as MeshInstance3D
		for index: int in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(index) as StandardMaterial3D
			if original == null or original.albedo_texture == null: return false
			var finish := ShaderMaterial.new()
			finish.resource_name = "YellowLootFabric_InstanceOnly"
			finish.shader = shader
			finish.set_shader_parameter("source_albedo",original.albedo_texture)
			finish.set_shader_parameter("source_normal",original.normal_texture)
			finish.set_shader_parameter("source_mr",original.roughness_texture)
			finish.set_shader_parameter("has_normal",original.normal_enabled and original.normal_texture != null)
			finish.set_shader_parameter("has_mr",original.roughness_texture != null)
			finish.set_shader_parameter("source_normal_depth",original.normal_scale)
			# Override the instance surface; the imported mesh/material stays shared
			# and unchanged for the wearable regular packs elsewhere in the park.
			mesh.set_surface_override_material(index,finish)
	return true

static func _collect_mesh_boxes(node: Node, boxes: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		boxes.append(node.global_transform*node.mesh.get_aabb())
	for child: Node in node.get_children(): _collect_mesh_boxes(child,boxes)

static func _reject(root: Node3D, reason: String) -> Dictionary:
	# Candidate models are supplied for this build; an invalid partial cluster
	# never registers loot. Caller must supply fresh instances after rejection.
	root.get_parent().remove_child(root)
	root.queue_free()
	return {"ok":false,"reason":reason}

static func _preflight_reject(models: Dictionary, reason: String) -> Dictionary:
	var disposed := {}
	for slot: Dictionary in slots():
		var model = models.get(slot.id)
		if not model is Node3D or not is_instance_valid(model): continue
		if model.get_parent() != null or disposed.has(model.get_instance_id()): continue
		disposed[model.get_instance_id()] = true
		model.queue_free()
	return {"ok":false,"reason":reason}
