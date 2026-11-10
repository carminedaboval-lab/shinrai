extends Node3D
# Mount the origin on the real lantern's oil dish, inside its open chamber.
# This component supplies fire and local light only; it never makes a stone asset.
# The flame shader comes from the shared pool: one compiled shader for every
# lantern (the phase is a uniform), instead of one per instance.
const ShaderPool := preload("res://scripts/shinrai_shader_pool.gd")
# The single flame text. biomes/moss_garden.gd reads this const for its
# script-free lantern flames, so both kinds of lantern share one pooled shader
# (the pool keys on the exact string). Keep it byte for byte: 4-space indents.
const FLAME_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform float phase = 0.0;
void vertex() {
    // Turn around world Y only, keeping the flame foot on the oil dish.
    vec3 up = vec3(0.0,1.0,0.0);
    vec3 facing = vec3(INV_VIEW_MATRIX[2].x,0.0,INV_VIEW_MATRIX[2].z);
    facing = length(facing)>0.001 ? normalize(facing) : vec3(0.0,0.0,1.0);
    vec3 right = normalize(cross(up,facing));
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right,0.0),vec4(up,0.0),vec4(facing,0.0),MODEL_MATRIX[3]);
}
void fragment() {
    float t = TIME + phase;
    float y = 1.0 - UV.y;
    float bend = (sin(t*5.7+y*7.0)*0.045 + sin(t*9.1-y*12.0)*0.025)*y*y;
    float x = (UV.x - 0.5 - bend)*2.0;
    float width = 0.74*pow(max(1.0-y,0.001),0.68);
    float edge = 1.0-smoothstep(width*0.64,width,abs(x));
    float foot = smoothstep(0.0,0.08,y);
    float tip = 1.0-smoothstep(0.82+0.045*sin(t*7.0),1.0,y);
    float core = exp(-x*x*30.0)*(1.0-smoothstep(0.40,0.77,y));
    vec3 amber = mix(vec3(1.0,0.20,0.025),vec3(1.0,0.77,0.29),core);
    ALBEDO = amber;
    EMISSION = amber * (2.2 + 1.1*core);
    ALPHA = edge*foot*tip*0.94;
}
"""
@export var flame_height := 0.055
@export var flame_width := 0.026
@export var light_range := 1.8
@export var light_energy := 0.045
@export var spill_energy := 0.65
@export var phase := 0.0
var _light: OmniLight3D
var _flame: MeshInstance3D
var _spill: SpotLight3D
var _time := 0.0

func _ready() -> void:
	var shader := ShaderPool.shader(FLAME_SHADER)
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("phase",phase)
	var flame := MeshInstance3D.new()
	_flame = flame
	flame.name = "SmallOilFlame"
	var quad := QuadMesh.new()
	quad.size = Vector2(flame_width,flame_height)
	flame.mesh = quad
	flame.position.y = flame_height*0.5
	flame.material_override = material
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)
	_light = OmniLight3D.new()
	_light.name = "WarmChamberLight"
	_light.position.y = flame_height*0.45
	_light.light_color = Color(1.0,0.64,0.30)
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.omni_attenuation = 1.8
	_light.shadow_enabled = true
	_light.shadow_bias = 0.03
	_light.shadow_normal_bias = 0.15
	_light.light_size = 0.025
	add_child(_light)
	# Low, forward spill from the aperture represents reflected firelight.
	# The chamber's sill otherwise shadows every nearby ground ray.
	_spill = SpotLight3D.new()
	_spill.name = "ReflectedApertureGlow"
	_spill.position = Vector3(0,flame_height*.45,.225)
	_spill.rotation_degrees = Vector3(-35,180,0)
	_spill.light_color = Color(1.0,.64,.30)
	_spill.light_energy = spill_energy
	_spill.spot_range = 1.8
	_spill.spot_angle = 50
	_spill.spot_attenuation = 2.0
	_spill.shadow_enabled = true
	_spill.shadow_bias = .03
	_spill.shadow_normal_bias = .15
	_spill.light_size = .025
	add_child(_spill)

func _process(delta: float) -> void:
	_time += delta
	# Independent bounded flicker; no global environment, exposure or sun edits.
	var t := _time+phase
	var fade := 1.0
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var distance := global_position.distance_to(camera.global_position)
		fade = 1.0-smoothstep(18.0,24.0,distance)
		_flame.visible = distance<45.0
	_light.visible = fade>0.0
	_light.light_energy = light_energy*fade*(1.0+0.055*sin(t*5.7)+0.025*sin(t*9.1))
	_spill.visible = fade>0.0
	_spill.light_energy = spill_energy*fade*(1.0+0.055*sin(t*5.7)+0.025*sin(t*9.1))
