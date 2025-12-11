shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// --- UNIFORMS (Editable in the Inspector) ---

// PBR Textures
// Corrected hints for sampler2D textures
uniform sampler2D albedo_tex;
uniform sampler2D normal_tex : hint_normal;
uniform sampler2D roughness_tex;

// Base Color Control
uniform vec4 base_color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Glow / Mask
uniform sampler2D glow_mask_tex;
uniform vec4 glow_color : source_color;
uniform float glow_intensity = 1.0; 

// NEW: Pulsing Control (Only speed)
uniform float pulse_speed = 2.0; 

// Scaling
uniform float uv_scale = 1.0; 


void fragment() {
    // 1. UV Scaling
    vec2 scaled_uv = UV * uv_scale;

    // 2. Sample Textures (PBR)
    vec4 albedo_sampled = texture(albedo_tex, scaled_uv);
    vec3 normal_map = texture(normal_tex, scaled_uv).rgb;
    float roughness = texture(roughness_tex, scaled_uv).r;
    
    // 2a. Apply Base Color Tint/Multiplier
    vec4 albedo_color = albedo_sampled * base_color_tint;

    // Sample the glow mask texture (grayscale value)
    float mask = texture(glow_mask_tex, scaled_uv).r;

    // 3. PULSE CALCULATION (Simplified)
    
    // Use the absolute value of the sine wave (abs(sin())) to create a pulse that goes 
    // from 0.0 (off) to 1.0 (on) and back to 0.0, which is simpler than mixing 
    // the negative/positive range. The '1.0 + sin(TIME * pulse_speed)' part 
    // ensures the wave always starts and ends at the base of the pulse.
    
    // Sine wave oscillates between -1.0 and 1.0
    float sine_wave = sin(TIME * pulse_speed);
    
    // Remap sine wave from [-1, 1] to [0, 1] using 0.5 * (1 + sin(x))
    float pulse_value = 0.5 + 0.5 * sine_wave;
    
    // Use the pulse_value to modulate the intensity
    float final_intensity = glow_intensity * pulse_value;
    
    // 4. Glow Masking and Color Mixing
    
    // The glow color's intensity for the albedo mix should also pulse
    vec4 pulsing_glow_color = glow_color * final_intensity;
    
    // Mix the base albedo color with the pulsing glow color, using the mask as the weight.
    vec4 final_albedo = mix(albedo_color, pulsing_glow_color, mask);
    
    // 5. Final Output

    // Set Albedo (Base Color)
    ALBEDO = final_albedo.rgb;

    // Set Normal and Roughness (PBR)
    NORMAL_MAP = normal_map;
    ROUGHNESS = roughness;

    // Set Emission (Glow)
    // Use the calculated final_intensity to modulate the emission strength
    EMISSION = glow_color.rgb * mask * final_intensity;
}