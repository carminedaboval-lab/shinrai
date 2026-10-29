extends SubViewportContainer
## Inventory-only view of the same supplied full body used by the player.
## No controller, shared animation, original mesh or material is modified.

const MODEL_PATH := "res://assets/characters/urban_explorer_2050/urban_explorer_2050_body.glb"
const Catalog = preload("res://scripts/extraction_weapon_catalog.gd")
# Wrist orientations measured from the existing UZI holding pose.
const GRASP := {
	"Left":{"frame":Basis(Vector3(0.2225492,-0.5583190,-0.7992195),Vector3(-0.9659967,-0.0156133,-0.2580825),Vector3(0.1316139,0.8294794,-0.5428090))},
	"Right":{"frame":Basis(Vector3(-0.2420954,-0.9548583,-0.1721496),Vector3(-0.9131085,0.2842134,-0.2923280),Vector3(0.3280590,0.0864200,-0.9406959))},
}

# Per-weapon glove fits; original scene anchors and source meshes stay unchanged.
const HAND_FITS := {
	"kite":{
		"Left":{"rotation":Basis.IDENTITY,"offset":Vector3.ZERO,"scale":1.219512195122},
		"Right":{"rotation":Basis(Vector3(0.8824171510,0.3928774280,-0.2588190451),Vector3(-0.4067366431,0.9135454576,0.0000000000),Vector3(0.2364429630,0.1052711896,0.9659258263)),"offset":Vector3(0.0374266564,0.0387223519,-0.0141582214),"scale":1.2195121951219512},
	},
	"shigure":{
		"Left":{"rotation":Basis.IDENTITY,"offset":Vector3.ZERO,"scale":1.219512195122},
		"Right":{"rotation":Basis(Vector3(0.8824171510,0.3928774280,-0.2588190451),Vector3(-0.4067366431,0.9135454576,0.0000000000),Vector3(0.2364429630,0.1052711896,0.9659258263)),"offset":Vector3(0.0466616564,0.0547223519,-0.0141582214),"scale":1.2195121951219512},
	},
	"uzi":{
		"Left":{"rotation":Basis.IDENTITY,"offset":Vector3.ZERO,"scale":1.219512195122},
		"Right":{"rotation":Basis(Vector3(1.00000000,0.00000000,-0.00000000),Vector3(0.00000000,1.00000000,0.00000000),Vector3(0.00000000,0.00000000,1.00000000)),"offset":Vector3(0.00000000,0.00000000,0.00000000),"scale":1.219512},
	},
}

