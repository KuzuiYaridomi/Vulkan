shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 fog_color : source_color = vec3(0.17, 0.175, 0.19);
uniform float density : hint_range(0.0, 1.0) = 0.7;
uniform float height = 18.0;
uniform float near_clear = 1.5;
uniform float far_full = 14.0;
uniform vec2 drift = vec2(0.012, 0.004);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = clamp(world_pos.y / height, 0.0, 1.0);
	float vertical = (1.0 - smoothstep(0.3, 1.0, h)) * smoothstep(0.0, 2.5, world_pos.y);
	vec2 uv = vec2(world_pos.x + world_pos.z, world_pos.y * 1.6) * 0.035;
	float n = texture(noise_tex, uv + TIME * drift).r * 0.6
			+ texture(noise_tex, uv * 2.3 - TIME * drift * 1.5).r * 0.4;
	float d = length(world_pos - CAMERA_POSITION_WORLD);
	float a = density * vertical * mix(0.55, 1.0, n) * smoothstep(near_clear, far_full, d);
	ALBEDO = fog_color;
	ALPHA = a;
}
