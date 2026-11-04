extends Node3D
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")

# Sheltered freshwater: measured terrain depth, wind packets and a live planar
# reflection. The supplied lake mesh, water level and swimming remain unchanged.
@export_range(0.0, 1.0, 0.01) var motion_speed := 0.32:
	set(value):
		motion_speed = clampf(value, 0.0, 1.0)
		_set_water_parameter(&"lake_motion_speed", motion_speed)
@export_range(0.0, 1.0, 0.01) var ripple_scale := 0.72:
	set(value):
		ripple_scale = clampf(value, 0.0, 1.0)
		_set_water_parameter(&"lake_ripple_scale", ripple_scale)
@export_range(0.0, 1.0, 0.01) var strength := 1.0:
	set(value):
		strength = clampf(value, 0.0, 1.0)
		_set_water_parameter(&"lake_life_strength", strength)
		for bank: Dictionary in _shore_banks: bank.material.set_shader_parameter("shore_strength",strength)
		for bank: Dictionary in _shore_banks: bank.film.set_shader_parameter("shore_strength",strength)
@export var enabled := true:
	set(value):
		enabled = value
		if _water != null and _source != null: _water.material_override = _material if enabled else _source
		for bank: Dictionary in _shore_banks: bank.node.material_override = bank.material if enabled else bank.source
		for bank: Dictionary in _shore_banks: bank.film_node.visible = enabled
var auto_install := true
var installed := false
var report: Dictionary = {}
var _water: MeshInstance3D
var _source: ShaderMaterial
var _material: ShaderMaterial
var _reflection: SubViewport
var _camera: Camera3D
## The planar reflection redraws the whole world, about a third of a lake view's
## frame. It renders every other frame; the ripples hide one frame of lag.
var _reflection_parity := 0
var _water_y := 0.102
var _previous_layers := 1
var _cached_probe: ReflectionProbe
var _cached_probe_mask := 1048575
var _shore_banks: Array[Dictionary] = []
# Negative uses engine time; explicit values are for reproducible review only.
var shoreline_review_time := -1.0
var _last_shore_clock := INF
var _last_reflection_ready := -1.0
var _reflection_matrices_valid := false
var _last_reflection_projection: Projection
var _last_reflection_view: Transform3D
var reflection_projection_updates := 0
var reflection_view_updates := 0
## A sheltered freshwater lake has broken, muted reflections rather than a
## polished mirror. Attenuate radiance itself, not its blend alpha (which would
## merely substitute the unattenuated sky). Original depth/shore geometry stays.
@export_range(0.0, 1.0, 0.01) var reflection_strength := .68:
	set(value):
		reflection_strength = clampf(value,0.0,1.0)
		_set_water_parameter(&"lake_reflection_strength",reflection_strength)
const REFLECTION_HEIGHT_CAP := 540.0
const REFLECTION_INTERNAL_NEAR := .75

const SHORE_UNIFORMS := """
uniform float shore_strength = 1.0;
uniform float shore_clock = -1.0;
uniform float shore_width_m = 2.3;
"""
const SHORE_FUNCTIONS := """
float shore_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float shore_noise(vec2 p) {
    vec2 a=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(shore_hash(a),shore_hash(a+vec2(1,0)),f.x),
               mix(shore_hash(a+vec2(0,1)),shore_hash(a+vec2(1,1)),f.x),f.y);
}
"""
const SHORE_FRAGMENT := """
    float shore_t = shore_clock < 0.0 ? TIME : shore_clock;
    vec2 shore_p = world_position.xz;
    float shore_phase_offset = shore_noise(shore_p*.025)*.28+dot(shore_p,vec2(.006,.003));
    float shore_phase = fract(shore_t/5.6+shore_phase_offset);
    // A quicker run-up and a longer drain-back; adjacent banks stay continuous.
    float shore_pulse = smoothstep(0.0,.28,shore_phase)*(1.0-smoothstep(.34,1.0,shore_phase));
    float shore_maximum = mix(.44,.70,shore_noise(shore_p*.18));
    if (water_at_outer_edge) shore_maximum = min(shore_maximum,.34);
    float shore_front = .035+shore_maximum*shore_pulse;
    shore_front += sin(dot(shore_p,vec2(2.3,3.1))+shore_t*1.8)*.009*shore_pulse;
    float shore_distance = (water_at_outer_edge ? 1.0-UV.x : UV.x)*shore_width_m;
    float shore_film = (1.0-smoothstep(shore_front-.025,shore_front+.045,shore_distance))*shore_strength;
    // Wet ground outlasts each wave. Existing scan/soil detail stays visible.
    float shore_drain = smoothstep(0.0,.20,shore_phase)*(1.0-smoothstep(.40,1.0,shore_phase));
    float shore_damp = (1.0-smoothstep(.05,shore_maximum+.14,shore_distance))*(.45+.55*shore_drain)*shore_strength;
    vec3 shore_soil = ALBEDO;
    ALBEDO *= mix(1.0,.72,shore_damp);
    ALBEDO = mix(ALBEDO,mix(shore_soil*.42,vec3(.020,.038,.025),.22),shore_film*.60);
    ROUGHNESS = mix(ROUGHNESS,mix(.38,.19,shore_drain),shore_damp*.80);
    ROUGHNESS = mix(ROUGHNESS,.065,shore_film);
    SPECULAR = mix(SPECULAR,.357,shore_film);
    vec3 shore_normal = normalize(vec3(.013*cos(dot(shore_p,vec2(4.1,2.3))-shore_t*.8),1.0,
                                      .010*sin(dot(shore_p,vec2(-2.7,5.1))+shore_t*.65)));
    NORMAL = normalize(mix(NORMAL,(VIEW_MATRIX*vec4(shore_normal,0)).xyz,shore_film*.94));
"""

