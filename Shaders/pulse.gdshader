shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

uniform vec4 base_color : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform float pulse_speed : hint_range(0.1, 10.0) = 2.0;
uniform float intensity_min : hint_range(0.0, 2.0) = 0.8;
uniform float intensity_max : hint_range(0.0, 5.0) = 1.5;

void fragment() {
    // Pulse 0–1 with time
    float t = sin(TIME * pulse_speed) * 0.5 + 0.5;
    float brightness = mix(intensity_min, intensity_max, t);

    vec3 final_rgb = base_color.rgb * brightness;

    // Apply color directly so it's always visible
    ALBEDO = final_rgb;
    EMISSION = final_rgb;
    ALPHA = base_color.a;
}
