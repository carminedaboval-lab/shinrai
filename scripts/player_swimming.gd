extends RefCounted

var terrain: Node3D
var submerged := false
var swimming := false
var underwater_environment: Environment
var previous_environment: Environment
var previous_far := 1000.0

func update_visuals(player: CharacterBody3D) -> void:
	if not is_instance_valid(terrain):
		terrain = player.get_tree().get_first_node_in_group("midori_terrain")
	var below: bool = is_instance_valid(terrain) and terrain.installed and terrain.water_at(Vector2(player.global_position.x,player.global_position.z)) and player.camera.global_position.y < terrain.WATER_Y - (0.025 if not submerged else -0.025)
	if below == submerged: return
	submerged = below
	player.is_underwater = below
	if below:
		previous_environment = player.camera.environment
		previous_far = player.camera.far
		var source: Environment = player.get_viewport().find_world_3d().environment
		underwater_environment = source.duplicate() if source != null else Environment.new()
		underwater_environment.background_mode = Environment.BG_COLOR
		underwater_environment.background_color = Color(0.035,0.075,0.055)
		underwater_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		underwater_environment.ambient_light_color = Color(0.50,0.60,0.42)
		underwater_environment.ambient_light_energy = 0.8
		underwater_environment.volumetric_fog_enabled = false
		underwater_environment.fog_enabled = true
		underwater_environment.fog_density = 0.23
		underwater_environment.fog_light_color = Color(0.14,0.22,0.13)
		underwater_environment.fog_light_energy = 0.8
		underwater_environment.fog_sky_affect = 1.0
		underwater_environment.ssr_enabled = false
		player.camera.environment = underwater_environment
		player.camera.far = 45.0
	else:
		player.camera.environment = previous_environment
		player.camera.far = previous_far

func advance(player: CharacterBody3D, delta: float, input: Vector2, fast: bool, down: bool, up: bool) -> bool:
	update_visuals(player)
	var p := Vector2(player.global_position.x,player.global_position.z)
	var in_water: bool = is_instance_valid(terrain) and terrain.installed and terrain.water_at(p)
	var depth: float = terrain.WATER_Y-player.global_position.y if in_water else 0.0
	var active: bool = in_water and depth > (0.60 if swimming else 0.85)
	if not active:
		if swimming:
			player.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
			player.velocity.y = maxf(0.0,player.velocity.y)
			player.weapon.show()
			if is_instance_valid(player.uzi_viewmodel): player.uzi_viewmodel.show()
		swimming = false
		player.is_swimming = false
		return false
	swimming = true
	player.is_swimming = true
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	player._set_crouch_state(false)
	player.head.position.y = player.STANDING_HEAD_HEIGHT
	player.ads = false
	player.sprinting = false
	player.weapon.hide()
	if is_instance_valid(player.uzi_viewmodel): player.uzi_viewmodel.hide()
	player._tick_stamina(delta,false,false)
	var basis: Basis = player.camera.global_basis
	var wish: Vector3 = basis.x * input.x + basis.z * input.y
	if up or down: wish.y = float(up)-float(down)
	if wish.length()>1.0: wish = wish.normalized()
	var speed := 2.8 if fast else 1.9
	if player.stun_remaining > 0.0 and not player.drone_stun_active: speed *= player.STUN_MOVE_MULTIPLIER
	var target := wish * speed
	var float_feet: float = terrain.WATER_Y-player.STANDING_HEAD_HEIGHT+0.20
	if absf(wish.y)<0.05:
		# Idle swimmers gently rise, then settle with their eyes above the surface.
		target.y = clampf((float_feet-player.global_position.y)*2.0,-0.45,0.45)
	elif target.y>0.0:
		# Ease into the floating height, avoiding repeated exits into falling mode.
		target.y = minf(target.y,maxf(0.0,(float_feet-player.global_position.y)*3.0))
	player.velocity = player.velocity.move_toward(target,delta*5.0)
	player.move_and_slide()
	update_visuals(player)
	player.jump_was_down = up
	return true

func reset(player: CharacterBody3D) -> void:
	if submerged:
		player.camera.environment = previous_environment
		player.camera.far = previous_far
	submerged = false
	swimming = false
	player.is_swimming = false
	player.is_underwater = false
	player.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	if is_instance_valid(player.weapon): player.weapon.show()
	if is_instance_valid(player.uzi_viewmodel): player.uzi_viewmodel.show()

