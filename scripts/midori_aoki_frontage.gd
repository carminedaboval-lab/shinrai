extends RefCounted
## Aoki-only asymmetric wall-borne window assembly. Original metre-scale work.
## Keeps the 13 existing openings and 26 existing glass panes intact.
static func build(street: Node3D, house: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "AokiAsymmetricWindowBay"
	root.set_meta("creator_protected",true)
	root.set_meta("creator_editable",false)
	house.add_child(root)
	# 90mm solid-timber jamb facings bear on the masonry beside the opening.
	# They return to the original wall plane, rather than floating in the garden.
	for x: float in [.215,2.385]:
		_part(street,root,"WindowBayBearingJamb",Vector3(x,1.59,-.10),Vector3(.13,1.70,.24),"arch_cedar")
		_part(street,root,"WindowBayJambStoneFoot",Vector3(x,.76,-.10),Vector3(.15,.08,.26),"arch_stone")
		for yy: float in [1.00,2.18]:
			_part(street,root,"JambFixingPlug",Vector3(x,yy,-.225),Vector3(.022,.022,.012),"arch_pale_wood")
	# Continuous supported head/sill disclose the depth of the original bay.
	_part(street,root,"WindowBayHeadBeam",Vector3(1.30,2.445,-.12),Vector3(2.32,.14,.28),"arch_cedar")
	_part(street,root,"FoldedWindowHeadFlashing",Vector3(1.30,2.53,-.195),Vector3(2.44,.035,.49),"arch_metal")
	_part(street,root,"HeadFlashingDripReturn",Vector3(1.30,2.505,-.435),Vector3(2.44,.045,.018),"arch_metal")
	_part(street,root,"HeadSoffitBoard",Vector3(1.30,2.485,-.29),Vector3(2.32,.025,.26),"arch_pale_wood")
	_part(street,root,"WindowBayStoneSill",Vector3(1.30,.77,-.115),Vector3(2.34,.07,.35),"arch_stone")
	_part(street,root,"SillDripNose",Vector3(1.30,.746,-.285),Vector3(2.34,.023,.018),"arch_stone")
	# Privacy covers only the right portion. Paired rails are mechanically fixed
	# through the solid right reveal, with no posts in the existing planted strip.
	for yy: float in [1.12,2.365]:
		_part(street,root,"ScreenMasonryAnchorPlate",Vector3(2.49,yy,-.035),Vector3(.12,.16,.045),"arch_metal")
		_part(street,root,"ScreenStandOffBracket",Vector3(2.49,yy,-.18),Vector3(.045,.07,.29),"arch_metal")
		_part(street,root,"ScreenCantileverRail",Vector3(1.965,yy,-.315),Vector3(1.13,.055,.075),"arch_metal")
		for dy: float in [-.045,.045]:
			_part(street,root,"ScreenAnchorBolt",Vector3(2.49,yy+dy,-.062),Vector3(.018,.018,.012),"arch_metal")
	for i: int in range(10):
		var x := 1.46+float(i)*.104
		var slat := _part(street,root,"AngledPrivacyBatten",Vector3(x,1.7425,-.365),Vector3(.035,1.43,.085),"arch_cedar")
		slat.rotation.y = -.24
	# The bracket-bearing right stile joins both rails and covers the hardware.
	_part(street,root,"ScreenOuterStile",Vector3(2.49,1.7425,-.365),Vector3(.055,1.43,.09),"arch_cedar")
	var report := {"owner":"aoki_frontage","original_openings_retained":13,"original_glass_panes_retained":26,"new_glass_panes":0,"collision_members_added":0,"ground_posts":0,"screen_battens":10,"minimum_entrance_clearance_m":1.5,"local_bounds":AABB(Vector3(.14,.734,-.454),Vector3(2.42,1.814,.494)),"screen_bounds":AABB(Vector3(1.43,1.0275,-.415),Vector3(1.09,1.43,.15)),"wall_anchor_points":[Vector3(2.49,1.12,-.035),Vector3(2.49,2.365,-.035)],"construction":"solid wall-bearing jambs; supported projecting window head; right-side masonry anchor plates and stand-offs carry two screen rails; 10 angled timber battens","source_provenance":"Original constructed geometry; existing project timber, stone and metal; no source resources changed"}
	root.set_meta("aoki_frontage_construction",report)
	house.set_meta("aoki_frontage_construction",report)
	return report

static func _part(street: Node3D,parent: Node3D,label: String,position: Vector3,size: Vector3,key: String) -> MeshInstance3D:
	return street.call("_box",parent,label,position,size,key,false) as MeshInstance3D