# Bone poses in the original gun frame, applied only to cached inventory gloves.
const HAND_POSES := {
	"shigure":{
		"DEF-f_index.01.R_0591":Transform3D(Basis(Vector3(0.1353578828,0.7479297367,0.6387251738),Vector3(-0.5739544588,0.5763372167,-0.5789157466),Vector3(-0.8152573593,-0.2903243072,0.5194208631)),Vector3(0.0378746408,-0.0360960684,-0.0160325256)),
		"DEF-f_index.02.R_0572":Transform3D(Basis(Vector3(0.2677720569,0.8301631505,0.4866642787),Vector3(-0.8671909399,0.4243818612,-0.2659914036),Vector3(-0.4390201854,-0.3323355589,0.8350935701)),Vector3(0.0079367937,-0.0060339020,-0.0462291601)),
		"DEF-f_index.03.R_0573":Transform3D(Basis(Vector3(0.4093894781,0.9125861944,0.0698702931),Vector3(-0.8892270638,0.4110203988,-0.2398286872),Vector3(-0.2434217979,0.0473612969,0.9576950613)),Vector3(-0.0169448035,0.0061425540,-0.0538610888)),
		"DEF-f_index.03.R_end_01011":Transform3D(Basis(Vector3(0.4093894781,0.9125861944,0.0698702931),Vector3(-0.8892270638,0.4110203988,-0.2398286872),Vector3(-0.2434217979,0.0473612969,0.9576950613)),Vector3(-0.0314524073,0.0128482891,-0.0577738572)),
		"DEF-f_middle.01.R_0624":Transform3D(Basis(Vector3(-0.0962062996,0.9838091843,0.0534149063),Vector3(-0.9942426406,-0.1076826206,-0.0720706945),Vector3(-0.0703418187,-0.0645017531,1.0033677611)),Vector3(0.0307214202,-0.0558581966,-0.0229007510)),
		"DEF-f_middle.02.R_0625":Transform3D(Basis(Vector3(-0.1666234689,0.9736042139,0.1005206798),Vector3(-0.1756253398,-0.1378233807,0.9828019210),Vector3(0.9672315798,0.1634193297,0.1933840633)),Vector3(-0.0182892594,-0.0611664628,-0.0264534189)),
		"DEF-f_middle.03.R_0626":Transform3D(Basis(Vector3(0.3536800525,0.9169433913,0.1517171517),Vector3(0.5331737732,-0.3183223061,0.7824948723),Vector3(0.7786147007,-0.1858323857,-0.6112152250)),Vector3(-0.0238064893,-0.0654961633,0.0044210486)),
		"DEF-f_middle.03.R_end_01024":Transform3D(Basis(Vector3(0.3536800525,0.9169433913,0.1517171517),Vector3(0.5331737732,-0.3183223061,0.7824948723),Vector3(0.7786147007,-0.1858323857,-0.6112152250)),Vector3(-0.0134313140,-0.0716904848,0.0196478319)),
		"DEF-f_ring.01.R_0643":Transform3D(Basis(Vector3(-0.0534571155,0.9853960268,-0.0931218074),Vector3(-0.9996024593,-0.0716403148,-0.0099831831),Vector3(-0.0199620524,0.0880689388,1.0030083128)),Vector3(0.0268339839,-0.0763857639,-0.0235842447)),
		"DEF-f_ring.02.R_0644":Transform3D(Basis(Vector3(-0.2089882665,0.9652856705,0.1004199171),Vector3(-0.2327065593,-0.1604372553,0.9672507839),Vector3(0.9459462160,0.1945847471,0.2597513266)),Vector3(-0.0119578154,-0.0791660300,-0.0239716263)),
		"DEF-f_ring.03.R_0645":Transform3D(Basis(Vector3(0.4619577777,0.8723840949,0.1359936809),Vector3(0.5269367553,-0.3780364515,0.7565905447),Vector3(0.7243374624,-0.2707940646,-0.6459125286)),Vector3(-0.0191270346,-0.0841084891,0.0058271523)),
		"DEF-f_ring.03.R_end_01032":Transform3D(Basis(Vector3(0.4619577777,0.8723840949,0.1359936809),Vector3(0.5269367553,-0.3780364515,0.7565905447),Vector3(0.7243374624,-0.2707940646,-0.6459125286)),Vector3(-0.0103990591,-0.0903701379,0.0183590239)),
		"DEF-f_pinky.01.R_0662":Transform3D(Basis(Vector3(0.4329191613,0.8346975649,-0.3348413154),Vector3(-0.8290540229,0.1995493137,-0.5188856462),Vector3(-0.3711830507,0.4948125709,0.7911301766)),Vector3(0.0310237184,-0.0980130548,-0.0139191863)),
		"DEF-f_pinky.02.R_0663":Transform3D(Basis(Vector3(-0.1045436159,0.8482939748,-0.5060203893),Vector3(-0.8904816480,0.1306937887,0.4433427794),Vector3(0.4427085053,0.5024645717,0.7480069134)),Vector3(0.0059375942,-0.0919750122,-0.0296198887)),
		"DEF-f_pinky.03.R_0664":Transform3D(Basis(Vector3(-0.4202217770,0.8928407036,-0.0568562689),Vector3(-0.3562459809,-0.1023138378,0.9350122301),Vector3(0.8377542881,0.4271053781,0.3581796467)),Vector3(-0.0082457052,-0.0898932000,-0.0225586296)),
		"DEF-f_pinky.03.R_end_01040":Transform3D(Basis(Vector3(-0.4202217770,0.8928407036,-0.0568562689),Vector3(-0.3562459809,-0.1023138378,0.9350122301),Vector3(0.8377542881,0.4271053781,0.3581796467)),Vector3(-0.0135121043,-0.0914057097,-0.0087363049)),
		"DEF-thumb.01.R_0595":Transform3D(Basis(Vector3(0.3229074693,0.0724750699,0.9521424404),Vector3(-0.9019716036,-0.2727850696,0.3248745285),Vector3(0.2674697279,-0.9591309734,-0.0087273386)),Vector3(0.0780710891,-0.0380194167,0.0173633523)),
		"DEF-thumb.02.R_0596":Transform3D(Basis(Vector3(0.0574805490,-0.6357661015,0.7783539448),Vector3(-0.9965523178,-0.0441793057,0.0491678711),Vector3(-0.0113181616,-0.7629471039,-0.6388379702)),Vector3(0.0488788795,-0.0468480169,0.0278778531)),
		"DEF-thumb.03.R_0597":Transform3D(Basis(Vector3(0.4321555296,-0.7761403150,0.4549307745),Vector3(-0.7778679595,-0.5788447666,-0.2579507141),Vector3(0.4566362731,-0.2215213483,-0.8606822579)),Vector3(0.0162330202,-0.0482951352,0.0294885566)),
		"DEF-thumb.03.R_end_01012":Transform3D(Basis(Vector3(0.4321555296,-0.7761403150,0.4549307745),Vector3(-0.7778679595,-0.5788447666,-0.2579507141),Vector3(0.4566362731,-0.2215213483,-0.8606822579)),Vector3(0.0008358624,-0.0597528178,0.0243826671)),
	},
	"kite":{
		"DEF-f_index.01.R_0591":Transform3D(Basis(Vector3(0.0886386066,0.7705216010,0.6197823448),Vector3(-0.5796795477,0.5365443627,-0.6105927600),Vector3(-0.8174010419,-0.3074512470,0.5060237798)),Vector3(0.0378746408,-0.0360960684,-0.0160325256)),
		"DEF-f_index.02.R_0572":Transform3D(Basis(Vector3(0.2624257093,0.8307581051,0.4885576413),Vector3(-0.8924384745,0.3987355617,-0.2177958636),Vector3(-0.3879391063,-0.3608206022,0.8484566345)),Vector3(0.0076381681,-0.0081095240,-0.0478814551)),
		"DEF-f_index.03.R_0573":Transform3D(Basis(Vector3(0.4093874443,0.9125891044,0.0698441968),Vector3(-0.8891339776,0.4109978391,-0.2402121660),Vector3(-0.2437522366,0.0475433474,0.9576019903)),Vector3(-0.0179678389,0.0033310847,-0.0541305484)),
		"DEF-f_index.03.R_end_01011":Transform3D(Basis(Vector3(0.4093874443,0.9125891044,0.0698441968),Vector3(-0.8891339776,0.4109978391,-0.2402121660),Vector3(-0.2437522366,0.0475433474,0.9576019903)),Vector3(-0.0324739240,0.0100364517,-0.0580495732)),
		"DEF-f_middle.01.R_0624":Transform3D(Basis(Vector3(-0.4829998742,0.8547223757,0.1270830334),Vector3(-0.8676538710,-0.5008665166,-0.0402200562),Vector3(0.0273177585,-0.1366034098,0.9982227006)),Vector3(0.0307214202,-0.0558581966,-0.0229007510)),
		"DEF-f_middle.02.R_0625":Transform3D(Basis(Vector3(-0.1758805631,0.9768442798,0.0247837331),Vector3(-0.2904514242,-0.0829658050,0.9615060091),Vector3(0.9379321541,0.1791488157,0.2963598798)),Vector3(-0.0120490865,-0.0805482522,-0.0248833657)),
		"DEF-f_middle.03.R_0626":Transform3D(Basis(Vector3(0.4701052223,0.8582682600,0.1768319269),Vector3(0.5462844693,-0.4291670562,0.7178373803),Vector3(0.7051731540,-0.2317221779,-0.6807306620)),Vector3(-0.0211735481,-0.0831546162,0.0053220964)),
		"DEF-f_middle.03.R_end_01024":Transform3D(Basis(Vector3(0.4701052223,0.8582682600,0.1768319269),Vector3(0.5462844693,-0.4291670562,0.7178373803),Vector3(0.7051731540,-0.2317221779,-0.6807306620)),Vector3(-0.0105432481,-0.0915058962,0.0192906917)),
		"DEF-f_ring.01.R_0643":Transform3D(Basis(Vector3(-0.2306238402,0.9627991203,-0.0486329329),Vector3(-0.9707481102,-0.2491102488,0.0054097899),Vector3(-0.0091343563,0.0428661358,1.0061110053)),Vector3(0.0268339839,-0.0763857639,-0.0235842447)),
		"DEF-f_ring.02.R_0644":Transform3D(Basis(Vector3(-0.2229742869,0.9559590028,0.1481942421),Vector3(-0.3771278940,-0.2375899665,0.9037655083),Vector3(0.8951176147,0.1612936794,0.4158088791)),Vector3(-0.0108380386,-0.0860531457,-0.0233742724)),
		"DEF-f_ring.03.R_0645":Transform3D(Basis(Vector3(0.5277666462,0.8310527839,0.1541652242),Vector3(0.5201342208,-0.4447985409,0.7243050499),Vector3(0.6835295958,-0.2954944399,-0.6787249127)),Vector3(-0.0224565475,-0.0933725031,0.0044686814)),
		"DEF-f_ring.03.R_end_01032":Transform3D(Basis(Vector3(0.5277666462,0.8310527839,0.1541652242),Vector3(0.5201342208,-0.4447985409,0.7243050499),Vector3(0.6835295958,-0.2954944399,-0.6787249127)),Vector3(-0.0138412465,-0.1007399731,0.0164657886)),
		"DEF-f_pinky.01.R_0662":Transform3D(Basis(Vector3(0.4958561719,0.7908734941,-0.3534168994),Vector3(-0.8325855379,0.2890532597,-0.4686601651),Vector3(-0.2733810951,0.5195823335,0.8147393874)),Vector3(0.0310237184,-0.0980130548,-0.0139191863)),
		"DEF-f_pinky.02.R_0663":Transform3D(Basis(Vector3(-0.1878918313,0.8893178831,-0.4004984797),Vector3(-0.9314383178,-0.0535382978,0.3689817917),Vector3(0.3058965094,0.4469591272,0.8453583105)),Vector3(0.0058307350,-0.0892667374,-0.0281001300)),
		"DEF-f_pinky.03.R_0664":Transform3D(Basis(Vector3(-0.4134895695,0.8922662336,-0.0993521193),Vector3(-0.4359586391,-0.0958515875,0.9013211019),Vector3(0.8036704640,0.4299208275,0.4264103398)),Vector3(-0.0090049206,-0.0901192942,-0.0222232451)),
		"DEF-f_pinky.03.R_end_01040":Transform3D(Basis(Vector3(-0.4134895695,0.8922662336,-0.0993521193),Vector3(-0.4359586391,-0.0958515875,0.9013211019),Vector3(0.8036704640,0.4299208275,0.4264103398)),Vector3(-0.0154497153,-0.0915362722,-0.0088989778)),
		"DEF-thumb.01.R_0595":Transform3D(Basis(Vector3(0.3160151221,0.0708676112,0.9545728472),Vector3(-0.9067573721,-0.2648231183,0.3180687213),Vector3(0.2594575680,-0.9613527830,-0.0055716237)),Vector3(0.0780710891,-0.0380194167,0.0173633523)),
		"DEF-thumb.02.R_0596":Transform3D(Basis(Vector3(0.0627273783,-0.6356082496,0.7780776579),Vector3(-0.9961865641,-0.0488969063,0.0520310936),Vector3(-0.0095529553,-0.7628927959,-0.6389316545)),Vector3(0.0487239893,-0.0465903293,0.0276575839)),
		"DEF-thumb.03.R_0597":Transform3D(Basis(Vector3(0.4283269877,-0.7787582578,0.4540768298),Vector3(-0.7828540985,-0.5735815704,-0.2546017275),Vector3(0.4519419042,-0.2255011880,-0.8621253228)),Vector3(0.0160901110,-0.0481919905,0.0293620831)),
		"DEF-thumb.03.R_end_01012":Transform3D(Basis(Vector3(0.4283269877,-0.7787582578,0.4540768298),Vector3(-0.7828540985,-0.5735815704,-0.2546017275),Vector3(0.4519419042,-0.2255011880,-0.8621253228)),Vector3(0.0005942574,-0.0595454931,0.0243224836)),
	},
}
# END_HAND_POSES

