extends RefCounted
## Measured render-only construction details, inspired by the ONIBUS reference's
## folded metal weather edges, protected timber ends and supported counter.
## The reference photograph is analysis only; no photo pixels or branding are used.
const TARGETS := ["MoriCoffee","UedaBooks","YakitoriShop","KobayashiHouse","NishiTownhouse"]

static func build(street: Node3D) -> Dictionary:
	if street.has_meta("building_reference_details"): return street.get_meta("building_reference_details")
	var report := {"properties":[],"window_assemblies":0,"head_sheets":0,"drip_hems":0,"end_caps":0,"sill_trays":0,"counter_brackets":0,"plinth_joints":0,"timber_end_caps":0,"mesh_members":0,"colliders":0,"lights":0,"opening_clearance_unchanged":true,"reference":"ONIBUS Nakameguro official exterior photograph; analysis only"}
	for node: Node in street.find_children("*","Node3D",true,false):
		if not String(node.name) in TARGETS or not node.has_meta("building_access"): continue
		var house := node as Node3D
		if house.has_node("ReferenceConstructionDetails"): continue
		var group := Node3D.new()
		group.name = "ReferenceConstructionDetails"
		group.set_meta("creator_protected",true)
		group.set_meta("render_only",true)
		house.add_child(group)
		var metal := _metal(street,house)
		var stone := _stone(street,house)
		var windows: Array[Node] = house.find_children("*","StaticBody3D",true,false)
		for window: Node in windows:
			if window.get_meta("building_access_kind","") != "window": continue
			var pane := window as Node3D
			# Only the established front elevation. Side/rear orientations are skipped.
			var local_basis := house.global_basis.inverse()*pane.global_basis
			if local_basis.z.dot(Vector3.BACK)<.999: continue
			var centre := house.to_local(pane.global_position)
			var access: Dictionary = house.get_meta("building_access",{})
			var dimensions: Dictionary = access.get("dimensions",{})
			var front := float(dimensions.get("front_z_m",0.0))
			if absf(centre.z-(front+.34))>.04: continue
			var size: Vector3 = window.get("dimensions")
			var width := size.x+.16
			var top := centre.y+size.y*.5+.08
			var bottom := centre.y-size.y*.5-.08
			# Head sheet is entirely ABOVE the wall aperture. It bears into the
			# 80mm timber head and projects from the actual outer wall z=front.
			# All metal lower edges remain at least 25mm outside clear aperture.
			var span := width+.07
			_box(group,"FoldedWindowHeadSheet",Vector3(centre.x,top+.046,front-.026),Vector3(span,.008,.10),metal,report)
			report.head_sheets += 1
			_box(group,"TurnedDownHeadDripHem",Vector3(centre.x,top+.032,front-.074),Vector3(span,.028,.010),metal,report)
			report.drip_hems += 1
			for side: float in [-1.0,1.0]:
				_box(group,"HeadFlashingClosedEnd",Vector3(centre.x+side*(span*.5-.005),top+.047,front-.026),Vector3(.010,.030,.10),metal,report)
				report.end_caps += 1
			# Nishi already has a continuous supported upper visor: retain it,
			# while the tiny per-opening hems close its weathering construction.
			# Ground entry windows keep their existing finished sill and sweep.
			var entry := String(window.name).begins_with("GroundEntryWindow")
			if not entry:
				_box(group,"WindowSillWeatherTray",Vector3(centre.x,bottom-.022,front+.045),Vector3(span,.012,.19),metal,report)
				report.sill_trays += 1
				_box(group,"SillUndersideDrip",Vector3(centre.x,bottom-.039,front-.047),Vector3(span,.026,.009),metal,report)
				report.drip_hems += 1
				for side: float in [-1.0,1.0]:
					_box(group,"SillTrayStopEnd",Vector3(centre.x+side*(span*.5-.005),bottom-.012,front+.045),Vector3(.010,.030,.19),metal,report)
					report.end_caps += 1
			report.window_assemblies += 1
		# Joints are small recessed mortar-colour strips on EXISTING coping,
		# discovered by named physical mesh. They never form a new plinth
		# across a door. No invented grid is projected across an entire wall.
		for member: Node in house.find_children("*","MeshInstance3D",true,false):
			var visual := member as MeshInstance3D
			if visual.mesh == null: continue
			var label := String(visual.name)
			if label.begins_with("FrontPlinthCoping"):
				var b := visual.mesh.get_aabb()
				if b.size.x<.9: continue
				var mid := house.to_local(visual.to_global(b.get_center()))
				var count := int(floor(b.size.x/1.15))
				for i: int in range(1,count+1):
					var x := mid.x-b.size.x*.5+float(i)*b.size.x/float(count+1)
					_box(group,"CopingStoneButtJoint",Vector3(x,mid.y+b.size.y*.5+.0006,mid.z),Vector3(.006,.0012,b.size.z-.012),stone,report)
					report.plinth_joints += 1
			if String(house.name)=="YakitoriShop" and visual.get_meta("constructed_cladding",false):
				var b := visual.mesh.get_aabb()
				var mid := house.to_local(visual.to_global(b.get_center()))
				# Only broad front header/spandrel fields, not side walls, openings
				# or existing corner members. End trims close the real 20mm boards.
				if mid.z>.35 or mid.z<-.35 or b.size.x<1.5 or b.size.y>.85: continue
				for y: float in [b.position.y,b.end.y]:
					var p := house.to_local(visual.to_global(Vector3(b.get_center().x,y,b.position.z)))
					_box(group,"CladdingExposedEndMetalCap",p+Vector3(0,0,-.006),Vector3(b.size.x,.024,.032),metal,report)
					report.timber_end_caps += 1
		# Mori's existing projecting display sills get actual small support
		# brackets, never a new counter spanning the door or entry-window sweep.
		if String(house.name)=="MoriCoffee":
			for member: Node in house.find_children("ProjectingTimberDisplaySill*","MeshInstance3D",true,false):
				var sill := member as MeshInstance3D
				var b := sill.mesh.get_aabb()
				var mid := house.to_local(sill.to_global(b.get_center()))
				for side: float in [-1.0,1.0]:
					var x := mid.x+side*b.size.x*.30
					_box(group,"CounterBracketWallLeg",Vector3(x,mid.y-.10,.21),Vector3(.024,.18,.025),metal,report)
					_box(group,"CounterBracketBearing",Vector3(x,mid.y-.035,.155),Vector3(.024,.025,.13),metal,report)
					report.counter_brackets += 1
		report.properties.append(String(house.name))
		house.set_meta("reference_construction_details",{"members":group.get_child_count(),"render_only":true,"apertures_measured_from":"building_access window dimensions and front_z_m","reference_criteria":"folded weather edges with hems/endcaps; coping butt joints; protected timber ends; supported existing counter"})
	street.set_meta("building_reference_details",report)
	return report

static func _box(parent: Node3D,label: String,p: Vector3,size: Vector3,material: Material,report: Dictionary) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = p
	mesh.material_override = material
	mesh.set_meta("render_only",true)
	parent.add_child(mesh)
	report.mesh_members += 1

static func _metal(street: Node3D,house: Node3D) -> StandardMaterial3D:
	var mats: Dictionary = street.get("materials")
	var source: StandardMaterial3D = mats["arch_metal"]
	var result := source.duplicate() as StandardMaterial3D
	result.resource_name = String(house.name)+"_ReferenceFoldedMetal"
	result.roughness = .40
	result.metallic = .15
	return result

static func _stone(street: Node3D,house: Node3D) -> StandardMaterial3D:
	var mats: Dictionary = street.get("materials")
	var source: StandardMaterial3D = mats["arch_stone"]
	var result := source.duplicate() as StandardMaterial3D
	result.resource_name = String(house.name)+"_CopingButtMortar"
	result.albedo_texture = null
	result.normal_enabled = false
	result.albedo_color = Color("#77776a")
	result.roughness = .95
	return result
