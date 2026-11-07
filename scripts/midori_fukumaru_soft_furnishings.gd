extends RefCounted
## Static interior textiles and PBR finishes, batched with the room furniture.
## All surface UVs are metres except the individually mapped plant leaves.
const CityKit := preload("res://scripts/midori_near_city_kit.gd")
const TIMBER := "res://assets/shinrai/streets/midori_frontage_construction/mori_bentwood_chair_smoked_walnut_veneer_"

const FABRIC_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float night = 0.0;
uniform float yarn_density = 240.0;
uniform float upholstery = 0.0;
vec3 palette_linear(vec3 c) {
    return mix(c/12.92, pow((c+0.055)/1.055, vec3(2.4)), step(vec3(0.04045),c));
}
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise21(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
    // Plain cotton has fine yarns; the sofa uses a visibly coarser heathered
    // weave. Fade the yarn and slub before they become subpixel glitter.
    vec2 yarn = UV * yarn_density;
    float resolved = 1.0 - smoothstep(0.22, 0.68, max(fwidth(yarn.x), fwidth(yarn.y)));
    float warp = cos(yarn.x * 6.2831853);
    float weft = cos(yarn.y * 6.2831853);
    float over_under = warp * weft;
    float fiber = (warp * 0.36 + weft * 0.40 + over_under * 0.24) * resolved;
    float slub_frequency = mix(68.0, 102.0, upholstery);
    float slub_resolved = 1.0 - smoothstep(0.25, 0.80, max(fwidth(UV.x), fwidth(UV.y)) * slub_frequency);
    float slub = (noise21(UV * vec2(slub_frequency, 11.0)) - 0.5) * slub_resolved;
    float fleck = (noise21(UV * slub_frequency) - 0.5) * slub_resolved;
    float dye = noise21(UV * 5.0) - 0.5;
    ALBEDO = palette_linear(COLOR.rgb) * (0.98 + dye * 0.035 + slub * 0.09
        + fleck * mix(0.035, 0.19, upholstery) + fiber * mix(0.065, 0.14, upholstery));
    ROUGHNESS = clamp(0.88 + slub * 0.08 - fiber * 0.045, 0.80, 0.96);
    SPECULAR = 0.27;
    AO = COLOR.a * (0.975 + 0.025 * fiber);
    AO_LIGHT_AFFECT = 0.3;
    float relief = mix(0.16, 0.27, upholstery) * resolved;
    NORMAL_MAP = normalize(vec3(-sin(yarn.x * 6.2831853) * relief,
        -sin(yarn.y * 6.2831853) * relief, 1.0)) * 0.5 + 0.5;
    NORMAL_MAP_DEPTH = 0.7;
}
"""

const WOOD_SHADER := """
shader_type spatial;
uniform float night = 0.0;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_map : filter_linear_mipmap_anisotropic, repeat_enable;
void fragment() {
    // The veneer photograph runs horizontally. Joinery maps its long axis
    // to UV.y, so rotate the sampled grain and keep its physical scale.
    vec2 uv = vec2(UV.y / 1.15, UV.x / 0.42);
    vec3 wood = texture(albedo_map, uv).rgb;
    // Preserve the sealed wood's authored reflectance; the vertex values
    // are modest finish multipliers distinguishing lighter and darker pieces.
    ALBEDO = wood * COLOR.rgb;
    // This source is the glTF metallic/roughness pack: roughness is green.
    // Its red channel is white, not roughness. No unrelated scratch normal.
    ROUGHNESS = clamp(texture(roughness_map, uv).g * 0.57, 0.27, 0.48);
    SPECULAR = 0.45;
    AO = COLOR.a;
    AO_LIGHT_AFFECT = 0.30;
}
"""

const FINISH_SHADER := """
shader_type spatial;
uniform float night = 0.0;
uniform float metal = 0.0;
uniform float rough = 0.4;
uniform float finish_kind = 0.0;
vec3 palette_linear(vec3 c) {
    return mix(c/12.92, pow((c+0.055)/1.055, vec3(2.4)), step(vec3(0.04045),c));
}
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise21(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
    // Broad wiped areas alter gloss, not a painted-on dirt colour. The small
    // brushed-steel strokes and enamel orange peel are distance filtered.
    float handling = noise21(UV * 9.0) - 0.5;
    float micro_resolved = 1.0 - smoothstep(0.25, 0.85, max(fwidth(UV.x), fwidth(UV.y)) * 320.0);
    float brushed = (noise21(UV * vec2(340.0, 5.0)) - 0.5) * micro_resolved;
    float peel = (noise21(UV * 260.0) - 0.5) * micro_resolved;
    float steel = step(0.5, finish_kind) * (1.0 - step(1.5, finish_kind));
    // Hex enamel/ceramic colours specify diffuse sRGB. The neutral steel
    // values instead specify its already linear metallic reflectance.
    vec3 tint = mix(palette_linear(COLOR.rgb), COLOR.rgb, steel);
    ALBEDO = tint * (0.99 + handling * 0.018 + brushed * steel * 0.045);
    METALLIC = metal;
    ROUGHNESS = clamp(rough + handling * mix(0.035, 0.12, steel)
        + brushed * steel * 0.10 + peel * (1.0 - steel) * 0.035, 0.13, 0.70);
    SPECULAR = 0.5;
    NORMAL_MAP = normalize(vec3(brushed * steel * 0.16 + peel * 0.035,
        peel * 0.035, 1.0)) * 0.5 + 0.5;
    NORMAL_MAP_DEPTH = 0.55;
    AO = COLOR.a;
    AO_LIGHT_AFFECT = 0.3;
}
"""

const FOLIAGE_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float night = 0.0;
vec3 palette_linear(vec3 c) {
    return mix(c/12.92, pow((c+0.055)/1.055, vec3(2.4)), step(vec3(0.04045),c));
}
void fragment() {
    // Leaf meshes provide their silhouette and cupped normals. Veins remain
    // slight tonal/gloss changes rather than tubes floating above the blade.
    float centre = abs(UV.x - 0.5);
    float midrib = 1.0 - smoothstep(0.008, 0.022 + fwidth(UV.x), centre);
    float branches = abs(fract(UV.y * 6.0 - centre * 3.3) - 0.5);
    float veins = 1.0 - smoothstep(0.012, 0.045 + fwidth(UV.y) * 6.0, branches);
    float edge = smoothstep(0.32, 0.50, centre);
    ALBEDO = palette_linear(COLOR.rgb) * (0.94 + midrib * 0.13 + veins * 0.035 - edge * 0.075);
    ROUGHNESS = 0.38 + edge * 0.13 + veins * 0.045;
    SPECULAR = 0.42;
    AO = COLOR.a;
    AO_LIGHT_AFFECT = 0.3;
}
"""

