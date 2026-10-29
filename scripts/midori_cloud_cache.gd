extends Node
## Reuse slowly changing cloud radiance: cache distant cloud radiance/alpha in a linear HDR cubemap.
## Original dome/sky/material are retained. No main resolution or lighting edits.
var host: Node
var original: ShaderMaterial
var original_override: Material
var native_material: ShaderMaterial
var candidate: ShaderMaterial
var texture:=TextureCubemapRD.new()
var size:=512
var enabled:=false
var cache_ready:=false
var pending:=false
var error:=""
var elapsed:=0.0
var face:=0
var front_index:=0
var disposed:=false
var clock_seconds:=0.0
var clock_rollover:=3600.0
var freeze_clock:=false
var cycle_params:=PackedByteArray()
var published_night:=-1.0
var current_night:=1.0
var completed_cycles:=0
var dispatches:=0
var has_sun:=false
var shader_rid:=RID()
var pipeline_rid:=RID()
var texture_rids: Array[RID]=[]
var uniform_rids: Array[RID]=[]
var compute_code: String
var events: Array=[]
var capture_events:=false

func install(park: Node, resolution: int=512) -> Dictionary:
	var domes:=park.find_children("CalmCloudDome","MeshInstance3D",true,false)
	if domes.size()!=1: return {"error":"Expected exactly one cloud dome"}
	if resolution not in [256,512,1024]: return {"error":"Unsupported cube size"}
	size=resolution
	host=domes[0].get_parent()
	original=host.material
	if original.shader.code.sha256_text()!="a8a909a33351196722866b546c51394291d7968b7d448426aa045c6623e74d21": return {"error":"Installed cloud source drift"}
	if host.dome.material_override!=original: return {"error":"Host and visible dome materials differ"}
	original_override=host.dome.material_override
	compute_code=build_compute(original.shader.code)
	clock_seconds=Time.get_ticks_usec()/1000000.0
	clock_rollover=float(ProjectSettings.get_setting("rendering/limits/time/time_rollover_secs",3600.0))
	for property: Dictionary in host.get_parent().get_property_list():
		if property.name=="park_directional_light": has_sun=true
	native_material=original.duplicate()
	native_material.shader=Shader.new()
	native_material.shader.code=original.shader.code.replace("shader_type spatial;","shader_type spatial;\nuniform float qa_cloud_time=0.0;").replace("*TIME*","*qa_cloud_time*")
	for uniform: Dictionary in original.shader.get_shader_uniform_list():
		var value=original.get_shader_parameter(uniform.name)
		if value!=null: native_material.set_shader_parameter(uniform.name,value)
	candidate=ShaderMaterial.new()
	candidate.render_priority=original.render_priority
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, fog_disabled;
uniform samplerCube cached_clouds: filter_linear;
uniform vec3 sun_direction=vec3(0.45,0.58,0.68);
varying vec3 sky_ray;
void vertex(){ sky_ray=(MODEL_MATRIX*vec4(VERTEX,0.0)).xyz; }
void fragment(){ vec4 cloud=texture(cached_clouds,normalize(sky_ray)); ALBEDO=cloud.rgb/max(cloud.a,0.00001); ALPHA=cloud.a; }
"""
	candidate.shader=shader
	candidate.set_shader_parameter("sun_direction",original.get_shader_parameter("sun_direction"))
	process_priority=200
	process_mode=Node.PROCESS_MODE_ALWAYS
	_sync_state()
	var params:=parameters(-1)
	pending=true
	_record_event({"event":"initial_request","cpu_us":Time.get_ticks_usec(),"phase":clock_seconds})
	RenderingServer.call_on_render_thread(_create.bind(params))
	return {"qa_only":false,"resolution":size,"refresh":"coherent back cube, one face per0.25s, publish complete six-face snapshot; night transition uses native until new cube ready","linear_hdr":"premultiplied RGBA16F; original dome/sky/lighting retained","clock":"explicit shared native/cache clock from initial engine ticks then scaled frame delta; configured rollover; always-process through tree pause","source_sha256":original.shader.code.sha256_text(),"candidate_sha256":FileAccess.get_sha256(get_script().resource_path)}

static func build_compute(source: String) -> String:
	var functions:=source.substr(source.find("float hash3"),source.find("void vertex()")-source.find("float hash3"))
	var body:=source.substr(source.find("void fragment() {")+"void fragment() {".length()).strip_edges()
	body=body.left(body.rfind("}"))
	body=body.replace("vec3 ray=normalize(sky_ray);","")
	body=body.replace("FRAGCOORD.xy","vec2(pixel.xy)")
	body=body.replace("ALBEDO=","vec3 cloud_color=").replace("ALPHA=","float cloud_alpha=")
	return """#version 450
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(rgba16f,set=0,binding=0) uniform writeonly imageCube target_clouds;
layout(push_constant,std430) uniform Params {vec4 settings;vec4 sun_night;vec4 options;} params;
#define TIME params.settings.x
#define coverage params.settings.y
#define drift_speed params.settings.z
#define daylight_brightness params.settings.w
#define sun_direction params.sun_night.xyz
#define night_amount params.sun_night.w
"""+functions+"""
void main(){
 ivec3 pixel=ivec3(gl_GlobalInvocationID);
 int side=int(params.options.x);
 if(pixel.x>=side||pixel.y>=side) return;
 int face=int(params.options.y)<0?pixel.z:int(params.options.y);
 vec2 uv=(vec2(pixel.xy)+vec2(0.5))/float(side)*2.0-1.0;
 vec3 ray;
 if(face==0)ray=vec3(1,-uv.y,-uv.x);
 else if(face==1)ray=vec3(-1,-uv.y,uv.x);
 else if(face==2)ray=vec3(uv.x,1,uv.y);
 else if(face==3)ray=vec3(uv.x,-1,-uv.y);
 else if(face==4)ray=vec3(uv.x,-uv.y,1);
 else ray=vec3(-uv.x,-uv.y,-1);
 ray=normalize(ray);
"""+body+"\n imageStore(target_clouds,ivec3(pixel.xy,face),vec4(cloud_color*cloud_alpha,cloud_alpha));\n}"

func parameters(which: int) -> PackedByteArray:
	var sun: Vector3=native_material.get_shader_parameter("sun_direction")
	return PackedFloat32Array([clock_seconds,host.coverage,host.drift_metres_per_second,host.daylight_cloud_brightness,sun.x,sun.y,sun.z,current_night,float(size),float(which),0.0,0.0]).to_byte_array()

func _sync_state() -> void:
	if not is_instance_valid(host): return
	current_night=1.0 if host.get_parent().is_night_mode else 0.0
	var sun: Vector3=native_material.get_shader_parameter("sun_direction")
	if has_sun and is_instance_valid(host.get_parent().park_directional_light): sun=host.get_parent().park_directional_light.global_basis.z.normalized()
	native_material.set_shader_parameter("sun_direction",sun)
	native_material.set_shader_parameter("night_amount",current_night)
	native_material.set_shader_parameter("qa_cloud_time",clock_seconds)
	candidate.set_shader_parameter("sun_direction",sun)
	if enabled and is_instance_valid(host.dome):
		var shown: Material=candidate if published_night==current_night and cache_ready else native_material
		host.material=shown;host.dome.material_override=shown

func _create(params: PackedByteArray) -> void:
	if disposed: return
	var rd:=RenderingServer.get_rendering_device()
	if rd==null: _failed.call_deferred("RenderingDevice unavailable");return
	var source:=RDShaderSource.new()
	source.source_compute=compute_code
	var spirv:=rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty(): _failed.call_deferred(spirv.compile_error_compute);return
	shader_rid=rd.shader_create_from_spirv(spirv)
	pipeline_rid=rd.compute_pipeline_create(shader_rid)
	if not shader_rid.is_valid() or not pipeline_rid.is_valid(): _failed.call_deferred("Compute pipeline creation failed");return
	var format:=RDTextureFormat.new()
	format.texture_type=RenderingDevice.TEXTURE_TYPE_CUBE
	format.width=size;format.height=size;format.array_layers=6
	format.format=RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format.usage_bits=RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	for index in 2:
		var rid:=rd.texture_create(format,RDTextureView.new())
		if not rid.is_valid(): _failed.call_deferred("Cloud texture allocation failed");return
		texture_rids.append(rid)
		var uniform:=RDUniform.new()
		uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform.binding=0;uniform.add_id(rid)
		var binding:=rd.uniform_set_create([uniform],shader_rid,0)
		if not binding.is_valid(): _failed.call_deferred("Cloud uniform allocation failed");return
		uniform_rids.append(binding)
	_dispatch(params,0,true)

func _dispatch(params: PackedByteArray, target_index: int, initial: bool=false) -> void:
	if disposed: return
	if params.size()!=48 or target_index>=uniform_rids.size(): _failed.call_deferred("Invalid cloud dispatch state");return
	var rd:=RenderingServer.get_rendering_device()
	var list:=rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list,pipeline_rid)
	rd.compute_list_bind_uniform_set(list,uniform_rids[target_index],0)
	rd.compute_list_set_push_constant(list,params,params.size())
	var which:=int(params.decode_float(36))
	rd.compute_list_dispatch(list,ceili(size/8.0),ceili(size/8.0),6 if which<0 else 1)
	rd.compute_list_end()
	_completed.call_deferred(target_index,which,params.decode_float(28),initial)

func _completed(target_index: int, which: int, night: float, initial: bool) -> void:
	pending=false
	if disposed: return
	dispatches+=1
	_record_event({"event":"dispatch_submitted","cpu_us":Time.get_ticks_usec(),"face":which,"target":target_index,"initial":initial,"night":night})
	if initial or which==5:
		front_index=target_index
		texture.texture_rd_rid=texture_rids[front_index]
		candidate.set_shader_parameter("cached_clouds",texture)
		published_night=night
		cache_ready=true
		completed_cycles+=1
		_record_event({"event":"cube_published","cpu_us":Time.get_ticks_usec(),"generation":completed_cycles,"night":night})
		cycle_params=PackedByteArray()
		face=0
	_sync_state()

func _failed(message: String) -> void:
	pending=false
	if disposed: return
	error=message;push_warning(message)

func apply(use_cache: bool) -> void:
	if disposed or not is_instance_valid(host): return
	enabled=use_cache
	_sync_state()
	if not enabled:
		host.material=native_material
		host.dome.material_override=native_material

func _process(delta: float) -> void:
	if disposed: return
	if not freeze_clock: clock_seconds=fmod(clock_seconds+delta,clock_rollover)
	_sync_state()
	if not enabled or pending or not cache_ready: return
	elapsed+=delta
	var interval:=0.0 if published_night!=current_night else 0.25
	if elapsed<interval: return
	elapsed=0.0
	if cycle_params.is_empty(): cycle_params=parameters(0)
	var params:=cycle_params.duplicate()
	params.encode_float(36,float(face))
	_record_event({"event":"face_requested","cpu_us":Time.get_ticks_usec(),"face":face,"phase":params.decode_float(0),"night":params.decode_float(28)})
	face+=1
	pending=true
	RenderingServer.call_on_render_thread(_dispatch.bind(params,1-front_index,false))

func restore() -> bool:
	enabled=false
	if not is_instance_valid(host) or original==null or native_material==null: return true
	_sync_state()
	original.set_shader_parameter("night_amount",current_night)
	original.set_shader_parameter("sun_direction",native_material.get_shader_parameter("sun_direction"))
	host.material=original
	if is_instance_valid(host.dome): host.dome.material_override=original_override
	return host.material==original and (not is_instance_valid(host.dome) or host.dome.material_override==original_override)

func dispose() -> void:
	if disposed: return
	restore()
	disposed=true
	pending=false
	cache_ready=false
	set_process(false)
	texture.texture_rd_rid=RID()
	if candidate!=null: candidate.set_shader_parameter("cached_clouds",null)
	RenderingServer.call_on_render_thread(_free_rd)

func _exit_tree() -> void:
	dispose()
	# Drain this node-bound render callback before the node can be destroyed.
	# Only scene teardown synchronizes; normal gameplay never waits for the GPU.
	RenderingServer.force_sync()

func _free_rd() -> void:
	var rd:=RenderingServer.get_rendering_device()
	if rd==null: return
	for resource in uniform_rids:
		if resource.is_valid(): rd.free_rid(resource)
	uniform_rids.clear()
	if pipeline_rid.is_valid(): rd.free_rid(pipeline_rid);pipeline_rid=RID()
	if shader_rid.is_valid(): rd.free_rid(shader_rid);shader_rid=RID()
	for resource in texture_rids:
		if resource.is_valid(): rd.free_rid(resource)
	texture_rids.clear()

func snapshot() -> Dictionary:
	return {"enabled":enabled,"displayed":"cached" if host.material==candidate else ("native_clocked" if host.material==native_material else "original"),"generation":completed_cycles,"phase":clock_seconds,"published_night":published_night,"current_night":current_night,"pending":pending,"front_index":front_index,"material_id":host.dome.material_override.get_instance_id(),"texture_rid":str(texture.texture_rd_rid),"events":events.size()}

func _record_event(event: Dictionary) -> void:
	if not capture_events: return
	if events.size()>=4096: events.pop_front()
	events.append(event)
