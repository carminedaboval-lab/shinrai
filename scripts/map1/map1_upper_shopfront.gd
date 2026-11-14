extends Node3D
## Street-level commercial tenants of tall or otherwise non-enterable blockout buildings. The existing shell remains
## solid: the glazing shows a shallow display, and makes no promise of a playable floor.
const Rules := preload("res://scripts/map1/map1_house_rules.gd")
const Kit := preload("res://scripts/interior_kit/house_kit.gd")
const JP := {"coffee shop":"喫茶", "ramen shop":"らーめん","sushi counter":"寿司","soba shop":"そば","izakaya":"居酒屋","yakitori bar":"焼鳥","grocer":"青果","rice and liquor shop":"米・酒","set-meal diner":"定食","curry shop":"カレー","convenience store":"商店","tobacco and sweets shop":"菓子"}

const CREAM := Color("#eee2c4")
const WOOD := Color("#704b36")
const DARK := Color("#253233")
const WINDOW := Color("#395057")
const PALE := Color("#a5bdba")
const TRADES := {
	"coffee shop":["喫茶あおい","COFFEE",Color("#386a63")],
	"ramen shop":["麺屋はち","RAMEN",Color("#a34033")],
	"set-meal diner":["あさひ食堂","TEISHOKU",Color("#9a6439")],
	"izakaya":["酒処よりみち","IZAKAYA",Color("#693b43")],
	"sushi counter":["鮨なぎ","SUSHI",Color("#334e63")],
	"yakitori bar":["焼鳥とりよし","YAKITORI",Color("#763e32")],
	"curry shop":["カレーきいろ","CURRY",Color("#b18135")],
	"soba shop":["そば処むぎ","SOBA",Color("#535b48")],
	"convenience store":["まちマート","MART",Color("#327c71")],
	"rice and liquor shop":["米と酒こめや","SAKE",Color("#5a5147")],
	"grocer":["青葉青果","FRESH",Color("#506f42")],
	"tobacco and sweets shop":["かどや菓子店","SWEETS",Color("#82714b")],
}
## Independents take a neighbourhood name; convenience stores keep their chain fascia.
const LOCAL_NAMES := {
	"ramen shop":["麺屋はち","北らーめん","中華そば丸福","味噌らーめんくら"],
	"set-meal diner":["あさひ食堂","ひなた食堂","キッチン伊藤","まち食堂"],
	"sushi counter":["鮨なぎ","鮨かえで","すし魚新"],
	"yakitori bar":["焼鳥とりよし","炭火焼鳥","鳥吉"],
	"izakaya":["酒処よりみち","赤ちょうちん","酒場つき"],
	"curry shop":["カレーきいろ","カレー六","スパイス鳩"],
	"soba shop":["そば処むぎ","そば松","そば処みず"],
	"grocer":["青葉青果","八百かず","八百丸"]
}
var blocks: Array = []
var shapes := SurfaceTool.new()
var profile_count := 0
var sign_faces := 0
var trade := ""
var building := -1
var street_reached := false
var box_height := 0.0
var floors := 0
var frontage := 0.0

static func install(map: Node3D) -> void:
	var group := Node3D.new()
	group.name = "TallShopfronts"
	map.add_child(group)
	for business: Dictionary in map.data.get("businesses",[]):
		var idx := int(business.box)
		var b: Array = map.data.boxes[idx]
		if Rules.floors_of(b) <= 2 and bool(map.world.site(idx).ok): continue
		var face := new()
		group.add_child(face)
		face.name = "Tenant_%d" % idx
		face.building = idx
		face.trade = str(business.what)
		face.place(map,b)
		face.dress()

func place(map: Node3D, b: Array) -> void:
	box_height = float(b[4])
	floors = Rules.floors_of(b)
	var centre := Vector3(b[0],0,b[2])
	var turn := Rules.box_basis(b)
	var best := -INF
	for side: int in 4:
		var out: Vector3 = turn * [Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT][side]
		var along := Vector3(out.z,0,-out.x)
		var wid := float(b[3] if side%2 == 0 else b[5])
		var deep := float(b[5] if side%2 == 0 else b[3])
		var wall := centre+out*(deep*0.5)
		var nearest := INF
		var open := 0.0
		for edge: float in [-0.28,0,0.28]:
			for n: int in range(1,29):
				var step := wall + along * wid * edge + out * n
				if map.world.solid_at(step.x,step.z,building): break
				open += 1.0
				if map.world.road_at(step.x,step.z):
					nearest=minf(nearest,n)
					break
		var quality := (100.0-nearest if nearest < INF else open/3.0) + minf(wid,10)*0.04
		if quality <= best: continue
		best = quality
		street_reached = nearest < INF
		position = map.on_ground(wall.x,wall.z,0.035) + out * 0.035
		rotation.y = atan2(out.x,out.z)
		frontage = minf(wid-0.28,10.4)

func part(x:float,y:float,z:float,w:float,h:float,d:float,c:Color,angle:=0.0) -> void:
	blocks.append([Transform3D(Basis(Vector3.RIGHT,angle)*Basis.from_scale(Vector3(w,h,d)),Vector3(x,y,z)),c])

