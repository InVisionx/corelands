shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_opaque;

uniform sampler2D mask_tex : source_color;
uniform vec4 tint_color : source_color = vec4(1.0, 0.6, 0.2, 1.0);

// --- Timing Controls ---
uniform float lifetime : hint_range(0.1, 10.0) = 2.0;
uniform float finish_early : hint_range(0.0, 2.0) = 0.5;

// --- Visual Controls ---
uniform float fade_strength : hint_range(0.0, 1.0) = 0.5;
uniform float spin_speed : hint_range(-10.0, 10.0) = 1.0;
uniform float max_radius : hint_range(0.0, 2.0) = 1.0;
uniform float end_fade : hint_range(0.0, 1.0) = 0.5;

// --- Gradient Controls ---
uniform bool use_vertical_gradient = false;     // toggle ring ↔ beam
uniform bool flip_vertical_gradient = false;    // flip beam direction
uniform bool invert_gradient = false;           // 🔄 NEW — invert black↔white for both modes
uniform float beam_height = 1.0;

varying float v_progress;

void vertex() {
	v_progress = INSTANCE_CUSTOM.x; // 0→1 per particle
}

void fragment() {
	float progress = clamp(v_progress, 0.0, 1.0);

	// effect timing
	float early_point = clamp(1.0 - (finish_early / lifetime), 0.0, 1.0);
	float expand_progress = min(progress / max(early_point, 0.0001), 1.0);
	float fade_factor = 1.0 - smoothstep(early_point, 1.0, progress) * end_fade;

	// rotation
	float angle = progress * spin_speed * 6.2831853;
	float c = cos(angle);
	float s = sin(angle);
	mat2 rot = mat2(vec2(c, s), vec2(-s, c));

	vec2 uv = UV;
	vec2 centered = uv - vec2(0.5);
	centered = rot * centered;

	float mask = texture(mask_tex, centered + vec2(0.5)).r;
	float gradient = 0.0;

	if (use_vertical_gradient) {
		// 🔶 Vertical beam fade (bottom→top default)
		float v = clamp(uv.y, 0.0, 1.0);
		if (flip_vertical_gradient) v = 1.0 - v;

		float swirl_mod = 0.5 + 0.5 * sin(centered.x * 6.2831853 + angle);
		v += (swirl_mod - 0.5) * 0.1;
		v = clamp(v, 0.0, 1.0);

		float visible_limit = expand_progress;
		gradient = smoothstep(visible_limit - fade_strength, visible_limit, v);
		// fade from black→white normally (invisible→visible)
		gradient = 1.0 - gradient;
	} 
	else {
		// 🔷 Radial ring fade (center→edges default)
		float dist = length(centered) * 2.0;
		float gradient_radius = expand_progress * max_radius;
		gradient = smoothstep(gradient_radius - fade_strength, gradient_radius, dist);
	}

	// 🔄 Apply global inversion toggle (swap black↔white)
	if (invert_gradient)
		gradient = 1.0 - gradient;

	float alpha = mask * gradient * fade_factor;
	if (alpha < 0.01) discard;

	ALBEDO = tint_color.rgb;
	ALPHA  = alpha * tint_color.a;
}
