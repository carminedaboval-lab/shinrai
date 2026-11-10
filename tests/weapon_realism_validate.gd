extends SceneTree

# Loads every catalogue weapon's real viewmodel under a camera (no park boot)
# and checks the contracts the rebuilt geometry must keep: fitted rig, moving
# parts, sockets, ADS sight alignment, fire/reload and bolt cycle presentation.
#   godot --path . --script res://tests/weapon_realism_validate.gd
const Catalog = preload("res://scripts/extraction_weapon_catalog.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, text: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + text)
	if not ok:
		failures.append(text)

func _run() -> void:
	var cam := Camera3D.new()
	cam.current = true
	root.add_child(cam)
	for key: String in Catalog.READY_WEAPONS:
		if key == "uzi":
			continue  # raw glTF; the player wraps it in uzi_viewmodel.gd (unchanged)
		var spec: Dictionary = Catalog.WEAPONS[key]
		var packed := load(spec.scene) as PackedScene
		if packed == null:
			_check(false, key + " scene loads")
			continue
		var vm := packed.instantiate()
		cam.add_child(vm)
		var deadline := Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < deadline and not (vm.get("loaded") and (vm.get("_fitted") if vm.get("_fitted") != null else true)) and not vm.get("failed"):
			await process_frame
		for frame: int in range(30):
			await process_frame
		_check(vm.get("failed") != true, key + " viewmodel loads without failure")
		_check(vm.get("loaded") == true, key + " viewmodel reports loaded")
		if vm.get("_fitted") != null:
			_check(vm.get("_fitted") == true, key + " assembly fitted to the supplied hands")
		var assembly := vm.get("assembly") as Node3D
		if assembly != null:
			for marker: String in ["GripRight", "GripLeft", "Muzzle", "IronRearSight", "IronFrontSight", "OpticSocket", "BoltRelease", "EjectionPort"]:
				_check(assembly.get_node_or_null(marker) is Node3D, key + " has marker " + marker)
			var muzzle: Vector3 = vm.get_muzzle_world_position()
			_check(cam.to_local(muzzle).z < -0.1, key + " muzzle sits in front of the camera")
			var mag := vm.get("magazine_mesh") as Node3D
			_check(mag != null, key + " magazine part resolved")
			var finish_count := 0
			for mesh: MeshInstance3D in assembly.find_children("*", "MeshInstance3D", true, false):
				for s in mesh.get_surface_override_material_count():
					var m := mesh.get_surface_override_material(s)
					if m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.resource_path.ends_with("weapon_real_finish.gdshader"):
						finish_count += 1
			if key != "uzi":
				_check(finish_count > 0, key + " uses the real-counterpart finishes (%d surfaces)" % finish_count)
		# ADS: settle fully aimed and confirm the iron sight line is centred.
		vm.set_ads_blend(1.0)
		for frame: int in range(90):
			await process_frame
		if vm.has_method("get_sight_world_points"):
			var pts: PackedVector3Array = vm.get_sight_world_points()
			if pts.size() == 2:
				var rear := cam.to_local(pts[0])
				var front := cam.to_local(pts[1])
				_check(front.z < rear.z and rear.z < 0.0, key + " sights in front of the eye, rear nearer (rear z %.3f front z %.3f)" % [rear.z, front.z])
				_check(Vector2(rear.x, rear.y).length() < 0.004 and Vector2(front.x, front.y).length() < 0.004, key + " sight line centred on screen (rear %.4f, front %.4f)" % [Vector2(rear.x, rear.y).length(), Vector2(front.x, front.y).length()])
		vm.set_ads_blend(0.0)
		for frame: int in range(20):
			await process_frame
		if vm.has_method("is_ready_for_input") and vm.is_ready_for_input():
			vm.play_fire()
			for frame: int in range(12):
				await process_frame
			_check(vm.get("failed") != true, key + " fires without failure")
			if vm.has_method("play_cycle"):
				vm.play_cycle(0.6)
				for frame: int in range(60):
					await process_frame
				_check(not vm.is_cycle_active(), key + " bolt cycle completes")
			vm.play_reload(true)
			# Give the reload 9 s of real time AND 900 frames: on a slow or paging machine
			# (or under --fixed-fps) real time alone runs out before the animation does.
			var t := Time.get_ticks_msec() + 9000
			var waited := 0
			while (Time.get_ticks_msec() < t or waited < 900) and not vm.is_ready_for_input():
				await process_frame
				waited += 1
			_check(vm.is_ready_for_input(), key + " empty reload completes")
		else:
			_check(false, key + " ready for input after equip")
		vm.queue_free()
		await process_frame
	print("WEAPON_REALISM_VALIDATE: ", failures.size(), " failures")
	for f: String in failures:
		print("  - ", f)
	quit(0 if failures.is_empty() else 1)
