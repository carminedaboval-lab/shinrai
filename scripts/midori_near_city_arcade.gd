extends "res://scripts/midori_near_city_handmade.gd"
## ゲームポンポコ 緑公園前店: the game centre next to the police box, built the way the Akihabara
## ones really are. Only the street face gets the loud enamel; the sides are the same plain
## cladding as any office. Each storey has a glazed front and its own lit band, so the street can
## see what it sells: print club booths, cabinets, a medal pusher, and VR rooms on top. A corner
## board stands up on steel with its lamps out on long arms, and the posters are lit from the
## lightbox below. The prizes leave by drone now, and the crane machines still cost two hundred yen.
## Local origin is the middle of the lot's street front.
const ATLAS := "res://assets/shinrai/near_city/arcade_atlas.png"
const ART := "res://assets/shinrai/near_city/arcade_art.png"
const LANE_ATLAS := "res://assets/shinrai/near_city/lane_atlas.png"
const CUT_SHADER := preload("res://scripts/midori_near_city_cutout.gdshader")
const WASH_SHADER := preload("res://scripts/midori_near_city_wash.gdshader")
const SHADE_SHADER := preload("res://scripts/midori_near_city_shade.gdshader")
const SHINE_SHADER := preload("res://scripts/midori_near_city_shine.gdshader")
const PLUSH_SHADER := preload("res://scripts/midori_near_city_plush.gdshader")
const ORB_SHADER := preload("res://scripts/midori_near_city_orb.gdshader")
const POOL_SHADER := preload("res://scripts/midori_near_city_pool.gdshader")
const WIDE := 7.18
const DEEP := 7.68
const HEAD := 3.0
const LIGHT_LOW := 3.15
const LIGHT_HIGH := 4.55
const TOP := 15.7
const ENTRY_X0 := 1.2
const ENTRY_X1 := 5.9
const GLASS_Z := -.95
const ROOM := 5.6
const CRANE_ATLAS := "res://assets/shinrai/near_city/crane_atlas.png"
const FLOORS_ATLAS := "res://assets/shinrai/near_city/floors_atlas.png"
const FLOORS_PHOTO := "res://assets/shinrai/near_city/floors_photo.png"
const VR_WALL := "res://assets/shinrai/near_city/vr_wall.png"
const VR_TANUKI := Rect2(0, 24.0 / 1024.0, 512.0 / 1536.0, 972.0 / 1024.0)
const VR_TITLE := Rect2(512.0 / 1536.0, 0, 1024.0 / 1536.0, 300.0 / 1024.0)
const MEDALS: Array[Vector2] = [Vector2(572, 38), Vector2(630, 49), Vector2(672, 98), Vector2(735, 77), Vector2(816, 73), Vector2(787, 110), Vector2(852, 116), Vector2(909, 98), Vector2(905, 38), Vector2(583, 133), Vector2(631, 165), Vector2(696, 157), Vector2(819, 165), Vector2(882, 180), Vector2(748, 189), Vector2(677, 213), Vector2(805, 226), Vector2(990, 208), Vector2(965, 132), Vector2(941, 226), Vector2(803, 30)] # Whole coins lying on top in the photograph.
const MOTION_TURN := PI + .25 # Square to the door, near enough, as an installer would leave it.
const QUIET: Array[String] = ["front", "wash", "lamp", "panel", "led", "room", "sign", "poster", "art", "screen", "gold", "goods", "cut", "prize", "carpet", "crane_lit", "crane_sign", "crane_screen", "floor_print", "floor_lit", "floor_screen", "print_screen", "photo_print", "photo_lit", "case_lamp", "shade", "shine", "orb", "vanity", "pool", "spill", "shine_hall", "sign_in", "led_low", "wash_in", "lamp_in", "led_in", "neon_in", "photo_in", "coin", "steel_in", "vinyl_in", "cut_vr", "cloth", "wash_vr"]
const ROOM_TINT := Color(1.0, .98, .95)
const ROOM_NIGHT_TINT := Color(.65, .79, 1.0) # The shader browns all it lights after dark; this hands it back.
const ROOM_DAY := 1.2
const ROOM_NIGHT := 2.7
const NIGHT_STEEL := .72 # Bright metal mirrors the room, so a lamp's tint cannot reach it; it takes less browning.
const CLUB_AIR := Color(1.0, .95, .88) # 2F by day: the room's own warm tubes, not the blue sky the windows never let this far in.
const CLUB_AIR_ENERGY := .4
const VR_AIR := Color(.92, .92, .94) # 5F by day: the sky's blue would turn every black in the rooms navy.
const VR_AIR_ENERGY := .3
const VR_POOL := 1.1 # How far a room downlight's pool reaches from 2.34 m up.
const CAB_W := 1.24
const CAB_D := .95
const BACK_ROW := -4.4 # Far enough back to leave a clear metre behind the front row.
const GLASS_TOP := 2.1
const COIL_TOP := 1.95
const POD_REST := 1.72
const POD_LOW := 1.38
const ARM_X := .15
const ARM_Y := -.09
const TOY := Vector3(.122, .082, .1)
const TOY_Y := 1.085
const CLAW_HOME := Vector2(.34, -.26)
const CLAW_GRAB := Vector2(-.02, -.34)
const STAIR_X := 1.2 # Where the flights start, east of the door landings.
const TREAD := .28
const BAND_N := -5.72
const BAND_MID := -6.66
const BAND_S := -7.6
const UPPER_END := 4.44
const TURN_CEILING := 5.2 # Over the long first flight, high enough to clear your head on the way back.
const STAIR_TOP := 15.33
const STAIR_DOOR := Vector2(.4, 1.2)
const ROOM_HIGH := 2.34
const CRANE_END := 14.2
const WAKE_REACH := 2.8
const ROOM_X0 := .15
const ROOM_X1 := 7.0
const DOOR_X := 3.55
const WALK_X0 := -28.6 # The walk from the crossing by the side road, in street-front metres.
const WALK_X1 := 11.4
const WALK_Z := 15.6
const STOREY := 2.7
const BAND := .5
const GLASS_X0 := .3
const GLASS_X1 := 4.9
const COBALT := Color(.03, .12, .62)
const SHUT := Color(.012, .03, .16)
const JOINT := Color(.1, .15, .34)
const AWNING := Color("#a8240c")
const INK := Color("#101014")
const STEELWORK := Color("#3e4044")
const BOARD_LOW := TOP + .7
const BOARD_HIGH := TOP + 3.9
const BOARD_X0 := -.35
const BOARD_X1 := 7.45
const BOARD_FRONT := .1
const BOARD_BACK := -2.25

var _cranes: Array[Dictionary] = []
var _sliders: Array[Dictionary] = []
var _door_open := 0.0
var _wake_rest := 0.0
var _fire: Array[Node3D] = []
var _shelves: Array[Dictionary] = []
var _ground: StaticBody3D = null
var _room_lamps: Array[Light3D] = []
var _probe: ReflectionProbe = null
var _mirror_probe: ReflectionProbe = null
var _vr_probe: ReflectionProbe = null
var _hall_probe: ReflectionProbe = null
var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))

func _ready() -> void:
	_rng.seed = 120
	add_to_group("playable_buildings")
	_build_looks()
	_solids()
	_enamel_front()
	_plain_sides()
	_roof()
	_piers()
	_lightbox()
	_awning()
	_entry()
	_inside()
	_doors()
	_stairs()
	_fire_doors()
	_upper_solids()
	_floors()
	_wall_posters()
	_blade()
	_board()
	_pavement()
	_kit.commit(self, _looks, QUIET)
	_kit = null
	_omni("Arcade", Vector3(0, 2.5, -.35), ROOM_NIGHT_TINT, 1.9, 8.0)
	# No window reaches the machines, so the room's own tubes burn all day.
	for row: Array in [["ArcadeRoom", -2.2], ["ArcadeFloor", -4.2]]:
		_omni(row[0], Vector3(0, 2.6, row[1]), ROOM_TINT, ROOM_DAY, 6.0)
		var lamp: Light3D = _lamps.pop_back()
		lamp.visible = true
		lamp.light_specular = .04 # Long tubes, not a bulb: no hot spot on anything glossy.
		lamp.distance_fade_enabled = true
		lamp.distance_fade_begin = 40.0
		lamp.distance_fade_length = 10.0
		_room_lamps.append(lamp)
	# The motion seat is the one thing on 5F the painted light cannot reach round, so its door-side
	# downlight is real: narrow enough to stay inside the partitions, which it would light through.
	var seat_lamp := SpotLight3D.new()
	seat_lamp.name = "VrSeatLamp"
	seat_lamp.transform = Transform3D(Basis.looking_at(Vector3(0, -1, .42)), _front * Vector3(2.58, _storey_base(3) + .34 + ROOM_HIGH - .04, -3.85))
	seat_lamp.light_color = Color(1.0, .95, .88)
	seat_lamp.light_energy = 1.6
	seat_lamp.light_specular = .25
	seat_lamp.spot_range = 3.2
	seat_lamp.spot_angle = 19.0
	seat_lamp.spot_angle_attenuation = .7
	seat_lamp.shadow_enabled = false
	add_child(seat_lamp)
	# A polished floor only shines if it has a room to mirror; nothing here adds ambient.
	_probe = ReflectionProbe.new()
	_probe.name = "ArcadeShine"
	_probe.position = _front * Vector3((ROOM_X0 + ROOM_X1) * .5, 1.5, (GLASS_Z - .01 - ROOM) * .5)
	_probe.size = Vector3(6.85, 3.0, 4.65)
	_probe.interior = true
	_probe.box_projection = true
	_probe.blend_distance = 0.0
	_probe.intensity = 1.0
	_probe.max_distance = 12.0
	_probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(_probe)
	# A make-up mirror needs something to show: 2F looked at once, from the stools, at each change of light.
	_mirror_probe = ReflectionProbe.new()
	_mirror_probe.name = "PrintClubMirror"
	# The box stands 5 cm proud of floor, walls and ceiling: laid on them, it takes or misses each face by rounding.
	_mirror_probe.position = _front * Vector3(2.59, _storey_base(0) + .34 + ROOM_HIGH * .5, -2.87)
	_mirror_probe.size = Vector3(4.88, ROOM_HIGH + .1, 5.56)
	_mirror_probe.origin_offset = Vector3(.16, .2, -1.18)
	_mirror_probe.interior = true
	_mirror_probe.box_projection = true
	_mirror_probe.blend_distance = 0.0
	_mirror_probe.max_distance = 8.0
	_mirror_probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	_mirror_probe.ambient_color = CLUB_AIR
	_mirror_probe.ambient_color_energy = CLUB_AIR_ENERGY
	_mirror_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(_mirror_probe)
	# 5F is all black surfaces, and left alone they mirror the open sky and read navy by day.
	_vr_probe = ReflectionProbe.new()
	_vr_probe.name = "VrRooms"
	_vr_probe.position = _front * Vector3(2.59, _storey_base(3) + .34 + ROOM_HIGH * .5, -2.87)
	_vr_probe.size = Vector3(4.88, ROOM_HIGH + .1, 5.56)
	_vr_probe.interior = true
	_vr_probe.box_projection = true
	_vr_probe.blend_distance = 0.0
	_vr_probe.max_distance = 8.0
	_vr_probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	_vr_probe.ambient_color = VR_AIR
	_vr_probe.ambient_color_energy = VR_AIR_ENERGY
	_vr_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(_vr_probe)
	# 3F's terrazzo is polished like the old halls': it only shines if something shows the screens and lamps to it.
	_hall_probe = ReflectionProbe.new()
	_hall_probe.name = "ArcadeHall"
	_hall_probe.position = _front * Vector3(2.59, _storey_base(1) + .34 + ROOM_HIGH * .5, -2.87)
	_hall_probe.size = Vector3(4.88, ROOM_HIGH + .1, 5.56)
	_hall_probe.origin_offset = Vector3(0, -.4, 0)
	_hall_probe.interior = true
	_hall_probe.box_projection = true
	_hall_probe.blend_distance = 0.0
	_hall_probe.max_distance = 8.0
	_hall_probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	_hall_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(_hall_probe)

func set_night_mode(value: bool) -> void:
	super(value)
	# The shader weights daylight about three times heavier, so the same room takes less lamp by day.
	for lamp: Light3D in _room_lamps:
		lamp.light_energy = ROOM_NIGHT if value else ROOM_DAY
		lamp.light_color = ROOM_NIGHT_TINT if value else ROOM_TINT
	if _probe != null:
		for look: ShaderMaterial in [_looks.chrome, _looks.fitting]:
			look.set_shader_parameter("night", NIGHT_STEEL if value else 0.0)
		_looks.mirror.set_shader_parameter("night", 0.0) # Glass gives back what it sees, unbrowned.
		_probe.update_mode = ReflectionProbe.UPDATE_ONCE
		_mirror_probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED if value else ReflectionProbe.AMBIENT_COLOR
		_mirror_probe.update_mode = ReflectionProbe.UPDATE_ONCE
		_vr_probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED if value else ReflectionProbe.AMBIENT_COLOR
		_vr_probe.update_mode = ReflectionProbe.UPDATE_ONCE
		_hall_probe.update_mode = ReflectionProbe.UPDATE_ONCE

func _build_looks() -> void:
	_shared_looks()
	var signs: Texture2D = load(ATLAS)
	var art: Texture2D = load(ART)
	var crane: Texture2D = load(CRANE_ATLAS)
	var grime: Texture2D = load(TEXTURES + "arcade_enamel.png")
	_looks.ceil = _look("plastered_wall_03", 1.4, .95)
	_looks.ceil.set_shader_parameter("chroma", .1)
	_looks.ceil.set_shader_parameter("glow", .55)
	_looks.ceil.set_shader_parameter("day_glow", .42)
	_looks.panel = _look("", 1.0, .5)
	_looks.panel.set_shader_parameter("glow", 1.5)
	_looks.panel.set_shader_parameter("day_glow", 1.1)
	_looks.ceil_pale = _look("", 1.0, .9)
	_looks.ceil_pale.set_shader_parameter("glow", .62)
	_looks.ceil_pale.set_shader_parameter("day_glow", .5)
	_looks.paper_pale = _look("", 1.0, .8)
	_looks.paper_pale.set_shader_parameter("glow", .6)
	_looks.paper_pale.set_shader_parameter("day_glow", .46)
	_looks.paint = _look("", 1.0, .8)
	_looks.paint.set_shader_parameter("glow", .55)
	_looks.paint.set_shader_parameter("day_glow", .42)
	_looks.vinyl = _look("", 1.0, .35)
	_looks.vinyl.set_shader_parameter("glow", .5)
	_looks.vinyl.set_shader_parameter("day_glow", .3)
	_looks.plaster = _look("white_stucco", 2.2, .9)
	_looks.plaster.set_shader_parameter("chroma", .3)
	_looks.plaster.set_shader_parameter("glow", .6)
	_looks.plaster.set_shader_parameter("day_glow", .34)
	var orb := ShaderMaterial.new() # A booth's globes are the shot: they burn the same at any hour.
	orb.shader = ORB_SHADER
	_looks.orb = orb
	_looks.vanity = _look("", 1.0, .5)
	_looks.vanity.set_shader_parameter("glow", 2.0)
	_looks.vanity.set_shader_parameter("day_glow", 2.0)
	_looks.mirror = _look("", 1.0, .04, 1.0)
	_looks.case_lamp = _look("", 1.0, .5)
	_looks.case_lamp.set_shader_parameter("glow", 3.2)
	_looks.case_lamp.set_shader_parameter("day_glow", 2.6)
	_looks.dado = _look("", 1.0, .22)
	_looks.dado.set_shader_parameter("glow", .4)
	_looks.dado.set_shader_parameter("day_glow", .3)
	_looks.paper = _look("plastered_wall_03", 2.2, .85)
	_looks.paper.set_shader_parameter("chroma", .3)
	_looks.paper.set_shader_parameter("glow", .55)
	_looks.paper.set_shader_parameter("day_glow", .42)
	_looks.stair = _look("", 1.0, .75)
	_looks.stair.set_shader_parameter("glow", .3)
	_looks.stair.set_shader_parameter("day_glow", .2)
	_looks.stairwall = _look("plastered_wall_03", 3.0, .9)
	_looks.stairwall.set_shader_parameter("chroma", .2)
	_looks.stairwall.set_shader_parameter("glow", .5)
	_looks.stairwall.set_shader_parameter("day_glow", .4)
	for row: Array in [["terrazzo", "arcade_terrazzo.jpg", 2.0, .16, .2, .16], ["terrazzo_tan", "arcade_terrazzo.jpg", 1.0, .07, .5, .42], ["lattice", "arcade_lattice.png", .24, .8, .55, .42], ["tile", "arcade_tile.jpg", 1.2, .3, .42, .34], ["mosaic", "arcade_mosaic.jpg", 1.8, .28, .52, .4], ["rug", "arcade_carpet.jpg", .8, .95, .5, .36], ["rug_line", "arcade_carpet_line.png", 1.2, .95, .3, .22], ["speck", "arcade_terrazzo.jpg", 2.0, .6, .35, .3]]:
		var look := _look("", row[2], row[3])
		look.set_shader_parameter("albedo_map", load(TEXTURES + row[1]))
		look.set_shader_parameter("glow", row[4])
		look.set_shader_parameter("day_glow", row[5])
		_looks[row[0]] = look
	_looks.terrazzo.set_shader_parameter("chroma", .12)
	_looks.terrazzo_tan.set_shader_parameter("chroma", .5)
	_looks.speck.set_shader_parameter("chroma", .1)
	_looks.spray = _look("plastered_wall_03", .7, 1.0)
	_looks.spray.set_shader_parameter("chroma", .45)
	_looks.spray.set_shader_parameter("glow", .34) # A black slab stays black at night too.
	_looks.spray.set_shader_parameter("day_glow", .42)
	_looks.boards = _look("japanese_cedar_planks", .7, .6)
	_looks.boards.set_shader_parameter("albedo_map", load(TEXTURES + "arcade_boards.jpg")) # Charcoal stain, its dark planks evened out so no band repeats up the wall.
	_looks.boards.set_shader_parameter("glow", .3)
	_looks.boards.set_shader_parameter("day_glow", .18)
	_looks.cloth = _look("", 1.0, .9) # Heavy matte drape: a shade paler than the wall it hangs in.
	_looks.cloth.set_shader_parameter("glow", .6)
	_looks.cloth.set_shader_parameter("day_glow", .6)
	_looks.shell = _look("", 1.0, .3)
	_looks.shell.set_shader_parameter("glow", .55)
	_looks.shell.set_shader_parameter("day_glow", .22)
	_looks.shell_in = _look("", 1.0, .3) # 3F: no lamp reaches these after dark, so a shell's own glow is all its form; keep it low.
	_looks.shell_in.set_shader_parameter("glow", .3)
	_looks.shell_in.set_shader_parameter("day_glow", .22)
	_looks.led_low = _look("", 1.0, .3) # 3F's small lights: at the shared led's night level they all burn to white and lose their colour.
	_looks.led_low.set_shader_parameter("glow", .85)
	_looks.led_low.set_shader_parameter("day_glow", .55)
	for row: Array in [["lamp_in", .5, 3.2], ["led_in", .3, 1.5], ["neon_in", .3, 2.6]]: # 4F's machines are its light, at any hour.
		var look := _look("", 1.0, row[1])
		look.set_shader_parameter("glow", row[2])
		look.set_shader_parameter("day_glow", row[2])
		_looks[row[0]] = look
	_looks.steel_in = _look("", 1.0, .3, .35) # No sky gets in here to mirror, so 4F's steel holds its own cool grey.
	_looks.steel_in.set_shader_parameter("glow", .25)
	_looks.steel_in.set_shader_parameter("day_glow", .25)
	_looks.vinyl_in = _look("", 1.0, .6) # 4F's seats: worn black vinyl, a silhouette against the machines, not a sheen.
	_looks.vinyl_in.set_shader_parameter("glow", .1)
	_looks.vinyl_in.set_shader_parameter("day_glow", .1)
	_looks.coin = _look("", 1.0, .32, .8) # The medals under a pusher's roof lamps, day or night.
	_looks.coin.set_shader_parameter("glow", .75)
	_looks.coin.set_shader_parameter("day_glow", .75)
	_looks.chrome = _look("", 1.0, .16, .9)
	_looks.fitting = _look("", 1.0, .42, .55)
	_looks.gloss = _look("", 1.0, .1)
	_looks.gloss.set_shader_parameter("glow", .55)
	_looks.gloss.set_shader_parameter("day_glow", .34)
	_looks.clad = _look("", 1.0, .34, .2)
	_looks.frame = _look("", 1.0, .42, .5)
	for look: ShaderMaterial in [_looks.clad, _looks.frame]:
		look.set_shader_parameter("albedo_map", grime)
		look.set_shader_parameter("tile", 5.0)
	_looks.render = _look("exterior_wall_cladding", 3.0, .9)
	_looks.render.set_shader_parameter("chroma", .5)
	_looks.stone = _look("", 1.0, .2)
	_looks.room = _look("", 1.0, .55)
	_looks.room.set_shader_parameter("glow", .55)
	_looks.room.set_shader_parameter("day_glow", .3)
	_looks.carpet = _look("", 1.0, .9)
	_looks.carpet.set_shader_parameter("albedo_map", signs)
	_looks.carpet.set_shader_parameter("glow", .4)
	_looks.carpet.set_shader_parameter("day_glow", .2)
	_looks.prize = _look("", 1.0, .75)
	_looks.prize.set_shader_parameter("glow", .62)
	_looks.prize.set_shader_parameter("day_glow", .5)
	var floors: Texture2D = load(FLOORS_ATLAS)
	var photos: Texture2D = load(FLOORS_PHOTO)
	for row: Array in [["photo_print", photos, .45, .3], ["photo_lit", photos, .9, .45], ["photo_in", photos, .9, .9], ["floor_print", floors, .4, .2], ["floor_lit", floors, 1.0, 1.0], ["floor_screen", floors, 1.6, 1.6], ["print_screen", floors, 1.05, .8], ["crane_print", crane, .34, .14], ["crane_lit", crane, .9, .8], ["crane_sign", crane, .85, .8], ["crane_screen", crane, 1.5, .7], ["sign", signs, 1.0, .3], ["sign_in", signs, 1.0, .9], ["poster", signs, .55, .22], ["art", art, .5, .16], ["screen", art, 1.3, .7], ["board", art, .22, .08], ["goods", load(LANE_ATLAS), .7, .2]]:
		var look := _look("", 1.0, .7)
		look.set_shader_parameter("albedo_map", row[1])
		look.set_shader_parameter("glow", row[2])
		look.set_shader_parameter("day_glow", row[3])
		_looks[row[0]] = look
	var cut := ShaderMaterial.new()
	cut.shader = CUT_SHADER
	cut.set_shader_parameter("atlas", signs)
	cut.set_shader_parameter("glow", .62)
	cut.set_shader_parameter("day_glow", .5)
	_looks.cut = cut
	var cut_vr := ShaderMaterial.new() # 5F's decals, printed straight on the boards so no plate shows.
	cut_vr.shader = CUT_SHADER
	cut_vr.set_shader_parameter("atlas", load(VR_WALL))
	cut_vr.set_shader_parameter("glow", .5)
	cut_vr.set_shader_parameter("day_glow", .4)
	_looks.cut_vr = cut_vr
	_looks.gold = _look("", 1.0, .32, .8)
	_looks.gold.set_shader_parameter("glow", .6)
	_looks.gold.set_shader_parameter("day_glow", .3)
	var plush := ShaderMaterial.new()
	plush.shader = PLUSH_SHADER
	plush.set_shader_parameter("faces", crane)
	plush.set_shader_parameter("day_glow", .62) # The case lamps do not know what time it is.
	_looks.plush = plush
	var wash := ShaderMaterial.new()
	wash.shader = WASH_SHADER
	_looks.wash = wash
	var wash_in := ShaderMaterial.new() # 4F's machines throw their colour on the carpet whatever the hour.
	wash_in.shader = WASH_SHADER
	wash_in.set_shader_parameter("day_level", .7)
	_looks.wash_in = wash_in
	var wash_vr := ShaderMaterial.new() # 5F's downlights stand off the wall, so their fall starts broad.
	wash_vr.shader = WASH_SHADER
	wash_vr.set_shader_parameter("day_level", .7)
	wash_vr.set_shader_parameter("throat", .5)
	_looks.wash_vr = wash_vr
	var pool := ShaderMaterial.new() # 3F's light: no real lamp, and nothing for the hour to turn off.
	pool.shader = POOL_SHADER
	_looks.pool = pool
	var spill := ShaderMaterial.new()
	spill.shader = POOL_SHADER
	spill.set_shader_parameter("fan", 1.0)
	_looks.spill = spill
	var shine := ShaderMaterial.new()
	shine.shader = SHINE_SHADER
	shine.render_priority = -1 # Under the dark at each machine's foot, not over it.
	_looks.shine = shine
	var hall := ShaderMaterial.new() # 3F's terrazzo: the same polish, its own lamps.
	hall.shader = SHINE_SHADER
	hall.render_priority = -1
	_looks.shine_hall = hall
	var shade := ShaderMaterial.new()
	shade.shader = SHADE_SHADER
	_looks.shade = shade

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _enamel_front() -> void:
	# Enamel round the outside and a glazed storey for every floor, so the street can see what
	# each one sells. The right-hand column stays solid for the posters, the plant and the hatch.
	var f := _front
	var columns: Array[float] = [0.0, GLASS_X0, 2.6, GLASS_X1, 6.04, WIDE]
	var levels: Array[float] = []
	for i: int in range(4):
		levels.append(_storey_base(i))
		levels.append(_storey_base(i) + BAND)
	levels.append(_storey_base(4))
	levels.append(TOP)
	var holes: Array[Rect2] = []
	for i: int in range(4):
		holes.append(Rect2(GLASS_X0, _storey_base(i) + BAND, GLASS_X1 - GLASS_X0, STOREY - BAND))
	var hatch := Rect2(5.45, 10.55, 1.0, 2.4)
	holes.append(hatch)
	for row: int in range(levels.size() - 1):
		var y: float = levels[row]
		var tall: float = levels[row + 1] - y
		for i: int in range(columns.size() - 1):
			var tone := _rng.randf_range(.9, 1.08)
			var lean := _rng.randf_range(-.02, .02)
			var side := _rng.randf_range(-.014, .014)
			for piece: Rect2 in _minus(Rect2(columns[i], y, columns[i + 1] - columns[i], tall), holes):
				var a := f * Vector3(piece.position.x, piece.position.y, side)
				var b := f * Vector3(piece.position.x, piece.end.y, side + lean)
				var c := f * Vector3(piece.end.x, piece.end.y, lean)
				var d := f * Vector3(piece.end.x, piece.position.y, 0)
				_kit.quad("clad", a, b, c, d, Color(COBALT.r * tone, COBALT.g * tone, COBALT.b * tone), .9, 1.0, .06, Vector2(columns[i] * 1.7, y * 1.3))
	for x: float in columns:
		for piece: Rect2 in _minus(Rect2(x - .028, LIGHT_HIGH, .056, TOP - LIGHT_HIGH), holes):
			_bar("frame", f, piece.get_center().x, piece.get_center().y, .016, Vector3(piece.size.x, piece.size.y, .04), JOINT)
	for y: float in levels:
		for piece: Rect2 in _minus(Rect2(0, y - .028, WIDE, .056), holes):
			_bar("frame", f, piece.get_center().x, piece.get_center().y, .016, Vector3(piece.size.x, piece.size.y, .04), JOINT)
	_reveal(f, hatch, .14, Color("#2a2c34"))
	_kit.quad("clad", f * Vector3(hatch.position.x, hatch.position.y, -.14), f * Vector3(hatch.position.x, hatch.end.y, -.14), f * Vector3(hatch.end.x, hatch.end.y, -.14), f * Vector3(hatch.end.x, hatch.position.y, -.14), SHUT, .8, 1.0, .4)
	_bar("frame", f, hatch.get_center().x, hatch.get_center().y, -.1, Vector3(hatch.size.x, .05, .06), Color("#6a6e78"))
	# Bare aluminium where somebody cut in the fibre and never had the panel re-enamelled.
	_bar("frame", f, 6.69, TOP - .8, .012, Vector3(.9, 1.3, .02), Color("#8f959c"))
	_bar("metal", f, 6.7, TOP - .8, .08, Vector3(.42, .5, .12), Color("#55585c"))
	_status(f, 6.8, TOP - .64, .146, GREEN)
	_status(f, 6.72, TOP - .64, .146, AMBER)
	_fibre([f * Vector3(7.06, TOP + .05, .1), f * Vector3(7.06, TOP - .8, .1), f * Vector3(6.9, TOP - .8, .1)])

func _storey_base(i: int) -> float:
	return LIGHT_HIGH + float(i) * STOREY

func _inside() -> void:
	# A real ground floor: charcoal terrazzo polished hard, a pale ceiling with its services on
	# show, painted walls over a laminate dado, and the machines.
	var f := _front
	var near := GLASS_Z - .01
	_floor_tiles(.02, ROOM_X0, ROOM_X1, near, -ROOM, Color(.2, .2, .21), Color(.19, .19, .2), "terrazzo", 1.8, Color(.34, .3, .22))
	_ceiling()
	var length := ROOM_X1 - ROOM_X0
	var deep := ROOM + near
	_wall(Transform3D(Basis.IDENTITY, f * Vector3(ROOM_X0, 0, -ROOM)), length, [Rect2(STAIR_DOOR.x - ROOM_X0, 0, STAIR_DOOR.y - STAIR_DOOR.x, 2.12)], Color(.92, .74, .16))
	_wall(Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(ROOM_X0, 0, near)), deep, [])
	_wall(Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(ROOM_X1, 0, -ROOM)), deep, [])
	# Behind the glass line: the piers either side, seen from inside.
	var inner := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), f * Vector3(ROOM_X1, 0, near))
	_wall(inner, length, [Rect2(ROOM_X1 - ENTRY_X1, 0, ENTRY_X1 - ENTRY_X0, HEAD)])
	_stair_door()
	_wall_dressing()
	# Back from the glass in pairs, with room to stand at each one and an aisle from the door.
	# Each row: where it stands, what it sells, the side not against a neighbour, and its stock.
	for row: Array in [[.96, 0, [-1.0], true], [2.2, 1, [1.0], false], [4.9, 2, [-1.0], false], [6.14, 0, [1.0], false]]:
		_cabinet(Transform3D(Basis.IDENTITY, f * Vector3(row[0], .02, -2.2)), row[1], false, row[2], row[3])
		_solid(row[0] - .62, row[0] + .62, 0, 2.36, -3.15, -2.0)
	_cabinet(Transform3D(Basis.IDENTITY, f * Vector3(2.5, .02, BACK_ROW)), 0, true)
	_rhythm(Transform3D(Basis.IDENTITY, f * Vector3(4.65, .02, BACK_ROW)))
	_cabinet(Transform3D(Basis.IDENTITY, f * Vector3(5.9, .02, BACK_ROW)), 2, true)
	_solid(1.88, 3.12, 0, 2.36, BACK_ROW - CAB_D, BACK_ROW + .2)
	_solid(4.22, 5.08, 0, 2.36, BACK_ROW - .72, BACK_ROW + .25)
	_solid(5.28, 6.52, 0, 2.36, BACK_ROW - CAB_D, BACK_ROW + .2)
	var feet := PackedVector4Array()
	for foot: Rect2 in [Rect2(.34, -3.15, 2.48, .95), Rect2(4.28, -3.15, 2.48, .95), Rect2(1.88, BACK_ROW - CAB_D, 1.24, CAB_D), Rect2(4.22, BACK_ROW - .72, .86, .72), Rect2(5.28, BACK_ROW - CAB_D, 1.24, CAB_D)]:
		_contact(foot)
		var a := f * Vector3(foot.position.x, 0, foot.position.y)
		var b := f * Vector3(foot.end.x, 0, foot.end.y)
		feet.append(Vector4(a.x, a.z, b.x, b.z))
	# The polish, one quad over the terrazzo: what it mirrors is traced in its shader.
	var y := .0235
	_kit.quad("shine", f * Vector3(ROOM_X0, y, near), f * Vector3(ROOM_X0, y, -ROOM), f * Vector3(ROOM_X1, y, -ROOM), f * Vector3(ROOM_X1, y, near), Color.WHITE)
	var first := f * Vector3(1.1, 0, -1.9)
	_looks.shine.set_shader_parameter("lamp_first", Vector2(first.x, first.z))
	_looks.shine.set_shader_parameter("lamp_step", Vector2(2.45, -2.7))
	_looks.shine.set_shader_parameter("feet", feet)

func _contact(foot: Rect2, y := .024) -> void:
	# The dark round a machine's foot, gone a hand's width out, since nothing in here casts a shadow.
	var f := _front
	var reach := .24
	var x0 := foot.position.x
	var x1 := foot.end.x
	var z0 := foot.position.y
	var z1 := foot.end.y
	var inner: Array[Vector3] = [f * Vector3(x0, y, z0), f * Vector3(x0, y, z1), f * Vector3(x1, y, z1), f * Vector3(x1, y, z0)]
	var outer: Array[Vector3] = [f * Vector3(x0 - reach, y, z0 - reach), f * Vector3(x0 - reach, y, z1 + reach), f * Vector3(x1 + reach, y, z1 + reach), f * Vector3(x1 + reach, y, z0 - reach)]
	for i: int in range(4):
		var j := (i + 1) % 4
		_kit.quad("shade", inner[j], outer[j], outer[i], inner[i], Color.WHITE, .42, 1.0)

func _ceiling() -> void:
	# Pale board, painted and left plain, with surface battens in two straight rows and the
	# building's services run where anyone can see them. The air-con, sprinklers, detectors and
	# speakers are cut straight into it.
	var f := _front
	var near := GLASS_Z - .01
	var step := .6
	var x := ROOM_X0
	while x < ROOM_X1 - .01:
		var x1 := minf(x + step, ROOM_X1)
		var z := near
		while z > -ROOM + .01:
			var z1 := maxf(z - step, -ROOM)
			var tone := _rng.randf_range(.98, 1.02)
			_kit.quad("ceil_pale", f * Vector3(x, HEAD, z1), f * Vector3(x, HEAD, z), f * Vector3(x1, HEAD, z), f * Vector3(x1, HEAD, z1), Color(.84 * tone, .82 * tone, .76 * tone))
			z = z1
		x = x1
	for batten_z: float in [-1.9, -4.6]:
		for batten_x: float in [1.1, 3.55, 6.0]:
			_bar("plain", f, batten_x, HEAD - .035, batten_z, Vector3(1.25, .07, .16), Color("#e8e6e0"))
			for lane: float in [-.034, .034]:
				_bar("panel", f, batten_x, HEAD - .074, batten_z + lane, Vector3(1.18, .012, .05), Color(.96, .95, 1.0))
	_services()
	for at: Vector2 in [Vector2(2.2, -3.4), Vector2(5.2, -3.4)]:
		_air_con(at)
	for at: Vector2 in [Vector2(.9, -1.4), Vector2(3.0, -1.4), Vector2(4.8, -1.4), Vector2(6.4, -1.4), Vector2(.9, -4.4), Vector2(3.6, -4.8), Vector2(6.4, -4.4)]:
		_sprinkler(f * Vector3(at.x, HEAD, at.y))
	for at: Vector2 in [Vector2(3.5, -2.2), Vector2(1.5, -5.1)]:
		_detector(f * Vector3(at.x, HEAD, at.y))
	for at: Vector2 in [Vector2(1.8, -2.9), Vector2(5.4, -2.9), Vector2(3.5, -3.9)]:
		_speaker(f * Vector3(at.x, HEAD, at.y))
	_camera(f * Vector3(3.5, HEAD, -3.1))
	# The way out, hung over the doors, green and on all night by law.
	_bar("plain", f, 3.55, HEAD - .3, -1.4, Vector3(.62, .2, .08), Color("#e8e8e4"))
	_panel("crane_lit", Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), f * Vector3(3.85, 0, -1.445)), 0, .6, HEAD - .39, HEAD - .21, 0, _cell(420, 1920, 360, 120))
	for x_at: float in [3.3, 3.8]:
		_kit.tube("metal", [f * Vector3(x_at, HEAD, -1.4), f * Vector3(x_at, HEAD - .2, -1.4)], .006, Color("#6a6c70"), 4)

