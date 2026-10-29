shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float life : hint_range(0.0, 1.0) = 1.0;
uniform float shot_seed = 0.0;
void vertex() {
    // World-sized emission sprite at the real muzzle, with normal depth testing.
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float radius = length(p);
    float angle = atan(p.y, p.x);
    float lobes = pow(0.5 + 0.5 * sin(angle * 5.0 + shot_seed), 3.0);
    float reach = 0.36 + 0.36 * lobes;
    float wisps = 0.8 + 0.2 * sin(angle * 11.0 + radius * 18.0 + shot_seed);
    float flame = (1.0 - smoothstep(reach * 0.35, reach, radius)) * wisps;
    float core = exp(-radius * radius * 42.0);
    float fade = smoothstep(0.0, 0.7, life);
    vec3 hot = mix(vec3(1.0, 0.24, 0.035), vec3(1.0, 0.9, 0.68), core);
    ALBEDO = hot;
    EMISSION = hot * (1.5 + 2.5 * core);
    ALPHA = max(flame * 0.65, core) * fade;
}
