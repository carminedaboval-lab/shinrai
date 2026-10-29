extends RefCounted
## Original project geometry, Codex 2026-10-23; no new external asset sources.
## Reuses installed joinery walnut and arch_stone/arch_metal/arch_glass materials.
## Integration: architecture._recessed_window delegates replace_window with same args;
## architecture._balcony delegates replace_balcony(street,anchor,w), w=building width.
## Optional screen_mounts(street,anchor,center_x,bottom,top,screen_width) adds only
## mounting hardware behind root-owned vertical screen slats (not duplicate slats).
## No collision, footprint, opening, socket, roof, or lighting changes.
## Construction counts before existing street batching:37 mesh members/window
## (4 reveals,8 rebated perimeter,8 sash,8 seals,2 panes,2 pulls,4 guides,1 sill);
## balcony77 members (6 deck/edge,9 support,30 post/shoe/cap,21 front rails,
## 1 front handrail,6 return rails,2 return handrails,2 wall terminations).
## Optional screen hardware10 members (2 rails,4 stand-offs,4 wall plates).
## Window sill original envelope retained; 14mm fall and6x6mm underside drip kerf.
## Shared-material batching yields existing material surfaces, not77 balcony draws.
## No engine/GPU validation performed by author; root owns parser/native acceptance.

static func _part(street: Node3D, anchor: Node3D, label: String, pos: Vector3, size: Vector3, key: String) -> MeshInstance3D:
	# Existing street batching merges these shared-material members after build.
	return street.call("_box",anchor,label,pos,size,key,false) as MeshInstance3D

static func _seals(street: Node3D) -> void:
	var mats: Dictionary = street.get("materials")
	if not mats.has("upper_glazing_seal"):
		street.call("_material","upper_glazing_seal",Color("#20251f"),.94,"",1.0)

static func replace_window(street: Node3D, anchor: Node3D, x: float, bottom: float, top: float, width: float, narrow: bool) -> void:
	_seals(street)
	var height := top-bottom
	var center_y := (top+bottom)*.5
	var reveal_key := "arch_cedar" if narrow else "arch_interior"
	# Existing 460mm reveal envelope: front -.02, rear .44. Keep opening intact.
	for side: float in [-1.0,1.0]:
		_part(street,anchor,"UpperConstructionSideReveal",Vector3(x+side*(width*.5-.045),center_y,.21),Vector3(.09,height,.46),reveal_key)
	for yy: float in [bottom,top]:
		_part(street,anchor,"UpperConstructionHeadSillReveal",Vector3(x,yy,.21),Vector3(width,.10,.46),reveal_key)
	# Four solid 65mm perimeter faces, with a distinct 18mm recessed shoulder.
	# The shoulder is behind the frame, not a bright line drawn on the glazing.
	for side: float in [-1.0,1.0]:
		_part(street,anchor,"UpperOuterFrameJamb",Vector3(x+side*(width*.5-.115),center_y,.325),Vector3(.065,height-.10,.13),"arch_cedar")
		_part(street,anchor,"UpperFrameRebateShoulder",Vector3(x+side*(width*.5-.151),center_y,.377),Vector3(.018,height-.13,.030),"arch_cedar")
	for side: float in [-1.0,1.0]:
		var yy := center_y+side*(height*.5-.083)
		_part(street,anchor,"UpperOuterFrameHeadSill",Vector3(x,yy,.325),Vector3(width-.23,.065,.13),"arch_cedar")
		_part(street,anchor,"UpperHorizontalRebateShoulder",Vector3(x,yy-side*.036,.377),Vector3(width-.29,.018,.030),"arch_cedar")
	# Two physically distinct sliding leaves. 12mm overlap at the meeting stile;
	# track centers differ by18mm. Sashes:35mm stiles,45mm rails,45mm depth.
	var clear_width := width-.320
	var leaf_width := clear_width*.5+.012
	var leaf_height := height-.240
	for leaf: int in range(2):
		var side := -1.0 if leaf == 0 else 1.0
		var cx := x+side*(clear_width*.25-.006)
		var z := .326+float(leaf)*.018
		for edge: float in [-1.0,1.0]:
			_part(street,anchor,"UpperLeafStile",Vector3(cx+edge*(leaf_width*.5-.0175),center_y,z),Vector3(.035,leaf_height,.045),"arch_pale_wood")
		for edge: float in [-1.0,1.0]:
			_part(street,anchor,"UpperLeafRail",Vector3(cx,center_y+edge*(leaf_height*.5-.0225),z),Vector3(leaf_width-.070,.045,.045),"arch_pale_wood")
		var glass_width := leaf_width-.070
		var glass_height := leaf_height-.090
		# 8mm black EPDM bite stands just proud of the glass around each pane.
		for edge: float in [-1.0,1.0]:
			_part(street,anchor,"UpperLeafVerticalSeal",Vector3(cx+edge*(glass_width*.5-.004),center_y,z+.009),Vector3(.008,glass_height,.010),"upper_glazing_seal")
		for edge: float in [-1.0,1.0]:
			_part(street,anchor,"UpperLeafHorizontalSeal",Vector3(cx,center_y+edge*(glass_height*.5-.004),z+.009),Vector3(glass_width-.016,.008,.010),"upper_glazing_seal")
		_part(street,anchor,"UpperIndividualLeafGlass",Vector3(cx,center_y,z+.014),Vector3(glass_width-.008,glass_height-.008,.008),"arch_glass")
		# Slim recessed pull is on its own meeting stile, not in free space.
		_part(street,anchor,"UpperLeafRecessedPull",Vector3(cx-side*(leaf_width*.5-.018),center_y-.16,z-.024),Vector3(.013,.105,.008),"arch_metal")
	# Paired track guides retain the two leaves and disclose the sliding assembly.
	for yy: float in [bottom+.118,top-.118]:
		for z: float in [.326,.344]:
			_part(street,anchor,"UpperSashTrackGuide",Vector3(x,yy,z+.026),Vector3(clear_width,.008,.009),"arch_metal")
	_profiled_sill(street,anchor,x,bottom,width)
	anchor.set_meta("upper_two_leaf_construction",true)