func _services() -> void:
	# Nobody boxes these in on a plain ceiling. Thin, colour-coded, and clipped on in the order the
	# trades arrived: the red sprinkler main first, tight to the slab, then power in yellow under
	# it, then green data.
	var f := _front
	var near := GLASS_Z - .01
	var red := Color("#b0180e")
	var yellow := Color("#d8b020")
	var green := Color("#3c9a50")
	_kit.tube("paint", [f * Vector3(ROOM_X0, 2.955, -1.1), f * Vector3(ROOM_X1, 2.955, -1.1)], .03, red, 8)
	for x: float in [.9, 3.0, 4.8, 6.4]:
		_kit.tube("paint", [f * Vector3(x, 2.955, -1.1), f * Vector3(x, 2.955, -1.4)], .012, red, 6)
	for i: int in range(3):
		var y := 2.9 - float(i % 2) * .032
		var run := .29 + float(i) * .055
		var turn := -5.41 + float(i) * .055
		_kit.tube("paint", [f * Vector3(run, y, near), f * Vector3(run, y, turn + .1), f * Vector3(run + .03, y, turn + .03), f * Vector3(run + .1, y, turn), f * Vector3(ROOM_X1, y, turn)], .018, yellow, 6)
	for y: float in [2.894, 2.866]:
		_kit.tube("paint", [f * Vector3(ROOM_X0, y, -5.5), f * Vector3(ROOM_X1, y, -5.5)], .014, green, 6)
	# The later trunk, up the same way as the power and through the ceiling to the risers.
	_fibre([f * Vector3(.21, 2.88, near), f * Vector3(.21, 2.88, -5.2), f * Vector3(.21, 2.93, -5.26), f * Vector3(.21, HEAD, -5.26)])
	var tag := -1.6
	while tag > -5.2:
		_bar("led", f, .21, 2.853, tag, Vector3(.05, .01, .018), CYAN)
		tag -= 2.0
	var hangers: Array[Vector3] = []
	var x_at := .7
	while x_at < ROOM_X1:
		hangers.append(Vector3(x_at, 2.98, -1.1))
		hangers.append(Vector3(x_at, 2.915, -5.41))
		hangers.append(Vector3(x_at + .2, 2.908, -5.5))
		x_at += 1.5
	var z_at := -1.6
	while z_at > -5.2:
		hangers.append(Vector3(.29, 2.915, z_at))
		hangers.append(Vector3(.4, 2.915, z_at))
		z_at -= 1.5
	for at: Vector3 in hangers:
		_kit.tube("metal", [f * Vector3(at.x, HEAD, at.z), f * at], .005, Color("#8a8c90"), 4)

func _air_con(at: Vector2, top := HEAD, body := Color(.91, .89, .83)) -> void:
	# A four-way cassette as they really are: a thin off-white plate, a raised grille of fine slats
	# on three ribs, a long rounded outlet with its flap on each side, and an indicator in one corner.
	var f := _front
	var shade := _rng.randf_range(.93, 1.0)
	var skin := Color(body.r * shade, body.g * shade, body.b * shade)
	var centre := f * Vector3(at.x, top, at.y)
	_plate(centre, .475, .06, 0.0, .022, skin)
	for turn: int in range(4):
		var side := Transform3D(Basis(Vector3.UP, PI * .5 * float(turn)), centre)
		var hole := Color("#0b0b0d")
		_kit.quad("plain", side * Vector3(-.28, -.0225, .296), side * Vector3(-.28, -.0225, .372), side * Vector3(.28, -.0225, .372), side * Vector3(.28, -.0225, .296), hole)
		for x: float in [-.28, .28]:
			_kit.disc("plain", side * Vector3(x, -.0225, .334), side.basis.x, side.basis.z, .038, hole)
		# The flap, hinged at the outer edge and hanging a little open.
		_kit.quad("room", side * Vector3(-.27, -.046, .304), side * Vector3(-.27, -.027, .366), side * Vector3(.27, -.027, .366), side * Vector3(.27, -.046, .304), skin * .86)
		for x: float in [-.27, .27]:
			_bar("room", side, x, -.03, .335, Vector3(.012, .03, .06), skin * .7)
	_plate(centre + Vector3.DOWN * .022, .272, .04, 0.0, .02, skin * 1.03)
	var grid := Transform3D(Basis.IDENTITY, centre)
	_kit.quad("plain", grid * Vector3(-.216, -.0425, -.216), grid * Vector3(-.216, -.0425, .216), grid * Vector3(.216, -.0425, .216), grid * Vector3(.216, -.0425, -.216), Color("#101012"))
	var z := -.208
	while z < .21:
		_bar("room", grid, 0, -.0445, z, Vector3(.43, .003, .0078), skin)
		z += .0165
	for x: float in [-.1075, 0.0, .1075]:
		_bar("room", grid, x, -.0462, 0, Vector3(.008, .004, .43), skin)
	# The maker's badge, and the receiver with its one green light.
	_bar("plain", grid, 0, -.0432, -.244, Vector3(.07, .002, .014), Color("#5a5a5c"))
	_bar("plain", grid, .39, -.0232, .39, Vector3(.05, .002, .026), Color("#3a3a3c"))
	_bar("led", grid, .378, -.0245, .39, Vector3(.008, .002, .008), GREEN)

func _plate(centre: Vector3, half: float, corner: float, lift: float, thick: float, tint: Color) -> void:
	# A rounded square hanging under `centre`: its face, and the short edge up to what it hangs from.
	var ring: Array[Vector3] = []
	for c: int in range(4):
		var base := PI * .5 * float(c)
		var at := Vector3(cos(base + PI * .25), 0, sin(base + PI * .25)) * (half - corner) * sqrt(2.0)
		for i: int in range(6):
			var a := base + PI * .5 * float(i) / 5.0
			ring.append(at + Vector3(cos(a), 0, sin(a)) * corner)
	var face := centre + Vector3.DOWN * (lift + thick)
	for i: int in range(ring.size()):
		var p: Vector3 = ring[i]
		var q: Vector3 = ring[(i + 1) % ring.size()]
		_kit.quad("room", face, face + q, face + p, face + p, tint)
		_kit.quad("room", centre + q + Vector3.DOWN * lift, centre + p + Vector3.DOWN * lift, face + p, face + q, tint * .84)

func _sprinkler(at: Vector3, plate := Color("#d8d8d4"), brass := Color("#c0a040")) -> void:
	_kit.disc("metal", at + Vector3.DOWN * .03, Vector3.RIGHT, Vector3.BACK, .04, plate)
	_kit.lathe("metal", at + Vector3.DOWN * .07, [Vector2(.012, 0), Vector2(.008, .02), Vector2(.012, .04)], brass, 8)
	_kit.disc("metal", at + Vector3.DOWN * .072, Vector3.RIGHT, Vector3.BACK, .018, brass)

func _detector(at: Vector3, body := Color("#e8e8e4")) -> void:
	_kit.lathe("plain", at + Vector3.DOWN * .06, [Vector2(.05, 0), Vector2(.06, .04), Vector2(.05, .06)], body, 16)
	_kit.disc("plain", at + Vector3.DOWN * .06, Vector3.RIGHT, Vector3.BACK, .05, body.darkened(.08))
	_kit.disc("led", at + Vector3.DOWN * .062, Vector3.RIGHT, Vector3.BACK, .006, Color(1.0, .1, .08))

func _speaker(at: Vector3, rim := Color("#d8d8d4"), cone := Color("#2a2a2e")) -> void:
	_kit.disc("plain", at + Vector3.DOWN * .03, Vector3.RIGHT, Vector3.BACK, .11, rim)
	_kit.disc("plain", at + Vector3.DOWN * .033, Vector3.RIGHT, Vector3.BACK, .085, cone)

func _dome(at: Vector3) -> void:
	# The ordinance dome in the black a dark floor orders it in.
	_kit.lathe("metal", at + Vector3.DOWN * .06, [Vector2(.03, 0), Vector2(.075, .03), Vector2(.075, .06)], Color("#26262a"), 10)
	_kit.lathe("bottle", at + Vector3.DOWN * .12, [Vector2(0, 0), Vector2(.05, .012), Vector2(.07, .06)], Color("#0d0e11"), 10)

func _stair_door() -> void:
	# The arrow over the way up.
	_panel("poster", Transform3D(Basis.IDENTITY, _front * Vector3(ROOM_X0, 0, -ROOM)), .32, .98, 2.2, 2.86, .012, _cell(910, 1250, 280, 330))

func _wall_dressing() -> void:
	# What actually hangs on a game centre wall: prints in frames, the law, and the fire kit.
	var f := _front
	var west := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(ROOM_X0, 0, GLASS_Z - .01))
	var east := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(ROOM_X1, 0, -ROOM))
	var back := Transform3D(Basis.IDENTITY, f * Vector3(ROOM_X0, 0, -ROOM))
	_framed(west, .4, 1.3, 1.42, 2.72, "art", _cell(0, 0, 1024, 1200))
	_framed(west, 2.5, 3.4, 1.42, 2.72, "sign", _cell(1410, 1110, 300, 420))
	_framed(east, .5, 1.35, 1.42, 2.72, "sign", _cell(1830, 552, 200, 260))
	_framed(east, 2.7, 3.6, 1.42, 2.72, "art", _cell(1024, 0, 1024, 1200))
	_framed(back, 3.0, 3.9, 1.58, 2.02, "crane_print", _cell(0, 1850, 400, 190))
	# Extinguisher in its red bracket and the fire bell, by the way out, where the inspector wants them.
	var kit := 1.4
	_bar("plain", back, kit, .92, .04, Vector3(.26, .78, .08), Color("#c01818"))
	_kit.lathe("gloss", back * Vector3(kit, .02, .13), [Vector2(.075, 0), Vector2(.08, .5), Vector2(.05, .58), Vector2(.018, .62)], Color("#d01414"), 16)
	_kit.tube("plain", [back * Vector3(kit, .64, .13), back * Vector3(kit + .12, .58, .13), back * Vector3(kit + .1, .22, .13)], .009, Color("#101014"), 5)
	_bar("fitting", back, kit, 1.72, .03, Vector3(.28, .28, .06), Color("#b01414"))
	_kit.disc("gloss", back * Vector3(kit, 1.72, .062), back.basis.x, back.basis.y, .09, Color("#d81818"))
	_bar("led", back, kit, 1.92, .03, Vector3(.05, .05, .03), Color(1.0, .1, .08))
	_solid(ROOM_X0 + kit - .14, ROOM_X0 + kit + .14, 0, 1.98, -ROOM, -ROOM + .21)
	# The plant box, high on the wall with its conduit up into the ceiling, and its louvre.
	_bar("plain", west, 3.9, 2.3, .08, Vector3(.5, .4, .16), Color("#d4d4cc"))
	for i: int in range(5):
		_bar("plain", west, 3.9, 2.2 + float(i) * .05, .1615, Vector3(.4, .012, .003), Color("#8e8e88"))
	_kit.tube("metal", [west * Vector3(3.9, 2.5, .02), west * Vector3(3.9, HEAD, .02)], .014, Color("#b8b8b0"), 6) # Tight to the wall, behind the fibre.
	_solid(ROOM_X0, ROOM_X0 + .16, 2.1, 2.5, -5.11, -4.61)
	# The staff's blue step, left against the wall where it was last wanted.
	var blue := Color("#1c3f9c")
	_bar("plain", f, .275, .235, -4.5, Vector3(.23, .03, .34), Color("#c4c8cc"))
	for z: float in [-4.36, -4.64]:
		_bar("plain", f, .275, .11, z, Vector3(.21, .22, .03), blue)
	_bar("plain", f, .275, .08, -4.5, Vector3(.05, .025, .26), blue)
	_solid(.16, .39, 0, .25, -4.67, -4.33)

func _framed(face: Transform3D, x0: float, x1: float, y0: float, y1: float, part: String, rect: Rect2) -> void:
	_bar("fitting", face, (x0 + x1) * .5, (y0 + y1) * .5, .012, Vector3(x1 - x0 + .05, y1 - y0 + .05, .024), Color("#c8ccd0"))
	_panel(part, face, x0, x1, y0, y1, .026, rect)

func _solid(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> void:
	# One box the player cannot walk through, given in street-front metres.
	if _ground == null:
		_ground = StaticBody3D.new()
		_ground.name = "ArcadeCollision"
		_ground.collision_layer = 1
		_ground.collision_mask = 0
		_ground.add_to_group("midori_walk_surface")
		add_child(_ground)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, y1 - y0, z1 - z0)
	shape.shape = box
	shape.position = _front * Vector3((x0 + x1) * .5, (y0 + y1) * .5, (z0 + z1) * .5)
	_ground.add_child(shape)

func _solids() -> void:
	# The way here from the park's outside pavement, then the building itself. Street-front metres:
	# +z runs back towards the park, and the rail's gap by the side road is the crossing.
	var lane := -.08
	_solid(WALK_X0, WALK_X1, lane - 1.0, lane, -.2, WALK_Z)
	_solid(0, WIDE, -1.0, .02, -DEEP, -.2)
	_solid(ENTRY_X0, ENTRY_X1, -1.0, .03, GLASS_Z, 0)
	# Edges of the walk: rail, poles, and the fronts of the neighbours.
	_solid(WALK_X0, -.2, -.1, 3.0, 1.1, 1.3)
	_solid(-.2, 0, -.1, 3.0, 0, 1.3)
	_solid(WIDE, WALK_X1, -.1, 3.0, -.2, 0)
	# The pavement continues east to Fukumaru's residential stair.
	_solid(WALK_X1, WALK_X1 + .2, -.1, 3.0, 3.4, WALK_Z)
	_solid(WALK_X0 - .2, WALK_X0, -.1, 3.0, 1.1, WALK_Z)
	for run: Vector2 in [Vector2(WALK_X0, -25.6), Vector2(-1.6, 8.4), Vector2(8.9, WALK_X1)]:
		_solid(run.x, run.y, -.1, .86, 9.55, 9.65)
	for post: Vector3 in [Vector3(-.6, 5.0, .17), Vector3(-12.6, 8.0, .1)]:
		_solid(post.x - post.z, post.x + post.z, -.1, 3.0, post.y - post.z, post.y + post.z)
	# The shell: piers, side lights over the door line, walls, and everything above the ceiling.
	_solid(0, ENTRY_X0, 0, HEAD, GLASS_Z, .22)
	_solid(ENTRY_X1, WIDE, 0, HEAD, GLASS_Z, .22)
	_solid(ENTRY_X0, 2.35, 0, HEAD, GLASS_Z - .05, GLASS_Z + .05)
	_solid(4.75, ENTRY_X1, 0, HEAD, GLASS_Z - .05, GLASS_Z + .05)
	_solid(2.35, 4.75, 2.57, HEAD, GLASS_Z - .05, GLASS_Z + .05)
	# Things that stand in the way.
	_solid(1.2, 1.64, 0, 1.66, -.92, -.04)
	_solid(6.08, 7.0, 0, 1.9, 0, .74)
	_solid(4.86, 5.34, 0, .92, .6, 1.1)

func contains_world_point(point: Vector3) -> bool:
	# The raid's edge makes room for this one building and the walk over the road to it.
	var at := _front.affine_inverse() * to_local(point)
	return at.x >= WALK_X0 and at.x <= WALK_X1 and at.z >= -DEEP and at.z <= WALK_Z + .5

func _doors() -> void:
	# Two glass leaves that slide apart behind the side lights when someone walks up.
	var bronze := Color("#26262a")
	var shared := _kit
	for side: float in [-1.0, 1.0]:
		var leaf := AnimatableBody3D.new()
		leaf.name = "SlidingDoor"
		leaf.collision_layer = 1
		leaf.collision_mask = 0
		leaf.sync_to_physics = false
		leaf.position = _front * Vector3(DOOR_X + side * .6, 0, GLASS_Z)
		add_child(leaf)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.2, 2.5, .06)
		shape.shape = box
		shape.position = Vector3(0, 1.31, 0)
		leaf.add_child(shape)
		_kit = Kit.new()
		var here := Transform3D.IDENTITY
		_kit.quad("front", Vector3(-.6, .06, .004), Vector3(-.6, 2.56, .004), Vector3(.6, 2.56, .004), Vector3(.6, .06, .004), Color.WHITE)
		_kit.quad("front", Vector3(.6, .06, -.004), Vector3(.6, 2.56, -.004), Vector3(-.6, 2.56, -.004), Vector3(-.6, .06, -.004), Color.WHITE)
		for x: float in [-.57, .57]:
			_bar("metal", here, x, 1.31, 0, Vector3(.06, 2.5, .05), bronze)
		for y: float in [.09, 2.53]:
			_bar("metal", here, 0, y, 0, Vector3(1.2, .06, .05), bronze)
		_bar("chrome", here, -side * .5, 1.1, 0, Vector3(.025, .7, .09), Color("#c8ccd0"))
		_seal(leaf, Vector3.ZERO, 0.0)
		_sliders.append({"leaf": leaf, "home": leaf.position.x, "side": side})
	_kit = shared

func _run_doors(eye: Vector3, delta: float) -> void:
	var at := _front.affine_inverse() * to_local(eye)
	var wanted := 1.0 if Vector2(at.x - DOOR_X, at.z - GLASS_Z).length() < 2.6 else 0.0
	_door_open = move_toward(_door_open, wanted, delta * 1.5)
	var eased := smoothstep(0.0, 1.0, _door_open)
	for slider: Dictionary in _sliders:
		(slider.leaf as Node3D).position.x = slider.home + float(slider.side) * eased * 1.14

func _floor_y(i: int) -> float:
	# 0 is the shop floor, 1 to 4 are 2F to 5F.
	return .02 if i == 0 else _storey_base(i - 1) + .34

func _stairs() -> void:
	# A plain concrete dog-leg behind the back wall, the only way up: from the landing by each door,
	# east along the front half, round a turning landing, and back west along the rear half.
	for i: int in range(4):
		var y0 := _floor_y(i)
		var y1 := _floor_y(i + 1)
		var mid := (y0 + y1) * .5
		var steps := 14 if i == 0 else 8
		var turn := STAIR_X + float(steps) * TREAD
		_flight(STAIR_X, turn, y0, mid, BAND_MID + .04, BAND_N, steps, BAND_N - .05)
		_flight(turn, STAIR_X, mid, y1, BAND_S, BAND_MID - .04, steps, BAND_S + .05)
		_landing(turn, turn + 1.0, mid)
		_landing(ROOM_X0, STAIR_X, y1)
		_bar("stairwall", _front, (STAIR_X + turn) * .5, (y0 + y1) * .5, BAND_MID, Vector3(turn - STAIR_X, y1 - y0, .08), Color("#c4c8c0"))
		_solid(STAIR_X, turn, y0, y1, BAND_MID - .04, BAND_MID + .04)
		_stair_lamp(Vector3((turn + turn + 1.0) * .5, mid + 2.05, BAND_S + .03))
		_stair_lamp(Vector3(.7, y1 + 2.05, BAND_S + .03))
	_stair_lamp(Vector3(.7, 2.05, BAND_S + .03))
	_stair_shell()
	for i: int in range(5):
		_stair_opening(_floor_y(i))
		var number := _cell(922, 1122, 92, 96) if i == 0 else _cell(0, 1620.0 + float(i - 1) * 105.0, 170, 100)
		_panel("sign", Transform3D(Basis.IDENTITY, _front * Vector3(0, 0, BAND_S)), .34, .96, _floor_y(i) + 1.3, _floor_y(i) + 1.72, .012, number)

func _flight(xa: float, xb: float, ya: float, yb: float, z0: float, z1: float, steps: int, rail_z: float) -> void:
	var f := _front
	var tread := absf(xb - xa) / float(steps)
	var towards := signf(xb - xa)
	var wide := z1 - z0
	var mid_z := (z0 + z1) * .5
	for k: int in range(steps):
		var u := float(k + 1) / float(steps)
		var top := lerpf(ya, yb, u)
		var x := lerpf(xa, xb, (float(k) + .5) / float(steps))
		_bar("stair", f, x, top - .16, mid_z, Vector3(tread, .32, wide), Color("#3c403c"))
		_bar("metal", f, x - towards * (tread * .5 - .02), top + .001, mid_z, Vector3(.04, .006, wide - .04), Color("#c0a040"))
	_ramp(xa, xb, ya, yb, z0, z1)
	# The sloping underside, seen from the flight below.
	var low_a := f * Vector3(xa, ya - .3, z0)
	var low_b := f * Vector3(xa, ya - .3, z1)
	var high_b := f * Vector3(xb, yb - .3, z1)
	var high_a := f * Vector3(xb, yb - .3, z0)
	if towards > 0.0:
		_kit.quad("stairwall", low_a, low_b, high_b, high_a, Color("#b8bcb4"))
	else:
		_kit.quad("stairwall", high_a, high_b, low_b, low_a, Color("#b8bcb4"))
	# Handrail on the wall, on brackets, the same steel tube on every floor since 1996.
	var rail: Array[Vector3] = [f * Vector3(xa, ya + .86, rail_z), f * Vector3(xb, yb + .86, rail_z)]
	_kit.tube("chrome", rail, .018, Color("#a8acb0"), 8)
	for u: float in [.1, .5, .9]:
		var at := Vector3(lerpf(xa, xb, u), lerpf(ya, yb, u) + .8, rail_z)
		_kit.tube("metal", [f * at, f * (at + Vector3(0, .06, 0))], .008, Color("#6a6c70"), 5)

func _ramp(xa: float, xb: float, ya: float, yb: float, z0: float, z1: float) -> void:
	_solid(0, 1, 0, 1, z0, z1)
	var shape: CollisionShape3D = _ground.get_child(_ground.get_child_count() - 1)
	var along := Vector2(xb - xa, yb - ya)
	if along.x < 0.0:
		along = -along # Always tilted from its low-x end, so "up" stays up for either direction.
	var box := BoxShape3D.new()
	box.size = Vector3(along.length() + .1, .3, z1 - z0)
	shape.shape = box
	var tilt := Basis(Vector3.BACK, atan2(along.y, along.x))
	shape.transform = _front * Transform3D(tilt, Vector3((xa + xb) * .5, (ya + yb) * .5, (z0 + z1) * .5) + tilt * Vector3(0, -.15, 0))

func _landing(x0: float, x1: float, y: float) -> void:
	_bar("stair", _front, (x0 + x1) * .5, y - .14, (BAND_N + BAND_S) * .5, Vector3(x1 - x0, .28, BAND_N - BAND_S), Color("#3c403c"))
	_solid(x0, x1, y - .28, y, BAND_S, BAND_N)

func _stair_lamp(at: Vector3) -> void:
	# The bulkhead lamp in its cage, on all night because the fire brigade says so.
	var spot := _front * at
	_bar("metal", _front, at.x, at.y, at.z + .02, Vector3(.3, .16, .04), Color("#b8bab6"))
	_ball(spot + Vector3.BACK * .05, Vector3(.13, .07, .04), Color(1.0, .95, .84), "panel", 6, 14)

func _stair_shell() -> void:
	# Painted concrete on four sides, with a line at each floor where the pour stopped.
	var f := _front
	var paint := Color(.62, .66, .6)
	var east := 6.2
	var doors: Array[Rect2] = []
	for i: int in range(5):
		doors.append(Rect2(east - STAIR_DOOR.y, _floor_y(i), STAIR_DOOR.y - STAIR_DOOR.x, 2.1))
	var south := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), f * Vector3(east, 0, BAND_N))
	var north := Transform3D(Basis.IDENTITY, f * Vector3(ROOM_X0, 0, BAND_S))
	var west := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(ROOM_X0, 0, BAND_N))
	var end := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(east, 0, BAND_S))
	var high := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(UPPER_END, 0, BAND_S))
	var rows: Array = [[south, east - ROOM_X0, 0.0, doors], [north, east - ROOM_X0, 0.0, []], [west, BAND_N - BAND_S, 0.0, []], [end, BAND_N - BAND_S, 0.0, []], [high, BAND_N - BAND_S, TURN_CEILING, []]]
	for row: Array in rows:
		var face: Transform3D = row[0]
		var length: float = row[1]
		var from: float = row[2]
		var holes: Array[Rect2] = []
		holes.assign(row[3])
		var top := STAIR_TOP if from > 0.0 or length < 3.0 and face != end else (TURN_CEILING if face == end else STAIR_TOP)
		for piece: Rect2 in _minus(Rect2(0, from, length, top - from), holes):
			_kit.quad("stairwall", face * Vector3(piece.position.x, piece.position.y, 0), face * Vector3(piece.position.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.position.y, 0), paint, .94, 1.0, 0.0, Vector2(piece.position.x, -piece.position.y))
	# Ceiling over the turn of the first flight, and over the top landing.
	_kit.quad("stairwall", f * Vector3(UPPER_END, TURN_CEILING, BAND_S), f * Vector3(UPPER_END, TURN_CEILING, BAND_N), f * Vector3(east, TURN_CEILING, BAND_N), f * Vector3(east, TURN_CEILING, BAND_S), paint * .9)
	_kit.quad("stairwall", f * Vector3(ROOM_X0, STAIR_TOP, BAND_S), f * Vector3(ROOM_X0, STAIR_TOP, BAND_N), f * Vector3(UPPER_END, STAIR_TOP, BAND_N), f * Vector3(UPPER_END, STAIR_TOP, BAND_S), paint * .9)
	# The block under the first flight back, closed off.
	var closet := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(STAIR_X, 0, BAND_S))
	_kit.quad("stairwall", closet * Vector3(0, 0, 0), closet * Vector3(0, 4.59, 0), closet * Vector3(BAND_MID - .04 - BAND_S, 4.59, 0), closet * Vector3(BAND_MID - .04 - BAND_S, 0, 0), paint)
	_kit.quad("stairwall", f * Vector3(ROOM_X0, .02, BAND_S), f * Vector3(ROOM_X0, .02, BAND_N), f * Vector3(STAIR_X, .02, BAND_N), f * Vector3(STAIR_X, .02, BAND_S), Color("#5c6058"))

func _stair_opening(y: float) -> void:
	# A steel frame through the wall; the door itself is the game's own, hung in it.
	var f := _front
	var x0 := STAIR_DOOR.x
	var x1 := STAIR_DOOR.y
	var head := y + 2.1
	var frame := Color("#2a2c30")
	for x: float in [x0 - .02, x1 + .02]:
		_bar("metal", f, x, y + 1.05, (BAND_N - ROOM) * .5, Vector3(.05, 2.1, -ROOM - BAND_N + .06), frame)
	_bar("metal", f, (x0 + x1) * .5, head + .02, (BAND_N - ROOM) * .5, Vector3(x1 - x0 + .09, .05, -ROOM - BAND_N + .06), frame)
	var into := -ROOM
	_kit.quad("plain", f * Vector3(x0, head, BAND_N), f * Vector3(x0, head, into), f * Vector3(x1, head, into), f * Vector3(x1, head, BAND_N), Color("#3a3c40"))
	# The room's floor stops at the wall's face and the landing starts at its back: a steel sill spans the wall between.
	_bar("metal", f, (x0 + x1) * .5, y - .012, (BAND_N - ROOM) * .5, Vector3(x1 - x0, .03, -ROOM - BAND_N + .04), frame)

func _upper_solids() -> void:
	var floors := [1, 2, 3, 4]
	_solid(0, WIDE, HEAD, _floor_y(1), -ROOM, .22)
	_solid(-.2, ROOM_X0, 0, HEAD, -ROOM, GLASS_Z)
	_solid(ROOM_X1, WIDE + .2, 0, HEAD, -ROOM, GLASS_Z)
	_solid(0, STAIR_DOOR.x, 0, HEAD, BAND_N, -ROOM)
	_solid(STAIR_DOOR.y, WIDE, 0, HEAD, BAND_N, -ROOM)
	_solid(STAIR_DOOR.x, STAIR_DOOR.y, 2.1, HEAD, BAND_N, -ROOM)
	for i: int in floors:
		var y := _floor_y(i)
		var top := y + 2.34
		var next := _floor_y(i + 1) if i < 4 else TOP
		_solid(0, WIDE, top, next, -ROOM, .22)
		_solid(.2, 4.98, y, top, -.14, -.02)
		_solid(4.98, WIDE + .2, y, top, -ROOM, .22)
		_solid(-.2, .2, y, top, -ROOM, .22)
		_solid(.2, STAIR_DOOR.x, y, top, BAND_N, -ROOM)
		_solid(STAIR_DOOR.y, 4.98, y, top, BAND_N, -ROOM)
		_solid(STAIR_DOOR.x, STAIR_DOOR.y, y + 2.1, top, BAND_N, -ROOM)
	_solid(-.2, ROOM_X0, 0, TOP, BAND_S - .1, BAND_N)
	_solid(0, WIDE, 0, TOP, -DEEP - .2, BAND_S)
	_solid(6.2, WIDE + .2, 0, TOP, BAND_S, BAND_N)
	_solid(UPPER_END, 6.2, TURN_CEILING, TOP, BAND_S, BAND_N)
	_solid(ROOM_X0, UPPER_END, STAIR_TOP, TOP + .3, BAND_S, BAND_N)
	_solid(STAIR_X, STAIR_X + .05, 0, 4.59, BAND_S, BAND_MID - .04)

func _grid_ceiling(top: float, x0: float, x1: float, near: float, far: float, tile: Color, grid: Color, panels: Array, part: String, bar_part := "metal", bar_wide := .024, bar_deep := .024) -> void:
	var f := _front
	var step := .6
	var col := 0
	var x := x0
	while x < x1 - .01:
		var end := minf(x + step, x1)
		var row := 0
		var z := near
		while z > far + .01:
			var z1 := maxf(z - step, far)
			if Vector2i(col, row) in panels:
				_kit.quad("panel", f * Vector3(x, top - .005, z1), f * Vector3(x, top - .005, z), f * Vector3(end, top - .005, z), f * Vector3(end, top - .005, z1), Color(.96, .95, 1.0))
			else:
				var tone := _rng.randf_range(.92, 1.06)
				_kit.quad(part, f * Vector3(x, top, z1), f * Vector3(x, top, z), f * Vector3(end, top, z), f * Vector3(end, top, z1), Color(tile.r * tone, tile.g * tone, tile.b * tone), 1.0, 1.0, 0.0, Vector2(x * 1.3, z * 1.3))
			z = z1
			row += 1
		x = end
		col += 1
	x = x0 + step
	while x < x1:
		_bar(bar_part, f, x, top - bar_deep * .5, (near + far) * .5, Vector3(bar_wide, bar_deep, near - far), grid)
		x += step
	var z := near - step
	while z > far:
		_bar(bar_part, f, (x0 + x1) * .5, top - bar_deep * .5, z, Vector3(x1 - x0, bar_deep, bar_wide), grid)
		z -= step

func _wall(face: Transform3D, length: float, holes: Array[Rect2], paper := Color(.93, .88, .66)) -> void:
	# Grey rubber skirting, a pale laminate dado in sheet widths, a chrome rail, flat paint above
	# to throw the light back, and the 2050 line of cyan just under the ceiling.
	var rail := 1.22
	var high := HEAD
	var dado := Color(.84, .84, .82)
	var u := .0
	while u < length - .01:
		var wide := minf(.92, length - u)
		var tone := _rng.randf_range(.9, 1.08)
		for piece: Rect2 in _minus(Rect2(u, .1, wide, rail - .1), holes):
			_kit.quad("dado", face * Vector3(piece.position.x, piece.position.y, 0), face * Vector3(piece.position.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.position.y, 0), Color(dado.r * tone, dado.g * tone, dado.b * tone), .9, 1.0)
		for piece: Rect2 in _minus(Rect2(u + wide - .004, .1, .008, rail - .1), holes):
			_bar("plain", face, piece.get_center().x, piece.get_center().y, .002, Vector3(piece.size.x, piece.size.y, .004), dado.darkened(.25))
		u += wide
	for piece: Rect2 in _minus(Rect2(0, rail, length, high - rail), holes):
		_kit.quad("paint", face * Vector3(piece.position.x, piece.position.y, 0), face * Vector3(piece.position.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.position.y, 0), paper, .94, 1.0)
	for row: Array in [[0.0, .1, .012, "plain", Color("#55575c")], [rail - .012, .03, .018, "chrome", Color("#c8ccd0")]]:
		for piece: Rect2 in _minus(Rect2(0, row[0], length, row[1]), holes):
			_bar(row[3], face, piece.get_center().x, piece.get_center().y, row[2] * .5, Vector3(piece.size.x, piece.size.y, row[2]), row[4])
	for piece: Rect2 in _minus(Rect2(.1, high - .1, length - .2, .01), holes):
		_bar("led", face, piece.get_center().x, piece.get_center().y, .006, Vector3(piece.size.x, .012, .01), CYAN)

func _fire_doors() -> void:
	# The game's own door, so these open on E with its prompt and its swing check like any other.
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("#5a5c60")
	steel.roughness = .45
	steel.metallic = .3
	# The upper floors have no real lamp to catch it: bare steel would go to a black hole after dark.
	steel.emission_enabled = true
	steel.emission = Color("#3e4044")
	var grip := StandardMaterial3D.new() # The door's own fittings go just as black, and a way out wants its handle seen.
	grip.albedo_color = Color("#8a9290")
	grip.roughness = .35
	grip.metallic = .6
	grip.emission_enabled = true
	grip.emission = Color("#767a7a")
	var mid := (STAIR_DOOR.x + STAIR_DOOR.y) * .5
	for i: int in range(5):
		var door: Node3D = load("res://scripts/building_access/door.gd").new()
		door.name = "FireDoor%dF" % (i + 1)
		door.position = _front * Vector3(mid, _floor_y(i), (BAND_N - ROOM) * .5)
		add_child(door)
		door.open_angle = PI * .5 # Swings into the stairwell, the way fire doors are hung.
		door.configure(Vector3(STAIR_DOOR.y - STAIR_DOOR.x - .02, 2.08, .05), steel, false, "fire door")
		for part: Node in door.leaf.get_children():
			if part is GeometryInstance3D:
				(part as GeometryInstance3D).visibility_range_end = 28.0
				if (part as GeometryInstance3D).material_override != steel:
					(part as GeometryInstance3D).material_override = grip
		_fire.append(door)

