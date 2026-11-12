extends Node
## Preserve nearby small-plant shadows. Spatially bound small-plant shadow casters; retain native geometry.
const ShadowShader = preload("res://shaders/midori_grass_shadow_fade.gdshader")
const OpaqueShadowShader = preload("res://shaders/midori_ground_shadow_fade.gdshader")
const FOREST_SHADER_SHA256 := "bedacc0eed1dd6d925ce28a0ccb27f422eb8eff6ddae1cbd8ed125abf9884f71"
const FOREST_PHOTO_SHADER_SHA256 := "bf9aa2fd73bf3faa0a28b4620fd51debad937671c1ec942d25041d3e5dc7cb65"
const ACCEPTED_FOREST_SHADER_SHA256: Array[String] = [FOREST_SHADER_SHA256, FOREST_PHOTO_SHADER_SHA256]
const SOFT_FULL := 10.0
const SOFT_ZERO := 16.0
const SOFT_CULL := 18.0
# Native species previously stopped casting at12m; smooth within that footprint.
# Keep the already accepted forest10to16 fade unchanged.
const NATIVE_SOFT_FULL := 8.0
const NATIVE_SOFT_ZERO := 12.0
# Measured dense-route positive demand254 exceeded192. Keep bounded headroom
# and local native overflow for exceptional visits, without global fade loss.
const MAX_POOL := 384
var host: Node3D
var soft_allowed := false
var soft_active := false
var thinning_active := false
var soft_failed := false
var soft_failure_reason := ""
var soft_material: ShaderMaterial
var opaque_soft_material: ShaderMaterial
var forest_fade_count := 0
var opaque_fade_count := 0
var opaque_materials: Array[StandardMaterial3D] = []
var native_shadow_materials: Dictionary = {}
# Small, synchronous-pass cache; every native material is fully polled again
# before validation. Never rely on Resource.changed for builtin setter coverage.
var native_material_validation: Dictionary = {}
var native_coverage_signatures: Dictionary = {}
## Shadow shader code -> its one Shader (see _sync_native_shadow_material).
var _shadow_shaders: Dictionary = {}
var native_validation_max := 0
var native_coverage_refreshes := 0
var native_material_poll_passes := 0
var shadow_camera_updates := 0
var last_shadow_camera := Vector3.INF
var native_cutout_count := 0
var native_opaque_count := 0
var eligible: Array[int] = []
var fade_eligible_count := 0
var mutation_depth := 0
var recapture_pending := false
var visibility_sources: Array[MultiMeshInstance3D] = []
var thinned: Dictionary = {}
var pool: Array[MultiMeshInstance3D] = []
var available: Array[MultiMeshInstance3D] = []
var pool_active: Dictionary = {}
var overflow_native: Dictionary = {}
var demand_peak := 0
var overflow_peak := 0
var source_shader: Shader
var max_pool_size := 0
const CELL:=8.0
const ON_DISTANCE:=10.0
const OFF_DISTANCE:=12.0
var rows: Array=[]
var grid: Dictionary={}
var active: Dictionary={}
var camera: Camera3D
var enabled:=false
var last_position:=Vector3.INF
var maximum_extent:=0.0
var updates:=0
var max_update_us:=0

static func _forest_shader_accepted(shader: Shader) -> bool:
	# Both reviewed shaders preserve the exact opaque ribbon silhouette.
	# Every existing mesh, range, coverage and pool guard still applies below.
	return shader != null and shader.code.replace("\r\n","\n").sha256_text() in ACCEPTED_FOREST_SHADER_SHA256

