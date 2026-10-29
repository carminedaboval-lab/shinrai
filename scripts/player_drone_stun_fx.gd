extends CanvasLayer
## Branching edge discharges; the gameplay timer is the sole time source.
## Peripheral electrical feedback and a brief render-only camera offset.
## No screen copy, aim/body transform edits, input handling or idle tick.

var overlay: ColorRect
var intensity: float = 0.0
var remaining: float = 0.0
var duration: float = 0.0
var shader_material: ShaderMaterial
var reduced_motion: bool = false
var _camera: Camera3D
var _camera_base_offset := Vector2.ZERO
var _shake_active := false
const SHAKE_SECONDS := .35
const SHAKE_HORIZONTAL_METRES := .008
const SHAKE_VERTICAL_METRES := .005

const FIZZ_SHADER: String = """
shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float effect_time = 0.0;
uniform float motion_scale = 1.0;
uniform vec2 viewport_size = vec2(1920.0, 1080.0);

float hash1(float p) {
    return fract(sin(p * 127.1 + 311.7) * 43758.5453);
}

// Angular paths stay fixed for a burst; the discharge front travels inward.
float jagged(float t, float seed) {
    float segment = t * 13.0;
    float index = floor(segment);
    return mix(hash1(index + seed), hash1(index + seed + 1.0), fract(segment)) * 2.0 - 1.0;
}

// Screen-height coordinates keep the cobalt strands fine at any aspect ratio.
// Channels: defined cobalt strand, narrow dark corona, tiny blue highlight.
vec3 filament(vec2 p, float start_depth, float length, float anchor,
              float slope, float seed, float head, float tail, float amplitude) {
    float t = (p.x - start_depth) / length;
    float pixel = 1.0 / max(viewport_size.y, 1.0);
    if (t < 0.0 || t > 1.0 || p.x > head + pixel * 3.0 || p.x < tail - pixel * 3.0) {
        return vec3(0.0);
    }
    float shape = anchor + slope * t + jagged(t, seed) * amplitude * sin(t * 3.141593);
    float distance_to_arc = abs(p.y - shape);
    float taper = mix(1.0, 0.42, t);
    float width = max(pixel * 0.85, 0.00080) * taper;
    float strand = 1.0 - smoothstep(width, width + pixel * 0.75, distance_to_arc);
    float corona = exp(-distance_to_arc / max(width * 2.2, pixel * 1.25));
    float highlight = 1.0 - smoothstep(width * 0.18, width * 0.18 + pixel * 0.40, distance_to_arc);
    float reveal = 1.0 - smoothstep(head - pixel * 2.0, head + pixel * 2.0, p.x);
    reveal *= smoothstep(tail - pixel * 2.0, tail + pixel * 2.0, p.x);
    return vec3(strand, corona * 0.32, highlight * 0.24) * reveal;
}

vec3 edge_burst(vec2 p, float span, float reach_limit, float seed, float delay) {
    float period = 0.44 + hash1(seed + 4.0) * 0.24;
    float time = effect_time - delay;
    if (time < 0.0 && motion_scale > 0.5) { return vec3(0.0); }
    float cycle = floor(max(time, 0.0) / period);
    float age = fract(max(time, 0.0) / period);
    if (motion_scale < 0.5) { cycle = 0.0; }
    float event_seed = seed + cycle * 31.7;
    float life = 0.42 + hash1(event_seed + 7.0) * 0.22;
    float progress = age / life;
    // A fixed, fully formed pattern replaces travel/flicker in reduced motion.
    if (motion_scale < 0.5) { progress = 0.42; }
    if (progress >= 1.0) { return vec3(0.0); }
    float reach = reach_limit * mix(0.65, 1.0, hash1(event_seed + 2.0));
    float anchor = span * mix(0.08, 0.92, hash1(event_seed + 9.0));
    float slope = (hash1(event_seed + 6.0) - 0.5) * 0.12;
    float head = reach * smoothstep(0.0, 0.34, progress);
    float tail = reach * smoothstep(0.48, 0.96, progress) - 0.004;
    float amplitude = 0.014 + hash1(event_seed + 12.0) * 0.012;
    vec3 result = filament(p, 0.0, reach, anchor, slope, event_seed, head, tail, amplitude);
    float fork_direction = hash1(event_seed + 17.0) < 0.5 ? -1.0 : 1.0;
    float fork = 0.28;
    float fork_anchor = anchor + slope * fork + jagged(fork, event_seed) * amplitude * sin(fork * 3.141593);
    result += filament(p, reach * fork, reach * 0.50, fork_anchor,
                       slope * 0.50 + fork_direction * 0.057, event_seed + 70.0,
                       head, tail, amplitude * 0.70) * 0.86;
    // One bounded second fork, attached to the parent rather than a loose spark.
    fork = 0.61;
    fork_anchor = anchor + slope * fork + jagged(fork, event_seed) * amplitude * sin(fork * 3.141593);
    result += filament(p, reach * fork, reach * 0.28, fork_anchor,
                       slope * 0.28 - fork_direction * 0.043, event_seed + 113.0,
                       head, tail, amplitude * 0.52) * 0.67;
    float flicker = 0.62 + 0.38 * hash1(floor(progress * 9.0) + event_seed + 30.0);
    float envelope = smoothstep(0.0, 0.025, progress) * (1.0 - smoothstep(0.56, 0.96, progress));
    if (motion_scale < 0.5) { flicker = 0.86; }
    return result * envelope * flicker;
}

void fragment() {
    float aspect = viewport_size.x / max(viewport_size.y, 1.0);
    vec3 field = vec3(0.0);
    // Keep the central 72% width / 74% height fully transparent, unchanged.
    // Six fixed edge streams; three filaments each, no full-frame noise/capture.
    if (UV.x < 0.14) {
        vec2 p = vec2(UV.x * aspect, UV.y);
        field += edge_burst(p, 1.0, min(0.14 * aspect, 0.20), 11.0, 0.0);
        field += edge_burst(p, 1.0, min(0.12 * aspect, 0.17), 29.0, 0.18);
    }
    if (UV.x > 0.86) {
        vec2 p = vec2((1.0 - UV.x) * aspect, UV.y);
        field += edge_burst(p, 1.0, min(0.14 * aspect, 0.20), 47.0, 0.07);
        field += edge_burst(p, 1.0, min(0.12 * aspect, 0.17), 63.0, 0.29);
    }
    if (UV.y < 0.13) {
        field += edge_burst(vec2(UV.y, UV.x * aspect), aspect, 0.125, 83.0, 0.12);
    }
    if (UV.y > 0.87) {
        field += edge_burst(vec2(1.0 - UV.y, UV.x * aspect), aspect, 0.125, 101.0, 0.24);
    }
    float strand = clamp(field.x, 0.0, 1.0);
    float corona = clamp(field.y, 0.0, 1.0);
    float highlight = clamp(field.z, 0.0, 0.24);
    float energy = strand + corona + highlight;
    vec3 tint = (strand * vec3(0.012, 0.055, 0.64)
                 + corona * vec3(0.003, 0.018, 0.14)
                 + highlight * vec3(0.06, 0.29, 1.0)) / max(energy, 0.0001);
    float alpha = clamp((strand * 0.97 + corona * 0.48 + highlight * 0.20) * intensity, 0.0, 0.94);
    COLOR = vec4(tint, alpha);
}
"""