func _room(y: float, mood: int) -> void:
	# Each tenant fits out its own floor, so no two share a wall, a floor or a ceiling.
	var f := _front
	var x0 := .2
	var x1 := 4.98
	var near := -.1
	var far := -ROOM
	var top := y + ROOM_HIGH
	var depth := ROOM + near
	var door: Array[Rect2] = [Rect2(STAIR_DOOR.x - x0, 0, STAIR_DOOR.y - STAIR_DOOR.x, 2.1)]
	var back := Transform3D(Basis.IDENTITY, f * Vector3(x0, y, far))
	var west := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(x0, y, near))
	var east := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(x1, y, far))
	var bright: Array = [Vector2i(1, 1), Vector2i(3, 1), Vector2i(5, 1), Vector2i(7, 1), Vector2i(1, 4), Vector2i(3, 4), Vector2i(5, 4), Vector2i(7, 4), Vector2i(1, 7), Vector2i(5, 7)]
	match mood:
		0:
			_kit.quad("mosaic", f * Vector3(x0, y, near), f * Vector3(x0, y, far), f * Vector3(x1, y, far), f * Vector3(x1, y, near), Color.WHITE, 1.0, 1.0, 0.0, Vector2(x0, near))
			_grid_ceiling(top, x0, x1, near, far, Color(.9, .89, .9), Color("#cfcdd3"), bright, "ceil_pale", "ceil_pale", .016, .008)
			_wall_panels(back, x1 - x0, door)
			_wall_panels(west, depth, [])
			_wall_panels(east, depth, [])
		1:
			# Polished tan terrazzo, and the sage runner the old halls lay down their main way through.
			var honey := Color(1.09, .99, .83)
			var straw := Color(1.02, .92, .78)
			_floor_tiles(y, x0, x1, near, -3.35, honey, straw, "terrazzo_tan", .6)
			_floor_tiles(y, x0, x1, -3.35, -4.2, Color(.46, .6, .58), Color(.42, .55, .53), "terrazzo_tan", .6)
			_floor_tiles(y, x0, x1, -4.2, far, honey, straw, "terrazzo_tan", .6)
			_exposed_ceiling(top, x0, x1, near, far)
			_wall_warm(back, x1 - x0, door, false)
			_wall_warm(west, depth, [])
			_wall_warm(east, depth, [])
		2:
			_floor_tiles(y, x0, x1, near, far, Color(.06, .12, .17), Color(.035, .07, .12), "rug", .6)
			_casino_ceiling(top, x0, x1, near, far)
			_wall_speck(back, x1 - x0, door)
			_wall_speck(west, depth, [])
			_wall_speck(east, depth, [])
		_:
			# Black in the rooms, a flat grey apron at their doors, and a dark scratched carpet down the walkway.
			_floor_tiles(y, x0, x1, near, -4.3, Color(.03, .03, .036), Color(.028, .028, .034), "rug", 1.2)
			_floor_tiles(y, x0, x1, -4.3, -4.9, Color(.12, .118, .112), Color(.118, .116, .11), "room", 1.2)
			_floor_tiles(y, x0, x1, -4.9, far, Color(.7, .7, .7), Color(.68, .68, .68), "rug_line", 1.2)
			_grid_ceiling(top, x0, x1, near, far, Color(.05, .05, .06), Color("#0b0b0d"), [], "ceil", "plain")
			_wall_boards(back, x1 - x0, door)
			_wall_boards(west, depth, [])
			_wall_boards(east, depth, [])
	# What the fire code asks of every floor, whoever the tenant is.
	if mood >= 2: # On a black ceiling even the fire code wears black, or it is all you look at.
		_air_con(Vector2(2.6, -3.2), top, Color("#121216") if mood == 2 else Color("#0c0c0e"))
		for at: Vector2 in [Vector2(1.1, -1.4), Vector2(3.9, -1.4), Vector2(1.1, -4.6), Vector2(3.9, -4.6)]:
			_sprinkler(f * Vector3(at.x, top, at.y), Color("#26262a"), Color("#5a4c28"))
		_detector(f * Vector3(1.6, top, -3.1), Color("#26262a"))
		_speaker(f * Vector3(3.8, top, -3.1), Color("#26262a"), Color("#0c0c0e"))
		_dome(f * Vector3(.9, top, -2.6))
	else:
		_air_con(Vector2(4.0, -4.0) if mood == 1 else Vector2(2.6, -3.2), top)
		for at: Vector2 in [Vector2(1.1, -1.4), Vector2(3.9, -1.4), Vector2(1.1, -4.6), Vector2(3.9, -4.6)]:
			_sprinkler(f * Vector3(at.x, top, at.y))
		_detector(f * Vector3(1.6, top, -3.1))
		_speaker(f * Vector3(3.8, top, -3.1))
		_camera(f * Vector3(.9, top, -2.6))
	_bar("plain", f, .8, y + 2.2, far + .03, Vector3(.52, .17, .06), Color("#e8e8e4"))
	_panel("crane_lit", f, .55, 1.05, y + 2.13, y + 2.27, far + .062, _cell(420, 1920, 360, 120))

func _floor_tiles(y: float, x0: float, x1: float, near: float, far: float, tint: Color, other: Color, part: String, size: float, joint := Color.TRANSPARENT) -> void:
	# Laid square in the given material, the pattern running on from tile to tile.
	var f := _front
	var col := 0
	var x := x0
	while x < x1 - .01:
		var end := minf(x + size, x1)
		var row := 0
		var z := near
		while z > far + .01:
			var z1 := maxf(z - size, far)
			var tone := _rng.randf_range(.96, 1.03)
			var pick: Color = tint if (col + row) % 2 == 0 else other
			_kit.quad(part, f * Vector3(x, y, z), f * Vector3(x, y, z1), f * Vector3(end, y, z1), f * Vector3(end, y, z), Color(pick.r * tone, pick.g * tone, pick.b * tone), 1.0, 1.0, 0.0, Vector2(x, z))
			z = z1
			row += 1
		x = end
		col += 1
	if joint.a > 0.0:
		x = x0 + size
		while x < x1:
			_bar("plain", f, x, y + .001, (near + far) * .5, Vector3(.006, .002, near - far), joint)
			x += size
		var z := near - size
		while z > far:
			_bar("plain", f, (x0 + x1) * .5, y + .001, z, Vector3(x1 - x0, .002, .006), joint)
			z -= size

func _flat_wall(face: Transform3D, length: float, holes: Array[Rect2], part: String, tint: Color) -> void:
	for piece: Rect2 in _minus(Rect2(0, 0, length, ROOM_HIGH), holes):
		_kit.quad(part, face * Vector3(piece.position.x, piece.position.y, 0), face * Vector3(piece.position.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.position.y, 0), tint, .96, 1.0, 0.0, Vector2(piece.position.x, -piece.position.y))

func _wall_panels(face: Transform3D, length: float, holes: Array[Rect2]) -> void:
	# Pale wall board in the builders' 910 mm module, shadow gaps and all, a steel rail at door height,
	# and a band of dull rose paint above it: the room is only the box the machines stand in.
	_flat_wall(face, length, holes, "plaster", Color("#dcd5cb"))
	var u := .91
	while u < length:
		for piece: Rect2 in _minus(Rect2(u - .002, .09, .004, 1.96), holes):
			_bar("plain", face, piece.get_center().x, piece.get_center().y, .001, Vector3(piece.size.x, piece.size.y, .002), Color("#8a847c"))
		u += .91
	for piece: Rect2 in _minus(Rect2(0, 2.05, length, ROOM_HIGH - 2.05), holes):
		_kit.quad("paint", face * Vector3(piece.position.x, piece.position.y, .002), face * Vector3(piece.position.x, piece.end.y, .002), face * Vector3(piece.end.x, piece.end.y, .002), face * Vector3(piece.end.x, piece.position.y, .002), Color("#a9838a"))
	for piece: Rect2 in _minus(Rect2(0, 2.04, length, .025), holes):
		_bar("fitting", face, piece.get_center().x, piece.get_center().y, .006, Vector3(piece.size.x, piece.size.y, .012), Color("#9a9ca0"))
	for piece: Rect2 in _minus(Rect2(0, 0, length, .09), holes):
		_bar("plain", face, piece.get_center().x, .045, .006, Vector3(piece.size.x, .09, .012), Color("#4c4a4a"))

func _exposed_ceiling(top: float, x0: float, x1: float, near: float, far: float) -> void:
	# No ceiling at all, as in the real ones: a black slab, sprayed beams, thin pipe and cable nobody
	# tidied, and enamel domes on two rails, each with its pool on the floor and the dark between them.
	var f := _front
	_kit.quad("spray", f * Vector3(x0, top, far), f * Vector3(x0, top, near), f * Vector3(x1, top, near), f * Vector3(x1, top, far), Color(.15, .13, .12))
	for z_at: float in [-1.9, -4.9]:
		_bar("spray", f, 2.59, top - .1, z_at, Vector3(4.78, .2, .36), Color(.3, .26, .22))
	for x: float in [.95, 3.4]:
		# Down out of the slab behind the zone boards, over them, and away through the back beam.
		_kit.tube("metal", [f * Vector3(x, top, -.2), f * Vector3(x, top - .07, -.3), f * Vector3(x, top - .07, -4.8)], .025, Color("#3a3c40"), 8)
		for z_at: float in [-1.2, -3.0, -4.4]:
			_bar("metal", f, x, top - .04, z_at, Vector3(.03, .08, .03), Color("#2a2c30"))
	_bar("metal", f, 2.2, top - .07, (near + far) * .5, Vector3(.3, .03, near - far), Color("#3a3c42"))
	var cross := near - .6
	while cross > far:
		_bar("metal", f, 2.2, top - .05, cross, Vector3(.3, .012, .03), Color("#4a4c52"))
		cross -= .4
	# Cable nobody clipped up, each dropped out of the slab and sagging clear under the beam it crosses.
	# Two end in the same box; the newest, blue network cable came in with the 2050 network.
	var box := Vector2(3.18, -2.78)
	_bar("plain", f, box.x, top - .04, box.y, Vector3(.14, .08, .14), Color("#2a2c30"))
	_bar("plain", f, 1.27, top - .04, -4.64, Vector3(.14, .08, .14), Color("#2a2c30")) # Where the lit run goes to ground.
	for run: Array in [[Vector2(.5, -.66), box, "plain", Color("#17181a")], [Vector2(.7, -4.55), box, "plain", Color("#2a2420")], [Vector2(2.5, -.66), Vector2(1.3, -4.55), "plain", Color("#1d4a86")]]:
		var from: Vector2 = run[0]
		var to: Vector2 = run[1]
		var lead := (to - from).normalized() * .12 # They leave the slab on a slant, as a cable will.
		var loose: Array[Vector3] = [f * Vector3(from.x - lead.x, top, from.y - lead.y)]
		for i: int in range(9):
			var u := float(i) / 8.0
			var at := from.lerp(to, u)
			loose.append(f * Vector3(at.x, top - .08 - .16 * (1.0 - pow(2.0 * u - 1.0, 2.0)), at.y))
		loose.append(f * Vector3(to.x + lead.x, top, to.y + lead.y))
		_kit.tube(run[2], loose, .006, run[3], 4)
	# The rails hang over the aisles, where a pool can land, from behind the zone boards to the last lamp.
	var start := -.62
	var end := -4.66
	var warm := Color(1.0, .84, .6)
	var floor_y := top - ROOM_HIGH + .004
	for x: float in [1.15, 3.55]:
		_bar("metal", f, x, top - .3, (start + end) * .5, Vector3(.03, .03, start - end), Color("#1a1c20"))
		for z_at: float in [-1.5, -3.0, -4.5]:
			_kit.tube("metal", [f * Vector3(x, top, z_at), f * Vector3(x, top - .3, z_at)], .005, Color("#2a2c30"), 3)
		var z := near - .7
		while z > end:
			_kit.lathe("metal", f * Vector3(x, top - .44, z), [Vector2(.2, 0), Vector2(.17, .05), Vector2(.06, .1), Vector2(.02, .13)], Color("#3a3e38"), 24)
			_kit.disc("panel", f * Vector3(x, top - .432, z), Vector3.RIGHT, Vector3.BACK, .197, Color("#e8dcc8"))
			_kit.disc("case_lamp", f * Vector3(x, top - .436, z), Vector3.RIGHT, Vector3.BACK, .17, warm)
			var lit := minf(z + .9, near) # Cut off at the glass: the floor ends there, and so does the pool.
			_kit.atlas("pool", f * Vector3(x - .9, floor_y, lit), f * Vector3(x - .9, floor_y, z - .9), f * Vector3(x + .9, floor_y, z - .9), f * Vector3(x + .9, floor_y, lit), Rect2(0, 0, 1, (lit - z + .9) / 1.8), warm * .3)
			z -= 1.7

func _casino_ceiling(top: float, x0: float, x1: float, near: float, far: float) -> void:
	# A black ceiling and one line of small warm spots down each aisle, clear of the fans: the machines do the rest.
	var f := _front
	_kit.quad("plain", f * Vector3(x0, top, far), f * Vector3(x0, top, near), f * Vector3(x1, top, near), f * Vector3(x1, top, far), Color("#0c0808"))
	for x: float in [1.45, 3.7]:
		var z := -.5
		while z > -5.4:
			_kit.disc("lamp_in", f * Vector3(x, top - .006, z), Vector3.RIGHT, Vector3.BACK, .04, Color(1.0, .8, .5))
			z -= 1.2

func _wall_warm(face: Transform3D, length: float, holes: Array[Rect2], spots := true) -> void:
	# As in the old Tokyo halls: cream lattice paper to head height with a red band along its top,
	# flat paint above, conduit nobody hid, and small spots clipped to it to scallop the paper.
	var paper := 1.98
	for row: Array in [[Rect2(0, 0, length, paper), "lattice", Color("#efe0c0").darkened(.15)], [Rect2(0, paper, length, ROOM_HIGH - paper), "paper_pale", Color("#e6d2b0").darkened(.15)]]:
		_flat_wall_piece(face, row[0], holes, row[1], row[2])
	for piece: Rect2 in _minus(Rect2(0, paper, length, .06), holes):
		_bar("plain", face, piece.get_center().x, piece.get_center().y, .004, Vector3(piece.size.x, piece.size.y, .008), Color("#b01820"))
	for piece: Rect2 in _minus(Rect2(0, 0, length, .1), holes):
		_bar("plain", face, piece.get_center().x, .05, .006, Vector3(piece.size.x, .1, .012), Color("#2a1c14"))
	_kit.tube("metal", [face * Vector3(0, 2.2, .03), face * Vector3(length, 2.2, .03)], .012, Color("#5a5c62"), 5)
	var u := .5
	while u < length:
		_bar("metal", face, u, 2.2, .02, Vector3(.03, .05, .04), Color("#3a3c42"))
		u += 1.1
	if not spots: # The back wall's run: the door and the tall machines leave a spot nothing to land on.
		return
	for share: float in [.22, .5, .78]:
		var at := length * share
		_bar("metal", face, at, 2.19, .05, Vector3(.02, .012, .05), Color("#141416")) # Its clip to the conduit.
		_kit.lathe("metal", face * Vector3(at, 2.08, .07), [Vector2(.03, 0), Vector2(.036, .08), Vector2(.014, .11)], Color("#141416"), 8)
		_kit.disc("case_lamp", face * Vector3(at, 2.082, .07), Vector3.RIGHT, Vector3.BACK, .026, Color(1.0, .84, .6))
		_panel("spill", face, at - .6, at + .6, .7, 2.12, .012, Rect2(0, 0, 1, 1), Color(1.0, .82, .55) * .28)

func _flat_wall_piece(face: Transform3D, area: Rect2, holes: Array[Rect2], part: String, tint: Color) -> void:
	# As _flat_wall, for one band of a wall, its texture keeping its true scale.
	for piece: Rect2 in _minus(area, holes):
		_kit.quad(part, face * Vector3(piece.position.x, piece.position.y, 0), face * Vector3(piece.position.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.position.y, 0), tint, .96, 1.0, 0.0, Vector2(piece.position.x, -piece.position.y))

func _wall_speck(face: Transform3D, length: float, holes: Array[Rect2]) -> void:
	# The near-black flecked wall of a slot floor, gone from view behind the machines lit in front of it.
	_flat_wall(face, length, holes, "speck", Color(.09, .09, .12))
	for piece: Rect2 in _minus(Rect2(0, 0, length, .12), holes):
		_bar("plain", face, piece.get_center().x, .06, .01, Vector3(piece.size.x, .12, .02), Color("#08080a"))

func _wall_boards(face: Transform3D, length: float, holes: Array[Rect2]) -> void:
	# Board-marked charcoal panels, the way the VR rooms dress their walls: the grain runs level and
	# carries on round any door, and the through-bolts were set by eye.
	for p: Rect2 in _minus(Rect2(0, 0, length, ROOM_HIGH), holes):
		_kit.quad("boards", face * Vector3(p.end.x, p.position.y, 0), face * Vector3(p.position.x, p.position.y, 0), face * Vector3(p.position.x, p.end.y, 0), face * Vector3(p.end.x, p.end.y, 0), Color(.24, .24, .25), 1.0, 1.0, 0.0, Vector2(p.position.y, p.end.x))
	var u := .3
	while u < length:
		for y: float in [.45, 1.25, 2.05]:
			var at := Vector2(u + _rng.randf_range(-.06, .06), y + _rng.randf_range(-.06, .06))
			if holes.all(func(hole: Rect2) -> bool: return not hole.grow(.04).has_point(at)):
				_kit.disc("plain", face * Vector3(at.x, at.y, .003), face.basis.x, face.basis.y, .027, Color("#0a0a0c"))
				_kit.disc("paint", face * Vector3(at.x, at.y, .006), face.basis.x, face.basis.y, .02, Color(.011, .011, .012)) # A breath of glow, or after dark every bolt reads as a hole.
		u += .6

func _pad(at: Vector3, half: float, tall: float, tint: Color, part: String) -> void:
	# A square vinyl pad: straight sides, a rolled edge with its piping, and a flat top.
	var levels: Array[Vector2] = [Vector2(half - .012, .0), Vector2(half, .012), Vector2(half, tall - .024), Vector2(half - .01, tall - .006), Vector2(half - .03, tall)]
	var squares: Array = []
	for level: Vector2 in levels:
		var h := level.x
		squares.append([at + Vector3(-h, level.y, h), at + Vector3(h, level.y, h), at + Vector3(h, level.y, -h), at + Vector3(-h, level.y, -h)])
	for i: int in range(levels.size() - 1):
		for side: int in range(4):
			var next := (side + 1) % 4
			_kit.quad(part, squares[i][side], squares[i + 1][side], squares[i + 1][next], squares[i][next], tint)
	var top: Array = squares[levels.size() - 1]
	_kit.quad(part, top[0], top[3], top[2], top[1], tint)
	var under: Array = squares[0]
	_kit.quad(part, under[0], under[1], under[2], under[3], tint * .6)
	var piping: Array[Vector3] = [squares[2][0], squares[2][1], squares[2][2], squares[2][3], squares[2][0]]
	_kit.tube(part, piping, .0035, tint * 1.25, 4)

func _stool(at: Vector3, tint: Color, legs := "chrome", pad := "shell", chrome := Color("#b8bcc2")) -> void:
	# Four tube legs and a square vinyl pad, the stool every real arcade row sits on.
	var ring: Array[Vector3] = []
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		_kit.tube(legs, [at + Vector3(c.x * .17, 0, c.y * .17), at + Vector3(c.x * .115, .44, c.y * .115)], .01, chrome, 6) # Up into the pad.
		ring.append(at + Vector3(c.x * .15, .16, c.y * .15))
	ring.append(ring[0])
	_kit.tube(legs, ring, .007, chrome, 5)
	_pad(at + Vector3.UP * .44, .165, .07, tint, pad)

func _swivel(at: Vector3, out: Vector3, tint: Color) -> void:
	# The low-backed swivel chair of a slot row, bolted down, its back well under the machine's face so
	# you can see down the row over it, with a foot ring worn bright.
	var chrome := Color("#3e4146")
	_kit.lathe("steel_in", at, [Vector2(.2, .005), Vector2(.19, .02), Vector2(.05, .05), Vector2(.03, .42)], Color("#26282c"), 24)
	var side := Vector3.UP.cross(out).normalized()
	var axes := Basis(side, Vector3.UP, out.normalized())
	_pillow(at + Vector3.UP * .47, Vector3(.2, .05, .19), tint, axes, 5, 20, .6, "vinyl_in")
	_pillow(at + Vector3.UP * .76 + out * .19, Vector3(.19, .2, .05), tint, axes, 7, 20, .6, "vinyl_in")
	_kit.tube("steel_in", [at + Vector3.UP * .46 + out * .14, at + Vector3.UP * .64 + out * .2], .014, chrome, 6)
	var ring: Array[Vector3] = []
	for i: int in range(25):
		var a := TAU * float(i) / 24.0
		ring.append(at + Vector3(cos(a) * .15, .2, sin(a) * .15))
	_kit.tube("steel_in", ring, .006, chrome, 5)
	for i: int in range(3):
		var a := TAU * float(i) / 3.0 + .5
		_kit.tube("steel_in", [at + Vector3.UP * .2, at + Vector3(cos(a) * .15, .2, sin(a) * .15)], .005, chrome, 4)

func _tray(at: Vector3, turn: float, stack: int, cell: Rect2) -> void:
	# A red tray stack from the aisle, topped with the real thing out of the photograph.
	var t := Transform3D(Basis(Vector3.UP, turn), at)
	for i: int in range(stack):
		_bar("gloss", t, 0, .05 + float(i) * .1, 0, Vector3(.38, .09, .26), Color("#c01018"))
		_bar("plain", t, 0, .1 + float(i) * .1, 0, Vector3(.4, .012, .28), Color("#e02028"))
	var y := float(stack) * .1 + .012
	_kit.atlas("photo_print", t * Vector3(-.17, y, .11), t * Vector3(-.17, y, -.11), t * Vector3(.17, y, -.11), t * Vector3(.17, y, .11), cell)

func _fan_string(top: float, x: float, z0: float, z1: float) -> void:
	# Round plaques on a line down the aisle, red and white, each turned to whoever walks under it
	# and hung by hand, so no two sit quite square.
	var f := _front
	_kit.tube("plain", [f * Vector3(x, top - .118, z0), f * Vector3(x, top - .118, z1)], .004, Color("#1a1a1e"), 3)
	for drop: float in [z0, (z0 + z1) * .5, z1]:
		_kit.tube("plain", [f * Vector3(x, top, drop), f * Vector3(x, top - .118, drop)], .003, Color("#1a1a1e"), 3)
	var cells: Array[Rect2] = [Rect2(357.0 / 1024.0, 277.0 / 1024.0, 156.0 / 1024.0, 156.0 / 1024.0), Rect2(537.0 / 1024.0, 277.0 / 1024.0, 156.0 / 1024.0, 156.0 / 1024.0)]
	var i := 0
	var z := z0
	# Each is a 5 mm foam board, printed both faces, its cut edge white, hung on a clip and a short hook.
	var radius := .11
	while z > z1:
		var cell: Rect2 = cells[i % 2]
		var wobble := fposmod(float(i) * .618 + x, 1.0) - .5 # Fixed per plaque: the shared dice stay where the rest of the floors expect them.
		var swing := Basis(Vector3.UP, (.3 if i % 2 == 0 else -.3) + wobble * .16) * Basis(Vector3.BACK, wobble * -.1)
		var right := swing * Vector3.RIGHT
		var up := swing * Vector3.UP
		var out := right.cross(up)
		var at := f * Vector3(x, top - .118 - .035 - radius, z)
		_kit.disc("photo_in", at + out * .0026, right, up, radius, Color.WHITE, cell)
		_kit.disc("photo_in", at - out * .0026, -right, up, radius, Color.WHITE, cell)
		_turned("plain", at, Basis(right, out, -up).orthonormalized(), [Vector2(radius, -.0026), Vector2(radius, .0026)], Color("#ecebe6"), 28)
		var lip := at + up * (radius - .012)
		_bar("metal", Transform3D(swing, lip), 0, 0, 0, Vector3(.016, .02, .009), Color("#b8bcc2")) # The clip, biting the top.
		_kit.tube("metal", [lip + up * .01, lip + up * .028, f * Vector3(x, top - .118, z)], .0012, Color("#8a8e94"), 3)
		z -= .42
		i += 1

func _hanging_poster(x: float, z: float, top: float, part: String, cell: Rect2, aspect: float, strip := Rect2()) -> void:
	# A poster on two wires over the aisle, printed both sides so it reads either way you walk,
	# hung true to its own shape and turned however the wires happened to settle.
	var wide := .34
	var high := top - .1
	var low := high - wide * aspect
	var t := Transform3D(Basis(Vector3.UP, _rng.randf_range(-.15, .15)), _front * Vector3(x, 0, z))
	for face: Transform3D in [t, t * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)]:
		_panel(part, face, -wide * .5, wide * .5, low, high, .002, cell)
		if strip.size != Vector2.ZERO:
			_panel(part, face, -wide * .5, wide * .5, low - wide * .175, low, .002, strip)
	for side: float in [-.14, .14]:
		_kit.tube("metal", [t * Vector3(side, top, 0), t * Vector3(side, high, 0)], .003, Color("#6a6c70"), 3)

func _flyer(face: Transform3D, part: String, x0: float, x1: float, y0: float, y1: float, cell: Rect2, roll: float) -> void:
	# Taped up by whoever was on shift, so never quite square.
	var mid := Vector2((x0 + x1) * .5, (y0 + y1) * .5)
	var t := Transform3D(face.basis * Basis(Vector3.BACK, roll), face * Vector3(mid.x, mid.y, .008))
	_panel(part, t, x0 - mid.x, x1 - mid.x, y0 - mid.y, y1 - mid.y, 0, cell)

func _game_poster(face: Transform3D, x: float, y: float, game: int, roll: float) -> void:
	# The cheapest poster there is: a shot of the game with its title strip under it.
	var t := Transform3D(face.basis * Basis(Vector3.BACK, roll), face * Vector3(x, y, .008))
	_panel("floor_print", t, -.3, .3, -.1725, .2775, 0, _cell(float(game) * 410.0, 0, 400, 300))
	_panel("floor_print", t, -.3, .3, -.2775, -.1725, 0, _cell(float(game) * 410.0, 310, 400, 70))

func _curly_lead(from: Vector2, to: Vector2, top: float, tint: Color) -> void:
	# A coiled extension lead, as in the real halls: hooked to the slab at each end and sagging in
	# between, its coil stretched open where it hangs lowest.
	var f := _front
	var run := 140
	var path: Array[Vector3] = []
	var span := from.distance_to(to)
	for i: int in range(run + 1):
		var u := float(i) / float(run)
		var at := from.lerp(to, u)
		path.append(f * Vector3(at.x, top - .06 - .3 * (1.0 - pow(2.0 * u - 1.0, 2.0)), at.y))
	var coil: Array[Vector3] = []
	var turns := span / .022
	var steps := int(turns * 7.0)
	for i: int in range(steps + 1):
		var u := float(i) / float(steps)
		var k := mini(int(u * float(run)), run - 1)
		var a := path[k].lerp(path[k + 1], u * float(run) - float(k))
		var along := (path[k + 1] - path[k]).normalized()
		var side := along.cross(Vector3.UP).normalized()
		var up := side.cross(along)
		var spin := TAU * turns * u
		coil.append(a + (side * cos(spin) + up * sin(spin)) * .011)
	_kit.tube("plain", coil, .0025, tint, 3)
	for end: Vector2 in [from, to]:
		_kit.tube("metal", [f * Vector3(end.x, top, end.y), f * Vector3(end.x, top - .06, end.y)], .003, Color("#6a6c70"), 3)
func _cab_top(t: Transform3D, cell: Rect2, extra: int) -> void:
	# Nothing on a real cabinet stays bare: an acrylic stand of how-to cards, and whatever got left.
	# Nobody squares a POP stand to the row, so no two of them line up.
	var turn := .12 if _rng.randf() < .5 else -.12
	var stand := Transform3D(t.basis * Basis(Vector3.UP, turn), t * Vector3(_rng.randf_range(-.08, .08), 0, -.14))
	var high := 1.56 + .16 * cell.size.y / cell.size.x
	_bar("metal", stand, 0, 1.54, 0, Vector3(.2, .032, .07), Color("#c8ccd0")) # Deep enough to sit on the crown's slope.
	_panel("floor_print", stand, -.08, .08, 1.555, high, .012, cell)
	_kit.quad("plain", stand * Vector3(.08, 1.555, .01), stand * Vector3(.08, high, .01), stand * Vector3(-.08, high, .01), stand * Vector3(-.08, 1.555, .01), Color("#d8d8d4"))
	if extra == 1:
		_plush(t * Vector3(.18, 1.61, -.22), TOY, t.basis * Basis(Vector3.UP, .5), Color("#dcb878"), _cell_crane(), true)
	elif extra == 2:
		# The headset, hung on its peg on the crown between plays.
		var hook := t * Vector3(.24, 1.585, -.05)
		_kit.tube("metal", [t * Vector3(.24, 1.52, -.05), hook + t.basis.y * .08], .005, Color("#6a6c70"), 5)
		var band: Array[Vector3] = []
		for i: int in range(11):
			var a := PI * float(i) / 10.0
			band.append(hook + t.basis.y * sin(a) * .07 + t.basis.x * cos(a) * .07)
		_kit.tube("plain", band, .008, Color("#17181a"), 5)
		for side: float in [-1.0, 1.0]:
			_ball(hook + t.basis.x * side * .07, Vector3(.03, .045, .045), Color("#23252a"), "plain", 6, 12, t.basis)

func _cell_crane() -> Rect2:
	return _cell(0, 0, 512, 512)

func _extrude(part: String, t: Transform3D, outline: Array[Vector2], x0: float, x1: float, tint: Color) -> void:
	# An outline in (z, y), counter-clockwise from the front foot, pushed across x and capped.
	var count := outline.size()
	for i: int in range(count):
		var p := outline[i]
		var q := outline[(i + 1) % count]
		_kit.quad(part, t * Vector3(x0, p.y, p.x), t * Vector3(x0, q.y, q.x), t * Vector3(x1, q.y, q.x), t * Vector3(x1, p.y, p.x), tint)
	var corners := Geometry2D.triangulate_polygon(PackedVector2Array(outline))
	for i: int in range(0, corners.size(), 3):
		var a := outline[corners[i]]
		var b := outline[corners[i + 1]]
		var c := outline[corners[i + 2]]
		if (b - a).cross(c - a) < 0.0:
			var swap := b
			b = c
			c = swap
		_kit.quad(part, t * Vector3(x1, a.y, a.x), t * Vector3(x1, b.y, b.x), t * Vector3(x1, c.y, c.x), t * Vector3(x1, c.y, c.x), tint)
		_kit.quad(part, t * Vector3(x0, a.y, a.x), t * Vector3(x0, c.y, c.x), t * Vector3(x0, b.y, b.x), t * Vector3(x0, b.y, b.x), tint)

func _slope(t: Transform3D, low: Vector2, high: Vector2) -> Transform3D:
	# A face lying on an outline's edge: +x across the machine, +y up the edge, +z out of it.
	var run := (high - low).normalized()
	var up := t.basis * Vector3(0, run.y, run.x)
	var across := t.basis.x
	return Transform3D(Basis(across, up, across.cross(up)), t * Vector3(0, low.y, low.x))

func _box_solid(t: Transform3D, centre: Vector3, size: Vector3) -> void:
	# As _solid, for a machine standing at an angle.
	_solid(0, 1, 0, 1, 0, 1)
	var shape: CollisionShape3D = _ground.get_child(_ground.get_child_count() - 1)
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = t * Transform3D(Basis.IDENTITY, centre)

func _arcade_floor(y: float) -> void:
	# Sit-down cabinets back to back down the middle, screens the only real light in the room.
	var f := _front
	_room(y, 1)
	_zone_boards(y + 2.34, [_cell(0, 300, 460, 140), _cell(470, 300, 460, 140), _cell(940, 300, 460, 140)])
	var teal := Color("#123e4a")
	var red := Color("#5e1418")
	var seats: Array[Color] = [teal, teal, red, teal, red, teal]
	var cards: Array[Rect2] = [_cell(1020, 1320, 300, 420), _cell(1020, 1750, 300, 280)]
	var slot := 0
	# Set back from the glass, so the way along the window stays a full metre.
	for z: float in [-1.52, -2.26, -3.0]:
		var east_cab := Transform3D(Basis(Vector3.UP, PI * .5), f * Vector3(2.79, y, z))
		var west_cab := Transform3D(Basis(Vector3.UP, -PI * .5), f * Vector3(1.75, y, z))
		_cab(east_cab, slot % 5)
		_cab_top(east_cab, cards[slot % 2], slot)
		_stool(f * Vector3(3.59, y, z), seats[slot], "chrome", "shell_in")
		_cab(west_cab, (slot + 2) % 5)
		_cab_top(west_cab, cards[(slot + 1) % 2], 2 - slot)
		_stool(f * Vector3(.95, y, z), seats[slot + 3], "chrome", "shell_in")
		if slot != 1: # The two ends of the row, whichever way each cabinet faces.
			var out := -1.0 if slot == 0 else 1.0
			_cab_stripe(east_cab, out, Color("#2aa860"))
			_cab_stripe(west_cab, -out, Color("#2aa860"))
		slot += 1
	# Two rows back to back leave a valley down the crowns: boarded over, so it is not a gap. The
	# seam between them at each end carries the thin lit line that says the row is on the network.
	_bar("plain", f, 2.27, y + 1.43, -2.26, Vector3(.42, .14, 2.18), Color("#2a2c30"))
	for z: float in [-1.164, -3.356]:
		_bar("led_low", f, 2.27, y + .66, z, Vector3(.012, 1.1, .002), CYAN)
	_solid(1.31, 3.23, y, y + 1.55, -3.356, -1.164)
	# Nothing up here throws a shadow after dark, so each heavy thing keeps its own at the foot. Against
	# a wall the foot given stops a reach short of it, or the dark would run on through into the stairs.
	for foot: Rect2 in [Rect2(1.67, -3.356, 1.2, 2.192), Rect2(4.4, -1.85, .34, 1.3), Rect2(3.75, -5.36, .99, .78), Rect2(1.94, -5.36, 1.72, .77), Rect2(1.25, -5.36, .5, .12)]:
		_contact(foot, y + .005)
	# The polish under it all, mirroring the enamel domes down each aisle; the island, the back row and the washers stand dark in it.
	_kit.quad("shine_hall", f * Vector3(.2, y + .003, -.1), f * Vector3(.2, y + .003, -ROOM), f * Vector3(4.98, y + .003, -ROOM), f * Vector3(4.98, y + .003, -.1), Color.WHITE)
	var hall_feet := PackedVector4Array()
	for foot: Rect2 in [Rect2(1.31, -3.356, 1.92, 2.192), Rect2(3.75, -5.6, 1.1, 1.02), Rect2(1.95, -5.6, 1.7, 1.16), Rect2(4.34, -1.85, .64, 1.3), Rect2(1.25, -5.6, .5, .36)]:
		var a := f * Vector3(foot.position.x, 0, foot.position.y)
		var b := f * Vector3(foot.end.x, 0, foot.end.y)
		hall_feet.append(Vector4(a.x, a.z, b.x, b.z))
	var lamp := f * Vector3(1.15, 0, -.8)
	var hall: ShaderMaterial = _looks.shine_hall
	hall.set_shader_parameter("ceiling", y + 1.9)
	hall.set_shader_parameter("machine_top", y + 1.55)
	hall.set_shader_parameter("lamp_first", Vector2(lamp.x, lamp.z))
	hall.set_shader_parameter("lamp_step", Vector2(2.4, -1.7))
	hall.set_shader_parameter("lamp_count", Vector2(1.0, 2.0))
	hall.set_shader_parameter("lamp_half", Vector2(.17, .17))
	hall.set_shader_parameter("lamp_level", 3.2)
	hall.set_shader_parameter("board_level", .04)
	hall.set_shader_parameter("tint", Vector3(1.0, .84, .62))
	hall.set_shader_parameter("feet", hall_feet)
	# The change machine and the big music games stand along the back, clear of the door.
	_kiosk(Transform3D(Basis.IDENTITY, f * Vector3(1.5, y, -5.24)), "shell_in")
	_solid(1.25, 1.75, y, y + 1.7, -5.6, -5.24)
	_dj_cab(Transform3D(Basis.IDENTITY, f * Vector3(4.3, y, -5.1)))
	_solid(3.75, 4.85, y, y + 2.12, -5.6, -4.58)
	_washer(Transform3D(Basis(Vector3.UP, -PI * .5), f * Vector3(4.48, y, -.87)))
	_washer(Transform3D(Basis(Vector3.UP, -PI * .5), f * Vector3(4.48, y, -1.53)))
	_solid(4.34, 4.98, y, y + 1.76, -1.85, -.55)
	_drum_game(Transform3D(Basis.IDENTITY, f * Vector3(2.8, y, -4.78)))
	_solid(1.95, 3.65, y, y + 2.2, -5.6, -4.44)
	# Flyers taped up wherever the aisle has a bit of wall, no two alike on one wall.
	var west := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(.2, y, -.1))
	var east := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(4.98, y, -ROOM))
	_flyer(west, "floor_print", .5, 1.1, 1.1, 1.94, _cell(1020, 1320, 300, 420), .02)
	_flyer(west, "art", 1.2, 1.9, 1.04, 1.86, _cell(0, 0, 1024, 1200), -.015)
	_flyer(west, "floor_print", 2.0, 2.56, 1.36, 1.88, _cell(1020, 1750, 300, 280), .03)
	_game_poster(west, 2.96, 1.42, 3, -.02)
	_game_poster(west, 3.7, 1.58, 2, .025)
	_game_poster(west, 4.4, 1.44, 4, -.03)
	_game_poster(east, 2.85, 1.52, 1, .02)
	_flyer(east, "floor_print", 3.22, 3.7, 1.26, 1.71, _cell(1020, 1750, 300, 280), -.02)
	# Over the aisles: posters on wires, and the coiled lead somebody strung across for a fan years ago.
	var top := y + ROOM_HIGH
	_hanging_poster(.75, -1.5, top, "floor_print", _cell(1020, 1750, 300, 280), 280.0 / 300.0)
	_hanging_poster(.75, -3.1, top, "art", _cell(0, 0, 1024, 1200), 1200.0 / 1024.0)
	_hanging_poster(3.9, -2.3, top, "floor_print", _cell(1020, 1320, 300, 420), 420.0 / 300.0)
	_hanging_poster(3.9, -3.3, top, "floor_print", _cell(1230, 0, 400, 300), .75, _cell(1230, 310, 400, 70))
	_curly_lead(Vector2(.62, -2.3), Vector2(4.1, -3.6), top, Color("#d8d2c0"))
	# What a room that is actually run leaves about: the staff's rack, a fan, a bin, drinks.
	_wire_rack(y)
	_solid(4.63, 4.98, y, y + 1.7, -3.7, -3.1)
	_stand_fan(f * Vector3(4.72, y, -4.2))
	_solid(4.57, 4.87, y, y + 1.55, -4.4, -4.0) # As wide as the wire head, not the foot.
	_bin(f * Vector3(.45, y, -4.25)) # Far enough down the wall to leave a metre past the row's corner.
	_solid(.3, .6, y, y + .56, -4.4, -4.1)
	# The spare cable, kicked in under the bottom shelf, where the rack's own footprint keeps feet off it.
	var coil: Array[Vector3] = []
	for i: int in range(58):
		var a := TAU * float(i) / 18.0
		var r := .12 - float(i) * .00047
		coil.append(f * Vector3(4.8 + cos(a) * r, y + .008 + float(i) * .0004, -3.42 + sin(a) * r))
	_kit.tube("plain", coil, .006, Color("#17181a"), 4)
	var drink := Color("#9ad0e4")
	var left_on_deck := Transform3D(Basis(Vector3.UP, -PI * .5), f * Vector3(1.75, y, -2.26))
	_bottle(left_on_deck * Vector3(.325, .772, .39), drink)
	var left_on_top := Transform3D(Basis(Vector3.UP, PI * .5), f * Vector3(2.79, y, -3.0))
	var butt := left_on_top * Vector3(-.22, 1.567, -.25)
	var neck := left_on_top * Vector3(-.05, 1.567, -.27)
	var shoulder := butt.lerp(neck, .68)
	_kit.tube("gloss", [butt, shoulder], .03, drink, 8)
	_kit.tube("gloss", [shoulder, neck], .013, drink, 6)
	_ball(butt, Vector3.ONE * .03, drink, "gloss", 3, 8)
	_ball(shoulder, Vector3.ONE * .03, drink, "gloss", 3, 8)