const SURFACE_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float lake_life_strength = 1.0;
uniform float lake_motion_speed = 0.32;
uniform float lake_ripple_scale = 0.72;
uniform float lake_reflection_strength = 0.68;
uniform sampler2D lake_depth : filter_linear, repeat_disable;
uniform vec4 depth_bounds = vec4(-220.5,-180.5,441.0,361.0);
uniform sampler2D planar_reflection : source_color, filter_linear, repeat_disable;
uniform mat4 reflection_projection;
uniform mat4 reflection_view;
uniform float reflection_ready = 0.0;
uniform float water_y = 0.102;
varying vec3 world_position;
float lake_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float lake_noise(vec2 p) {
    vec2 a=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(lake_hash(a),lake_hash(a+vec2(1,0)),f.x),
               mix(lake_hash(a+vec2(0,1)),lake_hash(a+vec2(1,1)),f.x),f.y);
}
vec2 lake_wave(vec2 p,vec2 direction,float k,float slope,float phase,float t) {
    float q=dot(p,direction)*k+phase-sqrt(9.81*k)*t*lake_motion_speed;
    return direction*slope*cos(q)*(1.0-smoothstep(0.65,2.5,fwidth(q)));
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p=world_position.xz;
    float depth=max(0.0,texture(lake_depth,(p-depth_bounds.xy)/depth_bounds.zw).r);
    float packet=lake_noise(p*0.12+vec2(-0.022,0.014)*TIME*lake_motion_speed);
    float gust=smoothstep(0.18,0.86,packet);
    float phase=lake_noise(p*0.28)*4.0;
    vec2 slope=vec2(0);
    // Longer low-amplitude wind packets retain surface variation at distance.
    // These alter normals only: water geometry/level and swimming are exact.
    slope+=lake_wave(p,normalize(vec2(.83,.55)),1.7,.022,phase*.31,TIME);
    slope+=lake_wave(p,normalize(vec2(.97,.24)),.72,.010,-phase*.19,TIME);
    slope+=lake_wave(p,normalize(vec2(.83,.55)),4.2,.018,phase,TIME);
    slope+=lake_wave(p,normalize(vec2(.97,.24)),8.1,.016,-phase*.73,TIME);
    slope+=lake_wave(p,normalize(vec2(.61,.79)),13.7,.012,phase*1.37,TIME);
    slope+=lake_wave(p,normalize(vec2(.99,-.12)),21.3,.008,-phase*1.91,TIME);
    slope+=lake_wave(p,normalize(vec2(.42,.91)),31.1,.005,phase*2.53,TIME);
    slope+=lake_wave(p,normalize(vec2(-.34,.94)),17.2,.004,phase*.41,TIME);
    slope*=mix(.22,.95,gust)*lake_ripple_scale*smoothstep(.01,.45,depth);
    vec3 n=normalize(vec3(-slope.x,1.0,-slope.y));
    NORMAL=normalize((VIEW_MATRIX*vec4(n,0)).xyz);
    // Beer-Lambert-like attenuation based on the existing terrain, not stripes
    // painted across the surface. Deep bulk is opaque with suspended organics.
    float shallows=exp(-depth*1.65);
    float sediment=lake_noise(p*.65)*.5+lake_noise(p*2.4)*.5;
    vec3 body=mix(vec3(.009,.027,.021),vec3(.070,.078,.042),shallows);
    body*=mix(.91,1.09,sediment*shallows);
    ALBEDO=mix(vec3(.030,.062,.031),body,lake_life_strength);
    METALLIC=0.0;
    SPECULAR=.30;
    ROUGHNESS=mix(.24,mix(.14,.23,gust),lake_life_strength);
    vec4 projected=reflection_projection*reflection_view*vec4(world_position,1.0);
    vec2 uv=projected.xy/max(projected.w,.0001)*vec2(.5,-.5)+.5;
    uv+=vec2(slope.x,-slope.y)*.028;
    float border=smoothstep(0.0,.035,min(min(uv.x,uv.y),min(1.0-uv.x,1.0-uv.y)));
    float valid=reflection_ready*border*step(.001,projected.w)*step(water_y+.035,CAMERA_POSITION_WORLD.y);
    vec3 reflected=texture(planar_reflection,clamp(uv,vec2(.001),vec2(.999))).rgb;
    // RADIANCE preserves the engine's angle-dependent dielectric reflectance.
    // The surface stays in the opaque pass and falls back to the existing probe.
    RADIANCE=vec4(reflected*lake_reflection_strength,valid*lake_life_strength);
}
"""

func _set_water_parameter(parameter: StringName, value: float) -> void:
	if _material != null: _material.set_shader_parameter(parameter, value)
	for bank: Dictionary in _shore_banks:
		bank.film.set_shader_parameter(parameter, value)

func _ready() -> void:
	await LoadingBudget.wait_structure(get_parent())
	if auto_install: call_deferred("install")

func install() -> void:
	if installed or get_parent() == null: return
	var terrain := get_parent().get_node_or_null("MidoriTerrain")
	while terrain != null and not terrain.installed: await get_tree().process_frame
	var _ft := preload("res://scripts/startup_trace.gd").begin()
	_water = get_parent().find_child("LakeWaterSurface",true,false) as MeshInstance3D
	if _water == null or not _water.material_override is ShaderMaterial:
		push_warning("MIDORI_LAKE_LIFE: supplied lake material not found")
		return
	_source = _water.material_override as ShaderMaterial
	_water_y = (_water.global_transform * _water.mesh.get_aabb().get_center()).y
	_previous_layers = _water.layers
	_cached_probe = get_parent().find_child("LakeCachedReflection",true,false) as ReflectionProbe
	if _cached_probe != null: _cached_probe_mask = _cached_probe.reflection_mask
	_water.layers = _water.layers | 2
	_water.layers = _water.layers & ~1
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SURFACE_SHADER
	_material.shader = shader
	_material.resource_name = "MidoriFreshwater_DepthWindReflection"
	_material.set_shader_parameter("lake_life_strength",strength)
	_material.set_shader_parameter("lake_motion_speed",motion_speed)
	_material.set_shader_parameter("lake_ripple_scale",ripple_scale)
	_material.set_shader_parameter("lake_reflection_strength",reflection_strength)
	_material.set_shader_parameter("water_y",_water_y)
	var image := Image.create(441,361,false,Image.FORMAT_RF)
	var maximum_depth := 0.0
	for z: int in range(361):
		for x: int in range(441):
			var point := Vector2(x-220,z-180)
			var height: float = terrain.height_at(point) if terrain != null else -3.0
			var depth := maxf(0.0,_water_y-height)
			maximum_depth = maxf(maximum_depth,depth)
			image.set_pixel(x,z,Color(depth,0,0))
	_material.set_shader_parameter("lake_depth",ImageTexture.create_from_image(image))
	if RenderingServer.get_current_rendering_method() == "forward_plus": _create_reflection()
	_install_shore_wash()
	_water.material_override = _material if enabled else _source
	_last_shore_clock = INF
	_last_reflection_ready = -1.0
	_reflection_matrices_valid = false
	preload("res://scripts/startup_trace.gd").finish("feature.lake_life", _ft)
	installed = true
	report = {"modified_surfaces":1,"vertex_displacement_m":0.0,"water_y":_water_y,"depth_map_resolution":[441,361],"maximum_depth_m":maximum_depth,"planar_reflection":_reflection != null,"reflection_probe_reused":get_parent().find_child("LakeCachedReflection",true,false)!=null,"source_shader_unchanged":true}
	report["animated_bank_surfaces"] = _shore_banks.size()
	report["wash_cycle_seconds"] = 5.6
	report["maximum_mainland_runup_m"] = .744
	report["maximum_island_runup_m"] = .384
	report["thin_water_films"] = _shore_banks.size()
	report["film_offset_m"] = .0012
	report["reflection_strength"] = reflection_strength
	report["reflection_height_cap"] = int(REFLECTION_HEIGHT_CAP)
	report["small_understory_reflection_policy"] = "existing small-plant exclusion includes sparse understory via shared classifier"
	print("MIDORI_LAKE_LIFE: ",JSON.stringify(report))

func _create_reflection() -> void:
	_reflection = SubViewport.new()
	_reflection.name = "LakePlanarReflection"
	_reflection.size = Vector2i(960,540)
	_reflection.world_3d = get_world_3d()
	_reflection.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# The root view retains native resolution/MSAA/TAA. The softer secondary
	# reflection is bilinearly sampled and does not need another MSAA pass.
	_reflection.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_reflection)
	_camera = Camera3D.new()
	_camera.name = "ReflectedLakeCamera"
	_camera.cull_mask = 1048575 & ~2
	_reflection.add_child(_camera)
	_camera.make_current()
	_material.set_shader_parameter("planar_reflection",_reflection.get_texture())

func _process(_delta: float) -> void:
	if shoreline_review_time != _last_shore_clock:
		for bank: Dictionary in _shore_banks:
			bank.material.set_shader_parameter("shore_clock",shoreline_review_time)
			bank.film.set_shader_parameter("shore_clock",shoreline_review_time)
		_last_shore_clock = shoreline_review_time
	for bank: Dictionary in _shore_banks:
		var light_factor: Variant = bank.source.get_shader_parameter("scene_light_factor")
		if not bank.has("last_light_factor") or bank.last_light_factor != light_factor:
			bank.material.set_shader_parameter("scene_light_factor",light_factor)
			bank.last_light_factor = light_factor
	if not installed or _reflection == null: return
	var source := get_viewport().get_camera_3d()
	var active := enabled and strength > 0.0 and source != null and source.global_position.y > _water_y+.035
	# Reuse this frame's exact bounds for culling and quality-tier selection.
	# Recompute next frame so edits/moved bank geometry remain visible.
	var bounds := AABB()
	if active:
		bounds = _reflection_consumer_bounds()
		active = _reflection_consumers_visible(source) and _reflection_is_visible(source,bounds)
	_select_reflection_source(active)
	_reflection_parity = (_reflection_parity + 1) % 2 if active else 0
	var render_now := active and _reflection_parity == 0
	# UPDATE_ONCE drops back to disabled after its render, so set it every time.
	_reflection.render_target_update_mode = SubViewport.UPDATE_ONCE if render_now else SubViewport.UPDATE_DISABLED
	var ready_value := 1.0 if active else 0.0
	if ready_value != _last_reflection_ready:
		_material.set_shader_parameter("reflection_ready",ready_value)
		for bank: Dictionary in _shore_banks: bank.film.set_shader_parameter("reflection_ready",ready_value)
		_last_reflection_ready = ready_value
	# On the off frame keep the last image and the matrices it was rendered with.
	if not render_now: return
	var size := get_viewport().get_visible_rect().size
	var scale := _reflection_target_scale(source,bounds)
	var lod_threshold := 4.0 if _reflection_resolution_scale==1.0 else 8.0
	if _reflection.mesh_lod_threshold != lod_threshold: _reflection.mesh_lod_threshold = lod_threshold
	var target := Vector2i(maxi(2,int(size.x*scale)),maxi(2,int(size.y*scale)))
	if _reflection.size != target: _reflection.size = target
	if _camera.keep_aspect != source.keep_aspect: _camera.keep_aspect = source.keep_aspect
	if _camera.projection != source.projection: _camera.projection = source.projection
	if _camera.frustum_offset != source.frustum_offset: _camera.frustum_offset = source.frustum_offset
	if _camera.fov != source.fov: _camera.fov = source.fov
	if _camera.size != source.size: _camera.size = source.size
	if _camera.near != source.near: _camera.near = source.near
	if _camera.far != source.far: _camera.far = source.far
	if _camera.environment != source.environment: _camera.environment = source.environment
	if _camera.attributes != source.attributes: _camera.attributes = source.attributes
	var mirrored := source.get_camera_transform()
	var eye := mirrored.origin
	eye.y = 2.0*_water_y-eye.y
	var forward := -mirrored.basis.z
	forward.y = -forward.y
	var up := mirrored.basis.y
	up.y = -up.y
	_camera.global_position = eye
	_camera.look_at(eye+forward,up)
	_publish_reflection_matrices()

func _publish_reflection_matrices() -> void:
	# Compute each matrix once, and upload only the values that changed. The
	# viewport still renders every active frame, including animated reflections.
	var projection := _camera.get_camera_projection()
	var view := _camera.global_transform.affine_inverse()
	if not _reflection_matrices_valid or projection != _last_reflection_projection:
		_material.set_shader_parameter("reflection_projection",projection)
		for bank: Dictionary in _shore_banks: bank.film.set_shader_parameter("reflection_projection",projection)
		_last_reflection_projection = projection
		reflection_projection_updates += 1
	if not _reflection_matrices_valid or view != _last_reflection_view:
		_material.set_shader_parameter("reflection_view",view)
		for bank: Dictionary in _shore_banks: bank.film.set_shader_parameter("reflection_view",view)
		_last_reflection_view = view
		reflection_view_updates += 1
	_reflection_matrices_valid = true

func _reflection_consumers_visible(source: Camera3D) -> bool:
	# A hidden lake can still have a visible film, so check every receiver.
	if _water.is_visible_in_tree() and (source.cull_mask & _water.layers) != 0: return true
	for bank: Dictionary in _shore_banks:
		var film: MeshInstance3D = bank.film_node
		if is_instance_valid(film) and film.is_visible_in_tree() and (source.cull_mask & film.layers) != 0: return true
	return false

func _install_shore_wash() -> void:
	var lake := _water.get_parent()
	for node: Node in lake.get_children():
		if not node is MeshInstance3D: continue
		if node.name != "ContinuousNaturalBank" and not String(node.name).ends_with("_SoftBank"): continue
		var bank := node as MeshInstance3D
		var source := bank.material_override as ShaderMaterial
		if source == null or not source.shader.code.contains("float landward = water_at_outer_edge"): continue
		var code := source.shader.code
		code = code.replace("varying vec3 world_position;",SHORE_UNIFORMS+"\nvarying vec3 world_position;")
		code = code.replace("void vertex()",SHORE_FUNCTIONS+"\nvoid vertex()")
		code = code.insert(code.rfind("}"),SHORE_FRAGMENT)
		var shader := Shader.new()
		shader.code = code
		var material := source.duplicate() as ShaderMaterial
		material.shader = shader
		material.resource_name = "MidoriShore_SwashAndDampSoil"
		material.set_shader_parameter("shore_strength",strength)
		material.set_shader_parameter("shore_width_m",.84 if String(node.name).ends_with("_SoftBank") else 2.3)
		# The film is on the water render layer, excluded from its own reflected
		# camera. It reuses the fitted bank mesh and adds no collision or assets.
		var film_code := SURFACE_SHADER.replace("render_mode cull_disabled;","render_mode cull_disabled, depth_draw_never;")
		film_code = film_code.replace("varying vec3 world_position;",SHORE_UNIFORMS+"\nuniform bool water_at_outer_edge = false;\nvarying vec3 world_position;")
		film_code = film_code.replace("void vertex()",SHORE_FUNCTIONS+"\nvoid vertex()")
		film_code = film_code.replace("world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;","VERTEX.y += .0012; world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;")
		var front_code := SHORE_FRAGMENT.substr(0,SHORE_FRAGMENT.find("    // Wet ground"))
		film_code = film_code.insert(film_code.rfind("}"),front_code+"\n    ALPHA = shore_film * .32;\n    if (ALPHA < .002) discard;\n")
		var film_shader := Shader.new()
		film_shader.code = film_code
		var film := _material.duplicate() as ShaderMaterial
		film.shader = film_shader
		film.resource_name = "MidoriShore_AdvancingWaterFilm"
		film.render_priority = 2
		film.set_shader_parameter("shore_strength",strength)
		film.set_shader_parameter("shore_width_m",.84 if String(node.name).ends_with("_SoftBank") else 2.3)
		film.set_shader_parameter("water_at_outer_edge",String(node.name).ends_with("_SoftBank"))
		var film_node := MeshInstance3D.new()
		film_node.name = "ShoreWaterFilm"
		film_node.mesh = bank.mesh
		film_node.material_override = film
		film_node.layers = 2
		film_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		film_node.visible = enabled
		bank.add_child(film_node)
		_shore_banks.append({"node":bank,"source":source,"material":material,"film":film,"film_node":film_node,"mesh":bank.mesh,"transform":bank.global_transform})
		bank.material_override = material if enabled else source

var _reflection_resolution_scale := 1.0
func _reflection_consumer_bounds() -> AABB:
	var bounds: AABB=_water.global_transform*_water.mesh.get_aabb()
	for bank: Dictionary in _shore_banks:
		var mesh: MeshInstance3D=bank.node
		bounds=bounds.merge(mesh.global_transform*mesh.mesh.get_aabb())
		var film: MeshInstance3D=bank.film_node
		bounds=bounds.merge(film.global_transform*film.mesh.get_aabb())
	return bounds.grow(.1)
var _water_triangles := PackedVector3Array()
func _reflection_is_visible(source: Camera3D, bounds: AABB = AABB()) -> bool:
	if bounds.size == Vector3.ZERO: bounds = _reflection_consumer_bounds()
	var interior:=source.global_position-source.global_basis.z*(source.near+source.far)*.5
	for plane: Plane in source.get_frustum():
		var sign_inside:=1.0 if plane.distance_to(interior)>=0 else -1.0
		var all_outside:=true
		for corner in 8:
			if sign_inside*plane.distance_to(bounds.get_endpoint(corner))>=-.01:
				all_outside=false;break
		if all_outside: return false
	# The lake's box spans most of the park, so the camera often stands inside
	# it facing away from the water. Test the water's own triangles as well.
	if _water_triangles.is_empty():
		for point: Vector3 in _water.mesh.get_faces(): _water_triangles.append(_water.global_transform*point)
	var planes := source.get_frustum()
	var signs: Array[float] = []
	for plane: Plane in planes: signs.append(1.0 if plane.distance_to(interior)>=0 else -1.0)
	for t in range(0,_water_triangles.size(),3):
		var culled:=false
		for p in planes.size():
			if signs[p]*planes[p].distance_to(_water_triangles[t])<-.01 and signs[p]*planes[p].distance_to(_water_triangles[t+1])<-.01 and signs[p]*planes[p].distance_to(_water_triangles[t+2])<-.01:
				culled=true;break
		if not culled: return true
	return false
func _reflection_target_scale(source: Camera3D, bounds: AABB = AABB()) -> float:
	# The output texture keeps one size while walking, so allocation/receiver
	# changes cannot expose a different texture at the old distance boundary.
	var size := get_viewport().get_visible_rect().size
	var output_scale := minf(1.0,REFLECTION_HEIGHT_CAP/maxf(size.y,1.0))
	if bounds.size == Vector3.ZERO: bounds = _reflection_consumer_bounds()
	var nearest := source.global_position.clamp(bounds.position,bounds.end)
	var distance := source.global_position.distance_to(nearest)
	# One output size keeps the texture stable while walking. Apply the same
	# proportional reduction to all tiers instead of accidentally rendering a
	# larger internal image when output resolution is reduced.
	if _reflection_resolution_scale==1.0:
		if distance>83.0: _reflection_resolution_scale=.25
		elif distance>38.0: _reflection_resolution_scale=.5
	elif _reflection_resolution_scale==.5:
		if distance<=35.0: _reflection_resolution_scale=1.0
		elif distance>83.0: _reflection_resolution_scale=.25
	else:
		if distance<=35.0: _reflection_resolution_scale=1.0
		elif distance<=80.0: _reflection_resolution_scale=.5
	var internal_scale := minf(1.0,(_reflection_resolution_scale*REFLECTION_INTERNAL_NEAR)/output_scale)
	if _reflection.scaling_3d_scale != internal_scale: _reflection.scaling_3d_scale = internal_scale
	return output_scale


func _select_reflection_source(planar_active: bool) -> void:
	if not is_instance_valid(_cached_probe): return
	# Forward+ blends probes after the spatial shader's custom RADIANCE. Mask
	# only the water/film layer while its live reflection is active; all other
	# receivers and the probe capture remain unchanged. Restore the cached
	# source when disabled, below water, offscreen or at zero strength.
	var mask := (_cached_probe_mask & ~2) if planar_active else _cached_probe_mask
	if _cached_probe.reflection_mask != mask: _cached_probe.reflection_mask = mask

func _exit_tree() -> void:
	if is_instance_valid(_cached_probe): _cached_probe.reflection_mask = _cached_probe_mask