var weapon_id := ""
var optic_id := ""
var weapon_model: Node3D
var weapon_available := false
var pose_modifier: SkeletonModifier3D
var torso_bone := -1
var torso_reference := Transform3D.IDENTITY
var weapon_rest := Transform3D.IDENTITY
var arms: Dictionary = {}
var grip_errors: Dictionary = {}
static var uzi_mesh_cache: Array[Dictionary] = []
static var supplied_hands: Dictionary = {}
static var supplied_wrists: Dictionary = {}
static var sleeve_mesh_cache: ArrayMesh
var body_arms: MeshInstance3D
var original_arm_mesh: Mesh
const HAND_SCALE := 0.82
const ORIGINAL_GRIPS := {"Right":Vector3(0.065,-0.075,0),"Left":Vector3(-0.105,-0.035,0.005)}
const CUFFS := {
	"Right":{"center":Vector3(0.137716,-0.088323,0.009699),"axis":Vector3(-0.799404,0.587707,0.124713)},
	"Left":{"center":Vector3(-0.009069,-0.055948,0.061988),"axis":Vector3(-0.633728,0.658042,-0.406656)}
}
const SLEEVES := {
	"Right":{"center":Vector3(0.004635,0.282519,0.002343),"major":Vector3(-0.673777,0,-0.738935)},
	"Left":{"center":Vector3(0.001632,0.287429,-0.000025),"major":Vector3(0.668619,0,-0.743605)}
}

