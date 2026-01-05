shader_type spatial;

// --- GROUP 1: BASE ROCK (Black Vertex Color) ---
group_uniforms Base_Rock_Material;
uniform vec4 rock_color : source_color = vec4(0.188, 0.188, 0.188, 1.0);
uniform float rock_metallic : hint_range(0, 1) = 0.0;
uniform float rock_roughness : hint_range(0, 1) = 0.2;

// --- GROUP 2: ORE VEIN (Red Vertex Color) ---
group_uniforms Ore_Material;
uniform vec4 ore_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float ore_metallic : hint_range(0, 1) = 0.8;
uniform float ore_roughness : hint_range(0, 1) = 0.2;

// --- GROUP 3: GLOW & BORDER EFFECT ---
group_uniforms Glow_Effects;
uniform vec4 emission_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float base_emission_strength : hint_range(0, 10) = 1.0; // Glow of the main red part
uniform float border_boost_strength : hint_range(0, 20) = 5.0;  // Extra glow at the edge
uniform float border_width : hint_range(0.1, 20.0) = 10.0;         // How thick the line is

void fragment() {
	// 1. Get the Mask from Vertex Color (Red Channel)
	// 0.0 = Rock, 1.0 = Ore, 0.5 = The Border
	float mask = COLOR.r;

	// 2. Mix Albedo, Metallic, and Roughness
	vec3 final_albedo = mix(rock_color.rgb, ore_color.rgb, mask);
	float final_metallic = mix(rock_metallic, ore_metallic, mask);
	float final_roughness = mix(rock_roughness, ore_roughness, mask);

	// 3. Calculate the "Border Line"
	// This math creates a hump that peaks when the mask is near 0.5 (the transition)
	// sin(mask * PI) starts at 0, goes to 1, and back to 0.
	float border_mask = sin(mask * 3.14159);

	// Sharpen the border based on width preference
	border_mask = pow(border_mask, border_width);

	// 4. Calculate Emission
	// Base glow only applies to the Ore part (mask), not the rock
	vec3 base_glow = emission_color.rgb * base_emission_strength * mask;

	// Border glow adds on top of that, specifically at the transition
	vec3 border_glow = emission_color.rgb * border_boost_strength * border_mask;

	// --- FINAL OUTPUT ---
	ALBEDO = final_albedo;
	METALLIC = final_metallic;
	ROUGHNESS = final_roughness;
	EMISSION = base_glow + border_glow;
}