func _ensure_overlay() -> void:
    if is_instance_valid(overlay):
        return
    # Below the existing HUD/lens layers; above the 3D view.
    layer = 0
    overlay = ColorRect.new()
    overlay.name = "DroneStunFizz"
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.focus_mode = Control.FOCUS_NONE
    overlay.color = Color.WHITE
    overlay.visible = false
    var shader := Shader.new()
    shader.code = FIZZ_SHADER
    shader_material = ShaderMaterial.new()
    shader_material.shader = shader
    overlay.material = shader_material
    add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func begin(seconds: float) -> void:
    if not is_finite(seconds) or seconds <= 0.0:
        clear()
        return
    _ensure_overlay()
    _restore_camera()
    if is_instance_valid(_camera) and not reduced_motion:
        _camera_base_offset = Vector2(_camera.h_offset, _camera.v_offset)
        _shake_active = true
    duration = clampf(seconds, 0.0, 3.0)
    update_remaining(duration)

func update_remaining(seconds: float) -> void:
    if not is_finite(seconds) or seconds <= 0.0 or duration <= 0.0:
        clear()
        return
    _ensure_overlay()
    remaining = clampf(seconds, 0.0, duration)
    var elapsed: float = duration - remaining
    var onset: float = 1.0 - smoothstep(0.0, 0.20, elapsed)
    var fade: float = smoothstep(0.0, minf(0.35, duration), remaining)
    intensity = (0.70 + 0.30 * onset) * fade
    shader_material.set_shader_parameter("intensity", intensity)
    shader_material.set_shader_parameter("effect_time", elapsed)
    shader_material.set_shader_parameter("viewport_size", get_viewport().get_visible_rect().size)
    shader_material.set_shader_parameter("motion_scale", 0.0 if reduced_motion else 1.0)
    _update_camera(elapsed)
    overlay.visible = intensity > 0.0

func bind_camera(camera: Camera3D, reduce_motion: bool = false) -> void:
    _restore_camera()
    _camera = camera
    reduced_motion = reduce_motion

func _update_camera(elapsed: float) -> void:
    if not _shake_active: return
    if reduced_motion or elapsed >= SHAKE_SECONDS or not is_instance_valid(_camera):
        _restore_camera()
        return
    var envelope := smoothstep(0.0, .025, elapsed) * (1.0 - smoothstep(.03, SHAKE_SECONDS, elapsed))
    var horizontal := (sin(elapsed * TAU * 23.0) * .75 + sin(elapsed * TAU * 31.0) * .25) * SHAKE_HORIZONTAL_METRES * envelope
    var vertical := sin(elapsed * TAU * 29.0) * SHAKE_VERTICAL_METRES * envelope
    # Viewport offsets affect rendering, while shoot() uses the unchanged
    # camera.global_transform. Head rotation, recoil and body physics stay intact.
    _camera.h_offset = _camera_base_offset.x + horizontal
    _camera.v_offset = _camera_base_offset.y + vertical

func _restore_camera() -> void:
    if _shake_active and is_instance_valid(_camera):
        _camera.h_offset = _camera_base_offset.x
        _camera.v_offset = _camera_base_offset.y
    _shake_active = false

func _exit_tree() -> void:
    _restore_camera()

func clear() -> void:
    _restore_camera()
    intensity = 0.0
    remaining = 0.0
    duration = 0.0
    if is_instance_valid(overlay):
        overlay.visible = false
    if is_instance_valid(shader_material):
        shader_material.set_shader_parameter("intensity", 0.0)