func _bottle(at: Vector3, tint: Color) -> void:
	# A plastic drink, left standing where it was finished.
	_kit.lathe("gloss", at, [Vector2(.027, 0), Vector2(.03, .02), Vector2(.03, .13), Vector2(.012, .17), Vector2(.012, .2)], tint, 8)
	_kit.disc("plain", at + Vector3.UP * .2, Vector3.RIGHT, Vector3.FORWARD, .013, Color("#e8e8e4"))

func _bin(at: Vector3) -> void:
	# A grey bin with a pale liner folded over its rim.
	_kit.lathe("room", at, [Vector2(.12, 0), Vector2(.15, .53)], Color("#4a4e54"), 12)
	_kit.lathe("room", at, [Vector2(.156, .49), Vector2(.158, .55), Vector2(.13, .552)], Color("#e8e6e0"), 12)
	_kit.disc("plain", at + Vector3.UP * .54, Vector3.RIGHT, Vector3.FORWARD, .132, Color("#26262a"))

func _stand_fan(at: Vector3) -> void:
	# The pedestal fan every hall keeps by the machines that run hot, its head tipped down at the room.
	var skin := Color("#a4a4a0")
	_kit.lathe("room", at, [Vector2(.15, 0), Vector2(.15, .02), Vector2(.03, .05), Vector2(.015, .06)], skin, 24)
	_kit.tube("room", [at, at + Vector3.UP * 1.3], .014, skin, 6)
	var out := Vector3(-cos(.26), -sin(.26), 0)
	var right := out.cross(Vector3.UP).normalized()
	var up := right.cross(out)
	var hub := at + Vector3.UP * 1.35
	_ball(hub - out * .07, Vector3(.055, .055, .08), skin, "room", 5, 8, Basis(right, up, -out))
	_kit.disc("room", hub + out * .02, right, up, .045, skin)
	for ring: float in [.2, .13]:
		var wire: Array[Vector3] = []
		for i: int in range(25):
			var a := TAU * float(i) / 24.0
			wire.append(hub + (right * cos(a) + up * sin(a)) * ring + out * .02)
		_kit.tube("room", wire, .004, skin, 3)
	for i: int in range(12):
		var a := TAU * float(i) / 12.0
		_kit.tube("room", [hub + (right * cos(a) + up * sin(a)) * .045 + out * .02, hub + (right * cos(a) + up * sin(a)) * .2 + out * .02], .002, skin, 3)
	for i: int in range(3):
		var a := TAU * float(i) / 3.0 + .4
		var along := right * cos(a) + up * sin(a)
		var across := right * cos(a + 1.57) + up * sin(a + 1.57)
		var a0 := hub + along * .04 - across * .03
		var a1 := hub + along * .17 - across * .05
		var a2 := hub + along * .17 + across * .05
		var a3 := hub + along * .04 + across * .03
		_kit.quad("room", a0, a1, a2, a3, Color("#c4c8cc"))
		_kit.quad("room", a3, a2, a1, a0, Color("#a8acb0"))

func _wire_rack(y: float) -> void:
	# Chrome wire shelving on the east wall, where the dead boards go to wait for a man who no longer
	# comes, and the top shelf the shift's visors charge on.
	var f := _front
	var chrome := Color("#b8bcc2")
	var x0 := 4.64
	var x1 := 4.97
	var near := -3.11
	var far := -3.69
	for c: Vector2 in [Vector2(x0, near), Vector2(x1, near), Vector2(x0, far), Vector2(x1, far)]:
		_kit.tube("chrome", [f * Vector3(c.x, y, c.y), f * Vector3(c.x, y + 1.7, c.y)], .008, chrome, 5)
	for level: float in [.22, .68, 1.14, 1.6]:
		var at := y + level
		_kit.tube("chrome", [f * Vector3(x0, at, near), f * Vector3(x1, at, near), f * Vector3(x1, at, far), f * Vector3(x0, at, far), f * Vector3(x0, at, near)], .006, chrome, 4)
		for i: int in range(1, 6):
			var z := near + (far - near) * float(i) / 6.0
			_kit.tube("chrome", [f * Vector3(x0, at, z), f * Vector3(x1, at, z)], .003, chrome, 3)
	var dead := Color("#1a1c20")
	for row: Vector2 in [Vector2(.22, -3.26), Vector2(.68, -3.52)]:
		_bar("plain", f, 4.8, y + row.x + .131, row.y, Vector3(.24, .25, .3), dead)
		_bar("gloss", f, 4.679, y + row.x + .131, row.y, Vector3(.004, .2, .25), Color("#0c0e12"))
	for i: int in range(3):
		_bar("plain", f, 4.8 + float(i) * .012, y + 1.152 + float(i) * .03, -3.38 - float(i) * .02, Vector3(.2, .014, .17), Color("#1f5a3a"))
		_bar("plain", f, 4.76 + float(i) * .012, y + 1.163 + float(i) * .03, -3.36 - float(i) * .02, Vector3(.05, .008, .05), Color("#16181a"))
	_bar("plain", f, 4.8, y + 1.622, -3.4, Vector3(.26, .03, .5), Color("#20242a"))
	for i: int in range(4):
		var z := -3.22 - float(i) * .12
		_ball(f * Vector3(4.78, y + 1.665, z), Vector3(.085, .03, .05), Color("#0c1018"), "gloss", 3, 8)
		_bar("led_low", f, 4.692, y + 1.665, z, Vector3(.006, .012, .012), CYAN)

func _cab(t: Transform3D, game: int) -> void:
	# The white sit-down cabinet Japan has built since the eighties: origin at the floor under the
	# screen, +z towards the player. A coloured crown, speakers either side of a small lit title, a
	# deep black bezel under its hood, a printed panel in a thick white lip, and two doors below.
	var half := .355 # A finger's width to the next one, so a row reads as machines and not one long desk.
	var white := Color("#e4e4e6")
	var crown: Color = [Color("#a8121c"), Color("#123a8a"), Color("#127a3c"), Color("#c85a10"), Color("#0e5a38")][game]
	var glow: Color = [Color(1.0, .5, .25), Color(.35, .42, 1.0), Color(.3, .9, .5), Color(1.0, .45, .3), Color(.22, .85, .45)][game]
	var seam := Color("#a8a8ac")
	var outline: Array[Vector2] = [Vector2(.08, .05), Vector2(.08, .6), Vector2(.42, .7), Vector2(.44, .76), Vector2(.14, .86), Vector2(-.1, 1.33), Vector2(.02, 1.38), Vector2(.02, 1.52), Vector2(-.3, 1.54), Vector2(-.52, 1.2), Vector2(-.52, .05)]
	_extrude("shell_in", t, outline, -half, half, white)
	_bar("plain", t, 0, .025, -.22, Vector3(half * 2.0 - .04, .05, .58), Color("#101014"))
	_bar("shell_in", t, 0, 1.495, .022, Vector3(half * 2.0 - .05, .05, .006), crown)
	_bar("plain", t, 0, 1.425, .022, Vector3(half * 2.0 - .05, .08, .004), Color("#101014"))
	_panel("floor_lit", t, -.17, .17, 1.395, 1.455, .0255, _cell(float(game) * 410.0, 310, 400, 70))
	for side: float in [-1.0, 1.0]:
		_bar("shell_in", t, side * .26, 1.425, .03, Vector3(.16, .085, .05), white)
		_bar("plain", t, side * .26, 1.425, .056, Vector3(.12, .06, .004), Color("#101014"))
	var screen := _slope(t, Vector2(.14, .86), Vector2(-.1, 1.33))
	_bar("gloss", screen, 0, .26, .004, Vector3(.6, .5, .008), Color("#050507"))
	_panel("floor_screen", screen, -.26, .26, .06, .45, .009, _cell(float(game) * 410.0, 0, 400, 300))
	_kit.quad("front", screen * Vector3(-.265, .055, .014), screen * Vector3(-.265, .455, .014), screen * Vector3(.265, .455, .014), screen * Vector3(.265, .055, .014), Color.WHITE)
	_bar("shell_in", screen, 0, .53, .03, Vector3(.7, .05, .06), white)
	for side: float in [-1.0, 1.0]:
		_bar("shell_in", screen, side * .32, .26, .015, Vector3(.04, .5, .03), white)
	var deck := _slope(t, Vector2(.44, .76), Vector2(.14, .86))
	# The panel: a printed sheet under clear acrylic, held by a carriage bolt at each corner, the
	# game's colour run along its edges. Sticks and 30 mm buttons stand through it, two players' worth.
	_bar("gloss", deck, 0, .158, .003, Vector3(.62, .2, .006), Color("#16181f"))
	for y: float in [.064, .252]:
		_bar("paint", deck, 0, y, .0062, Vector3(.6, .005, .001), crown)
	for x: float in [-.295, .295]:
		for y: float in [.072, .244]:
			_ball(deck * Vector3(x, y, .006), Vector3(.006, .0025, .006), Color("#0c0c0e"), "metal", 2, 8, _turn_axes(deck))
	_bar("shell_in", t, 0, .72, .432, Vector3(half * 2.0 - .02, .05, .006), white)
	var caps: Array[Color] = [Color("#e01e2c"), Color("#f0c010"), Color("#2a6de0")]
	for player: float in [-.155, .155]:
		_stick(deck, player - .075, .15, Color("#d81818"))
		for i: int in range(6):
			var column := i % 3
			var at := Vector2(player + .005 + float(column) * .039, .118 + float(i / 3) * .044 + (.008 if column == 1 else 0.0)) # Set on an arc, as the hand lies.
			_button(deck, at, .015, caps[column])
		_button(deck, Vector2(player + .06, .228), .011, Color("#f2f2ee")) # Start.
	# The 2050 way to pay, up on the lip by the screen where your hand already is.
	_bar("gloss", deck, .25, .287, .004, Vector3(.1, .044, .006), Color("#0a0c12"))
	_kit.disc("led_low", deck * Vector3(.226, .287, .0075), deck.basis.x, deck.basis.y, .017, CYAN)
	_kit.disc("gloss", deck * Vector3(.226, .287, .008), deck.basis.x, deck.basis.y, .012, Color("#0c1018"))
	_bar("led_low", deck, .275, .287, .0075, Vector3(.03, .006, .001), CYAN)
	# Two doors, a lock, the older reader on the right one, and a steel kick plate for the shoes.
	for x: float in [-.31, .04, .31]:
		_bar("plain", t, x, .33, .0808, Vector3(.004, .5, .002), seam)
	for y: float in [.08, .58]:
		_bar("plain", t, 0, y, .0808, Vector3(.624, .004, .002), seam)
	_kit.disc("metal", t * Vector3(0, .33, .0815), t.basis.x, t.basis.y, .012, Color("#b8bcc2"))
	_bar("metal", t, .175, .36, .084, Vector3(.2, .24, .006), Color("#8a8c90"))
	for x: float in [.125, .225]:
		_bar("led_low", t, x, .4, .088, Vector3(.03, .05, .004), Color(1.0, .2, .1))
	for i: int in range(5):
		_bar("plain", t, .175, .28 + float(i) * .012, .0875, Vector3(.12, .004, .002), Color("#2a2c30"))
	_bar("chrome", t, 0, .03, .076, Vector3(half * 2.0 - .02, .06, .012), Color("#b8bcc2"))
	# What the screen throws on the floor round the stool: the only light these machines need.
	var low := .004
	_kit.atlas("spill", t * Vector3(-.45, low, 1.08), t * Vector3(-.45, low, .08), t * Vector3(.45, low, .08), t * Vector3(.45, low, 1.08), Rect2(0, 0, 1, 1), glow * .36)

func _cab_stripe(t: Transform3D, side: float, tint: Color) -> void:
	# The exposed end of a row: a stripe in from the moulded edge, foot to crown, one ribbon mitred at each bend.
	var line: Array[Vector2] = [Vector2(.05, .08), Vector2(.05, .625), Vector2(.385, .72), Vector2(.13, .835), Vector2(-.125, 1.32), Vector2(-.01, 1.395), Vector2(-.01, 1.495), Vector2(-.28, 1.51)]
	var last := line.size() - 1
	var miters: Array[Vector2] = []
	for i: int in range(last + 1):
		var from := (line[mini(i + 1, last)] - line[i]).normalized() if i == 0 else (line[i] - line[i - 1]).normalized()
		var to := from if i == last else (line[i + 1] - line[i]).normalized()
		var n0 := Vector2(-from.y, from.x)
		var bisect := (n0 + Vector2(-to.y, to.x)).normalized()
		miters.append(bisect * .015 / bisect.dot(n0))
	var edge := func(i: int, out: float) -> Vector3:
		var p: Vector2 = line[i] + miters[i] * out
		return t * Vector3(side * .3565, p.y, p.x)
	for i: int in range(last):
		_kit.quad("shell_in", edge.call(i, side), edge.call(i, -side), edge.call(i + 1, -side), edge.call(i + 1, side), tint)

func _stick(deck: Transform3D, x: float, y: float, tint: Color) -> void:
	# A Japanese stick: a black dust washer flat on the panel, a short steel shaft, and a 35 mm ball top
	# with its moulding seam.
	var axes := _turn_axes(deck)
	var foot := deck * Vector3(x, y, .006) # The printed panel's face.
	_turned("plain", foot, axes, [Vector2(.019, 0), Vector2(.019, .0015), Vector2(.012, .0025), Vector2(.0055, .003), Vector2(.0045, .0045)], Color("#0c0c10"), 20)
	_turned("chrome", foot, axes, [Vector2(.004, .004), Vector2(.004, .03), Vector2(.006, .033)], Color("#c4c8cc"), 10)
	var top := foot + deck.basis.z * .047
	_ball(top, Vector3.ONE * .0175, tint, "gloss", 8, 16, axes)
	_turned("gloss", top, axes, [Vector2(.0177, -.0008), Vector2(.0177, .0008)], tint * .7, 16)

func _button(deck: Transform3D, at: Vector2, radius: float, tint: Color) -> void:
	# A snap-in push button: a raised bezel ring round a domed plunger, both in the cap's own plastic.
	var axes := _turn_axes(deck)
	var foot := deck * Vector3(at.x, at.y, .006)
	var k := radius / .015
	_turned("gloss", foot, axes, [Vector2(.0152 * k, 0), Vector2(.0152 * k, .0022), Vector2(.0143 * k, .0032), Vector2(.0131 * k, .0032), Vector2(.0128 * k, .0024)], tint * .82, 20)
	_turned("gloss", foot, axes, [Vector2(.0122 * k, .0024), Vector2(.0122 * k, .0046), Vector2(.0105 * k, .0058), Vector2(.006 * k, .0064), Vector2(0, .0066)], tint, 20)

func _turn_axes(deck: Transform3D) -> Basis:
	# Axes for a turned part standing square out of a sloped face: its y is the face's normal.
	return Basis(deck.basis.x, deck.basis.z, -deck.basis.y)

func _turned(part: String, base: Vector3, axes: Basis, profile: Array[Vector2], tint: Color, sides := 12) -> void:
	# The kit's lathe, about any axis: profile is radius and height along axes.y.
	for j: int in range(profile.size() - 1):
		var p0 := profile[j]
		var p1 := profile[j + 1]
		var slope := Vector2(p1.y - p0.y, p0.x - p1.x).normalized()
		for s: int in range(sides):
			var a0 := TAU * float(s) / float(sides)
			var a1 := TAU * float(s + 1) / float(sides)
			var dir0 := Vector3(cos(a0), 0, sin(a0))
			var dir1 := Vector3(cos(a1), 0, sin(a1))
			var n0 := axes * (dir0 * slope.x + Vector3.UP * slope.y).normalized()
			var n1 := axes * (dir1 * slope.x + Vector3.UP * slope.y).normalized()
			var a := base + axes * (dir0 * p0.x + Vector3.UP * p0.y)
			var b := base + axes * (dir0 * p1.x + Vector3.UP * p1.y)
			var c := base + axes * (dir1 * p1.x + Vector3.UP * p1.y)
			var d := base + axes * (dir1 * p0.x + Vector3.UP * p0.y)
			_kit.smooth(part, a, b, c, d, n0, n0, n1, n1, tint)

func _washer(t: Transform3D) -> void:
	# The round touch-ring music game the Japanese call a washing machine, and so does everyone.
	var half := .31
	var outline: Array[Vector2] = [Vector2(.08, .05), Vector2(.14, .5), Vector2(.1, .84), Vector2(-.04, 1.46), Vector2(-.06, 1.62), Vector2(-.16, 1.74), Vector2(-.5, 1.74), Vector2(-.5, .05)]
	_extrude("shell_in", t, outline, -half, half, Color("#eceef2"))
	var face := _slope(t, Vector2(.1, .84), Vector2(-.04, 1.46))
	var centre := face * Vector3(0, .31, .004)
	_kit.disc("plain", centre, face.basis.x, face.basis.y, .285, Color("#101018"))
	_kit.disc("floor_screen", face * Vector3(0, .31, .008), face.basis.x, face.basis.y, .25, Color.WHITE, _cell(330, 1660, 220, 220))
	var ring: Array[Vector3] = []
	for i: int in range(33):
		var a := TAU * float(i) / 32.0
		ring.append(face * Vector3(cos(a) * .272, .31 + sin(a) * .272, .012))
	_kit.tube("neon", ring, .009, Color(.3, .8, 1.0), 5)
	for i: int in range(8):
		var a := TAU * float(i) / 8.0 + .39
		_kit.disc("led_low", face * Vector3(cos(a) * .3, .31 + sin(a) * .3, .009), face.basis.x, face.basis.y, .026, Color(1.0, .86, .2))
	var brow := _slope(t, Vector2(-.04, 1.46), Vector2(-.06, 1.62)) # The card lies on the brow over the ring.
	_panel("sign_in", brow, -.18, .18, .045, .155, .002, _cell(470, 300, 460, 140))
	var foot := _slope(t, Vector2(.08, .05), Vector2(.14, .5)) # The shin leans out, and the coin door leans with it.
	_bar("metal", foot, 0, .27, .003, Vector3(.22, .22, .006), Color("#a8acb0"))

func _dj_cab(t: Transform3D) -> void:
	# Taken from the real two-deck machine: black gloss, a marquee over a big screen, light up both
	# uprights, turntables and keys on a deck proud of the body, woofers below, and steel to stand on.
	var half := .55
	var dark := Color("#08080a")
	var black := Color("#101014")
	var steel := Color("#6a6e74")
	var light := Color(.22, .42, 1.0)
	var body: Array[Vector2] = [Vector2(.08, .05), Vector2(.08, .86), Vector2(.04, 1.0), Vector2(.0, 1.86), Vector2(-.1, 1.98), Vector2(-.5, 1.98), Vector2(-.5, .05)]
	_extrude("shell_in", t, body, -half, half, black)
	_bar("steel_in", t, 0, .03, .29, Vector3(half * 2.0 - .04, .05, .42), steel)
	_bar("plain", t, 0, .058, .29, Vector3(.7, .004, .36), Color("#18181c"))
	# The lower cabinet: a woofer either side of the service door.
	for side: float in [-1.0, 1.0]:
		var at := t * Vector3(side * .33, .47, .083)
		_kit.disc("plain", at, t.basis.x, t.basis.y, .175, dark)
		_kit.disc("metal", at + t.basis.z * .002, t.basis.x, t.basis.y, .155, Color("#26272c"))
		_kit.disc("plain", at + t.basis.z * .004, t.basis.x, t.basis.y, .115, Color("#16171b"))
		_kit.disc("metal", at + t.basis.z * .006, t.basis.x, t.basis.y, .04, Color("#4a4c52"))
		var ring: Array[Vector3] = []
		for i: int in range(25):
			var a := TAU * float(i) / 24.0
			ring.append(at + t.basis.z * .006 + (t.basis.x * cos(a) + t.basis.y * sin(a)) * .165)
		_kit.tube("led_low", ring, .0045, light, 4)
	_bar("plain", t, 0, .46, .082, Vector3(.2, .72, .004), Color("#17171b"))
	_kit.disc("metal", t * Vector3(.07, .5, .085), t.basis.x, t.basis.y, .014, Color("#6a6c72"))
	for i: int in range(6):
		_bar("plain", t, 0, .2 + float(i) * .024, .085, Vector3(.13, .009, .002), dark)
	# The deck, with a steel lip, two platters, and the keys beside each.
	var deck_side: Array[Vector2] = [Vector2(.46, .8), Vector2(.46, .86), Vector2(.1, 1.0), Vector2(.0, 1.0), Vector2(.0, .76), Vector2(.12, .76)]
	_extrude("shell_in", t, deck_side, -half, half, Color("#141418"))
	_bar("steel_in", t, 0, .83, .462, Vector3(half * 2.0, .05, .006), steel)
	var keys := _slope(t, Vector2(.46, .86), Vector2(.1, 1.0))
	var run := Vector2(.36, .14).length()
	_bar("plain", keys, 0, run * .5, .002, Vector3(half * 2.0 - .04, run - .02, .004), Color("#1e1f24"))
	for side: float in [-1.0, 1.0]:
		var hub := keys * Vector3(side * .4, run * .5, .006)
		_kit.disc("plain", hub, keys.basis.x, keys.basis.y, .125, dark)
		_kit.disc("metal", hub + keys.basis.z * .003, keys.basis.x, keys.basis.y, .105, Color("#a8acb0"))
		_kit.disc("plain", hub + keys.basis.z * .005, keys.basis.x, keys.basis.y, .022, Color("#1a1a1e"))
		for i: int in range(7):
			var up := i % 2 == 1
			var x := side * .17 + (float(i) - 3.0) * .03
			_bar("led_low", keys, x, run * (.64 if up else .4), .008, Vector3(.024, .05, .006), Color("#34343e") if up else Color(.92, .92, .98))
	_bar("plain", keys, 0, run * .55, .006, Vector3(.1, .15, .004), Color("#0a0c10"))
	_bar("led_low", keys, 0, run * .55, .009, Vector3(.08, .1, .002), Color(.2, .34, .5))
	# The screen deep in its bezel, and the lit uprights.
	var glass := _slope(t, Vector2(.04, 1.0), Vector2(.0, 1.86))
	var tall := Vector2(.04, .86).length()
	_bar("plain", glass, 0, tall * .5, .002, Vector3(.76, tall - .02, .006), dark)
	_panel("sign_in", glass, -.33, .33, .02, tall - .02, .006, _cell(1830, 1110, 200, 260))
	for side: float in [-1.0, 1.0]:
		_bar("shell_in", t, side * .49, 1.42, -.02, Vector3(.12, 1.02, .16), black)
		_bar("neon", t, side * .49, 1.42, .062, Vector3(.016, .92, .006), light)
		_bar("shell_in", t, side * .46, 1.92, -.28, Vector3(.05, .12, .1), black)
	# The marquee on its uprights, tipped down at the players.
	var box: Array[Vector2] = [Vector2(.06, 1.9), Vector2(.02, 2.12), Vector2(-.34, 2.12), Vector2(-.3, 1.9)]
	_extrude("shell_in", t, box, -half + .02, half - .02, black)
	_panel("sign_in", _slope(t, Vector2(.06, 1.9), Vector2(.02, 2.12)), -.38, .38, .0, .22, .003, _cell(1830, 1445, 200, 60))
	# The flanks: seams, a vent, and the one label everyone reads.
	for side: float in [-1.0, 1.0]:
		var flank := Transform3D(t.basis * Basis(Vector3.BACK * -side, Vector3.UP, Vector3.RIGHT * side), t * Vector3(side * half, 0, 0))
		var mid := side * .21
		_bar("plain", flank, mid, .86, .003, Vector3(.56, .006, .004), dark)
		_bar("plain", flank, mid, .1, .003, Vector3(.56, .1, .004), Color("#17181b"))
		for i: int in range(6):
			_bar("plain", flank, mid, 1.2 + float(i) * .024, .003, Vector3(.2, .009, .004), dark)
		_bar("gold", flank, mid, 1.6, .004, Vector3(.13, .05, .002), Color(.9, .72, .16))

func _drum_game(t: Transform3D) -> void:
	# A pair of real taiko on carved cradles over a white printed base with its coin door, a framed
	# screen with the song cards either side, and a topper cut to anything but a rectangle.
	var dark := Color("#201410")
	var red := Color("#c8281c")
	_bar("shell_in", t, 0, .32, -.3, Vector3(1.7, .64, .96), Color("#efece4")) # Stops inside the top band, which lids it.
	_bar("shell_in", t, 0, .66, -.3, Vector3(1.72, .08, .98), red) # Painted, not polished: a mirror finish turns this red to salmon.
	_bar("shell_in", t, 0, .03, -.3, Vector3(1.72, .06, .98), red)
	_bar("room", t, 0, .34, .184, Vector3(.3, .54, .008), Color("#f8f6f0"))
	_bar("plain", t, 0, .34, .1885, Vector3(.29, .003, .001), Color("#b8b4a8"))
	_bar("plain", t, 0, .47, .189, Vector3(.1, .05, .002), Color("#0c0c10"))
	_bar("plain", t, 0, .22, .189, Vector3(.16, .03, .002), Color("#0c0c10"))
	for side: float in [-1.0, 1.0]:
		_panel("sign_in", t, side * .5 - .3, side * .5 + .3, .13, .55, .182, _cell(1730, 1830, 300, 210))
	# The screen in its red frame: a note lane with the next seven beats coming down it.
	_bar("shell_in", t, 0, 1.18, -.72, Vector3(1.0, .96, .2), red)
	_bar("plain", t, 0, 1.19, -.617, Vector3(.92, .84, .006), Color("#f4f0e8"))
	_bar("room", t, 0, 1.2, -.613, Vector3(.84, .72, .006), Color("#0a1030"))
	_bar("panel", t, 0, 1.36, -.609, Vector3(.7, .14, .003), Color("#2a3048"))
	_kit.disc("led_low", t * Vector3(-.3, 1.36, -.6065), t.basis.x, t.basis.y, .062, Color(.95, .95, 1.0))
	_kit.disc("panel", t * Vector3(-.3, 1.36, -.606), t.basis.x, t.basis.y, .052, Color("#2a3048"))
	var beats: Array[Color] = [Color(1.0, .25, .2), Color(1.0, .25, .2), Color(.25, .55, 1.0), Color(1.0, .25, .2), Color(.25, .55, 1.0), Color(.25, .55, 1.0), Color(1.0, .25, .2)]
	for i: int in range(7):
		_kit.disc("led_low", t * Vector3(-.2 + float(i) * .085, 1.36, -.6055), t.basis.x, t.basis.y, .034, beats[i])
	_bar("led_low", t, -.12, 1.02, -.609, Vector3(.42, .03, .003), Color(1.0, .75, .2))
	# Song cards in plastic sleeves either side, and the board the whole thing wears on its head.
	for side: float in [-1.0, 1.0]:
		var x := side * .66
		_bar("metal", t, x, .83, -.72, Vector3(.04, .26, .03), Color("#6a6c70"))
		_bar("prize", t, x, 1.27, -.72, Vector3(.26, .62, .04), Color("#f6f1e6"))
		_panel("floor_print", t, x - .11, x + .11, 1.31, 1.475, -.698, _cell(0.0 if side < 0.0 else 820.0, 0, 400, 300))
		_panel("floor_print", t, x - .11, x + .11, 1.06, 1.225, -.698, _cell(410.0 if side < 0.0 else 1640.0, 0, 400, 300))
	_bar("room", t, 0, 1.95, -.63, Vector3(1.66, .58, .058), dark)
	for disc: Array in [[-.8, 2.0, .22, Color("#2a9a4a")], [-.84, 1.72, .17, Color("#2a6ad0")], [-.32, 2.1, .16, Color("#d8301c")], [.32, 2.1, .16, Color("#2a9a4a")], [.74, 2.02, .2, Color("#2a6ad0")], [.78, 1.74, .16, Color("#d8301c")]]:
		_kit.disc("shell_in", t * Vector3(disc[0], disc[1], -.664), t.basis.x, t.basis.y, disc[2], disc[3])
	# The board runs the machine's width in the print's own orange, so its round mark can stay round.
	_panel("sign_in", t, -.82, .82, 1.68, 2.22, -.6, _cell(1738, 1838, 8, 8))
	_panel("sign_in", t, -.386, .386, 1.68, 2.22, -.598, _cell(1730, 1830, 300, 210))
	for side: float in [-1.0, 1.0]:
		var low := t * Vector3(side * .42, .86, -.22)
		var high := t * Vector3(side * .42, 1.08, .06)
		var face := (high - low).normalized()
		var across := t.basis.x
		var up := face.cross(across)
		var mid := (low + high) * .5
		var skin := mid + face * .21
		_bar("shell_in", t, side * .42, .725, -.1, Vector3(.6, .05, .32), Color("#7a2418"))
		_bar("shell_in", t, side * .42, .8, -.1, Vector3(.46, .12, .28), Color("#7a2418"))
		_barrel(mid, Basis(across, face, across.cross(face)), .42, [.22, .27, .3, .3, .275], Color("#a8481a"))
		_kit.disc("panel", skin, across, up, .265, Color("#e6c48c") * .56) # Cream hide, by any light; paler and the camera greys it.
		var rim: Array[Vector3] = []
		for i: int in range(29):
			var a := TAU * float(i) / 28.0
			rim.append(skin - face * .012 + (across * cos(a) + up * sin(a)) * .275)
		_kit.tube("plain", rim, .014, Color("#1c1412"), 5)
		# The mesh pocket on the front with the sticks stood in it.
		_bar("plain", t, side * .6, .5, .19, Vector3(.1, .36, .02), Color("#3050a0"))
		for stick: float in [-.02, .02]:
			_kit.tube("plain", [t * Vector3(side * .6 + stick, .42, .2), t * Vector3(side * .6 + stick * 1.5, .78, .205)], .011, Color("#d8c8a8"), 5)

func _barrel(mid: Vector3, axes: Basis, length: float, radii: Array[float], tint: Color) -> void:
	# A turned drum body along axes.y, tail to rim: a ring for each radius, the belly swelling between them.
	var sides := 20
	var last := radii.size() - 1
	var step := length / float(last)
	for r: int in range(last):
		var y0 := -length * .5 + step * float(r)
		var y1 := y0 + step
		var lean0 := (radii[maxi(r - 1, 0)] - radii[r + 1]) / (step * 2.0)
		var lean1 := (radii[r] - radii[mini(r + 2, last)]) / (step * 2.0)
		for s: int in range(sides):
			var a0 := TAU * float(s) / float(sides)
			var a1 := TAU * float(s + 1) / float(sides)
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var a := mid + axes * (d0 * radii[r] + Vector3.UP * y0)
			var b := mid + axes * (d0 * radii[r + 1] + Vector3.UP * y1)
			var c := mid + axes * (d1 * radii[r + 1] + Vector3.UP * y1)
			var d := mid + axes * (d1 * radii[r] + Vector3.UP * y0)
			_kit.smooth("shell_in", a, b, c, d, axes * (d0 + Vector3.UP * lean0).normalized(), axes * (d0 + Vector3.UP * lean1).normalized(), axes * (d1 + Vector3.UP * lean1).normalized(), axes * (d1 + Vector3.UP * lean0).normalized(), tint)

# ---------------------------------------------------------------- 4F: the medal floor

