shader_type spatial;
// We use generic modes here.
// NOTE: If you want this to always face the camera (Billboarding),
// you must add 'billboard_y' to the line below manually.
render_mode unshaded, cull_disabled, depth_draw_opaque;

// --- MASTER SWITCH ---
uniform int effect_mode : hint_enum("Pulse", "Fire", "Combined") = 0;

// --- PULSE SETTINGS (Mode 0) ---
group_uniforms Pulse_Settings;
uniform vec4 pulse_color : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform float pulse_speed : hint_range(0.1, 10.0) = 2.0;
uniform float intensity_min : hint_range(0.0, 2.0) = 0.8;
uniform float intensity_max : hint_range(0.0, 5.0) = 1.5;

// --- FIRE SETTINGS (Mode 1) ---
group_uniforms Fire_Settings;
uniform sampler2D noise_tex : filter_nearest;
uniform vec4 color_inner : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 color_mid : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform vec4 color_outer : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float flow_speed = 1.0;
uniform float erosion_amount : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec4 final_color = vec4(1.0);

    // ============================
    // MODE 0: PULSE (Your Original)
    // ============================
    if (effect_mode == 0) {
        float t = sin(TIME * pulse_speed) * 0.5 + 0.5;
        float brightness = mix(intensity_min, intensity_max, t);
        final_color = pulse_color * brightness;
    }

    // ============================
    // MODE 1: FIRE (Scrolling Noise)
    // ============================
    else if (effect_mode == 1) {
        // Scroll Logic
        vec2 scroll_uv = UV;
        scroll_uv.y += TIME * flow_speed;
        float noise_val = texture(noise_tex, scroll_uv).r;

        // Shape Logic
        float fuel = 1.0 - UV.y;
        float shape = fuel - (noise_val * erosion_amount);

        // Hard Cutoff (Pixel Art Style)
        if (shape < 0.1) discard;

        // Color Banding
        vec3 fire_rgb = color_outer.rgb;
        if (shape > 0.4) fire_rgb = color_mid.rgb;
        if (shape > 0.7) fire_rgb = color_inner.rgb;

        final_color = vec4(fire_rgb, 1.0);
    }

    // ============================
    // MODE 2: COMBINED (Flickering Fire)
    // ============================
    else {
        // 1. Calculate Fire Shape first
        vec2 scroll_uv = UV;
        scroll_uv.y += TIME * flow_speed;
        float noise_val = texture(noise_tex, scroll_uv).r;
        float fuel = 1.0 - UV.y;
        float shape = fuel - (noise_val * erosion_amount);

        if (shape < 0.1) discard;

        vec3 fire_rgb = color_outer.rgb;
        if (shape > 0.4) fire_rgb = color_mid.rgb;
        if (shape > 0.7) fire_rgb = color_inner.rgb;

        // 2. Apply Pulse Intensity ON TOP of the fire colors
        float t = sin(TIME * pulse_speed + (noise_val * 5.0)) * 0.5 + 0.5;
        float brightness = mix(intensity_min, intensity_max, t);

        final_color = vec4(fire_rgb * brightness, 1.0);
    }

    ALBEDO = final_color.rgb;
    ALPHA = final_color.a;
}