extends Node3D
## Local electrical arcing and an occasional short burst of sparks at a wrecked
## leg's knee. It follows that joint as the leg hangs and kicks.
var actor: Node3D
var leg := ""
var particles: CPUParticles3D
var arc: ImmediateMesh
var flash: OmniLight3D
var t := 0.0
# Irregular short bursts with long quiet gaps, not a steady strobe.
const BURST_SECONDS := .16
const GAP_MIN := 2.2
const GAP_MAX := 4.8
var next_burst := 0.0
var burst_until := -1.0
var knee_bone := -1

func _ready() -> void:
	particles=CPUParticles3D.new();particles.amount=6;particles.lifetime=.32
	particles.explosiveness=.9;particles.direction=Vector3.UP;particles.spread=60
	particles.initial_velocity_min=.8;particles.initial_velocity_max=1.7
	particles.gravity=Vector3(0,-6.0,0);particles.scale_amount_min=.5;particles.scale_amount_max=.9
	particles.emitting=false
	var spark:=BoxMesh.new();spark.size=Vector3(.006,.028,.006)
	particles.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY,true)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(.35,.85,1);material.emission_enabled=true;material.emission=Color(.18,.7,1);material.emission_energy_multiplier=2.2
	var spark_material:=material.duplicate() as StandardMaterial3D
	spark_material.albedo_color=Color(1,.55,.1);spark_material.emission=Color(1,.28,.025)
	spark.material=spark_material;particles.mesh=spark;add_child(particles)
	arc=ImmediateMesh.new();var mesh:=MeshInstance3D.new();mesh.mesh=arc;mesh.material_override=material;add_child(mesh)
	flash=OmniLight3D.new();flash.name="Flash";flash.light_color=Color(.2,.7,1);flash.omni_range=.5;flash.shadow_enabled=false;flash.light_energy=0.0;add_child(flash)
	next_burst=randf_range(.15,.6)
	var visual: Node=actor.get("visual") if is_instance_valid(actor) else null
	if visual!=null and visual.get("skeleton")!=null: knee_bone=(visual.skeleton as Skeleton3D).find_bone(leg+"_Lower")

func _follow_knee() -> void:
	if knee_bone<0 or not is_instance_valid(actor): return
	var skeleton: Skeleton3D=actor.visual.skeleton
	global_position=skeleton.global_transform*skeleton.get_bone_global_pose(knee_bone).origin

func _process(delta: float) -> void:
	t+=delta
	_follow_knee()
	if t>=next_burst:
		burst_until=t+BURST_SECONDS;next_burst=t+randf_range(GAP_MIN,GAP_MAX)
		particles.restart();particles.emitting=true
	var pulse:=t<burst_until
	if not pulse: particles.emitting=false
	flash.light_energy=.5 if pulse else 0.0
	arc.clear_surfaces()
	if not pulse: return
	arc.surface_begin(Mesh.PRIMITIVE_LINES)
	for branch in 2:
		var previous:=Vector3.ZERO
		for i in range(1,5):
			var point:=Vector3(sin(t*89+float(i)*3+branch)*.035,float(i)*.02,cos(t*73+float(i)*2+branch)*.035)
			arc.surface_add_vertex(previous);arc.surface_add_vertex(point);previous=point
	arc.surface_end()
