shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always; // force writing to depth

uniform sampler2D base_texture : source_color;
uniform sampler2D mask_texture : source_color;

uniform vec4 tint_color : source_color = vec4(1.0, 0.3, 0.3, 1.0);
uniform bool use_mask = true;

void fragment() {
    vec4 base = texture(base_texture, UV);
    vec3 color_out = base.rgb;

    if (use_mask) {
        float m = texture(mask_texture, UV).r;
        color_out = mix(base.rgb, tint_color.rgb, m);
    }

    ALBEDO = color_out;
    ALPHA = 1.0;
}