class InventoryPose extends SkeletonModifier3D:
	var preview: Control
	func _process_modification_with_delta(_delta: float) -> void:
		if is_instance_valid(preview): preview._apply_equipped_idle()
var viewport: SubViewport
var model: Node3D
var camera: Camera3D
var animator: AnimationPlayer
var available := false
var idle_clip := ""
var yaw := 0.12
var distance := 2.72
var dragging := false
var skeleton: Skeleton3D
var backpack_id := ""
var backpack_attachment: BoneAttachment3D
const BACKPACKS := {
	"backpack_regular":"res://assets/shinrai/gear/backpacks/regular.glb",
	"backpack_mountain":"res://assets/shinrai/gear/backpacks/mountain.glb"
}

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = "Drag to rotate character · scroll to zoom · double-click to reset"
	viewport = SubViewport.new()
	viewport.name = "CharacterStudio"
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	var studio := Node3D.new()
	viewport.add_child(studio)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9c7d5")
	environment.ambient_light_energy = 0.60
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	studio.add_child(world)
	_light(studio, Vector3(1.5,2.7,2.2), Color("ffe5cc"), 3.5)
	_light(studio, Vector3(-2.0,1.5,1.0), Color("c4dcec"), 2.2)
	_light(studio, Vector3(0.6,2.0,-1.8), Color("eff2dd"), 3.0)
	camera = Camera3D.new()
	camera.fov = 36.0
	camera.near = 0.05
	camera.far = 12.0
	studio.add_child(camera)
	camera.make_current()
	if ResourceLoader.exists(MODEL_PATH):
		var source := load(MODEL_PATH) as PackedScene
		if source != null:
			model = source.instantiate() as Node3D
			studio.add_child(model)
			for node: Node in model.find_children("*", "Skeleton3D", true, false):
				skeleton = node as Skeleton3D
				break
			for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
				mesh.visible = true
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				mesh.extra_cull_margin = 2.0
			for node: Node in model.find_children("*", "AnimationPlayer", true, false):
				animator = node as AnimationPlayer
				break
			if animator != null:
				for clip: StringName in animator.get_animation_list():
					if str(clip) == "Idle_02" or str(clip).ends_with("/Idle_02"):
						var idle := animator.get_animation(clip).duplicate(true) as Animation
						idle.loop_mode = Animation.LOOP_LINEAR
						var library := AnimationLibrary.new()
						library.add_animation("idle", idle)
						animator.add_animation_library("inventory", library)
						idle_clip = "inventory/idle"
						animator.play(idle_clip)
						animator.advance(0.0)
						break
			available = not idle_clip.is_empty()
			_prepare_equipped_idle()
	_update_camera()
	resized.connect(_resize)
	visibility_changed.connect(_visibility)
	_resize()
	_visibility()
	if not available:
		var label := Label.new()
		label.text = "Character preview unavailable"
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		add_child(label)

