shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// --- Input Textures & Colors ---
uniform sampler2D mask_texture;
uniform vec4 color_a : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.0, 0.0, 1.0, 1.0);

// --- Texture Movement ---
uniform float time_speed = 0.5;
uniform bool move_circle = false;
uniform bool move_vertical = false;
uniform float uniform_scale = 1.0;

// --- Cape Physics ---
uniform float wind_strength : hint_range(0.0, 2.0) = 0.2;
uniform float wind_speed_hz : hint_range(0.0, 10.0) = 3.0;
uniform float wave_frequency : hint_range(0.0, 10.0) = 4.0;
uniform vec2 wind_direction = vec2(1.0, 0.0);

// Vertex color mask
uniform bool use_vertex_color_mask = false;

// ------------------------------------------------
// VERTEX
// ------------------------------------------------
void vertex() {
	float influence = UV.y;
	if (use_vertex_color_mask) {
		influence = COLOR.r;
	}

	influence = pow(influence, 2.2);

	float t = TIME * wind_speed_hz;
	float phase = t - influence * 1.8;

	float sway = sin(phase + UV.y * wave_frequency);

	float flutter = sin(
		phase * 3.2 +
		VERTEX.x * 4.0 +
		VERTEX.y * 2.0
	) * 0.35;

	float motion = (sway + flutter) * wind_strength * influence;

	VERTEX.x += motion * wind_direction.x;
	VERTEX.z += motion * wind_direction.y;
}

// ------------------------------------------------
// FRAGMENT
// ------------------------------------------------
vec2 get_animated_uv(vec2 base_uv) {
	vec2 scaled_uv = base_uv * uniform_scale;
	vec2 offset = vec2(0.0);
	float t = TIME * time_speed;

	if (move_vertical) {
		offset.y -= t * 0.1;
	}

	if (move_circle) {
		offset.x += cos(t) * 0.1;
		offset.y += sin(t) * 0.1;
	}

	return fract(scaled_uv + offset);
}

void fragment() {
	vec2 animated_uv = get_animated_uv(UV);
	float mask_value = texture(mask_texture, animated_uv).r;
	vec4 final_color = mix(color_a, color_b, mask_value);
	ALBEDO = final_color.rgb;
}