func install(park: Node3D) -> Dictionary:
	# Preserve existing rows/native policy if recapture prerequisites are absent.
	if park.get_node_or_null("MidoriDistanceDetail")==null or park.get_viewport().get_camera_3d()==null:return {"error":"Recapture prerequisites unavailable"}
	native_material_validation.clear();native_coverage_signatures.clear()
	last_shadow_camera=Vector3.INF
	_disconnect_opaque_materials()
	for source: MultiMeshInstance3D in visibility_sources:
		if is_instance_valid(source) and source.visibility_changed.is_connected(_on_source_visibility):source.visibility_changed.disconnect(_on_source_visibility)
	visibility_sources.clear()
	if not rows.is_empty():apply(false)
	if is_instance_valid(source_shader) and source_shader.changed.is_connected(_invalidate_soft):source_shader.changed.disconnect(_invalidate_soft)
	rows.clear();grid.clear();active.clear();eligible.clear();thinned.clear()
	maximum_extent=0.0;fade_eligible_count=0;forest_fade_count=0;opaque_fade_count=0;native_cutout_count=0;native_opaque_count=0;native_shadow_materials.clear();source_shader=null;soft_allowed=false;soft_failed=false;soft_failure_reason=""
	host=park
	var shader_eligibility: Dictionary={}
	var forest_meshes: Dictionary={}
	var thin_fingerprints: Dictionary={}
	var mesh_fingerprints: Dictionary={}
	# Digest headers of the prototype meshes (see _mesh_header).
	var prototype_headers: Dictionary={}
	var species_counts: Dictionary={}
	var selected_species: Dictionary={}
	for original: MultiMeshInstance3D in park.find_children("JapaneseForestGrassDrift_*","MultiMeshInstance3D",true,false):
		if original.multimesh!=null and original.multimesh.mesh!=null and original.visibility_range_begin==0.0 and original.visibility_range_end==18.0 and original.visibility_range_fade_mode==GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF:
			var material: ShaderMaterial=original.material_override as ShaderMaterial
			# One shader-code digest per shader (thousands of drifts share a few).
			if material!=null and material.shader!=null:
				var drift_shader_id: int=material.shader.get_instance_id()
				if not shader_eligibility.has(drift_shader_id):shader_eligibility[drift_shader_id]=_forest_shader_accepted(material.shader)
				if shader_eligibility[drift_shader_id]:forest_meshes[original.multimesh.mesh.get_instance_id()]=true
	# Exact mesh resources of the supplied fern/fountain prototypes, not material names.
	for property: String in ["midnight_fern_prototype","emerald_fountain_grass_prototype"]:
		var prototype: Node=park.get(property)
		if is_instance_valid(prototype):
			for part: MeshInstance3D in prototype.find_children("*","MeshInstance3D",true,false):
				if part.mesh!=null:
					var fingerprint: String=_mesh_geometry_fingerprint(part.mesh)
					var materials: Array[Material]=[]
					for surface: int in part.mesh.get_surface_count():materials.append(part.get_active_material(surface))
					if thin_fingerprints.has(fingerprint) and (thin_fingerprints[fingerprint].species!=property or thin_fingerprints[fingerprint].materials!=materials):
						thin_fingerprints[fingerprint].ambiguous=true
					elif not thin_fingerprints.has(fingerprint):thin_fingerprints[fingerprint]={"species":property,"materials":materials,"ambiguous":false}
					mesh_fingerprints[part.mesh.get_instance_id()]=fingerprint
					if part.mesh is ArrayMesh:prototype_headers[_mesh_header(part.mesh)]=true
	var container:=park.get_node_or_null("MidoriDistanceDetail")
	if container==null: return {"error":"Requires reviewed spatial planting candidate"}
	camera=park.get_viewport().get_camera_3d()
	if camera==null: return {"error":"Missing main camera"}
	opaque_soft_material=ShaderMaterial.new();opaque_soft_material.shader=OpaqueShadowShader
	opaque_soft_material.set_shader_parameter("cutout_enabled",false)
	opaque_soft_material.set_shader_parameter("midori_sc_fade_distances",Vector2(NATIVE_SOFT_FULL,NATIVE_SOFT_ZERO))
	var retained:=0
	for geometry in container.get_children():
		if not geometry is MultiMeshInstance3D or not geometry.is_visible_in_tree() or geometry.multimesh==null: continue
		if geometry.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: continue
		if not str(geometry.name).begins_with("grass_Cell_") and not str(geometry.name).begins_with("flowers_Cell_") and not str(geometry.name).begins_with("other_planting_Cell_"): continue
		var bounds: AABB=geometry.global_transform*geometry.multimesh.get_aabb()
		var extent:=maxf(bounds.size.x,bounds.size.z)*0.5
		if extent>8.0: retained+=1;continue
		maximum_extent=maxf(maximum_extent,extent)
		var center:=bounds.get_center()
		var key:=Vector2i(floori(center.x/CELL),floori(center.z/CELL))
		if not grid.has(key): grid[key]=[]
		grid[key].append(rows.size())
		var soft := false
		var material: ShaderMaterial=geometry.material_override as ShaderMaterial
		if material!=null and material.shader!=null and material.next_pass==null and geometry.material_overlay==null and geometry.transparency==0.0 and geometry.get_script()==null and geometry.visibility_range_begin==0.0 and geometry.multimesh.mesh.get_surface_count()==1 and bounds.size.y<=1.5:
			var shader_id: int=material.shader.get_instance_id()
			if not shader_eligibility.has(shader_id):shader_eligibility[shader_id]=_forest_shader_accepted(material.shader)
			soft=shader_eligibility[shader_id] and forest_meshes.has(geometry.multimesh.mesh.get_instance_id()) and str(geometry.name).begins_with("grass_Cell_") and geometry.visibility_range_end==18.0 and geometry.visibility_range_end_margin==2.0 and geometry.visibility_range_fade_mode==GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF and geometry.visibility_parent==NodePath() and not geometry.top_level and (not geometry.multimesh.mesh is ArrayMesh or geometry.multimesh.mesh.shadow_mesh==null)
			if soft:source_shader=material.shader
		var mesh_id: int=geometry.multimesh.mesh.get_instance_id()
		if not soft and not mesh_fingerprints.has(mesh_id):
			# The digest starts with this header: a mesh whose header no supplied
			# prototype has can never match one, so its full surface read-back
			# (a GPU download per mesh) is skipped; it stays unmatched as before.
			var candidate: Mesh=geometry.multimesh.mesh
			if candidate is ArrayMesh and candidate.shadow_mesh!=candidate and not prototype_headers.has(_mesh_header(candidate)):
				mesh_fingerprints[mesh_id]="unmatched:%d"%mesh_id
			else:mesh_fingerprints[mesh_id]=_mesh_geometry_fingerprint(candidate)
		var trusted: Dictionary=thin_fingerprints.get(mesh_fingerprints.get(mesh_id,""),{})
		var materials_match: bool=not trusted.is_empty() and not trusted.ambiguous
		if materials_match:
			for surface: int in geometry.multimesh.mesh.get_surface_count():
				var effective: Material=geometry.material_override if geometry.material_override!=null else geometry.multimesh.mesh.surface_get_material(surface)
				if effective!=trusted.materials[surface]:materials_match=false;break
		var species: String="forest_grass" if soft else (str(trusted.species) if materials_match else "")
		var thin_eligible: bool=soft or (not species.is_empty() and geometry.visibility_range_begin==0.0 and geometry.get_script()==null and geometry.material_overlay==null and geometry.transparency==0.0)
		if thin_eligible:
			if not species_counts.has(species):species_counts[species]={"chunks":0,"instances":0}
			species_counts[species].chunks+=1;species_counts[species].instances+=geometry.multimesh.instance_count
		if thin_eligible:eligible.append(rows.size())
		var soft_kind: String="forest" if soft else ""
		var native_materials: Array[Material]=_source_materials(geometry)
		var native_shadow: ShaderMaterial
		if not soft and _native_source_compatible(geometry,native_materials):
			soft=true;soft_kind="native_coverage"
			if native_materials.size()==1:
				var original: StandardMaterial3D=native_materials[0]
				var material_key: int=original.get_instance_id()
				if not native_shadow_materials.has(material_key):
					var shadow:=ShaderMaterial.new()
					_sync_native_shadow_material(original,shadow)
					native_shadow_materials[material_key]=shadow
				native_shadow=native_shadow_materials[material_key]
				if original.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:native_cutout_count+=1
				else:native_opaque_count+=1
			else:
				native_shadow=opaque_soft_material
				native_opaque_count+=1
			for original: StandardMaterial3D in native_materials:
				if not opaque_materials.has(original):
					opaque_materials.append(original)
					if not original.changed.is_connected(_on_opaque_material_changed):original.changed.connect(_on_opaque_material_changed)
		if soft_kind=="forest":forest_fade_count+=1
		elif soft_kind=="native_coverage":opaque_fade_count+=1
		if soft:
			fade_eligible_count+=1
			visibility_sources.append(geometry)
			if not geometry.visibility_changed.is_connected(_on_source_visibility):geometry.visibility_changed.connect(_on_source_visibility)
		var row: Dictionary={"node":geometry,"shadow":geometry.cast_shadow,"bounds":bounds,"soft":soft,"soft_kind":soft_kind,"material":material if soft_kind=="forest" else null,"native_materials":native_materials,"native_shadow":native_shadow,"thin_eligible":thin_eligible,"species":species,"rank":str(park.get_path_to(geometry)).sha256_text()}
		if soft:
			row["mm"]=geometry.multimesh;row["mesh"]=geometry.multimesh.mesh;row["transform"]=geometry.global_transform
			row["range_begin"]=geometry.visibility_range_begin;row["range_end"]=geometry.visibility_range_end
			row["range_begin_margin"]=geometry.visibility_range_begin_margin;row["range_margin"]=geometry.visibility_range_end_margin;row["range_fade"]=geometry.visibility_range_fade_mode
			row["shadow_mesh"]=geometry.multimesh.mesh.shadow_mesh if geometry.multimesh.mesh is ArrayMesh else null
			row["layers"]=geometry.layers;row["lod"]=geometry.lod_bias;row["custom_aabb"]=geometry.custom_aabb;row["extra_cull"]=geometry.extra_cull_margin;row["occlusion"]=geometry.ignore_occlusion_culling
		rows.append(row)
	eligible.sort_custom(func(a: int,b: int) -> bool:return rows[a].rank<rows[b].rank)
	for index: int in eligible.slice(0,int(eligible.size()*.25)):
		thinned[index]=true
		var species: String=rows[index].species
		if not selected_species.has(species):selected_species[species]={"chunks":0,"instances":0}
		selected_species[species].chunks+=1;selected_species[species].instances+=rows[index].node.multimesh.instance_count
	soft_allowed=fade_eligible_count>0
	if soft_allowed:
		soft_material=ShaderMaterial.new();soft_material.shader=ShadowShader
		soft_material.set_shader_parameter("midori_sc_fade_distances",Vector2(SOFT_FULL,SOFT_ZERO))

		if is_instance_valid(source_shader) and not source_shader.changed.is_connected(_invalidate_soft):source_shader.changed.connect(_invalidate_soft)
	if get_parent()==null:park.add_child(self)
	process_priority=220
	return {"qa_only":false,"species_counts":species_counts,"selected_species":selected_species,"unique_geometry_fingerprints":mesh_fingerprints.size(),"caster_chunks":rows.size(),"large_chunks_retained":retained,"activate_m":ON_DISTANCE,"deactivate_m":OFF_DISTANCE,"near_shadow_trade":"Same25% eligible caster chunks remain shadowless in Balanced; supported forest shadows full through10m then fade to16m; native opaque/scissor full through8m then fade to original12m maximum","thinning_eligible_chunks":eligible.size(),"true_fade_forest_chunks":forest_fade_count,"true_fade_native_coverage_chunks":opaque_fade_count,"native_cutout_chunks":native_cutout_count,"native_opaque_chunks":native_opaque_count,"native_material_variants":native_shadow_materials.size(),"native_material_poll_passes":native_material_poll_passes,"shadow_camera_updates":shadow_camera_updates,"native_validation_max":native_validation_max,"native_coverage_refreshes":native_coverage_refreshes,"true_fade_total_chunks":fade_eligible_count,"shadowless_chunks":thinned.size(),"scope":"thinning only exact forest/fern/fountain; separate faithful supported native coverage fades retain main geometry/materials and iris/woody density"}

