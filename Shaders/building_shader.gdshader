shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

// --- BASE TEXTURE & TINT ---
uniform sampler2D atlas_texture : source_color, filter_nearest;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0); // <--- NEW: Default White (No change)

// --- DETAIL SETTINGS ---
uniform sampler2D detail_grain : hint_default_white, filter_linear_mipmap;
uniform float detail_scale = 20.0;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.05;

// --- GRADIENT SETTINGS (Dirt/Grounding) ---
uniform vec4 bottom_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float gradient_height : hint_range(0.1, 20.0) = 5.0;
uniform float gradient_offset : hint_range(-10.0, 10.0) = 0.0;
uniform float gradient_power : hint_range(0.1, 5.0) = 1.0;

// --- RIM LIGHT ---
uniform float rim_power : hint_range(0.0, 10.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.5;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying float local_y;

void vertex() {
    local_y = VERTEX.y;
}

void fragment() {
    // 1. BASE TEXTURE
    vec4 base = texture(atlas_texture, UV);

    // 2. APPLY TINT (Multiply)
    // This colors the texture but keeps the brightness values relative
    base.rgb *= albedo_tint.rgb;

    // 3. APPLY GRAIN
    vec3 grain = texture(detail_grain, UV * detail_scale).rgb;
    base.rgb = mix(base.rgb, base.rgb * grain, detail_strength);

    // 4. APPLY VERTICAL GRADIENT
    float adjusted_y = local_y + gradient_offset;
    float grad_mask = clamp(adjusted_y / gradient_height, 0.0, 1.0);
    grad_mask = pow(grad_mask, gradient_power);

    // Mix dirt on top of the tinted color
    base.rgb = mix(bottom_color.rgb, base.rgb, grad_mask);

    // 5. RIM LIGHT
    float fresnel = sqrt(1.0 - dot(NORMAL, VIEW));
    fresnel = pow(fresnel, rim_power);
    base.rgb += rim_color.rgb * fresnel * rim_strength;

    ALBEDO = base.rgb;
}