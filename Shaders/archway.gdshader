shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

// ------------------ Parameters ------------------

// Two colors to blend
uniform vec4 color_a : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.3, 0.05, 1.0);

// Mask texture (black/white)
uniform sampler2D mask_tex;

// Mapping controls
uniform bool use_triplanar = false;
uniform float uv_scale : hint_range(0.01, 10.0, 0.01) = 1.0;
uniform vec2 scroll_speed = vec2(0.0, 0.0);

// Triplanar controls
uniform float triplanar_scale : hint_range(0.1, 10.0) = 1.0;
uniform float triplanar_sharpness : hint_range(1.0, 10.0) = 4.0;

// Misc
uniform bool invert_mask = false;

// ------------------ Helper: Triplanar ------------------
vec4 triplanar_sample(sampler2D tex, vec3 n, vec3 pos, float scale, float sharp, vec2 scroll) {
	vec3 w = abs(n);
	w = pow(w, vec3(sharp));
	w /= (w.x + w.y + w.z);
	pos /= scale;
	pos.xy += scroll * TIME;
	pos.yz += scroll * TIME;
	pos.xz += scroll * TIME;
	vec4 x = texture(tex, pos.yz);
	vec4 y = texture(tex, pos.xz);
	vec4 z = texture(tex, pos.xy);
	return x * w.x + y * w.y + z * w.z;
}

// ------------------ Fragment ------------------
void fragment() {
	float mask;

	if (use_triplanar) {
		mask = triplanar_sample(mask_tex, NORMAL, VERTEX, triplanar_scale, triplanar_sharpness, scroll_speed).r;
	} else {
		vec2 uv = UV * uv_scale + TIME * scroll_speed;
		mask = texture(mask_tex, uv).r;
	}

	if (invert_mask) {
		mask = 1.0 - mask;
	}

	vec3 final_col = mix(color_a.rgb, color_b.rgb, mask);

	ALBEDO = final_col;
	EMISSION = final_col; // Makes glow work
	ALPHA = 1.0;
}