static func _source_materials(source: MultiMeshInstance3D) -> Array[Material]:
	var result: Array[Material]=[]
	for surface: int in source.multimesh.mesh.get_surface_count():result.append(source.material_override if source.material_override!=null else source.multimesh.mesh.surface_get_material(surface))
	return result

static func _native_material_compatible(material: StandardMaterial3D) -> bool:
	# Only understood coverage and vertex modes. Opaque ignores texture alpha;
	# scissor reproduces native alpha exactly before the independent distance fade.
	return is_instance_valid(material) and material.next_pass==null and material.transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED,BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR] and material.alpha_antialiasing_mode in [BaseMaterial3D.ALPHA_ANTIALIASING_OFF,BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE] and material.cull_mode==BaseMaterial3D.CULL_DISABLED and material.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and not material.grow and not material.fixed_size and not material.use_point_size and not material.use_particle_trails and not material.use_fov_override and not material.use_z_clip_scale and not material.no_depth_test and material.depth_test==0 and material.blend_mode==BaseMaterial3D.BLEND_MODE_MIX and material.depth_draw_mode==BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY and not material.proximity_fade_enabled and material.distance_fade_mode==BaseMaterial3D.DISTANCE_FADE_DISABLED and not material.uv1_triplanar and not material.heightmap_enabled and not material.albedo_texture_msdf and not material.refraction_enabled and not material.shadow_to_opacity and material.stencil_mode==0 and material.texture_filter>=0 and material.texture_filter<=5

