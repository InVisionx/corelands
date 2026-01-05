shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// CONTROLS
uniform float triplanar_blend_sharpness : hint_range(1.0, 20.0) = 4.0;
uniform float specular_smoothness : hint_range(0.0, 1.0) = 0.0; // Helps remove "sparkles" on rough surfaces

// --- BASE LAYER ---
group_uniforms BaseLayer;
uniform sampler2D base_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap_anisotropic;
// G=Roughness, B=Metallic. Defaults to White so sliders work without texture.
uniform sampler2D base_orm : hint_default_white, filter_linear_mipmap_anisotropic;
uniform vec3 base_tint : source_color = vec3(1.0);
uniform float base_roughness : hint_range(0.0, 1.0) = 1.0; // SLIDER ADDED
uniform float base_metallic : hint_range(0.0, 1.0) = 0.0;  // SLIDER ADDED
uniform float base_scale = 0.5;
uniform float base_normal_strength = 1.0;

// --- RED LAYER ---
group_uniforms RedLayer;
uniform sampler2D red_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D red_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D red_orm : hint_default_white, filter_linear_mipmap_anisotropic;
uniform vec3 red_tint : source_color = vec3(1.0);
uniform float red_roughness : hint_range(0.0, 1.0) = 1.0; // SLIDER ADDED
uniform float red_metallic : hint_range(0.0, 1.0) = 0.0;  // SLIDER ADDED
uniform float red_scale = 0.5;
uniform float red_normal_strength = 1.0;

// --- BLUE LAYER ---
group_uniforms BlueLayer;
uniform sampler2D blue_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D blue_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D blue_orm : hint_default_white, filter_linear_mipmap_anisotropic;
uniform vec3 blue_tint : source_color = vec3(1.0);
uniform float blue_roughness : hint_range(0.0, 1.0) = 1.0; // SLIDER ADDED
uniform float blue_metallic : hint_range(0.0, 1.0) = 0.0;  // SLIDER ADDED
uniform float blue_scale = 0.5;
uniform float blue_normal_strength = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_NORMAL_MATRIX * NORMAL));
}

vec3 triplanar_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(triplanar_blend_sharpness));
	return w / (w.x + w.y + w.z);
}

vec3 sample_triplanar_albedo(sampler2D tex, vec3 pos, vec3 w, float scale) {
	vec3 x = texture(tex, pos.yz * scale).rgb;
	vec3 y = texture(tex, pos.xz * scale).rgb;
	vec3 z = texture(tex, pos.xy * scale).rgb;
	return x * w.x + y * w.y + z * w.z;
}

// Samples the ORM texture (G = Roughness, B = Metallic)
vec2 sample_triplanar_orm(sampler2D tex, vec3 pos, vec3 w, float scale) {
	vec2 x = texture(tex, pos.yz * scale).gb;
	vec2 y = texture(tex, pos.xz * scale).gb;
	vec2 z = texture(tex, pos.xy * scale).gb;
	return x * w.x + y * w.y + z * w.z;
}

vec3 sample_triplanar_normal(sampler2D tex, vec3 pos, vec3 w, float scale, float strength) {
	vec3 tx = texture(tex, pos.yz * scale).xyz * 2.0 - 1.0;
	vec3 ty = texture(tex, pos.xz * scale).xyz * 2.0 - 1.0;
	vec3 tz = texture(tex, pos.xy * scale).xyz * 2.0 - 1.0;

	tx.xy *= strength;
	ty.xy *= strength;
	tz.xy *= strength;

	vec3 weights = w;
	vec3 blend_normal =
		vec3(0.0, tx.y, tx.x) * weights.x +
		vec3(ty.y, 0.0, ty.x) * weights.y +
		vec3(tz.x, tz.y, 0.0) * weights.z;

	return normalize(blend_normal + world_normal);
}

void fragment() {
	// Vertex Paint Weights
	vec4 vcol = COLOR;
	float w_r = vcol.r;
	float w_b = vcol.b;
	float w_base = max(0.0, 1.0 - (w_r + w_b));

	float total_layer_weight = w_base + w_r + w_b;
	w_base /= total_layer_weight;
	w_r /= total_layer_weight;
	w_b /= total_layer_weight;

	vec3 tri_w = triplanar_weights(world_normal);

	// --- BASE LAYER ---
	vec3 base_col = sample_triplanar_albedo(base_albedo, world_pos, tri_w, base_scale) * base_tint;
	vec2 base_orm_vals = sample_triplanar_orm(base_orm, world_pos, tri_w, base_scale);
	// Apply Sliders
	float base_r_final = base_orm_vals.r * base_roughness;
	float base_m_final = base_orm_vals.g * base_metallic;
	vec3 n_base = sample_triplanar_normal(base_normal, world_pos, tri_w, base_scale, base_normal_strength);

	// --- RED LAYER ---
	vec3 red_col = sample_triplanar_albedo(red_albedo, world_pos, tri_w, red_scale) * red_tint;
	vec2 red_orm_vals = sample_triplanar_orm(red_orm, world_pos, tri_w, red_scale);
	// Apply Sliders
	float red_r_final = red_orm_vals.r * red_roughness;
	float red_m_final = red_orm_vals.g * red_metallic;
	vec3 n_red = sample_triplanar_normal(red_normal, world_pos, tri_w, red_scale, red_normal_strength);

	// --- BLUE LAYER ---
	vec3 blue_col = sample_triplanar_albedo(blue_albedo, world_pos, tri_w, blue_scale) * blue_tint;
	vec2 blue_orm_vals = sample_triplanar_orm(blue_orm, world_pos, tri_w, blue_scale);
	// Apply Sliders
	float blue_r_final = blue_orm_vals.r * blue_roughness;
	float blue_m_final = blue_orm_vals.g * blue_metallic;
	vec3 n_blue = sample_triplanar_normal(blue_normal, world_pos, tri_w, blue_scale, blue_normal_strength);

	// --- FINAL BLEND ---
	ALBEDO =
		base_col * w_base +
		red_col * w_r +
		blue_col * w_b;

	ROUGHNESS =
		base_r_final * w_base +
		red_r_final * w_r +
		blue_r_final * w_b;

	METALLIC =
		base_m_final * w_base +
		red_m_final * w_r +
		blue_m_final * w_b;

	NORMAL = normalize(
		n_base * w_base +
		n_red * w_r +
		n_blue * w_b
	);

	// Optional: SPECULAR anti-aliasing
	SPECULAR = 0.5 + specular_smoothness;
}