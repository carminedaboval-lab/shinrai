extends RefCounted
## Call after all ground and gallery art, before layer assignment and batching.
const Art = preload("res://scripts/midori_court_art.gd")
const Lighting = preload("res://scripts/midori_display_lighting.gd")
const Paving = preload("res://scripts/midori_paving_readability.gdshader")
const Surface = preload("res://scripts/midori_surface_readability.gdshader")

static func build(street: Node3D) -> Dictionary:
	var changed := 0
	var replacements: Dictionary = {}
	var paving_ids: Dictionary = {}
	var mats: Dictionary = street.get("materials")
	for index: int in range(5):
		var material := mats.get("land_slab_%d"%index) as ShaderMaterial
		if material!=null: paving_ids[material.get_instance_id()]=[.97,1.025,.955,1.04,.985][index]
	var ramp := mats.get("land_ramp") as ShaderMaterial
	if ramp!=null: paving_ids[ramp.get_instance_id()]=1.0
	var paving_count := 0
	# Replace shader only on this street's existing opaque asphalt/paint materials.
	# Retain every texture and metre-scale normal; no new surface geometry.
	for node: Node in street.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		var mat := mesh.material_override as ShaderMaterial
		if mat!=null and mat.shader!=null and mat.shader.resource_path=="res://scripts/midori_street_asphalt.gdshader":
			var id := mat.get_instance_id()
			if not replacements.has(id):
				var copy := mat.duplicate() as ShaderMaterial
				copy.shader=Surface
				replacements[id]=copy
			mesh.material_override=replacements[id]
			changed+=1
		elif mat!=null and paving_ids.has(mat.get_instance_id()):
			var id := mat.get_instance_id()
			if not replacements.has(id):
				var copy := mat.duplicate() as ShaderMaterial
				copy.shader=Paving
				copy.set_shader_parameter("stone_luminance",paving_ids[id])
				copy.set_shader_parameter("stone_weather",1.0)
				replacements[id]=copy
			mesh.material_override=replacements[id]
			paving_count+=1
	# Sloped ramps may carry the same stones as per-surface mesh materials.
	for node: Node in street.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if mesh.mesh==null or mesh.material_override!=null: continue
		for index: int in range(mesh.mesh.get_surface_count()):
			var mat := mesh.get_active_material(index) as ShaderMaterial
			if mat==null or not paving_ids.has(mat.get_instance_id()): continue
			var id := mat.get_instance_id()
			if not replacements.has(id):
				var copy := mat.duplicate() as ShaderMaterial
				copy.shader=Paving
				copy.set_shader_parameter("stone_luminance",paving_ids[id])
				copy.set_shader_parameter("stone_weather",1.0)
				replacements[id]=copy
			mesh.set_surface_override_material(index,replacements[id])
			paving_count+=1
	return {"paving_surfaces":paving_count,"paving_materials":paving_ids.size(),"surfaces":changed,"new_geometry":0,"collisions_changed":0,"repair_areas":4,"aggregate_repeat_m":2.0,"source_textures_preserved":true}

static func build_gallery(street: Node3D, gallery: Dictionary) -> Dictionary:
	var room := gallery.get("interior_group") as Node3D
	if room==null: return {"ok":false,"reason":"gallery interior absent"}
	var root := Node3D.new()
	root.name="InteriorWindowReadability"
	room.add_child(root)
	var packed := load(Art.VASE) as PackedScene
	if packed==null: return {"ok":false,"reason":"licensed vase absent"}
	var count := 0
	# Four groups sit on existing .62m timber window benches, clear of the door.
	# Empty centre sockets and the previously placed vase remain untouched.
	for row: Array in [[-3.62,.27],[-2.28,.36],[2.95,.31],[3.62,.22]]:
		var vase := packed.instantiate() as Node3D
		var bounds := Art._bounds(vase,vase.transform)
		if bounds.size.y<.001:
			vase.free()
			continue
		var height := float(row[1])
		var factor := minf(height/bounds.size.y,.38/maxf(bounds.size.x,bounds.size.z))
		var plinth_height := .035 if count%2==0 else .10
		var group := Node3D.new()
		group.name="InteriorWindowGroup%d"%count
		group.position=Vector3(float(row[0]),.62,.80)
		root.add_child(group)
		street.call("_box",group,"InteriorDisplayRiser",Vector3(0,plinth_height*.5,0),Vector3(.40,plinth_height,.40),"arch_stone",false)
		var holder := Node3D.new()
		holder.name="InteriorStonewareSupported"
		holder.position=Vector3(0,plinth_height,0)
		holder.scale=Vector3.ONE*factor
		group.add_child(holder)
		vase.position=Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)
		holder.add_child(vase)
		Art._name_interior(vase)
		count+=1
	# Two heads illuminate the display furniture/ceramics using the gallery mask.
	var lights: Array=[]
	for side: float in [-1.0,1.0]:
		lights.append(Lighting._beam(street,room,["HakuWindowAccentWest" if side<0 else "HakuWindowAccentEast",Vector3(side*2.95,2.75,1.42),Vector3(side*2.95,.83,.80),1.1,.90,54.0,true],1<<11))
	return {"ok":count==4,"additional_vases":count,"stone_risers":count,"new_lights":lights,"supports":"existing .62m supported timber window benches","route_changed":false,"source_materials_preserved":true,"new_colliders":0}