## Axially symmetric ceramics and paper lanterns, baked together per frontage.
func profile(x:float,y:float,z:float,levels:Array, tint:Color, segments:=16) -> void:
	for n: int in segments:
		var aa := TAU*n/segments
		var bb := TAU*(n+1)/segments
		for j: int in range(levels.size()-1):
			var lo: Vector2 = levels[j]
			var hi: Vector2 = levels[j+1]
			var a := Vector3(x+cos(aa)*lo.x, y+lo.y,z+sin(aa)*lo.x)
			var b := Vector3(x+cos(bb)*lo.x, y+lo.y,z+sin(bb)*lo.x)
			var c := Vector3(x+cos(bb)*hi.x, y+hi.y,z+sin(bb)*hi.x)
			var d := Vector3(x+cos(aa)*hi.x, y+hi.y,z+sin(aa)*hi.x)
			var norm := Vector3(cos((aa+bb)*0.5)*(hi.y-lo.y),lo.x-hi.x,sin((aa+bb)*0.5)*(hi.y-lo.y)).normalized()
			for v: Vector3 in [a,b,c,a,c,d]:
				shapes.set_normal(norm)
				shapes.set_color(tint)
				shapes.add_vertex(v)
	profile_count+=1

## Put the glyph triangles on the same surface as the lanterns and ceramics.
func words(text: String, fallback: String, at: Vector3, width: float, height: float, angle:=0.0) -> void:
	var glyphs := Kit.sign_shape(text)
	if glyphs.corners.is_empty(): glyphs=Kit.sign_shape(fallback)
	if glyphs.corners.is_empty(): return
	var fit:=minf(width/glyphs.size.x,height/glyphs.size.y)
	var turn:=Basis(Vector3.UP,angle)
	for point: Vector3 in glyphs.corners:
		shapes.set_normal(turn.z)
		shapes.set_color(CREAM)
		shapes.add_vertex(at+turn*(point*fit))
	sign_faces+=1

