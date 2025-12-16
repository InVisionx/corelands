shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// User controls
uniform float variation_amount : hint_range(0.0, 1.0) = 0.1; 
uniform float rotation_amount : hint_range(0.0, 1.0) = 0.25; 
uniform float scale_variation : hint_range(0.0, 2.0) = 0.2;

// Texture
uniform sampler2D albedo_tex : source_color;

varying vec2 uv_var;

// Hash function
float hash13(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

void vertex() {
    // Convert INSTANCE_ID to float before using it
    float id = float(INSTANCE_ID);

    // Generate a random number per-instance
    float rnd = hash13(vec3(id, id * 1.31, id * 2.77));

    // Rotation (radians)
    float rot = (rnd - 0.5) * rotation_amount * 6.2831853; 

    // Random scale
    float sc = 1.0 + (rnd - 0.5) * scale_variation;

    // Start with UV
    vec2 uv = UV * sc;

    // Rotate
    float cs = cos(rot);
    float sn = sin(rot);

    uv = vec2(
        uv.x * cs - uv.y * sn,
        uv.x * sn + uv.y * cs
    );

    // Random offset
    uv += vec2(rnd * variation_amount, rnd * variation_amount * 0.73);

    uv_var = uv;
}

void fragment() {
    vec4 col = texture(albedo_tex, uv_var);
    ALBEDO = col.rgb;
    ALPHA = col.a;
}