static func _native_source_compatible(source: MultiMeshInstance3D, materials: Array[Material]) -> bool:
	var mesh: ArrayMesh=source.multimesh.mesh as ArrayMesh
	if mesh==null:return false
	if source.get_script()!=null or source.material_overlay!=null or source.transparency!=0.0 or source.visibility_parent!=NodePath() or source.top_level or mesh.get_blend_shape_count()!=0:return false
	if materials.is_empty():return false
	for surface: int in materials.size():
		var native: StandardMaterial3D=materials[surface] as StandardMaterial3D
		if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES or not _native_material_compatible(native):return false
		# One override cannot reproduce several different cutout textures. Several
		# opaque surfaces have identical full coverage, so their geometry is safe.
		if materials.size()>1 and native.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:return false
	return true

func _sync_native_shadow_material(original: StandardMaterial3D, shadow: ShaderMaterial) -> void:
	# A changed shader/material must receive the current camera even at rest.
	last_shadow_camera=Vector3.INF
	var filters: Array[String]=["filter_nearest","filter_linear","filter_nearest_mipmap","filter_linear_mipmap","filter_nearest_mipmap_anisotropic","filter_linear_mipmap_anisotropic"]
	var code: String=OpaqueShadowShader.code.replace("filter_linear_mipmap, repeat_enable",filters[original.texture_filter]+", "+("repeat_enable" if original.texture_repeat else "repeat_disable"))
	if shadow.shader==null or shadow.shader.code!=code:
		# Materials whose shadow code is identical share one Shader: each new one
		# compiled the same code again (16 compiles, ~1.2 s of the one frame this
		# install runs in). A cached Shader's code is never changed; a material
		# that needs other code takes (or makes) the Shader for that code.
		var shader: Shader=_shadow_shaders.get(code)
		if shader==null:
			shader=Shader.new();shader.code=code
			_shadow_shaders[code]=shader
		shadow.shader=shader
	shadow.set_shader_parameter("cutout_enabled",original.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
	shadow.set_shader_parameter("texture_albedo",original.albedo_texture)
	shadow.set_shader_parameter("albedo_alpha",original.albedo_color.a)
	shadow.set_shader_parameter("use_vertex_alpha",original.vertex_color_use_as_albedo)
	shadow.set_shader_parameter("alpha_threshold",original.alpha_scissor_threshold)
	shadow.set_shader_parameter("uv_scale",Vector2(original.uv1_scale.x,original.uv1_scale.y))
	shadow.set_shader_parameter("uv_offset",Vector2(original.uv1_offset.x,original.uv1_offset.y))
	shadow.set_shader_parameter("midori_sc_fade_distances",Vector2(NATIVE_SOFT_FULL,NATIVE_SOFT_ZERO))
	native_coverage_signatures[original.get_instance_id()]=_native_coverage_signature(original)

static func _native_coverage_signature(original: StandardMaterial3D) -> Array:
	# Builtin alpha/UV setters need not emit changed. Poll these once per shared
	# material; the shadow samples the original texture resource directly.
	return [original.transparency,original.albedo_color.a,original.albedo_texture,original.vertex_color_use_as_albedo,original.uv1_scale,original.uv1_offset,original.texture_filter,original.texture_repeat,original.alpha_scissor_threshold]

func _poll_native_materials() -> bool:
	native_material_poll_passes+=1
	# No yields or retained validity across passes. Full compatibility remains
	# checked even for currently inactive shared materials, at most once each.
	native_material_validation.clear()
	for original: StandardMaterial3D in opaque_materials:
		if not _native_material_compatible(original):return false
		var id: int=original.get_instance_id()
		native_material_validation[id]=true
		var signature: Array=_native_coverage_signature(original)
		if native_coverage_signatures.get(id,[])!=signature:
			if native_shadow_materials.has(id):_sync_native_shadow_material(original,native_shadow_materials[id])
			else:native_coverage_signatures[id]=signature
			native_coverage_refreshes+=1
	native_validation_max=maxi(native_validation_max,native_material_validation.size())
	return true

func _native_row_matches(source: MultiMeshInstance3D, expected: Array) -> bool:
	# Source/mesh identities and structural guards are never cached. Avoid making
	# a fresh material array for every carrier, every frame.
	var mesh: ArrayMesh=source.multimesh.mesh as ArrayMesh
	if mesh==null or source.get_script()!=null or mesh.get_blend_shape_count()!=0:return false
	var surfaces: int=mesh.get_surface_count()
	if surfaces==0 or surfaces!=expected.size():return false
	for surface: int in surfaces:
		if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:return false
		var effective: Material=source.material_override if source.material_override!=null else mesh.surface_get_material(surface)
		if not is_instance_valid(effective) or effective!=expected[surface]:return false
		if not native_material_validation.get(effective.get_instance_id(),false):return false
		# General material admission permits scissor for single-surface sources;
		# several different surfaces still require fully opaque native coverage.
		if surfaces>1 and effective.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:return false
	return true

func _set_shadow_camera(position: Vector3) -> void:
	if position==last_shadow_camera:return
	last_shadow_camera=position;shadow_camera_updates+=1
	soft_material.set_shader_parameter("midori_sc_main_camera",position)
	opaque_soft_material.set_shader_parameter("midori_sc_main_camera",position)
	for material: ShaderMaterial in native_shadow_materials.values():material.set_shader_parameter("midori_sc_main_camera",position)

func _disconnect_opaque_materials() -> void:
	for material: StandardMaterial3D in opaque_materials:
		if is_instance_valid(material) and material.changed.is_connected(_on_opaque_material_changed):material.changed.disconnect(_on_opaque_material_changed)
	opaque_materials.clear()

func _on_opaque_material_changed() -> void:
	native_material_validation.clear()
	for material: StandardMaterial3D in opaque_materials:
		if not _native_material_compatible(material):_invalidate_soft();return
		if native_shadow_materials.has(material.get_instance_id()):_sync_native_shadow_material(material,native_shadow_materials[material.get_instance_id()])

## The first block _mesh_geometry_fingerprint hashes (cheap: no surface data).
static func _mesh_header(mesh: ArrayMesh) -> PackedByteArray:
	return var_to_bytes([mesh.get_surface_count(),mesh.get_blend_shape_count(),mesh.get_aabb(),mesh.custom_aabb,mesh.blend_shape_mode])

static func _mesh_geometry_fingerprint(mesh: Mesh, include_shadow: bool = true) -> String:
	# Native producers copy geometry before assigning effective surface materials.
	# Hash each unique resource once during capture, including every native surface
	# buffer, LOD and blend-shape field; material identity is checked separately.
	if not mesh is ArrayMesh:return ""
	var digest:=HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(_mesh_header(mesh))
	for shape: int in mesh.get_blend_shape_count():digest.update(var_to_bytes(mesh.get_blend_shape_name(shape)))
	for surface: int in mesh.get_surface_count():
		var data: Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),surface)
		data.erase("material")
		var keys: Array=data.keys();keys.sort()
		for field: String in keys:digest.update(var_to_bytes([field,data[field]]))
	if include_shadow:
		if mesh.shadow_mesh==mesh:return ""
		digest.update(var_to_bytes(_mesh_geometry_fingerprint(mesh.shadow_mesh,false) if mesh.shadow_mesh!=null else "no_shadow_mesh"))
	return digest.finish().hex_encode()

