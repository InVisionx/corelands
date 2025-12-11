shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// ----- Base Layer -----
group_uniforms BaseLayer;
uniform sampler2D base_albedo;
uniform sampler2D base_normal;
uniform sampler2D base_roughness;
uniform sampler2D base_metallic;
uniform vec2  base_scale = vec2(1.0);
uniform float base_normal_strength   = 1.0;
uniform float base_roughness_strength = 1.0;
uniform float base_metallic_strength  = 1.0;

// ----- Red Layer -----
group_uniforms RedLayer;
uniform sampler2D red_albedo;
uniform sampler2D red_normal;
uniform sampler2D red_roughness;
uniform sampler2D red_metallic;
uniform vec2  red_scale = vec2(1.0);
uniform float red_normal_strength   = 1.0;
uniform float red_roughness_strength = 1.0;
uniform float red_metallic_strength  = 1.0;

// ----- Blue Layer -----
group_uniforms BlueLayer;
uniform sampler2D blue_albedo;
uniform sampler2D blue_normal;
uniform sampler2D blue_roughness;
uniform sampler2D blue_metallic;
uniform vec2  blue_scale = vec2(1.0);
uniform float blue_normal_strength   = 1.0;
uniform float blue_roughness_strength = 1.0;
uniform float blue_metallic_strength  = 1.0;

// ----- Blend Settings -----
group_uniforms BlendSettings;
uniform float transition_width = 0.2; // 0 = hard edge, higher = soft blend

//----------------------------------------------------------
void fragment() {
	vec4 vcol = COLOR;

	// scaled UVs
	vec2 uv_base = UV * base_scale;
	vec2 uv_red  = UV * red_scale;
	vec2 uv_blue = UV * blue_scale;

	// sample albedo
	vec3 base_col = texture(base_albedo, uv_base).rgb;
	vec3 red_col  = texture(red_albedo,  uv_red ).rgb;
	vec3 blue_col = texture(blue_albedo, uv_blue).rgb;

	// sample roughness / metallic (apply strengths)
	float base_rough = texture(base_roughness, uv_base).r * base_roughness_strength;
	float red_rough  = texture(red_roughness,  uv_red ).r * red_roughness_strength;
	float blue_rough = texture(blue_roughness, uv_blue).r * blue_roughness_strength;

	float base_met = texture(base_metallic, uv_base).r * base_metallic_strength;
	float red_met  = texture(red_metallic,  uv_red ).r * red_metallic_strength;
	float blue_met = texture(blue_metallic, uv_blue).r * blue_metallic_strength;

	// sample + unpack normals
	vec3 n_base = texture(base_normal, uv_base).rgb * 2.0 - 1.0;
	vec3 n_red  = texture(red_normal,  uv_red ).rgb * 2.0 - 1.0;
	vec3 n_blue = texture(blue_normal, uv_blue).rgb * 2.0 - 1.0;

	// apply strength, keep length normalized
	n_base.xy *= base_normal_strength; n_base.z = sqrt(max(1.0 - dot(n_base.xy, n_base.xy), 0.0));
	n_red.xy  *= red_normal_strength;  n_red.z  = sqrt(max(1.0 - dot(n_red.xy,  n_red.xy ), 0.0));
	n_blue.xy *= blue_normal_strength; n_blue.z = sqrt(max(1.0 - dot(n_blue.xy, n_blue.xy), 0.0));

	// vertex-color blend weights
	float r = smoothstep(0.0, 1.0, vcol.r);
	float b = smoothstep(0.0, 1.0, vcol.b);
	float blend_r = smoothstep(0.0, transition_width, vcol.r);
	float blend_b = smoothstep(0.0, transition_width, vcol.b);
	float g = clamp(1.0 - (blend_r + blend_b), 0.0, 1.0);

	float total = max(blend_r + blend_b + g, 0.001);
	blend_r /= total;
	blend_b /= total;
	g /= total;

	// blend normals (tangent space)
	vec3 n_tan = normalize(n_base * g + n_red * blend_r + n_blue * blend_b);

	// to world space
	mat3 TBN = mat3(TANGENT, BINORMAL, NORMAL);
	vec3 n_world = normalize(TBN * n_tan);

	// final blended outputs
	vec3 final_col   = base_col * g + red_col * blend_r + blue_col * blend_b;
	float final_rough = base_rough * g + red_rough * blend_r + blue_rough * blend_b;
	float final_met   = base_met * g + red_met * blend_r + blue_met * blend_b;

	ALBEDO    = final_col;
	ROUGHNESS = clamp(final_rough, 0.0, 1.0);
	METALLIC  = clamp(final_met, 0.0, 1.0);
	NORMAL    = n_world;
}
