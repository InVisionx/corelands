shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

// --- Uniforms for Input Textures and Colors ---
uniform sampler2D mask_texture; // Black/White image: Black is Color A, White is Color B

// CORRECTED: Using 'source_color' hint
uniform vec4 color_a : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Color for the black areas (Color A)
uniform vec4 color_b : source_color = vec4(0.0, 0.0, 1.0, 1.0); // Color for the white areas (Color B)

// --- Uniforms for UNIFIED Movement Controls ---
uniform float time_speed = 0.5;      // Overall speed multiplier for animation
uniform bool move_circle = false;     // Move the mask in a circular pattern (Oscillating)
uniform bool move_vertical = false;   // Move the mask up/down (Continuous Scrolling)

// --- Uniforms for UNIFIED Scaling Control ---
uniform float uniform_scale = 1.0;   // Scale (Tiling) for the mask


// Function to calculate the modified UV for the mask
vec2 get_animated_uv(vec2 base_uv) {
    vec2 scaled_uv = base_uv * uniform_scale;
    vec2 offset = vec2(0.0);

    // Get time with speed control
    float t = TIME * time_speed;

    // Vertical Movement (Continuous Scrolling)
    if (move_vertical) {
        // Moves the texture consistently down over time. 
        // Use + t * 0.1 for consistent UP movement.
        offset.y -= t * 0.1; 
    }

    // Circular Movement (Oscillating)
    if (move_circle) {
        // Creates a circular offset path
        offset.x += cos(t) * 0.1;
        offset.y += sin(t) * 0.1;
    }

    // `fract()` ensures UVs stay between 0.0 and 1.0 for clean, seamless tiling.
    return fract(scaled_uv + offset);
}


void fragment() {
    // 1. Calculate the single, animated UV for the mask
    vec2 animated_uv = get_animated_uv(UV);

    // 2. Get the Mask Value using the animated UV
    float mask_value = texture(mask_texture, animated_uv).r;

    // 3. Blend the Colors using the mask
    vec4 final_color = mix(color_a, color_b, mask_value);

    // 4. Output the result
    ALBEDO = final_color.rgb;
}