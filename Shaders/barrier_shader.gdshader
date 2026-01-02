shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.5); // Translucent White
uniform sampler2D noise_tex; // Plug in a FastNoiseLite texture here
uniform float speed : hint_range(0.0, 0.5) = 0.1;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.2;

void vertex() {
    // This makes the barrier "wiggle" slightly
    float noise_val = texture(noise_tex, UV + TIME * speed).r;
    VERTEX.y += noise_val * wave_strength;
}

void fragment() {
    // This creates the moving mist effect
    float noise_val = texture(noise_tex, UV + (TIME * speed * 0.5)).r;
    float noise_val2 = texture(noise_tex, UV - (TIME * speed * 0.2)).r;
    
    float final_alpha = (noise_val * noise_val2) * color.a;
    
    ALBEDO = color.rgb;
    ALPHA = final_alpha;
}