extends RefCounted
## Original exterior colour schedules for Midori's existing homes and workshops.
## Runs after CourtFinishes, before batching. Each property owns its coatings;
## shared source materials, source maps, geometry and shallow room contents stay intact.
const WALL_SHADER = preload("res://scripts/midori_house_paint.gdshader")
const PROFILES := {
	"KobayashiHouse": {"name":"Warm chalk / chestnut", "body":"#d8d0bd", "lower":"#c1b49f", "trim":"#665e50", "timber":"#978064", "door":"#816348", "metal":"#434c48", "line":3.30},
	"SugiCourtyardHouse": {"name":"Celadon / deep sage", "body":"#b6c1ad", "lower":"#788d7c", "trim":"#4e6358", "timber":"#9b8866", "door":"#8d734e", "metal":"#42544d", "line":3.30},
	"AokiHouse": {"name":"Blush earth / smoked cedar", "body":"#c9afa0", "lower":"#b49987", "trim":"#6e5e53", "timber":"#8d7057", "door":"#795d47", "metal":"#4a4d49", "line":3.30},
	"WestCornerWorkshopResidence": {"name":"Silver mineral / workshop slate", "body":"#b6bbb2", "lower":"#71848a", "trim":"#4c5d61", "timber":"#9b846a", "door":"#a27b5b", "metal":"#465355", "line":3.30},
	"EastGardenResidence": {"name":"Pale tea / garden green", "body":"#cdd4bc", "lower":"#acbba0", "trim":"#61705c", "timber":"#a28d6c", "door":"#698174", "metal":"#48574c", "line":3.30},
	"NishiTownhouse": {"name":"Dusty indigo / honey cedar", "body":"#94a7ae", "lower":"#718a98", "trim":"#455b63", "timber":"#9f8562", "door":"#a0875e", "metal":"#414f56", "line":3.35},
	"HigashiPorchHome": {"name":"Warm greige / olive grey", "body":"#d1c6b4", "lower":"#b1b5a1", "trim":"#626c60", "timber":"#947c62", "door":"#84654b", "metal":"#48534d", "line":3.35},
	"KadoMakerWorkroom": {"name":"Potter's clay / warm putty", "body":"#c1aa91", "lower":"#b29a80", "trim":"#696457", "timber":"#927a5d", "door":"#776d57", "metal":"#50574f", "line":0.92}
}

static func apply(street: Node3D, house: Node3D) -> Dictionary:
	var id := String(house.name)
	if not PROFILES.has(id):
		return {}
	if house.has_meta("residential_paint_finish"):
		return house.get_meta("residential_paint_finish")
	var profile: Dictionary = PROFILES[id]
	var source: Dictionary = street.get("materials")
	var coatings: Dictionary = {}
	var repeated_roles: Dictionary = {}
	_remember_roles(house,source,repeated_roles)
	var stats := {"mineral":0,"timber":0,"painted_trim":0,"door":0,"roof_rainwater":0}
	_coat(house,house,source,profile,coatings,stats,repeated_roles)
	var report := {
		"profile_id":id,"scheme_name":profile.name,
		"body_hex":profile.body,"lower_hex":profile.lower,"trim_hex":profile.trim,
		"timber_hex":profile.timber,"door_hex":profile.door,"metal_hex":profile.metal,
		"paint_line_local_y":profile.line,"finish_members":stats,
		"geometry_unchanged":true,"interiors_excluded":true,
		"source_maps_unchanged":true,"materials_owned_by_property":true,
		"finish":"matte mineral walls; low-sheen exterior timber; coated roof and rainwater goods",
		"design_basis":"restrained planted Midori residential lanes and artisan court; original colour schedules"
	}
	house.set_meta("residential_paint_finish",report)
	return report

