extends Node3D

# Reuse isolated shells from the supplied blossom cluster. Tree geometry,
# imported meshes/materials, physics and the existing emitter nodes are retained.
const PETALS := [
	preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/petals/sakura_petal_a.glb"),
	preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/petals/sakura_petal_b.glb"),
]
const GROUND_TREES := ["DenseSakura_12","DenseSakura_20","DenseSakura_22"]
const SOURCE_FIELDS := ["transform","top_level","local_coords","amount","lifetime","preprocess","visibility_aabb","visibility_range_end","draw_pass_1","process_material","material_override","cast_shadow"]
@export var enabled := true
var installed := false
var report: Dictionary = {}
var _states: Array[Dictionary] = []
var _ground: Node3D
var _park: Node3D
var _meshes: Array[Mesh] = []
var _ground_material: StandardMaterial3D
var _drift_materials: Dictionary = {}
var _shader: Shader
var _ground_anchors: Array[Vector3] = []

func _ready() -> void:
	call_deferred("install")

func install() -> void:
	if installed or not enabled:
		return
	_park = get_parent().get_parent() as Node3D
	if _park == null:
		return
	# Allow the existing Sakura autoload's deferred replacements to finish.
	for frame: int in range(3):
		await get_tree().process_frame
	await get_tree().physics_frame
	top_level = true
	global_transform = Transform3D.IDENTITY
	for scene: PackedScene in PETALS:
		var source := scene.instantiate() as Node3D
		var visual := source.find_child("*",true,false) as MeshInstance3D
		if visual == null:
			for child: Node in source.find_children("*","MeshInstance3D",true,false):
				visual = child as MeshInstance3D
				break
		if visual == null or visual.mesh == null:
			source.free()
			push_warning("MIDORI_PETALS: supplied shell mesh missing")
			return
		_meshes.append(visual.mesh)
		if _ground_material == null:
			_ground_material = visual.get_active_material(0).duplicate() as StandardMaterial3D
		source.free()
	_ground_material.metallic = 0
	_ground_material.roughness = .86
	_ground_material.normal_enabled = false
	_ground_material.emission_enabled = false
	_ground_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ground_material.albedo_color = Color(.84,.80,.82)
	_ground_material.vertex_color_use_as_albedo = true
	_shader = Shader.new()
	_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform float floor_y = 0.0;