static func distance_sq(bounds: AABB, point: Vector3) -> float:
	var nearest:=Vector2(clampf(point.x,bounds.position.x,bounds.end.x),clampf(point.z,bounds.position.z,bounds.end.z))
	return nearest.distance_squared_to(Vector2(point.x,point.z))

func apply(use_budget: bool) -> void:
	_release_all()
	enabled=use_budget
	thinning_active=enabled and is_instance_valid(host) and not bool(host.get("high_render_quality"))
	soft_active=enabled and mutation_depth==0 and not recapture_pending and soft_allowed and not soft_failed and is_instance_valid(camera) and is_instance_valid(host) and not bool(host.get("high_render_quality"))
	active.clear();overflow_native.clear()
	for row: Dictionary in rows:
		if not is_instance_valid(row.node): continue
		row.node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if enabled else row.shadow
	last_position=Vector3.INF
	if enabled: update_near()

func update_near() -> void:
	if not enabled or not is_instance_valid(camera): return
	var started:=Time.get_ticks_usec()
	var position:=camera.global_position
	# Reconcile exclusive proxy/native ownership before native acquisition.
	if soft_active:_update_soft(position)
	for index: int in active.keys():
		if not is_instance_valid(rows[index].node):active.erase(index);continue
		if distance_sq(rows[index].bounds,position)>OFF_DISTANCE*OFF_DISTANCE:
			rows[index].node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			active.erase(index)
	var key:=Vector2i(floori(position.x/CELL),floori(position.z/CELL))
	var reach:=ceili((ON_DISTANCE+maximum_extent)/CELL)
	for x in range(key.x-reach,key.x+reach+1):
		for z in range(key.y-reach,key.y+reach+1):
			for index: int in grid.get(Vector2i(x,z),[]):
				if not is_instance_valid(rows[index].node):continue
				if thinning_active and thinned.has(index):continue
				if soft_active and pool_active.has(index):continue
				if not active.has(index) and distance_sq(rows[index].bounds,position)<=ON_DISTANCE*ON_DISTANCE:
					rows[index].node.cast_shadow=rows[index].shadow
					active[index]=true
	last_position=position
	updates+=1;max_update_us=maxi(max_update_us,Time.get_ticks_usec()-started)