func _medal_floor(y: float) -> void:
	# Change your yen for tokens, then lose them slowly: slots, medal pachinko and a coin pusher.
	var f := _front
	_room(y, 2)
	_zone_boards(y + 2.34, [_cell(0, 450, 460, 140), _cell(470, 450, 460, 140), _cell(940, 450, 460, 140)])
	_pusher(Transform3D(Basis.IDENTITY, f * Vector3(2.6, y, -2.44))) # Set back to leave a clear metre along the glass.
	_solid(1.825, 3.375, y, y + 2.3, -3.725, -1.155)
	var faces: Array[Rect2] = [_cell(0, 400, 300, 520), _cell(310, 400, 300, 520), _cell(620, 400, 300, 520)]
	var tops: Array[Color] = [Color(1.0, .3, .2), Color(.2, .7, 1.0), Color(.8, .3, 1.0)]
	var i := 0
	for z: float in [-1.0, -1.62, -2.24, -2.86]:
		_slot(Transform3D(Basis(Vector3.UP, PI * .5), f * Vector3(.72, y, z)), faces[i % 3], tops[i % 3])
		i += 1
	_solid(.2, .82, y, y + 2.02, -3.17, -.69)
	var game := 0
	for z: float in [-1.0, -1.72, -2.44]:
		_pachi(Transform3D(Basis(Vector3.UP, -PI * .5), f * Vector3(4.48, y, z)), game)
		_swivel(f * Vector3(4.1, y, z), Vector3.LEFT, Color("#17171b"))
		game += 1
	_bar("steel_in", f, 4.43, y + .74, -1.72, Vector3(.1, .03, 2.16), Color("#585c62")) # The one steel shelf the whole bank's trays stand on.
	_solid(4.38, 4.98, y, y + 1.9, -2.81, -.63)
	for x: float in [3.5, 4.12]:
		_slot(Transform3D(Basis.IDENTITY, f * Vector3(x, y, -5.1)), faces[i % 3], tops[i % 3])
		i += 1
	_solid(3.2, 4.43, y, y + 2.02, -5.6, -5.0)
	var kiosk := Transform3D(Basis.IDENTITY, f * Vector3(1.9, y, -5.24))
	_kiosk(kiosk, "shell_in", "led_in")
	_floor_glow(kiosk, 0, .02, Color(1.0, .25, .15) * .16)
	_solid(1.65, 2.15, y, y + 1.7, -5.6, -5.2)
	# The plaques down both aisles, and the trays a good run leaves stacked by the wall.
	var top := y + ROOM_HIGH
	_fan_string(top, 1.3, -.7, -3.9)
	_fan_string(top, 3.85, -.7, -3.9)
	var balls := Rect2(0, 0, 512.0 / 1024.0, 256.0 / 1024.0)
	var coins := Rect2(520.0 / 1024.0, 0, 500.0 / 1024.0, 256.0 / 1024.0)
	_tray(f * Vector3(.42, y, -3.42), .1, 4, coins)
	_tray(f * Vector3(.42, y, -3.72), -.06, 3, balls)
	_tray(f * Vector3(4.72, y, -3.3), PI * .5, 3, balls)
	_tray(f * Vector3(4.72, y, -3.72), PI * .5 + .1, 5, coins)
	_solid(.2, .64, y, y + .6, -3.9, -3.26)
	_solid(4.56, 4.98, y, y + .6, -3.92, -3.1)
	var west := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(.2, y, -.1))
	var poster := Rect2(0, 270.0 / 1024.0, 340.0 / 1024.0, 480.0 / 1024.0)
	_framed(west, 3.2, 3.8, 1.0, 1.86, "photo_in", poster)
	# Lit units close the row ends, so the aisle does not open on a black slab.
	var turned := Basis(Vector3.UP, PI)
	var change := _cell(1020, 810, 300, 500)
	var jackpot := _cell(1830, 1540, 210, 280)
	_end_unit(Transform3D(Basis.IDENTITY, f * Vector3(.46, y, -.7)), .5, "floor_lit", change, 1.667, tops[0])
	_end_unit(Transform3D(turned, f * Vector3(.46, y, -3.16)), .5, "sign_in", jackpot, 1.333, tops[1])
	_end_unit(Transform3D(Basis.IDENTITY, f * Vector3(4.73, y, -.64)), .46, "photo_in", poster, 1.412, tops[1])
	_end_unit(Transform3D(turned, f * Vector3(4.73, y, -2.8)), .46, "sign_in", jackpot, 1.333, tops[2])

func _deep(tint: Color) -> Color:
	# Paint goes to the shader as linear light, so a lit colour has to be squared to keep its hue.
	return Color(tint.r * tint.r, tint.g * tint.g, tint.b * tint.b)

func _floor_glow(t: Transform3D, x: float, foot: float, tint: Color) -> void:
	# What a lit machine throws on the carpet at its foot; t's +z runs out into the aisle.
	_kit.atlas("wash_in", t * Vector3(x + .5, .006, foot), t * Vector3(x + .5, .006, foot + .7), t * Vector3(x - .5, .006, foot + .7), t * Vector3(x - .5, .006, foot), Rect2(0, 0, 1, .7), tint)

func _end_unit(t: Transform3D, wide: float, part: String, card: Rect2, aspect: float, strip: Color) -> void:
	# The end of a row: a dark plate, a lit card over the machines' own screen, a strip along its head.
	var half := wide * .44
	_bar("plain", t, 0, .96, .004, Vector3(wide, 1.8, .008), Color("#0c0c10"))
	_panel(part, t, -half, half, .86, .86 + half * 2.0 * aspect, .009, card)
	_panel("floor_lit", t, -half, half, .52, .52 + half * 2.0 * .5625, .009, _cell(1340, 1730, 320, 180))
	_bar("led_in", t, 0, 1.76, .01, Vector3(wide, .02, .004), _deep(strip) * .7)

func _palm_mark(t: Transform3D, x: float, y: float, z: float, r: float) -> void:
	# The 2050 way to pay, on any deck: a cyan ring on dark glass, a hand in a few short lines.
	var cyan := _deep(CYAN)
	_kit.disc("led_in", t * Vector3(x, y, z), t.basis.x, t.basis.y, r, cyan)
	_kit.disc("gloss", t * Vector3(x, y, z + .001), t.basis.x, t.basis.y, r * .82, Color("#0c1018"))
	_kit.disc("led_in", t * Vector3(x, y - r * .24, z + .002), t.basis.x, t.basis.y, r * .28, cyan)
	for k: int in range(4):
		_bar("led_in", t, x + (float(k) - 1.5) * r * .2, y + r * .22, z + .002, Vector3(r * .11, r * .42, .001), cyan)

func _deck_pad(t: Transform3D, x: float, y: float, z: float) -> void:
	# The palm plate on a machine's deck, tipped up so it reads from the aisle.
	var pad := Transform3D(t.basis * Basis(Vector3.RIGHT, -.7), t * Vector3(x, y, z))
	_bar("gloss", pad, 0, 0, 0, Vector3(.09, .09, .008), Color("#0a0c12"))
	_palm_mark(pad, 0, 0, .005, .036)

func _pusher(t: Transform3D) -> void:
	# A two-sided coin pusher: a painted deck heaped with medals, a shelf sliding back and forth to
	# nudge them over the lip, a glass box round it all with a prize wheel in it, and a lit arch on top.
	var steel := Color("#4c5056")
	var rainbow: Array[Color] = [Color("#ff2ea0"), Color("#ffd020"), Color("#20e070"), Color("#20a0ff")]
	_bar("shell_in", t, 0, .42, 0, Vector3(1.5, .76, 2.5), Color("#b01220"), .85, 1.0)
	_bar("plain", t, 0, .03, 0, Vector3(1.44, .06, 2.44), Color("#0a0a0c"))
	for y: float in [.1, .79]:
		_bar("steel_in", t, 0, y, 0, Vector3(1.53, .03, 2.53), steel)
	for turn: float in [0.0, PI]:
		var side := Transform3D(t.basis * Basis(Vector3.UP, turn), t.origin)
		_kit.atlas("floor_lit", side * Vector3(.72, .81, 1.22), side * Vector3(.06, .85, 1.22), side * Vector3(.06, .85, -1.22), side * Vector3(.72, .81, -1.22), _cell(1340, 856, 620, 394))
		_coin_heap(side)
		_shelf(side)
		var seat := Transform3D(side.basis * Basis(Vector3.UP, PI * .5), side * Vector3(.75, 0, 0))
		for s: float in [-.6, .6]:
			_pusher_station(seat, s)
			_stool(seat * Vector3(s, 0, .3), Color("#7a1414"), "steel_in", "shell_in", Color("#4a4d52"))
		var back := Transform3D(side.basis * Basis(Vector3.UP, PI * .5), side * Vector3(.055, 0, 0))
		_bar("steel_in", back, 0, .94, .006, Vector3(2.4, .16, .012), steel)
		# Low enough that the roof does not cut the title, and either side of the wheel, not behind it.
		_panel("floor_lit", back, -1.2, -.3, 1.02, 1.397, .0, _cell(1340, 550, 620, 260))
		_panel("floor_lit", back, .3, 1.2, 1.02, 1.397, .0, _cell(1340, 550, 620, 260))
		# The prize wheel, standing clear of the back panel with its own neon round it.
		_kit.disc("floor_lit", back * Vector3(0, 1.2, .035), back.basis.x, back.basis.y, .24, Color.WHITE, _cell(950, 420, 360, 360))
		var ring: Array[Vector3] = []
		for k: int in range(25):
			var a := TAU * float(k) / 24.0
			ring.append(back * Vector3(cos(a) * .26, 1.2 + sin(a) * .26, .035))
		_kit.tube("neon_in", ring, .008, _deep(Color(.9, .3, 1.0)), 4)
		_kit.quad("front", side * Vector3(.74, .82, 1.24), side * Vector3(.74, 1.52, 1.24), side * Vector3(.74, 1.52, -1.24), side * Vector3(.74, .82, -1.24), Color.WHITE)
		_kit.atlas("wash_in", side * Vector3(.745, .86, .62), side * Vector3(.745, 1.48, .16), side * Vector3(.745, 1.48, -.04), side * Vector3(.745, .86, .42), Rect2(0, .15, 1, .75), Color.WHITE * .06)
		# A static rainbow along the lip, proud of the steel band.
		for k: int in range(12):
			_bar("led_in", side, .766, .8, -1.22 + (float(k) + .5) * 2.44 / 12.0, Vector3(.015, .02, 2.44 / 12.0 - .008), _deep(rainbow[k % 4]) * .6)
		var tower := Transform3D(side.basis * Basis(Vector3.UP, PI * .5), side * Vector3(.082, 0, 0))
		_panel("sign_in", tower, -.169, .169, 1.7, 2.15, 0, _cell(1830, 1540, 210, 280))
		_panel("sign_in", tower, -.7, -.22, 1.79, 1.936, 0, _cell(0, 450, 460, 140))
		_panel("sign_in", tower, .22, .7, 1.79, 1.936, 0, _cell(470, 450, 460, 140))
		# The arch's face: a band of lit segments under a neon edge.
		var edge: Array[Vector3] = []
		for k: int in range(13):
			var a0 := PI * float(k) / 12.0
			var a1 := PI * float(k + 1) / 12.0
			edge.append(tower * Vector3(cos(a0) * .75, 2.0 + sin(a0) * .24, .004))
			if k < 12:
				_kit.quad("led_in", tower * Vector3(cos(a1) * .66, 2.0 + sin(a1) * .16, .002), tower * Vector3(cos(a1) * .72, 2.0 + sin(a1) * .215, .002), tower * Vector3(cos(a0) * .72, 2.0 + sin(a0) * .215, .002), tower * Vector3(cos(a0) * .66, 2.0 + sin(a0) * .16, .002), _deep(rainbow[k % 4]) * .6)
		_kit.tube("neon_in", edge, .011, _deep(Color(1.0, .3, .55)), 5)
		var end := Transform3D(side.basis, side * Vector3(0, 0, 1.25))
		_panel("floor_print", end, -.42, .42, .16, .729, .004, _cell(1340, 400, 620, 420))
		_kit.quad("front", end * Vector3(-.74, .82, -.01), end * Vector3(-.74, 1.52, -.01), end * Vector3(.74, 1.52, -.01), end * Vector3(.74, .82, -.01), Color.WHITE)
		_kit.atlas("wash_in", end * Vector3(-.34, .86, -.005), end * Vector3(.02, 1.48, -.005), end * Vector3(.2, 1.48, -.005), end * Vector3(-.16, .86, -.005), Rect2(0, .15, 1, .75), Color.WHITE * .06)
	_bar("shell_in", t, 0, 1.17, 0, Vector3(.1, .72, 2.44), Color("#101014"))
	_bar("gloss", t, 0, 1.58, 0, Vector3(1.53, .12, 2.54), Color("#0c0c12"))
	_bar("steel_in", t, 0, 1.52, 0, Vector3(1.55, .02, 2.56), steel)
	_bar("lamp_in", t, .4, 1.5, 0, Vector3(.05, .012, 2.2), Color(1.0, .95, .85))
	_bar("lamp_in", t, -.4, 1.5, 0, Vector3(.05, .012, 2.2), Color(1.0, .95, .85))
	var arch: Array[Vector2] = [Vector2(.75, 1.64), Vector2(.75, 2.0)]
	for k: int in range(1, 12):
		var a := PI * float(k) / 12.0
		arch.append(Vector2(cos(a) * .75, 2.0 + sin(a) * .24))
	arch.append(Vector2(-.75, 2.0))
	arch.append(Vector2(-.75, 1.64))
	_extrude("gloss", t, arch, -.08, .08, Color("#0c0c12"))
	for corner: Vector2 in [Vector2(-.74, -1.24), Vector2(.74, -1.24), Vector2(-.74, 1.24), Vector2(.74, 1.24)]:
		_bar("chrome", t, corner.x, 1.17, corner.y, Vector3(.022, .72, .022), Color("#b8bcc2"))
	# Fine bulbs set flat in the fascia, each in a chrome cup, close set all the way round the roof.
	for out: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var along := Vector3.UP.cross(out)
		var long := absf(out.x) > .5
		var reach := 1.24 if long else .74
		var face := out * (.767 if long else 1.272) + Vector3.UP * 1.58
		var at := -reach
		var i := 0
		while at <= reach + .001:
			var spot := t * (face + along * at)
			_kit.disc("chrome", spot, t.basis * along, t.basis.y, .013, Color("#9a9ea4"))
			_kit.disc("lamp_in", spot + t.basis * out * .001, t.basis * along, t.basis.y, .009, _deep([Color(1.0, .7, .2), Color(1.0, .18, .12)][i % 2]) * .5)
			at += .05
			i += 1

func _deck(x: float) -> float:
	# The height of a pusher's painted deck, x metres out from its spine.
	return lerpf(.85, .81, (x - .06) / .66)

func _coin_tile(here: Transform3D, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, tint: Color) -> void:
	# One true-scale patch of the coin photograph, flipped at random so the repeat does not show.
	var coins := Rect2(520.0 / 1024.0, 0, 500.0 / 1024.0, 256.0 / 1024.0)
	if _rng.randf() < .5:
		coins = Rect2(coins.end.x, 0, -coins.size.x, coins.size.y)
	_kit.atlas("photo_in", here * Vector3(x1, y1, z1), here * Vector3(x0, y0, z1), here * Vector3(x0, y0, z0), here * Vector3(x1, y1, z0), coins, tint)

func _coin_heap(side: Transform3D) -> void:
	# Medals 27 mm across, lapped like shingles over a bed of the real thing, deepest against the
	# shelf and hanging over the lip; only a few stray out to the painted lanes.
	var bed := Color(.85, .72, .55)
	var stagger: Array[float] = [-.05, .07, -.02, .04] # So the bed ends raggedly, not on one ruled line.
	for row: int in range(4): # Right out to the lip: only the end lanes show paint.
		var x0 := .335 + float(row) * .09625
		var x1 := x0 + .09625
		for col: int in range(10):
			var z0 := -1.04 + stagger[row] + float(col) * .208
			_coin_tile(side, x0, x1, z0, z0 + .208, _deck(x0) + .003, _deck(x1) + .003, bed)
	for i: int in range(700):
		var stray := _rng.randf() < .06
		var along := _rng.randf_range(-1.18, 1.18) if stray else _rng.randf_range(-1.02, 1.02)
		if i % 7 == 0: # Every seventh laps over an end of the bed and hides its edge.
			along = signf(_rng.randf() - .5) * _rng.randf_range(.92, 1.13)
		var s := _rng.randf_range(-1.0, 1.0)
		var bank := pow(absf(s), .6)
		var x := lerpf(.34, .72, .5 + .5 * signf(s) * bank)
		var drift := .5 + .5 * sin(along * 3.1 + 1.0)
		var depth := 0 if stray else mini(5, int(_rng.randf() * (1.0 + 1.5 * drift + 4.0 * bank * bank)))
		var y := _deck(x) + .007 + float(depth) * .004
		var lean := .08 if depth == 0 else .3
		_medal(side, Vector3(x, y, along), Vector3(_rng.randf_range(-lean, lean), 1.0, _rng.randf_range(-lean, lean)).normalized())

func _medal(here: Transform3D, at: Vector3, tilt: Vector3) -> void:
	# One medal: a whole coin out of the photograph, turned any way up, in copper or nickel.
	var right := tilt.cross(Vector3.FORWARD).normalized().rotated(tilt, _rng.randf() * TAU)
	var patch := (MEDALS[_rng.randi() % MEDALS.size()] - Vector2(29, 29)) / 1024.0
	var metal := Color(1.0, .8, .58).lerp(Color(.92, .94, .96), pow(_rng.randf(), 3.0))
	var tone := _rng.randf_range(.55, 1.0)
	_kit.disc("photo_in", here * at, here.basis * right, here.basis * tilt.cross(right), .0135, Color(metal.r * tone, metal.g * tone, metal.b * tone), Rect2(patch, Vector2(58, 58) / 1024.0))

func _shelf(side: Transform3D) -> void:
	# Built on its own so it can slide; everything else in the box stands still, but its own layer
	# of medals rides along on it, and the two columns that never quite fall.
	var shared := _kit
	_kit = Kit.new()
	var here := Transform3D(side.basis, Vector3.ZERO)
	_bar("steel_in", here, 0, 0, 0, Vector3(.24, .07, 2.3), Color("#565a60"))
	_bar("steel_in", here, .122, 0, 0, Vector3(.006, .05, 2.28), Color("#3e4248"))
	for row: int in range(2):
		var x0 := -.106 + float(row) * .106
		for col: int in range(11):
			var z0 := -1.144 + float(col) * .208
			_coin_tile(here, x0, x0 + .106, z0, z0 + .208, .0355, .0355, Color(.85, .72, .55))
	for i: int in range(120):
		_medal(here, Vector3(_rng.randf_range(-.1, .1), .0375 + _rng.randf() * .006, _rng.randf_range(-1.12, 1.12)), Vector3(_rng.randf_range(-.14, .14), 1.0, _rng.randf_range(-.14, .14)).normalized())
	# A column is rolls of medals stood on each other, a little out of true, never one smooth peg.
	var roll: Array[Vector2] = [Vector2(.0175, 0), Vector2(.02, .003), Vector2(.02, .017), Vector2(.0175, .02), Vector2(0, .02)]
	for z: float in [-.36, .36]:
		for k: int in range(8):
			var tone := _rng.randf_range(.7, 1.0)
			var copper := Color(.5, .3, .13) if k % 3 != 1 else Color(.5, .5, .46)
			_kit.lathe("coin", here * Vector3(-.05 + _rng.randf_range(-.002, .002), .035 + float(k) * .02, z + _rng.randf_range(-.002, .002)), roll, Color(copper.r * tone, copper.g * tone, copper.b * tone), 10)
	var home := side * Vector3(.2, .88, 0)
	var node := _seal(self, home)
	_kit = shared
	_shelves.append({"node": node, "home": home, "out": side.basis.x})

func _pusher_station(seat: Transform3D, x: float) -> void:
	# One player's place: a sloped panel with a screen and a button, and the tray the winnings hit.
	_bar("plain", seat, x, .6, .006, Vector3(.54, .28, .012), Color("#17151e"))
	_panel("floor_screen", seat, x - .17, x + .17, .53, .72, .014, _cell(1340, 1730, 320, 180))
	_kit.disc("led_in", seat * Vector3(x + .2, .5, .014), seat.basis.x, seat.basis.y, .03, Color(1.0, .09, .02))
	_kit.disc("steel_in", seat * Vector3(x - .22, .5, .014), seat.basis.x, seat.basis.y, .018, Color("#5e6268"))
	# Payout and its lip stay within the machine's own line: the aisle has no centimetres to give them.
	_bar("plain", seat, x, .28, .008, Vector3(.42, .12, .016), Color("#050507"))
	_bar("steel_in", seat, x, .22, .012, Vector3(.46, .016, .026), Color("#585c62"))
	for i: int in range(12):
		_kit.disc("coin", seat * Vector3(x + _rng.randf_range(-.19, .19), .232 + _rng.randf() * .004, .012), seat.basis.x, -seat.basis.z, .0125, Color("#b98a52"))
	_floor_glow(seat, x, 0, Color(1.0, .75, .3) * .18)

func _slot(t: Transform3D, face: Rect2, glow: Color) -> void:
	# A pachislot on its island: origin at the middle of the glass, floor level, +z to the stool.
	var steel := Color("#3a3c42")
	_bar("shell_in", t, 0, .93, -.26, Vector3(.6, 1.86, .52), Color("#14141a"))
	# Two lit panels in dark frames, the title and reels over the belly, the shell showing between them.
	_panel("floor_lit", t, -.27, .27, 1.18, 1.78, .004, Rect2(face.position, face.size * Vector2(1.0, .645)))
	_panel("floor_lit", t, -.27, .27, .84, 1.15, .004, Rect2(face.position + face.size * Vector2(.04, .665), face.size * Vector2(.92, .31)))
	for row: Vector2 in [Vector2(1.18, 1.78), Vector2(.84, 1.15)]:
		for y: float in [row.x, row.y]:
			_bar("steel_in", t, 0, y, .006, Vector3(.56, .012, .012), steel)
		for x: float in [-.274, .274]:
			_bar("steel_in", t, x, (row.x + row.y) * .5, .006, Vector3(.012, row.y - row.x, .012), steel)
	_bar("steel_in", t, 0, 1.82, 0, Vector3(.58, .05, .02), Color("#5a5e64"))
	_bar("led_in", t, 0, 1.91, -.1, Vector3(.58, .1, .16), _deep(glow) * .7)
	_bar("led_in", t, 0, 1.91, -.018, Vector3(.58, .02, .004), Color.WHITE)
	for x: float in [-.292, .292]:
		_bar("led_in", t, x, 1.3, .001, Vector3(.012, 1.0, .006), _deep(glow) * .7)
	_bar("steel_in", t, 0, .79, .04, Vector3(.56, .05, .12), Color("#2e3036"))
	for x: float in [-.1, 0.0, .1]:
		_kit.disc("led_in", t * Vector3(x, .816, .06), t.basis.x, -t.basis.z, .024, Color(1.0, .06, .03))
	_kit.tube("steel_in", [t * Vector3(-.2, .8, .05), t * Vector3(-.2, .9, .072)], .007, Color("#6a6e74"), 6)
	_ball(t * Vector3(-.2, .91, .075), Vector3.ONE * .022, Color("#d81818"), "gloss", 6, 10)
	_deck_pad(t, .205, .846, .05)
	_bar("plain", t, 0, .5, .003, Vector3(.5, .46, .006), Color("#22242c"))
	for i: int in range(9):
		_bar("plain", t, 0, .42 + float(i) * .018, .007, Vector3(.28, .007, .002), Color("#08080a"))
	_bar("steel_in", t, 0, .22, .05, Vector3(.42, .02, .1), Color("#585c62"))
	_bar("plain", t, 0, .25, .012, Vector3(.38, .05, .02), Color("#050507"))
	_kit.lathe("shell_in", t * Vector3(.14, .232, .06), [Vector2(.03, 0), Vector2(.04, .07), Vector2(.036, .07), Vector2(.03, .012), Vector2(0, .012)], Color("#7a1414"), 16) # The red plastic cup every medal floor hands out.
	_swivel(t * Vector3(0, 0, .42), t.basis.z, Color("#17171b"))
	_floor_glow(t, 0, 0, Color(1.0, .25, .15) * .2)

func _pachi(t: Transform3D, game: int) -> void:
	# Medal pachinko, flush in its bank: a steel frame, a data unit on a steel band, a round board
	# with a small screen and scattered beads, a ring of lamps, and the tray on the bank's shelf.
	var steel := Color("#585c62")
	var surround: Color = [Color("#a81c20"), Color("#d8dce0"), Color("#2450a8")][game % 3]
	_bar("shell_in", t, 0, .93, -.25, Vector3(.72, 1.86, .5), Color("#2a2c32"))
	for x: float in [-.35, .35]:
		_bar("steel_in", t, x, .93, .005, Vector3(.02, 1.84, .01), steel)
	_bar("steel_in", t, 0, 1.85, .005, Vector3(.72, .02, .01), steel)
	_bar("steel_in", t, 0, 1.76, .003, Vector3(.68, .16, .006), steel)
	_bar("plain", t, 0, 1.76, .01, Vector3(.4, .1, .02), Color("#0a0a0e"))
	var data: Array[Color] = [Color(.2, 1.0, .5), Color(1.0, .3, .2), Color(1.0, .7, .15)]
	for k: int in range(3):
		_bar("led_in", t, -.15 + float(k) * .06, 1.76, .0205, Vector3(.05, .022, .002), _deep(data[k]))
	_palm_mark(t, .12, 1.76, .0205, .036)
	_bar("shell_in", t, 0, 1.22, .002, Vector3(.66, .7, .004), surround)
	var centre := t * Vector3(0, 1.22, .006)
	_kit.disc("plain", centre, t.basis.x, t.basis.y, .3, Color("#101018"))
	_panel("floor_screen", t, -.16, .16, 1.1, 1.34, .012, _cell(float(game) * 410.0, 0, 400, 300))
	var beads: Array[Color] = [Color(.2, .6, 1.0), Color(1.0, .25, .2), Color(1.0, .8, .2), Color(.3, 1.0, .5)]
	# The playfield: lit segments round the screen, so the board is busy and never a black hole.
	for i: int in range(24):
		var a0 := TAU * float(i) / 24.0
		var a1 := TAU * float(i + 1) / 24.0
		_kit.quad("led_in", t * Vector3(cos(a1) * .2, 1.22 + sin(a1) * .2, .0072), t * Vector3(cos(a1) * .29, 1.22 + sin(a1) * .29, .0072), t * Vector3(cos(a0) * .29, 1.22 + sin(a0) * .29, .0072), t * Vector3(cos(a0) * .2, 1.22 + sin(a0) * .2, .0072), _deep(beads[(i + game) % 4]) * .22)
	for i: int in range(34):
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(.21, .285)
		_kit.disc("led_in", t * Vector3(cos(a) * r, 1.22 + sin(a) * r, .008), t.basis.x, t.basis.y, _rng.randf_range(.005, .009), _deep(beads[i % 4]))
	var ring: Array[Vector3] = []
	for i: int in range(37):
		var a := TAU * float(i) / 36.0
		ring.append(t * Vector3(cos(a) * .302, 1.22 + sin(a) * .302, .012))
	for i: int in range(24):
		var a := TAU * float(i) / 24.0
		_kit.disc("led_in", t * Vector3(cos(a) * .322, 1.22 + sin(a) * .322, .006), t.basis.x, t.basis.y, .008, _deep(Color(.2, .6, 1.0)))
	_kit.tube("steel_in", ring, .012, Color("#6a6e74"), 6)
	_kit.disc("front", t * Vector3(0, 1.22, .016), t.basis.x, t.basis.y, .29, Color.WHITE) # The glass, seated inside the ring.
	_bar("steel_in", t, 0, .8, .05, Vector3(.54, .08, .1), Color("#585c62"))
	_bar("plain", t, 0, .82, .085, Vector3(.34, .03, .03), Color("#101014"))
	_ball(t * Vector3(.24, .8, .077), Vector3.ONE * .022, Color("#d81818"), "gloss", 6, 10)
	_deck_pad(t, -.23, .866, .05)
	_panel("floor_print", t, -.2, .2, .29, .515, .002, _cell(1340, 1730, 320, 180))
	for i: int in range(10):
		_ball(t * Vector3(_rng.randf_range(-.15, .15), .845, .078 + _rng.randf_range(-.008, .008)), Vector3.ONE * .011, Color("#8a8e94"), "steel_in", 4, 8)
	_floor_glow(t, 0, .1, Color(.3, .6, 1.0) * .2)

func _kiosk(t: Transform3D, skin := "shell", light := "led") -> void:
	# The change machine: origin at the middle of its face, the only honest deal in the building.
	_bar(skin, t, 0, .85, -.18, Vector3(.5, 1.7, .36), Color("#b81418"))
	_panel("floor_lit", t, -.23, .23, .893, 1.66, .002, _cell(1020, 810, 300, 500))
	_bar("metal", t, 0, .4, .01, Vector3(.42, .26, .02), Color("#7a7c82"))
	_bar("plain", t, 0, .34, .024, Vector3(.3, .08, .012), Color("#050507"))
	_kit.disc(light, t * Vector3(.14, .47, .022), t.basis.x, t.basis.y, .02, Color(.2, .9, .4))

# ---------------------------------------------------------------- 2F: the print club

func _print_club(y: float) -> void:
	# Three photo booths you can step into, the scribbling station, and the make-up counter.
	var f := _front
	_room(y, 0)
	var a := _cell(0, 930, 500, 620)
	var b := _cell(510, 930, 500, 620)
	var pink := _cell(1340, 1260, 340, 460)
	var blue := _cell(1690, 1260, 340, 460)
	var rows: Array = [[1.85, -1.2, PI * .5, a, pink, Color("#ff5aa8")], [1.85, -3.15, PI * .5, b, blue, Color("#40b0f0")], [3.35, -1.2, -PI * .5, b, blue, Color("#40b0f0")]]
	for row: Array in rows:
		_print_booth(Transform3D(Basis(Vector3.UP, row[2]), f * Vector3(row[0], y, row[1])), row[3], row[4], row[5])
	_touchup(Transform3D(Basis(Vector3.UP, -PI * .5), f * Vector3(4.48, y, -4.7)))
	_solid(4.3, 4.98, y, y + 1.95, -5.2, -4.2) # Out to the pelmet and the pens.
	_powder(y)
	# The round card past booth 3's corner, taped up where you meet it walking back from the mirrors.
	var pop := f * Vector3(3.35, y + 1.75, -2.158)
	_kit.disc("room", pop, f.basis.x, f.basis.y, .157, Color("#f6f4f6"))
	_kit.disc("room", pop, -f.basis.x, f.basis.y, .157, Color("#f6f4f6"))
	_kit.disc("floor_lit", pop + Vector3.FORWARD * .002, -f.basis.x, f.basis.y, .15, Color.WHITE, _cell(1680, 1740, 200, 200))
	_solid(3.2, 3.35, y + 1.6, y + 1.9, -2.17, -2.15)
	# The shop's own wall: the free runs only, clear of the mirrors and the way out.
	var east := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(4.98, y, -ROOM))
	var back := Transform3D(Basis.IDENTITY, f * Vector3(.2, y, -ROOM))
	_framed(east, 1.6, 2.4, .95, 1.942, "floor_print", a)
	_framed(east, 2.7, 3.25, 1.1, 1.844, "floor_print", pink)
	_framed(back, 3.7, 4.22, 1.17, 1.874, "floor_print", blue)