varying float petal_world_y;
void vertex() {
	float phase = TIME * 2.1 + INSTANCE_CUSTOM.x * 3.7;
	float ax = sin(phase) * 0.36;
	float az = cos(phase * 0.83) * 0.23;
	mat3 rx = mat3(vec3(1,0,0),vec3(0,cos(ax),sin(ax)),vec3(0,-sin(ax),cos(ax)));
	mat3 rz = mat3(vec3(cos(az),sin(az),0),vec3(-sin(az),cos(az),0),vec3(0,0,1));
	VERTEX = rz * rx * VERTEX;
	NORMAL = normalize(rz * rx * NORMAL);
	petal_world_y = (MODEL_MATRIX * vec4(VERTEX,1.0)).y;
}
void fragment() {
	ALBEDO = texture(atlas,UV).rgb * COLOR.rgb * vec3(.84,.80,.82);
	ROUGHNESS = .86;
	METALLIC = 0.0;
	SPECULAR = .2;
	ALPHA = COLOR.a * smoothstep(floor_y + .002, floor_y + .07, petal_world_y);
}
"""
	_ground = Node3D.new()
	_ground.name = "SparseSettledSakuraPetals"
	add_child(_ground)
	report = {"emitters_refined":0,"live_particles_per_tree":6,"ground_pockets":0,"ground_petals":0,"ground_ray_misses":0,"source_mesh_triangles":[14,12],"world_length_m":.016,"new_emitters":0,"collision_changes":0}
	var random := RandomNumberGenerator.new()
	random.seed = 20500017
	for name_value: String in GROUND_TREES:
		var anchor := _park.find_child(name_value.replace("DenseSakura_","DenseSakuraCollision_"),true,false) as Node3D
		if anchor != null:
			_ground_anchors.append(anchor.global_position)
	# Deferred replacements can receive generated names while the old node exits.
	for node: Node in _park.find_children("*","Node3D",true,false):
		var tree := node as Node3D
		if not tree.has_meta(&"midori_jogoss_sakura"):
			continue
		var emitter := tree.get_node_or_null("LoopingFallingSakuraPetals") as GPUParticles3D
		if emitter != null:
			_refine_emitter(emitter,tree.global_position.y)
		for anchor: Vector3 in _ground_anchors:
			if Vector2(tree.global_position.x,tree.global_position.z).distance_to(Vector2(anchor.x,anchor.z)) < .001:
				_ground_pocket(tree,random)
				break
	installed = true
	print("MIDORI_PETALS: ",JSON.stringify(report))

func _refine_emitter(emitter: GPUParticles3D, floor_y: float) -> void:
	var original := {"node":emitter}
	for field: String in SOURCE_FIELDS:
		original[field] = emitter.get(field)
	_states.append(original)
	var origin := emitter.global_position
	var old_process := emitter.process_material as ParticleProcessMaterial
	var box := old_process.emission_box_extents * emitter.global_basis.get_scale()
	var process := old_process.duplicate() as ParticleProcessMaterial
	process.emission_box_extents = Vector3(minf(box.x,2.2),minf(box.y,.3),minf(box.z,2.2))
	process.direction = Vector3(.12,-1,.05)
	process.spread = 18
	process.initial_velocity_min = .28
	process.initial_velocity_max = .42
	process.gravity = Vector3(.012,-.022,.004)
	process.particle_flag_rotate_y = true
	process.angle_min = -180
	process.angle_max = 180
	process.angular_velocity_min = -65
	process.angular_velocity_max = 65
	process.scale_min = .75
	process.scale_max = 1.10
	var key := roundi(floor_y*1000)
	if not _drift_materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = _shader
		material.set_shader_parameter("atlas",_ground_material.albedo_texture)
		material.set_shader_parameter("floor_y",floor_y)
		_drift_materials[key] = material
	emitter.top_level = true
	emitter.global_transform = Transform3D(Basis.IDENTITY,origin)
	emitter.local_coords = true
	emitter.amount = 6
	emitter.lifetime = 11
	emitter.preprocess = 0
	emitter.draw_pass_1 = _meshes[report.emitters_refined % _meshes.size()]
	emitter.process_material = process
	emitter.material_override = _drift_materials[key]
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.visibility_range_end = 45
	emitter.visibility_aabb = AABB(Vector3(-3.4,floor_y-origin.y-.1,-3),Vector3(7,origin.y-floor_y+1,6))
	emitter.restart()
	report.emitters_refined += 1

func _ground_pocket(tree: Node3D, random: RandomNumberGenerator) -> void:
	var transforms: Array[Array] = [[],[]]
	var colors: Array[Array] = [[],[]]
	var centre := tree.global_position + Vector3(1.25,0,.35)
	for index: int in range(18):
		var position := centre + Vector3(random.randfn(0,.38),0,random.randfn(0,.25))
		var point := Vector2(position.x,position.z)
		if point.distance_to(Vector2(tree.global_position.x,tree.global_position.z)) < .75:
			continue
		if is_finite(float(_park.bridge_surface_height(point))) or Geometry2D.is_point_in_polygon(point/_park.LAYOUT_SCALE,PackedVector2Array(_park.lake_contour)):
			continue
		var ray := PhysicsRayQueryParameters3D.create(Vector3(position.x,tree.global_position.y+.4,position.z),Vector3(position.x,tree.global_position.y-.15,position.z),1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y < .98:
			report.ground_ray_misses += 1
			continue
		position.y = hit.position.y + .001
		var size := random.randf_range(.75,1.10)
		var basis := Basis(Quaternion(Vector3.UP,hit.normal)) * Basis(Vector3.UP,random.randf_range(-PI,PI))
		basis = basis.scaled(Vector3.ONE*size)
		var variant := index % _meshes.size()
		transforms[variant].append(Transform3D(basis,position))
		colors[variant].append(Color(1,random.randf_range(.92,1),random.randf_range(.91,1),1))
	for variant: int in range(_meshes.size()):
		if transforms[variant].is_empty():
			continue
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_colors = true
		batch.mesh = _meshes[variant]
		batch.instance_count = transforms[variant].size()
		for index: int in range(batch.instance_count):
			batch.set_instance_transform(index,transforms[variant][index])
			batch.set_instance_color(index,colors[variant][index])
		var visual := MultiMeshInstance3D.new()
		visual.name = "%s_PetalPocket_%d" % [tree.name,variant]
		visual.multimesh = batch
		visual.material_override = _ground_material
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.visibility_range_end = 24
		_ground.add_child(visual)
		report.ground_petals += batch.instance_count
	report.ground_pockets += 1

func restore() -> void:
	for state: Dictionary in _states:
		var emitter := state.node as GPUParticles3D
		if not is_instance_valid(emitter):
			continue
		# Restore local transform after reattaching to the original scale hierarchy.
		emitter.top_level = state.top_level
		for field: String in SOURCE_FIELDS:
			if field not in ["transform","top_level"]:
				emitter.set(field,state[field])
		emitter.transform = state.transform
		emitter.restart()
	if is_instance_valid(_ground):
		_ground.hide()
	report["restored"] = true
