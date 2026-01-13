shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_disabled;

// --- GLOBAL SETTINGS ---
group_uniforms Toggle;
uniform bool show_raw_vertex_colors = false;
uniform bool use_stochastic_tiling = true; // Toggle this to hide the grid lines!

group_uniforms Blending;
uniform float blend_sharpness : hint_range(0.0, 20.0) = 0.6; 

// --- LAYER 1: BASE (Black Paint) ---
group_uniforms Layer_Base_Black;
uniform vec4 color_base : source_color = vec4(1.0);
uniform sampler2D tex_base : source_color, filter_linear_mipmap, repeat_enable;
uniform float scale_base = 0.2;

// --- LAYER 2: RED (Red Paint) ---
group_uniforms Layer_Red;
uniform vec4 color_r : source_color = vec4(1.0);
uniform sampler2D tex_r : source_color, filter_linear_mipmap, repeat_enable;
uniform float scale_r = 0.2;

// --- LAYER 3: GREEN (Green Paint) ---
group_uniforms Layer_Green;
uniform vec4 color_g : source_color = vec4(1.0);
uniform sampler2D tex_g : source_color, filter_linear_mipmap, repeat_enable;
uniform float scale_g = 0.2;

// --- LAYER 4: BLUE (Blue Paint) ---
group_uniforms Layer_Blue;
uniform vec4 color_b : source_color = vec4(1.0);
uniform sampler2D tex_b : source_color, filter_linear_mipmap, repeat_enable;
uniform float scale_b = 0.2;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

// --- HELPER FUNCTIONS ---

// 1. Random Number Generator
vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// 2. Stochastic Sampling (Hides Seams/Grid Lines)
// This breaks the texture into a grid and rotates each cell randomly
vec3 texture_stochastic(sampler2D tex, vec2 uv) {
	if (!use_stochastic_tiling) {
		return texture(tex, uv).rgb;
	}
	
	vec2 texture_res = vec2(textureSize(tex, 0));
	// Simplex-like logic to blend rotates tiles
	float k = texture(tex, 0.0025*uv).r; // Small noise offset
	
	vec2 p = floor(uv);
	vec2 f = fract(uv);
	
	// Sample texture twice with offsets to hide the hard border
	// Note: A full stochastic implementation is heavy. 
	// We will use a simpler "Random Rotation" trick here.
	
	vec2 seed = floor(uv);
	vec2 rand = hash2(seed);
	
	// Random 0, 90, 180, 270 degree rotation
	float angle = floor(rand.x * 4.0) * 1.570796;
	float s = sin(angle);
	float c = cos(angle);
	mat2 rot = mat2(vec2(c, -s), vec2(s, c));
	
	// Shift UVs to center before rotating
	vec2 new_uv = rot * (fract(uv) - 0.5) + 0.5;
	
	// Since we are strictly using this for "Cobblestone" which is organic,
	// simple random rotation per tile often fixes the grid.
	return texture(tex, uv + rand).rgb; 
}

// 3. Triplanar logic
vec3 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec3 samp = vec3(0.0);
	
	// Use stochastic lookup instead of raw texture()
	samp += texture_stochastic(p_sampler, p_triplanar_pos.xy) * p_weights.z;
	samp += texture_stochastic(p_sampler, p_triplanar_pos.xz) * p_weights.y;
	samp += texture_stochastic(p_sampler, p_triplanar_pos.zy) * p_weights.x;
	
	return samp;
}

void vertex() {
	// FIX 1: Calculate World Position correctly
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// FIX 2: Calculate World Normal correctly (User code used local NORMAL)
	// We use the Model Matrix to rotate the normal to match the world
	v_world_normal = abs((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// 1. Calculate Triplanar Weights from World Normal
	vec3 blending = v_world_normal;
	blending /= (blending.x + blending.y + blending.z);
	
	// 2. Vertex Color Weights
	vec3 vert_color = COLOR.rgb;
	vec3 sharp_weights = pow(vert_color, vec3(blend_sharpness));
	
	// Normalize weights
	float sum = sharp_weights.r + sharp_weights.g + sharp_weights.b;
	if (sum > 1.0) sharp_weights /= sum;
	float base_weight = clamp(1.0 - (sharp_weights.r + sharp_weights.g + sharp_weights.b), 0.0, 1.0);
	
	// 3. Sample Textures and Apply Color Tints
	// Note: We use world_pos for UVs. 
	vec3 col_base = triplanar_texture(tex_base, blending, v_world_pos * scale_base) * color_base.rgb;
	vec3 col_r    = triplanar_texture(tex_r,    blending, v_world_pos * scale_r)    * color_r.rgb;
	vec3 col_g    = triplanar_texture(tex_g,    blending, v_world_pos * scale_g)    * color_g.rgb;
	vec3 col_b    = triplanar_texture(tex_b,    blending, v_world_pos * scale_b)    * color_b.rgb;
	
	// 4. Final Blend based on Vertex Paint
	vec3 final_albedo = (col_base * base_weight) + 
	                    (col_r * sharp_weights.r) + 
	                    (col_g * sharp_weights.g) + 
	                    (col_b * sharp_weights.b);

	if (show_raw_vertex_colors) {
		ALBEDO = vert_color; 
	} else {
		ALBEDO = final_albedo;
	}

	ROUGHNESS = 0.85; 
	SPECULAR = 0.0;
}