func _process(_delta: float) -> void:
	# A camera switch or camera-free frame is temporary, not an asset mismatch.
	var current:=get_viewport().get_camera_3d()
	if current!=camera:
		camera=current;last_position=Vector3.INF
	var updates_before: int=updates
	if recapture_pending and mutation_depth==0 and is_instance_valid(host) and host.get_viewport().get_camera_3d()!=null:_recapture_after_writer()
	var desired_soft: bool=enabled and mutation_depth==0 and not recapture_pending and soft_allowed and not soft_failed and is_instance_valid(camera) and is_instance_valid(host) and not bool(host.get("high_render_quality"))
	var desired_thinning: bool=enabled and is_instance_valid(host) and not bool(host.get("high_render_quality"))
	if desired_soft!=soft_active or desired_thinning!=thinning_active:
		apply(enabled)
		return
	# Recapture and movement already validate all owned sources synchronously.
	# Do not repeat that same full pass in this process callback.
	if updates!=updates_before:return
	if enabled and is_instance_valid(camera) and camera.global_position.distance_squared_to(last_position)>.25:
		update_near()
		return
	if soft_active:
		if forest_fade_count>0 and not is_instance_valid(source_shader):_invalidate_soft()
		elif not _poll_native_materials():_invalidate_soft()
		else:
			_set_shadow_camera(camera.global_position)
			for index: int in pool_active.keys():
				if not _valid_soft_source(index):_invalidate_soft();break
				var source: MultiMeshInstance3D=rows[index].node
				if not source.is_visible_in_tree():_release(index)

func restore() -> bool:
	apply(false)
	for row: Dictionary in rows:
		if not is_instance_valid(row.node) or row.node.cast_shadow!=row.shadow: return false
	return true

