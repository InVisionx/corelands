shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_always;

uniform sampler2D noise_tex : source_color; // plug in NoiseTexture2D or a seamless noise
uniform vec4 glow_color : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float swirl_speed : hint_range(0.0, 5.0) = 0.8;
uniform float swirl_scale : hint_range(0.1, 10.0) = 2.0;
uniform float intensity : hint_range(0.0, 10.0) = 5.0;
uniform float base_visibility : hint_range(0.0, 1.0) = 0.1;

void fragment() {
    vec2 uv = UV * swirl_scale;

    // rotation matrix (column-major)
    float a = TIME * swirl_speed;
    float ca = cos(a);
    float sa = sin(a);
    mat2 rot = mat2(vec2(ca, sa), vec2(-sa, ca));

    // rotate around center
    uv = rot * (uv - 0.5) + 0.5;

    // scrolling sample for motion
    vec2 flow = vec2(TIME * 0.10, -TIME * 0.10);
    float n = texture(noise_tex, uv + flow).r;

    // shape the noise → brighter cores, softer lows
    n = smoothstep(0.3, 1.0, n);

    float glow = mix(base_visibility, 1.0, n);
	//ALBEDO = glow_color.rgb * 0.05;
    ALBEDO   = glow_color.rgb * glow;
    EMISSION = glow_color.rgb * intensity * glow;
    ALPHA    = glow;
}
