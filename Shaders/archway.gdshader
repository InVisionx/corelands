shader_type spatial;
render_mode unshaded, cull_disabled; // Unshaded makes it glow, cull_disabled shows both sides

uniform vec4 color_a : source_color = vec4(0.0, 0.0, 0.0, 1.0); // Darker color (Black/Dark Purple)
uniform vec4 color_b : source_color = vec4(0.8, 0.0, 1.0, 1.0); // Lighter color (Bright Purple)

// IMPORTANT: 'repeat_enable' tells Godot to loop the texture so it doesn't streak at the edges
uniform sampler2D noise_tex : source_color, filter_linear_mipmap, repeat_enable;

uniform vec2 scroll_speed = vec2(0.1, 0.1);
uniform float uv_scale = 1.0;
uniform float emission_strength = 2.0;

void fragment() {
	// 1. Calculate moving UVs
	vec2 moving_uv = (UV * uv_scale) + (TIME * scroll_speed);

	// 2. Sample the noise
	float noise_val = texture(noise_tex, moving_uv).r;

	// 3. Mix the colors
	vec3 final_color = mix(color_a.rgb, color_b.rgb, noise_val);

	// 4. Output
	ALBEDO = final_color;
	EMISSION = final_color * emission_strength; // Multiply to make it bloom/glow
}