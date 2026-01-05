shader_type sky;

// --- Colors & Gradient ---
group_uniforms Sky_Colors;
uniform vec3 top_color : source_color = vec3(0.02, 0.05, 0.15);
uniform vec3 horizon_color : source_color = vec3(0.1, 0.2, 0.4);

// --- Stars ---
group_uniforms Stars;
uniform float star_density : hint_range(0.0, 1.0) = 0.05;
uniform float star_brightness : hint_range(0.0, 5.0) = 2.0;
uniform float twinkle_speed : hint_range(0.0, 10.0) = 1.0;

// --- The Moon ---
group_uniforms Moon;
uniform vec3 moon_color : source_color = vec3(0.9, 0.95, 1.0);
uniform float moon_size : hint_range(0.0, 0.2) = 0.05;
uniform float moon_glow : hint_range(0.0, 1.0) = 0.1;
uniform vec3 moon_pos_norm = vec3(0.5, 0.5, 0.0);

// --- Clouds ---
group_uniforms Clouds;
uniform sampler2D cloud_texture : filter_linear_mipmap, repeat_enable;
uniform vec3 cloud_color : source_color = vec3(0.4, 0.4, 0.6);
uniform float cloud_speed : hint_range(0.0, 0.1) = 0.01;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.4;
uniform float cloud_edge_softness : hint_range(0.0, 1.0) = 0.1;

// --- Helper Functions ---
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void sky() {
    // 1. Basic Background Gradient
    float gradient_mask = clamp(EYEDIR.y, 0.0, 1.0);
    vec3 final_color = mix(horizon_color, top_color, pow(gradient_mask, 0.5));

    // 2. Stars (FIXED: Spherical Mapping)
    if (EYEDIR.y > 0.0) {
        // We calculate Angle (atan) and Height (asin) to map a sphere
        // This prevents the stretching at the horizon
        float theta = atan(EYEDIR.z, EYEDIR.x);
        float phi = asin(EYEDIR.y);

        // Combine them into a UV and multiply by a large number for grid size
        vec2 sphere_uv = vec2(theta, phi) * 200.0;

        vec2 grid_id = floor(sphere_uv);
        float star_value = random(grid_id);

        if (star_value > (1.0 - (star_density * 0.01))) {
            float twinkle = sin(TIME * twinkle_speed + star_value * 20.0);
            twinkle = (twinkle + 1.0) * 0.5;
            final_color += vec3(star_brightness * twinkle);
        }
    }

    // 3. The Moon (Unchanged)
    float dist_to_moon = distance(EYEDIR, normalize(moon_pos_norm));
    if (dist_to_moon < moon_size) {
        final_color = moon_color;
    } else if (dist_to_moon < moon_size + moon_glow) {
        float glow_intensity = 1.0 - ((dist_to_moon - moon_size) / moon_glow);
        final_color += moon_color * glow_intensity * 0.5;
    }

    // 4. Moving Clouds (Unchanged - Perspective helps clouds look 3D)
    if (EYEDIR.y > 0.0) {
        vec2 cloud_uv = EYEDIR.xz / (EYEDIR.y + 0.3);
        vec2 animated_uv = cloud_uv + (vec2(TIME * cloud_speed, 0.0));
        float noise_value = texture(cloud_texture, animated_uv).r;
        float cloud_alpha = smoothstep(1.0 - cloud_density, (1.0 - cloud_density) + cloud_edge_softness, noise_value);
        float horizon_fade = clamp(EYEDIR.y * 3.0, 0.0, 1.0);
        cloud_alpha *= horizon_fade;
        final_color = mix(final_color, cloud_color, cloud_alpha);
    }

    COLOR = final_color;
}