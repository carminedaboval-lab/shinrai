extends RefCounted
## Local task/accent lighting with physically aimed fittings. No environment edits.

static func build(street: Node3D, gallery: Dictionary) -> Dictionary:
	var report := {"lights":[],"global_environment_changed":false,"existing_fixture_positions_preserved":true}
	# Keep gentle room fill, but stop omnidirectional practicals making ceilings
	# the brightest surfaces. New beams are carried by real ceiling fittings.
	for light: Light3D in street.get("light_members"):
		if str(light.name).begins_with("Interior") and str(light.name).ends_with("RegisteredPractical"):
			light.set_meta("street_night_energy",.30)
			light.set_meta("street_day_energy",.24)
		if str(light.name)=="ShopWorkingPendant" and light.get_parent().name=="MoriCoffee":
			light.set_meta("street_night_energy",.38)
			light.set_meta("street_day_energy",.30)
	var cafe := street.get_node("MoriCoffee") as Node3D
	for row: Array in [
		["MoriCounterTask",Vector3(2.48,2.35,4.8),Vector3(2.5,1.02,4.8),1.65,1.05,47.0,false],
		["MoriSeatingTask",Vector3(-2.5,2.35,3.6),Vector3(-2.5,.85,3.6),1.10,.80,63.0,false],
		["MoriMenuAccent",Vector3(0,2.72,6.30),Vector3(0,1.80,7.58),1.20,.90,42.0,true]
	]:
		report.lights.append(_beam(street,cafe,row,0))
	var room := gallery.get("interior_group") as Node3D
	if room!=null:
		for row: Array in [
			["HakuHeroAccent",Vector3(-2.65,2.75,3.55),Vector3(-2.70,.98,3.65),1.70,1.25,32.0,true],
			["HakuCompanionAccent",Vector3(2.65,2.75,3.55),Vector3(2.70,.85,3.65),1.10,.85,36.0,true],
			["HakuArtAccent",Vector3(-2.9,2.75,7.55),Vector3(-2.9,1.70,9.42),1.60,1.20,35.0,true],
			["HakuGlazeStudyTask",Vector3(2.55,2.75,8.45),Vector3(2.80,.94,8.75),1.30,.95,52.0,true]
		]:
			report.lights.append(_beam(street,room,row,1<<11))
	return report

static func _beam(street: Node3D,parent: Node3D,row: Array,mask: int) -> Dictionary:
	var id := String(row[0])
	var point: Vector3=row[1]
	var target: Vector3=row[2]
	var light := SpotLight3D.new()
	light.name=id
	light.position=point
	light.light_color=Color("#ffe6c7")
	light.light_energy=float(row[3])
	light.spot_range=4.5
	light.spot_angle=float(row[5])
	light.spot_attenuation=1.2
	light.spot_angle_attenuation=1.0
	light.shadow_enabled=false
	if mask!=0: light.light_cull_mask=mask
	light.set_meta("street_night_energy",float(row[3]))
	light.set_meta("street_day_energy",float(row[4]))
	parent.add_child(light)
	var direction := (target-point).normalized()
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP))>.98 else Vector3.UP
	light.look_at(parent.to_global(target),up)
	street.get("light_members").append(light)
	if bool(row[6]):
		var fittings := Node3D.new()
		fittings.name="Interior"+id+"CeilingFitting"
		parent.add_child(fittings)
		street.call("_box",fittings,"CeilingAnchor",Vector3(point.x,2.945,point.z),Vector3(.20,.055,.12),"arch_metal",false)
		var stem_height := maxf(.04,2.9175-point.y)
		street.call("_box",fittings,"SwivelStem",Vector3(point.x,point.y+stem_height*.5,point.z),Vector3(.025,stem_height,.025),"arch_metal",false)
		var pivot := Node3D.new()
		pivot.name="AimedLampHead"
		pivot.transform=light.transform
		fittings.add_child(pivot)
		var body := MeshInstance3D.new()
		body.name="TrackSpotHousing"
		var cylinder := CylinderMesh.new()
		cylinder.top_radius=.052
		cylinder.bottom_radius=.052
		cylinder.height=.145
		cylinder.radial_segments=16
		body.mesh=cylinder
		body.rotation.x=PI*.5
		body.position.z=-.045
		body.material_override=street.get("materials")["arch_metal"]
		pivot.add_child(body)
		var lens := MeshInstance3D.new()
		lens.name="RecessedTrackSpotLens"
		var disc := CylinderMesh.new()
		disc.top_radius=.040
		disc.bottom_radius=.040
		disc.height=.007
		disc.radial_segments=16
		lens.mesh=disc
		lens.rotation.x=PI*.5
		lens.position.z=-.119
		lens.material_override=street.get("materials")["warm"]
		pivot.add_child(lens)
	var data := {"id":id,"position":point,"target":target,"world_position":parent.to_global(point),"world_target":parent.to_global(target),"angle_degrees":float(row[5]),"night_energy":float(row[3]),"day_energy":float(row[4]),"visible_fitting":"new aimed ceiling track head" if bool(row[6]) else "existing pendant shade","mask":light.light_cull_mask,"light_node":str(light.get_path())}
	light.set_meta("display_task_light",data)
	return data
