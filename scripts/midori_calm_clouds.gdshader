shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, fog_disabled;
uniform float coverage : hint_range(0.0,1.0) = 0.46;
uniform float drift_speed = 0.35;
uniform float night_amount = 0.0;
uniform float daylight_brightness = 0.64;
uniform vec3 sun_direction = vec3(0.45,0.58,0.68);
varying vec3 sky_ray;
float hash3(vec3 p) {
    p = fract(p * vec3(0.1031,0.11369,0.13787));
    p += dot(p,p.yzx + 19.19);
    return fract((p.x + p.y)*p.z);
}
float noise3(vec3 p) {
    vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),
        mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float density(vec3 p) {
    float h=(p.y-1050.0)/520.0;
    if (h<=0.0 || h>=1.0) return 0.0;
    float envelope=smoothstep(0.0,0.16,h)*(1.0-smoothstep(0.48,1.0,h));
    vec3 q=p*0.0029;
    float broad=noise3(vec3(q.x*0.47,0.71,q.z*0.47));
    if (broad<=0.43) return 0.0;
    float lumps=noise3(q)*0.65+noise3(q*2.07+11.4)*0.25+noise3(q*4.13-8.1)*0.10;
    // Preserve the original broad cloud banks and blue-sky openings.
    // Smaller scales perturb the volume itself, not just its alpha outline.
    float curl=noise3(q*5.3+vec3(6.2,19.1,3.7));
    float fine=noise3(q*12.7-vec3(4.1,7.3,15.8));
    float micro=noise3(q*27.3+vec3(17.3,5.9,11.1));
    float field=broad*0.46+lumps*0.54;
    field+=(curl-0.48)*0.085+(fine-0.50)*0.042+(micro-0.50)*0.015;
    float body=smoothstep(0.56-coverage*0.08,0.69-coverage*0.03,field);
    body*=smoothstep(0.43,0.64,broad);
    float erosion=(1.0-fine)*0.11+(1.0-micro)*0.045;
    body=max(body-erosion*(1.0-body),0.0);
    return body*envelope;
}
void vertex() {
    sky_ray = (MODEL_MATRIX * vec4(VERTEX,0.0)).xyz;
}
void fragment() {
    vec3 ray=normalize(sky_ray);
    vec2 drift=vec2(0.83205,0.55470)*TIME*drift_speed;
    vec3 sun=normalize(sun_direction);
    float alpha=0.0;
    vec3 sum=vec3(0.0);
    if (ray.y>0.035) {
        float start=1050.0/ray.y;
        float step_length=700.0/(ray.y*56.0);
        // Deterministic pixel jitter softens shallow-angle step bands.
        float jitter=hash3(vec3(FRAGCOORD.xy,0.0));
        for(int i=0;i<56;i++) {
            vec3 p=ray*(start+(float(i)+jitter)*step_length);
            p.xz-=drift;
            float d=density(p);
            if(d>0.003) {
                float shadow=density(p+sun*55.0)*0.48+density(p+sun*140.0)*0.34+density(p+sun*300.0)*0.18;
                float cloud_height=clamp((p.y-1050.0)/520.0,0.0,1.0);
                float light=exp(-shadow*3.4)*mix(0.64,1.0,smoothstep(0.0,0.72,cloud_height));
                // Cooler shaded bellies and warm lit lobes distinguish volume
                // from a flat white sky overlay. Edge scattering stays bounded.
                float forward_scatter=pow(max(dot(ray,sun),0.0),10.0);
                float thin_edge=(1.0-smoothstep(0.06,0.22,d));
                vec3 base=mix(vec3(0.30,0.37,0.45),vec3(0.93,0.92,0.89),light);
                base+=vec3(0.055,0.047,0.032)*forward_scatter*thin_edge;
                base=mix(base, mix(vec3(0.018,0.026,0.045),vec3(0.085,0.105,0.14),light),night_amount);
                float a=(1.0-exp(-d*step_length*0.008));
                sum+=(1.0-alpha)*a*base;
                alpha+=(1.0-alpha)*a;
            }
        }
        // Very thin, separate higher haze keeps plenty of open sky.
        vec2 high=ray.xz*(3400.0/ray.y)*0.00039-drift*0.00017;
        float haze=smoothstep(0.54,0.83,noise3(vec3(high.x,2.7,high.y)))*0.10;
        vec3 haze_color=mix(vec3(0.77,0.83,0.88),vec3(0.10,0.14,0.20),night_amount);
        sum+=(1.0-alpha)*haze*haze_color;
        alpha+=(1.0-alpha)*haze;
    }
    float horizon=smoothstep(0.07,0.27,ray.y);
    ALBEDO=(sum/max(alpha,0.0001))*mix(daylight_brightness,1.0,night_amount);
    ALPHA=alpha*horizon;
}