func _print_booth(t: Transform3D, banner: Rect2, sheet: Rect2, tint: Color) -> void:
	# Origin at the middle of the front, +z out. You duck under the printed curtain on the right; the
	# left of the front is the machine: its own steel, with the sample sheet framed above. Inside: a
	# coloured floor and end wall, the backdrop, a camera on rails, and four great globes of white light.
	var w := .95
	var d := 1.6
	var high := 2.06
	var wall := .05
	var skin := Color("#f7f5f8")
	var seam := Color("#c9c7cc")
	var kick := Color("#202024")
	var frame := Color("#dcdade")
	_bar("shell", t, 0, high + .03, -d * .5, Vector3(w * 2.0, .06, d), skin)
	_bar("shell", t, 0, high * .5, -d + wall * .5, Vector3(w * 2.0, high, wall), skin)
	for side: float in [-1.0, 1.0]:
		_bar("shell", t, side * (w - wall * .5), high * .5, -d * .5, Vector3(wall, high, d), skin)
	_bar("shell", t, -.5, high * .5, -wall * .5, Vector3(.9, high, wall), skin)
	_bar("shell", t, .43, high - .03, -wall * .5, Vector3(.96, .06, wall), skin)
	_box_solid(t, Vector3(0, high * .5, -d + wall * .5), Vector3(w * 2.0, high, wall))
	_box_solid(t, Vector3(-w + wall * .5, high * .5, -d * .5), Vector3(wall, high, d))
	_box_solid(t, Vector3(w - wall * .5, high * .5, -d * .5), Vector3(wall, high, d))
	_box_solid(t, Vector3(-.5, high * .5, -wall * .5), Vector3(.9, high, wall))
	# The door posts: the curtain rail runs between them, and no slit of the shop shows past its edge.
	for x: float in [-.04, .915]:
		_bar("shell", t, x, 1.0, .03, Vector3(.02 if x < 0.0 else .03, 2.0, .06), skin)
		_box_solid(t, Vector3(x, 1.0, .03), Vector3(.02 if x < 0.0 else .03, 2.0, .06))
	# Inside. The floor and the two walls you see under the curtain take the booth's colour; the rest is cream.
	var cream := Color("#ece8dc")
	var hue := tint.lerp(Color.WHITE, .6)
	var joint := Color("#b8b4a8")
	var far := -d + wall + .002
	_kit.quad("prize", t * Vector3(-w, .012, -.05), t * Vector3(-w, .012, -d), t * Vector3(w, .012, -d), t * Vector3(w, .012, -.05), tint.lerp(Color.WHITE, .25))
	_kit.quad("prize", t * Vector3(-.9, .012, far), t * Vector3(-.9, high, far), t * Vector3(.9, high, far), t * Vector3(.9, .012, far), hue)
	_kit.quad("prize", t * Vector3(-.05, .012, -wall - .002), t * Vector3(-.05, high, -wall - .002), t * Vector3(-.9, high, -wall - .002), t * Vector3(-.9, .012, -wall - .002), cream)
	_kit.quad("prize", t * Vector3(-.898, .012, -wall), t * Vector3(-.898, high, -wall), t * Vector3(-.898, high, -d + wall), t * Vector3(-.898, .012, -d + wall), cream)
	for x: float in [-.42, .4]:
		_bar("plain", t, x, 1.03, far + .001, Vector3(.006, 2.03, .002), joint)
	_bar("plain", t, 0, .62, far + .001, Vector3(1.8, .006, .002), joint)
	_panel("photo_print", t, -.2, .08, 1.42, 1.56, far + .002, Rect2(350.0 / 1024.0, 450.0 / 1024.0, 160.0 / 1024.0, 80.0 / 1024.0))
	_panel("floor_print", t, -.2, .08, 1.26, 1.387, far + .002, _cell(1890, 1930, 150, 68))
	var backdrop := Transform3D(t.basis * Basis(Vector3.UP, -PI * .5), t * Vector3(w - wall - .002, 0, -d * .5))
	_kit.quad("prize", backdrop * Vector3(-.74, .02, 0), backdrop * Vector3(-.74, high - .02, 0), backdrop * Vector3(.74, high - .02, 0), backdrop * Vector3(.74, .02, 0), hue)
	_bar("panel", t, 0, high - .012, -d * .5, Vector3(1.5, .012, 1.2), Color(.98, .97, 1.0))
	var unit := Transform3D(t.basis * Basis(Vector3.UP, PI * .5), t * Vector3(-.5, 0, -.84))
	_bar("shell", unit, 0, 1.0, -.2, Vector3(1.3, 2.0, .4), Color("#eeecf2"))
	_box_solid(t, Vector3(-.59, 1.0, -.84), Vector3(.62, 2.0, 1.3)) # Out past the globes, so no one stands inside one.
	_kit.quad("prize", unit * Vector3(-.65, .012, .002), unit * Vector3(-.65, 2.0, .002), unit * Vector3(.65, 2.0, .002), unit * Vector3(.65, .012, .002), cream)
	for x: float in [-.33, .33]:
		_bar("plain", unit, x, 1.0, .003, Vector3(.006, 2.0, .002), joint)
	_bar("plain", unit, 0, .62, .003, Vector3(1.3, .006, .002), joint)
	# The camera: a black housing on two rails, the lens over the little screen that shows you yourself.
	_bar("plain", unit, 0, 1.42, .03, Vector3(.24, .46, .06), Color("#0c0c10"))
	for x: float in [-.06, .06]:
		_bar("plain", unit, x, 1.07, .012, Vector3(.02, .24, .016), Color("#16161a"))
	_kit.disc("plain", unit * Vector3(0, 1.56, .062), unit.basis.x, unit.basis.y, .085, Color("#22222a"))
	_kit.disc("gloss", unit * Vector3(0, 1.56, .064), unit.basis.x, unit.basis.y, .055, Color("#1a2a4a"))
	_panel("print_screen", unit, -.1, .1, 1.26, 1.407, .062, _cell(700, 1560, 300, 220))
	for corner: Vector2 in [Vector2(-.32, 1.04), Vector2(.32, 1.04), Vector2(-.32, 1.72), Vector2(.32, 1.72)]:
		_ball(unit * Vector3(corner.x, corner.y, .3), Vector3.ONE * .28, Color(1.0, .99, .97), "orb", 20, 40)
	# The face it shows the floor: the sample sheet in its frame, three prints across and three down,
	# with the shop's arrow card taped over it. Below the break line, the machine's own steel.
	var head := sheet.size.y * 60.0 / 460.0
	var samples := Rect2(sheet.position + Vector2(0, head), sheet.size - Vector2(0, head))
	_bar("room", t, -.49, 1.425, .002, Vector3(.85, 1.14, .002), frame)
	_panel("floor_lit", t, -.9, -.08, 1.835, 1.98, .004, Rect2(sheet.position, Vector2(sheet.size.x, head)))
	for row: int in range(3):
		for col: int in range(3):
			var x := -.9 + float(col) * .82 / 3.0
			var low := .87 + float(row) * .965 / 3.0
			_panel("floor_lit", t, x, x + .82 / 3.0, low, low + .965 / 3.0, .004, samples)
	var note := Transform3D(t.basis * Basis(Vector3.BACK, -.04), t * Vector3(-.62, 1.18, .007))
	_panel("floor_print", note, -.17, .17, -.077, .077, 0, _cell(1680, 1950, 200, 90))
	_bar("plain", t, -.5, .6, .003, Vector3(.9, .008, .006), seam)
	_bar("plain", t, -.5, .025, .002, Vector3(.9, .05, .004), kick)
	for x: float in [-.78, -.22]:
		_bar("plain", t, x, .52, .003, Vector3(.14, .035, .006), Color("#3a3a40"))
	_bar("plain", t, -.5, .29, .002, Vector3(.508, .348, .004), seam)
	_bar("shell", t, -.5, .29, .004, Vector3(.5, .34, .008), Color("#efedf1"))
	_kit.disc("plain", t * Vector3(-.5, .42, .0085), t.basis.x, t.basis.y, .012, Color("#6e7278"))
	_bar("plain", t, -.5, .345, .0085, Vector3(.17, .05, .001), Color("#1a3a9c"))
	_bar("plain", t, -.5, .2, .009, Vector3(.24, .08, .002), Color("#16161a"))
	_bar("plain", t, -.5, .157, .014, Vector3(.26, .01, .022), Color("#8a8e94"))
	_palm_pad(t, -.76, .745, .003)
	_curtain(t, -.03, .9, .78, 1.98, banner, .03, .14)
	_panel("floor_print", t, .42, .88, 1.57, 1.83, .07, _cell(0, 1560, 320, 180))
	var card := Transform3D(t.basis * Basis(Vector3.BACK, .05), t * Vector3(.3, 1.31, .068))
	_panel("floor_print", card, -.092, .092, -.11, .11, 0, _cell(1890, 1740, 150, 180))
	_bar("room", card, 0, .112, .001, Vector3(.07, .02, .001), Color("#f4ecc8"))
	_bar("room", t, .43, .012, 0, Vector3(.94, .024, .1), Color("#f2f0f2"))
	_bar("plain", t, .42, 2.21, -.1, Vector3(.76, .22, .1), Color("#e01880"))
	_panel("floor_lit", t, .06, .78, 2.12, 2.3, -.048, _cell(330, 1560, 360, 90))
	_bar("led", t, 0, high + .065, .004, Vector3(w * 2.0, .02, .012), tint)
	# Printed down both sides, which is what the rest of the room sees: a poster over seamed steel, on casters.
	var wheel: Array[Vector2] = [Vector2(.02, 0), Vector2(.03, .012), Vector2(.03, .038), Vector2(.018, .05)]
	for side: float in [-1.0, 1.0]:
		var flank := Transform3D(t.basis * Basis(Vector3.UP, side * PI * .5), t * Vector3(side * w, 0, -d * .5))
		_bar("room", flank, 0, 1.3, .002, Vector3(1.14, 1.4, .002), frame)
		_panel("floor_print", flank, -.55, .55, .62, 1.98, .004, banner)
		_bar("led", flank, 0, high + .065, 0, Vector3(d, .02, .012), tint)
		_bar("plain", flank, 0, .6, .003, Vector3(d, .008, .006), seam)
		_bar("plain", flank, 0, .025, .002, Vector3(d, .05, .004), kick)
		for u: float in [-.5, 0.0, .5]:
			_bar("plain", flank, u, .325, .002, Vector3(.006, .55, .002), seam)
		for z: float in [.012, -d + .04]:
			_kit.lathe("plain", t * Vector3(side * (w - .012), 0, z), wheel, Color("#2a2a30"), 10)

func _curtain(t: Transform3D, x0: float, x1: float, y0: float, y1: float, rect: Rect2, z: float, lift := 0.0) -> void:
	# A printed cloth on a rail, deep in its pleats, its plain back to the booth. With lift, the hem
	# curves up at both corners, the way a real one is cut.
	var strips := 24
	var bottom := Color("#fff2f8")
	var deep := .03
	var flat: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for i: int in range(strips):
		var a := float(i) / float(strips)
		var b := float(i + 1) / float(strips)
		var za := z + sin(a * TAU * 3.0) * deep
		var zb := z + sin(b * TAU * 3.0) * deep
		var hem_a := y0 + lift * pow(absf(2.0 * a - 1.0), 4.0)
		var hem_b := y0 + lift * pow(absf(2.0 * b - 1.0), 4.0)
		var xa := lerpf(x0, x1, a)
		var xb := lerpf(x0, x1, b)
		var ua := lerpf(rect.position.x, rect.end.x, a)
		var ub := lerpf(rect.position.x, rect.end.x, b)
		var va := lerpf(rect.end.y, rect.position.y, (hem_a - y0) / (y1 - y0))
		var vb := lerpf(rect.end.y, rect.position.y, (hem_b - y0) / (y1 - y0))
		var na := (t.basis * Vector3(-cos(a * TAU * 3.0) * .6, 0, 1)).normalized()
		var nb := (t.basis * Vector3(-cos(b * TAU * 3.0) * .6, 0, 1)).normalized()
		var fold := 1.0 - .13 * (.5 + .5 * sin((a + b) * TAU * 1.5 + PI * .5))
		var points: Array[Vector3] = [t * Vector3(xa, hem_a, za), t * Vector3(xa, y1, za), t * Vector3(xb, y1, zb), t * Vector3(xb, hem_b, zb)]
		var normals: Array[Vector3] = [na, na, nb, nb]
		var prints: Array[Vector2] = [Vector2(ua, va), Vector2(ua, rect.position.y), Vector2(ub, rect.position.y), Vector2(ub, vb)]
		_kit.mapped("floor_print", points, normals, prints, flat, Color(fold, fold, fold))
		_kit.quad("paint", t * Vector3(xb, hem_b, zb - .002), t * Vector3(xb, y1, zb - .002), t * Vector3(xa, y1, za - .002), t * Vector3(xa, hem_a, za - .002), Color(bottom.r * fold, bottom.g * fold, bottom.b * fold))
	_kit.tube("chrome", [t * Vector3(x0, y1 + .01, z), t * Vector3(x1, y1 + .01, z)], .009, Color("#c8ccd0"), 6)

func _touchup(t: Transform3D) -> void:
	# Where the photos come out and you scribble on them: one big screen tipped back in its recess
	# between black decals, two pink pens on long goosenecks, one slot.
	var skin := Color("#f4f0f6")
	var ink := Color("#101014")
	_bar("shell", t, 0, .475, -.25, Vector3(1.0, .95, .5), skin)
	_bar("shell", t, 0, 1.62, -.25, Vector3(1.0, .6, .5), skin)
	_bar("shell", t, 0, 1.135, -.375, Vector3(1.0, .37, .25), skin)
	_bar("plain", t, 0, 1.92, .08, Vector3(1.0, .05, .24), Color("#e01880"))
	_curtain(t, -.5, .5, 1.5, 1.9, _cell(0, 1040, 500, 200), .1)
	_bar("plain", t, 0, 1.41, .004, Vector3(1.0, .18, .008), ink)
	_panel("photo_print", t, -.245, .245, 1.32, 1.5, .009, Rect2(710.0 / 1024.0, 270.0 / 1024.0, 300.0 / 1024.0, 110.0 / 1024.0))
	var tilt := _slope(t, Vector2(.02, .96), Vector2(-.24, 1.31))
	var long := Vector2(.26, .35).length()
	_bar("shell", tilt, 0, long * .5, -.008, Vector3(.96, long + .05, .012), skin)
	_bar("plain", tilt, 0, long * .5, 0, Vector3(.66, long + .05, .004), ink)
	_panel("print_screen", tilt, -.3, .3, 0, long, .004, _cell(700, 1560, 300, 220))
	for side: float in [-1.0, 1.0]:
		_bar("shell", t, side * .49, 1.135, -.115, Vector3(.02, .37, .27), skin)
		_bar("plain", tilt, side * .405, long * .5, 0, Vector3(.13, long - .04, .004), ink)
		_bar("gold", tilt, side * .405, long * .5, .0025, Vector3(.09, .004, .001), Color("#c8a040"))
		var neck: Array[Vector3] = []
		for i: int in range(7):
			var u := float(i) / 6.0
			var sag := sin(u * PI)
			neck.append(t * Vector3(side * (lerpf(.36, .3, u) + sag * .03), lerpf(.94, 1.0, u) - sag * .36, lerpf(.005, .12, u) + sag * .05))
		_kit.tube("plain", neck, .007, Color("#b4b8bc"), 5)
		var grip := t * Vector3(side * .3, 1.0, .12)
		_kit.tube("gloss", [grip, grip + t.basis * Vector3(-side * .07, .14, -.07)], .011, Color("#ff7ab0"), 6)
	_bar("plain", t, 0, .62, .004, Vector3(.4, .05, .01), Color("#3a3c44"))
	_palm_pad(t, -.24, .79, .002)
	_panel("floor_print", t, -.42, .42, .44, .55, .002, _cell(0, 1900, 1000, 130))
	_bar("plain", t, 0, .24, .002, Vector3(.608, .308, .004), Color("#c9c7cc"))
	_bar("shell", t, 0, .24, .003, Vector3(.6, .3, .006), Color("#e8e6ec"))
	_kit.disc("plain", t * Vector3(.24, .24, .0065), t.basis.x, t.basis.y, .012, Color("#6e7278"))
	_bar("plain", t, 0, .025, .002, Vector3(1.0, .05, .004), Color("#202024"))

func _palm_pad(t: Transform3D, x: float, y: float, z: float) -> void:
	# The 2050 way to pay: a dark glass plate you hold your palm over, ringed in cyan, its tag alongside.
	_bar("gloss", t, x, y, z + .004, Vector3(.15, .15, .008), Color("#0a0c12"))
	_kit.disc("led", t * Vector3(x, y, z + .0085), t.basis.x, t.basis.y, .056, CYAN)
	_kit.disc("gloss", t * Vector3(x, y, z + .009), t.basis.x, t.basis.y, .046, Color("#0c1018"))
	_panel("floor_lit", t, x + .09, x + .36, y - .042, y + .042, z + .001, _cell(1060, 1177, 220, 68))

func _powder(y: float) -> void:
	# The back counter: mirrors with bulbs, curling tongs on hooks, stools, and a bin of tissues.
	var f := _front
	_bar("room", f, 2.75, y + .42, -5.38, Vector3(2.2, .84, .42), Color("#c79aa4"))
	_bar("gloss", f, 2.75, y + .85, -5.38, Vector3(2.24, .03, .46), Color("#ece6e0"))
	_solid(1.65, 3.85, y, y + .86, -5.6, -5.16)
	for x: float in [2.05, 2.75, 3.45]:
		_bar("mirror", f, x, y + 1.46, -5.585, Vector3(.6, .94, .02), Color(.93, .94, .95))
		var at := x - .3
		while at <= x + .3:
			for row: float in [1.0, 1.95]:
				_ball(f * Vector3(at, y + row, -5.56), Vector3.ONE * .03, Color(1.0, .94, .84), "vanity", 8, 16)
			at += .15
		_stool(f * Vector3(x, y, -4.86), Color("#a8707e"), "plain") # Painted legs: bright steel only mirrors this floor's tiles.
		_kit.tube("plain", [f * Vector3(x + .22, y + .84, -5.56), f * Vector3(x + .3, y + .6, -5.5), f * Vector3(x + .26, y + .4, -5.5)], .005, Color("#101014"), 3)
		_kit.lathe("gloss", f * Vector3(x + .26, y + .86, -5.3), [Vector2(.016, 0), Vector2(.014, .18)], Color("#e8609a"), 8)
	_bar("room", f, 2.05, y + .9, -5.3, Vector3(.24, .08, .14), Color("#ffffff"))
	_bar("room", f, 3.1, y + .92, -5.42, Vector3(.1, .1, .1), Color("#a8e0f8"))

func _floors() -> void:
	var f := _front
	var bronze := Color("#26262a")
	for i: int in range(4):
		var base := _storey_base(i)
		var low := base + BAND
		var high := base + STOREY
		var opening := Rect2(GLASS_X0, low, GLASS_X1 - GLASS_X0, STOREY - BAND)
		_reveal(f, opening, .08, Color("#20222a"))
		_kit.quad("front", f * Vector3(GLASS_X0, low, -.07), f * Vector3(GLASS_X0, high, -.07), f * Vector3(GLASS_X1, high, -.07), f * Vector3(GLASS_X1, low, -.07), Color.WHITE)
		for x: float in [GLASS_X0 + .03, 1.45, 2.6, 3.75, GLASS_X1 - .03]:
			_bar("metal", f, x, (low + high) * .5, -.05, Vector3(.06, high - low, .09), bronze)
		_bar("metal", f, 2.6, low + .03, -.05, Vector3(GLASS_X1 - GLASS_X0, .06, .09), bronze)
		_bar("metal", f, 2.6, high - .03, -.05, Vector3(GLASS_X1 - GLASS_X0, .06, .09), bronze)
		# The red triangle marks the pane a ladder crew breaks in through.
		_panel("cut", f, 1.86, 2.14, low + .9, low + 1.18, -.066, _cell(1720, 1110, 100, 100))
		_bar("plain", f, 2.6, base + .25, .03, Vector3(4.6, .38, .06), Color("#0a1030"))
		_panel("sign", f, .36, 4.84, base + .09, base + .41, .062, _cell(0, 1620.0 + float(i) * 105.0, 1400, 100))
	_print_club(_storey_base(0) + .34)
	_arcade_floor(_storey_base(1) + .34)
	_medal_floor(_storey_base(2) + .34)
	_vr_floor(_storey_base(3) + .34)

func _zone_boards(top: float, cards: Array[Rect2]) -> void:
	# Slung just behind the glass on chains, printed both ways: the street reads them from the
	# pavement, and the room finds its way by the same boards.
	var f := _front
	for i: int in range(3):
		var x := 1.1 + float(i) * 1.5
		_bar("plain", f, x, top - .3, -.52, Vector3(1.26, .4, .05), Color("#0c0c10"))
		_panel("sign", f, x - .6, x + .6, top - .48, top - .12, -.492, cards[i])
		_panel("sign_in", Transform3D(Basis(Vector3.UP, PI), f * Vector3(x, 0, -.548)), -.6, .6, top - .48, top - .12, 0, cards[i])
		for side: float in [-.5, .5]:
			_kit.tube("metal", [f * Vector3(x + side, top, -.52), f * Vector3(x + side, top - .1, -.52)], .006, Color("#6a6c70"), 3)

func _vr_floor(y: float) -> void:
	# The new money: three timber-clad rooms built into the floor, cloth in their doors, a printed
	# mascot and title to sell them, and inside, a tracked floor and a headset on a cable overhead.
	var f := _front
	_room(y, 3)
	var top := y + ROOM_HIGH
	var warm := Color(1.0, .9, .78)
	for x: float in [1.75, 3.4]:
		_wall_boards(Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(x + .05, y, -.4)), 3.78, [])
		_wall_boards(Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(x - .05, y, -4.18)), 3.78, [])
		_bar("plain", f, x, (y + top) * .5, -.4, Vector3(.1, top - y, .1), Color("#141416"))
		_solid(x - .05, x + .05, y, top, -4.18, -.35)
	# The wall they share along the walkway, a metre of door in each: x runs backwards on its aisle face.
	var aisle := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), f * Vector3(4.98, y, -4.3))
	var doors: Array[Vector2] = [Vector2(.47, 1.47), Vector2(2.08, 3.08), Vector2(3.7, 4.7)]
	var out: Array[Rect2] = []
	var inward: Array[Rect2] = []
	for door: Vector2 in doors:
		out.append(Rect2(4.98 - door.y, 0, 1.0, 2.1))
		inward.append(Rect2(door.x - .2, 0, 1.0, 2.1))
		_solid(door.x, door.y, y + 2.1, top, -4.3, -4.18)
		_vr_curtain(door.x, door.y, y)
	_wall_boards(aisle, 4.78, out)
	_wall_boards(Transform3D(Basis.IDENTITY, f * Vector3(.2, y, -4.18)), 4.78, inward)
	for piece: Vector2 in [Vector2(.2, .47), Vector2(1.47, 2.08), Vector2(3.08, 3.7), Vector2(4.7, 4.98)]:
		_solid(piece.x, piece.y, y, top, -4.3, -4.18)
	for hole: Rect2 in out:
		_reveal(aisle, Rect2(hole.position.x, .002, 1.0, 2.098), .12, Color("#08080a"))
		var mid := hole.get_center().x
		_bar("steel_in", aisle, mid, 2.19, .01, Vector3(1.0, .18, .02), Color("#9a9c9e"))
		_bar("led_low", aisle, mid, 2.125, .021, Vector3(.92, .008, .004), CYAN)
		for bolt: float in [-.43, -.14, .14, .43]:
			_kit.disc("metal", aisle * Vector3(mid + bolt, 2.205, .0205), aisle.basis.x, aisle.basis.y, .017, Color("#26282c"))
	# The way in is roped by nothing: two posts, standing either side of the middle door.
	for x: float in [1.94, 3.22]:
		_kit.lathe("steel_in", f * Vector3(x, y, -4.44), [Vector2(.13, 0), Vector2(.13, .012), Vector2(.115, .02), Vector2(.03, .034), Vector2(.02, .06), Vector2(.02, .9), Vector2(.032, .91), Vector2(.032, .98), Vector2(.022, .995), Vector2(.0, 1.0)], Color("#a4a8ae"), 28)
		_solid(x - .1, x + .1, y, y + 1.0, -4.54, -4.34)
	# The red band over the walkway, a flat paint job on the black.
	_bar("paint", f, 2.59, top - .013, -4.65, Vector3(4.78, .026, .7), Color(.1, .022, .024))
	# Warm spots down the walkway, each with its pool, and the fall of light they leave on the boards.
	var low := y + .004
	for x: float in [1.78, 2.585, 3.39]:
		_kit.disc("plain", f * Vector3(x, top - .025, -5.1), Vector3.RIGHT, Vector3.BACK, .07, Color("#0c0c0e"))
		_kit.disc("panel", f * Vector3(x, top - .026, -5.1), Vector3.RIGHT, Vector3.BACK, .05, Color(1.0, .86, .68))
		_kit.atlas("pool", f * Vector3(x - .8, low, -4.3), f * Vector3(x - .8, low, -5.6), f * Vector3(x + .8, low, -5.6), f * Vector3(x + .8, low, -4.3), Rect2(0, .1875, 1, .8125), warm * .14)
		_panel("wash_vr", Transform3D(Basis.IDENTITY, f * Vector3(x, y, -ROOM)), -.55, .55, .1, 2.3, .01, Rect2(0, 1, 1, -1), warm * .2) # What the same lamp leaves on the back wall.
	var flip := Rect2(0, 1, 1, -1) # The wash's lamp at its top edge.
	var back := Transform3D(Basis.IDENTITY, f * Vector3(.2, y, -ROOM))
	for u: float in [1.59, 3.205]:
		_panel("poster", aisle, u - .23, u + .23, 1.12, 1.72, .008, _cell(1830, 552, 200, 260))
		_panel("wash_vr", aisle, u - .3, u + .3, .1, 2.3, .01, flip, warm * .2)
	# The show on the boards: its title on the back wall, and the house tanuki where the door looks.
	_panel("cut_vr", back, 1.4, 3.8, 1.2, 1.9, .008, VR_TITLE)
	_panel("cut_vr", Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(4.98, y, -5.6)), .15, 1.15, .1, 2.0, .008, VR_TANUKI)
	var cards: Array[Rect2] = [_cell(1410, 1830, 310, 100), _cell(1410, 1935, 310, 100), _cell(1410, 1830, 310, 100)]
	var centres: Array[float] = [.97, 2.58, 4.2]
	var walls: Array[Vector2] = [Vector2(.2, 1.7), Vector2(1.8, 3.35), Vector2(3.45, 4.98)]
	for i: int in range(3):
		var x: float = centres[i]
		var at := f * Vector3(x, y, -2.4)
		# Each room's own two downlights, so staff can watch the player. The seat room's front one goes
		# door-side of the cassette, so the seat's face is lit and some of it gets out under the curtain.
		var lamps: Array[Vector3] = []
		for z: float in ([-1.0, -3.85] if i == 1 else [-1.3, -3.3]):
			_vr_downlight(x, z, y, top, walls[i])
			lamps.append(f * Vector3(x, y, z))
		_vr_bay(at, top, i == 1, lamps)
		if i == 1:
			_solid(2.08, 3.08, y, y + 1.4, -3.0, -1.9)
		else:
			_solid(x + .35, x + .55, y + 1.3, y + 1.54, -2.17, -1.95) # The headset waiting on its cable.
		_bar("plain", f, x, top - .24, -.62, Vector3(1.24, .4, .05), Color("#060a14"))
		_panel("sign", f, x - .6, x + .6, top - .43, top - .05, -.592, cards[i])
		_panel("sign_in", Transform3D(Basis(Vector3.UP, PI), f * Vector3(x, 0, -.648)), -.6, .6, top - .43, top - .05, 0, cards[i])

func _vr_downlight(x: float, z: float, y: float, top: float, walls: Vector2) -> void:
	# A recessed can in the black grid, its pool on the floor, and the scallop it throws up either wall.
	var f := _front
	var white := Color(1.0, .95, .88)
	_kit.disc("plain", f * Vector3(x, top - .025, z), Vector3.RIGHT, Vector3.BACK, .07, Color("#0c0c0e"))
	_kit.disc("panel", f * Vector3(x, top - .026, z), Vector3.RIGHT, Vector3.BACK, .05, white)
	var low := y + .004
	var half := minf(VR_POOL, minf(x - walls.x, walls.y - x))
	var near := minf(z + VR_POOL, -.12) # Stopped short of the glass, or the street sees it on the slab edge.
	_kit.atlas("pool", f * Vector3(x - half, low, near), f * Vector3(x - half, low, z - VR_POOL), f * Vector3(x + half, low, z - VR_POOL), f * Vector3(x + half, low, near), Rect2(.5 - half / (2.0 * VR_POOL), 0, half / VR_POOL, (near - z + VR_POOL) / (2.0 * VR_POOL)), white * .2)
	var flip := Rect2(0, 1, 1, -1)
	_panel("wash_vr", Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(walls.x, y, z)), -.42, .42, .05, 2.3, .012, flip, white * .2)
	_panel("wash_vr", Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(walls.y, y, z)), -.42, .42, .05, 2.3, .012, flip, white * .2)

func _vr_curtain(x0: float, x1: float, y: float) -> void:
	# Two drops of heavy matte cloth overlapping at the middle of the door, a good half metre short
	# of the floor, so it is black under them. Cloth: you walk through it.
	var f := _front
	var mid := (x0 + x1) * .5
	var strips := 16
	var target := _kit._part("cloth")
	for drop: Array in [[x0, mid + .04, -4.205, x0 * 3.1], [mid - .04, x1, -4.265, x0 * 5.3 + 1.0]]:
		var left: float = drop[0]
		var wide: float = drop[1] - left
		var z: float = drop[2]
		var phase: float = drop[3]
		var folds: Array[Vector2] = []
		for i: int in range(strips + 1):
			var a := wide * float(i) / float(strips)
			var one := a * TAU / .23 + phase
			var two := a * TAU / .14 + phase * 1.7
			folds.append(Vector2(sin(one) * .017 + sin(two) * .009, cos(one) * .46 + cos(two) * .4)) # How far out it hangs here, and how steeply.
		for i: int in range(strips):
			var a := left + wide * float(i) / float(strips)
			var b := left + wide * float(i + 1) / float(strips)
			var pa := f * Vector3(a, y + .5, z + folds[i].x)
			var pb := f * Vector3(b, y + .5, z + folds[i + 1].x)
			var qa := f * Vector3(a, y + 2.1, z + folds[i].x)
			var qb := f * Vector3(b, y + 2.1, z + folds[i + 1].x)
			var na := Vector3(folds[i].y, 0, -1).normalized()
			var nb := Vector3(folds[i + 1].y, 0, -1).normalized()
			# No lamp reaches in here to model the folds, so the shade runs across them corner to corner.
			var lit_a := Color(.118, .111, .104) * (.76 + .27 * clampf(folds[i].y, -1.0, 1.0))
			var lit_b := Color(.118, .111, .104) * (.76 + .27 * clampf(folds[i + 1].y, -1.0, 1.0))
			for side: Array in [[pa, qa, qb, pb, na, nb], [pb, qb, qa, pa, -nb, -na]]:
				var low_a: Color = lit_a if side[0] == pa else lit_b
				var low_b: Color = lit_b if side[0] == pa else lit_a
				var hem_a := Color(low_a.r, low_a.g, low_a.b, 1.0)
				var hem_b := Color(low_b.r, low_b.g, low_b.b, 1.0)
				var head_a := Color(low_a.r * .8, low_a.g * .8, low_a.b * .8, 1.0) # In the shadow of the lintel.
				var head_b := Color(low_b.r * .8, low_b.g * .8, low_b.b * .8, 1.0)
				var tangent: Vector3 = ((side[3] as Vector3) - (side[0] as Vector3)).normalized()
				for row: Array in [[side[0], side[4], hem_a], [side[1], side[4], head_a], [side[2], side[5], head_b], [side[0], side[4], hem_a], [side[2], side[5], head_b], [side[3], side[5], hem_b]]:
					_kit._emit(target, row[0], row[1], tangent, row[2], Vector2.ZERO, Vector2.ZERO)

func _motion_chair(at: Vector3) -> void:
	# What a real motion seat is: a moulded racing shell on two rams over a steel base, grips either
	# side, a harness, and nothing a person would need to be hung inside.
	var seat := Transform3D(Basis(Vector3.UP, MOTION_TURN), at)
	var steel := Color("#3a3d44")
	var shell := Color("#18191d")
	var vinyl := Color("#141518")
	var rod := Color("#9a9ea4")
	_bar("steel_in", seat, 0, .05, -.06, Vector3(.76, .1, .84), Color("#24262c"))
	for i: int in range(12): # The hazard edge, along the front of the plate where a foot finds it.
		_bar("paint", seat, -.5 + float(i) * .0909, .002, .6, Vector3(.0909, .004, .05), Color("#b89a20") if i % 2 == 0 else Color("#101012"))
	_kit.lathe("steel_in", at + Vector3.UP * .1, [Vector2(.13, 0), Vector2(.13, .03), Vector2(.08, .06), Vector2(.08, .3)], steel, 20)
	for side: float in [-1.0, 1.0]:
		_kit.tube("steel_in", [seat * Vector3(side * .26, .1, -.34), seat * Vector3(side * .23, .28, -.24)], .034, steel, 10)
		_kit.tube("chrome", [seat * Vector3(side * .23, .28, -.24), seat * Vector3(side * .2, .44, -.15)], .016, rod, 8)
	_bar("steel_in", seat, 0, .43, -.02, Vector3(.52, .04, .56), steel)
	# The foot plate, out on two struts.
	for side: float in [-1.0, 1.0]:
		_kit.tube("steel_in", [seat * Vector3(side * .16, .42, .2), seat * Vector3(side * .16, .24, .44)], .014, steel, 6)
	_bar("steel_in", seat, 0, .23, .46, Vector3(.42, .018, .22), Color("#50545a"))
	# The shell: a moulded bucket, wide and deep at the hips, pinched at the shoulders, winged again
	# round the head; the padding sits inside it, with piping where the two meet.
	var back_low := Vector2(.0, .5) # (z, y): where the back meets the cushion, then up the spine.
	var back_high := Vector2(-.09, 1.27)
	var rise := (back_high - back_low).normalized()
	var ahead := Vector3(0, -rise.x, rise.y) # Out of the back towards whoever sits in it.
	var spine := func(t: float) -> Vector3:
		var p := back_low.lerp(back_high, t)
		return Vector3(0, p.y, p.x)
	var wide := func(t: float) -> float:
		return lerpf(.25, .265, smoothstep(0.0, .35, t)) - .07 * smoothstep(.6, .78, t) + .015 * smoothstep(.85, 1.0, t)
	var deep := func(t: float) -> float:
		return lerpf(.15, .08, smoothstep(0.0, .45, t)) - .05 * smoothstep(.55, .75, t) + .06 * smoothstep(.8, .95, t)
	var outer: Array = []
	var inner: Array = []
	for i: int in range(13):
		var t := float(i) / 12.0
		var ring_out: Array[Vector3] = []
		var ring_in: Array[Vector3] = []
		for j: int in range(15):
			var phi := lerpf(-PI * .5, PI * .5, float(j) / 14.0)
			var w: float = wide.call(t)
			var d: float = deep.call(t)
			var p: Vector3 = spine.call(t)
			ring_out.append(seat * (p + Vector3(sin(phi) * (w + .02), 0, 0) + ahead * (d * (1.0 - cos(phi)) - .025)))
			ring_in.append(seat * (p + Vector3(sin(phi) * (w - .015), 0, 0) + ahead * ((d - .01) * (1.0 - cos(phi)) + .015)))
		outer.append(ring_out)
		inner.append(ring_in)
	_loft("shell_in", outer, shell)
	_loft("vinyl_in", inner, vinyl)
	# The cushion, wings rising either side for the thighs.
	var under: Array = []
	var cushion: Array = []
	for i: int in range(7):
		var t := float(i) / 6.0
		var z := lerpf(.02, .4, t)
		var y := lerpf(.5, .47, t)
		var lip := lerpf(.11, .07, t)
		var ring_out: Array[Vector3] = []
		var ring_in: Array[Vector3] = []
		for j: int in range(15):
			var phi := lerpf(-PI * .5, PI * .5, float(j) / 14.0)
			ring_out.append(seat * Vector3(sin(phi) * .285, y - .03 + lip * (1.0 - cos(phi)), z))
			ring_in.append(seat * Vector3(sin(phi) * .25, y + .015 + (lip - .01) * (1.0 - cos(phi)), z))
		under.append(ring_out)
		cushion.append(ring_in)
	_loft("shell_in", under, shell)
	_loft("vinyl_in", cushion, vinyl)
	# Piping round the rim of the shell, and the stitched centre panels in the seat's red.
	for skin: Array in [outer, under]:
		for edge: int in [0, 14]:
			var line: Array[Vector3] = []
			for ring: Array in skin:
				line.append(ring[edge])
			_kit.tube("plain", line, .009, Color("#1a1b20"), 5)
	var top_line: Array[Vector3] = []
	for j: int in range(15):
		top_line.append(outer[12][j])
	_kit.tube("plain", top_line, .009, Color("#1a1b20"), 5)
	for side: float in [-.07, .07]:
		var stitch: Array[Vector3] = []
		for i: int in range(1, 10):
			var t := float(i) / 12.0
			stitch.append(seat * (spine.call(t) + Vector3(side, 0, 0) + ahead * .017))
		_kit.tube("plain", stitch, .003, Color("#7a1418"), 3)
	# The belt slots under the head wings.
	for side: float in [-.08, .08]:
		var slot_at: Vector3 = spine.call(.8) + Vector3(side, 0, 0) + ahead * .016
		_kit.quad("plain", seat * (slot_at + Vector3(-.025, -.012, 0)), seat * (slot_at + Vector3(-.025, .012, 0)), seat * (slot_at + Vector3(.025, .012, 0)), seat * (slot_at + Vector3(.025, -.012, 0)), Color("#050506"))
	# Grips on stalks, and the harness, loose over the empty seat.
	for side: float in [-1.0, 1.0]:
		_kit.tube("steel_in", [seat * Vector3(side * .31, .46, .1), seat * Vector3(side * .34, .62, .14), seat * Vector3(side * .34, .78, .16)], .014, steel, 6)
		_kit.lathe("plain", seat * Vector3(side * .34, .78, .16), [Vector2(.022, 0), Vector2(.024, .02), Vector2(.022, .12), Vector2(.014, .13)], Color("#101012"), 12)
		_kit.tube("plain", [seat * Vector3(side * .08, 1.12, -.035), seat * Vector3(side * .1, .86, .03), seat * Vector3(side * .05, .62, .14)], .012, Color("#26272c"), 4)
	_bar("metal", seat, 0, .62, .1, Vector3(.1, .03, .05), Color("#7a7c82"))

func _loft(part: String, rings: Array, tint: Color) -> void:
	# A skin through rings of points, faced both ways: a moulded shell is seen from either side.
	for i: int in range(rings.size() - 1):
		var low: Array = rings[i]
		var high: Array = rings[i + 1]
		for j: int in range(low.size() - 1):
			_kit.quad(part, low[j], high[j], high[j + 1], low[j + 1], tint)
			_kit.quad(part, low[j + 1], high[j + 1], high[j], low[j], tint)

