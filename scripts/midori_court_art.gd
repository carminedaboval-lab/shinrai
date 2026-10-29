extends RefCounted
## Sparse original art placement; imported vase PBR materials remain untouched.
const VASE := "res://assets/shinrai/streets/midori_court_art/haku_stoneware_vase.glb"
const STUDY := "res://assets/shinrai/streets/midori_court_art/street_study.png"

static func build(street: Node3D, gallery: Dictionary) -> Dictionary:
	var sockets: Dictionary = gallery.get("sockets",{})
	var instances: Array[Dictionary] = []
	var packed := load(VASE) as PackedScene
	var chosen := {"hero":false,"window":false,"shelf":false,"workbench":false,"sculpture":false}
	for id: String in sockets:
		var row: Dictionary = sockets[id]
		var height := 0.0
		var category := ""
		if id.begins_with("InteriorHeroVaseSocket") and not chosen.hero:
			height=.30
			category="hero"
		elif id.begins_with("InteriorWindowCeramicSocket") and not chosen.window:
			height=.22
			category="window"
		elif id.begins_with("InteriorShelfCeramicSocket") and not chosen.shelf and float(row.support_y)>.8:
			height=.25
			category="shelf"
		elif id.begins_with("InteriorWorkbenchCeramicsSocket") and not chosen.workbench:
			height=.18
			category="workbench"
		elif id.begins_with("InteriorSculptureSocket") and not chosen.sculpture:
			height=.36
			category="sculpture"
		if category.is_empty(): continue
		chosen[category]=true
		if packed==null: continue
		var socket := row.get("node") as Node3D
		if socket==null: continue
		var asset := packed.instantiate() as Node3D
		if asset==null: continue
		var raw := _bounds(asset,asset.transform)
		if raw.size.y<.001:
			asset.free()
			continue
		var factor := height/raw.size.y
		var available: Vector3 = row.available_size_m
		if raw.size.x*factor>available.x or raw.size.z*factor>available.z or height>available.y:
			asset.free()
			continue
		var holder := Node3D.new()
		holder.name="InteriorStoneware_"+category
		holder.scale=Vector3.ONE*factor
		socket.add_child(holder)
		var centre := Node3D.new()
		centre.name="InteriorVaseBottomAlignment"
		centre.position=Vector3(-raw.get_center().x,-raw.position.y,-raw.get_center().z)
		holder.add_child(centre)
		centre.add_child(asset)
		_name_interior(asset)
		# Display support colliders already exist. Add a truthful vase envelope,
		# entirely outside the clear aisle, rather than an invisible route blocker.
		var size := raw.size*factor
		street.call("_solid",socket,"InteriorStonewareCollision",Vector3(0,height*.5,0),size)
		var local_bounds := AABB(Vector3(-size.x*.5,0,-size.z*.5),size)
		var world_bounds: AABB = socket.global_transform*local_bounds
		instances.append({"id":category,"socket":id,"asset":VASE,"height_m":height,"uniform_scale":factor,"support_y":row.support_y,"local_bounds":local_bounds,"world_bounds":world_bounds,"materials_preserved":true,"collision":"single actual mesh bounds envelope"})
	var artwork := _painting(street,gallery,sockets)
	return {"ok":instances.size()==5 and int(artwork.get("artwork_count",0))==1,"asset_paths":[VASE,STUDY],"vase_instances":instances,"vase_count":instances.size(),"vase_collision_count":instances.size(),"nominal_source_triangles":10000,"nominal_instanced_triangles":instances.size()*10000,"artwork":artwork,"artwork_count":artwork.get("artwork_count",0),"lights_created":0,"source_assets_modified":false,"imported_materials_preserved":true}

static func _painting(street: Node3D, gallery: Dictionary, sockets: Dictionary) -> Dictionary:
	var first: Node3D
	var removed := 0
	var fixtures := gallery.get("fixtures_group") as Node3D
	# Identify only the four members of the second authored frame by exact
	# positions; Godot may replace duplicate names with generated names.
	if fixtures!=null:
		for child: Node in fixtures.get_children():
			if not child is MeshInstance3D: continue
			var mesh := child as MeshInstance3D
			var p := mesh.position
			var side := absf(absf(p.x)-.5375)<.002 and absf(p.y-1.70)<.002
			var rail := absf(p.x)<.002 and absf(absf(p.y-1.70)-.5675)<.002
			if absf(p.z-9.46)<.002 and (side or rail):
				fixtures.remove_child(mesh)
				mesh.free()
				removed+=1
	for id: String in sockets:
		if id.begins_with("InteriorPaintingSocket"):
			first=sockets[id].get("node") as Node3D
			break
	if first==null: return {"artwork_count":0,"second_frame_members_removed":removed,"error":"painting socket absent"}
	var texture := load(STUDY) as Texture2D
	if texture==null: return {"artwork_count":0,"second_frame_members_removed":removed,"error":"street study texture absent"}
	var ratio := float(texture.get_width())/float(texture.get_height())
	var display := Vector2(.89,.89/ratio)
	if display.y>.95: display=Vector2(.95*ratio,.95)
	# Portrait backmat uses the existing frame; the landscape image remains
	# uncropped at its original aspect ratio, with visible linen margins.
	street.call("_box",first,"InteriorPaintingBackmat",Vector3(0,0,.008),Vector3(.99,1.05,.012),"arch_linen",false)
	var material := StandardMaterial3D.new()
	material.resource_name="CourtOriginalStreetStudy"
	material.albedo_texture=texture
	material.albedo_color=Color.WHITE
	material.roughness=.92
	material.metallic_specular=.15
	var quad := QuadMesh.new()
	quad.size=display
	var image := MeshInstance3D.new()
	image.name="InteriorSingleStreetStudy"
	image.mesh=quad
	image.material_override=material
	# QuadMesh faces+Z by default; rotate its front toward the gallery (-Z).
	image.rotation.y=PI
	image.position=Vector3(0,0,-.002)
	first.add_child(image)
	return {"artwork_count":1,"image":STUDY,"socket":str(first.name),"original_pixels":Vector2i(texture.get_width(),texture.get_height()),"image_size_m":display,"backmat_size_m":Vector2(.99,1.05),"aspect_preserved":true,"cropped":false,"existing_frame_reused":true,"second_frame_members_removed":removed,"collisions_created":0}

static func _bounds(node: Node3D, transform: Transform3D) -> AABB:
	var result := AABB()
	var first := true
	if node is MeshInstance3D and (node as MeshInstance3D).mesh!=null:
		result=transform*(node as MeshInstance3D).get_aabb()
		first=false
	for child: Node in node.get_children():
		if not child is Node3D: continue
		var box := _bounds(child,transform*(child as Node3D).transform)
		if box.size.length_squared()<.000001: continue
		result=box if first else result.merge(box)
		first=false
	return result

static func _name_interior(node: Node) -> void:
	if not String(node.name).begins_with("Interior"): node.name="Interior"+String(node.name)
	for child: Node in node.get_children(): _name_interior(child)
