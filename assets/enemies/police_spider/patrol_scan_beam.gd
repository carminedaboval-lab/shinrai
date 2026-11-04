extends Node3D
## Searchlight on the drone's lightbar. It shows what the drone is doing: a slow
## sweep on patrol scans, a wider white search, and an amber lock while the drone
## identifies a target. Off in combat, where the stun emitter's aim beam takes over.
const LENGTH := 11.0
const RADIUS := 1.5
const WHITE := Color(.78,.88,1.0)
const AMBER := Color(1.0,.62,.16)
const BEAM_SHADER := preload("res://shaders/patrol_scan_beam.gdshader")

var actor: CharacterBody3D
var brain: Node
var area_scan := false
var clock := 0.0
var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _lamp: SpotLight3D
var _mode := ""

func _ready() -> void:
	clock=randf()*TAU
	var cone:=CylinderMesh.new()
	cone.top_radius=.03;cone.bottom_radius=RADIUS;cone.height=LENGTH
	cone.radial_segments=16;cone.rings=1;cone.cap_top=false;cone.cap_bottom=false
	_material=ShaderMaterial.new();_material.shader=BEAM_SHADER
	_mesh=MeshInstance3D.new();_mesh.name="ScanCone";_mesh.mesh=cone;_mesh.material_override=_material
	_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.visibility_range_end=90.0;_mesh.visibility_range_end_margin=10.0
	_mesh.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# Cylinder top (the apex) stays at this node; the open end points along +Z.
	_mesh.transform=Transform3D(Basis(Vector3.RIGHT,-PI*.5),Vector3(0,0,LENGTH*.5))
	add_child(_mesh)
	_lamp=SpotLight3D.new();_lamp.name="ScanLamp"
	_lamp.spot_range=LENGTH*1.4;_lamp.spot_angle=atan2(RADIUS,LENGTH)*57.3;_lamp.light_energy=2.2
	_lamp.shadow_enabled=false;_lamp.light_specular=.2
	_lamp.distance_fade_enabled=true;_lamp.distance_fade_begin=45.0;_lamp.distance_fade_length=15.0
	# SpotLight3D shines along -Z; turn it to match the cone.
	_lamp.rotation.y=PI
	add_child(_lamp)
	_apply("")

func _wanted_mode() -> String:
	if not is_instance_valid(actor) or actor.dead: return ""
	# Awareness is attached by the pack after this node exists.
	if not is_instance_valid(brain): brain=actor.get_node_or_null("Awareness")
	var state: String=str(brain.state) if is_instance_valid(brain) else "PATROL"
	if state in ["NOTICE","IDENTIFY"]: return "lock"
	if state=="SEARCH": return "search"
	if state=="PATROL" and area_scan: return "sweep"
	return ""

func _apply(mode: String) -> void:
	_mode=mode
	var on:=not mode.is_empty()
	_mesh.visible=on;_lamp.visible=on
	if not on: return
	var color: Color=AMBER if mode=="lock" else WHITE
	_material.set_shader_parameter("beam_color",color)
	_material.set_shader_parameter("strength",.6 if mode=="lock" else .38)
	_lamp.light_color=color

func _process(delta: float) -> void:
	var mode:=_wanted_mode()
	if mode!=_mode: _apply(mode)
	if mode.is_empty(): return
	clock+=delta
	if mode=="lock":
		var point: Vector3=brain.last_known
		if point.is_finite() and global_position.distance_squared_to(point)>.25:
			look_at(point+Vector3.UP*.9,Vector3.UP,true)
	else:
		rotation=Vector3(.16,sin(clock*(1.0 if mode=="sweep" else 1.7))*.7,0)