func _vr_bay(at: Vector3, top: float, seat: bool, lamps: Array[Vector3]) -> void:
	# A tracked platform with its lit ring; the middle room is the motion seat on a steel plate.
	if seat:
		_bar("steel_in", Transform3D(Basis.IDENTITY, at), 0, .02, 0, Vector3(1.14, .04, 1.3), Color("#1c1e22"))
		_box_solid(Transform3D(Basis.IDENTITY, at), Vector3(0, .02, 0), Vector3(1.14, .04, 1.3))
		_motion_chair(at + Vector3.UP * .04)
	else:
		_kit.lathe("plain", at, [Vector2(.7, 0), Vector2(.7, .05), Vector2(.0, .06)], Color("#141416"), 28)
		# The step stands proud of the floor's pools, so each downlight's pool is laid again on its top,
		# measured from the same lamp: where the two meet at the edge, the light carries straight on.
		var target := _kit._part("pool")
		for lamp: Vector3 in lamps:
			if Vector2(lamp.x - at.x, lamp.z - at.z).length() > VR_POOL + .7:
				continue
			for j: int in range(8):
				for k: int in range(28):
					var corners: Array[Vector3] = []
					for c: Vector2i in [Vector2i(j, k), Vector2i(j + 1, k), Vector2i(j + 1, k + 1), Vector2i(j, k + 1)]:
						var r := .7 * float(c.x) / 8.0
						var a := TAU * float(c.y) / 28.0
						corners.append(at + Vector3(cos(a) * r, .062 - .01 * r / .7, sin(a) * r))
					for tri: Array in [[corners[0], corners[1], corners[2]], [corners[0], corners[2], corners[3]]]:
						if ((tri[2] as Vector3) - (tri[0] as Vector3)).cross((tri[1] as Vector3) - (tri[0] as Vector3)).y < 0.0:
							tri.reverse()
						for p: Vector3 in tri:
							var uv := Vector2(.5, .5) + Vector2(p.x - lamp.x, p.z - lamp.z) / (2.0 * VR_POOL)
							_kit._emit(target, p, Vector3.UP, Vector3.RIGHT, Color(1.0, .95, .88) * .2, uv, Vector2.ZERO)
		for turn: float in [0.0, PI * .25]: # The platform is a low step, not a picture of one: two squares make its round.
			_box_solid(Transform3D(Basis(Vector3.UP, turn), at), Vector3(0, .0275, 0), Vector3(1.32, .055, 1.32))
		var ring: Array[Vector3] = []
		for i: int in range(33):
			var a := TAU * float(i) / 32.0
			ring.append(at + Vector3(cos(a) * .66, .058, sin(a) * .66))
		_kit.tube("led", ring, .008, Color(.1, .42, .5), 5)
	# The boom overhead, its cable, and the headset waiting on the end of it, looking back at the door.
	var mount := Vector3(at.x, top - .02, at.z)
	var boom := mount + Vector3(.3, -.32, 0)
	_kit.tube("steel_in", [mount, boom], .03, Color("#1e2026"), 10)
	var hold := Transform3D(Basis(Vector3.UP, MOTION_TURN), at) * Transform3D(Basis.IDENTITY, Vector3(.34, 1.06, .02)) if seat else Transform3D(Basis(Vector3.UP, PI), at + Vector3(.45, 1.42, .34))
	# Its straps: one round the back of the head from either end of the visor, one over the top.
	var band: Array[Vector3] = []
	for i: int in range(11):
		var a := PI * float(i) / 10.0
		band.append(hold * Vector3(cos(a) * .095, 0, -sin(a) * .19))
	_kit.tube("plain", band, .008, Color("#1a1b1f"), 5)
	var crown: Array[Vector3] = []
	for i: int in range(7):
		var u := float(i) / 6.0
		crown.append(hold * Vector3(0, .055 * (1.0 - u) + sin(u * PI) * .06, -.03 - .16 * u))
	_kit.tube("plain", crown, .008, Color("#1a1b1f"), 5)
	var cable: Array[Vector3] = []
	var end: Vector3 = crown[3]
	for i: int in range(8):
		var u := float(i) / 7.0
		cable.append(boom.lerp(end, u) + Vector3(.1, 0, .06) * sin(u * PI))
	_kit.tube("plain", cable, .012, Color("#101216"), 4)
	_bar("vinyl_in", hold, 0, 0, 0, Vector3(.19, .11, .1), Color("#26282e"))
	_bar("shell_in", hold, 0, 0, .051, Vector3(.17, .09, .004), Color("#101216"))
	_bar("plain", hold, 0, 0, -.058, Vector3(.17, .085, .016), Color("#0c0c0e")) # The face pad.
	_bar("led", hold, 0, 0, .053, Vector3(.13, .03, .006), Color(.2, .9, 1.0))
	_bar("paint", Transform3D(Basis.IDENTITY, mount), -.52, -.04, -.5, Vector3(.1, .12, .1), Color(.03, .03, .034))
	_status(Transform3D(Basis.IDENTITY, mount), -.52, -.07, -.45, GREEN)

func _plain_sides() -> void:
	# Nobody pays for enamel where the street cannot see it: office cladding and a few small windows.
	var paint := Color(1.0, 1.0, .98)
	var holes: Array[Rect2] = [Rect2(2.2, 9.6, .9, 1.1), Rect2(4.8, 9.6, .9, 1.1), Rect2(2.2, 12.6, .9, 1.1), Rect2(4.8, 12.6, .9, 1.1)]
	for face: Transform3D in [_west, _east]:
		_render_wall(face, DEEP, TOP, 3.4, 3.0, paint, holes, .85)
		for r: Rect2 in holes:
			_window(face, r, _rng.randf(), false)
	var louvre := Rect2(2.4, 8.2, 2.2, 1.1)
	_render_wall(_back, WIDE, TOP, 3.4, 3.0, paint, [louvre], .85)
	_reveal(_back, louvre, .1, Color("#6b6a66"))
	_kit.quad("plain", _back * Vector3(louvre.position.x, louvre.position.y, -.1), _back * Vector3(louvre.position.x, louvre.end.y, -.1), _back * Vector3(louvre.end.x, louvre.end.y, -.1), _back * Vector3(louvre.end.x, louvre.position.y, -.1), Color("#17181a"))
	# The rainwater pipe down the corner, strapped on every storey.
	var f := _front
	_kit.tube("metal", [f * Vector3(7.11, TOP, .09), f * Vector3(7.11, .1, .09)], .05, Color("#8a8c8c"), 8)
	var y := 1.6
	while y < TOP:
		_bar("metal", f, 7.11, y, .05, Vector3(.13, .03, .12), Color("#5a5c5e"))
		y += 3.0

func _roof() -> void:
	var f := _front
	_kit.quad("plain", f * Vector3(0, TOP, 0), f * Vector3(0, TOP, -DEEP), f * Vector3(WIDE, TOP, -DEEP), f * Vector3(WIDE, TOP, 0), Color("#4a4c50"), .8, .9)
	_bar("frame", f, WIDE * .5, TOP + .05, -.02, Vector3(WIDE + .08, .1, .14), JOINT)
	_bar("frame", f, WIDE * .5, TOP + .05, -DEEP + .02, Vector3(WIDE + .08, .1, .14), JOINT)
	for x: float in [.02, WIDE - .02]:
		_bar("frame", f, x, TOP + .05, -DEEP * .5, Vector3(.14, .1, DEEP), JOINT)
	_outdoor_unit(_at(f, 1.5, TOP + .34, -4.6), 0, 0, 0)
	_outdoor_unit(_at(f, 2.5, TOP + .34, -4.6), 0, 0, 0)
	_outdoor_unit(_at(f, 3.5, TOP + .34, -4.6), 0, 0, 0)
	_bar("metal", f, 5.6, TOP + .4, -5.4, Vector3(.7, .8, 1.4), Color("#7a7c7a"))
	_kit.tube("metal", [f * Vector3(5.6, TOP + .8, -5.4), f * Vector3(5.6, TOP + 1.3, -5.4)], .16, Color("#8a8c8a"), 10)
	# The prize drone's pad: the one thing up here younger than the panels.
	_bar("metal", f, 2.6, TOP + .1, -6.5, Vector3(1.4, .1, 1.4), Color("#2c2e30"))
	_status(f, 2.0, TOP + .17, -5.9, GREEN)
	_status(f, 3.2, TOP + .17, -5.9, GREEN)

func _piers() -> void:
	# Dark polished stone either side of the entry, what the bank next door would have had.
	var f := _front
	for row: Array in [[ENTRY_X0 * .5, ENTRY_X0], [(ENTRY_X1 + WIDE) * .5, WIDE - ENTRY_X1]]:
		_bar("stone", f, row[0], LIGHT_LOW * .5, -.1, Vector3(row[1], LIGHT_LOW, .2), Color("#15171c"), .85, 1.0)
		_bar("stone", f, row[0], .16, .015, Vector3(row[1] + .01, .32, .03), Color("#3a3c42"))
	# The lit poster case on the left pier: this week's game over the print club.
	_bar("frame", f, .6, 1.52, .1, Vector3(1.04, 2.86, .2), Color("#c8ccd2"))
	_panel("art", f, .13, 1.07, 1.62, 2.72, .204, _cell(0, 0, 1024, 1200))
	_panel("sign", f, .13, 1.07, .22, 1.54, .204, _cell(1410, 1110, 300, 420))
	# A drinks machine on the right pier, and the meters above it.
	_bar("metal", f, 6.54, .95, .37, Vector3(.92, 1.86, .72), Color("#c8ccce"))
	_panel("goods", f, 6.12, 6.96, .12, 1.8, .733, _cell(1500, 1520, 240, 420))
	_bar("metal", f, 6.3, 2.4, .05, Vector3(.42, .5, .1), Color("#a8aaa8"))
	_bar("metal", f, 6.8, 2.34, .05, Vector3(.3, .36, .1), Color("#8f928f"))
	_kit.tube("metal", [f * Vector3(6.3, 2.65, .06), f * Vector3(6.3, 3.1, .06)], .018, Color("#6a6c6c"), 6)

func _lightbox() -> void:
	var f := _front
	var mid := (LIGHT_LOW + LIGHT_HIGH) * .5
	_bar("plain", f, WIDE * .5, mid, .13, Vector3(WIDE + .02, LIGHT_HIGH - LIGHT_LOW, .62), Color("#2a2c30"))
	_panel("sign", f, .03, WIDE - .03, LIGHT_LOW + .04, LIGHT_HIGH - .04, .443, _cell(0, 0, 1400, 273))
	for y: float in [LIGHT_LOW + .025, LIGHT_HIGH - .025]:
		_bar("frame", f, WIDE * .5, y, .43, Vector3(WIDE + .04, .05, .05), Color("#c8ccd2"))
	for x: float in [.02, 2.4, 4.78, WIDE - .02]:
		_bar("frame", f, x, mid, .43, Vector3(.04, LIGHT_HIGH - LIGHT_LOW, .05), Color("#c8ccd2"))
	# Lamps along the top of the box, thrown up the wall over the posters.
	for x: float in [5.6, 6.5]:
		_bar("metal", f, x, LIGHT_HIGH + .07, .3, Vector3(.28, .12, .16), Color("#3a3c3e"))
		_panel("wash", f, x - 1.05, x + 1.05, LIGHT_HIGH + .08, LIGHT_HIGH + 6.0, .14, Rect2(0, 0, 1, 1), Color(1.0, .9, .78) * .3)
	_camera(f * Vector3(ENTRY_X0 + .2, HEAD - .02, -.2))

func _awning() -> void:
	# Over the doors only, and sewn in widths that have each faded at their own rate.
	var f := _front
	var inner := Vector2(3.13, .4)
	var outer := Vector2(2.74, 1.25)
	for i: int in range(8):
		var a := lerpf(ENTRY_X0, ENTRY_X1, float(i) / 8.0)
		var b := lerpf(ENTRY_X0, ENTRY_X1, float(i + 1) / 8.0)
		_kit.quad("plain", f * Vector3(a, outer.x, outer.y), f * Vector3(a, inner.x, inner.y), f * Vector3(b, inner.x, inner.y), f * Vector3(b, outer.x, outer.y), AWNING.darkened(_rng.randf_range(0.0, .1)), .92, 1.0, .6)
	var x0 := ENTRY_X0
	var x1 := ENTRY_X1
	_kit.quad("plain", f * Vector3(x0, inner.x - .01, inner.y), f * Vector3(x0, outer.x - .01, outer.y), f * Vector3(x1, outer.x - .01, outer.y), f * Vector3(x1, inner.x - .01, inner.y), AWNING.darkened(.5))
	_kit.quad("plain", f * Vector3(x0, outer.x - .16, outer.y), f * Vector3(x0, outer.x, outer.y), f * Vector3(x1, outer.x, outer.y), f * Vector3(x1, outer.x - .16, outer.y), AWNING.darkened(.1), .95, 1.0, .5)
	_kit.quad("plain", f * Vector3(x1, outer.x - .16, outer.y - .01), f * Vector3(x1, outer.x, outer.y - .01), f * Vector3(x0, outer.x, outer.y - .01), f * Vector3(x0, outer.x - .16, outer.y - .01), AWNING.darkened(.5))
	for x: float in [x0 + .02, x1 - .02]:
		_kit.quad("plain", f * Vector3(x, outer.x, outer.y), f * Vector3(x, inner.x, inner.y), f * Vector3(x, inner.x - .3, inner.y), f * Vector3(x, outer.x - .16, outer.y), AWNING.darkened(.3))
		_kit.tube("metal", [f * Vector3(x, outer.x - .02, outer.y), f * Vector3(x, inner.x - .02, inner.y)], .012, STEEL, 5)
	for x: float in [2.1, 3.0, 3.9, 4.8]:
		_kit.tube("metal", [f * Vector3(x, outer.x - .03, outer.y - .02), f * Vector3(x, inner.x - .03, inner.y)], .009, STEEL, 4)

func _entry() -> void:
	# The step back from the street, tiled and downlit, with the glass line behind it.
	var f := _front
	var x0 := ENTRY_X0
	var x1 := ENTRY_X1
	var z := GLASS_Z
	_kit.quad("stone", f * Vector3(x0, .03, 0), f * Vector3(x0, .03, z), f * Vector3(x1, .03, z), f * Vector3(x1, .03, 0), Color("#6a6c70"))
	_kit.quad("room", f * Vector3(x0, HEAD, z), f * Vector3(x0, HEAD, 0), f * Vector3(x1, HEAD, 0), f * Vector3(x1, HEAD, z), Color("#2a2c32"))
	_kit.quad("stone", f * Vector3(x0, 0, 0), f * Vector3(x0, HEAD, 0), f * Vector3(x0, HEAD, z), f * Vector3(x0, 0, z), Color("#15171c"))
	_kit.quad("stone", f * Vector3(x1, 0, z), f * Vector3(x1, HEAD, z), f * Vector3(x1, HEAD, 0), f * Vector3(x1, 0, 0), Color("#15171c"))
	_bar("plain", f, (x0 + x1) * .5, 3.08, .0, Vector3(x1 - x0, .16, .12), Color("#17181c"))
	for x: float in [1.8, 2.9, 4.0, 5.1]:
		_kit.disc("lamp", f * Vector3(x, HEAD - .01, z * .5), Vector3.RIGHT, Vector3.BACK, .06, Color(1.0, .95, .88))
	var bronze := Color("#2a2826")
	for pane: Vector2 in [Vector2(x0, DOOR_X - 1.2), Vector2(DOOR_X + 1.2, x1)]:
		_kit.quad("front", f * Vector3(pane.x, .03, z), f * Vector3(pane.x, HEAD, z), f * Vector3(pane.y, HEAD, z), f * Vector3(pane.y, .03, z), Color.WHITE)
		_kit.quad("front", f * Vector3(pane.y, .03, z), f * Vector3(pane.y, HEAD, z), f * Vector3(pane.x, HEAD, z), f * Vector3(pane.x, .03, z), Color.WHITE)
	for x: float in [x0 + .03, 2.35, 4.75, x1 - .03]:
		_bar("metal", f, x, HEAD * .5, z, Vector3(.07, HEAD, .1), bronze)
	_bar("metal", f, (x0 + x1) * .5, 2.62, z, Vector3(x1 - x0, .1, .1), bronze)
	_bar("metal", f, 3.55, 2.8, z + .02, Vector3(2.5, .3, .12), Color("#3a3a3a"))
	_bar("stone", f, (x0 + x1) * .5, .05, z, Vector3(x1 - x0, .08, .1), Color("#202226"))
	_kit.quad("plain", f * Vector3(2.4, .04, z + .5), f * Vector3(2.4, .04, z - .4), f * Vector3(4.7, .04, z - .4), f * Vector3(4.7, .04, z + .5), Color("#17181c"))
	# Floor guide on the jamb, where you stop to read it.
	var jamb := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(x1, 0, z))
	_bar("plain", jamb, .34, 1.72, .012, Vector3(.54, 1.12, .024), INK)
	_panel("sign", jamb, .11, .57, 1.2, 2.24, .026, _cell(910, 600, 280, 640))
	var left := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT).rotated(Vector3.UP, PI), f * Vector3(x0, 0, 0))
	_panel("poster", left, .12, .8, 1.76, 2.66, .012, _cell(1830, 552, 200, 260))
	var cards: Array[Rect2] = [_cell(1410, 820, 200, 280), _cell(1830, 820, 200, 280)]
	var tints: Array[Color] = [Color("#d81820"), Color("#1a78e8"), Color("#f0a810"), Color("#28a858")]
	var slot := 0
	for level: int in range(2):
		for along: float in [-.26, -.7]:
			_gacha(Transform3D(Basis(Vector3.UP, PI * .5), f * Vector3(x0 + .4, .03 + float(level) * .81, along)), cards[slot % 2], tints[slot])
			slot += 1

func _cabinet(t: Transform3D, kind: int, simple := false, sides: Array = [-1.0, 1.0], heap := false) -> void:
	# One UFO catcher, front-bottom-centre at t, as the Sega and Taito ones are built: glass nearly
	# to the ceiling, a printed back wall, a bed of balls, and a console you lean on.
	_cabinet_body(t, sides)
	_control_deck(t, simple)
	_prize_stage(t, kind, simple, heap)
	_rails(t)
	if simple or kind == 1:
		var at := Vector2([.3, .16, -.2][kind], -.46)
		_beam(Transform3D(t.basis, t * Vector3(0, 0, at.y)))
		var carriage := Transform3D(t.basis, t * Vector3(at.x, 0, at.y))
		_motor(carriage)
		_coil(carriage, COIL_TOP - POD_REST - .03)
		var head := Transform3D(t.basis, carriage * Vector3(0, POD_REST, 0))
		_head(head)
		for side: float in [-1.0, 1.0]:
			_arm(Transform3D(t.basis, head * Vector3(side * ARM_X, ARM_Y, 0)), side)
	else:
		_working_claw(t, kind)
	_cabinet_frame(t, kind, sides)

func _flank(t: Transform3D, side: float) -> Transform3D:
	# A cabinet's side read from outside: +x across it, +z out of it, x = 0 at its left edge.
	var along := Vector3.FORWARD if side > 0.0 else Vector3.BACK
	var start := 0.0 if side > 0.0 else -CAB_D
	return Transform3D(t.basis * Basis(along, Vector3.UP, Vector3.RIGHT * side), t * Vector3(side * CAB_W * .5, 0, start))

func _cabinet_body(t: Transform3D, sides: Array) -> void:
	var half := CAB_W * .5
	var enamel := Color("#f0eef2")
	_bar("plain", t, 0, .04, -CAB_D * .5, Vector3(CAB_W - .06, .08, CAB_D - .08), Color("#121216"))
	_bar("shell", t, 0, .47, -CAB_D * .5, Vector3(CAB_W, .78, CAB_D), enamel, .86, 1.0)
	_kit.atlas("crane_print", t * Vector3(-half, .08, .002), t * Vector3(-half, .84, .002), t * Vector3(half, .84, .002), t * Vector3(half, .08, .002), _cell(0, 812, 1024, 620))
	for x: float in [-.5, .5]:
		_kit.lathe("fitting", t * Vector3(x, 0, -.04), [Vector2(.03, 0), Vector2(.034, .03), Vector2(.012, .08)], Color("#3a3c40"), 12)
	# The prize flap: hinged at the top, sunk in a chrome frame, pushed in by every hand since 2031.
	var x0 := .08
	var x1 := .52
	var y0 := .16
	var y1 := .6
	_kit.quad("plain", t * Vector3(x0, y0, .003), t * Vector3(x0, y1, .003), t * Vector3(x1, y1, .003), t * Vector3(x1, y0, .003), Color("#08080a"))
	_panel("crane_print", t, x0 + .025, x1 - .025, y0 + .025, y1 - .025, .012, _cell(0, 1440, 400, 400))
	for y: float in [y0 + .01, y1 - .01]:
		_bar("chrome", t, (x0 + x1) * .5, y, .012, Vector3(x1 - x0 + .03, .022, .024), Color("#d8dce0"))
	for x: float in [x0, x1]:
		_bar("chrome", t, x, (y0 + y1) * .5, .012, Vector3(.022, y1 - y0 + .03, .024), Color("#d8dce0"))
	# The service door and its lock.
	_bar("shell", t, -.3, .46, .006, Vector3(.42, .52, .012), Color("#e4e2e8"))
	for y: float in [.28, .64]:
		_bar("fitting", t, -.5, y, .014, Vector3(.03, .05, .012), Color("#8a8c90"))
	_kit.disc("chrome", t * Vector3(-.14, .46, .0135), t.basis.x, t.basis.y, .018, Color("#d8dce0"))
	_bar("plain", t, -.14, .46, .0145, Vector3(.004, .018, .002), Color("#101014"))
	for i: int in range(5):
		_bar("plain", t, -.3, .3 + float(i) * .016, .0135, Vector3(.24, .005, .002), Color("#2a2a30"))
	# Caution labels, stuck wherever there was room beside the door.
	for y: float in [.5, .57, .66]:
		var x := -.015 + _rng.randf_range(-.025, .025)
		_kit.quad("room", t * Vector3(x - .03, y - .02, .003), t * Vector3(x - .03, y + .02, .003), t * Vector3(x + .03, y + .02, .003), t * Vector3(x + .03, y - .02, .003), Color("#f0c820"))
		_kit.quad("room", t * Vector3(x - .03, y + .01, .0035), t * Vector3(x - .03, y + .02, .0035), t * Vector3(x + .03, y + .02, .0035), t * Vector3(x + .03, y + .01, .0035), Color("#141416"))
	# Printed down each side that shows, with its seam, its vent, and the sill up to the bed.
	for side: float in sides:
		var flank := _flank(t, side)
		var seam := .48 if side > 0.0 else CAB_D - .48
		var vent := .75 if side > 0.0 else CAB_D - .75
		_panel("crane_print", flank, .03, .92, .08, .84, .001, _cell(0, 812, 752, 620))
		_kit.quad("shell", flank * Vector3(0, .86, 0), flank * Vector3(0, .96, 0), flank * Vector3(CAB_D, .96, 0), flank * Vector3(CAB_D, .86, 0), Color("#e4e2e8"))
		_bar("plain", flank, seam, .46, .002, Vector3(.004, .76, .002), Color("#a8a6ae"))
		for i: int in range(5):
			_bar("plain", flank, vent, .3 + float(i) * .016, .002, Vector3(.24, .005, .002), Color("#2a2a30"))

func _control_deck(t: Transform3D, simple: bool) -> void:
	# A wedge you can lean on, with the plate tilted up at you.
	var half := CAB_W * .5
	var skin := Color("#d8d6dc")
	var low := .78
	var mid := .9
	var high := .98
	var out := .2
	_kit.quad("shell", t * Vector3(-half, low, 0), t * Vector3(-half, high, 0), t * Vector3(-half, mid, out), t * Vector3(-half, low + .04, out), skin)
	_kit.quad("shell", t * Vector3(half, low + .04, out), t * Vector3(half, mid, out), t * Vector3(half, high, 0), t * Vector3(half, low, 0), skin)
	_kit.quad("shell", t * Vector3(-half, low + .04, out), t * Vector3(-half, mid, out), t * Vector3(half, mid, out), t * Vector3(half, low + .04, out), skin)
	_kit.quad("shell", t * Vector3(half, low + .04, out), t * Vector3(half, low, 0), t * Vector3(-half, low, 0), t * Vector3(-half, low + .04, out), skin.darkened(.4))
	_kit.atlas("crane_print", t * Vector3(-half, mid, out), t * Vector3(-half, high, 0), t * Vector3(half, high, 0), t * Vector3(half, mid, out), _cell(0, 512, 1024, 300))
	_bar("chrome", t, 0, mid - .006, out + .004, Vector3(CAB_W, .012, .012), Color("#d8dce0"))
	_bar("led", t, 0, mid - .04, out + .003, Vector3(CAB_W - .1, .01, .006), Color(1.0, .2, .54))
	var normal := Vector3(0, out, high - mid).normalized()
	var toward := Vector3.RIGHT.cross(normal)
	var deck := Transform3D(t.basis * Basis(Vector3.RIGHT, normal, toward), t * Vector3(0, (mid + high) * .5, out * .5))
	# Stick: rubber boot, chrome shaft, red ball top, the same since 1985.
	var foot := deck * Vector3(-.38, .002, 0)
	_kit.disc("plain", foot, deck.basis.x, -deck.basis.z, .034, Color("#16161a"))
	_kit.lathe("plain", foot, [Vector2(.03, 0), Vector2(.022, .012), Vector2(.012, .024)], Color("#101014"), 14)
	_kit.lathe("chrome", foot + Vector3.UP * .02, [Vector2(.008, 0), Vector2(.008, .09)], Color("#e0e4e8"), 10)
	_ball(foot + Vector3.UP * .118, Vector3.ONE * .03, Color("#d01414"), "gloss", 10, 16)
	# The one big button.
	var button := deck * Vector3(-.138, .002, 0)
	_kit.lathe("chrome", button, [Vector2(.056, 0), Vector2(.056, .01), Vector2(.044, .014), Vector2(.0, .014)], Color("#c8ccd0"), 22)
	_ball(button + Vector3.UP * .012, Vector3(.042, .018, .042), Color(1.0, .66, .08), "led", 6, 18)
	# Pay screen in a black bezel, and the palm pad every machine got in the forties.
	_bar("plain", deck, .26, .003, -.002, Vector3(.3, .008, .2), Color("#0c0c10"))
	_kit.atlas("crane_screen", deck * Vector3(.125, .0085, .082), deck * Vector3(.125, .0085, -.086), deck * Vector3(.395, .0085, -.086), deck * Vector3(.395, .0085, .082), _cell(420, 1670, 360, 240))
	if not simple:
		_kit.disc("led", deck * Vector3(.5, .004, 0), deck.basis.x, -deck.basis.z, .05, Color(.1, .9, .8))
		_kit.disc("plain", deck * Vector3(.5, .005, 0), deck.basis.x, -deck.basis.z, .042, Color("#101418"))

func _prize_stage(t: Transform3D, kind: int, simple: bool, heap: bool) -> void:
	var half := CAB_W * .5
	var low := .96
	var high := GLASS_TOP
	var white := Color("#f6f4f6")
	# The bed takes the colour of the balls on it, so a gap between them never shows white.
	var bed: Color = [Color("#ff9cc8"), white, Color("#8ccaf0")][kind]
	var well: Array[Rect2] = [Rect2(.13, -.47, half - .16, .41)]
	for piece: Rect2 in _minus(Rect2(-half, -CAB_D, CAB_W, CAB_D - .03), well):
		_kit.quad("prize", t * Vector3(piece.position.x, low, piece.end.y), t * Vector3(piece.position.x, low, piece.position.y), t * Vector3(piece.end.x, low, piece.position.y), t * Vector3(piece.end.x, low, piece.end.y), bed)
	_kit.atlas("crane_lit", t * Vector3(-half, high - .62, -CAB_D + .01), t * Vector3(-half, high, -CAB_D + .01), t * Vector3(half, high, -CAB_D + .01), t * Vector3(half, high - .62, -CAB_D + .01), _cell(1024, float(kind) * 500.0, 1024, 500))
	_kit.quad("prize", t * Vector3(-half, low, -CAB_D + .01), t * Vector3(-half, high - .62, -CAB_D + .01), t * Vector3(half, high - .62, -CAB_D + .01), t * Vector3(half, low, -CAB_D + .01), white * .92)
	_kit.quad("prize", t * Vector3(-half, high, -CAB_D), t * Vector3(-half, high, -.03), t * Vector3(half, high, -.03), t * Vector3(half, high, -CAB_D), white * .8)
	for z: float in [-.1, -.5, -.86]:
		_bar("case_lamp", t, 0, high - .012, z, Vector3(CAB_W - .1, .01, .03), Color(1.0, .98, .95))
	# Prize chute front right: a white funnel down to the flap, with a clear wall round it.
	var x0 := .13
	var x1 := half - .03
	var z0 := -.06
	var z1 := -.47
	var drop := low - .09
	var lip := .07
	_kit.quad("plain", t * Vector3(x0 + lip, drop, z0 - lip), t * Vector3(x0 + lip, drop, z1 + lip), t * Vector3(x1 - lip, drop, z1 + lip), t * Vector3(x1 - lip, drop, z0 - lip), Color("#08080a"))
	_kit.quad("prize", t * Vector3(x0 + lip, drop, z1 + lip), t * Vector3(x0, low, z1), t * Vector3(x1, low, z1), t * Vector3(x1 - lip, drop, z1 + lip), white * .86)
	_kit.quad("prize", t * Vector3(x0 + lip, drop, z0 - lip), t * Vector3(x0, low, z0), t * Vector3(x0, low, z1), t * Vector3(x0 + lip, drop, z1 + lip), white * .94)
	_kit.quad("prize", t * Vector3(x1 - lip, drop, z1 + lip), t * Vector3(x1, low, z1), t * Vector3(x1, low, z0), t * Vector3(x1 - lip, drop, z0 - lip), white * .8)
	_kit.quad("prize", t * Vector3(x1 - lip, drop, z0 - lip), t * Vector3(x1, low, z0), t * Vector3(x0, low, z0), t * Vector3(x0 + lip, drop, z0 - lip), white * .7)
	var top := low + .17
	for row: Array in [[Vector3(x0, 0, z1), Vector3(x1, 0, z1)], [Vector3(x1, 0, z1), Vector3(x0, 0, z1)], [Vector3(x0, 0, z0), Vector3(x0, 0, z1)], [Vector3(x0, 0, z1), Vector3(x0, 0, z0)]]:
		var a: Vector3 = row[0]
		var b: Vector3 = row[1]
		_kit.quad("front", t * (a + Vector3.UP * low), t * (a + Vector3.UP * top), t * (b + Vector3.UP * top), t * (b + Vector3.UP * low), Color.WHITE)
	_bar("gloss", t, (x0 + x1) * .5, top, z1, Vector3(x1 - x0, .01, .012), Color("#f0f4f8"))
	_bar("gloss", t, x0, top, (z0 + z1) * .5, Vector3(.012, .01, z0 - z1), Color("#f0f4f8"))
	# Price and phone code, stuck inside the glass where you cannot miss them.
	_panel("crane_print", t, -.56, -.3, low + .02, low + .17, -.03, _cell(420, 1440, 360, 220))
	_panel("crane_print", t, -.28, -.15, low + .02, low + .17, -.03, _cell(800, 1440, 200, 220))
	# A price card propped on the bed, never quite where the last machine had it.
	var card := Vector2(_rng.randf_range(-.1, .06), _rng.randf_range(-.18, -.1))
	var prop := Transform3D(t.basis * Basis(Vector3.UP, _rng.randf_range(-.3, .3)) * Basis(Vector3.RIGHT, -.5), t * Vector3(card.x, .965 if kind == 1 else 1.025, card.y))
	_panel("crane_print", prop, -.0575, .0575, 0, .07, 0, _cell(420, 1440, 360, 220))
	match kind:
		0:
			_ball_bed(t, [Color("#ff4f9e"), Color("#ffffff"), Color("#ffa6cf")], simple)
			_toy_pile(t, Color("#dcb878"), _cell(0, 0, 512, 512), true, simple, heap)
		1:
			_figure_boxes(t)
		_:
			_ball_bed(t, [Color("#2ab0f0"), Color("#ffffff"), Color("#ffb020")], simple)
			_toy_pile(t, Color("#ffdc48"), _cell(512, 0, 512, 512), false, simple, heap)

func _ball_bed(t: Transform3D, tints: Array, simple: bool) -> void:
	# The little balls that fill the bed, loose and uneven, with a second layer where they heaped.
	var step := .11 if simple else .078
	var edge := CAB_W * .5 - .06 # Ball and jitter, stopping short of the side glass.
	var z := -.89
	var row := 0
	var made := 0
	while z < -.075:
		var x := -edge + (step * .5 if row % 2 == 1 else 0.0)
		while x < edge:
			if x < .08 or z < -.53: # Clear of the wall round the chute.
				var at := Vector3(x + _rng.randf_range(-.012, .012), .996 + _rng.randf() * .012, z + _rng.randf_range(-.012, .012))
				# The balls you can read at the glass, front or side, get the rounder cut.
				var near := z > -.42 or absf(x) > .42
				_ball(t * at, Vector3.ONE * .038, tints[made % tints.size()], "gloss", 7 if near else 5, 12 if near else 10)
				made += 1
				var heaped := at.x < .54 and at.z < -.09 and (at.x < .05 or at.z < -.56)
				if not simple and heaped and _rng.randf() < .3:
					_ball(t * (at + Vector3(.03, .046, .02)), Vector3.ONE * .038, tints[(made * 2) % tints.size()], "gloss", 5, 10)
			x += step
		z += step * .87
		row += 1

func _toy_pile(t: Transform3D, tint: Color, face: Rect2, ears: bool, simple: bool, heap := false) -> void:
	# Toys thrown loose on the bed, a few resting on the others, each lying how it landed.
	# Rows are x, y, z, turn, tilt up at you, and roll.
	var pile: Array = [[-.36, 1.085, -.52, -.1, .3, .12]]
	if not simple:
		pile.append_array([[-.43, 1.085, -.3, .5, .4, 0.0], [.26, 1.085, -.62, .4, .34, .08], [-.2, 1.07, -.16, -.6, 1.1, -.1]])
	if heap:
		_toy_heap(t, tint, face, ears)
	else:
		pile.append_array([[-.45, 1.085, -.76, .2, .3, .05], [-.2, 1.085, -.78, -.3, .32, -.1], [.1, 1.085, -.76, .15, .3, .1], [.42, 1.085, -.76, -.25, .36, -.06]])
		if not simple:
			pile.append_array([[-.34, 1.21, -.72, .1, .4, -.2], [-.04, 1.21, -.7, -.3, .44, .16], [.26, 1.21, -.74, .2, .42, -.12]])
	for row: Array in pile:
		var bent := t.basis * Basis(Vector3.UP, row[3]) * Basis(Vector3.RIGHT, -float(row[4])) * Basis(Vector3.BACK, row[5])
		_plush(t * Vector3(row[0], row[1], row[2]), TOY, bent, tint.darkened(_rng.randf_range(0.0, .05)), face, ears)