func _exit_tree() -> void:
	_disconnect_opaque_materials()
	for source: MultiMeshInstance3D in visibility_sources:
		if is_instance_valid(source) and source.visibility_changed.is_connected(_on_source_visibility):source.visibility_changed.disconnect(_on_source_visibility)
	visibility_sources.clear()
	if is_instance_valid(source_shader) and source_shader.changed.is_connected(_invalidate_soft):source_shader.changed.disconnect(_invalidate_soft)
	apply(false)


func _valid_soft_source(index: int) -> bool:
	var row: Dictionary=rows[index]
	if not is_instance_valid(row.node):return false
	var source: MultiMeshInstance3D=row.node
	if not source.is_inside_tree() or source.multimesh!=row.mm or source.multimesh.mesh!=row.mesh:return false
	if source.material_overlay!=null or source.transparency!=0.0:return false
	if row.soft_kind=="forest":
		var material: ShaderMaterial=source.material_override as ShaderMaterial
		if material!=row.material or material==null or material.shader!=source_shader or material.next_pass!=null:return false
	else:
		if not _native_row_matches(source,row.native_materials):return false
	if source.multimesh.mesh is ArrayMesh and source.multimesh.mesh.shadow_mesh!=row.shadow_mesh:return false
	return source.global_transform==row.transform and source.layers==row.layers and source.lod_bias==row.lod and source.custom_aabb==row.custom_aabb and source.extra_cull_margin==row.extra_cull and source.ignore_occlusion_culling==row.occlusion and source.visibility_range_begin==row.range_begin and source.visibility_range_end==row.range_end and source.visibility_range_begin_margin==row.range_begin_margin and source.visibility_range_end_margin==row.range_margin and source.visibility_range_fade_mode==row.range_fade and source.visibility_parent==NodePath() and not source.top_level and source.global_transform*source.multimesh.get_aabb()==row.bounds

func _on_source_visibility() -> void:
	last_position=Vector3.INF

func before_source_change() -> void:
	mutation_depth+=1
	if mutation_depth==1:
		# Suspend only the new fade. Keep original10/12 budget active while an
		# asynchronous writer yields; never restore all15k casters for that interval.
		apply(enabled)

func after_source_change() -> void:
	mutation_depth=maxi(0,mutation_depth-1)
	if mutation_depth==0:
		recapture_pending=true
		_recapture_after_writer()

func _recapture_after_writer() -> void:
	if not is_instance_valid(host) or not host.is_inside_tree() or host.is_queued_for_deletion():return
	if host.get_viewport().get_camera_3d()==null:return
	# Honor any restore/disable requested while the asynchronous writer yielded.
	# install() temporarily restores source modes synchronously before capture.
	var requested_policy: bool=enabled
	var result: Dictionary=install(host)
	if result.has("error"):return
	# Mode restoration and capture above are synchronous, with no rendered/yielding
	# all-caster interval. Publish policy only after successful fresh bounds.
	recapture_pending=false
	apply(requested_policy)

func _invalidate_soft(reason: String = "source_incompatible") -> void:
	# No source hash sweep per frame; a shader edit or active-source incompatibility
	# falls back synchronously to the original native budget. Visible materials stay.
	soft_failed=true;soft_failure_reason=reason
	apply(enabled)

func _release(index: int) -> void:
	var proxy: MultiMeshInstance3D=pool_active[index]
	proxy.hide();proxy.multimesh=null
	pool_active.erase(index);available.append(proxy)

func _release_all() -> void:
	for index: int in pool_active.keys():_release(index)
	for proxy: MultiMeshInstance3D in pool:
		proxy.hide();proxy.queue_free()
	pool.clear();available.clear()

func _soft_zero_squared(row: Dictionary) -> float:
	return NATIVE_SOFT_ZERO*NATIVE_SOFT_ZERO if row.soft_kind=="native_coverage" else SOFT_ZERO*SOFT_ZERO