static func materials(h: Node3D) -> void:
	if h._looks.has("apartment_fabric"):
		return
	var cloth := ShaderMaterial.new()
	cloth.shader = Shader.new()
	cloth.shader.code = FABRIC_SHADER
	h._looks["apartment_fabric"] = cloth
	var upholstery := ShaderMaterial.new()
	upholstery.shader = cloth.shader
	upholstery.set_shader_parameter("yarn_density", 118.0)
	upholstery.set_shader_parameter("upholstery", 1.0)
	h._looks["apartment_upholstery"] = upholstery
	var wood := ShaderMaterial.new()
	wood.shader = Shader.new()
	wood.shader.code = WOOD_SHADER
	wood.set_shader_parameter("albedo_map", load(TIMBER + "diff_2k.jpg"))
	wood.set_shader_parameter("roughness_map", load(TIMBER + "rough_2k.png"))
	h._looks["apartment_wood"] = wood
	var finish := Shader.new()
	finish.code = FINISH_SHADER
	for item: Array in [["apartment_ceramic", 0.0, 0.25, 0.0], ["apartment_steel", 0.88, 0.30, 1.0], ["apartment_enamel", 0.0, 0.36, 2.0]]:
		var material := ShaderMaterial.new()
		material.shader = finish
		material.set_shader_parameter("metal", item[1])
		material.set_shader_parameter("rough", item[2])
		material.set_shader_parameter("finish_kind", item[3])
		h._looks[item[0]] = material
	var foliage := ShaderMaterial.new()
	foliage.shader = Shader.new()
	foliage.shader.code = FOLIAGE_SHADER
	h._looks["apartment_foliage"] = foliage

static func _crease(u: float, v: float, centre: Vector2, angle: float, length: float, width: float) -> float:
	var q := Vector2(u,v) - centre
	var along := q.x*cos(angle) + q.y*sin(angle)
	var across := -q.x*sin(angle) + q.y*cos(angle)
	# A finite ridge with a shallow adjacent trough, rather than two
	# crossing periodic waves which made the first pass look quilted.
	var ridge := exp(-pow(across/width,2.0))
	var trough := exp(-pow((across+width*1.8)/(width*1.1),2.0))*.36
	return (ridge-trough) * exp(-pow(along/length,2.0))