static func _profiled_sill(street: Node3D, anchor: Node3D, x: float, bottom: float, width: float) -> void:
	# Same old sill envelope: width+.12, y bottom-.0925..-.0375, z -.07..+.23.
	# Top falls14mm toward the street; 6x6mm underside kerf is actual geometry.
	var section: Array[Vector2] = [Vector2(-.070,-.0515),Vector2(.230,-.0375),Vector2(.230,-.0925),Vector2(-.044,-.0925),Vector2(-.044,-.0865),Vector2(-.050,-.0865),Vector2(-.050,-.0925),Vector2(-.070,-.0925)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := (width+.12)*.5
	for i: int in range(section.size()):
		var a: Vector2 = section[i]
		var b: Vector2 = section[(i+1)%section.size()]
		var normal := Vector3(0,b.x-a.x,a.y-b.y).normalized()
		_face(tool,[Vector3(x-half,bottom+a.y,a.x),Vector3(x+half,bottom+a.y,a.x),Vector3(x+half,bottom+b.y,b.x),Vector3(x-half,bottom+b.y,b.x)],normal)
	var indices := Geometry2D.triangulate_polygon(PackedVector2Array(section))
	for side: float in [-1.0,1.0]:
		for i: int in range(0,indices.size(),3):
			var points: Array[Vector3] = []
			for j: int in range(3):
				var p: Vector2 = section[indices[i+j]]
				points.append(Vector3(x+side*half,bottom+p.y,p.x))
			_face(tool,points,Vector3.RIGHT*side)
	_emit(street,anchor,"UpperSlopingSillWithUndercutDrip",tool,"arch_stone")

static func replace_balcony(street: Node3D, anchor: Node3D, building_width: float) -> void:
	var width := building_width-.75
	# Wider constructed balcony: z-1.50..+.18, finishedY3.98 unchanged.
	_part(street,anchor,"BalconyStructuralDeck",Vector3(0,3.915,-.66),Vector3(width,.070,1.68),"arch_stone")
	_part(street,anchor,"BalconyWalkingTopping",Vector3(0,3.966,-.66),Vector3(width-.024,.028,1.656),"arch_stone")
	_part(street,anchor,"BalconyFoldedFrontEdge",Vector3(0,3.931,-1.4925),Vector3(width,.082,.015),"arch_metal")
	_part(street,anchor,"BalconyEdgeTopReturn",Vector3(0,3.974,-1.474),Vector3(width,.012,.052),"arch_metal")
	_part(street,anchor,"BalconyUnderEdgeDripHem",Vector3(0,3.887,-1.489),Vector3(width,.012,.022),"arch_metal")
	for side: float in [-1.0,1.0]:
		_part(street,anchor,"BalconyFoldedCornerReturn",Vector3(side*(width*.5-.0075),3.931,-.66),Vector3(.015,.082,1.65),"arch_metal")
	for cx: float in [-width*.36,0,width*.36]:
		_part(street,anchor,"BalconyStructuralWallPlate",Vector3(cx,3.64,-.055),Vector3(.12,.52,.040),"arch_metal")
		_part(street,anchor,"BalconyCantileverTopArm",Vector3(cx,3.852,-.75),Vector3(.065,.056,1.40),"arch_metal")
		# Real triangular plate underneath top arm, connected to its wall plate.
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var section: Array[Vector2] = [Vector2(-1.45,3.824),Vector2(-.075,3.824),Vector2(-.075,3.395)]
		for side: float in [-1.0,1.0]:
			var points: Array[Vector3] = []
			for p: Vector2 in section: points.append(Vector3(cx+side*.0175,p.y,p.x))
			_face(tool,points,Vector3.RIGHT*side)
		for i: int in range(3):
			var a: Vector2 = section[i]
			var b: Vector2 = section[(i+1)%3]
			_face(tool,[Vector3(cx-.0175,a.y,a.x),Vector3(cx+.0175,a.y,a.x),Vector3(cx+.0175,b.y,b.x),Vector3(cx-.0175,b.y,b.x)],Vector3(0,b.x-a.x,a.y-b.y).normalized())
		_emit(street,anchor,"BalconyTriangularCantileverWeb",tool,"arch_metal")
	var post_x: Array[float] = []
	for i: int in range(8):
		var cx := -width*.5+.015+float(i)*(width-.030)/7.0
		post_x.append(cx)
		_post(street,anchor,cx,-1.45)
	for i: int in range(7):
		var gap := post_x[i+1]-post_x[i]-.045
		for yy: float in [4.15,4.43,4.71]:
			_part(street,anchor,"BalconyRailTerminatedIntoPosts",Vector3((post_x[i]+post_x[i+1])*.5,yy,-1.45),Vector3(gap,.035,.035),"arch_metal")
	# One continuous capped handrail bears on posts; ends use explicit end caps.
	_part(street,anchor,"BalconyCappedHandrail",Vector3(0,5.0125,-1.45),Vector3(width,.055,.065),"arch_metal")
	for side: float in [-1.0,1.0]:
		var cx := side*(width*.5-.015)
		_post(street,anchor,cx,.075)
		for yy: float in [4.15,4.43,4.71]:
			_part(street,anchor,"BalconyRailReturnBetweenPosts",Vector3(cx,yy,-.6875),Vector3(.035,.035,1.480),"arch_metal")
		_part(street,anchor,"BalconyHandrailCornerReturn",Vector3(cx,5.0125,-.6875),Vector3(.065,.055,1.590),"arch_metal")
		_part(street,anchor,"BalconyHandrailWallTermination",Vector3(cx,5.0125,.105),Vector3(.080,.085,.010),"arch_metal")
	anchor.set_meta("upper_balcony_construction",{"front_posts":8,"return_posts":2,"front_rail_spans":7,"deck_depth_m":1.68,"deck_front_z":-1.50,"deck_back_z":.18,"outward_projection_m":1.50,"deck_top_y":3.98,"rail_top_y":5.04,"clear_depth_no_planter_m":1.2425,"deck_bounds":AABB(Vector3(-width*.5,3.88,-1.50),Vector3(width,.10,1.68)),"support_front_z":-1.45,"collision_changed":false})

static func _post(street: Node3D, anchor: Node3D, x: float, z: float) -> void:
	_part(street,anchor,"BalconyPostBaseShoe",Vector3(x,4.005,z),Vector3(.075,.050,.080),"arch_metal")
	_part(street,anchor,"BalconyPostSeatedInShoe",Vector3(x,4.505,z),Vector3(.045,1.00,.045),"arch_metal")
	_part(street,anchor,"BalconyPostTopCap",Vector3(x,5.004,z),Vector3(.050,.006,.050),"arch_metal")

static func screen_mounts(street: Node3D, anchor: Node3D, center_x: float, bottom: float, top: float, screen_width: float) -> void:
	# Root's slats sit at z-.14 with130mm depth, rear face-.075. The rail front
	# meets that rear face;80mm brackets then connect the rail to wall anchors.
	for yy: float in [bottom+.14,top-.14]:
		_part(street,anchor,"UpperScreenRecessedMountRail",Vector3(center_x,yy,-.0525),Vector3(screen_width+.08,.045,.045),"arch_cedar")
		for side: float in [-1.0,1.0]:
			var cx := center_x+side*maxf(.04,screen_width*.5-.06)
			_part(street,anchor,"UpperScreenRailStandoff",Vector3(cx,yy,.010),Vector3(.035,.035,.080),"arch_metal")
			_part(street,anchor,"UpperScreenWallMountPlate",Vector3(cx,yy,.055),Vector3(.070,.090,.010),"arch_metal")

static func _face(tool: SurfaceTool, points: Array[Vector3], normal: Vector3) -> void:
	# Godot clockwise front winding; equivalent to installed architecture helper.
	if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal) > 0.0: points.reverse()
	for i: int in range(1,points.size()-1):
		for index: int in [0,i,i+1]:
			var p := points[index]
			tool.set_normal(normal)
			var axis := normal.abs().max_axis_index()
			tool.set_uv(Vector2(p.z,p.y) if axis == 0 else (Vector2(p.x,p.z) if axis == 1 else Vector2(p.x,p.y)))
			tool.add_vertex(p)

static func _emit(street: Node3D, anchor: Node3D, label: String, tool: SurfaceTool, key: String) -> void:
	tool.index()
	tool.generate_tangents()
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = tool.commit()
	var mats: Dictionary = street.get("materials")
	node.material_override = mats[key]
	anchor.add_child(node)
