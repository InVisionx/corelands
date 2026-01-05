shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.5); 
uniform sampler2D noise_tex; 
uniform float speed : hint_range(0.0, 0.5) = 0.1;

// INCREASED DEFAULT RADIUS (Try sliding this up and down in inspector)
uniform float mask_radius : hint_range(0.0, 5.0) = 1.0; 
uniform float mask_softness : hint_range(0.0, 1.0) = 0.5;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	// Optional: Push vertices out slightly based on noise
	float noise = texture(noise_tex, UV + TIME * speed).r;
	VERTEX += NORMAL * noise * 0.1; 
}

void fragment() {
	float noise_val = texture(noise_tex, UV + (TIME * speed * 0.5)).r;
	float noise_val2 = texture(noise_tex, UV - (TIME * speed * 0.2)).r;
	
	// FIX: If no texture is assigned, default to 1.0 so it doesn't vanish
	float combined_noise = (noise_val * noise_val2);
	if (combined_noise == 0.0) {
		combined_noise = 1.0; 
	}
	
	// SPHERE MASK LOGIC
	float dist_from_center = length(local_pos);
	
	// Smoothstep: High value (1.0) at center, Low value (0.0) at radius edge
	float sphere_mask = smoothstep(mask_radius, mask_radius - mask_softness, dist_from_center);

	float final_alpha = combined_noise * color.a * sphere_mask;
	
	ALBEDO = color.rgb;
	ALPHA = final_alpha;
}