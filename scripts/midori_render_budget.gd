extends RefCounted
## Complete secondary rendering preparation before HQ unlocks deployment.
const RESULT:=&"midori_render_budget"
static func install_before_hq(park: Node3D) -> Dictionary:
	if park.has_meta(RESULT): return park.get_meta(RESULT)
	var report: Dictionary={"status":"installed","native_main_resolution":true,"native_near_geometry":true}
	if not park.has_meta("midori_distance_detail"):
		return {"error":"Spatial planting is unavailable", "status":"native_fallback"}
	var reflection=preload("res://scripts/midori_reflection_content.gd").new()
	reflection.name="MidoriReflectionContent"
	report["reflection"]=reflection.install(park)
	if report.reflection.has("error"): reflection.free();report["error"]=report.reflection.error
	var shadows=preload("res://scripts/midori_near_plant_shadows.gd").new()
	shadows.name="MidoriNearPlantShadows"
	report["plant_shadows"]=shadows.install(park)
	if report.plant_shadows.has("error"): shadows.free();report["error"]=report.plant_shadows.error
	else: shadows.apply(true)
	report["draw_distance"]=await preload("res://scripts/midori_draw_distance.gd").apply(park)
	if not is_instance_valid(park): return {"status":"cancelled"}
	if RenderingServer.get_current_rendering_method()=="gl_compatibility":
		report["clouds"]={"status":"native_fallback","reason":"Compute rendering unavailable"}
	else:
		var cache=preload("res://scripts/midori_cloud_cache.gd").new()
		cache.name="MidoriCloudCache";park.add_child(cache)
		report["clouds"]=cache.install(park,512)
		if not report.clouds.has("error"):
			cache.apply(true)
			var tree:=park.get_tree()
			var deadline:=Time.get_ticks_msec()+30000
			while is_instance_valid(park) and is_instance_valid(cache) and not cache.cache_ready and cache.error.is_empty() and Time.get_ticks_msec()<deadline:
				await tree.process_frame
			if not is_instance_valid(park) or not is_instance_valid(cache): return {"status":"cancelled"}
		if report.clouds.has("error") or not cache.cache_ready:
			report["error"]="Cloud cache unavailable; original cloud material retained"
			cache.dispose();cache.queue_free()
		else: report.clouds["ready_before_hq"]=true
	if report.has("error"): report.status="partial_native_fallback"
	park.set_meta(RESULT,report)
	return report