func _light(parent: Node, at: Vector3, tint: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = tint
	light.light_energy = energy
	light.omni_range = 6.0
	parent.add_child(light)

func set_backpack(id: String) -> void:
	if backpack_id == id: return
	backpack_id = id
	if is_instance_valid(backpack_attachment):
		backpack_attachment.get_parent().remove_child(backpack_attachment)
		backpack_attachment.queue_free()
	backpack_attachment = null
	if skeleton == null or not BACKPACKS.has(id) or not ResourceLoader.exists(BACKPACKS[id]): return
	var bone := -1
	for index: int in range(skeleton.get_bone_count()):
		if skeleton.get_bone_name(index).ends_with("Spine2"): bone = index
	if bone < 0: return
	var pack := (load(BACKPACKS[id]) as PackedScene).instantiate() as Node3D
	pack.name = "EquippedBackpack"
	backpack_attachment = BoneAttachment3D.new()
	backpack_attachment.bone_name = skeleton.get_bone_name(bone)
	skeleton.add_child(backpack_attachment)
	backpack_attachment.add_child(pack)
	# Keep the supplied measured 0.45 / 0.65 m pack at its original unit scale.
	# Fit behind the torso, then follow the same animated spine as the body.
	var at := Vector3(0.0, 0.98, -0.27) if id == "backpack_regular" else Vector3(0.0, 0.83, -0.36)
	var desired := model.global_transform * Transform3D(Basis(Vector3.UP, PI), at)
	var bone_world := skeleton.global_transform * skeleton.get_bone_global_pose(bone)
	pack.transform = bone_world.affine_inverse() * desired

func _resize() -> void:
	# Render no larger than 900 px; the preview is inactive outside inventory.
	stretch_shrink = maxi(1, ceili(maxf(size.x, size.y) / 900.0))

func _visibility() -> void:
	if viewport == null: return
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	if animator != null: animator.active = is_visible_in_tree()
	if pose_modifier != null: pose_modifier.active = is_visible_in_tree()
	dragging = false

func reset_view() -> void:
	yaw = 0.12
	distance = 2.72
	_update_camera()

func _update_camera() -> void:
	if camera == null: return
	var focus := Vector3(0.0, 0.88, 0.0)
	camera.position = focus + Vector3(sin(yaw), 0.025, cos(yaw)) * distance
	camera.look_at(focus)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed and event.double_click: reset_view()
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			distance = clampf(distance + (-0.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.15), 2.68, 3.8)
			_update_camera()
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.009
		_update_camera()
		accept_event()

func _bone(suffix: String) -> int:
	for i: int in range(skeleton.get_bone_count()):
		if skeleton.get_bone_name(i).ends_with(suffix): return i
	return -1

func _relax_posture() -> void:
	# Remove the raised clavicles from the source unarmed idle. Keep its small
	# weight shifts and breathing, while the upper torso stays comfortably upright.
	var spine := _bone("Spine")
	var pose := skeleton.get_bone_global_pose(spine)
	pose.basis = pose.basis.slerp(skeleton.get_bone_global_rest(spine).basis,0.65)
	skeleton.set_bone_global_pose(spine,pose)
	for side: String in ["Left","Right"]:
		var shoulder := _bone(side+"Shoulder")
		skeleton.set_bone_pose_rotation(shoulder,skeleton.get_bone_rest(shoulder).basis.get_rotation_quaternion())

func _prepare_equipped_idle() -> void:
	if skeleton == null: return
	torso_bone = _bone("Spine2")
	if torso_bone < 0: return
	_relax_posture()
	torso_reference = skeleton.get_bone_global_pose(torso_bone)
	for side: String in ["Left", "Right"]:
		var upper := _bone(side + "Arm")
		var lower := _bone(side + "ForeArm")
		var hand := _bone(side + "Hand")
		var hand_rest := skeleton.get_bone_global_rest(hand)
		var index := skeleton.get_bone_global_rest(_bone(side+"HandIndex1")).origin
		var middle := skeleton.get_bone_global_rest(_bone(side+"HandMiddle1")).origin
		var pinky := skeleton.get_bone_global_rest(_bone(side+"HandRing1")).origin
		var middle_at := (index+middle)*0.5
		var forward := (middle_at-hand_rest.origin).normalized()
		var across := (pinky-index).normalized()
		across = (across-forward*across.dot(forward)).normalized()
		var frame := Basis(across,forward,across.cross(forward)).orthonormalized()
		arms[side] = {"upper":upper,"lower":lower,"hand":hand,
			"palm_frame":hand_rest.basis.inverse()*frame,
			"palm_contact":hand_rest.affine_inverse()*(hand_rest.origin+(middle_at-hand_rest.origin)*0.65)}
	_prepare_sleeves()
	pose_modifier = InventoryPose.new()
	pose_modifier.preview = self
	skeleton.add_child(pose_modifier)

func set_loadout(id: String, optic: String) -> void:
	var compatible_optic := optic if Catalog.compatible(id,optic) else ""
	if weapon_id == id and optic_id == compatible_optic and weapon_available: return
	weapon_id = id
	optic_id = compatible_optic
	weapon_available = false
	if is_instance_valid(weapon_model):
		weapon_model.get_parent().remove_child(weapon_model)
		weapon_model.queue_free()
	weapon_model = null
	if body_arms != null: body_arms.mesh = original_arm_mesh
	if not Catalog.available(id) or skeleton == null: return
	if id == "uzi":
		weapon_model = _uzi_geometry()
	else:
		var path: String = str(Catalog.WEAPONS[id].scene).replace("_viewmodel.tscn", "_weapon.tscn")
		if ResourceLoader.exists(path): weapon_model = (load(path) as PackedScene).instantiate() as Node3D
	if weapon_model == null: return
	model.add_child(weapon_model)
	weapon_model.name = "EquippedWeapon"
	if not optic_id.is_empty() and weapon_model.has_node("OpticSocket") and ResourceLoader.exists(Catalog.OPTICS[optic_id].scene):
		var optic_model := (load(Catalog.OPTICS[optic_id].scene) as PackedScene).instantiate() as Node3D
		weapon_model.get_node("OpticSocket").add_child(optic_model)
		optic_model.name = "EquippedOptic"
	if not weapon_model.has_node("GripRight") or not weapon_model.has_node("GripLeft"):
		weapon_model.queue_free(); weapon_model = null; return
	_add_supplied_hands()
	# Across the lower chest, muzzle down. Preserve every supplied model's scale.
	var turn := Basis.from_euler(Vector3(-0.05,deg_to_rad(165.0),deg_to_rad(17.0)))
	var right_grip: Vector3 = weapon_model.get_node("GripRight").position
	weapon_rest = Transform3D(turn,Vector3(-0.12,1.075,0.14)-turn*right_grip)
	weapon_available = true
	_apply_equipped_idle()
	_fit_sleeve_cuffs()

func _uzi_geometry() -> Node3D:
	if uzi_mesh_cache.is_empty():
		var source := (load(Catalog.WEAPONS.uzi.scene) as PackedScene).instantiate() as Node3D
		viewport.add_child(source)
		var source_rig: Skeleton3D
		for rig: Skeleton3D in source.find_children("*", "Skeleton3D", true, false): source_rig = rig; break
		for ap: AnimationPlayer in source.find_children("*", "AnimationPlayer", true, false):
			for clip: String in ap.get_animation_list():
				if clip.ends_with("|Idle"):
					ap.play(clip);ap.advance(0.0);ap.pause();break
		if source_rig == null: source.queue_free(); return null
		var body := source_rig.find_bone("UZI Body_0725")
		if body < 0: source.queue_free(); return null
		# Freeze only the supplied gun surfaces in memory. Keep the source asset,
		# first-person arms, original rig and gameplay animations completely intact.
		var gun_frame := (source_rig.global_transform * source_rig.get_bone_global_pose(body)).orthonormalized()
		var to_weapon := Transform3D(Basis(Vector3.UP,-PI*0.5),Vector3.ZERO) * gun_frame.affine_inverse()
		for side: String in ["Left","Right"]:
			var hand := source_rig.find_bone("DEF-hand.L_0458" if side=="Left" else "DEF-hand.R_0583")
			supplied_wrists[side] = to_weapon * source_rig.to_global(source_rig.get_bone_global_pose(hand).origin)
		for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
			if str(mesh.name) == "Object_13":
				_cache_hand_variants(mesh,source_rig,to_weapon)
			if str(mesh.name) not in ["Object_1084", "Object_1085"]: continue
			var frozen := _bake_supplied_pose(mesh,source_rig)
			if frozen == null: continue
			for surface: int in range(frozen.get_surface_count()):
				frozen.surface_set_material(surface,mesh.get_active_material(surface))
			uzi_mesh_cache.append({"mesh":frozen,"transform":to_weapon*mesh.global_transform})
		source.get_parent().remove_child(source);source.queue_free()
	if uzi_mesh_cache.is_empty(): return null
	var gun := Node3D.new()
	for row: Dictionary in uzi_mesh_cache:
		var mesh := MeshInstance3D.new()
		mesh.mesh = row.mesh
		mesh.transform = row.transform
		gun.add_child(mesh)
	for row: Array in [["GripRight",Vector3(0.065,-0.075,0.0)],["GripLeft",Vector3(-0.105,-0.035,0.005)]]:
		var socket := Marker3D.new(); socket.name = row[0]; socket.position = row[1]; gun.add_child(socket)
	return gun

func _apply_equipped_idle() -> void:
	if skeleton == null or torso_bone < 0 or arms.size() != 2: return
	_relax_posture()
	var torso_delta := skeleton.get_bone_global_pose(torso_bone) * torso_reference.affine_inverse()
	if weapon_available and is_instance_valid(weapon_model):
		weapon_model.global_transform = skeleton.global_transform * torso_delta * skeleton.global_transform.affine_inverse() * model.global_transform * weapon_rest
	for side: String in arms:
		var arm: Dictionary = arms[side]
		var hand_pose := skeleton.get_bone_global_pose(arm.hand)
		var target := Vector3(-0.31 if side == "Right" else 0.31,0.86,0.03)
		var desired_basis := hand_pose.basis
		var contact_target := Vector3.ZERO
		if weapon_available and is_instance_valid(weapon_model):
			var fit := _hand_fit(side)
			var cuff_axis:Vector3=CUFFS[side].axis
			desired_basis = skeleton.global_basis.inverse() * weapon_model.global_basis * fit.basis.orthonormalized() * (GRASP[side].frame as Basis) * (arm.palm_frame as Basis).inverse()
			# Fit the sleeve to the measured opening of each bent glove, not its palm.
			contact_target = weapon_model.to_global(fit*((CUFFS[side].center as Vector3)+cuff_axis*0.006))
			target = skeleton.to_local(contact_target)
		_solve_idle_arm(arm,target,desired_basis,side)
		if weapon_available:
			var wrist := skeleton.to_global(skeleton.get_bone_global_pose(arm.hand).origin)
			grip_errors[side] = wrist.distance_to(contact_target)

func _solve_idle_arm(arm: Dictionary, target: Vector3, hand_basis: Basis, side: String) -> void:
	var upper := skeleton.get_bone_global_pose(arm.upper)
	var lower := skeleton.get_bone_global_pose(arm.lower)
	var hand := skeleton.get_bone_global_pose(arm.hand)
	var a := upper.origin.distance_to(lower.origin)
	var b := lower.origin.distance_to(hand.origin)
	var direction := (target-upper.origin).normalized()
	var reach := clampf(upper.origin.distance_to(target),absf(a-b)+0.001,a+b-0.001)
	var pole := Vector3(-0.30 if side == "Right" else 0.30,0.99,-0.01)-upper.origin
	var bend := (pole-direction*pole.dot(direction)).normalized()
	var along := (a*a-b*b+reach*reach)/(2.0*reach)
	var elbow := upper.origin+direction*along+bend*sqrt(maxf(0,a*a-along*along))
	var wrist := upper.origin+direction*reach
	var upper_rest := skeleton.get_bone_global_rest(arm.upper).basis
	var lower_rest := skeleton.get_bone_global_rest(arm.lower).basis
	var turn_upper := Basis(Quaternion(upper_rest.y.normalized(),(elbow-upper.origin).normalized()))
	var turn_lower := Basis(Quaternion(lower_rest.y.normalized(),(wrist-elbow).normalized()))
	skeleton.set_bone_global_pose(arm.upper,Transform3D(turn_upper*upper_rest,upper.origin))
	skeleton.set_bone_global_pose(arm.lower,Transform3D(turn_lower*lower_rest,elbow))
	skeleton.set_bone_global_pose(arm.hand,Transform3D(hand_basis,wrist))

func _hand_weights(mesh: MeshInstance3D, rig: Skeleton3D, arrays: Array, side: String = "") -> PackedFloat32Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var result := PackedFloat32Array();result.resize(vertices.size())
	var bindings: Array[bool] = []
	for bind: int in range(mesh.skin.get_bind_count()):
		var label := str(mesh.skin.get_bind_name(bind))
		if label.is_empty(): label=rig.get_bone_name(mesh.skin.get_bind_bone(bind))
		bindings.append(label.contains("Hand") if side.is_empty() else (label.begins_with("DEF-") and label.contains(".L" if side=="Left" else ".R")))
	var count := joints.size()/vertices.size()
	for vertex: int in range(vertices.size()):
		for influence: int in range(count):
			var offset := vertex*count+influence
			if bindings[joints[offset]]:result[vertex]+=weights[offset]
	return result

func _prepare_sleeves() -> void:
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if str(mesh.name)=="Body_Arms":body_arms=mesh;break
	if body_arms==null:return
	original_arm_mesh=body_arms.mesh
	if sleeve_mesh_cache != null:return
	sleeve_mesh_cache=ArrayMesh.new()
	for surface: int in range(original_arm_mesh.get_surface_count()):
		var arrays := original_arm_mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var cut := PackedByteArray();cut.resize(vertices.size())
		for side: String in ["Left","Right"]:
			var to_hand := skeleton.get_bone_global_rest(_bone(side+"Hand")).affine_inverse()*body_arms.transform
			for vertex: int in range(vertices.size()):
				var point := to_hand*vertices[vertex]
				if point.y>0.0 and absf(point.x)<0.11 and absf(point.z)<0.10:cut[vertex]=1
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for i: int in range(0,indices.size(),3):
			if cut[indices[i]] or cut[indices[i+1]] or cut[indices[i+2]]:continue
			kept.append_array(indices.slice(i,i+3))
		arrays[Mesh.ARRAY_INDEX]=kept
		_tailor_sleeve_arrays(arrays)
		sleeve_mesh_cache.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},original_arm_mesh.surface_get_format(surface))
		sleeve_mesh_cache.surface_set_material(surface,body_arms.get_active_material(surface))

