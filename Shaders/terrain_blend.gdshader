shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// ----- Base Layer -----
group_uniforms BaseLayer;
uniform sampler2D base_albedo : source_color;
// NEW! Color tint for the base layer. Defaults to white (no change).
uniform vec3 base_color_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D base_normal : hint_normal;
uniform sampler2D base_roughness;
uniform sampler2D base_metallic;
uniform vec2  base_scale = vec2(0.5);
uniform float base_normal_strength   = 1.0;
uniform float base_roughness_strength = 1.0;
uniform float base_metallic_strength  = 1.0;

// ----- Red Layer -----
group_uniforms RedLayer;
uniform sampler2D red_albedo : source_color;
// NEW! Color tint for the red painted layer.
uniform vec3 red_color_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D red_normal : hint_normal;
uniform sampler2D red_roughness;
uniform sampler2D red_metallic;
uniform vec2  red_scale = vec2(0.5);
uniform float red_normal_strength   = 1.0;
uniform float red_roughness_strength = 1.0;
uniform float red_metallic_strength  = 1.0;

// ----- Blue Layer -----
group_uniforms BlueLayer;
uniform sampler2D blue_albedo : source_color;
// NEW! Color tint for the blue painted layer.
uniform vec3 blue_color_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D blue_normal : hint_normal;
uniform sampler2D blue_roughness;
uniform sampler2D blue_metallic;
uniform vec2  blue_scale = vec2(0.5);
uniform float blue_normal_strength   = 1.0;
uniform float blue_roughness_strength = 1.0;
uniform float blue_metallic_strength  = 1.0;

// ----- DATA TO PASS FROM VERTEX TO FRAGMENT -----
varying vec3 world_pos;

void vertex() {
	// Calculate the world position of the vertex
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 vcol = COLOR;

	// Use World Position (XZ) for UVs so scaling works
	vec2 uv_base = world_pos.xz * base_scale;
	vec2 uv_red  = world_pos.xz * red_scale;
	vec2 uv_blue = world_pos.xz * blue_scale;

	// Sample Textures AND APPLY TINT
    // NEW! Multiply the sampled texture RGB by the tint RGB
	vec3 base_col = texture(base_albedo, uv_base).rgb * base_color_tint;
	vec3 red_col  = texture(red_albedo,  uv_red ).rgb * red_color_tint;
	vec3 blue_col = texture(blue_albedo, uv_blue).rgb * blue_color_tint;

	float base_rough = texture(base_roughness, uv_base).r * base_roughness_strength;
	float red_rough  = texture(red_roughness,  uv_red ).r * red_roughness_strength;
	float blue_rough = texture(blue_roughness, uv_blue).r * blue_roughness_strength;

	float base_met = texture(base_metallic, uv_base).r * base_metallic_strength;
	float red_met  = texture(red_metallic,  uv_red ).r * red_metallic_strength;
	float blue_met = texture(blue_metallic, uv_blue).r * blue_metallic_strength;

	vec3 n_base = texture(base_normal, uv_base).rgb * 2.0 - 1.0;
	vec3 n_red  = texture(red_normal,  uv_red ).rgb * 2.0 - 1.0;
	vec3 n_blue = texture(blue_normal, uv_blue).rgb * 2.0 - 1.0;

	// Apply Normal Strength
	n_base.xy *= base_normal_strength; n_base.z = sqrt(max(1.0 - dot(n_base.xy, n_base.xy), 0.0));
	n_red.xy  *= red_normal_strength;  n_red.z  = sqrt(max(1.0 - dot(n_red.xy,  n_red.xy ), 0.0));
	n_blue.xy *= blue_normal_strength; n_blue.z = sqrt(max(1.0 - dot(n_blue.xy, n_blue.xy), 0.0));

	// --------------------------------------------------------------------
	// FIXED BLENDING LOGIC (Linear)
	// --------------------------------------------------------------------
	float weight_r = vcol.r;
	float weight_b = vcol.b;
	float weight_base = max(0.0, 1.0 - (weight_r + weight_b));

	// Re-normalize
	float total = weight_base + weight_r + weight_b;
	weight_base /= total;
	weight_r    /= total;
	weight_b    /= total;
	// --------------------------------------------------------------------

	// Blend Normals
	vec3 n_tan = normalize(n_base * weight_base + n_red * weight_r + n_blue * weight_b);
	mat3 TBN = mat3(TANGENT, BINORMAL, NORMAL);
	vec3 n_world = normalize(TBN * n_tan);

	// Blend Albedo, Roughness, Metallic
	vec3 final_col   = base_col * weight_base + red_col * weight_r + blue_col * weight_b;
	float final_rough = base_rough * weight_base + red_rough * weight_r + blue_rough * weight_b;
	float final_met   = base_met * weight_base + red_met * weight_r + blue_met * weight_b;

	ALBEDO    = final_col;
	ROUGHNESS = clamp(final_rough, 0.0, 1.0);
	METALLIC  = clamp(final_met, 0.0, 1.0);
	NORMAL    = n_world;
}