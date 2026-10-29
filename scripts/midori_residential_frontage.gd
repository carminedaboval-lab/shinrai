extends RefCounted
## Small supported entrance identities for the five existing residential shells.
## Call after the neighbourhood/context builders and before street static batching.

static func build(street: Node3D, _context: Dictionary, _neighbourhood: Dictionary) -> Dictionary:
	var report := {"frontages":[],"planter_groups":[],"omitted":[],"lights_created":0,"collisions_created":0,"source_assets_modified":false,"global_environment_changed":false,"light_sync":"existing street light registry and midori_night_effect group","geometry_policy":"wall/soffit supported visual members only; original shells, doorbells, openings, collision and routes retained"}
	var specs: Array[Dictionary] = [
		{"path":"SouthNeighbourhoodBuildings/KobayashiHouse","number":"01","door":-2.25},
		{"path":"SouthNeighbourhoodBuildings/SugiCourtyardHouse","number":"02","door":2.25},
		{"path":"SouthNeighbourhoodBuildings/AokiHouse","number":"03","door":-2.25},
		{"path":"ConnectedNeighbourhoodContext/WestCornerWorkshopResidence","number":"04","door":-2.25},
		{"path":"ConnectedNeighbourhoodContext/EastGardenResidence","number":"05","door":-2.25}
	]
	for spec: Dictionary in specs:
		var house := street.get_node_or_null(String(spec.path)) as Node3D
		if house == null:
			report.omitted.append({"house":spec.path,"reason":"expected installed house root is absent"})
			continue
		if house.has_node("ResidentialEntranceIdentity"):
			report.omitted.append({"house":spec.path,"reason":"entrance identity already present; duplicate build skipped"})
			continue
		var frontage := _entrance(street,house,String(spec.number),float(spec.door))
		report.frontages.append(frontage)
		report.lights_created += 1
	street.set_meta("residential_frontage_finish",report)
	return report

static func _entrance(street: Node3D, house: Node3D, number: String, door_x: float) -> Dictionary:
	var root := Node3D.new()
	root.name = "ResidentialEntranceIdentity"
	root.set_meta("creator_protected",true)
	root.set_meta("creator_editable",false)
	house.add_child(root)
	var members: Array[Dictionary] = []
	# The masonry pier to the LEFT of every doorway is solid. Sugi's doorbell
	# occupies the right pier, so a mirrored plate would cover that original item.
	var plate_x := door_x-.94
	_part(street,root,"FlushMailPlateBody",Vector3(plate_x,1.30,-.035),Vector3(.36,.52,.075),"arch_metal",members)
	_part(street,root,"MailSlotRecess",Vector3(plate_x,1.31,-.075),Vector3(.265,.025,.008),"arch_shadow",members)
	_part(street,root,"MailSlotWeatherLip",Vector3(plate_x,1.332,-.085),Vector3(.285,.022,.027),"arch_metal",members)
	_part(street,root,"MailRetrievalPanel",Vector3(plate_x,1.148,-.076),Vector3(.302,.214,.009),"arch_metal",members)
	_part(street,root,"MailRetrievalLowerJoint",Vector3(plate_x,1.039,-.077),Vector3(.305,.008,.010),"arch_shadow",members)
	_part(street,root,"MailRetrievalPull",Vector3(plate_x+.102,1.15,-.090),Vector3(.018,.055,.020),"arch_metal",members)
	for side: float in [-1.0,1.0]:
		_part(street,root,"MailPlateCaptiveFixing",Vector3(plate_x+side*.137,1.514,-.077),Vector3(.013,.013,.010),"arch_stone",members)
	street.call("_text",root,"ResidentialNumber",number,Vector3(plate_x,1.443,-.081),.105,Color("#e4dfcf"))
	# The anchor touches the underside of the existing CanopySoffit at Y2.4375.
	# Body and diffuser are connected; no detached emissive point in the facade.
	_part(street,root,"PorchLampSoffitAnchor",Vector3(door_x,2.417,-.12),Vector3(.22,.042,.12),"arch_metal",members)
	_part(street,root,"PorchLampHousing",Vector3(door_x,2.360,-.12),Vector3(.35,.080,.19),"arch_metal",members)
	_part(street,root,"PorchLampRecessedDiffuser",Vector3(door_x,2.316,-.12),Vector3(.285,.012,.135),"warm",members)
	var light_point := Vector3(door_x,2.290,-.12)
	street.call("_omni",root,light_point,.60,2.85,0.0,Color("#ffe1b8"))
	var light := root.get_child(root.get_child_count()-1) as OmniLight3D
	light.name = "ResidentialPorchNightLight"
	var data := {"house":str(house.name),"root":str(root.get_path()),"number":number,"door_local_x":door_x,"house_transform":house.global_transform,"members":members,"mesh_members":members.size(),"label_members":1,"collision_members":0,"original_doorbell_preserved":true,"mail_mount_local":Vector3(plate_x,1.30,.0025),"mail_support":"original solid front masonry pier at local Z0; rear of plate overlaps by 2.5mm","lamp_support":"existing canopy soffit underside Y2.4375; anchor top Y2.438","lamp_world_position":root.to_global(light_point),"lamp_node":str(light.get_path()),"night_energy":.60,"day_energy":0.0,"range_m":2.85,"shadow_enabled":false,"registered":street.get("light_members").has(light),"night_group":light.is_in_group("midori_night_effect"),"existing_entrance_apron_width_m":1.50,"ground_members_added":0}
	root.set_meta("residential_frontage_construction",data)
	return data

static func _part(street: Node3D, root: Node3D, label: String, p: Vector3, size: Vector3, key: String, members: Array[Dictionary]) -> void:
	var visual := street.call("_box",root,label,p,size,key,false) as MeshInstance3D
	members.append({"id":label,"local_position":p,"size":size,"material":key,"world_bounds":visual.global_transform*visual.get_aabb()})