func _tailor_sleeve_arrays(arrays: Array) -> void:
	# Taper the last 45 mm of the jacket to the supplied glove opening. Work in
	# rest space so the original skin weights and breathing motion remain valid.
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
	for side:String in ["Left","Right"]:
		var to_arm:=skeleton.get_bone_global_rest(arms[side].lower).affine_inverse()*body_arms.transform
		var from_arm:=to_arm.affine_inverse()
		var center:Vector3=SLEEVES[side].center
		var major:Vector3=SLEEVES[side].major
		var minor:=Vector3(-major.z,0,major.x)
		for i:int in range(vertices.size()):
			var point:Vector3=to_arm*vertices[i]
			var delta:=point-center
			if delta.y < -0.045 or delta.y > 0.025 or Vector2(delta.x,delta.z).length()>0.10:continue
			var u:=clampf((delta.y+0.045)/0.045,0.0,1.0)
			var blend:=u*u*(3.0-2.0*u)
			var derivative:=6.0*u*(1.0-u)/0.045
			var a:=delta.dot(major)
			var b:=delta.dot(minor)
			var f:=1.0-0.35*blend
			var g:=1.0-0.18*blend
			vertices[i]=from_arm*(center+Vector3.UP*delta.y+major*a*f+minor*b*g)
			var jacobian:=Basis(major*major.x*f+minor*minor.x*g,Vector3.UP-major*a*0.35*derivative-minor*b*0.18*derivative,major*major.z*f+minor*minor.z*g)
			normals[i]=(from_arm.basis*jacobian.inverse().transposed()*to_arm.basis*normals[i]).normalized()
			if not tangents.is_empty():
				var tangent:=Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
				tangent=(from_arm.basis*jacobian*to_arm.basis*tangent).normalized()
				tangents[i*4]=tangent.x;tangents[i*4+1]=tangent.y;tangents[i*4+2]=tangent.z
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TANGENT]=tangents