func _update_soft(position: Vector3) -> void:
	if forest_fade_count>0 and not is_instance_valid(source_shader):_invalidate_soft();return
	if not _poll_native_materials():_invalidate_soft();return
	_set_shadow_camera(position)
	for index: int in pool_active.keys():
		if not _valid_soft_source(index):_invalidate_soft();return
		var source: MultiMeshInstance3D=rows[index].node
		if not source.is_visible_in_tree() or distance_sq(rows[index].bounds,position)>=_soft_zero_squared(rows[index]):_release(index)
	for index: int in overflow_native.keys():
		if not is_instance_valid(rows[index].node):
			active.erase(index);overflow_native.erase(index);continue
		var source: MultiMeshInstance3D=rows[index].node
		if not is_instance_valid(source) or not source.is_visible_in_tree() or distance_sq(rows[index].bounds,position)>SOFT_CULL*SOFT_CULL:
			if is_instance_valid(source):source.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			active.erase(index);overflow_native.erase(index)
	var needed: Array[int]=[]
	var positive_demand := 0
	var key:=Vector2i(floori(position.x/CELL),floori(position.z/CELL))
	var reach:=ceili((SOFT_ZERO+maximum_extent)/CELL)
	for x: int in range(key.x-reach,key.x+reach+1):
		for z: int in range(key.y-reach,key.y+reach+1):
			for index: int in grid.get(Vector2i(x,z),[]):
				if not rows[index].soft or thinned.has(index):continue
				if not is_instance_valid(rows[index].node):_invalidate_soft();return
				var source: MultiMeshInstance3D=rows[index].node
				# Active carriers were fully checked above before any release. An
				# inactive candidate needs no proxy contract walk at zero coverage.
				if not source.is_visible_in_tree() or distance_sq(rows[index].bounds,position)>=_soft_zero_squared(rows[index]):continue
				if pool_active.has(index):positive_demand+=1;continue
				if not _valid_soft_source(index):_invalidate_soft();return
				positive_demand+=1
				if overflow_native.has(index):continue
				needed.append(index)
	demand_peak=maxi(demand_peak,positive_demand)
	needed.sort_custom(func(a: int,b: int) -> bool:
		var da: float=distance_sq(rows[a].bounds,position)
		var db: float=distance_sq(rows[b].bounds,position)
		return rows[a].rank<rows[b].rank if is_equal_approx(da,db) else da<db)
	for index: int in needed:
		# Stable per-visit native fallback avoids promoting an ON chunk to a weak
		# dither merely because a slot becomes available. Never disable all fades.
		if pool_active.has(index) or overflow_native.has(index):continue
		var source: MultiMeshInstance3D=rows[index].node
		var proxy: MultiMeshInstance3D
		if not available.is_empty():proxy=available.pop_back()
		elif pool.size()<MAX_POOL:
			proxy=MultiMeshInstance3D.new();proxy.name="PooledPlantShadow"
			proxy.visible=false;add_child(proxy);proxy.top_level=true
			proxy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			proxy.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
			pool.append(proxy);max_pool_size=maxi(max_pool_size,pool.size())
		else:
			overflow_native[index]=true;overflow_peak=maxi(overflow_peak,overflow_native.size());continue
		proxy.hide()
		proxy.material_override=rows[index].native_shadow if rows[index].soft_kind=="native_coverage" else soft_material
		proxy.multimesh=source.multimesh;proxy.global_transform=source.global_transform
		proxy.layers=source.layers;proxy.lod_bias=source.lod_bias
		proxy.custom_aabb=source.custom_aabb;proxy.extra_cull_margin=source.extra_cull_margin
		proxy.ignore_occlusion_culling=source.ignore_occlusion_culling
		proxy.visibility_range_begin=source.visibility_range_begin;proxy.visibility_range_end=source.visibility_range_end
		proxy.visibility_range_begin_margin=source.visibility_range_begin_margin;proxy.visibility_range_end_margin=source.visibility_range_end_margin
		proxy.visibility_range_fade_mode=source.visibility_range_fade_mode
		# Publish ownership synchronously; no frame can render both source/proxy.
		source.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		active.erase(index);overflow_native.erase(index);pool_active[index]=proxy;proxy.show()

func soft_report() -> Dictionary:
	var selected_instances:=0
	for index: int in thinned:
		if is_instance_valid(rows[index].node):selected_instances+=rows[index].node.multimesh.instance_count
	return {"soft_active":soft_active,"soft_failed":soft_failed,"fallback_reason":soft_failure_reason,"thinning_active":thinning_active,"eligible_chunks":eligible.size(),"fade_forest_chunks":forest_fade_count,"fade_native_coverage_chunks":opaque_fade_count,"native_cutout_chunks":native_cutout_count,"native_opaque_chunks":native_opaque_count,"native_material_variants":native_shadow_materials.size(),"native_material_poll_passes":native_material_poll_passes,"shadow_camera_updates":shadow_camera_updates,"native_validation_max":native_validation_max,"native_coverage_refreshes":native_coverage_refreshes,"fade_total_chunks":fade_eligible_count,"shadowless_chunks":thinned.size(),"selected_chunk_instances":selected_instances,"selection_unit":"25% of eligible forest/fern/fountain caster chunks; not individual plants/all casters; iris preserved","pool_size":pool.size(),"active_carriers":pool_active.size(),"maximum_pool":max_pool_size,"capacity_limit":MAX_POOL,"demand_peak":demand_peak,"native_overflow_current":overflow_native.size(),"native_overflow_peak":overflow_peak,"native_overflow_on":active.keys().filter(func(index: int) -> bool:return overflow_native.has(index)).size(),"full_m":SOFT_FULL,"zero_m":SOFT_ZERO,"native_full_m":NATIVE_SOFT_FULL,"native_zero_m":NATIVE_SOFT_ZERO,"cull_m":SOFT_CULL,"original_policy_m":[ON_DISTANCE,OFF_DISTANCE],"high_original_policy":true,"apply_false_restores_original_modes":true}
