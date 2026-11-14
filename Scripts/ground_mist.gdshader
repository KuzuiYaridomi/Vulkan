shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 mist_color : source_color = vec3(0.2, 0.21, 0.23);
uniform float density : hint_range(0.0, 1.0) = 0.4;
uniform float scale = 0.03;
uniform vec2 wind = vec2(0.012, 0.006);
uniform float fade_radius = 30.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * scale;
	float n = texture(noise_tex, uv + TIME * wind).r * 0.6
			+ texture(noise_tex, uv * 2.1 - TIME * wind * 1.4).r * 0.4;
	float a = smoothstep(0.3, 0.85, n) * density;
	float d = length(world_pos.xz - CAMERA_POSITION_WORLD.xz);
	a *= 1.0 - smoothstep(fade_radius * 0.55, fade_radius, d);
	ALBEDO = mist_color;
	ALPHA = a;
}