func _toy_heap(t: Transform3D, tint: Color, face: Rect2, ears: bool) -> void:
	# The stock of a filled machine: a dozen of the big ones slumped against the back wall, each
	# lying on the ones below, thinning as it climbs, with the front of the bed left to the claw.
	var big := TOY * 1.25
	var heap: Array = [[-.39, 1.115, -.75], [-.13, 1.12, -.72], [.13, 1.115, -.76], [.39, 1.12, -.73], [-.04, 1.12, -.6], [-.39, 1.275, -.77], [-.12, 1.285, -.76], [.14, 1.27, -.77], [.39, 1.26, -.77], [-.27, 1.44, -.77], [.03, 1.455, -.77], [.29, 1.41, -.76]]
	for row: Array in heap:
		var turn := _rng.randf_range(-.34, .34)
		var tilt := _rng.randf_range(.2, .34)
		var roll := _rng.randf_range(-.22, .22)
		var bent := t.basis * Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, -tilt) * Basis(Vector3.BACK, roll)
		var at := Vector3(float(row[0]) + _rng.randf_range(-.02, .02), float(row[1]) + _rng.randf_range(-.012, .012), float(row[2]) + _rng.randf_range(-.012, .012))
		_plush(t * at, big, bent, tint.darkened(_rng.randf_range(0.0, .05)), face, ears, 6, 10)

func _plush(at: Vector3, size: Vector3, axes: Basis, tint: Color, face: Rect2, ears: bool, rings := 8, sides := 14) -> void:
	# A stuffed pillow with the face printed into its cloth, so nothing floats and nothing z-fights.
	var ground := -size.y * .84
	for r: int in range(rings):
		for s: int in range(sides):
			var lat0 := -PI * .5 + PI * float(r) / float(rings)
			var lat1 := -PI * .5 + PI * float(r + 1) / float(rings)
			var lon0 := -TAU * float(s) / float(sides)
			var lon1 := -TAU * float(s + 1) / float(sides)
			var corners: Array[Vector3] = [_stuffed(lat0, lon0, size, .72, ground), _stuffed(lat1, lon0, size, .72, ground), _stuffed(lat1, lon1, size, .72, ground), _stuffed(lat0, lon1, size, .72, ground)]
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			var prints: Array[Vector2] = []
			var marks: Array[float] = []
			for p: Vector3 in corners:
				var sag := 1.0 - .09 * p.y / size.y
				var n := _stuffed_normal(p, size)
				points.append(at + axes * Vector3(p.x * sag, p.y, p.z * sag))
				normals.append(axes * n)
				prints.append(face.position + face.size * Vector2(.5 + p.x / size.x * .5, .5 - p.y / size.y * .5))
				marks.append(n.z)
			_kit.mapped("plush", points, normals, prints, marks, tint)
	if ears:
		var grown := size.x / TOY.x
		for side: float in [-1.0, 1.0]:
			_pillow(at + axes * Vector3(side * .082 * grown, size.y * .86, -.01 * grown), Vector3(.03, .028, .018) * grown, Color("#4a2a14"), axes, 4, 8)

func _figure_boxes(t: Transform3D) -> void:
	# Boxed figures on show at the back, and one balanced on two chrome bars, which is the game.
	var box := _cell(800, 1670, 220, 300)
	var chrome := Color("#e0e4e8")
	# The steel shelves they stand on, one under each row.
	for row: Array in [[.9675, .015], [1.275, .02], [1.585, .02]]:
		_bar("fitting", t, 0, row[0], -.76, Vector3(1.216, row[1], .17), Color("#d8dce0"))
	for row: int in range(3):
		for i: int in range(5):
			var x := -.5 + float(i) * .25
			var y := 1.12 + float(row) * .31
			var z := -.76
			_bar("shell", t, x, y, z, Vector3(.21, .29, .15), Color("#101828"))
			_panel("crane_print", t, x - .105, x + .105, y - .145, y + .145, z + .077, box)
	for x: float in [-.5, -.22]:
		_kit.tube("chrome", [t * Vector3(x, 1.2, -.5), t * Vector3(x, 1.2, -.06)], .009, chrome, 8)
		for z: float in [-.46, -.1]:
			_kit.lathe("plain", t * Vector3(x, 1.19, z), [Vector2(.014, 0), Vector2(.014, .02)], Color("#c01818"), 8)
	_bar("chrome", t, -.36, 1.2, -.5, Vector3(.42, .022, .022), chrome)
	_bar("fitting", t, -.36, 1.08, -.5, Vector3(.42, .22, .03), Color("#8a8c90"))
	var slanted := Transform3D(t.basis * Basis(Vector3.UP, .22), t * Vector3(-.36, 1.36, -.26))
	_bar("shell", slanted, 0, 0, 0, Vector3(.21, .29, .15), Color("#101828"))
	_panel("crane_print", slanted, -.105, .105, -.145, .145, .077, box)

func _rails(t: Transform3D) -> void:
	for side: float in [-.56, .56]:
		_bar("fitting", t, side, GLASS_TOP - .03, -.48, Vector3(.03, .03, .86), Color("#b8bcc2"))

func _beam(f: Transform3D) -> void:
	_bar("fitting", f, 0, GLASS_TOP - .06, 0, Vector3(1.12, .03, .05), Color("#b8bcc2"))

func _motor(f: Transform3D) -> void:
	# The carriage that runs along the beam, and the sleeve the rod slides up inside.
	_bar("fitting", f, 0, GLASS_TOP - .1, 0, Vector3(.16, .07, .13), Color("#6a6c72"))
	_kit.tube("chrome", [f * Vector3(0, GLASS_TOP - .12, 0), f * Vector3(0, 1.86, 0)], .024, Color("#c8ccd0"), 10)

func _coil(f: Transform3D, length: float) -> void:
	# The coiled lead, one metre long as built; a working claw stretches it by scale.
	var points: Array[Vector3] = []
	for i: int in range(96):
		var a := float(i) * .62
		var r := float(i) / 95.0
		points.append(f * Vector3(.05 + cos(a) * .022, COIL_TOP - r * length, -.03 + sin(a) * .022))
	_kit.tube("plain", points, .0035, Color("#f0f0ec"), 4)

func _head(f: Transform3D) -> void:
	# The white pod with its dark visor, on a chrome rod, with the yoke that carries the arms.
	_kit.tube("chrome", [f * Vector3(0, .05, 0), f * Vector3(0, .58, 0)], .016, Color("#e4e8ec"), 10)
	_kit.lathe("fitting", f * Vector3(0, .06, 0), [Vector2(.03, 0), Vector2(.03, .03)], Color("#b8bcc2"), 12)
	_ball(f.origin, Vector3(.135, .08, .1), Color("#f6f6f4"), "gloss", 16, 32, f.basis)
	_ball(f * Vector3(0, 0, .074), Vector3(.086, .046, .032), Color("#101a24"), "gloss", 12, 24, f.basis)
	_bar("fitting", f, 0, ARM_Y, 0, Vector3(ARM_X * 2.0 + .03, .012, .03), Color("#d8dce0"))

func _arm(f: Transform3D, side: float) -> void:
	# Hung from a hinge at f, curving back in at the tip like a clear plastic hook.
	var tip := f * Vector3(side * -.03, -.225, 0)
	_kit.tube("gloss", [f.origin, f * Vector3(side * .028, -.11, 0), f * Vector3(side * .008, -.19, 0), tip], .012, Color("#9fb4c2"), 8)
	_ball(tip, Vector3(.016, .012, .016), Color("#2a2c30"), "plain", 4, 8, f.basis)

func _seal(parent: Node3D, at: Vector3, reach := 30.0) -> Node3D:
	# Closes the kit in hand into its own moving part, drawn only when someone is near it.
	var node := Node3D.new()
	node.position = at
	parent.add_child(node)
	_kit.commit(node, _looks, QUIET)
	for child: Node in node.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).visibility_range_end = reach
	return node

func _working_claw(t: Transform3D, kind: int) -> void:
	var shared := _kit
	var rig := Node3D.new()
	rig.transform = t
	add_child(rig)
	var here := Transform3D.IDENTITY
	_kit = Kit.new()
	_beam(here)
	var beam := _seal(rig, Vector3(0, 0, CLAW_HOME.y))
	_kit = Kit.new()
	_motor(here)
	var carriage := _seal(beam, Vector3(CLAW_HOME.x, 0, 0))
	_kit = Kit.new()
	_coil(here, 1.0)
	var lead := _seal(carriage, Vector3(0, 0, 0))
	_kit = Kit.new()
	_head(here)
	var head := _seal(carriage, Vector3(0, POD_REST, 0))
	_kit = Kit.new()
	_arm(here, -1.0)
	var left := _seal(head, Vector3(-ARM_X, ARM_Y, 0))
	_kit = Kit.new()
	_arm(here, 1.0)
	var right := _seal(head, Vector3(ARM_X, ARM_Y, 0))
	# The one toy the claw can actually reach and lift.
	_kit = Kit.new()
	var tint: Color = Color("#dcb878") if kind == 0 else Color("#ffdc48")
	_plush(Vector3.ZERO, TOY, Basis(Vector3.UP, .15) * Basis(Vector3.RIGHT, -.32), tint, _cell(0, 0, 512, 512) if kind == 0 else _cell(512, 0, 512, 512), kind == 0)
	var prey := _seal(rig, Vector3(CLAW_GRAB.x, TOY_Y, CLAW_GRAB.y))
	# The strip and the lamp that come on when it wakes: dark until then, so the waking is a shock.
	var alarm: Color = Color(1.0, .16, .5) if kind == 0 else Color(1.0, .7, .1)
	_kit = Kit.new()
	_bar("neon", here, 0, GLASS_TOP - .03, -.05, Vector3(CAB_W - .1, .02, .014), alarm)
	_bar("neon", here, 0, .96, -.05, Vector3(CAB_W - .1, .014, .014), alarm)
	var flash := _seal(rig, Vector3.ZERO)
	flash.visible = false
	_kit = shared
	var glare := OmniLight3D.new()
	glare.position = Vector3(0, 1.6, .15)
	glare.light_color = alarm
	glare.light_energy = 1.8
	glare.omni_range = 3.4
	glare.visible = false
	rig.add_child(glare)
	var crane := {"rig": rig, "beam": beam, "carriage": carriage, "lead": lead, "head": head, "left": left, "right": right, "prey": prey, "flash": flash, "glare": glare, "clock": 0.0, "running": false, "wait": 0.0, "rest": 0.0}
	_cranes.append(crane)
	_pose(crane, 0.0)

func _process(delta: float) -> void:
	# Each machine runs its attract loop only when someone is close enough to watch it.
	var eye := get_viewport().get_camera_3d()
	if eye == null:
		return
	_run_doors(eye.global_position, delta)
	if eye.global_position.distance_squared_to(global_position) > 900.0:
		return
	var sway := sin(float(Time.get_ticks_msec()) * .0016) * .05
	for shelf: Dictionary in _shelves:
		(shelf.node as Node3D).position = shelf.home + shelf.out * sway
	var nearest: Dictionary = {}
	var best := WAKE_REACH
	_wake_rest = maxf(0.0, _wake_rest - delta)
	for crane: Dictionary in _cranes:
		crane.rest = maxf(0.0, float(crane.rest) - delta)
		if crane.running:
			_run_crane(crane, delta)
			continue
		var reach := (crane.rig as Node3D).global_position.distance_to(eye.global_position)
		if reach < best and float(crane.rest) <= 0.0 and _wake_rest <= 0.0:
			best = reach
			nearest = crane
	if not nearest.is_empty():
		_wake(nearest, 0.0)
		_wake_rest = _rng.randf_range(35.0, 60.0)
		# Sometimes a second one starts up behind you a moment later.
		if _rng.randf() < .55:
			var others: Array[Dictionary] = []
			for crane: Dictionary in _cranes:
				if not crane.running and float(crane.rest) <= 0.0:
					others.append(crane)
			if not others.is_empty():
				_wake(others[_rng.randi() % others.size()], _rng.randf_range(.5, 1.4))

func _wake(crane: Dictionary, delay: float) -> void:
	crane.running = true
	crane.wait = delay
	crane.clock = 3.6

func _run_crane(crane: Dictionary, delta: float) -> void:
	if float(crane.wait) > 0.0:
		crane.wait = float(crane.wait) - delta
		return
	crane.clock = float(crane.clock) + delta
	var lit: bool = fmod(float(crane.clock) * 5.0, 1.0) < .62
	(crane.flash as Node3D).visible = lit
	(crane.glare as Node3D).visible = lit
	_pose(crane, crane.clock)
	if float(crane.clock) >= CRANE_END:
		crane.running = false
		crane.clock = 0.0
		crane.rest = _rng.randf_range(30.0, 70.0)
		(crane.flash as Node3D).visible = false
		(crane.glare as Node3D).visible = false

func _pose(crane: Dictionary, time: float) -> void:
	# Out over the bed one axis at a time, down, close, up with the toy, lose it, and back to the
	# chute to open empty-handed, as nine goes in ten really do.
	var x := lerpf(lerpf(CLAW_HOME.x, CLAW_GRAB.x, smoothstep(4.0, 5.4, time)), CLAW_HOME.x, smoothstep(11.0, 13.4, time))
	var z := lerpf(lerpf(CLAW_HOME.y, CLAW_GRAB.y, smoothstep(5.4, 6.8, time)), CLAW_HOME.y, smoothstep(11.0, 13.4, time))
	var pod := _pod_height(time)
	var grip := smoothstep(8.8, 9.4, time) - smoothstep(13.4, 13.9, time)
	(crane.beam as Node3D).position.z = z
	(crane.carriage as Node3D).position.x = x
	(crane.head as Node3D).position.y = pod
	(crane.lead as Node3D).position.y = COIL_TOP * (1.0 - (COIL_TOP - pod - .03))
	(crane.lead as Node3D).scale.y = COIL_TOP - pod - .03
	(crane.left as Node3D).rotation.z = grip * .2
	(crane.right as Node3D).rotation.z = -grip * .2
	var lifted := 0.0
	if time > 9.4 and time < 10.4:
		lifted = pod - POD_LOW
	elif time >= 10.4 and time < 10.75:
		var fall := (time - 10.4) / .35
		lifted = (_pod_height(10.4) - POD_LOW) * (1.0 - fall * fall)
	(crane.prey as Node3D).position.y = TOY_Y + lifted

func _pod_height(time: float) -> float:
	return lerpf(POD_REST, POD_LOW, smoothstep(7.2, 8.8, time) - smoothstep(9.4, 11.0, time))

func _cabinet_frame(t: Transform3D, kind: int, sides: Array) -> void:
	# Slim posts, glass on three sides, a thin lit header and the coloured light down each edge.
	var half := CAB_W * .5
	var low := .96
	var high := GLASS_TOP
	var post := Color("#23252a")
	_kit.quad("front", t * Vector3(-half, low, -.025), t * Vector3(-half, high, -.025), t * Vector3(half, high, -.025), t * Vector3(half, low, -.025), Color.WHITE)
	for side: float in [-1.0, 1.0]:
		var x := side * (half - .004)
		_kit.quad("front", t * Vector3(x, low, -.03), t * Vector3(x, high, -.03), t * Vector3(x, high, -CAB_D), t * Vector3(x, low, -CAB_D), Color.WHITE)
		_kit.quad("front", t * Vector3(x, low, -CAB_D), t * Vector3(x, high, -CAB_D), t * Vector3(x, high, -.03), t * Vector3(x, low, -.03), Color.WHITE)
		_bar("fitting", t, side * (half - .012), (low + high) * .5, -.024, Vector3(.024, high - low, .028), post)
		_bar("fitting", t, side * (half - .012), (low + high) * .5, -CAB_D + .014, Vector3(.024, high - low, .028), post)
		for i: int in range(16):
			var u := float(i) / 16.0
			var tone := Color.from_hsv(fposmod(.88 + float(kind) * .2 + u * .3, 1.0), .8, 1.0)
			_bar("led", t, side * (half - .012), lerpf(low, high, u + .03), -.008, Vector3(.012, (high - low) / 16.0, .006), tone)
	_bar("fitting", t, 0, low - .012, -.024, Vector3(CAB_W - .004, .024, .03), post) # Stops short of the sill it meets.
	_bar("shell", t, 0, high + .1, -CAB_D * .5, Vector3(CAB_W, .2, CAB_D), Color("#e6e4e8"))
	var strip := _cell(1024, 1500.0 + float(kind) * 180.0, 1024, 170)
	_panel("crane_sign", t, -half + .01, half - .01, high + .02, high + .18, .002, strip)
	# The header wraps round whichever sides show, so the roof reads as a printed band.
	for side: float in sides:
		var flank := _flank(t, side)
		_panel("crane_sign", flank, .01, CAB_D - .01, high + .02, high + .18, .001, strip)
		_bar("plain", flank, CAB_D * .5, high + .012, .001, Vector3(CAB_D - .02, .004, .002), Color("#a8a6ae"))
	# The rear sheet, since the cross aisle to the stairs runs right past it: blind steel from the
	# base to the roof, two banks of vents, a seam, and the lead down to the floor box.
	var rear := Transform3D(t.basis * Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), t * Vector3(0, 0, -CAB_D - .001))
	_kit.quad("paint", rear * Vector3(-half, .86, 0), rear * Vector3(-half, high, 0), rear * Vector3(half, high, 0), rear * Vector3(half, .86, 0), Color("#c6c4cc"))
	_bar("plain", rear, 0, 1.5, .001, Vector3(CAB_W, .004, .002), Color("#9a98a0"))
	for y: float in [1.14, 1.76]:
		for i: int in range(5):
			_bar("plain", rear, -.32, y + float(i) * .026, .002, Vector3(.32, .009, .002), Color("#2a2a30"))
	_bar("fitting", rear, .38, 1.08, .012, Vector3(.12, .16, .024), Color("#8a8c90"))
	_kit.tube("plain", [rear * Vector3(.38, 1.0, .014), rear * Vector3(.41, .7, .018), rear * Vector3(.37, .34, .016), rear * Vector3(.42, .03, .018), rear * Vector3(.54, .012, .02)], .007, Color("#17181a"), 5)

func _pillow(at: Vector3, size: Vector3, tint: Color, axes: Basis, rings := 4, sides := 8, full := 1.0, part := "plush") -> void:
	# A stuffed shape: rounder than a box, fuller than an egg, and flat where it sits.
	var ground := -size.y * .84
	for r: int in range(rings):
		for s: int in range(sides):
			var lat0 := -PI * .5 + PI * float(r) / float(rings)
			var lat1 := -PI * .5 + PI * float(r + 1) / float(rings)
			var lon0 := -TAU * float(s) / float(sides)
			var lon1 := -TAU * float(s + 1) / float(sides)
			var a := _stuffed(lat0, lon0, size, full, ground)
			var b := _stuffed(lat1, lon0, size, full, ground)
			var c := _stuffed(lat1, lon1, size, full, ground)
			var d := _stuffed(lat0, lon1, size, full, ground)
			_kit.smooth(part, at + axes * a, at + axes * b, at + axes * c, at + axes * d, axes * _stuffed_normal(a, size), axes * _stuffed_normal(b, size), axes * _stuffed_normal(c, size), axes * _stuffed_normal(d, size), tint)

func _stuffed(lat: float, lon: float, size: Vector3, full: float, ground: float) -> Vector3:
	var band := pow(absf(cos(lat)), full)
	var y := signf(sin(lat)) * pow(absf(sin(lat)), full) * size.y
	var x := signf(cos(lon)) * pow(absf(cos(lon)), full)
	var z := signf(sin(lon)) * pow(absf(sin(lon)), full)
	return Vector3(band * x * size.x, maxf(y, ground), band * z * size.z)

func _stuffed_normal(p: Vector3, size: Vector3) -> Vector3:
	return Vector3(p.x / (size.x * size.x), p.y / (size.y * size.y), p.z / (size.z * size.z)).normalized()

func _rhythm(t: Transform3D) -> void:
	# Built as the real ones are: a black gloss tower, a marquee on two uprights, a deck proud of the
	# body at the waist, woofers in the lower cabinet, and steel underfoot where the shoes land.
	var half := .43
	var dark := Color("#0c0c10")
	var black := Color("#101014")
	var steel := Color("#9a9ea4")
	var accent := Color("#7a5cff")
	var body: Array[Vector2] = [Vector2(0, .06), Vector2(0, .86), Vector2(-.08, .98), Vector2(-.12, 1.92), Vector2(-.22, 2.02), Vector2(-.72, 2.02), Vector2(-.72, .06)]
	_extrude("shell_in", t, body, -half, half, black)
	_bar("fitting", t, 0, .03, -.36, Vector3(half * 2.0 - .04, .06, .68), Color("#2a2c30"))
	_bar("chrome", t, 0, .045, .07, Vector3(half * 2.0 - .02, .05, .14), steel)
	# The lower cabinet: two woofers behind steel rings, and the service door under them.
	for side: float in [-1.0, 1.0]:
		var at := t * Vector3(side * .2, .6, .003)
		_kit.disc("plain", at, t.basis.x, t.basis.y, .15, dark)
		_kit.disc("metal", at + t.basis.z * .002, t.basis.x, t.basis.y, .135, Color("#26272c"))
		_kit.disc("plain", at + t.basis.z * .004, t.basis.x, t.basis.y, .1, Color("#17181c"))
		_kit.disc("metal", at + t.basis.z * .006, t.basis.x, t.basis.y, .036, Color("#4a4c52"))
		var ring: Array[Vector3] = []
		for i: int in range(25):
			var a := TAU * float(i) / 24.0
			ring.append(at + t.basis.z * .006 + (t.basis.x * cos(a) + t.basis.y * sin(a)) * .146)
		_kit.tube("led", ring, .004, accent, 4)
	_bar("plain", t, 0, .24, .002, Vector3(.7, .28, .004), Color("#19191d"))
	_bar("plain", t, 0, .385, .004, Vector3(.7, .004, .004), dark)
	_bar("plain", t, 0, .095, .004, Vector3(.7, .004, .004), dark)
	for i: int in range(6):
		_bar("plain", t, -.2, .17 + float(i) * .024, .005, Vector3(.2, .009, .004), dark)
	_kit.disc("metal", t * Vector3(.28, .27, .005), t.basis.x, t.basis.y, .016, Color("#6a6c72"))
	_bar("gold", t, .16, .32, .005, Vector3(.1, .035, .002), Color(.9, .72, .16))
	_bar("room", t, .16, .15, .005, Vector3(.13, .05, .002), Color(.92, .92, .9))
	# The deck stands proud of the body, with a steel lip and five glass keys in metal frames.
	var deck: Array[Vector2] = [Vector2(.25, .76), Vector2(.25, .82), Vector2(.0, 1.0), Vector2(-.09, 1.0), Vector2(-.09, .72), Vector2(.05, .72)]
	_extrude("shell_in", t, deck, -half, half, Color("#141418"))
	_bar("chrome", t, 0, .79, .252, Vector3(half * 2.0, .05, .006), steel)
	_bar("led", t, 0, .752, .2, Vector3(half * 2.0 - .1, .006, .006), accent)
	var keys := _slope(t, Vector2(.25, .82), Vector2(.0, 1.0))
	var run := Vector2(.25, .18).length()
	_bar("plain", keys, 0, run * .5, .002, Vector3(half * 2.0 - .04, run - .02, .004), Color("#1e1f24"))
	for i: int in range(5):
		var x := -.24 + float(i) * .12
		_bar("fitting", keys, x, run * .42, .005, Vector3(.106, .15, .006), Color("#8a8e94"))
		_bar("led", keys, x, run * .42, .009, Vector3(.086, .13, .006), Color(.66, .72, .9) if i % 2 == 0 else Color(.84, .86, .94))
	_bar("led", keys, .365, run * .62, .005, Vector3(.1, .07, .004), Color("#ff8a1e"))
	_bar("plain", keys, .365, run * .62, .008, Vector3(.08, .05, .004), Color("#08080a"))
	_kit.disc("led", keys * Vector3(.365, run * .3, .006), keys.basis.x, keys.basis.y, .03, Color("#28d8e8"))
	_kit.disc("plain", keys * Vector3(.365, run * .3, .007), keys.basis.x, keys.basis.y, .024, Color("#08080a"))
	_bar("room", keys, -.36, run * .5, .005, Vector3(.09, .11, .002), Color(.9, .9, .88))
	# The screen sits deep in a black bezel, with a light wing down each side of it.
	var glass := _slope(t, Vector2(-.08, .98), Vector2(-.12, 1.92))
	var tall := Vector2(.04, .94).length()
	_bar("plain", glass, 0, tall * .5, .002, Vector3(.66, tall - .04, .006), dark)
	_panel("sign", glass, -.3, .3, .07, .85, .006, _cell(1830, 1110, 200, 260))
	for side: float in [-1.0, 1.0]:
		_bar("led", glass, side * .348, tall * .5, .004, Vector3(.012, tall - .16, .006), accent)
		_bar("shell_in", glass, side * .39, tall * .5, .004, Vector3(.07, tall - .06, .006), Color("#1c1c22"))
		for i: int in range(7):
			_bar("plain", glass, side * .39, .2 + float(i) * .09, .008, Vector3(.05, .012, .002), dark)
	# The marquee rides on two uprights, tipped down at the players, and it lights the deck.
	for side: float in [-1.0, 1.0]:
		_bar("shell_in", t, side * .38, 2.06, -.32, Vector3(.05, .12, .12), black)
	var box: Array[Vector2] = [Vector2(.0, 2.1), Vector2(-.05, 2.32), Vector2(-.5, 2.32), Vector2(-.44, 2.1)]
	_extrude("shell_in", t, box, -half, half, black)
	_panel("sign", _slope(t, Vector2(.0, 2.1), Vector2(-.05, 2.32)), -.41, .41, .006, .22, .003, _cell(1830, 1445, 200, 60))
	_bar("fitting", t, 0, 2.104, -.2, Vector3(half * 2.0 - .02, .008, .34), Color("#6a6c72"))
	# The flanks: one printed flash of the game's colour, a seam, the vents, and the warning label.
	for side: float in [-1.0, 1.0]:
		var flank := Transform3D(t.basis * Basis(Vector3.BACK * -side, Vector3.UP, Vector3.RIGHT * side), t * Vector3(side * half, 0, 0))
		var mid := side * .36
		var edge := side * (half + .002)
		_kit.beam("led", t * Vector3(edge, .86, .0), t * Vector3(edge, .98, -.08), .012, .004, t.basis.x, accent)
		_kit.beam("led", t * Vector3(edge, .98, -.08), t * Vector3(edge, 1.92, -.12), .012, .004, t.basis.x, accent)
		var flash: float = -.3
		_kit.quad("paint", flank * Vector3(mid + flash, .3, .002), flank * Vector3(mid + flash + .26, 1.84, .002), flank * Vector3(mid + flash + .42, 1.84, .002), flank * Vector3(mid + flash + .16, .3, .002), Color("#3a24a8"))
		_kit.quad("paint", flank * Vector3(mid + flash + .2, .3, .002), flank * Vector3(mid + flash + .46, 1.84, .002), flank * Vector3(mid + flash + .5, 1.84, .002), flank * Vector3(mid + flash + .24, .3, .002), Color("#b02468"))
		_bar("plain", flank, mid, .86, .003, Vector3(.7, .006, .004), dark)
		_bar("plain", flank, mid, .1, .003, Vector3(.7, .1, .004), Color("#17181b"))
		for i: int in range(6):
			_bar("plain", flank, mid + .18, 1.3 + float(i) * .024, .003, Vector3(.2, .009, .004), dark)
		_bar("gold", flank, mid - .2, 1.62, .004, Vector3(.13, .05, .002), Color(.9, .72, .16))

func _wall_posters() -> void:
	# Two big prints stacked up the solid column, as the real ones hang them, on black frames.
	var f := _front
	for row: Array in [[5.1, 7.45, _cell(1024, 0, 1024, 1200)], [7.53, 9.88, _cell(0, 0, 1024, 1200)]]:
		var low: float = row[0]
		var high: float = row[1]
		_bar("plain", f, 6.04, (low + high) * .5, .08, Vector3(2.08, high - low + .08, .1), INK)
		_panel("art", f, 5.04, 7.04, low, high, .132, row[2])

func _blade() -> void:
	# Out over the police box roof, so it catches anyone walking this way along the street.
	var f := _front
	var low := 8.9
	var high := 15.2
	var z := -.4
	var rect := _cell(1200, 600, 190, 980)
	_bar("plain", f, -.6, (low + high) * .5, z, Vector3(1.24, high - low, .14), INK)
	_panel("sign", f, -1.2, -.02, low + .02, high - .02, z + .075, rect)
	var back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), f * Vector3(0, 0, z))
	_panel("sign", back, .02, 1.2, low + .02, high - .02, .075, rect)
	for y: float in [9.6, 12.0, 14.5]:
		_bar("metal", f, .02, y, z, Vector3(.1, .12, .1), STEEL)

func _flood(at: Vector3, out: Vector3) -> void:
	# A lamp on a long arm, the way every billboard in the country is still lit.
	var lamp := at + out
	_kit.tube("metal", [at, lamp], .016, Color("#3a3c3e"), 5)
	_kit.lathe("metal", lamp + Vector3.DOWN * .12, [Vector2(.1, 0), Vector2(.085, .06), Vector2(.03, .12)], Color("#7a7c7e"), 12)
	_kit.disc("lamp", lamp + Vector3.DOWN * .11, Vector3.RIGHT, Vector3.BACK, .08, Color(1.0, .92, .76))

func _board() -> void:
	# The corner board: bigger than the building under it, and turned to face two streets.
	var f := _front
	var x_mid := (BOARD_X0 + BOARD_X1) * .5
	var y_mid := (BOARD_LOW + BOARD_HIGH) * .5
	var z_mid := (BOARD_FRONT + BOARD_BACK) * .5
	var tall := BOARD_HIGH - BOARD_LOW
	var span := BOARD_X1 - BOARD_X0
	var reach := BOARD_FRONT - BOARD_BACK
	_bar("plain", f, x_mid, y_mid, z_mid, Vector3(span, tall, reach), Color("#3a3c40"), .85, 1.0)
	_panel("board", f, BOARD_X0, BOARD_X1, BOARD_LOW, BOARD_HIGH, BOARD_FRONT + .012, _cell(0, 1210, 1560, 640))
	var side := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(BOARD_X0, 0, BOARD_BACK))
	_panel("board", side, 0, reach, BOARD_LOW, BOARD_HIGH, .012, _cell(1570, 1210, 470, 640))
	var edge := Color("#c8ccd2")
	for y: float in [BOARD_LOW, BOARD_HIGH]:
		_bar("frame", f, x_mid, y, BOARD_FRONT + .01, Vector3(span + .08, .07, .08), edge)
		_bar("frame", f, BOARD_X0 - .01, y, z_mid, Vector3(.08, .07, reach + .08), edge)
	_bar("frame", f, BOARD_X0, y_mid, BOARD_FRONT + .01, Vector3(.08, tall, .08), edge)
	_bar("frame", f, BOARD_X1, y_mid, BOARD_FRONT + .01, Vector3(.08, tall, .08), edge)
	_bar("frame", f, BOARD_X0 - .01, y_mid, BOARD_BACK, Vector3(.08, tall, .08), edge)
	# The steel it stands on, with daylight underneath, and the ribs on its bare back.
	for x: float in [.6, 2.6, 4.6, 6.6]:
		for z: float in [-.2, -2.0]:
			_bar("metal", f, x, (TOP + BOARD_LOW) * .5, z, Vector3(.12, BOARD_LOW - TOP, .12), STEELWORK)
		_kit.beam("metal", f * Vector3(x, TOP, -3.6), f * Vector3(x, BOARD_HIGH - .5, BOARD_BACK - .02), .08, .08, Vector3.UP, STEELWORK)
		_bar("metal", f, x, y_mid, BOARD_BACK - .03, Vector3(.1, tall, .06), STEELWORK)
	_bar("metal", f, 3.6, BOARD_LOW - .08, -.2, Vector3(WIDE - .3, .12, .1), STEELWORK)
	_bar("metal", f, 3.6, BOARD_LOW - .08, -2.0, Vector3(WIDE - .3, .12, .1), STEELWORK)
	for i: int in range(8):
		var x := lerpf(BOARD_X0 + .4, BOARD_X1 - .4, float(i) / 7.0)
		_flood(f * Vector3(x, BOARD_HIGH + .02, BOARD_FRONT - .06), Vector3(0, .5, 1.3))
		_panel("wash", f, x - .85, x + .85, BOARD_LOW + .02, BOARD_HIGH - .02, BOARD_FRONT + .02, Rect2(0, 1, 1, -1), Color(1.0, .9, .74) * .26)
	for i: int in range(3):
		var u := .4 + float(i) * .78
		_flood(side * Vector3(u, BOARD_HIGH + .02, -.06), Vector3(-1.3, .5, 0))
		_panel("wash", side, u - .6, u + .6, BOARD_LOW + .02, BOARD_HIGH - .02, .02, Rect2(0, 1, 1, -1), Color(1.0, .9, .74) * .26)

func _pavement() -> void:
	_a_board(_front * Vector3(5.1, 0, .85))

func _gacha(t: Transform3D, card: Rect2, tint: Color) -> void:
	# One capsule machine: coin body below, clear box of capsules above, card behind the plastic.
	_bar("plain", t, 0, .17, -.19, Vector3(.42, .34, .38), tint)
	_bar("plain", t, 0, .79, -.19, Vector3(.42, .03, .38), tint.darkened(.2))
	_bar("metal", t, 0, .345, -.19, Vector3(.42, .02, .38), Color("#c8ccd0"))
	for x: float in [-.2, .2]:
		_bar("metal", t, x, .57, -.01, Vector3(.02, .44, .02), Color("#c8ccd0"))
	_kit.disc("metal", t * Vector3(0, .22, .002), t.basis.x, t.basis.y, .07, Color("#d8dce0"))
	_bar("metal", t, 0, .22, .012, Vector3(.1, .022, .02), Color("#9a9c9e"))
	_bar("plain", t, 0, .07, .002, Vector3(.16, .08, .01), Color("#0c0c0e"))
	_kit.quad("plain", t * Vector3(-.2, .36, -.37), t * Vector3(-.2, .77, -.37), t * Vector3(.2, .77, -.37), t * Vector3(.2, .36, -.37), Color("#d8d8d0"))
	var colours: Array[Color] = [Color("#ff5aa8"), Color("#40c0f0"), Color("#ffd83c"), Color("#f4f4f0"), Color("#60d070")]
	for i: int in range(11):
		var at := Vector3(_rng.randf_range(-.15, .15), .41 + _rng.randf() * .26, _rng.randf_range(-.3, -.1))
		_ball(t * at, Vector3.ONE * .048, colours[i % colours.size()], "bottle", 7, 12)
	_panel("poster", t, -.125, .125, .39, .74, -.018, card)
	_kit.quad("front", t * Vector3(-.2, .36, -.008), t * Vector3(-.2, .78, -.008), t * Vector3(.2, .78, -.008), t * Vector3(.2, .36, -.008), Color.WHITE)
	_kit.quad("front", t * Vector3(-.2, .36, -.37), t * Vector3(-.2, .78, -.37), t * Vector3(-.2, .78, -.008), t * Vector3(-.2, .36, -.008), Color.WHITE)
	_kit.quad("front", t * Vector3(.2, .36, -.008), t * Vector3(.2, .78, -.008), t * Vector3(.2, .78, -.37), t * Vector3(.2, .36, -.37), Color.WHITE)

func _a_board(at: Vector3) -> void:
	# The folding stand, set out at opening time and never quite straight.
	var yaw := Basis(Vector3.UP, .22)
	var lean := Basis(Vector3.RIGHT, -.14)
	var t := Transform3D(yaw * lean, at)
	_bar("metal", t, 0, .46, -.012, Vector3(.54, .9, .02), Color("#d8dce0"))
	_panel("poster", t, -.25, .25, .06, .86, .002, _cell(1620, 710, 200, 300))
	var rear := Transform3D(yaw * Basis(Vector3.RIGHT, .14), at + yaw * Vector3(0, 0, -.26))
	_bar("metal", rear, 0, .46, -.012, Vector3(.54, .9, .02), Color("#8a8c8e"))
