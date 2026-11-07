extends Node3D

# Bullet impacts and the player's muzzle flare. Add one instance to the world.
# Decals and particle bursts are pooled so sustained UZI fire cannot pile up
# nodes, and nothing here casts shadows or adds lights.

const MAX_DECALS := 48
const MAX_BURSTS := 10
const DECAL_LIFETIME := 24.0
const FLARE_TIME := 0.05

enum Surface { DUST, METAL }

var _decals: Array[Decal] = []
var _decal_birth: Array[float] = []
var _decal_index := 0
var _sparks: Array[CPUParticles3D] = []
var _dust: Array[CPUParticles3D] = []
var _spark_index := 0
var _dust_index := 0
var _flare: MeshInstance3D
var _flare_material: StandardMaterial3D
var _flare_time := 0.0
var _clock := 0.0

func _ready() -> void:
	name = "CombatImpactFX"
	top_level = true
	var hole := _radial_texture([
		[0.0, Color(0.02, 0.02, 0.02, 0.96)],
		[0.32, Color(0.04, 0.035, 0.03, 0.9)],
		[0.5, Color(0.16, 0.13, 0.1, 0.35)],
		[1.0, Color(0.16, 0.13, 0.1, 0.0)],
	])
	for i in MAX_DECALS:
		var decal := Decal.new()
		decal.texture_albedo = hole
		decal.size = Vector3(0.1, 0.12, 0.1)
		decal.cull_mask = 1
		decal.distance_fade_enabled = true
		decal.distance_fade_begin = 22.0
		decal.distance_fade_length = 8.0
		decal.visible = false
		add_child(decal)
		_decals.append(decal)
		_decal_birth.append(-1000.0)
	var spark_material := _particle_material(true)
	var dust_material := _particle_material(false)
	for i in MAX_BURSTS:
		_sparks.append(_make_burst(spark_material, true))
		_dust.append(_make_burst(dust_material, false))
	_build_flare()

func spawn_impact(position: Vector3, normal: Vector3, surface: Surface = Surface.DUST, leave_mark: bool = true) -> void:
	if not is_finite(position.x) or normal.length_squared() < 0.0001:
		return
	var basis := _basis_from_normal(normal)
	if surface == Surface.METAL:
		_emit(_sparks[_spark_index], position, basis)
		_spark_index = (_spark_index + 1) % MAX_BURSTS
	else:
		_emit(_dust[_dust_index], position, basis)
		_dust_index = (_dust_index + 1) % MAX_BURSTS
		# A few hot fragments sell the hit even on soft surfaces.
		_emit(_sparks[_spark_index], position, basis, 4)
		_spark_index = (_spark_index + 1) % MAX_BURSTS
	if leave_mark:
		var decal := _decals[_decal_index]
		decal.global_transform = Transform3D(basis.rotated(basis.y, randf() * TAU), position)
		var scale_jitter := randf_range(0.8, 1.2)
		decal.size = Vector3(0.1 * scale_jitter, 0.12, 0.1 * scale_jitter)
		decal.modulate = Color(1, 1, 1, 1)
		decal.visible = true
		_decal_birth[_decal_index] = _clock
		_decal_index = (_decal_index + 1) % MAX_DECALS

func show_muzzle_flare(position: Vector3, direction: Vector3) -> void:
	if not is_instance_valid(_flare):
		return
	_flare.global_position = position + direction.normalized() * 0.06
	var size := randf_range(0.16, 0.24)
	_flare.scale = Vector3(size, size, size)
	_flare.rotation = Vector3.ZERO
	_flare_material.albedo_color = Color(1.0, randf_range(0.72, 0.84), 0.45, 1.0)
	_flare.visible = true
	_flare_time = FLARE_TIME

func _process(delta: float) -> void:
	_clock += delta
	if _flare_time > 0.0:
		_flare_time -= delta
		if _flare_time <= 0.0:
			_flare.visible = false
	for i in MAX_DECALS:
		var decal := _decals[i]
		if not decal.visible:
			continue
		var age := _clock - _decal_birth[i]
		if age > DECAL_LIFETIME:
			decal.visible = false
		elif age > DECAL_LIFETIME - 3.0:
			decal.modulate.a = (DECAL_LIFETIME - age) / 3.0

func _emit(burst: CPUParticles3D, position: Vector3, basis: Basis, amount: int = -1) -> void:
	burst.global_transform = Transform3D(basis, position + basis.y * 0.02)
	if amount > 0:
		burst.amount = amount
	else:
		burst.amount = int(burst.get_meta("full_amount"))
	burst.restart()

func _make_burst(material: StandardMaterial3D, hot: bool) -> CPUParticles3D:
	var burst := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = material
	burst.mesh = quad
	burst.one_shot = true
	burst.emitting = false
	burst.explosiveness = 1.0
	burst.local_coords = false
	burst.direction = Vector3.UP
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ramp := Gradient.new()
	if hot:
		burst.amount = 14
		burst.lifetime = 0.32
		burst.spread = 42.0
		burst.initial_velocity_min = 3.0
		burst.initial_velocity_max = 7.5
		burst.gravity = Vector3(0, -9.8, 0)
		burst.scale_amount_min = 0.018
		burst.scale_amount_max = 0.04
		ramp.set_color(0, Color(1.0, 0.9, 0.6, 1.0))
		ramp.set_color(1, Color(1.0, 0.35, 0.08, 0.0))
	else:
		burst.amount = 9
		burst.lifetime = 0.75
		burst.spread = 30.0
		burst.initial_velocity_min = 0.7
		burst.initial_velocity_max = 2.0
		burst.gravity = Vector3(0, -1.6, 0)
		burst.damping_min = 1.5
		burst.damping_max = 2.5
		burst.scale_amount_min = 0.06
		burst.scale_amount_max = 0.14
		ramp.set_color(0, Color(0.55, 0.5, 0.42, 0.4))
		ramp.set_color(1, Color(0.5, 0.46, 0.4, 0.0))
	burst.color_ramp = ramp
	burst.set_meta("full_amount", burst.amount)
	add_child(burst)
	return burst

func _particle_material(hot: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = _radial_texture([
		[0.0, Color(1, 1, 1, 1)],
		[0.45 if hot else 0.3, Color(1, 1, 1, 0.75 if hot else 0.5)],
		[1.0, Color(1, 1, 1, 0)],
	])
	if hot:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return material

func _build_flare() -> void:
	_flare_material = StandardMaterial3D.new()
	_flare_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flare_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_flare_material.billboard_keep_scale = true
	_flare_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flare_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flare_material.albedo_texture = _radial_texture([
		[0.0, Color(1, 1, 1, 1)],
		[0.18, Color(1, 0.9, 0.6, 0.9)],
		[0.5, Color(1, 0.55, 0.15, 0.3)],
		[1.0, Color(1, 0.4, 0.1, 0)],
	])
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_flare = MeshInstance3D.new()
	_flare.name = "MuzzleFlare"
	_flare.mesh = quad
	_flare.material_override = _flare_material
	_flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flare.visible = false
	add_child(_flare)

static func _radial_texture(stops: Array) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array()
	gradient.colors = PackedColorArray()
	for stop: Array in stops:
		gradient.add_point(float(stop[0]), stop[1] as Color)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture

static func _basis_from_normal(normal: Vector3) -> Basis:
	# Decals and bursts project along local Y, so Y follows the surface normal.
	var y := normal.normalized()
	var helper := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := helper.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)
