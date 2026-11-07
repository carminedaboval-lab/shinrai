extends RefCounted

# Visual state for one K17 drone: hull material, a rim that changes colour with
# AI state, a brightening wind-up before each shot, and a white hit flash.
# AI behaviour stays in enemy.gd; this only reads it.

const DRONE_SHADER := preload("res://shaders/k17_drone.gdshader")
# Indexed by enemy.gd AIState: PATROL, ALERT, COMBAT, SEARCH, RETURN_TO_PATROL.
const STATE_RIM: Array[Color] = [
	Color(0.3, 0.85, 1.0),
	Color(1.0, 0.68, 0.18),
	Color(1.0, 0.2, 0.14),
	Color(1.0, 0.68, 0.18),
	Color(0.3, 0.85, 1.0),
]
const WINDUP_TIME := 0.35

var material: ShaderMaterial
var _rim := STATE_RIM[0]
var _flash := 0.0
var _clock := 0.0

func apply(visual_root: Node) -> void:
	material = ShaderMaterial.new()
	material.shader = DRONE_SHADER
	material.set_shader_parameter("rim_color", _rim)
	var stack: Array[Node] = [visual_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			(node as MeshInstance3D).material_override = material
		stack.append_array(node.get_children())

func notify_hit() -> void:
	_flash = 1.0

func update(delta: float, ai_state: int, attack_cooldown: float, night: bool) -> void:
	if material == null:
		return
	_clock += delta
	_flash = maxf(0.0, _flash - delta * 9.0)
	var wanted: Color = STATE_RIM[clampi(ai_state, 0, STATE_RIM.size() - 1)]
	_rim = _rim.lerp(wanted, minf(1.0, delta * 6.0))
	var strength := 0.75 if night else 0.5
	if ai_state == 2:
		# Combat pulses slowly, then flares just before the shot lands.
		strength += 0.15 * (0.5 + 0.5 * sin(_clock * 7.0))
		if attack_cooldown > 0.0 and attack_cooldown < WINDUP_TIME:
			strength += 1.4 * (1.0 - attack_cooldown / WINDUP_TIME)
	material.set_shader_parameter("rim_color", _rim)
	material.set_shader_parameter("rim_strength", strength)
	material.set_shader_parameter("flash", _flash * 1.6)
