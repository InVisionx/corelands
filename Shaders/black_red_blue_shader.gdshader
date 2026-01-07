shader_type spatial;

// --- BASE (BLACK VERTEX COLOR) - THE GRIP ---
group_uniforms Base_Material_Black;
uniform vec3 base_albedo : source_color = vec3(0.1, 0.1, 0.1); 
uniform float base_metallic : hint_range(0.0, 1.0) = 0.0;     
uniform float base_roughness : hint_range(0.0, 1.0) = 0.8;    

// --- RED (RED VERTEX COLOR) - METAL 1 ---
group_uniforms Red_Material_Grip;
uniform vec3 red_albedo : source_color = vec3(1.0, 1.0, 1.0);
uniform float red_metallic : hint_range(0.0, 1.0) = 1.0;      
uniform float red_roughness : hint_range(0.0, 1.0) = 0.2;     

// --- BLUE (BLUE VERTEX COLOR) - METAL 2 ---
group_uniforms Blue_Material_Accents;
uniform vec3 blue_albedo : source_color = vec3(1.0, 1.0, 1.0);
uniform float blue_metallic : hint_range(0.0, 1.0) = 1.0;     
uniform float blue_roughness : hint_range(0.0, 1.0) = 0.2;    

// --- BRUSHED METAL EFFECT (New) ---
group_uniforms Brushed_Metal;
uniform sampler2D brush_texture : filter_linear_mipmap; // We will put a NoiseTexture here
uniform vec2 brush_scale = vec2(1.0, 20.0);             // Stretch Y a lot to make streaks
uniform float brush_strength : hint_range(0.0, 1.0) = 0.5;

// --- EDGE WEAR ---
group_uniforms Edge_Wear_Grime;
uniform float wear_amount : hint_range(0.0, 1.0) = 0.5;      
uniform float wear_sharpness : hint_range(0.1, 10.0) = 3.0;  
uniform vec3 wear_color : source_color = vec3(0.0, 0.0, 0.0); 

void fragment() {
	float red_mask = step(0.5, COLOR.r);
	float blue_mask = step(0.5, COLOR.b);

	// --- 1. CALCULATE BRUSHED EFFECT ---
	// We stretch the UVs. If your blade UVs go Up/Down, stretch Y (20.0). 
	// If they go Left/Right, stretch X (20.0, 1.0).
	float brush_noise = texture(brush_texture, UV * brush_scale).r;
	
	// We want the noise to affect roughness (make scratches dull)
	// and albedo (make scratches slightly dark)
	float brush_factor = brush_noise * brush_strength;

	// --- 2. SETUP BASE MATERIALS ---
	vec3 final_albedo = base_albedo;
	float final_metallic = base_metallic;
	float final_roughness = base_roughness;

	// Apply Red Material (Modifying roughness with brush_factor)
	// clamp ensures we don't go below 0 or above 1
	float red_rough_brushed = clamp(red_roughness + brush_factor, 0.0, 1.0);
	vec3 red_albedo_brushed = mix(red_albedo, red_albedo * 0.8, brush_factor); // Darken slightly

	final_albedo = mix(final_albedo, red_albedo_brushed, red_mask);
	final_metallic = mix(final_metallic, red_metallic, red_mask);
	final_roughness = mix(final_roughness, red_rough_brushed, red_mask);
	
	// Apply Blue Material (Same logic)
	float blue_rough_brushed = clamp(blue_roughness + brush_factor, 0.0, 1.0);
	vec3 blue_albedo_brushed = mix(blue_albedo, blue_albedo * 0.8, brush_factor);

	final_albedo = mix(final_albedo, blue_albedo_brushed, blue_mask);
	final_metallic = mix(final_metallic, blue_metallic, blue_mask);
	final_roughness = mix(final_roughness, blue_rough_brushed, blue_mask);

	// --- 3. APPLY WEAR ---
	float fresnel = 1.0 - dot(NORMAL, VIEW);
	float wear_factor = pow(fresnel, wear_sharpness);
	final_albedo = mix(final_albedo, wear_color, wear_factor * wear_amount);

	ALBEDO = final_albedo;
	METALLIC = final_metallic;
	ROUGHNESS = final_roughness;
}