func dress() -> void:
	shapes.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := frontage
	var tenant: Array = TRADES.get(trade,[trade.to_upper(),"SHOP",WOOD])
	var brand := str(tenant[0])
	var short_name := str(tenant[1])
	var display_word := str(JP.get(trade,short_name))
	var colour: Color = tenant[2]
	var area_key := floori(position.x/128.0)*7 + floori(position.z/128.0)*3
	if LOCAL_NAMES.has(trade):
		var options: Array = LOCAL_NAMES[trade]
		brand = str(options[posmod(area_key,options.size())])
		colour = colour.lerp([Color("#ad825f"),Color("#645d56"),Color("#6c6249")][posmod(area_key,3)],0.16)
	var local_cafe := building % 3
	if trade == "coffee shop":
		local_cafe = posmod(roundi(global_position.x),3)
		brand = ["喫茶あおい","珈琲はと","喫茶なぎ"][local_cafe]
		colour = [Color("#385957"),Color("#734c38"),Color("#4d5465")][local_cafe]
	var food := trade not in ["convenience store","grocer","tobacco and sweets shop","rice and liquor shop"]
	var coffee := trade == "coffee shop"
	var fabric := food and not coffee
	# Upper tenancy reads as separate floors: recessed-looking windows, sills, occasional
	# closed blinds. They stay outside the solid shell, without advertising playable rooms.
	var cols := clampi(floori(w/2.15),2,5)
	for level: int in range(1,floors):
		var cy := (level+0.5) * box_height/floors
		for col: int in cols:
			var x := (float(col+0.5)/cols-0.5)*w
			var ww := minf(1.32, w/cols-0.26)
			part(x,cy,0.052,ww+0.12,1.48,0.09,DARK)
			part(x,cy,0.109,ww,1.34,0.038,WINDOW.lightened(0.16))
			part(x,cy,0.14,0.054,1.36,0.03,PALE)
			part(x,cy-0.73,0.12,ww+0.20,0.085,0.22,PALE)
			if (building+level+col)%4==0:
				part(x,cy+0.4,0.139,ww,0.48,0.045,Color("#b3aba0"))
	part(0,1.49,0.055,w,2.96,0.11,WOOD if food else DARK)
	part(0,2.71,0.14,w+0.02,0.46,0.22,colour)
	words(brand,short_name,Vector3(0,2.73,0.262),w-0.2,0.32)
	var door_x := -w*0.31
	part(door_x,1.15,0.13,w*0.23,2.2,0.10,WINDOW)
	part(door_x-w*0.072,1.0,0.21,0.05,0.30,0.07,CREAM)
	var display := w*0.155
	var dw := w*0.57
	part(display,1.38,0.13,dw,1.76,0.12,WINDOW)
	part(display,0.52,0.22,dw+0.10,0.11,0.24,WOOD)
	for j: int in 4:
		part(display+(j/3.0-0.5)*dw,1.38,0.22,0.065,1.78,0.06,WOOD if food else PALE)
	if coffee:
		# Narrow copper valance, broad picture window and a lit shelf of ceramic cups.
		part(display,2.26,0.43,dw+0.18,0.09,0.76,colour,0.14)
		part(display,1.02,0.26,dw*0.93,0.09,0.18,WOOD)
		for j: int in 4:
			var cx := display+(j-1.5)*dw*0.18
			profile(cx,1.065,0.36,[Vector2(0.048,0),Vector2(0.08,0.11),Vector2(0.078,0.14),Vector2(0.063,0.14),Vector2(0.055,0.08)],CREAM)
			part(cx+0.078,1.15,0.36,0.055,0.078,0.04,CREAM)
		for j: int in 2:
			var x := display+(j-0.5)*dw*0.48
			part(x,2.0,0.24,0.025,0.29,0.025,DARK)
			profile(x,1.81,0.37,[Vector2(0.17,0),Vector2(0.11,0.09),Vector2(0.046,0.13)],Color("#ce995a"))
		words("自家焙煎","COFFEE",Vector3(display,0.76,0.235),dw*0.82,0.17)
	elif fabric:
		# An actual split curtain over the entry; lanterns, screens and the foods separate trades.
		for j: int in 4:
			var curtain_x := door_x+(j-1.5)*w*0.06
			part(curtain_x,2.03-(j%2)*0.04,0.32,w*0.055,0.58,0.065,colour.lightened(0.12))
			part(curtain_x,1.81-(j%2)*0.04,0.356,w*0.05,0.034,0.014,CREAM)
		part(door_x,2.38,0.32,w*0.265,0.055,0.085,WOOD)
		if trade in ["izakaya","yakitori bar","ramen shop"]:
			var qty := 3 if trade == "izakaya" else (2 if trade=="yakitori bar" else 1)
			for j: int in qty:
				var x := display+(j-(qty-1)*0.5)*0.45
				profile(x,2.0,0.46,[Vector2(0.09,-0.25),Vector2(0.16,-0.17),Vector2(0.18,0),Vector2(0.16,0.17),Vector2(0.09,0.25)],Color("#cc613d"))
				for dy: float in [-0.22,-0.12,0.12,0.22]:
					var radius := 0.13 if absf(dy)>0.2 else 0.175
					profile(x,2.0+dy,0.46,[Vector2(radius,-0.012),Vector2(radius,0.012)],DARK)
			if trade == "ramen shop":
				# An order window, three sample bowls and a stack of lacquer trays.
				part(display,1.01,0.34,dw*0.94,0.095,0.42,WOOD)
				for n: int in 3:
					var bx := display+(n-1)*dw*0.21
					profile(bx,1.06,0.45,[Vector2(0.095,0),Vector2(0.19,0.14),Vector2(0.185,0.16),Vector2(0.158,0.16),Vector2(0.10,0.06)],CREAM)
		elif trade in ["sushi counter","soba shop"]:
			for j: int in 10:
				part(display+(j/9.0-0.5)*dw,1.46,0.29,0.045,1.38,0.07,WOOD)
			part(display,0.84,0.40,dw,0.13,0.45,CREAM)
		else:
			for j: int in 3:
				part(display+(j-1)*dw*0.25,1.39,0.24,dw*0.18,0.49,0.025,CREAM)
				part(display+(j-1)*dw*0.25,1.43,0.262,dw*0.12,0.09,0.018,colour)
	else:
		# Projecting striped awning and stocked display at the wall, off the walkway.
		for j: int in 9:
			part(display+(j-4)*dw/9.0,2.21,0.40,dw/9.0,0.12,0.70,colour if j%2==0 else CREAM,0.18)
		for j: int in 3:
			var x := display+(j-1)*dw*0.29
			part(x,0.56,0.34,dw*0.25,0.23,0.38,WOOD if trade=="grocer" else PALE)
			for k: int in 4:
				var q := x+(k-1.5)*dw*0.05
				if trade=="rice and liquor shop":
					profile(q,0.68,0.40,[Vector2(0.048,0),Vector2(0.048,0.16),Vector2(0.022,0.21),Vector2(0.022,0.26)],Color("#82704b") if j%2==0 else Color("#507566"))
				else:
					part(q,0.72,0.39,dw*0.045,0.13,0.14,[Color("#b45036"),Color("#819050"),Color("#c39955")][j])
	# A double-sided blade is readable when walking parallel to the building.
	var blade_x := w*0.44
	part(blade_x,2.50,0.49,0.12,0.82,0.80,colour)
	for sign_side: int in [-1,1]:
		words(display_word,short_name,Vector3(blade_x+sign_side*0.068,2.5,0.49),0.69,0.29,sign_side*PI*0.5)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = BoxMesh.new()
	multi.instance_count = blocks.size()
	for j: int in blocks.size():
		multi.set_instance_transform(j,blocks[j][0])
		multi.set_instance_color(j,blocks[j][1])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	node.material_override = mat
	if profile_count>0 or sign_faces>0:
		var detail := MeshInstance3D.new()
		shapes.index()
		detail.mesh=shapes.commit()
		detail.material_override=mat
		detail.visibility_range_end=120
		add_child(detail)
	node.visibility_range_end = 185
	add_child(node)
