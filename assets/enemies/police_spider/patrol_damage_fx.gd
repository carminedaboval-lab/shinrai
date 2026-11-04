extends Node3D
## Visible wear from body damage: sparks below 60%, smoke and failing lights
## below 30%, a burst on destruction, then a smoking wreck. Lives under the
## lightbar so it stays with the chassis, including the ragdoll corpse.
const SPARK_HEALTH := 60.0
const SMOKE_HEALTH := 30.0
const WRECK_SMOKE_SECONDS := 12.0

static var _spark_material: StandardMaterial3D
static var _smoke_material: StandardMaterial3D

var lights: Node3D
var _sparks: CPUParticles3D
var _smoke: CPUParticles3D
var _spark_wait := 0.0
var _sparking := false
var _wreck_time := -1.0

func bind(health: Node, police_lights: Node3D) -> void:
	lights=police_lights
	health.health_changed.connect(_on_health)
	health.destroyed.connect(_on_destroyed)
	health.leg_destroyed.connect(func(_leg: String) -> void: _burst(10))
	set_process(false)

func _on_health(total: float) -> void:
	if total<=0.0: return
	if total<SPARK_HEALTH and not _sparking:
		_sparking=true;_spark_wait=.1
		set_process(true)
	if total<SMOKE_HEALTH:
		_ensure_smoke().emitting=true
		lights.damage_flicker=true

func _on_destroyed() -> void:
	_burst(26)
	_ensure_smoke().emitting=true
	_ensure_smoke().amount=20
	lights.damage_flicker=false
	_sparking=false;_wreck_time=WRECK_SMOKE_SECONDS
	set_process(true)

func _process(delta: float) -> void:
	if _wreck_time>=0.0:
		_wreck_time-=delta
		if _wreck_time<=0.0:
			_ensure_smoke().emitting=false;set_process(false)
		return
	_spark_wait-=delta
	if _spark_wait<=0.0:
		_spark_wait=randf_range(.9,3.2)
		_burst(7)

func _burst(amount: int) -> void:
	var sparks:=_ensure_sparks()
	sparks.amount=amount
	sparks.restart()

func _ensure_sparks() -> CPUParticles3D:
	if _sparks!=null: return _sparks
	if _spark_material==null: _spark_material=_particle_material(true)
	_sparks=CPUParticles3D.new();_sparks.name="DamageSparks"
	var quad:=QuadMesh.new();quad.material=_spark_material;_sparks.mesh=quad
	_sparks.one_shot=true;_sparks.emitting=false;_sparks.explosiveness=1.0;_sparks.local_coords=false
	_sparks.lifetime=.42;_sparks.direction=Vector3.UP;_sparks.spread=60.0
	_sparks.initial_velocity_min=1.6;_sparks.initial_velocity_max=4.2
	_sparks.gravity=Vector3(0,-9.8,0);_sparks.scale_amount_min=.016;_sparks.scale_amount_max=.034
	var ramp:=Gradient.new();ramp.set_color(0,Color(1,.92,.62,1));ramp.set_color(1,Color(1,.32,.06,0))
	_sparks.color_ramp=ramp
	_sparks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparks.position=Vector3(0,-.08,0)
	add_child(_sparks)
	return _sparks

func _ensure_smoke() -> CPUParticles3D:
	if _smoke!=null: return _smoke
	if _smoke_material==null: _smoke_material=_particle_material(false)
	_smoke=CPUParticles3D.new();_smoke.name="DamageSmoke"
	var quad:=QuadMesh.new();quad.material=_smoke_material;_smoke.mesh=quad
	_smoke.amount=12;_smoke.lifetime=2.2;_smoke.local_coords=false;_smoke.emitting=false
	_smoke.direction=Vector3.UP;_smoke.spread=16.0
	_smoke.initial_velocity_min=.45;_smoke.initial_velocity_max=.9
	_smoke.gravity=Vector3(.12,.3,0);_smoke.damping_min=.3;_smoke.damping_max=.6
	_smoke.scale_amount_min=.3;_smoke.scale_amount_max=.62
	var ramp:=Gradient.new();ramp.set_color(0,Color(.12,.12,.13,.5));ramp.set_color(1,Color(.3,.3,.32,0))
	_smoke.color_ramp=ramp
	_smoke.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_smoke)
	return _smoke

static func _particle_material(hot: bool) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale=true
	material.vertex_color_use_as_albedo=true
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	if hot: material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	var gradient:=Gradient.new()
	gradient.set_color(0,Color(1,1,1,1));gradient.set_color(1,Color(1,1,1,0))
	var soft:=GradientTexture2D.new();soft.gradient=gradient
	soft.fill=GradientTexture2D.FILL_RADIAL
	soft.fill_from=Vector2(.5,.5);soft.fill_to=Vector2(1,.5);soft.width=48;soft.height=48
	material.albedo_texture=soft
	return material
