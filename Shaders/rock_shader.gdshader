shader_type spatial;

// --- BASE ROCK ---
group_uniforms Base_Rock;
uniform vec4 base_color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0); // TINT ADDED
uniform sampler2D base_texture : source_color, filter_linear_mipmap;

uniform sampler2D base_normal_texture : hint_normal, filter_linear_mipmap; // NORMAL MAP ADDED
uniform float base_normal_strength : hint_range(0.0, 2.0) = 1.0; 

uniform sampler2D base_roughness_texture : hint_default_white, filter_linear_mipmap; // ROUGHNESS MAP ADDED
uniform float rock_roughness : hint_range(0.0, 1.0) = 0.9; // Acts as a multiplier now
uniform float rock_metallic : hint_range(0.0, 1.0) = 0.0;

// --- ORE SETTINGS ---
group_uniforms Ore_Settings;
uniform vec4 ore_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float ore_roughness : hint_range(0.0, 1.0) = 0.2;
uniform float ore_metallic : hint_range(0.0, 1.0) = 1.0;
uniform float ore_emission_strength : hint_range(0.0, 10.0) = 0.0;

// --- BLENDING ---
group_uniforms Blending;
uniform float blend_threshold : hint_range(0.0, 1.0) = 0.1;
uniform float blend_softness : hint_range(0.001, 1.0) = 0.1;

void fragment() {
	// --- 1. CALCULATE BASE ROCK PROPERTIES ---
	// Apply the Tint to the Albedo Texture
	vec3 rock_albedo = texture(base_texture, UV).rgb * base_color_tint.rgb;
	
	// Get Roughness from texture and multiply by the slider
	float rock_rough_final = texture(base_roughness_texture, UV).r * rock_roughness;
	
	// Get Normal Map
	vec3 rock_normal = texture(base_normal_texture, UV).rgb;
	
	// --- 2. CALCULATE MASK ---
	// (0.0 = Rock, 1.0 = Ore)
	float mask = smoothstep(blend_threshold, blend_threshold + blend_softness, COLOR.r);
	
	// --- 3. MIX EVERYTHING ---
	
	// Color
	ALBEDO = mix(rock_albedo, ore_color.rgb, mask);
	
	// Roughness & Metallic
	ROUGHNESS = mix(rock_rough_final, ore_roughness, mask);
	METALLIC = mix(rock_metallic, ore_metallic, mask);
	
	// Emission
	EMISSION = ore_color.rgb * ore_emission_strength * mask;
	
	// --- 4. APPLY NORMAL MAP ---
	// We mix the Rock's bumpy normal with a "Flat" normal (0.5, 0.5, 1.0)
	// This makes the Ore veins look smooth/filled in, covering the rock's cracks.
	vec3 flat_normal = vec3(0.5, 0.5, 1.0);
	vec3 final_normal = mix(rock_normal, flat_normal, mask);
	
	NORMAL_MAP = final_normal;
	NORMAL_MAP_DEPTH = base_normal_strength;
}