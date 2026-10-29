extends RefCounted
## Original location-specific artwork, mounted to existing shop interior walls.
const FOLDER := "res://assets/shinrai/streets/interior_paintings/"

static func build(street: Node3D) -> Dictionary:
	var rows: Array[Dictionary] = []
	for spec: Dictionary in [
		{"shop":"MoriCoffee","id":"mori_morning","title":"Morning beside the park","position":Vector3(-4.69,1.95,3.25),"yaw":PI*.5,"width":1.50,"frame":"arch_cedar","theme":"Coffee and the neighbouring park"},
		{"shop":"UedaBooks","id":"ueda_reading_rain","title":"Reading weather","position":Vector3(5.19,1.95,6.04),"yaw":-PI*.5,"width":1.35,"frame":"arch_metal","theme":"Books and the city in rain"},
		{"shop":"HinataDaily","id":"hinata_seasonal","title":"Autumn delivery","position":Vector3(-4.69,1.95,1.0),"yaw":PI*.5,"width":1.20,"frame":"arch_pale_wood","theme":"Seasonal Japanese produce"},
		{"shop":"YakitoriShop","id":"yakitori_evening","title":"The evening grill","position":Vector3(-2.29,1.95,4.30),"yaw":PI*.5,"width":1.35,"frame":"arch_cedar","theme":"Charcoal cooking and warm evening dining"}
	]:
		var shop := street.get_node_or_null(NodePath(spec.shop)) as Node3D
		if shop==null: continue
		var texture := load(FOLDER+String(spec.id)+".png") as Texture2D
		if texture==null: continue
		var size := Vector2(float(spec.width),float(spec.width)*float(texture.get_height())/float(texture.get_width()))
		var outer := size+Vector2(.16,.16)
		var holder := Node3D.new()
		holder.name="InteriorPainting_"+String(spec.id)
		holder.position=spec.position
		holder.rotation.y=float(spec.yaw)
		holder.set_meta("creator_editable",true)
		holder.set_meta("creator_display_name",spec.title)
		holder.set_meta("creator_object_kind","wall_art")
		holder.set_meta("interior_painting",true)
		shop.add_child(holder)
		# +Z is the room-facing side; backboard starts 2mm from the wall plane.
		street.call("_box",holder,"InteriorPaintingBackboard",Vector3(0,0,.008),Vector3(outer.x,outer.y,.012),"arch_cedar",false)
		street.call("_box",holder,"InteriorPaintingLinenMat",Vector3(0,0,.016),Vector3(outer.x-.04,outer.y-.04,.004),"arch_linen",false)
		for side: float in [-1.0,1.0]:
			street.call("_box",holder,"InteriorPaintingFrameStile",Vector3(side*(outer.x*.5-.018),0,.023),Vector3(.036,outer.y,.042),spec.frame,false)
			street.call("_box",holder,"InteriorPaintingFrameRail",Vector3(0,side*(outer.y*.5-.018),.023),Vector3(outer.x-.072,.036,.042),spec.frame,false)
		var material := StandardMaterial3D.new()
		material.resource_name="OriginalInteriorPainting_"+String(spec.id)
		material.albedo_texture=texture
		material.roughness=.95
		material.metallic_specular=.12
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var canvas := MeshInstance3D.new()
		canvas.name="InteriorPaintedSurface"
		var quad := QuadMesh.new()
		quad.size=size
		canvas.mesh=quad
		canvas.material_override=material
		canvas.position.z=.019
		holder.add_child(canvas)
		var row := {"id":spec.id,"shop":spec.shop,"title":spec.title,"theme":spec.theme,"texture":FOLDER+String(spec.id)+".png","position_local":spec.position,"yaw":spec.yaw,"image_size_m":size,"frame_size_m":outer,"local_bounds":AABB(Vector3(-outer.x*.5,-outer.y*.5,.002),Vector3(outer.x,outer.y,.042)),"normal_local":holder.basis.z,"aspect_preserved":true,"emission":false,"world_bounds":holder.global_transform*AABB(Vector3(-outer.x*.5,-outer.y*.5,.002),Vector3(outer.x,outer.y,.042))}
		holder.set_meta("painting_record",row)
		rows.append(row)
	var report := {"ok":rows.size()==4,"paintings":rows,"count":rows.size(),"new_lights":0,"new_colliders":0,"per_frame_scripts":0,"existing_gallery_art_retained":true}
	street.set_meta("interior_paintings",report)
	return report
