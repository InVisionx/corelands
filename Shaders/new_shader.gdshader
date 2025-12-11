// NOTE: Shader automatically converted from Godot Engine 4.5.stable's StandardMaterial3D.
// RENDER MODE: Simplified to only include necessary modes.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

// --- EXISTING UNIFORMS (from your original material) ---
uniform vec4 albedo : source_color; // Default ALBEDO from StandardMaterial3D (can be ignored)
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform ivec2 albedo_texture_size;

// --- CUSTOM B/W MASK & EMISSION UNIFORMS ---
uniform vec4 tint_color : source_color; // The custom color for the white parts of the mask.
uniform float emission_intensity : hint_range(0.0, 10.0) = 1.0; // The glow effect multiplier.
// --- END CUSTOM UNIFORMS ---

// --- EXISTING PARTICLE ANIMATION UNIFORMS ---
uniform int particles_anim_h_frames : hint_range(1, 128);
uniform int particles_anim_v_frames : hint_range(1, 128);
uniform bool particles_anim_loop;
// --- EXISTING UV UNIFORMS (Keep for compatibility) ---
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;
// --- IGNORED PBR UNIFORMS (You can remove these if you don't need them at all) ---
uniform float point_size : hint_range(0.1, 128.0, 0.1);
uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);


// ----------------------------------------------------------------------
// VERTEX FUNCTION: Handles Billboard and Flipbook UV Animation
// ----------------------------------------------------------------------
void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;

	// Billboard Mode: Particles (Inherited from the base Spatial Shader)
	mat4 mat_world = mat4(
			normalize(INV_VIEW_MATRIX[0]),
			normalize(INV_VIEW_MATRIX[1]),
			normalize(INV_VIEW_MATRIX[2]),
			MODEL_MATRIX[3]);
	mat_world = mat_world * mat4(
			vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0),
			vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0),
			vec4(0.0, 0.0, 1.0, 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;

	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);

	// Flipbook Animation Logic
	float h_frames = float(particles_anim_h_frames);
	float v_frames = float(particles_anim_v_frames);
	float particle_total_frames = float(particles_anim_h_frames * particles_anim_v_frames);
	
	// INSTANCE_CUSTOM.z is the normalized time (0 to 1) for animation offset/loop
	float particle_frame = floor(INSTANCE_CUSTOM.z * float(particle_total_frames)); 
	if (!particles_anim_loop) {
		particle_frame = clamp(particle_frame, 0.0, particle_total_frames - 1.0);
	} else {
		particle_frame = mod(particle_frame, particle_total_frames);
	}
	
	UV /= vec2(h_frames, v_frames);
	UV += vec2(mod(particle_frame, h_frames) / h_frames, floor((particle_frame + 0.5) / h_frames) / v_frames);
}

// ----------------------------------------------------------------------
// FRAGMENT FUNCTION: Handles Masking, Tinting, and Emission
// ----------------------------------------------------------------------
void fragment() {
	vec2 base_uv = UV;

	// 1. Get the texture color (albedo_tex)
	vec4 albedo_tex = texture(texture_albedo, base_uv);
    
    // The mask value is the brightness of the grayscale texture
    float mask_value = albedo_tex.r;

	// 2. Discard (make transparent) the black parts of the mask.
	if (mask_value < 0.01) {
		discard;
	}

	// 3. Set ALBEDO (Base Color)
	// Apply the custom tint_color, scaled by the mask's brightness.
	ALBEDO = tint_color.rgb * mask_value;

	// 4. Set ALPHA/TRANSPARENCY
	// Alpha is controlled by the custom tint_color's alpha and the mask value.
	ALPHA = tint_color.a * mask_value; 

	// 5. Add EMISSION (Glow)
	// The emission uses the tint_color, scaled by the mask and the intensity multiplier.
	EMISSION = tint_color.rgb * mask_value * emission_intensity;

    // --- PBR properties (Kept for completeness, but typically not needed for glowy particles) ---
	float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;

	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
    // --- End PBR properties ---
}