static func _point(u: float, v: float, wide: float, deep: float, tall: float, rumple: float) -> Vector3:
	var dome := pow(maxf(0.0, 1.0-pow(absf(u), 5.0)), .35) * pow(maxf(0.0, 1.0-pow(absf(v), 5.0)), .35)
	var loose_cover := rumple >= .018 and minf(wide,deep) > .65
	var folds := _crease(u,v,Vector2(-.65,.06),.35,.58,.10)*.80
	folds += _crease(u,v,Vector2(-.06,.38),-.58,.60,.12)*.70
	folds += _crease(u,v,Vector2(.48,-.30),1.05,.60,.10)
	folds += _crease(u,v,Vector2(-.25,-.72),-.16,.40,.10)*.65
	folds += _crease(u,v,Vector2(.70,.64),-.44,.42,.11)*.70
	var y := tall * (.17 + .83*dome) + folds * rumple * dome
	var corner_pull := .10
	if loose_cover:
		# A duvet is a thin slack envelope on the mattress, not a giant pillow.
		# Side tension falls away into its hem; finite folds survive to the edge.
		var side_drop := smoothstep(.64,1.0,absf(u))
		var end_drop := smoothstep(.74,1.0,absf(v))
		y = tall*(.57+.35*dome-.49*side_drop-.24*end_drop)
		y += folds * rumple * (.48+.52*dome)
		y = maxf(.003,y)
		corner_pull = .035
	return Vector3(u*wide*.5*sqrt(1.0-corner_pull*v*v), y, v*deep*.5*sqrt(1.0-corner_pull*u*u))

static func _normal(u: float, v: float, wide: float, deep: float, tall: float, rumple: float) -> Vector3:
	var du := _point(minf(u+.004,1.0),v,wide,deep,tall,rumple) - _point(maxf(u-.004,-1.0),v,wide,deep,tall,rumple)
	var dv := _point(u,minf(v+.004,1.0),wide,deep,tall,rumple) - _point(u,maxf(v-.004,-1.0),wide,deep,tall,rumple)
	return dv.cross(du).normalized()

static func pad(h: Node3D, xf: Transform3D, wide: float, deep: float, tall: float, tint: Color, rumple := .006, nx := 12, nz := 16, part := "apartment_fabric") -> void:
	var kit: CityKit = h._kit
	var loose_cover := rumple >= .018 and minf(wide,deep) > .65
	if loose_cover:
		# Roughly four-centimetre cells resolve the selected creases without a
		# dense subdivision budget on all pillows, mattresses and seat cushions.
		nx = maxi(nx,32)
		nz = maxi(nz,40)
	for z: int in range(nz):
		for x: int in range(nx):
			var us: Array[float] = [float(x)/nx*2.0-1.0, float(x+1)/nx*2.0-1.0]
			var vs: Array[float] = [float(z)/nz*2.0-1.0, float(z+1)/nz*2.0-1.0]
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			var uv: Array[Vector2] = []
			for p: Vector2 in [Vector2(us[0],vs[0]),Vector2(us[0],vs[1]),Vector2(us[1],vs[1]),Vector2(us[1],vs[0])]:
				points.append(xf * _point(p.x,p.y,wide,deep,tall,rumple))
				normals.append(xf.basis * _normal(p.x,p.y,wide,deep,tall,rumple))
				uv.append(Vector2(p.x*wide*.5,p.y*deep*.5))
			kit.mapped(part,points,normals,uv,[0.0,0.0,0.0,0.0],tint)
	# A curved closed hem joins the cloth face to the underside. No plane
	# pokes beyond the mattress or the collision footprint.
	var boundary: Array[Vector2] = []
	for x: int in range(nx): boundary.append(Vector2(float(x)/nx*2.0-1.0,-1))
	for z: int in range(nz): boundary.append(Vector2(1,float(z)/nz*2.0-1.0))
	for x: int in range(nx): boundary.append(Vector2(1.0-float(x)/nx*2.0,1))
	for z: int in range(nz): boundary.append(Vector2(-1,1.0-float(z)/nz*2.0))
	for i: int in range(boundary.size()):
		var a := boundary[i]
		var b := boundary[(i+1)%boundary.size()]
		var pa := _point(a.x,a.y,wide,deep,tall,rumple)
		var pb := _point(b.x,b.y,wide,deep,tall,rumple)
		var na := xf.basis * Vector3(a.x,0,a.y).normalized()
		var nb := xf.basis * Vector3(b.x,0,b.y).normalized()
		kit.mapped(part,[xf*Vector3(pa.x,0,pa.z),xf*pa,xf*pb,xf*Vector3(pb.x,0,pb.z)],
			[na,na,nb,nb],[Vector2(0,0),Vector2(0,tall),Vector2(pa.distance_to(pb),tall),Vector2(pa.distance_to(pb),0)],
			[0.0,0.0,0.0,0.0],tint,.92)
	# Upholstery piping and a duvet's sewn hem have actual silhouettes. An
	# inset path keeps even the small round seam inside the original footprint.
	var seam: Array[Vector3] = []
	var inset := .020 if loose_cover else .013
	for p: Vector2 in boundary:
		var u := p.x * (1.0-inset/(maxf(wide,.10)*.5))
		var v := p.y * (1.0-inset/(maxf(deep,.10)*.5))
		var on_cloth := _point(u,v,wide,deep,tall,rumple)
		on_cloth += _normal(u,v,wide,deep,tall,rumple) * .0008
		seam.append(xf*on_cloth)
	seam.append(seam[0])
	kit.tube(part,seam,.0012 if loose_cover else .0018,tint.darkened(.075),4,.96)

