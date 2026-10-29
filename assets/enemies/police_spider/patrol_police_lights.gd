extends Node3D
## A small roof lightbar follows the animated chassis, including wall traversal.
var visual: Node3D
var state := "PATROL"
var clock := 0.0
var materials: Array[StandardMaterial3D] = []
var lamps: Array[OmniLight3D] = []
var strengths := Vector2.ZERO
var leg_markers: Dictionary = {}
const LEG_COLORS := {"FL":0,"FR":1,"RL":1,"RR":0}
# Measured source LED centres and outward normals, converted to Godot Y-up.
const LEG_MOUNTS := {
	"FL":[Vector3(-.5081,.2220,.6101),Vector3(-.4473,-.4227,.7882)],
	"FR":[Vector3(.5556,.2043,.6116),Vector3(.6726,-.1818,.7173)],
	"RL":[Vector3(-.8132,.2247,-.6077),Vector3(.3098,-.7412,.5956)],
	"RR":[Vector3(.8305,.2256,-.5068),Vector3(.4641,.1409,.8745)]}
const COLORS := [Color(1,.025,.015),Color(.025,.18,1)]

func _ready() -> void:
	var housing:=MeshInstance3D.new();var base:=BoxMesh.new();base.size=Vector3(.36,.023,.115);housing.mesh=base
	var dark:=StandardMaterial3D.new();dark.albedo_color=Color(.035,.045,.055);dark.roughness=.42;dark.metallic=.65
	housing.material_override=dark;add_child(housing)
	for i in 2:
		var lens:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.15,.042,.088);lens.mesh=box
		lens.position=Vector3(-.083 if i==0 else .083,.031,0)
		var material:=StandardMaterial3D.new();material.albedo_color=COLORS[i]*.15
		material.emission_enabled=true;material.emission=COLORS[i];material.emission_energy_multiplier=0
		material.roughness=.22;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		lens.material_override=material;materials.append(material);add_child(lens)
		var lamp:=OmniLight3D.new();lamp.position=lens.position+Vector3.UP*.055
		lamp.light_color=COLORS[i];lamp.light_energy=0;lamp.omni_range=2.2
		lamp.omni_attenuation=1.6;lamp.shadow_enabled=false;lamps.append(lamp);add_child(lamp)
	for leg: String in LEG_COLORS:
		var marker:=Node3D.new();marker.name=leg+"RunningLight";add_child(marker)
		var surround:=MeshInstance3D.new();var rim:=CylinderMesh.new()
		rim.top_radius=.026;rim.bottom_radius=.026;rim.height=.008;surround.mesh=rim
		surround.material_override=dark;marker.add_child(surround)
		var lens:=MeshInstance3D.new();var dome:=SphereMesh.new();dome.radius=.020;dome.height=.040
		lens.mesh=dome;lens.scale.y=.35;lens.position.y=.006
		var color: Color=COLORS[LEG_COLORS[leg]]
		var material:=StandardMaterial3D.new();material.albedo_color=color*.32
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled=true;material.emission=color;material.emission_energy_multiplier=.35
		lens.material_override=material;marker.add_child(lens)
		var lamp:=OmniLight3D.new();lamp.position.y=.025;lamp.light_color=color
		lamp.light_energy=.0035;lamp.omni_range=.14;lamp.omni_attenuation=2.0
		lamp.shadow_enabled=false;marker.add_child(lamp)
		leg_markers[leg]={"node":marker,"material":material,"lamp":lamp}

func set_alert_state(next: String) -> void:
	if state==next: return
	state=next;clock=0
	_update_flash()

func _process(delta: float) -> void:
	clock+=delta
	if is_instance_valid(visual) and visual.skeleton!=null:
		var skeleton: Skeleton3D=visual.skeleton
		var bone:=skeleton.find_bone("Body")
		var motion: Transform3D=skeleton.get_bone_global_pose(bone)*skeleton.get_bone_global_rest(bone).affine_inverse()
		# Measured roof maximum is 0.7474 m under this footprint; base rests above it.
		global_transform=skeleton.global_transform*motion*Transform3D(Basis.IDENTITY,Vector3(-.04,.759,-.06))
		for leg: String in leg_markers:
			var lower:=skeleton.find_bone(leg+"_Lower")
			var leg_motion:=skeleton.get_bone_global_pose(lower)*skeleton.get_bone_global_rest(lower).affine_inverse()
			var center: Vector3=LEG_MOUNTS[leg][0]
			var normal: Vector3=(LEG_MOUNTS[leg][1] as Vector3).normalized()
			var mount:=Transform3D(Basis(Quaternion(Vector3.UP,normal)),center+normal*.006)
			leg_markers[leg].node.global_transform=skeleton.global_transform*leg_motion*mount
	_update_flash()

func _update_flash() -> void:
	strengths=Vector2.ZERO
	if state in ["NOTICE","IDENTIFY","SEARCH","COMBAT_ENTER","COMBAT"]:
		var combat:=state in ["COMBAT_ENTER","COMBAT"]
		var period:=.8 if combat else 1.4
		var phase:=fposmod(clock,period)/period
		# Two short red pulses, then two blue; slower single pulses when assessing.
		if combat:
			strengths.x=1.0 if phase<.10 or (phase>=.17 and phase<.27) else 0.0
			strengths.y=1.0 if (phase>=.5 and phase<.60) or (phase>=.67 and phase<.77) else 0.0
		else:
			strengths.x=1.0 if phase<.18 else 0.0
			strengths.y=1.0 if phase>=.5 and phase<.68 else 0.0
	for i in materials.size():
		materials[i].albedo_color=COLORS[i]*lerpf(.10,1.0,strengths[i])
		materials[i].emission_energy_multiplier=strengths[i]*4.0
		lamps[i].light_energy=strengths[i]*1.6
	# Steady low-output markers stay on independently of the alert flash cycle.
	for leg: String in leg_markers:
		var powered:=state!="DISABLED"
		var color: Color=COLORS[LEG_COLORS[leg]]
		leg_markers[leg].material.albedo_color=color*(.32 if powered else .06)
		leg_markers[leg].material.emission_energy_multiplier=.35 if powered else 0.0
		leg_markers[leg].lamp.light_energy=.0035 if powered else 0.0