func _cache_hand_variants(mesh: MeshInstance3D, rig: Skeleton3D, to_weapon: Transform3D) -> void:
	var original: Array[Transform3D] = []
	for index: int in range(rig.get_bone_count()): original.append(rig.get_bone_pose(index))
	var to_rig := (to_weapon*rig.global_transform).affine_inverse()
	for id: String in HAND_FITS:
		for index: int in range(original.size()): rig.set_bone_pose(index,original[index])
		var poses: Dictionary = HAND_POSES.get(id,{})
		# Bone order is parent-first; each absolute target is in the source gun frame.
		for index: int in range(rig.get_bone_count()):
			var bone_name := rig.get_bone_name(index)
			if poses.has(bone_name): rig.set_bone_global_pose(index,to_rig*(poses[bone_name] as Transform3D))
		supplied_hands[id] = {"Left":[],"Right":[]}
		_cache_hands(mesh,rig,to_weapon*mesh.global_transform,id)
	for index: int in range(original.size()): rig.set_bone_pose(index,original[index])

func _cache_hands(mesh: MeshInstance3D, rig: Skeleton3D, to_gun: Transform3D, id: String) -> void:
	var baked := _bake_supplied_pose(mesh,rig)
	for side: String in ["Left","Right"]:
		var hand := ArrayMesh.new()
		for surface: int in range(mesh.mesh.get_surface_count()):
			var original := mesh.mesh.surface_get_arrays(surface)
			var weights := _hand_weights(mesh,rig,original,side)
			var arrays := baked.surface_get_arrays(surface)
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var kept := PackedInt32Array()
			for i: int in range(0,indices.size(),3):
				if (weights[indices[i]]+weights[indices[i+1]]+weights[indices[i+2]])/3.0<0.01:continue
				kept.append_array(indices.slice(i,i+3))
			if kept.is_empty():continue
			arrays[Mesh.ARRAY_INDEX]=kept
			hand.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},baked.surface_get_format(surface))
			hand.surface_set_material(hand.get_surface_count()-1,mesh.get_active_material(surface))
		if hand.get_surface_count()>0:supplied_hands[id][side].append({"mesh":hand,"transform":to_gun})

func _add_supplied_hands() -> void:
	if uzi_mesh_cache.is_empty():
		var cache_source := _uzi_geometry()
		if cache_source != null:cache_source.free()
	var profile := _hand_profile(weapon_id)
	if not supplied_hands.has(profile):return
	if supplied_hands[profile].Left.is_empty() or supplied_hands[profile].Right.is_empty():return
	if body_arms != null:body_arms.mesh=sleeve_mesh_cache
	for side: String in ["Left","Right"]:
		var fit := _hand_fit(side)
		for row: Dictionary in supplied_hands[profile][side]:
			var mesh:=MeshInstance3D.new()
			mesh.name="SuppliedGrip"+side
			mesh.mesh=row.mesh
			mesh.transform=fit*(row.transform as Transform3D)
			weapon_model.add_child(mesh)