static func _coat(node: Node, house: Node3D, source: Dictionary, profile: Dictionary, coatings: Dictionary, stats: Dictionary, repeated_roles: Dictionary) -> void:
	var label := String(node.name)
	# Keep objects behind glazing and all furnishings on their original finishes.
	if _interior_label(label):
		return
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		if _anonymous_room_content(visual): return
		var original := visual.material_override
		if original is ShaderMaterial and original.resource_name == "Court_WarmIvoryMineralRender":
			if not coatings.has("mineral"):
				var wall := ShaderMaterial.new()
				wall.resource_name = String(house.name)+"_MineralPaint"
				wall.shader = WALL_SHADER
				for parameter: String in ["mineral_color","mineral_normal","mineral_roughness"]:
					wall.set_shader_parameter(parameter,original.get_shader_parameter(parameter))
				wall.set_shader_parameter("upper_tint",Color(String(profile.body)))
				wall.set_shader_parameter("lower_tint",Color(String(profile.lower)))
				wall.set_shader_parameter("paint_line_world_y",house.global_position.y+float(profile.line))
				coatings["mineral"] = wall
			visual.material_override = coatings.mineral
			stats.mineral += 1
		elif original is ShaderMaterial and original.resource_name == "Court_FineGrainedTimber":
			var category := _role(visual,source,repeated_roles)
			if category.is_empty(): category = "timber"
			if not coatings.has(category):
				var wood := original.duplicate() as ShaderMaterial
				wood.resource_name = String(house.name)+"_"+category
				var tint: String = profile.timber
				if category == "painted_trim": tint = profile.trim
				if category == "door": tint = profile.door
				wood.set_shader_parameter("timber_tint",Color(tint))
				if category == "painted_trim":
					wood.set_shader_parameter("timber_contrast",.10)
					wood.set_shader_parameter("normal_depth",.10)
				coatings[category] = wood
			visual.material_override = coatings[category]
			stats[category] += 1
		elif original == source.get("arch_metal") and _role(visual,source,repeated_roles) == "roof_rainwater":
			if not coatings.has("roof_rainwater"):
				var metal := original.duplicate() as StandardMaterial3D
				metal.resource_name = String(house.name)+"_CoatedRoofRainwater"
				metal.albedo_color = Color(String(profile.metal))
				metal.metallic = .12
				metal.roughness = .56
				coatings["roof_rainwater"] = metal
			visual.material_override = coatings.roof_rainwater
			stats.roof_rainwater += 1
	for child: Node in node.get_children():
		_coat(child,house,source,profile,coatings,stats,repeated_roles)

static func _interior_label(label: String) -> bool:
	for prefix: String in ["Interior","Room","Curtain","RecessRoom","RecessSide","LinenCurtain","SmallRoomObject","RecessShelf","ShelfObject"]:
		if label.begins_with(prefix): return true
	return false

static func _anonymous_room_content(visual: MeshInstance3D) -> bool:
	# Repeated window contents can lose their authored label when Godot resolves
	# sibling name collisions. The room's back band is behind the .53m sash.
	return String(visual.name).begins_with("@") and visual.mesh != null and visual.position.z >= .65 and visual.position.z <= 1.06 and visual.position.y >= .5 and visual.position.y <= 5.7 and visual.mesh.get_aabb().size.y < 2.0

static func _section(visual: MeshInstance3D) -> String:
	# Repeated pieces retain the same material and physical section even when
	# their labels become @MeshInstance3D@... . Ignore only the longest dimension
	# so a mono-pitch roof's two unequal downpipes still share one finish.
	var size := visual.mesh.get_aabb().size
	var along := size.max_axis_index()
	var material := visual.material_override
	return "%s|%d:%.5f:%.5f" % [material.resource_name,along,size[(along+1)%3],size[(along+2)%3]]

static func _named_role(label: String, material: Material, source: Dictionary) -> String:
	if material is ShaderMaterial and material.resource_name == "Court_FineGrainedTimber":
		if label.contains("Door"): return "door"
		return "painted_trim" if _painted_trim(label) else "timber"
	if material == source.get("arch_metal"):
		return "roof_rainwater" if _roof_rainwater(label) else "hardware"
	return ""

static func _remember_roles(node: Node, source: Dictionary, sections: Dictionary) -> void:
	var label := String(node.name)
	if _interior_label(label): return
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		if not label.begins_with("@") and visual.mesh != null and visual.material_override != null:
			var role := _named_role(label,visual.material_override,source)
			if not role.is_empty():
				var section := _section(visual)
				if not sections.has(section): sections[section] = []
				if not sections[section].has(role): sections[section].append(role)
	for child: Node in node.get_children(): _remember_roles(child,source,sections)

static func _role(visual: MeshInstance3D, source: Dictionary, sections: Dictionary) -> String:
	var label := String(visual.name)
	if not label.begins_with("@"):
		return _named_role(label,visual.material_override,source)
	if visual.mesh == null: return ""
	var candidates: Array = sections.get(_section(visual),[])
	return String(candidates[0]) if candidates.size()==1 else ""

static func _painted_trim(label: String) -> bool:
	for part: String in ["Fascia","CornerCover","ProudTimberCorner","StoreyBand","StoreyLedger","CedarLedger","FieldTermination","WindowBayBearingJamb","WindowBayHeadBeam","WorkroomPortal","WorkroomContinuousLintel","WorkroomLintelCorbel"]:
		if label.contains(part): return true
	return false

static func _roof_rainwater(label: String) -> bool:
	# Handles, hinges, window tracks, service cabinets and nameplates retain their
	# original finishes; roof coatings end at the actual construction boundaries.
	for part: String in ["Roof","Gutter","Downpipe","DrainShoe","RidgeCap","RidgeFoldedCap","Rainwater","PipeWallClip","PipeFixingClip","EntranceCanopy"]:
		if label.contains(part): return true
	return label.begins_with("Nishi") and (label.contains("CanopyDeck") or label.contains("FoldedFrontDrip") or label.contains("PipeShoe") or label.contains("PipeClip") or label.contains("UpperWindowVisor"))