static func throw_on_sofa(h: Node3D, xf: Transform3D) -> void:
	# A small woven throw spills over the left back cushion, onto the seat.
	var kit: CityKit = h._kit
	const STEPS := 12
	const ROWS := 48
	for row: int in range(ROWS):
		for i: int in range(STEPS):
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			var uv: Array[Vector2] = []
			for corner: Vector2i in [Vector2i(i,row),Vector2i(i,row+1),Vector2i(i+1,row+1),Vector2i(i+1,row)]:
				var u := float(corner.x)/STEPS
				var t := float(corner.y)/ROWS
				var p := _throw_point(u,t)
				var du := _throw_point(u+.002,t)-_throw_point(u-.002,t)
				var dt := _throw_point(u,minf(1.0,t+.002))-_throw_point(u,maxf(0.0,t-.002))
				points.append(xf*p)
				normals.append(xf.basis*dt.cross(du).normalized())
				uv.append(Vector2(u*.36,t*1.05))
			kit.mapped("apartment_fabric",points,normals,uv,[0.0,0.0,0.0,0.0],Color("#74858c"))
	# Folded-over woven edges are heavier than the loose fabric between them.
	for edge: float in [.015,.985]:
		var hem: Array[Vector3] = []
		for row: int in range(ROWS+1):
			hem.append(xf*(_throw_point(edge,float(row)/ROWS)+Vector3(0,.001,0)))
		kit.tube("apartment_fabric",hem,.0015,Color("#6d7f87"),4)
	# Short, irregular grouped fringe hangs from the exposed lower edge.
	for i: int in range(19):
		var u := .035+float(i)*.049
		var end := _throw_point(u,1.0)
		var length := .016 + .004*sin(float(i)*2.7)
		kit.tube("apartment_fabric",[xf*end,xf*(end+Vector3(.001*sin(float(i)), -length*.70, length*.64))],
			.0008,Color("#819198"),4)

static func _throw_point(u: float, t: float) -> Vector3:
	# Clearance from the independently rounded back/seat cushions prevents
	# the crossing cloth/cushion faces seen in the first review.
	var path: Array[Vector2] = [Vector2(-.319,.72),Vector2(-.30,.785),Vector2(-.25,.806),
		Vector2(-.19,.806),Vector2(-.135,.78),Vector2(-.112,.68),Vector2(-.112,.55),
		Vector2(-.090,.445),Vector2(.06,.404),Vector2(.20,.402),Vector2(.28,.378),Vector2(.33,.32)]
	var at := t*float(path.size()-1)
	var row := mini(int(at),path.size()-2)
	var f := at-float(row)
	var p := path[row].cubic_interpolate(path[row+1],path[maxi(0,row-1)],path[mini(path.size()-1,row+2)],f)
	var folds := _crease(u,t,Vector2(.23,.46),1.42,.36,.07)*.009
	folds += _crease(u,t,Vector2(.73,.79),1.30,.30,.065)*.007
	var x := -.58+u*.36
	var seat_sag := .014*pow((x+.335)/.3275,2.0)*smoothstep(.63,.76,t)
	return Vector3(x,p.y+folds-seat_sag,p.x)