static func _hand_profile(id: String) -> String:
	if HAND_FITS.has(id):return id
	var profile := str(Catalog.weapon(id).get("presentation_profile","kite"))
	return profile if HAND_FITS.has(profile) else "kite"

func _hand_fit(side: String) -> Transform3D:
	var grip: Node3D=weapon_model.get_node("Grip"+side)
	var record: Dictionary=HAND_FITS[_hand_profile(weapon_id)][side]
	var basis: Basis=(record.rotation as Basis).scaled(Vector3.ONE*HAND_SCALE*float(record.scale))
	return Transform3D(basis,grip.position+(record.offset as Vector3)-basis*(ORIGINAL_GRIPS[side] as Vector3))

func _fit_sleeve_cuffs() -> void:
	# The first-person gloves have bent cuff openings. Adapt only their short
	# cuffs to this jacket's relaxed forearms; keep the palm and finger fit intact.
	for side: String in ["Left","Right"]:
		var glove:=weapon_model.get_node_or_null("SuppliedGrip"+side) as MeshInstance3D
		if glove==null or glove.mesh==null:continue
		var fit:=_hand_fit(side)
		var center:Vector3=fit*(CUFFS[side].center as Vector3)
		var axis:Vector3=(fit.basis*(CUFFS[side].axis as Vector3)).normalized()
		var forearm:=skeleton.get_bone_global_pose(arms[side].lower)
		var normal:Vector3=(weapon_model.global_basis.inverse()*skeleton.global_basis*forearm.basis.y).normalized()
		# Measured sleeve edge in the forearm's rest space. The cut is behind the
		# wrist joint; overlap it slightly so breathing cannot reveal an open seam.
		var sleeve_center:Vector3=SLEEVES[side].center
		var target:Vector3=weapon_model.to_local(skeleton.to_global(forearm*sleeve_center))-normal*0.005
		var turn:=Quaternion(axis,normal)
		var rotation:=Basis(turn)
		var to_local:=glove.transform.affine_inverse()
		var fitted:=ArrayMesh.new()
		for surface:int in range(glove.mesh.get_surface_count()):
			var arrays:=glove.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
			for i:int in range(vertices.size()):
				var point:Vector3=glove.transform*vertices[i]
				var depth:float=(point-center).dot(axis)
				var amount:float=1.0-smoothstep(0.004,0.060,depth)
				if amount<=0.0 or point.distance_to(center)>0.075:continue
				var offset:Vector3=target+rotation*(point-center)-point
				vertices[i]=to_local*(point+offset*amount)
				var u:=clampf((depth-0.004)/0.056,0.0,1.0)
				var gradient:=axis*(-6.0*u*(1.0-u)/0.056)
				var bend:=Basis(Vector3.RIGHT.lerp(rotation.x,amount)+offset*gradient.x,Vector3.UP.lerp(rotation.y,amount)+offset*gradient.y,Vector3.BACK.lerp(rotation.z,amount)+offset*gradient.z)
				normals[i]=(to_local.basis*bend.inverse().transposed()*glove.transform.basis*normals[i]).normalized()
				if not tangents.is_empty():
					var tangent:=Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
					tangent=(to_local.basis*bend*glove.transform.basis*tangent).normalized()
					tangents[i*4]=tangent.x;tangents[i*4+1]=tangent.y;tangents[i*4+2]=tangent.z
			arrays[Mesh.ARRAY_VERTEX]=vertices
			arrays[Mesh.ARRAY_NORMAL]=normals
			arrays[Mesh.ARRAY_TANGENT]=tangents
			fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},glove.mesh.surface_get_format(surface))
			fitted.surface_set_material(surface,glove.mesh.surface_get_material(surface))
		glove.mesh=fitted

func _bake_supplied_pose(mesh: MeshInstance3D, rig: Skeleton3D) -> ArrayMesh:
	# Skin directly from the current bone poses. GPU baking in the same frame as
	# AnimationPlayer.advance() can still contain the previous renderer pose.
	var matrices: Array[Transform3D] = []
	var to_mesh := mesh.global_transform.affine_inverse()*rig.global_transform
	for bind: int in range(mesh.skin.get_bind_count()):
		var bone := rig.find_bone(mesh.skin.get_bind_name(bind))
		if bone < 0: bone = mesh.skin.get_bind_bone(bind)
		matrices.append(to_mesh*rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var baked := ArrayMesh.new()
	for surface: int in range(mesh.mesh.get_surface_count()):
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
		var joints: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		var count := joints.size()/positions.size()
		for i: int in range(positions.size()):
			var point:=Vector3.ZERO
			var normal:=Vector3.ZERO
			var tangent:=Vector3.ZERO
			for k: int in range(count):
				var offset:=i*count+k
				var weight:=weights[offset]
				if weight<=0.0:continue
				var matrix:=matrices[joints[offset]]
				point+=(matrix*positions[i])*weight
				normal+=(matrix.basis*normals[i])*weight
				if not tangents.is_empty():
					tangent+=(matrix.basis*Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2]))*weight
			positions[i]=point
			normals[i]=normal.normalized()
			if not tangents.is_empty():
				tangent=tangent.normalized()
				tangents[i*4]=tangent.x;tangents[i*4+1]=tangent.y;tangents[i*4+2]=tangent.z
		arrays[Mesh.ARRAY_VERTEX]=positions
		arrays[Mesh.ARRAY_NORMAL]=normals
		arrays[Mesh.ARRAY_TANGENT]=tangents
		arrays[Mesh.ARRAY_BONES]=null
		arrays[Mesh.ARRAY_WEIGHTS]=null
		var flags:int=mesh.mesh.surface_get_format(surface)&~(Mesh.ARRAY_FORMAT_BONES|Mesh.ARRAY_FORMAT_WEIGHTS|Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags)
		baked.surface_set_material(surface,mesh.get_active_material(surface))
	return baked
