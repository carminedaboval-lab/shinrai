extends Node3D
## Local electrical arcing and short bursts of physical spark particles.
var particles: CPUParticles3D
var arc: ImmediateMesh
var t := 0.0

func _ready() -> void:
	particles=CPUParticles3D.new();particles.amount=22;particles.lifetime=.38
	particles.explosiveness=.85;particles.direction=Vector3.UP;particles.spread=75
	particles.initial_velocity_min=1.0;particles.initial_velocity_max=2.2
	particles.gravity=Vector3(0,-3.0,0);particles.scale_amount_min=.55;particles.scale_amount_max=1.1
	var spark:=BoxMesh.new();spark.size=Vector3(.007,.035,.007)
	particles.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY,true)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(.35,.85,1);material.emission_enabled=true;material.emission=Color(.18,.7,1);material.emission_energy_multiplier=3
	var spark_material:=material.duplicate() as StandardMaterial3D
	spark_material.albedo_color=Color(1,.55,.1);spark_material.emission=Color(1,.28,.025)
	spark.material=spark_material;particles.mesh=spark;add_child(particles)
	arc=ImmediateMesh.new();var mesh:=MeshInstance3D.new();mesh.mesh=arc;mesh.material_override=material;add_child(mesh)
	var light:=OmniLight3D.new();light.name="Flash";light.light_color=Color(.2,.7,1);light.omni_range=.65;light.shadow_enabled=false;add_child(light)

func _process(delta: float) -> void:
	t+=delta
	var pulse:=fposmod(t,1.35)<.32
	particles.emitting=pulse
	get_node("Flash").light_energy=.8 if pulse else 0.0
	arc.clear_surfaces()
	if not pulse: return
	arc.surface_begin(Mesh.PRIMITIVE_LINES)
	for branch in 3:
		var previous:=Vector3.ZERO
		for i in range(1,6):
			var point:=Vector3(sin(t*89+float(i)*3+branch)*.05,float(i)*.025,cos(t*73+float(i)*2+branch)*.05)
			arc.surface_add_vertex(previous);arc.surface_add_vertex(point);previous=point
	arc.surface_end()
