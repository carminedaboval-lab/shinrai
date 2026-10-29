shader_type spatial;
render_mode cull_disabled;
uniform vec3 midori_sc_main_camera;
uniform vec2 midori_sc_fade_distances = vec2(10.0,16.0);
uniform bool cutout_enabled = false;
uniform sampler2D texture_albedo : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float albedo_alpha = 1.0;
uniform bool use_vertex_alpha = false;
uniform float alpha_threshold = 0.5;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
varying vec3 rest_world;
void vertex() {
 rest_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 UV=UV*uv_scale+uv_offset;
}
void fragment() {
 if (cutout_enabled) {
  float native_alpha=albedo_alpha*texture(texture_albedo,UV).a;
  if (use_vertex_alpha) native_alpha*=COLOR.a;
  if (native_alpha<alpha_threshold) discard;
 }
 float distance_m=distance(rest_world.xz,midori_sc_main_camera.xz);
 float coverage=1.0-smoothstep(midori_sc_fade_distances.x,midori_sc_fade_distances.y,distance_m);
 float noise=fract(sin(dot(floor(rest_world*64.0),vec3(127.1,311.7,74.7)))*43758.5453);
 if (coverage<=0.0 || (coverage<1.0 && noise>=coverage)) discard;
}
